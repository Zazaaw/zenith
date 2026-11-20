// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the capsule notice as ZenithNoticeCenter presents it. The
// shape springs from the island's outline to the capsule; the content blurs
// in once the shape has mostly grown, piece by piece, and out in reverse.

struct ZenithNoticeRoot: View {
    @ObservedObject var center: ZenithNoticeCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let outline = center.outline
        let shape = ZenithNoticeShape(hanging: outline.hanging, shoulder: outline.shoulder, radius: outline.radius)
        ZStack(alignment: .topLeading) {
            if let notice = center.notice {
                ZStack(alignment: .topLeading) {
                    shape
                        .fill(Color.black)
                        .overlay {
                            // A floating pill keeps a hairline on light wallpapers;
                            // a hanging one meets the screen's black edge.
                            if !outline.hanging { shape.stroke(Color.white.opacity(0.12), lineWidth: 1) }
                        }
                        .frame(width: outline.rect.width, height: outline.rect.height)
                        .offset(x: outline.rect.minX, y: outline.rect.minY)
                    ZenithNoticeContent(notice: notice, shown: center.contentShown, reduceMotion: reduceMotion,
                                        thumbnail: thumbnail(for: notice))
                        .id(center.revision)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
                        .frame(width: center.row.width, height: center.row.height)
                        .offset(x: center.row.minX, y: center.row.minY)
                }
                .frame(width: center.panelSize.width, height: center.panelSize.height, alignment: .topLeading)
                .mask(alignment: .topLeading) {
                    shape
                        .frame(width: outline.rect.width, height: outline.rect.height)
                        .offset(x: outline.rect.minX, y: outline.rect.minY)
                }
                .contentShape(ZenithNoticeHitShape(outline: outline))
                .onTapGesture { center.activate() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(notice.accessibilityText)
                .accessibilityAddTraits(notice.action == .none ? [] : .isButton)
                .accessibilityAction { center.activate() }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: center.revision)
            }
        }
        .frame(width: center.panelSize.width, height: center.panelSize.height, alignment: .topLeading)
        .opacity(center.surfaceOpacity)
        .environment(\.colorScheme, .dark)
    }

    private func thumbnail(for notice: ZenithNotice) -> NSImage? {
        guard case .file(let url) = notice.glyph else { return nil }
        return center.thumbnails[url]
    }
}

