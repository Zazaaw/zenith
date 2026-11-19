// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreLocation
import EventKit

/// Zenith fork: where the lock screen's weather and reminders stand with
/// their macOS permission. Reading a status never asks for one.
enum LockScreenWidgetAccess: Equatable {
    case notDetermined, denied, granted

    /// macOS grants location as "always"; the iOS "when in use" status
    /// (raw value 4) is unavailable to name here but counts as granted too.
    init(location status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways: self = .granted
        case .notDetermined: self = .notDetermined
        case .denied, .restricted: self = .denied
        default: self = status.rawValue == 4 ? .granted : .denied
        }
    }

    /// Reading reminders takes full access; write-only access cannot read them.
    init(reminders status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess: self = .granted
        case .notDetermined: self = .notDetermined
        case .denied, .restricted, .writeOnly: self = .denied
        @unknown default: self = .denied
        }
    }
}
