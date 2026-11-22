// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the padlock island on the lock screen: its right slot, the
// greetings' names, durations and text, its sizes and window, and its switches.
enum LockIslandTests {
    static func run(_ suite: TestSuite) {
        slot(suite)
        names(suite)
        durations(suite)
        strings(suite)
        sizes(suite)
        switches(suite)
        opening(suite)
    }

    /// Zenith fork: as the Mac locks, the island's first frame is already its
    /// greeting, growing out of the desktop island; the resting padlock and
    /// bars are never drawn first.
    private static func opening(_ suite: TestSuite) {
        typealias I = ZenithLockIsland
        suite.expect(I.openingMoment(locking: true, farewell: true, remoteDevice: nil) == .farewell,
                     "locking with the farewell on, the first moment shown is the farewell, not the padlock at rest")
        suite.expect(I.openingMoment(locking: true, farewell: false, remoteDevice: nil) == .rest,
                     "with the farewell off it opens at rest")
        suite.expect(I.openingMoment(locking: true, farewell: true, remoteDevice: "Faiz’s iPhone")
                        == .remoteLock(device: "Faiz’s iPhone")
                        && I.openingMoment(locking: true, farewell: false, remoteDevice: "Faiz’s iPhone")
                        == .remoteLock(device: "Faiz’s iPhone"),
                     "locked from an iPhone, the first moment shown says so, farewell or not")
        suite.expect(I.openingMoment(locking: false, farewell: true, remoteDevice: "Faiz’s iPhone") == .rest,
                     "back from a dark display nobody locked it just now: it opens at rest")
        suite.expect(I.openingHold(.farewell) == I.farewellHold && I.openingHold(.remoteLock(device: "a")) == I.remoteHold
                        && I.openingHold(.rest) == nil,
                     "the greeting holds for its time, then the island draws back into the pill")
        suite.expect(I.padlockHold(.farewell) == I.farewellHold && I.padlockHold(.rest) < I.farewellHold
                        && I.padlockHold(.remoteLock(device: "a")) < I.farewellHold,
                     "the padlock stays open while the farewell waves, and closes at once otherwise")
        // The entrance runs from the desktop island's shape into the greeting, never through the resting pill.
        let camera = CGSize(width: 185, height: 32)
        let desktop = CGSize(width: 285, height: 32)
        let farewell = I.size(camera: camera, wing: 120)
        let floor = NotchMotionFloor.floor(camera: camera, target: farewell, closedHeight: camera.height)
        let entrance = NotchMotionTimeline(from: desktop, to: farewell, begin: 0, floor: floor)
        let frames = stride(from: 0.0, through: 1.2, by: 1.0 / 120).map { entrance.shape(at: $0) }
        suite.expect(frames.first == desktop && abs((frames.last?.width ?? 0) - farewell.width) < 0.5
                        && frames.allSatisfy { $0.width >= desktop.width - 0.5 && $0.height >= camera.height - 0.5 },
                     "the farewell grows from the desktop island's own frame, never smaller than it or the camera")
    }

    private static func slot(_ suite: TestSuite) {
        typealias I = ZenithLockIsland
        suite.expect(I.slot(playing: false, charging: true, percent: 80, recentlyPlugged: true, focus: "Work")
                     == .charging(percent: 80),
                     "a charger just plugged in wins over a Focus for its first seconds")
        suite.expect(I.slot(playing: false, charging: true, percent: 80, recentlyPlugged: false, focus: "Work")
                     == .focus(name: "Work"),
                     "after that the Focus wins")
        suite.expect(I.slot(playing: false, charging: true, percent: nil, recentlyPlugged: false, focus: nil)
                     == .charging(percent: nil),
                     "the charge shows while the charger stays connected")
        suite.expect(I.slot(playing: true, charging: true, percent: 50, recentlyPlugged: false, focus: "Work") == .music
                     && I.slot(playing: true, charging: true, percent: 50, recentlyPlugged: true, focus: nil) == .charging(percent: 50),
                     "a song keeps its bars, except over a charger just plugged in")
        suite.expect(I.slot(playing: false, charging: false, percent: 50, recentlyPlugged: false, focus: "") == .none,
                     "nothing to show leaves the slot empty")
        suite.expect(I.chargeLead == 5 && I.chargingHex == 0x34D399 && I.focusHex == 0xA78BFA,
                     "charging is green for five seconds' lead; Focus is violet")
    }

    private static func names(_ suite: TestSuite) {
        suite.expect(ZenithLockIsland.firstName(fullName: "Faiz Rahman", userName: "faiz") == "Faiz", "the first word of the full name")
        suite.expect(ZenithLockIsland.firstName(fullName: "  ", userName: "faiz") == "faiz", "else the short user name")
        let text = ZenithStrings.lockIsland(.enUS)
        suite.expect(text.seeYou("Faiz") == "See you, Faiz 👋" && text.welcomeBack("Faiz") == "Welcome back, Faiz",
                     "the greetings name the person")
        suite.expect(text.seeYou("") == "See you 👋" && text.welcomeBack("") == "Welcome back",
                     "without a name the greetings still read")
    }

