// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the padlock island on the lock screen. At rest it shows the
// padlock beside the camera and, on the other side, the music's bars, the
// charge while the charger is connected, or the Focus that is on. As the Mac
// locks it widens to wave goodbye. The welcome back is the desktop island's
// own burst (ZenithIslandBurst.welcome), so it never stacks over an open
// page. Pure rules and sizes; the view and the service live beside the lock
// screen's own.

/// What the island is showing.
enum ZenithLockIslandMoment: Equatable {
    case rest
    /// "See you, Faiz 👋", one line beside the padlock.
    case farewell
    /// Zenith fork (remote lock): "Locked from Faiz’s iPhone" over "just now",
    /// with the iPhone, in place of the farewell when an iPhone locked the Mac.
    case remoteLock(device: String)
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
    /// How long the farewell holds before the island draws back.
    static let farewellHold: TimeInterval = 2.2
    /// After unlocking, when the desktop island greets: as soon as it is back,
    /// under the padlock island, which fades once the greeting has begun.
    static let welcomeDelay: TimeInterval = 0.1
    /// How long the padlock island stays over the returned desktop island.
    static let unlockOverlap: TimeInterval = 0.35
    /// The longest the padlock island waits for the desktop island to return.
    static let unlockPatience: TimeInterval = 1.5
    /// How long the closed desktop island stays drawn under the lock
    /// screen's padlock island as the Mac locks.
    static let handoffOverlap: TimeInterval = 0.6
    /// How long "Locked from Faiz’s iPhone" holds before the island draws back.
    static let remoteHold: TimeInterval = 3

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

    /// A wing wide enough for `content` points, never narrower than the camera's fit.
    static func wing(for content: CGFloat, resting: CGFloat) -> CGFloat {
        max(resting, min(maximumWing, content + wingInset * 2))
    }

    /// The island at rest or saying goodbye: the camera between two equal wings.
    static func size(camera: CGSize, wing: CGFloat) -> CGSize {
        CGSize(width: camera.width + wing * 2, height: camera.height)
    }

    /// The island's window: room for the farewell, the island grown below
    /// the camera (`grown`) and their swing around the resting island, still
    /// within the screen. The window takes no clicks.
    static func windowFrame(around surface: CGRect, in screen: CGRect) -> CGRect {
        let swing = ZenithIslandMotion.widthSwingLimit + ZenithIslandMotion.narrowingLimit
        let widest = max(surface.width + maximumWing * 2, ZenithIslandRoom.maximumWidth)
        let width = min(screen.width, widest + swing * 2)
        let height = grownHeight(camera: surface.height, lines: 2) + ZenithIslandMotion.heightSwingLimit
            + ZenithIslandMotion.flatteningLimit
        let frame = CGRect(x: surface.midX - width / 2, y: surface.maxY - height, width: width, height: height)
        return frame.intersection(screen).integral
    }

    // MARK: Grown below the camera

    /// Zenith fork: "Locked from Faiz’s iPhone" says more than a wing holds,
    /// so the island grows down into two lines below the camera, the way
    /// the desktop island's welcome does: the padlock on its tile, the words,
    /// and the iPhone at the end, with the island's padding around them. The
    /// same pieces and gaps as the welcome (ZenithIslandBurstLayout).
    static func remoteRow(device: String) -> ZenithIslandBurstLayout.Row {
        typealias Layout = ZenithIslandBurstLayout
        return .init(leading: Layout.markSide + Layout.tileGap, trailing: Layout.columnGap + Layout.remoteGlyph,
                     title: Layout.words(RemoteText.lockedFrom(device), Layout.chargeTitleFont),
                     subtitle: Layout.words(RemoteText.justNow, Layout.chargeSubtitleFont), wrapsTitle: true)
    }

    /// The grown island's height for a strip `camera` points tall: the row
    /// right under it, a long device's name on a second line, and the
    /// island's padding below.
    static func grownHeight(camera: CGFloat, lines: Int) -> CGFloat {
        let row = ZenithIslandBurstLayout.welcomeRow
            + CGFloat(max(1, min(2, lines)) - 1) * ZenithIslandBurstLayout.titleLineHeight
        return ZenithIslandInset.height(content: row, strip: camera)
    }

    /// The island grown for a remote lock, at least as wide as the island
    /// it grows out of (`resting`), so none of that one shows past it.
    static func remoteFit(device: String, camera: CGFloat, resting: CGFloat,
                          screenWidth: CGFloat) -> ZenithIslandBurstLayout.Fit {
        ZenithIslandBurstLayout.fit(remoteRow(device: device),
                                    height: { grownHeight(camera: camera, lines: $0) - camera - ZenithIslandInset.belowCamera
                                        - ZenithIslandInset.padding },
                                    top: camera + ZenithIslandInset.belowCamera, bottom: ZenithIslandInset.padding,
                                    minimum: 360, covering: resting, floats: false, screenWidth: screenWidth)
    }
}
