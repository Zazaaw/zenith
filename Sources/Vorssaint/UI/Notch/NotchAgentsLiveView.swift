// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// MARK: State and layout

/// Zenith fork: the AI page's three tabs. Progress follows a Claude Code
/// session step by step (its hooks), Usage shows each agent's allowance as a
/// ring, and Stats keeps upstream's cards as they were.
enum NotchAgentsTab: String, CaseIterable, Identifiable {
    case progress, usage, stats
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .progress: return "checklist"
        case .usage: return "gauge.with.dots.needle.33percent"
        case .stats: return "chart.bar.xaxis"
        }
    }

    func title(_ text: ZenithClaudeHooksStrings) -> String {
        switch self {
        case .progress: return text.progress
        case .usage: return text.usage
        case .stats: return text.stats
        }
    }
}

/// What the page remembers while the app runs: the tab, which the island's
/// height follows, and the session picked by hand.
final class NotchAgentsPageState: ObservableObject {
    static let shared = NotchAgentsPageState()
    @Published var tab: NotchAgentsTab = .progress
    @Published var chosenSession: String?
}

/// The page's measures, shared with the island's geometry so the page's
/// height is known before it draws.
enum NotchAgentsPageLayout {
    static let headerHeight: CGFloat = 24
    static let gap: CGFloat = 10
    /// Six checklist rows; the rings and their words fit too.
    static let bodyHeight: CGFloat = 112
    static let rowHeight: CGFloat = 16
    static let rowSpacing: CGFloat = 3
    /// The card's corner follows the island's (28) inset by the page's padding.
    // Zenith fork: the open island's corner (40) less its padding (ZenithIslandInset).
    static var cardRadius: CGFloat { ZenithIsland.cardRadius }
    static let ringSize: CGFloat = 58

    /// Progress and Usage keep one height, whatever they show; Stats is as
    /// tall as its cards, so nil.
    static func fixedHeight(tab: NotchAgentsTab = NotchAgentsPageState.shared.tab) -> CGFloat? {
        tab == .stats ? nil : headerHeight + gap + bodyHeight
    }

    /// The cards' height with the page's header above them; no cards, none.
    static func statsHeight(cards: CGFloat) -> CGFloat {
        cards > 0 ? cards + headerHeight + gap : 0
    }
}

extension AnyTransition {
    /// Zenith fork: the page's blur crossfade (blur, opacity and a hint of
    /// scale, nothing that lays out again). Kept local so a shared island
    /// transition can replace it in one place.
    static func notchAgentsSwap(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity
            : .modifier(active: NotchAgentsBlurSwap(amount: 1), identity: NotchAgentsBlurSwap(amount: 0))
    }
}

struct NotchAgentsBlurSwap: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: 6 * amount)
            .opacity(1 - amount)
            .scaleEffect(1 - 0.02 * amount)
    }
}

enum NotchAgentsMotion {
    static let swap = IslandMotion.smooth(0.32)
    static let rows = IslandMotion.spring(response: 0.38, damping: 0.86)
    static let stagger: Double = 0.04
}

// MARK: Page

