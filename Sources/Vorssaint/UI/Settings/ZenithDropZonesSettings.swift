// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

extension NotchDropTarget: PanelOrderItem {}

/// Zenith fork: the Drop zones section in Settings › Shelf, in the Settings
/// kit's section and rows. It holds every place
/// a drag on the island can land (ZenithDropZones): a live preview of the
/// zones as an image drag gets them, then one row per zone with its glyph,
/// its name, when it shows, and its switch, dragged or moved with the arrows
/// into the order the island lays them out. Files or AirDrop always stays on,
/// so every drag has somewhere to land. It replaces the AirDrop, photo
/// actions and Overlay switches, whose keys it keeps in step.
struct ZenithDropZonesSettingsSection: View {
    /// Whether the island shows its Files page, which the shelf's zones and
    /// the image zones need; the Shelf page tracks it.
    let islandShowsFiles: Bool
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.zenithDropZones) private var raw = ZenithDropZones.automatic
    // Read while the card was never changed, when the zones follow them.
    @AppStorage(DefaultsKey.notchAirDropEnabled) private var airDrop = true
    @AppStorage(DefaultsKey.notchPhotoActionsEnabled) private var photoActions = true
    @AppStorage(DefaultsKey.designOverlayDropEnabled) private var overlay = true
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfOn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragging: NotchDropTarget?

    private var text: ZenithDropZonesStrings { ZenithStrings.dropZones(l10n.language) }
    private var zones: ZenithDropZones {
        ZenithDropZones(encoded: raw, airDrop: airDrop, photoActions: photoActions, overlay: overlay)
    }

    var body: some View {
        let zones = zones
        let order = zones.order
        ZenithSection(text.title, anchor: .zenithDropZones, footer: text.rule) { // Settings search lands here
            VStack(alignment: .leading, spacing: 10) {
                preview(zones)
                Text(text.caption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            ForEach(order, id: \.self) { target in
                PanelReorderableItem(item: target,
                                     order: Binding(get: { order }, set: { save(zones.reordering($0)) }),
                                     dragging: $dragging) {
                    row(target, zones: zones, index: order.firstIndex(of: target) ?? 0, count: order.count)
                }
            }
        }
    }

    // MARK: Preview

    /// The zones an image dropped now would get, drawn with the island's own
    /// tiles on a piece of island, the first one as the drop's target.
    @ViewBuilder
    private func preview(_ zones: ZenithDropZones) -> some View {
        let targets = zones.targets(for: .oneImage, shelf: shelfAvailable,
                                    mediaTools: AppFeature.mediaTools.isAvailable,
                                    filesPage: islandShowsFiles, overlayAvailable: AppFeature.screenshot.isAvailable)
        if !targets.isEmpty {
            let page = previewPage(count: targets.count)
            let inset = ZenithIsland.pageInset
            let natural = CGSize(width: page.width + inset * 2, height: page.height + inset * 2)
            VStack(spacing: 6) {
                GeometryReader { proxy in
                    let scale = min(1, proxy.size.width / natural.width)
                    island(targets, page: page)
                        .frame(width: natural.width, height: natural.height)
                        .scaleEffect(scale, anchor: .topLeading)
                }
                .aspectRatio(natural.width / natural.height, contentMode: .fit)
                .frame(maxWidth: natural.width)
                .frame(maxWidth: .infinity)
                Text(text.preview)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text.preview)
            .accessibilityValue(targets.map { $0.zenithTitle(l10n.language) }.joined(separator: ", "))
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: targets)
        }
    }

    /// The page the island gives the zones: as wide as the widened island
    /// makes it, one tile high.
    private func previewPage(count: Int) -> CGSize {
        let width = ZenithDropZoneLayout.contentWidth(count: max(count, ZenithDropZoneLayout.widensFrom),
                                                      maximum: .greatestFiniteMagnitude) ?? 0
        return CGSize(width: width, height: (ZenithDropZoneLayout.preferredTileWidth * ZenithDropZoneLayout.tileAspect).rounded())
    }

    private func island(_ targets: [NotchDropTarget], page: CGSize) -> some View {
        let frames = ZenithDropZoneLayout.frames(count: targets.count, in: page)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(targets.enumerated()), id: \.element) { index, target in
                if index < frames.count {
                    ZenithDropZoneTile(target: target, language: l10n.language, selected: index == 0,
                                       dimmed: index != 0, index: index, animatesEntrance: false)
                        .frame(width: frames[index].width, height: frames[index].height)
                        .position(x: frames[index].midX, y: frames[index].midY)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: page.width, height: page.height, alignment: .topLeading)
        .padding(ZenithIsland.pageInset)
        .background(Color.black, in: RoundedRectangle(cornerRadius: ZenithIsland.islandRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    // MARK: Rows

    /// A zone: its glyph, its name, when it shows (or why it cannot), the
    /// arrows that move it, and its switch.
    private func row(_ target: NotchDropTarget, zones: ZenithDropZones, index: Int, count: Int) -> some View {
        let title = target.zenithTitle(l10n.language)
        let reason = unavailableReason(target)
        let on = zones.isOn(target)
        let locked = on && !zones.canTurnOff(target)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
                .help(ZenithStrings.homeShortcuts(l10n.language).dragHint)
                .accessibilityHidden(true)
            ZenithIslandGlyphTile(symbol: target.zenithSymbol, tint: ZenithIslandPalette.color(hex: target.zenithTintHex),
                                  size: 26)
                .saturation(on && reason == nil ? 1 : 0)
                .opacity(on && reason == nil ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ZenithType.rowTitle)
                    .foregroundStyle(on ? .primary : .secondary)
                Text(reason ?? target.zenithWhen(l10n.language))
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            moveButton("chevron.up", tabText.moveUp, enabled: index > 0) { save(zones.moving(target, to: index - 1)) }
            moveButton("chevron.down", tabText.moveDown, enabled: index < count - 1) {
                save(zones.moving(target, to: index + 1))
            }
            Toggle(title, isOn: Binding(get: { on }, set: { save(zones.setting(target, on: $0)) }))
                .labelsHidden()
                .toggleStyle(ZenithSwitchStyle())
                .disabled(locked)
                .help(locked ? text.rule : title)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(dragging == target ? ZenithSurface.tileFill : .clear,
                    in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
        .padding(.horizontal, -6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if index > 0 { Button(tabText.moveUp) { save(zones.moving(target, to: index - 1)) } }
            if index < count - 1 { Button(tabText.moveDown) { save(zones.moving(target, to: index + 1)) } }
        }
    }

    private var tabText: ZenithTabBarStrings { ZenithStrings.tabBar(l10n.language) }

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

    // MARK: Availability

    /// The shelf takes drops: its feature, its own switch.
    private var shelfAvailable: Bool { AppFeature.shelf.isAvailable && shelfOn && islandShowsFiles }

    /// Why a zone cannot show on this Mac right now, in the words the rest
    /// of Settings uses; nil when it can.
    private func unavailableReason(_ target: NotchDropTarget) -> String? {
        let filesPage = FeatureStrings.notchEditor(l10n.language).showPage(FeatureStrings.notch(l10n.language).files)
        switch target {
        case .airDrop:
            return nil
        case .files, .media:
            if !AppFeature.shelf.isAvailable { return AppFeature.shelf.enableReason(l10n) }
            if target == .media, !AppFeature.mediaTools.isAvailable { return AppFeature.mediaTools.enableReason(l10n) }
            if !shelfOn { return text.shelfOff }
            return islandShowsFiles ? nil : filesPage
        case .transform, .removeBackground:
            return islandShowsFiles ? nil : filesPage
        case .overlay:
            if !AppFeature.screenshot.isAvailable { return AppFeature.screenshot.enableReason(l10n) }
            return islandShowsFiles ? nil : filesPage
        }
    }

    // MARK: Edits

    private func save(_ next: ZenithDropZones) {
        guard next != zones else { return }
        withAnimation(ZenithMotion.respecting(ZenithMotion.spring())) {
            ZenithDropZones.save(next)
        }
        NotchPhotoActionsService.shared.syncWithPreferences()
    }
}
