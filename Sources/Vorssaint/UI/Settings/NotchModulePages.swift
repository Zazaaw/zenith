// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import EventKit
import SwiftUI

// Zenith fork: the Dynamic Island page's Modules section (docs/SETTINGS-KIT.md,
// a tile grid like System Monitor's): a tile per module with its Orbit icon,
// its name and the switch that shows it in the island, and the selected
// module's settings under the grid, opening with a small header and the
// module's own animation. Their place among the sections stays on the
// Content tab above.

// MARK: - Grid

/// The Modules section: the tiles, then the chosen module's settings.
struct IslandModulesSection: View {
    @Binding var selection: IslandSettingsModule
    /// The "show in the island" preference each tile's switch reads and writes.
    let showing: (IslandSettingsModule) -> Binding<Bool>
    /// Scrolls the page to an id inside the module's settings.
    let reveal: (String) -> Void
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    /// Where every way into a module scrolls the page to.
    static let anchorID = "zenith.island.modules"

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        VStack(alignment: .leading, spacing: 18) {
            ZenithSection(text.modules, footer: text.modulesFooter) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(IslandSettingsModule.allCases) { module in
                        IslandModuleTile(module: module, title: module.title(l10n.language),
                                         hint: module == .companion ? FeatureStrings.notchMascot(l10n.language).hint
                                             : text.showInIslandHint,
                                         selected: module == selection,
                                         available: features.isAvailable(module.feature),
                                         isOn: showing(module)) { selection = module }
                    }
                }
                .padding(.vertical, 12)
            }
            .id(Self.anchorID)
            IslandModuleDetail(module: selection, reveal: reveal)
                .id(selection)
        }
    }
}

/// One module: its icon on the stage (click it for its settings) and its switch.
private struct IslandModuleTile: View {
    let module: IslandSettingsModule
    let title: String
    let hint: String
    let selected: Bool
    let available: Bool
    @Binding var isOn: Bool
    let select: () -> Void
    @Environment(\.zenithTint) private var tint
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 8) {
            Button(action: select) {
                ZStack {
                    ZenithStageGradient(tint: tint, dark: colorScheme == .dark)
                    IslandModuleIcon(module: module, size: 36)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .opacity(available ? 1 : 0.45)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(shape)
                .overlay(shape.strokeBorder(selected ? Color.accentColor
                                                : Color.primary.opacity(contrast == .increased ? 0.3 : 0.08),
                                            lineWidth: selected ? 2.5 : 1))
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selected ? .isSelected : [])
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                // Off and still while its feature is out of Orbit; its settings say how to bring it back.
                ZenithRowSwitch(title: title, isOn: available ? $isOn : .constant(false))
                    .scaleEffect(0.85)
                    .disabled(!available)
                    .help(hint)
            }
        }
    }
}

/// A module's Orbit icon, from the bitmap cache.
private struct IslandModuleIcon: View {
    let module: IslandSettingsModule
    let size: CGFloat

