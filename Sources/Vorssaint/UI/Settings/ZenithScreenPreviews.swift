// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the preview cards of the Settings pages about the screen
// (General and the menu bar, the sound tools, Features, Energy, Monitor,
// Switcher, Dock, Window layout, Screen capture, Media, App updates). Each
// picture is the part of the screen the feature changes, drawn on this
// Mac's wallpaper with sample data (ZenithScreenPictures). Where a page holds
// several features, the card starts on the one the page was opened for and
// its picker steps through the others; clicking the outlined part opens the
// settings for it.

/// One picture a card can show.
enum ZenithScreenScene: String, CaseIterable {
    case look, panel, hider
    case mixer, output, priority, musicBlock
    case hub
    case keepAwake, brightness, extraBrightness, bluetoothSleep
    case monitorMenuBar, monitorPanel, fans
    case switcherWindows, switcherIcons, switcherSimple
    case dockPreview, dockClick, spacesOrder
    case snap, maximize
    case screenshot, scrolling, recording, screenText, color
    case mediaVideo, mediaGIF, mediaImage, mediaText
    case updatesPanel, updatesNotice

    var text: ZenithScreenPreviewText {
        let s = ZenithPreviewsScreenStrings.shared
        switch self {
        case .look: return s.look
        case .panel: return s.panel
        case .hider: return s.hider
        case .mixer: return s.mixer
        case .output: return s.output
        case .priority: return s.priority
        case .musicBlock: return s.musicBlock
        case .hub: return s.hub
        case .keepAwake: return s.keepAwake
        case .brightness: return s.brightness
        case .extraBrightness: return s.extraBrightness
        case .bluetoothSleep: return s.bluetoothSleep
        case .monitorMenuBar: return s.monitorMenuBar
        case .monitorPanel: return s.monitorPanel
        case .fans: return s.fans
        case .switcherWindows: return s.switcherWindows
        case .switcherIcons: return s.switcherIcons
        case .switcherSimple: return s.switcherSimple
        case .dockPreview: return s.dockPreview
        case .dockClick: return s.dockClick
        case .spacesOrder: return s.spacesOrder
        case .snap: return s.snap
        case .maximize: return s.maximize
        case .screenshot: return s.screenshot
        case .scrolling: return s.scrolling
        case .recording: return s.recording
        case .screenText: return s.screenText
        case .color: return s.color
        case .mediaVideo: return s.mediaVideo
        case .mediaGIF: return s.mediaGIF
        case .mediaImage: return s.mediaImage
        case .mediaText: return s.mediaText
        case .updatesPanel: return s.updatesPanel
        case .updatesNotice: return s.updatesNotice
        }
    }

    /// The hub feature the picture belongs to; nil for parts of the app.
    var feature: AppFeature? {
        switch self {
        case .look, .panel, .hider, .hub, .monitorMenuBar, .monitorPanel: return nil
        case .mixer: return .mixer
        case .output: return .soundOutputSwitcher
        case .priority: return .audioPriority
        case .musicBlock: return .musicBlock
        case .keepAwake: return .keepAwake
        case .brightness: return .brightness
        case .extraBrightness: return .extraBrightness
        case .bluetoothSleep: return .bluetoothSleep
        case .fans: return .fanControl
        case .switcherWindows, .switcherIcons, .switcherSimple: return .switcher
        case .dockPreview: return .dockPreview
        case .dockClick: return .dockClick
        case .spacesOrder: return .spacesOrder
        case .snap: return .windowLayout
        case .maximize: return .windowMaximizer
        case .screenshot, .scrolling: return .screenshot
        case .recording: return .screenRecorder
        case .screenText: return .screenOCR
        case .color: return .colorPicker
        case .mediaVideo, .mediaGIF, .mediaImage, .mediaText: return .mediaTools
        case .updatesPanel, .updatesNotice: return .appUpdates
        }
    }

    var isAvailable: Bool { feature?.isAvailable ?? true }

    var captureTool: ScreenCaptureTool? {
        switch self {
        case .screenshot: return .screenshot
        case .scrolling: return .scrolling
        case .recording: return .recording
        case .screenText: return .text
        case .color: return .color
        default: return nil
        }
    }

    var mediaTool: MediaTool? {
        switch self {
        case .mediaVideo: return .videoCompressor
        case .mediaGIF: return .gifMaker
        case .mediaImage: return .imageCompressor
        case .mediaText: return .textExtractor
        default: return nil
        }
    }

    init?(captureTool tool: ScreenCaptureTool) {
        guard let scene = Self.allCases.first(where: { $0.captureTool == tool }) else { return nil }
        self = scene
    }

    init?(mediaTool tool: MediaTool) {
        guard let scene = Self.allCases.first(where: { $0.mediaTool == tool }) else { return nil }
        self = scene
    }

