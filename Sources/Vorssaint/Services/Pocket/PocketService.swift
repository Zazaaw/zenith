// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import ImageIO
import IOKit.ps
import Security
import SystemConfiguration
import UniformTypeIdentifiers

/// Zenith fork: Zenith Pocket on the Mac, the iPhone and Apple Watch companion.
///
/// While Pocket is on, a relay is saved and a phone is paired (or a QR code
/// waits for one), one `PocketLink` keeps the Mac on the pairing's sealed
/// channel. It publishes this Mac's state, built from what Zenith's services
/// already publish (battery, lock, Keep Awake, WakaTime, prayer times, now
/// playing, Claude Code's hooks, Batteries): live while someone listens,
/// and in the Mac's box for a phone whose app is closed. It runs the few
/// commands a phone may send (lock, Keep Awake, play/pause and skip) and
/// hands the phone's and Watch's batteries to Batteries.
///
/// Nothing polls: every reading comes from a publisher or a notification
/// those services already have, a change waits two seconds for others and
/// travels at most every five, and the box is written at once only for a
/// change worth waking up to, otherwise at most once a minute. Off, asleep
/// or unpaired, nothing runs at all. Used on the main thread.
final class PocketService {
    static let shared = PocketService()

    private let store = PocketStore.shared
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket", qos: .utility)

    private var installed = false
    private var loaded = false
    private var relay: PocketRelayConfig?
    private var pairing: PocketPairing?
    private var lastSeen: Date?
    private var sharing = PocketSharing()
    private var sleeping = false
    private var defaultsObserver: PocketDefaultsObserver?
    private var syncPending = false

    // While the link runs.
    private var link: PocketLink?
    /// The second round's parts (`PocketParts`), alive while the link is.
    private var parts: [PocketPart] = []
    /// A part changed since the last live send / box write.
    private var partsDirty = false
    private var partsBoxDirty = false
    /// Whether a phone has Pocket open (its `.presence`), with the moment it lapses.
    private var watching = false
    private var watchingWork: DispatchWorkItem?
    private var generation = 0
    private var sinks: Set<AnyCancellable> = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?
    private var sampler: PowerSampler?
    private var battery: PocketMacState.Battery?
    private var locked = false
    private var macName = "Mac"
    private var limiter = RemoteRateLimiter()
    private var report: [PocketDeviceReport.Device] = []

    private var liveWork: DispatchWorkItem?
    private var boxWork: DispatchWorkItem?
    private var heartbeatWork: DispatchWorkItem?
    private var prayerTimer: Timer?
    private var prayerTimerAt: Date?
    private var sentInputs: PocketMacInputs?
    private var sentSharing: PocketSharing?
    private var sentAt: Date?
    private var boxInputs: PocketMacInputs?
    private var boxSharing: PocketSharing?
    private var boxAt: Date?
    private var boxFailedAt: Date?

    private var wallpaperKey: String?
    private var wallpaperHash: String?
    /// Whether `store.problem` is the relay's, which a good write clears.
    private var relayProblem = false

