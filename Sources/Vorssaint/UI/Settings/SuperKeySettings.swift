// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct SuperKeySettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var superKey = SuperKeyService.shared
    @AppStorage(DefaultsKey.superKeyEnabled) private var enabled = false
    @AppStorage(DefaultsKey.superKeySource) private var sourceRaw = SuperKeySource.capsLock.rawValue
    @AppStorage(DefaultsKey.superKeyModifiers) private var modifierStorage =
        SuperKeySupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.superKeySoloAction) private var soloActionRaw = SuperKeySoloAction.none.rawValue

    private var text: SuperKeyStrings { FeatureStrings.superKey(l10n.language) }

    private struct ModifierChoice: Identifiable {
        let modifier: GlobalShortcutModifiers
        let symbol: String
        let name: String
        var id: String { name }
    }

    private let modifierChoices = [
        ModifierChoice(modifier: .shift, symbol: "⇧", name: "Shift"),
        ModifierChoice(modifier: .control, symbol: "⌃", name: "Control"),
        ModifierChoice(modifier: .option, symbol: "⌥", name: "Option"),
        ModifierChoice(modifier: .command, symbol: "⌘", name: "Command"),
    ]

    private var pageText: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    // Zenith fork: a kit feature page: the hero with the master switch, the
    // key to hold as pictures, the modifiers it stands for, then what a press
    // alone does.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.pageTitle, subtitle: pageText.superKeySubtitle, chips: chips,
                           isOn: enabledBinding, switchLabel: text.enableToggle, switchHint: text.enableCaption,
                           animation: .superKey)
                if enabled, let failure = superKey.mappingFailure {
                    ZenithCallout(.warning, text.mappingFailure(failure))
                } else if enabled, superKey.isPausedForApplication {
                    ZenithCallout(.info, FeatureStrings.mouseExceptions(l10n.language).pausedSuperKey)
                }
                if enabled, !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithSuperKeyPreviewCard()
                VStack(alignment: .leading, spacing: 10) {
                    ZenithSectionTitle(text.sourceKey)
                    ZenithVisualPicker(text.sourceKey, selection: sourceBinding,
                                       options: SuperKeySource.allCases.map { ZenithPickerOption($0, text.sourceLabel($0)) },
                                       minimumTileWidth: 96, tileHeight: 56) { source, selected in
                        SuperKeySourceArt(source: source, selected: selected)
                    }
                    ZenithSection {
                        ZenithRow(pageText.modifiersRow, info: text.modifierKeysNote) {
                            HStack(spacing: 5) {
                                ForEach(modifierChoices) { modifierKeyCap($0) }
                            }
                        }
                        if enabled {
                            MouseExceptionsList(scope: .superKey).padding(.vertical, 8)
                        }
                    }
                }
                .zenithPreviewTarget("superKey.main")
                ZenithSection(pageText.soloSection) {
                    ZenithRow(text.soloSection, selection: soloBinding, info: text.soloCaption) {
                        Text(text.soloNothing).tag(SuperKeySoloAction.none)
                        Text(text.soloCapsLock).tag(SuperKeySoloAction.capsLock)
                        Text(text.soloInputSource).tag(SuperKeySoloAction.inputSource)
                        Text(text.soloEscape).tag(SuperKeySoloAction.escape)
                    }
                }
                .disabled(!enabled)
                .zenithPreviewTarget("superKey.solo")
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .zenithPreviewJumps()
    }

    private var chips: [ZenithChip] {
        let glyphs = modifierChoices.filter { selectedModifiers.contains($0.modifier) }.map(\.symbol).joined()
        var chips = [ZenithChip(text.sourceLabel(source)), ZenithChip(glyphs)]
        if enabled, superKey.isRunning, superKey.mappingFailure == nil, !superKey.isPausedForApplication {
            chips.append(ZenithChip(text.activeNow, dot: ZenithStatus.success))
        }
        return chips
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { value in
            enabled = value
            SuperKeyService.shared.syncWithPreferences()
            guard value, !permissions.accessibility else { return }
            permissions.requestAccessibility()
            permissions.openAccessibilitySettings()
        })
    }

    private func modifierKeyCap(_ choice: ModifierChoice) -> some View {
        let selected = selectedModifiers.contains(choice.modifier)
        return Button {
            toggle(choice.modifier)
        } label: {
            Text(choice.symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(minWidth: 30, minHeight: 30)
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected
                            ? Color.accentColor.opacity(0.14)
                            : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(selected
                            ? Color.accentColor.opacity(0.45)
                            : Color.primary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled || (selected && !canRemove(choice.modifier)))
        .help(choice.name)
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectedModifiers: GlobalShortcutModifiers {
        SuperKeySupport.modifiers(from: modifierStorage)
    }

    private var source: SuperKeySource { SuperKeySource.sanitized(sourceRaw) }

    private var sourceBinding: Binding<SuperKeySource> {
        Binding {
            source
        } set: { source in
            sourceRaw = source.rawValue
            SuperKeyService.shared.syncWithPreferences()
        }
    }

    private func toggle(_ modifier: GlobalShortcutModifiers) {
        var next = selectedModifiers
        if next.contains(modifier) {
            next.remove(modifier)
        } else {
            next.insert(modifier)
        }
        guard next.hasPrimaryModifier else { return }
        modifierStorage = SuperKeySupport.storageValue(for: next)
        SuperKeyService.shared.syncWithPreferences()
    }

    private func canRemove(_ modifier: GlobalShortcutModifiers) -> Bool {
        var remaining = selectedModifiers
        remaining.remove(modifier)
        return remaining.hasPrimaryModifier
    }

    private var soloBinding: Binding<SuperKeySoloAction> {
        Binding {
            SuperKeySoloAction.sanitized(soloActionRaw)
        } set: { action in
            soloActionRaw = action.rawValue
            SuperKeyService.shared.syncWithPreferences()
        }
    }
}

/// Zenith fork: a source key's tile: the key as a keycap with its symbol.
private struct SuperKeySourceArt: View {
    let source: SuperKeySource
    let selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.84)], startPoint: .top, endPoint: .bottom))
            .frame(width: source == .capsLock ? 58 : 40, height: 30)
            .overlay(Image(systemName: source.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.65)))
            .shadow(color: .black.opacity(0.3), radius: selected ? 4 : 2, y: 2)
            .accessibilityHidden(true)
    }
}
