// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices

// Zenith fork: Privacy Blur at work. While the blur is up it watches only
// the chosen apps.
//
// Windows: an Accessibility observer per running app tells it when a window
// moves, resizes, appears, closes, minimises or takes focus, and the
// workspace tells it when an app opens, quits, hides, comes forward or the
// Space changes. Each of those reads the window server's list once (bounds
// and order need no permission) and puts a pane just above every visible
// chat window, then closes the panes whose window left the screen. Without
// Accessibility the same refresh runs on a slow timer.
//
// Items: for an app blurred item by item, each window's Accessibility tree
// is read off the main thread (PrivacyBlurContentReader: roles and frames,
// never text) and its items found (PrivacyBlurItems). A window is read
// whole when its pane appears or resizes, when the app says its content
// changed (value, layout, focus, elements created or destroyed), after a
// click in it (a chat switch), and twice a second while the app is
// frontmost, for what no notification told. Reads are coalesced: one at a
// time per window, at most every `readInterval`. While the pointer is over
// a chat window a scroll-wheel monitor is up: each wheel event moves the
// scrolled area's items at once by the wheel's delta (so the blur stays on
// its bubble), and that area alone is read again, up to 60 times a second,
// to put them where the app has them. Whole reads wait until the scroll
// ends. Nothing runs while the blur is off or no chat window is on screen.
//
// For other features that want to follow windows (App Lock): the
// tracker's surface is `start(_:)`, `stop()`, `accessibilityChanged()`,
// `refresh()`, `isRunning` and `overlayCount`; `PrivacyBlurPlacement`
// (window list, targets, flipping, ordering) and `PrivacyBlurAppWatch`
// (window notifications per app; `contentEvents: true` adds the content
// ones) can be used on their own. Their signatures are kept as they were.

@MainActor
final class PrivacyBlurTracker {
    /// Without Accessibility, how often the window list is read.
    static let fallbackInterval: TimeInterval = 0.5
    /// While a mouse button is held on a blurred window: a drag or a click
    /// that brings it forward. Ends when the button comes up.
    static let pressInterval: TimeInterval = 1.0 / 60
    /// While a chosen app blurred item by item is frontmost, how often its
    /// windows are read whole for changes no notification told (2 Hz).
    static let contentInterval: TimeInterval = 0.5
    /// The soonest a window is read whole again.
    static let readInterval: TimeInterval = 0.15
    /// While it scrolls, the soonest the scrolled area is read again (60 Hz).
    static let scrollReadInterval: TimeInterval = 1.0 / 60
    /// A scroll is over this long after its last wheel event.
    static let scrollIdle: TimeInterval = 0.18

    private var preferences: PrivacyBlurPreferences?
    private var watches: [pid_t: PrivacyBlurAppWatch] = [:]
    /// The chosen app each watched process belongs to.
    private var appByPID: [pid_t: String] = [:]
    private var overlays: [CGWindowID: PrivacyBlurOverlay] = [:]
    /// The panes' windows, front to back, as last listed.
    private var order: [PrivacyBlurWindow] = []
    private var contents: [CGWindowID: PrivacyBlurWindowContent] = [:]
    private var reader: PrivacyBlurContentReader?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private var pointerMonitors: [Any] = []
    private var keyMonitors: [Any] = []
    private var scrollMonitor: Any?
    private var fallbackTimer: Timer?
    private var contentTimer: Timer?
    private var pressTimer: Timer?
    private var typingTimer: Timer?
    private var revealTimer: Timer?
    private var refreshPending = false
    private var holding = false
    private var lastKey: TimeInterval?
    /// The frontmost chosen app's front window, which typing reveals.
    private var focusedTargetID: CGWindowID?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    var isRunning: Bool { preferences != nil }
    var overlayCount: Int { overlays.count }

    // MARK: Start and stop

