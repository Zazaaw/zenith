// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the quick tools that shared the Quick Tools page, each on a
// page of its own: Quick Launcher, Quick Toggles, Quit Apps, Cleaning Mode,
// Wallpaper and Scratchpad. Each opens with its hero and the tool's picture
// from the old shared card, then its rows, which write the same defaults and
// sync the same services as before.

/// One quick tool's picture on the stage, from the Quick Tools card.
struct QuickToolPreviewCard: View {
    let feature: QuickToolsPreviewFeature

    var body: some View {
        ZenithSettingsPreviewCard(id: "quickTools.\(feature)", caption: caption, highlight: feature.name) {
            QuickToolsPreviewPicture(group: feature.group, shown: feature, available: [feature]) { _ in
                SettingsRouter.shared.request(feature.feature.settingsDestination)
            }
        }
    }

    private var caption: String {
        let text = ZenithPreviewsToolsStrings.shared
        switch feature {
        case .wallpaper: return text.quickWallpaperCaption
        case .cleaningMode: return text.quickCleaningCaption
        default:
            switch feature.group {
            case .panel: return text.quickPanelCaption
            case .windows: return text.quickWindowsCaption
            case .apps: return text.quickAppsCaption
            }
        }
    }
}

/// The page frame every quick tool shares: the scroll, the width, the gaps.
private struct QuickToolPage<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18, content: content)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(22)
        }
    }
}

private extension View {
    /// The hero as the page's search destination.
    func quickToolAnchor(_ anchor: SettingsSectionAnchor) -> some View {
        zenithSectionAnchor(anchor, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
    }
}

// MARK: - Quick Launcher

struct QuickLauncherSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var launcher = QuickLauncherService.shared
    @AppStorage(DefaultsKey.quickLauncherShortcutEnabled) private var shortcutEnabled = true

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    var body: some View {
        QuickToolPage {
            ZenithHero(title: l10n.s.launcherName, subtitle: text.quickLauncherSubtitle,
                       chips: [ZenithChip(l10n.s.quickToolShortcutToggle,
                                          dot: shortcutEnabled ? ZenithStatus.success : nil)],
                       animation: .quickLauncher)
                .quickToolAnchor(.quickLauncher)
            QuickToolPreviewCard(feature: .launcher)
            ZenithSection(footer: l10n.s.launcherEditHint) {
                ZenithRow(l10n.s.launcherOpenNow, info: l10n.s.launcherCaption, button: text.open) {
                    QuickLauncherService.shared.show()
                }
                ZenithRow(l10n.s.quickToolShortcutToggle, isOn: $shortcutEnabled,
                          warning: shortcutEnabled && launcher.shortcutRegistrationFailed ? l10n.s.shortcutUnavailable : nil)
                    .onChange(of: shortcutEnabled) { _, _ in QuickLauncherService.shared.syncWithPreferences() }
                ShortcutPreferenceRow(role: .quickLauncher, isEnabled: shortcutEnabled) {
                    QuickLauncherService.shared.syncWithPreferences()
                }
                .padding(.vertical, 9)
            }
        }
    }
}

// MARK: - Quick Toggles

struct QuickTogglesSettingsPage: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var brightness = BrightnessService.shared

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }
    private var toggles: QuickToggleFeatureStrings { FeatureStrings.quickToggles(l10n.language) }

    var body: some View {
        QuickToolPage {
            ZenithHero(title: toggles.pageTitle, subtitle: text.quickTogglesSubtitle, animation: .quickToggles)
                .quickToolAnchor(.quickToggles)
            QuickToolPreviewCard(feature: .toggles)
            ZenithSection(footer: toggles.panelCaption) {
                ZenithRow(colorScheme == .dark ? toggles.darkModeToLight : toggles.darkModeToDark,
                          button: text.tryIt) {
                    QuickTogglesService.shared.toggleDarkMode()
                }
                if brightness.keyboardLightEnabled != nil {
                    ZenithRow(FeatureStrings.brightness(l10n.language).keyboardLight, isOn: Binding(
                        get: { brightness.keyboardLightEnabled ?? false },
                        set: { brightness.setKeyboardLightEnabled($0) }))
                    ZenithRow(FeatureStrings.brightness(l10n.language).keyboardLight, value: Binding(
                        get: { Double(brightness.keyboardLightLevel ?? 0) },
                        set: { brightness.setKeyboardLightLevel(Float($0)) }
                    ), in: 0...1, valueLabel: "\(Int(((brightness.keyboardLightLevel ?? 0) * 100).rounded()))%",
                       minimumSymbol: "light.min", maximumSymbol: "light.max",
                       onEditingChanged: brightness.keyboardLightDragChanged)
                }
                DiskExclusionsList().padding(.vertical, 8)
            }
        }
        .onAppear { brightness.refreshKeyboardLight() }
    }
}

