// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Combine
import Foundation
import IOKit.pwr_mgt

/// Zenith fork: Claude Code in detail for Zenith Pocket, and replying to it
/// from the phone.
///
/// While Pocket shares Claude Code (`PocketDefaults.shareAgents`), this part
/// keeps `ClaudeHooksService` running even with the island's AI section off,
/// and fills `PocketMacState.claude` from its sessions, the usage reader's
/// snapshot and the end of Claude's last reply (read from the transcript the
/// Stop hook names).
///
/// Away mode (`.setAway` from the phone) is the file `<container>/PocketAway/on`.
/// With it, the hook script holds each finished turn for a reply, announcing
/// `<session>.waiting`; this part watches that folder, says which sessions
/// accept a reply, and hands a checked reply over as `<session>.<pid>.reply`.
/// Away mode lasts while Zenith runs, but its file only while the link is up,
/// so a Mac asleep or unpaired never holds Claude. Unlocking the Mac turns it
/// off: the person is back. While it is on, the Mac doesn't idle to sleep (or
/// a reply could never arrive); the screen still sleeps and locks as usual.
/// Used on the main thread.
final class PocketClaudePart: PocketPart {
    /// Away mode, kept across link restarts (sleep, a network change) while Zenith runs.
    private static var away = false

    static var awayURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent(ClaudeHooksSupport.awayFolderName, isDirectory: true)
    }

    private var context: PocketPartContext?
    private var sharing = false
    private var sharingObserver: PocketClaudeDefaultsObserver?
    private var unlockObserver: NSObjectProtocol?
    private var sinks = Set<AnyCancellable>()
    private var usage: PocketClaude.Usage?
    private var messages: [String: PocketClaudeRules.Message] = [:]
    /// The turns (their end) whose reply was read or is being read.
    private var readTurns: [String: Date] = [:]
    private var waiting: [String: PocketClaudeRules.Waiting] = [:]
    private var awaySource: DispatchSourceFileSystemObject?
    private var expiry: Timer?
    /// Keeps the Mac from idling to sleep while Away mode is on; 0 = none.
    private var awake = IOPMAssertionID(0)
    private let io = DispatchQueue(label: "id.satuvisual.zenith.pocket.claude", qos: .utility)

    func start(_ context: PocketPartContext) {
        self.context = context
        sharingObserver = PocketClaudeDefaultsObserver(key: PocketDefaults.shareAgents) { [weak self] in
            DispatchQueue.main.async { self?.sharingChanged() }
        }
        unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.unlocked() }
        sharingChanged()
    }

    func stop() {
        end()
        sharingObserver = nil
        if let unlockObserver { DistributedNotificationCenter.default().removeObserver(unlockObserver) }
        unlockObserver = nil
        context = nil
    }

    func fill(_ state: inout PocketMacState) {
        guard sharing else { return }
        let now = Date()
        let holding = Set(waiting.filter { PocketClaudeRules.holds($0.value, now: now, alive: Self.alive) }.keys)
        var claude = PocketClaudeRules.claude(sessions: ClaudeHooksService.shared.sessions, messages: messages,
                                              waiting: holding, usage: usage, away: Self.away, now: now)
        claude.awayMinutes = PocketClaudeRules.awayMinutes()
        for index in claude.sessions.indices where holding.contains(claude.sessions[index].id) {
            claude.sessions[index].replyDeadline = waiting[claude.sessions[index].id]?.deadline
        }
        state.claude = claude
    }

    func handle(_ command: PocketCommand, id: UUID) -> Bool {
        switch command {
        case .setAway(let on):
            setAway(on, id: id)
        case .setAwayWait(let minutes):
            setAwayWait(minutes, id: id)
        case .claudeReply(let session, let text):
            reply(text, to: session, id: id)
        default:
            return false
        }
        return true
    }

    // MARK: Sharing

    private func sharingChanged() {
        let next = UserDefaults.standard.object(forKey: PocketDefaults.shareAgents) as? Bool ?? true
        guard next != sharing || (next && sinks.isEmpty) else { return }
        sharing = next
        if next { begin() } else { end() }
        context?.changed()
    }

    private func begin() {
        ClaudeHooksService.shared.setPocketWants(true)
        sinks.removeAll()
        ClaudeHooksService.shared.$sessions.dropFirst()
            .sink { [weak self] sessions in self?.sessionsChanged(sessions) }.store(in: &sinks)
        AgentUsageService.shared.$snapshot
            .sink { [weak self] snapshot in self?.usageChanged(snapshot) }.store(in: &sinks)
        openAwayFolder()
        writeAwayFlag()
        sessionsChanged(ClaudeHooksService.shared.sessions)
    }

    private func end() {
        if sharing || !sinks.isEmpty { ClaudeHooksService.shared.setPocketWants(false) }
        sharing = false
        sinks.removeAll()
        closeAwayFolder()
        // Nothing can answer now: a holding hook lets its turn end.
        if let url = Self.awayURL { try? FileManager.default.removeItem(at: url.appendingPathComponent("on")) }
        holdAwake(false)
        messages = [:]
        readTurns = [:]
        waiting = [:]
        usage = nil
    }

    // MARK: Sessions and usage

    private func sessionsChanged(_ sessions: [ClaudeHooksSupport.Session]) {
        let ids = Set(sessions.map(\.id))
        messages = messages.filter { ids.contains($0.key) }
        readTurns = readTurns.filter { ids.contains($0.key) }
        for session in sessions {
            guard let finished = session.finished, let path = session.transcript, readTurns[session.id] != finished else { continue }
            if case .working = session.state { continue }
            readTurns[session.id] = finished
            let id = session.id
            // A moment for Claude Code to finish writing the transcript.
            io.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let text = PocketClaudeRules.readLastMessage(path: path)
                DispatchQueue.main.async {
                    guard let self, let text, self.readTurns[id] == finished else { return }
                    self.messages[id] = PocketClaudeRules.Message(finished: finished, text: text)
                    self.context?.changed()
                }
            }
        }
        context?.changed()
    }

    private func usageChanged(_ snapshot: AgentUsageSnapshot) {
        let next = PocketClaudeRules.usage(snapshot, now: Date())
        guard next != usage else { return }
        usage = next
        context?.changed()
    }

    // MARK: Away mode

    private func setAway(_ on: Bool, id: UUID) {
        guard sharing else { return answer(id, false, PocketClaudeRules.sharingOff) }
        // A hook from before Away mode is cancelled by Claude Code after 5 s.
        if on, ClaudeHooksService.settingsState() != .connected {
            return answer(id, false, PocketClaudeRules.hooksNeeded)
        }
        Self.away = on
        writeAwayFlag()
        answer(id, true, on ? PocketClaudeRules.awayOnLine(PocketClaudeRules.awayMinutes()) : PocketClaudeRules.awayOffLine)
        context?.changed()
    }

    private func setAwayWait(_ minutes: Int, id: UUID) {
        guard PocketClaudeRules.isAwayChoice(minutes) else { return answer(id, false, PocketClaudeRules.badAwayWait) }
        UserDefaults.standard.set(minutes, forKey: PocketClaudeRules.awayMinutesKey)
        // A turn already holding keeps its own deadline; the next one waits the new time.
        writeAwayFlag()
        answer(id, true, PocketClaudeRules.awayWaitLine(minutes))
        context?.changed()
    }

    private func unlocked() {
        guard Self.away else { return }
        Self.away = false
        writeAwayFlag()
        context?.changed()
    }

    private func writeAwayFlag() {
        holdAwake(Self.away && sharing)
        guard let url = Self.awayURL else { return }
        let flag = url.appendingPathComponent("on")
        if Self.away && sharing {
            // The script reads the wait, in seconds, from the flag itself.
            let seconds = PocketClaudeRules.awaySeconds(PocketClaudeRules.awayMinutes())
            if PrivateFileStore.createDirectory(at: url) { PrivateFileStore.write(Data("\(seconds)\n".utf8), to: flag) }
        } else {
            try? FileManager.default.removeItem(at: flag)
        }
    }

    /// Idle system sleep only: the display sleeps and the screen locks as
    /// usual (and unlocking ends Away mode); a closed lid still sleeps.
    private func holdAwake(_ on: Bool) {
        if on, awake == 0 {
            var id = IOPMAssertionID(0)
            let made = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                                   IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                   "Zenith Pocket Away mode: waiting for a reply from the phone" as CFString, &id)
            if made == kIOReturnSuccess { awake = id }
        } else if !on, awake != 0 {
            IOPMAssertionRelease(awake)
            awake = 0
        }
    }

    private func openAwayFolder() {
        guard awaySource == nil, let url = Self.awayURL, PrivateFileStore.createDirectory(at: url) else { return }
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename],
                                                               queue: .main)
        source.setEventHandler { [weak self] in self?.scanAway() }
        source.setCancelHandler { close(descriptor) }
        awaySource = source
        source.resume()
        scanAway()
    }

    private func closeAwayFolder() {
        awaySource?.cancel()
        awaySource = nil
        expiry?.invalidate()
        expiry = nil
    }

    /// Reads which hooks hold a turn, and drops replies no hook will read.
    private func scanAway() {
        guard let url = Self.awayURL else { return }
        let manager = FileManager.default
        let now = Date()
        var next: [String: PocketClaudeRules.Waiting] = [:]
        var replies: [(name: String, session: String, pid: Int32)] = []
        for name in (try? manager.contentsOfDirectory(atPath: url.path)) ?? [] {
            switch PocketClaudeRules.awayFile(name) {
            case .waiting(let session):
                let file = url.appendingPathComponent(name)
                if let text = try? String(contentsOf: file, encoding: .utf8), let held = PocketClaudeRules.waiting(text),
                   PocketClaudeRules.holds(held, now: now, alive: Self.alive) {
                    next[session] = held
                } else if let date = (try? manager.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date,
                          now.timeIntervalSince(date) > 5 {
                    // Left by a hook that was killed.
                    try? manager.removeItem(at: file)
                }
            case .reply(let session, let pid):
                replies.append((name, session, pid))
            case .other:
                break
            }
        }
        for reply in replies where next[reply.session]?.pid != reply.pid {
            try? manager.removeItem(at: url.appendingPathComponent(reply.name))
        }
        if next != waiting {
            waiting = next
            context?.changed()
        }
        // A hook killed without cleaning up leaves no event behind: look again.
        expiry?.invalidate()
        expiry = waiting.isEmpty ? nil : Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            self?.scanAway()
        }
    }

    private func reply(_ text: String, to session: String, id: UUID) {
        guard sharing else { return answer(id, false, PocketClaudeRules.sharingOff) }
        let held = waiting[session].flatMap { PocketClaudeRules.holds($0, now: Date(), alive: Self.alive) ? $0 : nil }
        switch PocketClaudeRules.check(reply: text, session: session, away: Self.away, holding: held != nil) {
        case .refuse(let message):
            answer(id, false, message)
        case .send(let reply):
            guard let held, let folder = Self.awayURL else { return answer(id, false, PocketClaudeRules.notWaiting) }
            let file = folder.appendingPathComponent(PocketClaudeRules.replyName(session: session, pid: held.pid))
            let data = PocketClaudeRules.hookAnswer(reply)
            let context = self.context
            io.async {
                guard PrivateFileStore.write(data, to: file) else {
                    context?.reply(id, false, PocketClaudeRules.couldNotWrite)
                    return
                }
                // The hook takes the file within a second; one still there wasn't read.
                let deadline = Date().addingTimeInterval(PocketClaudeRules.handoverWait)
                while Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.25)
                    if !FileManager.default.fileExists(atPath: file.path) {
                        context?.reply(id, true, PocketClaudeRules.sent)
                        return
                    }
                }
                try? FileManager.default.removeItem(at: file)
                context?.reply(id, false, PocketClaudeRules.missed)
            }
        }
    }

    private func answer(_ id: UUID, _ ok: Bool, _ message: String) {
        context?.reply(id, ok, message)
    }

    private static func alive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}

/// Watches one preference (key-value observing on the standard defaults).
private final class PocketClaudeDefaultsObserver: NSObject {
    private let key: String
    private let changed: () -> Void

    init(key: String, changed: @escaping () -> Void) {
        self.key = key
        self.changed = changed
        super.init()
        UserDefaults.standard.addObserver(self, forKeyPath: key, options: [], context: nil)
    }

    deinit { UserDefaults.standard.removeObserver(self, forKeyPath: key) }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        changed()
    }
}
