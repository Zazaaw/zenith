// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AVFoundation
import Foundation

// Zenith fork: the island's Camera page starts its mirror as it appears once
// camera access is allowed, instead of waiting for "Open camera". Without
// access yet the button still asks first; denied, the page keeps upstream's
// guidance. The camera stops on the same terms as before: leaving the page
// or closing the island (CameraPreviewService.hideEmbedded).
//
// The test executable compiles this file (build.sh, TEST_SOURCES): keep it
// free of anything outside Foundation and AVFoundation.

enum ZenithCameraAutoStart {
    /// The live preview fades in from this blur (points), sharp at the end.
    static let blur: CGFloat = 10
    static let revealDuration: Double = 0.32
    /// A session that takes longer than this shows a quiet spinner; a quick
    /// one never flashes it.
    static let loadingDelay: Double = 0.15

    /// The "Start the mirror automatically" switch, on unless turned off.
    static func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: DefaultsKey.notchCameraAutoStart) as? Bool ?? true
    }

    /// Whether the page starts the mirror by itself as it appears: only with
    /// access already granted, so a page never raises the permission prompt
    /// on its own, and only once per appearance (`attempted`), so stopping
    /// the mirror by hand leaves it stopped.
    static func startsOnAppear(status: AVAuthorizationStatus, isOn: Bool, attempted: Bool) -> Bool {
        isOn && !attempted && status == .authorized
    }

    /// The same, for the camera access this Mac has granted now. Asking
    /// never shows the permission prompt.
    static func startsOnAppear(isOn: Bool, attempted: Bool) -> Bool {
        // Checked last, as the page draws: the switch and the visit decide first.
        guard isOn, !attempted else { return false }
        return startsOnAppear(status: AVCaptureDevice.authorizationStatus(for: .video), isOn: isOn, attempted: attempted)
    }
}
