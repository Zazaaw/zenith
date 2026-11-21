// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import IOKit.ps

// Zenith fork: presents bursts (ZenithIslandBurstSupport) as the island's own
// notice, so the island grows and shrinks back through its window host, with
// no second window over it. A capsule notice showing gives way at once
// (ZenithNoticeCenter watches the island's notice).

extension NotchService {
    /// Grows the island for `content` now. While the island is open or busy
    /// with a drag or the capture controls, a prayer's time waits for it to
    /// close, up to `ZenithBurstWaiter.prayerPatience`; a charger's moment
    /// has passed by then and is dropped.
    @discardableResult
    func showZenithBurst(_ content: ZenithIslandBurst.Content) -> Bool {
        let burst = ZenithIslandBurst(content, start: Date())
        guard ZenithIslandBurstTiming.replaces(notice?.zenith, with: burst, at: burst.start) else { return false }
        guard !expanded, !dragPlaceholder, captureControls == nil else {
            if case .prayer = content { ZenithBurstWaiter.shared.wait(content) }
            return false
        }
        ZenithBurstWaiter.shared.cancel()
        let symbol: String
        switch content {
        case .prayer(let prayer): symbol = prayer.symbol
        case .charge(let charge): symbol = charge.bolt ? "battery.100percent.bolt" : "battery.50percent"
        }
        return show(NotchNotice(event: burst.event, title: burst.title, detail: burst.subtitle, symbol: symbol,
                                zenith: burst))
    }
}

/// A prayer's burst waiting for the island to close.
final class ZenithBurstWaiter {
    static let shared = ZenithBurstWaiter()
    /// As long as the capsule used to wait for its turn.
    static let prayerPatience: TimeInterval = 120

    private var waiting: (content: ZenithIslandBurst.Content, deadline: Date)?
    private var timer: Timer?

    func wait(_ content: ZenithIslandBurst.Content) {
        waiting = (content, Date().addingTimeInterval(Self.prayerPatience))
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.retry() }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        waiting = nil
    }

    private func retry() {
        guard let waiting, waiting.deadline > Date() else { cancel(); return }
        let island = NotchService.shared
        guard !island.expanded, !island.dragPlaceholder, island.captureControls == nil else { return }
        cancel()
        island.showZenithBurst(waiting.content)
    }
}

/// Zenith fork: macOS's own time to full, from the power source's public
/// description (the battery menu's estimate). Nil while it is calculating or
/// when the Mac has no battery charging.
enum ZenithPowerEstimate {
    static func minutesToFull() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let minutes = description[kIOPSTimeToFullChargeKey] as? Int else { continue }
            return ZenithPowerFormat.minutes(TimeInterval(minutes) * 60)
        }
        return nil
    }
}
