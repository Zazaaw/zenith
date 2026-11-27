// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Remove Background, a feature page on the Settings
/// kit (docs/SETTINGS-KIT.md): the hero with the master switch, the stage
/// lifting a subject off its background, where it works (the shortcut, the
/// Command Bar, the Shelf) and where the result goes. Everything writes
/// `RemoveBackgroundDefaults`; `RemoveBackgroundService` follows.
struct RemoveBackgroundSettingsPage: View {
    @ObservedObject private var service = RemoveBackgroundService.shared
    @AppStorage(RemoveBackgroundDefaults.enabled) private var enabled = false
    @AppStorage(RemoveBackgroundDefaults.output) private var output = RemoveBackgroundOutput.besideOriginal.rawValue
    @AppStorage(RemoveBackgroundDefaults.framing) private var framing = RemoveBackgroundFraming.keep.rawValue
    @AppStorage(RemoveBackgroundDefaults.shortcut) private var shortcut = RemoveBackgroundService.defaultShortcut.storageValue
    @State private var stageState = 1

    private let text = ZenithStrings.removeBackground(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                           isOn: Binding(get: { enabled }, set: { on in
                               enabled = on
                               service.syncWithPreferences()
                           }),
                           switchLabel: text.enable, switchHint: text.enableHint, animation: .removeBackground)
                    .zenithSectionAnchor(.zenithRemoveBackground, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                stage
                Group {
                    triggers
                    result
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var chips: [ZenithChip] {
        var chips = [ZenithChip(text.chipLocal)]
        if let saved = GlobalShortcut(storageValue: shortcut) { chips.append(ZenithChip(saved.displayString)) }
        chips.append(ZenithChip((RemoveBackgroundOutput(rawValue: output) ?? .besideOriginal).title))
        return chips
    }

    // MARK: Stage

    private var stage: some View {
        ZenithStage(caption: text.stageCaption, states: [text.stageBefore, text.stageAfter, text.stageCropped],
                    selection: $stageState) {
            RemoveBackgroundStageArt(state: stageState)
        }
    }

    // MARK: Sections

    private var triggers: some View {
        ZenithSection(text.triggersSection, footer: text.automationNote) {
            ZenithShortcutSettingRow(text.shortcut, info: text.shortcutCaption,
                                     storageKey: RemoveBackgroundDefaults.shortcut,
                                     fallback: RemoveBackgroundService.defaultShortcut,
                                     refused: service.shortcutRefused,
                                     conflict: service.conflict(for:),
                                     sync: service.syncWithPreferences)
            ZenithRow(text.commandBarRow, info: text.commandBarCaption) {
                Image(systemName: "command").foregroundStyle(.secondary)
            }
            ZenithRow(text.shelfRow, info: text.shelfCaption) {
                Image(systemName: "tray.full").foregroundStyle(.secondary)
            }
        }
    }

    private var result: some View {
        ZenithSection(text.resultSection, anchor: .zenithRemoveBackgroundResult, footer: text.footnote) {
            ZenithRow(text.output, selection: $output, info: text.outputCaption) {
                ForEach(RemoveBackgroundOutput.allCases) { Text($0.title).tag($0.rawValue) }
            }
            ZenithRow(text.framing, selection: $framing, info: text.framingCaption) {
                ForEach(RemoveBackgroundFraming.allCases) { Text($0.title).tag($0.rawValue) }
            }
        }
    }
}

// MARK: - Stage art

/// A picture card: a figure on a sunset and hills, then the figure alone on
/// the transparency checkerboard, then cropped to it. Still, as the stage
/// pills choose.
struct RemoveBackgroundStageArt: View {
    let state: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 22) {
            card(cutout: false, cropped: false)
                .opacity(state == 0 ? 1 : 0.55)
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.55))
            card(cutout: true, cropped: state == 2)
                .opacity(state == 0 ? 0.55 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state == 0 ? "A photo with its background" : "The subject on a transparent background")
    }

    private func card(cutout: Bool, cropped: Bool) -> some View {
        let width: CGFloat = cropped ? 92 : 150, height: CGFloat = cropped ? 120 : 130
        return ZStack {
            if cutout {
                ZenithHeroChecker(square: 9, dark: colorScheme == .dark)
            } else {
                LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.4), Color(red: 0.55, green: 0.35, blue: 0.75)],
                               startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1, green: 0.86, blue: 0.55)).frame(width: 34).offset(x: 40, y: -30)
                Ellipse().fill(Color(red: 0.25, green: 0.2, blue: 0.45)).frame(width: 220, height: 90).offset(x: -30, y: 62)
            }
            RemoveBackgroundFigure()
                .frame(width: 70, height: 100)
                .offset(y: cropped ? 6 : 16)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

/// The subject: a head and shoulders in a warm tone.
struct RemoveBackgroundFigure: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.98, blue: 1), Color(red: 0.8, green: 0.84, blue: 0.95)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 70, height: 60)
                .offset(y: 34)
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.7), Color(red: 0.93, green: 0.68, blue: 0.52)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 40, height: 40)
                .offset(y: -16)
        }
    }
}
