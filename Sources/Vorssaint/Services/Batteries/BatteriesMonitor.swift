// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import AppKit
import Foundation

/// Zenith fork: runs the Batteries readers and fills `BatteriesStore`.
///
/// It runs while Batteries is on and the island runs (the island follows
/// it through `NotchService.syncWithPreferences`). A scan reads every
/// source on its own queue, off the main thread, with a time limit on each
/// process; overlapping requests share the scan in flight. Between scans
/// there is one one-shot timer and nothing else: every `refreshMinutes`
/// while the page or widget is on screen, every five minutes while it is
/// not and some device can alert, never otherwise. The store, the alert
/// rules and the last-known registry live on the main thread.
final class BatteriesMonitor: ObservableObject {
    static let shared = BatteriesMonitor()

    /// Every device of the last scan in display order, hidden ones included,
    /// so Settings can list a hidden device to show it again. The store's
    /// `devices` leaves those out.
    @Published private(set) var allDevices: [BatteryDevice] = []

    private let store: BatteriesStore
    private let scanQueue = DispatchQueue(label: "id.satuvisual.zenith.batteries.scan", qos: .utility)

    private var running = false
    private var config = BatteriesConfig()
    private var visible = false
    private var timer: DispatchSourceTimer?
    private var startWork: DispatchWorkItem?
    private var scanning = false
    private var rescanAfterScan = false
    private var lastScanAt: Date?
    private var cancellation: BatteriesScanCancellation?
    private var generation = 0
    private var registry: BatteriesRegistry?
    private var savedSignature: String?
    private var savedAt: Date?
    private var symbolAvailability: [String: Bool] = [:]
    private var airPods: BatteriesAirPodsScanner?

    // Used from the scan queue and the iPhone branch of a scan.
    private let batteryService = BatteriesBatteryService()
    private let watch = BatteriesWatchReader()
    private let identityLock = NSLock()
    private var identities: [String: BatteriesReaders.IOSIdentity] = [:]

    /// The first scan waits this long after Batteries starts, so it never
    /// competes with the launch or an unlock.
    private static let startDelay: TimeInterval = 3
    /// A last-seen time alone is written at most this often.
    private static let saveInterval: TimeInterval = 30 * 60
    private static let airPodsWindow: TimeInterval = 4

    init(store: BatteriesStore = .shared) {
        self.store = store
    }

    // MARK: Lifecycle (main thread)

    /// Cheap and idempotent: the island calls it on every preference change.
    func syncWithPreferences() {
        let next = BatteriesConfig.current()
        guard next.enabled else { stop(); return }
        guard running else {
            config = next
            start()
            return
        }
        guard next != config else { return }
        let readersChanged = next.readerSignature != config.readerSignature
        let filterChanged = next.hidden != config.hidden || next.muted != config.muted
        config = next
        updateAirPodsScanner()
        if filterChanged { publish(allDevices) }
        if readersChanged { requestScan(followUp: true) } else { reschedule() }
    }

    /// Batteries turned off or the island stopped: nothing keeps running
    /// and the store empties.
    func stop() {
        let wasActive = running || !store.devices.isEmpty || store.refreshHandler != nil
        pause()
        guard wasActive else { return }
        store.refreshHandler = nil
        store.visibilityHandler = nil
        airPods?.stop()
        airPods = nil
        allDevices = []
        store.devices = []
        store.lastUpdated = nil
        store.pendingLowAlert = nil
        store.iOSTools = .unknown
    }

    /// The island went away for a while (lock, sleep): scans stop, the last
    /// readings stay for when it returns.
    func suspend() {
        pause()
    }

    private func pause() {
        running = false
        generation += 1
        startWork?.cancel(); startWork = nil
        timer?.cancel(); timer = nil
        cancellation?.cancel(); cancellation = nil
        scanning = false
        rescanAfterScan = false
        if store.isRefreshing { store.isRefreshing = false }
    }

