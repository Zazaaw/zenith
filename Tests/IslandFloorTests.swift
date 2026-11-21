// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreGraphics
import Foundation

// Zenith fork: the island never shows narrower or shorter than the camera
// cutout it covers, at any frame of any transition; closing onto the strip
// settles from above; bursts never stack over an open page; and the Claude
// chime comes with the island, rate-limited, or not at all.
enum IslandFloorTests {
    static func run(_ suite: TestSuite) {
        floorFunction(suite)
        everyTransition(suite)
        landing(suite)
        interruptions(suite)
        bursts(suite)
        chime(suite)
    }

    /// A 14-inch MacBook Pro's camera: about 205 by 37 points.
    private static let geometry: NotchGeometry = {
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1800, height: 1169), safeAreaTop: 37,
                                     cameraWidth: 205, layout: .spacious)
        geometry.compactSideRoom = 280
        return geometry
    }()

    private static var camera: CGSize { geometry.restingSize(showsContent: false) }

    private static func floorFunction(_ suite: TestSuite) {
        let open = geometry.expanded
        suite.expect(NotchMotionFloor.floor(for: open, geometry: geometry) == camera,
                     "an open island keeps above the bare camera")
        let strip = CGSize(width: camera.width + 160, height: camera.height)
        suite.expect(NotchMotionFloor.floor(for: strip, geometry: geometry) == strip,
                     "closing onto a strip keeps above that strip")
        let hidden = CGSize(width: geometry.collapsed.width, height: 0)
        let hiding = NotchMotionFloor.floor(for: hidden, geometry: geometry)
        suite.expect(hiding.height == camera.height && hiding.width >= camera.width
                     && ZenithIslandMotion.bottom(floor: hiding.height, from: open.height, to: 0) == 0,
                     "a hiding island may go behind the camera, which covers it")
        var capsule = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0, cameraWidth: 0,
                                    layout: .spacious, menuBarHeight: 24, silhouette: .capsule, barEdge: 0.5)
        capsule.compactSideRoom = 280
        suite.expect(NotchMotionFloor.floor(for: capsule.expanded, geometry: capsule) == .zero,
                     "a floating capsule has no cutout to bare")
        suite.expect(camera.width > 0 && camera.height > 0 && abs(camera.width - 205) < 1,
                     "the floor is the camera's own size: \(camera)")
    }

    /// Every pair of the island's sizes: closed, strips, notices, a peek, a
    /// burst, open pages of two sizes, and hidden.
    private static func everyTransition(_ suite: TestSuite) {
        let strip = CGSize(width: camera.width + 160, height: camera.height)
        let notice = CGSize(width: camera.width + 120, height: camera.height)
        let peek = geometry.peek
        let burst = CGSize(width: 440, height: camera.height + 70)
        let open = geometry.expanded
        let shortPage = CGSize(width: open.width, height: max(camera.height + 90, open.height * 0.6))
        let narrowPage = CGSize(width: max(camera.width + 200, open.width * 0.7), height: open.height)
        let hidden = CGSize(width: geometry.collapsed.width, height: 0)
        let sizes = [camera, strip, notice, peek, burst, open, shortPage, narrowPage, hidden]
        var checked = 0
        for from in sizes {
            for to in sizes where from != to {
                let floor = NotchMotionFloor.floor(for: to, geometry: geometry)
                let motion = NotchMotion.frames(from: from, to: to, floor: floor)
                let least = CGSize(width: ZenithIslandMotion.bottom(floor: floor.width, from: from.width, to: to.width),
                                   height: ZenithIslandMotion.bottom(floor: floor.height, from: from.height, to: to.height))
                let fine = stride(from: 0.0, through: motion.duration, by: 1.0 / 480).allSatisfy {
                    let shape = NotchMotion.shape(at: $0, from: from, to: to, floor: floor)
                    return shape.width >= least.width - 0.001 && shape.height >= least.height - 0.001
                }
                checked += 1
                suite.expect(fine && motion.sizes.allSatisfy { $0.width >= least.width - 0.001 && $0.height >= least.height - 0.001 },
                             "no frame from \(from) to \(to) shows inside the camera cutout")
                // Every frame of a visible island covers the camera.
                if from.height > 0 && to.height > 0 {
                    suite.expect(motion.sizes.allSatisfy { $0.width >= camera.width - 0.001 && $0.height >= camera.height - 0.001 },
                                 "the camera stays covered from \(from) to \(to)")
                }
                suite.expect(motion.sizes.last == to, "the motion still ends exactly at \(to)")
            }
        }
        suite.expect(checked == sizes.count * (sizes.count - 1), "every transition between the island's sizes is checked")
    }

    private static func landing(_ suite: TestSuite) {
        let open = geometry.expanded
        for target in [camera, CGSize(width: camera.width + 160, height: camera.height)] {
            let floor = NotchMotionFloor.floor(for: target, geometry: geometry)
            let frames = stride(from: 0.0, through: 1.6, by: 1.0 / 480).map { NotchMotion.shape(at: $0, from: open, to: target, floor: floor) }
            suite.expect(frames.allSatisfy { $0.width >= target.width - 0.001 && $0.height >= target.height - 0.001 },
                         "closing onto \(target) settles from above with no undershoot")
            // The softer landing still rebounds a little outward once it touches down.
            let touched = frames.firstIndex { $0.height - target.height < 0.5 } ?? frames.count
            let rebound = frames[min(touched, frames.count)...].map { $0.height - target.height }.max() ?? 0
            suite.expect(rebound > 0.05 && rebound < (open.height - target.height) * 0.04,
                         "the landing rebounds outward a touch: \(rebound) pt")
        }
        // Between two open sizes the island may swing past its target, but
        // never into the camera.
        let shortPage = CGSize(width: open.width, height: camera.height + 90)
        let floor = NotchMotionFloor.floor(for: shortPage, geometry: geometry)
        let shrink = NotchMotion.frames(from: open, to: shortPage, floor: floor)
        suite.expect((shrink.sizes.map(\.height).min() ?? 0) < shortPage.height
                     && shrink.sizes.allSatisfy { $0.height >= camera.height - 0.001 },
                     "a smaller open page may undershoot, only above the camera")
        suite.expect(ZenithIslandMotion.landingWidth.bounce < ZenithIslandMotion.shrinkingWidth.bounce
                     && ZenithIslandMotion.landingHeight.bounce < ZenithIslandMotion.shrinkingHeight.bounce,
                     "the landing is softer than an open island's shrink")
        // Its speed is still the derivative of its place, reflected or not.
        let step = 1e-5
        let speeds = stride(from: 0.05, through: 0.9, by: 0.05).allSatisfy { time in
            let before = NotchMotion.size(at: time - step, from: open, to: camera, floor: camera)
            let after = NotchMotion.size(at: time + step, from: open, to: camera, floor: camera)
            let speed = NotchMotion.velocity(at: time, from: open, to: camera, floor: camera)
            return abs((after.height - before.height) / (2 * step) - speed.height) < 0.5
        }
        suite.expect(speeds, "a landing's speed matches its motion")
        // Closing eases in over its first 80 ms, then lands softly; opening
        // still leaves at once and swings past its size.
        let closingSpeeds = stride(from: 0.0, through: 1.0, by: 1.0 / 480).map {
            abs(NotchMotion.velocity(at: $0, from: open, to: camera, floor: camera).height)
        }
        let peak = closingSpeeds.max() ?? 1
        let early = abs(NotchMotion.velocity(at: 0.02, from: open, to: camera, floor: camera).height)
        let unhurried = abs(NotchMotion.size(at: 0.04, from: open, to: camera, floor: camera).height - open.height)
        suite.expect(early < peak * 0.2 && unhurried < (open.height - camera.height) * 0.06,
                     "closing gathers speed gently instead of starting at full speed: \(early) of \(peak) pt/s")
        let rising = zip(closingSpeeds.prefix(30), closingSpeeds.prefix(30).dropFirst()).allSatisfy { $1 >= $0 - 0.001 }
        suite.expect(rising, "its first frames only speed up")
        let warp = ZenithIslandMotion.warp
        suite.expect(warp(0.04, 0.08).rate == 0.5 && warp(0.08, 0.08).time == 0.04 && warp(0.2, 0.08).time == 0.16
                     && warp(0.2, 0.08).rate == 1 && warp(0.1, 0).time == 0.1,
                     "the ease-in's clock runs slowly, then with the clock, a constant 40 ms behind")
        let opening = stride(from: 0.0, through: 1.2, by: 1.0 / 480).map {
            NotchMotion.shape(at: $0, from: camera, to: open, floor: NotchMotionFloor.floor(for: open, geometry: geometry))
        }
        suite.expect((opening.map(\.height).max() ?? 0) > open.height + 8
                     && NotchMotion.velocity(at: 0.04, from: camera, to: open).width > peak * 0.5,
                     "opening keeps the bouncy overshoot and sets off at once")
    }

    private static func interruptions(_ suite: TestSuite) {
        let open = geometry.expanded
        let floor = NotchMotionFloor.floor(for: open, geometry: geometry)
        let opening = NotchMotionTimeline(from: camera, to: open, begin: 0, floor: floor)
        for retarget in [0.05, 0.12, 0.25, 0.4] {
            let closingFloor = NotchMotionFloor.floor(for: camera, geometry: geometry)
            guard let closing = opening.continued(to: camera, at: retarget, floor: closingFloor) else {
                suite.expect(false, "an opening turned back carries on")
                continue
            }
            let fine = stride(from: retarget, through: retarget + 2, by: 1.0 / 240).allSatisfy {
                let shape = closing.shape(at: $0)
                return shape.width >= camera.width - 0.001 && shape.height >= camera.height - 0.001
            }
            suite.expect(fine && closing.floor == closingFloor && closing.frames().sizes.last == camera,
                         "an opening turned back at \(retarget) s closes without baring the camera")
        }
        let strip = CGSize(width: camera.width + 160, height: camera.height)
        let wide = NotchMotionTimeline(from: open, to: strip, begin: 0, floor: NotchMotionFloor.floor(for: strip, geometry: geometry))
        suite.expect(stride(from: 0.0, through: 2, by: 1.0 / 240).allSatisfy {
                         let shape = wide.shape(at: $0)
                         return shape.width >= strip.width - 0.001 && shape.height >= strip.height - 0.001
                     },
                     "a running close onto a strip keeps above it")
    }

    private static func bursts(_ suite: TestSuite) {
        let now = Date()
        let welcome = ZenithIslandBurst(.welcome(ZenithWelcomeBurst(title: "Welcome back, Faiz", subtitle: "Locked for 2h 14m",
                                                                   photo: nil, initials: "FH")), start: now)
        let agent = ZenithIslandBurst(.agent(ZenithAgentBurst(provider: .claude, title: "Claude needs you", subtitle: "zenith")),
                                      start: now)
        suite.expect(welcome.duration == 3 && agent.duration == ZenithIslandBurstTiming.agent && agent.module == .agents
                     && welcome.module == nil && welcome.title == "Welcome back, Faiz" && agent.subtitle == "zenith",
                     "a welcome stays about 3 s; Claude's burst opens the AI page")
        suite.expect(ZenithIslandBurstTiming.patience(welcome.content) == 5 && ZenithIslandBurstTiming.patience(agent.content) == 5
                     && ZenithIslandBurstTiming.patience(.charge(.make(.charging, percent: 50, minutes: nil,
                                                                       island: ZenithStrings.island(.enUS),
                                                                       notices: ZenithStrings.notices(.enUS),
                                                                       locale: Locale(identifier: "en_US")))) == 0,
                     "an open island makes a greeting wait at most 5 s, then it is dropped")
        let size = ZenithIslandBurstLayout.size(welcome, geometry: geometry)
        suite.expect(size.width >= 360 && size.height > camera.height && size.width <= geometry.screen.width,
                     "the welcome grows the island itself below the camera: \(size)")
        let prayer = ZenithIslandBurst(.prayer(ZenithPrayerBurst(symbol: "sun.max", title: "Waktunya Ashar", subtitle: "15.04",
                                                                 nextLabel: "Next", next: nil)), start: now)
        suite.expect(!ZenithIslandBurstTiming.replaces(prayer, with: welcome, at: now)
                     && ZenithIslandBurstTiming.replaces(agent, with: welcome, at: now),
                     "a prayer's time is not cut short by a greeting")
    }

    private static func chime(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.claude-chime"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(ClaudeHooksSupport.chime(in: defaults) == .soundAndIsland
                     && Defaults.registeredDefaults[DefaultsKey.notchAgentsClaudeChime] as? String == "soundAndIsland",
                     "by default the chime comes with the island")
        defaults.set(false, forKey: DefaultsKey.notchAgentsClaudeSound)
        suite.expect(ClaudeHooksSupport.chime(in: defaults) == .off && !ClaudeHooksSupport.playsSound(in: defaults),
                     "the old sound switch, off, is still off")
        ClaudeHooksSupport.setChime(.soundAndIsland, in: defaults)
        suite.expect(ClaudeHooksSupport.chime(in: defaults) == .soundAndIsland
                     && defaults.object(forKey: DefaultsKey.notchAgentsClaudeSound) as? Bool != false,
                     "choosing again leaves the old switch behind")
        ClaudeHooksSupport.setChime(.off, in: defaults)
        suite.expect(ClaudeHooksSupport.chime(in: defaults) == .off, "off stays off")

        var limiter = ClaudeChimeLimiter()
        let start = Date(timeIntervalSince1970: 1_000_000)
        suite.expect(limiter.allows(session: "a", at: start), "the first session waiting chimes")
        suite.expect(!limiter.allows(session: "b", at: start.addingTimeInterval(10)),
                     "another session within 30 s keeps quiet")
        suite.expect(limiter.allows(session: "b", at: start.addingTimeInterval(31)), "after 30 s another session may chime")
        suite.expect(!limiter.allows(session: "a", at: start.addingTimeInterval(120)),
                     "the same session within 3 minutes keeps quiet")
        suite.expect(limiter.allows(session: "a", at: start.addingTimeInterval(181)), "after 3 minutes it may chime again")
        // Many sessions sitting idle at once still chime only every 30 s.
        var busy = ClaudeChimeLimiter()
        let chimes = (0..<600).filter { busy.allows(session: "s\($0 % 12)", at: start.addingTimeInterval(Double($0))) }.count
        suite.expect(chimes <= 600 / 30 + 1, "a dozen idle sessions over 10 minutes chime at most \(chimes) times")

        for language in AppLanguage.allCases {
            let text = ZenithStrings.claudeChime(language)
            suite.expect([text.alert, text.alertCaption, text.off, text.soundAndIsland, text.needsYou].allSatisfy { !$0.isEmpty }
                         && text.needsYou.contains("Claude"),
                         "\(language): the chime's text is written")
        }
    }
}
