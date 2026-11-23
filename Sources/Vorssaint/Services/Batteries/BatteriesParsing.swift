// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import Foundation

/// Zenith fork: what the Batteries readers get back, turned into
/// `BatteryDevice` values. Everything here is pure (data in, values out) so
/// it can be tested without devices, processes or Bluetooth.

// MARK: - Bluetooth (system_profiler)

/// Battery levels of paired Bluetooth devices from
/// `system_profiler SPBluetoothDataType -json`: AirPods, Magic accessories,
/// third-party headphones, controllers, and iPhone/iPad/Watch over
/// Continuity.
enum BatteriesBluetooth {
    static let idPrefix = "bt-"

    /// What one system_profiler pass reports.
    struct Report: Equatable {
        /// The devices to list: every connected one, and Continuity devices
        /// (iPhone, iPad, Watch) even when not connected.
        var devices: [BatteryDevice] = []
        /// The lowercased name of every device paired with this Mac,
        /// connected or not, so nearby AirPods are matched against the
        /// user's own only.
        var pairedNames: Set<String> = []
        /// Accessories listed as not connected. One that macOS holds a live
        /// level for is connected after all, and this is its name and kind.
        var notConnected: [BatteryDevice] = []
    }

    static func report(from data: Data) -> Report {
        guard !data.isEmpty,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [Any] else {
            return Report()
        }
        var report = Report()
        for case let section as [String: Any] in sections {
            for (name, props) in entries(section["device_connected"]) {
                report.pairedNames.insert(name.lowercased())
                if let device = parse(name: name, props: props) { report.devices.append(device) }
            }
            // Continuity only reports a level now and then, so the device
            // appears as "—" rather than vanishing. Other not-connected
            // accessories stay out, or every device ever paired would show.
            for (name, props) in entries(section["device_not_connected"]) {
                report.pairedNames.insert(name.lowercased())
                guard let device = parse(name: name, props: props) else { continue }
                if isContinuityDevice(device.kind) {
                    report.devices.append(device)
                } else {
                    report.notConnected.append(device)
                }
            }
        }
        return report
    }

    private static func entries(_ value: Any?) -> [(String, [String: Any])] {
        guard let list = value as? [Any] else { return [] }
        var result: [(String, [String: Any])] = []
        for case let entry as [String: Any] in list {
            // One name per dictionary; sorted so a malformed entry with more
            // reads the same way every time.
            for name in entry.keys.sorted() {
                if let props = entry[name] as? [String: Any] { result.append((name, props)) }
            }
        }
        return result
    }

    static func isContinuityDevice(_ kind: BatteryDeviceKind) -> Bool {
        kind == .iphone || kind == .ipad || kind == .watch
    }

    /// The Bluetooth address a device was listed under, if it had one.
    static func address(of device: BatteryDevice) -> String? {
        guard device.id.hasPrefix(idPrefix) else { return nil }
        return BatteriesAddress.normalized(String(device.id.dropFirst(idPrefix.count)))
    }

    static func parse(name: String, props: [String: Any]) -> BatteryDevice? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // A connected device is never at 0%: a 0 for its one battery is a
        // level it has not given, so it reads as unknown, not as empty.
        let main = percentValue(props["device_batteryLevelMain"]).flatMap { $0 > 0 ? $0 : nil }
        let left = percentValue(props["device_batteryLevelLeft"])
        let right = percentValue(props["device_batteryLevelRight"])
        let caseLevel = percentValue(props["device_batteryLevelCase"])
        let productID = productIDValue(props["device_productID"], vendor: props["device_vendorID"])

        let percent: Int?
        var components: [BatteryDevice.Component] = []
        if BatteriesSingleCellAudio.isSingleCell(productID: productID, name: trimmed) {
            // AirPods Max and the like have one battery: one ring, never a
            // left, a right or a case, whatever else the listing carries.
            percent = main ?? [left, right].compactMap { $0 }.filter { $0 > 0 }.max()
        } else {
            // AirPods are one entry: the lowest bud, then the case.
            let budsMin = [left, right].compactMap { $0 }.min()
            percent = main ?? budsMin ?? caseLevel
            if let left { components.append(.init(label: "Left", percent: left)) }
            if let right { components.append(.init(label: "Right", percent: right)) }
            if let caseLevel { components.append(.init(label: "Case", percent: caseLevel)) }
        }

