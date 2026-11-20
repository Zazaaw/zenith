// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the home page's row of shortcuts, edited in the island.
//
// "Customize Home" edits the shortcuts under the widgets as well: each one in
// the row gets a remove badge and can be dragged to a new place, and the
// strip's Shortcuts side offers every shortcut this Mac can show. Cancel puts
// the row back; Done saves it with the widgets.
//
// The row is stored where upstream keeps it, in the keys the Home controls in
// Settings edit: `notchControlOrder` (the order) and `notchHiddenControls`
// (those switched off). Both are registered, so backups carry them, and the
// island and Settings always edit the same truth.
//
// Everything here is pure (Foundation and CoreGraphics only) and compiled into
// the tests. ZenithHomeEditor (UI) drives the edit mode; ZenithHomeShortcutsView
// draws it.

/// The home page's shortcuts: every shortcut in the row's order, and those
/// switched off. Levels (the island's top row) and the player (a widget now)
/// are not shortcuts and keep their own settings.
struct ZenithHomeShortcuts: Equatable {
    /// Everything the row can hold, in upstream's order.
    static let candidates: [NotchControlItem] = NotchControlItem.allCases.filter(isShortcut)

    static func isShortcut(_ item: NotchControlItem) -> Bool { !item.isLevel && item != .music }

    /// Every shortcut, in order: the stored ones first, then any the list has
    /// not met yet, as upstream reads it.
    private(set) var order: [NotchControlItem]
    /// The shortcuts switched off, whatever this Mac makes available.
    private(set) var hidden: Set<NotchControlItem>

    init(order: [NotchControlItem] = [], hidden: Set<NotchControlItem> = []) {
        var seen = Set<NotchControlItem>()
        self.order = (order + Self.candidates).filter { Self.isShortcut($0) && seen.insert($0).inserted }
        self.hidden = hidden.filter(Self.isShortcut)
    }

    /// The row: the shortcuts switched on that this Mac can show, in order.
    func shown(available: Set<NotchControlItem>) -> [NotchControlItem] {
        order.filter { !hidden.contains($0) && available.contains($0) }
    }

    /// What the strip offers: every shortcut this Mac can show, in order.
    func offered(available: Set<NotchControlItem>) -> [NotchControlItem] {
        order.filter { available.contains($0) }
    }

    func contains(_ item: NotchControlItem) -> Bool { Self.isShortcut(item) && !hidden.contains(item) }

    // MARK: Editing

    /// Whether `item` can join the row: a shortcut this Mac can show, not in
    /// the row yet, with room for one more.
    func canAdd(_ item: NotchControlItem, available: Set<NotchControlItem>, capacity: Int = .max) -> Bool {
        Self.isShortcut(item) && available.contains(item) && !contains(item)
            && shown(available: available).count < capacity
    }

