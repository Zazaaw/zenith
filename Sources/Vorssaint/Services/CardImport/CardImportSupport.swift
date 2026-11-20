// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: importing photos and videos from camera cards. Everything here
// is pure Foundation and compiled into the tests: which volumes count as a
// camera card, which files are media, the destination plan (RAW, JPG and
// Video folders, the rename pattern, collisions), the import ledger, the
// throughput and ETA, the activity model and formatting.
// CardImportCopier copies; CardImportService watches the volumes and runs it.

// MARK: - Media

enum CardMediaKind: String, Codable, Equatable, Sendable {
    case raw, jpeg, video

    var isPhoto: Bool { self != .video }
}

enum CardMediaClassifier {
    /// Raw files from Sony, Canon, Nikon, Fujifilm, Adobe, Olympus/OM and Panasonic.
    static let rawExtensions: Set<String> = ["arw", "cr2", "cr3", "nef", "raf", "dng", "orf", "rw2"]
    /// Finished photos; HEIC travels with the JPGs.
    static let jpegExtensions: Set<String> = ["jpg", "jpeg", "heic", "heif"]
    /// Clips from mirrorless bodies (MP4, MOV), AVCHD (MTS), cinema cameras
    /// (MXF) and Blackmagic (BRAW).
    static let videoExtensions: Set<String> = ["mp4", "mov", "mts", "mxf", "braw"]

    /// The kind of a file by its extension, ignoring case. Hidden files,
    /// including the `._` AppleDouble files macOS leaves on FAT cards, are not media.
    static func kind(ofFileNamed name: String) -> CardMediaKind? {
        guard !name.hasPrefix("."), !name.isEmpty else { return nil }
        let ext = (name as NSString).pathExtension.lowercased()
        if rawExtensions.contains(ext) { return .raw }
        if jpegExtensions.contains(ext) { return .jpeg }
        if videoExtensions.contains(ext) { return .video }
        return nil
    }
}

// MARK: - Detection

/// What the volume says about itself, read from its resource values.
struct CardVolumeTraits: Equatable {
    var isLocal = true
    var isRemovable = false
    var isEjectable = false
    var isRootFileSystem = false
}

enum CardDetection {
    /// Folders a camera leaves at the top of its card: DCIM (every still
    /// camera, by the DCF standard), Sony's XAVC tree, AVCHD, and a CLIP
    /// folder some video bodies write.
    static let markers = ["DCIM", "PRIVATE/M4ROOT", "PRIVATE/AVCHD", "AVCHD", "CLIP"]

    /// Where the media sits under those markers. Sony's thumbnails
    /// (M4ROOT/THMBNL, JPGs) and proxies (M4ROOT/SUB, MP4s) stay out, so
    /// they are neither counted nor copied.
    static let mediaRoots = ["DCIM", "PRIVATE/M4ROOT/CLIP", "PRIVATE/AVCHD/BDMV/STREAM", "AVCHD/BDMV/STREAM", "CLIP"]

    /// A volume that can be a card: on this Mac, removable or ejectable, and
    /// not the startup disk. A built-in SD slot is internal but removable.
    static func isCandidate(_ traits: CardVolumeTraits) -> Bool {
        traits.isLocal && !traits.isRootFileSystem && (traits.isRemovable || traits.isEjectable)
    }

    /// The markers present on a volume, as folders.
    static func markers(in root: URL, fileManager: FileManager = .default) -> [String] {
        markers.filter { isDirectory(root.appendingPathComponent($0, isDirectory: true), fileManager: fileManager) }
    }

    static func isCameraCard(root: URL, traits: CardVolumeTraits, fileManager: FileManager = .default) -> Bool {
        isCandidate(traits) && !markers(in: root, fileManager: fileManager).isEmpty
    }

    static func isDirectory(_ url: URL, fileManager: FileManager = .default) -> Bool {
        var directory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }
}

// MARK: - Scan

