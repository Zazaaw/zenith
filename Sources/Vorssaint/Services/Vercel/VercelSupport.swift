// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: recent Vercel deployments, in the Dynamic Island.
///
/// Zenith reads the personal account and every team the access token can see
/// (`GET /v2/teams`, then `GET /v6/deployments` per scope), merges them newest
/// first, and polls faster while something builds so the closed island can
/// follow the build and show how it ended. Everything here is pure, so it can
/// be tested without a token or the network.
enum VercelSupport {
    /// The section's mark: Vercel's own is a triangle.
    static let symbol = "triangle.fill"
    static let apiURL = URL(string: "https://api.vercel.com")!
    /// Deployments asked for per scope, and kept on the page across scopes.
    static let deploymentsPerScope = 10
    static let shownDeployments = 12
    /// Teams beyond this are not asked about, so one refresh stays a handful of requests.
    static let maximumTeams = 10
    /// While a deployment is queued or building: often enough to follow it.
    static let buildingInterval: TimeInterval = 15
    /// Nothing building: a new deployment shows up within two minutes.
    static let idleInterval: TimeInterval = 2 * 60
    /// After a failed refresh, back off rather than hammer the API.
    static let failureInterval: TimeInterval = 5 * 60
    static let failedBuildInterval: TimeInterval = 60
    /// A page that appears reads the list again when it is older than this.
    static let staleAfter: TimeInterval = 60
    /// How long the closed island shows how a build ended.
    static let resultDuration: TimeInterval = 8

    // MARK: Models

    enum State: String, Equatable, Sendable {
        case queued, initializing, building, ready, error, canceled, unknown

        /// Vercel's `readyState` / `state` values (QUEUED, INITIALIZING,
        /// BUILDING, READY, ERROR, CANCELED). Anything else reads as unknown.
        init(api value: String?) {
            switch value?.uppercased() {
            case "QUEUED": self = .queued
            case "INITIALIZING": self = .initializing
            case "BUILDING": self = .building
            case "READY": self = .ready
            case "ERROR": self = .error
            case "CANCELED", "CANCELLED": self = .canceled
            default: self = .unknown
            }
        }

        /// Still on its way: what the closed island follows.
        var inProgress: Bool { self == .queued || self == .initializing || self == .building }
        /// Done, one way or the other: what the closed island reports.
        var isFinished: Bool { self == .ready || self == .error || self == .canceled }

