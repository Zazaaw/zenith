// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Vercel's teams and deployments, how they merge, what the
/// closed island shows and how often Zenith asks again.
enum VercelTests {
    static func run(_ suite: TestSuite) {
        states(suite)
        parsing(suite)
        merging(suite)
        liveActivity(suite)
        polling(suite)
        requests(suite)
        island(suite)
        secrets(suite)
    }

    /// The build joins the closed island's activities after agents, and the
    /// section stays out of the island until it is turned on.
    private static func island(_ suite: TestSuite) {
        suite.expect(NotchSupport.compactActivities(timer: false, downloads: true, agents: true, calendar: true,
                                                   music: true, vercel: true) == [.downloads, .agents, .vercel, .calendar, .music]
                     && NotchSupport.compactActivity(timer: false, downloads: false, music: true, vercel: true) == .vercel,
                     "a Vercel build follows agents and comes before an event and music")
        suite.expect(!NotchSupport.compactActivities(timer: false, downloads: false, agents: false, calendar: false,
                                                    music: false).contains(.vercel),
                     "no build, no Vercel activity")
        suite.expect(NotchCompactActivity.vercel.module == .vercel && NotchCompactActivity.vercel.title(.enUS) == "Vercel",
                     "the build opens the Vercel page")
        suite.expect(NotchModule.vercel.isAvailable(), "the Vercel section is always listed, so its token can be pasted")
    }

    /// The token's file name can never leave the secrets folder.
    private static func secrets(_ suite: TestSuite) {
        suite.expect(ZenithSecretStore.isValidName("vercel-token") && ZenithSecretStore.isValidName("waka_tok.v2"),
                     "plain names are accepted")
        suite.expect(!ZenithSecretStore.isValidName("") && !ZenithSecretStore.isValidName("../escape")
                     && !ZenithSecretStore.isValidName("a/b") && !ZenithSecretStore.isValidName(".hidden")
                     && !ZenithSecretStore.isValidName("tökens") && !ZenithSecretStore.isValidName(String(repeating: "a", count: 65)),
                     "paths, hidden names, non-ASCII and overlong names are refused")
    }

    /// The shape of `GET /v6/deployments`, trimmed to what Zenith reads plus a
    /// few fields it ignores.
    static let deploymentsJSON = """
        {"deployments": [
          {"uid": "dpl_build", "name": "web", "url": "web-abc123-team.vercel.app", "created": 1763520000000,
           "state": "BUILDING", "type": "LAMBDAS", "target": "production", "source": "git",
           "creator": {"uid": "u1", "username": "someone"},
           "meta": {"githubCommitRef": "main", "githubCommitMessage": "Fix the header\\n\\nLonger body",
                    "githubCommitSha": "abc"},
           "inspectorUrl": "https://vercel.com/team/web/dpl_build", "aliasAssigned": null},
          {"uid": "dpl_ready", "name": "docs", "url": "docs-xyz.vercel.app", "createdAt": 1763510000000,
           "readyState": "READY", "state": "READY", "target": null,
           "meta": {"gitlabCommitRef": "feature/a", "gitlabCommitMessage": "  "},
           "inspectorUrl": "https://vercel.com/team/docs/dpl_ready"},
          {"uid": "dpl_failed", "name": "api", "url": "api-1.vercel.app", "created": 1763500000000,
           "state": "ERROR", "inspectorUrl": "http://insecure.example/dpl"},
          {"name": "no-uid"}
        ], "pagination": {"count": 4, "next": null, "prev": null}}
        """

    private static func deployments(scope: String? = nil) -> [VercelSupport.Deployment] {
        VercelSupport.deployments(from: Data(deploymentsJSON.utf8), scope: scope) ?? []
    }

    private static func deployment(_ uid: String, _ state: VercelSupport.State, created: TimeInterval,
                                   project: String = "web", scope: String? = nil) -> VercelSupport.Deployment {
        VercelSupport.Deployment(uid: uid, project: project, host: "\(uid).vercel.app", state: state,
                                 created: Date(timeIntervalSince1970: created), isProduction: false, branch: nil,
                                 commitMessage: nil, inspectorURL: nil, scope: scope)
    }

