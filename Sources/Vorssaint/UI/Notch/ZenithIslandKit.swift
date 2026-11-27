// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the open island's second component set, after p441z.my.id's
// Resume page. Pages stop being stacks of boxed cards: they become a bento
// grid laid straight on the island, its cells parted by hairlines, each cell
// headed by a mono label with its metadata at the far end. Hero numbers are
// set in SF Mono with their unit smaller and dimmer; levels are 3-point
// capsules; choices sit in a dark segmented well whose active block slides;
// live states are small glowing dots; tags are outlined mono capsules.
//
// The values are chosen to read on pure black and on the translucent grey a
// glass island shows over a bright wallpaper: hairlines at 12% rather than
// faint fills, and no card lifts at all.
//
// The test executable compiles this file (build.sh, TEST_SOURCES) because
// several island declarations copied into it draw with these pieces: keep it
// free of anything outside SwiftUI, AppKit, `ZenithTokens`/`ZenithIsland`,
// `ZenithIslandSilhouette` and `ZenithIslandInset` (ZenithIslandRoom.swift).
//
// The third pass (after a reference island studied frame by frame) adds
// concentric radii, bento cells as soft rounded cards, the morph every
// content swap goes through, and tinted glyph tiles for the modules' own
// colours.

// MARK: - Values

extension ZenithIsland {
    /// A bento cell's mono heading and the metadata at its far end.
    static let label = Color.white.opacity(0.45)
    static let meta = Color.white.opacity(0.35)

    /// The line between bento cells, and the one Increase Contrast asks for.
    static let divider = Color.white.opacity(0.12)
    static let contrastDivider = Color.white.opacity(0.4)

    /// A row or a cell under the pointer, and the keyboard's cursor.
    static let rowHover = Color.white.opacity(0.06)
    static let cursorFill = Color.white.opacity(0.10)
    static let cursorStroke = Color.white.opacity(0.3)

    /// A level: its fill over its track.
    static let barFill = Color.white.opacity(0.85)
    static let barTrack = Color.white.opacity(0.10)

    /// A chart's bars, and the current or highlighted one.
    static let chartBar = Color.white.opacity(0.25)
    static let chartHighlight = Color.white.opacity(0.9)

    static func divider(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? contrastDivider : divider
    }

    /// A data colour (a language, a provider) pulled toward grey, so it still
    /// tells one series from another without shouting over the page.
    static func muted(_ color: Color) -> Color { color.opacity(0.72) }
}

// MARK: - Concentric radii

extension ZenithIsland {
    /// The open island's bottom corner, which everything inside it nests in.
    static var islandRadius: CGFloat { ZenithIslandSilhouette.openCornerRadius }
    /// From the island's side and bottom to its page: the open island's one
    /// padding (`ZenithIslandInset.padding`), past its 27-point shoulder.
    static var pageInset: CGFloat { ZenithIslandInset.padding }

    /// The radius of a surface `depth` points inside one of radius `outer`,
    /// so the two curves run parallel: outer less the inset, never below
    /// `minimum`, where a curve would pinch to a point.
    static func innerRadius(depth: CGFloat, outer: CGFloat = islandRadius,
                            minimum: CGFloat = ZenithRadius.small) -> CGFloat {
        ZenithIslandInset.concentricRadius(inset: depth, outer: outer, minimum: minimum)
    }

    /// A card laid on a page, concentric with the island's corner (20).
    static var cardRadius: CGFloat { innerRadius(depth: pageInset) }

    /// Something inside such a card, `padding` in from its edge.
    static func nestedRadius(padding: CGFloat) -> CGFloat { innerRadius(depth: padding, outer: cardRadius) }

    /// A card's soft fill and its hairline on the island's black.
    static let cardFill = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)
}

