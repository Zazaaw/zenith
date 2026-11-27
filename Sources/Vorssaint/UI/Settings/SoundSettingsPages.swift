// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the sound tools, a Settings page each (they were sections of
// General and Quick Tools): Volume Mixer, Sound Output (the output switcher
// with the audio priority), Music Blocker and Mic Mute. Feature pages in the
// kit (docs/SETTINGS-KIT.md): the hero with the tool's own animation, its
// picture on the stage, then compact rows. Every row writes the preference
// it always did and tells the same service.

// MARK: - Volume Mixer

struct VolumeMixerSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var preciseVolumeRoller = PreciseVolumeRollerService.shared
    @AppStorage(DefaultsKey.mixerHideInactiveApps) private var hideInactiveApps = false
    @AppStorage(DefaultsKey.mixerLowerVolumeOnHeadphonesDisconnect) private var lowerOnHeadphonesDisconnect = false
    @AppStorage(DefaultsKey.mixerHeadphonesDisconnectVolumePercent)
    private var headphonesDisconnectVolumePercent = Defaults.defaultMixerHeadphonesDisconnectVolumePercent
    @AppStorage(DefaultsKey.preciseVolumeRollerEnabled) private var preciseVolumeRollerEnabled = false

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        ZenithToolPage {
            ZenithHero(title: s.mixerSection, subtitle: text.mixerSubtitle,
                       chips: [ZenithChip(text.apps(mixer.apps.count))], animation: .volumeMixer)
                .zenithSectionAnchor(.mixer, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            ZenithScenePreview(scenes: [.mixer])
            ZenithSection(text.mixerDevices) {
                MixerSection(settingsMode: true)
                    .padding(.vertical, 10)
            }
            ZenithSection(text.mixerOptions) {
                if AppVolumeMixer.isSupported {
                    ZenithRow(FeatureStrings.mixer(l10n.language).hideInactiveApps, isOn: $hideInactiveApps)
                }
                ZenithRow(s.mixerLowerOnHeadphonesDisconnect, isOn: $lowerOnHeadphonesDisconnect,
                          info: s.mixerLowerOnHeadphonesDisconnectCaption)
                if lowerOnHeadphonesDisconnect {
                    ZenithRow(s.mixerHeadphonesDisconnectVolume, value: headphonesVolume,
                              in: Defaults.minimumMixerHeadphonesDisconnectVolumePercent...100, step: 5,
                              format: { "\($0)%" })
                }
                ZenithRow(s.preciseVolumeRollerEnable, isOn: $preciseVolumeRollerEnabled,
                          info: s.preciseVolumeRollerCaption,
                          warning: preciseVolumeRollerEnabled && permissions.accessibility && preciseVolumeRoller.tapFailed
                            ? s.preciseVolumeRollerTapFailed : nil)
                    .onChange(of: preciseVolumeRollerEnabled) { _, enabled in
                        if enabled { permissions.requestAccessibility() }
                        PreciseVolumeRollerService.shared.syncWithPreferences()
                    }
                if preciseVolumeRollerEnabled, !permissions.accessibility {
                    ZenithRow(s.permissionAccessibility, essential: s.permissionMissing,
                              button: s.permissionOpenSettings) {
                        Permissions.shared.openAccessibilitySettings()
                    }
                }
                if AppVolumeMixer.isSupported, !choices.isEmpty {
                    ZenithMoreOptions(id: "volumeMixer", anchors: [.zenithMixerVisibleApps]) {
                        ZenithRow(s.mixerVisibleApps, info: text.mixerVisibleCaption) {
                            Text(mixer.hiddenApps.isEmpty ? s.mixerAllShown
                                 : "\(s.mixerHiddenCountLabel): \(mixer.hiddenApps.count)")
                                .font(ZenithType.body)
                                .foregroundStyle(.secondary)
                        }
                        .zenithSectionAnchor(.zenithMixerVisibleApps, cornerRadius: 10, inset: 4)
                        ForEach(choices) { choice in
                            ZenithRow(choice.name, isOn: choice.listedBinding(mixer))
                                .disabled(!choice.canToggle)
                        }
                    }
                }
            }
        }
        .onAppear { mixer.refreshApps() }
    }

    private var choices: [MixerListChoice] { MixerListChoice.all(mixer) }

    private var headphonesVolume: Binding<Int> {
        Binding(get: { Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent(headphonesDisconnectVolumePercent) },
                set: { headphonesDisconnectVolumePercent = Defaults.sanitizedMixerHeadphonesDisconnectVolumePercent($0) })
    }
}

