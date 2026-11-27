// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Appearance, the tile beside General. The theme of
/// Zenith's windows, how the island moves (a style with a looping preview,
/// and its sliders), what the open island is made of, and when it trades its
/// effects for battery. Island choices read and write through
/// `ZenithAppearanceStore`; `ZenithAppearance.shared` publishes them.
struct AppearanceSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var theme = AppAppearanceController.shared
    @ObservedObject private var appearance = ZenithAppearance.shared
    @ObservedObject private var settingsWindow = SettingsWindowVisibility.shared
    @State private var onScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let text = ZenithStrings.appearancePage(.enUS)
    private var themeStrings: AppearanceStrings { FeatureStrings.appearance(l10n.language) }
    private var general: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    /// The catalog draws the previews still, so its pictures do not depend
    /// on the moment they are taken.
    static var previewsPlay = true

    /// Liquid Glass needs macOS 26 and a compiler that knows it.
    static var liquidGlassAvailable: Bool {
#if compiler(>=6.2)
        if #available(macOS 26, *) { return true }
#endif
        return false
    }

    // Zenith fork: a system page of the kit (docs/SETTINGS-KIT.md): the
    // header, then each choice as pictures with its rows in a section.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithSystemHeader(title: text.title, subtitle: text.subtitle)
                themeSection.zenithSectionAnchor(.zenithAppearanceTheme)
                motionSection.zenithSectionAnchor(.zenithAppearanceMotion)
                glassSection.zenithSectionAnchor(.zenithAppearanceGlass)
                batterySection.zenithSectionAnchor(.zenithAppearanceBattery)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
    }

    // MARK: Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.theme)
            ZenithVisualPicker(text.theme, selection: $theme.appearance,
                               options: AppAppearance.allCases.map { ZenithPickerOption($0, $0.title(themeStrings)) },
                               minimumTileWidth: 120, tileHeight: 70) { option, _ in
                AppearanceThemePicture(option: option)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
            }
            ZenithFootnote(general.appearanceCaption)
            if Self.liquidGlassAvailable {
                ZenithSection {
                    ZenithRow(themeStrings.liquidGlass, isOn: $theme.liquidGlassEnabled,
                              info: "\(general.liquidGlassOtherWindows). \(general.liquidGlassCaption)")
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: Motion

    /// The previews loop only while someone can see them: the page open in a
    /// visible Settings window, without Reduce Motion or battery saving.
    private var previewsPlay: Bool {
        Self.previewsPlay && onScreen && settingsWindow.isVisible && !reduceMotion && !appearance.isSavingBattery
    }

    private var motionSection: some View {
        let motion = appearance.motion
        let previews = previews(motion)
        return VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.motion)
            Group {
                if previewsPlay {
                    TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                        presetTiles(motion, previews: previews, time: context.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    presetTiles(motion, previews: previews, time: nil)
                }
            }
            ZenithFootnote(text.presetCaption(motion.preset))
            ZenithSection(footer: reduceMotion ? text.reduceMotionOn : text.reduceMotionNote) {
                sliderRow(title: text.speed, caption: text.speedCaption,
                          value: motion.speed, range: IslandMotionSettings.speedRange, step: 0.05,
                          label: text.times(motion.speed), ends: ("tortoise", "hare")) { value in
                    ZenithAppearanceStore.setSpeed(value)
                }
                ZenithMoreOptions(id: "appearance.motion") {
                    sliderRow(title: text.bounce, caption: text.bounceCaption,
                              value: motion.values.bounce, range: IslandMotionValues.bounceRange, step: 0.05,
                              label: text.percent(motion.values.bounce)) { value in
                        ZenithAppearanceStore.editCustom(from: appearance.motion) { $0.bounce = value }
                    }
                    sliderRow(title: text.blur, caption: text.blurCaption,
                              value: motion.values.blur, range: IslandMotionValues.blurRange, step: 0.5,
                              label: text.points(motion.values.blur)) { value in
                        ZenithAppearanceStore.editCustom(from: appearance.motion) { $0.blur = value }
                    }
                    sliderRow(title: text.contentPace, caption: text.contentPaceCaption,
                              value: motion.values.contentPace, range: IslandMotionValues.paceRange, step: 0.05,
                              label: text.times(motion.values.contentPace)) { value in
                        ZenithAppearanceStore.editCustom(from: appearance.motion) { $0.contentPace = value }
                    }
                    Text(text.customNote)
                        .font(ZenithType.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 9)
                }
            }
            .padding(.top, 8)
        }
    }

    /// Each tile's timing at the chosen speed, worked out once per change
    /// rather than on every frame of the previews.
    private func previews(_ motion: IslandMotionSettings) -> [(preset: IslandMotionPreset, preview: IslandMotionPreview)] {
        let custom = ZenithAppearanceStore.customValues()
        return IslandMotionPreset.allCases.map { preset in
            let values = preset == motion.preset ? motion.values : preset == .custom ? custom : preset.values
            return (preset, IslandMotionPreview(settings: IslandMotionSettings(preset: preset, values: values,
                                                                               speed: motion.speed)))
        }
    }

    private func presetTiles(_ motion: IslandMotionSettings,
                             previews: [(preset: IslandMotionPreset, preview: IslandMotionPreview)],
                             time: Double?) -> some View {
        ZenithVisualPicker(text.motion,
                           selection: Binding(get: { motion.preset }, set: { ZenithAppearanceStore.selectPreset($0) }),
                           options: IslandMotionPreset.allCases.map {
                               ZenithPickerOption($0, text.preset($0), detail: text.presetCaption($0))
                           },
                           minimumTileWidth: 104, tileHeight: 62) { preset, _ in
            let preview = previews.first { $0.preset == preset }?.preview
            AppearanceMotionPicture(frame: time.flatMap { preview?.frame(at: $0) } ?? .open)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(6)
        }
    }

    // MARK: Glass

    private var glassSection: some View {
        let glass = appearance.glass
        return VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.glass)
            // Liquid Glass stays in view where it is missing, and says what it needs.
            ZenithVisualPicker(text.glass,
                               selection: Binding(get: { glass.style }, set: { style in
                                   guard style != .liquid || Self.liquidGlassAvailable else { return }
                                   ZenithAppearanceStore.setGlassStyle(style)
                               }),
                               options: IslandGlassStyle.allCases.map { style in
                                   ZenithPickerOption(style, text.glassStyle(style),
                                                      detail: style == .liquid && !Self.liquidGlassAvailable
                                                          ? text.liquidNeedsMacOS26 : nil)
                               },
                               minimumTileWidth: 140, tileHeight: 76) { style, _ in
                AppearanceGlassPicture(style: style, gradientHeight: glass.gradientHeight, tint: glass.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(6)
                    .opacity(style != .liquid || Self.liquidGlassAvailable ? 1 : 0.45)
            }
            ZenithFootnote(text.glassCaption)
            if !Self.liquidGlassAvailable { ZenithFootnote(text.liquidNeedsMacOS26) }
            if reduceTransparency {
                ZenithCallout(.info, text.reduceTransparencyOn)
            }
            ZenithSection {
                sliderRow(title: text.gradientHeight, caption: text.gradientHeightCaption,
                          value: glass.gradientHeight, range: 0...1, step: 0.05, label: text.percent(glass.gradientHeight)) {
                    ZenithAppearanceStore.setGradientHeight($0)
                }
                .disabled(glass.style != .gradient)
                .opacity(glass.style == .gradient ? 1 : 0.45)
                sliderRow(title: text.tint, caption: text.tintCaption,
                          value: glass.tint, range: 0...1, step: 0.05, label: text.percent(glass.tint)) {
                    ZenithAppearanceStore.setTint($0)
                }
                .disabled(glass.style == .black)
                .opacity(glass.style == .black ? 0.45 : 1)
            }
            .padding(.top, 8)
        }
    }

    // MARK: Battery

    private var batterySection: some View {
        ZenithSection(text.battery) {
            ZenithRow(text.saveBattery, info: text.saveBatteryCaption,
                      badge: appearance.isSavingBattery ? text.savingNow : nil) {
                Picker(text.saveBattery, selection: Binding(get: { appearance.batterySaver },
                                                            set: { ZenithAppearanceStore.setBatterySaver($0) })) {
                    ForEach(IslandBatterySaver.allCases) { saver in
                        Text(text.batterySaver(saver)).tag(saver)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    // MARK: Pieces

    /// A row with a slider and its value. The slider rounds to `step`; the
    /// tortoise and hare, when given, stand at its ends.
    private func sliderRow(title: String, caption: String, value: Double,
                           range: ClosedRange<Double>, step: Double, label: String,
                           ends: (String, String)? = nil, set: @escaping (Double) -> Void) -> some View {
        ZenithRow(title, value: Binding(get: { value }, set: { set(($0 / step).rounded() * step) }), in: range,
                  info: caption, valueLabel: label, minimumSymbol: ends?.0, maximumSymbol: ends?.1)
    }
}
