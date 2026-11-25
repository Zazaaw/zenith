// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Watchtower's words: the sites the Mac watches and the safety of the
/// person's work (unpushed repos, Time Machine, disk space), on plain values
/// so the iPhone and the Watch say the same thing and it can be tested.
public enum PocketWatchtowerPresentation {
    /// A certificate ending sooner than this needs a look.
    public static let certificateWarning: TimeInterval = 14 * 24 * 3600
    /// A backup older than this needs a look.
    public static let staleBackup: TimeInterval = 7 * 24 * 3600
    /// Free disk below these is a warning, then an alert.
    public static let lowDisk = 15
    public static let criticalDisk = 5

    // MARK: Words

    /// "one" … "ten", then digits: "two things need you".
    public static func number(_ value: Int) -> String {
        let words = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return words.indices.contains(value) ? words[value] : String(value)
    }

    /// "one thing", "two things".
    public static func count(_ value: Int, _ noun: String) -> String {
        number(value) + " " + noun + (value == 1 ? "" : "s")
    }

    /// The 24-hour time with a dot, as the Style Kit writes it: "9.40", "15.22".
    public static func timeOfDay(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return "\(parts.hour ?? 0)." + String(format: "%02d", parts.minute ?? 0)
    }

    /// When a status began: "since 9.40", "since yesterday, 21.10", "for 5 days".
    public static func since(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let at = min(date, now)
        if calendar.isDate(at, inSameDayAs: now) { return "since " + timeOfDay(at, calendar: calendar) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(at, inSameDayAs: yesterday) {
            return "since yesterday, " + timeOfDay(at, calendar: calendar)
        }
        let days = max(2, calendar.dateComponents([.day], from: calendar.startOfDay(for: at),
                                                  to: calendar.startOfDay(for: now)).day ?? 2)
        return "for \(days) days"
    }

    /// The first letter up, for a clause that opens a sentence.
    static func capitalised(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    // MARK: Sites

    /// Worst first: down, paused, slow, not yet known, then up; by name within.
    public static func sorted(_ sites: [PocketSites.Site]) -> [PocketSites.Site] {
        sites.enumerated().sorted { a, b in
            let ra = rank(a.element.status), rb = rank(b.element.status)
            if ra != rb { return ra < rb }
            return a.offset < b.offset
        }.map(\.element)
    }

    static func rank(_ status: PocketSites.Site.Status) -> Int {
        switch status {
        case .down: return 0
        case .paused: return 1
        case .slow: return 2
        case .unknown: return 3
        case .up: return 4
        }
    }

    /// A deploy that failed. Hosts name it "error" (Vercel, Netlify) or "failed".
    public static func deployFailed(_ site: PocketSites.Site) -> Bool {
        guard let state = site.deployState?.lowercased() else { return false }
        return state == "error" || state == "failed"
    }

    public static func certificateEndsSoon(_ site: PocketSites.Site, now: Date) -> Bool {
        guard let expires = site.certificateExpiresAt else { return false }
        return expires.timeIntervalSince(now) < certificateWarning
    }

    /// An up site that still wants a look: a failed deploy or a certificate
    /// about to end.
    public static func needsLook(_ site: PocketSites.Site, now: Date) -> Bool {
        deployFailed(site) || certificateEndsSoon(site, now: now)
    }

    public static func siteBadge(_ site: PocketSites.Site) -> PocketBadge {
        switch site.status {
        case .up: return PocketBadge("Up", .good)
        case .down: return PocketBadge("Down", .alert)
        case .paused: return PocketBadge("Paused", .attention)
        case .slow: return PocketBadge("Slow", .attention)
        case .unknown: return PocketBadge("Checking", .quiet)
        }
    }

    public static func siteTone(_ site: PocketSites.Site) -> PocketTone { siteBadge(site).tone }

    /// The number on the right: "182 ms" while it answers well, the HTTP
    /// status when it doesn't, nil when nothing came back.
    public static func siteValue(_ site: PocketSites.Site) -> String? {
        if let status = site.httpStatus, !(200..<400).contains(status) { return String(status) }
        if let latency = site.latencyMs { return latency >= 1000 ? seconds(latency) : "\(latency) ms" }
        return site.httpStatus.map(String.init)
    }

    /// "2.4 s".
    static func seconds(_ milliseconds: Int) -> String {
        String(format: "%.1f s", Double(milliseconds) / 1000)
    }

    /// The row's small line: who hosts it, how its deploy went, its
    /// certificate when it ends soon, or why it is down.
    public static func siteMeta(_ site: PocketSites.Site, now: Date) -> String {
        var parts: [String] = []
        switch site.host?.lowercased() {
        case "vercel"?: parts.append("Vercel")
        case "netlify"?: parts.append("Netlify")
        default: break
        }
        switch site.status {
        case .down:
            parts.append(site.httpStatus.map { "answers \($0)" } ?? "no answer")
        case .paused:
            parts.append("paused by its host")
        case .unknown where site.checkedAt == nil:
            parts.append("not checked yet")
        default:
            break
        }
        if deployFailed(site) {
            parts.append("deploy failed")
        } else if let state = site.deployState?.lowercased(), ["building", "queued", "initializing", "enqueued"].contains(state) {
            parts.append("deploying")
        } else if let deployed = site.deployedAt {
            parts.append("deployed " + PocketPresentation.ago(deployed, now: now))
        }
        if let expires = site.certificateExpiresAt, certificateEndsSoon(site, now: now) {
            let days = Int(expires.timeIntervalSince(now) / 86_400)
            parts.append(expires <= now ? "certificate expired" : days < 1 ? "certificate ends today"
                         : "certificate ends in \(count(days, "day"))")
        }
        if parts.isEmpty { return site.url.hasPrefix("https://") ? "https" : "http" }
        return parts.joined(separator: " · ")
    }

    /// "checked 9.40": the newest check.
    public static func checkedLine(_ sites: PocketSites?, calendar: Calendar = .current) -> String? {
        guard let newest = sites?.sites.compactMap(\.checkedAt).max() else { return nil }
        return "checked " + timeOfDay(newest, calendar: calendar)
    }

    public static func sitesBadge(_ sites: PocketSites?, now: Date) -> PocketBadge {
        let list = sites?.sites ?? []
        guard !list.isEmpty else { return PocketBadge("None", .quiet) }
        if list.contains(where: { $0.status == .down }) { return PocketBadge("Down", .alert) }
        if list.contains(where: { $0.status == .paused }) { return PocketBadge("Paused", .attention) }
        if list.allSatisfy({ $0.status == .unknown }) { return PocketBadge("Checking", .quiet) }
        if list.contains(where: { $0.status == .slow }) { return PocketBadge("Slow", .attention) }
        if list.contains(where: { needsLook($0, now: now) }) { return PocketBadge("Look", .attention) }
        return PocketBadge("All up", .good)
    }

    /// Whether Home's Sites card should carry a dot.
    public static func sitesNeedYou(_ sites: PocketSites?, now: Date) -> Bool {
        (sites?.sites ?? []).contains { $0.status == .down || $0.status == .paused || needsLook($0, now: now) }
    }

    /// "**Your sites are up,** one deploy needs a look.", "**example.com is
    /// down,** since 9.40." … the worst news first.
    public static func sitesSentence(_ sites: PocketSites?, now: Date, calendar: Calendar = .current) -> PocketSentence {
        let list = sites?.sites ?? []
        guard !list.isEmpty else {
            return PocketSentence(lead: "Watching ", value: "no sites", after: ".",
                                  rest: "Add them in Zenith on your Mac, under iPhone & Watch.", tone: .quiet)
        }
        let down = list.filter { $0.status == .down }
        if down.count == 1 {
            let site = down[0]
            return PocketSentence(lead: site.name + " is ", value: "down", after: ",",
                                  rest: whenLine(site, now: now, calendar: calendar), tone: .alert)
        }
        if down.count > 1 {
            let rest = down.count == list.count ? "every one you watch." : "\(down[0].name) and \(number(down.count - 1)) more."
            return PocketSentence(lead: capitalised(number(down.count)) + " sites are ", value: "down", after: ",",
                                  rest: rest, tone: .alert)
        }
        let paused = list.filter { $0.status == .paused }
        if paused.count == 1 {
            return PocketSentence(lead: paused[0].name + " is ", value: "paused", after: ",",
                                  rest: "its host stopped serving it.", tone: .attention)
        }
        if paused.count > 1 {
            return PocketSentence(lead: capitalised(number(paused.count)) + " sites are ", value: "paused", after: ",",
                                  rest: "their hosts stopped serving them.", tone: .attention)
        }
        if list.allSatisfy({ $0.status == .unknown }) {
            return PocketSentence(lead: "Checking ", value: "your sites", after: ",",
                                  rest: "the first answers come in soon.", tone: .quiet)
        }
        let slow = list.filter { $0.status == .slow }
        if slow.count == 1 {
            let rest = slow[0].latencyMs.map { "it took \(seconds($0)) to answer." } ?? "it answers late."
            return PocketSentence(lead: slow[0].name + " is ", value: "slow", after: ",", rest: rest, tone: .attention)
        }
        if slow.count > 1 {
            return PocketSentence(lead: capitalised(number(slow.count)) + " sites are ", value: "slow", after: ",",
                                  rest: "they answer late.", tone: .attention)
        }
        let lead = list.count == 1 ? list[0].name + " is " : "Your sites are "
        return PocketSentence(lead: lead, value: "up", after: ",", rest: lookLine(list, now: now), tone: .good)
    }

    /// "since 9.40.", or as of the last check when the start isn't known.
    static func whenLine(_ site: PocketSites.Site, now: Date, calendar: Calendar) -> String {
        if let start = site.since { return since(start, now: now, calendar: calendar) + "." }
        if let checked = site.checkedAt { return "as of " + timeOfDay(checked, calendar: calendar) + "." }
        return "as of the last check."
    }

    /// What an all-up list still asks: failed deploys, ending certificates.
    static func lookLine(_ list: [PocketSites.Site], now: Date) -> String {
        let deploys = list.filter(deployFailed).count
        let certificates = list.filter { !deployFailed($0) && certificateEndsSoon($0, now: now) }.count
        switch (deploys, certificates) {
        case (0, 0):
            return list.count == 1 ? (list[0].latencyMs.map { "answering in \($0) ms." } ?? "answering well.")
                : "all \(number(list.count)) answering well."
        case (_, 0): return count(deploys, "deploy") + (deploys == 1 ? " needs" : " need") + " a look."
        case (0, _): return count(certificates, "certificate") + (certificates == 1 ? " ends" : " end") + " soon."
        default: return count(deploys + certificates, "thing") + " need a look."
        }
    }

    // MARK: Safety

    /// How much a repo stands to lose: no remote at all, then commits that
    /// never left the Mac, then changes never committed.
    public enum Risk: Int, Comparable, Sendable {
        case noRemote = 0, unpushed, uncommitted, none
        public static func < (a: Risk, b: Risk) -> Bool { a.rawValue < b.rawValue }
    }

    public static func risk(_ repo: PocketSafety.Repo) -> Risk {
        if !repo.hasRemote { return .noRemote }
        if repo.unpushed > 0 { return .unpushed }
        if repo.uncommitted > 0 { return .uncommitted }
        return .none
    }

    /// Riskiest first; within a risk, the most work first, then by name.
    public static func sorted(_ repos: [PocketSafety.Repo]) -> [PocketSafety.Repo] {
        repos.sorted { a, b in
            let ra = risk(a), rb = risk(b)
            if ra != rb { return ra < rb }
            let wa = a.unpushed * 10 + a.uncommitted, wb = b.unpushed * 10 + b.uncommitted
            if wa != wb { return wa > wb }
            return a.path.localizedStandardCompare(b.path) == .orderedAscending
        }
    }

    public static func repoTone(_ repo: PocketSafety.Repo) -> PocketTone {
        switch risk(repo) {
        case .noRemote: return .alert
        case .unpushed: return .attention
        case .uncommitted: return .info
        case .none: return .good
        }
    }

    /// "2 commits not pushed · main", "no remote · 6 changed files", "3 changed files · main".
    public static func repoMeta(_ repo: PocketSafety.Repo) -> String {
        var parts: [String] = []
        if !repo.hasRemote { parts.append("no remote") }
        if repo.unpushed > 0 { parts.append("\(repo.unpushed) commit\(repo.unpushed == 1 ? "" : "s") not pushed") }
        if repo.uncommitted > 0 { parts.append("\(repo.uncommitted) changed file\(repo.uncommitted == 1 ? "" : "s")") }
        if let branch = repo.branch, !branch.isEmpty, repo.hasRemote { parts.append(branch) }
        return parts.isEmpty ? "all pushed" : parts.joined(separator: " · ")
    }

    /// The backup's state.
    public enum Backup: Equatable, Sendable {
        /// Not read yet (an older Mac, or the scan hasn't run).
        case unknown
        /// No destination at all.
        case off
        /// A destination, but no backup the Mac could see (never ran, or its disk is away).
        case none
        case recent(Date)
        case stale(Date)
    }

    public static func backup(_ safety: PocketSafety?, now: Date) -> Backup {
        guard let safety, let configured = safety.timeMachineConfigured else { return .unknown }
        guard configured else { return .off }
        guard let last = safety.lastBackup else { return .none }
        return now.timeIntervalSince(last) > staleBackup ? .stale(last) : .recent(last)
    }

    public static func backupTitle(_ safety: PocketSafety?, now: Date) -> String {
        switch backup(safety, now: now) {
        case .unknown: return "Time Machine"
        case .off: return "Time Machine has never run"
        case .none: return "No backup found"
        case .recent(let at): return "Backed up " + PocketPresentation.ago(at, now: now)
        case .stale(let at): return "Last backup " + PocketPresentation.ago(at, now: now)
        }
    }

    public static func backupMeta(_ safety: PocketSafety?, now: Date) -> String {
        switch backup(safety, now: now) {
        case .unknown: return "not read yet"
        case .off: return "plug in a disk to start backing up"
        case .none: return "connect its disk so it can run"
        case .recent: return "time machine"
        case .stale: return "connect its disk soon"
        }
    }

    public static func backupTone(_ safety: PocketSafety?, now: Date) -> PocketTone {
        switch backup(safety, now: now) {
        case .unknown: return .quiet
        case .off: return .alert
        case .none, .stale: return .attention
        case .recent: return .good
        }
    }

    public static func diskTone(_ percent: Int) -> PocketTone {
        percent < criticalDisk ? .alert : percent < lowDisk ? .attention : .plain
    }

    /// "42% free".
    public static func diskLine(_ percent: Int) -> String { "\(max(0, min(100, percent)))% free" }

    /// Everything that needs the person: each risky repo, a backup that
    /// isn't running, a disk running out.
    public static func todo(_ safety: PocketSafety?, now: Date) -> Int {
        guard let safety else { return 0 }
        let repos = max(safety.reposAtRisk ?? 0, safety.repos.filter { risk($0) != .none }.count)
        let backupTodo: Int
        switch backup(safety, now: now) {
        case .off, .none, .stale: backupTodo = 1
        case .unknown, .recent: backupTodo = 0
        }
        let disk = (safety.diskFreePercent.map { $0 < lowDisk } ?? false) ? 1 : 0
        return repos + backupTodo + disk
    }

    public static func safetyBadge(_ safety: PocketSafety?, now: Date) -> PocketBadge {
        guard safety != nil else { return PocketBadge("Not scanned", .quiet) }
        let count = todo(safety, now: now)
        return count == 0 ? PocketBadge("Safe", .good) : PocketBadge("\(count) to do", .attention)
    }

    /// "**Your work is mostly safe,** two things need you.", "**Time Machine
    /// has never run.**" …
    public static func safetySentence(_ safety: PocketSafety?, now: Date) -> PocketSentence {
        guard let safety else {
            return PocketSentence(lead: "Nothing ", value: "scanned", after: " yet.",
                                  rest: "Turn on Safety in Zenith on your Mac.", tone: .quiet)
        }
        let count = todo(safety, now: now)
        let repos = max(safety.reposAtRisk ?? 0, safety.repos.filter { risk($0) != .none }.count)
        let state = backup(safety, now: now)
        if count == 0 {
            let rest: String
            if case .recent = state { rest = "everything is pushed and backed up." } else { rest = "everything is pushed." }
            return PocketSentence(lead: "Your work is ", value: "safe", after: ",", rest: rest, tone: .good)
        }
        // Only the backup is wrong: say it plainly.
        if repos == 0, count == 1 {
            switch state {
            case .off:
                return PocketSentence(lead: "Time Machine ", value: "has never run", after: ".", rest: "", tone: .alert)
            case .none:
                return PocketSentence(lead: "Time Machine ", value: "hasn't backed up", after: ",",
                                      rest: "or its disk is away.", tone: .attention)
            case .stale(let at):
                return PocketSentence(lead: "Your last backup was ", value: PocketPresentation.ago(at, now: now), after: ",",
                                      rest: "connect its disk soon.", tone: .attention)
            case .unknown, .recent:
                break
            }
            if let disk = safety.diskFreePercent {
                return PocketSentence(lead: "Your disk is ", value: "\(disk)% free", after: ",",
                                      rest: "make some room.", tone: diskTone(disk) == .alert ? .alert : .attention)
            }
        }
        let needs = number(count) + (count == 1 ? " thing needs you." : " things need you.")
        if count >= 5 {
            return PocketSentence(lead: "Your work is ", value: "at risk", after: ",", rest: needs, tone: .alert)
        }
        return PocketSentence(lead: "Your work is ", value: "mostly safe", after: ",", rest: needs, tone: .attention)
    }

    /// Whether Home's Safety card should carry a dot.
    public static func safetyNeedsYou(_ safety: PocketSafety?, now: Date) -> Bool {
        todo(safety, now: now) > 0
    }
}
