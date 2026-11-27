// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Brightness, built with the Settings kit. Out of
/// the old Energy page: the displays' brightness and power (the hero's pill
/// is the control's switch), the keys that set it, the speakers of a monitor,
/// and extra brightness on XDR panels.
struct BrightnessSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var extraBrightness = ExtraBrightnessService.shared
    @ObservedObject private var brightness = BrightnessService.shared
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessEnabled = false
    @AppStorage(DefaultsKey.brightnessKeysEnabled) private var brightnessKeysEnabled = false
    @AppStorage(DefaultsKey.brightnessOSDEnabled) private var brightnessOSDEnabled = false
    @AppStorage(DefaultsKey.displayVolumeEnabled) private var displayVolume = false
    @AppStorage(DefaultsKey.displayVolumeKeysEnabled) private var displayVolumeKeys = false
    @AppStorage(DefaultsKey.brightnessKeyStep)
    private var brightnessKeyStep = BrightnessSupport.KeyStep.standard.rawValue
    @AppStorage(DefaultsKey.extraBrightnessEnabled) private var extraBrightnessEnabled = false
    @AppStorage(DefaultsKey.extraBrightnessLevel) private var extraBrightnessLevel = 100

    private let page = ZenithStrings.systemApps(.enUS)
    private var strings: BrightnessFeatureStrings { FeatureStrings.brightness(l10n.language) }

    var body: some View {
        let control = AppFeature.brightness.isAvailable
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: page.brightnessTitle, subtitle: page.brightnessSubtitle, chips: chips,
                           isOn: control ? enabledBinding : nil, switchLabel: strings.enable,
                           animation: .brightness)
                if control, needsAccessibility, !permissions.accessibility {
                    ZenithPermissionSection(kind: .accessibility)
                }
                ZenithScreenPreviewCard(group: .brightness)
                if control {
                    displaysSection
                    if brightnessEnabled { keysSection }
                }
                if AppFeature.extraBrightness.isAvailable {
                    extraSection
                }
            }
        }
        // Shared subviews draw plain toggles; outside a Form those would be
        // checkboxes, so the whole page asks for switches.
        .toggleStyle(ZenithSwitchStyle())
        .onAppear {
            // Displays may have changed since launch (docked, clamshell).
            if AppFeature.brightness.isAvailable { BrightnessService.shared.refresh() }
            if AppFeature.extraBrightness.isAvailable { ExtraBrightnessService.shared.syncWithPreferences() }
        }
    }

    private var chips: [ZenithChip] {
        var chips: [ZenithChip] = []
        if AppFeature.brightness.isAvailable, brightnessEnabled {
            chips.append(ZenithChip(page.brightnessDisplayCount(brightness.displays.count)))
        }
        if AppFeature.extraBrightness.isAvailable, extraBrightness.supported, extraBrightnessEnabled {
            chips.append(ZenithChip(page.brightnessExtraOn, dot: ZenithStatus.success))
        }
        return chips
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { brightnessEnabled }, set: { on in
            brightnessEnabled = on
            BrightnessService.shared.syncWithPreferences()
        })
    }

    private var needsAccessibility: Bool {
        brightnessEnabled && (brightnessKeysEnabled || brightnessOSDEnabled || (displayVolume && displayVolumeKeys)
            || BrightnessSupport.KeyStep.sanitized(brightnessKeyStep) != .standard)
    }

    // MARK: Displays

    private var displaysSection: some View {
        ZenithSection(page.brightnessDisplays, anchor: .brightness) {
            if !brightnessEnabled {
                ZenithRow(strings.enable, info: strings.enableCaption) {
                    ZenithRowSwitch(title: strings.enable, isOn: enabledBinding)
                }
            } else if brightness.displays.isEmpty {
                ZenithRow(strings.noDisplays) { EmptyView() }
            } else {
                ForEach(brightness.displays) { display in
                    VStack(alignment: .leading, spacing: 6) {
                        displayRow(display)
                        if display.isActive, let audio = display.audio {
                            MonitorSpeakerVolumeRow(displayName: display.name, audio: audio,
                                                    strings: strings, compact: false)
                                .padding(.leading, 38)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            if brightnessEnabled, let failure = brightness.displayControlFailure {
                ZenithRow(strings.enable, warning: displayControlFailureText(failure, strings: strings)) { EmptyView() }
            }
        }
    }

    private func displayRow(_ display: BrightnessDisplay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(display.isActive ? Color.accentColor : Color.secondary)
                .frame(width: 26, height: 26)
                .background((display.isActive ? Color.accentColor : Color.secondary).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(display.name)
                .font(ZenithType.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 80, alignment: .leading)
            if display.isActive, display.method != nil {
                Slider(value: Binding(get: { display.brightness },
                                      set: { BrightnessService.shared.setBrightness(
                                          $0, for: display.id,
                                          showOSD: brightnessOSDEnabled) }),
                       in: 0...1)
                    .disabled(brightness.isDisplayPending(display.id))
                    .accessibilityLabel(display.name)
                Text("\(Int((display.brightness * 100).rounded()))%")
                    .font(ZenithType.figures(11.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Spacer()
                if !display.isActive {
                    Text(strings.displayOff)
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
            SoftwareDimmingButton(display: display)
            DisplayPowerButton(display: display)
        }
    }

    // MARK: Keys

    /// The keys that set brightness and a monitor's volume. The step and the
    /// shortcuts stay in view; the on-screen display and the speakers' keys
    /// fold under More options.
    private var keysSection: some View {
        ZenithSection(page.brightnessKeys, footer: strings.externalCaption) {
            ZenithRow(strings.keysToggle, isOn: $brightnessKeysEnabled, info: strings.keysCaption)
                .onChange(of: brightnessKeysEnabled) { _, isOn in
                    if isOn { Permissions.shared.requestAccessibility() }
                    BrightnessService.shared.syncWithPreferences()
                }
            ZenithRow(strings.keyStep, selection: brightnessKeyStepBinding, info: strings.keyStepCaption) {
                Text(strings.keyStepStandard).tag(BrightnessSupport.KeyStep.standard)
                Text(strings.keyStepHalf).tag(BrightnessSupport.KeyStep.half)
                Text(strings.keyStepQuarter).tag(BrightnessSupport.KeyStep.quarter)
            }
            DisplayBrightnessShortcutControls(showsSettingsRow: true)
            ZenithMoreOptions(id: "brightness.keys") {
                if brightness.brightnessOSDSupported {
                    ZenithRow(strings.osdToggle, isOn: $brightnessOSDEnabled, info: strings.osdCaption)
                        .onChange(of: brightnessOSDEnabled) { _, isOn in
                            if isOn { Permissions.shared.requestAccessibility() }
                            BrightnessService.shared.syncWithPreferences()
                        }
                }
                ZenithRow(strings.volumeToggle, isOn: $displayVolume, info: strings.volumeCaption)
                    .onChange(of: displayVolume) { _, _ in
                        BrightnessService.shared.syncWithPreferences()
                    }
                if displayVolume {
                    ZenithRow(strings.volumeKeysToggle, isOn: $displayVolumeKeys, info: strings.volumeKeysCaption)
                        .onChange(of: displayVolumeKeys) { _, isOn in
                            if isOn { Permissions.shared.requestAccessibility() }
                            BrightnessService.shared.syncWithPreferences()
                        }
                    if displayVolumeKeys {
                        MonitorVolumeKeyControls(strings: strings)
                    }
                }
            }
        }
    }

    /// A finer step answers the keys in place of the system, which takes the
    /// same permission as the other key options.
    private var brightnessKeyStepBinding: Binding<BrightnessSupport.KeyStep> {
        Binding {
            BrightnessSupport.KeyStep.sanitized(brightnessKeyStep)
        } set: { step in
            brightnessKeyStep = step.rawValue
            if step != .standard { Permissions.shared.requestAccessibility() }
            BrightnessService.shared.syncWithPreferences()
        }
    }

    // MARK: Extra brightness

    private var extraSection: some View {
        ZenithSection(page.brightnessExtra, anchor: .extraBrightness) {
            if extraBrightness.supported {
                ZenithRow(l10n.s.extraBrightnessName, isOn: $extraBrightnessEnabled,
                          info: l10n.s.extraBrightnessCaption)
                    .onChange(of: extraBrightnessEnabled) { _, _ in
                        ExtraBrightnessService.shared.syncWithPreferences()
                    }
                if extraBrightnessEnabled {
                    ZenithRow(l10n.s.extraBrightnessLevelLabel, value: extraBrightnessLevelBinding, in: 10...100,
                              step: 5, valueLabel: "\(extraBrightnessLevel)%",
                              minimumSymbol: "sun.min", maximumSymbol: "sun.max.fill")
                }
            } else {
                ZenithRow(l10n.s.extraBrightnessName, essential: l10n.s.extraBrightnessUnsupported) { EmptyView() }
            }
        }
    }

    private var extraBrightnessLevelBinding: Binding<Double> {
        Binding(get: { Double(extraBrightnessLevel) },
                set: { newValue in
                    extraBrightnessLevel = Int(newValue)
                    ExtraBrightnessService.shared.levelDidChange()
                })
    }
}
