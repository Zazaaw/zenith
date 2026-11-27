// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct WindowLayoutSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var service = WindowLayoutService.shared
    @ObservedObject private var maximizer = WindowMaximizer.shared
    @AppStorage(DefaultsKey.windowMaximizeEnabled) private var maximizeEnabled = false
    @ObservedObject private var pointerDisplay = PointerDisplayService.shared
    @AppStorage(DefaultsKey.pointerDisplayEnabled) private var pointerDisplayEnabled = false
    @AppStorage(DefaultsKey.panelUtilityWindowLayout) private var showInPanel = true
    @AppStorage(DefaultsKey.windowLayoutShortcutsEnabled) private var shortcutsEnabled = true
    @AppStorage(DefaultsKey.windowDirectionalEnabled) private var directionalEnabled = false
    @AppStorage(DefaultsKey.windowDirectionalShortcut) private var directionalShortcutRaw = GlobalShortcut.windowDirectionalDefault.storageValue
    @AppStorage(DefaultsKey.windowEdgeSnapEnabled) private var edgeSnapEnabled = false
    @AppStorage(DefaultsKey.windowEdgeSnapDisabledZones) private var edgeSnapDisabledZones = ""
    @AppStorage(DefaultsKey.windowEdgeSnapZoneActions) private var edgeSnapZoneActions = ""
    @AppStorage(DefaultsKey.windowEdgeSnapRestoreOnDrag) private var edgeSnapRestoreOnDrag = false
    @AppStorage(DefaultsKey.windowGestureEnabled) private var gestureEnabled = false
    @AppStorage(DefaultsKey.windowGestureModifiers) private var gestureModifiers = WindowGestureSupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.windowGestureRaiseWindow) private var gestureRaiseWindow = false
    @AppStorage(DefaultsKey.windowLayoutWindowGap) private var windowGap = 0
    @AppStorage(DefaultsKey.windowLayoutScreenGap) private var screenGap = 0
    @AppStorage(DefaultsKey.windowReserveStageManagerSpace) private var reserveStageManagerSpace = false
    @AppStorage(DefaultsKey.windowLayoutMarginPercent) private var marginPercent = WindowLayoutMargin.defaultPercent
    @AppStorage(DefaultsKey.windowLayoutSideRepeatCyclesThirds) private var sideRepeatCyclesThirds = false
    @State private var directionalError: String?
    @State private var systemTilingEnabled = WindowEdgeSnapSupport.isSystemTilingEnabled
    // Same preference the Switcher page exposes next to Dock Preview; it is
    // mirrored here because it is a window-juggling behavior people look for
    // on this page too.
    @AppStorage(DefaultsKey.dockClickCycleWindows) private var dockClickCycleWindows = false

    private var text: WindowLayoutFeatureStrings {
        FeatureStrings.windowLayout(l10n.language)
    }

    private var pageText: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    // Zenith fork: a kit page for window layout and the green button: the
    // hero, the picture, the green button, snapping, the shortcuts, then the
    // placements (halves first, the rest under More options) and the options.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: pageText.windowLayoutSubtitle, chips: chips,
                           animation: .windowLayout)
                if !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithScreenPreviewCard(group: .windowLayout)
                if AppFeature.windowMaximizer.isAvailable {
                    maximizerSection
                }
                if AppFeature.windowLayout.isAvailable {
                    if systemTilingEnabled { systemTilingCallout }
                    snapSection
                    shortcutsSection
                    placementSection
                    otherSection
                }
                if AppFeature.windowLayout.isAvailable || AppFeature.windowMaximizer.isAvailable {
                    optionsSection
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { refreshSystemTilingState() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSystemTilingState()
        }
    }

    private var chips: [ZenithChip] {
        var all: [Bool] = []
        if AppFeature.windowLayout.isAvailable { all += [edgeSnapEnabled, gestureEnabled, shortcutsEnabled] }
        if AppFeature.windowMaximizer.isAvailable { all.append(maximizeEnabled) }
        var chips = [ZenithChip(pageText.onCount(all.filter { $0 }.count, of: all.count))]
        if maximizeEnabled, maximizer.isRunning, AppFeature.windowMaximizer.isAvailable {
            chips.append(ZenithChip(l10n.s.windowMaximizeActiveNow, dot: ZenithStatus.success))
        }
        return chips
    }

    // The green button override keeps this page reachable when it is the
    // only one of the two still switched on in the hub.
    private var maximizerSection: some View {
        ZenithSection(pageText.maximizeSection, anchor: .windowMaximizer) {
            ZenithRow(l10n.s.windowMaximizeName, isOn: $maximizeEnabled, info: l10n.s.windowMaximizeCaption)
                .onChange(of: maximizeEnabled) { _, _ in WindowMaximizer.shared.syncWithPreferences() }
            WindowMaximizerExclusionsList().padding(.vertical, 8)
        }
    }

    private var systemTilingCallout: some View {
        ZenithCallout(.warning, edgeSnapEnabled ? "\(text.edgeSnapSystemConflict) \(text.edgeSnapWaitingForSystem)"
                          : text.edgeSnapSystemConflict) {
            Button(text.edgeSnapOpenSystemSettings) {
                NSWorkspace.shared.open(WindowEdgeSnapSupport.desktopAndDockSettingsURL)
            }
        }
    }

    private var snapSection: some View {
        ZenithSection(text.gestureSection) {
            ZenithRow(text.edgeSnapEnable, isOn: $edgeSnapEnabled, info: text.edgeSnapCaption)
                .onChange(of: edgeSnapEnabled) { _, _ in WindowLayoutService.shared.syncWithPreferences() }
            WindowEdgeSnapZonePicker(disabledZonesStorage: $edgeSnapDisabledZones,
                                     zoneActionsStorage: $edgeSnapZoneActions,
                                     text: text,
                                     resetTitle: l10n.s.shortcutReset)
                .disabled(!edgeSnapEnabled)
                .opacity(edgeSnapEnabled ? 1 : 0.45)
                .padding(.vertical, 10)
                .onChange(of: edgeSnapDisabledZones) { _, _ in WindowLayoutService.shared.syncWithPreferences() }
            ZenithRow(WindowEdgeSnapRestoreStrings.localized(l10n.language).title, isOn: $edgeSnapRestoreOnDrag,
                      info: WindowEdgeSnapRestoreStrings.localized(l10n.language).caption)
                .disabled(!edgeSnapEnabled)
            ZenithRow(text.gestureEnable, isOn: $gestureEnabled, info: text.gestureCaption)
                .onChange(of: gestureEnabled) { _, _ in WindowLayoutService.shared.syncWithPreferences() }
            if gestureEnabled {
                WindowGestureModifierPicker(storageValue: $gestureModifiers, title: text.gestureModifiers)
                    .padding(.vertical, 8)
                    .onChange(of: gestureModifiers) { _, _ in WindowLayoutService.shared.syncWithPreferences() }
                WindowGestureHints(modifierStorage: gestureModifiers, moveText: text.gestureMove,
                                   resizeText: text.gestureResize)
                    .padding(.vertical, 8)
                    .help(text.gestureResizeHint)
                ZenithRow(text.gestureRaiseWindow, isOn: $gestureRaiseWindow, info: text.gestureResizeHint)
            }
        }
    }

    private var shortcutsSection: some View {
        let directional = WindowDirectionalStrings.localized(l10n.language)
        let pointer = PointerDisplayStrings.localized(l10n.language)
        return ZenithSection(text.shortcuts) {
            ZenithRow(text.shortcuts, isOn: $shortcutsEnabled, info: text.shortcutsCaption,
                      warning: service.failedShortcutActions.isEmpty ? nil : l10n.s.shortcutUnavailable)
                .onChange(of: shortcutsEnabled) { _, _ in WindowLayoutService.shared.syncWithPreferences() }
            ZenithRow(directional.title, isOn: $directionalEnabled, info: directional.caption)
                .onChange(of: directionalEnabled) { _, _ in service.syncWithPreferences() }
            if directionalEnabled {
                ZenithRow(directional.title,
                          warning: directionalError ?? (service.directionalShortcutRegistrationFailed
                                                        ? l10n.s.shortcutUnavailable : nil)) {
                    ShortcutRecorderButton(shortcut: directionalKeyShortcut,
                                           isEnabled: permissions.accessibility,
                                           waitingTitle: l10n.s.shortcutPressKeys,
                                           emptyTitle: directionalTrigger.displayString,
                                           notCapturedAction: { directionalError = l10n.s.shortcutNotCaptured },
                                           recordingChanged: { if $0 { directionalError = nil } },
                                           captureModifiersAction: { saveDirectionalTrigger(.modifiers($0)) },
                                           invalidAction: { directionalError = l10n.s.shortcutInvalid },
                                           captureAction: saveDirectionalShortcut)
                        .frame(width: 130)
                }
            }
            // The pointer moves without Accessibility, so this sits outside
            // the window shortcuts switch and works before that grant.
            ZenithRow(pointer.title, isOn: $pointerDisplayEnabled, info: pointer.caption,
                      warning: pointerDisplayEnabled && pointerDisplay.shortcutRegistrationFailed
                          ? l10n.s.shortcutUnavailable : nil)
                .onChange(of: pointerDisplayEnabled) { _, _ in
                    // Also syncs the pointer key, and starts or stops
                    // watching app switches for Ignore apps.
                    service.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .pointerNextDisplay,
                                  isEnabled: pointerDisplayEnabled,
                                  additionalConflict: { service.shortcutConflictTitle($0) }) {
                pointerDisplay.syncWithPreferences()
            }
            .padding(.vertical, 9)
        }
    }

    private var placementSection: some View {
        ZenithSection(pageText.placementsSection) {
            ForEach(Self.halfActions) { action in actionRow(action) }
            ZenithRow(text.sideRepeatCycle, isOn: $sideRepeatCyclesThirds, info: text.sideRepeatCycleCaption)
            ZenithMoreOptions(id: "windowLayout.placements") {
                placementGroup(text.thirds, Self.thirdActions)
                placementGroup(text.quarterRows, Self.quarterRowActions)
                placementGroup(text.quarterColumns, Self.quarterColumnActions)
                placementGroup(text.sixths, Self.sixthActions)
                placementGroup(text.corners, Self.cornerActions)
            }
        }
    }

    /// A family of placements under More options: its name, then its rows.
    @ViewBuilder
    private func placementGroup(_ title: String, _ actions: [WindowLayoutAction]) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
        ForEach(actions) { action in actionRow(action) }
    }

    private var otherSection: some View {
        ZenithSection(text.other) {
            actionRow(.maximize)
            actionRow(.marginMaximize)
            ZenithRow(text.marginPerEdge, value: Binding(
                get: { WindowLayoutMargin.sanitizedPercent(marginPercent) },
                set: { marginPercent = WindowLayoutMargin.sanitizedPercent($0) }
            ), in: WindowLayoutMargin.percentRange, step: 1,
               valueLabel: "\(Int(WindowLayoutMargin.sanitizedPercent(marginPercent).rounded()))%")
            actionRow(.fullScreen)
            actionRow(.center)
            actionRow(.previousDisplay)
            actionRow(.nextDisplay)
            actionRow(.restore)
            if let message = resultMessage {
                Text(message)
                    .font(ZenithType.caption)
                    .foregroundStyle(resultColor)
                    .padding(.vertical, 8)
            }
        }
    }

    private var optionsSection: some View {
        let stageManager = WindowStageManagerStrings.localized(l10n.language)
        return ZenithSection(l10n.s.keepAwakeOptions) {
            if AppFeature.windowLayout.isAvailable {
                ZenithRow(text.showInPanel, isOn: $showInPanel, info: "\(text.caption) \(text.permissionCaption)")
            }
            ZenithRow(stageManager.title, isOn: $reserveStageManagerSpace, info: stageManager.caption)
            if AppFeature.windowLayout.isAvailable {
                ZenithMoreOptions(id: "windowLayout") {
                    gapPicker(text.windowGap, selection: $windowGap)
                    gapPicker(text.screenGap, selection: $screenGap)
                    ZenithRow(l10n.s.dockClickCycleWindows, isOn: $dockClickCycleWindows,
                              info: l10n.s.dockClickCycleWindowsCaption)
                        .onChange(of: dockClickCycleWindows) { _, _ in DockClickService.shared.syncWithPreferences() }
                    WindowLayoutIgnoredAppsList().padding(.vertical, 8)
                }
            }
        }
    }

    private var directionalTrigger: WindowDirectionalTrigger {
        WindowDirectionalTrigger(storageValue: directionalShortcutRaw) ?? .key(.windowDirectionalDefault)
    }

    private var directionalKeyShortcut: GlobalShortcut {
        if case .key(let shortcut) = directionalTrigger { return shortcut }
        return .windowDirectionalDefault
    }

    private func saveDirectionalShortcut(_ shortcut: GlobalShortcut) {
        if let conflict = service.directionalShortcutConflictTitle(shortcut) {
            directionalError = String(format: l10n.s.shortcutConflictFormat, conflict)
            return
        }
        saveDirectionalTrigger(.key(shortcut))
    }

    private func saveDirectionalTrigger(_ trigger: WindowDirectionalTrigger) {
        directionalError = nil
        directionalShortcutRaw = trigger.storageValue
        service.syncWithPreferences()
    }

    /// The gaps take effect on the next placement — the engine reads them
    /// per apply — so the pickers need no service sync.
    private func gapPicker(_ title: String, selection: Binding<Int>) -> some View {
        ZenithRow(title, selection: selection, info: text.gapsCaption) {
            ForEach(WindowLayoutGaps.presets, id: \.self) { value in
                Text(gapPresetTitle(value)).tag(value)
            }
        }
    }

    private func gapPresetTitle(_ value: Int) -> String {
        let name: String
        switch value {
        case 0: return text.gapNone
        case 8: name = text.gapTiny
        case 16: name = text.gapSmall
        case 32: name = text.gapMedium
        case 64: name = text.gapLarge
        case 128: name = text.gapExtraLarge
        default: return "\(value) px"
        }
        return "\(name) (\(value) px)"
    }

    private func refreshSystemTilingState() {
        systemTilingEnabled = WindowEdgeSnapSupport.isSystemTilingEnabled
        WindowLayoutService.shared.syncWithPreferences()
    }

    private static let halfActions: [WindowLayoutAction] = [
        .leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerHalf,
    ]
    private static let thirdActions: [WindowLayoutAction] = [
        .leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds, .centerTwoThirds,
        .topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds,
    ]
    private static let quarterRowActions: [WindowLayoutAction] = [
        .topQuarter, .upperMiddleQuarter, .lowerMiddleQuarter, .bottomQuarter,
    ]
    private static let quarterColumnActions: [WindowLayoutAction] = [
        .leftQuarter, .leftMiddleQuarter, .rightMiddleQuarter, .rightQuarter,
    ]
    private static let sixthActions: [WindowLayoutAction] = [
        .topLeftSixth, .topCenterSixth, .topRightSixth,
        .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth,
    ]
    private static let cornerActions: [WindowLayoutAction] = [
        .topLeft, .topRight, .bottomLeft, .bottomRight,
    ]

    /// One row per action: try-it button on the left, the action's global
    /// shortcut recorder inline on the right — every action is adjustable
    /// right where it lives, no separate shortcut list to hunt for.
    private func actionRow(_ action: WindowLayoutAction) -> some View {
        WindowLayoutActionRow(action: action,
                              title: title(for: action),
                              symbol: symbol(for: action),
                              applyEnabled: permissions.accessibility,
                              shortcutEnabled: shortcutsEnabled && permissions.accessibility)
            .padding(.vertical, 5)
    }

    private func title(for action: WindowLayoutAction) -> String {
        action.title(text)
    }

    private func symbol(for action: WindowLayoutAction) -> String {
        action.symbolName
    }

    private var resultMessage: String? {
        switch service.lastResult {
        case .success(let restored): return restored ? text.restored : text.done
        case .failure(.missingAccessibility): return text.missingPermission
        case .failure(.noWindow): return text.noWindow
        case .failure(.noRestore): return text.noRestore
        case .failure(.failed): return text.failed
        case nil: return nil
        }
    }

    private var resultColor: Color {
        switch service.lastResult {
        case .success: return ZenithStatus.success
        case .failure: return ZenithStatus.warning
        case nil: return .secondary
        }
    }
}

