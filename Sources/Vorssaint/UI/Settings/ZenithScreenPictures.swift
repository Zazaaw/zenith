// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the pictures of the screen previews (ZenithScreenPreviews),
// one per scene, from the pieces in ZenithScreenPictureParts. Sample data
// only; the ones about movement loop with ZenithPreviewLoop, which stands
// still while Settings is hidden or Reduce Motion is on.

private typealias M = ZenithScreenPictureMetrics

/// The picture of one scene.
struct ZenithScreenPicture: View {
    let scene: ZenithScreenScene

    var body: some View {
        switch scene {
        case .look: ZenithLookPicture()
        case .panel: ZenithPanelPicture()
        case .hider: ZenithHiderPicture()
        case .mixer: ZenithMixerPicture()
        case .output: ZenithOutputPicture()
        case .priority: ZenithPriorityPicture()
        case .musicBlock: ZenithMusicBlockPicture()
        case .hub: ZenithHubPicture()
        case .keepAwake: ZenithKeepAwakePicture()
        case .brightness: ZenithBrightnessPicture()
        case .extraBrightness: ZenithExtraBrightnessPicture()
        case .bluetoothSleep: ZenithBluetoothSleepPicture()
        case .monitorMenuBar: ZenithMonitorMenuBarPicture()
        case .monitorPanel: ZenithMonitorPanelPicture(fans: false)
        case .fans: ZenithMonitorPanelPicture(fans: true)
        case .switcherWindows: ZenithSwitcherPicture(layout: .windows)
        case .switcherIcons: ZenithSwitcherPicture(layout: .icons)
        case .switcherSimple: ZenithSwitcherPicture(layout: .simple)
        case .dockPreview: ZenithDockPreviewPicture()
        case .dockClick: ZenithDockClickPicture()
        case .spacesOrder: ZenithSpacesPicture()
        case .snap: ZenithSnapPicture()
        case .maximize: ZenithMaximizePicture()
        case .screenshot: ZenithCapturePicture(kind: .screenshot)
        case .scrolling: ZenithScrollingPicture()
        case .recording: ZenithCapturePicture(kind: .recording)
        case .screenText: ZenithCapturePicture(kind: .text)
        case .color: ZenithColorPicture()
        case .mediaVideo, .mediaGIF, .mediaImage, .mediaText: ZenithMediaPicture(scene: scene)
        case .updatesPanel: ZenithUpdatesPanelPicture()
        case .updatesNotice: ZenithUpdatesNoticePicture()
        }
    }
}

private var text: ZenithPreviewsScreenStrings { .shared }

/// A section's title as the panel names it.
private func panelTitle(_ section: PanelSectionID) -> String { section.title(L10n.shared.s) }

private func featureTitle(_ feature: AppFeature) -> String {
    feature.hubTitle(L10n.shared.s, hub: FeatureStrings.hub(L10n.shared.language))
}

// MARK: - General

/// Zenith's windows and panel in the look picked on the page.
private struct ZenithLookPicture: View {
    var body: some View {
        ZenithScreenDesktop { size in
            ZenithScreenWindow(title: AppInfo.name, tint: .accentColor)
                .frame(width: 330, height: 220)
                .position(x: 215, y: 190)
            ZenithKeepAwakePanel()
                .zenithPreviewPart(cornerRadius: 18, highlighted: true) { ZenithScreenScene.look.open() }
                .pinnedTop(x: 585, top: 38)
        }
    }
}

/// The panel open under Zenith's item, its tabs outlined.
private struct ZenithPanelPicture: View {
    var body: some View {
        ZenithScreenDesktop { _ in
            ZenithKeepAwakePanel(tabsPart: { ZenithScreenScene.panel.open() })
                .pinnedTop(x: 530, top: 38)
        }
    }
}

/// The panel on its Keep Awake section, as it first opens.
private struct ZenithKeepAwakePanel: View {
    var tabsPart: (() -> Void)?

    var body: some View {
        ZenithScreenPanel(selected: .keepAwake, title: panelTitle(.keepAwake), tabsPart: tabsPart) {
            HStack {
                Text(verbatim: L10n.shared.s.keepAwakeTitle).font(.system(size: 12.5, weight: .medium))
                Spacer()
                Capsule().fill(Color.primary.opacity(0.15)).frame(width: 34, height: 20)
                    .overlay(alignment: .leading) { Circle().fill(.white).frame(width: 16).padding(2) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(["15m", "30m", "1h", "2h", "4h", "8h", "∞", "…"], id: \.self) { label in
                    Text(verbatim: label).font(.system(size: 11.5, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 24)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                }
            }
        }
    }
}

/// Status items left of the divider tucking away and coming back.
private struct ZenithHiderPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.3) { phase in
            let open = M.pulse(phase, 0.1, 0.25, 0.6, 0.75)
            ZenithScreenDesktop(extra: { items(open, size: 13) }) { size in
                ZenithScreenMenuBarLens {
                    items(open, size: 15)
                    ZenithScreenZenithItem(size: 15)
                    Image(systemName: "battery.75percent")
                    Image(systemName: "wifi")
                }
                .zenithPreviewPart(cornerRadius: 12, highlighted: true) { ZenithScreenScene.hider.open() }
                .scaleEffect(1.5)
                .position(x: size.width / 2, y: size.height * 0.55)
            }
        }
    }

    @ViewBuilder private func items(_ open: CGFloat, size: CGFloat) -> some View {
        HStack(spacing: size) {
            ForEach(["music.note", "cloud", "paintpalette", "timer"], id: \.self) { symbol in
                Image(systemName: symbol).font(.system(size: size))
            }
        }
        .fixedSize()
        .frame(width: open * size * 8.6, alignment: .trailing)
        .clipped()
        .opacity(Double(open))
        Image(systemName: open > 0.5 ? "chevron.right" : "chevron.left")
            .font(.system(size: size * 0.8, weight: .bold))
            .opacity(0.8)
    }
}

