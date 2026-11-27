// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// The emoji list comes from Unicode's emoji data and CLDR (Unicode License v3);
// see Resources/Emoji/NOTICE.txt.

import SwiftUI

/// Zenith fork: Settings → Emoji Picker, a feature page on the Settings kit:
/// the hero with the master switch (which asks for Accessibility, for the
/// paste, the first time), a stage of the panel, the skin tone as pictures,
/// how it opens and what it remembers, and Unicode's credit. Everything
/// writes `EmojiPickerDefaults`; `EmojiPickerService` follows.
struct EmojiPickerSettingsPage: View {
    @ObservedObject private var service = EmojiPickerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(EmojiPickerDefaults.enabled) private var enabled = false
    @AppStorage(EmojiPickerDefaults.skinTone) private var skinTone = ""
    @AppStorage(EmojiPickerDefaults.recentCount) private var recentCount = EmojiPickerDefaults.defaultRecentCount
    @AppStorage(EmojiPickerDefaults.showInCommandBar) private var showInCommandBar = true
    @AppStorage(EmojiPickerDefaults.shortcut) private var shortcut = EmojiPickerService.defaultShortcut.storageValue
    @State private var stageState = 0
    @State private var showsLicense = false
    @State private var cleared = false

    private let text = ZenithStrings.emojiPicker(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                           isOn: Binding(get: { enabled }, set: { service.setEnabled($0) }),
                           switchLabel: text.enable, switchHint: text.enableHint, animation: .emojiPicker)
                    .zenithSectionAnchor(.zenithEmojiPicker, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                if enabled, !permissions.accessibility {
                    ZenithCallout(.warning, text.accessibilityNeeded) {
                        Button(text.openAccessibility) { Permissions.shared.requestAccessibility() }
                    }
                }
                ZenithStage(caption: text.stageCaption, states: [text.stageBrowse, text.stageSearch],
                            selection: $stageState) {
                    EmojiPickerStageArt(searching: stageState == 1, tone: tone)
                }
                Group {
                    tones
                    opening
                    picking
                    credit
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var tone: CommandBarEmoji.SkinTone { CommandBarEmoji.SkinTone(rawValue: skinTone) ?? .none }

    private var chips: [ZenithChip] {
        var chips = [ZenithChip(text.emojiCount(EmojiCatalog.shared.count))]
        if let saved = GlobalShortcut(storageValue: shortcut) { chips.append(ZenithChip(saved.displayString)) }
        chips.append(ZenithChip(tone.swatch + " " + text.tone(tone)))
        return chips
    }

    // MARK: Sections

    private var tones: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.skinTone)
            ZenithVisualPicker(text.skinTone, selection: $skinTone,
                               options: CommandBarEmoji.SkinTone.allCases.map {
                                   ZenithPickerOption($0.rawValue, text.tone($0), detail: text.skinToneCaption)
                               }) { value, _ in
                Text(verbatim: (CommandBarEmoji.SkinTone(rawValue: value) ?? .none).swatch)
                    .font(.system(size: 30))
                    .accessibilityHidden(true)
            }
        }
    }

    private var opening: some View {
        ZenithSection(text.openSection) {
            ZenithShortcutSettingRow(text.shortcut, info: text.shortcutCaption,
                                     storageKey: EmojiPickerDefaults.shortcut,
                                     fallback: EmojiPickerService.defaultShortcut,
                                     refused: service.shortcutRefused,
                                     conflict: service.conflict(for:),
                                     sync: service.syncWithPreferences)
            ZenithRow(text.showInCommandBar, isOn: $showInCommandBar, info: text.showInCommandBarCaption)
        }
    }

    private var picking: some View {
        ZenithSection(text.pickingSection, anchor: .zenithEmojiPickerPicking) {
            ZenithRow(text.recentCount, value: $recentCount, in: EmojiPickerDefaults.recentCountRange, step: 4,
                      info: text.recentCountCaption)
            ZenithRow(text.clearRecents, info: text.clearRecentsCaption, button: cleared ? "Cleared" : text.clearRecents) {
                service.clearUsage()
                cleared = true
            }
        }
    }

    private var credit: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZenithFootnote(text.licenceLine)
                Button(showsLicense ? text.hideLicense : text.showLicense) { showsLicense.toggle() }
                    .buttonStyle(.link)
                    .font(ZenithType.caption)
            }
            if showsLicense {
                Text(verbatim: Self.notice)
                    .font(ZenithType.mono(10))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
            }
        }
    }

    /// The bundled notice, with the Unicode licence in full.
    static var notice: String {
        guard let url = Bundle.main.url(forResource: "NOTICE", withExtension: "txt", subdirectory: EmojiCatalog.resourceFolder),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "Unicode License v3" }
        return text
    }
}

// MARK: - Stage art

/// The panel in miniature: its search field and a few rows of emoji, the
/// chosen one ringed.
struct EmojiPickerStageArt: View {
    let searching: Bool
    let tone: CommandBarEmoji.SkinTone

    private static let browse = ["😀", "😂", "🥰", "😎", "🤔", "😴", "👋", "👍", "🙏", "👏", "💪", "🫶",
                                 "🐱", "🐶", "🌸", "🍕", "☕️", "🚀"]
    private static let found = ["🐱", "🐈", "😺", "😸", "😻", "😼"]

    var body: some View {
        let emoji = searching ? Self.found : Self.browse
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 10, weight: .semibold))
                Text(verbatim: searching ? "cat" : "Search emoji")
                    .font(.system(size: 12))
                    .opacity(searching ? 1 : 0.5)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.12)))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 2), count: 6), spacing: 2) {
                ForEach(Array(emoji.enumerated()), id: \.offset) { index, character in
                    Text(verbatim: CommandBarEmoji.applying(tone, to: character))
                        .font(.system(size: 19))
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(index == (searching ? 0 : 7) ? Color.white.opacity(0.22) : .clear))
                }
            }
        }
        .padding(10)
        .frame(width: 210)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.06).opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(searching ? "The picker finding cats" : "The picker's grid of emoji")
    }
}
