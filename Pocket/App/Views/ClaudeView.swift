// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// The Claude tab. A stand-in over the first round's Agents screen until the
/// Claude tracking and reply screens replace it.
struct ClaudeView: View {
    let now: Date
    var body: some View { AgentsView(now: now) }
}
