// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// MARK: Layout

/// Zenith fork: the measures of a terminal command in the closed island,
/// shared by the island's geometry (NotchService) and the strips that draw
/// it, so the wings fit what is drawn.
///
/// Around a camera: the state's mark and the clock left of the camera, the
/// program right of it. In a floating capsule: mark, clock and program in one
/// row. The clock's slot is as wide as its widest reading, so the wings never
/// move while it ticks; only reaching an hour widens it, once.
enum CommandActivityLayout {
    static let clockFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    static let capsuleClockFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let programFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let markSpacing: CGFloat = 5
    /// Below this wing the clock goes and only the mark and the program stay.
    static let clockWing: CGFloat = 50

    static func iconSize(height: CGFloat) -> CGFloat { min(12, NotchTimerSupport.stripIconSize(height: height)) }

    /// The program, how many more run beside it, and its folder when asked for.
    static func detail(_ activity: CommandActivitySupport.Activity) -> String {
        CommandActivitySupport.detail(activity)
    }

    static func clockWidth(_ activity: CommandActivitySupport.Activity, font: NSFont) -> CGFloat {
        width(CommandActivitySupport.clockTemplate(long: activity.isLong), font: font)
    }

    /// The wider side, measured as the strip draws it, with the clearance from
    /// the silhouette's curve and air beside the camera. The watch's wings
    /// fit the same mark-and-reading shape, so the island lends them.
    static func stripWing(_ activity: CommandActivitySupport.Activity?, in geometry: NotchGeometry) -> CGFloat {
        guard let activity else { return NotchWatchSupport.stripWingRange.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let height = provisional.compactActivityContentHeight
        let icon = iconSize(height: height)
        let iconInset = provisional.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = iconInset + icon + markSpacing + clockWidth(activity, font: clockFont)
        let right = textInset + width(detail(activity), font: programFont)
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }

    /// The floating capsule's row: mark, clock and program.
    static func capsuleSurface(_ activity: CommandActivitySupport.Activity?, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let activity else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.spacing + clockWidth(activity, font: capsuleClockFont)
            + layout.groupSpacing + layout.width(detail(activity), font: layout.detailFont)
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func accessibilityValue(_ activity: CommandActivitySupport.Activity, language: AppLanguage) -> String {
        let text = ZenithStrings.commandActivity(language)
        switch activity {
        case .running: return "\(text.running), \(detail(activity))"
        case .finished(_, _, _, let duration, let succeeded):
            return "\(succeeded ? text.succeeded : text.failed), \(detail(activity)), "
                + CommandActivitySupport.clock(duration)
        }
    }
}

// MARK: Mark and clock

/// The command's state: an arc turning while it runs, then a ✓ in emerald or
/// a ✗ in red. Finishing, the arc shrinks away as the mark grows in, so the
/// colour crosses from purple to the result's, and the mark gives one small
/// spring bump. Only scale, rotation and opacity animate. Reduce Motion
/// keeps the arc still and swaps the two with a plain fade.
struct CommandStateMark: View {
    enum Phase: Equatable { case running, succeeded, failed }

    let phase: Phase
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bumps = 0

    init(_ activity: CommandActivitySupport.Activity, size: CGFloat) {
        switch activity {
        case .running: phase = .running
        case .finished(_, _, _, _, let succeeded): phase = succeeded ? .succeeded : .failed
        }
        self.size = size
    }

    private var swap: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.35).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            switch phase {
            case .running:
                CommandSpinner(size: size).transition(swap)
            case .succeeded, .failed:
                Image(systemName: phase == .succeeded ? "checkmark" : "xmark")
                    .font(.system(size: size * (phase == .succeeded ? 0.86 : 0.78), weight: .bold))
                    .foregroundStyle(phase == .succeeded ? ZenithStatus.success : ZenithStatus.error)
                    .transition(swap)
            }
        }
        .frame(width: size, height: size)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: bumps) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                SpringKeyframe(1.12, duration: 0.14, spring: .snappy)
                SpringKeyframe(1, duration: 0.21, spring: .smooth)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2), value: phase)
        .onChange(of: phase) { old, new in
            if old == .running, new != .running, !reduceMotion { bumps += 1 }
        }
        .accessibilityHidden(true)
    }
}

