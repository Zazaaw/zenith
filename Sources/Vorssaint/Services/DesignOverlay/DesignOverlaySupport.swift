// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation
import ImageIO

// Zenith fork: the design QA overlay. A reference image (a Figma export) floats
// over the browser at its true point size, so a build can be checked against
// the design pixel for pixel. This file is the pure part: how big the image is
// in points, where it sits and how it moves, what each display remembers, the
// column grid, and which island drop targets an image gets. The test
// executable compiles it (build.sh, TEST_SOURCES).

/// How the reference is drawn over what is under it.
enum DesignOverlayBlend: String, CaseIterable, Identifiable {
    /// The image as it is, at the chosen opacity.
    case normal
    /// The absolute difference between the image and the screen under it:
    /// black where they match. Needs Screen Recording, because one window
    /// cannot blend with another's pixels (see DesignOverlayDifference).
    case difference
    /// The image inverted. At 50% over a matching build it cancels to a flat
    /// grey, so anything off stands out without any permission.
    case invert

    var id: String { rawValue }

    /// The stored value, or `fallback` for anything unknown.
    static func stored(_ raw: String?, fallback: DesignOverlayBlend = .normal) -> DesignOverlayBlend {
        raw.flatMap(DesignOverlayBlend.init(rawValue:)) ?? fallback
    }
}

/// The pixel density the reference was exported at: detected, or set by hand.
enum DesignOverlayScaleChoice: String, CaseIterable, Identifiable {
    case automatic, x1, x2, x3

    var id: String { rawValue }

    /// The fixed factor, nil for automatic.
    var factor: Int? {
        switch self {
        case .automatic: return nil
        case .x1: return 1
        case .x2: return 2
        case .x3: return 3
        }
    }

    /// The factor to draw with: the hand-set one, or the detected one.
    func resolved(detected: Int) -> Int {
        factor ?? min(max(detected, 1), 3)
    }

    static func stored(_ raw: String?) -> DesignOverlayScaleChoice {
        raw.flatMap(DesignOverlayScaleChoice.init(rawValue:)) ?? .automatic
    }
}

/// What Image I/O says about a reference without decoding it.
struct DesignOverlayImageInfo: Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    /// Dots per inch as the file states it, nil when it states none.
    let dpi: Double?

    init(pixelWidth: Int, pixelHeight: Int, dpi: Double?) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.dpi = dpi
    }

    /// Reads size and density from a file or from clipboard data.
    init?(source: CGImageSource) {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0
        else { return nil }
        let dpi = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue
            ?? (properties[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue
        // A picture taken sideways reports its stored size; the overlay draws
        // it upright, so swap for orientations 5 to 8.
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let turned = (5...8).contains(orientation)
        self.init(pixelWidth: turned ? height : width, pixelHeight: turned ? width : height, dpi: dpi)
    }

    init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        self.init(source: source)
    }

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        self.init(source: source)
    }
}

enum DesignOverlaySupport {
    // MARK: Scale

    /// Frame widths design tools start from, in points: phones, tablets,
    /// laptops and desktops. An export whose width divides into one of
    /// these was made at that multiple.
    static let commonFrameWidths: Set<Int> = [
        320, 360, 375, 390, 393, 402, 412, 414, 428, 430, 440,
        600, 744, 768, 800, 810, 820, 834, 1024, 1112, 1133, 1194,
        1280, 1366, 1440, 1512, 1536, 1600, 1680, 1728, 1920,
    ]

    /// The scale an image was exported at.
    ///
    /// A density in the file decides first: 144 dpi is a 2x export, 216 a 3x
    /// one (macOS screenshots and Sketch write it). Figma writes no density,
    /// so the width decides next: a known frame width is 1x, twice or three
    /// times one is 2x or 3x (2880 for a 1440 frame, 1170 for a 390 phone).
    /// Failing both, an image wider than the screen is taken at the smallest
    /// factor that fits it, and anything else at 1x.
    static func detectedScale(pixelWidth: Int, dpi: Double?, screenPointWidth: CGFloat? = nil) -> Int {
        if let dpi, dpi.isFinite, dpi > 80 {
            return min(max(Int((dpi / 72).rounded()), 1), 3)
        }
        guard pixelWidth > 0 else { return 1 }
        let fitsScreen = screenPointWidth.map { CGFloat(pixelWidth) <= $0 } ?? true
        if commonFrameWidths.contains(pixelWidth), fitsScreen { return 1 }
        for factor in [2, 3] where pixelWidth % factor == 0 && commonFrameWidths.contains(pixelWidth / factor) {
            return factor
        }
        if let screenPointWidth, screenPointWidth > 0, !fitsScreen {
            for factor in [2, 3] where CGFloat(pixelWidth) / CGFloat(factor) <= screenPointWidth { return factor }
            return 3
        }
        return 1
    }