// MARK: - Sound

private struct ZenithMixerPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.5) { phase in
            let music = 0.35 + 0.45 * M.pulse(phase, 0.1, 0.4, 0.6, 0.9)
            ZenithScreenDesktop { _ in
                ZenithScreenPanel(selected: .mixer, title: panelTitle(.mixer)) {
                    VStack(alignment: .leading, spacing: 12) {
                        row(.music, value: music)
                        row(.safari, value: 0.45)
                        row(.zoom, value: 1)
                    }
                    .zenithPreviewPart(cornerRadius: 10, highlighted: true) { ZenithScreenScene.mixer.open() }
                }
                .pinnedTop(x: 530, top: 38)
            }
        }
    }

    private func row(_ app: ZenithScreenApp, value: CGFloat) -> some View {
        ZenithScreenPanelRow(app: app, title: app.name) {
            ZenithScreenLevel(value: value, width: 100)
            Text(verbatim: "\(Int(value * 100))%").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

/// The outputs in a row, the sound moving along them with each press.
private struct ZenithOutputPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4.5, stillPhase: 0.4) { phase in
            let current = Int(phase * 3) % 3
            let pressed = (phase * 3).truncatingRemainder(dividingBy: 1) < 0.15
            ZenithScreenDesktop { size in
                HStack(spacing: 14) {
                    device("laptopcomputer", text.speakers, on: current == 0)
                    arrow
                    device("airpodspro", text.airPods, on: current == 1)
                    arrow
                    device("display", text.studioDisplay, on: current == 2)
                }
                .zenithPreviewPart(cornerRadius: 18, highlighted: true) { ZenithScreenScene.output.open() }
                .position(x: size.width / 2, y: size.height * 0.42)
                HStack(spacing: 8) {
                    ZenithScreenKey(label: "⌥", down: pressed)
                    ZenithScreenKey(label: "⌘", down: pressed)
                    ZenithScreenKey(label: "O", down: pressed)
                }
                .position(x: size.width / 2, y: size.height * 0.8)
            }
        }
    }

    private var arrow: some View {
        Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).foregroundStyle(.white.opacity(0.7))
    }

    private func device(_ symbol: String, _ name: String, on: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 30, weight: .regular))
                .frame(height: 38)
            Text(verbatim: name).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
            Image(systemName: on ? "speaker.wave.2.fill" : "speaker.fill")
                .font(.system(size: 12)).opacity(on ? 1 : 0.35)
        }
        .foregroundStyle(.white)
        .frame(width: 140, height: 112)
        .background(on ? Color.accentColor.opacity(0.85) : Color(white: 0.12).opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

/// Devices in the order picked; the first one connected is in use.
private struct ZenithPriorityPicture: View {
    var body: some View {
        ZenithScreenDesktop { size in
            VStack(spacing: 0) {
                row(1, "airpodspro", text.airPods, inUse: true)
                Divider().overlay(.white.opacity(0.1))
                row(2, "display", text.studioDisplay, inUse: false)
                Divider().overlay(.white.opacity(0.1))
                row(3, "laptopcomputer", text.speakers, inUse: false)
            }
            .frame(width: 380)
            .background(Color(white: 0.12).opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
            .zenithPreviewPart(cornerRadius: 16, highlighted: true) { ZenithScreenScene.priority.open() }
            .position(x: size.width / 2, y: size.height * 0.55)
        }
    }

    private func row(_ rank: Int, _ symbol: String, _ name: String, inUse: Bool) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(rank)").font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.12), in: Circle())
            Image(systemName: symbol).font(.system(size: 17)).frame(width: 26)
            Text(verbatim: name).font(.system(size: 13.5, weight: .medium))
            Spacer()
            if inUse {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 12)).foregroundStyle(Color.accentColor)
            }
            Image(systemName: "line.3.horizontal").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 48)
    }
}

