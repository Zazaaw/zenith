// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the lock screen v2's minimal layer on the lock screen, fed by
/// the music and lyrics services. `ZenithLockScreenMinimalLayer` draws it.
struct ZenithLockScreenMinimalView: View {
    @ObservedObject var model: NotchLockScreenModel
    @ObservedObject var zenith: ZenithLockScreenV2Model
    let size: CGSize
    /// The title line's top, from the panel's top.
    let titleTop: CGFloat
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var lyrics = NotchLyricsService.shared

    var body: some View {
        let playback = model.showsMusic(music.playback) ? music.playback : nil
        let zenith = zenith
        ZenithLockScreenMinimalLayer(
            gates: zenith.gates, playback: playback,
            lyrics: ZenithLockScreenV2Model.timedLyrics(lyrics.lyrics, playback: playback),
            offset: ZenithLockScreenLyricTiming.offset(island: lyrics.offset, lockScreen: zenith.gates.lyricOffset),
            size: size, titleTop: titleTop, fullShown: zenith.fullShown, hintAvailable: zenith.hintAvailable,
            openFull: { zenith.openFull() }, noteHint: { zenith.noteHintShown() })
    }
}

/// Zenith fork: the minimal layer itself, over the wallpaper and under the
/// activity row: the song's title and artist on one line, with no cover, and
/// right under it the line being sung with the next one, as one block over a
/// soft shade. The Settings preview draws it with sample content.
///
/// Clicking the title opens a small glass card with the song's controls,
/// which folds back after four seconds left alone. Clicking the lyric opens
/// the full layer. The panel takes clicks only where these draw.
struct ZenithLockScreenMinimalLayer: View {
    let gates: ZenithLockScreenV2Gates
    let playback: NotchPlayback?
    /// Timed lines (`ZenithLockScreenV2Model.timedLyrics`), when there are.
    let lyrics: NotchLyrics?
    /// Seconds the lines are moved by (`ZenithLockScreenLyricTiming`).
    let offset: Double
    let size: CGSize
    let titleTop: CGFloat
    var fullShown = false
    var hintAvailable = false
    /// Off in the Settings preview: nothing opens, nothing is counted.
    var interactive = true
    var openFull: () -> Void = {}
    var noteHint: () -> Void = {}
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var interactions = 0
    @State private var hoveringCard = false
    @State private var hoveringLyric = false

    private typealias Layout = ZenithLockScreenMinimalLayout
    private var text: ZenithLockScreenV2Strings { ZenithStrings.lockScreenV2(l10n.language) }
    private var radial: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var lyricWidth: CGFloat { max(160, min(size.width - 32, Layout.lyricWidth)) }

