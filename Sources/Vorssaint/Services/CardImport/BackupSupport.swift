// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: a verified second copy of every card import, so client photos
// live in two places before the card is formatted (the 3-2-1 rule). Pure
// Foundation, compiled into the tests: the backup destinations (a drive by
// its identity plus a path on it, so a drive mounted again is known), the
// settings, the backup plan, the manifest, the comparison of two copies, the
// ledger of imports and their safety, the reminder timing and the activity.
// CardBackupJob copies and hashes; CardBackupService watches the drives and
// runs it.

// MARK: - Volumes and destinations

/// A mounted volume as the backup knows it: its identity, its name, where it is.
struct CardBackupVolume: Equatable, Sendable {
    let key: String
    let name: String
    let url: URL
}

enum CardBackupVolumeIdentity {
    /// How a drive is known again when it mounts: its volume UUID; for a
    /// network share, which often has none, the share's address without the
    /// account (`share:smb://nas.local/Photos`); failing both, its name and
    /// capacity.
    static func key(uuid: String?, remountURL: URL?, name: String, capacity: Int?) -> String {
        if let uuid = uuid?.trimmingCharacters(in: .whitespacesAndNewlines), !uuid.isEmpty { return uuid.uppercased() }
        if let remountURL, let scheme = remountURL.scheme?.lowercased(), let host = remountURL.host?.lowercased(),
           !host.isEmpty {
            let path = remountURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return "share:\(scheme)://\(host)" + (path.isEmpty ? "" : "/" + path)
        }
        return "name:\(name)-\(capacity ?? 0)"
    }
}

/// A folder on a backup drive, kept as the drive's identity and the path
/// from its root, so the same folder is found wherever the drive mounts.
struct CardBackupDestination: Codable, Equatable, Identifiable, Sendable {
    var id: String
    /// `CardBackupVolumeIdentity.key` of its drive.
    var volume: String
    /// The drive's name when it was chosen, to show while it is away.
    var volumeName: String
    /// From the drive's root, with `/` between folders; empty for the root.
    var path: String