// MARK: - Quit Apps

struct QuitAppsSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var quickToggles = QuickTogglesService.shared
    @AppStorage(DefaultsKey.quitAppsShortcutEnabled) private var quitAllShortcutEnabled = false
    @AppStorage(DefaultsKey.quitAppsExceptFrontShortcutEnabled) private var quitOthersShortcutEnabled = false

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }
    private var toggles: QuickToggleFeatureStrings { FeatureStrings.quickToggles(l10n.language) }

    var body: some View {
        QuickToolPage {
            ZenithHero(title: l10n.s.quitAppsName, subtitle: text.quitAppsSubtitle, animation: .quitApps)
                .quickToolAnchor(.quitApps)
            QuickToolPreviewCard(feature: .quitApps)
            ZenithSection(footer: l10n.s.quitAppsCaption) {
                ZenithRow(toggles.quitAllTitle, button: text.open) { QuickTogglesService.shared.showQuitApps() }
                QuitAllExceptionsList().padding(.vertical, 8)
            }
            ZenithSection(text.shortcutsSection) {
                ZenithRow("\(l10n.s.quickToolShortcutToggle): \(toggles.quitAllTitle)", isOn: $quitAllShortcutEnabled,
                          warning: quitAllShortcutEnabled && quickToggles.shortcutRegistrationFailed
                              ? l10n.s.shortcutUnavailable : nil)
                    .onChange(of: quitAllShortcutEnabled) { _, _ in QuickTogglesService.shared.syncWithPreferences() }
                ShortcutPreferenceRow(role: .quitAll, isEnabled: quitAllShortcutEnabled) {
                    QuickTogglesService.shared.syncWithPreferences()
                }
                .padding(.vertical, 9)
                ZenithRow("\(l10n.s.quickToolShortcutToggle): \(toggles.quitOthersTitle)", isOn: $quitOthersShortcutEnabled,
                          warning: quitOthersShortcutEnabled && quickToggles.othersShortcutRegistrationFailed
                              ? l10n.s.shortcutUnavailable : nil)
                    .onChange(of: quitOthersShortcutEnabled) { _, _ in QuickTogglesService.shared.syncWithPreferences() }
                ShortcutPreferenceRow(role: .quitAllExceptFront, isEnabled: quitOthersShortcutEnabled) {
                    QuickTogglesService.shared.syncWithPreferences()
                }
                .padding(.vertical, 9)
            }
        }
    }
}

// MARK: - Cleaning Mode

struct CleaningModeSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.cleaningModeKeepScreenVisible) private var keepScreenVisible = false

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    var body: some View {
        QuickToolPage {
            ZenithHero(title: l10n.s.cleaningMenuItem, subtitle: text.cleaningModeSubtitle, animation: .cleaningMode)
                .quickToolAnchor(.cleaningMode)
            QuickToolPreviewCard(feature: .cleaningMode)
            ZenithSection {
                ZenithRow(l10n.s.cleaningStartNow, info: l10n.s.cleaningPanelCaption, button: l10n.s.cleaningStartNow) {
                    CleaningModeManager.shared.activate()
                }
                ZenithRow(l10n.s.cleaningKeepScreenVisibleToggle, isOn: $keepScreenVisible,
                          info: l10n.s.cleaningKeepScreenVisibleCaption)
            }
        }
    }
}

// MARK: - Wallpaper

struct WallpaperSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var applyAllDisplays = WallpaperService.shared.applyAllDisplays

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }
    private var wallpaper: WallpaperFeatureStrings { FeatureStrings.wallpaper(l10n.language) }

    var body: some View {
        QuickToolPage {
            ZenithHero(title: wallpaper.pageTitle, subtitle: text.wallpaperSubtitle, animation: .wallpaper)
                .quickToolAnchor(.wallpaper)
            QuickToolPreviewCard(feature: .wallpaper)
            ZenithSection {
                ZenithRow(wallpaper.applyAllDisplays, isOn: Binding(get: { applyAllDisplays }, set: { value in
                    applyAllDisplays = value
                    WallpaperService.shared.applyAllDisplays = value
                }))
                ZenithRow(wallpaper.openSystemSettings, button: text.open) {
                    WallpaperService.shared.openSystemWallpaperSettings()
                }
            }
        }
        .onAppear { applyAllDisplays = WallpaperService.shared.applyAllDisplays }
    }
}

