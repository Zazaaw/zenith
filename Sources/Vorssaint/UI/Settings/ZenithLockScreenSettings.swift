// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: Settings → Lock Screen. The hero with the island's lock
/// screen switch, a live preview drawn on this Mac's wallpaper beside the
/// padlock sounds, then four tabs: what shows over the wallpaper (the
/// island's items and the job rings), the song's title and lyrics, the
/// terminal readout, and the full-screen lyrics with their corners and
/// background. Clicking a part of the preview opens its tab, and a search
/// result opens the tab its section is in. A part that depends on another is
/// greyed while that one is off. Every switch is drawn in SwiftUI.
struct ZenithLockScreenSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.notchLockScreen) private var lockScreen = false
    @AppStorage(DefaultsKey.notchLockSounds) private var lockSounds = false
    @AppStorage(DefaultsKey.zenithLockSettingsTab) private var storedTab = ZenithLockScreenSettingsTab.fallback.rawValue
    /// The layer picked in the preview card; nil follows the tab.
    @State private var previewOverride: ZenithLockScreenPreviewMode?

    private var text: ZenithLockScreenSettingsStrings { ZenithStrings.lockScreenSettings(l10n.language) }
    private var page: ZenithLockScreenPageStrings { ZenithStrings.lockScreenPage(l10n.language) }
    private var locked: NotchLockScreenStrings { FeatureStrings.notchLockScreen(l10n.language) }
    private var tab: ZenithLockScreenSettingsTab { .stored(storedTab) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Zenith fork: the kit's feature hero (docs/SETTINGS-KIT.md), the
                // lock screen's switch as its "On" pill.
                ZenithHero(title: locked.title, subtitle: page.subtitle, chips: [ZenithChip(title(tab))],
                           isOn: $lockScreen, switchLabel: locked.show, switchHint: locked.showHint,
                           animation: .lockScreen)
                previewCard
                VStack(alignment: .leading, spacing: 14) {
                    ZenithLockScreenTabBar(selection: Binding(get: { tab }, set: select), title: title)
                    // Kept in view while the lock screen is off, greyed, so
                    // the page reads the same whichever way the switch is.
                    Group {
                        switch tab {
                        case .wallpaper: ZenithLockScreenWallpaperTab()
                        case .music: ZenithLockScreenMusicTab()
                        case .terminal: ZenithLockScreenTerminalTab()
                        case .full: ZenithLockScreenFullTab()
                        }
                    }
                    .disabled(!lockScreen)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear(perform: followSearch)
        .onChange(of: router.requestID) { _, _ in followSearch() }
    }

    // MARK: Preview

    private var previewMode: ZenithLockScreenPreviewMode {
        previewOverride ?? (tab == .full ? .full : .minimal)
    }

    /// The preview, and beside it the layer it draws, what it outlines, and
    /// the padlock sounds, which belong to the lock screen as a whole. Zenith
    /// fork: the shared preview card every Settings page opens with.
    private var previewCard: some View {
        let modes: [ZenithLockScreenPreviewMode] = [.minimal, .full]
        return ZenithSettingsPreviewCard(
            id: "lockScreen", caption: page.previewWallpaper,
            states: [page.previewMinimal, page.previewFull],
            selection: Binding(get: { modes.firstIndex(of: previewMode) ?? 0 }, set: { index in
                let mode = modes[min(max(index, 0), modes.count - 1)]
                previewOverride = mode == (tab == .full ? .full : .minimal) ? nil : mode
            }),
            highlight: partName(tab.previewPart), aspectRatio: Self.screenRatio) {
            ZenithLockScreenPreview(mode: previewMode, highlight: tab.previewPart) { part in
                select(ZenithLockScreenSettingsTab(part: part))
            }
        } footer: {
            VStack(alignment: .leading, spacing: 10) {
                ZenithLockScreenDivider()
                ZenithLockScreenTitledSwitch(title: locked.sounds, isOn: $lockSounds, expands: true)
                    .help(locked.soundsHint)
            }
        }
    }

    /// This Mac's screen, width over height; a MacBook's when none is known.
    private static var screenRatio: CGFloat {
        guard let size = NSScreen.main?.frame.size, size.width > 0, size.height > 0 else { return 1800.0 / 1169.0 }
        return size.width / size.height
    }

    private func partName(_ part: ZenithLockScreenPreviewPart) -> String {
        switch part {
        case .activityRow: return page.activityRow
        case .nowPlaying: return page.titleAndLyrics
        case .terminal: return ZenithStrings.lockScreenTerminal(l10n.language).title
        case .full: return text.fullSection
        }
    }

    // MARK: Tabs

    private func title(_ tab: ZenithLockScreenSettingsTab) -> String {
        switch tab {
        case .wallpaper: return text.overWallpaper
        case .music: return page.tabMusic
        case .terminal: return text.terminal
        case .full: return text.fullSection
        }
    }

    /// Opens a tab; the preview follows it again.
    private func select(_ next: ZenithLockScreenSettingsTab) {
        previewOverride = nil
        if storedTab != next.rawValue { storedTab = next.rawValue }
    }

    /// A search that lands on this page opens the tab holding its section,
    /// before the page scrolls to it and outlines it.
    private func followSearch() {
        guard router.destination.page == .lockScreen,
              let landing = ZenithLockScreenSettingsTab(anchor: router.destination.sectionAnchor) else { return }
        select(landing)
    }
}

