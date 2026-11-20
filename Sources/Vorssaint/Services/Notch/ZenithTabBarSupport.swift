// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: what the open island's tab pill (ZenithIslandDock) holds,
// chosen in Settings → Dynamic Island → Layout → Tab bar. The owner pins up to
// six sections in their own order; the gallery always closes the pill, so
// every section stays one click away. Pure, so the tests read it as the pill
// and the card do.

/// One tab in the pill: a pinned section, the open page while it is not
/// pinned, or the section gallery.
enum ZenithTabBarItem: Hashable, Identifiable {
    case module(NotchModule)
    case page(NotchModule)
    case gallery
    var id: Self { self }

    var module: NotchModule? {
        switch self {
        case .module(let module), .page(let module): return module
        case .gallery: return nil
        }
    }
}

/// The pill's tabs and which one is chosen, if any.
struct ZenithTabBarLayout: Equatable {
    var items: [ZenithTabBarItem]
    var chosen: ZenithTabBarItem?
}

/// The sections pinned in the pill as stored: their raw values in order.
/// Names this version does not know are kept, so a backup from a later one
/// keeps its pins, but nothing reads them.
struct ZenithTabBarPins: Equatable {
    private(set) var raw: [String]

    init(raw: [String]) {
        var seen = Set<String>()
        self.raw = raw.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    init(_ modules: [NotchModule]) { self.init(raw: modules.map(\.rawValue)) }

    init(encoded: String) {
        self.init(raw: encoded.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    var encoded: String { raw.joined(separator: ",") }

    /// Every known section stored, unavailable ones included, in order.
    var known: [NotchModule] { raw.compactMap(NotchModule.init(rawValue:)) }

    /// The pinned tabs that show: known and available, in order, at most six.
    func visible(available: [NotchModule]) -> [NotchModule] {
        let shown = Set(available)
        return Array(known.filter(shown.contains).prefix(ZenithTabBar.maximumPinned))
    }

    func isPinned(_ module: NotchModule, available: [NotchModule]) -> Bool {
        visible(available: available).contains(module)
    }

    func isFull(available: [NotchModule]) -> Bool {
        visible(available: available).count >= ZenithTabBar.maximumPinned
    }

    /// An available section can join while the pill has room.
    func canPin(_ module: NotchModule, available: [NotchModule]) -> Bool {
        available.contains(module) && !isPinned(module, available: available) && !isFull(available: available)
    }

    /// A new pin joins the end, just before the gallery.
    func pinning(_ module: NotchModule, available: [NotchModule]) -> ZenithTabBarPins {
        guard canPin(module, available: available) else { return self }
        return ZenithTabBarPins(raw: raw.filter { $0 != module.rawValue } + [module.rawValue])
    }

    func unpinning(_ module: NotchModule) -> ZenithTabBarPins {
        ZenithTabBarPins(raw: raw.filter { $0 != module.rawValue })
    }

    /// Moves a shown pin to `index` among the shown pins, clamped at both
    /// ends. What does not show (unknown, unavailable) keeps its place.
    func moving(_ module: NotchModule, to index: Int, available: [NotchModule]) -> ZenithTabBarPins {
        var shown = visible(available: available)
        guard let from = shown.firstIndex(of: module) else { return self }
        shown.remove(at: from)
        shown.insert(module, at: min(max(0, index), shown.count))
        return reordering(shown, available: available)
    }

    /// The shown pins in a new order, as a drag leaves them; anything but a
    /// reordering of exactly the shown pins changes nothing.
    func reordering(_ order: [NotchModule], available: [NotchModule]) -> ZenithTabBarPins {
        let shown = visible(available: available)
        guard order.count == shown.count, Set(order) == Set(shown) else { return self }
        let slots = Set(shown.map(\.rawValue))
        var next = order.makeIterator()
        return ZenithTabBarPins(raw: raw.map { slots.contains($0) ? (next.next()?.rawValue ?? $0) : $0 })
    }

    /// Every section in the order the card lists it: the shown pins first,
    /// as in the pill, then the rest in the island's order.
    func listed(available: [NotchModule], order: [NotchModule]) -> [NotchModule] {
        let shown = visible(available: available)
        var seen = Set(shown)
        return shown + (order + NotchModule.allCases).filter { seen.insert($0).inserted }
    }
}

/// The tab bar's settings, as the pill and the Settings card read them.
struct ZenithTabBarConfiguration: Equatable {
    var enabled = true
    var pins = ZenithTabBarPins(ZenithTabBar.defaultPins)
    /// A temporary tab for the open page while it is not pinned.
    var currentPage = true
    /// Counts on the tabs that have one (the Shelf, notifications).
    var badges = true
}

enum ZenithTabBar {
    static let maximumPinned = 6
    /// Home and Files: the pill as it was before it could be chosen.
    static let defaultPins: [NotchModule] = [.controls, .files]
    static var defaultEncoded: String { ZenithTabBarPins(defaultPins).encoded }
    /// The sections whose tab can carry a count.
    static let badgedModules: Set<NotchModule> = [.files, .notifications]

    static func configuration(in defaults: UserDefaults = .standard) -> ZenithTabBarConfiguration {
        ZenithTabBarConfiguration(
            enabled: isEnabled(in: defaults),
            pins: ZenithTabBarPins(encoded: defaults.string(forKey: DefaultsKey.zenithTabBarModules) ?? defaultEncoded),
            currentPage: defaults.object(forKey: DefaultsKey.zenithTabBarCurrentPage) as? Bool ?? true,
            badges: defaults.object(forKey: DefaultsKey.zenithTabBarBadges) as? Bool ?? true)
    }

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: DefaultsKey.zenithTabBarEnabled) as? Bool ?? true
    }

    static func save(_ pins: ZenithTabBarPins, in defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: DefaultsKey.zenithTabBarModules) ?? defaultEncoded != pins.encoded else { return }
        defaults.set(pins.encoded, forKey: DefaultsKey.zenithTabBarModules)
    }

