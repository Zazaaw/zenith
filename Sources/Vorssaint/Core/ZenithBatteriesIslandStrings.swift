// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import Foundation

// Zenith fork: the island's Batteries text (the page, its Home widget, the
// Battery Low card and its compact form). English in every language, by the
// owner's decision, as face unlock's: the advice is the droplet's own words.

struct ZenithBatteriesIslandStrings {
    let title = "Batteries"
    let summary = "Battery levels of this Mac, iPhone, Apple Watch and Bluetooth devices."
    let refresh = "Refresh"
    let reading = "Reading batteries…"
    let empty = "No batteries found"
    let emptyHint = "Bluetooth keyboards, mice, headphones and game controllers show here, and iPhone and Apple Watch once their reading is on."
    let noLevel = "No level yet"
    /// A level that is not known.
    let unknownLevel = "—"

    // Where a reading came from: the List layout's caption, in capitals.
    let builtIn = "Built-in"
    let bluetooth = "Bluetooth"
    let usb = "USB"
    let wifi = "Wi-Fi"
    let viaIPhone = "Via iPhone"
    /// `{time}` is how long ago, as "2 h".
    let lastSeen = "Last seen {time} ago"
    let lessThanAMinute = "<1 min"
    let minutes = "{count} min"
    let hours = "{count} h"
    let days = "{count} d"

    // The Battery Low card: the droplet's line of advice.
    let lowTitle = "Battery Low"
    let lowAlone = "Its battery is running low. It is recommended to charge it."
    /// `{name}` is the other device's name.
    let lowOne = "{name} is low too. It is recommended to charge them."
    /// `{count}` is how many more devices are low.
    let lowMany = "{count} more devices are low too. It is recommended to charge them."

    // VoiceOver.
    let percentValue = "{percent} percent"
    let levelUnknown = "Level unknown"
    let charging = "charging"
    let notReachable = "not reachable, last seen {time} ago"
    let open = "Open Batteries"

    func source(_ source: BatterySource) -> String {
        switch source {
        case .builtIn: return builtIn
        case .bluetooth: return bluetooth
        case .usb: return usb
        case .wifi: return wifi
        case .viaIPhone: return viaIPhone
        }
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func batteriesIsland(_ language: AppLanguage) -> ZenithBatteriesIslandStrings {
        ZenithBatteriesIslandStrings()
    }
}
