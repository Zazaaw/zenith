// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// The Satu Visual star, from logo-satu-visual.svg (the path make-icon.swift
/// draws), fitted into the shorter side and centred. Fill it even-odd: the
/// small X at its heart is a hole.
struct StarShape: Shape {
    private static let size: CGFloat = 203.603
    private static let d = "M115.551 68.1172L163.717 19.9512L183.449 39.6826L135.08 88.0518H203.603V115.956H135.485L183.651 164.122L163.92 183.854L115.551 135.484V203.603H87.6465V135.485L39.4805 183.651L19.749 163.92L67.7119 115.956H0V88.0518H68.1172L19.9512 39.8857L39.6826 20.1533L87.6465 68.1172V0H115.551V68.1172ZM102.168 93.5625L86.2012 77.5957L78.3271 85.4707L94.2939 101.437L78.3271 117.404L86.2012 125.278L102.168 109.311L118.136 125.278L126.01 117.404L110.042 101.437L126.01 85.4707L118.136 77.5957L102.168 93.5625Z"

    /// Parsed once: the absolute M, L, H, V and Z commands the logo uses.
    private static let unit: Path = {
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
        var path = Path()
        var i = 0
        var point = CGPoint.zero
        var command = ""
        func next() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if tokens[i].first?.isLetter == true { command = tokens[i]; i += 1 }
            switch command {
            case "M": point = CGPoint(x: next(), y: next()); path.move(to: point); command = "L"
            case "L": point = CGPoint(x: next(), y: next()); path.addLine(to: point)
            case "H": point.x = next(); path.addLine(to: point)
            case "V": point.y = next(); path.addLine(to: point)
            case "Z": path.closeSubpath()
            default: i += 1
            }
        }
        return path
    }()

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let scale = side / Self.size
        return Self.unit.applying(CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)))
    }
}
