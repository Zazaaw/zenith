// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Today page in the open island. A calm bento of soft cards,
// one per source with something from today: a tinted glyph tile, a small mono
// label, a big mono figure that counts up as the card arrives, and one line
// of detail. Cards rise in from a blur 40 ms apart; Reduce Motion fades them
// and shows the figures as they are. The band above holds Copy as text and
// Save image. Every colour is a soft tint of the source's own; only a failure
// wears a status colour.

struct RecapPage: View {
    let size: CGSize
    @ObservedObject private var service = RecapService.shared
    // The page redraws as the sources it reads answer.
    @ObservedObject private var wakaTime = WakaTimeService.shared
    @ObservedObject private var vercel = VercelService.shared
    @ObservedObject private var github = GitHubService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let language = l10n.language
        let locale = language.formattingLocale()
        let text = ZenithStrings.recap(language)
        let cards = RecapFormat.cards(service.recap(), text: text, language: language, locale: locale)
        content(cards, text: text, locale: locale)
            .frame(width: size.width, height: size.height, alignment: .top)
            .zenithMorph(on: cards.isEmpty)
            .environment(\.locale, locale)
            .onAppear { service.viewAppeared() }
            .onDisappear { service.viewDisappeared() }
    }

    @ViewBuilder
    private func content(_ cards: [RecapCard], text: ZenithRecapStrings, locale: Locale) -> some View {
        if cards.isEmpty {
            VStack(spacing: 12) {
                ZenithIslandGlyphTile(symbol: NotchModule.recap.zenithIconSymbol, tint: NotchModule.recap.zenithTint, size: 48)
                Text(text.empty)
                    .font(.system(size: 12.5))
                    .foregroundStyle(ZenithIsland.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            RecapBento(cards: cards, size: size, locale: locale)
        }
    }
}

/// The cards in rows of equal height. Up to three side by side, two when
/// four make a square; a short last row stretches to the full width.
struct RecapBento: View {
    let cards: [RecapCard]
    let size: CGSize
    let locale: Locale
    /// A still image has no arrival.
    var animated = true

    static let spacing: CGFloat = 8
    /// What a card's tile, figure and detail need (RecapCardView.inset each
    /// way); below it the page scrolls rather than squeeze them.
    static let minimumCardHeight: CGFloat = 82
    static let maximumCardHeight: CGFloat = 104
    /// The still image's cards.
    static let stillCardHeight: CGFloat = 88

    static func columns(count: Int, width: CGFloat) -> Int {
        if count <= 3 { return max(1, count) }
        if count == 4 { return 2 }
        // A preset's page is about 424 points wide: three cards still read there.
        return width >= 400 ? 3 : 2
    }

    var body: some View {
        let columns = Self.columns(count: cards.count, width: size.width)
        let rows = stride(from: 0, to: cards.count, by: columns).map { Array(cards[$0..<min($0 + columns, cards.count)]) }
        let fitted = (size.height - Self.spacing * CGFloat(max(0, rows.count - 1))) / CGFloat(max(1, rows.count))
        let height = min(Self.maximumCardHeight, max(Self.minimumCardHeight, fitted.isFinite ? fitted : Self.minimumCardHeight))
        let grid = VStack(spacing: Self.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: Self.spacing) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, card in
                        RecapCardView(card: card, locale: locale, order: rowIndex * columns + column, animated: animated)
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                    }
                }
            }
        }
        if fitted < Self.minimumCardHeight && animated {
            ScrollView(.vertical, showsIndicators: false) { grid }
        } else {
            grid
        }
    }
}

/// One source's card: tile and label on top, the figure, then its detail.
struct RecapCardView: View {
    let card: RecapCard
    let locale: Locale
    /// Its place in the arrival, 40 ms per step.
    var order = 0
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var arrived = false
    @State private var counted = false

    private var tint: Color { ZenithIslandPalette.color(hex: card.source.hex) }
    private var still: Bool { !animated || reduceMotion }

    /// The card's padding; the tile's corner stays concentric with it.
    static let inset: CGFloat = 10

