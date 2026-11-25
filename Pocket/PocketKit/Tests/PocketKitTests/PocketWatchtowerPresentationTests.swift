// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

fileprivate typealias W = PocketWatchtowerPresentation
fileprivate typealias Site = PocketSites.Site
fileprivate typealias Repo = PocketSafety.Repo

/// A fixed clock and calendar, so times read the same anywhere.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()
/// 2027-01-15 08:00 UTC.
private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func site(_ name: String, _ status: Site.Status, http: Int? = 200, latency: Int? = 180, since: Date? = nil,
                  host: String? = nil, deploy: String? = nil, deployedAt: Date? = nil, certificate: Date? = nil) -> Site {
    Site(url: "https://\(name)", name: name, status: status, httpStatus: http, latencyMs: latency,
         checkedAt: now.addingTimeInterval(-120), host: host, deployState: deploy, deployedAt: deployedAt,
         certificateExpiresAt: certificate ?? now.addingTimeInterval(80 * day), since: since)
}

@Suite struct WatchtowerWordsTests {
    @Test func numbersAndTimes() {
        #expect(W.number(2) == "two" && W.number(10) == "ten" && W.number(12) == "12")
        #expect(W.count(1, "thing") == "one thing" && W.count(3, "thing") == "three things")
        let morning = utc.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 7, minute: 40))!
        #expect(W.timeOfDay(morning, calendar: utc) == "7.40")
        #expect(W.since(morning, now: now, calendar: utc) == "since 7.40")
        #expect(W.since(morning.addingTimeInterval(-day + 3600 * 12), now: now, calendar: utc) == "since yesterday, 19.40")
        #expect(W.since(now.addingTimeInterval(-5 * day), now: now, calendar: utc) == "for 5 days")
        #expect(W.since(now.addingTimeInterval(600), now: now, calendar: utc).hasPrefix("since 8."), "a clock running ahead")
    }
}

@Suite struct WatchtowerSitesTests {
    @Test func nothingWatched() {
        let sentence = W.sitesSentence(PocketSites(), now: now, calendar: utc)
        #expect(sentence.value == "no sites" && sentence.tone == .quiet)
        #expect(W.sitesBadge(nil, now: now) == PocketBadge("None", .quiet))
        #expect(!W.sitesNeedYou(nil, now: now))
    }

    @Test func allUpWithAFailedDeploy() {
        let sites = PocketSites(sites: [site("example.com", .up, host: "netlify", deploy: "ready", deployedAt: now.addingTimeInterval(-7200)),
                                        site("example.org", .up, host: "vercel", deploy: "error")])
        let sentence = W.sitesSentence(sites, now: now, calendar: utc)
        #expect(sentence.text == "Your sites are up, one deploy needs a look.")
        #expect(sentence.tone == .good)
        #expect(W.sitesBadge(sites, now: now) == PocketBadge("Look", .attention))
        #expect(W.sitesNeedYou(sites, now: now))
        #expect(W.siteMeta(sites.sites[0], now: now) == "Netlify · deployed 2h ago")
        #expect(W.siteMeta(sites.sites[1], now: now) == "Vercel · deploy failed")
    }

    @Test func allUpAndQuiet() {
        let sites = PocketSites(sites: [site("example.com", .up), site("example.org", .up)])
        #expect(W.sitesSentence(sites, now: now, calendar: utc).text == "Your sites are up, all two answering well.")
        #expect(W.sitesBadge(sites, now: now) == PocketBadge("All up", .good))
        let one = PocketSites(sites: [site("example.com", .up, latency: 182)])
        #expect(W.sitesSentence(one, now: now, calendar: utc).text == "example.com is up, answering in 182 ms.")
    }

    @Test func downSaysSince() {
        let start = utc.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 7, minute: 40))!
        let sites = PocketSites(sites: [site("example.com", .up), site("example.net", .down, http: 503, since: start)])
        let sentence = W.sitesSentence(sites, now: now, calendar: utc)
        #expect(sentence.text == "example.net is down, since 7.40.")
        #expect(sentence.tone == .alert && sentence.value == "down")
        #expect(W.sitesBadge(sites, now: now) == PocketBadge("Down", .alert))
        #expect(W.sorted(sites.sites).first?.name == "example.net", "the worst first")
        #expect(W.siteValue(sites.sites[1]) == "503")
        #expect(W.siteMeta(sites.sites[1], now: now) == "answers 503")
        let silent = site("example.net", .down, http: nil, latency: nil)
        #expect(W.siteMeta(silent, now: now) == "no answer" && W.siteValue(silent) == nil)
        #expect(W.sitesSentence(PocketSites(sites: [silent]), now: now, calendar: utc).text == "example.net is down, as of 7.58.")
    }

    @Test func severalDown() {
        let sites = PocketSites(sites: [site("a.example", .down), site("b.example", .down), site("c.example", .up)])
        #expect(W.sitesSentence(sites, now: now, calendar: utc).text == "Two sites are down, a.example and one more.")
    }

    @Test func pausedAndSlow() {
        let paused = PocketSites(sites: [site("example.vercel.app", .paused, http: 402, host: "vercel"), site("example.com", .slow, latency: 2400)])
        let sentence = W.sitesSentence(paused, now: now, calendar: utc)
        #expect(sentence.text == "example.vercel.app is paused, its host stopped serving it.")
        #expect(sentence.tone == .attention)
        #expect(W.siteValue(paused.sites[0]) == "402")
        #expect(W.siteMeta(paused.sites[0], now: now) == "Vercel · paused by its host")
        let slow = PocketSites(sites: [site("example.com", .slow, latency: 2400), site("example.org", .up)])
        #expect(W.sitesSentence(slow, now: now, calendar: utc).text == "example.com is slow, it took 2.4 s to answer.")
        #expect(W.siteValue(slow.sites[0]) == "2.4 s")
    }

    @Test func certificatesAndChecking() {
        let ending = site("example.com", .up, certificate: now.addingTimeInterval(5 * day + 60))
        #expect(W.siteMeta(ending, now: now) == "certificate ends in five days")
        #expect(W.sitesSentence(PocketSites(sites: [ending, site("example.org", .up)]), now: now, calendar: utc).rest
                == "one certificate ends soon.")
        let checking = Site(url: "https://example.com", name: "example.com", status: .unknown)
        #expect(W.sitesSentence(PocketSites(sites: [checking]), now: now, calendar: utc).value == "your sites")
        #expect(W.siteMeta(checking, now: now) == "not checked yet")
        #expect(W.checkedLine(PocketSites(sites: [ending]), calendar: utc) == "checked 7.58")
    }
}

