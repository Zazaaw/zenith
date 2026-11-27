// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The Settings pages. Lives here (without SwiftUI) so the visibility rules
/// below and the unit tests can reason about pages without pulling UI in.
enum SettingsPage: Hashable, CaseIterable {
    case general, features, monitor
    case switcher, dock, keyDebounce, superKey, finderTools, autoQuit, quitProtection, cleaner, uninstaller, urlCleaner, homebrew, appUpdates, media, clipboard, windowLayout, shelf, textSnippets, screenshot, radialMenu, commandBar, killProcess, portManager, notch, notchMascot
    case shortcuts, advanced, about, releaseNotes, support
    case workspaces // Zenith fork: part of the app, no hub feature gates it
    case lockScreen // Zenith fork: the island's lock screen, a page of its own
    case remote // Zenith fork: lock and check status from an iPhone, a page of its own
    case pocket // Zenith fork: Zenith Pocket, the iPhone and Watch companion, beside iPhone Remote
    case faceUnlock // Zenith fork: unlock by looking at the Mac, a page of its own
    case batteries // Zenith fork: every device's battery and when to warn, under Monitor
    case translate // Zenith fork: translate a selection on this Mac, a page of its own
    case meetings // Zenith fork: calls from the calendar, Join and the mic, beside the lock screen
    case mechakey // Zenith fork: mechanical keyboard sounds as you type, a page of its own
    case appearance // Zenith fork: how the island moves and what it is made of, a sidebar tile
    case scrolling, pointer, mouseButtons // Zenith fork: the Mouse page, one page per job
    case spaces // Zenith fork: Spaces in a fixed order, apart from the Dock
    case quickLauncher, quickToggles, quitApps, cleaningMode, wallpaper, scratchpad // Zenith fork: Quick Tools, one page each
    case removeBackground, emojiPicker, calculator // Zenith fork: Orbit wave 2, pages of their own
    // Zenith fork: the island's sections with options of their own, each a page in the Island group.
    case notchCalendar, notchNotifications, notchMusic, notchTimer, notchAgents, notchDownloads, notchWatch
    // Zenith fork: the System group's pages split out of Energy, Monitor and General.
    case sleep, brightness, fanControl, menuBar
    // Zenith fork: the sound tools, a page each (they were sections of General and Quick Tools).
    case volumeMixer, soundOutput, musicBlocker, micMute
    // Zenith fork: the capture tools, a page each (Screen capture and Quick Tools were split).
    case screenRecording, textCapture, colorPicker, cameraPreview
}

