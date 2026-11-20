// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the About page, about Zenith first. The app with its rotating
// decrypt headline and shiny line, figures that count up, a bento of what it
// can do (each tile opens that part of Settings), then a little about who
// makes it, the studio and the source.
//
// Motion stays in SwiftUI's animation system and only moves transform and
// opacity. The one exception is the decrypt effect, which is discrete by
// design: it swaps one string per ~34 ms step. Everything continuous (the
// rotating word, the shimmer, the status ping) stops when the page is left
// or the Settings window is closed or covered, and Reduce Motion turns it all
// into plain fades.

struct ZenithAboutPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var settingsWindow = SettingsWindowVisibility.shared

    var body: some View {
        let strings = ZenithStrings.about(l10n.language)
        let visible = settingsWindow.isVisible
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZenithAboutReveal(order: 0) { _ in
                    ZenithAboutHero()
                }
                ZenithAboutReveal(order: 1) { shown in
                    ZenithAboutHeadline(active: visible && shown)
                }
                .padding(.top, 26)
                ZenithAboutReveal(order: 2) { shown in
                    ZenithShinyText(text: strings.subtitle, active: visible && shown)
                }
                .padding(.top, 8)
                ZenithAboutReveal(order: 3) { shown in
                    ZenithAboutStats(stats: [
                        ZenithAboutStat(value: ZenithAbout.featureCount, label: strings.featureCount),
                        ZenithAboutStat(value: ZenithAbout.languageCount, label: strings.languageCount),
                        ZenithAboutStat(value: ZenithAbout.accountCount, label: strings.accountCount),
                    ], play: shown)
                }
                .padding(.top, 28)

                ZenithAboutReveal(order: 4, waitsForScroll: true) { shown in
                    VStack(alignment: .leading, spacing: 6) {
                        ZenithAboutTitle(text: strings.featuresTitle, play: shown)
                        Text(strings.featuresCaption)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 48)
                ZenithAboutFeatures(strings: strings)
                    .padding(.top, 16)

                ZenithAboutReveal(order: 5, waitsForScroll: true) { shown in
                    VStack(alignment: .leading, spacing: 12) {
                        ZenithAboutTitle(text: strings.madeBy, play: shown)
                        ZenithMakerCard(strings: strings, active: visible && shown)
                        ZenithLinkCard(title: AppInfo.maker, caption: strings.studioCaption, url: AppInfo.websiteURL) {
                            BrandBadge(size: 40)
                        }
                    }
                }
                .padding(.top, 48)
                ZenithAboutReveal(order: 6, waitsForScroll: true) { _ in
                    ZenithAboutClosing()
                }
                .padding(.top, 36)
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
/// Blocks below the fold wait until they are scrolled to, so their titles
/// and figures play where they can be seen.
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
/// wait for the scroll, when a third of it is inside the scroll view (macOS
/// 15). If the scroll view never reports either way, a fallback shows it
/// after two seconds, so nothing can stay hidden.
private struct ZenithWhenVisible: ViewModifier {
    let waitsForScroll: Bool
    let action: () -> Void
    @State private var reported = false

    func body(content: Content) -> some View {
        if waitsForScroll, #available(macOS 15.0, *) {
            content
                .onScrollVisibilityChange(threshold: 0.3) { visible in
                    reported = true
                    if visible { action() }
                }
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    if !Task.isCancelled, !reported { action() }
                }
        } else {
            content.onAppear(perform: action)
        }
    }
}

// MARK: - Hero

/// The app: its icon, name and version (and, in developer builds only, the
/// commit it was built from).
private struct ZenithAboutHero: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZenithAboutAppIcon(size: 80)
            VStack(alignment: .leading, spacing: 6) {
                Text(AppInfo.name)
                    .font(ZenithType.pageTitle)
                    .tracking(ZenithType.pageTitleTracking)
                ZenithFlowRow(spacing: 8) {
                    Text("\(l10n.s.versionPrefix) \(AppInfo.version)")
                        .font(ZenithType.mono(11.5))
                        .foregroundStyle(.secondary)
                    if AppInfo.isBeta {
                        Text(l10n.s.betaBadgeLabel.uppercased())
                            .font(ZenithType.mono(9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ZenithStatus.fill(ZenithStatus.warning), in: Capsule())
                            .overlay(Capsule().strokeBorder(ZenithStatus.stroke(ZenithStatus.warning)))
                            .foregroundStyle(ZenithStatus.warning)
                    }
                    if AppInfo.isDeveloperBuild, let commit = AppInfo.buildCommit {
                        // Dev-only: which source commit this build came from. Never shipped.
                        Text(commit)
                            .font(ZenithType.mono(10.5))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

/// Zenith's own icon from the bundle, else the Satu Visual badge it is made from.
private struct ZenithAboutAppIcon: View {
    let size: CGFloat

    private static let icon: NSImage? = Bundle.main.image(forResource: "AppIcon")

    var body: some View {
        if let icon = Self.icon {
            // The artwork sits inside a transparent margin; drawn a little
            // larger, its body is `size` across.
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size * 1.22, height: size * 1.22)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            BrandBadge(size: size)
                .accessibilityHidden(true)
        }
    }
}

/// “Your Mac, at its ⟨word⟩”, the word in the serif italic accent face about
/// 1.18× larger. On one line when it fits, else broken after the comma;
/// either way the word's box is as wide as the widest word, so nothing moves
/// as it changes.
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
        let words = ZenithAbout.rotatingWords
        let word = words[index % words.count]
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                lead("\(ZenithAbout.headlineLead) \(ZenithAbout.headlineJoin)")
                wordView(word)
            }
            VStack(alignment: .leading, spacing: 0) {
                lead(ZenithAbout.headlineLead)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    lead(ZenithAbout.headlineJoin)
                    wordView(word)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ZenithAbout.headlineLead) \(ZenithAbout.headlineJoin) \(word)")
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
            ForEach(ZenithAbout.rotatingWords, id: \.self) { Text(verbatim: $0).hidden() }
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
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 14.5))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Figures

