// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the clock kit art moves by (docs/SETTINGS-KIT.md).

/// The clock for kit art (the hero, a stage's own art): seconds while it may
/// move, `ZenithKitMotionRule.stillTime` otherwise. One `TimelineView`, paused
/// (no frames, no timers) while the page is gone, the window is hidden or
/// covered, Reduce Motion is on or the battery saver is saving.
///
///     ZenithKitClock { t, moving in
///         MyArt(t: t)
///     }
struct ZenithKitClock<Content: View>: View {
    @ViewBuilder var content: (_ t: Double, _ moving: Bool) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var appearance = ZenithAppearance.shared
    @State private var windowVisible = true
    @State private var shown = false

    /// Every kit loop divides this, so wrapping the clock never jumps.
    private static var wrap: Double { 80 }

    var body: some View {
        let moving = ZenithKitMotionRule.animates(pageShown: shown, windowVisible: windowVisible,
                                                  reduceMotion: reduceMotion,
                                                  savingBattery: appearance.isSavingBattery)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !moving)) { context in
            let t = moving ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.wrap)
                : ZenithKitMotionRule.stillTime
            content(t, moving)
        }
        .background(ZenithWindowVisibilityReader(visible: $windowVisible))
        .onAppear { shown = true }
        .onDisappear { shown = false }
    }
}
