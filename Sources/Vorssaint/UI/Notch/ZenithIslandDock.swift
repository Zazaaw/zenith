// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the open island's tab pill. A small black capsule floats just
// below the island, apart from it, with Home, Files (the Shelf, with a count
// of what it holds), the page on screen when it is neither (in its own
// colour) and the section gallery. The chosen tab sits in a grey capsule that
// slides between them.
//
// It is drawn in the island's own window, on the floating-controls layer
// that already reaches below the island (`NotchQuickAccessContainer`), so it
// follows the island to its display, hides for Mission Control with it, and a
// click on it is a click on the island, which never closes it. The window
// reserves room for it below the island only while it shows; elsewhere the
// window stays as it was.
//
// The island's top row no longer repeats the gallery's button; the pill, the
// island's menu, Command-K and the module shortcuts all still reach it.

enum ZenithIslandDockLayout {
    static let height: CGFloat = 26
    /// From the island's bottom edge to the pill. A reference island leaves
    /// about 15 points; the pill reads as the island's own a little closer.
    static let gap: CGFloat = 12
    static let padding: CGFloat = 3
    static let segmentHeight: CGFloat = height - padding * 2
    static let segmentMinimumWidth: CGFloat = 34
    static let segmentSpacing: CGFloat = 2
    static let glyphSize: CGFloat = 11.5
    static let badgeSize: CGFloat = 15
    /// Below the pill, room for its shadow.
    static let bottomMargin: CGFloat = 10
    /// The widest the pill gets: four tabs and a badge, with room to spare.
    static let maximumWidth: CGFloat = 220
    /// Around the pill the pointer still counts as over the island.
    static let hoverMargin: CGFloat = 14

    /// From the island's bottom to the pill's top: below the floating
    /// buttons when some sit under the island.
    static func offset(belowQuickAccess: Bool) -> CGFloat {
        belowQuickAccess ? NotchQuickAccessLayout.gap + NotchQuickAccessLayout.diameter + gap : gap
    }

    /// The room the window keeps below the island for the pill.
    static func reservation(belowQuickAccess: Bool) -> CGFloat {
        offset(belowQuickAccess: belowQuickAccess) + height + bottomMargin
    }

    /// One corridor from the island's bottom edge down past the pill, so the
    /// pointer crossing the gap never leaves the island.
    static func hoverRect(anchor: CGPoint, belowQuickAccess: Bool) -> CGRect {
        let top = anchor.y - offset(belowQuickAccess: belowQuickAccess)
        return CGRect(x: anchor.x - maximumWidth / 2, y: top,
                      width: maximumWidth, height: anchor.y + height - top)
            .insetBy(dx: -hoverMargin, dy: -hoverMargin)
    }
}

/// Only the transition owns the pill's motion: where it hangs, whether it
/// shows, and the frame it was last drawn at, which clicks are tested against.
final class ZenithIslandDockMotion: ObservableObject {
    /// The pill's top centre, in the floating layer's coordinates.
    @Published private(set) var anchor = CGPoint.zero
    @Published private(set) var visible = false
    /// How long the pill waits before arriving, so its tabs can follow it.
    @Published private(set) var arrivalDelay: TimeInterval = 0
    private(set) var interactive = false
    private(set) var belowQuickAccess = false
    /// The pill as laid out, in the same coordinates.
    var pillFrame = CGRect.null
    private var body = CGRect.zero

    /// Hangs the pill below an island whose body is `body`. A resize moves
    /// it on the spring that carries the island's sides.
    func configure(body: CGRect, belowQuickAccess: Bool, animated: Bool) {
        let anchor = CGPoint(x: body.midX.rounded(), y: body.maxY + ZenithIslandDockLayout.offset(belowQuickAccess: belowQuickAccess))
        self.belowQuickAccess = belowQuickAccess
        guard anchor != self.anchor else { self.body = body; return }
        let spring = NotchMotion.sideSpring(from: self.body.size, to: body.size)
        let animation: Animation? = animated && visible ? .spring(duration: spring.duration, bounce: spring.bounce) : nil
        self.body = body
        withAnimation(animation) { self.anchor = anchor }
    }

    /// The pill arrives on the morph's spring, blurred and a little small,
    /// once the island has nearly opened; it leaves quickly as the island closes.
    func setVisible(_ visible: Bool, animated: Bool, delay: TimeInterval = 0) {
        guard self.visible != visible else { return }
        interactive = visible
        if visible { arrivalDelay = animated ? delay : 0 }
        let still = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let animation: Animation? = animated
            ? (visible ? ZenithMorph.animation(reduceMotion: still).delay(delay) : .easeIn(duration: Self.departure))
            : nil
        withAnimation(animation) { self.visible = visible }
    }