/// Stable, non-localized identities for destinations inside shared Settings
/// pages. Raw values may be persisted or used by UI identifiers, so cases can
/// be added but never renamed.
enum SettingsSectionAnchor: String, CaseIterable, Hashable {
    case panelConfiguration
    case mixer
    case audioPriority
    case musicBlocking
    case keepAwake
    case brightness
    case extraBrightness
    case bluetoothSleep
    case scrollDirection
    case scrollZoom
    case focusFollowsMouse
    case smoothScroll
    case linearScroll
    case scrollSpeed
    case mouseAcceleration
    case mouseNavigation
    case mouseButtonShortcuts
    case middleClick
    case mouseClickDebounce
    case switcher
    case dock
    case dockClick
    case spacesOrder
    case finderCutPaste
    case finderRename
    case clipboardHistory
    case pastePlain
    case quickLauncher
    case quickToggles
    case quitApps
    case screenshot
    case screenshotScrolling
    case screenRecorder
    case colorPicker
    case screenOCR
    case micMute
    case cameraPreview
    case wallpaper
    case scratchpad
    case cleaningMode
    case soundOutputSwitcher
    case keyboardBrightnessShortcuts
    case fanControl
    case monitorAlerts
    case windowMaximizer
    case diskImageInstaller // Zenith fork: its prompt's remembered choices, on Finder Tools
    // Zenith fork: the fork's own sections, which Settings search lands on
    // (ZenithSettingsSearch). Their raw values all start with "zenith".
    case zenithWakaTime, zenithVercel, zenithGitHub, zenithCardImport, zenithDevServers, zenithGit, zenithSky, zenithRecap, zenithPrompter
    case zenithClaudeHooks, zenithCardBackup, zenithPrayerTimes, zenithGoldenHour, zenithCameraAutoStart, zenithReply
    case zenithLockScreen, zenithCommandActivity, zenithExportTracker, zenithNotices, zenithTabBar
    case zenithDropZones, zenithWatermark, zenithDesignOverlay, zenithBeautify, zenithQR, zenithMenuBarHider
    case zenithLockScreenTerminal, zenithLockScreenLyrics, zenithLockScreenMusic
    case zenithRemote
    case zenithPocket, zenithPocketRelay, zenithPocketPairing, zenithPocketSharing, zenithPocketWatchtower
    case zenithFaceUnlock
    case zenithBatteries, zenithBatteriesAlerts, zenithBatteriesIPhone
    case zenithTranslate, zenithTranslateLanguages, zenithTranslateDownloads
    case zenithMeetings, zenithMeetingsCalls, zenithMeetingsProviders // Zenith fork
    case zenithMechakey, zenithMechakeyRepeat // Zenith fork: the repeat switch sits under More options
    case zenithAppearanceTheme, zenithAppearanceMotion, zenithAppearanceGlass, zenithAppearanceBattery
    // Zenith fork: rows under More options on the sound and capture pages, which search opens.
    case zenithMixerVisibleApps, zenithScreenshotMore, zenithScreenshotLoupe, zenithRecordingMore
    case zenithRemoveBackground, zenithRemoveBackgroundResult // Zenith fork: Orbit wave 2
    case zenithEmojiPicker, zenithEmojiPickerPicking
    case zenithCalculator, zenithCalculatorAnswers