private extension ZenithLockScreenSettingsTab {
    /// The part the preview outlines while this tab is open.
    var previewPart: ZenithLockScreenPreviewPart {
        switch self {
        case .wallpaper: return .activityRow
        case .music: return .nowPlaying
        case .terminal: return .terminal
        case .full: return .full
        }
    }

    /// The tab of a part clicked in the preview.
    init(part: ZenithLockScreenPreviewPart) {
        switch part {
        case .activityRow: self = .wallpaper
        case .nowPlaying: self = .music
        case .terminal: self = .terminal
        case .full: self = .full
        }
    }
}

// MARK: - Over the wallpaper

/// The island's items in the activity row, as chips, and the job rings with
/// the sources they follow. Music has the Music & Lyrics tab.
private struct ZenithLockScreenWallpaperTab: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLockScreenWeather) private var weather = false
    @AppStorage(DefaultsKey.notchLockScreenReminders) private var reminders = false
    @AppStorage(DefaultsKey.zenithLockJobs) private var jobs = true
    @AppStorage(DefaultsKey.zenithLockJobExport) private var jobExport = true
    @AppStorage(DefaultsKey.zenithLockJobCardImport) private var jobCardImport = true
    @AppStorage(DefaultsKey.zenithLockJobBackup) private var jobBackup = true
    @AppStorage(DefaultsKey.zenithLockJobCommand) private var jobCommand = true
    @AppStorage(DefaultsKey.zenithLockJobVercel) private var jobVercel = true

    private var items: [NotchLockScreenItem] {
        // WakaTime only on a Mac that has it.
        NotchLockScreenItem.allCases.filter { $0 != .music && ($0 != .wakatime || WakaTimeSupport.hasConfiguration()) }
    }

    var body: some View {
        let text = ZenithStrings.lockScreenSettings(l10n.language)
        let page = ZenithStrings.lockScreenPage(l10n.language)
        VStack(alignment: .leading, spacing: 14) {
            ZenithLockScreenCard(title: page.activityRow, caption: page.activityRowCaption) {
                ZenithLockScreenChipGrid {
                    ForEach(items) { item in
                        ZenithLockScreenItemChip(item: item, title: item.title(l10n.language))
                    }
                }
                // What Weather and Reminders read, or the permission they miss.
                if weather { ZenithLockScreenWeatherAccess() }
                if reminders { ZenithLockScreenRemindersAccess() }
            }
            ZenithLockScreenCard(title: text.jobs, caption: page.jobsCaption) {
                ZenithLockScreenSwitch(title: text.jobs, isOn: $jobs)
            } content: {
                ZenithLockScreenChipGrid {
                    ZenithLockScreenChip(title: page.jobExport, symbol: "film", isOn: $jobExport, help: text.jobExport)
                    ZenithLockScreenChip(title: page.jobCardImport, symbol: "sdcard", isOn: $jobCardImport,
                                         help: text.jobCardImport)
                    ZenithLockScreenChip(title: text.jobBackup, symbol: "externaldrive.badge.checkmark", isOn: $jobBackup)
                    ZenithLockScreenChip(title: page.jobCommand, symbol: "terminal", isOn: $jobCommand,
                                         help: text.jobCommand)
                    ZenithLockScreenChip(title: NotchModule.vercel.title(l10n.language), symbol: NotchModule.vercel.symbol,
                                         isOn: $jobVercel, help: text.jobVercel)
                }
                .disabled(!jobs)
            }
            ZenithLockScreenIslandCard()
        }
        .zenithSectionAnchor(.zenithLockScreen, cornerRadius: ZenithRadius.panel + 6, inset: 6) // Settings search lands here
    }
}

