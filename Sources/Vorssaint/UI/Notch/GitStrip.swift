// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the current repository's branch in the closed island, when
// the person turns it on: the module's glyph left of the camera, the branch
// right of it with an amber dot while anything is uncommitted, on the
// watch's wings; in the floating capsule, all three in one row. The branch
// crossfades when it changes, the dot scales in and out; a click opens the
// Git page. Reduce Motion fades.

enum GitStripLayout {
    static let branchFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    static let capsuleBranchFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let glyphSize: CGFloat = 11
    static let dotSize: CGFloat = 5
    static let dotSpacing: CGFloat = 5
    /// Characters of the branch the strip keeps, its middle cut out beyond.
    static let branchLimit = 16

    static func branch(_ indicator: GitIndicator) -> String {
        GitFormat.middleTruncated(indicator.branch, limit: branchLimit)
    }

    /// The wider side, measured as the strip draws it, with the clearance
    /// from the silhouette's curve and air beside the camera.
    static func stripWing(_ indicator: GitIndicator?, in geometry: NotchGeometry) -> CGFloat {
        let range = NotchWatchSupport.stripWingRange
        guard let indicator else { return range.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: range.lowerBound)
        let glyphInset = provisional.compactActivityEdgeInset(boxHeight: glyphSize, radius: 0)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = glyphInset + glyphSize + 2
        let right = textInset + width(branch(indicator), font: branchFont) + dotSpacing + dotSize
        return min(range.upperBound, max(left, right) + NotchTimerSupport.stripCameraGap)
    }

    /// The floating capsule's row: the glyph, the branch and the dot.
    static func capsuleSurface(_ indicator: GitIndicator?, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let indicator else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.spacing + width(branch(indicator), font: capsuleBranchFont)
            + dotSpacing + dotSize
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func accessibilityValue(_ indicator: GitIndicator, language: AppLanguage) -> String {
        let text = ZenithStrings.git(language)
        let branch = text.branchValue.replacingOccurrences(of: "%@", with: indicator.branch)
        return indicator.dirty ? branch + ", " + text.dirty : branch
    }
}

/// The branch and, while anything is uncommitted, its dot.
private struct GitStripBranch: View {
    let indicator: GitIndicator
    let font: NSFont
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let branch = GitStripLayout.branch(indicator)
        HStack(spacing: GitStripLayout.dotSpacing) {
            Text(branch)
                .font(Font(font as CTFont))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .id(branch)
                .transition(GitMotion.row(reduceMotion: reduceMotion))
            if indicator.dirty {
                Circle()
                    .fill(ZenithStatus.warning)
                    .frame(width: GitStripLayout.dotSize, height: GitStripLayout.dotSize)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? IslandMotion.easeInOut(ZenithMotion.fast) : IslandMotion.spring(response: 0.32, damping: 0.8),
                   value: indicator)
    }
}

struct GitActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var git = GitService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The branch going clears it before the strip has left.
        NotchStripHold(git.indicator, shows: git.indicator != nil) { indicator in
            if let indicator { strip(indicator) }
        }
    }

    private func strip(_ indicator: GitIndicator) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        return Button { service.openActivity(NotchCompactActivity.git.module) } label: {
            HStack(spacing: 0) {
                Image(systemName: GitSupportSymbols.module)
                    .font(.system(size: GitStripLayout.glyphSize, weight: .semibold))
                    .foregroundStyle(NotchModule.git.zenithTint)
                    .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: GitStripLayout.glyphSize, radius: 0))
                    .frame(width: wing, height: height, alignment: .leading)
                    .clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                GitStripBranch(indicator: indicator, font: GitStripLayout.branchFont)
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
        .accessibilityLabel(ZenithStrings.git(l10n.language).title)
        .accessibilityValue(GitStripLayout.accessibilityValue(indicator, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

/// The branch in the floating capsule: the glyph, the branch and the dot in one row.
struct GitCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var git = GitService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(git.indicator, shows: git.indicator != nil) { indicator in
            if let indicator { row(indicator) }
        }
    }

    private func row(_ indicator: GitIndicator) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        return HStack(spacing: layout.spacing) {
            Image(systemName: GitSupportSymbols.module)
                .font(.system(size: layout.symbolSize, weight: .semibold))
                .foregroundStyle(NotchModule.git.zenithTint)
                .frame(width: layout.symbolWidth)
            GitStripBranch(indicator: indicator, font: GitStripLayout.capsuleBranchFont)
        }
        .padding(.leading, side + layout.endPadding)
        .padding(.trailing, side + layout.endPadding)
        .frame(width: size.width, height: geometry.stripHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.git(l10n.language).title)
        .accessibilityValue(GitStripLayout.accessibilityValue(indicator, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
