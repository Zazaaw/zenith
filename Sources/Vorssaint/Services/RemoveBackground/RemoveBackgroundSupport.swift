// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

// Zenith fork: Remove Background's decisions, without Vision, windows or the
// real clipboard, so the tests reach them: the preferences, which pictures it
// works on and where they come from, where the result goes, the name of a
// file beside the original, and the subject's bounds for a crop.

/// Kept here, not in `DefaultsKey`, so the feature's files never edit a
/// shared registry.
enum RemoveBackgroundDefaults {
    static let enabled = "zenithRemoveBackgroundEnabled" // Bool, default false
    static let shortcut = "zenithRemoveBackgroundShortcut" // GlobalShortcut storage; absent = default, "" = none
    static let output = "zenithRemoveBackgroundOutput"   // RemoveBackgroundOutput.rawValue, default beside
    static let framing = "zenithRemoveBackgroundFraming" // RemoveBackgroundFraming.rawValue, default keep

    static let backupKeys: Set<String> = [enabled, shortcut, output, framing]
}

/// Where a result goes.
enum RemoveBackgroundOutput: String, CaseIterable, Identifiable {
    /// A PNG next to the original, `name (no background).png`.
    case besideOriginal = "beside"
    /// Back on the clipboard, as a PNG with its transparency.
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .besideOriginal: return "Beside the original"
        case .clipboard: return "Clipboard"
        }
    }
}

/// The result's canvas.
enum RemoveBackgroundFraming: String, CaseIterable, Identifiable {
    /// The picture's own size, the background made transparent.
    case keep
    /// Cropped to the subject.
    case crop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: return "Keep the canvas"
        case .crop: return "Crop to the subject"
        }
    }
}

struct RemoveBackgroundPreferences: Equatable {
    var enabled: Bool
    var output: RemoveBackgroundOutput
    var framing: RemoveBackgroundFraming

    init(defaults: UserDefaults = .standard) {
        enabled = defaults.object(forKey: RemoveBackgroundDefaults.enabled) as? Bool ?? false
        output = RemoveBackgroundOutput(rawValue: defaults.string(forKey: RemoveBackgroundDefaults.output) ?? "")
            ?? .besideOriginal
        framing = RemoveBackgroundFraming(rawValue: defaults.string(forKey: RemoveBackgroundDefaults.framing) ?? "")
            ?? .keep
    }
}

// MARK: - Inputs

/// What a press of the shortcut, the Command Bar or the Shelf hands over.
enum RemoveBackgroundSource: Equatable {
    /// Picture files: the Finder selection, a shelf item, files on the clipboard.
    case files([URL])
    /// A picture on the clipboard that is not a file (a copied screenshot).
    case clipboardImage
    /// Nothing to work on.
    case nothing
}

/// Where one result goes.
enum RemoveBackgroundDestination: Equatable {
    case file(URL)
    case clipboard
}

enum RemoveBackgroundSupport {
    /// At most this many pictures per press, so a large selection does not
    /// keep the Mac busy for minutes.
    static let maximumFiles = 20

    /// Whether a file is a picture Image I/O reads.
    static func isImage(_ url: URL) -> Bool {
        guard url.isFileURL, let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) && !type.conforms(to: .pdf)
    }

    /// The pictures among `urls`, in order, once each, up to the limit.
    static func images(in urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return Array(urls.filter { isImage($0) && seen.insert($0.standardizedFileURL.path).inserted }
            .prefix(maximumFiles))
    }

    /// The shortcut's source: the Finder selection while Finder is in front
    /// and has pictures selected, otherwise the clipboard's picture files,
    /// otherwise a picture on the clipboard.
    static func source(finderInFront: Bool, finderSelection: [URL], clipboardFiles: [URL],
                       clipboardHasImage: Bool) -> RemoveBackgroundSource {
        if finderInFront {
            let selected = images(in: finderSelection)
            if !selected.isEmpty { return .files(selected) }
        }
        return clipboardSource(files: clipboardFiles, hasImage: clipboardHasImage)
    }

    /// The Command Bar's source: the clipboard only.
    static func clipboardSource(files: [URL], hasImage: Bool) -> RemoveBackgroundSource {
        let pictures = images(in: files)
        if !pictures.isEmpty { return .files(pictures) }
        return hasImage ? .clipboardImage : .nothing
    }

    /// A file's result goes beside it, or to the clipboard when that is the
    /// setting or the folder cannot be written. A picture that was never a
    /// file can only go back to the clipboard.
    static func destination(for input: URL?, output: RemoveBackgroundOutput, folderWritable: Bool,
                            exists: (URL) -> Bool) -> RemoveBackgroundDestination {
        guard let input, output == .besideOriginal, folderWritable else { return .clipboard }
        return .file(outputURL(for: input, exists: exists))
    }

    // MARK: Naming

    static let nameSuffix = " (no background)"

    /// `photo.jpg` → `photo (no background).png`, then `… 2.png`, `… 3.png`
    /// while those exist. Never over an existing file.
    static func outputURL(for input: URL, exists: (URL) -> Bool) -> URL {
        let folder = input.deletingLastPathComponent()
        var base = input.deletingPathExtension().lastPathComponent
        if base.isEmpty { base = "Picture" }
        // Running it again on a result does not stack the suffix.
        if base.hasSuffix(nameSuffix) { base.removeLast(nameSuffix.count) }
        let stem = base + nameSuffix
        var candidate = folder.appendingPathComponent(stem).appendingPathExtension("png")
        var number = 2
        while exists(candidate), number < 10_000 {
            candidate = folder.appendingPathComponent("\(stem) \(number)").appendingPathExtension("png")
            number += 1
        }
        return candidate
    }

    // MARK: Cropping

    /// The smallest rectangle holding every pixel at least `threshold`
    /// opaque, in the image's own top-left pixel coordinates, or nil when
    /// nothing is. `rgba` is 8-bit, four bytes a pixel, alpha last, with
    /// `bytesPerRow` per row. A few faint pixels Vision leaves at the edge
    /// do not count: the default threshold is 8 of 255.
    static func subjectBounds(rgba: [UInt8], width: Int, height: Int, bytesPerRow: Int,
                              threshold: UInt8 = 8) -> CGRect? {
        guard width > 0, height > 0, bytesPerRow >= width * 4, rgba.count >= bytesPerRow * (height - 1) + width * 4
        else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * bytesPerRow
            for x in 0..<width where rgba[row + x * 4 + 3] >= threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    // MARK: Words

    /// The card's line for a finished run.
    static func summary(done: Int, failed: Int, toClipboard: Bool) -> String {
        if done == 0 { return failed == 1 ? "No subject found" : "No subjects found" }
        let what = done == 1 ? "Background removed" : "\(done) backgrounds removed"
        let where_ = toClipboard ? " · copied" : ""
        let missed = failed > 0 ? " · \(failed) without a subject" : ""
        return what + where_ + missed
    }
}