/// The padlock island at the camera: its slots and its greetings, one switch each.
private struct ZenithLockScreenIslandCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.zenithLockIslandCharging) private var charging = true
    @AppStorage(DefaultsKey.zenithLockIslandFocus) private var focus = true
    @AppStorage(DefaultsKey.zenithLockIslandFarewell) private var farewell = true
    @AppStorage(DefaultsKey.zenithLockIslandWelcome) private var welcome = true

    var body: some View {
        let text = ZenithStrings.lockIsland(l10n.language)
        ZenithLockScreenCard(title: text.section, caption: text.sectionCaption) {
            VStack(alignment: .leading, spacing: 0) {
                line(text.charging, symbol: "bolt.fill", caption: text.chargingCaption, isOn: $charging)
                ZenithLockScreenDivider()
                line(text.focus, symbol: "moon.fill", caption: text.focusCaption, isOn: $focus)
                ZenithLockScreenDivider()
                line(text.farewell, symbol: "hand.wave", caption: text.farewellCaption, isOn: $farewell)
                ZenithLockScreenDivider()
                line(text.welcome, symbol: "lock.open", caption: text.welcomeCaption, isOn: $welcome)
            }
        }
    }

    private func line(_ title: String, symbol: String, caption: String, isOn: Binding<Bool>) -> some View {
        ZenithSwitchRow(title, isOn: isOn) {
            ZenithLockScreenLineLabel(title: title, symbol: symbol, caption: caption)
        }
        .padding(.vertical, 11)
    }
}

/// One of the island's items as a chip. Weather and Reminders ask for their
/// permission when turned on, never at launch or from the lock screen.
private struct ZenithLockScreenItemChip: View {
    let item: NotchLockScreenItem
    let title: String
    @AppStorage private var isOn: Bool

    init(item: NotchLockScreenItem, title: String) {
        self.item = item
        self.title = title
        _isOn = AppStorage(wrappedValue: item.isOnByDefault, item.defaultsKey)
    }

    var body: some View {
        ZenithLockScreenChip(title: title, symbol: item.symbol, isOn: $isOn)
            .onChange(of: isOn) { _, on in
                guard on else { return }
                switch item {
                case .weather: WeatherService.shared.requestAccess()
                case .reminders: RemindersService.shared.requestAccess()
                default: break
                }
            }
    }
}

/// Under the chips while Weather is on: where the data comes from, or what
/// permission is missing.
private struct ZenithLockScreenWeatherAccess: View {
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.lockScreenWidgets(l10n.language)
        ZenithLockScreenAccessNote(
            symbol: NotchLockScreenItem.weather.symbol, access: weather.access, caption: text.weatherCaption,
            needed: text.locationNeeded, denied: text.locationDenied, request: { weather.requestAccess() },
            openSettings: { weather.openLocationSettings() })
            .onAppear { weather.refreshAccess() }
    }
}

/// Under the chips while Reminders is on: what shows, or what permission is missing.
private struct ZenithLockScreenRemindersAccess: View {
    @ObservedObject private var reminders = RemindersService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.lockScreenWidgets(l10n.language)
        ZenithLockScreenAccessNote(
            symbol: NotchLockScreenItem.reminders.symbol, access: reminders.access, caption: text.remindersCaption,
            needed: text.remindersNeeded, denied: text.remindersDenied, request: { reminders.requestAccess() },
            openSettings: { reminders.openRemindersSettings() })
            .onAppear { reminders.refreshAccess() }
            // Access changed in System Settings shows here when Zenith comes back.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                reminders.refreshAccess()
            }
    }
}

