// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the menu bar hider's decisions, kept free of AppKit so the
// harness drives them with a fake clock and fake status items. The live
// status items, event monitors and window probes are in MenuBarHiderService.
//
// The technique is the familiar one: Zenith owns a chevron and one or two
// divider status items. A divider whose length is very large pushes every
// item to its left off the screen; a short one lets them back. The person
// arranges which icons are hidden by ⌘-dragging them past a divider, and
// macOS remembers every position under the items' autosave names.

extension Notification.Name {
    /// A shortcut field stopped listening, so held keys register again.
    static let zenithShortcutCaptureEnded = Notification.Name("ZenithShortcutCaptureEnded")
}

// MARK: - Settings

/// How long revealed icons stay before they tuck away again.
enum MenuBarHiderDelay: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case thirty = 30
    case never = 0

    static let standard: MenuBarHiderDelay = .ten

    var id: Int { rawValue }
    var interval: TimeInterval? { self == .never ? nil : TimeInterval(rawValue) }

    /// An unknown or missing value reads as the standard delay, never as
    /// "never": a missing integer would otherwise read back as zero.
    static func stored(_ value: Any?) -> MenuBarHiderDelay {
        let raw = (value as? Int) ?? (value as? NSNumber)?.intValue
        return raw.flatMap(MenuBarHiderDelay.init(rawValue:)) ?? standard
    }
}

struct MenuBarHiderSettings: Equatable {
    var enabled = false
    var alwaysHidden = false
    var delay = MenuBarHiderDelay.standard
    var collapseOnClickOutside = true
    var showOnHover = false
    var notchGuard = true
    var shortcutEnabled = false

    static func read(_ defaults: UserDefaults) -> MenuBarHiderSettings {
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        let standard = MenuBarHiderSettings()
        return MenuBarHiderSettings(
            enabled: flag(DefaultsKey.menuBarHiderEnabled, standard.enabled),
            alwaysHidden: flag(DefaultsKey.menuBarHiderAlwaysHidden, standard.alwaysHidden),
            delay: .stored(defaults.object(forKey: DefaultsKey.menuBarHiderDelay)),
            collapseOnClickOutside: flag(DefaultsKey.menuBarHiderCollapseOnClick, standard.collapseOnClickOutside),
            showOnHover: flag(DefaultsKey.menuBarHiderShowOnHover, standard.showOnHover),
            notchGuard: flag(DefaultsKey.menuBarHiderNotchGuard, standard.notchGuard),
            shortcutEnabled: flag(DefaultsKey.menuBarHiderShortcutEnabled, standard.shortcutEnabled))
    }

    /// The preferences Settings backs up, with their first-run values.
    static var registered: [String: Any] {
        let standard = MenuBarHiderSettings()
        return [
            DefaultsKey.menuBarHiderEnabled: standard.enabled,
            DefaultsKey.menuBarHiderAlwaysHidden: standard.alwaysHidden,
            DefaultsKey.menuBarHiderDelay: standard.delay.rawValue,
            DefaultsKey.menuBarHiderCollapseOnClick: standard.collapseOnClickOutside,
            DefaultsKey.menuBarHiderShowOnHover: standard.showOnHover,
            DefaultsKey.menuBarHiderNotchGuard: standard.notchGuard,
            DefaultsKey.menuBarHiderShortcutEnabled: standard.shortcutEnabled,
        ]
    }
}

// MARK: - State machine

/// What the menu bar shows: only the visible icons, the hidden section too,
/// or every section including the always hidden one.
enum MenuBarHiderReveal: String, Equatable {
    case collapsed, hidden, all
}

enum MenuBarHiderTrigger: Equatable {
    /// A click on the chevron or a divider, or the empty menu bar the
    /// collapsed divider covers.
    case click
    /// ⌥-click: the always hidden section too.
    case optionClick
    case shortcut
    /// The pointer resting on an empty part of the menu bar.
    case hover
    case showHidden
    case showAll
    case hide
}

/// What the probes saw at the moment a collapse came due.
struct MenuBarHiderEnvironment: Equatable {
    /// Some app's menu, perhaps one of the revealed items', is open.
    var menuOpen = false
    var mouseDown = false
    var pointerInMenuBar = false

    /// Collapsing now would pull the items out from under the person.
    var holdsOpen: Bool { menuOpen || mouseDown || pointerInMenuBar }
}

