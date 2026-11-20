// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the Git page. The porcelain v2 parser on every kind of entry,
/// the operation under way from fixture repository folders, finding a
/// repository's root (linked worktrees included), the remote's GitHub page,
/// the editor's window title, the sticky choice of the current repository on
/// a fake clock, the options and the island's lists, and, when `git` is on
/// this Mac, a real repository made in a temporary folder: committed,
/// modified, staged and stashed there and read back as the page reads it.
/// Nothing touches a repository outside that folder.
enum GitTests {
    static func run(_ suite: TestSuite) {
        porcelain(suite)
        porcelainHeaders(suite)
        commitSummary(suite)
        operations(suite)
        discovery(suite)
        watcherFilter(suite)
        remotes(suite)
        editors(suite)
        selector(suite)
        options(suite)
        executable(suite)
        formatting(suite)
        island(suite)
        strings(suite)
        realRepository(suite)
    }

    private static func records(_ parts: [String]) -> Data {
        Data(parts.joined(separator: "\0").appending("\0").utf8)
    }

    // MARK: Porcelain

    private static func porcelain(_ suite: TestSuite) {
        let data = records([
            "# branch.oid 1234567890abcdef1234567890abcdef12345678",
            "# branch.head feat/island",
            "# branch.upstream origin/feat/island",
            "# branch.ab +2 -1",
            "# stash 3",
            "1 M. N... 100644 100644 100644 aaaaaaa bbbbbbb src/staged.swift",
            "1 .M N... 100644 100644 100644 aaaaaaa bbbbbbb src/modified file.swift",
            "1 MM N... 100644 100644 100644 aaaaaaa bbbbbbb both.swift",
            "1 A. N... 000000 100644 100644 0000000 bbbbbbb added.swift",
            "1 .D N... 100644 100644 000000 aaaaaaa aaaaaaa gone.swift",
            "2 R. N... 100644 100644 100644 aaaaaaa bbbbbbb R100 new name.swift", "old name.swift",
            "u UU N... 100644 100644 100644 100644 aaaaaaa bbbbbbb ccccccc conflict.swift",
            "? notes/todo.md",
            "! ignored.log",
        ])
        let parsed = GitPorcelain.parse(data)
        suite.expect(parsed.changes.count == 8, "every changed entry is read and the ignored one is not")
        let counts = parsed.counts
        suite.expect(counts == GitCounts(staged: 4, modified: 3, untracked: 1, conflicted: 1),
                     "staged counts the index's letters, modified the tree's, a file in both counts in both")
        suite.expect(parsed.changes.first { $0.path == "src/modified file.swift" } != nil,
                     "a path with a space stays whole")
        let renamed = parsed.changes.first { $0.kind == .renamed }
        suite.expect(renamed?.path == "new name.swift" && renamed?.originalPath == "old name.swift" && renamed?.letter == "R",
                     "a rename keeps its original path from the record after it")
        suite.expect(parsed.changes.first { $0.isConflicted }?.letter == "!"
                     && parsed.changes.first { $0.isUntracked }?.letter == "?"
                     && parsed.changes.first { $0.path == "gone.swift" }?.letter == "D"
                     && parsed.changes.first { $0.path == "both.swift" }?.letter == "M",
                     "each change shows one letter")
        let listed = parsed.listed(8).map(\.path)
        suite.expect(listed.first == "conflict.swift" && listed.last == "notes/todo.md"
                     && listed.firstIndex(of: "src/staged.swift")! < listed.firstIndex(of: "src/modified file.swift")!,
                     "conflicts lead the list, then staged, modified and untracked")
        suite.expect(parsed.listed(3).count == 3, "the list stops at its limit")
        suite.expect(GitPorcelain.parse(Data()).changes.isEmpty && GitPorcelain.parse(Data("garbage".utf8)).changes.isEmpty,
                     "nothing, or noise, reads as no change")
        let warned = Data("warning: could not open directory 'x/': Permission denied\n# branch.oid abc1234\0# branch.head main\0? a.txt\0".utf8)
        let afterWarning = GitPorcelain.parse(warned)
        suite.expect(afterWarning.branch.oid == "abc1234" && afterWarning.branch.head == "main" && afterWarning.counts.untracked == 1,
                     "a warning git printed in front of a record is dropped")
    }

