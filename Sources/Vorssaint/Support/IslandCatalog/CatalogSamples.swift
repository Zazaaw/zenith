// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Zenith fork: the island catalog's sample data, posed into the services
/// through their `catalogPose` hooks. Names, numbers and places are made up.
@MainActor
enum CatalogSamples {
    static let now = Date()

    /// Every service back to nothing going on, before each shot.
    static func reset() {
        NotchTimerService.shared.catalogPose(NotchTimerSession())
        NotchMusicService.shared.catalogPose(playback: nil, artwork: nil, tint: nil)
        NotchDownloadService.shared.catalogPose(items: [], folderName: nil)
        AgentUsageService.shared.catalogPose(AgentUsageSnapshot())
        ClaudeHooksService.shared.catalogPose(sessions: [], strip: nil)
        NotchCalendarService.shared.catalogPose(events: [], countdown: nil)
        KeepAwakeManager.shared.catalogPose(active: false, until: nil, minutes: nil)
        VercelService.shared.catalogPose(state: .idle, deployments: [], activity: nil)
        CommandActivityService.shared.catalogPose(nil)
        CardImportService.shared.catalogPose(activity: nil, progress: CardImportProgress())
        CardBackupService.shared.catalogPose(progress: CardImportProgress())
        ExportTrackerService.shared.catalogPose(activity: nil, live: nil)
        DevServersService.shared.catalogPose(servers: [], indicator: nil)
        SkyService.shared.catalogPose(day: nil, prayer: nil, golden: nil)
        GitService.shared.catalogPose(state: .empty, current: nil, snapshot: nil, indicator: nil)
        BatteriesStore.shared.devices = [] // Zenith fork
        BatteriesStore.shared.lastUpdated = nil
        BatteriesIslandService.shared.catalogPose(indicator: nil)
        WakaTimeService.shared.catalogPose(today: nil, history: [:])
        GitHubService.shared.catalogPose(nil)
        NotchNotificationService.shared.catalogPose([])
        ShelfService.shared.catalogPose([])
        ClipboardHistoryService.shared.catalogPose([])
    }

    // MARK: Music

    static var cover: NSImage? { ZenithLockScreenPreviewSample.cover }

    static func music(playing: Bool = true) {
        let base = ZenithLockScreenPreviewSample.playback(from: now)
        let playback = NotchPlayback(track: base.track, isPlaying: playing, elapsed: base.elapsed, duration: base.duration,
                                     rate: playing ? 1 : 0, sampledAt: now, canSeek: true,
                                     canSkipNext: true, canSkipPrevious: true)
        NotchMusicService.shared.catalogPose(playback: playback, artwork: cover,
                                             tint: NotchArtworkTint.from(red: 0.84, green: 0.05, blue: 0.16))
    }

    // MARK: Timer

    static func timer(minutes: Int = 25, elapsed: TimeInterval = 382, mode: NotchTimerMode = .timer) {
        var session = NotchTimerSession()
        session.start(mode: mode, minutes: minutes, now: NotchTimerService.shared.now - elapsed)
        NotchTimerService.shared.catalogPose(session)
    }

    // MARK: Downloads

    static func downloads(completed: Bool = false) {
        let item = NotchDownloadItem(id: "catalog-download",
                                     url: URL(fileURLWithPath: "/Users/Shared/Downloads/Brand-Guidelines-2026.pdf"),
                                     name: "Brand-Guidelines-2026.pdf", receivedBytes: 38_400_000,
                                     fraction: completed ? 1 : 0.62, completed: completed, active: !completed,
                                     date: now)
        let older = NotchDownloadItem(id: "catalog-download-2",
                                      url: URL(fileURLWithPath: "/Users/Shared/Downloads/zenith-icons.zip"),
                                      name: "zenith-icons.zip", receivedBytes: 4_200_000, fraction: 1,
                                      completed: true, active: false, date: now.addingTimeInterval(-3600))
        NotchDownloadService.shared.catalogPose(items: [item, older], folderName: "Downloads")
    }

    // MARK: AI agents

