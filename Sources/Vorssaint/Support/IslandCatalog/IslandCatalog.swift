// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import ObjectiveC
import SwiftUI

/// Zenith fork: `--render-island-catalog <dir>` draws the island's states
/// offscreen, with sample data, into PNGs for the catalog PDF
/// (Tools/IslandCatalog/run.sh), then exits.
///
/// It runs before the app's defaults migrations and never reaches the app
/// delegate, so it shows no window, takes no shortcut and leaves a running
/// Zenith alone. Preferences are read from memory only: every registered
/// default and the shot's own choices sit in the volatile argument domain,
/// and writes to any defaults are dropped. Services are posed through their
/// `catalogPose` hooks rather than started. The run script adds a sandbox
/// that denies the network, the Keychain, notifications, the camera and any
/// write outside the output folder.
@MainActor
enum IslandCatalog {
    nonisolated static let flag = "--render-island-catalog"
    /// Read by the few services the catalog must keep from reaching out.
    nonisolated static let isRendering = CommandLine.arguments.contains(flag)

    nonisolated static func isRequested(by arguments: [String]) -> Bool { arguments.contains(flag) }

    static func runAndExit() -> Never {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            print("ISLAND CATALOG FAILED: \(flag) needs an output folder")
            exit(1)
        }
        // The sandbox is what keeps a stray write or request from leaving the
        // process; render.sh starts it and says so.
        guard ProcessInfo.processInfo.environment["ZENITH_ISLAND_CATALOG_SANDBOX"] == "1" else {
            print("ISLAND CATALOG FAILED: run it through Tools/IslandCatalog/render.sh, which sandboxes it")
            exit(1)
        }
        let folder = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let only = arguments.firstIndex(of: "--only").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        CatalogDefaults.isolate()
        // Run in its sandbox, the app's own saved preferences are out of reach.
        let saved = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }?.count ?? 0
        print("saved preferences visible: \(saved)")
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            print("ISLAND CATALOG FAILED: \(error.localizedDescription)")
            exit(1)
        }
        // Zenith fork: `--only motion…` renders frame sequences of transitions instead.
        if let only, only.hasPrefix("motion") {
            let failures = CatalogMotion.render(prefix: only, into: folder)
            print(failures.isEmpty ? "ISLAND MOTION OK" : "ISLAND MOTION FAILED: \(failures)")
            exit(failures.isEmpty ? 0 : 1)
        }
        var manifest: [[String: Any]] = []
        var failures: [String] = []
        // Zenith fork: `--only readme…` draws the README's pictures instead.
        let shots = only?.hasPrefix("readme") == true ? CatalogShots.readme : CatalogShots.all
        for shot in shots where only.map({ shot.id.hasPrefix($0) }) ?? true {
            let url = folder.appendingPathComponent(shot.id + ".png")
            if let entry = CatalogRenderer.render(shot, to: url) {
                manifest.append(entry)
                print("rendered \(shot.id) \(Int(entry["width"] as? CGFloat ?? 0))x\(Int(entry["height"] as? CGFloat ?? 0))")
            } else {
                failures.append(shot.id)
                print("FAILED \(shot.id)")
            }
        }
        if only == nil {
            let data = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            try? data?.write(to: folder.appendingPathComponent("manifest.json"))
        }
        let muted = CatalogDefaults.mutedKeys.sorted()
        if !muted.isEmpty { print("defaults writes dropped: \(muted.joined(separator: ", "))") }
        print(failures.isEmpty ? "ISLAND CATALOG OK: \(manifest.count) renders" : "ISLAND CATALOG FAILED: \(failures)")
        exit(failures.isEmpty ? 0 : 1)
    }
}

// MARK: - Preferences in memory

/// Every preference the views read comes from memory, never the app's own
/// domain, and nothing is written.
@MainActor
enum CatalogDefaults {
    private(set) static var mutedKeys = Set<String>()
    private static var base: [String: Any] = [:]

    static func isolate() {
        muteWrites()
        var values = Defaults.registeredDefaults
        for feature in AppFeature.allCases { values[feature.availabilityKey] = true }
        values.merge(CatalogShots.basePreferences) { $1 }
        base = values
        apply([:])
    }

    /// The base choices with `overrides` on top, for one shot.
    static func apply(_ overrides: [String: Any]) {
        UserDefaults.standard.setVolatileDomain(base.merging(overrides) { $1 }, forName: UserDefaults.argumentDomain)
    }

    nonisolated private static func note(_ key: NSString) {
        let key = key as String
        DispatchQueue.main.async { MainActor.assumeIsolated { _ = mutedKeys.insert(key) } }
    }

