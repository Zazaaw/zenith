// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Zenith Pocket's Mac side on fixed inputs: the state built
/// from Zenith's readings and what the share switches leave out, when it
/// travels live and when it goes in the box, what each command from the
/// phone does, how the phone's batteries join Batteries (one entry for a
/// phone read both ways), the pairing's phases, the preferences and the
/// wallpaper's hash. No relay, network, screen lock, Keep Awake or media.
enum PocketTests {
    static func run(_ suite: TestSuite) {
        suite.run("pocket-state") { state(suite) }
        suite.run("pocket-readings") { readings(suite) }
        suite.run("pocket-cadence") { cadence(suite) }
        suite.run("pocket-commands") { commands(suite) }
        suite.run("pocket-batteries") { batteries(suite) }
        suite.run("pocket-phases") { phases(suite) }
        suite.run("pocket-preferences") { preferences(suite) }
    }

    private static let now = Date(timeIntervalSince1970: 1_795_000_000)
    private static let relay = PocketRelayConfig(url: URL(string: "https://example.supabase.co")!,
                                                 anonKey: "header.payload.signature")

    private static func session(_ id: String, _ state: ClaudeHooksSupport.Session.State,
                                steps: [ClaudeHooksSupport.Step] = []) -> ClaudeHooksSupport.Session {
        ClaudeHooksSupport.Session(id: id, folder: "zenith", state: state, steps: steps,
                                   turnStarted: now.addingTimeInterval(-300), lastEvent: now.addingTimeInterval(-10),
                                   finished: state == .done ? now.addingTimeInterval(-5) : nil,
                                   waitingSince: { if case .waiting = state { return now.addingTimeInterval(-20) }; return nil }())
    }

    private static func inputs() -> PocketMacInputs {
        var inputs = PocketMacInputs(macName: "Faiz’s MacBook Pro")
        inputs.battery = PocketMacState.Battery(percent: 62, charging: false, minutesRemaining: 240)
        inputs.locked = true
        inputs.coding = PocketMacState.Coding(seconds: 5_400, goalSeconds: 14_400)
        inputs.nextPrayer = PocketMacState.Prayer(name: "Ashar", at: now.addingTimeInterval(3_600))
        inputs.sessions = [
            session("a", .waiting(.permission), steps: [
                ClaudeHooksSupport.Step(id: "1", tool: "Read", target: "Notes.md", phase: .done),
                ClaudeHooksSupport.Step(id: "2", tool: "Bash", target: "npm", phase: .running),
            ]),
            session("b", .working),
            session("c", .done),
        ]
        inputs.playback = PocketMacInputs.Playback(title: "Song", artist: "Band", playing: true, elapsed: 30,
                                                   sampledAt: now.addingTimeInterval(-10), rate: 1, duration: 200)
        inputs.accessories = [PocketMacState.Accessory(id: "bt-1", name: "AirPods", kind: "headphones",
                                                       percent: 80, charging: false)]
        inputs.wallpaperHash = "abc"
        return inputs
    }

    // MARK: State

