// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import Combine
import Foundation

/// Zenith fork: the island's side of Batteries. It takes each low-battery
/// alert the monitor leaves in BatteriesStore, grows the island into the
/// droplet's Battery Low card for five seconds (ZenithIslandBurst), and keeps
/// the compact form in the closed island afterwards (the device's symbol, a
/// red battery and its level) until the device charges or recovers, the
/// Batteries page opens, or a few minutes pass. It also tells the store
/// whether the page or its Home widget is on screen.
final class BatteriesIslandService: ObservableObject {
    static let shared = BatteriesIslandService()

    /// The compact form, while it stands.
    @Published private(set) var indicator: BatteriesLowIndicator?

    private let store = BatteriesStore.shared
    private var subscriptions: Set<AnyCancellable> = []
    private var expiry: DispatchWorkItem?
    /// How many of the page and the widget are on screen.
    private var visibleCount = 0

    private init() {}

    private var text: ZenithBatteriesIslandStrings { ZenithStrings.batteriesIsland(L10n.shared.language) }

    // MARK: Life

    /// Batteries' own switch is read as each alert comes, so turning it off
    /// in Settings needs no call here; the island's switch stops it all.
    func syncWithPreferences() {
        guard NotchSupport.isEnabled() else { stop(); return }
        if !BatteriesIslandSupport.isEnabled() { clearIndicator() }
        guard subscriptions.isEmpty else { return }
        store.$pendingLowAlert
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alert in self?.present(alert) }
            .store(in: &subscriptions)
        store.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in self?.follow(devices) }
            .store(in: &subscriptions)
    }

    func stop() {
        subscriptions.removeAll()
        clearIndicator()
    }

    // MARK: Alerts

    private func present(_ alert: BatteriesLowAlert) {
        // Taken once, whether or not the island can show it now.
        if store.pendingLowAlert?.id == alert.id { store.pendingLowAlert = nil }
        guard NotchSupport.isEnabled(), BatteriesIslandSupport.isEnabled() else { return }
        let burst = BatteriesIslandSupport.lowBurst(alert, text: text)
        setIndicator(BatteriesLowIndicator(deviceID: burst.deviceID, name: burst.name, symbol: burst.symbol,
                                           percent: burst.percent, since: Date()))
        // Over a closed island it grows now; an open one shows the compact
        // form once it closes, and the card if it closes soon enough.
        NotchService.shared.showZenithBurst(.batteryLow(burst))
    }

    private func follow(_ devices: [BatteryDevice]) {
        guard let indicator else { return }
        let device = devices.first { $0.id == indicator.deviceID }
        let threshold = BatteriesIslandSupport.threshold()
        guard BatteriesIslandSupport.indicatorStands(indicator, device: device, threshold: threshold, now: Date()) else {
            clearIndicator()
            return
        }
        let next = BatteriesIslandSupport.updated(indicator, device: device)
        if next != indicator { self.indicator = next }
    }

    private func setIndicator(_ next: BatteriesLowIndicator) {
        indicator = next
        expiry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.clearIndicator() }
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + BatteriesIslandSupport.compactLinger, execute: work)
    }

    private func clearIndicator() {
        expiry?.cancel()
        expiry = nil
        if indicator != nil { indicator = nil }
    }

    // MARK: On screen

    /// The page or its widget appeared. The page answers the compact form.
    func shown(page: Bool) {
        if page { clearIndicator() }
        visibleCount += 1
        if visibleCount == 1 { store.setVisible(true) }
    }

    func hidden() {
        guard visibleCount > 0 else { return }
        visibleCount -= 1
        if visibleCount == 0 { store.setVisible(false) }
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension BatteriesIslandService {
    func catalogPose(indicator: BatteriesLowIndicator?) {
        expiry?.cancel()
        expiry = nil
        self.indicator = indicator
    }
}
#endif
