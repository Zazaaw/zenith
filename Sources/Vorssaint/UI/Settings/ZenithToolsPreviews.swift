// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the preview cards of the tool and info pages of Settings,
// built on the shared card (`ZenithSettingsPreviewCard`).
//
// The tools are drawn where they appear on screen, with made-up rows: the
// Cleaner, Homebrew, Uninstaller and Port Manager in the menu bar panel
// under Zenith's item, Kill Process in the Command Bar, and Quick Tools'
// panels and windows over the desktop. Nothing scans, lists processes,
// calls brew or touches a device for a picture, and the loops stop while the
// window is hidden or Reduce Motion is on (`ZenithPreviewLoop`).
//
// The info pages (About, What’s New, Support, Advanced) open with a plain
// card of their own on a quiet stage instead of the desktop.

private var toolsText: ZenithPreviewsToolsStrings { .shared }

// MARK: - Loop helpers

private enum PreviewCurve {
    /// 0 before `from`, 1 after `to`, eased in between.
    static func ramp(_ phase: Double, _ from: Double, _ to: Double) -> Double {
        guard to > from else { return phase >= to ? 1 : 0 }
        let t = min(max((phase - from) / (to - from), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Up over `rise`, held, then down over `fall`: for something that comes and goes.
    static func pulse(_ phase: Double, rise: ClosedRange<Double>, fall: ClosedRange<Double>) -> Double {
        ramp(phase, rise.lowerBound, rise.upperBound) * (1 - ramp(phase, fall.lowerBound, fall.upperBound))
    }
}

private func hexColor(_ hex: UInt32) -> Color { ZenithIslandPalette.color(hex: hex) }

// MARK: - Shared pieces

/// A floating Zenith surface (the menu bar panel, the quick panel, the
/// Command Bar) in the window colour of the current appearance.
private struct PreviewSurface<Content: View>: View {
    var width: CGFloat
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(padding)
            .frame(width: width, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.97), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
    }
}

/// A tool's title row in the menu bar panel.
private struct PreviewToolHeader: View {
    let title: String
    let symbol: String
    let hex: UInt32

    var body: some View {
        HStack(spacing: 8) {
            ZenithIslandGlyphTile(symbol: symbol, tint: hexColor(hex), size: 22)
            Text(title).font(.system(size: 12.5, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }
}

/// The menu bar panel hanging under Zenith's item, holding one tool.
private struct PreviewMenuPanel<Content: View>: View {
    var width: CGFloat = 332
    /// From the right edge of the screen to the panel's.
    var trailing: CGFloat = 96
    @ViewBuilder var content: () -> Content

    var body: some View {
        PreviewSurface(width: width, content: content)
            .padding(.top, ZenithPreviewDesktop<EmptyView>.menuBarHeight + 6)
            .padding(.trailing, trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

/// A plain button drawn in a picture.
private struct PreviewButton: View {
    let title: String
    var prominent = true
    var tint: Color = .accentColor
    var pressed = false

    var body: some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: prominent ? .infinity : nil)
            .background(prominent ? tint.opacity(pressed ? 0.75 : 1) : tint.opacity(pressed ? 0.3 : 0.12),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// A checkbox drawn in a picture.
private struct PreviewCheck: View {
    var on: Bool

    var body: some View {
        Image(systemName: on ? "checkmark.square.fill" : "square")
            .font(.system(size: 13))
            .foregroundStyle(on ? Color.accentColor : Color.secondary)
    }
}

/// A switch drawn in a picture, sliding with `value` from 0 (off) to 1 (on).
private struct PreviewSwitch: View {
    var value: Double

    var body: some View {
        Capsule()
            .fill(Color.accentColor.opacity(value))
            .background(Capsule().fill(Color.primary.opacity(0.15)))
            .frame(width: 26, height: 15)
            .overlay(alignment: .leading) {
                Circle().fill(.white).frame(width: 13, height: 13)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    .offset(x: 1 + 11 * value)
            }
    }
}

/// Cells in rows of `columns`. A plain Grid: a lazy grid inside a Form row
/// trips SwiftUI's lazy layout.
private struct PreviewGrid<Cell: View>: View {
    let count: Int
    let columns: Int
    var spacing: CGFloat = 8
    @ViewBuilder let cell: (Int) -> Cell

    var body: some View {
        let rows = Array(0..<((count + columns - 1) / columns))
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(Array((row * columns)..<min(count, (row + 1) * columns)), id: \.self) { index in
                        cell(index).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

/// A picture that is not the desktop: content laid out on a `width`-point
/// stage (its height follows the card), scaled to fit, over a quiet backdrop.
private struct PreviewStage<Content: View>: View {
    var width: CGFloat = 560
    @ViewBuilder var content: (CGSize) -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / width
            let size = CGSize(width: width, height: geo.size.height / max(scale, 0.01))
            ZStack {
                backdrop
                content(size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private var backdrop: some View {
        let dark = colorScheme == .dark
        return ZStack {
            Color(white: dark ? 0.09 : 0.96)
            RadialGradient(colors: [Color.accentColor.opacity(dark ? 0.28 : 0.16), .clear],
                           center: .init(x: 0.5, y: 0.0), startRadius: 10, endRadius: 420)
            ZenithDotGrid(spacing: 18, dot: 1.2)
        }
    }
}

extension View {
    /// Zenith fork: a preview card on a page that is not a Form, as wide as
    /// the Form pages' cards at most.
    func zenithToolsPreviewWidth() -> some View {
        frame(maxWidth: 760).frame(maxWidth: .infinity)
    }

    /// Zenith fork: a preview card held above a grouped Form. Inside it, the
    /// Form would box the card in a section and scroll it away when Settings
    /// lands on a section.
    func zenithToolsPreviewPinned() -> some View {
        zenithToolsPreviewWidth()
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }
}

// MARK: - Quick Tools

/// The features of Quick Tools, in the order of the page's sections.
enum QuickToolsPreviewFeature: CaseIterable {
    case launcher, toggles, quitApps, micMute, cameraPreview, wallpaper, scratchpad, cleaningMode

    var anchor: SettingsSectionAnchor {
        switch self {
        case .launcher: return .quickLauncher
        case .toggles: return .quickToggles
        case .quitApps: return .quitApps
        case .micMute: return .micMute
        case .cameraPreview: return .cameraPreview
        case .wallpaper: return .wallpaper
        case .scratchpad: return .scratchpad
        case .cleaningMode: return .cleaningMode
        }
    }

    var feature: AppFeature {
        switch self {
        case .launcher: return .quickLauncher
        case .toggles: return .quickToggles
        case .quitApps: return .quitApps
        case .micMute: return .micMute
        case .cameraPreview: return .cameraPreview
        case .wallpaper: return .wallpaper
        case .scratchpad: return .scratchpad
        case .cleaningMode: return .cleaningMode
        }
    }

    var group: QuickToolsPreviewGroup {
        switch self {
        case .launcher, .toggles, .wallpaper: return .panel
        case .scratchpad, .cameraPreview: return .windows
        case .quitApps, .micMute, .cleaningMode: return .apps
        }
    }

    var name: String {
        switch self {
        case .launcher: return toolsText.quickLauncher
        case .toggles: return toolsText.quickToggles
        case .quitApps: return toolsText.quitApps
        case .micMute: return toolsText.micMute
        case .cameraPreview: return toolsText.cameraPreview
        case .wallpaper: return toolsText.wallpaper
        case .scratchpad: return toolsText.scratchpad
        case .cleaningMode: return toolsText.cleaningMode
        }
    }

    init?(anchor: SettingsSectionAnchor?) {
        guard let anchor, let match = Self.allCases.first(where: { $0.anchor == anchor }) else { return nil }
        self = match
    }
}

/// The card's states on Quick Tools: the features drawn together. Wallpaper
/// and Cleaning mode have pictures of their own, shown when Settings lands
/// on them.
enum QuickToolsPreviewGroup: CaseIterable {
    case panel, windows, apps

    var title: String {
        switch self {
        case .panel: return toolsText.quickPanelState
        case .windows: return toolsText.quickWindowsState
        case .apps: return toolsText.quickAppsState
        }
    }

    var features: [QuickToolsPreviewFeature] { QuickToolsPreviewFeature.allCases.filter { $0.group == self } }
}

/// The card on Quick Tools. It follows the feature Settings opened the page
/// on (a sidebar row or a search result lands on its section); the states
/// switch between groups of features, and clicking a part of the picture
/// lands on that feature's section the same way.
struct QuickToolsPreviewCard: View {
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var features = FeatureRuntime.shared
    /// The group picked in the card; nil follows the routed feature.
    @State private var pickedGroup: QuickToolsPreviewGroup?

    private var available: [QuickToolsPreviewFeature] {
        _ = features.revision
        return QuickToolsPreviewFeature.allCases.filter { $0.feature.isAvailable }
    }

    private var groups: [QuickToolsPreviewGroup] {
        QuickToolsPreviewGroup.allCases.filter { group in available.contains { $0.group == group } }
    }

    private var routed: QuickToolsPreviewFeature? {
        guard router.destination.page == .quickTools,
              let feature = QuickToolsPreviewFeature(anchor: router.destination.sectionAnchor),
              available.contains(feature) else { return nil }
        return feature
    }

    private var group: QuickToolsPreviewGroup {
        if let pickedGroup, groups.contains(pickedGroup) { return pickedGroup }
        return routed?.group ?? groups.first ?? .panel
    }

    /// The feature outlined: the routed one when its group is shown, else the group's first.
    private var shown: QuickToolsPreviewFeature {
        if let routed, routed.group == group { return routed }
        return group.features.first(where: available.contains) ?? .launcher
    }

    var body: some View {
        let states = self.groups
        ZenithSettingsPreviewCard(
            id: "quickTools", caption: caption,
            states: states.map(\.title),
            selection: Binding(get: { states.firstIndex(of: group) ?? 0 },
                               set: { pickedGroup = states.indices.contains($0) ? states[$0] : nil }),
            highlight: shown.name
        ) {
            QuickToolsPreviewPicture(group: group, shown: shown, available: available, open: open)
        }
        .onChange(of: router.requestID) { _, _ in pickedGroup = nil }
    }

    private var caption: String {
        switch shown {
        case .wallpaper: return toolsText.quickWallpaperCaption
        case .cleaningMode: return toolsText.quickCleaningCaption
        default:
            switch group {
            case .panel: return toolsText.quickPanelCaption
            case .windows: return toolsText.quickWindowsCaption
            case .apps: return toolsText.quickAppsCaption
            }
        }
    }

    private func open(_ feature: QuickToolsPreviewFeature) {
        pickedGroup = nil
        // Zenith fork: Mic Mute and Camera Preview have pages of their own.
        router.request(feature.anchor.page == .quickTools
                       ? FeatureSettingsDestination(.quickTools, sectionAnchor: feature.anchor)
                       : feature.feature.settingsDestination)
    }
}

/// The picture for a group of Quick Tools: the features where they appear,
/// the `shown` one outlined.
struct QuickToolsPreviewPicture: View {
    let group: QuickToolsPreviewGroup
    let shown: QuickToolsPreviewFeature
    let available: [QuickToolsPreviewFeature]
    let open: (QuickToolsPreviewFeature) -> Void

    var body: some View {
        ZenithPreviewDesktop(screenWidth: 900) {
            ZenithPreviewLoop(period: 6, stillPhase: 0.55) { phase in
                ZStack {
                    switch shown {
                    case .wallpaper: wallpaper(phase)
                    case .cleaningMode: cleaning(phase).modifier(part(.cleaningMode, radius: 0))
                    default:
                        switch group {
                        case .panel: panel(phase)
                        case .windows: windows(phase)
                        case .apps: apps(phase)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func has(_ feature: QuickToolsPreviewFeature) -> Bool { available.contains(feature) }

    private func part(_ feature: QuickToolsPreviewFeature, radius: CGFloat = 16) -> some ViewModifier {
        PreviewPartModifier(radius: radius, highlighted: shown == feature) { open(feature) }
    }

    // MARK: Panel

    private static let tiles: [(String, String, UInt32)] = [
        ("bolt", toolsText.sampleKeepAwake, 0xF59E0B), ("sparkle", toolsText.sampleCleaner, 0x2DD4BF),
        ("togglepower", toolsText.sampleToggles, 0x60A5FA), ("mic", toolsText.sampleMic, 0xF472B6),
        ("text.viewfinder", toolsText.sampleText, 0x22D3EE), ("eyedropper", toolsText.sampleColor, 0xE879F9),
        ("doc.on.clipboard", toolsText.sampleClipboard, 0xA78BFA), ("rectangle.3.group", toolsText.sampleLayout, 0x38BDF8),
        ("keyboard", toolsText.sampleCleaning, 0xA3E635), ("shippingbox", toolsText.sampleHomebrew, 0xFB923C),
        ("web.camera", toolsText.sampleCamera, 0x10B981), ("note.text", toolsText.sampleNotes, 0xFACC15),
    ]

    @ViewBuilder private func panel(_ phase: Double) -> some View {
        let selected = Int(phase * Double(Self.tiles.count)) % Self.tiles.count
        HStack(alignment: .top, spacing: 40) {
            if has(.launcher) {
                PreviewSurface(width: 330, cornerRadius: 22, padding: 16) {
                    HStack {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "asterisk").font(.system(size: 16, weight: .bold))
                        Spacer()
                        Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    PreviewGrid(count: Self.tiles.count, columns: 4, spacing: 10) { index in
                        let tile = Self.tiles[index]
                        VStack(spacing: 5) {
                            ZenithIslandGlyphTile(symbol: tile.0, tint: hexColor(tile.2), size: 40, cornerRadius: 11)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: index == selected ? 2 : 0)
                                        .padding(-2)
                                }
                            Text(tile.1).font(.system(size: 9.5, weight: .medium)).lineLimit(1)
                        }
                    }
                }
                .modifier(part(.launcher, radius: 24))
            }
            if has(.toggles) {
                toggles(phase).modifier(part(.toggles))
            }
        }
        .padding(.top, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func toggles(_ phase: Double) -> some View {
        let dark = PreviewCurve.pulse(phase, rise: 0.3...0.4, fall: 0.85...0.95)
        let rows: [(String, String, Double)] = [
            ("moon.fill", toolsText.sampleDarkMode, dark), ("eye", toolsText.sampleHiddenFiles, 0),
            ("desktopcomputer", toolsText.sampleDesktopIcons, 1), ("trash", toolsText.sampleEmptyTrash, 0),
        ]
        return PreviewSurface(width: 250) {
            ZenithPanelSectionLabel(text: toolsText.quickToggles)
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Image(systemName: rows[index].0).font(.system(size: 12)).frame(width: 18).foregroundStyle(.secondary)
                    Text(rows[index].1).font(.system(size: 12))
                    Spacer(minLength: 0)
                    PreviewSwitch(value: rows[index].2)
                }
            }
        }
    }

    // MARK: Windows

    @ViewBuilder private func windows(_ phase: Double) -> some View {
        ZStack {
            if has(.scratchpad) {
                scratchpad(phase)
                    .modifier(part(.scratchpad))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 120).padding(.top, 70)
            }
            if has(.cameraPreview) {
                camera(phase)
                    .modifier(part(.cameraPreview, radius: 90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 140).padding(.bottom, 50)
            }
        }
    }

    private func scratchpad(_ phase: Double) -> some View {
        let lines = toolsText.sampleNoteLines
        let total = lines.reduce(0) { $0 + $1.count }
        let typed = Int(Double(total) * PreviewCurve.ramp(phase, 0.05, 0.8))
        return PreviewSurface(width: 320, cornerRadius: 12) {
            HStack(spacing: 6) {
                ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(hexColor($0)).frame(width: 10, height: 10) }
                Spacer()
                Text(toolsText.scratchpad).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 42, height: 1)
            }
            Text(toolsText.sampleNoteTitle).font(.system(size: 15, weight: .bold))
            VStack(alignment: .leading, spacing: 5) {
                ForEach(lines.indices, id: \.self) { index in
                    let before = lines[..<index].reduce(0) { $0 + $1.count }
                    let shownCount = min(max(typed - before, 0), lines[index].count)
                    Text("– " + String(lines[index].prefix(shownCount)))
                        .font(.system(size: 12.5))
                        .opacity(shownCount > 0 ? 1 : 0)
                }
            }
            .frame(height: 96, alignment: .topLeading)
        }
    }

    private func camera(_ phase: Double) -> some View {
        let breathe = 1 + 0.02 * sin(phase * 2 * .pi)
        return ZStack {
            Circle().fill(LinearGradient(colors: [Color(white: 0.32), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 92))
                .foregroundStyle(.white.opacity(0.55))
                .scaleEffect(breathe)
                .offset(y: 14)
        }
        .frame(width: 170, height: 170)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }

    // MARK: Apps

    private static let dock: [(String, UInt32)] = [
        ("face.smiling", 0x38BDF8), ("safari", 0x60A5FA), ("envelope.fill", 0x3B82F6), ("music.note", 0xFB7185),
        ("message.fill", 0x34D399), ("photo", 0xFACC15), ("terminal", 0x94A3B8),
    ]

    @ViewBuilder private func apps(_ phase: Double) -> some View {
        ZStack {
            if has(.micMute) {
                micIsland(phase)
                    .modifier(part(.micMute, radius: 18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            if has(.quitApps) {
                dock(phase)
                    .modifier(part(.quitApps, radius: 22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16)
            }
        }
    }

    private func micIsland(_ phase: Double) -> some View {
        let open = PreviewCurve.pulse(phase, rise: 0.08...0.2, fall: 0.85...0.97)
        return HStack(spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ZenithStatus.error)
            Text(toolsText.sampleMicMuted)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(open)
        }
        .padding(.horizontal, 18)
        .frame(width: 200 + 60 * open, height: 30 + 10 * open)
        .background(Color.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16, style: .continuous))
    }

    private func dock(_ phase: Double) -> some View {
        let quit = PreviewCurve.pulse(phase, rise: 0.35...0.55, fall: 0.88...0.98)
        return VStack(spacing: 10) {
            Text(toolsText.sampleQuitting)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.95), in: Capsule())
                .opacity(PreviewCurve.pulse(phase, rise: 0.28...0.36, fall: 0.6...0.7))
            HStack(spacing: 10) {
                ForEach(Self.dock.indices, id: \.self) { index in
                    let fades = index > 0 && index < 6
                    VStack(spacing: 4) {
                        ZenithIslandGlyphTile(symbol: Self.dock[index].0, tint: hexColor(Self.dock[index].1), size: 48, cornerRadius: 12)
                        Circle().fill(Color.primary.opacity(0.7)).frame(width: 4, height: 4)
                            .opacity(fades ? 1 - quit : 1)
                    }
                    .opacity(fades ? 1 - 0.6 * quit : 1)
                    .scaleEffect(fades ? 1 - 0.12 * quit : 1)
                }
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        }
    }

    // MARK: Wallpaper and cleaning mode

    private static let wallpapers: [[UInt32]] = [
        [0x312E81, 0xA855F7], [0x0F766E, 0x99F6E4], [0x9A3412, 0xFDBA74],
        [0x1E3A8A, 0x60A5FA], [0x3F6212, 0xBEF264], [0x831843, 0xF9A8D4],
    ]

    private func wallpaper(_ phase: Double) -> some View {
        let picked = Int(phase * Double(Self.wallpapers.count)) % Self.wallpapers.count
        return ZStack {
            LinearGradient(colors: Self.wallpapers[picked].map(hexColor), startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.65)
                .padding(.top, ZenithPreviewDesktop<EmptyView>.menuBarHeight)
                .animation(.easeInOut(duration: 0.6), value: picked)
            PreviewMenuPanel(width: 300, trailing: 150) {
                ZenithPanelSectionLabel(text: toolsText.sampleWallpapers)
                PreviewGrid(count: Self.wallpapers.count, columns: 3, spacing: 8) { index in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(LinearGradient(colors: Self.wallpapers[index].map(hexColor), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: index == picked ? 2.5 : 0).padding(-3))
                }
                HStack {
                    Text(toolsText.sampleAllDisplays).font(.system(size: 12))
                    Spacer()
                    PreviewSwitch(value: 1)
                }
            }
            .modifier(part(.wallpaper))
        }
    }

    private func cleaning(_ phase: Double) -> some View {
        let sweep = phase * 1.6 - 0.3
        return ZStack {
            Color.black
            LinearGradient(stops: [.init(color: .clear, location: max(0, sweep - 0.15)),
                                   .init(color: .white.opacity(0.10), location: min(max(sweep, 0), 1)),
                                   .init(color: .clear, location: min(sweep + 0.15, 1))],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                Text(toolsText.sampleCleaningTitle).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                Text(toolsText.sampleCleaningHint).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                Text(toolsText.sampleCleaningUnlock)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(.white.opacity(0.15), in: Capsule())
                    .padding(.top, 6)
            }
        }
    }
}

/// `zenithPreviewPart` as a modifier value, so a picture can pick it per feature.
private struct PreviewPartModifier: ViewModifier {
    let radius: CGFloat
    let highlighted: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content.zenithPreviewPart(cornerRadius: radius, highlighted: highlighted, action: action)
    }
}

// MARK: - Cleaner

/// The Cleaner's card: a scan that ends on what is safe to clean, and with
/// WhatsApp downloads on, its tool as a second state.
struct CleanerPreviewCard: View {
    /// 0 the cleaner, 1 WhatsApp downloads; nil when only the cleaner is on.
    let selection: Binding<Int>?

    var body: some View {
        let whatsApp = selection?.wrappedValue == 1
        ZenithSettingsPreviewCard(
            id: "cleaner", caption: whatsApp ? toolsText.whatsAppCaption : toolsText.cleanerCaption,
            states: selection == nil ? [] : [toolsText.cleanerState, toolsText.whatsAppState],
            selection: selection
        ) {
            ZenithPreviewDesktop(screenWidth: 760) {
                ZenithPreviewLoop(period: 7, stillPhase: 0.8) { phase in
                    PreviewMenuPanel {
                        if whatsApp { CleanerPreviewWhatsApp(phase: phase) } else { CleanerPreviewScan(phase: phase) }
                    }
                }
            }
        }
    }
}

private struct CleanerPreviewScan: View {
    let phase: Double

    private static let rows: [(String, String, String)] = [
        ("archivebox", toolsText.cleanerCaches, "2.4 GB"), ("hammer", toolsText.cleanerDeveloper, "1.8 GB"),
        ("doc.text", toolsText.cleanerLogs, "312 MB"), ("power", toolsText.cleanerLogin, "3 items"),
    ]

    var body: some View {
        PreviewToolHeader(title: toolsText.cleanerTitle, symbol: "sparkle", hex: 0x2DD4BF)
        ZStack(alignment: .top) {
            scanning.opacity(1 - PreviewCurve.ramp(phase, 0.3, 0.36))
            results.opacity(PreviewCurve.ramp(phase, 0.32, 0.38))
        }
        .frame(height: 194, alignment: .top)
    }

    private var scanning: some View {
        let progress = PreviewCurve.ramp(phase, 0.02, 0.3)
        let label = Self.rows[min(Int(progress * Double(Self.rows.count)), Self.rows.count - 1)].1
        return VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 34, weight: .light)).foregroundStyle(.secondary)
            Text(toolsText.cleanerScanning).font(.system(size: 13, weight: .semibold))
            Capsule().fill(Color.primary.opacity(0.1)).frame(width: 200, height: 5)
                .overlay(alignment: .leading) { Capsule().fill(Color.accentColor).frame(width: 200 * progress, height: 5) }
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.top, 34)
        .frame(maxWidth: .infinity)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZenithPanelSectionLabel(text: toolsText.cleanerSafe)
                Spacer()
                Text("4.6 GB").font(ZenithType.mono(10.5, weight: .semibold)).foregroundStyle(ZenithStatus.success)
            }
            ForEach(Self.rows.indices, id: \.self) { index in
                let row = Self.rows[index]
                HStack(spacing: 8) {
                    PreviewCheck(on: true)
                    Image(systemName: row.0).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                    Text(row.1).font(.system(size: 12))
                    Spacer(minLength: 0)
                    Text(row.2).font(ZenithType.mono(10.5)).foregroundStyle(.secondary)
                }
                .opacity(PreviewCurve.ramp(phase, 0.36 + Double(index) * 0.04, 0.42 + Double(index) * 0.04))
            }
            Divider()
            HStack(spacing: 8) {
                PreviewCheck(on: false)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(toolsText.cleanerOptional).font(.system(size: 12))
                    Text(toolsText.cleanerOptionalRow).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text("6.1 GB").font(ZenithType.mono(10.5)).foregroundStyle(.secondary)
            }
            .opacity(PreviewCurve.ramp(phase, 0.52, 0.58))
            PreviewButton(title: toolsText.cleanerButton)
                .opacity(PreviewCurve.ramp(phase, 0.56, 0.62))
        }
    }
}

private struct CleanerPreviewWhatsApp: View {
    let phase: Double

    private static let files: [(String, String, String, String, Bool)] = [
        ("film", "WhatsApp Video 2026-08-14.mp4", "101 d", "318 MB", true),
        ("doc.richtext", "WhatsApp Document 2026-09-02.pdf", "82 d", "92 MB", true),
        ("photo", "WhatsApp Image 2026-09-20.jpeg", "64 d", "2 MB", true),
        ("photo", "WhatsApp Image 2026-11-19.jpeg", "4 d", "1.8 MB", false),
        ("film", "WhatsApp Video 2026-11-21.mp4", "2 d", "46 MB", false),
    ]

    var body: some View {
        PreviewToolHeader(title: toolsText.whatsAppTitle, symbol: "arrow.down.doc", hex: 0x10B981)
        HStack(spacing: 6) {
            Image(systemName: "folder").font(.system(size: 11)).foregroundStyle(.secondary)
            Text(toolsText.whatsAppFolder).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text("30 d").font(ZenithType.mono(10)).foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.files.indices, id: \.self) { index in
                let file = Self.files[index]
                let picked = file.4 ? PreviewCurve.ramp(phase, 0.2 + Double(index) * 0.08, 0.26 + Double(index) * 0.08) : 0
                let gone = file.4 ? PreviewCurve.pulse(phase, rise: 0.62...0.72, fall: 0.94...0.99) : 0
                HStack(spacing: 8) {
                    PreviewCheck(on: picked > 0.5)
                    Image(systemName: file.0).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(file.1).font(.system(size: 11.5)).lineLimit(1).truncationMode(.middle)
                        Text("\(file.2) · \(file.3)").font(ZenithType.mono(9.5)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(file.4 ? toolsText.whatsAppTrash : toolsText.whatsAppKeep)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(file.4 ? ZenithStatus.warning : ZenithStatus.success)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((file.4 ? ZenithStatus.warning : ZenithStatus.success).opacity(0.12), in: Capsule())
                }
                .opacity(1 - 0.75 * gone)
                .offset(x: 18 * gone)
            }
        }
        PreviewButton(title: toolsText.whatsAppButton, pressed: PreviewCurve.pulse(phase, rise: 0.56...0.6, fall: 0.64...0.68) > 0.5)
    }
}

// MARK: - Homebrew

/// Homebrew's card: the installed packages in the menu bar panel with the
/// updates waiting, one of them upgrading.
struct HomebrewPreviewCard: View {
    var body: some View {
        ZenithSettingsPreviewCard(id: "homebrew", caption: toolsText.homebrewCaption) {
            ZenithPreviewDesktop(screenWidth: 760) {
                ZenithPreviewLoop(period: 7, stillPhase: 0.2) { phase in
                    PreviewMenuPanel { HomebrewPreviewPanel(phase: phase) }
                }
            }
        }
    }
}

private struct HomebrewPreviewPanel: View {
    let phase: Double

    private static let packages: [(name: String, old: String, new: String?, cask: Bool)] = [
        ("git", "2.47.0", "2.47.1", false), ("node", "22.11.0", "23.3.0", false),
        ("Visual Studio Code", "1.95.3", "1.96.0", true), ("ffmpeg", "7.1", nil, false),
    ]

    var body: some View {
        let upgrading = PreviewCurve.pulse(phase, rise: 0.3...0.32, fall: 0.62...0.64) > 0.5
        let upgraded = PreviewCurve.pulse(phase, rise: 0.62...0.64, fall: 0.96...0.99) > 0.5
        PreviewToolHeader(title: toolsText.homebrewTitle, symbol: "shippingbox", hex: 0xFB923C)
        HStack(spacing: 0) {
            ForEach([toolsText.homebrewSearch, toolsText.homebrewInstalled], id: \.self) { title in
                Text(title)
                    .font(.system(size: 11, weight: title == toolsText.homebrewInstalled ? .semibold : .regular))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(title == toolsText.homebrewInstalled ? Color.primary.opacity(0.1) : .clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        HStack(spacing: 8) {
            Label(upgraded ? toolsText.homebrewUpdatesLeft : toolsText.homebrewUpdates, systemImage: "arrow.up.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(ZenithStatus.warning)
            Spacer()
            PreviewButton(title: toolsText.homebrewUpgradeAll, prominent: false)
        }
        VStack(spacing: 2) {
            ForEach(Self.packages.indices, id: \.self) { index in
                row(index, upgrading: index == 0 && upgrading, upgraded: index == 0 && upgraded)
            }
        }
    }

    private func row(_ index: Int, upgrading: Bool, upgraded: Bool) -> some View {
        let package = Self.packages[index]
        let pending = package.new != nil && !upgraded
        let version = upgraded ? (package.new ?? package.old) : (package.new.map { "\(package.old) → \($0)" } ?? package.old)
        return HStack(spacing: 8) {
            Image(systemName: package.cask ? "app" : "terminal")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(package.name).font(.system(size: 12, weight: index == 0 ? .semibold : .regular))
                Text(upgrading ? toolsText.homebrewUpgrading : version)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if upgrading {
                ProgressView().controlSize(.mini)
            } else if pending {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(ZenithStatus.warning)
            } else {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(ZenithStatus.success)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 5)
        .background(index == 0 ? Color.accentColor.opacity(0.12) : .clear,
                    in: RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous))
    }
}

// MARK: - Uninstaller

/// The Uninstaller's card: an app dropped on the panel and the files it
/// left around the Mac, with their sizes.
struct UninstallerPreviewCard: View {
    var body: some View {
        ZenithSettingsPreviewCard(id: "uninstaller", caption: toolsText.uninstallerCaption) {
            ZenithPreviewDesktop(screenWidth: 760) {
                ZenithPreviewLoop(period: 7, stillPhase: 0.8) { phase in
                    PreviewMenuPanel { UninstallerPreviewPanel(phase: phase) }
                }
            }
        }
    }
}

private struct UninstallerPreviewPanel: View {
    let phase: Double

    private static let files: [(String, String, String)] = [
        ("folder", "Application Support/Lumen", "1.4 GB"),
        ("folder", "Caches/com.example.lumen", "486 MB"),
        ("folder", "Containers/com.example.lumen", "92 MB"),
        ("doc.text", "Logs/Lumen", "2.1 MB"),
        ("doc", "Preferences/com.example.lumen.plist", "12 KB"),
    ]

    var body: some View {
        let dropped = PreviewCurve.ramp(phase, 0.04, 0.16)
        PreviewToolHeader(title: toolsText.uninstallerTitle, symbol: "trash", hex: 0xF87171)
        HStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: "sun.max.fill", tint: hexColor(0xF59E0B), size: 40, cornerRadius: 10)
                .scaleEffect(0.7 + 0.3 * dropped)
                .offset(y: -18 * (1 - dropped))
                .opacity(dropped)
            VStack(alignment: .leading, spacing: 2) {
                Text(toolsText.uninstallerApp).font(.system(size: 13, weight: .semibold))
                Text(toolsText.uninstallerAppDetail).font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            .opacity(dropped)
            Spacer()
        }
        HStack {
            ZenithPanelSectionLabel(text: toolsText.uninstallerFound)
            Spacer()
        }
        .opacity(PreviewCurve.ramp(phase, 0.16, 0.22))
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Self.files.indices, id: \.self) { index in
                let file = Self.files[index]
                let found = PreviewCurve.ramp(phase, 0.2 + Double(index) * 0.06, 0.26 + Double(index) * 0.06)
                HStack(spacing: 8) {
                    PreviewCheck(on: found > 0.5)
                    Image(systemName: file.0).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
                    Text(file.1).font(.system(size: 11)).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(file.2).font(ZenithType.mono(10.5)).foregroundStyle(.secondary)
                }
                .opacity(0.25 + 0.75 * found)
            }
        }
        PreviewButton(title: toolsText.uninstallerButton, tint: ZenithStatus.error)
            .opacity(PreviewCurve.ramp(phase, 0.5, 0.56))
    }
}

// MARK: - Kill Process

/// Kill Process's card: the Command Bar listing processes by CPU, the
/// busiest one being quit.
struct KillProcessPreviewCard: View {
    var body: some View {
        ZenithSettingsPreviewCard(id: "killProcess", caption: toolsText.killCaption) {
            ZenithPreviewDesktop(screenWidth: 860) {
                ZenithPreviewLoop(period: 6, stillPhase: 0.2) { phase in
                    KillProcessPreviewBar(phase: phase)
                        .padding(.top, 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }
}

private struct KillProcessPreviewBar: View {
    let phase: Double

    private static let processes: [(String, UInt32, String, String, String)] = [
        ("macwindow", 0x60A5FA, "Renderer Helper", "48.2%", "1.3 GB"),
        ("terminal", 0x34D399, "node", "22.4%", "412 MB"),
        ("magnifyingglass", 0x94A3B8, "mds_stores", "6.1%", "96 MB"),
        ("music.note", 0xFB7185, "Music", "2.3%", "238 MB"),
        ("face.smiling", 0x38BDF8, "Finder", "0.8%", "140 MB"),
    ]

    var body: some View {
        let pressed = PreviewCurve.pulse(phase, rise: 0.3...0.33, fall: 0.4...0.43) > 0.5
        let gone = PreviewCurve.pulse(phase, rise: 0.42...0.56, fall: 0.94...0.99)
        let typed = Int(Double(toolsText.killQuery.count) * PreviewCurve.ramp(phase, 0.02, 0.16))
        PreviewSurface(width: 560, cornerRadius: 22, padding: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundStyle(.secondary)
                Text(String(toolsText.killQuery.prefix(typed)))
                    .font(.system(size: 17))
                Rectangle().fill(Color.accentColor).frame(width: 2, height: 20)
                Spacer()
            }
            Divider()
            VStack(spacing: 0) {
                ForEach(Self.processes.indices, id: \.self) { index in
                    let process = Self.processes[index]
                    let collapse = index == 0 ? gone : 0
                    HStack(spacing: 10) {
                        ZenithIslandGlyphTile(symbol: process.0, tint: hexColor(process.1), size: 26, cornerRadius: 7)
                        Text(process.2).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(process.3).font(ZenithType.mono(11.5)).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
                        Text(process.4).font(ZenithType.mono(11.5)).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
                        PreviewButton(title: toolsText.killButton, prominent: false,
                                      tint: index == 0 ? ZenithStatus.error : .secondary, pressed: index == 0 && pressed)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 40 * (1 - collapse))
                    .background(index == 0 ? Color.accentColor.opacity(0.12 * (1 - collapse)) : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(1 - collapse)
                    .clipped()
                }
            }
        }
    }
}

// MARK: - Port Manager

/// Port Manager's card: the open ports in the menu bar panel with the
/// process behind each, a dev server being stopped.
struct PortManagerPreviewCard: View {
    var body: some View {
        ZenithSettingsPreviewCard(id: "portManager", caption: toolsText.portCaption) {
            ZenithPreviewDesktop(screenWidth: 760) {
                ZenithPreviewLoop(period: 6, stillPhase: 0.2) { phase in
                    PreviewMenuPanel { PortManagerPreviewPanel(phase: phase) }
                }
            }
        }
    }
}

private struct PortManagerPreviewPanel: View {
    let phase: Double

    private static let ports: [(Int, String, Int, String)] = [
        (3000, "node", 4121, "127.0.0.1"), (5173, "node", 4188, "127.0.0.1"),
        (8080, "python3", 3920, "*"), (5432, "postgres", 702, "127.0.0.1"),
    ]

    var body: some View {
        let pressed = PreviewCurve.pulse(phase, rise: 0.3...0.33, fall: 0.4...0.43) > 0.5
        let gone = PreviewCurve.pulse(phase, rise: 0.42...0.56, fall: 0.94...0.99)
        PreviewToolHeader(title: toolsText.portTitle, symbol: "network", hex: 0x60A5FA)
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text(toolsText.portFilter).foregroundStyle(.tertiary)
            Spacer()
        }
        .font(.system(size: 11.5))
        .padding(7)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        VStack(spacing: 0) {
            ForEach(Self.ports.indices, id: \.self) { index in
                let port = Self.ports[index]
                let collapse = index == 1 ? gone : 0
                HStack(spacing: 8) {
                    Image(systemName: "network").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor).frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(String(port.0)).font(.system(size: 12, weight: .semibold, design: .monospaced))
                            Text("TCP").font(.system(size: 8.5, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.primary.opacity(0.08), in: Capsule())
                            if port.3 == "*" {
                                Text(toolsText.portAllInterfaces).font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(ZenithStatus.warning)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(ZenithStatus.warning.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(port.1).font(.system(size: 11))
                        Text("PID \(String(port.2))  •  \(port.3)").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    PreviewButton(title: toolsText.portKill, prominent: false,
                                  tint: index == 1 ? ZenithStatus.error : .secondary, pressed: index == 1 && pressed)
                }
                .padding(.vertical, 5)
                .frame(height: 54 * (1 - collapse))
                .opacity(1 - collapse)
                .clipped()
            }
        }
    }
}

// MARK: - Advanced

/// What Advanced's tools reach, for its card.
enum AdvancedPreviewPart: CaseIterable {
    case backup, permissions, uninstall

    var title: String {
        switch self {
        case .backup: return toolsText.advancedBackup
        case .permissions: return toolsText.advancedPermissions
        case .uninstall: return toolsText.advancedUninstall
        }
    }

    var detail: String {
        switch self {
        case .backup: return toolsText.advancedBackupDetail
        case .permissions: return toolsText.advancedPermissionsDetail
        case .uninstall: return toolsText.advancedUninstallDetail
        }
    }

    var symbol: String {
        switch self {
        case .backup: return "square.and.arrow.up.on.square"
        case .permissions: return "lock.shield"
        case .uninstall: return "trash"
        }
    }

    var hex: UInt32 {
        switch self {
        case .backup: return 0x60A5FA
        case .permissions: return 0xF59E0B
        case .uninstall: return 0xF87171
        }
    }

    /// The scroll target of its section on the page.
    var sectionID: String { "zenith.advanced.\(self)" }
}

/// Advanced's card: Zenith in the middle and lines out to what the page's
/// tools touch. Clicking one scrolls to its section.
struct AdvancedPreviewCard: View {
    let highlighted: AdvancedPreviewPart
    let open: (AdvancedPreviewPart) -> Void

    var body: some View {
        ZenithSettingsPreviewCard(id: "advanced", caption: toolsText.advancedCaption, highlight: highlighted.title) {
            PreviewStage { size in
                ZenithPreviewLoop(period: 4, stillPhase: 0.3) { phase in
                    diagram(size: size, phase: phase)
                }
            }
        }
    }

    private func diagram(size: CGSize, phase: Double) -> some View {
        let parts = AdvancedPreviewPart.allCases
        let hub = CGPoint(x: size.width / 2, y: size.height * 0.26)
        let nodes = parts.indices.map { CGPoint(x: size.width * (0.19 + 0.31 * Double($0)), y: size.height * 0.72) }
        return ZStack {
            ForEach(parts.indices, id: \.self) { index in
                let target = CGPoint(x: nodes[index].x, y: nodes[index].y - 38)
                Path { path in
                    path.move(to: CGPoint(x: hub.x, y: hub.y + 36))
                    path.addQuadCurve(to: target, control: CGPoint(x: target.x, y: hub.y + 40))
                }
                .stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                let t = (phase + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(hexColor(parts[index].hex))
                    .frame(width: 7, height: 7)
                    .position(quad(from: CGPoint(x: hub.x, y: hub.y + 36), to: target,
                                   control: CGPoint(x: target.x, y: hub.y + 40), t: t))
                    .opacity(sin(t * .pi))
            }
            ZenithAboutAppIcon(size: 64)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .position(hub)
            ForEach(parts.indices, id: \.self) { index in
                node(parts[index])
                    .zenithPreviewPart(cornerRadius: 12, highlighted: highlighted == parts[index]) { open(parts[index]) }
                    .position(nodes[index])
            }
        }
    }

    private func node(_ part: AdvancedPreviewPart) -> some View {
        VStack(spacing: 6) {
            ZenithIslandGlyphTile(symbol: part.symbol, tint: hexColor(part.hex), size: 30)
            Text(part.title).font(.system(size: 12.5, weight: .semibold))
            Text(part.detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: 152, height: 84)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
    }

    private func quad(from: CGPoint, to: CGPoint, control: CGPoint, t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                       y: u * u * from.y + 2 * u * t * control.y + t * t * to.y)
    }
}

// MARK: - About

/// About's card: the app icon under a slow halo, the name, version and studio.
struct AboutPreviewCard: View {
    var body: some View {
        ZenithSettingsPreviewCard(id: "about", caption: toolsText.aboutCaption) {
            PreviewStage { _ in
                ZenithPreviewLoop(period: 10, stillPhase: 0.1) { phase in
                    HStack(spacing: 30) {
                        ZStack {
                            // A soft halo turning slowly: the colours fade out from
                            // the middle, so no blur is needed.
                            Circle()
                                .fill(AngularGradient(colors: [.accentColor, .purple, .pink, .orange, .accentColor],
                                                      center: .center, angle: .degrees(phase * 360)))
                                .mask(RadialGradient(colors: [.black, .black.opacity(0.35), .clear],
                                                     center: .center, startRadius: 30, endRadius: 100))
                                .frame(width: 200, height: 200)
                                .opacity(0.6)
                            ZenithAboutAppIcon(size: 104)
                                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppInfo.name)
                                .font(.system(size: 40, weight: .bold))
                                .tracking(ZenithType.pageTitleTracking)
                            Text(toolsText.aboutVersion(AppInfo.version))
                                .font(ZenithType.mono(13))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(toolsText.aboutBy).foregroundStyle(.secondary)
                                BrandBadge(size: 18)
                                Text(AppInfo.maker).fontWeight(.semibold)
                            }
                            .font(.system(size: 14))
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

// MARK: - What’s New

/// What’s New's card: the version and its first highlights.
struct ReleaseNotesPreviewCard: View {
    let notes: ReleaseNotes

    /// Up to three bullets, added ones first, without their Markdown marks.
    private var highlights: [(String, String)] {
        let ordered = notes.sections.sorted { ($0.title.lowercased() == "added" ? 0 : 1) < ($1.title.lowercased() == "added" ? 0 : 1) }
        var picked: [(String, String)] = []
        for section in ordered {
            for bullet in section.bulletItems where picked.count < 3 {
                let plain = bullet.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                // The first sentence is the highlight; thanks and details stay on the page.
                let first = plain.range(of: ". ").map { String(plain[..<$0.lowerBound]) + "." } ?? plain
                picked.append((symbol(section.title), first))
            }
        }
        return picked
    }

    var body: some View {
        ZenithSettingsPreviewCard(id: "releaseNotes", caption: toolsText.notesCaption) {
            PreviewStage { _ in
                ZenithPreviewLoop(period: 6, stillPhase: 0.5) { phase in
                    HStack(alignment: .center, spacing: 28) {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .scaleEffect(1 + 0.06 * sin(phase * 2 * .pi))
                            Text(toolsText.notesTitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                            Text("v\(notes.version)")
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .tracking(-1)
                            if let date = notes.date {
                                Text(date).font(ZenithType.mono(11)).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 170, alignment: .leading)
                        VStack(alignment: .leading, spacing: 12) {
                            let items = highlights.isEmpty ? [("checkmark.circle.fill", toolsText.notesFallback)] : highlights
                            ForEach(items.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: items[index].0)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 18)
                                    Text(items[index].1)
                                        .font(.system(size: 12.5))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(16)
                        .frame(width: 330, alignment: .leading)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func symbol(_ title: String) -> String {
        switch title.lowercased() {
        case "added": return "plus.circle.fill"
        case "changed": return "slider.horizontal.3"
        case "fixed": return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Support

/// Support's card: a heart with a star and a coffee circling it.
struct SupportPreviewCard: View {
    var body: some View {
        ZenithSettingsPreviewCard(id: "support", caption: toolsText.supportCaption) {
            PreviewStage { size in
                ZenithPreviewLoop(period: 8, stillPhase: 0.15) { phase in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
                    ZStack {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                            .frame(width: 190, height: 190)
                            .position(center)
                        orbiter("star.fill", tint: .yellow, angle: phase * 360, center: center)
                        orbiter("cup.and.saucer.fill", tint: .orange, angle: phase * 360 + 180, center: center)
                        ZStack {
                            Circle().fill(LinearGradient(colors: [hexColor(0xF472B6), hexColor(0xE11D48)], startPoint: .top, endPoint: .bottom)).frame(width: 84, height: 84)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.white)
                                .scaleEffect(1 + 0.07 * max(0, sin(phase * 4 * .pi)))
                        }
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
                        .position(center)
                        Text(toolsText.supportLine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .position(x: center.x, y: size.height - 26)
                    }
                }
            }
        }
    }

    private func orbiter(_ symbol: String, tint: Color, angle: Double, center: CGPoint) -> some View {
        let radians = angle * .pi / 180
        return Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 38, height: 38)
            .background(Circle().fill(tint.opacity(0.14)))
            .position(x: center.x + 95 * cos(radians), y: center.y + 95 * sin(radians))
    }
}
