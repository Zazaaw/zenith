// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import Foundation

/// Static identity of the app, shared by UI, notifications and tooling.
///
/// Zenith fork: every brand value lives here. Zenith is based on Vorssaint;
/// the GPL requires that attribution to stay visible (see `copyright`).
enum AppInfo {
    static let name = "Zenith"
    static let maker = "Satu Visual"
    static let copyright = "© 2026 Satu Visual · Based on Vorssaint © 2026 Vorssaint"
    static let websiteURL = URL(string: "https://p441z-satuvisual.vercel.app")!
    static let repositoryURL = URL(string: "https://github.com/satuvisual/zenith")!
    /// `owner/repo` on GitHub, used by the update check.
    static let repositorySlug = "satuvisual/zenith"
    /// Zenith has no donation, Discord or social channel yet; UI hides what is nil.
    static let coffeeURL: URL? = nil
    static let discordURL: URL? = nil
    static let socialURL: URL? = nil

    static let bundleIdentifier = "id.satuvisual.zenith"
    static let developerBundleIdentifier = "id.satuvisual.zenith.dev"

    /// Off until Zenith publishes its own signed releases. The upstream updater
    /// verifies Vorssaint's Developer ID, so pointing it anywhere else would only fail,
    /// and pointing it at upstream would replace Zenith with the official Vorssaint.
    static let updatesEnabled = false
    /// Zenith runs no feedback or sharing service yet. Nil keeps feedback from
    /// leaving the Mac; sharing uploads go to a reserved `.invalid` host (RFC 2606)
    /// that never resolves, so nothing reaches Vorssaint's servers.
    static let feedbackEndpoint: URL? = nil
    static let sharingEndpoint = URL(string: "https://sharing.zenith.invalid")!

    /// The bundle version. The fallback only applies to the bare binary
    /// (e.g. `--selftest`), never the shipped app, which reads its Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// True for the local "Vorssaint (Developer)" build (bundle id ends in `.dev`).
    /// It is never published and never auto-updates; all work is tested here first.
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }

    /// True when the current version is a pre-release (e.g. 3.3.4-beta.1 or 3.3.4-rc.1).
    static var isBeta: Bool {
        if isDeveloperBuild && UserDefaults.standard.bool(forKey: DefaultsKey.simulateBetaUI) {
            return true
        }
        let v = version.lowercased()
        return v.contains("-beta") || v.contains("-rc") || v.contains("-alpha")
    }

    /// The git commit a Developer build was compiled from, e.g. "ed2ebba · 2026-06-15 21:30"
    /// (or with a "-dirty" suffix on the SHA for uncommitted changes). build.sh stamps
    /// this into the Developer bundle only, so you can confirm at a glance that the
    /// running dev app matches the source you are about to change. nil in the official app.
    static var buildCommit: String? {
        Bundle.main.object(forInfoDictionaryKey: "VorssaintBuildCommit") as? String
    }
}
