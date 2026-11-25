// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The safety of the person's work in full, opened from Home's Safety card. A stand-in.
struct SafetySheet: View {
    let safety: PocketSafety?
    var body: some View { Text("Safety").font(K.sans(20, bold: true)).padding() }
}
