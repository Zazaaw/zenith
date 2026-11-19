// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the About page, after the maker's portfolio (p441z.my.id). A
// profile hero with the rotating decrypt word and the shiny subtitle, social
// buttons, figures that count up, the bio rising in word by word, a "Now"
// timeline, the stack in slow marquee rows, then the studio and the app.
//
// Motion stays in SwiftUI's animation system and only moves transform and
// opacity. The one exception is the decrypt effect, which is discrete by
// design: it swaps one string per ~34 ms step. Everything continuous (the
// marquee, the rotating word, the shimmer, the status ping) stops when the
// page is left or the Settings window is closed or covered, and Reduce
// Motion turns it all into plain fades.

struct ZenithAboutPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var settingsWindow = SettingsWindowVisibility.shared

    var body: some View {
        let strings = ZenithStrings.maker(l10n.language)
        let visible = settingsWindow.isVisible
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZenithAboutReveal(order: 0) { _ in
                    ZenithAboutIdentity(strings: strings, active: visible)
                }
                ZenithAboutReveal(order: 1) { shown in
                    ZenithAboutHeadline(active: visible && shown)
                }
                .padding(.top, 24)
                ZenithAboutReveal(order: 2) { shown in
                    ZenithShinyText(text: ZenithMaker.subtitle, active: visible && shown)
                }
                .padding(.top, 8)
                ZenithAboutReveal(order: 3) { _ in
                    ZenithAboutSocialRow(strings: strings)
                }
                .padding(.top, 20)
                ZenithAboutReveal(order: 4) { shown in
                    ZenithAboutStats(strings: strings, play: shown)
                }
                .padding(.top, 30)

                ZenithAboutReveal(order: 5, waitsForScroll: true) { shown in
                    VStack(alignment: .leading, spacing: 14) {
                        ZenithAboutTitle(text: strings.aboutTitle, play: shown)
                        ZenithRevealParagraph(text: strings.bio, play: shown)
                    }
                }
                .padding(.top, 44)
                ZenithAboutReveal(order: 6, waitsForScroll: true) { shown in
                    VStack(alignment: .leading, spacing: 18) {
                        ZenithAboutTitle(text: strings.nowTitle, play: shown)
                        ZenithAboutTimeline(entries: ZenithMaker.timeline, strings: strings, play: shown)
                    }
                }
                .padding(.top, 44)
                ZenithAboutReveal(order: 7, waitsForScroll: true) { shown in
                    VStack(alignment: .leading, spacing: 16) {
                        ZenithAboutTitle(text: strings.stackTitle, play: shown)
                        ZenithStackMarquee(running: visible && shown)
                    }
                }
                .padding(.top, 44)
                ZenithAboutReveal(order: 8, waitsForScroll: true) { _ in
                    ZenithAboutStudio(strings: strings)
                }
                .padding(.top, 44)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Entrance

/// One block of the page rising in (8 pt and opacity, on the reveal curve)
/// the first time it shows, a few tens of milliseconds after the one above.
/// Blocks below the fold wait until they are scrolled to, so their titles,
/// figures and timeline play where they can be seen.
private struct ZenithAboutReveal<Content: View>: View {
    let order: Int
    let waitsForScroll: Bool
    let content: (Bool) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var requested = false

    init(order: Int, waitsForScroll: Bool = false, @ViewBuilder content: @escaping (Bool) -> Content) {
        self.order = order
        self.waitsForScroll = waitsForScroll
        self.content = content
    }

    var body: some View {
        content(shown)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .modifier(ZenithWhenVisible(waitsForScroll: waitsForScroll, action: reveal))
    }

    private func reveal() {
        guard !requested else { return }
        requested = true
        // Staggered 60 ms apart; a block reached by scrolling comes in at once.
        let delay = waitsForScroll ? 0 : Double(order) * 0.06
        let animation = reduceMotion ? Animation.easeOut(duration: 0.25) : ZenithMotion.reveal(0.55)
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .milliseconds(Int(delay * 1000))) }
            withAnimation(animation) { shown = true }
        }
    }
}

