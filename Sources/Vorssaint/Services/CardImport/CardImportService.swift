// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import DiskArbitration

// Zenith fork: camera cards for the island. Watches volumes mount and
// unmount while the island runs with card detection on; a card (a removable
// volume with a DCIM folder or a camera's video folders) is read off the
// main thread, offered in a capsule notice, and imported from its page: the
// plan and the copy run in a background task, which the main thread reads
// ten times a second for the page and the closed island's activity.

/// A camera card in the Mac.
struct CardImportCard: Identifiable, Equatable {
    /// The volume's UUID, which a card formatted in the camera changes.
    let id: String
    let url: URL
    let name: String
    /// Nil while it is being read.
    var scan: CardScan?
    /// Files on it the ledger has seen come off before.
    var importedBefore = 0
}

/// What the page will import with: the event folder's name and the options,
/// filled from the defaults for each card.
struct CardImportDraft: Equatable {
    var eventName = ""
    var options = CardImportOptions()
}

/// An import under way, or how the last one ended. Retrying keeps adding to it.
struct CardImportSession: Equatable {
    enum Phase: Equatable {
        case preparing, copying, finished
        case failed(CardImportFailure)
    }

    enum Eject: Equatable { case idle, ejecting, ejected, failed }

    let cardID: String
    let cardName: String
    let folder: URL
    let options: CardImportOptions
    var phase = Phase.preparing
    /// Over every run of this import.
    var copiedFiles = 0
    var copiedBytes: Int64 = 0
    var skipped = 0
    var eject = Eject.idle
    /// Ledger keys this import copied, which a retry never copies again.
    var copiedKeys: Set<String> = []

    var isRunning: Bool { phase == .preparing || phase == .copying }
}

/// The copy's progress on its own, so its ten readings a second redraw only
/// the views that show them.
final class CardImportMeter: ObservableObject {
    @Published fileprivate(set) var progress = CardImportProgress()
}

final class CardImportService: ObservableObject {
    static let shared = CardImportService()

    @Published private(set) var cards: [CardImportCard] = []
    /// The card the page shows; the newest one when nothing was chosen.
    @Published var selectedID: String?
    @Published var draft = CardImportDraft()
    @Published private(set) var session: CardImportSession?
    /// What the closed island shows; changes only when an import starts or ends.
    @Published private(set) var activity: CardImportActivity?
    let meter = CardImportMeter()

    private var watching = false
    private var observers: [NSObjectProtocol] = []
    private let queue = DispatchQueue(label: "com.vorssaint.zenith.card-import", qos: .utility)
    private var job: CardImportJob?
    private var task: Task<Void, Never>?
    private var poll: Timer?
    private var rate = CardImportRate()
    private var ledgers: [String: CardImportLedger] = [:]
    private var unsavedKeys = 0
    private var activityWork: DispatchWorkItem?
    /// When a run started copying, for a removal noticed just after it failed.
    private var lastFailure: (card: String, at: TimeInterval)?

    private init() {}

    var card: CardImportCard? {
        cards.first { $0.id == selectedID } ?? cards.last
    }