/// The AI page: a header with the agent and what it is doing, the tabs on
/// its right, and the chosen tab beneath.
struct NotchAgentsLivePage: View {
    let size: CGSize
    @ObservedObject private var hooks = ClaudeHooksService.shared
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var accounts = CodexProfileLimitsService.shared
    @ObservedObject private var state = NotchAgentsPageState.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DefaultsKey.notchAgentsClaude) private var claude = true
    @State private var connected = true

    private var text: ZenithClaudeHooksStrings { ZenithStrings.claudeHooks(l10n.language) }
    private var layout: NotchAgentsPageLayout.Type { NotchAgentsPageLayout.self }

    private var session: ClaudeHooksSupport.Session? {
        ClaudeHooksSupport.focus(hooks.sessions, chosen: state.chosenSession)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.gap) {
            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    heading
                        .id(headingKey)
                        .transition(.notchAgentsSwap(reduceMotion: reduceMotion))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                if state.tab == .progress, hooks.sessions.count > 1 { pager }
                NotchAgentsTabs(selection: $state.tab, text: text)
            }
            .frame(height: layout.headerHeight)
            ZStack(alignment: .top) {
                content
                    .id(state.tab)
                    .transition(.notchAgentsSwap(reduceMotion: reduceMotion))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 2)
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(reduceMotion ? IslandMotion.easeInOut(0.2) : NotchAgentsMotion.swap, value: state.tab)
        .animation(reduceMotion ? IslandMotion.easeInOut(0.2) : NotchAgentsMotion.swap, value: headingKey)
        .environment(\.locale, l10n.language.formattingLocale())
        .onAppear {
            usage.pageDidAppear(preview: preview)
            accounts.pageDidAppear(preview: preview)
            connected = ClaudeHooksService.settingsState() == .connected
        }
        .onDisappear {
            guard !preview else { return }
            usage.pageDidDisappear()
            accounts.pageDidDisappear()
        }
        .onChange(of: state.tab) { _, _ in
            // Stats' cards report leaving when another tab takes their place;
            // the page is still there.
            DispatchQueue.main.async {
                usage.pageDidAppear(preview: preview)
                accounts.pageDidAppear(preview: preview)
            }
        }
    }

    // MARK: Header

    /// Changes with the tab and the session shown, which crossfades the heading.
    private var headingKey: String {
        switch state.tab {
        case .progress: return "progress." + (session?.id ?? usage.snapshot.live.first?.id ?? "none")
        case .usage, .stats: return state.tab.rawValue
        }
    }

    @ViewBuilder private var heading: some View {
        switch state.tab {
        case .progress:
            if let session {
                NotchAgentsHeading(provider: .claude, title: AgentProvider.claude.displayName,
                                   status: status(session), tint: statusTint(session), working: session.state != .done)
            } else if let live = usage.snapshot.live.first {
                NotchAgentsHeading(provider: live.provider, title: live.provider.displayName,
                                   status: live.project.isEmpty ? text.working : text.workingIn(live.project),
                                   tint: live.provider.tint, working: true)
            } else {
                NotchAgentsHeading(provider: claude ? .claude : nil,
                                   title: claude ? AgentProvider.claude.displayName
                                       : FeatureStrings.notchAgents(l10n.language).title,
                                   status: text.idle, tint: ZenithIsland.tertiary, working: false)
            }
        case .usage, .stats:
            HStack(spacing: 7) {
                Image(systemName: state.tab.symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(state.tab.title(text))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(ZenithIsland.secondary)
        }
    }

    private func status(_ session: ClaudeHooksSupport.Session) -> String {
        switch session.state {
        case .working: return session.folder.isEmpty ? text.working : text.workingIn(session.folder)
        case .waiting(.permission): return text.needsPermission
        case .waiting(.input): return text.waitingForYou
        case .done:
            guard let finished = session.finished else { return text.done }
            let seconds = finished.timeIntervalSince(session.turnStarted)
            return seconds >= 1 ? text.doneAfter(AgentFormat.duration(seconds, locale: l10n.language.formattingLocale(), units: 1))
                : text.done
        }
    }

    private func statusTint(_ session: ClaudeHooksSupport.Session) -> Color {
        switch session.state {
        case .working: return AgentProvider.claude.tint
        case .waiting: return ZenithStatus.warning
        case .done: return ZenithStatus.success
        }
    }

    /// Several sessions at once: which one shows, and a way to the next.
    private var pager: some View {
        let sessions = hooks.sessions
        let index = sessions.firstIndex { $0.id == session?.id } ?? 0
        return Button {
            state.chosenSession = sessions[(index + 1) % sessions.count].id
        } label: {
            HStack(spacing: 3) {
                Text("\(index + 1)/\(sessions.count)")
                    .font(ZenithType.mono(10, weight: .medium))
                    .contentTransition(.numericText(value: Double(index)))
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(ZenithIsland.secondary)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .help(text.nextSession)
        .accessibilityLabel(text.nextSession)
    }

    // MARK: Tabs

    @ViewBuilder private var content: some View {
        switch state.tab {
        case .progress:
            if let session {
                NotchAgentsProgressView(session: session, text: text)
                    .id(session.id)
                    .transition(.notchAgentsSwap(reduceMotion: reduceMotion))
            } else {
                NotchAgentsLogProgressView(live: usage.snapshot.live, text: text,
                                           offersConnect: claude && !connected && !preview)
            }
        case .usage:
            NotchAgentsUsageView(text: text)
        case .stats:
            NotchAgentsView(size: CGSize(width: size.width,
                                         height: max(0, size.height - layout.headerHeight - layout.gap - 2)))
        }
    }
}

// MARK: Header pieces

/// The agent's mark, its name and what it is doing, the dot in the state's colour.
private struct NotchAgentsHeading: View {
    let provider: AgentProvider?
    let title: String
    let status: String
    let tint: Color
    let working: Bool

    var body: some View {
        HStack(spacing: 7) {
            if let provider {
                NotchAgentGlyph(provider: provider, size: 12, working: working)
            } else {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .medium)).foregroundStyle(ZenithIsland.secondary)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
                .fixedSize()
            HStack(spacing: 5) {
                ZenithStatusDot(color: tint, size: 5)
                Text(status)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(-1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Small pills, the chosen one in emerald's 10/20/100, the others grey.
private struct NotchAgentsTabs: View {
    @Binding var selection: NotchAgentsTab
    let text: ZenithClaudeHooksStrings
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 5) {
            ForEach(NotchAgentsTab.allCases) { tab in
                let active = tab == selection
                Button { selection = tab } label: {
                    Text(tab.title(text))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(active ? ZenithStatus.success : ZenithIsland.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 22)
                        .background(Capsule(style: .continuous)
                            .fill(active ? ZenithStatus.fill(ZenithStatus.success) : Color.white.opacity(0.06)))
                        .overlay(Capsule(style: .continuous)
                            .strokeBorder(active ? ZenithStatus.stroke(ZenithStatus.success)
                                          : contrast == .increased ? ZenithIsland.contrastHairline : .clear, lineWidth: 1))
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(NotchAgentsPillStyle())
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
    }
}

/// A press settles to 0.96 and springs back.
private struct NotchAgentsPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(configuration.isPressed ? IslandMotion.easeOut(0.1) : IslandMotion.spring(response: 0.3, damping: 0.7),
                       value: configuration.isPressed)
    }
}

// MARK: Progress

/// A Claude Code session's turn: the checklist on the left, the file being
/// written on the right.
private struct NotchAgentsProgressView: View {
    let session: ClaudeHooksSupport.Session
    let text: ZenithClaudeHooksStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = NotchAgentsPageLayout.self
        GeometryReader { proxy in
            let card = min(240, max(150, proxy.size.width * 0.44))
            HStack(alignment: .top, spacing: 14) {
                checklist
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                NotchAgentsFileCard(session: session, text: text)
                    .frame(width: card, height: layout.bodyHeight)
            }
        }
        .frame(height: NotchAgentsPageLayout.bodyHeight)
    }

    @ViewBuilder private var checklist: some View {
        let steps = session.shownSteps
        if steps.isEmpty {
            Text(text.noSteps)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ZenithIsland.tertiary)
                .padding(.top, 2)
        } else {
            VStack(alignment: .leading, spacing: NotchAgentsPageLayout.rowSpacing) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    NotchAgentsStepRow(step: step, waiting: session.state == .waiting(.permission) && step.phase == .running,
                                       order: index)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .modifier(active: NotchAgentsRowEntry(amount: 1), identity: NotchAgentsRowEntry(amount: 0)),
                            removal: .notchAgentsSwap(reduceMotion: false)))
                }
            }
            .animation(reduceMotion ? IslandMotion.easeInOut(0.2) : NotchAgentsMotion.rows, value: steps.map(\.id))
        }
    }
}

