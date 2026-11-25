// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// The Mac tab's words and numbers: its hero, the health tiles, sound,
/// Zenith's tools and Send to Mac, on plain values like `PocketPresentation`.
public enum PocketMacPresentation {
    // MARK: Hero

    /// "**Your Mac runs at 38%,** cool and quiet."
    public static func sentence(_ state: PocketMacState?, freshness: PocketFreshness, now: Date) -> PocketSentence {
        guard let state, freshness.isReachable else {
            return PocketPresentation.controlSentence(state, freshness: freshness, now: now)
        }
        guard let health = state.health else {
            return PocketSentence(lead: "Reading ", value: "your Mac", after: "…", rest: "", tone: .quiet)
        }
        return PocketSentence(lead: "Your Mac runs at ", value: "\(health.cpuPercent)%", after: ",",
                              rest: feel(health) + ".", tone: cpuTone(health.cpuPercent))
    }

    /// "cool and quiet", "warm and busy", "running steady" without a sensor.
    public static func feel(_ health: PocketHealth) -> String {
        let load = health.cpuPercent < 25 ? "quiet" : health.cpuPercent < 60 ? "steady" : "busy"
        guard let celsius = health.temperature else { return "running " + load }
        let heat = celsius < 55 ? "cool" : celsius < 80 ? "warm" : "hot"
        return heat + " and " + load
    }

    public static func cpuTone(_ percent: Int) -> PocketTone {
        percent < 60 ? .good : percent < 85 ? .attention : .alert
    }

    public static func temperatureTone(_ celsius: Double) -> PocketTone {
        celsius < 80 ? .good : celsius < 95 ? .attention : .alert
    }

    /// Plenty of room reads as information; under 15% free it wants a look.
    public static func diskTone(free: Int64, total: Int64) -> PocketTone {
        guard total > 0 else { return .quiet }
        let share = Double(free) / Double(total)
        return share < 0.05 ? .alert : share < 0.15 ? .attention : .info
    }

    // MARK: Numbers

    /// "230G", "1.4T", "820M": short enough for a tile.
    public static func bytes(_ value: Int64) -> String {
        let units: [(Double, String)] = [(1e12, "T"), (1e9, "G"), (1e6, "M"), (1e3, "K")]
        let number = Double(max(0, value))
        for (size, unit) in units where number >= size {
            let scaled = number / size
            return (scaled < 10 ? String(format: "%.1f", scaled) : String(Int(scaled.rounded()))) + unit
        }
        return "\(Int(number))B"
    }

    /// "1.2 MB/s", "84 KB/s", "0 B/s".
    public static func rate(_ bytesPerSecond: Int64) -> String {
        let number = Double(max(0, bytesPerSecond))
        for (size, unit) in [(1e9, "GB/s"), (1e6, "MB/s"), (1e3, "KB/s")] where number >= size {
            let scaled = number / size
            return (scaled < 10 ? String(format: "%.1f", scaled) : String(Int(scaled.rounded()))) + " " + unit
        }
        return "\(Int(number)) B/s"
    }

    /// "12.3%", "4%".
    public static func share(_ cpu: Double) -> String {
        guard cpu.isFinite else { return "0%" }
        return cpu < 10 ? String(format: "%.1f%%", cpu) : "\(Int(cpu.rounded()))%"
    }

    // MARK: Sound

    public static func outputSymbol(_ kind: String) -> String {
        switch kind {
        case "airpods": return "airpods"
        case "headphones": return "headphones"
        case "display": return "display"
        case "bluetooth": return "hifispeaker"
        case "speakers": return "speaker.wave.2"
        default: return "hifispeaker.2"
        }
    }

    public static func volumeSymbol(_ volume: Int, muted: Bool) -> String {
        if muted || volume == 0 { return "speaker.slash.fill" }
        return volume < 34 ? "speaker.wave.1.fill" : volume < 67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
    }

    /// The output playing now, for the section's label.
    public static func currentOutput(_ sound: PocketSound) -> String? {
        sound.outputs.first(where: \.current)?.name
    }

    // MARK: Tools

    /// What the timer tile says: "24:12", "paused · 12:03", "Focus done", "Start".
    public static func timerLine(_ timer: PocketTools.Timer?, now: Date) -> String {
        guard let timer else { return "Start" }
        if timer.paused { return "paused · " + PocketPresentation.clock(timer.remaining ?? 0) }
        if let ends = timer.endsAt { return PocketPresentation.clock(max(0, ends.timeIntervalSince(now))) }
        return timer.label
    }

    /// Seconds left on a running countdown, for its ring.
    public static func timerLeft(_ timer: PocketTools.Timer?, now: Date) -> TimeInterval? {
        guard let timer else { return nil }
        if timer.paused { return timer.remaining }
        return timer.endsAt.map { max(0, $0.timeIntervalSince(now)) }
    }

    /// ":3000 · :5173", or "none running".
    public static func devServersLine(_ servers: [PocketTools.DevServer]) -> String {
        servers.isEmpty ? "none running" : servers.prefix(3).map { ":\($0.port)" }.joined(separator: " · ")
    }

    /// "in 18m", "now · ends in 10m".
    public static func eventLine(_ event: PocketTools.Event, now: Date) -> String {
        if event.start <= now {
            guard let end = event.end else { return "now" }
            return "now · ends " + PocketPresentation.countdown(to: end, now: now)
        }
        return PocketPresentation.countdown(to: event.start, now: now)
    }

    // MARK: Send to Mac

    /// The phone fills the drop slots in turn: the one after the last used.
    public static func nextSlot(after last: Int?) -> Int {
        guard let last else { return 0 }
        return (last + 1) % PocketPairing.dropSlots
    }
}

extension PocketDrop {
    /// The most a drop's data may weigh so its sealed box stays under the
    /// relay's 350 000 characters: the data is base64 in the JSON and the
    /// sealed box is base64 again (4/3 twice, plus escaped slashes).
    public static let fitBytes = maxBytes

    /// The characters a sealed drop of `dataBytes` takes, as the relay sees it.
    public static func sealedLength(dataBytes: Int, nameLength: Int = 40) -> Int {
        // JSON: Data as base64 with `/` escaped (one in 64 characters), the
        // envelope's id, date, sender and the name.
        let base64 = (dataBytes + 2) / 3 * 4
        let json = base64 + base64 / 64 + nameLength + 160
        // ChaChaPoly's nonce and tag, then base64 again.
        return (json + 28 + 2) / 3 * 4
    }
}
