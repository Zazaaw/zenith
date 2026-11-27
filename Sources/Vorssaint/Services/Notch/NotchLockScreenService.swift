// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AudioToolbox
import Combine
import SwiftUI

/// The island over the lock screen: music on a pane of Liquid Glass between
/// the clock and the login controls, the activities as a line under the
/// clock, the padlock at the camera, and the padlock sounds. The
/// island drives it from its own session state. On locking it follows the
/// island's teardown, which stops the sources this service then restarts.
/// On unlocking the scene starts leaving before the island comes back, and
/// stops none of the sources the island takes back.
final class NotchLockScreenService {
    static let shared = NotchLockScreenService()

    private struct Frames: Equatable {
        var player: CGRect?
        var row: CGRect?
        var island: CGRect?
        /// The island itself inside its window, at the camera's fitted size.
        var islandSurface: CGRect?
        var terminal: CGRect? // Zenith fork
        var screen: CGRect? // Zenith fork: the lock screen v2's full layer covers it.
    }

    private let model = NotchLockScreenModel()
    private let zenith = ZenithLockScreenV2() // Zenith fork
    private let zenithIsland = ZenithLockIslandController() // Zenith fork: the padlock island's slots and greetings
    /// The player and the line of activities.
    private var scene: [NotchLockScreenPanel] = []
    private var island: NotchLockScreenPanel?
    private var full: NotchLockScreenPanel? // Zenith fork: the lock screen v2's full layer
    /// Zenith fork: watches the desktop's own zoom as the Mac unlocks. macOS
    /// scales every desktop window (the island's too) from about 0.9 back to 1
    /// while its shield fades the lock screen out, so the desktop island waits
    /// it out off screen and only then takes over from the padlock island.
    private var zoomProbe: ZenithDesktopZoomProbe?
    /// Zenith fork: the windows are delegated to the one lock screen Space
    /// (ZenithLockScreenSpace), kept for the app's lifetime; this says whether
    /// they are up, and `generation` which showing a late callback belongs to.
    private var showing = false
    private var generation = 0
    private var joinWork: DispatchWorkItem?
    /// Zenith fork: the padlock island still leaving after an unlock, and
    /// what times its hand-off and samples it.
    private var departing: NotchLockScreenPanel?
    private var unlockTimer: Timer?
    private var alphaTimer: Timer?
    /// Zenith fork: face unlock's state, and hover over the island's visible panel.
    private var faceSubscription: AnyCancellable?
    private var hoverTimer: Timer?
    private var hovering = false
    private var playbackSubscription: AnyCancellable?
    private var screenObserver: NSObjectProtocol?
    private var padlockWork: DispatchWorkItem?
    private var shownFrames = Frames()
    private var wasLocked = false

    private init() {}

    var isShowing: Bool { showing } // Zenith fork: the Space itself stays

    func sync(_ session: NotchSessionState) {
        let locking = session.locked && !wasLocked
        wasLocked = session.locked
        if locking { zenithIsland.locked() } // Zenith fork: the welcome counts from here
        if !session.locked { model.playedWhileLocked = false }
        if session.showsLockScreen, NotchLockScreenSupport.isEnabled() {
            // Locked at the Mac, the padlock is seen closing; back from a
            // dark display it is simply closed.
            show(closingPadlock: locking)
        } else {
            // Unlocked, the island owns the sources again; otherwise nothing
            // shows them until the lock screen returns.
            hide(unlocking: !session.locked && session.canPresent, stopsSources: !session.canPresent)
        }
    }

    /// The island is off: nothing it started keeps running.
    func close() {
        wasLocked = false
        model.playedWhileLocked = false
        hide(unlocking: false, stopsSources: true)
        // Zenith fork: a padlock island still handing over goes with it.
        if let departing {
            _ = NotchService.shared.takeLockHandoff()
            leave(departing)
        }
    }

