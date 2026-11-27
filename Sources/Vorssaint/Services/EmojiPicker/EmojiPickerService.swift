// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

// Zenith fork: the Emoji Picker's entry points. The shortcut (or the Command
// Bar's row) opens the floating panel over the app in front; Return pastes
// the chosen emoji there through the transient paste, which puts the
// clipboard back after. Off, nothing is registered or observed: no hotkey,
// no observer, and the list is not even read.

final class EmojiPickerService: ObservableObject {
    static let shared = EmojiPickerService()

    // E for emoji, on the four-modifier layer: ⌃⌥⌘E opens the latest capture.
    static let defaultShortcut = GlobalShortcut(keyCode: Int64(kVK_ANSI_E),
                                                modifiers: [.control, .option, .shift, .command])
    // Past Remove Background's 2700.
    private static let hotkeyID: UInt32 = 2710

    @Published private(set) var shortcutRefused = false

    private let hotkey = QuickToolHotkey(id: EmojiPickerService.hotkeyID)
    private var captureObserver: NSObjectProtocol?
    /// The app the picker opened over, which gets the emoji.
    private var target: pid_t?

    private init() {
        hotkey.onPress = { [weak self] in self?.toggle() }
    }

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: EmojiPickerDefaults.enabled)
    }

    static func launch() {
        guard isEnabled() else { return }
        shared.syncWithPreferences()
    }

    static func savedShortcut(_ defaults: UserDefaults = .standard) -> GlobalShortcut? {
        guard let raw = defaults.string(forKey: EmojiPickerDefaults.shortcut) else { return defaultShortcut }
        if raw.isEmpty { return nil }
        return GlobalShortcut(storageValue: raw) ?? defaultShortcut
    }

    /// The page's switch. Turning it on asks for Accessibility, which the
    /// paste into another app needs, the first time.
    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: EmojiPickerDefaults.enabled)
        if on, !AXIsProcessTrusted() { Permissions.shared.requestAccessibility() }
        syncWithPreferences()
    }

    func syncWithPreferences() {
        guard Self.isEnabled() else {
            hotkey.unregister()
            if let captureObserver { NotificationCenter.default.removeObserver(captureObserver) }
            captureObserver = nil
            if shortcutRefused { shortcutRefused = false }
            MainActor.assumeIsolated { EmojiPickerPanelController.shared.close() }
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
        let refused = !hotkey.sync(enabled: true, shortcut: shortcut, storageKey: EmojiPickerDefaults.shortcut)
        if refused != shortcutRefused { shortcutRefused = refused }
    }

    func conflict(for shortcut: GlobalShortcut) -> String? {
        GlobalShortcutRole.conflict(for: shortcut, excluding: nil)?.title(L10n.shared.s)
    }

    // MARK: The panel

    func toggle() {
        guard Self.isEnabled() else { return }
        MainActor.assumeIsolated {
            let panel = EmojiPickerPanelController.shared
            if panel.isOpen { return panel.close() }
            open()
        }
    }

    /// Opens over the app in front, which keeps its key window underneath.
    func open() {
        guard Self.isEnabled() else { return }
        let front = NSWorkspace.shared.frontmostApplication
        target = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front?.processIdentifier
        let preferences = EmojiPickerPreferences()
        let usage = EmojiUsage(data: UserDefaults.standard.data(forKey: EmojiPickerDefaults.usage))
        MainActor.assumeIsolated {
            EmojiPickerPanelController.shared.show(EmojiPickerModel(records: EmojiCatalog.shared, usage: usage,
                                                                    preferences: preferences))
        }
    }

    /// Return or a click: remembers the pick, closes, and pastes the emoji
    /// into the app the picker opened over.
    func insert(_ emoji: String, base: String) {
        var usage = EmojiUsage(data: UserDefaults.standard.data(forKey: EmojiPickerDefaults.usage))
        usage.record(base)
        UserDefaults.standard.set(usage.data, forKey: EmojiPickerDefaults.usage)
        MainActor.assumeIsolated { EmojiPickerPanelController.shared.close() }
        let target = self.target
        self.target = nil
        // A beat, so the app below has its key window back before the paste.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard let target, NSWorkspace.shared.frontmostApplication?.processIdentifier == target,
                  AXIsProcessTrusted() else {
                return Self.copyInstead(emoji)
            }
            if !TransientPaste.shared.paste(emoji, didFail: { Self.copyInstead(emoji) }) { Self.copyInstead(emoji) }
        }
    }

    /// No app to paste into, or no Accessibility: the emoji goes on the clipboard.
    private static func copyInstead(_ emoji: String) {
        GeneralPasteboardAccess.shared.async({ () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareVorssaintSource()
            return pasteboard.setString(emoji, forType: .string)
        }, then: { ok in
            if ok { QuickToolHUD.show(icon: "face.smiling", message: "\(emoji)  Copied") } else { NSSound.beep() }
        })
    }

    func clearUsage() {
        UserDefaults.standard.removeObject(forKey: EmojiPickerDefaults.usage)
    }

    func openSettings() {
        SettingsRouter.shared.request(FeatureSettingsDestination(.emojiPicker, sectionAnchor: .zenithEmojiPicker))
        appDelegate()?.openSettingsWindow()
    }
}