private struct ZenithLockScreenAccessNote: View {
    let symbol: String
    let access: LockScreenWidgetAccess
    let caption: String
    let needed: String
    let denied: String
    let request: () -> Void
    let openSettings: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                switch access {
                case .granted:
                    Text(caption)
                case .notDetermined:
                    Text(needed)
                    Button(l10n.s.permissionRequest, action: request)
                        .controlSize(.small)
                case .denied:
                    Text(denied)
                    Button(l10n.s.permissionOpenSettings, action: openSettings)
                        .controlSize(.small)
                }
            }
        }
        .font(ZenithType.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Music & Lyrics

/// The lock screen's music, the song's title under the activity row, its
/// lyrics, the shade behind them and how far they are moved in time.
private struct ZenithLockScreenMusicTab: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLockScreenMusic) private var music = true
    @AppStorage(DefaultsKey.zenithLockNowPlaying) private var nowPlaying = true
    @AppStorage(DefaultsKey.zenithLockTitleControls) private var titleControls = true
    @AppStorage(DefaultsKey.zenithLockLyrics) private var lyrics = true
    @AppStorage(DefaultsKey.zenithLockKaraoke) private var karaoke = true
    @AppStorage(DefaultsKey.zenithLockLyricShade) private var lyricShade = true

    var body: some View {
        let text = ZenithStrings.lockScreenSettings(l10n.language)
        let page = ZenithStrings.lockScreenPage(l10n.language)
        let showsTitle = music && nowPlaying
        ZenithLockScreenCard {
            VStack(alignment: .leading, spacing: 0) {
                line(page.music, symbol: "music.note", isOn: $music)
                ZenithLockScreenDivider()
                line(text.nowPlaying, symbol: "text.below.photo", caption: page.nowPlayingCaption, isOn: $nowPlaying)
                    .disabled(!music)
                ZenithLockScreenDivider()
                line(text.titleControls, symbol: "playpause", isOn: $titleControls, indented: true)
                    .disabled(!showsTitle)
                ZenithLockScreenDivider()
                line(text.lyrics, symbol: "quote.bubble", caption: text.lyricsCaption, isOn: $lyrics)
                    .disabled(!showsTitle)
                ZenithLockScreenDivider()
                line(text.karaoke, symbol: "highlighter", isOn: $karaoke, indented: true)
                    .disabled(!(showsTitle && lyrics))
                ZenithLockScreenDivider()
                line(page.lyricShade, symbol: "shadow", caption: page.lyricShadeCaption, isOn: $lyricShade)
                    .disabled(!showsTitle)
                ZenithLockScreenDivider()
                ZenithLockScreenLyricTimingSlider()
                    .padding(.vertical, 12)
                    .disabled(!(showsTitle && lyrics))
            }
        }
        .zenithSectionAnchor(.zenithLockScreenMusic, cornerRadius: ZenithRadius.panel + 6, inset: 6)
    }

    /// One row: its label and switch; a part that hangs from the row above
    /// is indented.
    private func line(_ title: String, symbol: String, caption: String? = nil, isOn: Binding<Bool>,
                      indented: Bool = false) -> some View {
        ZenithSwitchRow(title, isOn: isOn) {
            ZenithLockScreenLineLabel(title: title, symbol: symbol, caption: caption)
        }
        .padding(.leading, indented ? 24 : 0)
        .padding(.vertical, 11)
    }
}

/// How far the lyrics are moved against the song, with zero in the middle.
private struct ZenithLockScreenLyricTimingSlider: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.zenithLockLyricOffset) private var offset = 0.0
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let page = ZenithStrings.lockScreenPage(l10n.language)
        let locale = l10n.language.formattingLocale()
        let range = ZenithLockScreenLyricOffset.range
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZenithLockScreenLineIcon(symbol: "timer")
                Text(page.lyricTiming)
                    .font(ZenithType.rowTitle)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                Spacer(minLength: 12)
                Text(page.offset(offset, locale: locale))
                    .font(ZenithType.mono(13, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                ZenithLockScreenOffsetSlider(value: $offset, label: page.lyricTiming) {
                    page.offset($0, locale: locale)
                }
                ZStack {
                    HStack {
                        Text("\(page.earlier) \(page.offset(range.lowerBound, locale: locale))")
                        Spacer(minLength: 8)
                        Text("\(page.offset(range.upperBound, locale: locale)) \(page.later)")
                    }
                    Text(0.formatted(.number.locale(locale)))
                }
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
                Text(page.lyricTimingCaption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, ZenithLockScreenLineLabel.textInset)
        }
    }
}

