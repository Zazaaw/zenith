// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Directory construction is much more expensive than selecting an existing
/// row. Rebuild only when its language, icon source or availability changes.
final class SettingsDirectoryCache {
    private struct Key: Equatable {
        let language: AppLanguage
        let superKeySource: SuperKeySource
        let featureRevision: Int
    }

    private var navigationKey: Key?
    private(set) var sections: [SettingsSidebarSection] = []
    private(set) var items: [SettingsSidebarItem] = []
    private var searchKey: Key?
    private var searchState: SettingsSearchState?
    private var searchItems: [SettingsSearchItem] = []

    func navigation(strings: Strings, language: AppLanguage,
                    superKeySource: SuperKeySource, featureRevision: Int,
                    isAvailable: (AppFeature) -> Bool) -> [SettingsSidebarSection] {
        let key = Key(language: language, superKeySource: superKeySource,
                      featureRevision: featureRevision)
        if navigationKey != key {
            sections = SettingsDirectory.sidebarSections(
                strings, language: language, superKeySource: superKeySource,
                isAvailable: isAvailable)
            items = sections.flatMap(\.items)
            navigationKey = key
        }
        return sections
    }

    func search(strings: Strings, language: AppLanguage,
                superKeySource: SuperKeySource, featureRevision: Int,
                state: SettingsSearchState) -> [SettingsSearchItem] {
        let key = Key(language: language, superKeySource: superKeySource,
                      featureRevision: featureRevision)
        if searchKey != key || searchState != state {
            searchItems = SettingsDirectory.searchItems(
                strings, language: language, superKeySource: superKeySource, state: state)
            searchKey = key
            searchState = state
        }
        return searchItems
    }
}

/// Zenith fork: the floating sidebar of the Settings window. A rounded panel
/// inset from the window's edges, with the settings search on top, four big
/// tiles (General, Appearance, Command Bar, Orbit), the groups under small
/// uppercase headers, and the brand at its foot. Arrow keys move through the
/// tiles and rows once the sidebar has focus; while the search field has it,
/// they move through the results.
struct SettingsSidebarView: View {
    let cache: SettingsDirectoryCache

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.superKeySource) private var superKeySourceRaw = SuperKeySource.capsLock.rawValue
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var searchQuery = ""
    @State private var searchState: SettingsSearchState?
    @State private var activeSearchIndex: Int?
    @State private var collapsed: Set<SettingsSidebarGroup> = []
    @State private var navigationFromSidebar = false
    @FocusState private var searchFocused: Bool
    @FocusState private var listFocused: Bool

    static let width: CGFloat = 236
    static let cornerRadius: CGFloat = 18

    private struct SearchResultsSnapshot: Equatable {
        let query: String
        let groups: [SettingsSearchGroup]

        var isBlank: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var items: [SettingsSearchSuggestion] {
            groups.flatMap { group in
                (group.parentMatches ? [group.parentSuggestion] : []) + group.suggestions
            }
        }

        var ids: [SettingsSearchSuggestion.ID] { items.map(\.id) }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.query == rhs.query && lhs.ids == rhs.ids
        }
    }

    private var superKeySource: SuperKeySource { SuperKeySource.sanitized(superKeySourceRaw) }

    private var sections: [SettingsSidebarSection] {
        cache.navigation(strings: l10n.s, language: l10n.language, superKeySource: superKeySource,
                         featureRevision: features.revision, isAvailable: { features.isAvailable($0) })
    }

    private var items: [SettingsSidebarItem] {
        _ = sections
        return cache.items
    }

    private var selectedID: SettingsSidebarItem.ID? {
        SettingsSidebarSupport.selection(for: router.destination, in: items,
                                         preferredID: router.sidebarFeature.map { .feature($0) })
    }

    private var hasSearchQuery: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let searchResults: SearchResultsSnapshot = {
            guard hasSearchQuery else { return SearchResultsSnapshot(query: searchQuery, groups: []) }
            return SearchResultsSnapshot(
                query: searchQuery,
                groups: SettingsSearchSupport.groupedMatchingItems(
                    query: searchQuery,
                    items: cache.search(strings: l10n.s, language: l10n.language, superKeySource: superKeySource,
                                        featureRevision: features.revision, state: searchState ?? .current),
                    isAvailable: { features.isAvailable($0) }))
        }()

        VStack(spacing: 0) {
            SettingsSidebarSearchField(query: $searchQuery, isFocused: $searchFocused)
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 4)
            list(searchResults: searchResults)
            ZenithSidebarFooter()
        }
        .frame(width: Self.width)
        .background { panelBackground }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: contrast == .increased ? 1.5 : 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n.s.settingsTitle)
        .onAppear { expandSelectedGroup() }
        .onChange(of: hasSearchQuery) { _, searching in
            searchState = searching ? .current : nil
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification))
            .receive(on: RunLoop.main)) { _ in
                if hasSearchQuery { searchState = .current }
            }
        .onChange(of: searchResults, initial: true) { previous, current in
            updateSearchSelection(previous: previous, current: current)
        }
        .background {
            SettingsSearchKeyMonitor(customSearchFocused: searchFocused) { keyCode in
                handleSearchKey(keyCode, searchResults: searchResults.items)
            }
        }
    }

    // MARK: Panel

    @ViewBuilder
    private var panelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