    private static func porcelainHeaders(_ suite: TestSuite) {
        let tracked = GitPorcelain.parse(records(["# branch.oid 1234567890abcdef1234567890abcdef12345678",
                                                  "# branch.head main", "# branch.upstream origin/main",
                                                  "# branch.ab +5 -0"])).branch
        suite.expect(tracked.head == "main" && tracked.upstream == "origin/main" && tracked.ahead == 5 && tracked.behind == 0
                     && !tracked.isDetached && !tracked.isUnborn && tracked.shortOID == "1234567",
                     "the branch header with an upstream gives the branch and ahead and behind")
        let local = GitPorcelain.parse(records(["# branch.oid 1234567890abcdef1234567890abcdef12345678",
                                                "# branch.head topic"])).branch
        suite.expect(local.head == "topic" && local.upstream == nil && local.ahead == nil && local.behind == nil && local.stash == nil,
                     "without an upstream there is no ahead or behind")
        let unborn = GitPorcelain.parse(records(["# branch.oid (initial)", "# branch.head main"])).branch
        suite.expect(unborn.isUnborn && unborn.head == "main" && !unborn.isDetached, "a branch before its first commit")
        let detached = GitPorcelain.parse(records(["# branch.oid abcdef0123456789abcdef0123456789abcdef01",
                                                   "# branch.head (detached)"])).branch
        suite.expect(detached.isDetached && detached.head == nil && detached.shortOID == "abcdef0", "a detached HEAD keeps its commit")
        let odd = GitPorcelain.parse(records(["# branch.ab 5 3", "# stash -2", "# branch.future thing"])).branch
        suite.expect(odd.ahead == nil && odd.stash == nil, "malformed counts are ignored")
    }

    private static func commitSummary(_ suite: TestSuite) {
        let commit = GitCommitSummary.parse(Data("abc1234\0Fix the island: no more jumps\01795000000\n".utf8))
        suite.expect(commit?.shortSHA == "abc1234" && commit?.subject == "Fix the island: no more jumps"
                     && commit?.date == Date(timeIntervalSince1970: 1_795_000_000), "the last commit's sha, subject and time")
        suite.expect(GitCommitSummary.parse(Data("fatal: your current branch 'main' does not have any commits yet\n".utf8)) == nil,
                     "a repository without commits has no last commit")
    }

    // MARK: Operations

