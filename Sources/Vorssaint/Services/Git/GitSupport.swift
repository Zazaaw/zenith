// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the local Git status of the project the person works in, for
// the island's Git page, its home widget and the closed island's branch.
//
// Everything here is pure (Foundation only) and compiled into the tests: the
// porcelain v2 parser, the operation under way from the repository's state
// files, finding a repository's root, the remote's GitHub address, the
// editor's window title, the sticky choice of the current repository, the
// options and the formatting. GitRunner runs `git`; GitService watches and
// publishes. Read-only by design: nothing here pulls, pushes, commits or
// stages, and `git` never asks for anything.

/// The section's glyphs. The module wears the merge arrows (GitHub's page
/// already has the branch); a branch chip on the page keeps the branch.
enum GitSupportSymbols {
    static let module = "arrow.triangle.merge"
    static let branch = "arrow.triangle.branch"
}

// MARK: - Status

/// One changed path, as `git status --porcelain=v2` reports it.
struct GitFileChange: Equatable, Identifiable {
    enum Kind: Equatable { case ordinary, renamed, conflicted, untracked }

    let path: String
    /// Where a rename or copy came from.
    var originalPath: String? = nil
    /// The index's letter (`X`), `.` when unchanged.
    let index: Character
    /// The working tree's letter (`Y`), `.` when unchanged.
    let worktree: Character
    let kind: Kind

    var id: String { path }

    var isConflicted: Bool { kind == .conflicted }
    var isUntracked: Bool { kind == .untracked }
    var isStaged: Bool { (kind == .ordinary || kind == .renamed) && index != "." }
    var isModified: Bool { (kind == .ordinary || kind == .renamed) && worktree != "." }

    /// The one letter the page shows: `!` for a conflict, `?` untracked,
    /// otherwise the index's letter when staged and the tree's when not.
    var letter: String {
        switch kind {
        case .conflicted: return "!"
        case .untracked: return "?"
        case .ordinary, .renamed: return String(index != "." ? index : worktree)
        }
    }

    /// Conflicts first, then staged, modified and untracked, as they need the person.
    var rank: Int {
        if isConflicted { return 0 }
        if isStaged { return 1 }
        if isModified { return 2 }
        return 3
    }
}

/// What `# branch.*` and `# stash` headers say.
struct GitBranchInfo: Equatable {
    /// The commit HEAD is at; nil before the first commit.
    var oid: String?
    /// The branch's name; nil while HEAD is detached.
    var head: String?
    var upstream: String?
    var ahead: Int?
    var behind: Int?
    var stash: Int?

    var isDetached: Bool { head == nil && oid != nil }
    var isUnborn: Bool { oid == nil }
    var shortOID: String? { oid.map { String($0.prefix(7)) } }
}

struct GitCounts: Equatable {
    var staged = 0
    var modified = 0
    var untracked = 0
    var conflicted = 0

    var isClean: Bool { staged == 0 && modified == 0 && untracked == 0 && conflicted == 0 }

    init(staged: Int = 0, modified: Int = 0, untracked: Int = 0, conflicted: Int = 0) {
        self.staged = staged
        self.modified = modified
        self.untracked = untracked
        self.conflicted = conflicted
    }

    init(_ changes: [GitFileChange]) {
        for change in changes {
            if change.isConflicted { conflicted += 1 }
            if change.isUntracked { untracked += 1 }
            if change.isStaged { staged += 1 }
            if change.isModified { modified += 1 }
        }
    }
}

/// `git status --porcelain=v2 --branch -z`, read.
struct GitPorcelain: Equatable {
    var branch = GitBranchInfo()
    var changes: [GitFileChange] = []

    var counts: GitCounts { GitCounts(changes) }

