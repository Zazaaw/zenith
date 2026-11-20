// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: paints a Beautify composition with CoreGraphics, at the shot's
/// own pixels or scaled down for the live preview. Nothing here touches the
/// main actor, so the editor renders it in a detached task.
enum ScreenshotBeautifyRenderer {
    struct Input: Sendable {
        /// The flattened capture (marks and watermark included), or a reduced
        /// copy of it for the preview.
        let shot: CGImage
        /// The full capture's pixel size, which the layout is measured from.
        let shotPixels: CGSize
        /// The capture's pixels per point.
        let scale: CGFloat
        let style: ScreenshotBeautifyStyle
        /// Already blurred; nil paints the fallback gradient instead.
        let wallpaper: CGImage?
        /// Rounding the capture already carries in its alpha (a window's own
        /// corners), in full-size pixels, so the shadow follows it.
        var shotCorner: CGFloat = 0
    }

    /// The finished canvas. `outputScale` below 1 renders the same picture
    /// smaller for the preview; the layout, and so the look, does not change.
    static func render(_ input: Input, outputScale: CGFloat = 1) -> CGImage? {
        let style = input.style.sanitized()
        let layout = ScreenshotBeautifyLayout.make(shotPixels: input.shotPixels, scale: input.scale, style: style)
        let factor = max(min(outputScale, 1), 0.01)
        let width = max(Int((layout.canvas.width * factor).rounded()), 1)
        let height = max(Int((layout.canvas.height * factor).rounded()), 1)
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace(for: input.shot),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.scaleBy(x: CGFloat(width) / layout.canvas.width, y: CGFloat(height) / layout.canvas.height)
        let canvas = CGRect(origin: .zero, size: layout.canvas)
        // The layout measures from the top left; CoreGraphics draws from the bottom left.
        func up(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: layout.canvas.height - rect.maxY, width: rect.width, height: rect.height)
        }

        let backgroundLuminance = drawBackground(style, wallpaper: input.wallpaper, in: context, canvas: canvas)

        let card = up(layout.card)
        let cardPath = continuousRoundedRect(card, radius: layout.cornerRadius)
        if let shadow = layout.shadow {
            let ownCorner = layout.bar == nil ? input.shotCorner * layout.contentScale : 0
            let outline = continuousRoundedRect(card, radius: max(layout.cornerRadius, ownCorner))
            context.saveGState()
            // Only the shadow outside the card is kept, so a translucent shot
            // never shows a dark plate behind it.
            context.addRect(canvas.insetBy(dx: -canvas.width, dy: -canvas.height))
            context.addPath(outline)
            context.clip(using: .evenOdd)
            context.setShadow(offset: CGSize(width: 0, height: -shadow.offset * factor),
                              blur: shadow.blur * factor,
                              color: CGColor(gray: 0, alpha: shadow.alpha))
            context.addPath(outline)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fillPath()
            context.restoreGState()
        }

        context.saveGState()
        context.addPath(cardPath)
        context.clip()
        if let bar = layout.bar {
            drawBar(up(bar), frame: style.frame, lights: layout.lightCenters(scale: input.scale).map {
                CGPoint(x: $0.x, y: layout.canvas.height - $0.y)
            }, unit: max(input.scale, 1) * layout.contentScale, in: context)
        }
        context.draw(input.shot, in: up(layout.shot))
        context.restoreGState()

        if style.frame != .none {
            // A window's fine edge, so a light frame holds its shape on a light background.
            let line = max(input.scale, 1) * layout.contentScale * 0.5
            context.saveGState()
            context.addPath(continuousRoundedRect(card.insetBy(dx: line / 2, dy: line / 2),
                                                  radius: max(layout.cornerRadius - line / 2, 0)))
            context.setLineWidth(line)
            context.setStrokeColor(style.frame == .light
                                   ? CGColor(gray: 0, alpha: 0.14) : CGColor(gray: 1, alpha: 0.12))
            context.strokePath()
            context.restoreGState()
        }

