// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import Foundation

/// Zenith fork: the Batteries rules on plain values: how one scan's readings
/// combine, the last-known registry, the low-battery alert, the refresh
/// schedule and the preferences they read. No devices, no processes.

// MARK: - Preferences

struct BatteriesConfig: Equatable {
    /// The Mac has its own low-battery notice in the island, so Batteries
    /// stays quiet about it until the user turns its alert on. That default
    /// is the registered value of `mutedDeviceIDs`: once the list is written
    /// it says everything, and leaving "mac" out of it turns the alert on.
    static let mutedByDefault = ["mac"]

    var enabled = true
    var threshold = BatteriesDefaults.defaultThreshold
    var refreshMinutes = BatteriesDefaults.defaultRefreshMinutes
    var muted = Set(BatteriesConfig.mutedByDefault)
    var hidden: Set<String> = []
    var airPodsScanning = false
    var readIOSDevices = true

    static func current(in defaults: UserDefaults = .standard) -> BatteriesConfig {
        BatteriesConfig(
            enabled: defaults.object(forKey: BatteriesDefaults.enabled) as? Bool ?? true,
            threshold: sanitizedThreshold(defaults.object(forKey: BatteriesDefaults.threshold) as? Int),
            refreshMinutes: sanitizedRefreshMinutes(defaults.object(forKey: BatteriesDefaults.refreshMinutes) as? Int),
            muted: Set(defaults.stringArray(forKey: BatteriesDefaults.mutedDeviceIDs) ?? mutedByDefault),
            hidden: Set(defaults.stringArray(forKey: BatteriesDefaults.hiddenDeviceIDs) ?? []),
            airPodsScanning: defaults.object(forKey: BatteriesDefaults.airPodsScanning) as? Bool ?? false,
            readIOSDevices: defaults.object(forKey: BatteriesDefaults.readIOSDevices) as? Bool ?? true
        )
    }

    /// The contract's defaults, registered at launch so every part reading a
    /// key (AppStorage included) sees the same value, the muted Mac too.
    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            BatteriesDefaults.enabled: true,
            BatteriesDefaults.layout: BatteriesLayout.rings.rawValue,
            BatteriesDefaults.threshold: BatteriesDefaults.defaultThreshold,
            BatteriesDefaults.refreshMinutes: BatteriesDefaults.defaultRefreshMinutes,
            BatteriesDefaults.mutedDeviceIDs: mutedByDefault,
            BatteriesDefaults.hiddenDeviceIDs: [String](),
            BatteriesDefaults.airPodsScanning: false,
            BatteriesDefaults.readIOSDevices: true,
        ])
    }

    static func sanitizedThreshold(_ value: Int?) -> Int {
        guard let value, BatteriesDefaults.thresholdOptions.contains(value) else { return BatteriesDefaults.defaultThreshold }
        return value
    }

    static func sanitizedRefreshMinutes(_ value: Int?) -> Int {
        guard let value, BatteriesDefaults.refreshOptions.contains(value) else { return BatteriesDefaults.defaultRefreshMinutes }
        return value
    }

    /// What decides which readers a scan runs; a change asks for a new scan.
    var readerSignature: [Bool] { [airPodsScanning, readIOSDevices] }
}

// MARK: - One scan

/// Everything one scan read, before it is combined.
struct BatteriesScanInputs {
    var mac: BatteryDevice?
    /// iPhones and iPads (libimobiledevice) and watches through them.
    var apple: [BatteryDevice] = []
    var bluetooth = BatteriesBluetooth.Report()
    var accessories: [BatteriesAccessoryReading] = []
    var powerSources: [BatteriesPowerSourceReading] = []
    /// BLE Battery Service levels by `BatteriesNames.key`.
    var gattLevels: [String: Int] = [:]
    /// AirPods broadcasts by advertised name.
    var airPods: [String: BatteriesAirPodsSighting] = [:]
}

