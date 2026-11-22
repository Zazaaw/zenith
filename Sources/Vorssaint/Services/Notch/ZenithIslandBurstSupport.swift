// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

// Zenith fork: a burst is the island itself growing for a moment: a
// prayer's time coming, the charger plugged in, held or pulled out. It rides
// the island's own notice (NotchNotice.zenith), so the strip or pill on
// screen morphs into the bigger island through the window host's spring and
// blur (ZenithIslandMorph), stays a few seconds while a thin line empties,
// and shrinks back into whatever the closed island shows. Nothing is drawn
// over the island: there is one surface. Compiled into the tests.

struct ZenithIslandBurst: Equatable {
    enum Content: Equatable {
        case prayer(ZenithPrayerBurst)
        case charge(ZenithChargeBurst)
        /// Back at the Mac: "Welcome back, Faiz", right after unlocking.
        case welcome(ZenithWelcomeBurst)
        /// An agent waiting on the person: "Claude needs you".
        case agent(ZenithAgentBurst)
        /// An iPhone asked how the Mac is (RemoteControlService): "Faiz’s iPhone checked status".
        case remote(ZenithRemoteBurst)
    }

    let content: Content
    /// When it grew, for the line that empties while it stays.
    let start: Date
    let duration: TimeInterval

    init(_ content: Content, start: Date) {
        self.content = content
        self.start = start
        switch content {
        case .prayer: duration = ZenithIslandBurstTiming.prayer
        case .charge(let charge): duration = charge.state == .onBattery ? ZenithIslandBurstTiming.unplugged
            : ZenithIslandBurstTiming.charge
        case .welcome: duration = ZenithIslandBurstTiming.welcome
        case .agent: duration = ZenithIslandBurstTiming.agent
        case .remote: duration = ZenithIslandBurstTiming.remote
        }
    }

    /// The island notice it rides: a prayer's time comes like a timer's
    /// end, the charger like the battery's own notice, so a level the
    /// person moves (volume, brightness) still takes its place.
    var event: NotchEvent {
        switch content {
        case .prayer, .welcome, .remote: return .timer
        case .charge: return .battery
        case .agent: return .agents
        }
    }

    /// The page a click opens, if any.
    var module: NotchModule? {
        switch content {
        case .prayer: return .sky
        case .charge, .welcome, .remote: return nil
        case .agent: return .agents
        }
    }

    var title: String {
        switch content {
        case .prayer(let prayer): return prayer.title
        case .charge(let charge): return charge.title
        case .welcome(let welcome): return welcome.title
        case .agent(let agent): return agent.title
        case .remote(let remote): return remote.device
        }
    }

    var subtitle: String {
        switch content {
        case .prayer(let prayer): return prayer.subtitle
        case .charge(let charge): return charge.subtitle
        case .welcome(let welcome): return welcome.subtitle
        case .agent(let agent): return agent.subtitle
        case .remote(let remote): return remote.subtitle
        }
    }

    var accessibilityText: String {
        switch content {
        case .prayer(let prayer):
            return [prayer.title, prayer.subtitle, prayer.next.map { prayer.nextLabel + " " + $0 } ?? ""]
                .filter { !$0.isEmpty }.joined(separator: ", ")
        case .charge(let charge):
            return [charge.percent.map { "\($0)%" } ?? "", charge.title, charge.subtitle]
                .filter { !$0.isEmpty }.joined(separator: ", ")
        case .welcome, .agent, .remote:
            return [title, subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        }
    }

    /// How much of the line is left at `now`: 1 as it grows, 0 as it goes.
    func remaining(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - now.timeIntervalSince(start) / duration))
    }
}

/// “Waktunya Ashar”, “15.04 · Kemenag RI”, and the next prayer.
struct ZenithPrayerBurst: Equatable {
    let symbol: String
    let title: String
    let subtitle: String
    /// “Next”.
    let nextLabel: String
    /// “Maghrib 18.02”, when another prayer follows.
    let next: String?
}

/// "Welcome back, Faiz" over "Locked for 2h 14m", the green open padlock
/// before them and the account's picture after.
struct ZenithWelcomeBurst: Equatable {
    let title: String
    let subtitle: String
    /// The account's picture, or its initials when it has none.
    var photo: NSImage?
    var initials: String = ""
}

/// "Claude needs you" over the project's folder, with the agent's mark.
struct ZenithAgentBurst: Equatable {
    let provider: AgentProvider
    let title: String
    let subtitle: String
}

/// "Faiz’s iPhone checked status": the iPhone's glyph, the device's name, what
/// it did, and an eye at the end. English, like the answer the iPhone reads.
struct ZenithRemoteBurst: Equatable {
    let device: String
    var subtitle: String = RemoteText.checkedStatus
}