    private init() {}

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: PocketDefaults.enabled) }

    // MARK: Lifecycle

    /// At launch and whenever a Pocket preference changes (watched here, so
    /// Settings only writes its switches).
    func syncWithPreferences() {
        installOnce()
        if !loaded { load() }
        let next = PocketSharing.current()
        let sharingChanged = next != sharing
        sharing = next
        if Self.isEnabled, let pairing, !sleeping {
            if link?.pairing != pairing {
                startLink(pairing)
            } else if sharingChanged {
                bindSources()
                if !sharing.wallpaper { clearWallpaper() } else { checkWallpaper() }
                flush(force: true)
            }
        } else {
            stopLink(clearReport: !Self.isEnabled || pairing == nil)
        }
        publishPhase()
    }

    private func installOnce() {
        guard !installed else { return }
        installed = true
        store.saveRelayHandler = { relay in PocketService.onMain { PocketService.shared.saveRelay(relay) } }
        store.startPairingHandler = { PocketService.onMain { PocketService.shared.startPairing() } }
        store.cancelPairingHandler = { PocketService.onMain { PocketService.shared.cancelPairing() } }
        store.unpairHandler = { PocketService.onMain { PocketService.shared.unpair() } }
        defaultsObserver = PocketDefaultsObserver(keys: [PocketDefaults.enabled, PocketDefaults.shareWallpaper,
                                                         PocketDefaults.shareAgents, PocketDefaults.shareNowPlaying]) {
            PocketService.onMain { PocketService.shared.preferencesChanged() }
        }
        // Asleep, the relay can't be reached anyway: the link goes and comes
        // back on wake, which also reads what the phone left meanwhile.
        let workspace = NSWorkspace.shared.notificationCenter
        _ = workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            PocketService.shared.sleeping = true
            PocketService.shared.syncWithPreferences()
        }
        _ = workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            PocketService.shared.sleeping = false
            PocketService.shared.syncWithPreferences()
        }
    }

    /// Several switches written together make one sync.
    private func preferencesChanged() {
        guard !syncPending else { return }
        syncPending = true
        DispatchQueue.main.async { [self] in
            syncPending = false
            syncWithPreferences()
        }
    }

    private static func onMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
    }

    // MARK: Secrets

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    private func load() {
        loaded = true
        relay = ZenithSecretStore.read(PocketDefaults.relaySecret).flatMap(Self.decode)
        pairing = ZenithSecretStore.read(PocketDefaults.pairingSecret).flatMap(Self.decode)
        if let saved = pairing, saved.relay != relay {
            // A pairing outlived its relay (a file removed by hand): it can't be reached.
            forgetPairing()
        }
        let seen = UserDefaults.standard.double(forKey: PocketDefaults.lastSeen)
        lastSeen = pairing != nil && seen > 0 ? Date(timeIntervalSince1970: seen) : nil
    }

    private static func decode<Value: Decodable>(_ text: String) -> Value? {
        try? decoder.decode(Value.self, from: Data(text.utf8))
    }

    private static func save<Value: Encodable>(_ value: Value, as name: String) -> Bool {
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else { return false }
        return ZenithSecretStore.save(text, as: name)
    }

    // MARK: Handlers (Settings)

    private func saveRelay(_ next: PocketRelayConfig?) {
        if !loaded { load() }
        if let next, !next.isValid {
            store.problem = PocketPhaseRules.invalidRelay
            return
        }
        store.problem = nil
        guard PocketPhaseRules.forgetsPairing(saving: next, over: relay) else { return }
        if let next {
            guard Self.save(next, as: PocketDefaults.relaySecret) else {
                store.problem = PocketPhaseRules.couldNotSave
                return
            }
        } else {
            ZenithSecretStore.delete(PocketDefaults.relaySecret)
        }
        relay = next
        forgetPairing()
        syncWithPreferences()
    }

    private func startPairing() {
        if !loaded { load() }
        guard Self.isEnabled, let relay else {
            store.problem = PocketPhaseRules.turnOnFirst
            return
        }
        let fresh = PocketPairing.make(relay: relay, macName: Self.computerName())
        forgetPairing()
        guard Self.save(fresh, as: PocketDefaults.pairingSecret) else {
            store.problem = PocketPhaseRules.couldNotSave
            syncWithPreferences()
            return
        }
        store.problem = nil
        pairing = fresh
        syncWithPreferences()
    }

    private func cancelPairing() {
        forgetPairing()
        syncWithPreferences()
    }

    private func unpair() {
        if let pairing { Self.scrub(pairing) }
        forgetPairing()
        syncWithPreferences()
    }

    /// Overwrites the pairing's boxes with random bytes, so the phone that
    /// still holds the old key reads nothing from now on (the relay would
    /// otherwise keep the last state until its 30-day sweep).
    private static func scrub(_ pairing: PocketPairing) {
        let boxes = PocketBoxClient(relay: pairing.relay)
        for id in [pairing.macBoxID, pairing.wallpaperBoxID, pairing.phoneBoxID] {
            var noise = [UInt8](repeating: 0, count: 48)
            _ = SecRandomCopyBytes(kSecRandomDefault, noise.count, &noise)
            let sealed = Data(noise).base64EncodedString()
            Task { try? await boxes.put(id: id, sealed: sealed) }
        }
    }

    /// The pairing, its key and everything learnt through it go.
    private func forgetPairing() {
        ZenithSecretStore.delete(PocketDefaults.pairingSecret)
        UserDefaults.standard.removeObject(forKey: PocketDefaults.lastSeen)
        pairing = nil
        lastSeen = nil
        stopLink(clearReport: true)
        wallpaperKey = nil
        wallpaperHash = nil
    }

    private func publishPhase() {
        let phase = PocketPhaseRules.phase(enabled: Self.isEnabled, relay: relay, pairing: pairing, lastSeen: lastSeen)
        if store.phase != phase { store.phase = phase }
        if store.relay != relay { store.relay = relay }
    }

    // MARK: The link

    private func startLink(_ pairing: PocketPairing) {
        stopLink(clearReport: false)
        generation += 1
        let generation = self.generation
        let link = PocketLink(pairing: pairing, me: .mac)
        self.link = link
        store.link = .connecting
        macName = Self.computerName()
        locked = RemoteControlService.screenLocked()
        limiter = RemoteRateLimiter()
        startPower()
        observe()
        bindSources()
        startParts(pairing: pairing, link: link)
        Task {
            await link.start(onLive: { envelope in
                DispatchQueue.main.async { PocketService.shared.receive(envelope, generation: generation) }
            }, onStatus: { status in
                DispatchQueue.main.async { PocketService.shared.linkChanged(status, generation: generation) }
            })
        }
        // What the phone reported while the Mac was away.
        let phoneBox = pairing.phoneBoxID
        Task {
            guard let envelope = try? await link.getBox(phoneBox, as: PocketDeviceReport.self) else { return }
            DispatchQueue.main.async { PocketService.shared.receiveBox(envelope, generation: generation) }
        }
        checkWallpaper()
        flush(force: true)
    }

    private func stopLink(clearReport: Bool) {
        if clearReport, !report.isEmpty || !store.devices.isEmpty {
            report = []
            store.devices = []
            BatteriesMonitor.shared.setPocketReport([])
        }
        guard let link else {
            if store.link != .offline { store.link = .offline }
            return
        }
        generation += 1
        self.link = nil
        Task { await link.stop() }
        liveWork?.cancel(); liveWork = nil
        boxWork?.cancel(); boxWork = nil
        heartbeatWork?.cancel(); heartbeatWork = nil
        prayerTimer?.invalidate(); prayerTimer = nil; prayerTimerAt = nil
        sinks.removeAll()
        stopParts()
        unobserve()
        stopPower()
        sentInputs = nil; sentSharing = nil; sentAt = nil
        boxInputs = nil; boxSharing = nil; boxAt = nil; boxFailedAt = nil
        if store.link != .offline { store.link = .offline }
    }

    private func linkChanged(_ status: PocketLink.Status, generation: Int) {
        guard generation == self.generation else { return }
        if store.link != status { store.link = status }
        // Joined (again): whoever listens gets the state as it is now.
        if status == .live {
            sentInputs = nil
            stateMayHaveChanged()
        }
    }

    // MARK: From the phone

    private func receive(_ envelope: PocketEnvelope<PocketLive>, generation: Int) {
        guard generation == self.generation, envelope.from != .mac else { return }
        // The Mac's clock, not the phone's: it may run ahead or behind.
        seen(at: Date())
        switch envelope.body {
        case .report(let report): apply(report)
        case .command(let command): run(command, id: envelope.id)
        case .macState, .result, .wallpaperChanged: break
        }
    }

    private func receiveBox(_ envelope: PocketEnvelope<PocketDeviceReport>, generation: Int) {
        guard generation == self.generation, envelope.from != .mac else { return }
        seen(at: min(envelope.sentAt, Date()))
        apply(envelope.body)
    }

    /// The first message of a fresh pairing confirms it; later ones move
    /// `lastSeen` on, at Settings' granularity.
    private func seen(at date: Date) {
        guard lastSeen == nil || PocketPhaseRules.publishesSeen(date, after: lastSeen) else { return }
        lastSeen = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: PocketDefaults.lastSeen)
        publishPhase()
    }

    private func apply(_ incoming: PocketDeviceReport) {
        let clean = PocketBatteries.sanitized(incoming, now: Date())
        // The box may arrive after a live report it is older than.
        if let current = PocketBatteries.readAt(report), let next = PocketBatteries.readAt(clean), next < current { return }
        guard clean != report else { return }
        report = clean
        store.devices = clean
        BatteriesMonitor.shared.setPocketReport(clean)
        stateMayHaveChanged()
    }

    // MARK: Parts

    private func startParts(pairing: PocketPairing, link: PocketLink) {
        parts = PocketParts.make()
        let context = PocketPartContext(
            pairing: pairing, link: link,
            changed: { PocketService.onMain { PocketService.shared.partChanged() } },
            reply: { id, ok, message in PocketService.onMain { PocketService.shared.reply(id, ok: ok, message) } })
        parts.forEach { $0.start(context) }
    }

    private func stopParts() {
        parts.forEach { $0.stop() }
        parts = []
        watchingWork?.cancel(); watchingWork = nil
        watching = false
        partsDirty = false
        partsBoxDirty = false
    }

    private func partChanged() {
        guard link != nil else { return }
        partsDirty = true
        partsBoxDirty = true
        stateMayHaveChanged()
    }

    /// An open phone repeats its presence every minute; without it the Mac
    /// stops sampling after `presenceLapse`.
    private func setWatching(_ open: Bool) {
        watchingWork?.cancel(); watchingWork = nil
        if open {
            let lapse = DispatchWorkItem { PocketService.shared.setWatching(false) }
            watchingWork = lapse
            DispatchQueue.main.asyncAfter(deadline: .now() + PocketCadence.presenceLapse, execute: lapse)
        }
        guard open != watching else { return }
        watching = open
        parts.forEach { $0.setWatching(open) }
        if open { flush(force: false) }
    }

    /// The first round's state, then each part's field.
    private func buildState(_ inputs: PocketMacInputs, now: Date) -> PocketMacState {
        var state = PocketStateBuilder.state(inputs, sharing: sharing, now: now)
        for part in parts { part.fill(&state) }
        return state
    }

    // MARK: Commands

    private func run(_ command: PocketCommand, id: UUID) {
        // Presence comes once a minute from an open phone; it doesn't count
        // against the command limit.
        if case .presence(let open) = command {
            setWatching(open)
            reply(id, ok: true)
            return
        }
        guard limiter.allow(at: Date()) else {
            reply(id, ok: false, RemoteText.tooMany)
            return
        }
        for part in parts where part.handle(command, id: id) { return }
        let allowAnswers = UserDefaults.standard.bool(forKey: PocketDefaults.allowAnswers)
        switch PocketCommands.plan(command, allowAnswers: allowAnswers) {
        case .lock:
            let macBook = PowerSampler.hasInternalBattery
            if RemoteControlService.screenLocked() {
                reply(id, ok: true, RemoteText.alreadyLocked(macBook: macBook))
                return
            }
            // The lock screen says who asked, as for the SSH remote.
            ZenithRemoteLockMark.mark(device: report.first { $0.kind == .iphone }?.name ?? "iPhone")
            let immediate = QuickTogglesService.shared.lockScreenForRemote()
            reply(id, ok: true, immediate ? RemoteText.locked(macBook: macBook) : RemoteText.screenSaver)
        case .keepAwakeOff:
            KeepAwakeManager.shared.deactivate(reason: .manual)
            reply(id, ok: true)
        case .keepAwakeIndefinitely:
            keepAwake(id) { $0.activate(minutes: 0) }
        case .keepAwakePreset(let minutes):
            keepAwake(id) { $0.activate(minutes: minutes) }
        case .keepAwakeFor(let minutes):
            keepAwake(id) { $0.activate(until: Date().addingTimeInterval(TimeInterval(minutes) * 60)) }
        case .media(let playback):
            let music = NotchMusicService.shared
            if music.canPerform(playback), music.send(playback) {
                reply(id, ok: true)
            } else if let key = PocketCommands.mediaKey(playback) {
                // A player the island isn't following (or the island is off)
                // still hears the media keys.
                RadialMenuService.postMediaKey(key)
                reply(id, ok: true)
            } else {
                reply(id, ok: false)
            }
        case .answer:
            // No path exists yet; `plan` never returns this without one.
            reply(id, ok: false, PocketCommands.answersUnavailable)
        case .refresh:
            MainActor.assumeIsolated { WakaTimeService.shared.refreshIfStale() }
            checkWallpaper()
            sentInputs = nil
            flush(force: true)
            reply(id, ok: true)
        case .refuse(let message):
            reply(id, ok: false, message)
        }
    }

    private func keepAwake(_ id: UUID, _ start: (KeepAwakeManager) -> Void) {
        guard AppFeature.keepAwake.isAvailable else {
            reply(id, ok: false, PocketCommands.keepAwakeOff)
            return
        }
        let manager = KeepAwakeManager.shared
        start(manager)
        reply(id, ok: manager.isActive)
    }

    private func reply(_ id: UUID, ok: Bool, _ message: String? = nil) {
        guard let link else { return }
        let result = PocketLive.result(PocketCommandResult(commandID: id, ok: ok, message: message))
        Task { try? await link.send(result) }
    }

    // MARK: Sources

    /// Every publisher the state is read from; their first value is skipped,
    /// the state is built once after binding.
    private func bindSources() {
        sinks.removeAll()
        let awake = KeepAwakeManager.shared
        Self.watch(awake.$isActive, in: &sinks)
        Self.watch(awake.$endDate, in: &sinks)
        Self.watch(BatteriesStore.shared.$devices, in: &sinks)
        Self.watch(SkyService.shared.$day, in: &sinks)
        MainActor.assumeIsolated {
            let waka = WakaTimeService.shared
            Self.watch(waka.$today, in: &PocketService.shared.sinks)
            Self.watch(waka.$history, in: &PocketService.shared.sinks)
        }
        if sharing.agents { Self.watch(ClaudeHooksService.shared.$sessions, in: &sinks) }
        if sharing.nowPlaying { Self.watch(NotchMusicService.shared.$playback, in: &sinks) }
    }

    private static func watch<P: Publisher>(_ publisher: P, in sinks: inout Set<AnyCancellable>) where P.Failure == Never {
        publisher.dropFirst().sink { _ in PocketService.shared.stateMayHaveChanged() }.store(in: &sinks)
    }

    private func observe() {
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
                PocketService.shared.lockChanged(true)
            }))
        observers.append((distributed, distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
                PocketService.shared.lockChanged(false)
            }))
        // Each Space and display can have its own picture.
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append((workspace, workspace.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
                PocketService.shared.checkWallpaper()
            }))
        let center = NotificationCenter.default
        observers.append((center, center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
                PocketService.shared.checkWallpaper()
            }))
    }

    private func unobserve() {
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
    }

    private func lockChanged(_ isLocked: Bool) {
        guard locked != isLocked else { return }
        locked = isLocked
        stateMayHaveChanged()
    }

    // MARK: Power

    private func startPower() {
        guard powerSource == nil, PowerSampler.hasInternalBattery else { return }
        sampler = PowerSampler(smc: nil)
        readPower()
        let callback: IOPowerSourceCallbackType = { _ in
            PocketService.onMain { PocketService.shared.powerChanged() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, nil)?.takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private func stopPower() {
        if let source = powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        powerSource = nil
        sampler = nil
        battery = nil
    }

    private func powerChanged() {
        guard sampler != nil else { return }
        readPower()
        stateMayHaveChanged()
    }

    private func readPower() {
        guard let reading = sampler?.sample(), reading.hasBattery else { battery = nil; return }
        let charging = ZenithChargeState.of(external: reading.externalConnected, charging: reading.isCharging,
                                            percent: reading.chargePercent) == .charging
        battery = PocketStateBuilder.battery(percent: reading.chargePercent, charging: charging,
                                             minutesToFull: charging ? ZenithPowerEstimate.minutesToFull() : nil,
                                             secondsToEmpty: reading.timeRemainingSeconds,
                                             pluggedIn: reading.externalConnected)
    }

    // MARK: Publishing

    /// Something the state is made of may have changed: build it after the
    /// debounce, no sooner than the live interval allows.
    private func stateMayHaveChanged() {
        guard link != nil, liveWork == nil else { return }
        let work = DispatchWorkItem { PocketService.shared.flush(force: false) }
        liveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + PocketCadence.liveDelay(now: Date(), lastSent: sentAt),
                                      execute: work)
    }

    /// Builds the state; sends it live when it changed and the channel is
    /// joined; writes the box when the cadence says so (`force`: now).
    private func flush(force: Bool) {
        liveWork?.cancel(); liveWork = nil
        guard let link else { return }
        let now = Date()
        let inputs = gatherInputs(now: now)
        schedulePrayer(inputs.nextPrayer?.at)
        if store.link == .live, inputs != sentInputs || sharing != sentSharing || partsDirty {
            let state = buildState(inputs, now: now)
            partsDirty = false
            sentInputs = inputs
            sentSharing = sharing
            sentAt = now
            Task { try? await link.send(.macState(state)) }
        }
        considerBox(inputs, now: now, force: force)
    }

    private func considerBox(_ inputs: PocketMacInputs, now: Date, force: Bool) {
        var decision: PocketCadence.BoxDecision = force ? .now : PocketCadence.box(inputs, sharing: sharing, written: boxInputs,
                                                        sharingWritten: boxSharing, writtenAt: boxAt, now: now)
        // A part's change reaches the box on the ordinary cadence, at most once a minute.
        if decision == .none, partsBoxDirty {
            decision = .after(max(0, PocketCadence.boxInterval - now.timeIntervalSince(boxAt ?? .distantPast)))
        }
        // A relay that just refused waits out the interval before the next try.
        if let failed = boxFailedAt, decision != .none {
            let wait = PocketCadence.boxInterval - now.timeIntervalSince(failed)
            if wait > 0 { decision = .after(wait) }
        }
        switch decision {
        case .none:
            return
        case .after(let wait):
            guard boxWork == nil else { return }
            let work = DispatchWorkItem {
                PocketService.shared.boxWork = nil
                let now = Date()
                PocketService.shared.considerBox(PocketService.shared.gatherInputs(now: now), now: now, force: false)
            }
            boxWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: work)
        case .now:
            boxWork?.cancel(); boxWork = nil
            writeBox(inputs, now: now)
        }
    }

    private func writeBox(_ inputs: PocketMacInputs, now: Date) {
        guard let link else { return }
        boxInputs = inputs
        boxSharing = sharing
        boxAt = now
        boxFailedAt = nil
        heartbeatWork?.cancel()
        let beat = DispatchWorkItem {
            PocketService.shared.heartbeatWork = nil
            PocketService.shared.flush(force: true)
        }
        heartbeatWork = beat
        DispatchQueue.main.asyncAfter(deadline: .now() + PocketCadence.heartbeat, execute: beat)
        partsBoxDirty = false
        let state = buildState(inputs, now: now)
        let id = link.pairing.macBoxID
        let generation = self.generation
        Task {
            do {
                try await link.putBox(id, state)
                DispatchQueue.main.async { PocketService.shared.boxWritten(nil, generation: generation) }
            } catch {
                let code: Int? = { if case PocketRelayError.http(let code) = error { return code }; return nil }()
                DispatchQueue.main.async { PocketService.shared.boxWritten(code ?? 0, generation: generation) }
            }
        }
        // A wallpaper changed without a Space or display change shows up here.
        checkWallpaper()
    }

    /// nil: written; a code: refused (0 without an answer).
    private func boxWritten(_ failure: Int?, generation: Int) {
        guard generation == self.generation else { return }
        if let failure {
            boxInputs = nil
            boxFailedAt = Date()
            let problem = PocketPhaseRules.relayProblem(status: failure)
            relayProblem = true
            if store.problem != problem { store.problem = problem }
        } else if relayProblem {
            relayProblem = false
            store.problem = nil
        }
    }

    private func schedulePrayer(_ at: Date?) {
        guard at != prayerTimerAt else { return }
        prayerTimer?.invalidate(); prayerTimer = nil
        prayerTimerAt = at
        guard let at else { return }
        // Its time passed: the next one is due.
        let timer = Timer(fire: at.addingTimeInterval(1), interval: 0, repeats: false) { _ in
            PocketService.shared.stateMayHaveChanged()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        prayerTimer = timer
    }

    // MARK: Reading the state

    private func gatherInputs(now: Date) -> PocketMacInputs {
        var inputs = PocketMacInputs(macName: macName)
        inputs.battery = battery
        inputs.locked = locked
        let awake = KeepAwakeManager.shared
        inputs.awakeActive = awake.isActive
        inputs.awakeEnd = awake.endDate
        inputs.coding = MainActor.assumeIsolated { () -> PocketMacState.Coding? in
            let service = WakaTimeService.shared
            let key = WakaTimeSupport.dayKey(now)
            if let today = service.today, today.date == key {
                return PocketStateBuilder.coding(seconds: today.totalSeconds, goalMinutes: service.goalMinutes,
                                                 languages: today.languages)
            }
            return PocketStateBuilder.coding(seconds: service.history[key], goalMinutes: service.goalMinutes,
                                             languages: [])
        }
        let sky = SkyService.shared
        if let day = sky.currentDay(now: now), let next = PrayerTimesSupport.next(after: now, in: day.moments) {
            inputs.nextPrayer = PocketMacState.Prayer(name: sky.name(next.prayer, language: L10n.shared.language),
                                                      at: next.time)
        }
        if sharing.agents { inputs.sessions = ClaudeHooksService.shared.sessions }
        if sharing.nowPlaying { inputs.playback = NotchMusicService.shared.playback.flatMap(PocketStateBuilder.playback) }
        inputs.accessories = PocketStateBuilder.accessories(BatteriesStore.shared.devices, report: report)
        if sharing.wallpaper { inputs.wallpaperHash = wallpaperHash }
        return inputs
    }

    private static func computerName() -> String {
        let name = (SCDynamicStoreCopyComputerName(nil, nil) as String?)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.flatMap { $0.isEmpty ? nil : String($0.prefix(64)) } ?? "Mac"
    }

    // MARK: Wallpaper

    /// Reads the main display's picture again only when its file changed,
    /// and uploads the thumbnail only when it is a different picture.
    private func checkWallpaper() {
        guard let link, sharing.wallpaper, let screen = NSScreen.screens.first,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return }
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        let key = PocketWallpaperSupport.key(path: url.path, modified: modified)
        guard key != wallpaperKey else { return }
        wallpaperKey = key
        let generation = self.generation
        let box = link.pairing.wallpaperBoxID
        queue.async {
            guard let jpeg = Self.thumbnail(url) else { return }
            let hash = PocketWallpaperSupport.hash(jpeg)
            DispatchQueue.main.async {
                let service = PocketService.shared
                guard generation == service.generation, hash != service.wallpaperHash, let link = service.link else { return }
                Task {
                    do {
                        try await link.putBox(box, PocketWallpaper(jpeg: jpeg))
                        DispatchQueue.main.async { PocketService.shared.wallpaperUploaded(hash, generation: generation) }
                    } catch {
                        DispatchQueue.main.async {
                            // Tried again with the next check.
                            if generation == PocketService.shared.generation { PocketService.shared.wallpaperKey = nil }
                        }
                    }
                }
            }
        }
    }

    private func wallpaperUploaded(_ hash: String, generation: Int) {
        guard generation == self.generation, let link, sharing.wallpaper else { return }
        wallpaperHash = hash
        if store.link == .live { Task { try? await link.send(.wallpaperChanged(hash: hash)) } }
        stateMayHaveChanged()
    }

    /// Sharing turned off: the picture leaves the relay too, as an empty box.
    private func clearWallpaper() {
        guard wallpaperHash != nil || wallpaperKey != nil else { return }
        wallpaperHash = nil
        wallpaperKey = nil
        guard let link else { return }
        let box = link.pairing.wallpaperBoxID
        Task { try? await link.putBox(box, PocketWallpaper(jpeg: Data())) }
    }

    private static func thumbnail(_ url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: PocketWallpaperSupport.maximumPixels] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image,
                                   [kCGImageDestinationLossyCompressionQuality: PocketWallpaperSupport.quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

/// Watches a few preference keys (KVO), so a switch in Settings reaches the
/// service without it listening to every preference Zenith writes.
private final class PocketDefaultsObserver: NSObject {
    private let keys: [String]
    private let changed: () -> Void

    init(keys: [String], changed: @escaping () -> Void) {
        self.keys = keys
        self.changed = changed
        super.init()
        keys.forEach { UserDefaults.standard.addObserver(self, forKeyPath: $0, options: [], context: nil) }
    }

    deinit {
        keys.forEach { UserDefaults.standard.removeObserver(self, forKeyPath: $0) }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        changed()
    }
}