    /// The destination for a folder on a mounted volume, or nil when the
    /// folder is not on it.
    static func make(folder: URL, on volume: CardBackupVolume, id: String = UUID().uuidString) -> CardBackupDestination? {
        let path = folder.standardizedFileURL.path, root = volume.url.standardizedFileURL.path
        let relative: String
        if path == root { relative = "" }
        else if root == "/" { relative = String(path.dropFirst()) }
        else if path.hasPrefix(root + "/") { relative = String(path.dropFirst(root.count + 1)) }
        else { return nil }
        return CardBackupDestination(id: id, volume: volume.key, volumeName: volume.name,
                                     path: relative.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    /// Its drive, when mounted.
    func mountedVolume(in volumes: [CardBackupVolume]) -> CardBackupVolume? {
        volumes.first { $0.key == volume }
    }

    /// Where the folder is now, or nil while its drive is away.
    func folder(in volumes: [CardBackupVolume]) -> URL? {
        guard let volume = mountedVolume(in: volumes) else { return nil }
        return path.isEmpty ? volume.url : volume.url.appendingPathComponent(path, isDirectory: true)
    }

    /// `T7 Shield/Backups`, as Settings shows it.
    var displayPath: String { path.isEmpty ? volumeName : volumeName + "/" + path }
}

enum CardBackupDestinations {
    static let maximum = 2

    static func decode(_ stored: String?) -> [CardBackupDestination] {
        guard let data = stored?.data(using: .utf8), !data.isEmpty,
              let list = try? JSONDecoder().decode([CardBackupDestination].self, from: data) else { return [] }
        return Array(list.prefix(maximum))
    }

    static func encode(_ list: [CardBackupDestination]) -> String {
        guard !list.isEmpty, let data = try? JSONEncoder().encode(Array(list.prefix(maximum))) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// The list with one more, unless it is full or already holds that folder.
    static func adding(_ destination: CardBackupDestination, to list: [CardBackupDestination]) -> [CardBackupDestination] {
        guard list.count < maximum,
              !list.contains(where: { $0.volume == destination.volume && $0.path == destination.path }) else { return list }
        return list + [destination]
    }
}

// MARK: - Settings

struct CardBackupSettings: Equatable, Sendable {
    var destinations: [CardBackupDestination] = []
    /// Back up as soon as an import ends, when a destination is mounted.
    var automatic = false
    /// Compare every file by its hash after copying.
    var verify = true
    /// Remind after this many hours without a verified backup; 0 is off.
    var reminderHours = 24

    static let reminderChoices = [0, 6, 12, 24, 48]

    var reminderDelay: TimeInterval? { reminderHours > 0 ? TimeInterval(reminderHours) * 3600 : nil }

    static func current(in defaults: UserDefaults = .standard) -> CardBackupSettings {
        let hours = defaults.object(forKey: DefaultsKey.notchCardBackupReminderHours) as? Int ?? 24
        return CardBackupSettings(
            destinations: CardBackupDestinations.decode(defaults.string(forKey: DefaultsKey.notchCardBackupDestinations)),
            automatic: defaults.object(forKey: DefaultsKey.notchCardBackupAutomatic) as? Bool ?? false,
            verify: defaults.object(forKey: DefaultsKey.notchCardBackupVerify) as? Bool ?? true,
            reminderHours: reminderChoices.contains(hours) ? hours : 24)
    }
}

// MARK: - Source and plan

/// A file in an event folder, by its path from the folder.
struct CardBackupFile: Equatable, Sendable {
    let path: String
    let size: Int64
}

enum CardBackupScanner {
    /// Every regular file in the event folder, packages' contents included,
    /// sorted by path. Hidden files stay out: the import's partial files, a
    /// manifest, Finder's `.DS_Store`.
    static func scan(folder: URL, isCancelled: () -> Bool = { false }) -> [CardBackupFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let root = folder.standardizedFileURL.path
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys,
                                                          options: [.skipsHiddenFiles]) else { return [] }
        var files: [CardBackupFile] = []
        for case let url as URL in walker {
            if isCancelled() { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(root + "/") else { continue }
            files.append(CardBackupFile(path: String(path.dropFirst(root.count + 1)), size: Int64(values.fileSize ?? 0)))
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}

/// A file and its copy, by their paths from their two folders.
struct CardBackupPair: Codable, Equatable, Sendable {
    /// In the folder copied from: the event folder, or the card.
    let source: String
    /// In the folder copied to: the backup's event folder, or the event folder.
    let copy: String
    let size: Int64
}

struct CardBackupPlan: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        let pair: CardBackupPair
        /// Already on the backup with the same size, so not copied again;
        /// the verification still compares it.
        let present: Bool
    }

    var items: [Item] = []

    var copies: [Item] { items.filter { !$0.present } }
    var copyBytes: Int64 { copies.reduce(0) { $0 + $1.pair.size } }
    var bytes: Int64 { items.reduce(0) { $0 + $1.pair.size } }
    var pairs: [CardBackupPair] { items.map(\.pair) }
}

enum CardBackupPlanner {
    /// The event folder's files into the backup's event folder, by the same
    /// paths. `existing` is the size of a file already at a path there, nil
    /// when there is none. A file of the same size there counts as copied
    /// (the hashes settle it); a different file is never replaced, the copy
    /// takes `-1`, `-2` as a card import does, or the copy of it an earlier
    /// backup made there.
    static func plan(_ files: [CardBackupFile], existing: (String) -> Int64?) -> CardBackupPlan {
        var plan = CardBackupPlan()
        var taken = Set<String>()
        for file in files {
            let folder = (file.path as NSString).deletingLastPathComponent
            let name = (file.path as NSString).lastPathComponent
            var attempt = 0
            while true {
                let candidate = CardImportPlanner.alternative(name, attempt: attempt)
                let path = folder.isEmpty ? candidate : folder + "/" + candidate
                attempt += 1
                guard taken.insert(path.lowercased()).inserted else { continue }
                if let size = existing(path) {
                    if size == file.size {
                        plan.items.append(.init(pair: CardBackupPair(source: file.path, copy: path, size: file.size),
                                                present: true))
                        break
                    }
                    if attempt < 10_000 { continue }
                }
                plan.items.append(.init(pair: CardBackupPair(source: file.path, copy: path, size: file.size), present: false))
                break
            }
        }
        return plan
    }
}

// MARK: - Comparison

/// A file whose copy cannot be trusted.
enum CardBackupMismatch: Codable, Equatable, Sendable {
    /// The copy is not there.
    case missing(String)
    /// The copy's size differs.
    case size(String, expected: Int64, found: Int64)
    /// Same size, different content.
    case content(String)
    /// The original or the copy could not be read.
    case unreadable(String)

    var file: String {
        switch self {
        case .missing(let file), .size(let file, _, _), .content(let file), .unreadable(let file): return file
        }
    }
}

/// How one pair compares, from what was measured: the sizes on each side
/// (nil when the file is not there) and the hashes (nil when not read).
enum CardBackupComparison {
    static func compare(_ pair: CardBackupPair, sourceSize: Int64?, copySize: Int64?,
                        sourceHash: String?, copyHash: String?) -> CardBackupMismatch? {
        guard sourceSize != nil else { return .unreadable(pair.source) }
        guard let copySize else { return .missing(pair.copy) }
        if copySize != sourceSize { return .size(pair.copy, expected: sourceSize ?? pair.size, found: copySize) }
        guard let sourceHash, let copyHash else { return .unreadable(pair.copy) }
        return sourceHash == copyHash ? nil : .content(pair.copy)
    }
}

// MARK: - Manifest

/// `.zenith-backup.json` in the backup's event folder: every file it holds
/// that matched the import, with its size, SHA-256 and date.
struct CardBackupManifest: Codable, Equatable, Sendable {
    static let fileName = ".zenith-backup.json"

    struct Entry: Codable, Equatable, Sendable {
        /// From the backup's event folder.
        var file: String
        var size: Int64
        var sha256: String
        /// The file's modification date.
        var date: Date
        /// Its path in the import, when it differs.
        var source: String?
    }

    var version = 1
    var event: String
    /// The import's event folder, `~` for the home folder.
    var source: String
    var verified: Date
    var files: [Entry]
    /// Files whose copy did not match, by name.
    var mismatches: [String] = []

    var bytes: Int64 { files.reduce(0) { $0 + $1.size } }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }

    static func decode(_ data: Data) -> CardBackupManifest? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CardBackupManifest.self, from: data)
    }

