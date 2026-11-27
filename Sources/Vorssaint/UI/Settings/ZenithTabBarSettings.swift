// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Tab bar card in Settings → Dynamic Island → Layout. It
/// chooses what the pill under the open island holds (ZenithTabBar): a live
/// preview drawn with the island's own pill, the master switch, every section
/// in pill order with a switch that pins it (up to six, dragged or moved to
/// order them), the gallery fixed at the end, the open page's own tab and
/// the counts. Nothing about the pill is edited in the island itself.
struct ZenithTabBarSettings: View {
    @ObservedObject private var l10n = L10n.shared
    /// Its sections' switches and order live elsewhere; a change there
    /// syncs the island, which redraws this card.
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var shelf = ShelfService.shared
    @ObservedObject private var notifications = NotchNotificationService.shared
    @AppStorage(DefaultsKey.zenithTabBarEnabled) private var enabled = true
    @AppStorage(DefaultsKey.zenithTabBarModules) private var pinsRaw = ZenithTabBar.defaultEncoded
    @AppStorage(DefaultsKey.zenithTabBarCurrentPage) private var currentPage = true
    @AppStorage(DefaultsKey.zenithTabBarBadges) private var badges = true
    // Read so the list follows the Content tab: sections shown or hidden there, and their order.
    @AppStorage(DefaultsKey.notchHiddenModules) private var hiddenModules = ""
    @AppStorage(DefaultsKey.notchModuleOrder) private var moduleOrder = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragging: NotchModule?

    private var text: ZenithTabBarStrings { ZenithStrings.tabBar(l10n.language) }
    private var pins: ZenithTabBarPins { ZenithTabBarPins(encoded: pinsRaw) }

    var body: some View {
        let routed = NotchSupport.modules()
        let pinned = pins.visible(available: routed)
        let full = pins.isFull(available: routed)
        // A heading drawn here rather than through SettingsCard's title, whose
        // labels Settings search indexes from upstream's catalogs.
        VStack(alignment: .leading, spacing: 8) {
            ZenithSectionTitle(text.section) // the kit's section title, as the island page's others
            SettingsCard {
                preview(routed: routed, pinned: pinned)
                ZenithSwitchRow(text.show, isOn: $enabled) { label(text.show, caption: text.showHint) }
                VStack(alignment: .leading, spacing: 13) {
                    hairline
                    Text(text.tabs)
                        .font(ZenithType.emphasis)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 2) {
                        ForEach(pins.listed(available: routed, order: orderedModules)) { module in
                            let index = pinned.firstIndex(of: module)
                            PanelReorderableItem(item: module, isEnabled: index != nil && enabled,
                                                 order: Binding(get: { pinned }, set: { reorder($0, routed: routed) }),
                                                 dragging: $dragging) {
                                row(module, index: index, count: pinned.count, full: full, routed: routed)
                            }
                        }
                        galleryRow
                    }
                    Text(full ? text.full : text.limit(ZenithTabBar.maximumPinned))
                        .font(ZenithType.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    hairline
                    ZenithSwitchRow(text.currentPage, isOn: $currentPage) {
                        label(text.currentPage, caption: text.currentPageHint)
                    }
                    ZenithSwitchRow(text.badges, isOn: $badges) { label(text.badges, caption: text.badgesHint) }
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.45)
            }
        }
        .zenithSectionAnchor(.zenithTabBar, cornerRadius: ZenithRadius.panel + 6, inset: 6) // Settings search lands here
    }

    // MARK: Preview

