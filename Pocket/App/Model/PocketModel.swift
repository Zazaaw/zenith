// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Observation
import PocketKit
import UIKit

/// Everything the screens show, and the one link to the Mac.
///
/// While the app is open, a `PocketLink` (`.phone`) keeps the sealed live
/// channel: the Mac's state arrives as it changes, commands go out and their
/// results come back. On opening, the Mac's box and the wallpaper box give
/// the last known state at once, and `.refresh` asks the Mac for a fresh one.
/// In the background the link is closed; only the battery report goes on,
/// through the phone's box (see `BackgroundReport`).
@MainActor
@Observable
final class PocketModel {
    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let ok: Bool
    }

    /// The tabs, in the island bar's order.
    enum Tab: Int, CaseIterable, Identifiable {
        case home, control, agents, devices
        var id: Int { rawValue }
    }

    /// The keep-awake lengths offered; 0 is until turned off.
    static let awakeChoices = [15, 60, 240]
    /// A Mac box older than this is read again while the app stays open.
    static let boxPoll: TimeInterval = 5 * 60
    /// How long a command waits for the Mac's result.
    static let resultTimeout: TimeInterval = 10

    private(set) var pairing: PocketPairing?
    private(set) var link: PocketLink.Status = .offline
    private(set) var state: PocketMacState?
    /// The Mac's clock when the shown state was sent (to count a song on).
    private(set) var stateSentAt: Date?
    /// When the newest state was sent (box) or received (live).
    private(set) var heardAt: Date?
    private(set) var stateIsLive = false
    /// The first box read after opening is still on its way.
    private(set) var loading = false
    private(set) var relayProblem: String?
    private(set) var wallpaper: UIImage?
    private(set) var phone: PocketDeviceReport.Device?
    private(set) var toast: Toast?
    /// The Mac's reply to an answer, by question id.
    private(set) var answers: [String: String] = [:]
    private(set) var answering: Set<String> = []
    /// The keep-awake length last asked for here, for the meter's whole.
    private(set) var awakeChoice: Int?
    /// The question the island bar is open on, nil when it is a bar.
    private(set) var islandQuestion: PocketMacState.AgentQuestion?
    private var dismissedQuestions: Set<String> = []

    var tab: Tab = .home
    var showingSettings = false
    /// A code scanned (or opened) while already paired, waiting for a yes.
    var replacement: PocketPairing?

    private var pocketLink: PocketLink?
    private var generation = 0
    private var active = false
    private var poll: Task<Void, Never>?
    private var pending: [UUID: PocketCommand] = [:]
    private var wallpaperHash: String?
    private var fetchingWallpaper: String?
    private var reportWork: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        pairing = PairingStore.load()
        if let cached = WallpaperCache.load() {
            wallpaperHash = cached.hash
            wallpaper = UIImage(data: cached.jpeg)
        }
    }

    // MARK: Derived

    func freshness(now: Date = Date()) -> PocketFreshness {
        PocketPresentation.freshness(heardAt: heardAt, live: stateIsLive, now: now)
    }

    /// Commands need the channel joined and a Mac that is awake to hear them.
    func canControl(now: Date = Date()) -> Bool {
        link == .live && freshness(now: now).isReachable
    }

    /// Why the controls are off, nil when they work.
    func controlProblem(now: Date = Date()) -> String? {
        if !freshness(now: now).isReachable {
            return "Your Mac is asleep, off or offline. Lock and Keep Awake work again once Zenith is back."
        }
        if link != .live { return "Connecting to your Mac…" }
        return nil
    }

    var batteryItems: [PocketBatteryItem] { PocketPresentation.batteryItems(state, phone: phone) }

    // MARK: Lifecycle

    func becameActive() {
        guard !active else { return }
        active = true
        observeBattery()
        phone = PhoneBattery.read()
        guard let pairing else { return }
        start(pairing)
    }

    func movedToBackground() {
        guard active else { return }
        active = false
        unobserveBattery()
        stop()
        guard let pairing else { return }
        // One last report for Zenith, then the background refresh takes over.
        let report = PhoneBattery.report()
        let task = UIApplication.shared.beginBackgroundTask(withName: "Pocket report")
        Task {
            if let report { try? await PocketLink(pairing: pairing, me: .phone).putBox(pairing.phoneBoxID, report) }
            UIApplication.shared.endBackgroundTask(task)
        }
        BackgroundReport.schedule()
    }

    private func start(_ pairing: PocketPairing) {
        stop()
        generation += 1
        let generation = self.generation
        let link = PocketLink(pairing: pairing, me: .phone)
        pocketLink = link
        loading = state == nil
        let onLive: @Sendable (PocketEnvelope<PocketLive>) -> Void = { [weak self] envelope in
            Task { @MainActor in self?.receive(envelope, generation: generation) }
        }
        let onStatus: @Sendable (PocketLink.Status) -> Void = { [weak self] status in
            Task { @MainActor in self?.linkChanged(status, generation: generation) }
        }
        Task { await link.start(onLive: onLive, onStatus: onStatus) }
        Task { await readMacBox(generation: generation) }
        sendReport()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(PocketModel.boxPoll))
                guard !Task.isCancelled, let self else { return }
                await self.readMacBox(generation: generation)
            }
        }
    }

    private func stop() {
        generation += 1
        poll?.cancel(); poll = nil
        reportWork?.cancel(); reportWork = nil
        if let pocketLink { Task { await pocketLink.stop() } }
        pocketLink = nil
        link = .offline
        stateIsLive = false
        pending.removeAll()
        answering.removeAll()
    }

    // MARK: Pairing

    /// A scanned code or an opened link. Returns whether it was a pairing code.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let next = PocketPairing(url: url) else { return false }
        if let pairing, pairing != next {
            replacement = next
        } else if pairing == nil {
            pair(with: next)
        }
        return true
    }

    func pair(with next: PocketPairing) {
        replacement = nil
        guard PairingStore.save(next) else {
            show("Pocket couldn't save the pairing on this iPhone.", ok: false)
            return
        }
        stop()
        forgetMac()
        pairing = next
        tab = .home
        if active { start(next) }
    }

    /// Forgets the key. The phone's box is emptied first, so Zenith drops
    /// this iPhone from Batteries.
    func unpair() {
        guard let pairing else { return }
        stop()
        Task { try? await PocketLink(pairing: pairing, me: .phone).putBox(pairing.phoneBoxID, PocketDeviceReport(devices: [])) }
        PairingStore.delete()
        self.pairing = nil
        forgetMac()
        showingSettings = false
    }

    private func forgetMac() {
        state = nil; stateSentAt = nil; heardAt = nil; stateIsLive = false
        relayProblem = nil; answers = [:]; awakeChoice = nil
        islandQuestion = nil; dismissedQuestions = []
        wallpaper = nil; wallpaperHash = nil
        WallpaperCache.clear()
    }

    // MARK: From the Mac

    private func linkChanged(_ status: PocketLink.Status, generation: Int) {
        guard generation == self.generation else { return }
        link = status
        guard status == .live, let pocketLink else { return }
        // Joined: ask for the state as it is now, and tell Zenith our battery.
        let report = PhoneBattery.report()
        Task {
            _ = try? await pocketLink.send(.command(.refresh))
            if let report { _ = try? await pocketLink.send(.report(report)) }
        }
    }

    private func receive(_ envelope: PocketEnvelope<PocketLive>, generation: Int) {
        guard generation == self.generation, envelope.from == .mac else { return }
        switch envelope.body {
        case .macState(let next):
            // Received now: the phone's clock, as the Mac's may differ.
            apply(next, sentAt: envelope.sentAt, heard: Date(), live: true)
        case .result(let result):
            finish(result)
        case .wallpaperChanged(let hash):
            fetchWallpaper(hash)
        case .report, .command:
            break
        }
    }

    private func readMacBox(generation: Int) async {
        guard let pocketLink, let pairing else { return }
        do {
            let envelope = try await pocketLink.getBox(pairing.macBoxID, as: PocketMacState.self)
            guard generation == self.generation else { return }
            loading = false
            relayProblem = nil
            if let envelope, envelope.from == .mac {
                apply(envelope.body, sentAt: envelope.sentAt, heard: min(envelope.sentAt, Date()), live: false)
            }
        } catch {
            guard generation == self.generation else { return }
            loading = false
            relayProblem = Self.describe(error)
        }
    }

    private func apply(_ next: PocketMacState, sentAt: Date, heard: Date, live: Bool) {
        // A box older than what the channel already said is no news.
        if !live, let heardAt, heard <= heardAt { return }
        state = next
        stateSentAt = sentAt
        heardAt = max(heard, heardAt ?? heard)
        stateIsLive = live
        loading = false
        if next.awakeUntil == nil { awakeChoice = nil }
        if let hash = next.wallpaperHash {
            if hash != wallpaperHash { fetchWallpaper(hash) }
        } else if wallpaperHash != nil {
            // Sharing the wallpaper was turned off on the Mac.
            wallpaper = nil; wallpaperHash = nil
            WallpaperCache.clear()
        }
        updateIsland(next.questions)
    }

    private func fetchWallpaper(_ hash: String) {
        guard hash != wallpaperHash, hash != fetchingWallpaper, let pocketLink, let pairing else { return }
        fetchingWallpaper = hash
        let generation = self.generation
        Task {
            let envelope = try? await pocketLink.getBox(pairing.wallpaperBoxID, as: PocketWallpaper.self)
            guard generation == self.generation else { return }
            fetchingWallpaper = nil
            guard let jpeg = envelope?.body.jpeg else { return }
            if jpeg.isEmpty {
                wallpaper = nil; wallpaperHash = nil
                WallpaperCache.clear()
                return
            }
            guard let image = UIImage(data: jpeg) else { return }
            wallpaper = image
            wallpaperHash = WallpaperCache.hash(jpeg)
            WallpaperCache.save(jpeg)
        }
    }

    // MARK: Island

    private func updateIsland(_ questions: [PocketMacState.AgentQuestion]) {
        let ids = Set(questions.map(\.id))
        dismissedQuestions.formIntersection(ids)
        answers = answers.filter { ids.contains($0.key) }
        islandQuestion = questions.first { !dismissedQuestions.contains($0.id) }
    }

    /// Folds the island back into the bar until another question comes.
    func collapseIsland() {
        if let islandQuestion { dismissedQuestions.insert(islandQuestion.id) }
        islandQuestion = nil
    }

    // MARK: Commands

    func lock() { send(.lock) }

    /// nil turns keep-awake off; 0 keeps the Mac awake until turned off.
    func keepAwake(_ minutes: Int?) {
        guard send(.keepAwake(minutes: minutes)) else { return }
        awakeChoice = minutes
    }

    func media(_ action: PocketCommand.MediaAction) { send(.media(action)) }

    /// Sent as asked; the Mac answers whether it can (not yet: its reply
    /// says so, and it shows under the question).
    func answer(_ question: PocketMacState.AgentQuestion, allow: Bool) {
        guard send(.answer(questionID: question.id, allow: allow)) else { return }
        answering.insert(question.id)
    }

    @discardableResult
    private func send(_ command: PocketCommand) -> Bool {
        guard canControl(), let pocketLink else {
            show(controlProblem() ?? PocketPresentation.unreachable, ok: false)
            return false
        }
        let generation = self.generation
        Task {
            do {
                let id = try await pocketLink.send(.command(command))
                guard generation == self.generation else { return }
                pending[id] = command
                try? await Task.sleep(for: .seconds(Self.resultTimeout))
                guard generation == self.generation, pending.removeValue(forKey: id) != nil else { return }
                if case .answer(let questionID, _) = command { answering.remove(questionID) }
                show(PocketPresentation.noAnswer, ok: false)
            } catch {
                guard generation == self.generation else { return }
                show("Pocket isn't connected yet. Try again in a moment.", ok: false)
            }
        }
        return true
    }

    private func finish(_ result: PocketCommandResult) {
        guard let command = pending.removeValue(forKey: result.commandID) else { return }
        let line = PocketPresentation.resultLine(result, for: command)
        switch command {
        case .refresh:
            if !result.ok { show(line, ok: false) }
        case .answer(let questionID, _):
            answering.remove(questionID)
            answers[questionID] = line
        default:
            show(line, ok: result.ok)
        }
    }

    // MARK: Toast

    func show(_ text: String, ok: Bool) {
        let next = Toast(text: text, ok: ok)
        toast = next
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if toast?.id == next.id { toast = nil }
        }
    }

    // MARK: Battery report

    private func observeBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let center = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [weak self] in self?.batteryChanged() }
            })
        }
    }

    private func unobserveBattery() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    /// Level and state often change together; one report covers both.
    private func batteryChanged() {
        reportWork?.cancel()
        reportWork = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            self.phone = PhoneBattery.read()
            self.sendReport()
        }
    }

    /// This iPhone's battery: live when the channel is joined, and in the box.
    private func sendReport() {
        guard let pocketLink, let pairing, let report = PhoneBattery.report() else { return }
        phone = report.devices.first
        let live = link == .live
        Task {
            if live { _ = try? await pocketLink.send(.report(report)) }
            try? await pocketLink.putBox(pairing.phoneBoxID, report)
        }
    }

    private static func describe(_ error: Error) -> String {
        if case PocketRelayError.http(let code) = error {
            return "The relay refused Pocket (HTTP \(code))."
        }
        return "Pocket couldn't reach the relay."
    }
}
