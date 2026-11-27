// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: Settings → iPhone Remote, a page of its own, built with the
// Settings kit. The switch in the hero, a read-only checklist (Remote
// Login, Tailscale), the devices whose keys Zenith added to
// ~/.ssh/authorized_keys, the values to type into the Shortcut, a local
// test, the optional hardening command (shown, never run, under More
// options) and the last requests.

struct RemoteControlSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = RemoteControlService.shared
    @AppStorage(DefaultsKey.zenithRemoteEnabled) private var enabled = false
    @State private var name = ""
    @State private var key = ""
    @State private var message: (text: String, good: Bool)?
    @State private var copied: String?
    private let page = ZenithStrings.everyday(.enUS)

    private var text: ZenithRemoteStrings { ZenithStrings.remote(l10n.language) }

    /// The name the scripts use: the one being typed, else the first device's, else "iPhone".
    private var deviceName: String {
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return RemoteDeviceName.sanitize(typed) }
        return service.devices.first?.name ?? RemoteControl.defaultDevice
    }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                           isOn: Binding(get: { enabled }, set: { on in
                               enabled = on
                               service.syncWithPreferences()
                           }),
                           switchLabel: text.enable, switchHint: text.enableCaption, animation: .remote)
                    .zenithSectionAnchor(.zenithRemote, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                ZenithRemotePreviewCard { // Zenith fork: the shared preview card
                    SettingsRouter.shared.request(FeatureSettingsDestination(.remote, sectionAnchor: .zenithRemote))
                }
                checklist
                devices
                shortcut
                test
                recent
            }
        }
        .onAppear {
            service.checkReadiness()
            service.reloadDevices()
        }
    }

    private var chips: [ZenithChip] {
        let ready = service.readiness.remoteLogin == true && tailscaleReady == true
        return [ZenithChip(ready ? page.remoteReady : page.remoteNotReady,
                           dot: ready ? ZenithStatus.success : ZenithStatus.warning),
                ZenithChip(page.remoteDevices(service.devices.count))]
    }

    // MARK: Checklist

    private var checklist: some View {
        let readiness = service.readiness
        return ZenithSection(text.checklist) {
            checkRow(title: text.remoteLogin, ok: readiness.remoteLogin,
                     detail: readiness.remoteLogin == true ? text.remoteLoginOn : text.remoteLoginOff)
            checkRow(title: text.tailscale, ok: tailscaleReady, detail: tailscaleDetail)
            HStack {
                Spacer()
                if readiness.checking { ProgressView().controlSize(.small) }
                Button(text.checkAgain) { service.checkReadiness() }
                    .disabled(readiness.checking)
            }
            .padding(.vertical, 8)
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

    /// What is missing stays under the title: it is what to fix before the
    /// Shortcut can reach this Mac.
    private func checkRow(title: String, ok: Bool?, detail: String) -> some View {
        ZenithRow(title, info: ok == true ? detail : nil, essential: ok == false ? detail : nil) {
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
        ZenithSection(text.devices, footer: text.devicesCaption) {
            if service.devices.isEmpty {
                Text(text.noDevices)
                    .font(ZenithType.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
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
                .padding(.vertical, 8)
            }
            VStack(alignment: .leading, spacing: 8) {
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
            .padding(.vertical, 10)
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
        ZenithSection(text.shortcut, footer: text.shortcutCaption) {
            value(text.host, service.readiness.host ?? "…")
            value(text.user, Self.userName)
            value(text.port, "22")
            value(text.lockScript, RemoteScript.shortcutScript(.lock, device: deviceName))
            value(text.statusScript, RemoteScript.shortcutScript(.status, device: deviceName))
            // The optional hardening command: shown, never run.
            ZenithMoreOptions(id: "remote") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text.hardening).font(ZenithType.rowTitle)
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
                .padding(.vertical, 10)
            }
        }
    }

    private func value(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(ZenithType.body)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(ZenithType.mono(12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            copyButton(value)
        }
        .padding(.vertical, 8)
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
        ZenithSection(text.test) {
            ZenithRow(service.running ? text.testCaption : text.testOff) {
                HStack(spacing: 8) {
                    if service.testing { ProgressView().controlSize(.small) }
                    Button(text.test) { service.runTest() }
                        .disabled(!service.running || service.testing)
                }
            }
            if let output = service.testOutput, !output.isEmpty {
                Text(output)
                    .font(ZenithType.mono(11.5))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: ZenithRadius.large))
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: Recent requests

    private var recent: some View {
        ZenithSection(text.recent) {
            if service.log.isEmpty {
                Text(text.recentEmpty)
                    .font(ZenithType.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(service.log) { entry in
                    HStack(spacing: 10) {
                        Text(entry.date, format: .dateTime.hour().minute().second())
                            .font(ZenithType.mono(11))
                            .foregroundStyle(.secondary)
                        Text(entry.device.isEmpty ? "?" : entry.device)
                            .font(ZenithType.body)
                            .lineLimit(1)
                        Spacer()
                        if entry.outcome == .refused {
                            Label(text.refused, systemImage: "exclamationmark.circle")
                                .font(ZenithType.caption)
                                .foregroundStyle(ZenithStatus.warning)
                        }
                        Text(verb(entry.verb))
                            .font(ZenithType.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
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
