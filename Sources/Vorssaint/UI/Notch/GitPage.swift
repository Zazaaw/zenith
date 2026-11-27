// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Git page in the open island. The repository on its
// tinted tile with a switch to the pinned and recent ones, the branch chip,
// ahead and behind in mono, the actions (open in the editor or Terminal, copy
// the branch, open on GitHub), an amber banner while a merge, rebase or
// cherry-pick is open, the counts as small tinted pills, the last commit, and
// the first changed files. Read-only: no pull, push or commit, on purpose.
// Counts roll their digits; rows rise out of a blur; the page's states and a
// switch of repository go through the island's morph. Transform, opacity and
// blur only; Reduce Motion fades.

enum GitMotion {
    static func list(reduceMotion: Bool) -> Animation {
        reduceMotion ? IslandMotion.easeInOut(ZenithMotion.fast) : ZenithMorph.animation
    }

    /// A row rises 6 points out of a blur; under Reduce Motion it only fades.
    static func row(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: GitRowEffect(amount: 1, rise: 6), identity: GitRowEffect(amount: 0, rise: 6)),
            removal: .modifier(active: GitRowEffect(amount: 1, rise: 0), identity: GitRowEffect(amount: 0, rise: 0)))
    }

    static func pill(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity)
    }
}

private struct GitRowEffect: ViewModifier {
    let amount: CGFloat
    let rise: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: 6 * amount)
            .opacity(Double(1 - amount))
            .scaleEffect(1 - 0.03 * amount)
            .offset(y: rise * amount)
    }
}

/// The colours a change's kind wears: they carry meaning, so they come from
/// the status palette, and a word always goes with them.
enum GitPalette {
    static let staged = ZenithStatus.success
    static let modified = ZenithStatus.warning
    static let untracked = ZenithStatus.info
    static let conflicted = ZenithStatus.error

    static func color(_ change: GitFileChange) -> Color {
        if change.isConflicted { return conflicted }
        if change.isUntracked { return untracked }
        return change.isStaged ? staged : modified
    }
}

struct GitPage: View {
    let size: CGSize
    @ObservedObject private var service = GitService.shared
    @ObservedObject private var l10n = L10n.shared

    private var text: ZenithGitStrings { ZenithStrings.git(l10n.language) }

    private enum Stage: Hashable { case empty, loading, failed, ready(String) }

    private var stage: Stage {
        guard let root = service.current?.root else { return .empty }
        switch service.state {
        case .empty: return .empty
        case .loading: return service.snapshot == nil ? .loading : .ready(root)
        case .failed: return .failed
        case .ready: return service.snapshot == nil ? .loading : .ready(root)
        }
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .top)
            .zenithMorph(on: stage)
            .onAppear { service.shown() }
            .onDisappear { service.hidden() }
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .empty:
            GitEmpty(text: text, accessibility: service.accessibilityGranted)
        case .loading:
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            VStack(spacing: 8) {
                GitHeader(text: text, snapshot: nil)
                Text(text.failed)
                    .font(.system(size: 12))
                    .foregroundStyle(ZenithIsland.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .ready:
            if let snapshot = service.snapshot { GitStatusView(snapshot: snapshot, text: text) }
        }
    }
}

// MARK: - Empty

