// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: Privacy Blur's decisions, without windows, observers or event
// monitors, so the tests reach every one: the preferences, the chat apps and
// where their columns sit, the parts of a window each region covers, which
// part the pointer reveals, which on-screen windows get an overlay and when
// one has to be ordered again, and when the blur is on at all.
//
// Geometry is in the window server's space (origin at the top left of the
// main display, y down). A window's parts are in its own space (origin at
// its top left, y down), which is also the overlay view's flipped space.

/// Privacy Blur's preferences. Kept here, not in `DefaultsKey`, so the
/// feature's files never edit a shared registry.
enum PrivacyBlurDefaults {
    static let enabled = "zenithPrivacyBlurEnabled"                 // Bool, default false
    static let apps = "zenithPrivacyBlurApps"                       // [String] app ids, default [WhatsApp]
    static let customNames = "zenithPrivacyBlurCustomNames"         // [String: String] bundle id → name
    static let regions = "zenithPrivacyBlurRegions"                 // [String: [String]] app id → regions
    static let listWidths = "zenithPrivacyBlurListWidths"           // [String: Double] app id → chat list edge
    static let strength = "zenithPrivacyBlurStrength"               // Double 0...1, default 0.6
    static let hover = "zenithPrivacyBlurHover"                     // PrivacyBlurHover, default .region
    static let holdKey = "zenithPrivacyBlurHoldKey"                 // PrivacyBlurHoldKey, default .none
    static let revealWhileTyping = "zenithPrivacyBlurRevealTyping"  // Bool, default false
    static let when = "zenithPrivacyBlurWhen"                       // PrivacyBlurWhen, default .always
    static let presentationMode = "zenithPrivacyBlurPresentation"   // Bool, default false (not backed up)
    static let shortcut = "zenithPrivacyBlurShortcut"               // GlobalShortcut.storageValue, "" for none

    /// What the settings backup carries. Presentation mode is the state of
    /// one talk on one Mac, so it stays out.
    static let backupKeys: Set<String> = [enabled, apps, customNames, regions, listWidths, strength, hover,
                                          holdKey, revealWhileTyping, when, shortcut]
    static let defaultStrength = 0.6
}

// MARK: - Apps

/// Where a chat app's columns sit, in points from its window's edges. The
/// apps change their layouts, so these are a starting point the page lets
/// the person adjust (the chat list's edge); "Everything" never depends on them.
struct PrivacyBlurLayout: Equatable {
    /// A strip on the leading edge before the chat list: WhatsApp's tabs,
    /// Slack's workspaces, Discord's servers.
    var rail: CGFloat
    /// The chat list's trailing edge, from the window's leading edge.
    var listEdge: CGFloat
    /// The conversation's header (the name and photo), from the window's top.
    var header: CGFloat
    /// Where the chat list's rows start, from the window's top.
    var listTop: CGFloat
    /// The photos' column at the leading edge of the list.
    var avatar: CGFloat
    /// A trailing panel of names (Discord's members), 0 for none.
    var trailing: CGFloat = 0

    /// For an app Zenith knows nothing about: a common two-column chat.
    static let generic = PrivacyBlurLayout(rail: 0, listEdge: 320, header: 56, listTop: 90, avatar: 64)

    /// The chat list edge a slider may choose.
    static let listEdgeRange: ClosedRange<Double> = 160...720
}

