// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices
import Carbon.HIToolbox

// Zenith fork: the ways a reply leaves the island, one per app. Each channel
// works off the main thread and reports on it. None of them logs or keeps
// the text: it lives in the call and, when a step fails, in the app's own
// composer or on the clipboard where the person can still use it.

protocol ZenithReplyChannel {
    /// Delivers the reply and calls back once, on the main thread.
    func send(_ text: String, to target: ZenithReplyTarget, completion: @escaping (ZenithReplyOutcome) -> Void)
}

enum ZenithReplyChannels {
    static func channel(for app: ZenithReplyApp) -> ZenithReplyChannel {
        switch app {
        case .messages: return ZenithMessagesReplyChannel()
        case .whatsApp: return ZenithWhatsAppReplyChannel()
        }
    }

    /// Whether WhatsApp replies drive WhatsApp's window. On by default.
    static var sendsWhatsAppAutomatically: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.notchWhatsAppAutoReply) as? Bool ?? true
    }
}

/// Puts a reply on the clipboard for the person to paste. It is marked as
/// private, so clipboard histories (this app's included) leave it out.
enum ZenithReplyPasteboard {
    static func copy(_ text: String) {
        GeneralPasteboardAccess.shared.async({ () -> Int? in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(text, forType: .string) else { return nil }
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardHistorySensitiveText.concealedPasteboardType))
            return pasteboard.changeCount
        }) { changeCount in
            if let changeCount { ClipboardHistoryService.shared.ignoreNextChange(upTo: changeCount) }
        }
    }
}

// MARK: - Messages

/// Messages answers AppleScript: the chat is found from the notification's
/// sender, and the reply goes to that chat. Needs Automation for Messages.
struct ZenithMessagesReplyChannel: ZenithReplyChannel {
    /// One script at a time; NSAppleScript stays on this queue.
    static let queue = DispatchQueue(label: "com.satuvisual.zenith.reply.messages", qos: .userInitiated)

    func send(_ text: String, to target: ZenithReplyTarget, completion: @escaping (ZenithReplyOutcome) -> Void) {
        Self.queue.async {
            let outcome = Self.deliver(text, sender: target.sender)
            DispatchQueue.main.async {
                if case .opened = outcome { Self.handOff(text, target: target) }
                completion(outcome)
            }
        }
    }

    private static func deliver(_ text: String, sender: String) -> ZenithReplyOutcome {
        let listing = run(ZenithAppleScript.messagesChatsScript())
        guard listing.error == nil, let output = listing.output else {
            return ZenithReplyFallback.messages(errorNumber: listing.error ?? 0)
        }
        let resolution = ZenithMessagesChats.resolve(sender: sender, in: ZenithMessagesChats.parse(output))
        guard let recipient = ZenithReplyFallback.messages(resolution: resolution) else {
            return .opened(prefilled: false, copied: true)
        }
        let sending = run(ZenithAppleScript.messagesSendScript(text: text, to: recipient))
        return ZenithReplyFallback.messages(errorNumber: sending.error)
    }

    /// Runs a script and returns its text or its error number. The error's
    /// message is never read: it can quote the script, and so the reply.
    private static func run(_ source: String) -> (output: String?, error: Int?) {
        guard let script = NSAppleScript(source: source) else { return (nil, 0) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error { return (nil, (error[NSAppleScript.errorNumber] as? Int) ?? 0) }
        return (result.stringValue ?? "", nil)
    }

    /// The conversation opens from its notification, or Messages itself
    /// opens, and the reply waits on the clipboard.
    private static func handOff(_ text: String, target: ZenithReplyTarget) {
        ZenithReplyPasteboard.copy(text)
        NotchNotificationService.shared.open(target.notificationID) { result in
            guard result == .unavailable || result == .uncertain else { return }
            ZenithWhatsAppReplyChannel.openApplication(target.bundleIdentifier)
        }
    }
}

// MARK: - WhatsApp

/// WhatsApp has no scripting. With the setting on, the reply is typed into
/// WhatsApp's own window through Accessibility: open the chat (its link for a
/// phone number, otherwise WhatsApp's search), put the text in the composer,
/// press Return, and go back to the app that was in front. Every step is
/// checked, and a step that cannot be confirmed stops there, leaving WhatsApp
/// open with the reply in its composer or on the clipboard.
struct ZenithWhatsAppReplyChannel: ZenithReplyChannel {
    static let queue = DispatchQueue(label: "com.satuvisual.zenith.reply.whatsapp", qos: .userInitiated)

