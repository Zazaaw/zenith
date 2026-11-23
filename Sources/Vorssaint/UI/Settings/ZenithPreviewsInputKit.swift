// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the pieces the mouse, keyboard, files and clipboard pages draw
// their looping previews with (ZenithPreviewsInputMouse.swift and
// ZenithPreviewsInputPages.swift): a stage on a quiet dot grid, keys, a
// mouse, a pointer, small windows, all drawn in SwiftUI from a phase that
// `ZenithPreviewLoop` drives, and sample data only. Plus the jump a click on
// an outlined part makes on a page whose sections have no Settings anchor:
// the page scrolls to the setting and frames it, the way a search lands.

/// Timing helpers for a 0…1 loop phase.
enum ZPI {
    /// Where `phase` is between `start` and `end`, clamped to 0…1.
    static func span(_ phase: Double, _ start: Double, _ end: Double) -> Double {
        min(1, max(0, (phase - start) / max(end - start, 0.0001)))
    }

    /// `span`, eased in and out.
    static func ease(_ phase: Double, _ start: Double, _ end: Double) -> Double {
        let x = span(phase, start, end)
        return x * x * (3 - 2 * x)
    }

    /// 1 between `start` and `end`, faded over `fade` at each edge.
    static func pulse(_ phase: Double, _ start: Double, _ end: Double, fade: Double = 0.04) -> Double {
        min(span(phase, start, start + fade), 1 - span(phase, end - fade, end))
    }

    static let stage = adaptive(light: 0xE9E9EC, dark: 0x1C1C1E)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x2C2C2E)
    static let raised = adaptive(light: 0xF4F4F6, dark: 0x3A3A3C)
    static let ink = Color.primary.opacity(0.78)
    static let line = Color.primary.opacity(0.16)
    static let stroke = Color.primary.opacity(0.22)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

// MARK: - Stage

/// A looping illustration on a dot grid. `content` is laid out in points on a
/// stage `width` wide (its height follows the card's shape, about 200), then
/// scaled to the card, so every picture is drawn at one size.
struct ZPIStage<Content: View>: View {
    var width: CGFloat = 440
    var period: TimeInterval = 3
    var still: Double = 0.5
    @ViewBuilder var content: (Double) -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / width
            ZStack {
                ZPI.stage
                ZenithDotGrid(spacing: 14 * scale, dot: 1.2 * scale)
                ZenithPreviewLoop(period: period, stillPhase: still) { phase in
                    content(phase)
                }
                .frame(width: width, height: geo.size.height / max(scale, 0.01))
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A small label under a part of the picture.
struct ZPILabel: View {
    let text: String
    var lit = false

    init(_ text: String, lit: Bool = false) {
        self.text = text
        self.lit = lit
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(lit ? Color.accentColor : Color.secondary)
            .lineLimit(1)
            .fixedSize()
    }
}

/// A keycap, lit while it is part of what happens, pressed `depth` 0…1.
struct ZPIKey: View {
    let label: String
    var lit = false
    var depth: Double = 0
    var width: CGFloat = 30
    var height: CGFloat = 30
    var fontSize: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Text(label)
            .font(ZenithType.mono(fontSize, weight: .semibold))
            .foregroundStyle(lit ? Color.accentColor : ZPI.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 4)
            .frame(width: width, height: height)
            .background(shape.fill(lit ? Color.accentColor.opacity(0.16) : ZPI.surface))
            .overlay(shape.strokeBorder(lit ? Color.accentColor.opacity(0.75) : ZPI.stroke, lineWidth: 1))
            .background(shape.fill(Color.black.opacity(0.22)).offset(y: 2 * (1 - depth)))
            .offset(y: 2 * depth)
    }
}

/// A chord of keycaps, as the shortcut's caps.
struct ZPIChord: View {
    let caps: [String]
    var lit = true
    var depth: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(caps.enumerated()), id: \.offset) { _, cap in
                ZPIKey(label: cap, lit: lit, depth: depth, width: cap.count > 2 ? CGFloat(cap.count) * 8 + 16 : 30)
            }
        }
    }
}

/// A capsule tag: what happened, in mono.
struct ZPIChip: View {
    let text: String
    var symbol: String?
    var lit = true

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(ZenithType.mono(10.5, weight: .medium)).lineLimit(1)
        }
        .fixedSize()
        .foregroundStyle(lit ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(lit ? Color.accentColor.opacity(0.14) : ZPI.surface))
        .overlay(Capsule().strokeBorder(lit ? Color.accentColor.opacity(0.4) : ZPI.stroke))
    }
}

