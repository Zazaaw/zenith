// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the padlock island over the lock screen, moving as the
/// island does (NotchMotionTimeline, the same springs, lags and squash) and
/// drawn at 120 Hz while it moves. At rest: a bigger padlock beside the
/// camera and, across it, the music's bars, the charge or the Focus. It
/// widens to wave goodbye as the Mac locks. Unlocked, it grows the desktop
/// island's own welcome burst, which the desktop island then takes over at
/// the same shape. Zenith fork: it also shows face unlock (FaceUnlockIslandStage).
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
    /// Drawn at this many seconds into its entrance, still, for the
    /// catalog's frame sequences; nil on the lock screen.
    var frozen: TimeInterval? = nil
    /// Zenith fork: face unlock's animations drawn as stills, for the
    /// catalog, whose offscreen renders never capture a video layer.
    var stillMedia = false
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion: NotchMotionTimeline?
    @State private var settleAt: TimeInterval = 0
    /// Zenith fork: the corners' style, blending between Zenith's and Glance's.
    @State private var corners = FaceUnlockCornerBlend(from: 0, to: 0, begin: 0)
    @State private var cornersMoving = false

    private var playing: Bool { model.showsMusic(music.playback) && music.playback?.isPlaying == true }
    private var text: ZenithLockIslandStrings { ZenithStrings.lockIsland(l10n.language) }
    private var restingWing: CGFloat { max(0, (size.width - cameraWidth) / 2) }
    private var camera: CGSize { CGSize(width: cameraWidth, height: size.height) }
    private var slot: ZenithLockIslandSlot { island.slot(playing: playing) }
    /// Zenith fork: what it shows, face unlock included, and whether its
    /// right wing adds the face glyph (armed, at rest).
    private var stage: FaceUnlockIslandStage { island.stage }
    private var faceGlyph: Bool { FaceUnlockIslandStage.showsFaceGlyph(moment: island.moment, face: island.face) }
    /// Zenith fork: Glance's corners for face unlock's own shapes.
    private var glanceCorners: Bool { FaceUnlockIslandStage.usesGlanceCorners(stage, faceGlyph: faceGlyph) }

    var body: some View {
        let goal = goal
        TimelineView(.animation(minimumInterval: nil, paused: frozen != nil || (motion == nil && !cornersMoving))) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let shape = frozen.map { entranceMotion(to: goal, begin: 0)?.shape(at: $0) ?? goal }
                ?? motion?.shape(at: now)
                // Zenith fork: until its entrance starts, the island stands where it grows from.
                ?? island.entrance ?? goal
            surface(shape: shape, goal: goal,
                    continuous: frozen != nil || reduceMotion ? (glanceCorners ? 1 : 0) : corners.value(at: now))
                .frame(width: shape.width, height: shape.height, alignment: .top)
                .frame(width: window?.width ?? size.width, height: window?.height ?? size.height, alignment: .top)
                .offset(x: origin.x + size.width / 2 - (window?.width ?? size.width) / 2, y: origin.y)
        }
        .frame(width: window?.width ?? size.width, height: window?.height ?? size.height, alignment: .topLeading)
        .onChange(of: goal) { old, new in retarget(from: old, to: new) }
        // Zenith fork: the shape the desktop island takes over from as the Mac unlocks.
        .onAppear {
            island.shownSize = goal
            let target: CGFloat = glanceCorners ? 1 : 0 // Zenith fork
            corners = FaceUnlockCornerBlend(from: target, to: target, begin: 0)
            startEntrance()
        }
        // Zenith fork: the corners ease from one style to the other (a scan becoming the welcome).
        .onChange(of: glanceCorners) { _, glance in
            let now = Date().timeIntervalSinceReferenceDate
            corners = FaceUnlockCornerBlend(from: corners.value(at: now), to: glance ? 1 : 0, begin: now)
            cornersMoving = true
        }
        .task(id: corners.begin) {
            guard cornersMoving else { return }
            try? await Task.sleep(nanoseconds: UInt64((FaceUnlockCornerBlend.duration + 0.05) * 1_000_000_000))
            if !Task.isCancelled { cornersMoving = false }
        }
        .onChange(of: goal) { _, new in island.shownSize = new }
        .onChange(of: island.entranceReleased) { _, released in if released { startEntrance() } } // Zenith fork
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
        let content = faceGlyph ? FaceUnlockIslandLayout.armedWing(slot: slotWidth(slot)) : slotWidth(slot) // Zenith fork
        return ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.wing(for: content, resting: restingWing))
    }

    /// Zenith fork: the welcome as the desktop island draws it, at its size,
    /// so the desktop island takes it over at the very same shape.
    private func welcomeFit(_ welcome: ZenithWelcomeBurst) -> ZenithIslandBurstLayout.Fit {
        ZenithIslandBurstLayout.fit(ZenithIslandBurst(.welcome(welcome), start: .distantPast), geometry: geometry)
    }

    /// Zenith fork: Glance's scanning panel, or its minimal widening.
    private var scanGoal: CGSize {
        FaceUnlockIslandLayout.scanSize(style: island.faceStyle, resting: restGoal, camera: camera)
    }

    private var touchIDFit: ZenithIslandBurstLayout.Fit {
        FaceUnlockIslandLayout.touchIDFit(camera: size.height, resting: restGoal.width, screenWidth: geometry.screen.width)
    }

    /// Zenith fork (remote lock): the island grown below the camera, and its lines.
    private func remoteFit(_ device: String) -> ZenithIslandBurstLayout.Fit {
        ZenithLockIsland.remoteFit(device: device, camera: size.height, resting: restGoal.width,
                                   screenWidth: geometry.screen.width)
    }

    /// Where the island is headed for what it shows now.
    private var goal: CGSize {
        switch stage {
        case .moment(.rest):
            return restGoal
        case .moment(.farewell):
            let width = Self.farewellWidth(text.seeYou(island.firstName))
            return ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.wing(for: width, resting: restingWing))
        case .moment(.remoteLock(let device)): // Zenith fork: locked from an iPhone, grown below the camera
            return remoteFit(device).size
        case .moment(.welcome(let welcome)): // Zenith fork: unlocked, the welcome grows here first
            return welcomeFit(welcome).size
        case .moment(.bare): // Zenith fork: drawn back into the camera
            return camera
        case .scan: // Zenith fork: face unlock
            return scanGoal
        case .touchID:
            return touchIDFit.size
        }
    }

    /// Zenith fork: content that morphs as one page; within it, the slot and
    /// the farewell, or the scan's animations, change in place.
    private var stageKey: String {
        switch stage {
        case .moment(.rest), .moment(.farewell), .moment(.bare): return "wings"
        case .moment(.remoteLock): return "remote"
        case .moment(.welcome): return "welcome"
        case .scan: return "scan"
        case .touchID: return "touchID"
        }
    }

    /// The farewell beside the camera, as wide as its wing must be.
    static func farewellWidth(_ text: String) -> CGFloat { textWidth(text, size: 13, weight: .semibold) + 2 }

    /// Never narrower or shorter than the camera; back at rest it settles from above.
    private func floor(to target: CGSize) -> CGSize {
        NotchMotionFloor.floor(camera: CGSize(width: cameraWidth, height: size.height), target: target,
                               closedHeight: size.height)
    }

    /// Zenith fork: as the Mac locks, the island grows out of the desktop
    /// island it covers (`ZenithLockIslandModel.entrance`) into what it shows
    /// first, the farewell or "Locked from …", with that content from frame one.
    private func entranceMotion(to goal: CGSize, begin: TimeInterval) -> NotchMotionTimeline? {
        guard let start = island.entrance, start != goal else { return nil }
        return NotchMotionTimeline(from: start, to: goal, begin: begin, floor: floor(to: goal))
    }

    /// The entrance's clock starts on the turn after the island's first
    /// frame: until then it stands at the shape it grows from, so the first
    /// frame on screen is that shape however long the lock screen takes to
    /// come in. Reduce Motion shows the goal at once.
    /// Zenith fork: the entrance waits for the lock screen to release it
    /// (ZenithLockIslandModel.entranceReleased: the window on screen, the
    /// shield faded in), then starts on the next turn, into whatever the
    /// island shows by then.
    private func startEntrance() {
        guard frozen == nil, island.entrance != nil, island.entranceReleased else { return }
        guard !reduceMotion else { island.entrance = nil; return }
        DispatchQueue.main.async {
            guard island.entrance != nil, let next = entranceMotion(to: goal, begin: Date().timeIntervalSinceReferenceDate)
            else { island.entrance = nil; return }
            island.entrance = nil
            ZenithLockTrace.log("entrance grows: \(next.start) -> \(next.target)")
            motion = next
            settleAt = next.begin + next.frames().duration
            island.settlesAt = settleAt
        }
    }

    /// A new goal carries the running motion on from where it is, at its
    /// speed; at rest it starts from the last goal (or, before its entrance
    /// has started, from where it grows). Reduce Motion snaps.
    private func retarget(from old: CGSize, to new: CGSize) {
        guard frozen == nil else { return }
        guard !reduceMotion else { motion = nil; island.settlesAt = 0; return }
        // Zenith fork: an entrance not yet released stays at the notch; it
        // grows into the newest goal when it starts.
        if motion == nil, island.entrance != nil, !island.entranceReleased { return }
        let old = motion == nil ? island.entrance ?? old : old
        island.entrance = nil
        let now = Date().timeIntervalSinceReferenceDate
        let floor = floor(to: new)
        let next = motion?.continued(to: new, at: now, floor: floor)
            ?? NotchMotionTimeline(from: old, to: new, begin: now, floor: floor)
        motion = next
        settleAt = next.begin + next.frames().duration
        island.settlesAt = settleAt // Zenith fork: the unlock hands over once it is still
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

    /// Zenith fork: the room between the padlock's box and the glyph inside
    /// it: the face glyph keeps the same from the right edge, so the two
    /// sit as far from their edges as each other.
    static let padlockLead: CGFloat = {
        let configuration = NSImage.SymbolConfiguration(pointSize: ZenithLockIsland.padlockSize, weight: .semibold)
        let width = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)?.size.width ?? ZenithLockIsland.padlockSize
        return max(0, (FaceUnlockIslandLayout.glyphBox - width) / 2)
    }()

    static func textWidth(_ string: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        guard !string.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        return ceil(NSAttributedString(string: string, attributes: [.font: font]).size().width)
    }

    // MARK: Drawing

    private func surface(shape: CGSize, goal: CGSize, continuous: CGFloat) -> some View {
        // Zenith fork: Zenith's outline, or Glance's squircle corners for face unlock, blended.
        let outline = FaceUnlockIslandShape(radius: NotchLayout.surfaceRadius(height: shape.height), continuous: continuous)
        return ZStack(alignment: .top) {
            outline.fill(.black)
            ZStack(alignment: .top) {
                // Zenith fork: one page per stage, morphing as the island's pages do.
                page(width: shape.width)
                    .id(stageKey)
                    .transition(.zenithMorph(reduceMotion: reduceMotion))
            }
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: stageKey)
            .frame(width: shape.width, height: shape.height, alignment: .top)
            .clipShape(outline)
        }
    }

    @ViewBuilder private func page(width: CGFloat) -> some View {
        switch stage {
        case .moment(.remoteLock(let device)): // Zenith fork: grown below the camera
            grownRemote(device)
        case .moment(.welcome(let welcome)): // Zenith fork: the desktop island's own welcome, as it draws it
            ZenithIslandBurstView(burst: ZenithIslandBurst(.welcome(welcome), start: .distantPast), geometry: geometry)
        case .scan(let media): // Zenith fork: face unlock
            scanPanel(media)
        case .touchID:
            touchIDRow
        case .moment(.rest), .moment(.farewell), .moment(.bare):
            wings(width: width)
        }
    }

    /// Zenith fork: Glance's scanning panel: the square animation under the
    /// camera; in the minimal style the padlock on the left wing and the
    /// animation on the right. With the style set to none the results show
    /// the still, as in Glance.
    @ViewBuilder private func scanPanel(_ media: FaceUnlockIslandMedia) -> some View {
        let goal = scanGoal
        let plays = media == .idle || FaceUnlockIslandStyle.playsResults(island.faceStyle)
        if island.faceStyle == .minimal {
            let wing = max(0, (goal.width - cameraWidth) / 2)
            let side = FaceUnlockIslandLayout.minimalVideoSide(height: goal.height)
            HStack(spacing: 0) {
                Image(systemName: media == .success ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: FaceUnlockIslandLayout.minimalLockSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .animation(reduceMotion ? nil : IslandMotion.smooth(0.4), value: media)
                    .frame(width: wing, height: goal.height)
                Spacer(minLength: 0)
                FaceUnlockMediaView(media: media, plays: plays, still: stillMedia)
                    .frame(width: side, height: side)
                    .frame(width: wing, height: goal.height)
            }
            .frame(width: goal.width, height: goal.height)
        } else {
            let side = FaceUnlockIslandLayout.videoSide(in: goal)
            FaceUnlockMediaView(media: media, plays: plays, still: stillMedia)
                .frame(width: side, height: side)
                .padding(.top, FaceUnlockIslandLayout.videoTop)
                .frame(width: goal.width, height: goal.height, alignment: .top)
        }
    }

    /// Zenith fork: "Unlock with Touch ID once to use Face ID", below the
    /// camera, with the island's padding around it.
    private var touchIDRow: some View {
        let fit = touchIDFit
        let shoulder = NotchLayout.shoulder(height: fit.size.height)
        return HStack(spacing: 0) {
            // Concentric with Glance's corner, 20 points in.
            ZenithBurstTile(symbol: "touchid", tint: .white,
                            radius: FaceUnlockIslandSilhouette.innerRadius(height: fit.size.height), fill: 0.12)
            ZenithBurstWords(title: FaceUnlockIslandText.needsTouchID, subtitle: "", titleLines: fit.lines)
                .padding(.leading, ZenithIslandBurstLayout.tileGap)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: ZenithIslandBurstLayout.markSide)
        .foregroundStyle(.white)
        .padding(.horizontal, ZenithIslandRoom.edge + shoulder)
        .padding(.top, size.height + ZenithIslandInset.belowCamera)
        .frame(width: fit.size.width, height: fit.size.height, alignment: .top)
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
                        // Zenith fork: whole while its wing grows, coming out from behind the camera.
                        .fixedSize()
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                } else if faceGlyph { // Zenith fork: armed for face unlock, its glyph at the wing's end
                    HStack(spacing: FaceUnlockIslandLayout.glyphGap) {
                        if slot != .none { slotView(slot).id(slotKey(slot)) }
                        // As big as the padlock reads and as far from the right edge,
                        // both centred on the strip's height.
                        Image(systemName: "faceid")
                            .font(.system(size: min(FaceUnlockIslandLayout.glyphSize, size.height * 0.6), weight: .medium))
                            .foregroundStyle(.white)
                            .fixedSize()
                            .padding(.trailing, Self.padlockLead)
                            .frame(height: size.height)
                    }
                    .transition(.zenithMorph(reduceMotion: reduceMotion))
                } else {
                    slotView(slot)
                        .id(slotKey(slot))
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                }
            }
            .padding(.trailing, inset)
            .frame(width: wing, height: size.height, alignment: .trailing)
            .clipped()
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: island.moment)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: slotKey(slot))
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: faceGlyph) // Zenith fork
        }
        .frame(width: width, height: size.height)
    }

    private func padlock(tint: Color) -> some View {
        Image(systemName: model.padlockOpen ? "lock.open.fill" : "lock.fill")
            .font(.system(size: min(ZenithLockIsland.padlockSize, size.height * 0.56), weight: .semibold))
            .foregroundStyle(tint)
            // Atoll's padlock motion, the shackle replaced down then up.
            .contentTransition(.symbolEffect(.replace.downUp))
            .animation(reduceMotion ? nil : IslandMotion.snappy(0.28), value: model.padlockOpen)
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
            Image(systemName: ZenithRemoteLockMark.symbol(for: device))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: Layout.remoteGlyph, height: Layout.markSide)
                .padding(.leading, Layout.columnGap)
        }
        .frame(minHeight: Layout.welcomeRow)
        .foregroundStyle(.white)
    }
}
