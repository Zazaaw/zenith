// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the home page's widget row and its edit mode.
//
// "Customize Home" in the island's menu (or on the Home tab of the pill)
// opens the edit mode on the home page: the widgets wiggle very slightly,
// each with a remove badge, and a strip of the widgets that can be added
// rises in at the bottom with Cancel and Done. Adding one flies its icon
// from the strip into its place (`matchedGeometryEffect`) while the island
// springs wider; removing one shrinks, fades and blurs it out while the
// island narrows. Cancel puts the layout back; Done saves it.
//
// The island's size follows the layout through its own geometry
// (`ZenithHomeIsland.geometry`, read by `NotchService.expandedGeometry`):
// every change here updates that state and asks the island to present
// again, so the silhouette springs to the new size as a page change does,
// rather than the page relaying itself out under a fixed island.

@MainActor
final class ZenithHomeEditor: ObservableObject {
    static let shared = ZenithHomeEditor()

    @Published private(set) var editing = false
    @Published private(set) var draft = ZenithHomeLayout()
    /// Widgets whose icons are flying into their place.
    @Published private(set) var landing: Set<ZenithHomeWidget> = []
    /// Bumps when a saved layout changes, so the row redraws.
    @Published private(set) var revision = 0

    private var landingWork: [ZenithHomeWidget: DispatchWorkItem] = [:]

    private init() {}

    /// The layout on screen.
    var layout: ZenithHomeLayout { editing ? draft : ZenithHomeIsland.stored() }

    /// The widgets that show, for the island's modules.
    func shown(modules: [NotchModule]) -> [ZenithHomeWidget] { layout.shown(modules: modules) }

    /// Widgets the strip offers: those whose pages are on.
    func candidates(modules: [NotchModule]) -> [ZenithHomeWidget] {
        ZenithHomeWidget.allCases.filter { $0.isAvailable(modules: modules) }
    }

    func canAdd(_ widget: ZenithHomeWidget, service: NotchService) -> Bool {
        draft.canAdd(widget, maximumWidth: service.geometry.zenithHomeMaximumContentWidth)
    }

    // MARK: Edit mode

    /// Opens the edit mode on the home page, bringing the home page first.
    func begin(on service: NotchService) {
        guard service.modules.contains(.controls) else { return }
        if service.selected != .controls || service.showingSections || service.showingAppPanel
            || service.selectedMetric != nil {
            service.select(.controls)
        }
        draft = ZenithHomeIsland.stored()
        ZenithHomeIsland.draft = draft
        ZenithHomeIsland.editing = true
        withAnimation(ZenithMorph.animation(reduceMotion: reduceMotion)) { editing = true }
        service.refreshPresentation()
    }

    func toggle(_ widget: ZenithHomeWidget, service: NotchService) {
        draft.contains(widget) ? remove(widget, service: service) : add(widget, service: service)
    }

    func add(_ widget: ZenithHomeWidget, service: NotchService) {
        guard editing, canAdd(widget, service: service) else { return }
        withAnimation(ZenithMorph.animation(reduceMotion: reduceMotion)) {
            draft = draft.adding(widget, maximumWidth: service.geometry.zenithHomeMaximumContentWidth)
            if !reduceMotion { landing.insert(widget) }
        }
        ZenithHomeIsland.draft = draft
        service.refreshPresentation()
        guard !reduceMotion else { return }
        // Once the icon has landed, the widget takes its place.
        landingWork[widget]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.22)) { _ = self.landing.remove(widget) }
            self.landingWork[widget] = nil
        }
        landingWork[widget] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + ZenithMorph.response + 0.06, execute: work)
    }

    func remove(_ widget: ZenithHomeWidget, service: NotchService) {
        guard editing, draft.contains(widget) else { return }
        landingWork[widget]?.cancel()
        landingWork[widget] = nil
        withAnimation(ZenithMorph.animation(reduceMotion: reduceMotion)) {
            draft = draft.removing(widget)
            landing.remove(widget)
        }
        ZenithHomeIsland.draft = draft
        service.refreshPresentation()
    }

    /// Done: keeps the layout.
    func done(service: NotchService) { end(saving: true, service: service) }

    /// Cancel: puts the layout back as it was.
    func cancel(service: NotchService) { end(saving: false, service: service) }

    /// Leaves the edit mode without saving when the home page goes away.
    func abandon() {
        guard editing else { return }
        end(saving: false, service: .shared)
    }

    private func end(saving: Bool, service: NotchService) {
        guard editing else { return }
        landingWork.values.forEach { $0.cancel() }
        landingWork = [:]
        if saving, draft != ZenithHomeIsland.stored() {
            ZenithHomeIsland.save(draft)
            revision += 1
        }
        ZenithHomeIsland.editing = false
        ZenithHomeIsland.draft = nil
        withAnimation(ZenithMorph.animation(reduceMotion: reduceMotion)) {
            editing = false
            landing = []
        }
        service.refreshPresentation()
    }

    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