/// The play key pressed with nothing playing, and Music staying shut.
private struct ZenithMusicBlockPicture: View {
    var body: some View {
        ZenithScreenDesktop { size in
            ZenithScreenKey(label: "", symbol: "playpause.fill", down: true)
                .scaleEffect(1.3)
                .position(x: size.width / 2 - 150, y: size.height * 0.42)
            ZenithScreenNotice(symbol: "nosign", tint: Color(red: 1, green: 0.4, blue: 0.4), title: text.musicBlocked)
                .position(x: size.width / 2 + 60, y: size.height * 0.42)
            let apps = ZenithScreenApp.dock
            ZenithScreenDockBar(apps: apps, part: (3, { ZenithScreenScene.musicBlock.open() }))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "nosign").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white, Color(red: 0.95, green: 0.25, blue: 0.25))
                        .background(Circle().fill(Color(red: 0.95, green: 0.25, blue: 0.25)).padding(1))
                        .offset(x: ZenithScreenDockBar.iconCenter(3) + 8, y: -2)
                }
                .position(x: size.width / 2, y: size.height - 36)
        }
    }
}

// MARK: - Features

/// The parts features add, appearing one after the other.
private struct ZenithHubPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 6, stillPhase: 0.95) { phase in
            let shown = [M.step(phase, 0.05, 0.15), M.step(phase, 0.2, 0.3), M.step(phase, 0.35, 0.45),
                         M.step(phase, 0.5, 0.6)].map { $0 * (1 - M.step(phase, 0.92, 1)) }
            ZenithScreenDesktop(extra: {
                part(shown[0], label: text.monitorLabel, page: .monitor, labelOffset: CGSize(width: 30, height: 30)) {
                    readings
                }
            }) { size in
                part(shown[1], label: text.islandLabel, page: .notch, labelOffset: CGSize(width: -60, height: 30)) {
                    ZenithScreenIsland(width: 130) {
                        Image(systemName: "music.note").foregroundStyle(.pink)
                    } trailing: {
                        Image(systemName: "waveform").foregroundStyle(.pink)
                    }
                }
                .position(x: size.width / 2, y: 16)
                part(shown[2], label: text.switcherLabel, page: .switcher) {
                    ZenithMiniSwitcher(selected: 1)
                }
                .position(x: size.width * 0.7, y: size.height * 0.4)
                let dockWidth = ZenithScreenDockBar.width(count: ZenithScreenApp.dock.count)
                part(shown[3], label: text.dockLabel, page: .dock) {
                    ZenithDockPreviewPopup()
                }
                .position(x: size.width / 2 - dockWidth / 2 + ZenithScreenDockBar.iconCenter(1) + 30, y: size.height - 150)
                ZenithScreenDockBar()
                    .position(x: size.width / 2, y: size.height - 36)
            }
        }
    }

    private var readings: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu")
            Text(verbatim: "12%")
        }
        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
    }

    private func part<Content: View>(_ shown: CGFloat, label: String, page: SettingsPage,
                                     labelOffset: CGSize = CGSize(width: 0, height: 26),
                                     @ViewBuilder content: () -> Content) -> some View {
        content()
            .overlay(alignment: .bottom) {
                Label(label, systemImage: "plus.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.accentColor, in: Capsule())
                    .fixedSize()
                    .offset(labelOffset)
            }
            .zenithPreviewPart(cornerRadius: 12, highlighted: true) {
                SettingsRouter.shared.request(FeatureSettingsDestination(page))
            }
            .opacity(Double(shown))
            .scaleEffect(0.9 + 0.1 * shown)
    }
}

// MARK: - Energy

private struct ZenithKeepAwakePicture: View {
    var body: some View {
        ZenithScreenDesktop(zenithActive: true) { size in
            ZenithScreenIsland(width: 210, height: 32) {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(.orange).font(.system(size: 14))
            } trailing: {
                Text(verbatim: text.awakeTime).font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
            .zenithPreviewPart(cornerRadius: 14, highlighted: true) { ZenithScreenScene.keepAwake.open() }
            .position(x: size.width / 2, y: 16)
            ZenithScreenNotice(symbol: "sun.max.fill", tint: .yellow, title: text.keepAwakeToast,
                               detail: text.keepAwakeToastDetail)
                .position(x: size.width / 2, y: size.height * 0.5)
        }
    }
}

/// The brightness keys dimming and brightening a display, with its level.
private struct ZenithBrightnessPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.4) { phase in
            let level = 0.3 + 0.6 * M.pulse(phase, 0.05, 0.4, 0.55, 0.9)
            let rising = phase < 0.5
            ZenithScreenDesktop { size in
                Color.black.opacity(0.55 * Double(1 - level)).allowsHitTesting(false)
                HStack(spacing: 8) {
                    ZenithScreenKey(label: "", symbol: "sun.min", down: !rising && phase < 0.9)
                    ZenithScreenKey(label: "", symbol: "sun.max", down: rising && phase > 0.05)
                }
                .position(x: size.width / 2, y: size.height * 0.36)
                VStack(spacing: 10) {
                    Image(systemName: "sun.max.fill").font(.system(size: 30))
                    Text(verbatim: text.studioDisplay).font(.system(size: 11.5, weight: .medium))
                    segments(level)
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(Color(white: 0.12).opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .zenithPreviewPart(cornerRadius: 18, highlighted: true) { ZenithScreenScene.brightness.open() }
                .position(x: size.width / 2, y: size.height * 0.72)
            }
        }
    }

