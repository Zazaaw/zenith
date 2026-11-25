// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

// Draws Pocket's app icon: the Satu Visual eight-armed star in white on
// black, full bleed (iOS cuts the squircle itself).
// Usage: swift Pocket/Tools/make-icon.swift <out.png>

import AppKit

/// The star from logo-satu-visual.svg (its first path, a 203.6-point square).
let star = "M115.551 68.1172L163.717 19.9512L183.449 39.6826L135.08 88.0518H203.603V115.956H135.485L183.651 164.122L163.92 183.854L115.551 135.484V203.603H87.6465V135.485L39.4805 183.651L19.749 163.92L67.7119 115.956H0V88.0518H68.1172L19.9512 39.8857L39.6826 20.1533L87.6465 68.1172V0H115.551V68.1172ZM102.168 93.5625L86.2012 77.5957L78.3271 85.4707L94.2939 101.437L78.3271 117.404L86.2012 125.278L102.168 109.311L118.136 125.278L126.01 117.404L110.042 101.437L126.01 85.4707L118.136 77.5957L102.168 93.5625Z"
let starSize: CGFloat = 203.603

/// Reads the absolute M, L, H, V and Z commands the logo uses.
func path(_ d: String) -> CGPath {
    var tokens: [String] = []
    var number = ""
    for c in d {
        if c.isLetter {
            if !number.isEmpty { tokens.append(number); number = "" }
            tokens.append(String(c))
        } else if c == " " || c == "," {
            if !number.isEmpty { tokens.append(number); number = "" }
        } else {
            number.append(c)
        }
    }
    if !number.isEmpty { tokens.append(number) }
    let path = CGMutablePath()
    var i = 0
    var point = CGPoint.zero
    var command = ""
    func next() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i])!) }
    while i < tokens.count {
        if tokens[i].first!.isLetter { command = tokens[i]; i += 1 }
        switch command {
        case "M": point = CGPoint(x: next(), y: next()); path.move(to: point); command = "L"
        case "L": point = CGPoint(x: next(), y: next()); path.addLine(to: point)
        case "H": point.x = next(); path.addLine(to: point)
        case "V": point.y = next(); path.addLine(to: point)
        case "Z": path.closeSubpath()
        default: fatalError("unsupported command \(command)")
        }
    }
    return path
}

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(gray: 0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
let side = CGFloat(size) * 0.5
var transform = CGAffineTransform(translationX: (CGFloat(size) - side) / 2, y: (CGFloat(size) + side) / 2)
    .scaledBy(x: side / starSize, y: -side / starSize)
context.addPath(path(star).copy(using: &transform)!)
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fillPath(using: .evenOdd)
let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
