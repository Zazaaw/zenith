// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

// Zenith fork: photo actions in the island. Drop images on Transform to
// convert, resize, compress or strip them, or one image on Remove Background
// for a transparent PNG of its subject. This file is the pure part (which
// targets a drag gets, what an option writes and under which name, the size
// arithmetic and the readings); the test executable compiles it.

/// What a drop on a photo target asks for.
enum NotchPhotoAction: String, Equatable {
    case transform
    case removeBackground

    init?(target: NotchDropTarget) {
        switch target {
        case .transform: self = .transform
        case .removeBackground: self = .removeBackground
        case .files, .airDrop, .media, .overlay: return nil
        }
    }

    var target: NotchDropTarget {
        switch self {
        case .transform: return .transform
        case .removeBackground: return .removeBackground
        }
    }
}

/// Transform's steps; one is chosen at a time. Watermark can also ride along
/// with the others (`NotchPhotoRecipe.watermark`).
enum NotchPhotoTransformKind: String, CaseIterable, Identifiable {
    case convert, resize, compress, strip, watermark
    var id: String { rawValue }
}

/// The formats Zenith writes. TIFF only passes through: a resized or stripped
/// TIFF stays one, but Convert never offers it.
enum NotchPhotoFormat: String, CaseIterable, Identifiable {
    case jpeg, png, webp, heic, tiff
    var id: String { rawValue }

