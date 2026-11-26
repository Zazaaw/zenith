// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import LocalAuthentication
import Observation
import PocketKit
import WidgetKit

/// Everything the Watch shows, and how it reaches the Mac without a socket.
///
/// State: the newest of what the iPhone handed over (WatchConnectivity) and
/// the Mac's box read straight from the relay over HTTPS, on opening and
/// every minute while the app shows. Commands go out as REST broadcasts on
/// the pairing's channel (`PocketCourier`), sealed as `.watch`; if that
/// fails and the iPhone is near, the iPhone sends them. The Watch hears no
/// reply, so it reads the box again a few seconds later and says so once the
/// Mac's state shows the change.
@MainActor
@Observable
final class WatchModel {
    struct Note: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let tone: PocketTone
        var symbol: String {
            switch tone {
            case .good: return "checkmark.circle.fill"
            case .alert: return "exclamationmark.circle.fill"
            case .attention: return "clock.fill"
            default: return "paperplane.fill"
            }
        }
    }

    /// While the app shows, the box is read again this often.
    static let poll: TimeInterval = 60
    /// A box older than this on opening asks the Mac for a fresh one.
    static let staleBox: TimeInterval = 90
    /// The Mac samples its sound only while someone watches.
    static let presenceEvery: TimeInterval = 60

    private(set) var pairing: PocketPairing?
    private(set) var snapshot: PocketWatchSnapshot?
    /// The iPhone's battery, as the iPhone last said.
    private(set) var phone: PocketDeviceReport.Device?
    /// This Watch's battery, read here.
    private(set) var battery: PocketDeviceReport.Device?
    private(set) var checking = false
    private(set) var problem: String?
    private(set) var note: Note?
    /// Commands sent and not yet seen in the Mac's state, by `busyKey`.
    private(set) var busy: Set<String> = []

    private var active = false
    private var loop: Task<Void, Never>?
    private var glance: String?

    init() {
        pairing = WatchVault.loadPairing()
        snapshot = WatchVault.loadSnapshot()
        glance = snapshot.map(Self.glance)
        battery = WatchBattery.read()
        PhoneLink.shared.start(model: self)
    }

    var state: PocketMacState? { snapshot?.state }

    func freshness(now: Date = Date()) -> PocketFreshness {
        PocketPresentation.freshness(heardAt: snapshot?.heardAt, live: false, now: now)
    }

    var batteryItems: [PocketBatteryItem] {
        PocketPresentation.batteryItems(state, phone: phone, watch: battery)
    }

    // MARK: Lifecycle

    func becameActive() {
        guard !active else { return }
        active = true
        batteryChanged()
        if pairing == nil { PhoneLink.shared.hello() }
        loop = Task { [weak self] in
            await self?.refresh(askMac: true)
            await self?.watchMac()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(WatchModel.poll))
                guard !Task.isCancelled, let self else { return }
                self.batteryChanged()
                await self.refresh(askMac: false)
                await self.watchMac()
            }
        }
    }

    func resignedActive() {
        guard active else { return }
        active = false
        loop?.cancel(); loop = nil
        WatchBattery.stop()
    }

    /// A background refresh: the Watch's battery to the iPhone, the box for
    /// the complications.
    func backgroundRefresh() async {
        battery = WatchBattery.read()
        if let battery { PhoneLink.shared.send(battery: battery, queued: true) }
        await refresh(askMac: false)
    }

    /// Tells the Mac someone is watching, so it shares its sound (volume,
    /// the mic) while the app is open; it lapses on its own once it closes.
    private func watchMac() async {
        guard let pairing, freshness().isReachable else { return }
        _ = try? await PocketCourier(pairing: pairing, me: .watch).send(.command(.presence(watching: true)))
    }

    // MARK: Battery

    func batteryChanged() {
        guard let next = WatchBattery.read() else { return }
        let moved = next.percent != battery?.percent || next.charging != battery?.charging
        battery = next
        if moved || active { PhoneLink.shared.send(battery: next, queued: false) }
    }

    // MARK: State

    /// Reads the box; a stale one asks the Mac for its state and reads again.
    func refresh(askMac: Bool) async {
        guard let pairing else { return }
        checking = snapshot == nil
        defer { checking = false }
        do {
            let fetched = try await WatchVault.fetch(pairing)
            guard pairing == self.pairing else { return }
            problem = nil
            if let fetched { apply(fetched) }
            let age = Date().timeIntervalSince(snapshot?.heardAt ?? .distantPast)
            guard askMac, age > Self.staleBox, freshness().isReachable || snapshot == nil else { return }
            _ = try? await PocketCourier(pairing: pairing, me: .watch).send(.command(.refresh))
            try? await Task.sleep(for: .seconds(2.5))
            if let again = try? await WatchVault.fetch(pairing), pairing == self.pairing { apply(again) }
        } catch {
            problem = "Pocket couldn't reach the relay."
        }
    }

    /// Keeps the newer state, saves it for the complications, and reloads
    /// them when what they show changed.
    @discardableResult
    func apply(_ next: PocketWatchSnapshot) -> Bool {
        guard let newest = PocketWatchSnapshot.newest(snapshot, next), newest != snapshot else { return false }
        let before = snapshot?.state
        snapshot = newest
        WatchVault.saveSnapshot(newest)
        let key = Self.glance(newest)
        if key != glance {
            glance = key
            WidgetCenter.shared.reloadAllTimelines()
        }
        if let before, PocketWatchPresentation.needsYou(newest.state), !PocketWatchPresentation.needsYou(before) {
            Haptics.notify()
        }
        return true
    }

    /// What the complications show, to tell when they need a reload.
    private static func glance(_ snapshot: PocketWatchSnapshot) -> String {
        let state = snapshot.state
        return [PocketWatchPresentation.inline(snapshot, now: snapshot.heardAt),
                "\(state.battery?.charging ?? false)", "\(PocketWatchPresentation.needsYou(state))"].joined(separator: "|")
    }

    /// The iPhone's application context: its pairing, its newest state and battery.
    func receive(_ context: PocketWatchContext) {
        if let next = context.pairing {
            if next != pairing {
                if pairing != nil { forget() }
                pairing = next
                WatchVault.savePairing(next)
                if active { Task { await refresh(askMac: true) } }
            }
            if let snapshot = context.snapshot { apply(snapshot) }
            phone = context.phone
        } else if pairing != nil {
            forget()
            pairing = nil
            WatchVault.deletePairing()
            phone = nil
        }
    }

    private func forget() {
        snapshot = nil
        glance = nil
        busy = []
        WatchVault.saveSnapshot(nil)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Commands

    func lock() { send(.lock) }
    func keepAwake(_ minutes: Int?) { send(.keepAwake(minutes: minutes)) }
    func muteMic(_ muted: Bool) { send(.muteMic(muted)) }
    func media(_ action: PocketCommand.MediaAction) { send(.media(action), quiet: true) }
    func setVolume(_ percent: Int) { send(.setVolume(min(100, max(0, percent))), quiet: true) }
    func setAway(_ on: Bool) { send(.setAway(on)) }
    func setAwayWait(_ minutes: Int) { send(.setAwayWait(minutes: minutes)) }

    /// A reply makes Claude Code act on the Mac, so the Watch must be on a
    /// wrist and unlocked, as the iPhone asks for Face ID.
    func reply(to session: PocketClaude.Session, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PocketPresentation.claudeReplyFits(trimmed) else {
            show(trimmed.isEmpty ? "Say something to send." : "That reply is too long.", .alert)
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithWristDetection, error: &error) else {
            show("Wear your Apple Watch, unlocked, to reply to Claude.", .alert)
            return
        }
        send(.claudeReply(sessionID: session.id, text: trimmed))
    }

    func isBusy(_ command: PocketCommand) -> Bool { busy.contains(Self.busyKey(command)) }

    private static func busyKey(_ command: PocketCommand) -> String {
        switch command {
        case .lock: return "lock"
        case .keepAwake: return "awake"
        case .muteMic: return "mic"
        case .setAway, .setAwayWait: return "away"
        case .claudeReply: return "reply"
        case .media: return "media"
        case .setVolume: return "volume"
        default: return "other"
        }
    }

    /// Sends a command over REST broadcast (else through the iPhone), then
    /// reads the Mac's box until its state shows the change. `quiet` ones
    /// (media, volume) show no note.
    func send(_ command: PocketCommand, quiet: Bool = false) {
        guard let pairing else { return }
        guard freshness().isReachable else {
            show(PocketPresentation.unreachable, .quiet)
            Haptics.failure()
            return
        }
        let key = Self.busyKey(command)
        if !quiet { busy.insert(key); show(PocketWatchPresentation.sentLine(command), .info) }
        let before = state
        Task {
            var sent = (try? await PocketCourier(pairing: pairing, me: .watch).send(.command(command))) != nil
            if !sent { sent = await PhoneLink.shared.relay(command) }
            guard pairing == self.pairing else { return }
            guard sent else {
                busy.remove(key)
                show("Pocket couldn't reach your Mac. Try again.", .alert)
                Haptics.failure()
                return
            }
            if !quiet { Haptics.tap() }
            await confirm(command, before: before, key: key, quiet: quiet, pairing: pairing)
        }
    }

    /// The Watch can't hear the Mac's reply: it asks for a fresh box and
    /// reads it a few times until the state agrees.
    private func confirm(_ command: PocketCommand, before: PocketMacState?, key: String, quiet: Bool, pairing: PocketPairing) async {
        defer { busy.remove(key) }
        try? await Task.sleep(for: .seconds(1))
        if !quiet { _ = try? await PocketCourier(pairing: pairing, me: .watch).send(.command(.refresh)) }
        var waited: TimeInterval = 1
        for delay in PocketWatchPresentation.confirmDelays {
            try? await Task.sleep(for: .seconds(max(0, delay - waited)))
            waited = delay
            guard pairing == self.pairing else { return }
            guard let fetched = try? await WatchVault.fetch(pairing) else { continue }
            let changed = apply(fetched)
            switch PocketWatchPresentation.confirms(command, before: before, after: fetched.state) {
            case true?:
                if !quiet { show(PocketWatchPresentation.doneLine(command), .good); Haptics.success() }
                return
            case nil where changed:
                if !quiet { show(PocketWatchPresentation.doneLine(command), .good) }
                return
            default:
                continue
            }
        }
        if !quiet { show(PocketWatchPresentation.unconfirmed, .attention) }
    }

    // MARK: Notes

    func show(_ text: String, _ tone: PocketTone) {
        let next = Note(text: text, tone: tone)
        note = next
        Task {
            try? await Task.sleep(for: .seconds(3))
            if note?.id == next.id { note = nil }
        }
    }
}
