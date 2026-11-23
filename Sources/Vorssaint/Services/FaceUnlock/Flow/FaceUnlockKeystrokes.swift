// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import ApplicationServices
import CoreGraphics
import Foundation

/// Zenith fork: types the stored password into the lock screen (Glance's
/// `KeystrokeInjector`). Keyboard events are posted at the HID tap, the only
/// place the login window's secure field reads them from, which needs
/// Accessibility. Called only by `FaceUnlockSession.typeStoredPassword`,
/// after its CGSession check; never by anything else.
final class FaceUnlockKeystrokes: FaceUnlockPasswordTyping {
    var canType: Bool { AXIsProcessTrusted() }

    /// Clears the field, types the UTF-8 password, presses Return. Takes
    /// bytes so the caller can zero them; the brief String lives only here.
    func type(_ password: Data) throws {
        guard canType else { throw FaceUnlockSecurityError.accessibility }
        guard let text = String(data: password, encoding: .utf8), !text.isEmpty else {
            throw FaceUnlockSecurityError.typingFailed
        }
        let source = CGEventSource(stateID: .hidSystemState)
        try clearField(source)
        try postText(text, source)
        try postKey(Self.returnKey, source: source)
    }

    private static let returnKey: CGKeyCode = 0x24
    private static let rightArrow: CGKeyCode = 0x7C
    private static let delete: CGKeyCode = 0x33
    private static let command: CGKeyCode = 0x37
    private static let keyGap: TimeInterval = 0.012
    /// Quartz delivers only a short Unicode payload per event reliably.
    private static let batchLength = 20
    private static let batchGap: TimeInterval = 0.004

    /// ⌘→ then ⌘⌫, positional keys on every layout (unlike ⌘A), so a stray
    /// key pressed on the lock screen is not typed in front of the password.
    private func clearField(_ source: CGEventSource?) throws {
        try postKey(Self.rightArrow, command: true, source: source)
        try postKey(Self.delete, command: true, source: source)
    }

    private func postKey(_ key: CGKeyCode, command: Bool = false, source: CGEventSource?) throws {
        if command {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: Self.command, keyDown: true) else {
                throw FaceUnlockSecurityError.typingFailed
            }
            down.flags = .maskCommand
            down.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: Self.keyGap)
        }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            throw FaceUnlockSecurityError.typingFailed
        }
        let flags: CGEventFlags = command ? .maskCommand : []
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: Self.keyGap)
        up.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: Self.keyGap)
        if command {
            guard let release = CGEvent(keyboardEventSource: source, virtualKey: Self.command, keyDown: false) else {
                throw FaceUnlockSecurityError.typingFailed
            }
            release.flags = []
            release.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: Self.keyGap)
        }
    }

    /// Unicode events, so the keyboard layout does not matter; batches never
    /// split a surrogate pair.
    private func postText(_ text: String, _ source: CGEventSource?) throws {
        for batch in Self.batches(Array(text.utf16), length: Self.batchLength) {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                throw FaceUnlockSecurityError.typingFailed
            }
            batch.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
                up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            }
            down.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: Self.batchGap)
            up.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: Self.batchGap)
        }
    }

    /// UTF-16 split into runs of at most `length`, never between a high and a
    /// low surrogate.
    static func batches(_ units: [UInt16], length: Int) -> [[UInt16]] {
        var result: [[UInt16]] = []
        var start = 0
        while start < units.count {
            var end = min(start + max(length, 2), units.count)
            if end < units.count, (0xD800...0xDBFF).contains(units[end - 1]) { end -= 1 }
            result.append(Array(units[start..<end]))
            start = end
        }
        return result
    }
}
