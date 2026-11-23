// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (glance/FaceLabController.swift).
//
// Face Lab's threshold calibration: tagged scores and the cutoff they suggest.

import Foundation

/// One manually-tagged data point for threshold calibration: "this
/// similarity score came from a genuine match" or "from an impostor."
struct FaceLabCalibrationSample: Identifiable {
    let id = UUID()
    let centroidSimilarity: Float
    let isGenuine: Bool
}

/// Zenith fork: the calibration arithmetic on its own, so it is testable.
enum FaceLabCalibration {
    static func suggestedThreshold(_ samples: [FaceLabCalibrationSample]) -> Float? {
        let genuine = samples.filter(\.isGenuine).map(\.centroidSimilarity)
        let impostor = samples.filter { !$0.isGenuine }.map(\.centroidSimilarity)
        guard let minGenuine = genuine.min(), let maxImpostor = impostor.max() else { return nil }
        return (minGenuine + maxImpostor) / 2
    }

    static func distributionsOverlap(_ samples: [FaceLabCalibrationSample]) -> Bool {
        let genuine = samples.filter(\.isGenuine).map(\.centroidSimilarity)
        let impostor = samples.filter { !$0.isGenuine }.map(\.centroidSimilarity)
        guard let minGenuine = genuine.min(), let maxImpostor = impostor.max() else { return false }
        return maxImpostor >= minGenuine
    }
}
