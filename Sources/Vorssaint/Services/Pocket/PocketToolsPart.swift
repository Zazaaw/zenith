// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Combine
import Foundation

/// Zenith fork: Zenith's own tools on Zenith Pocket's Mac tab, each read from
/// the service that already keeps it: the workspaces (`WorkspaceService`),
/// the island timer (`NotchTimerService`), the dev servers
/// (`DevServersService`), the next event (`NotchCalendarService`), the
/// downloads in progress (`NotchDownloadService`) and, only when the person
/// shares it, the latest text clips (`ClipboardHistoryService`). Nothing is
/// polled: each publisher says when to send again. While a phone watches,
/// the dev servers are looked at as for a page on screen.
final class PocketToolsPart: PocketPart {
    private var context: PocketPartContext?
    private var sinks: Set<AnyCancellable> = []
    private var eventTimer: Timer?
    private var watching = false
    private var sharesClipboard = false

    func start(_ context: PocketPartContext) {
        self.context = context
        sharesClipboard = UserDefaults.standard.bool(forKey: PocketDefaults.shareClipboard)
        watch(WorkspaceService.shared.$workspaces)
        watch(NotchTimerService.shared.$session)
        watch(DevServersService.shared.$servers)
        watch(NotchDownloadService.shared.$items)
        watch(ClipboardHistoryService.shared.$entries, clipboard: true)
        NotchCalendarService.shared.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.eventsChanged() }
            .store(in: &sinks)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.preferencesChanged() }
            .store(in: &sinks)
    }

    func stop() {
        setWatching(false)
        sinks.removeAll()
        eventTimer?.invalidate(); eventTimer = nil
        context = nil
    }

    func setWatching(_ open: Bool) {
        guard open != watching else { return }
        watching = open
        if open { DevServersService.shared.shown() } else { DevServersService.shared.hidden() }
    }

    func fill(_ state: inout PocketMacState) {
        let now = Date()
        state.tools = PocketTools(workspaces: workspaces(), timer: timer(now: now), devServers: devServers(),
                                  nextEvent: PocketToolsRules.nextEvent(events(), now: now),
                                  downloads: downloads(), clips: clips())
    }

    func handle(_ command: PocketCommand, id: UUID) -> Bool {
        switch command {
        case .openWorkspace, .timer, .pauseTimer, .stopDevServer: break
        default: return false
        }
        switch PocketMacCommands.plan(command) {
        case .workspace(let uuid)?: openWorkspace(uuid, id: id)
        case .startTimer(let minutes)?: startTimer(minutes, id: id)
        case .stopTimer?: stopTimer(id: id)
        case .pauseTimer(let paused)?: pauseTimer(paused, id: id)
        case .stopDevServer(let port)?: stopDevServer(port, id: id)
        case .refuse(let message)?: context?.reply(id, false, message)
        default: context?.reply(id, false, nil)
        }
        return true
    }

    // MARK: Observing

    private func watch<P: Publisher>(_ publisher: P, clipboard: Bool = false) where P.Failure == Never {
        publisher.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !clipboard || self.sharesClipboard else { return }
                self.context?.changed()
            }
            .store(in: &sinks)
    }

    private func preferencesChanged() {
        let next = UserDefaults.standard.bool(forKey: PocketDefaults.shareClipboard)
        guard next != sharesClipboard else { return }
        sharesClipboard = next
        context?.changed()
    }

    /// The next event changes when one starts or ends, not only when the
    /// calendar does: wake then.
    private func eventsChanged() {
        eventTimer?.invalidate(); eventTimer = nil
        context?.changed()
        guard let at = PocketToolsRules.nextChange(events(), now: Date()) else { return }
        let timer = Timer(fire: at.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            self?.eventsChanged()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        eventTimer = timer
    }

    // MARK: Reading

    private func workspaces() -> [PocketTools.Workspace] {
        WorkspaceService.shared.enabled.prefix(12).map {
            PocketTools.Workspace(id: $0.id.uuidString, name: String($0.name.prefix(60)), symbol: $0.symbol)
        }
    }

    private func timer(now: Date) -> PocketTools.Timer? {
        guard NotchTimerSupport.isEnabled() else { return nil }
        let service = NotchTimerService.shared
        let session = service.session
        guard session.hasSession else { return nil }
        let clock = service.now
        let label = Self.label(session.phase)
        if session.completed { return PocketTools.Timer(label: label + " done", remaining: 0) }
        if session.isPaused { return PocketTools.Timer(label: label, remaining: session.reading(at: clock), paused: true) }
        guard let deadline = session.deadline else { return PocketTools.Timer(label: label) }
        // Whole seconds, so the same timer reads the same in every state.
        let ends = Date(timeIntervalSince1970: (now.timeIntervalSince1970 + deadline - clock).rounded())
        return PocketTools.Timer(label: label, endsAt: ends)
    }

    private static func label(_ phase: NotchTimerPhase) -> String {
        switch phase {
        case .timer: return "Timer"
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        case .stopwatch: return "Stopwatch"
        }
    }

    private func devServers() -> [PocketTools.DevServer] {
        DevServersService.shared.servers.prefix(8).map {
            PocketTools.DevServer(port: $0.port, process: $0.framework, project: $0.project)
        }
    }

    private func events() -> [PocketToolsRules.Event] {
        guard NotchCalendarSupport.isEnabled() else { return [] }
        return NotchCalendarService.shared.events.map {
            PocketToolsRules.Event(title: $0.title, start: $0.start, end: $0.end, allDay: $0.allDay)
        }
    }

    private func downloads() -> [PocketTools.Download] {
        NotchDownloadService.shared.items.filter { $0.active && !$0.completed }.prefix(3).map {
            PocketTools.Download(name: String($0.name.prefix(80)), progress: $0.fraction)
        }
    }

    private func clips() -> [String] {
        guard sharesClipboard else { return [] }
        let service = ClipboardHistoryService.shared
        guard service.isRunning else { return [] }
        let texts = service.entries.filter { $0.kind == .text }.sorted { $0.copiedAt > $1.copiedAt }.prefix(20).map(\.text)
        return PocketToolsRules.clips(Array(texts))
    }

    // MARK: Commands

    private func openWorkspace(_ uuid: UUID, id: UUID) {
        let service = WorkspaceService.shared
        guard let workspace = service.workspace(uuid), workspace.isEnabled else {
            context?.reply(id, false, PocketMacCommands.badWorkspace)
            return
        }
        guard service.runningID == nil else {
            context?.reply(id, false, PocketToolsRules.workspaceBusy)
            return
        }
        service.run(uuid)
        context?.reply(id, true, "Opening \(workspace.name).")
    }

    private func startTimer(_ minutes: Int, id: UUID) {
        guard NotchTimerSupport.isEnabled() else {
            context?.reply(id, false, PocketToolsRules.timerOff)
            return
        }
        let service = NotchTimerService.shared
        // A new length from the phone replaces whatever ran.
        if service.session.hasSession { service.cancel() }
        service.start(mode: .timer, minutes: minutes)
        if service.session.isRunning {
            context?.reply(id, true, "Timer set for \(PocketPresentation.duration(minutes: minutes)).")
        } else {
            context?.reply(id, false, "Your Mac couldn't start the timer.")
        }
    }

    private func stopTimer(id: UUID) {
        let service = NotchTimerService.shared
        guard service.session.hasSession else {
            context?.reply(id, false, PocketToolsRules.noTimer)
            return
        }
        service.cancel()
        context?.reply(id, true, "Timer stopped.")
    }

    private func pauseTimer(_ paused: Bool, id: UUID) {
        guard NotchTimerSupport.isEnabled() else {
            context?.reply(id, false, PocketToolsRules.timerOff)
            return
        }
        let service = NotchTimerService.shared
        let session = service.session
        guard session.isRunning || session.isPaused else {
            context?.reply(id, false, PocketToolsRules.noTimer)
            return
        }
        if paused == session.isRunning { service.pauseOrResume() }
        context?.reply(id, true, paused ? "Timer paused." : "Timer running again.")
    }

    /// The Port Manager's path, as the island's Kill: SIGTERM, then SIGKILL if
    /// the very same process (pid and start time) is still there.
    private func stopDevServer(_ port: Int, id: UUID) {
        guard let server = DevServersService.shared.servers.first(where: { $0.ports.contains(port) }) else {
            context?.reply(id, false, PocketToolsRules.devServerGone)
            return
        }
        guard server.canKill, let start = server.startMicros else {
            context?.reply(id, false, PocketToolsRules.devServerKeep)
            return
        }
        let killer = KillProcessService.shared
        killer.kill(pid: server.pid, name: server.processName, startedAt: start, force: false) {
            DispatchQueue.main.async { DevServersService.shared.refresh() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + DevServersKillConfirmation.escalation) {
            guard KillProcessService.startTime(for: server.pid) == start else { return }
            killer.kill(pid: server.pid, name: server.processName, startedAt: start, force: true) {
                DispatchQueue.main.async { DevServersService.shared.refresh() }
            }
        }
        context?.reply(id, true, "Stopping \(server.title) on :\(port).")
    }
}
