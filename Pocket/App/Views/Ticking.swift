// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// The time, redrawn every `every` seconds (one by default) on the whole
/// second, for the small part of a page that counts: a countdown, a turn's
/// elapsed time. The pages themselves tick by the minute (RootView), so
/// wrap only the label that needs seconds, not the card around it:
///
///     SecondsTimeline { now in
///         Text(PocketPresentation.countdown(to: deadline, now: now))
///     }
///
/// Like any `TimelineView`, it stops while off screen or in the background.
struct SecondsTimeline<Content: View>: View {
    var every: TimeInterval = 1
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(.periodic(from: Self.wholeSecond(), by: every)) { context in
            content(context.date)
        }
    }

    /// Now, rounded down to the second, so each tick lands as the clock's
    /// seconds change rather than part-way through one.
    private static func wholeSecond() -> Date {
        Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down))
    }
}
