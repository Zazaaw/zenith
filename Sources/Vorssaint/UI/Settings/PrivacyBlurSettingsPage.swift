// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Zenith fork: Settings → Privacy Blur, a feature page on the Settings kit
/// (docs/SETTINGS-KIT.md): the hero with the master switch (which asks for
/// Accessibility the first time it turns on), a chat window blurred item by
/// item on the stage, the apps and how each one blurs (each item or the
/// whole window), what to blur (the browser extension's options), how
/// strong, how to peek, and when it blurs. Everything writes
/// `PrivacyBlurDefaults`; `PrivacyBlurService` follows.
struct PrivacyBlurSettingsPage: View {
    @ObservedObject private var service = PrivacyBlurService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(PrivacyBlurDefaults.enabled) private var enabled = false
    @AppStorage(PrivacyBlurDefaults.strength) private var strength = PrivacyBlurDefaults.defaultStrength
    @AppStorage(PrivacyBlurDefaults.messages) private var blurMessages = true
    @AppStorage(PrivacyBlurDefaults.previews) private var blurPreviews = true
    @AppStorage(PrivacyBlurDefaults.media) private var blurMedia = true
    @AppStorage(PrivacyBlurDefaults.avatars) private var blurAvatars = true
    @AppStorage(PrivacyBlurDefaults.names) private var blurNames = true
    @AppStorage(PrivacyBlurDefaults.input) private var blurInput = true
    @AppStorage(PrivacyBlurDefaults.noDelay) private var noDelay = false
    @AppStorage(PrivacyBlurDefaults.holdKey) private var holdKey = PrivacyBlurHoldKey.none.rawValue
    @AppStorage(PrivacyBlurDefaults.revealWhileTyping) private var revealWhileTyping = false
    @AppStorage(PrivacyBlurDefaults.when) private var when = PrivacyBlurWhen.always.rawValue
    @AppStorage(PrivacyBlurDefaults.presentationMode) private var presentation = false
    @AppStorage(PrivacyBlurDefaults.shortcut) private var shortcut = PrivacyBlurService.defaultShortcut.storageValue
    @State private var stageState = 0
    /// Bumped after each write of a preference that is not a plain value.
    @State private var revision = 0

    private let text = ZenithStrings.privacyBlur(.enUS)

    var body: some View {
        let preferences = stored
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips(preferences),
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
                    PrivacyBlurStageArt(options: preferences.options,
                                        mode: preferences.apps.first.map(preferences.mode(of:)) ?? .items,
                                        hovering: stageState == 1,
                                        frost: PrivacyBlurRevealing.frostOpacity(strength: strength))
                }
                Group {
                    apps(preferences)
                    items(preferences)
                    blur
                    revealing(preferences)
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
        // The plain values are read through their @AppStorage so a switch redraws the page at once.
        _ = (blurMessages, blurPreviews, blurMedia, blurAvatars, blurNames, blurInput, noDelay)
        return PrivacyBlurPreferences(defaults: .standard)
    }