    private static func temporaryFolder(_ name: String) -> String {
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("com.vorssaint.tests.git-\(name)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    private static func write(_ text: String, to path: String) {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private static func operations(_ suite: TestSuite) {
        let base = temporaryFolder("operations")
        defer { try? FileManager.default.removeItem(atPath: base) }
        func fixture(_ name: String, _ files: [String: String]) -> String {
            let dir = (base as NSString).appendingPathComponent(name)
            write("ref: refs/heads/main\n", to: dir + "/HEAD")
            for (file, contents) in files { write(contents, to: dir + "/" + file) }
            return dir
        }
        suite.expect(GitOperation.detect(gitDir: fixture("clean", [:])) == nil, "a quiet repository has no operation")
        suite.expect(GitOperation.detect(gitDir: fixture("merge", ["MERGE_HEAD": "abc\n"])) == .merge, "a merge left open")
        suite.expect(GitOperation.detect(gitDir: fixture("rebase", ["rebase-merge/msgnum": "3\n", "rebase-merge/end": "7\n"]))
                     == .rebase(step: 3, total: 7), "an interactive rebase and its step")
        suite.expect(GitOperation.detect(gitDir: fixture("apply", ["rebase-apply/next": "2", "rebase-apply/last": "5"]))
                     == .rebase(step: 2, total: 5), "a rebase that applies patches")
        suite.expect(GitOperation.detect(gitDir: fixture("am", ["rebase-apply/applying": "", "rebase-apply/next": "1"]))
                     == .applyMailbox, "git am is not a rebase")
        suite.expect(GitOperation.detect(gitDir: fixture("pick", ["CHERRY_PICK_HEAD": "abc"])) == .cherryPick, "a cherry-pick")
        suite.expect(GitOperation.detect(gitDir: fixture("revert", ["REVERT_HEAD": "abc"])) == .revert, "a revert")
        suite.expect(GitOperation.detect(gitDir: fixture("bisect", ["BISECT_LOG": "# bad"])) == .bisect, "a bisect")
        let common = fixture("common", ["BISECT_LOG": "# bad"])
        suite.expect(GitOperation.detect(gitDir: fixture("linked", [:]), commonDir: common) == .bisect,
                     "a linked worktree finds the bisect in the main repository")
        suite.expect(GitOperation.detect(gitDir: fixture("both", ["rebase-merge/msgnum": "1", "MERGE_HEAD": "abc"]))
                     == .rebase(step: 1, total: nil), "a rebase that stopped on a merge reads as the rebase")
    }

    // MARK: Discovery

    private static func discovery(_ suite: TestSuite) {
        let base = (temporaryFolder("discovery") as NSString).standardizingPath
        defer { try? FileManager.default.removeItem(atPath: base) }
        let repo = base + "/Code/zenith"
        write("ref: refs/heads/main\n", to: repo + "/.git/HEAD")
        write("print(1)\n", to: repo + "/Sources/App/main.swift")
        let found = GitRepoLocator.locate(from: repo + "/Sources/App/main.swift", home: base)
        suite.expect(found?.root == repo && found?.gitDir == repo + "/.git" && found?.commonDir == repo + "/.git"
                     && found?.name == "zenith", "a file deep in the tree finds its repository's root")
        suite.expect(GitRepoLocator.locate(from: repo + "/Sources/App/not-there.swift", home: base)?.root == repo,
                     "a file not saved yet still finds its folder's repository")
        suite.expect(GitRepoLocator.locate(from: repo + "/.git/COMMIT_EDITMSG", home: base)?.root == repo,
                     "the commit message being edited belongs to its repository")
        suite.expect(GitRepoLocator.locate(from: repo, home: base)?.root == repo, "the root itself")

        let nested = repo + "/Packages/Kit"
        write("ref: refs/heads/main\n", to: nested + "/.git/HEAD")
        suite.expect(GitRepoLocator.locate(from: nested + "/Package.swift", home: base)?.root == nested,
                     "the nearest repository wins")

        let linked = base + "/Code/zenith-feature"
        write("gitdir: ../zenith/.git/worktrees/feature\n", to: linked + "/.git")
        write("ref: refs/heads/feature\n", to: repo + "/.git/worktrees/feature/HEAD")
        write("../..\n", to: repo + "/.git/worktrees/feature/commondir")
        let worktree = GitRepoLocator.locate(from: linked + "/README.md", home: base)
        suite.expect(worktree?.root == linked && worktree?.gitDir == repo + "/.git/worktrees/feature"
                     && worktree?.commonDir == repo + "/.git", "a linked worktree reads its own HEAD and the main refs")

        let broken = base + "/Code/broken"
        write("not a pointer\n", to: broken + "/.git")
        suite.expect(GitRepoLocator.locate(from: broken + "/file", home: base) == nil, "a .git file of another shape is no repository")
        let empty = base + "/Code/empty"
        try? FileManager.default.createDirectory(atPath: empty + "/.git", withIntermediateDirectories: true)
        suite.expect(GitRepoLocator.repository(at: empty) == nil, "a .git folder without HEAD is no repository")

        write("ref: refs/heads/main\n", to: base + "/.git/HEAD")
        write("x\n", to: base + "/Notes/today.md")
        suite.expect(GitRepoLocator.locate(from: base + "/Notes/today.md", home: base) == nil,
                     "a dotfiles repository at home never claims the folders under it")
        suite.expect(GitRepoLocator.locate(from: base + "/Notes/today.md", home: base, allowsHome: true)?.root == base,
                     "unless asked, as pinning home is")
        suite.expect(GitRepoLocator.locate(from: "relative/path") == nil, "a relative path is never resolved")

        write("a\nb\nc\n", to: repo + "/.git/logs/refs/stash")
        suite.expect(GitRepoLocator.stashCount(commonDir: repo + "/.git") == 3
                     && GitRepoLocator.stashCount(commonDir: nested + "/.git") == 0, "the stash counts its reflog's lines")
    }

    private static func watcherFilter(_ suite: TestSuite) {
        let git = "/Users/dev/Code/zenith/.git"
        let relevant = ["/HEAD", "/index", "/refs/heads/main", "/packed-refs", "/MERGE_HEAD", "/config",
                        "/rebase-merge/msgnum", "/logs/refs/stash", "/FETCH_HEAD"]
        let ignored = ["/index.lock", "/objects/ab/cdef", "/logs/HEAD", "/logs/refs/heads/main", "/HEAD.lock", "/description"]
        suite.expect(relevant.allSatisfy { GitRepoLocator.isRelevantChange(git + $0) }
                     && ignored.allSatisfy { !GitRepoLocator.isRelevantChange(git + $0) },
                     "the watcher reads again for HEAD, the index, refs and the operation files, never for objects or locks")
    }

    // MARK: Remotes

    private static func remotes(_ suite: TestSuite) {
        let page = "https://github.com/satuvisual/zenith"
        let mapped = ["https://github.com/satuvisual/zenith.git", "https://github.com/satuvisual/zenith",
                      "http://github.com/satuvisual/zenith/", "https://user:ghp_secret@github.com/satuvisual/zenith.git",
                      "git@github.com:satuvisual/zenith.git", "github.com:satuvisual/zenith",
                      "ssh://git@github.com/satuvisual/zenith.git", "ssh://git@github.com:22/satuvisual/zenith",
                      "git://github.com/satuvisual/zenith.git", "git+ssh://git@github.com/satuvisual/zenith.git",
                      "git@github.com-work:satuvisual/zenith.git", "git@github-work:satuvisual/zenith.git",
                      "https://www.github.com/satuvisual/zenith.git", "  git@GitHub.com:satuvisual/zenith.git\n"]
        for remote in mapped {
            suite.expect(GitRemote.gitHubURL(remote)?.absoluteString == page, "\(remote) opens the repository on GitHub")
        }
        let unmapped = ["https://gitlab.com/satuvisual/zenith.git", "git@bitbucket.org:a/b.git", "git@github.com:onlyowner",
                        "/Users/dev/backups/zenith.git", "file:///Users/dev/zenith.git", "https://github.com/a/b/c",
                        "git@github.company.com:a/b.git", "", "https://github.com.evil.example/a/b"]
        for remote in unmapped {
            suite.expect(GitRemote.gitHubURL(remote) == nil, "\(remote) is not a GitHub repository")
        }
        suite.expect(GitRemote.gitHubURL("git@github.com:satuvisual/zenith.git", branch: "feat/git notch")?.absoluteString
                     == page + "/tree/feat/git%20notch", "a branch opens its own page")
        suite.expect(GitRemote.gitHubURL("git@github.com:satuvisual/zenith.git", branch: nil)?.absoluteString == page,
                     "without an upstream the repository's page opens")

        let config = Data("remote.origin.url\ngit@github.com:satuvisual/zenith.git\0remote.upstream.url\nhttps://github.com/vorssaint/vorssaint-utils.git\0".utf8)
        let entries = GitRemote.urls(fromConfig: config)
        suite.expect(entries.map(\.name) == ["origin", "upstream"], "the config's remotes in order")
        suite.expect(GitRemote.preferred(entries, upstream: "upstream/main") == "https://github.com/vorssaint/vorssaint-utils.git"
                     && GitRemote.preferred(entries, upstream: nil) == "git@github.com:satuvisual/zenith.git"
                     && GitRemote.preferred([], upstream: "origin/main") == nil,
                     "the upstream's remote, else origin")
        let slashed = [GitRemoteEntry(name: "team", url: "a"), GitRemoteEntry(name: "team/fork", url: "b")]
        suite.expect(GitRemote.preferred(slashed, upstream: "team/fork/main") == "b", "the longest remote name that starts the upstream")
    }

    // MARK: Editors

    private static func editors(_ suite: TestSuite) {
        suite.expect(GitEditor.from(bundleIdentifier: "com.microsoft.VSCode") == .vsCode
                     && GitEditor.from(bundleIdentifier: "dev.zed.Zed") == .zed
                     && GitEditor.from(bundleIdentifier: "com.apple.dt.Xcode") == .xcode
                     && GitEditor.from(bundleIdentifier: "com.apple.Safari") == nil && GitEditor.from(bundleIdentifier: nil) == nil,
                     "editors by their bundle id")
        suite.expect(GitEditor.vsCode.folderNames(fromTitle: "GitSupport.swift — Swift").first == "Swift",
                     "VS Code's file — folder")
        suite.expect(GitEditor.vsCode.folderNames(fromTitle: "● GitSupport.swift — zenith — Visual Studio Code").first == "zenith",
                     "a dirty mark and the app's name go")
        suite.expect(GitEditor.cursor.folderNames(fromTitle: "zenith (Workspace)").first == "zenith", "a workspace's suffix goes")
        suite.expect(GitEditor.zed.folderNames(fromTitle: "zenith — GitSupport.swift").first == "zenith", "Zed's folder — file")
        suite.expect(GitEditor.vsCode.folderNames(fromTitle: "Visual Studio Code").isEmpty, "a title of only the app names nothing")

        let known = ["/Users/dev/Code/zenith", "/Users/dev/Code/Other"]
        suite.expect(GitEditor.resolve(names: ["Settings.json", "zenith"], among: known) == "/Users/dev/Code/zenith"
                     && GitEditor.resolve(names: ["other"], among: known) == "/Users/dev/Code/Other"
                     && GitEditor.resolve(names: ["nowhere"], among: known) == nil,
                     "a title's folder name finds the known folder of that name")
        suite.expect(GitEditor.path(fromDocument: "file:///Users/dev/Code/zenith/a%20b.swift") == "/Users/dev/Code/zenith/a b.swift"
                     && GitEditor.path(fromDocument: "/Users/dev/x.swift") == "/Users/dev/x.swift"
                     && GitEditor.path(fromDocument: "https://example.com") == nil,
                     "an accessibility document is a file URL or a path")
        let storage = Data("""
            {"windowsState":{"lastActiveWindow":{"folder":"file:///Users/dev/Code/zenith"},
             "openedWindows":[{"folder":"file:///Users/dev/Code/site"},{"workspace":{"id":"x"}}]},
             "backupWorkspaces":{"folders":[{"folderUri":"file:///Users/dev/Code/zenith"},{"folderUri":"vscode-remote://ssh/x"}]}}
            """.utf8)
        suite.expect(GitEditor.storageFolders(storage) == ["/Users/dev/Code/zenith", "/Users/dev/Code/site"]
                     && GitEditor.storageFolders(Data("[]".utf8)).isEmpty,
                     "VS Code's storage lists its windows' local folders once each")
    }

    // MARK: The current repository

    private static func selector(_ suite: TestSuite) {
        let start = Date(timeIntervalSince1970: 1_795_000_000)
        func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }
        let a = "/Code/a", b = "/Code/b", c = "/Code/c", d = "/Code/d", pinned = "/Code/pinned"
        var selector = GitRepoSelector(hold: 20 * 60)
        suite.expect(selector.resolved(pinned: [], now: start) == nil
                     && selector.resolved(pinned: [pinned], now: start)?.source == .pinned,
                     "nothing seen: the first pinned repository, or none")

        selector.observeEditor(a, now: at(0))
        suite.expect(selector.resolved(pinned: [pinned], now: at(1))?.root == a
                     && selector.resolved(pinned: [], now: at(1))?.source == .editor, "the editor's project")
        selector.observeTerminal(b, at: at(5))
        suite.expect(selector.resolved(pinned: [], now: at(6))?.root == b, "a newer command in another repository takes over")
        selector.observeEditor(a, now: at(8))
        suite.expect(selector.resolved(pinned: [], now: at(8))?.root == b,
                     "looking again at the same editor project never undoes a newer sign")
        selector.editorActivated()
        selector.observeEditor(a, now: at(10))
        suite.expect(selector.resolved(pinned: [], now: at(10))?.root == a, "coming back to the editor brings its project back")
        selector.observeTerminal(b, at: at(9))
        suite.expect(selector.resolved(pinned: [], now: at(11))?.root == a, "a command older than the switch does not")

        // Other apps in front: the editor's project holds, then the pin takes over.
        suite.expect(selector.resolved(pinned: [pinned], now: at(10 + 19 * 60))?.root == a, "it stays while away for a while")
        let later = selector.resolved(pinned: [pinned], now: at(10 + 21 * 60))
        suite.expect(later?.root == pinned && later?.source == .pinned, "after the hold the first pinned repository shows")
        suite.expect(selector.resolved(pinned: [], now: at(10 + 21 * 60))?.root == a, "with nothing pinned the last one stays")
        selector.observeEditor(a, now: at(10 + 22 * 60))
        suite.expect(selector.resolved(pinned: [pinned], now: at(10 + 22 * 60))?.root == a, "seen again, it is fresh again")

        selector.choose(c, now: at(2000))
        suite.expect(selector.resolved(pinned: [], now: at(2001))?.source == .chosen, "a pick on the page")
        selector.observeEditor(a, now: at(2003))
        suite.expect(selector.resolved(pinned: [], now: at(2003))?.root == c, "the same editor project leaves the pick alone")
        selector.observeEditor(d, now: at(2005))
        suite.expect(selector.resolved(pinned: [], now: at(2005))?.root == d, "another editor project replaces it")

        // The editor stays on its project while a command elsewhere goes stale.
        selector.observeTerminal(b, at: at(2010))
        selector.observeEditor(d, now: at(2010 + 10))
        suite.expect(selector.resolved(pinned: [], now: at(2020))?.root == b, "the command holds while it is fresh")
        selector.observeEditor(d, now: at(2010 + 21 * 60))
        suite.expect(selector.resolved(pinned: [], now: at(2010 + 21 * 60))?.root == d,
                     "once stale, the editor still in front takes back its project")

        selector.forget(d)
        suite.expect(selector.current == nil && selector.resolved(pinned: [pinned], now: at(5000))?.root == pinned,
                     "a repository that went away gives way to the pin")
        var fresh = GitRepoSelector()
        fresh.observeEditor(nil, now: start)
        suite.expect(fresh.current == nil && GitRepoSelector.defaultHold == 20 * 60, "an editor naming no project changes nothing")
    }

