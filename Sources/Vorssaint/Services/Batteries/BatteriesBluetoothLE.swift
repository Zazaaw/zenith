// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import CoreBluetooth
import Foundation

/// Zenith fork: the two Batteries readers that use CoreBluetooth.
///
/// Neither ever asks for Bluetooth on its own: the Battery Service read
/// runs only once Zenith already holds Bluetooth access (the menu bar's
/// peripheral battery asks for it), and the AirPods scan only while the
/// user has turned AirPods scanning on, which is when the prompt belongs.
enum BatteriesBluetoothAccess {
    static var isGranted: Bool { CBManager.authorization == .allowedAlways }

    /// The bundle declares why it uses Bluetooth; without that, TCC ends a
    /// process that touches CoreBluetooth (the test runner, a bare binary).
    static var isDeclared: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil
    }
}

/// The standard BLE Battery Service (0x180F / 0x2A19) of connected
/// accessories macOS gives no level for elsewhere, through the same
/// time-boxed read the menu bar's peripheral battery uses. Blocking; call
/// from the scan queue.
final class BatteriesBatteryService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.batteries.ble", qos: .utility)
    /// Belongs to `queue`: the read keeps its central only while it is held.
    private var reader: PeripheralBluetoothReading?

    /// Levels by `BatteriesNames.key`, or empty after `timeout`.
    func read(timeout: TimeInterval = 6) -> [String: Int] {
        guard BatteriesBluetoothAccess.isDeclared, BatteriesBluetoothAccess.isGranted else { return [:] }
        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var levels: [String: Int] = [:]
        }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let cancellation = BoundedProcessCancellation()
        queue.async { [weak self] in
            guard let self else { done.signal(); return }
            let reader = BluetoothBatteryRead(queue: self.queue, cancellation: cancellation) { [weak self] readings in
                box.lock.lock()
                for reading in readings where (1...100).contains(reading.percent) {
                    box.levels[BatteriesNames.key(reading.name)] = reading.percent
                }
                box.lock.unlock()
                self?.reader = nil
                done.signal()
            }
            self.reader = reader
            reader.start()
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            queue.async { [weak self] in
                self?.reader?.cancel()
                self?.reader = nil
            }
            return [:]
        }
        box.lock.lock(); defer { box.lock.unlock() }
        return box.levels
    }
}

/// Listens for AirPods proximity broadcasts in short windows and keeps the
/// latest per advertised name, in memory only. Runs only while AirPods
/// scanning is on: continuous scanning has a power cost.
final class BatteriesAirPodsScanner: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "id.satuvisual.zenith.batteries.airpods", qos: .utility)
    // Belong to `queue`.
    private var central: CBCentralManager?
    private var scanning = false
    private var stopWork: DispatchWorkItem?
    private var waiting: [() -> Void] = []

    private let lock = NSLock()
    private var latest: [String: BatteriesAirPodsSighting] = [:]

    /// Listens for `seconds`, then calls `completion` on the scanner's queue.
    func scanBriefly(seconds: TimeInterval, completion: @escaping () -> Void) {
        guard BatteriesBluetoothAccess.isDeclared else { completion(); return }
        queue.async { [self] in
            if central == nil {
                central = CBCentralManager(delegate: self, queue: queue,
                                           options: [CBCentralManagerOptionShowPowerAlertKey: false])
            }
            scanning = true
            waiting.append(completion)
            startIfReady()
            stopWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.endWindow() }
            stopWork = work
            queue.asyncAfter(deadline: .now() + max(0, seconds), execute: work)
        }
    }

    /// Readings heard within `maxAge`, by advertised name.
    func sightings(maxAge: TimeInterval, now: Date = Date()) -> [String: BatteriesAirPodsSighting] {
        lock.lock(); defer { lock.unlock() }
        latest = latest.filter { now.timeIntervalSince($0.value.date) <= maxAge }
        return latest
    }

    /// Stops listening, drops the central and forgets every reading.
    func stop() {
        queue.async { [self] in
            stopWork?.cancel()
            stopWork = nil
            scanning = false
            central?.stopScan()
            central?.delegate = nil
            central = nil
            let pending = waiting
            waiting.removeAll()
            pending.forEach { $0() }
        }
        lock.lock(); latest.removeAll(); lock.unlock()
    }

    private func endWindow() {
        stopWork = nil
        scanning = false
        central?.stopScan()
        let pending = waiting
        waiting.removeAll()
        pending.forEach { $0() }
    }

    private func startIfReady() {
        guard scanning, let central, central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        startIfReady()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard scanning,
              let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let battery = BatteriesAirPodsProximity.decode(manufacturerData: manufacturer) else { return }
        // An advert without a real name cannot be told apart from a
        // stranger's AirPods, so it is skipped.
        guard let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String),
              !name.isEmpty else { return }
        // 127 means CoreBluetooth had no RSSI for this packet.
        let rssi = RSSI.intValue == 127 ? Int.min : RSSI.intValue
        lock.lock()
        latest[name] = BatteriesAirPodsSighting(battery: battery, date: Date(), rssi: rssi)
        lock.unlock()
    }
}
