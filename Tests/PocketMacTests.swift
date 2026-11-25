// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Zenith Pocket's Mac tab on the Mac side, on fixed inputs:
/// what each command asks for and why one is refused, which process the
/// phone may quit, how a dropped file is named and kept from replacing
/// another, how the health readings are rounded, the sound outputs' kinds,
/// the tools' next event and clips, and when sampling runs. Nothing here
/// changes the volume, mutes, quits, opens a link, touches the clipboard or
/// writes to Downloads.
enum PocketMacTests {
    static func run(_ suite: TestSuite) {
        suite.run("pocket-mac-commands") { commands(suite) }
        suite.run("pocket-mac-quit") { quit(suite) }
        suite.run("pocket-mac-drops") { drops(suite) }
        suite.run("pocket-mac-health") { health(suite) }
        suite.run("pocket-mac-sound-tools") { soundAndTools(suite) }
        suite.run("pocket-mac-sampling") { sampling(suite) }
    }

    private static let now = Date(timeIntervalSince1970: 1_795_000_000)

    private static func plan(_ command: PocketCommand) -> PocketMacPlan? { PocketMacCommands.plan(command) }

    // MARK: Commands

    private static func commands(_ suite: TestSuite) {
        suite.expect(plan(.setVolume(40)) == .volume(0.4), "volume as a fraction")
        suite.expect(plan(.setVolume(0)) == .volume(0) && plan(.setVolume(100)) == .volume(1), "both ends of the slider")
        suite.expect(plan(.setVolume(101)) == .refuse(PocketMacCommands.badVolume)
                        && plan(.setVolume(-1)) == .refuse(PocketMacCommands.badVolume), "a volume out of range is refused")
        suite.expect(plan(.setOutput(id: "BuiltInSpeakerDevice")) == .output("BuiltInSpeakerDevice"), "an output by its UID")
        suite.expect(plan(.setOutput(id: "")) == .refuse(PocketMacCommands.badOutput), "an empty output is refused")
        suite.expect(plan(.muteMic(true)) == .muteMic(true), "mic mute")
        suite.expect(plan(.seek(seconds: 42)) == .seek(42), "seek to a position")
        suite.expect(plan(.seek(seconds: -1)) == .refuse(PocketMacCommands.badPosition)
                        && plan(.seek(seconds: .infinity)) == .refuse(PocketMacCommands.badPosition), "no position before or past time")

        let id = UUID()
        suite.expect(plan(.openWorkspace(id: id.uuidString)) == .workspace(id), "a workspace by its id")
        suite.expect(plan(.openWorkspace(id: "work")) == .refuse(PocketMacCommands.badWorkspace), "a made-up workspace id")
        suite.expect(plan(.timer(minutes: 25, label: "Focus")) == .startTimer(minutes: 25), "a timer")
        suite.expect(plan(.timer(minutes: nil, label: nil)) == .stopTimer, "no minutes stops the timer")
        suite.expect(plan(.timer(minutes: 0, label: nil)) == .refuse(PocketMacCommands.badTimer)
                        && plan(.timer(minutes: 181, label: nil)) == .refuse(PocketMacCommands.badTimer), "the ruler's range only")
        suite.expect(plan(.pauseTimer(true)) == .pauseTimer(true), "pause")
        suite.expect(plan(.stopDevServer(port: 5173)) == .stopDevServer(port: 5173), "a dev server by its port")
        suite.expect(plan(.stopDevServer(port: 70_000)) == .refuse(PocketMacCommands.badPort), "no such port")
        suite.expect(plan(.quitProcess(pid: 1)) == .refuse(PocketMacCommands.badProcess)
                        && plan(.quitProcess(pid: 0)) == .refuse(PocketMacCommands.badProcess), "launchd and the kernel are never asked")
        suite.expect(plan(.quitProcess(pid: 812)) == .quit(pid: 812), "an app by its pid")

        suite.expect(plan(.sendText("hello")) == .clipboard("hello"), "text for the clipboard")
        suite.expect(plan(.sendText(" \n ")) == .refuse(PocketMacCommands.emptyText), "blank text is refused")
        let longest = String(repeating: "a", count: PocketMacCommands.maximumText)
        suite.expect(plan(.sendText(longest)) == .clipboard(longest), "20,000 characters fit")
        suite.expect(plan(.sendText(longest + "a")) == .refuse(PocketMacCommands.longText), "one more doesn't")

        suite.expect(plan(.openURL("https://satuvisual.id/zenith")) == .open(URL(string: "https://satuvisual.id/zenith")!),
                     "an https link")
        suite.expect(plan(.openURL("  http://localhost:3000 ")) == .open(URL(string: "http://localhost:3000")!), "trimmed")
        for bad in ["file:///etc/passwd", "javascript:alert(1)", "zenith-pocket://pair", "ssh://mac", "https://", "", "not a link"] {
            suite.expect(plan(.openURL(bad)) == .refuse(PocketMacCommands.badLink), "\(bad) is not opened")
        }
        suite.expect(plan(.collectDrop(slot: 3)) == .collect(slot: 3), "the last slot")
        suite.expect(plan(.collectDrop(slot: 4)) == .refuse(PocketMacCommands.badSlot)
                        && plan(.collectDrop(slot: -1)) == .refuse(PocketMacCommands.badSlot), "slots are 0 to 3")

        for other in [PocketCommand.lock, .refresh, .keepAwake(minutes: 15), .media(.next), .presence(watching: true),
                      .setAway(true), .claudeReply(sessionID: "a", text: "go")] {
            suite.expect(plan(other) == nil, "\(other) isn't the Mac tab's")
        }
    }

