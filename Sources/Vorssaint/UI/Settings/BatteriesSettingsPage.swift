// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import AppKit
import SwiftUI

/// Zenith fork: Settings → Batteries, under Monitor. The switch for the whole
/// feature, the island page's layout, the devices with their alert switches
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
    private static let formula = "libimobiledevice"

    private var groups: (accessories: [BatteryDevice], mobile: [BatteryDevice]) {
        BatteriesDevicePreferences.split(store.devices, hidden: hidden)
    }

    private static let lookID = "zenith.preview.look" // Zenith fork

    var body: some View {
        ScrollViewReader { proxy in // Zenith fork: the preview card scrolls to its settings
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle) {
                    BatteriesTitledSwitch(title: text.enable, isOn: $enabled)
                        .help(text.enableHint)
                }
                .zenithSectionAnchor(.zenithBatteries)
                // Zenith fork: the shared preview card.
                ZenithBatteriesPreviewCard(state: $previewState) {
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Self.lookID, anchor: .center) }
                } openAlerts: {
                    router.request(FeatureSettingsDestination(.batteries, sectionAnchor: .zenithBatteriesAlerts))
                }
                Rectangle().fill(ZenithSurface.hairline).frame(height: 1)
                // Kept in view while Batteries is off, greyed, so the page
                // reads the same whichever way the switch is.
                VStack(alignment: .leading, spacing: 22) {
                    lookSection.id(Self.lookID)
                    devicesSection
                    alertSection
                    iOSSection
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
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

    private var lookSection: some View {
        BatteriesSection(symbol: "square.grid.2x2", title: text.look) {
            BatteriesRow {
                rowTitle(text.layout)
                Spacer(minLength: 12)
                BatteriesSegmented(title: text.layout, selection: $layout, options: [
                    (BatteriesLayout.rings.rawValue, text.rings), (BatteriesLayout.list.rawValue, text.list),
                ])
            }
        }
    }

    // MARK: Devices

    private var devicesSection: some View {
        let devices = groups.accessories
        let hiddenRows = BatteriesDevicePreferences.hiddenRows(store.devices, hidden: hidden, names: hiddenNames)
        return BatteriesSection(symbol: "battery.75percent", title: text.devices, trailing: text.alert,
                                footnote: devices.isEmpty ? nil : devicesFootnote(devices)) {
            if devices.isEmpty {
                BatteriesRow { caption(text.devicesEmpty) }
            }
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                if index > 0 { BatteriesDivider() }
                deviceRow(device)
            }
            if !hiddenRows.isEmpty {
                BatteriesDivider()
                BatteriesRow {
                    Text(text.hidden.uppercased())
                        .font(ZenithType.mono(9.5, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                .padding(.bottom, -6)
                ForEach(hiddenRows, id: \.id) { row in
                    BatteriesRow {
                        Text(row.name)
                            .font(ZenithType.rowTitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Button(text.unhide) { setHidden(false, id: row.id, name: nil) }
                            .controlSize(.small)
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
        return BatteriesRow {
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
            ZenithSwitch(isOn: alert)
                .accessibilityRepresentation { Toggle(device.name, isOn: alert) }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(text.hide) { setHidden(true, id: device.id, name: device.name) }
        }
    }

    // MARK: Low battery alert

    private var alertSection: some View {
        BatteriesSection(symbol: "bell.badge", title: text.lowBatteryAlert, footnote: text.alertRule) {
            BatteriesRow {
                rowTitle(text.warnAt)
                Spacer(minLength: 12)
                BatteriesSegmented(title: text.warnAt, selection: $threshold,
                                   options: BatteriesDefaults.thresholdOptions.map { ($0, "\($0)%") })
            }
            BatteriesDivider()
            BatteriesRow {
                rowTitle(text.checkEvery, caption: text.checkEveryCaption)
                Spacer(minLength: 12)
                BatteriesSegmented(title: text.checkEvery, selection: $refreshMinutes,
                                   options: BatteriesDefaults.refreshOptions.map { ($0, text.count(text.minutes, $0)) })
            }
            BatteriesDivider()
            BatteriesRow {
                ZenithSwitchRow(text.airPodsScanning, isOn: $airPodsScanning) {
                    rowTitle(text.airPodsScanning, caption: text.airPodsScanningCaption)
                }
            }
        }
        .zenithSectionAnchor(.zenithBatteriesAlerts)
    }

    // MARK: iPhone & Apple Watch

    private var iOSSection: some View {
        let devices = groups.mobile
        return BatteriesSection(symbol: "iphone", title: text.iOSSection, trailing: readIOSDevices ? text.alert : nil) {
            BatteriesRow {
                ZenithSwitchRow(text.readIOS, isOn: $readIOSDevices) {
                    rowTitle(text.readIOS, caption: text.readIOSCaption)
                }
            }
            if readIOSDevices {
                BatteriesDivider()
                toolsRow
                ForEach(devices) { device in
                    BatteriesDivider()
                    deviceRow(device)
                }
                if devices.isEmpty, case .installed = store.iOSTools {
                    BatteriesDivider()
                    BatteriesRow { caption(text.noIOSDevices) }
                }
                BatteriesDivider()
                steps
            }
        }
        .zenithSectionAnchor(.zenithBatteriesIPhone)
    }

    @ViewBuilder
    private var toolsRow: some View {
        switch store.iOSTools {
        case .unknown:
            BatteriesRow {
                caption(text.checkingTools)
                Spacer()
            }
        case .installed(let watchSupport):
            BatteriesRow {
                VStack(alignment: .leading, spacing: 4) {
                    Label(text.toolsInstalled, systemImage: "checkmark.circle")
                        .font(ZenithType.footnote)
                        .foregroundStyle(.secondary)
                    if !watchSupport {
                        caption(text.noWatchSupport)
                    }
                }
                Spacer()
            }
        case .missing:
            missingToolsRow
        }
    }

    /// The amber box, what is missing, and Homebrew's install of it, its
    /// progress and its failure shown by Homebrew's own status card.
    private var missingToolsRow: some View {
        BatteriesRow {
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
                        .padding(.leading, settingsRowTextInset)
                } else if homebrew.operation != nil, installStatus == nil {
                    caption(text.busyHomebrew)
                        .padding(.leading, settingsRowTextInset)
                }
                if let installStatus {
                    if installStatus.result == .failed {
                        Text(text.installFailed)
                            .font(ZenithType.caption)
                            .foregroundStyle(ZenithStatus.error)
                            .padding(.leading, settingsRowTextInset)
                    }
                    HomebrewOperationOutputView(homebrew: homebrew, output: .status(installStatus), compact: true)
                        .padding(.leading, settingsRowTextInset)
                }
            }
        }
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
        BatteriesRow {
            VStack(alignment: .leading, spacing: 8) {
                step(1, text.stepCable)
                step(2, text.stepWiFi)
                step(3, text.stepWatch)
            }
            Spacer(minLength: 0)
        }
    }

    private func step(_ number: Int, _ string: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(ZenithType.mono(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(ZenithSurface.tileFill))
                .overlay(Circle().strokeBorder(ZenithSurface.tileStroke))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(string)
                .font(ZenithType.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

// MARK: - Chrome

/// A section: its glyph and bold title above a hairline card, an optional
/// mono label over the card's switch column, and an optional line under it.
private struct BatteriesSection<Content: View>: View {
    let symbol: String
    let title: String
    var trailing: String? = nil
    var footnote: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(title)
                    .font(ZenithType.sectionTitle)
                    .tracking(ZenithType.sectionTitleTracking)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                if let trailing {
                    Text(trailing.uppercased())
                        .font(ZenithType.mono(9.5, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 16)
                }
            }
            .padding(.leading, 2)
            let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .background(ZenithSurface.cardFill, in: shape)
                .overlay(shape.strokeBorder(ZenithSurface.hairline))
            if let footnote {
                Text(footnote)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One row of a section's card.
private struct BatteriesRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

/// The hairline between rows, inset like the rows.
private struct BatteriesDivider: View {
    var body: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).padding(.horizontal, 16)
    }
}

/// The page's switch beside its title, as the Lock Screen page's.
private struct BatteriesTitledSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(ZenithType.rowTitle)
                .fixedSize()
            ZenithSwitch(isOn: $isOn)
        }
        .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
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