enum BatteriesMerge {
    /// A broadcast older than this no longer fills a level.
    static let airPodsLevelMaxAge: TimeInterval = 10 * 60
    /// AirPods that are not connected at all get their own row only while
    /// they broadcast close by and recently, so a case across the room (or
    /// someone else's) does not show up.
    static let airPodsRowMaxAge: TimeInterval = 2 * 60
    static let airPodsNearbyRSSI = -60
    static let proximityIDPrefix = "airpods-proximity-"
    static let accessoryIDPrefix = "hid-"
    static let powerSourceIDPrefix = "ps-"

    static func isProximityOnly(_ id: String) -> Bool { id.hasPrefix(proximityIDPrefix) }

    /// The Mac, the iPhone side, then system_profiler's devices with the
    /// levels it misses filled from macOS's accessory power sources, the
    /// IORegistry, the BLE Battery Service and AirPods broadcasts.
    static func combine(_ inputs: BatteriesScanInputs, now: Date) -> [BatteryDevice] {
        var result: [BatteryDevice] = []
        if let mac = inputs.mac { result.append(mac) }
        result.append(contentsOf: inputs.apple)

        var unclaimed = inputs.accessories
        func claim(_ device: BatteryDevice) -> BatteriesAccessoryReading? {
            guard let reading = BatteriesAccessoryReading.reading(
                address: BatteriesBluetooth.address(of: device), name: device.name, in: unclaimed) else { return nil }
            if let index = unclaimed.firstIndex(of: reading) { unclaimed.remove(at: index) }
            return reading
        }
        // A device with one battery takes the power source's level, as
        // macOS's own list does; any other device only when nothing else
        // gave one. AirPods with two pods and a case keep their buds.
        var unusedSources = inputs.powerSources
        func claimSource(for device: BatteryDevice) -> BatteriesPowerSourceReading? {
            if let model = BatteriesAirPodsModel(productID: device.productID, name: device.name), model != .max { return nil }
            guard let source = BatteriesPowerSourceReading.reading(
                address: BatteriesBluetooth.address(of: device), name: device.name,
                productID: device.productID, in: unusedSources) else { return nil }
            if let index = unusedSources.firstIndex(of: source) { unusedSources.remove(at: index) }
            return source
        }

        for var device in inputs.bluetooth.devices {
            let reading = claim(device)
            if let source = claimSource(for: device) {
                device.vendorID = device.vendorID ?? source.vendorID
                if device.percent == nil
                    || BatteriesSingleCellAudio.isSingleCell(productID: device.productID, name: device.name) {
                    device.percent = source.level
                    device.isCharging = source.isCharging
                }
            }
            if device.percent == nil {
                if let reading {
                    device.percent = reading.level
                } else if let level = inputs.gattLevels[BatteriesNames.key(device.name)], level > 0 {
                    device.percent = level
                } else if let sighting = sighting(for: device.name, in: inputs.airPods, now: now,
                                                  maxAge: airPodsLevelMaxAge, minRSSI: nil),
                          let level = sighting.battery.level {
                    device.percent = level
                    device.isCharging = sighting.battery.isCharging
                    if device.components.isEmpty { device.components = sighting.battery.components }
                }
            }
            if device.kind == .other, let kind = reading?.kind { device.kind = kind }
            device.vendorID = device.vendorID ?? reading?.vendorID
            result.append(device)
        }

        // An accessory with a live level that system_profiler listed as not
        // connected, or left out, is connected: list it under its own name.
        for reading in unclaimed {
            if var device = BatteriesAccessoryReading.paired(for: reading, in: inputs.bluetooth.notConnected) {
                if device.kind == .other, let kind = reading.kind { device.kind = kind }
                device.vendorID = device.vendorID ?? reading.vendorID
                device.percent = reading.level
                result.append(device)
            } else if let name = reading.name, !name.isEmpty {
                result.append(BatteryDevice(
                    id: accessoryIDPrefix + (reading.address ?? BatteriesNames.key(name)),
                    name: name,
                    kind: reading.kind ?? BatteriesBluetooth.kind(name: name, minorType: nil),
                    source: .bluetooth,
                    percent: reading.level,
                    vendorID: reading.vendorID
                ))
            }
        }

        // Zenith fork: the same for an accessory power source no listed
        // device took (a headset system_profiler shows as not connected, or
        // not at all). One that names a device already listed is part of it
        // (AirPods publish a source per bud), never a row of its own.
        for source in unusedSources {
            guard let name = source.name, !name.isEmpty,
                  BatteriesNameMatch.best(name, in: result, name: \.name) == nil else { continue }
            if var device = paired(source, in: inputs.bluetooth.notConnected) {
                device.percent = source.level
                device.isCharging = source.isCharging
                device.vendorID = device.vendorID ?? source.vendorID
                result.append(device)
            } else {
                result.append(BatteryDevice(
                    id: powerSourceIDPrefix + (source.address ?? BatteriesNames.key(name)),
                    name: name,
                    kind: source.kind,
                    source: .bluetooth,
                    percent: source.level,
                    isCharging: source.isCharging,
                    productID: source.vendorID == 0x004C ? source.productID : nil,
                    vendorID: source.vendorID
                ))
            }
        }

        // AirPods open nearby but not connected never reach system_profiler:
        // add them from the broadcast, only ones paired with this Mac.
        let known = Set(result.map { BatteriesNames.key($0.name) })
        for name in inputs.airPods.keys.sorted() {
            let key = BatteriesNames.key(name)
            guard inputs.bluetooth.pairedNames.contains(name.lowercased()) || inputs.bluetooth.pairedNames.contains(key),
                  !known.contains(key),
                  let sighting = sighting(for: name, in: inputs.airPods, now: now,
                                          maxAge: airPodsRowMaxAge, minRSSI: airPodsNearbyRSSI) else { continue }
            result.append(BatteryDevice(
                id: proximityIDPrefix + name,
                name: name,
                kind: .headphones,
                source: .bluetooth,
                percent: sighting.battery.level,
                isCharging: sighting.battery.isCharging,
                components: sighting.battery.components,
                productID: Int(sighting.battery.model)
            ))
        }
        return result
    }

