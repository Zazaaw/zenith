// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the Mouse page, split into the three jobs it held: Scrolling,
// Pointer and Mouse Buttons. Each page opens with its hero and the group's
// picture on the stage, then one section per feature, each with its switch
// first, its options after it and the apps it leaves alone. Every row writes
// the same defaults and syncs the same service as the old page did.

/// The Accessibility grant as a section of its own, while a page needs it.
struct InputWindowsPermissionSection: View {
    var kind: PermissionKind = .accessibility
    var title: String?
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ZenithSection(title ?? l10n.s.permissionRequired) {
            PermissionRow(kind: kind).padding(.vertical, 8)
        }
    }
}

/// The key to hold, as keycaps: one glance says which key, no menu.
struct ScrollModifierKeys: View {
    @Binding var selection: ScrollHorizontalModifier
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let names = FeatureStrings.quitProtection(l10n.language)
        let choices: [(ScrollHorizontalModifier, String, String)] = [
            (.shift, "⇧", names.shiftKey),
            (.option, "⌥", names.optionKey),
            (.control, "⌃", names.controlKey),
            (.command, "⌘", l10n.s.scrollHorizontalCommandKey),
        ]
        HStack(spacing: 6) {
            ForEach(choices, id: \.0) { modifier, glyph, name in
                let selected = selection == modifier
                Button { selection = modifier } label: {
                    HStack(spacing: 5) {
                        Text(verbatim: glyph).font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        Text(name).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selected ? Color.accentColor : .primary)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.14))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Scrolling

struct ScrollingSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var inverter = ScrollInverter.shared
    @AppStorage(DefaultsKey.scrollInverterEnabled) private var invertVertical = false
    @AppStorage(DefaultsKey.scrollInverterHorizontalEnabled) private var invertHorizontal = false
    @AppStorage(DefaultsKey.scrollHorizontalEnabled) private var horizontalScrollEnabled = false
    @AppStorage(DefaultsKey.scrollHorizontalModifier) private var horizontalScrollModifier = ScrollHorizontalModifier.shift
    @AppStorage(DefaultsKey.pinchZoomEnabled) private var pinchZoomEnabled = false
    @AppStorage(DefaultsKey.pinchZoomModifier) private var pinchZoomModifier = ScrollZoomModifier.control.rawValue
    @AppStorage(DefaultsKey.smoothScrollEnabled) private var smoothScrollEnabled = false
    @AppStorage(DefaultsKey.smoothScrollStep) private var smoothScrollStep = SmoothScrollSupport.defaultStep
    @AppStorage(DefaultsKey.smoothScrollResponse) private var smoothScrollResponse = SmoothScrollSupport.defaultResponse
    @AppStorage(DefaultsKey.smoothScrollCoast) private var smoothScrollCoast = SmoothScrollSupport.defaultCoast
    @AppStorage(DefaultsKey.linearScrollEnabled) private var linearScrollEnabled = false
    @AppStorage(DefaultsKey.linearScrollLines) private var linearScrollLines = ScrollWheelSupport.defaultLinesPerNotch
    @AppStorage(DefaultsKey.scrollSpeedEnabled) private var scrollSpeedEnabled = false
    @AppStorage(DefaultsKey.scrollSpeedModifier) private var scrollSpeedModifier = ScrollHorizontalModifier.option
    @AppStorage(DefaultsKey.scrollSpeedMultiplier) private var scrollSpeedMultiplier = ScrollWheelSupport.defaultSpeedMultiplier

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.scrollingTitle, subtitle: text.scrollingSubtitle, chips: chips,
                           animation: .scrolling)
                if engaged && !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithMousePreviewCard(group: .scroll)
                if AppFeature.scrollInverter.isAvailable || AppFeature.scrollHorizontal.isAvailable {
                    direction
                }
                if AppFeature.scrollZoom.isAvailable { zoom }
                if AppFeature.smoothScroll.isAvailable { smooth }
                if AppFeature.linearScroll.isAvailable { linear }
                if AppFeature.scrollSpeed.isAvailable { speed }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var chips: [ZenithChip] {
        let all: [(AppFeature, Bool)] = [
            (.scrollInverter, invertVertical || invertHorizontal), (.scrollHorizontal, horizontalScrollEnabled),
            (.scrollZoom, zoomEnabled), (.smoothScroll, smoothScrollEnabled), (.linearScroll, linearScrollEnabled),
            (.scrollSpeed, scrollSpeedEnabled),
        ].filter { $0.0.isAvailable }
        var chips = [ZenithChip(text.onCount(all.filter(\.1).count, of: all.count))]
        if inversionEnabled, inverter.isRunning { chips.append(ZenithChip(text.activeNow, dot: ZenithStatus.success)) }
        return chips
    }

