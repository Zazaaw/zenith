// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (glance/ArcFaceEmbedder.swift).
//
// Requires a canonically-aligned 112x112 input (see FaceAligner) — unlike VisionFeaturePrintEmbedder, accuracy depends on alignment.
//
// The model is InsightFace's ArcFace `w600k_mbf` (buffalo_s pack), converted to
// Core ML by Glance's tools/convert_arcface.py. InsightFace publishes these
// pretrained weights for non-commercial research use only; see
// Resources/FaceUnlock/NOTICE.txt.

import CoreGraphics
import CoreML
import CoreVideo
import Foundation

enum ArcFaceEmbedderError: LocalizedError {
    case modelNotFound
    case modelCompileFailed(String)
    case modelLoadFailed(String)
    case pixelBufferCreationFailed
    case unexpectedInputSize(got: (Int, Int), expected: Int)
    case unexpectedOutput(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "ArcFace.mlpackage was not found in the app bundle (Contents/Resources/FaceUnlock)."
        case .modelCompileFailed(let detail):
            return "Couldn't compile the ArcFace Core ML model: \(detail)"
        case .modelLoadFailed(let detail):
            return "Failed to load the ArcFace Core ML model: \(detail)"
        case .pixelBufferCreationFailed:
            return "Couldn't prepare the aligned face image for Core ML."
        case .unexpectedInputSize(let got, let expected):
            return "ArcFaceEmbedder expects a \(expected)x\(expected) aligned image, got \(got.0)x\(got.1). Run the face through FaceAligner first."
        case .unexpectedOutput(let detail):
            return "ArcFace model produced an unexpected output: \(detail)"
        }
    }
}

final class ArcFaceEmbedder: FaceEmbedder, @unchecked Sendable {
    let name = "ArcFace (w600k_mbf)"
    let modelIdentifier = "arcface-w600k_mbf-v1"
    let embeddingDimension = 512
    let requiresAlignment = true

    private static let inputSize = FaceAligner.outputSize
    private static let inputName = "input_image"
    private static let outputName = "embedding"

    // Loaded once and reused — model load dominates a single inference.
    private let model: MLModel
    private let pixelBufferPool: CVPixelBufferPool

    /// Zenith fork: takes the loaded model (see `ArcFaceModelLoader`) instead of
    /// locating a precompiled one in the bundle.
    init(model: MLModel) throws {
        self.model = model
        guard let pool = Self.makePixelBufferPool(size: Self.inputSize) else {
            throw ArcFaceEmbedderError.pixelBufferCreationFailed
        }
        pixelBufferPool = pool
    }

    private static func makePixelBufferPool(size: Int) -> CVPixelBufferPool? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size,
            kCVPixelBufferHeightKey as String: size,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
        return pool
    }

    /// `MLModel.prediction(from:)` is synchronous/blocking — callers run embedders off the main actor.
    func embedding(for face: CGImage) throws -> [Float] {
        guard face.width == Self.inputSize, face.height == Self.inputSize else {
            throw ArcFaceEmbedderError.unexpectedInputSize(got: (face.width, face.height), expected: Self.inputSize)
        }

        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            throw ArcFaceEmbedderError.pixelBufferCreationFailed
        }
        try Self.render(face, into: pixelBuffer)

        let input = try MLDictionaryFeatureProvider(dictionary: [Self.inputName: MLFeatureValue(pixelBuffer: pixelBuffer)])
        let output = try model.prediction(from: input)

        guard let multiArray = output.featureValue(for: Self.outputName)?.multiArrayValue else {
            throw ArcFaceEmbedderError.unexpectedOutput("no '\(Self.outputName)' output found")
        }
        guard multiArray.count == embeddingDimension else {
            throw ArcFaceEmbedderError.unexpectedOutput("expected \(embeddingDimension) floats, got \(multiArray.count)")
        }

        let raw = Self.floatVector(from: multiArray)
        return FaceEmbedding.l2Normalized(raw)
    }

    private static func render(_ image: CGImage, into pixelBuffer: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw ArcFaceEmbedderError.pixelBufferCreationFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    /// `MLMultiArray` storage isn't guaranteed to be a flat, stride-1 buffer, so this indexes via the array's own subscript.
    private static func floatVector(from array: MLMultiArray) -> [Float] {
        var result = [Float](repeating: 0, count: array.count)
        for i in 0..<array.count {
            result[i] = array[i].floatValue
        }
        return result
    }
}

/// Zenith fork: finds the bundled `ArcFace.mlpackage`, compiles it into
/// Application Support on first use (cached by content hash) and loads the
/// compiled model. A precompiled `.mlmodelc` in the bundle, as Glance ships
/// it, is used as is.
enum ArcFaceModelLoader {
    private static let resourceSubdirectory = "FaceUnlock"

    static func loadModel() async throws -> MLModel {
        let compiledURL = try await compiledModelURL()
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        do {
            return try await MLModel.load(contentsOf: compiledURL, configuration: configuration)
        } catch {
            throw ArcFaceEmbedderError.modelLoadFailed(error.localizedDescription)
        }
    }

    private static func compiledModelURL() async throws -> URL {
        let bundle = Bundle.main
        // Both names are checked in case the model was added under a different name (Glance's lookup).
        for name in [FaceModelCache.modelName, "w600k_mbf"] {
            if let url = bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: resourceSubdirectory)
                ?? bundle.url(forResource: name, withExtension: "mlmodelc") {
                return url
            }
        }
        guard let packageURL = bundle.url(
            forResource: FaceModelCache.modelName, withExtension: "mlpackage", subdirectory: resourceSubdirectory
        ) else {
            throw ArcFaceEmbedderError.modelNotFound
        }
        guard let container = PrivateFileStore.containerURL else {
            throw ArcFaceEmbedderError.modelCompileFailed("no Application Support container outside an app bundle")
        }
        let directory = container
            .appendingPathComponent("FaceUnlock", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)

        let hash: String
        do {
            hash = try await Task.detached(priority: .userInitiated) {
                try FaceModelCache.contentHash(ofPackageAt: packageURL)
            }.value
        } catch {
            throw ArcFaceEmbedderError.modelCompileFailed("couldn't read the bundled package: \(error.localizedDescription)")
        }
        let cachedURL = FaceModelCache.compiledModelURL(in: directory, hash: hash)
        if FileManager.default.fileExists(atPath: cachedURL.appendingPathComponent("coremldata.bin").path) {
            return cachedURL
        }

        let temporaryURL: URL
        do {
            temporaryURL = try await MLModel.compileModel(at: packageURL)
        } catch {
            throw ArcFaceEmbedderError.modelCompileFailed(error.localizedDescription)
        }
        guard PrivateFileStore.createDirectory(at: directory) else {
            // Still usable this launch from the temporary location; it compiles again next time.
            return temporaryURL
        }
        let manager = FileManager.default
        try? manager.removeItem(at: cachedURL)
        do {
            try manager.moveItem(at: temporaryURL, to: cachedURL)
        } catch {
            return temporaryURL
        }
        for stale in FaceModelCache.staleModels(in: directory, keeping: cachedURL) {
            try? manager.removeItem(at: stale)
        }
        return cachedURL
    }
}
