// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Orbit, the store-like catalog on the Features page. One list
/// covers every hub feature and Zenith's own pages. It keeps no state of its
/// own: a feature is on while the hub's availability says so and turns on
/// and off through `FeatureRuntime`, and a Zenith page reads the switch its
/// page already has. Pure, so the catalog, its routing and its search are
/// covered by the unit harness.

/// Orbit's shelves, in the order the chips show them. `all` and `installed`
/// are views, never an item's home.
enum OrbitCategory: String, CaseIterable, Identifiable {
    case all, island, ai, productivity, media, files, capture, windows, input, sound, system, devices, privacy, installed

    var id: String { rawValue }

    /// The categories an item can belong to.
    static let shelves: [OrbitCategory] = allCases.filter { $0 != .all && $0 != .installed }
}

enum OrbitItemID: Hashable, Identifiable {
    case feature(AppFeature)
    case page(SettingsPage)

    var id: Self { self }
}

struct OrbitItem: Identifiable, Equatable {
    let id: OrbitItemID
    /// The art in `OrbitIcons`, by its English name.
    let iconName: String
    let category: OrbitCategory
    /// A Zenith page's own on switch and its registered default. Nil for a
    /// hub feature, and for a page that is simply part of the app.
    var switchKey: String? = nil
    var switchDefault = false
    /// The hub feature this item does nothing without.
    var requires: AppFeature? = nil
    /// What a Zenith page asks for. A hub feature declares its own.
    var pagePermissions: [AppPermission] = []

    var feature: AppFeature? {
        if case .feature(let feature) = id { return feature }
        return nil
    }

    var page: SettingsPage? {
        if case .page(let page) = id { return page }
        return nil
    }

    var permissions: [AppPermission] { feature?.permissions ?? pagePermissions }

    /// The nearest Settings surface: the feature's own destination, or the page.
    var destination: FeatureSettingsDestination {
        if let feature { return feature.settingsDestination }
        return FeatureSettingsDestination(page ?? .features)
    }
}

enum OrbitItemState: Equatable {
    case on, off
    /// On, but missing a permission it is using right now.
    case needsPermission([AppPermission])
    /// Off, and this Mac cannot run it.
    case unsupported(String)

    var isOn: Bool {
        switch self {
        case .on, .needsPermission: return true
        case .off, .unsupported: return false
        }
    }
}

/// The capsule a row shows.
enum OrbitButton: Equatable { case get, open, unavailable }

/// What pressing Get does: the features to install, in order, and the page
/// to open afterwards for an item whose own page switches it on.
struct OrbitGetPlan: Equatable {
    let install: [AppFeature]
    let opens: FeatureSettingsDestination?
}

enum OrbitCatalog {
    /// Zenith's own pages, which no hub feature stands for.
    static let pages: [SettingsPage] = [.lockScreen, .meetings, .translate, .mechakey, .workspaces,
                                        .pocket, .remote, .batteries, .faceUnlock,
                                        .removeBackground, .emojiPicker, .calculator, // Zenith fork: Orbit wave 2
                                        .appLock] // Zenith fork: App Lock

    /// Every item: the hub's features in their catalog order, then the pages.
    static let items: [OrbitItem] = AppFeature.allCases.map(item(for:)) + pages.compactMap(item(for:))

    private static let byID: [OrbitItemID: OrbitItem] = Dictionary(items.map { ($0.id, $0) },
                                                                   uniquingKeysWith: { first, _ in first })

    static func item(_ id: OrbitItemID) -> OrbitItem? { byID[id] }

    /// The curated row at the top of All.
    static let picks: [OrbitItemID] = [
        .page(.meetings), .page(.translate), .page(.mechakey), .feature(.shelf), .feature(.clipboardHistory),
        .page(.pocket), .page(.batteries), .page(.faceUnlock), .feature(.commandBar),
        .page(.removeBackground), .page(.emojiPicker), .page(.calculator), // Orbit wave 2
    ]

    /// The item the banner shows.
    static let featured: OrbitItemID = .page(.meetings)

    /// How many items a shelf shows on All before See All.
    static let shelfPreviewCount = 6

