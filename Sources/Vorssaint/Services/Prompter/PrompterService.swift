// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

// Zenith fork: the teleprompter's state. It keeps the scripts (files in the
// container, their list in a registered default), the one prompting session
// and its clock, and talks to the island: the island asks it for the reading
// panel's size (`islandGeometry`), whether to stay open (`holdsIsland`) and
// gives it the keys while it prompts (`handleIslandKey`). Nothing runs while
// no session does, except the optional global shortcut.

/// One prompting session: the script laid out, where it is and how it moves.
struct PrompterSessionState {
    let scriptID: UUID
    let paragraphs: [PrompterParagraph]
    var settings: PrompterSettings
    var timeline: PrompterTimeline
    /// The reader's measurements replaced the estimate for this layout.
    var measured = false
    /// Bumped whenever the column lays out anew, so a late measurement of
    /// an older layout is ignored.
    var generation = 0
    var clock: PrompterClock
    /// 3, 2, 1 before the start; nil once it runs.
    var countdown: Int?
    var playing = false
    var finished = false
    /// Voice-paced and quiet for 1.5 seconds.
    var voiceHolding = false
    /// The microphone is being read for the voice pace.
    var listening = false
    /// Frames keep coming until this moment, for a jump's glide.
    var animatingUntil: TimeInterval = 0

    var runs: Bool { playing && countdown == nil && !voiceHolding && !finished }
    func animating(at time: TimeInterval) -> Bool { runs || time < animatingUntil }
}

final class PrompterService: ObservableObject {
    static let shared = PrompterService()
    /// The quick tools' hotkey ids are small numbers; workspaces take 1800 and up.
    private static let hotkeyID: UInt32 = 1950

    @Published private(set) var scripts: [PrompterScript] = []
    @Published private(set) var selectedID: UUID?
    /// The chosen script's text as it is being edited; saved shortly after typing stops.
    @Published private(set) var draft = ""
    @Published private(set) var session: PrompterSessionState? { didSet { syncIsland() } }
    @Published private(set) var shortcutRefused = false
    /// A dialog of ours stands beside the island; it must stay open.
    @Published private(set) var modalActive = false { didSet { syncIsland() } }

    private let store: PrompterStore?
    private var storedList: String
    private var saveWork: DispatchWorkItem?
    private var countdownWork: DispatchWorkItem?
    private var finishWork: DispatchWorkItem?
    private var glideWork: DispatchWorkItem?
    private var relayoutWork: DispatchWorkItem?
    private var measuredFrames: [Int: CGRect] = [:]
    private var islandWatch = Set<AnyCancellable>()
    private var defaultsObserver: NSObjectProtocol?
    private var captureObserver: NSObjectProtocol?
    private let hotkey = QuickToolHotkey(id: PrompterService.hotkeyID)
    private let voice = PrompterVoiceMonitor()
    private var voicePace = PrompterVoicePace(now: 0)

