// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Zenith fork: what is left of Quick Tools once each tool has a page of its
/// own: Mic Mute and Camera Preview, until they move too.
struct QuickToolsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var micMute = MicMuteService.shared
    @ObservedObject private var cameraPreview = CameraPreviewService.shared
    @AppStorage(DefaultsKey.micMuteShortcutEnabled) private var micShortcutEnabled = false
    @AppStorage(DefaultsKey.micMuteFollowCallApps) private var micFollowCallApps = false
    @AppStorage(DefaultsKey.cameraPreviewShortcutEnabled) private var cameraShortcutEnabled = false
    @AppStorage(DefaultsKey.micMuteMenuBarIndicator) private var micMenuBarIndicator = false

    var body: some View {
        // Zenith fork: the preview card stays above the sections, so it is in
        // view when a sidebar row or a search scrolls the page to its feature.
        VStack(spacing: 0) {
        QuickToolsPreviewCard()
            .zenithToolsPreviewPinned()
        Form {
            if AppFeature.micMute.isAvailable {
                Section {
                    Button {
                        MicMuteService.shared.toggle()
                    } label: {
                        Label(micMute.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName,
                              systemImage: micMute.controlSymbol)
                    }
                    microphoneStatus
                    Text(l10n.s.micMuteCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(l10n.s.micMuteFollowCallAppsToggle, isOn: $micFollowCallApps)
                        .onChange(of: micFollowCallApps) { _, _ in
                            micMute.syncWithPreferences()
                        }
                    Text(l10n.s.micMuteFollowCallAppsCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(l10n.s.micMuteMenuBarToggle, isOn: $micMenuBarIndicator)
                    Text(l10n.s.micMuteMenuBarCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(l10n.s.quickToolShortcutToggle, isOn: $micShortcutEnabled)
                        .onChange(of: micShortcutEnabled) { _, _ in
                            MicMuteService.shared.syncWithPreferences()
                        }
                    ShortcutPreferenceRow(role: .micMute,
                                          isEnabled: micShortcutEnabled) {
                        MicMuteService.shared.syncWithPreferences()
                    }
                    if micShortcutEnabled, micMute.shortcutRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(ZenithStatus.warning)
                    }
                } header: {
                    Text(l10n.s.micMuteName)
                }
                .settingsFormSectionAnchor(.micMute)
            } else if micMute.warning != nil {
                Section(l10n.s.micMuteName) { microphoneStatus }
                    .settingsFormSectionAnchor(.micMute)
            }

            if AppFeature.cameraPreview.isAvailable {
                Section {
                    Button {
                        CameraPreviewService.shared.show()
                    } label: {
                        Label(FeatureStrings.cameraPreview(l10n.language).openButton,
                              systemImage: "web.camera")
                    }
                    Text(FeatureStrings.cameraPreview(l10n.language).panelCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(l10n.s.quickToolShortcutToggle, isOn: $cameraShortcutEnabled)
                        .onChange(of: cameraShortcutEnabled) { _, _ in
                            CameraPreviewService.shared.syncWithPreferences()
                        }
                    ShortcutPreferenceRow(role: .cameraPreview,
                                          isEnabled: cameraShortcutEnabled) {
                        CameraPreviewService.shared.syncWithPreferences()
                    }
                    if cameraShortcutEnabled, cameraPreview.shortcutRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(ZenithStatus.warning)
                    }
                    if permissions.camera == .denied {
                        CameraPermissionRow()
                    }
                } header: {
                    Text(FeatureStrings.cameraPreview(l10n.language).pageTitle)
                }
                .settingsFormSectionAnchor(.cameraPreview)
            }
        }
        .formStyle(.grouped)
        } // Zenith fork
    }

    @ViewBuilder private var microphoneStatus: some View {
        if micMute.isMuted || micMute.warning != nil {
            Label(micMute.warning?.message ?? l10n.s.micMutedHUD,
                  systemImage: micMute.controlSymbol)
                .font(.caption)
                .foregroundStyle(ZenithStatus.warning) // Zenith fork: the status palette
        }
        if micMute.warning == .manualRestore {
            Button(l10n.s.micManualRestoreChecked) { micMute.acknowledgeManualRestore() }
        }
    }
}

/// The camera state has no re-prompt once denied, so the row goes straight
/// to System Settings instead of offering a dead request button.
private struct CameraPermissionRow: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(ZenithStatus.warning)
                Text(FeatureStrings.cameraPreview(l10n.language).permName)
                Spacer()
                Text(l10n.s.permissionMissing)
                    .font(.caption)
                    .foregroundStyle(ZenithStatus.warning)
            }
            Button(l10n.s.permissionOpenSettings) {
                Permissions.shared.openCameraSettings()
            }
            .controlSize(.small)
        }
    }
}
