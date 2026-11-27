// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the open island's tab pill. A small black capsule floats just
// below the island, apart from it, with the sections pinned in Settings
// (ZenithTabBar: Home and Files, with the Shelf's count, unless chosen
// otherwise), the page on screen when it is none of them (in its own colour)
// and the section gallery, always last. The chosen tab sits in a grey capsule
// that slides between them.
//
// It is drawn in the island's own window, on the floating-controls layer
// that already reaches below the island (`NotchQuickAccessContainer`), so it
// follows the island to its display, hides for Mission Control with it, and a
// click on it is a click on the island, which never closes it. The window
// reserves room for it below the island only while it shows; elsewhere the
// window stays as it was.
//
// The island's top row no longer repeats the gallery's button; the pill, the
// island's menu, Command-K and the module shortcuts all still reach it. With
// the tab bar switched off the pill goes and the row gets its button back.

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
    /// The widest the pill gets: six pins, the open page and the gallery,
    /// two of them with a badge, with room to spare.
    static let maximumWidth: CGFloat = 360
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
            ? (visible ? ZenithMorph.animation(reduceMotion: still).delay(delay) : IslandMotion.easeIn(Self.departure))
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


/// What the pill shows: its tabs, the chosen one, and whether a detail (the
/// app panel, a metric) covers the open page, whose tab then leads back.
struct ZenithIslandDockTabs: Equatable {
    var layout: ZenithTabBarLayout
    var detail: Bool
}

struct ZenithIslandDockView: View {
    @ObservedObject var service: NotchService
    @ObservedObject var motion: ZenithIslandDockMotion
    @ObservedObject private var shelf = ShelfService.shared
    @ObservedObject private var notifications = NotchNotificationService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // What Settings → Dynamic Island → Layout → Tab bar chose, read live.
    @AppStorage(DefaultsKey.zenithTabBarModules) private var pins = ZenithTabBar.defaultEncoded
    @AppStorage(DefaultsKey.zenithTabBarCurrentPage) private var currentPage = true
    @AppStorage(DefaultsKey.zenithTabBarBadges) private var badges = true
    /// What the pill shows, moved on the morph's spring rather than with the
    /// island's page, which changes with animations switched off.
    @State private var shown: ZenithIslandDockTabs?

    private static let space = "zenith.island.dock"

    private var current: ZenithIslandDockTabs {
        let detail = service.showingAppPanel || service.selectedMetric != nil
        let configuration = ZenithTabBarConfiguration(pins: ZenithTabBarPins(encoded: pins), currentPage: currentPage)
        return ZenithIslandDockTabs(layout: ZenithTabBar.layout(configuration, available: service.modules,
                                                                page: service.showingSections ? nil : service.selected,
                                                                detail: detail),
                                    detail: detail)
    }

    private var counts: [NotchModule: Int] {
        badges ? [.files: shelf.items.count, .notifications: notifications.items.count] : [:]
    }

    var body: some View {
        let tabs = shown ?? current
        ZStack(alignment: .topLeading) {
            Color.clear
            ZenithIslandDockPill(tabs: tabs, counts: counts, shown: motion.visible, arrivalDelay: motion.arrivalDelay,
                                 detailTitle: service.detailTitle, appPanel: service.showingAppPanel, service: service,
                                 activate: activate)
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
            // animations disabled, and the pill still slides to it. A change
            // made in Settings moves on the same spring.
            withTransaction(Transaction(animation: motion.visible ? ZenithMorph.animation(reduceMotion: reduceMotion) : nil)) {
                shown = next
            }
        }
    }

    private func activate(_ item: ZenithTabBarItem, detail: Bool) {
        switch item {
        case .gallery: service.toggleSections()
        case .module(let module): service.select(module)
        case .page(let module): if detail { service.goBack() } else { service.select(module) }
        }
    }
}

