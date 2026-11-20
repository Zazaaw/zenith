// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: the customisable home page (ZenithHomeLayoutSupport): adding,
/// removing and reordering widgets within the row's limits, persistence and
/// backups, the migration from the old home page and the Music switch it
/// keeps following, the island's size, the edit mode's draft, the shortcut
/// row (ZenithHomeShortcutsSupport: adding, removing, reordering, availability,
/// fitting the row, upstream's keys and backups, cancel and done), and the
/// strings.
enum HomeLayoutTests {
    static func run(_ suite: TestSuite) {
        editing(suite)
        limits(suite)
        persistence(suite)
        migration(suite)
        availability(suite)
        islandSize(suite)
        editMode(suite)
        shortcutEditing(suite)
        shortcutAvailability(suite)
        shortcutFitting(suite)
        shortcutPersistence(suite)
        shortcutEditMode(suite)
        strings(suite)
    }

    private static let suiteName = "com.vorssaint.tests.home-layout"

    private static func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func editing(_ suite: TestSuite) {
        let empty = ZenithHomeLayout()
        let two = empty.adding(.nowPlaying).adding(.timer)
        suite.expect(two.widgets == [.nowPlaying, .timer], "an added widget joins the end of the row")
        suite.expect(two.adding(.timer) == two, "a widget already in the row is not added twice")
        suite.expect(two.removing(.nowPlaying).widgets == [.timer] && two.removing(.weather) == two,
                     "removing takes only that widget out, and a missing one changes nothing")
        let three = two.adding(.clipboard)
        suite.expect(three.moving(.clipboard, to: 0).widgets == [.clipboard, .nowPlaying, .timer]
                     && three.moving(.nowPlaying, to: 9).widgets == [.timer, .clipboard, .nowPlaying]
                     && three.moving(.nowPlaying, to: -3).widgets == [.nowPlaying, .timer, .clipboard]
                     && three.moving(.weather, to: 0) == three,
                     "moving reorders within the row, clamped at both ends, and ignores a widget not in it")
        suite.expect(ZenithHomeLayout([.timer, .timer, .weather]).widgets == [.timer, .weather],
                     "a repeated widget keeps its first place")
    }