    private static func durations(_ suite: TestSuite) {
        let locale = Locale(identifier: "en_US")
        let long = ZenithLockIsland.duration(2 * 3_600 + 14 * 60 + 20, locale: locale)
        suite.expect(long.contains("2") && long.contains("14") && !long.contains("20"),
                     "hours and minutes, without seconds: \(long)")
        let short = ZenithLockIsland.duration(20, locale: locale)
        suite.expect(short.contains("20"), "under a minute counts seconds: \(short)")
        suite.expect(!ZenithLockIsland.duration(-5, locale: locale).isEmpty && !ZenithLockIsland.duration(.nan, locale: locale).isEmpty,
                     "a clock that moved back still reads")
        let text = ZenithStrings.lockIsland(.enUS)
        suite.expect(text.detail(duration: "2h 14m", notifications: nil) == "Locked for 2h 14m"
                     && text.detail(duration: "2h 14m", notifications: 0) == "Locked for 2h 14m"
                     && text.detail(duration: "2h 14m", notifications: 3) == "Locked for 2h 14m · notifications: 3",
                     "the count joins the duration only when there is one")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.lockIsland(language)
            let all = [text.section, text.sectionCaption, text.charging, text.chargingCaption, text.focus, text.focusCaption,
                       text.farewell, text.farewellCaption, text.welcome, text.welcomeCaption, text.seeYou, text.seeYouNameless,
                       text.welcomeBack, text.welcomeBackNameless, text.lockedFor, text.notifications]
            suite.expect(all.allSatisfy { !$0.isEmpty }, "\(language): every island text is written")
            suite.expect(text.seeYou.contains("{name}") && text.welcomeBack.contains("{name}")
                         && !text.seeYouNameless.contains("{") && !text.welcomeBackNameless.contains("{")
                         && text.lockedFor.contains("{duration}") && text.notifications.contains("{count}"),
                         "\(language): the greetings keep their placeholders")
            suite.expect(text.seeYou.contains("👋") && text.seeYouNameless.contains("👋"), "\(language): the farewell waves")
        }
    }

    private static func sizes(_ suite: TestSuite) {
        let camera = CGSize(width: 185, height: 32)
        let rest = ZenithLockIsland.size(camera: camera, wing: 40)
        suite.expect(rest == CGSize(width: 265, height: 32), "at rest the camera sits between two equal wings")
        suite.expect(ZenithLockIsland.wing(for: 0, resting: 40) == 40
                     && ZenithLockIsland.wing(for: 100, resting: 40) == 124
                     && ZenithLockIsland.wing(for: 900, resting: 40) == ZenithLockIsland.maximumWing,
                     "a wing grows for its content, up to its widest")
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let surface = CGRect(x: 1512 / 2 - 132.5, y: 982 - 32, width: 265, height: 32)
        let window = ZenithLockIsland.windowFrame(around: surface, in: screen)
        let widest = ZenithLockIsland.size(camera: camera, wing: ZenithLockIsland.maximumWing)
        // The farewell's swing and squash fit inside the window, which stays on the screen.
        let floor = NotchMotionFloor.floor(camera: CGSize(width: camera.width, height: rest.height), target: rest,
                                           closedHeight: rest.height)
        let farewell = NotchMotion.frames(from: rest, to: widest)
        let back = NotchMotion.frames(from: widest, to: rest, floor: floor)
        suite.expect(back.sizes.allSatisfy { $0.width >= rest.width - 0.001 && $0.height >= rest.height - 0.001 },
                     "back at rest after the farewell, the island settles from above, never inside the camera")
        let reach = (farewell.sizes + back.sizes).reduce(CGSize.zero) {
            CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height))
        }
        suite.expect(window.width >= reach.width && window.height >= reach.height && screen.contains(window)
                     && window.maxY == screen.maxY && abs(window.midX - surface.midX) <= 0.5,
                     "the island's window holds every frame of its farewell, centred on the camera")
        suite.expect(ZenithLockIsland.padlockSize == 17, "the padlock is about 17 points")
    }

    private static func switches(_ suite: TestSuite) {
        let defaults = UserDefaults(suiteName: "com.vorssaint.tests.lock-island")!
        defaults.removePersistentDomain(forName: "com.vorssaint.tests.lock-island")
        let options: [ZenithLockScreenOption] = [.islandCharging, .islandFocus, .islandFarewell, .islandWelcome]
        suite.expect(options.allSatisfy { $0.isOnByDefault && $0.isOn(in: defaults) && !$0.isFullLayer },
                     "each of the island's switches starts on")
        suite.expect(Set(options.map(\.defaultsKey)).count == options.count
                     && options.allSatisfy { Defaults.registeredDefaults[$0.defaultsKey] as? Bool == true },
                     "each has its own registered key")
        defaults.set(false, forKey: ZenithLockScreenOption.islandWelcome.defaultsKey)
        suite.expect(!ZenithLockScreenOption.islandWelcome.isOn(in: defaults) && ZenithLockScreenOption.islandFarewell.isOn(in: defaults),
                     "each turns off on its own")
        defaults.removePersistentDomain(forName: "com.vorssaint.tests.lock-island")
    }
}
