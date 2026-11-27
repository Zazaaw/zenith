// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import Combine
import CoreImage
import ImageIO
import Vision

// Zenith fork: Remove Background's entry points and its work. The shortcut
// takes the Finder selection while Finder is in front, otherwise the
// clipboard's picture; the Command Bar takes the clipboard; the Shelf's menu
// hands its files over. Vision's foreground instance mask runs on a work
// queue, the result is written beside the original or put on the clipboard,
// and a small card says what happened. Off, nothing is registered or
// observed: no hotkey, no observer.

final class RemoveBackgroundService: ObservableObject {
    static let shared = RemoveBackgroundService()

    // B for background, on the four-modifier layer: ⌃⌥⌘B is the menu bar hider's.
    static let defaultShortcut = GlobalShortcut(keyCode: Int64(kVK_ANSI_B),
                                                modifiers: [.control, .option, .shift, .command])
    // Past Mechakey's 2600.
    private static let hotkeyID: UInt32 = 2700

    @Published private(set) var shortcutRefused = false
    @Published private(set) var working = false

    private let hotkey = QuickToolHotkey(id: RemoveBackgroundService.hotkeyID)
    private var captureObserver: NSObjectProtocol?
    private let queue = DispatchQueue(label: "Zenith.RemoveBackground", qos: .userInitiated)

    private init() {
        hotkey.onPress = { [weak self] in self?.runFromShortcut() }
    }

