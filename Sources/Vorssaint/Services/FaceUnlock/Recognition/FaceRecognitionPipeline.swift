// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (glance/FaceRecognitionPipeline.swift).
//
// Only place that should construct a FaceEmbedder — keeps all consumers in sync.

import CoreGraphics
import Foundation
import os

struct FaceRecognitionResult {
    let embedding: [Float]
    /// What was actually fed to the embedder, for debug UIs to inspect.
    let alignedImage: CGImage
    let alignmentTier: AlignmentTier
    let quality: Float?
    let face: DetectedFace
}

enum FaceRecognitionPipelineError: LocalizedError {
    case noFaceDetected
    case alignmentFailed

    var errorDescription: String? {
        switch self {
        case .noFaceDetected: return "No face detected in frame."
        case .alignmentFailed: return "Could not align the detected face."
        }
    }
}

/// Zenith fork: one pipeline for the whole app, loaded at first use, since the
/// model has to be compiled before it can load (see `ArcFaceModelLoader`).
/// Glance builds one per controller with a synchronous init.
@MainActor
final class FaceRecognitionPipeline {
    nonisolated let embedder: FaceEmbedder

    /// Set when ArcFace failed to compile or load and the weaker Vision feature-print embedder is in use instead.
    let usingFallbackEmbedder: Bool
    let fallbackReason: String?

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "zenith", category: "FaceUnlock")
    private static var loadTask: Task<FaceRecognitionPipeline, Never>?
    /// The loaded pipeline, once `shared()` has finished.
    private(set) static var loaded: FaceRecognitionPipeline?

    private init(embedder: FaceEmbedder, fallbackReason: String?) {
        self.embedder = embedder
        self.usingFallbackEmbedder = fallbackReason != nil
        self.fallbackReason = fallbackReason
    }

    /// Compiles and loads ArcFace on the first call, falling back to Vision's
    /// feature print (and saying why) when it can't. Later calls return the same pipeline.
    static func shared() async -> FaceRecognitionPipeline {
        if let loaded { return loaded }
        if let loadTask { return await loadTask.value }
        let task = Task { @MainActor () -> FaceRecognitionPipeline in
            let pipeline: FaceRecognitionPipeline
            do {
                let model = try await ArcFaceModelLoader.loadModel()
                pipeline = FaceRecognitionPipeline(embedder: try ArcFaceEmbedder(model: model), fallbackReason: nil)
                log.info("Face unlock is using ArcFace.")
            } catch {
                let reason = error.localizedDescription
                pipeline = FaceRecognitionPipeline(embedder: VisionFeaturePrintEmbedder(), fallbackReason: reason)
                log.error("ArcFace unavailable, using Vision Feature Print: \(reason, privacy: .public)")
            }
            loaded = pipeline
            return pipeline
        }
        loadTask = task
        return await task.value
    }

    /// Runs detect/align/embed from a background task instead of blocking the main actor.
    /// - Parameter previousBoundingBox: previous frame's selected box, if any — lets a continuous scanner keep selection "stuck" to the same person instead of re-picking every frame.
    nonisolated func recognize(in frame: CGImage, preferNear previousBoundingBox: CGRect? = nil) throws -> FaceRecognitionResult {
        let faces = try FaceDetector.detectFaces(in: frame)
        guard let face = FaceSelection.selectDominantFace(
            in: faces,
            preferNear: previousBoundingBox,
            minimumWidth: FaceUnlockRecognitionSettings.minimumFaceWidth()
        ) else {
            throw FaceRecognitionPipelineError.noFaceDetected
        }
        return try recognize(face, in: frame)
    }

    /// Aligns and embeds an already-chosen face; enrollment uses this to bypass the prominence filter so a too-small face reads as "move closer" rather than "nobody there".
    nonisolated func recognize(_ face: DetectedFace, in frame: CGImage) throws -> FaceRecognitionResult {
        let inputImage: CGImage
        let tier: AlignmentTier
        if embedder.requiresAlignment {
            guard let aligned = FaceAligner.align(face, from: frame) else {
                throw FaceRecognitionPipelineError.alignmentFailed
            }
            inputImage = aligned.image
            tier = aligned.tier
        } else {
            guard let cropped = FaceDetector.crop(face, from: frame) else {
                throw FaceRecognitionPipelineError.alignmentFailed
            }
            inputImage = cropped
            tier = .paddedCrop
        }

        let embedding = try embedder.embedding(for: inputImage)
        return FaceRecognitionResult(embedding: embedding, alignedImage: inputImage, alignmentTier: tier, quality: face.quality, face: face)
    }

    /// Sorted by centroid similarity descending; includes stale identities (different embedder) since `bestMatch` is what excludes them from actually matching.
    nonisolated func score(_ embedding: [Float], against identities: [FaceIdentity]) -> [ScoredIdentity] {
        FaceMatching.score(embedding, against: identities)
    }

    /// Shared by Face Lab and the unlock scan so tuning stays consistent.
    nonisolated func bestMatch(in scored: [ScoredIdentity], threshold: Float) -> ScoredIdentity? {
        FaceMatching.bestMatch(in: scored, threshold: threshold, modelIdentifier: embedder.modelIdentifier)
    }
}