    /// The changes the page lists, the ones that need the person first.
    func listed(_ limit: Int) -> [GitFileChange] {
        Array(changes.enumerated().sorted { ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset) }
            .map(\.element).prefix(limit))
    }

    private static let prefixes: Set<Character> = ["#", "1", "2", "u", "?", "!"]

    /// Reads records split by NUL. A rename's original path is the record
    /// after it. Anything of another shape is skipped, and a warning `git`
    /// printed in front of a record (the runner shares one pipe for both
    /// streams) is dropped up to its last newline.
    static func parse(_ data: Data) -> GitPorcelain {
        let records = data.split(separator: 0, omittingEmptySubsequences: false)
            .map { String(decoding: $0, as: UTF8.self) }
        var result = GitPorcelain()
        var index = 0
        while index < records.count {
            var record = records[index]
            index += 1
            if let first = record.first, !(prefixes.contains(first) && record.dropFirst().first == " "),
               let newline = record.lastIndex(of: "\n") {
                record = String(record[record.index(after: newline)...])
            }
            guard let first = record.first, record.dropFirst().first == " " else { continue }
            switch first {
            case "#":
                header(String(record.dropFirst(2)), into: &result.branch)
            case "1":
                let fields = record.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
                guard fields.count == 9, let xy = letters(fields[1]) else { continue }
                result.changes.append(GitFileChange(path: String(fields[8]), index: xy.0, worktree: xy.1, kind: .ordinary))
            case "2":
                let fields = record.split(separator: " ", maxSplits: 9, omittingEmptySubsequences: false)
                guard fields.count == 10, let xy = letters(fields[1]) else { continue }
                let original = index < records.count ? records[index] : nil
                index += 1
                result.changes.append(GitFileChange(path: String(fields[9]), originalPath: original,
                                                    index: xy.0, worktree: xy.1, kind: .renamed))
            case "u":
                let fields = record.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
                guard fields.count == 11, let xy = letters(fields[1]) else { continue }
                result.changes.append(GitFileChange(path: String(fields[10]), index: xy.0, worktree: xy.1, kind: .conflicted))
            case "?":
                let path = String(record.dropFirst(2))
                guard !path.isEmpty else { continue }
                result.changes.append(GitFileChange(path: path, index: "?", worktree: "?", kind: .untracked))
            default:
                continue // "!" ignored files are never asked for
            }
        }
        return result
    }

    private static func letters(_ field: Substring) -> (Character, Character)? {
        guard field.count == 2, let x = field.first, let y = field.last else { return nil }
        return (x, y)
    }

    private static func header(_ text: String, into branch: inout GitBranchInfo) {
        let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return }
        let value = String(parts[1])
        switch parts[0] {
        case "branch.oid": branch.oid = value == "(initial)" || value.isEmpty ? nil : value
        case "branch.head": branch.head = value == "(detached)" || value.isEmpty ? nil : value
        case "branch.upstream": branch.upstream = value.isEmpty ? nil : value
        case "branch.ab":
            let counts = value.split(separator: " ")
            guard counts.count == 2, counts[0].hasPrefix("+"), counts[1].hasPrefix("-"),
                  let ahead = Int(counts[0].dropFirst()), let behind = Int(counts[1].dropFirst()),
                  ahead >= 0, behind >= 0 else { return }
            branch.ahead = ahead
            branch.behind = behind
        case "stash": branch.stash = Int(value).flatMap { $0 >= 0 ? $0 : nil }
        default: return
        }
    }
}

/// The commit HEAD points at.
struct GitCommitSummary: Equatable {
    let shortSHA: String
    let subject: String
    let date: Date

    /// `git log -1 --format=%h%x00%s%x00%ct`.
    static func parse(_ data: Data) -> GitCommitSummary? {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: "\0", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var sha = String(parts[0])
        if let newline = sha.lastIndex(of: "\n") { sha = String(sha[sha.index(after: newline)...]) }
        guard !sha.isEmpty, sha.count <= 40, sha.allSatisfy(\.isHexDigit),
              let seconds = TimeInterval(parts[2].trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return GitCommitSummary(shortSHA: sha, subject: String(parts[1]), date: Date(timeIntervalSince1970: seconds))
    }
}

// MARK: - Operations under way

/// A merge, rebase, cherry-pick, revert, bisect or mailbox apply left open,
/// read from the state files `git` keeps in the repository's folder.
enum GitOperation: Equatable {
    case merge
    case rebase(step: Int?, total: Int?)
    case cherryPick
    case revert
    case bisect
    case applyMailbox

