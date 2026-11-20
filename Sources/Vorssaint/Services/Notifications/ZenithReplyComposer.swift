// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

/// Zenith fork: the reply row's state. One row is open at a time, on the held
/// preview or on the island's notifications page. Drafts and the replies sent
/// live only in memory, for as long as their notification stays in the inbox.
final class ZenithReplyComposer: ObservableObject {
    static let shared = ZenithReplyComposer()

    enum Surface: Equatable { case preview, page }

    /// What the message line shows after a reply.
    enum Status: Equatable {
        case sent(String, at: Date)
        /// Automatic sending stopped and the app was opened instead; `attempted`
        /// is false when the setting asked for that in the first place.
        case opened(app: String, prefilled: Bool, copied: Bool, attempted: Bool)
        case needsPermission(ZenithReplyPermission)
        case failed
    }

    @Published private(set) var openID: UUID?
    @Published private(set) var surface: Surface?
    @Published private(set) var drafts: [UUID: String] = [:]
    @Published private(set) var sendingID: UUID?
    @Published private(set) var statuses: [UUID: Status] = [:]
    /// Bumped to put the caret back in the open field.
    @Published private(set) var focusRequest = 0

    private var inboxSubscription: AnyCancellable?
    private var clickMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    /// A reply that drove another app hands the front back to the one before;
    /// that activation is not the person leaving.
    private var ignoresActivationUntil = Date.distantPast

