// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreGraphics
import Foundation

// Zenith fork: the lock screen's windows (Glance's level and behaviour), the
// padlock island's hand-off as the Mac unlocks, and how it shows face unlock.
// Run with the lock-island suite.
enum FaceUnlockIslandTests {
    static func run(_ suite: TestSuite) {
        windows(suite)
        handover(suite)
        stages(suite)
        sizes(suite)
        timing(suite)
        style(suite)
        corners(suite)
        blinks(suite)
    }

    /// Glance's continuous corners, for face unlock's shapes only.
    private static func corners(_ suite: TestSuite) {
        typealias C = FaceUnlockIslandSilhouette
        typealias S = FaceUnlockIslandStage
        suite.expect(S.usesGlanceCorners(.scan(.idle), faceGlyph: false) && S.usesGlanceCorners(.scan(.success), faceGlyph: false)
                        && S.usesGlanceCorners(.scan(.failure), faceGlyph: false) && S.usesGlanceCorners(.touchID, faceGlyph: false)
                        && S.usesGlanceCorners(.moment(.rest), faceGlyph: true),
                     "the armed pill with its glyph, the scan, its results and the Touch ID line take Glance's corners")
        suite.expect(!S.usesGlanceCorners(.moment(.rest), faceGlyph: false) && !S.usesGlanceCorners(.moment(.farewell), faceGlyph: true)
                        && !S.usesGlanceCorners(.moment(.welcome(ZenithWelcomeBurst(title: "Welcome back", subtitle: ""))), faceGlyph: false)
                        && !S.usesGlanceCorners(.moment(.remoteLock(device: "iPhone")), faceGlyph: false)
                        && !S.usesGlanceCorners(.moment(.bare), faceGlyph: false),
                     "every other island keeps Zenith's")
        suite.expect(C.reach == 1.528 && C.radius(height: 37, body: 300, depth: 7) == 12
                        && C.radius(height: 200, body: 231, depth: 27) == 60,
                     "the squircle runs from 12 points on the closed pill to 60 on the open panel, reaching 1.528 times out")
        suite.expect(abs(C.radius(height: 49, body: 40, depth: 7) - 20 / 1.528) < 0.001
                        && abs(C.radius(height: 20, body: 300, depth: 7) - 13 / 1.528) < 0.001,
                     "it never runs past the straight edges, across or down")
        suite.expect(C.innerRadius(height: 37) == 8 && C.innerRadius(height: 178) == 40,
                     "inner elements stay concentric, 20 points in")
        let rect = CGRect(x: 0, y: 0, width: 300, height: 120)
        let shoulder = NotchLayout.shoulder(height: rect.height), radius = NotchLayout.surfaceRadius(height: rect.height)
        let zenith = ZenithIslandSilhouette.hangingPath(in: rect, shoulder: shoulder, radius: radius)
        let blended = C.path(in: rect, shoulder: shoulder, radius: radius, continuous: 0)
        var same = abs(zenith.boundingRect.width - blended.boundingRect.width) < 0.01
            && abs(zenith.boundingRect.height - blended.boundingRect.height) < 0.01
        for x in stride(from: 1.0, to: 300, by: 7) {
            for y in stride(from: 1.0, to: 120, by: 3) where zenith.contains(CGPoint(x: x, y: y)) != blended.contains(CGPoint(x: x, y: y)) {
                same = false
            }
        }
        suite.expect(same, "with no blend the outline is exactly Zenith's island, shoulders and corners")
        let glance = C.path(in: rect, shoulder: shoulder, radius: radius, continuous: 1)
        let side = max(0, min(shoulder, rect.width / 2))
        let r = C.radius(height: 120, body: rect.width - side * 2, depth: min(side + max(0, ZenithIslandSilhouette.openShoulderDepth - side)
            * ZenithIslandSilhouette.openness(height: 120), 60))
        suite.expect(glance.contains(CGPoint(x: side + r * C.reach + 1, y: 119.6)) && !glance.contains(CGPoint(x: side + 1.5, y: 118.5))
                        && glance.contains(CGPoint(x: 150, y: 2)) && glance.contains(CGPoint(x: side + 0.5, y: 118 - r * C.reach)),
                     "blended fully, the bottom corners are the squircle, flat until 1.528 radii from the corner, under the same shoulders")
        let blend = FaceUnlockCornerBlend(from: 0, to: 1, begin: 10)
        suite.expect(blend.value(at: 10) == 0 && blend.value(at: 10 + FaceUnlockCornerBlend.duration) == 1
                        && abs(blend.value(at: 10 + FaceUnlockCornerBlend.duration / 2) - 0.5) < 0.001 && blend.value(at: .nan) == 1,
                     "a scan becoming the welcome eases its corners from one style to the other, no jump")
    }

