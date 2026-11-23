// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the lock screen v2's full layer on the lock screen, fed by the
/// music, lyrics and job services. `ZenithLockScreenFullLayer` draws it.
struct ZenithLockScreenFullView: View {
    @ObservedObject var zenith: ZenithLockScreenV2Model
    let size: CGSize
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var lyrics = NotchLyricsService.shared
    @ObservedObject private var jobs = ZenithLockScreenJobs.shared
    @ObservedObject private var l10n = L10n.shared
    /// On while the layer shows and while it fades out; off, nothing ticks
    /// in a window no one sees.
    @State private var live = false

    var body: some View {
        let zenith = zenith
        let language = l10n.language
        let items = jobs.items
        ZenithLockScreenFullLayer(
            gates: zenith.gates, scheme: zenith.scheme, backdrop: zenith.backdrop, edgeRing: zenith.edgeRing,
            account: zenith.account, playback: music.playback, artwork: music.artwork,
            lyrics: ZenithLockScreenV2Model.timedLyrics(lyrics.lyrics, playback: music.playback),
            offset: ZenithLockScreenLyricTiming.offset(island: lyrics.offset, lockScreen: zenith.gates.lyricOffset),
            size: size, live: live,
            top: { date in ZenithLockScreenTopEntry.live(at: date, language: language, jobs: items) },
            onClose: { zenith.closeFull() })
            .task(id: zenith.fullShown) {
                if zenith.fullShown { live = true; return }
                try? await Task.sleep(nanoseconds: 450_000_000)
                if !Task.isCancelled, !zenith.fullShown { live = false }
            }
    }
}

/// Zenith fork: one item at the full layer's top right, ready to draw.
struct ZenithLockScreenTopEntry: Identifiable, Equatable {
    let item: ZenithLockScreenTopItem
    var symbol: String?
    var primary = ""
    var secondary: String?
    /// The jobs item draws its rings instead.
    var jobs: [ZenithLockScreenJob] = []
    var overflow = 0
    var id: ZenithLockScreenTopItem { item }

    /// What each item has to show now, read as the activity row reads it:
    /// the next prayer, the weather (never the place), the timer, the event
    /// counted down to, today's coding time and the long jobs. An item with
    /// nothing to show is left out.
    @MainActor static func live(at date: Date, language: AppLanguage,
                                jobs: [ZenithLockScreenJob]) -> [ZenithLockScreenTopItem: ZenithLockScreenTopEntry] {
        var entries: [ZenithLockScreenTopItem: ZenithLockScreenTopEntry] = [:]
        let arrangement = ZenithLockScreenJobLine.arrange(jobs)
        if !arrangement.isEmpty {
            entries[.jobs] = Self(item: .jobs, jobs: arrangement.shown, overflow: arrangement.overflow)
        }
        let sky = SkyService.shared
        if let day = sky.currentDay(now: date), let next = PrayerTimesSupport.next(after: date, in: day.moments) {
            entries[.prayer] = Self(item: .prayer, symbol: next.prayer.symbol, primary: sky.name(next.prayer, language: language),
                                    secondary: PrayerTimesSupport.clock(next.time, locale: language.formattingLocale()))
        }
        let weather = WeatherService.shared
        if let snapshot = weather.snapshot, WeatherSupport.isShowable(snapshot, now: date) {
            let unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.temperatureUnit) ?? "") ?? .celsius
            let range = snapshot.high.flatMap { high in snapshot.low.map { (high, $0) } }
            entries[.weather] = Self(item: .weather, symbol: WeatherSupport.symbol(code: snapshot.code, isDay: snapshot.isDay),
                                     primary: WeatherSupport.degrees(snapshot.temperature, unit: unit),
                                     secondary: range.map { WeatherSupport.degrees($0.0, unit: unit) + " / " + WeatherSupport.degrees($0.1, unit: unit) })
        }
        let timer = NotchTimerService.shared
        if timer.session.hasSession {
            let session = timer.session
            let finished = NotchLockScreenSupport.timerFinished(session, at: timer.now)
            let text = FeatureStrings.notchActivities(language)
            entries[.timer] = Self(item: .timer,
                                   symbol: finished ? "checkmark.circle.fill" : session.isPaused ? "pause.circle.fill"
                                       : session.countsUp ? "stopwatch.fill" : "timer",
                                   primary: finished ? text.finished : NotchTimerSupport.clockText(for: session, at: timer.now))
        }
        let calendar = NotchCalendarService.shared
        if let countdown = calendar.countdown, countdown.isShown(at: date, leadTime: calendar.countdownLeadTime) {
            entries[.calendar] = Self(item: .calendar, symbol: "calendar",
                                      primary: NotchCalendarStrip.displayTitle(countdown.event,
                                                                               untitled: FeatureStrings.notchCalendar(language).untitled),
                                      secondary: NotchCalendarSupport.countdownText(until: countdown.target, now: date))
        }
        if let seconds = WakaTimeService.shared.today?.totalSeconds, seconds > 0 {
            entries[.wakatime] = Self(item: .wakatime, symbol: NotchModule.wakatime.symbol,
                                      primary: WakaTimeSupport.duration(seconds, locale: Locale(identifier: language.rawValue)))
        }
        return entries
    }
}

