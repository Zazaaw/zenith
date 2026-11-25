// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: Claude Code sessions, live, from its own hooks.
///
/// The hook script writes one small JSON file per event into
/// `<container>/Agents/`. This service watches that folder with a
/// DispatchSource (no polling), reads and deletes each file on its own queue,
/// keeps every session's state (`ClaudeHooksSupport.Tracker`) and publishes
/// it on the main thread. A timer runs only for moments that change on their
/// own: a ✓ running out, a wait no longer worth the closed island, a session
/// going stale.
///
/// It runs while the island shows the AI section with Claude on, or while
/// Zenith Pocket shares Claude Code with a paired phone. Off, the folder goes
/// too, and the script, finding no folder, writes nothing.
final class ClaudeHooksService: ObservableObject {
    static let shared = ClaudeHooksService()

    /// Every session, the one needing a look first.
    @Published private(set) var sessions: [ClaudeHooksSupport.Session] = []
    /// What the closed island shows: a session that needs the person or one that just ended.
    @Published private(set) var strip: ClaudeHooksSupport.Strip?
    /// When the hook last wrote, kept on this Mac only (never backed up).
    @Published private(set) var lastEvent: Date?
    /// Zenith fork: how often sessions waiting for the person may chime; main thread only.
    private var chimeLimiter = ClaudeChimeLimiter()

    private let queue = DispatchQueue(label: "com.vorssaint.zenith.claude-hooks", qos: .utility)
    /// Main thread: published values are accepted only while running.
    private var active = false
    /// Zenith fork, main thread: who wants the sessions. The island (its AI
    /// section with Claude), and Zenith Pocket while it shares Claude Code.
    /// The closed island's strip, its chime and the day's recap stay the island's.
    private var islandWants = false
    private var pocketWants = false
    /// `islandWants`, as `queue` reads it.
    private var recordsRecap = false

    // Owned by `queue`.
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var tracker = ClaudeHooksSupport.Tracker()
    private var folder: URL?

    private init() {
        let stored = UserDefaults.standard.double(forKey: DefaultsKey.notchAgentsClaudeLastEvent)
        lastEvent = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// `<Application Support>/<bundle id>/Agents`, for this build's bundle id.
    static var folderURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent(ClaudeHooksSupport.folderName, isDirectory: true)
    }