    static func load(folder: URL) -> CardBackupManifest? {
        (try? Data(contentsOf: folder.appendingPathComponent(fileName, isDirectory: false))).flatMap(decode)
    }

    /// Written whole beside the files, replacing only an older manifest.
    @discardableResult
    func save(folder: URL) -> Bool {
        guard let data = encoded() else { return false }
        return (try? data.write(to: folder.appendingPathComponent(Self.fileName, isDirectory: false), options: .atomic)) != nil
    }
}

// MARK: - Ledger

/// How safe an import is: on this Mac only, copied to a backup, or copied
/// and compared file by file.
enum CardBackupState: String, Codable, Equatable, Sendable {
    case imported, backedUp, verified
}

/// One backup of an event, on one destination.
struct CardBackupCopy: Codable, Equatable, Sendable {
    var destination: String
    var drive: String
    var backedUp: Date
    var verified: Date?
    var files: Int
    var bytes: Int64
    /// Files that did not match at the last verification.
    var problems: Int = 0
}

/// A card that went into an event, and how its check against the import went.
struct CardBackupCard: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var imported: Date
    var verified: Date?
    var problems: Int = 0
}

/// One event folder: what went into it, and where else it is.
struct CardBackupRecord: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var event: String
    /// The event folder, `~` for the home folder.
    var folder: String
    /// The last import into it.
    var imported: Date
    var files: Int
    var bytes: Int64
    var cards: [CardBackupCard] = []
    var copies: [CardBackupCopy] = []
    var reminded: Date?

    /// Copies made since the last import into the folder; an older one
    /// misses what came after it.
    var currentCopies: [CardBackupCopy] { copies.filter { $0.backedUp >= imported } }

    var state: CardBackupState {
        let current = currentCopies
        if current.contains(where: { $0.verified != nil && $0.problems == 0 }) { return .verified }
        return current.isEmpty ? .imported : .backedUp
    }

    /// The best of the current copies, for its drive and its figures.
    var bestCopy: CardBackupCopy? {
        let current = currentCopies
        return current.first { $0.verified != nil && $0.problems == 0 } ?? current.max { $0.backedUp < $1.backedUp }
    }

    func card(_ id: String) -> CardBackupCard? { cards.first { $0.id == id } }
}

struct CardBackupLedger: Codable, Equatable, Sendable {
    static let capacity = 200
    static let fileName = "backups.json"

    private(set) var records: [CardBackupRecord] = []

    init(records: [CardBackupRecord] = []) {
        self.records = Array(records.suffix(Self.capacity))
    }

    func record(_ id: String) -> CardBackupRecord? { records.first { $0.id == id } }