private struct ZenithAboutStat {
    let value: Int
    let label: String
}

/// Big figures that count up, split by hairlines, each over a grey label.
private struct ZenithAboutStats: View {
    let stats: [ZenithAboutStat]
    let play: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                ZenithStatFigure(value: stat.value, label: stat.label,
                                 play: play, delay: 0.15 + Double(index) * 0.1)
                    .padding(.leading, index == 0 ? 0 : 22)
                    .padding(.trailing, 22)
                    .overlay(alignment: .leading) {
                        if index > 0 {
                            Rectangle().fill(ZenithSurface.hairline).frame(width: 1)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(stat.value) \(stat.label)")
            }
        }
    }
}

private struct ZenithStatFigure: View {
    let value: Int
    let label: String
    let play: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The final figure, hidden, holds the width so nothing shifts as it counts.
            Text(verbatim: "\(value)")
                .hidden()
                .overlay(alignment: .leading) {
                    ZenithCountUp(value: play || reduceMotion ? Double(value) : 0)
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

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(verbatim: "\(Int(value.rounded()))")
    }
}

// MARK: - Features

/// The bento of what Zenith does. Each tile rises in as it scrolls into
/// view, a beat after the tile before it, and opens its part of Settings.
private struct ZenithAboutFeatures: View {
    let strings: ZenithAboutStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed: Set<Int> = []
    @State private var queue = ZenithRevealQueue(step: 0.06)
    @State private var waiting: [Int] = []
    @State private var flushing = false

    var body: some View {
        ZenithAboutBentoGrid(spacing: 10) {
            ForEach(ZenithAbout.areas.indices, id: \.self) { index in
                let area = ZenithAbout.areas[index]
                ZenithFeatureTile(area: area, strings: strings.area(area.id),
                                  shown: revealed.contains(index))
                    .modifier(ZenithWhenVisible(waitsForScroll: true) { request(index) })
                    .layoutValue(key: ZenithAboutBentoSpan.self, value: area.span)
            }
        }
    }

    /// Tiles that come into view in the same moment are gathered for a
    /// frame, then handed their slots in reading order.
    private func request(_ index: Int) {
        guard !waiting.contains(index), !revealed.contains(index) else { return }
        waiting.append(index)
        guard !flushing else { return }
        flushing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            flush()
        }
    }

    private func flush() {
        flushing = false
        let slots = queue.schedule(waiting, now: ProcessInfo.processInfo.systemUptime)
        waiting = []
        let animation = reduceMotion ? Animation.easeOut(duration: 0.25) : ZenithMotion.reveal(0.55)
        for slot in slots {
            Task { @MainActor in
                if slot.delay > 0 { try? await Task.sleep(for: .milliseconds(Int(slot.delay * 1000))) }
                withAnimation(animation) { _ = revealed.insert(slot.index) }
            }
        }
    }
}

private struct ZenithAboutBentoSpan: LayoutValueKey {
    static let defaultValue = 1
}

/// Two columns of hairline tiles (one when narrow). A tile may span both;
/// tiles sharing a row take its tallest height, so their edges line up.
private struct ZenithAboutBentoGrid: Layout {
    var spacing: CGFloat = 10

    private struct Row {
        var indices: [Int]
        var widths: [CGFloat]
        var height: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 640
        let rows = arrange(width: width, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, width) in zip(row.indices, row.widths) {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: row.height))
                x += width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        let columns = ZenithBento.columns(for: width)
        let spans = subviews.map { $0[ZenithAboutBentoSpan.self] }
        return ZenithBento.rows(spans: spans, columns: columns).map { indices in
            let available = max(0, width - spacing * CGFloat(indices.count - 1))
            let shares = ZenithBento.shares(spans: indices.map { spans[$0] }, columns: columns)
            let widths = shares.map { (available * CGFloat($0)).rounded(.down) }
            let height = zip(indices, widths).map { index, width in
                subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            }.max() ?? 0
            return Row(indices: indices, widths: widths, height: height)
        }
    }
}

