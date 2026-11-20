// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

// Zenith fork: the photo actions' encode path, Image I/O and Core Image only.
// It reuses the Media converter's pieces (the orientation-aware decoder in
// `MediaImageProcessing`, the render-size guard, staging an output and
// installing it without replacing anything) but not its renderer: that one
// draws into a device-RGB bitmap, which would turn a Display P3 photo into
// sRGB numbers without converting them. Here the decoded image keeps its own
// colour space and Image I/O embeds that profile in the output; only a space a
// format cannot carry (CMYK, Lab, an untagged or extended-range one) is
// converted, to sRGB or Display P3, before writing.
//
// The test executable compiles this file; the Vision request that finds a
// subject lives with the service, outside the tests.

enum NotchPhotoError: Error, Equatable {
    case unreadable
    case tooLarge
    case unsupportedFormat
    case writeFailed
    case noSubject
    case cancelled
}

/// One written file.
struct NotchPhotoOutput: Equatable {
    let input: URL
    let url: URL
    let inputBytes: Int64
    let outputBytes: Int64
    let pixelSize: CGSize
}

/// Asked from the main thread, read between steps on the work queue.
final class NotchPhotoCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }

    func check() throws {
        if isCancelled { throw NotchPhotoError.cancelled }
    }
}

enum NotchPhotoEncoder {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The types Image I/O can write on this Mac (WebP is read-only on some
    /// macOS versions).
    static var writableTypes: [String] {
        CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    }

    // MARK: Transform

    /// Converts, resizes, compresses, strips or watermarks one picture into
    /// `directory`, in one pass: decode at the output's size, draw the
    /// watermark at that full resolution, encode. `logo` is the watermark's
    /// logo already read (a batch reads it once); nil reads the style's own.
    /// `stage` reports this file's own progress, 0 to 1.
    static func transform(_ input: URL, recipe: NotchPhotoRecipe, directory: URL,
                          reserved: inout Set<String>, writable: [String] = writableTypes,
                          logo: NotchWatermarkLogo? = nil,
                          cancellation: NotchPhotoCancellation? = nil,
                          fileManager: FileManager = .default,
                          stage: (Double) -> Void = { _ in }) throws -> NotchPhotoOutput {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { throw NotchPhotoError.unreadable }
        let index = CGImageSourceGetPrimaryImageIndex(source)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let sourceSize = MediaSupport.imageDisplaySize(properties: properties)
        else { throw NotchPhotoError.unreadable }
        let sourceFormat = NotchPhotoFormat(typeIdentifier: CGImageSourceGetType(source) as String?)
        let format = recipe.outputFormat(source: sourceFormat, writable: writable)
        guard writable.contains(format.typeIdentifier) else { throw NotchPhotoError.unsupportedFormat }
        try cancellation?.check()
        stage(0.1)

        let name = NotchPhotoActionsSupport.outputName(for: input, suffix: recipe.nameSuffix, format: format)
        let output = NotchPhotoActionsSupport.uniqueOutputURL(
            in: directory, baseName: name.base, fileExtension: name.ext, reserved: reserved,
            exists: { fileManager.fileExists(atPath: $0.path) })
        reserved.insert(output.standardizedFileURL.path)
        let staged = try MediaSupport.temporaryOutputURL(for: output, fileManager: fileManager)
        defer { MediaSupport.discardStagedOutput(staged, fileManager: fileManager) }

        // A strip that keeps format and size copies the encoded image as it is
        // and only leaves the metadata behind: no generation loss.
        let lossless = recipe.kind == .strip && recipe.watermark == nil && format == sourceFormat
            && CGImageSourceGetCount(source) == 1
            && copyWithoutMetadata(source, properties: properties, format: format, to: staged)
        var pixelSize = sourceSize
        if !lossless {
            let target = NotchPhotoActionsSupport.targetSize(source: sourceSize, longEdge: recipe.outputLongEdge)
            guard MediaSupport.imageRenderSizeIsSafe(target) else { throw NotchPhotoError.tooLarge }
            guard let decoded = MediaImageProcessing.decode(
                source, at: index,
                maximumDimension: NotchPhotoActionsSupport.decodeMaxPixel(source: sourceSize,
                                                                          longEdge: recipe.outputLongEdge))
            else { throw NotchPhotoError.unreadable }
            try cancellation?.check()
            stage(0.5)
            var image = prepared(decoded, for: format)
            // The watermark, after the resize and before the encode.
            if let style = recipe.watermark {
                guard let marked = NotchWatermarkRenderer.watermarked(
                    image, style: style, logo: logo ?? NotchWatermarkLogo.load(style.logoFile))
                else { throw NotchPhotoError.writeFailed }
                image = marked
                try cancellation?.check()
                stage(0.7)
            }
            pixelSize = CGSize(width: image.width, height: image.height)
            let metadata = recipe.stripsMetadata ? [:] : carriedProperties(properties)
            try write(image, format: format, quality: recipe.lossyQuality, properties: metadata, to: staged)
        }
        try cancellation?.check()
        stage(0.9)
        try install(staged, at: output)
        return NotchPhotoOutput(input: input, url: output, inputBytes: fileSize(input), outputBytes: fileSize(output),
                                pixelSize: pixelSize)
    }

    // MARK: Cutout

    /// The subject over transparency: `image` where `mask` is white, nothing
    /// where it is black, at the image's own size and in its colour space.
    static func cutout(_ image: CGImage, mask: CIImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let extent = input.extent
        guard !extent.isEmpty, !mask.extent.isEmpty, !mask.extent.isInfinite else { return nil }
        let fitted = mask.transformed(by: CGAffineTransform(scaleX: extent.width / mask.extent.width,
                                                            y: extent.height / mask.extent.height))
        let filter = CIFilter.blendWithMask()
        filter.inputImage = input
        filter.backgroundImage = CIImage.empty()
        filter.maskImage = fitted
        guard let composed = filter.outputImage else { return nil }
        let space = rgbSpace(for: image.colorSpace)
        return context.createCGImage(composed, from: extent, format: .RGBA8, colorSpace: space)
    }

    /// Writes a cutout as a PNG beside its original: `photo-cutout.png`.
    static func writeCutout(_ image: CGImage, for input: URL, directory: URL, reserved: inout Set<String>,
                            fileManager: FileManager = .default) throws -> NotchPhotoOutput {
        let name = NotchPhotoActionsSupport.outputName(for: input, suffix: NotchPhotoActionsSupport.cutoutSuffix,
                                                      format: .png)
        let output = NotchPhotoActionsSupport.uniqueOutputURL(
            in: directory, baseName: name.base, fileExtension: name.ext, reserved: reserved,
            exists: { fileManager.fileExists(atPath: $0.path) })
        reserved.insert(output.standardizedFileURL.path)
        let staged = try MediaSupport.temporaryOutputURL(for: output, fileManager: fileManager)
        defer { MediaSupport.discardStagedOutput(staged, fileManager: fileManager) }
        try write(image, format: .png, quality: 1, properties: [:], to: staged)
        try install(staged, at: output)
        return NotchPhotoOutput(input: input, url: output, inputBytes: fileSize(input), outputBytes: fileSize(output),
                                pixelSize: CGSize(width: image.width, height: image.height))
    }

    /// The upright picture at up to `maximumDimension` on its long edge, for
    /// the subject request and for previews.
    static func uprightImage(at url: URL, maximumDimension: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let index = CGImageSourceGetPrimaryImageIndex(source)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let size = MediaSupport.imageDisplaySize(properties: properties),
              MediaSupport.imageRenderSizeIsSafe(size) else { return nil }
        let limit = min(maximumDimension, Int(max(size.width, size.height)))
        return MediaImageProcessing.decode(source, at: index, maximumDimension: max(1, limit))
    }

    // MARK: Colour

    /// The space the output is written in: nil keeps the image's own (sRGB,
    /// Display P3, Adobe RGB or any other tagged RGB or grey profile). An
    /// extended-range or HDR space becomes Display P3, so the wide colours
    /// survive in an 8-bit file; CMYK, Lab, indexed and untagged images
    /// become sRGB.
    static func outputColorSpace(for space: CGColorSpace?) -> CGColorSpace? {
        guard let space else { return CGColorSpace(name: CGColorSpace.sRGB) }
        if CGColorSpaceUsesExtendedRange(space) || CGColorSpaceUsesITUR_2100TF(space) {
            return CGColorSpace(name: CGColorSpace.displayP3)
        }
        switch space.model {
        case .rgb, .monochrome:
            return space.copyICCData() == nil ? CGColorSpace(name: CGColorSpace.sRGB) : nil
        default:
            return CGColorSpace(name: CGColorSpace.sRGB)
        }
    }

    private static func rgbSpace(for space: CGColorSpace?) -> CGColorSpace {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let space else { return srgb }
        if let converted = outputColorSpace(for: space) { return converted.model == .rgb ? converted : srgb }
        return space.model == .rgb ? space : srgb
    }

    static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    /// The image the format can carry: in a space it embeds, and on white
    /// when the format has no alpha. Untouched when it already fits.
    static func prepared(_ image: CGImage, for format: NotchPhotoFormat) -> CGImage {
        let converted = outputColorSpace(for: image.colorSpace)
        let flattens = !format.keepsAlpha && hasAlpha(image)
        guard converted != nil || flattens else { return image }
        var space = converted ?? image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        // A grey bitmap context has no alpha: a grey picture that must keep
        // its transparency is drawn in sRGB instead.
        if space.model == .monochrome, !flattens, hasAlpha(image) { space = CGColorSpace(name: CGColorSpace.sRGB)! }
        guard space.model == .rgb || space.model == .monochrome else { return image }
        let alpha: CGImageAlphaInfo = space.model == .monochrome ? .none : flattens ? .noneSkipLast : .premultipliedLast
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue) else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        if flattens {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(rect)
        }
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        return context.makeImage() ?? image
    }

