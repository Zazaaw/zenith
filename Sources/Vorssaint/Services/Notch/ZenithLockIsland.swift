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
    /// The account's picture for the welcome, read as the Mac locks.
    @Published var photo: NSImage?
    /// Zenith fork: the padlock island's shape as it stands, set by its view:
    /// the shape the desktop island takes over from as the Mac unlocks.
    var shownSize: CGSize?
    /// Zenith fork: as the Mac locks, the shape the island first appears at
    /// (the desktop island it covers) and grows from into its opening
    /// moment. Taken by the view as it starts that motion.
    var entrance: CGSize?
    /// Zenith fork: whether the island may grow out of `entrance` now. As the
    /// Mac locks it stands at the bare notch until its window is on screen
    /// and macOS's shield has faded in; the lock screen releases it then, so
    /// the whole spring is seen, whatever face unlock shows by that time.
    @Published var entranceReleased = true
    /// Zenith fork: when the island's motion comes to rest (reference date
    /// seconds), set by its view: the unlock hands over only once it is still.
    var settlesAt: TimeInterval = 0
    /// Zenith fork: face unlock as the island shows it (FaceUnlockPresence),
    /// with the animation style read as a scan begins, and when the success
    /// animation began, so an unlock waits it out before the welcome.
    @Published var face = FaceUnlockIslandState.hidden
    @Published var faceStyle = FaceUnlockAnimationStyle.original
    var faceSuccessAt: Date?

    /// Zenith fork: what the island shows from its moment and face unlock.
    var stage: FaceUnlockIslandStage { FaceUnlockIslandStage.resolve(moment: moment, face: face) }

    func isMoving(at now: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Bool { now < settlesAt }

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
    /// Zenith fork (remote lock): the iPhone that locked the Mac, if one did.
    private var lockedFrom: String?
    private var work: [DispatchWorkItem] = []
    private var plugWork: DispatchWorkItem?
    private var sampler: PowerSampler?
    private var powerSource: CFRunLoopSource?
    private var photoRequest = 0

    /// The Mac locked at this moment: the welcome counts from here.
    func locked(at date: Date = Date()) {
        lockedAt = date
        lockedFrom = ZenithRemoteLockMark.take(at: date) // Zenith fork: an iPhone asked for this lock
    }

    /// The lock screen appeared, before its island is drawn. Returns how long
    /// the padlock waits before it closes: as the Mac locks, the farewell
    /// holds it open. Locking, the island's first frame is already its
    /// opening moment, at `start` (the desktop island it covers), growing
    /// from there; nothing at rest is drawn first.
    /// Zenith fork: locking, the island stands at `start` (the bare notch)
    /// until `releaseEntrance()`; the opening moment's hold counts from then.
    @discardableResult
    func begin(locking: Bool, from start: CGSize? = nil) -> TimeInterval {
        cancelWork()
        let options = ZenithLockIslandModel.Options.current()
        model.options = options
        model.firstName = ZenithLockIsland.firstName(fullName: NSFullUserName(), userName: NSUserName())
        model.focus = options.focus ? ZenithLockIslandFocus.current() : nil
        if options.charging { startPower() } else { stopPower() }
        if options.welcome { loadPhoto() }
        // Zenith fork: locked from an iPhone, the island says so in the farewell's
        // place, its padlock already closed (nobody is at the Mac to wave to).
        let moment = ZenithLockIsland.openingMoment(locking: locking, farewell: options.farewell,
                                                    remoteDevice: locking ? lockedFrom : nil)
        model.moment = moment
        model.entrance = locking ? start : nil
        model.entranceReleased = model.entrance == nil // Zenith fork: released by the lock screen
        if let hold = ZenithLockIsland.openingHold(moment) {
            if model.entranceReleased { scheduleOpeningHold(hold) } else { pendingHold = hold }
        }
        return ZenithLockIsland.padlockHold(moment)
    }

    /// Zenith fork: the island's window is on screen and macOS's shield has
    /// faded in: the island grows out of the notch now, into whatever it
    /// shows by then, and its opening moment starts counting.
    func releaseEntrance() {
        guard !model.entranceReleased else { return }
        model.entranceReleased = true
        if let hold = pendingHold {
            pendingHold = nil
            scheduleOpeningHold(hold)
        }
    }

    private func scheduleOpeningHold(_ hold: TimeInterval) {
        let began = Date()
        schedule(after: hold) { [weak self] in
            ZenithLockTrace.log(ZenithDesktopZoom.text("opening moment over after %.2f s (hold %.2f)",
                                                       Date().timeIntervalSince(began), hold))
            self?.model.moment = .rest
        }
    }

    /// Zenith fork: face unlock's state changed while the lock screen shows.
    /// The animation style is read as a scan begins, as Glance snapshots it
    /// per attempt, so a change mid-attempt never resizes the panel. A match
    /// holds through the unlock (FaceUnlockIslandStage.next).
    func show(face incoming: FaceUnlockIslandState, sessionLocked: Bool = true,
              style: () -> FaceUnlockAnimationStyle = { FaceUnlockIslandStyle.current() }) {
        let face = FaceUnlockIslandStage.next(current: model.face, incoming: incoming, sessionLocked: sessionLocked)
        if face != incoming { ZenithLockTrace.log("face \(incoming) ignored: the match holds into the welcome") }
        guard model.face != face else { return }
        if face == .scanning || (Self.attempting(face) && !Self.attempting(model.face)) { model.faceStyle = style() }
        model.faceSuccessAt = face == .success ? Date() : nil
        ZenithLockTrace.log("face \(model.face) -> \(face) style=\(model.faceStyle.rawValue)")
        model.face = face
    }

    /// A scan and its result: one attempt, one style.
    private static func attempting(_ face: FaceUnlockIslandState) -> Bool {
        switch face {
        case .scanning, .success, .failure: return true
        case .hidden, .armed, .needsTouchID: return false
        }
    }

    /// Zenith fork: unlocked: the welcome grows in the island itself, or with
    /// none the island draws back into the bare notch.
    /// Straight from what it shows (the success, the pill), never through the
    /// resting pill or the camera; an entrance not yet begun grows from the notch.
    func showUnlocked(_ welcome: ZenithWelcomeBurst?) {
        cancelWork()
        model.entranceReleased = true
        model.moment = welcome.map { .welcome($0) } ?? .bare
    }

    /// Zenith fork: the island draws back into the bare notch before it goes.
    func collapse() {
        cancelWork()
        model.moment = .bare
    }

    /// The Mac unlocked: the welcome, when it is on, which the padlock island
    /// grows (`showUnlocked`) and the desktop island then takes over at the
    /// same shape; `end()` resets the island once it has gone.
    func unlocking(at date: Date = Date()) -> ZenithWelcomeBurst? {
        cancelWork()
        let since = lockedAt
        let remote = lockedFrom // Zenith fork
        lockedAt = nil
        lockedFrom = nil
        guard model.options.welcome else { return nil }
        let language = L10n.shared.language
        let text = ZenithStrings.lockIsland(language)
        let seconds = since.map { date.timeIntervalSince($0) } ?? 0
        // The island cannot count notifications while locked; it keeps only
        // those received in an unlocked session.
        let detail = remote.map { RemoteText.welcomeDetail(device: $0, seconds: seconds) } // Zenith fork
            ?? text.detail(duration: ZenithLockIsland.duration(seconds, locale: language.formattingLocale()),
                           notifications: nil)
        return ZenithWelcomeBurst(title: text.welcomeBack(model.firstName), subtitle: detail, photo: model.photo,
                                  initials: ZenithLockScreenInitials.of(NSFullUserName()))
    }

    /// The lock screen went away, or its island has gone after an unlock.
    func end() {
        cancelWork()
        stopPower()
        model.moment = .rest
        model.entrance = nil
        model.entranceReleased = true // Zenith fork
        model.face = .hidden
        model.faceSuccessAt = nil
    }

    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        work.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelWork() {
        work.forEach { $0.cancel() }
        work = []
        pendingHold = nil // Zenith fork
    }

    /// Zenith fork: the opening moment's hold, waiting for the entrance.
    private var pendingHold: TimeInterval?

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
