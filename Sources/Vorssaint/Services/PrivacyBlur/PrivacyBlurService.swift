// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

// Zenith fork: Privacy Blur's state on the main thread. It follows the
// preferences (Settings → Privacy Blur, a restored backup), decides whether
// the blur is up (always, or while the screen is shared, with the shortcut's
// override on top) and starts or stops the tracker. Off, nothing runs: no
// observer, no monitor, no timer, no hotkey.

@MainActor
final class PrivacyBlurService: ObservableObject {
    static let shared = PrivacyBlurService()

    // P for privacy, on the four-modifier layer: ⌃⌥⌘P opens a copied image.
    static let defaultShortcut = GlobalShortcut(keyCode: Int64(kVK_ANSI_P),
                                                modifiers: [.control, .option, .shift, .command])
    // Past the Emoji Picker's 2710, with room between.
    private static let hotkeyID: UInt32 = 2760
    /// While the blur waits for a share, how often the screen watcher is asked.
    static let sharingInterval: TimeInterval = 2

    @Published private(set) var shortcutRefused = false
    @Published private(set) var sharing = PrivacyBlurSharing()
    /// The shortcut's pause (false) or manual start (true), until the rules change.
    @Published private(set) var override: Bool?
    @Published private(set) var isBlurring = false
    @Published private(set) var trusted = false

    private let tracker = PrivacyBlurTracker()
    private let hotkey = QuickToolHotkey(id: PrivacyBlurService.hotkeyID)
    private var observers: [NSObjectProtocol] = []
    private var sharingTimer: Timer?
    private var applied: PrivacyBlurPreferences?
    private var lastAutomatic = false
    private var registeredShortcut: String?

