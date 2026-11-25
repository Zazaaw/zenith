// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: one part of what Zenith Pocket shares beyond its first round
/// (Claude Code in detail, the Mac's health and sound, Zenith's tools, the
/// watched sites, the safety of the person's work). Each part is its own
/// object in its own file, registered in `PocketParts.make()`, so the parts
/// can grow without editing `PocketService`.
///
/// Everything is called on the main thread. A part keeps what it shares
/// cached and cheap to copy: `fill` runs on every state the Mac sends.
protocol PocketPart: AnyObject {
    /// The link is up. Begin observing; call `context.changed()` whenever what
    /// `fill` writes may differ.
    func start(_ context: PocketPartContext)
    /// The link went down (Pocket off, unpaired, asleep). Stop everything.
    func stop()
    /// Whether a phone has Pocket open. Parts that sample (health, sound)
    /// sample only while it is true; parts that observe can ignore it.
    func setWatching(_ watching: Bool)
    /// Writes this part's field of the state.
    func fill(_ state: inout PocketMacState)
    /// Handles a command that belongs to this part and answers it through
    /// `context.reply`; returns false for commands that aren't its own.
    func handle(_ command: PocketCommand, id: UUID) -> Bool
}

extension PocketPart {
    func setWatching(_ watching: Bool) {}
    func handle(_ command: PocketCommand, id: UUID) -> Bool { false }
}

/// What a part may use while the link is up.
struct PocketPartContext {
    let pairing: PocketPairing
    let link: PocketLink
    /// Something this part shares may have changed: send soon (debounced).
    let changed: () -> Void
    /// Answers a command: ok, and an English line the phone shows.
    let reply: (UUID, Bool, String?) -> Void
}
