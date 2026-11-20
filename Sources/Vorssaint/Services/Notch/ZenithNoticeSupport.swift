// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: capsule notices. A short system event grows out of the closed
// island as a wide pill, stays a few seconds and shrinks back. Everything here
// is pure (no AppKit, no SwiftUI) and compiled into the tests: the notice
// model, the queue, the battery thresholds with their hysteresis, settings,
// sizes and formatting. ZenithNoticeService presents; ZenithNoticeView draws.

/// One capsule notice: a leading glyph, a title, a subtitle and a trailing accessory.
struct ZenithNotice: Equatable {
    enum Kind: String, CaseIterable {
        case batteryCritical, batteryLow, charging, unplugged, chargeLimit, audio, download, export
        /// A camera card mounted, offering to import it (CardImportService).
        case card

        /// Higher shows first and may cut a lower one short.
        var priority: Int {
            switch self {
            case .batteryCritical: return 5
            case .batteryLow: return 4
            case .audio, .card: return 3
            case .charging, .unplugged: return 2
            case .chargeLimit, .download, .export: return 1
            }
        }
    }

    /// Colour with a meaning: red for low battery, amber for getting low,
    /// green for charging and full, the system accent for information; a
    /// module's identity colour (`tint`) where the notice is that module's.
    enum Tone: Equatable { case red, amber, green, accent, white, tint(NotchModule) }

    enum Glyph: Equatable {
        case none
        case symbol(String, Tone)
        /// A QuickLook thumbnail of the file, its icon until one is ready.
        case file(URL)
    }

    enum Accessory: Equatable {
        case none
        /// A ring filled to the percentage, the number inside.
        case ring(percent: Int, tone: Tone)
        /// A switch-like pill with a battery: Low Power Mode, on or off.
        case lowPower(on: Bool)
        /// A checkmark that draws itself.
        case checkmark
        /// What a click on the capsule does, as words on a solid pill.
        case action(String)
    }

    enum Action: Equatable {
        case none
        case batterySettings
        case reveal(URL)
        /// Opens the card's import page in the island; the card's volume key.
        case importCard(String)
    }

    let kind: Kind
    /// Two notices with the same key are one: a newer one updates it in place.
    let key: String
    var title: String
    var subtitle: String
    var glyph: Glyph = .none
    var accessory: Accessory = .none
    var action: Action = .none

    var priority: Int { kind.priority }
    var duration: TimeInterval { ZenithNoticeTiming.duration(kind) }
    var accessibilityText: String { [title, subtitle].filter { !$0.isEmpty }.joined(separator: ", ") }
}

// MARK: - Queue

/// At most one notice shows. The rest wait by priority, then in arrival order;
/// a notice with the key of one already waiting or showing updates it, and a
/// newer power state makes an older one moot.
struct ZenithNoticeQueue {
    struct Entry: Equatable {
        var notice: ZenithNotice
        var expires: TimeInterval
        let order: Int
    }

    enum Outcome: Equatable {
        /// Waits its turn.
        case queued
        /// Replaced a waiting notice with the same key, in its place.
        case coalesced
        /// Has the key of the notice on screen, which now shows it.
        case updatedCurrent
        /// Outranks the notice on screen, which should leave now.
        case preempts
    }

    static let capacity = 6

    private(set) var pending: [Entry] = []
    private(set) var current: ZenithNotice?
    private var counter = 0

    /// How long a notice may wait for the island before it is stale.
    static func lifetime(_ kind: ZenithNotice.Kind) -> TimeInterval {
        switch kind {
        case .batteryCritical, .batteryLow: return 90
        case .audio, .charging, .unplugged: return 12
        case .chargeLimit, .download, .card, .export: return 30
        }
    }

    /// Keys a new notice makes moot: a charger plugged in answers a low
    /// battery warning, and one pulled out ends the charge it was making.
    static func supersededKeys(by notice: ZenithNotice) -> [String] {
        switch notice.kind {
        case .charging: return [ZenithNoticeKey.batteryLow]
        case .unplugged: return [ZenithNoticeKey.chargeLimit]
        default: return []
        }
    }

    var isEmpty: Bool { pending.isEmpty }