/// What the charger is doing, from the battery's reading.
enum ZenithChargeState: Equatable {
    /// Filling.
    case charging
    /// Plugged in but not filling short of full: Optimized Battery Charging
    /// or the charge limit holds it.
    case held
    /// Plugged in and full.
    case full
    case onBattery

    static func of(external: Bool, charging: Bool, percent: Int?) -> ZenithChargeState {
        guard external else { return .onBattery }
        if charging { return .charging }
        return (percent ?? 100) >= 100 ? .full : .held
    }
}

struct ZenithChargeBurst: Equatable {
    let state: ZenithChargeState
    let percent: Int?
    let title: String
    let subtitle: String
    let tone: ZenithNotice.Tone

    /// What the island says for `state`: green while it fills, with the time
    /// to full when macOS has one; amber while held, in macOS's own words;
    /// on battery, the time left, tinted by how much is left. `hint` takes
    /// the subtitle's place while filling (the charge reaching its level).
    static func make(_ state: ZenithChargeState, percent: Int?, minutes: Int?, hint: String? = nil,
                     island: ZenithIslandStrings, notices: ZenithNoticeStrings, locale: Locale) -> ZenithChargeBurst {
        let percent = percent.map(ZenithNoticeFormat.clamped)
        func time(_ template: String) -> String? {
            minutes.map { ZenithPowerFormat.filling(template, minutes: $0, locale: locale) }
        }
        switch state {
        case .charging:
            return ZenithChargeBurst(state: state, percent: percent, title: notices.charging,
                                     subtitle: hint ?? time(island.fullIn) ?? notices.chargerConnected, tone: .green)
        case .held:
            return ZenithChargeBurst(state: state, percent: percent, title: island.onHold,
                                     subtitle: island.optimizedCharging, tone: .amber)
        case .full:
            return ZenithChargeBurst(state: state, percent: percent, title: island.charged,
                                     subtitle: notices.chargerConnected, tone: .green)
        case .onBattery:
            let tone: ZenithNotice.Tone = percent.map { $0 <= 10 ? .red : $0 <= 20 ? .amber : .white } ?? .white
            return ZenithChargeBurst(state: state, percent: percent, title: notices.onBattery,
                                     subtitle: time(island.left) ?? notices.chargerRemoved, tone: tone)
        }
    }

    /// The bolt rides the fill while a charger is in.
    var bolt: Bool { state != .onBattery }
}

enum ZenithIslandBurstTiming {
    /// A prayer's time: long enough to read the next one too.
    static let prayer: TimeInterval = 8
    /// The charger plugged in, or the charge held.
    static let charge: TimeInterval = 3.2
    /// The charger pulled out: briefly.
    static let unplugged: TimeInterval = 2.6
    /// Back from the lock screen, and an agent asking for the person.
    static let welcome: TimeInterval = 3
    static let agent: TimeInterval = 2.6
    /// An iPhone checking on the Mac: a glance.
    static let remote: TimeInterval = 2

    /// How long a burst waits for an open or busy island to close before it
    /// is dropped: a prayer's time is worth waiting for, a greeting only a
    /// moment, a charger's moment not at all.
    static func patience(_ content: ZenithIslandBurst.Content) -> TimeInterval {
        switch content {
        case .prayer: return 120
        case .welcome, .agent, .remote: return 5
        case .charge: return 0
        }
    }

    /// Where a burst is in its life: growing in and staying with the line
    /// emptying, or gone back into the island.
    enum Phase: Equatable {
        case shown(remaining: Double)
        case settled
    }

    static func phase(_ burst: ZenithIslandBurst, at now: Date) -> Phase {
        now.timeIntervalSince(burst.start) < burst.duration ? .shown(remaining: burst.remaining(at: now)) : .settled
    }

    /// Whether a burst may take the island from the one showing: a prayer
    /// is not cut short by a charger, anything else gives way to the newer.
    static func replaces(_ current: ZenithIslandBurst?, with incoming: ZenithIslandBurst, at now: Date) -> Bool {
        guard let current, phase(current, at: now) != .settled else { return true }
        if case .prayer = current.content {
            switch incoming.content {
            case .charge, .welcome, .agent, .remote: return false
            case .prayer: break
            }
        }
        return true
    }
}