/// A chat app Privacy Blur knows: its name, the bundle ids it ships under
/// and where its columns sit.
struct PrivacyBlurPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIDs: [String]
    let layout: PrivacyBlurLayout

    static let whatsApp = PrivacyBlurPreset(
        id: "net.whatsapp.WhatsApp", name: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp", "desktop.WhatsApp"],
        layout: PrivacyBlurLayout(rail: 64, listEdge: 440, header: 64, listTop: 150, avatar: 72))
    static let telegram = PrivacyBlurPreset(
        id: "ru.keepcoder.Telegram", name: "Telegram",
        bundleIDs: ["ru.keepcoder.Telegram", "com.tdesktop.Telegram", "org.telegram.desktop"],
        layout: PrivacyBlurLayout(rail: 0, listEdge: 320, header: 56, listTop: 92, avatar: 66))
    static let slack = PrivacyBlurPreset(
        id: "com.tinyspeck.slackmacgap", name: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"],
        layout: PrivacyBlurLayout(rail: 72, listEdge: 340, header: 92, listTop: 92, avatar: 40))
    static let discord = PrivacyBlurPreset(
        id: "com.hnc.Discord", name: "Discord", bundleIDs: ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary"],
        layout: PrivacyBlurLayout(rail: 72, listEdge: 312, header: 70, listTop: 70, avatar: 56, trailing: 240))
    static let messages = PrivacyBlurPreset(
        id: "com.apple.MobileSMS", name: "Messages", bundleIDs: ["com.apple.MobileSMS"],
        layout: PrivacyBlurLayout(rail: 0, listEdge: 320, header: 52, listTop: 100, avatar: 70))

    /// In the order the page offers them; WhatsApp first, the default.
    static let all: [PrivacyBlurPreset] = [whatsApp, telegram, slack, discord, messages]

    static func named(_ id: String) -> PrivacyBlurPreset? { all.first { $0.id == id } }

    /// The preset a running app's bundle id belongs to.
    static func matching(bundleID: String) -> PrivacyBlurPreset? {
        all.first { $0.bundleIDs.contains(bundleID) }
    }
}

/// The apps the person chose, as stored: a preset's id or a custom app's
/// bundle id, each once, in their order. Nothing stored means WhatsApp.
enum PrivacyBlurApps {
    static let defaultApps = [PrivacyBlurPreset.whatsApp.id]

    static func normalized(_ stored: [String]?) -> [String] {
        guard let stored else { return defaultApps }
        var seen = Set<String>()
        return stored.compactMap { raw in
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            // A preset's other bundle ids fold into its own.
            let canonical = PrivacyBlurPreset.matching(bundleID: id)?.id ?? id
            guard !canonical.isEmpty, seen.insert(canonical).inserted else { return nil }
            return canonical
        }
    }

    /// Whether a running app with `bundleID` is the chosen `app`.
    static func matches(bundleID: String?, app: String) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        if let preset = PrivacyBlurPreset.named(app) { return preset.bundleIDs.contains(bundleID) }
        return bundleID == app
    }

    /// The chosen app a running app's `bundleID` belongs to, if any.
    static func app(for bundleID: String?, in apps: [String]) -> String? {
        apps.first { matches(bundleID: bundleID, app: $0) }
    }

    /// The name the page shows.
    static func name(of app: String, customNames: [String: String]) -> String {
        if let preset = PrivacyBlurPreset.named(app) { return preset.name }
        if let name = customNames[app], !name.isEmpty { return name }
        return app.split(separator: ".").last.map(String.init) ?? app
    }

    /// The layout for `app`, with the person's chat list edge when they moved it.
    static func layout(of app: String, listEdges: [String: Double]) -> PrivacyBlurLayout {
        var layout = PrivacyBlurPreset.named(app)?.layout ?? .generic
        if let edge = listEdges[app], edge.isFinite {
            let range = PrivacyBlurLayout.listEdgeRange
            layout.listEdge = CGFloat(min(range.upperBound, max(range.lowerBound, edge)))
        }
        return layout
    }

    /// The presets the Add menu still offers.
    static func addablePresets(to apps: [String]) -> [PrivacyBlurPreset] {
        PrivacyBlurPreset.all.filter { !apps.contains($0.id) }
    }
}

// MARK: - Regions

/// What a window blurs.
enum PrivacyBlurRegion: String, CaseIterable, Identifiable {
    case everything, chatList, messages, names

    var id: String { rawValue }