    static func sighting(for name: String, in sightings: [String: BatteriesAirPodsSighting], now: Date,
                         maxAge: TimeInterval, minRSSI: Int?) -> BatteriesAirPodsSighting? {
        let key = BatteriesNames.key(name)
        guard let sighting = sightings.first(where: { BatteriesNames.key($0.key) == key })?.value,
              now.timeIntervalSince(sighting.date) <= maxAge else { return nil }
        if let minRSSI, sighting.rssi < minRSSI { return nil }
        return sighting
    }

    private static func paired(_ source: BatteriesPowerSourceReading, in devices: [BatteryDevice]) -> BatteryDevice? {
        if let address = source.address,
           let match = devices.first(where: { BatteriesBluetooth.address(of: $0) == address }) {
            return match
        }
        guard let name = source.name else { return nil }
        return devices.first { BatteriesNames.key($0.name) == BatteriesNames.key(name) }
    }

    /// Whether a connected accessory is still without a level after the
    /// quick sources, which is when the BLE Battery Service is worth asking.
    static func needsBatteryService(_ inputs: BatteriesScanInputs, now: Date) -> Bool {
        combine(inputs, now: now).contains {
            $0.source == .bluetooth && $0.percent == nil && !BatteriesBluetooth.isContinuityDevice($0.kind)
        }
    }

    /// The same iPhone, iPad or Watch can come from Bluetooth and from the
    /// iPhone side at once. One device per name: a level beats "—", then
    /// live beats last known, then the iPhone side beats Bluetooth, then the
    /// more recent last known wins.
    static func deduplicated(_ devices: [BatteryDevice]) -> [BatteryDevice] {
        var best: [String: BatteryDevice] = [:]
        var order: [String] = []
        for device in devices {
            let key = BatteriesNames.key(device.name)
            guard let existing = best[key] else {
                best[key] = device
                order.append(key)
                continue
            }
            if isBetter(device, than: existing) { best[key] = device }
        }
        return order.compactMap { best[$0] }
    }

