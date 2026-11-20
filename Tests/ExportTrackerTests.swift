// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the export tracker: which files count and which stay out,
/// the growth and stability state machine on a fake clock, naming the app
/// that writes, sizes and times as the island reads them, several exports at
/// once, batches of images, and a real file written in chunks on disk.
enum ExportTrackerTests {
    typealias Support = ExportTrackerSupport

    static func run(_ suite: TestSuite) {
        filter(suite)
        folders(suite)
        preferences(suite)
        growth(suite)
        quietFiles(suite)
        rewrites(suite)
        producers(suite)
        formatting(suite)
        concurrent(suite)
        batches(suite)
        realFile(suite)
        strings(suite)
    }

    private static let base = Date(timeIntervalSince1970: 1_763_600_000)
    private static func at(_ seconds: TimeInterval) -> Date { base.addingTimeInterval(seconds) }
    private static let configuration = Support.Configuration(minimumBytes: 1_000_000)
    private static let movies = "/Users/me/Movies"
    private static let mb: Int64 = 1_000_000

    // MARK: Filter

    private static func filter(_ suite: TestSuite) {
        let roots = [movies, "/Users/me/Desktop"]
        let counted = ["Wedding.mov", "CLIENT/Export/final.MP4", "a.mxf", "b.m4v", "rec.mkv", "c.braw", "mix.wav",
                       "voice.aac", "song.mp3", "p.jpg", "p.jpeg", "p.png", "p.tif", "p.tiff", "p.heic", "art.psd",
                       "deck.pdf"]
        for name in counted {
            suite.expect(Support.isCandidate(movies + "/" + name, roots: roots), "\(name) is a media output")
        }
        suite.expect(Support.isCandidate("/Users/me/Desktop/clip.mov", roots: roots),
                     "a file in another watched folder counts")
        let left: [(String, String)] = [
            ("notes.txt", "a file that is not media"),
            ("clip", "a file without an extension"),
            (".hidden.mov", "a hidden file"),
            ("clip.mov.part", "a partial download"),
            ("clip.part.mov", "a temporary name before the extension"),
            ("clip.tmp.mov", "a temporary file"),
            ("clip.mp4.crdownload", "a browser download"),
            ("~$deck.pdf", "an Office lock file"),
            ("Project/CacheClip/frame.mov", "Resolve's render cache"),
            ("Project/.gallery/still.png", "Resolve's gallery"),
            ("Day 1/ProxyMedia/A001.mov", "proxies"),
            ("Day 1/OptimizedMedia/A001.mov", "optimized media"),
            ("Untitled.fcpbundle/Event/Render Files/a.mov", "Final Cut's render files"),
            ("Photos Library.photoslibrary/originals/a.heic", "a photo library"),
            ("Catalog.lrdata/preview.jpg", "Lightroom previews"),
            (".Trash/old.mov", "a hidden folder"),
            ("clip.mov.download/clip.mov", "Safari's download package"),
        ]
        for (name, what) in left {
            suite.expect(!Support.isCandidate(movies + "/" + name, roots: roots), "\(what) stays out")
        }
        suite.expect(!Support.isCandidate("/Users/me/Movies2/clip.mov", roots: roots)
                     && !Support.isCandidate("/Users/me/Documents/clip.mov", roots: roots)
                     && !Support.isCandidate(movies, roots: roots),
                     "only files below a watched folder count, not a folder whose name starts the same")
        suite.expect(Support.fileExtension("/a/B.MOV") == "mov" && Support.fileExtension("/a/.mov") == ""
                     && Support.fileExtension("/a/b") == "",
                     "the extension is read in lower case, a leading dot is no extension")
    }

