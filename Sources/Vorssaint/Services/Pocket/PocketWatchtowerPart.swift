// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Security

/// Zenith fork: Watchtower, the Pocket part that keeps an eye on what the
/// person would otherwise notice days late: a site that went down or was
/// paused by its host, a deploy that failed, a certificate about to end;
/// repos with work that never left this Mac, and a backup that isn't running.
///
/// It runs only while Pocket's link does (on, paired, awake). Sites are
/// checked every ten minutes with one ephemeral URLSession (HEAD, then GET
/// when a server refuses HEAD; ten seconds at most); with a Vercel or Netlify
/// token saved, their APIs say how the latest deploy went. Repos are scanned
/// every half hour on a background queue, `git` run under `nice` with read-only
/// commands and a timeout each; Time Machine and the disk are read with them.
/// Tokens only ever travel to api.vercel.com and api.netlify.com.
final class PocketWatchtowerPart: PocketPart {
    /// Posted by Settings when a token was saved or removed.
    static let tokensChanged = Notification.Name("PocketWatchtowerTokensChanged")

    private var context: PocketPartContext?
    private var sites: PocketSites?
    private var safety: PocketSafety?
    private var sitesTimer: Timer?
    private var safetyTimer: Timer?
    private var checkingSites = false
    private var scanning = false
    /// Bumped on stop and when what they watch changes, so a late answer is dropped.
    private var sitesGeneration = 0
    private var safetyGeneration = 0
    private var checker: PocketSiteChecker?
    private var observer: PocketWatchtowerDefaultsObserver?
    private var tokenObserver: NSObjectProtocol?
    private var lastSettings: Settings?
    private let scan = PocketSafetyScanner()

    private struct Settings: Equatable {
        var watchSites: Bool
        var sites: [URL]
        var watchSafety: Bool
        var folder: String

        static func current() -> Settings {
            Settings(watchSites: PocketWatchtowerDefaults.watchesSites(),
                     sites: PocketWatchtowerSupport.siteURLs(PocketWatchtowerDefaults.siteList()),
                     watchSafety: PocketWatchtowerDefaults.watchesSafety(),
                     folder: PocketWatchtowerDefaults.folder())
        }
    }

    func start(_ context: PocketPartContext) {
        self.context = context
        let settings = Settings.current()
        lastSettings = settings
        sites = placeholder(settings.sites, keeping: nil)
        observer = PocketWatchtowerDefaultsObserver(keys: PocketWatchtowerDefaults.keys) { [weak self] in
            Self.onMain { self?.settingsChanged() }
        }
        tokenObserver = NotificationCenter.default.addObserver(forName: Self.tokensChanged, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleSites(after: 1)
        }
        if settings.watchSites, !settings.sites.isEmpty { scheduleSites(after: PocketWatchtowerSupport.sitesFirstDelay) }
        if settings.watchSafety { scheduleSafety(after: PocketWatchtowerSupport.safetyFirstDelay) }
    }

    func stop() {
        sitesGeneration += 1
        safetyGeneration += 1
        sitesTimer?.invalidate()
        safetyTimer?.invalidate()
        sitesTimer = nil
        safetyTimer = nil
        observer = nil
        if let tokenObserver { NotificationCenter.default.removeObserver(tokenObserver) }
        tokenObserver = nil
        checker?.invalidate()
        checker = nil
        scan.cancel()
        checkingSites = false
        scanning = false
        context = nil
    }

    func fill(_ state: inout PocketMacState) {
        guard let settings = lastSettings else { return }
        if settings.watchSites, let sites, !sites.sites.isEmpty { state.sites = sites }
        if settings.watchSafety, let safety { state.safety = safety }
    }

    // MARK: Settings

