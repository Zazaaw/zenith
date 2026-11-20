// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the island's drop chooser. While a drag hovers the Files page,
/// the zones it offers (in the order chosen in Settings › Shelf › Drop zones)
/// sit side by side as rounded tiles, in the layout `ZenithDropZoneLayout`
/// gives the drop's own hit test, so the tile that lights up is the one the
/// file lands on. A drag offering three zones or more has already widened the
/// island (`NotchGeometry.zenithDropZoneCount`), so each tile has room for its
/// glyph over a one-line name.
struct ZenithDropZonesView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var archives = NotchFileToolsService.shared
    @ObservedObject private var photos = NotchPhotoActionsService.shared

    var body: some View {
        let targets = service.zenithDropTargets
        let selected = selectedTarget
        GeometryReader { proxy in
            let frames = ZenithDropZoneLayout.frames(count: targets.count, in: proxy.size)
            ZStack(alignment: .topLeading) {
                ForEach(Array(targets.enumerated()), id: \.element) { index, target in
                    if index < frames.count {
                        tile(target, index: index, selected: selected)
                            .frame(width: frames[index].width, height: frames[index].height)
                            .position(x: frames[index].midX, y: frames[index].midY)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    /// The zone the drop would land on now: the drag's own flags, as the
    /// service reads them on accept.
    private var selectedTarget: NotchDropTarget? {
        if let photo = service.photoDropTarget { return photo }
        if service.targetsAirDrop { return .airDrop }
        if service.targetsMediaDrop { return .media }
        return service.offersFilesDrop ? .files : nil
    }

    private func tile(_ target: NotchDropTarget, index: Int, selected: NotchDropTarget?) -> some View {
        let photoText = ZenithStrings.photoActions(l10n.language)
        let available: Bool
        let note: String?
        switch target {
        case .files, .overlay: (available, note) = (true, nil)
        case .airDrop: (available, note) = (service.airDropAvailable, nil)
        case .media: (available, note) = (archives.canAcceptMediaDrop, l10n.s.mediaRunning)
        case .transform, .removeBackground: (available, note) = (photos.canAcceptDrop, photoText.busy)
        }
        return ZenithDropZoneTile(target: target, language: l10n.language,
                                  selected: selected == target, dimmed: selected != nil && selected != target,
                                  available: available, note: note, index: index)
    }
}

/// One drop zone: its glyph centred over a single-line name, in a rounded
/// tile concentric with the island. At rest it is a dashed hairline with a
/// grey glyph; the zone a drop would land on fills with its colour (10% fill,
/// 20% outline, the glyph at full strength), lifts and grows its glyph on a
/// spring, and the other zones step back a little. When a drag arrives the
/// tiles come in one after another, 40 ms apart, out of a blur. Reduce Motion
/// keeps the fades and drops the movement and the blur.
struct ZenithDropZoneTile: View {
    let target: NotchDropTarget
    let language: AppLanguage
    let selected: Bool
    var dimmed = false
    var available = true
    var note: String?
    var index = 0
    /// Off for still previews, which show the tiles as they settle.
    var animatesEntrance = true
    @State private var entered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let title = target.zenithTitle(language)
        let tint = ZenithIslandPalette.color(hex: target.zenithTintHex)
        let shape = RoundedRectangle(cornerRadius: ZenithIsland.cardRadius, style: .continuous)
        let shown = entered || !animatesEntrance
        VStack(spacing: 9) {
            ZStack {
                glyph.foregroundStyle(ZenithIsland.secondary).opacity(selected ? 0 : 1)
                glyph.foregroundStyle(tint).opacity(selected ? 1 : 0)
            }
            .scaleEffect(selected && !reduceMotion ? 1.12 : 1)
            .offset(y: reduceMotion ? 0 : selected ? -4 : shown ? 0 : 5)
            label(title)
                .foregroundStyle(Color.white)
                .opacity(selected ? 0.95 : 0.6)
            if !available, let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundStyle(ZenithIsland.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { shape.fill(tint.opacity(selected ? 0.10 : 0)) }
        .overlay {
            ZStack {
                shape.strokeBorder(contrast == .increased ? ZenithIsland.contrastDivider : Color.white.opacity(0.2),
                                   style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .opacity(selected ? 0 : 1)
                shape.strokeBorder(tint.opacity(contrast == .increased ? 0.5 : 0.2), lineWidth: 1)
                    .opacity(selected ? 1 : 0)
            }
            .allowsHitTesting(false)
        }
        .opacity(shown ? (available ? (dimmed ? 0.72 : 1) : 0.45) : 0)
        .blur(radius: reduceMotion || shown ? 0 : 6)
        .scaleEffect(reduceMotion ? 1 : shown ? 1 : 0.96)
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : .spring(response: 0.34, dampingFraction: 0.8),
                   value: selected)
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : .spring(response: 0.34, dampingFraction: 0.86),
                   value: dimmed)
        .onAppear {
            guard animatesEntrance, !entered else { return }
            withAnimation((reduceMotion ? Animation.easeOut(duration: 0.2)
                           : .spring(response: ZenithMorph.response, dampingFraction: ZenithMorph.damping))
                .delay(ZenithMotion.layerDelay(index))) {
                entered = true
            }
        }
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(!available ? (note ?? "") : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var glyph: some View {
        Image(systemName: target.zenithSymbol)
            .font(.system(size: 22, weight: .regular))
            .frame(height: 26)
    }

    /// The full name on one line, or the short one where it would not fit.
    private func label(_ title: String) -> some View {
        ViewThatFits(in: .horizontal) {
            Text(title).lineLimit(1)
            Text(target.zenithShortTitle(language)).lineLimit(1)
            Text(target.zenithShortTitle(language)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.system(size: 12.5, weight: .medium))
    }
}
