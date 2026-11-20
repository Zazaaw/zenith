// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the Watermark step of the island's photo actions. A logo, a
// line of text or both, placed on a 3×3 grid or repeated diagonally across
// the picture for a proof, then written with the rest of Transform in one
// pass (resize, watermark, encode). This file is the pure part: the style a
// preset stores, the presets themselves, where the mark goes and how large it
// is, the tile pattern, and the white-or-black choice. The test executable
// compiles it; the drawing lives in `NotchWatermarkRenderer`.

/// What the watermark shows.
enum NotchWatermarkContent: String, Codable, CaseIterable, Identifiable {
    case logo, text, both
    var id: String { rawValue }

    var showsLogo: Bool { self != .text }
    var showsText: Bool { self != .logo }
}

/// A place on the 3×3 grid, read left to right, top to bottom.
enum NotchWatermarkPosition: Int, Codable, CaseIterable, Identifiable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
    var id: Int { rawValue }

    /// 0 left, 1 centre, 2 right.
    var column: Int { rawValue % 3 }
    /// 0 top, 1 middle, 2 bottom.
    var row: Int { rawValue / 3 }
}

/// The mark's colour. Auto picks white or black from what lies under it;
/// `original` keeps a chosen logo's own colours (text still follows Auto).
enum NotchWatermarkColor: String, Codable, CaseIterable, Identifiable {
    case auto, white, black, custom, original
    var id: String { rawValue }
}

/// The text's weight, as SF Pro's steps.
enum NotchWatermarkWeight: String, Codable, CaseIterable, Identifiable {
    case regular, medium, semibold, bold
    var id: String { rawValue }

    /// `NSFont.Weight`'s raw values, which Core Text's weight trait shares.
    var fontWeight: CGFloat {
        switch self {
        case .regular: return 0
        case .medium: return 0.23
        case .semibold: return 0.3
        case .bold: return 0.4
        }
    }
}

/// White or black, as Auto decides it.
enum NotchWatermarkTone: Equatable {
    case light, dark
}

/// Everything a watermark is, as a preset stores it. Sizes are shares of the
/// picture's short edge, so one style reads the same on a 1080 px story and a
/// 45 MP original. A value from an older version or an edited backup decodes
/// with defaults for what it lacks and is brought back into range.
struct NotchWatermarkStyle: Codable, Equatable {
    static let defaultText = "© Satu Visual"
    /// The mark's height, % of the short edge.
    static let scaleRange = 2.0...30.0
    /// From the picture's edge, % of the short edge.
    static let marginRange = 0.0...15.0
    static let opacityRange = 0.1...1.0
    static let textLimit = 80

    var content: NotchWatermarkContent = .logo
    /// A logo copied into the app's container (`NotchWatermarkLogoStore`);
    /// nil for the bundled Satu Visual star.
    var logoFile: String?
    var text: String = Self.defaultText
    var weight: NotchWatermarkWeight = .semibold
    var position: NotchWatermarkPosition = .bottomRight
    var margin: Double = 3
    var scale: Double = 8
    var opacity: Double = 0.8
    var color: NotchWatermarkColor = .auto
    /// `#RRGGBB`, used when `color` is `.custom`.
    var customColor: String = "#FFFFFF"
    var shadow = true
    /// Repeated diagonally over the whole picture, for proofs.
    var tiled = false

    init(content: NotchWatermarkContent = .logo, logoFile: String? = nil, text: String = Self.defaultText,
         weight: NotchWatermarkWeight = .semibold, position: NotchWatermarkPosition = .bottomRight,
         margin: Double = 3, scale: Double = 8, opacity: Double = 0.8, color: NotchWatermarkColor = .auto,
         customColor: String = "#FFFFFF", shadow: Bool = true, tiled: Bool = false) {
        self.content = content
        self.logoFile = logoFile
        self.text = text
        self.weight = weight
        self.position = position
        self.margin = margin
        self.scale = scale
        self.opacity = opacity
        self.color = color
        self.customColor = customColor
        self.shadow = shadow
        self.tiled = tiled
    }