        let address = (props["device_address"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? trimmed
        return BatteryDevice(
            id: idPrefix + address,
            name: trimmed,
            kind: kind(name: trimmed, minorType: props["device_minorType"] as? String),
            source: .bluetooth,
            percent: percent,
            // Only earbuds with separate cells have components.
            components: components.count > 1 ? components : [],
            productID: productID,
            vendorID: identifierValue(props["device_vendorID"])
        )
    }

    /// "0x200A" from an Apple accessory (vendor 0x004C); nil for any other
    /// maker, whose product ids mean something else.
    static func productIDValue(_ raw: Any?, vendor: Any?) -> Int? {
        guard identifierValue(vendor) == 0x004C else { return nil }
        return identifierValue(raw)
    }

    /// system_profiler reports device identifiers as hex strings or numbers.
    static func identifierValue(_ raw: Any?) -> Int? {
        if let number = raw as? NSNumber { return number.intValue }
        guard var text = (raw as? String)?.trimmingCharacters(in: .whitespaces).lowercased() else { return nil }
        if text.hasPrefix("0x") { text.removeFirst(2) }
        return Int(text, radix: 16)
    }

    /// "37%", Dutch "37 %" (a no-break space before the sign), "٣٧٪": the
    /// whole number before any percent sign, read digit by digit so any
    /// script's digits count and a decimal part ("37,5 %") is dropped.
    static func percentValue(_ raw: Any?) -> Int? {
        if let number = raw as? NSNumber {
            let value = number.intValue
            return (0...100).contains(value) ? value : nil
        }
        guard let text = raw as? String else { return nil }
        let percentSigns: Set<Character> = ["%", "\u{066A}", "\u{FF05}", "\u{FE6A}"]
        let head = text.split(whereSeparator: { percentSigns.contains($0) }).first ?? Substring(text)
        var value = 0
        var sawDigit = false
        for character in head {
            if character.isNumber, let digit = character.wholeNumberValue, (0...9).contains(digit) {
                value = value * 10 + digit
                sawDigit = true
                if value > 100 { return nil }
            } else if sawDigit {
                break
            }
        }
        return sawDigit ? value : nil
    }

    /// The minor type first, then the name, English first, then the words
    /// a renamed accessory carries in other languages ("Harry de Muis").
    static func kind(name: String, minorType: String?) -> BatteryDeviceKind {
        let haystack = ((minorType ?? "") + " " + name).lowercased()
        if haystack.contains("iphone") || haystack.contains("smartphone")
            || haystack.contains("cellphone") {
            return .iphone
        }
        if haystack.contains("ipad") || haystack.contains("tablet") { return .ipad }
        if haystack.contains("watch") { return .watch }
        if haystack.contains("airpods") || haystack.contains("headphone")
            || haystack.contains("headset") || haystack.contains("earbud") {
            return .headphones
        }
        if ["keyboard", "toetsenbord", "tastatur", "clavier", "teclado", "tastiera", "klawiatura"]
            .contains(where: { haystack.contains($0) }) { return .keyboard }
        if ["mouse", "muis", "maus", "souris", "ratón", "raton", "mysz"]
            .contains(where: { haystack.contains($0) }) { return .mouse }
        if haystack.contains("trackpad") { return .trackpad }
        if haystack.contains("speaker") { return .speaker }
        if haystack.contains("gamepad") || haystack.contains("controller") { return .gamepad }
        return .other
    }
}

/// Bluetooth addresses in every spelling the readers meet.
enum BatteriesAddress {
    /// "AA:BB:CC:DD:EE:FF", "aa-bb-cc-dd-ee-ff" and a bare serial all become
    /// lowercase hex; anything without six bytes of it is not an address.
    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let hex = raw.lowercased().filter { $0.isHexDigit && $0.isASCII }
        return hex.count >= 12 ? hex : nil
    }

    /// Exactly six bytes: an accessory identifier that is a longer id (a
    /// UUID) is not an address, and is matched by name instead.
    static func exact(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let hex = raw.lowercased().filter { $0.isHexDigit && $0.isASCII }
        return hex.count == 12 ? hex : nil
    }
}

// MARK: - AirPods

/// The AirPods models with a symbol of their own, by product id first (a
/// renamed pair keeps it), then by name.
enum BatteriesAirPodsModel: Equatable {
    case airPods, airPods3, airPods4, pro, max

