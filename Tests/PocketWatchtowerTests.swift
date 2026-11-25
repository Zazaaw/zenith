// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Watchtower's decisions on fixtures. Typed sites become URLs
/// or are refused; an answer reads as up, slow, paused or down; Vercel's and
/// Netlify's answers give a site's latest deploy; `git` and `tmutil` output
/// reads back; the folder walk stops at repos and skips what it should; and
/// the riskiest repos come first. Nothing here reaches the network or runs
/// `git` or `tmutil`.
enum PocketWatchtowerTests {
    static func run(_ suite: TestSuite) {
        preferences(suite)
        siteURLs(suite)
        classification(suite)
        sitesFromProbes(suite)
        vercel(suite)
        netlify(suite)
        git(suite)
        walk(suite)
        timeMachine(suite)
        strings(suite)
    }

    private typealias Support = PocketWatchtowerSupport
    private typealias Probe = PocketWatchtowerSupport.Probe

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.pocket-watchtower"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(PocketWatchtowerDefaults.watchesSites(in: defaults) && PocketWatchtowerDefaults.watchesSafety(in: defaults),
                     "sites and safety are watched once Pocket is on")
        suite.expect(PocketWatchtowerDefaults.siteList(in: defaults).isEmpty, "no site is watched by default")
        suite.expect(PocketWatchtowerDefaults.folder(in: defaults, home: "/Users/someone") == "/Users/someone/Developer",
                     "the folder defaults to ~/Developer")
        defaults.set("/Volumes/Work/code", forKey: PocketWatchtowerDefaults.safetyFolder)
        suite.expect(PocketWatchtowerDefaults.folder(in: defaults, home: "/Users/someone") == "/Volumes/Work/code", "a chosen folder")
        suite.expect(Support.displayPath("/Users/someone/Developer", home: "/Users/someone") == "~/Developer"
                     && Support.displayPath("/Volumes/Work", home: "/Users/someone") == "/Volumes/Work", "the folder as the person sees it")
        suite.expect(ZenithSecretStore.isValidName(PocketWatchtowerDefaults.netlifySecret), "the Netlify token's file name")
    }

    private static func siteURLs(_ suite: TestSuite) {
        suite.expect(Support.siteURL("example.com")?.absoluteString == "https://example.com/", "https is assumed")
        suite.expect(Support.siteURL("  HTTP://Example.COM/blog#top ")?.absoluteString == "http://example.com/blog",
                     "the scheme kept, the host lowercased, the fragment dropped")
        for bad in ["", "not a site", "ftp://example.com", "example", "https://user:pass@example.com", "javascript:alert(1)"] {
            suite.expect(Support.siteURL(bad) == nil, "\"\(bad)\" is refused")
        }
        let list = Support.siteURLs(["example.com", "https://example.com", "example.org"] + (0..<30).map { "s\($0).example.net" })
        suite.expect(list.count == Support.maximumSites && list[0].absoluteString == "https://example.com/"
                     && list[1].host == "example.org", "repeats dropped, capped: \(list.prefix(3))")
        suite.expect(Support.siteName(URL(string: "https://www.example.com/")!) == "example.com"
                     && Support.siteName(URL(string: "https://example.com/blog")!) == "example.com/blog", "the name the phone shows")
    }

    private static func classification(_ suite: TestSuite) {
        func status(_ probe: Probe) -> PocketSites.Site.Status { Support.classify(probe) }
        suite.expect(status(Probe(status: 200, latencyMs: 180)) == .up, "200 is up")
        suite.expect(status(Probe(status: 301, latencyMs: 90)) == .up, "a redirect is up")
        suite.expect(status(Probe(status: 200, latencyMs: 2400)) == .slow, "past 1.5 s is slow")
        suite.expect(status(Probe(status: 402, latencyMs: 100)) == .paused, "402 is paused")
        suite.expect(status(Probe(status: 503, latencyMs: 100, headers: ["x-vercel-error": "DEPLOYMENT_PAUSED"])) == .paused,
                     "Vercel's paused header")
        suite.expect(status(Probe(status: 503, latencyMs: 100,
                                  body: "<h1>Site not available</h1><p>This site was paused as it reached its usage limits.</p>")) == .paused,
                     "Netlify's paused page")
        suite.expect(status(Probe(status: 503, latencyMs: 100, body: "<h1>Service Unavailable</h1>")) == .down, "a 5xx is down")
        suite.expect(status(Probe(status: 404, latencyMs: 100)) == .down, "a missing page is down")
        suite.expect(status(Probe(status: 401, latencyMs: 100)) == .up && status(Probe(status: 403, latencyMs: 100)) == .up,
                     "a protected site answers")
        suite.expect(status(Probe(status: 429, latencyMs: 100)) == .unknown, "rate limited says nothing")
        suite.expect(status(Probe(timedOut: true)) == .down && status(Probe()) == .down, "no answer is down")
        suite.expect(status(Probe(offline: true)) == .unknown, "an offline Mac knows nothing")
        suite.expect(Support.isOffline(.notConnectedToInternet) && !Support.isOffline(.timedOut)
                     && !Support.isOffline(.cannotFindHost), "offline is the Mac's own state, not a missing host")

        suite.expect(!Support.needsGet(after: Probe(status: 200)) && Support.needsGet(after: Probe(status: 405))
                     && Support.needsGet(after: Probe(status: 503)) && Support.needsGet(after: Probe()),
                     "a refused or failed HEAD is asked again with GET")
        suite.expect(!Support.needsGet(after: Probe(timedOut: true)) && !Support.needsGet(after: Probe(status: 402)),
                     "a timeout or a paused site isn't asked twice")
        suite.expect(Support.host(["server": "Vercel"]) == "vercel" && Support.host(["x-vercel-id": "fra1::abc"]) == "vercel"
                     && Support.host(["server": "Netlify"]) == "netlify" && Support.host(["server": "nginx"]) == nil,
                     "the host from the headers")
    }

    private static func sitesFromProbes(_ suite: TestSuite) {
        let url = URL(string: "https://example.com/")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let earlier = now.addingTimeInterval(-600)
        let down = Support.site(url, probe: Probe(status: 503, latencyMs: 80, headers: ["server": "Vercel"]), previous: nil,
                                certificate: now.addingTimeInterval(86_400 * 30), vercel: nil, netlify: nil, now: earlier)
        suite.expect(down.status == .down && down.host == "vercel" && down.since == earlier && down.name == "example.com"
                     && down.certificateExpiresAt != nil, "a first reading: \(down)")
        let still = Support.site(url, probe: Probe(status: 503, latencyMs: 80), previous: down, certificate: nil,
                                 vercel: nil, netlify: nil, now: now)
        suite.expect(still.since == earlier && still.certificateExpiresAt == down.certificateExpiresAt,
                     "still down: since stays, the known certificate too")
        let back = Support.site(url, probe: Probe(status: 200, latencyMs: 80), previous: still, certificate: nil,
                                vercel: nil, netlify: nil, now: now)
        suite.expect(back.status == .up && back.since == now, "back up: since moves")
        let offline = Support.site(url, probe: Probe(offline: true), previous: still, certificate: nil, vercel: nil, netlify: nil, now: now)
        suite.expect(offline == still, "offline keeps the last reading")
        let hosted = [Support.HostedSite(id: "prj_1", name: "web", domains: ["example.com"], deployState: "error", deployedAt: earlier)]
        let deployed = Support.site(url, probe: Probe(status: 200, latencyMs: 80), previous: nil, certificate: nil,
                                    vercel: hosted, netlify: nil, now: now)
        suite.expect(deployed.host == "vercel" && deployed.deployState == "error" && deployed.deployedAt == earlier,
                     "the API knows the site: its deploy, and the host")
        let plain = Support.site(URL(string: "http://example.com/")!, probe: Probe(status: 200, latencyMs: 80), previous: nil,
                                 certificate: now, vercel: nil, netlify: nil, now: now)
        suite.expect(plain.certificateExpiresAt == nil, "http has no certificate")
    }

    private static func vercel(_ suite: TestSuite) {
        let json = #"""
        {"projects":[
          {"id":"prj_web","name":"web",
           "targets":{"production":{"alias":["example.com","www.example.com"],"readyState":"READY","createdAt":1799990000000}},
           "latestDeployments":[{"readyState":"ERROR","createdAt":1799995000000,"target":"production"},
                                {"readyState":"BUILDING","createdAt":1799999000000,"target":null}]},
          {"id":"prj_docs","name":"Docs","alias":[{"domain":"docs.example.org"}]},
          {"name":"no-id"}
        ],"pagination":{"count":3}}
        """#
        let projects = Support.vercelProjects(from: Data(json.utf8)) ?? []
        suite.expect(projects.count == 2, "projects with an id: \(projects)")
        let web = projects.first { $0.id == "prj_web" }
        suite.expect(web?.domains == ["web.vercel.app", "example.com", "www.example.com"], "its domains: \(String(describing: web?.domains))")
        suite.expect(web?.deployState == "error" && web?.deployedAt == Date(timeIntervalSince1970: 1_799_995_000),
                     "a production build that failed after the live one; a preview doesn't count")
        let docs = projects.first { $0.id == "prj_docs" }
        suite.expect(docs?.domains == ["docs.vercel.app", "docs.example.org"] && docs?.deployState == nil, "an alias object, no deploys")
        suite.expect(Support.match(URL(string: "https://www.example.com/")!, in: projects)?.id == "prj_web"
                     && Support.match(URL(string: "https://docs.vercel.app/")!, in: projects)?.id == "prj_docs"
                     && Support.match(URL(string: "https://example.net/")!, in: projects) == nil, "matched by host")
        suite.expect(Support.vercelProjects(from: Data("{}".utf8)) == nil && Support.vercelProjects(from: Data("nope".utf8)) == nil,
                     "an answer of another shape")
        let request = Support.vercelProjectsRequest(teamID: "team_1", token: " tok_123 ", userAgent: "Zenith/1")
        suite.expect(request.url?.host == "api.vercel.com" && request.url?.path == "/v9/projects"
                     && request.url?.query?.contains("teamId=team_1") == true
                     && request.value(forHTTPHeaderField: "Authorization") == "Bearer tok_123", "the projects request")
    }

    private static func netlify(_ suite: TestSuite) {
        let json = #"""
        [{"id":"site-1","name":"example","url":"http://example.com","ssl_url":"https://example.netlify.app",
          "custom_domain":"example.com","domain_aliases":["www.example.com"],
          "published_deploy":{"state":"ready","published_at":"2026-11-20T10:00:00.123Z","created_at":"2026-11-20T09:58:00Z"}},
         {"id":"site-2","name":"other","url":"https://other.netlify.app","published_deploy":null},
         {"name":"no id"}]
        """#
        let sites = Support.netlifySites(from: Data(json.utf8)) ?? []
        suite.expect(sites.count == 2, "sites with an id: \(sites)")
        suite.expect(sites.first?.domains == ["example.com", "example.netlify.app", "www.example.com"], "domains: \(String(describing: sites.first?.domains))")
        suite.expect(sites.first?.deployState == "ready" && sites.first?.deployedAt != nil, "the live deploy")
        suite.expect(sites.last?.deployState == nil && sites.last?.deployedAt == nil, "a site never published")
        let deploys = #"[{"state":"error","context":"deploy-preview","created_at":"2026-11-21T08:00:00Z"},{"state":"error","context":"production","created_at":"2026-11-20T12:00:00Z"}]"#
        let latest = Support.netlifyLatestDeploy(from: Data(deploys.utf8))
        suite.expect(latest?.state == "error" && latest?.at == Support.date(iso: "2026-11-20T12:00:00Z"), "the newest production deploy")
        suite.expect(Support.netlifyLatestDeploy(from: Data("[]".utf8)) == nil, "no deploys")
        let request = Support.netlifyDeploysRequest(siteID: "site-1", token: "tok", userAgent: "Zenith/1")
        suite.expect(request.url?.absoluteString == "https://api.netlify.com/api/v1/sites/site-1/deploys?per_page=3"
                     && request.value(forHTTPHeaderField: "Authorization") == "Bearer tok", "the deploys request")
        suite.expect(Support.deployState("ENQUEUED") == "queued" && Support.deployState("processing") == "building"
                     && Support.deployState("READY") == "ready" && Support.deployState("CANCELED") == "canceled"
                     && Support.deployState("") == nil, "one word per state across hosts")
    }

    private static func git(_ suite: TestSuite) {
        let status = Data(["# branch.oid 1234567890abcdef1234567890abcdef12345678", "# branch.head feat/event",
                           "# branch.upstream origin/feat/event", "# branch.ab +1 -0",
                           "1 .M N... 100644 100644 100644 1111111 2222222 src/app.swift",
                           "2 R. N... 100644 100644 100644 3333333 4444444 R100 src/new.swift", "src/old.swift",
                           "? notes.txt", ""].joined(separator: "\0").utf8)
        let remotes = Data("origin\nupstream\n".utf8)
        let repo = Support.repo(path: "/Users/someone/Developer/work/kit", root: "/Users/someone/Developer", status: status,
                                remotes: remotes, unpushed: Data("3\n".utf8))
        suite.expect(repo.name == "kit" && repo.path == "work/kit" && repo.branch == "feat/event", "the repo's names: \(repo)")
        suite.expect(repo.uncommitted == 3 && repo.unpushed == 3 && repo.hasRemote, "a rename counts once; every branch's commits")
        let noRemote = Support.repo(path: "/Users/someone/Developer/site", root: "/Users/someone/Developer", status: status,
                                    remotes: Data(), unpushed: nil)
        suite.expect(!noRemote.hasRemote && noRemote.unpushed == 0, "no remote: nothing to push to")
        let fallback = Support.repo(path: "/x/y", root: "/x", status: status, remotes: remotes, unpushed: nil)
        suite.expect(fallback.unpushed == 1, "a failed count falls back to the branch's own lead")
        suite.expect(Support.count(Data("warning: something\n12\n".utf8)) == 12 && Support.count(Data("fatal: no".utf8)) == nil,
                     "a count past a warning")
        suite.expect(Support.remotes(Data("fatal: not a git repository\n".utf8)).isEmpty, "an error is no remote")
        suite.expect(Support.relativePath("/x", root: "/x") == "x", "the folder itself is a repo")

        // Read only: none of the commands writes or reaches the network.
        let commands = [Support.statusCommand, Support.remoteCommand, Support.unpushedCommand]
        suite.expect(commands.allSatisfy { ["status", "remote", "rev-list"].contains($0[0]) }
                     && !commands.joined().contains { ["fetch", "push", "pull", "gc", "add", "commit"].contains($0) },
                     "read-only commands")

        let repos = [PocketSafety.Repo(name: "clean", path: "clean", unpushed: 0, uncommitted: 0, hasRemote: true),
                     PocketSafety.Repo(name: "dirty", path: "dirty", unpushed: 0, uncommitted: 4, hasRemote: true),
                     PocketSafety.Repo(name: "ahead", path: "ahead", unpushed: 2, uncommitted: 0, hasRemote: true),
                     PocketSafety.Repo(name: "lonely", path: "lonely", unpushed: 0, uncommitted: 0, hasRemote: false)]
        let risky = Support.atRisk(repos, limit: 2)
        suite.expect(risky.listed.map(\.name) == ["lonely", "ahead"] && risky.total == 3,
                     "riskiest first, capped, the clean one left out: \(risky)")
    }

    private static func walk(_ suite: TestSuite) {
        // /dev: a, b (repo), personal/zenith (repo, with a nested repo inside),
        // .hidden/x (repo), node_modules/y (repo), deep/1/2/3 (repo, too deep).
        let tree: [String: [String]] = [
            "/dev": ["b", "a", "personal", ".hidden", "node_modules", "deep"],
            "/dev/a": [], "/dev/personal": ["zenith"], "/dev/personal/zenith": ["inner"],
            "/dev/.hidden": ["x"], "/dev/node_modules": ["y"],
            "/dev/deep": ["1"], "/dev/deep/1": ["2"], "/dev/deep/1/2": ["3"], "/dev/deep/1/2/3": [],
        ]
        let repos: Set<String> = ["/dev/b", "/dev/personal/zenith", "/dev/personal/zenith/inner", "/dev/.hidden/x",
                                  "/dev/node_modules/y", "/dev/deep/1/2/3"]
        let found = Support.repositories(in: "/dev", children: { tree[$0] }, isRepository: repos.contains)
        suite.expect(found == ["/dev/b", "/dev/personal/zenith"], "repos within three folders, not inside each other: \(found)")
        let capped = Support.repositories(in: "/dev", limit: 1, children: { tree[$0] }, isRepository: repos.contains)
        suite.expect(capped == ["/dev/b"], "capped")
        suite.expect(Support.repositories(in: "/dev/b", children: { tree[$0] }, isRepository: repos.contains) == ["/dev/b"],
                     "a folder that is a repo")
        suite.expect(Support.repositories(in: "/missing", children: { tree[$0] }, isRepository: repos.contains).isEmpty,
                     "a folder that can't be read")
    }

    private static func timeMachine(_ suite: TestSuite) {
        suite.expect(Support.timeMachineConfigured("tmutil: No destinations configured.\n") == false, "no destination")
        let info = """
        ====================================================
        Name          : Backup
        Kind          : Local
        Mount Point   : /Volumes/Backup
        ID            : 01234567-89AB-CDEF-0123-456789ABCDEF
        """
        suite.expect(Support.timeMachineConfigured(info) == true && Support.timeMachineMounted(info), "a mounted destination")
        let away = info.replacingOccurrences(of: "Mount Point   : /Volumes/Backup\n", with: "")
        suite.expect(Support.timeMachineConfigured(away) == true && !Support.timeMachineMounted(away), "a destination not connected")
        suite.expect(Support.timeMachineConfigured("") == nil, "an empty answer says nothing")

        let utc = TimeZone(identifier: "UTC")!
        let expected = Date(timeIntervalSince1970: 1_795_169_700) // 2026-11-20 10:15:00 UTC
        suite.expect(Support.latestBackup("/Volumes/Backup/Backups.backupdb/Mac/2026-11-20-101500\n", timeZone: utc) == expected,
                     "an HFS backup folder")
        suite.expect(Support.latestBackup("/Volumes/.timemachine/ABC/2026-11-20-101500.backup/2026-11-20-101500.backup\n",
                                          timeZone: utc) == expected, "an APFS backup")
        suite.expect(Support.latestBackup("Failed to mount backup destination, error: Error Domain=com.apple.backupd.ErrorDomain Code=17",
                                          timeZone: utc) == nil, "an error")
        suite.expect(Support.diskFreePercent(available: 250, total: 1000) == 25 && Support.diskFreePercent(available: 5, total: 0) == nil,
                     "free disk as a share")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.pocketWatchtower(language)
            suite.expect(text.all.allSatisfy { !$0.isEmpty } && text.all.count > 20, "\(language.rawValue): every string")
        }
        suite.expect(!PocketWatchtowerSearch.aliases.isEmpty && PocketWatchtowerSearch.aliases.contains("situs mati"),
                     "Indonesian search words")
        suite.expect(SettingsSectionAnchor.zenithPocketWatchtower.page == .pocket, "the section lands on iPhone & Watch")
    }
}