    private static func states(_ suite: TestSuite) {
        suite.expect(VercelSupport.State(api: "QUEUED") == .queued && VercelSupport.State(api: "initializing") == .initializing
                     && VercelSupport.State(api: "BUILDING") == .building && VercelSupport.State(api: "READY") == .ready
                     && VercelSupport.State(api: "ERROR") == .error && VercelSupport.State(api: "CANCELED") == .canceled
                     && VercelSupport.State(api: "DELETED") == .unknown && VercelSupport.State(api: nil) == .unknown,
                     "Vercel's states map to Zenith's, anything new reads as unknown")
        suite.expect([VercelSupport.State.queued, .initializing, .building].allSatisfy(\.inProgress)
                     && ![VercelSupport.State.ready, .error, .canceled, .unknown].contains(where: \.inProgress),
                     "queued, initializing and building are on their way")
        suite.expect([VercelSupport.State.ready, .error, .canceled].allSatisfy(\.isFinished)
                     && !VercelSupport.State.unknown.isFinished && !VercelSupport.State.building.isFinished,
                     "ready, error and canceled are finished")
    }

    private static func parsing(_ suite: TestSuite) {
        let list = deployments(scope: "Team")
        suite.expect(list.map(\.uid) == ["dpl_build", "dpl_ready", "dpl_failed"],
                     "deployments without an id are skipped, the rest keep their order")
        let building = list[0]
        suite.expect(building.project == "web" && building.state == .building && building.isProduction
                     && building.branch == "main" && building.commitTitle == "Fix the header"
                     && building.created == Date(timeIntervalSince1970: 1_763_520_000) && building.scope == "Team",
                     "a deployment reads its project, state, target, branch, commit's first line, time and team")
        suite.expect(building.openURL?.absoluteString == "https://vercel.com/team/web/dpl_build",
                     "a deployment on its way opens its build log on the dashboard")
        let ready = list[1]
        suite.expect(ready.state == .ready && !ready.isProduction && ready.branch == "feature/a"
                     && ready.commitTitle == nil && ready.created == Date(timeIntervalSince1970: 1_763_510_000),
                     "readyState wins, createdAt is read, GitLab refs count and a blank commit is none")
        suite.expect(ready.openURL?.absoluteString == "https://docs-xyz.vercel.app",
                     "a ready deployment opens itself")
        let failed = list[2]
        suite.expect(failed.inspectorURL == nil && failed.openURL?.absoluteString == "https://api-1.vercel.app",
                     "only an https dashboard link is kept; without one a failed deployment opens its host")
        suite.expect(VercelSupport.deployments(from: Data("{\"error\": {}}".utf8), scope: nil) == nil
                     && VercelSupport.deployments(from: Data("not json".utf8), scope: nil) == nil,
                     "an answer without deployments is no list")

        let teams = VercelSupport.teams(from: Data("""
            {"teams": [{"id": "team_1", "slug": "acme", "name": "Acme"}, {"id": "team_2", "slug": "solo", "name": ""},
                       {"slug": "broken"}], "pagination": {}}
            """.utf8))
        suite.expect(teams == [VercelSupport.Team(id: "team_1", slug: "acme", name: "Acme"),
                               VercelSupport.Team(id: "team_2", slug: "solo", name: "solo")],
                     "teams need an id and fall back to their slug for a name")
        suite.expect(VercelSupport.isPlausibleToken("  AbCdEf0123456789xyzQ  ")
                     && VercelSupport.isPlausibleToken("vcp_abc-DEF_1234567890")
                     && !VercelSupport.isPlausibleToken("short")
                     && !VercelSupport.isPlausibleToken("has spaces inside the token value")
                     && !VercelSupport.isPlausibleToken("tökenWithUnicode123456"),
                     "a token is one run of letters, digits, _ or -")
    }

