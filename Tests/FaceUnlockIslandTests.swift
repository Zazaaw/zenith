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
        suite.expect(L.armedWing(slot: 0) == L.glyphSize && L.armedWing(slot: 20) == 20 + L.glyphGap + L.glyphSize,
                     "armed, the right wing makes room for the face glyph after its slot")
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
