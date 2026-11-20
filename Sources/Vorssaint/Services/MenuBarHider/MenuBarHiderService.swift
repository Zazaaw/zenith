// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices
import Combine

/// Zenith fork: hides menu bar icons the person ⌘-drags left of Zenith's
/// divider, the way Ice and Hidden Bar do. Off by default. While off it owns
/// no status item, no monitor and no timer; the defaults observer only
/// re-reads the settings.
///
/// Events reach the core from here: clicks on the chevron, the shortcut,
/// hovering the empty menu bar, clicks elsewhere and the Mac locking. One
/// timer wakes the core when its next deadline comes.
final class MenuBarHiderService: ObservableObject {
    static let shared = MenuBarHiderService()

    @Published private(set) var reveal: MenuBarHiderReveal = .collapsed
    @Published private(set) var blockers: [MenuBarHiderBlocker] = []
    @Published private(set) var behindNotch: [String] = []
    @Published private(set) var shortcutRegistrationFailed = false

    /// Hovering has to rest this long before the icons show.
    private static let hoverDwell: TimeInterval = 0.25

    private let items = MenuBarHiderStatusItems()
    private let sensing: MenuBarHiderSystemSensing
    private let core: MenuBarHiderCore
    private let hotkey = QuickToolHotkey(id: 97)
    private var started = false
    private var timer: Timer?
    private var clickMonitors: [Any] = []
    private var moveMonitors: [Any] = []
    private var emptyAreaMonitor: Any?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var defaultsObserver: NSObjectProtocol?
    private var captureObserver: NSObjectProtocol?
    private var defaultsSyncScheduled = false
    private var hoverTimer: Timer?
    private var pointerWasInBar = false
    private var lastShortcut: String?

    private init() {
        sensing = MenuBarHiderSystemSensing(items: items)
        core = MenuBarHiderCore(host: items, sensing: sensing, settings: .read(.standard))
        items.onClick = { [weak self] click in self?.handle(click) }
        hotkey.onPress = { [weak self] in self?.perform(.shortcut) }
    }

    // MARK: Lifecycle