/// A media file on the card.
struct CardFile: Equatable, Sendable {
    /// From the card's root, with `/` between folders.
    let relativePath: String
    let size: Int64
    /// When it was shot, as the camera stamped the file: its creation date,
    /// or its modification date where the card keeps no creation date.
    let captured: Date
    let kind: CardMediaKind

    var name: String { (relativePath as NSString).lastPathComponent }

    /// How the ledger knows a file again: its name, size and capture second.
    /// A camera's numbers wrap around (DSC09999 is followed by DSC00001), so
    /// the name alone could name two photos; with the second it cannot.
    var ledgerKey: String {
        "\(name.lowercased())|\(size)|\(Int64(captured.timeIntervalSince1970.rounded(.down)))"
    }
}

struct CardScan: Equatable, Sendable {
    var files: [CardFile] = []

    var photos: Int { files.filter(\.kind.isPhoto).count }
    var videos: Int { files.filter { $0.kind == .video }.count }
    var photoBytes: Int64 { files.filter(\.kind.isPhoto).reduce(0) { $0 + $1.size } }
    var videoBytes: Int64 { files.filter { $0.kind == .video }.reduce(0) { $0 + $1.size } }
    var bytes: Int64 { files.reduce(0) { $0 + $1.size } }
    var isEmpty: Bool { files.isEmpty }
}

enum CardScanner {
    /// Every media file under the card's media roots, sorted by path. Runs
    /// on whatever thread calls it; the service calls it off the main thread.
    static func scan(root: URL, fileManager: FileManager = .default,
                     isCancelled: () -> Bool = { false }) -> CardScan {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey]
        var seen = Set<String>()
        var files: [CardFile] = []
        let rootPath = root.standardizedFileURL.path
        for folder in CardDetection.mediaRoots {
            let start = root.appendingPathComponent(folder, isDirectory: true)
            guard CardDetection.isDirectory(start, fileManager: fileManager),
                  let walker = fileManager.enumerator(at: start, includingPropertiesForKeys: keys,
                                                      options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in walker {
                if isCancelled() { return CardScan(files: files) }
                guard let kind = CardMediaClassifier.kind(ofFileNamed: url.lastPathComponent),
                      let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
                let path = url.standardizedFileURL.path
                guard path.hasPrefix(rootPath + "/"), seen.insert(path.lowercased()).inserted else { continue }
                let relative = String(path.dropFirst(rootPath.count + 1))
                let captured = values.creationDate ?? values.contentModificationDate ?? Date(timeIntervalSince1970: 0)
                files.append(CardFile(relativePath: relative, size: Int64(values.fileSize ?? 0), captured: captured, kind: kind))
            }
        }
        files.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        return CardScan(files: files)
    }
}

// MARK: - Options

enum CardRenamePattern: String, CaseIterable, Sendable {
    /// The camera's own names, as DSC01234.ARW.
    case original
    /// `YYYYMMDD-HHMMSS-####`, from the capture time and the order in this import.
    case dateSequence = "date"
}

struct CardImportOptions: Equatable, Sendable {
    var separateRaw = true
    var videoFolder = true
    var skipImported = true
    var rename = CardRenamePattern.original
    var ejectWhenDone = true

    static func current(in defaults: UserDefaults = .standard) -> CardImportOptions {
        func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        return CardImportOptions(
            separateRaw: flag(DefaultsKey.notchCardImportSplitRaw, true),
            videoFolder: flag(DefaultsKey.notchCardImportVideoFolder, true),
            skipImported: flag(DefaultsKey.notchCardImportSkipImported, true),
            rename: CardRenamePattern(rawValue: defaults.string(forKey: DefaultsKey.notchCardImportRename) ?? "") ?? .original,
            ejectWhenDone: flag(DefaultsKey.notchCardImportEject, true))
    }

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: DefaultsKey.notchCardImportEnabled) as? Bool ?? true
    }
}

// MARK: - Destination

