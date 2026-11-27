// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

/// Zenith fork: keeps `IslandMotion.current` in step with Settings →
/// Appearance, the battery saver and Reduce Motion, and tells the agents'
/// loops when the saver comes or goes. A change takes effect with the next
/// animation: nothing restarts.
@MainActor
final class IslandMotionLive {
    static let shared = IslandMotionLive()

    private var subscriptions: Set<AnyCancellable> = []

    func start() {
        guard subscriptions.isEmpty else { return }
        let appearance = ZenithAppearance.shared
        appearance.$motion.combineLatest(appearance.$isSavingBattery)
            .sink { [weak self] motion, saving in self?.apply(settings: motion, saving: saving) }
            .store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.apply(settings: appearance.motion, saving: appearance.isSavingBattery)
            }
            .store(in: &subscriptions)
    }

    private func apply(settings: IslandMotionSettings, saving: Bool) {
        let motion = IslandMotion(settings: settings,
                                  reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                                  savingBattery: saving)
        if motion != IslandMotion.current { IslandMotion.current = motion }
        IslandAgentMotionGate.shared.update(savingBattery: saving)
    }
}
