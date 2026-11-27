// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import AppKit
import SwiftUI

/// Zenith fork: Settings → Batteries, built with the Settings kit. The switch
/// for the whole feature in the hero, the island page's layout as pictures, the devices with their alert switches
/// (and the hidden ones, to show again), when to warn, and the iPhone, iPad
/// and Apple Watch readings with the libimobiledevice they need. Everything
/// reads `BatteriesStore.shared` and writes `BatteriesDefaults`; a change asks
/// the monitor for a scan.
struct BatteriesSettingsPage: View {
    @ObservedObject private var store = BatteriesStore.shared
    @ObservedObject private var homebrew = HomebrewManager.shared
    @AppStorage(BatteriesDefaults.enabled) private var enabled = true
    @AppStorage(BatteriesDefaults.layout) private var layout = BatteriesLayout.rings.rawValue
    @AppStorage(BatteriesDefaults.threshold) private var threshold = BatteriesDefaults.defaultThreshold
    @AppStorage(BatteriesDefaults.refreshMinutes) private var refreshMinutes = BatteriesDefaults.defaultRefreshMinutes
    @AppStorage(BatteriesDefaults.airPodsScanning) private var airPodsScanning = false
    @AppStorage(BatteriesDefaults.readIOSDevices) private var readIOSDevices = true

    @State private var muted = BatteriesDevicePreferences.muted()
    @State private var hidden = BatteriesDevicePreferences.hidden()
    @State private var hiddenNames = BatteriesDevicePreferences.hiddenNames()
    /// Zenith fork: the preview card's state, which follows the section opened.
    @State private var previewState = ZenithBatteriesPreviewCard.page
    @ObservedObject private var router = SettingsRouter.shared

    private let text = ZenithStrings.batteries(.enUS)
    private let page = ZenithStrings.everyday(.enUS)
    private static let formula = "libimobiledevice"

    private var groups: (accessories: [BatteryDevice], mobile: [BatteryDevice]) {
        BatteriesDevicePreferences.split(store.devices, hidden: hidden)
    }

    private static let lookID = "zenith.preview.look" // Zenith fork

