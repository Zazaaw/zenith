// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Only values that change which controls exist belong in the search cache key.
struct SettingsSearchState: Equatable {
    struct Hardware: Equatable {
        let battery, notchedDisplay, plainDisplay, keyboardLight, bluetoothSleep, brightnessOSD: Bool
    }

    let hardware: Hardware
    let bars, batteryRest, capsule, customSize, minimalMascot, groupsMinimizedWindows: Bool
    private let switches: Set<String>

    init(defaults: UserDefaults, hardware: Hardware) {
        self.hardware = hardware
        bars = defaults.string(forKey: DefaultsKey.menuBarMetricAppearance) == "bars"
        batteryRest = defaults.string(forKey: DefaultsKey.notchIdleContent) == NotchIdleContent.battery.rawValue
        capsule = defaults.string(forKey: DefaultsKey.notchSilhouette) != NotchSilhouette.notch.rawValue
        customSize = defaults.string(forKey: DefaultsKey.notchSize) == NotchSize.custom.rawValue
        minimalMascot = (NotchMascotStyle(rawValue: defaults.string(forKey: DefaultsKey.notchMascotStyle) ?? "")
            ?? .satuVisual) == .minimal
        groupsMinimizedWindows = (defaults.string(forKey: DefaultsKey.switcherMinimizedPlacement)
            ?? WindowSwitchMinimizedPlacement.normal.rawValue) != WindowSwitchMinimizedPlacement.normal.rawValue
        switches = Set([
            DefaultsKey.clamshellPreferred, DefaultsKey.keepAwakeMouseJiggleEnabled, DefaultsKey.brightnessControlEnabled,
            DefaultsKey.displayVolumeEnabled, DefaultsKey.displayVolumeKeysEnabled,
            DefaultsKey.bluetoothSleepEnabled, DefaultsKey.dockPreviewEnabled, DefaultsKey.switcherSimpleMode,
            DefaultsKey.switcherIconRowMode, DefaultsKey.notchLyricsEnabled, DefaultsKey.notchShelf,
            DefaultsKey.notchClipboardWindow, DefaultsKey.notchLowBatteryTint, DefaultsKey.notchLowBatteryEarly,
            DefaultsKey.notchHideInFullscreen, DefaultsKey.notchHoverInFullscreen, DefaultsKey.notchOpenOnHover,
            DefaultsKey.notchHideUntilHover, DefaultsKey.notchHoverExpands, DefaultsKey.notchAgentsClaude,
            DefaultsKey.notchAgentsLiveActivity, DefaultsKey.notchAgentsFinishAlert, DefaultsKey.notchAgentsLimitAlert,
            DefaultsKey.notchCommandBar, DefaultsKey.notchMascotVisits, DefaultsKey.monitorAlertCPU,
            DefaultsKey.monitorAlertCPUTemperature, DefaultsKey.monitorAlertDisk,
            DefaultsKey.monitorAlertBattery, DefaultsKey.monitorAlertBatteryTemperature,
        ].filter { defaults.bool(forKey: $0) })
    }

    func on(_ key: String) -> Bool { switches.contains(key) }
}

extension SettingsSearchState {
    static var current: Self {
        Self(defaults: .standard, hardware: Hardware(
            battery: PowerSampler.hasInternalBattery, notchedDisplay: NotchSupport.hasNotchedDisplay,
            plainDisplay: NotchSupport.hasDisplayWithoutNotch, keyboardLight: BrightnessService.keyboardLightIsSupported,
            bluetoothSleep: BluetoothSleepService.isSupported,
            brightnessOSD: AppFeature.brightness.isAvailable && UserDefaults.standard.bool(forKey: DefaultsKey.brightnessControlEnabled)
                && BrightnessService.shared.brightnessOSDSupported))
    }
}

/// One Settings page as the sidebar and the command bar present it.
struct SettingsDirectoryItem: Identifiable {
    let page: SettingsPage
    let title: String
    let icon: String
    let terms: [SettingsSearchTerms]
    var id: SettingsPage { page }

    init(page: SettingsPage, title: String, icon: String,
         keywords: [String] = [],
         featureKeywords: [(feature: AppFeature, titles: [String])] = [],
         terms: [SettingsSearchTerms] = []) {
        self.page = page
        self.title = title
        self.icon = icon
        self.terms = [SettingsSearchTerms(keywords)]
            + featureKeywords.map { SettingsSearchTerms($0.titles, feature: $0.feature) } + terms
    }
}

/// The single map of the Settings window: sections, pages, icons and search
/// keywords. The sidebar draws its tool list from these pages; the command bar
/// searches them. One list, so a page added here is findable everywhere.
enum SettingsDirectory {
    /// Shared pages whose tools cover the page without a separate overview row.
    private static let toolOnlyPages: Set<SettingsPage> = [
        .energy, .switcher, .clipboard, .cutPaste, .quickTools, .screenshot,
    ]