        var symbol: String {
            switch self {
            case .queued: return "clock"
            case .initializing: return "gearshape"
            case .building: return "hammer"
            case .ready: return "checkmark.circle.fill"
            case .error: return "xmark.octagon.fill"
            case .canceled: return "slash.circle"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    struct Team: Equatable, Sendable {
        let id: String
        let slug: String
        let name: String
    }

    struct Deployment: Equatable, Identifiable, Sendable {
        let uid: String
        /// The project's name.
        let project: String
        /// The deployment's own host, without a scheme (`my-app-abc123.vercel.app`).
        let host: String?
        let state: State
        let created: Date
        let isProduction: Bool
        let branch: String?
        let commitMessage: String?
        /// The dashboard's page for this deployment, with its build log.
        let inspectorURL: URL?
        /// The team it belongs to, nil for the personal account.
        let scope: String?

        var id: String { uid }

        /// A ready deployment opens itself; one still building, or one that
        /// failed, opens its page on the dashboard, where the build log is.
        var openURL: URL? {
            let site = host.flatMap { URL(string: "https://\($0)") }
            if state == .ready { return site ?? inspectorURL }
            return inspectorURL ?? site
        }

        /// The commit's first line, or nothing when it has none.
        var commitTitle: String? {
            commitMessage?.split(whereSeparator: \.isNewline).first
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    /// What the closed island shows: a build on its way, or how one just ended.
    enum Activity: Equatable, Sendable {
        case building(project: String, count: Int)
        case result(project: String, state: State)

        var project: String {
            switch self {
            case .building(let project, _), .result(let project, _): return project
            }
        }

        var state: State {
            switch self {
            case .building: return .building
            case .result(_, let state): return state
            }
        }
    }

    enum Outcome: Equatable, Sendable {
        case ready([Deployment])
        /// The token was refused everywhere: it is wrong, expired or revoked.
        case unauthorized
        case failed
    }

    /// One scope's answer: its HTTP status (nil when it never arrived) and
    /// its deployments when the body could be read.
    struct ScopeResult: Sendable {
        let status: Int?
        let deployments: [Deployment]?
    }

    // MARK: Token

    /// Vercel tokens are a single run of letters, digits, `_` or `-`. This
    /// only catches a paste that is plainly something else; Vercel decides.
    static func isPlausibleToken(_ value: String) -> Bool {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (16...256).contains(token.count) else { return false }
        return token.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "_" || $0 == "-"
        }
    }

    // MARK: Requests

    static func request(_ path: String, query: [URLQueryItem] = [], token: String,
                        userAgent: String, base: URL = apiURL) -> URLRequest {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))",
                         forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        return request
    }

    static func teamsRequest(token: String, userAgent: String) -> URLRequest {
        request("v2/teams", query: [URLQueryItem(name: "limit", value: String(maximumTeams))],
                token: token, userAgent: userAgent)
    }

    /// The latest deployments of the personal account (no `teamId`) or of one team.
    static func deploymentsRequest(teamID: String?, token: String, userAgent: String) -> URLRequest {
        var query = [URLQueryItem(name: "limit", value: String(deploymentsPerScope))]
        if let teamID { query.append(URLQueryItem(name: "teamId", value: teamID)) }
        return request("v6/deployments", query: query, token: token, userAgent: userAgent)
    }

    // MARK: Parsing

    static func teams(from data: Data) -> [Team]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let teams = root["teams"] as? [[String: Any]] else { return nil }
        return teams.compactMap { item in
            guard let id = item["id"] as? String, !id.isEmpty else { return nil }
            let slug = item["slug"] as? String ?? id
            let name = (item["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? slug
            return Team(id: id, slug: slug, name: name)
        }
    }

    static func deployments(from data: Data, scope: String?) -> [Deployment]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["deployments"] as? [[String: Any]] else { return nil }
        return items.compactMap { deployment(from: $0, scope: scope) }
    }

    static func deployment(from item: [String: Any], scope: String?) -> Deployment? {
        guard let uid = item["uid"] as? String ?? item["id"] as? String, !uid.isEmpty else { return nil }
        // `readyState` is the newer name; the list has long answered with `state`.
        let state = State(api: item["readyState"] as? String ?? item["state"] as? String)
        let milliseconds = number(item["created"]) ?? number(item["createdAt"]) ?? 0
        let meta = item["meta"] as? [String: Any] ?? [:]
        func text(_ key: String) -> String? {
            (meta[key] as? String).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        let host = (item["url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            .map { $0.replacingOccurrences(of: "https://", with: "") }
        let inspector = (item["inspectorUrl"] as? String).flatMap(URL.init(string:))
            .flatMap { $0.scheme == "https" ? $0 : nil }
        return Deployment(uid: uid,
                          project: (item["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? host ?? uid,
                          host: host,
                          state: state,
                          created: Date(timeIntervalSince1970: milliseconds / 1000),
                          isProduction: (item["target"] as? String) == "production",
                          branch: text("githubCommitRef") ?? text("gitlabCommitRef") ?? text("bitbucketCommitRef"),
                          commitMessage: text("githubCommitMessage") ?? text("gitlabCommitMessage")
                            ?? text("bitbucketCommitMessage"),
                          inspectorURL: inspector,
                          scope: scope)
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? Double) ?? (value as? Int).map(Double.init) ?? (value as? NSNumber)?.doubleValue
    }

    // MARK: Merging

    /// Every scope's deployments as one list, newest first, each once (a
    /// Hobby account can answer as itself and as its default team; the
    /// team's copy is kept, since it names where the deployment lives).
    static func merged(_ lists: [[Deployment]], limit: Int = shownDeployments) -> [Deployment] {
        var seen = Set<String>()
        return lists.joined()
            .sorted {
                if $0.created != $1.created { return $0.created > $1.created }
                if $0.uid != $1.uid { return $0.uid < $1.uid }
                return $0.scope != nil && $1.scope == nil
            }
            .filter { seen.insert($0.uid).inserted }
            .prefix(max(0, limit))
            .map { $0 }
    }

    /// The page's list when any scope answered. A token refused by every
    /// scope that answered is unauthorized; no answer at all is a failure.
    static func outcome(_ results: [ScopeResult]) -> Outcome {
        let read = results.compactMap(\.deployments)
        if !read.isEmpty { return .ready(merged(read)) }
        let refused = results.contains { $0.status == 401 || $0.status == 403 }
        return refused ? .unauthorized : .failed
    }

    /// Whether the page should name each deployment's team: only when the
    /// list mixes scopes.
    static func mixesScopes(_ deployments: [Deployment]) -> Bool {
        Set(deployments.map { $0.scope ?? "" }).count > 1
    }

    // MARK: Live activity

    /// Deployments seen on their way in `previous` that `current` shows finished.
    static func finished(previous: [Deployment], current: [Deployment]) -> [Deployment] {
        let wasRunning = Set(previous.filter(\.state.inProgress).map(\.uid))
        return current.filter { wasRunning.contains($0.uid) && $0.state.isFinished }
    }

    /// A build on its way wins over a result; a result shows for
    /// `resultDuration` after it was noticed, then nothing does.
    static func activity(deployments: [Deployment], result: Deployment?, resultSince: Date?,
                         now: Date) -> Activity? {
        let running = deployments.filter(\.state.inProgress)
        if let newest = running.max(by: { $0.created < $1.created }) {
            return .building(project: newest.project, count: running.count)
        }
        if let result, let resultSince, now.timeIntervalSince(resultSince) < resultDuration, now >= resultSince {
            return .result(project: result.project, state: result.state)
        }
        return nil
    }

    /// How long until the next refresh: quick while anything is on its way,
    /// slow otherwise, slower after a failure. A failure during a build
    /// still checks back within a minute, so the build is not lost for long.
    /// In the background, only for failure alerts, the pace is gentler, and a
    /// failure waits for the next turn like any other read.
    static func pollInterval(deployments: [Deployment], failed: Bool, background: Bool = false) -> TimeInterval {
        let building = deployments.contains(where: \.state.inProgress)
        if background { return building ? backgroundBuildingInterval : backgroundIdleInterval }
        if failed { return building ? failedBuildInterval : failureInterval }
        return building ? buildingInterval : idleInterval
    }

    // MARK: Failure alerts

    /// With nothing on screen asking, failure alerts read the list every two
    /// minutes while something builds and every ten otherwise.
    static let backgroundBuildingInterval: TimeInterval = 2 * 60
    static let backgroundIdleInterval: TimeInterval = 10 * 60
    /// A failure Zenith never saw building is announced only this soon after
    /// it was created; a build seen on its way is followed this long while
    /// its team drops out of a read.
    static let failureAlertWindow: TimeInterval = 6 * 60 * 60
    /// How far the Mac's clock and Vercel's may disagree.
    static let clockAllowance: TimeInterval = 60
    /// Deployments already announced, remembered so none is announced twice.
    static let rememberedFailures = 32
    /// A read after a long sleep announces no more than this many.
    static let failureAlertsPerRead = 3

    /// A notification when a build fails, even with the island closed. Off
    /// until switched on in the section's options.
    static func sendsFailureAlerts(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchVercelFailureAlerts)
    }

    /// What failure alerts keep of the last list read.
    struct FailureBaseline: Equatable, Sendable {
        /// Deployments seen on their way and not seen to finish since, with
        /// when each was created.
        var inProgress: [String: Date]
        /// Every deployment that list showed.
        var seen: Set<String>
        /// When the request for that list went out.
        var polledAt: Date
    }

    /// The baseline after reading `current`. A build seen on its way stays
    /// followed when its team is missing from this read, for up to
    /// `failureAlertWindow`, so a scope that failed once does not lose it.
    static func failureBaseline(previous: FailureBaseline?, current: [Deployment], polledAt: Date) -> FailureBaseline {
        let listed = Set(current.map(\.uid))
        var inProgress: [String: Date] = [:]
        for (uid, created) in previous?.inProgress ?? [:]
        where !listed.contains(uid) && polledAt.timeIntervalSince(created) < failureAlertWindow {
            inProgress[uid] = created
        }
        for deployment in current where deployment.state.inProgress {
            inProgress[deployment.uid] = deployment.created
        }
        return FailureBaseline(inProgress: inProgress, seen: listed, polledAt: polledAt)
    }

    /// The failed deployments to announce, newest first: one the baseline saw
    /// on its way, or one it never saw that was created after its read (give
    /// or take `clockAllowance`) and is already in error. One already
    /// announced, one seen finished before, or one older than
    /// `failureAlertWindow` is left alone, so the first read after launch,
    /// which only sets the baseline, never announces an old failure.
    static func failureAlerts(since baseline: FailureBaseline, current: [Deployment], polledAt: Date,
                              notified: Set<String>, limit: Int = failureAlertsPerRead) -> [Deployment] {
        var picked = Set<String>()
        return current
            .filter { deployment in
                guard deployment.state == .error, !notified.contains(deployment.uid),
                      picked.insert(deployment.uid).inserted else { return false }
                if baseline.inProgress[deployment.uid] != nil { return true }
                guard !baseline.seen.contains(deployment.uid) else { return false }
                return deployment.created >= baseline.polledAt.addingTimeInterval(-clockAllowance)
                    && polledAt.timeIntervalSince(deployment.created) < failureAlertWindow
            }
            .sorted { $0.created != $1.created ? $0.created > $1.created : $0.uid < $1.uid }
            .prefix(max(0, limit))
            .map { $0 }
    }

    /// The announced deployments, the newest last, at most `rememberedFailures`.
    static func remembering(_ uids: [String], in notified: [String]) -> [String] {
        let fresh = uids.reduce(into: [String]()) { list, uid in if !list.contains(uid) { list.append(uid) } }
        return Array((notified.filter { !fresh.contains($0) } + fresh).suffix(rememberedFailures))
    }

    /// The notification's body: the project and its branch. Never the commit
    /// message, as on the lock screen.
    static func failureBody(_ deployment: Deployment) -> String {
        [deployment.project, deployment.branch].compactMap { $0 }.joined(separator: " · ")
    }
}