    mutating func enqueue(_ notice: ZenithNotice, now: TimeInterval) -> Outcome {
        let superseded = Self.supersededKeys(by: notice)
        pending.removeAll { superseded.contains($0.notice.key) }
        if let current, current.key == notice.key {
            self.current = notice
            return .updatedCurrent
        }
        let expires = now + Self.lifetime(notice.kind)
        if let index = pending.firstIndex(where: { $0.notice.key == notice.key }) {
            pending[index].notice = notice
            pending[index].expires = expires
            return .coalesced
        }
        counter += 1
        pending.append(Entry(notice: notice, expires: expires, order: counter))
        if pending.count > Self.capacity, let weakest = pending.indices.min(by: { lhs, rhs in
            let (a, b) = (pending[lhs], pending[rhs])
            return a.notice.priority != b.notice.priority ? a.notice.priority < b.notice.priority : a.order < b.order
        }) {
            pending.remove(at: weakest)
        }
        if let current, notice.priority > current.priority, pending.contains(where: { $0.notice.key == notice.key }) {
            return .preempts
        }
        return .queued
    }

    /// Leaves out what waited too long for the island.
    mutating func prune(now: TimeInterval) {
        pending.removeAll { $0.expires <= now }
    }

    /// Takes the next notice to show, highest priority first, leaving out
    /// any that waited too long. It becomes the current one.
    mutating func next(now: TimeInterval) -> ZenithNotice? {
        prune(now: now)
        guard let index = pending.indices.min(by: { lhs, rhs in
            let (a, b) = (pending[lhs], pending[rhs])
            return a.notice.priority != b.notice.priority ? a.notice.priority > b.notice.priority : a.order < b.order
        }) else { return nil }
        let entry = pending.remove(at: index)
        current = entry.notice
        return entry.notice
    }

    /// The notice on screen has left.
    mutating func finishCurrent() { current = nil }

    /// Drops what waits for a kind the person turned off, or everything.
    mutating func removeAll(where shouldRemove: (ZenithNotice) -> Bool = { _ in true }) {
        pending.removeAll { shouldRemove($0.notice) }
    }
}

enum ZenithNoticeKey {
    static let batteryLow = "battery.low"
    static let power = "battery.power"
    static let chargeLimit = "battery.limit"
    static func audio(_ name: String) -> String { "audio." + name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    static func download(_ url: URL) -> String { "download." + url.standardizedFileURL.path }
    static func card(_ volume: String) -> String { "card." + volume }
    /// An export: one file, or a batch of images by its folder.
    static func export(_ id: String) -> String { "export." + id }
}

// MARK: - Battery

struct ZenithBatteryReading: Equatable {
    var percent: Int?
    var external: Bool
    var charging: Bool
}

/// Which battery notices are on and where their thresholds sit.
struct ZenithBatterySettings: Equatable {
    var lowOn = true
    var low = 20
    var criticalOn = true
    var critical = 10
    var highOn = true
    var high = 80
    var chargerOn = true

    static let lowChoices = [15, 20, 25, 30]
    static let criticalChoices = [5, 10, 15]
    static let highChoices = [80, 85, 90, 95]
    /// A threshold is crossed once; it counts again only after the charge
    /// moved this far back, so a level wavering around it stays quiet.
    static let hysteresis = 3

    static func current(in defaults: UserDefaults = .standard) -> ZenithBatterySettings {
        func choice(_ key: String, _ choices: [Int], _ fallback: Int) -> Int {
            let value = defaults.integer(forKey: key)
            return choices.contains(value) ? value : fallback
        }
        return ZenithBatterySettings(
            lowOn: defaults.bool(forKey: DefaultsKey.notchNoticeBatteryLow),
            low: choice(DefaultsKey.notchNoticeBatteryLowLevel, lowChoices, 20),
            criticalOn: defaults.bool(forKey: DefaultsKey.notchNoticeBatteryCritical),
            critical: choice(DefaultsKey.notchNoticeBatteryCriticalLevel, criticalChoices, 10),
            highOn: defaults.bool(forKey: DefaultsKey.notchNoticeBatteryHigh),
            high: choice(DefaultsKey.notchNoticeBatteryHighLevel, highChoices, 80),
            chargerOn: defaults.bool(forKey: DefaultsKey.notchNoticeCharger))
    }
}

enum ZenithBatteryEvent: Equatable {
    case low(percent: Int, critical: Bool)
    case charging(percent: Int?)
    case unplugged(percent: Int?)
    case chargeLimit(percent: Int)
}

/// Turns power readings into notices. The first reading is a baseline: a
/// Mac already below a threshold at launch says nothing until it recovers
/// past the threshold and crosses it again.
struct ZenithBatteryNoticeState {
    private(set) var last: ZenithBatteryReading?
    private var lowArmed = true
    private var criticalArmed = true
    private var highArmed = true