    /// `gitDir` holds HEAD and the state files; `commonDir` is the main
    /// repository's folder for a linked worktree (bisect keeps its log there).
    static func detect(gitDir: String, commonDir: String? = nil, fileManager: FileManager = .default) -> GitOperation? {
        func exists(_ name: String, in folder: String = gitDir) -> Bool {
            fileManager.fileExists(atPath: (folder as NSString).appendingPathComponent(name))
        }
        func number(_ name: String) -> Int? {
            let path = (gitDir as NSString).appendingPathComponent(name)
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if exists("rebase-merge") {
            return .rebase(step: number("rebase-merge/msgnum"), total: number("rebase-merge/end"))
        }
        if exists("rebase-apply") {
            if exists("rebase-apply/applying") { return .applyMailbox }
            return .rebase(step: number("rebase-apply/next"), total: number("rebase-apply/last"))
        }
        if exists("MERGE_HEAD") { return .merge }
        if exists("CHERRY_PICK_HEAD") { return .cherryPick }
        if exists("REVERT_HEAD") { return .revert }
        if exists("BISECT_LOG") || exists("BISECT_LOG", in: commonDir ?? gitDir) { return .bisect }
        return nil
    }
}

// MARK: - Finding the repository

/// A working tree's root and where `git` keeps its files for it.
struct GitRepoLocation: Equatable, Hashable {
    /// The working tree's top folder.
    let root: String
    /// HEAD, the index and the state files: `<root>/.git`, or a linked
    /// worktree's folder under the main repository.
    let gitDir: String
    /// Refs, packed refs, config and the stash's log.
    let commonDir: String

