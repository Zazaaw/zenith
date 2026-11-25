// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import UIKit

// MARK: - Health

/// CPU, temperature (or memory) and disk as three tiles whose numbers roll;
/// CPU and temperature draw their last ten minutes as a sparkline (a meter
/// until there are two readings), disk a meter; the network under them.
struct MacHealthTiles: View {
    let health: PocketHealth?
    let reachable: Bool
    /// The readings the phone kept, oldest first.
    var history: [MacStore.HealthSample] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = true

    /// Points per sparkline: enough for a curve, few enough to glide.
    private static let points = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let health {
                    tile("CPU", value: Double(health.cpuPercent), text: "\(health.cpuPercent)%",
                         meter: Double(health.cpuPercent) / 100, tint: K.color(PocketMacPresentation.cpuTone(health.cpuPercent)),
                         spark: line({ $0.cpu }, span: 20, bounds: 0...100))
                    if let celsius = health.temperature {
                        tile("Temp", value: celsius, text: "\(Int(celsius))°", meter: celsius / 105,
                             tint: K.color(PocketMacPresentation.temperatureTone(celsius)),
                             spark: line({ $0.temperature }, span: 8, bounds: 0...110))
                    } else if let memory = health.memoryPercent {
                        tile("Memory", value: Double(memory), text: "\(memory)%", meter: Double(memory) / 100,
                             tint: memory < 85 ? K.blue : K.amber, spark: line({ $0.memory }, span: 10, bounds: 0...100))
                    }
                    if let free = health.diskFree, let total = health.diskTotal, total > 0 {
                        tile("Disk free", value: Double(free / 1_000_000_000), text: PocketMacPresentation.bytes(free),
                             meter: 1 - Double(free) / Double(total),
                             tint: K.color(PocketMacPresentation.diskTone(free: free, total: total)))
                    }
                } else {
                    ForEach(["CPU", "Temp", "Disk free"], id: \.self) { label in
                        tile(label, value: 0, text: "—", meter: 0, tint: K.faint)
                            .shimmering()
                            .opacity(reachable ? 1 : 0.5)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .onScrollVisibilityChange(threshold: 0.1) { onScreen = $0 }
            if let line = networkLine {
                Text(line).font(K.mono(11)).foregroundStyle(K.faint).padding(.horizontal, 4)
                    .contentTransition(.numericText())
                    .animation(Motion.quick, value: line)
            }
        }
    }