enum CardImportDestination {
    static let defaultBase = "~/Pictures/Imports"
    static let rawFolder = "RAW"
    static let jpegFolder = "JPG"
    static let videoFolder = "Video"
    static let maximumNameLength = 120

    /// The base folder the setting names (with `~` for the home folder), or
    /// `~/Pictures/Imports` when it names none.
    static func baseURL(stored: String?, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        let path = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chosen = path.isEmpty ? defaultBase : path
        if chosen == "~" { return home }
        if chosen.hasPrefix("~/") { return home.appendingPathComponent(String(chosen.dropFirst(2)), isDirectory: true) }
        return URL(fileURLWithPath: chosen, isDirectory: true)
    }

    /// How the setting keeps a folder: inside the home folder with `~`, so a
    /// backup restored on another Mac still points home.
    static func stored(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        let path = url.standardizedFileURL.path, homePath = home.standardizedFileURL.path
        if path == homePath { return "~" }
        if path.hasPrefix(homePath + "/") { return "~/" + path.dropFirst(homePath.count + 1) }
        return path
    }

    /// `YYYY-MM-DD`, the event folder's first words.
    static func eventName(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// The event folder's name as typed, made safe for a folder: no slash or
    /// colon, no leading dot, no control characters, at most 120 characters.
    /// Nil when nothing is left.
    static func folderName(_ typed: String) -> String? {
        var name = typed.unicodeScalars.map { scalar -> String in
            if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar) { return " " }
            if scalar == "/" || scalar == ":" { return "-" }
            return String(scalar)
        }.joined()
        name = name.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        while name.hasPrefix(".") { name.removeFirst() }
        name = name.trimmingCharacters(in: .whitespaces)
        if name.count > maximumNameLength { name = String(name.prefix(maximumNameLength)).trimmingCharacters(in: .whitespaces) }
        return name.isEmpty ? nil : name
    }

    static func eventFolder(base: URL, typed: String, fallbackDate: Date, timeZone: TimeZone = .current) -> URL {
        base.appendingPathComponent(folderName(typed) ?? eventName(for: fallbackDate, timeZone: timeZone), isDirectory: true)
    }
}

// MARK: - Plan

struct CardImportPlan: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        let file: CardFile
        /// From the event folder, as `RAW/DSC01234.ARW`.
        let destination: String
    }

    var items: [Item] = []
    /// Already imported, so left on the card where they are.
    var skipped: [CardFile] = []

    var bytes: Int64 { items.reduce(0) { $0 + $1.file.size } }
    var isEmpty: Bool { items.isEmpty }
}

enum CardImportPlanner {
    /// The folder a kind goes to inside the event folder, if any.
    static func subfolder(for kind: CardMediaKind, options: CardImportOptions) -> String? {
        switch kind {
        case .video: return options.videoFolder ? CardImportDestination.videoFolder : nil
        case .raw: return options.separateRaw ? CardImportDestination.rawFolder : nil
        case .jpeg: return options.separateRaw ? CardImportDestination.jpegFolder : nil
        }
    }