    func send(_ text: String, to target: ZenithReplyTarget, completion: @escaping (ZenithReplyOutcome) -> Void) {
        let plan = ZenithWhatsAppPlan.decide(sender: target.sender, text: text,
                                             automatic: ZenithReplyChannels.sendsWhatsAppAutomatically,
                                             accessibility: AXIsProcessTrusted())
        switch plan {
        case .needsAccessibility:
            completion(.needsPermission(.accessibility))
        case .openPrefilled(let url):
            Self.open(url, bundleIdentifier: target.bundleIdentifier)
            completion(.opened(prefilled: true, copied: false))
        case .openAndCopy:
            ZenithReplyPasteboard.copy(text)
            Self.openApplication(target.bundleIdentifier)
            completion(.opened(prefilled: false, copied: true))
        case .automate(let route):
            let previous = NSWorkspace.shared.frontmostApplication
            Self.queue.async {
                let automation = ZenithWhatsAppAutomation(bundleIdentifier: target.bundleIdentifier, text: text,
                                                          sender: target.sender)
                let stopped = automation.run(route)
                DispatchQueue.main.async {
                    guard let stage = stopped else {
                        if let previous, previous.bundleIdentifier != target.bundleIdentifier, !previous.isTerminated {
                            previous.activate()
                        }
                        completion(.sent)
                        return
                    }
                    let outcome = ZenithReplyFallback.whatsApp(after: stage, route: route)
                    if case .opened(_, let copied) = outcome, copied { ZenithReplyPasteboard.copy(text) }
                    // A stop before the chat opened leaves WhatsApp where it
                    // was; the link still opens the right chat with the text.
                    if case .link(let url) = route, stage == .launching || stage == .openingChat {
                        Self.open(url, bundleIdentifier: target.bundleIdentifier)
                    } else {
                        Self.openApplication(target.bundleIdentifier)
                    }
                    completion(outcome)
                }
            }
        }
    }

    static func applicationURL(_ bundleIdentifier: String) -> URL? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              Bundle(url: url)?.bundleIdentifier == bundleIdentifier else { return nil }
        return url
    }

    static func openApplication(_ bundleIdentifier: String) {
        guard let url = applicationURL(bundleIdentifier) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
    }

    static func open(_ link: URL, bundleIdentifier: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let app = applicationURL(bundleIdentifier) {
            NSWorkspace.shared.open([link], withApplicationAt: app, configuration: configuration) { _, _ in }
        } else {
            NSWorkspace.shared.open(link)
        }
    }
}

/// One automated reply, run on the WhatsApp queue. Returns nil once Return
/// has sent the reply, or the stage it stopped at.
private final class ZenithWhatsAppAutomation {
    private let bundleIdentifier: String
    private let text: String
    private let sender: String
    private let deadline = Date().addingTimeInterval(15)
    private var pid: pid_t = 0
    private var application: AXUIElement?

    init(bundleIdentifier: String, text: String, sender: String) {
        self.bundleIdentifier = bundleIdentifier
        self.text = text
        self.sender = sender
    }

    func run(_ route: ZenithWhatsAppPlan.Route) -> ZenithWhatsAppStage? {
        guard launch() else { return .launching }
        let composer: AXUIElement
        switch route {
        case .link(let url):
            onMain { ZenithWhatsAppReplyChannel.open(url, bundleIdentifier: self.bundleIdentifier) }
            // The link opens the number's chat with the reply already typed.
            guard waitForFront(timeout: 4),
                  let found = wait(timeout: 5, { self.composer(containing: self.text) }) else { return .openingChat }
            composer = found
        case .search(let name):
            guard let window = focusedWindow(), openChat(named: name, in: window),
                  let found = wait(timeout: 3, { self.composer(containing: nil) }) else { return .openingChat }
            guard place(text, in: found) else { return .placingText }
            composer = found
        }
        if pressReturnAndConfirm(composer) { return nil }
        // The text may have been set without WhatsApp noticing it; typed in
        // through a paste it is, so try once more that way.
        guard set(composer, value: ""), paste(text, into: composer), contains(composer, text),
              pressReturnAndConfirm(composer) else { return .sending }
        return nil
    }

    // MARK: Steps