    private func segments(_ level: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<16, id: \.self) { index in
                Rectangle().fill(.white.opacity(CGFloat(index) < level * 16 ? 0.95 : 0.2)).frame(width: 7, height: 6)
            }
        }
    }
}

/// An XDR display's brightness going past the usual maximum.
private struct ZenithExtraBrightnessPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.5) { phase in
            let extra = M.pulse(phase, 0.1, 0.45, 0.65, 0.95)
            ZenithScreenDesktop { size in
                Color.white.opacity(0.22 * Double(extra)).blendMode(.plusLighter).allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sun.max.fill").foregroundStyle(.yellow)
                        Text(verbatim: L10n.shared.s.extraBrightnessName).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(verbatim: "\(100 + Int(60 * extra))%").font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15)).frame(width: 300, height: 8)
                        Capsule().fill(LinearGradient(colors: [.white, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 188 + 112 * extra, height: 8)
                        Rectangle().fill(.white.opacity(0.7)).frame(width: 2, height: 16).offset(x: 187)
                    }
                    HStack {
                        Text(verbatim: "100%").offset(x: 170)
                        Spacer()
                        Text(verbatim: text.percent160)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .frame(width: 300)
                .padding(18)
                .background(Color(white: 0.12).opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
                .zenithPreviewPart(cornerRadius: 18, highlighted: true) { ZenithScreenScene.extraBrightness.open() }
                .position(x: size.width / 2, y: size.height * 0.56)
            }
        }
    }
}

/// The Mac asleep with Bluetooth off, then awake with it back on.
private struct ZenithBluetoothSleepPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 5, stillPhase: 0.25) { phase in
            let asleep = phase < 0.5
            let dark = M.pulse(phase, 0.02, 0.12, 0.48, 0.58)
            let symbol = AppFeature.bluetoothSleep.symbolName
            ZenithScreenDesktop(extra: {
                Image(systemName: symbol).font(.system(size: 13)).opacity(asleep ? 0.35 : 1)
            }) { size in
                Color.black.opacity(0.75 * Double(dark)).allowsHitTesting(false)
                Group {
                    if asleep {
                        ZenithScreenNotice(symbol: "moon.zzz.fill", tint: .indigo, title: text.asleep, detail: text.bluetoothOff)
                    } else {
                        ZenithScreenNotice(symbol: "airpodspro", title: text.bluetoothOn, detail: text.airPods)
                    }
                }
                .zenithPreviewPart(cornerRadius: 16, highlighted: true) { ZenithScreenScene.bluetoothSleep.open() }
                .position(x: size.width / 2, y: size.height * 0.52)
            }
        }
    }
}

// MARK: - Monitor

/// The menu bar's readings, live, drawn larger in the middle.
private struct ZenithMonitorMenuBarPicture: View {
    var body: some View {
        ZenithScreenDesktop { size in
            MenuBarMetricsPreview()
                .frame(width: 380)
                .zenithPreviewPart(cornerRadius: 10, highlighted: true) { ZenithScreenScene.monitorMenuBar.open() }
                .scaleEffect(1.35)
                .position(x: size.width / 2, y: size.height * 0.5)
        }
    }
}

/// The panel's System section, or its fans.
private struct ZenithMonitorPanelPicture: View {
    let fans: Bool

    var body: some View {
        ZenithScreenDesktop { _ in
            ZenithScreenPanel(selected: fans ? .fanControl : .system,
                              title: panelTitle(fans ? .fanControl : .system)) {
                Group {
                    if fans { fanRows } else { systemRows }
                }
                .zenithPreviewPart(cornerRadius: 10, highlighted: true) {
                    (fans ? ZenithScreenScene.fans : .monitorPanel).open()
                }
            }
            .pinnedTop(x: 530, top: 38)
        }
    }

    private var systemRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            graphRow(text.cpu, value: "12%", points: [0.2, 0.3, 0.25, 0.5, 0.35, 0.3, 0.6, 0.4, 0.3, 0.25, 0.35, 0.2], tint: .blue)
            graphRow(text.memory, value: "9.4 GB", points: [0.55, 0.56, 0.58, 0.57, 0.6, 0.62, 0.61, 0.6, 0.63, 0.62, 0.64, 0.63],
                     tint: .green)
        }
    }

    private func graphRow(_ title: String, value: String, points: [CGFloat], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(verbatim: title).font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text(verbatim: value).font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            ZenithScreenSparkline(points: points, tint: tint).frame(height: 30)
        }
    }

    private var fanRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZenithScreenPanelRow(symbol: "fanblades.fill", title: text.fan, detail: text.rpm) {
                Text(verbatim: text.auto).font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())
            }
            ZenithScreenLevel(value: 0.42, width: 236)
        }
    }
}