    var page: SettingsPage {
        switch self {
        case .mixer, .zenithMixerVisibleApps: return .volumeMixer
        case .audioPriority, .soundOutputSwitcher: return .soundOutput
        case .musicBlocking: return .musicBlocker
        case .micMute: return .micMute
        case .cameraPreview: return .cameraPreview
        case .panelConfiguration, .zenithMenuBarHider: return .menuBar // Zenith fork
        case .keepAwake, .bluetoothSleep: return .sleep // Zenith fork
        case .brightness, .extraBrightness: return .brightness // Zenith fork
        case .scrollDirection, .scrollZoom, .smoothScroll, .linearScroll, .scrollSpeed: return .scrolling
        case .focusFollowsMouse, .mouseAcceleration: return .pointer
        case .mouseNavigation, .mouseButtonShortcuts, .middleClick, .mouseClickDebounce: return .mouseButtons
        case .switcher: return .switcher
        case .dock, .dockClick: return .dock
        case .spacesOrder: return .spaces
        case .finderCutPaste, .finderRename, .diskImageInstaller: return .finderTools
        case .clipboardHistory, .pastePlain: return .clipboard
        case .quickLauncher: return .quickLauncher
        case .quickToggles: return .quickToggles
        case .quitApps: return .quitApps
        case .cleaningMode: return .cleaningMode
        case .wallpaper: return .wallpaper
        case .scratchpad: return .scratchpad
        case .screenshot, .screenshotScrolling, .zenithScreenshotMore, .zenithScreenshotLoupe: return .screenshot
        case .screenRecorder, .zenithRecordingMore: return .screenRecording
        case .screenOCR: return .textCapture
        case .colorPicker: return .colorPicker
        case .keyboardBrightnessShortcuts: return .shortcuts
        case .fanControl: return .fanControl // Zenith fork
        case .monitorAlerts: return .monitor
        case .windowMaximizer: return .windowLayout
        // Zenith fork
        case .zenithWakaTime, .zenithVercel, .zenithGitHub, .zenithCardImport, .zenithDevServers, .zenithGit, .zenithSky,
             .zenithRecap, .zenithPrompter,
             .zenithCardBackup, .zenithPrayerTimes, .zenithGoldenHour, .zenithCameraAutoStart,
             .zenithCommandActivity, .zenithExportTracker, .zenithNotices, .zenithTabBar:
            return .notch
        case .zenithReply: return .notchNotifications // Zenith fork: the island's sections, pages of their own
        case .zenithClaudeHooks: return .notchAgents
        case .zenithLockScreen, .zenithLockScreenTerminal, .zenithLockScreenLyrics, .zenithLockScreenMusic: return .lockScreen
        case .zenithRemote: return .remote
        case .zenithPocket, .zenithPocketRelay, .zenithPocketPairing, .zenithPocketSharing, .zenithPocketWatchtower: return .pocket
        case .zenithFaceUnlock: return .faceUnlock
        case .zenithBatteries, .zenithBatteriesAlerts, .zenithBatteriesIPhone: return .batteries
        case .zenithTranslate, .zenithTranslateLanguages, .zenithTranslateDownloads: return .translate
        case .zenithMeetings, .zenithMeetingsCalls, .zenithMeetingsProviders: return .meetings // Zenith fork
        case .zenithMechakey, .zenithMechakeyRepeat: return .mechakey
        case .zenithRemoveBackground, .zenithRemoveBackgroundResult: return .removeBackground // Zenith fork
        case .zenithEmojiPicker, .zenithEmojiPickerPicking: return .emojiPicker
        case .zenithCalculator, .zenithCalculatorAnswers: return .calculator
        case .zenithAppearanceTheme, .zenithAppearanceMotion, .zenithAppearanceGlass, .zenithAppearanceBattery: return .appearance
        case .zenithDropZones, .zenithWatermark: return .shelf
        case .zenithDesignOverlay, .zenithBeautify: return .screenshot
        case .zenithQR: return .clipboard
        }
    }
}

enum NotchSettingsLocation: Hashable {
    case layout, activity, behavior
    case module(NotchModule)

    var tab: NotchSettingsTab {
        switch self {
        case .layout: return .layout
        case .activity: return .activity
        case .behavior: return .behavior
        case .module: return .content
        }
    }

    var id: String {
        switch self {
        case .layout: return "layout"
        case .activity: return "activity"
        case .behavior: return "behavior"
        case .module(let module): return "content." + module.rawValue
        }
    }

    func title(_ language: AppLanguage) -> String {
        let editor = FeatureStrings.notchEditor(language)
        switch self {
        case .layout: return editor.layout
        case .activity: return editor.activity
        case .behavior: return editor.behavior
        case .module(let module): return module.title(language)
        }
    }
}

extension NotchModule {
    /// Zenith fork: the page of its own a section's options live on, or nil
    /// for the sections whose options stay on the island page's Content tab.
    var settingsPage: SettingsPage? {
        switch self {
        case .calendar: return .notchCalendar
        case .notifications: return .notchNotifications
        case .music: return .notchMusic
        case .timer: return .notchTimer
        case .agents: return .notchAgents
        case .downloads: return .notchDownloads
        case .watch: return .notchWatch
        default: return nil
        }
    }
}

extension SettingsPage {
    /// Zenith fork: one of the island's sections on a page of its own.
    var isNotchModulePage: Bool {
        NotchModule.allCases.contains { $0.settingsPage == self }
    }
}

/// A feature's nearest configuration surface. The optional anchor distinguishes
/// a feature section on a shared page; nil means the page itself is the target.
struct FeatureSettingsDestination: Hashable {
    let page: SettingsPage
    private(set) var sectionAnchor: SettingsSectionAnchor?
    let notchLocation: NotchSettingsLocation?

