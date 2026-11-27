// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Switcher page: the app switcher chosen from three drawn layouts, its
/// shortcuts and options as rows, then its window previews.
struct SwitcherSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var secureInput = SecureInputMonitor.shared
    @State private var switcherCoversSecureInput = AppSwitcher.shared.coversSecureInput
    @AppStorage(DefaultsKey.switcherEnabled) private var switcherEnabled = true
    @AppStorage(DefaultsKey.switcherShortcut) private var switcherShortcutStorage = GlobalShortcut.switcherDefault.storageValue
    @AppStorage(DefaultsKey.switcherAllWindowsShortcutEnabled) private var allWindowsShortcutEnabled = false
    @AppStorage(DefaultsKey.switcherTakeOverSystemShortcuts) private var switcherTakeOverSystemShortcuts = false
    @AppStorage(DefaultsKey.switcherIconRowMode) private var switcherIconRowMode = false
    @AppStorage(DefaultsKey.switcherSimpleMode) private var switcherSimpleMode = false
    @AppStorage(DefaultsKey.switcherMergeTabs) private var switcherMergeTabs = false
    @AppStorage(DefaultsKey.switcherWindowlessApps) private var switcherWindowlessApps = SwitcherWindowlessApps.fallback.rawValue
    @AppStorage(DefaultsKey.switcherMinimizedPlacement) private var switcherMinimizedPlacement = WindowSwitchMinimizedPlacement.normal.rawValue
    @AppStorage(DefaultsKey.switcherTreatHiddenAppsLikeMinimized) private var switcherTreatHiddenAppsLikeMinimized = true
    @AppStorage(DefaultsKey.switcherShowFullscreenWindows) private var switcherShowFullscreenWindows = true
    @AppStorage(DefaultsKey.switcherScreenPlacement) private var switcherScreenPlacement = SwitcherScreenPlacement.fallback.rawValue
    @AppStorage(DefaultsKey.switcherCurrentDisplayOnly) private var switcherCurrentDisplayOnly = false
    @AppStorage(DefaultsKey.switcherCurrentSpaceOnly) private var switcherCurrentSpaceOnly = false
    @AppStorage(DefaultsKey.switcherSearchPinEnabled) private var switcherSearchPinEnabled = false
    @AppStorage(DefaultsKey.switcherShowShortcutHints) private var switcherShowShortcutHints = true
    @AppStorage(DefaultsKey.switcherAppearanceDelay) private var switcherAppearanceDelay = SwitcherSupport.defaultAppearanceDelayMilliseconds
    @AppStorage(DefaultsKey.switcherInstantSelection) private var switcherInstantSelection = false
    @AppStorage(DefaultsKey.switcherIgnoreHoverSelection) private var switcherIgnoreHoverSelection = false
    @AppStorage(DefaultsKey.switcherMaxColumns) private var switcherMaxColumns = 0
    private var pages: SettingsPageStrings { FeatureStrings.settingsPages(l10n.language) }
    private var switcherEngaged: Bool { switcherEnabled && AppFeature.switcher.isAvailable }
    /// Only then does the macOS switcher on ⌘Tab need explaining: without the
    /// take-over, or without the Accessibility grant the tap needs, it answers
    /// anyway and keeps answering after secure input ends.
    private var switcherReplacesSystemShortcuts: Bool {
        switcherEngaged && switcherTakeOverSystemShortcuts && permissions.accessibility
    }
    private var switcherWindowlessAppsSelection: Binding<String> {
        Binding(
            get: {
                SwitcherWindowlessApps.mode(
                    storedValue: switcherWindowlessApps,
                    takeOverSystemShortcuts: switcherTakeOverSystemShortcuts).rawValue
            },
            set: { value in
                if !switcherTakeOverSystemShortcuts { switcherWindowlessApps = value }
            }
        )
    }

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    // Zenith fork: a kit feature page: the hero with the switcher's switch,
    // the layout in use on the stage, the layouts as pictures, its shortcuts,
    // its everyday options (the rest under More options), the per-app rules
    // and the window previews.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: l10n.s.tabSwitcher, subtitle: pages.switcherDescription, chips: chips,
                           isOn: enabledBinding, switchLabel: l10n.s.switcherEnable,
                           switchHint: l10n.s.switcherEnableCaption, animation: .switcher)
                    .zenithSectionAnchor(.switcher, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                if switcherEngaged {
                    if !permissions.accessibility {
                        InputWindowsPermissionSection()
                    }
                    if !permissions.screenRecording, SwitcherSupport.capturesPreviews(simpleMode: switcherSimpleMode) {
                        InputWindowsPermissionSection(kind: .screenRecording)
                    }
                }
                ZenithScreenPreviewCard(group: .switcher, current: layout == .simple ? .switcherSimple
                                        : layout == .icons ? .switcherIcons : .switcherWindows)
                layoutPicker
                shortcuts.disabled(!switcherEnabled)
                options.disabled(!switcherEnabled)
                // Per-app rules can be prepared while the switcher is off, as
                // before the redesign.
                ZenithSection {
                    SwitcherAppRulesList().padding(.vertical, 8)
                }
                WindowPreviewsCard(sizeKey: DefaultsKey.switcherPreviewSize,
                                   excludedAppsKey: DefaultsKey.switcherPreviewExcludedApps)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .observesSecureInput(isActive: switcherReplacesSystemShortcuts)
        .onReceive(AppSwitcher.shared.$coversSecureInput) { switcherCoversSecureInput = $0 }
    }

    private var chips: [ZenithChip] {
        let shortcut = (GlobalShortcut(storageValue: switcherShortcutStorage) ?? .switcherDefault).displayString
        return [ZenithChip(layoutTitle(layout)), ZenithChip(shortcut)]
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { switcherEnabled }, set: { value in
            switcherEnabled = value
            AppSwitcher.shared.syncWithPreferences()
        })
    }

    // MARK: - App switcher

    private var layout: SwitcherLayout {
        if switcherSimpleMode { return .simple }
        return switcherIconRowMode ? .icons : .windows
    }

    private func layoutTitle(_ layout: SwitcherLayout) -> String {
        switch layout {
        case .windows: return pages.switcherLayoutWindows
        case .icons: return pages.switcherLayoutIcons
        case .simple: return pages.switcherLayoutSimple
        }
    }

    private func layoutCaption(_ layout: SwitcherLayout) -> String {
        switch layout {
        case .windows: return pages.switcherLayoutWindowsCaption
        case .icons: return l10n.s.switcherIconRowModeCaption
        case .simple: return l10n.s.switcherSimpleModeCaption
        }
    }

    private func choose(_ layout: SwitcherLayout) {
        switch layout {
        case .windows:
            switcherSimpleMode = false
            switcherIconRowMode = false
        case .icons:
            switcherSimpleMode = false
            switcherIconRowMode = true
        case .simple:
            switcherSimpleMode = true
        }
        AppSwitcher.shared.syncWithPreferences()
    }

    private var layoutPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.layoutSection)
            ZenithVisualPicker(text.layoutSection, selection: Binding(get: { layout }, set: { choose($0) }),
                               options: [SwitcherLayout.windows, .icons, .simple].map {
                                   ZenithPickerOption($0, layoutTitle($0), detail: layoutCaption($0))
                               }, minimumTileWidth: 150, tileHeight: 74) { layout, _ in
                SwitcherLayoutSketch(layout: layout)
            }
        }
        .disabled(!switcherEnabled)
    }

    private var shortcuts: some View {
        ZenithSection(text.shortcutsSection,
                      footer: String(format: l10n.s.switcherUsageHintFormat,
                                     (GlobalShortcut(storageValue: switcherShortcutStorage) ?? .switcherDefault).displayString)) {
            ShortcutPreferenceRow(role: .switcher, isEnabled: switcherEnabled,
                                  label: l10n.s.switcherShortcutHintApps) {
                AppSwitcher.shared.syncWithPreferences()
            }
            .padding(.vertical, 9)
            ShortcutPreferenceRow(role: .switcherWindow, isEnabled: switcherEnabled,
                                  label: l10n.s.switcherShortcutHintWindows) {
                AppSwitcher.shared.syncWithPreferences()
            }
            .padding(.vertical, 9)
            .help(l10n.s.switcherWindowShortcutCaption)
            ZenithRow(FeatureStrings.switcherShortcuts(l10n.language).allWindows, isOn: $allWindowsShortcutEnabled,
                      info: FeatureStrings.switcherShortcuts(l10n.language).allWindowsCaption)
                .onChange(of: allWindowsShortcutEnabled) { _, _ in AppSwitcher.shared.syncWithPreferences() }
            if allWindowsShortcutEnabled {
                ShortcutPreferenceRow(role: .switcherAllWindows, isEnabled: switcherEnabled) {
                    AppSwitcher.shared.syncWithPreferences()
                }
                .padding(.vertical, 9)
            }
            ZenithRow(l10n.s.switcherTakeOverSystemShortcuts, isOn: $switcherTakeOverSystemShortcuts,
                      info: l10n.s.switcherTakeOverSystemShortcutsCaption)
                .onChange(of: switcherTakeOverSystemShortcuts) { _, _ in AppSwitcher.shared.syncWithPreferences() }
            // Secure input hides every key from the switcher's tap. When
            // its Carbon stand-ins cannot register, ⌘Tab goes back to macOS
            // until it ends, and without a word here the macOS switcher
            // looks like the replacement stopped working.
            if switcherReplacesSystemShortcuts, secureInput.holder != .off, !switcherCoversSecureInput {
                SecureInputRow(blocking: .switcher).padding(.vertical, 8)
            }
        }
    }

    private var options: some View {
        ZenithSection(l10n.s.keepAwakeOptions) {
            ZenithRow(l10n.s.switcherAppearanceDelay, value: switcherAppearanceDelayBinding,
                      in: Double(SwitcherSupport.appearanceDelayMillisecondsRange.lowerBound)
                          ... Double(SwitcherSupport.appearanceDelayMillisecondsRange.upperBound),
                      step: 25, info: l10n.s.switcherAppearanceDelayCaption,
                      valueLabel: "\(sanitizedSwitcherAppearanceDelay) ms")
            ZenithRow(l10n.s.switcherInstantSelection, isOn: $switcherInstantSelection,
                      info: l10n.s.switcherInstantSelectionCaption)
            ZenithRow(l10n.s.switcherMinimizedPlacementLabel, selection: $switcherMinimizedPlacement) {
                Text(l10n.s.switcherMinimizedPlacementNormal).tag(WindowSwitchMinimizedPlacement.normal.rawValue)
                Text(l10n.s.switcherMinimizedPlacementEnd).tag(WindowSwitchMinimizedPlacement.end.rawValue)
                Text(l10n.s.switcherMinimizedPlacementHidden).tag(WindowSwitchMinimizedPlacement.hidden.rawValue)
            }
            .onChange(of: switcherMinimizedPlacement) { _, _ in AppSwitcher.shared.syncWithPreferences() }
            if switcherMinimizedPlacement != WindowSwitchMinimizedPlacement.normal.rawValue {
                ZenithRow(l10n.s.switcherTreatHiddenAppsLikeMinimized, isOn: $switcherTreatHiddenAppsLikeMinimized)
                    .onChange(of: switcherTreatHiddenAppsLikeMinimized) { _, _ in AppSwitcher.shared.syncWithPreferences() }
            }
            ZenithRow(l10n.s.switcherCurrentDisplayOnly, isOn: $switcherCurrentDisplayOnly,
                      info: l10n.s.switcherCurrentDisplayOnlyCaption)
            ZenithRow(l10n.s.switcherCurrentSpaceOnly, isOn: $switcherCurrentSpaceOnly,
                      info: l10n.s.switcherCurrentSpaceOnlyCaption)
            ZenithMoreOptions(id: "switcher") {
                ZenithRow(l10n.s.switcherWindowlessApps, selection: switcherWindowlessAppsSelection,
                          info: l10n.s.switcherWindowlessAppsCaption,
                          essential: switcherTakeOverSystemShortcuts
                              ? String(format: l10n.s.switcherWindowlessAppsLockedFormat, l10n.s.switcherTakeOverSystemShortcuts)
                              : nil) {
                    Text(l10n.s.switcherWindowlessAppsOff).tag(SwitcherWindowlessApps.off.rawValue)
                    Text(l10n.s.switcherWindowlessAppsFinder).tag(SwitcherWindowlessApps.finder.rawValue)
                    Text(l10n.s.switcherWindowlessAppsAll).tag(SwitcherWindowlessApps.all.rawValue)
                }
                .disabled(switcherTakeOverSystemShortcuts)
                ZenithRow(l10n.s.switcherScreenPlacementLabel, selection: $switcherScreenPlacement,
                          info: l10n.s.switcherScreenPlacementCaption) {
                    Text(l10n.s.switcherScreenPlacementPointer).tag(SwitcherScreenPlacement.pointer.rawValue)
                    Text(l10n.s.switcherScreenPlacementMenuBar).tag(SwitcherScreenPlacement.menuBar.rawValue)
                    Text(l10n.s.switcherScreenPlacementActiveWindow).tag(SwitcherScreenPlacement.activeWindow.rawValue)
                }
                ZenithRow(l10n.s.switcherMaxColumns, value: switcherMaxColumnsBinding,
                          in: Double(SwitcherSupport.maxColumnsRange.lowerBound - 1)
                              ... Double(SwitcherSupport.maxColumnsRange.upperBound),
                          step: 1, info: l10n.s.switcherMaxColumnsCaption, valueLabel: switcherMaxColumnsLabel)
                ZenithRow(l10n.s.switcherIgnoreHoverSelection, isOn: $switcherIgnoreHoverSelection,
                          info: l10n.s.switcherIgnoreHoverSelectionCaption)
                ZenithRow(l10n.s.switcherSearchPin, isOn: $switcherSearchPinEnabled, info: l10n.s.switcherSearchPinCaption)
                if switcherSimpleMode || switcherIconRowMode {
                    ZenithRow(l10n.s.switcherShowShortcutHints, isOn: $switcherShowShortcutHints,
                              info: l10n.s.switcherShowShortcutHintsCaption)
                }
                ZenithRow(l10n.s.switcherMergeTabs, isOn: $switcherMergeTabs, info: l10n.s.switcherMergeTabsCaption)
                ZenithRow(l10n.s.switcherShowFullscreenWindows, isOn: $switcherShowFullscreenWindows)
                    .onChange(of: switcherShowFullscreenWindows) { _, _ in AppSwitcher.shared.syncWithPreferences() }
            }
        }
    }

    // MARK: - State

    private var sanitizedSwitcherAppearanceDelay: Int {
        SwitcherSupport.sanitizedAppearanceDelay(milliseconds: switcherAppearanceDelay)
    }

    private var sanitizedSwitcherMaxColumns: Int? {
        SwitcherSupport.sanitizedMaxColumns(switcherMaxColumns)
    }

    private var switcherMaxColumnsLabel: String {
        sanitizedSwitcherMaxColumns.map(String.init) ?? l10n.s.switcherMaxColumnsAuto
    }

    /// The slider's leftmost step, one below the range, stands for Auto.
    private var switcherMaxColumnsBinding: Binding<Double> {
        let auto = SwitcherSupport.maxColumnsRange.lowerBound - 1
        return Binding(
            get: { Double(sanitizedSwitcherMaxColumns ?? auto) },
            set: {
                let value = Int($0.rounded())
                switcherMaxColumns = value <= auto ? 0 : SwitcherSupport.sanitizedMaxColumns(value) ?? 0
            }
        )
    }

    private var switcherAppearanceDelayBinding: Binding<Double> {
        Binding(
            get: { Double(sanitizedSwitcherAppearanceDelay) },
            set: {
                switcherAppearanceDelay = SwitcherSupport.sanitizedAppearanceDelay(
                    milliseconds: Int($0.rounded()))
            }
        )
    }
}