    func record(folder: String) -> CardBackupRecord? { records.first { $0.folder == folder } }

    /// Newest import first.
    var newestFirst: [CardBackupRecord] { records.sorted { $0.imported > $1.imported } }

    /// Events without a verified backup, newest first.
    var pending: [CardBackupRecord] { newestFirst.filter { $0.state != .verified } }

    /// An import into an event folder. A folder already known takes the new
    /// files, which its older copies miss, so its state falls back to imported.
    @discardableResult
    mutating func recordImport(folder: String, event: String, card: String, cardName: String,
                               files: Int, bytes: Int64, at date: Date, id: String = UUID().uuidString) -> String {
        if let index = records.firstIndex(where: { $0.folder == folder }) {
            records[index].imported = max(date, records[index].imported)
            records[index].files += files
            records[index].bytes += bytes
            records[index].event = event
            records[index].reminded = nil
            if let at = records[index].cards.firstIndex(where: { $0.id == card }) {
                records[index].cards[at].imported = date
                records[index].cards[at].verified = nil
            } else {
                records[index].cards.append(CardBackupCard(id: card, name: cardName, imported: date))
            }
            return records[index].id
        }
        records.append(CardBackupRecord(id: id, event: event, folder: folder, imported: date, files: files, bytes: bytes,
                                        cards: [CardBackupCard(id: card, name: cardName, imported: date)]))
        if records.count > Self.capacity { records.removeFirst(records.count - Self.capacity) }
        return id
    }

    /// The event copied to a destination; unverified until `recordVerification`.
    mutating func recordBackup(_ id: String, destination: String, drive: String, files: Int, bytes: Int64, at date: Date) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].copies.removeAll { $0.destination == destination }
        records[index].copies.append(CardBackupCopy(destination: destination, drive: drive, backedUp: date,
                                                    verified: nil, files: files, bytes: bytes))
    }

    /// Every file of a destination's copy compared; `problems` did not match.
    mutating func recordVerification(_ id: String, destination: String, problems: Int, at date: Date) {
        guard let index = records.firstIndex(where: { $0.id == id }),
              let copy = records[index].copies.firstIndex(where: { $0.destination == destination }) else { return }
        records[index].copies[copy].verified = date
        records[index].copies[copy].problems = problems
    }

    /// A card compared with what came off it.
    mutating func recordCardCheck(_ id: String, card: String, problems: Int, at date: Date) {
        guard let index = records.firstIndex(where: { $0.id == id }),
              let at = records[index].cards.firstIndex(where: { $0.id == card }) else { return }
        records[index].cards[at].verified = date
        records[index].cards[at].problems = problems
    }

    mutating func markReminded(_ ids: [String], at date: Date) {
        for index in records.indices where ids.contains(records[index].id) { records[index].reminded = date }
    }

    mutating func remove(_ id: String) { records.removeAll { $0.id == id } }

    static func load(folder: URL) -> CardBackupLedger {
        let url = folder.appendingPathComponent(fileName, isDirectory: false)
        guard let data = try? Data(contentsOf: url) else { return CardBackupLedger() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(CardBackupLedger.self, from: data)) ?? CardBackupLedger()
    }

    func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
}

/// What came off each card into an event, card path to event path, kept
/// beside the ledger so the card can be compared with the import later.
enum CardBackupPairs {
    static func fileName(record: String) -> String {
        "pairs-" + CardImportLedger.fileName(volume: record).dropFirst("ledger-".count)
    }

    static func decode(_ data: Data) -> [String: [CardBackupPair]] {
        (try? JSONDecoder().decode([String: [CardBackupPair]].self, from: data)) ?? [:]
    }

    static func encode(_ pairs: [String: [CardBackupPair]]) -> Data? { try? JSONEncoder().encode(pairs) }

    /// New pairs for a card, replacing an earlier pair for the same card file.
    static func merging(_ new: [CardBackupPair], card: String, into pairs: [String: [CardBackupPair]]) -> [String: [CardBackupPair]] {
        var all = pairs
        var list = all[card] ?? []
        let replaced = Set(new.map(\.source))
        list.removeAll { replaced.contains($0.source) }
        all[card] = list + new
        return all
    }
}

// MARK: - Reminders

