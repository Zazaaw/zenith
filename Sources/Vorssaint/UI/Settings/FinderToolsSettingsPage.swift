// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Finder Tools, built with the Settings kit. The
/// old Cut & Paste page plus what else works inside Finder: cut and paste
/// (and pasting a copied image as a file), the rename key, and the disk
/// image installer's remembered choices. No master switch: each tool keeps
/// its own, at the top of its section.
struct FinderToolsSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var service = FinderCutPaste.shared
    @AppStorage(DefaultsKey.finderCutPasteEnabled) private var enabled = false
    @AppStorage(DefaultsKey.finderCutPasteShowHUD) private var showHUD = true
    @AppStorage(DefaultsKey.finderPasteImageAsFile) private var pasteImageAsFile = false
    @AppStorage(DefaultsKey.finderRenameEnabled) private var renameEnabled = false
    @AppStorage(DefaultsKey.finderRenameShortcut) private var renameShortcutRaw =
        GlobalShortcut.finderRenameDefault.storageValue
    @AppStorage(DefaultsKey.diskImageInstallerTrashesDownload) private var trashesDownload = true
    @AppStorage(DefaultsKey.diskImageInstallerRevealsApp) private var revealsApp = false
    @AppStorage(DefaultsKey.diskImageInstallerUseUserApplications) private var userApplications = false
    @State private var renameError: String?
    @State private var recordingRename = false
    @State private var pendingRenameTakeOver: GlobalShortcut?

    private let page = ZenithStrings.everyday(.enUS)

    private var renameText: FinderRenameFeatureStrings {
        FeatureStrings.finderRename(l10n.language)
    }

    private var renameShortcut: GlobalShortcut {
        GlobalShortcut(storageValue: renameShortcutRaw) ?? .finderRenameDefault
    }

    private var needsAccessibility: Bool {
        (AppFeature.finderCutPaste.isAvailable && (enabled || pasteImageAsFile))
            || (AppFeature.finderRename.isAvailable && renameEnabled)
    }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: page.finderTitle, subtitle: page.finderSubtitle, chips: chips,
                           animation: .finderTools)
                if needsAccessibility, !permissions.accessibility {
                    ZenithPermissionSection(kind: .accessibility,
                                            note: AppFeature.finderCutPaste.isAvailable && enabled
                                                ? l10n.s.cutPasteAutomationNote : nil)
                }
                ZenithCutPastePreviewCard()
                if AppFeature.finderCutPaste.isAvailable {
                    cutPasteSection
                    howSection
                }
                if AppFeature.finderRename.isAvailable {
                    renameSection
                }
                if AppFeature.diskImageInstaller.isAvailable {
                    diskImageSection
                }
            }
        }
        .onChange(of: l10n.language) { _, _ in renameError = nil }
    }

    private var chips: [ZenithChip] {
        var chips: [ZenithChip] = []
        if AppFeature.finderCutPaste.isAvailable, enabled {
            chips.append(ZenithChip("⌘X  ⌘V", dot: service.isRunning ? ZenithStatus.success : nil))
        }
        if AppFeature.finderRename.isAvailable, renameEnabled {
            chips.append(ZenithChip(renameShortcut.displayString))
        }
        if chips.isEmpty { chips.append(ZenithChip(page.finderReady)) }
        return chips
    }

    // MARK: Cut and paste

    private var cutPasteSection: some View {
        ZenithSection(page.finderCutPaste, anchor: .finderCutPaste) {
            ZenithRow(l10n.s.cutPasteEnable, isOn: $enabled, info: l10n.s.cutPasteEnableCaption)
                .onChange(of: enabled) { _, _ in FinderCutPaste.shared.syncWithPreferences() }
            if enabled {
                ZenithRow(l10n.s.cutPasteShowHUD, isOn: $showHUD, info: l10n.s.cutPasteShowHUDCaption)
                    .onChange(of: showHUD) { _, _ in FinderCutPaste.shared.syncWithPreferences() }
            }
            if enabled, service.isRunning {
                ZenithRowStatus(text: l10n.s.cutPasteActiveNow)
            }
            ZenithRow(FeatureStrings.clipboard(l10n.language).pasteImageAsFile, isOn: $pasteImageAsFile,
                      info: FeatureStrings.clipboard(l10n.language).pasteImageAsFileCaption)
                .onChange(of: pasteImageAsFile) { _, _ in FinderCutPaste.shared.syncWithPreferences() }
        }
    }

    private var howSection: some View {
        ZenithSection(l10n.s.cutPasteHowTitle, footer: l10n.s.cutPasteTextNote) {
            howRow(keys: ["⌘", "X"], text: l10n.s.cutPasteStep1)
            howRow(keys: ["⌘", "V"], text: l10n.s.cutPasteStep2)
        }
    }

    private func howRow(keys: [String], text: String) -> some View {
        HStack(spacing: 10) {
            ShortcutCaps(keys: keys)
                .frame(width: 56, alignment: .leading)
            Text(text)
                .font(ZenithType.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rename

    private var renameSection: some View {
        ZenithSection(page.finderRename, anchor: .finderRename) {
            ZenithRow(renameText.enableLabel, isOn: $renameEnabled, info: renameText.caption)
                .onChange(of: renameEnabled) { _, _ in FinderRenameService.shared.syncWithPreferences() }
            ZenithRow(renameText.shortcutLabel,
                      essential: recordingRename && renameError == nil
                        ? ShortcutRecordingCaption.text(l10n.s, canClear: false) : nil,
                      warning: renameError) {
                HStack(spacing: 8) {
                    ShortcutRecorderButton(
                        shortcut: pendingRenameTakeOver ?? renameShortcut,
                        isEnabled: renameEnabled,
                        waitingTitle: l10n.s.shortcutPressKeys,
                        notCapturedAction: { renameError = l10n.s.shortcutNotCaptured },
                        recordingChanged: { recording in
                            recordingRename = recording
                            if recording {
                                renameError = nil
                                pendingRenameTakeOver = nil
                            }
                        },
                        invalidAction: { renameError = l10n.s.shortcutInvalid },
                        captureAction: saveRenameShortcut
                    )
                    .frame(width: 108)
                    .disabled(!renameEnabled)
                    Button(l10n.s.shortcutReset, action: resetRenameShortcut)
                        .disabled(!renameEnabled || renameShortcut == .finderRenameDefault)
                }
            }
            if let pendingRenameTakeOver {
                SystemShortcutTakeOverOffer(
                    shortcut: pendingRenameTakeOver,
                    onAccept: {
                        renameShortcutRaw = pendingRenameTakeOver.storageValue
                        SystemShortcutTakeover.setTakeOver(DefaultsKey.finderRenameShortcut, true)
                        self.pendingRenameTakeOver = nil
                        FinderRenameService.shared.syncWithPreferences()
                    },
                    onDismiss: {
                        self.pendingRenameTakeOver = nil
                        renameError = String(format: l10n.s.shortcutConflictFormat, "macOS")
                    }
                )
                .padding(.vertical, 8)
            }
        }
    }

    private func resetRenameShortcut() {
        renameShortcutRaw = GlobalShortcut.finderRenameDefault.storageValue
        renameError = nil
        pendingRenameTakeOver = nil
        SystemShortcutTakeover.setTakeOver(DefaultsKey.finderRenameShortcut, false)
        FinderRenameService.shared.syncWithPreferences()
    }

    private func saveRenameShortcut(_ shortcut: GlobalShortcut) {
        if let conflict = GlobalShortcutRole.conflict(for: shortcut, excluding: .finderRename) {
            renameError = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
            return
        }
        if let conflict = WindowLayoutService.shared.shortcutConflictTitle(shortcut) {
            renameError = String(format: l10n.s.shortcutConflictFormat, conflict)
            return
        }
        // The offer is the last word on a combination: every other check has
        // already passed, so accepting it writes exactly what a save writes.
        switch SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: SystemShortcutTakeover.conflictsWithMacOS(shortcut, for: .finderRename),
            takenOver: SystemShortcutTakeover.isTakenOver(DefaultsKey.finderRenameShortcut),
            current: GlobalShortcut(storageValue: renameShortcutRaw)) {
        case .offer:
            pendingRenameTakeOver = shortcut
            renameError = nil
            return
        case .save(let clearTakeOver):
            renameShortcutRaw = shortcut.storageValue
            renameError = nil
            if clearTakeOver { SystemShortcutTakeover.setTakeOver(DefaultsKey.finderRenameShortcut, false) }
        }
        FinderRenameService.shared.syncWithPreferences()
    }

    // MARK: Disk images

    /// The choices the installer's prompt starts with; ticking them there
    /// writes the same keys, so both always agree.
    private var diskImageSection: some View {
        let text = FeatureStrings.diskImageInstaller(l10n.language)
        return ZenithSection(page.finderDiskImages, anchor: .diskImageInstaller, footer: page.finderDiskImagesFooter) {
            ZenithRow(text.trashDownloadOption, isOn: $trashesDownload)
            ZenithRow(text.revealAppOption, isOn: $revealsApp)
            ZenithRow(text.useUserApplications, isOn: $userApplications)
        }
    }
}