    /// The two blinks seen on video (IMG_9851): the success going back to the
    /// pill before the welcome, and the lock's entrance arriving already grown.
    private static func blinks(_ suite: TestSuite) {
        typealias S = FaceUnlockIslandStage
        suite.expect(S.next(current: .success, incoming: .hidden, sessionLocked: false) == .success,
                     "face unlock standing down as the Mac unlocks keeps the success up, to morph straight into the welcome")
        suite.expect(S.next(current: .success, incoming: .hidden, sessionLocked: true) == .hidden
                        && S.next(current: .success, incoming: .failure(.noPassword), sessionLocked: true) == .failure(.noPassword)
                        && S.next(current: .scanning, incoming: .hidden, sessionLocked: false) == .hidden
                        && S.next(current: .armed, incoming: .scanning, sessionLocked: true) == .scanning,
                     "still locked, or anything but a match, the island takes the state as it comes")
        let welcome = ZenithLockIslandMoment.welcome(ZenithWelcomeBurst(title: "Welcome back", subtitle: ""))
        suite.expect(S.resolve(moment: welcome, face: S.next(current: .success, incoming: .hidden, sessionLocked: false))
                        == .moment(welcome),
                     "and the welcome then wins over the held success")
        typealias H = ZenithLockHandover
        suite.expect(H.entranceWait(sinceLock: 0) == H.shieldFadeIn && abs(H.entranceWait(sinceLock: 0.5) - (H.shieldFadeIn - 0.5)) < 0.0001,
                     "on screen early, the island stays the bare notch for the rest of the shield's fade")
        suite.expect(H.entranceWait(sinceLock: 2) == H.entranceFrames && H.entranceWait(sinceLock: .nan) == H.entranceFrames
                        && H.entranceFrames > 0,
                     "on screen late, it still shows the notch first and grows after, never arriving already grown")
    }

    private static func windows(_ suite: TestSuite) {
        typealias W = ZenithLockScreenWindow
        suite.expect(W.islandLevel.rawValue == Int(CGShieldingWindowLevel()) + 1,
                     "the padlock island sits one above the shielding level, as Glance's island does")
        suite.expect(W.islandLevel > .screenSaver && W.islandLevel > .statusBar && W.islandLevel > NSWindow.Level.popUpMenu,
                     "above every ordinary overlay tier, so the shield's fade never draws over it")
        suite.expect(W.collectionBehavior == [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle],
                     "on every Space, never moving with one, over full screen apps, out of window cycling")
        suite.expect(!W.collectionBehavior.contains(.moveToActiveSpace) && !W.collectionBehavior.contains(.transient),
                     "and nothing that would move it with the active Space")
        suite.expect(W.spaceFlag == 1, "the lock screen Space is created with the flag that keeps Finder's icons out of it")
        suite.expect(W.removedSpaces == 7, "a delegated window leaves every other Space (Glance's mask)")
        suite.expect(NotchLockScreenSupport.spaceLevel == 400, "the Space draws at the lock screen notifications' level")
    }

    private static func handover(_ suite: TestSuite) {
        typealias H = ZenithLockHandover
        suite.expect(!H.ready(elapsed: 0.2, desktopSettled: true, islandSettled: false)
                        && H.ready(elapsed: 0.9, desktopSettled: true, islandSettled: true),
                     "it hands over once the desktop has stopped zooming and the island is still")
        suite.expect(!H.ready(elapsed: 0.9, desktopSettled: false, islandSettled: true)
                        && H.ready(elapsed: H.desktopFallback, desktopSettled: false, islandSettled: true),
                     "with no reading of the zoom, the desktop counts as settled after about a second")
        suite.expect(H.ready(elapsed: H.longest, desktopSettled: false, islandSettled: false)
                        && H.ready(elapsed: .nan, desktopSettled: false, islandSettled: false),
                     "it never waits past its limit, nor on a broken clock")
        suite.expect(H.desktopFallback < H.longest && H.shieldFadeIn > 0.2 && H.shieldFadeIn < 1 && H.patience > 0,
                     "the fallback comes before the limit; the bare notch lasts about the shield's fade in")
        let welcome = CGSize(width: 380, height: 99)
        suite.expect(H.plan(welcome: true, shown: welcome) == .handOver(welcome),
                     "with a welcome, the desktop island takes over at the welcome's own shape")
        suite.expect(H.plan(welcome: false, shown: welcome) == .collapse && H.plan(welcome: true, shown: nil) == .collapse
                        && H.plan(welcome: true, shown: .zero) == .collapse,
                     "with nothing to hand over, the island draws back into the notch and goes")
        suite.expect(H.welcomeRemaining(shownFor: 1, duration: 3) == 2 && H.welcomeRemaining(shownFor: 5, duration: 3) == 0
                        && H.welcomeRemaining(shownFor: -1, duration: 3) == 3 && H.welcomeRemaining(shownFor: .nan, duration: 3) == 0,
                     "declined, the padlock island keeps the welcome for what is left of it")
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        suite.expect(H.handedOverStart(now: now, shownFor: 1.25) == Date(timeIntervalSinceReferenceDate: 998.75)
                        && H.handedOverStart(now: now, shownFor: -2) == now,
                     "taken over, the welcome ends when it would have in the padlock island")
        suite.expect(ZenithLockIsland.openingHold(.welcome(ZenithWelcomeBurst(title: "Welcome back", subtitle: "", photo: nil,
                                                                                initials: "F"))) == nil
                        && ZenithLockIsland.openingHold(.bare) == nil,
                     "the welcome and the bare notch hold for no timer of the island's own")
    }