/// A slider from earlier to later with zero in the middle: a tick marks it,
/// the fill grows from it, and a drag passing near it settles on it.
private struct ZenithLockScreenOffsetSlider: View {
    @Binding var value: Double
    let label: String
    let valueText: (Double) -> String
    @Environment(\.isEnabled) private var isEnabled

    private static let range = ZenithLockScreenLyricOffset.range
    private static let step = ZenithLockScreenLyricOffset.step
    private static let knob: CGFloat = 18
    /// How close to the middle, in points, a drag settles on zero.
    private static let detent: CGFloat = 7

    init(value: Binding<Double>, label: String, valueText: @escaping (Double) -> String) {
        _value = value
        self.label = label
        self.valueText = valueText
    }

    var body: some View {
        GeometryReader { geometry in
            let usable = max(geometry.size.width - Self.knob, 1)
            let middle = Self.knob / 2 + usable / 2
            let x = Self.knob / 2 + CGFloat(Self.fraction(value)) * usable
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: abs(x - middle), height: 4)
                    .offset(x: min(x, middle))
                Capsule()
                    .fill(Color.primary.opacity(0.45))
                    .frame(width: 2, height: 12)
                    .offset(x: middle - 1)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                    .frame(width: Self.knob, height: Self.knob)
                    .offset(x: x - Self.knob / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                guard isEnabled else { return }
                if abs(drag.location.x - middle) <= Self.detent {
                    store(0)
                } else {
                    let fraction = Double((drag.location.x - Self.knob / 2) / usable)
                    store(Self.range.lowerBound + fraction * (Self.range.upperBound - Self.range.lowerBound))
                }
            })
        }
        .frame(height: 22)
        .opacity(isEnabled ? 1 : 0.45)
        .focusable(isEnabled)
        .onKeyPress(.leftArrow) { nudge(-1) }
        .onKeyPress(.rightArrow) { nudge(1) }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: _ = nudge(1)
            case .decrement: _ = nudge(-1)
            @unknown default: break
            }
        }
    }

    private static func fraction(_ value: Double) -> Double {
        let clamped = min(max(value.isFinite ? value : 0, range.lowerBound), range.upperBound)
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func nudge(_ steps: Double) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        store(value + steps * Self.step)
        return .handled
    }

    /// Kept to the tenth and the range; reaching zero taps the trackpad.
    private func store(_ raw: Double) {
        let clamped = min(max(raw, Self.range.lowerBound), Self.range.upperBound)
        let tenths = (clamped / Self.step).rounded()
        let next = tenths == 0 ? 0 : tenths * Self.step
        guard next != value else { return }
        if next == 0 { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        value = next
    }
}

// MARK: - Terminal

/// The terminal readout's lines and title, and how high it sits.
private struct ZenithLockScreenTerminalTab: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchLockScreenTerminal) private var terminal = false
    @AppStorage(DefaultsKey.zenithLockTerminalPlacement) private var placement =
        ZenithLockScreenTerminalPlacement.fallback.rawValue

    var body: some View {
        let text = ZenithStrings.lockScreenSettings(l10n.language)
        ZenithLockScreenCard {
            VStack(alignment: .leading, spacing: 13) {
                NotchLockScreenTerminalSettings()
                if terminal {
                    ZenithLockScreenChoiceRow(title: text.placement, symbol: "arrow.up.and.down", selection: placementChoice) {
                        Text(text.placementNormal).tag(ZenithLockScreenTerminalPlacement.normal)
                        Text(text.placementLow).tag(ZenithLockScreenTerminalPlacement.low)
                    }
                    .padding(.leading, 22)
                }
            }
        }
        .zenithSectionAnchor(.zenithLockScreenTerminal, cornerRadius: ZenithRadius.panel + 6, inset: 6)
    }

    private var placementChoice: Binding<ZenithLockScreenTerminalPlacement> {
        Binding(get: { ZenithLockScreenTerminalPlacement(rawValue: placement) ?? .fallback },
                set: { placement = $0.rawValue })
    }
}

// MARK: - Full-screen lyrics