/// Zenith fork: the full layer itself, opened by clicking the minimal lyric.
/// One colour from the cover (or the blurred cover) covers the screen; the
/// record with the song under it and the lyrics form one group in the middle;
/// the corners keep the clock, the top row with its close button, who is at
/// the Mac and how to log in. The Settings preview draws it with samples.
///
/// Only the close button and the song's buttons take clicks. The layer
/// leaves with the close button, Esc, the music stopping, or unlocking.
struct ZenithLockScreenFullLayer: View {
    let gates: ZenithLockScreenV2Gates
    let scheme: ZenithLockScreenPalette.Scheme
    let backdrop: ZenithLockScreenBackdropImage?
    let edgeRing: Bool
    let account: ZenithLockScreenAccount?
    let playback: NotchPlayback?
    let artwork: NSImage?
    /// Timed lines (`ZenithLockScreenV2Model.timedLyrics`), when there are.
    let lyrics: NotchLyrics?
    let offset: Double
    let size: CGSize
    var live = true
    /// The Settings preview: buttons are drawn and do nothing.
    var preview = false
    var top: (Date) -> [ZenithLockScreenTopItem: ZenithLockScreenTopEntry] = { _ in [:] }
    var onClose: () -> Void = {}
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: ZenithLockScreenV2Strings { ZenithStrings.lockScreenV2(l10n.language) }
    private var radial: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }

    var body: some View {
        let layout = ZenithLockScreenFullLayout(size: size)
        let ink = scheme.ink.color
        ZStack(alignment: .topLeading) {
            backdropView
            if live {
                if gates.fullClock {
                    clock(layout, ink: ink)
                        .padding(.leading, layout.margin)
                        .padding(.top, layout.clockTop)
                }
                if let playback {
                    column(playback, layout: layout, ink: ink)
                        .frame(width: layout.discSize)
                        .padding(.leading, layout.groupLeft)
                        .padding(.top, gates.fullDisc ? layout.columnTop : textColumnTop(layout))
                    lyricsColumn(playback, layout: layout, ink: ink)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if live { ZenithLockScreenTopRow(gates: gates, scheme: scheme, layout: layout, preview: preview,
                                             entries: top, onClose: onClose) }
        }
        .overlay(alignment: .bottomLeading) {
            if live { identity(layout, ink: ink) }
        }
        .overlay(alignment: .bottomTrailing) {
            if live, gates.fullLoginHint { loginHint(layout, ink: ink) }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.colorScheme, scheme.inkIsDark ? .light : .dark)
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: scheme)
    }

    /// Without the record the song's text sits level with where it would be.
    private func textColumnTop(_ layout: ZenithLockScreenFullLayout) -> CGFloat {
        (layout.discMiddle - (layout.columnHeight - layout.discSize - layout.titleGap) / 2).rounded()
    }

    /// One solid colour, or the cover blurred to fill the screen under a
    /// light dim, crossfading as the song changes.
    private var backdropView: some View {
        ZStack {
            scheme.background.color
            if gates.fullBackground == .blurredCover, let backdrop {
                Image(nsImage: backdrop.image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(Color.black.opacity(scheme.dim))
                    .id(backdrop.id)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .easeInOut(duration: 0.6), value: backdrop?.id)
        .accessibilityHidden(true)
    }

    // MARK: Corners

    private func clock(_ layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        let locale = Locale(identifier: l10n.language.rawValue)
        return TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 2 * layout.scale) {
                Text(context.date, format: Date.FormatStyle(locale: locale).weekday(.wide).month(.wide).day())
                    .font(.system(size: layout.dateSize, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.6))
                // The hour as the Mac's own settings write it, 12 or 24 hour.
                Text(context.date, format: Date.FormatStyle(date: .omitted, time: .shortened))
                    .font(.system(size: layout.timeSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
            }
            .lineLimit(1)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private func identity(_ layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        if gates.fullAccount || gates.fullDevice, let account {
            HStack(spacing: 14 * layout.scale) {
                if gates.fullAccount { photo(account, layout: layout, ink: ink) }
                VStack(alignment: .leading, spacing: 2 * layout.scale) {
                    if gates.fullAccount, !account.name.isEmpty {
                        Text(account.name)
                            .font(.system(size: layout.nameSize, weight: .semibold))
                            .foregroundStyle(ink)
                    }
                    if gates.fullDevice, !account.device.isEmpty {
                        Text(account.device)
                            .font(.system(size: layout.deviceSize, weight: .medium))
                            .foregroundStyle(ink.opacity(0.55))
                    }
                }
                .lineLimit(1)
            }
            .frame(height: layout.photoSize)
            .padding(.leading, layout.margin)
            .padding(.bottom, layout.identityBottom)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
        }
    }

    /// The account's own picture in a thin ring, or its initials.
    private func photo(_ account: ZenithLockScreenAccount, layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        let side = layout.photoSize
        return Group {
            if let image = account.photo {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                Circle().fill(ink.opacity(0.14)).overlay {
                    Text(account.initials)
                        .font(.system(size: side * 0.38, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.85))
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .padding(3 * layout.scale)
        .overlay(Circle().strokeBorder(ink.opacity(0.3), lineWidth: max(1, 1.25 * layout.scale)))
        .accessibilityHidden(true)
    }

    private func loginHint(_ layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        HStack(spacing: 9 * layout.scale) {
            Image(systemName: "touchid")
                .font(.system(size: layout.hintSize * 1.25, weight: .regular))
            Text(text.loginHint)
                .font(.system(size: layout.hintSize, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(ink.opacity(ZenithLockScreenFullLyrics.opacity(0.45, darkInk: scheme.inkIsDark)))
        // Level with the account, whose picture sets the corner's height.
        .frame(height: layout.photoSize + 6 * layout.scale)
        .padding(.trailing, layout.margin)
        .padding(.bottom, layout.identityBottom)
        .allowsHitTesting(false)
    }

    // MARK: Song

    /// The record, then the title, artist and progress on its left edge,
    /// and the buttons under its middle.
    private func column(_ playback: NotchPlayback, layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if gates.fullDisc {
                ZenithLockScreenRecord(image: artwork, size: layout.discSize, ink: ink, hubSize: layout.hubSize,
                                       edgeRing: edgeRing, spins: gates.fullDiscSpin && playback.isPlaying)
                    .padding(.bottom, layout.titleGap)
            }
            Text(playback.track.title ?? radial.mediaNowPlaying)
                .font(.system(size: layout.titleSize, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .frame(height: layout.titleLine, alignment: .leading)
            if let artist = playback.track.artist ?? playback.track.album {
                Text(artist)
                    .font(.system(size: layout.artistSize, weight: .medium))
                    .foregroundStyle(ink.opacity(0.62))
                    .lineLimit(1)
                    .frame(height: layout.artistLine, alignment: .leading)
                    .padding(.top, layout.artistGap)
            }
            if playback.duration > 0 {
                progress(playback, layout: layout, ink: ink)
                    .padding(.top, layout.progressGap)
            }
            ZenithLockScreenTransport(playback: playback, sideSize: layout.sideControlSize, mainSize: layout.mainControlSize,
                                      spacing: 26 * layout.scale, buttonWidth: 56 * layout.scale,
                                      buttonHeight: layout.controlsHeight, ink: ink, preview: preview)
                .frame(width: layout.discSize)
                .padding(.top, layout.controlsGap)
        }
        .frame(width: layout.discSize, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func progress(_ playback: NotchPlayback, layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        TimelineView(.animation(minimumInterval: 1, paused: !playback.isPlaying)) { context in
            let position = playback.position(at: context.date)
            let fraction = min(1, max(0, position / playback.duration))
            VStack(spacing: layout.timesGap) {
                Capsule()
                    .fill(ink.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(ink.opacity(0.9)).frame(width: layout.discSize * fraction)
                    }
                    .frame(width: layout.discSize, height: layout.barHeight)
                HStack {
                    Text(NotchLockScreenSupport.timestamp(position))
                    Spacer()
                    Text("−" + NotchLockScreenSupport.timestamp(playback.duration - position))
                }
                .font(.system(size: layout.timesSize, weight: .medium, design: .monospaced))
                .foregroundStyle(ink.opacity(0.6))
                .frame(height: layout.timesLine)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Lyrics

    /// The lyrics right of the record, the sung line level with its middle,
    /// fading out before the clock and before the bottom corners.
    @ViewBuilder private func lyricsColumn(_ playback: NotchPlayback, layout: ZenithLockScreenFullLayout,
                                           ink: Color) -> some View {
        if let timed = lyrics {
            let offset = offset
            let height = size.height
            TimelineView(.explicit(timed.changeDates(for: playback, offset: offset, from: .now))) { context in
                let active = timed.activeIndex(at: playback.position(at: context.date), offset: offset)
                lyricLines(timed, active: active, playback: playback, offset: offset, layout: layout, ink: ink)
            }
            // The stack's middle is the record's.
            .frame(width: layout.lyricsWidth, height: layout.discMiddle * 2)
            .padding(.leading, layout.lyricsLeft)
            .frame(width: size.width, height: height, alignment: .topLeading)
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: layout.lyricsTop / height),
                    .init(color: .black, location: (layout.lyricsTop + layout.lyricsFade) / height),
                    .init(color: .black, location: (layout.lyricsBottom - layout.lyricsFade) / height),
                    .init(color: .clear, location: layout.lyricsBottom / height),
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
        }
    }

    private enum Role: Equatable {
        case previous, active, upcoming(Int)
    }

    private struct Slot: Identifiable, Equatable {
        let index: Int
        let role: Role
        var id: Int { index }
    }

    /// The line before, the one being sung, and three after it, fainter and
    /// softer the further they are.
    private func lyricLines(_ lyrics: NotchLyrics, active: Int?, playback: NotchPlayback, offset: Double,
                            layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        let window = ZenithLockScreenLyricWindow.make(lineCount: lyrics.lines.count, active: active,
                                                      upcoming: ZenithLockScreenFullLyrics.upcoming)
        var slots: [Slot] = []
        if let previous = window.previous { slots.append(Slot(index: previous, role: .previous)) }
        if let active = window.active { slots.append(Slot(index: active, role: .active)) }
        slots += window.upcoming.enumerated().map { Slot(index: $0.element, role: .upcoming($0.offset)) }
        let stack = ZenithLockScreenLyricStack(spacing: layout.lineGap) {
            ForEach(slots) { slot in
                line(slot, lyrics: lyrics, playback: playback, offset: offset, layout: layout, ink: ink)
                    .transition(.opacity)
                    .layoutValue(key: ZenithLockScreenSungLineKey.self, value: slot.role == .active)
            }
        }
        return Group {
            if reduceMotion {
                // Reduce Motion: the lines change in place, with a fade only.
                ZStack {
                    stack.id(active ?? -1).transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: active)
            } else {
                stack.animation(.spring(response: 0.42, dampingFraction: 0.9), value: active)
            }
        }
    }

    private func line(_ slot: Slot, lyrics: NotchLyrics, playback: NotchPlayback, offset: Double,
                      layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        let isActive = slot.role == .active
        let grows = isActive && !reduceMotion
        let dark = scheme.inkIsDark
        let opacity: Double
        let blur: CGFloat
        switch slot.role {
        case .previous:
            opacity = ZenithLockScreenFullLyrics.opacity(ZenithLockScreenFullLyrics.previousOpacity, darkInk: dark)
            blur = ZenithLockScreenFullLyrics.previousBlur
        case .active:
            opacity = 1
            blur = 0
        case .upcoming(let distance):
            opacity = ZenithLockScreenFullLyrics.upcomingOpacity(distance, darkInk: dark)
            blur = ZenithLockScreenFullLyrics.upcomingBlur(distance)
        }
        return ZenithLockScreenSungLine(lyrics: lyrics, index: slot.index, playback: playback, offset: offset,
                                        karaoke: isActive && gates.karaoke, ink: ink, sungOpacity: opacity,
                                        restOpacity: ZenithLockScreenFullLyrics.opacity(ZenithLockScreenFullLyrics.restOpacity,
                                                                                        darkInk: dark))
            .font(.system(size: isActive ? layout.activeSize : layout.lineSize, weight: .heavy))
            .lineLimit(isActive ? 2 : 1)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.interpolate)
            .frame(width: layout.lyricsWidth, alignment: .leading)
            .blur(radius: blur * layout.scale)
            // The new line being sung grows in from a little smaller.
            .keyframeAnimator(initialValue: CGFloat(1), trigger: isActive) { content, scale in
                content.scaleEffect(grows ? scale : 1, anchor: .leading)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(0.95, duration: 0.01)
                    SpringKeyframe(1, duration: 0.45, spring: .smooth)
                }
            }
    }
}

/// Zenith fork: marks the line being sung for `ZenithLockScreenLyricStack`.
struct ZenithLockScreenSungLineKey: LayoutValueKey {
    static let defaultValue = false
}

/// Zenith fork: the full layer's lines one under another, moved so the line
/// being sung has its middle on the stack's middle, however many lines it
/// wraps to. Lines may reach past the stack's bounds; the layer masks them.
struct ZenithLockScreenLyricStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = ProposedViewSize(width: bounds.width, height: nil)
        let heights = subviews.map { $0.sizeThatFits(width).height }
        let tops = ZenithLockScreenLyricPlacement.tops(heights: heights, spacing: spacing,
                                                       active: subviews.firstIndex { $0[ZenithLockScreenSungLineKey.self] },
                                                       middle: bounds.midY)
        for (subview, top) in zip(subviews, tops) {
            subview.place(at: CGPoint(x: bounds.minX, y: top), anchor: .topLeading, proposal: width)
        }
    }
}

/// Zenith fork: the record on the full layer: the cover clipped to a circle
/// under faint grooves, a thin hub ring at its middle, and a thin ring at its
/// edge when the cover's rim is close to the background. With its switch on
/// it turns slowly while the song plays and coasts to a stop on pause; under
/// Reduce Motion it stays still.
struct ZenithLockScreenRecord: View {
    let image: NSImage?
    let size: CGFloat
    let ink: Color
    let hubSize: CGFloat
    let edgeRing: Bool
    let spins: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle = 0.0
    @State private var spinStart: Date?

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.07))
            TimelineView(.animation(paused: spinStart == nil)) { context in
                cover.rotationEffect(.degrees(spinStart.map {
                    ZenithLockScreenDiscSpin.angle(from: angle, startedAt: $0, at: context.date)
                } ?? angle))
            }
            ForEach(0..<9, id: \.self) { groove in
                let diameter = size * (0.42 + CGFloat(groove) * 0.065)
                Circle().stroke(.black.opacity(0.1), lineWidth: max(0.5, size / 700)).frame(width: diameter, height: diameter)
                Circle().stroke(.white.opacity(0.05), lineWidth: max(0.5, size / 700))
                    .frame(width: diameter + size / 160, height: diameter + size / 160)
            }
            // A soft sheen, as light catches vinyl; it stays put as the record turns.
            Circle().fill(AngularGradient(colors: [.white.opacity(0), .white.opacity(0.07), .white.opacity(0),
                                                   .white.opacity(0.05), .white.opacity(0)], center: .center))
            Circle().strokeBorder(.black.opacity(0.12), lineWidth: max(1, size / 350))
            if edgeRing {
                Circle().strokeBorder(ink.opacity(0.25), lineWidth: max(1, size / 240))
            }
            Circle().stroke(ink.opacity(0.35), lineWidth: max(1, size / 220))
                .frame(width: hubSize, height: hubSize)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: size * 0.08, y: size * 0.04)
        .onAppear { follow(spins && !reduceMotion) }
        .onChange(of: spins && !reduceMotion) { follow(spins && !reduceMotion) }
        .accessibilityHidden(true)
    }

    private var cover: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.16, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func follow(_ turning: Bool) {
        if turning {
            if spinStart == nil { spinStart = Date() }
        } else if let start = spinStart {
            // From full speed to a stop, eased, carried a little further.
            let current = ZenithLockScreenDiscSpin.angle(from: angle, startedAt: start, at: Date())
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                spinStart = nil
                angle = current
            }
            guard !reduceMotion else { return }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: ZenithLockScreenDiscSpin.stopDuration)) {
                    angle = current + ZenithLockScreenDiscSpin.coast
                }
            }
        }
    }
}

/// Zenith fork: the full layer's top row: the round close button at the
/// corner and, from it outward, the jobs, the next prayer, the weather, the
/// timer, the calendar and WakaTime, each with its switch on and something
/// to show.
struct ZenithLockScreenTopRow: View {
    let gates: ZenithLockScreenV2Gates
    let scheme: ZenithLockScreenPalette.Scheme
    let layout: ZenithLockScreenFullLayout
    let preview: Bool
    let entries: (Date) -> [ZenithLockScreenTopItem: ZenithLockScreenTopEntry]
    let onClose: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ink = scheme.ink.color
        HStack(spacing: layout.topItemGap) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let entries = entries(context.date)
                let items = ZenithLockScreenTopRight.items(gates, showing: Set(entries.keys))
                HStack(spacing: layout.topItemGap) {
                    // Listed from the button outward, drawn left to right.
                    ForEach(items.reversed().compactMap { entries[$0] }) { entry in
                        item(entry, ink: ink)
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: items)
            }
            .allowsHitTesting(false)
            closeButton(ink: ink)
        }
        .fixedSize()
        .frame(height: layout.closeSize)
        .padding(.trailing, layout.margin)
        .padding(.top, max(0, layout.topRowMiddle - layout.closeSize / 2))
    }

    private func item(_ entry: ZenithLockScreenTopEntry, ink: Color) -> some View {
        let size = layout.topItemSize
        return HStack(spacing: 7 * layout.scale) {
            if entry.item == .jobs {
                HStack(spacing: 18 * layout.scale) {
                    ForEach(entry.jobs) { job in
                        // Pastel rings read on dark colours; over a light one they take the ink.
                        ZenithLockScreenJobItem(job: job, ink: ink, colourful: !scheme.inkIsDark, fontSize: size)
                    }
                    if entry.overflow > 0 {
                        Text("+\(entry.overflow)").foregroundStyle(ink.opacity(0.55))
                    }
                }
            } else {
                if let symbol = entry.symbol { Image(systemName: symbol).foregroundStyle(ink) }
                Text(entry.primary).foregroundStyle(ink)
                if let secondary = entry.secondary {
                    Text(secondary).foregroundStyle(ink.opacity(ZenithLockScreenFullLyrics.opacity(0.6, darkInk: scheme.inkIsDark)))
                }
            }
        }
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private func closeButton(ink: Color) -> some View {
        Button { if !preview { onClose() } } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 15 * layout.scale, weight: .semibold))
                .foregroundStyle(ink)
                .frame(width: layout.closeSize, height: layout.closeSize)
                .background(Circle().fill(ink.opacity(0.16)))
                .contentShape(Circle())
        }
        .buttonStyle(ZenithLockScreenPressStyle())
        .accessibilityLabel(ZenithStrings.lockScreenV2(l10n.language).closeFull)
    }
}
