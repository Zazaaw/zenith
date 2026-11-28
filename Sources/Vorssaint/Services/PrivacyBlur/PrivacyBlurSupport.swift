// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: Privacy Blur's decisions, without windows, observers or event
// monitors, so the tests reach every one: the preferences, the chat apps and
// how each one blurs, what the pointer reveals and how fast, which on-screen
// windows get an overlay and when one has to be ordered again, and when the
// blur is on at all. What a window's items are (chat rows, bubbles, names,
// photos) is decided in PrivacyBlurItems.swift.
//
// Geometry is in the window server's space (origin at the top left of the
// main display, y down). A window's items are in its own space (origin at
// its top left, y down), which is also the overlay view's flipped space.

/// Privacy Blur's preferences. Kept here, not in `DefaultsKey`, so the
/// feature's files never edit a shared registry.
enum PrivacyBlurDefaults {
    static let enabled = "zenithPrivacyBlurEnabled"                 // Bool, default false
    static let apps = "zenithPrivacyBlurApps"                       // [String] app ids, default [WhatsApp]
    static let customNames = "zenithPrivacyBlurCustomNames"         // [String: String] bundle id → name
    static let modes = "zenithPrivacyBlurModes"                     // [String: String] app id → PrivacyBlurMode
    static let strength = "zenithPrivacyBlurStrength"               // Double 0...1, default 0.6
    // What the item mode blurs, as the browser extension's options: all on but "No transition delay".
    static let messages = "zenithPrivacyBlurMessages"               // Bool, default true
    static let previews = "zenithPrivacyBlurPreviews"               // Bool, default true
    static let media = "zenithPrivacyBlurMedia"                     // Bool, default true
    static let avatars = "zenithPrivacyBlurAvatars"                 // Bool, default true
    static let names = "zenithPrivacyBlurNames"                     // Bool, default true
    static let input = "zenithPrivacyBlurInput"                     // Bool, default true
    static let hoverReveal = "zenithPrivacyBlurHoverReveal"         // Bool, default true
    static let noDelay = "zenithPrivacyBlurNoDelay"                 // Bool, default false
    static let holdKey = "zenithPrivacyBlurHoldKey"                 // PrivacyBlurHoldKey, default .none
    static let revealWhileTyping = "zenithPrivacyBlurRevealTyping"  // Bool, default false
    static let when = "zenithPrivacyBlurWhen"                       // PrivacyBlurWhen, default .always
    static let presentationMode = "zenithPrivacyBlurPresentation"   // Bool, default false (not backed up)
    static let shortcut = "zenithPrivacyBlurShortcut"               // GlobalShortcut.storageValue, "" for none
    /// The first version's hover menu ("off", "region", "circle"), read so
    /// a person who had turned hovering off keeps it off.
    static let legacyHover = "zenithPrivacyBlurHover"

    /// What the settings backup carries. Presentation mode is the state of
    /// one talk on one Mac, so it stays out.
    static let backupKeys: Set<String> = [enabled, apps, customNames, modes, strength, messages, previews, media,
                                          avatars, names, input, hoverReveal, noDelay, holdKey, revealWhileTyping,
                                          when, shortcut]
    static let defaultStrength = 0.6
}

// MARK: - Apps

/// How Zenith finds the items in an app's window.
enum PrivacyBlurItemSupport: Equatable {
    /// Rules made for the app from its Accessibility tree's shape (WhatsApp).
    case tuned
    /// Every text block, picture and text field the tree shows, without
    /// knowing the app. Unverified, so the app starts on the whole window.
    case generic
}

