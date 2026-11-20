// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices
import Combine
import CoreServices

/// What the closed island shows: the branch (or the detached commit) and
/// whether anything is uncommitted.
struct GitIndicator: Equatable {
    let branch: String
    let dirty: Bool
}

// Zenith fork: the local Git status of the project being worked on.
//
// Which repository: the frontmost editor's (VS Code, Cursor, Zed, Xcode),
// read through Accessibility when an editor comes to the front or leaves it
// and every 3 seconds while the page shows; the folder of the newest
// terminal command (CommandActivityService); the pinned ones; or one picked
// on the page. GitRepoSelector keeps the newest sign, and the last editor
// project for 20 minutes once other apps are in front.
//
// The status is read with `git` (GitRunner), off the main thread, bounded,
// never prompting and never taking the index lock: every 4 seconds while the
// page or its widget shows, every 30 while only the closed island's branch
// does, and at once when FSEvents report HEAD, the index, refs or the
// operation files changing. Nothing is read while nothing shows. A fetch
// runs only when the person turned it on. Read-only: no pull, push or commit.

final class GitService: ObservableObject {
    static let shared = GitService()

    enum State: Equatable { case empty, loading, ready, failed }

    static let visibleInterval: TimeInterval = 4
    static let indicatorInterval: TimeInterval = 30
    static let focusInterval: TimeInterval = 3
    static let recentLimit = 8

    @Published private(set) var state: State = .empty
    /// The repository shown and where it came from.
    @Published private(set) var current: GitRepoSelector.Current?
    @Published private(set) var snapshot: GitSnapshot?
    /// The closed island's branch: nil while it should not show.
    @Published private(set) var indicator: GitIndicator?
    /// Repositories seen lately, newest first, kept on this Mac only.
    @Published private(set) var recent: [String] = []
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var copied = false
    @Published private(set) var fetching = false

    private let queue = DispatchQueue(label: "com.vorssaint.zenith.git", qos: .utility)
    private var options = GitOptions()
    private var selector = GitRepoSelector()
    private var active = false
    private var viewers = 0
    private var pollTimer: Timer?
    private var pollInterval: TimeInterval = 0
    private var focusTimer: Timer?
    private var fetchTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var commandSubscription: AnyCancellable?
    private var reading = false
    private var pendingRead: Bool?
    private var changeWork: DispatchWorkItem?
    private var copiedWork: DispatchWorkItem?
    /// The editor that last showed each repository, for Open.
    private var editors: [String: GitEditor] = [:]
    private var lastFetch: [String: Date] = [:]

    // Owned by `queue`.
    private var stream: FSEventStreamRef?
    private var watchedPaths: [String] = []
    private var storageCache: [GitEditor: (date: Date, folders: [String])] = [:]

    private init() {
        recent = (UserDefaults.standard.stringArray(forKey: DefaultsKey.notchGitRecent) ?? []).prefix(Self.recentLimit).map { $0 }
    }

    /// Reads run while the page or widget shows, or the closed island's branch does.
    private var looks: Bool { viewers > 0 || (active && options.indicator) }

    // MARK: Lifecycle

    /// Called with every island preference sync and from the section's options.
    func syncWithPreferences() {
        options = GitOptions.current()
        active = NotchSupport.isEnabled() && NotchSupport.modules().contains(.git)
        guard active else {
            stop()
            return
        }
        observeWorkspace(options.fromEditor)
        observeCommands(options.fromTerminal)
        applySelection()
        schedule()
        publishIndicator()
    }

    /// The island stopped or the section went: no more watching in the background.
    func stop() {
        active = false
        observeWorkspace(false)
        observeCommands(false)
        if indicator != nil { indicator = nil }
        schedule()
    }

    /// The page or the home widget appeared; while any shows, it reads often.
    func shown() {
        viewers += 1
        options = GitOptions.current()
        accessibilityGranted = AXIsProcessTrusted()
        lookAtFrontmost()
        applySelection()
        schedule()
        refresh()
        fetchIfDue()
    }

    func hidden() {
        viewers = max(0, viewers - 1)
        schedule()
    }