    var body: some View {
        OrbitRasterizedIcon(key: "island-module|\(module.rawValue)", size: size) {
            if let icon = OrbitIcons.named(module.orbitName) {
                OrbitIconView(icon: icon)
            } else {
                SettingsFallbackIcon(symbol: module.notchModule?.symbol ?? AppFeature.notchMascot.symbolName,
                                     tint: SettingsSidebarGroup.island.tint)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Detail

/// The chosen module's settings, or how to bring it back while its feature
/// is out of Orbit.
private struct IslandModuleDetail: View {
    let module: IslandSettingsModule
    let reveal: (String) -> Void
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    var body: some View {
        if features.isAvailable(module.feature) {
            switch module {
            case .calendar: NotchCalendarModuleSettings()
            case .notifications: NotchNotificationsModuleSettings()
            case .music: NotchMusicModuleSettings()
            case .timer: NotchTimerModuleSettings()
            case .agents: NotchAgentsModuleSettings()
            case .downloads: NotchDownloadsModuleSettings()
            case .watch: NotchWatchModuleSettings()
            case .companion: NotchMascotModuleSettings(reveal: reveal)
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                IslandModuleHeader(module: module)
                ZenithCallout(.info, module.feature.enableReason(l10n)) {
                    Button(FeatureStrings.notchEditor(l10n.language).openFeatures) { module.feature.showInFeatures() }
                }
            }
        }
    }
}

/// The top of a module's settings: its animation, small, then its name,
/// what it does and a fact or two.
struct IslandModuleHeader: View {
    let module: IslandSettingsModule
    var chips: [ZenithChip] = []
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.zenithTint) private var tint
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    /// The hero's art at this scale.
    private static let scale: CGFloat = 0.44

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: ZenithKitSurface.heroRadius - 6, style: .continuous)
        HStack(alignment: .center, spacing: 14) {
            art
            VStack(alignment: .leading, spacing: 5) {
                Text(text.moduleSettings.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(tint.label(dark: dark).color)
                Text(module.title(l10n.language))
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(module.subtitle(text))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !chips.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        ForEach((1...chips.count).reversed(), id: \.self) { count in
                            HStack(spacing: 6) { ForEach(chips.prefix(count)) { $0 } }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(ZenithKitSurface.groupFill(dark: dark, opaque: true).opacity(dark ? 0.55 : 0.9))
                .overlay(shape.fill(LinearGradient(colors: [tint.deep.color.opacity(dark ? 0.16 : 0.1), .clear],
                                                   startPoint: .leading, endPoint: .center)))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(ZenithKitSurface.hairline(highContrast: contrast == .increased)))
    }

    private var art: some View {
        let size = ZenithHero<ZenithHeroIconArt>.artSize
        let tint = tint
        let dark = colorScheme == .dark
        let module = module
        return ZenithKitClock { t, moving in
            let context = ZenithHeroArtContext(t: t, moving: moving, tint: tint, dark: dark,
                                               icon: ZenithHeroIcon(orbitName: module.orbitName))
            IslandModuleArt(module: module, context: context)
                .frame(width: size, height: size)
                .scaleEffect(Self.scale)
                .frame(width: size * Self.scale, height: size * Self.scale)
        }
        .frame(width: size * Self.scale, height: size * Self.scale)
        .accessibilityHidden(true)
    }
}

/// Each module's hero animation (ZenithHeroAnimationsIsland).
private struct IslandModuleArt: View {
    let module: IslandSettingsModule
    let context: ZenithHeroArtContext

    var body: some View {
        switch module {
        case .calendar: ZenithCalendarHeroArt().art(context)
        case .notifications: ZenithNotificationsHeroArt().art(context)
        case .music: ZenithMusicHeroArt().art(context)
        case .timer: ZenithTimerHeroArt().art(context)
        case .agents: ZenithAgentsHeroArt().art(context)
        case .downloads: ZenithDownloadsHeroArt().art(context)
        case .watch: ZenithWatchHeroArt().art(context)
        case .companion: ZenithMascotHeroArt().art(context)
        }
    }
}

extension IslandSettingsModule {
    /// What the module does, under its name.
    func subtitle(_ text: ZenithIslandPagesStrings) -> String {
        switch self {
        case .calendar: return text.calendarSubtitle
        case .notifications: return text.notificationsSubtitle
        case .music: return text.musicSubtitle
        case .timer: return text.timerSubtitle
        case .agents: return text.agentsSubtitle
        case .downloads: return text.downloadsSubtitle
        case .watch: return text.watchSubtitle
        case .companion: return text.mascotSubtitle
        }
    }
}

// MARK: - Calendar

struct NotchCalendarModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.notchCalendarCountdown) private var countdown = false
    @AppStorage(DefaultsKey.notchCalendarCountdownLead) private var countdownLead = NotchCalendarSupport.defaultCountdownLeadMinutes
    @AppStorage(DefaultsKey.notchCalendarTimeLeft) private var timeLeft = false
    @AppStorage(DefaultsKey.notchCalendarWeekNumbers) private var weekNumbers = false

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let calendar = FeatureStrings.notchCalendar(l10n.language)
        let granted = permissions.calendarAccess == .fullAccess
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .calendar,
                               chips: [granted ? ZenithChip(text.granted) : ZenithChip(text.needsAccess, dot: ZenithStatus.warning)])
            if !granted {
                ZenithCallout(.warning, calendar.permission) {
                    Button(calendar.allow, action: permissions.requestCalendar).disabled(permissions.requestingCalendar)
                    Button(calendar.settings, action: permissions.openCalendarSettings)
                }
            }
            ZenithSection(text.countdown) {
                ZenithRow(calendar.countdown, isOn: $countdown, info: calendar.countdownHint)
                // Shown with the countdown off too: events chosen from their menu use the same lead.
                // A value outside the presets, from a backup or an older build, stays selectable.
                let lead = NotchCalendarSupport.countdownLeadMinutes(countdownLead)
                ZenithRow(calendar.countdownLead, selection: Binding(get: { lead }, set: { countdownLead = $0 })) {
                    ForEach(Set(NotchCalendarSupport.countdownLeadPresets + [lead]).sorted(), id: \.self) { minutes in
                        Text(AgentFormat.duration(TimeInterval(minutes * 60), locale: l10n.language.formattingLocale(),
                                                  style: .short)).tag(minutes)
                    }
                }
                ZenithRow(calendar.timeLeft, isOn: $timeLeft, info: calendar.timeLeftHint)
                ZenithMoreOptions(id: "notchCalendar") {
                    ZenithRow(calendar.weekNumbers, isOn: $weekNumbers)
                }
            }
            if granted {
                ZenithSection(calendar.calendars) {
                    NotchCalendarSelection(showsHeading: false)
                        .padding(.vertical, 8)
                }
            }
        }
        .onChange(of: [String(countdown), String(countdownLead), String(timeLeft), String(weekNumbers)]) { _, _ in
            NotchService.shared.syncWithPreferences()
        }
    }
}