    private var networkLine: String? {
        guard let health else { return nil }
        var parts: [String] = []
        if let down = health.networkDown { parts.append("↓ " + PocketMacPresentation.rate(down)) }
        if let up = health.networkUp { parts.append("↑ " + PocketMacPresentation.rate(up)) }
        if health.temperature != nil, let memory = health.memoryPercent { parts.append("memory \(memory)%") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A reading's sparkline heights from the history; empty until there are two.
    private func line(_ value: (MacStore.HealthSample) -> Double?, span: Double, bounds: ClosedRange<Double>) -> [Double] {
        let samples: [(at: Date, value: Double)] = history.compactMap { sample in value(sample).map { (at: sample.at, value: $0) } }
        return PocketMacPresentation.sparkline(samples, count: Self.points, minimumSpan: span, bounds: bounds)
    }

    private func tile(_ label: String, value: Double, text: String, meter: Double, tint: Color,
                      spark: [Double] = []) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased()).font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint).lineLimit(1)
            Text(text).font(K.mono(19, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                .countingNumber(value)
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                if spark.isEmpty {
                    Meter(value: meter, tint: tint, height: 4)
                        .animation(Motion.spring, value: meter)
                        .transition(.opacity)
                } else {
                    Sparkline(heights: spark, tint: tint, pulses: onScreen && !reduceMotion)
                        .padding(.horizontal, -3)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
            .frame(height: 28, alignment: .bottom)
            .animation(Motion.reveal, value: spark.isEmpty)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .macCard(padding: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(text)")
    }
}

// MARK: - Quick tools

enum MacSheet: String, Identifiable {
    case workspaces, timer, devServers, send
    var id: String { rawValue }
}

/// Workspaces, the timer and dev servers, as three tiles that open a sheet.
struct MacQuickTiles: View {
    let tools: PocketTools?
    let open: (MacSheet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Quick")
            HStack(spacing: 10) {
                tile("square.grid.2x2", "Workspace", tools?.workspaces.first?.name ?? "none set up",
                     active: false) { open(.workspaces) }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    tile("timer", "Timer", PocketMacPresentation.timerLine(tools?.timer, now: context.date),
                         active: tools?.timer != nil) { open(.timer) }
                }
                tile("server.rack", "Dev servers", PocketMacPresentation.devServersLine(tools?.devServers ?? []),
                     active: !(tools?.devServers.isEmpty ?? true)) { open(.devServers) }
            }
        }
    }

    private func tile(_ symbol: String, _ title: String, _ meta: String, active: Bool,
                      action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(active ? K.purple : K.muted)
                    Spacer()
                    if active { Circle().fill(K.purple).frame(width: 6, height: 6) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(K.sans(13, bold: true)).foregroundStyle(K.fg).lineLimit(1)
                    Text(meta).font(K.mono(10)).foregroundStyle(K.faint).lineLimit(1).monospacedDigit()
                }
            }
            .macCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// The next event, with how soon.
struct MacNextUp: View {
    let event: PocketTools.Event
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Next up", trailing: Calendar.current.isDateInToday(event.start) ? "today" : "tomorrow")
            HStack(spacing: 10) {
                Circle().fill(K.blue).frame(width: 7, height: 7)
                Text(event.title).font(K.sans(14, bold: true)).lineLimit(1)
                Spacer(minLength: 8)
                Text(event.start.formatted(date: .omitted, time: .shortened) + " · " + PocketMacPresentation.eventLine(event, now: now))
                    .font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
            }
            .macCard()
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Busiest, downloads, clips

/// The busiest apps on the Mac, each one quittable after a confirmation.
struct MacBusiest: View {
    @Environment(PocketModel.self) private var model
    let top: [PocketHealth.Process]
    @State private var quitting: PocketHealth.Process?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Busiest", trailing: "CPU")
            Rows {
                ForEach(Array(top.enumerated()), id: \.element.pid) { index, process in
                    HStack(spacing: 12) {
                        Text(process.name).font(K.sans(14, bold: true)).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(PocketMacPresentation.share(process.cpu)).font(K.mono(12)).foregroundStyle(K.muted)
                            .monospacedDigit().contentTransition(.numericText(value: process.cpu))
                        Button {
                            Haptics.tap()
                            quitting = process
                        } label: {
                            Text("Quit").font(K.sans(12, bold: true)).foregroundStyle(K.muted)
                                .padding(.horizontal, 10).frame(height: 28)
                                .background(K.fg.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("Quit \(process.name)")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if index < top.count - 1 { Rectangle().fill(K.border).frame(height: 1).padding(.leading, 14) }
                    }
                    .transition(.opacity)
                }
            }
            .animation(Motion.spring, value: top.map(\.pid))
        }
        .confirmationDialog("Quit \(quitting?.name ?? "this app")?", isPresented: Binding(
            get: { quitting != nil }, set: { if !$0 { quitting = nil } }), titleVisibility: .visible) {
            Button("Quit", role: .destructive) {
                if let quitting { model.quitApp(pid: quitting.pid) }
                quitting = nil
            }
            Button("Cancel", role: .cancel) { quitting = nil }
        } message: {
            Text("It quits as with ⌘Q; anything unsaved asks on the Mac. Zenith may say no if quitting from the phone is off.")
        }
    }
}

struct MacDownloads: View {
    let downloads: [PocketTools.Download]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Downloading")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(downloads, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name).font(K.sans(13, bold: true)).lineLimit(1)
                            Spacer()
                            if let progress = item.progress {
                                Text("\(Int(progress * 100))%").font(K.mono(11)).foregroundStyle(K.faint)
                                    .countingNumber(progress * 100)
                            }
                        }
                        Meter(value: item.progress ?? 0, tint: K.purple, height: 4)
                            .animation(Motion.spring, value: item.progress)
                            .opacity(item.progress == nil ? 0.4 : 1)
                    }
                }
            }
            .macCard()
        }
    }
}

/// The Mac's latest copied text; a tap puts one on this iPhone's clipboard.
struct MacClips: View {
    @Environment(PocketModel.self) private var model
    let clips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Copied on Mac", trailing: "tap to copy here")
            Rows {
                ForEach(Array(clips.prefix(5).enumerated()), id: \.offset) { index, clip in
                    Button {
                        UIPasteboard.general.string = clip
                        Haptics.success()
                        model.show("Copied to this iPhone.", ok: true)
                    } label: {
                        Text(clip).font(K.mono(12)).foregroundStyle(K.fg).lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    if index < min(clips.count, 5) - 1 { Rectangle().fill(K.border).frame(height: 1).padding(.leading, 14) }
                }
            }
        }
    }
}

// MARK: - Sheets

/// The chrome every Mac sheet shares: the background, a title and Done.
struct MacSheetFrame<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let eyebrow: String
    let sentence: PocketSentence
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            K.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }.font(K.sans(15, bold: true)).foregroundStyle(K.fg)
                    }
                    .padding(.horizontal, 24).padding(.top, 18)
                    Hero(eyebrow: eyebrow, badge: nil, sentence: sentence)
                    VStack(alignment: .leading, spacing: 14) { content }
                        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 40)
                        .blurFade(delay: 0.08)
                }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(K.fg)
        .presentationDetents([.medium, .large])
        .presentationBackground(K.bg)
    }
}

