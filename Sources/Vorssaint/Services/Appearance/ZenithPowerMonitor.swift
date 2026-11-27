// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import IOKit.ps

/// Zenith fork: tells `ZenithAppearance` about Low Power Mode and the internal
/// battery, so Automatic battery saving knows when to start. Both arrive as
/// notifications (the power state change and IOKit's power source run loop
/// source); nothing polls. Started once at launch and kept for the app's life.
@MainActor
final class ZenithPowerMonitor {
    static let shared = ZenithPowerMonitor()

    private var powerSource: CFRunLoopSource?
    private var lowPowerObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard lowPowerObserver == nil else { return }
        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // The callback runs on the main run loop, where the source is added.
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<ZenithPowerMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, Unmanaged.passUnretained(self).toOpaque())?
            .takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        refresh()
    }

    private func refresh() {
        let battery = ZenithPowerReading.current()
        ZenithAppearance.shared.updatePower(lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                            onBattery: battery.onBattery, batteryPercent: battery.percent)
    }
}

/// The internal battery as the battery saver needs it: whether the Mac runs
/// on it, and its charge. A Mac without one reads as on power, no percent.
struct ZenithPowerReading: Equatable {
    var onBattery: Bool
    var percent: Int?

    static let noBattery = ZenithPowerReading(onBattery: false, percent: nil)

    static func current() -> ZenithPowerReading {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return .noBattery }
        let descriptions = list.compactMap {
            IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any]
        }
        return reading(from: descriptions)
    }

    /// The first internal battery among IOKit's power source descriptions.
    static func reading(from descriptions: [[String: Any]]) -> ZenithPowerReading {
        guard let battery = descriptions.first(where: {
            $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType && $0[kIOPSIsPresentKey] as? Bool != false
        }) else { return .noBattery }
        let onBattery = battery[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
        var percent: Int?
        if let current = battery[kIOPSCurrentCapacityKey] as? Int, let maximum = battery[kIOPSMaxCapacityKey] as? Int,
           maximum > 0 {
            percent = min(100, max(0, Int((Double(current) * 100 / Double(maximum)).rounded())))
        }
        return ZenithPowerReading(onBattery: onBattery, percent: percent)
    }
}
