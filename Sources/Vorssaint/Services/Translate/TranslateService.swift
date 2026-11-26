// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

// Zenith fork: Translate's entry points. The shortcut reads what the app in
// front has selected (Accessibility first; where an app doesn't share it, a
// ⌘C whose clipboard is put back right after) and opens the card; the
// Command Bar translates the clipboard. Off, nothing is registered or
// observed: no hotkey, no observer, no polling. Main thread only, like the
// services it drives.

/// A pair the card could not translate before its languages are downloaded,
/// handed to the Settings page, which asks the system to download them.
struct TranslateDownloadRequest: Equatable {
    let from: String?
    let to: String
}

final class TranslateService: ObservableObject {
    static let shared = TranslateService()

    // T for Translate, on the four-modifier layer: ⌃⌥⌘T is the screen
    // text tool's already.
    static let defaultShortcut = GlobalShortcut(keyCode: Int64(kVK_ANSI_T),
                                                modifiers: [.control, .option, .shift, .command])
    // Past the QR codes' 1900s and the teleprompter's 1950.
    private static let hotkeyID: UInt32 = 2450

    /// macOS refused the combination (taken by another app).
    @Published private(set) var shortcutRefused = false
    /// A download the card asked for, until the Settings page starts it.
    @Published var pendingDownload: TranslateDownloadRequest?

    private let hotkey = QuickToolHotkey(id: TranslateService.hotkeyID)
    private var captureObserver: NSObjectProtocol?
    /// A press is being read (or copied); a second one waits for it.
    private var reading = false

    private init() {
        hotkey.onPress = { [weak self] in self?.translateSelection() }
    }

    private var text: ZenithTranslateStrings { ZenithStrings.translate(L10n.shared.language) }

