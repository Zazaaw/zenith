// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Combine
import Foundation

/// Zenith fork: Zenith Pocket, the iPhone and Apple Watch companion, on the
/// Mac side. The contract between its two parts, built in parallel:
/// - the service (`PocketService`): keeps the link to the relay, publishes
///   this Mac's state, runs the phone's commands, and hands the phone's and
///   Watch's batteries to Batteries;
/// - Settings (the "iPhone & Watch" page): the relay, pairing by QR code,
///   the paired phone, and what is shared.
/// Each side depends only on what is declared here and on PocketKit
/// (`Pocket/PocketKit/Sources/PocketKit`, compiled into the app).

/// Pocket preferences. Kept here, not in `DefaultsKey`, so the parts never
/// edit the same file.
enum PocketDefaults {
    static let enabled = "zenithPocketEnabled"                 // Bool, default false
    static let shareWallpaper = "zenithPocketShareWallpaper"   // Bool, default true
    static let shareAgents = "zenithPocketShareAgents"         // Bool, default true
    static let shareNowPlaying = "zenithPocketShareNowPlaying" // Bool, default true
    /// Whether the phone may answer Claude Code's questions. Off by default:
    /// approving a command from another device is a decision to make on purpose.
    static let allowAnswers = "zenithPocketAllowAnswers"       // Bool, default false

    /// ZenithSecretStore names (owner-only files, never in preferences or backups).
    static let relaySecret = "pocket-relay"       // JSON PocketRelayConfig
    static let pairingSecret = "pocket-pairing"   // JSON PocketPairing (holds the key)
}

/// Where the paired phone stands, as the Mac sees it.
enum PocketPhase: Equatable {
    /// Pocket is off, or no relay is set.
    case off
    /// A relay is set but nothing is paired.
    case unpaired
    /// A QR code is on screen and the Mac waits for the phone's first message.
    case pairing(PocketPairing)
    /// Paired; `lastSeen` is the phone's last message, nil before the first.
    case paired(lastSeen: Date?)
}

/// The state Settings reads. The service writes it on the main thread.
final class PocketStore: ObservableObject {
    static let shared = PocketStore()

    @Published var phase: PocketPhase = .off
    /// The relay's live link (`PocketLink.Status`), shown beside the phase.
    @Published var link: PocketLink.Status = .offline
    /// The relay as saved; nil until the person enters one.
    @Published var relay: PocketRelayConfig?
    /// The phone's last battery report (iPhone, and its Watch when it has one).
    @Published var devices: [PocketDeviceReport.Device] = []
    /// A short line for the page when something failed (relay refused, …).
    @Published var problem: String?

    /// Installed by the service.
    var saveRelayHandler: ((PocketRelayConfig?) -> Void)?
    var startPairingHandler: (() -> Void)?
    var cancelPairingHandler: (() -> Void)?
    var unpairHandler: (() -> Void)?

    /// Saves (or with nil, forgets) the relay; a change of relay unpairs.
    func saveRelay(_ relay: PocketRelayConfig?) { saveRelayHandler?(relay) }
    /// Makes a fresh pairing and shows its QR code (`phase = .pairing`).
    func startPairing() { startPairingHandler?() }
    func cancelPairing() { cancelPairingHandler?() }
    /// Forgets the pairing and its key; the phone can no longer reach this Mac.
    func unpair() { unpairHandler?() }

    /// Sample data to design and test the page against.
    static let sampleDevices: [PocketDeviceReport.Device] = [
        .init(kind: .iphone, name: "iPhone 13 Pro", percent: 43, charging: false, readAt: Date(timeIntervalSinceNow: -60)),
        .init(kind: .watch, name: "Apple Watch", percent: 89, charging: false, readAt: Date(timeIntervalSinceNow: -120)),
    ]
}
