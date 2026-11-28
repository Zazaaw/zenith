// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices

// Zenith fork: what tells App Lock's shield that the covered app's windows
// changed, only while a shield is up. An Accessibility observer on that one
// app reports a window moving, resizing, appearing, closing, minimising or
// taking focus; the workspace reports a Space change, the app hiding or
// coming forward, and the screens changing. A light check on a timer reads
// the window list now and then besides (faster without Accessibility, where
// it is the only source), so a window that slipped over its pane is caught.
// The same idea as Privacy Blur's tracker, kept apart so neither feature
// edits the other's files.

@MainActor
final class AppLockWindowTracker {
    enum Event {
        /// A window moved or resized: follow it now.
        case moved
        /// Windows came, went or changed Space: read the list now and just after.
        case changed
        /// The app's focused window changed: it may have taken the keyboard.
        case focus
        /// The timer's check.
        case tick
    }

    /// The check's interval with Accessibility (observers do the rest) and
    /// without it (the check is all there is).
    static let watchInterval: TimeInterval = 0.5
    static let fallbackInterval: TimeInterval = 0.2

    private var watch: AppLockAppWatch?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    private var onEvent: ((Event) -> Void)?

    var isRunning: Bool { onEvent != nil }

    func start(pid: pid_t, onEvent: @escaping (Event) -> Void) {
        stop()
        guard !ZenithQuiet.isOn else { return } // never an observer in tests or the catalog
        self.onEvent = onEvent
        let watch = AppLockAppWatch(pid: pid) { [weak self] notification in self?.accessibilityEvent(notification) }
        watch.install()
        self.watch = watch
        let workspace = NSWorkspace.shared.notificationCenter
        // Coming forward reorders the app's windows; AppLockService hands the
        // keyboard back to the shield when it is the covered app.
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            observe(workspace, name, .changed)
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification, .changed)
        let interval = watch.isWatching ? Self.watchInterval : Self.fallbackInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onEvent?(.tick) }
        }
        timer.tolerance = interval * 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        onEvent = nil
        watch?.invalidate()
        watch = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        timer?.invalidate()
        timer = nil
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ event: Event) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onEvent?(event) }
        }
        observers.append((center, token))
    }

    private func accessibilityEvent(_ notification: String) {
        switch notification {
        case kAXWindowMovedNotification, kAXWindowResizedNotification: onEvent?(.moved)
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification: onEvent?(.focus)
        default: onEvent?(.changed)
        }
    }
}

// MARK: - Accessibility

/// The covered app's Accessibility observer: on the app and on each of its
/// windows (some apps send a window's notifications only to the window).
/// Without Accessibility it installs nothing and the tracker's timer reads
/// the list instead.
@MainActor
final class AppLockAppWatch {
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
        guard AXObserverCreate(pid, appLockAXCallback, &created) == .success, let created else { return }
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

private func appLockAXCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
                               _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let watch = Unmanaged<AppLockAppWatch>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated { watch.handle(name) }
}
