// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import EventKit

/// Zenith fork: the lock screen's weather and reminders follow the lock screen.
///
/// `NotchLockScreenService` asks here whether each may show (its switch is on
/// and its permission granted), starts them as the lock screen appears and
/// stops them as it goes. It calls in on the main thread, where it builds its
/// windows. Nothing here ever asks for a permission.
enum NotchLockScreenWidgets {
    static func showsWeather() -> Bool {
        // The switch first, so a Mac with Weather off never touches Location Services.
        NotchLockScreenItem.weather.isOn()
            && MainActor.assumeIsolated { WeatherService.shared.refreshAccess() == .granted }
    }

    static func showsReminders() -> Bool {
        NotchLockScreenItem.reminders.isOn()
            && LockScreenWidgetAccess(reminders: EKEventStore.authorizationStatus(for: .reminder)) == .granted
    }

    static func start(weather: Bool, reminders: Bool) {
        MainActor.assumeIsolated {
            if weather {
                WeatherService.shared.lockScreenShown()
                Running.weather = true
            }
            if reminders {
                RemindersService.shared.lockScreenShown()
                Running.reminders = true
            }
        }
    }

    static func stop() {
        MainActor.assumeIsolated {
            if Running.weather {
                WeatherService.shared.lockScreenHidden()
                Running.weather = false
            }
            if Running.reminders {
                RemindersService.shared.lockScreenHidden()
                Running.reminders = false
            }
        }
    }
}

@MainActor
private enum Running {
    static var weather = false
    static var reminders = false
}