    init(_ page: SettingsPage, sectionAnchor: SettingsSectionAnchor? = nil) {
        self.page = page
        self.sectionAnchor = sectionAnchor
        self.notchLocation = nil
    }

    /// Zenith fork: a section with a page of its own (Calendar, Music, Agents…)
    /// lands on that page rather than on the island's Content tab.
    init(notch location: NotchSettingsLocation) {
        if case .module(let module) = location, let page = module.settingsPage {
            self.page = page
            notchLocation = nil
        } else {
            page = .notch
            notchLocation = location
        }
        sectionAnchor = nil
    }

    /// Zenith fork: a section inside one of the island's tabs or module options.
    init(notch location: NotchSettingsLocation, sectionAnchor: SettingsSectionAnchor) {
        self.init(notch: location)
        self.sectionAnchor = sectionAnchor
    }

    var hasValidSectionAnchor: Bool {
        sectionAnchor == nil || sectionAnchor?.page == page
    }
}

struct SettingsDestinationRequest: Equatable {
    let id: UUID
    let destination: FeatureSettingsDestination
}

/// A one-shot request to reveal a specific feature's row inside the Features
/// hub, correlated with the destination request that carries it by sharing
/// the same request id.
struct SettingsFeatureTargetRequest: Equatable {
    let id: UUID
    let feature: AppFeature
}

/// Whether the Settings window can be seen. Closing it keeps the window and
/// its last page alive, so a page that animates on its own pauses on this
/// instead of drawing for nobody until the app quits. Kept apart from the
/// router so a covered or reopened window does not redraw every page.
final class SettingsWindowVisibility: ObservableObject {
    static let shared = SettingsWindowVisibility()
    @Published private(set) var isVisible = false

    func set(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
    }
}

/// Selects a Settings destination and publishes a fresh request identity even
/// when callers ask for the same page and anchor repeatedly.
final class SettingsRouter: ObservableObject {
    static let shared = SettingsRouter()

    private struct HistoryEntry {
        let destination: FeatureSettingsDestination
        let sidebarFeature: AppFeature?
    }

    @Published var page: SettingsPage = .general {
        didSet {
            guard page != oldValue else { return }
            destination = FeatureSettingsDestination(page)
            sidebarFeature = nil
            pendingDestinationRequest = nil
            pendingFeatureTarget = nil
            if !isTraversingHistory {
                history.removeSubrange((historyIndex + 1)..<history.count)
                history.append(HistoryEntry(destination: destination, sidebarFeature: nil))
                historyIndex += 1
            }
        }
    }
    @Published private(set) var destination = FeatureSettingsDestination(.general)
    @Published private(set) var sidebarFeature: AppFeature?
    @Published private(set) var requestID = UUID()
    @Published private(set) var pendingDestinationRequest: SettingsDestinationRequest?
    /// One-shot hint for the Features hub: which feature row to reveal once
    /// the requested page lands. Always set (to nil when no target is given)
    /// on every `request`, so a stale target from an earlier search can never
    /// leak into a later, unrelated navigation.
    @Published private(set) var pendingFeatureTarget: SettingsFeatureTargetRequest?
    /// One-shot hint for the Cleaner page's tool switcher, so a panel surface
    /// can land directly on a specific tool. Consumed and cleared on arrival.
    @Published var cleanerTool: String?

    private var history = [HistoryEntry(destination: FeatureSettingsDestination(.general),
                                        sidebarFeature: nil)]
    private var historyIndex = 0
    private var isTraversingHistory = false

    init() {}

