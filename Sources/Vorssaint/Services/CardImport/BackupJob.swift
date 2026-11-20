// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Darwin
import Foundation

// Zenith fork: one backup of an event folder, or one check of a card against
// its import, off the main thread at low I/O priority. The copy goes through
// the card import's own copier (a hidden partial file, its size checked, then
// a rename that never replaces a file); the check reads both sides in 4 MB
// chunks into SHA-256. Nothing it reads from (the card, the import) is ever
// written, moved or deleted; on the backup it only adds files and its
// manifest. Compiled into the tests, which back up and check small folders.

enum CardBackupError: Error, Equatable, Sendable {
    case sourceMissing
    case destinationRemoved
    case diskFull(needed: Int64)
    case cancelled
    case failed(file: String)
}

/// How a job ended: what it copied, what it compared, and what did not match.
struct CardBackupOutcome: Equatable, Sendable {
    var copiedFiles = 0
    var copiedBytes: Int64 = 0
    /// Every file the backup holds for the event (or that came off the card).
    var files = 0
    var bytes: Int64 = 0
    /// Whether every file was compared.
    var verified = false
    var mismatches: [CardBackupMismatch] = []
    var error: CardBackupError?
}

enum CardBackupHasher {
    static let chunkSize = 4 << 20

    /// The file's SHA-256 in lowercase hex, read in chunks past the cache;
    /// `progress` hears each chunk's size. Nil when it cannot be read.
    static func sha256(of url: URL, chunkSize: Int = chunkSize, isCancelled: () -> Bool = { false },
                       progress: (Int) -> Void = { _ in }) throws -> String? {
        let input = open(url.path, O_RDONLY)
        guard input >= 0 else { return nil }
        defer { close(input) }
        _ = fcntl(input, F_NOCACHE, 1)
        let size = max(64 * 1024, chunkSize)
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        defer { buffer.deallocate() }
        var hasher = SHA256()
        while true {
            if isCancelled() { throw CardBackupError.cancelled }
            let count = read(input, buffer, size)
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if count == 0 { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: count))
            progress(count)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Runs `body` with this thread's disk I/O at utility priority, so a
    /// backup gives way to whatever the person is doing, and puts the
    /// thread's policy back after.
    static func lowPriority<T>(_ body: () throws -> T) rethrows -> T {
        let previous = getiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD)
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_UTILITY)
        defer { if previous >= 0 { setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, previous) } }
        return try body()
    }
}

/// One backup or check. The service starts it in a background task and reads
/// its state on a short timer, as it does a card import.
final class CardBackupJob: @unchecked Sendable {
    struct State: Equatable, Sendable {
        var stage = CardBackupStage.copying
        /// Of the stage under way.
        var totalFiles = 0
        var totalBytes: Int64 = 0
        var doneFiles = 0
        var doneBytes: Int64 = 0
        var current: String?
        var finished = false
        var outcome: CardBackupOutcome?
    }

    /// The folder read from (the event folder, or the card) and the one
    /// written to (the backup's event folder, or the event folder, never written).
    let source: URL
    let destination: URL
    let chunkSize: Int

    private let lock = NSLock()
    private var state = State()
    private var cancelled = false
    private var copier: CardImportJob?
    /// The backup drive's device, so a drive pulled out reads as that.
    private let destinationDevice: dev_t?

    init(source: URL, destination: URL, chunkSize: Int = CardBackupHasher.chunkSize) {
        self.source = source
        self.destination = destination
        self.chunkSize = chunkSize
        destinationDevice = Self.device(nearest: destination)
    }

    func cancel() {
        let copier = lock.withLock { () -> CardImportJob? in
            cancelled = true
            return self.copier
        }
        copier?.cancel()
    }

    var isCancelled: Bool { lock.withLock { cancelled } }

    /// The state as it is now; while copying, the copier's bytes so far.
    func snapshot() -> State {
        let (current, copier) = lock.withLock { (state, self.copier) }
        guard let copier, current.stage == .copying, !current.finished else { return current }
        var reading = current
        reading.doneBytes = copier.drain().copiedBytes
        return reading
    }

    private func update(_ change: (inout State) -> Void) { lock.withLock { change(&state) } }