    private func launch() -> Bool {
        var running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        if running == nil {
            onMain { ZenithWhatsAppReplyChannel.openApplication(self.bundleIdentifier) }
            running = wait(timeout: 8) {
                NSRunningApplication.runningApplications(withBundleIdentifier: self.bundleIdentifier).first
                    .flatMap { $0.isFinishedLaunching ? $0 : nil }
            }
        }
        guard let app = running else { return false }
        pid = app.processIdentifier
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.5)
        application = element
        onMain { _ = app.activate() }
        return waitForFront(timeout: 3) && wait(timeout: 4, { self.focusedWindow() }) != nil
    }

    /// WhatsApp's search: put the name in, then open the first chat the list
    /// shows for it. The chat must name the same person to count as open.
    private func openChat(named name: String, in window: AXUIElement) -> Bool {
        var field = descendants(of: window, limit: 1) { ZenithAX.subrole($0) == "AXSearchField" }.first
        if field == nil {
            // Command-F moves to the search field in WhatsApp.
            guard key(CGKeyCode(kVK_ANSI_F), flags: .maskCommand) else { return false }
            field = wait(timeout: 1.5) {
                guard let focused = ZenithAX.element(self.application, kAXFocusedUIElementAttribute) else { return nil }
                return ["AXTextField", "AXTextArea", "AXSearchField"].contains(ZenithAX.role(focused) ?? "") ? focused : nil
            }
        }
        guard let field else { return false }
        _ = ZenithAX.setFocused(field)
        if !(set(field, value: name) && contains(field, name)) {
            guard key(CGKeyCode(kVK_ANSI_A), flags: .maskCommand), paste(name, into: field), contains(field, name) else {
                return false
            }
        }
        let target = ZenithReplySender.normalizedName(name)
        let fieldFrame = ZenithAX.frame(field) ?? .zero
        // Results under the search field, in reading order, labelled with the name.
        let result = wait(timeout: 3) { () -> AXUIElement? in
            self.descendants(of: window, limit: 1) { element in
                guard !CFEqual(element, field), let frame = ZenithAX.frame(element),
                      frame.minY >= fieldFrame.maxY - 2, frame.minX < fieldFrame.maxX + 40 else { return false }
                return ZenithAX.labels(element).contains { ZenithReplySender.normalizedName($0) == target }
            }.first
        }
        if let result {
            let pressable = ZenithAX.pressableAncestor(of: result) ?? result
            if !ZenithAX.press(pressable) { _ = ZenithAX.setSelected(pressable) }
        } else {
            // The list may not label its rows; the first result is chosen
            // the way the keyboard does, and is then checked like any other.
            guard key(CGKeyCode(kVK_DownArrow), flags: []), key(CGKeyCode(kVK_Return), flags: []) else { return false }
        }
        // The conversation's header, beside the list, names the chat.
        return wait(timeout: 3) { () -> Bool? in
            let header = self.descendants(of: window, limit: 1) { element in
                guard let frame = ZenithAX.frame(element), frame.minX >= fieldFrame.maxX - 2 else { return false }
                return ZenithAX.labels(element).contains { ZenithReplySender.normalizedName($0) == target }
            }
            return header.isEmpty ? nil : true
        } ?? false
    }

    /// The conversation's composer: an editable text area that is not the
    /// search field, the lowest in the window.
    private func composer(containing text: String?) -> AXUIElement? {
        guard let window = focusedWindow() else { return nil }
        let areas = descendants(of: window, limit: 8) { element in
            ZenithAX.role(element) == "AXTextArea" && ZenithAX.subrole(element) != "AXSearchField"
                && ZenithAX.isEnabled(element)
        }
        let lowest = areas.max { (ZenithAX.frame($0)?.maxY ?? 0) < (ZenithAX.frame($1)?.maxY ?? 0) }
        guard let lowest else { return nil }
        if let text, !contains(lowest, text) { return nil }
        return lowest
    }

    private func place(_ text: String, in composer: AXUIElement) -> Bool {
        _ = ZenithAX.setFocused(composer)
        if set(composer, value: text), contains(composer, text) { return true }
        return paste(text, into: composer) && contains(composer, text)
    }

    /// Return sends in WhatsApp. Sent means the composer let go of the text.
    private func pressReturnAndConfirm(_ composer: AXUIElement) -> Bool {
        _ = ZenithAX.setFocused(composer)
        guard key(CGKeyCode(kVK_Return), flags: []) else { return false }
        return wait(timeout: 2) { self.contains(composer, self.text) ? nil : true } ?? false
    }

    // MARK: Helpers

    private func focusedWindow() -> AXUIElement? {
        ZenithAX.element(application, kAXFocusedWindowAttribute)
            ?? ZenithAX.element(application, kAXMainWindowAttribute)
    }

    private func set(_ element: AXUIElement, value: String) -> Bool {
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFString) == .success
    }

    private func contains(_ element: AXUIElement, _ text: String) -> Bool {
        guard let value = ZenithAX.string(element, kAXValueAttribute) else { return false }
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !wanted.isEmpty && value.replacingOccurrences(of: "\r", with: "\n").contains(wanted)
    }

    /// Pastes through the clipboard, which is put back afterwards.
    private func paste(_ text: String, into element: AXUIElement) -> Bool {
        guard isFront(), Date() < deadline else { return false }
        _ = ZenithAX.setFocused(element)
        let done = DispatchSemaphore(value: 0)
        var posted = false
        DispatchQueue.main.async {
            let started = TransientPaste.shared.paste(text, didPostShortcut: { posted = true; done.signal() },
                                                     didFail: { done.signal() })
            if !started { done.signal() }
        }
        guard done.wait(timeout: .now() + 3) == .success, posted else { return false }
        return wait(timeout: 1) { self.contains(element, text) ? true : nil } ?? false
    }

    /// Keys go only to WhatsApp, and only while it is in front.
    private func key(_ code: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard isFront(), Date() < deadline,
              let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return false }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        usleep(30_000)
        up.post(tap: .cghidEventTap)
        usleep(120_000)
        return true
    }

    private func isFront() -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    }

    private func waitForFront(timeout: TimeInterval) -> Bool {
        wait(timeout: timeout) { self.isFront() ? true : nil } ?? false
    }

    private func wait<T>(timeout: TimeInterval, _ probe: () -> T?) -> T? {
        let end = min(deadline, Date().addingTimeInterval(timeout))
        repeat {
            if let value = probe() { return value }
            usleep(100_000)
        } while Date() < end
        return probe()
    }

    private func descendants(of root: AXUIElement, limit: Int,
                             where matches: (AXUIElement) -> Bool) -> [AXUIElement] {
        ZenithAX.search(root, limit: limit, budget: 3_000, where: matches)
    }

    private func onMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
}