// MARK: - Scratchpad

struct ScratchpadSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var scratchpad = ScratchpadService.shared
    @AppStorage(DefaultsKey.scratchpadShortcutEnabled) private var shortcutEnabled = false
    @AppStorage(DefaultsKey.scratchpadRetention) private var retention = ScratchpadRetention.never.rawValue
    @AppStorage(DefaultsKey.scratchpadCloseOnClickOutside) private var closeOnClickOutside = true
    @AppStorage(DefaultsKey.scratchpadBackgroundOpacity) private var backgroundOpacity = 0.0
    @AppStorage(DefaultsKey.scratchpadTextSize) private var textSize = ScratchpadSupport.defaultTextSize

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }
    private var pad: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }

    var body: some View {
        QuickToolPage {
            ZenithHero(title: pad.pageTitle, subtitle: text.scratchpadSubtitle,
                       chips: [ZenithChip(retentionTitle)], animation: .scratchpad)
                .quickToolAnchor(.scratchpad)
            QuickToolPreviewCard(feature: .scratchpad)
            ZenithSection {
                ZenithRow(pad.openButton, info: pad.panelCaption, button: text.open) { ScratchpadService.shared.show() }
                ZenithRow(pad.retentionTitle, selection: $retention, info: pad.retentionCaption) {
                    Text(pad.retentionNever).tag(ScratchpadRetention.never.rawValue)
                    Text(pad.retentionDay).tag(ScratchpadRetention.day.rawValue)
                    Text(pad.retentionWeek).tag(ScratchpadRetention.week.rawValue)
                    Text(pad.retentionMonth).tag(ScratchpadRetention.month.rawValue)
                }
                ZenithRow(pad.closeOnClickOutside, isOn: $closeOnClickOutside)
                    .onChange(of: closeOnClickOutside) { _, _ in ScratchpadService.shared.outsideClickPreferenceDidChange() }
                ZenithMoreOptions(id: "scratchpad") {
                    ZenithRow(pad.textSize, value: Binding(
                        get: { ScratchpadSupport.sanitizedTextSize(textSize) },
                        set: { textSize = ScratchpadSupport.sanitizedTextSize($0) }
                    ), in: ScratchpadSupport.textSizeRange, step: 1,
                       valueLabel: "\(Int(ScratchpadSupport.sanitizedTextSize(textSize)))")
                    ZenithRow(pad.backgroundOpacity, value: Binding(
                        get: { ScratchpadSupport.sanitizedBackgroundOpacity(backgroundOpacity) },
                        set: { backgroundOpacity = ScratchpadSupport.sanitizedBackgroundOpacity($0) }
                    ), in: ScratchpadSupport.backgroundOpacityRange, step: 0.05,
                       info: "\(pad.backgroundTranslucent) → \(pad.backgroundOpaque)",
                       valueLabel: "\(Int((ScratchpadSupport.sanitizedBackgroundOpacity(backgroundOpacity) * 100).rounded()))%")
                }
            }
            ZenithSection(text.shortcutsSection) {
                ZenithRow(l10n.s.quickToolShortcutToggle, isOn: $shortcutEnabled,
                          warning: shortcutEnabled && scratchpad.shortcutRegistrationFailed ? l10n.s.shortcutUnavailable : nil)
                    .onChange(of: shortcutEnabled) { _, _ in ScratchpadService.shared.syncWithPreferences() }
                ShortcutPreferenceRow(role: .scratchpad, isEnabled: shortcutEnabled) {
                    ScratchpadService.shared.syncWithPreferences()
                }
                .padding(.vertical, 9)
            }
        }
    }

    private var retentionTitle: String {
        switch ScratchpadRetention(rawValue: retention) ?? .never {
        case .never: return pad.retentionNever
        case .day: return pad.retentionDay
        case .week: return pad.retentionWeek
        case .month: return pad.retentionMonth
        }
    }
}