    init?(productID: Int?, name: String) {
        switch productID {
        case 0x2002, 0x200F: self = .airPods
        case 0x2013: self = .airPods3
        case 0x2019, 0x201B: self = .airPods4
        case 0x200E, 0x2014, 0x2024, 0x2027: self = .pro
        case 0x200A, 0x201F: self = .max
        default:
            let lowered = name.lowercased()
            guard lowered.contains("airpods") else { return nil }
            if lowered.contains("airpods max") {
                self = .max
            } else if lowered.contains("airpods pro") {
                self = .pro
            } else {
                self = .airPods
            }
        }
    }

    /// Newer spellings before older ones; the first this macOS draws wins.
    var symbolCandidates: [String] {
        switch self {
        case .airPods: return ["airpods"]
        case .airPods3: return ["airpods.gen3", "airpods"]
        case .airPods4: return ["airpods.gen4", "airpods.gen3", "airpods"]
        case .pro: return ["airpods.pro", "airpodspro"]
        case .max: return ["airpods.max", "airpodsmax"]
        }
    }
}

/// Apple Bluetooth audio with one battery and no case: AirPods Max and the
/// over-ear and neckband Beats. They report one level, never a left and a right.
enum BatteriesSingleCellAudio {
    static let productIDs: Set<Int> = [
        0x200A, 0x201F,                 // AirPods Max, AirPods Max (USB-C)
        0x2006, 0x200C, 0x2025,         // Beats Solo3, Solo Pro, Solo 4
        0x2009, 0x2017,                 // Beats Studio3, Studio Pro
        0x2003, 0x2005, 0x200D, 0x2010, // Powerbeats3, BeatsX, Powerbeats 4, Beats Flex
    ]

    static func isSingleCell(productID: Int?, name: String) -> Bool {
        if let productID, productIDs.contains(productID) { return true }
        return name.lowercased().contains("airpods max")
    }
}

/// Battery and charging state decoded from an AirPods proximity broadcast.
struct BatteriesAirPodsBattery: Equatable {
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var leftCharging = false
    var rightCharging = false
    var caseCharging = false
    /// Apple model identifier (0x2019 = AirPods 4).
    var model: UInt16
    /// The one battery of a single-cell model; left, right and case are nil.
    var single: Int?
    var singleCharging = false

    var level: Int? { single ?? [left, right].compactMap { $0 }.min() }
    var isCharging: Bool { singleCharging || leftCharging || rightCharging }

    var components: [BatteryDevice.Component] {
        var components: [BatteryDevice.Component] = []
        if let left { components.append(.init(label: "Left", percent: left)) }
        if let right { components.append(.init(label: "Right", percent: right)) }
        if let caseLevel { components.append(.init(label: "Case", percent: caseLevel)) }
        return components.count > 1 ? components : []
    }
}

/// Apple's reverse-engineered "proximity pairing" advertisement
/// (manufacturer-data type 0x07), which AirPods broadcast when the case is
/// opened. Undocumented, so anything unexpected decodes to nil.
enum BatteriesAirPodsProximity {
    /// `data` is the raw manufacturer data including the little-endian
    /// Apple company id (4C 00).
    static func decode(manufacturerData data: Data) -> BatteriesAirPodsBattery? {
        let bytes = [UInt8](data)
        guard bytes.count >= 10, bytes[0] == 0x4C, bytes[1] == 0x00, bytes[2] == 0x07 else { return nil }
        let model = (UInt16(bytes[6]) << 8) | UInt16(bytes[5])
        // Bit 1 of byte 7's high nibble says which pod is primary.
        let flipped = ((bytes[7] >> 4) & 0x02) == 0
        let podHigh = Int(bytes[8] >> 4)
        let podLow = Int(bytes[8] & 0x0F)
        let caseNibble = Int(bytes[9] & 0x0F)
        let chargeBits = bytes[9] >> 4

        func level(_ nibble: Int) -> Int? {
            nibble == 15 ? nil : min(nibble, 10) * 10 // 0xF = absent
        }

        // A single-cell model sends its one battery in the low pod nibble
        // and its charging state in bit 0; nothing else is a battery.
        if BatteriesSingleCellAudio.productIDs.contains(Int(model)) {
            return BatteriesAirPodsBattery(model: model, single: level(podLow),
                                           singleCharging: (chargeBits & 0x01) != 0)
        }
        return BatteriesAirPodsBattery(
            left: level(flipped ? podHigh : podLow),
            right: level(flipped ? podLow : podHigh),
            caseLevel: level(caseNibble),
            // Charging nibble: bit 0 right pod, bit 1 left pod, bit 2 case.
            leftCharging: (chargeBits & 0x02) != 0,
            rightCharging: (chargeBits & 0x01) != 0,
            caseCharging: (chargeBits & 0x04) != 0,
            model: model
        )
    }
}

