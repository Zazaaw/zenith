// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: every Orbit icon in one place, looked up by the feature's
// English name. Drawn in code (OrbitIconKit), so they stay sharp at any size.

enum OrbitIcons {
    static let all: [OrbitIcon] = OrbitSeedIcons.icons + OrbitIconsA.icons + OrbitIconsB.icons + OrbitIconsC.icons
        + OrbitIconsD.icons + OrbitIconsE.icons
        + OrbitIconsAppLock.icons // Zenith fork: App Lock

    private static let byName: [String: OrbitIcon] = Dictionary(all.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

    static func named(_ name: String) -> OrbitIcon? { byName[name] }
}
