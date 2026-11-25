// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Security

/// Zenith fork: Send to Mac, from Zenith Pocket. Text goes on the clipboard,
/// an http(s) link opens in the default browser, and a photo or small file
/// the phone left in a drop slot is saved to ~/Downloads/Pocket, under a
/// plain name that never replaces a file. The slot is then overwritten with
/// noise, so the relay keeps nothing of it. Nothing else happens: no Finder
/// window, no app opened for the file.
final class PocketDropPart: PocketPart {
    private var context: PocketPartContext?
    private var collecting: Set<Int> = []
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket.drops", qos: .userInitiated)

    func start(_ context: PocketPartContext) { self.context = context }

    func stop() {
        context = nil
        collecting = []
    }

    func fill(_ state: inout PocketMacState) {}

    func handle(_ command: PocketCommand, id: UUID) -> Bool {
        switch command {
        case .sendText, .openURL, .collectDrop: break
        default: return false
        }
        switch PocketMacCommands.plan(command) {
        case .clipboard(let text)?: copy(text, id: id)
        case .open(let url)?: open(url, id: id)
        case .collect(let slot)?: collect(slot, id: id)
        case .refuse(let message)?: context?.reply(id, false, message)
        default: context?.reply(id, false, nil)
        }
        return true
    }

    // MARK: Text and links

    private func copy(_ text: String, id: UUID) {
        GeneralPasteboardAccess.shared.async({
            let board = NSPasteboard.general
            board.clearContents()
            board.declareVorssaintSource()
            return board.setString(text, forType: .string)
        }, then: { [weak self] copied in
            self?.context?.reply(id, copied, copied ? "On your Mac's clipboard." : "Your Mac's clipboard is busy. Try again.")
        })
    }

    private func open(_ url: URL, id: UUID) {
        let opened = NSWorkspace.shared.open(url)
        context?.reply(id, opened, opened ? "Opened on your Mac." : "Your Mac couldn't open that link.")
    }

    // MARK: Drops

    private func collect(_ slot: Int, id: UUID) {
        guard let context, collecting.insert(slot).inserted else {
            self.context?.reply(id, false, "That file is already on its way.")
            return
        }
        let box = context.pairing.dropBoxID(slot)
        let link = context.link
        let relay = context.pairing.relay
        let part = PocketWeak(self)
        Task {
            let envelope = try? await link.getBox(box, as: PocketDrop.self)
            DispatchQueue.main.async {
                guard let self = part.value else { return }
                guard let envelope, envelope.from == .phone else {
                    self.finish(slot, id: id, ok: false, PocketDropRules.missing)
                    return
                }
                if let refusal = PocketDropRules.refusal(envelope.body, sentAt: envelope.sentAt, now: Date()) {
                    self.finish(slot, id: id, ok: false, refusal)
                    Self.scrub(box, relay: relay)
                    return
                }
                self.save(envelope.body, slot: slot, box: box, relay: relay, id: id)
            }
        }
    }

    private func save(_ drop: PocketDrop, slot: Int, box: String, relay: PocketRelayConfig, id: UUID) {
        let name = PocketDropRules.sanitizedName(drop.name, kind: drop.kind, now: Date())
        queue.async { [weak self] in
            let saved = Self.write(drop.data, named: name)
            DispatchQueue.main.async { [weak self] in
                // Saved or not, the relay keeps nothing of it.
                Self.scrub(box, relay: relay)
                if let saved {
                    self?.finish(slot, id: id, ok: true, PocketDropRules.saved(saved))
                } else {
                    self?.finish(slot, id: id, ok: false, PocketDropRules.couldNotSave)
                }
            }
        }
    }

    private func finish(_ slot: Int, id: UUID, ok: Bool, _ message: String) {
        collecting.remove(slot)
        context?.reply(id, ok, message)
    }

    /// Writes into ~/Downloads/Pocket without ever replacing a file
    /// (`withoutOverwriting` holds even against a file appearing meanwhile).
    /// Returns the name it got.
    private static func write(_ data: Data, named name: String) -> String? {
        let manager = FileManager.default
        guard let downloads = manager.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return nil }
        let folder = downloads.appendingPathComponent(PocketDropRules.folderName, isDirectory: true)
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        for _ in 0..<3 {
            guard let free = PocketDropRules.available(name, exists: {
                manager.fileExists(atPath: folder.appendingPathComponent($0).path)
            }) else { return nil }
            do {
                try data.write(to: folder.appendingPathComponent(free), options: [.withoutOverwriting])
                return free
            } catch CocoaError.fileWriteFileExists {
                continue
            } catch {
                return nil
            }
        }
        return nil
    }

    /// Random bytes over the slot, as unpairing does for the other boxes.
    private static func scrub(_ box: String, relay: PocketRelayConfig) {
        var noise = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, noise.count, &noise)
        let sealed = Data(noise).base64EncodedString()
        let boxes = PocketBoxClient(relay: relay)
        Task { try? await boxes.put(id: box, sealed: sealed) }
    }
}
