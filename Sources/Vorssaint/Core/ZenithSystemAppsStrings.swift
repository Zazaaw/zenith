// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the new words of the System and Apps pages rebuilt with the
// Settings kit (System Monitor, Fan Control, Sleep, Brightness, Menu Bar,
// Command Bar, Cleaner, Uninstaller, Homebrew, App Updates, Kill Process,
// Port Manager): page titles the split made, section titles, hero subtitles
// and chips the old pages never had. English in every language, like the
// rest of Zenith's own chrome; the settings themselves keep their localized
// labels.

struct ZenithSystemAppsStrings {
    // System Monitor.
    let monitorTitle = "System Monitor"
    let monitorSubtitle = "CPU, memory, network, disk and power at a glance, in the menu bar and its panel."
    let monitorMetrics = "Metrics"
    let monitorMetricsFooter = "Each metric’s switch installs or removes it, as in Orbit. Click a metric for its options."
    let monitorInMenuBar = "In the menu bar"
    let monitorMenuBar = "Menu bar"
    let monitorPanel = "Panel"
    let monitorReadings = "Readings"
    let monitorOrder = "Order in the menu bar"
    let monitorMetricOff = "This metric is off. Switch it on to show it in the menu bar and the panel."
    let monitorTurnOn = "Turn On"
    let monitorValuesDetail = "Numbers, such as CPU 42%."
    let monitorBarsDetail = "A small gauge for CPU, GPU, memory and disk."
    let monitorConnectedDevices = "Devices"
    func monitorShown(_ count: Int) -> String { count == 1 ? "1 in the menu bar" : "\(count) in the menu bar" }
    func monitorEvery(_ seconds: Int) -> String { "Every \(seconds) s" }
    func monitorOn(_ count: Int) -> String { count == 1 ? "1 metric" : "\(count) metrics" }

    // Fan Control.
    let fanSubtitle = "Watch the fans and set them quiet or cool by temperature, from the menu bar panel."
    let fanPanel = "In the panel"
    let fanBeta = "Beta"
    let fanNoFans = "No fans"

    // Sleep.
    let sleepTitle = "Sleep"
    let sleepSubtitle = "Keep the Mac awake for as long as you need, and switch Bluetooth off while it sleeps."
    let sleepSession = "Keep awake"
    let sleepDuration = "Default duration"
    let sleepAutomation = "Starts by itself"
    let sleepOptions = "Options"
    let sleepMenuBarIcon = "Menu bar icon"
    let sleepBluetooth = "Bluetooth on sleep"
    let sleepAwake = "Awake"
    let sleepNormal = "Normal sleep"
    let sleepBluetoothOff = "Bluetooth off on sleep"

    // Brightness.
    let brightnessTitle = "Brightness"
    let brightnessSubtitle = "Set every display’s brightness, its speakers’ volume, and push XDR panels past their limit."
    let brightnessDisplays = "Displays"
    let brightnessKeys = "Keys"
    let brightnessExtra = "Extra brightness"
    func brightnessDisplayCount(_ count: Int) -> String { count == 1 ? "1 display" : "\(count) displays" }
    let brightnessExtraOn = "XDR boost on"

    // Menu Bar.
    let menuBarTitle = "Menu Bar"
    let menuBarSubtitle = "The panel behind Zenith’s icon, the icon itself, and the hider that tucks other icons away."
    let menuBarPanel = "Panel"
    let menuBarIcon = "Icon"
    let menuBarHider = "Menu bar hider"
    let menuBarHiderOn = "Hider on"
    let menuBarHow = "How it works"
    let menuBarZenithIcon = "Zenith icon"
    func menuBarTabs(_ count: Int) -> String { count == 1 ? "1 tab" : "\(count) tabs" }

    // Command Bar.
    let commandSubtitle = "Find apps, windows, files, settings and answers, and run actions, from one bar."
    let commandBar = "The bar"
    let commandSearch = "What it searches"
    let commandFiles = "Files"
    let commandSaved = "Saved"
    let commandTry = "Try"
    func commandSources(_ count: Int) -> String { count == 1 ? "1 source" : "\(count) sources" }

    // Cleaner.
    let cleanerSubtitle = "Find caches, logs and leftovers that are safe to remove, and clean them in one click."
    let cleanerWorkspace = "Scan"
    let cleanerTool = "Tool"

    // Uninstaller.
    let uninstallerSubtitle = "Remove an app with the files it leaves behind: support files, caches, preferences."
    let uninstallerWorkspace = "Remove an app"
    let uninstallerOptions = "Options"
    let uninstallerDrop = "Drop an app"

    // Homebrew.
    let homebrewSubtitle = "Search, install, update and remove casks and formulas without the Terminal."
    let homebrewWorkspace = "Packages"
    let homebrewMissing = "Not installed"
    func homebrewInstalled(_ count: Int) -> String { count == 1 ? "1 package" : "\(count) packages" }
    func homebrewUpdates(_ count: Int) -> String { count == 1 ? "1 update" : "\(count) updates" }

    // App Updates.
    let updatesSubtitle = "See which apps have an update, from Homebrew, the App Store and their own feeds."
    let updatesList = "Updates"
    let updatesChecking = "Checking"
    let updatesSchedule = "Checking"
    let updatesSources = "Sources"
    func updatesCount(_ count: Int) -> String { count == 1 ? "1 update" : "\(count) updates" }
    let updatesUpToDate = "Up to date"

    // Kill Process.
    let killSubtitle = "Every running process with its CPU and memory, to quit, force quit or restart."
    let killList = "Processes"
    let killOptions = "Options"
    func killCount(_ count: Int) -> String { count == 1 ? "1 process" : "\(count) processes" }

    // Port Manager.
    let portsSubtitle = "Which process listens on which port, and the way to stop it."
    let portsList = "Listening ports"
    func portsCount(_ count: Int) -> String { count == 1 ? "1 port" : "\(count) ports" }

    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func systemApps(_ language: AppLanguage) -> ZenithSystemAppsStrings {
        ZenithSystemAppsStrings()
    }
}
