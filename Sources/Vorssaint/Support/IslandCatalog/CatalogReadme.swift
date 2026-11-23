// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the README's pictures (`ONLY=readme…`): the island over the
/// sample wallpaper under a sample menu bar, the menu bar panel, and Settings
/// pages in their window. Same sample data and sandbox as the catalog.
@MainActor
extension CatalogShots {
    static var readme: [CatalogShot] { readmeIslands + readmePanels + readmeSettings }

    /// How wide a band of the screen the island pictures show.
    static let bandWidth: CGFloat = 1280

    /// `shot` drawn at the top of a band of the sample wallpaper, under the
    /// sample menu bar (none over the lock screen).
    static func banded(_ id: String, from shot: CatalogShot, menuBar: Bool = true, height: CGFloat? = nil) -> CatalogShot {
        CatalogShot(id: id, kind: .screen, preferences: shot.preferences, setup: shot.setup, teardown: shot.teardown,
                    settle: shot.settle) {
            let (view, size) = shot.draw()
            let band = CGSize(width: bandWidth, height: height ?? (size.height + 56).rounded(.up))
            let composed = ZStack(alignment: .top) {
                CatalogBackdrop(size: band, menuBar: menuBar)
                view.frame(width: size.width, height: size.height)
            }
            .frame(width: band.width, height: band.height, alignment: .top)
            .clipped()
            return (AnyView(composed), band)
        }
    }

    private static func source(_ id: String) -> CatalogShot? {
        (closed + compact + notices + pages + home + interactions + lockScreens + lockIslands).first { $0.id == id }
    }

    static var readmeIslands: [CatalogShot] {
        let menu: [(String, String)] = [
            ("closed-mascot-star", "readme-island-closed"),
            ("compact-music", "readme-island-music"),
            ("compact-timer-downloads", "readme-island-timer"),
            ("compact-agents-two", "readme-island-agents"),
            ("compact-prayer", "readme-island-prayer"),
            ("compact-vercel-building", "readme-island-vercel"),
            ("page-home", "readme-island-home"),
            ("home-tab-bar", "readme-island-tab-bar"),
            ("page-music", "readme-island-player"),
            ("page-calendar-month", "readme-island-calendar"),
            ("page-agents", "readme-island-agents-page"),
            ("page-wakatime", "readme-island-wakatime"),
            ("page-github", "readme-island-github"),
            ("page-vercel", "readme-island-vercel-page"),
            ("page-sky", "readme-island-sky"),
            ("page-files", "readme-island-files"),
            ("page-clipboard", "readme-island-clipboard"),
            ("drop-zones", "readme-island-drop"),
            ("burst-charging", "readme-island-charging"),
            ("burst-prayer", "readme-island-notice-prayer"),
            ("burst-claude", "readme-island-notice-claude"),
            ("notice-volume", "readme-island-notice-volume"),
            ("burst-remote-status", "readme-island-remote-status"),
            ("burst-welcome", "readme-island-welcome"),
        ]
        let lock: [(String, String)] = [
            ("lock-island-face-scanning", "readme-lock-face-scanning"),
            ("lock-island-face-success", "readme-lock-face-success"),
            ("lock-island-welcome", "readme-lock-welcome"),
            ("lock-island-remote", "readme-lock-remote"),
            ("lock-island-music", "readme-lock-music"),
        ]
        let bands = menu.compactMap { from, id in source(from).map { banded(id, from: $0) } }
            + lock.compactMap { from, id in source(from).map { banded(id, from: $0, menuBar: false) } }
        let screens = [
            lockScreen("readme-lock-minimal", mode: .minimal, preferences: [:]),
            lockScreen("readme-lock-full", mode: .full, preferences: [:]),
        ]
        return bands + screens
    }

    // MARK: The menu bar panel

    static var readmePanels: [CatalogShot] {
        [
            panel("readme-panel-keep-awake", section: .keepAwake, height: 470),
            panel("readme-panel-utilities", section: .utilities, height: 960),
            panel("readme-panel-toggles", section: .toggles, height: 700),
            panel("readme-panel-wakatime", section: .wakatime, height: 490) { CatalogSamples.wakaTime() },
        ]
    }