/// The pill itself: the island hangs it below the open island, and Settings
/// draws the same view as the tab bar's preview.
struct ZenithIslandDockPill: View {
    let tabs: ZenithIslandDockTabs
    /// The counts the badged tabs show; empty with badges off.
    var counts: [NotchModule: Int] = [:]
    var shown = true
    var arrivalDelay: TimeInterval = 0
    /// While a detail covers the page, its tab wears the detail's title.
    var detailTitle = ""
    var appPanel = false
    /// The island's service, for the Home tab's menu; nil in a preview.
    var service: NotchService? = nil
    var activate: ((ZenithTabBarItem, Bool) -> Void)? = nil
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Namespace private var selection

    var body: some View {
        HStack(spacing: ZenithIslandDockLayout.segmentSpacing) {
            ForEach(Array(tabs.layout.items.enumerated()), id: \.element) { index, item in
                tab(item, chosen: tabs.layout.chosen == item, detail: tabs.detail)
                    .modifier(ZenithIslandDockEntrance(shown: shown, still: reduceMotion, tab: true))
                    // Each tab follows the pill in, 40 ms after the one before.
                    .animation(shown
                                   ? ZenithMorph.animation(reduceMotion: reduceMotion)
                                       .delay(arrivalDelay + ZenithMotion.layerDelay(index + 1))
                                   : IslandMotion.easeIn(ZenithIslandDockMotion.departure),
                               value: shown)
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

    private func tab(_ item: ZenithTabBarItem, chosen: Bool, detail: Bool) -> some View {
        let count = ZenithTabBar.badge(item, counts: counts, enabled: true, detail: detail)
        let title = title(item, detail: detail)
        return Button { activate?(item, detail) } label: {
            HStack(spacing: 5) {
                ZenithIslandDockGlyph(symbol: symbol(item, detail: detail),
                                      tint: item.module?.zenithTint ?? ZenithIsland.primary, chosen: chosen)
                if let count {
                    Text(count > 99 ? "99+" : "\(count)")
                        .font(ZenithType.mono(9.5, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 4)
                        .frame(minWidth: ZenithIslandDockLayout.badgeSize, minHeight: ZenithIslandDockLayout.badgeSize)
                        .background(Color.white.opacity(0.14), in: Capsule())
                        .animation(ZenithMotion.respecting(IslandMotion.snappy(0.28)), value: count)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
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
        .accessibilityValue(count.map { "\($0)" } ?? "")
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier("notch.dock.\(identifier(item))")
        .modifier(ZenithDockHomeMenu(home: item == .module(.controls), service: service))
    }

    private func symbol(_ item: ZenithTabBarItem, detail: Bool) -> String {
        switch item {
        case .module(let module): return ZenithTabBar.symbol(module)
        case .page(let module): return detail && appPanel ? "macwindow" : module.symbol
        case .gallery: return "square.grid.2x2.fill"
        }
    }

    private func title(_ item: ZenithTabBarItem, detail: Bool) -> String {
        let language = l10n.language
        switch item {
        case .gallery: return FeatureStrings.notch(language).sectionsTitle
        case .page(let module) where detail: return detailTitle.isEmpty ? module.title(language) : detailTitle
        case .module(let module), .page(let module): return module.title(language)
        }
    }

    private func shortcut(_ item: ZenithTabBarItem) -> String? {
        if item == .gallery { return "⌘K" }
        return item.module.map { "⌥⌘\($0.shortcutKey.uppercased())" }
    }

    private func identifier(_ item: ZenithTabBarItem) -> String {
        switch item {
        case .module(.controls): return "home"
        case .module(.files): return "files"
        case .module(let module): return module.rawValue
        case .page: return "page"
        case .gallery: return "sections"
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
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: chosen)
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
            .animation(reduceMotion ? nil : configuration.isPressed ? IslandMotion.press : IslandMotion.pop(),
                       value: configuration.isPressed)
    }
}

/// The Home tab's secondary click offers Customize Home.
private struct ZenithDockHomeMenu: ViewModifier {
    let home: Bool
    let service: NotchService?

    func body(content: Content) -> some View {
        if home, let service {
            content.contextMenu { ZenithHomeMenuItem(service: service) }
        } else {
            content
        }
    }
}
