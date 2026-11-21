// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ImageIO
import SwiftUI

/// Zenith fork: which layer the Settings preview draws.
enum ZenithLockScreenPreviewMode: String, CaseIterable, Identifiable {
    case minimal, full
    var id: String { rawValue }
}

/// The parts of the lock screen the preview can highlight, and that a click on
/// the preview selects, so Settings can open the matching tab.
enum ZenithLockScreenPreviewPart: String, CaseIterable, Identifiable {
    case activityRow, nowPlaying, terminal, full
    var id: String { rawValue }
}

/// Zenith fork: where each part of the lock screen is drawn, for the preview's
/// highlight and its clicks. The lock screen itself ignores it.
struct ZenithLockScreenPartBounds: PreferenceKey {
    static var defaultValue: [ZenithLockScreenPreviewPart: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [ZenithLockScreenPreviewPart: Anchor<CGRect>],
                       nextValue: () -> [ZenithLockScreenPreviewPart: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Zenith fork: a live, scaled preview of the lock screen for Settings, drawn
/// over this Mac's own wallpaper with the real minimal and full layers, sample
/// content and the current switches. Toggling a switch shows at once.
/// `highlight` outlines a part; clicking a part calls `onSelect` with it.
struct ZenithLockScreenPreview: View {
    let mode: ZenithLockScreenPreviewMode
    var highlight: ZenithLockScreenPreviewPart? = nil
    var onSelect: (ZenithLockScreenPreviewPart) -> Void = { _ in }
    @StateObject private var settings = ZenithLockScreenPreviewSettings()
    @ObservedObject private var assets = ZenithLockScreenPreviewAssets.shared
    @ObservedObject private var l10n = L10n.shared
    /// The sample song starts over from here, so its lyrics keep moving.
    @State private var cycleStart = Date()

    private var canvas: CGSize { ZenithLockScreenPreviewAssets.screenSize }

    var body: some View {
        let canvas = canvas
        GeometryReader { proxy in
            let scale = max(0.01, proxy.size.width / canvas.width)
            screen(canvas: canvas, scale: scale)
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.lockScreenV2(l10n.language).preview)
        .onAppear { assets.load() }
        .task {
            // One pass of the sample lines, then again from the top.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(ZenithLockScreenPreviewSample.cycle * 1_000_000_000))
                guard !Task.isCancelled else { return }
                cycleStart = Date()
            }
        }
    }

    // MARK: The screen

    /// The lock screen at the main display's own size, in its points.
    private func screen(canvas: CGSize, scale: CGFloat) -> some View {
        let gates = settings.gates
        let playback = ZenithLockScreenPreviewSample.playback(from: cycleStart)
        return ZStack(alignment: .topLeading) {
            wallpaper(canvas)
            if mode == .full, gates.full {
                full(gates: gates, playback: playback, canvas: canvas)
            } else {
                ZenithLockScreenPreviewChrome(canvas: canvas, account: assets.account)
                minimal(gates: gates, playback: playback, canvas: canvas)
            }
            ZenithLockScreenPreviewIsland(canvas: canvas, notch: assets.notch)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .overlayPreferenceValue(ZenithLockScreenPartBounds.self) { bounds in
            GeometryReader { proxy in
                parts(bounds, proxy: proxy, canvas: canvas, scale: scale)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func wallpaper(_ canvas: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.34), Color(white: 0.16)], startPoint: .top, endPoint: .bottom)
            if let image = assets.wallpaper {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: canvas.width, height: canvas.height)
                    .clipped()
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }

    /// The activity row, the minimal layer and the terminal readout, where the
    /// lock screen puts them on this display.
    @ViewBuilder private func minimal(gates: ZenithLockScreenV2Gates, playback: NotchPlayback,
                                      canvas: CGSize) -> some View {
        let screen = CGRect(origin: .zero, size: canvas)
        if let row = NotchLockScreenLayout.rowFrame(in: screen) {
            let terminal = settings.terminal
            let arranged = NotchLockScreenTerminalLayout.arrange(
                row: row, player: NotchLockScreenLayout.playerFrame(in: screen), screen: screen,
                lines: terminal?.lines.count ?? 0, music: gates.nowPlaying,
                lift: ZenithLockScreenMinimalLayout.terminalLift(terminal?.placement ?? .fallback))
            ZenithLockScreenPreviewRow(gates: gates, size: row.size)
                .frame(width: row.width, height: row.height)
                .anchorPreference(key: ZenithLockScreenPartBounds.self, value: .bounds) { [.activityRow: $0] }
                .offset(x: row.minX, y: canvas.height - row.maxY)
            if gates.nowPlaying, let player = arranged.player {
                let panel = ZenithLockScreenMinimalLayout.frame(row: row, player: player)
                ZenithLockScreenMinimalLayer(
                    gates: gates, playback: playback, lyrics: ZenithLockScreenPreviewSample.lyrics,
                    offset: gates.lyricOffset, size: panel.size,
                    titleTop: ZenithLockScreenMinimalLayout.titleTop(row: row, panel: panel), interactive: false)
                    .frame(width: panel.width, height: panel.height)
                    .offset(x: panel.minX, y: canvas.height - panel.maxY)
            }
            if let terminal, let frame = arranged.terminal {
                let card = ZenithLockScreenMinimalLayout.terminalCard(
                    in: frame, cardHeight: NotchLockScreenTerminalLayout.height(lines: terminal.lines.count),
                    placement: terminal.placement)
                NotchLockScreenTerminalView(configuration: terminal.configuration, size: frame.size,
                                            anchorsBottom: ZenithLockScreenMinimalLayout.terminalAnchorsBottom(terminal.placement),
                                            sampleLines: terminal.lines)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: canvas.height - frame.maxY)
                Color.clear
                    .frame(width: card.width, height: card.height)
                    .anchorPreference(key: ZenithLockScreenPartBounds.self, value: .bounds) { [.terminal: $0] }
                    .offset(x: card.minX, y: canvas.height - card.maxY)
                    .allowsHitTesting(false)
            }
        }
    }

    private func full(gates: ZenithLockScreenV2Gates, playback: NotchPlayback, canvas: CGSize) -> some View {
        let look = settings.look(for: gates, canvas: canvas)
        let language = l10n.language
        return ZenithLockScreenFullLayer(
            gates: gates, scheme: look.scheme, backdrop: look.backdrop, edgeRing: look.edgeRing,
            account: assets.account, playback: playback, artwork: ZenithLockScreenPreviewSample.cover,
            lyrics: ZenithLockScreenPreviewSample.lyrics, offset: gates.lyricOffset, size: canvas, live: true, preview: true,
            top: { date in ZenithLockScreenPreviewSample.topEntries(at: date, language: language) })
            .frame(width: canvas.width, height: canvas.height)
            .anchorPreference(key: ZenithLockScreenPartBounds.self, value: .bounds) { [.full: $0] }
    }

    // MARK: Parts

    /// A click target over each part, and the dashed outline around the
    /// highlighted one.
    private func parts(_ bounds: [ZenithLockScreenPreviewPart: Anchor<CGRect>], proxy: GeometryProxy,
                       canvas: CGSize, scale: CGFloat) -> some View {
        let unit = 1 / scale
        return ZStack(alignment: .topLeading) {
            ForEach(ZenithLockScreenPreviewPart.allCases.filter { bounds[$0] != nil }) { part in
                if let anchor = bounds[part] {
                    let rect = proxy[anchor].insetBy(dx: part == .full ? 6 * unit : -8 * unit,
                                                     dy: part == .full ? 6 * unit : -6 * unit)
                    let shape = RoundedRectangle(cornerRadius: (part == .full ? 9 : 8) * unit, style: .continuous)
                    shape
                        .fill(Color.white.opacity(0.001))
                        .overlay {
                            if highlight == part {
                                shape.strokeBorder(Color.accentColor,
                                                   style: StrokeStyle(lineWidth: 1.5 * unit, dash: [5 * unit, 3.5 * unit]))
                            }
                        }
                        .frame(width: max(0, rect.width), height: max(0, rect.height))
                        .contentShape(shape)
                        .onTapGesture { onSelect(part) }
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }
}

/// Zenith fork: the switches the preview follows, read again whenever a
/// preference changes, so the preview follows Settings as it is used.
final class ZenithLockScreenPreviewSettings: ObservableObject {
    struct Terminal: Equatable {
        let configuration: NotchLockScreenTerminalConfiguration
        let placement: ZenithLockScreenTerminalPlacement
        let lines: [NotchLockScreenTerminalLine]
    }

    struct Look {
        let scheme: ZenithLockScreenPalette.Scheme
        let backdrop: ZenithLockScreenBackdropImage?
        let edgeRing: Bool
    }

    private struct LookKey: Equatable {
        let background: ZenithLockScreenFullBackground
        let coverColor: Bool
        let custom: UInt32
        let tone: ZenithLockScreenFullTone
        let blur: Double
        let canvas: CGSize
    }

    @Published private(set) var gates = ZenithLockScreenV2Gates()
    @Published private(set) var terminal: Terminal?
    private var observer: NSObjectProtocol?
    private var lookCache: (key: LookKey, look: Look)?

    init() {
        read()
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in self?.read() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// The lock screen's own music switch decides whether a song shows; the
    /// lyrics show as if the island's lyrics were on, so every part of the
    /// design can be seen.
    private func read() {
        let gates = ZenithLockScreenV2Gates.resolve(music: NotchLockScreenItem.music.isOn(), lyricsAvailable: true)
        if self.gates != gates { self.gates = gates }
        let terminal: Terminal? = NotchLockScreenTerminalSupport.isEnabled() ? {
            let selection = NotchLockScreenTerminalSupport.selection().shown
            guard !selection.isEmpty else { return nil }
            let configuration = NotchLockScreenTerminalConfiguration(
                sources: selection, showsProjects: NotchLockScreenTerminalSupport.showsProjects(),
                title: NotchLockScreenTerminalSupport.title())
            return Terminal(configuration: configuration, placement: ZenithLockScreenTerminalPlacement.current(),
                            lines: selection.map(ZenithLockScreenPreviewSample.terminalLine))
        }() : nil
        if self.terminal != terminal { self.terminal = terminal }
    }

    /// The full layer's colours from the sample cover, worked out once per
    /// choice of background.
    func look(for gates: ZenithLockScreenV2Gates, canvas: CGSize) -> Look {
        let key = LookKey(background: gates.fullBackground, coverColor: gates.fullCoverColor, custom: gates.fullCustomColor,
                          tone: gates.fullTone, blur: gates.fullBlurRadius, canvas: canvas)
        if let lookCache, lookCache.key == key { return lookCache.look }
        let look: Look
        if let cover = ZenithLockScreenPreviewSample.coverImage {
            let rendered = ZenithLockScreenV2.render(cover, gates: gates, screen: canvas)
            look = Look(scheme: rendered.scheme,
                        backdrop: rendered.backdrop.map {
                            ZenithLockScreenBackdropImage(id: 1, image: NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)))
                        },
                        edgeRing: rendered.edgeRing)
        } else {
            look = Look(scheme: ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: nil), backdrop: nil,
                        edgeRing: false)
        }
        lookCache = (key, look)
        return look
    }
}

/// Zenith fork: what the preview reads from this Mac once: the main display's
/// wallpaper (downscaled), its notch, and the account's name, picture and
/// computer name. Nothing leaves the Mac.
final class ZenithLockScreenPreviewAssets: ObservableObject {
    static let shared = ZenithLockScreenPreviewAssets()
    @Published private(set) var wallpaper: NSImage?
    @Published private(set) var account = ZenithLockScreenAccount(name: NSFullUserName(), device: "", photo: nil)
    private var wallpaperURL: URL?
    private var accountLoaded = false

    /// The display the lock screen draws its clock and login on.
    private static var mainScreen: NSScreen? { NSScreen.screens.first }

    static var screenSize: CGSize {
        let size = mainScreen?.frame.size ?? ZenithLockScreenFullLayout.reference
        return size.width > 0 && size.height > 0 ? size : ZenithLockScreenFullLayout.reference
    }

    /// The camera housing's width and height, on a display with one.
    var notch: CGSize? {
        guard let screen = Self.mainScreen, screen.safeAreaInsets.top > 0 else { return nil }
        let sides = (screen.auxiliaryTopLeftArea?.width ?? 0) + (screen.auxiliaryTopRightArea?.width ?? 0)
        let width = screen.frame.width - sides
        return width > 0 && sides > 0 ? CGSize(width: width, height: screen.safeAreaInsets.top) : nil
    }

    /// Reads the wallpaper again only when it changed; a picture that cannot
    /// be read (a dynamic wallpaper's folder, say) leaves the neutral gradient.
    func load() {
        if let screen = Self.mainScreen, let url = NSWorkspace.shared.desktopImageURL(for: screen), url != wallpaperURL {
            wallpaperURL = url
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let image = Self.thumbnail(of: url, maxPixel: 1600)
                DispatchQueue.main.async {
                    guard let self, self.wallpaperURL == url else { return }
                    self.wallpaper = image.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
                }
            }
        }
        guard !accountLoaded else { return }
        accountLoaded = true
        let name = NSFullUserName()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let photo = ZenithLockScreenAccount.photoData()
            let device = ZenithLockScreenAccount.deviceName()
            DispatchQueue.main.async {
                self?.account = ZenithLockScreenAccount(name: name, device: device, photo: photo.flatMap(NSImage.init(data:)))
            }
        }
    }

    private static func thumbnail(of url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: maxPixel]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// Zenith fork: the macOS parts of the lock screen the preview stands in for:
/// the date and clock, and the account with its password field.
struct ZenithLockScreenPreviewChrome: View {
    let canvas: CGSize
    let account: ZenithLockScreenAccount

    var body: some View {
        let clockBottom = NotchLockScreenLayout.clockBottom(screenHeight: canvas.height)
        ZStack(alignment: .top) {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 0) {
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: (clockBottom * 0.105).rounded(), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(context.date, format: Date.FormatStyle(date: .omitted, time: .shortened))
                        .font(.system(size: (clockBottom * 0.48).rounded(), weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.88))
                }
                .lineLimit(1)
                .fixedSize()
            }
            .frame(width: canvas.width, height: clockBottom, alignment: .bottom)
            login
                .frame(width: canvas.width)
                .offset(y: canvas.height - 210)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .top)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var login: some View {
        VStack(spacing: 8) {
            Group {
                if let photo = account.photo {
                    Image(nsImage: photo).resizable().interpolation(.high).scaledToFill()
                } else {
                    Circle().fill(.white.opacity(0.25)).overlay {
                        Text(account.initials).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(Circle())
            Text(account.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 168, height: 28)
                .overlay(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.55)).frame(width: 1.5, height: 15).padding(.leading, 12)
                }
        }
    }
}

/// Zenith fork: the locked island at the camera, on a display with one.
struct ZenithLockScreenPreviewIsland: View {
    let canvas: CGSize
    let notch: CGSize?

    var body: some View {
        if let notch {
            let wing = (notch.height * 1.1).rounded()
            UnevenRoundedRectangle(bottomLeadingRadius: notch.height * 0.32, bottomTrailingRadius: notch.height * 0.32,
                                   style: .continuous)
                .fill(.black)
                .frame(width: notch.width + wing * 2, height: notch.height)
                .overlay(alignment: .leading) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: notch.height * 0.36, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: wing)
                }
                .frame(width: canvas.width, alignment: .center)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Zenith fork: the activity row in the preview, with a sample weather
/// reading and sample jobs beside it when their switch is on.
struct ZenithLockScreenPreviewRow: View {
    let gates: ZenithLockScreenV2Gates
    let size: CGSize
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue

    var body: some View {
        let unit = TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
        HStack(spacing: 7) {
            Image(systemName: "cloud.sun.fill")
            Text(WeatherSupport.degrees(31, unit: unit))
            Text(WeatherSupport.degrees(31, unit: unit) + " / " + WeatherSupport.degrees(25, unit: unit))
                .foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 15, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(1)
        .fixedSize()
        .zenithLegibleOnWallpaper()
        .modifier(ZenithLockScreenJobsBeside(enabled: gates.jobs, sample: Array(ZenithLockScreenJobLine.sampleJobs.prefix(2))))
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// Zenith fork: the preview's sample song, its lines and the readings around it.
enum ZenithLockScreenPreviewSample {
    static let title = "Lose You Now"
    static let artist = "Nadia Rae"
    static let lines = [
        "Every time I close my eyes",
        "I don't wanna lose you now",
        "so I keep holding on to you",
        "never letting go",
        "even when the night is long",
        "I hear you calling out my name",
        "and nothing ever feels the same",
        "I don't wanna lose you now",
    ]
    /// Where the sample starts in the song, and how long each line lasts:
    /// slow enough for the karaoke to be seen.
    static let start = 58.0
    static let lineLength = 4.2
    static var cycle: Double { Double(lines.count) * lineLength }

    static let lyrics = NotchLyrics(
        lines: lines.enumerated().map { NotchLyricLine(time: start + 0.4 + Double($0.offset) * lineLength, text: $0.element) },
        plain: lines.joined(separator: "\n"), instrumental: false)

    static func playback(from date: Date) -> NotchPlayback {
        NotchPlayback(track: RadialNowPlayingSnapshot(title: title, artist: artist, album: nil, artworkData: nil,
                                                      appBundleIdentifier: nil, appPID: nil),
                      isPlaying: true, elapsed: start, duration: 204, rate: 1, sampledAt: date, canSeek: false)
    }

    /// A made-up cover: a deep red sleeve with a pale sun, so the vivid and
    /// muted tones and the record's edge ring all show.
    static let coverImage: CGImage? = {
        let side = 300
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let full = CGRect(x: 0, y: 0, width: side, height: side)
        context.setFillColor(CGColor(srgbRed: 0.84, green: 0.05, blue: 0.16, alpha: 1))
        context.fill(full)
        context.setFillColor(CGColor(srgbRed: 0.62, green: 0.02, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side / 3))
        context.setFillColor(CGColor(srgbRed: 0.97, green: 0.9, blue: 0.86, alpha: 1))
        context.fillEllipse(in: CGRect(x: 95, y: 110, width: 110, height: 110))
        context.setFillColor(CGColor(srgbRed: 0.98, green: 0.72, blue: 0.62, alpha: 0.9))
        for index in 0..<4 {
            context.fill(CGRect(x: 60 + index * 12, y: 70 - index * 12, width: 180 - index * 24, height: 4))
        }
        return context.makeImage()
    }()

    static let cover: NSImage? = coverImage.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }

    /// The full layer's top right with sample readings.
    static func topEntries(at date: Date, language: AppLanguage) -> [ZenithLockScreenTopItem: ZenithLockScreenTopEntry] {
        let unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.temperatureUnit) ?? "") ?? .celsius
        let calendar = Calendar.current
        let asr = calendar.date(bySettingHour: 15, minute: 4, second: 0, of: date) ?? date
        let indonesian = PrayerTimesSupport.usesIndonesian(SkySettings.current().names)
        return [
            .jobs: ZenithLockScreenTopEntry(item: .jobs, jobs: Array(ZenithLockScreenJobLine.sampleJobs.prefix(1))),
            .prayer: ZenithLockScreenTopEntry(item: .prayer, symbol: Prayer.asr.symbol,
                                              primary: ZenithStrings.sky(language).name(.asr, indonesian: indonesian),
                                              secondary: PrayerTimesSupport.clock(asr, locale: language.formattingLocale())),
            .weather: ZenithLockScreenTopEntry(item: .weather, symbol: "cloud.sun.fill",
                                               primary: WeatherSupport.degrees(31, unit: unit),
                                               secondary: WeatherSupport.degrees(31, unit: unit) + " / "
                                                   + WeatherSupport.degrees(25, unit: unit)),
            .timer: ZenithLockScreenTopEntry(item: .timer, symbol: "timer", primary: "18:42"),
            .calendar: ZenithLockScreenTopEntry(item: .calendar, symbol: "calendar", primary: "Design review",
                                                secondary: NotchCalendarSupport.countdownText(
                                                    until: date.addingTimeInterval(25 * 60), now: date)),
            .wakatime: ZenithLockScreenTopEntry(item: .wakatime, symbol: NotchModule.wakatime.symbol,
                                                primary: WakaTimeSupport.duration(5700, locale: Locale(identifier: language.rawValue))),
        ]
    }

    /// The readout's sample line for each source.
    static func terminalLine(_ source: NotchLockScreenTerminalSource) -> NotchLockScreenTerminalLine {
        let value: String
        switch source {
        case .agents: value = "2 running · claude, codex"
        case .waka: value = "1h 35m"
        case .vercel: value = "ready · 1d ago"
        case .ci: value = "3 checks passing"
        case .sys: value = "bat 61% · cpu 6%"
        case .dl: value = "1 file · 42%"
        case .timer: value = "focus 18:42"
        case .prayer: value = "ashar 15:04 · in 1h 32m"
        case .golden: value = "17:21–18:04"
        }
        return NotchLockScreenTerminalLine(source: source, value: value)
    }
}
