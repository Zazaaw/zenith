// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Darwin
import Foundation

// Zenith fork: copies a card import's plan, one file at a time, off the main
// thread. Each file is written to a hidden partial file next to its place,
// checked against the card's size, given the card's creation and
// modification dates, and only then moved to its name, never over another
// file. Nothing on the card is ever written, moved or deleted. Compiled into
// the tests, which copy a few small files end to end.

enum CardImportCopyError: Error, Equatable, Sendable {
    case cardRemoved
    case diskFull
    case cancelled
    case failed(file: String)
}

/// One import's copy. The service starts it in a background task and reads
/// its state on a short timer; the two share nothing else, so the state sits
/// behind a lock.
final class CardImportJob: @unchecked Sendable {
    struct State: Equatable, Sendable {
        /// The plan's, once it is known.
        var totalFiles = 0
        var totalBytes: Int64 = 0
        var skipped = 0
        var copiedFiles = 0
        var copiedBytes: Int64 = 0
        var current: String?
        /// Ledger keys of the files finished since the last drain.
        var finishedKeys: [String] = []
        /// Set once the copy has ended, well or not.
        var finished = false
        /// Why it ended early, if it did.
        var error: CardImportCopyError?
        /// With a full disk found before the copy: how much more it wants.
        var shortfall: Int64 = 0
    }

    static let partialPrefix = ".zenith-import-"
    static let partialSuffix = ".partial"

    let source: URL
    let destination: URL
    let chunkSize: Int
    /// How long a failed read waits to learn whether the card left.
    let removalGrace: TimeInterval

    private let lock = NSLock()
    private var state = State()
    private var cancelled = false
    private var sourceGone = false
    /// The card's device, so a mount point left behind reads as gone.
    private let sourceDevice: dev_t?

    init(source: URL, destination: URL, chunkSize: Int = 4 << 20, removalGrace: TimeInterval = 1.5) {
        self.source = source
        self.destination = destination
        self.chunkSize = max(64 * 1024, chunkSize)
        self.removalGrace = removalGrace
        sourceDevice = Self.device(of: source)
    }

    // MARK: Shared state

    func cancel() { lock.withLock { cancelled = true } }

    /// The card's volume went away.
    func markSourceGone() { lock.withLock { sourceGone = true } }

    var isCancelled: Bool { lock.withLock { cancelled } }

    /// The state as it is now, handing over the keys finished since the last look.
    func drain() -> State {
        lock.withLock {
            let snapshot = state
            state.finishedKeys.removeAll()
            return snapshot
        }
    }

    private func update(_ change: (inout State) -> Void) { lock.withLock { change(&state) } }

    /// The card is still where the copy started: mounted, the same device.
    var sourceAvailable: Bool {
        let gone = lock.withLock { sourceGone }
        guard !gone, let device = Self.device(of: source) else { return false }
        return sourceDevice == nil || device == sourceDevice
    }

    private static func device(of url: URL) -> dev_t? {
        var info = stat()
        return stat(url.path, &info) == 0 ? info.st_dev : nil
    }

    /// Ends the job before any copy, as the free space check does.
    func fail(_ error: CardImportCopyError, shortfall: Int64 = 0, plan: CardImportPlan) {
        update {
            $0.totalFiles = plan.items.count
            $0.totalBytes = plan.bytes
            $0.skipped = plan.skipped.count
            $0.shortfall = shortfall
            $0.error = error
            $0.finished = true
        }
    }

    // MARK: Copy

    /// Copies every file in the plan in order; stops at the first one that
    /// cannot be copied. Partial files from an earlier run that never ended
    /// (the Mac slept or Zenith quit) are cleared first.
    @discardableResult
    func run(_ plan: CardImportPlan) -> CardImportCopyError? {
        update {
            $0.totalFiles = plan.items.count
            $0.totalBytes = plan.bytes
            $0.skipped = plan.skipped.count
        }
        Self.removePartials(in: destination, plan: plan)
        var result: CardImportCopyError?
        for item in plan.items {
            if isCancelled { result = .cancelled; break }
            update { $0.current = item.file.name }
            do {
                _ = try copy(item)
                update {
                    $0.copiedFiles += 1
                    $0.finishedKeys.append(item.file.ledgerKey)
                }
            } catch let error as CardImportCopyError {
                result = error
                break
            } catch {
                result = .failed(file: item.file.name)
                break
            }
        }
        update {
            $0.current = nil
            $0.error = result
            $0.finished = true
        }
        return result
    }

