// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: every state the island catalog draws, in catalog order. The
/// ids are the PNG names the PDF script (Tools/IslandCatalog) looks up.
@MainActor
enum CatalogShots {
    /// What every shot starts from: the island on, in English, nothing resting.
    static let basePreferences: [String: Any] = {
        var values: [String: Any] = [
        DefaultsKey.language: AppLanguage.enUS.rawValue,
        DefaultsKey.notchEnabled: true,
        DefaultsKey.notchIdleContent: NotchIdleContent.none.rawValue,
        DefaultsKey.notchMascotEnabled: false,
        DefaultsKey.notchLiquidGlassEnabled: false,
        DefaultsKey.notchMusicActivity: true,
        DefaultsKey.notchKeepAwakeActivity: true,
        DefaultsKey.notchCalendarCountdown: true,
        DefaultsKey.notchAgentsEnabled: true,
        DefaultsKey.notchTimerEnabled: true,
        ]
        for event in NotchEvent.allCases { values[event.preferenceKey] = true }
        return values
    }()

    static var all: [CatalogShot] { closed + compact + notices + pages + home + interactions + lockScreens + lockIslands }

    // MARK: Geometry

    /// This Mac's camera when it has one, else a 14-inch MacBook Pro's.
    static let notched: NotchGeometry = {
        var geometry: NotchGeometry
        if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let bar = screen.frame.maxY - screen.visibleFrame.maxY
            geometry = NotchGeometry(screen: CGRect(origin: .zero, size: screen.frame.size),
                                     safeAreaTop: screen.safeAreaInsets.top, cameraWidth: max(0, right.minX - left.maxX),
                                     layout: .spacious, menuBarHeight: bar > 0 ? bar : screen.safeAreaInsets.top)
        } else {
            geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                     cameraWidth: 185, layout: .spacious, menuBarHeight: 32)
        }
        geometry.compactSideRoom = 280
        return geometry
    }()

    /// A display without a camera, where the island floats as a capsule.
    static let capsule: NotchGeometry = {
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0, cameraWidth: 0,
                                     layout: .spacious, menuBarHeight: 24, silhouette: .capsule, barEdge: 0.5)
        geometry.compactSideRoom = 280
        return geometry
    }()

    // MARK: Drawing

    /// The island as the window host draws it: the black silhouette and NotchView over it.
    static func island(_ pose: NotchService.CatalogPose) -> (view: AnyView, size: CGSize) {
        let service = NotchService.shared
        service.catalogPose(pose)
        let size = service.surfaceSize
        let shift = service.surfaceShift
        let width = size.width + abs(shift) * 2
        let shape = NotchShape.island(height: size.height, geometry: service.geometry)
        let view = ZStack(alignment: .top) {
            shape.fill(Color.black)
                .frame(width: size.width, height: size.height)
                .offset(x: shift)
            NotchView(service: service)
                .frame(width: width, height: size.height, alignment: .top)
        }
        .frame(width: width, height: size.height, alignment: .top)
        .environment(\.notchSettingsPreview, true)
        return (AnyView(view), CGSize(width: width, height: size.height))
    }

    static func pose(_ change: (inout NotchService.CatalogPose) -> Void = { _ in }) -> NotchService.CatalogPose {
        var pose = NotchService.CatalogPose(geometry: notched)
        change(&pose)
        return pose
    }

    static func power(_ percent: Int, charging: Bool = false, plugged: Bool = false) -> PowerReading {
        var reading = PowerReading()
        reading.chargePercent = percent
        reading.isCharging = charging
        reading.externalConnected = plugged || charging
        reading.hasBattery = true
        return reading
    }

    // MARK: Closed and resting

    static var closed: [CatalogShot] {
        [
            CatalogShot(id: "closed-idle") { island(pose()) },
            CatalogShot(id: "closed-mascot-star", preferences: [DefaultsKey.notchMascotEnabled: true,
                                                                 DefaultsKey.notchMascotStyle: NotchMascotStyle.satuVisual.rawValue]) {
                island(pose { $0.mascot = true })
            },
            CatalogShot(id: "closed-mascot-minimal", preferences: [DefaultsKey.notchMascotEnabled: true,
                                                                    DefaultsKey.notchMascotStyle: NotchMascotStyle.minimal.rawValue,
                                                                    DefaultsKey.notchMascotPalette: NotchMascotPalette.peach.rawValue]) {
                island(pose { $0.mascot = true })
            },
            CatalogShot(id: "closed-mascot-robot", preferences: [DefaultsKey.notchMascotEnabled: true,
                                                                  DefaultsKey.notchMascotStyle: NotchMascotStyle.robot.rawValue,
                                                                  DefaultsKey.notchMascotSide: NotchMascotSide.right.rawValue]) {
                island(pose { $0.mascot = true; $0.mascotSide = .right })
            },
            CatalogShot(id: "closed-battery",
                        preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.battery.rawValue]) {
                island(pose { $0.power = power(76) })
            },
            CatalogShot(id: "closed-battery-charging",
                        preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.battery.rawValue]) {
                island(pose { $0.power = power(54, charging: true) })
            },
            CatalogShot(id: "closed-battery-early",
                        preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.battery.rawValue,
                                      DefaultsKey.notchLowBatteryTint: true, DefaultsKey.notchLowBatteryEarly: true]) {
                island(pose { $0.power = power(18) })
            },
            CatalogShot(id: "closed-battery-low",
                        preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.battery.rawValue,
                                      DefaultsKey.notchLowBatteryTint: true]) {
                island(pose { $0.power = power(9) })
            },
            CatalogShot(id: "closed-capsule-battery",
                        preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.battery.rawValue,
                                      DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue]) {
                island(pose { $0.geometry = capsule; $0.power = power(76) })
            },
        ]
    }

    // MARK: Compact activities

    /// A closed island showing whatever `setup` posed.
    static func activity(_ id: String, preferences: [String: Any] = [:], inside: Bool = false,
                         activity: NotchCompactActivity? = nil, companion: NotchCompactActivity? = nil,
                         geometry: NotchGeometry? = nil, setup: @escaping @MainActor () -> Void) -> CatalogShot {
        CatalogShot(id: id, preferences: preferences, setup: setup) {
            island(pose {
                if let geometry { $0.geometry = geometry }
                $0.inside = inside
                $0.activity = activity
                $0.companion = companion
            })
        }
    }

    /// The island rests with the song: the song then shows as an activity.
    static let music: [String: Any] = [DefaultsKey.notchIdleContent: NotchIdleContent.music.rawValue]

    static var compact: [CatalogShot] {
        typealias S = CatalogSamples
        return [
            activity("compact-music", preferences: music) { S.music() },
            activity("compact-music-capsule", preferences: music.merging([DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue]) { $1 },
                     geometry: capsule) { S.music() },
            activity("compact-timer") { S.timer() },
            activity("compact-timer-capsule", preferences: [DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue],
                     geometry: capsule) { S.timer() },
            activity("compact-timer-downloads", activity: .timer, companion: .downloads) { S.timer(); S.downloads() },
            activity("compact-downloads") { S.downloads() },
            activity("compact-agents") { S.agentsWorking() },
            activity("compact-agents-two") { S.agentsWorking([.claude, .codex]) },
            activity("compact-claude-needs-you") { S.claudeNeedsYou() },
            activity("compact-calendar") { S.calendarCountdown() },
            activity("compact-keep-awake") { S.keepAwake() },
            activity("compact-vercel-building") { S.vercel(.building(project: "satuvisual-web", count: 1)) },
            activity("compact-vercel-ready") { S.vercel(.result(project: "satuvisual-web", state: .ready)) },
            activity("compact-vercel-failed") { S.vercel(.result(project: "satuvisual-web", state: .error)) },
            activity("compact-command-running") { S.command(S.runningCommand) },
            activity("compact-command-finished") { S.command(S.finishedCommand) },
            activity("compact-card-import") { S.cardImport(.copying(totalFiles: 412)) },
            activity("compact-card-import-done") { S.cardImport(.finished(files: 412, bytes: 48_000_000_000)) },
            activity("compact-backup") { S.cardImport(.backup(.running(.verifying, totalFiles: 412))) },
            activity("compact-export") { S.export() },
            activity("compact-export-done") { S.export(finished: true) },
            activity("compact-dev-servers") { S.devServers() },
            activity("compact-prayer") { S.prayer() },
            activity("compact-prayer-arrived") { S.prayer(arrived: true) },
            activity("compact-golden-hour") { S.golden() },
            activity("compact-git") { S.gitBranch() },
            activity("compact-battery-low") { S.batteryLow() }, // Zenith fork
            activity("compact-battery-low-headphones") { S.batteryLow("sample-headphones") }, // Zenith fork
            activity("compact-battery-low-capsule", preferences: [DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue],
                     geometry: capsule) { S.batteryLow() }, // Zenith fork
            activity("compact-picker", preferences: music, inside: true) { S.timer(); S.music(); S.downloads(); S.gitBranch() },
        ]
    }
}
#endif
