// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation
import Observation
import PocketKit
import UIKit

/// The Mac tab's own state beside the model: the now-playing cover, and what
/// Send to Mac sent lately. Kept apart so the model stays the link's.
@MainActor
@Observable
final class MacStore {
    static let shared = MacStore()

    struct Sent: Identifiable, Equatable {
        enum Kind { case text, link, photo, file }
        let id = UUID()
        let kind: Kind
        let title: String
        let detail: String
        let at: Date
    }

    private(set) var artwork: UIImage?
    private(set) var artworkHash: String?
    private(set) var recent: [Sent] = []
    /// A drop is being sealed and uploaded.
    private(set) var dropping = false
    private var fetchingArtwork: String?

    private static let lastSlotKey = "pocketLastDropSlot"

    // MARK: Artwork

    /// The cover in the Mac's box, fetched only when the state's hash moved.
    func showArtwork(_ hash: String?, model: PocketModel) {
        guard let hash else {
            if artwork != nil { artwork = nil; artworkHash = nil }
            return
        }
        guard hash != artworkHash, hash != fetchingArtwork, let pairing = model.pairing else { return }
        fetchingArtwork = hash
        Task {
            let envelope = try? await PocketLink(pairing: pairing, me: .phone).getBox(pairing.artworkBoxID, as: PocketWallpaper.self)
            fetchingArtwork = nil
            guard let jpeg = envelope?.body.jpeg, !jpeg.isEmpty,
                  SHA256.hash(data: jpeg).map({ String(format: "%02x", $0) }).joined() == hash,
                  let image = UIImage(data: jpeg) else { return }
            artwork = image
            artworkHash = hash
        }
    }

    // MARK: Send to Mac

    func remember(_ kind: Sent.Kind, _ title: String, _ detail: String) {
        recent.insert(Sent(kind: kind, title: title, detail: detail, at: Date()), at: 0)
        if recent.count > 6 { recent.removeLast(recent.count - 6) }
    }

    /// Slots go round in turn, across launches, so a drop the Mac hasn't
    /// collected yet is the last to be written over.
    func takeSlot() -> Int {
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: Self.lastSlotKey) as? Int
        let next = PocketMacPresentation.nextSlot(after: last)
        defaults.set(next, forKey: Self.lastSlotKey)
        return next
    }

    func setDropping(_ value: Bool) { dropping = value }

    // MARK: Health history

    /// One health reading as it arrived, for the tiles' sparklines.
    struct HealthSample: Equatable {
        let at: Date
        let cpu: Double
        let temperature: Double?
        let memory: Double?
    }

    /// The last ten minutes of readings, oldest first, kept in memory only.
    private(set) var history: [HealthSample] = []

    static let historySpan: TimeInterval = 10 * 60

    /// Notes the health in a state the phone just took in. The same state
    /// read twice (box and channel) counts once.
    func record(_ health: PocketHealth?, at time: Date) {
        guard let health else { return }
        if let last = history.last, time.timeIntervalSince(last.at) < 1 { return }
        history.append(HealthSample(at: time, cpu: Double(health.cpuPercent), temperature: health.temperature,
                                    memory: health.memoryPercent.map(Double.init)))
        let cutoff = time.addingTimeInterval(-Self.historySpan)
        if let first = history.firstIndex(where: { $0.at >= cutoff }), first > 0 { history.removeFirst(first) }
    }

    func clearHistory() { if !history.isEmpty { history = [] } }
}

extension PocketModel {
    var mac: MacStore { MacStore.shared }

    /// Sent without a toast or a wait for the result: presence, the volume
    /// slider and seeking say so through the next state instead.
    func sendQuietly(_ command: PocketCommand) {
        guard canControl(), let pocketLink else { return }
        Task { _ = try? await pocketLink.send(.command(command)) }
    }

    /// The Mac samples its health and sound only while this is true.
    func watchMac(_ open: Bool) { sendQuietly(.presence(watching: open)) }

    func setVolume(_ percent: Int) { sendQuietly(.setVolume(min(100, max(0, percent)))) }
    func seek(to seconds: TimeInterval) { sendQuietly(.seek(seconds: max(0, seconds))) }
    func setOutput(_ id: String) { send(.setOutput(id: id)) }
    func muteMic(_ muted: Bool) { send(.muteMic(muted)) }
    func openWorkspace(_ id: String) { send(.openWorkspace(id: id)) }
    func startTimer(minutes: Int) { send(.timer(minutes: minutes, label: nil)) }
    func stopTimer() { send(.timer(minutes: nil, label: nil)) }
    func pauseTimer(_ paused: Bool) { send(.pauseTimer(paused)) }
    func stopDevServer(port: Int) { send(.stopDevServer(port: port)) }
    func quitApp(pid: Int32) { send(.quitProcess(pid: pid)) }

    // MARK: Send to Mac

    func sendText(_ text: String) {
        guard send(.sendText(String(text.prefix(20_000)))) else { return }
        mac.remember(.text, PocketMacSend.title(text), "on the Mac's clipboard")
    }

    func openOnMac(_ url: URL) {
        guard send(.openURL(url.absoluteString)) else { return }
        mac.remember(.link, url.host() ?? url.absoluteString, "opened on the Mac")
    }

    /// Seals the file into the next drop slot, then asks the Mac to collect it.
    func drop(_ data: Data, name: String, kind: PocketDrop.Kind) {
        guard data.count <= PocketDrop.fitBytes else {
            show(PocketMacSend.tooBig, ok: false)
            return
        }
        guard canControl(), let pairing else {
            show(controlProblem() ?? PocketPresentation.unreachable, ok: false)
            return
        }
        let slot = mac.takeSlot()
        mac.setDropping(true)
        Task {
            defer { mac.setDropping(false) }
            do {
                try await PocketLink(pairing: pairing, me: .phone)
                    .putBox(pairing.dropBoxID(slot), PocketDrop(name: name, kind: kind, data: data))
            } catch {
                show("Pocket couldn't upload that. Try again.", ok: false)
                return
            }
            guard send(.collectDrop(slot: slot)) else { return }
            mac.remember(kind == .photo ? .photo : .file, name, "→ ~/Downloads/Pocket")
        }
    }
}

/// Getting things ready to send: photos shrunk to fit a drop.
enum PocketMacSend {
    static let tooBig = "That file is too big for Pocket. Files up to 180 KB fit."

    static func title(_ text: String) -> String {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").first.map(String.init) ?? ""
        return line.count > 40 ? String(line.prefix(39)) + "…" : line
    }

    /// A JPEG under `PocketDrop.fitBytes`: smaller and softer until it fits.
    nonisolated static func jpeg(_ image: UIImage) -> Data? {
        var side: CGFloat = 2048
        while side >= 320 {
            let resized = resize(image, longest: side)
            for quality in [0.8, 0.65, 0.5, 0.38] {
                if let data = resized.jpegData(compressionQuality: quality), data.count <= PocketDrop.fitBytes { return data }
            }
            side *= 0.75
        }
        return nil
    }

    nonisolated private static func resize(_ image: UIImage, longest: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, longest / max(size.width, size.height, 1))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func photoName(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Photo " + formatter.string(from: date) + ".jpg"
    }
}
