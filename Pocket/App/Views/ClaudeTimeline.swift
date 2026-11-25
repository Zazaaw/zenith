// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// This turn's steps, oldest first, on a thread: the first ones blur-fade in
/// in turn, a step that arrives later rises in at once as the thread grows
/// down to it, the oldest folds away, the running one pulses and its clock
/// ticks, and edits show their lines.
struct ClaudeTimeline: View {
    let steps: [PocketClaude.Step]
    let now: Date
    /// Steps on screen from the start stagger in; later ones need no wait.
    @State private var settled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                ClaudeStepRow(step: step, last: index == steps.count - 1, now: now)
                    .blurFade(delay: settled ? 0 : Double(index) * Motion.stagger, distance: settled ? 14 : 10)
                    .transition(.asymmetric(insertion: .identity,
                                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))))
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.6))
            settled = true
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .animation(Motion.spring, value: steps)
    }
}

struct ClaudeStepRow: View {
    let step: PocketClaude.Step
    let last: Bool
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                marker
                // The thread grows down to the next step as it arrives.
                Rectangle().fill(K.border).frame(width: 1.5).frame(maxHeight: .infinity)
                    .scaleEffect(x: 1, y: last ? 0 : 1, anchor: .top)
                    .opacity(last ? 0 : 1)
                    .animation(Motion.reveal, value: last)
            }
            .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(step.tool).font(K.sans(14, bold: true)).lineLimit(1)
                    if let added = step.added, step.phase != .failed {
                        Text("+\(added)").font(K.mono(11, .semibold)).foregroundStyle(K.emerald)
                        Text("−\(step.removed ?? 0)").font(K.mono(11, .semibold)).foregroundStyle(K.red)
                    }
                    Spacer(minLength: 6)
                    time
                }
                if let target = step.target, !target.isEmpty {
                    Text(target).font(K.mono(11.5)).foregroundStyle(K.muted).lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.bottom, last ? 0 : 14)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility)
    }

    private var marker: some View {
        ZStack {
            if step.phase == .running { ClaudePulse(tint: K.purple) }
            Circle().fill(fill).frame(width: 26, height: 26)
            Image(systemName: step.phase == .failed ? "xmark" : Self.symbol(step.tool))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                // A step that finishes gives a small nod.
                .symbolEffect(.bounce, value: step.phase == .running)
        }
        .frame(width: 26, height: 26)
        .animation(Motion.quick, value: step.phase)
    }

    /// A running step's clock ticks every second; the others only age.
    @ViewBuilder private var time: some View {
        if step.phase == .running {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(PocketPresentation.claudeStepTime(step, now: context.date))
                    .font(K.mono(10.5)).foregroundStyle(K.purple).monospacedDigit()
            }
        } else {
            Text(PocketPresentation.claudeStepTime(step, now: now)).font(K.mono(10.5)).foregroundStyle(K.faint)
        }
    }

    private var fill: Color {
        switch step.phase {
        case .running: return K.purple.opacity(0.16)
        case .failed: return K.red.opacity(0.12)
        case .done: return K.fg.opacity(0.08)
        }
    }

    private var tint: Color {
        switch step.phase {
        case .running: return K.purple
        case .failed: return K.red
        case .done: return K.muted
        }
    }

    private var accessibility: String {
        let state = step.phase == .running ? "running" : step.phase == .failed ? "failed" : "done"
        return [step.tool, step.target, state].compactMap { $0 }.joined(separator: ", ")
    }

    static func symbol(_ tool: String) -> String {
        switch tool {
        case "Read": return "doc.text"
        case "Edit", "MultiEdit", "Write", "NotebookEdit": return "pencil"
        case "Bash": return "terminal"
        case "Grep", "Glob", "LS": return "magnifyingglass"
        case "WebFetch", "WebSearch": return "globe"
        case "Task", "Agent": return "sparkles"
        default: return "wrench.and.screwdriver"
        }
    }
}

/// A ring that keeps swelling out of a running step and fading.
struct ClaudePulse: View {
    let tint: Color
    @State private var out = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .strokeBorder(tint.opacity(0.6), lineWidth: 1.5)
            .frame(width: 26, height: 26)
            .scaleEffect(out ? 1.55 : 1)
            .opacity(reduceMotion ? 0 : (out ? 0 : 0.9))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { out = true }
            }
            .accessibilityHidden(true)
    }
}
