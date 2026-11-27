// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: the island asks whether WakaTime is set up many times per
/// update; the answer is remembered, and forgotten when it may have changed.
enum WakaTimeConfigPresenceTests {
    static func run(_ suite: TestSuite) {
        shared(suite)
        remembers(suite)
        watchesFolder(suite)
    }

    private static func shared(_ suite: TestSuite) {
        let presence = WakaTimeConfigPresence.shared
        suite.expect(presence.url == WakaTimeSupport.configURL(), "the shared cache asks about the usual config file")
        suite.expect(WakaTimeSupport.hasConfiguration() == WakaTimeSupport.hasConfiguration(at: presence.url),
                     "the remembered answer matches the disk")
    }

    private static func remembers(_ suite: TestSuite) {
        var checks = 0
        var present = false
        let url = URL(fileURLWithPath: "/nonexistent/zenith-tests/.wakatime.cfg")
        let presence = WakaTimeConfigPresence(url: url, watchesFolder: false) { path in
            checks += 1
            return path == url.path && present
        }
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        suite.expect(!presence.isPresent(now: start) && checks == 1, "the first question asks the disk")
        present = true
        for second in 0..<100 { _ = presence.isPresent(now: start + Double(second) * 0.2) }
        suite.expect(checks == 1 && !presence.isPresent(now: start + 29),
                     "a hundred island updates within the lifetime ask the disk once")
        suite.expect(presence.isPresent(now: start + 30) && checks == 2, "after the lifetime it asks again")
        present = false
        presence.invalidate()
        suite.expect(!presence.isPresent(now: start + 31) && checks == 3, "an invalidation asks again at once")
        suite.expect(!presence.isPresent(now: start - 5) && checks == 4, "a clock set back asks again")
        present = true
        suite.expect(NSApplication.didBecomeActiveNotification.rawValue == "NSApplicationDidBecomeActiveNotification",
                     "the cache listens for the app becoming active")
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        suite.expect(presence.isPresent(now: start - 4) && checks == 5, "the app becoming active asks again")
    }

    private static func watchesFolder(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-wakatime-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent(".wakatime.cfg")
        // A long lifetime, so only the watcher can change the answer here.
        let presence = WakaTimeConfigPresence(url: file, lifetime: 3600)
        suite.expect(presence.isWatchingFolder && !presence.isPresent(), "a missing config reads as missing")
        func settles(on expected: Bool) -> Bool {
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline {
                if presence.isPresent() == expected { return true }
                Thread.sleep(forTimeInterval: 0.02)
            }
            return false
        }
        FileManager.default.createFile(atPath: file.path, contents: Data("[settings]\napi_key = k\n".utf8))
        suite.expect(settles(on: true), "adding the config is noticed without waiting out the lifetime")
        try? FileManager.default.removeItem(at: file)
        suite.expect(settles(on: false), "and so is removing it")
        let unwatched = WakaTimeConfigPresence(url: folder.appendingPathComponent("missing/.wakatime.cfg"))
        suite.expect(!unwatched.isWatchingFolder && unwatched.lifetime == 30,
                     "a folder that is not there yet falls back to asking every 30 seconds")
    }
}
