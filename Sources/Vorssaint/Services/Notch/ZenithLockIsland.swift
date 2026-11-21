// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import IOKit.ps

/// Zenith fork: what the padlock island shows beyond the padlock and the
/// music: the charge, the Focus, and its greetings. Its switches are read
/// once as the lock screen appears, like the rest of the lock screen's.
final class ZenithLockIslandModel: ObservableObject {
    struct Options: Equatable {
        var charging = true
        var focus = true
        var farewell = true
        var welcome = true

        static func current(in defaults: UserDefaults = .standard) -> Options {
            Options(charging: ZenithLockScreenOption.islandCharging.isOn(in: defaults),
                    focus: ZenithLockScreenOption.islandFocus.isOn(in: defaults),
                    farewell: ZenithLockScreenOption.islandFarewell.isOn(in: defaults),
                    welcome: ZenithLockScreenOption.islandWelcome.isOn(in: defaults))
        }
    }

    @Published var options = Options()
    @Published var moment = ZenithLockIslandMoment.rest
    @Published var charging = false
    @Published var percent: Int?
    @Published var recentlyPlugged = false
    @Published var focus: String?
    @Published var firstName = ""
    /// "Locked for 2h 14m", settled as the Mac unlocks.
    @Published var detail = ""
    @Published var photo: NSImage?

    func slot(playing: Bool) -> ZenithLockIslandSlot {
        ZenithLockIsland.slot(playing: playing, charging: options.charging && charging, percent: percent,
                              recentlyPlugged: recentlyPlugged, focus: options.focus ? focus : nil)
    }
}

/// Where the island would read the Focus that is on. macOS offers apps no
/// permission-free way to read it: `INFocusStatusCenter` needs the Focus
/// status entitlement and an authorization prompt, and only says whether
/// some Focus is on, never its name; the Do Not Disturb store sits behind
/// Full Disk Access. So the island has the slot, the colour and the switch,
/// and no reader until one exists; a reader set here fills it.
enum ZenithLockIslandFocus {
    nonisolated(unsafe) static var reader: (() -> String?)?

    static func current() -> String? { reader?() }
}

/// Runs the padlock island's extras while the lock screen shows.
final class ZenithLockIslandController {
    let model = ZenithLockIslandModel()
    private var lockedAt: Date?
    private var work: [DispatchWorkItem] = []
    private var plugWork: DispatchWorkItem?
    private var sampler: PowerSampler?
    private var powerSource: CFRunLoopSource?
    private var photoRequest = 0

    /// The Mac locked at this moment: the welcome counts from here.
    func locked(at date: Date = Date()) { lockedAt = date }

    /// The lock screen appeared. Returns how long the padlock waits before it
    /// closes: as the Mac locks, the farewell holds it open.
    @discardableResult
    func begin(locking: Bool) -> TimeInterval {
        cancelWork()
        let options = ZenithLockIslandModel.Options.current()
        model.options = options
        model.moment = .rest
        model.firstName = ZenithLockIsland.firstName(fullName: NSFullUserName(), userName: NSUserName())
        model.focus = options.focus ? ZenithLockIslandFocus.current() : nil
        if options.charging { startPower() } else { stopPower() }
        if options.welcome { loadPhoto() }
        guard locking, options.farewell else { return 0.35 }
        // Shown first at rest, the island then widens on the next turn.
        schedule(after: 0.05) { [weak self] in self?.model.moment = .farewell }
        schedule(after: ZenithLockIsland.farewellHold) { [weak self] in self?.model.moment = .rest }
        return ZenithLockIsland.farewellHold
    }

    /// The Mac unlocked. Returns how long the island stays before it fades,
    /// or nil to fade as it always has.
    func unlocking(at date: Date = Date()) -> TimeInterval? {
        cancelWork()
        stopPower()
        guard model.options.welcome else { return nil }
        let language = L10n.shared.language
        let seconds = lockedAt.map { date.timeIntervalSince($0) } ?? 0
        // The island cannot count notifications while locked; it keeps only
        // those received in an unlocked session.
        model.detail = ZenithStrings.lockIsland(language)
            .detail(duration: ZenithLockIsland.duration(seconds, locale: language.formattingLocale()), notifications: nil)
        lockedAt = nil
        model.moment = .welcome
        schedule(after: ZenithLockIsland.welcomeHold) { [weak self] in self?.model.moment = .rest }
        return ZenithLockIsland.welcomeHold + ZenithLockIsland.settleAfterGreeting
    }

    /// The lock screen went away without an unlock to greet.
    func end() {
        cancelWork()
        stopPower()
        model.moment = .rest
    }

    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        work.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelWork() {
        work.forEach { $0.cancel() }
        work = []
    }

    // MARK: Power

    private func startPower() {
        guard sampler == nil, PowerSampler.hasInternalBattery else { return }
        let sampler = PowerSampler(smc: nil)
        self.sampler = sampler
        apply(sampler.sample(), plugged: false)
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            Unmanaged<ZenithLockIslandController>.fromOpaque(context).takeUnretainedValue().powerChanged()
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    private func stopPower() {
        if let source = powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        powerSource = nil
        sampler = nil
        plugWork?.cancel()
        plugWork = nil
        model.recentlyPlugged = false
        model.charging = false
        model.percent = nil
    }

    private func powerChanged() {
        guard let sampler else { return }
        let next = sampler.sample()
        apply(next, plugged: !model.charging && next.externalConnected)
    }

    private func apply(_ reading: PowerReading, plugged: Bool) {
        let connected = reading.externalConnected && reading.hasBattery
        if model.charging != connected { model.charging = connected }
        if model.percent != reading.chargePercent { model.percent = reading.chargePercent }
        guard plugged, connected else { return }
        // A charger just plugged in wins the slot for its first seconds.
        plugWork?.cancel()
        model.recentlyPlugged = true
        let item = DispatchWorkItem { [weak self] in self?.model.recentlyPlugged = false }
        plugWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + ZenithLockIsland.chargeLead, execute: item)
    }

    // MARK: Photo

    private func loadPhoto() {
        photoRequest += 1
        let request = photoRequest
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let data = ZenithLockScreenAccount.photoData()
            DispatchQueue.main.async {
                guard let self, self.photoRequest == request else { return }
                self.model.photo = data.flatMap(NSImage.init(data:))
            }
        }
    }
}