/// A track ring with a short arc turning on it. Its own view, so every
/// command that starts gets a fresh turn; only its rotation animates.
private struct CommandSpinner: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        let line = max(1.4, size * 0.14)
        ZStack {
            Circle().stroke(ZenithStatus.progress.opacity(0.28), lineWidth: line)
            Circle().trim(from: 0, to: 0.3)
                .stroke(ZenithStatus.progress, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .animation(turning ? .linear(duration: 1.1).repeatForever(autoreverses: false) : nil) {
                    $0.rotationEffect(.degrees(turning ? 360 : 0))
                }
        }
        .padding(line / 2)
        .frame(width: size, height: size)
        .onAppear { turning = !reduceMotion }
        .onChange(of: reduceMotion) { _, reduced in turning = !reduced }
    }
}

/// The elapsed time while a command runs, its total once it ended. Mono
/// digits in a slot of fixed width: a tick only rolls the digits that change
/// (numeric text transition) and never lays out anything around them. The
/// tick is a TimelineView on the command's own start, so it lands on the
/// second and redraws this text alone.
struct CommandClock: View {
    let activity: CommandActivitySupport.Activity
    let font: NSFont
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // One timeline for both states, so the last running reading rolls into the total.
        TimelineView(.periodic(from: anchor, by: 1)) { context in
            let reading = text(at: context.date)
            Text(reading)
                .font(Font(font as CTFont))
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: false))
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: reading)
        }
        .frame(width: CommandActivityLayout.clockWidth(activity, font: font), alignment: .leading)
        .accessibilityHidden(true)
    }

    private var anchor: Date {
        if case .running(_, _, _, let start, _, _) = activity { return start }
        return Date(timeIntervalSinceReferenceDate: 0)
    }

    private func text(at date: Date) -> String {
        switch activity {
        case .running(_, _, _, let start, _, _): return CommandActivitySupport.clock(date.timeIntervalSince(start))
        case .finished(_, _, _, let duration, _): return CommandActivitySupport.clock(duration)
        }
    }
}

// MARK: Closed island