    func playSound(locking: Bool) {
        guard !ZenithQuiet.isOn else { return } // Zenith fork: tests stay silent
        guard let url = NotchLockScreenSupport.soundURL(locking: locking) else { return }
        var sound: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &sound) == noErr else { return }
        // Asked for here, so it plays even with interface sound effects off
        // in System Settings. The alert volume and the sound effects output
        // still apply, as they do to the Mac's own sounds.
        var interface: UInt32 = 0
        AudioServicesSetProperty(kAudioServicesPropertyIsUISound, UInt32(MemoryLayout<SystemSoundID>.size), &sound,
                                 UInt32(MemoryLayout<UInt32>.size), &interface)
        AudioServicesPlaySystemSoundWithCompletion(sound) { AudioServicesDisposeSystemSoundID(sound) }
    }

    /// Where each part goes on the displays as they are now.
    private static func frames() -> Frames {
        var frames = Frames()
        // macOS draws the clock and the password field on the main display.
        let main = CGMainDisplayID()
        if let screen = (NSScreen.screens.first(where: { $0.notchDisplayID == main }) ?? NSScreen.screens.first)?.frame {
            frames.player = NotchLockScreenLayout.playerFrame(in: screen)
            frames.row = NotchLockScreenLayout.rowFrame(in: screen)
            // Zenith fork: the terminal readout under the activities; the player keeps the rest.
            (frames.terminal, frames.player) = NotchLockScreenTerminalLayout.arrange(
                row: frames.row, player: frames.player, screen: screen,
                lines: NotchLockScreenTerminal.configuration()?.sources.count ?? 0,
                music: NotchLockScreenSupport.showsMusic() && NotchLockScreenItem.music.isOn(),
                lift: ZenithLockScreenMinimalLayout.terminalLift(ZenithLockScreenTerminalPlacement.current()))
            frames.screen = screen // Zenith fork
        }
        // The island's own reading of its camera, with the fit the person set.
        let geometry = NotchService.shared.geometry
        if geometry.isNotched, NSScreen.screens.contains(where: { $0.frame == geometry.screen && $0.safeAreaInsets.top > 0 }) {
            let surface = NotchLockScreenLayout.islandSurface(
                in: geometry.screen, cameraWidth: geometry.bareCutout.width, cameraHeight: geometry.bareCutout.height,
                wing: geometry.lockScreenMusicGeometry.compactActivityWingWidth)
            frames.islandSurface = surface
            // Zenith fork: room for the island's greetings and their swing.
            frames.island = surface.map { ZenithLockIsland.windowFrame(around: $0, in: geometry.screen) }
        }
        return frames
    }

    private func show(closingPadlock: Bool) {
        // Zenith fork: one Space for the app's lifetime, made the first time it is needed.
        guard !showing, let space = ZenithLockScreenSpace.shared else { return }
        // A padlock island still leaving from the last unlock goes at once.
        unlockTimer?.invalidate()
        unlockTimer = nil
        _ = NotchService.shared.takeLockHandoff()
        if let departing { leave(departing) }
        let frames = Self.frames()
        // Settled before any view reads it, so a padlock about to close is
        // drawn open from its first frame.
        padlockWork?.cancel()
        model.padlockOpen = closingPadlock
        // Zenith fork: each item also has its own lock screen switch.
        let calendar = NotchLockScreenItem.calendar.isOn()
        let gates = NotchLockScreenModel.Gates(
            music: NotchLockScreenSupport.showsMusic() && NotchLockScreenItem.music.isOn(),
            timer: NotchTimerSupport.isEnabled() && NotchLockScreenItem.timer.isOn(),
            agents: NotchAgentSupport.showsLiveActivity() && NotchLockScreenItem.agents.isOn(),
            downloads: NotchSupport.routes(.download) && NotchLockScreenItem.downloads.isOn(),
            countdown: NotchCalendarSupport.showsCountdown() && calendar,
            timeLeft: NotchCalendarSupport.showsTimeLeft() && calendar,
            // Zenith fork: not twice when the terminal readout shows its waka line.
            wakatime: WakaTimeSupport.hasConfiguration() && NotchLockScreenItem.wakatime.isOn()
                && !(frames.terminal != nil && NotchLockScreenTerminal.configuration()?.sources.contains(.waka) == true),
            // Zenith fork: weather and reminders also need their permission.
            weather: NotchLockScreenWidgets.showsWeather(),
            reminders: NotchLockScreenWidgets.showsReminders(),
            // Zenith fork: worked out on this Mac, so only their switches.
            prayer: NotchLockScreenItem.prayer.isOn(), golden: NotchLockScreenItem.golden.isOn(),
            jobs: ZenithLockScreenOption.jobs.isOn()) // Zenith fork
        if model.gates != gates { model.gates = gates }
        // Zenith fork: the lock screen v2, its switches read once here like the gates.
        let v2 = ZenithLockScreenV2Gates.resolve(music: gates.music, lyricsAvailable: NotchLyricsSupport.isEnabled())
        var scene: [NotchLockScreenPanel] = []
        // Without the Music section there is no player to show or to click.
        if gates.music, let frame = frames.player {
            if v2.nowPlaying, let row = frames.row {
                // Zenith fork: the now-playing line and the lyric take the player's place.
                let minimal = ZenithLockScreenMinimalLayout.frame(row: row, player: frame)
                let panel = Self.makePanel(frame: minimal, interactive: v2.minimalTakesClicks, content: ZenithLockScreenMinimalView(
                    model: model, zenith: zenith.model, size: minimal.size,
                    titleTop: ZenithLockScreenMinimalLayout.titleTop(row: row, panel: minimal)))
                panel.acceptsMouseMovedEvents = true
                scene.append(panel)
            } else {
                // The one part that takes clicks: the player's buttons and timeline.
                scene.append(Self.makePanel(frame: frame, interactive: true,
                                            content: NotchLockScreenPlayer(model: model, size: frame.size)))
            }
        }
        if let frame = frames.row {
            scene.append(Self.makePanel(frame: frame, content: NotchLockScreenActivities(model: model, size: frame.size)))
        }
        // Zenith fork: the terminal readout, settled as it appears.
        let terminal = frames.terminal.flatMap { frame in
            NotchLockScreenTerminal.configuration().map { (frame: frame, configuration: $0) }
        }
        if let terminal {
            scene.append(Self.makePanel(frame: terminal.frame, content: NotchLockScreenTerminalView(
                configuration: terminal.configuration, size: terminal.frame.size,
                anchorsBottom: ZenithLockScreenMinimalLayout.terminalAnchorsBottom(ZenithLockScreenTerminalPlacement.current()))))
        }
        // Zenith fork: settled before the island is drawn. As the Mac locks it
        // first stands at the bare camera, showing nothing but the notch while
        // macOS fades its shield in, then grows straight into the farewell (or
        // "Locked from …"); the farewell holds the padlock open.
        let began = CACurrentMediaTime()
        let padlockHold = frames.island == nil || frames.islandSurface == nil ? 0.35
            : zenithIsland.begin(locking: closingPadlock, from: closingPadlock ? Self.entrance(frames) : nil)
        // Zenith fork: face unlock as it stands, from the island's first frame.
        zenithIsland.show(face: FaceUnlockPresence.shared.state)
        let makeIsland = { [model, zenithIsland] in
            frames.island.flatMap { frame in
                frames.islandSurface.map { surface in
                    Self.makePanel(frame: frame, level: ZenithLockScreenWindow.islandLevel, content: ZenithLockScreenIsland( // Zenith fork
                        model: model, island: zenithIsland.model, size: surface.size,
                        cameraWidth: NotchService.shared.geometry.bareCutout.width,
                        geometry: NotchService.shared.geometry.lockScreenMusicGeometry,
                        window: frame.size, origin: CGPoint(x: surface.minX - frame.minX, y: frame.maxY - surface.maxY)))
                }
            }
        }
        let island = makeIsland()
        let panels = scene + [island].compactMap { $0 }
        guard !panels.isEmpty else { return }
        if !scene.isEmpty { startSources(gates) }
        if let terminal { NotchLockScreenTerminal.start(terminal.configuration) } // Zenith fork
        // Zenith fork: the full layer joins the Space too, but waits ordered out
        // until the lyric is clicked; the padlock island stays above it.
        let full = v2.full ? frames.screen.map { screen in
            Self.makePanel(frame: screen, interactive: true, content: ZenithLockScreenFullView(zenith: zenith.model, size: screen.size))
        } : nil
        zenith.begin(v2, full: full, island: island, rowWeather: gates.weather)
        showing = true // Zenith fork
        generation += 1
        self.scene = scene
        self.island = island
        self.full = full
        shownFrames = frames
        let closePadlock = { [weak self] in
            guard let self, closingPadlock else { return }
            let work = DispatchWorkItem { [weak self] in self?.model.padlockOpen = false }
            self.padlockWork?.cancel()
            self.padlockWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + padlockHold, execute: work)
        }
        // Zenith fork: with an entrance to come, the padlock's hold counts from it.
        if zenithIsland.model.entranceReleased { closePadlock() }
        // Zenith fork: delegated to the lock screen Space before they are first
        // shown, so they are drawn over the lock screen from their first frame,
        // and only once the session is actually locked.
        let generation = generation
        join(panels + [full].compactMap { $0 }, to: space, generation: generation) { [weak self] in
            guard let self else { return }
            defer {
                // Zenith fork: on screen at the bare notch now; once the shield
                // has faded in, the island grows out of it, the whole spring seen.
                if island != nil, !self.zenithIsland.model.entranceReleased {
                    island?.displayIfNeeded()
                    let wait = ZenithLockHandover.entranceWait(sinceLock: CACurrentMediaTime() - began)
                    DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                        guard let self, self.showing, self.generation == generation else { return }
                        ZenithLockTrace.log(ZenithDesktopZoom.text("entrance released at %.3f s", CACurrentMediaTime() - began)
                                            + " face=\(self.zenithIsland.model.face)")
                        self.zenithIsland.releaseEntrance()
                        closePadlock()
                    }
                }
            }
            for panel in panels {
                // The padlock island is there at once, solid; the rest fades in.
                if panel === island {
                    panel.alphaValue = 1
                    panel.orderFrontRegardless()
                    continue
                }
                panel.alphaValue = 0
                panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.35
                    panel.animator().alphaValue = 1
                }
            }
            ZenithLockTrace.log("ordered in: island level=\(island?.level.rawValue ?? 0) scene=\(self.scene.count)")
        }
        // Zenith fork: the closed desktop island draws back into the bare notch
        // as the lock begins, and the padlock island, which no zoom moves and
        // no shield covers, grows out of the notch once the lock screen is up.
        if island != nil {
            NotchService.shared.retireIsland(animated: closingPadlock)
            zoomProbe?.close()
            zoomProbe = ZenithDesktopZoomProbe(screen: frames.screen ?? NotchService.shared.geometry.screen)
            faceSubscription = FaceUnlockPresence.shared.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.zenithIsland.show(face: state, sessionLocked: ZenithLockScreenSpace.screenIsLocked())
                    self?.syncHover()
                }
            syncHover()
        }
        ZenithLockTrace.log("shown locking=\(closingPadlock) island=\(island != nil)"
                            + " moment=\(zenithIsland.model.moment) entrance=\(zenithIsland.model.entrance.map { "\($0)" } ?? "-")"
                            + " released=\(zenithIsland.model.entranceReleased)")
        playbackSubscription = NotchMusicService.shared.$playback
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playback in
                guard let self, playback?.isPlaying == true, !self.model.playedWhileLocked else { return }
                self.model.playedWhileLocked = true
            }
        // A display attached or rearranged while locked moves the clock, the
        // login controls and the camera; the scene and the padlock follow.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.showing, Self.frames() != self.shownFrames else { return } // Zenith fork
                self.hide(unlocking: false, stopsSources: false)
                self.show(closingPadlock: false)
            }
    }

    private func startSources(_ gates: NotchLockScreenModel.Gates) {
        if gates.music { NotchMusicService.shared.start() }
        if gates.downloads { NotchDownloadService.shared.syncWithPreferences() }
        // An event chosen from its menu counts down with the countdown for every event off.
        if gates.countdown || gates.timeLeft || !NotchCalendarSupport.chosenCountdowns().isEmpty {
            NotchCalendarService.shared.syncWithPreferences()
        }
        if gates.agents { AgentUsageService.shared.syncWithPreferences() }
        // Zenith fork: weather and reminders read only while the lock screen shows.
        NotchLockScreenWidgets.start(weather: gates.weather, reminders: gates.reminders)
    }


    private func hide(unlocking: Bool, stopsSources: Bool) {
        // Zenith fork: weather, reminders and the terminal readout stop with every hide.
        NotchLockScreenWidgets.stop()
        NotchLockScreenTerminal.stop()
        // Zenith fork: the lock screen v2 stops; its full layer, if up, leaves with the rest.
        _ = zenith.end()
        if stopsSources, !scene.isEmpty {
            NotchMusicService.shared.stop()
            NotchDownloadService.shared.stop()
            NotchCalendarService.shared.stop()
            AgentUsageService.shared.pause()
        }
        playbackSubscription = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        padlockWork?.cancel()
        padlockWork = nil
        // Zenith fork: face unlock and hover end with the lock screen; joining it too.
        faceSubscription = nil
        stopHover()
        joinWork?.cancel()
        joinWork = nil
        guard showing, let space = ZenithLockScreenSpace.shared else { return }
        let scene = scene, island = island, full = full, probe = zoomProbe
        self.scene = []
        self.island = nil
        self.full = nil
        zoomProbe = nil
        showing = false
        generation += 1
        ZenithLockTrace.log("hide unlocking=\(unlocking) shape=\(zenithIsland.model.shownSize.map { "\($0)" } ?? "-")")
        guard unlocking else {
            zenithIsland.end() // Zenith fork
            probe?.close()
            for panel in scene + [island, full].compactMap({ $0 }) { // Zenith fork: full
                space.undelegate(panel, name: panel === island ? "island" : "scene")
                panel.orderOut(nil)
            }
            return
        }
        // The lock screen is gone about 0.3 s after the unlock is announced;
        // the player leaves with it rather than lingering over the desktop.
        // Zenith fork: the scene sits at the island's ordinary level in the
        // lock screen Space, so macOS's shield fades it with the lock screen;
        // it finishes leaving and then leaves the Space.
        for panel in scene + [full].compactMap({ $0 }) {
            Self.fadeOut(panel, after: 0) { space.undelegate(panel, name: "scene") }
        }
        let welcome = zenithIsland.unlocking()
        guard let island else {
            probe?.close()
            zenithIsland.end()
            if let welcome {
                DispatchQueue.main.asyncAfter(deadline: .now() + ZenithLockHandover.burstDelay) {
                    NotchService.shared.showZenithBurst(.welcome(welcome))
                }
            }
            return
        }
        unlock(island, welcome: welcome, probe: probe, space: space)
    }

    /// Zenith fork: the padlock island as the Mac unlocks, as Glance's does:
    /// above macOS's shield it stays solid and still while the shield fades
    /// the lock screen out, and grows the welcome (after the success
    /// animation, if face unlock just matched) in itself. Once the desktop has
    /// stopped zooming and the island itself is still, the desktop island
    /// comes back at exactly the welcome's shape and takes it over, and the
    /// padlock island leaves the Space and goes at once, with no fade.
    private func unlock(_ island: NotchLockScreenPanel, welcome: ZenithWelcomeBurst?, probe: ZenithDesktopZoomProbe?,
                        space: ZenithLockScreenSpace) {
        let began = CACurrentMediaTime()
        departing = island
        ZenithLockTrace.log("unlock: padlock island level=\(island.level.rawValue) delegated=\(space.holds(island))"
                            + " alpha=\(island.alphaValue) face=\(zenithIsland.model.face)")
        sampleAlpha(of: island, since: began)
        NotchService.shared.holdIslandForLockScreen(upTo: ZenithLockHandover.longest + ZenithLockHandover.patience)
        model.padlockOpen = true
        let successSince = zenithIsland.model.faceSuccessAt.map { Date().timeIntervalSince($0) }
        let delay = FaceUnlockIslandTiming.welcomeDelay(successSince: successSince)
        var shownAt: CFTimeInterval?
        let grow = { [weak self] in
            guard let self, self.departing === island else { return }
            self.zenithIsland.showUnlocked(welcome)
            shownAt = CACurrentMediaTime()
            ZenithLockTrace.log(ZenithDesktopZoom.text("unlock: %@ grows at %.3f s", welcome == nil ? "bare" : "welcome",
                                                       CACurrentMediaTime() - began))
        }
        if delay > 0 {
            ZenithLockTrace.log(ZenithDesktopZoom.text("unlock: success animation plays %.2f s more", delay))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: grow)
        } else {
            grow()
        }
        var desktopSettled = false
        probe?.waitForRest { waited, zoomed in
            desktopSettled = true
            probe?.close()
            ZenithLockTrace.log(ZenithDesktopZoom.text("desktop zoom over after %.3f s (zoomed=", waited) + "\(zoomed))")
        }
        unlockTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self, self.departing === island else { timer.invalidate(); return }
            let now = CACurrentMediaTime()
            // Moved to what it hands over, its motion begun and over.
            let still = shownAt.map { now - $0 > 0.05 } == true && !self.zenithIsland.model.isMoving()
            // Without a probe the desktop counts as settled after the fallback.
            guard ZenithLockHandover.ready(elapsed: now - began, desktopSettled: desktopSettled, islandSettled: still)
            else { return }
            timer.invalidate()
            self.unlockTimer = nil
            self.handOver(island, welcome: welcome, began: began, shownFor: shownAt.map { now - $0 } ?? 0)
        }
        RunLoop.main.add(timer, forMode: .common)
        unlockTimer = timer
    }

    /// Zenith fork: the padlock island is ready to go (ZenithLockHandover.plan).
    private func handOver(_ island: NotchLockScreenPanel, welcome: ZenithWelcomeBurst?, began: CFTimeInterval,
                          shownFor: TimeInterval) {
        let plan = ZenithLockHandover.plan(welcome: welcome != nil, shown: zenithIsland.model.shownSize)
        ZenithLockTrace.log(ZenithDesktopZoom.text("hand-off at %.3f s, welcome shown %.3f s: ", CACurrentMediaTime() - began, shownFor)
                            + "\(plan)")
        guard case .handOver(let size) = plan, let welcome else {
            // Nothing to hand over: the island draws back into the notch and
            // goes, and the desktop island simply comes back.
            NotchService.shared.releaseIslandForLockScreen()
            if zenithIsland.model.moment == .bare {
                leave(island)
            } else {
                zenithIsland.collapse()
                DispatchQueue.main.asyncAfter(deadline: .now() + ZenithLockHandover.collapse) { [weak self] in
                    self?.leave(island)
                }
            }
            return
        }
        // The welcome as it stands: the desktop island's first frame shows it.
        let look = Self.look(of: island, size: size, frames: shownFrames)
        if let look { ZenithLockTrace.log(ZenithDesktopZoom.text("welcome look drawn, mean alpha %.2f", look.meanAlpha)) }
        var ended = false
        let handoff = ZenithLockHandoff(size: size, look: look?.image, welcome: welcome, shownFor: shownFor, handedOver: { [weak self] in
            guard !ended else { return }
            ended = true
            ZenithLockTrace.log(ZenithDesktopZoom.text("handed over at %.3f s: padlock island leaves at once",
                                                       CACurrentMediaTime() - began))
            self?.leave(island)
        }, declined: { [weak self] in
            guard !ended else { return }
            ended = true
            NotchService.shared.releaseIslandForLockScreen()
            // The island keeps the welcome to its end, then draws back into the notch.
            let remaining = ZenithLockHandover.welcomeRemaining(shownFor: shownFor, duration: ZenithIslandBurstTiming.welcome)
            ZenithLockTrace.log(ZenithDesktopZoom.text("hand-off declined: padlock island keeps the welcome %.2f s", remaining))
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                guard let self, self.departing === island else { return }
                self.zenithIsland.collapse()
                DispatchQueue.main.asyncAfter(deadline: .now() + ZenithLockHandover.collapse) { self.leave(island) }
            }
        })
        NotchService.shared.awaitLockHandoff(handoff)
        NotchService.shared.releaseIslandForLockScreen()
        // Not back on screen in time, it is not coming back to take over.
        DispatchQueue.main.asyncAfter(deadline: .now() + ZenithLockHandover.patience) {
            _ = NotchService.shared.takeLockHandoff()
            handoff.declined()
        }
    }

    /// Zenith fork: the padlock island goes now: out of the lock screen
    /// Space, then ordered out, solid to its last frame.
    private func leave(_ island: NotchLockScreenPanel) {
        ZenithLockScreenSpace.shared?.undelegate(island, name: "island")
        island.orderOut(nil)
        guard departing === island else { return }
        departing = nil
        unlockTimer?.invalidate()
        unlockTimer = nil
        ZenithLockTrace.log("padlock island ordered out")
        // Unless the lock screen came back meanwhile.
        if !showing { zenithIsland.end() }
    }

    /// Zenith fork: the padlock island's alpha as the window server reports
    /// it, sampled from the unlock and logged as it changes (lock.log).
    private func sampleAlpha(of island: NSWindow, since began: CFTimeInterval) {
        alphaTimer?.invalidate()
        guard ZenithLockTrace.sink != nil, island.windowNumber > 0 else { return }
        let id = CGWindowID(island.windowNumber)
        var last: (alpha: Double, onScreen: Bool)?
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            let elapsed = CACurrentMediaTime() - began
            let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first
            let alpha = (info?[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0
            let onScreen = (info?[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
            if last.map({ abs($0.alpha - alpha) > 0.005 || $0.onScreen != onScreen }) ?? true {
                ZenithLockTrace.log(ZenithDesktopZoom.text("island alpha %.3f at %.3f s", alpha, elapsed) + " onScreen=\(onScreen)")
                last = (alpha, onScreen)
            }
            guard elapsed >= ZenithLockHandover.longest + ZenithLockHandover.patience || info == nil || !onScreen else { return }
            timer.invalidate()
            if self?.alphaTimer === timer { self?.alphaTimer = nil }
        }
        RunLoop.main.add(timer, forMode: .common)
        alphaTimer = timer
    }

    /// Zenith fork: delegates `windows` to the lock screen Space once the
    /// session is actually locked, then runs `shown`; retried briefly while
    /// it is not yet. Never locked by then, nothing is shown.
    private func join(_ windows: [NotchLockScreenPanel], to space: ZenithLockScreenSpace, generation: Int,
                      attempt: Int = 0, shown: @escaping () -> Void) {
        guard showing, self.generation == generation else { return }
        if windows.allSatisfy({ space.delegate($0, name: $0 === island ? "island" : "scene") }) {
            joinWork = nil
            shown()
            return
        }
        guard attempt < 60 else {
            ZenithLockTrace.log("never locked after 3 s: lock screen windows stay hidden")
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.join(windows, to: space, generation: generation, attempt: attempt + 1, shown: shown)
        }
        joinWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    // MARK: Hover (Zenith fork)

    /// While face unlock shows, the island follows the pointer as Glance's
    /// does: it takes the pointer only over its visible panel, and hovering
    /// it asks for a scan (FaceUnlockPresence.onActivate). Polled, since a
    /// window ignoring the mouse gets no events.
    private func syncHover() {
        guard island != nil, FaceUnlockIslandStage.tracksHover(zenithIsland.model.face) else { stopHover(); return }
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.checkHover() }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
        checkHover()
    }

    private func stopHover() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hovering = false
        island?.ignoresMouseEvents = true
    }

    private func checkHover() {
        guard let island, let surface = shownFrames.islandSurface, let shown = zenithIsland.model.shownSize else { return }
        let over = FaceUnlockIslandLayout.hoverRect(surface: surface, shown: shown).contains(NSEvent.mouseLocation)
        if island.ignoresMouseEvents == over { island.ignoresMouseEvents = !over }
        guard over != hovering else { return }
        hovering = over
        guard over, FaceUnlockIslandStage.hoverActivates(zenithIsland.model.face) else { return }
        ZenithLockTrace.log("hover: face unlock asked to scan (\(zenithIsland.model.face))")
        FaceUnlockPresence.shared.onActivate?()
    }

    /// Zenith fork: where the padlock island first appears as the Mac locks:
    /// the bare camera, so nothing but the notch shows while macOS fades its
    /// shield in; it grows from there once the lock screen is up.
    private static func entrance(_ frames: Frames) -> CGSize? {
        guard let surface = frames.islandSurface else { return nil }
        return CGSize(width: NotchService.shared.geometry.bareCutout.width, height: surface.height)
    }

    /// Zenith fork: what the padlock island shows now, drawn at `size` from
    /// its window as it stands: the desktop island shows it in its first
    /// frame as it takes over. With how much of it is drawn, for the log.
    private static func look(of panel: NSPanel, size: CGSize, frames: Frames) -> (image: NSImage, meanAlpha: Double)? {
        guard let view = panel.contentView, let window = frames.island, let surface = frames.islandSurface,
              size.width > 0, size.height > 0 else { return nil }
        let x = surface.midX - window.minX - size.width / 2
        let rect = CGRect(x: x, y: view.isFlipped ? 0 : view.bounds.height - size.height, width: size.width, height: size.height)
            .intersection(view.bounds)
        guard !rect.isEmpty, let bitmap = view.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        view.cacheDisplay(in: rect, to: bitmap)
        let image = NSImage(size: rect.size)
        image.addRepresentation(bitmap)
        return (image, ZenithDesktopZoom.meanAlpha(bitmap))
    }

    private static func fadeOut(_ panel: NSPanel, after delay: TimeInterval, completion: @escaping () -> Void) {
        let duration: TimeInterval = 0.2
        let fade = {
            // AppKit steps its fades on the main thread, which the island
            // coming back holds as the Mac unlocks, so the player could stay
            // over the desktop for a second. The window server fades on its own,
            // once a fade-in AppKit may still be stepping stops where it is.
            panel.alphaValue = panel.alphaValue
            if NotchWindowServerFade.fadeOut(panel, duration: duration) {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    panel.alphaValue = 0
                    panel.orderOut(nil)
                    completion()
                }
            } else {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = duration
                    panel.animator().alphaValue = 0
                }, completionHandler: {
                    panel.orderOut(nil)
                    completion()
                })
            }
        }
        if delay > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: fade) } else { fade() }
    }

    /// Zenith fork: `level` lifts the padlock island above macOS's shield
    /// (ZenithLockScreenWindow.islandLevel); the scene keeps the island's
    /// ordinary level, so the shield fades it with the lock screen.
    private static func makePanel<Content: View>(frame: CGRect, interactive: Bool = false,
                                                 level: NSWindow.Level = NotchPanel.normalLevel,
                                                 content: Content) -> NotchLockScreenPanel {
        let panel = NotchLockScreenPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                         backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = level // Zenith fork
        panel.collectionBehavior = ZenithLockScreenWindow.collectionBehavior // Zenith fork: Glance's
        // Only the player's pane takes clicks, where it draws. Left unset, a
        // window lets clicks through its clear pixels, so the room around the
        // pane and a player with no song pass them to the lock screen beneath.
        // Set to false, the whole frame would take them even with nothing shown.
        if !interactive { panel.ignoresMouseEvents = true }
        let host = NotchLockScreenHostingView(rootView: AnyView(content))
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(frame, display: false)
        return panel
    }
}

