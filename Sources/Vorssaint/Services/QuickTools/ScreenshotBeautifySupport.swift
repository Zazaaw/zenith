// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: Beautify frames a screenshot for sharing (a background, padding,
// rounded corners, a shadow, an optional window frame and caption, at a chosen
// aspect). Everything here is pure, so the layout, the stored style and the
// presets are tested without a window; the pixels are in
// ScreenshotBeautifyRenderer and the editor's side in ScreenshotBeautifySession.

/// One look for a framed screenshot, stored as JSON. Every field decodes on its
/// own, so a style saved by an older build, or edited in a backup, still loads.
struct ScreenshotBeautifyStyle: Codable, Equatable, Sendable {
    enum Background: String, Codable, CaseIterable, Sendable {
        case gradient, solid, transparent, wallpaper
    }

    enum Shadow: String, Codable, CaseIterable, Sendable {
        case none, soft, strong
    }

    enum WindowFrame: String, Codable, CaseIterable, Sendable {
        case none, light, dark
    }

    enum Aspect: String, Codable, CaseIterable, Sendable {
        case auto, wide, square, portrait, story

        /// Width over height, or nil when the canvas follows the shot.
        var ratio: CGFloat? {
            switch self {
            case .auto: return nil
            case .wide: return 16.0 / 9.0
            case .square: return 1
            case .portrait: return 4.0 / 5.0
            case .story: return 9.0 / 16.0
            }
        }

        /// The ratio as people write it; never translated.
        var label: String {
            switch self {
            case .auto: return "Auto"
            case .wide: return "16:9"
            case .square: return "1:1"
            case .portrait: return "4:5"
            case .story: return "9:16"
            }
        }
    }

    enum Format: String, Codable, CaseIterable, Sendable {
        case png, jpeg

        var fileExtension: String { self == .png ? "png" : "jpg" }
    }

    var background: Background = .gradient
    var gradient: ScreenshotBeautifyGradient = .mist
    /// `#RRGGBB`, sRGB.
    var solid: String = "#F4F4F2"
    /// Margin around the shot as a fraction of the shot's size (see the layout).
    var padding: Double = 0.08
    /// Corner radius of the shot in points, multiplied by the capture's scale.
    var cornerRadius: Double = 12
    var shadow: Shadow = .soft
    var frame: WindowFrame = .none
    var aspect: Aspect = .auto
    var caption: String = ""
    var format: Format = .png