/// A small graph of recent readings.
struct ZenithScreenSparkline: View {
    let points: [CGFloat]
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let step = geo.size.width / CGFloat(max(points.count - 1, 1))
            let line = Path { path in
                for (index, value) in points.enumerated() {
                    let point = CGPoint(x: CGFloat(index) * step, y: geo.size.height * (1 - value))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            ZStack {
                line.stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                Path { path in
                    path.addPath(line)
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                }
                .fill(tint.opacity(0.18))
            }
        }
    }
}

// MARK: - Switcher

private enum ZenithSwitcherLayout { case windows, icons, simple }

/// The switcher over a desktop, stepping through its windows.
private struct ZenithSwitcherPicture: View {
    let layout: ZenithSwitcherLayout
    private let apps: [ZenithScreenApp] = [.safari, .mail, .figma, .notes]

    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.3) { phase in
            let selected = Int(phase * 4) % 4
            ZenithScreenDesktop { size in
                ZenithScreenWindow(title: apps[1].name, tint: apps[1].color)
                    .frame(width: 300, height: 200).position(x: 200, y: 170)
                ZenithScreenWindow(title: apps[0].name, tint: apps[0].color)
                    .frame(width: 320, height: 210).position(x: 540, y: 200)
                switcher(selected)
                    .zenithPreviewPart(cornerRadius: 20, highlighted: true) {
                        ZenithScreenScene.switcherWindows.open()
                    }
                    .position(x: size.width / 2, y: size.height * 0.55)
            }
        }
    }

    @ViewBuilder private func switcher(_ selected: Int) -> some View {
        switch layout {
        case .windows:
            HStack(spacing: 14) {
                ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                    VStack(spacing: 7) {
                        ZenithScreenThumbnail(tint: app.color)
                            .frame(width: 112, height: 76)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(index == selected ? Color.accentColor : .clear, lineWidth: 2.5))
                        HStack(spacing: 5) {
                            ZenithScreenAppIcon(app: app, size: 16)
                            Text(verbatim: app.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        }
                    }
                }
            }
            .switcherSurface()
        case .icons:
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                    VStack(spacing: 8) {
                        ZenithScreenThumbnail(tint: app.color)
                            .frame(width: 70, height: 48)
                            .opacity(index == selected ? 1 : 0)
                        ZenithScreenAppIcon(app: app, size: 52)
                            .padding(5)
                            .background(index == selected ? Color.white.opacity(0.18) : .clear,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .switcherSurface()
        case .simple:
            VStack(spacing: 12) {
                Text(verbatim: apps[selected].name).font(.system(size: 14, weight: .semibold))
                HStack(spacing: 12) {
                    ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                        ZenithScreenAppIcon(app: app, size: 46)
                            .padding(5)
                            .background(index == selected ? Color.white.opacity(0.18) : .clear,
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }
            .switcherSurface()
        }
    }
}

private extension View {
    func switcherSurface() -> some View {
        foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .padding(16)
            .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
    }
}

/// A small switcher, for the Features picture.
private struct ZenithMiniSwitcher: View {
    var selected: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array([ZenithScreenApp.safari, .mail, .figma].enumerated()), id: \.offset) { index, app in
                ZenithScreenAppIcon(app: app, size: 34)
                    .padding(4)
                    .background(index == selected ? Color.white.opacity(0.2) : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Dock

/// Two window previews over a Dock icon.
private struct ZenithDockPreviewPopup: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach([Color.blue, .teal], id: \.self) { tint in
                VStack(spacing: 5) {
                    ZenithScreenThumbnail(tint: tint)
                        .frame(width: 104, height: 70)
                    Text(verbatim: ZenithScreenApp.safari.name).font(.system(size: 10.5, weight: .medium))
                }
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .padding(10)
        .background(Color(white: 0.13).opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    }
}

private struct ZenithDockPreviewPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.6) { phase in
            let shown = M.pulse(phase, 0.2, 0.35, 0.85, 0.95)
            ZenithScreenDesktop { size in
                let dockWidth = ZenithScreenDockBar.width(count: ZenithScreenApp.dock.count)
                let iconX = size.width / 2 - dockWidth / 2 + ZenithScreenDockBar.iconCenter(1)
                ZenithDockPreviewPopup()
                    .zenithPreviewPart(cornerRadius: 16, highlighted: true) { ZenithScreenScene.dockPreview.open() }
                    .opacity(Double(shown))
                    .scaleEffect(0.92 + 0.08 * shown, anchor: .bottom)
                    .position(x: iconX + 30, y: size.height - 130)
                ZenithScreenDockBar()
                    .position(x: size.width / 2, y: size.height - 36)
                ZenithScreenPointer()
                    .position(x: iconX + 6, y: size.height - 34)
            }
        }
    }
}

/// A click on the app in front sends its window into the Dock.
private struct ZenithDockClickPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.36) { phase in
            let away = M.pulse(phase, 0.25, 0.55, 0.8, 0.95)
            ZenithScreenDesktop { size in
                let dockWidth = ZenithScreenDockBar.width(count: ZenithScreenApp.dock.count)
                let icon = CGPoint(x: size.width / 2 - dockWidth / 2 + ZenithScreenDockBar.iconCenter(1), y: size.height - 38)
                let home = CGPoint(x: size.width / 2, y: size.height * 0.45)
                ZenithScreenWindow(title: ZenithScreenApp.safari.name, tint: ZenithScreenApp.safari.color)
                    .frame(width: 360, height: 200)
                    .scaleEffect(1 - 0.9 * away)
                    .opacity(Double(1 - 0.8 * away))
                    .position(x: home.x + (icon.x - home.x) * away, y: home.y + (icon.y - home.y) * away)
                ZenithScreenDockBar(part: (1, { ZenithScreenScene.dockClick.open() }),
                                    lifted: phase > 0.15 && phase < 0.25 ? 1 : nil)
                    .position(x: size.width / 2, y: size.height - 36)
                ZenithScreenPointer()
                    .position(x: icon.x + 6, y: icon.y + 4)
            }
        }
    }
}