    static func isBetter(_ a: BatteryDevice, than b: BatteryDevice) -> Bool {
        if (a.percent != nil) != (b.percent != nil) { return a.percent != nil }
        if a.isReachable != b.isReachable { return a.isReachable }
        let aApple = isAppleSide(a.id), bApple = isAppleSide(b.id)
        if aApple != bApple { return aApple }
        return (a.unreachableSince ?? .distantPast) > (b.unreachableSince ?? .distantPast)
    }

    private static func isAppleSide(_ id: String) -> Bool {
        id.hasPrefix(BatteriesIOS.idPrefix) || id.hasPrefix(BatteriesWatch.idPrefix)
    }

    /// The Mac first, then live devices, then last-known ones, by name.
    static func ordered(_ devices: [BatteryDevice]) -> [BatteryDevice] {
        devices.sorted { a, b in
            if (a.kind == .mac) != (b.kind == .mac) { return a.kind == .mac }
            if a.isReachable != b.isReachable { return a.isReachable }
            let byName = a.name.localizedCaseInsensitiveCompare(b.name)
            return byName == .orderedSame ? a.id < b.id : byName == .orderedAscending
        }
    }
}

// MARK: - Last known

/// Remembers every device seen recently, so one that stops answering shows
/// dimmed with its last level instead of silently vanishing. Kept on disk;
/// AirPods known only from their broadcast are never saved.
struct BatteriesRegistry: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var device: BatteryDevice
        var lastSeen: Date
        /// The last live level and when it was read.
        var lastPercent: Int?
        var lastPercentDate: Date?
    }

    var entries: [String: Entry] = [:]
    /// Devices that already alerted and have not recovered yet, kept so a
    /// relaunch does not announce the same low battery again.
    var alerted: Set<String> = []

    /// Feed one scan in; get back the same devices plus any previously seen
    /// ones now missing, marked unreachable with their last level. A device
    /// listed without a live level shows its last one, dimmed as of when it
    /// was read. Anything not seen for `lifetime` is dropped.
    mutating func reconcile(current: [BatteryDevice], now: Date,
                            lifetime: TimeInterval = BatteriesDefaults.lastKnownLifetime) -> [BatteryDevice] {
        var seen = Set<String>()
        var result: [BatteryDevice] = []
        for device in current {
            if BatteriesMerge.isProximityOnly(device.id) {
                result.append(device)
                continue
            }
            seen.insert(device.id)
            var stored = device
            stored.unreachableSince = nil
            stored.symbolOverride = nil
            let previous = entries[device.id]
            var entry = Entry(device: stored, lastSeen: now,
                              lastPercent: previous?.lastPercent, lastPercentDate: previous?.lastPercentDate)
            var shown = device
            if let percent = device.percent {
                entry.lastPercent = percent
                entry.lastPercentDate = now
            } else if let last = entry.lastPercent, last > 0, let date = entry.lastPercentDate,
                      now.timeIntervalSince(date) <= lifetime {
                shown.percent = last
                shown.isCharging = false
                shown.fullyCharged = false
                shown.unreachableSince = date
            }
            entries[device.id] = entry
            result.append(shown)
        }

        for id in entries.keys.sorted() where !seen.contains(id) {
            guard let entry = entries[id] else { continue }
            if now.timeIntervalSince(entry.lastSeen) > lifetime || BatteriesMerge.isProximityOnly(id) {
                entries.removeValue(forKey: id)
                continue
            }
            var missing = entry.device
            missing.isCharging = false
            missing.fullyCharged = false
            missing.unreachableSince = entry.lastSeen
            if missing.percent == 0 { missing.percent = nil }
            if missing.percent == nil, let last = entry.lastPercent, last > 0 {
                missing.percent = last
                missing.unreachableSince = entry.lastPercentDate ?? entry.lastSeen
            }
            result.append(missing)
        }
        alerted.formIntersection(Set(entries.keys))
        return result
    }

    /// What is worth writing again: a new device, a new level, a new alert.
    /// Only the time a device was last seen moves on every scan.
    var persistenceSignature: String {
        let devices = entries.keys.sorted().map { id -> String in
            let entry = entries[id]
            return "\(id)=\(entry?.lastPercent ?? -1)/\(entry?.device.percent ?? -1)/\(entry?.device.name ?? "")"
        }
        return devices.joined(separator: "|") + "#" + alerted.sorted().joined(separator: ",")
    }

    static func decode(_ data: Data?) -> BatteriesRegistry {
        guard let data, let registry = try? JSONDecoder().decode(BatteriesRegistry.self, from: data) else {
            return BatteriesRegistry()
        }
        var cleaned = registry
        // Never kept, whatever an older file holds.
        cleaned.entries = cleaned.entries.filter { !BatteriesMerge.isProximityOnly($0.key) }
        return cleaned
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
}