    /// Called once Zenith's own status item exists, so the dividers are born
    /// after it and can be seeded just left of it.
    func start(mainItemFrame: @escaping () -> CGRect?) {
        guard !started else { return }
        started = true
        items.mainItemFrame = mainItemFrame
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleDefaultsSync()
            }
        captureObserver = NotificationCenter.default.addObserver(
            forName: .zenithShortcutCaptureEnded, object: nil, queue: .main) { [weak self] _ in
                self?.syncShortcut()
            }
        sync(interactive: false)
    }

    /// Short dividers before quitting, so the places macOS saves are the
    /// ones the person last saw.
    func prepareForTermination() {
        guard items.isInstalled else { return }
        items.apply(MenuBarHiderLayout.lengths(reveal: .all, alwaysHidden: items.hasAlwaysDivider,
                                               collapsedLength: sensing.collapsedLength))
    }

    /// Re-reads the preferences, for Settings and for a restored backup.
    func syncWithPreferences() {
        sync(interactive: true)
    }

    /// Registers the shortcut again, for the end of a shortcut recording.
    func syncShortcut() {
        guard started else { return }
        let settings = core.settings
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.menuBarHiderShortcut, fallback: .menuBarHiderDefault)
        let failed = !hotkey.sync(enabled: settings.enabled && settings.shortcutEnabled, shortcut: shortcut,
                                  storageKey: DefaultsKey.menuBarHiderShortcut)
        lastShortcut = UserDefaults.standard.string(forKey: DefaultsKey.menuBarHiderShortcut)
        if shortcutRegistrationFailed != failed { shortcutRegistrationFailed = failed }
    }

    func perform(_ trigger: MenuBarHiderTrigger) {
        core.perform(trigger, now: Date())
        changed()
    }

    // MARK: Preferences

    private func scheduleDefaultsSync() {
        guard !defaultsSyncScheduled else { return }
        defaultsSyncScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.defaultsSyncScheduled = false
            let settings = MenuBarHiderSettings.read(.standard)
            let shortcut = UserDefaults.standard.string(forKey: DefaultsKey.menuBarHiderShortcut)
            guard settings != self.core.settings || shortcut != self.lastShortcut else { return }
            self.sync(interactive: true)
        }
    }

    private func sync(interactive: Bool) {
        guard started else { return }
        let settings = MenuBarHiderSettings.read(.standard)
        core.sync(settings, now: Date(), interactive: interactive)
        syncObservers(enabled: settings.enabled)
        syncShortcut()
        changed()
    }

    // MARK: Changes

    /// Publishes the core's state and fits the monitors and the timer to it.
    private func changed() {
        if reveal != core.reveal { reveal = core.reveal }
        if blockers != core.blockers { blockers = core.blockers }
        if behindNotch != core.behindNotch { behindNotch = core.behindNotch }
        syncMonitors()
        reschedule()
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard let wake = core.nextWake else { return }
        let timer = Timer(fire: max(wake, Date()), interval: 0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.timer = nil
            self.core.tick(now: Date())
            self.changed()
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: Clicks

    private func handle(_ click: MenuBarHiderStatusItems.Click) {
        switch click {
        case .primary(let option):
            perform(option ? .optionClick : .click)
        case .secondary(let button):
            showMenu(from: button)
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let text = ZenithStrings.menuBarHider(L10n.shared.language)
        let menu = NSMenu()
        func add(_ title: String, _ trigger: MenuBarHiderTrigger, enabled: Bool) {
            let item = NSMenuItem(title: title, action: enabled ? #selector(MenuTarget.run(_:)) : nil, keyEquivalent: "")
            item.target = menuTarget
            item.representedObject = MenuTarget.Action.trigger(trigger)
            menu.addItem(item)
        }
        let reveal = core.reveal
        add(text.showHidden, .showHidden, enabled: reveal != .hidden)
        if core.settings.alwaysHidden { add(text.showAll, .showAll, enabled: reveal != .all) }
        add(text.hide, .hide, enabled: reveal != .collapsed)
        let names = sensing.namesBehindNotch()
        if !names.isEmpty {
            menu.addItem(.separator())
            let info = NSMenuItem(title: String(format: text.behindNotch, names.joined(separator: ", ")),
                                  action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: text.settings, action: #selector(MenuTarget.run(_:)), keyEquivalent: ",")
        settings.target = menuTarget
        settings.representedObject = MenuTarget.Action.settings
        menu.addItem(settings)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    private lazy var menuTarget = MenuTarget { [weak self] action in
        switch action {
        case .trigger(let trigger):
            self?.perform(trigger)
        case .settings:
            SettingsRouter.shared.request(FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration))
            appDelegate()?.openSettingsWindow()
        }
    }

    // MARK: Monitors

    private func syncMonitors() {
        let settings = core.settings
        let machine = core.machine
        let wantsClicks = settings.enabled && machine.isExpanded && !machine.pinned && settings.collapseOnClickOutside
        if wantsClicks, clickMonitors.isEmpty {
            let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
                self?.mouseDown(at: NSEvent.mouseLocation)
            }) { clickMonitors.append(global) }
            if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
                self?.mouseDown(at: NSEvent.mouseLocation)
                return event
            }) { clickMonitors.append(local) }
        } else if !wantsClicks, !clickMonitors.isEmpty {
            clickMonitors.forEach(NSEvent.removeMonitor)
            clickMonitors = []
        }

        // A click on the empty menu bar lands on a stretched divider, one of
        // Zenith's own windows, so only a local monitor is needed for it.
        if settings.enabled, emptyAreaMonitor == nil {
            emptyAreaMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self, let number = event.window?.windowNumber,
                      self.items.longDividerWindowNumbers.contains(number) else { return event }
                self.perform(event.modifierFlags.contains(.option) ? .optionClick : .click)
                return nil
            }
        } else if !settings.enabled, let monitor = emptyAreaMonitor {
            NSEvent.removeMonitor(monitor)
            emptyAreaMonitor = nil
        }

        let wantsMoves = settings.enabled && settings.showOnHover
            && (!machine.isExpanded || machine.revealedByHover)
        if wantsMoves, moveMonitors.isEmpty {
            pointerWasInBar = sensing.pointerInMenuBar(NSEvent.mouseLocation)
            if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
                self?.pointerMoved(to: NSEvent.mouseLocation)
            }) { moveMonitors.append(global) }
            if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] event in
                self?.pointerMoved(to: NSEvent.mouseLocation)
                return event
            }) { moveMonitors.append(local) }
            sensing.refreshAppMenuEdge()
        } else if !wantsMoves, !moveMonitors.isEmpty {
            moveMonitors.forEach(NSEvent.removeMonitor)
            moveMonitors = []
            cancelHover()
        }
    }

    private func mouseDown(at point: CGPoint) {
        guard !sensing.pointerInMenuBar(point) else { return }
        core.clickedOutside(now: Date())
        changed()
    }

    private func pointerMoved(to point: CGPoint) {
        let inBar = sensing.pointerInMenuBar(point)
        defer { pointerWasInBar = inBar }
        if core.machine.isExpanded {
            if pointerWasInBar, !inBar, core.machine.revealedByHover {
                core.pointerLeftMenuBar(now: Date())
                changed()
            }
            return
        }
        guard inBar, NSEvent.pressedMouseButtons == 0, let band = sensing.hoverBand(), MenuBarHiderLayout.contains(band, point)
        else {
            cancelHover()
            return
        }
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: Self.hoverDwell, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.hoverTimer = nil
            let point = NSEvent.mouseLocation
            guard NSEvent.pressedMouseButtons == 0, !self.core.machine.isExpanded,
                  let band = self.sensing.hoverBand(), MenuBarHiderLayout.contains(band, point) else { return }
            self.pointerWasInBar = true
            self.perform(.hover)
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func cancelHover() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    // MARK: System events

    private func syncObservers(enabled: Bool) {
        if !enabled {
            for (center, token) in observers { center.removeObserver(token) }
            observers = []
            timer?.invalidate()
            timer = nil
            return
        }
        guard observers.isEmpty else { return }
        let locked: (Notification) -> Void = { [weak self] _ in
            guard let self else { return }
            self.core.screenLocked(now: Date())
            self.changed()
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main, using: locked)))
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append((workspace, workspace.addObserver(forName: name, object: nil, queue: .main, using: locked)))
        }
        observers.append((workspace, workspace.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, !self.moveMonitors.isEmpty else { return }
                self.sensing.refreshAppMenuEdge()
            }))
        observers.append((NotificationCenter.default, NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.core.refresh(now: Date())
                self.changed()
            }))
    }
}

