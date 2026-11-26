// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import WatchConnectivity

/// The iPhone's side of Pocket on the Apple Watch, over WatchConnectivity.
///
/// The pairing goes to the Watch in the application context (re-sent when it
/// changes, sent empty on unpair), so the Watch reaches the relay itself.
/// Beside it rides the newest state this iPhone heard, trimmed for the Watch,
/// and the iPhone's battery: cheap and best effort, at most twice a minute
/// unless something the Watch's face shows changed. When the Watch can't
/// send a command itself it hands it here (`sendMessage`), and it goes out
/// over the live channel if one is open, else over REST broadcast. The other
/// way, the Watch sends its own battery (its application context, or a
/// queued user info from a background refresh), which Devices shows and
/// Zenith's Batteries gets with this iPhone's report.
@MainActor
final class WatchBridge: NSObject {
    static let shared = WatchBridge()

    /// States push at most this often unless the Watch's face would change.
    static let throttle: TimeInterval = 30

    private weak var model: PocketModel?
    private var pairing: PocketPairing?
    private var snapshot: PocketWatchSnapshot?
    private var phone: PocketDeviceReport.Device?
    private var sent: PocketWatchContext?
    private var sentKey: Glance?
    private var sentAt: Date?
    private var deferred: Task<Void, Never>?
    private var activated = false

    /// What the Watch's face and complications show; a change pushes at once.
    private struct Glance: Equatable {
        var percent: Int?
        var charging: Bool?
        var claude: String?
        var needsYou: Bool
        var locked: Bool
        var awake: Bool
        var away: Bool?
        var playing: String?
        var mic: Bool?

        init(_ state: PocketMacState?) {
            percent = state?.battery?.percent
            charging = state?.battery?.charging
            claude = PocketWatchPresentation.claudeWord(state?.claude)
            needsYou = PocketWatchPresentation.needsYou(state)
            locked = state?.locked ?? false
            awake = state?.awakeUntil != nil
            away = state?.claude?.away
            playing = state?.nowPlaying.map { "\($0.title)|\($0.playing)" }
            mic = state?.sound?.micMuted
        }
    }

    func start(model: PocketModel, pairing: PocketPairing?) {
        self.model = model
        self.pairing = pairing
        guard WCSession.isSupported(), !activated else { return }
        activated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: From the model

    func pairingChanged(_ next: PocketPairing?) {
        guard next != pairing else { return }
        pairing = next
        if next == nil { snapshot = nil }
        push(urgent: true)
    }

    func stateChanged(_ state: PocketMacState, sentAt: Date, heardAt: Date) {
        snapshot = PocketWatchSnapshot(state: PocketWatchPresentation.trimmed(state), sentAt: sentAt, heardAt: heardAt)
        push(urgent: Glance(state) != sentKey)
    }

    func phoneChanged(_ device: PocketDeviceReport.Device?) {
        guard device?.percent != phone?.percent || device?.charging != phone?.charging else { return }
        phone = device
        push(urgent: false)
    }

    // MARK: Sending

    private var context: PocketWatchContext {
        PocketWatchContext(pairing: pairing, snapshot: pairing == nil ? nil : snapshot, phone: phone)
    }

    private func push(urgent: Bool) {
        let wait = Self.throttle - Date().timeIntervalSince(sentAt ?? .distantPast)
        guard urgent || wait <= 0 else {
            guard deferred == nil else { return }
            deferred = Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let self else { return }
                self.deferred = nil
                self.pushNow()
            }
            return
        }
        pushNow()
    }

    private func pushNow() {
        deferred?.cancel(); deferred = nil
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let next = context
        guard next != sent, let dictionary = try? next.dictionary() else { return }
        do {
            try session.updateApplicationContext(dictionary)
            sent = next
            sentKey = Glance(next.snapshot?.state)
            sentAt = Date()
        } catch {
            // Too big or not now: the next change tries again.
        }
    }

    // MARK: From the Watch

    nonisolated private static let watchKey = "pocket.watchBattery"

    /// The Watch's last battery reading, kept across launches.
    nonisolated static func storedWatch() -> PocketDeviceReport.Device? {
        guard let data = UserDefaults.standard.data(forKey: watchKey) else { return nil }
        return PocketWatchContext.watchBattery(from: [PocketWatchContext.watchBatteryKey: data])
    }

    fileprivate func received(_ body: [String: Any]) {
        guard let device = PocketWatchContext.watchBattery(from: body) else { return }
        if let current = Self.storedWatch(), current.readAt > device.readAt { return }
        UserDefaults.standard.set(body[PocketWatchContext.watchBatteryKey] as? Data, forKey: Self.watchKey)
        model?.watchBatteryChanged(device)
    }

    fileprivate func activated(_ state: WCSessionActivationState) {
        guard state == .activated else { return }
        sent = nil
        pushNow()
        received(WCSession.default.receivedApplicationContext)
    }

    fileprivate func reply(to message: [String: Any]) async -> [String: Any] {
        if let command = PocketWatchContext.command(from: message) {
            let ok = await model?.relayFromWatch(command) ?? false
            return [PocketWatchContext.sentKey: ok]
        }
        if message[PocketWatchContext.helloKey] != nil {
            return (try? context.dictionary()) ?? [:]
        }
        return [:]
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in WatchBridge.shared.activated(activationState) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// A different Watch was paired: activate again for it.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchBridge.shared.sent = nil
            WatchBridge.shared.pushNow()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let body = Message(applicationContext)
        Task { @MainActor in WatchBridge.shared.received(body.body) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let body = Message(userInfo)
        Task { @MainActor in WatchBridge.shared.received(body.body) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let request = Message(message)
        let answer = Reply(replyHandler)
        Task { @MainActor in
            answer.send(await WatchBridge.shared.reply(to: request.body))
        }
    }
}

/// WatchConnectivity hands its dictionaries and reply handlers over on its
/// own queue; they hold property-list values only and are used once.
private struct Message: @unchecked Sendable {
    let body: [String: Any]
    init(_ body: [String: Any]) { self.body = body }
}

private struct Reply: @unchecked Sendable {
    let handler: ([String: Any]) -> Void
    init(_ handler: @escaping ([String: Any]) -> Void) { self.handler = handler }
    func send(_ body: [String: Any]) { handler(body) }
}

extension PocketModel {
    /// A command the Watch couldn't send itself: over the live channel when
    /// it is open, else the way the Watch would have, over REST broadcast.
    func relayFromWatch(_ command: PocketCommand) async -> Bool {
        if link == .live, let pocketLink, (try? await pocketLink.send(.command(command))) != nil { return true }
        guard let pairing else { return false }
        return (try? await PocketCourier(pairing: pairing, me: .phone).send(.command(command))) != nil
    }
}
