// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import AppKit

// Zenith fork: the island side of Batteries, kept out of the views so it can
// be tested (compiled into the tests): the preferences it reads, which
// devices show and in what words, the weakest one for the Home widget, the
// Battery Low card's advice and measures, the compact form's battery, and
// how long that compact form stays. The readings come from BatteriesStore,
// the contract the monitor fills.

enum BatteriesIslandSupport {
    // MARK: Preferences

    /// On unless turned off in Settings: off hides the page, its widget and
    /// the Battery Low card.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: BatteriesDefaults.enabled) as? Bool ?? true
    }

    static func layout(in defaults: UserDefaults = .standard) -> BatteriesLayout {
        defaults.string(forKey: BatteriesDefaults.layout).flatMap(BatteriesLayout.init(rawValue:)) ?? .rings
    }

    /// The alert level, one of the offered steps.
    static func threshold(in defaults: UserDefaults = .standard) -> Int {
        let value = defaults.object(forKey: BatteriesDefaults.threshold) as? Int ?? BatteriesDefaults.defaultThreshold
        return BatteriesDefaults.thresholdOptions.contains(value) ? value : BatteriesDefaults.defaultThreshold
    }

    static func hiddenDeviceIDs(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: BatteriesDefaults.hiddenDeviceIDs) ?? [])
    }

    // MARK: Devices

    /// What the page shows, in the store's order: everything not hidden in Settings.
    static func shown(_ devices: [BatteryDevice], hidden: Set<String>) -> [BatteryDevice] {
        hidden.isEmpty ? devices : devices.filter { !hidden.contains($0.id) }
    }

    /// The reachable device with the lowest known level, for the Home
    /// widget; the first of equals, so it does not flip between them.
    static func weakest(_ devices: [BatteryDevice]) -> BatteryDevice? {
        var weakest: BatteryDevice?
        for device in devices where device.isReachable {
            guard let percent = device.percent else { continue }
            if let current = weakest?.percent, current <= percent { continue }
            weakest = device
        }
        return weakest
    }

    /// The droplet's display names: a leading "Faiz’s " goes when what is
    /// left still names one device among those shown.
    static func displayNames(for devices: [BatteryDevice]) -> [String: String] {
        let shortened = devices.map { ownerStripped($0.name) }
        var counts: [String: Int] = [:]
        for (device, short) in zip(devices, shortened) {
            counts[(short ?? device.name).lowercased(), default: 0] += 1
        }
        var names: [String: String] = [:]
        for (device, short) in zip(devices, shortened) {
            if let short, counts[short.lowercased()] == 1 {
                names[device.id] = short
            } else {
                names[device.id] = device.name
            }
        }
        return names
    }

    static func ownerStripped(_ name: String) -> String? {
        let match = ["\u{2019}s ", "'s "].compactMap { name.range(of: $0) }.min { $0.lowerBound < $1.lowerBound }
        guard let match, match.lowerBound > name.startIndex else { return nil }
        let rest = name[match.upperBound...].trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }

    /// The level clamped to 0...100.
    static func clamped(_ percent: Int) -> Int { min(100, max(0, percent)) }

    static func percentText(_ percent: Int?, text: ZenithBatteriesIslandStrings) -> String {
        percent.map { "\(clamped($0))%" } ?? text.unknownLevel
    }

    /// The page's content height for `count` devices in `layout`: the rings'
    /// row with room above and below it, or the List's rows; at least an
    /// empty page's. The island never grows past its budget; more rows scroll.
    static func pageHeight(count: Int, layout: BatteriesLayout) -> CGFloat {
        guard count > 0 else { return emptyPageHeight }
        switch layout {
        case .rings: return BatteriesRingMetrics.solo.columnHeight + ringsPadding * 2
        case .list:
            let rows = CGFloat(BatteriesListMetrics.rows(Array(0..<count)).count)
            return rows * BatteriesListMetrics.rowHeight + max(0, rows - 1) + listPadding * 2
        }
    }

    static let emptyPageHeight: CGFloat = 140
    /// Above and below the rings' row.
    static let ringsPadding: CGFloat = 10
    /// Above and below the List's rows.
    static let listPadding: CGFloat = 4

    // MARK: Words

    /// How long ago, short: "<1 min", "12 min", "2 h", "3 d".
    static func elapsed(since date: Date, now: Date, text: ZenithBatteriesIslandStrings) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return text.lessThanAMinute }
        if seconds < 3_600 { return text.minutes.replacingOccurrences(of: "{count}", with: "\(Int(seconds / 60))") }
        if seconds < 86_400 { return text.hours.replacingOccurrences(of: "{count}", with: "\(Int(seconds / 3_600))") }
        return text.days.replacingOccurrences(of: "{count}", with: "\(Int(seconds / 86_400))")
    }

    /// The List layout's caption: where the reading came from, or, for a
    /// last-known level, when the device was last seen.
    static func caption(_ device: BatteryDevice, now: Date, text: ZenithBatteriesIslandStrings) -> String {
        guard let since = device.unreachableSince else { return text.source(device.source) }
        return text.lastSeen.replacingOccurrences(of: "{time}", with: elapsed(since: since, now: now, text: text))
    }

    /// The card's line of advice, as the droplet words it.
    static func lowDetail(others: [String], text: ZenithBatteriesIslandStrings) -> String {
        switch others.count {
        case 0: return text.lowAlone
        case 1: return text.lowOne.replacingOccurrences(of: "{name}", with: others[0])
        default: return text.lowMany.replacingOccurrences(of: "{count}", with: "\(others.count)")
        }
    }

    static func accessibilityValue(_ device: BatteryDevice, now: Date, text: ZenithBatteriesIslandStrings) -> String {
        var parts = [device.percent.map { text.percentValue.replacingOccurrences(of: "{percent}", with: "\(clamped($0))") }
            ?? text.levelUnknown]
        if device.isCharging { parts.append(text.charging) }
        if let since = device.unreachableSince {
            parts.append(text.notReachable.replacingOccurrences(of: "{time}", with: elapsed(since: since, now: now, text: text)))
        }
        return parts.joined(separator: ", ")
    }

    /// The SF Symbol battery nearest to a level, the droplet's steps.
    static func batterySymbol(percent: Int) -> String {
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    // MARK: The low alert

    /// The card for an alert, in the droplet's words.
    static func lowBurst(_ alert: BatteriesLowAlert, text: ZenithBatteriesIslandStrings) -> ZenithBatteryLowBurst {
        ZenithBatteryLowBurst(deviceID: alert.device.id, name: alert.device.name, percent: clamped(alert.percent),
                              symbol: alert.device.symbolName, detail: lowDetail(others: alert.others, text: text))
    }

    /// The compact form stays in the closed island this long after the
    /// card, unless the device charges, recovers, or the page is opened.
    static let compactLinger: TimeInterval = 5 * 60

    /// Whether a compact form for `indicator` still stands, given the
    /// device's current reading (nil when the store no longer lists it).
    static func indicatorStands(_ indicator: BatteriesLowIndicator, device: BatteryDevice?, threshold: Int,
                                now: Date) -> Bool {
        guard now.timeIntervalSince(indicator.since) < compactLinger else { return false }
        guard let device else { return true }
        if device.isCharging { return false }
        guard let percent = device.percent else { return true }
        return percent <= threshold
    }

    /// The indicator after a new reading of its device: its level follows.
    static func updated(_ indicator: BatteriesLowIndicator, device: BatteryDevice?) -> BatteriesLowIndicator {
        guard let percent = device?.percent else { return indicator }
        var next = indicator
        next.percent = clamped(percent)
        return next
    }
}