    private func schedule() {
        let wanted: TimeInterval = viewers > 0 ? Self.visibleInterval
            : active && options.indicator ? Self.indicatorInterval : 0
        if wanted != pollInterval {
            pollInterval = wanted
            pollTimer?.invalidate()
            pollTimer = wanted > 0 ? repeating(wanted) { [weak self] in self?.refresh() } : nil
        }
        let focuses = viewers > 0 && options.fromEditor
        if focuses != (focusTimer != nil) {
            focusTimer?.invalidate()
            focusTimer = focuses ? repeating(Self.focusInterval) { [weak self] in self?.lookAtFrontmost() } : nil
        }
        let fetches = looks && options.fetches
        if fetches != (fetchTimer != nil) {
            fetchTimer?.invalidate()
            fetchTimer = fetches ? repeating(60) { [weak self] in self?.fetchIfDue() } : nil
        }
        watch(looks ? snapshot?.location : nil)
    }

    private func repeating(_ interval: TimeInterval, _ action: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    // MARK: Which repository

    private func observeWorkspace(_ on: Bool) {
        let center = NSWorkspace.shared.notificationCenter
        guard on != !workspaceObservers.isEmpty else { return }
        guard on else {
            workspaceObservers.forEach(center.removeObserver)
            workspaceObservers = []
            return
        }
        func app(_ note: Notification) -> NSRunningApplication? {
            note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        }
        // Coming to the front, the editor's project counts as new; leaving
        // it, its focused window is the last project worked on.
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                     object: nil, queue: .main) { [weak self] note in
            guard let self, let app = app(note), let editor = GitEditor.from(bundleIdentifier: app.bundleIdentifier) else { return }
            self.selector.editorActivated()
            let pid = app.processIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.look(at: editor, pid: pid) }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification,
                                                     object: nil, queue: .main) { [weak self] note in
            guard let self, let app = app(note), let editor = GitEditor.from(bundleIdentifier: app.bundleIdentifier) else { return }
            self.look(at: editor, pid: app.processIdentifier)
            // Files saved before leaving the editor show at once.
            if self.looks { self.refresh() }
        })
    }

    private func observeCommands(_ on: Bool) {
        guard on else {
            commandSubscription = nil
            return
        }
        guard commandSubscription == nil else { return }
        // A command from before is weighed by its time like any other.
        commandSubscription = CommandActivityService.shared.$latestDirectory.compactMap { $0 }.removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] directory in self?.commandStarted(in: directory) }
    }

    private func commandStarted(in directory: CommandActivityService.CommandDirectory) {
        queue.async { [weak self] in
            guard let location = GitRepoLocator.locate(from: directory.path) else { return }
            DispatchQueue.main.async {
                guard let self, self.active, self.options.fromTerminal else { return }
                self.selector.observeTerminal(location.root, at: directory.time)
                self.applySelection()
            }
        }
    }

    /// The frontmost app, when it is an editor.
    private func lookAtFrontmost() {
        guard options.fromEditor, let app = NSWorkspace.shared.frontmostApplication,
              let editor = GitEditor.from(bundleIdentifier: app.bundleIdentifier) else { return }
        look(at: editor, pid: app.processIdentifier)
    }

    private func look(at editor: GitEditor, pid: pid_t) {
        guard options.fromEditor, active || viewers > 0 else { return }
        let known = options.pinnedPaths() + recent
        queue.async { [weak self] in
            guard let self else { return }
            let focus = GitFocusReader.read(pid: pid)
            let location = focus.flatMap {
                GitFocusReader.repository(for: $0, editor: editor, known: known, storage: self.storage)
            }
            let granted = focus != nil
            DispatchQueue.main.async {
                if self.accessibilityGranted != granted { self.accessibilityGranted = granted }
                guard let location else { return }
                self.editors[location.root] = editor
                self.selector.observeEditor(location.root, now: Date())
                self.applySelection()
            }
        }
    }

    /// On the queue: a VS Code family editor's folders, read again when its file changes.
    private func storage(_ editor: GitEditor) -> [String] {
        guard let folder = editor.storageFolder else { return [] }
        let path = NSHomeDirectory() + "/Library/Application Support/" + folder + "/User/globalStorage/storage.json"
        let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date ?? .distantPast
        if let cached = storageCache[editor], cached.date == date { return cached.folders }
        let folders = GitFocusReader.storageFolders(editor)
        storageCache[editor] = (date, folders)
        return folders
    }

    /// Shows the repository the selector settles on.
    private func applySelection() {
        let resolved = selector.resolved(pinned: options.pinnedPaths(), now: Date())
        guard resolved?.root != current?.root else {
            if resolved?.source != current?.source { current = resolved }
            return
        }
        current = resolved
        if snapshot?.location.root != resolved?.root { snapshot = nil }
        state = resolved == nil ? .empty : .loading
        if let root = resolved?.root { remember(root) }
        publishIndicator()
        watch(nil)
        refresh()
    }

    /// Picked from the page's switch.
    func choose(_ root: String) {
        selector.choose(root, now: Date())
        applySelection()
    }

    private func remember(_ root: String) {
        var list = recent.filter { $0 != root }
        list.insert(root, at: 0)
        list = Array(list.prefix(Self.recentLimit))
        guard list != recent else { return }
        recent = list
        UserDefaults.standard.set(list, forKey: DefaultsKey.notchGitRecent)
    }

    private func forget(_ root: String) {
        selector.forget(root)
        editors[root] = nil
        if recent.contains(root) {
            recent.removeAll { $0 == root }
            UserDefaults.standard.set(recent, forKey: DefaultsKey.notchGitRecent)
        }
    }

    /// The page's switch: pinned repositories, then the ones seen lately.
    var choices: [String] {
        var seen = Set<String>()
        return (options.pinnedPaths() + recent).filter { seen.insert($0).inserted }
    }

    // MARK: Reading

    func refresh(reloadsRemotes: Bool = false) {
        guard looks, let root = current?.root, let executable = GitCLI.executable() else { return }
        if reading {
            pendingRead = (pendingRead ?? false) || reloadsRemotes
            return
        }
        reading = true
        let previous = snapshot
        queue.async { [weak self] in
            let result: Result<GitSnapshot, GitRunner.Failure>
            if let location = GitRepoLocator.repository(at: root) {
                result = GitRunner.snapshot(executable: executable, location: location, previous: previous,
                                            reloadsRemotes: reloadsRemotes)
            } else {
                result = .failure(.notRepository)
            }
            DispatchQueue.main.async { self?.finish(result, root: root) }
        }
    }

    private func finish(_ result: Result<GitSnapshot, GitRunner.Failure>, root: String) {
        reading = false
        defer {
            if let reloads = pendingRead {
                pendingRead = nil
                refresh(reloadsRemotes: reloads)
            }
        }
        guard current?.root == root else {
            pendingRead = pendingRead ?? false
            return
        }
        switch result {
        case .success(let fresh):
            if fresh != snapshot { snapshot = fresh }
            if state != .ready { state = .ready }
            if looks { watch(fresh.location) }
        case .failure(.notRepository) where options.pinnedPaths().contains(root):
            // A pin that is no repository (any more) says so; Settings marks it too.
            snapshot = nil
            state = .failed
        case .failure(.notRepository):
            forget(root)
            snapshot = nil
            current = nil
            applySelection()
        case .failure:
            if snapshot == nil { state = .failed }
        }
        publishIndicator()
    }

    private func publishIndicator() {
        var next: GitIndicator?
        if active, options.indicator, let snapshot, snapshot.location.root == current?.root {
            let branch = snapshot.branch.head ?? snapshot.branch.shortOID
            next = branch.map { GitIndicator(branch: $0, dirty: !snapshot.counts.isClean) }
        }
        if next != indicator { indicator = next }
    }

    private func fetchIfDue() {
        guard options.fetches, looks, !fetching, let snapshot, snapshot.location.root == current?.root,
              snapshot.branch.upstream != nil, let executable = GitCLI.executable() else { return }
        let root = snapshot.location.root
        let now = Date()
        if let last = lastFetch[root], now.timeIntervalSince(last) < options.fetchInterval { return }
        fetching = true
        lastFetch[root] = now
        let location = snapshot.location
        let remote = snapshot.upstreamRemote
        queue.async { [weak self] in
            GitRunner.fetch(executable: executable, location: location, remote: remote)
            DispatchQueue.main.async {
                self?.fetching = false
                self?.refresh()
            }
        }
    }

    // MARK: Watching (FSEvents)

    private func watch(_ location: GitRepoLocation?) {
        var paths: [String] = []
        if let location {
            paths = [location.gitDir]
            if location.commonDir != location.gitDir { paths.append(location.commonDir) }
        }
        queue.async { [weak self] in
            guard let self, paths != self.watchedPaths else { return }
            self.closeStream()
            self.watchedPaths = paths
            if !paths.isEmpty { self.openStream(paths) }
        }
    }

    private func openStream(_ paths: [String]) {
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let service = Unmanaged<GitService>.fromOpaque(info).takeUnretainedValue()
            let list = (unsafeBitCast(paths, to: NSArray.self) as? [String]) ?? []
            let relevant = list.prefix(count).filter(GitRepoLocator.isRelevantChange)
            guard !relevant.isEmpty else { return }
            let config = relevant.contains { $0.hasSuffix("/config") }
            DispatchQueue.main.async { service.changed(reloadsRemotes: config) }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let created = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, paths as CFArray,
                                                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.3, flags) else {
            return
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            return
        }
        stream = created
    }

    private func closeStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// A burst of changes (a commit writes the index, a ref and HEAD) reads once.
    private func changed(reloadsRemotes: Bool) {
        changeWork?.cancel()
        let reloads = reloadsRemotes || (pendingRead ?? false)
        let work = DispatchWorkItem { [weak self] in self?.refresh(reloadsRemotes: reloads) }
        changeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: Actions

    /// The editor that last showed the repository, else the first one installed.
    func editor(for root: String) -> (editor: GitEditor, url: URL)? {
        let workspace = NSWorkspace.shared
        if let editor = editors[root], let url = workspace.urlForApplication(withBundleIdentifier: editor.bundleIdentifier) {
            return (editor, url)
        }
        for editor in GitEditor.allCases {
            if let url = workspace.urlForApplication(withBundleIdentifier: editor.bundleIdentifier) { return (editor, url) }
        }
        return nil
    }

    static func appName(_ url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    func openInEditor() {
        guard let root = current?.root, let (editor, app) = editor(for: root) else {
            NSSound.beep()
            return
        }
        var target = URL(fileURLWithPath: root, isDirectory: true)
        if editor == .xcode, let project = Self.xcodeProject(in: root) { target = project }
        open([target], with: app)
    }

    func openInTerminal() {
        guard let root = current?.root,
              let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            NSSound.beep()
            return
        }
        open([URL(fileURLWithPath: root, isDirectory: true)], with: app)
    }

    func openOnGitHub() {
        guard let url = snapshot?.gitHubURL, NSWorkspace.shared.open(url) else {
            NSSound.beep()
            return
        }
    }

    func copyBranch() {
        guard let branch = snapshot?.branch.head ?? snapshot?.branch.oid else { return }
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            NSPasteboard.general.declareVorssaintSource()
            return NSPasteboard.general.setString(branch, forType: .string)
        }, then: { [weak self] copied in
            guard let self else { return }
            guard copied else {
                NSSound.beep()
                return
            }
            self.copied = true
            self.copiedWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.copied = false }
            self.copiedWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
        })
    }

    private func open(_ urls: [URL], with app: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: configuration) { _, error in
            if error != nil { DispatchQueue.main.async { NSSound.beep() } }
        }
    }

    /// The workspace, else the project, at the top of the folder.
    private static func xcodeProject(in root: String) -> URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        let pick = names.sorted().first { $0.hasSuffix(".xcworkspace") } ?? names.sorted().first { $0.hasSuffix(".xcodeproj") }
        return pick.map { URL(fileURLWithPath: root).appendingPathComponent($0) }
    }

    /// Accessibility in System Settings.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