// MARK: - Low battery

enum BatteriesAlerts {
    /// Edge-triggered, as in the droplet: a device alerts once when it drops
    /// to the threshold or below, and again only after it climbs back to
    /// threshold + 5. Never while charging; a muted device is marked as
    /// alerted without a word, so turning it on later stays quiet until it
    /// recovers. Several devices going low in one scan make one alert, the
    /// lowest first, the rest named in `others`.
    static func evaluate(_ devices: [BatteryDevice], threshold: Int, muted: Set<String>,
                         alerted: inout Set<String>, id: UUID = UUID()) -> BatteriesLowAlert? {
        var newlyLow: [(device: BatteryDevice, percent: Int)] = []
        for device in devices where device.isReachable {
            guard let percent = device.percent else { continue }
            if percent >= threshold + BatteriesDefaults.rearmMargin {
                alerted.remove(device.id)
                continue
            }
            guard percent <= threshold, !device.isCharging, !alerted.contains(device.id) else { continue }
            alerted.insert(device.id)
            if !muted.contains(device.id) { newlyLow.append((device, percent)) }
        }
        let ranked = newlyLow.enumerated().sorted {
            $0.element.percent != $1.element.percent ? $0.element.percent < $1.element.percent : $0.offset < $1.offset
        }.map(\.element)
        guard let lead = ranked.first else { return nil }
        return BatteriesLowAlert(id: id, device: lead.device, percent: lead.percent,
                                 others: ranked.dropFirst().map(\.device.name))
    }
}

// MARK: - Schedule

enum BatteriesSchedule {
    /// Every `refreshMinutes` while the page or widget is on screen; every
    /// five minutes while it is not, only when some device can alert;
    /// nothing at all when Batteries is off.
    static func interval(enabled: Bool, visible: Bool, refreshMinutes: Int, canAlert: Bool) -> TimeInterval? {
        guard enabled else { return nil }
        if visible { return TimeInterval(refreshMinutes * 60) }
        return canAlert ? TimeInterval(BatteriesDefaults.hiddenRefreshMinutes * 60) : nil
    }

    static func canAlert(_ devices: [BatteryDevice], muted: Set<String>) -> Bool {
        devices.contains { !muted.contains($0.id) }
    }

    /// A restarted schedule waits out the rest of its interval, so hiding
    /// the page never triggers a scan nobody sees.
    static func delay(interval: TimeInterval, lastScanAt: Date?, now: Date) -> TimeInterval {
        guard let lastScanAt else { return 0 }
        return max(0, interval - now.timeIntervalSince(lastScanAt))
    }

    /// The page opening asks for a scan only when the last one is older than this.
    static let freshEnough: TimeInterval = 10
}
