// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Settings → Dynamic Island. Zenith fork: a feature page of the kit
/// (docs/SETTINGS-KIT.md): the hero with the island's switch, the island on
/// the stage, then its tabs: the layout and size, the sections and their
/// order, what it rests with and the notices it shows, and how it opens. The
/// sections with options of their own (Calendar, Notifications, Music, Timer,
/// Agents, Downloads, Watch) and the companion have pages in the Island group.
struct NotchSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.notchGesturesEnabled) private var gesturesEnabled = true
    @AppStorage(DefaultsKey.notchKeyboardLight) private var keyboardLight = true
    @AppStorage(DefaultsKey.notchNotificationsEnabled) private var notificationsEnabled = true
    @AppStorage(DefaultsKey.notchTimerEnabled) private var timerEnabled = true
    @AppStorage(DefaultsKey.notchCameraEnabled) private var cameraEnabled = true
    @AppStorage(DefaultsKey.notchCameraAutoStart) private var cameraAutoStart = true // Zenith fork
    @AppStorage(DefaultsKey.notchAccessoriesEnabled) private var accessoriesEnabled = true
    @AppStorage(DefaultsKey.notchCalendarEnabled) private var calendarEnabled = true
    @AppStorage(DefaultsKey.notchAgentsEnabled) private var agentsEnabled = false
    @AppStorage(DefaultsKey.notchWatchEnabled) private var watchEnabled = true
    @AppStorage(DefaultsKey.notchVercelEnabled) private var vercelEnabled = false // Zenith fork
    @AppStorage(DefaultsKey.notchEnabled) private var enabled = false
    @AppStorage(DefaultsKey.notchMascotEnabled) private var mascotEnabled = false
    @AppStorage(DefaultsKey.notchMascotHidesWhenIdle) private var mascotHidesWhenIdle = true
    @AppStorage(DefaultsKey.notchMascotStyle) private var mascotStyle = NotchMascotStyle.satuVisual.rawValue
    @AppStorage(DefaultsKey.notchMascotShape) private var mascotShape = NotchMascotShape.ball.rawValue
    @AppStorage(DefaultsKey.notchMascotPalette) private var mascotPalette = NotchMascotPalette.pearl.rawValue
    @AppStorage(DefaultsKey.notchMascotSide) private var mascotSide = NotchMascotSide.left.rawValue
    @AppStorage(DefaultsKey.notchDisplay) private var display = NotchDisplay.automatic.rawValue
    @AppStorage(DefaultsKey.notchSilhouette) private var silhouette = NotchSilhouette.capsule.rawValue
    @AppStorage(DefaultsKey.notchOpenOnHover) private var hover = false
    @AppStorage(DefaultsKey.notchShortcutEnabled) private var shortcutEnabled = false
    @AppStorage(DefaultsKey.notchHideInFullscreen) private var hideInFullscreen = false
    @AppStorage(DefaultsKey.notchHoverInFullscreen) private var hoverInFullscreen = false
    @AppStorage(DefaultsKey.notchHideUntilHover) private var hideUntilHover = false
    @AppStorage(DefaultsKey.notchHiddenShowsActivity) private var hiddenShowsActivity = false
    @AppStorage(DefaultsKey.notchCoversMenus) private var coversMenus = true
    @AppStorage(DefaultsKey.notchHoverDelay) private var hoverDelay = NotchSupport.defaultHoverDelay
    @AppStorage(DefaultsKey.notchCloseDelay) private var closeDelay = NotchSupport.defaultCloseDelay
    @AppStorage(DefaultsKey.notchReturnHome) private var returnHome = false
    @AppStorage(DefaultsKey.notchHomeModule) private var homeModule = NotchModule.controls.rawValue
    @AppStorage(DefaultsKey.notchOpensActivity) private var opensActivity = true
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchModuleOrder) private var order = ""
    @AppStorage(DefaultsKey.notchVolume) private var volume = true
    @AppStorage(DefaultsKey.notchInputSource) private var inputSource = true
    @AppStorage(DefaultsKey.notchMicrophone) private var microphone = true
    @AppStorage(DefaultsKey.notchBrightness) private var brightness = true
    @AppStorage(DefaultsKey.notchBattery) private var battery = true
    @AppStorage(DefaultsKey.notchClipboard) private var clipboard = true
    @AppStorage(DefaultsKey.notchClipboardWindow) private var clipboardWindow = true
    @AppStorage(DefaultsKey.notchClipboardCardSize) private var clipboardCardSize = NotchClipboardCardSize.comfortable.rawValue
    @AppStorage(DefaultsKey.screenshotDefaultAction) private var captureAction = ""
    @AppStorage(DefaultsKey.notchCapture) private var capture = true
    @AppStorage(DefaultsKey.notchTrackChange) private var trackChange = true
    @AppStorage(DefaultsKey.notchIdleContent) private var idle = NotchIdleContent.music.rawValue
    @AppStorage(DefaultsKey.notchLowBatteryTint) private var lowBatteryTint = false
    @AppStorage(DefaultsKey.notchLowBatteryThreshold) private var lowBatteryThreshold = NotchSupport.defaultLowBatteryThreshold
    @AppStorage(DefaultsKey.notchLowBatteryEarly) private var earlyBatteryWarning = false
    @AppStorage(DefaultsKey.notchLowBatteryEarlyThreshold) private var earlyBatteryThreshold = NotchSupport.defaultEarlyBatteryThreshold
    @AppStorage(DefaultsKey.notchLowBatteryMenuBar) private var lowBatteryMenuBar = true
    @AppStorage(DefaultsKey.notchHiddenControls) private var hiddenControls = NotchControlItem.defaultHidden
    @AppStorage(DefaultsKey.notchControlOrder) private var controlOrder = ""
    @AppStorage(DefaultsKey.notchShowInCaptures) private var showInCaptures = true
    @AppStorage(DefaultsKey.notchSize) private var size = NotchSize.spacious.rawValue
    @AppStorage(DefaultsKey.notchOutlineEnabled) private var outlineEnabled = false
    @AppStorage(DefaultsKey.notchHideMenuBarGap) private var hideMenuBarGap = false
    @AppStorage(DefaultsKey.notchCustomWidth) private var customWidth = NotchSize.defaultWidth
    @AppStorage(DefaultsKey.notchCustomHeight) private var customHeight = NotchSize.defaultHeight
    @AppStorage(DefaultsKey.notchCameraFitWidth) private var cameraFitWidth = 0.0
    @AppStorage(DefaultsKey.notchCameraFitHeight) private var cameraFitHeight = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitWidth) private var capsuleFitWidth = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitHeight) private var capsuleFitHeight = 0.0
    @AppStorage(DefaultsKey.notchCapsuleFitDrop) private var capsuleFitDrop = 0.0
    @AppStorage(DefaultsKey.notchHapticFeedback) private var hapticFeedback = true
    @AppStorage(DefaultsKey.notchShelf) private var shelfWindow = true
    @AppStorage(DefaultsKey.notchDragReveal) private var dragReveal = true
    @AppStorage(DefaultsKey.notchCaptureControls) private var captureControls = true
    @AppStorage(DefaultsKey.notchQuickPanel) private var quickPanel = true
    @AppStorage(DefaultsKey.notchAppPanel) private var appPanel = false
    @AppStorage(DefaultsKey.notchHidesMenuBarIcon) private var hidesMenuBarIcon = false
    @AppStorage(DefaultsKey.notchKeepAwakeActivity) private var keepAwakeActivity = false
    @AppStorage(DefaultsKey.notchScratchpad) private var scratchpad = true
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessControlEnabled = false
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) private var clipboardHistoryEnabled = false
    @AppStorage(DefaultsKey.notchHoverExpands) private var hoverExpand = true
    @AppStorage(DefaultsKey.notchQuickAccessLayout) private var accessData = Data()
    @State private var tab = NotchSettingsTab.layout
    @State private var selectedModule = NotchModule.controls
    @State private var draggingModule: NotchModule?
    @State private var draggingControl: NotchControlItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }
    private var pages: ZenithIslandPagesStrings { ZenithStrings.islandPages(l10n.language) }

    private var configuration: [String] {
        [String(enabled), String(calendarEnabled),
         String(notificationsEnabled), String(gesturesEnabled),
         idle, hiddenControls, controlOrder, size,
         String(timerEnabled),
         String(cameraEnabled), String(accessoriesEnabled), String(outlineEnabled), String(hideMenuBarGap),
         String(customWidth), String(customHeight), String(cameraFitWidth), String(cameraFitHeight),
         String(capsuleFitWidth), String(capsuleFitHeight), String(capsuleFitDrop), String(hapticFeedback),
         String(shelfWindow), String(dragReveal), String(captureControls), String(quickPanel), String(appPanel),
         String(hoverExpand), String(hideUntilHover), String(hiddenShowsActivity), String(hideInFullscreen),
         String(hoverInFullscreen), String(coversMenus),
         display, silhouette, String(hover), hidden, order, String(volume), String(inputSource),
         String(brightness), String(keyboardLight),
         String(microphone), String(battery), String(clipboard), String(clipboardWindow), clipboardCardSize,
         String(capture), String(trackChange), captureAction, String(showInCaptures),
         String(returnHome), homeModule, String(opensActivity), String(scratchpad),
         String(agentsEnabled), String(watchEnabled), String(keepAwakeActivity), String(shortcutEnabled),
         String(vercelEnabled)]
    }

    private var access: Binding<NotchQuickAccessConfiguration> {
        Binding(get: { NotchQuickAccessConfiguration.stored() }, set: { accessData = $0.encoded })
    }

    private var orderedModules: [NotchModule] {
        let stored = order.split(separator: ",").compactMap { NotchModule(rawValue: String($0)) }
        var seen = Set<NotchModule>()
        return (stored + NotchModule.allCases).filter { seen.insert($0).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.description, chips: heroChips, isOn: $enabled,
                           switchLabel: text.enable, animation: .island)
                if enabled, AppFeature.notch.isAvailable, !(hover && hideUntilHover && !hiddenShowsActivity),
                   !notch.geometry.isNotched, !permissions.accessibility {
                    ZenithCallout(.warning, text.menuBarAccessHint) {
                        Button(l10n.s.permissionRequest) { permissions.requestAccessibility() }
                        Button(l10n.s.permissionOpenSettings) { permissions.openAccessibilitySettings() }
                    }
                }
                // Zenith fork: the island on the stage, its states the tabs below.
                ZenithNotchPreviewCard(tab: $tab, module: selectedModule, canOpen: enabled) { NotchService.shared.open() }
                Group {
                    switch tab {
                    case .layout: layoutPage
                    case .content: contentEditor
                    case .activity: activityPage
                    case .behavior: behaviorPage
                    }
                }
                .id(tab)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onChange(of: configuration) { _, _ in sync() }
        .onChange(of: accessData) { _, _ in NotchService.shared.syncWithPreferences() }
        .onChange(of: tab) { _, _ in draggingModule = nil; draggingControl = nil }
        .onAppear(perform: revealDestination)
        .onChange(of: router.requestID) { _, _ in revealDestination() }
    }

    /// The island's size and how it opens, as two facts beside the switch.
    private var heroChips: [ZenithChip] {
        let chosen = NotchSize(rawValue: size) ?? .spacious
        let sizeChip = chosen == .compact ? pages.compactChip : chosen == .custom ? pages.customChip : pages.spaciousChip
        return [ZenithChip(sizeChip), ZenithChip(hover ? pages.hoverChip : pages.clickChip)]
    }

    private func revealDestination() {
        guard let location = router.destination.notchLocation else { return }
        if case .module(let module) = location { selectedModule = module }
        tab = location.tab
    }

    private func sync() {
        NotchService.shared.syncWithPreferences()
        if AppFeature.brightness.isAvailable { BrightnessService.shared.syncWithPreferences() }
    }

    // MARK: Layout

    private var layoutPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            NotchLayoutEditor(configuration: access, size: $size, width: $customWidth, height: $customHeight) {
                selectedModule = .controls; tab = .content
            }
            VStack(alignment: .leading, spacing: 10) {
                ZenithSectionTitle(text.size)
                ZenithVisualPicker(text.size, selection: Binding(get: { NotchSize(rawValue: size) ?? .spacious },
                                                                 set: { size = $0.rawValue }),
                                   options: [ZenithPickerOption(NotchSize.compact, text.compact),
                                             ZenithPickerOption(NotchSize.spacious, text.spacious),
                                             ZenithPickerOption(NotchSize.custom, text.custom)],
                                   minimumTileWidth: 120) { item, _ in
                    NotchSizeTileArt(size: item)
                }
            }
            if size == NotchSize.custom.rawValue {
                ZenithSection(footer: text.sizeHint) {
                    dimensionSlider(text.width, value: $customWidth, range: NotchSize.widthRange, fallback: NotchSize.defaultWidth)
                    dimensionSlider(text.maximumHeight, value: $customHeight, range: NotchSize.heightRange,
                                    fallback: NotchSize.defaultHeight)
                }
            }
            ZenithTabBarSettings() // Zenith fork: what the tab pill under the open island holds.
            // Only a display without a camera can float the island.
            if NotchSupport.hasDisplayWithoutNotch {
                VStack(alignment: .leading, spacing: 10) {
                    ZenithSectionTitle(text.withoutNotch)
                    ZenithVisualPicker(text.withoutNotch,
                                       selection: Binding(get: { NotchSilhouette(rawValue: silhouette) ?? .capsule },
                                                          set: { silhouette = $0.rawValue }),
                                       options: [ZenithPickerOption(NotchSilhouette.capsule, text.capsuleShape),
                                                 ZenithPickerOption(NotchSilhouette.notch, text.notchShape)],
                                       minimumTileWidth: 220) { item, _ in
                        NotchSilhouetteSample(silhouette: item)
                    }
                    // An island kept on a camera, or away with the lid closed,
                    // shows neither shape, so the card says where to change that.
                    if enabled, !NotchService.reachesDisplayWithoutNotch(NotchDisplay(rawValue: display) ?? .automatic) {
                        ZenithCallout(.info, text.withoutNotchUnreached) {
                            Button(text.showOnAllDisplays) { display = NotchDisplay.all.rawValue }
                        }
                    }
                }
            }
            ZenithSection {
                switchRow("capsule", text.showOutline, isOn: $outlineEnabled)
                // Only a physical camera has an outline to match.
                if NotchSupport.hasNotchedDisplay {
                    switchRow("rectangle.topthird.inset.filled", text.hideMenuBarGap,
                              caption: text.hideMenuBarGapHint, isOn: $hideMenuBarGap)
                }
                ZenithMoreOptions(id: "notch.fit") {
                    if NotchSupport.hasDisplayWithoutNotch, NotchSilhouette(rawValue: silhouette) ?? .capsule == .capsule {
                        // Even widths keep the capsule centred on whole points.
                        fitSlider(text.width, card: text.capsuleFit, hint: text.capsuleFitHint, value: $capsuleFitWidth,
                                  range: NotchCapsuleFit.widthRange, step: 2)
                        fitSlider(text.height, card: text.capsuleFit, value: $capsuleFitHeight,
                                  range: NotchCapsuleFit.heightRange, step: 1)
                        fitSlider(text.fromTop, card: text.capsuleFit, value: $capsuleFitDrop,
                                  range: NotchCapsuleFit.dropRange, step: 1)
                    }
                    if NotchSupport.hasNotchedDisplay {
                        // Whole points keep the island centred on the camera's pixels.
                        fitSlider(text.width, card: text.cameraFit, hint: text.cameraFitHint, value: $cameraFitWidth,
                                  range: NotchCameraFit.widthRange, step: 1)
                        fitSlider(text.height, card: text.cameraFit, value: $cameraFitHeight,
                                  range: NotchCameraFit.heightRange, step: 0.5)
                    }
                }
            }
        }
    }

    // MARK: Sections

    /// The sections in a list of their own, beside the chosen one's options.
    /// The stage above shows the island on it. A section with a page of its
    /// own leads there.
    private var contentEditor: some View {
        HStack(alignment: .top, spacing: 16) {
            sectionList
                .frame(width: 210, height: 540, alignment: .top)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    let module = selectedModule
                    let available = module.isAvailable()
                    // Zenith fork: GitHub names what it is missing (the GitHub CLI).
                    NotchSectionHeader(module: module, shown: isShown(module),
                                       reason: available ? nil : moduleFeature(module).map { $0.enableReason(l10n) }
                                           ?? (module == .github ? ZenithStrings.gitHub(l10n.language).missingCLI : text.disabled)) {
                        SettingsRouter.shared.request(FeatureSettingsDestination(.features), targetFeature: moduleFeature(module))
                    }
                    if let page = module.settingsPage {
                        // Zenith fork: its options live on its own page in the Island group.
                        ZenithSection {
                            ZenithRow(pages.openSection, info: pages.modulePageHint, value: module.title(l10n.language)) {
                                router.request(FeatureSettingsDestination(page))
                            }
                        }
                    } else if available || module == .github, hasOptions(module) {
                        // Zenith fork: GitHub's options can look again for a gh the
                        // usual folders missed, so they show while it is unavailable.
                        SettingsCard { moduleOptions(module) }
                    } else if available {
                        Text(editor.noOptions).font(ZenithType.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 22)
            }
            .id(selectedModule)
            .frame(height: 540)
        }
    }

    /// Every section in the island's order, each with the switch that shows it.
    private var sectionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(editor.sections).font(.headline)
                Text(editor.sectionsHint).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(orderedModules) { module in
                            NotchSectionListRow(module: module, included: moduleBinding(module), available: module.isAvailable(),
                                                selected: selectedModule == module,
                                                order: Binding(get: { orderedModules },
                                                               set: { order = $0.map(\.rawValue).joined(separator: ",") }),
                                                dragging: $draggingModule) { selectedModule = module }
                                .id(module)
                        }
                    }
                }
                .scrollIndicators(.automatic)
                // A section chosen from the island itself may sit low in the list.
                .onAppear { reader.scrollTo(selectedModule) }
                .onChange(of: selectedModule) { _, module in
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { reader.scrollTo(module) }
                }
            }
        }
        .padding(10)
        .zenithGroupBackground()
    }

    private func isShown(_ module: NotchModule) -> Bool {
        module.isAvailable() && moduleBinding(module).wrappedValue
    }

    /// The mixer, the system page and the tools arrange themselves in the island.
    private func hasOptions(_ module: NotchModule) -> Bool {
        ![.mixer, .system, .tools].contains(module)
    }

    @ViewBuilder private func moduleOptions(_ module: NotchModule) -> some View {
        switch module {
        case .controls:
            let primary = [NotchControlItem.music, .volume, .brightness, .keyboardLight]
            HStack(spacing: 10) {
                ForEach(primary) { item in
                    toggleCard(item.title(l10n), symbol: item.symbol, value: controlBinding(item), available: item.isAvailable(),
                               reason: controlReason(item), reservesReason: !primary.allSatisfy { $0.isAvailable() },
                               unavailableAction: controlUnavailableAction(item))
                }
            }
            Text(text.controlShortcuts).font(.subheadline.weight(.medium))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                ForEach(orderedShortcuts) { item in
                    PanelReorderableItem(item: item,
                        order: Binding(get: { orderedShortcuts }, set: { controlOrder = $0.map(\.rawValue).joined(separator: ",") }),
                        dragging: $draggingControl) {
                        toggleCard(item.title(l10n), symbol: item.symbol, value: controlBinding(item), available: item.isAvailable(),
                                   reason: controlReason(item), reservesReason: !orderedShortcuts.allSatisfy { $0.isAvailable() },
                                   unavailableAction: controlUnavailableAction(item))
                    }
                }
            }
            Divider()
            let activities = FeatureStrings.notchActivities(l10n.language)
            SettingsFeatureSwitchRow(symbol: NotchControlItem.keepAwake.symbol, title: activities.keepAwakeActivity,
                                     caption: activities.keepAwakeActivityHint, isOn: $keepAwakeActivity, feature: .keepAwake)
        case .camera:
            Text(FeatureStrings.notchActivities(l10n.language).cameraHint).font(.callout).foregroundStyle(.secondary)
            // Zenith fork: the page starts its mirror itself once access is granted.
            let camera = ZenithStrings.camera(l10n.language)
            ZenithSwitchRow(camera.autoStart, isOn: $cameraAutoStart) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(camera.autoStart).font(ZenithType.rowTitle)
                    Text(camera.autoStartCaption).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .zenithSectionAnchor(.zenithCameraAutoStart) // Zenith fork: Settings search
            if permissions.camera == .granted {
                Label(l10n.s.permissionGranted, systemImage: "checkmark.circle.fill").foregroundStyle(ZenithStatus.success)
            } else {
                Button(l10n.s.permissionRequest, action: permissions.requestCamera)
                Button(l10n.s.permissionOpenSettings, action: permissions.openCameraSettings)
            }
        case .files:
            destination(text.files, symbol: "tray.full", value: $shelfWindow, available: AppFeature.shelf.isAvailable)
            if shelfWindow { switchRow("hand.draw", text.dragReveal, isOn: $dragReveal) }
            if AppFeature.mediaTools.isAvailable {
                Text(FeatureStrings.notchFiles(l10n.language).optimizeDropHint)
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .clipboard:
            destination(FeatureStrings.clipboard(l10n.language).title, symbol: "doc.on.clipboard", value: $clipboardWindow, available: AppFeature.clipboardHistory.isAvailable)
            switchRow("doc.on.clipboard", text.clipboardActivity, caption: text.privacy, isOn: $clipboard)
            if clipboardWindow, AppFeature.clipboardHistory.isAvailable {
                let size = FeatureStrings.notchClipboardSize(l10n.language)
                // Read as the page reads it, so a value it does not know shows comfortable here too.
                SettingsChoiceRow(symbol: "rectangle.compress.vertical", title: size.entrySize,
                                  selection: Binding(get: { NotchClipboardCardSize(stored: clipboardCardSize) },
                                                     set: { clipboardCardSize = $0.rawValue })) {
                    Text(size.compact).tag(NotchClipboardCardSize.compact)
                    Text(size.comfortable).tag(NotchClipboardCardSize.comfortable)
                }
                Text(size.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .captures:
            SettingsFeatureSwitchRow(symbol: "camera.viewfinder", title: text.captureActivity, isOn: $capture, feature: .screenshot)
            if capture, AppFeature.screenshot.isAvailable {
                ScreenshotDefaultActionPicker(strings: FeatureStrings.screenshot(l10n.language), selection: $captureAction)
            }
        case .scratchpad:
            destination(FeatureStrings.scratchpad(l10n.language).pageTitle, symbol: "note.text", value: $scratchpad)
        case .wakatime:
            // Zenith fork: the personal token that unlocks ranges and coding now.
            WakaTimeTokenSettings()
        case .vercel:
            // Zenith fork: the access token and the build in the closed island.
            VercelSettings()
        case .github:
            // Zenith fork: which gh is used, and a way to look for it again.
            GitHubSettings()
        case .cardImport:
            // Zenith fork: card detection, the base folder and the import defaults.
            CardImportSettings()
        case .devServers:
            // Zenith fork: detection, the notice, the closed island's count and extra ports or names.
            DevServersSettings()
        case .recap:
            // Zenith fork: the daily notice, its time and the sources it reads.
            RecapSettingsView()
        case .sky:
            // Zenith fork: the method, the place, the reminders and the golden hour.
            SkySettingsView()
        case .git:
            // Zenith fork: pinned repositories, where the current one comes from, the fetch and the branch.
            GitSettings()
        case .prompter:
            // Zenith fork: the scripts, the reading, mirror, the guide, the voice pace and the shortcut.
            PrompterSettingsView()
        // Zenith fork: these have pages of their own in the Island group (NotchModulePages),
        // and Batteries keeps its options on its own page under Devices.
        case .music, .notifications, .downloads, .calendar, .timer, .agents, .watch,
             .mixer, .system, .tools, .batteries, .calculator:
            EmptyView()
        }
    }

    // MARK: Activity

    private var activityPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZenithSection(editor.resting) {
                HStack(alignment: .top, spacing: 10) {
                    // With the companion on, the island rests with it when it
                    // has nothing else to show, so that choice is the companion,
                    // unless it hides in the island when idle.
                    idleChoice(.none, title: restsWithMascot ? FeatureStrings.notchMascot(l10n.language).title : text.idleNone,
                               symbol: "minus")
                    if PowerSampler.hasInternalBattery {
                        idleChoice(.battery, title: text.battery, symbol: "battery.75percent",
                                   reason: AppFeature.monitorPower.enableReason(l10n)) { AppFeature.monitorPower.showInFeatures() }
                    }
                    idleChoice(.music, title: text.music, symbol: "music.note",
                               reason: pageReason(.music, feature: nil), fix: pageAction(.music, feature: nil))
                    // Offered once the section is on, and kept while it is the
                    // saved choice, waiting like the others.
                    if NotchSupport.canRest(with: .agents) || idle == NotchIdleContent.agents.rawValue {
                        idleChoice(.agents, title: FeatureStrings.notchAgents(l10n.language).restingTitle, symbol: "sparkles",
                                   reason: pageReason(.agents, feature: .notchAgents), fix: pageAction(.agents, feature: .notchAgents))
                    }
                }
                .padding(.vertical, 10)
                if restingChoice == .battery { lowBatteryControls }
                switchRow("menubar.rectangle", text.coverMenus, caption: text.coverMenusHint, isOn: $coversMenus)
                // Zenith fork: the companion's own page, from where it rests.
                if features.isAvailable(.notchMascot) {
                    ZenithRow(pages.companion, info: pages.companionHint, value: mascotEnabled ? pages.on : pages.off) {
                        router.request(FeatureSettingsDestination(.notchMascot))
                    }
                }
            }
            ZenithSection(editor.feedback) {
                let volumeAvailable = AppFeature.mixer.isAvailable
                let brightnessAvailable = AppFeature.brightness.isAvailable && brightnessControlEnabled
                let keyboardLightAvailable = AppFeature.brightness.isAvailable && BrightnessService.keyboardLightIsSupported
                let microphoneAvailable = AppFeature.micMute.isAvailable
                // A Mac without a battery has no battery notices, so that card
                // is left out rather than shown waiting for Power.
                let hasBattery = PowerSampler.hasInternalBattery
                let batteryAvailable = AppFeature.monitorPower.isAvailable
                let accessoriesAvailable = AppFeature.notchAccessories.isAvailable && AppFeature.monitorPower.isAvailable
                let clipboardAvailable = AppFeature.clipboardHistory.isAvailable && clipboardHistoryEnabled
                    && NotchSupport.modules().contains(.clipboard)
                let capturesAvailable = AppFeature.screenshot.isAvailable && NotchSupport.modules().contains(.captures)
                let musicAvailable = NotchSupport.modules().contains(.music)
                let reserves = ![volumeAvailable, brightnessAvailable, keyboardLightAvailable, microphoneAvailable,
                                 batteryAvailable || !hasBattery, accessoriesAvailable, clipboardAvailable, capturesAvailable,
                                 musicAvailable].allSatisfy { $0 }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 10)], spacing: 10) {
                    toggleCard(text.volume, symbol: "speaker.wave.2", value: $volume, available: volumeAvailable,
                               reason: AppFeature.mixer.enableReason(l10n), reservesReason: reserves,
                               unavailableAction: { AppFeature.mixer.showInFeatures() })
                    toggleCard(text.brightness, symbol: "sun.max", value: $brightness, available: brightnessAvailable,
                               reason: AppFeature.brightness.isAvailable ? editor.enableSetting(FeatureStrings.brightness(l10n.language).enable) : AppFeature.brightness.enableReason(l10n),
                               reservesReason: reserves,
                               unavailableAction: {
                                   if AppFeature.brightness.isAvailable {
                                       router.request(AppFeature.brightness.settingsDestination)
                                   } else {
                                       AppFeature.brightness.showInFeatures()
                                   }
                               })
                    toggleCard(FeatureStrings.brightness(l10n.language).keyboardLight, symbol: "light.max", value: $keyboardLight,
                              available: keyboardLightAvailable,
                              reason: !AppFeature.brightness.isAvailable ? AppFeature.brightness.enableReason(l10n) : editor.keyboardLightUnavailable,
                              reservesReason: reserves,
                              unavailableAction: !AppFeature.brightness.isAvailable ? { AppFeature.brightness.showInFeatures() } : nil)
                    toggleCard(l10n.s.mixerInputTitle, symbol: "mic", value: $microphone, available: microphoneAvailable,
                               reason: AppFeature.micMute.enableReason(l10n), reservesReason: reserves,
                               unavailableAction: { AppFeature.micMute.showInFeatures() })
                    if hasBattery {
                        toggleCard(text.battery, symbol: "battery.75percent", value: $battery, available: batteryAvailable,
                                   reason: AppFeature.monitorPower.enableReason(l10n), reservesReason: reserves,
                                   unavailableAction: { AppFeature.monitorPower.showInFeatures() })
                    }
                    toggleCard(FeatureStrings.notchActivities(l10n.language).accessories, symbol: "headphones", value: $accessoriesEnabled,
                              available: accessoriesAvailable,
                              reason: (AppFeature.monitorPower.isAvailable ? AppFeature.notchAccessories : .monitorPower).enableReason(l10n),
                              reservesReason: reserves,
                              unavailableAction: {
                                  (AppFeature.monitorPower.isAvailable ? AppFeature.notchAccessories : .monitorPower).showInFeatures()
                              })
                    toggleCard(FeatureStrings.clipboard(l10n.language).title, symbol: "doc.on.clipboard", value: $clipboard,
                               available: clipboardAvailable, reason: clipboardFeedbackReason, reservesReason: reserves,
                               unavailableAction: { openClipboardFeedbackSetup() })
                    toggleCard(text.captures, symbol: "camera.viewfinder", value: $capture, available: capturesAvailable,
                               reason: pageReason(.captures, feature: .screenshot), reservesReason: reserves,
                               unavailableAction: pageAction(.captures, feature: .screenshot))
                    toggleCard(text.newTrack, symbol: "music.note", value: $trackChange, available: musicAvailable,
                               reason: pageReason(.music, feature: nil), reservesReason: reserves,
                               unavailableAction: pageAction(.music, feature: nil))
                    // A layout change is read straight from the system, so
                    // this card never waits on another feature.
                    toggleCard(text.inputSource, symbol: "keyboard", value: $inputSource,
                               available: true, reservesReason: reserves)
                }
                .padding(.vertical, 10)
                if accessoriesEnabled {
                    Text(FeatureStrings.notchActivities(l10n.language).accessoryDescription)
                        .font(ZenithType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                }
                if enabled, (volume || brightness || keyboardLight), !permissions.accessibility {
                    PermissionRow(kind: .accessibility).padding(.vertical, 8)
                }
            }
            // Zenith fork: the lock screen's switches have a page of their own (ZenithLockScreenSettings).
            let locked = FeatureStrings.notchLockScreen(l10n.language)
            let lockedPage = ZenithStrings.lockScreenSettings(l10n.language)
            ZenithSection {
                ZenithRow(locked.title, info: lockedPage.movedCaption, value: nil) {
                    router.request(FeatureSettingsDestination(.lockScreen))
                }
            }
            CommandActivitySettings() // Zenith fork: long-running terminal commands in the closed island.
            ExportTrackerSettings() // Zenith fork: renders, recordings and photo exports in the closed island.
            ZenithNoticeSettings() // Zenith fork: capsule notices for battery, headphones and downloads.
        }
    }

    // MARK: Behavior

    private var opening: Binding<NotchOpening> {
        Binding(get: {
            guard hover else { return .click }
            if hideUntilHover { return .hiddenUntilHover }
            return hoverExpand ? .hoverExpand : .hoverPreview
        }, set: { choice in
            switch choice {
            case .click: hideUntilHover = false; hover = false
            case .hoverPreview: hideUntilHover = false; hover = true; hoverExpand = false
            case .hoverExpand: hideUntilHover = false; hover = true; hoverExpand = true
            case .hiddenUntilHover: hover = true; hoverExpand = true; hideUntilHover = true
            }
        })
    }

    private var behaviorPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                ZenithSectionTitle(editor.opening)
                ZenithVisualPicker(editor.opening, selection: opening, options: [
                    ZenithPickerOption(NotchOpening.click, editor.clickOpen),
                    ZenithPickerOption(NotchOpening.hoverPreview, editor.hoverPreview),
                    ZenithPickerOption(NotchOpening.hoverExpand, editor.hoverExpand),
                    ZenithPickerOption(NotchOpening.hiddenUntilHover, editor.hiddenUntilHover),
                ], minimumTileWidth: 120) { item, _ in
                    NotchSymbolTileArt(symbol: item.symbol)
                }
            }
            ZenithSection {
                if hover && hideUntilHover {
                    switchRow("sparkles", editor.hiddenShowsActivity,
                              caption: hiddenShowsActivity ? editor.hiddenShowsActivityHint : nil, isOn: $hiddenShowsActivity)
                }
                if hover || (hideInFullscreen && hoverInFullscreen) {
                    delayRow(editor.activationTime, hint: editor.activationTimeHint, value: $hoverDelay,
                             range: NotchSupport.hoverDelayRange, sanitize: NotchSupport.sanitizedHoverDelay)
                    if hoverExpand {
                        delayRow(editor.closeTime, hint: editor.closeTimeHint, value: $closeDelay,
                                 range: NotchSupport.closeDelayRange, sanitize: NotchSupport.sanitizedCloseDelay)
                    }
                }
                ZenithRow(l10n.s.quickToolShortcutToggle, isOn: $shortcutEnabled,
                          warning: shortcutEnabled && notch.shortcutRegistrationFailed ? l10n.s.shortcutUnavailable : nil)
                if shortcutEnabled {
                    ShortcutPreferenceRow(role: .notch) {
                        NotchService.shared.syncWithPreferences()
                    }
                    .padding(.vertical, 9)
                }
                SettingsFeatureSwitchRow(symbol: "hand.draw", title: FeatureStrings.notchGestures(l10n.language).title,
                                         caption: gesturesEnabled ? FeatureStrings.notchGestures(l10n.language).hint : nil,
                                         isOn: $gesturesEnabled, feature: .notchGestures)
                ZenithMoreOptions(id: "notch.behavior") {
                    switchRow("waveform.path", text.hapticFeedback, isOn: $hapticFeedback)
                    reopeningRow
                    switchRow("livephoto", editor.openActivity, caption: editor.openActivityHint, isOn: $opensActivity)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ZenithSectionTitle(text.display)
                // A mode this version no longer offers is treated as automatic, as the island does.
                ZenithVisualPicker(text.display,
                                   selection: Binding(get: { NotchDisplay(rawValue: display) ?? .automatic },
                                                      set: { display = $0.rawValue }),
                                   options: [ZenithPickerOption(NotchDisplay.automatic, text.automatic),
                                             ZenithPickerOption(NotchDisplay.builtIn, text.builtIn),
                                             ZenithPickerOption(NotchDisplay.main, text.mainDisplay),
                                             ZenithPickerOption(NotchDisplay.pointer, text.followPointer),
                                             ZenithPickerOption(NotchDisplay.all, text.allDisplays)],
                                   minimumTileWidth: 110) { item, _ in
                    NotchSymbolTileArt(symbol: Self.displaySymbol(item))
                }
            }
            ZenithSection {
                switchRow("arrow.up.left.and.arrow.down.right", text.hideInFullscreen, isOn: $hideInFullscreen)
                if hideInFullscreen {
                    switchRow("cursorarrow", text.hoverInFullscreen, isOn: $hoverInFullscreen)
                }
            }
            ZenithSection(editor.destinations, footer: editor.appPanelHint) {
                destination(text.panel, symbol: "bubble.middle.top", value: $appPanel)
                switchRow("menubar.rectangle", editor.hideMenuBarIcon, caption: editor.hideMenuBarIconHint,
                          isOn: $hidesMenuBarIcon)
                destination(text.tools, symbol: NotchModule.tools.symbol, value: $quickPanel, available: AppFeature.quickLauncher.isAvailable)
                destination(FeatureStrings.clipboard(l10n.language).title, symbol: "doc.on.clipboard", value: $clipboardWindow, available: AppFeature.clipboardHistory.isAvailable)
                destination(text.files, symbol: "tray.full", value: $shelfWindow, available: AppFeature.shelf.isAvailable)
                destination(text.captures, symbol: "camera.viewfinder", value: $captureControls)
                destination(FeatureStrings.scratchpad(l10n.language).pageTitle, symbol: "note.text", value: $scratchpad, available: AppFeature.scratchpad.isAvailable)
            }
            ZenithSection(editor.privacy) {
                switchRow("camera.viewfinder", text.showInCaptures, isOn: $showInCaptures)
            }
        }
    }

    private static func displaySymbol(_ display: NotchDisplay) -> String {
        switch display {
        case .automatic: return "display.2"
        case .builtIn: return "laptopcomputer"
        case .main: return "display"
        case .pointer: return "cursorarrow.motionlines"
        case .all: return "rectangle.on.rectangle"
        }
    }

    private var reopeningRow: some View {
        ZenithRow(editor.reopening, selection: Binding(get: {
            guard returnHome else { return "" }
            return NotchModule(rawValue: homeModule) != nil
                || NotchReopeningDestination(rawValue: homeModule) != nil
                ? homeModule : NotchModule.controls.rawValue
        }, set: { value in
            returnHome = !value.isEmpty
            if returnHome { homeModule = value }
        })) {
            Text(editor.lastPage).tag("")
            Text(text.panel).tag(NotchReopeningDestination.appPanel.rawValue)
            Text(text.sectionsTitle).tag(NotchReopeningDestination.explore.rawValue)
            ForEach(NotchSupport.modules()) { module in
                Text(module.title(l10n.language)).tag(module.rawValue)
            }
            if let saved = NotchModule(rawValue: homeModule), !NotchSupport.modules().contains(saved) {
                Text(saved.title(l10n.language)).tag(homeModule).disabled(true)
            }
        }
    }

    /// The resting charge can turn red once it runs low, and amber a little
    /// earlier, at levels the person picks.
    @ViewBuilder private var lowBatteryControls: some View {
        let strings = NotchLowBatteryStrings.localized(l10n.language)
        switchRow("battery.25percent", strings.title, caption: strings.caption, isOn: $lowBatteryTint)
        if lowBatteryTint {
            let red = NotchSupport.sanitizedLowBatteryThreshold(lowBatteryThreshold)
            levelSlider(strings.threshold, range: NotchSupport.batteryLevelScale,
                        value: Binding(get: { red },
                                       set: {
                                           lowBatteryThreshold = NotchSupport.sanitizedLowBatteryThreshold($0)
                                           // Raising red past amber carries amber along above it.
                                           earlyBatteryThreshold = NotchSupport.earlyBatteryThreshold(earlyBatteryThreshold,
                                                                                                     above: lowBatteryThreshold)
                                       }))
            switchRow("battery.50percent", strings.early, caption: strings.earlyCaption, isOn: $earlyBatteryWarning)
            if earlyBatteryWarning {
                // Both sliders share one fixed scale; amber stops just above red.
                levelSlider(strings.earlyThreshold, range: NotchSupport.batteryLevelScale,
                            value: Binding(get: { NotchSupport.earlyBatteryThreshold(earlyBatteryThreshold, above: red) },
                                           set: { earlyBatteryThreshold = NotchSupport.earlyBatteryThreshold($0, above: red) }))
            }
            switchRow("menubar.rectangle", strings.menuBar, isOn: $lowBatteryMenuBar)
        }
    }

    private func levelSlider(_ title: String, range: ClosedRange<Int>, value: Binding<Int>) -> some View {
        let slider = Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) })
        return ZenithRow(title, value: slider, in: Double(range.lowerBound)...Double(range.upperBound), step: 1,
                         valueLabel: "\(value.wrappedValue)%")
    }

    private func delayRow(_ title: String, hint: String, value stored: Binding<Double>,
                          range: ClosedRange<Double>, sanitize: @escaping (Double) -> Double) -> some View {
        let value = Binding(get: { sanitize(stored.wrappedValue) }, set: { stored.wrappedValue = sanitize($0) })
        let formatted = String(format: editor.activationTimeFormat, locale: Locale(identifier: l10n.language.rawValue),
                               value.wrappedValue)
        return ZenithRow(title, value: value, in: range, step: 0.05, info: hint, valueLabel: formatted)
    }

    private func showModule(_ module: NotchModule) {
        selectedModule = module
        tab = .content
    }

    /// A control that opens a page is off while that page is hidden, or while
    /// the feature behind it is disabled; the others follow their feature.
    private func controlReason(_ item: NotchControlItem) -> String {
        // The keyboard light also needs a keyboard that has one.
        if item == .keyboardLight, AppFeature.brightness.isAvailable { return editor.keyboardLightUnavailable }
        switch item.setupRequirement {
        case .feature(let feature): return feature.enableReason(l10n)
        case .page(let module, let feature): return pageReason(module, feature: feature)
        case .none: return text.disabled
        }
    }

    private func controlUnavailableAction(_ item: NotchControlItem) -> (() -> Void)? {
        if item == .keyboardLight, AppFeature.brightness.isAvailable { return nil }
        switch item.setupRequirement {
        case .feature(let feature):
            return { feature.showInFeatures() }
        case .page(let module, let feature):
            return pageAction(module, feature: feature)
        case .none: return nil
        }
    }

    /// The one feature a page needs; Captures and System accept any of several.
    private func moduleFeature(_ module: NotchModule) -> AppFeature? {
        switch module {
        case .controls, .music, .captures, .system: return nil
        case .mixer: return .mixer
        case .clipboard: return .clipboardHistory
        case .files: return .shelf
        case .tools: return .quickLauncher
        case .calendar: return .notchCalendar
        case .notifications: return .notchNotifications
        case .timer: return .notchTimer
        case .camera: return .cameraPreview
        case .downloads: return .notchDownloads
        case .scratchpad: return .scratchpad
        case .agents: return .notchAgents
        case .watch: return .notchWatch
        case .wakatime, .vercel, .github, .cardImport, .devServers, .recap, .sky, .git, .prompter,
             .batteries, .calculator: return nil // Zenith fork: cardImport, devServers, recap, sky, git, prompter, batteries
        }
    }

    private func pageReason(_ module: NotchModule, feature: AppFeature?) -> String {
        if let feature, !feature.isAvailable { return feature.enableReason(l10n) }
        return editor.showPage(module.title(l10n.language))
    }

    /// Where pageReason leads: Features while the feature is uninstalled,
    /// otherwise the section on the Content tab.
    private func pageAction(_ module: NotchModule, feature: AppFeature?) -> () -> Void {
        {
            if let feature, !feature.isAvailable { feature.showInFeatures() }
            else { showModule(module) }
        }
    }

    private var clipboardFeedbackReason: String {
        let title = FeatureStrings.clipboard(l10n.language).title
        if !AppFeature.clipboardHistory.isAvailable { return AppFeature.clipboardHistory.enableReason(l10n) }
        if !clipboardHistoryEnabled { return editor.enableSetting(FeatureStrings.clipboard(l10n.language).enable) }
        return editor.showPage(title)
    }

    private func openClipboardFeedbackSetup() {
        if !AppFeature.clipboardHistory.isAvailable { AppFeature.clipboardHistory.showInFeatures() }
        else if !clipboardHistoryEnabled { router.request(AppFeature.clipboardHistory.settingsDestination) }
        else { showModule(.clipboard) }
    }

    private func toggleCard(_ title: String, symbol: String, value: Binding<Bool>, available: Bool, reason: String? = nil,
                            reservesReason: Bool = false, unavailableAction: (() -> Void)? = nil) -> some View {
        NotchEditorItem(symbol: symbol, title: title, included: value, available: available,
                        unavailableReason: available ? nil : reason ?? text.disabled,
                        unavailableAction: unavailableAction, reservesReason: reservesReason) {
            value.wrappedValue.toggle()
        }
    }

    /// What the closed island rests with while it is on, by its own rule. The
    /// island switch stands apart, so with the island off this still shows
    /// what it would rest with. A saved battery reading on a Mac without a
    /// battery rests with nothing.
    private var restingChoice: NotchIdleContent {
        let choice = NotchSupport.idleContent()
        return choice == .battery && !PowerSampler.hasInternalBattery ? .none : choice
    }

    private var restsWithMascot: Bool {
        enabled && mascotEnabled && !mascotHidesWhenIdle && features.isAvailable(.notchMascot)
    }

    /// The companion where it rests, beside a camera drawn black on black.
    private var restingMascot: some View {
        let look = NotchMascotLook(style: NotchMascotStyle(rawValue: mascotStyle) ?? .satuVisual,
                                   shape: NotchMascotShape(rawValue: mascotShape) ?? .ball,
                                   palette: NotchMascotPalette(rawValue: mascotPalette) ?? .pearl)
        let right = NotchMascotSide(rawValue: mascotSide) == .right
        return HStack(spacing: 14) {
            if right { Color.clear.frame(width: 12, height: 12) }
            else { NotchMascotView(look: look, size: 12, idles: false).frame(width: 12, height: 12) }
            RoundedRectangle(cornerRadius: 4).fill(.black).frame(width: 20, height: 12)
            if right { NotchMascotView(look: look, size: 12, idles: false).frame(width: 12, height: 12) }
            else { Color.clear.frame(width: 12, height: 12) }
        }
    }

    /// A resting choice. One the island cannot rest with just now stays
    /// choosable, dimmed, with what brings it back under it. The choice the
    /// island rests with is marked, and a saved one that waits keeps a fainter
    /// mark.
    private func idleChoice(_ item: NotchIdleContent, title: String, symbol: String,
                            reason: String? = nil, fix: @escaping () -> Void = {}) -> some View {
        let waits = reason != nil && !NotchSupport.canRest(with: item)
        let marked = restingChoice == item || (waits && idle == item.rawValue)
        return VStack(spacing: 6) {
            Button { idle = item.rawValue } label: {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        if item == .none, restsWithMascot {
                            restingMascot
                        } else if item != .none {
                            Image(systemName: symbol).font(.system(size: 11))
                            RoundedRectangle(cornerRadius: 4).fill(.black).frame(width: 20, height: 12)
                            if item == .battery || item == .agents { Text(item == .agents ? "62%" : "76%").font(.system(size: 9, weight: .medium)) }
                            else { Image(systemName: item == .music ? "waveform" : "minus").font(.system(size: 9)) }
                        } else { Color.clear.frame(width: 50, height: 12) }
                    }.foregroundStyle(.white).padding(10).background(.black, in: Capsule())
                    Text(title).font(.system(size: 11, weight: .medium))
                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(marked ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityAddTraits(restingChoice == item ? .isSelected : [])
                // VoiceOver selects what the island rests with. A saved choice
                // that waits says it is hidden from the island, and the link
                // under it says why.
                .accessibilityValue(waits && idle == item.rawValue ? editor.hiddenInIsland : "")
                .opacity(waits ? 0.45 : 1)
            if waits, let reason {
                Button(reason, action: fix)
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func destination(_ title: String, symbol: String, value: Binding<Bool>, available: Bool = true) -> some View {
        SettingsChoiceRow(symbol: symbol, title: title, selection: value) {
            Text(text.title).tag(true)
            Text(editor.separate).tag(false)
        }.disabled(!available)
    }

    /// An option with its icon, one line and a switch, like every other page.
    private func switchRow(_ symbol: String, _ title: String, caption: String? = nil, isOn: Binding<Bool>) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(ZenithSwitchStyle())
        }
    }

    private func dimensionSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, fallback: Double) -> some View {
        let bounded = Binding(get: { NotchSize.clamped(value.wrappedValue, to: range, fallback: fallback) },
                              set: { value.wrappedValue = NotchSize.clamped($0, to: range, fallback: fallback) })
        return ZenithRow(title, value: bounded, in: range, step: 10,
                         valueLabel: Int(bounded.wrappedValue).formatted(.number))
    }

    /// A correction around zero, signed so the untouched value reads as none.
    /// Titled with its kind (capsule or camera), since both share names.
    private func fitSlider(_ title: String, card: String, hint: String? = nil, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double) -> some View {
        let bounded = Binding(get: { NotchSize.clamped(value.wrappedValue, to: range, fallback: 0) },
                              set: { value.wrappedValue = NotchSize.clamped($0, to: range, fallback: 0) })
        let formatted = bounded.wrappedValue.formatted(.number.sign(strategy: .always(includingZero: false))
            .precision(.fractionLength(0...1)).locale(Locale(identifier: l10n.language.rawValue)))
        return ZenithRow("\(card) · \(title)", value: bounded, in: range, step: step, info: hint,
                         valueLabel: formatted.isEmpty ? "0" : formatted)
    }
    private var orderedShortcuts: [NotchControlItem] {
        let stored = controlOrder.split(separator: ",").compactMap { NotchControlItem(rawValue: String($0)) }
        var seen = Set<NotchControlItem>()
        return (stored + NotchControlItem.allCases).filter {
            !$0.isLevel && $0 != .music && seen.insert($0).inserted
        }
    }

    private func controlBinding(_ item: NotchControlItem) -> Binding<Bool> {
        Binding {
            !hiddenControls.split(separator: ",").contains(Substring(item.rawValue))
        } set: { shown in
            var values = Set(hiddenControls.split(separator: ",").map(String.init))
            if shown { values.remove(item.rawValue) } else { values.insert(item.rawValue) }
            hiddenControls = values.sorted().joined(separator: ",")
        }
    }

    private func moduleBinding(_ module: NotchModule) -> Binding<Bool> {
        Binding {
            (module != .timer || timerEnabled) && (module != .camera || cameraEnabled)
                && (module != .calendar || calendarEnabled) && (module != .notifications || notificationsEnabled)
                && (module != .agents || agentsEnabled) && (module != .watch || watchEnabled)
                && (module != .vercel || vercelEnabled) // Zenith fork
                && !hidden.split(separator: ",").contains(Substring(module.rawValue))
        } set: { shown in
            if module == .timer { timerEnabled = shown }
            if module == .camera { cameraEnabled = shown }
            if module == .calendar { calendarEnabled = shown }
            if module == .notifications { notificationsEnabled = shown }
            if module == .agents { agentsEnabled = shown }
            if module == .watch { watchEnabled = shown }
            if module == .vercel { vercelEnabled = shown } // Zenith fork
            var values = Set(hidden.split(separator: ",").map(String.init))
            if shown { values.remove(module.rawValue) } else { values.insert(module.rawValue) }
            hidden = values.sorted().joined(separator: ",")
        }
    }

}

