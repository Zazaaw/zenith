// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Dev servers section's options in Settings → Dynamic
/// Island → Content: detection, the notice for a new server, the count in the
/// closed island, and ports or process names that also count.
struct DevServersSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDevServersEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchDevServersAnnounce) private var announces = true
    @AppStorage(DefaultsKey.notchDevServersIndicator) private var indicator = false
    @AppStorage(DefaultsKey.notchDevServersExtraPorts) private var ports = ""
    @AppStorage(DefaultsKey.notchDevServersExtraNames) private var names = ""
    @State private var portsDraft = ""
    @State private var namesDraft = ""
    @FocusState private var focused: Field?

    private enum Field: Hashable { case ports, names }

    private var text: ZenithDevServersStrings { ZenithStrings.devServers(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSwitchRow(text.detect, isOn: $enabled) {
                label(text.detect, caption: text.detectCaption)
            }
            if enabled {
                ZenithSwitchRow(text.announce, isOn: $announces) {
                    label(text.announce, caption: text.announceCaption)
                }
                ZenithSwitchRow(text.indicator, isOn: $indicator) {
                    label(text.indicator, caption: text.indicatorCaption)
                }
                Divider().padding(.vertical, 2)
                field(text.extraPorts, placeholder: text.extraPortsPlaceholder, draft: $portsDraft, field: .ports)
                field(text.extraNames, placeholder: text.extraNamesPlaceholder, draft: $namesDraft, field: .names)
                Text(text.extrasCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .zenithSectionAnchor(.zenithDevServers) // Settings search lands here
        .onAppear {
            portsDraft = ports
            namesDraft = names
        }
        .onChange(of: enabled) { _, _ in sync() }
        .onChange(of: announces) { _, _ in sync() }
        .onChange(of: indicator) { _, _ in sync() }
        .onChange(of: ports) { _, _ in sync() }
        .onChange(of: names) { _, _ in sync() }
        .onChange(of: focused) { previous, _ in
            if previous == .ports { commitPorts() }
            if previous == .names { commitNames() }
        }
    }

    private func field(_ title: String, placeholder: String, draft: Binding<String>, field: Field) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            TextField(title, text: draft, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(maxWidth: 220)
                .focused($focused, equals: field)
                .onSubmit { field == .ports ? commitPorts() : commitNames() }
        }
    }

    private func commitPorts() {
        let trimmed = portsDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != ports { ports = trimmed }
    }

    private func commitNames() {
        let trimmed = namesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != names { names = trimmed }
    }

    private func sync() {
        NotchService.shared.syncWithPreferences()
        ZenithNoticeCenter.shared.syncWithPreferences()
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