    private init() {
        inboxSubscription = NotchNotificationService.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.trim() }
    }

    // MARK: Reading

    func target(for item: NotchSystemNotification) -> ZenithReplyTarget? {
        let service = NotchNotificationService.shared
        guard let identifier = service.sourceBundleIdentifier(for: item.id),
              let app = ZenithReplyApp(bundleIdentifier: identifier) else { return nil }
        let sender = ZenithReplySender.stripped(item.content.title)
        guard !sender.isEmpty else { return nil }
        return ZenithReplyTarget(notificationID: item.id, app: app, bundleIdentifier: identifier,
                                 appName: item.content.app.isEmpty ? app.displayName : item.content.app,
                                 sender: sender)
    }

    func isOpen(_ id: UUID, on surface: Surface) -> Bool { openID == id && self.surface == surface }

    func draft(for id: UUID) -> String { drafts[id] ?? "" }

    func setDraft(_ text: String, for id: UUID) {
        drafts[id] = text.isEmpty ? nil : text
    }

    // MARK: Opening and closing

    func open(_ item: NotchSystemNotification, on surface: Surface) {
        guard target(for: item) != nil else { return }
        if openID != nil, openID != item.id || self.surface != surface { close() }
        openID = item.id
        self.surface = surface
        ZenithReplyHold.notificationID = item.id
        ZenithReplyHold.previewExtraHeight = 0
        takeKeyboard()
        focusRequest += 1
        if surface == .page {
            NotchService.shared.setPageLayer(.notifications) { [weak self] in self?.close() }
        } else {
            fitPreview()
        }
        watchForLeaving()
    }

    func toggle(_ item: NotchSystemNotification, on surface: Surface) {
        isOpen(item.id, on: surface) ? close() : open(item, on: surface)
    }

    /// Esc, a click elsewhere, or the notification leaving. The draft stays
    /// for a reopening, in memory.
    func close() {
        guard let surface = self.surface else { return }
        openID = nil
        self.surface = nil
        ZenithReplyHold.notificationID = nil
        ZenithReplyHold.previewExtraHeight = 0
        stopWatchingForLeaving()
        switch surface {
        case .page:
            NotchService.shared.setPageLayer(.notifications, close: nil)
        case .preview:
            NotchService.shared.refreshPresentation()
            releaseKeyboard()
        }
        // The island no longer holds on for the row: a pointer that left
        // while writing now closes it as usual.
        DispatchQueue.main.async { NotchService.shared.hover(false) }
    }

    /// The row's view went away with its surface: a new banner took the
    /// preview, or the island closed.
    func surfaceDisappeared(_ id: UUID, _ surface: Surface) {
        guard openID == id, self.surface == surface else { return }
        close()
    }

    // MARK: Sending

    func send(_ item: NotchSystemNotification) {
        guard sendingID == nil, let target = target(for: item),
              let text = ZenithReplyDraft.sendable(draft(for: item.id)) else { return }
        sendingID = item.id
        let attempted = target.app == .messages || ZenithReplyChannels.sendsWhatsAppAutomatically
        ZenithReplyChannels.channel(for: target.app).send(text, to: target) { [weak self] outcome in
            guard let self else { return }
            self.sendingID = nil
            self.ignoresActivationUntil = Date().addingTimeInterval(1.5)
            switch outcome {
            case .sent:
                self.drafts[item.id] = nil
                self.statuses[item.id] = .sent(text, at: Date())
                self.focusRequest += 1
            case .opened(let prefilled, let copied):
                // The reply now waits in the app or on the clipboard.
                self.drafts[item.id] = nil
                self.statuses[item.id] = .opened(app: target.appName, prefilled: prefilled, copied: copied,
                                                 attempted: attempted)
            case .needsPermission(let permission):
                self.statuses[item.id] = .needsPermission(permission)
            case .failed:
                self.statuses[item.id] = .failed
            }
            if self.openID == item.id, self.surface == .preview { self.fitPreview() }
        }
    }

    /// The words the message line shows for a status.
    static func message(for status: Status, language: AppLanguage) -> String {
        let text = ZenithStrings.reply(language)
        switch status {
        case .sent(let reply, _):
            return text.you.replacingOccurrences(of: "%@", with: reply)
        case .opened(let app, let prefilled, _, let attempted):
            let format = attempted ? (prefilled ? text.openedPrefilled : text.openedCopied)
                : (prefilled ? text.handOffPrefilled : text.handOffCopied)
            return format.replacingOccurrences(of: "%@", with: app)
        case .needsPermission(.automation): return text.needsAutomation
        case .needsPermission(.accessibility): return text.needsAccessibility
        case .failed: return text.failed
        }
    }

    /// The held preview grows by the row, and by whatever a status needs
    /// beyond the message it stands in for, measured as the preview draws it.
    private func fitPreview() {
        guard surface == .preview, let id = openID else { return }
        var extra = ZenithReplyHold.rowSpacing + ZenithReplyHold.rowHeight
        if let status = statuses[id], let item = NotchNotificationService.shared.items.first(where: { $0.id == id }) {
            typealias Layout = NotchNotificationPreviewLayout
            let width = NotchService.shared.geometry.notificationPreviewContentWidth
            let shown = Layout.textHeight(Self.message(for: status, language: L10n.shared.language),
                                          font: Layout.bodyFont, lines: Layout.bodyLines, width: width)
            let body = Layout.textHeight(item.content.body, font: Layout.bodyFont, lines: Layout.bodyLines, width: width)
            extra += max(0, shown - body) + (body == 0 ? Layout.spacing : 0)
        }
        guard ZenithReplyHold.previewExtraHeight != extra else { return }
        ZenithReplyHold.previewExtraHeight = extra
        NotchService.shared.refreshPresentation()
    }

    func grantAccess(_ permission: ZenithReplyPermission, for id: UUID) {
        statuses[id] = nil
        switch permission {
        case .automation: Permissions.shared.openAutomationSettings()
        case .accessibility: Permissions.shared.requestAccessibility()
        }
    }

    // MARK: Keyboard

    /// The island is a panel that never activates Zenith; it takes the
    /// keyboard the way the Command Bar in it does, and gives it back.
    private func takeKeyboard() {
        guard let panel = NotchService.shared.presentationWindow as? NotchPanel else { return }
        panel.acceptsKeyFocus = true
        panel.makeKey()
    }

    private func releaseKeyboard() {
        guard !NotchService.shared.expanded,
              let panel = NotchService.shared.presentationWindow as? NotchPanel else { return }
        panel.acceptsKeyFocus = false
        NotchService.shared.resignPanelKey()
    }

    /// The open island closes on a click elsewhere by itself; a held preview
    /// does not, so its row watches for one, and for another app coming
    /// forward. A reply on its way to WhatsApp brings WhatsApp forward itself.
    private func watchForLeaving() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.surface == .preview else { return }
            self.close()
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.sendingID == nil, Date() > self.ignoresActivationUntil,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier
                else { return }
                self.close()
            }
    }

    private func stopWatchingForLeaving() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
    }

    /// Drafts and replies leave with their notification.
    private func trim() {
        let ids = Set(NotchNotificationService.shared.items.map(\.id))
        if let openID, !ids.contains(openID) { close() }
        let draftsLeft = drafts.filter { ids.contains($0.key) }
        if draftsLeft.count != drafts.count { drafts = draftsLeft }
        let statusesLeft = statuses.filter { ids.contains($0.key) || $0.key == sendingID }
        if statusesLeft.count != statuses.count { statuses = statusesLeft }
    }
}
