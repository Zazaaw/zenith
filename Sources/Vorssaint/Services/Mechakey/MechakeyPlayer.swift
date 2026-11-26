// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Mechakey plays the keyboard sound packs of Mechvibes by Hải Nguyễn (MIT),
// https://github.com/hainguyents13/mechvibes — see the notice in About.

import AudioToolbox
import AVFoundation
import CoreGraphics
import Foundation

// Zenith fork: Mechakey's sound. One thread of its own runs a listen-only
// key tap and an AVAudioEngine with a few player nodes, so a key's sound
// never waits for the main thread. A key event reads two lookup tables and
// schedules a buffer decoded when the pack loaded: no file, no allocation of
// ours on that path. With Mechakey off and no preview playing, the tap and
// the engines are gone; the thread, made the first time it is needed, sleeps
// on its run loop without a timer or a wakeup.
//
// Not a keylogger: the tap sees key codes only to pick a sound, keeps
// nothing, and cannot change or hold back an event (`.listenOnly`).

/// A pack decoded for playback: one buffer per slice, a short fade at each
/// cut so no slice ends on a click.
final class MechakeyLoadedPack {
    let id: String
    let table: MechakeySoundTable
    let buffers: [AVAudioPCMBuffer]
    let format: AVAudioFormat
    let gain: Float

    init?(pack: MechakeyPack, bundle: Bundle = .main) {
        guard let folder = bundle.resourceURL?
                .appendingPathComponent(MechakeyPack.resourceFolder, isDirectory: true)
                .appendingPathComponent(pack.id, isDirectory: true),
              let data = try? Data(contentsOf: folder.appendingPathComponent("config.json")),
              let config = try? MechakeyPackConfig(data: data),
              let file = try? AVAudioFile(forReading: folder.appendingPathComponent(config.audioFile)),
              file.length > 0,
              let whole = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                           frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: whole)) != nil,
              let source = whole.floatChannelData else { return nil }
        let format = file.processingFormat
        let table = MechakeySoundTable(config: config, sampleRate: format.sampleRate, totalFrames: Int(whole.frameLength))
        let fade = max(1, Int(format.sampleRate * 0.002))
        var buffers: [AVAudioPCMBuffer] = []
        buffers.reserveCapacity(table.slices.count)
        for range in table.slices {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(range.count)),
                  let target = buffer.floatChannelData else { return nil }
            buffer.frameLength = AVAudioFrameCount(range.count)
            let tail = min(fade, range.count / 4)
            for channel in 0..<Int(format.channelCount) {
                let samples = target[channel]
                samples.update(from: source[channel] + range.lowerBound, count: range.count)
                for step in 0..<tail { samples[range.count - 1 - step] *= Float(step) / Float(tail) }
            }
            buffers.append(buffer)
        }
        id = pack.id
        self.table = table
        self.buffers = buffers
        self.format = format
        gain = Float(config.recommendedVolume)
    }

    /// `--selftest`: every bundled pack decodes, and its keys have sounds.
    /// The bare binary in `build/` carries no packs, which only warns.
    static func selfTest(failures: inout [String], warnings: inout [String], bundle: Bundle = .main) {
        guard let folder = bundle.resourceURL?.appendingPathComponent(MechakeyPack.resourceFolder),
              FileManager.default.fileExists(atPath: folder.path) else {
            warnings.append("Mechakey sound packs not bundled")
            return
        }
        // Space, Return and A have a press and a release in every pack.
        let keys: [UInt16] = [49, 36, 0]
        for pack in MechakeyPack.all {
            guard let loaded = MechakeyLoadedPack(pack: pack, bundle: bundle) else {
                failures.append("Mechakey pack \(pack.id) does not load")
                continue
            }
            if loaded.buffers.isEmpty
                || keys.contains(where: { loaded.table.press($0) == nil || loaded.table.release($0) == nil }) {
                failures.append("Mechakey pack \(pack.id) has keys without sounds")
            }
        }
    }

    /// "hello " typed once, mixed into one buffer.
    func previewBuffer(keyUpSounds: Bool) -> AVAudioPCMBuffer? {
        let hits = MechakeyPreview.hits(keyUpSounds: keyUpSounds)
        let longest = table.slices.map(\.count).max() ?? 0
        let length = MechakeyPreview.length(of: hits, sampleRate: format.sampleRate, longestSlice: longest)
        guard length > 0, let mix = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length)),
              let target = mix.floatChannelData else { return nil }
        mix.frameLength = AVAudioFrameCount(length)
        for channel in 0..<Int(format.channelCount) { target[channel].initialize(repeating: 0, count: length) }
        for hit in hits {
            guard let index = hit.down ? table.press(hit.keyCode) : table.release(hit.keyCode),
                  let slice = buffers[index].floatChannelData else { continue }
            let start = Int((hit.offset * format.sampleRate).rounded())
            let count = min(Int(buffers[index].frameLength), length - start)
            guard count > 0 else { continue }
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<count { target[channel][start + frame] += slice[channel][frame] }
            }
        }
        return mix
    }
}