    private func settingsChanged() {
        guard context != nil else { return }
        let settings = Settings.current()
        guard settings != lastSettings else { return }
        let previous = lastSettings
        lastSettings = settings
        if settings.sites != previous?.sites || settings.watchSites != previous?.watchSites {
            sitesGeneration += 1
            checkingSites = false
            sites = placeholder(settings.sites, keeping: sites)
            sitesTimer?.invalidate()
            if settings.watchSites, !settings.sites.isEmpty { scheduleSites(after: 2) }
        }
        if settings.folder != previous?.folder || settings.watchSafety != previous?.watchSafety {
            safetyTimer?.invalidate()
            if settings.folder != previous?.folder {
                safetyGeneration += 1
                safety = nil
                scan.cancel()
                scanning = false
            }
            if settings.watchSafety { scheduleSafety(after: 3) }
        }
        context?.changed()
    }

    /// The listed sites, each with its last reading or as not checked yet.
    private func placeholder(_ urls: [URL], keeping current: PocketSites?) -> PocketSites {
        PocketSites(sites: urls.map { url in
            current?.sites.first { $0.url == url.absoluteString }
                ?? PocketSites.Site(url: url.absoluteString, name: PocketWatchtowerSupport.siteName(url), status: .unknown)
        })
    }

    // MARK: Sites

    private func scheduleSites(after delay: TimeInterval) {
        sitesTimer?.invalidate()
        sitesTimer = Self.timer(after: delay) { [weak self] in self?.checkSites() }
    }

    private func checkSites() {
        guard context != nil, let settings = lastSettings, settings.watchSites, !settings.sites.isEmpty else { return }
        guard !checkingSites else { return }
        checkingSites = true
        let checker = self.checker ?? PocketSiteChecker()
        self.checker = checker
        let urls = settings.sites
        let previous = sites
        let generation = sitesGeneration
        Task { [weak self] in
            let result = await checker.check(urls, previous: previous)
            Self.onMain {
                guard let self, self.sitesGeneration == generation else { return }
                self.checkingSites = false
                if result != self.sites {
                    self.sites = result
                    self.context?.changed()
                }
                self.scheduleSites(after: PocketWatchtowerSupport.sitesInterval)
            }
        }
    }

    // MARK: Safety

    private func scheduleSafety(after delay: TimeInterval) {
        safetyTimer?.invalidate()
        safetyTimer = Self.timer(after: delay) { [weak self] in self?.scanSafety() }
    }

    private func scanSafety() {
        guard context != nil, let settings = lastSettings, settings.watchSafety, !scanning else { return }
        scanning = true
        let generation = safetyGeneration
        let lastBackup = safety?.lastBackup
        scan.run(folder: settings.folder, lastKnownBackup: lastBackup) { [weak self] result in
            Self.onMain {
                guard let self, self.safetyGeneration == generation else { return }
                self.scanning = false
                if let result, result != self.safety {
                    self.safety = result
                    self.context?.changed()
                }
                self.scheduleSafety(after: PocketWatchtowerSupport.safetyInterval)
            }
        }
    }

