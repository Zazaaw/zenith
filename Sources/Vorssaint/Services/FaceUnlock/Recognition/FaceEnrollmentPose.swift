// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance
// (glance/Onboarding/OnboardingController.swift, glance/Onboarding/EnrollmentDirectionSweep.swift).
//
// The guided nine-pose enrollment's geometry: which head turn each pose wants, when
// a turn matches, when it goes too far, and where the head points for the ring.
// Pure: no camera, Vision or UI, so it is testable.

import CoreGraphics
import Foundation

/// A single guided head pose captured during enrollment — center plus the
/// 8 compass directions, in the exact order presented to the user.
enum EnrollmentPose: Int, CaseIterable {
    case center, left, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft

    enum YawBand { case left, none, right }
    enum PitchBand { case up, none, down }

    var yawBand: YawBand {
        switch self {
        case .left, .topLeft, .bottomLeft: return .left
        case .right, .topRight, .bottomRight: return .right
        case .center, .top, .bottom: return .none
        }
    }

    var pitchBand: PitchBand {
        switch self {
        case .top, .topLeft, .topRight: return .up
        case .bottom, .bottomLeft, .bottomRight: return .down
        case .center, .left, .right: return .none
        }
    }

    /// Compass angle (0 = up, clockwise) this pose's ring sector is centered
    /// on. `nil` for center, which pulses the whole ring instead of
    /// claiming a sector.
    var compassAngle: Double? {
        switch self {
        case .center: return nil
        case .left: return 270
        case .topLeft: return 315
        case .top: return 0
        case .topRight: return 45
        case .right: return 90
        case .bottomRight: return 135
        case .bottom: return 180
        case .bottomLeft: return 225
        }
    }

    var instruction: String {
        switch self {
        case .center: return "Look straight at the camera"
        case .left: return "Turn your head slightly left"
        case .topLeft: return "Turn your head to the top left"
        case .top: return "Turn your head slightly up"
        case .topRight: return "Turn your head to the top right"
        case .right: return "Turn your head slightly right"
        case .bottomRight: return "Turn your head to the bottom right"
        case .bottom: return "Turn your head slightly down"
        case .bottomLeft: return "Turn your head to the bottom left"
        }
    }

    /// Relaxes this pose's yaw/pitch bands — same knob as `stallWidenFactor`, so >1 is easier.
    var matchLeniency: Float {
        switch self {
        case .bottomLeft, .bottomRight: return 1.5
        case .bottom: return 1.2
        default: return 1
        }
    }

    /// Persisted alongside each sample so a saved identity records which
    /// pose each embedding came from.
    var name: String {
        switch self {
        case .center: return "center"
        case .left: return "left"
        case .topLeft: return "top_left"
        case .top: return "top"
        case .topRight: return "top_right"
        case .right: return "right"
        case .bottomRight: return "bottom_right"
        case .bottom: return "bottom"
        case .bottomLeft: return "bottom_left"
        }
    }
}

/// An extreme head turn is not useful enrollment data. Kept separate from
/// "too far", which describes face distance rather than pose.
enum EnrollmentExcessiveTurn: Equatable {
    case left, topLeft, up, topRight, right, bottomRight, down, bottomLeft

    var instruction: String {
        switch self {
        case .left: return "Too far left"
        case .topLeft: return "Too far toward the top left"
        case .up: return "Too far up"
        case .topRight: return "Too far toward the top right"
        case .right: return "Too far right"
        case .bottomRight: return "Too far toward the bottom right"
        case .down: return "Too far down"
        case .bottomLeft: return "Too far toward the bottom left"
        }
    }
}

/// Where the head is currently turned, for the ring's live indicator.
struct EnrollmentHeadTurn: Equatable {
    /// Compass angle (0 = up, clockwise) — same frame as `EnrollmentPose.compassAngle`.
    let angle: Double
    /// How far the turn has gone toward the current pose's threshold, 0...1.
    let progress: Double
}

/// Glance's pose-matching bands and the decisions built on them.
enum EnrollmentPoseRules {
    // Pose-matching bands, in radians. Yaw: left turn is positive, matching the mirrored
    // preview. Pitch's sign is the opposite of the initial guess — see `pitchMatches` below.
    static let yawInnerThreshold: Float = 0.24
    static let yawCenterTolerance: Float = 0.18
    static let yawOuterCap: Float = 0.51
    static let pitchInnerThreshold: Float = 0.17
    static let pitchCenterTolerance: Float = 0.15
    static let pitchOuterCap: Float = 0.37
    /// If a pose takes longer than `stallTimeout`, matching bands widen by this factor so an
    /// unusual camera angle can't permanently strand the user.
    static let stallWidenFactor: Float = 1.25
    /// Below this fraction of the threshold the direction is mostly sensor noise.
    static let headTurnDeadzone: Double = 0.15

