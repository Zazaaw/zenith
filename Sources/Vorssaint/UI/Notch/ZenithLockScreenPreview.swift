// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: which layer the Settings preview draws.
enum ZenithLockScreenPreviewMode: String, CaseIterable, Identifiable {
    case minimal, full
    var id: String { rawValue }
}

/// The parts of the lock screen the preview can highlight, and that a click on
/// the preview selects, so Settings can open the matching tab.
enum ZenithLockScreenPreviewPart: String, CaseIterable, Identifiable {
    case activityRow, nowPlaying, terminal, full
    var id: String { rawValue }
}

/// Zenith fork: a live, scaled preview of the lock screen for Settings, drawn
/// over this Mac's own wallpaper with sample content and the current switches.
/// Placeholder until the lock screen views provide the real drawing.
struct ZenithLockScreenPreview: View {
    let mode: ZenithLockScreenPreviewMode
    var highlight: ZenithLockScreenPreviewPart? = nil
    var onSelect: (ZenithLockScreenPreviewPart) -> Void = { _ in }

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.3))
            .aspectRatio(1800.0 / 1169.0, contentMode: .fit)
    }
}