    private func start() {
        running = true
        store.refreshHandler = { [weak self] in
            Self.onMain { self?.refreshNow() }
        }
        store.visibilityHandler = { [weak self] visible in
            Self.onMain { self?.setVisible(visible) }
        }
        updateAirPodsScanner()
        if registry == nil { loadRegistry() }
        let work = DispatchWorkItem { [weak self] in
            self?.startWork = nil
            self?.requestScan()
        }
        startWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startDelay, execute: work)
    }

    private static func onMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread { body() } else { DispatchQueue.main.async(execute: body) }
    }

    func refreshNow() {
        guard running else { return }
        startWork?.cancel(); startWork = nil
        requestScan()
    }

    func setVisible(_ visible: Bool) {
        guard self.visible != visible else { return }
        self.visible = visible
        guard running else { return }
        if visible, startWork == nil,
           lastScanAt.map({ Date().timeIntervalSince($0) > BatteriesSchedule.freshEnough }) ?? true {
            requestScan()
        } else {
            reschedule()
        }
    }

    private func updateAirPodsScanner() {
        if config.airPodsScanning, BatteriesBluetoothAccess.isDeclared {
            if airPods == nil { airPods = BatteriesAirPodsScanner() }
        } else {
            airPods?.stop()
            airPods = nil
        }
    }

    // MARK: Schedule

    private func reschedule() {
        timer?.cancel(); timer = nil
        guard running, !scanning, startWork == nil else { return }
        let shown = allDevices.filter { !config.hidden.contains($0.id) }
        guard let interval = BatteriesSchedule.interval(
            enabled: config.enabled, visible: visible, refreshMinutes: config.refreshMinutes,
            canAlert: BatteriesSchedule.canAlert(shown, muted: config.muted)) else { return }
        let delay = BatteriesSchedule.delay(interval: interval, lastScanAt: lastScanAt, now: Date())
        let timer = DispatchSource.makeTimerSource(queue: .main)
        // A tenth of the interval of slack lets macOS group the wake-up
        // with others.
        timer.schedule(deadline: .now() + delay, repeating: .never,
                       leeway: .seconds(max(1, Int(interval / 10))))
        timer.setEventHandler { [weak self] in
            self?.timer = nil
            self?.requestScan()
        }
        self.timer = timer
        timer.resume()
    }

    // MARK: Scan

    /// A scan in flight answers every request made meanwhile; `followUp`
    /// asks for one more after it (a reader was switched on or off).
    private func requestScan(followUp: Bool = false) {
        guard running else { return }
        if scanning {
            if followUp { rescanAfterScan = true }
            return
        }
        beginScan()
    }

    private func beginScan() {
        timer?.cancel(); timer = nil
        scanning = true
        store.isRefreshing = true
        lastScanAt = Date()
        let config = self.config
        let generation = self.generation
        let cancellation = BatteriesScanCancellation()
        self.cancellation = cancellation
        let airPods = self.airPods
        scanQueue.async { [weak self] in
            guard let self else { return }
            let result = self.scan(config: config, airPods: airPods, cancellation: cancellation)
            DispatchQueue.main.async { [weak self] in
                self?.finish(result, generation: generation)
            }
        }
    }

    private struct ScanResult {
        var devices: [BatteryDevice]
        var tools: BatteriesIOSToolsStatus
        var date: Date
    }

    /// The scan queue's part: every reader, then one combined list.
    private func scan(config: BatteriesConfig, airPods: BatteriesAirPodsScanner?,
                      cancellation: BatteriesScanCancellation) -> ScanResult? {
        guard !cancellation.isCancelled else { return nil }
        let airPodsDone = DispatchSemaphore(value: 0)
        if let airPods {
            airPods.scanBriefly(seconds: Self.airPodsWindow) { airPodsDone.signal() }
        } else {
            airPodsDone.signal()
        }

        // The iPhone side runs beside the Bluetooth readers.
        let toolsInstalled = BatteriesReaders.iOSToolsInstalled
        final class AppleBox: @unchecked Sendable { var devices: [BatteryDevice] = [] }
        let apple = AppleBox()
        let appleDone = DispatchGroup()
        if config.readIOSDevices, toolsInstalled {
            DispatchQueue.global(qos: .utility).async(group: appleDone) { [weak self] in
                guard let self else { return }
                apple.devices = self.readApple(cancellation: cancellation)
            }
        }

        var inputs = BatteriesScanInputs()
        inputs.mac = BatteriesReaders.mac()
        inputs.bluetooth = BatteriesReaders.bluetooth(cancellation: cancellation)
        inputs.accessories = BatteriesReaders.accessories()
        inputs.powerSources = BatteriesReaders.powerSources()
        if !cancellation.isCancelled, BatteriesMerge.needsBatteryService(inputs, now: Date()) {
            inputs.gattLevels = batteryService.read()
        }
        // Past these limits a reader is not waited for: its devices show
        // their last known levels until the next scan.
        if appleDone.wait(timeout: .now() + 40) == .success { inputs.apple = apple.devices }
        _ = airPodsDone.wait(timeout: .now() + Self.airPodsWindow + 2)
        if let airPods { inputs.airPods = airPods.sightings(maxAge: BatteriesMerge.airPodsLevelMaxAge) }
        guard !cancellation.isCancelled else { return nil }

        let tools: BatteriesIOSToolsStatus
        if !toolsInstalled {
            tools = .missing
        } else {
            // The library is loaded only while iPhone reading is on.
            tools = .installed(watchSupport: config.readIOSDevices ? watch.isAvailable : BatteriesWatchReader.isInstalled)
        }
        let now = Date()
        return ScanResult(devices: BatteriesMerge.combine(inputs, now: now), tools: tools, date: now)
    }

    private func readApple(cancellation: BatteriesScanCancellation) -> [BatteryDevice] {
        identityLock.lock()
        var known = identities
        identityLock.unlock()
        let (devices, listed) = BatteriesReaders.iOSDevices(identities: &known, cancellation: cancellation)
        identityLock.lock()
        identities.merge(known) { _, new in new }
        identityLock.unlock()
        guard !cancellation.isCancelled else { return devices }
        // Only an iPhone pairs with a watch.
        let phones = listed.filter { known[$0.udid]?.productType.map { $0.hasPrefix("iPhone") } ?? true }
        return devices + watch.read(iPhones: phones)
    }

    // MARK: Results (main thread)

    private func finish(_ result: ScanResult?, generation: Int) {
        guard generation == self.generation, running else { return }
        scanning = false
        cancellation = nil
        store.isRefreshing = false
        if let result { apply(result) }
        if rescanAfterScan {
            rescanAfterScan = false
            beginScan()
        } else {
            reschedule()
        }
    }

    private func apply(_ result: ScanResult) {
        var registry = self.registry ?? BatteriesRegistry()
        // Reconciled before deduplicating, or the dropped copy would come
        // back from the registry as a missing device.
        let reconciled = registry.reconcile(current: result.devices, now: result.date)
        let devices = BatteriesMerge.ordered(BatteriesMerge.deduplicated(reconciled)).map { device -> BatteryDevice in
            var device = device
            device.symbolOverride = BatteriesSymbols.override(for: device, isAvailable: symbolIsAvailable)
            return device
        }
        let shown = devices.filter { !config.hidden.contains($0.id) }
        var alerted = registry.alerted
        let alert = BatteriesAlerts.evaluate(shown, threshold: config.threshold, muted: config.muted, alerted: &alerted)
        registry.alerted = alerted
        self.registry = registry

        publish(devices)
        store.lastUpdated = result.date
        if store.iOSTools != result.tools { store.iOSTools = result.tools }
        if let alert { store.pendingLowAlert = alert }
        save(registry, now: result.date)
    }

    private func publish(_ devices: [BatteryDevice]) {
        if allDevices != devices { allDevices = devices }
        let shown = devices.filter { !config.hidden.contains($0.id) }
        if store.devices != shown { store.devices = shown }
    }

    private func symbolIsAvailable(_ name: String) -> Bool {
        if let known = symbolAvailability[name] { return known }
        let available = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        symbolAvailability[name] = available
        return available
    }

    // MARK: Last known, on disk

    private static var registryURL: URL? {
        PrivateFileStore.containerURL?
            .appendingPathComponent("Batteries", isDirectory: true)
            .appendingPathComponent("last-known.json")
    }

    private func loadRegistry() {
        guard let url = Self.registryURL else { registry = BatteriesRegistry(); return }
        scanQueue.async { [weak self] in
            let loaded = BatteriesRegistry.decode(try? Data(contentsOf: url))
            DispatchQueue.main.async {
                guard let self, self.registry == nil else { return }
                self.registry = loaded
                self.savedSignature = loaded.persistenceSignature
            }
        }
    }

    private func save(_ registry: BatteriesRegistry, now: Date) {
        let signature = registry.persistenceSignature
        guard signature != savedSignature || savedAt.map({ now.timeIntervalSince($0) > Self.saveInterval }) ?? true,
              let url = Self.registryURL, let data = registry.encoded() else { return }
        savedSignature = signature
        savedAt = now
        scanQueue.async {
            guard PrivateFileStore.createDirectory(at: url.deletingLastPathComponent()) else { return }
            PrivateFileStore.write(data, to: url)
        }
    }
}