    /// Whether the open page's top row leads with the gallery's button. The
    /// pill holds the way there while it shows; without it, the island goes
    /// back to upstream's rule: the row keeps the button unless a floating
    /// button already leads to the gallery.
    static func sectionsButtonInRow(floatingExplore: Bool, in defaults: UserDefaults = .standard) -> Bool {
        !isEnabled(in: defaults) && !floatingExplore
    }

    /// The pill: the shown pins, then the open page's own tab while it is not
    /// one of them (or a detail covers it) and the current page is wanted,
    /// and always the gallery last. `page` is nil while the gallery shows.
    static func layout(_ configuration: ZenithTabBarConfiguration, available: [NotchModule],
                       page: NotchModule?, detail: Bool) -> ZenithTabBarLayout {
        let pinned = configuration.pins.visible(available: available)
        var items = pinned.map(ZenithTabBarItem.module)
        var chosen: ZenithTabBarItem? = page == nil ? .gallery : nil
        if let page {
            if !detail, pinned.contains(page) {
                chosen = .module(page)
            } else if configuration.currentPage {
                items.append(.page(page))
                chosen = .page(page)
            }
        }
        items.append(.gallery)
        return ZenithTabBarLayout(items: items, chosen: chosen)
    }

    /// The count a tab shows, if it shows one.
    static func badge(_ item: ZenithTabBarItem, counts: [NotchModule: Int], enabled: Bool, detail: Bool = false) -> Int? {
        guard enabled, let module = item.module, badgedModules.contains(module),
              !(detail && item == .page(module)), let count = counts[module], count > 0 else { return nil }
        return count
    }

    /// A tab's glyph: Home and Files in their filled forms, as the pill
    /// first drew them, every other section in its own.
    static func symbol(_ module: NotchModule) -> String {
        switch module {
        case .controls: return "house.fill"
        case .files: return "tray.fill"
        default: return module.symbol
        }
    }
}

/// Why a section can or cannot be pinned on this Mac.
enum ZenithTabBarAvailability: Equatable {
    /// It shows in the island, so its tab can too.
    case available
    /// It could show, but is switched off in the island's sections.
    case hidden
    /// Its feature is off or missing on this Mac.
    case unavailable

    static func of(_ module: NotchModule, routed: [NotchModule], in defaults: UserDefaults = .standard) -> Self {
        if routed.contains(module) { return .available }
        return module.isAvailable(in: defaults) ? .hidden : .unavailable
    }
}