    static var isSupported: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        isSupported && defaults.bool(forKey: TranslateDefaults.enabled)
    }

    /// At launch: only a Translate that is on comes to life.
    static func launch() {
        guard isEnabled() else { return }
        shared.syncWithPreferences()
    }

    /// The combination the shortcut answers to, nil when it was cleared.
    static func savedShortcut(_ defaults: UserDefaults = .standard) -> GlobalShortcut? {
        guard let raw = defaults.string(forKey: TranslateDefaults.shortcut) else { return defaultShortcut }
        if raw.isEmpty { return nil }
        return GlobalShortcut(storageValue: raw) ?? defaultShortcut
    }

    // MARK: Shortcut

    /// Registers the shortcut while Translate is on, and lets go of it and
    /// of everything else when it is off. Called at launch, by the Settings
    /// page and after a shortcut field stops recording.
    func syncWithPreferences() {
        guard Self.isEnabled() else {
            hotkey.unregister()
            if let captureObserver { NotificationCenter.default.removeObserver(captureObserver) }
            captureObserver = nil
            if shortcutRefused { shortcutRefused = false }
            if #available(macOS 15.0, *) { MainActor.assumeIsolated { TranslateCardController.shared.close() } }
            return
        }
        if captureObserver == nil {
            // Recording any shortcut field releases every quick tool key; this
            // brings Translate's back when it ends.
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
        let refused = !hotkey.sync(enabled: true, shortcut: shortcut, storageKey: TranslateDefaults.shortcut)
        if refused != shortcutRefused { shortcutRefused = refused }
    }

    /// Who already answers to a combination, or nil when it is free.
    func conflict(for shortcut: GlobalShortcut) -> String? {
        GlobalShortcutRole.conflict(for: shortcut, excluding: nil)?.title(L10n.shared.s)
    }

    // MARK: Translating

    /// The shortcut: what the app in front has selected.
    func translateSelection() {
        guard Self.isEnabled(), #available(macOS 15.0, *), !reading else { return }
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            showMessage(text.nothingSelected)
            return
        }
        guard AXIsProcessTrusted() else {
            MainActor.assumeIsolated { TranslateCardController.shared.showAccessibilityNeeded() }
            return
        }
        reading = true
        let pid = front.processIdentifier
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let selection = SelectedTextReader.read(processID: pid)
            DispatchQueue.main.async {
                guard let self else { return }
                if let selection, let prepared = TranslateText.prepare(selection.text) {
                    self.reading = false
                    self.present(prepared, origin: .selection(pid, replaceable: !selection.fromTextMarkers))
                } else {
                    self.copySelection(from: pid)
                }
            }
        }
    }

    /// The Command Bar's row: what the clipboard holds.
    func translateClipboard() {
        guard Self.isEnabled(), #available(macOS 15.0, *) else { return }
        GeneralPasteboardAccess.shared.async(timeout: 1.5, { _ in
            NSPasteboard.general.string(forType: .string)
        }, then: { [weak self] value in
            guard let self else { return }
            guard let value, let prepared = TranslateText.prepare(value) else {
                self.showMessage(self.text.clipboardEmpty)
                return
            }
            self.present(prepared, origin: .clipboard)
        })
    }

    /// The card's Download button: Settings → Translate, which asks the
    /// system to download the pair in a window that can show its prompt.
    func requestDownload(from: String?, to: String) {
        pendingDownload = TranslateDownloadRequest(from: from, to: to)
        openSettings(anchor: .zenithTranslateDownloads)
    }

    func openSettings(anchor: SettingsSectionAnchor = .zenithTranslate) {
        SettingsRouter.shared.request(FeatureSettingsDestination(.translate, sectionAnchor: anchor))
        appDelegate()?.openSettingsWindow()
    }

    private func present(_ prepared: TranslateText.Prepared, origin: TranslateOrigin) {
        guard #available(macOS 15.0, *) else { return }
        let preferences = TranslatePreferences.read()
        MainActor.assumeIsolated {
            TranslateCardController.shared.show(TranslateCardModel(prepared: prepared, origin: origin,
                                                                   preferences: preferences))
        }
    }

    private func showMessage(_ message: String) {
        guard #available(macOS 15.0, *) else { return }
        MainActor.assumeIsolated { TranslateCardController.shared.show(TranslateCardModel(message: message)) }
    }

    // MARK: Copy fallback

    /// For apps that don't tell Accessibility what is selected: keep the
    /// clipboard, press ⌘C for the person, read what it copied and put the
    /// clipboard back, unless they copied something else in the meantime.
    /// When the clipboard can't be kept whole, nothing is copied at all.
    private func copySelection(from pid: pid_t) {
        GeneralPasteboardAccess.shared.async({ () -> (Int, TranslateClipboardSnapshot?) in
            let pasteboard = NSPasteboard.general
            return (pasteboard.changeCount, TranslateClipboardSnapshot.take(from: pasteboard))
        }, then: { [weak self] before, snapshot in
            guard let self else { return }
            guard let snapshot else { return self.finishReading(nil, pid: pid) }
            self.ignoreInHistory(upTo: before + 2)
            Self.postCopyWhenModifiersReleased(attempt: 0) { posted in
                guard posted else { return self.finishReading(nil, pid: pid) }
                self.waitForCopy(before: before, snapshot: snapshot, pid: pid, attempt: 0)
            }
        })
    }

    /// Up to about half a second for the app to answer the copy; one read
    /// per step, and none once it has.
    private func waitForCopy(before: Int, snapshot: TranslateClipboardSnapshot, pid: pid_t, attempt: Int) {
        GeneralPasteboardAccess.shared.async({ () -> (Int, String?) in
            let pasteboard = NSPasteboard.general
            let count = pasteboard.changeCount
            return (count, count != before ? pasteboard.string(forType: .string) : nil)
        }, then: { [weak self] after, string in
            guard let self else { return }
            guard after != before else {
                guard attempt < 15 else { return self.finishReading(nil, pid: pid) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    self.waitForCopy(before: before, snapshot: snapshot, pid: pid, attempt: attempt + 1)
                }
                return
            }
            self.ignoreInHistory(upTo: after)
            let copied = TranslateClipboard.copiedText(changeCountBefore: before, changeCountAfter: after, string: string)
            GeneralPasteboardAccess.shared.async({
                TranslateClipboard.restore(snapshot, to: NSPasteboard.general, ifUnchangedSince: after)
            }, then: { restored in
                if let restored { self.ignoreInHistory(upTo: restored) }
                self.finishReading(copied, pid: pid)
            })
        })
    }

    private func finishReading(_ copied: String?, pid: pid_t) {
        reading = false
        guard let copied, let prepared = TranslateText.prepare(copied) else {
            showMessage(text.nothingSelected)
            return
        }
        present(prepared, origin: .selection(pid, replaceable: true))
    }

    /// The copy and the clipboard put back never reach the clipboard
    /// history, which only listens while it is on.
    private func ignoreInHistory(upTo changeCount: Int) {
        guard AppFeature.clipboardHistory.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.clipboardHistoryEnabled) else { return }
        ClipboardHistoryService.shared.ignoreNextChange(upTo: changeCount)
    }

    /// ⌘C posted while the shortcut's modifiers are still held would arrive
    /// as another combination, so wait for a clean keyboard first (15 ms
    /// steps, about 1.5 s at most). A password field takes no copy.
    private static func postCopyWhenModifiersReleased(attempt: Int, completion: @escaping (Bool) -> Void) {
        let held = CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        guard held.isEmpty else {
            guard attempt < 100 else { return completion(false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                postCopyWhenModifiersReleased(attempt: attempt + 1, completion: completion)
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            guard !IsSecureEventInputEnabled(),
                  let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
            else { return completion(false) }
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            completion(true)
        }
    }
}

/// Where the text came from, which decides whether Replace is offered.
enum TranslateOrigin: Equatable {
    /// A selection in the app with this process; `replaceable` is false for
    /// a web page read through text markers, where a paste lands elsewhere.
    case selection(pid_t, replaceable: Bool)
    case clipboard
}
