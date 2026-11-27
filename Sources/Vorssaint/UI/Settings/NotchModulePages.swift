// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import EventKit
import SwiftUI

// Zenith fork: the island's sections with options of their own, each a page
// in the Island group (docs/SETTINGS-KIT.md, feature page recipe): the hero
// with the section's switch for the island, the section in the open island
// on the stage, then its options. Their place among the sections and the
// sections without options stay on the Dynamic Island page.

// MARK: - Shell

/// Whether a section shows in the island: its own switch where it has one,
/// and its absence from the hidden list, as the island page's list reads it.
enum NotchModuleShowing {
    static func binding(_ module: NotchModule, hidden: Binding<String>, enabled: Binding<Bool>? = nil) -> Binding<Bool> {
        Binding {
            (enabled?.wrappedValue ?? true)
                && !hidden.wrappedValue.split(separator: ",").contains(Substring(module.rawValue))
        } set: { shown in
            enabled?.wrappedValue = shown
            var values = Set(hidden.wrappedValue.split(separator: ",").map(String.init))
            if shown { values.remove(module.rawValue) } else { values.insert(module.rawValue) }
            hidden.wrappedValue = values.sorted().joined(separator: ",")
            NotchService.shared.syncWithPreferences()
        }
    }
}

/// The page every section shares: the hero, a note while the island is off,
/// the section on the stage and the section's options under it.
struct NotchModuleSettingsPage<Animation: ZenithHeroAnimation, Content: View>: View {
    let module: NotchModule
    let subtitle: String
    var chips: [ZenithChip] = []
    let isShown: Binding<Bool>
    let animation: Animation
    let content: Content
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false

    init(module: NotchModule, subtitle: String, chips: [ZenithChip] = [], isShown: Binding<Bool>,
         animation: Animation, @ViewBuilder content: () -> Content) {
        self.module = module
        self.subtitle = subtitle
        self.chips = chips
        self.isShown = isShown
        self.animation = animation
        self.content = content()
    }

    private var text: ZenithIslandPagesStrings { ZenithStrings.islandPages(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: module.title(l10n.language), subtitle: subtitle, chips: chips, isOn: isShown,
                           switchLabel: text.showInIsland, switchHint: text.showInIslandHint, animation: animation)
                if !islandEnabled {
                    ZenithCallout(.info, text.islandOff) {
                        Button(text.turnOnIsland) {
                            islandEnabled = true
                            NotchService.shared.syncWithPreferences()
                        }
                    }
                }
                NotchModuleStage(module: module, caption: text.previewCaption)
                content
                HStack(spacing: 8) {
                    ZenithFootnote(text.moreOnIslandPage)
                    Button(FeatureStrings.notch(l10n.language).title) {
                        router.request(FeatureSettingsDestination(notch: .module(.controls)))
                    }
                    .buttonStyle(.link)
                    .font(ZenithType.caption)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }
}

/// A section in the open island, on the stage.
struct NotchModuleStage: View {
    let module: NotchModule
    let caption: String

    var body: some View {
        ZenithSettingsPreviewCard(id: "notch." + module.rawValue, caption: caption) {
            let size = ZenithPreviewOpenIsland<NotchPagePreview>.size(module)
            ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: size.width, minimum: 720)) {
                ZenithPreviewOpenIsland(module: module)
            }
            .id(module)
        }
    }
}

// MARK: - Calendar