/// Carries the chevron menu's choices back to the service.
private final class MenuTarget: NSObject {
    enum Action {
        case trigger(MenuBarHiderTrigger)
        case settings
    }

    private let handler: (Action) -> Void

    init(_ handler: @escaping (Action) -> Void) {
        self.handler = handler
    }

    @objc func run(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? Action else { return }
        handler(action)
    }
}

// MARK: - Probes

/// Reads the window server and the screens for the core. Window bounds and
/// owner names need no permission; the app menus' extent is read through
/// Accessibility only when Zenith already has it, and never asks.
final class MenuBarHiderSystemSensing: MenuBarHiderSensing {
    private weak var items: MenuBarHiderStatusItems?
    private var appMenuEdge: CGFloat?
    private var appMenuQuery = 0

    init(items: MenuBarHiderStatusItems) {
        self.items = items
    }

    var collapsedLength: CGFloat {
        MenuBarHiderLayout.collapsedLength(screenWidths: NSScreen.screens.map(\.frame.width))
    }

    func environment() -> MenuBarHiderEnvironment {
        MenuBarHiderEnvironment(menuOpen: Self.menuIsOpen(),
                                mouseDown: NSEvent.pressedMouseButtons != 0,
                                pointerInMenuBar: pointerInMenuBar(NSEvent.mouseLocation))
    }