// MARK: - Sound Output

struct SoundOutputSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var outputSwitcher = SoundOutputSwitcher.shared
    @AppStorage(DefaultsKey.soundOutputSwitcherEnabled) private var enabled = false
    @State private var selectedUIDs: [String] = []
    @State private var scene = 0

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        let switcher = features.isAvailable(.soundOutputSwitcher)
        let priority = features.isAvailable(.audioPriority)
        ZenithToolPage {
            ZenithHero(title: s.soundOutputSwitcherTitle, subtitle: text.outputSubtitle,
                       chips: chips(switcher: switcher), animation: .soundOutput)
                .zenithSectionAnchor(.soundOutputSwitcher, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            ZenithScenePreview(scenes: scenes(switcher: switcher, priority: priority), selection: $scene)
            if switcher { switcherSection }
            if priority {
                ZenithSection(s.audioPrioritySection, anchor: .audioPriority, footer: s.audioPriorityCaption) {
                    AudioPriorityDisclosure(initiallyExpanded: true, showsHeader: false, showsCaption: false)
                        .padding(.vertical, 10)
                }
            }
        }
        .onAppear { selectedUIDs = outputSwitcher.selectedDeviceUIDs() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)) { _ in
            selectedUIDs = outputSwitcher.selectedDeviceUIDs()
        }
        .onChange(of: enabled) { _, isEnabled in
            if let seeded = SoundOutputSwitcherControls.seed(enabled: isEnabled, selected: selectedUIDs, mixer: mixer) {
                setSelectedUIDs(seeded)
            }
            outputSwitcher.syncWithPreferences()
        }
    }

    private func chips(switcher: Bool) -> [ZenithChip] {
        guard switcher, enabled else { return [] }
        return [ZenithChip(text.devices(selectedUIDs.count)),
                ZenithShortcutChip.chip(.soundOutputSwitcher, enabled: enabled)]
    }

    private func scenes(switcher: Bool, priority: Bool) -> [ZenithScreenScene] {
        (switcher ? [.output] : []) + (priority ? [.priority] : [])
    }

    private var switcherSection: some View {
        let s = l10n.s
        let devices = SoundOutputSwitcherControls.devices(mixer)
        return ZenithSection(text.outputSwitcher) {
            ZenithRow(s.soundOutputSwitcherEnable, isOn: $enabled, info: s.soundOutputSwitcherCaption,
                      warning: enabled && outputSwitcher.lastSwitchFailed ? s.soundOutputSwitcherNoAvailableSelection : nil)
            if enabled {
                ShortcutPreferenceRow(role: .soundOutputSwitcher, isEnabled: enabled,
                                      additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                    outputSwitcher.syncWithPreferences()
                }
                .padding(.vertical, 9)
                if outputSwitcher.registrationFailed {
                    ZenithRow(text.outputShortcut, warning: s.shortcutUnavailable) { EmptyView() }
                }
                if devices.isEmpty {
                    ZenithRow(s.soundOutputSwitcherDevices, essential: s.mixerSystemOutputNoDevices) { EmptyView() }
                } else {
                    ForEach(devices) { device in
                        ZenithRow(device.isDefault ? "\(device.name) (\(s.mixerOutputCurrent))" : device.name,
                                  isOn: selectionBinding(for: device.uid))
                    }
                }
            }
        }
    }

    private func selectionBinding(for uid: String) -> Binding<Bool> {
        Binding(get: { selectedUIDs.contains(uid) }, set: { selected in
            setSelectedUIDs(SoundOutputSwitcherControls.selection(selectedUIDs, uid: uid, selected: selected, mixer: mixer))
        })
    }

    private func setSelectedUIDs(_ uids: [String]) {
        let sanitized = Defaults.sanitizedSoundOutputSwitcherDeviceUIDs(uids)
        selectedUIDs = sanitized
        outputSwitcher.setSelectedDeviceUIDs(sanitized)
    }
}

// MARK: - Music Blocker

