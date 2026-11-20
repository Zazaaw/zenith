// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Git widget for Customize Home. The repository's name,
/// the branch with ahead and behind, and the counts as small dots and
/// numbers (or Clean); a click opens the page. While it shows, the status is
/// read as often as on the page.
struct GitHomeWidget: View {
    let service: NotchService
    @ObservedObject private var git = GitService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: ZenithGitStrings { ZenithStrings.git(l10n.language) }

    var body: some View {
        ZenithHomeOpenButton(action: { service.select(.git) }) {
            VStack(alignment: .leading, spacing: 5) {
                ZenithHomeWidgetHeader(widget: .git, title: text.title) {
                    if let root = git.current?.root {
                        Text((root as NSString).lastPathComponent)
                            .font(ZenithType.mono(10, weight: .semibold))
                            .foregroundStyle(ZenithIsland.meta)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if let snapshot = git.snapshot, snapshot.location.root == git.current?.root {
                    content(snapshot)
                        .transition(GitMotion.row(reduceMotion: reduceMotion))
                } else {
                    Text(git.current == nil ? text.empty : " ")
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(GitMotion.list(reduceMotion: reduceMotion), value: git.snapshot?.location.root)
        }
        .onAppear { git.shown() }
        .onDisappear { git.hidden() }
    }

    private func content(_ snapshot: GitSnapshot) -> some View {
        let branch = snapshot.branch.head ?? snapshot.branch.shortOID ?? "HEAD"
        let counts = snapshot.counts
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.branch.isDetached ? "smallcircle.filled.circle" : GitSupportSymbols.branch)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(NotchModule.git.zenithTint)
                Text(branch)
                    .font(ZenithType.mono(11, weight: .medium))
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if snapshot.branch.upstream != nil {
                    Text("↑\(snapshot.branch.ahead ?? 0) ↓\(snapshot.branch.behind ?? 0)")
                        .font(ZenithType.mono(9.5))
                        .foregroundStyle(ZenithIsland.meta)
                        .fixedSize()
                        .accessibilityLabel([text.ahead.replacingOccurrences(of: "%@", with: "\(snapshot.branch.ahead ?? 0)"),
                                             text.behind.replacingOccurrences(of: "%@", with: "\(snapshot.branch.behind ?? 0)")]
                            .joined(separator: ", "))
                }
            }
            HStack(spacing: 8) {
                if counts.isClean {
                    count(nil, text.clean, ZenithStatus.success)
                } else {
                    if counts.conflicted > 0 { count(counts.conflicted, text.conflicts, GitPalette.conflicted) }
                    if counts.staged > 0 { count(counts.staged, text.staged, GitPalette.staged) }
                    if counts.modified > 0 { count(counts.modified, text.modified, GitPalette.modified) }
                    if counts.untracked > 0 { count(counts.untracked, text.untracked, GitPalette.untracked) }
                }
            }
        }
    }

    /// A dot in the kind's colour and its number; the word goes to VoiceOver
    /// and the tooltip, as the widget is narrow.
    private func count(_ value: Int?, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(value.map { "\($0)" } ?? title)
                .font(value == nil ? .system(size: 10.5, weight: .medium) : ZenithType.mono(10.5, weight: .semibold))
                .foregroundStyle(value == nil ? color : ZenithIsland.primary)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(value ?? 0)))
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: value)
        }
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { title + " \($0)" } ?? title)
    }
}
