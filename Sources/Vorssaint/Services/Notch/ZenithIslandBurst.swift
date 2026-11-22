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
        // A burst never stacks over an open page: it waits for the island to
        // close, as long as it is worth waiting for, or is dropped.
        guard !expanded, !dragPlaceholder, captureControls == nil else {
            let patience = ZenithIslandBurstTiming.patience(content)
            if patience > 0 { ZenithBurstWaiter.shared.wait(content, patience: patience) }
            return false
        }
        ZenithBurstWaiter.shared.cancel()
        let symbol: String
        switch content {
        case .prayer(let prayer): symbol = prayer.symbol
        case .charge(let charge): symbol = charge.bolt ? "battery.100percent.bolt" : "battery.50percent"
        case .welcome: symbol = "lock.open.fill"
        case .agent: symbol = "exclamationmark.bubble.fill"
        case .remote: symbol = "iphone"
        }
        return show(NotchNotice(event: burst.event, title: burst.title, detail: burst.subtitle, symbol: symbol,
                                zenith: burst))
    }
}

/// Zenith fork: the lock screen's padlock pill handing over to the island as
/// the Mac unlocks, so the two read as one island: the island comes back at
/// the pill's frame and shape and grows into the welcome from there, and the
/// pill's window goes the moment the island is on screen beneath it.
struct ZenithLockHandoff {
    /// The pill as it stands, centred on the camera.
    let size: CGSize
    /// What the pill shows, drawn at `size`: the island's first frame shows
    /// it too, then lets it go as the welcome rides in, so the cross-over
    /// changes nothing on screen.
    var look: NSImage?
    let welcome: ZenithWelcomeBurst
    /// The island is on screen at the pill's frame: the pill goes now.
    let handedOver: () -> Void
    /// The island cannot take over (hidden, in full screen, open, or not
    /// back in time): the pill fades over it as it used to, and the welcome
    /// comes as an ordinary burst if the island can show one.
    let declined: () -> Void
}

/// A prayer's burst waiting for the island to close.
final class ZenithBurstWaiter {
    static let shared = ZenithBurstWaiter()
    /// As long as the capsule used to wait for its turn.
    static let prayerPatience: TimeInterval = 120

    private var waiting: (content: ZenithIslandBurst.Content, deadline: Date)?
    private var timer: Timer?

    func wait(_ content: ZenithIslandBurst.Content, patience: TimeInterval = prayerPatience) {
        waiting = (content, Date().addingTimeInterval(patience))
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