    private static func limits(_ suite: TestSuite) {
        let full = ZenithHomeLayout([.nowPlaying, .timer, .weather])
        suite.expect(ZenithHomeLayout.maximum == 3 && full.count == 3 && !full.canAdd(.clipboard)
                     && full.adding(.clipboard) == full,
                     "the row holds three widgets side by side and no more")
        suite.expect(ZenithHomeLayout(ZenithHomeWidget.allCases).count == ZenithHomeLayout.maximum,
                     "a longer list is cut to the row's maximum")
        let two = ZenithHomeLayout([.nowPlaying, .timer])
        let room = ZenithHomeLayout.contentWidth([.nowPlaying, .timer, .clipboard])
        suite.expect(two.canAdd(.clipboard, maximumWidth: room) && !two.canAdd(.clipboard, maximumWidth: room - 1)
                     && two.adding(.clipboard, maximumWidth: room - 1) == two,
                     "a widget that would make the row wider than the display allows is not offered")
        suite.expect(ZenithHomeLayout.contentWidth([]) == 0
                     && ZenithHomeLayout.contentWidth([.weather]) == ZenithHomeWidget.weather.width
                     && two.contentWidth == ZenithHomeWidget.nowPlaying.width + ZenithHomeWidget.timer.width
                        + ZenithHomeLayout.spacing,
                     "the row is its widgets' widths and the gaps between them")
        let display = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32, cameraWidth: 210)
        let small = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 640, height: 480), safeAreaTop: 0, cameraWidth: 0)
        let widest = ZenithHomeLayout.contentWidth(Array(ZenithHomeWidget.allCases.sorted { $0.width > $1.width }.prefix(3)))
        suite.expect(widest <= display.zenithHomeMaximumContentWidth
                     && small.zenithHomeMaximumContentWidth < widest
                     && small.zenithHomeMaximumContentWidth >= 0,
                     "a laptop display holds any three widgets; a small one limits what the strip offers")
    }

    private static func persistence(_ suite: TestSuite) {
        let layout = ZenithHomeLayout([.timer, .nowPlaying, .shelf])
        suite.expect(layout.encoded == "timer,nowPlaying,shelf"
                     && ZenithHomeLayout.decode(layout.encoded) == layout,
                     "a layout survives being stored, in order")
        suite.expect(ZenithHomeLayout.decode("") == ZenithHomeLayout() && ZenithHomeLayout().encoded == "",
                     "an empty home is stored as an empty list, not as never chosen")
        suite.expect(ZenithHomeLayout.decode(nil) == nil && ZenithHomeLayout.decode(ZenithHomeLayout.automatic) == nil
                     && ZenithHomeLayout.decode(" auto ") == nil,
                     "no value and the automatic marker both mean never customised")
        suite.expect(ZenithHomeLayout.decode("timer, hologram ,timer,weather")?.widgets == [.timer, .weather],
                     "unknown names from a later version are skipped and repeats keep their first place")
        suite.expect(ZenithHomeIsland.defaultsKey == DefaultsKey.zenithHomeLayout
                     && Defaults.registeredDefaults[DefaultsKey.zenithHomeLayout] as? String == ZenithHomeLayout.automatic
                     && SettingsBackupSupport.exportKeys().contains(DefaultsKey.zenithHomeLayout),
                     "the layout is registered, starts automatic, and travels with settings backups")

        let defaults = freshDefaults()
        defaults.set("", forKey: DefaultsKey.notchHiddenControls)
        ZenithHomeIsland.save(ZenithHomeLayout([.timer, .weather]), in: defaults)
        suite.expect(defaults.string(forKey: DefaultsKey.zenithHomeLayout) == "timer,weather"
                     && defaults.string(forKey: DefaultsKey.notchHiddenControls) == "music",
                     "saving a home without the player switches the home page's Music off")
        ZenithHomeIsland.save(ZenithHomeLayout([.nowPlaying, .timer]), in: defaults)
        suite.expect(defaults.string(forKey: DefaultsKey.notchHiddenControls) == ""
                     && ZenithHomeIsland.resolved(in: defaults, controlsHaveMusic: true).widgets == [.nowPlaying, .timer],
                     "saving a home with the player switches Music back on and reads back as saved")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func migration(_ suite: TestSuite) {
        suite.expect(ZenithHomeLayout.resolved(stored: nil, controlsHaveMusic: true).widgets == [.nowPlaying]
                     && ZenithHomeLayout.resolved(stored: ZenithHomeLayout.automatic, controlsHaveMusic: true).widgets == [.nowPlaying],
                     "a home page never customised shows the player, as it always did")
        suite.expect(ZenithHomeLayout.resolved(stored: nil, controlsHaveMusic: false).isEmpty,
                     "with the Music switch off, an uncustomised home page has no cards, as before")
        suite.expect(ZenithHomeLayout.resolved(stored: "nowPlaying,timer", controlsHaveMusic: false).widgets == [.timer],
                     "switching Music off in Settings takes the player out of a customised row")
        suite.expect(ZenithHomeLayout.resolved(stored: "timer,weather", controlsHaveMusic: true).widgets
                        == [.nowPlaying, .timer, .weather]
                     && ZenithHomeLayout.resolved(stored: "timer,weather,shelf", controlsHaveMusic: true).widgets
                        == [.nowPlaying, .timer, .weather],
                     "switching Music on brings the player back first, the last widget giving way in a full row")
        suite.expect(ZenithHomeLayout.hiddenControls("panel,scratchpad", showingMusic: false) == "music,panel,scratchpad"
                     && ZenithHomeLayout.hiddenControls("music,panel", showingMusic: true) == "panel"
                     && ZenithHomeLayout.hiddenControls("", showingMusic: true) == "",
                     "the hidden controls keep their sorted list form as Music follows the layout")
        let defaults = freshDefaults()
        suite.expect(ZenithHomeIsland.stored(in: defaults).widgets == [.nowPlaying],
                     "a Mac that never chose sees the default home page with its player")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func availability(_ suite: TestSuite) {
        let layout = ZenithHomeLayout([.nowPlaying, .timer, .weather])
        suite.expect(layout.shown(modules: [.controls, .music]) == [.nowPlaying, .weather]
                     && layout.shown(modules: [.controls, .timer]) == [.nowPlaying, .timer, .weather],
                     "a widget whose page is off waits, still chosen, while the player and the weather stand alone")
        suite.expect(ZenithHomeWidget.allCases.filter { $0.module == nil } == [.weather]
                     && ZenithHomeWidget.allCases.allSatisfy { $0.isAvailable(modules: NotchModule.allCases) },
                     "every widget shows with every page on")
        suite.expect(Set(ZenithHomeWidget.allCases.map(\.hex)).count == ZenithHomeWidget.allCases.count
                     && ZenithHomeWidget.allCases.allSatisfy { widget in
                         widget.module.map { ZenithIslandPalette.hex($0) == widget.hex } ?? true
                     },
                     "each widget has its own colour, its page's where it has one")
    }

    private static func islandSize(_ suite: TestSuite) {
        let single = ZenithHomeIsland.geometry(widgets: [.nowPlaying], editing: false)
        suite.expect(single.contentWidth == nil && single.hasCards && single.stripHeight == 0,
                     "a single card fills the row at the island's own width, as the player did")
        let none = ZenithHomeIsland.geometry(widgets: [], editing: false)
        suite.expect(none.contentWidth == nil && !none.hasCards, "an empty home page has no card row")
        suite.expect(ZenithHomeIsland.geometry(widgets: [], editing: true).hasCards
                     && ZenithHomeIsland.geometry(widgets: [], editing: true).stripHeight
                        == ZenithHomeIsland.stripHeight + ZenithHomeIsland.stripSpacing,
                     "edit mode keeps the row's room and adds the strip below it")

        let base = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32, cameraWidth: 210)
        var home = base.page(.controls, controls: [.volume, .music, .keepAwake], sectionsButton: false)
        let plain = home.expandedSize(module: .controls, controlsHaveMusic: true)
        home.zenithHome = ZenithHomeIsland.geometry(widgets: [.nowPlaying], editing: false)
        suite.expect(home.expandedSize(module: .controls, controlsHaveMusic: true) == plain,
                     "the player alone leaves the home page exactly as it was")
        let three: [ZenithHomeWidget] = [.nowPlaying, .timer, .clipboard]
        home.zenithHome = ZenithHomeIsland.geometry(widgets: three, editing: false)
        let wide = home.expandedSize(module: .controls, controlsHaveMusic: true)
        suite.expect(wide.width == ZenithHomeLayout.contentWidth(three) + NotchLayout.horizontalInset * 2
                     && wide.width > plain.width && wide.height == plain.height,
                     "widgets side by side widen the island to fit them, keeping its height")
        home.zenithHome = ZenithHomeIsland.geometry(widgets: three, editing: true)
        let editingSize = home.expandedSize(module: .controls, controlsHaveMusic: true)
        suite.expect(editingSize.height == plain.height + ZenithHomeIsland.stripHeight + ZenithHomeIsland.stripSpacing
                     && editingSize.width == wide.width,
                     "edit mode grows the island by the strip, at the same width")
        home.zenithHome = ZenithHomeIsland.geometry(widgets: [.timer], editing: false)
        suite.expect(home.expandedSize(module: .controls, controlsHaveMusic: false).height == plain.height,
                     "a widget other than the player keeps the card row the player had")
        let small = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 640, height: 480), safeAreaTop: 0, cameraWidth: 0)
        var cramped = small.page(.controls, controls: [.music], sectionsButton: false)
        cramped.zenithHome = ZenithHomeIsland.geometry(widgets: three, editing: false)
        suite.expect(cramped.expandedWidth <= small.screen.width - 24,
                     "the island never grows past the display's edge")
    }

    private static func editMode(_ suite: TestSuite) {
        let defaults = freshDefaults()
        let saved = ZenithHomeIsland.editing, savedDraft = ZenithHomeIsland.draft
        ZenithHomeIsland.editing = true
        ZenithHomeIsland.draft = ZenithHomeLayout([.weather, .system])
        suite.expect(ZenithHomeIsland.current(in: defaults).widgets == [.weather, .system]
                     && ZenithHomeIsland.geometry(modules: NotchModule.allCases, in: defaults).stripHeight > 0,
                     "while editing, the island sizes the draft, with its strip")
        ZenithHomeIsland.editing = false
        ZenithHomeIsland.draft = nil
        suite.expect(ZenithHomeIsland.current(in: defaults).widgets == [.nowPlaying]
                     && defaults.persistentDomain(forName: suiteName)?[DefaultsKey.zenithHomeLayout] == nil,
                     "cancelling leaves the stored home page untouched")
        ZenithHomeIsland.editing = saved
        ZenithHomeIsland.draft = savedDraft
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: Shortcuts

    private static let everyShortcut = Set(ZenithHomeShortcuts.candidates)

    /// A row of `items`, every other shortcut switched off.
    private static func row(_ items: [NotchControlItem]) -> ZenithHomeShortcuts {
        ZenithHomeShortcuts(order: [], hidden: everyShortcut.subtracting(items))
    }

    private static func shortcutEditing(_ suite: TestSuite) {
        suite.expect(ZenithHomeShortcuts.candidates.count == 11
                     && ZenithHomeShortcuts.candidates.allSatisfy { !$0.isLevel && $0 != .music },
                     "the shortcut row offers every control but the levels and the player")
        let two = row([.keepAwake, .timer])
        suite.expect(two.shown(available: everyShortcut) == [.keepAwake, .timer],
                     "the row is the shortcuts switched on, in order")
        let three = two.adding(.panel, available: everyShortcut)
        suite.expect(three.shown(available: everyShortcut) == [.keepAwake, .timer, .panel],
                     "an added shortcut joins the end of the row")
        suite.expect(row([.timer]).adding(.mixer, available: everyShortcut).shown(available: everyShortcut)
                        == [.timer, .mixer],
                     "a shortcut that came earlier in the order still joins the end, where its icon lands")
        suite.expect(three.adding(.timer, available: everyShortcut) == three
                     && three.adding(.volume, available: everyShortcut) == three
                     && three.adding(.music, available: everyShortcut) == three,
                     "a shortcut already in the row, a level and the player are not added")
        let removed = three.removing(.keepAwake)
        suite.expect(removed.shown(available: everyShortcut) == [.timer, .panel] && removed.order == three.order
                     && three.removing(.calendar) == three,
                     "removing switches only that shortcut off, keeping its place, and a missing one changes nothing")
        suite.expect(three.moving(.panel, to: 0, available: everyShortcut).shown(available: everyShortcut)
                        == [.panel, .keepAwake, .timer]
                     && three.moving(.keepAwake, to: 9, available: everyShortcut).shown(available: everyShortcut)
                        == [.timer, .panel, .keepAwake]
                     && three.moving(.panel, to: -3, available: everyShortcut).shown(available: everyShortcut)
                        == [.panel, .keepAwake, .timer]
                     && three.moving(.timer, by: -1, available: everyShortcut).shown(available: everyShortcut)
                        == [.timer, .keepAwake, .panel]
                     && three.moving(.calendar, to: 0, available: everyShortcut) == three,
                     "moving reorders within the row, clamped at both ends, and ignores a shortcut not in it")
        let moved = three.moving(.panel, to: 0, available: everyShortcut)
        let outside = ZenithHomeShortcuts.candidates.filter { !three.shown(available: everyShortcut).contains($0) }
        suite.expect(outside.allSatisfy { moved.order.firstIndex(of: $0) == three.order.firstIndex(of: $0) },
                     "the shortcuts outside the row keep their places in the order when the row is reordered")
        suite.expect(ZenithHomeShortcuts(order: [.timer, .timer, .volume, .music]).order
                        == [.timer] + ZenithHomeShortcuts.candidates.filter { $0 != .timer },
                     "the order keeps a shortcut's first place, drops the levels and the player, and lists every shortcut")
    }

    private static func shortcutAvailability(_ suite: TestSuite) {
        let shortcuts = row([.keepAwake, .timer, .panel])
        let withoutTimer = everyShortcut.subtracting([.timer])
        suite.expect(shortcuts.shown(available: withoutTimer) == [.keepAwake, .panel] && shortcuts.contains(.timer)
                     && !shortcuts.offered(available: withoutTimer).contains(.timer),
                     "a shortcut this Mac cannot show waits, still switched on, and the strip does not offer it")
        suite.expect(!shortcuts.canAdd(.calendar, available: everyShortcut.subtracting([.calendar]))
                     && shortcuts.adding(.calendar, available: everyShortcut.subtracting([.calendar])) == shortcuts,
                     "an unavailable shortcut cannot be added")
        suite.expect(shortcuts.offered(available: everyShortcut) == ZenithHomeShortcuts.candidates,
                     "with everything available the strip offers every shortcut")
        let defaults = freshDefaults()
        defaults.set(false, forKey: DefaultsKey.notchTimerEnabled)
        let available = ZenithHomeShortcuts.available(in: defaults)
        suite.expect(available.contains(.panel) && !available.contains(.timer)
                     && available.isSubset(of: everyShortcut)
                     && available == Set(ZenithHomeShortcuts.candidates.filter { $0.isAvailable(in: defaults) }),
                     "availability follows upstream's: the panel always, the timer only while its page is on")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func shortcutFitting(_ suite: TestSuite) {
        let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
        for layout in [NotchSize.compact, .spacious] {
            let geometry = NotchGeometry(screen: display, safeAreaTop: 32, cameraWidth: 210, layout: layout)
            let capacity = geometry.zenithHomeShortcutCapacity(levels: 2, hasCards: true)
            let width = geometry.contentWidth
            func scrolls(_ count: Int) -> Bool {
                let home = NotchLayout.controls(hasCards: true, shortcutCount: count, width: width,
                                                height: geometry.contentBudget)
                return NotchLayout.railGap(columns: NotchLayout.railColumns(count: count, rows: home.shortcutRows),
                                           itemWidth: NotchLayout.shortcutWidth, spacing: NotchLayout.shortcutSpacing,
                                           least: NotchLayout.shortcutLeastSpacing, width: width) == nil
            }
            suite.expect(capacity >= 4 && !scrolls(capacity)
                         && (capacity == ZenithHomeShortcuts.candidates.count || scrolls(capacity + 1)),
                         "the row holds as many shortcuts as fit without scrolling, and one more would scroll: \(layout)")
        }
        let wide = ZenithHomeShortcuts.capacity(width: 504, height: 102, hasCards: true, levelRow: false)
        let narrow = ZenithHomeShortcuts.capacity(width: 304, height: 102, hasCards: true, levelRow: false)
        suite.expect(narrow < wide && narrow >= 1 && ZenithHomeShortcuts.capacity(width: 0, height: 0, hasCards: true,
                                                                                  levelRow: false) == 1,
                     "a narrower island holds fewer shortcuts, and always at least one")
        let full = row(Array(ZenithHomeShortcuts.candidates.prefix(4)))
        suite.expect(!full.canAdd(.scratchpad, available: everyShortcut, capacity: 4)
                     && full.adding(.scratchpad, available: everyShortcut, capacity: 4) == full
                     && full.canAdd(.scratchpad, available: everyShortcut, capacity: 5),
                     "a full row takes no more, and room for one more lets it join")
        let compact = NotchGeometry(screen: display, safeAreaTop: 32, cameraWidth: 210, layout: .compact)
        suite.expect(compact.zenithHomeShortcutCapacity(levels: 2, hasCards: false)
                        >= compact.zenithHomeShortcutCapacity(levels: 2, hasCards: true),
                     "without the card row the shortcuts have at least as much room")
    }

    private static func shortcutPersistence(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchControlOrder] != nil
                     && Defaults.registeredDefaults[DefaultsKey.notchHiddenControls] != nil
                     && SettingsBackupSupport.exportKeys().isSuperset(of: [DefaultsKey.notchControlOrder,
                                                                           DefaultsKey.notchHiddenControls]),
                     "the shortcut row lives in upstream's registered keys, which settings backups carry")
        let decoded = ZenithHomeShortcuts.decode(order: "panel, timer,hologram,volume", hidden: "music,keepAwake,hologram")
        suite.expect(Array(decoded.order.prefix(2)) == [.panel, .timer] && decoded.order.count == 11
                     && decoded.hidden == [.keepAwake]
                     && ZenithHomeShortcuts.decode(order: decoded.encodedOrder, hidden: nil).order == decoded.order,
                     "the order and the switched-off shortcuts read back as stored, unknown names skipped")
        suite.expect(ZenithHomeShortcuts.decode(order: nil, hidden: nil).hidden
                        == Set(NotchControlItem.defaultHidden.split(separator: ",").compactMap {
                            NotchControlItem(rawValue: String($0)) }.filter(ZenithHomeShortcuts.isShortcut)),
                     "no hidden list means upstream's default shortcuts")
        suite.expect(row([.timer]).encodedHidden(preserving: "volume,music,hologram,panel,timer")
                        == (["hologram", "music", "volume"] + ZenithHomeShortcuts.candidates.filter { $0 != .timer }
                            .map(\.rawValue)).sorted().joined(separator: ","),
                     "saving keeps the levels, the player and later names in the hidden list, sorted as Settings writes it")

        let defaults = freshDefaults()
        ZenithHomeShortcuts.stored(in: defaults).save(in: defaults)
        suite.expect(defaults.persistentDomain(forName: suiteName)?[DefaultsKey.notchControlOrder] == nil
                     && defaults.persistentDomain(forName: suiteName)?[DefaultsKey.notchHiddenControls] == nil,
                     "saving an unchanged row writes nothing")
        defaults.set("music", forKey: DefaultsKey.notchHiddenControls)
        let available = ZenithHomeShortcuts.available(in: defaults)
        let chosen = ZenithHomeShortcuts.stored(in: defaults)
            .removing(.mixer).moving(.panel, to: 0, available: available)
        chosen.save(in: defaults)
        let upstream = NotchSupport.controls(in: defaults).filter(ZenithHomeShortcuts.isShortcut)
        suite.expect(upstream == chosen.shown(available: available) && upstream.first == .panel && !upstream.contains(.mixer)
                     && ZenithHomeShortcuts.stored(in: defaults) == chosen,
                     "the island's row is the one upstream and Settings read back")
        suite.expect(defaults.string(forKey: DefaultsKey.notchHiddenControls) == "mixer,music",
                     "saving the row leaves the player's switch where the widgets put it")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func shortcutEditMode(_ suite: TestSuite) {
        let defaults = freshDefaults()
        defaults.set("music", forKey: DefaultsKey.notchHiddenControls)
        let saved = ZenithHomeIsland.editing, savedDraft = ZenithHomeIsland.shortcutDraft
        let stored = NotchSupport.controls(in: defaults)
        let available = ZenithHomeShortcuts.available(in: defaults)
        let draft = ZenithHomeShortcuts.stored(in: defaults).removing(.panel).moving(.timer, to: 0, available: available)
        ZenithHomeIsland.editing = true
        ZenithHomeIsland.shortcutDraft = draft
        let editing = ZenithHomeIsland.controls(stored, in: defaults)
        suite.expect(editing.filter(ZenithHomeShortcuts.isShortcut) == draft.shown(available: available)
                     && editing.filter { !ZenithHomeShortcuts.isShortcut($0) } == stored.filter { !ZenithHomeShortcuts.isShortcut($0) },
                     "while editing, the island lays out the draft's shortcuts beside the stored levels")
        // Cancel: the draft goes and nothing was written.
        ZenithHomeIsland.editing = false
        ZenithHomeIsland.shortcutDraft = nil
        suite.expect(ZenithHomeIsland.controls(stored, in: defaults) == stored
                     && defaults.persistentDomain(forName: suiteName)?[DefaultsKey.notchControlOrder] == nil
                     && NotchSupport.controls(in: defaults) == stored,
                     "cancelling leaves the stored shortcuts untouched")
        // Done: the draft is saved and read back.
        draft.save(in: defaults)
        suite.expect(NotchSupport.controls(in: defaults).filter(ZenithHomeShortcuts.isShortcut) == draft.shown(available: available),
                     "done saves the draft's row, as the island showed it")
        ZenithHomeIsland.editing = saved
        ZenithHomeIsland.shortcutDraft = savedDraft
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.home(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 9 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words every home string, with curly apostrophes and no em dash")
            suite.expect(text.removeFormat.components(separatedBy: "%@").count == 2
                         && text.addFormat.components(separatedBy: "%@").count == 2
                         && !text.remove("X").contains("%@"),
                         "\(language.rawValue) names the widget once when adding or removing it")
            let shortcuts = Mirror(reflecting: ZenithStrings.homeShortcuts(language)).children.compactMap { $0.value as? String }
            suite.expect(shortcuts.count == 6
                         && shortcuts.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words every shortcut editing string, with curly apostrophes and no em dash")
        }
    }
}