/// The full layer opened by clicking the lyric: its parts, its top right
/// corner and its background, all greyed while it is off.
private struct ZenithLockScreenFullTab: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.zenithLockFull) private var full = true
    @AppStorage(DefaultsKey.zenithLockFullDisc) private var fullDisc = true
    @AppStorage(DefaultsKey.zenithLockFullDiscSpin) private var fullDiscSpin = false
    @AppStorage(DefaultsKey.zenithLockFullAccount) private var fullAccount = true
    @AppStorage(DefaultsKey.zenithLockFullDevice) private var fullDevice = true
    @AppStorage(DefaultsKey.zenithLockFullClock) private var fullClock = true
    @AppStorage(DefaultsKey.zenithLockFullLoginHint) private var fullLoginHint = true
    // Top right.
    @AppStorage(DefaultsKey.zenithLockJobs) private var jobs = true
    @AppStorage(DefaultsKey.zenithLockFullJobs) private var fullJobs = true
    @AppStorage(DefaultsKey.zenithLockFullTopPrayer) private var topPrayer = true
    @AppStorage(DefaultsKey.zenithLockFullTopWeather) private var topWeather = true
    @AppStorage(DefaultsKey.zenithLockFullTopTimer) private var topTimer = false
    @AppStorage(DefaultsKey.zenithLockFullTopCalendar) private var topCalendar = false
    @AppStorage(DefaultsKey.zenithLockFullTopWakaTime) private var topWakaTime = false

    var body: some View {
        let text = ZenithStrings.lockScreenSettings(l10n.language)
        let page = ZenithStrings.lockScreenPage(l10n.language)
        let language = l10n.language
        VStack(alignment: .leading, spacing: 14) {
            ZenithLockScreenCard(title: text.fullSection, caption: page.fullOpenCaption) {
                ZenithLockScreenSwitch(title: text.full, isOn: $full)
            } content: {
                ZenithLockScreenChipGrid {
                    ZenithLockScreenChip(title: text.fullDisc, symbol: "opticaldisc", isOn: $fullDisc)
                    ZenithLockScreenChip(title: page.fullDiscSpin, symbol: "arrow.clockwise.circle", isOn: $fullDiscSpin)
                        .disabled(!fullDisc)
                    ZenithLockScreenChip(title: page.fullAccount, symbol: "person.crop.circle", isOn: $fullAccount,
                                         help: text.fullAccount)
                    ZenithLockScreenChip(title: text.fullDevice, symbol: "laptopcomputer", isOn: $fullDevice)
                    ZenithLockScreenChip(title: text.fullClock, symbol: "clock", isOn: $fullClock)
                    ZenithLockScreenChip(title: text.fullLoginHint, symbol: "key", isOn: $fullLoginHint)
                }
                .disabled(!full)
            }
            ZenithLockScreenCard(title: page.topRight, caption: page.topRightCaption) {
                ZenithLockScreenChipGrid {
                    // The rings come from the job progress over the wallpaper.
                    ZenithLockScreenChip(title: text.jobs, symbol: "hourglass", isOn: $fullJobs)
                        .disabled(!jobs)
                    ZenithLockScreenChip(title: ZenithStrings.sky(language).lockPrayer, symbol: "moon.stars",
                                         isOn: $topPrayer)
                    ZenithLockScreenChip(title: ZenithStrings.lockScreenWidgets(language).weather,
                                         symbol: NotchLockScreenItem.weather.symbol, isOn: $topWeather)
                        // The same reading as the activity row's, so the same permission.
                        .onChange(of: topWeather) { _, on in if on { WeatherService.shared.requestAccess() } }
                    ZenithLockScreenChip(title: NotchModule.timer.title(language), symbol: NotchModule.timer.symbol,
                                         isOn: $topTimer)
                    ZenithLockScreenChip(title: NotchModule.calendar.title(language), symbol: NotchModule.calendar.symbol,
                                         isOn: $topCalendar)
                    if WakaTimeSupport.hasConfiguration() {
                        ZenithLockScreenChip(title: NotchModule.wakatime.title(language),
                                             symbol: NotchModule.wakatime.symbol, isOn: $topWakaTime)
                    }
                }
            }
            .disabled(!full)
            ZenithLockScreenCard(title: text.background) {
                ZenithLockScreenFullBackgroundRows()
            }
            .disabled(!full)
            Text(text.fullCaption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .zenithSectionAnchor(.zenithLockScreenLyrics, cornerRadius: ZenithRadius.panel + 6, inset: 6)
    }
}

/// The full layer's background: a solid colour, from the cover (vivid or
/// muted) or chosen here, or the cover itself blurred, with how strongly.
private struct ZenithLockScreenFullBackgroundRows: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.zenithLockFullBackground) private var storedBackground =
        ZenithLockScreenFullBackground.fallback.rawValue
    @AppStorage(DefaultsKey.zenithLockFullCoverColor) private var fullCoverColor = true
    @AppStorage(DefaultsKey.zenithLockFullTone) private var storedTone = ZenithLockScreenFullTone.fallback.rawValue
    @AppStorage(DefaultsKey.zenithLockFullBlurRadius) private var blurRadius = ZenithLockScreenFullBlur.fallback
    @AppStorage(DefaultsKey.zenithLockFullCustomColor) private var customColor =
        ZenithLockScreenCustomColor.string(ZenithLockScreenCustomColor.fallback)

    private var background: ZenithLockScreenFullBackground {
        ZenithLockScreenFullBackground(rawValue: storedBackground) ?? .fallback
    }

    var body: some View {
        let text = ZenithStrings.lockScreenSettings(l10n.language)
        let page = ZenithStrings.lockScreenPage(l10n.language)
        VStack(alignment: .leading, spacing: 13) {
            ZenithLockScreenChoiceRow(title: page.style, symbol: "photo", selection: backgroundChoice) {
                Text(text.backgroundSolid).tag(ZenithLockScreenFullBackground.solid)
                Text(text.backgroundBlurred).tag(ZenithLockScreenFullBackground.blurredCover)
            }
            if background == .blurredCover {
                HStack(spacing: 12) {
                    ZenithLockScreenRowLabel(title: text.blur, symbol: "drop")
                    Spacer(minLength: 12)
                    Text(text.blurSoft).font(ZenithType.caption).foregroundStyle(.secondary)
                    Slider(value: blurChoice, in: ZenithLockScreenFullBlur.range) { Text(text.blur) }
                        .labelsHidden()
                        .frame(minWidth: 120, maxWidth: 220)
                    Text(text.blurStrong).font(ZenithType.caption).foregroundStyle(.secondary)
                }
            } else {
                ZenithLockScreenChoiceRow(title: text.color, symbol: "paintpalette", selection: $fullCoverColor) {
                    Text(text.colorFromCover).tag(true)
                    Text(text.colorChoose).tag(false)
                }
                // The tone shapes the cover's colour only.
                ZenithLockScreenChoiceRow(title: page.tone, symbol: "circle.lefthalf.filled", selection: toneChoice) {
                    Text(page.toneVivid).tag(ZenithLockScreenFullTone.vivid)
                    Text(page.toneMuted).tag(ZenithLockScreenFullTone.muted)
                }
                .disabled(!fullCoverColor)
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
    }

    private var backgroundChoice: Binding<ZenithLockScreenFullBackground> {
        Binding(get: { background }, set: { storedBackground = $0.rawValue })
    }

    private var toneChoice: Binding<ZenithLockScreenFullTone> {
        Binding(get: { ZenithLockScreenFullTone(rawValue: storedTone) ?? .fallback },
                set: { storedTone = $0.rawValue })
    }

    /// Whole points; the slider has no ticks, so it moves smoothly.
    private var blurChoice: Binding<Double> {
        Binding(get: { min(max(blurRadius, ZenithLockScreenFullBlur.range.lowerBound), ZenithLockScreenFullBlur.range.upperBound) },
                set: { value in
                    let rounded = value.rounded()
                    if rounded != blurRadius { blurRadius = rounded }
                })
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
}

// MARK: - Pieces

/// The page's card: a hairline over the faintest lift, as `SettingsCard`,
/// with its title, caption and an optional switch inside.
private struct ZenithLockScreenCard<Accessory: View, Content: View>: View {
    let title: String?
    let caption: String?
    let accessory: Accessory
    let content: Content

    init(title: String? = nil, caption: String? = nil, @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityAddTraits(.isHeader)
                        if let caption {
                            Text(caption)
                                .font(ZenithType.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    accessory
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, title == nil ? 4 : 16)
        .zenithLockScreenCardSurface()
    }
}

extension ZenithLockScreenCard where Accessory == EmptyView {
    init(title: String? = nil, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, caption: caption, accessory: { EmptyView() }, content: content)
    }
}

private extension View {
    func zenithLockScreenCardSurface() -> some View {
        background(ZenithSurface.cardFill, in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
                .strokeBorder(ZenithSurface.hairline))
    }
}

/// The four tabs, full width, the open one on a raised pill.
private struct ZenithLockScreenTabBar: View {
    @Binding var selection: ZenithLockScreenSettingsTab
    let title: (ZenithLockScreenSettingsTab) -> String
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ZenithLockScreenSettingsTab.allCases) { tab in
                let selected = tab == selection
                Button { selection = tab } label: {
                    Text(title(tab))
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.primary.opacity(0.10))
                                    .overlay(Capsule().strokeBorder(ZenithSurface.hairline))
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(ZenithSurface.tileFill, in: Capsule())
        .overlay(Capsule().strokeBorder(ZenithSurface.hairline))
        .animation(ZenithMotion.respecting(ZenithMotion.toggle()), value: selection)
        .accessibilityElement(children: .contain)
    }
}

/// Three chips to a row.
private struct ZenithLockScreenChipGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), alignment: .leading,
                  spacing: 10, content: content)
    }
}

