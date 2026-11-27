// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: SwiftUI steps an animated `scrollTo` on a screen's display link, so in a
/// test window the reveal depends on the displays: while they sleep the link
/// never ticks and the scroll stays at its first frame. A suite whose
/// generated views reveal with `withAnimation` conforms to this. Inside it the
/// production bodies resolve `withAnimation` here, and the change lands at
/// once where the animation would end, whatever displays are attached.
protocol ImmediateAnimations {}

extension ImmediateAnimations {
    static func withAnimation<Result>(_ animation: Animation? = .default,
                                      _ body: () throws -> Result) rethrows -> Result {
        try withTransaction(Transaction(animation: nil), body)
    }
}