    /// The script Claude Code runs, beside the folder rather than in it, so
    /// turning the feature off never leaves a hook pointing at nothing.
    static var scriptURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent(ClaudeHooksSupport.scriptName, isDirectory: false)
    }

    /// The command this build merges into `~/.claude/settings.json`.
    static var command: String? {
        scriptURL.map { ClaudeHooksSettings.command(script: $0.path) }
    }

    // MARK: Lifecycle

    /// Called with every island preference sync.
    func syncWithPreferences() {
        islandWants = ClaudeHooksSupport.isEnabled()
        apply()
    }

    /// The island stopped, or the section or Claude went off.
    func stop() {
        islandWants = false
        apply()
    }

    /// Zenith fork: Zenith Pocket shares Claude Code (true) or stopped (false).
    func setPocketWants(_ wants: Bool) {
        guard wants != pocketWants else { return }
        pocketWants = wants
        apply()
    }

    private func apply() {
        guard islandWants || pocketWants else {
            stopWatching()
            return
        }
        if !islandWants, strip != nil { strip = nil }
        let folder = Self.folderURL
        let island = islandWants
        active = true
        queue.async { [self] in
            recordsRecap = island
            Self.refreshScriptIfInstalled()
            if source == nil || self.folder != folder {
                closeWatcher()
                self.folder = folder
                openWatcher()
            }
            scan()
        }
    }

    private func stopWatching() {
        active = false
        if !sessions.isEmpty { sessions = [] }
        if strip != nil { strip = nil }
        queue.async { [self] in
            closeWatcher()
            timer?.cancel()
            timer = nil
            tracker = ClaudeHooksSupport.Tracker()
            if let folder = folder ?? Self.folderURL { try? FileManager.default.removeItem(at: folder) }
            folder = nil
        }
    }

    // MARK: Watching (on `queue`)

    private func openWatcher() {
        guard let folder, PrivateFileStore.createDirectory(at: folder) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = folder
        try? excluded.setResourceValues(values)
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .delete, .rename], queue: queue)
        source.setEventHandler { [weak self, unowned source] in
            guard let self else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                // The folder itself went away: make it again and keep watching.
                self.closeWatcher()
                self.openWatcher()
            }
            self.scan()
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    private func closeWatcher() {
        source?.cancel()
        source = nil
    }

    /// Reads what the hook wrote since the last look, deletes it, applies it
    /// in order and publishes.
    private func scan() {
        guard let folder else { return }
        let manager = FileManager.default
        let now = Date()
        var read: [(event: ClaudeHooksSupport.Event, written: Date)] = []
        var names = (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
        // Left while the app was away: only the latest are worth reading.
        if names.count > ClaudeHooksSupport.maxFilesPerScan {
            names.sort()
            for name in names.dropLast(ClaudeHooksSupport.maxFilesPerScan) {
                try? manager.removeItem(at: folder.appendingPathComponent(name, isDirectory: false))
            }
            names = Array(names.suffix(ClaudeHooksSupport.maxFilesPerScan))
        }
        for name in names {
            let url = folder.appendingPathComponent(name, isDirectory: false)
            let attributes = try? manager.attributesOfItem(atPath: url.path)
            let written = attributes?[.modificationDate] as? Date ?? now
            let kind = ClaudeHooksSupport.kind(ofFile: name)
            guard kind == .event else {
                if ClaudeHooksSupport.removesLeftover(kind, age: now.timeIntervalSince(written)) {
                    try? manager.removeItem(at: url)
                }
                continue
            }
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            let data = size <= ClaudeHooksSupport.maxFileSize ? try? Data(contentsOf: url) : nil
            try? manager.removeItem(at: url)
            if let event = data.flatMap(ClaudeHooksSupport.parse) { read.append((event, written)) }
        }
        for event in ClaudeHooksSupport.ordered(read) {
            tracker.apply(event, now: now)
            // The day's recap counts turns (prompts) and the sessions they were in.
            if event.kind == .prompt, recordsRecap {
                RecapService.record(.agent(session: event.session, prompt: true, at: event.time))
            }
        }
        if !read.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.noteEvent(now) }
        }
        refresh(now: now)
    }

    /// Drops stale sessions, publishes, and waits for the next change.
    private func refresh(now: Date) {
        tracker.removeStale(now: now)
        let sessions = tracker.ordered()
        let strip = tracker.strip(now: now)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.active else { return }
            if self.sessions != sessions { self.sessions = sessions }
            let strip = self.islandWants ? strip : nil
            if self.strip != strip {
                let before = self.strip
                self.strip = strip
                self.announce(strip, after: before)
            }
        }
        schedule(now: now)
    }

    private func schedule(now: Date) {
        timer?.cancel()
        timer = nil
        guard let moment = tracker.nextChange(after: now) else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + max(0, moment.timeIntervalSince(now)) + 0.01, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in self?.refresh(now: Date()) }
        self.timer = timer
        timer.resume()
    }

    // MARK: Main thread

    private func noteEvent(_ date: Date) {
        lastEvent = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: DefaultsKey.notchAgentsClaudeLastEvent)
    }

    /// Zenith fork: when a session starts needing the person, a soft sound
    /// with the island's burst naming the project, never the sound alone, and
    /// no more often than `ClaudeChimeLimiter` allows.
    private func announce(_ strip: ClaudeHooksSupport.Strip?, after before: ClaudeHooksSupport.Strip?) {
        guard let strip, case .needsYou = strip.kind, strip != before,
              ClaudeHooksSupport.chime() == .soundAndIsland, chimeLimiter.allows(session: strip.session, at: Date()) else { return }
        let island = NotchService.shared
        let burst = ZenithAgentBurst(provider: .claude, title: ZenithStrings.claudeChime(L10n.shared.language).needsYou,
                                     subtitle: strip.folder)
        // An open island already shows the AI page's own row; the burst
        // waits a moment for it to close. Anything else keeps quiet.
        guard island.showZenithBurst(.agent(burst)) || island.expanded else { return }
        guard let sound = NSSound(named: "Tink")?.copy() as? NSSound else { return }
        sound.volume = 0.35
        sound.play()
    }

    // MARK: Claude Code settings

    static func settingsState() -> ClaudeHooksSettings.State {
        guard let command else { return .missing }
        guard let text = ClaudeHooksSettings.read(at: ClaudeHooksSettings.settingsURL) else { return .unreadable }
        return ClaudeHooksSettings.state(of: text, command: command)
    }

    /// Writes the script, then merges the hooks into `~/.claude/settings.json`.
    static func connect() -> ClaudeHooksSettings.EditResult {
        guard let command, writeScript() else { return .failed }
        return ClaudeHooksSettings.edit(at: ClaudeHooksSettings.settingsURL, install: command)
    }

    /// Takes the hooks out of `~/.claude/settings.json` and the script away.
    static func disconnect() -> ClaudeHooksSettings.EditResult {
        let result = ClaudeHooksSettings.edit(at: ClaudeHooksSettings.settingsURL, install: nil)
        if result == .changed || result == .unchanged, let scriptURL {
            try? FileManager.default.removeItem(at: scriptURL)
        }
        return result
    }

    @discardableResult
    private static func writeScript() -> Bool {
        guard let scriptURL, let folder = folderURL,
              PrivateFileStore.createDirectory(at: scriptURL.deletingLastPathComponent()) else { return false }
        let script = Data(ClaudeHooksSupport.hookScript(folder: folder.path).utf8)
        if (try? Data(contentsOf: scriptURL)) == script { return true }
        return PrivateFileStore.write(script, to: scriptURL)
    }

    /// An update may change the script; one already installed follows it.
    private static func refreshScriptIfInstalled() {
        guard let scriptURL, FileManager.default.fileExists(atPath: scriptURL.path) else { return }
        writeScript()
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension ClaudeHooksService {
    func catalogPose(sessions: [ClaudeHooksSupport.Session], strip: ClaudeHooksSupport.Strip?) {
        self.sessions = sessions
        self.strip = strip
    }
}
#endif