/// Thin Accessibility reads and writes with short timeouts. A failed call
/// reads as missing; nothing here throws or logs.
enum ZenithAX {
    static func value(_ element: AXUIElement?, _ attribute: String) -> CFTypeRef? {
        guard let element else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.5)
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    static func element(_ element: AXUIElement?, _ attribute: String) -> AXUIElement? {
        guard let value = value(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    static func role(_ element: AXUIElement) -> String? { string(element, kAXRoleAttribute) }
    static func subrole(_ element: AXUIElement) -> String? { string(element, kAXSubroleAttribute) }

    static func isEnabled(_ element: AXUIElement) -> Bool {
        (value(element, kAXEnabledAttribute) as? Bool) ?? true
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    /// What an element says it is called, in the attributes apps use.
    static func labels(_ element: AXUIElement) -> [String] {
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute].compactMap { string(element, $0) }
            .filter { !$0.isEmpty && $0.utf8.count <= 512 }
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), let size = value(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &origin),
              AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    static func actions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    static func press(_ element: AXUIElement) -> Bool {
        actions(element).contains(kAXPressAction)
            && AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    static func setFocused(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    }

    static func setSelected(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXSelectedAttribute as CFString, kCFBooleanTrue) == .success
    }

    /// The nearest element that opens on a press: a row, a cell or a button.
    static func pressableAncestor(of element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0..<6 {
            guard let candidate = current else { return nil }
            if actions(candidate).contains(kAXPressAction)
                || ["AXRow", "AXCell", "AXButton"].contains(role(candidate) ?? "") { return candidate }
            current = self.element(candidate, kAXParentAttribute)
        }
        return nil
    }

    /// Breadth-first, so results come in the order a window lays them out
    /// from the top, within a budget of elements visited.
    static func search(_ root: AXUIElement, limit: Int, budget: Int,
                       where matches: (AXUIElement) -> Bool) -> [AXUIElement] {
        var queue = [root]
        var index = 0
        var found: [AXUIElement] = []
        while index < queue.count, index < budget, found.count < limit {
            let element = queue[index]
            index += 1
            if matches(element) { found.append(element) }
            queue += children(element)
        }
        return found
    }
}
