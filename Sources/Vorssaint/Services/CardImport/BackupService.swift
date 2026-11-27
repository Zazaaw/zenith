// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

// Zenith fork: verified backups of card imports. Every import lands in the
// backup ledger as "imported only"; a backup copies the event folder onto a
// backup drive (one or two, known by their volume identity wherever they
// mount) and, when asked, compares every file by hash, writing a manifest.
// A card can also be checked against what came off it before it is
// formatted, which this never does itself: "safe to format" is only words.
// Runs one job at a time off the main thread; the main thread reads it ten
// times a second for the page and the closed island, as a card import does.

/// The progress of the backup or check under way, on its own so its readings
/// redraw only the views that show them.
final class CardBackupMeter: ObservableObject {
    @Published fileprivate(set) var progress = CardImportProgress()
}

/// A backup or a check of one event: under way, or how it ended.
struct CardBackupRun: Equatable {
    enum Kind: Equatable {
        /// Onto a destination, by its id, with its drive's name.
        case backup(destination: String, drive: String)
        /// A card, by its volume key, against the event folder.
        case card(String)
    }

    enum Phase: Equatable {
        case waiting
        case running(CardBackupStage)
        /// `verified` when every file was compared and matched.
        case finished(files: Int, bytes: Int64, verified: Bool)
        case failed(CardBackupFailure)
    }

    let record: String
    let kind: Kind
    var phase = Phase.waiting
    /// A backup compares its files once copied.
    var verifies = true
    var mismatches: [CardBackupMismatch] = []

    var isActive: Bool {
        switch phase {
        case .waiting, .running: return true
        default: return false
        }
    }

    var isCardCheck: Bool { if case .card = kind { return true } else { return false } }
}

final class CardBackupService: ObservableObject {
    static let shared = CardBackupService()

    @Published private(set) var ledger = CardBackupLedger()
    /// Mounted volumes, to know which destinations are here.
    @Published private(set) var volumes: [CardBackupVolume] = []
    /// What runs now and what waits, in order.
    @Published private(set) var runs: [CardBackupRun] = []
    /// How the last backup of each event and the last check of each card ended.
    @Published private(set) var results: [String: CardBackupRun] = [:]
    /// The page shows the list of events and their safety.
    @Published var showsList = false
    let meter = CardBackupMeter()

    private var watching = false
    private var loaded = false
    private var observers: [NSObjectProtocol] = []
    private let queue = DispatchQueue(label: "com.vorssaint.zenith.card-backup", qos: .utility)
    private var job: CardBackupJob?
    private var started = Date()
    private var poll: Timer?
    private var reminderTimer: Timer?
    private var rate = CardImportRate()
    private var stage: CardBackupStage?
    private var activityWork: DispatchWorkItem?

    private init() {}

    private var text: ZenithCardBackupStrings { ZenithStrings.cardBackup(L10n.shared.language) }
    private var settings: CardBackupSettings { CardBackupSettings.current() }
    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    static var folder: URL? { CardImportService.ledgerFolder }
    private static var pairsFolder: URL? { folder?.appendingPathComponent("BackupPairs", isDirectory: true) }

    // MARK: Lifecycle

