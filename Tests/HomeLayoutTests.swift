// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: the customisable home page (ZenithHomeLayoutSupport): adding,
/// removing and reordering widgets within the row's limits, persistence and
/// backups, the migration from the old home page and the Music switch it
/// keeps following, the island's size, the edit mode's draft, the gallery's
/// pages, and the strings.
enum HomeLayoutTests {
    static func run(_ suite: TestSuite) {
        editing(suite)
        limits(suite)
        persistence(suite)
        migration(suite)
        availability(suite)
        islandSize(suite)
        editMode(suite)
        galleryPages(suite)
        strings(suite)
    }

    private static let suiteName = "id.satuvisual.zenith.tests.home-layout"

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
                     && defaults.string(forKey: DefaultsKey.zenithHomeLayout) == nil,
                     "cancelling leaves the stored home page untouched")
        ZenithHomeIsland.editing = saved
        ZenithHomeIsland.draft = savedDraft
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func galleryPages(_ suite: TestSuite) {
        suite.expect(ZenithWidgetsPaging.pages(rows: 7, visible: 3) == 3 && ZenithWidgetsPaging.pages(rows: 3, visible: 3) == 1
                     && ZenithWidgetsPaging.pages(rows: 1, visible: 0) == 1 && ZenithWidgetsPaging.pages(rows: 0, visible: 3) == 1,
                     "the gallery has a page per visible set of rows, and always one")
        suite.expect(ZenithWidgetsPaging.pageStart(4, rows: 7, visible: 3) == 3
                     && ZenithWidgetsPaging.pageStart(6, rows: 7, visible: 3) == 6
                     && ZenithWidgetsPaging.pageStart(40, rows: 7, visible: 3) == 6
                     && ZenithWidgetsPaging.pageStart(-2, rows: 7, visible: 3) == 0,
                     "the gallery rests on the first row of a page, within the pages it has")
        let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
        for layout in [NotchSize.compact, .spacious] {
            let geometry = NotchGeometry(screen: display, safeAreaTop: 32, cameraWidth: 210, layout: layout)
            let count = NotchModule.allCases.count
            let rows = NotchSectionPaging.rows(count: count, columns: geometry.sectionColumns)
            let visible = geometry.sectionRows(count: count)
            let pages = ZenithWidgetsPaging.pages(rows: rows, visible: visible)
            suite.expect(pages >= 2 && pages * visible * geometry.sectionColumns >= count,
                         "every module has a place on the gallery's pages: \(layout)")
        }
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
        }
    }
}
