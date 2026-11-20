// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: workspaces on the island's home page (Customize Home). Up to
// three of the workspaces that are on, each a calm tile in its colour with
// its name; a click runs it, and the tile holds a small spinner until the
// run's notice says how it went.

struct WorkspacesHomeWidget: View {
    @ObservedObject private var workspaces = WorkspaceService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Side by side in a 252 point card.
    private static let shown = 3

    var body: some View {
        let text = ZenithStrings.workspaces(l10n.language)
        let list = Array(workspaces.enabled.prefix(Self.shown))
        VStack(alignment: .leading, spacing: 6) {
            ZenithHomeWidgetHeader(widget: .workspaces, title: text.title)
            if list.isEmpty {
                Text(text.widgetEmpty)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ZenithIsland.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 6) {
                    ForEach(list) { workspace in
                        tile(workspace, text: text)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMotion.spring(), value: workspaces.runningID)
    }

    private func tile(_ workspace: Workspace, text: ZenithWorkspacesStrings) -> some View {
        let running = workspaces.runningID == workspace.id
        let busy = workspaces.runningID != nil
        let name = WorkspaceFormat.displayName(workspace.name, text: text)
        return Button { workspaces.run(workspace.id) } label: {
            VStack(spacing: 4) {
                ZStack {
                    ZenithIslandGlyphTile(symbol: workspace.symbol,
                                          tint: ZenithIslandPalette.color(hex: workspace.color.hex), size: 24)
                        .opacity(running ? 0 : 1)
                        .scaleEffect(running && !reduceMotion ? 0.8 : 1)
                    if running {
                        ProgressView()
                            .controlSize(.mini)
                            .transition(.opacity)
                    }
                }
                .frame(width: 24, height: 24)
                Text(name)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy && !running ? 0.5 : 1)
        .help(WorkspaceFormat.commandTitle(workspace.name, text: text))
        .accessibilityLabel(WorkspaceFormat.commandTitle(workspace.name, text: text))
    }
}