/// Runs `action` once the view is on screen: on appear, or, for blocks that
/// wait for the scroll, when half of it is inside the scroll view (macOS 15).
/// A fallback shows it after two seconds anyway, so nothing can stay hidden.
private struct ZenithWhenVisible: ViewModifier {
    let waitsForScroll: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if waitsForScroll, #available(macOS 15.0, *) {
            content
                .onScrollVisibilityChange(threshold: 0.3) { visible in
                    if visible { action() }
                }
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled { action() }
                }
        } else {
            content.onAppear(perform: action)
        }
    }
}

// MARK: - Hero

private struct ZenithAboutIdentity: View {
    let strings: ZenithMakerStrings
    let active: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            avatar
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: ZenithMaker.name)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .textSelection(.enabled)
                Text(verbatim: "@\(ZenithMaker.handle)")
                    .font(ZenithType.mono(12.5))
                    .foregroundStyle(.secondary)
                ZenithStatusChip(text: strings.status, active: active)
                    .padding(.top, 5)
            }
        }
    }

    private var avatar: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Group {
            if let image = ZenithMaker.photo {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Text(verbatim: "F")
                    .font(.system(size: 38, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ZenithSurface.tileFill)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(shape)
        .overlay(shape.strokeBorder(ZenithSurface.tileStroke))
        .accessibilityLabel(ZenithMaker.name)
    }
}

/// Style Kit's status chip with a green dot that pings now and then.
private struct ZenithStatusChip: View {
    let text: String
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ZenithStatus.success)
                .frame(width: 7, height: 7)
                .background {
                    if active && !reduceMotion {
                        Circle()
                            .stroke(ZenithStatus.success, lineWidth: 1.2)
                            .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { ring, t in
                                ring.scaleEffect(1 + 1.5 * t).opacity(Double(0.7 * (1 - t)))
                            } keyframes: { _ in
                                CubicKeyframe(1, duration: 1.4)
                                LinearKeyframe(1, duration: 1.2)
                            }
                    }
                }
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(ZenithStatus.success)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(ZenithStatus.fill(ZenithStatus.success), in: Capsule())
        .overlay(Capsule().strokeBorder(ZenithStatus.stroke(ZenithStatus.success)))
    }
}

/// “I build for the web — and I ⟨word⟩”, the word in the serif italic accent
/// face about 1.18× larger. On one line when it fits, else broken after the
/// dash; either way the word's box is as wide as the widest word, so nothing
/// moves as it changes.
private struct ZenithAboutHeadline: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var frame: ZenithDecryptFrame?

    private static let size: CGFloat = 27
    private static let wordSize = size * 1.18
    private static let leadFont = Font.system(size: size, weight: .bold)
    private static let wordFont = Font.system(size: wordSize, weight: .medium, design: .serif).italic()

    var body: some View {
        let words = ZenithMaker.rotatingWords
        let word = words[index % words.count]
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                lead("\(ZenithMaker.headlineLead) \(ZenithMaker.headlineJoin)")
                wordView(word)
            }
            VStack(alignment: .leading, spacing: 0) {
                lead(ZenithMaker.headlineLead)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    lead(ZenithMaker.headlineJoin)
                    wordView(word)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ZenithMaker.headlineLead) \(ZenithMaker.headlineJoin) \(word)")
        .accessibilityAddTraits(.isHeader)
        .task(id: active) {
            guard active else {
                frame = nil
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                let next = (index + 1) % words.count
                if reduceMotion {
                    withAnimation(.easeInOut(duration: 0.35)) { index = next }
                } else {
                    index = next
                    await ZenithDecrypt.play(words[next]) { frame = $0 }
                }
            }
            frame = nil
        }
    }

    private func lead(_ text: String) -> some View {
        Text(verbatim: text)
            .font(Self.leadFont)
            .tracking(-0.6)
            .lineLimit(1)
    }

    private func wordView(_ word: String) -> some View {
        ZStack(alignment: .leading) {
            ForEach(ZenithMaker.rotatingWords, id: \.self) { Text(verbatim: $0).hidden() }
            ZenithDecrypt.text(frame ?? .clean(word), size: Self.wordSize)
                .contentTransition(.opacity)
        }
        .font(Self.wordFont)
        .lineLimit(1)
        .fixedSize()
    }
}

