// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: Settings → Lock Screen. The island's lock screen switch and
/// its padlock sounds, then three cards: what shows over the wallpaper (the
/// island's items, the job rings and their sources, the song's title and its
/// lyrics), the terminal readout and where it sits, and the full-screen
/// lyrics with each of their parts. A part that depends on another is greyed
/// while that one is off. Every switch is drawn in SwiftUI (ZenithSwitchRow).
struct ZenithLockScreenSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLockScreen) private var lockScreen = false
    @AppStorage(DefaultsKey.notchLockSounds) private var lockSounds = false
    @AppStorage(DefaultsKey.notchLockScreenTerminal) private var terminal = false
    @AppStorage(DefaultsKey.zenithLockTerminalPlacement) private var placement = ZenithLockScreenTerminalPlacement.fallback.rawValue
    // Over the wallpaper.
    @AppStorage(DefaultsKey.zenithLockJobs) private var jobs = true
    @AppStorage(DefaultsKey.zenithLockJobExport) private var jobExport = true
    @AppStorage(DefaultsKey.zenithLockJobCardImport) private var jobCardImport = true
    @AppStorage(DefaultsKey.zenithLockJobBackup) private var jobBackup = true
    @AppStorage(DefaultsKey.zenithLockJobCommand) private var jobCommand = true
    @AppStorage(DefaultsKey.zenithLockJobVercel) private var jobVercel = true
    @AppStorage(DefaultsKey.zenithLockNowPlaying) private var nowPlaying = true
    @AppStorage(DefaultsKey.zenithLockLyrics) private var lyrics = true
    @AppStorage(DefaultsKey.zenithLockKaraoke) private var karaoke = true
    @AppStorage(DefaultsKey.zenithLockTitleControls) private var titleControls = true
    // Full-screen lyrics.
    @AppStorage(DefaultsKey.zenithLockFull) private var full = true
    @AppStorage(DefaultsKey.zenithLockFullDisc) private var fullDisc = true
    @AppStorage(DefaultsKey.zenithLockFullAccount) private var fullAccount = true
    @AppStorage(DefaultsKey.zenithLockFullDevice) private var fullDevice = true
    @AppStorage(DefaultsKey.zenithLockFullClock) private var fullClock = true
    @AppStorage(DefaultsKey.zenithLockFullJobs) private var fullJobs = true
    @AppStorage(DefaultsKey.zenithLockFullCoverColor) private var fullCoverColor = true
    @AppStorage(DefaultsKey.zenithLockFullLoginHint) private var fullLoginHint = true
    @AppStorage(DefaultsKey.zenithLockFullBackground) private var storedBackground = ZenithLockScreenFullBackground.fallback.rawValue
    @AppStorage(DefaultsKey.zenithLockFullBlurRadius) private var blurRadius = ZenithLockScreenFullBlur.fallback
    @AppStorage(DefaultsKey.zenithLockFullCustomColor) private var customColor =
        ZenithLockScreenCustomColor.string(ZenithLockScreenCustomColor.fallback)

    private var text: ZenithLockScreenSettingsStrings { ZenithStrings.lockScreenSettings(l10n.language) }
    private var locked: NotchLockScreenStrings { FeatureStrings.notchLockScreen(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: locked.title, subtitle: text.subtitle)
                SettingsCard {
                    switchRow("lock.display", locked.show, caption: locked.showHint, isOn: $lockScreen)
                    switchRow("speaker.wave.2", locked.sounds, caption: locked.soundsHint, isOn: $lockSounds)
                }
                // Kept in view while the lock screen is off, greyed, so the
                // page reads the same whichever way the switch is.
                Group {
                    overWallpaperCard
                    terminalCard
                    fullCard
                }
                .disabled(!lockScreen)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    // MARK: Cards

    private var overWallpaperCard: some View {
        SettingsCard(title: text.overWallpaper) {
            NotchLockScreenItemToggles()
            row(text.jobs, symbol: "hourglass", isOn: $jobs)
            Group {
                row(text.jobExport, symbol: "film", isOn: $jobExport, enabled: jobs)
                row(text.jobCardImport, symbol: "sdcard", isOn: $jobCardImport, enabled: jobs)
                row(text.jobBackup, symbol: "externaldrive.badge.checkmark", isOn: $jobBackup, enabled: jobs)
                row(text.jobCommand, symbol: "terminal", isOn: $jobCommand, enabled: jobs)
                row(text.jobVercel, symbol: NotchModule.vercel.symbol, isOn: $jobVercel, enabled: jobs)
            }
            .padding(.leading, Self.indent)
            row(text.nowPlaying, symbol: "music.note", isOn: $nowPlaying)
            row(text.titleControls, symbol: "playpause", isOn: $titleControls, enabled: nowPlaying)
                .padding(.leading, Self.indent)
            row(text.lyrics, symbol: "quote.bubble", caption: text.lyricsCaption, isOn: $lyrics)
            row(text.karaoke, symbol: "highlighter", isOn: $karaoke, enabled: lyrics)
                .padding(.leading, Self.indent)
        }
        .zenithSectionAnchor(.zenithLockScreen, cornerRadius: ZenithRadius.panel + 6, inset: 6) // Settings search lands here
    }

    private var terminalCard: some View {
        SettingsCard(title: text.terminal) {
            NotchLockScreenTerminalSettings()
            if terminal {
                HStack(spacing: 12) {
                    ZenithLockScreenRowLabel(title: text.placement, symbol: "arrow.up.and.down")
                    Spacer(minLength: 12)
                    Picker(text.placement, selection: placementChoice) {
                        ForEach(ZenithLockScreenTerminalPlacement.allCases) { choice in
                            Text(title(choice)).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.leading, Self.indent)
            }
        }
        .zenithSectionAnchor(.zenithLockScreenTerminal, cornerRadius: ZenithRadius.panel + 6, inset: 6)
    }

    private var fullCard: some View {
        SettingsCard(title: text.fullSection) {
            row(text.full, symbol: "music.note.list", isOn: $full)
            Group {
                row(text.fullDisc, symbol: "opticaldisc", isOn: $fullDisc, enabled: full)
                row(text.fullAccount, symbol: "person.crop.circle", isOn: $fullAccount, enabled: full)
                row(text.fullDevice, symbol: "laptopcomputer", isOn: $fullDevice, enabled: full)
                row(text.fullClock, symbol: "clock", isOn: $fullClock, enabled: full)
                // The rings come from the job progress above.
                row(text.jobs, symbol: "hourglass", isOn: $fullJobs, enabled: full && jobs)
                row(text.fullLoginHint, symbol: "key", isOn: $fullLoginHint, enabled: full)
                backgroundRows
            }
            .padding(.leading, Self.indent)
            Text(text.fullCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .zenithSectionAnchor(.zenithLockScreenLyrics, cornerRadius: ZenithRadius.panel + 6, inset: 6)
    }

    /// The full layer's background: a solid colour, from the cover or chosen
    /// here, or the cover itself blurred, with how strongly.
    @ViewBuilder
    private var backgroundRows: some View {
        let blurred = fullBackground == .blurredCover
        choiceRow(text.background, symbol: "photo", selection: backgroundChoice) {
            Text(text.backgroundSolid).tag(ZenithLockScreenFullBackground.solid)
            Text(text.backgroundBlurred).tag(ZenithLockScreenFullBackground.blurredCover)
        }
        Group {
            if blurred {
                HStack(spacing: 12) {
                    ZenithLockScreenRowLabel(title: text.blur, symbol: "drop")
                    Spacer(minLength: 12)
                    Text(text.blurSoft).font(ZenithType.caption).foregroundStyle(.secondary)
                    Slider(value: blurChoice, in: ZenithLockScreenFullBlur.range, step: 1) { Text(text.blur) }
                        .labelsHidden()
                        .frame(minWidth: 120, maxWidth: 200)
                    Text(text.blurStrong).font(ZenithType.caption).foregroundStyle(.secondary)
                }
            } else {
                choiceRow(text.color, symbol: "paintpalette", selection: $fullCoverColor) {
                    Text(text.colorFromCover).tag(true)
                    Text(text.colorChoose).tag(false)
                }
                if !fullCoverColor {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            ZenithLockScreenRowLabel(title: text.colorChoose, symbol: "eyedropper")
                            Spacer(minLength: 12)
                            ColorPicker(text.colorChoose, selection: customColorChoice, supportsOpacity: false)
                                .labelsHidden()
                        }
                        Text(text.customColorCaption)
                            .font(ZenithType.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(.leading, Self.indent)
        .disabled(!full)
    }

    // MARK: Rows

    /// A label and a few segments, greyed while the full layer is off.
    private func choiceRow<Value: Hashable, Options: View>(_ title: String, symbol: String, selection: Binding<Value>,
                                                           @ViewBuilder options: () -> Options) -> some View {
        HStack(spacing: 12) {
            ZenithLockScreenRowLabel(title: title, symbol: symbol)
            Spacer(minLength: 12)
            Picker(title, selection: selection) { options() }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
        }
        .disabled(!full)
    }

    /// How far a part that depends on the row above it is indented.
    private static let indent: CGFloat = 22

    /// The island's own switch rows: an icon tile, a title and its caption.
    private func switchRow(_ symbol: String, _ title: String, caption: String? = nil, isOn: Binding<Bool>) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(ZenithSwitchStyle())
        }
    }

    /// One part of the lock screen, greyed and fixed while `enabled` is false.
    private func row(_ title: String, symbol: String, caption: String? = nil, isOn: Binding<Bool>,
                     enabled: Bool = true) -> some View {
        ZenithSwitchRow(title, isOn: isOn) {
            ZenithLockScreenRowLabel(title: title, symbol: symbol, caption: caption)
        }
        .disabled(!enabled)
    }

    private var placementChoice: Binding<ZenithLockScreenTerminalPlacement> {
        Binding(get: { ZenithLockScreenTerminalPlacement(rawValue: placement) ?? .fallback },
                set: { placement = $0.rawValue })
    }

    private var fullBackground: ZenithLockScreenFullBackground {
        ZenithLockScreenFullBackground(rawValue: storedBackground) ?? .fallback
    }

    private var backgroundChoice: Binding<ZenithLockScreenFullBackground> {
        Binding(get: { fullBackground }, set: { storedBackground = $0.rawValue })
    }

    private var blurChoice: Binding<Double> {
        Binding(get: { min(max(blurRadius, ZenithLockScreenFullBlur.range.lowerBound), ZenithLockScreenFullBlur.range.upperBound) },
                set: { blurRadius = $0.rounded() })
    }

    /// The chosen colour as "RRGGBB", read and written in sRGB.
    private var customColorChoice: Binding<Color> {
        Binding(get: {
            let rgb = ZenithLockScreenCustomColor.parse(customColor) ?? ZenithLockScreenCustomColor.fallback
            return Color(.sRGB, red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255,
                         blue: Double(rgb & 0xFF) / 255)
        }, set: { color in
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            func byte(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
            let value = ZenithLockScreenCustomColor.string(byte(srgb.redComponent) << 16 | byte(srgb.greenComponent) << 8
                                                           | byte(srgb.blueComponent))
            if value != customColor { customColor = value }
        })
    }

    private func title(_ placement: ZenithLockScreenTerminalPlacement) -> String {
        switch placement {
        case .normal: return text.placementNormal
        case .low: return text.placementLow
        }
    }
}

/// A row's icon and title, with a caption under it, greyed when disabled.
private struct ZenithLockScreenRowLabel: View {
    let title: String
    let symbol: String
    var caption: String? = nil
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .foregroundStyle(isEnabled ? .primary : .secondary)
            if let caption {
                Text(caption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }
        }
    }
}