    /// The panel as it opens under its menu bar icon, over the wallpaper.
    static func panel(_ id: String, section: PanelSectionID, height: CGFloat,
                      setup: @escaping @MainActor () -> Void = {}) -> CatalogShot {
        CatalogShot(id: id, kind: .screen, preferences: [DefaultsKey.panelShowWallpaper: false],
                    setup: { setup(); MenuPanelFocus.shared.focus(section) },
                    teardown: { MenuPanelFocus.shared.showNormalPanel() }, settle: 1.2) {
            let size = CGSize(width: 560, height: height)
            let bar = notched.menuBarHeight
            let view = ZStack(alignment: .topTrailing) {
                CatalogBackdrop(size: size, menuBar: true, edge: .trailing)
                MenuPanelView()
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.11)))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12)))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .padding(.top, bar + 8)
                    .padding(.trailing, 150)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipped()
            return (AnyView(view), size)
        }
    }

    // MARK: Settings

    static var readmeSettings: [CatalogShot] {
        typealias S = CatalogSamples
        return [
            settings("readme-settings-general", page: .general),
            settings("readme-settings-island", page: .notch) {
                NotchService.shared.catalogPose(pose())
                S.music(); S.timer(); S.calendarCountdown()
            },
            settings("readme-settings-lock-screen", page: .lockScreen,
                     preferences: [DefaultsKey.notchLockScreen: true], settle: 2) {
                S.music()
                ZenithLockScreenPreviewAssets.shared.catalogPose(
                    wallpaper: S.wallpaper,
                    account: ZenithLockScreenAccount(name: "Satu Visual", device: "MacBook Pro", photo: nil))
            },
            settings("readme-settings-face-unlock", page: .faceUnlock,
                     preferences: [DefaultsKey.faceUnlockEnabled: true, DefaultsKey.faceUnlockNoticeAccepted: true]) {
                FaceUnlockRuntime.shared.session.catalogPose(hasPassword: true)
            },
            settings("readme-settings-remote", page: .remote, preferences: [DefaultsKey.zenithRemoteEnabled: true]) {
                S.remote()
            },
            // Drawn as if covered, so the headline holds its word rather than mid-decrypt.
            settings("readme-settings-about", page: .about, visible: false, settle: 3),
            settings("readme-settings-monitor", page: .monitor),
            CatalogShot(id: "readme-about-credits", settle: 0.4) {
                let size = CGSize(width: 640, height: 250)
                let view = FaceUnlockCredits()
                    .padding(24)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .background(Color(white: 0.09))
                return (AnyView(view), size)
            },
        ]
    }

    /// The Settings window open on `page`, as the app opens it.
    static func settings(_ id: String, page: SettingsPage, preferences: [String: Any] = [:], visible: Bool = true,
                         settle: TimeInterval = 1.5, setup: @escaping @MainActor () -> Void = {}) -> CatalogShot {
        CatalogShot(id: id, kind: .window, preferences: preferences, setup: {
            setup()
            SettingsRouter.shared.page = page
            SettingsWindowVisibility.shared.set(visible)
        }, teardown: {
            SettingsWindowVisibility.shared.set(false)
        }, settle: settle) {
            (AnyView(SettingsView()), CGSize(width: 1000, height: 700))
        }
    }
}

extension CatalogSamples {
    /// iPhone Remote set up with one made-up iPhone and a few requests.
    static func remote() {
        let key = RemotePublicKey(type: "ssh-ed25519", blob: "AAAAC3NzaC1lZDI1NTE5AAAAIC4tGx7QmZ3cSamp1eKeyZen1thR3m0te")
        let readiness = RemoteControlService.Readiness(checking: false, remoteLogin: true, tailscaleInstalled: true,
                                                       tailscale: RemoteTailscale.Status(running: true, host: "studio-mac"),
                                                       host: "studio-mac")
        let log = [
            RemoteControlService.LogEntry(date: now.addingTimeInterval(-4 * 60), device: "Alex’s iPhone", verb: .status,
                                          outcome: .done),
            RemoteControlService.LogEntry(date: now.addingTimeInterval(-38 * 60), device: "Alex’s iPhone", verb: .lock,
                                          outcome: .done),
        ]
        RemoteControlService.shared.catalogPose(running: true, readiness: readiness,
                                                devices: [RemoteDevice(name: "Alex’s iPhone", key: key)], log: log)
    }
}

/// A band of the sample wallpaper from the top of the screen, with a sample
/// menu bar: a made-up app's menus on the left, status items on the right.
struct CatalogBackdrop: View {
    let size: CGSize
    var menuBar = true
    /// Which part of the screen's width the band shows.
    var edge: HorizontalAlignment = .center

    var body: some View {
        let screen = max(CatalogShots.notched.screen.width, size.width)
        let wallpaper = CatalogSamples.wallpaper
        ZStack(alignment: .top) {
            Image(nsImage: wallpaper)
                .resizable()
                .frame(width: screen, height: screen * wallpaper.size.height / wallpaper.size.width)
                .frame(width: size.width, height: size.height, alignment: Alignment(horizontal: edge, vertical: .top))
                .clipped()
            if menuBar { CatalogMenuBar(width: size.width, height: CatalogShots.notched.menuBarHeight, edge: edge) }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

struct CatalogMenuBar: View {
    let width: CGFloat
    let height: CGFloat
    var edge: HorizontalAlignment = .center

    var body: some View {
        HStack(spacing: 0) {
            if edge != .trailing {
                HStack(spacing: 19) {
                    Image(systemName: "apple.logo").font(.system(size: 15, weight: .medium))
                    Text(verbatim: "Finder").fontWeight(.bold)
                    ForEach(["File", "Edit", "View", "Go"], id: \.self) { Text(verbatim: $0) }
                }
                .padding(.leading, 18)
            }
            Spacer(minLength: 0)
            HStack(spacing: 17) {
                if let glyph = BlackHoleGlyph.image(active: false) {
                    Image(nsImage: glyph).renderingMode(.template)
                }
                Image(systemName: "battery.75percent")
                Image(systemName: "wifi")
                Image(systemName: "magnifyingglass")
                Image(systemName: "switch.2")
                Text(verbatim: "Mon Nov 23  9:41 AM")
            }
            .padding(.trailing, 16)
        }
        .font(.system(size: 13.5))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 0.5)
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.14))
    }
}
#endif
