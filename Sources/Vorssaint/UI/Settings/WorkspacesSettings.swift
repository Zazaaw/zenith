// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Zenith fork: Settings → Workspaces. The list of workspaces as calm tiles
// in their colours, and below it the chosen one: its name, symbol, colour,
// whether it is on, its shortcut, Run Now, and its steps (added, removed,
// reordered and edited in WorkspacesStepEditor). Headings are drawn here, not
// through SettingsCard's title, and switches are ZenithSwitchRow, so the page
// stays out of the search index upstream builds from its own catalogs.

struct WorkspacesSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WorkspaceService.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: UUID?
    @State private var confirmsDelete = false

    private var text: ZenithWorkspacesStrings { ZenithStrings.workspaces(l10n.language) }

    private var selected: Workspace? {
        selection.flatMap(service.workspace) ?? service.workspaces.first
    }

    private static let listID = "zenith.preview.list" // Zenith fork

    var body: some View {
        ScrollViewReader { proxy in // Zenith fork: the preview card scrolls to the list
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle) {
                    HStack(spacing: 8) {
                        Button(text.capture) { select(service.captureCurrent()) }
                            .help(text.captureHint)
                        Button(text.addWorkspace) { select(service.addBlank()) }
                            .buttonStyle(.borderedProminent)
                    }
                    .disabled(service.workspaces.count >= WorkspaceLibrary.maximum)
                }
                // Zenith fork: the shared preview card.
                ZenithWorkspacesPreviewCard {
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Self.listID, anchor: .top) }
                }
                listCard.id(Self.listID)
                if let workspace = selected {
                    WorkspaceEditor(workspace: workspace, confirmsDelete: $confirmsDelete)
                        .id(workspace.id)
                        .transition(.opacity)
                    if needsAccessibility(workspace), !permissions.accessibility {
                        SettingsCard { PermissionRow(kind: .accessibility) }
                    }
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
            .animation(motion, value: selected?.id)
        }
        }
        .toggleStyle(ZenithSwitchStyle())
        .confirmationDialog(selected.map { WorkspaceFormat.displayName($0.name, text: text) } ?? "",
                            isPresented: $confirmsDelete) {
            Button(text.delete, role: .destructive) { deleteSelected() }
            Button(ZenithStrings.home(l10n.language).cancel, role: .cancel) {}
        }
    }

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMotion.spring()
    }

    private func select(_ workspace: Workspace) {
        withAnimation(motion) { selection = workspace.id }
    }

    private func deleteSelected() {
        guard let id = selected?.id else { return }
        let list = service.workspaces
        let index = list.firstIndex { $0.id == id } ?? 0
        withAnimation(motion) {
            service.remove(id)
            let rest = list.filter { $0.id != id }
            selection = rest.isEmpty ? nil : rest[min(index, rest.count - 1)].id
        }
    }

    private func needsAccessibility(_ workspace: Workspace) -> Bool {
        workspace.runnableSteps.contains { $0.kind == .arrange }
    }

    // MARK: List

    private var listCard: some View {
        SettingsCard {
            if service.workspaces.isEmpty {
                Text(text.empty)
                    .font(ZenithType.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 2) {
                    ForEach(service.workspaces) { workspace in
                        row(workspace)
                    }
                }
            }
        }
    }

    private func row(_ workspace: Workspace) -> some View {
        let chosen = selected?.id == workspace.id
        let running = service.runningID == workspace.id
        return HStack(spacing: 12) {
            ZenithIslandGlyphTile(symbol: workspace.symbol, tint: ZenithIslandPalette.color(hex: workspace.color.hex), size: 30)
                .saturation(workspace.isEnabled ? 1 : 0.2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(WorkspaceFormat.displayName(workspace.name, text: text))
                        .font(ZenithType.rowTitle)
                    if workspace.isExample { tag(text.example) }
                }
                Text(summary(workspace))
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let shortcut = GlobalShortcut(storageValue: workspace.shortcut) {
                Text(shortcut.displayString)
                    .font(ZenithType.mono(11))
                    .foregroundStyle(.secondary)
                    .opacity(workspace.isEnabled ? 1 : 0.5)
            }
            runButton(workspace, running: running)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(chosen ? ZenithSurface.tileFill : .clear,
                    in: RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
                .strokeBorder(chosen ? ZenithSurface.tileStroke : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { select(workspace) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(chosen ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { select(workspace) }
    }

    /// Its steps in order, the ones that run.
    private func summary(_ workspace: Workspace) -> String {
        let steps = workspace.runnableSteps.map { $0.kind.title(text) }
        return steps.isEmpty ? text.noSteps : steps.joined(separator: " · ")
    }

    private func runButton(_ workspace: Workspace, running: Bool) -> some View {
        Button { service.run(workspace.id) } label: {
            ZStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(running ? 0 : 1)
                if running { ProgressView().controlSize(.mini) }
            }
            .frame(width: 26, height: 26)
            .background(ZenithSurface.tileFill, in: Circle())
            .overlay(Circle().strokeBorder(ZenithSurface.tileStroke))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(service.runningID != nil)
        .help(text.runNow)
        .accessibilityLabel("\(text.runNow), \(WorkspaceFormat.displayName(workspace.name, text: text))")
    }

    private func tag(_ title: String) -> some View {
        Text(title.uppercased())
            .font(ZenithType.mono(9.5, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(ZenithSurface.tileFill, in: Capsule())
            .overlay(Capsule().strokeBorder(ZenithSurface.hairline))
    }
}

// MARK: - Editor

/// The chosen workspace: its identity and settings, then its steps.
private struct WorkspaceEditor: View {
    let workspace: Workspace
    @Binding var confirmsDelete: Bool
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WorkspaceService.shared
    @State private var shortcutMessage: String?

    private var text: ZenithWorkspacesStrings { ZenithStrings.workspaces(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                heading(WorkspaceFormat.displayName(workspace.name, text: text))
                SettingsCard { general }
            }
            WorkspacesStepEditor(workspace: workspace)
        }
    }

    private func update(_ change: (inout Workspace) -> Void) {
        guard let current = service.workspace(workspace.id) else { return }
        service.update(current.edited(change))
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 13) {
            if workspace.isExample {
                Label(text.exampleHint, systemImage: "lightbulb")
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Text(text.name).font(ZenithType.rowTitle)
                Spacer(minLength: 12)
                TextField(text.name, text: Binding(get: { workspace.name }, set: { name in update { $0.name = name } }))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .labelsHidden()
            }
            hairline
            symbolPicker
            colorPicker
            hairline
            ZenithSwitchRow(text.use, isOn: Binding(get: { workspace.isEnabled },
                                                    set: { on in update { $0.isEnabled = on } })) {
                label(text.use, caption: text.useHint)
            }
            shortcutRow
            hairline
            footer
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.symbol).font(ZenithType.rowTitle)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 8), alignment: .leading, spacing: 6) {
                ForEach(WorkspaceSymbols.choices, id: \.self) { symbol in
                    let chosen = workspace.symbol == symbol
                    Button { update { $0.symbol = symbol } } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 34, height: 30)
                            .foregroundStyle(chosen ? ZenithIslandPalette.color(hex: workspace.color.hex) : .secondary)
                            .background(chosen ? ZenithSurface.tileFill : .clear,
                                        in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                                    .strokeBorder(chosen ? ZenithSurface.tileStroke : ZenithSurface.hairline)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            Text(text.color).font(ZenithType.rowTitle)
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                ForEach(WorkspaceColor.allCases, id: \.self) { color in
                    let chosen = workspace.color == color
                    Button { update { $0.color = color } } label: {
                        Circle()
                            .fill(ZenithIslandPalette.color(hex: color.hex))
                            .frame(width: 18, height: 18)
                            .padding(3)
                            .overlay(Circle().strokeBorder(chosen ? Color.primary.opacity(0.55) : .clear, lineWidth: 1.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(color.title(text))
                    .accessibilityLabel(color.title(text))
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }
    }

    private var shortcutRow: some View {
        let s = l10n.s
        let refused = service.refusedShortcuts.contains(workspace.id)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(text.shortcut).font(ZenithType.rowTitle)
                Spacer(minLength: 12)
                if refused {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ZenithStatus.warning)
                        .help(s.shortcutNotCaptured)
                }
                ShortcutRecorderButton(
                    shortcut: GlobalShortcut(storageValue: workspace.shortcut) ?? .radialMenuDefault,
                    isEnabled: workspace.isEnabled,
                    waitingTitle: s.shortcutPressKeys,
                    emptyTitle: workspace.shortcut.isEmpty ? s.shortcutNone : nil,
                    clearAction: {
                        shortcutMessage = nil
                        update { $0.shortcut = "" }
                    },
                    notCapturedAction: { shortcutMessage = s.shortcutNotCaptured },
                    recordingChanged: { recording in if recording { shortcutMessage = nil } },
                    invalidAction: { shortcutMessage = s.shortcutInvalid },
                    captureAction: { shortcut in
                        if let owner = service.conflict(for: shortcut, excluding: workspace.id) {
                            shortcutMessage = s.shortcutConflictFormat.replacingOccurrences(of: "%@", with: owner)
                            return
                        }
                        shortcutMessage = nil
                        update { $0.shortcut = shortcut.storageValue }
                    }
                )
                .frame(width: 130)
            }
            if let shortcutMessage {
                Text(shortcutMessage)
                    .font(ZenithType.caption)
                    .foregroundStyle(ZenithStatus.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        let running = service.runningID == workspace.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { service.run(workspace.id) } label: {
                    HStack(spacing: 6) {
                        if running {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(running ? text.running : text.runNow)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(service.runningID != nil || workspace.runnableSteps.isEmpty)
                Spacer(minLength: 8)
                Button(text.delete, role: .destructive) { confirmsDelete = true }
            }
            if let report = service.lastReports[workspace.id] {
                let notice = WorkspaceFormat.notice(report, text: text)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: report.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(report.succeeded ? ZenithStatus.success : ZenithStatus.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(text.lastRun) · \(notice.title)").font(ZenithType.caption)
                        if !report.succeeded {
                            ForEach(Array(report.problems.enumerated()), id: \.offset) { _, problem in
                                Text(problem.text(text))
                                    .font(ZenithType.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(ZenithType.sectionTitle)
            .tracking(ZenithType.sectionTitleTracking)
            .padding(.leading, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(ZenithType.rowTitle)
            Text(caption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hairline: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).accessibilityHidden(true)
    }
}

// MARK: - Pickers

enum WorkspacePickers {
    /// Apps from an open panel limited to applications, starting in /Applications.
    static func chooseApps(multiple: Bool = true) -> [WorkspaceApp] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = multiple
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.map { url in
            WorkspaceApp(bundleID: Bundle(url: url)?.bundleIdentifier ?? "",
                         name: InstalledApps.displayName(fromFinderName: FileManager.default.displayName(atPath: url.path)),
                         path: url.path)
        }
    }

    /// A file or folder for an app to open.
    static func chooseTarget() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return (url.path as NSString).abbreviatingWithTildeInPath
    }

    static func chooseImage() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }

    static func icon(_ app: WorkspaceApp) -> NSImage {
        if let url = WorkspaceSystemPerformer.applicationURL(app) { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