    var body: some View {
        VStack(spacing: 0) {
            if let playback {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        if expanded, gates.titleControls, interactive {
                            ZenithLockScreenTitleCard(playback: playback, width: min(Layout.cardWidth, size.width - 32),
                                                      hovering: $hoveringCard) { interactions += 1 }
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        } else {
                            title(playback)
                                .transition(.opacity)
                        }
                    }
                    lyric(playback)
                        .padding(.top, Layout.lyricGap)
                }
                .background { if gates.lyricShade { shade } }
                .anchorPreference(key: ZenithLockScreenPartBounds.self, value: .bounds) { [.nowPlaying: $0] }
            }
        }
        .padding(.top, titleTop)
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .opacity(fullShown ? 0 : 1)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: fullShown)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.32), value: expanded)
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: playback == nil)
        // Left alone for four seconds, the card folds back into the title.
        .task(id: "\(expanded) \(interactions) \(hoveringCard)") {
            guard expanded, !hoveringCard else { return }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            expanded = false
        }
        .onChange(of: playback == nil) { if playback == nil { expanded = false } }
        .onChange(of: fullShown) { if fullShown { expanded = false } }
    }

    /// A soft dark glow behind the title and the lyric, so white type reads
    /// over a light wallpaper. One gradient, never redrawn per frame; it
    /// takes no clicks.
    private var shade: some View {
        GeometryReader { proxy in
            EllipticalGradient(stops: [.init(color: .black.opacity(0.4), location: 0),
                                       .init(color: .black.opacity(0.24), location: 0.45),
                                       .init(color: .black.opacity(0), location: 1)],
                               center: .center)
                .frame(width: proxy.size.width + Layout.shadeReach.width * 2,
                       height: proxy.size.height + Layout.shadeReach.height * 2)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Title

    private func title(_ playback: NotchPlayback) -> some View {
        let line = HStack(spacing: 7) {
            Text(playback.track.title ?? radial.mediaNowPlaying)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .layoutPriority(1)
            if let artist = playback.track.artist ?? playback.track.album {
                Text(artist)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .lineLimit(1)
        .frame(maxWidth: lyricWidth)
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: lyricWidth)
        .zenithLegibleOnWallpaper()
        return Group {
            if gates.titleControls, interactive {
                Button {
                    expanded = true
                    interactions += 1
                } label: {
                    line.padding(.horizontal, 10).padding(.vertical, Layout.titlePadding).contentShape(Rectangle())
                }
                .buttonStyle(ZenithLockScreenPressStyle())
                .accessibilityLabel(text.songControls)
                .accessibilityValue([playback.track.title, playback.track.artist].compactMap { $0 }.joined(separator: ", "))
            } else {
                line.padding(.vertical, Layout.titlePadding).accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Lyric

    @ViewBuilder private func lyric(_ playback: NotchPlayback) -> some View {
        if gates.lyrics, playback.isPlaying, let timed = lyrics {
            let offset = offset
            let block = TimelineView(.explicit(timed.changeDates(for: playback, offset: offset, from: .now))) { context in
                lines(timed, active: timed.activeIndex(at: playback.position(at: context.date), offset: offset),
                      playback: playback, offset: offset)
            }
            .frame(width: lyricWidth)
            .contentShape(Rectangle())
            Group {
                if gates.full, interactive {
                    Button { openFull() } label: { block }
                        .buttonStyle(.plain)
                        .accessibilityLabel(text.fullLyrics)
                } else {
                    block
                }
            }
            .onHover { inside in
                guard interactive else { return }
                hoveringLyric = inside
                if inside, gates.full { noteHint() }
            }
            .overlay(alignment: .bottom) {
                if hoveringLyric, gates.full, hintAvailable {
                    hint.alignmentGuide(.bottom) { $0[.top] - 12 }
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: hoveringLyric)
        }
    }

    private func lines(_ lyrics: NotchLyrics, active: Int?, playback: NotchPlayback, offset: Double) -> some View {
        let window = ZenithLockScreenLyricWindow.make(lineCount: lyrics.lines.count, active: active, upcoming: 1)
        return ZStack(alignment: .top) {
            VStack(spacing: Layout.lineSpacing) {
                if let index = window.active {
                    ZenithLockScreenSungLine(lyrics: lyrics, index: index, playback: playback, offset: offset,
                                             karaoke: gates.karaoke, ink: .white)
                        .font(.system(size: 23, weight: .bold))
                        .lineLimit(2)
                }
                if let next = window.upcoming.first {
                    Text(ZenithLockScreenSungLine.shown(lyrics.lines[next].text))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.center)
            .frame(width: lyricWidth)
            .zenithLegibleOnWallpaper()
            .id(active ?? -1)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity.combined(with: .offset(y: -8))))
        }
        // Quick, so the new line is in place as it starts to be sung.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.28), value: active)
    }

    private var hint: some View {
        Text(text.lyricHint)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .modifier(ZenithLockScreenGlass(cornerRadius: 13))
            .allowsHitTesting(false)
    }
}

/// Zenith fork: the title opened: cover, title and artist, the buttons, the
/// timeline. Only on the lock screen itself, where the song can be played.
struct ZenithLockScreenTitleCard: View {
    let playback: NotchPlayback
    let width: CGFloat
    @Binding var hovering: Bool
    var onInteraction: () -> Void = {}
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let radial = FeatureStrings.radialMenu(l10n.language)
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                NotchArtwork(image: music.artwork, size: 32, source: playback.track)
                VStack(alignment: .leading, spacing: 1) {
                    Text(playback.track.title ?? radial.mediaNowPlaying)
                        .font(.system(size: 13, weight: .semibold))
                    if let artist = playback.track.artist ?? playback.track.album {
                        Text(artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                ZenithLockScreenTransport(playback: playback, sideSize: 15, mainSize: 19, spacing: 4,
                                          buttonWidth: 34, buttonHeight: 32, onCommand: onInteraction)
            }
            NotchMusicTimeline(playback: playback, service: music, tint: .white, timesBeside: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: width)
        .modifier(ZenithLockScreenGlass(cornerRadius: 18))
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ZenithStrings.lockScreenV2(l10n.language).songControls)
    }
}

/// Zenith fork: the line being sung. With karaoke the words sung so far are
/// bright, the one being sung fades in from its first letter with a soft
/// edge, and the rest stay dim, worked out from the time spent in the line;
/// no word is ever left half lit. Without karaoke the whole line is bright.
struct ZenithLockScreenSungLine: View {
    let lyrics: NotchLyrics
    let index: Int
    let playback: NotchPlayback
    let offset: Double
    let karaoke: Bool
    let ink: Color
    var sungOpacity = 0.95
    var restOpacity = 0.5

    /// An empty line is a pause in the singing.
    static func shown(_ text: String) -> String { text.isEmpty ? "♪" : text }

    var body: some View {
        let text = Self.shown(lyrics.lines[index].text)
        if karaoke {
            TimelineView(.animation(minimumInterval: 0.05, paused: !playback.isPlaying)) { context in
                Text(attributed(text, at: context.date))
            }
        } else {
            Text(text).foregroundStyle(ink.opacity(sungOpacity))
        }
    }

    private func attributed(_ text: String, at date: Date) -> AttributedString {
        let line = lyrics.lines[index]
        let next = lyrics.lines.indices.contains(index + 1) ? lyrics.lines[index + 1].time + offset : nil
        let progress = ZenithLockScreenKaraoke.progress(start: line.time + offset, next: next, characters: text.count,
                                                        position: playback.position(at: date))
        let levels = ZenithLockScreenKaraoke.levels(text, progress: progress)
        var string = AttributedString(text)
        string.foregroundColor = ink.opacity(restOpacity)
        let characters = string.characters
        var cursor = characters.startIndex
        var offset = 0
        // A run of characters at one level shares one colour.
        while offset < levels.count, cursor < characters.endIndex {
            let level = levels[offset]
            var end = characters.index(after: cursor)
            var length = 1
            while offset + length < levels.count, levels[offset + length] == level, end < characters.endIndex {
                end = characters.index(after: end)
                length += 1
            }
            if level > 0 {
                string[cursor..<end].foregroundColor = ink.opacity(restOpacity + (sungOpacity - restOpacity) * level)
            }
            cursor = end
            offset += length
        }
        return string
    }
}

/// Zenith fork: the song's own buttons, as the lock screen player has them.
/// Never a permission prompt: one asked for here would open behind the lock
/// screen, where no one can answer it. In the Settings preview they are drawn
/// and do nothing.
struct ZenithLockScreenTransport: View {
    let playback: NotchPlayback
    let sideSize: CGFloat
    let mainSize: CGFloat
    let spacing: CGFloat
    let buttonWidth: CGFloat
    let buttonHeight: CGFloat
    var ink: Color = .white
    var preview = false
    var onCommand: () -> Void = {}
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What a tap on play or pause asked for, shown at once until the player says so.
    @State private var requestedPlaying: Bool?
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }

    var body: some View {
        HStack(spacing: spacing) {
            if preview || !music.lacksTrackSkipping(.previous) {
                button("backward.fill", size: sideSize, title: text.mediaPrevious, command: .previous)
            }
            button((requestedPlaying ?? playback.isPlaying) ? "pause.fill" : "play.fill", size: mainSize,
                   title: text.mediaPlayPause, command: .toggle)
            if preview || !music.lacksTrackSkipping(.next) {
                button("forward.fill", size: sideSize, title: text.mediaNext, command: .next)
            }
        }
        .allowsHitTesting(!preview)
        .onChange(of: music.playback?.isPlaying) {
            if music.playback?.isPlaying == requestedPlaying { requestedPlaying = nil }
        }
        .onChange(of: music.playback?.track) { requestedPlaying = nil }
        .task(id: requestedPlaying) {
            guard requestedPlaying != nil else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { requestedPlaying = nil }
        }
    }

    private func button(_ symbol: String, size: CGFloat, title: String, command: NotchMusicService.Command) -> some View {
        Button {
            guard !preview else { return }
            onCommand()
            let playing = requestedPlaying ?? playback.isPlaying
            if music.send(command, context: playback.commandContext), command == .toggle,
               playback.canSendCommandsDirectly { requestedPlaying = !playing }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(ink)
                .contentTransition(.symbolEffect(.replace))
                .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: symbol)
                .frame(width: buttonWidth, height: buttonHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(ZenithLockScreenPressStyle())
        .disabled(!preview && !music.canPerform(command))
        .accessibilityLabel(title)
    }
}

/// Zenith fork: a press that dims, with no wash, for any ink.
struct ZenithLockScreenPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(enabled ? (configuration.isPressed ? 0.6 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? ZenithMotion.pressedScale : 1)
            .animation(ZenithMotion.press, value: configuration.isPressed)
    }
}

/// Zenith fork: the lock screen's frosted glass, as the terminal readout
/// has it: the HUD blur with a dark wash, solid under Reduce Transparency.
struct ZenithLockScreenGlass: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(white: 0.08))
                } else {
                    ZStack {
                        NotchLockScreenMaterial(cornerRadius: cornerRadius)
                        shape.fill(.black.opacity(0.35))
                    }
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(contrast == .increased ? 0.35 : 0.1), lineWidth: 1)
                .allowsHitTesting(false))
    }
}

