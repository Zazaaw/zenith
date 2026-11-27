// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the test run is quiet, and every alert beep goes through
/// `ZenithQuiet`, so a test that provokes a failure on purpose never beeps on
/// the owner's Mac.
enum ZenithQuietTests {
    static func run(_ suite: TestSuite) {
        suite.expect(ZenithQuiet.isOn, "the test run is quiet")

        let root = URL(fileURLWithPath: "Sources/Vorssaint")
        var offenders: [String] = []
        if let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let file as URL in files where file.pathExtension == "swift"
                && file.lastPathComponent != "ZenithQuiet.swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                if text.contains("NSSound.beep()") { offenders.append(file.lastPathComponent) }
            }
        }
        suite.expect(offenders.isEmpty, "alert beeps go through ZenithQuiet.beep(), not NSSound.beep(): \(offenders)")
    }
}