/// Reveal, auto-collapse and hover rules. Time always comes in as an
/// argument, so the harness runs it on a fake clock.
struct MenuBarHiderMachine: Equatable {
    /// How soon a collapse held off by an open menu or a pressed button is tried again.
    static let retryInterval: TimeInterval = 1
    /// A click elsewhere lands before the menu it closes has gone; a short
    /// grace lets the menu probe see the menu close first.
    static let clickOutsideGrace: TimeInterval = 0.3
    /// Icons revealed by hovering tuck away this long after the pointer leaves.
    static let hoverLeaveGrace: TimeInterval = 0.8

    private(set) var settings: MenuBarHiderSettings
    private(set) var reveal: MenuBarHiderReveal = .collapsed
    private(set) var deadline: Date?
    private(set) var revealedByHover = false
    /// Revealed for arranging, right after the feature was switched on, or
    /// held open because collapsing would hide Zenith's own icon: no timer,
    /// no click elsewhere, only an explicit action or a lock collapses it.
    private(set) var pinned = false

    init(settings: MenuBarHiderSettings) {
        self.settings = settings
    }

    var isExpanded: Bool { reveal != .collapsed }

    /// Where a trigger takes the bar from `reveal`, nil when it does nothing.
    /// The always hidden section only ever opens on purpose: ⌥-click or the
    /// chevron's menu, never on hover or the shortcut.
    static func target(for trigger: MenuBarHiderTrigger, from reveal: MenuBarHiderReveal,
                       alwaysHidden: Bool) -> MenuBarHiderReveal? {
        switch trigger {
        case .click, .shortcut:
            return reveal == .collapsed ? .hidden : .collapsed
        case .optionClick:
            guard alwaysHidden else { return reveal == .collapsed ? .hidden : .collapsed }
            return reveal == .all ? .collapsed : .all
        case .hover:
            return reveal == .collapsed ? .hidden : nil
        case .showHidden:
            return .hidden
        case .showAll:
            return alwaysHidden ? .all : .hidden
        case .hide:
            return .collapsed
        }
    }

    /// Moves to the reveal a trigger asks for and starts its timer.
    @discardableResult
    mutating func handle(_ trigger: MenuBarHiderTrigger, now: Date) -> Bool {
        guard let target = Self.target(for: trigger, from: reveal, alwaysHidden: settings.alwaysHidden)
        else { return false }
        return move(to: target, now: now, byHover: trigger == .hover)
    }

    @discardableResult
    mutating func move(to target: MenuBarHiderReveal, now: Date, byHover: Bool = false, pin: Bool = false) -> Bool {
        let resolved = target == .all && !settings.alwaysHidden ? .hidden : target
        let changed = resolved != reveal
        reveal = resolved
        guard resolved != .collapsed else {
            deadline = nil
            revealedByHover = false
            pinned = false
            return changed
        }
        revealedByHover = byHover
        pinned = pin
        deadline = pin ? nil : settings.delay.interval.map { now.addingTimeInterval($0) }
        return changed
    }

    @discardableResult
    mutating func collapse() -> Bool {
        move(to: .collapsed, now: .distantPast)
    }

    /// Keeps the bar open with no timer, for when collapsing would hide what
    /// must stay visible.
    mutating func hold() {
        guard isExpanded else { return }
        deadline = nil
        pinned = true
        revealedByHover = false
    }

    func isDue(_ now: Date) -> Bool {
        guard isExpanded, let deadline else { return false }
        return now >= deadline
    }

    /// A collapse came due while something still holds the bar open.
    mutating func postpone(_ now: Date) {
        guard isExpanded else { return }
        deadline = now.addingTimeInterval(Self.retryInterval)
    }

    mutating func clickedOutside(_ now: Date) {
        guard isExpanded, !pinned, settings.collapseOnClickOutside else { return }
        bringDeadline(to: now.addingTimeInterval(Self.clickOutsideGrace))
    }

    mutating func pointerLeftMenuBar(_ now: Date) {
        guard isExpanded, revealedByHover, !pinned else { return }
        bringDeadline(to: now.addingTimeInterval(Self.hoverLeaveGrace))
    }

    /// The Mac locked, slept or switched user: everything tucks away at once.
    @discardableResult
    mutating func screenLocked() -> Bool {
        collapse()
    }