    func pointerInMenuBar(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { screen in
            let frame = screen.frame
            return frame.contains(point)
                || (abs(point.y - frame.maxY) < 1 && frame.minX <= point.x && point.x < frame.maxX)
        }) else { return false }
        return point.y >= screen.frame.maxY - Self.barHeight(screen)
    }

    /// The screen whose menu bar holds the chevron.
    private var barScreen: NSScreen? {
        guard let frame = items?.frames().chevron else { return NSScreen.main }
        return NSScreen.screens.first { $0.frame.minX <= frame.midX && frame.midX <= $0.frame.maxX } ?? NSScreen.main
    }

    func hoverBand() -> CGRect? {
        guard let screen = barScreen, let divider = items?.frames().divider else { return nil }
        var limits: [CGFloat] = []
        if let gap = Self.notchGap(screen) { limits.append(gap.maxX) }
        if let appMenuEdge { limits.append(appMenuEdge) }
        return MenuBarHiderLayout.hoverBand(screen: screen.frame, barHeight: Self.barHeight(screen),
                                            dividerMaxX: divider.maxX, leftLimits: limits)
    }

    func alwaysHiddenOverflowsNotch(_ frames: MenuBarHiderFrames) -> Bool {
        guard let screen = barScreen, let gap = Self.notchGap(screen), let always = frames.alwaysDivider else { return false }
        let items = statusWindows(on: screen).map(\.frame)
        return MenuBarHiderLayout.alwaysHiddenOverflows(alwaysDivider: always, items: items, gap: gap)
    }

    func namesBehindNotch() -> [String] {
        guard let screen = barScreen, let gap = Self.notchGap(screen) else { return [] }
        var names: [String] = []
        for window in statusWindows(on: screen) where MenuBarHiderLayout.isBehindNotch(window.frame, gap: gap) {
            if !names.contains(window.owner) { names.append(window.owner) }
        }
        return names
    }

    /// Reads where the front app's menus end, off the main thread, for the
    /// left edge of the hover band.
    func refreshAppMenuEdge() {
        appMenuQuery += 1
        let query = appMenuQuery
        guard AXIsProcessTrusted(), let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            appMenuEdge = nil
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let edge = Self.appMenuMaxX(pid: pid)
            DispatchQueue.main.async {
                guard let self, self.appMenuQuery == query else { return }
                self.appMenuEdge = edge
            }
        }
    }

    // MARK: Window server

    private struct StatusWindow {
        let frame: CGRect
        let owner: String
    }

    /// Other status items in the menu bar of `screen`, in Cocoa coordinates.
    /// The hider's own items are left out, and so is anything wider than the
    /// screen (a collapsed divider, Zenith's or another hider's).
    private func statusWindows(on screen: NSScreen) -> [StatusWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height else { return [] }
        let own = items?.windowNumbers ?? []
        let level = Int(CGWindowLevelForKey(.statusWindow))
        let band = screen.frame.maxY - Self.barHeight(screen)
        var windows: [StatusWindow] = []
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == level,
                  let number = info[kCGWindowNumber as String] as? Int, !own.contains(number),
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"], let width = bounds["Width"], let height = bounds["Height"],
                  width > 0, width < screen.frame.width, height > 0 else { continue }
            let frame = CGRect(x: x, y: primaryHeight - y - height, width: width, height: height)
            // This screen's bar only; an item macOS dropped off it can't be judged.
            guard frame.maxY >= band, frame.minY <= screen.frame.maxY + 1,
                  frame.maxX > screen.frame.minX, frame.minX < screen.frame.maxX else { continue }
            windows.append(StatusWindow(frame: frame, owner: info[kCGWindowOwnerName as String] as? String ?? "?"))
        }
        return windows
    }

    /// Any app's menu is open: the status item menus, context menus and the
    /// menu bar's own menus all live on the pop-up menu level.
    private static func menuIsOpen() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let level = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return list.contains { ($0[kCGWindowLayer as String] as? Int) == level }
    }

    // MARK: Screens

    static func barHeight(_ screen: NSScreen) -> CGFloat {
        max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
    }

    static func notchGap(_ screen: NSScreen) -> CGRect? {
        MenuBarHiderLayout.notchGap(topLeft: screen.auxiliaryTopLeftArea, topRight: screen.auxiliaryTopRightArea)
    }

    static var hasNotchedScreen: Bool {
        NSScreen.screens.contains { notchGap($0) != nil }
    }

    // MARK: Accessibility

    private static func appMenuMaxX(pid: pid_t) -> CGFloat? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.1)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &value) == .success,
              let menuBar = value, CFGetTypeID(menuBar) == AXUIElementGetTypeID() else { return nil }
        let bar = menuBar as! AXUIElement
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar, kAXChildrenAttribute as CFString, &children) == .success,
              let last = (children as? [AXUIElement])?.last else { return nil }
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(last, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(last, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return point.x + extent.width
    }
}
