// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Settings → System Monitor. Zenith fork: built with the Settings kit. The
/// metrics as tiles, each with its own switch (it installs or removes the
/// metric, as Orbit does) and its options in a section under the grid; then
/// what the menu bar shows and how, the panel's blocks, the readings both
/// share, and the alerts. Fan Control has a page of its own.
struct MonitorSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    @AppStorage(DefaultsKey.menuBarCombineTemperatures) private var combineTemperatures = true
    @AppStorage(DefaultsKey.menuBarSeparateMetrics) private var separateMetrics = false
    @AppStorage(DefaultsKey.menuBarMetricSpacing) private var metricSpacing = "standard"
    @AppStorage(DefaultsKey.menuBarMetricAppearance) private var metricAppearance = "values"
    @AppStorage(DefaultsKey.menuBarHideIconWithMetrics) private var hideIconWithMetrics = false
    @AppStorage(DefaultsKey.monitorInterval) private var interval = 2
    @AppStorage(DefaultsKey.monitorGraphScale) private var graphScale = true
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.networkSpeedUnit) private var networkSpeedUnit = NetworkSpeedUnit.bytes
    @AppStorage(DefaultsKey.monitorMemoryMetric) private var memoryMetric = "used"
    @AppStorage(DefaultsKey.menuBarMemoryStyle) private var memoryStyle = "percent"
    @AppStorage(DefaultsKey.menuBarNetworkUploadFirst) private var uploadFirst = false
    @AppStorage(DiskMenuBarStyle.defaultsKey) private var diskStyle = DiskMenuBarStyle.percent
    @AppStorage(DefaultsKey.menuBarMetricOrder) private var metricOrder = ""
    @State private var picked: AppFeature?

    private let page = ZenithStrings.systemApps(.enUS)

    var body: some View {
        // A plain stack, not a lazy one: a lazy stack estimates the rows it
        // has not built yet, and with the taller Bars options this page kept
        // it re-measuring and re-anchoring without ever settling, which hung
        // Settings on the first scroll.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: page.monitorTitle, subtitle: page.monitorSubtitle, chips: chips,
                           animation: .systemMonitor)
                ZenithScreenPreviewCard(group: .monitor)
                metricsSection
                metricSection(selected)
                menuBarSection
                panelSection
                readingsSection
                ZenithSection(FeatureStrings.monitorAlerts(l10n.language).section, anchor: .monitorAlerts) {
                    MonitorAlertsControls(compact: false).padding(.vertical, 10)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(ZenithSwitchStyle())
        .onAppear {
            interval = Defaults.sanitizedMonitorInterval(interval)
            metricAppearance = Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)
            if TemperatureUnit(rawValue: temperatureUnit) == nil {
                temperatureUnit = TemperatureUnit.celsius.rawValue
            }
            memoryMetric = Defaults.sanitizedMonitorMemoryMetric(memoryMetric)
        }
    }

    private var chips: [ZenithChip] {
        let on = MonitorMetricFamily.allCases.filter { $0.feature.isAvailable }.count
        let shown = MenuBarMetric.enabled(in: .standard).count
        return [ZenithChip(page.monitorOn(on)), ZenithChip(page.monitorShown(shown)),
                ZenithChip(page.monitorEvery(Defaults.sanitizedMonitorInterval(interval)))]
    }

    /// The metric whose options show under the grid: the one clicked, or the
    /// first one switched on.
    private var selected: MonitorMetricFamily {
        if let picked, let family = MonitorMetricFamily(feature: picked) { return family }
        return MonitorMetricFamily.allCases.first { $0.feature.isAvailable } ?? .cpu
    }

    private func title(_ family: MonitorMetricFamily) -> String {
        family.feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language), language: l10n.language)
    }

    // MARK: Metrics

    private var metricsSection: some View {
        ZenithSection(page.monitorMetrics, footer: page.monitorMetricsFooter) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(MonitorMetricFamily.allCases) { family in
                    MonitorMetricTile(family: family, title: title(family), selected: family == selected) {
                        picked = family.feature
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    /// The chosen metric's own options: what of it the menu bar shows, and
    /// the choices that only it has.
    @ViewBuilder
    private func metricSection(_ family: MonitorMetricFamily) -> some View {
        ZenithSection(title(family)) {
            if !family.feature.isAvailable {
                ZenithCallout(.info, page.monitorMetricOff) {
                    Button(page.monitorTurnOn) { FeatureRuntime.shared.setAvailable([family.feature], true) }
                }
                .padding(.vertical, 10)
            } else {
                ForEach(family.menuBarMetrics) { metric in
                    MonitorMenuBarSwitchRow(metric: metric, title: "\(page.monitorInMenuBar): \(metric.title(l10n.s))")
                }
                switch family {
                case .memory:
                    ZenithRow(l10n.s.monitorMemoryPressureDot, isOn: Binding(
                        get: { Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent" },
                        set: { memoryStyle = $0 ? "both" : "percent" }))
                    ZenithRow(l10n.s.monitorMemoryMetricLabel, selection: $memoryMetric) {
                        Text(l10n.s.memoryMetricUsed).tag("used")
                        Text(l10n.s.memoryMetricApp).tag("app")
                    }
                case .network:
                    ZenithRow(l10n.s.monitorNetworkUploadFirst, isOn: $uploadFirst)
                    ZenithRow(FeatureStrings.monitorLayout(l10n.language).networkSpeedUnit, selection: $networkSpeedUnit) {
                        Text(verbatim: "MB/s").tag(NetworkSpeedUnit.bytes)
                        Text(verbatim: "Mbps").tag(NetworkSpeedUnit.bits)
                    }
                case .disk:
                    ZenithRow(l10n.s.diskMenuBarStyleLabel, selection: $diskStyle) {
                        Text(l10n.s.diskMenuBarUsedPercentage).tag(DiskMenuBarStyle.percent)
                        Text(l10n.s.diskMenuBarAvailableSpace).tag(DiskMenuBarStyle.free)
                        Text(l10n.s.diskMenuBarUsedSpace).tag(DiskMenuBarStyle.used)
                    }
                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: Menu bar

    private var appearanceStrings: MenuBarAppearanceStrings {
        FeatureStrings.menuBarAppearance(l10n.language)
    }

    private var appearance: MenuBarMetricAppearance {
        MenuBarMetricAppearance(rawValue: Defaults.sanitizedMenuBarMetricAppearance(metricAppearance)) ?? .values
    }

    private var appearanceBinding: Binding<MenuBarMetricAppearance> {
        Binding(get: { appearance }, set: { metricAppearance = $0.rawValue })
    }

    /// How the readings look in the menu bar: values or bars as pictures,
    /// then spacing and the icon; the order and the bars' colours fold away.
    private var menuBarSection: some View {
        ZenithSection(page.monitorMenuBar, footer: l10n.s.monitorMenuBarCaption) {
            VStack(alignment: .leading, spacing: 8) {
                ZenithRow(appearanceStrings.label, info: appearanceStrings.caption) { EmptyView() }
                ZenithVisualPicker(appearanceStrings.label, selection: appearanceBinding, options: [
                    ZenithPickerOption(.values, appearanceStrings.values, detail: page.monitorValuesDetail),
                    ZenithPickerOption(.bars, appearanceStrings.bars, detail: page.monitorBarsDetail),
                ], minimumTileWidth: 150, tileHeight: 56) { value, _ in
                    MenuBarStyleArt(appearance: value)
                }
            }
            .padding(.bottom, 12)
            if appearance.allowsCombinedTemperatures {
                ZenithRow(l10n.s.monitorCombineTemperatures, isOn: $combineTemperatures,
                          info: l10n.s.monitorCombineTemperaturesCaption)
            }
            ZenithRow(l10n.s.menuBarSpacingLabel, selection: $metricSpacing) {
                Text(l10n.s.menuBarSpacingStandard).tag("standard")
                Text(l10n.s.menuBarSpacingCompact).tag("compact")
            }
            ZenithRow(l10n.s.menuBarHideIconToggle, isOn: $hideIconWithMetrics, info: l10n.s.menuBarHideIconCaption)
            ZenithMoreOptions(id: "monitor.menuBar") {
                ZenithRow(l10n.s.monitorSeparateMenuBarMetrics, isOn: $separateMetrics,
                          info: appearance.allowsCombinedTemperatures
                            ? l10n.s.monitorSeparateMenuBarMetricsCaption : nil)
                VStack(alignment: .leading, spacing: 8) {
                    ZenithRow(page.monitorOrder, info: FeatureStrings.notchEditor(l10n.language).reorderHint) {
                        EmptyView()
                    }
                    MenuBarMetricTiles()
                }
                .padding(.bottom, 12)
                if appearance == .bars {
                    MenuBarUsageBarSettings(strings: appearanceStrings).padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: Panel and readings

    private var panelSection: some View {
        ZenithSection(page.monitorPanel, footer: l10n.s.monitorPanelConfigHint) {
            MonitorPanelConfig(tiles: true).padding(.vertical, 12)
            ZenithRow(GraphScaleStrings.localized(l10n.language).title, isOn: $graphScale)
        }
    }

    private var readingsSection: some View {
        ZenithSection(page.monitorReadings) {
            ZenithRow(l10n.s.monitorIntervalLabel, selection: $interval) {
                Text(l10n.s.monitorInterval1).tag(1)
                Text(l10n.s.monitorInterval2).tag(2)
                Text(l10n.s.monitorInterval5).tag(5)
            }
            ZenithRow(l10n.s.temperatures, selection: $temperatureUnit) {
                Text(verbatim: "°C").tag(TemperatureUnit.celsius.rawValue)
                Text(verbatim: "°F").tag(TemperatureUnit.fahrenheit.rawValue)
            }
        }
    }
}

/// The metric families System Monitor's tiles stand for, one hub feature
/// each, in the panel's order.
enum MonitorMetricFamily: CaseIterable, Identifiable {
    case cpu, gpu, memory, network, disk, power, devices

    var id: Self { self }

    init?(feature: AppFeature) {
        guard let family = Self.allCases.first(where: { $0.feature == feature }) else { return nil }
        self = family
    }

    var feature: AppFeature {
        switch self {
        case .cpu: return .monitorCPU
        case .gpu: return .monitorGPU
        case .memory: return .monitorMemory
        case .network: return .monitorNetwork
        case .disk: return .monitorDisk
        case .power: return .monitorPower
        case .devices: return .connectedDevices
        }
    }

    var symbol: String { feature.symbolName }

    /// The menu bar readings of this family this Mac can show.
    var menuBarMetrics: [MenuBarMetric] {
        MenuBarMetric.allCases.filter { $0.feature == feature && $0.isAvailableOnCurrentHardware }
    }
}

/// One metric: its picture on the stage (click it for the metric's options)
/// and its switch.
private struct MonitorMetricTile: View {
    let family: MonitorMetricFamily
    let title: String
    let selected: Bool
    let select: () -> Void
    @ObservedObject private var features = FeatureRuntime.shared
    @Environment(\.zenithTint) private var tint
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let on = family.feature.isAvailable
        VStack(spacing: 8) {
            Button(action: select) {
                ZStack {
                    ZenithStageGradient(tint: tint, dark: colorScheme == .dark)
                    Image(systemName: family.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(on ? 0.95 : 0.45))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(shape)
                .overlay(shape.strokeBorder(selected ? Color.accentColor
                                                : Color.primary.opacity(contrast == .increased ? 0.3 : 0.08),
                                            lineWidth: selected ? 2.5 : 1))
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                ZenithRowSwitch(title: title, isOn: Binding(
                    get: { family.feature.isAvailable },
                    set: { FeatureRuntime.shared.setAvailable([family.feature], $0) }))
                    .scaleEffect(0.85)
            }
        }
    }
}

/// A switch for one menu bar reading, backed by its own key.
private struct MonitorMenuBarSwitchRow: View {
    let title: String
    @AppStorage private var shown: Bool

    init(metric: MenuBarMetric, title: String) {
        self.title = title
        _shown = AppStorage(wrappedValue: false, metric.defaultsKey)
    }

    var body: some View {
        ZenithRow(title, isOn: $shown)
    }
}

/// Values or bars, drawn the way the menu bar would draw a CPU reading.
private struct MenuBarStyleArt: View {
    let appearance: MenuBarMetricAppearance

    var body: some View {
        mockup
            .frame(width: 110, height: 34)
            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // The same proportions the real blocks use (MenuBarRenderer), reduced to
    // a CPU sample so the two styles read as themselves.
    @ViewBuilder
    private var mockup: some View {
        switch appearance {
        case .values:
            HStack(spacing: 10) {
                block(label: "CPU", value: "42%")
                block(label: "RAM", value: "61%")
            }
        case .bars:
            HStack(spacing: 10) {
                bar(label: "CPU", fraction: 0.42)
                bar(label: "RAM", fraction: 0.61)
            }
        }
    }

    private func block(label: String, value: String) -> some View {
        VStack(spacing: -1) {
            Text(label)
                .font(.system(size: 6.6, weight: .medium))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.white)
    }

    private func bar(label: String, fraction: CGFloat) -> some View {
        HStack(spacing: 2) {
            VStack(spacing: -1.8) {
                ForEach(Array(label.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(.system(size: 6.1, weight: .semibold))
                }
            }
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                    .stroke(Color.white, lineWidth: 1.15)
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(Color(red: 0.39, green: 0.82, blue: 1.0))
                    .frame(width: 4.8, height: 13.8 * fraction)
                    .padding(.bottom, 2.1)
            }
            .frame(width: 9, height: 18)
        }
        .foregroundStyle(.white)
    }
}

/// The menu bar readings as tiles: drag to put them in order, click the
/// checkmark to show or hide one. The order stays independent from which
/// metrics are visible, so toggles do not reshuffle it.
private struct MenuBarMetricTiles: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.menuBarMetricOrder) private var metricOrder = ""
    @State private var order: [MenuBarMetric] = MenuBarMetric.order(in: .standard)
    @State private var dragging: MenuBarMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: monitorTokenColumns, spacing: 8) {
                ForEach(visibleOrder) { metric in
                    // Dragging moves within the full saved order, so metrics
                    // hidden by the hub keep their slot for their return.
                    PanelReorderableItem(item: metric, order: $order, dragging: $dragging) {
                        MenuBarMetricTile(metric: metric)
                    }
                }
            }
            .monitorTokenGroup()
        }
        .onAppear { order = MenuBarMetric.order(in: .standard) }
        .onChange(of: order) { _, order in
            // Only a drag writes; reloading the saved order must not.
            if order != MenuBarMetric.order(in: .standard) { MenuBarMetric.setOrder(order) }
        }
        .onChange(of: metricOrder) { _, _ in order = MenuBarMetric.order(in: .standard) }
    }

    /// Metrics whose family left the hub keep their saved slot but stay out
    /// of the editor until they return.
    private var visibleOrder: [MenuBarMetric] {
        order.filter { $0.feature.isAvailable && $0.isAvailableOnCurrentHardware }
    }
}

extension MenuBarMetric: PanelOrderItem {}

/// One reading, backed by its own key so the preview above updates the
/// moment it is ticked. A reading with its own option carries it in its card.
private struct MenuBarMetricTile: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let metric: MenuBarMetric
    @AppStorage private var shown: Bool
    @AppStorage(DefaultsKey.menuBarMemoryStyle) private var memoryStyle = "percent"
    @AppStorage(DefaultsKey.menuBarNetworkUploadFirst) private var uploadFirst = false
    @AppStorage(DiskMenuBarStyle.defaultsKey) private var diskStyle = DiskMenuBarStyle.percent

    init(metric: MenuBarMetric) {
        self.metric = metric
        _shown = AppStorage(wrappedValue: false, metric.defaultsKey)
    }

    var body: some View {
        MonitorToken(symbol: metric.symbolName, title: metric.title(l10n.s), included: $shown,
                     options: options, optionsSummary: optionsSummary)
    }

    /// What the reading's option makes the menu bar show, in its own terms.
    private var optionsSummary: String {
        switch metric {
        case .memory:
            return Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent"
                ? l10n.s.monitorMemoryPressureDot : FeatureStrings.mouseClickDebounce(l10n.language).moreOptions
        case .network: return uploadFirst ? "↑ ↓" : "↓ ↑"
        case .diskUsage:
            switch diskStyle {
            case DiskMenuBarStyle.free: return l10n.s.diskMenuBarAvailableSpace
            case DiskMenuBarStyle.used: return l10n.s.diskMenuBarUsedSpace
            default: return l10n.s.diskMenuBarUsedPercentage
            }
        default: return ""
        }
    }

    private var options: AnyView? {
        switch metric {
        case .memory:
            return AnyView(MonitorTokenOption(
                symbol: "circle.fill",
                title: l10n.s.monitorMemoryPressureDot,
                tint: ZenithStatus.success,
                isOn: Binding(get: { Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent" },
                              set: { memoryStyle = $0 ? "both" : "percent" })))
        case .network:
            return AnyView(MonitorTokenOption(symbol: "arrow.up.arrow.down",
                                                 title: l10n.s.monitorNetworkUploadFirst,
                                                 isOn: $uploadFirst))
        case .diskUsage:
            return AnyView(Picker(l10n.s.diskMenuBarStyleLabel, selection: $diskStyle) {
                Text(l10n.s.diskMenuBarUsedPercentage).tag(DiskMenuBarStyle.percent)
                Text(l10n.s.diskMenuBarAvailableSpace).tag(DiskMenuBarStyle.free)
                Text(l10n.s.diskMenuBarUsedSpace).tag(DiskMenuBarStyle.used)
            }
            .pickerStyle(.menu))
        default:
            return nil
        }
    }
}

private struct MenuBarUsageBarSettings: View {
    let strings: MenuBarAppearanceStrings

    @AppStorage(DefaultsKey.menuBarUsageBarNormalColor) private var normalColor = MenuBarUsageBarSupport.defaultNormalColor
    @AppStorage(DefaultsKey.menuBarUsageBarElevatedColor) private var elevatedColor = MenuBarUsageBarSupport.defaultElevatedColor
    @AppStorage(DefaultsKey.menuBarUsageBarCriticalColor) private var criticalColor = MenuBarUsageBarSupport.defaultCriticalColor
    @AppStorage(DefaultsKey.menuBarUsageBarMediumThreshold) private var mediumThreshold = MenuBarUsageBarSupport.defaultMediumThreshold
    @AppStorage(DefaultsKey.menuBarUsageBarHighThreshold) private var highThreshold = MenuBarUsageBarSupport.defaultHighThreshold

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(strings.customize)
                .font(.subheadline.weight(.semibold))

            ColorPicker(strings.normalColor,
                        selection: colorBinding($normalColor,
                                                fallback: MenuBarUsageBarSupport.defaultNormalColor),
                        supportsOpacity: false)
            ColorPicker(strings.mediumColor,
                        selection: colorBinding($elevatedColor,
                                                fallback: MenuBarUsageBarSupport.defaultElevatedColor),
                        supportsOpacity: false)
            ColorPicker(strings.highColor,
                        selection: colorBinding($criticalColor,
                                                fallback: MenuBarUsageBarSupport.defaultCriticalColor),
                        supportsOpacity: false)

            Divider()

            Stepper(value: mediumBinding, in: 1...99) {
                HStack {
                    Text(strings.mediumFrom)
                    Spacer()
                    Text("\(mediumThreshold)%")
                        .monospacedDigit()
                }
            }
            Stepper(value: highBinding, in: 2...100) {
                HStack {
                    Text(strings.highFrom)
                    Spacer()
                    Text("\(highThreshold)%")
                        .monospacedDigit()
                }
            }
        }
        .onAppear(perform: sanitize)
    }

    private var mediumBinding: Binding<Int> {
        Binding(get: { mediumThreshold },
                set: { mediumThreshold = min(max(1, $0), max(1, highThreshold - 1)) })
    }

    private var highBinding: Binding<Int> {
        Binding(get: { highThreshold },
                set: { highThreshold = min(100, max(mediumThreshold + 1, $0)) })
    }

    private func colorBinding(_ storage: Binding<String>, fallback: String) -> Binding<Color> {
        Binding {
            let rgb = MenuBarUsageBarSupport.rgb(for: storage.wrappedValue, fallback: fallback)
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } set: { color in
            guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return }
            storage.wrappedValue = MenuBarUsageBarSupport.hex(red: Double(converted.redComponent),
                                                              green: Double(converted.greenComponent),
                                                              blue: Double(converted.blueComponent))
        }
    }

    private func sanitize() {
        normalColor = MenuBarUsageBarSupport.sanitizedColorHex(normalColor,
                                                               fallback: MenuBarUsageBarSupport.defaultNormalColor)
        elevatedColor = MenuBarUsageBarSupport.sanitizedColorHex(elevatedColor,
                                                                 fallback: MenuBarUsageBarSupport.defaultElevatedColor)
        criticalColor = MenuBarUsageBarSupport.sanitizedColorHex(criticalColor,
                                                                 fallback: MenuBarUsageBarSupport.defaultCriticalColor)
        let thresholds = MenuBarUsageBarSupport.thresholds(medium: mediumThreshold,
                                                           high: highThreshold)
        mediumThreshold = thresholds.medium
        highThreshold = thresholds.high
    }
}