    mutating func update(_ settings: MenuBarHiderSettings, now: Date) {
        let previous = self.settings
        self.settings = settings
        guard settings.enabled else {
            collapse()
            return
        }
        if reveal == .all, !settings.alwaysHidden { reveal = .hidden }
        if previous.delay != settings.delay, isExpanded, !pinned {
            deadline = settings.delay.interval.map { now.addingTimeInterval($0) }
        }
    }

    private mutating func bringDeadline(to date: Date) {
        if let deadline, deadline <= date { return }
        deadline = date
    }
}

// MARK: - Geometry

struct MenuBarHiderLengths: Equatable {
    var divider: CGFloat
    var alwaysDivider: CGFloat?
}

/// Window frames of the items, in screen points. Nil when an item is not in
/// the bar, or not yet placed.
struct MenuBarHiderFrames: Equatable {
    var main: CGRect?
    var chevron: CGRect?
    var divider: CGRect?
    var alwaysDivider: CGRect?
}

/// Why the items cannot be arranged as they are.
enum MenuBarHiderBlocker: String, Equatable {
    /// Zenith's own icon is left of the divider and would hide with the rest.
    case iconInside
    /// The chevron is left of the divider and would hide with the rest.
    case chevronInside
    /// The always hidden divider is right of the main one, so it is ignored.
    case alwaysOutside

    var blocksCollapse: Bool { self != .alwaysOutside }
}

enum MenuBarHiderLayout {
    static let chevronLength: CGFloat = 20
    static let dividerLength: CGFloat = 10
    static let alwaysDividerLength: CGFloat = 12
    /// Far wider than any menu bar, so nothing to its left stays on screen.
    static let minimumCollapsedLength: CGFloat = 10_000

    static func collapsedLength(screenWidths: [CGFloat]) -> CGFloat {
        max(minimumCollapsedLength, (screenWidths.max() ?? 0) * 2)
    }

    /// The always hidden divider only ever opens together with the main one,
    /// so its section never shows on its own.
    static func lengths(reveal: MenuBarHiderReveal, alwaysHidden: Bool,
                        collapsedLength: CGFloat) -> MenuBarHiderLengths {
        let divider = reveal == .collapsed ? collapsedLength : dividerLength
        guard alwaysHidden else {
            return MenuBarHiderLengths(divider: divider, alwaysDivider: nil)
        }
        return MenuBarHiderLengths(divider: divider,
                                   alwaysDivider: reveal == .all ? alwaysDividerLength : collapsedLength)
    }

    /// Items never overlap in the bar, and a divider grows to the left, so
    /// right edges order the items whatever length a divider has right now.
    static func isLeft(_ item: CGRect, of other: CGRect) -> Bool {
        item.maxX < other.maxX - 0.5
    }

    /// Unknown frames block nothing: an item that is not placed yet cannot be
    /// judged, and the next check sees it.
    static func blockers(_ frames: MenuBarHiderFrames) -> [MenuBarHiderBlocker] {
        guard let divider = frames.divider else { return [] }
        var found: [MenuBarHiderBlocker] = []
        if let main = frames.main, !isLeft(divider, of: main) { found.append(.iconInside) }
        if let chevron = frames.chevron, !isLeft(divider, of: chevron) { found.append(.chevronInside) }
        if let always = frames.alwaysDivider, !isLeft(always, of: divider) { found.append(.alwaysOutside) }
        return found
    }

    // MARK: Notch

    /// The camera housing between the two usable top areas of a notched
    /// screen, nil on a screen without one.
    static func notchGap(topLeft: CGRect?, topRight: CGRect?) -> CGRect? {
        guard let topLeft, let topRight, topRight.minX > topLeft.maxX + 1 else { return nil }
        return CGRect(x: topLeft.maxX, y: min(topLeft.minY, topRight.minY),
                      width: topRight.minX - topLeft.maxX, height: max(topLeft.height, topRight.height))
    }

    /// macOS never shows a status item left of the camera, so one that starts
    /// left of the gap's right edge is behind the notch or dropped.
    static func reachesNotch(_ frame: CGRect, gap: CGRect) -> Bool {
        frame.minX < gap.maxX - 0.5
    }

    static func isBehindNotch(_ frame: CGRect, gap: CGRect) -> Bool {
        frame.minX < gap.maxX - 0.5 && frame.maxX > gap.minX + 0.5
    }