    // MARK: Direction

    private var direction: some View {
        ZenithSection(text.direction, anchor: .scrollDirection, footer: l10n.s.scrollTrackpadNote) {
            if AppFeature.scrollInverter.isAvailable {
                ZenithRow(l10n.s.invertVerticalScroll, isOn: $invertVertical)
                    .onChange(of: invertVertical) { _, _ in directionChanged() }
                ZenithRow(l10n.s.invertHorizontalScroll, isOn: $invertHorizontal)
                    .onChange(of: invertHorizontal) { _, _ in directionChanged() }
            }
            if AppFeature.scrollHorizontal.isAvailable {
                ZenithRow(l10n.s.scrollHorizontalName, isOn: $horizontalScrollEnabled,
                          info: l10n.s.scrollHorizontalCaption)
                    .onChange(of: horizontalScrollEnabled) { _, _ in directionChanged() }
                if horizontalScrollEnabled {
                    ZenithRow(l10n.s.scrollHorizontalModifierLabel) {
                        ScrollModifierKeys(selection: $horizontalScrollModifier)
                    }
                }
            }
            if directionEnabled {
                MouseExceptionsList(scope: .scrollDirection).padding(.vertical, 8)
            }
        }
    }

    private func directionChanged() {
        ScrollInverter.shared.syncWithPreferences()
        if directionEnabled { permissions.requestAccessibility() }
    }

    // MARK: Zoom

    private var zoom: some View {
        let names = FeatureStrings.quitProtection(l10n.language)
        let modifier = Binding(get: { ScrollZoomModifier(storageValue: pinchZoomModifier) },
                               set: { pinchZoomModifier = $0.rawValue })
        return ZenithSection(text.zoom, anchor: .scrollZoom) {
            ZenithRow(l10n.s.pinchZoom, isOn: $pinchZoomEnabled, info: l10n.s.zoomControlNote)
                .onChange(of: pinchZoomEnabled) { _, active in
                    ScrollInverter.shared.syncWithPreferences()
                    if active { permissions.requestAccessibility() }
                }
            if pinchZoomEnabled {
                ZenithRow(text.scrollKey, selection: modifier) {
                    Text(l10n.s.shortcutNone).tag(ScrollZoomModifier.none)
                    Text("⌥ \(names.optionKey)").tag(ScrollZoomModifier.option)
                    Text("⌃ \(names.controlKey)").tag(ScrollZoomModifier.control)
                    Text("⌘ \(l10n.s.scrollHorizontalCommandKey)").tag(ScrollZoomModifier.command)
                }
                .onChange(of: pinchZoomModifier) { _, _ in ScrollInverter.shared.syncWithPreferences() }
            }
            // Without the direction section on the page, its exceptions live here.
            if !AppFeature.scrollInverter.isAvailable && !AppFeature.scrollHorizontal.isAvailable, directionEnabled {
                MouseExceptionsList(scope: .scrollDirection).padding(.vertical, 8)
            }
        }
    }

    // MARK: Smooth, linear, speed

    private var smooth: some View {
        ZenithSection(l10n.s.smoothScrollName, anchor: .smoothScroll) {
            ZenithRow(l10n.s.smoothScrollName, isOn: $smoothScrollEnabled, info: l10n.s.smoothScrollCaption)
                .onChange(of: smoothScrollEnabled) { _, enabled in
                    SmoothScrollService.shared.syncWithPreferences()
                    if enabled { permissions.requestAccessibility() }
                }
            if smoothScrollEnabled {
                ZenithRow(l10n.s.smoothScrollStepLabel, value: intBinding($smoothScrollStep, SmoothScrollSupport.sanitizedStep),
                          in: range(SmoothScrollSupport.stepRange), step: 10,
                          valueLabel: "\(SmoothScrollSupport.sanitizedStep(smoothScrollStep))")
                MouseExceptionsList(scope: .smoothScroll).padding(.vertical, 8)
                ZenithMoreOptions(id: "scrolling.smooth") {
                    ZenithRow(l10n.s.smoothScrollResponseLabel,
                              value: intBinding($smoothScrollResponse, SmoothScrollSupport.sanitizedResponse),
                              in: range(SmoothScrollSupport.responseRange), step: 5,
                              valueLabel: "\(SmoothScrollSupport.sanitizedResponse(smoothScrollResponse))%")
                    ZenithRow(l10n.s.smoothScrollCoastLabel,
                              value: intBinding($smoothScrollCoast, SmoothScrollSupport.sanitizedCoast),
                              in: range(SmoothScrollSupport.coastRange), step: 5,
                              valueLabel: "\(SmoothScrollSupport.sanitizedCoast(smoothScrollCoast))%")
                }
            }
        }
    }