    var name: String { (root as NSString).lastPathComponent }
}

enum GitRepoLocator {
    /// Walks up from a file or folder to the first folder holding `.git`. The
    /// home folder and `/` are never a project's root (a dotfiles repository
    /// at home would claim every folder under it) unless `allowsHome`.
    static func locate(from path: String, home: String? = NSHomeDirectory(), allowsHome: Bool = false,
                       fileManager: FileManager = .default) -> GitRepoLocation? {
        let standardized = (path as NSString).standardizingPath
        guard standardized.hasPrefix("/") else { return nil }
        var isDirectory: ObjCBool = false
        var folder = standardized
        if !(fileManager.fileExists(atPath: standardized, isDirectory: &isDirectory) && isDirectory.boolValue) {
            folder = (standardized as NSString).deletingLastPathComponent
        }
        let homePath = home.map { ($0 as NSString).standardizingPath }
        var steps = 0
        while folder != "/" && !folder.isEmpty && steps < 64 {
            steps += 1
            if (folder as NSString).lastPathComponent != ".git", let location = repository(at: folder, fileManager: fileManager) {
                if folder == homePath && !allowsHome { return nil }
                return location
            }
            folder = (folder as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// The repository whose working tree starts at exactly this folder.
    static func repository(at folder: String, fileManager: FileManager = .default) -> GitRepoLocation? {
        let dotGit = (folder as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: dotGit, isDirectory: &isDirectory) else { return nil }
        let gitDir: String
        if isDirectory.boolValue {
            gitDir = dotGit
        } else {
            // A linked worktree or a submodule: `gitdir: <path>`, maybe relative.
            guard let text = try? String(contentsOfFile: dotGit, encoding: .utf8),
                  let line = text.split(whereSeparator: \.isNewline).first, line.hasPrefix("gitdir:") else { return nil }
            let target = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
            guard !target.isEmpty else { return nil }
            gitDir = absolute(target, relativeTo: folder)
        }
        guard fileManager.fileExists(atPath: (gitDir as NSString).appendingPathComponent("HEAD")) else { return nil }
        var commonDir = gitDir
        let commonFile = (gitDir as NSString).appendingPathComponent("commondir")
        if let text = try? String(contentsOfFile: commonFile, encoding: .utf8) {
            let target = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty { commonDir = absolute(target, relativeTo: gitDir) }
        }
        return GitRepoLocation(root: folder, gitDir: gitDir, commonDir: commonDir)
    }

    private static func absolute(_ path: String, relativeTo base: String) -> String {
        let joined = path.hasPrefix("/") ? path : (base as NSString).appendingPathComponent(path)
        return (joined as NSString).standardizingPath
    }

    /// Entries of the stash: lines of its reflog.
    static func stashCount(commonDir: String) -> Int {
        let path = (commonDir as NSString).appendingPathComponent("logs/refs/stash")
        guard let data = FileManager.default.contents(atPath: path) else { return 0 }
        return data.split(separator: UInt8(ascii: "\n")).count
    }

    /// Whether a path the repository's watcher reports changes what the page
    /// shows: HEAD, the index, refs, the stash, config and the operation
    /// files, but never objects, logs of other refs or a lock being taken.
    static func isRelevantChange(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        if name.hasSuffix(".lock") || path.contains("/objects/") { return false }
        if path.contains("/logs/") { return path.hasSuffix("/logs/refs/stash") }
        let watched: Set<String> = ["HEAD", "index", "packed-refs", "config", "MERGE_HEAD", "CHERRY_PICK_HEAD",
                                    "REVERT_HEAD", "BISECT_LOG", "FETCH_HEAD", "ORIG_HEAD", "msgnum", "next"]
        return watched.contains(name) || path.contains("/refs/") || path.contains("/rebase-merge")
            || path.contains("/rebase-apply")
    }
}

// MARK: - The remote on GitHub

struct GitRemoteEntry: Equatable {
    let name: String
    let url: String
}

enum GitRemote {
    /// A GitHub remote's page in the browser: https, `git@github.com:o/r.git`,
    /// `ssh://`, `git://`, and SSH host aliases such as `github.com-work`.
    /// Credentials in the URL are dropped. Any other host is nil.
    static func gitHubURL(_ remote: String) -> URL? {
        var text = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var host = ""
        var path = ""
        if let scheme = text.range(of: "://") {
            text = String(text[scheme.upperBound...])
            guard let slash = text.firstIndex(of: "/") else { return nil }
            var authority = String(text[..<slash])
            path = String(text[text.index(after: slash)...])
            if let at = authority.lastIndex(of: "@") { authority = String(authority[authority.index(after: at)...]) }
            if let colon = authority.firstIndex(of: ":") { authority = String(authority[..<colon]) }
            host = authority
        } else if let colon = text.firstIndex(of: ":"), !text[..<colon].contains("/") {
            // scp-like: [user@]host:owner/repo
            var authority = String(text[..<colon])
            if let at = authority.lastIndex(of: "@") { authority = String(authority[authority.index(after: at)...]) }
            host = authority
            path = String(text[text.index(after: colon)...])
        } else {
            return nil
        }
        host = host.lowercased()
        if host.hasPrefix("www.") { host.removeFirst(4) }
        // SSH aliases for a second account: `github.com-work`, `github-work`.
        let alias = (host.hasPrefix("github.com-") || host.hasPrefix("github-")) && !host.dropFirst(7).contains(".")
        guard host == "github.com" || alias else { return nil }
        while path.hasPrefix("/") { path.removeFirst() }
        while path.hasSuffix("/") { path.removeLast() }
        if path.lowercased().hasSuffix(".git") { path.removeLast(4) }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && !$0.contains(" ") && $0 != "." && $0 != ".." }) else {
            return nil
        }
        return URL(string: "https://github.com/" + parts.joined(separator: "/"))
    }

    /// The branch's page when it has one upstream, the repository's otherwise.
    static func gitHubURL(_ remote: String, branch: String?) -> URL? {
        guard let base = gitHubURL(remote) else { return nil }
        guard let branch, !branch.isEmpty else { return base }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#?%")
        guard let escaped = branch.addingPercentEncoding(withAllowedCharacters: allowed) else { return base }
        return URL(string: base.absoluteString + "/tree/" + escaped) ?? base
    }

    /// `git config --null --get-regexp ^remote\..*\.url$`: `key\nvalue\0`.
    static func urls(fromConfig data: Data) -> [GitRemoteEntry] {
        String(decoding: data, as: UTF8.self).split(separator: "\0").compactMap { entry in
            let pair = entry.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return nil }
            let key = pair[0].split(separator: "\n").last.map(String.init) ?? ""
            guard key.hasPrefix("remote."), key.hasSuffix(".url"), key.count > 11 else { return nil }
            return GitRemoteEntry(name: String(key.dropFirst(7).dropLast(4)), url: String(pair[1]))
        }
    }

