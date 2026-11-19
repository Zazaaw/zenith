// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the terminal readout under the lock screen clock.
///
/// A monospaced status board on dark glass, white like the rest of the lock
/// screen. As it appears, its lines type in one after another, each whole;
/// after that the values change in place. Reduce Motion shows every line at
/// once and keeps the cursor still. It never takes clicks.
struct NotchLockScreenTerminalView: View {
    let configuration: NotchLockScreenTerminalConfiguration
    let size: CGSize
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var wakaTime = WakaTimeService.shared
    @ObservedObject private var vercel = VercelService.shared
    @ObservedObject private var gitHub = GitHubService.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var timer = NotchTimerService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    /// Lines typed in so far, until `typing` ends.
    @State private var typed = 0
    @State private var typing = true

    private typealias Layout = NotchLockScreenTerminalLayout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let lines = NotchLockScreenTerminalSupport.lines(configuration.sources, readings: readings(at: context.date),
                                                             showsProjects: configuration.showsProjects)
            ZStack(alignment: .top) {
                if !lines.isEmpty {
                    card(typing && !reduceMotion ? Array(lines.prefix(typed)) : lines)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .task { await typeIn() }
    }

    /// One line every `ZenithMotion.layerStagger` (40 ms), as many steps as
    /// lines may show. A line whose data arrives later simply appears.
    private func typeIn() async {
        guard !reduceMotion else { typing = false; return }
        let step = UInt64(ZenithMotion.layerStagger * 1_000_000_000)
        for count in 1...max(1, configuration.sources.count) {
            try? await Task.sleep(nanoseconds: step)
            guard !Task.isCancelled else { return }
            typed = count
        }
        typing = false
    }

    private func readings(at date: Date) -> NotchLockScreenTerminalReadings {
        var readings = NotchLockScreenTerminalReadings(now: date)
        for source in configuration.sources {
            switch source {
            case .agents:
                readings.agents = usage.snapshot.live
            case .waka:
                readings.wakaSeconds = wakaTime.today?.totalSeconds
                readings.wakaGoalMinutes = wakaTime.goalMinutes
                readings.wakaTopProject = wakaTime.today?.projects.max { $0.seconds < $1.seconds }?.name
            case .vercel:
                readings.deployments = vercel.deployments
            case .ci:
                readings.inbox = gitHub.inbox
            case .sys:
                let power = monitor.snapshot.power
                readings.batteryPercent = power?.hasBattery == true ? power?.chargePercent : nil
                readings.charging = power?.isCharging == true
                readings.cpu = monitor.snapshot.cpuUsage
            case .dl:
                readings.downloads = downloads.items
            case .timer:
                readings.timer = timer.session
                readings.timerNow = timer.now
            }
        }
        return readings
    }

    /// A small window: a title bar, then the lines, the last ending in the
    /// cursor. As wide as its longest line, centered in the panel.
    private func card(_ lines: [NotchLockScreenTerminalLine]) -> some View {
        // A max-width frame grows to its limit, so the glass would span the
        // whole panel: the card takes its own width first, and the panel's
        // width with truncated lines only when a line is longer than that.
        ViewThatFits(in: .horizontal) {
            glass(content(lines).frame(minWidth: Layout.minimumWidth, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false))
            glass(content(lines).frame(width: Layout.width, alignment: .leading))
        }
    }

    private func content(_ lines: [NotchLockScreenTerminalLine]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines) { line in
                    row(line, cursor: line.id == lines.last?.id).frame(height: Layout.lineHeight)
                }
            }
            .font(.system(size: Layout.fontSize, weight: .regular, design: .monospaced))
            .lineLimit(1)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
    }

    private func glass(_ content: some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
        return content
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.top, Layout.headerHeight)
            }
            .background {
                // Frosted like the music pane: the lock screen's own HUD blur, a light
                // dark wash over it so the mono text stays legible on bright wallpapers.
                if reduceTransparency {
                    shape.fill(Color(white: 0.08))
                } else {
                    ZStack {
                        NotchLockScreenMaterial(cornerRadius: ZenithRadius.card)
                        shape.fill(.black.opacity(0.35))
                    }
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(contrast == .increased ? 0.35 : 0.1), lineWidth: 1))
    }

    /// Three grey dots and the window's name, like a terminal's title bar.
    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.white.opacity(0.22)).frame(width: 7, height: 7)
                }
            }
            Text("zenith — status")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(height: Layout.headerHeight)
        .accessibilityHidden(true)
    }

    private func row(_ line: NotchLockScreenTerminalLine, cursor showsCursor: Bool) -> some View {
        HStack(spacing: 0) {
            Text(NotchLockScreenTerminalSupport.prompt + " ").foregroundStyle(.white.opacity(0.4))
            Text(NotchLockScreenTerminalSupport.paddedLabel(line.source) + "  ").foregroundStyle(.white.opacity(0.5))
            Text(line.value)
                .foregroundStyle(.white.opacity(0.92))
                .truncationMode(.tail)
            if let color = tint(line.tone) {
                Circle().fill(color).frame(width: 5, height: 5).padding(.leading, 6)
            }
            if showsCursor {
                cursor.padding(.leading, 5).accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tint(_ tone: NotchLockScreenTerminalTone) -> Color? {
        switch tone {
        case .plain: return nil
        case .warning: return ZenithStatus.warning
        case .failure: return ZenithStatus.error
        }
    }

    /// A block that blinks, solid while lines type in and under Reduce Motion.
    @ViewBuilder private var cursor: some View {
        if reduceMotion || typing {
            block(visible: true)
        } else {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                block(visible: Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0)
            }
        }
    }

    private func block(visible: Bool) -> some View {
        Rectangle()
            .fill(.white.opacity(visible ? 0.75 : 0))
            .frame(width: 7.5, height: 14)
    }
}