/// The window previews card on the Switcher and Dock pages: each page has its
/// own preview size and paused apps, while the minimal look is shared.
struct WindowPreviewsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @AppStorage private var previewSize: String
    private let excludedAppsKey: String

    init(sizeKey: String, excludedAppsKey: String) {
        _previewSize = AppStorage(wrappedValue: "normal", sizeKey)
        self.excludedAppsKey = excludedAppsKey
    }

    // Zenith fork: the sizes as pictures, then the look and the paused apps
    // as kit rows.
    var body: some View {
        let sizes: [(String, String, CGFloat)] = [
            ("small", l10n.s.previewSizeSmall, 0.5), ("normal", l10n.s.previewSizeNormal, 0.66),
            ("large", l10n.s.previewSizeLarge, 0.83), ("xlarge", l10n.s.previewSizeXLarge, 1),
        ]
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(FeatureStrings.windowPreviewExclusions(l10n.language).sectionTitle)
            ZenithVisualPicker(l10n.s.previewSizeLabel, selection: Binding(get: { previewSize }, set: { value in
                previewSize = value
                AppSwitcher.shared.syncWithPreferences()
            }), options: sizes.map { ZenithPickerOption($0.0, $0.1) }, tileHeight: 58) { value, _ in
                WindowPreviewSizeArt(scale: sizes.first { $0.0 == value }?.2 ?? 0.66)
            }
            ZenithSection {
                ZenithRow(l10n.s.minimalWindowPreviews, isOn: $minimalPreviews, info: l10n.s.minimalWindowPreviewsCaption)
                WindowPreviewExclusionsList(key: excludedAppsKey).padding(.vertical, 8)
            }
        }
    }
}

