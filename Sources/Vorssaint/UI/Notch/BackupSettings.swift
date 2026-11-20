// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the backup part of the Card Import options in Settings →
/// Dynamic Island → Content: up to two backup folders (each a drive, known
/// again wherever it mounts, and a path on it), whether a backup starts by
/// itself and is verified, and the reminder's delay.
struct CardBackupSettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var backups = CardBackupService.shared
    @AppStorage(DefaultsKey.notchCardBackupDestinations) private var stored = ""
    @AppStorage(DefaultsKey.notchCardBackupAutomatic) private var automatic = false
    @AppStorage(DefaultsKey.notchCardBackupVerify) private var verify = true
    @AppStorage(DefaultsKey.notchCardBackupReminderHours) private var reminder = 24
    @State private var problem: String?

    private var text: ZenithCardBackupStrings { ZenithStrings.cardBackup(l10n.language) }

    var body: some View {
        let list = CardBackupDestinations.decode(stored)
        VStack(alignment: .leading, spacing: 10) {
            Text(text.settingsTitle).font(ZenithType.emphasis)
            Text(text.settingsCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if list.isEmpty {
                Text(text.noDestinations).foregroundStyle(.secondary)
            }
            ForEach(list) { destination in
                destinationRow(destination)
            }
            HStack(spacing: 10) {
                Button(text.addDestination, action: choose)
                    .disabled(list.count >= CardBackupDestinations.maximum)
                if let problem {
                    Text(problem).font(ZenithType.caption).foregroundStyle(ZenithStatus.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .animation(ZenithMotion.respecting(.easeOut(duration: 0.2)), value: problem)
            ZenithSwitchRow(text.automatic, isOn: $automatic) {
                label(text.automatic, caption: text.automaticCaption)
            }
            ZenithSwitchRow(text.verifyAfter, isOn: $verify) {
                label(text.verifyAfter, caption: text.verifyCaption)
            }
            HStack(alignment: .top, spacing: 12) {
                label(text.reminder, caption: text.reminderCaption)
                Spacer(minLength: 12)
                Picker(text.reminder, selection: $reminder) {
                    ForEach(CardBackupSettings.reminderChoices, id: \.self) { hours in
                        Text(hours == 0 ? text.reminderOff
                             : CardImportFormat.filling(text.hours, CardImportFormat.count(hours, locale: l10n.language.formattingLocale())))
                            .tag(hours)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
        // Which drives are here now, also while card detection is off.
        .onAppear { backups.settingsChanged() }
        .onChange(of: reminder) { _, _ in backups.settingsChanged() }
        .onChange(of: automatic) { _, _ in backups.settingsChanged() }
    }

    private func destinationRow(_ destination: CardBackupDestination) -> some View {
        let mounted = backups.isMounted(destination)
        return HStack(spacing: 10) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.volumeName).lineLimit(1)
                Text(destination.path.isEmpty ? "/" : destination.path)
                    .font(ZenithType.mono(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            HStack(spacing: 5) {
                Circle().fill(mounted ? ZenithStatus.success : Color.secondary.opacity(0.6)).frame(width: 6, height: 6)
                Text(mounted ? text.connected : text.notConnected)
                    .font(ZenithType.caption).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .animation(ZenithMotion.respecting(.easeOut(duration: 0.2)), value: mounted)
            Button(text.remove) { backups.removeDestination(destination.id) }
        }
        .accessibilityElement(children: .combine)
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text.addDestination.replacingOccurrences(of: "…", with: "")
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch backups.addDestination(folder: url) {
        case .added: problem = nil
        case .sameDrive: problem = text.sameDrive
        case .card: problem = text.cardChosen
        case .full, .unreadable: NSSound.beep()
        }
    }
}
