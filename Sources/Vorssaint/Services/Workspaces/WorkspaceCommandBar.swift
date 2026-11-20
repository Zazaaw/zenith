// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: "Workspace: Coding" in the Command Bar, one row per workspace
// that is on. The rows sit with the actions (an `action.` id), so they take
// aliases, pins and the bar's own per-row shortcuts like any action.

extension CommandBarCatalog {
    static func workspaceEntries(_ bar: CommandBarFeatureStrings) -> [CommandBarEntry] {
        let text = ZenithStrings.workspaces(L10n.shared.language)
        let english = ZenithStrings.workspaces(.enUS)
        return WorkspaceService.shared.enabled.map { workspace in
            let id = workspace.id
            return CommandBarEntry(id: "action.workspaces.\(id.uuidString)",
                                   title: WorkspaceFormat.commandTitle(workspace.name, text: text),
                                   subtitle: text.kind,
                                   keywords: [workspace.name, text.kind, english.kind, text.title, english.title]
                                       .joined(separator: " "),
                                   icon: .symbol(workspace.symbol),
                                   shortcut: GlobalShortcut(storageValue: workspace.shortcut),
                                   run: { _ in
                                       // A beat, so the bar is gone before the first app comes forward.
                                       DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                           WorkspaceService.shared.run(id)
                                       }
                                   })
        }
    }
}