    static func poseMatches(yaw: Float, pitch: Float, pose: EnrollmentPose, widened: Bool) -> Bool {
        let factor = (widened ? stallWidenFactor : 1.0) * pose.matchLeniency
        return yawMatches(yaw, band: pose.yawBand, factor: factor)
            && pitchMatches(pitch, band: pose.pitchBand, factor: factor)
    }

    static func yawMatches(_ yaw: Float, band: EnrollmentPose.YawBand, factor: Float) -> Bool {
        switch band {
        case .none: return abs(yaw) < yawCenterTolerance * factor
        case .left: return yaw > yawInnerThreshold / factor && yaw < yawOuterCap
        case .right: return yaw < -yawInnerThreshold / factor && yaw > -yawOuterCap
        }
    }

    /// Confirmed empirically: Vision reports negative pitch for "looking up" and positive
    /// for "looking down" — the opposite of the initial guess.
    static func pitchMatches(_ pitch: Float, band: EnrollmentPose.PitchBand, factor: Float) -> Bool {
        switch band {
        case .none: return abs(pitch) < pitchCenterTolerance * factor
        case .up: return pitch < -pitchInnerThreshold / factor && pitch > -pitchOuterCap
        case .down: return pitch > pitchInnerThreshold / factor && pitch < pitchOuterCap
        }
    }

    /// Reports the dominant axis when a user has gone beyond enrollment's safe pose
    /// envelope. At these angles, Vision's embedding is unlikely to be a useful,
    /// repeatable sample, so capture is explicitly rejected before the hold timer runs.
    static func excessiveTurn(yaw: Float, pitch: Float) -> EnrollmentExcessiveTurn? {
        let yawOvershoot = abs(yaw) / yawOuterCap
        let pitchOvershoot = abs(pitch) / pitchOuterCap
        guard max(yawOvershoot, pitchOvershoot) >= 1 else { return nil }

        let yawExceeded = yawOvershoot >= 1
        let pitchExceeded = pitchOvershoot >= 1
        if yawExceeded, pitchExceeded {
            // Vision uses positive yaw for a left turn and negative pitch for an upward turn.
            switch (yaw > 0, pitch < 0) {
            case (true, true): return .topLeft
            case (false, true): return .topRight
            case (false, false): return .bottomRight
            case (true, false): return .bottomLeft
            }
        }
        if yawOvershoot >= pitchOvershoot {
            return yaw > 0 ? .left : .right
        }
        return pitch < 0 ? .up : .down
    }

    /// Live head direction toward `pose`, or `nil` when there's nothing to point at. Axes are normalized
    /// against the pose's thresholds, so `progress` hits 1 as the pose starts matching.
    static func headTurn(yaw: Float, pitch: Float, toward pose: EnrollmentPose) -> EnrollmentHeadTurn? {
        guard pose != .center else { return nil }
        // Vision inverts both axes vs. the screen: +yaw turns left, +pitch looks down.
        let x = Double(-yaw / (yawInnerThreshold / pose.matchLeniency))
        let y = Double(-pitch / (pitchInnerThreshold / pose.matchLeniency))

        let magnitude = (x * x + y * y).squareRoot()
        guard magnitude > headTurnDeadzone else { return nil }

        let degrees = atan2(x, y) * 180 / .pi
        return EnrollmentHeadTurn(angle: degrees < 0 ? degrees + 360 : degrees, progress: min(magnitude, 1))
    }
}

/// The direction the onboarding's light sweep travels for a pose (Glance's
/// `EnrollmentSweepDirection`); the ribbon view itself belongs to the onboarding UI.
enum EnrollmentSweepDirection: CaseIterable, Hashable {
    case left, right, up, down, topLeft, topRight, bottomLeft, bottomRight

    /// Unit travel vector in screen space (x right, y down); sweep originates on the
    /// opposite side, e.g. `.left` travels right → left.
    var travel: CGVector {
        let d = CGFloat(1 / sqrt(2.0))
        switch self {
        case .left:        return CGVector(dx: -1, dy: 0)
        case .right:       return CGVector(dx: 1, dy: 0)
        case .up:          return CGVector(dx: 0, dy: -1)
        case .down:        return CGVector(dx: 0, dy: 1)
        case .topLeft:     return CGVector(dx: -d, dy: -d)
        case .topRight:    return CGVector(dx: d, dy: -d)
        case .bottomLeft:  return CGVector(dx: -d, dy: d)
        case .bottomRight: return CGVector(dx: d, dy: d)
        }
    }

    init?(pose: EnrollmentPose) {
        switch pose {
        case .center:      return nil
        case .left:        self = .left
        case .right:       self = .right
        case .top:         self = .up
        case .bottom:      self = .down
        case .topLeft:     self = .topLeft
        case .topRight:    self = .topRight
        case .bottomLeft:  self = .bottomLeft
        case .bottomRight: self = .bottomRight
        }
    }
}
