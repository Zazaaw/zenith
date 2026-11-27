// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: connecting Claude Code's hooks, in the AI page's settings.
/// Connect shows exactly what will be merged into `~/.claude/settings.json`
/// before anything is written; Disconnect takes only Zenith's handlers out.
/// The heading is drawn here and the switch is a `ZenithSwitchRow`, so
/// Settings search, which indexes upstream's catalogs, stays as it was.
struct NotchAgentsClaudeHooksSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ClaudeHooksService.shared
    // Zenith fork: the old sound switch, read only to keep its "off".
    @AppStorage(DefaultsKey.notchAgentsClaudeSound) private var sound = true
    @AppStorage(DefaultsKey.notchAgentsClaudeChime) private var chime = ClaudeChimeMode.soundAndIsland.rawValue
    @State private var state = ClaudeHooksSettings.State.missing
    @State private var changed = false
    @State private var editFailed = false

    private var text: ZenithClaudeHooksStrings { ZenithStrings.claudeHooks(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The section's title is the Agents page's (ZenithSection).
            Text(text.caption).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            status
            HStack(spacing: 8) {
                switch state {
                case .connected:
                    Button(text.disconnect, role: .destructive, action: disconnect)
                case .outdated:
                    Button(text.connect, action: confirmConnect)
                    Button(text.disconnect, role: .destructive, action: disconnect)
                case .missing:
                    Button(text.connect, action: confirmConnect)
                case .unreadable:
                    EmptyView()
                }
            }
            if changed {
                Text(text.newSessions).font(.caption).foregroundStyle(.secondary)
            }
            if editFailed {
                Text(text.editFailed).font(.caption).foregroundStyle(ZenithStatus.error)
            }
            chimePicker
            Text(text.privacy).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .zenithSectionAnchor(.zenithClaudeHooks) // Settings search lands here
        .onAppear(perform: refresh)
    }

    /// Off, or the sound with the island's burst: never the sound alone.
    private var chimePicker: some View {
        let words = ZenithStrings.claudeChime(l10n.language)
        let selection = Binding<ClaudeChimeMode>(
            get: { _ = (sound, chime); return ClaudeHooksSupport.chime() },
            set: { ClaudeHooksSupport.setChime($0) })
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(words.alert)
                Text(words.alertCaption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Picker(words.alert, selection: selection) {
                Text(words.off).tag(ClaudeChimeMode.off)
                Text(words.soundAndIsland).tag(ClaudeChimeMode.soundAndIsland)
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch state {
            case .connected:
                Label(text.connected, systemImage: "checkmark.circle.fill").foregroundStyle(ZenithStatus.success)
            case .outdated:
                Label(text.outdated, systemImage: "exclamationmark.circle").foregroundStyle(ZenithStatus.warning)
            case .missing:
                Label(text.notConnected, systemImage: "circle.dashed").foregroundStyle(.secondary)
            case .unreadable:
                Label(text.unreadable, systemImage: "exclamationmark.triangle").foregroundStyle(ZenithStatus.warning)
            }
            // Relative, so it reads again now and then while the page shows.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(lastEventText(now: context.date)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func lastEventText(now: Date) -> String {
        guard let date = service.lastEvent else { return text.noEvents }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = l10n.language.formattingLocale()
        formatter.unitsStyle = .short
        return text.lastEvent(formatter.localizedString(for: min(date, now), relativeTo: now))
    }

    private func refresh() { state = ClaudeHooksService.settingsState() }

    /// Shows the exact JSON before anything is written.
    private func confirmConnect() {
        guard let command = ClaudeHooksService.command else { return }
        let alert = NSAlert()
        alert.messageText = text.confirmTitle
        alert.informativeText = text.confirmMessage
        alert.addButton(withTitle: text.add)
        alert.addButton(withTitle: text.cancel)
        alert.accessoryView = Self.codeView(ClaudeHooksSettings.fragment(command: command))
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            apply(ClaudeHooksService.connect())
            NotchService.shared.syncWithPreferences()
        }
        if let window = NSApp.keyWindow { alert.beginSheetModal(for: window, completionHandler: finish) }
        else { finish(alert.runModal()) }
    }

    private func disconnect() { apply(ClaudeHooksService.disconnect()) }

    private func apply(_ result: ClaudeHooksSettings.EditResult) {
        editFailed = result == .failed || result == .unreadable
        if result == .changed { changed = true }
        refresh()
    }

    /// The JSON in a scrolling, selectable monospaced box.
    private static func codeView(_ code: String) -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 260))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true
        let view = NSTextView(frame: scroll.bounds)
        view.string = code
        view.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        view.isEditable = false
        view.isSelectable = true
        view.textContainerInset = NSSize(width: 6, height: 6)
        view.isHorizontallyResizable = true
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                   height: CGFloat.greatestFiniteMagnitude)
        view.autoresizingMask = [.height]
        scroll.documentView = view
        return scroll
    }
}