    private static func onMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
    }

    /// A one-shot timer with some slack, so macOS can group its wake-ups.
    private static func timer(after delay: TimeInterval, _ fire: @escaping () -> Void) -> Timer {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in fire() }
        timer.tolerance = max(1, delay * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

// MARK: - Checking sites

/// One URLSession for the sites and the hosts' APIs: ephemeral (no cookies,
/// no cache), ten seconds per request. As the session's delegate it reads
/// each server's certificate expiry from the trust it is handed, then lets
/// the system judge the trust as usual.
private final class PocketSiteChecker: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var expiries: [String: Date] = [:]
    private var session: URLSession?
    /// The hosts' lists from the last read that worked, for a failed one.
    private var vercel: [PocketWatchtowerSupport.HostedSite]?
    private var netlify: [PocketWatchtowerSupport.HostedSite]?

    private var userAgent: String { "\(AppInfo.name)/\(AppInfo.version)" }

    private func currentSession() -> URLSession {
        lock.lock()
        defer { lock.unlock() }
        if let session { return session }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = PocketWatchtowerSupport.requestTimeout
        configuration.timeoutIntervalForResource = PocketWatchtowerSupport.requestTimeout * 3
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        let made = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        session = made
        return made
    }

    func invalidate() {
        lock.lock()
        let session = self.session
        self.session = nil
        lock.unlock()
        session?.invalidateAndCancel()
    }

    func check(_ urls: [URL], previous: PocketSites?) async -> PocketSites {
        let probes = await withTaskGroup(of: (Int, PocketWatchtowerSupport.Probe).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { (index, await self.probe(url)) }
            }
            var collected = [PocketWatchtowerSupport.Probe](repeating: .init(), count: urls.count)
            for await (index, probe) in group { collected[index] = probe }
            return collected
        }
        let hosts = Set(probes.compactMap { PocketWatchtowerSupport.host($0.headers) })
        await readHosts(hosts, urls: urls)
        let now = Date()
        let (vercel, netlify) = lockedLists()
        return PocketSites(sites: zip(urls, probes).map { url, probe in
            let previousSite = previous?.sites.first { $0.url == url.absoluteString }
            return PocketWatchtowerSupport.site(url, probe: probe, previous: previousSite,
                                                certificate: expiry(url.host), vercel: vercel, netlify: netlify, now: now)
        })
    }

    // MARK: Probes

    private func probe(_ url: URL) async -> PocketWatchtowerSupport.Probe {
        let head = await request(url, method: "HEAD")
        guard PocketWatchtowerSupport.needsGet(after: head) else { return head }
        return await request(url, method: "GET")
    }

    /// One request; for GET, at most the first 32 KB of an error page is read.
    private func request(_ url: URL, method: String) async -> PocketWatchtowerSupport.Probe {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = PocketWatchtowerSupport.requestTimeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let started = Date()
        do {
            let (bytes, response) = try await currentSession().bytes(for: request)
            let latency = Int(Date().timeIntervalSince(started) * 1000)
            guard let http = response as? HTTPURLResponse else {
                bytes.task.cancel()
                return .init(latencyMs: latency)
            }
            var headers: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let key = key as? String, let value = value as? String { headers[key.lowercased()] = value }
            }
            var body: String?
            if method == "GET", http.statusCode >= 400 {
                var data = Data()
                for try await byte in bytes {
                    data.append(byte)
                    if data.count >= PocketWatchtowerSupport.maximumBodyBytes { break }
                }
                body = String(decoding: data, as: UTF8.self)
            }
            bytes.task.cancel()
            return .init(status: http.statusCode, latencyMs: latency, headers: headers, body: body)
        } catch let error as URLError {
            return .init(timedOut: error.code == .timedOut, offline: PocketWatchtowerSupport.isOffline(error.code))
        } catch {
            return .init()
        }
    }

    // MARK: Hosts' APIs

    /// Vercel and Netlify are asked only when a token is saved and one of
    /// the sites is theirs.
    private func readHosts(_ hosts: Set<String>, urls: [URL]) async {
        if hosts.contains("vercel"), let token = ZenithSecretStore.read(VercelService.secretName) {
            if let list = await vercelProjects(token: token) { store(vercel: list) }
        } else {
            store(vercel: nil)
        }
        if hosts.contains("netlify"), let token = ZenithSecretStore.read(PocketWatchtowerDefaults.netlifySecret) {
            if let list = await netlifySites(token: token, watching: urls) { store(netlify: list) }
        } else {
            store(netlify: nil)
        }
    }

    /// The personal account's projects, then each team's.
    private func vercelProjects(token: String) async -> [PocketWatchtowerSupport.HostedSite]? {
        let teams = await load(VercelSupport.teamsRequest(token: token, userAgent: userAgent)).flatMap(VercelSupport.teams(from:)) ?? []
        var all: [PocketWatchtowerSupport.HostedSite] = []
        var anyAnswered = false
        for teamID in [nil] + teams.prefix(VercelSupport.maximumTeams).map({ Optional($0.id) }) {
            let request = PocketWatchtowerSupport.vercelProjectsRequest(teamID: teamID, token: token, userAgent: userAgent)
            guard let list = await load(request).flatMap(PocketWatchtowerSupport.vercelProjects(from:)) else { continue }
            anyAnswered = true
            all += list
        }
        return anyAnswered ? all : nil
    }

    /// The person's Netlify sites, then the latest deploy (which may have
    /// failed after the live one) of only those being watched: one request each.
    private func netlifySites(token: String, watching urls: [URL]) async -> [PocketWatchtowerSupport.HostedSite]? {
        guard var sites = await load(PocketWatchtowerSupport.netlifySitesRequest(token: token, userAgent: userAgent))
            .flatMap(PocketWatchtowerSupport.netlifySites(from:)) else { return nil }
        for index in sites.indices where urls.contains(where: { PocketWatchtowerSupport.match($0, in: [sites[index]]) != nil }) {
            let request = PocketWatchtowerSupport.netlifyDeploysRequest(siteID: sites[index].id, token: token, userAgent: userAgent)
            if let latest = await load(request).flatMap(PocketWatchtowerSupport.netlifyLatestDeploy(from:)) {
                sites[index].deployState = latest.state ?? sites[index].deployState
                sites[index].deployedAt = latest.at ?? sites[index].deployedAt
            }
        }
        return sites
    }

    /// The body of a 2xx answer.
    private func load(_ request: URLRequest) async -> Data? {
        guard let (data, response) = try? await currentSession().data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else { return nil }
        return data
    }

    // MARK: Locked state

    private func store(vercel list: [PocketWatchtowerSupport.HostedSite]?) {
        lock.lock(); vercel = list; lock.unlock()
    }

    private func store(netlify list: [PocketWatchtowerSupport.HostedSite]?) {
        lock.lock(); netlify = list; lock.unlock()
    }

    private func lockedLists() -> ([PocketWatchtowerSupport.HostedSite]?, [PocketWatchtowerSupport.HostedSite]?) {
        lock.lock()
        defer { lock.unlock() }
        return (vercel, netlify)
    }

    private func expiry(_ host: String?) -> Date? {
        guard let host = host?.lowercased() else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return expiries[host]
    }

    // MARK: URLSessionDelegate

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust, let date = Self.expiry(of: trust) {
            lock.lock()
            expiries[challenge.protectionSpace.host.lowercased()] = date
            lock.unlock()
        }
        // The system decides as it always would; this only reads the date.
        completionHandler(.performDefaultHandling, nil)
    }

    /// The leaf certificate's "not after" date.
    private static func expiry(of trust: SecTrust) -> Date? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let leaf = chain.first,
              let values = SecCertificateCopyValues(leaf, [kSecOIDX509V1ValidityNotAfter] as CFArray, nil) as? [String: Any],
              let entry = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
              let seconds = (entry[kSecPropertyKeyValue as String] as? NSNumber)?.doubleValue
        else { return nil }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}