/// One AirPods broadcast as last heard, by advertised name. Never saved.
struct BatteriesAirPodsSighting: Equatable {
    var battery: BatteriesAirPodsBattery
    var date: Date
    var rssi: Int
}

// MARK: - IORegistry accessories

/// A level macOS itself holds for a connected accessory (`BatteryPercent`
/// on Apple's device management service and on HID devices).
struct BatteriesAccessoryReading: Equatable {
    /// Lowercase hex digits only.
    var address: String?
    var name: String?
    var level: Int
    var kind: BatteryDeviceKind?
    var vendorID: Int?

    /// HID usage, which no locale renames.
    static func kind(usagePage: Int?, usage: Int?) -> BatteryDeviceKind? {
        switch (usagePage, usage) {
        case (0x01, 0x02): return .mouse
        case (0x01, 0x06): return .keyboard
        case (0x0D, 0x05): return .trackpad
        default: return nil
        }
    }

    /// The reading for this device: its address first, then its name among
    /// readings that name no address, an exact name or the only close one,
    /// so two mice never trade levels.
    static func reading(address: String?, name: String, in readings: [BatteriesAccessoryReading]) -> BatteriesAccessoryReading? {
        if let address = BatteriesAddress.normalized(address),
           let match = readings.first(where: { $0.address == address }) {
            return match
        }
        return BatteriesNameMatch.best(name, in: readings.filter { $0.address == nil }, name: \.name)
    }

    /// The paired device a reading belongs to, by address, then by name.
    static func paired(for reading: BatteriesAccessoryReading, in devices: [BatteryDevice]) -> BatteryDevice? {
        if let address = reading.address,
           let match = devices.first(where: { BatteriesBluetooth.address(of: $0) == address }) {
            return match
        }
        guard reading.address == nil, let name = reading.name?.lowercased() else { return nil }
        return devices.first { $0.name.lowercased() == name }
    }
}

// MARK: - Accessory power sources

/// An accessory power source: what `pmset -g accps` prints and macOS's own
/// battery list shows. One-battery headphones (AirPods Max, many others)
/// have their level here when system_profiler gives none.
struct BatteriesPowerSourceReading: Equatable {
    /// Twelve lowercase hex digits when the source names a Bluetooth address.
    var address: String?
    var name: String?
    var productID: Int?
    var vendorID: Int?
    var level: Int
    var isCharging: Bool
    /// "Accessory Category", e.g. "Headphone".
    var category: String?

