// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

// Zenith fork: regenerates the brand masters that Tools/MakeIcon.swift reads,
// from the Satu Visual star (Resources/Brand/satuvisual-mark.svg):
//
//   Resources/Brand/logo.png              black mark on transparent, 1024 px
//   Resources/Brand/AppIcon-Default.png   finished macOS app icon, 1024 px
//
// Run from the repository root after changing the mark or the icon design:
//
//   swift Tools/zenith-brand-assets.swift
//
// The outputs are committed, so a normal build never runs this.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let brand = root.appendingPathComponent("Resources/Brand")
let markURL = brand.appendingPathComponent("satuvisual-mark.svg")

guard let mark = NSImage(contentsOf: markURL) else {
    print("could not load \(markURL.path)")
    exit(1)
}

// MARK: - Design

/// macOS icon grid on a 1024 canvas: the body is 824 pt square, centered.
let canvas: CGFloat = 1024
let body: CGFloat = 824
/// Superellipse exponent for the body outline. Close to the continuous-corner
/// shape of system icons; a plain rounded rectangle reads boxier at large sizes.
let squircleExponent: CGFloat = 5
/// Mark size relative to the body. The star is square, so it needs less of the
/// body than the wide upstream mark did to carry the same visual weight.
let markScale: CGFloat = 0.5
/// The body's light fill, top to bottom.
let fillTop = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let fillBottom = NSColor(srgbRed: 0.925, green: 0.925, blue: 0.93, alpha: 1)
/// Near-black ink, matching the Satu Visual avatar (#0A0A0A).
let ink = NSColor(srgbRed: 0.039, green: 0.039, blue: 0.039, alpha: 1)

// MARK: - Drawing helpers

func bitmap(_ size: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                     isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}

func render(_ size: Int, _ draw: (CGContext) -> Void) -> Data {
    let rep = bitmap(size)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func squircle(in rect: CGRect, exponent n: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = a * copysign(pow(abs(c), 2 / n), c)
        let y = b * copysign(pow(abs(s), 2 / n), s)
        let point = CGPoint(x: rect.midX + x, y: rect.midY + y)
        i == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

/// The mark tinted with `color`, drawn into `rect`.
func drawMark(in rect: CGRect, color: NSColor) {
    let tinted = NSImage(size: rect.size, flipped: false) { bounds in
        mark.draw(in: bounds)
        color.set()
        bounds.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: rect)
}

// MARK: - logo.png

let logo = render(Int(canvas)) { _ in
    let side = canvas * 0.8
    drawMark(in: CGRect(x: (canvas - side) / 2, y: (canvas - side) / 2, width: side, height: side),
             color: .black)
}
try logo.write(to: brand.appendingPathComponent("logo.png"))

// MARK: - AppIcon-Default.png

let icon = render(Int(canvas)) { cg in
    let rect = CGRect(x: (canvas - body) / 2, y: (canvas - body) / 2, width: body, height: body)
    let outline = squircle(in: rect, exponent: squircleExponent)

    // Soft drop shadow under the body, as on system icons.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 28,
                 color: NSColor(white: 0, alpha: 0.28).cgColor)
    cg.addPath(outline)
    cg.setFillColor(fillBottom.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Body: a gentle top-to-bottom light gradient.
    cg.saveGState()
    cg.addPath(outline)
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [fillTop.cgColor, fillBottom.cgColor] as CFArray,
                              locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY),
                          end: CGPoint(x: 0, y: rect.minY), options: [])
    cg.restoreGState()

    // Hairline edge so the white body holds its shape on white backgrounds.
    cg.saveGState()
    cg.addPath(outline)
    cg.setStrokeColor(NSColor(white: 0, alpha: 0.08).cgColor)
    cg.setLineWidth(2)
    cg.strokePath()
    cg.restoreGState()

    let side = body * markScale
    drawMark(in: CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side),
             color: ink)
}
try icon.write(to: brand.appendingPathComponent("AppIcon-Default.png"))

print("wrote logo.png and AppIcon-Default.png in \(brand.path)")