// MARK: - Jobs

/// Zenith fork: the long jobs beside the activity row's own items, the first
/// left of them and the second right, so the items keep the row's middle.
struct ZenithLockScreenJobsBeside: ViewModifier {
    let enabled: Bool
    /// The Settings preview's jobs, in place of the live ones.
    var sample: [ZenithLockScreenJob]? = nil
    @ObservedObject private var jobs = ZenithLockScreenJobs.shared
    /// Room kept on each side while a job shows, so the row gives up its
    /// last items before a job runs off the panel.
    static let reserve: CGFloat = 210
    static let gap: CGFloat = 26

    /// Each side's slot: the reserve less the gap to the row's items.
    static var slot: CGFloat { reserve - gap }

    // The jobs used to sit in overlays placed by alignment guides, which
    // the overlay did not honour when drawn offscreen: both jobs landed on
    // the row's own items. Slots of their own beside the items, as wide on
    // both sides, keep the items in the middle with nothing on top of them.
    func body(content: Content) -> some View {
        let arrangement = enabled ? ZenithLockScreenJobLine.arrange(sample ?? jobs.items) : .init()
        if arrangement.isEmpty {
            content
        } else {
            HStack(spacing: Self.gap) {
                // Each job at its own width (its label capped), against the
                // items; one wider than its slot reaches outward, never inward.
                Group {
                    if let job = arrangement.leading { ZenithLockScreenJobItem(job: job).fixedSize() }
                }
                .frame(width: Self.slot, alignment: .trailing)
                content
                HStack(spacing: 12) {
                    if let job = arrangement.trailing { ZenithLockScreenJobItem(job: job).fixedSize() }
                    if arrangement.overflow > 0 {
                        Text("+\(arrangement.overflow)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize()
                    }
                }
                .frame(width: Self.slot, alignment: .leading)
            }
            .lineLimit(1)
        }
    }
}

/// Zenith fork: one long job: a small ring, its label, and how far it is.
struct ZenithLockScreenJobItem: View {
    let job: ZenithLockScreenJob
    var ink: Color = .white
    /// Each source's own ring colour; off, the ring takes the ink.
    var colourful = true
    var fontSize: CGFloat = 15

