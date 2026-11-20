// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: a customisable home page. The home page's card row, where the
// player used to sit alone, holds up to three widgets side by side, chosen
// in an edit mode the island's menu opens ("Customize Home"). The island
// widens to fit them, up to what the display allows, and a widget that would
// not fit is not offered.
//
// Everything here is pure (Foundation and CoreGraphics only) and compiled into
// the tests: the widgets, the layout and its rules, persistence, migration
// from the old home page, and the island's size. ZenithHomeEditor (UI) drives
// the edit mode; ZenithHomeLayoutView draws it.

/// A widget the home page's card row can hold.
enum ZenithHomeWidget: String, CaseIterable, Identifiable {
    case nowPlaying, timer, clipboard, calendar, weather, system, agents, shelf
    /// Up to three running dev servers (DevServersService).
    case devServers
    // Zenith fork: today is the day's recap so far (RecapService).
    case today
    /// The next prayer and the golden hour (SkyService).
    case prayer, golden

    var id: String { rawValue }

    /// The island page the widget is a small view of, which must be on for
    /// the widget to show; nil when it stands alone.
    var module: NotchModule? {
        switch self {
        case .nowPlaying: return .music
        case .timer: return .timer
        case .clipboard: return .clipboard
        case .calendar: return .calendar
        case .weather: return nil
        case .system: return .system
        case .agents: return .agents
        case .shelf: return .files
        case .devServers: return .devServers
        case .today: return .recap
        case .prayer, .golden: return .sky
        }
    }

    /// The glyph on its icon in the edit strip.
    var symbol: String {
        switch self {
        case .nowPlaying: return "music.note"
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard.fill"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .system: return "cpu.fill"
        case .agents: return "sparkles"
        case .shelf: return "tray.full.fill"
        case .devServers: return "server.rack"
        case .today: return "sun.horizon.fill"
        case .prayer: return "moon.stars.fill"
        case .golden: return "sun.horizon.fill"
        }
    }

    /// Its icon's colour: the colour of the page it comes from, so a widget
    /// and its page read as the same thing. Weather has no page and takes a
    /// light sky blue of its own.
    var hex: UInt32 {
        switch self {
        case .nowPlaying: return 0xFB7185
        case .timer: return 0xC084FC
        case .clipboard: return 0xA78BFA
        case .calendar: return 0xF87171
        case .weather: return 0x7DD3FC
        case .system: return 0x4ADE80
        case .agents: return 0xFB923C
        case .shelf: return 0x2DD4BF
        case .devServers: return 0x86EFAC
        case .today: return 0xA5B4FC
        case .prayer: return 0x93C5FD
        case .golden: return 0xFCD34D
        }
    }

    /// The width it reads best at in the card row. The player keeps its
    /// cover, a line of title and its transport; the others hold a reading
    /// and a control or two.
    var width: CGFloat {
        switch self {
        case .nowPlaying: return 300
        case .timer: return 196
        case .clipboard: return 252
        case .calendar: return 216
        case .weather: return 172
        case .system: return 196
        case .agents: return 196
        case .shelf: return 216
        case .devServers: return 216
        case .today: return 216
        case .prayer: return 196
        case .golden: return 216
        }
    }

    /// Whether the widget can show: its page is on, or it has none. The
    /// player follows the home page's own Music switch instead
    /// (`ZenithHomeLayout.resolved`).
    func isAvailable(modules: [NotchModule]) -> Bool {
        guard let module, self != .nowPlaying else { return true }
        return modules.contains(module)
    }
}

/// The widgets on the home page, in order.
struct ZenithHomeLayout: Equatable {
    /// Side by side in the card row, never more.
    static let maximum = 3
    /// Between two widgets.
    static let spacing: CGFloat = 10
    /// What a home page that was never customised stores: the layout follows
    /// the old home page, the player when its Music switch is on.
    static let automatic = "auto"

    private(set) var widgets: [ZenithHomeWidget]