    private static func folders(_ suite: TestSuite) {
        let home = "/Users/me"
        suite.expect(Support.entry(forPath: "/Users/me/Movies", home: home) == "~/Movies"
                     && Support.entry(forPath: "/Users/me/Movies/", home: home) == "~/Movies"
                     && Support.entry(forPath: "/Users/me", home: home) == "~"
                     && Support.entry(forPath: "/Volumes/Footage/Exports", home: home) == "/Volumes/Footage/Exports"
                     && Support.entry(forPath: "/Users/meow/Movies", home: home) == "/Users/meow/Movies",
                     "a folder under home is kept as ~/…, so a backup reads on another Mac")
        suite.expect(Support.expanded("~/Movies", home: home + "/") == "/Users/me/Movies"
                     && Support.expanded("~", home: home) == home
                     && Support.expanded("/Volumes/Footage/", home: home) == "/Volumes/Footage",
                     "an entry expands back to its folder")
        let list = [Support.Folder(entry: "~/Movies", on: true), Support.Folder(entry: "~/Movies/Exports", on: true),
                    Support.Folder(entry: "~/Desktop", on: true), Support.Folder(entry: "~/Downloads", on: false),
                    Support.Folder(entry: "/Volumes/Footage", on: true), Support.Folder(entry: "relative", on: true)]
        suite.expect(Support.roots(list, home: home) == ["/Users/me/Desktop", "/Users/me/Movies", "/Volumes/Footage"],
                     "folders switched off, relative paths and folders inside another are not watched twice")
    }

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.export-tracker"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(!Support.isEnabled(in: defaults) && Support.minimum(in: defaults) == 1
                     && Support.configuration(in: defaults).minimumBytes == 1_000_000,
                     "off by default, a file shows from 1 MB")
        suite.expect(Support.folders(in: defaults) == [Support.Folder(entry: "~/Movies", on: true),
                                                       Support.Folder(entry: "~/Desktop", on: true),
                                                       Support.Folder(entry: "~/Downloads", on: false)],
                     "Movies and Desktop are watched, Downloads is listed but off")
        defaults.set(50, forKey: DefaultsKey.notchExportMinimum)
        suite.expect(Support.minimum(in: defaults) == 50, "a listed minimum is kept")
        defaults.set(7, forKey: DefaultsKey.notchExportMinimum)
        suite.expect(Support.minimum(in: defaults) == 1, "anything else falls back to 1 MB")
        defaults.set(["~/Movies", " ~/Movies ", "", "/Volumes/A"], forKey: DefaultsKey.notchExportFolders)
        defaults.set(["/Volumes/A"], forKey: DefaultsKey.notchExportFoldersOff)
        suite.expect(Support.folders(in: defaults) == [Support.Folder(entry: "~/Movies", on: true),
                                                       Support.Folder(entry: "/Volumes/A", on: false)],
                     "the stored list is trimmed, without blanks or doubles")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.notchExportTracker] as? Bool == false
                     && registered[DefaultsKey.notchExportFolders] as? [String] == ["~/Movies", "~/Desktop", "~/Downloads"]
                     && registered[DefaultsKey.notchExportFoldersOff] as? [String] == ["~/Downloads"]
                     && registered[DefaultsKey.notchExportMinimum] as? Int == 1
                     && registered[DefaultsKey.notchExportSound] as? Bool == true
                     && registered[DefaultsKey.notchExportNotify] as? Bool == true,
                     "every option is registered, so it is backed up")
    }

    // MARK: State machine

    private static func growth(_ suite: TestSuite) {
        let path = movies + "/Wedding.mov"
        var tracker = Support.Tracker()
        suite.expect(tracker.noteChange(path: path, size: 0, now: at(0), configuration: configuration)
                     && tracker.isSampling && tracker.activity(now: at(0), configuration: configuration) == nil,
                     "a new file is tracked but not shown before it grows")
        tracker.sample(path: path, size: 400_000, now: at(1), configuration: configuration)
        suite.expect(tracker.activity(now: at(1), configuration: configuration) == nil,
                     "a file still under the minimum does not show")
        tracker.sample(path: path, size: 3 * mb, now: at(2), configuration: configuration)
        let running = tracker.activity(now: at(2), configuration: configuration)
        suite.expect(running?.phase == .running && running?.name == "Wedding.mov" && running?.started == at(0)
                     && running?.others == 0 && running?.bytes == nil,
                     "once it keeps growing past the minimum it shows, timed from when it appeared")
        let live = tracker.live(now: at(2), configuration: configuration)
        suite.expect(live?.id == path && live?.bytes == 3 * mb && (live?.rate ?? 0) > 0,
                     "its size and rate are live, apart from what lays the island out")
        tracker.sample(path: path, size: 5 * mb, now: at(3), configuration: configuration)
        suite.expect(tracker.activity(now: at(3), configuration: configuration) == running,
                     "a new size changes nothing the island lays out")
        for second in 4...6 {
            tracker.sample(path: path, size: 5 * mb, now: at(TimeInterval(second)), configuration: configuration)
            suite.expect(tracker.writerChecksDue(now: at(TimeInterval(second)), configuration: configuration).isEmpty,
                         "a size still for \(second - 3) s is not asked about yet")
        }
        tracker.sample(path: path, size: 5 * mb, now: at(7), configuration: configuration)
        suite.expect(tracker.writerChecksDue(now: at(7), configuration: configuration).map(\.path) == [path],
                     "after 4 s at the same size, whoever writes it is asked")
        tracker.writerChecked(path: path, writing: true, writerPID: 321, now: at(7))
        tracker.advance(now: at(7), configuration: configuration)
        suite.expect(tracker.activity(now: at(7), configuration: configuration)?.phase == .running
                     && tracker.takeFinished().isEmpty
                     && tracker.writerChecksDue(now: at(7.5), configuration: configuration).isEmpty
                     && tracker.writerChecksDue(now: at(8), configuration: configuration).first?.pid == 321,
                     "a file still open for writing (a slow render, a paused recording) keeps running, asked each second")
        tracker.sample(path: path, size: 9 * mb, now: at(9), configuration: configuration)
        suite.expect(tracker.writerChecksDue(now: at(12), configuration: configuration).isEmpty,
                     "growing again restarts the 4 s")
        tracker.sample(path: path, size: 9 * mb, now: at(13), configuration: configuration)
        tracker.writerChecked(path: path, writing: false, now: at(13))
        tracker.advance(now: at(13), configuration: configuration)
        let done = tracker.activity(now: at(13), configuration: configuration)
        suite.expect(done?.phase == .finished && done?.bytes == 9 * mb && done?.duration == 9 && !tracker.isSampling,
                     "closed and still, it is done: ✓ with the final size and the time it grew")
        let finished = tracker.takeFinished()
        suite.expect(finished.count == 1 && finished.first?.path == path && finished.first?.bytes == 9 * mb
                     && tracker.takeFinished().isEmpty,
                     "the end is announced once")
        suite.expect(tracker.nextChange(after: at(13), configuration: configuration) == at(21)
                     && tracker.activity(now: at(20.9), configuration: configuration)?.phase == .finished,
                     "the ✓ stays 8 s")
        tracker.advance(now: at(21), configuration: configuration)
        suite.expect(tracker.activity(now: at(21), configuration: configuration) == nil,
                     "then the island lets it go")

        var fallback = Support.Tracker()
        fallback.noteChange(path: path, size: 0, now: at(0), configuration: configuration)
        fallback.sample(path: path, size: 2 * mb, now: at(1), configuration: configuration)
        fallback.sample(path: path, size: 2 * mb, now: at(5), configuration: configuration)
        fallback.writerChecked(path: path, writing: nil, now: at(5))
        suite.expect(fallback.activity(now: at(5), configuration: configuration)?.phase == .finished,
                     "when nobody can say who writes it, a size still for 4 s alone ends it")

        var born = Support.Tracker()
        born.noteChange(path: path, size: 2 * mb, created: at(-30), now: at(0), configuration: configuration)
        born.sample(path: path, size: 4 * mb, now: at(1), configuration: configuration)
        suite.expect(born.activity(now: at(1), configuration: configuration)?.started == at(-30),
                     "a file noticed late is timed from its creation")
        var old = Support.Tracker()
        old.noteChange(path: path, size: 2 * mb, created: at(-3 * 86_400), now: at(0), configuration: configuration)
        old.sample(path: path, size: 4 * mb, now: at(1), configuration: configuration)
        suite.expect(old.activity(now: at(1), configuration: configuration)?.started == at(0),
                     "an old file written to again is timed from now")
    }

    private static func quietFiles(_ suite: TestSuite) {
        let copy = movies + "/copied.mov"
        var tracker = Support.Tracker()
        tracker.noteChange(path: copy, size: 800 * mb, now: at(0), configuration: configuration)
        for second in 1...4 {
            tracker.sample(path: copy, size: 800 * mb, now: at(TimeInterval(second)), configuration: configuration)
            tracker.advance(now: at(TimeInterval(second)), configuration: configuration)
            suite.expect(tracker.activity(now: at(TimeInterval(second)), configuration: configuration) == nil,
                         "a file that landed whole never shows (\(second) s)")
        }
        suite.expect(!tracker.isSampling && tracker.takeFinished().isEmpty,
                     "after 4 s it is let go, no sampling, nothing announced")
        suite.expect(!tracker.noteChange(path: copy, size: 800 * mb, now: at(10), configuration: configuration),
                     "a tag or Spotlight touching it again does not track it again")

        let small = movies + "/small.mp3"
        var tiny = Support.Tracker()
        tiny.noteChange(path: small, size: 0, now: at(0), configuration: configuration)
        for second in 1...8 {
            tiny.sample(path: small, size: Int64(second) * 100_000, now: at(TimeInterval(second)),
                        configuration: configuration)
        }
        suite.expect(tiny.activity(now: at(8), configuration: configuration) == nil,
                     "a file growing under the minimum never shows")

        let gone = movies + "/gone.mov"
        var deleted = Support.Tracker()
        deleted.noteChange(path: gone, size: 0, now: at(0), configuration: configuration)
        deleted.sample(path: gone, size: 5 * mb, now: at(1), configuration: configuration)
        deleted.sample(path: gone, size: nil, now: at(2), configuration: configuration)
        suite.expect(deleted.activity(now: at(2), configuration: configuration) == nil && !deleted.isSampling,
                     "a file removed or renamed away stops showing, with nothing announced")
    }

    private static func rewrites(_ suite: TestSuite) {
        let path = movies + "/Render.mp4"
        var tracker = Support.Tracker()
        tracker.noteChange(path: path, size: 0, now: at(0), configuration: configuration)
        tracker.sample(path: path, size: 5 * mb, now: at(1), configuration: configuration)
        tracker.sample(path: path, size: 5 * mb, now: at(5), configuration: configuration)
        tracker.writerChecked(path: path, writing: false, now: at(5))
        _ = tracker.takeFinished()
        suite.expect(tracker.noteChange(path: path, size: 6 * mb, now: at(7), configuration: configuration)
                     && tracker.activity(now: at(7), configuration: configuration)?.phase == .running
                     && tracker.activity(now: at(7), configuration: configuration)?.started == at(0),
                     "a file that writes again moments after its ✓ picks up where it left")

        var producer = Support.Tracker()
        producer.noteChange(path: path, size: 0, now: at(0), configuration: configuration)
        producer.sample(path: path, size: 5 * mb, now: at(1), configuration: configuration)
        suite.expect(producer.wantsAttribution(now: at(1), configuration: configuration) == [path],
                     "an export just shown is asked who writes it")
        producer.attribute(path: path, .unknown, now: at(1))
        suite.expect(producer.wantsAttribution(now: at(2), configuration: configuration).isEmpty
                     && producer.wantsAttribution(now: at(3), configuration: configuration) == [path],
                     "a writer not found is asked again later, every time a little later")
        let resolve = Support.Producer(name: "DaVinci Resolve", kind: .video, tint: 0xFB923C)
        producer.attribute(path: path, .producer(resolve), pid: 77, now: at(3))
        suite.expect(producer.activity(now: at(3), configuration: configuration)?.producer == resolve
                     && producer.wantsAttribution(now: at(10), configuration: configuration).isEmpty,
                     "once found, the app shows and is not asked again")
        var copy = Support.Tracker()
        copy.noteChange(path: path, size: 0, now: at(0), configuration: configuration)
        copy.sample(path: path, size: 5 * mb, now: at(1), configuration: configuration)
        copy.attribute(path: path, .ignored, now: at(1))
        suite.expect(copy.activity(now: at(1), configuration: configuration) == nil && !copy.isSampling,
                     "a file Finder, a sync or Zenith itself writes is let go")
    }

    // MARK: Producers

    private static func producers(_ suite: TestSuite) {
        func named(_ executable: String, _ file: String = "/Users/me/Movies/a.mov") -> Support.Producer? {
            guard case .producer(let producer) = Support.attribution(executablePath: executable, pid: 10, ownPID: 1,
                                                                     path: file) else { return nil }
            return producer
        }
        let resolve = named("/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/MacOS/Resolve")
        suite.expect(resolve?.name == "DaVinci Resolve" && resolve?.kind == .video
                     && resolve?.bundlePath == "/Applications/DaVinci Resolve/DaVinci Resolve.app",
                     "DaVinci Resolve is named from its app, whose icon the island shows")
        let obs = named("/Applications/OBS.app/Contents/MacOS/OBS")
        suite.expect(obs?.name == "OBS" && obs?.kind == .recorder, "OBS records")
        let table: [(String, String, Support.Producer.Kind)] = [
            ("/Applications/Final Cut Pro.app/Contents/MacOS/Final Cut Pro", "Final Cut Pro", .video),
            ("/Applications/Final Cut Pro.app/Contents/XPCServices/Render.xpc/Contents/MacOS/Render", "Final Cut Pro", .video),
            ("/Applications/Compressor.app/Contents/MacOS/Compressor", "Compressor", .encoder),
            ("/Applications/Adobe Premiere Pro 2025/Adobe Premiere Pro 2025.app/Contents/MacOS/Adobe Premiere Pro 2025",
             "Premiere Pro", .video),
            ("/Applications/Adobe Media Encoder 2025/Adobe Media Encoder 2025.app/Contents/MacOS/Adobe Media Encoder 2025",
             "Media Encoder", .encoder),
            ("/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app/Contents/MacOS/Adobe Lightroom Classic",
             "Lightroom Classic", .photo),
            ("/Applications/Adobe Lightroom/Adobe Lightroom.app/Contents/MacOS/Adobe Lightroom", "Lightroom", .photo),
            ("/Applications/Adobe Photoshop 2025/Adobe Photoshop 2025.app/Contents/MacOS/Adobe Photoshop 2025",
             "Photoshop", .photo),
            ("/System/Applications/Photos.app/Contents/MacOS/Photos", "Photos", .photo),
            ("/opt/homebrew/bin/ffmpeg", "ffmpeg", .encoder),
            ("/Applications/HandBrake.app/Contents/MacOS/HandBrake", "HandBrake", .encoder),
            ("/usr/local/bin/HandBrakeCLI", "HandBrake", .encoder),
            ("/Applications/Logic Pro.app/Contents/MacOS/Logic Pro X", "Logic Pro", .audio),
        ]
        for (executable, name, kind) in table {
            let producer = named(executable)
            suite.expect(producer?.name == name && producer?.kind == kind, "\(executable) is \(name)")
        }
        suite.expect(named("/opt/homebrew/bin/ffmpeg")?.bundlePath == nil,
                     "a program outside an app has no icon, so its glyph shows")
        let unknown = named("/Applications/Kdenlive.app/Contents/MacOS/kdenlive", "/Users/me/Movies/a.mp4")
        suite.expect(unknown?.name == "Kdenlive" && unknown?.kind == .video
                     && named("/usr/local/bin/x265", "/Users/me/Movies/a.wav")?.kind == .audio,
                     "an app not in the list is named as it is, its kind taken from the file")
        let ignored = ["/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder", "/bin/cp", "/usr/bin/ditto",
                       "/usr/bin/rsync", "/Applications/Safari.app/Contents/MacOS/Safari",
                       "/Applications/Dropbox.app/Contents/MacOS/Dropbox",
                       "/System/Library/PrivateFrameworks/CloudDocsDaemon.framework/Versions/A/Support/bird",
                       "/Applications/Zenith.app/Contents/MacOS/Zenith"]
        for executable in ignored {
            suite.expect(Support.attribution(executablePath: executable, pid: 10, ownPID: 1, path: "/a/b.mov") == .ignored,
                         "\(executable) copies, syncs or downloads: never an export")
        }
        suite.expect(Support.attribution(executablePath: "/Applications/OBS.app/Contents/MacOS/OBS", pid: 5, ownPID: 5,
                                         path: "/a/b.mov") == .ignored,
                     "Zenith's own outputs stay out")
        suite.expect(Support.attribution(executablePath: "", pid: 10, ownPID: 1, path: "/a/b.mov") == .unknown,
                     "a process without a path says nothing")

        let finder = "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"
        let daemon = "/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/Versions/A/Support/photolibraryd"
        let lightroom = "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app/Contents/MacOS/Adobe Lightroom Classic"
        let davinci = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/MacOS/Resolve"
        let photos = "/System/Applications/Photos.app/Contents/MacOS/Photos"
        suite.expect(Support.batchProducer(runningExecutables: [finder, daemon]) == nil,
                     "with no app that exports images running, a batch is a copy")
        suite.expect(Support.batchProducer(runningExecutables: [finder, daemon, lightroom])?.name == "Lightroom Classic",
                     "a running photo app is credited with a batch of images")
        suite.expect(Support.batchProducer(runningExecutables: [davinci, photos])?.name == "Photos"
                     && Support.batchProducer(runningExecutables: [davinci])?.name == "DaVinci Resolve",
                     "a photo app comes before a video app, which can render stills")
        suite.expect(Support.isWriteMode(openFlags: 0x2) && Support.isWriteMode(openFlags: 0x3)
                     && !Support.isWriteMode(openFlags: 0x1),
                     "the kernel's FWRITE says a file is open for writing")
    }

    // MARK: Formatting

    private static func formatting(_ suite: TestSuite) {
        let cases: [(Int64, String)] = [
            (0, "0 KB"), (830_000, "830 KB"), (1_000_000, "1.0 MB"), (4_200_000, "4.2 MB"), (512_000_000, "512 MB"),
            (999_600_000, "1.0 GB"), (2_100_000_000, "2.1 GB"), (4_249_000_000, "4.2 GB"), (123_400_000_000, "123 GB"),
            (1_200_000_000_000, "1.2 TB"), (-5, "0 KB"),
        ]
        for (bytes, text) in cases {
            suite.expect(Support.size(bytes) == text, "\(bytes) bytes read \(text), got \(Support.size(bytes))")
        }
        let german = Locale(identifier: "de_DE")
        suite.expect(Support.size(2_100_000_000, locale: german) == "2,1 GB"
                     && Support.sizeTemplate(locale: german) == "00,0 GB",
                     "the decimal mark follows the language")
        let template = Support.sizeTemplate().count
        let sweep = stride(from: 0.0, through: 14.0, by: 0.05).map { Int64(pow(10, $0)) }
        suite.expect(sweep.allSatisfy { Support.size($0).count <= template },
                     "the size's slot holds its widest reading, so its width never changes while it grows")
        suite.expect(Support.finishedDetail(bytes: 4_200_000_000, duration: 751) == "4.2 GB · 12:31"
                     && Support.finishedDetail(bytes: 2 * mb, duration: 3725) == "2.0 MB · 1:02:05",
                     "done reads its size and how long it took")
        suite.expect(Support.rate(48_000_000) == "48 MB/s" && Support.rate(0).isEmpty && Support.rate(.nan).isEmpty,
                     "the rate reads per second, and nothing without one")
        suite.expect(Support.filling("%d images", count: 12) == "12 images", "a batch fills its count")
    }

    // MARK: Several at once

    private static func concurrent(_ suite: TestSuite) {
        let first = movies + "/Ceremony.mov", second = movies + "/Reception.mov"
        var tracker = Support.Tracker()
        tracker.noteChange(path: first, size: 0, now: at(0), configuration: configuration)
        tracker.sample(path: first, size: 5 * mb, now: at(1), configuration: configuration)
        tracker.noteChange(path: second, size: 0, now: at(3), configuration: configuration)
        tracker.sample(path: first, size: 9 * mb, now: at(4), configuration: configuration)
        tracker.sample(path: second, size: 2 * mb, now: at(4), configuration: configuration)
        let both = tracker.activity(now: at(4), configuration: configuration)
        suite.expect(both?.path == second && both?.others == 1 && tracker.live(now: at(4), configuration: configuration)?.id == second,
                     "two exports show the newest, +1")
        suite.expect(Set(tracker.sampledPaths) == [first, second], "both are sized each second")
        for second in 5...8 {
            tracker.sample(path: first, size: 9 * mb, now: at(TimeInterval(second)), configuration: configuration)
        }
        tracker.sample(path: second, size: 6 * mb, now: at(8), configuration: configuration)
        suite.expect(tracker.writerChecksDue(now: at(8), configuration: configuration).map(\.path) == [first],
                     "only the one that stopped growing is asked about")
        tracker.writerChecked(path: first, writing: false, now: at(8))
        let firstDone = tracker.activity(now: at(8), configuration: configuration)
        suite.expect(firstDone?.phase == .finished && firstDone?.path == first && firstDone?.others == 1
                     && tracker.live(now: at(8), configuration: configuration) == nil,
                     "the one that ended shows its ✓ first, the other still counted")
        tracker.advance(now: at(16), configuration: configuration)
        let after = tracker.activity(now: at(16), configuration: configuration)
        suite.expect(after?.phase == .running && after?.path == second && after?.others == 0,
                     "then the island goes back to the one still running")
        suite.expect(tracker.takeFinished().map(\.path) == [first], "only the finished one is announced")
    }

    private static func batches(_ suite: TestSuite) {
        let folder = "/Users/me/Desktop/Wedding Selects"
        let lightroom = Support.Producer(name: "Lightroom Classic", kind: .photo, tint: 0x38BDF8)
        var tracker = Support.Tracker()
        for index in 0..<3 {
            let path = folder + "/IMG_\(index).jpg"
            let time = TimeInterval(index)
            tracker.noteChange(path: path, size: 6 * mb, now: at(time), configuration: configuration)
            tracker.sample(path: path, size: 6 * mb, now: at(time + 1), configuration: configuration)
        }
        suite.expect(tracker.wantsBatchProducer == [folder] && tracker.activity(now: at(3), configuration: configuration) == nil,
                     "images landing whole wait to know whether an app that exports them runs")
        tracker.setBatchProducer(folder: folder, lightroom)
        let running = tracker.activity(now: at(3), configuration: configuration)
        suite.expect(running?.phase == .running && running?.count == 3 && running?.producer == lightroom
                     && running?.name == "Wedding Selects"
                     && tracker.live(now: at(3), configuration: configuration)?.bytes == 18 * mb
                     && !tracker.isSampling,
                     "three or more in one folder are one export, counted, with their total size")
        // One caught half written still joins the batch rather than showing alone.
        let late = folder + "/IMG_3.jpg"
        tracker.noteChange(path: late, size: 0, now: at(4), configuration: configuration)
        tracker.sample(path: late, size: 7 * mb, now: at(5), configuration: configuration)
        suite.expect(tracker.activity(now: at(5), configuration: configuration)?.count == 3,
                     "an image half written is no export of its own")
        tracker.sample(path: late, size: 7 * mb, now: at(6), configuration: configuration)
        suite.expect(tracker.activity(now: at(6), configuration: configuration)?.count == 4,
                     "and joins the batch once written")
        suite.expect(tracker.nextChange(after: at(6), configuration: configuration) == at(10),
                     "the batch is due to end 4 s after its last image")
        tracker.advance(now: at(10), configuration: configuration)
        let done = tracker.activity(now: at(10), configuration: configuration)
        suite.expect(done?.phase == .finished && done?.count == 4 && done?.bytes == 25 * mb && done?.path == late
                     && done?.duration == 6,
                     "no image for 4 s ends it: ✓ with the count, total size and time")
        let finished = tracker.takeFinished()
        suite.expect(finished.count == 1 && finished.first?.count == 4, "a batch is announced once")

        var copies = Support.Tracker()
        for index in 0..<6 {
            let path = folder + "/copy_\(index).jpg"
            copies.noteChange(path: path, size: 6 * mb, now: at(0), configuration: configuration)
            copies.sample(path: path, size: 6 * mb, now: at(1), configuration: configuration)
        }
        copies.setBatchProducer(folder: folder, nil)
        suite.expect(copies.activity(now: at(1), configuration: configuration) == nil,
                     "with no such app running, images landing are a copy and never show")
        copies.advance(now: at(6), configuration: configuration)
        suite.expect(copies.takeFinished().isEmpty, "and nothing is announced")

        var pair = Support.Tracker()
        for index in 0..<2 {
            let path = folder + "/pair_\(index).png"
            pair.noteChange(path: path, size: 6 * mb, now: at(0), configuration: configuration)
            pair.sample(path: path, size: 6 * mb, now: at(1), configuration: configuration)
        }
        pair.setBatchProducer(folder: folder, lightroom)
        suite.expect(pair.activity(now: at(1), configuration: configuration) == nil,
                     "two images are not yet a batch")
        let video = movies + "/whole.mov"
        var whole = Support.Tracker()
        whole.noteChange(path: video, size: 6 * mb, now: at(0), configuration: configuration)
        whole.sample(path: video, size: 6 * mb, now: at(1), configuration: configuration)
        suite.expect(whole.batches.isEmpty, "a video landing whole never joins a batch")
    }

    // MARK: A real file

    /// A file written in chunks on disk while it stays open, then left still
    /// and closed: active, held while open, then done. The clock is fake; the
    /// sizes and the open-for-writing answers are the real ones.
    private static func realFile(_ suite: TestSuite) {
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.export-tracker-"
                                                                       + UUID().uuidString, isDirectory: true)
        guard (try? manager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
            suite.expect(false, "the temporary folder is created")
            return
        }
        defer { try? manager.removeItem(at: folder) }
        let root = ExportWriterProbe.canonical(folder.path)
        let path = root + "/Render.mov"
        guard manager.createFile(atPath: path, contents: nil), let handle = FileHandle(forWritingAtPath: path) else {
            suite.expect(false, "the file is created")
            return
        }
        func size() -> Int64? { ((try? manager.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.int64Value }
        suite.expect(Support.isCandidate(path, roots: [root]), "the file counts under its folder")
        var tracker = Support.Tracker()
        var clock: TimeInterval = 0
        tracker.noteChange(path: path, size: size(), now: at(clock), configuration: configuration)
        let chunk = Data(repeating: 0x5A, count: 700_000)
        for _ in 0..<4 {
            try? handle.write(contentsOf: chunk)
            clock += 1
            tracker.sample(path: path, size: size(), now: at(clock), configuration: configuration)
        }
        suite.expect(tracker.activity(now: at(clock), configuration: configuration)?.phase == .running
                     && tracker.live(now: at(clock), configuration: configuration)?.bytes == 2_800_000,
                     "written in chunks, the file shows with its real size")
        let openers = ExportWriterProbe.openers(of: path) ?? []
        suite.expect(openers.contains { $0.pid == getpid() && $0.writing },
                     "the kernel says this process has it open for writing")
        let own = openers.first { $0.pid == getpid() }?.executable ?? ""
        suite.expect(Support.attribution(executablePath: own, pid: getpid(), ownPID: getpid(), path: path) == .ignored,
                     "a file this process writes is its own output")
        // It stops growing but stays open: still running.
        for _ in 0..<4 {
            clock += 1
            tracker.sample(path: path, size: size(), now: at(clock), configuration: configuration)
        }
        for check in tracker.writerChecksDue(now: at(clock), configuration: configuration) {
            tracker.writerChecked(path: check.path, writing: ExportWriterProbe.isWriting(check.path, pid: getpid()),
                                  writerPID: getpid(), now: at(clock))
        }
        suite.expect(tracker.activity(now: at(clock), configuration: configuration)?.phase == .running,
                     "still for 4 s but open for writing, it keeps running")
        try? handle.close()
        clock += 1
        tracker.sample(path: path, size: size(), now: at(clock), configuration: configuration)
        let checks = tracker.writerChecksDue(now: at(clock), configuration: configuration)
        suite.expect(checks.first?.pid == getpid(), "the known writer is asked again")
        for check in checks {
            tracker.writerChecked(path: check.path, writing: ExportWriterProbe.isWriting(check.path, pid: getpid()),
                                  now: at(clock))
        }
        let done = tracker.activity(now: at(clock), configuration: configuration)
        suite.expect(done?.phase == .finished && done?.bytes == 2_800_000 && done?.duration == 4,
                     "closed, it is done with its final size and the time it grew")
        suite.expect(ExportWriterProbe.openers(of: path)?.isEmpty == true, "nobody has it open any more")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.exportTracker(language)
            let all = [text.activityTitle, text.section, text.toggle, text.toggleCaption, text.folders,
                       text.foldersCaption, text.addFolder, text.removeFolder, text.missing, text.choose,
                       text.minimumSize, text.megabytes, text.sound, text.notify, text.notifyCaption, text.exporting,
                       text.recording, text.exportFinished, text.recordingSaved, text.images, text.finished]
            suite.expect(!all.contains { $0.isEmpty } && text.megabytes.contains("%d") && text.images.contains("%d"),
                         "\(language.rawValue) has the export tracker's text")
            suite.expect(!all.contains { $0.contains("—") || $0.contains("'") },
                         "\(language.rawValue) uses curly apostrophes and no em dash")
        }
    }
}
