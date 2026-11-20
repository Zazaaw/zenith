// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the menu bar hider. The state machine and the core run on a
/// fake clock with fake status items and fake probes; no status item, event
/// monitor or window list is ever touched.
enum MenuBarHiderTests {
    static func run(_ suite: TestSuite) {
        delays(suite)
        settings(suite)
        reveals(suite)
        timing(suite)
        lengths(suite)
        order(suite)
        notch(suite)
        hover(suite)
        placement(suite)
        motion(suite)
        core(suite)
        shortcut(suite)
        strings(suite)
    }

    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    private static func enabled(_ change: (inout MenuBarHiderSettings) -> Void = { _ in }) -> MenuBarHiderSettings {
        var settings = MenuBarHiderSettings()
        settings.enabled = true
        change(&settings)
        return settings
    }

    // MARK: Settings

    private static func delays(_ suite: TestSuite) {
        suite.expect(MenuBarHiderDelay.stored(nil) == .ten && MenuBarHiderDelay.stored(7) == .ten
                        && MenuBarHiderDelay.stored("5") == .ten,
                     "a missing or unknown delay reads as ten seconds, never as never")
        suite.expect(MenuBarHiderDelay.stored(5) == .five && MenuBarHiderDelay.stored(NSNumber(value: 30)) == .thirty
                        && MenuBarHiderDelay.stored(0) == .never,
                     "5, 30 and 0 read back as themselves")
        suite.expect(MenuBarHiderDelay.allCases.map(\.interval) == [5, 10, 30, nil],
                     "the choices are 5, 10 and 30 seconds, then never")
    }

    private static func settings(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.menubar-hider"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "the isolated defaults suite opens")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let fresh = MenuBarHiderSettings.read(defaults)
        suite.expect(fresh == MenuBarHiderSettings() && !fresh.enabled && !fresh.alwaysHidden && fresh.delay == .ten
                        && fresh.collapseOnClickOutside && !fresh.showOnHover && fresh.notchGuard && !fresh.shortcutEnabled,
                     "hiding starts off, with a ten second delay and click elsewhere and the notch guard on")

        defaults.set(true, forKey: DefaultsKey.menuBarHiderEnabled)
        defaults.set(true, forKey: DefaultsKey.menuBarHiderAlwaysHidden)
        defaults.set(30, forKey: DefaultsKey.menuBarHiderDelay)
        defaults.set(false, forKey: DefaultsKey.menuBarHiderCollapseOnClick)
        defaults.set(true, forKey: DefaultsKey.menuBarHiderShowOnHover)
        defaults.set(false, forKey: DefaultsKey.menuBarHiderNotchGuard)
        defaults.set(true, forKey: DefaultsKey.menuBarHiderShortcutEnabled)
        let saved = MenuBarHiderSettings.read(defaults)
        suite.expect(saved == MenuBarHiderSettings(enabled: true, alwaysHidden: true, delay: .thirty,
                                                   collapseOnClickOutside: false, showOnHover: true,
                                                   notchGuard: false, shortcutEnabled: true),
                     "every option reads back what was saved")
        defaults.set(0, forKey: DefaultsKey.menuBarHiderDelay)
        suite.expect(MenuBarHiderSettings.read(defaults).delay == .never, "a saved zero is never")

        let registered = Defaults.registeredDefaults
        let ours = MenuBarHiderSettings.registered
        suite.expect(ours.count == 7 && ours.allSatisfy { key, value in
            (registered[key] as? NSObject)?.isEqual(value) == true
        }, "every option is registered with its first-run value, so it joins backups")
        suite.expect(registered[DefaultsKey.menuBarHiderShortcut] as? String
                        == GlobalShortcut.menuBarHiderDefault.storageValue,
                     "the shortcut is registered with its default combination")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(ours.keys.allSatisfy(exported.contains) && exported.contains(DefaultsKey.menuBarHiderShortcut),
                     "a settings backup carries the hider's options and shortcut")
        suite.expect(MenuBarHiderPlacement.allNames.allSatisfy { !exported.contains(MenuBarHiderPlacement.positionKey($0)) },
                     "the dividers' places are this Mac's and stay out of backups")
    }

