// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: Remove Background's decisions. Which files are pictures,
/// where a press takes them from, where the result goes, the name beside the
/// original, the subject's bounds for a crop, the card's words and the
/// preferences. No Vision, no clipboard, no window.
enum RemoveBackgroundTests {
    static func run(_ suite: TestSuite) {
        pictures(suite)
        sources(suite)
        destinations(suite)
        naming(suite)
        cropping(suite)
        words(suite)
        preferences(suite)
    }

    private static func file(_ path: String) -> URL { URL(fileURLWithPath: path) }

    private static func pictures(_ suite: TestSuite) {
        for name in ["a.png", "b.JPG", "c.jpeg", "d.heic", "e.tiff", "f.webp", "g.gif"] {
            suite.expect(RemoveBackgroundSupport.isImage(file("/tmp/\(name)")), "\(name) is a picture")
        }
        for name in ["a.pdf", "b.txt", "c.mov", "d", "e.zip"] {
            suite.expect(!RemoveBackgroundSupport.isImage(file("/tmp/\(name)")), "\(name) is not a picture")
        }
        suite.expect(!RemoveBackgroundSupport.isImage(URL(string: "https://example.com/a.png")!),
                     "a web address is not a file")
        let many = (0..<30).map { file("/tmp/p\($0).png") }
        let mixed = [file("/tmp/a.png"), file("/tmp/notes.txt"), file("/tmp/a.png"), file("/tmp/b.jpg")]
        suite.expect(RemoveBackgroundSupport.images(in: mixed) == [file("/tmp/a.png"), file("/tmp/b.jpg")],
                     "pictures only, in order, once each")
        suite.expect(RemoveBackgroundSupport.images(in: many).count == RemoveBackgroundSupport.maximumFiles,
                     "at most \(RemoveBackgroundSupport.maximumFiles) a press")
    }

    private static func sources(_ suite: TestSuite) {
        typealias S = RemoveBackgroundSupport
        let selection = [file("/Users/me/a.png"), file("/Users/me/b.txt")]
        let copied = [file("/Users/me/c.jpg")]
        suite.expect(S.source(finderInFront: true, finderSelection: selection, clipboardFiles: copied, clipboardHasImage: true)
                        == .files([file("/Users/me/a.png")]),
                     "Finder in front with pictures selected: the selection")
        suite.expect(S.source(finderInFront: true, finderSelection: [file("/Users/me/b.txt")], clipboardFiles: copied,
                              clipboardHasImage: false) == .files(copied),
                     "a selection without pictures falls back to the clipboard")
        suite.expect(S.source(finderInFront: false, finderSelection: selection, clipboardFiles: copied,
                              clipboardHasImage: false) == .files(copied),
                     "another app in front: the clipboard, whatever Finder has selected")
        suite.expect(S.source(finderInFront: false, finderSelection: [], clipboardFiles: [], clipboardHasImage: true)
                        == .clipboardImage, "a copied picture that is not a file")
        suite.expect(S.source(finderInFront: false, finderSelection: [], clipboardFiles: [file("/tmp/x.txt")],
                              clipboardHasImage: false) == .nothing, "nothing to work on")
        suite.expect(S.clipboardSource(files: copied, hasImage: true) == .files(copied),
                     "a copied file wins over the picture data that comes with it")
    }

    private static func destinations(_ suite: TestSuite) {
        typealias S = RemoveBackgroundSupport
        let input = file("/Users/me/Pictures/cat.jpg")
        suite.expect(S.destination(for: input, output: .besideOriginal, folderWritable: true, exists: { _ in false })
                        == .file(file("/Users/me/Pictures/cat (no background).png")),
                     "beside the original")
        suite.expect(S.destination(for: input, output: .clipboard, folderWritable: true, exists: { _ in false }) == .clipboard,
                     "to the clipboard when that is the setting")
        suite.expect(S.destination(for: input, output: .besideOriginal, folderWritable: false, exists: { _ in false })
                        == .clipboard, "a folder it cannot write sends the result to the clipboard")
        suite.expect(S.destination(for: nil, output: .besideOriginal, folderWritable: true, exists: { _ in false })
                        == .clipboard, "a picture that was never a file goes back to the clipboard")
    }