    static var ledgerFolder: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent("CardImport", isDirectory: true)
    }

    static var baseFolder: URL {
        CardImportDestination.baseURL(stored: UserDefaults.standard.string(forKey: DefaultsKey.notchCardImportFolder))
    }

    private var text: ZenithCardImportStrings { ZenithStrings.cardImport(L10n.shared.language) }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: Lifecycle

    /// Called with every island preference sync.
    func syncWithPreferences() {
        guard CardImportOptions.isEnabled(), NotchSupport.isEnabled() else {
            stop()
            return
        }
        guard !watching else { return }
        watching = true
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { note in
                guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
                CardImportService.shared.volumeMounted(url, announces: true)
            },
            center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { note in
                guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
                CardImportService.shared.volumeUnmounted(url)
            },
        ]
        // Cards already in the Mac show on the page, without a notice.
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil,
                                                            options: [.skipHiddenVolumes]) ?? []
        for url in mounted { volumeMounted(url, announces: false) }
    }

    /// Detection off or the island stopped: no more watching. An import under
    /// way finishes on its own; the card it reads stays listed until then.
    func stop() {
        guard watching else { return }
        watching = false
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers.removeAll()
        let reading = session?.isRunning == true ? session?.cardID : nil
        cards.removeAll { $0.id != reading }
    }

    // MARK: Volumes

    private struct Identity: Sendable {
        let key: String
        let url: URL
        let name: String
    }

    private func volumeMounted(_ url: URL, announces: Bool) {
        queue.async {
            guard let identity = Self.identity(of: url) else { return }
            DispatchQueue.main.async { CardImportService.shared.cardFound(identity) }
            let scan = CardScanner.scan(root: url)
            let ledger = Self.ledgerFolder.map { CardImportLedger.load(volume: identity.key, folder: $0) }
                ?? CardImportLedger(volume: identity.key)
            DispatchQueue.main.async {
                CardImportService.shared.cardRead(identity, scan: scan, ledger: ledger, announces: announces)
            }
        }
    }

    private func cardFound(_ identity: Identity) {
        guard watching, !cards.contains(where: { $0.id == identity.key }) else { return }
        cards.append(CardImportCard(id: identity.key, url: identity.url, name: identity.name))
    }

    private func cardRead(_ identity: Identity, scan: CardScan, ledger: CardImportLedger, announces: Bool) {
        guard watching else { return }
        // A ledger this Mac already holds in memory is newer than the file.
        let ledger = ledgers[identity.key] ?? ledger
        ledgers[identity.key] = ledger
        let known = ledger.keySet
        var card = CardImportCard(id: identity.key, url: identity.url, name: identity.name, scan: scan)
        card.importedBefore = scan.files.filter { known.contains($0.ledgerKey) }.count
        if let index = cards.firstIndex(where: { $0.id == identity.key }) { cards[index] = card } else { cards.append(card) }
        let busy = session?.isRunning == true
        // A card put in starts afresh, unless it is the one a failed import waits for.
        if announces, let ended = session, !ended.isRunning {
            let waits: Bool = { if case .failed = ended.phase { return ended.cardID == card.id } else { return false } }()
            if !waits { session = nil }
        }
        if !busy, announces || selectedID == nil || selectedID == card.id {
            selectedID = card.id
            resetDraft(for: card)
        }
        guard announces, !scan.isEmpty else { return }
        let notice = CardImportFormat.notice(scan: scan, volume: identity.name, importedBefore: card.importedBefore,
                                             text: text, language: L10n.shared.language)
        ZenithNoticeCenter.shared.cardInserted(volume: identity.key, title: notice.title, subtitle: notice.subtitle)
    }

    private func volumeUnmounted(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard let card = cards.first(where: { $0.url.standardizedFileURL.path == path }) else { return }
        ZenithNoticeCenter.shared.cardRemoved(volume: card.id)
        if session?.cardID == card.id, session?.isRunning == true { job?.markSourceGone() }
        // A copy that failed a moment ago on this card failed because it left.
        if var current = session, current.cardID == card.id, case .failed(.failed) = current.phase,
           let failure = lastFailure, failure.card == card.id, now - failure.at < 5 {
            current.phase = .failed(.cardRemoved)
            session = current
            showActivity(.failed(.cardRemoved), for: CardImportTiming.failedHold)
        }
        if session?.cardID == card.id, session?.eject == .ejecting {
            session?.eject = .ejected
        }
        cards.removeAll { $0.id == card.id }
        if selectedID == card.id { selectedID = cards.last?.id }
        if let next = self.card, session?.isRunning != true { resetDraft(for: next) }
    }

    /// A camera card's identity, or nil for any other volume. Reads the
    /// volume, so it runs off the main thread.
    private static func identity(of url: URL) -> Identity? {
        let keys: Set<URLResourceKey> = [.volumeIsLocalKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
                                         .volumeIsRootFileSystemKey, .volumeUUIDStringKey, .volumeLocalizedNameKey,
                                         .volumeTotalCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        let traits = CardVolumeTraits(isLocal: values.volumeIsLocal ?? false,
                                      isRemovable: values.volumeIsRemovable ?? false,
                                      isEjectable: values.volumeIsEjectable ?? false,
                                      isRootFileSystem: values.volumeIsRootFileSystem ?? false)
        guard CardDetection.isCameraCard(root: url, traits: traits) else { return nil }
        let name = values.volumeLocalizedName ?? url.lastPathComponent
        // FAT and exFAT cards often give Foundation no UUID; Disk Arbitration
        // derives one from the volume's serial number.
        let key = values.volumeUUIDString ?? diskArbitrationUUID(of: url)
            ?? "\(name)-\(values.volumeTotalCapacity ?? 0)"
        return Identity(key: key, url: url, name: name)
    }

    private static func diskArbitrationUUID(of url: URL) -> String? {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
              let description = DADiskCopyDescription(disk) as? [CFString: Any],
              let value = description[kDADiskDescriptionVolumeUUIDKey] else { return nil }
        let uuid = value as! CFUUID // swiftlint:disable:this force_cast
        return CFUUIDCreateString(kCFAllocatorDefault, uuid) as String?
    }

    // MARK: The page

    private func resetDraft(for card: CardImportCard) {
        let options = CardImportOptions.current()
        let known = ledgers[card.id]?.keySet ?? []
        let fresh = card.scan?.files.filter { !known.contains($0.ledgerKey) } ?? []
        let newest = (fresh.isEmpty ? card.scan?.files ?? [] : fresh).map(\.captured).max()
        draft = CardImportDraft(eventName: CardImportDestination.eventName(for: newest ?? Date()), options: options)
    }

    func select(_ id: String) {
        guard session?.isRunning != true, let card = cards.first(where: { $0.id == id }) else { return }
        selectedID = id
        if session?.cardID != id { session = nil }
        resetDraft(for: card)
    }

    /// Files the draft would leave out for this card.
    func importedBefore(_ card: CardImportCard) -> Int { card.importedBefore }

    /// The notice's Import: the card's page in the island.
    func openImport(volume: String) {
        if cards.contains(where: { $0.id == volume }) { select(volume) }
        NotchService.shared.open(.cardImport)
    }

    // MARK: Import

    /// Starts the selected card with the draft.
    func startImport() {
        guard let card, card.scan != nil, session?.isRunning != true else { return }
        let base = Self.baseFolder
        let folder = CardImportDestination.eventFolder(base: base, typed: draft.eventName, fallbackDate: Date())
        session = CardImportSession(cardID: card.id, cardName: card.name, folder: folder, options: draft.options)
        run(card)
    }

    /// The same import again, after the card came back or room was made.
    func retry() {
        guard var current = session, case .failed = current.phase,
              let card = cards.first(where: { $0.id == current.cardID }), card.scan != nil else { return }
        current.phase = .preparing
        session = current
        run(card)
    }

    func stopImport() {
        job?.cancel()
    }

    /// Back to the card after a result.
    func dismissResult() {
        guard session?.isRunning != true else { return }
        session = nil
        setActivity(nil)
        if let card { resetDraft(for: card) }
    }

    func reveal() {
        guard let folder = session?.folder else { return }
        if FileManager.default.fileExists(atPath: folder.path) {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } else {
            NSWorkspace.shared.open(Self.baseFolder)
        }
    }

    private func run(_ card: CardImportCard) {
        guard let current = session, let scan = card.scan else { return }
        var skip = current.copiedKeys
        if current.options.skipImported { skip.formUnion(ledgers[card.id]?.keySet ?? []) }
        let job = CardImportJob(source: card.url, destination: current.folder)
        self.job = job
        rate = CardImportRate()
        meter.progress = CardImportProgress()
        setActivity(.copying(totalFiles: max(1, scan.files.count - skip.count)))
        let options = current.options, folder = current.folder, files = scan.files
        task = Task.detached(priority: .utility) {
            let plan = CardImportPlanner.plan(files, options: options, skip: skip, exists: { path in
                FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path)
            })
            if let shortfall = Self.shortfall(for: plan, in: folder) {
                job.fail(.diskFull, shortfall: shortfall, plan: plan)
                return
            }
            job.run(plan)
        }
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: CardImportTiming.poll, repeats: true) { _ in
            CardImportService.shared.readJob()
        }
    }

    /// How much more room the plan wants than the destination has, if any.
    private static func shortfall(for plan: CardImportPlan, in folder: URL) -> Int64? {
        var probe = folder
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
        guard let free = (try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage else { return nil }
        let wanted = plan.bytes + CardImportTiming.spaceMargin
        return free < wanted ? wanted - free : nil
    }

    /// Ten times a second while a copy runs: its progress, the files it
    /// finished for the ledger, and how it ended.
    private func readJob() {
        guard let job, var current = session else { return }
        let state = job.drain()
        if !state.finishedKeys.isEmpty { record(state.finishedKeys, card: current.cardID) }
        if current.phase == .preparing, state.totalFiles > 0 || state.finished {
            current.phase = state.finished && state.error != nil ? current.phase : .copying
            current.skipped = state.skipped
            session = current
        }
        rate.record(copied: state.copiedBytes, at: now)
        var progress = CardImportProgress(totalFiles: state.totalFiles, totalBytes: state.totalBytes,
                                          copiedFiles: state.copiedFiles, copiedBytes: state.copiedBytes,
                                          current: state.current, eta: nil, bytesPerSecond: rate.bytesPerSecond)
        progress.eta = rate.eta(remaining: state.totalBytes - state.copiedBytes, at: now)
        if progress != meter.progress { meter.progress = progress }
        guard state.finished else { return }
        finish(state)
    }

    private func finish(_ state: CardImportJob.State) {
        poll?.invalidate()
        poll = nil
        job = nil
        task = nil
        guard var current = session else { return }
        current.copiedFiles += state.copiedFiles
        current.copiedBytes += state.copiedBytes
        saveLedger(current.cardID)
        refreshImported(current.cardID)
        switch state.error {
        case nil:
            current.phase = .finished
            session = current
            showActivity(.finished(files: current.copiedFiles, bytes: current.copiedBytes), for: CardImportTiming.finishedHold)
            if current.options.ejectWhenDone { eject() }
        case .cancelled?:
            // Stopped by hand: what was copied stays, and the card is ready again.
            session = nil
            setActivity(nil)
            if let card { resetDraft(for: card) }
        case .cardRemoved?:
            fail(&current, .cardRemoved)
        case .diskFull?:
            fail(&current, .diskFull(needed: max(state.shortfall, state.totalBytes - state.copiedBytes)))
        case .failed(let file)?:
            lastFailure = (current.cardID, now)
            fail(&current, .failed(file: file))
        }
    }

    private func fail(_ current: inout CardImportSession, _ failure: CardImportFailure) {
        current.phase = .failed(failure)
        session = current
        showActivity(.failed(failure), for: CardImportTiming.failedHold)
    }

    // MARK: Ledger

    private func record(_ keys: [String], card: String) {
        session?.copiedKeys.formUnion(keys)
        var ledger = ledgers[card] ?? CardImportLedger(volume: card)
        ledger.record(keys)
        ledgers[card] = ledger
        unsavedKeys += keys.count
        if unsavedKeys >= CardImportTiming.ledgerBatch { saveLedger(card) }
    }

    private func saveLedger(_ card: String) {
        unsavedKeys = 0
        guard let ledger = ledgers[card], let folder = Self.ledgerFolder else { return }
        queue.async {
            guard PrivateFileStore.createDirectory(at: folder) else { return }
            ledger.save(folder: folder)
        }
    }

    private func refreshImported(_ id: String) {
        guard let index = cards.firstIndex(where: { $0.id == id }), let scan = cards[index].scan else { return }
        let known = ledgers[id]?.keySet ?? []
        cards[index].importedBefore = scan.files.filter { known.contains($0.ledgerKey) }.count
    }

    // MARK: Eject

    /// Ejects the session's card, or the selected one. Never during a copy.
    func eject() {
        guard session?.isRunning != true,
              let id = session?.cardID ?? card?.id, let card = cards.first(where: { $0.id == id }) else { return }
        if session?.cardID == id { session?.eject = .ejecting }
        let url = card.url
        DispatchQueue.global(qos: .userInitiated).async {
            let ejected: Bool
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                ejected = true
            } catch {
                ejected = !FileManager.default.fileExists(atPath: url.path)
            }
            DispatchQueue.main.async { CardImportService.shared.ejectEnded(id, ejected: ejected) }
        }
    }

    private func ejectEnded(_ id: String, ejected: Bool) {
        guard session?.cardID == id else { return }
        session?.eject = ejected ? .ejected : .failed
    }

    // MARK: Activity

    private func setActivity(_ next: CardImportActivity?) {
        activityWork?.cancel()
        activityWork = nil
        if activity != next { activity = next }
    }

    /// A result shows in the closed island for a while, then goes.
    private func showActivity(_ next: CardImportActivity, for hold: TimeInterval) {
        setActivity(next)
        let work = DispatchWorkItem {
            let service = CardImportService.shared
            if service.activity == next { service.activity = nil }
        }
        activityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hold, execute: work)
    }
}