    /// Starts watching, or applies new preferences to a running tracker.
    func start(_ preferences: PrivacyBlurPreferences) {
        guard !ZenithQuiet.isOn else { return } // Zenith fork: never an overlay or observer in tests
        let previous = self.preferences
        let appsChanged = previous?.apps != preferences.apps || previous?.modes != preferences.modes
        let monitorsChanged = previous?.options.hoverReveal != preferences.options.hoverReveal
            || previous?.holdKey != preferences.holdKey || previous?.revealWhileTyping != preferences.revealWhileTyping
        self.preferences = preferences
        if reader == nil { reader = PrivacyBlurContentReader() }
        if previous == nil { installWorkspaceObservers() }
        if appsChanged {
            // A mode changed: the watches come back with or without content notifications.
            if previous != nil, previous?.modes != preferences.modes {
                watches.values.forEach { $0.invalidate() }
                watches.removeAll()
            }
            syncWatches()
        }
        if previous != nil, monitorsChanged { removeMonitors() }
        refresh()
        // New options apply to the items already read; a window switched to items is read afresh.
        if previous != nil, previous?.modes != preferences.modes { overlays.keys.forEach(requestRead) }
        overlays.keys.forEach(render)
        applyReveal()
    }

    /// Lets go of everything: panes, observers, monitors, timers and reads.
    func stop() {
        guard isRunning else { return }
        preferences = nil
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
        workspaceObservers.removeAll()
        appObservers.forEach(NotificationCenter.default.removeObserver)
        appObservers.removeAll()
        watches.values.forEach { $0.invalidate() }
        watches.removeAll()
        appByPID.removeAll()
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        order.removeAll()
        contents.values.forEach { $0.cancel() }
        contents.removeAll()
        reader?.forget()
        reader = nil
        removeMonitors()
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        contentTimer?.invalidate()
        contentTimer = nil
        pressTimer?.invalidate()
        pressTimer = nil
        typingTimer?.invalidate()
        typingTimer = nil
        revealTimer?.invalidate()
        revealTimer = nil
        holding = false
        lastKey = nil
        focusedTargetID = nil
    }

    /// Accessibility was granted or taken back: observers come or go, and
    /// the windows are read (or blur whole).
    func accessibilityChanged() {
        guard isRunning else { return }
        watches.values.forEach { $0.invalidate() }
        watches.removeAll()
        syncWatches()
        updateMonitors()
        refresh()
        for id in overlays.keys {
            if AXIsProcessTrusted() { requestRead(id) } else { contents[id]?.forgetScene() }
            render(id)
        }
    }