    private func end(_ outcome: CardBackupOutcome) -> CardBackupOutcome {
        update {
            $0.current = nil
            $0.outcome = outcome
            $0.finished = true
        }
        return outcome
    }

    // MARK: Backup

    /// The event folder onto the backup: planned against what the backup
    /// already holds, copied, then (with `verify`) every file compared by
    /// hash and the manifest written. `event` and `sourceName` go into the
    /// manifest.
    @discardableResult
    func runBackup(event: String, sourceName: String, verify: Bool, now: () -> Date = Date.init) -> CardBackupOutcome {
        CardBackupHasher.lowPriority { backup(event: event, sourceName: sourceName, verify: verify, now: now) }
    }

    private func backup(event: String, sourceName: String, verify: Bool, now: () -> Date) -> CardBackupOutcome {
        var outcome = CardBackupOutcome()
        guard CardDetection.isDirectory(source) else {
            outcome.error = .sourceMissing
            return end(outcome)
        }
        let files = CardBackupScanner.scan(folder: source, isCancelled: { isCancelled })
        if isCancelled { outcome.error = .cancelled; return end(outcome) }
        let plan = CardBackupPlanner.plan(files) { path in
            CardImportJob.size(of: destination.appendingPathComponent(path, isDirectory: false))
        }
        outcome.files = plan.items.count
        outcome.bytes = plan.bytes
        if let needed = Self.shortfall(plan.copyBytes, in: destination) {
            outcome.error = .diskFull(needed: needed)
            return end(outcome)
        }
        let copies = plan.copies
        let copier = CardImportJob(source: source, destination: destination, removalGrace: 0.2)
        update {
            $0.stage = .copying
            $0.totalFiles = copies.count
            $0.totalBytes = plan.copyBytes
        }
        lock.withLock { self.copier = copier }
        if !copies.isEmpty {
            CardImportJob.removePartials(in: destination, paths: copies.map(\.pair.copy))
        }
        var placed: [CardBackupPair] = []
        for item in plan.items {
            if isCancelled { outcome.error = .cancelled; break }
            guard !item.present else { placed.append(item.pair); continue }
            update { $0.current = (item.pair.source as NSString).lastPathComponent }
            do {
                let landed = try copier.copyFile(item.pair.source, size: item.pair.size, to: item.pair.copy)
                let path = CardImportJob.relativePath(of: landed, in: destination) ?? item.pair.copy
                placed.append(CardBackupPair(source: item.pair.source, copy: path, size: item.pair.size))
                outcome.copiedFiles += 1
                outcome.copiedBytes += item.pair.size
                update {
                    $0.doneFiles += 1
                    $0.doneBytes = outcome.copiedBytes
                }
            } catch let error as CardImportCopyError {
                outcome.error = mapped(error, needed: plan.copyBytes - outcome.copiedBytes)
                break
            } catch {
                outcome.error = .failed(file: (item.pair.source as NSString).lastPathComponent)
                break
            }
        }
        lock.withLock { self.copier = nil }
        update { $0.doneBytes = outcome.copiedBytes }
        guard outcome.error == nil else { return end(outcome) }
        guard verify else { return end(outcome) }

        let check = compare(placed)
        outcome.mismatches = check.mismatches
        if let error = check.error { outcome.error = error; return end(outcome) }
        outcome.verified = true
        let manifest = CardBackupManifest(event: event, source: sourceName, verified: now(), files: check.entries,
                                          mismatches: check.mismatches.map(\.file))
        manifest.save(folder: destination)
        return end(outcome)
    }

    // MARK: Card against import

    /// Each card file against its copy in the event folder, by hash.
    @discardableResult
    func runCheck(_ pairs: [CardBackupPair]) -> CardBackupOutcome {
        CardBackupHasher.lowPriority {
            var outcome = CardBackupOutcome()
            outcome.files = pairs.count
            outcome.bytes = pairs.reduce(0) { $0 + $1.size }
            guard CardDetection.isDirectory(source) else {
                outcome.error = .sourceMissing
                return end(outcome)
            }
            let check = compare(pairs)
            outcome.mismatches = check.mismatches
            outcome.error = check.error
            outcome.verified = check.error == nil
            return end(outcome)
        }
    }