    private enum CodingKeys: String, CodingKey {
        case content, logoFile, text, weight, position, margin, scale, opacity, color, customColor, shadow, tiled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = NotchWatermarkStyle()
        content = (try? values.decodeIfPresent(NotchWatermarkContent.self, forKey: .content)) ?? fallback.content
        logoFile = (try? values.decodeIfPresent(String.self, forKey: .logoFile)) ?? nil
        text = (try? values.decodeIfPresent(String.self, forKey: .text)) ?? fallback.text
        weight = (try? values.decodeIfPresent(NotchWatermarkWeight.self, forKey: .weight)) ?? fallback.weight
        position = (try? values.decodeIfPresent(NotchWatermarkPosition.self, forKey: .position)) ?? fallback.position
        margin = (try? values.decodeIfPresent(Double.self, forKey: .margin)) ?? fallback.margin
        scale = (try? values.decodeIfPresent(Double.self, forKey: .scale)) ?? fallback.scale
        opacity = (try? values.decodeIfPresent(Double.self, forKey: .opacity)) ?? fallback.opacity
        color = (try? values.decodeIfPresent(NotchWatermarkColor.self, forKey: .color)) ?? fallback.color
        customColor = (try? values.decodeIfPresent(String.self, forKey: .customColor)) ?? fallback.customColor
        shadow = (try? values.decodeIfPresent(Bool.self, forKey: .shadow)) ?? fallback.shadow
        tiled = (try? values.decodeIfPresent(Bool.self, forKey: .tiled)) ?? fallback.tiled
        self = sanitized()
    }

    /// In range and safe to draw: sizes clamped, the text one line of at
    /// most `textLimit` characters, a logo name that cannot leave its folder,
    /// a colour that parses.
    func sanitized() -> NotchWatermarkStyle {
        var style = self
        style.margin = Self.clamped(margin, to: Self.marginRange, fallback: 3)
        style.scale = Self.clamped(scale, to: Self.scaleRange, fallback: 8)
        style.opacity = Self.clamped(opacity, to: Self.opacityRange, fallback: 0.8)
        style.text = NotchWatermarkSupport.textInput(text)
            .trimmingCharacters(in: .whitespaces)
        if let file = logoFile, !NotchWatermarkLogoStore.isValidName(file) { style.logoFile = nil }
        if NotchWatermarkSupport.rgb(hex: customColor) == nil { style.customColor = "#FFFFFF" }
        return style
    }

    private static func clamped(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

    /// Whether anything at all would be drawn.
    var drawsSomething: Bool { content.showsLogo || !text.trimmingCharacters(in: .whitespaces).isEmpty }

    func encoded() -> String {
        guard let data = try? JSONEncoder.sorted.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decoded(_ string: String?) -> NotchWatermarkStyle {
        guard let data = string?.data(using: .utf8), !data.isEmpty,
              let style = try? JSONDecoder().decode(NotchWatermarkStyle.self, from: data) else { return NotchWatermarkStyle() }
        return style
    }
}

/// A named style.
struct NotchWatermarkPreset: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var style: NotchWatermarkStyle
}

/// The geometry of one mark, in its own box with the origin top left.
struct NotchWatermarkBlock: Equatable {
    var size: CGSize
    var logo: CGRect?
    var text: CGRect?
}

enum NotchWatermarkSupport {
    /// What a watermarked output's name ends with.
    static let nameSuffix = "-wm"
    static let presetLimit = 24
    static let presetNameLimit = 40
    /// The tile pattern rises to the right at this angle, in degrees.
    static let tileAngle: CGFloat = 30
    /// Above this relative luminance black reads better than white: the
    /// point where both have the same WCAG contrast against the backdrop.
    static let toneThreshold = 0.179

    // MARK: Settings

    static func style(in defaults: UserDefaults = .standard) -> NotchWatermarkStyle {
        NotchWatermarkStyle.decoded(defaults.string(forKey: DefaultsKey.notchWatermarkStyle))
    }

    static func saveStyle(_ style: NotchWatermarkStyle, in defaults: UserDefaults = .standard) {
        let encoded = style.sanitized().encoded()
        guard defaults.string(forKey: DefaultsKey.notchWatermarkStyle) != encoded else { return }
        defaults.set(encoded, forKey: DefaultsKey.notchWatermarkStyle)
    }