    private static func state(_ suite: TestSuite) {
        let shared = PocketStateBuilder.state(inputs(), sharing: PocketSharing(), now: now)
        suite.expect(shared.macName == "Faiz’s MacBook Pro" && shared.locked && shared.battery?.percent == 62,
                     "the Mac's name, lock and battery travel")
        suite.expect(shared.coding?.seconds == 5_400 && shared.nextPrayer?.name == "Ashar", "coding and prayer travel")
        suite.expect(shared.sessions.map(\.status) == [.waiting, .running, .done], "sessions keep their order and status")
        suite.expect(shared.sessions.first?.since == now.addingTimeInterval(-20)
                        && shared.sessions[1].since == now.addingTimeInterval(-300)
                        && shared.sessions[2].since == now.addingTimeInterval(-5),
                     "a session counts from its wait, its turn or its end")
        suite.expect(shared.questions.count == 1 && shared.questions.first?.tool == "Bash"
                        && shared.questions.first?.detail == "npm" && shared.questions.first?.project == "zenith",
                     "a permission wait is a question about the tool still running")
        suite.expect(shared.nowPlaying?.title == "Song" && shared.nowPlaying?.elapsed == 40,
                     "a playing song's position is counted on to now")
        suite.expect(shared.wallpaperHash == "abc" && shared.accessories.count == 1, "wallpaper and accessories travel")

        let quiet = PocketStateBuilder.state(inputs(), sharing: PocketSharing(wallpaper: false, agents: false,
                                                                              nowPlaying: false), now: now)
        suite.expect(quiet.sessions.isEmpty && quiet.questions.isEmpty, "agents off: no sessions, no questions")
        suite.expect(quiet.nowPlaying == nil && quiet.wallpaperHash == nil, "now playing and wallpaper off")
        suite.expect(quiet.battery == shared.battery && quiet.locked && quiet.coding == shared.coding
                        && quiet.accessories == shared.accessories, "the rest stays")

        var waitingInput = inputs()
        waitingInput.sessions = [session("d", .waiting(.input))]
        suite.expect(PocketStateBuilder.state(waitingInput, sharing: PocketSharing(), now: now).questions.isEmpty,
                     "waiting for the next prompt is not a question")
        var many = inputs()
        many.sessions = (0..<12).map { session("s\($0)", .working) }
        suite.expect(PocketStateBuilder.state(many, sharing: PocketSharing(), now: now).sessions.count
                        == PocketStateBuilder.maximumSessions, "at most eight sessions")
        var unnamed = inputs()
        unnamed.sessions = [ClaudeHooksSupport.Session(id: "e", folder: "", state: .working, turnStarted: now, lastEvent: now)]
        suite.expect(PocketStateBuilder.state(unnamed, sharing: PocketSharing(), now: now).sessions.first?.project
                        == "Claude Code", "a session without a folder is Claude Code")

        suite.expect(PocketStateBuilder.awakeUntil(active: false, end: now) == nil, "keep-awake off is nil")
        suite.expect(PocketStateBuilder.awakeUntil(active: true, end: nil) == .distantFuture,
                     "until turned off is the distant future")
        suite.expect(PocketStateBuilder.awakeUntil(active: true, end: now) == now, "a timed session ends at its end")
        let encoded = try? JSONEncoder().encode(shared)
        suite.expect(encoded.flatMap { try? JSONDecoder().decode(PocketMacState.self, from: $0) } == shared,
                     "the state survives coding")
    }

