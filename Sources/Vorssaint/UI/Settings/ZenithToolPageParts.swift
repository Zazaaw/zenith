// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the parts the sound and capture pages share, in the kit's
// style (docs/SETTINGS-KIT.md): the screen picture of a tool on the stage, a
// shortcut as a switch with its recorder under it, a folder to save into,
// and the page's frame.

/// A feature page's column: the kit's width and padding in a scroll view.
struct ZenithToolPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(22)
        }
    }
}

/// A tool's screen picture on the stage, with the scenes as pills when there
/// are several (Screenshot and Scrolling, the switcher and the priority list).
struct ZenithScenePreview: View {
    let scenes: [ZenithScreenScene]
    @Binding var selection: Int

    init(scenes: [ZenithScreenScene], selection: Binding<Int> = .constant(0)) {
        self.scenes = scenes
        _selection = selection
    }

    var body: some View {
        let shown = scenes.indices.contains(selection) ? scenes[selection] : scenes.first ?? .look
        ZenithSettingsPreviewCard(id: "scene.\(shown.rawValue)", caption: shown.text.caption,
                                  states: scenes.count > 1 ? scenes.map(\.text.state) : [],
                                  selection: scenes.count > 1 ? $selection : nil,
                                  highlight: shown.text.part) {
            ZenithScreenPicture(scene: shown)
        }
    }
}

/// A global shortcut as two rows: the switch that turns it on (its title
/// names the action) and the recorder under it, with the warning when the
/// shortcut can't be registered.
struct ZenithShortcutSwitchRows: View {
    let title: String
    var info: String?
    let role: GlobalShortcutRole
    @Binding var isOn: Bool
    var failed = false
    var additionalConflict: (GlobalShortcut) -> String? = { _ in nil }
    let sync: () -> Void
    @ObservedObject private var l10n = L10n.shared

    // Two rows of the section it sits in: its own stack draws them, with the
    // hairline between (a section pads and divides only its direct children).
    var body: some View {
        ZenithRowStack {
            ZenithRow(title, isOn: $isOn, info: info, warning: isOn && failed ? l10n.s.shortcutUnavailable : nil)
                .onChange(of: isOn) { _, _ in sync() }
            ShortcutPreferenceRow(role: role, isEnabled: isOn, additionalConflict: additionalConflict, onChange: sync)
                .padding(.vertical, 9)
                .disabled(!isOn)
                .opacity(isOn ? 1 : 0.55)
        }
        .zenithFullBleed()
    }
}

/// The folder a tool saves into: its name, Choose…, and a reset back to the
/// Desktop while another folder is set.
struct ZenithFolderRow: View {
    let title: String
    let chooseTitle: String
    @Binding var path: String
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ZenithRow(title) {
            HStack(spacing: 8) {
                Text(folderName)
                    .font(ZenithType.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !path.isEmpty {
                    Button { path = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                    .screenshotSafeHelp(l10n.s.shortcutReset)
                    .accessibilityLabel(l10n.s.shortcutReset)
                }
                Button(chooseTitle, action: choose)
            }
        }
    }

    private var folderName: String {
        let manager = FileManager.default
        if !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if manager.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
                return manager.displayName(atPath: expanded)
            }
        }
        let desktop = manager.urls(for: .desktopDirectory, in: .userDomainMask).first
        return desktop.map { manager.displayName(atPath: $0.path) } ?? "Desktop"
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

/// A shortcut's state for a hero chip: its keys while it is on.
enum ZenithShortcutChip {
    static func chip(_ role: GlobalShortcutRole, enabled: Bool) -> ZenithChip {
        let text = ZenithStrings.soundCapture(.enUS)
        guard enabled, let shortcut = role.assignedShortcut() else { return ZenithChip(text.noShortcut) }
        return ZenithChip(shortcut.displayString)
    }
}