/// A line with a light band passing across it now and then, as magicui's
/// animated shiny text on the portfolio: out over 2.4 s, a pause, back again.
/// The band is a gradient mask whose end points move; nothing is laid out.
private struct ZenithShinyText: View {
    let text: String
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let label = Text(verbatim: text).font(.system(size: 14.5))
        label
            .foregroundStyle(.secondary)
            .overlay {
                if active && !reduceMotion {
                    label
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .keyframeAnimator(initialValue: CGFloat(-0.3), repeating: true) { shine, x in
                            shine.mask {
                                LinearGradient(colors: [.clear, .black, .clear],
                                               startPoint: UnitPoint(x: x - 0.14, y: 0.5),
                                               endPoint: UnitPoint(x: x + 0.14, y: 0.5))
                            }
                        } keyframes: { _ in
                            CubicKeyframe(1.3, duration: 2.4)
                            LinearKeyframe(1.3, duration: 2.4)
                            CubicKeyframe(-0.3, duration: 2.4)
                            LinearKeyframe(-0.3, duration: 0.8)
                        }
                        .accessibilityHidden(true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Social row

private struct ZenithAboutSocialRow: View {
    let strings: ZenithMakerStrings

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ZenithMaker.socials, id: \.url) { link in
                ZenithSocialButton(link: link, title: link.title ?? strings.website)
            }
        }
    }
}

/// A round hairline button that lifts 2 pt on hover.
private struct ZenithSocialButton: View {
    let link: ZenithSocialLink
    let title: String
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        Button { openURL(link.url) } label: {
            icon
                .frame(width: 15, height: 15)
                .foregroundStyle(hovering ? .primary : .secondary)
                .frame(width: 36, height: 36)
                .background(hovering ? ZenithSurface.tileFill : ZenithSurface.cardFill, in: Circle())
                .overlay(Circle().strokeBorder(hovering ? Color.primary.opacity(0.2) : ZenithSurface.tileStroke))
                .offset(y: hovering && !reduceMotion ? -2 : 0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithAboutMotion.hover(reduceMotion), value: hovering)
        .help(title)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var icon: some View {
        switch link.icon {
        case let .symbol(name):
            Image(systemName: name).font(.system(size: 14, weight: .medium))
        case let .bundled(name):
            ZenithBundledIcon(name: name, size: 15)
        }
    }
}

enum ZenithAboutMotion {
    /// Hover lifts land on a light spring; with Reduce Motion only colours fade.
    static func hover(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: ZenithMotion.fast) : .spring(response: 0.3, dampingFraction: 0.8)
    }
}

/// A monochrome simple-icons mark (CC0) from Resources/Images, tinted to the
/// label colour like an SF Symbol.
private struct ZenithBundledIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if let image = ZenithBundledIcons.image(name) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}

private enum ZenithBundledIcons {
    private static let images: [String: NSImage] = {
        var names = ZenithMaker.stack.compactMap(\.icon)
        for link in ZenithMaker.socials {
            if case let .bundled(name) = link.icon { names.append(name) }
        }
        var images: [String: NSImage] = [:]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Images"),
                  let image = NSImage(contentsOf: url) else { continue }
            image.isTemplate = true
            images[name] = image
        }
        return images
    }()

    static func image(_ name: String) -> NSImage? { images[name] }
}

// MARK: - Figures

/// Three big figures that count up, split by hairlines, each over a grey label.
private struct ZenithAboutStats: View {
    let strings: ZenithMakerStrings
    let play: Bool

    var body: some View {
        let stats: [(value: Int, suffix: String, label: String, detail: String?)] = [
            (ZenithMaker.yearsBuilding, "+", strings.yearsBuilding, nil),
            (AppLanguage.allCases.count, "", strings.languagesSpoken, nil),
            (ZenithMaker.disciplines, "", strings.disciplines, strings.disciplinesDetail),
        ]
        HStack(alignment: .top, spacing: 0) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                ZenithStatFigure(value: stat.value, suffix: stat.suffix, label: stat.label,
                                 play: play, delay: 0.15 + Double(index) * 0.1)
                    .padding(.leading, index == 0 ? 0 : 22)
                    .padding(.trailing, 22)
                    .overlay(alignment: .leading) {
                        if index > 0 {
                            Rectangle().fill(ZenithSurface.hairline).frame(width: 1)
                        }
                    }
                    .help(stat.detail ?? "")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stat.value)\(stat.suffix) \(stat.label)\(stat.detail.map { ", \($0)" } ?? "")")
            }
        }
    }
}