/// The island's outline grown into a capsule. Floating, it is a pill whose
/// ends are half its height; hanging from the top edge, it keeps the island's
/// shoulders at the top and rounds its bottom by `radius`.
struct ZenithNoticeShape: Shape {
    var hanging: Bool
    var shoulder: CGFloat
    var radius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulder, radius) }
        set { shoulder = newValue.first; radius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        guard hanging else {
            let corner = min(max(0, radius), rect.height / 2, rect.width / 2)
            return Path(roundedRect: rect, cornerRadius: corner, style: .circular)
        }
        let shoulder = min(max(0, self.shoulder), rect.width / 2, rect.height)
        let bottom = min(max(0, radius), rect.height - shoulder, (rect.width - shoulder * 2) / 2)
        let tangent: CGFloat = 0.55228475
        let (w, h) = (rect.width, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.minX + w - shoulder, y: rect.minY + shoulder),
                      control1: CGPoint(x: rect.minX + w - shoulder * tangent, y: rect.minY),
                      control2: CGPoint(x: rect.minX + w - shoulder, y: rect.minY + shoulder * (1 - tangent)))
        path.addLine(to: CGPoint(x: rect.minX + w - shoulder, y: rect.minY + h - bottom))
        path.addCurve(to: CGPoint(x: rect.minX + w - shoulder - bottom, y: rect.minY + h),
                      control1: CGPoint(x: rect.minX + w - shoulder, y: rect.minY + h - bottom * (1 - tangent)),
                      control2: CGPoint(x: rect.minX + w - shoulder - bottom * (1 - tangent), y: rect.minY + h))
        path.addLine(to: CGPoint(x: rect.minX + shoulder + bottom, y: rect.minY + h))
        path.addCurve(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + h - bottom),
                      control1: CGPoint(x: rect.minX + shoulder + bottom * (1 - tangent), y: rect.minY + h),
                      control2: CGPoint(x: rect.minX + shoulder, y: rect.minY + h - bottom * (1 - tangent)))
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                      control1: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder * (1 - tangent)),
                      control2: CGPoint(x: rect.minX + shoulder * tangent, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Where the capsule takes clicks: its outline where it stands in the window.
private struct ZenithNoticeHitShape: Shape {
    let outline: ZenithNoticeOutline

    func path(in _: CGRect) -> Path {
        ZenithNoticeShape(hanging: outline.hanging, shoulder: outline.shoulder, radius: outline.radius)
            .path(in: outline.rect)
    }
}

extension ZenithNotice.Tone {
    var color: Color {
        switch self {
        case .red: return ZenithStatus.error
        case .amber: return ZenithStatus.warning
        case .green: return ZenithStatus.success
        case .accent: return Color(nsColor: .controlAccentColor)
        case .white: return .white.opacity(0.95)
        }
    }
}

/// One row: glyph, title over subtitle, accessory. Each piece blurs in after
/// the one before it.
private struct ZenithNoticeContent: View {
    let notice: ZenithNotice
    let shown: Bool
    let reduceMotion: Bool
    let thumbnail: NSImage?

    private typealias Layout = ZenithNoticeLayout

    var body: some View {
        let pieces = notice.glyph == .none ? 3 : 4
        HStack(spacing: Layout.spacing) {
            if notice.glyph != .none {
                glyph
                    .frame(width: Layout.glyph, height: Layout.glyph)
                    .zenithNoticeReveal(shown, index: 0, count: pieces, reduceMotion: reduceMotion)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(notice.title)
                    .font(.system(size: Layout.titleSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(notice.kind == .download ? .middle : .tail)
                    .zenithNoticeReveal(shown, index: pieces - 3, count: pieces, reduceMotion: reduceMotion)
                Text(notice.subtitle)
                    .font(.system(size: Layout.subtitleSize))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .zenithNoticeReveal(shown, index: pieces - 2, count: pieces, reduceMotion: reduceMotion)
            }
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory
                .zenithNoticeReveal(shown, index: pieces - 1, count: pieces, reduceMotion: reduceMotion)
        }
        .padding(.leading, Layout.inset + (notice.glyph == .none ? Layout.endInset : 0))
        .padding(.trailing, Layout.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var glyph: some View {
        switch notice.glyph {
        case .none:
            EmptyView()
        case let .symbol(name, tone):
            Image(systemName: name)
                .font(.system(size: 19, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tone.color)
        case .file(let url):
            ZenithNoticeThumbnail(url: url, image: thumbnail)
        }
    }

    @ViewBuilder private var accessory: some View {
        switch notice.accessory {
        case .none:
            EmptyView()
        case let .ring(percent, tone):
            ZenithNoticeRing(percent: percent, color: tone.color, shown: shown, reduceMotion: reduceMotion)
        case .lowPower(let on):
            ZenithNoticeLowPowerSwitch(on: on, reduceMotion: reduceMotion)
        case .checkmark:
            ZenithNoticeCheckmark(shown: shown, reduceMotion: reduceMotion)
        }
    }
}

private extension View {
    /// Blur 10 → 0 with opacity, 40 ms after the piece before; out in reverse.
    /// Reduce Motion fades only.
    func zenithNoticeReveal(_ shown: Bool, index: Int, count: Int, reduceMotion: Bool) -> some View {
        let order = shown ? index : max(0, count - 1 - index)
        let step = shown ? ZenithNoticeTiming.stagger : ZenithNoticeTiming.stagger * 0.6
        let duration = shown ? ZenithNoticeTiming.contentDuration : ZenithNoticeTiming.contentOut * 0.7
        return blur(radius: shown || reduceMotion ? 0 : ZenithNoticeTiming.blurRadius)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: ZenithNoticeTiming.fade)
                       : .easeOut(duration: duration).delay(Double(order) * step), value: shown)
    }
}

/// The file's QuickLook thumbnail, its Finder icon until one is ready.
private struct ZenithNoticeThumbnail: View {
    let url: URL
    let image: NSImage?

    var body: some View {
        let side = ZenithNoticeLayout.glyph + 2
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    }
                    .transition(.opacity)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: side, height: side)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: image != nil)
    }
}

/// A ring filled to the percentage, which draws as the content arrives.
private struct ZenithNoticeRing: View {
    let percent: Int
    let color: Color
    let shown: Bool
    let reduceMotion: Bool

    var body: some View {
        let fraction = CGFloat(ZenithNoticeFormat.clamped(percent)) / 100
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: shown || reduceMotion ? fraction : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(shown ? 0.16 : 0), value: shown)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: percent)
            Text("\(ZenithNoticeFormat.clamped(percent))")
                .font(.system(size: percent >= 100 ? 9.5 : 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(1.5)
        .frame(width: ZenithNoticeLayout.ring, height: ZenithNoticeLayout.ring)
    }
}

/// Low Power Mode as a switch-like pill holding a battery: red and off, or
/// amber and on, as macOS colours the battery in that mode.
private struct ZenithNoticeLowPowerSwitch: View {
    let on: Bool
    let reduceMotion: Bool

    var body: some View {
        let color = on ? ZenithStatus.warning : ZenithStatus.error
        let width = ZenithNoticeLayout.lowPowerWidth, height = ZenithNoticeLayout.lowPowerHeight
        let knob = height - 6
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(color.opacity(0.28))
            Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1)
            Image(systemName: on ? "battery.25percent" : "battery.0percent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: on ? .leading : .trailing)
                .padding(.horizontal, 6)
            Circle()
                .fill(color)
                .overlay { Capsule().fill(.white.opacity(0.9)).frame(width: 2, height: knob * 0.42) }
                .frame(width: knob, height: knob)
                .padding(3)
                .shadow(color: color.opacity(0.6), radius: 4)
        }
        .frame(width: width, height: height)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: on)
    }
}

/// A checkmark inside a circle, drawn with `trim` once the content is in.
private struct ZenithNoticeCheckmark: View {
    let shown: Bool
    let reduceMotion: Bool

    var body: some View {
        let drawn = shown || reduceMotion
        ZStack {
            Circle()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(ZenithStatus.success, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(shown ? 0.12 : 0), value: shown)
            ZenithNoticeCheckShape()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(ZenithStatus.success, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .padding(8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(shown ? 0.36 : 0), value: shown)
        }
        .padding(2)
        .frame(width: ZenithNoticeLayout.ring, height: ZenithNoticeLayout.ring)
    }
}

private struct ZenithNoticeCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        return path
    }
}