// MARK: - Notifications

struct NotchNotificationsModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.notchNotificationsEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchDismissNativeNotifications) private var dismissNative = false

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let notifications = FeatureStrings.notchNotifications(l10n.language)
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .notifications)
            if enabled, !permissions.accessibility {
                ZenithSection(text.access) {
                    PermissionRow(kind: .accessibility).padding(.vertical, 8)
                }
            }
            ZenithSection(text.banners) {
                ZenithRow(notifications.hideSystemBanner, isOn: $dismissNative, info: notifications.hideSystemBannerHint)
            }
            ZenithSection(text.replies) {
                ZenithReplySettings()
            }
        }
        .onChange(of: dismissNative) { _, _ in NotchService.shared.syncWithPreferences() }
    }
}

// MARK: - Music

struct NotchMusicModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchShowPlayingMusic) private var showPlayingMusic = true
    @AppStorage(DefaultsKey.notchIncludeOtherPlayers) private var includeOtherPlayers = true
    @AppStorage(DefaultsKey.notchMusicShowVolume) private var showVolume = false
    @AppStorage(DefaultsKey.notchPreferredPlayer) private var preferredPlayer = NotchPreferredPlayer.automatic
    @AppStorage(DefaultsKey.notchLyricsEnabled) private var lyricsEnabled = true
    @AppStorage(DefaultsKey.notchLyricsOnline) private var lyricsOnline = false
    @AppStorage(DefaultsKey.notchBrowserCovers) private var browserCovers = false
    @AppStorage(DefaultsKey.notchQueueEnabled) private var queueEnabled = true
    @AppStorage(DefaultsKey.notchLiveEqualizer) private var liveEqualizer = false
    @State private var players: [NotchPreferredPlayer.Choice]?

    private var configuration: [String] {
        [String(showPlayingMusic), String(includeOtherPlayers), String(showVolume), preferredPlayer,
         String(lyricsEnabled), String(lyricsOnline), String(queueEnabled), String(liveEqualizer)]
    }

    private var chips: [ZenithChip] {
        let text = ZenithStrings.islandPages(l10n.language)
        var chips: [ZenithChip] = []
        if lyricsEnabled, AppFeature.notchLyrics.isAvailable { chips.append(ZenithChip(text.lyricsOn)) }
        if queueEnabled, AppFeature.notchQueue.isAvailable { chips.append(ZenithChip(text.queueOn)) }
        if liveEqualizer, AppFeature.notchLiveEqualizer.isAvailable { chips.append(ZenithChip(text.equalizerOn)) }
        return chips
    }

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let notch = FeatureStrings.notch(l10n.language)
        let music = FeatureStrings.notchMusicExtras(l10n.language)
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .music, chips: chips)
            ZenithSection(text.nowPlaying) {
                ZenithRow(notch.playingMusic, isOn: $showPlayingMusic)
                ZenithRow(music.includeOtherPlayers, isOn: $includeOtherPlayers)
                ZenithRow(music.preferredPlayer, selection: $preferredPlayer, info: music.preferredPlayerHint) {
                    Text(music.automaticSource).tag(NotchPreferredPlayer.automatic)
                    ForEach(NotchPreferredPlayer.choices(in: players ?? [], including: preferredPlayer), id: \.bundleID) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }
                .task {
                    guard let choices = await NotchPreferredPlayer.loadInstalled(), !Task.isCancelled else { return }
                    players = choices
                }
                ZenithMoreOptions(id: "notchMusic") {
                    SettingsFeatureSwitchRow(symbol: "speaker.wave.2", title: music.showVolume,
                                             isOn: $showVolume, feature: .mixer)
                    ZenithRow(music.browserCovers, isOn: $browserCovers, info: music.browserCoversHint)
                }
            }
            ZenithSection(text.lyricsAndQueue) {
                SettingsFeatureSwitchRow(symbol: "text.quote", title: music.enableLyrics, isOn: $lyricsEnabled,
                                         feature: .notchLyrics)
                if lyricsEnabled, AppFeature.notchLyrics.isAvailable {
                    ZenithRow(music.online, isOn: $lyricsOnline, info: music.onlineHint)
                }
                SettingsFeatureSwitchRow(symbol: "list.bullet", title: music.enableQueue, caption: music.queueDescription,
                                         isOn: $queueEnabled, feature: .notchQueue)
                SettingsFeatureSwitchRow(symbol: "waveform", title: music.liveEqualizer,
                                         caption: NotchAudioLevelSupport.isSupported ? music.liveEqualizerHint
                                            : music.liveEqualizerUnavailable,
                                         isOn: $liveEqualizer, feature: .notchLiveEqualizer,
                                         enabled: NotchAudioLevelSupport.isSupported)
            }
        }
        .onChange(of: configuration) { _, _ in
            NotchService.shared.syncWithPreferences()
            if !NotchLyricsSupport.isEnabled() { NotchLyricsService.shared.stop() }
            NotchMusicService.shared.syncQueuePreference()
        }
        .onChange(of: browserCovers) { _, _ in NotchMusicService.shared.syncBrowserCovers() }
    }
}