private struct ZenithStatFigure: View {
    let value: Int
    let suffix: String
    let label: String
    let play: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The final figure, hidden, holds the width so nothing shifts as it counts.
            Text(verbatim: "\(value)\(suffix)")
                .hidden()
                .overlay(alignment: .leading) {
                    ZenithCountUp(value: play || reduceMotion ? Double(value) : 0, suffix: suffix)
                        .animation(reduceMotion ? nil : ZenithMotion.reveal(1.2).delay(delay), value: play)
                }
                .font(.system(size: 32, weight: .bold).monospacedDigit())
                .tracking(-0.8)
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A whole number that SwiftUI interpolates frame by frame.
private struct ZenithCountUp: View, Animatable {
    var value: Double
    let suffix: String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: "\(Int(value.rounded()))\(suffix)")
    }
}

// MARK: - Decrypt

/// A section title that decrypts in when its block appears.
private struct ZenithAboutTitle: View {
    let text: String
    let play: Bool

    var body: some View {
        ZenithDecryptText(text: text, play: play, size: 19)
            .font(ZenithType.sectionTitle)
            .tracking(ZenithType.sectionTitleTracking)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ZenithDecryptText: View {
    let text: String
    let play: Bool
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: ZenithDecryptFrame?
    @State private var played = false

    var body: some View {
        // Before it plays (still hidden by its block) it holds the first frame,
        // so the clean word never flashes ahead of the noise.
        let idle = played || reduceMotion ? ZenithDecryptFrame.clean(text) : ZenithDecrypt.frame(of: text, step: 0)
        ZenithDecrypt.text(frame ?? idle, size: size)
            .accessibilityLabel(text)
            .task(id: play) {
                guard play, !played, !reduceMotion else { return }
                await ZenithDecrypt.play(text) { frame = $0 }
                played = true
                frame = nil
            }
    }
}

extension ZenithDecrypt {
    /// One frame as a single `Text`: settled letters, a small green block,
    /// then the noise at 40%.
    static func text(_ frame: ZenithDecryptFrame, size: CGFloat) -> Text {
        var text = Text(verbatim: frame.settled)
        if frame.cursor {
            let block = size * 0.42
            text = text + Text(verbatim: "\u{25A0}")
                .font(.system(size: block))
                .baselineOffset(size * 0.28)
                .foregroundStyle(ZenithStatus.success)
        }
        if !frame.noise.isEmpty {
            text = text + Text(verbatim: frame.noise).foregroundStyle(Color.primary.opacity(0.4))
        }
        return text
    }

    /// Steps `text` from noise to clean, one frame per step, then hands back
    /// the clean word. Stops early, clean, when the task is cancelled.
    @MainActor
    static func play(_ text: String, update: (ZenithDecryptFrame) -> Void) async {
        for step in 0..<stepCount(for: text) {
            update(frame(of: text, step: step))
            try? await Task.sleep(for: .milliseconds(stepMilliseconds))
            if Task.isCancelled { break }
        }
        update(.clean(text))
    }
}

// MARK: - About

/// The bio rising in word by word (6 pt, a 4 pt blur clearing, opacity),
/// staggered across 1.2 s, as on the portfolio. One `Text` drawn by a
/// `TextRenderer`, so the paragraph is laid out once and only redrawn.
private struct ZenithRevealParagraph: View {
    let text: String
    let play: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: Double = 0

    var body: some View {
        if #available(macOS 15.0, *), !reduceMotion {
            styled(composed)
                .textRenderer(ZenithWordRevealRenderer(elapsed: elapsed))
                .onChange(of: play, initial: true) { _, play in
                    guard play, elapsed == 0 else { return }
                    withAnimation(.linear(duration: ZenithWordRevealTiming.total)) {
                        elapsed = ZenithWordRevealTiming.total
                    }
                }
        } else {
            styled(Text(text))
        }
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(.system(size: 14))
            .lineSpacing(4)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    @available(macOS 15.0, *)
    private var composed: Text {
        let units = ZenithWordReveal.units(text)
        return units.enumerated().reduce(Text(verbatim: "")) { text, unit in
            text + Text(verbatim: unit.element)
                .customAttribute(ZenithRevealUnit(index: unit.offset, count: units.count))
        }
    }
}

private enum ZenithWordRevealTiming {
    /// The last word starts this long after the first.
    static let spread = 1.2
    /// Each word's own rise.
    static let each = 0.6
    static let total = spread + each
}

@available(macOS 15.0, *)
private struct ZenithRevealUnit: TextAttribute {
    let index: Int
    let count: Int
}

@available(macOS 15.0, *)
private struct ZenithWordRevealRenderer: TextRenderer, Animatable {
    var elapsed: Double

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    var displayPadding: EdgeInsets { EdgeInsets(top: 6, leading: 6, bottom: 10, trailing: 6) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let done = elapsed >= ZenithWordRevealTiming.total
        for line in layout {
            for run in line {
                guard !done, let unit = run[ZenithRevealUnit.self] else {
                    context.draw(run)
                    continue
                }
                let start = ZenithWordRevealTiming.spread * Double(unit.index) / Double(max(unit.count - 1, 1))
                let progress = min(max((elapsed - start) / ZenithWordRevealTiming.each, 0), 1)
                if progress >= 1 {
                    context.draw(run)
                    continue
                }
                guard progress > 0 else { continue }
                // Ease out: the word decelerates into place.
                let eased = 1 - pow(1 - progress, 3)
                var word = context
                word.opacity = eased
                word.translateBy(x: 0, y: CGFloat(1 - eased) * 6)
                word.addFilter(.blur(radius: CGFloat(1 - eased) * 4))
                word.draw(run)
            }
        }
    }
}

// MARK: - Now

/// The timeline in the portfolio's style: a dot on a thin rail (green and
/// filled while ongoing, hollow grey once past), a logo tile, the role in
/// bold over the organisation and place, and the period in mono.
private struct ZenithAboutTimeline: View {
    let entries: [ZenithTimelineEntry]
    let strings: ZenithMakerStrings
    let play: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dot: CGFloat = 11
    private static let tile: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                row(entries[index], index: index)
            }
        }
    }

    private func row(_ entry: ZenithTimelineEntry, index: Int) -> some View {
        let delay = 0.12 + Double(index) * 0.08
        return HStack(alignment: .top, spacing: 16) {
            Color.clear.frame(width: Self.dot, height: 1)
            tile(entry.tile)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(entry.roleTitle(strings))
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(entry.period(strings))
                        .font(ZenithType.mono(11))
                        .foregroundStyle(entry.isCurrent ? ZenithStatus.success : Color.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                place(entry)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
        }
        .padding(.bottom, index == entries.count - 1 ? 0 : 24)
        .overlay(alignment: .topLeading) { rail(entry, index: index, delay: delay) }
        .opacity(play ? 1 : 0)
        .offset(y: play || reduceMotion ? 0 : 8)
        .animation(reduceMotion ? .easeOut(duration: 0.25) : ZenithMotion.reveal(0.5).delay(delay), value: play)
        .accessibilityElement(children: .combine)
    }

    private func place(_ entry: ZenithTimelineEntry) -> Text {
        let organisation = Text(verbatim: entry.organisation).foregroundStyle(.secondary)
        guard let location = entry.location else { return organisation }
        return organisation + Text(verbatim: ", \(location)").foregroundStyle(.tertiary)
    }

    /// The dot on its rail. The rail runs between dots only, and draws down
    /// from each dot as the row arrives.
    private func rail(_ entry: ZenithTimelineEntry, index: Int, delay: Double) -> some View {
        let dotTop = (Self.tile - Self.dot) / 2
        return VStack(spacing: 0) {
            Rectangle()
                .fill(ZenithSurface.tileStroke)
                .frame(width: 1, height: dotTop)
                .opacity(index == 0 ? 0 : 1)
            Group {
                if entry.isCurrent {
                    Circle().fill(ZenithStatus.success)
                } else {
                    Circle().strokeBorder(Color.secondary.opacity(0.55), lineWidth: 2)
                }
            }
            .frame(width: Self.dot, height: Self.dot)
            Rectangle()
                .fill(ZenithSurface.tileStroke)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .scaleEffect(x: 1, y: play || reduceMotion ? 1 : 0, anchor: .top)
                .animation(reduceMotion ? nil : ZenithMotion.reveal(0.6).delay(delay + 0.15), value: play)
                .opacity(index == entries.count - 1 ? 0 : 1)
        }
        .frame(width: Self.dot)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tile(_ tile: ZenithTimelineEntry.Tile) -> some View {
        switch tile {
        case .studio:
            BrandBadge(size: Self.tile)
        case .app:
            // The icon's artwork sits inside a transparent margin; drawn a
            // little larger, its body matches the other tiles.
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: Self.tile * 1.22, height: Self.tile * 1.22)
                .frame(width: Self.tile, height: Self.tile)
                .accessibilityHidden(true)
        case let .symbol(name):
            let shape = RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
            Image(systemName: name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.tile, height: Self.tile)
                .background(ZenithSurface.tileFill, in: shape)
                .overlay(shape.strokeBorder(ZenithSurface.tileStroke))
        }
    }
}

