// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The watched sites in full, opened from Home's Sites card. A stand-in.
struct SitesSheet: View {
    let sites: PocketSites?
    var body: some View { Text("Sites").font(K.sans(20, bold: true)).padding() }
}