private struct GitEmpty: View {
    let text: ZenithGitStrings
    let accessibility: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: NotchModule.git.zenithIconSymbol, tint: NotchModule.git.zenithTint, size: 44)
            Text(text.empty)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
            Text(text.emptyHint)
                .font(.system(size: 11.5))
                .foregroundStyle(ZenithIsland.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
            if !accessibility && GitOptions.current().fromEditor {
                Button(text.needsAccessibility) { GitService.openAccessibilitySettings() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ZenithStatus.warning)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Status

private struct GitStatusView: View {
    let snapshot: GitSnapshot
    let text: ZenithGitStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GitHeader(text: text, snapshot: snapshot)
            if let operation = snapshot.operation {
                GitOperationBanner(operation: operation, text: text)
                    .transition(GitMotion.row(reduceMotion: reduceMotion))
            }
            GitCountPills(snapshot: snapshot, text: text)
            GitCommitLine(snapshot: snapshot, text: text)
            GitFileList(snapshot: snapshot, text: text)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .animation(GitMotion.list(reduceMotion: reduceMotion), value: snapshot.operation)
    }
}

/// The repository's tile and name (a switch when there is more than one),
/// the branch chip with ahead and behind, and the actions.
private struct GitHeader: View {
    let text: ZenithGitStrings
    let snapshot: GitSnapshot?
    @ObservedObject private var service = GitService.shared

    var body: some View {
        HStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: NotchModule.git.zenithIconSymbol, tint: NotchModule.git.zenithTint, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                repository
                if let snapshot {
                    HStack(spacing: 6) {
                        GitBranchChip(branch: snapshot.branch, text: text)
                        GitAheadBehind(branch: snapshot.branch, text: text)
                        if service.fetching {
                            ProgressView().controlSize(.mini).help(text.fetching).accessibilityLabel(text.fetching)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GitActions(text: text, snapshot: snapshot)
        }
    }

    private var name: String {
        (service.current?.root as NSString?)?.lastPathComponent ?? text.title
    }

    @ViewBuilder private var repository: some View {
        let choices = service.choices
        if choices.count > 1 {
            Menu {
                ForEach(choices, id: \.self) { root in
                    Button { service.choose(root) } label: {
                        if root == service.current?.root {
                            Label(Self.menuTitle(root, among: choices), systemImage: "checkmark")
                        } else {
                            Text(Self.menuTitle(root, among: choices))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    title
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ZenithIsland.tertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(text.switchRepository)
            .accessibilityLabel(text.switchRepository + ", " + name)
        } else {
            title
        }
    }

    private var title: some View {
        Text(name)
            .font(.system(size: 13, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(ZenithIsland.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .help(service.current?.root ?? "")
    }

    /// The folder's name, and its path where two share a name.
    static func menuTitle(_ root: String, among roots: [String]) -> String {
        let name = (root as NSString).lastPathComponent
        let twins = roots.filter { ($0 as NSString).lastPathComponent == name }.count
        return twins > 1 ? name + "  " + (root as NSString).abbreviatingWithTildeInPath : name
    }
}

private struct GitBranchChip: View {
    let branch: GitBranchInfo
    let text: ZenithGitStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let label = branch.head ?? branch.shortOID ?? "HEAD"
        let tint = NotchModule.git.zenithTint
        HStack(spacing: 4) {
            Image(systemName: branch.isDetached ? "smallcircle.filled.circle" : GitSupportSymbols.branch)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(ZenithType.mono(10.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .contentTransition(reduceMotion ? .opacity : .interpolate)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 18)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 0.75))
        .frame(maxWidth: 200, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .help(branch.isDetached ? text.detached : label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(branch.isDetached ? text.detached + ", " + label
                            : text.branchValue.replacingOccurrences(of: "%@", with: label))
        .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: label)
    }
}

/// Commits ahead of and behind the upstream, as of the last fetch.
private struct GitAheadBehind: View {
    let branch: GitBranchInfo
    let text: ZenithGitStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if branch.upstream == nil {
            if branch.head != nil {
                Text(text.noUpstream)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ZenithIsland.tertiary)
                    .lineLimit(1)
            }
        } else {
            let ahead = branch.ahead ?? 0
            let behind = branch.behind ?? 0
            HStack(spacing: 6) {
                arrow("arrow.up", ahead)
                arrow("arrow.down", behind)
            }
            .help(branch.upstream ?? "")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([text.ahead.replacingOccurrences(of: "%@", with: "\(ahead)"),
                                 text.behind.replacingOccurrences(of: "%@", with: "\(behind)")].joined(separator: ", "))
        }
    }

    private func arrow(_ symbol: String, _ count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 8.5, weight: .bold))
            Text("\(count)")
                .font(ZenithType.mono(10.5, weight: .medium))
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: count)
        }
        .foregroundStyle(count > 0 ? ZenithIsland.primary : ZenithIsland.tertiary)
    }
}

/// Open in the editor and in Terminal, copy the branch, open on GitHub.
/// Pull and push are left out on purpose: the page only reads.
private struct GitActions: View {
    let text: ZenithGitStrings
    let snapshot: GitSnapshot?
    @ObservedObject private var service = GitService.shared

    var body: some View {
        let root = service.current?.root
        let editor = root.flatMap { service.editor(for: $0) }
        HStack(spacing: 2) {
            if let editor {
                NotchIconButton(symbol: "chevron.left.forwardslash.chevron.right",
                                title: text.openIn.replacingOccurrences(of: "%@", with: GitService.appName(editor.url))) {
                    service.openInEditor()
                }
            }
            NotchIconButton(symbol: "terminal", title: text.openTerminal) { service.openInTerminal() }
            if snapshot?.branch.head != nil || snapshot?.branch.oid != nil {
                NotchIconButton(symbol: service.copied ? "checkmark" : "doc.on.doc",
                                title: service.copied ? text.copied : text.copyBranch) { service.copyBranch() }
            }
            if snapshot?.gitHubURL != nil {
                NotchIconButton(symbol: "arrow.up.right.square", title: text.openGitHub) { service.openOnGitHub() }
            }
        }
    }
}

private struct GitOperationBanner: View {
    let operation: GitOperation
    let text: ZenithGitStrings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ZenithStatus.warning)
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
            Text(text.operationHint)
                .font(.system(size: 11))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ZenithStatus.warning.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(ZenithStatus.warning.opacity(0.3), lineWidth: 0.75))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch operation {
        case .merge: return text.merge
        case .rebase(let step, let total):
            if let step, let total, total > 0 { return text.rebase + " \(step)/\(total)" }
            return text.rebase
        case .cherryPick: return text.cherryPick
        case .revert: return text.revert
        case .bisect: return text.bisect
        case .applyMailbox: return text.applyMailbox
        }
    }
}

/// Staged, modified, untracked, conflicts and the stash, those above zero,
/// as small tinted pills; Clean when there is nothing.
private struct GitCountPills: View {
    let snapshot: GitSnapshot
    let text: ZenithGitStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Pill: Identifiable {
        let id: String
        let title: String
        let count: Int?
        let color: Color
    }

    private var pills: [Pill] {
        let counts = snapshot.counts
        var pills: [Pill] = []
        if counts.conflicted > 0 { pills.append(Pill(id: "conflicts", title: text.conflicts, count: counts.conflicted, color: GitPalette.conflicted)) }
        if counts.staged > 0 { pills.append(Pill(id: "staged", title: text.staged, count: counts.staged, color: GitPalette.staged)) }
        if counts.modified > 0 { pills.append(Pill(id: "modified", title: text.modified, count: counts.modified, color: GitPalette.modified)) }
        if counts.untracked > 0 { pills.append(Pill(id: "untracked", title: text.untracked, count: counts.untracked, color: GitPalette.untracked)) }
        if counts.isClean { pills.append(Pill(id: "clean", title: text.clean, count: nil, color: ZenithStatus.success)) }
        if snapshot.stash > 0 { pills.append(Pill(id: "stash", title: text.stash, count: snapshot.stash, color: ZenithIsland.secondary)) }
        return pills
    }

    var body: some View {
        let pills = pills
        HStack(spacing: 5) {
            ForEach(pills) { pill in
                GitPill(title: pill.title, count: pill.count, color: pill.color, clean: pill.id == "clean")
                    .transition(GitMotion.pill(reduceMotion: reduceMotion))
            }
        }
        .frame(height: 20)
        .animation(GitMotion.list(reduceMotion: reduceMotion), value: pills.map(\.id))
    }
}

private struct GitPill: View {
    let title: String
    let count: Int?
    let color: Color
    var clean = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            if clean {
                Image(systemName: "checkmark").font(.system(size: 8.5, weight: .bold))
            }
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
            if let count {
                Text("\(count)")
                    .font(ZenithType.mono(10.5, weight: .semibold))
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                    .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: count)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .frame(height: 18)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 0.75))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