/// The burst's island: a row right below the camera, with the open
/// island's padding beside and below it (ZenithIslandInset). The row's
/// pieces and the gaps between them are measured here from the same
/// constants the views lay them out with (`row(_:)`), so the island is never
/// narrower than what it draws. Past the widest island the subtitle wraps to
/// a second line instead of truncating.
enum ZenithIslandBurstLayout {
    // Prayer.
    static let tile: CGFloat = 46
    static let tileGap: CGFloat = 14
    static let columnGap: CGFloat = 24
    /// The tile's row: the title and subtitle centre against the tile.
    static let prayerRow: CGFloat = tile
    static let progressHeight: CGFloat = 3
    static let progressGap: CGFloat = 12
    static let prayerTitleFont = NSFont.systemFont(ofSize: 17, weight: .semibold)
    static let prayerSubtitleFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    static let nextLabelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let nextValueFont = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
    // Charge.
    /// The title over the subtitle, which the battery centres against.
    static let chargeRow: CGFloat = 36
    static let chargeTitleFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
    static let chargeSubtitleFont = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .regular)
    static let figureFont = NSFont.monospacedDigitSystemFont(ofSize: ZenithNoticeLayout.figureSize, weight: .semibold)
    /// Between the battery and its percentage (ZenithBatteryFigure).
    static let figureGap: CGFloat = 12
    /// Between a title and the subtitle below it.
    static let lineSpacing: CGFloat = 2
    /// What a subtitle's second line adds to its row.
    static let lineHeight: CGFloat = 16
    /// What a title's second line adds, where the title is what wraps.
    static let titleLineHeight: CGFloat = 19
    /// A line of text drawn by SwiftUI can come out a point or two wider than
    /// AppKit measures it; each piece of text keeps this much over.
    static let textSlack: CGFloat = 2
    // Welcome, agent, and the lock screen's remote lock: a tile, two lines,
    // and (welcome) the picture.
    static let welcomeRow: CGFloat = 38
    static let markSide: CGFloat = 36
    /// The tile's corner: rounded like the prayer's, scaled to its side.
    static let markRadius: CGFloat = 11
    static let photoSide: CGFloat = 36
    // Remote: one line, the iPhone, the name, what it did and the eye.
    static let remoteRow: CGFloat = 26
    static let remoteGlyph: CGFloat = 18
    static let remoteGap: CGFloat = 10
    /// Between the name and what it did, on the one line.
    static let remoteWordGap: CGFloat = 7
    static let remoteDetailFont = NSFont.systemFont(ofSize: 15, weight: .regular)

    /// A burst's row from left to right: fixed pieces (glyphs, tiles, the
    /// battery, the next prayer, the picture) with their gaps before and
    /// after the words, and the words' own widths.
    struct Row: Equatable {
        /// Everything before the words, the gap to them included.
        var leading: CGFloat
        /// Everything after the words, the gap from them included.
        var trailing: CGFloat = 0
        var title: CGFloat
        var subtitle: CGFloat
        /// Set when the title and subtitle share one line, this far apart
        /// (the remote status); otherwise the subtitle is below the title.
        var inlineGap: CGFloat? = nil
        /// Whether the title, rather than the subtitle, takes the second
        /// line: "Locked from {a long device name}" over "just now".
        var wrapsTitle = false

        /// The row's width on one line, the gaps included.
        var width: CGFloat {
            let words = inlineGap.map { title + (subtitle > 0 ? $0 + subtitle : 0) } ?? max(title, subtitle)
            return leading + words + trailing
        }

        /// Whether the words fit `content` points on `lines` lines: on one,
        /// the whole row; on two, the line that wraps within two and the
        /// other on its own.
        func fits(_ content: CGFloat, lines: Int) -> Bool {
            guard lines > 1 else { return width <= content + 0.5 }
            let room = content - leading - trailing + 0.5
            return wrapsTitle ? title <= room * 2 && subtitle <= room : title <= room && subtitle <= room * 2
        }
    }

    /// A line of text, with the room SwiftUI may draw it in.
    static func words(_ text: String, _ font: NSFont) -> CGFloat {
        let width = ZenithIslandRoom.measure(text, font: font)
        return width > 0 ? width + textSlack : 0
    }

    /// The battery and its percentage, as ZenithBatteryFigure draws them:
    /// the body, its nub and the gap to it, then the figure.
    static func figureWidth(percent: Int?) -> CGFloat {
        let battery = ZenithNoticeLayout.batteryWidth + 4
        guard let percent else { return battery }
        return battery + figureGap + words("\(ZenithNoticeFormat.clamped(percent))%", figureFont)
    }

    /// The next prayer's column, the label over the time.
    static func nextWidth(_ prayer: ZenithPrayerBurst) -> CGFloat {
        prayer.next.map { max(words(prayer.nextLabel, nextLabelFont), words($0, nextValueFont)) } ?? 0
    }

    static func row(_ burst: ZenithIslandBurst) -> Row {
        switch burst.content {
        case .prayer(let prayer):
            let next = nextWidth(prayer)
            return Row(leading: tile + tileGap, trailing: next > 0 ? columnGap + next : 0,
                       title: words(prayer.title, prayerTitleFont), subtitle: words(prayer.subtitle, prayerSubtitleFont))
        case .charge(let charge):
            return Row(leading: figureWidth(percent: charge.percent) + columnGap,
                       title: words(charge.title, chargeTitleFont), subtitle: words(charge.subtitle, chargeSubtitleFont))
        case .welcome(let welcome):
            return Row(leading: markSide + tileGap, trailing: columnGap + photoSide,
                       title: words(welcome.title, chargeTitleFont), subtitle: words(welcome.subtitle, chargeSubtitleFont))
        case .agent(let agent):
            return Row(leading: markSide + tileGap,
                       title: words(agent.title, chargeTitleFont), subtitle: words(agent.subtitle, chargeSubtitleFont))
        case .remote(let remote):
            return Row(leading: remoteGlyph + remoteGap, trailing: columnGap + remoteGlyph,
                       title: words(remote.device, chargeTitleFont), subtitle: words(remote.subtitle, remoteDetailFont),
                       inlineGap: remoteWordGap)
        }
    }

    /// The rows' height on `lines` lines, without the strip above them or
    /// the room below.
    static func contentHeight(_ burst: ZenithIslandBurst, lines: Int = 1) -> CGFloat {
        let more = CGFloat(max(1, min(2, lines)) - 1)
        switch burst.content {
        case .prayer: return prayerRow + more * lineHeight + progressGap + progressHeight
        case .charge, .agent: return chargeRow + more * lineHeight
        case .welcome: return welcomeRow + more * lineHeight
        // Two lines put what it did below the name, as a welcome reads.
        case .remote: return more > 0 ? welcomeRow : remoteRow
        }
    }

    /// Below the rows: the island's padding, or a floating capsule's even
    /// room above and below and its margin.
    static func bottomInset(geometry: NotchGeometry) -> CGFloat {
        geometry.floats ? ZenithIslandRoom.vertical + (geometry.floatingGap ?? 0) : ZenithIslandInset.padding
    }

    /// The content's width on one line, the gaps included.
    static func contentWidth(_ burst: ZenithIslandBurst) -> CGFloat { row(burst).width }

    /// Where the row starts from the island's top: right below the camera's
    /// strip, or inside a floating capsule's margin and room.
    static func rowTop(geometry: NotchGeometry) -> CGFloat {
        geometry.floats ? (geometry.floatingGap ?? 0) + ZenithIslandRoom.vertical
            : geometry.stripHeight + ZenithIslandInset.belowCamera
    }

    /// The island for a burst, the lines its words take and the room it
    /// leaves them.
    struct Fit: Equatable {
        let size: CGSize
        let lines: Int
        /// The row's width inside the island's edges and shoulders.
        let content: CGFloat
    }

    /// One line, as wide as it needs by the room rule; past the widest
    /// island, the subtitle on a second line.
    static func fit(_ burst: ZenithIslandBurst, geometry: NotchGeometry) -> Fit {
        fit(row(burst), height: { contentHeight(burst, lines: $0) }, top: rowTop(geometry: geometry),
            bottom: bottomInset(geometry: geometry), minimum: minimumWidth(burst), floats: geometry.floats,
            screenWidth: geometry.screen.width)
    }

    /// The island around `row`, `top` points from the island's top to the
    /// row and `bottom` below it, whose rows are `height(lines)` tall: as
    /// wide as the row on one line by the room rule, at least `minimum` and
    /// the island it covers, and on two lines once that is the widest.
    static func fit(_ row: Row, height: (Int) -> CGFloat, top: CGFloat, bottom: CGFloat, minimum: CGFloat,
                    covering: CGFloat = 0, floats: Bool, screenWidth: CGFloat) -> Fit {
        let edge = ZenithIslandRoom.edge(floats: floats)
        func island(lines: Int) -> Fit {
            let total = top + height(lines) + bottom
            // A floating capsule draws its pill inside the same shoulders (NotchLayout.capsuleBody).
            let shoulder = NotchLayout.shoulder(height: total)
            let width = ZenithIslandRoom.width(content: row.width, shoulder: shoulder, covering: covering,
                                               minimum: minimum, edge: edge, screenWidth: screenWidth)
            return Fit(size: CGSize(width: width, height: total), lines: lines,
                       content: ZenithIslandRoom.contentWidth(width: width, shoulder: shoulder, edge: edge))
        }
        let one = island(lines: 1)
        return row.fits(one.content, lines: 1) ? one : island(lines: 2)
    }

    static func size(_ burst: ZenithIslandBurst, geometry: NotchGeometry) -> CGSize {
        fit(burst, geometry: geometry).size
    }

    /// A charge says little; it keeps a smaller island than a prayer.
    static func minimumWidth(_ burst: ZenithIslandBurst) -> CGFloat {
        switch burst.content {
        case .charge, .welcome, .agent: return 360
        case .remote: return 320
        case .prayer: return ZenithIslandRoom.minimumWidth
        }
    }
}