    // MARK: Items

    private static func item(for feature: AppFeature) -> OrbitItem {
        let (icon, category) = placement(feature)
        let requires: AppFeature? = AppFeature.dynamicIslandExtensions.contains(feature) ? .notch : nil
        return OrbitItem(id: .feature(feature), iconName: icon, category: category, requires: requires)
    }

    private static func item(for page: SettingsPage) -> OrbitItem? {
        switch page {
        case .lockScreen:
            return OrbitItem(id: .page(page), iconName: "Lock Screen", category: .island,
                             switchKey: DefaultsKey.notchLockScreen, requires: .notch)
        case .meetings:
            return OrbitItem(id: .page(page), iconName: "Meetings", category: .productivity,
                             switchKey: DefaultsKey.zenithMeetingsEnabled, pagePermissions: [.calendar])
        case .translate:
            return OrbitItem(id: .page(page), iconName: "Quick Translate", category: .ai,
                             switchKey: TranslateDefaults.enabled, pagePermissions: [.accessibility])
        case .mechakey:
            return OrbitItem(id: .page(page), iconName: "Mechakey", category: .input,
                             switchKey: MechakeyDefaults.enabled)
        case .workspaces:
            return OrbitItem(id: .page(page), iconName: "Workspaces", category: .windows)
        case .pocket:
            return OrbitItem(id: .page(page), iconName: "Pocket", category: .devices,
                             switchKey: PocketDefaults.enabled)
        case .remote:
            return OrbitItem(id: .page(page), iconName: "iPhone Remote", category: .devices,
                             switchKey: DefaultsKey.zenithRemoteEnabled)
        case .batteries:
            return OrbitItem(id: .page(page), iconName: "Batteries", category: .devices,
                             switchKey: BatteriesDefaults.enabled, switchDefault: true)
        case .faceUnlock:
            return OrbitItem(id: .page(page), iconName: "Face Unlock", category: .devices,
                             switchKey: DefaultsKey.faceUnlockEnabled, pagePermissions: [.camera])
        // Zenith fork: Orbit wave 2.
        case .removeBackground:
            return OrbitItem(id: .page(page), iconName: "Remove Background", category: .ai,
                             switchKey: RemoveBackgroundDefaults.enabled)
        case .emojiPicker:
            return OrbitItem(id: .page(page), iconName: "Emoji Picker", category: .productivity,
                             switchKey: EmojiPickerDefaults.enabled, pagePermissions: [.accessibility])
        case .calculator:
            return OrbitItem(id: .page(page), iconName: "Calculator", category: .productivity,
                             switchKey: CalculatorDefaults.enabled)
        case .appLock: // Zenith fork: App Lock
            return OrbitItem(id: .page(page), iconName: "App Lock", category: .privacy,
                             switchKey: AppLockDefaults.enabled)
        default:
            return nil
        }
    }