/// One part of Zenith: a symbol tile, the name, a line, and chips naming
/// what is inside. Lifts 2 pt on hover; a click opens it in Settings, or the
/// Features page when it is not installed.
private struct ZenithFeatureTile: View {
    let area: ZenithFeatureArea
    let strings: ZenithAboutAreaStrings
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    symbol
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(hovering ? Color.primary : Color.secondary)
                        .opacity(hovering ? 1 : 0.55)
                        .offset(x: hovering && !reduceMotion ? 2 : 0)
                        .padding(.top, 2)
                }
                Text(strings.title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                Text(strings.caption)
                    .font(.system(size: 12.5))
                    .lineSpacing(2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                Spacer(minLength: 14)
                ZenithFlowRow(spacing: 6) {
                    ForEach(strings.chips, id: \.self) { chip($0) }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(hovering ? ZenithSurface.tileFill : ZenithSurface.cardFill, in: shape)
            .overlay(shape.strokeBorder(hovering ? ZenithSurface.tileStroke : ZenithSurface.hairline))
            .offset(y: hovering && !reduceMotion ? -2 : 0)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithAboutMotion.hover(reduceMotion), value: hovering)
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduceMotion ? 0 : 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(strings.title). \(strings.caption)")
        .accessibilityAddTraits(.isLink)
    }

    private var symbol: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
        return Image(systemName: area.symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(hovering ? Color.primary : Color.secondary)
            .frame(width: 36, height: 36)
            .background(ZenithSurface.tileFill, in: shape)
            .overlay(shape.strokeBorder(ZenithSurface.tileStroke))
    }

    private func chip(_ text: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous)
        return Text(text)
            .font(ZenithType.mono(10.5))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(ZenithSurface.tileFill, in: shape)
            .overlay(shape.strokeBorder(ZenithSurface.hairline))
    }

    private func open() {
        let route = area.route(isAvailable: { $0.isAvailable })
        SettingsRouter.shared.request(route.destination, targetFeature: route.targetFeature,
                                      sidebarFeature: route.sidebarFeature)
    }
}

// MARK: - Made by

/// The maker, briefly: photo, name, line and handle, the bio, then the
/// round link buttons.
private struct ZenithMakerCard: View {
    let strings: ZenithAboutStrings
    let active: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                photo
                VStack(alignment: .leading, spacing: 4) {
                    // The status chip sits beside the name only when there is room.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            name
                            ZenithStatusChip(text: strings.status, active: active).fixedSize()
                        }
                        name
                    }
                    Text(strings.role)
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                    Text(verbatim: "@\(ZenithMaker.handle)")
                        .font(ZenithType.mono(11))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(strings.bio)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: 8) {
                ForEach(ZenithMaker.socials, id: \.url) { link in
                    ZenithSocialButton(link: link, title: link.title ?? strings.website)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ZenithSurface.cardFill, in: shape)
        .overlay(shape.strokeBorder(ZenithSurface.hairline))
    }

    private var name: some View {
        Text(verbatim: ZenithMaker.name)
            .font(.system(size: 21, weight: .bold))
            .tracking(-0.5)
            .lineLimit(1)
            .fixedSize()
            .textSelection(.enabled)
    }

    private var photo: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Group {
            if let image = ZenithMaker.photo {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Text(verbatim: "F")
                    .font(.system(size: 30, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ZenithSurface.tileFill)
            }
        }
        .frame(width: 76, height: 76)
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
                .lineLimit(1)
        }
        .foregroundStyle(ZenithStatus.success)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(ZenithStatus.fill(ZenithStatus.success), in: Capsule())
        .overlay(Capsule().strokeBorder(ZenithStatus.stroke(ZenithStatus.success)))
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
        var names = ["si-github"]
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

// MARK: - Closing

/// The source, the way back into the introduction, updates when they are on,
/// and the copyright.
private struct ZenithAboutClosing: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZenithLinkCard(title: AppInfo.repositorySlug, caption: l10n.s.viewOnGitHub, url: AppInfo.repositoryURL) {
                let shape = RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
                ZenithBundledIcon(name: "si-github", size: 17)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(ZenithSurface.tileFill, in: shape)
                    .overlay(shape.strokeBorder(ZenithSurface.tileStroke))
            }
            HStack(spacing: 8) {
                Button(l10n.s.reviewIntro) {
                    appDelegate()?.showOnboarding()
                }
                if AppInfo.showsUpstreamReleaseIntros {
                    Button(l10n.s.reviewHighlights) {
                        appDelegate()?.showUpdateHighlights(isReview: true)
                    }
                }
            }
            if AppInfo.updatesEnabled {
                Form { UpdatesView() }
                    .formStyle(.grouped)
                    .frame(minHeight: 280)
            }
            Text(AppInfo.copyright)
                .font(ZenithType.mono(10.5))
                .foregroundStyle(.tertiary)
        }
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