    /// Where every file goes. `skip` holds ledger keys to leave out (the
    /// ledger's when the option is on, and always what this import already
    /// copied); `exists` says whether a path inside the event folder is taken,
    /// which, like a name planned twice, never overwrites but takes `-1`, `-2`.
    /// With the date pattern, files are numbered in the order they were shot,
    /// and a RAW and its JPG (one shot, two files) share their number.
    static func plan(_ files: [CardFile], options: CardImportOptions, skip: Set<String> = [],
                     exists: (String) -> Bool = { _ in false }, timeZone: TimeZone = .current) -> CardImportPlan {
        var plan = CardImportPlan()
        var wanted: [CardFile] = []
        for file in files {
            if skip.contains(file.ledgerKey) { plan.skipped.append(file) } else { wanted.append(file) }
        }
        if options.rename == .dateSequence {
            wanted.sort { lhs, rhs in
                lhs.captured != rhs.captured ? lhs.captured < rhs.captured
                    : lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
        }
        var numbers: [String: Int] = [:]
        var taken = Set<String>()
        for file in wanted {
            var name = file.name
            if options.rename == .dateSequence {
                let shot = shotKey(file)
                let number = numbers[shot] ?? (numbers.count + 1)
                numbers[shot] = number
                name = renamed(file, number: number, timeZone: timeZone)
            }
            let folder = subfolder(for: file.kind, options: options)
            var attempt = 0
            var path = join(folder, name)
            while taken.contains(path.lowercased()) || exists(path) {
                attempt += 1
                path = join(folder, alternative(name, attempt: attempt))
            }
            taken.insert(path.lowercased())
            plan.items.append(.init(file: file, destination: path))
        }
        return plan
    }

    /// One shot: the file's folder and its name without the extension.
    private static func shotKey(_ file: CardFile) -> String {
        ((file.relativePath as NSString).deletingPathExtension).lowercased()
    }

    /// `20261120-101502-0001.ARW`: the capture time, then the number (four
    /// digits, more past 9999), then the camera's extension as it was.
    static func renamed(_ file: CardFile, number: Int, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: file.captured)
        let stamp = String(format: "%04d%02d%02d-%02d%02d%02d-%04d", c.year ?? 1970, c.month ?? 1, c.day ?? 1,
                           c.hour ?? 0, c.minute ?? 0, c.second ?? 0, number)
        let ext = (file.name as NSString).pathExtension
        return ext.isEmpty ? stamp : stamp + "." + ext
    }

    /// `photo.jpg` → `photo-1.jpg`, `photo-2.jpg`, …
    static func alternative(_ name: String, attempt: Int) -> String {
        guard attempt > 0 else { return name }
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        return ext.isEmpty ? "\(stem)-\(attempt)" : "\(stem)-\(attempt).\(ext)"
    }

    private static func join(_ folder: String?, _ name: String) -> String {
        folder.map { $0 + "/" + name } ?? name
    }
}

// MARK: - Ledger

/// What has come off one card before, kept per volume UUID (a card formatted
/// in the camera gets a new one, and so a fresh ledger). Keys only, never
/// paths or contents; oldest first, capped.
struct CardImportLedger: Codable, Equatable {
    static let capacity = 50_000

    var volume: String
    private(set) var keys: [String] = []

    init(volume: String, keys: [String] = []) {
        self.volume = volume
        self.keys = Array(keys.suffix(Self.capacity))
    }

    var keySet: Set<String> { Set(keys) }

    mutating func record(_ new: [String]) {
        var known = keySet
        for key in new where known.insert(key).inserted { keys.append(key) }
        if keys.count > Self.capacity { keys.removeFirst(keys.count - Self.capacity) }
    }

