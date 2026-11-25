// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// The Mac tab. A stand-in over the first round's Control screen until the
/// Mac's health, sound and tools replace it.
struct MacView: View {
    let now: Date
    var body: some View { ControlView(now: now) }
}
