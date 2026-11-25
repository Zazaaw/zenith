// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Watchtower, the Pocket part that watches the person's sites
/// and the safety of their work. Its decisions on plain values, so they can
/// be tested without the network, `git` or `tmutil`: which URLs count, what
/// an answer means, what Vercel and Netlify say about a site's deploys, what
/// `git` and `tmutil` print, and which repos come first.

// MARK: - Preferences

enum PocketWatchtowerDefaults {
    static let watchSites = "zenithPocketWatchSites"       // Bool, default true
    /// The sites to watch, as the person typed them (normalised on use). None by default.
    static let sites = "zenithPocketSites"                 // [String], default []
    static let watchSafety = "zenithPocketWatchSafety"     // Bool, default true
    /// The folder scanned for repos; absent means ~/Developer.
    static let safetyFolder = "zenithPocketSafetyFolder"   // String path

    /// ZenithSecretStore name of the optional Netlify personal access token.
    /// Vercel's token is the one the island's Vercel page keeps
    /// (`VercelService.secretName`).
    static let netlifySecret = "pocket-netlify-token"

    static let keys = [watchSites, sites, watchSafety, safetyFolder]

    static func watchesSites(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: watchSites) as? Bool ?? true
    }

    static func watchesSafety(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: watchSafety) as? Bool ?? true
    }

    static func siteList(in defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: sites) ?? []
    }

    static func folder(in defaults: UserDefaults = .standard, home: String = NSHomeDirectory()) -> String {
        let saved = defaults.string(forKey: safetyFolder)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? PocketWatchtowerSupport.defaultFolder(home: home) : saved
    }
}

enum PocketWatchtowerSupport {
    /// Sites every ten minutes, repos every half hour, while Pocket's link runs.
    static let sitesInterval: TimeInterval = 10 * 60
    static let safetyInterval: TimeInterval = 30 * 60
    /// The first round waits a little after the link starts, so it doesn't
    /// join the burst of everything else starting.
    static let sitesFirstDelay: TimeInterval = 5
    static let safetyFirstDelay: TimeInterval = 30
    static let requestTimeout: TimeInterval = 10
    /// Slower than this is slow.
    static let slowAfterMs = 1500
    static let maximumSites = 20
    /// Repos the phone is sent (the riskiest), repos looked at, and how deep.
    static let maximumListedRepos = 12
    static let maximumScannedRepos = 200
    static let maximumDepth = 3
    static let gitTimeout: TimeInterval = 6
    static let tmutilTimeout: TimeInterval = 10
    /// How much of an error page is read to tell "paused" from "down".
    static let maximumBodyBytes = 32 * 1024

    static func defaultFolder(home: String) -> String {
        (home as NSString).appendingPathComponent("Developer")
    }

    /// "~/Developer" for a folder under the home folder.
    static func displayPath(_ path: String, home: String = NSHomeDirectory()) -> String {
        let standard = (path as NSString).standardizingPath
        let homePath = (home as NSString).standardizingPath
        if standard == homePath { return "~" }
        if standard.hasPrefix(homePath + "/") { return "~" + standard.dropFirst(homePath.count) }
        return standard
    }

    // MARK: Sites

    /// A typed site as a URL: https assumed, http or https only, a host
    /// required, the fragment dropped. nil for anything else.
    static func siteURL(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = components.host, !host.isEmpty, host.contains(".") || host == "localhost",
              components.user == nil, components.password == nil
        else { return nil }
        components.scheme = scheme
        components.host = host.lowercased()
        components.fragment = nil
        if components.path.isEmpty { components.path = "/" }
        return components.url
    }

    /// The person's list as URLs, without repeats, at most `maximumSites`.
    static func siteURLs(_ list: [String]) -> [URL] {
        var seen = Set<String>()
        return list.compactMap(siteURL).filter { seen.insert($0.absoluteString).inserted }.prefix(maximumSites).map { $0 }
    }

