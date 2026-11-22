// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance
// (glance/Settings/GlanceSettings.swift, glance/SecureCredentialManager.swift).

import CryptoKit
import Foundation

/// Zenith fork: what recognition reads from the rest of face unlock. The keys
/// are registered by the settings page; every read falls back to Glance's
/// default, so recognition behaves the same before anything is registered.
enum FaceUnlockRecognitionSettings {
    static let livenessEnabledKey = "faceUnlockLivenessEnabled"
    static let livenessModeKey = "faceUnlockLivenessMode"
    static let matchThresholdKey = "faceUnlockMatchThreshold"
    static let cameraIDKey = "faceUnlockCameraID"
    static let detectionSecondsKey = "faceUnlockDetectionSeconds"
    /// Glance's "detection distance": below this fraction of the frame width a
    /// face is a bystander, not a candidate.
    static let minimumFaceWidthKey = "faceUnlockMinimumFaceWidth"

    /// Glance's defaults.
    static let defaultMatchThreshold: Float = 0.66
    static let defaultDetectionSeconds = 5
    static let detectionSecondsRange = 3...10
    static let defaultMinimumFaceWidth: Float = 0.21
    static let minimumFaceWidthRange: ClosedRange<Float> = 0.1...0.5

    /// Off means recognition alone decides an unlock: a photo of the enrolled
    /// user would pass.
    static func livenessEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: livenessEnabledKey) as? Bool ?? true
    }

    /// Light by default: Heavy needs a blink, pose or depth signal a still,
    /// non-blinking user may never produce, while Light still catches the main
    /// attack (a photo on a phone screen).
    static func livenessMode(_ defaults: UserDefaults = .standard) -> LivenessMode {
        defaults.string(forKey: livenessModeKey).flatMap(LivenessMode.init(rawValue:)) ?? .light
    }

    /// Raw cosine similarity both the centroid and the closest sample must clear.
    static func matchThreshold(_ defaults: UserDefaults = .standard) -> Float {
        guard let number = defaults.object(forKey: matchThresholdKey) as? NSNumber else {
            return defaultMatchThreshold
        }
        let value = number.floatValue
        return value.isFinite ? min(max(value, -1), 1) : defaultMatchThreshold
    }

    /// The camera to open; nil (or an empty string) is the system's default camera.
    static func cameraID(_ defaults: UserDefaults = .standard) -> String? {
        guard let id = defaults.string(forKey: cameraIDKey), !id.isEmpty else { return nil }
        return id
    }

    static func setCameraID(_ id: String?, _ defaults: UserDefaults = .standard) {
        if let id, !id.isEmpty {
            defaults.set(id, forKey: cameraIDKey)
        } else {
            defaults.removeObject(forKey: cameraIDKey)
        }
    }

    /// How long one scan window looks for a face, clamped to Glance's 3...10 s.
    static func detectionSeconds(_ defaults: UserDefaults = .standard) -> Int {
        guard let number = defaults.object(forKey: detectionSecondsKey) as? NSNumber else {
            return defaultDetectionSeconds
        }
        return min(max(number.intValue, detectionSecondsRange.lowerBound), detectionSecondsRange.upperBound)
    }

    static func minimumFaceWidth(_ defaults: UserDefaults = .standard) -> Float {
        guard let number = defaults.object(forKey: minimumFaceWidthKey) as? NSNumber, number.floatValue.isFinite else {
            return defaultMinimumFaceWidth
        }
        return min(max(number.floatValue, minimumFaceWidthRange.lowerBound), minimumFaceWidthRange.upperBound)
    }
}

/// Zenith fork: the session key enrolled faces are encrypted under. Glance
/// encrypts them with the same Touch-ID-gated key as the stored password; in
/// Zenith the security side owns that key and conforms to this. A nil key means
/// the session is locked: enrolled faces can be neither read nor saved.
protocol FaceUnlockKeyProvider: AnyObject {
    var sessionKey: SymmetricKey? { get }
}

enum FaceUnlockKeys {
    /// Set once at launch by the security side.
    nonisolated(unsafe) static var provider: FaceUnlockKeyProvider?

    static var sessionKey: SymmetricKey? { provider?.sessionKey }
    static var isSessionUnlocked: Bool { sessionKey != nil }
}

extension Notification.Name {
    /// Posted by the key provider whenever its session key appears or goes away,
    /// so the enrollment store reloads itself instead of every caller having to
    /// remember to (Glance's `secureCredentialSessionDidChange`).
    static let faceUnlockSessionDidChange = Notification.Name("FaceUnlock.sessionDidChange")
}