/// A row arriving: up from 6 pt, out of a blur.
private struct NotchAgentsRowEntry: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(1 - amount)
            .blur(radius: 4 * amount)
            .offset(y: 6 * amount)
    }
}

/// ✓ in Claude's colour once done, ▶ while it runs, ✗ in red when it failed;
/// finished rows step back.
private struct NotchAgentsStepRow: View {
    let step: ClaudeHooksSupport.Step
    /// The running step waits for permission: its ▶ turns amber.
    let waiting: Bool
    /// Its place in the list, for the staggered entrance.
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var symbol: String {
        switch step.phase {
        case .running: return "play.fill"
        case .done: return "checkmark"
        case .failed: return "xmark"
        }
    }

    private var tint: Color {
        switch step.phase {
        case .running: return waiting ? ZenithStatus.warning : AgentProvider.claude.tint
        case .done: return AgentProvider.claude.tint
        case .failed: return ZenithStatus.error
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: step.phase == .running ? 8.5 : 9.5, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 12)
            Text(step.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(step.phase == .running ? ZenithIsland.primary : ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(height: NotchAgentsPageLayout.rowHeight)
        .animation(IslandMotion.smooth(0.25), value: step.phase)
        .modifier(NotchAgentsRowEntry(amount: shown || reduceMotion ? 0 : 1))
        .onAppear {
            guard !shown else { return }
            withAnimation(NotchAgentsMotion.rows.delay(Double(order) * NotchAgentsMotion.stagger)) { shown = true }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The file the turn is on: its name in mono and Claude's colour, the lines
/// it added and removed, what is happening to it and a thin bar.
private struct NotchAgentsFileCard: View {
    let session: ClaudeHooksSupport.Session
    let text: ZenithClaudeHooksStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Focus: Equatable {
        let key: String
        let name: String
        let symbol: String
        let added: Int?
        let removed: Int?
        let phase: ClaudeHooksSupport.Step.Phase
        let status: String
        let stepID: String
    }

    private var focus: Focus? {
        let waiting = session.state == .waiting(.permission)
        if let file = session.file {
            return Focus(key: file.name, name: file.name, symbol: Self.symbol(file.tool), added: file.added,
                         removed: file.removed, phase: file.phase,
                         status: waiting && file.phase == .running ? text.needsPermission : status(file.tool, file.phase),
                         stepID: file.stepID)
        }
        guard let step = session.steps.last else { return nil }
        return Focus(key: step.id, name: step.target ?? step.toolName, symbol: Self.symbol(step.tool), added: nil,
                     removed: nil, phase: step.phase,
                     status: waiting && step.phase == .running ? text.needsPermission : status(step.tool, step.phase),
                     stepID: step.id)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NotchAgentsPageLayout.cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
            if let focus {
                details(focus)
                    .id(focus.key)
                    .transition(.notchAgentsSwap(reduceMotion: reduceMotion))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text.noSteps)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ZenithIsland.tertiary)
                        .lineLimit(2)
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                }
                .padding(14)
            }
        }
        .animation(reduceMotion ? IslandMotion.easeInOut(0.2) : NotchAgentsMotion.swap, value: focus?.key)
    }

    private func details(_ focus: Focus) -> some View {
        let tint = AgentProvider.claude.tint
        let waiting = focus.status == text.needsPermission
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: focus.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(focus.name)
                    .font(ZenithType.mono(12.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if let added = focus.added {
                    Text("+\(added)")
                        .font(ZenithType.mono(11.5, weight: .semibold))
                        .foregroundStyle(ZenithStatus.success)
                        .contentTransition(.numericText(value: Double(added)))
                        .fixedSize()
                }
                if let removed = focus.removed, removed > 0 {
                    Text("−\(removed)")
                        .font(ZenithType.mono(11.5, weight: .semibold))
                        .foregroundStyle(ZenithStatus.error)
                        .contentTransition(.numericText(value: Double(removed)))
                        .fixedSize()
                }
            }
            Text(focus.status)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(waiting ? ZenithStatus.warning : ZenithIsland.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
            NotchAgentsStepBar(stepID: focus.stepID, phase: focus.phase,
                               tint: focus.phase == .failed ? ZenithStatus.error : waiting ? ZenithStatus.warning : tint)
        }
        .animation(IslandMotion.smooth(0.3), value: focus.added)
        .animation(IslandMotion.smooth(0.3), value: focus.removed)
        .animation(IslandMotion.smooth(0.25), value: focus.status)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func status(_ tool: String, _ phase: ClaudeHooksSupport.Step.Phase) -> String {
        switch phase {
        case .failed: return text.failed
        case .done: return ClaudeHooksSupport.writingTools.contains(tool) ? text.saved : text.finished
        case .running:
            switch tool {
            case "Edit", "MultiEdit", "NotebookEdit": return text.editing
            case "Write": return text.saving
            case "Read": return text.reading
            case "Bash": return text.runningStep
            default: return text.workingStep
            }
        }
    }

    private static func symbol(_ tool: String) -> String {
        switch tool {
        case "Bash": return "terminal.fill"
        case "Read": return "doc.text"
        case "Edit", "MultiEdit", "Write", "NotebookEdit": return "doc.text.fill"
        case "Grep", "Glob": return "magnifyingglass"
        case "WebFetch", "WebSearch": return "globe"
        default: return "sparkle"
        }
    }
}

/// A thin bar: while the step runs it fills smoothly toward the end without
/// reaching it, and on completion it fills. Only the fill's offset moves.
private struct NotchAgentsStepBar: View {
    let stepID: String
    let phase: ClaudeHooksSupport.Step.Phase
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    /// Bumped by every start and finish, so a slow fill left from an earlier
    /// step never continues after it.
    @State private var generation = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(tint.opacity(0.16))
                Capsule(style: .continuous).fill(tint)
                    .offset(x: -(1 - progress) * proxy.size.width)
            }
            .clipShape(Capsule(style: .continuous))
        }
        .frame(height: 3)
        .onAppear { begin(phase) }
        .onChange(of: stepID) { _, _ in begin(phase) }
        .onChange(of: phase) { _, phase in
            guard phase != .running else { return }
            generation += 1
            withAnimation(reduceMotion ? IslandMotion.easeOut(0.2) : IslandMotion.spring(response: 0.35, damping: 0.9)) {
                progress = phase == .done ? 1 : max(progress, 0.15)
            }
        }
        .accessibilityHidden(true)
    }