    // MARK: State machine

    private static func reveals(_ suite: TestSuite) {
        typealias M = MenuBarHiderMachine
        suite.expect(M.target(for: .click, from: .collapsed, alwaysHidden: true) == .hidden
                        && M.target(for: .click, from: .hidden, alwaysHidden: true) == .collapsed
                        && M.target(for: .click, from: .all, alwaysHidden: true) == .collapsed
                        && M.target(for: .shortcut, from: .collapsed, alwaysHidden: true) == .hidden,
                     "a click or the shortcut shows the hidden section, and hides whatever is showing")
        suite.expect(M.target(for: .optionClick, from: .collapsed, alwaysHidden: true) == .all
                        && M.target(for: .optionClick, from: .hidden, alwaysHidden: true) == .all
                        && M.target(for: .optionClick, from: .all, alwaysHidden: true) == .collapsed,
                     "⌥-click opens the always hidden section too, and closes it again")
        suite.expect(M.target(for: .optionClick, from: .collapsed, alwaysHidden: false) == .hidden
                        && M.target(for: .showAll, from: .collapsed, alwaysHidden: false) == .hidden,
                     "without the always hidden section, ⌥-click and Show All show the hidden one")
        suite.expect(M.target(for: .hover, from: .collapsed, alwaysHidden: true) == .hidden
                        && M.target(for: .hover, from: .hidden, alwaysHidden: true) == nil
                        && M.target(for: .hover, from: .all, alwaysHidden: true) == nil,
                     "hovering only ever shows the hidden section, never the always hidden one, and never hides")
        suite.expect(M.target(for: .shortcut, from: .collapsed, alwaysHidden: true) != .all,
                     "the shortcut never opens the always hidden section")

        var machine = MenuBarHiderMachine(settings: enabled { $0.alwaysHidden = false })
        machine.move(to: .all, now: start)
        suite.expect(machine.reveal == .hidden, "asking for everything without the section shows the hidden icons")
        machine = MenuBarHiderMachine(settings: enabled { $0.alwaysHidden = true })
        machine.handle(.optionClick, now: start)
        machine.update(enabled { $0.alwaysHidden = false }, now: at(1))
        suite.expect(machine.reveal == .hidden, "switching the section off while it shows falls back to the hidden icons")
        machine.update(MenuBarHiderSettings(), now: at(2))
        suite.expect(machine.reveal == .collapsed && machine.deadline == nil, "switching hiding off collapses")
    }

