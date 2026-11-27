// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Settings → Screen Recording. Zenith fork: a page of its own in the kit
/// (docs/SETTINGS-KIT.md), split from Screen capture: the hero, the picture,
/// then how a recording starts and what it captures, where the file lands
/// (quality and frame rates under More options), the shortcuts and sharing.
struct ScreenRecordingSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = ScreenRecorderService.shared
    @ObservedObject private var sharing = RecordingShareService.shared
    @ObservedObject private var recent = RecentCaptureService.shared
    @AppStorage(DefaultsKey.recorderCountdown) private var countdown = 3
    @AppStorage(DefaultsKey.recorderQuality) private var qualityRaw =
        RecorderSupport.Quality.balanced.rawValue
    @AppStorage(DefaultsKey.recorderFrameRate) private var frameRate = 60
    @AppStorage(DefaultsKey.recorderSystemAudio) private var systemAudio = true
    @AppStorage(DefaultsKey.recorderMicrophone) private var microphone = false
    @AppStorage(DefaultsKey.recorderSaveFolder) private var saveFolder = ""
    @AppStorage(DefaultsKey.recorderOpenEditor) private var opensEditor = true
    @AppStorage(DefaultsKey.recorderAutomaticZoom) private var automaticZoom = true
    @AppStorage(DefaultsKey.recorderGIFFrameRate) private var gifFrameRate = 12
    @AppStorage(DefaultsKey.recorderSharingEnabled) private var sharingEnabled = true
    @AppStorage(DefaultsKey.recentCapturesShortcutEnabled) private var recentShortcutEnabled = false
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false

    private let text = ZenithStrings.soundCapture(.enUS)

    private var strings: RecorderFeatureStrings {
        FeatureStrings.recorder(l10n.language)
    }

    private var shareStrings: RecorderShareStrings {
        FeatureStrings.recorderShare(l10n.language)
    }

    private var screenshotStrings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        let s = l10n.s
        ZenithToolPage {
            ZenithHero(title: strings.pageTitle, subtitle: text.recordingSubtitle,
                       chips: [service.isRecording ? ZenithChip(RecorderSupport.elapsedLabel(seconds: service.elapsedSeconds),
                                                                dot: ZenithStatus.error)
                                                   : ZenithChip(qualityTitle),
                               ZenithChip(String(format: strings.frameRateFormat, frameRate)),
                               CaptureToolShortcutRows.chip(.recording)],
                       animation: .screenRecording)
                .zenithSectionAnchor(.screenRecorder, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            CapturePermissionSection(kind: .screenRecording)
            CapturePermissionSection(kind: .accessibility)
            ZenithScenePreview(scenes: [.recording])
            recording
            saving
            ZenithSection(text.shortcutSection) {
                CaptureToolShortcutRows(tool: .recording)
                ZenithShortcutSwitchRows(title: GlobalShortcutRole.recentCaptures.title(s), role: .recentCaptures,
                                         isOn: $recentShortcutEnabled, failed: recent.shortcutRegistrationFailed) {
                    recent.syncWithPreferences()
                }
            }
            sharingSection
        }
        .onAppear { sharing.refresh() }
        .sheet(isPresented: $showingSharedLinks) {
            RecorderSharedLinksView()
        }
        .sheet(isPresented: $showingSharePrivacy) {
            RecorderSharePrivacyView()
        }
    }

    private var qualityTitle: String {
        switch RecorderSupport.Quality(rawValue: qualityRaw) ?? .balanced {
        case .small: return strings.qualitySmall
        case .balanced: return strings.qualityBalanced
        case .high: return strings.qualityHigh
        }
    }

    private var recording: some View {
        ZenithSection(text.recordingRecord) {
            ZenithRow(service.isRecording ? text.recordingLive : text.recordingIdle,
                      info: strings.panelCaption,
                      essential: service.isRecording ? RecorderSupport.elapsedLabel(seconds: service.elapsedSeconds) : nil,
                      button: service.isRecording ? strings.stopButton : strings.startButton) {
                ScreenRecorderService.shared.toggle()
            }
            ZenithRow(strings.countdownLabel, selection: $countdown) {
                ForEach(ScreenshotSupport.allowedDelays, id: \.self) { seconds in
                    if seconds == 0 {
                        Text(strings.countdownOff).tag(0)
                    } else {
                        Text(String(format: strings.countdownSecondsFormat, seconds)).tag(seconds)
                    }
                }
            }
            ZenithRow(strings.systemAudioToggle, isOn: $systemAudio, info: strings.systemAudioCaption)
            ZenithRow(strings.microphoneToggle, isOn: $microphone, info: strings.microphoneCaption)
                .onChange(of: microphone) { _, enabled in
                    if enabled, permissions.microphone == .undetermined {
                        permissions.requestMicrophone()
                    }
                }
            if microphone, permissions.microphone != .granted {
                PermissionRow(kind: .microphone).padding(.vertical, 10)
            }
            ZenithRow(strings.openEditorToggle, isOn: $opensEditor, info: strings.openEditorCaption)
            ZenithRow(strings.automaticZoomToggle, isOn: $automaticZoom, info: strings.automaticZoomCaption)
        }
    }

    private var saving: some View {
        ZenithSection(text.recordingSaving) {
            ZenithFolderRow(title: strings.folderLabel, chooseTitle: strings.folderChoose, path: $saveFolder)
            ZenithMoreOptions(id: "screenRecording", anchors: [.zenithRecordingMore]) {
                ZenithRow(strings.qualityLabel, selection: $qualityRaw, info: strings.qualityCaption) {
                    Text(strings.qualitySmall).tag(RecorderSupport.Quality.small.rawValue)
                    Text(strings.qualityBalanced).tag(RecorderSupport.Quality.balanced.rawValue)
                    Text(strings.qualityHigh).tag(RecorderSupport.Quality.high.rawValue)
                }
                .zenithSectionAnchor(.zenithRecordingMore, cornerRadius: 10, inset: 4)
                ZenithRow(strings.frameRateLabel, selection: $frameRate) {
                    ForEach(RecorderSupport.frameRates, id: \.self) { rate in
                        Text(String(format: strings.frameRateFormat, rate)).tag(rate)
                    }
                }
                ZenithRow(strings.gifFrameRateLabel, selection: $gifFrameRate) {
                    ForEach(RecorderSupport.gifFrameRates, id: \.self) { rate in
                        Text(String(format: strings.frameRateFormat, rate)).tag(rate)
                    }
                }
            }
        }
    }

    private var sharingSection: some View {
        ZenithSection(screenshotStrings.shareSectionTitle) {
            ZenithRow(screenshotStrings.shareEnabledToggle, isOn: $sharingEnabled,
                      info: sharingEnabled ? shareStrings.caption : nil)
            ZenithRow(screenshotStrings.sharePrivacyButton, navigate: { showingSharePrivacy = true })
            if !sharing.records.isEmpty {
                ZenithRow(screenshotStrings.sharedLinksTitle, value: "\(sharing.records.count)",
                          navigate: { showingSharedLinks = true })
            }
        }
    }
}