    /// The saved presets. Never saved reads as the two starters; an empty
    /// list someone left by deleting them all stays empty.
    static func presets(in defaults: UserDefaults = .standard, language: AppLanguage) -> [NotchWatermarkPreset] {
        decodedPresets(defaults.string(forKey: DefaultsKey.notchWatermarkPresets), language: language)
    }

    static func savePresets(_ presets: [NotchWatermarkPreset], in defaults: UserDefaults = .standard) {
        defaults.set(encodedPresets(presets), forKey: DefaultsKey.notchWatermarkPresets)
    }

    static func defaultPresetID(in defaults: UserDefaults = .standard) -> String? {
        let id = defaults.string(forKey: DefaultsKey.notchWatermarkDefaultPreset) ?? ""
        return id.isEmpty ? nil : id
    }

    static func decodedPresets(_ string: String?, language: AppLanguage) -> [NotchWatermarkPreset] {
        guard let string, !string.isEmpty else { return starterPresets(language) }
        guard let data = string.data(using: .utf8),
              let presets = try? JSONDecoder().decode([NotchWatermarkPreset].self, from: data) else { return [] }
        var seen = Set<String>()
        return presets.compactMap { preset -> NotchWatermarkPreset? in
            guard let name = presetName(preset.name), !preset.id.isEmpty, seen.insert(preset.id).inserted else { return nil }
            return NotchWatermarkPreset(id: preset.id, name: name, style: preset.style.sanitized())
        }
        .prefix(presetLimit).map { $0 }
    }

    static func encodedPresets(_ presets: [NotchWatermarkPreset]) -> String {
        guard let data = try? JSONEncoder.sorted.encode(Array(presets.prefix(presetLimit))) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    /// Two to start from: a diagonal proof over the whole picture, and a
    /// small corner mark for posting.
    static func starterPresets(_ language: AppLanguage) -> [NotchWatermarkPreset] {
        let text = ZenithStrings.watermark(language)
        return [
            NotchWatermarkPreset(id: "client-proof", name: text.clientProof, style: NotchWatermarkStyle(
                content: .both, position: .center, scale: 7, opacity: 0.32, shadow: false, tiled: true)),
            NotchWatermarkPreset(id: "instagram", name: text.instagram, style: NotchWatermarkStyle(
                content: .both, position: .bottomRight, margin: 3, scale: 5, opacity: 0.85)),
        ]
    }

    /// A preset's name: one trimmed line, at most `presetNameLimit`
    /// characters; nil when nothing is left.
    static func presetName(_ raw: String) -> String? {
        let line = textInput(raw).trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }
        return String(line.prefix(presetNameLimit))
    }

    /// Saves `style` under `name`: a preset of the same name (any case) is
    /// replaced in place, a new one goes last. A full list refuses a new name.
    static func saving(_ style: NotchWatermarkStyle, named raw: String, to presets: [NotchWatermarkPreset],
                       id: () -> String = { UUID().uuidString }) -> (presets: [NotchWatermarkPreset], id: String?) {
        guard let name = presetName(raw) else { return (presets, nil) }
        var presets = presets
        if let index = presets.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            presets[index].name = name
            presets[index].style = style.sanitized()
            return (presets, presets[index].id)
        }
        guard presets.count < presetLimit else { return (presets, nil) }
        let preset = NotchWatermarkPreset(id: id(), name: name, style: style.sanitized())
        presets.append(preset)
        return (presets, preset.id)
    }

    /// The preset this style is, if it is one unchanged.
    static func matchingPreset(_ style: NotchWatermarkStyle, in presets: [NotchWatermarkPreset]) -> NotchWatermarkPreset? {
        let style = style.sanitized()
        return presets.first { $0.style == style }
    }

    /// Typed text as one line: line breaks and tabs become spaces, control
    /// characters go, and it stops at `NotchWatermarkStyle.textLimit`.
    static func textInput(_ raw: String) -> String {
        let scalars = raw.unicodeScalars.map { scalar -> Character in
            if scalar == "\n" || scalar == "\r" || scalar == "\t" { return " " }
            return Character(scalar)
        }.filter { character in
            !character.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        }
        return String(String(scalars).prefix(NotchWatermarkStyle.textLimit))
    }