/// The thread, the tap and the engines. Its public methods are for the main
/// thread; everything named `worker…` runs on Mechakey's own thread.
final class MechakeyPlayer {
    /// Simultaneous sounds: fast typing overlaps a key's release with the
    /// next keys' presses.
    static let voices = 8
    /// The engine rests after this long without a key, and wakes on the next.
    static let idleSeconds: CFTimeInterval = 60
    /// Frames per output cycle asked of the device: about 5 ms at 48 kHz.
    static let preferredBufferFrames: UInt32 = 256

    /// Main thread: the tap could not be made, so Input Monitoring is missing.
    var onTapFailure: (() -> Void)?
    /// Main thread: a preview finished.
    var onPreviewEnded: (() -> Void)?

    // Main thread only.
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var active: MechakeyPlayback?
    private var previewToken = 0
    private var previewing = false

    // Mechakey's thread only.
    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var loaded: MechakeyLoadedPack?
    private var playback: MechakeyPlayback?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var idleTimer: CFRunLoopTimer?
    private var lastSound: CFAbsoluteTime = 0
    private var previewEngine: AVAudioEngine?

    // MARK: Main thread

    /// Plays with these settings, or stops everything for nil.
    func apply(_ playback: MechakeyPlayback?) {
        guard playback != active else { return }
        active = playback
        if let playback {
            perform { $0.workerActivate(playback) }
        } else if runLoop != nil {
            perform { $0.workerDeactivate() }
        }
    }

    /// A few keys of a pack, whether or not Mechakey is on.
    func preview(_ pack: MechakeyPack, volume: Float, keyUpSounds: Bool) {
        previewToken += 1
        let token = previewToken
        previewing = true
        perform { worker in
            worker.workerPreview(pack, volume: volume, keyUpSounds: keyUpSounds) {
                DispatchQueue.main.async { worker.previewEnded(token) }
            }
        }
        // Should the engine never report the end, the thread still goes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.previewEnded(token) }
    }

    private func previewEnded(_ token: Int) {
        guard token == previewToken, previewing else { return }
        previewing = false
        perform { $0.workerStopPreview() }
        onPreviewEnded?()
    }

    private func perform(_ work: @escaping (MechakeyPlayer) -> Void) {
        if runLoop == nil { startThread() }
        guard let runLoop else { return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [self] in work(self) }
        CFRunLoopWakeUp(runLoop)
    }

    private func startThread() {
        let ready = DispatchSemaphore(value: 0)
        var loop: CFRunLoop?
        let thread = Thread {
            loop = CFRunLoopGetCurrent()
            // A port keeps the run loop waiting while there is nothing else on it.
            RunLoop.current.add(NSMachPort(), forMode: .default)
            ready.signal()
            while true {
                autoreleasepool { _ = RunLoop.current.run(mode: .default, before: .distantFuture) }
            }
        }
        thread.name = "Zenith Mechakey"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        self.thread = thread
        runLoop = loop
    }

    // MARK: Mechakey's thread

    private func workerActivate(_ playback: MechakeyPlayback) {
        if loaded?.id != playback.packID {
            workerTearDownEngine()
            loaded = MechakeyLoadedPack(pack: MechakeyPack.named(playback.packID))
        }
        self.playback = playback
        guard let loaded else { return }
        if engine == nil { workerBuildEngine(for: loaded) }
        engine?.mainMixerNode.outputVolume = playback.volume * loaded.gain
        if tap == nil { workerInstallTap() }
        if idleTimer == nil { workerStartIdleTimer() }
    }

