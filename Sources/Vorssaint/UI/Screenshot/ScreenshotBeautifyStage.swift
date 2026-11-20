// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: Beautify in the screenshot editor. The stage covers the editor
// while it is on (the editor stays alive underneath, marks and undo intact):
// the framed preview on the left, an inspector of hairline cards on the right,
// and the exports where the editor keeps its own.

/// The editor window's root: the upstream editor, and Beautify over it.
struct ScreenshotBeautifyContainer<Editor: View>: View {
    @ObservedObject var session: ScreenshotBeautifySession
    let editor: Editor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            editor
                .opacity(session.isActive ? 0 : 1)
                .allowsHitTesting(!session.isActive)
                .accessibilityHidden(session.isActive)
            if session.isActive {
                ScreenshotBeautifyStage(session: session)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMotion.reveal(),
                   value: session.isActive)
    }
}

/// Beautify's entry in the editor's action cluster.
struct ScreenshotBeautifyEditorButton: View {
    let action: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.beautify(l10n.language)
        Button(action: action) {
            Image(systemName: "wand.and.stars")
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .screenshotSafeHelp(text.enterHelp)
        .accessibilityLabel(text.title)
    }
}

// MARK: - Stage

struct ScreenshotBeautifyStage: View {
    @ObservedObject var session: ScreenshotBeautifySession
    @ObservedObject private var l10n = L10n.shared
    @State private var savingPreset = false
    @State private var presetName = ""
    @State private var lastFrame = ScreenshotBeautifyStyle.WindowFrame.light

    private typealias Style = ScreenshotBeautifyStyle
    private var text: ZenithBeautifyStrings { ZenithStrings.beautify(l10n.language) }
    private var strings: ScreenshotFeatureStrings { FeatureStrings.screenshot(l10n.language) }

