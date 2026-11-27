// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the agents activity in the closed island while a Claude Code
/// session needs the person (a permission prompt, or waiting for input), and
/// for a moment once a turn ends. It takes the place of the working agents'
/// reading in the same activity, `.agents`, never a second one beside it.
///
/// Around a camera: Claude's mark and an amber pulse (✓ in emerald once done)
/// left of it, "needs you · folder" right of it. The island lends the watch's
/// wider wings for the words. A floating capsule keeps upstream's agent strip.
enum NotchAgentsLiveStripLayout {
    static let labelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let markSpacing: CGFloat = 5
    static let dotSize: CGFloat = 5

    static func iconSize(height: CGFloat) -> CGFloat { min(13, NotchTimerSupport.stripIconSize(height: height)) }

    static func label(_ strip: ClaudeHooksSupport.Strip, language: AppLanguage) -> String {
        let text = ZenithStrings.claudeHooks(language)
        return strip.kind == .done ? text.doneShort : text.needsYou
    }

    static func detail(_ strip: ClaudeHooksSupport.Strip) -> String {
        strip.folder.isEmpty ? "" : " · " + String(strip.folder.prefix(24))
    }

    /// The wider side, measured as the strip draws it, with the clearance
    /// from the silhouette's curve and air beside the camera.
    static func stripWing(_ strip: ClaudeHooksSupport.Strip, language: AppLanguage, in geometry: NotchGeometry) -> CGFloat {
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let height = provisional.compactActivityContentHeight
        let icon = iconSize(height: height)
        let iconInset = provisional.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = iconInset + icon * 1.45 + markSpacing + dotSize * 2
        let right = textInset + CommandActivityLayout.width(label(strip, language: language) + detail(strip), font: labelFont)
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }
}

struct NotchAgentsLiveStrip: View {
    @ObservedObject var service: NotchService
    let strip: ClaudeHooksSupport.Strip
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let icon = NotchAgentsLiveStripLayout.iconSize(height: height)
        let wing = geometry.compactActivityWingWidth
        let iconInset = !geometry.compactActivityUsesFooter
            ? geometry.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2) : 0
        let textInset = !geometry.compactActivityUsesFooter
            ? geometry.compactActivityEdgeInset(boxHeight: 8, radius: 0) : 0
        let label = NotchAgentsLiveStripLayout.label(strip, language: l10n.language)
        HStack(spacing: 0) {
            Button { service.openActivity(.agents) } label: {
                HStack(spacing: NotchAgentsLiveStripLayout.markSpacing) {
                    NotchAgentMark(provider: .claude, size: icon)
                        .frame(width: icon * 1.45, height: icon * 1.45)
                    indicator
                }
                .padding(.leading, iconInset)
                .frame(width: wing, height: height, alignment: .leading)
                .contentShape(Rectangle())
            }
            Color.clear.frame(width: geometry.compactActivityCameraGap)
            Button { service.openActivity(.agents) } label: {
                HStack(spacing: 0) {
                    Text(label).foregroundStyle(ZenithIsland.primary)
                    Text(NotchAgentsLiveStripLayout.detail(strip)).foregroundStyle(ZenithIsland.secondary)
                }
                .font(Font(NotchAgentsLiveStripLayout.labelFont))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.opacity)
                .padding(.trailing, textInset)
                .frame(width: wing, height: height, alignment: .trailing)
                .contentShape(Rectangle())
            }
        }
        .frame(height: height)
        .padding(.horizontal, geometry.compactActivityHorizontalPadding)
        .padding(.top, geometry.compactActivityTopPadding)
        .buttonStyle(.plain)
        .animation(reduceMotion ? IslandMotion.easeInOut(0.2) : IslandMotion.spring(duration: 0.35, bounce: 0.2), value: strip.kind)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude")
        .accessibilityValue(label + NotchAgentsLiveStripLayout.detail(strip))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { service.openActivity(.agents) }
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }

    /// An amber pulse while the session waits; ✓ in emerald once it is done.
    /// The pulse is a layer animation, so the island's views never redraw for it.
    @ViewBuilder private var indicator: some View {
        ZStack {
            if strip.kind == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ZenithStatus.success)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            } else {
                NotchAgentPulse(tint: ZenithStatus.warning, size: NotchAgentsLiveStripLayout.dotSize)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .frame(width: NotchAgentsLiveStripLayout.dotSize * 2, height: NotchAgentsLiveStripLayout.dotSize * 2)
    }
}