/// A chat app Privacy Blur knows: its name, the bundle ids it ships under
/// and how its items are found.
struct PrivacyBlurPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIDs: [String]
    let items: PrivacyBlurItemSupport

    static let whatsApp = PrivacyBlurPreset(
        id: "net.whatsapp.WhatsApp", name: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp", "desktop.WhatsApp"],
        items: .tuned)
    static let telegram = PrivacyBlurPreset(
        id: "ru.keepcoder.Telegram", name: "Telegram",
        bundleIDs: ["ru.keepcoder.Telegram", "com.tdesktop.Telegram", "org.telegram.desktop"], items: .generic)
    static let slack = PrivacyBlurPreset(
        id: "com.tinyspeck.slackmacgap", name: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"], items: .generic)
    static let discord = PrivacyBlurPreset(
        id: "com.hnc.Discord", name: "Discord", bundleIDs: ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary"],
        items: .generic)
    static let messages = PrivacyBlurPreset(
        id: "com.apple.MobileSMS", name: "Messages", bundleIDs: ["com.apple.MobileSMS"], items: .generic)

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

    /// How the app's items are found: a preset's own rules, the generic ones otherwise.
    static func support(of app: String) -> PrivacyBlurItemSupport {
        PrivacyBlurPreset.named(app)?.items ?? .generic
    }

    /// The presets the Add menu still offers.
    static func addablePresets(to apps: [String]) -> [PrivacyBlurPreset] {
        PrivacyBlurPreset.all.filter { !apps.contains($0.id) }
    }
}

// MARK: - Modes

/// How an app's windows blur.
enum PrivacyBlurMode: String, CaseIterable, Identifiable {
    /// Each chat row's photo, name and preview, each bubble, the open
    /// chat's name and photo and the typing field, on their own.
    case items
    /// One pane over the whole window. Also what the item mode falls back
    /// to while it can't find the items (no Accessibility, a layout it
    /// doesn't recognise).
    case window

    var id: String { rawValue }

    /// The app's mode as stored, or its default: items for an app with
    /// rules of its own, the whole window for the rest.
    static func of(_ app: String, stored: [String: String]) -> PrivacyBlurMode {
        if let raw = stored[app], let mode = PrivacyBlurMode(rawValue: raw) { return mode }
        return PrivacyBlurApps.support(of: app) == .tuned ? .items : .window
    }
}

// MARK: - Revealing

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
    /// The item at this index is clear.
    case item(Int)
    /// A soft circle at this point (the window's space) is clear: hovering
    /// a window blurred whole.
    case circle(CGPoint)
}

/// How a reveal fades in and out.
struct PrivacyBlurTransition: Equatable {
    /// How long the pointer rests on an item before it clears.
    var delay: TimeInterval
    var fadeIn: TimeInterval
    var fadeOut: TimeInterval

    /// The rest before an item clears, as the extension has it.
    static let restingDelay: TimeInterval = 0.3

    /// A short rest before an item clears, unless "No transition delay" is
    /// on. Reduce Motion keeps the rest but drops the fades. Blurring again
    /// never waits.
    static func timing(noDelay: Bool, reduceMotion: Bool) -> PrivacyBlurTransition {
        let delay = noDelay ? 0 : restingDelay
        if reduceMotion { return PrivacyBlurTransition(delay: delay, fadeIn: 0, fadeOut: 0) }
        return PrivacyBlurTransition(delay: delay, fadeIn: noDelay ? 0 : 0.16, fadeOut: noDelay ? 0.1 : 0.2)
    }

    /// Whether going from `current` to `next` waits for the rest: only an
    /// item (or the circle) coming clear under the pointer. Holding the key,
    /// typing, blurring again, the circle following the pointer and the
    /// revealed item moving (a scroll, a read) are at once.
    static func waits(from current: PrivacyBlurReveal, to next: PrivacyBlurReveal) -> Bool {
        switch (current, next) {
        case (_, .none), (_, .all), (.circle, .circle): return false
        default: return current != next
        }
    }
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

    /// One overlay's reveal. Holding the key shows every window; typing shows
    /// the app's focused window; otherwise, when hovering reveals, the
    /// pointer shows the item under it, or a circle around it on a window
    /// blurred whole.
    static func reveal(hoverReveal: Bool, holding: Bool, typing: Bool, isFocusedWindow: Bool,
                       pointer: CGPoint?, windowSize: CGSize, items: [PrivacyBlurItem]) -> PrivacyBlurReveal {
        if holding { return .all }
        if typing && isFocusedWindow { return .all }
        guard hoverReveal, let pointer, CGRect(origin: .zero, size: windowSize).contains(pointer),
              let index = PrivacyBlurItems.item(at: pointer, in: items) else { return .none }
        return items[index].kind == .window ? .circle(pointer) : .item(index)
    }

