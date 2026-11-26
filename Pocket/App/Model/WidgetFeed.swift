// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import WidgetKit

/// Keeps the widgets' file (`WidgetVault`) current from the app: the Mac's
/// state as the app hears it, this iPhone's battery and the Watch's. A
/// change the widgets would show is written at once and reloads them (at
/// most every `reloadEvery`); anything else is written at most every
/// `writeEvery`, so the freshness line stays true without a write per state.
@MainActor
final class WidgetFeed {
    static let shared = WidgetFeed()

    static let writeEvery: TimeInterval = 60
    static let reloadEvery: TimeInterval = 20

    private var snapshot: PocketWidgetSnapshot
    private var glance: String
    private var writtenAt: Date?
    private var dirty = false
    private var reloadedAt: Date?
    private var pendingReload: Task<Void, Never>?

    private init() {
        snapshot = WidgetVault.load() ?? PocketWidgetSnapshot()
        glance = PocketWidgetPresentation.glance(snapshot, now: Date())
    }

    // MARK: From the model

    func stateChanged(_ state: PocketMacState, sentAt: Date, heardAt: Date) {
        snapshot = snapshot.with(state, sentAt: sentAt, heardAt: heardAt)
        changed()
    }

    func phoneChanged(_ phone: PocketDeviceReport.Device?) {
        guard let phone, !Self.same(phone, snapshot.phone) else { return }
        snapshot.phone = phone
        changed()
    }

    func watchChanged(_ watch: PocketDeviceReport.Device?) {
        guard !Self.same(watch, snapshot.watch) || watch?.readAt != snapshot.watch?.readAt else { return }
        snapshot.watch = watch
        changed()
    }

    /// Paired anew or unpaired: the last Mac's state goes, the batteries stay.
    func pairingChanged(paired: Bool, phone: PocketDeviceReport.Device?, watch: PocketDeviceReport.Device?) {
        snapshot = PocketWidgetSnapshot(phone: phone, watch: watch)
        if paired { write() } else { WidgetVault.save(nil); writtenAt = nil; dirty = false }
        glance = PocketWidgetPresentation.glance(snapshot, now: Date())
        reload(now: true)
    }

    /// The app is leaving: what it heard last is written for the widgets.
    func flush() {
        if dirty { write() }
    }

    /// A background refresh: the Mac's box, read for the widgets.
    func refresh(_ pairing: PocketPairing, phone: PocketDeviceReport.Device?) async {
        _ = await WidgetVault.current(pairing, force: true)
        if let phone { snapshot.phone = phone }
        // Takes the box the vault just saved, when it is newer.
        write()
        let key = PocketWidgetPresentation.glance(snapshot, now: Date())
        guard key != glance else { return }
        glance = key
        reload(now: true)
    }

    // MARK: Writing

    private func changed() {
        let key = PocketWidgetPresentation.glance(snapshot, now: Date())
        let moved = key != glance
        if moved || Date().timeIntervalSince(writtenAt ?? .distantPast) >= Self.writeEvery {
            write()
        } else {
            dirty = true
        }
        if moved {
            glance = key
            reload(now: false)
        }
    }

    private func write() {
        // A widget may have read a newer box while the app was away.
        if let disk = WidgetVault.load(), let theirs = disk.mac, theirs.heardAt > snapshot.mac?.heardAt ?? .distantPast {
            snapshot.mac = theirs
            snapshot.lockedSince = disk.lockedSince
        }
        WidgetVault.save(snapshot)
        writtenAt = Date()
        dirty = false
    }

    private func reload(now: Bool) {
        let wait = Self.reloadEvery - Date().timeIntervalSince(reloadedAt ?? .distantPast)
        guard now || wait <= 0 else {
            guard pendingReload == nil else { return }
            pendingReload = Task { [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let self else { return }
                self.pendingReload = nil
                self.reloadNow()
            }
            return
        }
        reloadNow()
    }

    private func reloadNow() {
        pendingReload?.cancel(); pendingReload = nil
        reloadedAt = Date()
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }

    private static func same(_ a: PocketDeviceReport.Device?, _ b: PocketDeviceReport.Device?) -> Bool {
        a?.percent == b?.percent && a?.charging == b?.charging && a?.name == b?.name
    }
}
