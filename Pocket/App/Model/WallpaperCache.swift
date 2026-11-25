// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation

/// The Mac's wallpaper thumbnail on disk, so Home shows it at once and it is
/// downloaded again only when the Mac's hash says it changed.
enum WallpaperCache {
    private static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("mac-wallpaper.jpg")
    }

    /// The same hash the Mac sends (`PocketMacState.wallpaperHash`).
    static func hash(_ jpeg: Data) -> String {
        SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
    }

    static func load() -> (hash: String, jpeg: Data)? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return (hash(data), data)
    }

    static func save(_ jpeg: Data) {
        try? jpeg.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