struct WorkspacesSheet: View {
    @Environment(PocketModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let workspaces = model.state?.tools?.workspaces ?? []
        MacSheetFrame(eyebrow: "Workspaces",
                      sentence: workspaces.isEmpty
                        ? PocketSentence(lead: "No workspaces ", value: "yet", after: ".", rest: "Make one in Zenith's Settings.", tone: .quiet)
                        : PocketSentence(lead: "Open a ", value: "workspace", after: "", rest: "on your Mac.", tone: .info)) {
            if !workspaces.isEmpty {
                Rows {
                    ForEach(Array(workspaces.enumerated()), id: \.element.id) { index, workspace in
                        Button {
                            Haptics.press()
                            model.openWorkspace(workspace.id)
                            dismiss()
                        } label: {
                            Row(symbol: workspace.symbol ?? "square.grid.2x2", title: workspace.name, meta: "opens its apps and windows",
                                divider: index < workspaces.count - 1) {
                                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .bold)).foregroundStyle(K.faint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .blurFade(index: index)
                    }
                }
            }
        }
    }
}

struct TimerSheet: View {
    @Environment(PocketModel.self) private var model
    private static let presets = [5, 15, 25, 45, 60, 90]

    var body: some View {
        let timer = model.state?.tools?.timer
        TimelineView(.periodic(from: .now, by: 1)) { context in
            MacSheetFrame(eyebrow: "Island timer", sentence: sentence(timer, now: context.date)) {
                if let timer, timer.endsAt != nil || timer.paused {
                    HStack(spacing: 8) {
                        PillButton(title: timer.paused ? "Resume" : "Pause", primary: true) {
                            Haptics.press()
                            model.pauseTimer(!timer.paused)
                        }
                        PillButton(title: "Stop") {
                            Haptics.warning()
                            model.stopTimer()
                        }
                    }
                } else if timer != nil {
                    PillButton(title: "Clear") { model.stopTimer() }
                }
                SectionLabel(text: timer == nil ? "Start" : "Start over").padding(.top, 6)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Array(Self.presets.enumerated()), id: \.element) { index, minutes in
                        Button {
                            Haptics.press()
                            model.startTimer(minutes: minutes)
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(minutes)").font(K.mono(22, .semibold))
                                Text("min").font(K.mono(10)).foregroundStyle(K.faint)
                            }
                            .frame(maxWidth: .infinity)
                            .macCard(padding: 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .blurFade(index: index)
                    }
                }
            }
        }
    }

    private func sentence(_ timer: PocketTools.Timer?, now: Date) -> PocketSentence {
        guard let timer else {
            return PocketSentence(lead: "No timer ", value: "running", after: ".", rest: "Pick a length to start one.", tone: .quiet)
        }
        let line = PocketMacPresentation.timerLine(timer, now: now)
        if timer.paused { return PocketSentence(lead: timer.label + " is ", value: "paused", after: ",", rest: line + ".", tone: .attention) }
        if timer.endsAt != nil { return PocketSentence(lead: timer.label + " ", value: line, after: "", rest: "left.", tone: .progress) }
        return PocketSentence(lead: "", value: timer.label, after: ".", rest: "", tone: .good)
    }
}

struct DevServersSheet: View {
    @Environment(PocketModel.self) private var model
    @State private var confirming: Int?

    var body: some View {
        let servers = model.state?.tools?.devServers ?? []
        MacSheetFrame(eyebrow: "Dev servers",
                      sentence: servers.isEmpty
                        ? PocketSentence(lead: "No dev servers ", value: "running", after: ".", rest: "", tone: .quiet)
                        : PocketSentence(lead: "", value: "\(servers.count) running", after: "", rest: "on your Mac.", tone: .good)) {
            if !servers.isEmpty {
                Rows {
                    ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                        Row(symbol: "server.rack", title: server.project ?? server.process,
                            meta: ":\(server.port) · \(server.process)", divider: index < servers.count - 1) {
                            Button {
                                if confirming == server.port {
                                    Haptics.warning()
                                    model.stopDevServer(port: server.port)
                                    confirming = nil
                                } else {
                                    Haptics.tap()
                                    withAnimation(Motion.quick) { confirming = server.port }
                                }
                            } label: {
                                Text(confirming == server.port ? "Stop?" : "Stop").font(K.sans(12, bold: true))
                                    .foregroundStyle(confirming == server.port ? K.red : K.muted)
                                    .padding(.horizontal, 12).frame(height: 30)
                                    .background((confirming == server.port ? K.red.opacity(0.12) : K.fg.opacity(0.07)), in: Capsule())
                            }
                            .buttonStyle(PressStyle())
                        }
                        .blurFade(index: index)
                    }
                }
                Text("Stop asks once more, then ends the server as the island's Kill does.")
                    .font(K.sans(13)).foregroundStyle(K.faint).padding(.horizontal, 4)
            }
        }
        .task(id: confirming) {
            guard confirming != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(Motion.quick) { confirming = nil }
        }
    }
}