    private static func merging(_ suite: TestSuite) {
        let personal = [deployment("a", .ready, created: 100), deployment("b", .ready, created: 300)]
        let team = [deployment("b", .ready, created: 300, scope: "Acme"), deployment("c", .error, created: 200, scope: "Acme")]
        let merged = VercelSupport.merged([personal, team])
        suite.expect(merged.map(\.uid) == ["b", "c", "a"], "scopes merge newest first, each deployment once")
        suite.expect(merged.first?.scope == "Acme", "a deployment seen in a team keeps the team's name")
        suite.expect(VercelSupport.merged([personal, team], limit: 2).count == 2, "the merged list is capped")
        suite.expect(VercelSupport.mixesScopes(merged) && !VercelSupport.mixesScopes(team),
                     "the team is named only when the list mixes scopes")

        let read = VercelSupport.ScopeResult(status: 200, deployments: personal)
        let refused = VercelSupport.ScopeResult(status: 403, deployments: nil)
        let lost = VercelSupport.ScopeResult(status: nil, deployments: nil)
        suite.expect(VercelSupport.outcome([refused, read]) == .ready(VercelSupport.merged([personal])),
                     "one scope answering is enough; a team the token cannot see is skipped")
        suite.expect(VercelSupport.outcome([refused, VercelSupport.ScopeResult(status: 401, deployments: nil)]) == .unauthorized,
                     "a token refused everywhere is unauthorized")
        suite.expect(VercelSupport.outcome([lost, VercelSupport.ScopeResult(status: 500, deployments: nil)]) == .failed
                     && VercelSupport.outcome([]) == .failed,
                     "no answer at all is a failure")
        suite.expect(VercelSupport.outcome([VercelSupport.ScopeResult(status: 200, deployments: [])]) == .ready([]),
                     "an account with no deployments is ready and empty")
    }

    private static func liveActivity(_ suite: TestSuite) {
        let before = [deployment("a", .building, created: 200), deployment("b", .queued, created: 100, project: "docs"),
                      deployment("c", .ready, created: 50)]
        let after = [deployment("a", .ready, created: 200), deployment("b", .error, created: 100, project: "docs"),
                     deployment("c", .ready, created: 50), deployment("d", .ready, created: 300)]
        suite.expect(VercelSupport.finished(previous: before, current: after).map(\.uid) == ["a", "b"],
                     "only deployments seen on their way count as just finished")
        suite.expect(VercelSupport.finished(previous: [], current: after).isEmpty,
                     "the first read after launch announces nothing")

        let now = Date(timeIntervalSince1970: 1000)
        suite.expect(VercelSupport.activity(deployments: before, result: nil, resultSince: nil, now: now)
                     == .building(project: "web", count: 2),
                     "the newest build on its way names the island, with how many build")
        let result = after[1]
        suite.expect(VercelSupport.activity(deployments: after, result: result, resultSince: now, now: now.addingTimeInterval(3))
                     == .result(project: "docs", state: .error),
                     "a result shows after the build ends")
        suite.expect(VercelSupport.activity(deployments: after, result: result, resultSince: now,
                                            now: now.addingTimeInterval(VercelSupport.resultDuration)) == nil,
                     "the result goes after its moment")
        suite.expect(VercelSupport.activity(deployments: before, result: result, resultSince: now, now: now)
                     == .building(project: "web", count: 2),
                     "a build on its way wins over a result")
        suite.expect(VercelSupport.activity(deployments: after, result: nil, resultSince: nil, now: now) == nil,
                     "nothing building and nothing just ended shows nothing")
        suite.expect(VercelSupport.Activity.result(project: "x", state: .ready).state == .ready
                     && VercelSupport.Activity.building(project: "x", count: 1).state == .building,
                     "an activity knows its state")
    }

    private static func polling(_ suite: TestSuite) {
        let idle = [deployment("a", .ready, created: 1)]
        let busy = idle + [deployment("b", .initializing, created: 2)]
        suite.expect(VercelSupport.pollInterval(deployments: busy, failed: false) == VercelSupport.buildingInterval
                     && VercelSupport.pollInterval(deployments: idle, failed: false) == VercelSupport.idleInterval
                     && VercelSupport.pollInterval(deployments: [], failed: true) == VercelSupport.failureInterval
                     && VercelSupport.pollInterval(deployments: busy, failed: true) == VercelSupport.failedBuildInterval,
                     "quick while building, slow when idle, backing off after a failure")
        suite.expect((15...20).contains(VercelSupport.buildingInterval)
                     && (120...300).contains(VercelSupport.idleInterval)
                     && VercelSupport.failedBuildInterval < VercelSupport.failureInterval,
                     "the cadence stays within 15–20 s building and 2–5 min idle")
    }

