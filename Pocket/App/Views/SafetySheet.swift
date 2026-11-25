// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The safety of the person's work in full, opened from Home's Safety card:
/// the sentence, the repos whose work never left the Mac (riskiest first),
/// the backup, and the disk.
struct SafetySheet: View {
    let safety: PocketSafety?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
        .foregroundStyle(K.fg)
        .presentationBackground(K.bg)
    }

    private func content(now: Date) -> some View {
        let repos = PocketWatchtowerPresentation.sorted(safety?.repos ?? []).filter {
            PocketWatchtowerPresentation.risk($0) != .none
        }
        let more = max(0, (safety?.reposAtRisk ?? repos.count) - repos.count)
        return ZStack {
            K.bg.ignoresSafeArea()
            Ambient().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(K.sans(15, bold: true)).foregroundStyle(K.fg)
                    }
                    .padding(.horizontal, 24).padding(.top, 18)
                    Hero(eyebrow: "Safety", badge: PocketWatchtowerPresentation.safetyBadge(safety, now: now),
                         sentence: PocketWatchtowerPresentation.safetySentence(safety, now: now),
                         footnote: safety?.scannedAt.map { "scanned " + PocketPresentation.ago($0, now: now) })
                        .blurFade()
                    if let safety {
                        sections(safety, repos: repos, more: more, now: now)
                            .padding(.horizontal, 20).padding(.top, 26)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sections(_ safety: PocketSafety, repos: [PocketSafety.Repo], more: Int, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Not pushed yet", trailing: safety.folder)
                .blurFade(delay: 0.08)
            if repos.isEmpty {
                Rows {
                    Row(symbol: "checkmark", title: "Everything is pushed", meta: "no repo is waiting on you", divider: false) {
                        WatchtowerDot(color: K.emerald)
                    }
                }
                .blurFade(delay: 0.12)
            } else {
                Rows {
                    ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
                        RepoRow(repo: repo, divider: index < repos.count - 1)
                            .blurFade(index: index, base: 0.12)
                    }
                }
                if more > 0 {
                    Text("and \(more) more on your Mac")
                        .font(K.mono(11)).foregroundStyle(K.faint).padding(.horizontal, 4)
                }
            }

            SectionLabel(text: "Backup").padding(.top, 16)
                .blurFade(delay: 0.2)
            BackupCard(safety: safety, now: now)
                .blurFade(delay: 0.24)

            if let disk = safety.diskFreePercent {
                SectionLabel(text: "Disk", trailing: PocketWatchtowerPresentation.diskLine(disk)).padding(.top, 16)
                    .blurFade(delay: 0.28)
                let tone = PocketWatchtowerPresentation.diskTone(disk)
                Meter(value: Double(disk) / 100, tint: tone == .plain ? K.muted : K.color(tone))
                    .padding(.horizontal, 4)
                    .blurFade(delay: 0.32)
            }
        }
    }
}

/// One repo: a dot in its risk's colour, its name and what's waiting.
private struct RepoRow: View {
    let repo: PocketSafety.Repo
    let divider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                WatchtowerDot(color: K.color(PocketWatchtowerPresentation.repoTone(repo)), live: !repo.hasRemote)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name).font(K.sans(15, bold: true)).lineLimit(1)
                    Text(PocketWatchtowerPresentation.repoMeta(repo))
                        .font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if repo.path != repo.name {
                    Text((repo.path as NSString).deletingLastPathComponent)
                        .font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            if divider { Rectangle().fill(K.border).frame(height: 1).padding(.leading, 58) }
        }
    }
}

/// Time Machine: a card edged in its status colour when it needs the person.
private struct BackupCard: View {
    let safety: PocketSafety
    let now: Date

    var body: some View {
        let tone = PocketWatchtowerPresentation.backupTone(safety, now: now)
        let tint = K.color(tone)
        let flagged = tone == .alert || tone == .attention
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        HStack(spacing: 12) {
            Image(systemName: flagged ? "externaldrive.badge.xmark" : "externaldrive.badge.checkmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tone == .quiet ? K.muted : tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(PocketWatchtowerPresentation.backupTitle(safety, now: now)).font(K.sans(15, bold: true))
                Text(PocketWatchtowerPresentation.backupMeta(safety, now: now)).font(K.mono(11)).foregroundStyle(K.faint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(K.card, in: shape)
        .overlay(shape.strokeBorder(flagged ? tint.opacity(0.3) : K.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
