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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle)
                themeCard.zenithSectionAnchor(.zenithAppearanceTheme)
                motionCard.zenithSectionAnchor(.zenithAppearanceMotion)
                glassCard.zenithSectionAnchor(.zenithAppearanceGlass)
                batteryCard.zenithSectionAnchor(.zenithAppearanceBattery)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
    }

    // MARK: Theme

    private var themeCard: some View {
        SettingsCard(title: text.theme) {
            HStack(spacing: 10) {
                ForEach(AppAppearance.allCases) { option in
                    AppearanceChoiceTile(title: option.title(themeStrings), selected: theme.appearance == option) {
                        theme.appearance = option
                    } picture: {
                        AppearanceThemePicture(option: option)
                    }
                }
            }
            caption(general.appearanceCaption)
            if Self.liquidGlassAvailable {
                Divider()
                ZenithSwitchRow("\(themeStrings.liquidGlass), \(general.liquidGlassOtherWindows)",
                                isOn: $theme.liquidGlassEnabled) {
                    SettingsRow(symbol: "sparkles", title: themeStrings.liquidGlass,
                                caption: "\(general.liquidGlassOtherWindows). \(general.liquidGlassCaption)") { EmptyView() }
                }
            }
        }
    }

    // MARK: Motion

    /// The previews loop only while someone can see them: the page open in a
    /// visible Settings window, without Reduce Motion or battery saving.
    private var previewsPlay: Bool {
        Self.previewsPlay && onScreen && settingsWindow.isVisible && !reduceMotion && !appearance.isSavingBattery
    }

    private var motionCard: some View {
        let motion = appearance.motion
        let previews = previews(motion)
        return SettingsCard(title: text.motion) {
            Group {
                if previewsPlay {
                    TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                        presetTiles(motion, previews: previews, time: context.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    presetTiles(motion, previews: previews, time: nil)
                }
            }
            caption(text.presetCaption(motion.preset))
            Divider()
            sliderRow(symbol: "arrow.up.and.down.circle", title: text.bounce, caption: text.bounceCaption,
                      value: motion.values.bounce, range: IslandMotionValues.bounceRange, step: 0.05,
                      label: text.percent(motion.values.bounce)) { value in
                ZenithAppearanceStore.editCustom(from: appearance.motion) { $0.bounce = value }
            }
            sliderRow(symbol: "aqi.medium", title: text.blur, caption: text.blurCaption,
                      value: motion.values.blur, range: IslandMotionValues.blurRange, step: 0.5,
                      label: text.points(motion.values.blur)) { value in
                ZenithAppearanceStore.editCustom(from: appearance.motion) { $0.blur = value }
            }
            sliderRow(symbol: "rectangle.stack", title: text.contentPace, caption: text.contentPaceCaption,
                      value: motion.values.contentPace, range: IslandMotionValues.paceRange, step: 0.05,
                      label: text.times(motion.values.contentPace)) { value in
                ZenithAppearanceStore.editCustom(from: appearance.motion) { $0.contentPace = value }
            }
            Divider()
            sliderRow(symbol: "speedometer", title: text.speed, caption: text.speedCaption,
                      value: motion.speed, range: IslandMotionSettings.speedRange, step: 0.05,
                      label: text.times(motion.speed), ends: ("tortoise", "hare")) { value in
                ZenithAppearanceStore.setSpeed(value)
            }
            note(symbol: "info.circle", text.customNote)
            note(symbol: "figure.walk.motion", reduceMotion ? text.reduceMotionOn : text.reduceMotionNote)
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
        HStack(spacing: 6) {
            ForEach(previews, id: \.preset) { item in
                AppearanceChoiceTile(title: text.preset(item.preset), symbol: symbol(item.preset),
                                     selected: motion.preset == item.preset, pictureHeight: 58) {
                    ZenithAppearanceStore.selectPreset(item.preset)
                } picture: {
                    AppearanceMotionPicture(frame: time.map { item.preview.frame(at: $0) } ?? .open)
                }
                .help(text.presetCaption(item.preset))
            }
        }
    }

    private func symbol(_ preset: IslandMotionPreset) -> String {
        switch preset {
        case .zenith: return "dot.radiowaves.right"
        case .snappy: return "bolt.fill"
        case .calm: return "leaf"
        case .playful: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }

    // MARK: Glass

    private var glassCard: some View {
        let glass = appearance.glass
        return SettingsCard(title: text.glass) {
            HStack(spacing: 10) {
                ForEach(IslandGlassStyle.allCases) { style in
                    let available = style != .liquid || Self.liquidGlassAvailable
                    AppearanceChoiceTile(title: text.glassStyle(style), selected: glass.style == style,
                                         enabled: available, pictureHeight: 70) {
                        ZenithAppearanceStore.setGlassStyle(style)
                    } picture: {
                        AppearanceGlassPicture(style: style, gradientHeight: glass.gradientHeight, tint: glass.tint)
                    }
                }
            }
            caption(text.glassCaption)
            if !Self.liquidGlassAvailable { caption(text.liquidNeedsMacOS26) }
            if reduceTransparency { note(symbol: "circle.lefthalf.filled", text.reduceTransparencyOn) }
            Divider()
            sliderRow(symbol: "square.tophalf.filled", title: text.gradientHeight, caption: text.gradientHeightCaption,
                      value: glass.gradientHeight, range: 0...1, step: 0.05, label: text.percent(glass.gradientHeight)) {
                ZenithAppearanceStore.setGradientHeight($0)
            }
            .disabled(glass.style != .gradient)
            .opacity(glass.style == .gradient ? 1 : 0.45)
            sliderRow(symbol: "circle.dotted.and.circle", title: text.tint, caption: text.tintCaption,
                      value: glass.tint, range: 0...1, step: 0.05, label: text.percent(glass.tint)) {
                ZenithAppearanceStore.setTint($0)
            }
            .disabled(glass.style == .black)
            .opacity(glass.style == .black ? 0.45 : 1)
        }
    }

    // MARK: Battery

    private var batteryCard: some View {
        SettingsCard(title: text.battery) {
            SettingsRow(symbol: "battery.75percent", title: text.saveBattery,
                        badge: appearance.isSavingBattery ? text.savingNow : nil,
                        caption: text.saveBatteryCaption) {
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
    private func sliderRow(symbol: String, title: String, caption: String, value: Double,
                           range: ClosedRange<Double>, step: Double, label: String,
                           ends: (String, String)? = nil, set: @escaping (Double) -> Void) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            HStack(spacing: 8) {
                if let ends { Image(systemName: ends.0).foregroundStyle(.secondary) }
                Slider(value: Binding(get: { value }, set: { set(($0 / step).rounded() * step) }), in: range)
                    .frame(width: 170)
                    .accessibilityLabel(title)
                    .accessibilityValue(label)
                if let ends { Image(systemName: ends.1).foregroundStyle(.secondary) }
                Text(label)
                    .font(ZenithType.mono(11.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }
        }
    }

    private func caption(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(symbol: String, _ string: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(.secondary)
            caption(string)
        }
    }
}
