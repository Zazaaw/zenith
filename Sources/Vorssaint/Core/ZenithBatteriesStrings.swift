// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Batteries' text in Settings (Settings → Batteries) and its
// credit in About. English in every language, by the owner's decision, as
// Face Unlock's. Settings search still finds it by Indonesian aliases
// (BatteriesSearch).

struct ZenithBatteriesStrings {
    // Page.
    let title = "Batteries"
    let subtitle = "Your Mac and everything around it, in one place, and when to warn you."
    let enable = "Enable Batteries"
    let enableHint = "The island’s Batteries page and the low battery alerts."

    // Look.
    let look = "Look"
    let layout = "Layout"
    let rings = "Rings"
    let list = "List"

    // Devices.
    let devices = "Devices"
    let alert = "Alert"
    let devicesEmpty = "No devices found yet. Your Mac shows here, and Bluetooth devices that report their battery."
    let devicesHint = "Right-click a device to hide it from Batteries."
    let hide = "Hide from Batteries"
    let hidden = "Hidden"
    let unhide = "Show Again"
    let charging = "charging"
    let full = "full"
    let lastSeen = "last seen {time}"
    let seen = "seen {time}"
    let justNow = "just now"
    let minutesAgo = "{n} min ago"
    let hoursAgo = "{n} h ago"
    let daysAgo = "{n} d ago"
    let noLevel = "—"
    let macAlertCaption = "The Mac’s own alert starts off: Zenith already warns when the Mac runs low."

    // Sources.
    let builtIn = "Built-in"
    let bluetooth = "Bluetooth"
    let usb = "USB"
    let wifi = "Wi-Fi"
    let viaIPhone = "Via iPhone"

    // Low battery alert.
    let lowBatteryAlert = "Low battery alert"
    let warnAt = "Warn me at"
    let checkEvery = "Check every"
    let minutes = "{n} min"
    let checkEveryCaption = "While the Batteries page isn’t open, it checks every 5 min."
    let alertRule = "Each device warns once, then again after it climbs 5% above the line. Charging devices never warn."
    let airPodsScanning = "AirPods scanning"
    let airPodsScanningCaption = "Listens for a few seconds on each check for the levels AirPods broadcast. Only AirPods paired with this Mac."

    // iPhone & Apple Watch.
    let iOSSection = "iPhone & Apple Watch"
    let readIOS = "Read iPhone, iPad and Apple Watch"
    let readIOSCaption = "Over a cable or the same Wi-Fi, through libimobiledevice."
    let needsTools = "Needs libimobiledevice"
    let needsToolsCaption = "Free and open source. Nothing to install on the phone or the watch."
    let install = "Install with Homebrew"
    let installing = "Installing…"
    let installFailed = "Homebrew couldn’t install libimobiledevice."
    let tryAgain = "Try Again"
    let noHomebrew = "Homebrew isn’t installed. Install it first, then come back here."
    let getHomebrew = "Get Homebrew"
    let busyHomebrew = "Homebrew is busy with something else. Try again when it’s done."
    let checkingTools = "Checking for libimobiledevice…"
    let toolsInstalled = "libimobiledevice installed"
    let noWatchSupport = "Apple Watch readings are unavailable: the library that reads them through the iPhone couldn’t be loaded."
    let watchCaption = "while the iPhone is reachable"
    let noIOSDevices = "No iPhone, iPad or Apple Watch found yet."
    let stepCable = "Connect the iPhone or iPad with a cable and tap Trust."
    let stepWiFi = "In Finder, turn on “Show this iPhone when on Wi-Fi”."
    let stepWatch = "Apple Watch is read through the iPhone it’s paired with."

    // About.
    let credit = "Batteries is adapted from the Batteries droplet by Akhil Chandran, used under the MIT License."
    let showLicense = "Show License"
    let hideLicense = "Hide License"

    /// "{n} min" and friends.
    func count(_ template: String, _ value: Int) -> String {
        template.replacingOccurrences(of: "{n}", with: String(value))
    }

    func time(_ template: String, _ value: String) -> String {
        template.replacingOccurrences(of: "{time}", with: value)
    }

    /// How long ago, in the captions' short form: "just now", "5 min ago", "2 h ago", "3 d ago".
    func ago(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes < 1 { return justNow }
        if minutes < 60 { return count(minutesAgo, minutes) }
        if minutes < 24 * 60 { return count(hoursAgo, minutes / 60) }
        return count(daysAgo, minutes / (24 * 60))
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func batteries(_ language: AppLanguage) -> ZenithBatteriesStrings {
        ZenithBatteriesStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum BatteriesSearch {
    static let aliases = ["battery", "batteries", "battery level", "low battery", "charge", "airpods", "headphones",
                          "keyboard", "mouse", "trackpad", "controller", "iphone", "ipad", "apple watch", "watch",
                          "baterai", "batre", "batere", "daya", "sisa baterai", "baterai lemah", "baterai habis",
                          "cas", "ngecas", "jam", "jam tangan", "tetikus", "papan ketik"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.batteries(language)
        return [text.enable, text.devices, text.lowBatteryAlert, text.iOSSection]
    }
}