    /// `previous` is the reading before this one when the caller knows it,
    /// which serves as the baseline if this state has none yet.
    mutating func update(_ reading: ZenithBatteryReading, previous: ZenithBatteryReading? = nil,
                         settings: ZenithBatterySettings) -> [ZenithBatteryEvent] {
        if last == nil, let previous { arm(previous, settings: settings) }
        guard let before = last else {
            arm(reading, settings: settings)
            return []
        }
        last = reading
        var events: [ZenithBatteryEvent] = []
        let percent = reading.percent.map { min(100, max(0, $0)) }
        if before.external != reading.external, settings.chargerOn {
            events.append(reading.external ? .charging(percent: percent) : .unplugged(percent: percent))
        }
        guard let percent else { return events }
        let margin = ZenithBatterySettings.hysteresis
        if percent >= settings.low + margin { lowArmed = true }
        if percent >= settings.critical + margin { criticalArmed = true }
        if percent <= settings.high - margin { highArmed = true }
        if !reading.external {
            if criticalArmed, percent <= settings.critical {
                criticalArmed = false
                // The deeper warning stands for both when one reading crosses
                // the two, as after a sleep. With it off, the low one covers
                // the jump, if it has not spoken yet.
                let lowPending = lowArmed && percent <= settings.low
                if percent <= settings.low { lowArmed = false }
                if settings.criticalOn { events.append(.low(percent: percent, critical: true)) }
                else if settings.lowOn, lowPending { events.append(.low(percent: percent, critical: false)) }
            } else if lowArmed, percent <= settings.low {
                lowArmed = false
                if settings.lowOn { events.append(.low(percent: percent, critical: false)) }
            }
        } else if highArmed, percent >= settings.high, percent < 100 {
            highArmed = false
            if settings.highOn { events.append(.chargeLimit(percent: percent)) }
        }
        return events
    }

    private mutating func arm(_ reading: ZenithBatteryReading, settings: ZenithBatterySettings) {
        last = reading
        guard let percent = reading.percent else { return }
        lowArmed = percent > settings.low
        criticalArmed = percent > settings.critical
        highArmed = percent < settings.high
    }

    /// Whether the capsule takes the place of the island's small battery
    /// notice for this change: the charger plugged in or out while that
    /// capsule is on, and a low charge while either low capsule is on. A full
    /// charge keeps the small notice, which the capsules do not cover.
    static func replacesSmallNotice(before: ZenithBatteryReading, after: ZenithBatteryReading,
                                    settings: ZenithBatterySettings) -> Bool {
        if before.external != after.external { return settings.chargerOn }
        let low = (after.percent ?? 100) <= 20 && (before.percent ?? 0) > 20
        return low && (settings.lowOn || settings.criticalOn)
    }
}

// MARK: - Accessories

enum ZenithAudioNotice {
    /// Symbols the accessory catalog gives audio devices.
    static let audioSymbols: Set<String> = ["airpods", "airpodspro", "airpodsmax", "headphones", "hifispeaker"]

    static func isAudio(symbol: String) -> Bool { audioSymbols.contains(symbol) }

