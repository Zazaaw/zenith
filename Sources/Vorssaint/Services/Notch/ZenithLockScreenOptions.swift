// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Combine
import Foundation

/// Zenith fork: every part of the lock screen v2, one switch each.
///
/// The minimal layer sits over the wallpaper: long jobs in the activity row,
/// the song's title and artist, a small two line lyric, and the terminal
/// readout at its chosen height. The full layer is the lyrics view opened by
/// clicking the lyric: a solid colour from the cover, the record, the lyrics
/// at full size, and the corners (clock, jobs, account, login hint).
enum ZenithLockScreenOption: String, CaseIterable, Identifiable {
    // Minimal layer.
    case jobs, nowPlaying, lyrics, karaoke, titleControls
    // Full layer.
    case full, fullDisc, fullAccount, fullDevice, fullClock, fullJobs, fullCoverColor, fullLoginHint

    var id: String { rawValue }

    var defaultsKey: String {
        switch self {
        case .jobs: return DefaultsKey.zenithLockJobs
        case .nowPlaying: return DefaultsKey.zenithLockNowPlaying
        case .lyrics: return DefaultsKey.zenithLockLyrics
        case .karaoke: return DefaultsKey.zenithLockKaraoke
        case .titleControls: return DefaultsKey.zenithLockTitleControls
        case .full: return DefaultsKey.zenithLockFull
        case .fullDisc: return DefaultsKey.zenithLockFullDisc
        case .fullAccount: return DefaultsKey.zenithLockFullAccount
        case .fullDevice: return DefaultsKey.zenithLockFullDevice
        case .fullClock: return DefaultsKey.zenithLockFullClock
        case .fullJobs: return DefaultsKey.zenithLockFullJobs
        case .fullCoverColor: return DefaultsKey.zenithLockFullCoverColor
        case .fullLoginHint: return DefaultsKey.zenithLockFullLoginHint
        }
    }

    /// Every part starts on; each can be turned off on its own.
    var isOnByDefault: Bool { true }

    /// Parts of the full layer only matter while the full layer itself is on.
    var isFullLayer: Bool {
        switch self {
        case .full, .fullDisc, .fullAccount, .fullDevice, .fullClock, .fullJobs, .fullCoverColor, .fullLoginHint: return true
        default: return false
        }
    }

    func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? isOnByDefault
    }
}

/// The full layer's background: one solid colour, or the cover itself blurred
/// to fill the screen. With `solid`, `ZenithLockScreenOption.fullCoverColor`
/// picks the colour's source: on = the cover's dominant colour, off = the
/// colour chosen in Settings (`ZenithLockScreenCustomColor`).
enum ZenithLockScreenFullBackground: String, CaseIterable, Identifiable {
    case solid, blurredCover

    var id: String { rawValue }
    static let fallback: Self = .solid

    static func current(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: DefaultsKey.zenithLockFullBackground).flatMap(Self.init(rawValue:)) ?? fallback
    }
}

/// How strongly the cover is blurred behind the full layer, in points.
enum ZenithLockScreenFullBlur {
    static let range: ClosedRange<Double> = 10...80
    static let fallback: Double = 40

    static func radius(in defaults: UserDefaults = .standard) -> Double {
        let stored = defaults.object(forKey: DefaultsKey.zenithLockFullBlurRadius) as? Double ?? fallback
        return min(max(stored, range.lowerBound), range.upperBound)
    }
}

/// The solid colour picked in Settings, as "RRGGBB".
enum ZenithLockScreenCustomColor {
    static let fallback: UInt32 = 0x1C1C1E

    static func rgb(in defaults: UserDefaults = .standard) -> UInt32 {
        parse(defaults.string(forKey: DefaultsKey.zenithLockFullCustomColor)) ?? fallback
    }

    static func parse(_ text: String?) -> UInt32? {
        guard var hex = text?.trimmingCharacters(in: .whitespaces) else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return value
    }

    static func string(_ rgb: UInt32) -> String { String(format: "%06X", rgb & 0xFFFFFF) }
}

/// Where the terminal readout sits: under the centre column as before, or low,
/// its bottom 10 pt above the login controls.
enum ZenithLockScreenTerminalPlacement: String, CaseIterable, Identifiable {
    case normal, low

    var id: String { rawValue }
    static let fallback: Self = .low

    static func current(in defaults: UserDefaults = .standard) -> Self {
        defaults.string(forKey: DefaultsKey.zenithLockTerminalPlacement).flatMap(Self.init(rawValue:)) ?? fallback
    }
}

/// The long jobs the activity row can follow, one switch each.
enum ZenithLockScreenJobSource: String, CaseIterable, Identifiable {
    case export, cardImport, backup, command, vercel

    var id: String { rawValue }

    var defaultsKey: String {
        switch self {
        case .export: return DefaultsKey.zenithLockJobExport
        case .cardImport: return DefaultsKey.zenithLockJobCardImport
        case .backup: return DefaultsKey.zenithLockJobBackup
        case .command: return DefaultsKey.zenithLockJobCommand
        case .vercel: return DefaultsKey.zenithLockJobVercel
        }
    }

    func isOn(in defaults: UserDefaults = .standard) -> Bool {
        ZenithLockScreenOption.jobs.isOn(in: defaults) && (defaults.object(forKey: defaultsKey) as? Bool ?? true)
    }
}

/// One long job as the lock screen shows it: a ring, a short label, a figure.
struct ZenithLockScreenJob: Identifiable, Equatable {
    let id: String
    let source: ZenithLockScreenJobSource
    /// Short, such as "DaVinci", "Import", "Backup", a command's name, a project.
    let label: String
    /// 0...1 when known; nil draws an indeterminate ring.
    let fraction: Double?
    /// Shown briefly with a check once done, then dropped.
    let finished: Bool
}

/// The jobs running now, newest first, already filtered by their switches.
/// Fed by ZenithLockScreenJobFeed; read by the lock screen views.
final class ZenithLockScreenJobs: ObservableObject {
    static let shared = ZenithLockScreenJobs()
    @Published var items: [ZenithLockScreenJob] = []
    /// At most this many show; the rest fold into "+N".
    static let visibleLimit = 2
}
