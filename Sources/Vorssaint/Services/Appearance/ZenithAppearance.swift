// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Combine
import Foundation

/// Zenith fork: the island's current motion, glass and battery-saving state,
/// published for the island and Settings. Values come from
/// `ZenithAppearanceSupport`; `updatePower` is fed by the power monitor.
@MainActor
final class ZenithAppearance: ObservableObject {
    static let shared = ZenithAppearance()

    @Published private(set) var motion = IslandMotionSettings.standard
    @Published private(set) var glass = IslandGlassSettings.standard
    @Published private(set) var batterySaver = IslandBatterySaver.automatic
    /// Whether the island should drop its expensive effects right now.
    @Published private(set) var isSavingBattery = false

    private let defaults: UserDefaults
    private var lowPowerMode = false
    private var onBattery = false
    private var batteryPercent: Int?
    private var observer: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
        observer = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
    }

    /// Re-reads the preferences; publishes only what changed.
    func reload() {
        let motion = IslandMotionSettings.load(from: defaults)
        if motion != self.motion { self.motion = motion }
        let glass = IslandGlassSettings.load(from: defaults)
        if glass != self.glass { self.glass = glass }
        let saver = IslandBatterySaver.load(from: defaults)
        if saver != batterySaver { batterySaver = saver }
        updateSaving()
    }

    /// The power monitor reports Low Power Mode and the battery here.
    func updatePower(lowPowerMode: Bool, onBattery: Bool, batteryPercent: Int?) {
        self.lowPowerMode = lowPowerMode
        self.onBattery = onBattery
        self.batteryPercent = batteryPercent
        updateSaving()
    }

    private func updateSaving() {
        let saving = batterySaver.isSaving(lowPowerMode: lowPowerMode, onBattery: onBattery, batteryPercent: batteryPercent)
        if saving != isSavingBattery { isSavingBattery = saving }
    }
}