    /// The reading for a device that just connected, matched by name the way
    /// the battery sampler coalesces it. AirPods can report each bud and the
    /// case; the lowest reading is the one worth knowing.
    static func batteryPercent(named name: String, in devices: [(name: String, percent: Int)]) -> Int? {
        let wanted = normalized(name)
        guard !wanted.isEmpty else { return nil }
        let matches = devices.filter { (0...100).contains($0.percent) && normalized($0.name) == wanted }
        return matches.map(\.percent).min()
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Formatting

enum ZenithNoticeFormat {
    static func clamped(_ percent: Int) -> Int { min(100, max(0, percent)) }

    /// `%d` in a localized template becomes the percentage.
    static func filling(_ template: String, percent: Int) -> String {
        template.replacingOccurrences(of: "%d", with: "\(clamped(percent))")
    }

    /// Title and percentage, as in “Charging · 80%”.
    static func titled(_ title: String, percent: Int?) -> String {
        guard let percent else { return title }
        return title + " · \(clamped(percent))%"
    }

    /// A battery's tone by how much is left.
    static func batteryTone(_ percent: Int) -> ZenithNotice.Tone {
        percent <= 10 ? .red : percent <= 20 ? .amber : .green
    }

    /// “1.6 MB · Downloads”, or the folder alone when the size is unknown.
    static func downloadDetail(bytes: Int64?, folder: String) -> String {
        guard let bytes, bytes >= 0 else { return folder }
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return folder.isEmpty ? size : size + " · " + folder
    }
}

// MARK: - Timing and sizes

enum ZenithNoticeTiming {
    /// On screen before it leaves by itself; the pointer on it holds it.
    static func duration(_ kind: ZenithNotice.Kind) -> TimeInterval {
        switch kind {
        case .batteryCritical, .batteryLow: return 6
        // A card asks for a decision, so it stays a little longer.
        case .card: return 7
        default: return 4
        }
    }

    /// After the pointer leaves a held notice.
    static let hoverGrace: TimeInterval = 1.5
    /// The shape's spring, on size and position only.
    static let springResponse = 0.4
    static let springDamping = 0.82
    /// The content waits until the shape has grown about 60% of the way.
    static let contentDelay = 0.14
    /// Between the pieces of the content as they blur in, and out in reverse.
    static let stagger = 0.04
    static let contentDuration = 0.24
    static let blurRadius: CGFloat = 10
    /// The content is gone before the shape shrinks back.
    static let contentOut = 0.16
    /// From the start of the shrink until the panel can leave.
    static let shrink = 0.42
    static let fade = 0.2
    /// Between one notice leaving and the next one growing.
    static let gap = 0.12
}

/// Measured from the reference frames: the capsule is about five times as
/// wide as tall (824 × 162 px), and its 13 pt title puts it near 400 × 79 pt.
/// Zenith keeps the brief's 360–420 × 56–64 range: 380 × 62, one row.
enum ZenithNoticeLayout {
    static let width: CGFloat = 380
    static let maximumWidth: CGFloat = 420
    static let rowHeight: CGFloat = 62
    static let glyph: CGFloat = 30
    static let ring: CGFloat = 30
    static let lowPowerWidth: CGFloat = 50
    static let lowPowerHeight: CGFloat = 28
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 12
    static let titleSize: CGFloat = 13
    static let subtitleSize: CGFloat = 11.5
    /// A pill's ends need this much more room inside than a square edge.
    static let endInset: CGFloat = 6

    /// As wide as the island already is, if wider, within the range and the display.
    static func width(closedWidth: CGFloat, screenWidth: CGFloat) -> CGFloat {
        let wanted = min(maximumWidth, max(width, closedWidth.isFinite ? closedWidth : 0))
        return max(0, min(wanted, screenWidth - 24))
    }

    /// The capsule in screen coordinates (origin at the bottom left). A
    /// floating island's capsule floats where its own top is; one hanging
    /// from the top edge hangs there too, with the row below the camera.
    static func frame(screen: CGRect, centerX: CGFloat, closedWidth: CGFloat, floats: Bool,
                      top: CGFloat, stripHeight: CGFloat) -> CGRect {
        let width = width(closedWidth: closedWidth, screenWidth: screen.width)
        let height = floats ? rowHeight : stripHeight + rowHeight - 6
        let x = min(max(screen.minX + 12, centerX - width / 2), screen.maxX - 12 - width)
        return CGRect(x: x, y: screen.maxY - top - height, width: width, height: height)
    }

    /// The row the content takes inside the capsule, from its top.
    static func rowTop(floats: Bool, stripHeight: CGFloat) -> CGFloat { floats ? 0 : stripHeight - 6 }
}