    /// The sidebar: the directory's rows (one per page, or one per tool on a
    /// shared page), sorted by `SettingsSidebarLayout` into the four tiles and
    /// the groups under them. Zenith fork: the floating sidebar's groups.
    static func sidebarSections(_ s: Strings,
                                language: AppLanguage,
                                superKeySource: SuperKeySource = SuperKeyService.shared.source,
                                state: SettingsSearchState = .current,
                                keyboardLight: Bool = BrightnessService.keyboardLightIsSupported,
                                isAvailable: (AppFeature) -> Bool) -> [SettingsSidebarSection] {
        let hub = FeatureStrings.hub(language)
        let rows = sections(s, language: language, superKeySource: superKeySource, state: state)
            .flatMap(\.items).flatMap { pageItem -> [SettingsSidebarItem] in
                var rows = SettingsSidebarSupport.items(
                    page: pageItem.page, title: pageItem.title, icon: pageItem.icon,
                    preferredFeatures: pageItem.terms.compactMap(\.feature),
                    includePage: !toolOnlyPages.contains(pageItem.page),
                    isAvailable: isAvailable) { feature in
                        if feature == .clipboardHistory {
                            return FeatureStrings.commandBar(language).sourceClipboard
                        }
                        return feature.hubTitle(s, hub: hub, language: language)
                    }
                if pageItem.page == .screenshot {
                    rows = SettingsSidebarSupport.screenshotRows(rows, language: language)
                }
                if pageItem.page == .general {
                    rows.insert(SettingsSidebarItem(
                        id: .setting(.panelConfiguration),
                        destination: FeatureSettingsDestination(
                            .general, sectionAnchor: .panelConfiguration),
                        title: s.menuBarSection, icon: "menubar.rectangle"), at: 1)
                    // Zenith fork: Appearance, a tile beside General.
                    rows.insert(SettingsSidebarItem(
                        id: .page(.appearance), destination: FeatureSettingsDestination(.appearance),
                        title: ZenithStrings.appearancePage(language).title, icon: "paintpalette"), at: 1)
                }
                if pageItem.page == .shortcuts, isAvailable(.brightness), keyboardLight {
                    let destination = FeatureSettingsDestination(
                        .shortcuts, sectionAnchor: .keyboardBrightnessShortcuts)
                    rows.append(SettingsSidebarItem(
                        id: .setting(.keyboardBrightnessShortcuts), destination: destination,
                        title: FeatureStrings.brightness(language).keyboardLight,
                        icon: "keyboard"))
                }
                // The companion lives in the island, and its settings in a tab
                // of the island's page rather than a row of their own.
                return rows.filter { $0.id != .page(.notchMascot) }
            }
        return SettingsSidebarLayout.sections(rows)
    }

    static func sidebarItems(_ s: Strings,
                             language: AppLanguage,
                             superKeySource: SuperKeySource = SuperKeyService.shared.source,
                             isAvailable: (AppFeature) -> Bool) -> [SettingsSidebarItem] {
        sidebarSections(s, language: language, superKeySource: superKeySource,
                        isAvailable: isAvailable).flatMap(\.items)
    }

    /// Destination-aware rows for focused Settings and Command Bar search.
    static func searchItems(_ s: Strings,
                            language: AppLanguage,
                             superKeySource: SuperKeySource = SuperKeyService.shared.source,
                             state: SettingsSearchState = .current) -> [SettingsSearchItem] {
        let pageItems = sections(s, language: language, superKeySource: superKeySource,
                                 state: state)
            .flatMap(\.items).map { item in
                SettingsSearchItem(id: .page(item.page),
                                   destination: FeatureSettingsDestination(item.page),
                                   title: item.title,
                                   icon: item.icon,
                                   terms: item.terms)
            }
        let hub = FeatureStrings.hub(language)
        let featureItems = SettingsSearchSupport.featureItems(language: language) { feature in
            feature.hubTitle(s, hub: hub, language: language)
        }
        var items = SettingsSearchSupport.combinedItems(pageItems: pageItems,
                                                        featureItems: featureItems)
        items.append(SettingsSearchItem(
            id: .setting(.panelConfiguration),
            destination: FeatureSettingsDestination(
                .general, sectionAnchor: .panelConfiguration),
            title: s.menuBarSection, icon: "menubar.rectangle",
            keywords: [s.showMenuBarIcon, FeatureStrings.generalSettings(language).menuBarIconTitle,
                       FeatureStrings.generalSettings(language).iconMissingTitle, "SF Symbols"]))
        items.append(SettingsSearchSupport.scrollingScreenshotItem(language: language))
        let alerts = FeatureStrings.monitorAlerts(language)
        items.append(SettingsSearchItem(
            id: .setting(.monitorAlerts), destination: FeatureSettingsDestination(.monitor, sectionAnchor: .monitorAlerts),
            title: alerts.section, icon: "bell", keywords: [alerts.cooldown], terms: [
                .init([alerts.cpu, alerts.cpuTemperature], feature: .monitorCPU),
                .init([alerts.cpuThreshold], feature: .monitorCPU, when: state.on(DefaultsKey.monitorAlertCPU)),
                .init([alerts.cpuTemperatureThreshold], feature: .monitorCPU, when: state.on(DefaultsKey.monitorAlertCPUTemperature)),
                .init([alerts.memory], feature: .monitorMemory),
                .init([alerts.disk], feature: .monitorDisk),
                .init([alerts.diskThreshold], feature: .monitorDisk, when: state.on(DefaultsKey.monitorAlertDisk)),
                .init([alerts.battery, alerts.batteryTemperature], feature: .monitorPower, when: state.hardware.battery),
                .init([alerts.batteryThreshold], feature: .monitorPower,
                      when: state.hardware.battery && state.on(DefaultsKey.monitorAlertBattery)),
                .init([alerts.batteryTemperatureThreshold], feature: .monitorPower,
                      when: state.hardware.battery && state.on(DefaultsKey.monitorAlertBatteryTemperature)),
            ]))
        if state.hardware.keyboardLight {
            items.append(SettingsSearchSupport.keyboardBrightnessShortcutItem(language: language))
        }
        ZenithSettingsSearch.extend(&items, language: language, state: state) // Zenith fork
        return items
    }