    /// With the card import's sync: watches drives mount and keeps the reminder's timer.
    func syncWithPreferences() {
        if !loaded { loadLedger() }
        guard !watching else {
            scheduleReminder()
            return
        }
        watching = true
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { note in
                let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                CardBackupService.shared.refreshVolumes(mounted: url)
            },
            center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { _ in
                CardBackupService.shared.refreshVolumes(mounted: nil)
            },
        ]
        refreshVolumes(mounted: nil)
        scheduleReminder()
    }

    /// Detection off or the island stopped. A backup under way finishes.
    func stop() {
        guard watching else { return }
        watching = false
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
        reminderTimer?.invalidate()
        reminderTimer = nil
    }

    /// Settings changed the destinations or the reminder.
    func settingsChanged() {
        objectWillChange.send()
        refreshVolumes(mounted: nil)
        scheduleReminder()
    }

    // MARK: Ledger

    private func loadLedger() {
        loaded = true
        guard let folder = Self.folder else { return }
        queue.async {
            let ledger = CardBackupLedger.load(folder: folder)
            DispatchQueue.main.async {
                let service = CardBackupService.shared
                // Imports recorded before the file was read are newer.
                var merged = ledger
                for record in service.ledger.records where merged.record(record.id) == nil {
                    merged = CardBackupLedger(records: merged.records + [record])
                }
                let wroteEarlier = !service.ledger.records.isEmpty
                service.ledger = merged
                // A save made before the file was read held only the newer imports.
                if wroteEarlier { service.saveLedger() }
                service.scheduleReminder()
            }
        }
    }

    private func saveLedger() {
        guard let folder = Self.folder, let data = ledger.encoded() else { return }
        queue.async {
            guard PrivateFileStore.createDirectory(at: folder) else { return }
            PrivateFileStore.write(data, to: folder.appendingPathComponent(CardBackupLedger.fileName, isDirectory: false))
        }
    }

    private func change(_ body: (inout CardBackupLedger) -> Void) {
        var next = ledger
        body(&next)
        guard next != ledger else { return }
        let kept = Set(next.records.map(\.id))
        let gone = ledger.records.map(\.id).filter { !kept.contains($0) }
        ledger = next
        saveLedger()
        if !gone.isEmpty, let folder = Self.pairsFolder {
            queue.async {
                for id in gone {
                    try? FileManager.default.removeItem(at: folder.appendingPathComponent(CardBackupPairs.fileName(record: id)))
                }
            }
        }
    }

    /// The records the page lists, newest first.
    var records: [CardBackupRecord] { ledger.newestFirst }

    /// Events without a verified backup, newest first.
    var pending: [CardBackupRecord] { ledger.pending }

    func record(_ id: String?) -> CardBackupRecord? { id.flatMap { ledger.record($0) } }

    // MARK: Imports

    /// A card import put files into an event folder. Returns its record. With
    /// automatic backup on and the import complete, the backup starts.
    @discardableResult
    func importFinished(folder: URL, card: String, cardName: String, pairs: [CardBackupPair], completed: Bool) -> String {
        if !loaded { loadLedger() }
        var id = ""
        change {
            id = $0.recordImport(folder: CardImportDestination.stored(folder), event: folder.lastPathComponent,
                                 card: card, cardName: cardName, files: pairs.count,
                                 bytes: pairs.reduce(0) { $0 + $1.size }, at: Date())
        }
        results[id] = nil
        results[Self.checkKey(id, card: card)] = nil
        if let folder = Self.pairsFolder {
            let record = id
            queue.async {
                guard PrivateFileStore.createDirectory(at: folder) else { return }
                let url = folder.appendingPathComponent(CardBackupPairs.fileName(record: record), isDirectory: false)
                let known = (try? Data(contentsOf: url)).map(CardBackupPairs.decode) ?? [:]
                if let data = CardBackupPairs.encode(CardBackupPairs.merging(pairs, card: card, into: known)) {
                    PrivateFileStore.write(data, to: url)
                }
            }
        }
        if completed, settings.automatic, !mountedDestinations.isEmpty { backUp(id) }
        scheduleReminder()
        return id
    }

    // MARK: Destinations

    var destinations: [CardBackupDestination] { settings.destinations }

    /// Destinations whose drive is mounted, with where they are now.
    var mountedDestinations: [(destination: CardBackupDestination, folder: URL)] {
        destinations.compactMap { destination in destination.folder(in: volumes).map { (destination, $0) } }
    }

    func isMounted(_ destination: CardBackupDestination) -> Bool { destination.mountedVolume(in: volumes) != nil }

    enum AddResult: Equatable { case added, sameDrive, card, full, unreadable }

    /// A folder the person chose becomes a destination, unless it sits on the
    /// imports' own drive or on a camera card.
    func addDestination(folder: URL) -> AddResult {
        let list = destinations
        guard list.count < CardBackupDestinations.maximum else { return .full }
        guard let volume = Self.volume(containing: folder) else { return .unreadable }
        if !CardDetection.markers(in: volume.url).isEmpty { return .card }
        if let imports = Self.volume(containing: Self.existingAncestor(of: CardImportService.baseFolder)),
           imports.key == volume.key { return .sameDrive }
        guard let destination = CardBackupDestination.make(folder: folder, on: volume) else { return .unreadable }
        let next = CardBackupDestinations.adding(destination, to: list)
        UserDefaults.standard.set(CardBackupDestinations.encode(next), forKey: DefaultsKey.notchCardBackupDestinations)
        settingsChanged()
        return .added
    }

    func removeDestination(_ id: String) {
        let next = destinations.filter { $0.id != id }
        UserDefaults.standard.set(CardBackupDestinations.encode(next), forKey: DefaultsKey.notchCardBackupDestinations)
        settingsChanged()
    }

    // MARK: Volumes

    private func refreshVolumes(mounted: URL?) {
        queue.async {
            let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil,
                                                             options: [.skipHiddenVolumes]) ?? []
            let found = urls.compactMap(Self.identity(ofVolume:))
            let arrived = mounted.flatMap { url in found.first { $0.url.standardizedFileURL == url.standardizedFileURL } }
            DispatchQueue.main.async { CardBackupService.shared.volumesRead(found, arrived: arrived) }
        }
    }

    private func volumesRead(_ found: [CardBackupVolume], arrived: CardBackupVolume?) {
        if found != volumes { volumes = found }
        guard let arrived, watching, destinations.contains(where: { $0.volume == arrived.key }) else { return }
        driveArrived(arrived)
    }

    /// A backup drive came back while events wait for it: backed up at
    /// once with automatic backup on, otherwise offered in a notice.
    private func driveArrived(_ volume: CardBackupVolume) {
        let waiting = pending
        guard !waiting.isEmpty else { return }
        existing(waiting) { present in
            guard !present.isEmpty else { return }
            let service = CardBackupService.shared
            if service.settings.automatic {
                service.backUp(present.map(\.id))
            } else {
                service.announce(present, subtitle: CardImportFormat.filling(service.text.driveConnected, volume.name))
            }
        }
    }

    /// The volume a folder is on, as the backup knows volumes.
    static func volume(containing folder: URL) -> CardBackupVolume? {
        guard let root = (try? folder.resourceValues(forKeys: [.volumeURLKey]))?.volume else { return nil }
        return identity(ofVolume: root)
    }

    private static func identity(ofVolume url: URL) -> CardBackupVolume? {
        let keys: Set<URLResourceKey> = [.volumeUUIDStringKey, .volumeURLForRemountingKey, .volumeLocalizedNameKey,
                                         .volumeTotalCapacityKey, .volumeIsLocalKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let name = values.volumeLocalizedName ?? url.lastPathComponent
        let uuid = values.volumeUUIDString ?? (values.volumeIsLocal == true ? CardImportService.diskArbitrationUUID(of: url) : nil)
        let key = CardBackupVolumeIdentity.key(uuid: uuid, remountURL: values.volumeURLForRemounting, name: name,
                                               capacity: values.volumeTotalCapacity)
        return CardBackupVolume(key: key, name: name, url: url)
    }

    private static func existingAncestor(of url: URL) -> URL {
        var probe = url
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
        return probe
    }

    // MARK: Running

    /// Backs up an event to every mounted destination.
    func backUp(_ id: String) { backUp([id]) }

    /// `verify` compares the files even with Verify after backup off, as the
    /// Verify button of a copy that was never compared asks.
    func backUp(_ ids: [String], verify: Bool = false) {
        let targets = mountedDestinations
        guard !targets.isEmpty else { return }
        for id in ids where ledger.record(id) != nil {
            for target in targets {
                let kind = CardBackupRun.Kind.backup(destination: target.destination.id, drive: target.destination.volumeName)
                guard !runs.contains(where: { $0.record == id && $0.kind == kind }) else { continue }
                runs.append(CardBackupRun(record: id, kind: kind, verifies: verify || settings.verify))
                results[id] = nil
            }
        }
        pump()
    }

    /// Every event without a verified backup.
    func backUpPending() {
        existing(pending) { present in CardBackupService.shared.backUp(present.map(\.id)) }
    }

    /// The card, still in the Mac, against what came off it into the event.
    func checkCard(_ card: String, record id: String) {
        guard canCheckCard(card, record: id),
              !runs.contains(where: { $0.record == id && $0.kind == .card(card) }) else { return }
        runs.append(CardBackupRun(record: id, kind: .card(card)))
        results[Self.checkKey(id, card: card)] = nil
        pump()
    }

    func canCheckCard(_ card: String, record id: String) -> Bool {
        ledger.record(id)?.card(card) != nil
            && CardImportService.shared.cards.contains { $0.id == card && $0.scan != nil }
    }

    /// Stops what runs and drops what waits. What was copied stays.
    func stopAll() {
        runs.removeAll { $0.phase == .waiting }
        job?.cancel()
    }

    /// The run of an event under way or waiting, if any.
    func activeRun(_ id: String?, cardCheck: Bool = false) -> CardBackupRun? {
        runs.first { $0.record == id && $0.isCardCheck == cardCheck }
    }

    func backupResult(_ id: String?) -> CardBackupRun? { id.flatMap { results[$0] } }

    func checkResult(_ id: String?, card: String) -> CardBackupRun? { id.flatMap { results[Self.checkKey($0, card: card)] } }

    private static func checkKey(_ id: String, card: String) -> String { id + "|card|" + card }

    private func pump() {
        guard job == nil, let index = runs.firstIndex(where: { $0.phase == .waiting }) else { return }
        let run = runs[index]
        guard let record = ledger.record(run.record) else {
            runs.remove(at: index)
            return pump()
        }
        let source = CardImportDestination.baseURL(stored: record.folder)
        let job: CardBackupJob
        switch run.kind {
        case let .backup(id, _):
            guard let target = mountedDestinations.first(where: { $0.destination.id == id }) else {
                end(run, phase: .failed(.driveRemoved))
                return pump()
            }
            job = CardBackupJob(source: source, destination: target.folder.appendingPathComponent(source.lastPathComponent,
                                                                                                  isDirectory: true))
            let verify = run.verifies, event = record.event, stored = record.folder
            Task.detached(priority: .utility) { job.runBackup(event: event, sourceName: stored, verify: verify) }
        case .card(let card):
            guard let mounted = CardImportService.shared.cards.first(where: { $0.id == card }) else {
                end(run, phase: .failed(.sourceMissing))
                return pump()
            }
            // The card is read, never written: it is the job's source; the
            // event folder is only read too.
            job = CardBackupJob(source: mounted.url, destination: source)
            let url = Self.pairsFolder?.appendingPathComponent(CardBackupPairs.fileName(record: record.id))
            Task.detached(priority: .utility) {
                let pairs = url.flatMap { try? Data(contentsOf: $0) }.map(CardBackupPairs.decode)?[card] ?? []
                job.runCheck(pairs)
            }
        }
        self.job = job
        started = Date()
        stage = nil
        runs[index].phase = .running(.copying)
        meter.progress = CardImportProgress()
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: CardBackupTiming.poll, repeats: true) { _ in
            CardBackupService.shared.readJob()
        }
    }

    /// Ten times a second while a job runs.
    private func readJob() {
        guard let job, let index = runs.firstIndex(where: { if case .running = $0.phase { return true } else { return false } })
        else { return }
        let state = job.snapshot()
        if stage != state.stage, state.totalFiles > 0 || state.finished {
            stage = state.stage
            rate = CardImportRate()
            runs[index].phase = .running(state.stage)
            setActivity(.running(state.stage, totalFiles: max(1, state.totalFiles)))
        }
        rate.record(copied: state.doneBytes, at: uptime)
        var progress = CardImportProgress(totalFiles: state.totalFiles, totalBytes: state.totalBytes,
                                          copiedFiles: state.doneFiles, copiedBytes: state.doneBytes,
                                          current: state.current, eta: nil, bytesPerSecond: rate.bytesPerSecond)
        progress.eta = rate.eta(remaining: state.totalBytes - state.doneBytes, at: uptime)
        if progress != meter.progress { meter.progress = progress }
        guard state.finished, let outcome = state.outcome else { return }
        finish(runs[index], outcome: outcome)
    }

    private func finish(_ run: CardBackupRun, outcome: CardBackupOutcome) {
        poll?.invalidate()
        poll = nil
        job = nil
        let now = Date()
        let phase: CardBackupRun.Phase
        switch outcome.error {
        case nil:
            phase = outcome.mismatches.isEmpty
                ? .finished(files: outcome.files, bytes: outcome.bytes, verified: outcome.verified)
                : .failed(.mismatches(outcome.mismatches.count))
        case .cancelled?:
            runs.removeAll { $0 == run }
            setActivity(nil)
            return pump()
        case .sourceMissing?: phase = .failed(.sourceMissing)
        case .destinationRemoved?: phase = .failed(.driveRemoved)
        case .diskFull(let needed)?: phase = .failed(.diskFull(needed: needed))
        case .failed(let file)?: phase = .failed(.failed(file: file))
        }
        switch run.kind {
        case let .backup(destination, drive) where outcome.error == nil:
            change {
                // Dated from its start: an import that ended while it ran is not in it.
                $0.recordBackup(run.record, destination: destination, drive: drive, files: outcome.files,
                                bytes: outcome.bytes, at: started)
                if outcome.verified {
                    $0.recordVerification(run.record, destination: destination, problems: outcome.mismatches.count, at: now)
                }
            }
        case .card(let card) where outcome.error == nil:
            change { $0.recordCardCheck(run.record, card: card, problems: outcome.mismatches.count, at: now) }
        default:
            break
        }
        var ended = run
        ended.mismatches = outcome.mismatches
        end(ended, phase: phase)
        scheduleReminder()
        pump()
    }

    private func end(_ run: CardBackupRun, phase: CardBackupRun.Phase) {
        var ended = run
        ended.phase = phase
        runs.removeAll { $0.record == run.record && $0.kind == run.kind }
        switch run.kind {
        case .backup: results[run.record] = ended
        case .card(let card): results[Self.checkKey(run.record, card: card)] = ended
        }
        switch phase {
        case let .finished(files, bytes, verified):
            showActivity(.finished(files: files, bytes: bytes, verified: verified), for: CardBackupTiming.finishedHold)
        case .failed(let failure):
            showActivity(.failed(failure), for: CardBackupTiming.failedHold)
        default:
            break
        }
    }

    // MARK: Activity

    private func setActivity(_ next: CardBackupActivity?) {
        activityWork?.cancel()
        activityWork = nil
        if CardImportService.shared.backupActivity != next { CardImportService.shared.backupActivity = next }
    }

    private func showActivity(_ next: CardBackupActivity, for hold: TimeInterval) {
        setActivity(next)
        let work = DispatchWorkItem {
            let imports = CardImportService.shared
            if imports.backupActivity == next { imports.backupActivity = nil }
        }
        activityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hold, execute: work)
    }

    // MARK: Reminders

    /// The records whose event folder is still there, read off the main thread.
    private func existing(_ records: [CardBackupRecord], then: @escaping ([CardBackupRecord]) -> Void) {
        queue.async {
            let present = records.filter {
                CardDetection.isDirectory(CardImportDestination.baseURL(stored: $0.folder))
            }
            DispatchQueue.main.async { then(present) }
        }
    }

    private func scheduleReminder() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        guard watching, let delay = settings.reminderDelay else { return }
        let now = Date()
        guard let next = CardBackupReminder.nextCheck(ledger.records, now: now, delay: delay) else { return }
        let wait = min(max(1, next.timeIntervalSince(now)), CardBackupTiming.reminderCheck)
        reminderTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { _ in
            CardBackupService.shared.checkReminders()
        }
    }

    private func checkReminders() {
        let due = CardBackupReminder.due(ledger.records, now: Date(), delay: settings.reminderDelay)
        guard !due.isEmpty else { return scheduleReminder() }
        existing(due) { present in
            let service = CardBackupService.shared
            // A folder that is gone counts as reminded, quietly.
            service.change { $0.markReminded(due.map(\.id), at: Date()) }
            if !present.isEmpty { service.announce(present, subtitle: CardBackupFormat.eventList(present, language: L10n.shared.language)) }
            service.scheduleReminder()
        }
    }

    /// "2 events not backed up", and Back up.
    private func announce(_ records: [CardBackupRecord], subtitle: String) {
        let language = L10n.shared.language
        ZenithNoticeCenter.shared.cardBackupPending(title: CardBackupFormat.reminderTitle(records, text: text, language: language),
                                                    subtitle: subtitle, action: text.backUp)
    }

    /// The notice's Back up: the list in the island, and the backup when a drive is here.
    func noticeBackUp() {
        showsList = true
        NotchService.shared.open(.cardImport)
        if !mountedDestinations.isEmpty { backUpPending() }
    }

    // MARK: Finder

    func reveal(_ record: CardBackupRecord) {
        let folder = CardImportDestination.baseURL(stored: record.folder)
        guard FileManager.default.fileExists(atPath: folder.path) else { return ZenithQuiet.beep() }
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension CardBackupService {
    func catalogPose(progress: CardImportProgress) { meter.progress = progress }
}
#endif