// MARK: - Scanning safety

/// Walks the folder for repos and asks each three read-only questions, then
/// reads Time Machine and the disk, on a background queue at low priority.
private final class PocketSafetyScanner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket.safety", qos: .background)
    private let lock = NSLock()
    /// The run that may go on; a cancelled or newer one ends the older.
    private var current = 0

    func cancel() {
        lock.lock(); current += 1; lock.unlock()
    }

    private func isCancelled(_ run: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return run != current
    }

    /// nil when cancelled.
    func run(folder: String, lastKnownBackup: Date?, done: @escaping (PocketSafety?) -> Void) {
        lock.lock(); current += 1; let run = current; lock.unlock()
        queue.async { [self] in
            done(scan(folder: folder, lastKnownBackup: lastKnownBackup, run: run))
        }
    }

    private func scan(folder: String, lastKnownBackup: Date?, run: Int) -> PocketSafety? {
        var repos: [PocketSafety.Repo] = []
        if let git = GitCLI.executable() {
            let fileManager = FileManager.default
            let paths = PocketWatchtowerSupport.repositories(in: folder, children: { path in
                guard let names = try? fileManager.contentsOfDirectory(atPath: path) else { return nil }
                // Symbolic links are not followed (the type is the link's own):
                // a link to ~ would walk the whole home folder.
                return names.filter { name in
                    let full = (path as NSString).appendingPathComponent(name)
                    return (try? fileManager.attributesOfItem(atPath: full))?[.type] as? FileAttributeType == .typeDirectory
                }
            }, isRepository: { GitRepoLocator.repository(at: $0) != nil })
            for path in paths {
                if isCancelled(run) { return nil }
                let status = gitRun(git, path, PocketWatchtowerSupport.statusCommand)
                guard status.status == 0, !status.timedOut else { continue }
                let remotes = gitRun(git, path, PocketWatchtowerSupport.remoteCommand)
                let hasRemote = remotes.status == 0 && !PocketWatchtowerSupport.remotes(remotes.output).isEmpty
                var unpushed: Data?
                if hasRemote {
                    let count = gitRun(git, path, PocketWatchtowerSupport.unpushedCommand)
                    if count.status == 0, !count.timedOut { unpushed = count.output }
                }
                repos.append(PocketWatchtowerSupport.repo(path: path, root: folder, status: status.output,
                                                          remotes: remotes.status == 0 ? remotes.output : Data(),
                                                          unpushed: unpushed))
            }
        }
        if isCancelled(run) { return nil }
        let risky = PocketWatchtowerSupport.atRisk(repos)

        let info = tmutil(["destinationinfo"])
        let configured = info.flatMap(PocketWatchtowerSupport.timeMachineConfigured)
        var lastBackup = configured == true ? lastKnownBackup : nil
        if configured == true, let info, PocketWatchtowerSupport.timeMachineMounted(info),
           let latest = tmutil(["latestbackup"]).flatMap({ PocketWatchtowerSupport.latestBackup($0) }) {
            lastBackup = latest
        }

        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let disk = PocketWatchtowerSupport.diskFreePercent(available: values?.volumeAvailableCapacityForImportantUsage,
                                                           total: values?.volumeTotalCapacity.map(Int64.init))
        return PocketSafety(repos: risky.listed, scannedAt: Date(), timeMachineConfigured: configured, lastBackup: lastBackup,
                            diskFreePercent: disk, reposAtRisk: risky.total,
                            folder: PocketWatchtowerSupport.displayPath(folder))
    }

    /// `git` under `nice`, with Zenith's no-prompt environment and a timeout.
    private func gitRun(_ git: String, _ root: String, _ command: [String]) -> BoundedProcessRunner.Result {
        BoundedProcessRunner.run("/usr/bin/nice", ["-n", "15", git] + GitCLI.arguments(root, command),
                                 timeout: PocketWatchtowerSupport.gitTimeout, maxOutputBytes: GitRunner.maxStatusBytes,
                                 environment: GitCLI.environment())
    }

    private func tmutil(_ arguments: [String]) -> String? {
        let result = BoundedProcessRunner.run("/usr/bin/nice", ["-n", "15", "/usr/bin/tmutil"] + arguments,
                                              timeout: PocketWatchtowerSupport.tmutilTimeout, maxOutputBytes: 64 * 1024)
        guard !result.timedOut else { return nil }
        return String(decoding: result.output, as: UTF8.self)
    }
}

// MARK: - Preferences

/// Watches Watchtower's preference keys (KVO), so a change in Settings
/// reaches the part without listening to every preference Zenith writes.
private final class PocketWatchtowerDefaultsObserver: NSObject {
    private let keys: [String]
    private let changed: () -> Void

    init(keys: [String], changed: @escaping () -> Void) {
        self.keys = keys
        self.changed = changed
        super.init()
        keys.forEach { UserDefaults.standard.addObserver(self, forKeyPath: $0, options: [], context: nil) }
    }

    deinit {
        keys.forEach { UserDefaults.standard.removeObserver(self, forKeyPath: $0) }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        changed()
    }
}