/// A fade the window server runs by itself, whatever the main thread is
/// doing. The symbols are resolved at runtime. Without them AppKit fades.
private enum NotchWindowServerFade {
    private typealias AlphaFunction = @convention(c) (UInt32, UnsafePointer<UInt32>, Int32, Float, Float) -> Int32

    private static let bridge: (connection: UInt32, setAlpha: AlphaFunction)? = {
        func symbol(_ name: String) -> UnsafeMutableRawPointer? {
            dlsym(UnsafeMutableRawPointer(bitPattern: -2) /* RTLD_DEFAULT */, name)
        }
        guard let main = symbol("CGSMainConnectionID"), let alpha = symbol("CGSSetWindowListAlpha") else { return nil }
        let connection = unsafeBitCast(main, to: (@convention(c) () -> UInt32).self)()
        guard connection != 0 else { return nil }
        return (connection, unsafeBitCast(alpha, to: AlphaFunction.self))
    }()

    /// Whether the window server took the fade.
    static func fadeOut(_ window: NSWindow, duration: TimeInterval) -> Bool {
        guard let bridge, window.windowNumber > 0 else { return false }
        var id = UInt32(window.windowNumber)
        return bridge.setAlpha(bridge.connection, &id, 1, 0, Float(duration)) == 0
    }
}

/// Never key and never main: while the Mac is locked every keystroke belongs
/// to the password field, and a click on the player must not take it away.
final class NotchLockScreenPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // A window that never holds key focus would otherwise draw its glass as
    // an inactive window does, flat and dull.
    @objc func _hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
    override func accessibilitySubrole() -> NSAccessibility.Subrole? { .unknown }
}

private final class NotchLockScreenHostingView: NSHostingView<AnyView> {
    // The panel is never key, so a button has to answer the first click.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
