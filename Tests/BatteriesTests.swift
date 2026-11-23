// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Batteries' readers and rules on fixed inputs: the
/// system_profiler JSON, ideviceinfo's output, the companion proxy's
/// replies, kind detection, AirPods as one entry, how one scan's sources
/// combine, display order, the low-battery alert, the last-known registry
/// and its expiry, the schedule and the preferences. No devices, processes,
/// Bluetooth or network.
enum BatteriesTests {
    static func run(_ suite: TestSuite) {
        bluetoothReport(suite)
        percentValues(suite)
        kinds(suite)
        iOSOutput(suite)
        watchReplies(suite)
        powerSources(suite)
        proximity(suite)
        combine(suite)
        ordering(suite)
        alerts(suite)
        registry(suite)
        schedule(suite)
        preferences(suite)
        symbols(suite)
    }

    private static let suiteName = "com.vorssaint.tests.batteries"
    private static let now = Date(timeIntervalSince1970: 1_795_000_000)

    private static func device(_ id: String, _ name: String, _ kind: BatteryDeviceKind = .other,
                               source: BatterySource = .bluetooth, percent: Int?, charging: Bool = false,
                               unreachableSince: Date? = nil) -> BatteryDevice {
        BatteryDevice(id: id, name: name, kind: kind, source: source, percent: percent,
                      isCharging: charging, unreachableSince: unreachableSince)
    }

    // MARK: Fixtures

    private static let profilerJSON = """
    {
      "SPBluetoothDataType" : [
        {
          "controller_properties" : { "controller_address" : "AA:BB:CC:DD:EE:00" },
          "device_connected" : [
            { "Faiz’s AirPods Pro" : {
                "device_address" : "11:22:33:44:55:66",
                "device_batteryLevelCase" : "62%",
                "device_batteryLevelLeft" : "80%",
                "device_batteryLevelRight" : "74%",
                "device_minorType" : "Headphones",
                "device_productID" : "0x2014",
                "device_vendorID" : "0x004C" } },
            { "Magic Mouse" : {
                "device_address" : "22:33:44:55:66:77",
                "device_batteryLevelMain" : "45%",
                "device_minorType" : "Mouse",
                "device_productID" : "0x0269",
                "device_vendorID" : "0x004C" } },
            { "MX Master 3S" : {
                "device_address" : "33:44:55:66:77:88",
                "device_batteryLevelMain" : "0%",
                "device_minorType" : "Mouse",
                "device_vendorID" : "0x046D" } },
            { "AirPods Max" : {
                "device_address" : "44:55:66:77:88:99",
                "device_batteryLevelLeft" : "0%",
                "device_batteryLevelRight" : "55%",
                "device_batteryLevelCase" : "0%",
                "device_productID" : "0x200A",
                "device_vendorID" : "0x004C" } },
            { "soundcore Liberty 4 NC" : {
                "device_address" : "E8:EE:CC:E0:A7:8E",
                "device_minorType" : "Headset" } }
          ],
          "device_not_connected" : [
            { "Faiz’s Apple\\u00a0Watch" : { "device_address" : "10:CE:E9:66:19:9D" } },
            { "Faiz’s iPhone" : { "device_address" : "AC:00:7A:08:A0:7B", "device_minorType" : "Smartphone" } },
            { "Maxfit61 5.0" : { "device_address" : "F4:EE:25:00:27:86", "device_minorType" : "Keyboard" } },
            { "Xbox Wireless Controller" : {
                "device_address" : "98:B6:EA:48:43:11",
                "device_minorType" : "Gamepad",
                "device_productID" : "0x02FD",
                "device_vendorID" : "0x045E" } }
          ]
        }
      ]
    }
    """

    private static var report: BatteriesBluetooth.Report {
        BatteriesBluetooth.report(from: Data(profilerJSON.utf8))
    }

    // MARK: Bluetooth