    static func agentsWorking(_ providers: [AgentProvider] = [.claude]) {
        var snapshot = AgentUsageSnapshot()
        snapshot.loaded = true
        snapshot.now = now
        snapshot.seen = Set(providers)
        snapshot.live = providers.enumerated().map { index, provider in
            AgentLiveSession(id: "catalog-\(provider.rawValue)", provider: provider,
                             started: now.addingTimeInterval(-640 - Double(index) * 300),
                             lastActivity: now.addingTimeInterval(-4), model: provider == .claude ? "claude-opus-4" : "gpt-5",
                             project: index == 0 ? "zenith" : "satuvisual-web",
                             tokens: AgentTokens(input: 18_400, cacheWrite: 2_100, cacheRead: 240_000, output: 9_800),
                             cost: 1.84)
        }
        AgentUsageService.shared.catalogPose(snapshot)
    }

    static func claudeNeedsYou() {
        let session = ClaudeHooksSupport.Session(id: "catalog-hooks", folder: "zenith", state: .waiting(.permission),
                                                 turnStarted: now.addingTimeInterval(-180),
                                                 lastEvent: now.addingTimeInterval(-6))
        ClaudeHooksService.shared.catalogPose(sessions: [session],
                                              strip: ClaudeHooksSupport.Strip(session: session.id, folder: "zenith",
                                                                              kind: .needsYou(.permission)))
    }

    // MARK: Calendar

    static let meeting = NotchCalendarEvent(id: "catalog-event", title: "Design review", calendar: "Satu Visual",
                                            start: now.addingTimeInterval(12 * 60), end: now.addingTimeInterval(57 * 60),
                                            allDay: false, location: "Zoom",
                                            color: NotchCalendarColor(red: 0.33, green: 0.55, blue: 0.98))

    static func calendarCountdown() {
        NotchCalendarService.shared.catalogPose(events: [meeting], countdown: NotchCalendarCountdown(event: meeting, ongoing: false))
    }

    // MARK: Keep Awake

    static func keepAwake() {
        KeepAwakeManager.shared.catalogPose(active: true, until: now.addingTimeInterval(42 * 60), minutes: 60)
    }

    // MARK: Vercel

    static func vercel(_ activity: VercelSupport.Activity) {
        VercelService.shared.catalogPose(state: .ready, deployments: [], activity: activity)
    }

    // MARK: Terminal commands

    static func command(_ activity: CommandActivitySupport.Activity) {
        CommandActivityService.shared.catalogPose(activity)
    }

    static let runningCommand = CommandActivitySupport.Activity.running(
        id: "catalog-npm", program: "npm", folder: "satuvisual-web", start: now.addingTimeInterval(-95), others: 1, long: false)
    static let finishedCommand = CommandActivitySupport.Activity.finished(
        id: "catalog-build", program: "swift build", folder: "zenith", duration: 214, succeeded: true)

    // MARK: Card import and backup

    static let cardProgress = CardImportProgress(totalFiles: 412, totalBytes: 48_000_000_000, copiedFiles: 173,
                                                 copiedBytes: 20_100_000_000, current: "A7S_0173.MP4", eta: 380,
                                                 bytesPerSecond: 820_000_000)

    static func cardImport(_ activity: CardImportActivity, page: Bool = false) {
        let session = CardImportSession(cardID: "SONY-A7S", cardName: "SONY A7S III",
                                        folder: URL(fileURLWithPath: "/Users/Shared/Footage/2026-11-21 Company profile"),
                                        options: CardImportOptions(), phase: .copying, copiedFiles: 173,
                                        copiedBytes: 20_100_000_000)
        CardImportService.shared.catalogPose(activity: activity, progress: cardProgress, session: page ? session : nil)
        CardBackupService.shared.catalogPose(progress: cardProgress)
    }

    // MARK: Exports