        if let caption = layout.caption {
            drawCaption(style.trimmedCaption, in: up(caption), fontSize: layout.captionFontSize,
                        lightBackground: backgroundLuminance > 0.5, context: context)
        }
        return context.makeImage()
    }

    // MARK: Background

    /// Paints the background and says how light it is, for the caption.
    private static func drawBackground(_ style: ScreenshotBeautifyStyle, wallpaper: CGImage?,
                                       in context: CGContext, canvas: CGRect) -> Double {
        switch style.background {
        case .transparent:
            // Clear exports are mostly placed on light pages.
            return 1
        case .solid:
            let color = ScreenshotBeautifyColor(hex: style.solid) ?? ScreenshotBeautifyColor(red: 0.96, green: 0.96, blue: 0.95)
            context.setFillColor(color.cgColor)
            context.fill(canvas)
            return color.luminance
        case .wallpaper:
            if let wallpaper {
                drawAspectFill(wallpaper, in: canvas, context: context)
                return averageLuminance(of: wallpaper)
            }
            drawGradient(.fallback, in: context, canvas: canvas)
            return ScreenshotBeautifyGradient.fallback.luminance
        case .gradient:
            drawGradient(style.gradient, in: context, canvas: canvas)
            return style.gradient.luminance
        }
    }

    private static func drawGradient(_ gradient: ScreenshotBeautifyGradient, in context: CGContext, canvas: CGRect) {
        let colors = gradient.stops.map(\.cgColor) as CFArray
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let shading = CGGradient(colorsSpace: space, colors: colors, locations: nil)
        else { return }
        context.drawLinearGradient(shading,
                                   start: CGPoint(x: canvas.minX, y: canvas.maxY),
                                   end: CGPoint(x: canvas.maxX, y: canvas.minY),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    private static func drawAspectFill(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0 else { return }
        let scale = max(rect.width / width, rect.height / height)
        let size = CGSize(width: width * scale, height: height * scale)
        context.saveGState()
        context.clip(to: rect)
        context.draw(image, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                       width: size.width, height: size.height))
        context.restoreGState()
    }

    static func averageLuminance(of image: CGImage) -> Double {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return 0.5 }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return ScreenshotBeautifyColor(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255,
                                       blue: Double(pixel[2]) / 255).luminance
    }

    // MARK: Window frame

    private static func drawBar(_ bar: CGRect, frame: ScreenshotBeautifyStyle.WindowFrame, lights: [CGPoint],
                                unit: CGFloat, in context: CGContext) {
        let light = frame == .light
        context.setFillColor(light ? CGColor(srgbRed: 0.925, green: 0.925, blue: 0.925, alpha: 1)
                                   : CGColor(srgbRed: 0.17, green: 0.17, blue: 0.18, alpha: 1))
        context.fill(bar)
        let separator = max(unit * 0.5, 1)
        context.setFillColor(light ? CGColor(gray: 0, alpha: 0.1) : CGColor(gray: 0, alpha: 0.45))
        context.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: separator))

        let fills = [(1.0, 0.373, 0.341), (0.996, 0.737, 0.18), (0.157, 0.784, 0.251)]
        let strokes = [(0.878, 0.267, 0.243), (0.871, 0.631, 0.137), (0.102, 0.671, 0.161)]
        let diameter = ScreenshotBeautifyLayout.lightDiameterPoints * unit
        for (index, center) in lights.enumerated() {
            let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            let fill = fills[index % fills.count]
            let stroke = strokes[index % strokes.count]
            context.setFillColor(CGColor(srgbRed: fill.0, green: fill.1, blue: fill.2, alpha: 1))
            context.fillEllipse(in: rect)
            let line = max(unit * 0.5, 0.5)
            context.setStrokeColor(CGColor(srgbRed: stroke.0, green: stroke.1, blue: stroke.2, alpha: light ? 1 : 0.8))
            context.setLineWidth(line)
            context.strokeEllipse(in: rect.insetBy(dx: line / 2, dy: line / 2))
        }
    }

    // MARK: Caption

    private static func drawCaption(_ text: String, in rect: CGRect, fontSize: CGFloat,
                                    lightBackground: Bool, context: CGContext) {
        guard !text.isEmpty, fontSize > 0 else { return }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let color = lightBackground ? CGColor(gray: 0.08, alpha: 0.72) : CGColor(gray: 1, alpha: 0.84)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let full = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(string: "\u{2026}", attributes: attributes))
        let line = CTLineCreateTruncatedLine(full, Double(rect.width), .end, ellipsis) ?? full
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: rect.midX - width / 2,
                                       y: rect.midY - (ascent - descent) / 2)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: Geometry

    /// A rounded rectangle with Apple's continuous corners: each corner eases
    /// into its edge over about 1.53 radii instead of meeting it at a tangent.
    static func continuousRoundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
        let reach = ScreenshotBeautifyLayout.continuousReach
        let r = min(max(radius, 0), min(rect.width, rect.height) / 2 / reach)
        guard r > 0.01 else { return CGPath(rect: rect, transform: nil) }
        let path = CGMutablePath()
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        // Points along one corner, as offsets from the corner along its two edges.
        let a = reach * r, b = 1.08849323 * r, c = 0.86840689 * r
        let d = 0.63149399 * r, e = 0.07491139 * r, f = 0.37282614 * r, g = 0.16906001 * r
        path.move(to: CGPoint(x: minX + a, y: maxY))
        // Top edge to the top right corner.
        path.addLine(to: CGPoint(x: maxX - a, y: maxY))
        path.addCurve(to: CGPoint(x: maxX - d, y: maxY - e),
                      control1: CGPoint(x: maxX - b, y: maxY), control2: CGPoint(x: maxX - c, y: maxY))
        path.addCurve(to: CGPoint(x: maxX - e, y: maxY - d),
                      control1: CGPoint(x: maxX - f, y: maxY - g), control2: CGPoint(x: maxX - g, y: maxY - f))
        path.addCurve(to: CGPoint(x: maxX, y: maxY - a),
                      control1: CGPoint(x: maxX, y: maxY - c), control2: CGPoint(x: maxX, y: maxY - b))
        // Right edge to the bottom right corner.
        path.addLine(to: CGPoint(x: maxX, y: minY + a))
        path.addCurve(to: CGPoint(x: maxX - e, y: minY + d),
                      control1: CGPoint(x: maxX, y: minY + b), control2: CGPoint(x: maxX, y: minY + c))
        path.addCurve(to: CGPoint(x: maxX - d, y: minY + e),
                      control1: CGPoint(x: maxX - g, y: minY + f), control2: CGPoint(x: maxX - f, y: minY + g))
        path.addCurve(to: CGPoint(x: maxX - a, y: minY),
                      control1: CGPoint(x: maxX - c, y: minY), control2: CGPoint(x: maxX - b, y: minY))
        // Bottom edge to the bottom left corner.
        path.addLine(to: CGPoint(x: minX + a, y: minY))
        path.addCurve(to: CGPoint(x: minX + d, y: minY + e),
                      control1: CGPoint(x: minX + b, y: minY), control2: CGPoint(x: minX + c, y: minY))
        path.addCurve(to: CGPoint(x: minX + e, y: minY + d),
                      control1: CGPoint(x: minX + f, y: minY + g), control2: CGPoint(x: minX + g, y: minY + f))
        path.addCurve(to: CGPoint(x: minX, y: minY + a),
                      control1: CGPoint(x: minX, y: minY + c), control2: CGPoint(x: minX, y: minY + b))
        // Left edge to the top left corner.
        path.addLine(to: CGPoint(x: minX, y: maxY - a))
        path.addCurve(to: CGPoint(x: minX + e, y: maxY - d),
                      control1: CGPoint(x: minX, y: maxY - b), control2: CGPoint(x: minX, y: maxY - c))
        path.addCurve(to: CGPoint(x: minX + d, y: maxY - e),
                      control1: CGPoint(x: minX + g, y: maxY - f), control2: CGPoint(x: minX + f, y: maxY - g))
        path.addCurve(to: CGPoint(x: minX + a, y: maxY),
                      control1: CGPoint(x: minX + c, y: maxY), control2: CGPoint(x: minX + b, y: maxY))
        path.closeSubpath()
        return path
    }

    /// The shot's own colour space when bitmaps can be drawn in it, so a P3
    /// capture keeps its colours, and sRGB otherwise.
    private static func colorSpace(for image: CGImage) -> CGColorSpace {
        if let own = image.colorSpace, own.model == .rgb, own.supportsOutput,
           CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                     space: own, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) != nil {
            return own
        }
        return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    // MARK: Sources

    /// A copy no larger than `maximumSide`, for the preview.
    static func reduced(_ image: CGImage, maximumSide: CGFloat) -> CGImage {
        let longest = CGFloat(max(image.width, image.height))
        guard longest > maximumSide else { return image }
        let factor = maximumSide / longest
        let width = max(Int((CGFloat(image.width) * factor).rounded()), 1)
        let height = max(Int((CGFloat(image.height) * factor).rounded()), 1)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace(for: image),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    private static let blurContext = CIContext(options: [.cacheIntermediates: false])

    /// The desktop picture, small and softly blurred: it only ever sits
    /// behind the shot, so detail would just compete with it.
    static func blurredWallpaper(at url: URL, maximumSide: Int = 1600) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSide,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let input = CIImage(cgImage: image)
        let radius = CGFloat(min(image.width, image.height)) * 0.035
        let blurred = input.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: input.extent)
        return blurContext.createCGImage(blurred, from: input.extent)
    }

    // MARK: Encoding

    /// PNG or JPEG carrying the capture's pixels per point as DPI, like every
    /// other screenshot output.
    static func encode(_ image: CGImage, scale: CGFloat, format: ScreenshotBeautifyStyle.Format) -> Data? {
        guard format == .jpeg else { return ScreenshotRenderer.pngData(from: image, scale: scale) }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let properties = [
            kCGImageDestinationLossyCompressionQuality: 0.92,
            kCGImagePropertyDPIWidth: Double(scale) * 72,
            kCGImagePropertyDPIHeight: Double(scale) * 72,
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