    /// The upstream's remote (the longest remote name that starts it), then
    /// `origin`, then the first.
    static func preferred(_ remotes: [GitRemoteEntry], upstream: String?) -> String? {
        if let upstream {
            let matching = remotes.filter { upstream.hasPrefix($0.name + "/") }.max { $0.name.count < $1.name.count }
            if let matching { return matching.url }
        }
        return remotes.first { $0.name == "origin" }?.url ?? remotes.first?.url
    }
}

// MARK: - Editors

/// The editors whose focused window names a project, and how to read them.
enum GitEditor: String, CaseIterable {
    case vsCode, vsCodeInsiders, vsCodium, cursor, windsurf, zed, zedPreview, xcode

    var bundleIdentifier: String {
        switch self {
        case .vsCode: return "com.microsoft.VSCode"
        case .vsCodeInsiders: return "com.microsoft.VSCodeInsiders"
        case .vsCodium: return "com.vscodium"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .windsurf: return "com.exafunction.windsurf"
        case .zed: return "dev.zed.Zed"
        case .zedPreview: return "dev.zed.Zed-Preview"
        case .xcode: return "com.apple.dt.Xcode"
        }
    }

    static func from(bundleIdentifier: String?) -> GitEditor? {
        guard let bundleIdentifier else { return nil }
        return allCases.first { $0.bundleIdentifier == bundleIdentifier }
    }

    /// The app's own name, as it may close the window title.
    var appNames: [String] {
        switch self {
        case .vsCode: return ["Visual Studio Code"]
        case .vsCodeInsiders: return ["Visual Studio Code - Insiders", "Visual Studio Code Insiders"]
        case .vsCodium: return ["VSCodium"]
        case .cursor: return ["Cursor"]
        case .windsurf: return ["Windsurf"]
        case .zed, .zedPreview: return ["Zed", "Zed Preview"]
        case .xcode: return ["Xcode"]
        }
    }

    /// The VS Code family keeps its windows' folders in a JSON file, which
    /// resolves a folder name in a title to its path.
    var storageFolder: String? {
        switch self {
        case .vsCode: return "Code"
        case .vsCodeInsiders: return "Code - Insiders"
        case .vsCodium: return "VSCodium"
        case .cursor: return "Cursor"
        case .windsurf: return "Windsurf"
        case .zed, .zedPreview, .xcode: return nil
        }
    }

    /// Folder names a window title may hold, most likely first. VS Code's
    /// default is `file — folder` (and maybe the app's name), Zed's
    /// `folder — file`; a dirty mark, a workspace suffix and the app's name go.
    func folderNames(fromTitle title: String) -> [String] {
        var parts = title.components(separatedBy: " — ")
        if parts.count == 1 { parts = title.components(separatedBy: " – ") }
        if parts.count == 1 { parts = title.components(separatedBy: " - ") }
        let names = Set(appNames.map { $0.lowercased() })
        var cleaned: [String] = []
        for part in parts {
            var text = part.trimmingCharacters(in: .whitespaces)
            for mark in ["● ", "• ", "* "] where text.hasPrefix(mark) { text.removeFirst(mark.count) }
            for suffix in [" (Workspace)", " [SSH]", " [Extension Development Host]"] where text.hasSuffix(suffix) {
                text.removeLast(suffix.count)
            }
            if let bracket = text.range(of: " [", options: .backwards), text.hasSuffix("]") {
                text = String(text[..<bracket.lowerBound])
            }
            text = text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !names.contains(text.lowercased()), !cleaned.contains(text) else { continue }
            cleaned.append(text)
        }
        switch self {
        case .zed, .zedPreview: return cleaned
        default: return cleaned.count > 1 ? Array(cleaned.dropFirst().reversed()) + [cleaned[0]] : cleaned
        }
    }

