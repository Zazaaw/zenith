// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the terminal readout's switch in the Lock Screen card, then
/// its lines (each with a switch and a place in the order) and whether
/// project names may show.
struct NotchLockScreenTerminalSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLockScreenTerminal) private var enabled = false
    @AppStorage(DefaultsKey.notchLockScreenTerminalLines) private var stored = NotchLockScreenTerminalSelection.defaultValue
    @AppStorage(DefaultsKey.notchLockScreenTerminalProjects) private var showsProjects = false

    private var selection: NotchLockScreenTerminalSelection { NotchLockScreenTerminalSelection(stored: stored) }

    // Plain toggles rather than SettingsRow, like the lock screen items above.
    var body: some View {
        let text = ZenithStrings.lockScreenTerminal(l10n.language)
        Toggle(isOn: $enabled) {
            Label(text.title, systemImage: "terminal")
                .foregroundStyle(.secondary)
        }
        .toggleStyle(TrailingSwitchToggleStyle())
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
                Toggle(isOn: $showsProjects) {
                    Text(text.showProjects).foregroundStyle(.secondary)
                }
                .toggleStyle(TrailingSwitchToggleStyle())
                .padding(.top, 4)
                Text(text.showProjectsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40 + 28)
            .padding(.bottom, 2)
        }
    }

    private func lineRow(_ entry: NotchLockScreenTerminalSelection.Entry,
                         text: ZenithLockScreenTerminalStrings) -> some View {
        HStack(spacing: 4) {
            moveButton(entry.source, by: -1, symbol: "chevron.up", title: text.moveUp)
            moveButton(entry.source, by: 1, symbol: "chevron.down", title: text.moveDown)
            Toggle(isOn: Binding(get: { entry.isOn }, set: { isOn in
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
            .toggleStyle(TrailingSwitchToggleStyle())
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