    private func chips(_ preferences: PrivacyBlurPreferences) -> [ZenithChip] {
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

    private func apps(_ preferences: PrivacyBlurPreferences) -> some View {
        ZenithSection(text.appsSection, anchor: .zenithPrivacyBlurApps, footer: text.appsFooter) {
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
        let generic = PrivacyBlurApps.support(of: app) == .generic
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
                Picker(text.blurMode, selection: modeBinding(app)) {
                    ForEach(PrivacyBlurMode.allCases) { Text(text.title($0, generic: generic)).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .help(text.modeCaption)
                Button(text.remove) { remove(app) }
                    .controlSize(.small)
            }
        }
    }

    private func modeBinding(_ app: String) -> Binding<PrivacyBlurMode> {
        Binding(get: { stored.mode(of: app) }, set: { mode in
            var modes = UserDefaults.standard.dictionary(forKey: PrivacyBlurDefaults.modes) as? [String: String] ?? [:]
            modes[app] = mode.rawValue
            write(modes, forKey: PrivacyBlurDefaults.modes)
        })
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
    }

    private func remove(_ app: String) {
        write(stored.apps.filter { $0 != app }, forKey: PrivacyBlurDefaults.apps)
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

    // MARK: What to blur

    private func items(_ preferences: PrivacyBlurPreferences) -> some View {
        let itemApps = preferences.apps.filter { preferences.mode(of: $0) == .items }
        let footer: String
        if itemApps.isEmpty {
            footer = text.windowOnlyNote
        } else if itemApps.contains(where: { PrivacyBlurApps.support(of: $0) == .generic }) {
            footer = text.genericNote
        } else {
            footer = text.itemsFooter
        }
        return VStack(alignment: .leading, spacing: 8) {
            ZenithSection(text.itemsSection, anchor: .zenithPrivacyBlurRegions, footer: footer) {
                ZenithRow(text.messages, isOn: $blurMessages, info: text.messagesCaption)
                ZenithRow(text.previews, isOn: $blurPreviews, info: text.previewsCaption)
                ZenithRow(text.media, isOn: $blurMedia, info: text.mediaCaption)
                ZenithRow(text.avatars, isOn: $blurAvatars, info: text.avatarsCaption)
                ZenithRow(text.names, isOn: $blurNames, info: text.namesCaption)
                ZenithRow(text.input, isOn: $blurInput, info: text.inputCaption)
            }
            .disabled(itemApps.isEmpty)
            if !itemApps.isEmpty, enabled, !permissions.accessibility {
                ZenithFootnote(text.itemsNeedAccessibility)
            }
        }
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

    private func revealing(_ preferences: PrivacyBlurPreferences) -> some View {
        let hoverReveal = Binding(get: { stored.options.hoverReveal },
                                  set: { write($0, forKey: PrivacyBlurDefaults.hoverReveal) })
        return ZenithSection(text.revealSection, anchor: .zenithPrivacyBlurReveal) {
            ZenithRow(text.hoverReveal, isOn: hoverReveal, info: text.hoverRevealCaption)
            ZenithRow(text.noDelay, isOn: $noDelay, info: text.noDelayCaption)
                .disabled(!preferences.options.hoverReveal)
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

// MARK: - Stage art

/// The stage: the sample WhatsApp window (PrivacyBlurSample) drawn small,
/// with the items the options blur frosted one by one by the same rules the
/// overlay follows. On Hover the pointer rests on a bubble and clears it
/// alone (or a circle, for a window blurred whole).
struct PrivacyBlurStageArt: View {
    let options: PrivacyBlurItemOptions
    let mode: PrivacyBlurMode
    let hovering: Bool
    let frost: Double
    @Environment(\.colorScheme) private var colorScheme

    private static let scene: PrivacyBlurScene = {
        let sample = PrivacyBlurSample.whatsApp()
        return PrivacyBlurItems.classify(.tuned, root: sample.root, window: sample.window)
    }()
    private static let window = PrivacyBlurSample.windowSize
    private static let scale: CGFloat = 0.25
    /// Where the stage's pointer rests: on a bubble, in the window's space.
    private static let pointer = CGPoint(x: 770, y: 292)

    var body: some View {
        let scale = Self.scale
        let dark = colorScheme == .dark
        let shown = PrivacyBlurItems.shown(scene: Self.scene, mode: mode, options: options, windowSize: Self.window)
        let reveal = hovering
            ? PrivacyBlurRevealing.reveal(hoverReveal: true, holding: false, typing: false, isFocusedWindow: false,
                                          pointer: Self.pointer, windowSize: Self.window, items: shown)
            : .none
        ZStack(alignment: .topLeading) {
            PrivacyBlurMiniWindow(scene: Self.scene, scale: scale)
            ForEach(shown.indices, id: \.self) { index in
                let item = shown[index]
                if reveal != .item(index) {
                    frostShape(item, dark: dark, scale: scale, reveal: reveal)
                }
            }
            if hovering {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.black)
                    .shadow(color: .white, radius: 1)
                    .offset(x: Self.pointer.x * scale - 3, y: Self.pointer.y * scale - 3)
            }
        }
        .frame(width: Self.window.width * scale, height: Self.window.height * scale, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hovering ? "A chat window, one message clear under the pointer"
                                     : "A chat window with each message, name and photo blurred")
    }

    /// Frost drawn, not blurred: a pale wash in the window's colour over the
    /// item, rounded like it.
    @ViewBuilder
    private func frostShape(_ item: PrivacyBlurItem, dark: Bool, scale: CGFloat, reveal: PrivacyBlurReveal) -> some View {
        let shape = RoundedRectangle(cornerRadius: item.cornerRadius * scale, style: .continuous)
        let base = dark ? Color(white: 0.3) : Color(white: 0.84)
        let pane = ZStack {
            shape.fill(base.opacity(0.7 + frost * 0.3))
            shape.fill(LinearGradient(colors: [.white.opacity(dark ? 0.1 : 0.4), .clear], startPoint: .top, endPoint: .bottom))
        }
        .frame(width: item.rect.width * scale, height: item.rect.height * scale)
        if case .circle(let point) = reveal {
            let radius = PrivacyBlurRevealing.circleRadius * scale
            pane
                .mask(Rectangle().overlay(
                    Circle()
                        .fill(RadialGradient(colors: [.black, .black, .clear], center: .center, startRadius: 0, endRadius: radius))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: (point.x - item.rect.minX) * scale, y: (point.y - item.rect.minY) * scale)
                        .blendMode(.destinationOut)
                ).compositingGroup())
                .offset(x: item.rect.minX * scale, y: item.rect.minY * scale)
        } else {
            pane.offset(x: item.rect.minX * scale, y: item.rect.minY * scale)
        }
    }
}

/// A chat window drawn from a scene: the window and its two
/// columns' backgrounds, each chat row's photo, name and preview, the open
/// chat's header, the bubbles (yours on the right) and the typing field.
struct PrivacyBlurMiniWindow: View {
    let scene: PrivacyBlurScene
    let scale: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let ink = dark ? Color.white : Color.black
        let list = scene.areas.first { $0.id == PrivacyBlurWhatsAppRules.listArea }?.rect ?? .zero
        let conversation = scene.areas.first { $0.id == PrivacyBlurWhatsAppRules.conversationArea }?.rect ?? .zero
        ZStack(alignment: .topLeading) {
            Rectangle().fill(dark ? Color(white: 0.11) : Color(white: 0.95))
            Rectangle().fill(dark ? Color(white: 0.15) : Color.white)
                .frame(width: list.width * scale).offset(x: list.minX * scale)
            Rectangle().fill(dark ? Color(white: 0.13) : Color(red: 0.96, green: 0.94, blue: 0.9))
                .frame(width: conversation.width * scale).offset(x: conversation.minX * scale)
            ForEach(scene.items.indices, id: \.self) { index in
                content(scene.items[index], conversation: conversation, ink: ink, dark: dark)
            }
        }
    }

    @ViewBuilder
    private func content(_ item: PrivacyBlurItem, conversation: CGRect, ink: Color, dark: Bool) -> some View {
        let rect = CGRect(x: item.rect.minX * scale, y: item.rect.minY * scale,
                          width: item.rect.width * scale, height: item.rect.height * scale)
        switch item.kind {
        case .avatar:
            Circle().fill(Self.avatar(Int(item.rect.minY / 69)))
                .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
        case .name, .preview:
            Capsule().fill(ink.opacity(item.kind == .name ? 0.45 : 0.22))
                .frame(width: rect.width * (item.kind == .name ? 0.55 : 0.8), height: max(2, rect.height * 0.4))
                .offset(x: rect.minX, y: rect.midY - max(2, rect.height * 0.4) / 2)
        case .message:
            let mine = item.rect.maxX > conversation.maxX - 24
            RoundedRectangle(cornerRadius: item.cornerRadius * scale, style: .continuous)
                .fill(mine ? Color(red: 0.3, green: 0.75, blue: 0.5).opacity(dark ? 0.6 : 0.55)
                           : (dark ? Color(white: 0.24) : Color.white))
                .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
        case .media:
            RoundedRectangle(cornerRadius: item.cornerRadius * scale, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.65, blue: 0.4), Color(red: 0.45, green: 0.55, blue: 0.95)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
        case .input:
            RoundedRectangle(cornerRadius: item.cornerRadius * scale, style: .continuous)
                .fill(dark ? Color(white: 0.22) : Color.white)
                .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
        case .window:
            EmptyView()
        }
    }

    private static func avatar(_ row: Int) -> Color {
        [Color(red: 0.95, green: 0.6, blue: 0.45), Color(red: 0.5, green: 0.7, blue: 0.95),
         Color(red: 0.65, green: 0.55, blue: 0.95), Color(red: 0.45, green: 0.8, blue: 0.6)][abs(row) % 4]
    }
}