    static func sections(_ s: Strings,
                         language: AppLanguage,
                         superKeySource: SuperKeySource = SuperKeyService.shared.source,
                         state: SettingsSearchState)
        -> [(title: String, items: [SettingsDirectoryItem])] {
        let categories = FeatureStrings.settingsCategories(language)
        let quitProtection = FeatureStrings.quitProtection(language)
        let brightness = FeatureStrings.brightness(language)
        let bluetooth = FeatureStrings.bluetoothSleep(language)
        let barStyle = FeatureStrings.menuBarAppearance(language)
        let previews = FeatureStrings.windowPreviewExclusions(language)
        let notch = FeatureStrings.notch(language)
        let notchEditor = FeatureStrings.notchEditor(language)
        let notchMusic = FeatureStrings.notchMusicExtras(language)
        let notchCalendar = FeatureStrings.notchCalendar(language)
        let notchAgents = FeatureStrings.notchAgents(language)
        let notchLowBattery = NotchLowBatteryStrings.localized(language)
        let mascot = FeatureStrings.notchMascot(language)
        let activities = FeatureStrings.notchActivities(language)
        let lockScreen = FeatureStrings.notchLockScreen(language)
        let pagesText = ZenithStrings.inputWindows(language) // Zenith fork
        let hover = state.on(DefaultsKey.notchOpenOnHover)
        let hideFullscreen = state.on(DefaultsKey.notchHideInFullscreen)
        let hoverDelay = hover || (hideFullscreen && state.on(DefaultsKey.notchHoverInFullscreen))
        let batteryRest = state.hardware.battery && state.batteryRest
        let tintedBattery = batteryRest && state.on(DefaultsKey.notchLowBatteryTint)
        let islandTerms: [SettingsSearchTerms] = [
            .init([notchEditor.layout, notch.size, notch.showOutline], notch: .layout),
            .init([notch.width, notch.maximumHeight], notch: .layout, when: state.customSize),
            .init([notch.cameraFit, notch.hideMenuBarGap, notch.width, notch.height],
                  notch: .layout, when: state.hardware.notchedDisplay),
            .init([notch.withoutNotch], notch: .layout, when: state.hardware.plainDisplay),
            .init([notch.capsuleFit, notch.width, notch.height, notch.fromTop],
                  notch: .layout, when: state.hardware.plainDisplay && state.capsule),
            .init([activities.keepAwakeActivity], notch: .module(.controls)),
            .init([notch.playingMusic, notchMusic.includeOtherPlayers, notchMusic.showVolume, notchMusic.preferredPlayer,
                   notchMusic.enableLyrics, notchMusic.browserCovers, notchMusic.enableQueue, notchMusic.liveEqualizer,
                   "music"], notch: .module(.music)),
            .init([notchMusic.online], feature: .notchLyrics, notch: .module(.music), when: state.on(DefaultsKey.notchLyricsEnabled)),
            .init([notchCalendar.countdown, notchCalendar.countdownLead, notchCalendar.timeLeft, notchCalendar.weekNumbers],
                  feature: .notchCalendar, notch: .module(.calendar)),
            .init([FeatureStrings.notchNotifications(language).hideSystemBanner], feature: .notchNotifications, notch: .module(.notifications)),
            .init([activities.soundEnabled, activities.hideTimerCountdown], feature: .notchTimer, notch: .module(.timer)),
            .init([notch.dragReveal], feature: .shelf, notch: .module(.files), when: state.on(DefaultsKey.notchShelf)),
            .init([notch.clipboardActivity, "clipboard"], feature: .clipboardHistory, notch: .module(.clipboard)),
            .init([FeatureStrings.notchClipboardSize(language).entrySize], feature: .clipboardHistory,
                  notch: .module(.clipboard), when: state.on(DefaultsKey.notchClipboardWindow)),
            .init(["camera"], feature: .cameraPreview, notch: .module(.camera)),
            .init([notchAgents.title, "Claude", "Codex", "OpenCode", "GitHub Copilot", "Cursor", "AI", "tokens", notchAgents.resetsCard,
                   notchAgents.limitsAs, notchAgents.limitFocus, notchAgents.liveActivity, notchAgents.finishAlert,
                   notchAgents.limitAlert, notchAgents.budget, notchAgents.priceUpdates], feature: .notchAgents, notch: .module(.agents)),
            .init([notchAgents.readout], feature: .notchAgents, notch: .module(.agents), when: state.on(DefaultsKey.notchAgentsLiveActivity)),
            .init([notchAgents.finishAfter], feature: .notchAgents, notch: .module(.agents), when: state.on(DefaultsKey.notchAgentsFinishAlert)),
            .init([notchAgents.limitAt], feature: .notchAgents, notch: .module(.agents), when: state.on(DefaultsKey.notchAgentsLimitAlert)),
            .init([FeatureStrings.claudeAccount(language).title], feature: .notchAgents,
                  notch: .module(.agents), when: state.on(DefaultsKey.notchAgentsClaude)),
            .init([notchEditor.activity, notchEditor.resting, notch.coverMenus, notchEditor.feedback, notch.inputSource,
                   notch.newTrack], notch: .activity),
            .init([notchLowBattery.title], feature: .monitorPower, notch: .activity, when: batteryRest),
            .init([notchLowBattery.threshold, notchLowBattery.early, notchLowBattery.menuBar],
                  feature: .monitorPower, notch: .activity, when: tintedBattery),
            .init([notchLowBattery.earlyThreshold], feature: .monitorPower, notch: .activity,
                  when: tintedBattery && state.on(DefaultsKey.notchLowBatteryEarly)),
            .init([notchEditor.behavior, notchEditor.opening, s.quickToolShortcutToggle,
                   FeatureStrings.notchGestures(language).title, notch.hapticFeedback, notchEditor.reopening,
                   notchEditor.openActivity, notch.display, notch.hideInFullscreen, notchEditor.destinations,
                   notch.panel, notch.tools, notch.files, notch.captures, notchEditor.privacy, notch.showInCaptures,
                   notchEditor.hideMenuBarIcon], notch: .behavior),
            .init([notchEditor.hiddenShowsActivity], notch: .behavior, when: hover && state.on(DefaultsKey.notchHideUntilHover)),
            .init([notchEditor.activationTime], notch: .behavior, when: hoverDelay),
            .init([notchEditor.closeTime], notch: .behavior, when: hoverDelay && state.on(DefaultsKey.notchHoverExpands)),
            .init([notch.hoverInFullscreen], notch: .behavior, when: hideFullscreen),
        ] + [AppFeature.screenshot, .screenRecorder, .screenOCR, .colorPicker].map {
            SettingsSearchTerms([notch.captureActivity], feature: $0, notch: .module(.captures))
        }
        return [
            (categories.essentials, [
                SettingsDirectoryItem(page: .general, title: s.tabGeneral, icon: "gearshape",
                                       keywords: [s.launchAtLogin, s.languageLabel,
                                                  FeatureStrings.feedback(language).sectionTitle],
                                       // The first title of each feature places its sidebar row,
                                       // so these follow the sidebar's order.
                                       featureKeywords: [
                                        (.musicBlock, [s.musicBlockTitle, s.musicBlockSection]),
                                        (.mixer, [s.mixerSection]),
                                        (.soundOutputSwitcher, [s.soundOutputSwitcherTitle]),
                                        (.audioPriority, [s.audioPrioritySection]),
                                        (.keepAwake, [s.globalHotkeySection, s.hotkeyToggle]),
                                       ]),
                // Searching any feature name lands here even when the feature
                // is hidden, so the hub is always the way back.
                SettingsDirectoryItem(page: .features, title: FeatureStrings.hub(language).pageTitle,
                                       icon: "square.grid.2x2",
                                       featureKeywords: AppFeature.allCases.map {
                                        ($0, [$0.hubTitle(s, hub: FeatureStrings.hub(language), language: language)])
                                       }),
                SettingsDirectoryItem(page: .energy, title: s.tabEnergy, icon: "bolt.fill",
                                       featureKeywords: [
                                        (.keepAwake, [s.keepAwakeTitle, s.clamshellTitle,
                                                      s.defaultDurationLabel, s.showCountdown,
                                                      s.keepAwakeActiveIconLabel,
                                                      s.keepAwakeActiveIconCoffee,
                                                      s.keepAwakeActiveIconEye,
                                                      FeatureStrings.keepAwakeAutomation(language)
                                                        .externalDisplayToggle,
                                                      FeatureStrings.keepAwakeAutomation(language)
                                                        .powerToggle,
                                                      FeatureStrings.keepAwakeAutomation(language)
                                                        .pauseWhenLockedToggle,
                                                      FeatureStrings.keepAwakeDisplaySleep(language)
                                                        .allowDisplaySleep,
                                                      s.keepAwakeOptions, s.keepAwakeAutoStart,
                                                      s.keepAwakeRightClickToggle, s.keepAwakeMouseJiggle]),
                                        (.brightness, [brightness.pageTitle, brightness.enable]),
                                        (.extraBrightness, [s.extraBrightnessName]),
                                        (.bluetoothSleep, [bluetooth.pageTitle]),
                                       ], terms: [
                                        .init([s.dimScreenOnLidCloseTitle], feature: .keepAwake,
                                              when: state.on(DefaultsKey.clamshellPreferred)),
                                        .init([s.keepAwakeMouseJiggleInterval], feature: .keepAwake,
                                              when: state.on(DefaultsKey.keepAwakeMouseJiggleEnabled)),
                                        .init([s.batteryDisableBelow], feature: .keepAwake, when: state.hardware.battery),
                                        .init([brightness.keyStep, brightness.keyStepHalf, brightness.keyStepQuarter,
                                               brightness.keysToggle, brightness.displayBrightnessShortcuts, brightness.volumeToggle],
                                              feature: .brightness, when: state.on(DefaultsKey.brightnessControlEnabled)),
                                        .init([brightness.volumeKeysToggle], feature: .brightness,
                                              when: state.on(DefaultsKey.brightnessControlEnabled) && state.on(DefaultsKey.displayVolumeEnabled)),
                                        .init([brightness.speakersStep, brightness.speakersMinimum, brightness.speakersMaximum],
                                              feature: .brightness, when: state.on(DefaultsKey.brightnessControlEnabled)
                                                && state.on(DefaultsKey.displayVolumeEnabled) && state.on(DefaultsKey.displayVolumeKeysEnabled)),
                                        .init([brightness.osdToggle], feature: .brightness,
                                              when: state.hardware.brightnessOSD && state.on(DefaultsKey.brightnessControlEnabled)),
                                        .init([bluetooth.enable], feature: .bluetoothSleep, when: state.hardware.bluetoothSleep),
                                        .init([bluetooth.restoreToggle], feature: .bluetoothSleep,
                                              when: state.hardware.bluetoothSleep && state.on(DefaultsKey.bluetoothSleepEnabled)),
                                       ]),
                SettingsDirectoryItem(page: .monitor, title: s.tabMonitor, icon: "chart.line.uptrend.xyaxis",
                                       keywords: [s.menuBarSpacingLabel, s.menuBarHideIconToggle, barStyle.label,
                                                  barStyle.bars, barStyle.values, s.monitorSeparateMenuBarMetrics,
                                                  s.monitorIntervalLabel, s.temperatures, GraphScaleStrings.localized(language).title],
                                       featureKeywords: [
                                        (.monitorMemory, [s.monitorMemoryPressureDot, s.monitorMemoryMetricLabel]),
                                        (.monitorNetwork, [FeatureStrings.monitorLayout(language).networkSpeedUnit]),
                                        (.fanControl, [FeatureStrings.fanControl(language).menuBarTitle]),
                                       ], terms: [
                                        .init([s.monitorCombineTemperatures], when: !state.bars),
                                        .init([barStyle.customize, barStyle.normalColor, barStyle.mediumColor, barStyle.highColor,
                                               barStyle.mediumFrom, barStyle.highFrom], when: state.bars),
                                       ]),
                // Zenith fork: every device's battery, a page of its own under Monitor (no hub feature).
                SettingsDirectoryItem(page: .batteries, title: ZenithStrings.batteries(language).title,
                                      icon: "battery.75percent", keywords: BatteriesSearch.keywords(language)),
            ]),
            (categories.windowsControls, [
                // Zenith fork: the Mouse page split into Scrolling, Pointer and Mouse Buttons.
                SettingsDirectoryItem(page: .scrolling, title: pagesText.scrollingTitle, icon: "scroll",
                                       keywords: [s.tabMouse, s.scrollTrackpadNote],
                                       featureKeywords: [
                                        // The direction section shows while either of its features is on.
                                        (.scrollInverter, [s.invertMouseScroll, s.invertVerticalScroll,
                                                           s.invertHorizontalScroll, s.scrollSection]),
                                        (.scrollHorizontal, [s.scrollHorizontalName,
                                                            s.scrollHorizontalModifierLabel, s.scrollSection]),
                                        (.scrollZoom, [s.zoomSection, s.pinchZoom]),
                                        (.smoothScroll, [s.smoothScrollName, s.smoothScrollStepLabel,
                                                         s.smoothScrollResponseLabel, s.smoothScrollCoastLabel]),
                                        (.linearScroll, [s.linearScrollName, s.linearScrollLinesLabel]),
                                        (.scrollSpeed, [s.scrollSpeedName, s.scrollSpeedMultiplierLabel]),
                                       ]),
                SettingsDirectoryItem(page: .pointer, title: pagesText.pointerTitle, icon: "cursorarrow.motionlines",
                                       keywords: [s.tabMouse],
                                       featureKeywords: [
                                        (.mouseAcceleration, [s.mouseAccelerationName]),
                                        (.focusFollowsMouse, [s.focusFollowsMouseName,
                                                              s.focusFollowsMouseDelay,
                                                              s.focusFollowsMouseRaise,
                                                              s.focusFollowsMouseWaitForStop]),
                                       ]),
                SettingsDirectoryItem(page: .mouseButtons, title: pagesText.mouseButtonsTitle,
                                       icon: "computermouse",
                                       keywords: [s.tabMouse],
                                       featureKeywords: [
                                        (.mouseNavigation, [s.mouseNavigationEnable, s.mouseNavigationSection]),
                                        (.mouseButtonShortcuts,
                                         [FeatureStrings.mouseButtons(language).pageTitle,
                                          FeatureStrings.mouseButtons(language).sideWheelLeftName,
                                          FeatureStrings.mouseButtons(language).sideWheelRightName,
                                          FeatureStrings.mouseExceptions(language).listTitle,
                                          FeatureStrings.mouseButtons(language).enableLabel,
                                          FeatureStrings.mouseButtons(language).spacesEnableLabel]),
                                        (.middleClick, [s.middleClickTapPicker, s.middleClickEnable]),
                                        (.mouseClickDebounce,
                                         [FeatureStrings.mouseClickDebounce(language).title,
                                          FeatureStrings.mouseClickDebounce(language).windowLabel,
                                          "debounce"]),
                                       ]),
                SettingsDirectoryItem(page: .switcher, title: s.tabSwitcher, icon: "rectangle.on.rectangle",
                                       featureKeywords: [
                                        (.switcher, [s.switcherEnable, s.switcherInstantSelection,
                                                     s.switcherIgnoreHoverSelection,
                                                     FeatureStrings.switcherShortcuts(language).allWindows,
                                                     s.switcherWindowlessApps,
                                                     s.switcherMaxColumns,
                                                     FeatureStrings.switcherAppRules(language).listTitle,
                                                     FeatureStrings.switcherAppRules(language)
                                                        .showWithoutWindows,
                                                     FeatureStrings.switcherAppRules(language).windowsOnly,
                                                     FeatureStrings.switcherAppRules(language).hidden,
                                                     s.switcherTakeOverSystemShortcuts, s.keepAwakeOptions,
                                                     s.switcherAppearanceDelay, s.switcherSearchPin,
                                                     s.switcherMergeTabs, s.switcherShowFullscreenWindows,
                                                     s.switcherMinimizedPlacementLabel,
                                                     s.switcherScreenPlacementLabel, s.switcherCurrentDisplayOnly,
                                                     s.switcherCurrentSpaceOnly,
                                                     previews.sectionTitle, s.minimalWindowPreviews,
                                                     previews.listTitle]),
                                       ], terms: [
                                        .init([s.switcherTreatHiddenAppsLikeMinimized], feature: .switcher,
                                              when: state.groupsMinimizedWindows),
                                        .init([s.switcherShowShortcutHints], feature: .switcher,
                                              when: state.on(DefaultsKey.switcherSimpleMode) || state.on(DefaultsKey.switcherIconRowMode)),
                                       ]),
                SettingsDirectoryItem(page: .dock, title: FeatureStrings.settingsPages(language).dockTitle,
                                       icon: "dock.rectangle",
                                       featureKeywords: [
                                        (.dockPreview, [s.dockPreviewName, s.dockPreviewEnable, previews.sectionTitle,
                                                        s.minimalWindowPreviews, previews.listTitle]),
                                        (.dockClick, [FeatureStrings.hub(language).titleDockClick,
                                                      s.dockClickMinimize, s.dockClickHide,
                                                      s.dockClickCycleWindows]),
                                       ], terms: [
                                        .init([s.dockPreviewOpenDelay, s.dockPreviewBackgroundOpacity,
                                               s.dockPreviewQuitAppOnClose, s.dockPreviewKeepDockVisible,
                                               s.dockPreviewOrderByCreation, s.switcherCurrentSpaceOnly], feature: .dockPreview,
                                              when: state.on(DefaultsKey.dockPreviewEnabled)),
                                       ]),
                // Zenith fork: Spaces in a fixed order, a page of its own beside the Dock.
                SettingsDirectoryItem(page: .spaces, title: pagesText.spacesTitle, icon: "rectangle.split.3x1",
                                      featureKeywords: [(.spacesOrder, [s.spacesOrderName, "Mission Control"])]),
                SettingsDirectoryItem(page: .windowLayout,
                                      title: FeatureStrings.windowLayout(language).title,
                                      icon: "rectangle.3.group",
                                      keywords: [WindowStageManagerStrings.localized(language).title, "Stage Manager"],
                                      featureKeywords: [
                                        (.windowLayout, [s.dockClickCycleWindows,
                                                         FeatureStrings.windowLayout(language).edgeSnapEnable,
                                                         WindowEdgeSnapRestoreStrings.localized(language).title,
                                                         FeatureStrings.windowLayout(language).gestureEnable,
                                                         FeatureStrings.windowLayout(language).gestureResize,
                                                         FeatureStrings.windowLayoutIgnoredApps(language).listTitle]),
                                        (.windowMaximizer,
                                         [s.windowMaximizeName,
                                          FeatureStrings.windowMaximizerExclusions(language).listTitle]),
                                      ]),
                SettingsDirectoryItem(page: .autoQuit, title: s.autoQuitName, icon: "xmark.rectangle",
                                      keywords: [s.autoQuitEnable,
                                                 FeatureStrings.autoQuitDockApps(language).listTitle,
                                                 FeatureStrings.autoQuitDockApps(language).caption]),
                SettingsDirectoryItem(page: .quitProtection,
                                      title: quitProtection.name,
                                      icon: "shield.lefthalf.filled",
                                      keywords: [quitProtection.description, "⌘Q", "⌘W",
                                                 quitProtection.hold, quitProtection.doublePress,
                                                 quitProtection.extraModifier]),
            ]),
            (categories.files, [
                SettingsDirectoryItem(page: .clipboard, title: FeatureStrings.clipboard(language).title,
                                       icon: "doc.on.clipboard",
                                       featureKeywords: [
                                        (.clipboardHistory, [FeatureStrings.clipboard(language).limit,
                                                             FeatureStrings.clipboardRetention(language).title,
                                                             FeatureStrings.clipboard(language).historyLayout,
                                                             FeatureStrings.clipboard(language).skipSensitive,
                                                             FeatureStrings.clipboard(language).pasteImageAsFile,
                                                             FeatureStrings.clipboard(language).autoClearEnable,
                                                             FeatureStrings.clipboard(language).autoClearOnSleep,
                                                             FeatureStrings.clipboard(language)
                                                                .autoClearOnDisplaySleep,
                                                             FeatureStrings.clipboard(language)
                                                                .autoClearOnScreenLock,
                                                             FeatureStrings.clipboardIgnoredApps(language)
                                                                .listTitle]),
                                        (.pastePlain, [s.pastePlainName]),
                                       ]),
                SettingsDirectoryItem(page: .cutPaste,
                                       title: FeatureStrings.finderRename(language).pageTitle,
                                       icon: "filemenu.and.selection",
                                       featureKeywords: [
                                        (.finderCutPaste, [s.cutPasteEnable]),
                                        (.finderRename,
                                         [FeatureStrings.finderRename(language).enableLabel]),
                                       ]),
                SettingsDirectoryItem(page: .shelf, title: s.shelfName, icon: "tray.full",
                                      keywords: [s.shelfEnable, s.shelfDropZoneToggle, s.shelfEdgeToggle,
                                                 s.shelfClearOnClose, s.shelfShortcutFinderSelection,
                                                 FeatureStrings.notch(language).title,
                                                 FeatureStrings.notchEditor(language).separate]),
                SettingsDirectoryItem(page: .media, title: s.mediaName, icon: "photo.on.rectangle.angled",
                                      keywords: ["PDF", "GIF", "PNG", "JPEG", "convert", "resize", "watermark",
                                                 "rename", "profile", "fit", "fill", "crop",
                                                 s.mediaStartConvertPDF, s.ocrName]),
            ]),
            // Everything about the apps installed on the Mac lives together:
            // what is out of date, what is junk and what should go.
            (categories.appManagement, [
                SettingsDirectoryItem(page: .appUpdates,
                                      title: FeatureStrings.appUpdates(language).pageTitle,
                                      icon: "arrow.down.app",
                                      keywords: [FeatureStrings.appUpdates(language).checkNow,
                                                 FeatureStrings.appUpdates(language).frequencyLabel,
                                                 FeatureStrings.appUpdates(language).appStoreBadge,
                                                 s.homebrewName]),
                SettingsDirectoryItem(page: .cleaner, title: s.cleanerName, icon: "sparkles",
                                      keywords: [s.cleanerScheduleTitle,
                                                 FeatureStrings.whatsAppDownloads(language).title,
                                                 FeatureStrings.whatsAppDownloads(language).automatic,
                                                 FeatureStrings.whatsAppDownloads(language).fileTypes]),
                SettingsDirectoryItem(page: .homebrew, title: s.homebrewName, icon: "shippingbox"),
                SettingsDirectoryItem(page: .uninstaller, title: s.uninstallerName, icon: "trash",
                                      keywords: [s.uninstallerCommandBarToggle, s.uninstallerWatchTrashToggle]),
                SettingsDirectoryItem(page: .killProcess,
                                      title: FeatureStrings.killProcess(language).pageTitle,
                                      icon: "xmark.octagon",
                                      keywords: ["force quit", "process", "cpu", "memory", "kill"]),
                SettingsDirectoryItem(page: .portManager,
                                      title: FeatureStrings.portManager(language).title,
                                      icon: "network",
                                      keywords: ["port", "ports", "listening", "socket", "PID", "kill port"]),
            ]),
            (categories.utilities, [
                SettingsDirectoryItem(page: .notch,
                                      title: notch.title,
                                      icon: "macbook",
                                      keywords: [notch.description, "notch"], terms: islandTerms),
                SettingsDirectoryItem(page: .notchMascot, title: mascot.title,
                                      icon: AppFeature.notchMascot.symbolName, keywords: mascot.searchKeywords,
                                      terms: [
                                        .init([mascot.shape], when: state.minimalMascot),
                                        .init([mascot.side], when: state.hardware.notchedDisplay || !state.capsule),
                                        .init([mascot.frequency], when: state.on(DefaultsKey.notchMascotVisits)),
                                        .init([mascot.opensAs], feature: .commandBar, when: state.on(DefaultsKey.notchCommandBar)),
                                      ]),
                // Zenith fork: the lock screen, a page of its own beside the island's.
                SettingsDirectoryItem(page: .lockScreen, title: lockScreen.title, icon: "lock.display",
                                      keywords: [lockScreen.show, lockScreen.sounds]),
                // Zenith fork: calls from the calendar, a page of its own beside the island's (no hub feature).
                SettingsDirectoryItem(page: .meetings, title: ZenithStrings.meetings(language).title,
                                      icon: "video", keywords: MeetingsSearch.keywords(language)),
                // Zenith fork: lock and check status from an iPhone, a page of its own (no hub feature).
                SettingsDirectoryItem(page: .remote, title: ZenithStrings.remote(language).title,
                                      icon: "iphone.radiowaves.left.and.right",
                                      keywords: ZenithRemoteSearch.keywords(language)),
                // Zenith fork: Zenith Pocket, the iPhone and Watch companion, right after iPhone Remote.
                SettingsDirectoryItem(page: .pocket, title: ZenithStrings.pocket(language).title,
                                      icon: "macbook.and.iphone", keywords: PocketSearch.keywords(language)),
                // Zenith fork: face unlock, a page of its own (no hub feature).
                SettingsDirectoryItem(page: .faceUnlock, title: ZenithStrings.faceUnlock(language).title,
                                      icon: "faceid", keywords: FaceUnlockSearch.keywords(language)),
                SettingsDirectoryItem(page: .commandBar,
                                      title: FeatureStrings.commandBar(language).pageTitle,
                                      icon: "command",
                                      keywords: [FeatureStrings.commandBar(language).openButton,
                                                 FeatureStrings.commandBar(language).searchPlaceholder,
                                                 FeatureStrings.commandBar(language).appCenterTitle,
                                                 FeatureStrings.commandBar(language).appAliasLabel]),
                // Zenith fork: workspaces, a page of the app's own (no hub feature).
                SettingsDirectoryItem(page: .workspaces, title: ZenithStrings.workspaces(language).title,
                                      icon: "square.grid.2x2",
                                      keywords: ZenithWorkspacesSearch.keywords(language)),
                SettingsDirectoryItem(page: .quickTools, title: s.quickToolsTab, icon: "wand.and.rays",
                                       featureKeywords: [
                                        (.quickLauncher, [s.launcherName]),
                                        (.micMute, [s.micMuteName, s.micMuteFollowCallAppsToggle, s.micMuteMenuBarToggle]),
                                        (.quickToggles, [FeatureStrings.quickToggles(language).pageTitle,
                                                         FeatureStrings.quickToggles(language)
                                                            .darkModeToDark,
                                                         FeatureStrings.quickToggles(language)
                                                            .emptyTrashTitle,
                                                         FeatureStrings.brightness(language)
                                                            .keyboardLight]),
                                        (.quitApps, [s.quitAppsName,
                                                     FeatureStrings.quickToggles(language).quitAllTitle,
                                                     FeatureStrings.quickToggles(language).quitOthersTitle,
                                                     FeatureStrings.quickToggles(language).exceptionsTitle]),
                                        (.cameraPreview,
                                         [FeatureStrings.cameraPreview(language).pageTitle]),
                                        (.wallpaper,
                                         [FeatureStrings.wallpaper(language).pageTitle]),
                                        (.scratchpad, [FeatureStrings.scratchpad(language).pageTitle]),
                                        (.cleaningMode, [s.cleaningMenuItem, s.cleaningKeepScreenVisibleToggle]),
                                       ]),
                SettingsDirectoryItem(page: .screenshot,
                                       title: FeatureStrings.screenshot(language).screenCaptureTitle,
                                       icon: "camera.viewfinder",
                                       featureKeywords: SettingsSearchSupport
                                        .screenCaptureFeatureKeywords(s, language: language)),
                SettingsDirectoryItem(page: .urlCleaner, title: s.urlCleanerName, icon: "link"),
                SettingsDirectoryItem(page: .keyDebounce, title: s.keyDebounceName, icon: "keyboard"),
                // Zenith fork: keyboard sounds as you type, a page of its own (no hub feature).
                SettingsDirectoryItem(page: .mechakey, title: ZenithStrings.mechakey(language).title,
                                      icon: "pianokeys", keywords: MechakeySearch.keywords(language)),
                SettingsDirectoryItem(page: .superKey,
                                      title: FeatureStrings.superKey(language).pageTitle,
                                      icon: superKeySource.systemImage,
                                      keywords: SuperKeySource.allCases.map {
                                          FeatureStrings.superKey(language).sourceLabel($0)
                                      }),
                SettingsDirectoryItem(page: .textSnippets,
                                      title: FeatureStrings.snippets(language).pageTitle,
                                      icon: "text.append",
                                      keywords: [FeatureStrings.snippets(language).triggerLabel,
                                                 FeatureStrings.snippets(language).addButton,
                                                 FeatureStrings.snippets(language).soundPickerLabel,
                                                 FeatureStrings.snippets(language).soundToggle]),
                // Zenith fork: Translate, a page of its own beside the text tools (no hub feature).
                SettingsDirectoryItem(page: .translate, title: ZenithStrings.translate(language).title,
                                      icon: "translate", keywords: TranslateSearch.keywords(language)),
                SettingsDirectoryItem(page: .radialMenu,
                                      title: FeatureStrings.radialMenu(language).pageTitle,
                                      icon: "circle.grid.cross",
                                      keywords: [FeatureStrings.radialMenu(language).addButton,
                                                 FeatureStrings.radialMenu(language).kindApp,
                                                 FeatureStrings.radialMenu(language).kindMedia,
                                                 FeatureStrings.radialMenu(language).kindSubmenu,
                                                 FeatureStrings.radialMenu(language).mouseTriggerRequirement]),
            ]),
            (categories.app, [
                SettingsDirectoryItem(page: .shortcuts, title: s.shortcutsPageTitle, icon: "command"),
                SettingsDirectoryItem(page: .advanced, title: s.tabAdvanced, icon: "wrench.and.screwdriver"),
                SettingsDirectoryItem(page: .about, title: s.tabAbout, icon: "info.circle",
                                      keywords: [s.reviewIntro, s.reviewHighlights]),
                SettingsDirectoryItem(page: .releaseNotes, title: s.tabReleaseNotes, icon: "sparkles"),
                SettingsDirectoryItem(page: .support, title: s.tabSupport, icon: "heart.fill",
                                      keywords: [s.donateButton, s.supportIntroStarButton]),
            ]),
        ]
    }
}
