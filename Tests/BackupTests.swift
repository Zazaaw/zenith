// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation

/// Zenith fork: verified backups of card imports. Destinations, settings,
/// the plan, the ledger, the reminders and the strings run on pure values;
/// hashing, the manifest, the comparison, the backup and the card check run
/// end to end in temporary folders. No real volume is read or written.
enum BackupTests {
    static func run(_ suite: TestSuite) {
        identity(suite)
        destinations(suite)
        settings(suite)
        planning(suite)
        hashing(suite)
        manifest(suite)
        comparison(suite)
        ledger(suite)
        reminders(suite)
        formatting(suite)
        backupEndToEnd(suite)
        mismatchesEndToEnd(suite)
        cardCheck(suite)
        failures(suite)
        activity(suite)
        strings(suite)
    }

    /// 2026-11-20 10:15:02 UTC.
    private static let t0 = Date(timeIntervalSince1970: 1_795_169_702)
    private static let hour: TimeInterval = 3600

    private static func temporaryFolder(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-backup-tests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func bytes(_ count: Int, seed: Int) -> Data {
        Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ seed) })
    }

    @discardableResult
    private static func write(_ root: URL, _ path: String, _ data: Data) -> URL {
        let url = root.appendingPathComponent(path, isDirectory: false)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
        return url
    }

    private static func contents(_ root: URL, _ path: String) -> Data? {
        try? Data(contentsOf: root.appendingPathComponent(path, isDirectory: false))
    }

    private static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Identity

    private static func identity(_ suite: TestSuite) {
        suite.expect(CardBackupVolumeIdentity.key(uuid: " 8f1b-11e0 ", remountURL: nil, name: "T7", capacity: 1) == "8F1B-11E0",
                     "a drive is known by its volume UUID, whatever its case")
        let share = CardBackupVolumeIdentity.key(uuid: nil, remountURL: URL(string: "smb://faiz@NAS.local/Photos/"),
                                                 name: "Photos", capacity: 9)
        suite.expect(share == "share:smb://nas.local/Photos",
                     "a share without a UUID is known by its address, without the account")
        suite.expect(CardBackupVolumeIdentity.key(uuid: "", remountURL: nil, name: "T7", capacity: 500) == "name:T7-500",
                     "a drive that says neither is known by its name and capacity")
        suite.expect(CardBackupVolumeIdentity.key(uuid: "A", remountURL: URL(string: "smb://nas/x"), name: "x", capacity: 1) == "A",
                     "a UUID wins over an address")
    }

    private static func destinations(_ suite: TestSuite) {
        let t7 = CardBackupVolume(key: "8F1B", name: "T7 Shield", url: URL(fileURLWithPath: "/Volumes/T7 Shield", isDirectory: true))
        let folder = URL(fileURLWithPath: "/Volumes/T7 Shield/Backups/Zenith", isDirectory: true)
        let destination = CardBackupDestination.make(folder: folder, on: t7, id: "d1")
        suite.expect(destination == CardBackupDestination(id: "d1", volume: "8F1B", volumeName: "T7 Shield", path: "Backups/Zenith"),
                     "a folder becomes its drive's identity and its path from the drive's root")
        suite.expect(CardBackupDestination.make(folder: t7.url, on: t7, id: "r")?.path == ""
                        && CardBackupDestination.make(folder: URL(fileURLWithPath: "/Volumes/Other/x"), on: t7) == nil,
                     "the root is an empty path, and a folder on another drive is not on this one")
        let root = CardBackupVolume(key: "MAC", name: "Macintosh HD", url: URL(fileURLWithPath: "/", isDirectory: true))
        suite.expect(CardBackupDestination.make(folder: URL(fileURLWithPath: "/Users/faiz/Backup"), on: root)?.path == "Users/faiz/Backup",
                     "a folder on the startup disk keeps its whole path")

        guard let destination else { return }
        suite.expect(destination.folder(in: []) == nil && destination.mountedVolume(in: []) == nil,
                     "a drive that is away has no folder")
        let again = CardBackupVolume(key: "8F1B", name: "T7 Shield", url: URL(fileURLWithPath: "/Volumes/T7 Shield 1", isDirectory: true))
        let other = CardBackupVolume(key: "OTHER", name: "T7 Shield", url: URL(fileURLWithPath: "/Volumes/T7 Shield", isDirectory: true))
        suite.expect(destination.folder(in: [other, again])?.path == "/Volumes/T7 Shield 1/Backups/Zenith",
                     "the drive is found by its identity wherever it mounts, not by its name or mount point")
        suite.expect(destination.displayPath == "T7 Shield/Backups/Zenith", "Settings shows the drive and the path")

        let nas = CardBackupDestination(id: "d2", volume: "share:smb://nas/Photos", volumeName: "Photos", path: "")
        var list = CardBackupDestinations.adding(destination, to: [])
        list = CardBackupDestinations.adding(destination, to: list)
        suite.expect(list.count == 1, "the same folder is not added twice")
        list = CardBackupDestinations.adding(nas, to: list)
        let third = CardBackupDestination(id: "d3", volume: "X", volumeName: "X", path: "")
        suite.expect(CardBackupDestinations.adding(third, to: list).count == 2, "two destinations at most")
        suite.expect(CardBackupDestinations.decode(CardBackupDestinations.encode(list)) == list
                        && CardBackupDestinations.decode("nonsense").isEmpty && CardBackupDestinations.decode(nil).isEmpty
                        && CardBackupDestinations.encode([]) == "",
                     "destinations read back as stored, and nothing else reads as any")
    }

    private static func settings(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.card-backup"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let fresh = CardBackupSettings.current(in: defaults)
        suite.expect(fresh == CardBackupSettings() && !fresh.automatic && fresh.verify && fresh.reminderHours == 24
                        && fresh.reminderDelay == 24 * hour,
                     "before anything is set: no automatic backup, verified, reminded after a day")
        defaults.set(0, forKey: DefaultsKey.notchCardBackupReminderHours)
        defaults.set(true, forKey: DefaultsKey.notchCardBackupAutomatic)
        defaults.set(false, forKey: DefaultsKey.notchCardBackupVerify)
        let chosen = CardBackupSettings.current(in: defaults)
        suite.expect(chosen.reminderDelay == nil && chosen.automatic && !chosen.verify, "the reminder turns off; the switches read back")
        defaults.set(7, forKey: DefaultsKey.notchCardBackupReminderHours)
        suite.expect(CardBackupSettings.current(in: defaults).reminderHours == 24, "an hour count not offered reads as a day")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchCardBackupDestinations] as? String == ""
                        && Defaults.registeredDefaults[DefaultsKey.notchCardBackupAutomatic] as? Bool == false
                        && Defaults.registeredDefaults[DefaultsKey.notchCardBackupVerify] as? Bool == true
                        && Defaults.registeredDefaults[DefaultsKey.notchCardBackupReminderHours] as? Int == 24,
                     "the backup preferences are registered, so they join the settings backup")
    }

    // MARK: Plan

    private static func planning(_ suite: TestSuite) {
        let files = [CardBackupFile(path: "JPG/A.JPG", size: 10), CardBackupFile(path: "RAW/B.ARW", size: 20),
                     CardBackupFile(path: "Video/C.MP4", size: 30), CardBackupFile(path: "notes.txt", size: 5)]
        let existing: [String: Int64] = ["JPG/A.JPG": 10, "RAW/B.ARW": 99]
        let plan = CardBackupPlanner.plan(files) { existing[$0] }
        suite.expect(plan.items.map(\.pair.copy) == ["JPG/A.JPG", "RAW/B-1.ARW", "Video/C.MP4", "notes.txt"]
                        && plan.items.map(\.present) == [true, false, false, false],
                     "the same structure; a file of the same size is there already, a different one is never replaced")
        suite.expect(plan.copies.count == 3 && plan.copyBytes == 55 && plan.bytes == 65 && plan.pairs.first?.source == "JPG/A.JPG",
                     "only what is missing is copied; every file is compared")
        let healed = CardBackupPlanner.plan(files) { ["JPG/A.JPG": 10, "RAW/B.ARW": 99, "RAW/B-1.ARW": 20][$0] }
        suite.expect(healed.items[1].pair.copy == "RAW/B-1.ARW" && healed.items[1].present,
                     "the copy an earlier backup set beside a different file is found again")
        let cased = CardBackupPlanner.plan([CardBackupFile(path: "x.jpg", size: 1), CardBackupFile(path: "X.JPG", size: 2)]) { _ in nil }
        suite.expect(cased.items.map(\.pair.copy) == ["x.jpg", "X-1.JPG"],
                     "two names that differ only in case do not share one place on a drive that ignores case")
        suite.expect(CardBackupPlanner.plan([]) { _ in nil }.items.isEmpty, "an empty event plans nothing")
    }

    // MARK: Hashing and manifest

    private static func hashing(_ suite: TestSuite) {
        let folder = temporaryFolder("hash")
        defer { try? FileManager.default.removeItem(at: folder) }
        let abc = write(folder, "abc.txt", Data("abc".utf8))
        let empty = write(folder, "empty", Data())
        let large = bytes(300_000, seed: 7)
        let big = write(folder, "big.bin", large)
        suite.expect((try? CardBackupHasher.sha256(of: abc)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                     "SHA-256 of a known value")
        suite.expect((try? CardBackupHasher.sha256(of: empty)) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                     "SHA-256 of an empty file")
        var heard = 0
        let streamed = try? CardBackupHasher.sha256(of: big, chunkSize: 64 * 1024, progress: { heard += $0 })
        suite.expect(streamed == hex(large) && heard == large.count,
                     "a file read in chunks hashes as it would whole, and every byte is counted")
        var unreadable = false
        do { unreadable = try CardBackupHasher.sha256(of: folder.appendingPathComponent("missing")) == nil } catch {}
        suite.expect(unreadable,
                     "a file that cannot be read has no hash")
        var cancelled = false
        do {
            _ = try CardBackupHasher.sha256(of: big, isCancelled: { true })
        } catch {
            cancelled = (error as? CardBackupError) == .cancelled
        }
        suite.expect(cancelled, "hashing stops when the job is stopped")
        let value = CardBackupHasher.lowPriority { 42 }
        suite.expect(value == 42, "work runs at low I/O priority and gives back its result")
    }

    private static func manifest(_ suite: TestSuite) {
        let folder = temporaryFolder("manifest")
        defer { try? FileManager.default.removeItem(at: folder) }
        let manifest = CardBackupManifest(event: "2026-11-20 Wisuda", source: "~/Pictures/Imports/2026-11-20 Wisuda", verified: t0,
                                          files: [.init(file: "RAW/A.ARW", size: 20, sha256: String(repeating: "a", count: 64),
                                                        date: t0, source: nil),
                                                  .init(file: "JPG/B-1.JPG", size: 10, sha256: String(repeating: "b", count: 64),
                                                        date: t0.addingTimeInterval(1), source: "JPG/B.JPG")],
                                          mismatches: ["C.MP4"])
        suite.expect(manifest.encoded().flatMap(CardBackupManifest.decode) == manifest, "the manifest reads back as written")
        suite.expect(manifest.save(folder: folder) && CardBackupManifest.load(folder: folder) == manifest
                        && CardBackupManifest.fileName.hasPrefix(".") && manifest.bytes == 30,
                     "it is saved hidden in the backup folder and loads again")
        let json = manifest.encoded().map { String(decoding: $0, as: UTF8.self) } ?? ""
        suite.expect(json.contains("\"sha256\"") && json.contains("\"size\"") && json.contains("\"file\"")
                        && json.contains("\"date\"") && json.contains("2026-11-20T"),
                     "each file has its name, size, SHA-256 and date, readable outside Zenith")
        suite.expect(CardBackupManifest.decode(Data("{".utf8)) == nil && CardBackupManifest.load(folder: temporaryFolder("none")) == nil,
                     "a broken or missing manifest reads as none")
    }

    // MARK: Comparison

    private static func comparison(_ suite: TestSuite) {
        let pair = CardBackupPair(source: "A.JPG", copy: "A-1.JPG", size: 10)
        suite.expect(CardBackupComparison.compare(pair, sourceSize: 10, copySize: 10, sourceHash: "x", copyHash: "x") == nil,
                     "same size and hash: a match")
        suite.expect(CardBackupComparison.compare(pair, sourceSize: 10, copySize: 10, sourceHash: "x", copyHash: "y") == .content("A-1.JPG"),
                     "a changed byte shows as different content")
        suite.expect(CardBackupComparison.compare(pair, sourceSize: 10, copySize: 9, sourceHash: nil, copyHash: nil)
                        == .size("A-1.JPG", expected: 10, found: 9),
                     "a size that differs settles it before any hashing")
        suite.expect(CardBackupComparison.compare(pair, sourceSize: 10, copySize: nil, sourceHash: nil, copyHash: nil) == .missing("A-1.JPG"),
                     "a copy that is not there is missing")
        suite.expect(CardBackupComparison.compare(pair, sourceSize: nil, copySize: 10, sourceHash: nil, copyHash: nil) == .unreadable("A.JPG"),
                     "an original that is not there cannot vouch for its copy")
        suite.expect(CardBackupComparison.compare(pair, sourceSize: 10, copySize: 10, sourceHash: "x", copyHash: nil) == .unreadable("A-1.JPG"),
                     "a copy that cannot be read is no backup")
        suite.expect(CardBackupMismatch.size("RAW/a", expected: 1, found: 2).file == "RAW/a", "a mismatch names its file")
    }

    // MARK: Ledger

    private static func ledger(_ suite: TestSuite) {
        var ledger = CardBackupLedger()
        let id = ledger.recordImport(folder: "~/Pictures/Imports/2026-11-20", event: "2026-11-20", card: "CARD-A",
                                     cardName: "EOS_DIGITAL", files: 10, bytes: 1_000, at: t0, id: "r1")
        suite.expect(id == "r1" && ledger.record("r1")?.state == .imported && ledger.pending.map(\.id) == ["r1"],
                     "an import starts as imported only")
        ledger.recordBackup("r1", destination: "d1", drive: "T7", files: 10, bytes: 1_000, at: t0.addingTimeInterval(60))
        suite.expect(ledger.record("r1")?.state == .backedUp && ledger.record("r1")?.bestCopy?.drive == "T7",
                     "copied but not compared: backed up")
        ledger.recordVerification("r1", destination: "d1", problems: 2, at: t0.addingTimeInterval(120))
        suite.expect(ledger.record("r1")?.state == .backedUp, "a verification that found problems is not verified")
        ledger.recordVerification("r1", destination: "d1", problems: 0, at: t0.addingTimeInterval(180))
        suite.expect(ledger.record("r1")?.state == .verified && ledger.pending.isEmpty, "every file matched: verified")

        // A second card into the same event: its new files are on no backup yet.
        let again = ledger.recordImport(folder: "~/Pictures/Imports/2026-11-20", event: "2026-11-20", card: "CARD-B",
                                        cardName: "NIKON", files: 5, bytes: 500, at: t0.addingTimeInterval(600))
        let record = ledger.record("r1")
        suite.expect(again == "r1" && record?.state == .imported && record?.files == 15 && record?.bytes == 1_500
                        && record?.cards.map(\.id) == ["CARD-A", "CARD-B"],
                     "a new import into an event folds in, and its older backup no longer covers it")
        ledger.recordBackup("r1", destination: "d1", drive: "T7", files: 15, bytes: 1_500, at: t0.addingTimeInterval(700))
        ledger.recordBackup("r1", destination: "d2", drive: "NAS", files: 15, bytes: 1_500, at: t0.addingTimeInterval(700))
        ledger.recordVerification("r1", destination: "d2", problems: 0, at: t0.addingTimeInterval(800))
        suite.expect(ledger.record("r1")?.state == .verified && ledger.record("r1")?.copies.count == 2
                        && ledger.record("r1")?.bestCopy?.drive == "NAS",
                     "a backup again replaces that destination's copy; one verified destination is enough")

        ledger.recordCardCheck("r1", card: "CARD-B", problems: 0, at: t0.addingTimeInterval(900))
        suite.expect(ledger.record("r1")?.card("CARD-B")?.verified != nil && ledger.record("r1")?.card("CARD-A")?.verified == nil,
                     "a card's check is kept per card")
        ledger.recordImport(folder: "~/Pictures/Imports/2026-11-20", event: "2026-11-20", card: "CARD-B",
                            cardName: "NIKON", files: 1, bytes: 10, at: t0.addingTimeInterval(1_000))
        suite.expect(ledger.record("r1")?.card("CARD-B")?.verified == nil, "more off the same card asks for its check again")

        ledger.recordImport(folder: "~/b", event: "b", card: "C", cardName: "C", files: 1, bytes: 1, at: t0.addingTimeInterval(2_000), id: "r2")
        suite.expect(ledger.newestFirst.map(\.id) == ["r2", "r1"] && ledger.record(folder: "~/b")?.id == "r2",
                     "the newest import comes first")
        ledger.remove("r2")
        suite.expect(ledger.record("r2") == nil, "a record can go")

        var full = CardBackupLedger()
        for index in 0..<(CardBackupLedger.capacity + 5) {
            full.recordImport(folder: "~/e\(index)", event: "e\(index)", card: "c", cardName: "c", files: 1, bytes: 1,
                              at: t0.addingTimeInterval(Double(index)), id: "e\(index)")
        }
        suite.expect(full.records.count == CardBackupLedger.capacity && full.record("e0") == nil
                        && full.record("e\(CardBackupLedger.capacity + 4)") != nil,
                     "the ledger keeps the newest imports")

        let folder = temporaryFolder("ledger")
        defer { try? FileManager.default.removeItem(at: folder) }
        try? ledger.encoded()?.write(to: folder.appendingPathComponent(CardBackupLedger.fileName))
        suite.expect(CardBackupLedger.load(folder: folder) == ledger && CardBackupLedger.load(folder: temporaryFolder("empty")).records.isEmpty,
                     "the ledger reads back from its file, and a missing file reads as empty")

        let pairs = CardBackupPairs.merging([CardBackupPair(source: "DCIM/1.JPG", copy: "JPG/1.JPG", size: 1)], card: "A", into: [:])
        let merged = CardBackupPairs.merging([CardBackupPair(source: "DCIM/1.JPG", copy: "JPG/1-1.JPG", size: 1),
                                              CardBackupPair(source: "DCIM/2.JPG", copy: "JPG/2.JPG", size: 2)], card: "A", into: pairs)
        suite.expect(merged["A"]?.map(\.copy) == ["JPG/1-1.JPG", "JPG/2.JPG"]
                        && CardBackupPairs.encode(merged).map(CardBackupPairs.decode) == merged
                        && CardBackupPairs.fileName(record: "a/b") == "pairs-a_b.json",
                     "where each card file landed is kept, the newest landing of a file winning")
    }

    // MARK: Reminders

    private static func reminders(_ suite: TestSuite) {
        var ledger = CardBackupLedger()
        ledger.recordImport(folder: "~/a", event: "a", card: "c", cardName: "c", files: 1, bytes: 1, at: t0, id: "a")
        let day = 24 * hour
        suite.expect(CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(23 * hour), delay: day).isEmpty,
                     "nothing is due before the delay")
        suite.expect(CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(day), delay: day).map(\.id) == ["a"],
                     "an import without a verified backup is due after the delay")
        suite.expect(CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(99 * day), delay: nil).isEmpty
                        && CardBackupReminder.nextCheck(ledger.records, now: t0, delay: nil) == nil,
                     "with the reminder off nothing is ever due")
        suite.expect(CardBackupReminder.nextCheck(ledger.records, now: t0, delay: day) == t0.addingTimeInterval(day),
                     "the timer aims at the moment it comes due")
        ledger.markReminded(["a"], at: t0.addingTimeInterval(day))
        suite.expect(CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(30 * hour), delay: day).isEmpty
                        && CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(2 * day), delay: day).map(\.id) == ["a"]
                        && CardBackupReminder.nextCheck(ledger.records, now: t0.addingTimeInterval(30 * hour), delay: day)
                            == t0.addingTimeInterval(2 * day),
                     "once reminded, it waits another delay before the next reminder")
        ledger.recordImport(folder: "~/a", event: "a", card: "c", cardName: "c", files: 1, bytes: 1,
                            at: t0.addingTimeInterval(36 * hour))
        suite.expect(ledger.record("a")?.reminded == nil
                        && CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(48 * hour), delay: day).isEmpty
                        && CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(60 * hour), delay: day).map(\.id) == ["a"],
                     "a new import into the event starts its delay again")
        ledger.recordBackup("a", destination: "d", drive: "T7", files: 2, bytes: 2, at: t0.addingTimeInterval(61 * hour))
        suite.expect(CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(90 * hour), delay: day).map(\.id) == ["a"],
                     "a backup that was never verified still reminds")
        ledger.recordVerification("a", destination: "d", problems: 0, at: t0.addingTimeInterval(62 * hour))
        suite.expect(CardBackupReminder.due(ledger.records, now: t0.addingTimeInterval(200 * hour), delay: day).isEmpty
                        && CardBackupReminder.nextCheck(ledger.records, now: t0, delay: day) == nil,
                     "a verified backup ends the reminders")
    }

    private static func formatting(_ suite: TestSuite) {
        let text = ZenithStrings.cardBackup(.enUS)
        var ledger = CardBackupLedger()
        for (index, name) in ["Wisuda", "Pensi", "Lomba", "Rapat"].enumerated() {
            ledger.recordImport(folder: "~/\(name)", event: name, card: "c", cardName: "c", files: 1, bytes: 1,
                                at: t0.addingTimeInterval(Double(index)), id: name)
        }
        let two = Array(ledger.newestFirst.prefix(2))
        suite.expect(CardBackupFormat.reminderTitle(two, text: text, language: .enUS) == "2 events not backed up",
                     "the reminder counts the events not backed up")
        ledger.recordBackup("Rapat", destination: "d", drive: "T7", files: 1, bytes: 1, at: t0.addingTimeInterval(10))
        suite.expect(CardBackupFormat.reminderTitle([ledger.record("Rapat")!], text: text, language: .enUS) == "1 event not verified",
                     "copied but never compared reads as not verified")
        suite.expect(CardBackupFormat.eventList(ledger.newestFirst, language: .enUS) == "Rapat · Lomba · Pensi · +1",
                     "the notice names three events, then how many more")
        let verified = CardBackupFormat.verified(files: 1_248, bytes: 52_000_000_000, text: text, language: .enUS)
        let files = CardBackupFormat.files(1_248, text: text, language: .enUS)
        suite.expect(verified == "Verified " + files + " · " + CardImportFormat.bytes(52_000_000_000)
                        && files.hasSuffix(" files") && files.hasPrefix("1") && files.contains("248"),
                     "a verified backup reads like Verified 1,248 files · 52 GB: \(verified)")
        suite.expect(CardBackupFormat.failure(.mismatches(3), text: text, language: .enUS) == "3 files don’t match"
                        && CardBackupFormat.failure(.mismatches(1), text: text, language: .enUS) == "1 file doesn’t match"
                        && CardBackupFormat.failure(.driveRemoved, text: text, language: .enUS) == "Backup drive removed",
                     "a failure says what went wrong")
        suite.expect(CardBackupFormat.files(5, text: ZenithStrings.cardBackup(.ru), language: .ru) == "5 файлов"
                        && CardBackupFormat.files(2, text: ZenithStrings.cardBackup(.ru), language: .ru) == "2 файла",
                     "counts agree with their number in Russian")
    }

    // MARK: End to end

    /// An event folder as a card import leaves it.
    private static func event(_ root: URL) -> [String: Data] {
        let files: [String: Data] = ["RAW/DSC00001.ARW": bytes(300_000, seed: 1), "JPG/DSC00001.JPG": bytes(5_000, seed: 2),
                                     "Video/C0001.MP4": bytes(1_000_000, seed: 3)]
        for (path, data) in files { write(root, path, data) }
        write(root, ".DS_Store", Data("finder".utf8))
        return files
    }

    private static func backupEndToEnd(_ suite: TestSuite) {
        let fm = FileManager.default
        let imports = temporaryFolder("imports")
        let drive = temporaryFolder("drive")
        defer { [imports, drive].forEach { try? fm.removeItem(at: $0) } }
        let source = imports.appendingPathComponent("2026-11-20 Wisuda", isDirectory: true)
        let files = event(source)
        let target = drive.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        // Something else already sits where the video would go.
        write(target, "Video/C0001.MP4", Data("other".utf8))
        let before = files.keys.sorted().map { contents(source, $0) }

        let job = CardBackupJob(source: source, destination: target, chunkSize: 64 * 1024)
        let outcome = job.runBackup(event: "2026-11-20 Wisuda", sourceName: "~/Pictures/Imports/2026-11-20 Wisuda",
                                    verify: true, now: { t0 })
        suite.expect(outcome.error == nil && outcome.verified && outcome.mismatches.isEmpty && outcome.copiedFiles == 3
                        && outcome.files == 3 && outcome.bytes == 1_305_000,
                     "an event backs up and every file verifies")
        suite.expect(contents(target, "RAW/DSC00001.ARW") == files["RAW/DSC00001.ARW"]
                        && contents(target, "JPG/DSC00001.JPG") == files["JPG/DSC00001.JPG"]
                        && contents(target, "Video/C0001-1.MP4") == files["Video/C0001.MP4"],
                     "the backup has the same structure and the same bytes")
        suite.expect(contents(target, "Video/C0001.MP4") == Data("other".utf8),
                     "a different file already on the backup is never replaced; the copy goes beside it")
        suite.expect(!fm.fileExists(atPath: target.appendingPathComponent(".DS_Store").path)
                        && ((try? fm.contentsOfDirectory(atPath: target.appendingPathComponent("RAW").path)) ?? [])
                            .allSatisfy { !$0.hasSuffix(CardImportJob.partialSuffix) },
                     "hidden files stay behind and no partial file is left")
        suite.expect(files.keys.sorted().map { contents(source, $0) } == before
                        && fm.fileExists(atPath: source.appendingPathComponent(".DS_Store").path),
                     "the import it read from is untouched")

        let manifest = CardBackupManifest.load(folder: target)
        suite.expect(manifest?.files.count == 3 && manifest?.event == "2026-11-20 Wisuda" && manifest?.verified == t0
                        && manifest?.files.first { $0.file == "RAW/DSC00001.ARW" }?.sha256 == hex(files["RAW/DSC00001.ARW"]!)
                        && manifest?.files.first { $0.file == "Video/C0001-1.MP4" }?.source == "Video/C0001.MP4"
                        && manifest?.mismatches.isEmpty == true,
                     "the manifest lists every file with its SHA-256, and where a moved copy came from")

        let state = job.snapshot()
        suite.expect(state.finished && state.stage == .verifying && state.doneFiles == 3 && state.doneBytes == state.totalBytes
                        && state.totalBytes == 2 * 1_305_000,
                     "the verification counts both sides of every file")

        let again = CardBackupJob(source: source, destination: target).runBackup(event: "e", sourceName: "s", verify: true)
        suite.expect(again.error == nil && again.copiedFiles == 0 && again.verified && again.files == 3,
                     "backing up again copies nothing new and verifies everything")

        write(source, "JPG/DSC00002.JPG", bytes(2_000, seed: 9))
        let more = CardBackupJob(source: source, destination: target).runBackup(event: "e", sourceName: "s", verify: false)
        suite.expect(more.error == nil && more.copiedFiles == 1 && !more.verified && more.files == 4,
                     "a file added later is copied; without verification the backup is only copied")
    }

    private static func mismatchesEndToEnd(_ suite: TestSuite) {
        let fm = FileManager.default
        let source = temporaryFolder("mismatch-source")
        let target = temporaryFolder("mismatch-target")
        defer { [source, target].forEach { try? fm.removeItem(at: $0) } }
        let files = event(source)
        _ = CardBackupJob(source: source, destination: target).runBackup(event: "e", sourceName: "s", verify: true)
        let pairs = files.keys.sorted().map { CardBackupPair(source: $0, copy: $0, size: Int64(files[$0]!.count)) }

        // One changed byte, one missing file, one cut short.
        var changed = files["RAW/DSC00001.ARW"]!
        changed[150_000] ^= 0xFF
        write(target, "RAW/DSC00001.ARW", changed)
        try? fm.removeItem(at: target.appendingPathComponent("JPG/DSC00001.JPG"))
        write(target, "Video/C0001.MP4", files["Video/C0001.MP4"]!.prefix(999_000))

        let check = CardBackupJob(source: source, destination: target, chunkSize: 64 * 1024).runCheck(pairs)
        suite.expect(check.error == nil && check.verified && check.mismatches.count == 3,
                     "every file is still compared when some do not match")
        suite.expect(check.mismatches.contains(.content("RAW/DSC00001.ARW"))
                        && check.mismatches.contains(.missing("JPG/DSC00001.JPG"))
                        && check.mismatches.contains(.size("Video/C0001.MP4", expected: 1_000_000, found: 999_000)),
                     "a changed byte, a missing file and a size mismatch are each found")
        suite.expect(contents(source, "RAW/DSC00001.ARW") == files["RAW/DSC00001.ARW"],
                     "the check reads, and never writes")
    }

    private static func cardCheck(_ suite: TestSuite) {
        let fm = FileManager.default
        let card = temporaryFolder("card")
        let base = temporaryFolder("card-imports")
        defer { [card, base].forEach { try? fm.removeItem(at: $0) } }
        let shot = Date(timeIntervalSince1970: 1_795_169_702)
        for (index, name) in ["DSC00001.ARW", "DSC00001.JPG", "DSC00002.JPG"].enumerated() {
            write(card, "DCIM/100MSDCF/" + name, bytes(70_000 + index * 1_000, seed: index))
            try? fm.setAttributes([.creationDate: shot, .modificationDate: shot],
                                  ofItemAtPath: card.appendingPathComponent("DCIM/100MSDCF/" + name).path)
        }
        let event = base.appendingPathComponent("2026-11-20", isDirectory: true)
        let plan = CardImportPlanner.plan(CardScanner.scan(root: card).files, options: CardImportOptions())
        let importJob = CardImportJob(source: card, destination: event, removalGrace: 0)
        importJob.run(plan)
        let placed = importJob.drain().placed
        suite.expect(placed.count == 3 && placed.contains(CardBackupPair(source: "DCIM/100MSDCF/DSC00001.ARW",
                                                                         copy: "RAW/DSC00001.ARW", size: 70_000)),
                     "a card import reports where each card file landed")
        let cardBefore = (try? fm.contentsOfDirectory(atPath: card.appendingPathComponent("DCIM/100MSDCF").path))?.sorted()

        let clean = CardBackupJob(source: card, destination: event, chunkSize: 64 * 1024).runCheck(placed)
        suite.expect(clean.error == nil && clean.verified && clean.mismatches.isEmpty && clean.files == 3,
                     "the card matches its import, file by file")
        var changed = contents(event, "JPG/DSC00002.JPG")!
        changed[0] ^= 0x01
        write(event, "JPG/DSC00002.JPG", changed)
        let dirty = CardBackupJob(source: card, destination: event).runCheck(placed)
        suite.expect(dirty.mismatches == [.content("JPG/DSC00002.JPG")], "a copy that differs from the card is named")
        suite.expect((try? fm.contentsOfDirectory(atPath: card.appendingPathComponent("DCIM/100MSDCF").path))?.sorted() == cardBefore
                        && contents(card, "DCIM/100MSDCF/DSC00002.JPG") == bytes(72_000, seed: 2),
                     "nothing on the card is written, moved or deleted")
        try? fm.removeItem(at: card)
        let gone = CardBackupJob(source: card, destination: event).runCheck(placed)
        suite.expect(gone.error == .sourceMissing && !gone.verified, "a card that left cannot be checked")
    }

    private static func failures(_ suite: TestSuite) {
        let fm = FileManager.default
        let drive = temporaryFolder("failures")
        defer { try? fm.removeItem(at: drive) }
        let missing = CardBackupJob(source: drive.appendingPathComponent("nowhere"), destination: drive.appendingPathComponent("x"))
            .runBackup(event: "e", sourceName: "s", verify: true)
        suite.expect(missing.error == .sourceMissing, "an import folder that is gone fails as missing")
        let source = temporaryFolder("failures-source")
        defer { try? fm.removeItem(at: source) }
        _ = event(source)
        let stopped = CardBackupJob(source: source, destination: drive.appendingPathComponent("y"))
        stopped.cancel()
        suite.expect(stopped.runBackup(event: "e", sourceName: "s", verify: true).error == .cancelled
                        && stopped.snapshot().finished,
                     "a stopped backup ends as stopped")
        suite.expect(CardBackupJob.shortfall(0, in: drive) == nil && CardBackupJob.shortfall(1, in: drive) == nil
                        && CardBackupJob.shortfall(Int64.max / 2, in: drive.appendingPathComponent("new/folder")) != nil,
                     "free space is checked against the nearest folder that exists")
        suite.expect(CardBackupJob(source: source, destination: drive).destinationAvailable, "a drive still here is available")
    }

    // MARK: Activity and strings

    private static func activity(_ suite: TestSuite) {
        let running = CardImportActivity.backup(.running(.verifying, totalFiles: 12))
        suite.expect(running.showsProgress && running.runningFiles == 12
                        && CardImportActivity.copying(totalFiles: 3).runningFiles == 3
                        && !CardImportActivity.backup(.finished(files: 1, bytes: 1, verified: true)).showsProgress
                        && CardImportActivity.backup(.failed(.driveRemoved)).runningFiles == nil,
                     "a backup under way shows a percentage in the card import's place; one that ended does not")
        let notice = ZenithNotice(kind: .card, key: ZenithNoticeKey.cardBackup, title: "2 events not backed up",
                                  subtitle: "Wisuda · Pensi", glyph: .symbol("externaldrive.badge.exclamationmark", .amber),
                                  accessory: .action("Back up"), action: .backUpCards)
        suite.expect(notice.priority == ZenithNotice.Kind.card.priority && notice.key != ZenithNoticeKey.card("cardBackup")
                        && ZenithNoticeKey.cardBackup == "card-backup",
                     "the reminder ranks as a card and is one notice of its own")
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(notice, now: 0)
        var again = notice
        again.title = "3 events not backed up"
        suite.expect(queue.enqueue(again, now: 1) == .coalesced && queue.pending.count == 1,
                     "a newer reminder updates the waiting one")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.cardBackup(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            let forms = text.files + text.events + text.mismatches
            suite.expect(values.count == 48 && (values + forms).allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words the backup, with curly apostrophes and no em dash")
            suite.expect(text.files.count == 3 && text.events.count == 3 && text.mismatches.count == 3
                            && forms.allSatisfy { $0.contains("%@") },
                         "\(language.rawValue) counts files, events and mismatches in three forms")
            suite.expect([text.connectDrive, text.backedUpTo, text.verifiedSummary, text.notBackedUp, text.notVerified,
                          text.driveConnected, text.hours].allSatisfy { $0.contains("%@") },
                         "\(language.rawValue) places its values")
        }
    }
}
