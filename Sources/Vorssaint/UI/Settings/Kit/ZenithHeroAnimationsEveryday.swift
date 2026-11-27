// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the hero animations of the Everyday and Devices pages, beside
// the kit's own in ZenithHeroAnimations.swift and under the same rules: a
// few shapes drawn from `context.t`, loops of 2 or 4 seconds, and a still
// frame at `t == 1.1` that reads on its own.

// MARK: - Clipboard

/// Clipboard: copied snippets slide out of the board and pile up beside it.
struct ZenithClipboardHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 4, offset: Double(k) / 3)
                let rise = ZenithKitEase.smooth(p / 0.6)
                let fade = p < 0.75 ? 1 : 1 - (p - 0.75) / 0.25
                ZenithHeroSnippetCard(lines: 2 + k % 2, dark: context.dark)
                    .rotationEffect(.degrees(8 - 6 * rise))
                    .offset(x: 30 + 34 * rise, y: 30 - 70 * rise)
                    .opacity(fade * min(1, p / 0.12))
            }
            context.icon.offset(y: -2 * (ZenithKitEase.pulse(t, period: 4) - 0.5))
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithClipboardHeroArt {
    static var clipboard: Self { .init() }
}

/// A slip of copied text: a small card with grey lines.
struct ZenithHeroSnippetCard: View {
    var lines = 2
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<lines, id: \.self) { line in
                Capsule().fill(Color.black.opacity(0.28)).frame(width: line == lines - 1 ? 18 : 30, height: 3.5)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white))
        .shadow(color: .black.opacity(dark ? 0.45 : 0.18), radius: 3, y: 2)
    }
}

// MARK: - Finder Tools

/// Finder Tools: a file is cut (its outline goes dashed), crosses over the
/// icon and lands in the folder on the other side.
struct ZenithFinderToolsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let cut = p > 0.12 && p < 0.8
        let move = ZenithKitEase.smooth((p - 0.3) / 0.35)
        let land = ZenithKitEase.bounceIn((p - 0.62) / 0.2)
        let fade = p < 0.85 ? 1 : 1 - (p - 0.85) / 0.15
        ZStack {
            context.icon
            Image(systemName: "folder.fill")
                .font(.system(size: 24))
                .foregroundStyle(context.tint.light.color.opacity(0.9))
                .scaleEffect(1 + 0.12 * land * (1 - land))
                .offset(x: 66, y: 46)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 20, height: 26)
                .overlay(Image(systemName: "doc.text").font(.system(size: 10, weight: .bold)).foregroundStyle(.gray))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .foregroundStyle(context.tint.light.color)
                    .padding(-4)
                    .opacity(cut ? 1 : 0))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                .offset(x: -66 + 132 * move, y: 40 - 70 * sin(move * .pi) + 6 * land)
                .scaleEffect(1 - 0.25 * land)
                .opacity(fade * min(1, p / 0.08))
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithFinderToolsHeroArt {
    static var finderTools: Self { .init() }
}

// MARK: - Media Tools