// MARK: - Stack

/// The stack in slow marquee rows, the middle one running the other way,
/// faded at both edges. A row pauses under the pointer; with Reduce Motion
/// the tags sit still, wrapped.
private struct ZenithStackMarquee: View {
    let running: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds per loop, row by row.
    private static let periods: [TimeInterval] = [96, 120, 108]

    var body: some View {
        Group {
            if reduceMotion {
                ZenithFlowRow(spacing: 8) {
                    ForEach(ZenithMaker.stack, id: \.name) { ZenithStackPill(item: $0) }
                }
            } else {
                let rows = ZenithMaker.stackRows(Self.periods.count)
                VStack(spacing: 10) {
                    ForEach(rows.indices, id: \.self) { index in
                        ZenithMarqueeRow(items: rows[index], period: Self.periods[index],
                                         reversed: index == 1, running: running)
                    }
                }
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                                           .init(color: .black, location: 0.08),
                                           .init(color: .black, location: 0.92),
                                           .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithMaker.stack.map(\.name).joined(separator: ", "))
    }
}

/// One row: two copies of the tags side by side, slid by one copy's width
/// per loop on the display clock. The time spent paused is banked, so the
/// row resumes where it stopped.
private struct ZenithMarqueeRow: View {
    let items: [ZenithStackItem]
    let period: TimeInterval
    let reversed: Bool
    let running: Bool
    @State private var copyWidth: CGFloat = 0
    @State private var hovering = false
    @State private var banked: TimeInterval = 0
    @State private var since: Date?