    private static func readings(_ suite: TestSuite) {
        let charging = PocketStateBuilder.battery(percent: 40, charging: true, minutesToFull: 55, secondsToEmpty: nil)
        suite.expect(charging == PocketMacState.Battery(percent: 40, charging: true, minutesRemaining: 55),
                     "charging counts to full")
        let draining = PocketStateBuilder.battery(percent: 40, charging: false, minutesToFull: 55, secondsToEmpty: 5_430)
        suite.expect(draining?.minutesRemaining == 91 && draining?.charging == false, "on battery counts to empty")
        let held = PocketStateBuilder.battery(percent: 80, charging: false, minutesToFull: nil, secondsToEmpty: nil)
        suite.expect(held?.minutesRemaining == nil && held?.charging == false, "held at a limit counts nothing")
        let heldPlugged = PocketStateBuilder.battery(percent: 80, charging: false, minutesToFull: nil, secondsToEmpty: 9_000, pluggedIn: true)
        suite.expect(heldPlugged?.pluggedIn == true && heldPlugged?.minutesRemaining == nil,
                     "plugged in and held says so, and does not count down a time to empty")
        let unplugged = PocketStateBuilder.battery(percent: 60, charging: false, minutesToFull: nil, secondsToEmpty: 3_600, pluggedIn: false)
        suite.expect(unplugged?.pluggedIn == false && unplugged?.minutesRemaining == 60, "on battery still counts to empty")
        suite.expect(PocketCadence.heartbeat >= 10 * 60 && PocketCadence.heartbeat > PocketCadence.boxInterval,
                     "the quiet rewrite is rare, and rarer than the busiest box cadence")
        suite.expect(PocketStateBuilder.battery(percent: nil, charging: false, minutesToFull: nil, secondsToEmpty: nil) == nil
                        && PocketStateBuilder.battery(percent: 140, charging: false, minutesToFull: nil, secondsToEmpty: nil) == nil,
                     "no level, no battery")

        let languages = [WakaTimeSupport.Entry(name: "Swift", seconds: 2_700), WakaTimeSupport.Entry(name: "Markdown", seconds: 900)]
        let coding = PocketStateBuilder.coding(seconds: 3_600.4, goalMinutes: 120, languages: languages)
        suite.expect(coding == PocketMacState.Coding(seconds: 3_600, goalSeconds: 7_200, topLanguage: "Swift",
                                                     topLanguagePercent: 75), "coding with its goal and top language")
        suite.expect(PocketStateBuilder.coding(seconds: 60, goalMinutes: 0, languages: [])?.goalSeconds == nil,
                     "no goal without one")
        suite.expect(PocketStateBuilder.coding(seconds: nil, goalMinutes: 60, languages: languages) == nil,
                     "no WakaTime reading, no coding")
        suite.expect(PocketStateBuilder.coding(seconds: 0, goalMinutes: 0, languages: languages)?.topLanguage == nil,
                     "nothing coded has no top language")

        let track = RadialNowPlayingSnapshot(title: " Song ", artist: "Band", album: nil, artworkData: Data([1, 2]),
                                             appBundleIdentifier: "com.apple.Music", appPID: 10)
        let playing = NotchPlayback(track: track, isPlaying: true, elapsed: 10, duration: 20, rate: 1,
                                    sampledAt: now, canSeek: false)
        let reading = PocketStateBuilder.playback(playing)
        suite.expect(reading?.title == "Song" && reading?.elapsed == 10 && reading?.duration == 20,
                     "a song is read with its position")
        suite.expect(reading.map { PocketStateBuilder.nowPlaying($0, now: now.addingTimeInterval(30)).elapsed } == 20,
                     "the position never runs past the end")
        let paused = NotchPlayback(track: track, isPlaying: false, elapsed: 10, duration: 20, rate: 0,
                                   sampledAt: now, canSeek: false)
        suite.expect(PocketStateBuilder.playback(paused).map { PocketStateBuilder.nowPlaying($0, now: now.addingTimeInterval(30)).elapsed } == 10,
                     "a paused song stays where it is")
        let stream = NotchPlayback(track: track, isPlaying: true, elapsed: 0, duration: 0, rate: 1,
                                   sampledAt: now, canSeek: false, hasPosition: false)
        suite.expect(PocketStateBuilder.playback(stream)?.elapsed == nil && PocketStateBuilder.playback(stream)?.duration == nil,
                     "a stream has no position")
        let untitled = RadialNowPlayingSnapshot(title: nil, artist: " ", album: nil, artworkData: nil,
                                                appBundleIdentifier: nil, appPID: nil)
        suite.expect(PocketStateBuilder.playback(NotchPlayback(track: untitled, isPlaying: true, elapsed: 0, duration: 0,
                                                               rate: 1, sampledAt: now, canSeek: false)) == nil,
                     "a song without a name is not sent")

        let devices = [
            BatteryDevice(id: "mac", name: "MacBook Pro", kind: .mac, source: .builtIn, percent: 90),
            BatteryDevice(id: "ios-1", name: "Faiz’s iPhone", kind: .iphone, source: .usb, percent: 50),
            BatteryDevice(id: "pocket-watch", name: "Apple Watch", kind: .watch, source: .pocket, percent: 70),
            BatteryDevice(id: "bt-1", name: "Magic Mouse", kind: .mouse, source: .bluetooth, percent: 45,
                          unreachableSince: now),
        ]
        let report = [PocketDeviceReport.Device(kind: .iphone, name: "Faiz's iPhone", percent: 51, charging: false, readAt: now)]
        let accessories = PocketStateBuilder.accessories(devices, report: report)
        suite.expect(accessories.map(\.id) == ["bt-1"], "the Mac, the phone and what the phone reported are left out")
        suite.expect(accessories.first?.kind == "mouse" && accessories.first?.seenAt == now && accessories.first?.percent == 45,
                     "an accessory keeps its kind, level and last-seen time")
        suite.expect(PocketStateBuilder.accessories(devices, report: []).map(\.id) == ["ios-1", "bt-1"],
                     "without a report the iPhone Batteries reads is an accessory")
    }

    // MARK: Cadence