/// Mission Control's row of Spaces, in the order you set.
private struct ZenithSpacesPicture: View {
    var body: some View {
        ZenithScreenDesktop(menuBar: false) { size in
            Color.black.opacity(0.35).allowsHitTesting(false)
            HStack(spacing: 16) {
                ForEach(1...3, id: \.self) { index in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.white.opacity(index == 2 ? 0.35 : 0.2))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.white.opacity(index == 2 ? 0.9 : 0.3), lineWidth: index == 2 ? 2 : 1))
                            .frame(width: 120, height: 72)
                        Text(verbatim: "\(text.desktop) \(index)").font(.system(size: 11.5, weight: .medium))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .zenithPreviewPart(cornerRadius: 16, highlighted: true) { ZenithScreenScene.spacesOrder.open() }
            .position(x: size.width / 2, y: 80)
            Label(text.spacesKept, systemImage: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.accentColor, in: Capsule())
                .fixedSize()
                .position(x: size.width / 2, y: 160)
            HStack(spacing: 30) {
                ZenithScreenWindow(title: ZenithScreenApp.safari.name, tint: .blue).frame(width: 220, height: 140)
                ZenithScreenWindow(title: ZenithScreenApp.notes.name, tint: .yellow).frame(width: 200, height: 130)
            }
            .position(x: size.width / 2, y: size.height * 0.74)
        }
    }
}

// MARK: - Window layout

/// A window dragged to the left edge, the half it will fill, then filling it.
private struct ZenithSnapPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4.5, stillPhase: 0.55) { phase in
            let drag = M.step(phase, 0.05, 0.4)
            let zone = M.pulse(phase, 0.4, 0.5, 0.62, 0.7)
            let snap = M.pulse(phase, 0.62, 0.72, 0.9, 1)
            ZenithScreenDesktop { size in
                let top = ZenithPreviewDesktop<EmptyView>.menuBarHeight + 6
                let half = CGRect(x: 6, y: top, width: size.width / 2 - 9, height: size.height - top - 6)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                    .frame(width: half.width, height: half.height)
                    .zenithPreviewPart(cornerRadius: 14, highlighted: true) { ZenithScreenScene.snap.open() }
                    .opacity(Double(max(zone, snap > 0 ? 0 : zone)))
                    .position(x: half.midX, y: half.midY)
                let free = CGRect(x: size.width / 2 - 170 - 180 * drag, y: 80 + 20 * drag, width: 340, height: 220)
                let rect = interpolate(free, half, snap)
                ZenithScreenWindow(title: ZenithScreenApp.notes.name, tint: ZenithScreenApp.notes.color)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                ZenithScreenPointer()
                    .opacity(Double(1 - snap))
                    .position(x: free.minX + 150, y: free.minY + 14)
            }
        }
    }

    private func interpolate(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }
}

/// The green button filling the screen with the window.
private struct ZenithMaximizePicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.2) { phase in
            let grow = M.pulse(phase, 0.3, 0.5, 0.8, 0.95)
            ZenithScreenDesktop { size in
                let top = ZenithPreviewDesktop<EmptyView>.menuBarHeight + 4
                let small = CGRect(x: size.width / 2 - 190, y: 90, width: 380, height: 220)
                let full = CGRect(x: 4, y: top, width: size.width - 8, height: size.height - top - 4)
                let rect = CGRect(x: small.minX + (full.minX - small.minX) * grow,
                                  y: small.minY + (full.minY - small.minY) * grow,
                                  width: small.width + (full.width - small.width) * grow,
                                  height: small.height + (full.height - small.height) * grow)
                ZenithScreenWindow(title: ZenithScreenApp.safari.name, tint: ZenithScreenApp.safari.color,
                                   greenPart: { ZenithScreenScene.maximize.open() })
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                ZenithScreenPointer()
                    .opacity(Double(1 - grow))
                    .position(x: small.minX + 52, y: small.minY + 19)
            }
        }
    }
}

