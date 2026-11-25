// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AudioToolbox
import CoreAudio
import Foundation

/// Zenith fork: the Mac's sound on Zenith Pocket's Mac tab: the output's
/// volume and mute, the outputs it can switch to, and the microphone mute
/// Zenith keeps (`MicMuteService`). Read every three seconds while a phone
/// has Pocket open, nothing otherwise.
///
/// Volume goes through the mixer when it drives the output (so a monitor's
/// speakers and its own bookkeeping follow), otherwise straight to the
/// output as macOS's own slider would; outputs switch as a workspace does
/// (`WorkspaceAudio`).
final class PocketSoundPart: PocketPart {
    private var context: PocketPartContext?
    private var sampling = PocketSampling()
    private var timer: Timer?
    private var generation = 0
    private var reading = false
    private var sound: PocketSound?
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket.sound", qos: .utility)

    func start(_ context: PocketPartContext) {
        self.context = context
        apply(sampling.setLink(true))
    }

    func stop() {
        apply(sampling.setLink(false))
        context = nil
    }

    func setWatching(_ watching: Bool) {
        apply(sampling.setWatching(watching))
    }

    func fill(_ state: inout PocketMacState) {
        state.sound = sound
    }

    func handle(_ command: PocketCommand, id: UUID) -> Bool {
        switch command {
        case .setVolume, .setOutput, .muteMic: break
        default: return false
        }
        switch PocketMacCommands.plan(command) {
        case .volume(let value)?: setVolume(value, id: id)
        case .output(let uid)?: setOutput(uid, id: id)
        case .muteMic(let muted)?: muteMic(muted, id: id)
        case .refuse(let message)?: context?.reply(id, false, message)
        default: context?.reply(id, false, nil)
        }
        return true
    }

    // MARK: Sampling

    private func apply(_ change: PocketSampling.Change) {
        switch change {
        case .none:
            return
        case .start:
            let timer = Timer(timeInterval: PocketMacCadence.sound, repeats: true) { [weak self] _ in self?.read() }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            read()
        case .stop:
            timer?.invalidate(); timer = nil
            generation += 1
            reading = false
            if sound != nil {
                sound = nil
                context?.changed()
            }
        }
    }

    private func read() {
        guard sampling.running, !reading else { return }
        reading = true
        let generation = self.generation
        let micMuted: Bool? = AppFeature.micMute.isAvailable ? MicMuteService.shared.isMuted : nil
        queue.async { [weak self] in
            let output = PocketSoundReader.read()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else { return }
                self.reading = false
                let next = output.map { PocketSound(volume: $0.volume, muted: $0.muted, micMuted: micMuted, outputs: $0.outputs) }
                guard next != self.sound else { return }
                self.sound = next
                self.context?.changed()
            }
        }
    }

    // MARK: Commands

    private func setVolume(_ value: Double, id: UUID) {
        let percent = Int((value * 100).rounded())
        AppVolumeMixer.shared.requestOutputAdjustment(volume: value) { [weak self] handled in
            DispatchQueue.main.async {
                guard let self else { return }
                if handled {
                    self.done(id, "Volume \(percent)%.")
                    return
                }
                self.queue.async {
                    let ok = PocketSoundReader.setVolume(Float(value))
                    DispatchQueue.main.async {
                        if ok { self.done(id, "Volume \(percent)%.") } else {
                            self.context?.reply(id, false, "This output's volume can't be set from the phone.")
                        }
                    }
                }
            }
        }
    }

    private func setOutput(_ uid: String, id: UUID) {
        queue.async { [weak self] in
            let outputs = PocketSoundReader.read()?.outputs ?? []
            guard let output = outputs.first(where: { $0.id == uid }) else {
                DispatchQueue.main.async { [weak self] in self?.context?.reply(id, false, PocketMacCommands.badOutput) }
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if WorkspaceAudio.setDefaultOutput(uid: uid) {
                    self.done(id, "Sound plays on \(output.name).")
                } else {
                    self.context?.reply(id, false, "Your Mac couldn't switch to \(output.name).")
                }
            }
        }
    }

    private func muteMic(_ muted: Bool, id: UUID) {
        guard AppFeature.micMute.isAvailable else {
            context?.reply(id, false, "Mic mute is turned off in Zenith.")
            return
        }
        MicMuteService.shared.setMuted(muted)
        done(id, muted ? "Your Mac's mic is muted." : "Your Mac's mic is on.")
    }

    /// Answers, then reads again so the phone sees the change at once.
    private func done(_ id: UUID, _ message: String) {
        context?.reply(id, true, message)
        read()
    }
}

/// The default output and the outputs it can switch to, read from Core Audio.
enum PocketSoundReader {
    struct Output {
        var volume: Int
        var muted: Bool
        var outputs: [PocketSound.Output]
    }

    static func read() -> Output? {
        guard let current = defaultOutput() else { return nil }
        let volume = volumeScalar(current).map(PocketSoundRules.percent) ?? 100
        let muted = uint32(current, kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput) == 1
        let outputs = deviceIDs().compactMap { id -> PocketSound.Output? in
            guard hasOutput(id), uint32(id, kAudioDevicePropertyDeviceCanBeDefaultDevice,
                                        scope: kAudioDevicePropertyScopeOutput) == 1,
                  let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
            let name = string(id, kAudioObjectPropertyName) ?? uid
            let transport = Self.transport(uint32(id, kAudioDevicePropertyTransportType) ?? 0)
            return PocketSound.Output(id: uid, name: String(name.prefix(60)),
                                      kind: PocketSoundRules.kind(transport, name: name), current: id == current)
        }
        return Output(volume: volume, muted: muted, outputs: Array(outputs.prefix(12)))
    }

    /// Straight to the default output, unmuting it above zero as macOS does.
    static func setVolume(_ value: Float) -> Bool {
        guard let device = defaultOutput() else { return false }
        var level = min(1, max(0, value))
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address),
              AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &level) == noErr
        else { return false }
        var mute: UInt32 = level <= 0.001 ? 1 : 0
        var muteAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                                     mScope: kAudioDevicePropertyScopeOutput,
                                                     mElement: kAudioObjectPropertyElementMain)
        if AudioObjectHasProperty(device, &muteAddress) {
            _ = AudioObjectSetPropertyData(device, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &mute)
        }
        return true
    }

    private static func transport(_ value: UInt32) -> PocketSoundRules.Transport {
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return .bluetooth
        case kAudioDeviceTransportTypeUSB: return .usb
        case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI: return .display
        case kAudioDeviceTransportTypeAirPlay: return .airPlay
        default: return .other
        }
    }

    private static func defaultOutput() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var id = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return id
    }

    private static func volumeScalar(_ device: AudioObjectID) -> Float? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
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
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                               scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
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
