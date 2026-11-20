// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: pull requests from GitHub, read through the GitHub CLI.
///
/// Zenith asks the `gh` the person already signed in with, so it needs no
/// token of its own: one GraphQL search for open pull requests waiting for
/// their review, one for their own, each with the head commit's check rollup.
/// Everything here is pure or a file check, so it can be tested without `gh`.
enum GitHubSupport {
    /// The section's mark: a pull request.
    static let symbol = "arrow.triangle.pull"
    /// While the section is on, the inbox is read this often.
    static let refreshInterval: TimeInterval = 5 * 60
    /// A page that appears reads again when the inbox is older than this.
    static let staleAfter: TimeInterval = 2 * 60
    /// Pull requests asked for per group.
    static let pageSize = 8
    /// A stuck `gh` is given up on after this long.
    static let timeout: TimeInterval = 25

    static let reviewQuery = "is:pr is:open review-requested:@me archived:false sort:updated-desc"
    static let mineQuery = "is:pr is:open author:@me archived:false sort:updated-desc"

    static let graphQL = """
        query($review: String!, $mine: String!, $first: Int!) {
          viewer { login }
          review: search(query: $review, type: ISSUE, first: $first) { issueCount nodes { ...pr } }
          mine: search(query: $mine, type: ISSUE, first: $first) { issueCount nodes { ...pr } }
        }
        fragment pr on PullRequest {
          number title url isDraft updatedAt createdAt
          repository { nameWithOwner }
          author { login }
          commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        }
        """

    /// `gh api graphql` with the query and its variables (`-F` sends the
    /// count as a number).
    static func arguments(pageSize: Int = pageSize) -> [String] {
        ["api", "graphql",
         "-f", "query=\(graphQL)",
         "-f", "review=\(reviewQuery)",
         "-f", "mine=\(mineQuery)",
         "-F", "first=\(max(1, pageSize))"]
    }

    // MARK: Models

    /// The head commit's combined checks.
    enum Checks: String, Equatable, Sendable {
        case success, failure, pending, none

