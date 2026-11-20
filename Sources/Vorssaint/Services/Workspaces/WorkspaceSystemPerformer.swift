// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices

// Zenith fork: the workspace steps on the real Mac. It runs on the
// workspace's background queue and may wait (for an app to launch, a window
// to appear, a Shortcut to finish); AppKit and the app's services are
// reached on the main thread. Every step reuses what Zenith already has:
// Window Layout's geometry and gaps, Keep Awake, the mixer's output switch,
// the wallpaper service, Quit Apps' rules and exceptions.

final class WorkspaceSystemPerformer: WorkspacePerforming {
    /// How long an app gets to launch, a window to show and a quit to finish.
    private let launchTimeout: TimeInterval = 15
    private let windowTimeout: TimeInterval = 6
    private let quitTimeout: TimeInterval = 6
    /// A breath after each launch or link, so the next step finds it settled.
    private let settle: TimeInterval = 0.35

    func perform(_ action: WorkspaceAction, in workspace: Workspace) -> [WorkspaceProblem] {
        switch action {
        case .openApps(let apps): return openApps(apps)
        case .hideOthers: return Self.onMain { Self.hideOthers(keeping: workspace.ownBundleIDs) }
        case .quitApps(let apps): return quit(apps, keeping: workspace.ownBundleIDs)
        case .arrange(let arrangements): return arrange(arrangements)
        case .keepAwake(let on): return Self.onMain { Self.keepAwake(on) }
        case .focus(let name): return runShortcut(name)
        case .sound(let sound): return Self.onMain { Self.setSound(sound) }
        case .wallpaper(let path): return Self.onMain { Self.setWallpaper(path) }
        case .openURL(let link): return openLink(link)
        }
    }

    // MARK: Apps

    private final class Outcome: @unchecked Sendable {
        private let lock = NSLock()
        private var failed = false
        func fail() { lock.lock(); failed = true; lock.unlock() }
        var didFail: Bool { lock.lock(); defer { lock.unlock() }; return failed }
    }

    private func openApps(_ apps: [WorkspaceApp]) -> [WorkspaceProblem] {
        var problems: [WorkspaceProblem] = []
        for app in apps {
            guard let appURL = Self.applicationURL(app) else {
                problems.append(.appMissing(app.name))
                continue
            }
            var targets: [URL] = []
            if !app.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let url = WorkspaceTarget.url(app.target),
                   !url.isFileURL || FileManager.default.fileExists(atPath: url.path) {
                    targets = [url]
                } else {
                    // The app still opens, without what it was to open.
                    problems.append(.appMissing(app.target))
                }
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            let done = DispatchSemaphore(value: 0)
            let outcome = Outcome()
            let finish: (NSRunningApplication?, Error?) -> Void = { _, error in
                if error != nil { outcome.fail() }
                done.signal()
            }
            if targets.isEmpty {
                NSWorkspace.shared.openApplication(at: appURL, configuration: configuration, completionHandler: finish)
            } else {
                NSWorkspace.shared.open(targets, withApplicationAt: appURL, configuration: configuration, completionHandler: finish)
            }
            guard done.wait(timeout: .now() + launchTimeout) == .success, !outcome.didFail else {
                problems.append(.openFailed(app.name))
                continue
            }
            let bundleID = app.bundleID.isEmpty ? Bundle(url: appURL)?.bundleIdentifier ?? "" : app.bundleID
            if !bundleID.isEmpty {
                _ = Self.wait(for: launchTimeout) {
                    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                        .contains { $0.isFinishedLaunching }
                }
            }
            Thread.sleep(forTimeInterval: settle)
        }
        return problems
    }

