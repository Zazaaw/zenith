// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import WatchConnectivity
import WatchKit

/// This Watch's battery, as a report entry for the iPhone (and Zenith).
@MainActor
enum WatchBattery {
    /// nil when watchOS has no reading yet.
    static func read(now: Date = Date()) -> PocketDeviceReport.Device? {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        let charging = device.batteryState == .charging || device.batteryState == .full
        let given = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PocketDeviceReport.Device(kind: .watch, name: given.isEmpty ? "Apple Watch" : given,
                                         percent: Int((level * 100).rounded()), charging: charging, readAt: now)
    }

    /// Monitoring costs a little; it runs only while the app shows.
    static func stop() { WKInterfaceDevice.current().isBatteryMonitoringEnabled = false }
}

/// The Watch's side of WatchConnectivity: the iPhone's application context
/// brings the pairing and its newest state; the Watch sends its battery
/// back (its own application context, a message when the iPhone is near so
/// it wakes and passes it on, or a queued user info from the background);
/// and a command the relay refused goes through the iPhone.
@MainActor
final class PhoneLink: NSObject {
    static let shared = PhoneLink()

    private weak var model: WatchModel?
    private var started = false

    func start(model: WatchModel) {
        self.model = model
        guard WCSession.isSupported(), !started else { return }
        started = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private var ready: Bool { WCSession.default.activationState == .activated }

    /// Asks the iPhone for its context (the Watch has no pairing yet).
    func hello() {
        let session = WCSession.default
        guard ready, session.isReachable else { return }
        session.sendMessage([PocketWatchContext.helloKey: true], replyHandler: { reply in
            let body = Body(reply)
            Task { @MainActor in PhoneLink.shared.received(body.value) }
        }, errorHandler: nil)
    }

    func send(battery: PocketDeviceReport.Device, queued: Bool) {
        let session = WCSession.default
        guard ready, let message = try? PocketWatchContext.watchBatteryMessage(battery) else { return }
        try? session.updateApplicationContext(message)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else if queued {
            session.transferUserInfo(message)
        }
    }

    /// Hands a command to the iPhone; true once the iPhone sent it on.
    func relay(_ command: PocketCommand) async -> Bool {
        let session = WCSession.default
        guard ready, session.isReachable, let message = try? PocketWatchContext.commandMessage(command) else { return false }
        return await withCheckedContinuation { continuation in
            let once = Once(continuation)
            session.sendMessage(message, replyHandler: { reply in
                once.resume(reply[PocketWatchContext.sentKey] as? Bool ?? false)
            }, errorHandler: { _ in once.resume(false) })
        }
    }

    fileprivate func received(_ body: [String: Any]) {
        guard let context = PocketWatchContext(dictionary: body) else { return }
        model?.receive(context)
    }

    fileprivate func activated() {
        received(WCSession.default.receivedApplicationContext)
        if model?.pairing == nil { hello() }
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in PhoneLink.shared.activated() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let body = Body(applicationContext)
        Task { @MainActor in PhoneLink.shared.received(body.value) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in if PhoneLink.shared.model?.pairing == nil { PhoneLink.shared.hello() } }
    }
}

/// WatchConnectivity's dictionaries hold property-list values only.
private struct Body: @unchecked Sendable {
    let value: [String: Any]
    init(_ value: [String: Any]) { self.value = value }
}

/// A continuation resumed by whichever of the reply or the error comes first.
private final class Once: @unchecked Sendable {
    private var continuation: CheckedContinuation<Bool, Never>?
    private let lock = NSLock()
    init(_ continuation: CheckedContinuation<Bool, Never>) { self.continuation = continuation }
    func resume(_ value: Bool) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