    private func begin(_ phase: ClaudeHooksSupport.Step.Phase) {
        generation += 1
        guard phase == .running else { progress = phase == .done ? 1 : 0.15; return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        guard !reduceMotion else { progress = 0.6; return }
        let mine = generation
        withAnimation(.easeOut(duration: 1.2)) {
            progress = 0.62
        } completion: {
            guard generation == mine else { return }
            withAnimation(.easeOut(duration: 24)) { progress = 0.94 }
        }
    }
}

/// Without a hook session: the agents the logs say are working, or an
/// invitation to connect Claude Code.
private struct NotchAgentsLogProgressView: View {
    let live: [AgentLiveSession]
    let text: ZenithClaudeHooksStrings
    let offersConnect: Bool

    var body: some View {
        if live.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ZenithIsland.tertiary)
                Text(offersConnect ? text.connectHint : text.nothingRunning)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ZenithIsland.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                if offersConnect { connectButton }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: NotchAgentsPageLayout.rowSpacing + 3) {
                        ForEach(live.prefix(4)) { session in row(session, now: context.date) }
                        if offersConnect {
                            Spacer(minLength: 0)
                            connectButton
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(height: NotchAgentsPageLayout.bodyHeight, alignment: .top)
        }
    }

    private func row(_ session: AgentLiveSession, now: Date) -> some View {
        HStack(spacing: 8) {
            NotchAgentGlyph(provider: session.provider, size: 9)
            Text(session.project.isEmpty ? session.provider.displayName : session.project)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(AgentPricing.displayName(session.model))
                .font(ZenithType.mono(10))
                .foregroundStyle(ZenithIsland.tertiary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(AgentFormat.clock(now.timeIntervalSince(session.started)))
                .font(ZenithType.mono(11, weight: .medium))
                .foregroundStyle(session.provider.tint)
                .contentTransition(.numericText())
        }
        .frame(height: 18)
    }

    private var connectButton: some View {
        Button {
            NotchService.shared.openSettings(showing: .agents)
        } label: {
            Label(text.connect, systemImage: "arrow.up.forward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AgentProvider.claude.tint)
                .labelStyle(.titleAndIcon)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Usage

/// Each agent's allowance as a ring around its mark, with what is left
/// beneath, the share shown as Settings chooses.
private struct NotchAgentsUsageView: View {
    let text: ZenithClaudeHooksStrings
    @ObservedObject private var usage = AgentUsageService.shared
    @ObservedObject private var resets = AgentCodexResetService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchAgentsLimitDisplay) private var display = NotchAgentLimitDisplay.remaining.rawValue
    @AppStorage(DefaultsKey.notchAgentsLimitFocus) private var focus = NotchAgentLimitFocus.mostUsed.rawValue
    @AppStorage(DefaultsKey.notchAgentsClaude) private var claude = true
    @AppStorage(DefaultsKey.notchAgentsCodex) private var codex = true
    @AppStorage(DefaultsKey.notchAgentsOpenCode) private var opencode = true

    private var providers: [AgentProvider] {
        let snapshot = usage.snapshot
        return [claude ? AgentProvider.claude : nil, codex ? .codex : nil, opencode ? .opencode : nil].compactMap { $0 }
            .filter { snapshot.limits[$0] != nil || snapshot.seen.contains($0) }
            .filter { $0 != .opencode || snapshot.limits[$0] != nil }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 30) {
                if providers.isEmpty {
                    Text(text.noLimits)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ZenithIsland.tertiary)
                } else {
                    ForEach(Array(providers.enumerated()), id: \.element) { index, provider in
                        ring(provider, order: index, now: context.date)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: NotchAgentsPageLayout.bodyHeight)
        .onAppear { if codex { resets.refreshIfStale() } }
    }

    private func ring(_ provider: AgentProvider, order: Int, now: Date) -> some View {
        let window = NotchAgentSupport.focusedLimit(usage.snapshot.limits[provider],
                                                    focus: NotchAgentLimitFocus(rawValue: focus) ?? .mostUsed, now: now)
        let used = display == NotchAgentLimitDisplay.used.rawValue
        let strings = FeatureStrings.notchAgents(l10n.language)
        let share = window.map { used ? strings.usedShare(AgentFormat.percent($0.usedFraction))
                                      : strings.left(AgentFormat.percent($0.remainingFraction)) } ?? "—"
        let badge = provider == .codex && (resets.summary?.available ?? 0) > 0
        return NotchAgentsRing(provider: provider,
                               fraction: window.map { used ? $0.usedFraction : $0.remainingFraction } ?? 0,
                               tint: window.map { agentLimitTint(provider, usedFraction: $0.usedFraction) } ?? provider.tint,
                               share: share, badge: badge, order: order)
            .help(window == nil ? text.noLimits : share)
    }
}

private struct NotchAgentsRing: View {
    let provider: AgentProvider
    let fraction: Double
    let tint: Color
    let share: String
    let badge: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let side = NotchAgentsPageLayout.ringSize
        let value = fraction.isFinite ? min(1, max(0, fraction)) : 0
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(tint.opacity(0.18), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(IslandMotion.smooth(0.6), value: value)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(NotchAgentMark(provider: provider, size: 13))
                if badge {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(provider.tint))
                        .offset(x: side * 0.36, y: -side * 0.36)
                }
            }
            .frame(width: side, height: side)
            Text(provider.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
            Text(share)
                .font(ZenithType.mono(10.5, weight: .medium))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(IslandMotion.smooth(0.4), value: share)
        }
        .opacity(shown || reduceMotion ? 1 : 0)
        .scaleEffect(shown || reduceMotion ? 1 : 0.92)
        .blur(radius: shown || reduceMotion ? 0 : 4)
        .onAppear {
            withAnimation(IslandMotion.spring(response: 0.42, damping: 0.82).delay(Double(order) * NotchAgentsMotion.stagger)) {
                shown = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