    static func applicationURL(_ app: WorkspaceApp) -> URL? {
        if !app.bundleID.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
            return url
        }
        guard !app.path.isEmpty, FileManager.default.fileExists(atPath: app.path) else { return nil }
        return URL(fileURLWithPath: app.path)
    }

    private static func snapshot(_ app: NSRunningApplication) -> WorkspaceRunningApp {
        WorkspaceRunningApp(pid: app.processIdentifier, bundleID: app.bundleIdentifier,
                            activationPolicy: app.activationPolicy.rawValue, isTerminated: app.isTerminated,
                            isHidden: app.isHidden)
    }

    private static func hideOthers(keeping own: Set<String>) -> [WorkspaceProblem] {
        let running = NSWorkspace.shared.runningApplications
        let keep = own.union(WorkspacePlans.zenithIDs(own: Bundle.main.bundleIdentifier))
        let targets = Set(WorkspacePlans.hideTargets(running.map(snapshot), keeping: keep))
        for app in running where targets.contains(app.processIdentifier) { app.hide() }
        return []
    }

    /// A polite quit (`terminate`, never `forceTerminate`), as Quit Apps does,
    /// with its exceptions. An app that is still open after a few seconds,
    /// say asking to save, is reported and left alone.
    private func quit(_ apps: [WorkspaceApp], keeping own: Set<String>) -> [WorkspaceProblem] {
        let asked: [NSRunningApplication] = Self.onMain {
            let running = NSWorkspace.shared.runningApplications
            let targets = Set(WorkspacePlans.quitTargets(apps, running: running.map(Self.snapshot),
                                                         exceptions: QuickTogglesService.shared.quitAllExceptions,
                                                         keeping: own))
            let chosen = running.filter { targets.contains($0.processIdentifier) }
            for app in chosen { _ = app.terminate() }
            return chosen
        }
        guard !asked.isEmpty else { return [] }
        _ = Self.wait(for: quitTimeout) { asked.allSatisfy(\.isTerminated) }
        return asked.filter { !$0.isTerminated }.map { app in
            .quitFailed(app.localizedName ?? apps.first { $0.bundleID == app.bundleIdentifier }?.name ?? "")
        }
    }

    private func openLink(_ link: String) -> [WorkspaceProblem] {
        guard let url = WorkspaceTarget.url(link) else { return [.linkFailed(link)] }
        let opened = Self.onMain { NSWorkspace.shared.open(url) }
        guard opened else { return [.linkFailed(link)] }
        Thread.sleep(forTimeInterval: settle)
        return []
    }

    // MARK: Windows

    private func arrange(_ arrangements: [WorkspaceArrangement]) -> [WorkspaceProblem] {
        guard !arrangements.isEmpty else { return [] }
        guard AXIsProcessTrusted() else { return [.needsAccessibility] }
        let (displays, top) = Self.onMain { (WorkspaceScreens.displays(), WorkspaceScreens.top()) }
        var problems: [WorkspaceProblem] = []
        for arrangement in arrangements {
            let name = arrangement.app.name
            guard let pid = Self.onMain({ Self.runningPID(arrangement.app) }) else {
                problems.append(.notRunning(name))
                continue
            }
            var found: AXUIElement?
            _ = Self.wait(for: windowTimeout) {
                found = WorkspaceWindows.frontWindow(of: pid)
                return found != nil
            }
            guard let window = found, let axFrame = WorkspaceWindows.frame(of: window) else {
                problems.append(.noWindow(name))
                continue
            }
            let current = WorkspaceGeometry.appKitRect(fromAX: axFrame, top: top)
            let target: CGRect?
            switch arrangement.placement {
            case .layout(let action):
                target = WorkspaceGeometry.display(for: current, in: displays).map { display in
                    WindowLayoutGeometry.rect(for: action, current: current, visibleFrame: display.visibleFrame,
                                              windowGap: WindowLayoutGaps.windowGap, screenGap: WindowLayoutGaps.screenGap,
                                              marginPercent: WindowLayoutMargin.percent).integral
                }
            case .frame(let frame):
                target = WorkspaceCapture.resolve(frame, displays: displays)
            }
            guard let target, WorkspaceWindows.setFrame(WorkspaceGeometry.axRect(fromAppKit: target, top: top), on: window)
            else {
                problems.append(.noWindow(name))
                continue
            }
        }
        return problems
    }

    private static func runningPID(_ app: WorkspaceApp) -> pid_t? {
        let running = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
        if !app.bundleID.isEmpty, let match = running.first(where: { $0.bundleIdentifier == app.bundleID }) {
            return match.processIdentifier
        }
        guard !app.path.isEmpty else { return nil }
        return running.first { $0.bundleURL?.path == app.path }?.processIdentifier
    }

    // MARK: Keep Awake, Focus, sound, wallpaper

    /// Starts an open-ended session, or ends the running one. Keep Awake
    /// records every start as the next default; a workspace is not the
    /// user's pick, so the saved duration and end time are put back.
    private static func keepAwake(_ on: Bool) -> [WorkspaceProblem] {
        let manager = KeepAwakeManager.shared
        guard on else {
            if manager.isActive { manager.deactivate(reason: .manual) }
            return []
        }
        guard AppFeature.keepAwake.isAvailable else { return [.keepAwakeUnavailable] }
        guard !manager.isActive else { return [] }
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.defaultDuration, DefaultsKey.keepAwakeSwitchUsesUntil]
        let saved = keys.map { defaults.object(forKey: $0) }
        manager.activate(minutes: 0)
        for (key, value) in zip(keys, saved) {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        return manager.isActive ? [] : [.keepAwakeUnavailable]
    }

    private func runShortcut(_ name: String) -> [WorkspaceProblem] {
        guard let arguments = WorkspaceShortcutsCommand.arguments(name) else { return [.shortcutFailed(name)] }
        let result = BoundedProcessRunner.run(WorkspaceShortcutsCommand.path, arguments,
                                              timeout: WorkspaceShortcutsCommand.timeout, maxOutputBytes: 64 * 1024)
        return result.status == 0 && !result.timedOut ? [] : [.shortcutFailed(name.trimmingCharacters(in: .whitespaces))]
    }

    private static func setSound(_ sound: WorkspaceSound) -> [WorkspaceProblem] {
        var problems: [WorkspaceProblem] = []
        if !sound.uid.isEmpty, !WorkspaceAudio.setDefaultOutput(uid: sound.uid) {
            problems.append(.outputMissing(sound.name.isEmpty ? sound.uid : sound.name))
        }
        if let volume = sound.volume { AppVolumeMixer.setSystemOutputVolume(volume) }
        return problems
    }

    /// Through the wallpaper feature when it is on (all displays, every
    /// Space, as its settings say); otherwise straight on each display.
    private static func setWallpaper(_ path: String) -> [WorkspaceProblem] {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return [.wallpaperFailed] }
        let url = URL(fileURLWithPath: path)
        if WallpaperService.shared.isAvailable, let entry = WallpaperSupport.ownEntries(from: [url]).first {
            WallpaperService.shared.apply(entry)
            return []
        }
        do {
            for screen in NSScreen.screens { try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:]) }
            return []
        } catch {
            return [.wallpaperFailed]
        }
    }

    // MARK: Helpers

    static func onMain<T>(_ work: () -> T) -> T {
        Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)
    }

    /// Polls until `condition` holds or the time runs out; whether it held.
    @discardableResult
    static func wait(for timeout: TimeInterval, every interval: TimeInterval = 0.1, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: interval)
        }
        return true
    }
}

