// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.
// Sizes and timings follow Glance's NotchGeometry and NotchOverlayController.

import CoreGraphics
import Foundation

// Zenith fork: how the lock screen's padlock island shows face unlock
// (FaceUnlockPresence): a face glyph on its right wing while armed, Glance's
// scanning panel and its animations while it looks, and a line asking for
// Touch ID when face unlock cannot type the password yet. Pure rules and
// sizes; the view is ZenithLockScreenIsland, the media FaceUnlockMediaView.
// Compiled into the tests.

/// Which of Glance's animations the island plays.
enum FaceUnlockIslandMedia: String, Equatable, CaseIterable {
    /// Looking for a face: Glance's idle animation, looping.
    case idle
    /// Matched: the unlock animation, once, held on its last frame.
    case success
    /// Not matched: the unsuccessful animation, once, held on its last frame.
    case failure

    var resource: String {
        switch self {
        case .idle: return "idleanimation"
        case .success: return "unlockanimation"
        case .failure: return "unsuccessfulunlockanimation"
        }
    }

    /// Glance loops only the idle animation; the others end on what they mean.
    var loops: Bool { self == .idle }

    /// The frame a still (the catalog, or no animation) shows: well into the
    /// loop, or the resolved last frame.
    var stillTime: TimeInterval {
        switch self {
        case .idle: return 1.0
        case .success: return FaceUnlockIslandTiming.successVideo - 0.02
        case .failure: return FaceUnlockIslandTiming.failureVideo - 0.02
        }
    }

    /// The still image shown before a video is ready, and in place of one
    /// with the animation style set to none: the unlock's first frame.
    static let poster = "unlockstatic"
    /// Where build.sh puts the media in the app's resources.
    static let folder = "FaceUnlock"
}

/// What the padlock island shows, from its own moment and face unlock's state.
enum FaceUnlockIslandStage: Equatable {
    /// The island's own moment (rest, farewell, remote lock, welcome, bare).
    case moment(ZenithLockIslandMoment)
    /// Glance's scanning panel, playing `media`.
    case scan(FaceUnlockIslandMedia)
    /// "Unlock with Touch ID once to use Face ID", below the camera.
    case touchID

    /// Unlocking wins over everything; a scan and its result win over the
    /// greetings, which are short and come first; the Touch ID line and the
    /// armed glyph only ever replace the island at rest.
    static func resolve(moment: ZenithLockIslandMoment, face: FaceUnlockIslandState) -> FaceUnlockIslandStage {
        switch moment {
        case .welcome, .bare: return .moment(moment)
        case .rest, .farewell, .remoteLock: break
        }
        switch face {
        case .scanning: return .scan(.idle)
        case .success: return .scan(.success)
        case .failure: return .scan(.failure)
        case .needsTouchID: return moment == .rest ? .touchID : .moment(moment)
        case .hidden, .armed: return .moment(moment)
        }
    }

    /// Whether the right wing adds the face glyph: armed, at rest.
    static func showsFaceGlyph(moment: ZenithLockIslandMoment, face: FaceUnlockIslandState) -> Bool {
        face == .armed && moment == .rest
    }

    /// Hovering the island asks for a scan while it waits or holds a failure, as in Glance.
    static func hoverActivates(_ face: FaceUnlockIslandState) -> Bool {
        switch face {
        case .armed, .failure: return true
        case .hidden, .scanning, .success, .needsTouchID: return false
        }
    }

    /// Whether the island takes the pointer at all: only while face unlock shows.
    static func tracksHover(_ face: FaceUnlockIslandState) -> Bool { face != .hidden }

    /// Zenith fork: Glance's continuous corners for face unlock's own shapes
    /// (the armed pill with its glyph, the scan and its results, the Touch ID
    /// line); every other island keeps Zenith's.
    static func usesGlanceCorners(_ stage: FaceUnlockIslandStage, faceGlyph: Bool) -> Bool {
        switch stage {
        case .scan, .touchID: return true
        case .moment(.rest): return faceGlyph
        case .moment: return false
        }
    }

    /// Zenith fork: the state the island takes when face unlock reports
    /// `incoming`. A match holds through the unlock: face unlock stands down
    /// (hidden) as the session unlocks, often a beat before the lock screen
    /// hears of it, and the success must morph straight into the welcome
    /// rather than back into the resting pill first. Still locked, it is taken.
    static func next(current: FaceUnlockIslandState, incoming: FaceUnlockIslandState,
                     sessionLocked: Bool) -> FaceUnlockIslandState {
        current == .success && incoming == .hidden && !sessionLocked ? .success : incoming
    }
}