    private var linear: some View {
        ZenithSection(l10n.s.linearScrollName, anchor: .linearScroll) {
            ZenithRow(l10n.s.linearScrollName, isOn: $linearScrollEnabled, info: l10n.s.linearScrollCaption)
                .onChange(of: linearScrollEnabled) { _, enabled in
                    ScrollInverter.shared.syncWithPreferences()
                    if enabled { permissions.requestAccessibility() }
                }
            if linearScrollEnabled {
                ZenithRow(l10n.s.linearScrollLinesLabel,
                          value: intBinding($linearScrollLines, ScrollWheelSupport.sanitizedLinesPerNotch),
                          in: range(ScrollWheelSupport.linesPerNotchRange), step: 1,
                          valueLabel: "\(ScrollWheelSupport.sanitizedLinesPerNotch(linearScrollLines))")
                MouseExceptionsList(scope: .linearScroll).padding(.vertical, 8)
            }
        }
    }

    private var speed: some View {
        ZenithSection(l10n.s.scrollSpeedName, anchor: .scrollSpeed) {
            ZenithRow(l10n.s.scrollSpeedName, isOn: $scrollSpeedEnabled, info: l10n.s.scrollSpeedCaption)
                .onChange(of: scrollSpeedEnabled) { _, enabled in
                    ScrollInverter.shared.syncWithPreferences()
                    if enabled { permissions.requestAccessibility() }
                }
            if scrollSpeedEnabled {
                ZenithRow(l10n.s.scrollHorizontalModifierLabel) {
                    ScrollModifierKeys(selection: $scrollSpeedModifier)
                }
                .onChange(of: scrollSpeedModifier) { _, _ in ScrollInverter.shared.syncWithPreferences() }
                ZenithRow(l10n.s.scrollSpeedMultiplierLabel,
                          value: intBinding($scrollSpeedMultiplier, ScrollWheelSupport.sanitizedSpeedMultiplier),
                          in: range(ScrollWheelSupport.speedMultiplierRange), step: 1,
                          valueLabel: "\(ScrollWheelSupport.sanitizedSpeedMultiplier(scrollSpeedMultiplier))×")
                MouseExceptionsList(scope: .scrollSpeed).padding(.vertical, 8)
            }
        }
    }

    // MARK: State

    private func intBinding(_ value: Binding<Int>, _ sanitize: @escaping (Int) -> Int) -> Binding<Double> {
        Binding(get: { Double(sanitize(value.wrappedValue)) }, set: { value.wrappedValue = Int($0) })
    }