    static let departure: TimeInterval = 0.16

    var hoverRect: CGRect? {
        visible ? ZenithIslandDockLayout.hoverRect(anchor: anchor, belowQuickAccess: belowQuickAccess) : nil
    }

    func contains(_ point: CGPoint) -> Bool {
        interactive && !pillFrame.isNull && pillFrame.insetBy(dx: -2, dy: -2).contains(point)
    }
}

/// The pill's hosting view spans the floating layer's stage, as the
/// floating buttons' does, and takes only the clicks that land on the pill.
final class ZenithIslandDockHost: NSHostingView<AnyView> {
    weak var motion: ZenithIslandDockMotion?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let motion, motion.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point)
    }
}

enum ZenithIslandDockItem: Hashable, Identifiable {
    case home, files, page(NotchModule), sections
    var id: Self { self }
}

struct ZenithIslandDockView: View {
    @ObservedObject var service: NotchService
    @ObservedObject var motion: ZenithIslandDockMotion
    @ObservedObject private var shelf = ShelfService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Namespace private var selection
    /// What the pill shows, moved on the morph's spring rather than with the
    /// island's page, which changes with animations switched off.
    @State private var shown: Tabs?

    private static let space = "zenith.island.dock"

    struct Tabs: Equatable {
        var items: [ZenithIslandDockItem]
        var chosen: ZenithIslandDockItem?
        var detail: Bool
    }

    private var current: Tabs {
        let modules = service.modules
        let detail = service.showingAppPanel || service.selectedMetric != nil
        var items: [ZenithIslandDockItem] = []
        if modules.contains(.controls) { items.append(.home) }
        if modules.contains(.files) { items.append(.files) }
        var chosen: ZenithIslandDockItem? = service.showingSections ? .sections : nil
        if !service.showingSections {
            let page = service.selected
            if !detail, page == .controls, items.contains(.home) { chosen = .home }
            else if !detail, page == .files, items.contains(.files) { chosen = .files }
            else { items.append(.page(page)); chosen = .page(page) }
        }
        items.append(.sections)
        return Tabs(items: items, chosen: chosen, detail: detail)
    }

