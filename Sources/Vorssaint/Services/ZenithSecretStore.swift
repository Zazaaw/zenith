// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: personal tokens (WakaTime, Vercel) kept as owner-only files in
/// the app's container, `<Application Support>/<bundle id>/Secrets/<name>`
/// (folder 0700, file 0600), never in preferences or settings backups.
///
/// Why not the Keychain: a self-signed build has no Team ID, so macOS ties a
/// keychain item to the binary's code hash and asks again after every rebuild,
/// "Always Allow" included. A 0600 file matches how WakaTime itself keeps its
/// key (`~/.wakatime.cfg`). Revisit once Zenith is signed with a Developer ID.
enum ZenithSecretStore {
    static func url(for name: String, container: URL? = PrivateFileStore.containerURL) -> URL? {
        guard isValidName(name) else { return nil }
        return container?.appendingPathComponent("Secrets", isDirectory: true).appendingPathComponent(name)
    }

    static func read(_ name: String, container: URL? = PrivateFileStore.containerURL) -> String? {
        guard let url = url(for: name, container: container),
              let value = try? String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    @discardableResult
    static func save(_ value: String, as name: String, container: URL? = PrivateFileStore.containerURL) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = url(for: name, container: container),
              PrivateFileStore.createDirectory(at: url.deletingLastPathComponent(), container: container)
        else { return false }
        return PrivateFileStore.write(Data(trimmed.utf8), to: url)
    }

    static func delete(_ name: String, container: URL? = PrivateFileStore.containerURL) {
        guard let url = url(for: name, container: container) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Plain file names only, so a name can never climb out of the folder.
    static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
