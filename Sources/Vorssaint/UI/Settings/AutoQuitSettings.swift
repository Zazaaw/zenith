// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct AutoQuitSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = AutoQuitService.shared
    @AppStorage(DefaultsKey.autoQuitEnabled) private var enabled = false
    @State private var showingAppPicker = false
    @State private var showingDockAppPicker = false

    private var dockAppsText: AutoQuitDockAppsStrings {
        FeatureStrings.autoQuitDockApps(l10n.language)
    }

    private var pageText: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    // Zenith fork: a kit feature page: the hero with the master switch, the
    // preview, how it works, then the apps it never quits and the menu bar
    // apps it may.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: l10n.s.autoQuitName, subtitle: pageText.autoQuitSubtitle, chips: chips,
                           isOn: enabledBinding, switchLabel: l10n.s.autoQuitEnable,
                           switchHint: l10n.s.autoQuitEnableCaption, animation: .autoQuit)
                    .zenithPreviewTarget("autoQuit.main")
                if enabled, !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithAutoQuitPreviewCard()
                ZenithSection(l10n.s.autoQuitHowTitle, footer: l10n.s.autoQuitPredictableNote) {
                    bullet("rectangle.badge.xmark", l10n.s.autoQuitStep1)
                    bullet("bolt.fill", l10n.s.autoQuitStep2)
                    bullet("exclamationmark.triangle.fill", l10n.s.autoQuitOngoingWorkNote, secondary: true)
                }
                exceptions
                dockApps
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .zenithPreviewJumps()
        .sheet(isPresented: $showingAppPicker) {
            appPickerSheet
        }
        .sheet(isPresented: $showingDockAppPicker) {
            dockAppPickerSheet
        }
    }

    private var chips: [ZenithChip] {
        var chips = [ZenithChip(pageText.count(sortedExceptions.count, "exception", "exceptions"))]
        if enabled, service.isRunning { chips.append(ZenithChip(pageText.activeNow, dot: ZenithStatus.success)) }
        return chips
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { value in
            enabled = value
            AutoQuitService.shared.syncWithPreferences()
        })
    }

    // The exception list has one reader, the window check, and that only
    // runs while the feature does. With the switch off every edit here is a
    // no-op, so the list follows it.
    private var exceptions: some View {
        ZenithSection(l10n.s.autoQuitExceptionsTitle, footer: l10n.s.autoQuitExceptionsCaption) {
            if sortedExceptions.isEmpty {
                Text(l10n.s.autoQuitExceptionsEmpty)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(sortedExceptions, id: \.self) { bundleID in
                    appRow(bundleID) {
                        if service.isMandatoryException(bundleID) {
                            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
                        } else {
                            removeButton(l10n.s.autoQuitExceptionsTitle) { service.removeException(bundleID) }
                        }
                    }
                }
            }
            ZenithRow(l10n.s.autoQuitAddApp, button: l10n.s.autoQuitAddApp) { showingAppPicker = true }
        }
        .disabled(!enabled)
    }

    private var dockApps: some View {
        ZenithSection(dockAppsText.listTitle, footer: dockAppsText.caption) {
            ForEach(sortedDockApps, id: \.self) { bundleID in
                appRow(bundleID) {
                    removeButton(dockAppsText.removeButton) { service.removeDockApp(bundleID) }
                }
            }
            ZenithRow(dockAppsText.addButton, button: dockAppsText.addButton) { showingDockAppPicker = true }
        }
        .disabled(!enabled)
    }

    private func appRow<Trailing: View>(_ bundleID: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 9) {
            Image(nsImage: InstalledApps.icon(for: bundleID))
                .resizable().frame(width: 20, height: 20)
            Text(InstalledApps.name(for: bundleID)).font(ZenithType.body)
            Spacer()
            trailing()
        }
        .padding(.vertical, 9)
    }

    private func removeButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var sortedExceptions: [String] {
        AutoQuitSupport.visibleExceptions(service.exceptions) {
            InstalledApps.url(for: $0) != nil
        }
        .sorted {
            InstalledApps.name(for: $0).localizedCaseInsensitiveCompare(InstalledApps.name(for: $1))
                == .orderedAscending
        }
    }

    private var appPickerSheet: some View {
        let excluded = Set(service.exceptions)
        return AppPickerView {
            showingAppPicker = false
        } onSelect: { url in
            showingAppPicker = false
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
            service.addException(bundleID)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: excluded)
        }
    }

    private var sortedDockApps: [String] {
        service.dockApps.sorted {
            InstalledApps.name(for: $0).localizedCaseInsensitiveCompare(InstalledApps.name(for: $1))
                == .orderedAscending
        }
    }

    private var dockAppPickerSheet: some View {
        let excluded = Set(service.dockApps + Defaults.mandatoryAutoQuitExceptionBundleIDs)
        return AppPickerView(emptyNote: dockAppsText.emptyNote) {
            showingDockAppPicker = false
        } onSelect: { url in
            showingDockAppPicker = false
            guard AutoQuitSupport.canAllowMenuBarQuit(bundleURL: url),
                  let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
            service.addDockApp(bundleID)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: excluded).filter {
                AutoQuitSupport.canAllowMenuBarQuit(bundleURL: $0.url)
            }
        }
    }

    private func bullet(_ icon: String, _ text: String, secondary: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: 18)
            Text(text)
                .font(secondary ? ZenithType.caption : ZenithType.body)
                .foregroundStyle(secondary ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }
}
