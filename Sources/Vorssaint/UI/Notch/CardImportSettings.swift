// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the Card Import section's options in Settings → Dynamic
/// Island → Content: whether cards are detected, the base folder imports go
/// into, and the defaults each card's page starts from.
struct CardImportSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchCardImportEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchCardImportFolder) private var folder = ""
    @AppStorage(DefaultsKey.notchCardImportSplitRaw) private var splitRaw = true
    @AppStorage(DefaultsKey.notchCardImportVideoFolder) private var videoFolder = true
    @AppStorage(DefaultsKey.notchCardImportSkipImported) private var skipImported = true
    @AppStorage(DefaultsKey.notchCardImportRename) private var rename = CardRenamePattern.original.rawValue
    @AppStorage(DefaultsKey.notchCardImportEject) private var eject = true

    private var text: ZenithCardImportStrings { ZenithStrings.cardImport(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSwitchRow(text.detect, isOn: $enabled) {
                label(text.detect, caption: text.detectCaption)
            }
            Divider().padding(.vertical, 2)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.folder)
                    Text(CardImportDestination.stored(CardImportDestination.baseURL(stored: folder)))
                        .font(ZenithType.mono(11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 12)
                if !folder.isEmpty {
                    Button(text.reset) { folder = "" }
                }
                Button(text.choose, action: chooseFolder)
            }
            Text(text.eventCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().padding(.vertical, 2)
            Text(text.defaults).font(ZenithType.emphasis)
            ZenithSwitchRow(text.separateRaw, isOn: $splitRaw) { Text(text.separateRaw) }
            ZenithSwitchRow(text.videoFolder, isOn: $videoFolder) { Text(text.videoFolder) }
            ZenithSwitchRow(text.skipImported, isOn: $skipImported) {
                label(text.skipImported, caption: text.skipCaption)
            }
            HStack(alignment: .top, spacing: 12) {
                label(text.rename, caption: text.renameCaption)
                Spacer(minLength: 12)
                Picker(text.rename, selection: $rename) {
                    Text(text.renameOriginal).tag(CardRenamePattern.original.rawValue)
                    Text(text.renameDate).tag(CardRenamePattern.dateSequence.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            ZenithSwitchRow(text.ejectWhenDone, isOn: $eject) { Text(text.ejectWhenDone) }
            Divider().padding(.vertical, 2)
            CardBackupSettingsView()
                .zenithSectionAnchor(.zenithCardBackup) // Settings search lands here
        }
        .zenithSectionAnchor(.zenithCardImport) // Settings search lands here
        .onChange(of: enabled) { _, _ in
            NotchService.shared.syncWithPreferences()
            ZenithNoticeCenter.shared.syncWithPreferences()
        }
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text.choose.replacingOccurrences(of: "…", with: "")
        let current = CardImportDestination.baseURL(stored: folder)
        panel.directoryURL = FileManager.default.fileExists(atPath: current.path) ? current
            : current.deletingLastPathComponent()
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folder = CardImportDestination.stored(url)
    }
}