    /// The choice as stored, Everything when nothing (or nothing known) is.
    static func choice(_ stored: [String]?) -> Set<PrivacyBlurRegion> {
        let regions = Set((stored ?? []).compactMap(PrivacyBlurRegion.init(rawValue:)))
        if regions.isEmpty || regions.contains(.everything) { return [.everything] }
        return regions
    }

    /// The choice after a tile is pressed: Everything stands alone, the parts
    /// combine, and taking the last part away leaves Everything.
    static func toggled(_ current: Set<PrivacyBlurRegion>, _ tapped: PrivacyBlurRegion) -> Set<PrivacyBlurRegion> {
        if tapped == .everything { return [.everything] }
        var next = current.subtracting([.everything])
        if next.contains(tapped) { next.remove(tapped) } else { next.insert(tapped) }
        return next.isEmpty ? [.everything] : next
    }

    /// For storage, in a fixed order.
    static func stored(_ regions: Set<PrivacyBlurRegion>) -> [String] {
        allCases.filter(regions.contains).map(\.rawValue)
    }
}

/// One blurred part of a window, in the window's own space.
struct PrivacyBlurPiece: Equatable {
    let region: PrivacyBlurRegion
    let rect: CGRect
}

enum PrivacyBlurRegions {
    /// Narrower than the chat list plus this, a chat app shows one column at
    /// a time, so a part can't be told from the rest: the whole window blurs.
    static let compactConversation: CGFloat = 260
    /// Windows smaller than this a side are popovers and tooltips, never chats.
    static let minimumSide: CGFloat = 120

    /// The parts of a window of `size` that `regions` blur. Everything is the
    /// window in two panes (the chat list's column and the rest), so hovering
    /// one reveals it alone. Parts inside another part are dropped, so no
    /// spot blurs twice.
    static func pieces(_ regions: Set<PrivacyBlurRegion>, layout: PrivacyBlurLayout, size: CGSize) -> [PrivacyBlurPiece] {
        let w = size.width, h = size.height
        guard w >= 1, h >= 1 else { return [] }
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        let rail = min(max(0, layout.rail), w / 4)
        let edge = min(max(layout.listEdge, rail + 80), w)
        let compact = w < edge + compactConversation
        let choice = regions.isEmpty ? [.everything] : regions

        if choice.contains(.everything) || compact {
            guard !compact else { return [PrivacyBlurPiece(region: .everything, rect: full)] }
            return [PrivacyBlurPiece(region: .everything, rect: CGRect(x: 0, y: 0, width: edge, height: h)),
                    PrivacyBlurPiece(region: .everything, rect: CGRect(x: edge, y: 0, width: w - edge, height: h))]
        }

        let trailing = min(max(0, layout.trailing), (w - edge) / 2)
        let header = min(max(0, layout.header), h / 3)
        let conversationWidth = w - edge - trailing
        var pieces: [PrivacyBlurPiece] = []
        if choice.contains(.chatList) {
            pieces.append(PrivacyBlurPiece(region: .chatList, rect: CGRect(x: rail, y: 0, width: edge - rail, height: h)))
        }
        if choice.contains(.messages) {
            pieces.append(PrivacyBlurPiece(region: .messages,
                                           rect: CGRect(x: edge, y: header, width: conversationWidth, height: h - header)))
        }
        if choice.contains(.names) {
            if header > 0 {
                pieces.append(PrivacyBlurPiece(region: .names, rect: CGRect(x: edge, y: 0, width: conversationWidth, height: header)))
            }
            let top = min(max(0, layout.listTop), h)
            let avatar = min(max(0, layout.avatar), edge - rail)
            if avatar > 0, top < h {
                pieces.append(PrivacyBlurPiece(region: .names, rect: CGRect(x: rail, y: top, width: avatar, height: h - top)))
            }
            if trailing > 0 {
                pieces.append(PrivacyBlurPiece(region: .names,
                                               rect: CGRect(x: w - trailing, y: header, width: trailing, height: h - header)))
            }
        }
        // A part inside another (the photos inside a blurred chat list) goes.
        return pieces.enumerated().filter { index, piece in
            !pieces.enumerated().contains { other, outer in
                other != index && outer.rect.contains(piece.rect) && (outer.rect != piece.rect || other < index)
            }
        }.map(\.element).filter { $0.rect.width >= 1 && $0.rect.height >= 1 }
    }
}

