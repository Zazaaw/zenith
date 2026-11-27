// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Settings → Screenshot. Zenith fork: a page of its own in the kit
/// (docs/SETTINGS-KIT.md), split from Screen capture, with the scrolling
/// screenshot as a section of it: the hero, the picture (screenshot or
/// scrolling), how a capture starts, scrolling capture, the shortcuts, what
/// happens after a capture, where it is saved, the editor's tools, sharing,
/// then the design overlay and Beautify. The loupe and the after-capture
/// preview sit under More options.
struct ScreenshotSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = ScreenshotService.shared
    @ObservedObject private var sharing = ScreenshotShareService.shared
    @ObservedObject private var recent = RecentCaptureService.shared
    @AppStorage(DefaultsKey.screenshotFullScreenShortcutEnabled)
    private var fullScreenShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotLastCaptureShortcutEnabled)
    private var lastCaptureShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotClipboardShortcutEnabled)
    private var clipboardShortcutEnabled = false
    @AppStorage(DefaultsKey.recentCapturesShortcutEnabled) private var recentShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotScrollingAutoScroll) private var autoScroll = false
    @AppStorage(DefaultsKey.screenshotFreeze) private var freeze = true
    @AppStorage(DefaultsKey.screenshotHideVorssaintWindows) private var hideVorssaintWindows = true
    @AppStorage(DefaultsKey.screenshotSaveFolder) private var saveFolder = ""
    @AppStorage(DefaultsKey.screenshotSaveSubfolder) private var saveSubfolder = ""
    @AppStorage(DefaultsKey.screenshotFileNamePattern) private var fileNamePattern = ""
    @AppStorage(DefaultsKey.screenshotFileNumberStart) private var numberStart = 1
    @AppStorage(DefaultsKey.screenshotFileNumberNext) private var nextNumber = 1
    @AppStorage(DefaultsKey.screenshotIncludePointer) private var includePointer = false
    @AppStorage(DefaultsKey.screenshotShowLastRegion) private var showLastRegion = true
    @AppStorage(DefaultsKey.screenshotHighlightWindows) private var highlightWindows = true
    @AppStorage(DefaultsKey.screenshotLoupeStartsOn) private var loupeStartsOn = false
    @AppStorage(DefaultsKey.screenshotLoupeRememberZoom) private var rememberLoupeZoom = false
    @AppStorage(DefaultsKey.screenshotLoupeDefaultZoom) private var loupeDefaultZoom = 1.0
    @AppStorage(DefaultsKey.screenshotLoupeSteppedZoomByDefault)
    private var steppedLoupeZoomByDefault = false
    @AppStorage(DefaultsKey.screenshotDownscale) private var downscale = false
    @AppStorage(DefaultsKey.screenshotDelay) private var delay = 0
    @AppStorage(DefaultsKey.screenshotDefaultAction) private var defaultActionRaw = ""
    @AppStorage(DefaultsKey.screenshotToolOrder) private var toolOrderRaw =
        ScreenshotSupport.Tool.defaultOrderStorage
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true
    @AppStorage(DefaultsKey.screenshotCopyToClipboard) private var copyToClipboard = false
    @AppStorage(DefaultsKey.screenshotCopyImageOnly) private var copyImageOnly = false
    @AppStorage(DefaultsKey.screenshotAddToShelf) private var addToShelf = false
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfEnabled = false
    @AppStorage(AppFeature.shelf.availabilityKey) private var shelfAvailable = false
    @AppStorage(DefaultsKey.screenshotPreviewPosition) private var previewPositionRaw = ""
    @AppStorage(DefaultsKey.screenshotPreviewTakesFocus) private var previewTakesFocus = true
    @AppStorage(DefaultsKey.screenshotPreviewEnabled) private var previewEnabled = true
    @AppStorage(DefaultsKey.screenshotPreviewDuration) private var previewDuration =
        ScreenshotSupport.defaultConfirmationPreviewDuration
    @AppStorage(DefaultsKey.screenshotSharingEnabled) private var sharingEnabled = true
    @AppStorage(DefaultsKey.screenshotUploadShortcutEnabled) private var uploadShortcutEnabled = false
    @AppStorage(DefaultsKey.screenshotUploadDuration) private var uploadDuration = ScreenshotShareDuration.oneHour.rawValue
    @State private var showingSharedLinks = false
    @State private var showingSharePrivacy = false
    @State private var scene = 0

    private let text = ZenithStrings.soundCapture(.enUS)

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        ZenithToolPage {
            ZenithHero(title: strings.pageTitle, subtitle: text.screenshotSubtitle,
                       chips: [CaptureToolShortcutRows.chip(.screenshot), ZenithChip(delayTitle(delay))],
                       animation: .screenshot)
                .zenithSectionAnchor(.screenshot, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            CapturePermissionSection(kind: .screenRecording)
            ZenithScenePreview(scenes: [.screenshot, .scrolling], selection: $scene)
            capture
            scrolling
            shortcuts
            afterCapture
            saving
            ZenithSection(strings.toolShortcutsTitle) {
                ScreenshotToolOrderControls(orderRaw: $toolOrderRaw, shortcutsEnabled: $toolShortcutsEnabled,
                                            showsTitle: false)
                    .padding(.vertical, 10)
            }
            sharingSection
            DesignOverlaySettingsSection() // Zenith fork: the design QA overlay.
            ScreenshotBeautifySettingsSection() // Zenith fork: Beautify.
        }
        .onAppear {
            sharing.refresh()
            followRoute()
        }
        .onChange(of: router.requestID) { _, _ in followRoute() }
        .sheet(isPresented: $showingSharedLinks) {
            ScreenshotSharedLinksView()
        }
        .sheet(isPresented: $showingSharePrivacy) {
            ScreenshotSharePrivacyView()
        }
    }

    /// Landing on scrolling capture shows its picture.
    private func followRoute() {
        if router.destination.sectionAnchor == .screenshotScrolling { scene = 1 }
    }

    private func delayTitle(_ seconds: Int) -> String {
        seconds == 0 ? strings.delayOff : String(format: strings.delaySecondsFormat, seconds)
    }

    // MARK: Capture

    private var capture: some View {
        ZenithSection(text.screenshotCapture) {
            ZenithRow(strings.pageTitle, info: strings.panelCaption, button: strings.captureButton) {
                ScreenCaptureService.shared.capture(initial: .screenshot)
            }
            ZenithRow(strings.freezeToggle, isOn: $freeze, info: strings.freezeCaption)
            ZenithRow(strings.delayLabel, selection: $delay) {
                ForEach(ScreenshotSupport.allowedDelays, id: \.self) { seconds in
                    Text(delayTitle(seconds)).tag(seconds)
                }
            }
            ZenithRow(strings.pointerToggle, isOn: $includePointer)
            ZenithRow(strings.lastRegionToggle, isOn: $showLastRegion)
            ZenithRow(strings.highlightWindowsToggle, isOn: $highlightWindows, info: strings.highlightWindowsCaption)
            ZenithMoreOptions(id: "screenshot.capture", anchors: [.zenithScreenshotLoupe]) {
                ZenithRow(strings.hideVorssaintWindowsToggle, isOn: $hideVorssaintWindows)
                ZenithRow(strings.loupeStartsOnToggle, isOn: $loupeStartsOn)
                    .zenithSectionAnchor(.zenithScreenshotLoupe, cornerRadius: 10, inset: 4)
                ZenithRow(strings.loupeRememberZoomToggle, isOn: $rememberLoupeZoom)
                if !rememberLoupeZoom {
                    ZenithRow(strings.loupeDefaultZoomLabel, selection: $loupeDefaultZoom) {
                        ForEach(ScreenshotSupport.captureLoupeDefaultZooms, id: \.self) { zoom in
                            Text(zoom.formatted(.number.precision(.fractionLength(0...1))) + "×").tag(zoom)
                        }
                    }
                }
                ZenithRow(strings.loupeWheelZoomLabel, selection: $steppedLoupeZoomByDefault,
                          info: strings.loupeZoomOptionCaption) {
                    Text(strings.loupeZoomFast).tag(false)
                    Text(strings.loupeZoomStepped).tag(true)
                }
            }
        }
    }

    // MARK: Scrolling

    private var scrolling: some View {
        ZenithSection(text.screenshotScrolling, anchor: .screenshotScrolling) {
            ZenithRow(strings.scrollingCaptureTitle, info: strings.scrollingCaptureCaption,
                      button: strings.scrollingCaptureButton) {
                ScreenCaptureService.shared.capture(initial: .scrolling)
            }
            ZenithRow(strings.scrollingAutoScrollToggle, isOn: $autoScroll, info: strings.scrollingAutoScrollCaption)
            if autoScroll, !permissions.accessibility {
                PermissionRow(kind: .accessibility).padding(.vertical, 10)
            }
            CaptureToolShortcutRows(tool: .scrolling)
        }
    }

    // MARK: Shortcuts

    private var shortcuts: some View {
        let sync = { ScreenshotService.shared.syncWithPreferences() }
        return ZenithSection(text.screenshotShortcuts) {
            CaptureToolShortcutRows(tool: .screenshot)
            ZenithShortcutSwitchRows(title: strings.fullScreenShortcutTitle, role: .screenshotFullScreen,
                                     isOn: $fullScreenShortcutEnabled,
                                     failed: service.fullScreenShortcutRegistrationFailed, sync: sync)
            ZenithShortcutSwitchRows(title: strings.editLastCapture, role: .screenshotLastCapture,
                                     isOn: $lastCaptureShortcutEnabled,
                                     failed: service.lastCaptureShortcutRegistrationFailed, sync: sync)
            ZenithShortcutSwitchRows(title: strings.editClipboardImage, role: .screenshotClipboard,
                                     isOn: $clipboardShortcutEnabled,
                                     failed: service.clipboardShortcutRegistrationFailed, sync: sync)
            ZenithShortcutSwitchRows(title: GlobalShortcutRole.recentCaptures.title(l10n.s), role: .recentCaptures,
                                     isOn: $recentShortcutEnabled, failed: recent.shortcutRegistrationFailed) {
                recent.syncWithPreferences()
            }
        }
    }

    // MARK: After a capture

    private var afterCapture: some View {
        ZenithSection(text.screenshotAfter) {
            ZenithRow(strings.autoCopyToggle, isOn: autoCopyBinding, info: strings.autoCopyCaption)
            ZenithRow(strings.copyImageOnlyToggle, isOn: $copyImageOnly, info: strings.copyImageOnlyCaption)
            ZenithRow(strings.addToShelfToggle, isOn: addToShelfBinding, info: strings.addToShelfCaption)
                .disabled(!shelfIsOn)
            ZenithMoreOptions(id: "screenshot.after", anchors: [.zenithScreenshotMore]) {
                ZenithRow(strings.defaultActionLabel, selection: $defaultActionRaw,
                          info: defaultActionRaw != ScreenshotDefaultAction.edit.rawValue ? strings.defaultActionCaption : nil) {
                    ScreenshotDefaultActionOptions(strings: strings)
                }
                .zenithSectionAnchor(.zenithScreenshotMore, cornerRadius: 10, inset: 4)
                if usesAutomaticConfirmationPreview {
                    ZenithRow(strings.confirmationPreviewToggle, isOn: $previewEnabled,
                              info: strings.confirmationPreviewCaption)
                    if previewEnabled {
                        ZenithRow(strings.confirmationPreviewDurationLabel, selection: $previewDuration) {
                            ForEach(ScreenshotSupport.confirmationPreviewDurations, id: \.self) { seconds in
                                if seconds == 0 {
                                    Text(strings.confirmationPreviewUntilDismissed).tag(0)
                                } else {
                                    Text(String(format: strings.delaySecondsFormat, seconds)).tag(seconds)
                                }
                            }
                        }
                    }
                }
                ZenithRow(strings.previewPositionLabel, selection: $previewPositionRaw) {
                    Text(strings.previewPositionAutomatic)
                        .tag(ScreenshotSupport.QuickPreviewPosition.automatic.rawValue)
                    Text(strings.previewPositionTopLeft)
                        .tag(ScreenshotSupport.QuickPreviewPosition.topLeft.rawValue)
                    Text(strings.previewPositionTopRight)
                        .tag(ScreenshotSupport.QuickPreviewPosition.topRight.rawValue)
                    Text(strings.previewPositionBottomLeft)
                        .tag(ScreenshotSupport.QuickPreviewPosition.bottomLeft.rawValue)
                    Text(strings.previewPositionBottomRight)
                        .tag(ScreenshotSupport.QuickPreviewPosition.bottomRight.rawValue)
                }
                ZenithRow(strings.previewFocusToggle, isOn: $previewTakesFocus, info: strings.previewFocusCaption)
            }
        }
    }

    /// The after-capture action can copy too, so the toggle reads on while
    /// either one copies. Turning it off clears both. Otherwise captures keep
    /// reaching the clipboard while the switch shows off.
    private var autoCopyBinding: Binding<Bool> {
        Binding {
            copyToClipboard || defaultAction.copiesToClipboard
        } set: { isOn in
            copyToClipboard = isOn
            if !isOn { defaultActionRaw = defaultAction.withoutCopy.rawValue }
        }
    }

    private var defaultAction: ScreenshotDefaultAction {
        ScreenshotDefaultAction(rawValue: defaultActionRaw) ?? .none
    }

    private var shelfIsOn: Bool {
        shelfEnabled && shelfAvailable
    }

    /// Reads off while the shelf is off, since no capture reaches it then.
    /// The choice itself is kept for when the shelf comes back.
    private var addToShelfBinding: Binding<Bool> {
        Binding {
            addToShelf && shelfIsOn
        } set: { isOn in
            addToShelf = isOn
        }
    }

    private var usesAutomaticConfirmationPreview: Bool {
        guard let action = ScreenshotDefaultAction(rawValue: defaultActionRaw) else { return false }
        switch action {
        case .save, .saveAndCopy, .copy: return true
        case .none, .edit: return false
        }
    }

    // MARK: Saving

    private var saving: some View {
        ZenithSection(text.screenshotSaving) {
            ZenithFolderRow(title: strings.folderLabel, chooseTitle: strings.folderChoose, path: $saveFolder)
            ZenithRow(strings.subfolderLabel, info: strings.subfolderCaption) {
                HStack(spacing: 8) {
                    if !saveSubfolder.isEmpty {
                        Text(ScreenshotSupport.expandSaveSubfolder(saveSubfolder, date: Date()))
                            .font(ZenithType.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    TextField(strings.subfolderLabel, text: $saveSubfolder)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
            }
            ZenithRow(strings.fileNamePatternLabel, info: strings.fileNamePatternCaption) {
                HStack(spacing: 8) {
                    Text(fileNamePreview)
                        .font(ZenithType.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    TextField(strings.fileNamePatternLabel, text: $fileNamePattern)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
            }
            if ScreenshotSupport.fileNamePatternUsesNumber(fileNamePattern) {
                ZenithRow(strings.fileNumberStartLabel,
                          info: String(format: strings.fileNumberNextFormat, nextNumber)) {
                    HStack(spacing: 8) {
                        TextField(strings.fileNumberStartLabel, value: $numberStart,
                                  formatter: Self.numberFieldFormatter)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Stepper(strings.fileNumberStartLabel, value: $numberStart, in: 0...999_999)
                            .labelsHidden()
                        Button(strings.fileNumberResetButton) { nextNumber = numberStart }
                    }
                }
                .onChange(of: numberStart) { _, newValue in nextNumber = newValue }
            }
            ZenithRow(strings.downscaleToggle, isOn: $downscale, info: strings.downscaleCaption)
        }
    }

    private static let numberFieldFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 999_999
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private var fileNamePreview: String {
        let trimmed = fileNamePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date())
        }
        return ScreenshotSupport.expandFileNamePattern(trimmed, date: Date(), number: nextNumber) + ".png"
    }

    // MARK: Sharing

    private var sharingSection: some View {
        ZenithSection(strings.shareSectionTitle) {
            ZenithRow(strings.shareEnabledToggle, isOn: $sharingEnabled,
                      info: sharingEnabled ? strings.shareCaption : nil)
                .onChange(of: sharingEnabled) { _, _ in service.syncWithPreferences() }
            if sharingEnabled {
                ZenithShortcutSwitchRows(title: strings.uploadLastCapture, role: .screenshotUpload,
                                         isOn: $uploadShortcutEnabled,
                                         failed: service.uploadShortcutRegistrationFailed) {
                    service.syncWithPreferences()
                }
                ZenithRow(strings.uploadExpiry, selection: $uploadDuration) {
                    ForEach(ScreenshotShareDuration.allCases) { duration in
                        Text(duration.title(strings)).tag(duration.rawValue)
                    }
                }
            }
            ZenithRow(strings.sharePrivacyButton, navigate: { showingSharePrivacy = true })
            if !sharing.records.isEmpty {
                ZenithRow(strings.sharedLinksTitle, value: "\(sharing.records.count)",
                          navigate: { showingSharedLinks = true })
            }
        }
    }
}

struct ScreenshotSharePrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    let actionTitle: String?
    let onAction: (() -> Void)?

    init(actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(strings.sharePrivacyTitle, systemImage: "hand.raised")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(actionTitle ?? strings.done) {
                    dismiss()
                    guard let onAction else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onAction()
                    }
                }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    privacyParagraph(symbol: "photo", text: strings.sharePrivacyData)
                    privacyParagraph(symbol: "externaldrive", text: strings.sharePrivacyStorage)
                    privacyParagraph(symbol: "person.2", text: strings.sharePrivacyAccess)
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

private struct ScreenshotSharedLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var sharing = ScreenshotShareService.shared
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

    private func linkRow(_ record: ScreenshotShareRecord) -> some View {
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
                copy(record.url)
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

    private func copy(_ url: URL) {
        sharing.copy(url)
    }

    private func delete(_ record: ScreenshotShareRecord) {
        deletingID = record.id
        Task {
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

struct ScreenshotDefaultActionPicker: View {
    let strings: ScreenshotFeatureStrings
    @Binding var selection: String

    var body: some View {
        Picker(strings.defaultActionLabel, selection: $selection) {
            ScreenshotDefaultActionOptions(strings: strings)
        }
    }
}

/// The after-capture actions, tagged with their stored values.
struct ScreenshotDefaultActionOptions: View {
    let strings: ScreenshotFeatureStrings

    var body: some View {
        Text(strings.defaultActionNone).tag(ScreenshotDefaultAction.none.rawValue)
        Text(strings.saveButton).tag(ScreenshotDefaultAction.save.rawValue)
        Text(strings.defaultActionSaveAndCopy).tag(ScreenshotDefaultAction.saveAndCopy.rawValue)
        Text(strings.copyButton).tag(ScreenshotDefaultAction.copy.rawValue)
        Text(strings.editButton).tag(ScreenshotDefaultAction.edit.rawValue)
    }
}