    private static func stages(_ suite: TestSuite) {
        typealias S = FaceUnlockIslandStage
        let welcome = ZenithLockIslandMoment.welcome(ZenithWelcomeBurst(title: "Welcome back, Faiz", subtitle: "Locked for 2m",
                                                                         photo: nil, initials: "FA"))
        suite.expect(S.resolve(moment: .rest, face: .hidden) == .moment(.rest)
                        && S.resolve(moment: .rest, face: .armed) == .moment(.rest),
                     "off or armed, the island is the padlock pill as today")
        suite.expect(S.resolve(moment: .rest, face: .scanning) == .scan(.idle)
                        && S.resolve(moment: .rest, face: .success) == .scan(.success)
                        && S.resolve(moment: .rest, face: .failure(.wrongFace)) == .scan(.failure),
                     "scanning, matched and not matched play Glance's idle, unlock and unsuccessful animations")
        suite.expect(S.resolve(moment: .farewell, face: .scanning) == .scan(.idle)
                        && S.resolve(moment: .remoteLock(device: "iPhone"), face: .failure(.timedOut)) == .scan(.failure),
                     "a scan wins over the greetings")
        suite.expect(S.resolve(moment: .rest, face: .needsTouchID) == .touchID
                        && S.resolve(moment: .farewell, face: .needsTouchID) == .moment(.farewell),
                     "the Touch ID line replaces the island at rest, after the farewell")
        suite.expect(S.resolve(moment: welcome, face: .success) == .moment(welcome)
                        && S.resolve(moment: .bare, face: .scanning) == .moment(.bare),
                     "unlocked, the welcome (or the bare notch) wins over everything")
        suite.expect(S.showsFaceGlyph(moment: .rest, face: .armed) && !S.showsFaceGlyph(moment: .farewell, face: .armed)
                        && !S.showsFaceGlyph(moment: .rest, face: .hidden) && !S.showsFaceGlyph(moment: .rest, face: .scanning),
                     "the face glyph shows on the resting pill while armed")
        suite.expect(S.hoverActivates(.armed) && S.hoverActivates(.failure(.spoofSuspected)) && !S.hoverActivates(.scanning)
                        && !S.hoverActivates(.success) && !S.hoverActivates(.needsTouchID) && !S.hoverActivates(.hidden),
                     "hovering asks for a scan while armed or holding a failure, as in Glance")
        suite.expect(!S.tracksHover(.hidden) && S.tracksHover(.armed) && S.tracksHover(.needsTouchID),
                     "the island follows the pointer only while face unlock shows")
        suite.expect(FaceUnlockIslandMedia.idle.loops && !FaceUnlockIslandMedia.success.loops && !FaceUnlockIslandMedia.failure.loops,
                     "only the idle animation loops; the results hold their last frame")
        suite.expect(FaceUnlockIslandMedia.allCases.map(\.resource) == ["idleanimation", "unlockanimation", "unsuccessfulunlockanimation"]
                        && FaceUnlockIslandMedia.poster == "unlockstatic" && FaceUnlockIslandMedia.folder == "FaceUnlock",
                     "each state plays Glance's own file, from the bundle's FaceUnlock folder")
    }