    private static func cadence(_ suite: TestSuite) {
        suite.expect(PocketCadence.liveDelay(now: now, lastSent: nil) == 2, "a first change waits the debounce")
        suite.expect(PocketCadence.liveDelay(now: now, lastSent: now.addingTimeInterval(-1)) == 4,
                     "sends stay five seconds apart")
        suite.expect(PocketCadence.liveDelay(now: now, lastSent: now.addingTimeInterval(-60)) == 2,
                     "an old send leaves only the debounce")

        let base = inputs()
        let sharing = PocketSharing()
        func box(_ next: PocketMacInputs, at seconds: TimeInterval, sharingNow: PocketSharing = PocketSharing()) -> PocketCadence.BoxDecision {
            PocketCadence.box(next, sharing: sharingNow, written: base, sharingWritten: sharing,
                              writtenAt: now, now: now.addingTimeInterval(seconds))
        }
        suite.expect(PocketCadence.box(base, sharing: sharing, written: nil, sharingWritten: nil, writtenAt: nil, now: now) == .now,
                     "nothing written yet: write now")
        suite.expect(box(base, at: 600) == .none, "nothing changed: nothing written, however long")

        var coding = base
        coding.coding?.seconds += 60
        suite.expect(box(coding, at: 20) == .after(40), "coding time waits for the minute")
        suite.expect(box(coding, at: 61) == .now, "and goes once it passed")
        var moved = base
        moved.playback?.elapsed = 90
        moved.playback?.sampledAt = now
        suite.expect(box(moved, at: 5) == .after(55), "a song's position waits too")
        var smallStep = base
        smallStep.battery?.percent = 61
        suite.expect(box(smallStep, at: 5) == .after(55), "a percent within the same five waits")
        var fifth = base
        fifth.battery?.percent = 59
        suite.expect(box(fifth, at: 5) == .now, "crossing a fifth percent writes now")

        var unlocked = base
        unlocked.locked = false
        suite.expect(box(unlocked, at: 1) == .now, "the lock writes now")
        var awake = base
        awake.awakeActive = true
        suite.expect(box(awake, at: 1) == .now, "keep-awake writes now")
        var plugged = base
        plugged.battery?.charging = true
        suite.expect(box(plugged, at: 1) == .now, "a plug writes now")
        var song = base
        song.playback?.title = "Another"
        suite.expect(box(song, at: 1) == .now, "a new song writes now")
        var answered = base
        answered.sessions[0].state = .working
        suite.expect(box(answered, at: 1) == .now, "a session's change writes now")
        var picture = base
        picture.wallpaperHash = "def"
        suite.expect(box(picture, at: 1) == .now, "a new wallpaper writes now")
        var accessory = base
        accessory.accessories = []
        suite.expect(box(accessory, at: 1) == .now, "an accessory going writes now")

        let quiet = PocketSharing(wallpaper: false, agents: false, nowPlaying: false)
        suite.expect(box(base, at: 1, sharingNow: quiet) == .now, "a share switch writes now")
        suite.expect(PocketCadence.box(song, sharing: quiet, written: base, sharingWritten: quiet,
                                       writtenAt: now, now: now.addingTimeInterval(1)) == .after(59),
                     "with now playing off a new song is no news")
        suite.expect(PocketCadence.box(picture, sharing: quiet, written: base, sharingWritten: quiet,
                                       writtenAt: now, now: now.addingTimeInterval(1)) == .after(59),
                     "with the wallpaper off a new one is no news")
    }

    // MARK: Commands