    static func export(finished: Bool = false) {
        let producer = ExportTrackerSupport.Producer(name: "DaVinci Resolve", kind: .video, tint: 0xF2994A)
        let activity = ExportTrackerSupport.Activity(
            id: "catalog-export", phase: finished ? .finished : .running,
            path: "/Users/Shared/Exports/Wedding-Teaser-4K.mov", name: "Wedding-Teaser-4K.mov", count: nil,
            producer: producer, started: now.addingTimeInterval(-75), bytes: finished ? 2_400_000_000 : nil,
            duration: finished ? 312 : 0, others: 0)
        ExportTrackerService.shared.catalogPose(activity: activity,
                                                live: finished ? nil : ExportTrackerSupport.Live(id: "catalog-export",
                                                                                                 bytes: 1_200_000_000,
                                                                                                 rate: 24_000_000))
    }

    // MARK: Dev servers

    static let servers = [
        DevServer(id: "catalog-next", kind: .next, pid: 4242, processName: "node", project: "satuvisual-web",
                  ports: [3000], port: 3000, startedAt: now.addingTimeInterval(-2 * 3600), startMicros: nil),
        DevServer(id: "catalog-vite", kind: .vite, pid: 4343, processName: "node", project: "zenith-docs",
                  ports: [5173], port: 5173, startedAt: now.addingTimeInterval(-25 * 60), startMicros: nil),
    ]

    static func devServers() {
        DevServersService.shared.catalogPose(servers: servers, indicator: servers.count)
    }

    // MARK: Sky

    static let jakarta = SkyPlace(coordinate: SolarSupport.Coordinate(latitude: -6.2, longitude: 106.82), name: "Jakarta")

    static var skyDay: SkyDay { SkyDay.make(containing: now, place: jakarta, configuration: PrayerConfiguration()) }

    static func prayer(arrived: Bool = false) {
        let moment = PrayerMoment(prayer: .asr, time: now.addingTimeInterval(arrived ? -30 : 14 * 60))
        SkyService.shared.catalogPose(day: skyDay, prayer: arrived ? .arrived(moment) : .upcoming(moment), golden: nil)
    }

    static func golden(during: Bool = false) {
        let window = SolarSupport.Window(band: .golden, morning: false,
                                         start: now.addingTimeInterval(during ? -10 * 60 : 20 * 60),
                                         end: now.addingTimeInterval(during ? 30 * 60 : 60 * 60))
        SkyService.shared.catalogPose(day: skyDay, prayer: nil, golden: during ? .during(window) : .upcoming(window))
    }

    // MARK: Batteries

    /// The contract's sample readings (BatteriesStore.sample), as the monitor
    /// would leave them in the store.
    static func batteries(_ devices: [BatteryDevice] = BatteriesStore.sample) {
        BatteriesStore.shared.devices = devices
        BatteriesStore.shared.lastUpdated = now
    }

    /// The compact form the Battery Low card leaves behind.
    static func batteryLow(_ id: String = "sample-gamepad") {
        batteries()
        guard let device = BatteriesStore.sample.first(where: { $0.id == id }) else { return }
        BatteriesIslandService.shared.catalogPose(indicator: BatteriesLowIndicator(
            deviceID: device.id, name: device.name, symbol: device.symbolName, percent: device.percent ?? 0, since: now))
    }

    /// The Battery Low card for one of the sample devices.
    static func batteryLowBurst(_ id: String = "sample-gamepad", others: [String] = []) -> ZenithIslandBurst.Content {
        let device = BatteriesStore.sample.first { $0.id == id } ?? BatteriesStore.sample[0]
        let alert = BatteriesLowAlert(id: UUID(), device: device, percent: device.percent ?? 0, others: others)
        return .batteryLow(BatteriesIslandSupport.lowBurst(alert, text: ZenithStrings.batteriesIsland(.enUS)))
    }

    // MARK: Git

    static func gitBranch() {
        GitService.shared.catalogPose(state: .empty, current: nil, snapshot: nil,
                                      indicator: GitIndicator(branch: "feat/island-catalog", dirty: true))
    }

