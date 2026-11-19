// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import EventKit

/// EventKit objects stay on one actor; only titles and due dates leave it.
private actor RemindersReader {
    private lazy var store = EKEventStore()

    func read(before end: Date) async -> [RemindersSupport.Item]? {
        guard !Task.isCancelled,
              LockScreenWidgetAccess(reminders: EKEventStore.authorizationStatus(for: .reminder)) == .granted else { return nil }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let calendar = Calendar.current
                let items = (reminders ?? []).compactMap {
                    RemindersSupport.item(id: $0.calendarItemIdentifier, title: $0.title, due: $0.dueDateComponents,
                                          completed: $0.isCompleted, calendar: calendar)
                }
                continuation.resume(returning: items)
            }
        }
    }
}

/// Zenith fork: reminders due today or overdue, for the lock screen.
///
/// Access is asked for only when the lock screen's Reminders switch is turned
/// on. Reminders are read when the lock screen shows, again whenever the
/// reminders database changes, and every 30 minutes while it stays (a day can
/// turn). Nothing is read otherwise, and nothing is written or kept on disk.
@MainActor
final class RemindersService: ObservableObject {
    static let shared = RemindersService()

    /// Incomplete reminders due before tomorrow, as last read.
    @Published private(set) var items: [RemindersSupport.Item] = []
    @Published private(set) var access: LockScreenWidgetAccess

    private var reader: RemindersReader?
    private var task: Task<Void, Never>?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var requesting = false

    private init() {
        access = LockScreenWidgetAccess(reminders: EKEventStore.authorizationStatus(for: .reminder))
    }

    // MARK: Permission

    /// Reads the current status; never prompts.
    @discardableResult
    func refreshAccess() -> LockScreenWidgetAccess {
        let current = LockScreenWidgetAccess(reminders: EKEventStore.authorizationStatus(for: .reminder))
        if access != current { access = current }
        if current != .granted { items = [] }
        return current
    }

    /// Asks macOS once, when the person turns Reminders on. Afterwards only
    /// System Settings can change the answer.
    func requestAccess() {
        guard !requesting, refreshAccess() == .notDetermined else { return }
        requesting = true
        let store = EKEventStore()
        store.requestFullAccessToReminders { [weak self, store] _, _ in
            _ = store
            Task { @MainActor [weak self] in
                self?.requesting = false
                self?.refreshAccess()
            }
        }
    }

    func openRemindersSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Lock screen

    func lockScreenShown() {
        guard refreshAccess() == .granted else { return }
        if reader == nil { reader = RemindersReader() }
        if observers.isEmpty {
            for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged, .NSSystemTimeZoneDidChange] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in MainActor.assumeIsolated { self?.refresh() }
                })
            }
        }
        if timer == nil {
            let timer = Timer(timeInterval: RemindersSupport.refreshInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = 60
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        refresh()
    }

    func lockScreenHidden() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
    }

    private func refresh() {
        task?.cancel()
        guard let reader, refreshAccess() == .granted else { return }
        let end = RemindersSupport.readEnd(now: Date(), calendar: .current)
        task = Task { [weak self] in
            let result = await reader.read(before: end)
            guard let self, !Task.isCancelled else { return }
            self.task = nil
            self.items = result ?? []
        }
    }
}