    /// The folders the VS Code family's `storage.json` lists: the last
    /// active window, the open windows and the backups' folders.
    static func storageFolders(_ data: Data) -> [String] {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        var uris: [String] = []
        if let windows = object["windowsState"] as? [String: Any] {
            if let last = windows["lastActiveWindow"] as? [String: Any], let folder = last["folder"] as? String {
                uris.append(folder)
            }
            for window in windows["openedWindows"] as? [[String: Any]] ?? [] {
                if let folder = window["folder"] as? String { uris.append(folder) }
            }
        }
        if let backups = object["backupWorkspaces"] as? [String: Any] {
            for folder in backups["folders"] as? [[String: Any]] ?? [] {
                if let uri = folder["folderUri"] as? String { uris.append(uri) }
            }
        }
        var seen = Set<String>()
        return uris.compactMap { uri in
            guard let url = URL(string: uri), url.isFileURL else { return nil }
            let path = url.standardizedFileURL.path
            return seen.insert(path).inserted ? path : nil
        }
    }

    /// The path an accessibility document names: a file URL or a plain path.
    static func path(fromDocument document: String) -> String? {
        let text = document.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("/") { return text }
        guard let url = URL(string: text), url.isFileURL else { return nil }
        let path = url.standardizedFileURL.path
        return path.isEmpty ? nil : path
    }

    /// The first folder name that names a known folder, by its last component.
    static func resolve(names: [String], among folders: [String]) -> String? {
        for name in names {
            if let match = folders.first(where: { ($0 as NSString).lastPathComponent == name }) { return match }
        }
        for name in names {
            let lowered = name.lowercased()
            if let match = folders.first(where: { ($0 as NSString).lastPathComponent.lowercased() == lowered }) {
                return match
            }
        }
        return nil
    }
}

// MARK: - The current repository

/// Which repository the page follows. The newest sign wins: the editor
/// switching to another project, a terminal command started in one, or a
/// repository picked on the page. Leaving the editor for other apps keeps the
/// current one for `hold`; after that a pinned repository takes over (the
/// last one stays when nothing is pinned).
struct GitRepoSelector: Equatable {
    enum Source: String, Equatable { case editor, terminal, pinned, chosen }

    struct Current: Equatable {
        let root: String
        let source: Source
        /// When it became the current one.
        let since: Date
        /// When it was last seen in use.
        var seen: Date

        init(root: String, source: Source, since: Date, seen: Date? = nil) {
            self.root = root
            self.source = source
            self.since = since
            self.seen = seen ?? since
        }
    }

    static let defaultHold: TimeInterval = 20 * 60

    var hold: TimeInterval = GitRepoSelector.defaultHold
    private(set) var current: Current?
    /// The editor's project when it was last looked at, so looking again at
    /// the same project never takes over from a newer sign.
    private(set) var lastEditorRoot: String?

    init(hold: TimeInterval = GitRepoSelector.defaultHold) { self.hold = hold }

    /// An editor came to the front: its next project counts as new.
    mutating func editorActivated() { lastEditorRoot = nil }

    /// The editor in front shows this project (nil: none it can name).
    mutating func observeEditor(_ root: String?, now: Date) {
        guard let root else { return }
        defer { lastEditorRoot = root }
        guard let current else {
            self.current = Current(root: root, source: .editor, since: now)
            return
        }
        if current.root == root {
            self.current?.seen = now
        } else if root != lastEditorRoot || now.timeIntervalSince(current.seen) > hold {
            // Another project in the editor, or the newer sign has gone stale
            // while the editor stayed on its project.
            self.current = Current(root: root, source: .editor, since: now)
        }
    }