    private static func timing(_ suite: TestSuite) {
        var machine = MenuBarHiderMachine(settings: enabled())
        machine.handle(.click, now: start)
        suite.expect(machine.reveal == .hidden && machine.deadline == at(10), "revealed icons get ten seconds")
        suite.expect(!machine.isDue(at(9.9)) && machine.isDue(at(10)), "the collapse comes due at ten seconds, not before")
        machine.postpone(at(10))
        suite.expect(machine.deadline == at(11) && machine.reveal == .hidden,
                     "an open menu holds the bar a second at a time")
        machine.clickedOutside(at(10.5))
        suite.expect(machine.deadline == at(10.8), "a click elsewhere brings the collapse forward to a short grace")
        machine.clickedOutside(at(10.6))
        suite.expect(machine.deadline == at(10.8), "a second click never pushes the collapse later")
        machine.collapse()
        suite.expect(machine.reveal == .collapsed && machine.deadline == nil && !machine.isDue(at(100)),
                     "collapsing clears the timer")

        machine = MenuBarHiderMachine(settings: enabled { $0.delay = .never })
        machine.handle(.click, now: start)
        suite.expect(machine.deadline == nil && !machine.isDue(at(10_000)), "never means no timer")
        machine.clickedOutside(at(1))
        suite.expect(machine.deadline == at(1.3), "a click elsewhere still collapses with no timer")

        machine = MenuBarHiderMachine(settings: enabled { $0.collapseOnClickOutside = false })
        machine.handle(.click, now: start)
        machine.clickedOutside(at(1))
        suite.expect(machine.deadline == at(10), "with click elsewhere off, a click changes nothing")

        machine = MenuBarHiderMachine(settings: enabled())
        machine.move(to: .hidden, now: start, pin: true)
        machine.clickedOutside(at(1))
        suite.expect(machine.pinned && machine.deadline == nil, "a bar opened for arranging ignores the timer and clicks")
        suite.expect(machine.screenLocked() && machine.reveal == .collapsed && !machine.pinned,
                     "locking the Mac collapses even a bar opened for arranging")
        suite.expect(!machine.screenLocked(), "locking a collapsed bar changes nothing")

        machine = MenuBarHiderMachine(settings: enabled { $0.delay = .never; $0.showOnHover = true })
        machine.handle(.hover, now: start)
        suite.expect(machine.revealedByHover && machine.deadline == nil, "hovering reveals with no timer of its own")
        machine.pointerLeftMenuBar(at(2))
        suite.expect(machine.deadline == at(2.8), "leaving the menu bar collapses a hover reveal after a short grace")
        machine.handle(.click, now: at(2.5))
        suite.expect(machine.reveal == .collapsed, "a click on a hover reveal hides the icons")
        machine.handle(.click, now: at(3))
        machine.pointerLeftMenuBar(at(4))
        suite.expect(!machine.revealedByHover && machine.deadline == nil,
                     "leaving the menu bar does not collapse icons shown on purpose")

        machine = MenuBarHiderMachine(settings: enabled())
        machine.handle(.click, now: start)
        machine.update(enabled { $0.delay = .thirty }, now: at(4))
        suite.expect(machine.deadline == at(34), "a new delay starts over from the change")
        machine.hold()
        suite.expect(machine.pinned && machine.deadline == nil && machine.reveal == .hidden,
                     "holding keeps the bar open without a timer")
    }

    // MARK: Geometry

    private static func lengths(_ suite: TestSuite) {
        let big: CGFloat = 10_000
        suite.expect(MenuBarHiderLayout.lengths(reveal: .collapsed, alwaysHidden: false, collapsedLength: big)
                        == MenuBarHiderLengths(divider: big, alwaysDivider: nil),
                     "collapsed, the divider pushes everything left of it off the screen")
        suite.expect(MenuBarHiderLayout.lengths(reveal: .hidden, alwaysHidden: false, collapsedLength: big)
                        == MenuBarHiderLengths(divider: MenuBarHiderLayout.dividerLength, alwaysDivider: nil),
                     "revealed, the divider shrinks to a thin line")
        suite.expect(MenuBarHiderLayout.lengths(reveal: .collapsed, alwaysHidden: true, collapsedLength: big)
                        == MenuBarHiderLengths(divider: big, alwaysDivider: big)
                        && MenuBarHiderLayout.lengths(reveal: .hidden, alwaysHidden: true, collapsedLength: big)
                        == MenuBarHiderLengths(divider: MenuBarHiderLayout.dividerLength, alwaysDivider: big),
                     "the always hidden divider stays long while only the hidden section shows")
        suite.expect(MenuBarHiderLayout.lengths(reveal: .all, alwaysHidden: true, collapsedLength: big)
                        == MenuBarHiderLengths(divider: MenuBarHiderLayout.dividerLength,
                                               alwaysDivider: MenuBarHiderLayout.alwaysDividerLength),
                     "showing everything shortens both dividers")
        suite.expect(MenuBarHiderLayout.collapsedLength(screenWidths: []) == 10_000
                        && MenuBarHiderLayout.collapsedLength(screenWidths: [1512, 3008]) == 10_000
                        && MenuBarHiderLayout.collapsedLength(screenWidths: [6016]) == 12_032,
                     "the collapsed length is at least ten thousand points and twice the widest screen")
        suite.expect(MenuBarHiderLayout.chevronLength > MenuBarHiderLayout.alwaysDividerLength
                        && MenuBarHiderLayout.alwaysDividerLength > MenuBarHiderLayout.dividerLength
                        && MenuBarHiderLayout.dividerLength >= 8,
                     "the chevron is a comfortable target and the dividers stay slim")
    }

    private static func item(_ maxX: CGFloat, width: CGFloat = 22) -> CGRect {
        CGRect(x: maxX - width, y: 945, width: width, height: 37)
    }