    // MARK: Apps

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let appEvents: [Notification.Name] = [NSWorkspace.didLaunchApplicationNotification,
                                              NSWorkspace.didTerminateApplicationNotification]
        for name in appEvents {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated { self?.appsChanged(app) }
            })
        }
        // Coming forward reorders the app's windows above everything; the
        // panes follow after the window server has done it.
        let orderEvents: [Notification.Name] = [NSWorkspace.didActivateApplicationNotification,
                                                NSWorkspace.didHideApplicationNotification,
                                                NSWorkspace.didUnhideApplicationNotification,
                                                NSWorkspace.activeSpaceDidChangeNotification]
        for name in orderEvents {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshSoon() }
            })
        }
        appObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSoon() }
        })
    }

    private func appsChanged(_ app: NSRunningApplication?) {
        guard let preferences else { return }
        // Only a launch or quit of a chosen app matters.
        if let app, PrivacyBlurApps.app(for: app.bundleIdentifier, in: preferences.apps) == nil,
           watches[app.processIdentifier] == nil, appByPID[app.processIdentifier] == nil { return }
        syncWatches()
        refreshSoon()
    }

    /// One watch per running chosen app; a quit app's watch goes.
    private func syncWatches() {
        guard let preferences else { return }
        var running: [pid_t: String] = [:]
        for app in NSWorkspace.shared.runningApplications where !app.isTerminated {
            if let chosen = PrivacyBlurApps.app(for: app.bundleIdentifier, in: preferences.apps) {
                running[app.processIdentifier] = chosen
            }
        }
        appByPID = running
        for (pid, watch) in watches where running[pid] == nil {
            watch.invalidate()
            watches[pid] = nil
        }
        let trusted = AXIsProcessTrusted()
        if trusted {
            for (pid, app) in running where watches[pid] == nil {
                let watch = PrivacyBlurAppWatch(pid: pid, contentEvents: preferences.mode(of: app) == .items) {
                    [weak self] notification in self?.accessibilityEvent(notification, pid: pid)
                }
                watch.install()
                watches[pid] = watch
            }
        }
        // A missing or refused observer falls back to reading the list on a timer.
        let needsFallback = !running.isEmpty && running.keys.contains { watches[$0]?.isWatching != true }
        if needsFallback, fallbackTimer == nil {
            let timer = Timer(timeInterval: Self.fallbackInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.fallbackTick() }
            }
            timer.tolerance = Self.fallbackInterval * 0.3
            RunLoop.main.add(timer, forMode: .common)
            fallbackTimer = timer
        } else if !needsFallback {
            fallbackTimer?.invalidate()
            fallbackTimer = nil
        }
    }

    private func fallbackTick() {
        // Accessibility granted meanwhile: the observers take over.
        if AXIsProcessTrusted(), watches.count < appByPID.count {
            syncWatches()
        }
        refresh()
    }

    private func accessibilityEvent(_ notification: String, pid: pid_t) {
        switch notification {
        case kAXWindowMovedNotification:
            refresh()
            followPress()
        case kAXWindowResizedNotification:
            refresh()
            followPress()
            readWindows(of: pid)
        case kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification,
             kAXApplicationHiddenNotification, kAXApplicationShownNotification, kAXWindowMiniaturizedNotification,
             kAXWindowDeminiaturizedNotification:
            refreshSoon()
        case kAXUIElementDestroyedNotification:
            // A window closed, or (with content events) anything in it went.
            refreshSoon()
            readWindows(of: pid)
        default:
            // The content changed: a message came, a chat opened, the layout moved.
            readWindows(of: pid)
        }
    }

    // MARK: Refresh

    /// A refresh now and again just after, for changes the window server
    /// finishes after it tells (activation, a Space, a window coming back).
    private func refreshSoon() {
        scheduleRefresh()
        for delay in [0.08, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    private func scheduleRefresh() {
        guard !refreshPending else { return }
        refreshPending = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.refreshPending = false
                self?.refresh()
            }
        }
    }

    /// Reads the window list once and makes the panes match it.
    func refresh() {
        guard let preferences, !ZenithQuiet.isOn else { return }
        let pids = Set(appByPID.keys)
        guard !pids.isEmpty else {
            closeAll()
            return
        }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                              kCGNullWindowID) as? [[String: Any]] ?? []
        let windows = PrivacyBlurPlacement.windows(from: info)
        let targets = PrivacyBlurPlacement.targets(in: windows, pids: pids)
        let wanted = Set(targets.map(\.id))
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.close()
            overlays[id] = nil
            contents[id]?.cancel()
            contents[id] = nil
        }
        order = targets
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        // Back to front, so each pane lands above its own window in turn.
        for target in targets.reversed() {
            guard let app = appByPID[target.pid] else { continue }
            let overlay = overlays[target.id] ?? PrivacyBlurOverlay(targetID: target.id)
            overlays[target.id] = overlay
            let content = contents[target.id] ?? PrivacyBlurWindowContent(pid: target.pid, app: app)
            contents[target.id] = content
            content.app = app
            // A new window, or one resized since it was read: read it whole.
            if preferences.mode(of: app) == .items, !content.matchesSize(target.frame.size) { requestRead(target.id) }
            overlay.update(frame: target.frame,
                           cocoaFrame: PrivacyBlurPlacement.cocoaFrame(target.frame, mainDisplayHeight: mainHeight),
                           items: items(for: content, size: target.frame.size),
                           frost: PrivacyBlurRevealing.frostOpacity(strength: preferences.strength))
            // Up but missing from this Space's list twice running: the pane
            // stayed on the Space its window left (full screen, a moved
            // window). Out and in again brings it to the current one.
            let listed = overlay.windowNumber.map { id in windows.contains { $0.id == id } } ?? false
            overlay.misses = overlay.isOnScreen && !listed ? overlay.misses + 1 : 0
            if overlay.misses >= 2 {
                overlay.hide()
                overlay.misses = 0
            }
            if PrivacyBlurPlacement.needsOrdering(overlay: overlay.isOnScreen ? overlay.windowNumber : nil,
                                                  target: target, ownPID: ownPID, in: windows) {
                overlay.order(above: target.id)
            }
        }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        focusedTargetID = targets.first { $0.pid == frontPID }?.id
        updateMonitors()
        syncContentTimer(frontPID: frontPID)
        applyReveal()
    }

    private func closeAll() {
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        order.removeAll()
        contents.values.forEach { $0.cancel() }
        contents.removeAll()
        focusedTargetID = nil
        updateMonitors()
        syncContentTimer(frontPID: nil)
    }

    // MARK: Items

    /// What a window's pane draws now: its scene's items for the options
    /// (moved by what scrolled since the read), or the whole window.
    private func items(for content: PrivacyBlurWindowContent, size: CGSize) -> [PrivacyBlurItem] {
        guard let preferences else { return [] }
        let mode = preferences.mode(of: content.app)
        let shown = PrivacyBlurItems.shown(scene: content.scene, mode: mode, options: preferences.options, windowSize: size)
        guard mode == .items, let scene = content.scene, scene.recognized else { return shown }
        let offsets = PrivacyBlurScrolling.residual(now: content.ledger.snapshot(), atRead: content.totalsAtRead)
        return PrivacyBlurScrolling.shifted(shown, areas: scene.areas, offsets: offsets)
    }

    /// Lays a window's pane out again from what is known, without a list read.
    private func render(_ id: CGWindowID) {
        guard let preferences, let overlay = overlays[id], let content = contents[id] else { return }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        overlay.update(frame: overlay.frame,
                       cocoaFrame: PrivacyBlurPlacement.cocoaFrame(overlay.frame, mainDisplayHeight: mainHeight),
                       items: items(for: content, size: overlay.frame.size),
                       frost: PrivacyBlurRevealing.frostOpacity(strength: preferences.strength))
    }

    private func readWindows(of pid: pid_t) {
        for (id, content) in contents where content.pid == pid { requestRead(id) }
    }

    /// A whole read of the window, coalesced: one at a time, at most every
    /// `readInterval`, and not while it scrolls (one follows the scroll).
    private func requestRead(_ id: CGWindowID) {
        guard let preferences, let content = contents[id], preferences.mode(of: content.app) == .items,
              AXIsProcessTrusted() else { return }
        if content.scrolling || content.reading {
            content.readAgain = true
            return
        }
        let wait = content.lastRead + Self.readInterval - ProcessInfo.processInfo.systemUptime
        guard wait <= 0 else {
            guard !content.readScheduled else { return }
            content.readScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self, weak content] in
                MainActor.assumeIsolated {
                    content?.readScheduled = false
                    self?.requestRead(id)
                }
            }
            return
        }
        guard let reader, let frame = overlays[id]?.frame, !frame.isEmpty else { return }
        content.reading = true
        content.readAgain = false
        reader.readWindow(pid: content.pid, windowID: id, frame: frame, ledger: content.ledger) { [weak self, weak content] read in
            guard let self, let content, self.contents[id] === content else { return }
            content.reading = false
            content.lastRead = ProcessInfo.processInfo.systemUptime
            content.take(read, support: PrivacyBlurApps.support(of: content.app))
            self.render(id)
            self.applyReveal()
            if content.readAgain { self.requestRead(id) }
        }
    }

    /// The scrolled area read again, coalesced at `scrollReadInterval`.
    private func requestPartRead(_ id: CGWindowID, area: Int) {
        guard let content = contents[id], let reader else { return }
        if content.partReading {
            content.partAgain = area
            return
        }
        guard let scene = content.scene, let target = scene.areas.first(where: { $0.id == area }),
              let window = content.windowHandle, let node = content.root?.node(target.nodeID),
              let handle = node.handle else { return }
        let wait = content.lastPartRead + Self.scrollReadInterval - ProcessInfo.processInfo.systemUptime
        content.partReading = true
        content.partAgain = nil
        let begin = { [weak self, weak content] in
            guard let self, let content, self.contents[id] === content else { return }
            reader.readPart(handle, window: window, ledger: content.ledger) { [weak self, weak content] read in
                guard let self, let content, self.contents[id] === content else { return }
                content.partReading = false
                content.lastPartRead = ProcessInfo.processInfo.systemUptime
                content.takePart(read, replacing: target.nodeID, area: area,
                                 support: PrivacyBlurApps.support(of: content.app))
                self.render(id)
                self.applyReveal()
                if let again = content.partAgain { self.requestPartRead(id, area: again) }
            }
        }
        if wait > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { MainActor.assumeIsolated { begin() } }
        } else {
            begin()
        }
    }

    /// Twice a second while a chosen app blurred item by item is frontmost
    /// and has a pane; nothing otherwise.
    private func syncContentTimer(frontPID: pid_t?) {
        let wanted: Bool = {
            guard let preferences, let frontPID, let app = appByPID[frontPID], preferences.mode(of: app) == .items,
                  AXIsProcessTrusted() else { return false }
            return contents.values.contains { $0.pid == frontPID }
        }()
        if wanted, contentTimer == nil {
            let timer = Timer(timeInterval: Self.contentInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.contentTick() }
            }
            timer.tolerance = Self.contentInterval * 0.2
            RunLoop.main.add(timer, forMode: .common)
            contentTimer = timer
        } else if !wanted, let timer = contentTimer {
            timer.invalidate()
            contentTimer = nil
        }
    }

    private func contentTick() {
        guard let front = NSWorkspace.shared.frontmostApplication?.processIdentifier, appByPID[front] != nil else {
            return syncContentTimer(frontPID: nil)
        }
        readWindows(of: front)
    }

    // MARK: Scrolling

    /// Up only while the pointer is over a chat window.
    private func syncScrollMonitor() {
        let over = overlays.isEmpty ? false : overlayUnderPointer() != nil
        if over, scrollMonitor == nil {
            scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let delta = event.scrollingDeltaY, precise = event.hasPreciseScrollingDeltas
                MainActor.assumeIsolated { self?.scrolled(delta: delta, precise: precise) }
            }
        } else if !over, let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    /// The front-most chat window under the pointer.
    private func overlayUnderPointer() -> PrivacyBlurOverlay? {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let mouse = NSEvent.mouseLocation
        for window in order {
            guard let overlay = overlays[window.id] else { continue }
            if PrivacyBlurPlacement.cocoaFrame(overlay.frame, mainDisplayHeight: mainHeight).contains(mouse) { return overlay }
        }
        return nil
    }

    private func scrolled(delta: CGFloat, precise: Bool) {
        guard let preferences, let overlay = overlayUnderPointer(), let content = contents[overlay.targetID],
              preferences.mode(of: content.app) == .items, let scene = content.scene else { return }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = PrivacyBlurPlacement.localPoint(NSEvent.mouseLocation, inWindow: overlay.frame, mainDisplayHeight: mainHeight)
        guard let area = PrivacyBlurScrolling.area(at: point, in: scene.areas) else { return }
        content.scrolling = true
        if let dy = PrivacyBlurScrolling.contentDelta(scrollingDeltaY: delta, precise: precise) {
            content.ledger.add(area.id, dy)
            render(overlay.targetID)
            applyReveal()
        }
        requestPartRead(overlay.targetID, area: area.id)
        let id = overlay.targetID
        content.scrollTimer?.invalidate()
        let timer = Timer(timeInterval: Self.scrollIdle, repeats: false) { [weak self, weak content] _ in
            MainActor.assumeIsolated {
                guard let self, let content else { return }
                content.scrollTimer = nil
                content.scrolling = false
                self.requestPartRead(id, area: area.id)
                // The scroll may have loaded rows and bubbles the part didn't hold.
                content.readAgain = false
                self.requestRead(id)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        content.scrollTimer = timer
    }

    // MARK: Pointer and keys

    /// Monitors only while a pane is up, and only those an option needs.
    private func updateMonitors() {
        guard let preferences, !overlays.isEmpty else {
            removeMonitors()
            return
        }
        if pointerMonitors.isEmpty {
            // A press on a blurred window follows its drag and the reorder a
            // click brings; moving tells hovering and the scroll monitor.
            let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .mouseMoved, .leftMouseDragged]
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
                let type = event.type
                MainActor.assumeIsolated { self?.pointerEvent(type) }
            }) { pointerMonitors.append(monitor) }
        }
        let wantsKeys = preferences.holdKey != .none || preferences.revealWhileTyping
        if wantsKeys, keyMonitors.isEmpty {
            var mask: NSEvent.EventTypeMask = []
            if preferences.holdKey != .none { mask.insert(.flagsChanged) }
            if preferences.revealWhileTyping { mask.insert(.keyDown) }
            let handler: (NSEvent) -> Void = { [weak self] event in
                let type = event.type, flags = UInt(event.modifierFlags.rawValue)
                MainActor.assumeIsolated { self?.keyEvent(type, flags: flags) }
            }
            if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) { keyMonitors.append(global) }
            if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                handler(event)
                return event
            }) { keyMonitors.append(local) }
        } else if !wantsKeys, !keyMonitors.isEmpty {
            keyMonitors.forEach(NSEvent.removeMonitor)
            keyMonitors.removeAll()
        }
        syncScrollMonitor()
    }

    private func removeMonitors() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors.removeAll()
        keyMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors.removeAll()
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        holding = false
    }

    private func pointerEvent(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            if overlays.values.contains(where: { contains(NSEvent.mouseLocation, $0.frame) }) {
                refresh()
                followPress()
            }
        case .leftMouseUp:
            scheduleRefresh()
            // A click in a chat window may open another chat: read it as it settles.
            if let overlay = overlayUnderPointer() {
                let id = overlay.targetID
                for delay in [0.12, 0.45] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        MainActor.assumeIsolated { self?.requestRead(id) }
                    }
                }
            }
        default:
            syncScrollMonitor()
            applyReveal()
        }
    }

    /// Reads the list every frame while the button is held, then once more.
    private func followPress() {
        guard pressTimer == nil, NSEvent.pressedMouseButtons & 1 == 1 else { return }
        let timer = Timer(timeInterval: Self.pressInterval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.refresh()
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    timer.invalidate()
                    self.pressTimer = nil
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pressTimer = timer
    }

    private func keyEvent(_ type: NSEvent.EventType, flags: UInt) {
        guard let preferences else { return }
        if type == .flagsChanged {
            let held = preferences.holdKey.isHeld(flags: flags)
            if held != holding {
                holding = held
                applyReveal()
            }
            return
        }
        guard type == .keyDown, preferences.revealWhileTyping, PrivacyBlurRevealing.countsAsTyping(flags: flags),
              let front = NSWorkspace.shared.frontmostApplication?.processIdentifier, appByPID[front] != nil else { return }
        lastKey = ProcessInfo.processInfo.systemUptime
        applyReveal()
        typingTimer?.invalidate()
        let timer = Timer(timeInterval: PrivacyBlurRevealing.typingHold + 0.05, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.typingTimer = nil
                self?.applyReveal()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        typingTimer = timer
    }

    private func contains(_ point: CGPoint, _ frame: CGRect) -> Bool {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return PrivacyBlurPlacement.cocoaFrame(frame, mainDisplayHeight: mainHeight).contains(point)
    }

    /// What each pane shows, from the pointer, the held key and typing. An
    /// item coming clear under the pointer waits for it to rest there
    /// (unless "No transition delay" is on); everything else is at once.
    private func applyReveal() {
        guard let preferences else { return }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let mouse = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        let typing = PrivacyBlurRevealing.isTyping(lastKey: lastKey, now: now)
        let transition = PrivacyBlurTransition.timing(
            noDelay: preferences.options.noDelay, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        var nextCheck: TimeInterval?
        for overlay in overlays.values {
            let pointer = PrivacyBlurPlacement.localPoint(mouse, inWindow: overlay.frame, mainDisplayHeight: mainHeight)
            let wanted = PrivacyBlurRevealing.reveal(hoverReveal: preferences.options.hoverReveal, holding: holding,
                                                     typing: typing, isFocusedWindow: overlay.targetID == focusedTargetID,
                                                     pointer: pointer, windowSize: overlay.frame.size, items: overlay.items)
            guard transition.delay > 0, PrivacyBlurTransition.waits(from: overlay.reveal, to: wanted) else {
                overlay.pending = nil
                overlay.apply(wanted, transition: transition)
                continue
            }
            // Blur what was clear at once, then clear the new item once the pointer rested on it.
            if let pending = overlay.pending, pending.reveal == wanted {
                if now - pending.since >= transition.delay {
                    overlay.pending = nil
                    overlay.apply(wanted, transition: transition)
                } else {
                    nextCheck = min(nextCheck ?? .infinity, pending.since + transition.delay - now)
                }
            } else {
                overlay.pending = (wanted, now)
                overlay.apply(.none, transition: transition)
                nextCheck = min(nextCheck ?? .infinity, transition.delay)
            }
        }
        revealTimer?.invalidate()
        revealTimer = nil
        if let nextCheck {
            let timer = Timer(timeInterval: max(0.01, nextCheck), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.revealTimer = nil
                    self?.applyReveal()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            revealTimer = timer
        }
    }
}

// MARK: - A window's items

/// What is known of one chat window's content: its last tree and scene,
/// the scroll since, and the reads in flight.
@MainActor
final class PrivacyBlurWindowContent {
    let pid: pid_t
    var app: String
    private(set) var root: PrivacyBlurNode?
    private(set) var scene: PrivacyBlurScene?
    private(set) var windowHandle: PrivacyBlurElementHandle?
    /// The window's frame (Accessibility's) at the last whole read.
    private(set) var readFrame: CGRect = .null
    /// The scroll totals each area's items were read at.
    private(set) var totalsAtRead: [Int: CGFloat] = [:]
    let ledger = PrivacyBlurScrollLedger()
    var reading = false
    var readAgain = false
    var readScheduled = false
    var lastRead: TimeInterval = 0
    var partReading = false
    var partAgain: Int?
    var lastPartRead: TimeInterval = 0
    var scrolling = false
    var scrollTimer: Timer?

    init(pid: pid_t, app: String) {
        self.pid = pid
        self.app = app
    }

    /// Whether the last read was of a window this size (resizing moves the columns).
    func matchesSize(_ size: CGSize) -> Bool {
        !readFrame.isNull && abs(readFrame.width - size.width) <= 2 && abs(readFrame.height - size.height) <= 2
    }

    /// A whole read: the tree and scene it found, or none (the window blurs whole).
    func take(_ read: PrivacyBlurRead, support: PrivacyBlurItemSupport) {
        root = read.root
        windowHandle = read.windowHandle
        readFrame = read.window
        totalsAtRead = read.totals
        scene = read.root.map { PrivacyBlurItems.classify(support, root: $0, window: read.window) }
    }

    /// A scroll area read again: swapped into the tree, which is read for
    /// items again. The part's frames follow the window if it moved since.
    func takePart(_ read: PrivacyBlurRead, replacing nodeID: Int, area: Int, support: PrivacyBlurItemSupport) {
        guard var part = read.root, let root, !readFrame.isNull, !read.window.isNull else { return }
        let dx = readFrame.minX - read.window.minX, dy = readFrame.minY - read.window.minY
        if dx != 0 || dy != 0 { part = part.offset(dx: dx, dy: dy) }
        guard let replaced = root.replacing(nodeID, with: part) else { return }
        self.root = replaced
        totalsAtRead[area] = read.totals[area] ?? 0
        scene = PrivacyBlurItems.classify(support, root: replaced, window: readFrame)
    }

    func forgetScene() {
        root = nil
        scene = nil
        windowHandle = nil
        readFrame = .null
    }

    func cancel() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
}

// MARK: - Accessibility

/// One chosen app's Accessibility observer: window moves, resizes, new and
/// closed windows, minimising and focus, on the app and on each window
/// (some apps send a window's notifications only to the window). With
/// `contentEvents`, also what tells the content changed: values, layout,
/// focus, selection and elements created or destroyed.
@MainActor
final class PrivacyBlurAppWatch {
    private static let appNotifications = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification,
                                           kAXMainWindowChangedNotification, kAXApplicationHiddenNotification,
                                           kAXApplicationShownNotification, kAXWindowMovedNotification,
                                           kAXWindowResizedNotification]
    private static let windowNotifications = [kAXWindowMovedNotification, kAXWindowResizedNotification,
                                              kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
                                              kAXUIElementDestroyedNotification]
    static let contentNotifications = [kAXValueChangedNotification, kAXLayoutChangedNotification,
                                       kAXCreatedNotification, kAXFocusedUIElementChangedNotification,
                                       kAXSelectedChildrenChangedNotification, kAXRowCountChangedNotification]

    let pid: pid_t
    let contentEvents: Bool
    private let application: AXUIElement
    private let onEvent: (String) -> Void
    private var observer: AXObserver?
    private var windows: [AXUIElement] = []

    var isWatching: Bool { observer != nil }

    init(pid: pid_t, contentEvents: Bool = false, onEvent: @escaping (String) -> Void) {
        self.pid = pid
        self.contentEvents = contentEvents
        self.onEvent = onEvent
        application = AXUIElementCreateApplication(pid)
        // An app that stops answering never holds Zenith up for long.
        AXUIElementSetMessagingTimeout(application, 0.25)
    }

    private var applicationNotifications: [String] {
        Self.appNotifications + (contentEvents ? Self.contentNotifications : [])
    }

    func install() {
        guard observer == nil, !ZenithQuiet.isOn, AXIsProcessTrusted() else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, privacyBlurAXCallback, &created) == .success, let created else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var added = 0
        for notification in applicationNotifications
            where AXObserverAddNotification(created, application, notification as CFString, refcon) == .success {
            added += 1
        }
        guard added > 0 else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        watchWindows()
    }

    /// Registers the window notifications on windows not yet watched.
    private func watchWindows() {
        guard let observer else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let list = value as? [AXUIElement] else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for window in list where !windows.contains(where: { CFEqual($0, window) }) {
            for notification in Self.windowNotifications {
                AXObserverAddNotification(observer, window, notification as CFString, refcon)
            }
        }
        windows = list
    }

    fileprivate func handle(_ notification: String) {
        if notification == kAXWindowCreatedNotification { watchWindows() }
        onEvent(notification)
    }

    /// Removes the observer before the watch goes, so no callback finds it gone.
    func invalidate() {
        guard let observer else { return }
        for notification in applicationNotifications {
            AXObserverRemoveNotification(observer, application, notification as CFString)
        }
        for window in windows {
            for notification in Self.windowNotifications {
                AXObserverRemoveNotification(observer, window, notification as CFString)
            }
        }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        self.observer = nil
        windows.removeAll()
    }
}

private func privacyBlurAXCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
                                   _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let watch = Unmanaged<PrivacyBlurAppWatch>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated { watch.handle(name) }
}