    /// A terminal command started in this project at `time`.
    mutating func observeTerminal(_ root: String, at time: Date) {
        if let current {
            if current.since > time { return }
            if current.root == root {
                self.current?.seen = max(current.seen, time)
                return
            }
        }
        current = Current(root: root, source: .terminal, since: time)
    }

    /// Picked on the page.
    mutating func choose(_ root: String, now: Date) {
        current = Current(root: root, source: .chosen, since: now)
    }

    /// A repository that went away (its folder deleted, or unpinned when it came from the pins).
    mutating func forget(_ root: String) {
        if current?.root == root { current = nil }
        if lastEditorRoot == root { lastEditorRoot = nil }
    }

    /// The repository to show now.
    func resolved(pinned: [String], now: Date) -> Current? {
        if let current, current.source != .pinned, now.timeIntervalSince(current.seen) <= hold { return current }
        if let first = pinned.first {
            if let current, current.root == first {
                return Current(root: first, source: .pinned, since: current.since, seen: current.seen)
            }
            return Current(root: first, source: .pinned, since: now)
        }
        return current
    }
}

// MARK: - Options

struct GitOptions: Equatable {
    /// Fetch choices in minutes.
    static let fetchChoices = [10, 30, 60]
    static let defaultFetchMinutes = 10

    var fromEditor = true
    var fromTerminal = true
    var fetches = false
    var fetchMinutes = GitOptions.defaultFetchMinutes
    var indicator = false
    /// Pinned repositories as stored: `~/…` under the home folder.
    var pinned: [String] = []

    static func current(in defaults: UserDefaults = .standard) -> GitOptions {
        func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        let minutes = defaults.object(forKey: DefaultsKey.notchGitFetchMinutes) as? Int ?? defaultFetchMinutes
        return GitOptions(fromEditor: flag(DefaultsKey.notchGitFromEditor, true),
                          fromTerminal: flag(DefaultsKey.notchGitFromTerminal, true),
                          fetches: flag(DefaultsKey.notchGitFetch, false),
                          fetchMinutes: fetchChoices.contains(minutes) ? minutes : defaultFetchMinutes,
                          indicator: flag(DefaultsKey.notchGitIndicator, false),
                          pinned: pinnedEntries(in: defaults))
    }

