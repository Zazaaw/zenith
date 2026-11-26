// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Mechakey plays the keyboard sound packs of Mechvibes by Hải Nguyễn (MIT),
// https://github.com/hainguyents13/mechvibes — see the notice in About.

import AppKit
import Combine
import Foundation

// Zenith fork: Mechakey's state on the main thread. It follows the
// preferences (Settings → Mechakey, a restored backup, the shortcut) and
// Input Monitoring, and tells the player what to do. Off by default; while
// off, only the optional toggle shortcut is registered.

final class MechakeyService: ObservableObject {
    static let shared = MechakeyService()
    /// The quick tools' hotkey ids are small numbers; workspaces take 1800 and up.
    private static let hotkeyID: UInt32 = 2600

    typealias Access = FaceUnlockSpaceKeyMonitor.Access

    @Published private(set) var access: Access = FaceUnlockSpaceKeyMonitor.access
    /// Mechakey is on and its key tap could not be made.
    @Published private(set) var tapFailed = false
    @Published private(set) var shortcutRefused = false
    /// The pack whose preview is playing.
    @Published private(set) var previewingPackID: String?

    private let player = MechakeyPlayer()
    private let hotkey = QuickToolHotkey(id: MechakeyService.hotkeyID)
    private var observers: [NSObjectProtocol] = []
    private var registeredShortcut: String?
    private var started = false

    private init() {
        hotkey.onPress = { [weak self] in self?.toggleFromShortcut() }
        player.onTapFailure = { [weak self] in
            guard let self else { return }
            tapFailed = true
            access = FaceUnlockSpaceKeyMonitor.access
            sync() // nothing to play without the tap: the engine goes too
        }
        player.onPreviewEnded = { [weak self] in self?.previewingPackID = nil }
    }

    /// At launch: the shortcut, and the sounds when Mechakey is on.
    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        // A restored backup, the shortcut or another window changed a preference.
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
            [weak self] _ in self?.sync()
        })
        // Coming back from System Settings, where Input Monitoring is granted.
        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil,
                                            queue: .main) { [weak self] _ in self?.refreshAccess() })
        observers.append(center.addObserver(forName: .zenithShortcutCaptureEnded, object: nil, queue: .main) {
            [weak self] _ in self?.syncShortcut(force: true)
        })
        refreshAccess()
    }

    private var preferences: MechakeyPreferences { MechakeyPreferences(defaults: .standard) }

    /// Applies the preferences; cheap when nothing changed, as it runs on
    /// every defaults change. Input Monitoring is read again only by
    /// `refreshAccess`, not here.
    func sync() {
        let preferences = preferences
        syncShortcut()
        guard preferences.enabled else {
            if tapFailed { tapFailed = false }
            player.apply(nil)
            return
        }
        player.apply(access == .granted && !tapFailed ? preferences.playback : nil)
    }

    /// Reads Input Monitoring again: at launch, coming back to Zenith, and
    /// after the prompt. A grant clears an earlier failed tap, for a retry.
    func refreshAccess() {
        let current = FaceUnlockSpaceKeyMonitor.access
        if current != access { access = current }
        if current == .granted, tapFailed {
            tapFailed = false
            player.apply(nil)
        }
        sync()
    }

    /// The page's switch and the shortcut. Turning it on asks for Input
    /// Monitoring the first time; macOS shows its prompt at most once.
    func setEnabled(_ on: Bool) {
        if on, FaceUnlockSpaceKeyMonitor.access == .notDetermined {
            FaceUnlockSpaceKeyMonitor.requestAccess()
            // The answer lands just after the call returns.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refreshAccess() }
        }
        UserDefaults.standard.set(on, forKey: MechakeyDefaults.enabled)
        refreshAccess()
    }

    private func toggleFromShortcut() {
        setEnabled(!preferences.enabled)
    }

    func preview(_ pack: MechakeyPack) {
        let preferences = preferences
        previewingPackID = pack.id
        player.preview(pack, volume: Float(preferences.volume), keyUpSounds: preferences.keyUpSounds)
    }

    // MARK: Shortcut

    func syncShortcut(force: Bool = false) {
        let raw = UserDefaults.standard.string(forKey: MechakeyDefaults.shortcut) ?? ""
        guard force || raw != registeredShortcut else { return }
        registeredShortcut = raw
        guard let shortcut = GlobalShortcut(storageValue: raw) else {
            hotkey.unregister()
            if shortcutRefused { shortcutRefused = false }
            return
        }
        let refused = !hotkey.sync(enabled: true, shortcut: shortcut, storageKey: MechakeyDefaults.shortcut)
        if refused != shortcutRefused { shortcutRefused = refused }
    }

    /// Who already answers to a combination, or nil when it is free.
    func conflict(for shortcut: GlobalShortcut) -> String? {
        GlobalShortcutRole.conflict(for: shortcut, excluding: nil)?.title(L10n.shared.s)
    }
}