    private var text: ZenithRemoveBackgroundStrings { ZenithStrings.removeBackground(L10n.shared.language) }

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: RemoveBackgroundDefaults.enabled)
    }

    /// At launch: only a Remove Background that is on comes to life.
    static func launch() {
        guard isEnabled() else { return }
        shared.syncWithPreferences()
    }

    static func savedShortcut(_ defaults: UserDefaults = .standard) -> GlobalShortcut? {
        guard let raw = defaults.string(forKey: RemoveBackgroundDefaults.shortcut) else { return defaultShortcut }
        if raw.isEmpty { return nil }
        return GlobalShortcut(storageValue: raw) ?? defaultShortcut
    }

    // MARK: Shortcut

    /// Registers the shortcut while the feature is on and lets go of
    /// everything when it is off. Called at launch, by the Settings page and
    /// after a shortcut field stops recording.
    func syncWithPreferences() {
        guard Self.isEnabled() else {
            hotkey.unregister()
            if let captureObserver { NotificationCenter.default.removeObserver(captureObserver) }
            captureObserver = nil
            if shortcutRefused { shortcutRefused = false }
            MainActor.assumeIsolated { RemoveBackgroundCardController.shared.close() }
            return
        }
        if captureObserver == nil {
            captureObserver = NotificationCenter.default.addObserver(forName: .zenithShortcutCaptureEnded, object: nil,
                                                                     queue: .main) { [weak self] _ in
                self?.syncWithPreferences()
            }
        }
        guard let shortcut = Self.savedShortcut() else {
            hotkey.unregister()
            if shortcutRefused { shortcutRefused = false }
            return
        }
        let refused = !hotkey.sync(enabled: true, shortcut: shortcut, storageKey: RemoveBackgroundDefaults.shortcut)
        if refused != shortcutRefused { shortcutRefused = refused }
    }

    func conflict(for shortcut: GlobalShortcut) -> String? {
        GlobalShortcutRole.conflict(for: shortcut, excluding: nil)?.title(L10n.shared.s)
    }

    func openSettings() {
        SettingsRouter.shared.request(FeatureSettingsDestination(.removeBackground, sectionAnchor: .zenithRemoveBackground))
        appDelegate()?.openSettingsWindow()
    }

    // MARK: Entry points

    /// The shortcut: Finder's selection while Finder is in front, otherwise the clipboard.
    func runFromShortcut() {
        guard Self.isEnabled(), !working else { return }
        let finderInFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
        guard finderInFront else { return runFromClipboard(emptyMessage: text.nothing) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let selection = FinderBridge.selectionURLs()
            DispatchQueue.main.async {
                guard let self else { return }
                let pictures = RemoveBackgroundSupport.images(in: selection)
                if pictures.isEmpty {
                    self.runFromClipboard(emptyMessage: self.text.nothing)
                } else {
                    self.process(.files(pictures))
                }
            }
        }
    }

    /// The Command Bar's row: what the clipboard holds.
    func runFromClipboard(emptyMessage: String? = nil) {
        guard Self.isEnabled(), !working else { return }
        let message = emptyMessage ?? text.clipboardNothing
        GeneralPasteboardAccess.shared.async(timeout: 1.5, { _ -> RemoveBackgroundClipboard? in
            RemoveBackgroundClipboard.read(NSPasteboard.general)
        }, then: { [weak self] clipboard in
            guard let self else { return }
            let source = RemoveBackgroundSupport.clipboardSource(files: clipboard?.files ?? [],
                                                                 hasImage: clipboard?.image != nil)
            switch source {
            case .files: self.process(source)
            case .clipboardImage: self.process(source, clipboardImage: clipboard?.image)
            case .nothing: self.showMessage(message)
            }
        })
    }

    /// The Shelf's menu: these files.
    func run(files: [URL]) {
        let pictures = RemoveBackgroundSupport.images(in: files)
        guard Self.isEnabled(), !working, !pictures.isEmpty else { return }
        process(.files(pictures))
    }

    /// The Shelf's menu item, while the feature is on and pictures are chosen.
    static func shelfMenuItem(for urls: [URL]) -> NSMenuItem? {
        guard isEnabled(), !RemoveBackgroundSupport.images(in: urls).isEmpty else { return nil }
        let item = RemoveBackgroundMenuItem(title: ZenithStrings.removeBackground(.enUS).title, urls: urls)
        item.image = NSImage(systemSymbolName: "person.and.background.dotted", accessibilityDescription: nil)
        return item
    }

    // MARK: Work

    private func process(_ source: RemoveBackgroundSource, clipboardImage: CGImage? = nil) {
        let preferences = RemoveBackgroundPreferences()
        working = true
        MainActor.assumeIsolated { RemoveBackgroundCardController.shared.show(.working(text.working)) }
        let box = RemoveBackgroundImageBox(clipboardImage)
        queue.async { [weak self] in
            let outcome = RemoveBackgroundWork.run(source, clipboardImage: box.image, preferences: preferences)
            let result = RemoveBackgroundOutcomeBox(outcome)
            DispatchQueue.main.async { self?.finish(result.outcome) }
        }
    }

    private func finish(_ outcome: RemoveBackgroundOutcome) {
        working = false
        if outcome.done == 0 && outcome.failed == 0 {
            return showMessage(text.failed)
        }
        let finished = { (copied: Bool) in
            let summary = RemoveBackgroundSupport.summary(done: outcome.done, failed: outcome.failed, toClipboard: copied)
            MainActor.assumeIsolated {
                RemoveBackgroundCardController.shared.show(.result(summary: summary, preview: outcome.preview,
                                                                  files: outcome.files, pngs: outcome.clipboardPNGs,
                                                                  copied: copied))
            }
        }
        guard !outcome.clipboardPNGs.isEmpty else { return finished(false) }
        Self.copy(pngs: outcome.clipboardPNGs) { ok in finished(ok) }
    }

    private func showMessage(_ message: String) {
        MainActor.assumeIsolated { RemoveBackgroundCardController.shared.show(.message(message)) }
    }

    /// Puts the results on the clipboard as PNGs, which keep their transparency.
    static func copy(pngs: [Data], completion: @escaping (Bool) -> Void) {
        GeneralPasteboardAccess.shared.async({ () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareVorssaintSource()
            let items = pngs.map { png -> NSPasteboardItem in
                let item = NSPasteboardItem()
                item.setData(png, forType: .png)
                if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
                return item
            }
            return pasteboard.writeObjects(items)
        }, then: completion)
    }
}

/// What the clipboard held: picture files, or a picture that is not a file.
struct RemoveBackgroundClipboard {
    let files: [URL]
    let image: CGImage?

    /// Read on the pasteboard's lane. A copied file wins over the picture
    /// data an app puts beside it.
    static func read(_ pasteboard: NSPasteboard) -> RemoveBackgroundClipboard {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self],
                                           options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        if !RemoveBackgroundSupport.images(in: urls).isEmpty { return RemoveBackgroundClipboard(files: urls, image: nil) }
        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType("public.jpeg"),
                     NSPasteboard.PasteboardType("public.heic")] {
            guard let data = pasteboard.data(forType: type),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = MediaImageProcessing.decode(source, at: CGImageSourceGetPrimaryImageIndex(source),
                                                          maximumDimension: MediaSupport.maxImageRenderDimension)
            else { continue }
            return RemoveBackgroundClipboard(files: [], image: image)
        }
        return RemoveBackgroundClipboard(files: [], image: nil)
    }
}

