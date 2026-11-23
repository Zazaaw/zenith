// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import SwiftUI

/// Zenith fork: the Batteries widget for Customize Home. The weakest
/// reachable device: its symbol on a tile (red while it is low), its level
/// large in mono, its name below; a click opens the page. While it shows,
/// the store reads as often as for the page.
struct BatteriesHomeWidget: View {
    let service: NotchService
    @ObservedObject private var store = BatteriesStore.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(BatteriesDefaults.threshold) private var thresholdRaw = BatteriesDefaults.defaultThreshold
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: ZenithBatteriesIslandStrings { ZenithStrings.batteriesIsland(l10n.language) }

    var body: some View {
        let devices = BatteriesIslandSupport.shown(store.devices, hidden: BatteriesIslandSupport.hiddenDeviceIDs())
        let weakest = BatteriesIslandSupport.weakest(devices)
        ZenithHomeOpenButton(action: { service.select(.batteries) }) {
            VStack(alignment: .leading, spacing: 6) {
                ZenithHomeWidgetHeader(widget: .batteries, title: text.title)
                if let weakest {
                    reading(weakest)
                        .id(weakest.id)
                        .transition(BatteriesMotion.item(reduceMotion: reduceMotion))
                } else {
                    Text(devices.isEmpty ? text.empty : text.noLevel)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(BatteriesMotion.change(reduceMotion: reduceMotion), value: weakest?.id)
        }
        .onAppear { if !preview { BatteriesIslandService.shared.shown(page: false) } }
        .onDisappear { if !preview { BatteriesIslandService.shared.hidden() } }
    }

    private func reading(_ device: BatteryDevice) -> some View {
        let threshold = BatteriesDefaults.thresholdOptions.contains(thresholdRaw) ? thresholdRaw
            : BatteriesDefaults.defaultThreshold
        let low = device.isLow(threshold: threshold)
        let tint = low ? BatteriesPalette.red : NotchModule.batteries.zenithTint
        return HStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: device.symbolName, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: BatteriesIslandSupport.percentText(device.percent, text: text))
                    .font(ZenithType.mono(20, weight: .bold))
                    .tracking(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(low ? BatteriesPalette.red : ZenithIsland.primary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                Text(verbatim: device.name)
                    .font(ZenithType.mono(10, weight: .medium))
                    .foregroundStyle(ZenithIsland.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: device.name))
        .accessibilityValue(Text(verbatim: BatteriesIslandSupport.accessibilityValue(device, now: Date(), text: text)))
    }
}