// MARK: - Timer

struct NotchTimerModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchTimerSoundEnabled) private var sound = true
    @AppStorage(DefaultsKey.notchHideTimerCountdown) private var hideCountdown = false

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let activities = FeatureStrings.notchActivities(l10n.language)
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .timer, chips: [ZenithChip(sound ? text.soundOn : text.silent)])
            ZenithSection(text.timer) {
                ZenithRow(activities.soundEnabled, isOn: $sound)
                ZenithRow(activities.hideTimerCountdown, isOn: $hideCountdown)
            }
        }
        .onChange(of: [String(sound), String(hideCountdown)]) { _, _ in NotchService.shared.syncWithPreferences() }
    }
}

// MARK: - Agents

struct NotchAgentsModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchAgentsClaude) private var claude = true
    @AppStorage(DefaultsKey.notchAgentsCodex) private var codex = true
    @AppStorage(DefaultsKey.notchAgentsOpenCode) private var opencode = true
    @AppStorage(DefaultsKey.notchAgentsCopilot) private var copilot = true
    @AppStorage(DefaultsKey.notchAgentsCursor) private var cursor = true

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let count = [claude, codex, opencode, copilot, cursor].filter { $0 }.count
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .agents, chips: [ZenithChip(text.agentCount(count))])
            NotchAgentsSettingsControls()
        }
    }
}

// MARK: - Downloads

struct NotchDownloadsModuleSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .downloads)
            NotchDownloadsSettingsControls()
        }
    }
}

// MARK: - Watch

struct NotchWatchModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWatchSound) private var sound = true

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        VStack(alignment: .leading, spacing: 18) {
            IslandModuleHeader(module: .watch, chips: [ZenithChip(sound ? text.soundOn : text.silent)])
            NotchWatchSettingsControls()
        }
    }
}