    /// One file: written beside its place under a partial name, its size
    /// checked, its dates set, then moved to the first free name. Returns
    /// where it landed.
    func copy(_ item: CardImportPlan.Item) throws -> URL {
        let from = source.appendingPathComponent(item.file.relativePath, isDirectory: false)
        let target = destination.appendingPathComponent(item.destination, isDirectory: false)
        let folder = target.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw Self.writeError(errno: Self.posixCode(error), file: item.file.name)
        }
        let partial = folder.appendingPathComponent(Self.partialPrefix + UUID().uuidString + Self.partialSuffix,
                                                    isDirectory: false)
        do {
            let copied = try copyData(from: from, to: partial, name: item.file.name)
            guard copied == item.file.size, Self.size(of: partial) == item.file.size else {
                throw CardImportCopyError.failed(file: item.file.name)
            }
            try Self.copyDates(from: from, to: partial)
            return try Self.place(partial, at: target)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            if let error = error as? CardImportCopyError { throw error }
            throw CardImportCopyError.failed(file: item.file.name)
        }
    }

    private func copyData(from: URL, to: URL, name: String) throws -> Int64 {
        let input = open(from.path, O_RDONLY)
        guard input >= 0 else { throw readError(errno: errno, file: name) }
        defer { close(input) }
        let output = open(to.path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
        guard output >= 0 else { throw Self.writeError(errno: errno, file: name) }
        defer { close(output) }
        // Thousands of large files pass through once: keep them out of the cache.
        _ = fcntl(input, F_NOCACHE, 1)
        _ = fcntl(output, F_NOCACHE, 1)
        let size = chunkSize
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        defer { buffer.deallocate() }
        var total: Int64 = 0
        while true {
            if isCancelled { throw CardImportCopyError.cancelled }
            let count = read(input, buffer, size)
            if count < 0 {
                if errno == EINTR { continue }
                throw readError(errno: errno, file: name)
            }
            if count == 0 { break }
            var written = 0
            while written < count {
                let result = write(output, buffer + written, count - written)
                if result < 0 {
                    if errno == EINTR { continue }
                    throw Self.writeError(errno: errno, file: name)
                }
                written += result
            }
            total += Int64(count)
            update { $0.copiedBytes += Int64(count) }
        }
        return total
    }

    /// A read that failed because the card left reads as that.
    /// A read that failed because the card left reads as that. A card pulled
    /// out fails its read before the volume unmounts, so it waits a moment.
    private func readError(errno _: Int32, file: String) -> CardImportCopyError {
        let deadline = Date().addingTimeInterval(removalGrace)
        while sourceAvailable, Date() < deadline { usleep(100_000) }
        return sourceAvailable ? .failed(file: file) : .cardRemoved
    }

    static func writeError(errno code: Int32, file: String) -> CardImportCopyError {
        [ENOSPC, EDQUOT].contains(code) ? .diskFull : .failed(file: file)
    }

    /// The POSIX error under a Foundation one, as a full disk reports itself.
    static func posixCode(_ error: Error) -> Int32 {
        let error = error as NSError
        if error.domain == NSPOSIXErrorDomain { return Int32(error.code) }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError, underlying.domain == NSPOSIXErrorDomain {
            return Int32(underlying.code)
        }
        if error.domain == NSCocoaErrorDomain, error.code == NSFileWriteOutOfSpaceError { return ENOSPC }
        return EIO
    }

    // MARK: Files

    static func size(of url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    /// The card's creation and modification dates on the copy.
    static func copyDates(from source: URL, to copy: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        var dates: [FileAttributeKey: Any] = [:]
        if let created = attributes[.creationDate] as? Date { dates[.creationDate] = created }
        if let modified = attributes[.modificationDate] as? Date { dates[.modificationDate] = modified }
        guard !dates.isEmpty else { return }
        try FileManager.default.setAttributes(dates, ofItemAtPath: copy.path)
    }

    /// Moves the finished copy to `target`, or to `name-1`, `name-2` … when
    /// that is taken; an existing file is never replaced.
    static func place(_ partial: URL, at target: URL) throws -> URL {
        let folder = target.deletingLastPathComponent()
        let name = target.lastPathComponent
        for attempt in 0..<10_000 {
            let candidate = folder.appendingPathComponent(CardImportPlanner.alternative(name, attempt: attempt),
                                                          isDirectory: false)
            if renamex_np(partial.path, candidate.path, UInt32(RENAME_EXCL)) == 0 { return candidate }
            guard errno == EEXIST else { throw writeError(errno: errno, file: name) }
        }
        throw CardImportCopyError.failed(file: name)
    }

    /// Partial files an earlier copy into these folders left behind.
    static func removePartials(in destination: URL, plan: CardImportPlan) {
        let folders = Set(plan.items.map { destination.appendingPathComponent($0.destination).deletingLastPathComponent() })
        for folder in folders {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            for name in names where name.hasPrefix(partialPrefix) && name.hasSuffix(partialSuffix) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name, isDirectory: false))
            }
        }
    }
}