    /// The name the phone shows: the host without "www.", and the path when
    /// there is one ("example.com/blog").
    static func siteName(_ url: URL) -> String {
        var host = url.host ?? url.absoluteString
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let path = url.path == "/" ? "" : url.path
        return host + path
    }

    /// What one request found.
    struct Probe: Equatable {
        var status: Int?
        var latencyMs: Int?
        /// Header names lowercased.
        var headers: [String: String] = [:]
        /// The start of an error page, when one was read.
        var body: String?
        var timedOut = false
        /// The Mac itself is offline: nothing is known about the site.
        var offline = false
    }

    /// HEAD first; a server that refuses or mishandles HEAD gets a GET.
    /// A timeout isn't asked again: that would only double the wait.
    static func needsGet(after head: Probe) -> Bool {
        if head.timedOut || head.offline { return false }
        guard let status = head.status else { return true }
        return status >= 400 && status != 402
    }

    /// Vercel's and Netlify's words for a site its owner's plan stopped
    /// serving (usage limits, a paused or disabled deployment).
    static let pausedMarkers = ["deployment_paused", "deployment_disabled", "this deployment is temporarily paused",
                                "deployment has been disabled", "paused as it reached", "usage limits",
                                "site not available"]

    static func isPaused(_ probe: Probe) -> Bool {
        if probe.status == 402 { return true }
        if let error = probe.headers["x-vercel-error"]?.lowercased(),
           error.contains("paused") || error.contains("disabled") || error.contains("payment") { return true }
        guard let status = probe.status, status >= 400, let body = probe.body?.lowercased() else { return false }
        return pausedMarkers.contains { body.contains($0) }
    }

    /// 2xx and 3xx are up (slow past 1.5 s), 402 or a host's "paused" page
    /// is paused, 5xx, other 4xx and no answer are down. 401 and 403 are a
    /// protected site that answers; 429 says nothing about it.
    static func classify(_ probe: Probe) -> PocketSites.Site.Status {
        if probe.offline { return .unknown }
        if isPaused(probe) { return .paused }
        guard let status = probe.status else { return .down }
        switch status {
        case 200..<400, 401, 403:
            return (probe.latencyMs ?? 0) > slowAfterMs ? .slow : .up
        case 429:
            return .unknown
        default:
            return .down
        }
    }

    /// "vercel" or "netlify" from the answer's headers, nil otherwise.
    static func host(_ headers: [String: String]) -> String? {
        let server = headers["server"]?.lowercased() ?? ""
        if server.contains("vercel") || headers["x-vercel-id"] != nil { return "vercel" }
        if server.contains("netlify") || headers["x-nf-request-id"] != nil { return "netlify" }
        return nil
    }

    /// The URL errors that mean the Mac is offline, not the site.
    static func isOffline(_ code: URLError.Code) -> Bool {
        [.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .callIsActive].contains(code)
    }

    /// When the site entered its status: kept while it stays, now when it changes.
    static func since(previous: PocketSites.Site?, status: PocketSites.Site.Status, now: Date) -> Date? {
        guard let previous, previous.status == status else { return now }
        return previous.since ?? previous.checkedAt ?? now
    }

    // MARK: Hosts' APIs

    /// A Vercel project or Netlify site: its domains and its latest
    /// production deploy.
    struct HostedSite: Equatable {
        let id: String
        let name: String
        let domains: [String]
        var deployState: String?
        var deployedAt: Date?
    }

