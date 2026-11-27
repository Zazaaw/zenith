// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Mechakey plays the keyboard sound packs of Mechvibes by Hải Nguyễn (MIT),
// https://github.com/hainguyents13/mechvibes — see the notice in About.

import AppKit
import SwiftUI

/// Zenith fork: Settings → Mechakey, the kit's reference feature page
/// (docs/SETTINGS-KIT.md): the hero with the master switch (which asks for
/// Input Monitoring the first time it turns on), the keys on the stage, the
/// packs as pictures, how typing sounds with key repeat under More options,
/// and the credit. Everything writes `MechakeyDefaults`; `MechakeyService` follows.
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
    @State private var stageKeys = MechakeyStageKeys.typing
    @State private var showsLicense = false

    private let text = ZenithStrings.mechakey(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle,
                           chips: [ZenithChip(pack.title), ZenithChip(text.packCount(MechakeyPack.all.count))],
                           isOn: enabledBinding, switchLabel: text.enable, switchHint: text.enableHint,
                           animation: .mechakey)
                    .zenithSectionAnchor(.zenithMechakey, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                if enabled, service.access != .granted || service.tapFailed {
                    accessCallout
                }
                stage
                packs
                typing
                credit
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { service.refreshAccess() }
    }

    private var pack: MechakeyPack { MechakeyPack.named(packID) }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { service.setEnabled($0) })
    }

    // MARK: Input Monitoring

    private var accessCallout: some View {
        ZenithCallout(.warning,
                      service.access == .notDetermined && !service.tapFailed ? text.accessNeeded : text.accessDenied) {
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

    // MARK: Stage

    private var stage: some View {
        ZenithStage(caption: text.stageCaption,
                    states: MechakeyStageKeys.allCases.map { $0.title(text) },
                    selection: Binding(get: { MechakeyStageKeys.allCases.firstIndex(of: stageKeys) ?? 0 },
                                       set: { stageKeys = MechakeyStageKeys.allCases[$0] })) {
            MechakeyStageArt(keys: stageKeys, playing: service.previewingPackID != nil) {
                service.preview(pack)
            }
        }
    }

    // MARK: Sound pack

    private var packs: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.soundPack)
            ZenithVisualPicker(text.soundPack, selection: Binding(get: { pack.id }, set: { id in
                packID = id
                service.preview(MechakeyPack.named(id))
            }), options: MechakeyPack.all.map { ZenithPickerOption($0.id, text.shortTitle(for: $0),
                                                                    detail: detail(for: $0)) }) { id, selected in
                MechakeyKeycapArt(color: MechakeyKeycapArt.color(for: id),
                                  playing: service.previewingPackID == id)
            }
        }
    }

    private func detail(for pack: MechakeyPack) -> String {
        [pack.title, text.caption(for: pack)].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Typing

    private var typing: some View {
        ZenithSection(text.typing, footer: text.secureInput) {
            ZenithRow(text.volume, value: $volume, in: 0...1, info: text.volumeCaption,
                      valueLabel: "\(Int((volume * 100).rounded()))%",
                      minimumSymbol: "speaker.fill", maximumSymbol: "speaker.wave.3.fill") { editing in
                // Letting go plays the chosen pack at the new level.
                if !editing { service.preview(pack) }
            }
            ZenithRow(text.keyUp, isOn: $keyUpSounds, info: text.keyUpCaption)
            shortcutRow
            ZenithMoreOptions(id: "mechakey", anchors: [.zenithMechakeyRepeat]) {
                ZenithRow(text.ignoreRepeat, isOn: $ignoreRepeat, info: text.ignoreRepeatCaption)
                    .zenithSectionAnchor(.zenithMechakeyRepeat, cornerRadius: 10, inset: 4)
            }
        }
    }

    private var shortcutRow: some View {
        let s = l10n.s
        let warning = shortcutMessage ?? (service.shortcutRefused ? s.shortcutNotCaptured : nil)
        return ZenithRow(text.shortcut, info: text.shortcutCaption, warning: warning, shortcut: {
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
        })
    }

    // MARK: Credit

    private var credit: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZenithFootnote(text.licenceLine)
                Button(showsLicense ? text.hideLicense : text.showLicense) { showsLicense.toggle() }
                    .buttonStyle(.link)
                    .font(ZenithType.caption)
            }
            if showsLicense {
                Text(verbatim: MechakeyCredits.license)
                    .font(ZenithType.mono(10))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Stage art

/// What the stage shows: a word of keys, the space bar or the return key.
enum MechakeyStageKeys: CaseIterable {
    case typing, space, enter

    func title(_ text: ZenithMechakeyStrings) -> String {
        switch self {
        case .typing: return text.stageTyping
        case .space: return text.stageSpace
        case .enter: return text.stageEnter
        }
    }
}

/// Keycaps on the stage, pressed one after another while the page is shown
/// (still under Reduce Motion or the battery saver), with a sound wave over
/// them. Clicking them plays the chosen pack.
struct MechakeyStageArt: View {
    let keys: MechakeyStageKeys
    let playing: Bool
    let play: () -> Void

    private static let word = ["Z", "E", "N", "I", "T", "H"]

    var body: some View {
        ZenithKitClock { t, _ in
            let pressed = Int((t * 4).rounded(.down)) % 8
            VStack(spacing: 16) {
                wave(t)
                HStack(spacing: 8) {
                    switch keys {
                    case .typing:
                        ForEach(Self.word.indices, id: \.self) { index in
                            MechakeyKeycap(label: Self.word[index], width: 48, pressed: index == (pressed == 7 ? 2 : pressed))
                        }
                    case .space:
                        MechakeyKeycap(label: "", width: 300, pressed: pressed % 2 == 0)
                    case .enter:
                        MechakeyKeycap(label: "return", width: 110, pressed: pressed % 2 == 0)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys == .typing ? Self.word.joined() : (keys == .space ? "Space" : "Return"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, play)
    }

    private func wave(_ t: Double) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                let base: [CGFloat] = [8, 14, 22, 30, 36, 30, 22, 14, 8]
                let swing = playing ? 0.55 + 0.45 * ZenithKitEase.pulse(t * 3 + Double(index) * 0.3, period: 1) : 1
                Capsule().fill(Color.primary.opacity(0.6)).frame(width: 3, height: base[index] * swing)
            }
        }
        .frame(height: 36)
    }
}

/// One keycap on the stage: a light cap over its dark wall.
struct MechakeyKeycap: View {
    let label: String
    let width: CGFloat
    let pressed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.12, green: 0.15, blue: 0.3).opacity(0.9))
                .frame(width: width + 4, height: 50)
                .offset(y: 5)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.82)], startPoint: .top, endPoint: .bottom))
                .frame(width: width, height: 44)
                .offset(y: pressed ? 3 : -1)
            Text(verbatim: label)
                .font(.system(size: label.count > 1 ? 12 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.6))
                .offset(y: pressed ? 2 : -2)
        }
        .frame(height: 56)
    }
}

/// A pack's tile: a keycap in the pack's colour with a play mark.
struct MechakeyKeycapArt: View {
    let color: Color
    let playing: Bool

    static func color(for id: String) -> Color {
        switch id {
        case "cherry-mx-blue": return Color(red: 0.3, green: 0.55, blue: 1)
        case "cherry-mx-brown": return Color(red: 0.6, green: 0.4, blue: 0.25)
        case "cherry-mx-red": return Color(red: 0.95, green: 0.3, blue: 0.3)
        case "cherry-mx-black": return Color(white: 0.2)
        case "topre-purple": return Color(red: 0.6, green: 0.45, blue: 0.9)
        case "eg-oreo": return Color(white: 0.92)
        default: return Color(red: 0.75, green: 0.6, blue: 1)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.55)).frame(width: 34, height: 30).offset(y: 3)
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 26)
            Image(systemName: playing ? "waveform" : "play.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityHidden(true)
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
