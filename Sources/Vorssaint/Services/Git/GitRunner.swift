// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: runs the read-only `git` commands behind the Git page, each
// bounded in time and output through BoundedProcessRunner, with an
// environment in which `git` never prompts. Called off the main thread.
// Compiled into the tests, which read a real repository made in a temporary
// folder.

/// Everything the page shows about one repository at one moment.
struct GitSnapshot: Equatable {
    let location: GitRepoLocation
    var branch: GitBranchInfo
    var changes: [GitFileChange]
    var lastCommit: GitCommitSummary?
    var operation: GitOperation?
    var stash: Int
    /// The remotes and their URLs, from the repository's config.
    var remotes: [GitRemoteEntry]
    var readAt: Date

    var counts: GitCounts { GitCounts(changes) }
    var listed: [GitFileChange] { GitPorcelain(branch: branch, changes: changes).listed(GitFormat.listedFiles) }
    /// The upstream's remote, then `origin`, then the first.
    var remoteURL: String? { GitRemote.preferred(remotes, upstream: branch.upstream) }

    var gitHubURL: URL? {
        remoteURL.flatMap { GitRemote.gitHubURL($0, branch: branch.upstream == nil ? nil : branch.head) }
    }

    /// The upstream's remote, for a fetch.
    var upstreamRemote: String? {
        guard let upstream = branch.upstream else { return nil }
        return remotes.map(\.name).filter { upstream.hasPrefix($0 + "/") }.max { $0.count < $1.count }
    }
}

enum GitRunner {
    enum Failure: Error, Equatable {
        case notRepository
        case timedOut
        case failed
    }

    static let statusTimeout: TimeInterval = 6
    static let fetchTimeout: TimeInterval = 30
    /// A status of this size is a hundred thousand changed paths; the rest is dropped.
    static let maxStatusBytes = 4 * 1024 * 1024

    static func run(_ executable: String, root: String, _ command: [String], timeout: TimeInterval = statusTimeout,
                    maxOutputBytes: Int = 256 * 1024) -> BoundedProcessRunner.Result {
        BoundedProcessRunner.run(executable, GitCLI.arguments(root, command), timeout: timeout,
                                 maxOutputBytes: maxOutputBytes, environment: GitCLI.environment())
    }

    /// Status, then the last commit when HEAD moved, the remotes when asked
    /// (or never read), the operation under way and the stash. The previous
    /// snapshot of the same repository saves the commands whose answer
    /// cannot have changed.
    static func snapshot(executable: String, location: GitRepoLocation, previous: GitSnapshot? = nil,
                         reloadsRemotes: Bool = false, now: Date = Date()) -> Result<GitSnapshot, Failure> {
        let status = run(executable, root: location.root, GitCLI.statusCommand, maxOutputBytes: maxStatusBytes)
        if status.timedOut { return .failure(.timedOut) }
        guard status.status == 0 else {
            return .failure(GitRepoLocator.repository(at: location.root) == nil ? .notRepository : .failed)
        }
        let porcelain = GitPorcelain.parse(status.output)
        let same = previous?.location == location ? previous : nil

        var commit: GitCommitSummary?
        if let oid = porcelain.branch.oid {
            if let same, same.branch.oid == oid, let kept = same.lastCommit {
                commit = kept
            } else {
                let log = run(executable, root: location.root, GitCLI.lastCommitCommand)
                commit = log.status == 0 && !log.timedOut ? GitCommitSummary.parse(log.output) : nil
            }
        }

        // The config is read again when the watcher says it changed.
        var remotes = same?.remotes ?? []
        if reloadsRemotes || same == nil {
            let config = run(executable, root: location.root, GitCLI.remotesCommand)
            // Exit 1 is no remote at all.
            remotes = config.status == 0 && !config.timedOut ? GitRemote.urls(fromConfig: config.output) : []
        }

        return .success(GitSnapshot(location: location, branch: porcelain.branch, changes: porcelain.changes,
                                    lastCommit: commit,
                                    operation: GitOperation.detect(gitDir: location.gitDir, commonDir: location.commonDir),
                                    stash: porcelain.branch.stash ?? GitRepoLocator.stashCount(commonDir: location.commonDir),
                                    remotes: remotes, readAt: now))
    }

    /// Fetches the upstream's remote without tags, quietly and without a
    /// prompt. True when it finished cleanly.
    @discardableResult
    static func fetch(executable: String, location: GitRepoLocation, remote: String?) -> Bool {
        let result = run(executable, root: location.root, GitCLI.fetchCommand(remote: remote), timeout: fetchTimeout)
        return result.status == 0 && !result.timedOut
    }
}