    private func range(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    private var inversionEnabled: Bool {
        AppFeature.scrollInverter.isAvailable && (invertVertical || invertHorizontal)
    }

    private var zoomEnabled: Bool {
        pinchZoomEnabled && ScrollZoomModifier(storageValue: pinchZoomModifier) != .none
    }

    private var directionEnabled: Bool {
        inversionEnabled
            || (AppFeature.scrollHorizontal.isAvailable && horizontalScrollEnabled)
            || (AppFeature.scrollZoom.isAvailable && zoomEnabled)
    }

    /// Only features that are on and still in Orbit ask for the grant.
    private var engaged: Bool {
        directionEnabled
            || (smoothScrollEnabled && AppFeature.smoothScroll.isAvailable)
            || (linearScrollEnabled && AppFeature.linearScroll.isAvailable)
            || (scrollSpeedEnabled && AppFeature.scrollSpeed.isAvailable)
    }
}

// MARK: - Pointer

struct PointerSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.mouseAccelerationDisabled) private var accelerationDisabled = false
    @AppStorage(DefaultsKey.focusFollowsMouseEnabled) private var focusEnabled = false
    @AppStorage(DefaultsKey.focusFollowsMouseRaise) private var focusRaise = true
    @AppStorage(DefaultsKey.focusFollowsMouseWaitForStop) private var focusWaitForStop = true
    @AppStorage(DefaultsKey.focusFollowsMouseDelay) private var focusDelay = FocusFollowsMouseSupport.defaultDelayMilliseconds

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.pointerTitle, subtitle: text.pointerSubtitle, chips: chips, animation: .pointer)
                if focusEnabled, AppFeature.focusFollowsMouse.isAvailable, !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithMousePreviewCard(group: .pointer)
                if AppFeature.mouseAcceleration.isAvailable {
                    ZenithSection(l10n.s.mouseAccelerationName, anchor: .mouseAcceleration) {
                        ZenithRow(l10n.s.mouseAccelerationName, isOn: $accelerationDisabled,
                                  info: l10n.s.mouseAccelerationCaption)
                            .onChange(of: accelerationDisabled) { _, _ in
                                MouseAccelerationService.shared.syncWithPreferences()
                            }
                    }
                }
                if AppFeature.focusFollowsMouse.isAvailable { focus }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var chips: [ZenithChip] {
        let all: [(AppFeature, Bool)] = [(.mouseAcceleration, accelerationDisabled), (.focusFollowsMouse, focusEnabled)]
            .filter { $0.0.isAvailable }
        return [ZenithChip(text.onCount(all.filter(\.1).count, of: all.count))]
    }

    private var focus: some View {
        ZenithSection(l10n.s.focusFollowsMouseName, anchor: .focusFollowsMouse) {
            ZenithRow(l10n.s.focusFollowsMouseName, isOn: $focusEnabled, info: l10n.s.focusFollowsMouseCaption)
                .onChange(of: focusEnabled) { _, enabled in
                    FocusFollowsMouseService.shared.syncWithPreferences()
                    if enabled { Permissions.shared.requestAccessibility() }
                }
            if focusEnabled {
                ZenithRow(l10n.s.focusFollowsMouseDelay, value: delayBinding,
                          in: Double(FocusFollowsMouseSupport.delayRange.lowerBound)
                              ... Double(FocusFollowsMouseSupport.delayRange.upperBound),
                          step: 50, valueLabel: "\(FocusFollowsMouseSupport.sanitizedDelay(focusDelay)) ms")
                ZenithRow(l10n.s.focusFollowsMouseRaise, isOn: $focusRaise)
                if !focusRaise {
                    ZenithRow(l10n.s.focusFollowsMouseWaitForStop, isOn: $focusWaitForStop)
                }
                MouseExceptionsList(scope: .focusFollowsMouse).padding(.vertical, 8)
            }
        }
    }

    private var delayBinding: Binding<Double> {
        Binding(get: { Double(FocusFollowsMouseSupport.sanitizedDelay(focusDelay)) },
                set: {
                    focusDelay = Int($0)
                    FocusFollowsMouseService.shared.preferencesDidChange()
                })
    }
}

// MARK: - Mouse Buttons

