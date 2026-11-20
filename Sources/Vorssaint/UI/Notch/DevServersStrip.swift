// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the dev servers' count in the closed island, when the person
// turns it on: a small green dot left of the camera and how many run right of
// it, with the watch's wings; in the floating capsule, the dot and the count
// side by side. The count rolls its digits; a click opens the page.

enum DevServersStripLayout {
    static let countFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    static let capsuleCountFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let dotSize: CGFloat = 6

    /// The wider side, measured as the strip draws it, with the clearance
    /// from the silhouette's curve and air beside the camera.
    static func stripWing(_ count: Int?, in geometry: NotchGeometry) -> CGFloat {
        let lower = NotchWatchSupport.stripWingRange.lowerBound
        guard let count else { return lower }
        let provisional = geometry.compactWatchGeometry(wing: lower)
        let dotInset = provisional.compactActivityEdgeInset(boxHeight: dotSize * 2, radius: dotSize)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = dotInset + dotSize * 2
        let right = textInset + width("\(count)", font: countFont)
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }

    /// The floating capsule's row: the dot and the count.
    static func capsuleSurface(_ count: Int?, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let count else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.spacing + width("\(count)", font: capsuleCountFont)
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func accessibilityValue(_ count: Int, language: AppLanguage) -> String {
        ZenithStrings.devServers(language).running.replacingOccurrences(of: "%@", with: "\(count)")
    }
}

/// The count, its digits rolling as servers come and go.
private struct DevServersCount: View {
    let count: Int
    let font: NSFont
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(count)")
            .font(Font(font as CTFont))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: count)
    }
}

struct DevServersActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var servers = DevServersService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The last server going clears the count before the strip has left.
        NotchStripHold(servers.indicator, shows: servers.indicator != nil) { count in
            if let count { strip(count) }
        }
    }

    private func strip(_ count: Int) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let dot = DevServersStripLayout.dotSize
        return Button { service.openActivity(NotchCompactActivity.devServers.module) } label: {
            HStack(spacing: 0) {
                ZenithStatusDot(color: ZenithStatus.success, live: true, size: dot)
                    .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: dot * 2, radius: dot))
                    .frame(width: wing, height: height, alignment: .leading)
                    .clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                DevServersCount(count: count, font: DevServersStripLayout.countFont)
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
        .accessibilityLabel(ZenithStrings.devServers(l10n.language).title)
        .accessibilityValue(DevServersStripLayout.accessibilityValue(count, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

/// The count in the floating capsule: the dot and the number in one row.
struct DevServersCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var servers = DevServersService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(servers.indicator, shows: servers.indicator != nil) { count in
            if let count { row(count) }
        }
    }

    private func row(_ count: Int) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        return HStack(spacing: layout.spacing) {
            ZenithStatusDot(color: ZenithStatus.success, live: true, size: DevServersStripLayout.dotSize)
                .frame(width: layout.symbolWidth)
            DevServersCount(count: count, font: DevServersStripLayout.capsuleCountFont)
        }
        .padding(.leading, side + layout.endPadding)
        .padding(.trailing, side + layout.endPadding)
        .frame(width: size.width, height: geometry.stripHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.devServers(l10n.language).title)
        .accessibilityValue(DevServersStripLayout.accessibilityValue(count, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
