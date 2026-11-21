// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the padlock island over the lock screen, moving as the
/// island does (NotchMotionTimeline, the same springs, lags and squash) and
/// drawn at 120 Hz while it moves. At rest: a bigger padlock beside the
/// camera and, across it, the music's bars, the charge or the Focus. It
/// widens to wave goodbye as the Mac locks and grows into two lines that
/// welcome the person back as it unlocks.
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
        .task(id: settleAt) {
            let wait = settleAt - Date().timeIntervalSinceReferenceDate
            guard motion != nil else { return }
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            if !Task.isCancelled, Date().timeIntervalSinceReferenceDate >= settleAt { motion = nil }
        }
        .accessibilityHidden(true)
    }

    // MARK: Size and motion

    /// Where the island is headed for what it shows now.
    private var goal: CGSize {
        switch island.moment {
        case .rest:
            return ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.wing(for: slotWidth(slot), resting: restingWing))
        case .farewell:
            let width = Self.textWidth(text.seeYou(island.firstName), size: 13, weight: .semibold)
            return ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.wing(for: width, resting: restingWing))
        case .welcome:
            let title = Self.textWidth(text.welcomeBack(island.firstName), size: 14, weight: .semibold)
            let detail = Self.textWidth(island.detail, size: 11.5, weight: .medium)
            return ZenithLockIsland.welcomeSize(camera: camera, resting: size, textWidth: max(title, detail))
        }
    }

    /// A new goal carries the running motion on from where it is, at its
    /// speed; at rest it starts from the last goal. Reduce Motion snaps.
    private func retarget(from old: CGSize, to new: CGSize) {
        guard !reduceMotion else { motion = nil; return }
        let now = Date().timeIntervalSinceReferenceDate
        let next = motion?.continued(to: new, at: now) ?? NotchMotionTimeline(from: old, to: new, begin: now)
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
                if island.moment == .welcome {
                    welcome(goal: goal)
                        .scaleEffect(ride(shape.width, over: goal.width), anchor: .top)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                } else {
                    wings(width: shape.width)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                }
            }
            .frame(width: shape.width, height: shape.height, alignment: .top)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: island.moment == .welcome)
            .clipShape(outline)
        }
    }

    /// The arriving content's share of its own width, as the island's pages ride it.
    private func ride(_ width: CGFloat, over goal: CGFloat) -> CGFloat {
        guard goal > 0 else { return 1 }
        return min(ZenithContentRide.incomingScale.upperBound, max(ZenithContentRide.incomingScale.lowerBound, width / goal))
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

    /// Two lines under the camera: the open padlock in green, the greeting
    /// and how long the Mac was locked, and the account's photo.
    private func welcome(goal: CGSize) -> some View {
        let green = ZenithIslandPalette.color(hex: ZenithLockIsland.chargingHex)
        return VStack(spacing: 0) {
            Color.clear.frame(height: size.height)
            HStack(spacing: ZenithLockIsland.welcomeGap) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: ZenithLockIsland.padlockSize, weight: .semibold))
                    .foregroundStyle(green)
                    .frame(width: ZenithLockIsland.padlockSize + 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.welcomeBack(island.firstName))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(island.detail)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                photo
            }
            .padding(.horizontal, ZenithLockIsland.welcomePadding)
            .frame(height: ZenithLockIsland.welcomeBlock - 6, alignment: .center)
        }
        .frame(width: goal.width, height: goal.height, alignment: .top)
    }

    @ViewBuilder private var photo: some View {
        let side = ZenithLockIsland.welcomePhoto
        if let image = island.photo {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: side, height: side)
                .clipShape(Circle())
        } else {
            Text(ZenithLockScreenInitials.of(NSFullUserName()))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: side, height: side)
                .background(Circle().fill(.white.opacity(0.16)))
        }
    }
}
