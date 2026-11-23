// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the padlock island on the lock screen. At rest it shows the
// padlock beside the camera and, on the other side, the music's bars, the
// charge while the charger is connected, or the Focus that is on. As the Mac
// locks it widens to wave goodbye. The welcome back is the desktop island's
// own burst (ZenithIslandBurst.welcome): it grows first in the padlock island,
// above macOS's shield, and the desktop island takes it over at the same shape
// once the desktop has settled (ZenithLockHandover). Pure rules and sizes; the
// view and the service live beside the lock screen's own.

/// Zenith fork: dev builds log the lock screen's hand-offs beside the
/// island's motion (`defaults write … zenithMotionTrace -bool true`,
/// ~/Library/Logs/ZenithDeveloper/island-motion.log); the island sets
/// `sink` as it starts. Nothing is logged without one.
enum ZenithLockTrace {
    nonisolated(unsafe) static var sink: ((String) -> Void)?

    /// Any build: `defaults write id.satuvisual.zenith zenithLockTrace -bool true`
    /// appends the lock hand-off events to ~/Library/Logs/Zenith/lock.log, so a
    /// live lock and unlock can be read back. Off by default; logs nothing else.
    static let fileSink: (String) -> Void = { line in
        guard UserDefaults.standard.bool(forKey: "zenithLockTrace") else { return }
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Zenith", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("lock.log")
        let stamp = String(format: "%.4f ", locale: Locale(identifier: "en_US_POSIX"), ProcessInfo.processInfo.systemUptime)
        guard let data = (stamp + line + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    static func log(_ line: @autoclosure () -> String) {
        guard let sink else { return }
        sink("lock " + line())
    }
}

/// Zenith fork: macOS's own zoom of the desktop as the Mac unlocks: every
/// desktop window (the island's too) is drawn scaled about the display's
/// centre, from about 0.9 back to 1, while the shield fades the lock screen
/// out. Seen on a live unlock: the window server reported the island's
/// windows at 0.91, 0.95, 0.96, 0.98 and then 1 over about 0.15 s, so a
/// desktop window stood in for the padlock pill showed smaller and lower,
/// as a second island. The island waits the zoom out off screen.
enum ZenithDesktopZoom {
    /// Without a zoom seen by then, there is none (Reduce Motion, or it was
    /// over before the unlock was announced).
    static let noZoomWait: TimeInterval = 0.1
    /// The longest the island waits, whatever the window server says.
    static let longest: TimeInterval = 0.8
    static let tolerance: CGFloat = 0.003

    static func zooming(_ scale: CGFloat?) -> Bool {
        guard let scale, scale.isFinite else { return false }
        return abs(scale - 1) > tolerance
    }

    /// Whether the zoom is over at `elapsed` seconds after the unlock, with
    /// the desktop at `scale` (nil when unknown) and a zoom seen or not.
    static func settled(elapsed: TimeInterval, scale: CGFloat?, sawZoom: Bool) -> Bool {
        if elapsed >= longest { return true }
        if zooming(scale) { return false }
        return sawZoom || elapsed >= noZoomWait
    }

    /// Numbers for the log, the same in every region.
    static func text(_ format: String, _ arguments: CVarArg...) -> String {
        String(format: format, locale: Locale(identifier: "en_US_POSIX"), arguments: arguments)
    }
}

/// What the island is showing.
enum ZenithLockIslandMoment: Equatable {
    case rest
    /// "See you, Faiz 👋", one line beside the padlock.
    case farewell
    /// Zenith fork (remote lock): "Locked from Faiz’s iPhone" over "just now",
    /// with the iPhone, in place of the farewell when an iPhone locked the Mac.
    case remoteLock(device: String)
    /// Zenith fork: unlocked, the welcome back grown in the padlock island
    /// itself, the desktop island's own burst at the same shape
    /// (ZenithIslandBurstView), until the desktop island takes it over.
    case welcome(ZenithWelcomeBurst)
    /// Zenith fork: drawn back into the bare notch: as the Mac locks, while
    /// macOS fades its shield in, and as the island leaves with nothing to hand over.
    case bare
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
    /// How long "Locked from Faiz’s iPhone" holds before the island draws back.
    static let remoteHold: TimeInterval = 3

    /// Zenith fork: what the padlock island shows from its very first frame.
    /// As the Mac locks, the farewell (or, locked from an iPhone, "Locked
    /// from …"), never the resting padlock first and the greeting after:
    /// the island grows out of the desktop island straight into it. Back
    /// from a dark display, at rest.
    static func openingMoment(locking: Bool, farewell: Bool, remoteDevice: String?) -> ZenithLockIslandMoment {
        guard locking else { return .rest }
        if let remoteDevice { return .remoteLock(device: remoteDevice) }
        return farewell ? .farewell : .rest
    }

    /// How long the opening moment holds before the island draws back into
    /// the resting pill; nil at rest.
    static func openingHold(_ moment: ZenithLockIslandMoment) -> TimeInterval? {
        switch moment {
        case .rest, .welcome, .bare: return nil
        case .farewell: return farewellHold
        case .remoteLock: return remoteHold
        }
    }

    /// When the padlock closes as the Mac locks: once the farewell has waved,
    /// or after a beat; locked from an iPhone it is closed from the start.
    static func padlockHold(_ moment: ZenithLockIslandMoment) -> TimeInterval {
        moment == .farewell ? farewellHold : 0.35
    }

    /// Zenith fork: whether the desktop island can take over from a padlock
    /// pill of `pill` as the Mac unlocks: one with a size to start from.
    static func handsOver(pill: CGSize) -> Bool {
        pill.width.isFinite && pill.height.isFinite && pill.width > 0 && pill.height > 0
    }

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
        // Zenith fork: and face unlock's scanning panel, the tallest it grows.
        let height = max(grownHeight(camera: surface.height, lines: 2), FaceUnlockIslandLayout.panel.height)
            + ZenithIslandMotion.heightSwingLimit + ZenithIslandMotion.flatteningLimit
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