    /// Whether two items are the same one, moved a little (a scroll, a new
    /// read): the same kind, mostly overlapping.
    static func sameItem(_ a: PrivacyBlurItem, _ b: PrivacyBlurItem) -> Bool {
        guard a.kind == b.kind else { return false }
        let overlap = a.rect.intersection(b.rect)
        guard !overlap.isNull else { return false }
        let smaller = min(a.rect.width * a.rect.height, b.rect.width * b.rect.height)
        return smaller > 0 && overlap.width * overlap.height >= smaller * 0.6
    }

    /// The reveal after the items changed: an item revealed before stays
    /// revealed at its new index, or nothing is when it went.
    static func remap(_ reveal: PrivacyBlurReveal, from old: [PrivacyBlurItem], to new: [PrivacyBlurItem]) -> PrivacyBlurReveal {
        guard case .item(let index) = reveal else { return reveal }
        guard old.indices.contains(index) else { return .none }
        if new.indices.contains(index), sameItem(old[index], new[index]) { return reveal }
        return new.firstIndex { sameItem(old[index], $0) }.map(PrivacyBlurReveal.item) ?? .none
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

/// Kept for callers of the first version: the smallest chat window.
enum PrivacyBlurRegions {
    static let minimumSide = PrivacyBlurPlacement.minimumSide
}

enum PrivacyBlurPlacement {
    /// Windows smaller than this a side are popovers and tooltips, never chats.
    static let minimumSide: CGFloat = 120

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
                && window.frame.width >= minimumSide && window.frame.height >= minimumSide
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
    var modes: [String: PrivacyBlurMode]
    var options: PrivacyBlurItemOptions
    var strength: Double
    var holdKey: PrivacyBlurHoldKey
    var revealWhileTyping: Bool
    var when: PrivacyBlurWhen
    var presentation: Bool

    init(defaults: UserDefaults) {
        func bool(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        enabled = bool(PrivacyBlurDefaults.enabled, false)
        apps = PrivacyBlurApps.normalized(defaults.array(forKey: PrivacyBlurDefaults.apps) as? [String])
        customNames = defaults.dictionary(forKey: PrivacyBlurDefaults.customNames) as? [String: String] ?? [:]
        let storedModes = defaults.dictionary(forKey: PrivacyBlurDefaults.modes) as? [String: String] ?? [:]
        modes = Dictionary(uniqueKeysWithValues: apps.map { ($0, PrivacyBlurMode.of($0, stored: storedModes)) })
        let hoveringWasOff = defaults.string(forKey: PrivacyBlurDefaults.legacyHover) == "off"
        options = PrivacyBlurItemOptions(messages: bool(PrivacyBlurDefaults.messages, true),
                                         previews: bool(PrivacyBlurDefaults.previews, true),
                                         media: bool(PrivacyBlurDefaults.media, true),
                                         avatars: bool(PrivacyBlurDefaults.avatars, true),
                                         names: bool(PrivacyBlurDefaults.names, true),
                                         input: bool(PrivacyBlurDefaults.input, true),
                                         hoverReveal: bool(PrivacyBlurDefaults.hoverReveal, !hoveringWasOff),
                                         noDelay: bool(PrivacyBlurDefaults.noDelay, false))
        let strength = defaults.object(forKey: PrivacyBlurDefaults.strength) as? Double ?? PrivacyBlurDefaults.defaultStrength
        self.strength = strength.isFinite ? min(1, max(0, strength)) : PrivacyBlurDefaults.defaultStrength
        holdKey = PrivacyBlurHoldKey(rawValue: defaults.string(forKey: PrivacyBlurDefaults.holdKey) ?? "") ?? .none
        revealWhileTyping = bool(PrivacyBlurDefaults.revealWhileTyping, false)
        when = PrivacyBlurWhen(rawValue: defaults.string(forKey: PrivacyBlurDefaults.when) ?? "") ?? .always
        presentation = bool(PrivacyBlurDefaults.presentationMode, false)
    }

    func mode(of app: String) -> PrivacyBlurMode { modes[app] ?? PrivacyBlurMode.of(app, stored: [:]) }
}
