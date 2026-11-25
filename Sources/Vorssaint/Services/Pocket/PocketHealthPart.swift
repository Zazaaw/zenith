// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

/// Zenith fork: the Mac's health on Zenith Pocket's Mac tab: CPU, its
/// temperature, memory and network from the system monitor (a background
/// consumer of its own, `setPocketNeeds`), the startup disk's free space,
/// and the busiest apps from `ProcessUsageService`, grouped by app as the
/// panel shows them. Read only while a phone has Pocket open, every four
/// seconds; gone from the state the moment it stops watching.
///
/// It also quits one of those apps when the person allows it
/// (`PocketDefaults.allowQuit`): politely, as ⌘Q would, and never Zenith, a
/// part of macOS or a process the phone wasn't shown.
final class PocketHealthPart: PocketPart {
    private var context: PocketPartContext?
    private var sampling = PocketSampling()
    private var timer: Timer?
    private var tick = 0
    private var generation = 0
    private var health: PocketHealth?
    private var top: [PocketHealth.Process] = []
    /// What the phone was shown, for the quit check.
    private var shared: [Int32: PocketQuitRules.Shared] = [:]
    private var disk: (free: Int64, total: Int64)?
    private var readingTop = false
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.pocket.health", qos: .utility)

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
        state.health = health
    }

    func handle(_ command: PocketCommand, id: UUID) -> Bool {
        guard case .quitProcess = command, let plan = PocketMacCommands.plan(command) else { return false }
        switch plan {
        case .quit(let pid): quit(pid, id: id)
        case .refuse(let message): context?.reply(id, false, message)
        default: context?.reply(id, false, PocketMacCommands.badProcess)
        }
        return true
    }

    // MARK: Sampling

    private func apply(_ change: PocketSampling.Change) {
        switch change {
        case .none:
            return
        case .start:
            SystemMonitor.shared.setPocketNeeds(SystemMonitorPanelNeeds(network: true, cpu: true, memory: true,
                                                                        cpuTemperature: true))
            tick = 0
            let timer = Timer(timeInterval: PocketMacCadence.health, repeats: true) { [weak self] _ in self?.sample() }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            sample()
        case .stop:
            SystemMonitor.shared.setPocketNeeds(.none)
            timer?.invalidate(); timer = nil
            generation += 1
            readingTop = false
            top = []
            shared = [:]
            disk = nil
            // Nobody watches: an old reading would only mislead a phone opened later.
            if health != nil {
                health = nil
                context?.changed()
            }
        }
    }

    private func sample() {
        guard sampling.running else { return }
        if tick % PocketMacCadence.diskEvery == 0 { readDisk() }
        if tick % PocketMacCadence.topEvery == 0 { readTop() }
        tick += 1
        publish()
    }

    private func publish() {
        let snapshot = SystemMonitor.shared.snapshot
        let reading = PocketHealthRules.Reading(cpu: snapshot.cpuUsage, temperature: snapshot.cpuTemperature,
                                                memoryUsed: snapshot.memoryUsed, memoryTotal: snapshot.memoryTotal,
                                                diskFree: disk?.free, diskTotal: disk?.total,
                                                down: snapshot.netDownBytesPerSec, up: snapshot.netUpBytesPerSec)
        let next = PocketHealthRules.health(reading, top: top)
        guard next != health else { return }
        health = next
        context?.changed()
    }

    private func readDisk() {
        let generation = self.generation
        queue.async { [weak self] in
            let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
            guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
                  let free = values.volumeAvailableCapacityForImportantUsage,
                  let total = values.volumeTotalCapacity else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else { return }
                self.disk = (free, Int64(total))
            }
        }
    }

    /// The busiest apps, read off the main thread: it walks every process.
    private func readTop() {
        guard !readingTop else { return }
        readingTop = true
        let generation = self.generation
        let interval = PocketMacCadence.health * Double(PocketMacCadence.topEvery)
        queue.async { [weak self] in
            let rows = ProcessUsageService.shared.topCPU(limit: 8, sampleInterval: interval)
            let read = rows.map { row in
                (process: PocketHealth.Process(pid: row.pid, name: row.name, cpu: row.value),
                 startedAt: row.startedAt ?? KillProcessService.startTime(for: row.pid))
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else { return }
                self.readingTop = false
                self.top = PocketHealthRules.busiest(read.map(\.process))
                let starts = Dictionary(read.map { ($0.process.pid, $0.startedAt) }, uniquingKeysWith: { first, _ in first })
                self.shared = Dictionary(uniqueKeysWithValues: self.top.map {
                    ($0.pid, PocketQuitRules.Shared(name: $0.name, startedAt: starts[$0.pid] ?? nil))
                })
                self.publish()
            }
        }
    }

    // MARK: Quitting

    private func quit(_ pid: Int32, id: UUID) {
        let app = NSRunningApplication(processIdentifier: pid)
        let path = app?.executableURL?.path
        let facts = PocketQuitRules.Facts(
            ownPID: ProcessInfo.processInfo.processIdentifier,
            startedAt: KillProcessService.startTime(for: pid),
            isApp: app.map { $0.activationPolicy == .regular && !$0.isTerminated } ?? false,
            bundleID: app?.bundleIdentifier, path: path,
            protectedProcess: KillProcessSupport.isProtected(pid: pid, name: shared[pid]?.name ?? "", path: path ?? ""))
        let allowed = UserDefaults.standard.bool(forKey: PocketDefaults.allowQuit)
        switch PocketQuitRules.verdict(pid: pid, allowed: allowed, shared: shared, facts: facts) {
        case .refuse(let message):
            context?.reply(id, false, message)
        case .quit(let name):
            // ⌘Q: the app may still ask to save, on the Mac, as it should.
            if app?.terminate() == true {
                context?.reply(id, true, PocketQuitRules.asked(name))
            } else {
                context?.reply(id, false, "\(name) didn't take the request to quit.")
            }
        }
    }
}