extension NotchControlItem: PanelOrderItem {}

/// How the island opens, the Behavior tab's pictures.
private enum NotchOpening: Hashable {
    case click, hoverPreview, hoverExpand, hiddenUntilHover

    var symbol: String {
        switch self {
        case .click: return "cursorarrow"
        case .hoverPreview: return "rectangle.topthird.inset.filled"
        case .hoverExpand: return "arrow.up.left.and.arrow.down.right"
        case .hiddenUntilHover: return "eye.slash"
        }
    }
}

/// A choice's symbol on a picker tile's stage.
private struct NotchSymbolTileArt: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

/// The open island at each size, drawn small: compact, spacious, or one
/// the person sizes.
private struct NotchSizeTileArt: View {
    let size: NotchSize

    var body: some View {
        let (width, height): (CGFloat, CGFloat) = switch size {
        case .compact: (40, 18)
        case .spacious: (62, 30)
        case .custom: (52, 24)
        }
        RoundedRectangle(cornerRadius: height / 2.6, style: .continuous)
            .fill(Color.black)
            .overlay(RoundedRectangle(cornerRadius: height / 2.6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16)))
            .frame(width: width, height: height)
            .overlay {
                if size == .custom {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

/// A standard menu bar on a display without a camera, at half size, with
/// the resting island in it.
private struct NotchSilhouetteSample: View {
    let silhouette: NotchSilhouette

    var body: some View {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 0,
                                     cameraWidth: 0, menuBarHeight: 24, silhouette: silhouette)
        let island = geometry.restingSize(showsContent: false)
        ZStack(alignment: .top) {
            Rectangle().fill(.primary.opacity(0.08)).frame(height: geometry.menuBarHeight)
            // Menus on the left and status items on the right, clear of the island.
            HStack(spacing: 9) {
                ForEach([26, 36, 30], id: \.self) { width in
                    Capsule().fill(.primary.opacity(0.22)).frame(width: CGFloat(width), height: 8)
                }
                Spacer(minLength: 0)
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.primary.opacity(0.22)).frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: geometry.menuBarHeight)
            NotchShape.island(height: island.height, geometry: geometry).fill(.black)
                .frame(width: island.width, height: island.height)
        }
        .frame(width: 400, height: 48, alignment: .top)
        .background(.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .scaleEffect(0.5)
        .frame(width: 200, height: 24)
        .accessibilityHidden(true)
    }
}