@Suite struct WatchtowerSafetyTests {
    fileprivate let unpushed = Repo(name: "style-kit", path: "work/style-kit", branch: "feat/event", unpushed: 2, uncommitted: 0, hasRemote: true)
    fileprivate let orphan = Repo(name: "portfolio", path: "portfolio", branch: "main", unpushed: 0, uncommitted: 6, hasRemote: false)
    fileprivate let dirty = Repo(name: "notes", path: "notes", branch: "main", unpushed: 0, uncommitted: 3, hasRemote: true)

    @Test func mostlySafe() {
        let safety = PocketSafety(repos: [unpushed, orphan], timeMachineConfigured: true,
                                  lastBackup: now.addingTimeInterval(-3600), diskFreePercent: 40)
        let sentence = W.safetySentence(safety, now: now)
        #expect(sentence.text == "Your work is mostly safe, two things need you.")
        #expect(sentence.tone == .attention)
        #expect(W.safetyBadge(safety, now: now) == PocketBadge("2 to do", .attention))
    }

    @Test func timeMachineNeverRan() {
        let safety = PocketSafety(repos: [], timeMachineConfigured: false, diskFreePercent: 40)
        let sentence = W.safetySentence(safety, now: now)
        #expect(sentence.text == "Time Machine has never run.")
        #expect(sentence.tone == .alert)
        #expect(W.backupTitle(safety, now: now) == "Time Machine has never run")
        #expect(W.backupTone(safety, now: now) == .alert)
        let away = PocketSafety(timeMachineConfigured: true, diskFreePercent: 40)
        #expect(W.safetySentence(away, now: now).text == "Time Machine hasn't backed up, or its disk is away.")
        let stale = PocketSafety(timeMachineConfigured: true, lastBackup: now.addingTimeInterval(-12 * day), diskFreePercent: 40)
        #expect(W.safetySentence(stale, now: now).text == "Your last backup was 12d ago, connect its disk soon.")
    }

    @Test func safeAndUnknown() {
        let safe = PocketSafety(timeMachineConfigured: true, lastBackup: now.addingTimeInterval(-3600), diskFreePercent: 40)
        #expect(W.safetySentence(safe, now: now).text == "Your work is safe, everything is pushed and backed up.")
        #expect(W.safetyBadge(safe, now: now) == PocketBadge("Safe", .good))
        let noTimeMachineReading = PocketSafety(diskFreePercent: 40)
        #expect(W.safetySentence(noTimeMachineReading, now: now).text == "Your work is safe, everything is pushed.")
        #expect(W.safetySentence(nil, now: now).tone == .quiet)
        #expect(!W.safetyNeedsYou(nil, now: now))
    }

    @Test func lowDiskAlone() {
        let full = PocketSafety(timeMachineConfigured: true, lastBackup: now, diskFreePercent: 4)
        let sentence = W.safetySentence(full, now: now)
        #expect(sentence.text == "Your disk is 4% free, make some room.")
        #expect(sentence.tone == .alert)
    }

    @Test func atRiskCountsTheCappedRepos() {
        let safety = PocketSafety(repos: [unpushed], timeMachineConfigured: true, lastBackup: now, diskFreePercent: 40, reposAtRisk: 7)
        #expect(W.todo(safety, now: now) == 7)
        #expect(W.safetySentence(safety, now: now).text == "Your work is at risk, seven things need you.")
    }

    @Test func reposSortByRisk() {
        let sorted = W.sorted([dirty, unpushed, orphan])
        #expect(sorted.map(\.name) == ["portfolio", "style-kit", "notes"])
        #expect(W.repoMeta(unpushed) == "2 commits not pushed · feat/event")
        #expect(W.repoMeta(orphan) == "no remote · 6 changed files")
        #expect(W.repoMeta(dirty) == "3 changed files · main")
        #expect(W.repoTone(orphan) == .alert && W.repoTone(unpushed) == .attention && W.repoTone(dirty) == .info)
    }
}