    var body: some View {
        ScrollViewReader { proxy in // Zenith fork: the preview card scrolls to its settings
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips, isOn: $enabled,
                           switchLabel: text.enable, switchHint: text.enableHint, animation: .batteries)
                    .zenithSectionAnchor(.zenithBatteries, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                // Zenith fork: the shared preview card.
                ZenithBatteriesPreviewCard(state: $previewState) {
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Self.lookID, anchor: .center) }
                } openAlerts: {
                    router.request(FeatureSettingsDestination(.batteries, sectionAnchor: .zenithBatteriesAlerts))
                }
                // Kept in view while Batteries is off, greyed, so the page
                // reads the same whichever way the switch is.
                VStack(alignment: .leading, spacing: 18) {
                    lookPicker.id(Self.lookID)
                    devicesSection
                    alertSection
                    iOSSection
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
        }
        }
        .onAppear {
            reload()
            store.refreshNow()
            followRoute()
        }
        .onChange(of: router.requestID) { _, _ in followRoute() }
        .onChange(of: enabled) { _, _ in store.refreshNow() }
        .onChange(of: layout) { _, _ in store.refreshNow() }
        .onChange(of: threshold) { _, _ in store.refreshNow() }
        .onChange(of: refreshMinutes) { _, _ in store.refreshNow() }
        .onChange(of: airPodsScanning) { _, _ in store.refreshNow() }
        .onChange(of: readIOSDevices) { _, _ in store.refreshNow() }
        .onChange(of: installStatus?.result) { _, result in
            if result == .succeeded { store.refreshNow() }
        }
    }

    private var chips: [ZenithChip] {
        let shown = groups.accessories.count + (readIOSDevices ? groups.mobile.count : 0)
        return [ZenithChip(page.batteriesDevices(shown)), ZenithChip(page.batteriesWarnAt(threshold))]
    }

    /// Zenith fork: a sidebar row or search landing on the alerts shows the
    /// Battery Low card; any other landing, the page.
    private func followRoute() {
        guard router.destination.page == .batteries else { return }
        if router.destination.sectionAnchor == .zenithBatteriesAlerts {
            // The compact form belongs to the alerts too, so it stays.
            if previewState == ZenithBatteriesPreviewCard.page { previewState = ZenithBatteriesPreviewCard.low }
        } else {
            previewState = ZenithBatteriesPreviewCard.page
        }
    }

    // MARK: Look

    /// The island page's layout, as pictures.
    private var lookPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.layout)
            ZenithVisualPicker(text.layout, selection: $layout, options: [
                ZenithPickerOption(BatteriesLayout.rings.rawValue, text.rings),
                ZenithPickerOption(BatteriesLayout.list.rawValue, text.list),
            ], minimumTileWidth: 150, tileHeight: 70) { value, _ in
                BatteriesLayoutArt(rings: value == BatteriesLayout.rings.rawValue)
            }
        }
    }

    // MARK: Devices

    private var devicesSection: some View {
        let devices = groups.accessories
        let hiddenRows = BatteriesDevicePreferences.hiddenRows(store.devices, hidden: hidden, names: hiddenNames)
        return ZenithSection(text.devices, footer: devices.isEmpty ? nil : devicesFootnote(devices)) {
            if devices.isEmpty {
                caption(text.devicesEmpty).padding(.vertical, 8)
            }
            ForEach(devices) { device in
                deviceRow(device)
            }
            if !hiddenRows.isEmpty {
                ZenithMoreOptions(id: "batteries.hidden") {
                    ForEach(hiddenRows, id: \.id) { row in
                        ZenithRow(row.name, essential: text.hidden) {
                            Button(text.unhide) { setHidden(false, id: row.id, name: nil) }
                        }
                    }
                }
            }
        }
    }

    /// How to hide a device, and why the Mac's own alert starts off.
    private func devicesFootnote(_ devices: [BatteryDevice]) -> String {
        guard devices.contains(where: { $0.id == BatteriesDevicePreferences.macID }) else { return text.devicesHint }
        return text.devicesHint + " " + text.macAlertCaption
    }

    private func deviceRow(_ device: BatteryDevice) -> some View {
        let alert = Binding(get: { !muted.contains(device.id) }, set: { setAlert($0, for: device.id) })
        return HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: device.symbolName)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(ZenithType.rowTitle)
                        .lineLimit(1)
                    Text(BatteriesDevicePreferences.caption(device, text: text))
                        .font(ZenithType.mono(10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .opacity(device.isReachable ? 1 : 0.45)
            Spacer(minLength: 12)
            Text(text.alert)
                .font(ZenithType.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            ZenithSwitch(isOn: alert)
                .accessibilityRepresentation { Toggle(device.name, isOn: alert) }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(text.hide) { setHidden(true, id: device.id, name: device.name) }
        }
    }

    // MARK: Low battery alert

    private var alertSection: some View {
        ZenithSection(text.lowBatteryAlert, anchor: .zenithBatteriesAlerts, footer: text.alertRule) {
            ZenithRow(text.warnAt) {
                BatteriesSegmented(title: text.warnAt, selection: $threshold,
                                   options: BatteriesDefaults.thresholdOptions.map { ($0, "\($0)%") })
            }
            ZenithMoreOptions(id: "batteries") {
                ZenithRow(text.checkEvery, info: text.checkEveryCaption) {
                    BatteriesSegmented(title: text.checkEvery, selection: $refreshMinutes,
                                       options: BatteriesDefaults.refreshOptions.map { ($0, text.count(text.minutes, $0)) })
                }
                ZenithRow(text.airPodsScanning, isOn: $airPodsScanning, info: text.airPodsScanningCaption)
            }
        }
    }

    // MARK: iPhone & Apple Watch

    private var iOSSection: some View {
        let devices = groups.mobile
        return ZenithSection(text.iOSSection, anchor: .zenithBatteriesIPhone) {
            ZenithRow(text.readIOS, isOn: $readIOSDevices, info: text.readIOSCaption)
            if readIOSDevices {
                toolsRow
                ForEach(devices) { device in
                    deviceRow(device)
                }
                if devices.isEmpty, case .installed = store.iOSTools {
                    caption(text.noIOSDevices).padding(.vertical, 8)
                }
                steps
            }
        }
    }

    @ViewBuilder
    private var toolsRow: some View {
        switch store.iOSTools {
        case .unknown:
            caption(text.checkingTools).padding(.vertical, 8)
        case .installed(let watchSupport):
            VStack(alignment: .leading, spacing: 4) {
                Label(text.toolsInstalled, systemImage: "checkmark.circle")
                    .font(ZenithType.footnote)
                    .foregroundStyle(.secondary)
                if !watchSupport {
                    caption(text.noWatchSupport)
                }
            }
            .padding(.vertical, 8)
        case .missing:
            missingToolsRow
        }
    }

    /// The amber box, what is missing, and Homebrew's install of it, its
    /// progress and its failure shown by Homebrew's own status card.
    private var missingToolsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                let box = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                Image(systemName: "shippingbox")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ZenithStatus.warning)
                    .frame(width: 30, height: 30)
                    .background(ZenithStatus.fill(ZenithStatus.warning), in: box)
                    .overlay(box.strokeBorder(ZenithStatus.stroke(ZenithStatus.warning)))
                rowTitle(text.needsTools, caption: text.needsToolsCaption)
                Spacer(minLength: 12)
                installButton
            }
            if homebrew.brewPath == nil {
                caption(text.noHomebrew)
            } else if homebrew.operation != nil, installStatus == nil {
                caption(text.busyHomebrew)
            }
            if let installStatus {
                if installStatus.result == .failed {
                    Text(text.installFailed)
                        .font(ZenithType.caption)
                        .foregroundStyle(ZenithStatus.error)
                }
                HomebrewOperationOutputView(homebrew: homebrew, output: .status(installStatus), compact: true)
            }
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var installButton: some View {
        if homebrew.brewPath == nil {
            if let url = URL(string: "https://brew.sh") {
                Link(text.getHomebrew, destination: url)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            let running = installStatus?.isActive == true
            Button(running ? text.installing : (installStatus?.result == .failed ? text.tryAgain : text.install)) {
                homebrew.install(HomebrewPackage(kind: .formula, name: Self.formula, displayName: Self.formula))
            }
            .buttonStyle(.borderedProminent)
            .disabled(homebrew.operation != nil)
        }
    }

    /// Homebrew's current or last run, when it is this page's install.
    private var installStatus: HomebrewOperationStatus? {
        guard let status = homebrew.operationStatus, status.action == .install,
              status.package?.kind == .formula, status.package?.name == Self.formula else { return nil }
        return status
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZenithStepRow(number: 1, text: text.stepCable)
            ZenithStepRow(number: 2, text: text.stepWiFi)
            ZenithStepRow(number: 3, text: text.stepWatch)
        }
        .padding(.vertical, 4)
    }

    // MARK: Preferences

    private func reload() {
        muted = BatteriesDevicePreferences.muted()
        hidden = BatteriesDevicePreferences.hidden()
        hiddenNames = BatteriesDevicePreferences.hiddenNames()
    }

    private func setAlert(_ on: Bool, for id: String) {
        BatteriesDevicePreferences.setAlert(on, for: id)
        reload()
        store.refreshNow()
    }

    private func setHidden(_ hide: Bool, id: String, name: String?) {
        BatteriesDevicePreferences.setHidden(hide, id: id, name: name)
        reload()
        store.refreshNow()
    }

    // MARK: Pieces

    private func rowTitle(_ title: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(ZenithType.rowTitle)
            if let caption {
                self.caption(caption)
            }
        }
    }

    private func caption(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Pieces

/// The island page's layout as a picture: three rings, or rows of levels.
private struct BatteriesLayoutArt: View {
    let rings: Bool
    private static let levels = [0.82, 0.56, 0.24]

    var body: some View {
        Group {
            if rings {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        ZStack {
                            Circle().stroke(Color.primary.opacity(0.15), lineWidth: 4)
                            Circle().trim(from: 0, to: Self.levels[index])
                                .stroke(index == 2 ? ZenithStatus.warning : ZenithStatus.success,
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 26, height: 26)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 6) {
                            Circle().fill(Color.primary.opacity(0.4)).frame(width: 7, height: 7)
                            Capsule().fill(Color.primary.opacity(0.15)).frame(width: 70, height: 5)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(index == 2 ? ZenithStatus.warning : ZenithStatus.success)
                                        .frame(width: 70 * Self.levels[index], height: 5)
                                }
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A few choices in a capsule well, the chosen one on a raised pill, in mono
/// for figures. Grey, not accent: the accent is for what is selected in lists.
private struct BatteriesSegmented<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button {
                    guard !selected else { return }
                    withAnimation(ZenithMotion.respecting(ZenithMotion.toggle())) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(ZenithType.mono(11.5, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 52)
                        .frame(height: 24)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.primary.opacity(0.12))
                                    .overlay(Capsule().strokeBorder(ZenithSurface.hairline))
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .overlay(Capsule().strokeBorder(ZenithSurface.hairline))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
