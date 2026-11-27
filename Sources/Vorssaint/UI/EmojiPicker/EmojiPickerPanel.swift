// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

// Zenith fork: the Emoji Picker's floating panel. Keyboard first: the search
// field has the keys, the arrows move through the grid, Return inserts,
// Escape closes. It never activates Zenith, so the app below keeps its key
// window for the paste.

/// What the panel shows and which emoji is chosen.
@MainActor
final class EmojiPickerModel: ObservableObject {
    static let columns = 9

    @Published var query = "" { didSet { rebuild() } }
    @Published private(set) var sections: [EmojiPickerSections.Section] = []
    @Published private(set) var selection = 0
    /// Bumped when the arrows move, so the grid scrolls to the choice (a
    /// hover choosing does not scroll).
    @Published private(set) var scrollSerial = 0

    let records: [EmojiRecord]
    let usage: EmojiUsage
    let preferences: EmojiPickerPreferences
    private var rows: [Range<Int>] = []
    private var flat: [EmojiRecord] = []

    init(records: [EmojiRecord], usage: EmojiUsage, preferences: EmojiPickerPreferences) {
        self.records = records
        self.usage = usage
        self.preferences = preferences
        rebuild()
    }

    var tone: CommandBarEmoji.SkinTone { preferences.skinTone }
    var selected: EmojiRecord? { flat.indices.contains(selection) ? flat[selection] : nil }
    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The flat index of an emoji in a section, for the grid's ids and clicks.
    func index(section: Int, item: Int) -> Int {
        sections.prefix(section).reduce(0) { $0 + $1.records.count } + item
    }

    func offset(of sectionID: String) -> Int? {
        guard let position = sections.firstIndex(where: { $0.id == sectionID }) else { return nil }
        return index(section: position, item: 0)
    }

    func move(_ move: EmojiGridNavigation.Move) {
        selection = EmojiGridNavigation.move(move, from: selection, rows: rows)
        scrollSerial += 1
    }

    func choose(_ index: Int, scroll: Bool = false) {
        guard flat.indices.contains(index) else { return }
        selection = index
        if scroll { scrollSerial += 1 }
    }

    private func rebuild() {
        if isSearching {
            let found = EmojiSearch.rank(records, query: query, usage: usage, limit: 240)
            sections = found.isEmpty ? [] : [EmojiPickerSections.Section(id: "results", title: "", symbol: "magnifyingglass",
                                                                           records: found)]
        } else {
            sections = EmojiPickerSections(records: records, usage: usage, recentCount: preferences.recentCount).sections
        }
        flat = sections.flatMap(\.records)
        rows = EmojiGridNavigation.rows(sectionCounts: sections.map(\.records.count), columns: Self.columns)
        selection = 0
    }
}

@MainActor
final class EmojiPickerPanelController {
    static let shared = EmojiPickerPanelController()

    private var panel: EmojiPickerPanel?
    private var model: EmojiPickerModel?
    private var keyMonitor: Any?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    private init() {}

    var isOpen: Bool { panel != nil }