    var body: some View {
        let scale = fontSize / 15
        let tint = colourful ? ZenithLockScreenJobLine.ringHex(job.source).map(Self.color(hex:)) ?? ink : ink
        HStack(spacing: 7 * scale) {
            ZenithLockScreenJobRing(fraction: job.fraction, finished: job.finished, tint: tint,
                                    track: ink.opacity(0.22), radius: 6 * scale, lineWidth: 2.25 * scale)
            Text(job.label)
                .foregroundStyle(ink.opacity(0.92))
                .frame(maxWidth: 140 * scale, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if !job.finished, let percent = ZenithLockScreenJobLine.percent(job.fraction) {
                Text(Double(percent) / 100, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(ink.opacity(0.5))
            }
        }
        .font(.system(size: fontSize, weight: .semibold))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    static func color(hex: UInt32) -> Color { ZenithLockScreenRGB(hex: hex).color }
}

/// Zenith fork: a job's ring: filled as far as the job has gone, spinning
/// while that is unknown, a check once done.
struct ZenithLockScreenJobRing: View {
    let fraction: Double?
    let finished: Bool
    let tint: Color
    let track: Color
    let radius: CGFloat
    let lineWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            if finished {
                Circle().stroke(tint, lineWidth: lineWidth)
                Image(systemName: "checkmark")
                    .font(.system(size: radius, weight: .heavy))
                    .foregroundStyle(tint)
            } else if let fraction {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, fraction)))
                    .stroke(tint, style: style)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: fraction)
            } else {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(tint, style: style)
                    .rotationEffect(.degrees(spinning ? 270 : -90))
                    .animation(reduceMotion || !spinning ? nil : .linear(duration: 1.1).repeatForever(autoreverses: false),
                               value: spinning)
                    .onAppear { if !reduceMotion { spinning = true } }
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Zenith fork: white type over any wallpaper, as the lock screen's own
    /// clock stays readable over a bright photo (the activity row's shadow).
    func zenithLegibleOnWallpaper() -> some View {
        shadow(color: .black.opacity(0.3), radius: 8, y: 1)
    }
}
