// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

@preconcurrency import AVFoundation
import Observation
@preconcurrency import Speech

/// Speaking a reply instead of typing it: the microphone into Apple's speech
/// recognizer, on the iPhone when it can, in the phone's own language.
/// Listening stops by itself after a pause the recognizer notices, or after
/// `limit` at most.
@MainActor
@Observable
final class Dictation {
    private(set) var listening = false
    /// What was heard so far in this listen.
    private(set) var transcript = ""
    /// Why it couldn't listen, shown under the composer.
    private(set) var problem: String?

    static let limit: Duration = .seconds(60)

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = 0

    func toggle() async {
        if listening { stop() } else { await start() }
    }

    func start() async {
        guard !listening else { return }
        problem = nil
        transcript = ""
        guard await Self.speechAllowed() else {
            problem = "Allow Speech Recognition for Pocket in Settings to dictate."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            problem = "Allow the microphone for Pocket in Settings to dictate."
            return
        }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            problem = "Dictation isn't available right now."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // On the phone when it can: what is said stays on it.
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            let engine = AVAudioEngine()
            Self.feed(engine.inputNode, into: request)
            engine.prepare()
            try engine.start()
            generation += 1
            let generation = self.generation
            task = Self.recognize(request, with: recognizer) { [weak self] text, final in
                Task { @MainActor in self?.heard(text, final: final, generation: generation) }
            }
            self.engine = engine
            self.request = request
            listening = true
            Task { [weak self] in
                try? await Task.sleep(for: Self.limit)
                guard let self, self.generation == generation else { return }
                self.stop()
            }
        } catch {
            problem = "Pocket couldn't use the microphone."
            stop()
        }
    }

    func stop() {
        generation += 1
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        engine = nil
        request = nil
        task = nil
        if listening { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        listening = false
    }

    private func heard(_ text: String?, final: Bool, generation: Int) {
        guard generation == self.generation else { return }
        if let text { transcript = text }
        if final { stop() }
    }

    // The audio and recognition callbacks run on their own threads, so they
    // are made outside the main actor.

    private nonisolated static func speechAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    private nonisolated static func feed(_ input: AVAudioInputNode, into request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func recognize(_ request: SFSpeechAudioBufferRecognitionRequest, with recognizer: SFSpeechRecognizer,
                                              update: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            update(result?.bestTranscription.formattedString, (result?.isFinal ?? false) || error != nil)
        }
    }
}
