// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the lock screen v2's full layer, opened by clicking the
/// minimal lyric. One solid colour from the cover covers the screen; the
/// record, the song and its buttons sit on the left, the lyrics at full size
/// on the right, and the corners keep the clock, the jobs, who is at the Mac
/// and how to log in.
///
/// The record and its buttons take clicks; a click anywhere else, the pointer
/// moving, or the music stopping, goes back to the minimal layer.
struct ZenithLockScreenFullView: View {
    @ObservedObject var zenith: ZenithLockScreenV2Model
    let size: CGSize
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var lyrics = NotchLyricsService.shared
    @ObservedObject private var jobs = ZenithLockScreenJobs.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// On while the layer shows and while it fades out; off, nothing ticks
    /// in a window no one sees.
    @State private var live = false

    private var text: ZenithLockScreenV2Strings { ZenithStrings.lockScreenV2(l10n.language) }
    private var radial: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }

    var body: some View {
        let layout = ZenithLockScreenFullLayout(size: size)
        let scheme = zenith.scheme
        let ink = scheme.ink.color
        ZStack(alignment: .topLeading) {
            scheme.background.color
            if live {
                if zenith.gates.fullClock {
                    clock(layout, ink: ink)
                        .padding(.leading, layout.margin)
                        .padding(.top, layout.clockTop)
                }
                if let playback = music.playback {
                    column(playback, layout: layout, scheme: scheme)
                        .frame(width: layout.discSize)
                        .padding(.leading, layout.columnLeft)
                        .padding(.top, layout.columnTop)
                    lyricsColumn(playback, layout: layout, ink: ink)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if live, zenith.gates.fullJobs { jobLine(layout, scheme: scheme) }
        }
        .overlay(alignment: .bottomLeading) {
            if live { identity(layout, ink: ink) }
        }
        .overlay(alignment: .bottomTrailing) {
            if live, zenith.gates.fullLoginHint { loginHint(layout, ink: ink) }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        // Anywhere but the buttons goes back to the minimal layer.
        .contentShape(Rectangle())
        .onTapGesture { zenith.closeFull() }
        .environment(\.colorScheme, scheme.inkIsDark ? .light : .dark)
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: scheme)
        .task(id: zenith.fullShown) {
            if zenith.fullShown { live = true; return }
            try? await Task.sleep(nanoseconds: 450_000_000)
            if !Task.isCancelled, !zenith.fullShown { live = false }
        }
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

    private func jobLine(_ layout: ZenithLockScreenFullLayout, scheme: ZenithLockScreenPalette.Scheme) -> some View {
        let arrangement = ZenithLockScreenJobLine.arrange(jobs.items)
        let ink = scheme.ink.color
        let height = 30 * layout.scale
        return HStack(spacing: 22 * layout.scale) {
            ForEach(arrangement.shown) { job in
                // Pastel rings read on dark colours; over a light one they take the ink.
                ZenithLockScreenJobItem(job: job, ink: ink, colourful: !scheme.inkIsDark, fontSize: 15 * layout.scale)
            }
            if arrangement.overflow > 0 {
                Text("+\(arrangement.overflow)")
                    .font(.system(size: 15 * layout.scale, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.5))
            }
        }
        .fixedSize()
        .frame(height: height)
        .padding(.trailing, layout.margin)
        .padding(.top, max(0, layout.timeMiddle - height / 2))
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: arrangement)
        .allowsHitTesting(false)
    }

    @ViewBuilder private func identity(_ layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        let gates = zenith.gates
        if gates.fullAccount || gates.fullDevice, let account = zenith.account {
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
                            .foregroundStyle(ink.opacity(0.5))
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
        .foregroundStyle(ink.opacity(0.4))
        // Level with the account, whose picture sets the corner's height.
        .frame(height: layout.photoSize + 6 * layout.scale)
        .padding(.trailing, layout.margin)
        .padding(.bottom, layout.identityBottom)
        .allowsHitTesting(false)
    }

    // MARK: Song

    private func column(_ playback: NotchPlayback, layout: ZenithLockScreenFullLayout,
                        scheme: ZenithLockScreenPalette.Scheme) -> some View {
        let ink = scheme.ink.color
        return VStack(spacing: 0) {
            if zenith.gates.fullDisc {
                ZenithLockScreenRecord(image: music.artwork, size: layout.discSize, hole: scheme.background.color)
                    .padding(.bottom, 34 * layout.scale)
            }
            Text(playback.track.title ?? radial.mediaNowPlaying)
                .font(.system(size: layout.titleSize, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(2)
            if let artist = playback.track.artist ?? playback.track.album {
                Text(artist)
                    .font(.system(size: layout.artistSize, weight: .medium))
                    .foregroundStyle(ink.opacity(0.55))
                    .lineLimit(1)
                    .padding(.top, 4 * layout.scale)
            }
            if playback.duration > 0 {
                progress(playback, layout: layout, ink: ink)
                    .padding(.top, 22 * layout.scale)
            }
            ZenithLockScreenTransport(playback: playback, sideSize: layout.sideControlSize, mainSize: layout.mainControlSize,
                                      spacing: 26 * layout.scale, buttonWidth: 56 * layout.scale,
                                      buttonHeight: 50 * layout.scale, ink: ink)
                .padding(.top, 12 * layout.scale)
        }
        .multilineTextAlignment(.center)
    }

    private func progress(_ playback: NotchPlayback, layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        TimelineView(.animation(minimumInterval: 1, paused: !playback.isPlaying)) { context in
            let position = playback.position(at: context.date)
            let fraction = min(1, max(0, position / playback.duration))
            VStack(spacing: 8 * layout.scale) {
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
                .foregroundStyle(ink.opacity(0.55))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Lyrics

    @ViewBuilder private func lyricsColumn(_ playback: NotchPlayback, layout: ZenithLockScreenFullLayout,
                                           ink: Color) -> some View {
        if let timed = ZenithLockScreenV2Model.timedLyrics(lyrics.lyrics, playback: playback) {
            let offset = lyrics.offset
            TimelineView(.explicit(timed.changeDates(for: playback, offset: offset, from: .now))) { context in
                let active = timed.activeIndex(at: playback.position(at: context.date), offset: offset)
                lyricLines(timed, active: active, playback: playback, offset: offset, layout: layout, ink: ink)
            }
            .frame(width: layout.lyricsWidth, alignment: .topLeading)
            .padding(.leading, layout.lyricsLeft)
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

    /// The line before, the one being sung, and five after it, fainter and
    /// softer the further they are. The line before keeps a fixed room, so
    /// the sung line's top stays where it is as the lines move up.
    private func lyricLines(_ lyrics: NotchLyrics, active: Int?, playback: NotchPlayback, offset: Double,
                            layout: ZenithLockScreenFullLayout, ink: Color) -> some View {
        let window = ZenithLockScreenLyricWindow.make(
            lineCount: lyrics.lines.count, active: active, upcoming: ZenithLockScreenFullLayout.upcomingOpacities.count)
        var slots: [Slot] = []
        if let previous = window.previous { slots.append(Slot(index: previous, role: .previous)) }
        if let active = window.active { slots.append(Slot(index: active, role: .active)) }
        slots += window.upcoming.enumerated().map { Slot(index: $0.element, role: .upcoming($0.offset)) }
        // Two lines' room for the line before, so it can wrap.
        let previousRoom = (layout.lineSize * 1.22 * 2).rounded()
        let stack = VStack(alignment: .leading, spacing: layout.lineGap) {
            if window.previous == nil {
                Color.clear.frame(height: previousRoom).id(-1)
            }
            ForEach(slots) { slot in
                line(slot, lyrics: lyrics, playback: playback, offset: offset, layout: layout, ink: ink,
                     previousRoom: previousRoom)
                    .transition(.opacity)
            }
        }
        .frame(width: layout.lyricsWidth, alignment: .topLeading)
        .padding(.top, max(0, layout.activeTop - previousRoom - layout.lineGap))
        return Group {
            if reduceMotion {
                // Reduce Motion: the lines change in place, with a fade only.
                ZStack(alignment: .topLeading) {
                    stack.id(active ?? -1).transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.3), value: active)
            } else {
                stack.animation(.spring(response: 0.6, dampingFraction: 0.86), value: active)
            }
        }
    }

    private func line(_ slot: Slot, lyrics: NotchLyrics, playback: NotchPlayback, offset: Double,
                      layout: ZenithLockScreenFullLayout, ink: Color, previousRoom: CGFloat) -> some View {
        let isActive = slot.role == .active
        let grows = isActive && !reduceMotion
        let opacity: Double
        let blur: CGFloat
        switch slot.role {
        case .previous:
            opacity = ZenithLockScreenFullLayout.previousOpacity
            blur = ZenithLockScreenFullLayout.previousBlur
        case .active:
            opacity = 1
            blur = 0
        case .upcoming(let distance):
            opacity = ZenithLockScreenFullLayout.upcomingOpacities[min(distance, ZenithLockScreenFullLayout.upcomingOpacities.count - 1)]
            blur = ZenithLockScreenFullLayout.upcomingBlurs[min(distance, ZenithLockScreenFullLayout.upcomingBlurs.count - 1)]
        }
        return ZenithLockScreenSungLine(lyrics: lyrics, index: slot.index, playback: playback, offset: offset,
                                        karaoke: isActive && zenith.gates.karaoke, ink: ink,
                                        sungOpacity: isActive ? 1 : opacity, restOpacity: 0.45)
            .font(.system(size: isActive ? layout.activeSize : layout.lineSize, weight: .heavy))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.interpolate)
            .frame(width: layout.lyricsWidth, height: slot.role == .previous ? previousRoom : nil, alignment: .bottomLeading)
            .blur(radius: blur * layout.scale)
            // The new line being sung grows in from a little smaller.
            .keyframeAnimator(initialValue: CGFloat(1), trigger: isActive) { content, scale in
                content.scaleEffect(grows ? scale : 1, anchor: .leading)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(0.94, duration: 0.01)
                    SpringKeyframe(1, duration: 0.6, spring: .smooth)
                }
            }
    }
}

/// Zenith fork: the record on the full layer: the cover clipped to a circle,
/// faint grooves over it, and a spindle hole in the background's colour. It
/// never spins.
struct ZenithLockScreenRecord: View {
    let image: NSImage?
    let size: CGFloat
    let hole: Color

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.07))
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.16, weight: .light))
                    .foregroundStyle(.white.opacity(0.35))
            }
            ForEach(0..<9, id: \.self) { groove in
                let diameter = size * (0.42 + CGFloat(groove) * 0.065)
                Circle().stroke(.black.opacity(0.11), lineWidth: max(0.5, size / 700)).frame(width: diameter, height: diameter)
                Circle().stroke(.white.opacity(0.05), lineWidth: max(0.5, size / 700))
                    .frame(width: diameter + size / 160, height: diameter + size / 160)
            }
            // A soft sheen, as light catches vinyl.
            Circle().fill(AngularGradient(colors: [.white.opacity(0), .white.opacity(0.07), .white.opacity(0),
                                                   .white.opacity(0.05), .white.opacity(0)], center: .center))
            Circle().strokeBorder(.black.opacity(0.22), lineWidth: max(1, size / 350))
            Circle().fill(hole)
                .frame(width: size * 0.06, height: size * 0.06)
                .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: size * 0.08, y: size * 0.04)
        .accessibilityHidden(true)
    }
}