    /// Whether showing the always hidden section put any of it where it
    /// cannot be clicked. `items` are other status items on that screen.
    static func alwaysHiddenOverflows(alwaysDivider: CGRect, items: [CGRect], gap: CGRect) -> Bool {
        if reachesNotch(alwaysDivider, gap: gap) { return true }
        return items.contains { isLeft($0, of: alwaysDivider) && reachesNotch($0, gap: gap) }
    }

    // MARK: Hover

    /// Without the app menus' extent or a notch to stop at, hovering only
    /// counts this close to the visible icons.
    static let hoverFallbackWidth: CGFloat = 160

    /// The empty stretch of the menu bar the collapsed divider covers: from
    /// the app menus (or the notch) to the first visible icon.
    static func hoverBand(screen: CGRect, barHeight: CGFloat, dividerMaxX: CGFloat,
                          leftLimits: [CGFloat]) -> CGRect? {
        let left = leftLimits.max() ?? dividerMaxX - hoverFallbackWidth
        let minX = max(screen.minX, left + 4)
        let maxX = min(screen.maxX, dividerMaxX)
        guard maxX - minX >= 8, barHeight > 0 else { return nil }
        return CGRect(x: minX, y: screen.maxY - barHeight, width: maxX - minX, height: barHeight)
    }

    static func contains(_ band: CGRect, _ point: CGPoint) -> Bool {
        point.x >= band.minX && point.x < band.maxX && point.y >= band.minY && point.y <= band.maxY + 1
    }
}

// MARK: - Placement

/// The items' autosave names and their first placement. macOS keeps each
/// item's position under `NSStatusItem Preferred Position <name>`, counted
/// from the right edge of the screen; an item without one is born at the
/// left end of the status area, against the notch. So the first time, the
/// chevron and the dividers are seeded just left of Zenith's own icon.
enum MenuBarHiderPlacement {
    static let chevronName = "ZenithMenuBarHiderChevron"
    static let dividerName = "ZenithMenuBarHiderDivider"
    static let alwaysDividerName = "ZenithMenuBarHiderAlwaysDivider"
    static let allNames = [chevronName, dividerName, alwaysDividerName]

    static func positionKey(_ name: String) -> String { "NSStatusItem Preferred Position \(name)" }

    static func visibilityKeys(_ name: String) -> [String] {
        ["NSStatusItem Visible \(name)", "NSStatusItem VisibleCC \(name)"]
    }

    /// Writes a position for each of the items that has none yet, one step
    /// further left than the item to its right. `mainDistance` stands in for
    /// the icon's saved position when it has none, measured from its frame.
    /// Positions already saved, the person's own arrangement, are kept.
    static func seed(in defaults: UserDefaults, mainAutosaveName: String,
                     mainDistance: Double?, alwaysHidden: Bool) {
        func stored(_ name: String) -> Double? {
            (defaults.object(forKey: positionKey(name)) as? NSNumber)?.doubleValue
        }
        guard var previous = stored(mainAutosaveName) ?? mainDistance else { return }
        let names = alwaysHidden ? allNames : [chevronName, dividerName]
        for name in names {
            if let saved = stored(name) {
                previous = saved
                continue
            }
            previous += 1
            defaults.set(previous, forKey: positionKey(name))
        }
    }

    /// The icon's distance from the right edge of its screen, the same
    /// measure macOS saves, for an icon that has no saved position yet.
    static func distance(of frame: CGRect, screens: [CGRect]) -> Double? {
        guard let screen = screens.first(where: { $0.minX <= frame.midX && frame.midX <= $0.maxX }) else { return nil }
        return Double(max(0, screen.maxX - frame.maxX))
    }
}

// MARK: - Glyph motion

/// The chevron turns half a circle on the Style Kit's spring curve,
/// `cubic-bezier(.34, 1.36, .5, 1)` over `ZenithMotion.standard`.
enum MenuBarHiderGlyphMotion {
    static let duration: TimeInterval = 0.3