// MARK: - Revealing

/// What hovering a blurred window shows.
enum PrivacyBlurHover: String, CaseIterable, Identifiable {
    case off
    /// The part under the pointer.
    case region
    /// A soft circle around the pointer.
    case circle

    var id: String { rawValue }
    static let defaultValue = PrivacyBlurHover.region
}

/// The key that reveals every blurred window while it is held alone.
enum PrivacyBlurHoldKey: String, CaseIterable, Identifiable {
    case none, option, control, command

    var id: String { rawValue }

    // The device-independent modifier bits, as NSEvent and CGEvent share them.
    static let shiftMask: UInt = 1 << 17
    static let controlMask: UInt = 1 << 18
    static let optionMask: UInt = 1 << 19
    static let commandMask: UInt = 1 << 20
    static let modifierMask: UInt = shiftMask | controlMask | optionMask | commandMask

    var mask: UInt {
        switch self {
        case .none: return 0
        case .option: return Self.optionMask
        case .control: return Self.controlMask
        case .command: return Self.commandMask
        }
    }

    var symbol: String {
        switch self {
        case .none: return ""
        case .option: return "⌥"
        case .control: return "⌃"
        case .command: return "⌘"
        }
    }

    /// Held, and held alone: ⌥ reveals, ⌥⇧ (a shortcut in progress) doesn't.
    func isHeld(flags: UInt) -> Bool {
        self != .none && flags & Self.modifierMask == mask
    }
}

/// What one overlay shows of its window right now.
enum PrivacyBlurReveal: Equatable {
    case none
    case all
    /// The piece at this index is clear.
    case piece(Int)
    /// A soft circle at this point (the window's space) is clear.
    case circle(CGPoint)
}

enum PrivacyBlurRevealing {
    /// How long typing keeps the focused window clear after the last key.
    static let typingHold: TimeInterval = 1.6
    /// The soft circle's radius, in points.
    static let circleRadius: CGFloat = 90

    /// A key that types, not a shortcut: no ⌘ or ⌃ with it.
    static func countsAsTyping(flags: UInt) -> Bool {
        flags & (PrivacyBlurHoldKey.commandMask | PrivacyBlurHoldKey.controlMask) == 0
    }

    static func isTyping(lastKey: TimeInterval?, now: TimeInterval) -> Bool {
        guard let lastKey else { return false }
        return now >= lastKey && now - lastKey < typingHold
    }

    /// The piece under `point` (the window's space): the smallest one that
    /// holds it, nil outside them all.
    static func piece(at point: CGPoint, in pieces: [PrivacyBlurPiece]) -> Int? {
        pieces.indices.filter { pieces[$0].rect.contains(point) }
            .min { pieces[$0].rect.width * pieces[$0].rect.height < pieces[$1].rect.width * pieces[$1].rect.height }
    }

    /// One overlay's reveal. Holding the key shows every window; typing shows
    /// the app's focused window; otherwise the pointer, when it is over this
    /// window, shows the part or the circle under it.
    static func reveal(hover: PrivacyBlurHover, holding: Bool, typing: Bool, isFocusedWindow: Bool,
                       pointer: CGPoint?, windowSize: CGSize, pieces: [PrivacyBlurPiece]) -> PrivacyBlurReveal {
        if holding { return .all }
        if typing && isFocusedWindow { return .all }
        guard let pointer, CGRect(origin: .zero, size: windowSize).contains(pointer) else { return .none }
        switch hover {
        case .off:
            return .none
        case .region:
            return piece(at: pointer, in: pieces).map(PrivacyBlurReveal.piece) ?? .none
        case .circle:
            let circle = CGRect(x: pointer.x - circleRadius, y: pointer.y - circleRadius,
                                width: circleRadius * 2, height: circleRadius * 2)
            return pieces.contains { $0.rect.intersects(circle) } ? .circle(pointer) : .none
        }
    }