    private static func sizes(_ suite: TestSuite) {
        typealias L = FaceUnlockIslandLayout
        let camera = CGSize(width: 205, height: 37)
        let pill = CGSize(width: 285, height: 37)
        suite.expect(L.scanSize(style: .original, resting: CGSize(width: 240, height: 37), camera: camera) == L.panel
                        && L.panel == CGSize(width: 252, height: 200),
                     "scanning grows into Glance's 220 × 200 panel with its flare")
        suite.expect(L.scanSize(style: .original, resting: pill, camera: camera) == CGSize(width: 285, height: 200)
                        && L.scanSize(style: .none, resting: pill, camera: camera) == CGSize(width: 285, height: 200),
                     "never narrower than the pill it grows out of; no animation keeps the panel")
        suite.expect(L.scanSize(style: .minimal, resting: CGSize(width: 240, height: 37), camera: camera)
                        == CGSize(width: 205 + 108, height: 49),
                     "the minimal style widens beside the camera and grows 12 pt, as Glance's does")
        suite.expect(L.videoSide(in: L.panel) == 144 && L.minimalVideoSide(height: 49) == 27 && L.videoSide(in: .zero) == 0,
                     "the square video fits between Glance's paddings")
        suite.expect(L.armedWing(slot: 0) == L.glyphBox && L.armedWing(slot: 20) == 20 + L.glyphGap + L.glyphBox,
                     "armed, the right wing makes room for the face glyph after its slot")
        suite.expect(L.glyphBox == ZenithLockIsland.padlockSize + 6 && L.glyphSize > ZenithLockIsland.padlockSize,
                     "the face glyph takes a box as wide as the padlock's, a point bigger since it is lighter")
        let resting: CGFloat = 40
        let armedPill = ZenithLockIsland.wing(for: L.armedWing(slot: 0), resting: resting)
        suite.expect(armedPill >= L.glyphBox + ZenithLockIsland.wingInset * 2,
                     "the pill widens until the glyph keeps the padlock's inset from the right edge")
        let surface = CGRect(x: 653, y: 945, width: 285, height: 37)
        let hover = L.hoverRect(surface: surface, shown: L.panel)
        suite.expect(abs(hover.midX - surface.midX) < 0.01 && hover.maxY == surface.maxY + L.hoverOutset
                        && hover.height == L.panel.height + L.hoverOutset * 2,
                     "the pointer counts over the visible panel, hanging from the screen's top at the camera")
        suite.expect(!hover.contains(CGPoint(x: surface.midX, y: surface.maxY - 230))
                        && hover.contains(CGPoint(x: surface.midX + 120, y: surface.maxY - 100)),
                     "and nowhere else in the island's larger window")
        let fit = L.touchIDFit(camera: camera.height, resting: pill.width, screenWidth: 1512)
        suite.expect(fit.lines == 1 && fit.size.width >= max(320, pill.width)
                        && fit.size.height == camera.height + ZenithIslandInset.belowCamera + ZenithIslandBurstLayout.markSide
                            + ZenithIslandInset.padding,
                     "the Touch ID line fits one row below the camera, at least as wide as the pill")
        let window = ZenithLockIsland.windowFrame(around: surface, in: CGRect(x: 0, y: 0, width: 1512, height: 982))
        suite.expect(window.height >= L.panel.height && window.width >= L.panel.width,
                     "the island's window has room for the scanning panel")
    }

    private static func timing(_ suite: TestSuite) {
        typealias T = FaceUnlockIslandTiming
        suite.expect(T.welcomeDelay(successSince: nil) == 0 && T.welcomeDelay(successSince: 5) == 0,
                     "with no success animation playing, the welcome grows at once")
        suite.expect(abs(T.welcomeDelay(successSince: 0) - (T.successVideo + T.successBeat)) < 0.0001
                        && abs(T.welcomeDelay(successSince: 0.5) - (T.successVideo + T.successBeat - 0.5)) < 0.0001,
                     "unlocked mid-success, the island plays the unlock animation out, then morphs into the welcome")
        suite.expect(abs(T.successVideo - 1.22) < 0.01 && abs(T.failureVideo - 1.52) < 0.01
                        && FaceUnlockIslandMedia.success.stillTime < T.successVideo,
                     "Glance's media lengths; the still is the resolved last frame")
    }

    private static func style(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.face-unlock-island"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        suite.expect(FaceUnlockIslandStyle.current(in: defaults) == .original, "unset, the style is Glance's original")
        defaults.set("minimal", forKey: FaceUnlockIslandStyle.defaultsKey)
        suite.expect(FaceUnlockIslandStyle.current(in: defaults) == .minimal, "the settings' choice is read")
        defaults.set("sparkles", forKey: FaceUnlockIslandStyle.defaultsKey)
        suite.expect(FaceUnlockIslandStyle.current(in: defaults) == .original, "an unknown value falls back to the original")
        suite.expect(FaceUnlockIslandStyle.defaultsKey == "faceUnlockAnimationStyle"
                        && !FaceUnlockIslandStyle.playsResults(.none) && FaceUnlockIslandStyle.playsResults(.minimal),
                     "the key is the settings' own; none skips the result animations")
        defaults.removePersistentDomain(forName: name)
    }
}