    /// Each feature's icon and shelf. Exhaustive, so a new feature has to
    /// choose both before the project compiles.
    private static func placement(_ feature: AppFeature) -> (icon: String, category: OrbitCategory) {
        switch feature {
        case .switcher: return ("Window Switcher", .windows)
        case .dockPreview: return ("Dock Preview", .windows)
        case .dockClick: return ("Dock Click", .windows)
        case .windowMaximizer: return ("Window Maximizer", .windows)
        case .windowLayout: return ("Window Snap", .windows)
        case .autoQuit: return ("Auto Quit", .windows)
        case .spacesOrder: return ("Spaces Order", .windows)
        case .radialMenu: return ("Radial Menu", .windows)
        case .quitWindowProtection: return ("Quit Protection", .windows)

        case .scrollInverter: return ("Scroll Direction", .input)
        case .scrollHorizontal: return ("Horizontal Scroll", .input)
        case .scrollZoom: return ("Scroll Zoom", .input)
        case .focusFollowsMouse: return ("Focus Follows Mouse", .input)
        case .smoothScroll: return ("Smooth Scroll", .input)
        case .linearScroll: return ("Linear Scroll", .input)
        case .scrollSpeed: return ("Scroll Speed", .input)
        case .mouseAcceleration: return ("Mouse Acceleration", .input)
        case .mouseNavigation: return ("Mouse Navigation", .input)
        case .mouseButtonShortcuts: return ("Mouse Buttons", .input)
        case .middleClick: return ("Middle Click", .input)
        case .mouseClickDebounce: return ("Click Debounce", .input)
        case .keyboardDebounce: return ("Key Debounce", .input)
        case .superKey: return ("Super Key", .input)

        case .commandBar: return ("Command Bar", .productivity)
        case .clipboardHistory: return ("Clipboard", .productivity)
        case .pastePlain: return ("Paste as Plain Text", .productivity)
        case .urlCleaner: return ("URL Cleaner", .productivity)
        case .textSnippets: return ("Text Snippets", .productivity)
        case .quickLauncher: return ("Quick Launcher", .productivity)
        case .quickToggles: return ("Quick Toggles", .productivity)
        case .scratchpad: return ("Scratchpad", .productivity)
        case .quitApps: return ("Quit Apps", .productivity)

        case .shelf: return ("Shelf", .files)
        case .finderCutPaste: return ("Cut and Paste", .files)
        case .finderRename: return ("Finder Rename", .files)
        case .diskImageInstaller: return ("Disk Image Installer", .files)

        case .mixer: return ("Volume Mixer", .sound)
        case .soundOutputSwitcher: return ("Sound Output", .sound)
        case .audioPriority: return ("Audio Priority", .sound)
        case .micMute: return ("Mic Mute", .sound)
        case .musicBlock: return ("Music Blocker", .sound)

        case .screenshot: return ("Screenshot", .capture)
        case .screenRecorder: return ("Screen Recorder", .capture)
        case .screenOCR: return ("Text Capture", .capture)
        case .colorPicker: return ("Color Picker", .capture)
        case .cameraPreview: return ("Camera Preview", .capture)

        case .mediaTools: return ("Media Tools", .media)
        case .wallpaper: return ("Wallpaper", .media)
        case .notchLyrics: return ("Lyrics", .media)
        case .notchQueue: return ("Up Next", .media)
        case .notchLiveEqualizer: return ("Live Equalizer", .media)

        case .notch: return ("Dynamic Island", .island)
        case .notchCalendar: return ("Calendar", .island)
        case .notchNotifications: return ("Notifications", .island)
        case .notchGestures: return ("Island Gestures", .island)
        case .notchTimer: return ("Focus Timer", .island)
        case .notchAccessories: return ("Live Activities", .island)
        case .notchDownloads: return ("Downloads", .island)
        case .notchWatch: return ("Screen Watch", .island)
        case .notchMascot: return ("Mascot", .island)
        case .notchAgents: return ("Agents", .ai)

        case .keepAwake: return ("Keep Awake", .system)
        case .brightness: return ("Brightness", .system)
        case .extraBrightness: return ("Extra Brightness", .system)
        case .cleaningMode: return ("Cleaning Mode", .system)
        case .cleaner: return ("Cleaner", .system)
        case .uninstaller: return ("Uninstaller", .system)
        case .homebrew: return ("Homebrew", .system)
        case .appUpdates: return ("App Updates", .system)
        case .killProcess: return ("Kill Process", .system)
        case .portManager: return ("Port Manager", .system)
        case .monitorCPU: return ("CPU", .system)
        case .monitorGPU: return ("GPU", .system)
        case .monitorMemory: return ("Memory", .system)
        case .monitorNetwork: return ("Network", .system)
        case .monitorDisk: return ("Disk", .system)
        case .monitorPower: return ("Power", .system)
        case .fanControl: return ("Fan Control", .system)

        case .connectedDevices: return ("Connected Devices", .devices)
        case .bluetoothSleep: return ("Bluetooth Sleep", .devices)
        }
    }

    // MARK: State

