// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance
// (NotchSkyLight.swift, itself from Lakr233/SkyLightWindow, MIT).

import AppKit

/// Zenith fork: the one Space the lock screen's windows are drawn in, over
/// the lock screen itself, as Glance draws its island there. It is created
/// once, the first time the lock screen needs it, shown at the level of the
/// notifications macOS draws over the lock screen, and kept for the app's
/// lifetime: never destroyed per lock, so nothing is torn down while macOS
/// fades its shield out at an unlock. Windows join it (delegate) only while
/// the session is actually locked, and leave it (undelegate) as they go.
///
/// The symbols are private SkyLight ones, resolved at runtime; without them
/// there is no Space, and nothing shows on the lock screen.
final class ZenithLockScreenSpace {
    private typealias MainConnection = @convention(c) () -> UInt32
    private typealias SpaceCreate = @convention(c) (UInt32, Int32, CFDictionary?) -> UInt64
    private typealias SpaceSetLevel = @convention(c) (UInt32, UInt64, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (UInt32, CFArray) -> Int32
    private typealias AddAndRemove = @convention(c) (UInt32, UInt64, CFArray, Int32) -> Int32
    private typealias RemoveWindows = @convention(c) (UInt32, CFArray, CFArray) -> Int32

    /// Created on first use and kept; nil when SkyLight offers no such Space.
    static let shared: ZenithLockScreenSpace? = ZenithLockScreenSpace()

    private let connection: UInt32
    private let space: UInt64
    private let addAndRemove: AddAndRemove
    private let removeWindows: RemoveWindows
    private var delegated = Set<Int>()

    private init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
              let main = dlsym(handle, "SLSMainConnectionID"), let create = dlsym(handle, "SLSSpaceCreate"),
              let level = dlsym(handle, "SLSSpaceSetAbsoluteLevel"), let show = dlsym(handle, "SLSShowSpaces"),
              let add = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces"),
              let remove = dlsym(handle, "SLSRemoveWindowsFromSpaces") else {
            ZenithLockTrace.log("space unavailable: SkyLight symbols missing")
            return nil
        }
        let connection = unsafeBitCast(main, to: MainConnection.self)()
        guard connection != 0 else { return nil }
        // Any flag but 1 makes Finder draw the desktop icons in this Space.
        let space = unsafeBitCast(create, to: SpaceCreate.self)(connection, ZenithLockScreenWindow.spaceFlag, nil)
        guard space != 0 else {
            ZenithLockTrace.log("space create failed")
            return nil
        }
        let levelResult = unsafeBitCast(level, to: SpaceSetLevel.self)(connection, space, NotchLockScreenSupport.spaceLevel)
        let showResult = unsafeBitCast(show, to: ShowSpaces.self)(connection, [NSNumber(value: space)] as CFArray)
        self.connection = connection
        self.space = space
        addAndRemove = unsafeBitCast(add, to: AddAndRemove.self)
        removeWindows = unsafeBitCast(remove, to: RemoveWindows.self)
        ZenithLockTrace.log("space created id=\(space) level=\(NotchLockScreenSupport.spaceLevel) (\(levelResult))"
                            + " shown (\(showResult))")
    }

    /// The session server's own answer, not a notification any process can
    /// post: whether the screen is locked now. False when it cannot say.
    static func screenIsLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    /// Moves `window` into this Space, out of every other, so it is drawn over
    /// the lock screen. Only while the screen is actually locked; false
    /// otherwise, or when the window has no number yet.
    @discardableResult
    func delegate(_ window: NSWindow, name: String) -> Bool {
        guard window.windowNumber > 0 else { return false }
        guard Self.screenIsLocked() else {
            ZenithLockTrace.log("delegate \(name) deferred: session not locked yet")
            return false
        }
        guard !delegated.contains(window.windowNumber) else { return true }
        let result = addAndRemove(connection, space, [NSNumber(value: window.windowNumber)] as CFArray,
                                  ZenithLockScreenWindow.removedSpaces)
        delegated.insert(window.windowNumber)
        ZenithLockTrace.log("delegate \(name) window=\(window.windowNumber) level=\(window.level.rawValue) (\(result))")
        return true
    }

    /// Takes `window` back out of this Space, before it is ordered out.
    func undelegate(_ window: NSWindow, name: String) {
        guard window.windowNumber > 0, delegated.remove(window.windowNumber) != nil else { return }
        let result = removeWindows(connection, [NSNumber(value: window.windowNumber)] as CFArray,
                                   [NSNumber(value: space)] as CFArray)
        ZenithLockTrace.log("undelegate \(name) window=\(window.windowNumber) (\(result))")
    }

    func holds(_ window: NSWindow) -> Bool { window.windowNumber > 0 && delegated.contains(window.windowNumber) }
}