    private static func naming(_ suite: TestSuite) {
        typealias S = RemoveBackgroundSupport
        let none: (URL) -> Bool = { _ in false }
        suite.expect(S.outputURL(for: file("/a/photo.jpg"), exists: none).path == "/a/photo (no background).png",
                     "photo.jpg becomes photo (no background).png")
        suite.expect(S.outputURL(for: file("/a/shot.PNG"), exists: none).lastPathComponent == "shot (no background).png",
                     "always a PNG, which keeps the transparency")
        suite.expect(S.outputURL(for: file("/a/my.trip.photo.heic"), exists: none).lastPathComponent
                        == "my.trip.photo (no background).png", "only the last extension goes")
        let taken: Set<String> = ["/a/photo (no background).png", "/a/photo (no background) 2.png"]
        suite.expect(S.outputURL(for: file("/a/photo.jpg"), exists: { taken.contains($0.path) }).lastPathComponent
                        == "photo (no background) 3.png", "never over an existing file")
        suite.expect(S.outputURL(for: file("/a/photo (no background).png"), exists: { taken.contains($0.path) })
                        .lastPathComponent == "photo (no background) 3.png",
                     "a result run again does not stack the suffix")
        suite.expect(S.outputURL(for: file("/a/.png"), exists: none).lastPathComponent.hasSuffix(" (no background).png"),
                     "a file with no name still gets one")
    }

    private static func cropping(_ suite: TestSuite) {
        typealias S = RemoveBackgroundSupport
        // A 6 × 4 picture, 32 bytes a row (8 of padding), an opaque 2 × 2
        // block at x 1...2, y 1...2 and one faint pixel at the corner.
        let width = 6, height = 4, row = 32
        var rgba = [UInt8](repeating: 0, count: row * height)
        for (x, y) in [(1, 1), (2, 1), (1, 2), (2, 2)] { rgba[y * row + x * 4 + 3] = 255 }
        rgba[3 * row + 5 * 4 + 3] = 4
        suite.expect(S.subjectBounds(rgba: rgba, width: width, height: height, bytesPerRow: row)
                        == CGRect(x: 1, y: 1, width: 2, height: 2),
                     "the subject's bounds, a faint edge pixel left out")
        suite.expect(S.subjectBounds(rgba: rgba, width: width, height: height, bytesPerRow: row, threshold: 1)
                        == CGRect(x: 1, y: 1, width: 5, height: 3), "a lower threshold takes the faint pixel in")
        suite.expect(S.subjectBounds(rgba: [UInt8](repeating: 0, count: row * height), width: width, height: height,
                                     bytesPerRow: row) == nil, "a picture with no subject has no bounds")
        let full = [UInt8](repeating: 255, count: 4 * 3 * 2)
        suite.expect(S.subjectBounds(rgba: full, width: 3, height: 2, bytesPerRow: 12) == CGRect(x: 0, y: 0, width: 3, height: 2),
                     "an opaque picture keeps its whole canvas")
        suite.expect(S.subjectBounds(rgba: [1, 2, 3], width: 3, height: 2, bytesPerRow: 12) == nil
                        && S.subjectBounds(rgba: full, width: 3, height: 2, bytesPerRow: 4) == nil
                        && S.subjectBounds(rgba: full, width: 0, height: 2, bytesPerRow: 12) == nil,
                     "a buffer too small for its size is refused, not read past")
    }

    private static func words(_ suite: TestSuite) {
        typealias S = RemoveBackgroundSupport
        suite.expect(S.summary(done: 1, failed: 0, toClipboard: false) == "Background removed", "one")
        suite.expect(S.summary(done: 1, failed: 0, toClipboard: true) == "Background removed · copied", "copied")
        suite.expect(S.summary(done: 3, failed: 1, toClipboard: false) == "3 backgrounds removed · 1 without a subject",
                     "several, one without a subject")
        suite.expect(S.summary(done: 0, failed: 1, toClipboard: false) == "No subject found"
                        && S.summary(done: 0, failed: 2, toClipboard: true) == "No subjects found", "none")
        suite.expect(RemoveBackgroundOutput.allCases.map(\.title) == ["Beside the original", "Clipboard"]
                        && RemoveBackgroundFraming.allCases.map(\.title) == ["Keep the canvas", "Crop to the subject"],
                     "the choices read in English")
    }

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.remove-background"
        guard let defaults = UserDefaults(suiteName: domain) else { return suite.expect(false, "test defaults") }
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let fresh = RemoveBackgroundPreferences(defaults: defaults)
        suite.expect(!fresh.enabled && fresh.output == .besideOriginal && fresh.framing == .keep,
                     "off by default; beside the original, canvas kept")
        defaults.set("clipboard", forKey: RemoveBackgroundDefaults.output)
        defaults.set("crop", forKey: RemoveBackgroundDefaults.framing)
        let set = RemoveBackgroundPreferences(defaults: defaults)
        suite.expect(set.output == .clipboard && set.framing == .crop, "the choices are read")
        defaults.set("elsewhere", forKey: RemoveBackgroundDefaults.output)
        suite.expect(RemoveBackgroundPreferences(defaults: defaults).output == .besideOriginal,
                     "an unknown choice reads as the default")
        suite.expect(RemoveBackgroundDefaults.backupKeys.count == 4
                        && RemoveBackgroundDefaults.backupKeys.allSatisfy { $0.hasPrefix("zenithRemoveBackground") },
                     "the backup carries the four preferences")
    }
}
