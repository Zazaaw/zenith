// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import WidgetKit

/// The Style Kit on a widget ("Kalimat"): a quiet card in `K`'s surfaces,
/// a hairline, an uppercase eyebrow, a sentence in bold and regular Plus
/// Jakarta Sans, and a thin bar or a mono line under it. Colour only marks
/// a status. Surfaces are picked from the widget's colour scheme rather
/// than resolved by UIKit, since a widget is drawn once per appearance.
struct WidgetPalette {
    let card: Color
    let border: Color
    let fg: Color
    let muted: Color
    let faint: Color
    let track: Color

    init(_ scheme: ColorScheme) {
        let dark = scheme == .dark
        card = dark ? Color(white: 0.071) : .white
        border = dark ? Color(white: 0.15) : Color(white: 0.89)
        fg = dark ? Color(white: 0.98) : Color(white: 0.07)
        muted = dark ? Color(white: 0.64) : Color(white: 0.42)
        faint = dark ? Color(white: 0.45) : Color(white: 0.56)
        track = dark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)
    }

    func color(_ tone: PocketTone) -> Color {
        switch tone {
        case .plain: return fg
        case .quiet: return muted
        default: return K.color(tone)
        }
    }
}

extension View {
    /// The widget's card: `K.card` with a hairline (amber while Claude waits
    /// on the person). Tinted and clear Home Screens drop it, as they drop
    /// every widget background.
    func widgetCard(_ scheme: ColorScheme, attention: Bool = false) -> some View {
        let palette = WidgetPalette(scheme)
        return containerBackground(for: .widget) {
            ZStack {
                palette.card
                ContainerRelativeShape()
                    .strokeBorder(attention ? K.amber.opacity(0.35) : palette.border, lineWidth: 1)
            }
        }
    }
}

/// "MACBOOK PRO", faint and tracked.
struct Eyebrow: View {
    let text: String
    let palette: WidgetPalette

    var body: some View {
        Text(text.uppercased())
            .font(K.sans(9.5, bold: true))
            .tracking(1.1)
            .foregroundStyle(palette.faint)
            .lineLimit(1)
    }
}

/// "At **47%**," over "charging.": the lead bold with its value in its
/// tone, the rest regular and muted.
struct SentenceText: View {
    let sentence: PocketSentence
    let palette: WidgetPalette
    var size: CGFloat = 21

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(Text(sentence.lead))\(Text(sentence.value).foregroundStyle(palette.color(sentence.tone)))\(Text(sentence.after))")
                .font(K.sans(size, bold: true))
                .foregroundStyle(palette.fg)
                .widgetAccentable()
            if !sentence.rest.isEmpty {
                Text(sentence.rest)
                    .font(K.sans(size))
                    .foregroundStyle(palette.muted)
            }
        }
        .tracking(-0.4)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sentence.text)
    }
}

/// The 3pt bar under a sentence.
struct ThinBar: View {
    let value: Double
    let tint: Color
    let palette: WidgetPalette

    var body: some View {
        Capsule()
            .fill(palette.track)
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(tint)
                        .frame(width: max(3, geometry.size.width * min(1, max(0, value))), height: 3)
                        .widgetAccentable()
                }
            }
    }
}

/// The mono line: freshness, or what a tap does.
struct MetaLine: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text).font(K.mono(10)).foregroundStyle(color).lineLimit(1)
    }
}

/// A small widget's frame: the eyebrow on top (with Claude's dot), the
/// sentence low, then whatever goes under it.
struct SmallCard<Under: View>: View {
    let lines: PocketWidgetLines
    let palette: WidgetPalette
    @ViewBuilder var under: Under

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Eyebrow(text: lines.eyebrow, palette: palette)
                Spacer(minLength: 0)
                if lines.needsYou {
                    Circle().fill(K.amber).frame(width: 6, height: 6).widgetAccentable()
                }
            }
            Spacer(minLength: 0)
            SentenceText(sentence: lines.sentence, palette: palette)
            under
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The Apple-like ring of the Batteries widget: a track and the level.
struct BatteryRing: View {
    let value: Double
    let tint: Color
    let track: Color
    var line: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: line)
            Circle()
                .trim(from: 0, to: min(1, max(0, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }
}

/// The ring colours of Apple's Batteries widget.
enum RingTone {
    static let green = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let red = Color(red: 1, green: 0.23, blue: 0.19)
}