    static func pinnedEntries(in defaults: UserDefaults = .standard) -> [String] {
        var seen = Set<String>()
        return (defaults.stringArray(forKey: DefaultsKey.notchGitPinned) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Pinned paths, `~` expanded.
    func pinnedPaths(home: String = NSHomeDirectory()) -> [String] {
        pinned.map { Self.expanded($0, home: home) }
    }

    static func expanded(_ entry: String, home: String) -> String {
        if entry == "~" { return home }
        if entry.hasPrefix("~/") { return (home as NSString).appendingPathComponent(String(entry.dropFirst(2))) }
        return entry
    }

    /// How a path is stored: under the home folder with `~`.
    static func entry(forPath path: String, home: String) -> String {
        let standardized = (path as NSString).standardizingPath
        if standardized == home { return "~" }
        if standardized.hasPrefix(home + "/") { return "~" + standardized.dropFirst(home.count) }
        return standardized
    }

    var fetchInterval: TimeInterval { TimeInterval(fetchMinutes * 60) }
}

// MARK: - The executable

enum GitCLI {
    /// `git` without the `/usr/bin` shim, which offers to install the
    /// developer tools when they are missing: Homebrew's, then the selected
    /// developer folder's (the `xcode-select` link), the Command Line Tools'
    /// and Xcode's.
    static func candidates(developerDirectory: String?) -> [String] {
        var paths = ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
        if let developerDirectory, !developerDirectory.isEmpty {
            paths.append((developerDirectory as NSString).appendingPathComponent("usr/bin/git"))
        }
        paths += ["/Library/Developer/CommandLineTools/usr/bin/git",
                  "/Applications/Xcode.app/Contents/Developer/usr/bin/git"]
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    static func find(developerDirectory: String?, isExecutable: (String) -> Bool) -> String? {
        candidates(developerDirectory: developerDirectory).first(where: isExecutable)
    }

    private static let lock = NSLock()
    private static var cached: (path: String?, at: Date)?

    /// The first `git` found, looked for again every 30 seconds.
    static func executable(now: Date = Date()) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached, now >= cached.at, now.timeIntervalSince(cached.at) < 30 { return cached.path }
        let developer = try? FileManager.default.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link")
        let path = find(developerDirectory: developer) { FileManager.default.isExecutableFile(atPath: $0) }
        cached = (path, now)
        return path
    }

    static func isInstalled() -> Bool { executable() != nil }

    /// What every `git` runs with: never a prompt, never a pager or colour,
    /// never the index lock (`git status` would otherwise write the index, and
    /// the watcher would see its own refresh), and the C locale to parse.
    static func environment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = base
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_ASKPASS"] = "/usr/bin/false"
        environment["SSH_ASKPASS"] = "/usr/bin/false"
        environment["SSH_ASKPASS_REQUIRE"] = "never"
        environment["GIT_SSH_COMMAND"] = "ssh -o BatchMode=yes -o ConnectTimeout=10"
        environment["GIT_PAGER"] = "cat"
        environment["GIT_EDITOR"] = "/usr/bin/false"
        environment["LC_ALL"] = "C"
        environment.removeValue(forKey: "GIT_DIR")
        environment.removeValue(forKey: "GIT_WORK_TREE")
        environment.removeValue(forKey: "GIT_INDEX_FILE")
        return environment
    }

    /// Before every command: no colour, no credential prompt and no fsmonitor daemon.
    static let baseArguments = ["--no-optional-locks", "-c", "color.ui=false", "-c", "core.fsmonitor=false",
                                "-c", "credential.interactive=never"]

    static func arguments(_ root: String, _ command: [String]) -> [String] {
        baseArguments + ["-C", root] + command
    }

    static let statusCommand = ["status", "--porcelain=v2", "--branch", "--show-stash", "-z", "--untracked-files=normal"]
    static let lastCommitCommand = ["log", "-1", "--no-show-signature", "--format=%h%x00%s%x00%ct"]
    static let remotesCommand = ["config", "--null", "--get-regexp", "^remote\\..*\\.url$"]
    /// Only the upstream's remote, without tags or submodules.
    static func fetchCommand(remote: String?) -> [String] {
        ["fetch", "--quiet", "--no-tags", "--no-recurse-submodules", "--no-write-fetch-head"]
            + (remote.map { [$0] } ?? [])
    }
}

// MARK: - Formatting

/// The page's sizes, here so the island's sizing (compiled into the tests) reads them.
enum GitPageMetrics {
    /// The header, the pills, the commit and a few files.
    static let minimumHeight: CGFloat = 168
    static let rowHeight: CGFloat = 17
}

enum GitFormat {
    /// The page lists this many changed files.
    static let listedFiles = 8
    static let subjectLimit = 72

    static func subject(_ subject: String, limit: Int = subjectLimit) -> String {
        let line = subject.split(whereSeparator: \.isNewline).first.map(String.init) ?? subject
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// A long name with its middle cut out, as the closed island fits it.
    static func middleTruncated(_ text: String, limit: Int) -> String {
        guard text.count > limit, limit > 3 else { return text }
        let head = (limit - 1) / 2 + (limit - 1) % 2
        let tail = limit - 1 - head
        return String(text.prefix(head)) + "…" + String(text.suffix(tail))
    }

    /// The upstream's remote branch name without the remote: `origin/main` → `main`.
    static func upstreamBranch(_ upstream: String?) -> String? {
        guard let upstream, let slash = upstream.firstIndex(of: "/") else { return upstream }
        let branch = upstream[upstream.index(after: slash)...]
        return branch.isEmpty ? nil : String(branch)
    }

    static func relative(_ date: Date, language: String, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