    private static func commands(_ suite: TestSuite) {
        suite.expect(PocketCommands.plan(.lock, allowAnswers: false) == .lock, "lock locks")
        let now = Date()
        let devices = [PocketDeviceReport.Device(kind: .iphone, name: " paiz ", percent: 80, charging: false, readAt: now),
                       PocketDeviceReport.Device(kind: .watch, name: "Faiz’s Apple Watch", percent: 60, charging: false, readAt: now)]
        suite.expect(PocketCommands.lockedBy(.watch, devices: devices) == "Faiz’s Apple Watch", "a lock from the Watch names the Watch")
        suite.expect(PocketCommands.lockedBy(.phone, devices: devices) == "paiz", "a lock from the iPhone names the iPhone, trimmed")
        suite.expect(PocketCommands.lockedBy(.watch, devices: [devices[0]]) == "Apple Watch"
                     && PocketCommands.lockedBy(.phone, devices: []) == "iPhone", "with no report, the kind of device")
        let long = [PocketDeviceReport.Device(kind: .iphone, name: String(repeating: "a", count: 90), percent: 1, charging: false, readAt: now)]
        suite.expect(PocketCommands.lockedBy(.phone, devices: long).count == PocketCommands.maximumDeviceName, "a long name is cut")
        ZenithRemoteLockMark.mark(device: "Faiz’s Apple Watch", symbol: ZenithRemoteLockMark.watchSymbol, at: now)
        suite.expect(ZenithRemoteLockMark.symbol(for: "Faiz’s Apple Watch") == "applewatch"
                     && ZenithRemoteLockMark.symbol(for: "Someone’s iPhone") == "iphone", "the lock island draws the device that asked")
        _ = ZenithRemoteLockMark.take(at: now)
        suite.expect(PocketCommands.plan(.keepAwake(minutes: nil), allowAnswers: false) == .keepAwakeOff, "nil is off")
        suite.expect(PocketCommands.plan(.keepAwake(minutes: 0), allowAnswers: false) == .keepAwakeIndefinitely,
                     "zero is until turned off")
        suite.expect(PocketCommands.plan(.keepAwake(minutes: 30), allowAnswers: false) == .keepAwakePreset(minutes: 30),
                     "one of Keep Awake's durations is its preset")
        suite.expect(PocketCommands.plan(.keepAwake(minutes: 45), allowAnswers: false) == .keepAwakeFor(minutes: 45),
                     "another length is an end time")
        suite.expect(PocketCommands.plan(.keepAwake(minutes: 24 * 60), allowAnswers: false) == .keepAwakeFor(minutes: 1_440),
                     "a day is allowed")
        for minutes in [-5, 24 * 60 + 1, Int.max] {
            suite.expect(PocketCommands.plan(.keepAwake(minutes: minutes), allowAnswers: false)
                            == .refuse(PocketCommands.badAwakeLength), "\(minutes) minutes is refused")
        }
        suite.expect(PocketCommands.plan(.media(.playPause), allowAnswers: false) == .media(.toggle)
                        && PocketCommands.plan(.media(.next), allowAnswers: false) == .media(.next)
                        && PocketCommands.plan(.media(.previous), allowAnswers: false) == .media(.previous),
                     "media actions are the island's commands")
        suite.expect(PocketCommands.mediaKey(.toggle) == .playPause && PocketCommands.mediaKey(.next) == .nextTrack
                        && PocketCommands.mediaKey(.previous) == .previousTrack && PocketCommands.mediaKey(.seek(1)) == nil,
                     "and fall back to the media keys")
        suite.expect(PocketCommands.plan(.refresh, allowAnswers: false) == .refresh, "refresh publishes")
        let answer = PocketCommand.answer(questionID: "a@1", allow: true)
        suite.expect(PocketCommands.plan(answer, allowAnswers: false) == .refuse(PocketCommands.answersOff),
                     "answers are refused while the switch is off")
        suite.expect(PocketCommands.plan(answer, allowAnswers: true) == .refuse(PocketCommands.answersUnavailable),
                     "and while no answering path exists")
        suite.expect(PocketCommands.plan(answer, allowAnswers: true, canAnswer: true) == .answer(questionID: "a@1", allow: true),
                     "only both together answer")
        suite.expect(PocketCommands.plan(answer, allowAnswers: false, canAnswer: true) == .refuse(PocketCommands.answersOff),
                     "the switch decides first")
    }

    // MARK: Batteries