    // MARK: Options

    private static func options(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.git"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "the test suite's defaults open")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let fallback = GitOptions.current(in: defaults)
        suite.expect(fallback.fromEditor && fallback.fromTerminal && !fallback.fetches && !fallback.indicator
                     && fallback.fetchMinutes == 10 && fallback.pinned.isEmpty,
                     "by default it follows the editor and the terminal, fetches nothing and keeps the closed island quiet")
        defaults.set([" ~/Code/zenith ", "~/Code/zenith", "", "/Volumes/Work/site"], forKey: DefaultsKey.notchGitPinned)
        defaults.set(7, forKey: DefaultsKey.notchGitFetchMinutes)
        defaults.set(true, forKey: DefaultsKey.notchGitFetch)
        let set = GitOptions.current(in: defaults)
        suite.expect(set.pinned == ["~/Code/zenith", "/Volumes/Work/site"] && set.fetchMinutes == 10 && set.fetches
                     && set.fetchInterval == 600, "pins are trimmed and kept once; an unknown interval falls back")
        suite.expect(set.pinnedPaths(home: "/Users/dev") == ["/Users/dev/Code/zenith", "/Volumes/Work/site"]
                     && GitOptions.entry(forPath: "/Users/dev/Code/zenith/", home: "/Users/dev") == "~/Code/zenith"
                     && GitOptions.entry(forPath: "/Users/dev", home: "/Users/dev") == "~"
                     && GitOptions.entry(forPath: "/Users/developer/x", home: "/Users/dev") == "/Users/developer/x",
                     "pins under home are stored with ~")
        let registered = Defaults.registeredDefaults
        let keys = [DefaultsKey.notchGitFromEditor, DefaultsKey.notchGitFromTerminal, DefaultsKey.notchGitFetch,
                    DefaultsKey.notchGitFetchMinutes, DefaultsKey.notchGitIndicator, DefaultsKey.notchGitPinned]
        suite.expect(keys.allSatisfy { registered[$0] != nil } && registered[DefaultsKey.notchGitRecent] == nil
                     && registered[DefaultsKey.notchGitIndicator] as? Bool == false
                     && registered[DefaultsKey.notchGitFetch] as? Bool == false,
                     "the options are backed up, the repositories seen lately stay on this Mac")
    }

