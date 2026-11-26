// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppIntents
import PocketKit
import SwiftUI
import WidgetKit

/// Control Center (and the Lock Screen's and Action button's controls):
/// lock the Mac, keep it awake for an hour, and its microphone. The toggles
/// read the Mac's state from the widgets' file (or its box when that is old).

struct LockControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "id.satuvisual.zenith.pocket.lock") {
            ControlWidgetButton(action: LockMacIntent()) {
                Label("Lock Mac", systemImage: "lock.laptopcomputer")
            }
        }
        .displayName("Lock Mac")
        .description("Locks your Mac through Zenith.")
    }
}

struct AwakeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "id.satuvisual.zenith.pocket.awake", provider: MacValue(read: AwakeRead())) { isOn in
            ControlWidgetToggle("Keep Mac Awake", isOn: isOn, action: KeepAwakeIntent()) { on in
                Label(on ? "On" : "Off", systemImage: on ? "cup.and.saucer.fill" : "cup.and.saucer")
            }
        }
        .displayName("Keep Mac Awake")
        .description("Keeps your Mac awake for an hour, or lets it sleep.")
    }
}

struct MicControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "id.satuvisual.zenith.pocket.mic", provider: MacValue(read: MicRead())) { isOn in
            ControlWidgetToggle("Mac Mic", isOn: isOn, action: MacMicIntent()) { on in
                Label(on ? "On" : "Muted", systemImage: on ? "mic.fill" : "mic.slash.fill")
            }
        }
        .displayName("Mac Mic")
        .description("Mutes or unmutes your Mac's microphone.")
    }
}

// MARK: Values

/// One reading of the Mac's state for a toggle.
protocol MacRead: Sendable {
    var preview: Bool { get }
    func value(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Bool
}

struct AwakeRead: MacRead {
    var preview: Bool { false }
    func value(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Bool { PocketWidgetPresentation.awakeIsOn(snapshot, now: now) }
}

struct MicRead: MacRead {
    var preview: Bool { true }
    func value(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Bool { PocketWidgetPresentation.micIsOn(snapshot) }
}

struct MacValue<Read: MacRead>: ControlValueProvider {
    let read: Read

    var previewValue: Bool { read.preview }

    func currentValue() async throws -> Bool {
        guard let pairing = PairingStore.load() else { return read.preview }
        let now = Date()
        return read.value(await WidgetVault.current(pairing, now: now), now: now)
    }
}
