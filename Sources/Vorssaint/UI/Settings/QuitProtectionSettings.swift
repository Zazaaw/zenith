// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct QuitProtectionSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = QuitProtectionService.shared

    @AppStorage(DefaultsKey.quitProtectionQuitEnabled) private var quitEnabled = false
    @AppStorage(DefaultsKey.quitProtectionQuitMode) private var quitMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitHoldDurationMs) private var quitHoldDuration = QuitProtectionSupport.defaultHoldDurationMilliseconds
    @AppStorage(DefaultsKey.quitProtectionQuitDoubleIntervalMs) private var quitDoubleInterval = QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
    @AppStorage(DefaultsKey.quitProtectionQuitExtraModifier) private var quitExtraModifier = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitScope) private var quitScope = QuitProtectionScope.all.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitShowFeedback) private var quitShowFeedback = true

    @AppStorage(DefaultsKey.quitProtectionCloseEnabled) private var closeEnabled = false
    @AppStorage(DefaultsKey.quitProtectionCloseMode) private var closeMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseHoldDurationMs) private var closeHoldDuration = QuitProtectionSupport.defaultHoldDurationMilliseconds
    @AppStorage(DefaultsKey.quitProtectionCloseDoubleIntervalMs) private var closeDoubleInterval = QuitProtectionSupport.defaultDoublePressIntervalMilliseconds
    @AppStorage(DefaultsKey.quitProtectionCloseExtraModifier) private var closeExtraModifier = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseScope) private var closeScope = QuitProtectionScope.all.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseShowFeedback) private var closeShowFeedback = true

    @State private var pickerShortcut: QuitProtectionShortcut?

    private var strings: QuitProtectionStrings {
        FeatureStrings.quitProtection(l10n.language)
    }

    private var pageText: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    // Zenith fork: a kit page: the hero (two shortcuts, so no single master
    // switch), the preview, then one section per shortcut.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: strings.name, subtitle: pageText.quitProtectionSubtitle, chips: chips,
                           animation: .quitProtection)
                if (quitEnabled || closeEnabled) && !permissions.accessibility {
                    InputWindowsPermissionSection(title: strings.accessibilityCaption)
                }
                ZenithQuitProtectionPreviewCard()
                ZenithFootnote(strings.intro)
                shortcutSection(shortcut: .quit,
                                enabled: $quitEnabled,
                                mode: $quitMode,
                                holdDuration: $quitHoldDuration,
                                doubleInterval: $quitDoubleInterval,
                                extraModifier: $quitExtraModifier,
                                scope: $quitScope,
                                showFeedback: $quitShowFeedback)
                shortcutSection(shortcut: .close,
                                enabled: $closeEnabled,
                                mode: $closeMode,
                                holdDuration: $closeHoldDuration,
                                doubleInterval: $closeDoubleInterval,
                                extraModifier: $closeExtraModifier,
                                scope: $closeScope,
                                showFeedback: $closeShowFeedback)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .zenithPreviewJumps()
        .sheet(item: $pickerShortcut) { shortcut in
            AppPickerView(onCancel: { pickerShortcut = nil }, onSelect: { url in
                pickerShortcut = nil
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
                service.addException(bundleID, for: shortcut)
            }, loadApps: {
                let excluded = Set(service.exceptions(for: shortcut))
                return InstalledApps.installedBundleApplications(excluding: excluded)
            })
        }
        .onAppear { service.syncWithPreferences() }
    }

    private var chips: [ZenithChip] {
        [ZenithChip(QuitProtectionShortcut.quit.symbol, dot: quitEnabled ? ZenithStatus.success : nil),
         ZenithChip(QuitProtectionShortcut.close.symbol, dot: closeEnabled ? ZenithStatus.success : nil)]
    }

    private func shortcutSection(shortcut: QuitProtectionShortcut,
                                 enabled: Binding<Bool>,
                                 mode: Binding<String>,
                                 holdDuration: Binding<Double>,
                                 doubleInterval: Binding<Double>,
                                 extraModifier: Binding<String>,
                                 scope: Binding<String>,
                                 showFeedback: Binding<Bool>) -> some View {
        let currentMode = QuitProtectionSupport.modeFor(mode.wrappedValue)
        let currentScope = QuitProtectionSupport.scopeFor(scope.wrappedValue)
        let currentModifier = QuitProtectionSupport.extraModifierFor(extraModifier.wrappedValue)
        let sync = { service.syncWithPreferences() }

        return ZenithSection(shortcut.symbol) {
            ZenithRow(strings.enabled, isOn: enabled, info: strings.enabledCaption)
                .onChange(of: enabled.wrappedValue) { _, _ in sync() }
            ZenithRow(strings.mode, selection: mode) {
                Text(strings.hold).tag(QuitProtectionMode.hold.rawValue)
                Text(strings.doublePress).tag(QuitProtectionMode.doublePress.rawValue)
                Text(strings.extraModifier).tag(QuitProtectionMode.extraModifier.rawValue)
            }
            .onChange(of: mode.wrappedValue) { _, _ in sync() }
            if currentMode == .hold {
                ZenithRow(strings.holdDuration, value: holdDuration, in: QuitProtectionSupport.holdDurationRange,
                          step: 50, valueLabel: "\(Int(holdDuration.wrappedValue.rounded())) ms")
                    .onChange(of: holdDuration.wrappedValue) { _, _ in sync() }
            }
            if currentMode == .doublePress {
                ZenithRow(strings.doublePressInterval, value: doubleInterval,
                          in: QuitProtectionSupport.doublePressIntervalRange,
                          step: 50, valueLabel: "\(Int(doubleInterval.wrappedValue.rounded())) ms")
                    .onChange(of: doubleInterval.wrappedValue) { _, _ in sync() }
            }
            if currentMode == .extraModifier {
                ZenithRow(strings.modifier, info: "\(modifierSymbol(currentModifier))\(shortcut.symbol)") {
                    Picker(strings.modifier, selection: extraModifier) {
                        Text("\(strings.shiftKey) (⇧)").tag(QuitProtectionExtraModifier.shift.rawValue)
                        Text("\(strings.optionKey) (⌥)").tag(QuitProtectionExtraModifier.option.rawValue)
                        Text("\(strings.controlKey) (⌃)").tag(QuitProtectionExtraModifier.control.rawValue)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
                .onChange(of: extraModifier.wrappedValue) { _, _ in sync() }
            }
            ZenithRow(strings.appScope, selection: scope) {
                Text(strings.allApps).tag(QuitProtectionScope.all.rawValue)
                Text(strings.selectedOnly).tag(QuitProtectionScope.selectedOnly.rawValue)
                Text(strings.allExceptSelected).tag(QuitProtectionScope.allExceptSelected.rawValue)
            }
            .onChange(of: scope.wrappedValue) { _, _ in sync() }
            exceptionsSection(for: shortcut, scope: currentScope, enabled: enabled.wrappedValue)
            ZenithMoreOptions(id: shortcut == .quit ? "quitProtection.quit" : "quitProtection.close") {
                ZenithRow(strings.feedback, isOn: showFeedback)
                    .onChange(of: showFeedback.wrappedValue) { _, _ in sync() }
            }
        }
        .zenithPreviewTarget(shortcut == .quit ? "quitProtection.quit" : "quitProtection.close")
    }

    @ViewBuilder
    private func exceptionsSection(for shortcut: QuitProtectionShortcut,
                                   scope: QuitProtectionScope,
                                   enabled: Bool) -> some View {
        if scope != .all {
            VStack(alignment: .leading, spacing: 7) {
                Text(strings.exceptions)
                    .font(.subheadline.weight(.semibold))
                let values = service.exceptions(for: shortcut)
                if values.isEmpty {
                    Text(strings.noExceptions)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(values, id: \.self) { bundleID in
                        HStack(spacing: 8) {
                            Image(nsImage: InstalledApps.icon(for: bundleID))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(InstalledApps.name(for: bundleID))
                            Spacer()
                            Button {
                                service.removeException(bundleID, for: shortcut)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    pickerShortcut = shortcut
                } label: {
                    Label(strings.addApp, systemImage: "plus")
                }
                .disabled(!enabled)
            }
            .disabled(!enabled)
            .padding(.vertical, 8)
        }
    }

    private func modifierSymbol(_ modifier: QuitProtectionExtraModifier) -> String {
        switch modifier {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }
}
