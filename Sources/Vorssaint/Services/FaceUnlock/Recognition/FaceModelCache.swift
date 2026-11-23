// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance.

import CryptoKit
import Foundation

/// Zenith fork: where the compiled ArcFace model is kept. Glance ships a
/// `.mlmodelc` Xcode compiled; Zenith builds without Xcode, so it bundles the
/// `.mlpackage` and compiles it on the Mac at first use. The compiled copy is
/// cached under a name derived from the package's content, so an updated model
/// compiles once and an unchanged one never again.
enum FaceModelCache {
    static let modelName = "ArcFace"

    /// SHA-256 over every file in the package, path and content, in a stable
    /// order. Any change to the weights or the spec gives a new hash.
    static func contentHash(ofPackageAt packageURL: URL) throws -> String {
        let manager = FileManager.default
        let root = packageURL.standardizedFileURL.resolvingSymlinksInPath()
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: packageURL.path])
        }
        var files: [(path: String, url: URL)] = []
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            files.append((String(path.dropFirst(rootPath.count)), url))
        }
        guard !files.isEmpty else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: packageURL.path])
        }
        var hasher = SHA256()
        for file in files.sorted(by: { $0.path < $1.path }) {
            hasher.update(data: Data(file.path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: try Data(contentsOf: file.url, options: .mappedIfSafe))
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// `<directory>/ArcFace-<first 16 hex>.mlmodelc`.
    static func compiledModelURL(in directory: URL, hash: String) -> URL {
        directory.appendingPathComponent("\(modelName)-\(hash.prefix(16)).mlmodelc", isDirectory: true)
    }

    /// Older compiled copies to remove once `current` is in place.
    static func staleModels(in directory: URL, keeping current: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.filter {
            $0.lastPathComponent.hasPrefix("\(modelName)-")
                && $0.pathExtension == "mlmodelc"
                && $0.lastPathComponent != current.lastPathComponent
        }
    }
}
