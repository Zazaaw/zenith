// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the capture controls collapsed while an area is chosen, as a
// row below the camera instead of two glyphs squeezed into its wings: the
// tool's glyph and name, a dim hint for what to do, and a round chevron that
// opens the controls, all clear of the shoulders by the island's room rule.

struct ZenithCaptureStrip: View {
    let tool: ScreenCaptureTool
    let geometry: NotchGeometry
    let size: CGSize
    let expand: () -> Void
    @ObservedObject private var l10n = L10n.shared

    private typealias Layout = ZenithCaptureStripLayout

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: tool.systemImageName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: Layout.icon, height: Layout.icon)
            Text(Layout.title(tool, language: l10n.language))
                .font(Font(Layout.titleFont))
                .foregroundStyle(ZenithIsland.primary)
                .padding(.leading, Layout.iconGap)
                .fixedSize()
            Text(Layout.hint(tool, language: l10n.language))
                .font(Font(Layout.hintFont))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, Layout.hintGap)
            Spacer(minLength: Layout.buttonGap)
            Button(action: expand) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: Layout.button, height: Layout.button)
                    .background(Circle().fill(.white.opacity(0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(FeatureStrings.notch(l10n.language).open)
        }
        .frame(height: Layout.rowHeight)
        .padding(.horizontal, ZenithIslandRoom.edge + NotchLayout.shoulder(height: size.height))
        .padding(.top, geometry.stripHeight - Layout.rowOverlap)
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}
