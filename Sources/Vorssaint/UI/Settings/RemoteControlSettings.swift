// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: Settings → iPhone Remote, a page of its own. The switch, a
// read-only checklist (Remote Login, Tailscale), the devices whose keys
// Zenith added to ~/.ssh/authorized_keys, the values to type into the
// Shortcut, a local test, the optional hardening command (shown, never
// run) and the last requests. Headings are drawn here and switches are
// ZenithSwitchRow, like the fork's other pages.

struct RemoteControlSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = RemoteControlService.shared
    @AppStorage(DefaultsKey.zenithRemoteEnabled) private var enabled = false
    @State private var name = ""
    @State private var key = ""
    @State private var message: (text: String, good: Bool)?
    @State private var copied: String?

    private var text: ZenithRemoteStrings { ZenithStrings.remote(l10n.language) }

    /// The name the scripts use: the one being typed, else the first device's, else "iPhone".
    private var deviceName: String {
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return RemoteDeviceName.sanitize(typed) }
        return service.devices.first?.name ?? RemoteControl.defaultDevice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle)
                ZenithRemotePreviewCard { // Zenith fork: the shared preview card
                    SettingsRouter.shared.request(FeatureSettingsDestination(.remote, sectionAnchor: .zenithRemote))
                }
                SettingsCard {
                    ZenithSwitchRow(text.enable, isOn: Binding(get: { enabled }, set: { on in
                        enabled = on
                        service.syncWithPreferences()
                    })) {
                        SettingsRow(symbol: "iphone.radiowaves.left.and.right", title: text.enable,
                                    caption: text.enableCaption) { EmptyView() }
                    }
                }
                .zenithSectionAnchor(.zenithRemote)
                checklist
                devices
                shortcut
                test
                hardening
                recent
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear {
            service.checkReadiness()
            service.reloadDevices()
        }
    }

    // MARK: Checklist

    private var checklist: some View {
        SettingsCard(title: text.checklist) {
            let readiness = service.readiness
            checkRow(symbol: "terminal", title: text.remoteLogin, ok: readiness.remoteLogin,
                     detail: readiness.remoteLogin == true ? text.remoteLoginOn : text.remoteLoginOff)
            Divider()
            checkRow(symbol: "network", title: text.tailscale, ok: tailscaleReady, detail: tailscaleDetail)
            HStack {
                Spacer()
                if readiness.checking { ProgressView().controlSize(.small) }
                Button(text.checkAgain) { service.checkReadiness() }
                    .disabled(readiness.checking)
            }
        }
    }

    private var tailscaleReady: Bool? {
        let readiness = service.readiness
        guard let installed = readiness.tailscaleInstalled else { return nil }
        return installed && readiness.tailscale?.running == true
    }

    private var tailscaleDetail: String {
        let readiness = service.readiness
        if readiness.tailscaleInstalled == false { return text.tailscaleMissing }
        if let status = readiness.tailscale, status.running { return text.connected(status.host ?? "Tailscale") }
        return text.tailscaleSignedOut
    }

    private func checkRow(symbol: String, title: String, ok: Bool?, detail: String) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: ok == nil ? nil : detail) {
            Group {
                switch ok {
                case .some(true):
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(ZenithStatus.success)
                case .some(false):
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(ZenithStatus.warning)
                case .none:
                    ProgressView().controlSize(.small)
                }
            }
            .font(.system(size: 15))
        }
    }

    /// The device name's placeholder and the account the Shortcut signs in
    /// as; the catalog's Settings renders show made-up ones.
    private static var namePrompt: String {
#if VORSSAINT_DEVELOPMENT
        if IslandCatalog.isRendering { return "Alex’s iPhone" }
#endif
        // The person's own first name, so the placeholder fits whoever runs Zenith.
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "My iPhone" : "\(first)’s iPhone"
    }

    private static var userName: String {
#if VORSSAINT_DEVELOPMENT
        if IslandCatalog.isRendering { return "alex" }
#endif
        return NSUserName()
    }

    // MARK: Devices

    private var devices: some View {
        SettingsCard(title: text.devices) {
            Text(text.devicesCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if service.devices.isEmpty {
                Text(text.noDevices).font(ZenithType.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(service.devices) { device in
                    HStack(spacing: 10) {
                        Image(systemName: "iphone").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name).font(ZenithType.rowTitle)
                            Text("\(device.key.type) …\(device.key.tail)")
                                .font(ZenithType.mono(10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(text.remove) {
                            service.removeDevice(device) { outcome in show(outcome, removing: true) }
                        }
                    }
                }
            }
            Divider()
            TextField(text.deviceName, text: $name, prompt: Text(Self.namePrompt))
                .textFieldStyle(.roundedBorder)
            TextField(text.publicKey, text: $key, prompt: Text(text.publicKey), axis: .vertical)
                .lineLimit(2...4)
                .font(ZenithType.mono(11))
                .textFieldStyle(.roundedBorder)
            HStack {
                if let message {
                    Text(message.text)
                        .font(ZenithType.caption)
                        .foregroundStyle(message.good ? ZenithStatus.success : ZenithStatus.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(text.add) {
                    service.addDevice(key: key, name: deviceName) { outcome in
                        show(outcome, removing: false)
                        if outcome == .changed || outcome == .unchanged { key = "" }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func show(_ outcome: RemoteAuthorizedKeys.Outcome, removing: Bool) {
        switch outcome {
        case .changed: message = removing ? nil : (text.added, true)
        case .unchanged, .notFound: message = nil
        case .invalidKey: message = (text.invalidKey, false)
        case .conflict: message = (text.conflict, false)
        case .isLink: message = (text.isLink, false)
        case .invalidScript, .failed: message = (text.failed, false)
        }
    }

    // MARK: The Shortcut

    private var shortcut: some View {
        SettingsCard(title: text.shortcut) {
            Text(text.shortcutCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            value(text.host, service.readiness.host ?? "…")
            value(text.user, Self.userName)
            value(text.port, "22")
            value(text.lockScript, RemoteScript.shortcutScript(.lock, device: deviceName))
            value(text.statusScript, RemoteScript.shortcutScript(.status, device: deviceName))
        }
    }

    private func value(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(ZenithType.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(ZenithType.mono(12))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            copyButton(value)
        }
    }

    private func copyButton(_ value: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = value
        } label: {
            Image(systemName: copied == value ? "checkmark" : "doc.on.doc")
                .frame(width: 14)
        }
        .buttonStyle(.borderless)
        .help(text.copy)
        .accessibilityLabel(text.copy)
    }

    // MARK: Test

    private var test: some View {
        SettingsCard(title: text.test) {
            HStack(alignment: .top) {
                Text(service.running ? text.testCaption : text.testOff)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if service.testing { ProgressView().controlSize(.small) }
                Button(text.test) { service.runTest() }
                    .disabled(!service.running || service.testing)
            }
            if let output = service.testOutput, !output.isEmpty {
                Text(output)
                    .font(ZenithType.mono(11.5))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: ZenithRadius.large))
            }
        }
    }

    // MARK: Hardening

    private var hardening: some View {
        SettingsCard(title: text.hardening) {
            Text(text.hardeningCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                Text(RemoteScript.hardeningCommand)
                    .font(ZenithType.mono(11))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                copyButton(RemoteScript.hardeningCommand)
            }
            .padding(10)
            .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: ZenithRadius.large))
        }
    }

    // MARK: Recent requests

    private var recent: some View {
        SettingsCard(title: text.recent) {
            if service.log.isEmpty {
                Text(text.recentEmpty).font(ZenithType.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(service.log) { entry in
                    HStack(spacing: 10) {
                        Text(entry.date, format: .dateTime.hour().minute().second())
                            .font(ZenithType.mono(11))
                            .foregroundStyle(.secondary)
                        Text(entry.device.isEmpty ? "?" : entry.device)
                            .font(ZenithType.footnote)
                            .lineLimit(1)
                        Spacer()
                        if entry.outcome == .refused {
                            Label(text.refused, systemImage: "exclamationmark.circle")
                                .font(ZenithType.caption)
                                .foregroundStyle(ZenithStatus.warning)
                        }
                        Text(verb(entry.verb))
                            .font(ZenithType.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func verb(_ verb: RemoteVerb?) -> String {
        switch verb {
        case .lock: return text.verbLock
        case .status: return text.verbStatus
        case nil: return "?"
        }
    }
}