    static func gitRepository() {
        let records = [
            "# branch.oid 4b34b6a0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6",
            "# branch.head feat/island-catalog",
            "# branch.upstream origin/feat/island-catalog",
            "# branch.ab +2 -0",
            "1 M. N... 100644 100644 100644 aaaaaaa bbbbbbb Sources/Vorssaint/UI/Notch/NotchView.swift",
            "1 .M N... 100644 100644 100644 aaaaaaa bbbbbbb Sources/Vorssaint/Services/Notch/NotchService.swift",
            "1 A. N... 000000 100644 100644 0000000 bbbbbbb Tools/IslandCatalog/render.sh",
            "? docs/island-catalog.md",
        ]
        let parsed = GitPorcelain.parse(Data(records.joined(separator: "\0").appending("\0").utf8))
        let root = "/Users/Shared/Projects/zenith"
        let snapshot = GitSnapshot(location: GitRepoLocation(root: root, gitDir: root + "/.git", commonDir: root + "/.git"),
                                   branch: parsed.branch, changes: parsed.changes,
                                   lastCommit: GitCommitSummary(shortSHA: "4b34b6a",
                                                                subject: "Lock screen v2: fix the merged slider's name",
                                                                date: now.addingTimeInterval(-42 * 60)),
                                   operation: nil, stash: 1,
                                   remotes: [GitRemoteEntry(name: "origin", url: "git@github.com:satuvisual/zenith.git")],
                                   readAt: now)
        GitService.shared.catalogPose(state: .ready,
                                      current: GitRepoSelector.Current(root: root, source: .editor,
                                                                       since: now.addingTimeInterval(-3600)),
                                      snapshot: snapshot,
                                      indicator: GitIndicator(branch: "feat/island-catalog", dirty: true))
    }

    // MARK: WakaTime, Vercel, GitHub, the recap

    static func wakaTime() {
        let today = WakaTimeSupport.Today(
            date: WakaTimeSupport.dayKey(now), totalSeconds: 18_720,
            projects: [.init(name: "zenith", seconds: 11_100), .init(name: "satuvisual-web", seconds: 6_000),
                       .init(name: "dotfiles", seconds: 1_620)],
            languages: [.init(name: "Swift", seconds: 10_800), .init(name: "TypeScript", seconds: 5400),
                        .init(name: "Markdown", seconds: 1320)])
        var history: [String: Double] = [:]
        let hours: [Double] = [3.2, 4.8, 2.1, 6.0, 5.4, 1.2, 5.2]
        for (offset, value) in hours.enumerated() {
            history[WakaTimeSupport.dayKey(now.addingTimeInterval(-Double(hours.count - 1 - offset) * 86_400))] = value * 3600
        }
        WakaTimeService.shared.catalogPose(today: today, history: history)
    }

    static func vercelDeployments() {
        func deployment(_ uid: String, _ project: String, _ state: VercelSupport.State, minutes: Double,
                        branch: String, message: String, production: Bool) -> VercelSupport.Deployment {
            VercelSupport.Deployment(uid: uid, project: project, host: "\(project)-\(uid).vercel.app", state: state,
                                     created: now.addingTimeInterval(-minutes * 60), isProduction: production,
                                     branch: branch, commitMessage: message, inspectorURL: nil, scope: nil)
        }
        VercelService.shared.catalogPose(state: .ready, deployments: [
            deployment("a1b2", "satuvisual-web", .building, minutes: 1, branch: "main", message: "Hero: new reel", production: true),
            deployment("c3d4", "satuvisual-web", .ready, minutes: 48, branch: "main", message: "Pricing copy", production: true),
            deployment("e5f6", "zenith-docs", .error, minutes: 130, branch: "docs/island", message: "Island catalog page",
                       production: false),
            deployment("g7h8", "zenith-docs", .ready, minutes: 300, branch: "main", message: "Typo fixes", production: true),
        ], activity: .building(project: "satuvisual-web", count: 1))
    }

