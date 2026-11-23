// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: which devices warn and which are hidden, as Settings → Batteries
/// writes them (`BatteriesDefaults.mutedDeviceIDs` and `.hiddenDeviceIDs`).
///
/// The Mac's own alert is off until it is turned on: Zenith already shows its
/// own low battery notice for the Mac. That default lives in the muted list
/// itself, so there is no second key: while `mutedDeviceIDs` has never been
/// written it reads as `["mac"]`, and every write keeps the Mac's state, so
/// turning the Mac on is the list without "mac". The monitor reads the list
/// through `isMuted` (or with the same `?? defaultMuted`).
enum BatteriesDevicePreferences {
    /// The Mac's id in `BatteriesStore.devices`.
    static let macID = "mac"
    /// The muted list before anything was turned on or off.
    static let defaultMuted = [macID]
    /// The names of hidden devices, so Settings can list them for showing
    /// again while the monitor leaves them out of `BatteriesStore.devices`.
    /// Settings' own: the monitor never reads it.
    static let hiddenNamesKey = "zenithBatteriesHiddenDeviceNames" // [String: String]

    static func muted(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: BatteriesDefaults.mutedDeviceIDs) ?? defaultMuted)
    }

    static func isMuted(_ id: String, in defaults: UserDefaults = .standard) -> Bool {
        muted(in: defaults).contains(id)
    }

    /// Turns one device's alert on or off, keeping every other device's.
    static func setAlert(_ on: Bool, for id: String, in defaults: UserDefaults = .standard) {
        var ids = muted(in: defaults)
        if on { ids.remove(id) } else { ids.insert(id) }
        defaults.set(ids.sorted(), forKey: BatteriesDefaults.mutedDeviceIDs)
    }

    static func hidden(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: BatteriesDefaults.hiddenDeviceIDs) ?? [])
    }

    /// The names Settings remembered for hidden devices, by id.
    static func hiddenNames(in defaults: UserDefaults = .standard) -> [String: String] {
        defaults.dictionary(forKey: hiddenNamesKey) as? [String: String] ?? [:]
    }

    /// Hides a device, or shows it again. Its name is kept while it is hidden.
    static func setHidden(_ hide: Bool, id: String, name: String?, in defaults: UserDefaults = .standard) {
        var ids = hidden(in: defaults)
        var names = hiddenNames(in: defaults)
        if hide {
            ids.insert(id)
            if let name, !name.isEmpty { names[id] = name }
        } else {
            ids.remove(id)
            names[id] = nil
        }
        defaults.set(ids.sorted(), forKey: BatteriesDefaults.hiddenDeviceIDs)
        if names.isEmpty {
            defaults.removeObject(forKey: hiddenNamesKey)
        } else {
            defaults.set(names, forKey: hiddenNamesKey)
        }
    }

    /// The devices of the Devices section (everything but iPhone, iPad and
    /// Apple Watch) and of the iPhone & Apple Watch one, hidden ones left out.
    static func split(_ devices: [BatteryDevice], hidden: Set<String>)
        -> (accessories: [BatteryDevice], mobile: [BatteryDevice]) {
        let shown = devices.filter { !hidden.contains($0.id) }
        return (shown.filter { !isMobile($0.kind) }, shown.filter { isMobile($0.kind) })
    }

    static func isMobile(_ kind: BatteryDeviceKind) -> Bool {
        kind == .iphone || kind == .ipad || kind == .watch
    }

    /// The hidden devices to list for showing again: a name from the store
    /// when the device is still there, else the one remembered, else its id.
    static func hiddenRows(_ devices: [BatteryDevice], hidden: Set<String>, names: [String: String])
        -> [(id: String, name: String)] {
        hidden.sorted().map { id in
            (id, devices.first(where: { $0.id == id })?.name ?? names[id] ?? id)
        }
    }

    /// A device's mono caption: "BLUETOOTH · 45%, charging" or
    /// "BLUETOOTH · 45%, last seen 2 h ago". The Apple Watch says it is read
    /// through the iPhone instead of when it was seen.
    static func caption(_ device: BatteryDevice, text: ZenithBatteriesStrings, now: Date = Date()) -> String {
        var level = levelText(device, text: text)
        if device.isCharging {
            level += ", " + text.charging
        } else if device.fullyCharged {
            level += ", " + text.full
        }
        if let since = device.unreachableSince {
            level += ", " + text.time(text.lastSeen, text.ago(now.timeIntervalSince(since)))
        } else if device.kind == .watch {
            level += " · " + text.watchCaption
        }
        return source(device.source, text: text).uppercased() + " · " + level
    }

    private static func levelText(_ device: BatteryDevice, text: ZenithBatteriesStrings) -> String {
        if let percent = device.percent { return "\(percent)%" }
        guard !device.components.isEmpty else { return text.noLevel }
        return device.components.map { "\($0.label) \($0.percent)%" }.joined(separator: " ")
    }

    static func source(_ source: BatterySource, text: ZenithBatteriesStrings) -> String {
        switch source {
        case .builtIn: return text.builtIn
        case .bluetooth: return text.bluetooth
        case .usb: return text.usb
        case .wifi: return text.wifi
        case .viaIPhone: return text.viaIPhone
        }
    }
}