// MARK: - Screen capture

private enum ZenithCaptureKind { case screenshot, recording, text }

/// A selection over a window: a screenshot, a recording, or text to copy.
private struct ZenithCapturePicture: View {
    let kind: ZenithCaptureKind

    var body: some View {
        ZenithPreviewLoop(period: kind == .recording ? 3 : 4.5, stillPhase: kind == .screenshot ? 0.45 : 0.7) { phase in
            ZenithScreenDesktop(extra: { recordingItem(phase) }) { size in
                ZenithScreenWindow(title: ZenithScreenApp.notes.name, tint: ZenithScreenApp.notes.color)
                    .frame(width: 420, height: 250)
                    .position(x: size.width / 2, y: size.height * 0.57)
                selection(phase, in: size)
            }
        }
    }

    @ViewBuilder private func recordingItem(_ phase: Double) -> some View {
        if kind == .recording {
            HStack(spacing: 5) {
                Image(systemName: "record.circle.fill").foregroundStyle(.red)
                Text(verbatim: text.recordingTime).font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .opacity(phase.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.6)
        }
    }

    @ViewBuilder private func selection(_ phase: Double, in size: CGSize) -> some View {
        let grow = kind == .screenshot ? M.step(phase, 0.05, 0.4) : 1
        // Text is one line picked out of the window's content.
        let rect = kind == .text
            ? CGRect(x: size.width / 2 - 112, y: size.height * 0.57 - 92, width: 310, height: 50)
            : CGRect(x: size.width / 2 - 170, y: size.height * 0.57 - 80, width: 120 + 220 * grow, height: 60 + 110 * grow)
        // The screen dims outside the selection.
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(rect)
        }
        .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
        Rectangle()
            .strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: kind == .recording ? [6, 4] : []))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
        switch kind {
        case .screenshot:
            let thumb = M.step(phase, 0.55, 0.75)
            Text(verbatim: text.selectionSize)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                .position(x: rect.maxX - 40, y: rect.maxY + 14)
            Color.clear
                .frame(width: rect.width, height: rect.height)
                .zenithPreviewPart(cornerRadius: 4, highlighted: true) { ZenithScreenScene.screenshot.open() }
                .position(x: rect.midX, y: rect.midY)
            ZenithScreenThumbnail(tint: ZenithScreenApp.notes.color)
                .frame(width: 130, height: 74)
                .opacity(Double(thumb))
                .offset(x: 30 * (1 - thumb))
                .position(x: size.width - 90, y: size.height - 56)
        case .recording:
            HStack(spacing: 12) {
                Image(systemName: "stop.fill").foregroundStyle(.red)
                Text(verbatim: text.recordingTime).font(.system(size: 13, weight: .semibold, design: .monospaced))
                Image(systemName: "mic.fill")
                Image(systemName: "pause.fill")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).frame(height: 34)
            .background(Color(white: 0.12).opacity(0.92), in: Capsule())
            .zenithPreviewPart(cornerRadius: 18, highlighted: true) { ZenithScreenScene.recording.open() }
            .position(x: rect.midX, y: rect.maxY + 30)
        case .text:
            ZenithScreenNotice(symbol: "text.viewfinder", tint: .accentColor, title: text.copied, detail: text.copiedText)
                .zenithPreviewPart(cornerRadius: 16, highlighted: true) { ZenithScreenScene.screenText.open() }
                .position(x: rect.midX, y: rect.maxY + 56)
        }
    }
}

/// A window's content scrolled under a selection, stitched into one image.
private struct ZenithScrollingPicture: View {
    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.7) { phase in
            let grow = M.step(phase, 0.05, 0.85)
            ZenithScreenDesktop { size in
                ZenithScreenWindow(title: ZenithScreenApp.safari.name, tint: ZenithScreenApp.safari.color)
                    .frame(width: 340, height: 250)
                    .overlay(Rectangle().strokeBorder(.white, lineWidth: 1.5).padding(.top, 26))
                    .position(x: 250, y: size.height * 0.57)
                Image(systemName: "arrow.down").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .shadow(radius: 3)
                    .position(x: 440, y: size.height * 0.57)
                VStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        ZenithScreenThumbnail(tint: [Color.blue, .teal, .indigo, .cyan][index])
                            .frame(width: 120, height: 66)
                            .opacity(CGFloat(index) <= grow * 4 ? 1 : 0.15)
                    }
                }
                .padding(6)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .zenithPreviewPart(cornerRadius: 12, highlighted: true) { ZenithScreenScene.scrolling.open() }
                .position(x: 580, y: size.height * 0.58)
            }
        }
    }
}

/// The loupe over the screen with the color it would copy.
private struct ZenithColorPicture: View {
    private let colors: [Color] = [.orange, .yellow, .pink, .orange, .red, .orange, .yellow, .orange, .brown]

