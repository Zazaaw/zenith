// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the Mouse & Trackpad page's preview card. The page holds a
// dozen features; the picker groups them into scrolling, the pointer and the
// buttons, and the feature the sidebar or a search opened picks the picture.
// Each picture loops what the feature does, with this Mac's own choices (the
// modifier keys, lines per notch, the debounce window) and sample content.

/// The picker's groups, in page order.
enum ZenithMousePreviewGroup: Int, CaseIterable {
    case scroll, pointer, buttons

    var features: [AppFeature] {
        switch self {
        case .scroll: return [.scrollInverter, .scrollHorizontal, .scrollZoom, .smoothScroll, .linearScroll, .scrollSpeed]
        case .pointer: return [.focusFollowsMouse, .mouseAcceleration]
        case .buttons: return [.mouseNavigation, .mouseButtonShortcuts, .mouseClickDebounce, .middleClick]
        }
    }

    func title(_ text: ZenithPreviewsInputStrings) -> String {
        switch self {
        case .scroll: return text.scroll
        case .pointer: return text.pointer
        case .buttons: return text.buttons
        }
    }

    static func of(_ feature: AppFeature) -> ZenithMousePreviewGroup? {
        allCases.first { $0.features.contains(feature) }
    }
}

struct ZenithMousePreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.scrollHorizontalModifier) private var horizontalModifier = ScrollHorizontalModifier.shift
    @AppStorage(DefaultsKey.pinchZoomModifier) private var zoomModifier = ScrollZoomModifier.control.rawValue
    @AppStorage(DefaultsKey.scrollSpeedModifier) private var speedModifier = ScrollHorizontalModifier.option
    @AppStorage(DefaultsKey.scrollSpeedMultiplier) private var speedMultiplier = ScrollWheelSupport.defaultSpeedMultiplier
    @AppStorage(DefaultsKey.linearScrollLines) private var linesPerNotch = ScrollWheelSupport.defaultLinesPerNotch
    @AppStorage(DefaultsKey.mouseClickDebounceWindowMs) private var debounceWindow = Defaults.defaultMouseClickDebounceWindowMs
    /// The group picked in the card; nil follows the routed feature.
    @State private var picked: AppFeature?

    private var text: ZenithPreviewsInputStrings { .shared }

    private var groups: [ZenithMousePreviewGroup] {
        ZenithMousePreviewGroup.allCases.filter { !$0.features.filter(\.isAvailable).isEmpty }
    }

    /// The feature the sidebar or a search opened on this page.
    private var routed: AppFeature? {
        guard router.page == .mouse else { return nil }
        if let feature = router.sidebarFeature, ZenithMousePreviewGroup.of(feature) != nil { return feature }
        guard let anchor = router.destination.sectionAnchor else { return nil }
        return ZenithMousePreviewGroup.allCases.flatMap(\.features).first {
            $0.isAvailable && $0.settingsDestination.sectionAnchor == anchor
        }
    }

    private var feature: AppFeature {
        picked ?? routed ?? groups.first?.features.first(where: \.isAvailable) ?? .scrollInverter
    }

    var body: some View {
        let groups = self.groups
        let feature = self.feature
        ZenithSettingsPreviewCard(id: "mouse", caption: caption(feature),
                                  states: groups.map { $0.title(text) },
                                  selection: Binding(get: {
                                      groups.firstIndex { $0 == ZenithMousePreviewGroup.of(feature) } ?? 0
                                  }, set: { index in
                                      guard groups.indices.contains(index) else { return }
                                      picked = groups[index].features.first(where: \.isAvailable)
                                  }),
                                  highlight: feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language))) {
            ZPIStage(period: period(feature), still: still(feature)) { phase in
                picture(feature, phase: phase)
            }
            .id(feature)
        }
        .onChange(of: router.requestID) { _, _ in picked = nil }
    }

    private func open(_ feature: AppFeature) {
        picked = nil
        router.request(feature.settingsDestination, sidebarFeature: feature)
    }

    private func period(_ feature: AppFeature) -> TimeInterval {
        switch feature {
        case .smoothScroll, .mouseAcceleration, .focusFollowsMouse: return 4
        case .scrollSpeed: return 4.5
        default: return 3.2
        }
    }

    /// The moment the picture stands on with Reduce Motion on.
    private func still(_ feature: AppFeature) -> Double {
        switch feature {
        case .smoothScroll, .focusFollowsMouse, .mouseAcceleration, .middleClick: return 0.6
        case .scrollSpeed: return 0.75
        case .mouseNavigation: return 0.45
        case .mouseButtonShortcuts: return 0.55
        case .mouseClickDebounce: return 0.7
        default: return 0.5
        }
    }

    private func caption(_ feature: AppFeature) -> String {
        switch feature {
        case .scrollHorizontal: return text.sidewaysCaption
        case .scrollZoom: return text.zoomCaption
        case .smoothScroll: return text.smoothCaption
        case .linearScroll: return text.linearCaption
        case .scrollSpeed: return text.speedCaption
        case .focusFollowsMouse: return text.focusCaption
        case .mouseAcceleration: return text.accelerationCaption
        case .mouseNavigation: return text.navigationCaption
        case .mouseButtonShortcuts: return text.buttonShortcutsCaption
        case .mouseClickDebounce: return text.debounceCaption
        case .middleClick: return text.middleClickCaption
        default: return text.invertCaption
        }
    }

    // MARK: Pictures

    @ViewBuilder
    private func picture(_ feature: AppFeature, phase: Double) -> some View {
        switch feature {
        case .scrollHorizontal: sideways(phase)
        case .scrollZoom: zoom(phase)
        case .smoothScroll: smooth(phase)
        case .linearScroll: linear(phase)
        case .scrollSpeed: speed(phase)
        case .focusFollowsMouse: focus(phase)
        case .mouseAcceleration: acceleration(phase)
        case .mouseNavigation: navigation(phase)
        case .mouseButtonShortcuts: buttonShortcut(phase)
        case .mouseClickDebounce: debounce(phase)
        case .middleClick: middleClick(phase)
        default: invert(phase)
        }
    }

    /// The mouse on the left, outlined, opening `feature`'s settings.
    private func mouse(_ feature: AppFeature, wheel: Double = 0, wheelLit: Bool = false, leftLit: Bool = false,
                       sideLit: Bool = false) -> some View {
        ZPIMouse(wheel: wheel, wheelLit: wheelLit, leftLit: leftLit, sideLit: sideLit)
            .zenithPreviewPart(cornerRadius: 36, highlighted: true) { open(feature) }
    }

    private func keyLabel(_ modifier: ScrollHorizontalModifier) -> String {
        switch modifier {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        case .command: return "⌘"
        }
    }

    private func arrow(_ x: CGFloat, _ y: CGFloat = 96) -> some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.tertiary)
            .position(x: x, y: y)
    }

    private func invert(_ phase: Double) -> some View {
        let roll = ZPI.ease(phase, 0.12, 0.72)
        return ZStack {
            mouse(.scrollInverter, wheel: roll * 4, wheelLit: roll > 0 && roll < 1)
                .position(x: 130, y: 88)
            Image(systemName: "arrow.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .opacity(roll > 0 && roll < 1 ? 1 : 0.3)
                .position(x: 130, y: 104)
            ZPILabel(text.wheelDown).position(x: 130, y: 168)
            arrow(220)
            ZPIWindow(width: 170, height: 130) {
                ZPIPageLines(offset: CGSize(width: 0, height: roll * 52), marked: 3)
            }
            .position(x: 320, y: 88)
            ZPILabel(text.pageMovesDown).position(x: 320, y: 168)
        }
    }

    private func sideways(_ phase: Double) -> some View {
        let held = ZPI.pulse(phase, 0.1, 0.85)
        let roll = ZPI.ease(phase, 0.2, 0.75)
        return ZStack {
            ZPIKey(label: keyLabel(horizontalModifier), lit: held > 0.5, depth: held, width: 40, height: 34)
                .zenithPreviewPart(cornerRadius: 8, highlighted: true) { open(.scrollHorizontal) }
                .position(x: 62, y: 88)
            Text("+").font(.system(size: 16, weight: .medium)).foregroundStyle(.tertiary).position(x: 100, y: 88)
            ZPIMouse(wheel: roll * 4, wheelLit: roll > 0 && roll < 1)
                .position(x: 148, y: 88)
            arrow(222)
            ZPIWindow(width: 170, height: 130) {
                timeline(offset: roll * 90)
            }
            .position(x: 320, y: 88)
            ZPILabel(text.pageMovesSideways).position(x: 320, y: 168)
        }
    }

    /// Blocks on a horizontal track, for a page that scrolls sideways.
    private func timeline(offset: Double) -> some View {
        GeometryReader { _ in
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<8, id: \.self) { index in
                    let width = CGFloat([44, 30, 52, 36][(index + row) % 4])
                    let x = (CGFloat(index) * 58 + CGFloat(row) * 17 - CGFloat(offset))
                        .truncatingRemainder(dividingBy: 464)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == 2 && row == 1 ? Color.accentColor.opacity(0.7) : ZPI.line)
                        .frame(width: width, height: 16)
                        .position(x: (x < -60 ? x + 464 : x) + width / 2, y: 22 + CGFloat(row) * 30)
                }
            }
        }
    }

    private func zoom(_ phase: Double) -> some View {
        let modifier = ScrollZoomModifier(storageValue: zoomModifier).modifier ?? .control
        let held = ZPI.pulse(phase, 0.1, 0.9)
        let zoom = ZPI.ease(phase, 0.2, 0.5) - ZPI.ease(phase, 0.62, 0.88)
        return ZStack {
            ZPIKey(label: keyLabel(modifier), lit: held > 0.5, depth: held, width: 40, height: 34)
                .zenithPreviewPart(cornerRadius: 8, highlighted: true) { open(.scrollZoom) }
                .position(x: 62, y: 88)
            Text("+").font(.system(size: 16, weight: .medium)).foregroundStyle(.tertiary).position(x: 100, y: 88)
            ZPIMouse(wheel: (ZPI.span(phase, 0.2, 0.5) - ZPI.span(phase, 0.62, 0.88)) * 3,
                     wheelLit: zoom > 0.02 && zoom < 0.98)
                .position(x: 148, y: 88)
            arrow(222)
            ZPIWindow(width: 170, height: 130) {
                ZStack {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.accentColor.opacity(0.75))
                        .scaleEffect(1 + 0.8 * zoom)
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .position(x: 320, y: 88)
            ZPILabel(text.pageZooms).position(x: 320, y: 168)
        }
    }

    private func smooth(_ phase: Double) -> some View {
        let progress = ZPI.span(phase, 0.08, 0.8)
        return ZStack {
            mouse(.smoothScroll, wheel: progress * 4, wheelLit: progress > 0 && progress < 1)
                .position(x: 82, y: 88)
            ZPILabel(text.wheelDown).position(x: 82, y: 168)
            arrow(160)
            graph(title: text.notchByNotch, lit: false, progress: progress, stepped: true)
                .position(x: 300, y: 54)
            graph(title: text.smooth, lit: true, progress: progress, stepped: false)
                .position(x: 300, y: 134)
        }
    }

    /// Page position over time: four notches, jumping or gliding.
    private func graph(title: String, lit: Bool, progress: Double, stepped: Bool) -> some View {
        let path = Path { path in
            let width = 150.0, height = 40.0
            path.move(to: CGPoint(x: 0, y: height))
            for step in 0..<4 {
                let x0 = Double(step) * width / 4, x1 = x0 + width / 4
                let y0 = height - Double(step) * height / 4, y1 = y0 - height / 4
                if stepped {
                    path.addLine(to: CGPoint(x: x0, y: y1))
                    path.addLine(to: CGPoint(x: x1, y: y1))
                } else {
                    path.addCurve(to: CGPoint(x: x1, y: y1), control1: CGPoint(x: x0 + 14, y: y0 - 2),
                                  control2: CGPoint(x: x0 + 18, y: y1))
                }
            }
        }
        return VStack(alignment: .leading, spacing: 5) {
            ZPILabel(title, lit: lit)
            ZStack(alignment: .topLeading) {
                path.stroke(ZPI.line, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                path.trim(from: 0, to: progress)
                    .stroke(lit ? Color.accentColor : Color.primary.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 150, height: 40)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ZPI.surface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(lit ? Color.accentColor.opacity(0.4) : ZPI.line))
    }

    private func linear(_ phase: Double) -> some View {
        let lines = max(1, linesPerNotch)
        // Three notches, each moving the page exactly `lines` lines.
        let notches = (0..<3).map { ZPI.ease(phase, 0.15 + Double($0) * 0.22, 0.25 + Double($0) * 0.22) }
        let moved = notches.reduce(0, +)
        let ticking = notches.contains { $0 > 0 && $0 < 1 }
        return ZStack {
            mouse(.linearScroll, wheel: moved, wheelLit: ticking)
                .position(x: 112, y: 82)
            ZPIChip(text: "\(lines) \(text.linesPerNotch)", symbol: "text.line.first.and.arrowtriangle.forward")
                .position(x: 112, y: 160)
            arrow(212)
            ZPIWindow(width: 170, height: 140) {
                ZPIPageLines(offset: CGSize(width: 0, height: moved * Double(lines) * 13), spacing: 13, marked: 0)
            }
            .position(x: 316, y: 92)
        }
    }

    private func speed(_ phase: Double) -> some View {
        let held = ZPI.pulse(phase, 0.5, 0.95)
        // Slow while the key is up, `speedMultiplier` times as fast while held.
        let slow = ZPI.span(phase, 0.05, 0.45) * 40
        let fast = ZPI.span(phase, 0.55, 0.95) * 40 * Double(max(1, speedMultiplier))
        return ZStack {
            ZPIKey(label: keyLabel(speedModifier), lit: held > 0.5, depth: held, width: 40, height: 34)
                .zenithPreviewPart(cornerRadius: 8, highlighted: true) { open(.scrollSpeed) }
                .position(x: 62, y: 88)
            Text("+").font(.system(size: 16, weight: .medium)).foregroundStyle(.tertiary).position(x: 100, y: 88)
            ZPIMouse(wheel: phase * 8, wheelLit: true)
                .position(x: 148, y: 88)
            ZPIChip(text: held > 0.5 ? "×\(speedMultiplier)" : "×1", lit: held > 0.5)
                .position(x: 148, y: 166)
            arrow(222)
            ZPIWindow(width: 170, height: 130) {
                ZPIPageLines(offset: CGSize(width: 0, height: slow + fast), marked: 5)
            }
            .position(x: 320, y: 88)
            ZPILabel(text.faster, lit: held > 0.5).position(x: 320, y: 168)
        }
    }

    private func focus(_ phase: Double) -> some View {
        let travel = ZPI.ease(phase, 0.2, 0.45) - ZPI.ease(phase, 0.7, 0.92)
        let rightActive = travel > 0.6
        let caret = Int(phase * 12) % 2 == 0
        return ZStack {
            ZPIWindow(width: 170, height: 124, active: !rightActive) {
                editor(active: !rightActive, caret: caret)
            }
            .position(x: 122, y: 88)
            ZPIWindow(width: 170, height: 124, active: rightActive) {
                editor(active: rightActive, caret: caret)
            }
            .zenithPreviewPart(cornerRadius: 12, highlighted: true) { open(.focusFollowsMouse) }
            .position(x: 318, y: 96)
            ZPIPointer()
                .position(x: 150 + travel * 190, y: 100 - travel * 4)
            ZPILabel(text.focusFollows).position(x: 220, y: 178)
        }
    }

    private func editor(active: Bool, caret: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule().fill(ZPI.line).frame(width: [110, 80, 96][index], height: 5)
            }
            HStack(spacing: 2) {
                Capsule().fill(ZPI.line).frame(width: 50, height: 5)
                Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 11)
                    .opacity(active && caret ? 1 : 0)
            }
        }
        .padding(12)
    }

    private func acceleration(_ phase: Double) -> some View {
        let progress = ZPI.span(phase, 0.1, 0.85)
        let width = 200.0, height = 110.0
        let curve = Path { path in
            path.move(to: CGPoint(x: 0, y: height))
            path.addCurve(to: CGPoint(x: width, y: 0), control1: CGPoint(x: width * 0.6, y: height),
                          control2: CGPoint(x: width * 0.85, y: height * 0.4))
        }
        let line = Path { path in
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: width, y: height * 0.15))
        }
        return ZStack {
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: width, y: height))
                }
                .stroke(ZPI.stroke, lineWidth: 1.5)
                curve.stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                line.trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                    .position(x: width * progress, y: height - (height * 0.85) * progress)
            }
            .frame(width: width, height: height)
            .zenithPreviewPart(cornerRadius: 10, highlighted: true) { open(.mouseAcceleration) }
            .position(x: 190, y: 82)
            ZPILabel(text.handSpeed).position(x: 190, y: 156)
            ZPILabel(text.pointerTravel).rotationEffect(.degrees(-90)).position(x: 72, y: 82)
            VStack(alignment: .leading, spacing: 8) {
                legend(text.linear, lit: true)
                legend(text.accelerated, lit: false)
            }
            .position(x: 364, y: 82)
        }
    }

    private func legend(_ title: String, lit: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(lit ? Color.accentColor : Color.primary.opacity(0.35)).frame(width: 16, height: 3)
            ZPILabel(title, lit: lit)
        }
    }

    private func navigation(_ phase: Double) -> some View {
        let press = ZPI.pulse(phase, 0.25, 0.4)
        let slide = ZPI.ease(phase, 0.3, 0.55) - ZPI.ease(phase, 0.85, 1)
        return ZStack {
            mouse(.mouseNavigation, sideLit: press > 0.5)
                .position(x: 120, y: 84)
            ZPILabel(text.sideButton, lit: press > 0.5).position(x: 120, y: 160)
            arrow(212)
            ZPIWindow(width: 180, height: 130) {
                GeometryReader { geo in
                    ZStack {
                        webPage(seed: 0).offset(x: -geo.size.width * (1 - slide))
                        webPage(seed: 1).offset(x: geo.size.width * slide)
                    }
                }
            }
            .position(x: 320, y: 88)
            ZPIChip(text: text.back, symbol: "chevron.backward", lit: slide > 0.1)
                .position(x: 320, y: 172)
        }
    }

    private func webPage(seed: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 5)
                .fill(seed == 0 ? Color.accentColor.opacity(0.35) : ZPI.line)
                .frame(height: 34)
            ForEach(0..<3, id: \.self) { index in
                Capsule().fill(ZPI.line).frame(width: [130, 96, 116][(index + seed) % 3], height: 5)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ZPI.surface)
    }

    private func buttonShortcut(_ phase: Double) -> some View {
        let press = ZPI.pulse(phase, 0.2, 0.38)
        let shown = ZPI.ease(phase, 0.3, 0.45) - ZPI.ease(phase, 0.85, 0.98)
        return ZStack {
            mouse(.mouseButtonShortcuts, sideLit: press > 0.5)
                .position(x: 96, y: 84)
            ZPILabel(text.sideButton, lit: press > 0.5).position(x: 96, y: 160)
            arrow(166)
            ZPIChord(caps: ["⌃", "↑"], lit: shown > 0.5, depth: press)
                .position(x: 226, y: 88)
            arrow(276)
            VStack(spacing: 6) {
                // A plain Grid: lazy grids crash inside Settings' Forms.
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(0..<2, id: \.self) { row in
                        GridRow {
                            ForEach(0..<2, id: \.self) { column in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(row * 2 + column == 1 ? Color.accentColor.opacity(0.45) : ZPI.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(ZPI.stroke))
                                    .frame(width: 44, height: 30)
                            }
                        }
                    }
                }
                ZPILabel(text.missionControl, lit: shown > 0.5)
            }
            .scaleEffect(0.85 + 0.15 * shown)
            .opacity(0.35 + 0.65 * shown)
            .position(x: 352, y: 96)
        }
    }

    private func debounce(_ phase: Double) -> some View {
        let window = max(1, debounceWindow)
        let sweep = ZPI.span(phase, 0.1, 0.85)
        let first = 0.3, second = 0.42
        return ZStack {
            mouse(.mouseClickDebounce, leftLit: abs(sweep - first) < 0.05 || abs(sweep - second) < 0.04)
                .position(x: 84, y: 84)
            ZStack(alignment: .topLeading) {
                // The window after a click in which another is a bounce.
                Rectangle().fill(Color.accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)
                    .offset(x: 230 * first, y: 10)
                Text("\(window) ms").font(ZenithType.mono(10, weight: .medium)).foregroundStyle(Color.accentColor)
                    .offset(x: 230 * first + 6, y: 0)
                Rectangle().fill(ZPI.stroke).frame(width: 230, height: 1.5).offset(y: 80)
                tick(at: first, lit: sweep >= first, crossed: false)
                tick(at: second, lit: sweep >= second, crossed: true)
                Rectangle().fill(Color.primary.opacity(0.35)).frame(width: 1, height: 90).offset(x: 230 * sweep)
            }
            .frame(width: 230, height: 90, alignment: .topLeading)
            .position(x: 300, y: 70)
            ZPILabel(text.oneClick, lit: sweep >= first).position(x: 268, y: 140)
            ZPILabel(text.bounce).opacity(sweep >= second ? 1 : 0.4).position(x: 268, y: 160)
        }
    }

    private func tick(at x: Double, lit: Bool, crossed: Bool) -> some View {
        ZStack {
            Capsule().fill(crossed ? Color.primary.opacity(0.35) : Color.accentColor).frame(width: 4, height: 34)
            if crossed {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                    .offset(y: -28)
            }
        }
        .opacity(lit ? 1 : 0.2)
        .offset(x: 230 * x - 2, y: 46)
    }

    private func middleClick(_ phase: Double) -> some View {
        let tap = ZPI.pulse(phase, 0.25, 0.4, fade: 0.05)
        let opened = ZPI.ease(phase, 0.38, 0.55) - ZPI.ease(phase, 0.88, 1)
        return ZStack {
            ZPITrackpad(fingers: 3, tap: tap, lit: true)
                .zenithPreviewPart(cornerRadius: 14, highlighted: true) { open(.middleClick) }
                .position(x: 104, y: 84)
            ZPILabel(text.threeFingerTap, lit: tap > 0.5).position(x: 104, y: 150)
            arrow(204)
            ZPIWindow(width: 180, height: 130) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        tab(lit: false)
                        tab(lit: true).scaleEffect(x: opened, anchor: .leading).opacity(opened)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    webPage(seed: 1).frame(height: 90)
                }
            }
            .position(x: 316, y: 84)
            ZPIPointer(pressed: tap > 0.5).position(x: 300, y: 118)
            ZPIChip(text: text.opensInNewTab, symbol: "plus.square.on.square", lit: opened > 0.5)
                .position(x: 316, y: 172)
        }
    }

    private func tab(lit: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(lit ? Color.accentColor.opacity(0.3) : ZPI.raised)
            .frame(width: 52, height: 14)
    }
}
