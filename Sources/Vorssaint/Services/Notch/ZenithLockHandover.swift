// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// The window level and behaviour follow Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance (NotchWindow.swift).

import AppKit

// Zenith fork: the lock screen's windows and how the padlock island leaves
// as the Mac unlocks, the way Glance's island does: it stays solid and still
// above macOS's shield while the shield fades the lock screen out, plays the
// welcome inside itself, and only once the desktop has settled hands over to
// the desktop island at the very same shape, then goes at once, with no fade.
// Pure rules and numbers; compiled into the tests.

/// Zenith fork: where the lock screen's windows are drawn.
enum ZenithLockScreenWindow {
    /// The padlock island and its face unlock panel: one above the shielding
    /// level, the highest public tier, so macOS's own shield fading in or out
    /// never draws over it.
    static var islandLevel: NSWindow.Level { NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1) }
    /// The island's windows are on every Space, never move with one, sit over
    /// full screen apps and are left out of window cycling.
    static let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
    ]
    /// SkyLight's flag for the lock screen Space: any other value has Finder
    /// draw the desktop icons into it.
    static let spaceFlag: Int32 = 1
    /// The Spaces a window delegated to the lock screen Space leaves (Glance's 7).
    static let removedSpaces: Int32 = 7
}

/// Zenith fork: the timing of the padlock island's lock and unlock.
enum ZenithLockHandover {
    /// Locking: how long the island stays the bare notch while macOS fades
    /// its shield in, before the farewell (or "Locked from …") grows out of it.
    static let shieldFadeIn: TimeInterval = 0.6
    /// Unlocking without a reading of the desktop's zoom: the desktop is
    /// taken as settled this long after the unlock.
    static let desktopFallback: TimeInterval = 1.0
    /// The longest the padlock island waits, for the desktop and its own
    /// motion, before it hands over whatever it shows.
    static let longest: TimeInterval = 2.5
    /// How long the desktop island may take to come back on screen once it
    /// is asked to take over; past it, the padlock island keeps the welcome.
    static let patience: TimeInterval = 1.5
    /// After the island draws back into the bare notch, before its window goes.
    static let collapse: TimeInterval = 0.55
    /// How long the desktop island takes to close into the bare notch as
    /// the Mac locks, before its window goes.
    static let retire: TimeInterval = 0.5
    /// Unlocked with no padlock island (no camera), when the desktop
    /// island's own welcome burst comes.
    static let burstDelay: TimeInterval = 0.1

    /// Whether the padlock island hands over now, `elapsed` seconds after the
    /// unlock: once the desktop has stopped zooming (or the fallback has
    /// passed) and the island itself has stopped moving; at `longest`
    /// whatever happens.
    static func ready(elapsed: TimeInterval, desktopSettled: Bool, islandSettled: Bool) -> Bool {
        guard elapsed.isFinite else { return true }
        if elapsed >= longest { return true }
        return (desktopSettled || elapsed >= desktopFallback) && islandSettled
    }

    /// What the padlock island does once it is ready.
    enum Plan: Equatable {
        /// The desktop island comes back at this shape, the welcome's, and
        /// takes over from it with nothing on screen moving.
        case handOver(CGSize)
        /// Nothing to hand over (no welcome): the island draws back into the
        /// bare notch and goes, and the desktop island simply comes back.
        case collapse
    }

    static func plan(welcome: Bool, shown: CGSize?) -> Plan {
        guard welcome, let shown, ZenithLockIsland.handsOver(pill: shown) else { return .collapse }
        return .handOver(shown)
    }

    /// The desktop island declined: how much longer the padlock island keeps
    /// the welcome, which has shown `shownFor` seconds of its `duration`.
    static func welcomeRemaining(shownFor: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard shownFor.isFinite, duration.isFinite else { return 0 }
        return max(0, duration - max(0, shownFor))
    }

    /// The welcome's burst for the desktop island, started `shownFor`
    /// seconds ago in the padlock island, so it ends when it would have.
    static func handedOverStart(now: Date, shownFor: TimeInterval) -> Date {
        now.addingTimeInterval(-max(0, shownFor.isFinite ? shownFor : 0))
    }
}