/// The Battery Low card's content, the island grown for a moment
/// (ZenithIslandBurst): the device's name and level, the line of advice and
/// the device's symbol.
struct ZenithBatteryLowBurst: Equatable {
    let deviceID: String
    let name: String
    let percent: Int
    let symbol: String
    let detail: String
}

/// The compact form in the closed island after the card: the device's
/// symbol, then a red battery and its level.
struct BatteriesLowIndicator: Equatable {
    let deviceID: String
    var name: String
    var symbol: String
    var percent: Int
    let since: Date
}

// MARK: - Measures

/// The droplet's BatteryRing numbers. `solo` is the page's ring, `list` the
/// small ring of a List row.
struct BatteriesRingMetrics: Equatable {
    let diameter: CGFloat
    let lineWidth: CGFloat
    let symbolSize: CGFloat
    let labelSize: CGFloat
    let nameSize: CGFloat
    let gap: CGFloat
    let nameGap: CGFloat
    /// Between two rings' columns.
    let spacing: CGFloat
    let badgeSize: CGFloat
    let boltSize: CGFloat

    static let solo = BatteriesRingMetrics(diameter: 62, lineWidth: 6, symbolSize: 22, labelSize: 15, nameSize: 11,
                                           gap: 6, nameGap: 2, spacing: 8, badgeSize: 18, boltSize: 10)