/// The pointer.
struct ZPIPointer: View {
    var pressed = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: "cursorarrow")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 0.6)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            if pressed {
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .offset(x: -7, y: -7)
            }
        }
        .frame(width: 20, height: 22, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// A small window with its traffic lights, content clipped under the bar.
struct ZPIWindow<Content: View>: View {
    var width: CGFloat
    var height: CGFloat
    var active = true
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(active ? [Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18),
                                        Color(red: 0.16, green: 0.79, blue: 0.25)][index] : ZPI.line)
                        .frame(width: 8, height: 8)
                }
                if let title {
                    Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .lineLimit(1).padding(.leading, 6)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
            Color.clear
                .overlay(alignment: .topLeading) { content() }
                .clipped()
        }
        .frame(width: width, height: height)
        .background(shape.fill(ZPI.surface))
        .overlay(shape.strokeBorder(active ? ZPI.stroke : ZPI.line))
        .clipShape(shape)
        .shadow(color: .black.opacity(active ? 0.28 : 0.12), radius: active ? 8 : 3, y: 3)
    }
}

/// Lines of text on a page, moved by `offset` (in points, wrapping).
struct ZPIPageLines: View {
    var offset = CGSize.zero
    var count = 14
    var spacing: CGFloat = 13
    var marked: Int?

    private static let widths: [CGFloat] = [0.86, 0.62, 0.92, 0.48, 0.78, 0.7, 0.9, 0.55, 0.82, 0.66, 0.74, 0.5, 0.88, 0.6]

    var body: some View {
        GeometryReader { geo in
            let total = spacing * CGFloat(count)
            let wrapped = offset.height.truncatingRemainder(dividingBy: total)
            let shift = wrapped < 0 ? wrapped + total : wrapped
            ForEach(0..<(count * 2), id: \.self) { index in
                let width = Self.widths[index % Self.widths.count] * (geo.size.width - 24)
                Capsule()
                    .fill(marked == index % count ? Color.accentColor.opacity(0.7) : ZPI.line)
                    .frame(width: width, height: 5)
                    .position(x: 12 + width / 2 + offset.width, y: 10 + CGFloat(index) * spacing - shift)
            }
        }
    }
}

/// A mouse seen from above: the wheel's ridges roll with `wheel`, and a
/// button, the wheel or the side button can be lit.
struct ZPIMouse: View {
    var wheel: Double = 0
    var wheelLit = false
    var leftLit = false
    var sideLit = false
    var wheelPressed = false

    var body: some View {
        let shell = Capsule(style: .circular)
        ZStack(alignment: .top) {
            shell.fill(ZPI.surface)
            // The left button, lit by a fill clipped to the shell.
            Rectangle()
                .fill(Color.accentColor.opacity(leftLit ? 0.35 : 0))
                .frame(width: 35, height: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(shell)
            Rectangle().fill(ZPI.stroke).frame(width: 1.5, height: 46)
            Rectangle().fill(ZPI.stroke).frame(height: 1.5).padding(.top, 46)
            wheelView.padding(.top, 13)
            Capsule()
                .fill(sideLit ? Color.accentColor : ZPI.stroke)
                .frame(width: 5, height: 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 58)
                .offset(x: -2)
        }
        .frame(width: 70, height: 108)
        .overlay(shell.strokeBorder(Color.primary.opacity(0.5), lineWidth: 2))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }

    private var wheelView: some View {
        let shape = Capsule()
        return ZStack {
            shape.fill(wheelLit ? Color.accentColor : ZPI.raised)
            ForEach(0..<4, id: \.self) { index in
                let y = (CGFloat(index) * 6 + CGFloat(wheel.truncatingRemainder(dividingBy: 1)) * 6)
                    .truncatingRemainder(dividingBy: 24) - 12
                Rectangle()
                    .fill(wheelLit ? Color.white.opacity(0.7) : ZPI.stroke)
                    .frame(width: 6, height: 1.5)
                    .offset(y: y)
            }
        }
        .frame(width: 10, height: 26)
        .clipShape(shape)
        .overlay(shape.strokeBorder(wheelLit ? Color.accentColor : ZPI.stroke))
        .scaleEffect(wheelPressed ? 0.88 : 1)
    }
}

/// A trackpad with fingers resting on it, `tap` 0…1 pressing them down.
struct ZPITrackpad: View {
    var fingers = 3
    var tap: Double = 0
    var lit = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack {
            shape.fill(ZPI.surface)
            HStack(spacing: 10) {
                ForEach(0..<fingers, id: \.self) { _ in
                    Circle()
                        .fill(lit ? Color.accentColor.opacity(0.35 + 0.5 * tap) : ZPI.line)
                        .frame(width: 18 - 3 * tap, height: 18 - 3 * tap)
                        .overlay(Circle().strokeBorder(lit ? Color.accentColor : ZPI.stroke))
                }
            }
        }
        .frame(width: 120, height: 84)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.4), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
    }
}

