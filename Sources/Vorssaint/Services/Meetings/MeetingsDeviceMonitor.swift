// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreAudio
import CoreMediaIO
import Darwin
import Foundation

/// Zenith fork: whether another app holds the microphone, and whether a
/// camera is on, for Meetings. Listens only while watching, which
/// MeetingsService asks for while a meeting is near or a call is live:
/// CoreAudio's default input and whether it runs somewhere, and each
/// camera's CoreMediaIO "running somewhere". Reading these needs no
/// permission and opens no device. Callbacks arrive on the main queue.
final class MeetingsDeviceMonitor {
    /// The microphone in use by another process, and a camera in use.
    var onChange: ((_ micInUse: Bool, _ cameraInUse: Bool) -> Void)?

    private let queue = DispatchQueue(label: "id.satuvisual.zenith.meetings.devices", qos: .utility)
    /// Main-thread view of what was asked for, so repeated asks cost nothing.
    private var wanted = false

    // On `queue`.
    private var watching = false
    private var input = AudioObjectID(kAudioObjectUnknown)
    private var defaultInputBlock: AudioObjectPropertyListenerBlock?
    private var runningBlock: AudioObjectPropertyListenerBlock?
    private var cameras: [CMIOObjectID: CMIOObjectPropertyListenerBlock] = [:]
    private var cameraListBlock: CMIOObjectPropertyListenerBlock?
    private var lastReported: (mic: Bool, camera: Bool)?

    private static let defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private static let runningSomewhereAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private static let cameraListAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    private static let cameraRunningAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))

    /// Starts or stops listening. Called on the main thread.
    func setWatching(_ watch: Bool) {
        guard watch != wanted else { return }
        wanted = watch
        queue.async { [weak self] in
            guard let self else { return }
            watch ? self.start() : self.stop()
        }
    }

    // MARK: Lifecycle (on `queue`)

    private func start() {
        guard !watching else { return }
        watching = true
        lastReported = nil
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.inputChanged() }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), [Self.defaultInputAddress],
                                               queue, block) == noErr {
            defaultInputBlock = block
        }
        let listBlock: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in self?.camerasChanged() }
        if CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), [Self.cameraListAddress],
                                              queue, listBlock) == noErr {
            cameraListBlock = listBlock
        }
        attachInput()
        attachCameras()
        report()
    }

    private func stop() {
        guard watching else { return }
        watching = false
        Self.removeListeners(input: input, defaultInputBlock: defaultInputBlock, runningBlock: runningBlock,
                             cameras: cameras, cameraListBlock: cameraListBlock, queue: queue)
        input = AudioObjectID(kAudioObjectUnknown)
        defaultInputBlock = nil
        runningBlock = nil
        cameras = [:]
        cameraListBlock = nil
        lastReported = nil
    }

    private static func removeListeners(input: AudioObjectID, defaultInputBlock: AudioObjectPropertyListenerBlock?,
                                        runningBlock: AudioObjectPropertyListenerBlock?,
                                        cameras: [CMIOObjectID: CMIOObjectPropertyListenerBlock],
                                        cameraListBlock: CMIOObjectPropertyListenerBlock?, queue: DispatchQueue) {
        if let defaultInputBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), [Self.defaultInputAddress],
                                                   queue, defaultInputBlock)
        }
        if let runningBlock, input != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(input, [Self.runningSomewhereAddress], queue, runningBlock)
        }
        for (camera, block) in cameras {
            CMIOObjectRemovePropertyListenerBlock(camera, [Self.cameraRunningAddress], queue, block)
        }
        if let cameraListBlock {
            CMIOObjectRemovePropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), [Self.cameraListAddress],
                                                  queue, cameraListBlock)
        }
    }

    // MARK: The microphone

    private func inputChanged() {
        guard watching else { return }
        attachInput()
        report()
    }

    /// Follows the default input: AirPods connecting move it, and the
    /// listener moves with it.
    private func attachInput() {
        let device = Self.defaultInput()
        guard device != input else { return }
        if let runningBlock, input != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(input, [Self.runningSomewhereAddress], queue, runningBlock)
        }
        runningBlock = nil
        input = device
        guard device != kAudioObjectUnknown else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.report() }
        if AudioObjectAddPropertyListenerBlock(device, [Self.runningSomewhereAddress], queue, block) == noErr {
            runningBlock = block
        }
    }

    private static func defaultInput() -> AudioObjectID {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), [Self.defaultInputAddress],
                                                0, nil, &size, &device)
        return status == noErr ? device : AudioObjectID(kAudioObjectUnknown)
    }

    private static func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    /// Another process records: the default input runs somewhere, and the
    /// processes CoreAudio lists show one other than this app with input
    /// running. Where that list cannot be read, the device running in no
    /// IO of this process stands for it.
    private func micInUseElsewhere() -> Bool {
        guard input != kAudioObjectUnknown,
              Self.uint32(input, kAudioDevicePropertyDeviceIsRunningSomewhere) == 1 else { return false }
        if let others = Self.otherProcessRecords() { return others }
        return Self.uint32(input, kAudioDevicePropertyDeviceIsRunning) != 1
    }

    private static func otherProcessRecords() -> Bool? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return nil }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return nil }
        let own = getpid()
        var readAny = false
        for process in processes.prefix(Int(size) / MemoryLayout<AudioObjectID>.size) {
            guard let running = uint32(process, kAudioProcessPropertyIsRunningInput) else { continue }
            readAny = true
            guard running == 1 else { continue }
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID,
                                                        mScope: kAudioObjectPropertyScopeGlobal,
                                                        mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(process, &pidAddress, 0, nil, &pidSize, &pid) == noErr, pid == own { continue }
            return true
        }
        return readAny ? false : nil
    }

    // MARK: Cameras

    private func camerasChanged() {
        guard watching else { return }
        attachCameras()
        report()
    }

    private func attachCameras() {
        let devices = Set(Self.cameraDevices())
        for (camera, block) in cameras where !devices.contains(camera) {
            CMIOObjectRemovePropertyListenerBlock(camera, [Self.cameraRunningAddress], queue, block)
            cameras[camera] = nil
        }
        for camera in devices where cameras[camera] == nil {
            let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in self?.report() }
            if CMIOObjectAddPropertyListenerBlock(camera, [Self.cameraRunningAddress], queue, block) == noErr {
                cameras[camera] = block
            }
        }
    }

    private static func cameraDevices() -> [CMIOObjectID] {
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, [Self.cameraListAddress], 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, [Self.cameraListAddress], 0, nil, size, &used, &devices) == noErr else {
            return []
        }
        return Array(devices.prefix(Int(used) / MemoryLayout<CMIOObjectID>.size))
    }

    private func cameraInUse() -> Bool {
        cameras.keys.contains { camera in
            var running: UInt32 = 0
            var used: UInt32 = 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            return CMIOObjectGetPropertyData(camera, [Self.cameraRunningAddress], 0, nil, size, &used, &running) == noErr
                && running != 0
        }
    }

    // MARK: Reporting

    private func report() {
        guard watching else { return }
        let state = (mic: micInUseElsewhere(), camera: cameraInUse())
        if let lastReported, lastReported == state { return }
        lastReported = state
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wanted else { return }
            self.onChange?(state.mic, state.camera)
        }
    }
}