    var body: some View {
        let inner = ZenithIsland.nestedRadius(padding: Self.inset)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                ZenithIslandGlyphTile(symbol: card.source.symbol, tint: tint, size: 18, cornerRadius: inner)
                Text(card.label.uppercased())
                    .font(ZenithType.mono(9.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(ZenithIsland.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 2)
            RecapCountUp(value: still || counted ? card.value : 0, figure: card.figure, locale: locale, size: 22)
                .animation(still ? nil : ZenithMotion.reveal(0.8), value: card.value)
            // Always a line, so the figures of a row sit level.
            detail
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.top, 1)
                .accessibilityHidden(card.notes.isEmpty)
        }
        .padding(Self.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // A soft wash of the source's colour, strongest at the top.
            RoundedRectangle(cornerRadius: ZenithIsland.cardRadius, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(contrast == .increased ? 0.16 : 0.10), tint.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .zenithIslandSoftCard()
        // Reduce Motion keeps the fade and drops the rise and the blur.
        .opacity(!animated || arrived ? 1 : 0)
        .blur(radius: still || arrived ? 0 : 8)
        .offset(y: still || arrived ? 0 : 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([card.label, RecapFormat.figure(card.value, card.figure, locale: locale), card.detail]
            .filter { !$0.isEmpty }.joined(separator: ", "))
        .onAppear(perform: arrive)
    }

    /// The notes in one line, a failure alone in the error colour.
    private var detail: Text {
        guard !card.notes.isEmpty else { return Text(verbatim: " ") }
        return card.notes.enumerated().reduce(Text(verbatim: "")) { line, item in
            let part = Text(verbatim: item.element.text)
                .foregroundColor(item.element.warns ? ZenithStatus.error : ZenithIsland.secondary)
            let joined = item.offset == 0 ? part : Text(verbatim: " · ").foregroundColor(ZenithIsland.meta) + part
            return line + joined
        }
    }

    private func arrive() {
        guard animated else { return }
        if reduceMotion {
            counted = true
            withAnimation(.easeOut(duration: ZenithMotion.fast)) { arrived = true }
            return
        }
        let delay = ZenithMotion.layerDelay(order)
        withAnimation(ZenithMotion.reveal(0.45).delay(delay)) { arrived = true }
        withAnimation(ZenithMotion.reveal(0.8).delay(delay + 0.05)) { counted = true }
    }
}

/// A figure that counts to its value: SwiftUI interpolates `value` frame by
/// frame and the reading follows in mono, a duration as `6h 11m`, a count
/// grouped as `1,248`.
struct RecapCountUp: View, Animatable {
    var value: Double
    let figure: RecapCard.Figure
    let locale: Locale
    var size: CGFloat = 24

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        ZenithFigure(text: RecapFormat.figure(value, figure, locale: locale), size: size)
            .monospacedDigit()
            .fixedSize()
    }
}

// MARK: - The band's actions

/// Copy as text and Save image, in the island's band above the page.
struct RecapPageActions: View {
    @ObservedObject private var service = RecapService.shared
    @ObservedObject private var wakaTime = WakaTimeService.shared
    @ObservedObject private var vercel = VercelService.shared
    @ObservedObject private var github = GitHubService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var copied = false
    @State private var saved: Bool?

    var body: some View {
        let text = ZenithStrings.recap(l10n.language)
        let empty = service.recap().isEmpty
        HStack(spacing: 2) {
            NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", title: copied ? text.copied : text.copyText) {
                service.copySummary { done in
                    guard done else { NSSound.beep(); return }
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
                }
            }
            NotchIconButton(symbol: saved == true ? "checkmark" : saved == false ? "exclamationmark.triangle" : "square.and.arrow.down",
                            title: saved == true ? text.saved : saved == false ? text.saveFailed : text.saveImage) {
                saved = RecapImageExport.save() != nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = nil }
            }
        }
        .disabled(empty)
    }
}

// MARK: - Save image

/// The recap as a still card, drawn by `ImageRenderer` into a PNG in Downloads.
enum RecapImageExport {
    static let width: CGFloat = 420