    /// `item` switched on at the end of the row, or unchanged when it cannot join.
    func adding(_ item: NotchControlItem, available: Set<NotchControlItem>, capacity: Int = .max) -> ZenithHomeShortcuts {
        guard canAdd(item, available: available, capacity: capacity) else { return self }
        let last = shown(available: available).last
        var next = self
        next.hidden.remove(item)
        next.order.removeAll { $0 == item }
        let index = last.flatMap { next.order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        next.order.insert(item, at: index)
        return next
    }

    /// `item` switched off. It keeps its place in the order, as a switch in
    /// Settings leaves it.
    func removing(_ item: NotchControlItem) -> ZenithHomeShortcuts {
        guard contains(item) else { return self }
        var next = self
        next.hidden.insert(item)
        return next
    }

    /// `item` moved to `index` within the row, clamped to it. The shortcuts
    /// outside the row (switched off, or unavailable here) keep their places.
    func moving(_ item: NotchControlItem, to index: Int, available: Set<NotchControlItem>) -> ZenithHomeShortcuts {
        var row = shown(available: available)
        guard let from = row.firstIndex(of: item) else { return self }
        row.remove(at: from)
        row.insert(item, at: min(max(0, index), row.count))
        let members = Set(row)
        var next = self
        for (slot, member) in zip(order.indices.filter { members.contains(order[$0]) }, row) {
            next.order[slot] = member
        }
        return next
    }

    /// `item` moved `offset` places along the row.
    func moving(_ item: NotchControlItem, by offset: Int, available: Set<NotchControlItem>) -> ZenithHomeShortcuts {
        guard let index = shown(available: available).firstIndex(of: item) else { return self }
        return moving(item, to: index + offset, available: available)
    }

    // MARK: Persistence

    /// The row from upstream's two lists. No hidden list means upstream's
    /// default; unknown names from a later version are skipped.
    static func decode(order: String?, hidden: String?) -> ZenithHomeShortcuts {
        func items(_ list: String) -> [NotchControlItem] {
            list.split(separator: ",").compactMap { NotchControlItem(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        }
        return ZenithHomeShortcuts(order: items(order ?? ""), hidden: Set(items(hidden ?? NotchControlItem.defaultHidden)))
    }

    /// The order list as Settings writes it: every shortcut, comma-separated.
    var encodedOrder: String { order.map(\.rawValue).joined(separator: ",") }

    /// `stored`, the whole hidden list, with this row's shortcuts in it. The
    /// levels, the player and names from a later version keep their entries;
    /// the list stays sorted, as Settings writes it.
    func encodedHidden(preserving stored: String) -> String {
        var values = Set(stored.split(separator: ",").map(String.init).filter { value in
            NotchControlItem(rawValue: value).map { !Self.isShortcut($0) } ?? true
        })
        values.formUnion(hidden.map(\.rawValue))
        return values.sorted().joined(separator: ",")
    }

    static func stored(in defaults: UserDefaults = .standard) -> ZenithHomeShortcuts {
        decode(order: defaults.string(forKey: DefaultsKey.notchControlOrder),
               hidden: defaults.string(forKey: DefaultsKey.notchHiddenControls))
    }

    /// The shortcuts this Mac can show: their features installed and on, and
    /// the pages they open shown (upstream's `isAvailable`).
    static func available(in defaults: UserDefaults = .standard) -> Set<NotchControlItem> {
        Set(candidates.filter { $0.isAvailable(in: defaults) })
    }

    /// Writes the row to upstream's keys, touching only what changed.
    func save(in defaults: UserDefaults = .standard) {
        let hiddenList = defaults.string(forKey: DefaultsKey.notchHiddenControls) ?? NotchControlItem.defaultHidden
        let nextHidden = encodedHidden(preserving: hiddenList)
        if Set(nextHidden.split(separator: ",")) != Set(hiddenList.split(separator: ",")) {
            defaults.set(nextHidden, forKey: DefaultsKey.notchHiddenControls)
        }
        let storedOrder = defaults.string(forKey: DefaultsKey.notchControlOrder) ?? ""
        if Self.decode(order: storedOrder, hidden: nil).order != order {
            defaults.set(encodedOrder, forKey: DefaultsKey.notchControlOrder)
        }
    }

    /// The home page's controls with this row in place of their shortcuts:
    /// the levels and the player from `controls`, then the row.
    func controls(replacing controls: [NotchControlItem], available: Set<NotchControlItem>) -> [NotchControlItem] {
        controls.filter { !Self.isShortcut($0) } + shown(available: available)
    }

    // MARK: Fitting

    /// How many shortcuts the home page holds without its rail scrolling
    /// sideways, `width` wide and `height` high, laid out as the page lays
    /// them out (`NotchLayout.controls`): the rows its height allows, each as
    /// many tiles as the width takes once the gaps close. At least one.
    static func capacity(width: CGFloat, height: CGFloat, hasCards: Bool, levelRow: Bool) -> Int {
        var fitting = 0
        for count in 1...candidates.count {
            let layout = NotchLayout.controls(hasCards: hasCards, levelRow: levelRow, shortcutCount: count,
                                              width: width, height: height)
            let columns = NotchLayout.railColumns(count: count, rows: layout.shortcutRows)
            guard layout.shortcutRows > 0,
                  NotchLayout.railGap(columns: columns, itemWidth: NotchLayout.shortcutWidth,
                                      spacing: NotchLayout.shortcutSpacing, least: NotchLayout.shortcutLeastSpacing,
                                      width: width) != nil else { break }
            fitting = count
        }
        return max(1, fitting)
    }
}

extension NotchGeometry {
    /// How many shortcuts this island's home page holds without its rail
    /// scrolling, with `levels` levels and with or without the card row: the
    /// page's whole budget, as `expandedSize` gives it, at its width.
    func zenithHomeShortcutCapacity(levels: Int, hasCards: Bool) -> Int {
        let count = max(0, levels)
        let levelRow = NotchLayout.bandLevelCount(count, band: NotchBand(geometry: self, contentWidth: contentWidth)) < count
        let room = contentBudget + (levelRow && layout != .custom ? NotchLayout.levelRowHeight + NotchLayout.rowSpacing : 0)
        return ZenithHomeShortcuts.capacity(width: contentWidth, height: room, hasCards: hasCards, levelRow: levelRow)
    }
}

extension ZenithHomeIsland {
    /// The shortcuts edit mode is changing, beside the widgets' draft.
    static var shortcutDraft: ZenithHomeShortcuts?

    /// The home page's controls as the island sizes them: while editing, the
    /// draft's row in place of the stored shortcuts.
    static func controls(_ controls: [NotchControlItem], in defaults: UserDefaults = .standard) -> [NotchControlItem] {
        guard editing, let shortcutDraft else { return controls }
        return shortcutDraft.controls(replacing: controls, available: ZenithHomeShortcuts.available(in: defaults))
    }
}
