// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Mechakey plays the keyboard sound packs of Mechvibes by Hải Nguyễn (MIT),
// https://github.com/hainguyents13/mechvibes — see the notice in About.

import AppKit
import SwiftUI

/// Zenith fork: Settings → Mechakey. The switch (which asks for Input
/// Monitoring the first time it turns on), the sound pack with a preview of
/// each, the volume, key-up sounds, key repeat, the toggle shortcut and the
/// credit. Everything writes `MechakeyDefaults`; `MechakeyService` follows.
struct MechakeySettingsPage: View {
    @ObservedObject private var service = MechakeyService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(MechakeyDefaults.enabled) private var enabled = false
    @AppStorage(MechakeyDefaults.pack) private var packID = MechakeyPack.defaultID
    @AppStorage(MechakeyDefaults.volume) private var volume = MechakeyDefaults.defaultVolume
    @AppStorage(MechakeyDefaults.keyUpSounds) private var keyUpSounds = true
    @AppStorage(MechakeyDefaults.ignoreRepeat) private var ignoreRepeat = true
    @AppStorage(MechakeyDefaults.shortcut) private var shortcut = ""
    @State private var shortcutMessage: String?

    private let text = ZenithStrings.mechakey(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle) {
                    HStack(spacing: 10) {
                        Text(text.enable)
                            .font(ZenithType.rowTitle)
                            .fixedSize()
                        ZenithSwitch(isOn: enabledBinding)
                    }
                    .accessibilityRepresentation { Toggle(text.enable, isOn: enabledBinding) }
                    .help(text.enableHint)
                }
                .zenithSectionAnchor(.zenithMechakey)
                if enabled, service.access != .granted || service.tapFailed {
                    accessCard
                }
                packCard
                typingCard
                MechakeyCredits()
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { service.refreshAccess() }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { service.setEnabled($0) })
    }

    // MARK: Input Monitoring

    private var accessCard: some View {
        SettingsCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ZenithStatus.warning)
                caption(service.access == .notDetermined && !service.tapFailed ? text.accessNeeded : text.accessDenied)
            }
            if service.access == .notDetermined {
                Button(text.allowInputMonitoring) {
                    FaceUnlockSpaceKeyMonitor.requestAccess()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { service.refreshAccess() }
                }
            } else {
                Button(text.openInputMonitoring) { FaceUnlockSettingsPage.openPrivacyPane("Privacy_ListenEvent") }
            }
        }
    }

    // MARK: Sound pack

    private var packCard: some View {
        SettingsCard(title: text.soundPack) {
            ForEach(Array(MechakeyPack.all.enumerated()), id: \.element.id) { index, pack in
                if index > 0 { Divider() }
                packRow(pack)
            }
            Divider()
            SettingsRow(symbol: "speaker.wave.2", title: text.volume, caption: text.volumeCaption) {
                Slider(value: $volume, in: 0...1) { editing in
                    // Letting go plays the chosen pack at the new level.
                    if !editing { service.preview(MechakeyPack.named(packID)) }
                }
                .frame(width: 180)
                .accessibilityLabel(text.volume)
            }
        }
    }

    private func packRow(_ pack: MechakeyPack) -> some View {
        let selected = MechakeyPack.named(packID) == pack
        let playing = service.previewingPackID == pack.id
        return HStack(spacing: 12) {
            Button {
                packID = pack.id
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.title).font(ZenithType.rowTitle)
                        if let line = text.caption(for: pack) { caption(line) }
                    }
                    Spacer(minLength: 12)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button {
                service.preview(pack)
            } label: {
                Label(playing ? text.previewing : text.preview, systemImage: playing ? "waveform" : "play.fill")
                    .font(ZenithType.footnote)
            }
            .buttonStyle(.borderless)
            .help("\(text.preview) \(pack.title)")
        }
    }

    // MARK: Typing

    private var typingCard: some View {
        SettingsCard(title: text.typing) {
            ZenithSwitchRow(text.keyUp, isOn: $keyUpSounds) {
                SettingsRow(symbol: "arrow.up.square", title: text.keyUp, caption: text.keyUpCaption) { EmptyView() }
            }
            Divider()
            ZenithSwitchRow(text.ignoreRepeat, isOn: $ignoreRepeat) {
                SettingsRow(symbol: "repeat", title: text.ignoreRepeat, caption: text.ignoreRepeatCaption) { EmptyView() }
            }
            Divider()
            shortcutRow
            caption(text.secureInput)
                .padding(.leading, settingsRowTextInset)
        }
    }

    private var shortcutRow: some View {
        let s = l10n.s
        return VStack(alignment: .leading, spacing: 4) {
            SettingsRow(symbol: "command", title: text.shortcut, caption: text.shortcutCaption) {
                HStack(spacing: 8) {
                    if service.shortcutRefused {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ZenithStatus.warning)
                            .help(s.shortcutNotCaptured)
                    }
                    ShortcutRecorderButton(
                        shortcut: GlobalShortcut(storageValue: shortcut) ?? .radialMenuDefault,
                        isEnabled: true,
                        waitingTitle: s.shortcutPressKeys,
                        emptyTitle: shortcut.isEmpty ? s.shortcutNone : nil,
                        clearAction: {
                            shortcutMessage = nil
                            shortcut = ""
                            service.syncShortcut()
                        },
                        notCapturedAction: { shortcutMessage = s.shortcutNotCaptured },
                        recordingChanged: { recording in if recording { shortcutMessage = nil } },
                        invalidAction: { shortcutMessage = s.shortcutInvalid },
                        captureAction: { captured in
                            if let owner = service.conflict(for: captured) {
                                shortcutMessage = s.shortcutConflictFormat.replacingOccurrences(of: "%@", with: owner)
                                return
                            }
                            shortcutMessage = nil
                            shortcut = captured.storageValue
                            service.syncShortcut()
                        }
                    )
                    .frame(width: 130)
                }
            }
            if let shortcutMessage {
                Text(shortcutMessage)
                    .font(ZenithType.caption)
                    .foregroundStyle(ZenithStatus.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, settingsRowTextInset)
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

/// Zenith fork: the credit for Mechakey's sound packs, on its page and in
/// About beside the others: Mechvibes by Hải Nguyễn (MIT, its notice in full
/// as the licence asks).
struct MechakeyCredits: View {
    @State private var showsLicense = false
    private let text = ZenithStrings.mechakey(.enUS)
    static let link = "https://github.com/hainguyents13/mechvibes"

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(text.credit)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: Self.link) {
                    Link(destination: url) { Text(verbatim: Self.link).font(ZenithType.mono(10.5)) }
                }
            }
            Button(showsLicense ? text.hideLicense : text.showLicense) { showsLicense.toggle() }
                .buttonStyle(.link)
                .font(ZenithType.footnote)
            if showsLicense {
                Text(verbatim: Self.license)
                    .font(ZenithType.mono(10))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ZenithSurface.cardFill, in: shape)
        .overlay(shape.strokeBorder(ZenithSurface.hairline))
    }

    /// Mechvibes' licence, verbatim.
    static let license = """
    MIT License

    Copyright (c) 2026 Hải Nguyễn

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}