    /// How opaque the frost over the blur is, for a strength of 0…1: always
    /// a little, so the blur reads as frosted glass, up to nearly solid.
    static func frostOpacity(strength: Double) -> Double {
        let s = strength.isFinite ? min(1, max(0, strength)) : PrivacyBlurDefaults.defaultStrength
        return 0.12 + 0.76 * s
    }
}

// MARK: - Windows

/// One on-screen window, as the window server lists it.
struct PrivacyBlurWindow: Equatable {
    let id: CGWindowID
    let pid: pid_t
    /// The window server's space: top left of the main display, y down.
    let frame: CGRect
    let layer: Int
    let alpha: Double
}

enum PrivacyBlurPlacement {
    /// `CGWindowListCopyWindowInfo`'s entries, front to back as listed.
    /// Bounds, owner, number and layer need no permission.
    static func windows(from info: [[String: Any]]) -> [PrivacyBlurWindow] {
        info.compactMap { entry in
            guard let number = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let raw = entry[kCGWindowBounds as String] as? [String: Any],
                  let x = (raw["X"] as? NSNumber)?.doubleValue, let y = (raw["Y"] as? NSNumber)?.doubleValue,
                  let width = (raw["Width"] as? NSNumber)?.doubleValue,
                  let height = (raw["Height"] as? NSNumber)?.doubleValue else { return nil }
            let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            return PrivacyBlurWindow(id: number, pid: pid, frame: CGRect(x: x, y: y, width: width, height: height),
                                     layer: layer, alpha: alpha)
        }
    }

    /// The windows that get an overlay: the chosen apps' ordinary windows
    /// (layer 0, visible, chat-sized), front to back. Menus, popovers and
    /// the apps' floating panels sit on other layers and are left alone.
    static func targets(in windows: [PrivacyBlurWindow], pids: Set<pid_t>) -> [PrivacyBlurWindow] {
        windows.filter { window in
            pids.contains(window.pid) && window.layer == 0 && window.alpha > 0.01
                && window.frame.width >= PrivacyBlurRegions.minimumSide
                && window.frame.height >= PrivacyBlurRegions.minimumSide
        }
    }

    /// The window server's rectangle in AppKit's space (origin at the bottom
    /// left of the main display, y up).
    static func cocoaFrame(_ frame: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: mainDisplayHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// A point in AppKit's space, in a window's own space (top left, y down).
    static func localPoint(_ point: CGPoint, inWindow frame: CGRect, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: (mainDisplayHeight - point.y) - frame.minY)
    }

    /// Whether `overlay` has to be ordered again to sit just above `target`.
    /// It is right when it is in front of the target with nothing between
    /// them but the target app's own windows (its sheets and children, which
    /// the window server keeps on their parent) and Zenith's other overlays.
    /// Another app's window between them, the overlay behind the target, or
    /// the overlay missing from the list means it is out of place.
    static func needsOrdering(overlay: CGWindowID?, target: PrivacyBlurWindow, ownPID: pid_t,
                              in windows: [PrivacyBlurWindow]) -> Bool {
        guard let overlay,
              let overlayIndex = windows.firstIndex(where: { $0.id == overlay }),
              let targetIndex = windows.firstIndex(where: { $0.id == target.id }) else { return true }
        guard overlayIndex < targetIndex else { return true }
        return windows[(overlayIndex + 1)..<targetIndex].contains { $0.pid != target.pid && $0.pid != ownPID }
    }
}

// MARK: - When it blurs

/// When the overlays are up while Privacy Blur is on.
enum PrivacyBlurWhen: String, CaseIterable, Identifiable {
    case always
    /// Only while the screen is shared, mirrored or in presentation mode.
    case whileSharing

    var id: String { rawValue }
}