    private static func executable(_ suite: TestSuite) {
        let candidates = GitCLI.candidates(developerDirectory: "/Applications/Xcode-beta.app/Contents/Developer")
        suite.expect(!candidates.contains("/usr/bin/git") && candidates.first == "/opt/homebrew/bin/git"
                     && candidates.contains("/Applications/Xcode-beta.app/Contents/Developer/usr/bin/git"),
                     "git is never the /usr/bin shim that offers to install the developer tools")
        suite.expect(GitCLI.find(developerDirectory: nil, isExecutable: { $0 == "/Library/Developer/CommandLineTools/usr/bin/git" })
                     == "/Library/Developer/CommandLineTools/usr/bin/git"
                     && GitCLI.find(developerDirectory: nil, isExecutable: { _ in false }) == nil,
                     "the first one there, or none")
        let environment = GitCLI.environment(base: ["PATH": "/usr/bin", "GIT_DIR": "/elsewhere", "HOME": "/Users/dev"])
        suite.expect(environment["GIT_TERMINAL_PROMPT"] == "0" && environment["GIT_OPTIONAL_LOCKS"] == "0"
                     && environment["GIT_DIR"] == nil && environment["HOME"] == "/Users/dev"
                     && environment["GIT_SSH_COMMAND"]?.contains("BatchMode=yes") == true,
                     "git never prompts, never takes the index lock, and reads only the repository asked for")
        let arguments = GitCLI.arguments("/Code/a", GitCLI.statusCommand)
        suite.expect(arguments.starts(with: ["--no-optional-locks"]) && arguments.contains("credential.interactive=never")
                     && arguments.contains("--porcelain=v2") && arguments.contains("-z"),
                     "status asks for porcelain v2 with NUL separators")
        let fetch = GitCLI.fetchCommand(remote: "origin")
        suite.expect(fetch.first == "fetch" && fetch.contains("--no-tags") && fetch.last == "origin",
                     "a fetch reads only the upstream's remote, without tags")
        let read = [GitCLI.statusCommand, GitCLI.lastCommitCommand, GitCLI.remotesCommand].map { $0.first ?? "" }
        suite.expect(read == ["status", "log", "config"] && !GitCLI.remotesCommand.contains("--add")
                     && !(GitCLI.statusCommand + GitCLI.lastCommitCommand).contains { ["push", "pull", "commit", "add"].contains($0) },
                     "the page only reads")
    }

