// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the island catalog's open island: its pages, Home and the
/// tab bar, the gallery, drops, capture controls, the Command Bar and the
/// lock screen.
@MainActor
extension CatalogShots {
    // MARK: Pages

    static func page(_ module: NotchModule, id: String? = nil, preferences: [String: Any] = [:],
                     settle: TimeInterval = 0.4, setup: @escaping @MainActor () -> Void = {},
                     change: @escaping (inout NotchService.CatalogPose) -> Void = { _ in }) -> CatalogShot {
        CatalogShot(id: id ?? "page-\(module.rawValue)", preferences: preferences, setup: setup, settle: settle) {
            // A preview never turns the camera on or opens the scratchpad's
            // file; Settings draws a still for both, and so does the catalog.
            if module == .camera || module == .scratchpad { return stillPage(module) }
            return island(pose {
                $0.expanded = true
                $0.selected = module
                change(&$0)
            })
        }
    }

    /// The page as Settings previews it (NotchIslandPreview), at full size.
    static func stillPage(_ module: NotchModule) -> (view: AnyView, size: CGSize) {
        let service = NotchService.shared
        service.catalogPose(pose())
        let geometry = service.previewGeometry(for: module)
        let size = service.previewSize(for: module)
        let content = geometry.contentSize(for: size)
        let band = NotchBand(geometry: geometry, contentWidth: content.width)
        let wraps = geometry.pageTop == .wrapsCamera
        let view = NotchPagePreview(module: module, size: content)
            .frame(width: content.width, height: content.height, alignment: .top)
            .clipped()
            .padding(.top, geometry.pageTopInset - geometry.headerTopInset)
            .overlayPreferenceValue(NotchBandKey.self, alignment: .top) { items in
                if geometry.headerRowHeight > 0 {
                    NotchBandRow(band: band) {
                        if !wraps {
                            if band.sectionsButton { NotchSectionsButton(action: {}) }
                            items.leading
                        }
                    } trailing: {
                        items.trailing
                        if band.trailingSectionsButton { NotchSectionsButton(action: {}) }
                    }
                }
            }
            .environment(\.notchBand, band)
            .padding(.horizontal, NotchLayout.horizontalInset)
            .padding(.top, geometry.headerTopInset)
            .padding(.bottom, NotchLayout.bottomInset)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background { NotchShape.island(height: size.height, geometry: geometry).fill(.black) }
            .foregroundStyle(.white)
            .tint(.white)
            .environment(\.notchPresentation, true)
            .environment(\.notchSettingsPreview, true)
        return (AnyView(view), size)
    }

