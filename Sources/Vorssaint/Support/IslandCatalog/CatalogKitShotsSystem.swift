// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the System and Apps pages rebuilt with the Settings kit, for
/// `ONLY=kit…` beside the kit's own pages (CatalogKitShots).
@MainActor
extension CatalogShots {
    static var kitSystemPages: [(String, SettingsPage, [String: Any], CGFloat)] {
        [
            ("system-monitor", .monitor, [DefaultsKey.menuBarCPU: true, DefaultsKey.menuBarMemory: true,
                                          DefaultsKey.menuBarNetwork: true], 2600),
            ("fan-control", .fanControl, [AppFeature.fanControl.availabilityKey: true], 900),
            ("sleep", .sleep, [AppFeature.keepAwake.availabilityKey: true,
                               AppFeature.bluetoothSleep.availabilityKey: true,
                               DefaultsKey.bluetoothSleepEnabled: true], 2000),
            ("brightness", .brightness, [AppFeature.brightness.availabilityKey: true,
                                         AppFeature.extraBrightness.availabilityKey: true,
                                         DefaultsKey.brightnessControlEnabled: true], 1500),
            ("menu-bar", .menuBar, [DefaultsKey.menuBarHiderEnabled: true], 2000),
            ("command-bar", .commandBar, [AppFeature.commandBar.availabilityKey: true,
                                          DefaultsKey.commandBarShortcutEnabled: true], 2800),
            ("cleaner", .cleaner, [AppFeature.cleaner.availabilityKey: true], 1300),
            ("uninstaller", .uninstaller, [AppFeature.uninstaller.availabilityKey: true], 1300),
            ("homebrew", .homebrew, [AppFeature.homebrew.availabilityKey: true], 1400),
            ("app-updates", .appUpdates, [AppFeature.appUpdates.availabilityKey: true], 1500),
            ("kill-process", .killProcess, [AppFeature.killProcess.availabilityKey: true], 1300),
            ("port-manager", .portManager, [AppFeature.portManager.availabilityKey: true], 1200),
        ]
    }
}
#endif
