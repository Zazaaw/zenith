// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import EventKit

/// EventKit objects stay on one actor; only the meetings found leave it.
private actor MeetingsCalendarReader {
    private lazy var store = EKEventStore()

    func read(interval: DateInterval, excluded: Set<String>, providers: Set<MeetingProvider>,
              now: Date) -> [Meeting] {
        guard !Task.isCancelled, EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let calendars = NotchCalendarSupport.calendarsToRead(store.calendars(for: .event), excluded: excluded,
                                                             identifier: \.calendarIdentifier)
        if calendars?.isEmpty == true { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        let candidates: [MeetingCandidate] = store.events(matching: predicate).compactMap { event in
            guard event.status != .canceled,
                  event.attendees?.contains(where: { $0.isCurrentUser && $0.participantStatus == .declined }) != true,
                  let identifier = event.eventIdentifier,
                  let start = event.startDate, let end = event.endDate else { return nil }
            return MeetingCandidate(id: identifier + ":" + String(start.timeIntervalSinceReferenceDate),
                                    title: event.title ?? "", start: start, end: end, allDay: event.isAllDay,
                                    url: event.url, location: event.location, notes: event.notes)
        }
        return MeetingSchedule.meetings(candidates, providers: providers, now: now)
    }
}

/// Zenith fork: Meetings. Runs only while the island runs and Meetings is on
/// in Settings. It reads today's events from the calendars the island's
/// Calendar reads, with the access that Calendar asked for (it never asks
/// itself), whenever they change, the day turns or the Mac wakes. Between
/// reads one timer waits for the next moment anything changes (a lead
/// begins, a meeting ends, midnight); nothing polls. Only while a meeting is
/// near or a call is live does it listen to the microphone and the cameras
/// (MeetingsDeviceMonitor). No event text is stored; the notices already
/// shown are kept by occurrence only. Used on the main thread, as the
/// island's other services are.
final class MeetingsService: ObservableObject {
    static let shared = MeetingsService()

    /// The live call, while the strip is on; what the closed island shows.
    @Published private(set) var call: MeetingCall?
    /// A camera on during the call.
    @Published private(set) var cameraInUse = false

    private var running = false
    private var settings = MeetingsSettings.current()
    private var excluded = Set<String>()
    private var meetings: [Meeting] = []
    private var reader: MeetingsCalendarReader?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var permissionSubscription: AnyCancellable?
    private var tracker = MeetingCallTracker()
    private let devices = MeetingsDeviceMonitor()
    private var micInUse = false

    private init() {
        devices.onChange = { [weak self] mic, camera in
            guard let self, self.running else { return }
            self.micInUse = mic
            if self.cameraInUse != camera { self.cameraInUse = camera }
            self.update(now: Date())
        }
    }

    private var text: ZenithMeetingsStrings { ZenithStrings.meetings(L10n.shared.language) }

    // MARK: Lifecycle

    /// With every island preference sync, and from Settings → Meetings.
    func syncWithPreferences() {
        let settings = MeetingsSettings.current()
        let excluded = NotchCalendarSupport.excludedCalendars()
        let wanted = settings.enabled && NotchSupport.isEnabled() && NotchService.shared.running
        guard wanted else { stop(); return }
        let changed = settings != self.settings || excluded != self.excluded
        self.settings = settings
        self.excluded = excluded
        if !running {
            running = true
            reader = MeetingsCalendarReader()
            observe()
            refresh()
        } else if changed {
            refresh()
        }
    }

    /// The island stopped, or Meetings was turned off: nothing keeps running.
    func stop() {
        guard running || timer != nil || call != nil else { return }
        running = false
        generation += 1
        task?.cancel(); task = nil
        timer?.invalidate(); timer = nil
        unobserve()
        reader = nil
        meetings = []
        tracker.reset()
        micInUse = false
        devices.setWatching(false)
        if call != nil { call = nil }
        if cameraInUse { cameraInUse = false }
    }

    private func observe() {
        unobserve()
        let center = NotificationCenter.default
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged, .NSSystemTimeZoneDidChange,
                     .NSSystemClockDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
        // The calendars picked in Settings, shared with the island's Calendar.
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            guard let self, self.running else { return }
            let settings = MeetingsSettings.current(), excluded = NotchCalendarSupport.excludedCalendars()
            guard settings != self.settings || excluded != self.excluded else { return }
            self.syncWithPreferences()
        })
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        permissionSubscription = Permissions.shared.$calendarAccess.removeDuplicates().dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    private func unobserve() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
        permissionSubscription = nil
    }

    // MARK: Reading

    private func refresh() {
        guard running, let reader else { return }
        task?.cancel()
        generation += 1
        let requested = generation
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            meetings = []
            update(now: Date())
            return
        }
        let now = Date()
        let interval = MeetingSchedule.readInterval(now: now)
        let excluded = excluded, providers = settings.enabledProviders
        task = Task { @MainActor [weak self] in
            let found = await reader.read(interval: interval, excluded: excluded, providers: providers, now: now)
            guard !Task.isCancelled, let self, self.running, self.generation == requested else { return }
            self.meetings = found
            self.task = nil
            self.update(now: Date())
        }
    }

    // MARK: Time

    /// Everything that follows from the meetings and the microphone at
    /// `now`: the notices due, whether to listen, the call, and the timer.
    private func update(now: Date) {
        timer?.invalidate(); timer = nil
        guard running else { return }
        let lead = settings.lead
        let meetings = self.meetings.filter { $0.end > now || $0.id == tracker.call?.meeting.id }

        let due = MeetingSchedule.noticesDue(meetings, now: now, lead: lead, noticed: MeetingsNoticeLog.noticed())
        if !due.isEmpty {
            MeetingsNoticeLog.record(due, now: now)
            for meeting in due { announce(meeting, now: now) }
        }

        let live = tracker.update(meetings: meetings, now: now, lead: lead, micInUse: micInUse)
        let near = MeetingSchedule.focus(meetings, now: now, lead: lead) != nil || live != nil
        devices.setWatching(near)
        if !near {
            micInUse = false
            if cameraInUse { cameraInUse = false }
        }
        let shown = settings.showsStrip ? live : nil
        if call != shown { call = shown }

        var next = MeetingSchedule.nextWake(meetings, now: now, lead: lead)
        if let check = tracker.nextCheck(now: now) { next = min(next, check) }
        let timer = Timer(fire: max(next, now.addingTimeInterval(0.5)), interval: 0, repeats: false) { [weak self] _ in
            self?.update(now: Date())
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func announce(_ meeting: Meeting, now: Date) {
        let language = L10n.shared.language
        ZenithNoticeCenter.shared.meetingSoon(
            id: meeting.id, title: MeetingsFormat.title(meeting, text: text),
            subtitle: MeetingsFormat.noticeSubtitle(meeting, now: now, text: text, locale: language.formattingLocale()),
            symbol: meeting.provider.symbol, tint: meeting.provider.tint, join: text.join)
    }

    // MARK: Actions

    /// Join, from the notice: opens the call where it belongs and counts the
    /// meeting as joined, so its strip shows before the call app opens the mic.
    func join(_ id: String) {
        guard let meeting = meetings.first(where: { $0.id == id }) else { return }
        let workspace = NSWorkspace.shared
        switch MeetingLinkParser.launch(meeting.link, installed: { workspace.urlForApplication(withBundleIdentifier: $0) != nil }) {
        case .open(let url):
            if !workspace.open(url) { NSSound.beep(); return }
        case .openWith(let url, let bundleID):
            guard let app = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
                if !workspace.open(url) { NSSound.beep() }
                return
            }
            workspace.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        }
        tracker.join(meeting, at: Date())
        update(now: Date())
    }

    /// A click on the strip: the call's app forward, or the island's Calendar
    /// for a call in a browser.
    func focusCall() {
        guard let call else { return }
        for bundleID in call.meeting.provider.appBundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                app.activate()
                return
            }
        }
        NotchService.shared.openActivity(.calendar)
    }

    /// Whether the strip offers mute: Mic Mute, the switch it goes through, is on.
    var offersMute: Bool { AppFeature.micMute.isAvailable }

    func toggleMute() {
        guard offersMute else { return }
        MicMuteService.shared.toggle()
    }
}