    /// The curve's height at time `t` (0...1), overshooting a little past 1.
    static func progress(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        if t == 0 || t == 1 { return t }
        let (x1, y1, x2, y2) = (0.34, 1.36, 0.5, 1.0)
        func bezier(_ s: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s
        }
        func slope(_ s: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * a + 6 * u * s * (b - a) + 3 * s * s * (1 - b)
        }
        // Newton on x(s) = t, falling back to bisection where the slope is flat.
        var s = t
        for _ in 0..<8 {
            let error = bezier(s, x1, x2) - t
            if abs(error) < 1e-6 { break }
            let d = slope(s, x1, x2)
            guard abs(d) > 1e-6 else { break }
            s = min(max(s - error / d, 0), 1)
        }
        if abs(bezier(s, x1, x2) - t) > 1e-4 {
            var low = 0.0, high = 1.0
            for _ in 0..<40 {
                s = (low + high) / 2
                if bezier(s, x1, x2) < t { low = s } else { high = s }
            }
        }
        return bezier(s, y1, y2)
    }

    /// The chevron's angle `elapsed` seconds into a turn from `from` to `to`.
    static func angle(from: Double, to: Double, elapsed: TimeInterval) -> Double {
        from + (to - from) * progress(elapsed / duration)
    }

    /// Collapsed, the chevron points left at what it can show; open, right.
    static func restingAngle(expanded: Bool) -> Double { expanded ? Double.pi : 0 }
}

// MARK: - Core

/// The live status items, behind a protocol so the harness never creates any.
protocol MenuBarHiderItemHost: AnyObject {
    var isInstalled: Bool { get }
    var hasAlwaysDivider: Bool { get }
    func install(alwaysHidden: Bool)
    func uninstall()
    func setAlwaysDivider(_ installed: Bool)
    func apply(_ lengths: MenuBarHiderLengths)
    func showExpanded(_ expanded: Bool, animated: Bool)
    func frames() -> MenuBarHiderFrames
}

/// What the core asks of the screen and the window server.
protocol MenuBarHiderSensing: AnyObject {
    var collapsedLength: CGFloat { get }
    func environment() -> MenuBarHiderEnvironment
    /// Whether the always hidden section, just shown, landed behind the notch.
    func alwaysHiddenOverflowsNotch(_ frames: MenuBarHiderFrames) -> Bool
    /// Names of the apps whose icons sit behind the notch right now.
    func namesBehindNotch() -> [String]
}

/// Ties the machine to the status items: applies lengths, checks the order
/// of the items before anything hides, and keeps the always hidden section
/// clear of the notch. One timer in the service wakes it at `nextWake`.
final class MenuBarHiderCore {
    /// After items are placed, and after each reveal, the order is checked once
    /// macOS has laid the bar out.
    static let installSettle: TimeInterval = 1
    static let revealSettle: TimeInterval = 0.3
    static let notchSettle: TimeInterval = 0.15

    private let host: MenuBarHiderItemHost
    private let sensing: MenuBarHiderSensing
    private(set) var machine: MenuBarHiderMachine
    private(set) var blockers: [MenuBarHiderBlocker] = []
    private(set) var behindNotch: [String] = []
    /// The last ⌥-reveal fell back to the hidden section because of the notch.
    private(set) var notchFallback = false
    private(set) var orderCheckAt: Date?
    private(set) var notchCheckAt: Date?

    init(host: MenuBarHiderItemHost, sensing: MenuBarHiderSensing, settings: MenuBarHiderSettings) {
        self.host = host
        self.sensing = sensing
        machine = MenuBarHiderMachine(settings: settings)
    }

    var settings: MenuBarHiderSettings { machine.settings }
    var reveal: MenuBarHiderReveal { machine.reveal }

    var nextWake: Date? {
        [machine.deadline, orderCheckAt, notchCheckAt].compactMap { $0 }.min()
    }

    /// The always hidden section is in use when it is on and its divider sits
    /// where it should.
    private var alwaysHiddenUsable: Bool {
        settings.alwaysHidden && !blockers.contains(.alwaysOutside)
    }