    static func gitHub() {
        func pull(_ number: Int, _ title: String, _ repository: String, author: String?, checks: GitHubSupport.Checks,
                  hours: Double, draft: Bool = false) -> GitHubSupport.PullRequest {
            GitHubSupport.PullRequest(number: number, title: title,
                                      url: URL(string: "https://github.com/\(repository)/pull/\(number)")!,
                                      repository: repository, author: author, isDraft: draft,
                                      updated: now.addingTimeInterval(-hours * 3600), checks: checks)
        }
        let review = [pull(212, "Notch: calmer hover on capsule displays", "satuvisual/zenith", author: "raka",
                           checks: .success, hours: 1.5)]
        let mine = [pull(214, "Island catalog: render every state offscreen", "satuvisual/zenith", author: nil,
                         checks: .pending, hours: 0.3),
                    pull(87, "Pricing page refresh", "satuvisual/web", author: nil, checks: .failure, hours: 5)]
        GitHubService.shared.catalogPose(GitHubSupport.Inbox(login: "satuvisual", reviewRequested: review, reviewCount: 1,
                                                             mine: mine, mineCount: 2))
    }

    static func recap() {
        var tally = RecapTally(day: RecapSchedule.dayKey(now))
        tally.commands = 9
        tally.commandSeconds = 41 * 60
        tally.photos = 268
        tally.videos = 144
        tally.importBytes = 48_000_000_000
        tally.exports = 3
        tally.exportBytes = 6_200_000_000
        tally.turns = 54
        tally.sessions = ["a", "b", "c"]
        RecapService.shared.catalogPose(tally: tally, commits: 14)
        wakaTime()
        vercelDeployments()
        gitHub()
    }

    // MARK: Notifications, the shelf, the clipboard, the calendar

    static func notifications() {
        let items = [
            NotchSystemNotification(id: CatalogShots.notificationID, content: CatalogShots.sampleNotification,
                                    received: now.addingTimeInterval(-120), canOpen: true),
            NotchSystemNotification(id: UUID(), content: NotchNotificationContent(app: "Mail", title: "Dina Prameswari",
                                                                                  subtitle: "Brief video company profile",
                                                                                  body: "Halo Alex, terlampir brief untuk shooting minggu depan."),
                                    received: now.addingTimeInterval(-25 * 60), canOpen: true),
            NotchSystemNotification(id: UUID(), content: NotchNotificationContent(app: "Calendar", title: "Design review",
                                                                                  subtitle: "", body: "In 15 minutes · Zoom"),
                                    received: now.addingTimeInterval(-50 * 60), canOpen: true),
        ]
        NotchNotificationService.shared.catalogPose(items)
    }