    var typeIdentifier: String {
        switch self {
        case .jpeg: return UTType.jpeg.identifier
        case .png: return UTType.png.identifier
        case .webp: return UTType.webP.identifier
        case .heic: return UTType.heic.identifier
        case .tiff: return UTType.tiff.identifier
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .webp: return "webp"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }

    /// The chip's words; format names read the same in every language.
    var title: String {
        switch self {
        case .jpeg: return "JPG"
        case .png: return "PNG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        }
    }

    var isLossy: Bool { self == .jpeg || self == .webp || self == .heic }
    /// JPEG has no alpha: a transparent picture is laid on white first.
    var keepsAlpha: Bool { self != .jpeg }

    init?(typeIdentifier: String?) {
        guard let typeIdentifier else { return nil }
        guard let match = Self.allCases.first(where: { $0.typeIdentifier == typeIdentifier }) else { return nil }
        self = match
    }

    /// Convert's chips on this Mac: JPG and PNG, WebP where Image I/O can
    /// write it, and HEIC. Where WebP cannot be written HEIC stands in its
    /// place, so the row never offers a format that would fail.
    static func offered(writable: [String]) -> [NotchPhotoFormat] {
        [.jpeg, .png, .webp, .heic].filter { writable.contains($0.typeIdentifier) }
    }
}

/// Resize's long edge. Nothing is ever made larger than it is.
enum NotchPhotoLongEdge: Int, CaseIterable, Identifiable {
    case hd = 1080
    case large = 2048
    case ultra = 4096
    case original = 0
    var id: Int { rawValue }
    var pixels: Int? { self == .original ? nil : rawValue }
}

/// Compress's JPEG quality presets.
enum NotchPhotoQuality: Int, CaseIterable, Identifiable {
    case small = 60
    case balanced = 80
    case high = 90
    var id: Int { rawValue }
    var value: Double { Double(rawValue) / 100 }
}

/// One Transform request: the chosen step and the options the surface holds.
struct NotchPhotoRecipe: Equatable {
    var kind: NotchPhotoTransformKind
    var format: NotchPhotoFormat = .jpeg
    var longEdge: NotchPhotoLongEdge = .large
    var quality: NotchPhotoQuality = .balanced
    /// The "strip EXIF" chip beside Convert, Resize and Compress.
    var alsoStrips = false
    /// The watermark drawn after any resize and before encoding: always for
    /// the Watermark step, and for the others when its chip is on.
    var watermark: NotchWatermarkStyle?

    /// Convert writes the chosen format; Compress always writes JPEG, since its
    /// presets are JPEG qualities; Resize and Strip keep the source's format
    /// where Zenith can write it, and fall back to JPEG (a RAW or WebP source).
    func outputFormat(source: NotchPhotoFormat?, writable: [String]) -> NotchPhotoFormat {
        switch kind {
        case .convert:
            return format
        case .compress:
            return .jpeg
        case .resize, .strip, .watermark:
            if let source, writable.contains(source.typeIdentifier) { return source }
            return .jpeg
        }
    }

    /// The long edge the output is held to, nil for the source's own size.
    var outputLongEdge: Int? { kind == .resize ? longEdge.pixels : nil }

    /// Whether camera, lens, GPS and other EXIF details are left behind.
    var stripsMetadata: Bool { kind == .strip || alsoStrips }

    /// The encoder's quality for a lossy format: the preset for Compress, a
    /// faithful 0.9 for Convert and Resize, and 0.92 for a Strip that has to
    /// re-encode (most strips copy the image data untouched).
    var lossyQuality: Double {
        switch kind {
        case .compress: return quality.value
        case .convert, .resize: return 0.9
        case .strip, .watermark: return 0.92
        }
    }

    /// What the output's name says about it: nothing for a conversion (its
    /// extension says it), the long edge for a resize, the quality for a
    /// compression, `clean` for a strip; then `-wm` for a watermark.
    var nameSuffix: String {
        let step: String
        switch kind {
        case .convert, .watermark: step = ""
        case .resize: step = longEdge.pixels.map { "-\($0)" } ?? ""
        case .compress: step = "-q\(quality.rawValue)"
        case .strip: step = "-clean"
        }
        return watermark == nil ? step : step + NotchWatermarkSupport.nameSuffix
    }
}

enum NotchPhotoActionsSupport {
    /// Whether the photo targets appear. Unset reads as on.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.notchPhotoActionsEnabled) as? Bool ?? true
    }

    /// A drag of more files than this is left to the shelf.
    static let maximumItems = 100

    /// The cutout's name ends with this, always a PNG.
    static let cutoutSuffix = "-cutout"

    /// Pictures Zenith can read and act on: photographs and the usual editing
    /// formats, camera RAW and Photoshop documents included. Animated and
    /// vector formats (GIF, SVG, PDF) and icons stay with the shelf.
    static func acceptsImage(_ type: UTType?) -> Bool {
        guard let type else { return false }
        var accepted: [UTType] = [.jpeg, .png, .tiff, .heic, .heif, .webP, .bmp, .rawImage]
        if let photoshop = UTType("com.adobe.photoshop-image") { accepted.append(photoshop) }
        if let avif = UTType("public.avif") { accepted.append(avif) }
        return accepted.contains { type.conforms(to: $0) }
    }

    /// The photo targets for a drag: none unless every item is an image;
    /// Remove Background only for a single image, Transform for any number.
    static func targets(imageCount: Int, allImages: Bool) -> [NotchDropTarget] {
        guard allImages, imageCount > 0, imageCount <= maximumItems else { return [] }
        return imageCount == 1 ? [.transform, .removeBackground] : [.transform]
    }

    /// The output's size: the source's held to `longEdge`, keeping its shape,
    /// never larger than the source.
    static func targetSize(source: CGSize, longEdge: Int?) -> CGSize {
        let width = max(1, source.width.rounded())
        let height = max(1, source.height.rounded())
        let long = max(width, height)
        guard let longEdge, longEdge > 0, CGFloat(longEdge) < long else {
            return CGSize(width: width, height: height)
        }
        let scale = CGFloat(longEdge) / long
        return CGSize(width: max(1, (width * scale).rounded()), height: max(1, (height * scale).rounded()))
    }

    /// The decoder's pixel budget for that size: its long edge.
    static func decodeMaxPixel(source: CGSize, longEdge: Int?) -> Int {
        let size = targetSize(source: source, longEdge: longEdge)
        return Int(max(size.width, size.height))
    }

    /// `photo.heic` with "-2048" and JPEG reads `photo-2048` / `jpg`.
    static func outputName(for input: URL, suffix: String, format: NotchPhotoFormat) -> (base: String, ext: String) {
        (MediaSupport.visibleOutputBaseName(for: input) + suffix, format.fileExtension)
    }

    /// A name in `directory` that is neither on disk nor reserved by another
    /// output of the same run: `photo.jpg`, then `photo-1.jpg`, `photo-2.jpg`.
    /// An original is never overwritten.
    static func uniqueOutputURL(in directory: URL, baseName: String, fileExtension: String,
                                reserved: Set<String> = [], exists: (URL) -> Bool) -> URL {
        let base = MediaSupport.sanitizedFileBaseName(baseName, fileExtension: fileExtension,
                                                      uniquenessSuffixByteReservation: 5)
        func candidate(_ index: Int) -> URL {
            directory.appendingPathComponent(index == 0 ? base : "\(base)-\(index)")
                .appendingPathExtension(fileExtension)
        }
        var index = 0
        while true {
            let url = candidate(index)
            if !reserved.contains(url.standardizedFileURL.path), !exists(url) { return url }
            index += 1
        }
    }

    /// Results land beside the original, the way Optimize media saves them;
    /// where that folder cannot be written (a read-only volume, a temporary
    /// folder a dragged promise came from) they go to `fallback`, Downloads.
    static func outputDirectory(for input: URL, isWritable: (URL) -> Bool, temporaryRoots: [URL],
                                fallback: URL) -> URL {
        let folder = input.deletingLastPathComponent().standardizedFileURL
        let temporary = temporaryRoots.contains { root in
            let root = root.standardizedFileURL.path
            return folder.path == root || folder.path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
        return !temporary && isWritable(folder) ? folder : fallback
    }

    /// A file size in mono: decimal units as Finder counts them, one decimal
    /// below ten, a dot whatever the language (it reads as a figure).
    static func formatBytes(_ bytes: Int64) -> String {
        let value = Double(max(0, bytes))
        let units = ["B", "KB", "MB", "GB", "TB"]
        var scaled = value
        var unit = 0
        while scaled >= 1000, unit < units.count - 1 {
            scaled /= 1000
            unit += 1
        }
        if unit == 0 { return "\(Int(scaled)) B" }
        // 999.95 KB would print as "1000.0": carry it into the next unit.
        if scaled >= 999.5, unit < units.count - 1 {
            scaled /= 1000
            unit += 1
        }
        let text = scaled < 10 ? String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), scaled)
            : String(Int(scaled.rounded()))
        return "\(text) \(units[unit])"
    }

    /// How much the size moved, as a signed whole percent: "−74%", "+12%",
    /// "0%". The minus is a real minus sign.
    static func sizeChange(from before: Int64, to after: Int64) -> String {
        guard before > 0 else { return "" }
        let change = (Double(after) - Double(before)) / Double(before) * 100
        let rounded = Int(change.rounded())
        if rounded == 0 { return "0%" }
        return rounded < 0 ? "\u{2212}\(-rounded)%" : "+\(rounded)%"
    }

    /// The run's progress from the files finished and the current file's own
    /// stage (0 to 1), so a single photo moves too.
    static func progress(completed: Int, total: Int, stage: Double) -> Double {
        guard total > 0 else { return 0 }
        let stage = stage.isFinite ? min(1, max(0, stage)) : 0
        return min(1, max(0, (Double(completed) + stage) / Double(total)))
    }
}