    // MARK: Metadata

    /// The source's descriptive metadata for an output that keeps it: EXIF,
    /// GPS, IPTC, the TIFF fields and the resolution. The orientation and
    /// pixel dimensions are left out, since the pixels are already upright
    /// and may have a new size.
    static func carriedProperties(_ properties: [CFString: Any]) -> [CFString: Any] {
        var carried: [CFString: Any] = [:]
        for key in [kCGImagePropertyExifDictionary, kCGImagePropertyExifAuxDictionary,
                    kCGImagePropertyGPSDictionary, kCGImagePropertyIPTCDictionary,
                    kCGImagePropertyTIFFDictionary] {
            guard var dictionary = properties[key] as? [CFString: Any] else { continue }
            dictionary.removeValue(forKey: kCGImagePropertyTIFFOrientation)
            dictionary.removeValue(forKey: kCGImagePropertyExifPixelXDimension)
            dictionary.removeValue(forKey: kCGImagePropertyExifPixelYDimension)
            if !dictionary.isEmpty { carried[key] = dictionary }
        }
        for key in [kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight] {
            if let value = properties[key] { carried[key] = value }
        }
        return carried
    }

    /// Copies the encoded image with no metadata but its orientation (the
    /// pixels are stored as the camera took them). False when Image I/O
    /// cannot copy this kind of file, and the caller re-encodes instead.
    private static func copyWithoutMetadata(_ source: CGImageSource, properties: [CFString: Any],
                                            format: NotchPhotoFormat, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.typeIdentifier as CFString, 1, nil)
        else { return false }
        let metadata = CGImageMetadataCreateMutable()
        if let orientation = properties[kCGImagePropertyOrientation] as? NSNumber, orientation.intValue != 1 {
            _ = CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary,
                                                             kCGImagePropertyTIFFOrientation, orientation)
        }
        let options = [
            kCGImageDestinationMetadata: metadata,
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageMetadataShouldExcludeXMP: true,
        ] as CFDictionary
        return CGImageDestinationCopyImageSource(destination, source, options, nil)
    }

    // MARK: Writing

    static func write(_ image: CGImage, format: NotchPhotoFormat, quality: Double,
                      properties: [CFString: Any], to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.typeIdentifier as CFString, 1, nil)
        else { throw NotchPhotoError.unsupportedFormat }
        var options = properties
        options[kCGImagePropertyOrientation] = 1
        if format.isLossy { options[kCGImageDestinationLossyCompressionQuality] = MediaSupport.sanitizedQuality(quality) }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw NotchPhotoError.writeFailed }
    }

    /// Moves the staged file into place; never over an existing item.
    private static func install(_ staged: URL, at output: URL) throws {
        do { try MediaSupport.installStagedOutput(staged, at: output, replacingExisting: false) }
        catch { throw NotchPhotoError.writeFailed }
        MediaSupport.makeVisibleIfNeeded(output)
    }

    static func fileSize(_ url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
}
