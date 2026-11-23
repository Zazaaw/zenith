// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import Foundation
import IOKit
import IOKit.ps
import SystemConfiguration

/// Zenith fork: the Batteries readers that touch the system. Every one of
/// them blocks and is called from the monitor's scan queue only, never the
/// main thread; every process runs with a time limit.
enum BatteriesReaders {
    // MARK: The Mac

    /// The Mac's internal battery through IOKit's power sources.
    static func mac() -> BatteryDevice? {
        guard PowerSampler.hasInternalBattery,
              let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = maximum > 0 ? Int((Double(current) * 100 / Double(maximum)).rounded()) : current
            let state = info[kIOPSPowerSourceStateKey] as? String
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let charged = info[kIOPSIsChargedKey] as? Bool ?? (percent >= 100 && state == kIOPSACPowerValue)
            return BatteryDevice(id: "mac", name: macName, kind: .mac, source: .builtIn,
                                 percent: min(100, max(0, percent)), isCharging: charging, fullyCharged: charged)
        }
        return nil
    }

    /// The computer name from System Settings, read once: `Host` can wait
    /// on the network for it.
    private static let macName: String = {
        let name = (SCDynamicStoreCopyComputerName(nil, nil) as String?)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Mac" : name
    }()

    // MARK: Bluetooth

    static func bluetooth(cancellation: BatteriesScanCancellation) -> BatteriesBluetooth.Report {
        guard let output = run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"],
                               timeout: 10, maxOutputBytes: 4 * 1024 * 1024, cancellation: cancellation) else {
            return BatteriesBluetooth.Report()
        }
        return BatteriesBluetooth.report(from: jsonBody(output))
    }

    /// The runner merges stderr into the output; a warning printed before
    /// the JSON would make it unreadable.
    static func jsonBody(_ data: Data) -> Data {
        guard let start = data.firstIndex(of: UInt8(ascii: "{")),
              let end = data.lastIndex(of: UInt8(ascii: "}")), start < end else { return data }
        return data.subdata(in: start..<(end + 1))
    }

    // MARK: IORegistry accessories

    /// Every accessory publishing `BatteryPercent` right now, one per device.
    static func accessories() -> [BatteriesAccessoryReading] {
        var readings: [BatteriesAccessoryReading] = []
        for className in ["AppleDeviceManagementHIDEventService", "IOHIDDevice"] {
            forEachService(matching: className) { service in
                // A device that publishes a level is connected, so a 0 is no level.
                guard let level = intProperty(service, "BatteryPercent"), (1...100).contains(level),
                      !(boolProperty(service, "Built-In") ?? false) else { return }
                let address = BatteriesAddress.normalized(stringProperty(service, "DeviceAddress"))
                    ?? BatteriesAddress.normalized(stringProperty(service, "SerialNumber"))
                let name = stringProperty(service, "Product")
                // The same device can publish on both classes.
                guard !readings.contains(where: {
                    ($0.address != nil && $0.address == address)
                        || ($0.address == nil && address == nil && $0.name == name)
                }) else { return }
                readings.append(BatteriesAccessoryReading(
                    address: address, name: name, level: level,
                    kind: BatteriesAccessoryReading.kind(usagePage: intProperty(service, "PrimaryUsagePage"),
                                                         usage: intProperty(service, "PrimaryUsage")),
                    vendorID: intProperty(service, "VendorID")))
            }
        }
        return readings
    }

    private static func forEachService(matching className: String, _ body: (io_service_t) -> Void) {
        guard let matching = IOServiceMatching(className) else { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            body(service)
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> AnyObject? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func intProperty(_ entry: io_registry_entry_t, _ key: String) -> Int? {
        (property(entry, key) as? NSNumber)?.intValue
    }

    private static func boolProperty(_ entry: io_registry_entry_t, _ key: String) -> Bool? {
        (property(entry, key) as? NSNumber)?.boolValue
    }

    private static func stringProperty(_ entry: io_registry_entry_t, _ key: String) -> String? {
        property(entry, key) as? String
    }

    // MARK: Accessory power sources

    private typealias CopyPowerSourcesByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?

    /// `kIOPSSourceForAccessories` in IOPowerSourcesPrivate.h. The public
    /// `IOPSCopyPowerSourcesInfo` lists only internal batteries and UPSes.
    private static let accessorySourceType: Int32 = 4

    /// Looked up once at run time (read-only, no swizzling); nil when this
    /// macOS does not have it, and the reader then returns nothing.
    private static let copyPowerSourcesByType: CopyPowerSourcesByType? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "IOPSCopyPowerSourcesByType") else {
            return nil
        }
        return unsafeBitCast(symbol, to: CopyPowerSourcesByType.self)
    }()

    static func powerSources() -> [BatteriesPowerSourceReading] {
        guard let copy = copyPowerSourcesByType,
              let blob = copy(accessorySourceType)?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return []
        }
        return sources.compactMap { source in
            (IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any])
                .flatMap(BatteriesPowerSourceReading.reading(from:))
        }
    }

    // MARK: iPhone and iPad

    /// Where Homebrew puts a tool; the app has no shell PATH.
    static func tool(_ name: String) -> String? {
        for directory in ["/opt/homebrew/bin", "/usr/local/bin"] {
            let candidate = directory + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    static var iOSToolsInstalled: Bool { tool("idevice_id") != nil && tool("ideviceinfo") != nil }

    struct IOSIdentity {
        var name: String?
        var productType: String?
    }

    /// iPhones and iPads over USB and the network. A device listed but not
    /// answering (locked, asleep, not trusted) is left out: the registry
    /// shows its last known level. `identities` caches names between scans.
    static func iOSDevices(identities: inout [String: IOSIdentity],
                           cancellation: BatteriesScanCancellation) -> (devices: [BatteryDevice], listed: [BatteriesIOS.Listed]) {
        guard let ideviceID = tool("idevice_id"), let ideviceinfo = tool("ideviceinfo") else { return ([], []) }
        let usb = text(ideviceID, ["-l"], timeout: 5, cancellation: cancellation) ?? ""
        let network = text(ideviceID, ["-n"], timeout: 5, cancellation: cancellation) ?? ""
        let listed = BatteriesIOS.listed(usbOutput: usb, networkOutput: network)
        var devices: [BatteryDevice] = []
        for entry in listed where !cancellation.isCancelled {
            var arguments = ["-u", entry.udid]
            if entry.network { arguments.append("-n") }
            guard let battery = text(ideviceinfo, arguments + ["-q", "com.apple.mobile.battery"],
                                    timeout: 8, cancellation: cancellation).map(BatteriesIOS.infoOutput) else { continue }
            var identity = identities[entry.udid] ?? IOSIdentity()
            if identity.name == nil {
                identity.name = BatteriesIOS.singleValue(text(ideviceinfo, arguments + ["-k", "DeviceName"],
                                                             timeout: 6, cancellation: cancellation))
            }
            if identity.productType == nil {
                identity.productType = BatteriesIOS.singleValue(text(ideviceinfo, arguments + ["-k", "ProductType"],
                                                                    timeout: 6, cancellation: cancellation))
            }
            identities[entry.udid] = identity
            if let device = BatteriesIOS.device(udid: entry.udid, network: entry.network, battery: battery,
                                                name: identity.name, productType: identity.productType) {
                devices.append(device)
            }
        }
        return (devices, listed)
    }

    private static func text(_ path: String, _ arguments: [String], timeout: TimeInterval,
                             cancellation: BatteriesScanCancellation) -> String? {
        run(path, arguments, timeout: timeout, maxOutputBytes: 256 * 1024, cancellation: cancellation)
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The output of a tool that exited cleanly in time, nil otherwise.
    private static func run(_ path: String, _ arguments: [String], timeout: TimeInterval, maxOutputBytes: Int,
                            cancellation: BatteriesScanCancellation) -> Data? {
        guard let token = cancellation.makeToken() else { return nil }
        defer { cancellation.finished(token) }
        let result = BoundedProcessRunner.run(path, arguments, timeout: timeout, maxOutputBytes: maxOutputBytes,
                                              cancellation: token)
        guard result.status == 0, !result.timedOut, !token.isCancelled else { return nil }
        return result.output
    }
}

/// One scan's processes: each child gets a token of its own (a token
/// launches one child), and cancelling the scan ends every one still running.
final class BatteriesScanCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var tokens: [ObjectIdentifier: BoundedProcessCancellation] = [:]

    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    func makeToken() -> BoundedProcessCancellation? {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return nil }
        let token = BoundedProcessCancellation()
        tokens[ObjectIdentifier(token)] = token
        return token
    }

    func finished(_ token: BoundedProcessCancellation) {
        lock.lock(); defer { lock.unlock() }
        tokens.removeValue(forKey: ObjectIdentifier(token))
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let running = Array(tokens.values)
        tokens.removeAll()
        lock.unlock()
        running.forEach { $0.cancel() }
    }
}