    // MARK: Comparing

    private struct Check {
        var entries: [CardBackupManifest.Entry] = []
        var mismatches: [CardBackupMismatch] = []
        var error: CardBackupError?
    }

    /// Both sides of every pair hashed and compared; a size that differs
    /// already settles it. Progress counts both sides' bytes.
    private func compare(_ pairs: [CardBackupPair]) -> Check {
        var check = Check()
        update {
            $0.stage = .verifying
            $0.totalFiles = pairs.count
            $0.totalBytes = pairs.reduce(0) { $0 + $1.size } * 2
            $0.doneFiles = 0
            $0.doneBytes = 0
        }
        for pair in pairs {
            if isCancelled { check.error = .cancelled; break }
            update { $0.current = (pair.copy as NSString).lastPathComponent }
            let original = source.appendingPathComponent(pair.source, isDirectory: false)
            let copy = destination.appendingPathComponent(pair.copy, isDirectory: false)
            let sourceSize = CardImportJob.size(of: original), copySize = CardImportJob.size(of: copy)
            var sourceHash: String?, copyHash: String?
            do {
                if let sourceSize, sourceSize == copySize {
                    sourceHash = try hash(original)
                    copyHash = try hash(copy)
                } else {
                    let skipped = (sourceSize ?? pair.size) * 2
                    update { $0.doneBytes += skipped }
                }
            } catch {
                check.error = .cancelled
                break
            }
            if let mismatch = CardBackupComparison.compare(pair, sourceSize: sourceSize, copySize: copySize,
                                                          sourceHash: sourceHash, copyHash: copyHash) {
                check.mismatches.append(mismatch)
                // The backup drive leaving shows as every file after it missing.
                if case .missing = mismatch, !destinationAvailable { check.error = .destinationRemoved; break }
            } else if let copyHash, let copySize {
                let date = (try? FileManager.default.attributesOfItem(atPath: copy.path)[.modificationDate] as? Date) ?? nil
                check.entries.append(.init(file: pair.copy, size: copySize, sha256: copyHash,
                                           date: date ?? Date(timeIntervalSince1970: 0),
                                           source: pair.source == pair.copy ? nil : pair.source))
            }
            update { $0.doneFiles += 1 }
        }
        return check
    }

    private func hash(_ url: URL) throws -> String? {
        try CardBackupHasher.sha256(of: url, chunkSize: chunkSize, isCancelled: { isCancelled }) { count in
            update { $0.doneBytes += Int64(count) }
        }
    }

    // MARK: Errors and space

    private func mapped(_ error: CardImportCopyError, needed: Int64) -> CardBackupError {
        switch error {
        case .cancelled: return .cancelled
        case .cardRemoved: return .sourceMissing
        case .diskFull: return destinationAvailable ? .diskFull(needed: max(0, needed)) : .destinationRemoved
        case .failed(let file): return destinationAvailable ? .failed(file: file) : .destinationRemoved
        }
    }

    /// The backup drive is still the one the job started on.
    var destinationAvailable: Bool {
        guard let device = Self.device(nearest: destination) else { return false }
        return destinationDevice == nil || device == destinationDevice
    }

    /// The device of the folder, or of its nearest parent that exists yet.
    private static func device(nearest url: URL) -> dev_t? {
        var probe = url.standardizedFileURL
        while true {
            var info = stat()
            if stat(probe.path, &info) == 0 { return info.st_dev }
            guard probe.pathComponents.count > 1 else { return nil }
            probe.deleteLastPathComponent()
        }
    }

    /// How much more room `bytes` wants than the drive has, if any. A drive
    /// that does not say (some network shares) is not held back.
    static func shortfall(_ bytes: Int64, in folder: URL) -> Int64? {
        guard bytes > 0 else { return nil }
        var probe = folder
        while !FileManager.default.fileExists(atPath: probe.path), probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
        let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                         .volumeAvailableCapacityKey])
        guard let free = values?.volumeAvailableCapacityForImportantUsage ?? values?.volumeAvailableCapacity.map(Int64.init),
              free > 0 else { return nil }
        let wanted = bytes + CardBackupTiming.spaceMargin
        return free < wanted ? wanted - free : nil
    }
}