    /// Replaces the setters of every UserDefaults with ones that only note the key.
    private static func muteWrites() {
        let type: AnyClass = UserDefaults.self
        func replace(_ name: String, _ block: Any) {
            guard let method = class_getInstanceMethod(type, NSSelectorFromString(name)) else { return }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
        let object: @convention(block) (AnyObject, AnyObject?, NSString) -> Void = { _, _, key in note(key) }
        let flag: @convention(block) (AnyObject, Bool, NSString) -> Void = { _, _, key in note(key) }
        let integer: @convention(block) (AnyObject, Int, NSString) -> Void = { _, _, key in note(key) }
        let float: @convention(block) (AnyObject, Float, NSString) -> Void = { _, _, key in note(key) }
        let double: @convention(block) (AnyObject, Double, NSString) -> Void = { _, _, key in note(key) }
        let remove: @convention(block) (AnyObject, NSString) -> Void = { _, key in note(key) }
        replace("setObject:forKey:", object)
        replace("setURL:forKey:", object)
        replace("setBool:forKey:", flag)
        replace("setInteger:forKey:", integer)
        replace("setFloat:forKey:", float)
        replace("setDouble:forKey:", double)
        replace("removeObjectForKey:", remove)
    }
}

// MARK: - Shots

/// What one render shows: its preferences, the state it poses and the view.
struct CatalogShot {
    enum Kind: String {
        /// Hangs from the top edge at the camera, as the island does.
        case island
        /// A whole screen, drawn by the view itself.
        case screen
        /// Zenith fork: a titled window around the view (Settings), with its
        /// title bar and toolbar, rounded and shadowed.
        case window
    }

    let id: String
    var kind: Kind = .island
    var preferences: [String: Any] = [:]
    /// Poses the services, after the shot's preferences are in place.
    var setup: @MainActor () -> Void = {}
    /// Puts the services back after the render.
    var teardown: @MainActor () -> Void = {}
    /// How long the view runs before it is drawn, for what loads on appear.
    var settle: TimeInterval = 0.25
    /// Zenith fork: draws a `.window` shot in Light Mode instead of Dark.
    var light = false
    let draw: @MainActor () -> (view: AnyView, size: CGSize)
}

// MARK: - Rendering

@MainActor
enum CatalogRenderer {
    static func render(_ shot: CatalogShot, to url: URL) -> [String: Any]? {
        CatalogDefaults.apply(shot.preferences)
        // Let anything that follows preference changes run before the pose.
        spin(0.05)
        CatalogSamples.reset()
        shot.setup()
        let (view, size) = shot.draw()
        guard size.width >= 1, size.height >= 1 else { shot.teardown(); return nil }
        if shot.kind == .window { return renderWindow(shot, view: view, size: size, to: url) }
        let host = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height, alignment: .top)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, Locale(identifier: "en_US")))
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        spin(shot.settle)
        host.layoutSubtreeIfNeeded()
        defer {
            window.contentView = nil
            window.close()
            shot.teardown()
        }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        do { try data.write(to: url) } catch { return nil }
        return ["id": shot.id, "kind": shot.kind.rawValue, "width": size.width, "height": size.height,
                "pixelsWide": bitmap.pixelsWide]
    }

    /// Zenith fork: the view as the content of a titled window, never shown,
    /// drawn with its frame (title bar, toolbar, sidebar), then given the
    /// window's rounded corners and shadow on a clear background.
    private static func renderWindow(_ shot: CatalogShot, view: AnyView, size: CGSize, to url: URL) -> [String: Any]? {
        let appearance = NSAppearance(named: shot.light ? .aqua : .darkAqua)
        NSApp.appearance = appearance
        let host = NSHostingController(rootView: view.environment(\.locale, Locale(identifier: "en_US")))
        host.sizingOptions = []
        let window = SettingsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.appearance = appearance
        window.isReleasedWhenClosed = false
        window.title = L10n.shared.s.settingsTitle
        window.setContentSize(size)
        defer {
            window.contentViewController = nil
            window.close()
            shot.teardown()
        }
        guard let frameView = window.contentView?.superview else { return nil }
        frameView.layoutSubtreeIfNeeded()
        spin(shot.settle)
        frameView.layoutSubtreeIfNeeded()
        spin(0.1)
        guard let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return nil }
        frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
        guard let image = bitmap.cgImage else { return nil }
        let scale = CGFloat(bitmap.pixelsWide) / frameView.bounds.width
        let margin: CGFloat = 40, radius: CGFloat = 12
        let points = CGSize(width: frameView.bounds.width + margin * 2, height: frameView.bounds.height + margin * 2)
        guard let context = CGContext(data: nil, width: Int(points.width * scale), height: Int(points.height * scale),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        let frame = CGRect(x: margin, y: margin, width: frameView.bounds.width, height: frameView.bounds.height)
        let rounded = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12), blur: 36, color: CGColor(gray: 0, alpha: 0.45))
        context.addPath(rounded)
        context.setFillColor(CGColor(gray: 0.12, alpha: 1))
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(rounded)
        context.clip()
        context.draw(image, in: frame)
        context.restoreGState()
        // The window's hairline edge.
        context.addPath(CGPath(roundedRect: frame.insetBy(dx: 0.25, dy: 0.25), cornerWidth: radius, cornerHeight: radius,
                               transform: nil))
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
        context.setLineWidth(0.5)
        context.strokePath()
        guard let output = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]) else { return nil }
        do { try data.write(to: url) } catch { return nil }
        return ["id": shot.id, "kind": shot.kind.rawValue, "width": points.width, "height": points.height,
                "pixelsWide": output.width]
    }

    static func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }
}
#endif