    private static func order(_ suite: TestSuite) {
        let main = item(1300), chevron = item(1278, width: 20)
        let collapsed = item(1258, width: 10_000), short = item(1258, width: 10)
        suite.expect(MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: main, chevron: chevron, divider: short)).isEmpty
                        && MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: main, chevron: chevron, divider: collapsed)).isEmpty,
                     "icon and chevron right of the divider pass, whatever the divider's length")
        suite.expect(MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: item(1100), chevron: chevron, divider: short))
                        == [.iconInside],
                     "Zenith's icon left of the divider blocks hiding")
        suite.expect(MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: main, chevron: item(1200), divider: short))
                        == [.chevronInside],
                     "the chevron left of the divider blocks hiding")
        suite.expect(MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: main, chevron: chevron, divider: short,
                                                                    alwaysDivider: item(1290, width: 12)))
                        == [.alwaysOutside]
                        && !MenuBarHiderBlocker.alwaysOutside.blocksCollapse,
                     "an always hidden divider right of the main one is only ignored")
        suite.expect(MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: nil, chevron: chevron, divider: short,
                                                                    alwaysDivider: item(1100, width: 10_000))).isEmpty,
                     "a hidden Zenith icon and a long always hidden divider further left pass")
        suite.expect(MenuBarHiderLayout.blockers(MenuBarHiderFrames(main: item(1100), chevron: nil, divider: nil)).isEmpty,
                     "items not placed yet block nothing")
    }

    private static func notch(_ suite: TestSuite) {
        // A 14-inch MacBook Pro at 1512 × 982.
        let left = CGRect(x: 0, y: 950, width: 661, height: 32)
        let right = CGRect(x: 851, y: 950, width: 661, height: 32)
        guard let gap = MenuBarHiderLayout.notchGap(topLeft: left, topRight: right) else {
            suite.expect(false, "a notched screen has a camera gap")
            return
        }
        suite.expect(gap.minX == 661 && gap.maxX == 851 && gap.height == 32, "the gap spans the camera housing")
        suite.expect(MenuBarHiderLayout.notchGap(topLeft: nil, topRight: right) == nil
                        && MenuBarHiderLayout.notchGap(topLeft: left, topRight: left) == nil,
                     "a screen without both top areas has no notch")
        suite.expect(MenuBarHiderLayout.isBehindNotch(CGRect(x: 840, y: 950, width: 22, height: 32), gap: gap)
                        && !MenuBarHiderLayout.isBehindNotch(CGRect(x: 851, y: 950, width: 22, height: 32), gap: gap)
                        && !MenuBarHiderLayout.isBehindNotch(CGRect(x: 600, y: 950, width: 22, height: 32), gap: gap),
                     "only an icon overlapping the camera counts as behind it")
        let always = CGRect(x: 900, y: 950, width: 12, height: 32)
        suite.expect(!MenuBarHiderLayout.alwaysHiddenOverflows(alwaysDivider: always,
                                                               items: [CGRect(x: 860, y: 950, width: 22, height: 32),
                                                                       CGRect(x: 1000, y: 950, width: 22, height: 32)],
                                                               gap: gap),
                     "always hidden icons right of the camera fit")
        suite.expect(MenuBarHiderLayout.alwaysHiddenOverflows(alwaysDivider: always,
                                                              items: [CGRect(x: 845, y: 950, width: 22, height: 32)],
                                                              gap: gap)
                        && MenuBarHiderLayout.alwaysHiddenOverflows(alwaysDivider: CGRect(x: 845, y: 950, width: 12, height: 32),
                                                                    items: [], gap: gap),
                     "an always hidden icon, or the divider itself, behind the camera overflows")
        suite.expect(!MenuBarHiderLayout.alwaysHiddenOverflows(alwaysDivider: always,
                                                               items: [CGRect(x: 845, y: 950, width: 22, height: 32)
                                                                   .offsetBy(dx: 200, dy: 0)], gap: gap),
                     "icons right of the always hidden divider are not its section")
    }

    private static func hover(_ suite: TestSuite) {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let band = MenuBarHiderLayout.hoverBand(screen: screen, barHeight: 32, dividerMaxX: 1100, leftLimits: [851, 420])
        suite.expect(band == CGRect(x: 855, y: 950, width: 245, height: 32),
                     "the hover band runs from the notch or the app menus, whichever is further right, to the divider")
        suite.expect(MenuBarHiderLayout.hoverBand(screen: screen, barHeight: 24, dividerMaxX: 1100, leftLimits: [])
                        == CGRect(x: 944, y: 958, width: 156, height: 24),
                     "without a notch or the app menus, only a short stretch beside the icons counts")
        suite.expect(MenuBarHiderLayout.hoverBand(screen: screen, barHeight: 32, dividerMaxX: 860, leftLimits: [851]) == nil,
                     "no band when the visible icons reach the notch")
        if let band {
            suite.expect(MenuBarHiderLayout.contains(band, CGPoint(x: 900, y: 981))
                            && MenuBarHiderLayout.contains(band, CGPoint(x: 900, y: 982))
                            && !MenuBarHiderLayout.contains(band, CGPoint(x: 900, y: 940))
                            && !MenuBarHiderLayout.contains(band, CGPoint(x: 1100, y: 970))
                            && !MenuBarHiderLayout.contains(band, CGPoint(x: 700, y: 970)),
                         "the band holds the top edge, not the icons, the notch or the desktop below")
        }
    }

    private static func placement(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.menubar-hider-places"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "the isolated defaults suite opens")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        func position(_ item: String) -> Double? {
            (defaults.object(forKey: MenuBarHiderPlacement.positionKey(item)) as? NSNumber)?.doubleValue
        }
        let chevron = MenuBarHiderPlacement.chevronName
        let divider = MenuBarHiderPlacement.dividerName
        let always = MenuBarHiderPlacement.alwaysDividerName

        MenuBarHiderPlacement.seed(in: defaults, mainAutosaveName: "Main", mainDistance: nil, alwaysHidden: true)
        suite.expect(position(chevron) == nil && position(divider) == nil,
                     "with nowhere to start from, macOS places the items")
        defaults.set(300.0, forKey: MenuBarHiderPlacement.positionKey("Main"))
        MenuBarHiderPlacement.seed(in: defaults, mainAutosaveName: "Main", mainDistance: 900, alwaysHidden: false)
        suite.expect(position(chevron) == 301 && position(divider) == 302 && position(always) == nil,
                     "the chevron and the divider start just left of Zenith's saved place")
        defaults.set(450.0, forKey: MenuBarHiderPlacement.positionKey(divider))
        MenuBarHiderPlacement.seed(in: defaults, mainAutosaveName: "Main", mainDistance: nil, alwaysHidden: true)
        suite.expect(position(chevron) == 301 && position(divider) == 450 && position(always) == 451,
                     "arranged places are kept, and the always hidden divider starts left of the divider")
        suite.expect(MenuBarHiderPlacement.positionKey("X") == "NSStatusItem Preferred Position X"
                        && MenuBarHiderPlacement.visibilityKeys("X") == ["NSStatusItem Visible X", "NSStatusItem VisibleCC X"],
                     "the keys are macOS's own")
        defaults.removePersistentDomain(forName: name)
        MenuBarHiderPlacement.seed(in: defaults, mainAutosaveName: "Main", mainDistance: 212, alwaysHidden: false)
        suite.expect(position(chevron) == 213 && position(divider) == 214,
                     "an icon with no saved place starts from where its frame is")
        let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: 0, width: 2560, height: 1440)]
        suite.expect(MenuBarHiderPlacement.distance(of: CGRect(x: 1278, y: 950, width: 22, height: 32), screens: screens) == 212
                        && MenuBarHiderPlacement.distance(of: CGRect(x: 3900, y: 1400, width: 22, height: 24), screens: screens) == 150
                        && MenuBarHiderPlacement.distance(of: CGRect(x: -500, y: 0, width: 22, height: 24), screens: screens) == nil,
                     "the distance counts from the right edge of the icon's own screen")
        suite.expect(Set(MenuBarHiderPlacement.allNames).count == 3
                        && !MenuBarHiderPlacement.allNames.contains(where: { $0.hasPrefix("Vorssaint") }),
                     "the items have their own names, apart from Zenith's icon")
    }

    private static func motion(_ suite: TestSuite) {
        let curve = MenuBarHiderGlyphMotion.progress
        suite.expect(curve(0) == 0 && curve(1) == 1 && curve(-1) == 0 && curve(2) == 1, "the turn starts at 0 and lands on 1")
        let samples = stride(from: 0.0, through: 1.0, by: 0.02).map(curve)
        let peak = samples.max() ?? 0
        suite.expect(peak > 1.01 && peak < 1.12, "the spring overshoots a few percent: \(peak)")
        suite.expect(curve(0.1) > 0.15 && curve(0.5) > 0.9, "the turn leaves quickly and is nearly there halfway")
        suite.expect(samples.allSatisfy(\.isFinite), "every frame of the turn is finite")
        suite.expectClose(MenuBarHiderGlyphMotion.angle(from: 0, to: .pi, elapsed: 0), 0, "angle at the start")
        suite.expectClose(MenuBarHiderGlyphMotion.angle(from: 0, to: .pi, elapsed: MenuBarHiderGlyphMotion.duration),
                          .pi, "angle at the end")
        suite.expectClose(MenuBarHiderGlyphMotion.angle(from: .pi, to: 0, elapsed: 10), 0, "angle long after")
        suite.expect(MenuBarHiderGlyphMotion.restingAngle(expanded: false) == 0
                        && MenuBarHiderGlyphMotion.restingAngle(expanded: true) == .pi
                        && MenuBarHiderGlyphMotion.duration == 0.3,
                     "collapsed points left, open points right, over the standard 0.3 seconds")
    }

    // MARK: Core

    final class FakeHost: MenuBarHiderItemHost {
        var isInstalled = false
        var hasAlwaysDivider = false
        var applied: [MenuBarHiderLengths] = []
        var expanded: [(Bool, Bool)] = []
        var removedWithLengths: MenuBarHiderLengths?
        var framesValue = MenuBarHiderFrames()
        var installs = 0

        func install(alwaysHidden: Bool) {
            isInstalled = true
            hasAlwaysDivider = alwaysHidden
            installs += 1
        }
        func uninstall() {
            removedWithLengths = applied.last
            isInstalled = false
            hasAlwaysDivider = false
        }
        func setAlwaysDivider(_ installed: Bool) { hasAlwaysDivider = installed }
        func apply(_ lengths: MenuBarHiderLengths) { applied.append(lengths) }
        func showExpanded(_ expanded: Bool, animated: Bool) { self.expanded.append((expanded, animated)) }
        func frames() -> MenuBarHiderFrames { framesValue }
    }

    final class FakeSensing: MenuBarHiderSensing {
        var collapsedLength: CGFloat = 10_000
        var environmentValue = MenuBarHiderEnvironment()
        var overflows = false
        var names: [String] = []
        func environment() -> MenuBarHiderEnvironment { environmentValue }
        func alwaysHiddenOverflowsNotch(_ frames: MenuBarHiderFrames) -> Bool { overflows }
        func namesBehindNotch() -> [String] { names }
    }

    private static let collapsedHidden = MenuBarHiderLengths(divider: 10_000, alwaysDivider: nil)
    private static let shownHidden = MenuBarHiderLengths(divider: MenuBarHiderLayout.dividerLength, alwaysDivider: nil)

    private static func core(_ suite: TestSuite) {
        let host = FakeHost(), sensing = FakeSensing()
        let core = MenuBarHiderCore(host: host, sensing: sensing, settings: MenuBarHiderSettings())
        core.sync(MenuBarHiderSettings(), now: start, interactive: false)
        suite.expect(!host.isInstalled && host.applied.isEmpty && core.nextWake == nil,
                     "switched off, nothing is created and nothing waits")
        core.perform(.click, now: start)
        suite.expect(core.reveal == .collapsed && host.applied.isEmpty, "a click does nothing while hiding is off")

        core.sync(enabled(), now: start, interactive: false)
        suite.expect(host.installs == 1 && core.reveal == .collapsed && host.applied.last == collapsedHidden,
                     "at launch the items are created already collapsed")
        suite.expect(core.orderCheckAt == at(MenuBarHiderCore.installSettle), "the order is checked once the bar settles")
        sensing.names = ["Dropbox"]
        core.tick(now: at(1))
        suite.expect(core.blockers.isEmpty && core.behindNotch == ["Dropbox"] && core.orderCheckAt == nil,
                     "the settled bar is in order, and the icons behind the notch are named")

        core.perform(.click, now: at(2))
        suite.expect(core.reveal == .hidden && host.applied.last == shownHidden
                        && host.expanded.last.map { $0 == (true, true) } == true,
                     "a click shows the hidden icons and turns the chevron")
        suite.expect(core.nextWake == at(2.3), "the next wake is the order check after the reveal")
        core.tick(now: at(2.3))
        suite.expect(core.nextWake == at(12), "then the collapse ten seconds after the click")
        sensing.environmentValue.menuOpen = true
        core.tick(now: at(12))
        suite.expect(core.reveal == .hidden && core.nextWake == at(13), "an open menu holds the icons")
        sensing.environmentValue = MenuBarHiderEnvironment(menuOpen: false, mouseDown: true)
        core.tick(now: at(13))
        suite.expect(core.reveal == .hidden && core.nextWake == at(14), "so does a pressed button")
        sensing.environmentValue = MenuBarHiderEnvironment()
        core.tick(now: at(14))
        suite.expect(core.reveal == .collapsed && host.applied.last == collapsedHidden
                        && host.expanded.last.map { $0 == (false, true) } == true,
                     "with nothing open the icons tuck away and the chevron turns back")

        // Zenith's own icon must never hide.
        core.perform(.click, now: at(20))
        host.framesValue = MenuBarHiderFrames(main: item(1100), chevron: item(1278), divider: item(1258, width: 10))
        core.perform(.click, now: at(21))
        suite.expect(core.reveal == .hidden && core.blockers == [.iconInside] && core.machine.pinned
                        && core.machine.deadline == nil,
                     "a collapse that would hide Zenith's icon is refused and the bar stays open")
        host.framesValue = MenuBarHiderFrames(main: item(1300), chevron: item(1278), divider: item(1258, width: 10))
        core.perform(.click, now: at(22))
        suite.expect(core.reveal == .collapsed && core.blockers.isEmpty, "once the icon is moved back, hiding works")
        host.framesValue = MenuBarHiderFrames(main: item(1100), chevron: item(1278), divider: item(1258, width: 10_000))
        core.refresh(now: at(23))
        core.tick(now: at(24))
        suite.expect(core.reveal == .hidden && core.blockers == [.iconInside],
                     "an icon found hidden after a change of screens is brought back")
        host.framesValue = MenuBarHiderFrames()
        core.screenLocked(now: at(25))
        suite.expect(core.reveal == .collapsed, "locking the Mac collapses")

        // Switching on from Settings leaves everything showing for arranging.
        let fresh = FakeHost()
        let arranging = MenuBarHiderCore(host: fresh, sensing: sensing, settings: MenuBarHiderSettings())
        arranging.sync(enabled(), now: start, interactive: true)
        suite.expect(fresh.isInstalled && arranging.reveal == .hidden && arranging.machine.pinned
                        && fresh.applied.last == shownHidden,
                     "turning hiding on shows the divider and hides nothing yet")
        arranging.clickedOutside(now: at(1))
        arranging.tick(now: at(30))
        suite.expect(arranging.reveal == .hidden, "nothing tucks away until the person collapses it")
        arranging.sync(MenuBarHiderSettings(), now: at(31), interactive: true)
        suite.expect(!fresh.isInstalled && fresh.removedWithLengths == shownHidden && arranging.nextWake == nil,
                     "turning it off removes the items with short dividers, so their places stay where they were seen")

        // The always hidden section.
        let host2 = FakeHost()
        let full = MenuBarHiderCore(host: host2, sensing: sensing, settings: MenuBarHiderSettings())
        full.sync(enabled { $0.alwaysHidden = true }, now: start, interactive: false)
        suite.expect(host2.hasAlwaysDivider && host2.applied.last == MenuBarHiderLengths(divider: 10_000, alwaysDivider: 10_000),
                     "the always hidden divider is created long too")
        full.perform(.click, now: at(1))
        suite.expect(full.reveal == .hidden
                        && host2.applied.last == MenuBarHiderLengths(divider: MenuBarHiderLayout.dividerLength, alwaysDivider: 10_000),
                     "a plain click leaves the always hidden icons away")
        full.perform(.optionClick, now: at(2))
        suite.expect(full.reveal == .all && full.notchCheckAt == at(2 + MenuBarHiderCore.notchSettle)
                        && host2.applied.last == MenuBarHiderLengths(divider: MenuBarHiderLayout.dividerLength,
                                                                      alwaysDivider: MenuBarHiderLayout.alwaysDividerLength),
                     "⌥-click shows them, and checks the notch once they are placed")
        sensing.overflows = true
        full.tick(now: at(2.2))
        suite.expect(full.reveal == .hidden && full.notchFallback && full.machine.deadline == at(12),
                     "always hidden icons that land behind the notch go away again, keeping the timer")
        full.perform(.optionClick, now: at(3))
        full.sync(enabled { $0.alwaysHidden = true; $0.notchGuard = false }, now: at(3.05), interactive: true)
        full.tick(now: at(3.2))
        suite.expect(full.reveal == .all, "with the notch guard off they stay, behind the notch or not")
        sensing.overflows = false

        host2.framesValue = MenuBarHiderFrames(main: item(1300), chevron: item(1278), divider: item(1258, width: 10),
                                               alwaysDivider: item(1290, width: 12))
        full.perform(.hide, now: at(4))
        suite.expect(full.reveal == .collapsed && full.blockers == [.alwaysOutside]
                        && host2.applied.last == collapsedHidden,
                     "a misplaced always hidden divider is ignored and kept short, and hiding still works")
        full.perform(.optionClick, now: at(5))
        suite.expect(full.reveal == .hidden, "while it is misplaced, ⌥-click shows only the hidden icons")
        full.sync(enabled { $0.alwaysHidden = false }, now: at(6), interactive: true)
        suite.expect(!host2.hasAlwaysDivider && full.blockers.isEmpty, "switching the section off removes its divider")
    }

    // MARK: Shortcut and words

    private static func shortcut(_ suite: TestSuite) {
        let role = GlobalShortcutRole.menuBarHider
        suite.expect(role.storageKey == DefaultsKey.menuBarHiderShortcut && role.defaultShortcut == .menuBarHiderDefault
                        && role.requiredEnableKeys == [DefaultsKey.menuBarHiderEnabled, DefaultsKey.menuBarHiderShortcutEnabled]
                        && role.feature == .quickToggles,
                     "the shortcut role is wired to the hider's own keys and lists with Quick Controls")
        suite.expect(GlobalShortcut.menuBarHiderDefault == GlobalShortcut(keyCode: 11, modifiers: [.control, .option, .command]),
                     "the default shortcut is Control-Option-Command-B")
        suite.expect(GlobalShortcutRole.allCases.filter { $0.defaultShortcut == .menuBarHiderDefault } == [.menuBarHider],
                     "no other action ships the same combination")
        suite.expect(!GlobalShortcutRole.activeRoles(isOn: { $0 != DefaultsKey.menuBarHiderShortcutEnabled }).contains(role),
                     "the shortcut is only live once switched on")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.menuBarHider(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 34 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("—") },
                         "\(language.rawValue) words the menu bar hider, with curly apostrophes and no em dash")
            suite.expect(String(format: text.secondsFormat, 30).contains("30") && text.behindNotch.contains("%@")
                            && !text.secondsFormat.contains("%@") && !text.behindNotch.contains("%d"),
                         "\(language.rawValue) keeps the placeholders")
        }
        suite.expect(GlobalShortcutRole.menuBarHider.title(L10n.shared.s) == ZenithStrings.menuBarHider(L10n.shared.language).shortcut,
                     "the shortcut is named for what it does")
    }
}