    private init() {
        hotkey.onPress = { [weak self] in MainActor.assumeIsolated { self?.toggleFromShortcut() } }
    }

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: PrivacyBlurDefaults.enabled)
    }

    /// At launch: only a Privacy Blur that is on comes to life.
    static func launch() {
        guard isEnabled(), !ZenithQuiet.isOn else { return }
        shared.syncWithPreferences()
    }

    static func savedShortcut(_ defaults: UserDefaults = .standard) -> GlobalShortcut? {
        guard let raw = defaults.string(forKey: PrivacyBlurDefaults.shortcut) else { return defaultShortcut }
        if raw.isEmpty { return nil }
        return GlobalShortcut(storageValue: raw) ?? defaultShortcut
    }

    /// The page's switch. Turning it on asks for Accessibility, which lets
    /// the panes follow their windows as they move, the first time.
    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: PrivacyBlurDefaults.enabled)
        if on, !ZenithQuiet.isOn, !AXIsProcessTrusted() { Permissions.shared.requestAccessibility() }
        syncWithPreferences()
    }

    /// Applies the preferences; cheap when nothing changed, as it runs on
    /// every defaults change.
    func syncWithPreferences() {
        // Zenith fork: tests and the catalog never draw an overlay or observe an app.
        guard !ZenithQuiet.isOn else { return shutDown() }
        let preferences = PrivacyBlurPreferences(defaults: .standard)
        guard preferences.enabled else { return shutDown() }
        installObservers()
        syncShortcut()
        refreshTrust()
        guard preferences != applied else { return }
        applied = preferences
        sharing.presentation = preferences.presentation
        if preferences.when == .whileSharing { readSharing() }
        syncSharingTimer(preferences)
        apply()
    }

    private func shutDown() {
        tracker.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        sharingTimer?.invalidate()
        sharingTimer = nil
        hotkey.unregister()
        registeredShortcut = nil
        applied = nil
        if shortcutRefused { shortcutRefused = false }
        if override != nil { override = nil }
        if isBlurring { isBlurring = false }
        lastAutomatic = false
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // A restored backup, another window or the page changed a preference.
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
            [weak self] _ in MainActor.assumeIsolated { self?.syncWithPreferences() }
        })
        // Coming back from System Settings, where Accessibility is granted.
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTrust() }
        })
        observers.append(center.addObserver(forName: .zenithShortcutCaptureEnded, object: nil, queue: .main) {
            [weak self] _ in MainActor.assumeIsolated { self?.syncShortcut(force: true) }
        })
        // A display starting or stopping to mirror.
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sharingMayHaveChanged() }
        })
    }

    private func refreshTrust() {
        let now = AXIsProcessTrusted()
        guard now != trusted else { return }
        trusted = now
        tracker.accessibilityChanged()
    }

    // MARK: Whether it blurs

    private func apply() {
        guard let preferences = applied else { return }
        let automatic = PrivacyBlurActivation.automatic(enabled: preferences.enabled, when: preferences.when,
                                                        sharing: sharing)
        let nextOverride = PrivacyBlurActivation.override(override, afterAutomatic: lastAutomatic, becomes: automatic)
        if nextOverride != override { override = nextOverride }
        lastAutomatic = automatic
        let active = PrivacyBlurActivation.effective(automatic: automatic, override: override)
        if active != isBlurring { isBlurring = active }
        if active { tracker.start(preferences) } else { tracker.stop() }
    }

    func toggleFromShortcut() {
        guard applied != nil else { return }
        override = PrivacyBlurActivation.toggled(automatic: lastAutomatic, override: override)
        apply()
    }

    // MARK: Sharing

    private func syncSharingTimer(_ preferences: PrivacyBlurPreferences) {
        let wanted = preferences.when == .whileSharing
        if wanted, sharingTimer == nil {
            let timer = Timer(timeInterval: Self.sharingInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sharingMayHaveChanged() }
            }
            timer.tolerance = Self.sharingInterval * 0.5
            RunLoop.main.add(timer, forMode: .common)
            sharingTimer = timer
        } else if !wanted {
            sharingTimer?.invalidate()
            sharingTimer = nil
        }
    }

    private func sharingMayHaveChanged() {
        guard applied?.when == .whileSharing else { return }
        let before = sharing
        readSharing()
        if sharing != before { apply() }
    }

    private func readSharing() {
        var next = sharing
        next.mirrored = PrivacyBlurScreenState.anyDisplayMirrored()
        next.screenWatched = PrivacyBlurScreenState.screenWatcherPresent()
        if next != sharing { sharing = next }
    }

    // MARK: Shortcut

    func syncShortcut(force: Bool = false) {
        let raw = UserDefaults.standard.string(forKey: PrivacyBlurDefaults.shortcut)
            ?? Self.defaultShortcut.storageValue
        guard force || raw != registeredShortcut else { return }
        registeredShortcut = raw
        guard let shortcut = Self.savedShortcut() else {
            hotkey.unregister()
            if shortcutRefused { shortcutRefused = false }
            return
        }
        let refused = !hotkey.sync(enabled: true, shortcut: shortcut, storageKey: PrivacyBlurDefaults.shortcut)
        if refused != shortcutRefused { shortcutRefused = refused }
    }

    func conflict(for shortcut: GlobalShortcut) -> String? {
        GlobalShortcutRole.conflict(for: shortcut, excluding: nil)?.title(L10n.shared.s)
    }
}

/// What the system says about other people seeing the screen. Mirroring is
/// public API; the screen watcher is the window server's own flag, read
/// through `dlsym` so a macOS without it simply reports none.
enum PrivacyBlurScreenState {
    static func anyDisplayMirrored() -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsInMirrorSet($0) != 0 }
    }

    private typealias WatcherPresent = @convention(c) () -> Bool
    private static let watcherPresent: WatcherPresent? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2) /* RTLD_DEFAULT */,
                                 "CGSIsScreenWatcherPresent") else { return nil }
        return unsafeBitCast(symbol, to: WatcherPresent.self)
    }()

    static func screenWatcherPresent() -> Bool { watcherPresent?() ?? false }
}