    /// Opens the settings for the outlined part: the feature's own section
    /// (its sidebar row on a page of several), the tool on Screen capture and
    /// Media, or the page.
    func open() {
        let router = SettingsRouter.shared
        if let tool = mediaTool {
            UserDefaults.standard.set(tool.rawValue, forKey: DefaultsKey.mediaLastTool)
            return
        }
        if let tool = captureTool {
            router.request(tool.settingsDestination, sidebarFeature: tool.feature)
            return
        }
        switch self {
        case .look, .panel, .hider:
            router.request(FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration))
        case .monitorMenuBar, .monitorPanel:
            router.request(FeatureSettingsDestination(.monitor))
        case .hub:
            router.request(FeatureSettingsDestination(.features))
        default:
            guard let feature else { return }
            router.request(feature.settingsDestination, sidebarFeature: feature)
        }
    }
}

/// The pages with a screen preview, and the pictures each can show.
enum ZenithScreenPreviewGroup: String {
    case general, sound, features, energy, monitor, switcher, dock, windowLayout, screenCapture, media, appUpdates

    /// Keys the folded state: one per page.
    var id: String { "screen.\(rawValue)" }

    var scenes: [ZenithScreenScene] {
        let all: [ZenithScreenScene]
        switch self {
        case .general: all = [.look, .panel, .hider]
        case .sound: all = [.mixer, .output, .priority, .musicBlock]
        case .features: all = [.hub]
        case .energy: all = [.keepAwake, .brightness, .extraBrightness, .bluetoothSleep]
        case .monitor: all = [.monitorMenuBar, .monitorPanel, .fans]
        case .switcher: all = [.switcherWindows, .switcherIcons, .switcherSimple]
        case .dock: all = [.dockPreview, .dockClick, .spacesOrder]
        case .windowLayout: all = [.snap, .maximize]
        case .screenCapture: return ScreenCaptureTool.available().compactMap(ZenithScreenScene.init(captureTool:))
        case .media: all = [.mediaVideo, .mediaGIF, .mediaImage, .mediaText]
        case .appUpdates: all = [.updatesPanel, .updatesNotice]
        }
        return all.filter(\.isAvailable)
    }

    /// The group of a General destination: the sound tools have theirs.
    init(general anchor: SettingsSectionAnchor?) {
        switch anchor {
        case .mixer?, .soundOutputSwitcher?, .audioPriority?, .musicBlocking?: self = .sound
        default: self = .general
        }
    }
}

extension ZenithScreenScene {
    /// The picture for a General destination, or an Energy one.
    init(anchor: SettingsSectionAnchor?) {
        switch anchor {
        case .panelConfiguration?: self = .panel
        case .mixer?: self = .mixer
        case .soundOutputSwitcher?: self = .output
        case .audioPriority?: self = .priority
        case .musicBlocking?: self = .musicBlock
        case .keepAwake?: self = .keepAwake
        case .brightness?: self = .brightness
        case .extraBrightness?: self = .extraBrightness
        case .bluetoothSleep?: self = .bluetoothSleep
        case .fanControl?: self = .fans
        case .dock?: self = .dockPreview
        case .dockClick?: self = .dockClick
        case .spacesOrder?: self = .spacesOrder
        case .windowMaximizer?: self = .maximize
        default: self = .look
        }
    }
}

/// The preview card of a page about the screen.
///
///     ZenithScreenPreviewCard(group: .energy, current: ZenithScreenScene(anchor: focus))
struct ZenithScreenPreviewCard: View {
    let group: ZenithScreenPreviewGroup
    /// The picture the page is on (its sidebar row, tool or layout); nil
    /// follows the section the page was opened on, or starts on the first.
    var current: ZenithScreenScene?
    var aspectRatio: CGFloat = 2.2
    @ObservedObject private var router = SettingsRouter.shared
    /// The picture picked in the card; nil follows the page.
    @State private var picked: ZenithScreenScene?

    var body: some View {
        let scenes = group.scenes
        // Without a scene from the page, the section the page was opened on.
        let routed = ZenithScreenScene(anchor: router.destination.sectionAnchor)
        let shown = [picked, current, routed].compactMap { $0 }.first(where: scenes.contains) ?? scenes.first ?? .look
        ZenithSettingsPreviewCard(
            id: group.id, caption: shown.text.caption, states: scenes.map(\.text.state),
            selection: Binding(get: { scenes.firstIndex(of: shown) ?? 0 },
                               set: { index in picked = scenes.indices.contains(index) ? scenes[index] : nil }),
            highlight: shown.text.part, aspectRatio: aspectRatio
        ) {
            ZenithScreenPicture(scene: shown)
        }
        .onChange(of: current) { _, _ in picked = nil }
        .onChange(of: router.requestID) { _, _ in picked = nil }
    }
}

/// The card as the first section of a grouped Form. It is the section's
/// header, which the Form draws without a background, so the card reads as
/// on the scrolling pages.
struct ZenithScreenPreviewSection: View {
    let group: ZenithScreenPreviewGroup
    var current: ZenithScreenScene?

    var body: some View {
        Section {
            EmptyView()
        } header: {
            ZenithScreenPreviewCard(group: group, current: current)
                .textCase(nil)
                .foregroundStyle(.primary)
                .padding(.bottom, 4)
        }
    }
}