    func show(_ model: EmojiPickerModel) {
        close()
        let view = EmojiPickerView(model: model, insert: { [weak self] in self?.insertSelected() })
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let panel = EmojiPickerPanel(contentRect: CGRect(origin: .zero, size: size),
                                     styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let visible = NSScreen.pointerVisibleFrame
        let pointer = NSEvent.mouseLocation
        var origin = CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height - 16)
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        self.panel = panel
        self.model = model
        installMonitors(for: panel)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        for monitor in [keyMonitor, localMonitor, globalMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        keyMonitor = nil
        localMonitor = nil
        globalMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil
    }

    private func insertSelected() {
        guard let model, let record = model.selected else { return ZenithQuiet.beep() }
        EmojiPickerService.shared.insert(record.character(model.tone), base: record.emoji)
    }

    private func installMonitors(for panel: NSPanel) {
        // The arrows, Return and Escape reach the grid before the search field.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === panel else { return event }
            let keyCode = Int(event.keyCode)
            let plain = event.modifierFlags.intersection([.command, .option, .control]).isEmpty
            let handled = MainActor.assumeIsolated { self?.handle(keyCode: keyCode, plain: plain) == true }
            return handled ? nil : event
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== panel { MainActor.assumeIsolated { self?.close() } }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func handle(keyCode: Int, plain: Bool) -> Bool {
        guard let model, plain else { return false }
        switch keyCode {
        case kVK_Escape:
            if model.isSearching { model.query = "" } else { close() }
        case kVK_Return, kVK_ANSI_KeypadEnter: insertSelected()
        case kVK_LeftArrow: model.move(.left)
        case kVK_RightArrow: model.move(.right)
        case kVK_UpArrow: model.move(.up)
        case kVK_DownArrow: model.move(.down)
        default: return false
        }
        return true
    }
}

private final class EmojiPickerPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - View

struct EmojiPickerView: View {
    @ObservedObject var model: EmojiPickerModel
    let insert: () -> Void
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let text = ZenithStrings.emojiPicker(.enUS)
    private static let cell: CGFloat = 36

    var body: some View {
        VStack(spacing: 10) {
            searchField
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    if model.sections.isEmpty {
                        Text(text.noResults)
                            .font(.system(size: 12.5))
                            .foregroundStyle(ZenithIsland.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        grid
                    }
                }
                .frame(height: 300)
                .onChange(of: model.scrollSerial) { _, _ in
                    guard let selected = model.selected else { return }
                    let id = gridID(of: model.selection, record: selected)
                    withAnimation(reduceMotion ? nil : .easeOut(duration: ZenithMotion.fast)) { proxy.scrollTo(id) }
                }
                .onChange(of: model.query) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
            footer
        }
        .padding(12)
        .frame(width: CGFloat(EmojiPickerModel.columns) * Self.cell + 24)
        .modifier(QRCardChrome(cornerRadius: 20))
        .modifier(QRArrival(shown: shown, reduceMotion: reduceMotion))
        .onAppear {
            searchFocused = true
            withAnimation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMorph.animation) { shown = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ZenithIsland.tertiary)
            TextField(text.searchPlaceholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(ZenithIsland.primary)
                .focused($searchFocused)
            if let selected = model.selected {
                Text(selected.character(model.tone))
                    .font(.system(size: 18))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .zenithIslandSoftCard(cornerRadius: 10)
    }

    private var grid: some View {
        LazyVStack(alignment: .leading, spacing: 6, pinnedViews: []) {
            Color.clear.frame(height: 0).id("top")
            ForEach(Array(model.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                if !section.title.isEmpty {
                    Text(section.title.uppercased())
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(ZenithIsland.tertiary)
                        .padding(.top, sectionIndex == 0 ? 0 : 6)
                        .id("section-\(section.id)")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.cell), spacing: 0), count: EmojiPickerModel.columns),
                          alignment: .leading, spacing: 0) {
                    ForEach(Array(section.records.enumerated()), id: \.offset) { item, record in
                        let index = model.index(section: sectionIndex, item: item)
                        EmojiPickerCell(emoji: record.character(model.tone), name: record.name,
                                        selected: index == model.selection, size: Self.cell)
                            .id(gridID(of: index, record: record))
                            .onHover { if $0 { model.choose(index) } }
                            .onTapGesture {
                                model.choose(index)
                                insert()
                            }
                    }
                }
            }
        }
    }

    private func gridID(of index: Int, record: EmojiRecord) -> String { "\(index)-\(record.emoji)" }

    private var footer: some View {
        HStack(spacing: 2) {
            if !model.isSearching {
                ForEach(EmojiCategory.allCases) { category in
                    Button {
                        if let offset = model.offset(of: category.rawValue) { model.choose(offset, scroll: true) }
                    } label: {
                        Image(systemName: category.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(currentCategory == category ? ZenithIsland.primary : ZenithIsland.tertiary)
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(category.title)
                    .accessibilityLabel(category.title)
                }
            }
            Spacer(minLength: 4)
            Text(model.selected?.name ?? text.hint)
                .font(.system(size: 10.5))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var currentCategory: EmojiCategory? { model.selected?.category }
}

/// One emoji in the grid, a soft tile behind the chosen one.
struct EmojiPickerCell: View {
    let emoji: String
    let name: String
    let selected: Bool
    let size: CGFloat

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.62))
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.white.opacity(0.16) : .clear))
            .contentShape(Rectangle())
            .accessibilityLabel(name)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
