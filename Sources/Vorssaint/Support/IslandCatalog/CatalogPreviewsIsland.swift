// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the preview cards of the island's and Zenith's own Settings
/// pages (`ONLY=readme-previews-island`): each page in its window as it
/// opens, and the card alone in each of its other states.
@MainActor
extension CatalogShots {
    static var previewsIsland: [CatalogShot] {
        typealias S = CatalogSamples
        let prefix = "readme-previews-island-"
        let pages: [CatalogShot] = [
            settings(prefix + "notch", page: .notch, height: 900),
            settings(prefix + "notch-activity", page: .notch, height: 900) {
                SettingsRouter.shared.request(FeatureSettingsDestination(notch: .activity))
            },
            settings(prefix + "notch-content", page: .notch, height: 900) {
                SettingsRouter.shared.request(FeatureSettingsDestination(notch: .module(.calendar)))
            },
            settings(prefix + "notch-behavior", page: .notch, height: 900) {
                SettingsRouter.shared.request(FeatureSettingsDestination(notch: .behavior))
            },
            settings(prefix + "mascot", page: .notch, preferences: [DefaultsKey.notchMascotEnabled: true],
                     height: 900) {
                // The companion's tile in the Modules grid, scrolled to.
                SettingsRouter.shared.request(FeatureSettingsDestination(notch: .companion))
            },
            settings(prefix + "lock-screen", page: .lockScreen, preferences: [DefaultsKey.notchLockScreen: true],
                     settle: 2, height: 900) {
                S.music()
                ZenithLockScreenPreviewAssets.shared.catalogPose(
                    wallpaper: S.wallpaper,
                    account: ZenithLockScreenAccount(name: "Satu Visual", device: "MacBook Pro", photo: nil))
            },
            settings(prefix + "face-unlock", page: .faceUnlock, height: 900),
            settings(prefix + "remote", page: .remote, height: 900),
            settings(prefix + "batteries", page: .batteries, height: 900),
            settings(prefix + "batteries-alerts", page: .batteries, height: 900) {
                SettingsRouter.shared.request(FeatureSettingsDestination(.batteries, sectionAnchor: .zenithBatteriesAlerts))
            },
            settings(prefix + "shelf", page: .shelf, preferences: [DefaultsKey.shelfEnabled: true], height: 900),
            settings(prefix + "workspaces", page: .workspaces, height: 900),
            settings(prefix + "command-bar", page: .commandBar, height: 900),
        ]
        let text = ZenithPreviewsIslandStrings.shared
        let cards: [CatalogShot] = [
            card(prefix + "card-face-success", states: [text.faceScanning, text.faceSuccess, text.faceFailure], state: 1) {
                ZenithLockIslandPicture(face: .success) {}
            },
            card(prefix + "card-face-failure", states: [text.faceScanning, text.faceSuccess, text.faceFailure], state: 2) {
                ZenithLockIslandPicture(face: .failure(.wrongFace)) {}
            },
            card(prefix + "card-remote-status", states: [text.remoteLocked, text.remoteStatus], state: 1) {
                ZenithRemotePreviewCardStatusPicture()
            },
            card(prefix + "card-batteries-compact", states: [text.batteriesPage, text.batteriesLow, text.batteriesCompact],
                 state: 2) {
                ZenithBatteriesPreviewCard(state: .constant(ZenithBatteriesPreviewCard.compact), openLook: {}, openAlerts: {})
            },
            card(prefix + "card-batteries-low", states: [text.batteriesPage, text.batteriesLow, text.batteriesCompact],
                 state: 1) {
                ZenithBatteriesPreviewCard(state: .constant(ZenithBatteriesPreviewCard.low), openLook: {}, openAlerts: {})
            },
            card(prefix + "card-shelf-airdrop", states: [text.shelfFiles, text.shelfAirDrop], state: 1) {
                ZenithShelfDropPicture(targets: [.files, .airDrop, .transform], landing: .airDrop) {}
            },
            card(prefix + "card-notch-companion", states: [text.notchCompanion], state: 0,
                 preferences: [DefaultsKey.notchMascotEnabled: true]) {
                ZenithMascotPicture {}
            },
        ]
        return pages + cards
    }

    /// One state of a card drawn alone at a Settings page's width.
    private static func card<Picture: View>(_ id: String, states: [String], state: Int,
                                            preferences: [String: Any] = [:],
                                            @ViewBuilder picture: @escaping @MainActor () -> Picture) -> CatalogShot {
        CatalogShot(id: id, kind: .screen, preferences: preferences, settle: 1) {
            let size = CGSize(width: 760, height: 330)
            let view = Group {
                // A card already in its own card draws as it is.
                if Picture.self == ZenithBatteriesPreviewCard.self {
                    picture()
                } else {
                    ZenithSettingsPreviewCard(id: "catalog", caption: "", states: states, selection: .constant(state),
                                              highlight: states[state]) { picture() }
                }
            }
            .padding(20)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(Color(white: 0.12))
            return (AnyView(view), size)
        }
    }
}

/// The remote card's Status picture, for the catalog.
private struct ZenithRemotePreviewCardStatusPicture: View {
    var body: some View {
        let content = ZenithIslandBurst.Content.remote(ZenithRemoteBurst(device: ZenithPreviewsIslandStrings.shared.remoteDevice))
        ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: ZenithPreviewBurstIsland.size(content).width,
                                                                           minimum: 640)) {
            ZenithPreviewBurstIsland(content).zenithPreviewPart(cornerRadius: 18, highlighted: true) {}
        }
    }
}
#endif