    /// Every ring's column: the ring, with room for a name a little wider
    /// than it, which truncates past this.
    var cellWidth: CGFloat { diameter + 12 }

    /// The most rings the page shows side by side; more scroll, with a fade
    /// on the side that has more.
    static let ringsShown = 5
    /// Past five, this much of the sixth column shows, so the row reads as one that scrolls.
    static let peek: CGFloat = 0.4

    /// `count` columns and the gaps between them.
    func rowWidth(count: Int) -> CGFloat {
        let rings = CGFloat(max(count, 0))
        return rings * cellWidth + max(rings - 1, 0) * spacing
    }

    /// The scroller's width for `count` rings in `available` points: the
    /// whole row while it fits five, else five and a peek of the next.
    func visibleWidth(count: Int, available: CGFloat) -> CGFloat {
        let wanted = count <= Self.ringsShown ? rowWidth(count: count)
            : rowWidth(count: Self.ringsShown) + spacing + cellWidth * Self.peek
        return max(0, min(available, wanted))
    }

    /// Whether `count` rings scroll in `available` points.
    func scrolls(count: Int, available: CGFloat) -> Bool {
        rowWidth(count: count) > visibleWidth(count: count, available: available) + 0.5
    }

    /// A column's height: the ring, the level and the name below it.
    var columnHeight: CGFloat {
        diameter + gap + (labelSize * 1.2).rounded(.up) + nameGap + (nameSize * 1.25).rounded(.up)
    }
}

/// The List layout: two columns of rows, each a small ring around the
/// device's symbol, the name over its caption, and the level at the end.
enum BatteriesListMetrics {
    static let rowHeight: CGFloat = 52
    static let ringDiameter: CGFloat = 36
    static let ringLine: CGFloat = 4
    static let symbolSize: CGFloat = 14
    static let ringGap: CGFloat = 10
    static let nameSize: CGFloat = 13
    static let captionSize: CGFloat = 9.5
    static let percentSize: CGFloat = 15
    static let boltSize: CGFloat = 10
    /// From the column's divider to a row's content.
    static let columnGap: CGFloat = 14
    static let columns = 2

    /// The devices in rows of two, left to right, then down.
    static func rows<T>(_ items: [T]) -> [[T]] {
        stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }
}

/// The droplet's Battery Low card (LowBatteryCard): the text column, the
/// battery and the device's symbol in their slot.
enum BatteriesCardMetrics {
    /// The droplet's row is 42; two lines of advice under the title need a
    /// little more as SwiftUI draws them.
    static let rowHeight: CGFloat = 44
    static let rowSpacing: CGFloat = 12
    static let textSpacerMinimum: CGFloat = 8
    static let titleRowSpacing: CGFloat = 8
    static let titleDescriptionSpacing: CGFloat = 3
    static let batteryWidth: CGFloat = 44
    static let batteryHeight: CGFloat = 24
    static let indicatorSpacing: CGFloat = 7
    static let symbolWidth: CGFloat = 20
    static let symbolSize: CGFloat = 17
    static let slot = CGSize(width: 75, height: 42)
    /// The card's island: as wide as the droplet's card reads, the advice on two lines.
    static let width: CGFloat = 420

    static let titleFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let percentFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let detailFont = NSFont.systemFont(ofSize: 10, weight: .medium)
}

/// The compact form's pieces in the closed island.
enum BatteriesStripMetrics {
    static let glyphSize: CGFloat = 12
    static let batterySize: CGFloat = 12
    static let percentFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    /// Between the battery and its level.
    static let batteryGap: CGFloat = 4

    static func percentWidth(_ percent: Int) -> CGFloat {
        ("\(BatteriesIslandSupport.clamped(percent))%" as NSString)
            .size(withAttributes: [.font: percentFont]).width.rounded(.up) + 2
    }
}

/// The droplet's colours on the island's black (the system's dark values):
/// green while charging or above the alert level, red at or below it, the
/// yellow bolt.
enum BatteriesPaletteHex {
    static let green: UInt32 = 0x30D158
    static let red: UInt32 = 0xFF453A
    static let yellow: UInt32 = 0xFFD60A
}