    /// `interactive` is true when the person just changed a setting: turning
    /// the feature on then leaves everything showing, so nothing vanishes
    /// before they have arranged it.
    func sync(_ settings: MenuBarHiderSettings, now: Date, interactive: Bool) {
        machine.update(settings, now: now)
        guard settings.enabled else {
            if host.isInstalled {
                // Back to short dividers first, so the saved places are where
                // the person last saw them.
                host.apply(MenuBarHiderLayout.lengths(reveal: .all, alwaysHidden: host.hasAlwaysDivider,
                                                      collapsedLength: sensing.collapsedLength))
                host.uninstall()
            }
            blockers = []
            behindNotch = []
            notchFallback = false
            orderCheckAt = nil
            notchCheckAt = nil
            return
        }
        if !host.isInstalled {
            host.install(alwaysHidden: settings.alwaysHidden)
            if interactive { machine.move(to: .hidden, now: now, pin: true) }
            apply(animated: false)
            orderCheckAt = now.addingTimeInterval(Self.installSettle)
            return
        }
        if host.hasAlwaysDivider != settings.alwaysHidden {
            host.setAlwaysDivider(settings.alwaysHidden)
            if !settings.alwaysHidden { blockers.removeAll { $0 == .alwaysOutside } }
            orderCheckAt = now.addingTimeInterval(Self.installSettle)
        }
        apply(animated: false)
    }

    func perform(_ trigger: MenuBarHiderTrigger, now: Date) {
        guard settings.enabled, host.isInstalled else { return }
        let alwaysHidden = alwaysHiddenUsable
        guard let target = MenuBarHiderMachine.target(for: trigger, from: machine.reveal, alwaysHidden: alwaysHidden)
        else { return }
        if target == .collapsed {
            collapse(now: now)
            return
        }
        machine.move(to: alwaysHidden ? target : (target == .all ? .hidden : target), now: now,
                     byHover: trigger == .hover)
        notchFallback = false
        apply(animated: true)
        orderCheckAt = now.addingTimeInterval(Self.revealSettle)
        if machine.reveal == .all, settings.notchGuard {
            notchCheckAt = now.addingTimeInterval(Self.notchSettle)
        }
    }

    func clickedOutside(now: Date) { machine.clickedOutside(now) }
    func pointerLeftMenuBar(now: Date) { machine.pointerLeftMenuBar(now) }

    func screenLocked(now: Date) {
        guard machine.isExpanded else { return }
        collapse(now: now)
    }

    /// Re-applies the lengths, for a change of screens.
    func refresh(now: Date) {
        guard host.isInstalled else { return }
        apply(animated: false)
        orderCheckAt = now.addingTimeInterval(Self.installSettle)
    }

    func tick(now: Date) {
        if let at = orderCheckAt, now >= at {
            orderCheckAt = nil
            checkOrder(now: now)
        }
        if let at = notchCheckAt, now >= at {
            notchCheckAt = nil
            checkNotch()
        }
        if machine.isDue(now) {
            if sensing.environment().holdsOpen {
                machine.postpone(now)
            } else {
                collapse(now: now)
            }
        }
    }

    /// Collapses unless that would hide Zenith's icon or the chevron itself;
    /// then the bar stays open and Settings says why.
    @discardableResult
    func collapse(now: Date) -> Bool {
        blockers = MenuBarHiderLayout.blockers(host.frames())
        if blockers.contains(where: \.blocksCollapse) {
            machine.hold()
            apply(animated: false)
            return false
        }
        let changed = machine.collapse()
        notchFallback = false
        notchCheckAt = nil
        apply(animated: true)
        return changed
    }

    private func checkOrder(now: Date) {
        let wasUsable = alwaysHiddenUsable
        blockers = MenuBarHiderLayout.blockers(host.frames())
        behindNotch = sensing.namesBehindNotch()
        if !machine.isExpanded, blockers.contains(where: \.blocksCollapse) {
            // Something that must stay visible is already out of sight.
            machine.move(to: .hidden, now: now, pin: true)
            apply(animated: true)
        } else if wasUsable != alwaysHiddenUsable {
            apply(animated: false)
        }
    }

    private func checkNotch() {
        guard machine.reveal == .all, settings.notchGuard,
              sensing.alwaysHiddenOverflowsNotch(host.frames()) else { return }
        machine.narrow(to: .hidden)
        notchFallback = true
        apply(animated: false)
    }

    private func apply(animated: Bool) {
        host.apply(MenuBarHiderLayout.lengths(reveal: machine.reveal, alwaysHidden: alwaysHiddenUsable,
                                              collapsedLength: sensing.collapsedLength))
        host.showExpanded(machine.isExpanded, animated: animated)
    }
}

extension MenuBarHiderMachine {
    /// Shows less without touching the timer or why the bar is open.
    mutating func narrow(to target: MenuBarHiderReveal) {
        guard isExpanded, target != .collapsed else { return }
        reveal = target
    }
}