    static func detectedScale(_ info: DesignOverlayImageInfo, screenPointWidth: CGFloat? = nil) -> Int {
        detectedScale(pixelWidth: info.pixelWidth, dpi: info.dpi, screenPointWidth: screenPointWidth)
    }

    /// The image's size on screen: its pixels over the export scale, so a 2x
    /// export of a 1440 point frame covers 1440 points.
    static func pointSize(pixelWidth: Int, pixelHeight: Int, scale: Int) -> CGSize {
        let factor = CGFloat(min(max(scale, 1), 3))
        return CGSize(width: CGFloat(max(pixelWidth, 1)) / factor, height: CGFloat(max(pixelHeight, 1)) / factor)
    }

    /// `value` on the display's pixel grid, so an edge lands on a device pixel.
    static func snapped(_ value: CGFloat, displayScale: CGFloat) -> CGFloat {
        let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
        return (value * scale).rounded() / scale
    }

    // MARK: Opacity

    static let defaultOpacity = 0.5
    /// Never fully invisible: a hidden overlay is closed, not transparent.
    static let opacityRange: ClosedRange<Double> = 0.05...1

    static func clampedOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOpacity }
        return min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }

    /// A digit key pressed in the HUD: 1 is 10%, 9 is 90%, 0 is 100%.
    static func opacity(forDigit digit: Int) -> Double? {
        guard (0...9).contains(digit) else { return nil }
        return digit == 0 ? 1 : Double(digit) / 10
    }

    // MARK: Coordinates

    /// A rectangle in Core Graphics' global space (top left of the main
    /// display, y down) as AppKit frames it (bottom left, y up).
    static func cocoaFrame(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The reverse of `cocoaFrame`.
    static func globalFrame(_ cocoa: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: cocoa.minX, y: primaryHeight - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }

    /// The image's frame in global space, from its offset into a display.
    static func frame(offset: CGPoint, size: CGSize, display: CGRect) -> CGRect {
        CGRect(origin: CGPoint(x: display.minX + offset.x, y: display.minY + offset.y), size: size)
    }

    /// The offset into `display` that puts the image's top left on `point`.
    static func offset(placing point: CGPoint, in display: CGRect) -> CGPoint {
        CGPoint(x: point.x - display.minX, y: point.y - display.minY)
    }

    /// Where the HUD goes, outside the image when there is room: under it,
    /// then over it, then inside the visible area's bottom edge. `visible` is
    /// the display's area free of the menu bar and Dock, all in global space.
    static func hudOrigin(image: CGRect, hud: CGSize, visible: CGRect, gap: CGFloat = 12) -> CGPoint {
        let x = min(max(image.minX, visible.minX + gap), max(visible.minX + gap, visible.maxX - hud.width - gap))
        if image.maxY + gap + hud.height <= visible.maxY - gap {
            return CGPoint(x: x, y: image.maxY + gap)
        }
        if image.minY - gap - hud.height >= visible.minY + gap {
            return CGPoint(x: x, y: image.minY - gap - hud.height)
        }
        return CGPoint(x: max(visible.minX + gap, visible.maxX - hud.width - gap), y: visible.maxY - hud.height - gap)
    }

    // MARK: Difference

    /// The part of the reference behind `visible` (a slice of the image's
    /// `frame`, both in points, y down), in the reference's own pixels with
    /// Core Image's origin at the bottom left.
    static func referenceCrop(frame: CGRect, visible: CGRect, imageScale: Int) -> CGRect {
        let slice = frame.intersection(visible)
        guard !slice.isNull, slice.width > 0, slice.height > 0 else { return .zero }
        let factor = CGFloat(min(max(imageScale, 1), 3))
        let x = (slice.minX - frame.minX) * factor
        let fromTop = (slice.minY - frame.minY) * factor
        let height = slice.height * factor
        let y = frame.height * factor - fromTop - height
        return CGRect(x: x, y: y, width: slice.width * factor, height: height)
    }

    /// Pixels to capture for `points` on a display of `displayScale`.
    static func capturePixels(_ points: CGSize, displayScale: CGFloat) -> (width: Int, height: Int) {
        let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
        return (max(1, Int((points.width * scale).rounded())), max(1, Int((points.height * scale).rounded())))
    }

    // MARK: Fit

    /// The window Fit aligns to, from the window server's list (front to
    /// back): the topmost one under the pointer, else the frontmost app's
    /// top window, else the topmost window. Slivers are skipped.
    static func targetWindow(in windows: [DesignOverlayWindowCandidate], mouse: CGPoint,
                             frontmost: Int32?) -> DesignOverlayWindowCandidate? {
        let usable = windows.filter { $0.frame.width >= 80 && $0.frame.height >= 80 }
        return usable.first { $0.frame.contains(mouse) }
            ?? usable.first { $0.pid == frontmost }
            ?? usable.first
    }

    /// Whether an Accessibility frame and a window server frame are the same window.
    static func sameFrame(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    /// A browser's page area among its web areas (frames inside a page are
    /// web areas too): the largest, held inside the window.
    static func pageFrame(_ areas: [CGRect], window: CGRect) -> CGRect? {
        areas.map { $0.intersection(window) }
            .filter { !$0.isNull && $0.width >= 40 && $0.height >= 40 }
            .max { $0.width * $0.height < $1.width * $1.height }
    }

    // MARK: Island

    /// The Overlay zone's glyph: one frame laid over another.
    static let dropSymbol = "square.on.square"

    /// Whether dropping one image on the island offers the Overlay zone. It
    /// follows the screenshot tool, which carries the overlay's settings.
    static var isDropEnabled: Bool {
        AppFeature.screenshot.isAvailable
            && UserDefaults.standard.object(forKey: DefaultsKey.designOverlayDropEnabled) as? Bool ?? true
    }

    /// An image drag's targets with Overlay after the photo actions: one
    /// image only, since the overlay shows a single reference.
    static func dropTargets(photo: [NotchDropTarget], imageCount: Int, overlay: Bool) -> [NotchDropTarget] {
        photo.filter { $0 != .overlay } + (overlay && imageCount == 1 ? [.overlay] : [])
    }
}

/// A window on screen, as Fit sees it: its owner and its frame in global
/// points, y down.
struct DesignOverlayWindowCandidate: Equatable {
    let pid: Int32
    let frame: CGRect
}

// MARK: - Placement

/// Arrow keys in the HUD.
enum DesignOverlayNudge: CaseIterable {
    case left, right, up, down

    /// The arrow's movement in points, y down: 1 point, 10 with Shift.
    func delta(large: Bool) -> CGVector {
        let step: CGFloat = large ? 10 : 1
        switch self {
        case .left: return CGVector(dx: -step, dy: 0)
        case .right: return CGVector(dx: step, dy: 0)
        case .up: return CGVector(dx: 0, dy: -step)
        case .down: return CGVector(dx: 0, dy: step)
        }
    }

    /// The arrow key's virtual key code.
    init?(keyCode: UInt16) {
        switch keyCode {
        case 123: self = .left
        case 124: self = .right
        case 125: self = .down
        case 126: self = .up
        default: return nil
        }
    }
}

/// Where the image sits on its display, and whether it may move.
struct DesignOverlayPlacement: Equatable {
    /// The image's top left from the display's top left, in points.
    var offset: CGPoint
    var locked = false

    /// One arrow press; nothing while locked.
    func nudged(_ direction: DesignOverlayNudge, large: Bool) -> DesignOverlayPlacement {
        let delta = direction.delta(large: large)
        return moved(by: delta)
    }

    func moved(by delta: CGVector) -> DesignOverlayPlacement {
        guard !locked, delta.dx.isFinite, delta.dy.isFinite else { return self }
        var next = self
        next.offset = CGPoint(x: offset.x + delta.dx, y: offset.y + delta.dy)
        return next
    }

    /// A new spot (a drag, or Fit); nothing while locked.
    func moved(to point: CGPoint) -> DesignOverlayPlacement {
        guard !locked, point.x.isFinite, point.y.isFinite else { return self }
        var next = self
        next.offset = point
        return next
    }

    func locking(_ locked: Bool) -> DesignOverlayPlacement {
        var next = self
        next.locked = locked
        return next
    }
}

// MARK: - Memory

/// What one display remembers about the overlay last shown on it.
struct DesignOverlayDisplayRecord: Equatable {
    var offset: CGPoint
    var opacity: Double
    var scale: DesignOverlayScaleChoice
    var locked: Bool

    var dictionary: [String: Any] {
        ["x": Double(offset.x), "y": Double(offset.y), "opacity": opacity, "scale": scale.rawValue,
         "locked": locked]
    }

    init(offset: CGPoint, opacity: Double, scale: DesignOverlayScaleChoice, locked: Bool = false) {
        self.offset = offset
        self.opacity = DesignOverlaySupport.clampedOpacity(opacity)
        self.scale = scale
        self.locked = locked
    }

    init?(dictionary: [String: Any]) {
        guard let x = (dictionary["x"] as? NSNumber)?.doubleValue,
              let y = (dictionary["y"] as? NSNumber)?.doubleValue,
              x.isFinite, y.isFinite
        else { return nil }
        let opacity = (dictionary["opacity"] as? NSNumber)?.doubleValue ?? DesignOverlaySupport.defaultOpacity
        self.init(offset: CGPoint(x: x, y: y), opacity: opacity,
                  scale: .stored(dictionary["scale"] as? String),
                  locked: (dictionary["locked"] as? NSNumber)?.boolValue ?? false)
    }
}

/// Per-display records and the last reference's file name, in the given
/// defaults. Both are this Mac's state rather than preferences, so neither is
/// registered (and neither travels in a settings backup). The image itself
/// lives in the app's container, never in defaults.
struct DesignOverlayMemory {
    let defaults: UserDefaults
    /// Records kept at most; the oldest goes first.
    static let capacity = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(for display: String) -> DesignOverlayDisplayRecord? {
        guard let stored = defaults.dictionary(forKey: DefaultsKey.designOverlayDisplays),
              let entry = stored[display] as? [String: Any]
        else { return nil }
        return DesignOverlayDisplayRecord(dictionary: entry)
    }

    func save(_ record: DesignOverlayDisplayRecord, for display: String, now: Date = Date()) {
        guard !display.isEmpty else { return }
        var stored = defaults.dictionary(forKey: DefaultsKey.designOverlayDisplays) ?? [:]
        var entry = record.dictionary
        entry["updated"] = now.timeIntervalSince1970
        stored[display] = entry
        while stored.count > Self.capacity {
            let oldest = stored.min { lhs, rhs in
                Self.updated(lhs.value) < Self.updated(rhs.value)
            }
            guard let oldest else { break }
            stored.removeValue(forKey: oldest.key)
        }
        defaults.set(stored, forKey: DefaultsKey.designOverlayDisplays)
    }

    private static func updated(_ value: Any) -> Double {
        ((value as? [String: Any])?["updated"] as? NSNumber)?.doubleValue ?? 0
    }

    /// The last reference's file name inside the overlay's folder.
    var lastImageName: String? {
        get {
            guard let name = defaults.string(forKey: DefaultsKey.designOverlayLastImage),
                  DesignOverlayMemory.isSafeName(name) else { return nil }
            return name
        }
        nonmutating set {
            if let newValue, DesignOverlayMemory.isSafeName(newValue) {
                defaults.set(newValue, forKey: DefaultsKey.designOverlayLastImage)
            } else {
                defaults.removeObject(forKey: DefaultsKey.designOverlayLastImage)
            }
        }
    }

    /// A plain file name: never a path that could leave the folder.
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && name != "." && name != ".." && !name.hasPrefix(".")
    }

    /// The name the copied reference gets: `reference.<extension>`, the
    /// extension kept when it is one the overlay reads, otherwise PNG.
    static func referenceName(forExtension ext: String) -> String {
        let lowered = ext.lowercased()
        let kept = ["png", "jpg", "jpeg", "tif", "tiff", "heic", "heif", "webp", "bmp", "psd", "avif"]
        return "reference." + (kept.contains(lowered) ? lowered : "png")
    }
}