/// Zenith fork: a terminal command in the closed island, around the camera:
/// the mark and the clock on the left, the program on the right, each
/// anchored to its own edge so the silhouette's curve decides the margin.
struct CommandActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var commands = CommandActivityService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The result going clears the activity before the strip has left.
        NotchStripHold(commands.activity, shows: commands.activity != nil) { activity in
            if let activity { strip(activity) }
        }
    }

    private func strip(_ activity: CommandActivitySupport.Activity) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let icon = CommandActivityLayout.iconSize(height: height)
        let detail = CommandActivityLayout.detail(activity)
        return Button { service.openActivity(NotchCompactActivity.command.module) } label: {
            HStack(spacing: 0) {
                HStack(spacing: CommandActivityLayout.markSpacing) {
                    if wing >= 28 { CommandStateMark(activity, size: icon) }
                    if wing >= CommandActivityLayout.clockWing {
                        CommandClock(activity: activity, font: CommandActivityLayout.clockFont)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2))
                .frame(width: wing, height: height, alignment: .leading)
                .clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                Group {
                    if wing >= 36 {
                        Text(detail)
                            .font(Font(CommandActivityLayout.programFont as CTFont))
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
                .padding(.trailing, geometry.compactActivityEdgeInset(boxHeight: 8, radius: 0))
                .frame(width: wing, height: height, alignment: .trailing)
                .clipped()
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, geometry.compactActivityHorizontalPadding)
        .padding(.top, geometry.compactActivityTopPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.commandActivity(l10n.language).activityTitle)
        .accessibilityValue(CommandActivityLayout.accessibilityValue(activity, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

/// Zenith fork: a terminal command in the floating capsule: mark, clock and
/// program in one row.
struct CommandCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var commands = CommandActivityService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(commands.activity, shows: commands.activity != nil) { activity in
            if let activity { row(activity) }
        }
    }

    private func row(_ activity: CommandActivitySupport.Activity) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        return HStack(spacing: layout.spacing) {
            CommandStateMark(activity, size: layout.symbolSize)
                .frame(width: layout.symbolWidth)
            CommandClock(activity: activity, font: CommandActivityLayout.capsuleClockFont)
            Text(CommandActivityLayout.detail(activity))
                .font(Font(layout.detailFont as CTFont))
                .lineLimit(1).truncationMode(.tail)
                .padding(.leading, layout.groupSpacing - layout.spacing)
        }
        .padding(.leading, side + layout.endPadding)
        .padding(.trailing, side + layout.endPadding)
        .frame(width: size.width, height: geometry.stripHeight)
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.commandActivity(l10n.language).activityTitle)
        .accessibilityValue(CommandActivityLayout.accessibilityValue(activity, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

// MARK: Settings

/// Zenith fork: the options in Settings → Dynamic Island → Activity: the
/// switch, when a command shows, the folder, more programs to leave out, and
/// the shell hook in `~/.zshrc`, added only after showing exactly what goes in.
struct CommandActivitySettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = CommandActivityService.shared
    @AppStorage(DefaultsKey.notchCommandActivity) private var enabled = false
    @AppStorage(DefaultsKey.notchCommandThreshold) private var threshold = CommandActivitySupport.defaultThreshold
    @AppStorage(DefaultsKey.notchCommandShowsFolder) private var showsFolder = false
    @AppStorage(DefaultsKey.notchCommandIgnored) private var ignored = ""
    @State private var draft = ""
    @State private var hook = CommandActivitySupport.HookState.missing
    @State private var copied = false
    @State private var changed = false
    @State private var editFailed = false
    @FocusState private var ignoreFocused: Bool

    private var text: ZenithCommandActivityStrings { ZenithStrings.commandActivity(l10n.language) }
    private var folder: String? { CommandActivityService.folderURL?.path }

    var body: some View {
        // A heading drawn here rather than through SettingsCard's title, whose
        // labels Settings search indexes from upstream's catalogs.
        VStack(alignment: .leading, spacing: 8) {
            ZenithSectionTitle(text.section) // the kit's section title, as the island page's others
            SettingsCard {
                ZenithSwitchRow(text.toggle, isOn: $enabled) {
                    label(text.toggle, caption: text.toggleCaption)
                }
                if enabled { options }
            }
        }
        .zenithSectionAnchor(.zenithCommandActivity, cornerRadius: ZenithRadius.panel + 6, inset: 6) // Settings search lands here
        .onAppear {
            draft = ignored
            refreshHook()
        }
        .onChange(of: enabled) { _, _ in NotchService.shared.syncWithPreferences() }
        .onChange(of: threshold) { _, _ in NotchService.shared.syncWithPreferences() }
        .onChange(of: showsFolder) { _, _ in NotchService.shared.syncWithPreferences() }
        .onChange(of: ignored) { _, _ in NotchService.shared.syncWithPreferences() }
    }

    @ViewBuilder private var options: some View {
        HStack(spacing: 12) {
            Text(text.showAfter)
            Spacer(minLength: 12)
            Picker(text.showAfter, selection: $threshold) {
                ForEach(CommandActivitySupport.thresholds, id: \.self) { seconds in
                    Text(text.seconds.replacingOccurrences(of: "%d", with: "\(seconds)")).tag(seconds)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        ZenithSwitchRow(text.showFolder, isOn: $showsFolder) {
            label(text.showFolder, caption: text.showFolderCaption)
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(text.ignore)
                Spacer(minLength: 12)
                TextField(text.ignore, text: $draft, prompt: Text(text.ignorePlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    .focused($ignoreFocused)
                    .onSubmit(commitIgnored)
                    .onChange(of: ignoreFocused) { _, focused in if !focused { commitIgnored() } }
            }
            Text(text.ignoreCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Divider().padding(.vertical, 2)
        hookSection
    }

    private var hookSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.hook).font(ZenithType.emphasis)
            hookStatus
            HStack(spacing: 8) {
                switch hook {
                case .installed(let installed) where installed == folder:
                    Button(text.remove, role: .destructive, action: removeHook)
                case .installed:
                    Button(text.install, action: confirmInstall)
                    Button(text.remove, role: .destructive, action: removeHook)
                case .missing:
                    Button(text.install, action: confirmInstall)
                case .damaged:
                    EmptyView()
                }
                Button(copied ? text.copied : text.copy, action: copySnippet)
                    .disabled(CommandActivityService.hookBlock == nil)
            }
            if changed {
                Text(text.newTab).font(ZenithType.caption).foregroundStyle(.secondary)
            }
            if editFailed {
                Text(text.editFailed).font(ZenithType.caption).foregroundStyle(ZenithStatus.error)
            }
            Text(text.hookCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hookStatus: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch hook {
            case .installed(let installed) where installed == folder:
                Label(text.installed, systemImage: "checkmark.circle.fill").foregroundStyle(ZenithStatus.success)
            case .installed:
                Label(text.otherBuild, systemImage: "exclamationmark.circle").foregroundStyle(ZenithStatus.warning)
            case .missing:
                Label(text.notInstalled, systemImage: "circle.dashed").foregroundStyle(.secondary)
            case .damaged:
                Label(text.damaged, systemImage: "exclamationmark.triangle").foregroundStyle(ZenithStatus.warning)
            }
            // Relative, so it reads again now and then while the page shows.
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(lastEventText(now: context.date))
                    .font(ZenithType.caption).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func lastEventText(now: Date) -> String {
        guard let date = service.lastEvent else { return text.noEvents }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        formatter.unitsStyle = .short
        return text.lastEvent.replacingOccurrences(of: "%@", with: formatter.localizedString(for: min(date, now),
                                                                                              relativeTo: now))
    }

    private func commitIgnored() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != ignored { ignored = trimmed }
    }

    private func refreshHook() { hook = CommandActivityService.hookState() }

    private func copySnippet() {
        guard let block = CommandActivityService.hookBlock else { return }
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            NSPasteboard.general.declareVorssaintSource()
            return NSPasteboard.general.setString(block, forType: .string)
        }, then: { done in
            if done { copied = true } else { ZenithQuiet.beep() }
        })
    }

    /// Shows the exact block before anything is written.
    private func confirmInstall() {
        guard let block = CommandActivityService.hookBlock else { return }
        let alert = NSAlert()
        alert.messageText = text.confirmTitle
        alert.informativeText = text.confirmMessage
        alert.addButton(withTitle: text.add)
        alert.addButton(withTitle: text.cancel)
        alert.accessoryView = Self.codeView(block)
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            apply(CommandActivityService.installHook())
        }
        if let window = NSApp.keyWindow { alert.beginSheetModal(for: window, completionHandler: finish) }
        else { finish(alert.runModal()) }
    }

    private func removeHook() { apply(CommandActivityService.removeHook()) }

    private func apply(_ result: CommandActivitySupport.HookEditResult) {
        editFailed = result == .failed
        if result == .changed { changed = true }
        refreshHook()
    }

    /// The block in a scrolling, selectable monospaced box.
    private static func codeView(_ code: String) -> NSView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 240))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true
        let view = NSTextView(frame: scroll.bounds)
        view.string = code
        view.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        view.isEditable = false
        view.isSelectable = true
        view.textContainerInset = NSSize(width: 6, height: 6)
        view.isHorizontallyResizable = true
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                   height: CGFloat.greatestFiniteMagnitude)
        view.autoresizingMask = [.height]
        scroll.documentView = view
        return scroll
    }
}