    private static func requests(_ suite: TestSuite) {
        let personal = VercelSupport.deploymentsRequest(teamID: nil, token: " tok \n", userAgent: "Zenith/1")
        suite.expect(personal.url?.absoluteString == "https://api.vercel.com/v6/deployments?limit=10"
                     && personal.value(forHTTPHeaderField: "Authorization") == "Bearer tok"
                     && personal.value(forHTTPHeaderField: "User-Agent") == "Zenith/1",
                     "the personal account's deployments, with the token as Bearer")
        let team = VercelSupport.deploymentsRequest(teamID: "team_1", token: "tok", userAgent: "Zenith/1")
        suite.expect(team.url?.absoluteString == "https://api.vercel.com/v6/deployments?limit=10&teamId=team_1",
                     "a team's deployments name the team")
        suite.expect(VercelSupport.teamsRequest(token: "tok", userAgent: "Zenith/1").url?.absoluteString
                     == "https://api.vercel.com/v2/teams?limit=10",
                     "the teams the token can see")
    }
}

/// Zenith fork: the GitHub CLI's answer, what a failed run means and where
/// `gh` is looked for.
enum GitHubTests {
    static func run(_ suite: TestSuite) {
        parsing(suite)
        failures(suite)
        command(suite)
        location(suite)
    }

    /// The shape `gh api graphql` answers with for Zenith's query.
    static let inboxJSON = """
        {"data": {"viewer": {"login": "someone"},
          "review": {"issueCount": 3, "nodes": [
            {"number": 12, "title": " Add the thing ", "url": "https://github.com/acme/web/pull/12", "isDraft": false,
             "updatedAt": "2026-11-19T00:44:19Z", "repository": {"nameWithOwner": "acme/web"},
             "author": {"login": "friend"},
             "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "PENDING"}}}]}},
            {"number": 13, "title": "No checks", "url": "https://github.com/acme/web/pull/13", "isDraft": true,
             "updatedAt": "2026-11-18T10:00:00.5Z", "repository": {"nameWithOwner": "acme/web"},
             "author": null, "commits": {"nodes": [{"commit": {"statusCheckRollup": null}}]}},
            {}
          ]},
          "mine": {"issueCount": 1, "nodes": [
            {"number": 7, "title": "Fix CI", "url": "https://github.com/someone/tool/pull/7", "isDraft": false,
             "updatedAt": "2026-11-17T08:00:00Z", "repository": {"nameWithOwner": "someone/tool"},
             "author": {"login": "someone"},
             "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": "FAILURE"}}}]}}
          ]}}}
        """

    private static func parsing(_ suite: TestSuite) {
        guard let inbox = GitHubSupport.inbox(from: Data(inboxJSON.utf8)) else {
            suite.expect(false, "the GitHub inbox parses")
            return
        }
        suite.expect(inbox.login == "someone" && inbox.reviewRequested.count == 2 && inbox.reviewCount == 3
                     && inbox.mine.count == 1 && inbox.mineCount == 1,
                     "both groups parse with their totals, skipping nodes that are not pull requests")
        let first = inbox.reviewRequested[0]
        suite.expect(first.number == 12 && first.title == "Add the thing" && first.repository == "acme/web"
                     && first.author == "friend" && !first.isDraft && first.checks == .pending
                     && first.url.absoluteString == "https://github.com/acme/web/pull/12"
                     && first.updated == GitHubSupport.date(from: "2026-11-19T00:44:19Z"),
                     "a pull request reads its number, title, repository, author, checks and time")
        let second = inbox.reviewRequested[1]
        suite.expect(second.isDraft && second.author == nil && second.checks == .none
                     && second.updated == GitHubSupport.date(from: "2026-11-18T10:00:00.5Z"),
                     "a draft without checks or author, with fractional seconds, still reads")
        suite.expect(inbox.mine[0].checks == .failure && inbox.failingCount == 1 && !inbox.isEmpty,
                     "failing checks on the person's own pull requests are counted")
        suite.expect(GitHubSupport.Checks(rollup: "SUCCESS") == .success && GitHubSupport.Checks(rollup: "ERROR") == .failure
                     && GitHubSupport.Checks(rollup: "EXPECTED") == .pending && GitHubSupport.Checks(rollup: nil) == .none,
                     "GitHub's rollup states map to passed, failed, running or none")

        let empty = GitHubSupport.inbox(from: Data("""
            {"data":{"viewer":{"login":"me"},"review":{"issueCount":0,"nodes":[]},"mine":{"issueCount":0,"nodes":[]}}}
            """.utf8))
        suite.expect(empty?.isEmpty == true && empty?.login == "me", "an empty inbox is an inbox")
        let noisy = GitHubSupport.inbox(from: Data(("warning: something\n" + inboxJSON + "\n").utf8))
        suite.expect(noisy?.mine.count == 1, "a line gh writes around the JSON does not hide it")
        suite.expect(GitHubSupport.inbox(from: Data("""
            {"errors":[{"message":"Field 'x' doesn't exist"}]}
            """.utf8)) == nil && GitHubSupport.inbox(from: Data("nope".utf8)) == nil,
                     "an error answer is no inbox")
    }