    private static let gap: CGFloat = 8
    private var moving: Bool { running && !hovering }

    var body: some View {
        Color.clear
            .frame(height: ZenithStackPill.height)
            .overlay(alignment: .leading) {
                TimelineView(.animation(minimumInterval: nil, paused: !moving)) { context in
                    let elapsed = banked + (since.map { max(0, context.date.timeIntervalSince($0)) } ?? 0)
                    let phase = (elapsed / period).truncatingRemainder(dividingBy: 1)
                    let travel = copyWidth + Self.gap
                    strip.offset(x: -travel * CGFloat(reversed ? 1 - phase : phase))
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onChange(of: moving, initial: true) { _, moving in
                let now = Date()
                if moving {
                    since = now
                } else if let start = since {
                    banked += now.timeIntervalSince(start)
                    since = nil
                }
            }
    }

    private var strip: some View {
        HStack(spacing: Self.gap) {
            ZenithStackTags(items: items)
                .equatable()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { copyWidth = $0 }
            ZenithStackTags(items: items)
                .equatable()
        }
        .fixedSize()
        .drawingGroup()
    }
}

private struct ZenithStackTags: View, Equatable {
    let items: [ZenithStackItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.name) { ZenithStackPill(item: $0) }
        }
    }
}

/// An icon and a name in a hairline capsule.
private struct ZenithStackPill: View {
    let item: ZenithStackItem
    static let height: CGFloat = 30

