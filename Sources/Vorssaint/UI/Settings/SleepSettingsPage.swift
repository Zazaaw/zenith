// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Sleep, built with the Settings kit. Out of the old
/// Energy page: Keep Awake (the hero's pill starts or ends a session, as the
/// old row's switch did; the default duration, what starts it by itself and
/// its options follow) and Bluetooth on sleep.
struct SleepSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.bluetoothSleepEnabled) private var bluetoothSleepEnabled = false
    @AppStorage(DefaultsKey.bluetoothSleepRestoreOnWake) private var bluetoothSleepRestoreOnWake = true
    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration = 0
    @AppStorage(DefaultsKey.batteryLimit) private var batteryLimit = 10
    @AppStorage(DefaultsKey.keepAwakeAutoStart) private var keepAwakeAutoStart = false
    @AppStorage(DefaultsKey.keepAwakeRightClickToggle) private var keepAwakeRightClickToggle = false
    @AppStorage(DefaultsKey.keepAwakeAllowDisplaySleep) private var keepAwakeAllowDisplaySleep = false
    @AppStorage(DefaultsKey.keepAwakePauseWhenLocked) private var keepAwakePauseWhenLocked = false
    @AppStorage(DefaultsKey.keepAwakeAutomationRequireAll) private var keepAwakeAutomationRequireAll = false
    @AppStorage(DefaultsKey.showCountdown) private var showCountdown = false
    @AppStorage(DefaultsKey.keepAwakeIconTint) private var keepAwakeIconTint = KeepAwakeIconTint.orange.rawValue
    @AppStorage(DefaultsKey.keepAwakeActiveIcon) private var keepAwakeActiveIcon = KeepAwakeActiveIcon.vorssaint.rawValue
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleEnabled) private var keepAwakeMouseJiggle = false
    @AppStorage(DefaultsKey.keepAwakeMouseJiggleInterval) private var keepAwakeMouseJiggleInterval = 5

    private let page = ZenithStrings.systemApps(.enUS)

    var body: some View {
        let keepAwake = AppFeature.keepAwake.isAvailable
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: page.sleepTitle, subtitle: page.sleepSubtitle, chips: chips,
                           isOn: keepAwake ? sessionBinding : nil, switchLabel: l10n.s.keepAwakeTitle,
                           animation: .sleep)
                ZenithScreenPreviewCard(group: .sleep)
                if keepAwake {
                    sessionSection
                    automationSection
                    optionsSection
                }
                if AppFeature.bluetoothSleep.isAvailable {
                    bluetoothSection
                }
            }
        }
        // Shared subviews draw plain toggles; outside a Form those would be
        // checkboxes, so the whole page asks for switches.
        .toggleStyle(ZenithSwitchStyle())
        .onAppear {
            defaultDuration = Defaults.sanitizedDefaultDuration(defaultDuration)
            batteryLimit = Defaults.sanitizedBatteryLimit(batteryLimit)
            keepAwakeIconTint = Defaults.sanitizedKeepAwakeIconTint(keepAwakeIconTint).rawValue
            keepAwakeActiveIcon = Defaults.sanitizedKeepAwakeActiveIcon(keepAwakeActiveIcon).rawValue
            keepAwakeMouseJiggleInterval = Defaults.sanitizedKeepAwakeMouseJiggleInterval(keepAwakeMouseJiggleInterval)
            if AppFeature.keepAwake.isAvailable { awake.refreshPasswordlessStatus() }
        }
    }

    private var chips: [ZenithChip] {
        var chips: [ZenithChip] = []
        if AppFeature.keepAwake.isAvailable {
            chips.append(ZenithChip(DurationPicker.title(for: defaultDuration, l10n.s)))
        }
        if AppFeature.bluetoothSleep.isAvailable, BluetoothSleepService.isSupported, bluetoothSleepEnabled {
            chips.append(ZenithChip(page.sleepBluetoothOff))
        }
        if chips.isEmpty { chips.append(ZenithChip(page.sleepNormal)) }
        return chips
    }

    // MARK: Keep awake

    /// The session the hero's pill starts: what it is doing right now, the
    /// default duration it starts with, and pausing while the Mac is locked.
    private var sessionSection: some View {
        ZenithSection(page.sleepSession, anchor: .keepAwake) {
            // A running countdown only while there is one to run down; an
            // automatic session names its condition instead, as in the panel.
            if awake.isActive, awake.sessionTrigger != .automation, let end = awake.endDate {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    ZenithRowStatus(text: "\(l10n.s.keepAwakeEndsIn) \(KeepAwakeCard.remainingText(until: end))",
                                    symbol: "sun.max.fill")
                }
            } else {
                ZenithRowStatus(text: sessionStatus, symbol: awake.isActive ? "sun.max.fill" : "moon.zzz.fill",
                                color: awake.isActive ? ZenithStatus.success : .secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.s.defaultDurationLabel).font(ZenithType.body)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], spacing: 6) {
                    ForEach(DurationPicker.choices, id: \.self) { minutes in
                        durationChip(minutes)
                    }
                }
            }
            .padding(.vertical, 10)
            ZenithRow(automationStrings.pauseWhenLockedToggle, isOn: $keepAwakePauseWhenLocked,
                      info: automationStrings.pauseWhenLockedCaption)
        }
    }

    private var sessionStatus: String {
        guard awake.isActive else { return l10n.s.keepAwakeNormalRules }
        if awake.sessionTrigger == .automation {
            return automationStrings.activeStatus(for: awake.activeAutomationConditions,
                                                  waitingForPower: awake.waitingForPower)
        }
        return l10n.s.keepAwakeUntilDisabled
    }

    private var sessionBinding: Binding<Bool> {
        Binding(
            get: { awake.isActive },
            set: { on in
                if on {
                    awake.startLastPick()
                } else if awake.isActive {
                    awake.toggle()
                }
            }
        )
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = defaultDuration == minutes
        return Button {
            defaultDuration = minutes
            // A chosen default is the newest pick, so the switch starts it.
            UserDefaults.standard.set(false, forKey: DefaultsKey.keepAwakeSwitchUsesUntil)
        } label: {
            Text(DurationPicker.title(for: minutes, l10n.s))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? Color.accentColor.opacity(0.12) : ZenithSurface.tileFill,
                            in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.7) : ZenithSurface.tileStroke,
                                      lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// The conditions that start a session by themselves.
    private var automationSection: some View {
        ZenithSection(automationStrings.automationSection,
                      footer: automationStrings.caption(requireAll: keepAwakeAutomationRequireAll)) {
            KeepAwakeAutomationEditor().padding(.vertical, 10)
        }
    }

    /// Everything else Keep Awake can do: the usual choices first, the rare
    /// ones and the menu bar icon's look under More options.
    private var optionsSection: some View {
        ZenithSection(l10n.s.keepAwakeOptions) {
            ZenithRow(l10n.s.keepAwakeAutoStart, isOn: $keepAwakeAutoStart, info: l10n.s.keepAwakeAutoStartCaption)
            ZenithRow(l10n.s.showCountdown, isOn: $showCountdown)
            ZenithRow(displaySleepStrings.allowDisplaySleep, isOn: $keepAwakeAllowDisplaySleep,
                      info: displaySleepStrings.allowDisplaySleepCaption)
            if PowerSampler.hasInternalBattery {
                ZenithRow(l10n.s.batteryDisableBelow, selection: $batteryLimit, info: l10n.s.batteryProtectionCaption) {
                    Text(l10n.s.batteryNever).tag(0)
                    Text(verbatim: "5%").tag(5)
                    Text(verbatim: "10%").tag(10)
                    Text(verbatim: "15%").tag(15)
                    Text(verbatim: "20%").tag(20)
                }
            }
            ZenithRow(l10n.s.clamshellTitle, info: l10n.s.clamshellExplanation,
                      essential: awake.clamshellSetupInProgress ? l10n.s.configuring : nil,
                      warning: awake.clamshellSetupFailed ? l10n.s.sudoersFailed : nil) {
                ZenithRowSwitch(title: l10n.s.clamshellTitle, isOn: $awake.clamshellPreferred)
                    .disabled(awake.clamshellSetupInProgress)
            }
            if awake.clamshellPreferred {
                ZenithRow(l10n.s.dimScreenOnLidCloseTitle, isOn: $awake.dimScreenOnLidClose,
                          info: l10n.s.dimScreenOnLidCloseCaption)
            }
            ZenithMoreOptions(id: "sleep.keepAwake") {
                ZenithRow(l10n.s.keepAwakeRightClickToggle, isOn: $keepAwakeRightClickToggle,
                          info: l10n.s.keepAwakeRightClickToggleCaption)
                ZenithRow(l10n.s.keepAwakeMouseJiggle, isOn: $keepAwakeMouseJiggle,
                          info: l10n.s.keepAwakeMouseJiggleCaption)
                if keepAwakeMouseJiggle {
                    ZenithRow(l10n.s.keepAwakeMouseJiggleInterval) {
                        KeepAwakeMouseJiggleIntervalPicker(selection: $keepAwakeMouseJiggleInterval)
                    }
                    if !permissions.accessibility {
                        PermissionRow(kind: .accessibility).padding(.vertical, 8)
                    }
                }
                KeepAwakeIconPicker(iconValue: $keepAwakeActiveIcon, tintValue: $keepAwakeIconTint)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: Bluetooth on sleep

    private var bluetoothSection: some View {
        let strings = FeatureStrings.bluetoothSleep(l10n.language)
        return ZenithSection(strings.pageTitle, anchor: .bluetoothSleep) {
            if BluetoothSleepService.isSupported {
                ZenithRow(strings.enable, isOn: $bluetoothSleepEnabled, info: strings.enableCaption)
                    .onChange(of: bluetoothSleepEnabled) { _, _ in
                        BluetoothSleepService.shared.syncWithPreferences()
                    }
                if bluetoothSleepEnabled {
                    ZenithRow(strings.restoreToggle, isOn: $bluetoothSleepRestoreOnWake, info: strings.restoreCaption)
                }
            } else {
                ZenithRow(strings.pageTitle, essential: strings.unsupported) { EmptyView() }
            }
        }
    }

    private var automationStrings: KeepAwakeAutomationStrings {
        FeatureStrings.keepAwakeAutomation(l10n.language)
    }

    private var displaySleepStrings: KeepAwakeDisplaySleepStrings {
        FeatureStrings.keepAwakeDisplaySleep(l10n.language)
    }
}