    private static func failures(_ suite: TestSuite) {
        suite.expect(GitHubSupport.failure(status: 4, output: "To get started with GitHub CLI, please run:  gh auth login")
                     == .notSignedIn,
                     "gh without an account asks to sign in")
        suite.expect(GitHubSupport.failure(status: 1, output: "gh: Bad credentials (HTTP 401)") == .notSignedIn,
                     "a refused token asks to sign in again")
        suite.expect(GitHubSupport.failure(status: 1, output: "error connecting to api.github.com") == .failed,
                     "anything else is a failure to reach GitHub")
    }

    private static func command(_ suite: TestSuite) {
        let arguments = GitHubSupport.arguments(pageSize: 5)
        suite.expect(Array(arguments.prefix(2)) == ["api", "graphql"]
                     && arguments.contains("review=\(GitHubSupport.reviewQuery)")
                     && arguments.contains("mine=\(GitHubSupport.mineQuery)")
                     && arguments.contains("first=5")
                     && arguments.contains { $0.hasPrefix("query=") && $0.contains("statusCheckRollup") },
                     "one GraphQL call asks for both groups with their checks")
        suite.expect(GitHubSupport.reviewQuery.contains("review-requested:@me") && GitHubSupport.reviewQuery.contains("is:open")
                     && GitHubSupport.mineQuery.contains("author:@me") && GitHubSupport.mineQuery.contains("is:open"),
                     "the groups are open pull requests awaiting the person's review, and their own")
        let environment = GitHubSupport.environment(for: URL(fileURLWithPath: "/nix/store/x/bin/gh"),
                                                    base: ["PATH": "/usr/bin:/bin", "HOME": "/Users/someone"])
        suite.expect(environment["PATH"]?.hasPrefix("/nix/store/x/bin:") == true && environment["HOME"] == "/Users/someone"
                     && environment["GH_PROMPT_DISABLED"] == "1" && environment["GH_NO_UPDATE_NOTIFIER"] == "1",
                     "gh runs with its own folder on PATH and nothing interactive")
    }

    private static func location(_ suite: TestSuite) {
        let home = URL(fileURLWithPath: "/Users/someone")
        let candidates = GitHubSupport.candidates(home: home, searchPath: "/custom/bin:relative/bin:/opt/homebrew/bin")
        suite.expect(candidates.first?.path == "/opt/homebrew/bin/gh"
                     && candidates.contains { $0.path == "/usr/local/bin/gh" }
                     && candidates.contains { $0.path == "/Users/someone/.local/bin/gh" }
                     && candidates.last?.path == "/custom/bin/gh"
                     && !candidates.contains { $0.path.hasPrefix("relative") }
                     && candidates.filter { $0.path == "/opt/homebrew/bin/gh" }.count == 1,
                     "Homebrew first, then the usual folders, then the absolute folders of PATH, each once")
        let found = GitHubSupport.executable(home: home, searchPath: "/custom/bin") { $0 == "/custom/bin/gh" }
        suite.expect(found?.path == "/custom/bin/gh", "a gh on PATH is found when the usual folders have none")
        suite.expect(GitHubSupport.executable(home: home, searchPath: nil) { _ in false } == nil,
                     "no gh anywhere is none")
        suite.expect(GitHubSupport.executable(home: home) { $0 == "/usr/local/bin/gh" || $0 == "/opt/homebrew/bin/gh" }?.path
                     == "/opt/homebrew/bin/gh",
                     "Apple silicon Homebrew wins over an older Intel one")
    }
}
