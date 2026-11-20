// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: what the open island's tab pill holds (ZenithTabBarSupport):
/// reading and writing the pins, sections this Mac cannot show, the limit of
/// six, the gallery always last, the open page's own tab, the counts, the
/// defaults matching the pill before it could be chosen, the island's row
/// button coming back with the bar off, backups, and the strings.
enum TabBarTests {
    static func run(_ suite: TestSuite) {
        parsing(suite)
        availability(suite)
        limit(suite)
        ordering(suite)
        galleryLast(suite)
        currentPage(suite)
        badges(suite)
        defaults(suite)
        rowButton(suite)
        persistence(suite)
        strings(suite)
    }

    private static let suiteName = "com.vorssaint.tests.tab-bar"

    private static func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static let everything = NotchModule.allCases

    private static func parsing(_ suite: TestSuite) {
        let pins = ZenithTabBarPins(encoded: "controls, music,files,later,music,,clipboard")
        suite.expect(pins.raw == ["controls", "music", "files", "later", "clipboard"],
                     "the stored list is read in order, trimmed, without repeats or empty names")
        suite.expect(pins.known == [.controls, .music, .files, .clipboard]
                     && pins.visible(available: everything) == [.controls, .music, .files, .clipboard],
                     "a name this version does not know is skipped when reading")
        suite.expect(pins.encoded == "controls,music,files,later,clipboard"
                     && ZenithTabBarPins(encoded: pins.encoded) == pins,
                     "writing keeps the order and the unknown name, so a later version's pins survive")
        suite.expect(ZenithTabBarPins(encoded: "").raw.isEmpty && ZenithTabBarPins([]).encoded == "",
                     "an empty list pins nothing")
        suite.expect(ZenithTabBarPins([.files, .controls]).encoded == "files,controls",
                     "pins are stored as comma-separated raw values")
        suite.expect(pins.unpinning(.music).raw == ["controls", "files", "later", "clipboard"]
                     && pins.unpinning(.timer) == pins,
                     "unpinning takes only that section out, and a section not pinned changes nothing")
    }

