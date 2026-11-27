// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the floating Settings sidebar. Every page stays reachable from
/// its tiles and groups, every destination has an Orbit icon or a fallback
/// symbol, and the arrow keys walk the tiles and rows.
enum SettingsSidebarTests {
    static func run(_ suite: TestSuite) {
        grouping(suite)
        reachability(suite)
        icons(suite)
        navigation(suite)
        SettingsChromeTests.run(suite)
    }

    private static func sections(available: @escaping (AppFeature) -> Bool) -> [SettingsSidebarSection] {
        let state = SettingsSearchState(defaults: UserDefaults(), hardware: .init(
            battery: true, notchedDisplay: true, plainDisplay: false,
            keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        return SettingsDirectory.sidebarSections(.enUS, language: .enUS, superKeySource: .capsLock, state: state,
                                                 keyboardLight: true, isAvailable: available)
    }

    private static func grouping(_ suite: TestSuite) {
        let all = sections(available: { _ in true })
        suite.expect(all.first?.group == .tiles
                        && all.first?.items.map(\.id) == SettingsSidebarLayout.tiles,
                     "the sidebar opens with General, Appearance, Command Bar and Orbit, in that order")
        suite.expect(all.map(\.group) == SettingsSidebarGroup.allCases.filter { group in all.contains { $0.group == group } }
                        && all.allSatisfy { !$0.items.isEmpty },
                     "groups follow their fixed order and none is drawn empty")
        suite.expect(all.dropFirst().allSatisfy { !$0.title.isEmpty && $0.title == $0.group.title },
                     "every group below the tiles has a header")
        let ids = all.flatMap(\.items).map(\.id)
        suite.expect(Set(ids).count == ids.count, "no row shows twice")
        suite.expect(all.allSatisfy { section in section.items.allSatisfy { SettingsSidebarGroup.of($0.id) == section.group } },
                     "each row sits in the group the table names for it")
        func group(_ group: SettingsSidebarGroup) -> [SettingsSidebarItem.ID] {
            all.first { $0.group == group }?.items.map(\.id) ?? []
        }
        suite.expect(Set(group(.fromOrbit)) == [.page(.meetings), .page(.translate), .page(.mechakey)]
                        && group(.fromOrbit).count == 3,
                     "From Orbit lists the features Zenith added: Meetings, Translate and Mechakey")
        suite.expect(group(.island).prefix(2) == [.page(.notch), .page(.lockScreen)]
                        && group(.devices).first == .page(.pocket)
                        && group(.everyday).prefix(2) == [.page(.shelf), .feature(.clipboardHistory)]
                        && group(.capture).first == .page(.screenshot)
                        && group(.system).first == .page(.monitor),
                     "the groups open with the rows the design leads with")
        // Zenith fork: one row per sound and capture tool, each its own page.
        suite.expect(group(.sound) == [.page(.volumeMixer), .page(.soundOutput), .page(.musicBlocker), .page(.micMute)]
                        && group(.capture) == [.page(.screenshot), .page(.screenRecording), .page(.textCapture),
                                               .page(.colorPicker), .page(.cameraPreview)],
                     "Sound and Capture list one page per tool")
        suite.expect(group(.zenith).contains(.page(.about)) && group(.zenith).contains(.page(.shortcuts)),
                     "the app's own pages close the sidebar")
        suite.expect(SettingsPage.allCases.filter { SettingsSidebarGroup.of(page: $0) == .tiles }
                        == [.general, .features, .commandBar, .appearance],
                     "only the four tile pages map to the tiles")

        let none = sections(available: { _ in false })
        let tiles = none.first { $0.group == .tiles }?.items.map(\.id) ?? []
        suite.expect(tiles == [.page(.general), .page(.appearance), .page(.features)],
                     "with Command Bar off in Orbit its tile steps aside and the others stay")
        suite.expect(none.allSatisfy { !$0.items.isEmpty }, "a group whose features are all off disappears")
        let appearance = ZenithStrings.appearancePage(.enUS)
        suite.expect(!appearance.title.isEmpty && !appearance.subtitle.isEmpty
                        && none.first?.items.first { $0.id == .page(.appearance) }?.title == appearance.title
                        && FeatureVisibilitySupport.isPageVisible(.appearance, isAvailable: { _ in false }),
                     "the Appearance page is always reachable, whatever Orbit has off")
    }

    /// Nothing the old sidebar reached may disappear: every page has a row
    /// (the island's companion lives in a tab of the island's page), and
    /// every available tool on a shared page keeps its own.
    private static func reachability(_ suite: TestSuite) {
        let items = sections(available: { _ in true }).flatMap(\.items)
        let pages = Set(items.map(\.destination.page))
        let missing = SettingsPage.allCases.filter { $0 != .notchMascot && !pages.contains($0) }
        suite.expect(missing.isEmpty, "every Settings page is reachable from the sidebar (missing: \(missing))")
        let ids = Set(items.map(\.id))
        let tools = AppFeature.allCases.filter { feature in
            let destination = feature.settingsDestination
            return destination.sectionAnchor != nil && destination.page != .notchMascot
        }
        let missingTools = tools.filter { !ids.contains(.feature($0)) }
        suite.expect(missingTools.isEmpty, "every tool on a shared page keeps its row (missing: \(missingTools))")
        suite.expect(ids.contains(.setting(.panelConfiguration)) && !ids.contains(.setting(.screenshotScrolling))
                        && ids.contains(.setting(.keyboardBrightnessShortcuts)),
                     "the menu bar editor and keyboard light shortcuts keep their rows; scrolling capture is Screenshot's")
        for item in items {
            suite.expect(SettingsSidebarSupport.selection(for: item.destination, in: items,
                                                          preferredID: item.id) == item.id,
                         "\(item.title) is selected when its page opens")
        }
    }

    private static func icons(_ suite: TestSuite) {
        let ids: [SettingsSidebarItem.ID] = SettingsPage.allCases.map { .page($0) }
            + AppFeature.allCases.map { .feature($0) } + SettingsSectionAnchor.allCases.map { .setting($0) }
        let unknown = ids.compactMap { id in
            SettingsSidebarIcons.orbitName(for: id).flatMap { OrbitIcons.named($0) == nil ? $0 : nil }
        }
        suite.expect(unknown.isEmpty, "every Orbit icon the table names exists in the kit (unknown: \(unknown))")
        let headerless = SettingsPage.allCases.filter {
            SettingsSidebarIcons.orbitName(page: $0) == nil && SettingsSidebarIcons.fallbackSymbol(page: $0) == nil
        }
        suite.expect(headerless.isEmpty, "every page's header has an Orbit icon or a fallback symbol (\(headerless))")
        suite.expect(SettingsPage.allCases.allSatisfy {
            SettingsSidebarIcons.orbitName(page: $0) == nil || SettingsSidebarIcons.fallbackSymbol(page: $0) == nil
        }, "a page with an Orbit icon has no fallback symbol to drift from it")
        let items = sections(available: { _ in true }).flatMap(\.items)
        suite.expect(items.allSatisfy { SettingsSidebarIcons.orbitIcon(for: $0.id) != nil || !$0.icon.isEmpty },
                     "every sidebar row draws an Orbit icon or its own symbol")
        let tiles = SettingsSidebarLayout.tiles.compactMap { SettingsSidebarIcons.orbitIcon(for: $0) }
        suite.expect(tiles.map(\.name) == ["General", "Appearance", "Command Bar", "Orbit"],
                     "the four tiles draw their own Orbit icons")
        suite.expect(SettingsSidebarGroup.allCases.allSatisfy { $0.tint.count == 2 },
                     "every group has a two-colour fallback tint")
        let commandBar = OrbitIcons.named("Command Bar")
        let shelf = OrbitIcons.named("Shelf")
        suite.expect(commandBar.map { SettingsSidebarIcons.isPale($0.tint) } == true
                        && shelf.map { SettingsSidebarIcons.isPale($0.tint) } == false,
                     "only a near-white compact icon is redrawn for Light Mode")
    }

    private static func navigation(_ suite: TestSuite) {
        let tiles = SettingsSidebarLayout.tiles
        let rows: [SettingsSidebarItem.ID] = [.page(.notch), .page(.lockScreen), .page(.shelf)]
        func move(_ from: SettingsSidebarItem.ID?, _ direction: SettingsSidebarDirection,
                  tiles: [SettingsSidebarItem.ID] = tiles) -> SettingsSidebarItem.ID? {
            SettingsSidebarNavigation.move(from: from, direction: direction, tiles: tiles, rows: rows)
        }
        suite.expect(move(.page(.general), .right) == .page(.appearance)
                        && move(.page(.appearance), .left) == .page(.general)
                        && move(.page(.general), .down) == .page(.commandBar)
                        && move(.page(.features), .up) == .page(.appearance)
                        && move(.page(.appearance), .right) == nil
                        && move(.page(.general), .up) == nil,
                     "arrow keys move around the 2×2 tiles")
        suite.expect(move(.page(.commandBar), .down) == .page(.notch)
                        && move(.page(.features), .down) == .page(.notch)
                        && move(.page(.notch), .up) == .page(.commandBar)
                        && move(.page(.notch), .down) == .page(.lockScreen)
                        && move(.page(.shelf), .down) == nil
                        && move(.page(.lockScreen), .left) == nil,
                     "down leaves the tiles for the first row, up from it returns to the bottom-left tile")
        let threeTiles: [SettingsSidebarItem.ID] = [.page(.general), .page(.appearance), .page(.features)]
        suite.expect(move(.page(.notch), .up, tiles: threeTiles) == .page(.features)
                        && move(.page(.appearance), .down, tiles: threeTiles) == .page(.notch),
                     "with three tiles the walk still finds its way between tiles and rows")
        suite.expect(move(nil, .down) == .page(.general) && move(.page(.about), .down) == .page(.notch),
                     "with nothing selected, or a row in a folded group, the walk starts over")
    }
}

/// Zenith fork: the Settings window's chrome: the account card's lines and
/// what a double-click on the window's top does.
enum SettingsChromeTests {
    static func run(_ suite: TestSuite) {
        account(suite)
        doubleClick(suite)
    }

    private static func account(_ suite: TestSuite) {
        let jane = SettingsAccountSummary(name: "Jane Appleseed", kind: .admin, computer: "MacBook Pro")
        suite.expect(jane.subtitle == "Admin · MacBook Pro" && jane.initials == "JA",
                     "the account card reads Admin · computer under the name, with the name's initials")
        suite.expect(SettingsAccountSummary(name: "Jane", kind: .standard, computer: "").subtitle == "Standard"
                        && SettingsAccountSummary(name: "Jane", kind: nil, computer: " Studio ").subtitle == "Studio"
                        && SettingsAccountSummary(name: "Jane", kind: nil, computer: "  ").subtitle.isEmpty,
                     "an unknown account type or computer name is left out, never shown as a lone dot")
        suite.expect(SettingsAccountSummary.displayName(fullName: "  Jane Appleseed ", userName: "jane") == "Jane Appleseed"
                        && SettingsAccountSummary.displayName(fullName: " ", userName: "jane") == "jane",
                     "an account without a full name shows its login name")
        suite.expect(SettingsAccountSummary(name: "jane", kind: nil, computer: "").initials == "J"
                        && SettingsAccountSummary(name: "", kind: nil, computer: "").initials.isEmpty,
                     "one word gives one initial, no name none (the card then draws a person)")
        suite.expect(SettingsAccountSummary.placeholder.name == "Jane Appleseed",
                     "the offscreen renders use the generic placeholder account")
    }

    private static func doubleClick(_ suite: TestSuite) {
        typealias D = SettingsTitleBarDoubleClick
        suite.expect(D.action(setting: "Maximize", legacyMinimize: false) == .zoom
                        && D.action(setting: "Fill", legacyMinimize: false) == .zoom
                        && D.action(setting: "Minimize", legacyMinimize: false) == .minimize
                        && D.action(setting: "None", legacyMinimize: true) == .none,
                     "a double-click on the window's top follows the system's choice")
        suite.expect(D.action(setting: nil, legacyMinimize: false) == .zoom
                        && D.action(setting: nil, legacyMinimize: true) == .minimize
                        && D.action(setting: "Something new", legacyMinimize: false) == .zoom,
                     "without the newer setting the older minimise flag decides, zoom by default")
        let domain = "vorss.tests.settings-chrome.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("Minimize", forKey: "AppleActionOnDoubleClick")
        suite.expect(D.current(defaults) == .minimize, "the setting is read from the defaults given")
    }
}