#if compiler(>=6.2)
        if #available(macOS 26.0, *),
           HUDBackdrop.drawsLiquidGlass(enabled: liquidGlassEnabled, reduceTransparency: reduceTransparency) {
            shape.fill(Color.clear)
                .glassEffect(.regular, in: shape)
                .overlay(shape.fill(solidFill.opacity(contrast == .increased ? 0.8 : 0.45)))
        } else {
            shape.fill(solidFill)
        }
#else
        shape.fill(solidFill)
#endif
    }

    /// A step lighter than the window in Dark Mode, near white in Light Mode.
    private var solidFill: Color {
        colorScheme == .dark ? Color(white: 0.145) : Color(white: 0.985)
    }

    private var borderColor: Color {
        if contrast == .increased { return Color.primary.opacity(0.45) }
        return colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.08)
    }

    // MARK: List

    private func list(searchResults: SearchResultsSnapshot) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if hasSearchQuery {
                        searchResultRows(searchResults)
                    } else {
                        navigationRows
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
            .focusable(!hasSearchQuery)
            .focusEffectDisabled()
            .focused($listFocused)
            .onMoveCommand { direction in
                guard let next = SettingsSidebarNavigation.move(
                    from: selectedID, direction: direction.sidebarDirection,
                    tiles: sections.first { $0.group == .tiles }?.items.map(\.id) ?? [],
                    rows: visibleRows.map(\.id)) else { return }
                pick(next)
                scroll(proxy, to: next, anchor: nil)
            }
            .onChange(of: activeSearchIndex) { _, index in
                guard let index, searchResults.items.indices.contains(index) else { return }
                scroll(proxy, to: searchResults.items[index].id, anchor: nil)
            }
            .onChange(of: hasSearchQuery) { _, searching in
                // Leaving a search brings the open page back into view.
                guard !searching else { return }
                expandSelectedGroup()
                DispatchQueue.main.async { scrollToSelection(proxy) }
            }
            .onChange(of: router.requestID) { _, _ in
                searchQuery = ""
                activeSearchIndex = nil
                // A click in the sidebar is already visible. Only external
                // routes need to reveal and scroll to their destination.
                let fromSidebar = navigationFromSidebar
                navigationFromSidebar = false
                guard !fromSidebar else { return }
                expandSelectedGroup()
                DispatchQueue.main.async { scrollToSelection(proxy) }
            }
        }
    }

    /// The rows the arrow keys walk through: every row of an open group.
    private var visibleRows: [SettingsSidebarItem] {
        sections.filter { $0.group != .tiles && !collapsed.contains($0.group) }.flatMap(\.items)
    }

    @ViewBuilder
    private var navigationRows: some View {
        let selected = selectedID
        ForEach(sections) { section in
            if section.group == .tiles {
                tiles(section.items, selected: selected)
            } else {
                groupHeader(section)
                if !collapsed.contains(section.group) {
                    ForEach(section.items) { item in
                        SettingsSidebarRow(item: item, isSelected: selected == item.id) { pick(item.id) }
                            .id(item.id)
                    }
                }
            }
        }
    }

    private func tiles(_ items: [SettingsSidebarItem], selected: SettingsSidebarItem.ID?) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items) { item in
                SettingsSidebarTile(item: item, isSelected: selected == item.id) { pick(item.id) }
                    .id(item.id)
            }
        }
        .padding(.bottom, 4)
    }

    private func groupHeader(_ section: SettingsSidebarSection) -> some View {
        SettingsSidebarGroupHeader(title: section.title, isCollapsed: collapsed.contains(section.group)) {
            let toggle = {
                if !collapsed.insert(section.group).inserted { collapsed.remove(section.group) }
            }
            if reduceMotion { toggle() } else { withAnimation(.snappy(duration: 0.2)) { toggle() } }
        }
    }

    private func pick(_ id: SettingsSidebarItem.ID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let feature: AppFeature?
        if case .feature(let selectedFeature) = id { feature = selectedFeature } else { feature = nil }
        if !searchFocused { listFocused = true }
        navigationFromSidebar = true
        router.request(item.destination, sidebarFeature: feature)
    }

    private func scroll<ID: Hashable>(_ proxy: ScrollViewProxy, to id: ID, anchor: UnitPoint?) {
        if reduceMotion {
            proxy.scrollTo(id, anchor: anchor)
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: anchor) }
        }
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard !hasSearchQuery, let selected = selectedID ?? items.first?.id else { return }
        proxy.scrollTo(selected, anchor: .center)
    }

    private func expandSelectedGroup() {
        guard let selected = selectedID else { return }
        collapsed.remove(SettingsSidebarGroup.of(selected))
    }

    // MARK: Search

    @ViewBuilder
    private func searchResultRows(_ searchResults: SearchResultsSnapshot) -> some View {
        ForEach(searchResults.groups, id: \.parentSuggestion.id) { group in
            searchPageRow(group, searchResults: searchResults)
            ForEach(group.suggestions) { suggestion in
                searchSuggestionRow(suggestion, searchResults: searchResults)
            }
        }
    }

    private func searchPageRow(_ group: SettingsSearchGroup, searchResults: SearchResultsSnapshot) -> some View {
        let suggestion = group.parentSuggestion
        let isSelected = searchResults.items.firstIndex { $0.id == suggestion.id } == activeSearchIndex
        return Button {
            requestSearchItem(suggestion)
        } label: {
            HStack(spacing: 8) {
                SettingsDestinationIcon(id: .page(group.id), symbol: group.pageItem.icon, size: 20)
                Text(group.pageItem.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
            }
            .searchResultRowStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding(.top, 4)
        .id(suggestion.id)
    }

    private func searchSuggestionRow(_ suggestion: SettingsSearchSuggestion,
                                     searchResults: SearchResultsSnapshot) -> some View {
        let isSelected = searchResults.items.firstIndex { $0.id == suggestion.id } == activeSearchIndex
        return Button {
            requestSearchItem(suggestion)
        } label: {
            Label(suggestion.title, systemImage: suggestion.icon)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .searchResultRowStyle(isSelected: isSelected)
                .padding(.leading, 18)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(suggestion.id)
    }

    private func handleSearchKey(_ keyCode: UInt16, searchResults: [SettingsSearchSuggestion]) -> Bool {
        switch keyCode {
        case 126: // Up
            guard !searchResults.isEmpty else { return false }
            activeSearchIndex = SettingsSearchSupport.moveSelection(
                index: activeSearchIndex, delta: -1, count: searchResults.count)
            return true
        case 125: // Down
            guard !searchResults.isEmpty else { return false }
            activeSearchIndex = SettingsSearchSupport.moveSelection(
                index: activeSearchIndex, delta: 1, count: searchResults.count)
            return true
        case 36, 76: // Return / Keypad Enter
            guard let index = activeSearchIndex, searchResults.indices.contains(index) else { return false }
            requestSearchItem(searchResults[index])
            return true
        default:
            return false
        }
    }

    private func updateSearchSelection(previous: SearchResultsSnapshot, current: SearchResultsSnapshot) {
        guard !current.isBlank, !current.items.isEmpty else {
            activeSearchIndex = nil
            return
        }
        if previous.query != current.query {
            activeSearchIndex = 0
        } else if previous.ids != current.ids {
            activeSearchIndex = SettingsSearchSupport.reconciledSelection(
                index: activeSearchIndex, previousIDs: previous.ids, resultIDs: current.ids)
        }
    }

    private func requestSearchItem(_ suggestion: SettingsSearchSuggestion) {
        activeSearchIndex = nil
        let routed = SettingsSearchSupport.route(for: suggestion)
        router.request(routed.destination, targetFeature: routed.targetFeature,
                       sidebarFeature: suggestion.item.feature)
    }
}

// MARK: - Keyboard navigation

private extension MoveCommandDirection {
    var sidebarDirection: SettingsSidebarDirection {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        @unknown default: return .down
        }
    }
}

// MARK: - Tiles and rows

/// One of the four big tiles: the icon over the title, filled with the
/// accent colour while its page is open.
private struct SettingsSidebarTile: View {
    let item: SettingsSidebarItem
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    private var title: String {
        item.id == .page(.features) ? SettingsSidebarLayout.orbitTitle : item.title
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsDestinationIcon(id: item.id, symbol: item.icon, size: 28)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor)
                                     : AnyShapeStyle(Color.primary.opacity(hovering ? 0.08 : 0.05)))
            }
            .overlay {
                if contrast == .increased, !isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.35))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A group's small uppercase name. Clicking it folds the group; the chevron