/// A finished run.
struct RemoveBackgroundOutcome {
    var done = 0
    var failed = 0
    /// Files written beside their originals.
    var files: [URL] = []
    /// Results bound for the clipboard.
    var clipboardPNGs: [Data] = []
    /// The first result, small, for the card.
    var preview: CGImage?
}

/// The Vision request and the writing, on the work queue.
enum RemoveBackgroundWork {
    static func run(_ source: RemoveBackgroundSource, clipboardImage: CGImage?,
                    preferences: RemoveBackgroundPreferences) -> RemoveBackgroundOutcome {
        var outcome = RemoveBackgroundOutcome()
        func keep(_ cutout: CGImage, input: URL?) {
            let fileManager = FileManager.default
            let folder = input?.deletingLastPathComponent().path ?? ""
            let destination = RemoveBackgroundSupport.destination(
                for: input, output: preferences.output, folderWritable: fileManager.isWritableFile(atPath: folder),
                exists: { fileManager.fileExists(atPath: $0.path) })
            switch destination {
            case .file(let url):
                // A file that cannot be written beside its original goes to the clipboard instead.
                if (try? write(cutout, to: url)) != nil {
                    outcome.files.append(url)
                } else if let png = png(cutout) {
                    outcome.clipboardPNGs.append(png)
                } else {
                    outcome.failed += 1
                    return
                }
            case .clipboard:
                guard let png = png(cutout) else { outcome.failed += 1; return }
                outcome.clipboardPNGs.append(png)
            }
            outcome.done += 1
            if outcome.preview == nil { outcome.preview = thumbnail(cutout) }
        }
        switch source {
        case .files(let urls):
            for url in urls {
                guard let image = NotchPhotoEncoder.uprightImage(at: url, maximumDimension: MediaSupport.maxImageRenderDimension),
                      let cutout = cutout(image, crop: preferences.framing == .crop)
                else { outcome.failed += 1; continue }
                keep(cutout, input: url)
            }
        case .clipboardImage:
            guard let clipboardImage, let cutout = cutout(clipboardImage, crop: preferences.framing == .crop) else {
                outcome.failed += 1
                break
            }
            keep(cutout, input: nil)
        case .nothing:
            break
        }
        return outcome
    }

    /// The subject over transparency, or nil when Vision finds none.
    static func cutout(_ image: CGImage, crop: Bool) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first,
              !observation.allInstances.isEmpty,
              let mask = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler),
              let cutout = NotchPhotoEncoder.cutout(image, mask: CIImage(cvPixelBuffer: mask))
        else { return nil }
        return crop ? cropped(cutout) ?? cutout : cutout
    }

    /// The cutout cropped to its opaque pixels.
    static func cropped(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height, row = width * 4
        var bytes = [UInt8](repeating: 0, count: row * height)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: row, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, let bounds = RemoveBackgroundSupport.subjectBounds(rgba: bytes, width: width, height: height,
                                                                         bytesPerRow: row) else { return nil }
        // The bitmap's rows run from the top, as CGImage cropping counts them.
        return image.cropping(to: bounds)
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        let staged = try MediaSupport.temporaryOutputURL(for: url)
        defer { MediaSupport.discardStagedOutput(staged) }
        try NotchPhotoEncoder.write(image, format: .png, quality: 1, properties: [:], to: staged)
        try MediaSupport.installStagedOutput(staged, at: url, replacingExisting: false)
        MediaSupport.makeVisibleIfNeeded(url)
    }

    private static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func thumbnail(_ image: CGImage) -> CGImage? {
        let long = max(image.width, image.height)
        guard long > 320 else { return image }
        let scale = 320 / Double(long)
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

private final class RemoveBackgroundImageBox: @unchecked Sendable {
    let image: CGImage?
    init(_ image: CGImage?) { self.image = image }
}

private final class RemoveBackgroundOutcomeBox: @unchecked Sendable {
    let outcome: RemoveBackgroundOutcome
    init(_ outcome: RemoveBackgroundOutcome) { self.outcome = outcome }
}

/// The Shelf's menu item, which keeps its files and runs on its own.
private final class RemoveBackgroundMenuItem: NSMenuItem {
    private let urls: [URL]

    init(title: String, urls: [URL]) {
        self.urls = urls
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func run() {
        RemoveBackgroundService.shared.run(files: urls)
    }
}