    /// A file name for the volume's ledger, from characters any disk takes.
    static func fileName(volume: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let safe = String(volume.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return "ledger-" + String(safe.prefix(80)) + ".json"
    }

    static func load(volume: String, folder: URL) -> CardImportLedger {
        let url = folder.appendingPathComponent(fileName(volume: volume), isDirectory: false)
        guard let data = try? Data(contentsOf: url),
              let ledger = try? JSONDecoder().decode(CardImportLedger.self, from: data), ledger.volume == volume else {
            return CardImportLedger(volume: volume)
        }
        return ledger
    }

    @discardableResult
    func save(folder: URL) -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(Self.fileName(volume: volume), isDirectory: false),
                           options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Throughput

/// The copy's speed, smoothed so one slow file does not swing the estimate,
/// and the time left from it. Nothing is estimated in the first seconds,
/// while the card's reader and the disk settle.
struct CardImportRate: Equatable {
    /// The weight a new sample gets against the running average.
    static let smoothing = 0.3
    /// Samples closer together than this fold into the next one.
    static let interval: TimeInterval = 0.5
    /// No estimate before this long has passed.
    static let warmUp: TimeInterval = 2

    private(set) var bytesPerSecond: Double?
    private var started: TimeInterval?
    private var lastTime: TimeInterval?
    private var lastBytes: Int64 = 0

    mutating func record(copied: Int64, at time: TimeInterval) {
        guard time.isFinite else { return }
        guard let lastTime else {
            started = time
            self.lastTime = time
            lastBytes = copied
            return
        }
        let elapsed = time - lastTime
        guard elapsed >= Self.interval else { return }
        let sample = Double(max(0, copied - lastBytes)) / elapsed
        bytesPerSecond = bytesPerSecond.map { $0 + (sample - $0) * Self.smoothing } ?? sample
        self.lastTime = time
        lastBytes = copied
    }

    /// Seconds left for `remaining` bytes, nil until there is a fair reading.
    func eta(remaining: Int64, at time: TimeInterval) -> TimeInterval? {
        if remaining <= 0 { return 0 }
        guard let started, time - started >= Self.warmUp, let rate = bytesPerSecond, rate > 1 else { return nil }
        return Double(remaining) / rate
    }
}

// MARK: - Progress and activity

struct CardImportProgress: Equatable, Sendable {
    var totalFiles = 0
    var totalBytes: Int64 = 0
    var copiedFiles = 0
    var copiedBytes: Int64 = 0
    /// The file being copied, by name.
    var current: String?
    var eta: TimeInterval?
    var bytesPerSecond: Double?

    var fraction: Double {
        guard totalBytes > 0 else { return totalFiles > 0 ? Double(copiedFiles) / Double(totalFiles) : 0 }
        return min(1, max(0, Double(copiedBytes) / Double(totalBytes)))
    }

    var filesLeft: Int { max(0, totalFiles - copiedFiles) }

    /// Whole percent, which reads 100 only once every file is in.
    var percent: Int {
        let value = Int((fraction * 100).rounded(.down))
        return copiedFiles >= totalFiles && totalFiles > 0 ? 100 : min(99, value)
    }
}

enum CardImportFailure: Equatable, Sendable {
    /// The card left before the copy ended.
    case cardRemoved
    /// The destination has no room; `needed` is how much more the rest takes.
    case diskFull(needed: Int64)
    /// A file could not be read or written; its name.
    case failed(file: String)
}

/// What the closed island shows: an import under way, how one ended.
enum CardImportActivity: Equatable, Sendable {
    /// `totalFiles` fixes how wide the reading gets, so the wings stay put.
    case copying(totalFiles: Int)
    case finished(files: Int, bytes: Int64)
    case failed(CardImportFailure)
    /// A backup of an import, or a card checked against it (CardBackupService),
    /// shown in the same place while no import is under way.
    case backup(CardBackupActivity)

    /// Under way, with a percentage and a bar.
    var showsProgress: Bool {
        switch self {
        case .copying, .backup(.running): return true
        default: return false
        }
    }

    /// The files the reading may count down from, while under way.
    var runningFiles: Int? {
        switch self {
        case .copying(let total), .backup(.running(_, let total)): return total
        default: return nil
        }
    }
}

enum CardImportTiming {
    /// How long a finished import stays in the closed island.
    static let finishedHold: TimeInterval = 8
    /// An error stays longer; the page keeps it until dismissed.
    static let failedHold: TimeInterval = 15
    /// Between two readings of the copy's progress.
    static let poll: TimeInterval = 0.1
    /// How much more free space a copy wants than its files take.
    static let spaceMargin: Int64 = 256 * 1024 * 1024
    /// The ledger is written after this many files, and when the import ends.
    static let ledgerBatch = 40
}

enum CardImportPageMetrics {
    /// The page's least height; a shorter custom island scrolls it.
    static let minimumHeight: CGFloat = 232
}

// MARK: - Formatting

enum CardImportFormat {
    /// `1,248` in the language's own grouping.
    static func count(_ value: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, value), countStyle: .file)
    }