// MARK: - The row

/// The home page's card row: the widgets side by side, each as wide as its
/// share of the row, in edit mode with a dashed outline, a remove badge and
/// a very slight wiggle.
struct ZenithHomeCardRow: View {
    @ObservedObject var service: NotchService
    let width: CGFloat
    let height: CGFloat
    let namespace: Namespace.ID
    @ObservedObject private var editor = ZenithHomeEditor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    /// Edit mode shows on the island, never in the Settings preview of it.
    private var editing: Bool { editor.editing && !preview }

    var body: some View {
        let widgets = editor.shown(modules: service.modules)
        let widths = Self.widths(widgets, in: width)
        HStack(spacing: ZenithHomeLayout.spacing) {
            ForEach(Array(widgets.enumerated()), id: \.element) { index, widget in
                slot(widget, index: index, alone: widgets.count == 1)
                    .frame(width: widths[index], height: height)
                    .transition(.asymmetric(insertion: .zenithMorph(reduceMotion: reduceMotion),
                                            removal: .zenithHomeDeparture(reduceMotion: reduceMotion)))
            }
            if widgets.isEmpty, editing {
                Text(ZenithStrings.home(l10n.language).emptyHint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZenithIsland.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zenithDropZone(cornerRadius: ZenithIsland.cardRadius)
                    .transition(.zenithMorph(reduceMotion: reduceMotion))
            }
        }
        .frame(width: width, height: height, alignment: .leading)
    }

    /// Each widget's share of `width`: its own width, scaled so the row fills it.
    static func widths(_ widgets: [ZenithHomeWidget], in width: CGFloat) -> [CGFloat] {
        guard !widgets.isEmpty else { return [] }
        if widgets.count == 1 { return [max(0, width)] }
        let room = max(0, width - ZenithHomeLayout.spacing * CGFloat(widgets.count - 1))
        let natural = widgets.reduce(0) { $0 + $1.width }
        return widgets.map { (room * $0.width / max(1, natural)).rounded(.down) }
    }

    private func slot(_ widget: ZenithHomeWidget, index: Int, alone: Bool) -> some View {
        let landing = editor.landing.contains(widget)
        let name = widget.title(l10n.language)
        return ZenithHomeWidgetView(widget: widget, service: service, height: height, framed: !alone || editing)
            .opacity(landing ? 0 : 1)
            .blur(radius: landing ? 6 : 0)
            .allowsHitTesting(!editing)
            .overlay {
                if landing {
                    ZenithIslandIcon(symbol: widget.symbol, hex: widget.hex, size: 40)
                        .matchedGeometryEffect(id: widget, in: namespace)
                        .transition(.asymmetric(insertion: .identity,
                                                removal: .opacity.combined(with: .scale(scale: 1.15))))
                }
            }
            .overlay {
                if editing {
                    RoundedRectangle(cornerRadius: ZenithIsland.cardRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if editing {
                    Button { editor.remove(widget, service: service) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(ZenithStatus.error, in: Circle())
                            .overlay { Circle().strokeBorder(Color.black, lineWidth: 1.5) }
                            .frame(width: 26, height: 26)
                            .contentShape(Circle())
                    }
                    .buttonStyle(ZenithAppIconButtonStyle())
                    .offset(x: 7, y: -7)
                    .help(ZenithStrings.home(l10n.language).remove(name))
                    .accessibilityLabel(ZenithStrings.home(l10n.language).remove(name))
                    // The badges follow the outline in, 40 ms later.
                    .transition(.scale(scale: 0.4).combined(with: .opacity)
                        .animation(ZenithMorph.animation(reduceMotion: reduceMotion).delay(ZenithMotion.layerStagger)))
                }
            }
            .modifier(ZenithHomeWiggle(active: editing && !reduceMotion, index: index))
    }
}

/// A widget leaving: it shrinks, fades and blurs out.
private struct ZenithHomeDepartureEffect: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: 10 * amount)
            .opacity(Double(1 - amount))
            .scaleEffect(1 - 0.18 * amount)
    }
}

extension AnyTransition {
    static func zenithHomeDeparture(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity
            : .modifier(active: ZenithHomeDepartureEffect(amount: 1), identity: ZenithHomeDepartureEffect(amount: 0))
    }
}

