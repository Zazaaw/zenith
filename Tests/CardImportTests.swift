// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Darwin
import Foundation

/// Zenith fork: importing camera cards. Detection, classification, the
/// destination plan, the ledger, the ETA and the strings run on pure values;
/// the scan and the copy run end to end on a card laid out in a temporary
/// folder. No real volume is read, mounted or ejected.
enum CardImportTests {
    static func run(_ suite: TestSuite) {
        detection(suite)
        classification(suite)
        destination(suite)
        planning(suite)
        renaming(suite)
        collisions(suite)
        ledger(suite)
        eta(suite)
        progress(suite)
        formatting(suite)
        copyEndToEnd(suite)
        copyFailures(suite)
        island(suite)
        notice(suite)
        strings(suite)
    }

    private static let utc = TimeZone(identifier: "UTC")!
    /// 2026-11-20 10:15:02 UTC.
    private static let shot = Date(timeIntervalSince1970: 1_795_169_702)

    private static func file(_ path: String, size: Int64 = 100, at date: Date = shot) -> CardFile {
        CardFile(relativePath: path, size: size, captured: date,
                 kind: CardMediaClassifier.kind(ofFileNamed: (path as NSString).lastPathComponent) ?? .jpeg)
    }

    private static func temporaryFolder(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-card-import-tests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private static func write(_ root: URL, _ path: String, bytes: Int, date: Date = shot) -> URL {
        let url = root.appendingPathComponent(path, isDirectory: false)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data((0..<bytes).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ path.count) })
        try? data.write(to: url)
        try? FileManager.default.setAttributes([.creationDate: date, .modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    // MARK: Detection

    private static func detection(_ suite: TestSuite) {
        let card = CardVolumeTraits(isLocal: true, isRemovable: true, isEjectable: true, isRootFileSystem: false)
        suite.expect(CardDetection.isCandidate(card), "a local removable volume can be a card")
        suite.expect(CardDetection.isCandidate(CardVolumeTraits(isLocal: true, isRemovable: false, isEjectable: true)),
                     "an ejectable volume, as a USB reader shows one, can be a card")
        suite.expect(!CardDetection.isCandidate(CardVolumeTraits(isLocal: true, isRemovable: false, isEjectable: false)),
                     "a fixed internal disk is never a card")
        suite.expect(!CardDetection.isCandidate(CardVolumeTraits(isLocal: false, isRemovable: true, isEjectable: true)),
                     "a network share is never a card")
        suite.expect(!CardDetection.isCandidate(CardVolumeTraits(isLocal: true, isRemovable: true, isEjectable: true,
                                                                 isRootFileSystem: true)),
                     "the startup disk is never a card")

        let fm = FileManager.default
        let empty = temporaryFolder("empty")
        let still = temporaryFolder("dcim")
        let sony = temporaryFolder("m4root")
        let avchd = temporaryFolder("avchd")
        let clip = temporaryFolder("clip")
        let decoy = temporaryFolder("decoy")
        defer { [empty, still, sony, avchd, clip, decoy].forEach { try? fm.removeItem(at: $0) } }
        try? fm.createDirectory(at: still.appendingPathComponent("DCIM/100MSDCF"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: sony.appendingPathComponent("PRIVATE/M4ROOT/CLIP"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: avchd.appendingPathComponent("PRIVATE/AVCHD/BDMV/STREAM"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: clip.appendingPathComponent("CLIP"), withIntermediateDirectories: true)
        // A file named like the folder is not the folder.
        write(decoy, "DCIM", bytes: 4)
        suite.expect(CardDetection.markers(in: still) == ["DCIM"] && CardDetection.isCameraCard(root: still, traits: card),
                     "a DCIM folder makes a removable volume a camera card")
        suite.expect(CardDetection.markers(in: sony) == ["PRIVATE/M4ROOT"]
                        && CardDetection.isCameraCard(root: sony, traits: card),
                     "Sony's XAVC tree makes a camera card without a DCIM folder")
        suite.expect(CardDetection.markers(in: avchd) == ["PRIVATE/AVCHD"] && CardDetection.markers(in: clip) == ["CLIP"],
                     "AVCHD and a CLIP folder make camera cards too")
        suite.expect(!CardDetection.isCameraCard(root: empty, traits: card)
                        && !CardDetection.isCameraCard(root: decoy, traits: card),
                     "a removable disk with no camera folders is left alone")
        suite.expect(!CardDetection.isCameraCard(root: still, traits: CardVolumeTraits()),
                     "camera folders on a fixed disk are left alone")
    }

    // MARK: Classification

    private static func classification(_ suite: TestSuite) {
        for ext in ["ARW", "cr2", "CR3", "nef", "RAF", "dng", "ORF", "rw2"] {
            suite.expect(CardMediaClassifier.kind(ofFileNamed: "IMG_0001." + ext) == .raw, "\(ext) is a raw photo")
        }
        for ext in ["JPG", "jpeg", "HEIC", "heif"] {
            suite.expect(CardMediaClassifier.kind(ofFileNamed: "IMG_0001." + ext) == .jpeg, "\(ext) is a finished photo")
        }
        for ext in ["MP4", "mov", "MTS", "MXF", "braw"] {
            suite.expect(CardMediaClassifier.kind(ofFileNamed: "C0001." + ext) == .video, "\(ext) is a video")
        }
        for name in ["C0001M01.XML", "INDEX.BDM", "GOPR0001.THM", "GL010001.LRV", "README", "photo.png",
                     "._DSC00001.ARW", ".DS_Store", ""] {
            suite.expect(CardMediaClassifier.kind(ofFileNamed: name) == nil, "\(name) is not media to import")
        }
        suite.expect(CardMediaKind.raw.isPhoto && CardMediaKind.jpeg.isPhoto && !CardMediaKind.video.isPhoto,
                     "raw and finished photos count as photos, clips as videos")
    }

    // MARK: Destination

    private static func destination(_ suite: TestSuite) {
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        suite.expect(CardImportDestination.baseURL(stored: "", home: home).path == "/Users/someone/Pictures/Imports"
                        && CardImportDestination.baseURL(stored: nil, home: home).path == "/Users/someone/Pictures/Imports",
                     "the base folder defaults to ~/Pictures/Imports")
        suite.expect(CardImportDestination.baseURL(stored: "~/Desktop/Shoots", home: home).path == "/Users/someone/Desktop/Shoots"
                        && CardImportDestination.baseURL(stored: "/Volumes/RAID/Imports", home: home).path == "/Volumes/RAID/Imports",
                     "a chosen folder reads back, home paths through ~")
        suite.expect(CardImportDestination.stored(URL(fileURLWithPath: "/Users/someone/Desktop/Shoots"), home: home)
                        == "~/Desktop/Shoots"
                        && CardImportDestination.stored(URL(fileURLWithPath: "/Volumes/RAID"), home: home) == "/Volumes/RAID",
                     "a folder in the home folder is kept with ~, one outside it as it is")
        suite.expect(CardImportDestination.eventName(for: shot, timeZone: utc) == "2026-11-20",
                     "the event folder starts as the day, YYYY-MM-DD")
        suite.expect(CardImportDestination.folderName("2026-11-20 Wisuda USU") == "2026-11-20 Wisuda USU",
                     "a typed event name is kept as it is")
        suite.expect(CardImportDestination.folderName("  ..Wisuda/USU: Sesi\n2  ") == "Wisuda-USU- Sesi 2",
                     "slashes, colons, leading dots and line breaks never reach the folder name")
        suite.expect(CardImportDestination.folderName("   ") == nil && CardImportDestination.folderName("...") == nil,
                     "a name with nothing left falls back")
        suite.expect(CardImportDestination.folderName(String(repeating: "a", count: 300))?.count
                        == CardImportDestination.maximumNameLength, "a very long name is cut short")
        let base = URL(fileURLWithPath: "/tmp/imports", isDirectory: true)
        suite.expect(CardImportDestination.eventFolder(base: base, typed: "", fallbackDate: shot, timeZone: utc).path
                        == "/tmp/imports/2026-11-20", "an empty name takes the day")
    }

    // MARK: Plan

    private static func planning(_ suite: TestSuite) {
        let files = [file("DCIM/100MSDCF/DSC00001.ARW"), file("DCIM/100MSDCF/DSC00001.JPG"),
                     file("DCIM/100MSDCF/IMG_0002.HEIC"), file("PRIVATE/M4ROOT/CLIP/C0001.MP4")]
        let split = CardImportPlanner.plan(files, options: CardImportOptions(), timeZone: utc)
        suite.expect(split.items.map(\.destination) == ["RAW/DSC00001.ARW", "JPG/DSC00001.JPG", "JPG/IMG_0002.HEIC",
                                                        "Video/C0001.MP4"],
                     "RAW and JPG go to their own folders and videos to Video, HEIC with the JPGs")
        var flat = CardImportOptions()
        flat.separateRaw = false
        flat.videoFolder = false
        suite.expect(CardImportPlanner.plan(files, options: flat).items.map(\.destination)
                        == ["DSC00001.ARW", "DSC00001.JPG", "IMG_0002.HEIC", "C0001.MP4"],
                     "with both options off everything lands in the event folder")
        var videosOnly = CardImportOptions()
        videosOnly.separateRaw = false
        suite.expect(CardImportPlanner.plan(files, options: videosOnly).items.map(\.destination)
                        == ["DSC00001.ARW", "DSC00001.JPG", "IMG_0002.HEIC", "Video/C0001.MP4"],
                     "videos can go to Video while the photos stay together")
        suite.expect(split.bytes == 400 && split.skipped.isEmpty && !split.isEmpty, "the plan adds up what it copies")
        suite.expect(CardImportPlanner.subfolder(for: .raw, options: CardImportOptions()) == "RAW"
                        && CardImportPlanner.subfolder(for: .jpeg, options: flat) == nil,
                     "each kind's folder follows the options")
    }

    private static func renaming(_ suite: TestSuite) {
        var options = CardImportOptions()
        options.rename = .dateSequence
        let later = shot.addingTimeInterval(65)
        // Out of order on the card: the numbers follow when they were shot.
        let files = [file("DCIM/101MSDCF/DSC00009.ARW", at: later), file("DCIM/100MSDCF/DSC00001.ARW"),
                     file("DCIM/100MSDCF/DSC00001.JPG"), file("DCIM/101MSDCF/DSC00009.JPG", at: later)]
        let plan = CardImportPlanner.plan(files, options: options, timeZone: utc)
        suite.expect(plan.items.map(\.destination) == ["RAW/20261120-101502-0001.ARW", "JPG/20261120-101502-0001.JPG",
                                                       "RAW/20261120-101607-0002.ARW", "JPG/20261120-101607-0002.JPG"],
                     "YYYYMMDD-HHMMSS-#### numbers shots in the order they were taken; a RAW and its JPG share one")
        suite.expect(CardImportPlanner.renamed(file("DCIM/X.dng"), number: 12_345, timeZone: utc) == "20261120-101502-12345.dng",
                     "past 9999 the number grows, and the extension keeps its case")
        let original = CardImportPlanner.plan(files, options: CardImportOptions(), timeZone: utc)
        suite.expect(original.items.first?.destination == "RAW/DSC00009.ARW",
                     "keeping the original names keeps the card's order")
    }

    private static func collisions(_ suite: TestSuite) {
        // Two folders on the card with the same file name.
        let files = [file("DCIM/100MSDCF/DSC00001.JPG"), file("DCIM/101MSDCF/DSC00001.JPG"),
                     file("DCIM/102MSDCF/dsc00001.jpg")]
        let plan = CardImportPlanner.plan(files, options: CardImportOptions())
        suite.expect(plan.items.map(\.destination) == ["JPG/DSC00001.JPG", "JPG/DSC00001-1.JPG", "JPG/dsc00001-2.jpg"],
                     "a name planned twice takes -1, -2, regardless of case")
        let taken: Set<String> = ["JPG/DSC00001.JPG", "JPG/DSC00001-1.JPG"]
        let existing = CardImportPlanner.plan([files[0]], options: CardImportOptions(), exists: { taken.contains($0) })
        suite.expect(existing.items.map(\.destination) == ["JPG/DSC00001-2.JPG"],
                     "a file already in the event folder is never planned over")
        suite.expect(CardImportPlanner.alternative("photo.jpg", attempt: 0) == "photo.jpg"
                        && CardImportPlanner.alternative("photo.jpg", attempt: 3) == "photo-3.jpg"
                        && CardImportPlanner.alternative("README", attempt: 1) == "README-1",
                     "alternatives keep the extension")
    }

    // MARK: Ledger

    private static func ledger(_ suite: TestSuite) {
        let folder = temporaryFolder("ledger")
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = [file("DCIM/100MSDCF/DSC00001.ARW", size: 2048), file("DCIM/100MSDCF/DSC00002.ARW", size: 4096)]
        suite.expect(files[0].ledgerKey == "dsc00001.arw|2048|1795169702", "a ledger key is the name, size and capture second")
        let first = CardImportPlanner.plan(files, options: CardImportOptions())
        var book = CardImportLedger.load(volume: "8F1B-11E0", folder: folder)
        suite.expect(book.keys.isEmpty, "a card seen for the first time has an empty ledger")
        book.record(first.items.map(\.file.ledgerKey))
        book.record([files[0].ledgerKey])
        suite.expect(book.keys.count == 2, "a key is recorded once")
        suite.expect(book.save(folder: folder), "the ledger saves")
        let read = CardImportLedger.load(volume: "8F1B-11E0", folder: folder)
        suite.expect(read == book, "the ledger reads back for the same volume")
        suite.expect(CardImportLedger.load(volume: "OTHER", folder: folder).keys.isEmpty,
                     "another card (or the same one formatted) starts over")
        // The card again, with one new shot and one file rewritten with another size.
        let again = [files[0], file("DCIM/100MSDCF/DSC00002.ARW", size: 4100), file("DCIM/100MSDCF/DSC00003.ARW")]
        let second = CardImportPlanner.plan(again, options: CardImportOptions(), skip: read.keySet)
        suite.expect(second.skipped.map(\.name) == ["DSC00001.ARW"]
                        && second.items.map(\.file.name) == ["DSC00002.ARW", "DSC00003.ARW"],
                     "what came off before is skipped; a file of another size is not the same file")
        let renumbered = [file("DCIM/100MSDCF/DSC00001.ARW", size: 2048, at: shot.addingTimeInterval(86_400))]
        suite.expect(CardImportPlanner.plan(renumbered, options: CardImportOptions(), skip: read.keySet).items.count == 1,
                     "a wrapped file number on another day is a new photo")
        suite.expect(CardImportLedger.fileName(volume: "8F1B/11E0 ..") == "ledger-8F1B_11E0___.json",
                     "the ledger's file name holds no path characters")
        var big = CardImportLedger(volume: "big")
        big.record((0..<(CardImportLedger.capacity + 10)).map { "k\($0)" })
        suite.expect(big.keys.count == CardImportLedger.capacity && big.keys.first == "k10",
                     "the ledger keeps the newest keys up to its cap")
    }

    // MARK: Rate

    private static func eta(_ suite: TestSuite) {
        var rate = CardImportRate()
        suite.expect(rate.eta(remaining: 1_000, at: 0) == nil, "no estimate before any reading")
        rate.record(copied: 0, at: 10)
        rate.record(copied: 10_000_000, at: 10.2)
        suite.expect(rate.bytesPerSecond == nil, "readings closer than the interval wait for the next")
        rate.record(copied: 50_000_000, at: 11)
        suite.expect(rate.bytesPerSecond.map { abs($0 - 50_000_000) < 1 } == true, "the first sample is the speed")
        suite.expect(rate.eta(remaining: 100_000_000, at: 11) == nil, "no estimate while the copy warms up")
        rate.record(copied: 150_000_000, at: 12)
        // 50 MB/s, then a 100 MB/s second: smoothed by 0.3.
        suite.expect(rate.bytesPerSecond.map { abs($0 - 65_000_000) < 1 } == true, "a new sample moves the average by 30%")
        suite.expect(rate.eta(remaining: 130_000_000, at: 12).map { abs($0 - 2) < 0.0001 } == true,
                     "time left is what remains over the smoothed speed")
        suite.expect(rate.eta(remaining: 0, at: 12) == 0, "nothing left, no time left")
        rate.record(copied: 150_000_000, at: 13)
        suite.expect(rate.bytesPerSecond.map { abs($0 - 45_500_000) < 1 } == true, "a stall slows the estimate, gently")
        rate.record(copied: 1, at: .nan)
        suite.expect(rate.bytesPerSecond.map { abs($0 - 45_500_000) < 1 } == true, "a bad clock reading is ignored")
    }

    private static func progress(_ suite: TestSuite) {
        var progress = CardImportProgress(totalFiles: 4, totalBytes: 1_000, copiedFiles: 3, copiedBytes: 999)
        suite.expect(progress.percent == 99 && progress.filesLeft == 1, "99.9% reads 99 until the last file is in")
        progress.copiedFiles = 4
        progress.copiedBytes = 1_000
        suite.expect(progress.percent == 100 && progress.fraction == 1 && progress.filesLeft == 0, "every file in reads 100")
        suite.expect(CardImportProgress().percent == 0 && CardImportProgress().fraction == 0, "an empty import reads 0")
        let empty = CardImportProgress(totalFiles: 2, totalBytes: 0, copiedFiles: 1, copiedBytes: 0)
        suite.expect(empty.fraction == 0.5, "files of no size count by files")
    }

    // MARK: Formatting

    private static func formatting(_ suite: TestSuite) {
        let en = Locale(identifier: "en_US")
        suite.expect(CardImportFormat.count(1248, locale: en) == "1,248", "counts are grouped")
        suite.expect(CardImportFormat.form(1, agreement: .oneAndMany) == 0 && CardImportFormat.form(2, agreement: .oneAndMany) == 2
                        && CardImportFormat.form(21, agreement: .byLastDigits) == 0
                        && CardImportFormat.form(22, agreement: .byLastDigits) == 1
                        && CardImportFormat.form(12, agreement: .byLastDigits) == 2
                        && CardImportFormat.form(3, agreement: .byWholeNumber) == 1
                        && CardImportFormat.form(22, agreement: .byWholeNumber) == 2,
                     "counted words take each language's form")
        let text = ZenithStrings.cardImport(.enUS)
        suite.expect(CardImportFormat.photos(1, text: text, language: .enUS) == "1 photo"
                        && CardImportFormat.photos(1248, text: text, language: .enUS).hasSuffix(" photos"),
                     "one photo, many photos")
        suite.expect(CardImportFormat.counted(5, forms: ZenithStrings.cardImport(.sk).photos, agreement: .byWholeNumber,
                                              locale: Locale(identifier: "sk")) == "5 fotiek",
                     "Slovak counts many photos in its own form")
        suite.expect(CardImportFormat.eta(12, locale: en) == "15s" && CardImportFormat.eta(125, locale: en) == "3m"
                        && CardImportFormat.eta(4_300, locale: en) == "1h 12m",
                     "time left reads short and rounds up: \(CardImportFormat.eta(12, locale: en)), "
                        + "\(CardImportFormat.eta(125, locale: en)), \(CardImportFormat.eta(4_300, locale: en))")
        var scan = CardScan(files: [file("DCIM/A.JPG", size: 3_000_000_000), file("DCIM/B.ARW", size: 3_000_000_000)])
        let photosOnly = CardImportFormat.notice(scan: scan, volume: "EOS_DIGITAL", importedBefore: 0, text: text, language: .enUS)
        suite.expect(photosOnly.title.hasPrefix("SD card · 2 photos · ") && photosOnly.subtitle == "EOS_DIGITAL",
                     "the notice reads SD card · photos · size: \(photosOnly.title)")
        scan.files.append(file("PRIVATE/M4ROOT/CLIP/C0001.MP4"))
        let both = CardImportFormat.notice(scan: scan, volume: "Untitled", importedBefore: 2, text: text, language: .enUS)
        suite.expect(both.subtitle == "Untitled · 1 video · 2 imported before",
                     "videos and what came off before go under it: \(both.subtitle)")
        let clips = CardImportFormat.notice(scan: CardScan(files: [file("CLIP/A.MXF")]), volume: "XDCAM", importedBefore: 0,
                                            text: text, language: .enUS)
        suite.expect(clips.title.hasPrefix("SD card · 1 video · "), "a card of clips leads with its videos")
    }

    // MARK: Copy

    private static func copyEndToEnd(_ suite: TestSuite) {
        let fm = FileManager.default
        let card = temporaryFolder("card")
        let base = temporaryFolder("imports")
        defer { [card, base].forEach { try? fm.removeItem(at: $0) } }
        let older = shot.addingTimeInterval(-3_600)
        let raw = write(card, "DCIM/100MSDCF/DSC00001.ARW", bytes: 9_000, date: older)
        write(card, "DCIM/100MSDCF/DSC00001.JPG", bytes: 3_000, date: older)
        write(card, "DCIM/101MSDCF/DSC00001.JPG", bytes: 2_500)
        write(card, "PRIVATE/M4ROOT/CLIP/C0001.MP4", bytes: 70_000)
        // Sony's thumbnails and proxies, and Finder's leftovers, stay on the card.
        write(card, "PRIVATE/M4ROOT/THMBNL/C0001T01.JPG", bytes: 100)
        write(card, "PRIVATE/M4ROOT/SUB/C0001S03.MP4", bytes: 100)
        write(card, "DCIM/100MSDCF/._DSC00001.ARW", bytes: 10)
        let before = (try? Data(contentsOf: raw)) ?? Data()

        let scan = CardScanner.scan(root: card)
        suite.expect(scan.files.map(\.relativePath) == ["DCIM/100MSDCF/DSC00001.ARW", "DCIM/100MSDCF/DSC00001.JPG",
                                                        "DCIM/101MSDCF/DSC00001.JPG", "PRIVATE/M4ROOT/CLIP/C0001.MP4"],
                     "the scan finds the media and leaves thumbnails, proxies and AppleDouble files out: "
                        + scan.files.map(\.relativePath).joined(separator: ", "))
        suite.expect(scan.photos == 3 && scan.videos == 1 && scan.photoBytes == 14_500 && scan.videoBytes == 70_000,
                     "the scan counts photos and videos with their sizes")
        suite.expect(scan.files.first.map { abs($0.captured.timeIntervalSince(older)) < 1 } == true,
                     "a file's capture time is its creation date")

        let event = CardImportDestination.eventFolder(base: base, typed: "2026-11-20 Wisuda USU", fallbackDate: shot)
        // A file already there keeps its place and its bytes.
        let squatter = write(event, "JPG/DSC00001.JPG", bytes: 7)
        let plan = CardImportPlanner.plan(scan.files, options: CardImportOptions(), exists: { path in
            fm.fileExists(atPath: event.appendingPathComponent(path).path)
        })
        let job = CardImportJob(source: card, destination: event, chunkSize: 4_096, removalGrace: 0)
        let error = job.run(plan)
        let state = job.drain()
        suite.expect(error == nil && state.finished && state.error == nil && state.copiedFiles == 4
                        && state.copiedBytes == 84_500 && state.totalFiles == 4 && state.totalBytes == 84_500,
                     "every file is copied: \(String(describing: error))")
        suite.expect(Set(state.finishedKeys) == Set(scan.files.map(\.ledgerKey)), "each copied file hands its key to the ledger")
        suite.expect(job.drain().finishedKeys.isEmpty, "keys are handed over once")
        let expected: [(String, Int64)] = [("RAW/DSC00001.ARW", 9_000), ("JPG/DSC00001-1.JPG", 3_000),
                                           ("JPG/DSC00001-2.JPG", 2_500), ("Video/C0001.MP4", 70_000)]
        for (path, size) in expected {
            suite.expect(CardImportJob.size(of: event.appendingPathComponent(path)) == size, "\(path) arrives whole")
        }
        suite.expect(CardImportJob.size(of: squatter) == 7, "the file that was there first is never overwritten")
        let copied = event.appendingPathComponent("RAW/DSC00001.ARW")
        let attributes = (try? fm.attributesOfItem(atPath: copied.path)) ?? [:]
        suite.expect((attributes[.creationDate] as? Date).map { abs($0.timeIntervalSince(older)) < 1 } == true
                        && (attributes[.modificationDate] as? Date).map { abs($0.timeIntervalSince(older)) < 1 } == true,
                     "the copy keeps the card's creation and modification dates")
        suite.expect((try? Data(contentsOf: copied)) == before && (try? Data(contentsOf: raw)) == before,
                     "the bytes match, and the card's file is untouched")
        suite.expect(fm.fileExists(atPath: card.appendingPathComponent("PRIVATE/M4ROOT/THMBNL/C0001T01.JPG").path)
                        && CardScanner.scan(root: card).files.count == 4, "nothing on the card is moved or deleted")
        let leftovers = (fm.enumerator(atPath: event.path)?.allObjects as? [String] ?? [])
            .filter { $0.contains(CardImportJob.partialPrefix) }
        suite.expect(leftovers.isEmpty, "no partial file stays behind")

        // A name taken between the plan and the copy still never overwrites.
        let late = CardImportPlan(items: [.init(file: scan.files[3], destination: "Video/C0001.MP4")])
        suite.expect(CardImportJob(source: card, destination: event, removalGrace: 0).run(late) == nil
                        && CardImportJob.size(of: event.appendingPathComponent("Video/C0001-1.MP4")) == 70_000
                        && CardImportJob.size(of: event.appendingPathComponent("Video/C0001.MP4")) == 70_000,
                     "a file that appeared after planning keeps its name; the copy takes the next one")

        // A partial file a stopped copy left is cleared before the next one.
        write(event, "RAW/" + CardImportJob.partialPrefix + "stale" + CardImportJob.partialSuffix, bytes: 5)
        let again = CardImportPlanner.plan(scan.files, options: CardImportOptions(),
                                           skip: Set(scan.files.dropFirst().map(\.ledgerKey)),
                                           exists: { fm.fileExists(atPath: event.appendingPathComponent($0).path) })
        _ = CardImportJob(source: card, destination: event, removalGrace: 0).run(again)
        suite.expect(!fm.fileExists(atPath: event.appendingPathComponent("RAW/" + CardImportJob.partialPrefix + "stale"
                                                                          + CardImportJob.partialSuffix).path)
                        && again.items.map(\.destination) == ["RAW/DSC00001-1.ARW"] && again.skipped.count == 3,
                     "leftovers go, skipped files stay skipped, and a re-import takes a new name")
    }

    private static func copyFailures(_ suite: TestSuite) {
        let fm = FileManager.default
        let card = temporaryFolder("pulled")
        let base = temporaryFolder("pulled-imports")
        defer { [card, base].forEach { try? fm.removeItem(at: $0) } }
        write(card, "DCIM/100MSDCF/DSC00001.JPG", bytes: 1_000)
        write(card, "DCIM/100MSDCF/DSC00002.JPG", bytes: 1_000)
        let plan = CardImportPlanner.plan(CardScanner.scan(root: card).files, options: CardImportOptions())

        let pulled = CardImportJob(source: card, destination: base, removalGrace: 0)
        try? fm.removeItem(at: card)
        suite.expect(pulled.run(plan) == .cardRemoved && pulled.drain().copiedFiles == 0,
                     "a card gone before its files are read ends as removed")

        let source = temporaryFolder("gone-file")
        defer { try? fm.removeItem(at: source) }
        write(source, "DCIM/100MSDCF/DSC00001.JPG", bytes: 1_000)
        let one = CardImportJob(source: source, destination: base, removalGrace: 0)
        suite.expect(one.run(plan) == .failed(file: "DSC00002.JPG") && one.drain().copiedFiles == 1,
                     "a file missing on a card still there fails with its name, after the ones before it")

        let stopped = CardImportJob(source: source, destination: base, removalGrace: 0)
        stopped.cancel()
        suite.expect(stopped.run(plan) == .cancelled && stopped.drain().finished, "a stopped job ends as stopped")
        let gone = CardImportJob(source: source, destination: base, removalGrace: 0)
        gone.markSourceGone()
        suite.expect(!gone.sourceAvailable, "an unmount tells the job its card is gone")

        suite.expect(CardImportJob.writeError(errno: ENOSPC, file: "a") == .diskFull
                        && CardImportJob.writeError(errno: EDQUOT, file: "a") == .diskFull
                        && CardImportJob.writeError(errno: EACCES, file: "a") == .failed(file: "a"),
                     "a full disk reads as one; other write errors name the file")
        suite.expect(CardImportJob.posixCode(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)) == ENOSPC
                        && CardImportJob.posixCode(NSError(domain: NSPOSIXErrorDomain, code: Int(EDQUOT))) == EDQUOT,
                     "Foundation's out-of-space error reads as a full disk")
        let full = CardImportJob(source: source, destination: base, removalGrace: 0)
        full.fail(.diskFull, shortfall: 4_096, plan: plan)
        let state = full.drain()
        suite.expect(state.finished && state.error == .diskFull && state.shortfall == 4_096 && state.totalFiles == 2,
                     "a full disk found before the copy ends the job with what it needs")
    }

    // MARK: Island

    private static func island(_ suite: TestSuite) {
        suite.expect(NotchSupport.compactActivities(timer: false, downloads: true, agents: false, calendar: true, music: true,
                                                   vercel: true, command: true, cardImport: true)
                        == [.downloads, .vercel, .command, .cardImport, .calendar, .music]
                        && NotchSupport.compactActivity(timer: false, downloads: false, music: true, cardImport: true) == .cardImport,
                     "a card import follows a terminal command and comes before an event and music")
        suite.expect(!NotchSupport.compactActivities(timer: false, downloads: false, agents: false, calendar: false,
                                                    music: false).contains(.cardImport), "no import, no activity")
        suite.expect(NotchCompactActivity.cardImport.module == .cardImport && NotchCompactActivity.cardImport.symbol == "camera.fill"
                        && NotchCompactActivity.cardImport.title(.enUS) == "Card Import",
                     "the activity opens the import page and wears the camera glyph")
        let keys = NotchModule.allCases.map(\.shortcutKey)
        suite.expect(Set(keys).count == keys.count && NotchModule.cardImport.symbol == "sdcard",
                     "the Card Import page has a shortcut key of its own")
        let palette = NotchModule.allCases.map(ZenithIslandPalette.hex)
        suite.expect(Set(palette).count == palette.count, "the Card Import page wears a colour of its own")

        let domain = "com.vorssaint.tests.card-import"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(CardImportOptions.isEnabled(in: defaults) && CardImportOptions.current(in: defaults) == CardImportOptions(),
                     "detection is on and the defaults read back before anything is set")
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        suite.expect(NotchModule.cardImport.isAvailable(in: defaults), "the section is always listed")
        defaults.set(false, forKey: DefaultsKey.notchCardImportEnabled)
        defaults.set(false, forKey: DefaultsKey.notchCardImportSplitRaw)
        defaults.set("date", forKey: DefaultsKey.notchCardImportRename)
        defaults.set(false, forKey: DefaultsKey.notchCardImportEject)
        let read = CardImportOptions.current(in: defaults)
        suite.expect(!CardImportOptions.isEnabled(in: defaults) && !read.separateRaw && read.rename == .dateSequence
                        && !read.ejectWhenDone && read.videoFolder && read.skipImported,
                     "the chosen defaults read back")
        suite.expect(!NotchSupport.modules(in: defaults).contains(.cardImport),
                     "with detection off the page leaves the island")
        defaults.set("nonsense", forKey: DefaultsKey.notchCardImportRename)
        suite.expect(CardImportOptions.current(in: defaults).rename == .original, "an unknown pattern keeps the names")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchCardImportEnabled] as? Bool == true
                        && Defaults.registeredDefaults[DefaultsKey.notchCardImportFolder] as? String == ""
                        && Defaults.registeredDefaults[DefaultsKey.notchCardImportRename] as? String == "original",
                     "the preferences are registered, so they join the backup")
    }

    private static func notice(_ suite: TestSuite) {
        let card = ZenithNotice(kind: .card, key: ZenithNoticeKey.card("8F1B-11E0"), title: "SD card · 2 photos · 6 GB",
                                subtitle: "EOS_DIGITAL", glyph: .symbol("sdcard.fill", .tint(.cardImport)),
                                accessory: .action("Import"), action: .importCard("8F1B-11E0"))
        suite.expect(card.priority == ZenithNotice.Kind.audio.priority && card.priority > ZenithNotice.Kind.download.priority
                        && card.priority < ZenithNotice.Kind.batteryLow.priority,
                     "a card outranks a download and yields to a low battery")
        suite.expect(card.duration > ZenithNoticeTiming.duration(.download) && ZenithNoticeQueue.lifetime(.card) == 30,
                     "a card's notice stays a little longer, and waits for the island up to 30 seconds")
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(card, now: 0)
        var again = card
        again.title = "SD card · 3 photos · 9 GB"
        suite.expect(queue.enqueue(again, now: 1) == .coalesced && queue.pending.count == 1,
                     "the same card mounting again updates its waiting notice")
        suite.expect(queue.next(now: 2)?.title == again.title, "the newest reading of the card shows")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.cardImport(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            let forms = text.photos + text.videos
            suite.expect(values.count == 45 && (values + forms).allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words the card import, with curly apostrophes and no em dash")
            suite.expect(text.photos.count == 3 && text.videos.count == 3 && forms.allSatisfy { $0.contains("%@") },
                         "\(language.rawValue) counts photos and videos in three forms")
            suite.expect([text.newFiles, text.alreadyImported, text.left, text.imported, text.skippedBefore,
                          text.diskFullDetail, text.failedDetail].allSatisfy { $0.contains("%@") },
                         "\(language.rawValue) places its values")
        }
    }
}