    private init() {
        store = PrompterStore.standard
        storedList = UserDefaults.standard.string(forKey: DefaultsKey.notchPrompterScripts) ?? ""
        scripts = store?.list() ?? []
        let last = UserDefaults.standard.string(forKey: DefaultsKey.notchPrompterLastScript).flatMap(UUID.init(uuidString:))
        selectedID = scripts.first(where: { $0.id == last })?.id ?? scripts.first?.id
        draft = selectedScript.flatMap { store?.text(of: $0) } ?? ""
        hotkey.onPress = { [weak self] in self?.toggleFromShortcut() }
        ZenithPrompterIsland.perform = { [weak self] action in self?.performIslandKey(action) ?? false }
        // A restored backup or another window changed the list: read it again.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                                                                  queue: .main) { [weak self] _ in
            self?.reloadIfChanged()
        }
        captureObserver = NotificationCenter.default.addObserver(forName: .zenithShortcutCaptureEnded, object: nil,
                                                                 queue: .main) { [weak self] _ in
            self?.syncShortcut()
        }
    }

    private var text: ZenithPrompterStrings { ZenithStrings.prompter(L10n.shared.language) }

    // MARK: Scripts

    var selectedScript: PrompterScript? { scripts.first { $0.id == selectedID } }

    func select(_ id: UUID) {
        guard id != selectedID, let script = scripts.first(where: { $0.id == id }) else { return }
        flushSave()
        selectedID = id
        draft = store?.text(of: script) ?? ""
        UserDefaults.standard.set(id.uuidString, forKey: DefaultsKey.notchPrompterLastScript)
    }

    /// Typing in an editor: the text is kept now and written a moment later.
    func setDraft(_ value: String) {
        guard value != draft else { return }
        draft = value
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushSave() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func flushSave() {
        saveWork?.cancel(); saveWork = nil
        guard let id = selectedID, let store,
              let script = scripts.first(where: { $0.id == id }), store.text(of: script) != draft else { return }
        store.save(draft, for: id)
        reloadList()
    }

    @discardableResult
    func createScript(name: String? = nil, text body: String = "", format: PrompterScriptFormat = .markdown) -> PrompterScript? {
        flushSave()
        guard let script = store?.create(name: name ?? text.untitledScript, text: body, format: format,
                                         fallbackName: text.untitledScript) else { return nil }
        reloadList()
        selectedID = script.id
        draft = body
        UserDefaults.standard.set(script.id.uuidString, forKey: DefaultsKey.notchPrompterLastScript)
        return script
    }

    func rename(_ id: UUID, to name: String) {
        store?.rename(id, to: name, fallbackName: text.untitledScript)
        reloadList()
    }

    func delete(_ id: UUID) {
        if session?.scriptID == id { stop() }
        if id == selectedID { saveWork?.cancel(); saveWork = nil }
        store?.delete(id)
        reloadList()
        if selectedID == id || selectedScript == nil {
            selectedID = scripts.first?.id
            draft = selectedScript.flatMap { store?.text(of: $0) } ?? ""
        }
    }

    /// The Scratchpad's chosen pad, as a new script named after it.
    var canUseScratchpad: Bool { AppFeature.scratchpad.isAvailable }

    func createFromScratchpad() {
        let pad = ScratchpadService.shared
        guard canUseScratchpad, pad.loadForEmbedding() else { return }
        pad.commitEdits()
        createScript(name: pad.selectedPadName, text: pad.text)
    }

    /// Imports `.txt` and `.md` files; false when one could not be read.
    @discardableResult
    func importFiles(_ urls: [URL]) -> Bool {
        flushSave()
        var allRead = true
        var last: PrompterScript?
        for url in urls {
            if let script = store?.importFile(at: url, fallbackName: text.untitledScript) { last = script } else { allRead = false }
        }
        reloadList()
        if let last {
            selectedID = last.id
            draft = store?.text(of: last) ?? ""
            UserDefaults.standard.set(last.id.uuidString, forKey: DefaultsKey.notchPrompterLastScript)
        }
        return allRead
    }

    /// The open panel, from Settings or above the island. From the island
    /// it floats over it, and the island stays open while it is up.
    func presentImport(from window: NSWindow?) {
        guard !modalActive else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = PrompterStore.importExtensions.compactMap { UTType(filenameExtension: $0) } + [.plainText]
        let failed = text.importFailed
        let complete: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            self?.modalActive = false
            if response == .OK, self?.importFiles(panel.urls) == false {
                QuickToolHUD.show(icon: "exclamationmark.triangle", message: failed)
            }
            if let window, window.isVisible { DispatchQueue.main.async { window.makeKey() } }
        }
        modalActive = true
        if let window, window === NotchService.shared.presentationWindow {
            panel.level = NSWindow.Level(rawValue: window.level.rawValue + 1)
            panel.hidesOnDeactivate = false
            panel.begin(completionHandler: complete)
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else if let window {
            panel.beginSheetModal(for: window, completionHandler: complete)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            complete(panel.runModal())
        }
    }

    private func reloadList() {
        storedList = UserDefaults.standard.string(forKey: DefaultsKey.notchPrompterScripts) ?? ""
        let list = store?.list() ?? []
        if list != scripts { scripts = list }
    }

    private func reloadIfChanged() {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.notchPrompterScripts) ?? ""
        if raw != storedList {
            reloadList()
            if selectedScript == nil {
                selectedID = scripts.first?.id
                draft = selectedScript.flatMap { store?.text(of: $0) } ?? ""
            }
        }
        let shortcut = UserDefaults.standard.string(forKey: DefaultsKey.notchPrompterShortcut) ?? ""
        if shortcut != registeredShortcut { syncShortcut() }
    }

    /// Duration of the chosen script at the default speed.
    func duration(of body: String, wpm: Int) -> TimeInterval {
        let words = PrompterText.wordCount(body)
        return wpm > 0 ? Double(words) * 60 / Double(wpm) : 0
    }

    // MARK: Shortcut

    private var registeredShortcut = ""

    /// At launch: registers the start/stop shortcut, if one is set.
    func start() {
        syncShortcut()
    }

    func syncShortcut() {
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.notchPrompterShortcut) ?? ""
        registeredShortcut = raw
        guard let shortcut = GlobalShortcut(storageValue: raw) else {
            hotkey.unregister()
            if shortcutRefused { shortcutRefused = false }
            return
        }
        let refused = !hotkey.sync(enabled: true, shortcut: shortcut, storageKey: DefaultsKey.notchPrompterShortcut)
        if refused != shortcutRefused { shortcutRefused = refused }
    }

    /// Who already answers to a combination, or nil when it is free.
    func conflict(for shortcut: GlobalShortcut) -> String? {
        GlobalShortcutRole.conflict(for: shortcut, excluding: nil)?.title(L10n.shared.s)
    }

    private func toggleFromShortcut() {
        if session != nil { stop(collapse: true) } else { startSession() }
    }

    // MARK: Session

    private static var now: TimeInterval { Date().timeIntervalSinceReferenceDate }
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// The island's reading panel while a session runs; nil otherwise.
    var islandGeometry: ZenithPrompterIslandGeometry? {
        session.map { ZenithPrompterIslandGeometry(settings: $0.settings) }
    }

    /// The island stays open while prompting and while our dialog is up.
    var holdsIsland: Bool { session != nil || modalActive }

    /// The reading column's width inside the panel, for the estimate.
    /// The island is the chosen width plus its open growth; the page
    /// sits inside its margins, and the text inside the panel's.
    static func columnWidth(panelWidth: Int) -> Double {
        Double(panelWidth) + Double(NotchLayout.openGrowth - NotchLayout.horizontalInset) * 2
            - PrompterReaderMetrics.textInset * 2
    }

    /// Starts prompting `id`, or the last script, after a 3-2-1 countdown, in the island.
    func startSession(_ id: UUID? = nil) {
        flushSave()
        // Starting again, from Settings say, begins anew.
        if session != nil { endSession() }
        guard let script = id.flatMap({ id in scripts.first { $0.id == id } }) ?? selectedScript ?? scripts.first,
              let store else { return }
        let body = script.id == selectedID ? draft : store.text(of: script)
        let paragraphs = PrompterText.paragraphs(body)
        guard !paragraphs.isEmpty, NotchSupport.isEnabled() else { ZenithQuiet.beep(); return }
        if script.id != selectedID { select(script.id) }
        let settings = PrompterSettings.current()
        let timeline = PrompterLayout.estimate(paragraphs, textSize: settings.textSize, lineSpacing: settings.lineSpacing,
                                               width: Self.columnWidth(panelWidth: settings.width))
        let now = Self.now
        let state = PrompterSessionState(scriptID: script.id, paragraphs: paragraphs, settings: settings, timeline: timeline,
                                         clock: PrompterClock(limit: timeline.limit,
                                                              speed: timeline.pointsPerSecond(wpm: settings.speed), now: now),
                                         countdown: 3)
        measuredFrames = [:]
        withoutAnimation { session = state }
        present()
        // The island could not open (off, or over a locked screen): nothing to prompt in.
        guard NotchService.shared.expanded, NotchService.shared.selected == .prompter else {
            endSession()
            return
        }
        watchIsland()
        scheduleCountdown()
        if settings.voicePaced { startListening() }
    }

    /// Ends prompting; the island goes back to the script page, or closes.
    func stop(collapse: Bool = false) {
        guard session != nil else { return }
        endSession()
        let notch = NotchService.shared
        if collapse { notch.collapse() }
        else if notch.expanded, notch.selected == .prompter { notch.refreshPresentation(transitionContent: .replace) }
    }

    private func endSession() {
        countdownWork?.cancel(); countdownWork = nil
        finishWork?.cancel(); finishWork = nil
        glideWork?.cancel(); glideWork = nil
        relayoutWork?.cancel(); relayoutWork = nil
        islandWatch.removeAll()
        voice.stop()
        if let session {
            // The speed and size chosen while reading are the next session's.
            let defaults = UserDefaults.standard
            defaults.set(session.settings.speed, forKey: DefaultsKey.notchPrompterSpeed)
            defaults.set(session.settings.textSize, forKey: DefaultsKey.notchPrompterTextSize)
        }
        withoutAnimation { session = nil }
    }

    /// Already on the page, the island morphs into the panel in place and
    /// takes the keyboard; otherwise opening it does both.
    private func present() {
        let notch = NotchService.shared
        if notch.expanded, notch.selected == .prompter, !notch.showingSections {
            notch.refreshPresentation(transitionContent: .replace)
            notch.presentationWindow?.makeKey()
        } else {
            notch.open(.prompter)
        }
    }

    /// Leaving the page, opening the gallery or closing the island ends the session.
    private func watchIsland() {
        islandWatch.removeAll()
        let notch = NotchService.shared
        Publishers.CombineLatest3(notch.$expanded, notch.$selected, notch.$showingSections)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expanded, selected, sections in
                guard self?.session != nil, !expanded || selected != .prompter || sections else { return }
                self?.endSession()
                // The tab pill and the floating buttons come back with the page left for.
                if expanded { notch.refreshPresentation() }
            }
            .store(in: &islandWatch)
    }

    private func scheduleCountdown() {
        countdownWork?.cancel()
        guard let count = session?.countdown else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, var state = self.session else { return }
            if count > 1 {
                state.countdown = count - 1
                self.session = state
                self.scheduleCountdown()
            } else {
                state.countdown = nil
                state.playing = true
                self.session = state
                self.voicePace.reset(at: Self.now)
                self.syncClock()
            }
        }
        countdownWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    /// Runs or holds the clock to match the session, and plans the end.
    private func syncClock() {
        guard var state = session else { return }
        let now = Self.now
        if state.clock.running != state.runs { state.clock.setRunning(state.runs, at: now) }
        session = state
        finishWork?.cancel(); finishWork = nil
        guard let finish = state.clock.finishTime() else { return }
        let work = DispatchWorkItem { [weak self] in self?.reachedEnd() }
        finishWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, finish - now) + 0.01, execute: work)
    }

    private func reachedEnd() {
        guard var state = session, state.clock.isFinished(at: Self.now) else { syncClock(); return }
        state.finished = true
        state.playing = false
        session = state
        syncClock()
    }

    // MARK: Controls

    func perform(_ action: PrompterKeyAction) {
        switch action {
        case .toggle: togglePlayback()
        case .faster: changeSpeed(by: PrompterSettings.speedStep)
        case .slower: changeSpeed(by: -PrompterSettings.speedStep)
        case .previous: jump(forward: false)
        case .next: jump(forward: true)
        case .larger: changeTextSize(by: PrompterSettings.textSizeStep)
        case .smaller: changeTextSize(by: -PrompterSettings.textSizeStep)
        case .exit: stop()
        }
    }

    func togglePlayback() {
        guard var state = session else { return }
        let now = Self.now
        if state.countdown != nil {
            // Space during the countdown starts right away.
            countdownWork?.cancel(); countdownWork = nil
            state.countdown = nil
            state.playing = true
        } else if state.finished {
            state.finished = false
            state.playing = true
            state.clock.jump(to: 0, at: now, animated: !reduceMotion)
            state.animatingUntil = now + PrompterClock.glideDuration
        } else {
            state.playing.toggle()
        }
        if state.playing { voicePace.reset(at: now); state.voiceHolding = false }
        session = state
        syncClock()
    }

    private func changeSpeed(by step: Int) {
        guard var state = session else { return }
        let speed = PrompterSettings.clampedSpeed(state.settings.speed + step)
        guard speed != state.settings.speed else { return }
        state.settings.speed = speed
        state.clock.setSpeed(state.timeline.pointsPerSecond(wpm: speed), at: Self.now)
        session = state
        syncClock()
    }

    private func jump(forward: Bool) {
        guard var state = session else { return }
        let now = Self.now
        let target = state.timeline.jumpTarget(from: state.clock.offset(at: now), forward: forward)
        let animated = !reduceMotion
        state.clock.jump(to: target, at: now, animated: animated)
        if target < state.timeline.limit { state.finished = false }
        if animated { state.animatingUntil = now + PrompterClock.glideDuration }
        session = state
        scheduleGlideEnd(state.animatingUntil - now)
        syncClock()
    }

    private func changeTextSize(by step: Int) {
        guard var state = session else { return }
        let size = PrompterSettings.clampedTextSize(state.settings.textSize + step)
        guard size != state.settings.textSize else { return }
        state.settings.textSize = size
        relayout(&state, with: PrompterLayout.estimate(state.paragraphs, textSize: size, lineSpacing: state.settings.lineSpacing,
                                                       width: Self.columnWidth(panelWidth: state.settings.width)))
        state.measured = false
        state.generation += 1
        measuredFrames = [:]
        withoutAnimation { session = state }
        syncClock()
    }

    func toggleMirror() {
        guard var state = session else { return }
        state.settings.mirror.toggle()
        UserDefaults.standard.set(state.settings.mirror, forKey: DefaultsKey.notchPrompterMirror)
        session = state
    }

    /// The same place in a new layout, at the same words per minute.
    private func relayout(_ state: inout PrompterSessionState, with next: PrompterTimeline) {
        let now = Self.now
        let offset = state.timeline.translate(state.clock.baseOffset(at: now), to: next)
        state.timeline = next
        state.clock.relayout(offset: offset, limit: next.limit, speed: next.pointsPerSecond(wpm: state.settings.speed), at: now)
    }

    private func scheduleGlideEnd(_ delay: TimeInterval) {
        glideWork?.cancel()
        guard delay > 0 else { return }
        let work = DispatchWorkItem { [weak self] in self?.objectWillChange.send() }
        glideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.02, execute: work)
    }

    // MARK: Measurement

    /// The reader's paragraph frames, in its column. Once every paragraph
    /// of the current layout has reported, they replace the estimate.
    func measured(index: Int, frame: CGRect, generation: Int) {
        guard let state = session, generation == state.generation, frame.height.isFinite, frame.height > 0 else { return }
        measuredFrames[index] = frame
        guard measuredFrames.count >= state.paragraphs.count, relayoutWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.relayoutWork = nil
            self.applyMeasurements()
        }
        relayoutWork = work
        DispatchQueue.main.async(execute: work)
    }

    private func applyMeasurements() {
        guard var state = session else { return }
        let frames = (0..<state.paragraphs.count).compactMap { measuredFrames[$0] }
        guard frames.count == state.paragraphs.count else { return }
        let next = PrompterTimeline(tops: frames.map { Double($0.minY) }, heights: frames.map { Double($0.height) },
                                    words: state.paragraphs.map(\.words),
                                    lineHeight: Double(state.settings.textSize) * 1.2)
        guard next != state.timeline else { return }
        relayout(&state, with: next)
        state.measured = true
        withoutAnimation { session = state }
        syncClock()
    }

    // MARK: Voice pace

    private func startListening() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        // Permission is asked for only by the switch in Settings; a session
        // without it scrolls at its speed alone.
        guard status == .authorized else { return }
        voicePace = PrompterVoicePace(now: Self.now)
        let started = voice.start { [weak self] level in self?.heard(level) }
        guard var state = session else { voice.stop(); return }
        state.listening = started
        session = state
    }

    private func heard(_ level: Float) {
        guard var state = session, state.listening else { return }
        let now = Self.now
        let holding = voicePace.update(level: level, at: now)
        // Only a playing script waits for the voice; a paused one stays paused.
        let wanted = state.playing && state.countdown == nil && holding
        guard wanted != state.voiceHolding else { return }
        state.voiceHolding = wanted
        session = state
        syncClock()
    }

    // MARK: Keys

    /// The island's keys while prompting, through `ZenithPrompterIsland`.
    /// True when the key was the prompter's.
    private func performIslandKey(_ action: PrompterKeyAction) -> Bool {
        let notch = NotchService.shared
        guard session != nil, notch.expanded, notch.selected == .prompter, !notch.showingSections else { return false }
        perform(action)
        return true
    }

    /// What the island reads of the session, kept as it changes.
    private func syncIsland() {
        let geometry = islandGeometry
        if ZenithPrompterIsland.geometry != geometry { ZenithPrompterIsland.geometry = geometry }
        ZenithPrompterIsland.holdsIsland = holdsIsland
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}

/// The microphone's level for the voice pace: an input tap on the engine,
/// its root mean square in dBFS handed to the main thread. No buffer is kept
/// and nothing is recognised; the engine stops with the session.
final class PrompterVoiceMonitor {
    private var engine: AVAudioEngine?

    @discardableResult
    func start(onLevel: @escaping (Float) -> Void) -> Bool {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return false }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            var sum: Float = 0
            for index in 0..<frames { sum += channel[index] * channel[index] }
            let level = PrompterVoicePace.level(rms: (sum / Float(frames)).squareRoot())
            DispatchQueue.main.async { onLevel(level) }
        }
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return false
        }
        self.engine = engine
        return true
    }

    func stop() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }
}