    static var pages: [CatalogShot] {
        typealias S = CatalogSamples
        return [
            page(.controls, id: "page-home") { S.music(); S.timer(); S.calendarCountdown() },
            page(.music, preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.music.rawValue]) { S.music() },
            page(.timer) { S.timer() },
            page(.calendar, preferences: [DefaultsKey.zenithCalendarMode: ZenithCalendarMode.week.rawValue]) { S.calendar() },
            page(.calendar, id: "page-calendar-month",
                 preferences: [DefaultsKey.zenithCalendarMode: ZenithCalendarMode.month.rawValue]) { S.calendar() },
            page(.downloads) { S.downloads() },
            page(.files) { S.shelf() },
            page(.clipboard, preferences: [DefaultsKey.clipboardHistoryEnabled: true]) { S.clipboard() },
            page(.captures),
            page(.notifications) { S.notifications() },
            CatalogShot(id: "page-system", setup: { SystemMonitor.shared.panelDidAppear() },
                        teardown: { SystemMonitor.shared.panelDidDisappear() }, settle: 2.5) {
                island(pose { $0.expanded = true; $0.selected = .system })
            },
            page(.tools),
            page(.mixer),
            page(.scratchpad),
            page(.camera),
            page(.agents) { S.agentsWorking([.claude, .codex]) },
            page(.watch),
            page(.wakatime) { S.wakaTime() },
            page(.vercel) { S.vercelDeployments() },
            page(.github) { S.gitHub() },
            page(.cardImport) { S.cardImport(.copying(totalFiles: 412), page: true) },
            page(.devServers) { S.devServers() },
            page(.recap, settle: 2.5) { S.recap() },
            page(.sky) { S.prayer() },
            page(.git) { S.gitRepository() },
            page(.prompter),
            // Zenith fork: Batteries in both layouts, more devices than fit, and none at all.
            page(.batteries, id: "page-batteries-rings",
                 preferences: [BatteriesDefaults.layout: BatteriesLayout.rings.rawValue]) { S.batteries() },
            page(.batteries, id: "page-batteries-rings-few",
                 preferences: [BatteriesDefaults.layout: BatteriesLayout.rings.rawValue]) {
                S.batteries(Array(BatteriesStore.sample.prefix(3)))
            },
            page(.batteries, id: "page-batteries-list",
                 preferences: [BatteriesDefaults.layout: BatteriesLayout.list.rawValue]) { S.batteries() },
            page(.batteries, id: "page-batteries-empty") { S.batteries([]) },
            page(.controls, id: "page-home-batteries",
                 preferences: [DefaultsKey.zenithHomeLayout: "batteries,timer"]) { S.batteries(); S.timer() },
        ]
    }

    // MARK: Home and its tab bar, the gallery, peeking

    static var home: [CatalogShot] {
        [
            CatalogShot(id: "home-tab-bar", setup: { CatalogSamples.music(); CatalogSamples.timer() }, settle: 0.4) {
                let (island, size) = island(pose { $0.expanded = true; $0.selected = .controls })
                let service = NotchService.shared
                let configuration = ZenithTabBarConfiguration(pins: ZenithTabBarPins(encoded: ZenithTabBar.defaultEncoded),
                                                              currentPage: true)
                let tabs = ZenithIslandDockTabs(layout: ZenithTabBar.layout(configuration, available: service.modules,
                                                                            page: .controls, detail: false),
                                                detail: false)
                let height = size.height + ZenithIslandDockLayout.gap + ZenithIslandDockLayout.height
                    + ZenithIslandDockLayout.bottomMargin
                let view = VStack(spacing: ZenithIslandDockLayout.gap) {
                    island.frame(width: size.width, height: size.height)
                    ZenithIslandDockPill(tabs: tabs, counts: [.files: 3, .notifications: 2]).fixedSize()
                }
                .frame(width: size.width, height: height, alignment: .top)
                return (AnyView(view), CGSize(width: size.width, height: height))
            },
            CatalogShot(id: "home-sections", settle: 0.4) {
                island(pose { $0.expanded = true; $0.showingSections = true })
            },
            CatalogShot(id: "home-peek") { island(pose { $0.peeking = true }) },
        ]
    }

    // MARK: Drops, capture controls and the Command Bar

    static var interactions: [CatalogShot] {
        [
            CatalogShot(id: "drop-hint") { island(pose { $0.dragPlaceholder = true }) },
            CatalogShot(id: "drop-hint-mascot", preferences: [DefaultsKey.notchMascotEnabled: true]) {
                island(pose { $0.dragPlaceholder = true; $0.mascot = true })
            },
            CatalogShot(id: "drop-zones", settle: 0.4) {
                island(pose {
                    $0.expanded = true
                    $0.selected = .files
                    $0.choosingFileDropDestination = true
                    $0.offersFilesDrop = true
                    $0.offersAirDrop = true
                    $0.airDropAvailable = true
                    $0.offersMediaDrop = true
                })
            },
            CatalogShot(id: "capture-controls", settle: 0.3) {
                island(pose {
                    $0.captureControls = ScreenCaptureSelectionOptions(availableTools: ScreenCaptureTool.allCases,
                                                                       selectedTool: .screenshot, showsCaptureMenu: true,
                                                                       controlsInNotch: true)
                })
            },
            CatalogShot(id: "capture-controls-recording", settle: 0.3) {
                island(pose {
                    $0.captureControls = ScreenCaptureSelectionOptions(availableTools: ScreenCaptureTool.allCases,
                                                                       selectedTool: .recording, showsCaptureMenu: true,
                                                                       controlsInNotch: true)
                })
            },
            CatalogShot(id: "capture-controls-collapsed") {
                island(pose {
                    $0.captureControls = ScreenCaptureSelectionOptions(availableTools: ScreenCaptureTool.allCases,
                                                                       selectedTool: .screenshot, showsCaptureMenu: true,
                                                                       controlsInNotch: true)
                    $0.captureControlsCollapsed = true
                })
            },
            CatalogShot(id: "command-bar", settle: 0.5) {
                island(pose { $0.expanded = true; $0.showingCommandBar = true; $0.commandBarHeight = CommandBarView.fieldHeight + 34 })
            },
        ]
    }

    // MARK: Lock screen

    static func lockScreen(_ id: String, mode: ZenithLockScreenPreviewMode, preferences: [String: Any]) -> CatalogShot {
        CatalogShot(id: id, kind: .screen, preferences: preferences, setup: {
            CatalogSamples.music()
            ZenithLockScreenPreviewAssets.shared.catalogPose(
                wallpaper: CatalogSamples.wallpaper,
                account: ZenithLockScreenAccount(name: "Satu Visual", device: "MacBook Pro", photo: nil))
        }, settle: 1.5) {
            let canvas = ZenithLockScreenPreviewAssets.screenSize
            let width: CGFloat = 1440
            let size = CGSize(width: width, height: (width * canvas.height / canvas.width).rounded())
            return (AnyView(ZenithLockScreenPreview(mode: mode)), size)
        }
    }

    static var lockScreens: [CatalogShot] {
        [
            lockScreen("lock-minimal", mode: .minimal, preferences: [:]),
            lockScreen("lock-full", mode: .full, preferences: [:]),
        ]
    }
}
#endif