    /// Keeps the first of each widget, up to the maximum.
    init(_ widgets: [ZenithHomeWidget] = []) {
        var seen = Set<ZenithHomeWidget>()
        self.widgets = Array(widgets.filter { seen.insert($0).inserted }.prefix(Self.maximum))
    }

    var isEmpty: Bool { widgets.isEmpty }
    var count: Int { widgets.count }
    func contains(_ widget: ZenithHomeWidget) -> Bool { widgets.contains(widget) }

    // MARK: Persistence

    /// Comma-separated raw values; an empty string is an empty home.
    var encoded: String { widgets.map(\.rawValue).joined(separator: ",") }

    /// A stored layout, or nil when none was ever chosen (no value, or the
    /// automatic marker). Unknown names from a later version are skipped and
    /// repeats keep their first place.
    static func decode(_ stored: String?) -> ZenithHomeLayout? {
        guard let stored else { return nil }
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != automatic else { return nil }
        return ZenithHomeLayout(trimmed.split(separator: ",").compactMap {
            ZenithHomeWidget(rawValue: $0.trimmingCharacters(in: .whitespaces))
        })
    }

    /// The home page as it was before it could be customised: the player
    /// when the Music switch is on, otherwise no cards.
    static func migrated(controlsHaveMusic: Bool) -> ZenithHomeLayout {
        ZenithHomeLayout(controlsHaveMusic ? [.nowPlaying] : [])
    }

    /// The layout to show. The home page's Music switch in Settings stays
    /// the say on the player: switched off, the player leaves; switched on
    /// while the layout lacks it, it comes back first, the last widget giving
    /// way when the row is full.
    static func resolved(stored: String?, controlsHaveMusic: Bool) -> ZenithHomeLayout {
        guard var layout = decode(stored) else { return migrated(controlsHaveMusic: controlsHaveMusic) }
        if !controlsHaveMusic {
            layout = layout.removing(.nowPlaying)
        } else if !layout.contains(.nowPlaying) {
            layout = ZenithHomeLayout([.nowPlaying] + layout.widgets.prefix(maximum - 1))
        }
        return layout
    }

    /// The widgets whose pages are on, in order.
    func shown(modules: [NotchModule]) -> [ZenithHomeWidget] {
        widgets.filter { $0.isAvailable(modules: modules) }
    }

    /// The hidden controls list after saving a layout: the Music switch
    /// follows whether the layout holds the player. The list keeps its
    /// sorted, comma-separated form.
    static func hiddenControls(_ hidden: String, showingMusic: Bool) -> String {
        var values = Set(hidden.split(separator: ",").map(String.init))
        if showingMusic { values.remove("music") } else { values.insert("music") }
        return values.sorted().joined(separator: ",")
    }

    // MARK: Editing

    /// The row's width for `widgets`, each at its own width.
    static func contentWidth(_ widgets: [ZenithHomeWidget]) -> CGFloat {
        guard !widgets.isEmpty else { return 0 }
        return widgets.reduce(0) { $0 + $1.width } + spacing * CGFloat(widgets.count - 1)
    }

    var contentWidth: CGFloat { Self.contentWidth(widgets) }

    /// Whether `widget` can join: it is not there yet, the row has room for
    /// one more, and the row would still fit `maximumWidth` (the widest page
    /// the display allows), when one is given.
    func canAdd(_ widget: ZenithHomeWidget, maximumWidth: CGFloat? = nil) -> Bool {
        guard !contains(widget), count < Self.maximum else { return false }
        guard let maximumWidth else { return true }
        return Self.contentWidth(widgets + [widget]) <= maximumWidth
    }

    /// The layout with `widget` at the end, or unchanged when it cannot join.
    func adding(_ widget: ZenithHomeWidget, maximumWidth: CGFloat? = nil) -> ZenithHomeLayout {
        canAdd(widget, maximumWidth: maximumWidth) ? ZenithHomeLayout(widgets + [widget]) : self
    }