    private static func bluetoothReport(_ suite: TestSuite) {
        let report = self.report
        let byName = Dictionary(report.devices.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        let airPods = byName["Faiz’s AirPods Pro"]
        suite.expect(airPods?.percent == 74, "AirPods are one entry at the lowest bud")
        suite.expect(airPods?.components.map(\.label) == ["Left", "Right", "Case"]
                     && airPods?.components.map(\.percent) == [80, 74, 62], "AirPods keep left, right and case")
        suite.expect(airPods?.kind == .headphones && airPods?.productID == 0x2014, "AirPods kind and Apple product id")
        suite.expect(airPods?.id == "bt-11:22:33:44:55:66" && airPods?.source == .bluetooth, "AirPods id and source")

        suite.expect(byName["Magic Mouse"]?.percent == 45 && byName["Magic Mouse"]?.kind == .mouse
                     && byName["Magic Mouse"]?.vendorID == 0x004C, "a Magic Mouse reads its main level")
        suite.expect(byName["MX Master 3S"] != nil && byName["MX Master 3S"]?.percent == nil,
                     "a connected device at 0% is listed without a level")
        suite.expect(byName["MX Master 3S"]?.productID == nil, "a non-Apple product id is not kept")

        let max = byName["AirPods Max"]
        suite.expect(max?.percent == 55 && max?.components.isEmpty == true,
                     "AirPods Max are one cell: no left, right or case, and a 0 is never its level")

        suite.expect(byName["soundcore Liberty 4 NC"]?.percent == nil
                     && byName["soundcore Liberty 4 NC"]?.kind == .headphones, "a headset without a level is listed")

        let watch = report.devices.first { $0.kind == .watch }
        suite.expect(watch != nil && watch?.percent == nil, "a watch not connected is still listed")
        suite.expect(byName["Faiz’s iPhone"]?.kind == .iphone, "an iPhone not connected is still listed")
        suite.expect(byName["Maxfit61 5.0"] == nil && byName["Xbox Wireless Controller"] == nil,
                     "other devices not connected stay out")
        suite.expect(report.notConnected.map(\.name).sorted() == ["Maxfit61 5.0", "Xbox Wireless Controller"],
                     "devices not connected are kept for a live level elsewhere")
        suite.expect(report.pairedNames.contains("maxfit61 5.0") && report.pairedNames.contains("faiz’s airpods pro"),
                     "every paired name is known, connected or not")
        suite.expect(BatteriesBluetooth.address(of: byName["Magic Mouse"]!) == "223344556677",
                     "the address normalizes to hex")

        suite.expect(BatteriesBluetooth.report(from: Data()).devices.isEmpty
                     && BatteriesBluetooth.report(from: Data("not json".utf8)).devices.isEmpty,
                     "unreadable output reports nothing")
    }

    private static func percentValues(_ suite: TestSuite) {
        suite.expect(BatteriesBluetooth.percentValue("37%") == 37, "37%")
        suite.expect(BatteriesBluetooth.percentValue("37\u{00A0}%") == 37, "a no-break space before the sign")
        suite.expect(BatteriesBluetooth.percentValue("37,5 %") == 37, "a decimal part is dropped")
        suite.expect(BatteriesBluetooth.percentValue("٣٧٪") == 37, "Arabic digits and sign")
        suite.expect(BatteriesBluetooth.percentValue("140%") == nil, "past 100 is no level")
        suite.expect(BatteriesBluetooth.percentValue(NSNumber(value: 64)) == 64, "a number")
        suite.expect(BatteriesBluetooth.percentValue("n/a") == nil, "no digits")
        suite.expect(BatteriesBluetooth.identifierValue("0x200A") == 0x200A
                     && BatteriesBluetooth.identifierValue(NSNumber(value: 76)) == 76, "identifiers as hex or numbers")
    }

    private static func kinds(_ suite: TestSuite) {
        let cases: [(String, String?, BatteryDeviceKind)] = [
            ("Faiz’s iPhone", nil, .iphone),
            ("Phone", "Smartphone", .iphone),
            ("iPad Pro", nil, .ipad),
            ("Faiz’s Apple\u{00A0}Watch", nil, .watch),
            ("Faiz’s AirPods", nil, .headphones),
            ("soundcore Liberty 4 NC", "Headset", .headphones),
            ("Harry de Muis", nil, .mouse),
            ("Logitech Tastatur", nil, .keyboard),
            ("Clavier de Léa", nil, .keyboard),
            ("Maxfit61 5.0", "Keyboard", .keyboard),
            ("Magic Trackpad", nil, .trackpad),
            ("JBL Flip 6", "Speaker", .speaker),
            ("Xbox Wireless Controller", "Gamepad", .gamepad),
            ("Mystery Box", nil, .other),
        ]
        for (name, minor, expected) in cases {
            let kind = BatteriesBluetooth.kind(name: name, minorType: minor)
            suite.expect(kind == expected, "kind of \(name): got \(kind), expected \(expected)")
        }
    }

    // MARK: iPhone and iPad

    private static func iOSOutput(_ suite: TestSuite) {
        let listed = BatteriesIOS.listed(
            usbOutput: "00008110-001A2B3C4D5E801E\n",
            networkOutput: "00008110-001A2B3C4D5E801E (Network)\n00008030-000A11B22C33D44E (Network)\nERROR: no device\n")
        suite.expect(listed == [.init(udid: "00008110-001A2B3C4D5E801E", network: false),
                                .init(udid: "00008030-000A11B22C33D44E", network: true)],
                     "USB first, the same device once, error lines ignored")

        let battery = BatteriesIOS.infoOutput("""
        BatteryCurrentCapacity: 45
        BatteryIsCharging: true
        ExternalChargeCapable: true
        FullyCharged: false
        Note: a value: with colons
        """)
        suite.expect(battery["BatteryCurrentCapacity"] == "45" && battery["Note"] == "a value: with colons",
                     "only the first colon splits key and value")
        let phone = BatteriesIOS.device(udid: "00008110-001A2B3C4D5E801E", network: false, battery: battery,
                                        name: "paiz", productType: "iPhone14,3")
        suite.expect(phone?.percent == 45 && phone?.isCharging == true && phone?.fullyCharged == false,
                     "the battery domain gives level and charging")
        suite.expect(phone?.id == "ios-00008110-001A2B3C4D5E801E" && phone?.kind == .iphone && phone?.source == .usb
                     && phone?.name == "paiz", "an iPhone over USB")
        let pad = BatteriesIOS.device(udid: "x", network: true, battery: ["BatteryCurrentCapacity": "80"],
                                      name: nil, productType: "iPad13,4")
        suite.expect(pad?.kind == .ipad && pad?.source == .wifi && pad?.name == "iPad", "an iPad over the network")
        suite.expect(BatteriesIOS.device(udid: "x", network: false, battery: ["BatteryIsCharging": "false"],
                                         name: "Locked", productType: nil) == nil,
                     "a locked device without a level is left to the registry")
        suite.expect(BatteriesIOS.singleValue("Faiz’s iPhone\n") == "Faiz’s iPhone", "a bare value")
        suite.expect(BatteriesIOS.singleValue("ERROR: Could not connect to lockdownd") == nil
                     && BatteriesIOS.singleValue("") == nil, "an error is no value")
    }

    // MARK: Apple Watch replies

    private static func plist(_ body: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">\(body)</plist>
        """.utf8)
    }

    private static func watchReplies(_ suite: TestSuite) {
        let registry = plist("<array><string>00008301-AAAABBBBCCCCDDDD</string><string> </string></array>")
        suite.expect(BatteriesWatch.registryUDIDs(fromXML: registry) == ["00008301-AAAABBBBCCCCDDDD"],
                     "the device registry lists watch UDIDs")

        let capacity = plist("<dict><key>RetrievedValueDictionary</key><dict><key>BatteryCurrentCapacity</key><integer>20</integer></dict></dict>")
        suite.expect(BatteriesWatch.reply(fromXML: capacity, key: "BatteryCurrentCapacity") == .value(.int(20)),
                     "a level reply")
        let charging = plist("<dict><key>RetrievedValueDictionary</key><dict><key>BatteryIsCharging</key><true/></dict></dict>")
        suite.expect(BatteriesWatch.reply(fromXML: charging, key: "BatteryIsCharging") == .value(.bool(true)),
                     "a charging reply is a Bool, not a 1")
        let name = plist("<dict><key>RetrievedValueDictionary</key><dict><key>DeviceName</key><string>Faiz’s Apple Watch</string></dict></dict>")
        suite.expect(BatteriesWatch.reply(fromXML: name, key: "DeviceName") == .value(.string("Faiz’s Apple Watch")),
                     "a name reply")
        let timeout = plist("<dict><key>Error</key><string>TimeoutReply</string></dict>")
        suite.expect(BatteriesWatch.reply(fromXML: timeout, key: "BatteryCurrentCapacity") == .timeout,
                     "a sleeping link times out, to be asked again")
        let unsupported = plist("<dict><key>Error</key><string>UnsupportedWatchKey</string></dict>")
        suite.expect(BatteriesWatch.reply(fromXML: unsupported, key: "BatteryPercent") == .unsupported,
                     "an unknown key is unsupported")
        suite.expect(BatteriesWatch.reply(fromXML: capacity, key: "BatteryIsCharging") == .failed("no value"),
                     "a reply for another key is no value")
        suite.expect(BatteriesWatch.reply(fromXML: Data("junk".utf8), key: "x") == .failed("unreadable"),
                     "unreadable data fails")

        let watch = BatteriesWatch.device(udid: "W1", name: "Faiz’s Apple Watch", capacity: 20, charging: true)
        suite.expect(watch?.id == "watch-W1" && watch?.kind == .watch && watch?.source == .viaIPhone
                     && watch?.percent == 20 && watch?.isCharging == true, "a watch read through its iPhone")
        suite.expect(BatteriesWatch.device(udid: "W1", name: nil, capacity: nil, charging: nil) == nil,
                     "no level, no watch")
        suite.expect(BatteriesWatch.device(udid: "W1", name: " ", capacity: 64, charging: nil)?.name == "Apple Watch",
                     "an unnamed watch")
        suite.expect(BatteriesWatchValue.int(1).boolValue == true && BatteriesWatchValue.string("37").intValue == 37,
                     "values convert")
    }

    // MARK: Power sources

    private static func powerSources(_ suite: TestSuite) {
        let soundcore: [String: Any] = [
            "Type": "Accessory Source", "Accessory Category": "Headphone", "Name": "soundcore Liberty 4 NC",
            "Current Capacity": 70, "Max Capacity": 100, "Is Charging": false,
            "Accessory Identifier": "E8-EE-CC-E0-A7-8E",
        ]
        let reading = BatteriesPowerSourceReading.reading(from: soundcore)
        suite.expect(reading?.level == 70 && reading?.name == "soundcore Liberty 4 NC" && reading?.kind == .headphones,
                     "an accessory source reads its level and category")
        suite.expect(reading?.address == "e8eecce0a78e", "its identifier is an address")
        suite.expect(BatteriesPowerSourceReading.reading(from: ["Type": "InternalBattery", "Current Capacity": 50]) == nil,
                     "the internal battery is not an accessory")
        suite.expect(BatteriesPowerSourceReading.reading(from: ["Type": "Accessory Source", "Current Capacity": 0]) == nil,
                     "a 0 is no level")
        suite.expect(BatteriesPowerSourceReading.reading(from: ["Type": "Accessory Source", "Current Capacity": 120,
                                                                 "Max Capacity": 100]) == nil,
                     "numbers that do not add up are no reading")
        let uuid = BatteriesPowerSourceReading.reading(from: ["Accessory Identifier": "6F1C2C1E-0000-4000-8000-00AA00BB00CC",
                                                               "Name": "Buds", "Current Capacity": 3, "Max Capacity": 4])
        suite.expect(uuid?.address == nil && uuid?.level == 75, "a UUID identifier is matched by name, levels scale")

        let other = BatteriesPowerSourceReading(address: nil, name: "Headset", productID: 0x200A, vendorID: 0x004C,
                                                level: 50, isCharging: false, category: nil)
        suite.expect(!other.fits(productID: 0x2014) && other.fits(productID: 0x200A) && other.fits(productID: nil),
                     "a source whose product id disagrees is never the device's")
    }

    private static func proximity(_ suite: TestSuite) {
        // AirPods 4 (0x2019): flipped pods, left 80, right 70, case 50, left charging.
        let bytes: [UInt8] = [0x4C, 0x00, 0x07, 0x19, 0x01, 0x19, 0x20, 0x00, 0x87, 0x25]
        let battery = BatteriesAirPodsProximity.decode(manufacturerData: Data(bytes))
        suite.expect(battery?.left == 80 && battery?.right == 70 && battery?.caseLevel == 50,
                     "pods and case decode")
        suite.expect(battery?.leftCharging == true && battery?.rightCharging == false && battery?.level == 70,
                     "charging bits and the lowest pod")
        // AirPods Max (0x200A): one battery in the low nibble.
        let max = BatteriesAirPodsProximity.decode(manufacturerData: Data([0x4C, 0x00, 0x07, 0x19, 0x01, 0x0A, 0x20,
                                                                           0x00, 0x06, 0x10]))
        suite.expect(max?.single == 60 && max?.left == nil && max?.singleCharging == true && max?.level == 60,
                     "a single-cell model has one battery")
        suite.expect(BatteriesAirPodsProximity.decode(manufacturerData: Data([0x4C, 0x00, 0x10, 0x05])) == nil,
                     "another message type is not AirPods")
    }

    // MARK: One scan

    private static func combine(_ suite: TestSuite) {
        var inputs = BatteriesScanInputs()
        inputs.mac = device("mac", "MacBook Pro", .mac, source: .builtIn, percent: 88)
        inputs.bluetooth = report
        // macOS's own list has the soundcore headset and the AirPods Max.
        inputs.powerSources = [
            BatteriesPowerSourceReading(address: nil, name: "soundcore Liberty 4 NC", productID: nil, vendorID: nil,
                                        level: 70, isCharging: false, category: "Headphone"),
            BatteriesPowerSourceReading(address: nil, name: "AirPods Max", productID: 0x200A, vendorID: 0x004C,
                                        level: 58, isCharging: true, category: "Headphone"),
            // The AirPods Pro publish a source too: it is part of them, never a row.
            BatteriesPowerSourceReading(address: nil, name: "Faiz’s AirPods Pro", productID: 0x2014, vendorID: 0x004C,
                                        level: 10, isCharging: false, category: "Headphone"),
            // A controller listed as not connected but with a live source is connected.
            BatteriesPowerSourceReading(address: "98b6ea484311", name: "Xbox Wireless Controller", productID: 0x02FD,
                                        vendorID: 0x045E, level: 15, isCharging: false, category: nil),
        ]
        // The keyboard listed as not connected publishes a level in the IORegistry.
        inputs.accessories = [BatteriesAccessoryReading(address: "f4ee25002786", name: "Maxfit61 5.0", level: 45,
                                                        kind: .keyboard, vendorID: 0x05AC)]
        inputs.gattLevels = ["mx master 3s": 63]
        inputs.airPods = [
            // Paired with this Mac, open nearby.
            "Faiz’s AirPods 4": BatteriesAirPodsSighting(
                battery: BatteriesAirPodsBattery(left: 90, right: 80, caseLevel: 40, model: 0x2019),
                date: now.addingTimeInterval(-30), rssi: -50),
            // Someone else's.
            "Stranger’s AirPods": BatteriesAirPodsSighting(
                battery: BatteriesAirPodsBattery(left: 50, right: 50, model: 0x2019), date: now, rssi: -40),
        ]
        var paired = inputs.bluetooth
        paired.pairedNames.insert("faiz’s airpods 4")
        inputs.bluetooth = paired

        let devices = BatteriesMerge.combine(inputs, now: now)
        let byName = Dictionary(devices.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        suite.expect(devices.first?.id == "mac", "the Mac comes first")
        suite.expect(byName["soundcore Liberty 4 NC"]?.percent == 70, "a headset takes its power source's level")
        suite.expect(byName["AirPods Max"]?.percent == 58 && byName["AirPods Max"]?.isCharging == true,
                     "a single-cell headset shows macOS's level")
        suite.expect(byName["Faiz’s AirPods Pro"]?.percent == 74
                     && devices.filter { $0.name == "Faiz’s AirPods Pro" }.count == 1,
                     "AirPods keep their buds, and their source is no row of its own")
        suite.expect(byName["Maxfit61 5.0"]?.percent == 45 && byName["Maxfit61 5.0"]?.id == "bt-F4:EE:25:00:27:86",
                     "a not-connected keyboard with a live level is listed under its own id")
        suite.expect(byName["Xbox Wireless Controller"]?.percent == 15 && byName["Xbox Wireless Controller"]?.kind == .gamepad,
                     "a not-connected controller with a power source is listed")
        suite.expect(byName["MX Master 3S"]?.percent == 63, "the BLE Battery Service fills a missing level")
        let nearby = byName["Faiz’s AirPods 4"]
        suite.expect(nearby?.percent == 80 && nearby?.id == "airpods-proximity-Faiz’s AirPods 4"
                     && nearby?.components.count == 3, "paired AirPods open nearby get a row from the broadcast")
        suite.expect(byName["Stranger’s AirPods"] == nil, "someone else's AirPods never show")

        var stale = inputs
        stale.airPods["Faiz’s AirPods 4"]?.date = now.addingTimeInterval(-300)
        suite.expect(!BatteriesMerge.combine(stale, now: now).contains { $0.name == "Faiz’s AirPods 4" },
                     "a broadcast older than two minutes adds no row")
        var far = inputs
        far.airPods["Faiz’s AirPods 4"]?.rssi = -80
        suite.expect(!BatteriesMerge.combine(far, now: now).contains { $0.name == "Faiz’s AirPods 4" },
                     "a weak broadcast adds no row")

        var missing = inputs
        missing.gattLevels = [:]
        suite.expect(BatteriesMerge.needsBatteryService(missing, now: now),
                     "a connected mouse without a level asks the Battery Service")
        suite.expect(!BatteriesMerge.needsBatteryService(inputs, now: now),
                     "with every accessory's level found, it is not asked")

        // The same iPhone from Bluetooth ("—") and from libimobiledevice.
        let deduplicated = BatteriesMerge.deduplicated([
            device("bt-AC", "Faiz’s iPhone", .iphone, percent: nil),
            device("ios-1", "Faiz's iPhone", .iphone, source: .usb, percent: 45),
            device("bt-10", "Faiz’s Apple\u{00A0}Watch", .watch, percent: nil),
            device("watch-1", "Faiz’s Apple Watch", .watch, source: .viaIPhone, percent: 20),
        ])
        suite.expect(deduplicated.map(\.id) == ["ios-1", "watch-1"],
                     "one device per name, the level from the iPhone side winning")
        let lastKnown = BatteriesMerge.deduplicated([
            device("bt-AC", "Phone", .iphone, percent: 30, unreachableSince: now.addingTimeInterval(-60)),
            device("ios-1", "Phone", .iphone, percent: 40, unreachableSince: now.addingTimeInterval(-600)),
            device("bt-X", "Phone", .iphone, percent: 50),
        ])
        suite.expect(lastKnown.map(\.id) == ["bt-X"], "live beats last known")
    }

    private static func ordering(_ suite: TestSuite) {
        let ordered = BatteriesMerge.ordered([
            device("bt-z", "Zebra Keyboard", .keyboard, percent: 50),
            device("bt-old", "Alpha Mouse", .mouse, percent: 30, unreachableSince: now),
            device("ios-1", "iPhone", .iphone, source: .usb, percent: 45),
            device("mac", "MacBook Pro", .mac, source: .builtIn, percent: 90),
            device("bt-a", "AirPods", .headphones, percent: 70),
        ])
        suite.expect(ordered.map(\.id) == ["mac", "bt-a", "ios-1", "bt-z", "bt-old"],
                     "the Mac, then live devices by name, then last-known ones: \(ordered.map(\.id))")
    }

    // MARK: Alerts

    private static func alerts(_ suite: TestSuite) {
        var alerted: Set<String> = []
        let fixed = UUID()
        func evaluate(_ devices: [BatteryDevice], threshold: Int = 20, muted: Set<String> = []) -> BatteriesLowAlert? {
            BatteriesAlerts.evaluate(devices, threshold: threshold, muted: muted, alerted: &alerted, id: fixed)
        }
        let mouse = { (percent: Int, charging: Bool) in device("bt-m", "Mouse", .mouse, percent: percent, charging: charging) }

        suite.expect(evaluate([mouse(21, false)]) == nil, "above the threshold, no alert")
        let first = evaluate([mouse(20, false)])
        suite.expect(first?.device.id == "bt-m" && first?.percent == 20 && first?.others == [] && first?.id == fixed,
                     "at the threshold, an alert")
        suite.expect(evaluate([mouse(18, false)]) == nil, "once per episode")
        suite.expect(evaluate([mouse(24, false)]) == nil && evaluate([mouse(19, false)]) == nil,
                     "below threshold + 5 it does not re-arm")
        suite.expect(evaluate([mouse(25, false)]) == nil, "threshold + 5 re-arms")
        suite.expect(evaluate([mouse(15, false)])?.percent == 15, "and it alerts again")

        alerted = []
        suite.expect(evaluate([mouse(10, true)]) == nil, "never while charging")
        suite.expect(evaluate([mouse(10, false)])?.percent == 10, "unplugged while low, it alerts")

        alerted = []
        suite.expect(evaluate([device("mac", "MacBook", .mac, source: .builtIn, percent: 12)], muted: ["mac"]) == nil,
                     "a muted device is quiet")
        suite.expect(alerted.contains("mac"), "and counted as alerted, so unmuting while low stays quiet")
        suite.expect(evaluate([device("mac", "MacBook", .mac, source: .builtIn, percent: 11)]) == nil,
                     "unmuted in the same episode, still quiet")

        alerted = []
        let grouped = evaluate([
            device("bt-k", "Keyboard", .keyboard, percent: 18),
            device("bt-p", "Pad", .gamepad, percent: 9),
            device("bt-h", "Headset", .headphones, percent: 18),
            device("bt-ok", "Fine", .mouse, percent: 80),
            device("bt-gone", "Gone", .mouse, percent: 5, unreachableSince: now),
        ], threshold: 20)
        suite.expect(grouped?.device.id == "bt-p" && grouped?.percent == 9 && grouped?.others == ["Keyboard", "Headset"],
                     "several low devices make one alert, the lowest first")
        suite.expect(!alerted.contains("bt-gone"), "a last-known level never alerts")

        alerted = []
        suite.expect(evaluate([mouse(30, false)], threshold: 30)?.percent == 30, "the threshold comes from settings")
    }

    // MARK: Registry

    private static func registry(_ suite: TestSuite) {
        var registry = BatteriesRegistry()
        let keyboard = device("bt-k", "Keyboard", .keyboard, percent: 60)
        let phone = device("ios-1", "iPhone", .iphone, source: .wifi, percent: 45, charging: true)
        let nearby = device("airpods-proximity-AirPods", "AirPods", .headphones, percent: 80)
        _ = registry.reconcile(current: [keyboard, phone, nearby], now: now)
        suite.expect(Set(registry.entries.keys) == ["bt-k", "ios-1"], "broadcast-only AirPods are never kept")

        let later = now.addingTimeInterval(3_600)
        let missing = registry.reconcile(current: [device("bt-k", "Keyboard", .keyboard, percent: nil)], now: later)
        let phoneLater = missing.first { $0.id == "ios-1" }
        suite.expect(phoneLater?.percent == 45 && phoneLater?.unreachableSince == now && phoneLater?.isCharging == false,
                     "a missing iPhone shows its last level, seen when it was last read, not charging")
        let keyboardLater = missing.first { $0.id == "bt-k" }
        suite.expect(keyboardLater?.percent == 60 && keyboardLater?.unreachableSince == now,
                     "a device listed without a level shows its last one, dimmed")

        let live = registry.reconcile(current: [device("bt-k", "Keyboard", .keyboard, percent: 55)], now: later)
        suite.expect(live.first { $0.id == "bt-k" }?.isReachable == true, "a live level is live again")

        registry.alerted = ["ios-1", "bt-k", "bt-forgotten"]
        let expired = registry.reconcile(current: [device("bt-k", "Keyboard", .keyboard, percent: 55)],
                                         now: now.addingTimeInterval(BatteriesDefaults.lastKnownLifetime + 60))
        suite.expect(!expired.contains { $0.id == "ios-1" } && registry.entries["ios-1"] == nil,
                     "a device not seen for seven days is dropped")
        suite.expect(registry.alerted == ["bt-k"], "alert state goes with the device")

        let stillKept = registry.reconcile(current: [], now: now.addingTimeInterval(BatteriesDefaults.lastKnownLifetime))
        suite.expect(stillKept.contains { $0.id == "bt-k" }, "within seven days it is kept")

        var withProximity = registry
        withProximity.entries["airpods-proximity-X"] = .init(device: nearby, lastSeen: now)
        let decoded = BatteriesRegistry.decode(withProximity.encoded())
        suite.expect(decoded.entries["airpods-proximity-X"] == nil && decoded.entries["bt-k"] != nil
                     && decoded.alerted == registry.alerted, "the file round-trips and never brings broadcasts back")
        suite.expect(BatteriesRegistry.decode(Data("{".utf8)) == BatteriesRegistry()
                     && BatteriesRegistry.decode(nil) == BatteriesRegistry(), "an unreadable file starts empty")

        var a = BatteriesRegistry()
        _ = a.reconcile(current: [keyboard], now: now)
        let signature = a.persistenceSignature
        _ = a.reconcile(current: [keyboard], now: later)
        suite.expect(a.persistenceSignature == signature, "only a last-seen time moving is not worth a write")
        _ = a.reconcile(current: [device("bt-k", "Keyboard", .keyboard, percent: 59)], now: later)
        suite.expect(a.persistenceSignature != signature, "a new level is")
    }

    // MARK: Schedule and preferences

    private static func schedule(_ suite: TestSuite) {
        suite.expect(BatteriesSchedule.interval(enabled: false, visible: true, refreshMinutes: 2, canAlert: true) == nil,
                     "nothing at all when Batteries is off")
        suite.expect(BatteriesSchedule.interval(enabled: true, visible: true, refreshMinutes: 2, canAlert: false) == 120,
                     "every refresh interval while visible")
        suite.expect(BatteriesSchedule.interval(enabled: true, visible: false, refreshMinutes: 1, canAlert: true) == 300,
                     "every five minutes while hidden when some device can alert")
        suite.expect(BatteriesSchedule.interval(enabled: true, visible: false, refreshMinutes: 1, canAlert: false) == nil,
                     "nothing while hidden when nothing can alert")
        let devices = [device("mac", "Mac", .mac, source: .builtIn, percent: 50)]
        suite.expect(!BatteriesSchedule.canAlert(devices, muted: ["mac"])
                     && BatteriesSchedule.canAlert(devices, muted: []), "a muted Mac alone cannot alert")
        suite.expect(BatteriesSchedule.delay(interval: 300, lastScanAt: now.addingTimeInterval(-100), now: now) == 200
                     && BatteriesSchedule.delay(interval: 300, lastScanAt: nil, now: now) == 0
                     && BatteriesSchedule.delay(interval: 60, lastScanAt: now.addingTimeInterval(-600), now: now) == 0,
                     "a restarted schedule waits out the rest of its interval")
    }

    private static func preferences(_ suite: TestSuite) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let unset = BatteriesConfig.current(in: defaults)
        suite.expect(unset == BatteriesConfig(), "unset preferences read the contract's defaults")
        suite.expect(unset.enabled && unset.readIOSDevices && !unset.airPodsScanning && unset.threshold == 20
                     && unset.refreshMinutes == 2 && unset.muted == ["mac"], "on, iPhones read, Mac muted")

        BatteriesConfig.registerDefaults(in: defaults)
        suite.expect(defaults.stringArray(forKey: BatteriesDefaults.mutedDeviceIDs) == ["mac"],
                     "the muted Mac is what every reader of the key sees")
        defaults.set(["bt-k"], forKey: BatteriesDefaults.mutedDeviceIDs)
        suite.expect(BatteriesConfig.current(in: defaults).muted == ["bt-k"], "a written list leaves the Mac unmuted")
        defaults.set(15, forKey: BatteriesDefaults.threshold)
        defaults.set(7, forKey: BatteriesDefaults.refreshMinutes)
        defaults.set(false, forKey: BatteriesDefaults.enabled)
        let written = BatteriesConfig.current(in: defaults)
        suite.expect(written.threshold == 15 && written.refreshMinutes == 2 && !written.enabled,
                     "an offered threshold is kept, an unknown interval is not")
        suite.expect(BatteriesConfig.sanitizedThreshold(99) == 20 && BatteriesConfig.sanitizedRefreshMinutes(10) == 10,
                     "values outside the options fall back")
    }

    private static func symbols(_ suite: TestSuite) {
        let all: (String) -> Bool = { _ in true }
        var mouse = device("bt-m", "Mouse", .mouse, percent: 50)
        mouse.vendorID = 0x004C
        suite.expect(BatteriesSymbols.override(for: mouse, isAvailable: all) == "magicmouse", "an Apple mouse")
        mouse.vendorID = 0x046D
        suite.expect(BatteriesSymbols.override(for: mouse, isAvailable: all) == nil, "another maker's mouse")
        mouse.vendorID = nil
        mouse.productID = 0x0269
        suite.expect(BatteriesSymbols.override(for: mouse, isAvailable: all) == "magicmouse",
                     "a product id kept from an Apple listing")

        var pods = device("bt-p", "Faiz’s Headphones", .headphones, percent: 50)
        pods.productID = 0x2019
        suite.expect(BatteriesSymbols.override(for: pods, isAvailable: { $0 == "airpods.gen3" }) == "airpods.gen3",
                     "AirPods 4 by product id, the first symbol this macOS draws")
        pods.productID = nil
        pods.name = "Faiz’s AirPods Pro"
        suite.expect(BatteriesSymbols.override(for: pods, isAvailable: { $0 == "airpodspro" }) == "airpodspro",
                     "AirPods Pro by name, the older spelling")
        pods.name = "AirPods Max"
        suite.expect(BatteriesSymbols.override(for: pods, isAvailable: all) == "airpods.max", "AirPods Max")
        suite.expect(BatteriesSymbols.override(for: pods, isAvailable: { _ in false }) == nil,
                     "no symbol drawn, the generic headphones")
        pods.name = "soundcore Liberty 4 NC"
        suite.expect(BatteriesSymbols.override(for: pods, isAvailable: all) == nil, "other headphones stay generic")
        suite.expect(pods.symbolName == "headphones", "the kind's symbol")
    }
}