private struct RecorderSharePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var shareStrings: RecorderShareStrings {
        FeatureStrings.recorderShare(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(strings.sharePrivacyTitle, systemImage: "hand.raised")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyParagraph(symbol: "video", text: shareStrings.privacyData)
                    privacyParagraph(symbol: "externaldrive", text: shareStrings.privacyStorage)
                    privacyParagraph(symbol: "person.2", text: shareStrings.privacyAccess)
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 390)
    }

    private func privacyParagraph(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RecorderSharedLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var sharing = RecordingShareService.shared
    @State private var deletingID: String?
    @State private var showingDeleteError = false

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(strings.sharedLinksTitle)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Divider()

            if sharing.records.isEmpty {
                ContentUnavailableView(strings.sharedLinksEmpty,
                                       systemImage: "link.badge.plus")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(sharing.records) { record in
                    linkRow(record)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 560, height: 360)
        .onAppear { sharing.refresh() }
        .alert(strings.deleteFailedHUD, isPresented: $showingDeleteError) {
            Button(strings.done, role: .cancel) {}
        }
    }

    private func linkRow(_ record: RecordingShareRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "link")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    Text(strings.expiresLabel)
                    Text(record.expiresAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                sharing.copy(record.url)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.copyLink)
            Button {
                NSWorkspace.shared.open(record.url)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .screenshotSafeHelp(strings.openLink)
            Button(role: .destructive) {
                delete(record)
            } label: {
                if deletingID == record.id {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(.borderless)
            .disabled(deletingID != nil)
            .screenshotSafeHelp(strings.deleteLink)
        }
        .padding(.vertical, 5)
    }

    private func delete(_ record: RecordingShareRecord) {
        deletingID = record.id
        Task { @MainActor in
            do {
                try await sharing.delete(record)
                QuickToolHUD.show(icon: "link", message: strings.linkDeletedHUD)
            } catch {
                showingDeleteError = true
            }
            deletingID = nil
        }
    }
}