/// shows while the pointer is over it, or while the group is folded.
private struct SettingsSidebarGroupHeader: View {
    let title: String
    let isCollapsed: Bool
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .opacity(hovering || isCollapsed ? 1 : 0)
            }
            .foregroundStyle(contrast == .increased ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
            .padding(.leading, 6)
            .padding(.trailing, 4)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
    }
}

/// A row of a group: the compact Orbit icon and the title.
private struct SettingsSidebarRow: View {
    let item: SettingsSidebarItem
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SettingsDestinationIcon(id: item.id, symbol: item.icon, size: 20)
                Text(item.title)
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 26)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor)
                                     : AnyShapeStyle(Color.primary.opacity(hovering ? 0.06 : 0)))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Search field

/// The settings search, styled after the system's pill. Esc and the clear
/// button empty the query, matching the system field.
private struct SettingsSidebarSearchField: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(l10n.s.settingsSearchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused(isFocused)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.urlCleanerClearButton)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

/// Up, Down and Return move through and open the search results while the
/// search field has focus, without the field losing it.
private struct SettingsSearchKeyMonitor: NSViewRepresentable {
    var customSearchFocused: Bool
    var handleKey: (UInt16) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.customSearchFocused = customSearchFocused
        context.coordinator.handleKey = handleKey
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(customSearchFocused: customSearchFocused, handleKey: handleKey)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator: NSObject {
        var customSearchFocused: Bool
        var handleKey: (UInt16) -> Bool
        private var monitor: Any?

        init(customSearchFocused: Bool, handleKey: @escaping (UInt16) -> Bool) {
            self.customSearchFocused = customSearchFocused
            self.handleKey = handleKey
        }

        func install(for view: NSView) {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak view] event in
                guard let self, let view, let window = view.window,
                      event.window === window,
                      Self.isNavigationKey(event),
                      let editor = window.firstResponder as? NSTextView,
                      editor.isFieldEditor,
                      customSearchFocused,
                      !editor.hasMarkedText() else { return event }
                return handleKey(event.keyCode) ? nil : event
            }
        }

        func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        private static func isNavigationKey(_ event: NSEvent) -> Bool {
            let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            guard event.modifierFlags.intersection(blockedModifiers).isEmpty else { return false }
            return [UInt16(126), 125, 36, 76].contains(event.keyCode)
        }
    }
}

private extension View {
    func searchResultRowStyle(isSelected: Bool) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
            }
    }
}
