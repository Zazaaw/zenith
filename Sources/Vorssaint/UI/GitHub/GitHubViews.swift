// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the GitHub page in the Dynamic Island: pull requests waiting
/// for the person's review, then their own, each with its checks.
struct NotchGitHubView: View {
    let size: CGSize
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = GitHubService.shared

    private var text: ZenithGitHubStrings { ZenithStrings.gitHub(l10n.language) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { service.viewAppeared() }
    }

    @ViewBuilder private var content: some View {
        switch (service.state, service.inbox) {
        case (.missingCLI, _):
            NotchEmptyView(symbol: GitHubSupport.symbol, message: text.missingCLI)
        case (.notSignedIn, _):
            NotchEmptyView(symbol: "person.crop.circle.badge.questionmark", message: text.notSignedIn) {
                NotchPillButton(title: text.retry, prominent: true) { service.refresh(force: true) }
            }
        case (.failed, nil):
            NotchEmptyView(symbol: "wifi.exclamationmark", message: text.failed) {
                NotchPillButton(title: text.retry, prominent: true) { service.refresh(force: true) }
            }
        case (_, nil):
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case (_, let inbox?):
            list(inbox)
        }
    }

    private func list(_ inbox: GitHubSupport.Inbox) -> some View {
        // Two groups can hold more than the page: scroll, with the island's soft edges.
        // Two groups of rows parted by hairlines, a full-width line between the groups.
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header(text.reviewRequested, count: inbox.reviewCount, refresh: true)
                if inbox.reviewRequested.isEmpty {
                    empty(text.nothingToReview)
                } else {
                    rows(inbox.reviewRequested, showsAuthor: true)
                }
                ZenithBentoDivider(.horizontal, gap: 17)
                header(text.yourPullRequests, count: inbox.mineCount, refresh: false)
                if inbox.mine.isEmpty {
                    empty(text.noneOpen)
                } else {
                    rows(inbox.mine, showsAuthor: false)
                }
            }
            .padding(.bottom, 8)
        }
        .notchScrollEdgeFade()
    }

    private func rows(_ pullRequests: [GitHubSupport.PullRequest], showsAuthor: Bool) -> some View {
        ForEach(Array(pullRequests.enumerated()), id: \.element.id) { index, pullRequest in
            if index > 0 { ZenithBentoDivider(.horizontal).padding(.horizontal, 8) }
            GitHubPullRequestRow(pullRequest: pullRequest, text: text, language: l10n.language, showsAuthor: showsAuthor)
        }
    }

    private func header(_ title: String, count: Int, refresh: Bool) -> some View {
        ZenithBentoHeader(label: title) {
            HStack(spacing: 6) {
                ZenithBentoMeta(text: "\(count)")
                if refresh {
                    Button { service.refresh(force: true) } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium)).zenithIslandGlyph()
                            .frame(width: 22, height: 22).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .zenithIslandHoverTracked()
                    .help(text.retry)
                    .accessibilityLabel(text.retry)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private func empty(_ message: String) -> some View {
        Text(message)
            .font(ZenithType.footnote)
            .foregroundStyle(ZenithIsland.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }
}

/// One pull request: its checks, title, repository and number, and how long
/// since it changed. A click opens it on GitHub.
private struct GitHubPullRequestRow: View {
    let pullRequest: GitHubSupport.PullRequest
    let text: ZenithGitHubStrings
    let language: AppLanguage
    let showsAuthor: Bool
    @State private var hovered = false

    var body: some View {
        Button { NSWorkspace.shared.open(pullRequest.url) } label: {
            HStack(alignment: .top, spacing: 8) {
                // The checks as a dot in their colour, glowing while they run; the detail line names them.
                ZenithStatusDot(color: Self.tint(pullRequest.checks), live: pullRequest.checks == .pending)
                    .frame(height: 18)
                    .help(text.label(pullRequest.checks))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(pullRequest.title).font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 4)
                        ZenithBentoMeta(text: VercelStyle.relative(pullRequest.updated, language: language))
                    }
                    Text(detail)
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(ZenithIsland.meta)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                .fill(hovered ? ZenithIsland.rowHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast)), value: hovered)
        .accessibilityElement(children: .combine)
    }

    /// `owner/repo #12`, then a draft's word, the author (for a review) and the checks.
    private var detail: String {
        var parts = ["\(pullRequest.repository) #\(pullRequest.number)"]
        if pullRequest.isDraft { parts.append(text.draft) }
        if showsAuthor, let author = pullRequest.author { parts.append("@" + author) }
        if pullRequest.checks != .none { parts.append(text.label(pullRequest.checks)) }
        return parts.joined(separator: " · ")
    }

    /// Passing checks are emerald, failing red, running purple, none grey.
    static func tint(_ checks: GitHubSupport.Checks) -> Color {
        switch checks {
        case .success: return ZenithStatus.success
        case .failure: return ZenithStatus.error
        case .pending: return ZenithStatus.progress
        case .none: return ZenithStatus.neutral
        }
    }
}

/// Zenith fork: the GitHub section's options: which `gh` Zenith uses and
/// who it is signed in as, or a way to look again for one outside the
/// usual folders.
struct GitHubSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = GitHubService.shared

    private var text: ZenithGitHubStrings { ZenithStrings.gitHub(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let executable = service.executable ?? GitHubCLI.installed() {
                Label(text.cliFound(executable.path), systemImage: "checkmark.seal.fill")
                    .foregroundStyle(ZenithStatus.success)
                if let login = service.inbox?.login {
                    Text(text.signedIn(login)).font(ZenithType.footnote).foregroundStyle(.secondary)
                } else if service.state == .notSignedIn {
                    Text(text.notSignedIn).font(ZenithType.footnote).foregroundStyle(ZenithStatus.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack {
                    Label(text.cliMissing, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(ZenithStatus.warning)
                    Spacer()
                    if service.lookingAgain { ProgressView().controlSize(.small) }
                    Button(text.lookAgain) { service.lookAgain() }.disabled(service.lookingAgain)
                }
                Text(text.missingCLI).font(ZenithType.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(text.caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
