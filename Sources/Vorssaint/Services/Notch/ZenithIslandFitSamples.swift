// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the longest words each grown island can be asked to show, in
// every language: a 40-character device name (the remote script's limit),
// a long first name, a long project folder, every prayer and method. The
// tests check them against the layout's measures and the selftest against
// the views themselves, so no burst or lock screen moment ever truncates
// or runs under the camera. Compiled into the tests.

enum ZenithIslandFitSamples {
    /// As long as the remote script lets a device name be.
    static let device = "Muhammad Faiz Hawari’s iPhone 17 Pro Max"
    /// A long first name, as the greetings take the account's first word.
    static let firstName = "Maximiliano"
    /// A long project folder, as Claude's burst names it.
    static let folder = "satuvisual-zenith-island-fit-review-worktree"

    /// Every burst kind, worded at its longest in `language`.
    static func bursts(_ language: AppLanguage, start: Date = Date(timeIntervalSince1970: 0)) -> [(name: String, burst: ZenithIslandBurst)] {
        let locale = language.formattingLocale()
        let island = ZenithStrings.island(language), notices = ZenithStrings.notices(language)
        let sky = ZenithStrings.sky(language), lock = ZenithStrings.lockIsland(language)
        let method = PrayerMethod.allCases.max { $0.title.count < $1.title.count }?.title ?? ""
        let clock = PrayerTimesSupport.clock(Date(timeIntervalSince1970: 66_120), timeZone: TimeZone(identifier: "UTC")!,
                                             locale: locale)
        var samples: [(String, ZenithIslandBurst.Content)] = []
        for prayer in Prayer.allCases {
            for indonesian in [false, true] {
                samples.append(("prayer-\(prayer.rawValue)\(indonesian ? "-id" : "")", .prayer(ZenithPrayerBurst(
                    symbol: prayer.symbol, title: sky.arrival(prayer, indonesian: indonesian),
                    subtitle: clock + " · " + method, nextLabel: island.next,
                    next: sky.name(prayer, indonesian: indonesian) + " " + clock))))
            }
        }
        let charges: [(String, ZenithChargeState, Int?, String?)] = [
            ("charge-charging", .charging, 600, nil), ("charge-estimating", .charging, nil, nil),
            ("charge-limit", .charging, nil, notices.chargeHint), ("charge-held", .held, nil, nil),
            ("charge-full", .full, nil, nil), ("charge-unplugged", .onBattery, 1_199, nil), ("charge-unknown", .onBattery, nil, nil),
        ]
        for (name, state, minutes, hint) in charges {
            samples.append((name, .charge(.make(state, percent: 100, minutes: minutes, hint: hint, island: island,
                                                notices: notices, locale: locale))))
        }
        let long = ZenithLockIsland.duration(25 * 3_600 + 59 * 60, locale: locale)
        samples.append(("welcome", .welcome(ZenithWelcomeBurst(
            title: lock.welcomeBack(firstName), subtitle: lock.detail(duration: long, notifications: nil), initials: "MH"))))
        samples.append(("welcome-remote", .welcome(ZenithWelcomeBurst(
            title: lock.welcomeBack(firstName), subtitle: RemoteText.welcomeDetail(device: device, seconds: 25 * 3_600 + 59 * 60),
            initials: "MH"))))
        samples.append(("agent", .agent(ZenithAgentBurst(provider: .claude, title: ZenithStrings.claudeChime(language).needsYou,
                                                         subtitle: folder))))
        samples.append(("remote", .remote(ZenithRemoteBurst(device: device))))
        samples.append(("remote-short", .remote(ZenithRemoteBurst(device: "Faiz’s iPhone"))))
        return samples.map { ($0.0, ZenithIslandBurst($0.1, start: start)) }
    }

    /// The lock screen's greetings beside the camera: the farewell's wing.
    static func farewell(_ language: AppLanguage) -> String {
        ZenithStrings.lockIsland(language).seeYou(firstName)
    }
}