/// An app's icon as a rounded square with a symbol.
struct ZPIAppIcon: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 34

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.48, weight: .semibold)).foregroundStyle(.white))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}

/// A document or folder icon with its name under it.
struct ZPIFile: View {
    let name: String
    var symbol = "doc.fill"
    var selected = false
    var dimmed = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(symbol.hasPrefix("folder") ? Color.accentColor.opacity(0.8) : Color.primary.opacity(0.55))
            Text(name)
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(selected ? Color.accentColor : .clear))
                .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.8))
        }
        .opacity(dimmed ? 0.45 : 1)
    }
}

// MARK: - Form rows

/// The preview card at the top of a grouped Form, as the footer of a Section
/// with no rows: no box is drawn behind it, so it reads as the same card as
/// on the pages that are not Forms, and the next section keeps its heading.
/// (As a header, the next section's heading lost its weight.)
struct ZenithPreviewFormSection<Card: View>: View {
    @ViewBuilder var card: () -> Card

    var body: some View {
        Section {
            EmptyView()
        } footer: {
            card()
                .multilineTextAlignment(.leading)
                .textCase(nil)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Jumping to a setting

/// Scrolls the page to a setting marked with `zenithPreviewTarget` and frames
/// it for a moment.
struct ZenithPreviewJump {
    fileprivate var perform: (String) -> Void = { _ in }
    func callAsFunction(_ target: String) { perform(target) }
}

private struct ZenithPreviewJumpKey: EnvironmentKey {
    static let defaultValue = ZenithPreviewJump()
}

extension EnvironmentValues {
    var zenithPreviewJump: ZenithPreviewJump {
        get { self[ZenithPreviewJumpKey.self] }
        set { self[ZenithPreviewJumpKey.self] = newValue }
    }
}

private struct ZenithPreviewTargetKey: PreferenceKey {
    static var defaultValue: [String: [Anchor<CGRect>]] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        for (id, bounds) in nextValue() { value[id, default: []].append(contentsOf: bounds) }
    }
}

extension View {
    /// Marks a setting a preview part leads to. On a grouped Form's Section
    /// it marks every row, and the frame takes them all in.
    func zenithPreviewTarget(_ id: String) -> some View {
        self.id(id)
            .anchorPreference(key: ZenithPreviewTargetKey.self, value: .bounds) { [id: [$0]] }
    }

    /// Gives the page's preview card its jump: scroll to a target, centered,
    /// and frame it as Settings search does.
    func zenithPreviewJumps() -> some View {
        modifier(ZenithPreviewJumpsModifier())
    }
}

private struct ZenithPreviewJumpsModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var target: String?
    @State private var framed = false
    @State private var token = UUID()

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .environment(\.zenithPreviewJump, ZenithPreviewJump { jump(to: $0, proxy: proxy) })
                .overlayPreferenceValue(ZenithPreviewTargetKey.self) { targets in
                    GeometryReader { geo in
                        if let target, let bounds = targets[target], let first = bounds.first {
                            let rect = bounds.dropFirst().reduce(geo[first]) { $0.union(geo[$1]) }.insetBy(dx: -6, dy: -6)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 2)
                                        .shadow(color: Color.accentColor.opacity(0.5), radius: 14)
                                }
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .opacity(framed ? 1 : 0)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
        }
    }

    private func jump(to id: String, proxy: ScrollViewProxy) {
        let current = UUID()
        token = current
        target = id
        if reduceMotion {
            proxy.scrollTo(id, anchor: .center)
            framed = true
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: .center)
                framed = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard token == current else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { framed = false }
        }
    }
}