    var body: some View {
        HStack(spacing: 6) {
            if let icon = item.icon {
                ZenithBundledIcon(name: icon, size: 13)
            }
            Text(verbatim: item.name)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .background(ZenithSurface.cardFill, in: Capsule())
        .overlay(Capsule().strokeBorder(ZenithSurface.tileStroke))
    }
}

// MARK: - Studio and app

private struct ZenithAboutStudio: View {
    let strings: ZenithMakerStrings
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithLinkCard(title: AppInfo.maker, caption: strings.studioCaption, url: AppInfo.websiteURL) {
                BrandBadge(size: 40)
            }
            ZenithLinkCard(title: AppInfo.repositorySlug, caption: l10n.s.viewOnGitHub, url: AppInfo.repositoryURL) {
                let shape = RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
                ZenithBundledIcon(name: "si-github", size: 17)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(ZenithSurface.tileFill, in: shape)
                    .overlay(shape.strokeBorder(ZenithSurface.tileStroke))
            }
            appBlock
                .padding(.top, 14)
            if AppInfo.updatesEnabled {
                Form { UpdatesView() }
                    .formStyle(.grouped)
                    .frame(minHeight: 280)
            }
            Text(AppInfo.copyright)
                .font(ZenithType.mono(10.5))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
    }

    /// The app itself, compact: icon, name, version (and, in developer
    /// builds only, the commit), and the way back into the introduction.
    private var appBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 54, height: 54)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(AppInfo.name).font(.system(size: 15, weight: .semibold))
                        if AppInfo.isBeta {
                            Text(l10n.s.betaBadgeLabel.uppercased())
                                .font(ZenithType.mono(9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ZenithStatus.fill(ZenithStatus.warning), in: Capsule())
                                .overlay(Capsule().strokeBorder(ZenithStatus.stroke(ZenithStatus.warning)))
                                .foregroundStyle(ZenithStatus.warning)
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(l10n.s.versionPrefix) \(AppInfo.version)")
                            .font(ZenithType.mono(11))
                            .foregroundStyle(.secondary)
                        if AppInfo.isDeveloperBuild, let commit = AppInfo.buildCommit {
                            // Dev-only: which source commit this build came from. Never shipped.
                            Text(commit)
                                .font(ZenithType.mono(10.5))
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }
                Spacer(minLength: 12)
                HStack(spacing: 8) {
                    if AppInfo.showsUpstreamReleaseIntros {
                        Button(l10n.s.reviewHighlights) {
                            appDelegate()?.showUpdateHighlights(isReview: true)
                        }
                    }
                    Button(l10n.s.reviewIntro) {
                        appDelegate()?.showOnboarding()
                    }
                }
            }
            Text(l10n.s.aboutDescription)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(ZenithSurface.cardFill, in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
            .strokeBorder(ZenithSurface.hairline))
    }
}

/// A row like the résumé card on p441z.my.id: a tile, a title over a muted
/// line, and an arrow out. Lifts 2 pt on hover.
struct ZenithLinkCard<Tile: View>: View {
    let title: String
    let caption: String
    let url: URL
    let tile: Tile
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    init(title: String, caption: String, url: URL, @ViewBuilder tile: () -> Tile) {
        self.title = title
        self.caption = caption
        self.url = url
        self.tile = tile()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        Button { openURL(url) } label: {
            HStack(spacing: 14) {
                tile
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(hovering ? ZenithStatus.success : Color.secondary)
                    .offset(x: hovering ? 1.5 : 0, y: hovering ? -1.5 : 0)
            }
            .padding(14)
            .background(hovering ? ZenithSurface.tileFill : ZenithSurface.cardFill, in: shape)
            .overlay(shape.strokeBorder(hovering ? ZenithSurface.tileStroke : ZenithSurface.hairline))
            .offset(y: hovering && !reduceMotion ? -2 : 0)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithAboutMotion.hover(reduceMotion), value: hovering)
        .help(url.absoluteString)
    }
}

/// Lays its children out left to right and wraps to the next line.
struct ZenithFlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