    private static func availability(_ suite: TestSuite) {
        let defaults = freshDefaults()
        defaults.set(true, forKey: AppFeature.shelf.availabilityKey)
        defaults.set("music", forKey: DefaultsKey.notchHiddenModules)
        let routed = NotchSupport.modules(in: defaults)
        suite.expect(routed.contains(.controls) && routed.contains(.files) && !routed.contains(.music)
                     && !routed.contains(.clipboard),
                     "the fixture routes Home and Files, hides Music and lacks Clipboard History")
        suite.expect(ZenithTabBarAvailability.of(.files, routed: routed, in: defaults) == .available
                     && ZenithTabBarAvailability.of(.music, routed: routed, in: defaults) == .hidden
                     && ZenithTabBarAvailability.of(.clipboard, routed: routed, in: defaults) == .unavailable,
                     "a section reads available when the island routes it, hidden when only its switch is off, "
                        + "unavailable when its feature is off")
        let pins = ZenithTabBarPins([.clipboard, .controls, .music, .files])
        suite.expect(pins.visible(available: routed) == [.controls, .files],
                     "sections the island cannot show are skipped in the pill, the rest keep their order")
        suite.expect(!pins.canPin(.clipboard, available: routed) && pins.pinning(.clipboard, available: routed) == pins
                     && !pins.isPinned(.music, available: routed),
                     "an unavailable section cannot be pinned and reads unpinned")
        defaults.set("", forKey: DefaultsKey.notchHiddenModules)
        suite.expect(pins.visible(available: NotchSupport.modules(in: defaults)) == [.controls, .music, .files],
                     "a stored pin comes back in its place once its section shows again")
        suite.expect(pins.listed(available: routed, order: [.files, .music]).prefix(3) == [.controls, .files, .music]
                     && Set(pins.listed(available: routed, order: [])) == Set(NotchModule.allCases)
                     && pins.listed(available: routed, order: []).count == NotchModule.allCases.count,
                     "the card lists every section once: the shown pins first, then the island's order")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func limit(_ suite: TestSuite) {
        let six: [NotchModule] = [.controls, .files, .music, .clipboard, .timer, .calendar]
        let full = ZenithTabBarPins(six)
        suite.expect(ZenithTabBar.maximumPinned == 6 && full.isFull(available: everything)
                     && !full.canPin(.system, available: everything)
                     && full.pinning(.system, available: everything) == full,
                     "the pill pins at most six sections; a seventh is refused")
        let seven = ZenithTabBarPins(six + [.system])
        suite.expect(seven.visible(available: everything) == six,
                     "a longer stored list shows only its first six")
        suite.expect(full.unpinning(.music).canPin(.system, available: everything)
                     && full.unpinning(.music).pinning(.system, available: everything).visible(available: everything)
                        == [.controls, .files, .clipboard, .timer, .calendar, .system],
                     "unpinning one makes room, and a new pin joins the end")
        let unavailable = ZenithTabBarPins([.agents] + six.dropLast())
        let routed = everything.filter { $0 != .agents }
        suite.expect(!unavailable.isFull(available: routed) && unavailable.canPin(.system, available: routed),
                     "only the pins that show count toward the limit")
        suite.expect(ZenithTabBar.layout(ZenithTabBarConfiguration(pins: seven), available: everything,
                                         page: .controls, detail: false).items.count == 7,
                     "six pins and the gallery are the most tabs the pill holds with the open page pinned")
    }

    private static func ordering(_ suite: TestSuite) {
        let pins = ZenithTabBarPins(raw: ["controls", "later", "files", "agents", "music"])
        let routed = everything.filter { $0 != .agents }
        suite.expect(pins.moving(.music, to: 0, available: routed).raw == ["music", "later", "controls", "agents", "files"],
                     "moving reorders the shown pins and leaves what does not show where it was")
        suite.expect(pins.moving(.controls, to: 9, available: routed).visible(available: routed) == [.files, .music, .controls]
                     && pins.moving(.files, to: -2, available: routed).visible(available: routed) == [.files, .controls, .music]
                     && pins.moving(.timer, to: 0, available: routed) == pins,
                     "moving is clamped at both ends and ignores a section not pinned")
        suite.expect(pins.reordering([.files, .music, .controls], available: routed).visible(available: routed)
                        == [.files, .music, .controls]
                     && pins.reordering([.files, .music], available: routed) == pins
                     && pins.reordering([.files, .music, .timer], available: routed) == pins,
                     "a drag's new order applies only when it reorders exactly the shown pins")
    }

    private static func galleryLast(_ suite: TestSuite) {
        let cases: [(ZenithTabBarPins, NotchModule?, Bool)] = [
            (ZenithTabBarPins([]), .music, false), (ZenithTabBarPins([]), nil, false),
            (ZenithTabBarPins([.music, .files]), .controls, true),
            (ZenithTabBarPins([.controls, .files, .music, .clipboard, .timer, .calendar]), .system, false),
        ]
        for current in [true, false] {
            for (pins, page, detail) in cases {
                let layout = ZenithTabBar.layout(ZenithTabBarConfiguration(pins: pins, currentPage: current),
                                                 available: everything, page: page, detail: detail)
                suite.expect(layout.items.last == .gallery && layout.items.filter { $0 == .gallery }.count == 1,
                             "the gallery closes the pill once, whatever is pinned (\(pins.encoded), current page \(current))")
            }
        }
        let empty = ZenithTabBar.layout(ZenithTabBarConfiguration(pins: ZenithTabBarPins([]), currentPage: false),
                                        available: everything, page: .music, detail: false)
        suite.expect(empty.items == [.gallery] && empty.chosen == nil,
                     "with nothing pinned and no current page the gallery alone still reaches every section")
        let gallery = ZenithTabBar.layout(ZenithTabBarConfiguration(), available: everything, page: nil, detail: false)
        suite.expect(gallery.chosen == .gallery, "the gallery's tab is chosen while the gallery shows")
    }

    private static func currentPage(_ suite: TestSuite) {
        let on = ZenithTabBarConfiguration(pins: ZenithTabBarPins([.controls, .files]), currentPage: true)
        var off = on
        off.currentPage = false
        let music = ZenithTabBar.layout(on, available: everything, page: .music, detail: false)
        suite.expect(music.items == [.module(.controls), .module(.files), .page(.music), .gallery] && music.chosen == .page(.music),
                     "a page that is not pinned gets its own tab before the gallery, chosen")
        let pinned = ZenithTabBar.layout(on, available: everything, page: .files, detail: false)
        suite.expect(pinned.items == [.module(.controls), .module(.files), .gallery] && pinned.chosen == .module(.files),
                     "a pinned page chooses its pinned tab and adds none")
        let detail = ZenithTabBar.layout(on, available: everything, page: .controls, detail: true)
        suite.expect(detail.items == [.module(.controls), .module(.files), .page(.controls), .gallery]
                     && detail.chosen == .page(.controls),
                     "a detail over a pinned page shows as the page's own tab, which leads back")
        let hidden = ZenithTabBar.layout(off, available: everything, page: .music, detail: false)
        suite.expect(hidden.items == [.module(.controls), .module(.files), .gallery] && hidden.chosen == nil,
                     "with the current page off an unpinned page adds no tab and none is chosen")
        suite.expect(ZenithTabBar.layout(off, available: everything, page: .controls, detail: false).chosen == .module(.controls),
                     "with the current page off a pinned page still chooses its tab")
    }

    private static func badges(_ suite: TestSuite) {
        let counts: [NotchModule: Int] = [.files: 4, .notifications: 120, .music: 3]
        suite.expect(ZenithTabBar.badge(.module(.files), counts: counts, enabled: true) == 4
                     && ZenithTabBar.badge(.page(.notifications), counts: counts, enabled: true) == 120,
                     "the Shelf and notifications show their counts, pinned or as the open page")
        suite.expect(ZenithTabBar.badge(.module(.music), counts: counts, enabled: true) == nil
                     && ZenithTabBar.badge(.gallery, counts: counts, enabled: true) == nil,
                     "sections without a count show none")
        suite.expect(ZenithTabBar.badge(.module(.files), counts: counts, enabled: false) == nil
                     && ZenithTabBar.badge(.module(.files), counts: [.files: 0], enabled: true) == nil,
                     "badges switched off, or an empty Shelf, show no count")
        suite.expect(ZenithTabBar.badge(.page(.files), counts: counts, enabled: true, detail: true) == nil,
                     "a detail's tab carries no count")
    }

    /// The pill before it could be chosen: Home, Files when the Shelf is
    /// on, the open page when it is neither, and the gallery.
    private static func defaults(_ suite: TestSuite) {
        let defaults = freshDefaults()
        let configuration = ZenithTabBar.configuration(in: defaults)
        suite.expect(configuration == ZenithTabBarConfiguration() && configuration.enabled && configuration.currentPage
                     && configuration.badges && configuration.pins.known == [.controls, .files]
                     && ZenithTabBar.defaultEncoded == "controls,files",
                     "unset, the bar shows with Home and Files pinned, the current page and badges on")
        let withFiles: [NotchModule] = [.controls, .music, .clipboard, .files, .system]
        let withoutFiles = withFiles.filter { $0 != .files }
        for modules in [withFiles, withoutFiles] {
            for page in modules {
                for detail in [false, true] {
                    let layout = ZenithTabBar.layout(configuration, available: modules, page: page, detail: detail)
                    suite.expect(layout == legacy(modules: modules, page: page, detail: detail),
                                 "the default pill matches the fixed one on \(page.rawValue)\(detail ? " under a detail" : "")"
                                    + (modules.contains(.files) ? "" : " without Files"))
                }
            }
            suite.expect(ZenithTabBar.layout(configuration, available: modules, page: nil, detail: false)
                            == legacy(modules: modules, page: nil, detail: false),
                         "the default pill matches the fixed one in the gallery")
        }
        defaults.set("music,later", forKey: DefaultsKey.zenithTabBarModules)
        defaults.set(false, forKey: DefaultsKey.zenithTabBarCurrentPage)
        defaults.set(false, forKey: DefaultsKey.zenithTabBarBadges)
        defaults.set(false, forKey: DefaultsKey.zenithTabBarEnabled)
        let stored = ZenithTabBar.configuration(in: defaults)
        suite.expect(stored.pins.raw == ["music", "later"] && !stored.currentPage && !stored.badges && !stored.enabled
                     && !ZenithTabBar.isEnabled(in: defaults),
                     "stored choices are read back")
        defaults.set("", forKey: DefaultsKey.zenithTabBarModules)
        suite.expect(ZenithTabBar.configuration(in: defaults).pins.raw.isEmpty,
                     "an emptied list stays empty rather than falling back to Home and Files")
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// The fixed pill's rule, as ZenithIslandDock drew it before the tab bar.
    private static func legacy(modules: [NotchModule], page: NotchModule?, detail: Bool) -> ZenithTabBarLayout {
        var items: [ZenithTabBarItem] = []
        if modules.contains(.controls) { items.append(.module(.controls)) }
        if modules.contains(.files) { items.append(.module(.files)) }
        var chosen: ZenithTabBarItem? = page == nil ? .gallery : nil
        if let page {
            if !detail, page == .controls, items.contains(.module(.controls)) { chosen = .module(.controls) }
            else if !detail, page == .files, items.contains(.module(.files)) { chosen = .module(.files) }
            else { items.append(.page(page)); chosen = .page(page) }
        }
        items.append(.gallery)
        return ZenithTabBarLayout(items: items, chosen: chosen)
    }

    /// The bar off gives the island's row its gallery button back, by
    /// upstream's rule; on, the pill holds the way there.
    private static func rowButton(_ suite: TestSuite) {
        let defaults = freshDefaults()
        suite.expect(!ZenithTabBar.sectionsButtonInRow(floatingExplore: false, in: defaults)
                     && !ZenithTabBar.sectionsButtonInRow(floatingExplore: true, in: defaults),
                     "with the tab bar on the row never repeats the gallery's button")
        defaults.set(false, forKey: DefaultsKey.zenithTabBarEnabled)
        suite.expect(ZenithTabBar.sectionsButtonInRow(floatingExplore: false, in: defaults)
                     && !ZenithTabBar.sectionsButtonInRow(floatingExplore: true, in: defaults),
                     "with the tab bar off the row leads with the button unless a floating button leads there")
        let base = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32, cameraWidth: 210)
        for module: NotchModule in [.controls, .music, .tools] {
            let off = base.page(module, controls: [],
                                sectionsButton: ZenithTabBar.sectionsButtonInRow(floatingExplore: false, in: defaults))
            suite.expect(off.rowShowsSectionsButton || off.sectionsButtonEndsRow,
                         "with the tab bar off \(module.rawValue)'s row shows the gallery button again")
        }
        defaults.set(true, forKey: DefaultsKey.zenithTabBarEnabled)
        let on = base.page(.controls, controls: [],
                           sectionsButton: ZenithTabBar.sectionsButtonInRow(floatingExplore: false, in: defaults))
        suite.expect(!on.rowShowsSectionsButton && !on.sectionsButtonEndsRow,
                     "with the tab bar on the row has no gallery button")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func persistence(_ suite: TestSuite) {
        let keys = [DefaultsKey.zenithTabBarEnabled, DefaultsKey.zenithTabBarModules,
                    DefaultsKey.zenithTabBarCurrentPage, DefaultsKey.zenithTabBarBadges]
        suite.expect(Defaults.registeredDefaults[DefaultsKey.zenithTabBarEnabled] as? Bool == true
                     && Defaults.registeredDefaults[DefaultsKey.zenithTabBarModules] as? String == ZenithTabBar.defaultEncoded
                     && Defaults.registeredDefaults[DefaultsKey.zenithTabBarCurrentPage] as? Bool == true
                     && Defaults.registeredDefaults[DefaultsKey.zenithTabBarBadges] as? Bool == true,
                     "the tab bar's keys are registered with today's pill as their defaults")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: keys),
                     "the tab bar's choices travel with settings backups")
        let defaults = freshDefaults()
        ZenithTabBar.save(ZenithTabBarPins(ZenithTabBar.defaultPins), in: defaults)
        suite.expect(defaults.persistentDomain(forName: suiteName)?[DefaultsKey.zenithTabBarModules] == nil,
                     "saving the pins unchanged writes nothing")
        ZenithTabBar.save(ZenithTabBarPins([.music, .controls]), in: defaults)
        suite.expect(defaults.string(forKey: DefaultsKey.zenithTabBarModules) == "music,controls"
                     && ZenithTabBar.configuration(in: defaults).pins.known == [.music, .controls],
                     "saved pins are read back in their order")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.tabBar(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 14 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words every tab bar string, with curly apostrophes and no em dash")
            suite.expect(text.limitFormat.components(separatedBy: "%d").count == 2
                         && text.limit(ZenithTabBar.maximumPinned).contains("6") && !text.limit(6).contains("%"),
                         "\(language.rawValue) names the limit once")
        }
    }
}
