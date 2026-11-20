// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the Exports card in Settings → Dynamic Island → Activity:
/// the switch, the watched folders (added through an open panel, each with
/// its own switch), the size a file needs, the sound, and the notification.
struct ExportTrackerSettings: View {
    typealias Support = ExportTrackerSupport

    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchExportTracker) private var enabled = false
    @AppStorage(DefaultsKey.notchExportMinimum) private var minimum = ExportTrackerSupport.defaultMinimum
    @AppStorage(DefaultsKey.notchExportSound) private var sound = true
    @AppStorage(DefaultsKey.notchExportNotify) private var notify = true
    @State private var folders: [Support.Folder] = []

    private var text: ZenithExportTrackerStrings { ZenithStrings.exportTracker(l10n.language) }
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    var body: some View {
        // A heading drawn here rather than through SettingsCard's title, whose
        // labels Settings search indexes from upstream's catalogs.
        VStack(alignment: .leading, spacing: 10) {
            Text(text.section)
                .font(ZenithType.sectionTitle)
                .tracking(ZenithType.sectionTitleTracking)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)
            SettingsCard {
                ZenithSwitchRow(text.toggle, isOn: $enabled) {
                    label(text.toggle, caption: text.toggleCaption)
                }
                if enabled { options }
            }
        }
        .zenithSectionAnchor(.zenithExportTracker, cornerRadius: ZenithRadius.panel + 6, inset: 6) // Settings search lands here
        .onAppear { folders = Support.folders() }
        .onChange(of: enabled) { _, on in
            if on, notify { Notifier.requestPermission() }
            sync()
        }
        .onChange(of: minimum) { _, _ in sync() }
        .onChange(of: notify) { _, on in if on, enabled { Notifier.requestPermission() } }
    }

    @ViewBuilder private var options: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.folders)
            VStack(spacing: 0) {
                ForEach(folders) { folder in
                    folderRow(folder)
                    if folder.id != folders.last?.id { Divider().padding(.leading, 28) }
                }
            }
            Button(text.addFolder, action: addFolders)
                .padding(.top, 2)
            Text(text.foldersCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        HStack(spacing: 12) {
            Text(text.minimumSize)
            Spacer(minLength: 12)
            Picker(text.minimumSize, selection: $minimum) {
                ForEach(Support.minimumChoices, id: \.self) { megabytes in
                    Text(Support.filling(text.megabytes, count: megabytes)).tag(megabytes)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        ZenithSwitchRow(text.sound, isOn: $sound) { Text(text.sound) }
        ZenithSwitchRow(text.notify, isOn: $notify) {
            label(text.notify, caption: text.notifyCaption)
        }
    }

    /// The folder's name as Finder shows it, its path below, its switch and a way out.
    private func folderRow(_ folder: Support.Folder) -> some View {
        let path = Support.expanded(folder.entry, home: home)
        let exists = FileManager.default.fileExists(atPath: path)
        return HStack(spacing: 8) {
            Image(systemName: exists ? "folder" : "questionmark.folder")
                .foregroundStyle(exists ? Color.secondary : ZenithStatus.warning)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(exists ? FileManager.default.displayName(atPath: path) : (path as NSString).lastPathComponent)
                    .lineLimit(1)
                Text(exists ? folder.entry : text.missing + " · " + folder.entry)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button { remove(folder) } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(text.removeFolder)
            .accessibilityLabel(text.removeFolder + ", " + folder.entry)
            Toggle(folder.entry, isOn: binding(folder))
                .labelsHidden()
                .toggleStyle(ZenithSwitchStyle())
        }
        .padding(.vertical, 5)
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func binding(_ folder: Support.Folder) -> Binding<Bool> {
        Binding(get: { folders.first { $0.id == folder.id }?.on ?? false }, set: { on in
            guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
            folders[index].on = on
            store()
        })
    }

    private func remove(_ folder: Support.Folder) {
        folders.removeAll { $0.id == folder.id }
        store()
    }

    private func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = text.choose
        panel.directoryURL = URL(fileURLWithPath: Support.expanded("~/Movies", home: home), isDirectory: true)
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            for url in panel.urls {
                let entry = Support.entry(forPath: url.path, home: home)
                if let index = folders.firstIndex(where: { $0.entry == entry }) {
                    folders[index].on = true
                } else {
                    folders.append(Support.Folder(entry: entry, on: true))
                }
            }
            store()
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: finish) }
        else { finish(panel.runModal()) }
    }

    private func store() {
        let defaults = UserDefaults.standard
        defaults.set(folders.map(\.entry), forKey: DefaultsKey.notchExportFolders)
        defaults.set(folders.filter { !$0.on }.map(\.entry), forKey: DefaultsKey.notchExportFoldersOff)
        sync()
    }

    private func sync() { NotchService.shared.syncWithPreferences() }
}