    private func workerDeactivate() {
        workerRemoveTap()
        workerTearDownEngine()
        if let idleTimer { CFRunLoopTimerInvalidate(idleTimer) }
        idleTimer = nil
        loaded = nil
        playback = nil
    }

    private func workerBuildEngine(for pack: MechakeyLoadedPack) {
        let engine = AVAudioEngine()
        let mixer = engine.mainMixerNode
        players = (0..<Self.voices).map { _ in
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: pack.format)
            return player
        }
        nextPlayer = 0
        engine.prepare()
        self.engine = engine
        workerStartEngine()
    }

    private func workerStartEngine() {
        guard let engine, !engine.isRunning else { return }
        Self.preferShortCycles(engine)
        do { try engine.start() } catch { return }
        for player in players where !player.isPlaying { player.play() }
        lastSound = CFAbsoluteTimeGetCurrent()
    }

    private func workerTearDownEngine() {
        players.forEach { $0.stop() }
        engine?.stop()
        players = []
        engine = nil
    }

    /// The output device's cycle, shortened for this engine only (the HAL
    /// gives each client its own); ignored where the device refuses.
    private static func preferShortCycles(_ engine: AVAudioEngine) {
        guard let unit = engine.outputNode.audioUnit else { return }
        var frames = preferredBufferFrames
        AudioUnitSetProperty(unit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0,
                             &frames, UInt32(MemoryLayout<UInt32>.size))
    }

    private func workerStartIdleTimer() {
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + 15, 15, 0, 0) {
            [weak self] _ in
            guard let self, let engine = self.engine, engine.isRunning,
                  CFAbsoluteTimeGetCurrent() - self.lastSound > Self.idleSeconds else { return }
            engine.pause()
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        idleTimer = timer
    }

    /// The key path: two table reads, then a buffer on the next player.
    private func workerPlay(_ index: Int) {
        guard let engine, let loaded, index < loaded.buffers.count, !players.isEmpty else { return }
        if !engine.isRunning {
            // Resting, or the output device changed: wake before the sound.
            workerStartEngine()
            guard engine.isRunning else { return }
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(loaded.buffers[index], at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
        lastSound = CFAbsoluteTimeGetCurrent()
    }

    fileprivate func workerHandle(_ type: CGEventType, _ event: CGEvent) {
        let kind: MechakeyKeyEvent
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        case .keyDown:
            kind = .down(isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .keyUp:
            kind = .up
        case .flagsChanged:
            kind = .flagsChanged(flags: event.flags.rawValue)
        default:
            return
        }
        guard let playback, let loaded else { return }
        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        guard let index = MechakeyEventDecision.slice(for: kind, keyCode: keyCode, keyUpSounds: playback.keyUpSounds,
                                                      ignoreRepeat: playback.ignoreRepeat, table: loaded.table) else { return }
        workerPlay(index)
    }

    private func workerInstallTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        // `self` rides unretained: the tap is always removed before the player goes.
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: mechakeyTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            DispatchQueue.main.async { [weak self] in self?.onTapFailure?() }
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        tapSource = source
    }

    private func workerRemoveTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
    }

    private func workerPreview(_ pack: MechakeyPack, volume: Float, keyUpSounds: Bool, ended: @escaping () -> Void) {
        workerStopPreview()
        let source = loaded?.id == pack.id ? loaded : MechakeyLoadedPack(pack: pack)
        guard let source, let buffer = source.previewBuffer(keyUpSounds: keyUpSounds) else {
            ended()
            return
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: source.format)
        engine.mainMixerNode.outputVolume = volume * source.gain
        do { try engine.start() } catch {
            ended()
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { _ in ended() }
        player.play()
        previewEngine = engine
    }

    private func workerStopPreview() {
        previewEngine?.stop()
        previewEngine = nil
    }
}

/// The tap's C callback: hands the event to the player and lets it through untouched.
private func mechakeyTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                 refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon {
        Unmanaged<MechakeyPlayer>.fromOpaque(refcon).takeUnretainedValue().workerHandle(type, event)
    }
    return Unmanaged.passUnretained(event)
}
