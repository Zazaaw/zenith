// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the padlock island on the lock screen. At rest it shows the
// padlock beside the camera and, on the other side, the music's bars, the
// charge while the charger is connected, or the Focus that is on. As the Mac
// locks it widens to wave goodbye; as it unlocks it grows into two lines
// that welcome the person back. Pure rules and sizes; the view and the
// service live beside the lock screen's own.

/// What the island is showing.
enum ZenithLockIslandMoment: Equatable {
    case rest
    /// "See you, Faiz 👋", one line beside the padlock.
    case farewell
    /// Two lines under the camera: the greeting and how long it was locked.
    case welcome
}

/// What the right side of the resting island shows.
enum ZenithLockIslandSlot: Equatable {
    case none
    case music
    case charging(percent: Int?)
    case focus(name: String)
}

enum ZenithLockIsland {
    /// The status palette: charging green, Focus violet.
    static let chargingHex: UInt32 = 0x34D399
    static let focusHex: UInt32 = 0xA78BFA
    /// The padlock's glyph, about 17 points.
    static let padlockSize: CGFloat = 17
    /// How long a just-plugged charger wins over a Focus.
    static let chargeLead: TimeInterval = 5
    /// How long each greeting holds before the island draws back.
    static let farewellHold: TimeInterval = 2.2
    static let welcomeHold: TimeInterval = 3
    /// Once drawn back, how long the island waits before it fades: its shrink settling.
    static let settleAfterGreeting: TimeInterval = 0.6

    /// The right slot: a charger just plugged in first, for its first five
    /// seconds; then a song playing; then a Focus; then the charge while the
    /// charger stays connected.
    static func slot(playing: Bool, charging: Bool, percent: Int?, recentlyPlugged: Bool, focus: String?) -> ZenithLockIslandSlot {
        if charging && recentlyPlugged { return .charging(percent: percent) }
        if playing { return .music }
        if let focus, !focus.isEmpty { return .focus(name: focus) }
        if charging { return .charging(percent: percent) }
        return .none
    }

    /// The account's first name: the first word of the full name, or the
    /// short user name when there is no full name.
    static func firstName(fullName: String, userName: String) -> String {
        let words = fullName.split(whereSeparator: { $0.isWhitespace })
        if let first = words.first { return String(first) }
        return userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How long the Mac was locked, short: "2h 14m", "14m", "40s".
    static func duration(_ seconds: TimeInterval, locale: Locale) -> String {
        let total = max(0, seconds.isFinite ? seconds : 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = total < 60 ? [.second] : total < 86_400 ? [.hour, .minute] : [.day, .hour]
        let rounded = total < 60 ? max(1, total.rounded()) : total
        return formatter.string(from: rounded) ?? ""
    }

    // MARK: Sizes

    /// Room on each side of a slot's content inside its wing.
    static let wingInset: CGFloat = 12
    /// The widest a wing grows for a name or a greeting, which then truncates.
    static let maximumWing: CGFloat = 210
    /// The welcome's two lines below the camera: their block's height, the
    /// photo's side and the island's least width.
    static let welcomeBlock: CGFloat = 54
    static let welcomePhoto: CGFloat = 32
    static let welcomeMinimumWidth: CGFloat = 320
    static let welcomeMaximumWidth: CGFloat = 460
    /// Padding inside the welcome's block, and the gaps between its parts.
    static let welcomePadding: CGFloat = 38
    static let welcomeGap: CGFloat = 12

    /// A wing wide enough for `content` points, never narrower than the camera's fit.
    static func wing(for content: CGFloat, resting: CGFloat) -> CGFloat {
        max(resting, min(maximumWing, content + wingInset * 2))
    }

    /// The island at rest or saying goodbye: the camera between two equal wings.
    static func size(camera: CGSize, wing: CGFloat) -> CGSize {
        CGSize(width: camera.width + wing * 2, height: camera.height)
    }

    /// The welcome: as wide as its two lines need, within its bounds, and as
    /// tall as the camera and its block below it.
    static func welcomeSize(camera: CGSize, resting: CGSize, textWidth: CGFloat) -> CGSize {
        let content = welcomePadding * 2 + padlockSize + 6 + welcomeGap * 2 + textWidth + welcomePhoto
        let width = min(welcomeMaximumWidth, max(welcomeMinimumWidth, resting.width, content))
        return CGSize(width: width, height: camera.height + welcomeBlock)
    }

    /// The island's window: room for the welcome and its swing around the
    /// resting island, still within the screen. The window takes no clicks.
    static func windowFrame(around surface: CGRect, in screen: CGRect) -> CGRect {
        let swing = ZenithIslandMotion.widthSwingLimit + ZenithIslandMotion.narrowingLimit
        let width = min(screen.width, max(surface.width + maximumWing * 2, welcomeMaximumWidth) + swing * 2)
        let height = surface.height + welcomeBlock + ZenithIslandMotion.heightSwingLimit + ZenithIslandMotion.flatteningLimit
        let frame = CGRect(x: surface.midX - width / 2, y: surface.maxY - height, width: width, height: height)
        return frame.intersection(screen).integral
    }
}
