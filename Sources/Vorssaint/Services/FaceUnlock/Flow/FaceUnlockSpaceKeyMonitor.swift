// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Foundation
import IOKit.hid

/// Zenith fork: Space on the lock screen, for the "On space" trigger
/// (Glance's `SpaceKeyMonitor`). Secure Event Input hides every keyboard
/// event tap there, so this reads the keyboards through IOKit HID, which
/// needs Input Monitoring (macOS resolves it through Accessibility first,
/// which Zenith has for typing the password).
///
/// Not a keylogger: it runs only while the screen is locked with the trigger
/// on, and its callback looks at one thing, whether the key is the spacebar
/// going down. Access is asked for only when the trigger is turned on.
final class FaceUnlockSpaceKeyMonitor: FaceUnlockSpaceKeyListening {
    enum Access: Equatable { case granted, denied, notDetermined }

    static var access: Access {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .notDetermined
        }
    }

    /// The system prompt, at most once; afterwards only System Settings can
    /// change it. Called from Settings when "On space" is turned on.
    @discardableResult
    static func requestAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    var hasAccess: Bool { Self.access == .granted }

    private var manager: IOHIDManager?
    private var onPress: (() -> Void)?

    func start(_ onPress: @escaping () -> Void) {
        self.onPress = onPress
        guard manager == nil, hasAccess else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Physical keyboards only.
        let match: [String: Int] = [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                                    kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        // The C callback carries no captures; `self` rides in the context,
        // unretained, which is safe because `stop()` always runs first.
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            let element = IOHIDValueGetElement(value)
            guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad),
                  IOHIDElementGetUsage(element) == UInt32(kHIDUsage_KeyboardSpacebar),
                  IOHIDValueGetIntegerValue(value) == 1 else { return }
            // Scheduled on the main run loop, so this is the main thread.
            Unmanaged<FaceUnlockSpaceKeyMonitor>.fromOpaque(context).takeUnretainedValue().onPress?()
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            return
        }
        self.manager = manager
    }

    func stop() {
        onPress = nil
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    deinit { stop() }
}
