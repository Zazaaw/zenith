// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Combine
import Foundation

/// Zenith fork: feeds ZenithLockScreenJobs from the fork's long jobs: an
/// export (ExportTrackerService), an SD card import (CardImportService), a
/// backup or a card check (CardBackupService), a long terminal command
/// (CommandActivityService) and a Vercel deployment (VercelService).
///
/// It only reads what those services already publish. Their changes, and the
/// copy meters' ten readings a second, arrive through Combine and are taken at
/// most twice a second; nothing polls. The one timer is for a finished job's
/// check, armed only while one lingers. It runs while the island runs with the
/// lock screen and its job progress on, and is synced with the island's other
/// services, so it keeps going while the Mac is locked.
final class ZenithLockScreenJobFeed {
    typealias Support = ZenithLockScreenJobFeedSupport

    static let shared = ZenithLockScreenJobFeed()

    private var subscription: AnyCancellable?
    private var state = Support.State()
    private var expiry: DispatchWorkItem?

    private init() {}

    /// Called with every island preference sync, the lock screen's switches included.
    func syncWithPreferences() {
        guard NotchLockScreenSupport.isEnabled(), ZenithLockScreenOption.jobs.isOn() else {
            stop()
            return
        }
        if subscription == nil { subscribe() }
        refresh()
    }

    /// The island stopped, or the lock screen or its jobs went off.
    func stop() {
        subscription = nil
        expiry?.cancel()
        expiry = nil
        state = Support.State()
        publish([])
    }

    private func subscribe() {
        let cards = CardImportService.shared
        let backups = CardBackupService.shared
        let changes: [AnyPublisher<Void, Never>] = [
            ExportTrackerService.shared.$activity.map { _ in () }.eraseToAnyPublisher(),
            cards.$session.map { _ in () }.eraseToAnyPublisher(),
            cards.meter.$progress.map { _ in () }.eraseToAnyPublisher(),
            backups.$runs.map { _ in () }.eraseToAnyPublisher(),
            backups.$results.map { _ in () }.eraseToAnyPublisher(),
            backups.meter.$progress.map { _ in () }.eraseToAnyPublisher(),
            CommandActivityService.shared.$activity.map { _ in () }.eraseToAnyPublisher(),
            VercelService.shared.$deployments.map { _ in () }.eraseToAnyPublisher(),
            L10n.shared.$language.map { _ in () }.eraseToAnyPublisher(),
        ]
        // @Published tells before the value changes, so the read waits a turn.
        subscription = Publishers.MergeMany(changes)
            .receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.refresh() }
    }

    private func refresh() {
        guard subscription != nil else { return }
        let now = Date()
        let jobs = state.update(inputs(), now: now) { $0.isOn() }
        publish(jobs)
        scheduleExpiry(after: now)
    }

    private func publish(_ jobs: [ZenithLockScreenJob]) {
        let shared = ZenithLockScreenJobs.shared
        if shared.items != jobs { shared.items = jobs }
    }

    /// Wakes once for the next finished job to go, and not at all otherwise.
    private func scheduleExpiry(after now: Date) {
        expiry?.cancel()
        expiry = nil
        guard let due = state.nextExpiry else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.expiry = nil
            self?.refresh()
        }
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, due.timeIntervalSince(now)) + 0.05, execute: work)
    }

    // MARK: Sources

    private func inputs() -> [Support.Input] {
        let text = ZenithStrings.lockScreenSettings(L10n.shared.language)
        var inputs: [Support.Input] = []
        if let export = Support.export(ExportTrackerService.shared.activity, fallback: text.labelExport) {
            inputs.append(export)
        }
        if let card = cardImport(text: text) { inputs.append(card) }
        inputs += backups(text: text)
        if let command = Support.command(CommandActivityService.shared.activity) { inputs.append(command) }
        inputs += Support.vercel(VercelService.shared.deployments)
        return inputs
    }

    private func cardImport(text: ZenithLockScreenSettingsStrings) -> Support.Input? {
        let service = CardImportService.shared
        guard let session = service.session else { return nil }
        let stage: Support.Stage
        switch session.phase {
        case .preparing: stage = .preparing
        case .copying: stage = .copying
        case .finished: stage = .finished
        case .failed: stage = .failed
        }
        return Support.copy(id: "import:\(session.cardID):\(session.folder.path)", source: .cardImport,
                            label: text.labelImport, stage: stage, progress: service.meter.progress)
    }

    /// The backup or check under way, and how the earlier ones ended: the
    /// state lets a result through only for a run it saw under way.
    private func backups(text: ZenithLockScreenSettingsStrings) -> [Support.Input] {
        let service = CardBackupService.shared
        func input(_ run: CardBackupRun, progress: CardImportProgress) -> Support.Input? {
            let stage: Support.Stage
            switch run.phase {
            case .waiting: return nil
            case .running: stage = .copying
            case .finished: stage = .finished
            case .failed: stage = .failed
            }
            let id: String
            switch run.kind {
            case .backup(let destination, _): id = "backup:\(run.record):\(destination)"
            case .card(let card): id = "check:\(run.record):\(card)"
            }
            return Support.copy(id: id, source: .backup, label: run.isCardCheck ? text.labelCheck : text.labelBackup,
                                stage: stage, progress: progress)
        }
        let running = service.runs.compactMap { input($0, progress: service.meter.progress) }
        let ended = service.results.values.compactMap { input($0, progress: CardImportProgress()) }
        return running + ended
    }
}