    /// `replacingVisit` swaps what the current visit shows without adding a
    /// history entry, for a fallback when the visited tool went away.
    func request(_ destination: FeatureSettingsDestination, targetFeature: AppFeature? = nil,
                 sidebarFeature: AppFeature? = nil, replacingVisit: Bool = false) {
        let requestID = UUID()
        let samePage = page == destination.page
        page = destination.page
        self.destination = destination
        self.sidebarFeature = sidebarFeature?.settingsDestination == destination ? sidebarFeature : nil
        let entry = HistoryEntry(destination: destination, sidebarFeature: self.sidebarFeature)
        // Section requests refine the current page visit, not a new history
        // entry. General shows one tool per anchor, so switching tools there
        // is a visit of its own.
        if samePage && !isTraversingHistory && !replacingVisit
            && Self.anchorSelectsTool(on: destination.page)
            && history[historyIndex].destination != destination {
            history.removeSubrange((historyIndex + 1)..<history.count)
            history.append(entry)
            historyIndex += 1
        } else {
            history[historyIndex] = entry
        }
        pendingDestinationRequest = SettingsDestinationRequest(id: requestID,
                                                               destination: destination)
        pendingFeatureTarget = targetFeature.map {
            SettingsFeatureTargetRequest(id: requestID, feature: $0)
        }
        self.requestID = requestID
    }

    private static func anchorSelectsTool(on page: SettingsPage) -> Bool {
        page == .general
    }

    func goBack(isPageVisible: (SettingsPage) -> Bool = { _ in true }) {
        navigateHistory(step: -1, isPageVisible: isPageVisible)
    }

    func goForward(isPageVisible: (SettingsPage) -> Bool = { _ in true }) {
        navigateHistory(step: 1, isPageVisible: isPageVisible)
    }

    func canGoBack(isPageVisible: (SettingsPage) -> Bool = { _ in true }) -> Bool {
        historyTarget(step: -1, isPageVisible: isPageVisible) != nil
    }

    func canGoForward(isPageVisible: (SettingsPage) -> Bool = { _ in true }) -> Bool {
        historyTarget(step: 1, isPageVisible: isPageVisible) != nil
    }

    private func navigateHistory(step: Int, isPageVisible: (SettingsPage) -> Bool) {
        guard let index = historyTarget(step: step, isPageVisible: isPageVisible) else { return }
        historyIndex = index
        isTraversingHistory = true
        cleanerTool = nil
        let entry = history[index]
        request(entry.destination, sidebarFeature: entry.sidebarFeature)
        isTraversingHistory = false
    }

    private func historyTarget(step: Int, isPageVisible: (SettingsPage) -> Bool) -> Int? {
        var index = historyIndex + step
        while history.indices.contains(index) {
            if isPageVisible(history[index].destination.page) { return index }
            index += step
        }
        return nil
    }

    /// Clears only the request a view actually handled. A newer request that
    /// arrived while the destination page was being installed must survive.
    func consumeDestinationRequest(id: UUID) {
        guard pendingDestinationRequest?.id == id else { return }
        pendingDestinationRequest = nil
    }

    /// Clears only the feature target a view actually revealed. Mirrors
    /// `consumeDestinationRequest`: a newer request that arrived while the
    /// Features hub was still laying out must survive.
    func consumeFeatureTarget(id: UUID) {
        guard pendingFeatureTarget?.id == id else { return }
        pendingFeatureTarget = nil
    }
}

extension AppFeature {
    /// The hub itself is the honest fallback for features without a separate
    /// configuration surface, but linking a row back to its current page would
    /// present a chevron that appears to do nothing.
    var hasNavigableSettingsDestination: Bool {
        settingsDestination.page != .features
    }