    /// One power source description, or nil when it is not an accessory or
    /// its numbers do not add up (any process can publish a power source).
    static func reading(from info: [String: Any]) -> BatteriesPowerSourceReading? {
        let transport = info["Transport Type"] as? String
        let isAccessory = info["Accessory Identifier"] != nil
            || info["Accessory Category"] != nil
            || transport?.hasPrefix("Bluetooth") == true
            || (info["Type"] as? String) == "Accessory Source"
        guard isAccessory, let current = (info["Current Capacity"] as? NSNumber)?.intValue else { return nil }
        let maximum = (info["Max Capacity"] as? NSNumber)?.intValue ?? 100
        guard current >= 0, maximum > 0, current <= maximum else { return nil }
        let level = Int((Double(current) / Double(maximum) * 100).rounded())
        // A connected accessory is not at 0%: a 0 is a level it has not given.
        guard (1...100).contains(level) else { return nil }
        return BatteriesPowerSourceReading(
            address: BatteriesAddress.exact(info["Accessory Identifier"] as? String),
            name: (info["Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            productID: (info["Product ID"] as? NSNumber)?.intValue,
            vendorID: (info["Vendor ID"] as? NSNumber)?.intValue,
            level: level,
            isCharging: (info["Is Charging"] as? NSNumber)?.boolValue ?? false,
            category: info["Accessory Category"] as? String
        )
    }

    /// When both product ids are known they must agree, so one headset's
    /// level never lands on another device that shares its name.
    func fits(productID deviceProductID: Int?) -> Bool {
        guard let deviceProductID, let productID else { return true }
        if let vendorID, vendorID != 0x004C { return false }
        return productID == deviceProductID
    }

    var kind: BatteryDeviceKind {
        let category = (category ?? "").lowercased()
        if category.contains("headphone") || category.contains("headset") || category.contains("audio") {
            return .headphones
        }
        if category.contains("keyboard") { return .keyboard }
        if category.contains("mouse") { return .mouse }
        if category.contains("trackpad") { return .trackpad }
        if category.contains("game") { return .gamepad }
        if category.contains("speaker") { return .speaker }
        return BatteriesBluetooth.kind(name: name ?? "", minorType: nil)
    }

    /// The source for this device: its address first, then its name among
    /// sources that name no address. A source whose product id disagrees
    /// with the device's is never its source.
    static func reading(address: String?, name: String, productID: Int?,
                        in readings: [BatteriesPowerSourceReading]) -> BatteriesPowerSourceReading? {
        let candidates = readings.filter { $0.fits(productID: productID) }
        if let address = BatteriesAddress.exact(address),
           let match = candidates.first(where: { $0.address == address }) {
            return match
        }
        return BatteriesNameMatch.best(name, in: candidates.filter { $0.address == nil }, name: \.name)
    }
}

/// An exact name, or the only close one.
enum BatteriesNameMatch {
    static func best<T>(_ name: String, in candidates: [T], name key: (T) -> String?) -> T? {
        let wanted = BatteriesNames.key(name)
        guard !wanted.isEmpty else { return nil }
        if let exact = candidates.first(where: { key($0).map(BatteriesNames.key) == wanted }) { return exact }
        let close = candidates.filter {
            guard let other = key($0).map(BatteriesNames.key), !other.isEmpty else { return false }
            return other.contains(wanted) || wanted.contains(other)
        }
        return close.count == 1 ? close.first : nil
    }
}

enum BatteriesNames {
    /// Bluetooth and lockdownd disagree on the apostrophe in "Faiz’s iPhone"
    /// and on the space in "Apple Watch" (a no-break space over Bluetooth).
    static func key(_ name: String) -> String {
        name.replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

// MARK: - iPhone and iPad (libimobiledevice tools)

enum BatteriesIOS {
    static let idPrefix = "ios-"

    struct Listed: Equatable, Sendable {
        var udid: String
        var network: Bool
    }

    /// `idevice_id -l` prints one UDID per line; `-n` the same for network
    /// devices. Newer versions add " (USB)" or " (Network)".
    static func listed(usbOutput: String, networkOutput: String) -> [Listed] {
        var seen = Set<String>()
        var result: [Listed] = []
        for (output, network) in [(usbOutput, false), (networkOutput, true)] {
            for line in output.split(whereSeparator: \.isNewline) {
                guard let udid = udid(from: line), seen.insert(udid).inserted else { continue }
                result.append(Listed(udid: udid, network: network))
            }
        }
        return result
    }

    static func udid(from line: Substring) -> String? {
        guard let token = line.split(separator: " ").first.map(String.init) else { return nil }
        // UDIDs are hex with dashes; anything else is an error message.
        let allowed = token.allSatisfy { ($0.isHexDigit && $0.isASCII) || $0 == "-" }
        return allowed && token.count >= 20 ? token : nil
    }

    /// ideviceinfo prints "Key: Value" per line; values can contain colons,
    /// so only the first colon splits key from value.
    static func infoOutput(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { result[key] = value }
        }
        return result
    }

    /// `ideviceinfo -k Key` prints the bare value.
    static func singleValue(_ output: String?) -> String? {
        guard let value = output?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty,
              !value.contains("\n"), !value.lowercased().hasPrefix("error") else { return nil }
        return value
    }

    static func kind(productType: String?, name: String) -> BatteryDeviceKind {
        let type = (productType ?? "").lowercased()
        if type.hasPrefix("ipad") { return .ipad }
        if type.hasPrefix("iphone") || type.hasPrefix("ipod") { return .iphone }
        return BatteriesBluetooth.kind(name: name, minorType: nil) == .ipad ? .ipad : .iphone
    }

    /// The device, or nil when the battery domain gave no level (a locked
    /// or untrusted device); the registry then shows its last known one.
    static func device(udid: String, network: Bool, battery: [String: String],
                       name: String?, productType: String?) -> BatteryDevice? {
        guard let text = battery["BatteryCurrentCapacity"], let percent = Int(text),
              (0...100).contains(percent) else { return nil }
        let fallback = productType?.lowercased().hasPrefix("ipad") == true ? "iPad" : "iPhone"
        let shownName = name.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        return BatteryDevice(
            id: idPrefix + udid,
            name: shownName,
            kind: kind(productType: productType, name: shownName),
            source: network ? .wifi : .usb,
            percent: percent,
            isCharging: battery["BatteryIsCharging"]?.lowercased() == "true",
            fullyCharged: battery["FullyCharged"]?.lowercased() == "true"
        )
    }
}

// MARK: - Apple Watch through its iPhone (companion proxy)

enum BatteriesWatchValue: Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)

    var intValue: Int? {
        switch self {
        case let .int(value): return value
        case let .string(text): return Int(text)
        case .bool: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case let .bool(value): return value
        case let .int(value): return value != 0
        case let .string(text): return ["true", "1", "yes"].contains(text.lowercased())
        }
    }

    var stringValue: String? {
        if case let .string(text) = self { return text }
        return nil
    }
}

enum BatteriesWatchReply: Equatable {
    case value(BatteriesWatchValue)
    /// The watch link was asleep; asking again usually answers.
    case timeout
    case unsupported
    case failed(String)
}

enum BatteriesWatch {
    static let idPrefix = "watch-"
    /// Read from the watch itself on each request; the first one after a
    /// while often times out while the link wakes.
    static let liveKeys = ["BatteryCurrentCapacity", "BatteryIsCharging"]
    /// Cached by the iPhone, quick.
    static let identityKeys = ["DeviceName", "ProductType"]