struct MusicBlockerSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var musicBlocker = MusicLaunchBlocker.shared
    @State private var replacementRejected = false
    @AppStorage(DefaultsKey.musicBlockEnabled) private var enabled = false
    @AppStorage(DefaultsKey.musicBlockReplacementPath) private var replacementPath = ""
    @AppStorage(DefaultsKey.musicBlockPlayReplacement) private var playReplacement = true

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        ZenithToolPage {
            ZenithHero(title: FeatureStrings.hub(l10n.language).titleMusicBlock, subtitle: text.musicSubtitle,
                       chips: replacementPath.isEmpty ? [] : [ZenithChip("\(text.musicReplacement): \(replacementName)")],
                       isOn: $enabled, switchLabel: s.musicBlockTitle, switchHint: s.musicBlockCaption,
                       animation: .musicBlocker)
                .zenithSectionAnchor(.musicBlocking, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            if enabled, !permissions.accessibility {
                ZenithSection { PermissionRow(kind: .accessibility).padding(.vertical, 10) }
            } else if enabled, !musicBlocker.isMonitoring {
                ZenithCallout(.warning, s.musicBlockUnavailable)
            }
            ZenithScenePreview(scenes: [.musicBlock])
            ZenithSection(footer: s.musicBlockCaption) {
                ZenithRow(s.musicBlockReplacementLabel,
                          warning: replacementRejected ? s.musicBlockReplacementBlocked : nil) {
                    HStack(spacing: 8) {
                        Text(replacementName).font(ZenithType.body).foregroundStyle(.secondary)
                        if !replacementPath.isEmpty {
                            Button {
                                replacementPath = ""
                                replacementRejected = false
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .help(text.musicClearReplacement)
                            .accessibilityLabel(text.musicClearReplacement)
                        }
                        Button(s.musicBlockChooseApp, action: chooseReplacement)
                    }
                }
                if !replacementPath.isEmpty {
                    ZenithRow(s.musicBlockPlayReplacement, isOn: $playReplacement)
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.55)
        }
        .onChange(of: enabled) { _, _ in musicBlocker.syncWithPreferences() }
    }

    private var replacementName: String {
        guard !replacementPath.isEmpty else { return l10n.s.musicBlockReplacementNone }
        let name = FileManager.default.displayName(atPath: replacementPath)
        return (name as NSString).deletingPathExtension
    }

    private func chooseReplacement() {
        replacementRejected = false
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Picking the blocked app itself would start a launch-and-kill loop.
        if let bundleID = Bundle(url: url)?.bundleIdentifier,
           MusicLaunchBlocker.blockedBundleIDs.contains(bundleID) {
            replacementRejected = true
            return
        }
        replacementPath = url.path
    }
}

// MARK: - Mic Mute

struct MicMuteSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @AppStorage(DefaultsKey.micMuteShortcutEnabled) private var shortcutEnabled = false
    @AppStorage(DefaultsKey.micMuteFollowCallApps) private var followCallApps = false
    @AppStorage(DefaultsKey.micMuteMenuBarIndicator) private var menuBarIndicator = false

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        ZenithToolPage {
            ZenithHero(title: s.micMuteName, subtitle: text.micSubtitle,
                       chips: [micMute.isMuted ? ZenithChip(text.micMuted, dot: ZenithStatus.error)
                                               : ZenithChip(text.micLive, dot: ZenithStatus.success),
                               ZenithShortcutChip.chip(.micMute, enabled: shortcutEnabled)],
                       animation: .micMute)
                .zenithSectionAnchor(.micMute, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            if let warning = micMute.warning {
                ZenithCallout(.warning, warning.message) {
                    if warning == .manualRestore {
                        Button(s.micManualRestoreChecked) { micMute.acknowledgeManualRestore() }
                    }
                }
            }
            ZenithSettingsPreviewCard(id: "micMute", caption: text.micStage) {
                QuickToolsPreviewPicture(group: .apps, shown: .micMute, available: [.micMute], open: { _ in })
            }
            ZenithSection(text.micNow) {
                ZenithRow("\(text.micRow): \(micMute.isMuted ? text.micMuted : text.micLive)", info: s.micMuteCaption,
                          button: micMute.isMuted ? s.micUnmuteName : s.micMuteName) {
                    MicMuteService.shared.toggle()
                }
            }
            ZenithSection(text.micBehaviour) {
                ZenithRow(s.micMuteFollowCallAppsToggle, isOn: $followCallApps, info: s.micMuteFollowCallAppsCaption)
                    .onChange(of: followCallApps) { _, _ in micMute.syncWithPreferences() }
                ZenithRow(s.micMuteMenuBarToggle, isOn: $menuBarIndicator, info: s.micMuteMenuBarCaption)
            }
            ZenithSection(text.micShortcut) {
                ZenithShortcutSwitchRows(title: s.quickToolShortcutToggle, role: .micMute, isOn: $shortcutEnabled,
                                         failed: micMute.shortcutRegistrationFailed) {
                    MicMuteService.shared.syncWithPreferences()
                }
            }
        }
    }
}