    /// Exhaustive by design: adding an AppFeature requires choosing its
    /// Settings destination before the project compiles.
    var settingsDestination: FeatureSettingsDestination {
        switch self {
        case .switcher: return FeatureSettingsDestination(.switcher, sectionAnchor: .switcher)
        case .dockPreview: return FeatureSettingsDestination(.dock, sectionAnchor: .dock)
        case .dockClick: return FeatureSettingsDestination(.dock, sectionAnchor: .dockClick)
        case .spacesOrder: return FeatureSettingsDestination(.spaces, sectionAnchor: .spacesOrder)
        case .windowMaximizer:
            return FeatureSettingsDestination(.windowLayout, sectionAnchor: .windowMaximizer)
        case .windowLayout: return FeatureSettingsDestination(.windowLayout)
        case .autoQuit: return FeatureSettingsDestination(.autoQuit)
        case .quitWindowProtection: return FeatureSettingsDestination(.quitProtection)

        case .scrollInverter, .scrollHorizontal:
            return FeatureSettingsDestination(.scrolling, sectionAnchor: .scrollDirection)
        case .scrollZoom:
            return FeatureSettingsDestination(.scrolling, sectionAnchor: .scrollZoom)
        case .focusFollowsMouse:
            return FeatureSettingsDestination(.pointer, sectionAnchor: .focusFollowsMouse)
        case .smoothScroll:
            return FeatureSettingsDestination(.scrolling, sectionAnchor: .smoothScroll)
        case .linearScroll:
            return FeatureSettingsDestination(.scrolling, sectionAnchor: .linearScroll)
        case .scrollSpeed:
            return FeatureSettingsDestination(.scrolling, sectionAnchor: .scrollSpeed)
        case .mouseAcceleration:
            return FeatureSettingsDestination(.pointer, sectionAnchor: .mouseAcceleration)
        case .mouseNavigation:
            return FeatureSettingsDestination(.mouseButtons, sectionAnchor: .mouseNavigation)
        case .mouseButtonShortcuts:
            return FeatureSettingsDestination(.mouseButtons, sectionAnchor: .mouseButtonShortcuts)
        case .middleClick:
            return FeatureSettingsDestination(.mouseButtons, sectionAnchor: .middleClick)
        case .mouseClickDebounce:
            return FeatureSettingsDestination(.mouseButtons, sectionAnchor: .mouseClickDebounce)
        case .keyboardDebounce: return FeatureSettingsDestination(.keyDebounce)
        case .textSnippets: return FeatureSettingsDestination(.textSnippets)
        case .superKey: return FeatureSettingsDestination(.superKey)

        case .clipboardHistory:
            return FeatureSettingsDestination(.clipboard, sectionAnchor: .clipboardHistory)
        case .pastePlain:
            return FeatureSettingsDestination(.clipboard, sectionAnchor: .pastePlain)
        case .finderCutPaste:
            return FeatureSettingsDestination(.finderTools, sectionAnchor: .finderCutPaste)
        case .finderRename:
            return FeatureSettingsDestination(.finderTools, sectionAnchor: .finderRename)
        case .shelf: return FeatureSettingsDestination(.shelf)
        case .urlCleaner: return FeatureSettingsDestination(.urlCleaner)
        case .diskImageInstaller:
            return FeatureSettingsDestination(.finderTools, sectionAnchor: .diskImageInstaller)

        // Zenith fork: the sound tools open their own pages.
        case .mixer: return FeatureSettingsDestination(.volumeMixer)
        case .soundOutputSwitcher, .audioPriority: return FeatureSettingsDestination(.soundOutput)
        case .micMute: return FeatureSettingsDestination(.micMute)
        case .musicBlock: return FeatureSettingsDestination(.musicBlocker)

        // Zenith fork: Energy split into Sleep and Brightness.
        case .keepAwake:
            return FeatureSettingsDestination(.sleep, sectionAnchor: .keepAwake)
        case .brightness:
            return FeatureSettingsDestination(.brightness, sectionAnchor: .brightness)
        case .extraBrightness:
            return FeatureSettingsDestination(.brightness, sectionAnchor: .extraBrightness)
        case .bluetoothSleep:
            return FeatureSettingsDestination(.sleep, sectionAnchor: .bluetoothSleep)

        case .quickLauncher:
            return FeatureSettingsDestination(.quickLauncher, sectionAnchor: .quickLauncher)
        case .quickToggles:
            return FeatureSettingsDestination(.quickToggles, sectionAnchor: .quickToggles)
        case .quitApps:
            return FeatureSettingsDestination(.quitApps, sectionAnchor: .quitApps)
        case .colorPicker: return FeatureSettingsDestination(.colorPicker) // Zenith fork
        case .screenOCR: return FeatureSettingsDestination(.textCapture) // Zenith fork
        case .cleaningMode:
            return FeatureSettingsDestination(.cleaningMode, sectionAnchor: .cleaningMode)
        case .mediaTools: return FeatureSettingsDestination(.media)
        case .cleaner: return FeatureSettingsDestination(.cleaner)
        case .uninstaller: return FeatureSettingsDestination(.uninstaller)
        case .killProcess: return FeatureSettingsDestination(.killProcess)
        case .portManager: return FeatureSettingsDestination(.portManager)
        case .homebrew: return FeatureSettingsDestination(.homebrew)
        case .appUpdates: return FeatureSettingsDestination(.appUpdates)
        case .screenshot: return FeatureSettingsDestination(.screenshot) // Zenith fork
        case .cameraPreview: return FeatureSettingsDestination(.cameraPreview) // Zenith fork
        case .wallpaper:
            return FeatureSettingsDestination(.wallpaper, sectionAnchor: .wallpaper)
        case .notch: return FeatureSettingsDestination(.notch)
        // Zenith fork: the island's sections with options open their own pages.
        case .notchCalendar: return FeatureSettingsDestination(.notchCalendar)
        case .notchNotifications: return FeatureSettingsDestination(.notchNotifications)
        case .notchGestures: return FeatureSettingsDestination(notch: .behavior)
        case .notchTimer: return FeatureSettingsDestination(.notchTimer)
        case .notchAccessories: return FeatureSettingsDestination(notch: .activity)
        case .notchLyrics, .notchQueue, .notchLiveEqualizer:
            return FeatureSettingsDestination(.notchMusic)
        case .notchDownloads: return FeatureSettingsDestination(.notchDownloads)
        case .notchAgents: return FeatureSettingsDestination(.notchAgents)
        case .notchWatch: return FeatureSettingsDestination(.notchWatch)
        case .notchMascot: return FeatureSettingsDestination(.notchMascot)
        case .radialMenu: return FeatureSettingsDestination(.radialMenu)
        case .scratchpad:
            return FeatureSettingsDestination(.scratchpad, sectionAnchor: .scratchpad)
        case .commandBar: return FeatureSettingsDestination(.commandBar)
        case .screenRecorder: return FeatureSettingsDestination(.screenRecording) // Zenith fork

        case .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower, .connectedDevices:
            return FeatureSettingsDestination(.monitor)
        case .fanControl: return FeatureSettingsDestination(.fanControl) // Zenith fork: a page of its own
        }
    }
}