    private static func formatting(_ suite: TestSuite) {
        let cut = GitFormat.middleTruncated("feature/a-very-long-branch-name", limit: 16)
        suite.expect(cut.count == 16 && cut.hasPrefix("feature/") && cut.hasSuffix("e") && cut.contains("…"),
                     "a long branch loses its middle")
        suite.expect(GitFormat.middleTruncated("main", limit: 16) == "main", "a short one stays")
        let subject = GitFormat.subject(String(repeating: "word ", count: 30) + "\nbody")
        suite.expect(subject.count <= GitFormat.subjectLimit && subject.hasSuffix("…") && !subject.contains("\n"),
                     "a long subject is cut and keeps its first line")
        suite.expect(GitFormat.upstreamBranch("origin/feat/x") == "feat/x" && GitFormat.upstreamBranch(nil) == nil,
                     "the upstream's branch without its remote")
    }

    // MARK: The island

    private static func island(_ suite: TestSuite) {
        let modules = NotchModule.allCases
        suite.expect(NotchModule.git.shortcutKey == "h" && Set(modules.map(\.shortcutKey)).count == modules.count,
                     "Git has a shortcut of its own")
        suite.expect(modules.filter { $0.symbol == NotchModule.git.symbol } == [.git]
                     && Set(modules.map(ZenithIslandPalette.hex)).count == modules.count,
                     "Git's glyph and colour are its own")
        suite.expect(NotchCompactActivity.git.module == .git && NotchCompactActivity.git.symbol == NotchModule.git.symbol,
                     "the branch in the closed island opens the page")
        suite.expect(NotchSupport.compactActivities(timer: false, downloads: false, agents: false, calendar: false, music: true,
                                                    keepAwake: true, devServers: true, git: true)
                     == [.music, .devServers, .git, .keepAwake],
                     "the branch waits behind music and the dev servers, before Keep Awake")
        suite.expect(NotchSupport.compactActivity(timer: true, downloads: false, music: false, git: true) == .timer
                     && NotchSupport.compactActivity(timer: false, downloads: false, music: false, git: true) == .git,
                     "it shows when nothing more pressing does")
        suite.expect(ZenithHomeWidget.git.module == .git && ZenithHomeWidget.git.isAvailable(modules: [.git])
                     && !ZenithHomeWidget.git.isAvailable(modules: [.controls]) && ZenithHomeWidget.git.hex == ZenithIslandPalette.hex(.git),
                     "the home widget follows the page and wears its colour")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.git(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 54 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words Git, with curly apostrophes and no em dash")
            suite.expect([text.ahead, text.behind, text.moreFiles, text.openIn, text.minutes, text.branchValue].allSatisfy { $0.contains("%@") },
                         "\(language.rawValue) places its values")
        }
    }

