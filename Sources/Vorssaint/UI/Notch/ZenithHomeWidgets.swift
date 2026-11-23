// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the home page's widgets, each a small view of an island page
// at the card row's height (80 points, 68 at the least). The player reuses
// the home page's own card; the others are compact views made for the row:
// a reading and a control or two, and a click on the body opens the page.

struct ZenithHomeWidgetView: View {
    let widget: ZenithHomeWidget
    let service: NotchService
    let height: CGFloat
    /// Beside other widgets, or in edit mode, each sits on a soft card; the
    /// player alone keeps the band it always had.
    let framed: Bool

    var body: some View {
        switch widget {
        case .nowPlaying:
            NotchMusicControlsView(notch: service, height: height)
                .frame(height: height)
                .modifier(ZenithHomeWidgetCard(framed: framed, padded: false))
        case .timer: ZenithHomeTimerWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .clipboard: ZenithHomeClipboardWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .calendar: ZenithHomeCalendarWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .weather: ZenithHomeWeatherWidget().modifier(ZenithHomeWidgetCard(framed: true))
        case .system: ZenithHomeSystemWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .agents: ZenithHomeAgentsWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .shelf: ZenithHomeShelfWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .devServers: DevServersHomeWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .today: RecapHomeWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true)) // Zenith fork
        case .prayer: SkyHomePrayerWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .golden: SkyHomeGoldenWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true))
        case .workspaces: WorkspacesHomeWidget().modifier(ZenithHomeWidgetCard(framed: true))
        case .git: GitHomeWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true)) // Zenith fork
        case .qr: QRHomeWidget().modifier(ZenithHomeWidgetCard(framed: true)) // Zenith fork
        case .batteries: BatteriesHomeWidget(service: service).modifier(ZenithHomeWidgetCard(framed: true)) // Zenith fork
        }
    }
}

/// A widget's soft card, concentric with the island's corner.
private struct ZenithHomeWidgetCard: ViewModifier {
    let framed: Bool
    var padded = true

    func body(content: Content) -> some View {
        if framed {
            content
                .padding(.horizontal, padded ? 12 : 0)
                .padding(.vertical, padded ? 10 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zenithIslandSoftCard()
        } else {
            content
        }
    }
}

/// A widget's heading: its page's colour as a small icon, a mono label, and
/// what a click on the body does at the far end.
struct ZenithHomeWidgetHeader<Trailing: View>: View {
    let widget: ZenithHomeWidget
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 6) {
            ZenithIslandIcon(symbol: widget.symbol, hex: widget.hex, size: 16, lifted: false)
            Text(title.uppercased())
                .font(ZenithType.mono(9.5, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(ZenithIsland.label)
                .lineLimit(1)
            Spacer(minLength: 4)
            trailing()
        }
        .frame(height: 16)
    }
}

extension ZenithHomeWidgetHeader where Trailing == EmptyView {
    init(widget: ZenithHomeWidget, title: String) {
        self.init(widget: widget, title: title, trailing: { EmptyView() })
    }
}

/// The whole card opens a page: a plain button with no chrome.
struct ZenithHomeOpenButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) { label().contentShape(Rectangle()) }
            .buttonStyle(.plain)
    }
}

// MARK: - Timer

