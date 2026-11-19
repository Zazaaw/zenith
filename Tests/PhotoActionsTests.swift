// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: the island's photo actions. Pure logic, then the encode path
/// end to end on small generated pictures in a temporary folder. Vision's
/// subject request is not run here (its answer depends on the model); the
/// cutout's composition is tested with a mask drawn by hand.
enum PhotoActionsTests {
    private typealias Support = NotchPhotoActionsSupport

    static func run(_ suite: TestSuite) {
        targets(suite)
        formats(suite)
        recipes(suite)
        sizes(suite)
        naming(suite)
        readings(suite)
        colour(suite)
        encoding(suite)
        cutout(suite)
        strings(suite)
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let values = Mirror(reflecting: ZenithStrings.photoActions(language)).children.compactMap { $0.value as? String }
            suite.expect(values.count == 29 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") },
                         "\(language.rawValue) words every photo action, with curly apostrophes")
        }
    }

    // MARK: Targets

    private static func targets(_ suite: TestSuite) {
        suite.expect(Support.targets(imageCount: 1, allImages: true) == [.transform, .removeBackground],
                     "a single image offers Transform and Remove Background")
        suite.expect(Support.targets(imageCount: 3, allImages: true) == [.transform],
                     "several images offer Transform only")
        suite.expect(Support.targets(imageCount: 2, allImages: false).isEmpty,
                     "a drag with anything but images gets no photo target")
        suite.expect(Support.targets(imageCount: 0, allImages: true).isEmpty, "no images, no targets")
        suite.expect(Support.targets(imageCount: Support.maximumItems + 1, allImages: true).isEmpty,
                     "a very large drag is left to the shelf")
        suite.expect(NotchAirDropSupport.targets(files: true, airDrop: true, media: true,
                                                 photo: [.transform, .removeBackground])
                        == [.files, .airDrop, .media, .transform, .removeBackground],
                     "photo targets follow the existing ones, left to right")
        suite.expect(NotchAirDropSupport.targets(files: true, airDrop: false, media: false, photo: [.airDrop, .transform])
                        == [.files, .transform], "only photo actions pass as photo targets")
        suite.expect(NotchAirDropSupport.targets(files: true, airDrop: true, media: false)
                        == [.files, .airDrop], "a drag without images keeps the targets it had")
        suite.expect(NotchPhotoAction(target: .transform) == .transform
                        && NotchPhotoAction(target: .removeBackground) == .removeBackground
                        && NotchPhotoAction(target: .files) == nil && NotchPhotoAction(target: .media) == nil,
                     "only the photo targets map to photo actions")
        suite.expect(NotchDropTarget.removeBackground.isPhotoAction && !NotchDropTarget.airDrop.isPhotoAction,
                     "the photo targets know themselves")

        for type in [UTType.jpeg, .png, .tiff, .heic, .webP, .rawImage] {
            suite.expect(Support.acceptsImage(type), "\(type.identifier) is a picture Zenith acts on")
        }
        if let nef = UTType(filenameExtension: "nef") {
            suite.expect(Support.acceptsImage(nef), "a camera RAW file conforms and is accepted")
        }
        for type in [UTType.gif, .svg, .pdf, .movie, .plainText, .folder, .icns] {
            suite.expect(!Support.acceptsImage(type), "\(type.identifier) stays with the shelf")
        }
        suite.expect(!Support.acceptsImage(nil), "an unknown type is not an image")
    }

    // MARK: Formats and recipes

    private static func formats(_ suite: TestSuite) {
        let withWebP = ["public.jpeg", "public.png", "org.webmproject.webp", "public.heic"]
        let withoutWebP = ["public.jpeg", "public.png", "public.heic", "public.tiff"]
        suite.expect(NotchPhotoFormat.offered(writable: withWebP) == [.jpeg, .png, .webp, .heic],
                     "WebP is offered where Image I/O writes it")
        suite.expect(NotchPhotoFormat.offered(writable: withoutWebP) == [.jpeg, .png, .heic],
                     "without WebP, HEIC is the third choice and TIFF is never offered")
        suite.expect(NotchPhotoFormat.offered(writable: NotchPhotoEncoder.writableTypes).contains(.jpeg)
                        && NotchPhotoFormat.offered(writable: NotchPhotoEncoder.writableTypes).contains(.png),
                     "this Mac writes JPEG and PNG")
        suite.expect(NotchPhotoFormat(typeIdentifier: "public.heic") == .heic
                        && NotchPhotoFormat(typeIdentifier: "public.camera-raw-image") == nil
                        && NotchPhotoFormat(typeIdentifier: nil) == nil, "source types map to writable formats")
        suite.expect(NotchPhotoFormat.allCases.map(\.fileExtension) == ["jpg", "png", "webp", "heic", "tiff"],
                     "each format has its extension")
        suite.expect(!NotchPhotoFormat.jpeg.keepsAlpha && NotchPhotoFormat.png.keepsAlpha && NotchPhotoFormat.heic.isLossy
                        && !NotchPhotoFormat.png.isLossy, "JPEG drops alpha; PNG is lossless")
    }

    private static func recipes(_ suite: TestSuite) {
        let writable = ["public.jpeg", "public.png", "public.heic", "public.tiff"]
        let convert = NotchPhotoRecipe(kind: .convert, format: .png)
        suite.expect(convert.outputFormat(source: .heic, writable: writable) == .png, "Convert writes the chosen format")
        suite.expect(convert.nameSuffix == "" && !convert.stripsMetadata && convert.lossyQuality == 0.9,
                     "a conversion keeps the name and the metadata")
        let compress = NotchPhotoRecipe(kind: .compress, quality: .small)
        suite.expect(compress.outputFormat(source: .png, writable: writable) == .jpeg, "Compress always writes JPEG")
        suite.expect(compress.nameSuffix == "-q60" && compress.lossyQuality == 0.6, "Compress names its quality")
        suite.expect(NotchPhotoQuality.allCases.map(\.rawValue) == [60, 80, 90], "three quality presets")
        let resize = NotchPhotoRecipe(kind: .resize, longEdge: .large)
        suite.expect(resize.outputFormat(source: .heic, writable: writable) == .heic, "Resize keeps the source format")
        suite.expect(resize.outputFormat(source: .webp, writable: writable) == .jpeg,
                     "Resize writes JPEG where the source format cannot be written")
        suite.expect(resize.outputFormat(source: nil, writable: writable) == .jpeg, "a RAW source resizes to JPEG")
        suite.expect(resize.nameSuffix == "-2048" && resize.outputLongEdge == 2048, "Resize names its long edge")
        let original = NotchPhotoRecipe(kind: .resize, longEdge: .original)
        suite.expect(original.nameSuffix == "" && original.outputLongEdge == nil, "Original keeps the size")
        suite.expect(NotchPhotoRecipe(kind: .convert, longEdge: .hd).outputLongEdge == nil,
                     "only Resize changes the size")
        let strip = NotchPhotoRecipe(kind: .strip)
        suite.expect(strip.stripsMetadata && strip.nameSuffix == "-clean"
                        && strip.outputFormat(source: .tiff, writable: writable) == .tiff,
                     "Strip keeps format and size, marks the name")
        var stripped = NotchPhotoRecipe(kind: .resize)
        stripped.alsoStrips = true
        suite.expect(stripped.stripsMetadata, "the strip chip strips beside another step")
    }

    // MARK: Sizes

    private static func sizes(_ suite: TestSuite) {
        suite.expect(Support.targetSize(source: CGSize(width: 6000, height: 4000), longEdge: 2048)
                        == CGSize(width: 2048, height: 1365), "landscape held to its long edge")
        suite.expect(Support.targetSize(source: CGSize(width: 3024, height: 4032), longEdge: 1080)
                        == CGSize(width: 810, height: 1080), "portrait held to its long edge")
        suite.expect(Support.targetSize(source: CGSize(width: 800, height: 600), longEdge: 4096)
                        == CGSize(width: 800, height: 600), "never made larger")
        suite.expect(Support.targetSize(source: CGSize(width: 5000, height: 5000), longEdge: nil)
                        == CGSize(width: 5000, height: 5000), "Original keeps every pixel")
        suite.expect(Support.targetSize(source: CGSize(width: 10000, height: 3), longEdge: 1080)
                        == CGSize(width: 1080, height: 1), "a sliver keeps at least one pixel")
        suite.expect(Support.decodeMaxPixel(source: CGSize(width: 3024, height: 4032), longEdge: 2048) == 2048
                        && Support.decodeMaxPixel(source: CGSize(width: 640, height: 480), longEdge: 2048) == 640,
                     "the decoder reads only the pixels the output needs")
    }

    // MARK: Naming

    private static func naming(_ suite: TestSuite) {
        let folder = URL(fileURLWithPath: "/Photos", isDirectory: true)
        let input = folder.appendingPathComponent("photo.heic")
        let name = Support.outputName(for: input, suffix: "", format: .jpeg)
        suite.expect(name.base == "photo" && name.ext == "jpg", "a conversion swaps the extension")
        suite.expect(Support.outputName(for: input, suffix: "-2048", format: .heic).base == "photo-2048",
                     "a suffix follows the name")
        suite.expect(Support.outputName(for: folder.appendingPathComponent(".hidden.png"), suffix: "", format: .png).base
                        == "hidden", "an output is never hidden")

        func unique(_ existing: Set<String>, reserved: Set<String> = [], base: String = "photo") -> String {
            Support.uniqueOutputURL(in: folder, baseName: base, fileExtension: "jpg", reserved: reserved,
                                    exists: { existing.contains($0.lastPathComponent) }).lastPathComponent
        }
        suite.expect(unique([]) == "photo.jpg", "a free name is used as it is")
        suite.expect(unique(["photo.jpg"]) == "photo-1.jpg", "an existing file is never overwritten")
        suite.expect(unique(["photo.jpg", "photo-1.jpg", "photo-2.jpg"]) == "photo-3.jpg", "the next free number")
        suite.expect(unique([], reserved: ["/Photos/photo.jpg"]) == "photo-1.jpg",
                     "two outputs of one run never share a name")
        suite.expect(unique([], base: "a/b:c") == "a-b-c.jpg", "a name is made safe for the file system")
        let long = String(repeating: "x", count: 400)
        let taken = unique([], base: long)
        suite.expect(taken.utf8.count <= 255 && unique([taken], base: long).utf8.count <= 255
                        && unique([taken], base: long).hasSuffix("-1.jpg"), "a long name leaves room for its number")

        let downloads = URL(fileURLWithPath: "/Users/me/Downloads", isDirectory: true)
        let temp = URL(fileURLWithPath: "/private/var/folders/xy/T", isDirectory: true)
        suite.expect(Support.outputDirectory(for: input, isWritable: { _ in true }, temporaryRoots: [temp],
                                             fallback: downloads).path == "/Photos",
                     "results land beside the original")
        suite.expect(Support.outputDirectory(for: input, isWritable: { _ in false }, temporaryRoots: [temp],
                                             fallback: downloads) == downloads,
                     "a folder that cannot be written sends results to Downloads")
        suite.expect(Support.outputDirectory(for: temp.appendingPathComponent("drop/photo.png"), isWritable: { _ in true },
                                             temporaryRoots: [temp], fallback: downloads) == downloads,
                     "a temporary folder is not a place to leave results")
        suite.expect(Support.outputDirectory(for: URL(fileURLWithPath: "/private/var/folders/xy/Trip/photo.png"),
                                             isWritable: { _ in true }, temporaryRoots: [temp],
                                             fallback: downloads).path == "/private/var/folders/xy/Trip",
                     "a folder that only starts like the temporary one is kept")
    }

    // MARK: Readings

    private static func readings(_ suite: TestSuite) {
        let cases: [(Int64, String)] = [(0, "0 B"), (999, "999 B"), (1_000, "1.0 KB"), (4_230_000, "4.2 MB"),
                                        (12_400_000, "12 MB"), (999_960, "1.0 MB"), (850_000, "850 KB"),
                                        (2_500_000_000, "2.5 GB"), (-5, "0 B")]
        for (bytes, expected) in cases {
            suite.expect(Support.formatBytes(bytes) == expected,
                         "\(bytes) bytes read \(expected), got \(Support.formatBytes(bytes))")
        }
        suite.expect(Support.sizeChange(from: 4_000_000, to: 1_000_000) == "\u{2212}75%", "smaller reads as a minus")
        suite.expect(Support.sizeChange(from: 1_000_000, to: 1_120_000) == "+12%", "larger reads as a plus")
        suite.expect(Support.sizeChange(from: 1_000_000, to: 1_001_000) == "0%", "no change reads as zero")
        suite.expect(Support.sizeChange(from: 0, to: 10).isEmpty, "nothing to compare against")
        suite.expect(Support.progress(completed: 0, total: 1, stage: 0.5) == 0.5, "a single file moves with its stage")
        suite.expect(Support.progress(completed: 2, total: 4, stage: 0.5) == 0.625, "a batch counts finished files")
        suite.expect(Support.progress(completed: 4, total: 4, stage: 1) == 1
                        && Support.progress(completed: 0, total: 0, stage: 1) == 0
                        && Support.progress(completed: 0, total: 2, stage: .nan) == 0,
                     "progress stays between 0 and 1")
    }

    // MARK: Colour

    private static func colour(_ suite: TestSuite) {
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: p3) == nil, "Display P3 is kept")
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: srgb) == nil, "sRGB is kept")
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: CGColorSpace(name: CGColorSpace.adobeRGB1998)!) == nil,
                     "another tagged RGB profile is kept")
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: CGColorSpace(name: CGColorSpace.genericCMYK)!)?.name
                        == CGColorSpace.sRGB, "CMYK becomes sRGB")
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: CGColorSpaceCreateDeviceRGB())?.name == CGColorSpace.sRGB,
                     "an untagged picture is written as sRGB")
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!)?.name
                        == CGColorSpace.displayP3, "an extended-range picture keeps its gamut as Display P3")
        suite.expect(NotchPhotoEncoder.outputColorSpace(for: nil)?.name == CGColorSpace.sRGB, "no space reads as sRGB")

        let transparent = image(width: 4, height: 4, space: p3, alpha: true, color: [1, 0, 0, 0.5])
        let flat = NotchPhotoEncoder.prepared(transparent, for: .jpeg)
        suite.expect(!NotchPhotoEncoder.hasAlpha(flat) && flat.colorSpace?.name == CGColorSpace.displayP3,
                     "JPEG lays a transparent picture on white in its own space")
        suite.expect(NotchPhotoEncoder.prepared(transparent, for: .png) === transparent,
                     "PNG keeps a tagged transparent picture untouched")
    }

    // MARK: Encoding

    private static func encoding(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-photo-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!

        // A Display P3 JPEG stored sideways (orientation 6) with camera and GPS details.
        let source = folder.appendingPathComponent("photo.jpg")
        let picture = image(width: 400, height: 300, space: p3, alpha: false, color: [1, 0, 0, 1])
        let written = writeJPEG(picture, to: source, properties: [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "Zenith Test Lens"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 48.85, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 2.35, kCGImagePropertyGPSLongitudeRef: "E"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Zenith"],
        ])
        suite.expect(written, "the fixture is written")
        let original = try? Data(contentsOf: source)
        var reserved = Set<String>()

        // Convert to PNG: upright, same profile, metadata kept.
        let png = try? NotchPhotoEncoder.transform(source, recipe: NotchPhotoRecipe(kind: .convert, format: .png),
                                                   directory: folder, reserved: &reserved)
        suite.expect(png?.url.lastPathComponent == "photo.png", "Convert writes photo.png beside the original")
        if let url = png?.url {
            let info = read(url)
            suite.expect(info.type == UTType.png.identifier, "the output is a PNG")
            suite.expect(info.width == 300 && info.height == 400, "the sideways photo is written upright")
            suite.expect(info.orientation == 1, "an upright output says so")
            suite.expect(info.profile == "Display P3", "Display P3 survives a conversion, got \(info.profile ?? "none")")
            suite.expect(info.lens == "Zenith Test Lens", "a conversion keeps the EXIF details")
        }

        // Convert to JPEG again: the original is not overwritten.
        var stages: [Double] = []
        let jpeg = try? NotchPhotoEncoder.transform(source, recipe: NotchPhotoRecipe(kind: .convert, format: .jpeg),
                                                    directory: folder, reserved: &reserved, stage: { stages.append($0) })
        suite.expect(jpeg?.url.lastPathComponent == "photo-1.jpg", "a same-format conversion takes the next name")
        suite.expect((try? Data(contentsOf: source)) == original, "the original is never touched")
        suite.expect(!stages.isEmpty && stages == stages.sorted() && (stages.last ?? 0) < 1,
                     "a file reports its stages in order")

        // Resize and strip in one go.
        var recipe = NotchPhotoRecipe(kind: .resize, longEdge: .hd)
        recipe.alsoStrips = true
        let big = folder.appendingPathComponent("wide.jpg")
        _ = writeJPEG(image(width: 1600, height: 900, space: p3, alpha: false, color: [0, 1, 0, 1]), to: big, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.5, kCGImagePropertyGPSLatitudeRef: "S"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "Zenith Test Lens"],
        ])
        let resized = try? NotchPhotoEncoder.transform(big, recipe: recipe, directory: folder, reserved: &reserved)
        suite.expect(resized?.url.lastPathComponent == "wide-1080.jpg", "Resize names the long edge")
        if let url = resized?.url {
            let info = read(url)
            suite.expect(info.width == 1080 && (607...608).contains(info.height),
                         "the long edge is 1080, got \(info.width)×\(info.height)")
            suite.expect(!info.hasGPS && info.lens == nil && info.make == nil, "stripping leaves EXIF and GPS behind")
            suite.expect(info.profile == "Display P3", "the profile is not metadata to strip")
            suite.expect((resized?.outputBytes ?? 0) > 0 && resized?.pixelSize.width == 1080,
                         "the output reports its size")
        }

        // Strip alone: lossless, upright on display, nothing left to locate.
        let clean = try? NotchPhotoEncoder.transform(source, recipe: NotchPhotoRecipe(kind: .strip),
                                                     directory: folder, reserved: &reserved)
        suite.expect(clean?.url.lastPathComponent == "photo-clean.jpg", "Strip marks the name")
        if let url = clean?.url {
            let info = read(url)
            suite.expect(!info.hasGPS && info.lens == nil && info.make == nil, "Strip removes EXIF, TIFF and GPS details")
            suite.expect(info.orientation == 6 && info.width == 400, "a lossless strip keeps the stored orientation")
            suite.expect(info.profile == "Display P3", "Strip keeps the colour profile")
        }

        // Compress a transparent PNG: JPEG on white.
        let alphaSource = folder.appendingPathComponent("logo.png")
        _ = write(image(width: 64, height: 64, space: CGColorSpace(name: CGColorSpace.sRGB)!, alpha: true,
                        color: [0, 0, 1, 0.4]), type: UTType.png.identifier, to: alphaSource, properties: [:])
        let compressed = try? NotchPhotoEncoder.transform(alphaSource, recipe: NotchPhotoRecipe(kind: .compress),
                                                          directory: folder, reserved: &reserved)
        suite.expect(compressed?.url.lastPathComponent == "logo-q80.jpg", "Compress writes a JPEG named for its quality")
        if let url = compressed?.url { suite.expect(read(url).type == UTType.jpeg.identifier, "the compressed file is JPEG") }

        // Two files of one run never collide, even before either is on disk.
        var batch = Set<String>()
        let one = folder.appendingPathComponent("same.png")
        let two = folder.appendingPathComponent("same.tiff")
        _ = write(picture, type: UTType.png.identifier, to: one, properties: [:])
        _ = write(picture, type: UTType.tiff.identifier, to: two, properties: [:])
        let first = try? NotchPhotoEncoder.transform(one, recipe: NotchPhotoRecipe(kind: .convert), directory: folder,
                                                     reserved: &batch)
        let second = try? NotchPhotoEncoder.transform(two, recipe: NotchPhotoRecipe(kind: .convert), directory: folder,
                                                      reserved: &batch)
        suite.expect(first?.url.lastPathComponent == "same.jpg" && second?.url.lastPathComponent == "same-1.jpg",
                     "a batch numbers outputs that would share a name")

        // A format this Mac cannot write is refused before anything is made.
        var none = Set<String>()
        do {
            _ = try NotchPhotoEncoder.transform(source, recipe: NotchPhotoRecipe(kind: .convert, format: .webp),
                                                directory: folder, reserved: &none, writable: ["public.jpeg"])
            suite.expect(false, "an unwritable format must fail")
        } catch {
            suite.expect(error as? NotchPhotoError == .unsupportedFormat, "an unwritable format is named as such")
        }
        let cancelled = NotchPhotoCancellation()
        cancelled.cancel()
        do {
            _ = try NotchPhotoEncoder.transform(source, recipe: NotchPhotoRecipe(kind: .convert, format: .heic),
                                                directory: folder, reserved: &none, cancellation: cancelled)
            suite.expect(false, "a cancelled run must stop")
        } catch {
            suite.expect(error as? NotchPhotoError == .cancelled, "cancelling stops the run")
        }
        suite.expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("photo.heic").path),
                     "a cancelled run leaves no file")
        let unreadable = folder.appendingPathComponent("broken.jpg")
        try? Data("not a picture".utf8).write(to: unreadable)
        do {
            _ = try NotchPhotoEncoder.transform(unreadable, recipe: NotchPhotoRecipe(kind: .convert), directory: folder,
                                                reserved: &none)
            suite.expect(false, "a broken file must fail")
        } catch {
            suite.expect(error as? NotchPhotoError == .unreadable, "a broken file reads as unreadable")
        }
    }

    // MARK: Cutout

    private static func cutout(_ suite: TestSuite) {
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        let picture = image(width: 8, height: 8, space: p3, alpha: false, color: [0, 1, 0, 1])
        // White over the left half, black over the right.
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 2, height: 4))
        let black = CIImage(color: .black).cropped(to: CGRect(x: 2, y: 0, width: 2, height: 4))
        let mask = white.composited(over: black)
        guard let result = NotchPhotoEncoder.cutout(picture, mask: mask) else {
            suite.expect(false, "the cutout is composed")
            return
        }
        suite.expect(result.width == 8 && result.height == 8, "the cutout keeps the picture's size")
        suite.expect(result.colorSpace?.name == CGColorSpace.displayP3, "the cutout keeps Display P3")
        let alpha = alphaValues(result)
        suite.expect(alpha.left > 250 && alpha.right < 5,
                     "the subject stays and the rest is transparent (left \(alpha.left), right \(alpha.right))")

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-cutout-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var reserved = Set<String>()
        let input = folder.appendingPathComponent("portrait.heic")
        let output = try? NotchPhotoEncoder.writeCutout(result, for: input, directory: folder, reserved: &reserved)
        suite.expect(output?.url.lastPathComponent == "portrait-cutout.png", "the cutout is a PNG named for its source")
        if let url = output?.url {
            let info = read(url)
            suite.expect(info.type == UTType.png.identifier && info.hasAlpha, "the cutout file is a transparent PNG")
        }
    }

    // MARK: Fixtures

    private static func image(width: Int, height: Int, space: CGColorSpace, alpha: Bool, color: [CGFloat]) -> CGImage {
        let info = alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: info.rawValue)!
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(colorSpace: space, components: color)!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @discardableResult
    private static func write(_ image: CGImage, type: String, to url: URL, properties: [CFString: Any]) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private static func writeJPEG(_ image: CGImage, to url: URL, properties: [CFString: Any]) -> Bool {
        write(image, type: UTType.jpeg.identifier, to: url, properties: properties)
    }

    private struct Info {
        var type: String?
        var width = 0
        var height = 0
        var orientation = 1
        var profile: String?
        var lens: String?
        var make: String?
        var hasGPS = false
        var hasAlpha = false
    }

    private static func read(_ url: URL) -> Info {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return Info() }
        var info = Info()
        info.type = CGImageSourceGetType(source) as String?
        info.width = (properties[kCGImagePropertyPixelWidth] as? Int) ?? 0
        info.height = (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0
        info.orientation = (properties[kCGImagePropertyOrientation] as? Int) ?? 1
        info.profile = properties[kCGImagePropertyProfileName] as? String
        info.lens = (properties[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifLensModel] as? String
        info.make = (properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake] as? String
        info.hasGPS = properties[kCGImagePropertyGPSDictionary] != nil
        info.hasAlpha = (properties[kCGImagePropertyHasAlpha] as? Bool) ?? false
        return info
    }

    /// The alpha of the left and right halves' middle pixels.
    private static func alphaValues(_ image: CGImage) -> (left: Int, right: Int) {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return (0, 255) }
        let row = height / 2
        let left = Int(pixels[(row * width + width / 4) * 4 + 3])
        let right = Int(pixels[(row * width + width * 3 / 4) * 4 + 3])
        return (left, right)
    }
}