/// In edit mode a widget rocks a degree either way, each a little out of
/// step with its neighbour; outside it, it settles back.
private struct ZenithHomeWiggle: ViewModifier {
    let active: Bool
    let index: Int
    @State private var tilted = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (tilted ? 1 : -1) * (index.isMultiple(of: 2) ? 1 : -1) : 0))
            .onAppear { if active { start() } }
            .onChange(of: active) { _, now in
                if now { start() } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { tilted = false }
                }
            }
    }

    private func start() {
        tilted = false
        withAnimation(.easeInOut(duration: 0.14).repeatForever(autoreverses: true)
                        .delay(ZenithMotion.layerDelay(index))) {
            tilted = true
        }
    }
}

// MARK: - The edit strip

/// The bottom of the home page in edit mode: the widgets that can be added,
/// as tinted icons over their names (a check on those already in the
/// row), scrolling sideways, then Cancel and Done.
struct ZenithHomeEditStrip: View {
    @ObservedObject var service: NotchService
    let namespace: Namespace.ID
    @ObservedObject private var editor = ZenithHomeEditor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let text = ZenithStrings.home(l10n.language)
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(editor.candidates(modules: service.modules).enumerated()), id: \.element) { index, widget in
                        candidate(widget, text: text)
                            .modifier(ZenithStripEntrance(shown: shown))
                            .animation(ZenithMorph.animation(reduceMotion: reduceMotion)
                                        .delay(ZenithMotion.layerDelay(index + 1)), value: shown)
                    }
                }
                .padding(.horizontal, 4)
            }
            .notchScrollEdgeFade(.horizontal)
            HStack(spacing: 8) {
                roundButton(symbol: "xmark", title: text.cancel, fill: Color.white.opacity(0.14)) {
                    editor.cancel(service: service)
                }
                roundButton(symbol: "checkmark", title: text.done, fill: ZenithIsland.accent) {
                    editor.done(service: service)
                }
                .keyboardShortcut(.defaultAction)
            }
            .modifier(ZenithStripEntrance(shown: shown))
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion).delay(ZenithMotion.layerDelay(2)), value: shown)
        }
        .frame(height: ZenithHomeIsland.stripHeight)
        .onAppear { shown = true }
    }

    private func candidate(_ widget: ZenithHomeWidget, text: ZenithHomeStrings) -> some View {
        let added = editor.draft.contains(widget)
        let addable = added || editor.canAdd(widget, service: service)
        let name = widget.title(l10n.language)
        return Button { editor.toggle(widget, service: service) } label: {
            VStack(spacing: 4) {
                ZStack {
                    if added {
                        ZenithIslandIcon(symbol: widget.symbol, hex: widget.hex, size: 34, lifted: false)
                    } else {
                        // The icon that flies into the row when the widget joins it.
                        ZenithIslandIcon(symbol: widget.symbol, hex: widget.hex, size: 34, lifted: false)
                            .matchedGeometryEffect(id: widget, in: namespace)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if added {
                        ZenithAppIconCheck(size: 14).offset(x: 4, y: 4)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                Text(name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(added ? ZenithIsland.primary : ZenithIsland.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 50)
            }
            .opacity(addable ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(ZenithAppIconButtonStyle())
        .disabled(!addable)
        .help(addable ? (added ? text.remove(name) : text.add(name)) : text.noRoom)
        .accessibilityLabel(added ? text.remove(name) : text.add(name))
        .accessibilityAddTraits(added ? .isSelected : [])
    }

    private func roundButton(symbol: String, title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(fill, in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75) }
                .contentShape(Circle())
        }
        .buttonStyle(ZenithAppIconButtonStyle())
        .help(title)
        .accessibilityLabel(title)
    }
}

/// The strip's pieces rising in: up from below out of a blur.
private struct ZenithStripEntrance: ViewModifier {
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 8)
            .offset(y: shown ? 0 : 14)
    }
}

extension ZenithHomeWidget {
    /// The widget's name: its page's, or the lock screen's word for weather.
    func title(_ language: AppLanguage) -> String {
        if self == .weather { return ZenithStrings.lockScreenWidgets(language).weather }
        return (module ?? .controls).title(language)
    }
}

/// "Customize Home" in the island's menu, with a divider after it, while the
/// home page is on and not already being edited.
struct ZenithHomeMenuItem: View {
    let service: NotchService
    @ObservedObject private var editor = ZenithHomeEditor.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if service.modules.contains(.controls), !editor.editing {
            Button { editor.begin(on: service) } label: {
                Label(ZenithStrings.home(l10n.language).customize, systemImage: "square.grid.3x1.below.line.grid.1x2")
            }
            Divider()
        }
    }
}
