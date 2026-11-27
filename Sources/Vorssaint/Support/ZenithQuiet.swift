// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

/// Zenith fork: test runs, the selftest and the offscreen island catalog run
/// the app's real code on the owner's Mac. While they do, nothing may make a
/// sound or listen to the keyboard: no alert beeps from a failure a test
/// provokes on purpose, no chimes, and no Mechakey tap catching real typing.
enum ZenithQuiet {
    /// Set once at the start of a test run, the selftest or the catalog.
    nonisolated(unsafe) static var isOn = false

    /// The alert sound for a failed action, unless the app runs quiet.
    static func beep() {
        guard !isOn else { return }
        NSSound.beep()
    }
}