// MARK: - Screens and windows

enum WorkspaceScreens {
    /// Every display, with its stable UUID. Main thread.
    static func displays() -> [WorkspaceDisplay] {
        NSScreen.screens.map { screen in
            WorkspaceDisplay(id: identifier(screen), frame: screen.frame, visibleFrame: screen.windowLayoutVisibleFrame,
                             isMain: abs(screen.frame.minX) < 0.5 && abs(screen.frame.minY) < 0.5)
        }
    }

    /// The top of the display that holds the menu bar, where Accessibility's origin sits.
    static func top() -> CGFloat {
        let main = NSScreen.screens.first { abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5 }
        return (main ?? NSScreen.main ?? NSScreen.screens.first)?.frame.maxY ?? 0
    }

    static func identifier(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return ""
        }
        let display = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue(),
              let text = CFUUIDCreateString(nil, uuid) as String? else { return String(display) }
        return text
    }
}

enum WorkspaceWindows {
    /// The app's focused window, its main one, or its first standard window.
    static func frontWindow(of pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let window = element(app, attribute), isStandard(window) { return window }
        }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        return windows.first(where: isStandard)
    }

    /// In Accessibility's coordinates (origin top left).
    static func frame(of window: AXUIElement) -> CGRect? {
        var position = CGPoint.zero
        var size = CGSize.zero
        guard let positionValue = value(window, kAXPositionAttribute), AXValueGetValue(positionValue, .cgPoint, &position),
              let sizeValue = value(window, kAXSizeAttribute), AXValueGetValue(sizeValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Size, position, then size again, so a window that the old size kept
    /// from moving (or the new position from growing) still lands.
    static func setFrame(_ frame: CGRect, on window: AXUIElement) -> Bool {
        let suspension = EnhancedUserInterfaceSuspension.suspend(forAppOf: window)
        defer { suspension?.resume() }
        var size = frame.size
        var origin = frame.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size), let originValue = AXValueCreate(.cgPoint, &origin) else {
            return false
        }
        _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, originValue) == .success
        let sized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue) == .success
        return moved || sized
    }

    private static func element(_ app: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func value(_ window: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private static func isStandard(_ window: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole) == .success else {
            // An app that names no subrole still has a window worth placing.
            return true
        }
        return (subrole as? String) == (kAXStandardWindowSubrole as String)
    }
}

// MARK: - Capture

enum WorkspaceSnapshot {
    /// The regular apps running now, back to front, with their front windows'
    /// frames when Accessibility allows: opened in this order, the frontmost
    /// ends up in front again. Main thread.
    static func capture(named name: String) -> Workspace {
        let zenith = WorkspacePlans.zenithIDs(own: Bundle.main.bundleIdentifier)
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && !$0.isHidden
                && !zenith.contains($0.bundleIdentifier ?? "")
        }
        let order = frontToBackPIDs()
        let sorted = running.sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs.processIdentifier) ?? Int.max
            let r = order.firstIndex(of: rhs.processIdentifier) ?? Int.max
            return l > r
        }
        let trusted = AXIsProcessTrusted()
        let top = WorkspaceScreens.top()
        let apps = sorted.map { app -> WorkspaceCapturedApp in
            let frame = trusted ? WorkspaceWindows.frontWindow(of: app.processIdentifier)
                .flatMap(WorkspaceWindows.frame(of:))
                .map { WorkspaceGeometry.appKitRect(fromAX: $0, top: top) } : nil
            return WorkspaceCapturedApp(bundleID: app.bundleIdentifier ?? "", name: app.localizedName ?? "",
                                        path: app.bundleURL?.path ?? "", frame: frame)
        }
        return WorkspaceCapture.workspace(named: name, apps: apps, displays: WorkspaceScreens.displays(), excluding: zenith)
    }

    /// Owners of the windows on screen, front first; reading them needs no permission.
    private static func frontToBackPIDs() -> [pid_t] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
        var seen = Set<pid_t>()
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  seen.insert(pid).inserted else { return nil }
            return pid
        }
    }
}
