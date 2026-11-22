// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the padlock island over the lock screen, moving as the
/// island does (NotchMotionTimeline, the same springs, lags and squash) and
/// drawn at 120 Hz while it moves. At rest: a bigger padlock beside the
/// camera and, across it, the music's bars, the charge or the Focus. It
/// widens to wave goodbye as the Mac locks; the welcome back is the desktop
/// island's own burst.
struct ZenithLockScreenIsland: View {
    @ObservedObject var model: NotchLockScreenModel
    @ObservedObject var island: ZenithLockIslandModel
    /// The island at rest, fitted to the camera, and the camera itself.
    let size: CGSize
    let cameraWidth: CGFloat
    let geometry: NotchGeometry
    /// The window, and the resting island's top left corner inside it.
    var window: CGSize? = nil
    var origin: CGPoint = .zero
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion: NotchMotionTimeline?
    @State private var settleAt: TimeInterval = 0

    private var playing: Bool { model.showsMusic(music.playback) && music.playback?.isPlaying == true }
    private var text: ZenithLockIslandStrings { ZenithStrings.lockIsland(l10n.language) }
    private var restingWing: CGFloat { max(0, (size.width - cameraWidth) / 2) }
    private var camera: CGSize { CGSize(width: cameraWidth, height: size.height) }
    private var slot: ZenithLockIslandSlot { island.slot(playing: playing) }

    var body: some View {
        let goal = goal
        TimelineView(.animation(minimumInterval: nil, paused: motion == nil)) { context in
            let shape = motion?.shape(at: context.date.timeIntervalSinceReferenceDate) ?? goal
            surface(shape: shape, goal: goal)
                .frame(width: shape.width, height: shape.height, alignment: .top)
                .frame(width: window?.width ?? size.width, height: window?.height ?? size.height, alignment: .top)
                .offset(x: origin.x + size.width / 2 - (window?.width ?? size.width) / 2, y: origin.y)
        }
        .frame(width: window?.width ?? size.width, height: window?.height ?? size.height, alignment: .topLeading)
        .onChange(of: goal) { old, new in retarget(from: old, to: new) }
        // Zenith fork: the pill the desktop island takes over from as the Mac unlocks.
        .onAppear { island.restSize = restGoal }
        .onChange(of: restGoal) { _, new in island.restSize = new }
        .task(id: settleAt) {
            let wait = settleAt - Date().timeIntervalSinceReferenceDate
            guard motion != nil else { return }
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            if !Task.isCancelled, Date().timeIntervalSinceReferenceDate >= settleAt { motion = nil }
        }
        .accessibilityHidden(true)
    }

    // MARK: Size and motion

