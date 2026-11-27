// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: whether `~/.wakatime.cfg` is there, without asking the disk
/// on every island update. The island lists its sections and works out its
/// compact activities many times a second while it changes, and each of those
/// asked whether WakaTime is set up: a copy of the whole environment and a
/// file check every time.
///
/// The file's place is worked out once, since the app's environment does not
/// change while it runs. Its presence is remembered until a file is added,
/// removed or renamed in its folder (a watcher on the folder says so), the app
/// becomes active, or `lifetime` passes, whichever comes first; the lifetime
/// covers a folder that cannot be watched, such as a WAKATIME_HOME not made yet.
final class WakaTimeConfigPresence: @unchecked Sendable {
    static let shared = WakaTimeConfigPresence(url: WakaTimeSupport.configURL())
    static let defaultLifetime: TimeInterval = 30

    let url: URL
    let lifetime: TimeInterval
    private let check: (String) -> Bool
    private let lock = NSLock()
    private var cached: (present: Bool, at: Date)?
    private var watcher: DispatchSourceFileSystemObject?
    private var activationObserver: NSObjectProtocol?

    init(url: URL, lifetime: TimeInterval = WakaTimeConfigPresence.defaultLifetime, watchesFolder: Bool = true,
         check: @escaping (String) -> Bool = { FileManager.default.isReadableFile(atPath: $0) }) {
        self.url = url
        self.lifetime = lifetime
        self.check = check
        if watchesFolder { watchFolder() }
        // NSApplication.didBecomeActiveNotification, named here so this file needs only Foundation.
        activationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSApplicationDidBecomeActiveNotification"), object: nil, queue: nil
        ) { [weak self] _ in self?.invalidate() }
    }

    deinit {
        watcher?.cancel()
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }

    /// Whether the file is there and readable, as of at most `lifetime` ago.
    func isPresent(now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let cached, now >= cached.at, now.timeIntervalSince(cached.at) < lifetime { return cached.present }
        let present = check(url.path)
        cached = (present, now)
        return present
    }

    /// The next question asks the disk again.
    func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    var isWatchingFolder: Bool { watcher != nil }

    /// A folder's own entries changing (a file added, removed or renamed) is
    /// a write to the folder. Edits inside the file are not, and need no
    /// answer here: they leave it where it is.
    private func watchFolder() {
        let folder = url.deletingLastPathComponent().path
        let descriptor = open(folder, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .rename, .delete],
                                                               queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in self?.invalidate() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }
}
