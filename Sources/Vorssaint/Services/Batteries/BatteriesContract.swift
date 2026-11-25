// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import Combine
import Foundation

/// Zenith fork: the shared contract between the three parts of Batteries,
/// built in parallel:
/// - the readers and the monitor (Mac, Bluetooth, accessory power sources,
///   BLE Battery Service, AirPods broadcasts, iPhone/iPad over libimobiledevice,
///   Apple Watch through its iPhone), the alert rules and the last-known cache;
/// - the island (Batteries page in Rings or List layout, Home widget,
///   the Battery Low card and its compact form);
/// - Settings (the Batteries page under Monitor).
/// Each side depends only on what is declared here.

/// What kind of device a reading is for. The symbol is the droplet's.
enum BatteryDeviceKind: String, Codable, Hashable, CaseIterable {
    case mac, iphone, ipad, watch, headphones, keyboard, mouse, trackpad, speaker, gamepad, other

    /// The kind's generic SF Symbol. `BatteryDevice.symbolName` refines it
    /// (Apple mice, AirPods models).
    var symbolName: String {
        switch self {
        case .mac: return "laptopcomputer"
        case .iphone: return "iphone"
        case .ipad: return "ipad"
        case .watch: return "applewatch"
        case .headphones: return "headphones"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .speaker: return "hifispeaker"
        case .gamepad: return "gamecontroller"
        case .other: return "wave.3.right.circle"
        }
    }
}

/// Where a reading came from, shown as the List layout's caption and in Settings.
/// Zenith fork: `pocket` is the iPhone's (and its Watch's) own report through
/// Zenith Pocket, over the internet rather than a cable or the local network.
enum BatterySource: String, Codable, Hashable {
    case builtIn, bluetooth, usb, wifi, viaIPhone, pocket
}

/// One device's battery. Mirrors the droplet's `DeviceBattery`.
struct BatteryDevice: Codable, Hashable, Identifiable {
    /// Per-component level, e.g. AirPods Left / Right / Case.
    struct Component: Codable, Hashable {
        let label: String
        let percent: Int
    }

    let id: String
    var name: String
    var kind: BatteryDeviceKind
    var source: BatterySource
    /// nil when the device is listed but gives no level ("—").
    var percent: Int?
    var isCharging: Bool = false
    var fullyCharged: Bool = false
    /// AirPods and other earbuds with separate cells; empty otherwise.
    var components: [Component] = []
    /// Set when the level is the last known one, not live: the device is
    /// missing from the current scan. Shown dimmed (0.45), with "seen … ago".
    var unreachableSince: Date?
    /// Apple's Bluetooth product id (AirPods models), when known.
    var productID: Int?
    /// The vendor reported by Bluetooth or HID, when known.
    var vendorID: Int?
    /// The exact SF Symbol to draw, resolved by the monitor (AirPods model,
    /// Apple mouse). nil means `kind.symbolName`.
    var symbolOverride: String?

    var isReachable: Bool { unreachableSince == nil }
    var symbolName: String { symbolOverride ?? kind.symbolName }

    /// The droplet's ring tint rule: green while charging or above the
    /// threshold, red at or below it.
    func isLow(threshold: Int) -> Bool {
        guard let percent, !isCharging else { return false }
        return percent <= threshold
    }
}

/// A low-battery alert for the island to present once (the Battery Low card,
/// then its compact form). `others` names further devices that went low in
/// the same scan, for the card's line of advice.
struct BatteriesLowAlert: Equatable, Identifiable {
    let id: UUID
    let device: BatteryDevice
    let percent: Int
    let others: [String]
}

/// Whether the libimobiledevice tools (Homebrew) are there for iPhone, iPad
/// and Apple Watch readings.
enum BatteriesIOSToolsStatus: Equatable {
    case unknown
    case missing
    /// `idevice_id` and `ideviceinfo` found; `watchSupport` is whether the
    /// library could be loaded for Apple Watch readings through the iPhone.
    case installed(watchSupport: Bool)
}

/// How the Batteries page draws its devices.
enum BatteriesLayout: String, CaseIterable, Identifiable {
    case rings, list
    var id: String { rawValue }
}

/// Batteries preferences. Kept here, not in `DefaultsKey`, so the three parts
/// never edit the same file.
enum BatteriesDefaults {
    static let enabled = "zenithBatteriesEnabled"                  // Bool, default true
    static let layout = "zenithBatteriesLayout"                    // BatteriesLayout raw, default .rings
    static let threshold = "zenithBatteriesThreshold"              // Int, one of thresholdOptions, default 20
    static let refreshMinutes = "zenithBatteriesRefreshMinutes"    // Int, one of refreshOptions, default 2
    static let mutedDeviceIDs = "zenithBatteriesMutedDeviceIDs"    // [String]: devices whose alert is off
    static let hiddenDeviceIDs = "zenithBatteriesHiddenDeviceIDs"  // [String]: devices not shown at all
    static let airPodsScanning = "zenithBatteriesAirPodsScanning"  // Bool, default false (droplet default)
    static let readIOSDevices = "zenithBatteriesReadIOSDevices"    // Bool, default true

    static let thresholdOptions = [10, 15, 20, 30]
    static let defaultThreshold = 20
    static let refreshOptions = [1, 2, 5, 10]
    static let defaultRefreshMinutes = 2
    /// The droplet's rules: refresh every 5 minutes while the page is not on
    /// screen (only when some device can alert); alert once, again only after
    /// the level recovers this far above the threshold; keep last-known
    /// levels this long.
    static let hiddenRefreshMinutes = 5
    static let rearmMargin = 5
    static let lastKnownLifetime: TimeInterval = 7 * 86_400
}

/// The state every part reads. The monitor writes it on the main thread.
final class BatteriesStore: ObservableObject {
    static let shared = BatteriesStore()

    /// Ordered like the droplet: the Mac first, then live devices, then last-known ones.
    @Published var devices: [BatteryDevice] = []
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    @Published var iOSTools: BatteriesIOSToolsStatus = .unknown
    /// Set by the monitor when a device goes low; the island presents it and
    /// sets it back to nil.
    @Published var pendingLowAlert: BatteriesLowAlert?

    /// Installed by the monitor.
    var refreshHandler: (() -> Void)?
    var visibilityHandler: ((Bool) -> Void)?

    /// Ask for a scan now (the page opening, a refresh button, a Settings change).
    func refreshNow() { refreshHandler?() }
    /// The island reports whether the Batteries page or widget is on screen,
    /// which picks the refresh interval.
    func setVisible(_ visible: Bool) { visibilityHandler?(visible) }

    /// Readings to design and test against before the monitor exists.
    static let sample: [BatteryDevice] = [
        BatteryDevice(id: "mac", name: "MacBook Pro", kind: .mac, source: .builtIn, percent: 100, isCharging: true),
        BatteryDevice(id: "sample-iphone", name: "iPhone", kind: .iphone, source: .wifi, percent: 57),
        BatteryDevice(id: "sample-watch", name: "Apple Watch", kind: .watch, source: .viaIPhone, percent: 64),
        BatteryDevice(id: "sample-headphones", name: "soundcore Liberty 4 NC", kind: .headphones, source: .bluetooth, percent: 70),
        BatteryDevice(id: "sample-gamepad", name: "Xbox Wireless Controller", kind: .gamepad, source: .bluetooth, percent: 15),
        BatteryDevice(id: "sample-keyboard", name: "Maxfit61 5.0", kind: .keyboard, source: .bluetooth, percent: 45,
                      unreachableSince: Date(timeIntervalSinceNow: -7_200)),
    ]
}