    static let inspectorWidth: CGFloat = 276

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(white: 0.115))
                .overlay {
                    LinearGradient(colors: [Color.white.opacity(0.035), .clear], startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBand
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
                HStack(alignment: .top, spacing: 12) {
                    previewArea
                    inspector
                        .frame(width: Self.inspectorWidth)
                }
                .padding(.top, 8)
                .padding([.horizontal, .bottom], 12)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Top band

    private var topBand: some View {
        ZStack {
            BrandMark(width: 40, tint: Color(white: 0.92))
            HStack(spacing: 8) {
                Button {
                    session.leave()
                } label: {
                    Label(text.backToEdit, systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                }
                .buttonStyle(ZenithPanelOutlineButtonStyle())
                .screenshotSafeHelp(text.backToEdit + "  (⎋)")
                Spacer(minLength: 12)
                actions
            }
            // The window's own buttons sit at the top left.
            .padding(.leading, 70)
        }
        .frame(height: 38)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .opacity(session.exporting ? 1 : 0)
                .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: session.exporting)
            Label(strings.dragOutHandleLabel, systemImage: "arrow.up.doc")
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
                .onDrag { session.dragProvider() }
                .screenshotSafeHelp(strings.dragOutHandleLabel)
                .accessibilityLabel(strings.dragOutHandleLabel)
            Divider().frame(height: 16).padding(.horizontal, 3)
            Button(text.saveBeside) { session.saveBesideOriginal() }
                .fixedSize()
                .screenshotSafeHelp(text.saveBesideHelp + "  (⌘S)")
            Button(strings.copyButton) { session.copy() }
                .buttonStyle(.borderedProminent)
                .screenshotSafeHelp("⏎  ⌘C")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 4)
    }

    // MARK: Preview

    private var previewArea: some View {
        GeometryReader { proxy in
            let margin: CGFloat = 14
            let available = CGSize(width: max(proxy.size.width - margin * 2, 40),
                                   height: max(proxy.size.height - margin * 2, 40))
            Group {
                if let image = session.preview {
                    let fit = Self.fitted(CGSize(width: image.width, height: image.height), in: available)
                    ZStack {
                        if session.style.background == .transparent { ScreenshotBeautifyChecker() }
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                    }
                    .frame(width: fit.width, height: fit.height)
                    .overlay(Rectangle().strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                    .onDrag { session.dragProvider() }
                    .accessibilityElement()
                    .accessibilityLabel(text.title)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    static func fitted(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let factor = min(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
    }

    // MARK: Inspector

    private var inspector: some View {
        ScrollView(.vertical) {
            VStack(spacing: 10) {
                presetsCard
                backgroundCard
                layoutCard
                finishCard
                captionCard
                outputCard
            }
            .padding(.bottom, 4)
        }
        .scrollIndicators(.automatic)
    }

    private func card<Content: View>(_ title: String, value: String? = nil,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZenithPanelSectionLabel(text: title)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zenithPanelCardSurface()
    }

    private func chips<Value: Hashable>(_ options: [(value: Value, title: String)],
                                        selection: Value,
                                        disabled: @escaping (Value) -> Bool = { _ in false },
                                        choose: @escaping (Value) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    choose(option.value)
                } label: {
                    Text(option.title).minimumScaleFactor(0.75)
                }
                .buttonStyle(ZenithPanelChipStyle(isSelected: selected))
                .disabled(disabled(option.value))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: Presets

    private var presetsCard: some View {
        card(text.presets, value: session.matchingPresetName) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(session.presets) { preset in
                        Button(preset.name) { session.apply(preset) }
                    }
                    if !session.presets.isEmpty {
                        Divider()
                        Menu(text.deletePreset) {
                            ForEach(session.presets) { preset in
                                Button(preset.name, role: .destructive) { session.deletePreset(named: preset.name) }
                            }
                        }
                    }
                } label: {
                    Text(session.matchingPresetName ?? text.presets)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(session.presets.isEmpty)
                Spacer(minLength: 6)
                Button {
                    presetName = session.matchingPresetName ?? ""
                    savingPreset = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(ZenithPanelOutlineButtonStyle())
                .screenshotSafeHelp(text.savePreset)
                .accessibilityLabel(text.savePreset)
                .popover(isPresented: $savingPreset, arrowEdge: .bottom) { presetPopover }
            }
        }
    }

    private var presetPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.savePreset).font(ZenithType.emphasis)
            TextField(text.presetName, text: $presetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit(savePreset)
            HStack {
                Spacer()
                Button(strings.cancel) { savingPreset = false }
                Button(strings.saveButton, action: savePreset)
                    .keyboardShortcut(.defaultAction)
                    .disabled(ScreenshotBeautifyPresets.cleanName(presetName).isEmpty)
            }
        }
        .padding(14)
    }

    private func savePreset() {
        guard !ScreenshotBeautifyPresets.cleanName(presetName).isEmpty else { return }
        session.savePreset(named: presetName)
        savingPreset = false
    }

    // MARK: Background

    private func name(_ background: Style.Background) -> String {
        switch background {
        case .gradient: return text.gradient
        case .solid: return text.solid
        case .transparent: return text.transparent
        case .wallpaper: return text.wallpaper
        }
    }

    private func symbol(_ background: Style.Background) -> String {
        switch background {
        case .gradient: return "circle.lefthalf.filled"
        case .solid: return "circle.fill"
        case .transparent: return "checkerboard.rectangle"
        case .wallpaper: return "photo"
        }
    }

    private func name(_ gradient: ScreenshotBeautifyGradient) -> String {
        switch gradient {
        case .ink: return text.ink
        case .paper: return text.paper
        case .mist: return text.mist
        case .peach: return text.peach
        case .sage: return text.sage
        case .sky: return text.sky
        case .sand: return text.sand
        case .dusk: return text.dusk
        }
    }

    private var backgroundCard: some View {
        card(text.background, value: name(session.style.background)) {
            HStack(spacing: 4) {
                ForEach(Style.Background.allCases, id: \.self) { kind in
                    let selected = session.style.background == kind
                    Button {
                        session.style.background = kind
                    } label: {
                        Image(systemName: symbol(kind))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(ZenithPanelChipStyle(isSelected: selected))
                    .screenshotSafeHelp(name(kind))
                    .accessibilityLabel(name(kind))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Group {
                switch session.style.background {
                case .gradient: gradientGrid
                case .solid: solidRow
                case .transparent: note(text.jpegNeedsBackground)
                case .wallpaper:
                    if session.wallpaperMissing { note(text.wallpaperMissing) }
                }
            }
            .transition(.opacity)
        }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: session.style.background)
    }

    private var gradientGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(ScreenshotBeautifyGradient.allCases, id: \.self) { gradient in
                let selected = session.style.gradient == gradient
                Button {
                    session.style.gradient = gradient
                } label: {
                    RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous)
                        .fill(LinearGradient(colors: gradient.stops.map(Self.color), startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(height: 30)
                        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.12),
                                          lineWidth: selected ? 2 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .screenshotSafeHelp(name(gradient))
                .accessibilityLabel(name(gradient))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var solidRow: some View {
        HStack(spacing: 7) {
            ForEach(ScreenshotBeautifySolids.swatches, id: \.self) { hex in
                let selected = session.style.solid.caseInsensitiveCompare(hex) == .orderedSame
                Button {
                    session.style.solid = hex
                } label: {
                    Circle()
                        .fill(ScreenshotBeautifyColor(hex: hex).map(Self.color) ?? .clear)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.16),
                                                       lineWidth: selected ? 2 : 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hex)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Spacer(minLength: 4)
            ColorPicker(text.customColor, selection: solidBinding, supportsOpacity: false)
                .labelsHidden()
                .screenshotSafeHelp(text.customColor)
        }
    }

    private var solidBinding: Binding<Color> {
        Binding(get: {
            ScreenshotBeautifyColor(hex: session.style.solid).map(Self.color) ?? .white
        }, set: { color in
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            session.style.solid = ScreenshotBeautifyColor(red: Double(srgb.redComponent),
                                                          green: Double(srgb.greenComponent),
                                                          blue: Double(srgb.blueComponent)).hex
        })
    }

    private static func color(_ value: ScreenshotBeautifyColor) -> Color {
        Color(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: 1)
    }

    private func note(_ value: String) -> some View {
        Text(value)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Layout

    private var layoutCard: some View {
        card(text.layout) {
            sliderRow(text.padding, value: "\(Int((session.style.padding * 100).rounded()))%",
                      binding: $session.style.padding, range: Style.paddingRange)
            sliderRow(text.corners, value: "\(Int(session.style.cornerRadius.rounded())) pt",
                      binding: $session.style.cornerRadius, range: Style.cornerRange)
            VStack(alignment: .leading, spacing: 6) {
                Text(text.aspect)
                    .font(ZenithType.footnote)
                    .foregroundStyle(.secondary)
                chips(Style.Aspect.allCases.map { ($0, $0 == .auto ? text.auto : $0.label) },
                      selection: session.style.aspect) { session.style.aspect = $0 }
            }
        }
    }

    private func sliderRow(_ title: String, value: String, binding: Binding<Double>,
                           range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(ZenithType.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value)
                    .font(ZenithType.mono(11))
                    .monospacedDigit()
            }
            Slider(value: binding, in: range)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel(title)
                .accessibilityValue(value)
        }
    }

    // MARK: Shadow and frame

    private var frameBinding: Binding<Bool> {
        Binding(get: { session.style.frame != .none }, set: { on in
            if on {
                session.style.frame = lastFrame
            } else {
                if session.style.frame != .none { lastFrame = session.style.frame }
                session.style.frame = .none
            }
        })
    }

    private var finishCard: some View {
        card(text.shadow) {
            chips([(Style.Shadow.none, text.none), (.soft, text.soft), (.strong, text.strong)],
                  selection: session.style.shadow) { session.style.shadow = $0 }
            Rectangle().fill(ZenithSurface.hairline).frame(height: 1)
            ZenithSwitchRow(text.windowFrame, isOn: frameBinding) {
                Text(text.windowFrame).font(ZenithType.footnote)
            }
            if session.style.frame != .none {
                chips([(Style.WindowFrame.light, text.light), (.dark, text.dark)],
                      selection: session.style.frame) { value in
                    lastFrame = value
                    session.style.frame = value
                }
                .transition(.opacity)
            }
        }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: session.style.frame == .none)
    }

    // MARK: Caption

    private var captionCard: some View {
        card(text.caption) {
            TextField(text.captionPlaceholder, text: $session.style.caption)
                .textFieldStyle(.plain)
                .font(ZenithType.body)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(ZenithSurface.tileFill,
                            in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                    .strokeBorder(ZenithPanelSurface.hairline))
        }
    }

    // MARK: Output

    private var sizeLabel: String? {
        guard let output = session.outputSize else { return nil }
        let retina = output.scale > 1 ? " @\(Int(output.scale.rounded()))x" : ""
        return "\(Int(output.size.width)) × \(Int(output.size.height))\(retina)"
    }

    private var outputCard: some View {
        card(text.output, value: sizeLabel) {
            chips([(Style.Format.png, "PNG"), (.jpeg, "JPEG")],
                  selection: session.style.effectiveFormat,
                  disabled: { $0 == .jpeg && !session.style.isOpaque }) { session.style.format = $0 }
        }
    }
}

/// The checkerboard behind a clear background, quiet on the dark stage.
struct ScreenshotBeautifyChecker: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 8
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.22)))
            var path = Path()
            let rows = Int((size.height / cell).rounded(.up))
            let columns = Int((size.width / cell).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    path.addRect(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(path, with: .color(Color(white: 0.28)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
