// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Zenith fork: Settings → Privacy Blur, a feature page on the Settings kit
/// (docs/SETTINGS-KIT.md): the hero with the master switch (which asks for
/// Accessibility the first time it turns on), a chat window frosting on the
/// stage, the apps, what to blur in each (pictures of the window's parts),
/// how strong, how to peek, and when it blurs. Everything writes
/// `PrivacyBlurDefaults`; `PrivacyBlurService` follows.
struct PrivacyBlurSettingsPage: View {
    @ObservedObject private var service = PrivacyBlurService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(PrivacyBlurDefaults.enabled) private var enabled = false
    @AppStorage(PrivacyBlurDefaults.strength) private var strength = PrivacyBlurDefaults.defaultStrength
    @AppStorage(PrivacyBlurDefaults.hover) private var hover = PrivacyBlurHover.defaultValue.rawValue
    @AppStorage(PrivacyBlurDefaults.holdKey) private var holdKey = PrivacyBlurHoldKey.none.rawValue
    @AppStorage(PrivacyBlurDefaults.revealWhileTyping) private var revealWhileTyping = false
    @AppStorage(PrivacyBlurDefaults.when) private var when = PrivacyBlurWhen.always.rawValue
    @AppStorage(PrivacyBlurDefaults.presentationMode) private var presentation = false
    @AppStorage(PrivacyBlurDefaults.shortcut) private var shortcut = PrivacyBlurService.defaultShortcut.storageValue
    @State private var stageState = 0
    @State private var chosenApp: String?
    /// Bumped after each write of a preference that is not a plain value.
    @State private var revision = 0

