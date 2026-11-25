// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The watched sites in full, opened from Home’s Sites card: the sentence,
/// then every site, worst first, with its status, how fast it answered and
/// how its latest deploy went. A tap opens the site.
struct SitesSheet: View {
    let sites: PocketSites?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
        .foregroundStyle(K.fg)
        .presentationBackground(K.bg)
    }

    private func content(now: Date) -> some View {
        let list = PocketWatchtowerPresentation.sorted(sites?.sites ?? [])
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
                    Hero(eyebrow: "Sites", badge: PocketWatchtowerPresentation.sitesBadge(sites, now: now),
                         sentence: PocketWatchtowerPresentation.sitesSentence(sites, now: now))
                        .blurFade()
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Watching", trailing: PocketWatchtowerPresentation.checkedLine(sites))
                            .blurFade(delay: 0.08)
                        if list.isEmpty {
                            Text("Add the sites you’d want to hear about in Zenith on your Mac: Settings, iPhone & Watch, Watchtower.")
                                .font(K.sans(13)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                                .blurFade(delay: 0.12)
                        } else {
                            Rows {
                                ForEach(Array(list.enumerated()), id: \.element.id) { index, site in
                                    SiteRow(site: site, now: now, divider: index < list.count - 1)
                                        .blurFade(index: index, base: 0.12)
                                }
                            }
                        }
                        Text("Your Mac checks every 10 minutes while Zenith Pocket is on.")
                            .font(K.mono(11)).foregroundStyle(K.faint).padding(.horizontal, 4).padding(.top, 6)
                            .blurFade(delay: 0.2)
                    }
                    .padding(.horizontal, 20).padding(.top, 26)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// One site: a glowing status dot, its name and what’s known about it, the
/// labelled status and the number behind it.
private struct SiteRow: View {
    let site: PocketSites.Site
    let now: Date
    let divider: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        let badge = PocketWatchtowerPresentation.siteBadge(site)
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                if let url = URL(string: site.url) { openURL(url) }
            } label: {
                HStack(spacing: 12) {
                    WatchtowerDot(color: K.color(badge.tone), live: site.status == .down)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name).font(K.sans(15, bold: true)).lineLimit(1).truncationMode(.middle)
                        Text(PocketWatchtowerPresentation.siteMeta(site, now: now))
                            .font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Status(badge: badge)
                        if let value = PocketWatchtowerPresentation.siteValue(site) {
                            Text(value).font(K.mono(11)).foregroundStyle(K.faint)
                                .countingNumber(Double(site.latencyMs ?? site.httpStatus ?? 0))
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .pressable()
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the site")
            if divider { Rectangle().fill(K.border).frame(height: 1).padding(.leading, 58) }
        }
    }
}

/// A status dot that glows in its colour; a site that is down breathes.
struct WatchtowerDot: View {
    let color: Color
    var live = false
    @State private var bright = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .shadow(color: color.opacity(bright ? 0.9 : 0.6), radius: bright ? 6 : 4)
            .accessibilityHidden(true)
            .onAppear {
                guard live, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { bright = true }
            }
    }
}