/// One part as a chip: on reads in the accent with a filled dot, off stays
/// quiet with an empty ring. VoiceOver reads it as a switch.
private struct ZenithLockScreenChip: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool
    /// A longer name for the tooltip, when the chip shortens it.
    var help: String? = nil
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: ZenithRadius.card - 2, style: .continuous) }

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                ZStack {
                    Circle().strokeBorder(isOn ? Color.accentColor : Color.primary.opacity(0.25), lineWidth: 1.5)
                    if isOn { Circle().fill(Color.accentColor).padding(3) }
                }
                .frame(width: 14, height: 14)
            }
            .foregroundStyle(isOn ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(isOn ? Color.accentColor.opacity(0.10) : Color.primary.opacity(hovering && isEnabled ? 0.05 : 0.025),
                        in: shape)
            .overlay(shape.strokeBorder(isOn ? Color.accentColor.opacity(0.55) : ZenithSurface.hairline, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .saturation(isEnabled ? 1 : 0)
        .onHover { hovering = $0 }
        .help(help ?? title)
        .animation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast)), value: isOn)
        .accessibilityRepresentation { Toggle(help ?? title, isOn: $isOn) }
    }
}

/// Zenith's switch alone, read by VoiceOver under its title.
private struct ZenithLockScreenSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        ZenithSwitch(isOn: $isOn)
            .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
    }
}