struct MouseButtonsSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var mouseNavigation = MouseNavigationService.shared
    @ObservedObject private var middleClick = MiddleClickService.shared
    @AppStorage(DefaultsKey.mouseNavigationEnabled) private var navigationEnabled = false
    @AppStorage(DefaultsKey.mouseButtonShortcutsEnabled) private var shortcutsEnabled = false
    @AppStorage(DefaultsKey.mouseSpacesGestureEnabled) private var spacesEnabled = false
    @AppStorage(DefaultsKey.middleClickEnabled) private var middleClickEnabled = false
    @AppStorage(DefaultsKey.middleClickTapFingers) private var middleClickTapFingers = 0
    @AppStorage(DefaultsKey.mouseClickDebounceEnabled) private var debounceEnabled = false
    @AppStorage(DefaultsKey.mouseClickDebounceWindowMs) private var debounceWindow = Defaults.defaultMouseClickDebounceWindowMs

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }
    private var debounceText: MouseClickDebounceStrings { FeatureStrings.mouseClickDebounce(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.mouseButtonsTitle, subtitle: text.mouseButtonsSubtitle, chips: chips,
                           animation: .mouseButtons)
                if engaged, !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithMousePreviewCard(group: .buttons)
                if AppFeature.mouseNavigation.isAvailable { navigation }
                if AppFeature.mouseButtonShortcuts.isAvailable { MouseButtonShortcutsSection() }
                if AppFeature.middleClick.isAvailable { middle }
                if AppFeature.mouseClickDebounce.isAvailable { debounce }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { MiddleClickService.shared.refreshDragGestureConflict() }
    }

    private var chips: [ZenithChip] {
        let all: [(AppFeature, Bool)] = [
            (.mouseNavigation, navigationEnabled), (.mouseButtonShortcuts, shortcutsEnabled || spacesEnabled),
            (.middleClick, middleClickEnabled), (.mouseClickDebounce, debounceEnabled),
        ].filter { $0.0.isAvailable }
        var chips = [ZenithChip(text.onCount(all.filter(\.1).count, of: all.count))]
        if navigationEnabled, mouseNavigation.isRunning {
            chips.append(ZenithChip(text.activeNow, dot: ZenithStatus.success))
        }
        return chips
    }

    private var navigation: some View {
        ZenithSection(l10n.s.mouseNavigationSection, anchor: .mouseNavigation) {
            ZenithRow(l10n.s.mouseNavigationEnable, isOn: $navigationEnabled, info: l10n.s.mouseNavigationCaption,
                      essential: navigationEnabled && mouseNavigation.isRunning ? l10n.s.mouseNavigationActiveNow : nil)
                .onChange(of: navigationEnabled) { _, enabled in
                    MouseNavigationService.shared.syncWithPreferences()
                    if enabled { permissions.requestAccessibility() }
                }
            if navigationEnabled {
                MouseExceptionsList(scope: .navigation).padding(.vertical, 8)
            }
        }
    }

    private var middle: some View {
        let fingers = Binding(get: { middleClickTapFingers }, set: { value in
            middleClickTapFingers = value
            MiddleClickService.shared.syncWithPreferences()
        })
        return ZenithSection(l10n.s.middleClickSection, anchor: .middleClick) {
            ZenithRow(l10n.s.middleClickEnable, isOn: $middleClickEnabled, info: l10n.s.middleClickEnableCaption)
                .onChange(of: middleClickEnabled) { _, enabled in
                    MiddleClickService.shared.syncWithPreferences()
                    if enabled { permissions.requestAccessibility() }
                }
            if middleClickEnabled {
                ZenithRow(l10n.s.middleClickTapPicker, info: l10n.s.middleClickTapCaption,
                          essential: middleClick.systemDragGestureConflict ? l10n.s.middleClickDragConflict : nil,
                          warning: middleClick.touchDeviceMissing ? l10n.s.middleClickNoTrackpad : nil) {
                    Picker(l10n.s.middleClickTapPicker, selection: fingers) {
                        Text(l10n.s.middleClickTapOff).tag(0)
                        Text(l10n.s.middleClickTapThreeFingers).tag(3)
                        Text(l10n.s.middleClickTapFourFingers).tag(4)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                MouseExceptionsList(scope: .middleClick).padding(.vertical, 8)
            }
        }
    }

    private var debounce: some View {
        let window = Binding(get: { Defaults.sanitizedMouseClickDebounceWindow(debounceWindow) }, set: {
            debounceWindow = Defaults.sanitizedMouseClickDebounceWindow($0)
            MouseClickDebounceService.shared.syncWithPreferences()
        })
        return ZenithSection(debounceText.title, anchor: .mouseClickDebounce) {
            ZenithRow(debounceText.title, isOn: $debounceEnabled, info: debounceText.caption)
                .onChange(of: debounceEnabled) { _, enabled in
                    MouseClickDebounceService.shared.syncWithPreferences()
                    if enabled { permissions.requestAccessibility() }
                }
            if debounceEnabled {
                ZenithRow(debounceText.windowLabel, value: window, in: Defaults.allowedMouseClickDebounceWindowRange,
                          info: debounceText.windowCaption, format: { "\($0) ms" })
            }
        }
    }

    private var engaged: Bool {
        (navigationEnabled && AppFeature.mouseNavigation.isAvailable)
            || ((shortcutsEnabled || spacesEnabled) && AppFeature.mouseButtonShortcuts.isAvailable)
            || (debounceEnabled && AppFeature.mouseClickDebounce.isAvailable)
            || (middleClickEnabled && AppFeature.middleClick.isAvailable)
    }
}