struct NotchCalendarSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchCalendarEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchCalendarCountdown) private var countdown = false
    @AppStorage(DefaultsKey.notchCalendarCountdownLead) private var countdownLead = NotchCalendarSupport.defaultCountdownLeadMinutes
    @AppStorage(DefaultsKey.notchCalendarTimeLeft) private var timeLeft = false
    @AppStorage(DefaultsKey.notchCalendarWeekNumbers) private var weekNumbers = false

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let calendar = FeatureStrings.notchCalendar(l10n.language)
        let granted = permissions.calendarAccess == .fullAccess
        NotchModuleSettingsPage(module: .calendar, subtitle: text.calendarSubtitle,
                                chips: [granted ? ZenithChip(text.granted) : ZenithChip(text.needsAccess, dot: ZenithStatus.warning)],
                                isShown: NotchModuleShowing.binding(.calendar, hidden: $hidden, enabled: $enabled),
                                animation: .calendar) {
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

struct NotchNotificationsSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchNotificationsEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchDismissNativeNotifications) private var dismissNative = false

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let notifications = FeatureStrings.notchNotifications(l10n.language)
        NotchModuleSettingsPage(module: .notifications, subtitle: text.notificationsSubtitle,
                                isShown: NotchModuleShowing.binding(.notifications, hidden: $hidden, enabled: $enabled),
                                animation: .notifications) {
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

struct NotchMusicSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
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
        NotchModuleSettingsPage(module: .music, subtitle: text.musicSubtitle, chips: chips,
                                isShown: NotchModuleShowing.binding(.music, hidden: $hidden), animation: .music) {
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

struct NotchTimerSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchTimerEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchTimerSoundEnabled) private var sound = true
    @AppStorage(DefaultsKey.notchHideTimerCountdown) private var hideCountdown = false

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let activities = FeatureStrings.notchActivities(l10n.language)
        NotchModuleSettingsPage(module: .timer, subtitle: text.timerSubtitle,
                                chips: [ZenithChip(sound ? text.soundOn : text.silent)],
                                isShown: NotchModuleShowing.binding(.timer, hidden: $hidden, enabled: $enabled),
                                animation: .timer) {
            ZenithSection(text.timer) {
                ZenithRow(activities.soundEnabled, isOn: $sound)
                ZenithRow(activities.hideTimerCountdown, isOn: $hideCountdown)
            }
        }
        .onChange(of: [String(sound), String(hideCountdown)]) { _, _ in NotchService.shared.syncWithPreferences() }
    }
}

// MARK: - Agents

struct NotchAgentsSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchAgentsEnabled) private var enabled = false
    @AppStorage(DefaultsKey.notchAgentsClaude) private var claude = true
    @AppStorage(DefaultsKey.notchAgentsCodex) private var codex = true
    @AppStorage(DefaultsKey.notchAgentsOpenCode) private var opencode = true
    @AppStorage(DefaultsKey.notchAgentsCopilot) private var copilot = true
    @AppStorage(DefaultsKey.notchAgentsCursor) private var cursor = true

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        let count = [claude, codex, opencode, copilot, cursor].filter { $0 }.count
        NotchModuleSettingsPage(module: .agents, subtitle: text.agentsSubtitle,
                                chips: [ZenithChip(text.agentCount(count))],
                                isShown: NotchModuleShowing.binding(.agents, hidden: $hidden, enabled: $enabled),
                                animation: .agents) {
            NotchAgentsSettingsControls()
        }
    }
}

// MARK: - Downloads

struct NotchDownloadsSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        NotchModuleSettingsPage(module: .downloads, subtitle: text.downloadsSubtitle,
                                isShown: NotchModuleShowing.binding(.downloads, hidden: $hidden),
                                animation: .downloads) {
            NotchDownloadsSettingsControls()
        }
    }
}

// MARK: - Watch

struct NotchWatchSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHiddenModules) private var hidden = ""
    @AppStorage(DefaultsKey.notchWatchEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchWatchSound) private var sound = true

    var body: some View {
        let text = ZenithStrings.islandPages(l10n.language)
        NotchModuleSettingsPage(module: .watch, subtitle: text.watchSubtitle,
                                chips: [ZenithChip(sound ? text.soundOn : text.silent)],
                                isShown: NotchModuleShowing.binding(.watch, hidden: $hidden, enabled: $enabled),
                                animation: .watch) {
            NotchWatchSettingsControls()
        }
    }
}
