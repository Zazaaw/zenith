// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// What a page's `Hero` tells the scroll view it sits in: its eyebrow and
/// badge, for the compact header, and where it ends in the page.
struct HeroSummary: Equatable, Sendable {
    var eyebrow: String
    var badge: PocketBadge?
    /// The hero's bottom edge in the page's own coordinates (`space`).
    var bottom: CGFloat

    /// The coordinate space of a tab's page, which moves with its content.
    static let space = "pocket.page"
}

/// The first hero in a page is the page's; any later one (a sheet's
/// preview, say) doesn't take over the header.
struct HeroSummaryKey: PreferenceKey {
    static let defaultValue: HeroSummary? = nil
    static func reduce(value: inout HeroSummary?, nextValue: () -> HeroSummary?) {
        if value == nil { value = nextValue() }
    }
}

/// A tab's scroll view. As the hero's sentence scrolls away, a compact
/// Liquid Glass header with its eyebrow and badge fades in at the top (a tap
/// on it scrolls back up). Pulling down past the hero draws the Satu Visual
/// star, which grows and turns with the pull, taps when far enough, and
/// spins while `refresh` runs once let go.
///
/// The pull is read from the scroll geometry rather than `.refreshable`,
/// whose system spinner SwiftUI can't hide.
struct TabScroll<Content: View>: View {
    /// Room above the compact header for something pinned there (the
    /// offline banner).
    var headerInset: CGFloat = 0
    let refresh: @MainActor () async -> Void
    @ViewBuilder let content: Content

    @State private var hero: HeroSummary?
    @State private var reading = ScrollReading()
    @State private var phase: ScrollPhase = .idle
    @State private var armed = false
    @State private var refreshing = false
    /// When the star began to spin; kept while it shrinks away after.
    @State private var spinSince: Date?
    @State private var position = ScrollPosition(edge: .top)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far to pull before letting go refreshes.
    private static var reach: CGFloat { 78 }
    /// The band the star spins in while refreshing.
    private static var band: CGFloat { 56 }

    var body: some View {
        let heroBottom = hero?.bottom
        ScrollView {
            content
                .coordinateSpace(.named(HeroSummary.space))
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .contentMargins(.top, refreshing ? Self.band : 0, for: .scrollContent)
        .onPreferenceChange(HeroSummaryKey.self) { hero = $0 }
        .onScrollGeometryChange(for: ScrollReading.self) { geometry in
            ScrollReading(geometry, heroBottom: heroBottom)
        } action: { _, next in
            reading = next
            guard phase == .interacting, !refreshing else { return }
            let far = next.pull >= Self.reach
            if far != armed {
                armed = far
                if far { Haptics.press() }
            }
        }
        .onScrollPhaseChange { old, new in
            phase = new
            if old == .interacting, new != .interacting {
                if armed, !refreshing { begin() }
                armed = false
            }
        }
        .overlay(alignment: .top) {
            PullStar(progress: refreshing ? 1 : min(1, reading.pull / Self.reach),
                     lit: armed || refreshing, pop: armed, spinSince: spinSince)
                .offset(y: ((refreshing ? Self.band : 0) + reading.pull) / 2 - PullStar.size / 2)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            if let hero {
                CompactHeader(summary: hero, progress: reading.header) {
                    Haptics.tap()
                    withAnimation(Motion.respecting(reduceMotion, Motion.reveal)) { position.scrollTo(edge: .top) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 2 + headerInset)
            }
        }
    }

    private func begin() {
        let started = Date()
        spinSince = started
        withAnimation(Motion.respecting(reduceMotion, Motion.spring)) { refreshing = true }
        Task {
            await refresh()
            // Long enough to read as a spin, even when the Mac is quick.
            let left = 0.9 - Date().timeIntervalSince(started)
            if left > 0 { try? await Task.sleep(for: .seconds(left)) }
            withAnimation(Motion.respecting(reduceMotion, Motion.spring)) { refreshing = false }
            try? await Task.sleep(for: .seconds(0.6))
            if !refreshing { spinSince = nil }
        }
    }
}

/// The scroll position as the header and the star use it, rounded so the
/// view only updates while one of them is moving.
private struct ScrollReading: Equatable {
    /// How far the compact header has come in, 0…1.
    var header: Double = 0
    /// How far the page is pulled down past its top, in points (≤ 160).
    var pull: CGFloat = 0

    init() {}

    init(_ geometry: ScrollGeometry, heroBottom: CGFloat?) {
        let y = geometry.contentOffset.y + geometry.contentInsets.top
        pull = min(160, max(0, -y)).rounded()
        // The header arrives as the sentence's last lines go under the top,
        // over 56 points.
        let start = max(24, (heroBottom ?? 180) - 120)
        let progress = min(1, max(0, (y - start) / 56))
        header = (progress * 50).rounded() / 50
    }
}

/// The compact header: the hero's eyebrow and badge in a glass capsule.
private struct CompactHeader: View {
    let summary: HeroSummary
    let progress: Double
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hidden = 1 - progress
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(summary.eyebrow.uppercased())
                    .font(K.sans(11, bold: true)).tracking(1.1).foregroundStyle(K.muted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let badge = summary.badge { Status(badge: badge) }
            }
            .blur(radius: reduceMotion ? 0 : hidden * 6)
            .padding(.leading, 18).padding(.trailing, summary.badge == nil ? 18 : 8)
            .frame(height: 40)
            .contentShape(Capsule())
            .glassEffect(.regular, in: Capsule())
        }
        .buttonStyle(PressStyle(haptic: false))
        .opacity(progress)
        .scaleEffect(reduceMotion ? 1 : 0.96 + 0.04 * progress, anchor: .top)
        .offset(y: reduceMotion ? 0 : -10 * hidden)
        .allowsHitTesting(progress > 0.6)
        .accessibilityHidden(progress < 0.6)
        .accessibilityLabel(summary.eyebrow)
        .accessibilityValue(summary.badge?.text ?? "")
        .accessibilityHint("Scrolls to the top")
    }
}

/// Pull to refresh's star: faint and small as the pull starts, full size and
/// full ink at the point where letting go refreshes, turning half a turn on
/// the way; then spinning until the refresh is done.
private struct PullStar: View {
    static let size: CGFloat = 22
    let progress: CGFloat
    /// Full ink: far enough to refresh, or refreshing.
    let lit: Bool
    /// A small swell the moment the pull is far enough.
    let pop: Bool
    let spinSince: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: spinSince == nil || reduceMotion)) { context in
            StarShape()
                .fill(lit ? K.fg : K.faint, style: FillStyle(eoFill: true))
                .frame(width: Self.size, height: Self.size)
                .rotationEffect(.degrees(reduceMotion ? 0 : angle(at: context.date)))
        }
        .animation(Motion.spring) { $0.scaleEffect(pop && !reduceMotion ? 1.12 : 1) }
        .scaleEffect(reduceMotion ? 1 : 0.35 + 0.65 * progress)
        .opacity(progress)
        .accessibilityHidden(true)
    }

    private func angle(at date: Date) -> Double {
        guard let spinSince else { return Double(progress) * 180 }
        return 180 + date.timeIntervalSince(spinSince) * 330
    }
}
