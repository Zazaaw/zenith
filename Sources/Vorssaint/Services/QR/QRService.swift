// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

// Zenith fork: the QR codes' entry points. A code of what the clipboard holds
// (a global shortcut, the island's clipboard cards, the home widget, the
// Command Bar), a new one from scratch, and a code read off the screen
// through the screen text tool's own capture. Main thread only, like the
// services it drives; nothing runs in the background between uses.

final class QRService: ObservableObject {
    static let shared = QRService()

    /// The last codes made, newest first (QRHistory, in a registered default).
    @Published private(set) var history: [String]
    /// The shortcuts macOS refused (taken by another app).
    @Published private(set) var shortcutFailed = false
    @Published private(set) var scanShortcutFailed = false

    // Past the hand-assigned quick tool ids, the radial menu's 1700s and the
    // workspaces' 1800s.
    private let makeHotkey = QuickToolHotkey(id: 1900)
    private let scanHotkey = QuickToolHotkey(id: 1901)
    private let cache = NSCache<NSString, QRMatrixBox>()
    private var defaultsObserver: NSObjectProtocol?

    private init() {
        history = QRHistory.load()
        makeHotkey.onPress = { [weak self] in self?.showClipboard() }
        scanHotkey.onPress = { [weak self] in self?.scanScreen() }
        // A backup restored, or the list cleared from another window.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                  object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let stored = QRHistory.load()
            if stored != self.history { self.history = stored }
        }
    }

    var text: ZenithQRStrings { ZenithStrings.qr(L10n.shared.language) }

    /// Scanning borrows the screen text tool's capture, so it follows that tool.
    var canScan: Bool { GlobalShortcutRole.zenithQRScan.isAvailable(using: { $0.isAvailable }) }

    // MARK: Shortcuts

    /// Registers both shortcuts as their switches and features say; called by
    /// FeatureRuntime for the clipboard and the screen text tool, at launch
    /// and when a shortcut field stops recording.
    func syncWithPreferences() {
        let defaults = UserDefaults.standard
        let make = GlobalShortcutRole.zenithQR
        let makeOn = make.isAvailable(using: { $0.isAvailable }) && make.requiredEnableKeys.allSatisfy { defaults.bool(forKey: $0) }
        shortcutFailed = !makeHotkey.sync(enabled: makeOn, shortcut: make.savedShortcut, storageKey: make.storageKey)
        let scan = GlobalShortcutRole.zenithQRScan
        let scanOn = scan.isAvailable(using: { $0.isAvailable }) && scan.requiredEnableKeys.allSatisfy { defaults.bool(forKey: $0) }
        scanShortcutFailed = !scanHotkey.sync(enabled: scanOn, shortcut: scan.savedShortcut, storageKey: scan.storageKey)
    }

    // MARK: Making codes

    /// A code of what the clipboard holds now, or a short note when it holds
    /// nothing a code is made of. The read runs on the pasteboard's own lane.
    func showClipboard() {
        GeneralPasteboardAccess.shared.async(timeout: 1.5, { _ in
            NSPasteboard.general.string(forType: .string)
        }, then: { [weak self] value in
            guard let self else { return }
            guard let value, let content = QRDetector.detect(value) else {
                QuickToolHUD.show(icon: "qrcode", message: self.text.noClipboard)
                return
            }
            self.show(content)
        })
    }

    /// A code of a clipboard entry's text (the island's QR action).
    func show(text value: String) {
        guard let content = QRDetector.detect(value) else { return }
        show(content)
    }

    func show(_ content: QRContent) {
        QRPanelController.shared.show(content)
    }

    /// The QR page with nothing in it yet, on the link field.
    func newCode() {
        QRPanelController.shared.show(nil)
    }

    /// Keeps a code's text for the QR page's list.
    func record(_ payload: String) {
        let list = QRHistory.adding(payload, to: history)
        guard list != history else { return }
        history = list
        UserDefaults.standard.set(list, forKey: DefaultsKey.zenithQRHistory)
    }

    func forget(_ payload: String) {
        history = QRHistory.remove(payload)
    }

    func clearHistory() {
        QRHistory.clear()
        history = []
    }

    /// The modules for a payload at the current settings, kept for the
    /// panel, the widget and the island so typing does not make the same
    /// code twice. Nil when the payload is too long for the level.
    func matrix(_ payload: String, correction: QRCorrection) -> QRMatrix? {
        let key = "\(correction.rawValue)\u{0}\(payload)" as NSString
        if let box = cache.object(forKey: key) { return box.matrix }
        guard let matrix = QRMatrix.make(payload, correction: correction) else { return nil }
        cache.setObject(QRMatrixBox(matrix), forKey: key)
        return matrix
    }

    // MARK: Scanning

    /// Opens the capture chooser on the text tool; the picked area is read
    /// for codes off the main thread and the result card shows what they hold.
    func scanScreen() {
        guard canScan else { return }
        let text = self.text
        ScreenCaptureService.shared.zenithCaptureImage { image in
            DispatchQueue.global(qos: .userInitiated).async {
                let payloads = QRScanner.read(image)
                DispatchQueue.main.async {
                    if payloads.isEmpty {
                        QuickToolHUD.show(icon: "qrcode.viewfinder", message: text.scanNone)
                    } else {
                        QRScanResultController.shared.show(payloads)
                    }
                }
            }
        }
    }
}

final class QRMatrixBox {
    let matrix: QRMatrix
    init(_ matrix: QRMatrix) { self.matrix = matrix }
}