    /// The item's state from injectable readers. `missing` names permissions
    /// known to be refused; `using` says whether a feature uses one right now
    /// (`AppFeature.activeFeatures`), so a grant only matters while it does.
    static func state(of item: OrbitItem,
                      isAvailable: (AppFeature) -> Bool,
                      switchValue: (String) -> Bool?,
                      missing: (AppPermission) -> Bool,
                      using: (AppFeature, AppPermission) -> Bool,
                      blockedReason: (AppFeature) -> String?) -> OrbitItemState {
        let on: Bool
        if let feature = item.feature {
            on = isAvailable(feature)
            if !on, let reason = blockedReason(feature) { return .unsupported(reason) }
        } else {
            let requirementMet = item.requires.map(isAvailable) ?? true
            let switchedOn = item.switchKey.map { switchValue($0) ?? item.switchDefault } ?? true
            on = requirementMet && switchedOn
        }
        guard on else { return .off }
        let needed = item.permissions.filter { permission in
            guard missing(permission) else { return false }
            guard let feature = item.feature else { return true }
            return using(feature, permission)
        }
        return needed.isEmpty ? .on : .needsPermission(needed)
    }

    static func button(for state: OrbitItemState) -> OrbitButton {
        switch state {
        case .on, .needsPermission: return .open
        case .off: return .get
        case .unsupported: return .unavailable
        }
    }

    // MARK: Actions

    /// Get installs what the item needs, through the hub's own install so its
    /// first-install rules apply. A Zenith page is switched on and set up on
    /// its own page, so Get takes the person there.
    static func getPlan(for item: OrbitItem, isAvailable: (AppFeature) -> Bool) -> OrbitGetPlan {
        var install: [AppFeature] = []
        if let required = item.requires, !isAvailable(required) { install.append(required) }
        if let feature = item.feature, !isAvailable(feature) { install.append(feature) }
        return OrbitGetPlan(install: install, opens: item.feature == nil ? item.destination : nil)
    }

    /// Where Open goes. Nil for a feature with no page of its own, whose
    /// details are all there is to show.
    static func openDestination(for item: OrbitItem) -> FeatureSettingsDestination? {
        if let feature = item.feature {
            return feature.hasNavigableSettingsDestination ? feature.settingsDestination : nil
        }
        return item.destination
    }

    /// What Turn Off uninstalls. Nil for a Zenith page, whose switch lives on
    /// its page, and for a page that is part of the app.
    static func turnOffFeatures(for item: OrbitItem) -> [AppFeature]? {
        item.feature.map { [$0] }
    }

    // MARK: Browsing and search

    /// The items a chip and a query leave. A query searches the whole
    /// catalog under the chosen chip.
    static func visible(in category: OrbitCategory, query: String,
                        isOn: (OrbitItemID) -> Bool,
                        words: [OrbitItemID: [String]] = [:],
                        from source: [OrbitItem] = items) -> [OrbitItem] {
        source.filter { item in
            switch category {
            case .all: break
            case .installed: guard isOn(item.id) else { return false }
            default: guard item.category == category else { return false }
            }
            return matches(item, query: query, words: words[item.id] ?? [])
        }
    }

    /// Settings search's rules: case, accents and word prefixes, then the
    /// item's summary, shelf, and the words Settings search knows it by,
    /// Indonesian aliases included.
    static func matches(_ item: OrbitItem, query: String, words: [String] = []) -> Bool {
        let text = ZenithStrings.orbit
        var keywords = [text.summary(item.id), text.category(item.category)] + words
        if let page = item.page { keywords += ZenithSettingsSearch.pageAliases[.page(page)] ?? [] }
        return SettingsSearchSupport.matches(query: query, title: text.name(item.id), keywords: keywords)
    }

    /// The words Settings search finds each item by: a feature's results
    /// (its localized name, the labels on its section and their aliases),
    /// and every result on a Zenith page that is not some feature's.
    static func searchWords(from results: [SettingsSearchItem]) -> [OrbitItemID: [String]] {
        var words: [OrbitItemID: [String]] = [:]
        for result in results {
            let terms = [result.title] + result.keywords + result.aliases
            var feature = result.feature
            if case .feature(let named) = result.id { feature = named }
            if let feature {
                words[.feature(feature), default: []] += terms
            } else if pages.contains(result.destination.page) {
                words[.page(result.destination.page), default: []] += terms
            }
        }
        return words
    }
}