/// A soft rounded card: a faint white fill under a fainter hairline, its
/// corner concentric with the island's. Increase Contrast draws the outline.
struct ZenithIslandSoftCard: ViewModifier {
    var cornerRadius: CGFloat = ZenithIsland.cardRadius
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(ZenithIsland.cardFill, in: shape)
            .overlay {
                shape.strokeBorder(contrast == .increased ? ZenithIsland.contrastHairline : ZenithIsland.cardStroke,
                                   lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Lays this view on a soft rounded card concentric with the island.
    func zenithIslandSoftCard(cornerRadius: CGFloat = ZenithIsland.cardRadius) -> some View {
        modifier(ZenithIslandSoftCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glyph tiles

extension ZenithIsland {
    /// A tinted tile's fill and outline: soft enough that the glyph in its
    /// full colour carries it, firmer with Increase Contrast.
    static func tileFill(_ tint: Color, contrast: ColorSchemeContrast = .standard) -> Color {
        tint.opacity(contrast == .increased ? 0.3 : 0.18)
    }

    static func tileStroke(_ tint: Color, contrast: ColorSchemeContrast = .standard) -> Color {
        tint.opacity(contrast == .increased ? 0.55 : 0.24)
    }
}

/// A module's glyph on a rounded tile. With a `tint` (a module's identity
/// colour, `NotchModule.zenithTint`) the glyph wears it over a soft tile of
/// the same hue; without one it is the monochrome glyph on a faint white tile.
struct ZenithIslandGlyphTile: View {
    let symbol: String
    var tint: Color? = nil
    var size: CGFloat = 28
    /// The tile's corner; by default a continuous corner about a third of its side.
    var cornerRadius: CGFloat? = nil
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius ?? (size * 0.3).rounded(), style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: (size * 0.46).rounded(), weight: .semibold))
            .foregroundStyle(tint ?? ZenithIsland.primary)
            .frame(width: size, height: size)
            .background(tint.map { ZenithIsland.tileFill($0, contrast: contrast) } ?? ZenithIsland.cardFill, in: shape)
            .overlay {
                shape.strokeBorder(tint.map { ZenithIsland.tileStroke($0, contrast: contrast) }
                                       ?? ZenithIsland.outline(contrast), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Bento

/// The hairline between bento cells. It sits centred in the gap the layout
/// already keeps, so a page that spaced its cards apart keeps its height and
/// draws the line where the gap was.
struct ZenithBentoDivider: View {
    /// `.horizontal` runs across, between rows; `.vertical` runs down,
    /// between the cells of a row.
    let axis: Axis
    /// The room the line is centred in.
    var gap: CGFloat = 1
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ axis: Axis, gap: CGFloat = 1) {
        self.axis = axis
        self.gap = gap
    }

    var body: some View {
        let line = Rectangle().fill(ZenithIsland.divider(contrast))
        Group {
            if axis == .horizontal {
                line.frame(height: 1).frame(maxWidth: .infinity).frame(height: max(1, gap))
            } else {
                line.frame(width: 1).frame(maxHeight: .infinity).frame(width: max(1, gap))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A bento cell's heading: a mono capital label at the leading edge, an
/// optional glyph before it, and whatever the cell wants at the trailing
/// edge (mono metadata, a tag, a small control).
struct ZenithBentoHeader<Trailing: View>: View {
    let label: String
    var symbol: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(ZenithIsland.label)
                    .frame(width: 12)
                    .accessibilityHidden(true)
            }
            Text(label)
                .modifier(ZenithBentoLabelStyle())
                .lineLimit(1)
            Spacer(minLength: 6)
            trailing()
        }
        .frame(height: 14)
    }
}

extension ZenithBentoHeader where Trailing == ZenithBentoMeta {
    init(label: String, symbol: String? = nil, meta: String?) {
        self.init(label: label, symbol: symbol) { ZenithBentoMeta(text: meta) }
    }
}

extension ZenithBentoHeader where Trailing == EmptyView {
    init(label: String, symbol: String? = nil) {
        self.init(label: label, symbol: symbol) { EmptyView() }
    }
}

/// Mono metadata at the trailing edge of a heading, or anywhere a time, a
/// count or a key stands beside words.
struct ZenithBentoMeta: View {
    let text: String?
    var size: CGFloat = 10

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(ZenithType.mono(size))
                .monospacedDigit()
                .foregroundStyle(ZenithIsland.meta)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// The bento label's look: 10-point mono capitals, tracked 0.6, at 45%.
struct ZenithBentoLabelStyle: ViewModifier {
    var color: Color = ZenithIsland.label

    func body(content: Content) -> some View {
        content
            .font(ZenithType.mono(10, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

/// One bento cell: its heading, then its content, with generous padding and
/// nothing drawn around it. Dividers come from the grid it sits in.
struct ZenithBentoCell<Trailing: View, Content: View>: View {
    let label: String?
    var symbol: String? = nil
    var padding = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    var spacing: CGFloat = 8
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let label {
                ZenithBentoHeader(label: label, symbol: symbol, trailing: trailing)
            }
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension ZenithBentoCell where Trailing == ZenithBentoMeta {
    init(label: String?, symbol: String? = nil, meta: String? = nil,
         padding: EdgeInsets = EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12),
         spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.init(label: label, symbol: symbol, padding: padding, spacing: spacing,
                  trailing: { ZenithBentoMeta(text: meta) }, content: content)
    }
}

/// Rows of cells, each on a soft rounded card concentric with the island,
/// `spacing` apart. The gaps are the ones the second pass's hairlines sat
/// in, so a page keeps its measurements. Cells in a row share its height;
/// `rowHeight` fixes it where the page has measured one.
struct ZenithBentoGrid<Item: Identifiable, Cell: View>: View {
    let rows: [[Item]]
    var spacing: CGFloat = 1
    var rowHeight: (([Item]) -> CGFloat?)? = nil
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
        }
    }

    @ViewBuilder private func rowView(_ row: [Item]) -> some View {
        let height = rowHeight?(row) ?? nil
        HStack(spacing: spacing) {
            ForEach(row) { item in
                cell(item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .zenithIslandSoftCard()
            }
        }
        .frame(height: height)
        .fixedSize(horizontal: false, vertical: height == nil)
    }
}

/// A cell that opens something: a faint wash under the pointer, never a lift
/// or a scale. The content draws itself.
struct ZenithBentoButtonStyle: ButtonStyle {
    /// Concentric with a soft card, 3 points inside it (17).
    var cornerRadius: CGFloat = ZenithIsland.nestedRadius(padding: 3)

    func makeBody(configuration: Configuration) -> some View {
        ZenithBentoButton(label: configuration.label, isPressed: configuration.isPressed, cornerRadius: cornerRadius)
    }
}

private struct ZenithBentoButton<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let cornerRadius: CGFloat
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        label
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isPressed ? ZenithIsland.cursorFill : hovering ? ZenithIsland.rowHover : .clear)
                    .padding(3)
            }
            .environment(\.zenithIslandHovered, hovering && enabled)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

// MARK: - Figures

/// A hero number in SF Mono, semibold and tightly tracked, with its unit (a
/// percent sign, "GB", "h", "↓") smaller and dimmer beside it. A reading is
/// split into its figures and the words around them, so "21%", "2h 13m",
/// "↓ 1.2 MB/s" and "$4.20" all read with the digits large.
struct ZenithFigure: View {
    let text: String
    var size: CGFloat = 22
    var tint: Color = ZenithIsland.primary
    /// The unit's size against the figure's.
    var unitScale: CGFloat = 0.55

    var body: some View {
        Self.compose(text, size: size, unitScale: unitScale, tint: tint)
            .tracking(-0.5)
            .lineLimit(1)
    }

    static func font(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static func unitFont(_ size: CGFloat, scale: CGFloat = 0.55) -> Font {
        .system(size: max(9, (size * scale).rounded()), weight: .medium, design: .monospaced)
    }

    /// The reading as one `Text`, so it scales, transitions and reads to
    /// VoiceOver as one.
    static func compose(_ text: String, size: CGFloat, unitScale: CGFloat = 0.55,
                        tint: Color = ZenithIsland.primary) -> Text {
        let parts = runs(text)
        guard parts.contains(where: \.figure) else {
            return Text(verbatim: text).font(font(size)).foregroundStyle(tint)
        }
        return parts.reduce(Text(verbatim: "")) { sum, part in
            let piece = part.figure
                ? Text(verbatim: part.text).font(font(size)).foregroundStyle(tint)
                : Text(verbatim: part.text).font(unitFont(size, scale: unitScale)).foregroundStyle(ZenithIsland.label)
            return Text("\(sum)\(piece)")
        }
    }

    /// The reading cut into runs of figures (digits with their separators)
    /// and of everything else.
    static func runs(_ text: String) -> [(text: String, figure: Bool)] {
        var runs: [(text: String, figure: Bool)] = []
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            let figure: Bool
            if character.isNumber {
                figure = true
            } else if ".,:".contains(character) || character == "\u{202F}" || character == "\u{00A0}" {
                // A separator belongs to the figure only between two digits.
                let before = index > 0 && characters[index - 1].isNumber
                let after = index + 1 < characters.count && characters[index + 1].isNumber
                figure = before && after
            } else {
                figure = false
            }
            if let last = runs.last, last.figure == figure {
                runs[runs.count - 1].text.append(character)
            } else {
                runs.append((String(character), figure))
            }
        }
        return runs
    }
}

// MARK: - Bars and charts

/// A level as a 3-point capsule: white over a faint track, or a status
/// colour when the level is a warning or an error.
struct ZenithDataBar: View {
    let value: Double
    /// `ZenithStatus.warning` or `.error` when the level means trouble.
    var status: Color? = nil
    var height: CGFloat = 3
    /// A tick where an even pace would be, as the AI limits draw one.
    var pace: Double? = nil

    var body: some View {
        let fraction = value.isFinite ? min(1, max(0, value)) : 0
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(ZenithIsland.barTrack)
                Capsule(style: .continuous)
                    .fill(status ?? ZenithIsland.barFill)
                    .frame(width: max(fraction > 0 ? height : 0, proxy.size.width * fraction))
                if let pace, pace.isFinite, pace > 0.02, pace < 0.98 {
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 1.5, height: height + 5)
                        .offset(x: proxy.size.width * pace - 0.75)
                }
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: pace == nil ? height : height + 5)
        .accessibilityHidden(true)
    }
}

/// A chart bar: thin, its top rounded and its foot square on the axis.
struct ZenithChartBar: View {
    /// Of the chart's height, 0 to 1.
    let fraction: Double
    var highlighted = false
    var tint: Color? = nil
    var minimum: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let height = max(minimum, proxy.size.height * CGFloat(fraction.isFinite ? min(1, max(0, fraction)) : 0))
            let radius = min(2, proxy.size.width / 2)
            UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
                .fill(tint ?? (highlighted ? ZenithIsland.chartHighlight : ZenithIsland.chartBar))
                .frame(height: height)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Segmented control

/// Choices in a dark rounded well, after the portfolio's switcher: the
/// chosen one is a solid block with a hairline and white words, sliding to a
/// new choice on the toggle curve (still under Reduce Motion); the others
/// read at half strength. No accent.
struct ZenithSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    var height: CGFloat = 26
    var fontSize: CGFloat = 11.5
    /// Words read in SF Pro, as the portfolio's switcher does; mono for codes.
    var mono = false
    /// Equal segments across the well, or each as wide as its words.
    var fills = true
    @Namespace private var segment
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                ZenithSegment(title: option.title, selected: option.value == selection,
                              namespace: segment, fontSize: fontSize, mono: mono, fills: fills) {
                    guard option.value != selection else { return }
                    withAnimation(ZenithMotion.respecting(IslandMotion.toggle())) { selection = option.value }
                }
            }
        }
        .padding(3)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: ZenithRadius.large + 1, style: .continuous)
            .fill(Color.white.opacity(0.07)))
        .overlay {
            RoundedRectangle(cornerRadius: ZenithRadius.large + 1, style: .continuous)
                .strokeBorder(contrast == .increased ? ZenithIsland.contrastDivider : Color.white.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct ZenithSegment: View {
    let title: String
    let selected: Bool
    let namespace: Namespace.ID
    let fontSize: CGFloat
    let mono: Bool
    let fills: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(mono ? ZenithType.mono(fontSize, weight: .medium) : .system(size: fontSize, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Color.white.opacity(0.95) : Color.white.opacity(hovering ? 0.75 : 0.5))
                .padding(.horizontal, 8)
                .frame(maxWidth: fills ? .infinity : nil, maxHeight: .infinity)
                .background {
                    if selected {
                        let shape = RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous)
                        shape.fill(Color.white.opacity(0.14))
                            .overlay(shape.strokeBorder(Color.white.opacity(contrast == .increased ? 0.45 : 0.12),
                                                        lineWidth: 1))
                            .matchedGeometryEffect(id: "segment", in: namespace)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Status dots

/// A live state as a small dot in its meaning colour, glowing softly while
/// the state is live, as the portfolio marks the current entry of its
/// timeline. Always beside words that say the same.
struct ZenithStatusDot: View {
    let color: Color
    var live = false
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background {
                if live {
                    Circle().fill(color.opacity(0.28)).frame(width: size * 2.2, height: size * 2.2)
                }
            }
            .shadow(color: live ? color.opacity(0.75) : .clear, radius: live ? size * 0.6 : 0)
            .frame(width: size * 2, height: size * 2)
            .accessibilityHidden(true)
    }
}

/// A status line: its dot, then the words in mono where they are metadata.
struct ZenithStatusLine: View {
    let color: Color
    let text: String
    var live = false
    var mono = true
    var size: CGFloat = 11
    var emphasised = false

    var body: some View {
        HStack(spacing: 4) {
            ZenithStatusDot(color: color, live: live)
            Text(text)
                .font(mono ? ZenithType.mono(size, weight: emphasised ? .medium : .regular)
                      : .system(size: size, weight: emphasised ? .semibold : .regular))
                .foregroundStyle(emphasised ? ZenithIsland.primary : ZenithIsland.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Command rows

/// A row of the section gallery's command palette: a glyph (on a soft tile
/// of the module's colour when it has a `tint`, otherwise monochrome), the
/// module's name and its shortcut in dim mono at the far end. The pointer
/// washes it; the current module wears a 2-point accent bar at its leading
/// edge (and an accent glyph without a tint); the keyboard's cursor is a
/// brighter fill under a 1-point outline, so it reads apart from both.
struct ZenithCommandRow: View {
    let symbol: String
    let title: String
    let shortcut: String
    let highlighted: Bool
    let current: Bool
    var height: CGFloat = 30
    /// The module's identity colour: the glyph then sits on its soft tinted
    /// tile (`ZenithIslandGlyphTile`); without one, the plain glyph.
    var tint: Color? = nil
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    /// The tinted tile's side in a row.
    static let tileSize: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
        HStack(spacing: tint == nil ? 10 : 9) {
            if let tint {
                ZenithIslandGlyphTile(symbol: symbol, tint: tint, size: Self.tileSize, cornerRadius: 6.5)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(current ? ZenithIsland.accent : hovering || highlighted ? ZenithIsland.primary
                                     : ZenithIsland.secondary)
                    .frame(width: 16, height: 16)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            Text(shortcut)
                .font(ZenithType.mono(10.5))
                .foregroundStyle(ZenithIsland.meta)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, tint == nil ? 12 : 9)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(shape.fill(highlighted ? ZenithIsland.cursorFill : hovering ? ZenithIsland.rowHover : .clear))
        .overlay {
            shape.strokeBorder(highlighted ? (contrast == .increased ? Color.white.opacity(0.6) : ZenithIsland.cursorStroke)
                               : .clear, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            if current {
                Capsule().fill(ZenithIsland.accent).frame(width: 2, height: height - 12).padding(.leading, 3)
            }
        }
        .contentShape(shape)
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

// MARK: - Drop zones

extension View {
    /// A place to drop files: a dashed hairline, brighter while a drag is over it.
    func zenithDropZone(targeted: Bool = false, cornerRadius: CGFloat = ZenithRadius.card) -> some View {
        modifier(ZenithDropZone(targeted: targeted, cornerRadius: cornerRadius))
    }
}

private struct ZenithDropZone: ViewModifier {
    let targeted: Bool
    let cornerRadius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(targeted ? ZenithIsland.rowHover : .clear))
            .overlay {
                shape.strokeBorder(targeted ? Color.white.opacity(0.5)
                                   : contrast == .increased ? ZenithIsland.contrastDivider : Color.white.opacity(0.2),
                                   style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .allowsHitTesting(false)
            }
    }
}

// MARK: - Charts

/// How the island's charts draw their bars.
enum ZenithChart {
    /// A bar a little over half its slot, never wider than 10 points.
    static func barWidth(slot: CGFloat) -> CGFloat {
        max(1, min(10, slot < 4 ? slot : (slot * 0.6).rounded()))
    }

    /// A bar of one series in white, or of several in their colours pulled
    /// toward grey; the current or pointed-at bar at full strength.
    static func agentFill(_ tint: Color?, bright: Bool) -> Color {
        guard let tint else { return bright ? ZenithIsland.chartHighlight : ZenithIsland.chartBar }
        return tint.opacity(bright ? 0.9 : 0.4)
    }
}

// MARK: - Readings

/// A reading cell of the System page: its mono heading with an arrow that
/// shows under the pointer (the cell opens a detail), the reading large in
/// mono, and a 3-point level or a line of detail under it.
struct ZenithSystemCell: View {
    let title: String
    let symbol: String
    let value: String?
    var detail: String? = nil
    var level: Double? = nil
    /// The level is the news: a low battery, a busy processor.
    var attention = false
    @Environment(\.zenithIslandHovered) private var hovered
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZenithBentoHeader(label: title, symbol: symbol) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(ZenithIsland.secondary)
                    .opacity(hovered ? 1 : 0)
            }
            Spacer(minLength: 2)
            ZenithFigure(text: value ?? "…", size: detail == nil ? 24 : 19)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : IslandMotion.smooth(0.25), value: value)
            Spacer(minLength: 2)
            if let detail {
                Text(detail).font(ZenithType.mono(10)).foregroundStyle(ZenithIsland.meta).lineLimit(1)
            } else if let level {
                ZenithDataBar(value: level, status: attention ? ZenithStatus.warning : nil)
            } else {
                Color.clear.frame(height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Sheets and tabs

/// A writing surface laid on the island (the scratchpad): a hairline above
/// it and the portfolio's faint dot grid behind the text, with no box.
struct ZenithIslandSheet: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .top) {
                    ZenithDotGrid(spacing: 18, dot: 1.2)
                    ZenithBentoDivider(.horizontal)
                }
            }
    }
}

/// A tab that can be the open one, as the segmented control's active block:
/// a solid white 14% capsule under a hairline, the rest bare.
struct ZenithIslandTabBlock: ViewModifier {
    let selected: Bool
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(Capsule().fill(selected ? Color.white.opacity(0.14) : hovering ? ZenithIsland.rowHover : .clear))
            .overlay {
                Capsule().strokeBorder(selected ? Color.white.opacity(contrast == .increased ? 0.45 : 0.12) : .clear,
                                       lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

// MARK: - Actions

/// The page's one main step as a button: words on the solid capsule.
struct ZenithIslandPrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: height)
            .modifier(ZenithIslandPrimaryAction())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}

/// A page's one main step (Start): a solid near-white capsule with dark
/// words, which reads on black and on a translucent grey island alike.
struct ZenithIslandPrimaryAction: ViewModifier {
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.black.opacity(0.88))
            .background(Capsule().fill(Color.white.opacity(hovering ? 1 : 0.9)))
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

/// A round transport control (pause, resume): a white glyph in a hairline
/// circle that takes a faint wash under the pointer.
struct ZenithIslandRoundControl: ViewModifier {
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(ZenithIsland.primary)
            .background(Circle().fill(hovering ? ZenithIsland.rowHover : .clear))
            .overlay {
                Circle().strokeBorder(contrast == .increased ? ZenithIsland.contrastHairline
                                      : Color.white.opacity(hovering ? 0.4 : 0.24), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

// MARK: - Home

/// A shortcut's glyph on the home page: plain, with no well. An active one
/// (Keep Awake on, the microphone muted, a recording, a timer) takes its
/// colour and a small glowing dot at its corner; its symbol changes too, so
/// the state never rests on colour alone.
struct ZenithIslandShortcutGlyph: ViewModifier {
    let active: Bool
    let tint: Color
    @Environment(\.zenithIslandHovered) private var hovered

    func body(content: Content) -> some View {
        content
            .foregroundStyle(active ? tint : hovered ? ZenithIsland.primary : Color.white.opacity(0.8))
            .overlay(alignment: .topTrailing) {
                if active {
                    ZenithStatusDot(color: tint, live: true, size: 5).offset(x: 2, y: 2)
                }
            }
    }
}

/// A row laid across the page with no box (the home page's player): a
/// hairline under it, centred in the gap that parts it from the next row.
struct ZenithIslandBand: ViewModifier {
    var gap: CGFloat = 10

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZenithBentoDivider(.horizontal).offset(y: gap / 2 + 0.5)
        }
    }
}