    /// One word per state across both hosts: ready, building, queued, error, canceled.
    static func deployState(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case "ready", "current": return "ready"
        case "error", "failed": return "error"
        case "building", "initializing", "processing", "uploading", "uploaded", "preparing", "prepared": return "building"
        case "queued", "enqueued", "new", "pending_review", "accepted": return "queued"
        case "canceled", "cancelled", "skipped", "rejected": return "canceled"
        default: return raw
        }
    }

    /// The site's project or site at its host, by its host name, with or without "www.".
    static func match(_ url: URL, in sites: [HostedSite]) -> HostedSite? {
        guard let host = url.host?.lowercased() else { return nil }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return sites.first { $0.domains.contains(host) } ?? sites.first { $0.domains.contains(bare) || $0.domains.contains("www." + bare) }
    }

    static let netlifyAPI = URL(string: "https://api.netlify.com/api/v1")!

    /// `GET /v9/projects`: the projects of the personal account or one team.
    static func vercelProjectsRequest(teamID: String?, token: String, userAgent: String) -> URLRequest {
        var query = [URLQueryItem(name: "limit", value: "100")]
        if let teamID { query.append(URLQueryItem(name: "teamId", value: teamID)) }
        var request = VercelSupport.request("v9/projects", query: query, token: token, userAgent: userAgent)
        request.timeoutInterval = requestTimeout * 2
        return request
    }

    /// Each project's domains (its production aliases, its own `.vercel.app`)
    /// and the newest production deploy: a build that failed after the live
    /// one reads as an error.
    static func vercelProjects(from data: Data) -> [HostedSite]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = root["projects"] as? [[String: Any]] else { return nil }
        return projects.compactMap { project in
            guard let id = project["id"] as? String, let name = project["name"] as? String else { return nil }
            var domains = [name.lowercased() + ".vercel.app"]
            let production = (project["targets"] as? [String: Any])?["production"] as? [String: Any]
            for alias in (production?["alias"] as? [Any] ?? []) + (project["alias"] as? [Any] ?? []) {
                if let domain = alias as? String { domains.append(domain.lowercased()) }
                if let domain = (alias as? [String: Any])?["domain"] as? String { domains.append(domain.lowercased()) }
            }
            var candidates: [(state: String?, at: Date?)] = []
            if let production { candidates.append((production["readyState"] as? String, date(milliseconds: production["createdAt"]))) }
            for deployment in project["latestDeployments"] as? [[String: Any]] ?? []
            where (deployment["target"] as? String) == "production" {
                candidates.append((deployment["readyState"] as? String, date(milliseconds: deployment["createdAt"])))
            }
            let newest = candidates.max { ($0.at ?? .distantPast) < ($1.at ?? .distantPast) }
            var seen = Set<String>()
            return HostedSite(id: id, name: name, domains: domains.filter { seen.insert($0).inserted },
                              deployState: deployState(newest?.state), deployedAt: newest?.at)
        }
    }

    /// The person's Netlify sites (`GET /sites`), one page of up to 100.
    static func netlifySitesRequest(token: String, userAgent: String) -> URLRequest {
        netlifyRequest(path: "sites", query: [URLQueryItem(name: "filter", value: "all"),
                                              URLQueryItem(name: "per_page", value: "100")],
                       token: token, userAgent: userAgent)
    }

    /// A site's latest deploy (`GET /sites/{id}/deploys?per_page=3`).
    static func netlifyDeploysRequest(siteID: String, token: String, userAgent: String) -> URLRequest {
        netlifyRequest(path: "sites/\(siteID)/deploys", query: [URLQueryItem(name: "per_page", value: "3")],
                       token: token, userAgent: userAgent)
    }

    static func netlifyRequest(path: String, query: [URLQueryItem], token: String, userAgent: String) -> URLRequest {
        var components = URLComponents(url: netlifyAPI.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = requestTimeout * 2
        return request
    }

    /// Each site's domains (its own, its custom one and aliases) and the
    /// deploy that is live.
    static func netlifySites(from data: Data) -> [HostedSite]? {
        guard let sites = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return sites.compactMap { site in
            guard let id = site["id"] as? String, !id.isEmpty else { return nil }
            var domains: [String] = []
            for key in ["url", "ssl_url"] {
                if let text = site[key] as? String, let host = URL(string: text)?.host { domains.append(host.lowercased()) }
            }
            if let custom = site["custom_domain"] as? String, !custom.isEmpty { domains.append(custom.lowercased()) }
            domains += (site["domain_aliases"] as? [String] ?? []).map { $0.lowercased() }
            let published = site["published_deploy"] as? [String: Any]
            var seen = Set<String>()
            return HostedSite(id: id, name: site["name"] as? String ?? id, domains: domains.filter { seen.insert($0).inserted },
                              deployState: deployState(published?["state"] as? String),
                              deployedAt: date(iso: published?["published_at"]) ?? date(iso: published?["created_at"]))
        }
    }

    /// The newest production deploy in a list of deploys, the newest of any
    /// kind when none says production.
    static func netlifyLatestDeploy(from data: Data) -> (state: String?, at: Date?)? {
        guard let deploys = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !deploys.isEmpty else { return nil }
        let deploy = deploys.first { ($0["context"] as? String) == "production" } ?? deploys[0]
        return (deployState(deploy["state"] as? String), date(iso: deploy["created_at"]))
    }

    static func date(milliseconds value: Any?) -> Date? {
        guard let number = (value as? NSNumber)?.doubleValue, number > 0 else { return nil }
        return Date(timeIntervalSince1970: number / 1000)
    }

    static func date(iso value: Any?) -> Date? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return precise.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    /// A probed site with what its host's API knows. A site whose headers
    /// named no host but that the API knows still takes the host's name.
    static func site(_ url: URL, probe: Probe, previous: PocketSites.Site?, certificate: Date?,
                     vercel: [HostedSite]?, netlify: [HostedSite]?, now: Date) -> PocketSites.Site {
        // Offline, the Mac knows nothing new: the last reading stands.
        if probe.offline, let previous { return previous }
        let status = classify(probe)
        var host = self.host(probe.headers)
        var hosted: HostedSite?
        if host != "netlify", let match = vercel.flatMap({ match(url, in: $0) }) { hosted = match; host = "vercel" }
        if hosted == nil, host != "vercel", let match = netlify.flatMap({ match(url, in: $0) }) { hosted = match; host = "netlify" }
        return PocketSites.Site(url: url.absoluteString, name: siteName(url), status: status, httpStatus: probe.status,
                                latencyMs: probe.latencyMs, checkedAt: now, host: host,
                                deployState: hosted?.deployState, deployedAt: hosted?.deployedAt,
                                certificateExpiresAt: url.scheme == "https" ? (certificate ?? previous?.certificateExpiresAt) : nil,
                                since: since(previous: previous, status: status, now: now))
    }

    // MARK: Repos

    /// Folders never walked into: hidden ones, dependencies and build output.
    static let skippedFolders: Set<String> = ["node_modules", "Pods", "Carthage", "DerivedData", "vendor", "build", "dist",
                                              "target", "Library"]

    /// The repos in `root`, at most `maximumDepth` folders down, without
    /// entering a repo once found. `children` lists a folder's subfolders
    /// (nil when it can't be read); `isRepository` says whether one holds `.git`.
    static func repositories(in root: String, maximumDepth: Int = maximumDepth, limit: Int = maximumScannedRepos,
                             children: (String) -> [String]?, isRepository: (String) -> Bool) -> [String] {
        var found: [String] = []
        var queue: [(path: String, depth: Int)] = [(root, 0)]
        while !queue.isEmpty, found.count < limit {
            let (folder, depth) = queue.removeFirst()
            if isRepository(folder) {
                found.append(folder)
                continue
            }
            guard depth < maximumDepth, let names = children(folder) else { continue }
            for name in names.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
            where !name.hasPrefix(".") && !skippedFolders.contains(name) {
                queue.append(((folder as NSString).appendingPathComponent(name), depth + 1))
            }
        }
        return found
    }

    /// `path` relative to `root` ("personal/zenith"); the folder's own name for the root itself.
    static func relativePath(_ path: String, root: String) -> String {
        let base = (root as NSString).standardizingPath
        let full = (path as NSString).standardizingPath
        if full.hasPrefix(base + "/") { return String(full.dropFirst(base.count + 1)) }
        return (full as NSString).lastPathComponent
    }

    /// Read-only `git` commands, nothing that writes or reaches the network.
    static let statusCommand = ["status", "--porcelain=v2", "--branch", "-z", "--untracked-files=normal"]
    static let remoteCommand = ["remote"]
    /// Commits on any local branch that no remote-tracking branch holds.
    static let unpushedCommand = ["rev-list", "--count", "--branches", "--not", "--remotes"]

    /// `git remote`: one name per line.
    static func remotes(_ output: Data) -> [String] {
        String(decoding: output, as: UTF8.self).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" ") && !$0.hasPrefix("warning:") && !$0.hasPrefix("fatal:") }
    }

    /// `git rev-list --count`: the last line that is a number.
    static func count(_ output: Data) -> Int? {
        String(decoding: output, as: UTF8.self).split(whereSeparator: \.isNewline).reversed()
            .lazy.compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.first
    }

    /// One repo from its three answers; `unpushed` is nil when it wasn't asked
    /// (no remote) or failed.
    static func repo(path: String, root: String, status: Data, remotes: Data, unpushed: Data?) -> PocketSafety.Repo {
        let porcelain = GitPorcelain.parse(status)
        let hasRemote = !self.remotes(remotes).isEmpty
        let ahead = unpushed.flatMap(count) ?? porcelain.branch.ahead ?? 0
        return PocketSafety.Repo(name: (path as NSString).lastPathComponent, path: relativePath(path, root: root),
                                 branch: porcelain.branch.head, unpushed: hasRemote ? ahead : 0,
                                 uncommitted: porcelain.changes.count, hasRemote: hasRemote)
    }

    /// The repos that need the person, riskiest first, capped; and how many there were.
    static func atRisk(_ repos: [PocketSafety.Repo], limit: Int = maximumListedRepos) -> (listed: [PocketSafety.Repo], total: Int) {
        let risky = PocketWatchtowerPresentation.sorted(repos.filter { PocketWatchtowerPresentation.risk($0) != .none })
        return (Array(risky.prefix(limit)), risky.count)
    }

    // MARK: Time Machine and disk

    /// `tmutil destinationinfo`: false for "No destinations configured",
    /// true when it lists one, nil when it said neither (an error).
    static func timeMachineConfigured(_ output: String) -> Bool? {
        let text = output.lowercased()
        if text.contains("no destinations configured") { return false }
        let listsOne = output.split(whereSeparator: \.isNewline).contains { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            return parts.count == 2 && ["name", "id", "kind"].contains(parts[0].trimmingCharacters(in: .whitespaces).lowercased())
        }
        return listsOne ? true : nil
    }

    /// Whether a destination is mounted now. `tmutil latestbackup` is only
    /// asked then: otherwise it tries to mount a network disk itself.
    static func timeMachineMounted(_ output: String) -> Bool {
        output.split(whereSeparator: \.isNewline).contains { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            return parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "mount point"
                && !parts[1].trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// `tmutil latestbackup`: the backup's folder ends in its local time,
    /// "2026-11-20-101500" (".backup" on APFS). nil for an error or nothing.
    static func latestBackup(_ output: String, timeZone: TimeZone = .current) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})"#) else { return nil }
        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.matches(in: output, range: range).last else { return nil }
        let numbers = (1...6).compactMap { Range(match.range(at: $0), in: output).flatMap { Int(output[$0]) } }
        guard numbers.count == 6 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2],
                                                  hour: numbers[3], minute: numbers[4], second: numbers[5]))
    }

    static func diskFreePercent(available: Int64?, total: Int64?) -> Int? {
        guard let available, let total, total > 0, available >= 0 else { return nil }
        return Int((Double(min(available, total)) / Double(total) * 100).rounded())
    }
}