    private let text = ZenithStrings.privacyBlur(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                           isOn: Binding(get: { enabled }, set: { service.setEnabled($0) }),
                           switchLabel: text.enable, switchHint: text.enableHint, animation: .privacyBlur)
                    .zenithSectionAnchor(.zenithPrivacyBlur, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                if enabled, !permissions.accessibility {
                    ZenithCallout(.warning, text.accessibilityNeeded) {
                        Button(text.openAccessibility) { Permissions.shared.requestAccessibility() }
                    }
                }
                ZenithStage(caption: text.stageCaption, states: [text.stageBlurred, text.stageHover],
                            selection: $stageState) {
                    PrivacyBlurStageArt(layout: stored.layout(of: currentApp), regions: stored.regions(of: currentApp),
                                        hovering: stageState == 1,
                                        hover: PrivacyBlurHover(rawValue: hover) ?? .defaultValue,
                                        frost: PrivacyBlurRevealing.frostOpacity(strength: strength))
                }
                Group {
                    apps
                    regions
                    blur
                    revealing
                    timing
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    // MARK: State

    private var stored: PrivacyBlurPreferences {
        _ = revision
        return PrivacyBlurPreferences(defaults: .standard)
    }

    /// The app whose regions the page shows: the chosen one, or the first.
    private var currentApp: String {
        let apps = stored.apps
        if let chosenApp, apps.contains(chosenApp) { return chosenApp }
        return apps.first ?? PrivacyBlurPreset.whatsApp.id
    }

    private var chips: [ZenithChip] {
        let preferences = stored
        var chips: [ZenithChip] = []
        if preferences.apps.count == 1, let app = preferences.apps.first {
            chips.append(ZenithChip(PrivacyBlurApps.name(of: app, customNames: preferences.customNames)))
        } else {
            chips.append(ZenithChip(text.appCount(preferences.apps.count)))
        }
        if preferences.when == .whileSharing {
            chips.append(ZenithChip(service.sharing.isSharing ? text.sharingNow : text.whenSharing,
                                    dot: service.sharing.isSharing ? ZenithStatus.warning : nil))
        }
        if enabled, service.override == false { chips.append(ZenithChip(text.paused)) }
        if let saved = GlobalShortcut(storageValue: shortcut) { chips.append(ZenithChip(saved.displayString)) }
        return chips
    }

    private func write(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        revision += 1
    }

    // MARK: Apps

    private var apps: some View {
        let preferences = stored
        return ZenithSection(text.appsSection, anchor: .zenithPrivacyBlurApps, footer: text.appsFooter) {
            if preferences.apps.isEmpty {
                ZenithRow(text.noApps) { EmptyView() }
            }
            ForEach(preferences.apps, id: \.self) { app in
                appRow(app, preferences: preferences)
            }
            ZenithRow(text.addApp) {
                Menu {
                    ForEach(PrivacyBlurApps.addablePresets(to: preferences.apps)) { preset in
                        Button(preset.name) { add(preset.id, name: nil) }
                    }
                    if !PrivacyBlurApps.addablePresets(to: preferences.apps).isEmpty { Divider() }
                    Button(text.addOtherApp) { chooseOtherApp() }
                } label: {
                    Label(text.add, systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private func appRow(_ app: String, preferences: PrivacyBlurPreferences) -> some View {
        let installed = PrivacyBlurAppLookup.url(of: app)
        let running = PrivacyBlurAppLookup.isRunning(app)
        return ZenithRow(PrivacyBlurApps.name(of: app, customNames: preferences.customNames),
                         info: PrivacyBlurPreset.named(app)?.bundleIDs.joined(separator: ", ") ?? app,
                         essential: installed == nil ? text.notInstalled : nil) {
            HStack(spacing: 10) {
                if let installed {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: installed.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(running ? text.running : text.notRunning)
                        .font(ZenithType.caption)
                        .foregroundStyle(.secondary)
                }
                Button(text.remove) { remove(app) }
                    .controlSize(.small)
            }
        }
    }

    private func add(_ app: String, name: String?) {
        var list = stored.apps
        guard !list.contains(app) else { return }
        list.append(app)
        if let name {
            var names = stored.customNames
            names[app] = name
            write(names, forKey: PrivacyBlurDefaults.customNames)
        }
        write(list, forKey: PrivacyBlurDefaults.apps)
        chosenApp = app
    }

    private func remove(_ app: String) {
        write(stored.apps.filter { $0 != app }, forKey: PrivacyBlurDefaults.apps)
        if chosenApp == app { chosenApp = nil }
    }

    /// Any other app, picked from Applications.
    private func chooseOtherApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = text.addApp
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path)
        add(PrivacyBlurPreset.matching(bundleID: bundleID)?.id ?? bundleID,
            name: (name as NSString).deletingPathExtension)
    }

    // MARK: Regions

    private var regions: some View {
        let preferences = stored
        let app = currentApp
        let chosen = preferences.regions(of: app)
        return VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.regionsSection)
            if preferences.apps.count > 1 {
                Picker(text.regionsFor, selection: Binding(get: { app }, set: { chosenApp = $0 })) {
                    ForEach(preferences.apps, id: \.self) { item in
                        Text(PrivacyBlurApps.name(of: item, customNames: preferences.customNames)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 4)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 12) {
                ForEach(PrivacyBlurRegion.allCases) { region in
                    PrivacyBlurRegionTile(label: text.title(region), detail: text.detail(region),
                                          selected: chosen.contains(region)) {
                        setRegions(PrivacyBlurRegion.toggled(chosen, region), for: app)
                    } art: {
                        PrivacyBlurRegionDiagram(region: region, layout: preferences.layout(of: app))
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(text.regionsSection)
            ZenithSection(anchor: .zenithPrivacyBlurRegions,
                          footer: chosen.contains(.names) && !chosen.contains(.chatList) ? text.namesNote : text.regionsCaption) {
                ZenithRow(text.listEdge, value: listEdgeBinding(app), in: PrivacyBlurLayout.listEdgeRange,
                          info: text.listEdgeCaption,
                          valueLabel: "\(Int(preferences.layout(of: app).listEdge)) pt",
                          minimumSymbol: "sidebar.left", maximumSymbol: "rectangle.leadinghalf.filled")
                ZenithRow(text.defaultListEdge, button: text.resetListEdge) {
                    var edges = stored.listEdges
                    edges[app] = nil
                    write(edges, forKey: PrivacyBlurDefaults.listWidths)
                }
            }
            .disabled(chosen.contains(.everything))
        }
    }

    private func setRegions(_ regions: Set<PrivacyBlurRegion>, for app: String) {
        var all = UserDefaults.standard.dictionary(forKey: PrivacyBlurDefaults.regions) as? [String: [String]] ?? [:]
        all[app] = PrivacyBlurRegion.stored(regions)
        write(all, forKey: PrivacyBlurDefaults.regions)
    }

    private func listEdgeBinding(_ app: String) -> Binding<Double> {
        Binding(get: { Double(stored.layout(of: app).listEdge) }, set: { value in
            var edges = stored.listEdges
            edges[app] = value.rounded()
            write(edges, forKey: PrivacyBlurDefaults.listWidths)
        })
    }

    // MARK: Blur

    private var blur: some View {
        ZenithSection(text.blurSection) {
            ZenithRow(text.strength, value: $strength, in: 0...1, info: text.strengthCaption,
                      valueLabel: "\(Int((strength * 100).rounded()))%",
                      minimumSymbol: "drop", maximumSymbol: "drop.fill")
        }
    }

    // MARK: Revealing

    private var revealing: some View {
        ZenithSection(text.revealSection, anchor: .zenithPrivacyBlurReveal) {
            ZenithRow(text.hover, selection: $hover, info: text.hoverCaption) {
                ForEach(PrivacyBlurHover.allCases) { Text(text.title($0)).tag($0.rawValue) }
            }
            ZenithShortcutSettingRow(text.shortcut, info: text.shortcutCaption,
                                     storageKey: PrivacyBlurDefaults.shortcut,
                                     fallback: PrivacyBlurService.defaultShortcut,
                                     refused: service.shortcutRefused,
                                     conflict: service.conflict(for:),
                                     sync: { service.syncShortcut(force: true) })
            ZenithMoreOptions(id: "privacyBlur", anchors: [.zenithPrivacyBlurKeys]) {
                ZenithRow(text.holdKey, selection: $holdKey, info: text.holdKeyCaption) {
                    ForEach(PrivacyBlurHoldKey.allCases) { Text(text.title($0)).tag($0.rawValue) }
                }
                .zenithSectionAnchor(.zenithPrivacyBlurKeys, cornerRadius: 10, inset: 4)
                ZenithRow(text.revealWhileTyping, isOn: $revealWhileTyping, info: text.revealWhileTypingCaption)
            }
        }
    }

    // MARK: When

    private var timing: some View {
        let whileSharing = when == PrivacyBlurWhen.whileSharing.rawValue
        return VStack(alignment: .leading, spacing: 8) {
            ZenithSection(text.whenSection, anchor: .zenithPrivacyBlurSharing) {
                ZenithRow(text.when, selection: $when, info: text.whenCaption) {
                    ForEach(PrivacyBlurWhen.allCases) { Text(text.title($0)).tag($0.rawValue) }
                }
                if whileSharing {
                    ZenithRow(text.presentation, isOn: $presentation, info: text.presentationCaption)
                    ZenithRow(service.sharing.isSharing ? text.sharingNow : text.notSharing) {
                        Circle()
                            .fill(service.sharing.isSharing ? ZenithStatus.warning : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }
            }
            ZenithFootnote(text.detectionNote)
        }
    }
}

// MARK: - Apps on this Mac

enum PrivacyBlurAppLookup {
    /// Where the app is installed: the first of a preset's bundle ids found.
    static func url(of app: String) -> URL? {
        let ids = PrivacyBlurPreset.named(app)?.bundleIDs ?? [app]
        return ids.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }

    static func isRunning(_ app: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { PrivacyBlurApps.matches(bundleID: $0.bundleIdentifier, app: app) }
    }
}

// MARK: - Region tiles

/// A region's tile: the kit's picture tile, chosen as part of a set.
struct PrivacyBlurRegionTile<Art: View>: View {
    let label: String
    let detail: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let art: () -> Art
    @Environment(\.zenithTint) private var tint
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    ZenithStageGradient(tint: tint, dark: colorScheme == .dark)
                    art()
                }
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .clipShape(shape)
                .overlay(shape.strokeBorder(selected ? Color.accentColor
                                                : Color.primary.opacity(contrast == .increased ? 0.3 : (hovering ? 0.2 : 0.08)),
                                            lineWidth: selected ? 2.5 : 1))
                Text(label)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(detail)
        .accessibilityLabel(label)
        .accessibilityHint(detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A tiny chat window with the region's parts frosted in the accent colour.
struct PrivacyBlurRegionDiagram: View {
    let region: PrivacyBlurRegion
    let layout: PrivacyBlurLayout
    @Environment(\.colorScheme) private var colorScheme

    private static let nominal = CGSize(width: 1100, height: 700)

    var body: some View {
        let size = CGSize(width: 88, height: 56)
        let scale = size.width / Self.nominal.width
        let pieces = PrivacyBlurRegions.pieces([region], layout: layout, size: Self.nominal)
        ZStack(alignment: .topLeading) {
            PrivacyBlurMiniWindow(layout: layout, scale: scale, detail: false)
            ForEach(pieces.indices, id: \.self) { index in
                let rect = pieces[index].rect
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: rect.width * scale, height: rect.height * scale)
                    .offset(x: rect.minX * scale, y: rect.minY * scale)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Stage art

/// A chat window drawn from the app's layout: a rail, the chat list's rows,
/// the conversation's header, bubbles and the composer. `scale` maps the
/// layout's points onto the drawing.
struct PrivacyBlurMiniWindow: View {
    let layout: PrivacyBlurLayout
    let scale: CGFloat
    var detail = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let rail = layout.rail * scale, edge = min(layout.listEdge * scale, w * 0.75)
            let header = layout.header * scale, top = layout.listTop * scale
            let ink = dark ? Color.white : Color.black
            ZStack(alignment: .topLeading) {
                Rectangle().fill(dark ? Color(white: 0.13) : Color(white: 0.98))
                Rectangle().fill(dark ? Color(white: 0.1) : Color(white: 0.93)).frame(width: rail)
                Rectangle().fill(dark ? Color(white: 0.16) : Color.white).frame(width: edge - rail).offset(x: rail)
                Rectangle().fill(ink.opacity(0.08)).frame(width: 0.5).offset(x: edge)
                // The conversation's header: a photo and a name.
                Circle().fill(Color(red: 0.5, green: 0.7, blue: 0.95)).frame(width: header * 0.55, height: header * 0.55)
                    .offset(x: edge + header * 0.3, y: header * 0.22)
                Capsule().fill(ink.opacity(0.35)).frame(width: (w - edge) * 0.22, height: max(2, header * 0.14))
                    .offset(x: edge + header * 1.0, y: header * 0.42)
                Rectangle().fill(ink.opacity(0.08)).frame(width: w - edge, height: 0.5).offset(x: edge, y: header)
                // The chat list's rows.
                let rowHeight = max(6, 72 * scale)
                ForEach(0..<12, id: \.self) { row in
                    let y = top + CGFloat(row) * rowHeight
                    if y + rowHeight * 0.8 < h {
                        Circle().fill(Self.avatar(row)).frame(width: rowHeight * 0.66, height: rowHeight * 0.66)
                            .offset(x: rail + rowHeight * 0.18, y: y + rowHeight * 0.17)
                        Capsule().fill(ink.opacity(0.4)).frame(width: (edge - rail) * 0.42, height: max(1.5, rowHeight * 0.13))
                            .offset(x: rail + rowHeight * 1.0, y: y + rowHeight * 0.25)
                        Capsule().fill(ink.opacity(0.18)).frame(width: (edge - rail) * 0.6, height: max(1.5, rowHeight * 0.11))
                            .offset(x: rail + rowHeight * 1.0, y: y + rowHeight * 0.55)
                    }
                }
                // The bubbles.
                ForEach(0..<6, id: \.self) { index in
                    let mine = index % 3 == 1
                    let width = (w - edge) * [0.42, 0.34, 0.5, 0.28, 0.44, 0.36][index]
                    let y = header + (h - header) * (0.08 + CGFloat(index) * 0.13)
                    if detail || index < 4 {
                        RoundedRectangle(cornerRadius: max(2, 8 * scale * 2), style: .continuous)
                            .fill(mine ? Color(red: 0.3, green: 0.78, blue: 0.5).opacity(dark ? 0.75 : 0.85)
                                       : (dark ? Color(white: 0.24) : Color(white: 0.9)))
                            .frame(width: width, height: max(4, (h - header) * 0.085))
                            .offset(x: mine ? w - width - 12 * scale * 2 : edge + 12 * scale * 2, y: y)
                    }
                }
            }
        }
    }

    private static func avatar(_ row: Int) -> Color {
        [Color(red: 0.95, green: 0.6, blue: 0.45), Color(red: 0.5, green: 0.7, blue: 0.95),
         Color(red: 0.65, green: 0.55, blue: 0.95), Color(red: 0.45, green: 0.8, blue: 0.6)][row % 4]
    }
}

/// The stage: the chat window with its chosen parts frosted; on Hover the
/// pointer rests on the conversation and clears the part (or the circle)
/// under it.
struct PrivacyBlurStageArt: View {
    let layout: PrivacyBlurLayout
    let regions: Set<PrivacyBlurRegion>
    let hovering: Bool
    let hover: PrivacyBlurHover
    let frost: Double
    @Environment(\.colorScheme) private var colorScheme

    private static let nominal = CGSize(width: 1100, height: 560)
    private static let drawn = CGSize(width: 440, height: 224)
    /// Where the stage's pointer rests, in the nominal window.
    private static let pointer = CGPoint(x: 780, y: 300)

    var body: some View {
        let scale = Self.drawn.width / Self.nominal.width
        let pieces = PrivacyBlurRegions.pieces(regions, layout: layout, size: Self.nominal)
        let reveal = hovering
            ? PrivacyBlurRevealing.reveal(hover: hover == .off ? .region : hover, holding: false, typing: false,
                                          isFocusedWindow: false, pointer: Self.pointer, windowSize: Self.nominal,
                                          pieces: pieces)
            : .none
        let dark = colorScheme == .dark
        ZStack(alignment: .topLeading) {
            PrivacyBlurMiniWindow(layout: layout, scale: scale)
            ForEach(pieces.indices, id: \.self) { index in
                let rect = pieces[index].rect
                if reveal != .piece(index) {
                    frostPane(dark: dark)
                        .frame(width: rect.width * scale, height: rect.height * scale)
                        .mask(holeMask(rect: rect, reveal: reveal, scale: scale))
                        .offset(x: rect.minX * scale, y: rect.minY * scale)
                }
            }
            if hovering {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.black)
                    .shadow(color: .white, radius: 1)
                    .offset(x: Self.pointer.x * scale - 3, y: Self.pointer.y * scale - 3)
            }
        }
        .frame(width: Self.drawn.width, height: Self.drawn.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hovering ? "A chat window, clear under the pointer" : "A chat window under frosted glass")
    }

    /// Frost drawn, not blurred: a pale wash in the window's colour with
    /// soft blobs where the text was.
    private func frostPane(dark: Bool) -> some View {
        ZStack {
            Rectangle().fill(dark ? Color(white: 0.22).opacity(0.75 + frost * 0.25) : Color(white: 0.94).opacity(0.75 + frost * 0.25))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill((dark ? Color.white : Color.black).opacity(0.06 * (1 - frost) + 0.02))
                        .frame(width: [70, 50, 90, 40, 66, 54][i], height: 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            LinearGradient(colors: [.white.opacity(dark ? 0.08 : 0.35), .clear], startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private func holeMask(rect: CGRect, reveal: PrivacyBlurReveal, scale: CGFloat) -> some View {
        if case .circle(let point) = reveal {
            let radius = PrivacyBlurRevealing.circleRadius * scale
            Rectangle()
                .overlay(
                    Circle()
                        .fill(RadialGradient(colors: [.black, .black, .clear], center: .center,
                                             startRadius: 0, endRadius: radius))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: (point.x - rect.minX) * scale, y: (point.y - rect.minY) * scale)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        } else {
            Rectangle()
        }
    }
}