/// Glance's sizes, in the island's terms. The notch panel is Glance's
/// 220 × 200 body plus its 16 pt flare on each side; Zenith's island has
/// shoulders instead of a flare, so it takes the whole width.
enum FaceUnlockIslandLayout {
    static let panel = CGSize(width: 252, height: 200)
    /// Around the video inside the panel (Glance's notch content padding).
    static let videoTop: CGFloat = 26
    static let videoBottom: CGFloat = 30
    static let videoSides: CGFloat = 40
    /// Minimal style: the island widens beside the camera and grows a little
    /// below it, the padlock on the left wing and the video on the right.
    static let minimalWing: CGFloat = 54
    static let minimalBump: CGFloat = 12
    static let minimalVideoWidth: CGFloat = 40
    static let minimalVideoInset: CGFloat = 11
    static let minimalLockSize: CGFloat = 16
    /// The face glyph on the armed island's right wing, mirroring the padlock
    /// on the left: a little bigger than the padlock's 17 points, the glyph
    /// being lighter, in a box as wide as the padlock's, as far from the right
    /// edge as the padlock is from the left; and its gap to the slot.
    static let glyphSize: CGFloat = 18
    static var glyphBox: CGFloat { ZenithLockIsland.padlockSize + 6 }
    static let glyphGap: CGFloat = 8

    /// The island for a scan: Glance's panel (or its minimal widening), never
    /// narrower than the island it grows out of.
    static func scanSize(style: FaceUnlockAnimationStyle, resting: CGSize, camera: CGSize) -> CGSize {
        switch style {
        case .original, .none:
            return CGSize(width: max(panel.width, resting.width), height: max(panel.height, resting.height))
        case .minimal:
            return CGSize(width: max(camera.width + minimalWing * 2, resting.width), height: camera.height + minimalBump)
        }
    }

    /// The square video inside the panel, aspect fitted between its paddings.
    static func videoSide(in size: CGSize) -> CGFloat {
        max(0, min(size.width - videoSides * 2, size.height - videoTop - videoBottom))
    }

    /// The minimal style's video beside the camera.
    static func minimalVideoSide(height: CGFloat) -> CGFloat {
        max(0, min(minimalVideoWidth, height - minimalVideoInset * 2))
    }

    /// Slack around the visible panel before the pointer counts as off it
    /// (Glance's), so the very edge of the shape still takes it.
    static let hoverOutset: CGFloat = 6

    /// Where the island's visible panel is on screen: `shown` hanging from
    /// the top of the resting island's `surface`, centred on the camera.
    static func hoverRect(surface: CGRect, shown: CGSize) -> CGRect {
        CGRect(x: surface.midX - shown.width / 2, y: surface.maxY - shown.height, width: shown.width, height: shown.height)
            .insetBy(dx: -hoverOutset, dy: -hoverOutset)
    }

    /// The right wing's content while armed: the slot, then the face glyph.
    static func armedWing(slot: CGFloat) -> CGFloat {
        max(0, slot) + (slot > 0 ? glyphGap : 0) + glyphBox
    }

    /// The Touch ID line: its glyph on a tile and the words, one row below
    /// the camera, with the pieces and gaps of the island's bursts.
    static func touchIDRow(_ text: String = FaceUnlockIslandText.needsTouchID) -> ZenithIslandBurstLayout.Row {
        typealias Layout = ZenithIslandBurstLayout
        return .init(leading: Layout.markSide + Layout.tileGap, title: Layout.words(text, Layout.chargeTitleFont),
                     subtitle: 0, wrapsTitle: true)
    }

    /// The island grown for the Touch ID line, at least as wide as the island
    /// it grows out of (`resting`).
    static func touchIDFit(camera: CGFloat, resting: CGFloat, screenWidth: CGFloat) -> ZenithIslandBurstLayout.Fit {
        typealias Layout = ZenithIslandBurstLayout
        return Layout.fit(touchIDRow(), height: { Layout.markSide + CGFloat(max(1, min(2, $0)) - 1) * Layout.titleLineHeight },
                          top: camera + ZenithIslandInset.belowCamera, bottom: ZenithIslandInset.padding,
                          minimum: 320, covering: resting, floats: false, screenWidth: screenWidth)
    }
}

/// Glance's media lengths.
enum FaceUnlockIslandTiming {
    /// unlockanimation.mp4 and unsuccessfulunlockanimation.mp4, at 60 fps.
    static let successVideo: TimeInterval = 1.22
    static let failureVideo: TimeInterval = 1.52
    /// A beat on the success's last frame before the island moves on.
    static let successBeat: TimeInterval = 0.12

    /// Unlocked while the success animation plays: how much longer before the
    /// island morphs into the welcome, `since` seconds into it (nil: none playing).
    static func welcomeDelay(successSince since: TimeInterval?) -> TimeInterval {
        guard let since, since.isFinite else { return 0 }
        return max(0, successVideo + successBeat - max(0, since))
    }
}

enum FaceUnlockIslandText {
    static let needsTouchID = "Unlock with Touch ID once to use Face ID"
}

/// The animation style the island reads. The settings side registers and
/// writes the key; read here with the original style as the fallback, under
/// a name of the island's own so the two sides never declare the same one.
enum FaceUnlockIslandStyle {
    static let defaultsKey = "faceUnlockAnimationStyle"

    static func current(in defaults: UserDefaults = .standard) -> FaceUnlockAnimationStyle {
        defaults.string(forKey: defaultsKey).flatMap(FaceUnlockAnimationStyle.init(rawValue:)) ?? .original
    }

    /// Whether the success and failure animations play; with none the panel
    /// shows the still, as Glance does.
    static func playsResults(_ style: FaceUnlockAnimationStyle) -> Bool { style != .none }
}