/// The timer's clock, its phase and one round control: start the chosen
/// mode, pause or resume a session, or go on to the next Pomodoro phase.
private struct ZenithHomeTimerWidget: View {
    let service: NotchService
    @ObservedObject private var timer = NotchTimerService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchTimerMode) private var mode: NotchTimerMode = .timer
    @AppStorage(DefaultsKey.notchTimerMinutes) private var savedMinutes = 15
    @AppStorage(DefaultsKey.notchPomodoroFocusMinutes) private var focusMinutes = 25
    private var text: NotchActivityStrings { FeatureStrings.notchActivities(l10n.language) }

    var body: some View {
        if timer.session.isRunning {
            TimelineView(.periodic(from: Date(timeIntervalSinceNow: NotchTimerSupport.tickScheduleOffset(
                for: timer.session, at: timer.now)), by: 1)) { _ in content }
        } else {
            content
        }
    }

    private var content: some View {
        let session = timer.session
        return HStack(spacing: 10) {
            ZenithHomeOpenButton(action: { service.select(.timer) }) {
                VStack(alignment: .leading, spacing: 4) {
                    ZenithHomeWidgetHeader(widget: .timer,
                                           title: session.hasSession ? text.phase(session.phase) : title(mode))
                    Text(session.hasSession ? NotchTimerSupport.clockText(for: session, at: timer.now) : idleClock)
                        .font(ZenithType.mono(24, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(ZenithIsland.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: !session.countsUp))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            control(session)
        }
    }

    @ViewBuilder private func control(_ session: NotchTimerSession) -> some View {
        if session.completed {
            if session.canStartNext {
                round("forward.fill", title: text.start, action: timer.startNext)
            } else {
                round("checkmark", title: l10n.s.supportIntroDoneButton, action: timer.cancel)
            }
        } else if session.hasSession {
            round(session.isPaused ? "play.fill" : "pause.fill",
                  title: session.isPaused ? text.resume : l10n.s.actionPause, action: timer.pauseOrResume)
        } else {
            round("play.fill", title: text.start) {
                timer.start(mode: mode, minutes: NotchTimerSupport.timerMinutes(savedMinutes))
            }
        }
    }

    private func round(_ symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZenithStatus.progress)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 34, height: 34)
                .background(ZenithStatus.progress.opacity(0.16), in: Circle())
                .overlay { Circle().strokeBorder(ZenithStatus.progress.opacity(0.4), lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(ZenithAppIconButtonStyle())
        .help(title)
        .accessibilityLabel(title)
    }

    private var idleClock: String {
        switch mode {
        case .timer: return NotchTimerSupport.clockText(Double(NotchTimerSupport.timerMinutes(savedMinutes)) * 60)
        case .pomodoro: return NotchTimerSupport.clockText(Double(focusMinutes) * 60)
        case .stopwatch: return NotchTimerSupport.stopwatchText(0)
        }
    }

    private func title(_ mode: NotchTimerMode) -> String {
        switch mode {
        case .timer: return text.timer
        case .pomodoro: return text.focus
        case .stopwatch: return NotchModule.timer.title(l10n.language)
        }
    }
}

// MARK: - Clipboard

/// The two latest copies as small cards; a click copies one back.
private struct ZenithHomeClipboardWidget: View {
    let service: NotchService
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var copied: UUID?

    var body: some View {
        let entries = Array(history.entries.prefix(2))
        VStack(alignment: .leading, spacing: 6) {
            ZenithHomeWidgetHeader(widget: .clipboard, title: NotchModule.clipboard.title(l10n.language)) {
                openButton
            }
            if entries.isEmpty {
                Text(FeatureStrings.clipboard(l10n.language).empty)
                    .font(.system(size: 11))
                    .foregroundStyle(ZenithIsland.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 6) {
                    ForEach(entries) { entry in card(entry) }
                    if entries.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private var openButton: some View {
        Button { service.select(.clipboard) } label: {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9, weight: .bold))
                .zenithIslandGlyph()
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(NotchModule.clipboard.title(l10n.language))
        .accessibilityLabel(NotchModule.clipboard.title(l10n.language))
    }

    private func card(_ entry: ClipboardHistoryEntry) -> some View {
        Button {
            history.copy(entry) { ok in
                guard ok else { return }
                withAnimation(ZenithMotion.respecting(.easeOut(duration: 0.18))) { copied = entry.id }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(ZenithMotion.respecting(.easeOut(duration: 0.18))) {
                        if copied == entry.id { copied = nil }
                    }
                }
            }
        } label: {
            ZStack(alignment: .topLeading) {
                if let color = entry.color {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1))
                } else {
                    Text(entry.cardPreview)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ZenithIsland.primary)
                        .lineLimit(2)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if copied == entry.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, ZenithStatus.success)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(ZenithAppIconButtonStyle())
        .help(entry.preview)
        .accessibilityLabel(entry.preview)
    }
}

// MARK: - Calendar

/// The next appointment this week: its start and title, its calendar's colour.
private struct ZenithHomeCalendarWidget: View {
    let service: NotchService
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        TimelineView(.everyMinute) { context in content(now: context.date) }
    }

    private func content(now: Date) -> some View {
        let text = FeatureStrings.notchCalendar(l10n.language)
        let event = NotchCalendarSupport.tileEvent(calendar.events, now: now)
        return ZenithHomeOpenButton(action: { service.select(.calendar) }) {
            VStack(alignment: .leading, spacing: 5) {
                ZenithHomeWidgetHeader(widget: .calendar, title: text.next)
                if let event {
                    HStack(alignment: .top, spacing: 7) {
                        Capsule().fill(event.color.color).frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NotchCalendarSupport.tileStartText(event.start, now: now,
                                                                    locale: l10n.language.formattingLocale()))
                                .font(ZenithType.mono(11, weight: .semibold))
                                .foregroundStyle(ZenithIsland.primary)
                                .lineLimit(1)
                            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            Text(title.isEmpty ? text.untitled : title)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(ZenithIsland.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxHeight: 32)
                } else {
                    Text(text.empty)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Weather

/// The sky and the temperature with today’s range, never the place's name.
/// Before location access is granted, a button asks for it; the widget never
/// asks on its own.
private struct ZenithHomeWeatherWidget: View {
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue

    var body: some View {
        let home = ZenithStrings.home(l10n.language)
        let words = ZenithStrings.lockScreenWidgets(l10n.language)
        VStack(alignment: .leading, spacing: 4) {
            ZenithHomeWidgetHeader(widget: .weather, title: words.weather)
            switch weather.access {
            case .granted:
                if let snapshot = weather.snapshot, WeatherSupport.isShowable(snapshot, now: Date()) {
                    let unit = TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
                    HStack(spacing: 8) {
                        Image(systemName: WeatherSupport.symbol(code: snapshot.code, isDay: snapshot.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(WeatherSupport.degrees(snapshot.temperature, unit: unit))
                                .font(ZenithType.mono(20, weight: .semibold))
                                .foregroundStyle(ZenithIsland.primary)
                            if let high = snapshot.high, let low = snapshot.low {
                                Text(WeatherSupport.degrees(high, unit: unit) + " / " + WeatherSupport.degrees(low, unit: unit))
                                    .font(ZenithType.mono(10))
                                    .foregroundStyle(ZenithIsland.meta)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .notDetermined:
                prompt(words.locationNeeded, action: home.allowLocation) { weather.requestAccess() }
            default:
                prompt(words.locationDenied, action: home.openSettings) { weather.openLocationSettings() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { weather.homeShown() }
        .onDisappear { weather.homeHidden() }
    }

    private func prompt(_ message: String, action title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .modifier(ZenithIslandPrimaryAction())
        }
        .buttonStyle(.plain)
        .help(message)
        .padding(.top, 4)
    }
}

// MARK: - System

/// The processor's load and the memory in use, as the System page reads them.
private struct ZenithHomeSystemWidget: View {
    let service: NotchService
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let snapshot = monitor.snapshot
        let memory: Double? = {
            guard let used = snapshot.memoryUsed, let total = snapshot.memoryTotal, total > 0 else { return nil }
            return Double(used) / Double(total)
        }()
        ZenithHomeOpenButton(action: { service.select(.system) }) {
            VStack(alignment: .leading, spacing: 6) {
                ZenithHomeWidgetHeader(widget: .system, title: NotchModule.system.title(l10n.language))
                reading("CPU", snapshot.cpuUsage)
                reading("MEM", memory, warns: snapshot.memoryPressure == .critical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func reading(_ label: String, _ value: Double?, warns: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(ZenithType.mono(9.5, weight: .medium))
                .foregroundStyle(ZenithIsland.label)
                .frame(width: 28, alignment: .leading)
            ZenithDataBar(value: value ?? 0, status: warns ? ZenithStatus.warning : nil)
                .frame(height: 3)
            Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "--")
                .font(ZenithType.mono(10.5, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Agents

/// What the AI page's closed strip reads, and how many agents are at work.
private struct ZenithHomeAgentsWidget: View {
    let service: NotchService
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let snapshot = usage.snapshot
        let reading = NotchAgentSupport.stripReading(snapshot, readout: NotchAgentSupport.readout(),
                                                     display: NotchAgentSupport.limitDisplay(),
                                                     focus: NotchAgentSupport.limitFocus(), now: Date())
        let working = Set(snapshot.live.map(\.provider)).count
        ZenithHomeOpenButton(action: { service.select(.agents) }) {
            VStack(alignment: .leading, spacing: 4) {
                ZenithHomeWidgetHeader(widget: .agents, title: NotchModule.agents.title(l10n.language)) {
                    if working > 0 { ZenithStatusDot(color: ZenithStatus.success, live: true) }
                }
                Text(reading.isEmpty ? "--" : reading)
                    .font(ZenithType.mono(20, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Shelf

/// The shelf's first items and how many there are; a click opens Files.
private struct ZenithHomeShelfWidget: View {
    let service: NotchService
    @ObservedObject private var shelf = ShelfService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let items = Array(shelf.items.prefix(3))
        ZenithHomeOpenButton(action: { service.select(.files) }) {
            VStack(alignment: .leading, spacing: 6) {
                ZenithHomeWidgetHeader(widget: .shelf, title: NotchModule.files.title(l10n.language)) {
                    if !shelf.items.isEmpty {
                        Text("\(shelf.items.count)")
                            .font(ZenithType.mono(10, weight: .semibold))
                            .foregroundStyle(ZenithIsland.meta)
                            .contentTransition(.numericText(value: Double(shelf.items.count)))
                    }
                }
                if items.isEmpty {
                    Text(FeatureStrings.notch(l10n.language).dropHint)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .zenithDropZone(cornerRadius: 10)
                } else {
                    HStack(spacing: 6) {
                        ForEach(items) { item in
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: item.hasContentThumbnail ? .fill : .fit)
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .help(item.title)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
