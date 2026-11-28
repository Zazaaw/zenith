// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices

// Zenith fork: Privacy Blur at work. While the blur is up it watches only
// the chosen apps: an Accessibility observer per running app tells it when
// a window moves, resizes, appears, closes, minimises or takes focus, and
// the workspace tells it when an app opens, quits, hides, comes forward or
// the Space changes. Each of those reads the window server's list once
// (bounds and order need no permission) and puts a pane just above every
// visible chat window, then closes the panes whose window left the screen.
// Pointer and key monitors exist only while a pane is up and an option
// needs them. Without Accessibility the same refresh runs on a slow timer.

@MainActor
final class PrivacyBlurTracker {
    /// Without Accessibility, how often the window list is read.
    static let fallbackInterval: TimeInterval = 0.5
    /// While a mouse button is held on a blurred window: a drag or a click
    /// that brings it forward. Ends when the button comes up.
    static let pressInterval: TimeInterval = 1.0 / 60

    private var preferences: PrivacyBlurPreferences?
    private var watches: [pid_t: PrivacyBlurAppWatch] = [:]
    /// The chosen app each watched process belongs to.
    private var appByPID: [pid_t: String] = [:]
    private var overlays: [CGWindowID: PrivacyBlurOverlay] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private var pointerMonitors: [Any] = []
    private var keyMonitors: [Any] = []
    private var fallbackTimer: Timer?
    private var pressTimer: Timer?
    private var typingTimer: Timer?
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
        let appsChanged = previous?.apps != preferences.apps
        let monitorsChanged = previous?.hover != preferences.hover || previous?.holdKey != preferences.holdKey
            || previous?.revealWhileTyping != preferences.revealWhileTyping
        self.preferences = preferences
        if previous == nil { installWorkspaceObservers() }
        if appsChanged { syncWatches() }
        if previous != nil, monitorsChanged { removeMonitors() }
        refresh()
    }

    /// Lets go of everything: panes, observers, monitors and timers.
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
        removeMonitors()
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        pressTimer?.invalidate()
        pressTimer = nil
        typingTimer?.invalidate()
        typingTimer = nil
        holding = false
        lastKey = nil
        focusedTargetID = nil
    }

    /// Accessibility was granted or taken back: observers come or go.
    func accessibilityChanged() {
        guard isRunning else { return }
        watches.values.forEach { $0.invalidate() }
        watches.removeAll()
        syncWatches()
        updateMonitors()
        refresh()
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
            for pid in running.keys where watches[pid] == nil {
                let watch = PrivacyBlurAppWatch(pid: pid) { [weak self] notification in
                    self?.accessibilityEvent(notification)
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

    private func accessibilityEvent(_ notification: String) {
        switch notification {
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            refresh()
            followPress()
        default:
            refreshSoon()
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
        }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let frost = PrivacyBlurRevealing.frostOpacity(strength: preferences.strength)
        // Back to front, so each pane lands above its own window in turn.
        for target in targets.reversed() {
            guard let app = appByPID[target.pid] else { continue }
            let overlay = overlays[target.id] ?? PrivacyBlurOverlay(targetID: target.id)
            overlays[target.id] = overlay
            let pieces = PrivacyBlurRegions.pieces(preferences.regions(of: app), layout: preferences.layout(of: app),
                                                   size: target.frame.size)
            overlay.update(frame: target.frame,
                           cocoaFrame: PrivacyBlurPlacement.cocoaFrame(target.frame, mainDisplayHeight: mainHeight),
                           pieces: pieces, frost: frost)
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
        applyReveal()
    }

    private func closeAll() {
        overlays.values.forEach { $0.close() }
        overlays.removeAll()
        focusedTargetID = nil
        updateMonitors()
    }

    // MARK: Pointer and keys

    /// Monitors only while a pane is up, and only those an option needs.
    private func updateMonitors() {
        guard let preferences, !overlays.isEmpty else {
            removeMonitors()
            return
        }
        if pointerMonitors.isEmpty {
            // A press on a blurred window follows its drag and the reorder a click brings.
            var mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp]
            if preferences.hover != .off { mask.formUnion([.mouseMoved, .leftMouseDragged]) }
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
    }

    private func removeMonitors() {
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors.removeAll()
        keyMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors.removeAll()
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
        default:
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

    /// What each pane shows, from the pointer, the held key and typing.
    private func applyReveal() {
        guard let preferences else { return }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let mouse = NSEvent.mouseLocation
        let typing = PrivacyBlurRevealing.isTyping(lastKey: lastKey, now: ProcessInfo.processInfo.systemUptime)
        for overlay in overlays.values {
            let pointer = PrivacyBlurPlacement.localPoint(mouse, inWindow: overlay.frame, mainDisplayHeight: mainHeight)
            overlay.apply(PrivacyBlurRevealing.reveal(hover: preferences.hover, holding: holding, typing: typing,
                                                      isFocusedWindow: overlay.targetID == focusedTargetID,
                                                      pointer: pointer, windowSize: overlay.frame.size,
                                                      pieces: overlay.pieces))
        }
    }
}

// MARK: - Accessibility

/// One chosen app's Accessibility observer: window moves, resizes, new and
/// closed windows, minimising and focus, on the app and on each window
/// (some apps send a window's notifications only to the window).
@MainActor
final class PrivacyBlurAppWatch {
    private static let appNotifications = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification,
                                           kAXMainWindowChangedNotification, kAXApplicationHiddenNotification,
                                           kAXApplicationShownNotification, kAXWindowMovedNotification,
                                           kAXWindowResizedNotification]
    private static let windowNotifications = [kAXWindowMovedNotification, kAXWindowResizedNotification,
                                              kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
                                              kAXUIElementDestroyedNotification]

    let pid: pid_t
    private let application: AXUIElement
    private let onEvent: (String) -> Void
    private var observer: AXObserver?
    private var windows: [AXUIElement] = []

    var isWatching: Bool { observer != nil }

    init(pid: pid_t, onEvent: @escaping (String) -> Void) {
        self.pid = pid
        self.onEvent = onEvent
        application = AXUIElementCreateApplication(pid)
        // An app that stops answering never holds Zenith up for long.
        AXUIElementSetMessagingTimeout(application, 0.25)
    }

    func install() {
        guard observer == nil, !ZenithQuiet.isOn, AXIsProcessTrusted() else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, privacyBlurAXCallback, &created) == .success, let created else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var added = 0
        for notification in Self.appNotifications
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
        for notification in Self.appNotifications {
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