    // MARK: Geometry

    /// The mark's unit: its height, as `scale` % of the short edge.
    static func unit(canvas: CGSize, scale: Double) -> CGFloat {
        max(1, min(canvas.width, canvas.height) * CGFloat(scale) / 100)
    }

    static func margin(canvas: CGSize, margin: Double) -> CGFloat {
        max(0, min(canvas.width, canvas.height) * CGFloat(margin) / 100)
    }

    /// Text alone is set a little larger than text beside a logo, whose
    /// height it then sits within.
    static func fontSize(unit: CGFloat, content: NotchWatermarkContent) -> CGFloat {
        content == .text ? unit * 0.62 : unit * 0.4
    }

    /// The gap between the logo and the text.
    static func gap(unit: CGFloat) -> CGFloat { unit * 0.3 }

    /// Lays out one mark: the logo `unit` tall at its own aspect, the text
    /// beside it (`textSize` as Core Text measured it), both centred on one
    /// line. A missing part takes no room.
    static func block(unit: CGFloat, content: NotchWatermarkContent, logoAspect: CGFloat?,
                      textSize: CGSize?) -> NotchWatermarkBlock {
        let aspect = logoAspect.map { $0.isFinite && $0 > 0 ? min(10, max(0.1, $0)) : 1 }
        let logo = content.showsLogo ? aspect.map { CGSize(width: unit * $0, height: unit) } : nil
        let text = content.showsText ? textSize.flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil } : nil
        switch (logo, text) {
        case let (logo?, text?):
            let height = max(logo.height, text.height)
            let gap = gap(unit: unit)
            return NotchWatermarkBlock(
                size: CGSize(width: logo.width + gap + text.width, height: height),
                logo: CGRect(origin: CGPoint(x: 0, y: (height - logo.height) / 2), size: logo),
                text: CGRect(origin: CGPoint(x: logo.width + gap, y: (height - text.height) / 2), size: text))
        case let (logo?, nil):
            return NotchWatermarkBlock(size: logo, logo: CGRect(origin: .zero, size: logo), text: nil)
        case let (nil, text?):
            return NotchWatermarkBlock(size: text, logo: nil, text: CGRect(origin: .zero, size: text))
        case (nil, nil):
            return NotchWatermarkBlock(size: .zero, logo: nil, text: nil)
        }
    }

    /// Where a mark of `block` size goes, top left in the picture's
    /// coordinates (origin top left): `margin` in from the edges its grid
    /// place touches, centred on the others. A mark wider than the picture
    /// less its margins stays inside the picture.
    static func origin(canvas: CGSize, block: CGSize, position: NotchWatermarkPosition, margin: CGFloat) -> CGPoint {
        func place(_ index: Int, length: CGFloat, size: CGFloat) -> CGFloat {
            let room = length - size
            guard room > 0 else { return room / 2 }
            let inset = min(margin, room / 2)
            switch index {
            case 0: return inset
            case 2: return room - inset
            default: return room / 2
            }
        }
        return CGPoint(x: place(position.column, length: canvas.width, size: block.width),
                       y: place(position.row, length: canvas.height, size: block.height))
    }

    /// The tile pattern's steps along a row and between rows: room around
    /// each mark so the picture still reads.
    static func tileSteps(block: CGSize, unit: CGFloat) -> CGSize {
        CGSize(width: block.width + max(unit * 2, block.width * 0.6),
               height: block.height + max(unit * 2.2, block.height * 1.4))
    }

    /// The tile pattern's centres in the picture's coordinates (origin top
    /// left): a lattice through the picture's centre, rows turned up to the
    /// right by `tileAngle` and every other row shifted half a step, keeping
    /// each copy that can touch the picture.
    static func tileCenters(canvas: CGSize, block: CGSize, unit: CGFloat) -> [CGPoint] {
        guard canvas.width > 0, canvas.height > 0, block.width > 0, block.height > 0, unit > 0 else { return [] }
        let step = tileSteps(block: block, unit: unit)
        // Up to the right on screen is a negative turn where y grows downward.
        let angle = -tileAngle * .pi / 180
        let cosine = cos(angle), sine = sin(angle)
        let centre = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let radius = hypot(block.width, block.height) / 2
        let reach = hypot(canvas.width, canvas.height) / 2 + radius
        let columns = Int((reach / step.width).rounded(.up)) + 1
        let rows = Int((reach / step.height).rounded(.up)) + 1
        guard columns < 400, rows < 400 else { return [] }
        var points: [CGPoint] = []
        for row in -rows...rows {
            for column in -columns...columns {
                let x = CGFloat(column) * step.width + (abs(row) % 2 == 1 ? step.width / 2 : 0)
                let y = CGFloat(row) * step.height
                let point = CGPoint(x: centre.x + x * cosine - y * sine, y: centre.y + x * sine + y * cosine)
                if point.x > -radius, point.x < canvas.width + radius, point.y > -radius, point.y < canvas.height + radius {
                    points.append(point)
                }
            }
        }
        return points
    }

    // MARK: Colour

    /// White on a dark backdrop, black on a light one.
    static func tone(luminance: Double) -> NotchWatermarkTone {
        luminance > toneThreshold ? .dark : .light
    }

    /// Relative luminance (WCAG) of an sRGB colour, components 0 to 1.
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ value: Double) -> Double {
            let value = min(1, max(0, value))
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// `#RRGGBB` (or `RRGGBB`) as components 0 to 1.
    static func rgb(hex: String) -> (red: Double, green: Double, blue: Double)? {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    static func hex(red: Double, green: Double, blue: Double) -> String {
        func byte(_ value: Double) -> Int { Int((min(1, max(0, value.isFinite ? value : 0)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

/// Logos chosen for watermarks, copied into the app's container so a preset
/// keeps working after the original file moves: `<container>/Watermarks/`.
/// Only the file's name goes into preferences and backups; a backup restored
/// on another Mac falls back to the star until a logo is chosen there.
enum NotchWatermarkLogoStore {
    static let folderName = "Watermarks"
    static let extensions = ["png", "svg", "pdf", "jpg", "jpeg", "heic", "tiff", "tif", "webp"]
    static let maximumBytes: Int64 = 40_000_000

    static func folder(container: URL? = PrivateFileStore.containerURL) -> URL? {
        container?.appendingPathComponent(folderName, isDirectory: true)
    }

    static func url(for name: String, container: URL? = PrivateFileStore.containerURL) -> URL? {
        guard isValidName(name) else { return nil }
        return folder(container: container)?.appendingPathComponent(name, isDirectory: false)
    }

    static func exists(_ name: String?, container: URL? = PrivateFileStore.containerURL) -> Bool {
        guard let name, let url = url(for: name, container: container) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// `logo-<id>.<ext>`: ASCII letters, digits, `.`, `_` and `-`, one known
    /// extension, never a path.
    static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 96, !name.hasPrefix("."), !name.contains("/"),
              name.unicodeScalars.allSatisfy({
                  $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0))
              }) else { return false }
        return extensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// Copies `source` into the folder and returns its new name, or nil
    /// when it is not a picture Zenith can draw or is too large.
    static func importLogo(from source: URL, container: URL? = PrivateFileStore.containerURL,
                           id: String = UUID().uuidString) -> String? {
        let ext = source.pathExtension.lowercased()
        guard extensions.contains(ext), let folder = folder(container: container) else { return nil }
        let size = (try? source.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard size > 0, Int64(size) <= maximumBytes, let data = try? Data(contentsOf: source) else { return nil }
        let name = "logo-\(id.lowercased()).\(ext)"
        guard isValidName(name), PrivateFileStore.createDirectory(at: folder, container: container) else { return nil }
        let destination = folder.appendingPathComponent(name, isDirectory: false)
        return PrivateFileStore.write(data, to: destination) ? name : nil
    }

    /// Removes logos nothing refers to any more.
    static func prune(keeping names: Set<String>, container: URL? = PrivateFileStore.containerURL) {
        guard let folder = folder(container: container),
              let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return }
        for file in files where isValidName(file) && !names.contains(file) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
        }
    }
}

private extension JSONEncoder {
    /// Stable output, so an unchanged style writes the same string.
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
