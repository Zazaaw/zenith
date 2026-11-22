// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Foundation

/// Zenith fork: face unlock's preferences, read from the defaults as one
/// snapshot (Glance's `GlanceSettings`, without its own store). Settings
/// writes the keys through `@AppStorage`; the coordinator reads a fresh
/// snapshot at each decision, so a change applies at the next lock.
struct FaceUnlockPreferences: Equatable {
    static let detectionRange = 3...10
    static let defaultDetectionSeconds = 5

    var isEnabled: Bool
    var triggers: Set<FaceUnlockTrigger>
    var autoLock: FaceUnlockAutoLock
    var retryOnHover: Bool
    var autoRetryOnce: Bool
    var detectionSeconds: Int
    var animationStyle: FaceUnlockAnimationStyle

    /// Nothing is shown on the lock screen with the animation off: scans run
    /// headless, as Glance's "Show animation" switched off.
    var showsIsland: Bool { animationStyle != .none }

    static let defaults = FaceUnlockPreferences(
        isEnabled: false, triggers: FaceUnlockTriggers.defaultSet, autoLock: .sevenDays, retryOnHover: true,
        autoRetryOnce: false, detectionSeconds: defaultDetectionSeconds, animationStyle: .original)

    init(isEnabled: Bool, triggers: Set<FaceUnlockTrigger>, autoLock: FaceUnlockAutoLock, retryOnHover: Bool,
         autoRetryOnce: Bool, detectionSeconds: Int, animationStyle: FaceUnlockAnimationStyle) {
        self.isEnabled = isEnabled
        self.triggers = triggers
        self.autoLock = autoLock
        self.retryOnHover = retryOnHover
        self.autoRetryOnce = autoRetryOnce
        self.detectionSeconds = Self.clampedDetection(detectionSeconds)
        self.animationStyle = animationStyle
    }

    init(defaults: UserDefaults) {
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }
        let fallback = Self.defaults
        self.init(
            isEnabled: defaults.bool(forKey: DefaultsKey.faceUnlockEnabled),
            triggers: FaceUnlockTriggers.decode(defaults.string(forKey: DefaultsKey.faceUnlockTriggers)),
            autoLock: (defaults.object(forKey: DefaultsKey.faceUnlockAutoLockDays) as? Int)
                .flatMap(FaceUnlockAutoLock.init(rawValue:)) ?? fallback.autoLock,
            retryOnHover: bool(DefaultsKey.faceUnlockRetryOnHover, fallback.retryOnHover),
            autoRetryOnce: bool(DefaultsKey.faceUnlockAutoRetry, fallback.autoRetryOnce),
            detectionSeconds: defaults.object(forKey: DefaultsKey.faceUnlockDetectionSeconds) as? Int
                ?? fallback.detectionSeconds,
            animationStyle: defaults.string(forKey: DefaultsKey.faceUnlockAnimationStyle)
                .flatMap(FaceUnlockAnimationStyle.init(rawValue:)) ?? fallback.animationStyle)
    }

    static func clampedDetection(_ seconds: Int) -> Int {
        min(max(seconds, detectionRange.lowerBound), detectionRange.upperBound)
    }
}

/// The triggers as one string, e.g. `onLock,onWake,onHover`. Unknown names
/// are skipped; an empty or unreadable value is the default set, so face
/// unlock always has something that starts it (Glance keeps one selected).
enum FaceUnlockTriggers {
    /// Glance's defaults: on lock and on wake, and hovering the island. Space
    /// is off since it needs Input Monitoring, asked only when it is turned on.
    static let defaultSet: Set<FaceUnlockTrigger> = [.onLock, .onWake, .onHover]
    static let defaultEncoded = encode(defaultSet)

    static func encode(_ triggers: Set<FaceUnlockTrigger>) -> String {
        FaceUnlockTrigger.allCases.filter(triggers.contains).map(\.rawValue).joined(separator: ",")
    }

    static func decode(_ value: String?) -> Set<FaceUnlockTrigger> {
        let parsed = Set((value ?? "").split(separator: ",").compactMap {
            FaceUnlockTrigger(rawValue: $0.trimmingCharacters(in: .whitespaces))
        })
        return parsed.isEmpty ? defaultSet : parsed
    }

    /// Turning one trigger on or off; the last one cannot be turned off.
    static func toggled(_ trigger: FaceUnlockTrigger, on: Bool, in triggers: Set<FaceUnlockTrigger>)
        -> Set<FaceUnlockTrigger> {
        var next = triggers
        if on { next.insert(trigger) } else { next.remove(trigger) }
        return next.isEmpty ? triggers : next
    }
}

/// Liveness: Light rejects photos and screens; Heavy also asks for a proof of
/// life (a blink, a turn). Stored as `faceUnlockLivenessMode` for recognition.
enum FaceUnlockLivenessLevel: String, CaseIterable, Identifiable {
    case light, heavy
    var id: String { rawValue }
}

/// The three stops of Glance's "Match confidence", as cosine-similarity
/// thresholds stored in `faceUnlockMatchThreshold`. The default is the 0.66
/// Glance stores and unlocks with (`GlanceSettings`); Glance's slider centres
/// its stops on 0.63 instead, so a fresh install reads "More strict" there.
/// Here the stops keep Glance's 0.05 spacing around the value in use.
enum FaceUnlockMatchLevel: Int, CaseIterable, Identifiable {
    case lessStrict, standard, moreStrict
    var id: Int { rawValue }

    var threshold: Double {
        switch self {
        case .lessStrict: return 0.61
        case .standard: return 0.66
        case .moreStrict: return 0.71
        }
    }

    /// The stop nearest a stored value, which a slider may not have written.
    static func nearest(to threshold: Double) -> FaceUnlockMatchLevel {
        allCases.min { abs($0.threshold - threshold) < abs($1.threshold - threshold) } ?? .standard
    }
}

/// Glance's "Detection distance": the smallest face, as a fraction of the
/// frame's width, taken for the person at the Mac rather than a passer-by
/// (`faceUnlockMinimumFaceWidth`). The default is the 0.21 Glance stores;
/// the stops keep its 0.04 spacing around it.
enum FaceUnlockDistanceLevel: Int, CaseIterable, Identifiable {
    case close, standard, far
    var id: Int { rawValue }

    var minimumFaceWidth: Double {
        switch self {
        case .close: return 0.25
        case .standard: return 0.21
        case .far: return 0.17
        }
    }

    static func nearest(to width: Double) -> FaceUnlockDistanceLevel {
        allCases.min { abs($0.minimumFaceWidth - width) < abs($1.minimumFaceWidth - width) } ?? .standard
    }
}