    /// `companion_proxy_get_device_registry`'s array of watch UDIDs, as XML.
    static func registryUDIDs(fromXML data: Data) -> [String] {
        guard let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return [] }
        let list = (root as? [Any]) ?? ((root as? [String: Any])?["PairedDevicesArray"] as? [Any]) ?? []
        return list.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A `GetValueFromRegistry` reply, as XML.
    static func reply(fromXML data: Data, key: String) -> BatteriesWatchReply {
        guard let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: Any] else { return .failed("unreadable") }
        if let values = root["RetrievedValueDictionary"] as? [String: Any], let raw = values[key] {
            if let value = value(raw) { return .value(value) }
            return .failed("unexpected value")
        }
        switch root["Error"] as? String {
        case "TimeoutReply": return .timeout
        case "UnsupportedWatchKey": return .unsupported
        case let error?: return .failed(error)
        case nil: return .failed("no value")
        }
    }

    static func value(_ raw: Any) -> BatteriesWatchValue? {
        if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .int(number.intValue)
        }
        if let text = raw as? String { return .string(text) }
        return nil
    }

    static func device(udid: String, name: String?, capacity: Int?, charging: Bool?) -> BatteryDevice? {
        guard let capacity, (0...100).contains(capacity) else { return nil }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return BatteryDevice(
            id: idPrefix + udid,
            name: (trimmed?.isEmpty == false ? trimmed : nil) ?? "Apple Watch",
            kind: .watch,
            source: .viaIPhone,
            percent: capacity,
            isCharging: charging ?? false,
            fullyCharged: capacity >= 100 && charging == true
        )
    }
}

// MARK: - Symbols

enum BatteriesSymbols {
    /// The exact symbol for a device, nil for its kind's generic one: Apple
    /// mice draw a Magic Mouse, AirPods their own model.
    static func override(for device: BatteryDevice, isAvailable: (String) -> Bool) -> String? {
        switch device.kind {
        case .mouse:
            // Apple uses 0x004C over Bluetooth and 0x05AC over USB/HID. Without
            // a vendor, a product id was already gated to Apple by the parser.
            let isApple = device.vendorID.map { $0 == 0x004C || $0 == 0x05AC } ?? (device.productID != nil)
            return isApple && isAvailable("magicmouse") ? "magicmouse" : nil
        case .headphones:
            guard let model = BatteriesAirPodsModel(productID: device.productID, name: device.name) else { return nil }
            return model.symbolCandidates.first(where: isAvailable)
        default:
            return nil
        }
    }
}