    // MARK: A real repository

    /// Setup commands for the temporary repository only, with no global or
    /// system config, so no hook, signing or template of this Mac runs.
    @discardableResult
    private static func setup(_ executable: String, _ root: String, _ arguments: [String]) -> Bool {
        var environment = GitCLI.environment()
        environment["GIT_CONFIG_GLOBAL"] = "/dev/null"
        environment["GIT_CONFIG_NOSYSTEM"] = "1"
        let result = BoundedProcessRunner.run(executable,
                                              ["-c", "user.name=Zenith Tests", "-c", "user.email=tests@example.invalid",
                                               "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main",
                                               "-c", "core.hooksPath=/dev/null", "-C", root] + arguments,
                                              timeout: 20, maxOutputBytes: 64 * 1024, environment: environment)
        return result.status == 0 && !result.timedOut
    }

    private static func realRepository(_ suite: TestSuite) {
        guard let executable = GitCLI.executable() else {
            print("  (git is not on this Mac: the real repository check is skipped)")
            return
        }
        let base = (temporaryFolder("real") as NSString).standardizingPath
        defer { try? FileManager.default.removeItem(atPath: base) }
        let root = base + "/zenith"
        try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        guard setup(executable, root, ["init", "-q"]), let location = GitRepoLocator.repository(at: root) else {
            suite.expect(false, "a temporary repository is made")
            return
        }
        suite.expect(GitRepoLocator.locate(from: root + "/Sources/x.swift", home: base) == location,
                     "the new repository is found from inside it")

        write("one\n", to: root + "/a.txt")
        guard case .success(let unborn) = GitRunner.snapshot(executable: executable, location: location) else {
            suite.expect(false, "a repository without commits reads")
            return
        }
        suite.expect(unborn.branch.head == "main" && unborn.branch.isUnborn && unborn.lastCommit == nil
                     && unborn.counts == GitCounts(untracked: 1) && unborn.remotes.isEmpty && unborn.operation == nil,
                     "before the first commit: the branch, no commit and one untracked file")

        write("two\n", to: root + "/b.txt")
        setup(executable, root, ["add", "a.txt", "b.txt"])
        guard setup(executable, root, ["commit", "-q", "-m", "First commit"]) else {
            suite.expect(false, "the temporary repository commits")
            return
        }
        write("one, changed\n", to: root + "/a.txt")
        write("two, staged\n", to: root + "/b.txt")
        setup(executable, root, ["add", "b.txt"])
        write("new\n", to: root + "/c d.txt")
        guard case .success(let dirty) = GitRunner.snapshot(executable: executable, location: location, previous: unborn) else {
            suite.expect(false, "a dirty repository reads")
            return
        }
        suite.expect(dirty.branch.head == "main" && dirty.branch.oid?.count == 40 && dirty.branch.upstream == nil
                     && dirty.counts == GitCounts(staged: 1, modified: 1, untracked: 1)
                     && dirty.listed.map(\.path) == ["b.txt", "a.txt", "c d.txt"]
                     && dirty.lastCommit?.subject == "First commit" && dirty.lastCommit?.shortSHA.count ?? 0 >= 7
                     && dirty.stash == 0 && dirty.gitHubURL == nil,
                     "committed, modified, staged and untracked read back as git sees them")
        let index = (try? FileManager.default.attributesOfItem(atPath: location.gitDir + "/index"))?[.modificationDate] as? Date
        _ = GitRunner.snapshot(executable: executable, location: location, previous: dirty)
        let after = (try? FileManager.default.attributesOfItem(atPath: location.gitDir + "/index"))?[.modificationDate] as? Date
        suite.expect(index != nil && index == after && !FileManager.default.fileExists(atPath: location.gitDir + "/index.lock"),
                     "reading never writes the index")

        setup(executable, root, ["remote", "add", "origin", "git@github.com:satuvisual/zenith.git"])
        guard case .success(let remote) = GitRunner.snapshot(executable: executable, location: location, previous: dirty,
                                                              reloadsRemotes: true) else {
            suite.expect(false, "the repository reads again with its remote")
            return
        }
        suite.expect(remote.remotes == [GitRemoteEntry(name: "origin", url: "git@github.com:satuvisual/zenith.git")]
                     && remote.gitHubURL?.absoluteString == "https://github.com/satuvisual/zenith"
                     && remote.lastCommit == dirty.lastCommit,
                     "the remote opens on GitHub, and an unmoved HEAD keeps its commit")

        let linked = base + "/zenith-feature"
        if setup(executable, root, ["worktree", "add", "-q", "-b", "feature", linked]),
           let worktree = GitRepoLocator.locate(from: linked + "/a.txt", home: base),
           case .success(let feature) = GitRunner.snapshot(executable: executable, location: worktree) {
            suite.expect(worktree.root == linked && worktree.commonDir == location.gitDir
                         && feature.branch.head == "feature" && feature.counts.isClean,
                         "a linked worktree reads its own branch")
        } else {
            suite.expect(false, "a linked worktree is made and read")
        }

        setup(executable, root, ["stash", "push", "-q"])
        guard case .success(let stashed) = GitRunner.snapshot(executable: executable, location: location, previous: remote) else {
            suite.expect(false, "the repository reads after a stash")
            return
        }
        suite.expect(stashed.stash == 1 && GitRepoLocator.stashCount(commonDir: location.commonDir) == 1
                     && stashed.counts == GitCounts(untracked: 1),
                     "the stash counts, and only the untracked file is left")

        try? FileManager.default.removeItem(atPath: root + "/.git")
        if case .failure(let failure) = GitRunner.snapshot(executable: executable, location: location) {
            suite.expect(failure == .notRepository, "a repository whose folder went away says so")
        } else {
            suite.expect(false, "a repository whose folder went away says so")
        }
    }
}