    private static func batteries(_ suite: TestSuite) {
        let report = PocketDeviceReport(devices: [
            .init(kind: .iphone, name: "  Faiz’s iPhone ", percent: 43, charging: false, readAt: now.addingTimeInterval(-60)),
            .init(kind: .iphone, name: "Second", percent: 50, charging: false, readAt: now),
            .init(kind: .watch, name: "", percent: 89, charging: true, readAt: now.addingTimeInterval(600)),
        ])
        let clean = PocketBatteries.sanitized(report, now: now)
        suite.expect(clean.count == 2 && clean[0].name == "Faiz’s iPhone", "one device per kind, names trimmed")
        suite.expect(clean[1].name == "Apple Watch" && clean[1].readAt == now, "no name, no future")
        suite.expect(PocketBatteries.sanitized(PocketDeviceReport(devices: [
            .init(kind: .iphone, name: "iPhone", percent: 101, charging: false, readAt: now),
            .init(kind: .watch, name: "Watch", percent: 50, charging: false, readAt: now.addingTimeInterval(-8 * 86_400)),
        ]), now: now).isEmpty, "levels out of range and readings past a week are dropped")
        suite.expect(PocketBatteries.readAt(clean) == now, "a report is as new as its newest reading")

        let fresh = PocketBatteries.device(clean[0], now: now)
        suite.expect(fresh.id == "pocket-iphone" && fresh.kind == .iphone && fresh.source == .pocket
                        && fresh.percent == 43 && fresh.isReachable, "a fresh reading is a live device")
        let stale = PocketBatteries.device(clean[0], now: now.addingTimeInterval(3_600))
        suite.expect(stale.unreachableSince == clean[0].readAt, "an hour later it shows as last known")
        suite.expect(PocketBatteries.device(clean[1], now: now).fullyCharged == false
                        && PocketBatteries.device(.init(kind: .watch, name: "W", percent: 100, charging: true, readAt: now),
                                                  now: now).fullyCharged, "full only at 100% on the charger")

        let scanDate = now.addingTimeInterval(-30)
        let mac = BatteryDevice(id: "mac", name: "MacBook Pro", kind: .mac, source: .builtIn, percent: 90)
        let usbPhone = BatteryDevice(id: "ios-1", name: "Faiz's iPhone", kind: .iphone, source: .usb, percent: 40)
        let alone = PocketBatteries.merged(scan: [mac], scanDate: scanDate, report: clean, now: now)
        suite.expect(alone.map(\.id) == ["mac", "pocket-iphone", "pocket-watch"], "without a match the report joins")

        let olderReport = PocketBatteries.merged(scan: [mac, usbPhone], scanDate: scanDate, report: clean, now: now)
        suite.expect(olderReport.count == 3 && olderReport[1] == usbPhone, "a scan newer than the report keeps the scan")

        let newer = [PocketDeviceReport.Device(kind: .iphone, name: "Faiz’s iPhone", percent: 38, charging: true, readAt: now)]
        let joined = PocketBatteries.merged(scan: [mac, usbPhone], scanDate: scanDate, report: newer, now: now)
        suite.expect(joined.count == 2 && joined[1].id == "ios-1" && joined[1].percent == 38 && joined[1].isCharging
                        && joined[1].source == .pocket, "a newer report fills Batteries' own entry")
        suite.expect(BatteriesMerge.deduplicated(joined).count == 2, "one iPhone after deduplicating")

        let lastKnown = BatteryDevice(id: "ios-1", name: "Faiz's iPhone", kind: .iphone, source: .wifi, percent: 60,
                                      unreachableSince: now.addingTimeInterval(-7_200))
        suite.expect(PocketBatteries.merged(scan: [lastKnown], scanDate: scanDate, report: clean, now: now)[0].percent == 43,
                     "a report beats a last-known level older than it")
        let noLevel = BatteryDevice(id: "bt-phone", name: "Faiz's iPhone", kind: .iphone, source: .bluetooth, percent: nil)
        suite.expect(PocketBatteries.merged(scan: [noLevel], scanDate: now, report: clean, now: now)[0].percent == 43,
                     "a report beats no level at all")

        let model = [PocketDeviceReport.Device(kind: .iphone, name: "iPhone 13 Pro", percent: 70, charging: false, readAt: now)]
        suite.expect(PocketBatteries.merged(scan: [mac, usbPhone], scanDate: scanDate, report: model, now: now).count == 2,
                     "a model name meets the only iPhone")
        let otherPhone = BatteryDevice(id: "ios-2", name: "Work iPhone", kind: .iphone, source: .wifi, percent: 80)
        suite.expect(PocketBatteries.merged(scan: [mac, usbPhone, otherPhone], scanDate: scanDate, report: model, now: now).count == 4,
                     "with two iPhones a model name meets neither")
        let named = [PocketDeviceReport.Device(kind: .iphone, name: "paiz", percent: 70, charging: false, readAt: now)]
        suite.expect(PocketBatteries.merged(scan: [usbPhone], scanDate: scanDate, report: named, now: now).count == 1,
                     "a name chosen in Pocket still meets the only iPhone")
        suite.expect(PocketBatteries.merged(scan: [usbPhone, otherPhone], scanDate: scanDate, report: named, now: now).count == 3,
                     "with two iPhones another name meets neither")
        let devices = [usbPhone, BatteryDevice(id: "w", name: "Apple Watch", kind: .watch, source: .viaIPhone, percent: 50)]
        suite.expect(PocketStateBuilder.accessories(devices, report: named).map(\.id) == ["w"],
                     "the phone isn't shown again among the Mac's accessories")
        let watch = BatteryDevice(id: "watch-1", name: "Apple Watch", kind: .watch, source: .viaIPhone, percent: 60)
        let watchReport = [PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 61, charging: false, readAt: now)]
        let watches = PocketBatteries.merged(scan: [watch], scanDate: scanDate, report: watchReport, now: now)
        suite.expect(watches.count == 1 && watches[0].id == "watch-1" && watches[0].percent == 61, "the Watch meets itself too")
        suite.expect(PocketBatteries.isPocketID("pocket-iphone") && !PocketBatteries.isPocketID("ios-1"), "Pocket's own ids")
    }

    // MARK: Pairing

    private static func phases(_ suite: TestSuite) {
        let pairing = PocketPairing.make(relay: relay, macName: "Mac")
        suite.expect(PocketPhaseRules.phase(enabled: false, relay: relay, pairing: pairing, lastSeen: now) == .off,
                     "off is off, paired or not")
        suite.expect(PocketPhaseRules.phase(enabled: true, relay: nil, pairing: nil, lastSeen: nil) == .off, "no relay is off")
        suite.expect(PocketPhaseRules.phase(enabled: true, relay: relay, pairing: nil, lastSeen: nil) == .unpaired,
                     "a relay without a pairing is unpaired")
        suite.expect(PocketPhaseRules.phase(enabled: true, relay: relay, pairing: pairing, lastSeen: nil) == .pairing(pairing),
                     "a pairing the phone never answered shows its code")
        suite.expect(PocketPhaseRules.phase(enabled: true, relay: relay, pairing: pairing, lastSeen: now) == .paired(lastSeen: now),
                     "the phone's first message pairs")
        suite.expect(PocketPhaseRules.publishesSeen(now, after: nil), "the first message is always news")
        suite.expect(!PocketPhaseRules.publishesSeen(now.addingTimeInterval(10), after: now)
                        && PocketPhaseRules.publishesSeen(now.addingTimeInterval(30), after: now),
                     "later ones at thirty seconds apart")
        suite.expect(!PocketPhaseRules.publishesSeen(now.addingTimeInterval(-600), after: now),
                     "an older box never moves last seen back")
        let other = PocketRelayConfig(url: URL(string: "https://other.supabase.co")!, anonKey: "a.b.c")
        suite.expect(PocketPhaseRules.forgetsPairing(saving: other, over: relay)
                        && PocketPhaseRules.forgetsPairing(saving: nil, over: relay)
                        && !PocketPhaseRules.forgetsPairing(saving: relay, over: relay),
                     "only another relay (or none) forgets the pairing")
        suite.expect(!PocketPhaseRules.relayProblem(status: 404).isEmpty
                        && PocketPhaseRules.relayProblem(status: 404) != PocketPhaseRules.relayProblem(status: 0),
                     "a refusal and no answer read differently")
    }

    private static func preferences(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.pocket"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "test defaults")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        suite.expect(PocketSharing.current(in: defaults) == PocketSharing(), "everything is shared by default")
        PocketDefaults.register(in: defaults)
        suite.expect(!defaults.bool(forKey: PocketDefaults.enabled) && !defaults.bool(forKey: PocketDefaults.allowAnswers),
                     "Pocket and answering start off")
        defaults.set(false, forKey: PocketDefaults.shareAgents)
        suite.expect(PocketSharing.current(in: defaults) == PocketSharing(wallpaper: true, agents: false, nowPlaying: true),
                     "a switch turned off is read")

        suite.expect(PocketWallpaperSupport.hash(Data("abc".utf8))
                        == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "the wallpaper hash is SHA-256")
        suite.expect(PocketWallpaperSupport.key(path: "/a.heic", modified: now)
                        != PocketWallpaperSupport.key(path: "/a.heic", modified: now.addingTimeInterval(1)),
                     "a picture changed in place is read again")
    }
}