    var body: some View {
        let tabs = shown ?? current
        ZStack(alignment: .topLeading) {
            Color.clear
            pill(tabs)
                .fixedSize()
                .modifier(ZenithIslandDockEntrance(shown: motion.visible, still: reduceMotion))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { motion.pillFrame = $0 }
                .position(x: motion.anchor.x, y: motion.anchor.y + ZenithIslandDockLayout.height / 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(name: Self.space)
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .tint(.white)
        .allowsHitTesting(motion.visible)
        .accessibilityHidden(!motion.visible)
        .onAppear { shown = current }
        .onChange(of: current) { _, next in
            // A fresh transaction: the island changes its page with
            // animations disabled, and the pill still slides to it.
            withTransaction(Transaction(animation: motion.visible ? ZenithMorph.animation(reduceMotion: reduceMotion) : nil)) {
                shown = next
            }
        }
    }

    private func pill(_ tabs: Tabs) -> some View {
        HStack(spacing: ZenithIslandDockLayout.segmentSpacing) {
            ForEach(Array(tabs.items.enumerated()), id: \.element) { index, item in
                tab(item, chosen: tabs.chosen == item, detail: tabs.detail)
                    .modifier(ZenithIslandDockEntrance(shown: motion.visible, still: reduceMotion, tab: true))
                    // Each tab follows the pill in, 40 ms after the one before.
                    .animation(motion.visible
                                   ? ZenithMorph.animation(reduceMotion: reduceMotion)
                                       .delay(motion.arrivalDelay + ZenithMotion.layerDelay(index + 1))
                                   : .easeIn(duration: ZenithIslandDockMotion.departure),
                               value: motion.visible)
                    .transition(.zenithMorph(reduceMotion: reduceMotion))
            }
        }
        .padding(ZenithIslandDockLayout.padding)
        .frame(height: ZenithIslandDockLayout.height)
        .background(Color.black, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(contrast == .increased ? 0.4 : 0.1), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FeatureStrings.notch(l10n.language).switchSection)
    }

    private func tab(_ item: ZenithIslandDockItem, chosen: Bool, detail: Bool) -> some View {
        let count = shelf.items.count
        let title = title(item, detail: detail)
        return Button { activate(item, detail: detail) } label: {
            HStack(spacing: 5) {
                ZenithIslandDockGlyph(symbol: symbol(item, detail: detail), tint: tint(item), chosen: chosen)
                if item == .files, count > 0 {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(ZenithType.mono(9.5, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 4)
                        .frame(minWidth: ZenithIslandDockLayout.badgeSize, minHeight: ZenithIslandDockLayout.badgeSize)
                        .background(Color.white.opacity(0.14), in: Capsule())
                        .animation(ZenithMotion.respecting(.snappy(duration: 0.28)), value: count)
                }
            }
            .padding(.horizontal, 10)
            .frame(minWidth: ZenithIslandDockLayout.segmentMinimumWidth)
            .frame(height: ZenithIslandDockLayout.segmentHeight)
            .background {
                if chosen {
                    Capsule()
                        .fill(Color.white.opacity(contrast == .increased ? 0.24 : 0.14))
                        .matchedGeometryEffect(id: "chosen", in: selection)
                }
            }
            .contentShape(Capsule())
            .zenithIslandHoverTracked()
        }
        .buttonStyle(ZenithIslandDockButtonStyle())
        .help(shortcut(item).map { "\(title)  \($0)" } ?? title)
        .accessibilityLabel(title)
        .accessibilityValue(item == .files && count > 0 ? "\(count)" : "")
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier("notch.dock.\(identifier(item))")
        .modifier(ZenithDockHomeMenu(home: item == .home, service: service))
    }

    private func module(_ item: ZenithIslandDockItem) -> NotchModule? {
        switch item {
        case .home: return .controls
        case .files: return .files
        case .page(let module): return module
        case .sections: return nil
        }
    }

    private func symbol(_ item: ZenithIslandDockItem, detail: Bool) -> String {
        switch item {
        case .home: return "house.fill"
        case .files: return "tray.fill"
        case .page(let module): return detail && service.showingAppPanel ? "macwindow" : module.symbol
        case .sections: return "square.grid.2x2.fill"
        }
    }

    private func tint(_ item: ZenithIslandDockItem) -> Color {
        module(item)?.zenithTint ?? ZenithIsland.primary
    }

    private func title(_ item: ZenithIslandDockItem, detail: Bool) -> String {
        let language = l10n.language
        switch item {
        case .sections: return FeatureStrings.notch(language).sectionsTitle
        case .page(let module) where detail: return service.detailTitle.isEmpty ? module.title(language) : service.detailTitle
        default: return module(item)?.title(language) ?? ""
        }
    }

    private func shortcut(_ item: ZenithIslandDockItem) -> String? {
        if item == .sections { return "⌘K" }
        return module(item).map { "⌥⌘\($0.shortcutKey.uppercased())" }
    }

    private func identifier(_ item: ZenithIslandDockItem) -> String {
        switch item {
        case .home: return "home"
        case .files: return "files"
        case .page: return "page"
        case .sections: return "sections"
        }
    }

    private func activate(_ item: ZenithIslandDockItem, detail: Bool) {
        switch item {
        case .home: service.select(.controls)
        case .files: service.select(.files)
        case .sections: service.toggleSections()
        case .page(let module): if detail { service.goBack() } else { service.select(module) }
        }
    }
}

/// A tab's glyph: grey at rest, bright under the pointer, and the module's
/// own colour on the chosen tab.
private struct ZenithIslandDockGlyph: View {
    let symbol: String
    let tint: Color
    let chosen: Bool
    @Environment(\.zenithIslandHovered) private var hovered

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: ZenithIslandDockLayout.glyphSize, weight: .semibold))
            .foregroundStyle(chosen ? tint : hovered ? ZenithIsland.primary : ZenithIsland.secondary)
            .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: chosen)
            .accessibilityHidden(true)
    }
}

/// Out of sight the pill is blurred, a little small and tucked up toward
/// the island; Reduce Motion leaves only the fade.
private struct ZenithIslandDockEntrance: ViewModifier {
    let shown: Bool
    let still: Bool
    var tab = false

    func body(content: Content) -> some View {
        let away = !shown && !still
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: away ? (tab ? 4 : 6) : 0)
            .scaleEffect(away ? (tab ? 0.8 : 0.88) : 1, anchor: .top)
            .offset(y: away && !tab ? -8 : 0)
    }
}

/// Presses settle fast to 94%; release springs back (Style Kit).
private struct ZenithIslandDockButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? ZenithMotion.pressedScale : 1)
            .animation(reduceMotion ? nil : configuration.isPressed ? ZenithMotion.press : ZenithMotion.spring(),
                       value: configuration.isPressed)
    }
}

/// The Home tab's secondary click offers Customize Home.
private struct ZenithDockHomeMenu: ViewModifier {
    let home: Bool
    let service: NotchService

    func body(content: Content) -> some View {
        if home {
            content.contextMenu { ZenithHomeMenuItem(service: service) }
        } else {
            content
        }
    }
}