    /// The padlock pill at rest, with what its right wing shows.
    private var restGoal: CGSize {
        ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.wing(for: slotWidth(slot), resting: restingWing))
    }

    /// Zenith fork (remote lock): the island grown below the camera, and its lines.
    private func remoteFit(_ device: String) -> ZenithIslandBurstLayout.Fit {
        ZenithLockIsland.remoteFit(device: device, camera: size.height, resting: restGoal.width,
                                   screenWidth: geometry.screen.width)
    }

    /// Where the island is headed for what it shows now.
    private var goal: CGSize {
        switch island.moment {
        case .rest:
            return restGoal
        case .farewell:
            let width = Self.farewellWidth(text.seeYou(island.firstName))
            return ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.wing(for: width, resting: restingWing))
        case .remoteLock(let device): // Zenith fork: locked from an iPhone, grown below the camera
            return remoteFit(device).size
        }
    }

    /// The farewell beside the camera, as wide as its wing must be.
    static func farewellWidth(_ text: String) -> CGFloat { textWidth(text, size: 13, weight: .semibold) + 2 }

    /// A new goal carries the running motion on from where it is, at its
    /// speed; at rest it starts from the last goal. Reduce Motion snaps.
    private func retarget(from old: CGSize, to new: CGSize) {
        guard !reduceMotion else { motion = nil; return }
        let now = Date().timeIntervalSinceReferenceDate
        // Never narrower or shorter than the camera; back at rest it settles from above.
        let floor = NotchMotionFloor.floor(camera: CGSize(width: cameraWidth, height: size.height), target: new,
                                           closedHeight: size.height)
        let next = motion?.continued(to: new, at: now, floor: floor)
            ?? NotchMotionTimeline(from: old, to: new, begin: now, floor: floor)
        motion = next
        settleAt = next.begin + next.frames().duration
    }

    private func slotWidth(_ slot: ZenithLockIslandSlot) -> CGFloat {
        switch slot {
        case .none: return 0
        case .music: return NotchLayout.compactMusicBarsWidth
        case .charging(let percent):
            return 12 + 4 + Self.textWidth(percent.map { "\($0)%" } ?? "", size: 12, weight: .semibold)
        case .focus(let name):
            return 12 + 5 + Self.textWidth(name, size: 12, weight: .semibold)
        }
    }

    static func textWidth(_ string: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        guard !string.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        return ceil(NSAttributedString(string: string, attributes: [.font: font]).size().width)
    }

    // MARK: Drawing

    private func surface(shape: CGSize, goal: CGSize) -> some View {
        let outline = NotchShape(attached: true, radius: NotchLayout.surfaceRadius(height: shape.height))
        return ZStack(alignment: .top) {
            outline.fill(.black)
            ZStack(alignment: .top) {
                if case .remoteLock(let device) = island.moment { // Zenith fork: grown below the camera
                    grownRemote(device)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                } else {
                    wings(width: shape.width)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                }
            }
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: island.moment)
            .frame(width: shape.width, height: shape.height, alignment: .top)
            .clipShape(outline)
        }
    }

    /// Zenith fork (remote lock): the row under the camera, with the padding
    /// of the island it grew into on each side and below.
    private func grownRemote(_ device: String) -> some View {
        let fit = remoteFit(device)
        let shoulder = NotchLayout.shoulder(height: fit.size.height)
        return ZenithLockRemoteRow(device: device, lines: fit.lines)
            .padding(.horizontal, ZenithIslandRoom.edge + shoulder)
            .padding(.top, size.height + ZenithIslandInset.belowCamera)
            .frame(width: fit.size.width, height: fit.size.height, alignment: .top)
    }

    /// The padlock beside the camera and, across it, the slot or the farewell,
    /// each riding its wing's outer edge.
    private func wings(width: CGFloat) -> some View {
        let wing = max(0, (width - cameraWidth) / 2)
        let inset = max(8, min(geometry.compactMusicArtworkInset + 2, ZenithLockIsland.wingInset))
        return HStack(spacing: 0) {
            padlock(tint: .white)
                .padding(.leading, inset)
                .frame(width: wing, height: size.height, alignment: .leading)
            Spacer(minLength: 0)
            ZStack(alignment: .trailing) {
                if island.moment == .farewell {
                    Text(text.seeYou(island.firstName))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                } else {
                    slotView(slot)
                        .id(slotKey(slot))
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                }
            }
            .padding(.trailing, inset)
            .frame(width: wing, height: size.height, alignment: .trailing)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: island.moment)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: slotKey(slot))
        }
        .frame(width: width, height: size.height)
    }

    private func padlock(tint: Color) -> some View {
        Image(systemName: model.padlockOpen ? "lock.open.fill" : "lock.fill")
            .font(.system(size: min(ZenithLockIsland.padlockSize, size.height * 0.56), weight: .semibold))
            .foregroundStyle(tint)
            // Atoll's padlock motion, the shackle replaced down then up.
            .contentTransition(.symbolEffect(.replace.downUp))
            .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: model.padlockOpen)
            .frame(width: ZenithLockIsland.padlockSize + 6, height: size.height)
    }

    private func slotKey(_ slot: ZenithLockIslandSlot) -> String {
        switch slot {
        case .none: return "none"
        case .music: return "music"
        case .charging: return "charging"
        case .focus: return "focus"
        }
    }

    @ViewBuilder private func slotView(_ slot: ZenithLockIslandSlot) -> some View {
        switch slot {
        case .none:
            Color.clear.frame(width: 1, height: 1)
        case .music:
            NotchEqualizerBars(isPlaying: playing, bars: NotchLayout.compactMusicBarCount,
                               barWidth: NotchLayout.compactMusicBarWidth, height: geometry.compactMusicBarHeight,
                               tint: music.artworkTint?.color ?? .white)
        case .charging(let percent):
            let green = ZenithIslandPalette.color(hex: ZenithLockIsland.chargingHex)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 11, weight: .bold))
                if let percent {
                    Text("\(percent)%").font(.system(size: 12, weight: .semibold)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(percent)))
                }
            }
            .foregroundStyle(green)
            .lineLimit(1)
        case .focus(let name):
            let violet = ZenithIslandPalette.color(hex: ZenithLockIsland.focusHex)
            HStack(spacing: 5) {
                Image(systemName: "moon.fill").font(.system(size: 11, weight: .semibold))
                Text(name).font(.system(size: 12, weight: .semibold)).truncationMode(.tail)
            }
            .foregroundStyle(violet)
            .lineLimit(1)
        }
    }
}

/// Zenith fork (remote lock): the padlock on its tile, "Locked from Faiz’s
/// iPhone" over "just now", and the iPhone at the end, laid out with the
/// pieces and gaps ZenithLockIsland.remoteRow measures.
struct ZenithLockRemoteRow: View {
    let device: String
    var lines = 1

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        HStack(spacing: 0) {
            ZenithBurstTile(symbol: "lock.fill", tint: .white, fill: 0.12)
            ZenithBurstWords(title: RemoteText.lockedFrom(device), subtitle: RemoteText.justNow, titleLines: lines)
                .padding(.leading, Layout.tileGap)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: Layout.remoteGlyph, height: Layout.markSide)
                .padding(.leading, Layout.columnGap)
        }
        .frame(minHeight: Layout.welcomeRow)
        .foregroundStyle(.white)
    }
}