    /// A made-up photo: a gradient with a sun, `hue` apart from the others.
    static func photo(_ hue: Double) -> NSImage {
        let size = NSSize(width: 240, height: 160)
        return NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: [NSColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1),
                                NSColor(hue: hue + 0.08, saturation: 0.7, brightness: 0.55, alpha: 1)])?
                .draw(in: rect, angle: -90)
            NSColor(white: 1, alpha: 0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.midX - 22, y: rect.midY - 4, width: 44, height: 44)).fill()
            return true
        }
    }

    /// A calm made-up wallpaper: a dusk sky over two soft hills.
    static let wallpaper: NSImage = NSImage(size: NSSize(width: 1600, height: 1000), flipped: false) { rect in
        NSGradient(colors: [NSColor(srgbRed: 0.98, green: 0.72, blue: 0.55, alpha: 1),
                            NSColor(srgbRed: 0.62, green: 0.48, blue: 0.72, alpha: 1),
                            NSColor(srgbRed: 0.16, green: 0.2, blue: 0.42, alpha: 1)])?.draw(in: rect, angle: 90)
        func hill(_ color: NSColor, base: CGFloat, peak: CGFloat, shift: CGFloat) {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: 0))
            path.line(to: NSPoint(x: 0, y: base))
            path.curve(to: NSPoint(x: rect.width, y: base * 0.8),
                       controlPoint1: NSPoint(x: rect.width * (0.3 + shift), y: peak),
                       controlPoint2: NSPoint(x: rect.width * (0.6 + shift), y: base * 0.4))
            path.line(to: NSPoint(x: rect.width, y: 0))
            path.close()
            color.setFill()
            path.fill()
        }
        hill(NSColor(srgbRed: 0.34, green: 0.27, blue: 0.45, alpha: 1), base: 330, peak: 520, shift: 0.1)
        hill(NSColor(srgbRed: 0.19, green: 0.16, blue: 0.3, alpha: 1), base: 220, peak: 330, shift: -0.15)
        return true
    }

    static func shelf() {
        func file(_ name: String, type: UTType) -> ShelfService.Item {
            ShelfService.Item(payload: .file(URL(fileURLWithPath: "/Users/Shared/Projects/" + name)), title: name,
                              icon: NSWorkspace.shared.icon(for: type), isImage: false)
        }
        ShelfService.shared.catalogPose([
            ShelfService.Item(payload: .file(URL(fileURLWithPath: "/Users/Shared/Projects/moodboard-01.jpg")),
                              title: "moodboard-01.jpg", icon: photo(0.58), isImage: true, hasContentThumbnail: true),
            ShelfService.Item(payload: .file(URL(fileURLWithPath: "/Users/Shared/Projects/moodboard-02.jpg")),
                              title: "moodboard-02.jpg", icon: photo(0.05), isImage: true, hasContentThumbnail: true),
            file("Brief-Company-Profile.pdf", type: .pdf),
            file("zenith-icons.zip", type: .zip),
            ShelfService.Item(payload: .link(URL(string: "https://satuvisual.id")!), title: "satuvisual.id",
                              icon: NSWorkspace.shared.icon(for: .internetShortcut), isImage: false),
        ])
    }

    static func clipboard() {
        ClipboardHistoryService.shared.catalogPose([
            ClipboardHistoryEntry(text: "https://satuvisual.id/work/zenith", copiedAt: now.addingTimeInterval(-40)),
            ClipboardHistoryEntry(text: "#5B8DEF", copiedAt: now.addingTimeInterval(-5 * 60)),
            ClipboardHistoryEntry(text: "Halo Dina, jadwal shooting kita geser ke Kamis jam 9 ya. Lokasi tetap di studio.",
                                  copiedAt: now.addingTimeInterval(-26 * 60)),
            ClipboardHistoryEntry(text: "git switch -c feat/island-catalog", copiedAt: now.addingTimeInterval(-2 * 3600),
                                  pinnedAt: now.addingTimeInterval(-3600)),
        ])
    }

    static func calendar() {
        Permissions.shared.catalogPoseCalendarAccess()
        let day = Calendar.current.startOfDay(for: now)
        func event(_ id: String, _ title: String, hour: Double, length: Double, red: Double, green: Double, blue: Double,
                   location: String = "") -> NotchCalendarEvent {
            NotchCalendarEvent(id: id, title: title, calendar: "Satu Visual",
                               start: day.addingTimeInterval(hour * 3600), end: day.addingTimeInterval((hour + length) * 3600),
                               allDay: false, location: location, color: NotchCalendarColor(red: red, green: green, blue: blue))
        }
        // Days around today, so the month grid carries dots in both calendars' colours.
        let around: [NotchCalendarEvent] = [(-18, true), (-9, true), (-9, false), (-4, true), (3, false), (7, true)]
            .enumerated().map { index, entry in
                let (offset, blue) = entry
                return event("around-\(index)", blue ? "Client call" : "Shoot", hour: 24 * Double(offset) + 10, length: 1,
                             red: blue ? 0.33 : 0.95, green: blue ? 0.55 : 0.55, blue: blue ? 0.98 : 0.2)
            }
        let events = [
            event("standup", "Stand-up", hour: 9, length: 0.25, red: 0.33, green: 0.55, blue: 0.98),
            meeting,
            event("shoot", "Shooting company profile", hour: 19, length: 2, red: 0.95, green: 0.55, blue: 0.2,
                  location: "Studio Kemang"),
        ] + around
        NotchCalendarService.shared.catalogPose(events: events.sorted { $0.start < $1.start },
                                                countdown: NotchCalendarCountdown(event: meeting, ongoing: false))
    }
}
#endif