    var body: some View {
        ZenithScreenDesktop { size in
            ZenithScreenWindow(title: ZenithScreenApp.figma.name, tint: .orange)
                .frame(width: 420, height: 250)
                .position(x: size.width / 2 - 60, y: size.height * 0.57)
            VStack(spacing: 8) {
                VStack(spacing: 1) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<9, id: \.self) { column in
                                Rectangle()
                                    .fill(colors[(row * 3 + column * 5) % colors.count].opacity(0.75 + Double((row + column) % 3) * 0.1))
                                    .frame(width: 11, height: 11)
                                    .overlay(row == 4 && column == 4 ? Rectangle().strokeBorder(.white, lineWidth: 2) : nil)
                            }
                        }
                    }
                }
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                Text(verbatim: text.colorHex).font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.black.opacity(0.75), in: Capsule())
            }
            .zenithPreviewPart(cornerRadius: 60, highlighted: true) { ZenithScreenScene.color.open() }
            .position(x: size.width / 2 + 170, y: size.height * 0.5)
        }
    }
}

// MARK: - Media

/// The panel's Media tool with a file dropped on it.
private struct ZenithMediaPicture: View {
    let scene: ZenithScreenScene

    var body: some View {
        ZenithPreviewLoop(period: 4, stillPhase: 0.9) { phase in
            let progress = M.step(phase, 0.1, 0.7)
            ZenithScreenDesktop { _ in
                ZenithScreenPanel(selected: .utilities, title: featureTitle(.mediaTools)) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 4) {
                            ForEach([ZenithScreenScene.mediaVideo, .mediaGIF, .mediaImage, .mediaText], id: \.self) { tool in
                                Text(verbatim: tool.text.state)
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity).frame(height: 22)
                                    .background(tool == scene ? Color.accentColor.opacity(0.2) : .clear,
                                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .foregroundStyle(tool == scene ? Color.accentColor : .primary)
                            }
                        }
                        ZenithScreenPanelRow(symbol: symbol, title: file, detail: progress < 1 ? nil : result) {
                            Image(systemName: progress < 1 ? "hourglass" : "checkmark.circle.fill")
                                .foregroundStyle(progress < 1 ? Color.secondary : .green)
                        }
                        ZenithScreenLevel(value: progress, width: 236)
                    }
                    .zenithPreviewPart(cornerRadius: 10, highlighted: true) { scene.open() }
                }
                .pinnedTop(x: 530, top: 38)
            }
        }
    }

    private var symbol: String {
        switch scene {
        case .mediaGIF: return "photo.stack"
        case .mediaImage: return "photo"
        case .mediaText: return "doc.text.viewfinder"
        default: return "film"
        }
    }

    private var file: String {
        switch scene {
        case .mediaGIF: return text.gifFile
        case .mediaImage: return text.imageFile
        case .mediaText: return text.pdfFile
        default: return text.videoFile
        }
    }

    private var result: String {
        switch scene {
        case .mediaGIF: return text.gifMade
        case .mediaImage: return text.imageShrunk
        case .mediaText: return text.textFound
        default: return text.compressed
        }
    }
}

// MARK: - App updates

private struct ZenithUpdatesPanelPicture: View {
    var body: some View {
        ZenithScreenDesktop { _ in
            ZenithScreenPanel(selected: .utilities, title: featureTitle(.appUpdates)) {
                VStack(alignment: .leading, spacing: 11) {
                    row(.figma, text.figmaVersion)
                    row(.arc, text.arcVersion)
                    row(.raycast, text.raycastVersion)
                    Text(verbatim: text.updateAll).font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 26)
                        .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .foregroundStyle(Color.accentColor)
                }
                .zenithPreviewPart(cornerRadius: 10, highlighted: true) { ZenithScreenScene.updatesPanel.open() }
            }
            .pinnedTop(x: 530, top: 38)
        }
    }

    private func row(_ app: ZenithScreenApp, _ version: String) -> some View {
        ZenithScreenPanelRow(app: app, title: app.name, detail: version) {
            Text(verbatim: text.update).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
    }
}

/// The notification a scheduled check posts.
private struct ZenithUpdatesNoticePicture: View {
    var body: some View {
        ZenithScreenDesktop { size in
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(white: 0.1))
                    .overlay(ZenithScreenZenithItem(size: 18).foregroundStyle(.white))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(verbatim: AppInfo.name).font(.system(size: 12.5, weight: .semibold))
                        Spacer()
                        Text(verbatim: text.now).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Text(verbatim: text.updatesNoticeTitle).font(.system(size: 12.5, weight: .semibold))
                    Text(verbatim: text.updatesNoticeBody).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(width: 330)
            .background(ZenithScreenSurface.panel(.dark).opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
            .zenithPreviewPart(cornerRadius: 18, highlighted: true) { ZenithScreenScene.updatesNotice.open() }
            .position(x: size.width - 185, y: 90)
        }
    }
}