    /// The island's own pill, as it shows with these choices: a pinned tab
    /// chosen, or, with the current page on, a section not pinned open as
    /// that page. Counts read live, with a sample while there are none.
    private func preview(routed: [NotchModule], pinned: [NotchModule]) -> some View {
        let page = currentPage ? routed.first { !pinned.contains($0) } ?? pinned.first : pinned.first
        let configuration = ZenithTabBarConfiguration(pins: pins, currentPage: currentPage)
        let layout = ZenithTabBar.layout(configuration, available: routed, page: page, detail: false)
        let counts: [NotchModule: Int] = badges
            ? [.files: max(shelf.items.count, 3), .notifications: max(notifications.items.count, 2)] : [:]
        return ZenithIslandDockPill(tabs: ZenithIslandDockTabs(layout: layout, detail: false), counts: counts)
            .fixedSize()
            .environment(\.colorScheme, .dark)
            .foregroundStyle(.white)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: layout)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: badges)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
                .strokeBorder(ZenithSurface.hairline))
            .opacity(enabled ? 1 : 0.45)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text.preview)
    }

    // MARK: Rows

    /// A section: its glyph, its name, why it cannot be pinned when it
    /// cannot, the buttons that move a pin, and the switch that pins it.
    private func row(_ module: NotchModule, index: Int?, count: Int, full: Bool, routed: [NotchModule]) -> some View {
        let title = module.title(l10n.language)
        let availability = ZenithTabBarAvailability.of(module, routed: routed)
        let usable = availability == .available
        let pinned = index != nil
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
                .opacity(pinned ? 1 : 0)
                .help(ZenithStrings.homeShortcuts(l10n.language).dragHint)
                .accessibilityHidden(true)
            ZenithIslandGlyphTile(symbol: ZenithTabBar.symbol(module), tint: module.zenithTint, size: 26)
                .saturation(usable ? 1 : 0)
                .opacity(usable ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ZenithType.rowTitle)
                    .foregroundStyle(usable ? .primary : .secondary)
                if let reason = reason(module, availability: availability) {
                    Text(reason)
                        .font(ZenithType.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let index {
                moveButton("chevron.up", text.moveUp, enabled: index > 0) { move(module, to: index - 1, routed: routed) }
                moveButton("chevron.down", text.moveDown, enabled: index < count - 1) {
                    move(module, to: index + 1, routed: routed)
                }
            }
            Toggle(title, isOn: Binding(get: { pinned }, set: { pin(module, $0, routed: routed) }))
                .labelsHidden()
                .toggleStyle(ZenithSwitchStyle())
                .disabled(!usable || (!pinned && full))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(dragging == module ? ZenithSurface.tileFill : .clear,
                    in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if let index, index > 0 {
                Button(text.moveUp) { move(module, to: index - 1, routed: routed) }
            }
            if let index, index < count - 1 {
                Button(text.moveDown) { move(module, to: index + 1, routed: routed) }
            }
        }
    }

    /// The gallery: always shown, always last, never removed.
    private var galleryRow: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 14, height: 1)
            ZenithIslandGlyphTile(symbol: "square.grid.2x2.fill", tint: .gray, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(FeatureStrings.notch(l10n.language).sectionsTitle).font(ZenithType.rowTitle)
                Text(text.alwaysLast).font(ZenithType.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 34)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }

    private func moveButton(_ symbol: String, _ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(title)
        .accessibilityLabel(title)
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(ZenithType.rowTitle)
            Text(caption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hairline: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).accessibilityHidden(true)
    }

    // MARK: Reasons

    /// Why a section cannot be pinned: off on the Content tab, or its feature
    /// off or missing on this Mac, in the words the Content tab uses.
    private func reason(_ module: NotchModule, availability: ZenithTabBarAvailability) -> String? {
        switch availability {
        case .available: return nil
        case .hidden: return FeatureStrings.notchEditor(l10n.language).showPage(module.title(l10n.language))
        case .unavailable:
            if let feature = feature(module), !feature.isAvailable { return feature.enableReason(l10n) }
            if module == .github { return ZenithStrings.gitHub(l10n.language).missingCLI }
            return FeatureStrings.notch(l10n.language).disabled
        }
    }

    /// The one feature a section needs, as the Content tab names it.
    private func feature(_ module: NotchModule) -> AppFeature? {
        switch module {
        case .mixer: return .mixer
        case .clipboard: return .clipboardHistory
        case .files: return .shelf
        case .tools: return .quickLauncher
        case .calendar: return .notchCalendar
        case .notifications: return .notchNotifications
        case .timer: return .notchTimer
        case .camera: return .cameraPreview
        case .downloads: return .notchDownloads
        case .scratchpad: return .scratchpad
        case .agents: return .notchAgents
        case .watch: return .notchWatch
        case .controls, .music, .captures, .system, .wakatime, .vercel, .github, .cardImport, .devServers, .recap, .sky, .git, .prompter,
             .batteries, .calculator: // Zenith fork
            return nil
        }
    }

    // MARK: Edits

    /// The island's own order of its sections, for the ones not pinned.
    private var orderedModules: [NotchModule] {
        moduleOrder.split(separator: ",").compactMap { NotchModule(rawValue: String($0)) }
    }

    private func pin(_ module: NotchModule, _ on: Bool, routed: [NotchModule]) {
        save(on ? pins.pinning(module, available: routed) : pins.unpinning(module))
    }

    private func move(_ module: NotchModule, to index: Int, routed: [NotchModule]) {
        save(pins.moving(module, to: index, available: routed))
    }

    private func reorder(_ order: [NotchModule], routed: [NotchModule]) {
        save(pins.reordering(order, available: routed))
    }

    private func save(_ next: ZenithTabBarPins) {
        guard next.encoded != pinsRaw else { return }
        withAnimation(ZenithMotion.respecting(ZenithMotion.spring())) { pinsRaw = next.encoded }
    }
}
