// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import UIKit

/// This iPhone's battery, as the report Zenith's Batteries shows.
@MainActor
enum PhoneBattery {
    /// nil when iOS has no reading (monitoring just turned on, or no battery).
    static func read(now: Date = Date()) -> PocketDeviceReport.Device? {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        let charging = device.batteryState == .charging || device.batteryState == .full
        return PocketDeviceReport.Device(kind: .iphone, name: name, percent: Int((level * 100).rounded()),
                                         charging: charging, readAt: now)
    }

    /// This iPhone, and its Apple Watch while the Watch's last reading is fresh.
    static func report(now: Date = Date()) -> PocketDeviceReport? {
        PocketPresentation.deviceReport(phone: read(now: now), watch: WatchBridge.storedWatch(), now: now)
    }

    /// iOS gives apps "iPhone" for the device's name, so the model makes it
    /// specific ("iPhone 13 Pro"); Zenith matches either to the iPhone it
    /// sees over USB or Wi-Fi.
    static var name: String {
        let given = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !given.isEmpty, given != "iPhone", given != UIDevice.current.model { return given }
        return models[identifier] ?? "iPhone"
    }

    private static var identifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// The iPhones iOS 26 runs on.
    private static let models: [String: String] = [
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE", "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max", "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e", "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
    ]
}