        /// GitHub's `StatusState`: SUCCESS, FAILURE, ERROR, PENDING, EXPECTED.
        init(rollup value: String?) {
            switch value?.uppercased() {
            case "SUCCESS": self = .success
            case "FAILURE", "ERROR": self = .failure
            case "PENDING", "EXPECTED": self = .pending
            default: self = .none
            }
        }

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            case .pending: return "clock.fill"
            case .none: return "circle.dashed"
            }
        }
    }

    struct PullRequest: Equatable, Identifiable, Sendable {
        let number: Int
        let title: String
        let url: URL
        let repository: String
        let author: String?
        let isDraft: Bool
        let updated: Date
        let checks: Checks
        /// When it was opened, for the day's recap (RecapSupport); nil when unknown.
        var created: Date? = nil

        var id: String { url.absoluteString }
    }

    struct Inbox: Equatable, Sendable {
        let login: String?
        let reviewRequested: [PullRequest]
        let reviewCount: Int
        let mine: [PullRequest]
        let mineCount: Int

        var isEmpty: Bool { reviewRequested.isEmpty && mine.isEmpty }
        var failingCount: Int { mine.filter { $0.checks == .failure }.count }
    }

    enum Failure: Error, Equatable, Sendable {
        /// `gh` has no account, or GitHub refused the one it has.
        case notSignedIn
        case failed
    }

    // MARK: Parsing

    /// The inbox from `gh api graphql`'s answer. The JSON is found even with
    /// a line `gh` wrote around it, since its output and errors share a pipe.
    static func inbox(from data: Data) -> Inbox? {
        guard let root = jsonObject(in: data), root["errors"] == nil || root["data"] is [String: Any],
              let body = root["data"] as? [String: Any] else { return nil }
        func group(_ key: String) -> (items: [PullRequest], count: Int)? {
            guard let search = body[key] as? [String: Any] else { return nil }
            let nodes = search["nodes"] as? [Any] ?? []
            let items = nodes.compactMap { ($0 as? [String: Any]).flatMap(pullRequest(from:)) }
            return (items, (search["issueCount"] as? Int) ?? items.count)
        }
        guard let review = group("review"), let mine = group("mine") else { return nil }
        let login = (body["viewer"] as? [String: Any])?["login"] as? String
        return Inbox(login: login, reviewRequested: review.items, reviewCount: max(review.count, review.items.count),
                     mine: mine.items, mineCount: max(mine.count, mine.items.count))
    }

    static func pullRequest(from node: [String: Any]) -> PullRequest? {
        guard let number = node["number"] as? Int,
              let link = node["url"] as? String, let url = URL(string: link), url.scheme == "https",
              let repository = (node["repository"] as? [String: Any])?["nameWithOwner"] as? String else { return nil }
        let rollup = ((((node["commits"] as? [String: Any])?["nodes"] as? [[String: Any]])?.last?["commit"]
            as? [String: Any])?["statusCheckRollup"] as? [String: Any])?["state"] as? String
        return PullRequest(number: number,
                           title: (node["title"] as? String).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? "",
                           url: url,
                           repository: repository,
                           author: (node["author"] as? [String: Any])?["login"] as? String,
                           isDraft: node["isDraft"] as? Bool ?? false,
                           updated: (node["updatedAt"] as? String).flatMap(date(from:)) ?? .distantPast,
                           checks: Checks(rollup: rollup),
                           created: (node["createdAt"] as? String).flatMap(date(from:)))
    }

    static func date(from text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    private static func jsonObject(in data: Data) -> [String: Any]? {
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { return root }
        guard let start = data.firstIndex(of: UInt8(ascii: "{")),
              let end = data.lastIndex(of: UInt8(ascii: "}")), start < end else { return nil }
        return try? JSONSerialization.jsonObject(with: data[start...end]) as? [String: Any]
    }

    /// What a failed run means. `gh` exits 4 when it has no account, and a
    /// token GitHub refuses comes back as HTTP 401.
    static func failure(status: Int32, output: String) -> Failure {
        if status == 4 || output.contains("gh auth login") || output.contains("HTTP 401")
            || output.contains("Bad credentials") { return .notSignedIn }
        return .failed
    }

    // MARK: The CLI

    /// Where `gh` is usually installed: Homebrew on both architectures, the
    /// official installer, MacPorts, Nix, version managers' shims and the
    /// person's own folders, then every absolute folder of `searchPath`.
    static func candidates(home: URL, searchPath: String? = nil) -> [URL] {
        let folders = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin",
                       home.appendingPathComponent(".local/bin").path,
                       home.appendingPathComponent("bin").path,
                       home.appendingPathComponent(".nix-profile/bin").path,
                       "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin",
                       home.appendingPathComponent(".local/share/mise/shims").path,
                       home.appendingPathComponent(".asdf/shims").path,
                       "/usr/bin"]
            + (searchPath ?? "").split(separator: ":").map(String.init).filter { $0.hasPrefix("/") }
        var seen = Set<String>()
        return folders.filter { seen.insert($0).inserted }
            .map { URL(fileURLWithPath: $0, isDirectory: true).appendingPathComponent("gh") }
    }

    static func executable(home: URL, searchPath: String? = nil,
                           isExecutable: (String) -> Bool = GitHubSupport.isExecutableFile) -> URL? {
        candidates(home: home, searchPath: searchPath).first { isExecutable($0.path) }
    }

    static func isExecutableFile(_ path: String) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory) && !directory.boolValue
            && FileManager.default.isExecutableFile(atPath: path)
    }

    /// The app's environment with `gh`'s folder first on PATH (an app opened
    /// from Finder has only the system folders), and nothing interactive:
    /// no prompts, no update notice, no colour.
    static func environment(for executable: URL,
                            base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = base
        environment["PATH"] = [executable.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin",
                               base["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"].joined(separator: ":")
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["GH_SPINNER_DISABLED"] = "1"
        environment["NO_COLOR"] = "1"
        environment["CLICOLOR"] = "0"
        return environment
    }
}

/// Zenith fork: finds `gh` without running anything on the way. The island
/// asks on every preference sync whether the GitHub section is available, so
/// the answer is a few file checks, remembered for a moment. A Terminal's
/// PATH (from the login shell) joins the search only once someone asks to
/// look again, since running the person's shell startup files is not free.
enum GitHubCLI {
    private static let lock = NSLock()
    private static var loginShellPath: String?
    private static var cached: (url: URL?, at: Date)?
    private static let cacheLifetime: TimeInterval = 10

    /// `gh`, from the usual folders, the app's PATH and any PATH a look again found.
    static func installed(now: Date = Date()) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        if let cached, now.timeIntervalSince(cached.at) < cacheLifetime, now >= cached.at { return cached.url }
        let path = [ProcessInfo.processInfo.environment["PATH"], loginShellPath].compactMap { $0 }.joined(separator: ":")
        let url = GitHubSupport.executable(home: FileManager.default.homeDirectoryForCurrentUser, searchPath: path)
        cached = (url, now)
        return url
    }

    static func isInstalled() -> Bool { installed() != nil }

    /// Asks the login shell for its PATH and searches again. It runs the
    /// person's shell, so it blocks for up to a few seconds: never call it
    /// on the main thread.
    static func lookAgain() -> URL? {
        let path = HomebrewEnvironment.loginShellExports(shellPath: HomebrewCommandBuilder.currentShellPath)["PATH"]
        lock.lock()
        if let path { loginShellPath = path }
        cached = nil
        lock.unlock()
        return installed()
    }
}
