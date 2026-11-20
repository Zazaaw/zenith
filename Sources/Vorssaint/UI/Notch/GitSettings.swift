// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the Git section's options in Settings → Dynamic Island →
/// Content: where the current repository comes from (the editor, terminal
/// commands), the pinned repositories (added through an open panel), the
/// background fetch and its interval, and the branch in the closed island.
/// Read-only by design, which the last line says.
struct GitSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchGitFromEditor) private var fromEditor = true
    @AppStorage(DefaultsKey.notchGitFromTerminal) private var fromTerminal = true
    @AppStorage(DefaultsKey.notchGitFetch) private var fetches = false
    @AppStorage(DefaultsKey.notchGitFetchMinutes) private var fetchMinutes = GitOptions.defaultFetchMinutes
    @AppStorage(DefaultsKey.notchGitIndicator) private var indicator = false
    @State private var pinned: [String] = []
    @State private var accessibility = AXIsProcessTrusted()

    private var text: ZenithGitStrings { ZenithStrings.git(l10n.language) }
    private let home = NSHomeDirectory()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSwitchRow(text.fromEditor, isOn: $fromEditor) {
                label(text.fromEditor, caption: text.fromEditorCaption)
            }
            if fromEditor && !accessibility {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ZenithStatus.warning)
                    Text(text.accessibilityOff).font(ZenithType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button(text.openAccessibility) { GitService.openAccessibilitySettings() }
                        .controlSize(.small)
                }
            }
            ZenithSwitchRow(text.fromTerminal, isOn: $fromTerminal) {
                label(text.fromTerminal, caption: text.fromTerminalCaption)
            }
            Divider().padding(.vertical, 2)
            pinnedList
            Divider().padding(.vertical, 2)
            ZenithSwitchRow(text.fetch, isOn: $fetches) {
                label(text.fetch, caption: text.fetchCaption)
            }
            if fetches {
                HStack(spacing: 12) {
                    Text(text.fetchEvery)
                    Spacer(minLength: 12)
                    Picker(text.fetchEvery, selection: $fetchMinutes) {
                        ForEach(GitOptions.fetchChoices, id: \.self) { minutes in
                            Text(text.minutes.replacingOccurrences(of: "%@", with: "\(minutes)")).tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            ZenithSwitchRow(text.indicator, isOn: $indicator) {
                label(text.indicator, caption: text.indicatorCaption)
            }
            Text(text.readOnly).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .zenithSectionAnchor(.zenithGit) // Settings search lands here
        .onAppear {
            pinned = GitOptions.pinnedEntries()
            accessibility = AXIsProcessTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibility = AXIsProcessTrusted()
        }
        .onChange(of: fromEditor) { _, _ in sync() }
        .onChange(of: fromTerminal) { _, _ in sync() }
        .onChange(of: fetches) { _, _ in sync() }
        .onChange(of: fetchMinutes) { _, _ in sync() }
        .onChange(of: indicator) { _, _ in sync() }
    }

    @ViewBuilder private var pinnedList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.pinned)
            if !pinned.isEmpty {
                VStack(spacing: 0) {
                    ForEach(pinned, id: \.self) { entry in
                        row(entry)
                        if entry != pinned.last { Divider().padding(.leading, 28) }
                    }
                }
            }
            Button(text.addRepository, action: addRepositories)
                .padding(.top, 2)
            Text(text.pinnedCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The folder's name, its path below (or why it is not a repository), and a way out.
    private func row(_ entry: String) -> some View {
        let path = GitOptions.expanded(entry, home: home)
        let exists = FileManager.default.fileExists(atPath: path)
        let repository = exists && GitRepoLocator.repository(at: path) != nil
        let note = !exists ? text.missing : !repository ? text.notRepository : nil
        return HStack(spacing: 8) {
            Image(systemName: repository ? GitSupportSymbols.branch : "questionmark.folder")
                .foregroundStyle(repository ? Color.secondary : ZenithStatus.warning)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text((path as NSString).lastPathComponent).lineLimit(1)
                Text(note.map { $0 + " · " + entry } ?? entry)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button { remove(entry) } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(text.removeRepository)
            .accessibilityLabel(text.removeRepository + ", " + entry)
        }
        .padding(.vertical, 5)
    }

    private func addRepositories() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = text.choose
        panel.directoryURL = URL(fileURLWithPath: home, isDirectory: true)
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            for url in panel.urls {
                // A folder inside a repository pins the repository itself.
                let root = GitRepoLocator.locate(from: url.path, allowsHome: true)?.root ?? url.path
                let entry = GitOptions.entry(forPath: root, home: home)
                if !pinned.contains(entry) { pinned.append(entry) }
            }
            store()
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: finish) }
        else { finish(panel.runModal()) }
    }

    private func remove(_ entry: String) {
        pinned.removeAll { $0 == entry }
        store()
    }

    private func store() {
        UserDefaults.standard.set(pinned, forKey: DefaultsKey.notchGitPinned)
        sync()
    }

    private func sync() {
        NotchService.shared.syncWithPreferences()
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
