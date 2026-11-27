// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Dock page: Dock Preview, Dock clicks and the window previews Dock
/// Preview shares with the switcher.
struct DockSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var dockPreview = DockPreviewService.shared
    @AppStorage(DefaultsKey.dockPreviewEnabled) private var dockPreviewEnabled = false
    @AppStorage(DefaultsKey.dockPreviewCurrentSpaceOnly) private var dockPreviewCurrentSpaceOnly = false
    @AppStorage(DefaultsKey.dockPreviewBackgroundOpacity) private var dockPreviewBackgroundOpacity = 1.0
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.dockPreviewOpenDelay) private var dockPreviewOpenDelay = DockPreviewSupport.defaultOpenDelayMilliseconds
    @AppStorage(DefaultsKey.dockPreviewQuitAppOnClose) private var dockPreviewQuitAppOnClose = false
    @AppStorage(DefaultsKey.dockPreviewOrderByCreation) private var dockPreviewOrderByCreation = false
    @AppStorage(DefaultsKey.dockPreviewKeepDockVisible) private var dockPreviewKeepDockVisible = false
    @AppStorage(DefaultsKey.dockClickMinimize) private var dockClickMinimize = false
    @AppStorage(DefaultsKey.dockClickHide) private var dockClickHide = false
    @AppStorage(DefaultsKey.dockClickCycleWindows) private var dockClickCycleWindows = false

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }
    private var dockPreviewEngaged: Bool { dockPreviewEnabled && AppFeature.dockPreview.isAvailable }

    // Zenith fork: a kit page for the Dock's two features: Dock Preview and
    // what a click on an icon does. Spaces in order has a page of its own.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.dockTitle, subtitle: text.dockSubtitle, chips: chips, animation: .dock)
                if needsAccessibility, !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                if dockPreviewEngaged, !permissions.screenRecording {
                    InputWindowsPermissionSection(kind: .screenRecording)
                }
                ZenithScreenPreviewCard(group: .dock)
                if AppFeature.dockPreview.isAvailable {
                    dockPreviewSection
                    WindowPreviewsCard(sizeKey: DefaultsKey.previewSize,
                                       excludedAppsKey: DefaultsKey.windowPreviewExcludedApps)
                }
                // Clicking a Dock icon is its own installable feature in the
                // hub, so it gets its own section here.
                if AppFeature.dockClick.isAvailable {
                    dockClickSection
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var chips: [ZenithChip] {
        let clicks = [dockClickMinimize, dockClickHide, dockClickCycleWindows].filter { $0 }.count
        let all: [(AppFeature, Bool)] = [(.dockPreview, dockPreviewEnabled), (.dockClick, clicks > 0)]
            .filter { $0.0.isAvailable }
        return [ZenithChip(text.onCount(all.filter(\.1).count, of: all.count))]
    }

    private var dockPreviewSection: some View {
        ZenithSection(l10n.s.dockPreviewName, anchor: .dock) {
            ZenithRow(l10n.s.dockPreviewEnable, isOn: $dockPreviewEnabled, info: l10n.s.dockPreviewEnableCaption,
                      essential: dockPreviewStatus)
                .onChange(of: dockPreviewEnabled) { _, _ in DockPreviewService.shared.syncWithPreferences() }
            if dockPreviewEnabled {
                ZenithRow(l10n.s.switcherCurrentSpaceOnly, isOn: $dockPreviewCurrentSpaceOnly,
                          info: l10n.s.dockPreviewCurrentSpaceOnlyCaption)
                    .onChange(of: dockPreviewCurrentSpaceOnly) { _, _ in DockPreviewService.shared.syncWithPreferences() }
                ZenithRow(l10n.s.dockPreviewOpenDelay, value: dockPreviewOpenDelayBinding,
                          in: DockPreviewSupport.openDelayMillisecondsRange, step: 50,
                          info: l10n.s.dockPreviewOpenDelayCaption, format: { "\($0) ms" })
                ZenithRow(l10n.s.dockPreviewQuitAppOnClose, isOn: $dockPreviewQuitAppOnClose,
                          info: l10n.s.dockPreviewQuitAppOnCloseCaption)
                ZenithMoreOptions(id: "dock.preview") {
                    ZenithRow(l10n.s.dockPreviewBackgroundOpacity, value: dockPreviewBackgroundOpacityBinding,
                              in: DockPreviewSupport.backgroundOpacityRange, step: 0.05,
                              info: dockPreviewBackgroundIsGlass ? l10n.s.dockPreviewBackgroundOpacityGlassCaption
                                  : l10n.s.dockPreviewBackgroundOpacityCaption,
                              valueLabel: "\(dockPreviewBackgroundOpacityPercent)%")
                        .disabled(dockPreviewBackgroundIsGlass)
                    ZenithRow(l10n.s.dockPreviewKeepDockVisible, info: l10n.s.dockPreviewKeepDockVisibleCaption) {
                        ZenithRowSwitch(title: l10n.s.dockPreviewKeepDockVisible, isOn: $dockPreviewKeepDockVisible)
                            .disabled(!DockAutohideHold.isSupported && !dockPreviewKeepDockVisible)
                    }
                    .onChange(of: dockPreviewKeepDockVisible) { _, _ in dockPreview.syncWithPreferences() }
                    ZenithRow(l10n.s.dockPreviewOrderByCreation, isOn: $dockPreviewOrderByCreation,
                              info: l10n.s.dockPreviewOrderByCreationCaption)
                }
            }
        }
    }

    private var dockClickSection: some View {
        ZenithSection(FeatureStrings.hub(l10n.language).titleDockClick, anchor: .dockClick) {
            ZenithRow(l10n.s.dockClickMinimize, isOn: $dockClickMinimize, info: l10n.s.dockClickMinimizeCaption)
                .onChange(of: dockClickMinimize) { _, enabled in
                    if enabled { dockClickHide = false }
                    DockClickService.shared.syncWithPreferences()
                }
            ZenithRow(l10n.s.dockClickHide, isOn: $dockClickHide, info: l10n.s.dockClickHideCaption)
                .onChange(of: dockClickHide) { _, enabled in
                    if enabled { dockClickMinimize = false }
                    DockClickService.shared.syncWithPreferences()
                }
            ZenithRow(l10n.s.dockClickCycleWindows, isOn: $dockClickCycleWindows,
                      info: l10n.s.dockClickCycleWindowsCaption)
                .onChange(of: dockClickCycleWindows) { _, _ in DockClickService.shared.syncWithPreferences() }
        }
    }

    // MARK: - State

    /// Dock Preview and every Dock click action work through Accessibility;
    /// the catalog knows which of them are on right now.
    private var needsAccessibility: Bool {
        FeatureVisibilitySupport.isPermissionNeeded(
            on: .dock, activeFeatures: AppFeature.activeFeatures(using: .accessibility))
    }

    /// Why Dock Preview is on but cannot show, the line under its switch.
    private var dockPreviewStatus: String? {
        guard dockPreviewEnabled else { return nil }
        if !permissions.accessibility { return "\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)" }
        if !permissions.screenRecording { return "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)" }
        switch dockPreview.blockedReason {
        case .dockUnavailable: return l10n.s.dockPreviewDockUnavailable
        default: return nil
        }
    }


    /// The slider only fades the classic material. Liquid Glass takes its
    /// transparency from System Settings, so the slider has nothing to change.
    private var dockPreviewBackgroundIsGlass: Bool {
        HUDBackdrop.drawsLiquidGlass(enabled: liquidGlassEnabled, reduceTransparency: reduceTransparency)
    }

    private var dockPreviewBackgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { DockPreviewSupport.sanitizedBackgroundOpacity(dockPreviewBackgroundOpacity) },
            set: { dockPreviewBackgroundOpacity = DockPreviewSupport.sanitizedBackgroundOpacity($0) }
        )
    }

    private var dockPreviewBackgroundOpacityPercent: Int {
        Int((DockPreviewSupport.sanitizedBackgroundOpacity(dockPreviewBackgroundOpacity) * 100).rounded())
    }

    private var dockPreviewOpenDelayBinding: Binding<Int> {
        Binding(
            get: { DockPreviewSupport.sanitizedOpenDelay(milliseconds: dockPreviewOpenDelay) },
            set: { dockPreviewOpenDelay = DockPreviewSupport.sanitizedOpenDelay(milliseconds: $0) }
        )
    }
}

/// Zenith fork: Spaces in a fixed order, a page of its own: the hero holds
/// the one switch, the picture shows what it keeps.
struct SpacesSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.spacesOrderEnabled) private var enabled = false

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.spacesTitle, subtitle: text.spacesSubtitle,
                           isOn: Binding(get: { enabled }, set: { value in
                               enabled = value
                               SpacesOrderHold.shared.syncWithPreferences()
                           }),
                           switchLabel: l10n.s.spacesOrderName, switchHint: l10n.s.spacesOrderCaption,
                           animation: .spaces)
                    .zenithSectionAnchor(.spacesOrder, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                ZenithScreenPreviewCard(group: .spaces)
                ZenithFootnote(l10n.s.spacesOrderCaption)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }
}