/// Media Tools: the frame's corners close in as a file is compressed, and
/// its size falls.
struct ZenithMediaToolsHeroArt: ZenithHeroAnimation {
    private static let sizes = ["48 MB", "31 MB", "17 MB", "6 MB"]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let squeeze = ZenithKitEase.smooth(p / 0.7)
        let step = min(Self.sizes.count - 1, Int(squeeze * Double(Self.sizes.count)))
        let side = 150 - 40 * squeeze
        ZStack {
            ForEach(0..<4, id: \.self) { corner in
                ZenithHeroCorner()
                    .stroke(context.tint.light.color.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(Double(corner) * 90))
                    .offset(x: (corner == 0 || corner == 3 ? -1 : 1) * side / 2,
                            y: (corner < 2 ? -1 : 1) * side / 2)
            }
            context.icon.scaleEffect(1 - 0.06 * squeeze)
            Text(verbatim: Self.sizes[step])
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(ZenithStatus.success.opacity(0.9)))
                .offset(x: 44, y: 48)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMediaToolsHeroArt {
    static var mediaTools: Self { .init() }
}

/// The top-left corner of a frame; rotate it for the others.
struct ZenithHeroCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - URL Cleaner

/// URL Cleaner: a link sits under the icon, and its tracking tail breaks off
/// and falls away.
struct ZenithURLCleanerHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let drop = ZenithKitEase.smooth((p - 0.35) / 0.4)
        let back = p > 0.9 ? (p - 0.9) / 0.1 : 0
        ZStack {
            context.icon.offset(y: -16)
            HStack(spacing: 0) {
                Text(verbatim: "zenith.app/post")
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.leading, 9)
                    .padding(.trailing, drop > 0.05 ? 9 : 2)
                Text(verbatim: "?utm_source=…")
                    .foregroundStyle(ZenithStatus.error)
                    .padding(.trailing, 8)
                    .offset(x: 10 * drop, y: 36 * drop)
                    .rotationEffect(.degrees(14 * drop))
                    .opacity((1 - drop) + back)
            }
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
            .fixedSize()
            .offset(y: 56)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithURLCleanerHeroArt {
    static var urlCleaner: Self { .init() }
}

// MARK: - Text Snippets

/// Text Snippets: a short trigger is typed, then grows into a paragraph.
struct ZenithTextSnippetsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let typed = min(4, Int(p / 0.07))
        let grow = ZenithKitEase.smooth((p - 0.32) / 0.35)
        let fade = p < 0.88 ? 1 : 1 - (p - 0.88) / 0.12
        ZStack {
            context.icon.offset(x: -26, y: -10)
            Text(verbatim: String(";sig".prefix(typed)) + (typed < 4 ? "▏" : ""))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(context.tint.light.color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .fixedSize()
                .offset(x: -26, y: 52)
                .opacity(1 - grow)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<3, id: \.self) { line in
                    let reach = ZenithKitEase.smooth(grow * 3 - Double(line))
                    Capsule().fill(Color.primary.opacity(0.55))
                        .frame(width: (line == 2 ? 34 : 56) * reach, height: 4)
                }
            }
            .frame(width: 60, alignment: .leading)
            .offset(x: 52, y: 40)
            .opacity(fade)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithTextSnippetsHeroArt {
    static var textSnippets: Self { .init() }
}

// MARK: - iPhone & Watch

/// iPhone & Watch: the Mac's state travels out to the phone and the Watch.
struct ZenithPocketHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(0..<2, id: \.self) { side in
                let x: CGFloat = side == 0 ? -72 : 72
                let y: CGFloat = side == 0 ? 34 : 40
                ForEach(0..<3, id: \.self) { k in
                    let p = ZenithKitEase.phase(t, period: 2, offset: Double(k) / 3 + Double(side) * 0.5)
                    Circle()
                        .fill(context.tint.light.color.opacity(0.85 * sin(p * .pi)))
                        .frame(width: 5, height: 5)
                        .offset(x: x * CGFloat(0.35 + 0.5 * p), y: y * CGFloat(0.35 + 0.5 * p))
                }
                Image(systemName: side == 0 ? "iphone" : "applewatch")
                    .font(.system(size: side == 0 ? 28 : 24, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.8))
                    .offset(x: x, y: y)
                    .offset(y: -2 * ZenithKitEase.pulse(t + Double(side), period: 2))
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithPocketHeroArt {
    static var pocket: Self { .init() }
}

// MARK: - iPhone Remote

/// iPhone Remote: the phone sends a signal, and the Mac's padlock snaps shut.
struct ZenithRemoteHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let p = ZenithKitEase.phase(t, period: 2)
        let snap = ZenithKitEase.bounceIn((p - 0.55) / 0.25)
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let q = ZenithKitEase.phase(t, period: 2, offset: -Double(k) * 0.12)
                Circle()
                    .trim(from: 0.58, to: 0.92)
                    .stroke(context.tint.light.color.opacity(0.7 * (1 - q)),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 40 + 70 * q, height: 40 + 70 * q)
                    .offset(x: -58, y: 50)
            }
            Image(systemName: "iphone")
                .font(.system(size: 22))
                .foregroundStyle(Color.primary.opacity(0.8))
                .offset(x: -62, y: 52)
            context.icon
            Image(systemName: snap > 0.5 ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(snap > 0.5 ? ZenithStatus.success : Color.gray))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(0.9 + 0.1 * snap)
                .offset(x: 38, y: 38)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithRemoteHeroArt {
    static var remote: Self { .init() }
}

// MARK: - Face Unlock

/// Face Unlock: the Face ID frame, a scan line passing down the face, then a tick.
struct ZenithFaceUnlockHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let scan = ZenithKitEase.smooth(p / 0.55)
        let done = ZenithKitEase.bounceIn((p - 0.6) / 0.2)
        let side: CGFloat = 132
        ZStack {
            ForEach(0..<4, id: \.self) { corner in
                ZenithHeroCorner()
                    .stroke((done > 0.5 ? ZenithStatus.success : context.tint.light.color).opacity(0.9),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(Double(corner) * 90))
                    .offset(x: (corner == 0 || corner == 3 ? -1 : 1) * (side / 2 - 11),
                            y: (corner < 2 ? -1 : 1) * (side / 2 - 11))
            }
            context.icon
            Capsule()
                .fill(LinearGradient(colors: [.clear, context.tint.light.color, .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: side - 24, height: 2.5)
                .shadow(color: context.tint.light.color, radius: 4)
                .offset(y: -side / 2 + 14 + (side - 28) * scan)
                .opacity(p < 0.58 ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ZenithStatus.success))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(done)
                .offset(x: 40, y: 40)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithFaceUnlockHeroArt {
    static var faceUnlock: Self { .init() }
}
