// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI
import SystemConfiguration

/// Zenith fork: the terminal readout's switch in the Lock Screen card, then
/// its lines (each with a switch and a place in the order), whether project
/// names may show, and the name in its title bar.
struct NotchLockScreenTerminalSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLockScreenTerminal) private var enabled = false
    @AppStorage(DefaultsKey.notchLockScreenTerminalLines) private var stored = NotchLockScreenTerminalSelection.defaultValue
    @AppStorage(DefaultsKey.notchLockScreenTerminalProjects) private var showsProjects = false
    @AppStorage(DefaultsKey.notchLockScreenTerminalTitle) private var storedTitle = ""
    /// The field's text, kept to one short line as it is typed.
    @State private var titleDraft = ""

    private var selection: NotchLockScreenTerminalSelection { NotchLockScreenTerminalSelection(stored: stored) }

    // Plain switch rows rather than SettingsRow, like the lock screen items above.
    var body: some View {
        let text = ZenithStrings.lockScreenTerminal(l10n.language)
        ZenithSwitchRow(text.title, isOn: $enabled) {
            Label(text.title, systemImage: "terminal")
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 40)
        .padding(.vertical, 2)
        if enabled {
            VStack(alignment: .leading, spacing: 6) {
                Text(text.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text.lines)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(selection.entries) { entry in
                    lineRow(entry, text: text)
                }
                ZenithSwitchRow(text.showProjects, isOn: $showsProjects) {
                    Text(text.showProjects).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                Text(text.showProjectsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                titleField(ZenithStrings.lockScreenTerminalTitle(l10n.language))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40 + 28)
            .padding(.bottom, 2)
        }
    }

    /// The title bar's name: empty keeps `zenith — status`, and a button
    /// fills in this Mac's name.
    private func titleField(_ text: ZenithLockScreenTerminalTitleStrings) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.windowTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            HStack(spacing: 6) {
                TextField(text.windowTitle, text: $titleDraft,
                          prompt: Text(NotchLockScreenTerminalSupport.defaultTitle))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: 260)
                Button {
                    if let title = NotchLockScreenTerminalSupport.computerTitle(Self.computerName()) {
                        titleDraft = title
                    }
                } label: {
                    Image(systemName: "desktopcomputer")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(text.useComputerName)
                .help(text.useComputerName)
            }
            Text(text.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { titleDraft = storedTitle }
        .onChange(of: titleDraft) { _, draft in
            // Cleaned as it is typed, so a pasted line break or a long name
            // never reaches the title bar; the readout trims the ends.
            let clean = NotchLockScreenTerminalSupport.titleInput(draft)
            if clean != draft { titleDraft = clean }
            if storedTitle != clean { storedTitle = clean }
        }
    }

    /// The name set in System Settings, General, Sharing; read when asked.
    private static func computerName() -> String? {
        SCDynamicStoreCopyComputerName(nil, nil) as String?
    }

    private func lineRow(_ entry: NotchLockScreenTerminalSelection.Entry,
                         text: ZenithLockScreenTerminalStrings) -> some View {
        HStack(spacing: 4) {
            moveButton(entry.source, by: -1, symbol: "chevron.up", title: text.moveUp)
            moveButton(entry.source, by: 1, symbol: "chevron.down", title: text.moveDown)
            ZenithSwitchRow(title(entry.source, text: text), isOn: Binding(get: { entry.isOn }, set: { isOn in
                var next = selection
                next.set(entry.source, isOn: isOn)
                stored = next.stored
            })) {
                HStack(spacing: 8) {
                    Text(title(entry.source, text: text))
                        .foregroundStyle(entry.isOn ? .primary : .secondary)
                    Text(entry.source.label)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 4)
        }
    }

    private func moveButton(_ source: NotchLockScreenTerminalSource, by offset: Int, symbol: String,
                            title: String) -> some View {
        Button {
            var next = selection
            next.move(source, by: offset)
            stored = next.stored
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!selection.canMove(source, by: offset))
        .accessibilityLabel(title)
        .help(title)
    }

    private func title(_ source: NotchLockScreenTerminalSource, text: ZenithLockScreenTerminalStrings) -> String {
        switch source {
        case .agents: return NotchModule.agents.title(l10n.language)
        case .waka: return NotchModule.wakatime.title(l10n.language)
        case .vercel: return NotchModule.vercel.title(l10n.language)
        case .ci: return text.checks
        case .sys: return text.system
        case .dl: return NotchModule.downloads.title(l10n.language)
        case .timer: return NotchModule.timer.title(l10n.language)
        }
    }
}