/// Which hub features keep each Settings page alive. A page with several
/// features only disappears when ALL of them are switched off in the hub.
enum FeatureVisibilitySupport {
    static let monitorFeatures: [AppFeature] = [
        .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
        .connectedDevices, .fanControl,
    ]

    /// Features gating a page; empty means the page is part of the app and
    /// always shows (General, Shortcuts, About and friends).
    static func features(for page: SettingsPage) -> [AppFeature] {
        switch page {
        // Zenith fork: Energy split into Sleep and Brightness; Fan Control left Monitor.
        case .sleep: return [.keepAwake, .bluetoothSleep]
        case .brightness: return [.brightness, .extraBrightness]
        case .fanControl: return [.fanControl]
        case .monitor: return monitorFeatures.filter { $0 != .fanControl }
        case .scrolling: return [.scrollInverter, .scrollHorizontal, .scrollZoom, .smoothScroll, .linearScroll, .scrollSpeed]
        case .pointer: return [.mouseAcceleration, .focusFollowsMouse]
        case .mouseButtons: return [.mouseNavigation, .mouseButtonShortcuts, .middleClick, .mouseClickDebounce]
        case .switcher: return [.switcher]
        case .dock: return [.dockPreview, .dockClick]
        case .spaces: return [.spacesOrder]
        case .windowLayout: return [.windowLayout, .windowMaximizer]
        case .autoQuit: return [.autoQuit]
        case .quitProtection: return [.quitWindowProtection]
        case .clipboard: return [.clipboardHistory, .pastePlain]
        case .finderTools: return [.finderCutPaste, .finderRename, .diskImageInstaller]
        case .shelf: return [.shelf]
        case .media: return [.mediaTools]
        case .quickLauncher: return [.quickLauncher]
        case .quickToggles: return [.quickToggles]
        case .quitApps: return [.quitApps]
        case .cleaningMode: return [.cleaningMode]
        case .wallpaper: return [.wallpaper]
        case .scratchpad: return [.scratchpad]
        case .urlCleaner: return [.urlCleaner]
        case .cleaner: return [.cleaner]
        case .homebrew: return [.homebrew]
        case .appUpdates: return [.appUpdates]
        case .uninstaller: return [.uninstaller]
        case .killProcess: return [.killProcess]
        case .portManager: return [.portManager]
        case .keyDebounce: return [.keyboardDebounce]
        case .superKey: return [.superKey]
        case .textSnippets: return [.textSnippets]
        case .screenshot: return [.screenshot]
        // Zenith fork: the sound and capture tools' own pages.
        case .volumeMixer: return [.mixer]
        case .soundOutput: return [.soundOutputSwitcher, .audioPriority]
        case .musicBlocker: return [.musicBlock]
        case .micMute: return [.micMute]
        case .screenRecording: return [.screenRecorder]
        case .textCapture: return [.screenOCR]
        case .colorPicker: return [.colorPicker]
        case .cameraPreview: return [.cameraPreview]
        case .notch: return [.notch, .notchGestures, .notchAccessories]
        // Zenith fork: the island's sections, each kept by its own feature;
        // Music by the island, whose section it is, or any of its extras.
        case .notchCalendar: return [.notchCalendar]
        case .notchNotifications: return [.notchNotifications]
        case .notchMusic: return [.notch, .notchLyrics, .notchQueue, .notchLiveEqualizer]
        case .notchTimer: return [.notchTimer]
        case .notchAgents: return [.notchAgents]
        case .notchDownloads: return [.notchDownloads]
        case .notchWatch: return [.notchWatch]
        case .notchMascot: return [.notchMascot]
        case .lockScreen: return [.notch] // Zenith fork: the island draws the lock screen
        case .radialMenu: return [.radialMenu]
        case .commandBar: return [.commandBar]
        case .translate: return [] // Zenith fork: a page of the app's own, which no hub feature hides
        case .general, .features, .shortcuts, .advanced, .about, .releaseNotes, .support,
             .workspaces, .remote, .pocket, .faceUnlock, .batteries,
             .meetings, .mechakey, .appearance, // Zenith fork
             .menuBar, // Zenith fork: the app's own menu bar, which no hub feature hides
             .removeBackground, .emojiPicker, .calculator: // Zenith fork: Orbit wave 2
            return []
        }
    }

    static func isPageVisible(_ page: SettingsPage,
                              isAvailable: (AppFeature) -> Bool) -> Bool {
        let gate = features(for: page)
        return gate.isEmpty || gate.contains(where: isAvailable)
    }

    /// Whether one of `page`'s features is among `activeFeatures`, the live
    /// users of a permission from `AppFeature.activeFeatures(using:)`. A page
    /// that several features share asks for the grant while any of them uses it.
    static func isPermissionNeeded(on page: SettingsPage,
                                   activeFeatures: [AppFeature]) -> Bool {
        features(for: page).contains(where: activeFeatures.contains)
    }
}