/// What Zenith can tell about the screen being seen by others.
struct PrivacyBlurSharing: Equatable {
    /// A display mirrors another: a projector, a TV, AirPlay mirroring.
    var mirrored = false
    /// macOS reports a screen watcher: Screen Sharing or a remote session.
    var screenWatched = false
    /// The person said so on the page.
    var presentation = false

    var isSharing: Bool { mirrored || screenWatched || presentation }
}

enum PrivacyBlurActivation {
    /// On by its own rules: the switch, and the sharing condition when asked for.
    static func automatic(enabled: Bool, when: PrivacyBlurWhen, sharing: PrivacyBlurSharing) -> Bool {
        guard enabled else { return false }
        switch when {
        case .always: return true
        case .whileSharing: return sharing.isSharing
        }
    }

    /// The shortcut's override wins until the rules change their mind.
    static func effective(automatic: Bool, override: Bool?) -> Bool { override ?? automatic }

    /// The override after a press of the shortcut: the other state, or none
    /// when the other state is what the rules want anyway.
    static func toggled(automatic: Bool, override: Bool?) -> Bool? {
        let next = !effective(automatic: automatic, override: override)
        return next == automatic ? nil : next
    }

    /// The override after the rules moved from `old` to `new`: a pause or a
    /// manual start lasts until the situation changes (sharing begins or
    /// ends), then the rules lead again.
    static func override(_ override: Bool?, afterAutomatic old: Bool, becomes new: Bool) -> Bool? {
        old == new ? override : nil
    }
}

/// Privacy Blur's preferences, read in one place.
struct PrivacyBlurPreferences: Equatable {
    var enabled: Bool
    var apps: [String]
    var customNames: [String: String]
    var regions: [String: Set<PrivacyBlurRegion>]
    var listEdges: [String: Double]
    var strength: Double
    var hover: PrivacyBlurHover
    var holdKey: PrivacyBlurHoldKey
    var revealWhileTyping: Bool
    var when: PrivacyBlurWhen
    var presentation: Bool

    init(defaults: UserDefaults) {
        enabled = defaults.object(forKey: PrivacyBlurDefaults.enabled) as? Bool ?? false
        apps = PrivacyBlurApps.normalized(defaults.array(forKey: PrivacyBlurDefaults.apps) as? [String])
        customNames = defaults.dictionary(forKey: PrivacyBlurDefaults.customNames) as? [String: String] ?? [:]
        let storedRegions = defaults.dictionary(forKey: PrivacyBlurDefaults.regions) as? [String: [String]] ?? [:]
        regions = Dictionary(uniqueKeysWithValues: apps.map { ($0, PrivacyBlurRegion.choice(storedRegions[$0])) })
        listEdges = defaults.dictionary(forKey: PrivacyBlurDefaults.listWidths) as? [String: Double] ?? [:]
        let strength = defaults.object(forKey: PrivacyBlurDefaults.strength) as? Double ?? PrivacyBlurDefaults.defaultStrength
        self.strength = strength.isFinite ? min(1, max(0, strength)) : PrivacyBlurDefaults.defaultStrength
        hover = PrivacyBlurHover(rawValue: defaults.string(forKey: PrivacyBlurDefaults.hover) ?? "") ?? .defaultValue
        holdKey = PrivacyBlurHoldKey(rawValue: defaults.string(forKey: PrivacyBlurDefaults.holdKey) ?? "") ?? .none
        revealWhileTyping = defaults.object(forKey: PrivacyBlurDefaults.revealWhileTyping) as? Bool ?? false
        when = PrivacyBlurWhen(rawValue: defaults.string(forKey: PrivacyBlurDefaults.when) ?? "") ?? .always
        presentation = defaults.object(forKey: PrivacyBlurDefaults.presentationMode) as? Bool ?? false
    }

    func regions(of app: String) -> Set<PrivacyBlurRegion> { regions[app] ?? [.everything] }

    func layout(of app: String) -> PrivacyBlurLayout { PrivacyBlurApps.layout(of: app, listEdges: listEdges) }
}