enum CardBackupReminder {
    /// Events to remind about now: without a verified backup, imported at
    /// least `delay` ago, and not reminded about within the last `delay`
    /// (since their last import). Nil `delay` is off.
    static func due(_ records: [CardBackupRecord], now: Date, delay: TimeInterval?) -> [CardBackupRecord] {
        guard let delay, delay > 0 else { return [] }
        return records.filter { record in
            guard record.state != .verified, now.timeIntervalSince(record.imported) >= delay else { return false }
            guard let reminded = record.reminded, reminded >= record.imported else { return true }
            return now.timeIntervalSince(reminded) >= delay
        }
    }

    /// When the next one comes due, for the timer; nil when none will.
    static func nextCheck(_ records: [CardBackupRecord], now: Date, delay: TimeInterval?) -> Date? {
        guard let delay, delay > 0 else { return nil }
        let dates: [Date] = records.compactMap { record in
            guard record.state != .verified else { return nil }
            var next = record.imported.addingTimeInterval(delay)
            if let reminded = record.reminded, reminded >= record.imported {
                next = max(next, reminded.addingTimeInterval(delay))
            }
            return max(next, now)
        }
        return dates.min()
    }
}

// MARK: - Activity

enum CardBackupStage: Equatable, Sendable {
    case copying, verifying
}

enum CardBackupFailure: Equatable, Sendable {
    /// Files whose copy does not match.
    case mismatches(Int)
    /// The backup drive went away during the backup.
    case driveRemoved
    /// The import's folder, or the card, is not there.
    case sourceMissing
    /// The backup drive has no room; how much more it takes.
    case diskFull(needed: Int64)
    /// A file could not be copied; its name.
    case failed(file: String)
}

/// What the closed island shows for a backup or a check: under way, done, failed.
enum CardBackupActivity: Equatable, Sendable {
    /// `totalFiles` fixes how wide the reading gets.
    case running(CardBackupStage, totalFiles: Int)
    /// `verified` when every file was compared and matched.
    case finished(files: Int, bytes: Int64, verified: Bool)
    case failed(CardBackupFailure)
}

enum CardBackupTiming {
    static let finishedHold: TimeInterval = 8
    static let failedHold: TimeInterval = 15
    /// Between two readings of the job.
    static let poll: TimeInterval = 0.1
    /// Between two looks at what is due for a reminder, besides the exact time.
    static let reminderCheck: TimeInterval = 15 * 60
    static let spaceMargin: Int64 = 256 * 1024 * 1024
}

// MARK: - Formatting

enum CardBackupFormat {
    static func files(_ count: Int, text: ZenithCardBackupStrings, language: AppLanguage) -> String {
        CardImportFormat.counted(count, forms: text.files, agreement: language.countAgreement,
                                 locale: language.formattingLocale())
    }

    static func events(_ count: Int, text: ZenithCardBackupStrings, language: AppLanguage) -> String {
        CardImportFormat.counted(count, forms: text.events, agreement: language.countAgreement,
                                 locale: language.formattingLocale())
    }

    /// `Verified 1,248 files · 52 GB`.
    static func verified(files count: Int, bytes: Int64, text: ZenithCardBackupStrings, language: AppLanguage) -> String {
        CardImportFormat.filling(text.verifiedSummary, files(count, text: text, language: language) + " · "
                                 + CardImportFormat.bytes(bytes))
    }

    /// The reminder's title: `2 events not backed up`, or `not verified`
    /// when each of them has a copy that was not compared.
    static func reminderTitle(_ records: [CardBackupRecord], text: ZenithCardBackupStrings, language: AppLanguage) -> String {
        let template = records.contains { $0.state == .imported } ? text.notBackedUp : text.notVerified
        return CardImportFormat.filling(template, events(records.count, text: text, language: language))
    }

    /// Up to three event names, then how many more.
    static func eventList(_ records: [CardBackupRecord], language: AppLanguage) -> String {
        let names = records.prefix(3).map(\.event)
        let more = records.count - names.count
        return (names + (more > 0 ? ["+" + CardImportFormat.count(more, locale: language.formattingLocale())] : []))
            .joined(separator: " · ")
    }

    /// What a failure reads as, short.
    static func failure(_ failure: CardBackupFailure, text: ZenithCardBackupStrings, language: AppLanguage) -> String {
        switch failure {
        case .mismatches(let count):
            return CardImportFormat.counted(count, forms: text.mismatches, agreement: language.countAgreement,
                                            locale: language.formattingLocale())
        case .driveRemoved: return text.driveRemoved
        case .sourceMissing: return text.sourceMissing
        case .diskFull: return text.driveFull
        case .failed: return text.stopped
        }
    }
}