    @MainActor
    @discardableResult
    static func save(now: Date = Date()) -> URL? {
        let language = L10n.shared.language
        let locale = language.formattingLocale()
        let text = ZenithStrings.recap(language)
        let recap = RecapService.shared.recap(now: now)
        let cards = RecapFormat.cards(recap, text: text, language: language, locale: locale)
        guard !cards.isEmpty,
              let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        let card = RecapShareCard(cards: cards, title: text.title, date: formatter.string(from: now), locale: locale)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
        for copy in 1...99 {
            let url = folder.appendingPathComponent(RecapFormat.imageName(app: AppInfo.name, title: text.title,
                                                                          day: recap.day, copy: copy))
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch {
                return nil
            }
        }
        return nil
    }
}

/// The still card: the island's black, the page's heading, the same bento.
struct RecapShareCard: View {
    let cards: [RecapCard]
    let title: String
    let date: String
    let locale: Locale

    var body: some View {
        let columns = RecapBento.columns(count: cards.count, width: RecapImageExport.width - 32)
        let rows = Int((Double(cards.count) / Double(columns)).rounded(.up))
        let height = CGFloat(rows) * RecapBento.stillCardHeight + CGFloat(max(0, rows - 1)) * RecapBento.spacing
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ZenithIslandGlyphTile(symbol: NotchModule.recap.zenithIconSymbol, tint: NotchModule.recap.zenithTint, size: 26)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(ZenithIsland.primary)
                Spacer(minLength: 8)
                Text(date)
                    .font(ZenithType.mono(11, weight: .medium))
                    .foregroundStyle(ZenithIsland.meta)
            }
            RecapBento(cards: cards, size: CGSize(width: RecapImageExport.width - 32, height: height), locale: locale,
                       animated: false)
                .frame(height: height)
            Text(AppInfo.name.uppercased())
                .font(ZenithType.mono(9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(ZenithIsland.meta)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: RecapImageExport.width)
        .background(RoundedRectangle(cornerRadius: ZenithIsland.islandRadius, style: .continuous).fill(Color.black))
    }
}

// MARK: - Home widget

/// Today on the home page: the day's biggest figure and the next two.
struct RecapHomeWidget: View {
    let service: NotchService
    @ObservedObject private var recap = RecapService.shared
    @ObservedObject private var wakaTime = WakaTimeService.shared
    @ObservedObject private var vercel = VercelService.shared
    @ObservedObject private var github = GitHubService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let language = l10n.language
        let locale = language.formattingLocale()
        let text = ZenithStrings.recap(language)
        let today = recap.recap()
        let lead = RecapFormat.headlineOrder.first(where: today.sources.contains)
        let card = lead.flatMap { RecapFormat.card($0, today, text: text, language: language, locale: locale, sharing: false) }
        let rest = RecapFormat.headline(today, text: text, language: language, locale: locale).dropFirst()
        Button(action: { service.select(.recap) }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ZenithIslandIcon(symbol: ZenithHomeWidget.today.symbol, hex: ZenithHomeWidget.today.hex, size: 16, lifted: false)
                    Text(text.title.uppercased())
                        .font(ZenithType.mono(9.5, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(ZenithIsland.label)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .frame(height: 16)
                if let card {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        RecapCountUp(value: card.value, figure: card.figure, locale: locale, size: 20)
                            .animation(reduceMotion ? nil : ZenithMotion.reveal(0.8), value: card.value)
                        Text(card.label)
                            .font(.system(size: 10.5))
                            .foregroundStyle(ZenithIsland.secondary)
                            .lineLimit(1)
                    }
                    Text(rest.joined(separator: " · "))
                        .font(.system(size: 10.5))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(verbatim: "--")
                        .font(ZenithType.mono(20, weight: .semibold))
                        .foregroundStyle(ZenithIsland.meta)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .environment(\.locale, locale)
        .onAppear { recap.viewAppeared() }
        .onDisappear { recap.viewDisappeared() }
    }
}