    // MARK: Quit

    private static func known(start: UInt64? = 7, app: Bool = true, bundle: String? = "com.figma.Desktop",
                              path: String? = "/Applications/Figma.app/Contents/MacOS/Figma",
                              protected: Bool = false) -> PocketQuitRules.Facts {
        PocketQuitRules.Facts(ownPID: 500, startedAt: start, isApp: app, bundleID: bundle, path: path,
                              protectedProcess: protected)
    }

    private static func quit(_ suite: TestSuite) {
        let shared: [Int32: PocketQuitRules.Shared] = [812: .init(name: "Figma", startedAt: 7),
                                                       500: .init(name: "Zenith", startedAt: 1)]
        func verdict(_ pid: Int32 = 812, allowed: Bool = true, facts: PocketQuitRules.Facts = known()) -> PocketQuitRules.Verdict {
            PocketQuitRules.verdict(pid: pid, allowed: allowed, shared: shared, facts: facts)
        }
        suite.expect(verdict() == .quit(name: "Figma"), "a busy app the phone was shown")
        suite.expect(verdict(allowed: false) == .refuse(PocketQuitRules.off), "off unless the person allows it")
        suite.expect(verdict(500) == .refuse(PocketQuitRules.itself), "never Zenith itself")
        suite.expect(verdict(facts: known(bundle: "id.satuvisual.zenith.developer")) == .refuse(PocketQuitRules.itself),
                     "nor the Developer build")
        suite.expect(verdict(613) == .refuse(PocketQuitRules.notListed), "only what was in the busiest list")
        suite.expect(verdict(facts: known(start: nil)) == .refuse(PocketQuitRules.gone), "an app that already quit")
        suite.expect(verdict(facts: known(start: 9)) == .refuse(PocketQuitRules.gone), "a pid reused by another process")
        suite.expect(verdict(facts: known(protected: true)) == .refuse(PocketQuitRules.system), "kernel, WindowServer and the like")
        suite.expect(verdict(facts: known(bundle: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"))
                        == .refuse(PocketQuitRules.system), "the Finder keeps running")
        suite.expect(verdict(facts: known(bundle: "com.apple.Dock", path: nil)) == .refuse(PocketQuitRules.system),
                     "bundle ids are matched without case")
        suite.expect(verdict(facts: known(bundle: nil, path: "/usr/libexec/backupd")) == .refuse(PocketQuitRules.system),
                     "a daemon under /usr")
        suite.expect(verdict(facts: known(bundle: "com.apple.Music", path: "/System/Applications/Music.app/Contents/MacOS/Music"))
                        == .quit(name: "Figma"), "macOS's own apps for people may quit")
        suite.expect(verdict(facts: known(app: false, bundle: nil, path: "/opt/homebrew/bin/node")) == .refuse(PocketQuitRules.notApp),
                     "a process without a window isn't the phone's to stop")
        suite.expect(PocketQuitRules.asked("Figma") == "Asked Figma to quit.", "the answer names the app")
    }

    // MARK: Drops

    private static func drops(_ suite: TestSuite) {
        func name(_ raw: String, _ kind: PocketDrop.Kind = .file) -> String {
            PocketDropRules.sanitizedName(raw, kind: kind, now: now)
        }
        suite.expect(name("IMG_5561.jpeg", .photo) == "IMG_5561.jpeg", "a plain name stays")
        suite.expect(name("../../.ssh/authorized_keys") == "ssh-authorized_keys", "no way out of the folder")
        suite.expect(name(".zshrc") == "zshrc", "never a hidden file")
        suite.expect(name("a/b:c\\d.txt") == "a-b-c-d.txt", "separators become dashes")
        suite.expect(name("note\u{0}\n.txt") == "note--.txt", "control characters go")
        suite.expect(name("IMG_0001", .photo) == "IMG_0001.jpg", "a photo without an extension is a JPEG")
        suite.expect(name("README") == "README", "a file without one stays without")
        suite.expect(name("", .photo).hasPrefix("Pocket photo ") && name("", .photo).hasSuffix(".jpg"), "a nameless photo")
        suite.expect(name("   ").hasPrefix("Pocket file "), "a blank name")
        let long = name(String(repeating: "x", count: 300) + ".pdf")
        suite.expect(long.count == PocketDropRules.maximumNameLength && long.hasSuffix(".pdf"), "shortened, extension kept")
        suite.expect(name("report.final version") == "report.final version", "a dot inside words isn't an extension")

        var taken: Set<String> = ["photo.jpg", "photo 2.jpg", "notes"]
        suite.expect(PocketDropRules.available("new.jpg", exists: taken.contains) == "new.jpg", "free names are used as is")
        suite.expect(PocketDropRules.available("photo.jpg", exists: taken.contains) == "photo 3.jpg", "the next free number")
        suite.expect(PocketDropRules.available("notes", exists: taken.contains) == "notes 2", "without an extension too")
        taken = Set((2...999).map { "full \($0).txt" } + ["full.txt"])
        suite.expect(PocketDropRules.available("full.txt", exists: taken.contains) == nil, "never over a file, even when all are taken")

        let photo = PocketDrop(name: "a.jpg", kind: .photo, data: Data(repeating: 1, count: 10))
        suite.expect(PocketDropRules.refusal(photo, sentAt: now.addingTimeInterval(-60), now: now) == nil, "a fresh drop")
        suite.expect(PocketDropRules.refusal(photo, sentAt: now.addingTimeInterval(-16 * 60), now: now) == PocketDropRules.stale,
                     "an old drop")
        suite.expect(PocketDropRules.refusal(PocketDrop(name: "a", kind: .file, data: Data()), sentAt: now, now: now)
                        == PocketDropRules.empty, "an empty drop")
        let big = PocketDrop(name: "a", kind: .file, data: Data(count: PocketDrop.maxBytes + 1))
        suite.expect(PocketDropRules.refusal(big, sentAt: now, now: now) == PocketDropRules.tooBig, "a drop over the limit")
        suite.expect(PocketDropRules.saved("a.jpg") == "Saved a.jpg to Downloads/Pocket.", "the answer says where")
    }

    // MARK: Health

    private static func health(_ suite: TestSuite) {
        var reading = PocketHealthRules.Reading(cpu: 0.384, temperature: 52.4, memoryUsed: 12, memoryTotal: 16,
                                                diskFree: 230_000_000_000, diskTotal: 494_000_000_000,
                                                down: 1_234_567, up: 87.6)
        let top = [PocketHealth.Process(pid: 3, name: "Xcode", cpu: 12.34), PocketHealth.Process(pid: 4, name: " Safari ", cpu: 40.06),
                   PocketHealth.Process(pid: 5, name: "idle", cpu: 0.04), PocketHealth.Process(pid: 6, name: "", cpu: 2)]
        let health = PocketHealthRules.health(reading, top: top)
        suite.expect(health?.cpuPercent == 38 && health?.temperature == 52 && health?.memoryPercent == 75, "rounded readings")
        suite.expect(health?.diskFree == 230_000_000_000 && health?.diskTotal == 494_000_000_000, "the startup disk")
        suite.expect(health?.networkDown == 1_200_000 && health?.networkUp == 88, "network to two figures")
        suite.expect(health?.top.map(\.name) == ["Safari", "Xcode", "pid 6"], "busiest first, idle ones left out, names trimmed")
        suite.expect(health?.top.first?.cpu == 40.1, "a tenth of a percent")
        reading.cpu = nil
        suite.expect(PocketHealthRules.health(reading, top: []) == nil, "nothing before the CPU is read")
        reading.cpu = 1.7
        reading.temperature = 250
        reading.memoryTotal = 0
        let odd = PocketHealthRules.health(reading, top: [])
        suite.expect(odd?.cpuPercent == 100 && odd?.temperature == nil && odd?.memoryPercent == nil, "readings out of range")
        suite.expect(PocketHealthRules.busiest((1...9).map { PocketHealth.Process(pid: Int32($0), name: "p", cpu: Double($0)) }).count == 5,
                     "five at most")
        suite.expect(PocketHealthRules.rate(.nan) == nil && PocketHealthRules.rate(-4) == 0 && PocketHealthRules.rate(9_960) == 10_000,
                     "rates stay sane")
    }

    // MARK: Sound and tools

    private static func soundAndTools(_ suite: TestSuite) {
        suite.expect(PocketSoundRules.kind(.builtIn, name: "MacBook Pro Speakers") == "speakers", "built-in speakers")
        suite.expect(PocketSoundRules.kind(.builtIn, name: "External Headphones") == "headphones", "the headphone jack")
        suite.expect(PocketSoundRules.kind(.bluetooth, name: "Faiz’s AirPods Pro") == "airpods", "AirPods")
        suite.expect(PocketSoundRules.kind(.bluetooth, name: "Soundcore Liberty 4") == "bluetooth", "other Bluetooth")
        suite.expect(PocketSoundRules.kind(.display, name: "LG UltraFine") == "display", "a display's speakers")
        suite.expect(PocketSoundRules.kind(.usb, name: "Scarlett 2i2") == "other", "an interface")
        suite.expect(PocketSoundRules.percent(0.625) == 63 && PocketSoundRules.percent(1.2) == 100
                        && PocketSoundRules.percent(.nan) == 0, "volume in whole percent")

        let events = [
            PocketToolsRules.Event(title: "Holiday", start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(80_000), allDay: true),
            PocketToolsRules.Event(title: "Standup", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), allDay: false),
            PocketToolsRules.Event(title: "Weekly sync", start: now.addingTimeInterval(1080), end: now.addingTimeInterval(4680), allDay: false),
            PocketToolsRules.Event(title: "Review", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(600), allDay: false),
            PocketToolsRules.Event(title: "Far", start: now.addingTimeInterval(90_000), end: now.addingTimeInterval(93_600), allDay: false),
        ]
        suite.expect(PocketToolsRules.nextEvent(events, now: now)?.title == "Review", "the one going on comes first")
        suite.expect(PocketToolsRules.nextEvent(Array(events.prefix(3)), now: now)?.title == "Weekly sync",
                     "all-day and finished events are skipped")
        suite.expect(PocketToolsRules.nextEvent([events[4]], now: now) == nil, "tomorrow's isn't next up")
        suite.expect(PocketToolsRules.nextChange(events, now: now) == now.addingTimeInterval(600), "wake when Review ends")

        let clips = PocketToolsRules.clips(["  first ", "", String(repeating: "b", count: 400)] + (1...20).map { "c\($0)" })
        suite.expect(clips.count == 10 && clips.first == "first", "ten clips, blank ones out")
        suite.expect(clips[1].count == 300 && clips[1].hasSuffix("…"), "a long clip is shortened")

        let text = ZenithStrings.pocketMac(.enUS)
        suite.expect(text.all.count == 4 && text.all.allSatisfy { !$0.isEmpty }, "every switch has text")
        suite.expect(AppLanguage.allCases.allSatisfy { ZenithStrings.pocketMac($0).allowQuit == text.allowQuit },
                     "English in every language")
    }

    // MARK: Sampling

    private static func sampling(_ suite: TestSuite) {
        var gate = PocketSampling()
        suite.expect(gate.setWatching(true) == .none && !gate.running, "a phone watching without a link samples nothing")
        suite.expect(gate.setLink(true) == .start && gate.running, "the link comes up while it watches")
        suite.expect(gate.setWatching(true) == .none, "presence repeats without restarting")
        suite.expect(gate.setWatching(false) == .stop && !gate.running, "the phone went away")
        suite.expect(gate.setWatching(true) == .start, "and came back")
        suite.expect(gate.setLink(false) == .stop, "the link went down")
        suite.expect(gate.setLink(true) == .none && !gate.running, "a new link waits for the phone to say it watches")

        suite.expect(PocketMacCadence.health >= 3 && PocketMacCadence.health <= 5
                        && PocketMacCadence.sound >= 3 && PocketMacCadence.sound <= 5, "a modest pace, 3 to 5 s")
        suite.expect(PocketMacCadence.health * Double(PocketMacCadence.topEvery) >= 8, "the process walk is rarer still")

        let name = "com.vorssaint.tests.pocket-mac"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "test defaults")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        PocketDefaults.register(in: defaults)
        suite.expect(!defaults.bool(forKey: PocketDefaults.shareClipboard) && !defaults.bool(forKey: PocketDefaults.allowQuit),
                     "the clipboard and quitting start off")
        suite.expect(PocketDefaults.shareClipboard.hasPrefix("zenithPocket") && PocketDefaults.allowQuit.hasPrefix("zenithPocket"),
                     "Pocket's own keys")
    }
}