private struct WindowLayoutActionRow: View {
    @ObservedObject private var l10n = L10n.shared
    let action: WindowLayoutAction
    let title: String
    let symbol: String
    let applyEnabled: Bool
    let shortcutEnabled: Bool
    @AppStorage private var rawValue: String
    @State private var errorText: String?
    @State private var isRecording = false
    @State private var pendingTakeOver: GlobalShortcut?

    init(action: WindowLayoutAction,
         title: String,
         symbol: String,
         applyEnabled: Bool,
         shortcutEnabled: Bool) {
        self.action = action
        self.title = title
        self.symbol = symbol
        self.applyEnabled = applyEnabled
        self.shortcutEnabled = shortcutEnabled
        _rawValue = AppStorage(
            wrappedValue: action.defaultShortcut?.storageValue
                ?? WindowLayoutAction.clearedShortcutStorageValue,
            action.shortcutKey
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    WindowLayoutService.shared.apply(action)
                } label: {
                    Label(title, systemImage: symbol)
                }
                .disabled(!applyEnabled)
                Spacer()
                ShortcutRecorderButton(shortcut: pendingTakeOver
                                           ?? shortcut
                                           ?? action.defaultShortcut
                                           ?? .windowLayoutLeftDefault,
                                       isEnabled: shortcutEnabled,
                                       waitingTitle: l10n.s.shortcutPressKeys,
                                       emptyTitle: pendingTakeOver == nil && shortcut == nil ? l10n.s.shortcutNone : nil,
                                       clearAction: clear,
                                       notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
                                       recordingChanged: { recording in
                                           isRecording = recording
                                           if recording {
                                               errorText = nil
                                               pendingTakeOver = nil
                                           }
                                       },
                                       invalidAction: { errorText = l10n.s.shortcutInvalid },
                                       captureAction: save)
                    .frame(width: 108)
                    .disabled(!shortcutEnabled)
                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!shortcutEnabled || shortcut == nil)
                .help(l10n.s.shortcutClear)
                .accessibilityLabel(l10n.s.shortcutClear)
                Button(l10n.s.shortcutReset) {
                    rawValue = action.defaultShortcut?.storageValue
                        ?? WindowLayoutAction.clearedShortcutStorageValue
                    errorText = nil
                    pendingTakeOver = nil
                    SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
                    WindowLayoutService.shared.syncWithPreferences()
                }
                .disabled(!shortcutEnabled || shortcut == action.defaultShortcut)
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(ZenithStatus.warning)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: true))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let pendingTakeOver {
                SystemShortcutTakeOverOffer(
                    shortcut: pendingTakeOver,
                    onAccept: {
                        rawValue = pendingTakeOver.storageValue
                        SystemShortcutTakeover.setTakeOver(action.shortcutKey, true)
                        self.pendingTakeOver = nil
                        WindowLayoutService.shared.syncWithPreferences()
                    },
                    onDismiss: {
                        self.pendingTakeOver = nil
                        errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
                    }
                )
            }
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private var shortcut: GlobalShortcut? {
        WindowLayoutAction.resolvedShortcut(storedValue: rawValue,
                                            defaultShortcut: action.defaultShortcut)
    }

    private func clear() {
        rawValue = WindowLayoutAction.clearedShortcutStorageValue
        errorText = nil
        pendingTakeOver = nil
        SystemShortcutTakeover.setTakeOver(action.shortcutKey, false)
        WindowLayoutService.shared.syncWithPreferences()
    }

    private func save(_ shortcut: GlobalShortcut) {
        if let conflict = GlobalShortcutRole.conflict(for: shortcut, excluding: nil) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
            return
        }
        if let conflict = WindowLayoutService.shared.shortcutConflictTitle(shortcut, excluding: action) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict)
            return
        }
        // The offer is the last word on a combination: every other check has
        // already passed, so accepting it writes exactly what a save writes.
        switch SystemShortcutTakeoverSupport.recorderDecision(
            shortcut: shortcut,
            conflictsWithMacOS: SystemShortcutTakeover.conflictsWithMacOS(shortcut),
            takenOver: SystemShortcutTakeover.isTakenOver(action.shortcutKey),
            current: GlobalShortcut(storageValue: rawValue)) {
        case .offer:
            pendingTakeOver = shortcut
            errorText = nil
            return
        case .save(let clearTakeOver):
            rawValue = shortcut.storageValue
            errorText = nil
            if clearTakeOver { SystemShortcutTakeover.setTakeOver(action.shortcutKey, false) }
        }
        WindowLayoutService.shared.syncWithPreferences()
    }
}