private struct GitCommitLine: View {
    let snapshot: GitSnapshot
    let text: ZenithGitStrings
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if let commit = snapshot.lastCommit {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 6) {
                    Text(commit.shortSHA)
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(NotchModule.git.zenithTint.opacity(0.85))
                    Text(GitFormat.subject(commit.subject))
                        .font(.system(size: 11.5))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Text(GitFormat.relative(commit.date, language: l10n.language.rawValue, now: context.date))
                        .font(ZenithType.mono(10))
                        .foregroundStyle(ZenithIsland.meta)
                        .lineLimit(1)
                        .fixedSize()
                }
                .help(commit.subject)
                .accessibilityElement(children: .combine)
            }
            .frame(height: 15)
        } else if snapshot.branch.isUnborn {
            Text(text.noCommits)
                .font(.system(size: 11.5))
                .foregroundStyle(ZenithIsland.tertiary)
                .frame(height: 15)
        }
    }
}

/// The first changed files: the status letter in its colour and the path,
/// its middle cut out when long.
private struct GitFileList: View {
    let snapshot: GitSnapshot
    let text: ZenithGitStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let listed = snapshot.listed
        let more = snapshot.changes.count - listed.count
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(listed) { change in
                    GitFileRow(change: change, text: text)
                        .transition(GitMotion.row(reduceMotion: reduceMotion))
                }
                if more > 0 {
                    Text(text.moreFiles.replacingOccurrences(of: "%@", with: "\(more)"))
                        .font(ZenithType.mono(10))
                        .foregroundStyle(ZenithIsland.meta)
                        .padding(.leading, 20)
                        .frame(height: GitPageMetrics.rowHeight)
                        .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(more)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(GitMotion.list(reduceMotion: reduceMotion), value: listed.map(\.id))
    }
}

private struct GitFileRow: View {
    let change: GitFileChange
    let text: ZenithGitStrings

    var body: some View {
        let color = GitPalette.color(change)
        HStack(spacing: 6) {
            Text(change.letter)
                .font(ZenithType.mono(10.5, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(change.path)
                .font(ZenithType.mono(10.5))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(height: GitPageMetrics.rowHeight)
        .help(change.originalPath.map { $0 + " → " + change.path } ?? change.path)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind + ", " + change.path)
    }

    private var kind: String {
        if change.isConflicted { return text.conflicts }
        if change.isUntracked { return text.untracked }
        return change.isStaged ? text.staged : text.modified
    }
}