    static let paddingRange: ClosedRange<Double> = 0...0.3
    static let cornerRange: ClosedRange<Double> = 0...48
    static let captionLimit = 120

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = ScreenshotBeautifyStyle()
        background = (try? container.decodeIfPresent(Background.self, forKey: .background)) ?? fallback.background
        gradient = ScreenshotBeautifyGradient.stored(
            (try? container.decodeIfPresent(String.self, forKey: .gradient)) ?? nil)
        solid = (try? container.decodeIfPresent(String.self, forKey: .solid))
            ?? fallback.solid
        padding = (try? container.decodeIfPresent(Double.self, forKey: .padding))
            ?? fallback.padding
        cornerRadius = (try? container.decodeIfPresent(Double.self, forKey: .cornerRadius)) ?? fallback.cornerRadius
        shadow = (try? container.decodeIfPresent(Shadow.self, forKey: .shadow))
            ?? fallback.shadow
        frame = (try? container.decodeIfPresent(WindowFrame.self, forKey: .frame))
            ?? fallback.frame
        aspect = (try? container.decodeIfPresent(Aspect.self, forKey: .aspect))
            ?? fallback.aspect
        caption = (try? container.decodeIfPresent(String.self, forKey: .caption))
            ?? fallback.caption
        format = (try? container.decodeIfPresent(Format.self, forKey: .format))
            ?? fallback.format
        self = sanitized()
    }

    /// Values pulled back into range, a colour that parses, a caption on one
    /// line and not too long.
    func sanitized() -> ScreenshotBeautifyStyle {
        var style = self
        style.padding = Self.clamp(padding.isFinite ? padding : 0.08, to: Self.paddingRange)
        style.cornerRadius = Self.clamp(cornerRadius.isFinite ? cornerRadius : 12, to: Self.cornerRange)
        style.solid = ScreenshotBeautifyColor(hex: solid).map(\.hex) ?? ScreenshotBeautifyStyle().solid
        let line = caption.components(separatedBy: .newlines).joined(separator: " ")
        style.caption = String(line.prefix(Self.captionLimit))
        return style
    }

    /// Something opaque always paints behind the shot except for Clear.
    var isOpaque: Bool { background != .transparent }

    /// JPEG has no alpha, so a clear background always leaves as PNG.
    var effectiveFormat: Format { isOpaque ? format : .png }

    var trimmedCaption: String { caption.trimmingCharacters(in: .whitespaces) }

    func encoded() -> String {
        guard let data = try? JSONEncoder.sortedKeys.encode(sanitized()),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    static func decoded(_ raw: String?) -> ScreenshotBeautifyStyle {
        guard let raw, let data = raw.data(using: .utf8),
              let style = try? JSONDecoder().decode(ScreenshotBeautifyStyle.self, from: data)
        else { return ScreenshotBeautifyStyle() }
        return style
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

private extension JSONEncoder {
    static var sortedKeys: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

// MARK: - Colours

/// An sRGB colour as the style stores it.
struct ScreenshotBeautifyColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// `#RRGGBB` or `RRGGBB`, any case.
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    var hex: String {
        func byte(_ value: Double) -> Int { Int((value * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Relative luminance (Rec. 709 weights on the stored values), enough to
    /// pick a caption colour that reads.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

/// The gradients Beautify offers: Satu Visual's two monochromes and a few soft
/// colours, all calm enough to sit behind any interface.
enum ScreenshotBeautifyGradient: String, Codable, CaseIterable, Sendable {
    case ink, paper, mist, peach, sage, sky, sand, dusk

    static let fallback = ScreenshotBeautifyGradient.mist

    static func stored(_ raw: String?) -> ScreenshotBeautifyGradient {
        raw.flatMap(ScreenshotBeautifyGradient.init(rawValue:)) ?? fallback
    }

    init(from decoder: Decoder) throws {
        self = Self.stored(try? decoder.singleValueContainer().decode(String.self))
    }

    /// Top-left to bottom-right.
    var stops: [ScreenshotBeautifyColor] {
        let hexes: [String]
        switch self {
        case .ink: hexes = ["#0A0A0A", "#2B2B2B"]
        case .paper: hexes = ["#FFFFFF", "#E6E6E3"]
        case .mist: hexes = ["#DCE6F4", "#EFE6F5"]
        case .peach: hexes = ["#FDE7DA", "#F6C9C1"]
        case .sage: hexes = ["#E3ECDD", "#B9CDB8"]
        case .sky: hexes = ["#D6E8F8", "#93BCE6"]
        case .sand: hexes = ["#F5EEE2", "#DCCAAE"]
        case .dusk: hexes = ["#2C3550", "#6A5C8E"]
        }
        return hexes.compactMap(ScreenshotBeautifyColor.init(hex:))
    }

    var luminance: Double {
        let values = stops.map(\.luminance)
        return values.reduce(0, +) / Double(max(values.count, 1))
    }
}

/// Quiet solids offered next to the colour well.
enum ScreenshotBeautifySolids {
    static let swatches = ["#F4F4F2", "#FFFFFF", "#0A0A0A", "#1F2330", "#E9EEF6", "#F3E9E2"]
}

// MARK: - Presets

/// A style the person named and kept.
struct ScreenshotBeautifyPreset: Codable, Equatable, Identifiable, Sendable {
    var name: String
    var style: ScreenshotBeautifyStyle

    var id: String { name }
}

enum ScreenshotBeautifyPresets {
    static let limit = 12
    static let nameLimit = 40

    static func cleanName(_ name: String) -> String {
        let line = name.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return String(line.prefix(nameLimit))
    }

    /// Adds a preset, or replaces the one with the same name (any case) in its
    /// place. The oldest falls off past the limit. An empty name changes nothing.
    static func saving(_ style: ScreenshotBeautifyStyle, named name: String,
                       to presets: [ScreenshotBeautifyPreset]) -> [ScreenshotBeautifyPreset] {
        let clean = cleanName(name)
        guard !clean.isEmpty else { return presets }
        var result = presets
        let preset = ScreenshotBeautifyPreset(name: clean, style: style.sanitized())
        if let index = result.firstIndex(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
            result[index] = preset
        } else {
            result.append(preset)
        }
        return Array(result.suffix(limit))
    }

    static func removing(named name: String, from presets: [ScreenshotBeautifyPreset]) -> [ScreenshotBeautifyPreset] {
        presets.filter { $0.name != name }
    }

    static func encoded(_ presets: [ScreenshotBeautifyPreset]) -> String {
        guard let data = try? JSONEncoder.sortedKeys.encode(Array(presets.suffix(limit))),
              let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }

    /// Unreadable entries are skipped one by one rather than losing the list,
    /// and names stay unique.
    static func decoded(_ raw: String?) -> [ScreenshotBeautifyPreset] {
        guard let raw, let data = raw.data(using: .utf8),
              let items = try? JSONDecoder().decode([LossyPreset].self, from: data)
        else { return [] }
        var result: [ScreenshotBeautifyPreset] = []
        for case let preset? in items.map(\.value) {
            let clean = cleanName(preset.name)
            guard !clean.isEmpty,
                  !result.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame })
            else { continue }
            result.append(ScreenshotBeautifyPreset(name: clean, style: preset.style.sanitized()))
        }
        return Array(result.suffix(limit))
    }

    private struct LossyPreset: Decodable {
        let value: ScreenshotBeautifyPreset?

        init(from decoder: Decoder) throws {
            value = try? ScreenshotBeautifyPreset(from: decoder)
        }
    }
}

// MARK: - Stored preferences

/// The last style, the named presets and the after-capture switch. All three
/// are registered defaults, so a settings backup carries them.
enum ScreenshotBeautifyStore {
    static func lastStyle(_ defaults: UserDefaults = .standard) -> ScreenshotBeautifyStyle {
        ScreenshotBeautifyStyle.decoded(defaults.string(forKey: DefaultsKey.screenshotBeautifyStyle))
    }

    static func saveLastStyle(_ style: ScreenshotBeautifyStyle, _ defaults: UserDefaults = .standard) {
        let encoded = style.encoded()
        guard defaults.string(forKey: DefaultsKey.screenshotBeautifyStyle) != encoded else { return }
        defaults.set(encoded, forKey: DefaultsKey.screenshotBeautifyStyle)
    }

    static func presets(_ defaults: UserDefaults = .standard) -> [ScreenshotBeautifyPreset] {
        ScreenshotBeautifyPresets.decoded(defaults.string(forKey: DefaultsKey.screenshotBeautifyPresets))
    }

    static func savePresets(_ presets: [ScreenshotBeautifyPreset], _ defaults: UserDefaults = .standard) {
        defaults.set(ScreenshotBeautifyPresets.encoded(presets), forKey: DefaultsKey.screenshotBeautifyPresets)
    }

    static func beautifiesAfterCapture(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.screenshotBeautifyAfterCapture)
    }
}

// MARK: - Layout

/// Where everything lands on the canvas, in pixels with the origin at the top
/// left. The shot keeps its own pixels: the canvas grows around it to the
/// padding and the aspect, and only a canvas past `maximumSide` scales down.
struct ScreenshotBeautifyLayout: Equatable, Sendable {
    struct ShadowSpec: Equatable, Sendable {
        let blur: CGFloat
        let offset: CGFloat
        let alpha: CGFloat
    }

    let canvas: CGSize
    /// The window frame's bar and the shot together.
    let card: CGRect
    let bar: CGRect?
    let shot: CGRect
    let caption: CGRect?
    let captionFontSize: CGFloat
    let cornerRadius: CGFloat
    let shadow: ShadowSpec?
    /// 1 unless the canvas had to shrink to stay under `maximumSide`.
    let contentScale: CGFloat

    /// Big enough for a 6K display at 9:16, small enough to stay out of
    /// gigabytes of memory.
    static let maximumSide: CGFloat = 8192
    /// A macOS title bar, in points.
    static let barHeightPoints: CGFloat = 28
    /// The traffic lights: diameter, first centre from the left, spacing.
    static let lightDiameterPoints: CGFloat = 12
    static let lightInsetPoints: CGFloat = 20
    static let lightSpacingPoints: CGFloat = 20
    /// The continuous corner reaches this many radii along each edge.
    static let continuousReach: CGFloat = 1.52866483

    static func make(shotPixels: CGSize, scale: CGFloat, style: ScreenshotBeautifyStyle,
                     maximumSide: CGFloat = maximumSide) -> ScreenshotBeautifyLayout {
        let style = style.sanitized()
        let pointScale = max(scale, 1)
        let shotWidth = max(shotPixels.width.rounded(), 1)
        let shotHeight = max(shotPixels.height.rounded(), 1)
        let barHeight = style.frame == .none ? 0 : (barHeightPoints * pointScale).rounded()
        let cardWidth = shotWidth
        let cardHeight = shotHeight + barHeight
        let size = (cardWidth * cardHeight).squareRoot()
        let padding = (size * CGFloat(style.padding)).rounded()

        let hasCaption = !style.trimmedCaption.isEmpty
        let fontSize = hasCaption ? max(13 * pointScale, cardWidth * 0.018).rounded() : 0
        let captionGap = hasCaption ? (fontSize * 1.1).rounded() : 0
        let captionHeight = hasCaption ? (fontSize * 1.35).rounded() : 0
        // A caption never sits on the canvas edge, even with no padding.
        let bottomExtra = hasCaption ? max(0, fontSize - padding) : 0

        let contentWidth = cardWidth
        let contentHeight = cardHeight + captionGap + captionHeight
        var width = contentWidth + padding * 2
        var height = contentHeight + padding * 2 + bottomExtra
        if let ratio = style.aspect.ratio {
            if width / height < ratio {
                width = (height * ratio).rounded(.up)
            } else {
                height = (width / ratio).rounded(.up)
            }
        }

        let factor = min(1, maximumSide / max(width, height))
        let canvas = CGSize(width: max((width * factor).rounded(), 1),
                            height: max((height * factor).rounded(), 1))
        let originX = (width - contentWidth) / 2
        let originY = (height - bottomExtra - contentHeight) / 2
        func scaled(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX * factor, y: rect.minY * factor,
                   width: rect.width * factor, height: rect.height * factor)
        }

        let card = CGRect(x: originX, y: originY, width: cardWidth, height: cardHeight)
        let bar = barHeight > 0 ? CGRect(x: originX, y: originY, width: cardWidth, height: barHeight) : nil
        let shot = CGRect(x: originX, y: originY + barHeight, width: shotWidth, height: shotHeight)
        let caption = hasCaption
            ? CGRect(x: originX, y: card.maxY + captionGap, width: contentWidth, height: captionHeight)
            : nil

        let maximumCorner = min(cardWidth, cardHeight) / 2 / continuousReach
        let corner = min(CGFloat(style.cornerRadius) * pointScale, maximumCorner)

        let shadow: ShadowSpec?
        switch style.shadow {
        case .none: shadow = nil
        case .soft: shadow = ShadowSpec(blur: size * 0.045 * factor, offset: size * 0.014 * factor, alpha: 0.22)
        case .strong: shadow = ShadowSpec(blur: size * 0.075 * factor, offset: size * 0.03 * factor, alpha: 0.42)
        }

        return ScreenshotBeautifyLayout(canvas: canvas,
                                        card: scaled(card),
                                        bar: bar.map(scaled),
                                        shot: scaled(shot),
                                        caption: caption.map(scaled),
                                        captionFontSize: fontSize * factor,
                                        cornerRadius: corner * factor,
                                        shadow: shadow,
                                        contentScale: factor)
    }

    /// Centres of the three traffic lights in the bar, left to right.
    func lightCenters(scale: CGFloat) -> [CGPoint] {
        guard let bar else { return [] }
        let unit = max(scale, 1) * contentScale
        return (0..<3).map { index in
            CGPoint(x: bar.minX + (Self.lightInsetPoints + CGFloat(index) * Self.lightSpacingPoints) * unit,
                    y: bar.midY)
        }
    }
}

// MARK: - Handoff from the capture preview

/// The capture preview's Beautify is its Edit with one wish attached: the
/// editor that opens next starts in Beautify. The wish lapses after a moment,
/// so a press that opened nothing cannot surprise a later editor.
enum ScreenshotBeautifyHandoff {
    private static var requestedAt: TimeInterval?
    static let lifetime: TimeInterval = 3

    static var title: String { ZenithStrings.beautify(L10n.shared.language).title }

    static func request(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        requestedAt = now
    }

    /// True once for a recent request.
    static func consume(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        defer { requestedAt = nil }
        guard let requestedAt else { return false }
        return now - requestedAt >= 0 && now - requestedAt <= lifetime
    }
}

// MARK: - Naming

enum ScreenshotBeautifyNaming {
    static let suffix = "-beautified"

    /// The original's name with the suffix and the export's extension, made
    /// unique in its folder so nothing is ever overwritten: `Shot-beautified.png`,
    /// then `Shot-beautified 2.png`.
    static func beautifiedName(for original: String, fileExtension: String,
                               exists: (String) -> Bool) -> String {
        let base = ((original as NSString).lastPathComponent as NSString).deletingPathExtension
        let stem = base.hasSuffix(suffix) ? base : base + suffix
        return ScreenshotSupport.uniqueFileName("\(stem).\(fileExtension)", exists: exists)
    }

    /// The beautified file beside `original`, never on top of anything.
    static func beautifiedURL(beside original: URL, fileExtension: String,
                              fileManager: FileManager = .default) -> URL {
        let folder = original.deletingLastPathComponent()
        let name = beautifiedName(for: original.lastPathComponent, fileExtension: fileExtension) {
            fileManager.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
        return folder.appendingPathComponent(name)
    }

    /// An original worth saving beside: a file that still exists in a folder
    /// the person keeps, not one of the app's caches or temporary copies.
    static func isUsableOriginal(_ url: URL?, fileManager: FileManager = .default) -> Bool {
        guard let url, url.isFileURL, fileManager.fileExists(atPath: url.path) else { return false }
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let library = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library").path
        let temporary = fileManager.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        if path.hasPrefix(library + "/") || path.hasPrefix(temporary) { return false }
        if path.hasPrefix("/private/var/folders/") || path.hasPrefix("/var/folders/") { return false }
        return fileManager.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }
}
