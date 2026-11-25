// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: what the island knows about the song beyond the first round:
/// its album, the app playing it and its cover, and seeking. The cover the
/// island already decoded (`NotchMusicService.artwork`) is shrunk to a small
/// JPEG and put in its own box (`artworkBoxID`, as a `PocketWallpaper`) only
/// when it is a different picture; the state carries its hash. All of it
/// follows the "Now playing" switch.
final class PocketMediaPart: PocketPart {
    static let artworkPixels = 300
    static let artworkQuality = 0.75

    private var context: PocketPartContext?
    private var sinks: Set<AnyCancellable> = []
    private var generation = 0
    /// The cover now, and the one in the box.
    private var artworkHash: String?
    private var uploadedHash: String?
    private var shared = true
    private var appNames: [String: String] = [:]
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket.artwork", qos: .utility)

    func start(_ context: PocketPartContext) {
        self.context = context
        shared = PocketSharing.current().nowPlaying
        NotchMusicService.shared.$artwork
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in self?.artworkChanged(image) }
            .store(in: &sinks)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.preferencesChanged() }
            .store(in: &sinks)
    }

    func stop() {
        sinks.removeAll()
        generation += 1
        artworkHash = nil
        uploadedHash = nil
        context = nil
    }

    func fill(_ state: inout PocketMacState) {
        guard var song = state.nowPlaying, let playback = NotchMusicService.shared.playback else { return }
        let album = playback.track.album?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        song.album = album.isEmpty ? nil : String(album.prefix(120))
        song.app = playback.track.appBundleIdentifier.flatMap(appName)
        song.artworkHash = artworkHash != nil && artworkHash == uploadedHash ? artworkHash : nil
        state.nowPlaying = song
    }

    func handle(_ command: PocketCommand, id: UUID) -> Bool {
        guard case .seek = command, let plan = PocketMacCommands.plan(command) else { return false }
        guard case .seek(let seconds) = plan else {
            if case .refuse(let message) = plan { context?.reply(id, false, message) }
            return true
        }
        let music = NotchMusicService.shared
        guard shared, let playback = music.playback, let position = playback.seekPosition(seconds, allowed: music.canSeek),
              music.canPerform(.seek(position)), music.send(.seek(position)) else {
            context?.reply(id, false, "This player can't jump to a position.")
            return true
        }
        context?.reply(id, true, nil)
        return true
    }

    // MARK: Artwork

    private func preferencesChanged() {
        let next = PocketSharing.current().nowPlaying
        guard next != shared else { return }
        shared = next
        if next {
            artworkChanged(NotchMusicService.shared.artwork)
        } else {
            // Turned off: the cover leaves the relay too, as an empty box.
            generation += 1
            artworkHash = nil
            if uploadedHash != nil, let context {
                uploadedHash = nil
                let box = context.pairing.artworkBoxID
                Task { try? await context.link.putBox(box, PocketWallpaper(jpeg: Data())) }
            }
        }
    }

    private func artworkChanged(_ image: NSImage?) {
        generation += 1
        guard shared, let image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            if artworkHash != nil {
                artworkHash = nil
                context?.changed()
            }
            return
        }
        let generation = self.generation
        queue.async { [weak self] in
            guard let jpeg = Self.jpeg(cgImage) else { return }
            let hash = PocketWallpaperSupport.hash(jpeg)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else { return }
                self.artworkHash = hash
                guard hash != self.uploadedHash else {
                    self.context?.changed()
                    return
                }
                self.upload(jpeg, hash: hash, generation: generation)
            }
        }
    }

    private func upload(_ jpeg: Data, hash: String, generation: Int) {
        guard let context else { return }
        let box = context.pairing.artworkBoxID
        let link = context.link
        let part = PocketWeak(self)
        Task {
            let ok = (try? await link.putBox(box, PocketWallpaper(jpeg: jpeg))) != nil
            DispatchQueue.main.async {
                guard let self = part.value, ok, self.generation == generation else { return }
                self.uploadedHash = hash
                self.context?.changed()
            }
        }
    }

    private static func jpeg(_ image: CGImage) -> Data? {
        let longest = max(image.width, image.height)
        guard longest > 0 else { return nil }
        let scale = min(1, Double(artworkPixels) / Double(longest))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        bitmap.interpolationQuality = .high
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = bitmap.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, scaled,
                                   [kCGImageDestinationLossyCompressionQuality: artworkQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: The player's name

    private func appName(_ bundleID: String) -> String? {
        if let known = appNames[bundleID] { return known.isEmpty ? nil : known }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { FileManager.default.displayName(atPath: $0.path) }
            .map { $0.hasSuffix(".app") ? String($0.dropLast(4)) : $0 } ?? ""
        appNames[bundleID] = name
        return name.isEmpty ? nil : name
    }
}
