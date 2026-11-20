// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

// Zenith fork: the workspaces a Mac keeps (WorkspaceLibrary, in one
// registered default so backups carry them), running one at a time on a
// background queue, the capsule notice a run ends with, and a global
// shortcut per workspace. Nothing runs in the background otherwise: no
// timer, no observer of other apps.

final class WorkspaceService: ObservableObject {
    static let shared = WorkspaceService()

    @Published private(set) var workspaces: [Workspace]
    /// The workspace running now; one at a time.
    @Published private(set) var runningID: UUID?
    /// How each workspace's last run went, since launch.
    @Published private(set) var lastReports: [UUID: WorkspaceRunReport] = [:]
    /// Workspaces whose shortcut macOS refused (taken by another app).
    @Published private(set) var refusedShortcuts: Set<UUID> = []

    /// Global shortcuts, one slot per position in the list (ids 1800 and up).
    private static let firstHotkeyID: UInt32 = 1800
    private var hotkeys: [QuickToolHotkey] = []
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.workspaces", qos: .userInitiated)
    private var stored: String
    private var defaultsObserver: NSObjectProtocol?

    private init() {
        stored = UserDefaults.standard.string(forKey: DefaultsKey.zenithWorkspaces) ?? ""
        workspaces = WorkspaceLibrary.decode(stored)
        // A backup restored or a defaults write from elsewhere: read them again.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                  object: nil, queue: .main) { [weak self] _ in
            self?.reloadIfChanged()
        }
    }

    private var text: ZenithWorkspacesStrings { ZenithStrings.workspaces(L10n.shared.language) }

    /// The ones offered in the Command Bar, the island and by shortcut.
    var enabled: [Workspace] { workspaces.filter(\.isEnabled) }

    func workspace(_ id: UUID) -> Workspace? { workspaces.first { $0.id == id } }

    // MARK: Editing

    func update(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        var list = workspaces
        list[index] = workspace
        save(list)
    }

    func add(_ workspace: Workspace) {
        save(workspaces + [workspace])
    }

    func remove(_ id: UUID) {
        save(workspaces.filter { $0.id != id })
    }

    /// A new, empty workspace, named and added at the end.
    func addBlank() -> Workspace {
        let workspace = Workspace(name: text.untitled, color: WorkspaceColor.allCases[workspaces.count % WorkspaceColor.allCases.count],
                                  steps: [WorkspaceStep(.openApps([]))])
        add(workspace)
        return workspace
    }

    /// "Capture Current": the apps running now and their windows, as a new workspace.
    func captureCurrent() -> Workspace {
        let workspace = WorkspaceSnapshot.capture(named: text.captureName)
        add(workspace)
        return workspace
    }

    private func save(_ list: [Workspace]) {
        workspaces = list
        // Known before the write, so the change notice it posts reads as ours.
        stored = WorkspaceLibrary.encode(list)
        WorkspaceLibrary.save(list)
        syncHotkeys()
    }

    private func reloadIfChanged() {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.zenithWorkspaces) ?? ""
        guard raw != stored else { return }
        stored = raw
        workspaces = WorkspaceLibrary.decode(raw)
        syncHotkeys()
    }

    // MARK: Running

    /// Runs a workspace's steps in order off the main thread, then says how
    /// it went. A second run waits for none: it is ignored while one runs.
    func run(_ id: UUID) {
        guard runningID == nil, let workspace = workspace(id) else { return }
        runningID = id
        let performer = WorkspaceSystemPerformer()
        queue.async { [weak self] in
            let report = WorkspaceRunner.run(workspace, with: performer)
            DispatchQueue.main.async { self?.finish(report, workspace: workspace) }
        }
    }

    private func finish(_ report: WorkspaceRunReport, workspace: Workspace) {
        runningID = nil
        lastReports[report.workspaceID] = report
        let notice = WorkspaceFormat.notice(report, text: text)
        if NotchService.shared.running {
            ZenithNoticeCenter.shared.workspaceFinished(id: workspace.id.uuidString, title: notice.title,
                                                        subtitle: notice.subtitle, symbol: workspace.symbol,
                                                        hex: workspace.color.hex, succeeded: report.succeeded)
        } else {
            Notifier.post(title: notice.title, body: notice.subtitle)
        }
    }

    // MARK: Shortcuts

    /// Registers each enabled workspace's shortcut; called at launch, after
    /// every edit, and when a shortcut field stops recording.
    func syncHotkeys() {
        var refused = Set<UUID>()
        let slots = Array(workspaces.prefix(WorkspaceLibrary.maximum))
        while hotkeys.count < slots.count {
            hotkeys.append(QuickToolHotkey(id: Self.firstHotkeyID + UInt32(hotkeys.count)))
        }
        for (index, hotkey) in hotkeys.enumerated() {
            guard index < slots.count, slots[index].isEnabled,
                  let shortcut = GlobalShortcut(storageValue: slots[index].shortcut) else {
                hotkey.unregister()
                continue
            }
            let id = slots[index].id
            hotkey.onPress = { [weak self] in self?.run(id) }
            if !hotkey.sync(enabled: true, shortcut: shortcut,
                            storageKey: "\(DefaultsKey.zenithWorkspaces).\(id.uuidString)") {
                refused.insert(id)
            }
        }
        if refused != refusedShortcuts { refusedShortcuts = refused }
    }

    /// At launch: only a Mac with a workspace shortcut registers anything.
    func start() {
        guard workspaces.contains(where: { $0.isEnabled && !$0.shortcut.isEmpty }) else { return }
        syncHotkeys()
    }

    /// Who already answers to a combination: an app shortcut's name, another
    /// workspace's, or nil when it is free.
    func conflict(for shortcut: GlobalShortcut, excluding id: UUID) -> String? {
        if let role = GlobalShortcutRole.conflict(for: shortcut, excluding: nil) {
            return role.title(L10n.shared.s)
        }
        return workspaces.first { $0.id != id && GlobalShortcut(storageValue: $0.shortcut) == shortcut }
            .map { WorkspaceFormat.commandTitle($0.name, text: text) }
    }
}
