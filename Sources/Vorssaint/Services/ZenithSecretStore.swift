// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: small secrets (personal tokens) kept as owner-only files in
/// the app's container, `<container>/Secrets/<name>`, the folder 0700 and
/// each file 0600.
///
/// Not the Keychain: a self-signed build without a Team ID has its Keychain
/// access tied to the binary's hash, so every rebuild asked again to read the
/// item, even after "Always Allow". Not UserDefaults either, so a secret is
/// never part of preferences or settings backups; the folder is also excluded
/// from Time Machine.
enum ZenithSecretStore {
    private static let folderName = "Secrets"

    /// Letters, digits, `.`, `_` and `-` only, so a name can never leave the folder.
    static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 64 && !name.hasPrefix(".")
            && name.unicodeScalars.allSatisfy {
                $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0))
            }
    }

    static func read(_ name: String) -> String? {
        guard let url = fileURL(name),
              let data = FileManager.default.contents(atPath: url.path),
              let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    @discardableResult
    static func save(_ value: String, as name: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let folder = folderURL(), let url = fileURL(name) else { return false }
        guard PrivateFileStore.createDirectory(at: folder) else { return false }
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var marked = folder
        try? marked.setResourceValues(excluded)
        return PrivateFileStore.write(Data(trimmed.utf8), to: url)
    }

    static func delete(_ name: String) {
        guard let url = fileURL(name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func folderURL() -> URL? {
        PrivateFileStore.containerURL?.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func fileURL(_ name: String) -> URL? {
        guard isValidName(name) else { return nil }
        return folderURL()?.appendingPathComponent(name, isDirectory: false)
    }
}