/// A window preview drawn at the size it stands for, on a size tile.
private struct WindowPreviewSizeArt: View {
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.9))
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.25))
                    .frame(height: 6 * scale + 2)
            }
            .frame(width: 60 * scale, height: 40 * scale)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

/// One of the three switcher layouts, drawn as the switcher would look:
/// window previews, one large icon per app under its previews, or a plain
/// list of icons and titles. Zenith fork: the art of a layout tile.
private struct SwitcherLayoutSketch: View {
    let layout: SwitcherLayout

    var body: some View {
        sketch
            .padding(10)
            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sketch: some View {
        switch layout {
        case .windows:
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    window(selected: index == 0)
                        .frame(width: 34, height: 26)
                }
            }
        case .icons:
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    VStack(spacing: 4) {
                        window(selected: index == 0)
                            .frame(width: 26, height: 18)
                            .opacity(index == 0 ? 1 : 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == 0 ? Color.accentColor : Color.white.opacity(0.35))
                            .frame(width: 16, height: 16)
                    }
                }
            }
        case .simple:
            // The real one: the selected app's title in a strip, then one
            // icon per app in a row underneath.
            VStack(spacing: 7) {
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 44, height: 4)
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == 0 ? Color.accentColor : Color.white.opacity(0.35))
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
    }

    private func window(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.white.opacity(selected ? 0.9 : 0.4))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 4)
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
    }
}

/// The three ways the switcher can look; `simple` wins over `icons` when
/// both keys are set, as the switcher itself decides.
private enum SwitcherLayout: Hashable {
    case windows, icons, simple
}