    func removing(_ widget: ZenithHomeWidget) -> ZenithHomeLayout {
        ZenithHomeLayout(widgets.filter { $0 != widget })
    }

    /// `widget` moved to `index`, clamped to the row.
    func moving(_ widget: ZenithHomeWidget, to index: Int) -> ZenithHomeLayout {
        guard let from = widgets.firstIndex(of: widget) else { return self }
        var next = widgets
        next.remove(at: from)
        next.insert(widget, at: min(max(0, index), next.count))
        return ZenithHomeLayout(next)
    }
}

/// What the island needs to know about the home page's widgets.
struct ZenithHomeIslandGeometry: Equatable {
    /// The page's width for the widgets side by side; nil leaves the island
    /// its own width, as a single card fills the row as the player always did.
    var contentWidth: CGFloat?
    /// The row of cards shows.
    var hasCards: Bool
    /// The edit strip below the page, with its spacing; 0 outside edit mode.
    var stripHeight: CGFloat
}

/// The home page's widgets as the island sizes and draws them. The edit mode
/// keeps its draft here, beside the stored layout, so the island's geometry
/// (which the tests compile on its own) reads both without the UI.
enum ZenithHomeIsland {
    /// The layout's key in settings, registered so backups carry it.
    static let defaultsKey = DefaultsKey.zenithHomeLayout

    /// The edit strip: the Widgets and Shortcuts switch with Cancel and Done
    /// (26 points and 6 below), then the icons over their names (52).
    static let stripHeight: CGFloat = 84
    /// Above the strip, as the home page spaces its rows.
    static let stripSpacing: CGFloat = 10

    /// Edit mode is on, and the layout it is changing.
    static var editing = false
    static var draft: ZenithHomeLayout?

    static func stored(in defaults: UserDefaults = .standard) -> ZenithHomeLayout {
        resolved(in: defaults, controlsHaveMusic: NotchSupport.controls(in: defaults).contains(.music))
    }

    static func resolved(in defaults: UserDefaults, controlsHaveMusic: Bool) -> ZenithHomeLayout {
        ZenithHomeLayout.resolved(stored: defaults.string(forKey: defaultsKey), controlsHaveMusic: controlsHaveMusic)
    }

    /// The layout on screen: the draft while editing, otherwise the stored one.
    static func current(in defaults: UserDefaults = .standard) -> ZenithHomeLayout {
        editing ? (draft ?? stored(in: defaults)) : stored(in: defaults)
    }

    /// Saves `layout` and moves the Music switch with it.
    static func save(_ layout: ZenithHomeLayout, in defaults: UserDefaults = .standard) {
        defaults.set(layout.encoded, forKey: defaultsKey)
        let hidden = defaults.string(forKey: DefaultsKey.notchHiddenControls) ?? NotchControlItem.defaultHidden
        let next = ZenithHomeLayout.hiddenControls(hidden, showingMusic: layout.contains(.nowPlaying))
        if next != hidden { defaults.set(next, forKey: DefaultsKey.notchHiddenControls) }
    }

    /// The island's view of the home page for `widgets` (those that show).
    static func geometry(widgets: [ZenithHomeWidget], editing: Bool) -> ZenithHomeIslandGeometry {
        ZenithHomeIslandGeometry(contentWidth: widgets.count > 1 ? ZenithHomeLayout.contentWidth(widgets) : nil,
                                 hasCards: !widgets.isEmpty || editing,
                                 stripHeight: editing ? stripHeight + stripSpacing : 0)
    }

    static func geometry(modules: [NotchModule], in defaults: UserDefaults = .standard) -> ZenithHomeIslandGeometry {
        geometry(widgets: current(in: defaults).shown(modules: modules), editing: editing)
    }
}

extension NotchGeometry {
    /// The widest home page the display allows, inside the island's sides.
    var zenithHomeMaximumContentWidth: CGFloat {
        max(0, screen.width - 24 - NotchQuickAccessLayout.gutter * 2 - NotchLayout.horizontalInset * 2)
    }
}
