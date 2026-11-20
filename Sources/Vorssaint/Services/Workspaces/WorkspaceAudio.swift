// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreAudio
import Foundation

// Zenith fork: the sound output a workspace switches to. The mixer
// (AppVolumeMixer) already knows the devices and switches them, keeping its
// per-app routes in step, but it lists them only while one of the sound
// features listens. So a workspace asks the mixer first and falls back to
// reading and setting the default output here, with the same HAL calls.

enum WorkspaceAudio {
    struct Device: Identifiable, Equatable {
        let uid: String
        let name: String
        var id: String { uid }
    }

    /// Output devices that can be the default one, the mixer's list when it has one.
    static func outputDevices() -> [Device] {
        let mixer = AppVolumeMixer.shared.outputDevices.filter(\.canBeDefaultOutput)
        if !mixer.isEmpty { return mixer.map { Device(uid: $0.uid, name: $0.name) } }
        return deviceIDs().compactMap { id in
            guard hasOutput(id), let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
            return Device(uid: uid, name: string(id, kAudioObjectPropertyName) ?? uid)
        }
    }

    /// Makes the device with this UID the default output. Through the mixer
    /// when it lists the device, so its routes follow; otherwise directly.
    static func setDefaultOutput(uid: String) -> Bool {
        let mixer = AppVolumeMixer.shared
        if mixer.outputDevices.contains(where: { $0.uid == uid && $0.canBeDefaultOutput }) {
            return mixer.setUniversalOutputDeviceUID(uid)
        }
        guard var id = deviceIDs().first(where: { hasOutput($0) && string($0, kAudioDevicePropertyDeviceUID) == uid })
        else { return false }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                          UInt32(MemoryLayout<AudioObjectID>.size), &id) == noErr
    }

    private static func deviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func hasOutput(_ id: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                 mScope: kAudioObjectPropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
              let text = value?.takeRetainedValue() else { return nil }
        return text as String
    }
}