    /// One of `forms` (one, few, many) for the count, by the language's rule.
    static func form(_ count: Int, agreement: CountAgreement) -> Int {
        let magnitude = abs(count)
        switch agreement {
        case .oneAndMany:
            return magnitude == 1 ? 0 : 2
        case .byWholeNumber:
            if magnitude == 1 { return 0 }
            return (2...4).contains(magnitude) ? 1 : 2
        case .byLastDigits:
            if (11...14).contains(magnitude % 100) { return 2 }
            switch magnitude % 10 {
            case 1: return 0
            case 2, 3, 4: return 1
            default: return 2
            }
        }
    }

    /// `%@` in the chosen form becomes the grouped count.
    static func counted(_ count: Int, forms: [String], agreement: CountAgreement, locale: Locale) -> String {
        guard !forms.isEmpty else { return self.count(count, locale: locale) }
        let template = forms[min(forms.count - 1, form(count, agreement: agreement))]
        return template.replacingOccurrences(of: "%@", with: self.count(count, locale: locale))
    }

    /// Time left, short: `45s`, `12m`, `1h 12m`, in the language's own units.
    /// Under a minute it rounds up to five seconds, so it does not flicker.
    static func eta(_ seconds: TimeInterval, locale: Locale) -> String {
        let value = max(0, seconds.isFinite ? seconds : 0)
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        let rounded: TimeInterval
        if value < 60 {
            formatter.allowedUnits = [.second]
            rounded = max(5, (value / 5).rounded(.up) * 5)
        } else if value < 3600 {
            formatter.allowedUnits = [.minute]
            rounded = (value / 60).rounded(.up) * 60
        } else {
            formatter.allowedUnits = [.hour, .minute]
            rounded = (value / 60).rounded(.up) * 60
        }
        return formatter.string(from: rounded) ?? "\(Int(rounded))s"
    }

    /// `%@` in a template becomes the value.
    static func filling(_ template: String, _ value: String) -> String {
        template.replacingOccurrences(of: "%@", with: value)
    }
}

extension CardImportFormat {
    static func photos(_ count: Int, text: ZenithCardImportStrings, language: AppLanguage) -> String {
        counted(count, forms: text.photos, agreement: language.countAgreement, locale: language.formattingLocale())
    }

    static func videos(_ count: Int, text: ZenithCardImportStrings, language: AppLanguage) -> String {
        counted(count, forms: text.videos, agreement: language.countAgreement, locale: language.formattingLocale())
    }

    /// The card's contents in a line: `1,248 photos · 32 videos`, either alone when the other is none.
    static func contents(_ scan: CardScan, text: ZenithCardImportStrings, language: AppLanguage) -> String {
        var parts: [String] = []
        if scan.photos > 0 { parts.append(photos(scan.photos, text: text, language: language)) }
        if scan.videos > 0 { parts.append(videos(scan.videos, text: text, language: language)) }
        return parts.joined(separator: " · ")
    }

    /// The capsule for a card that just mounted: `SD card · 1,248 photos · 64 GB`
    /// over the volume's name, its videos when it also has photos, and how
    /// many came off it before.
    static func notice(scan: CardScan, volume: String, importedBefore: Int, text: ZenithCardImportStrings,
                       language: AppLanguage) -> (title: String, subtitle: String) {
        let lead = scan.photos > 0 ? photos(scan.photos, text: text, language: language)
            : videos(scan.videos, text: text, language: language)
        let title = [text.sdCard, lead, bytes(scan.bytes)].joined(separator: " · ")
        var subtitle = [volume]
        if scan.photos > 0, scan.videos > 0 { subtitle.append(videos(scan.videos, text: text, language: language)) }
        if importedBefore > 0 {
            subtitle.append(filling(text.alreadyImported, count(importedBefore, locale: language.formattingLocale())))
        }
        return (title, subtitle.joined(separator: " · "))
    }

    /// `1,248 · 52 GB`, as a finished import reads.
    static func summary(files: Int, bytes value: Int64, language: AppLanguage) -> String {
        count(files, locale: language.formattingLocale()) + " · " + bytes(value)
    }
}