/// A short title and the switch it names, as one control.
private struct ZenithLockScreenTitledSwitch: View {
    let title: String
    @Binding var isOn: Bool
    /// Pushes the switch to the trailing edge.
    var expands = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(ZenithType.rowTitle)
                .fixedSize(horizontal: false, vertical: true)
            if expands { Spacer(minLength: 8) }
            ZenithSwitch(isOn: $isOn)
        }
        .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
    }
}

/// The label of a Music & Lyrics row: a glyph, a title and its caption.
private struct ZenithLockScreenLineLabel: View {
    let title: String
    let symbol: String
    var caption: String? = nil
    @Environment(\.isEnabled) private var isEnabled

    /// Where the text starts after the glyph.
    static let textInset: CGFloat = 18 + 10

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            ZenithLockScreenLineIcon(symbol: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZenithType.rowTitle)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                if let caption {
                    Text(caption)
                        .font(ZenithType.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ZenithLockScreenLineIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 18)
            .accessibilityHidden(true)
    }
}

private struct ZenithLockScreenDivider: View {
    var body: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1)
    }
}

/// A label and a few segments.
private struct ZenithLockScreenChoiceRow<Value: Hashable, Options: View>: View {
    let title: String
    let symbol: String
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    var body: some View {
        HStack(spacing: 12) {
            ZenithLockScreenRowLabel(title: title, symbol: symbol)
            Spacer(minLength: 12)
            Picker(title, selection: $selection) { options() }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
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