// MARK: - Grid

/// A column layout grid, as Figma draws one: columns of equal width with a
/// gutter between them, inside a margin on both sides.
struct DesignOverlayGrid: Hashable {
    let columns: Int
    let gutter: CGFloat
    let margin: CGFloat

    /// The columns across a frame of `size`, in its own coordinates. Empty
    /// when they do not fit.
    func columnFrames(in size: CGSize) -> [CGRect] {
        guard columns > 0, size.width > 0, size.height > 0, gutter >= 0, margin >= 0 else { return [] }
        let count = CGFloat(columns)
        let available = size.width - margin * 2 - gutter * (count - 1)
        guard available > 0 else { return [] }
        let width = available / count
        return (0..<columns).map { index in
            CGRect(x: margin + CGFloat(index) * (width + gutter), y: 0, width: width, height: size.height)
        }
    }

    /// "12 · 24 · 80": columns, gutter and margin.
    var label: String {
        "\(columns) · \(Self.format(gutter)) · \(Self.format(margin))"
    }

    private static func format(_ value: CGFloat) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", Double(value))
    }
}

enum DesignOverlayGridPreset: String, CaseIterable, Identifiable {
    case desktop, laptop, tablet, mobile

    var id: String { rawValue }

    var grid: DesignOverlayGrid {
        switch self {
        case .desktop: return DesignOverlayGrid(columns: 12, gutter: 24, margin: 80)
        case .laptop: return DesignOverlayGrid(columns: 12, gutter: 20, margin: 32)
        case .tablet: return DesignOverlayGrid(columns: 8, gutter: 16, margin: 24)
        case .mobile: return DesignOverlayGrid(columns: 4, gutter: 16, margin: 16)
        }
    }

    static func stored(_ raw: String?) -> DesignOverlayGridPreset {
        raw.flatMap(DesignOverlayGridPreset.init(rawValue:)) ?? .desktop
    }
}
