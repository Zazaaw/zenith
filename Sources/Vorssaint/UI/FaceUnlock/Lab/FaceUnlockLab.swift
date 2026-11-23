// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance.

import AppKit
import SwiftUI

/// Zenith fork: Face Lab, Glance's hidden debug tab, as its own window. The
/// face unlock settings page opens it with `FaceUnlockLab.open()`. The camera
/// runs only while the window is open and the user starts it.
@MainActor
enum FaceUnlockLab {
    /// What Face Lab asks the onboarding to start (Glance's Start Onboarding,
    /// Add Identity and Recapture buttons).
    enum EnrollmentRequest: Equatable {
        case fullOnboarding
        case addIdentity
        case recapture(UUID, name: String)
    }

    /// Set by the onboarding; while nil, Face Lab's guided enrollment buttons are disabled.
    static var enrollmentHandler: ((EnrollmentRequest) -> Void)?

    private static var window: NSWindow?
    private static var controller: FaceLabController?
    private static let windowDelegate = WindowDelegate()

    static func open() {
        guard FaceUnlockRecognition.isSupported else { return }
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let controller = FaceLabController()
        let host = NSHostingController(rootView: FaceLabView(controller: controller))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Face Lab"
        window.contentViewController = host
        window.isReleasedWhenClosed = false
        window.setContentSize(CGSize(width: 720, height: 820))
        window.center()
        window.delegate = windowDelegate
        self.window = window
        self.controller = controller
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    static func close() {
        window?.close()
    }

    fileprivate static func windowWillClose() {
        controller?.stop()
        controller = nil
        window?.contentViewController = nil
        window = nil
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            MainActor.assumeIsolated { FaceUnlockLab.windowWillClose() }
        }
    }
}
