// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: a live call in the closed island (MeetingsService). Left of
// the camera, the provider's glyph in its colour and the meeting's title;
// right of it, how long the call has run, a green dot while a camera is on,
// and the mic: white while live, red and slashed while muted, a click
// mutes or unmutes it through Mic Mute. A click elsewhere brings the call's
// app forward. In the floating capsule, all of it in one row. The widths
// do not follow the clock, the dot or the mute, so the island lays itself
// out once per call.

enum MeetingsStripLayout {
    static let titleFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let elapsedFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    static let capsuleTitleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let capsuleElapsedFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    static let glyphSize: CGFloat = 11
    static let micSize: CGFloat = 12
    static let micWidth: CGFloat = 16
    static let dotSize: CGFloat = 5
    static let spacing: CGFloat = 5
    /// Characters of the title the wing keeps.
    static let titleLimit = 16
    static let capsuleTitleLimit = 22
    /// The clock measured at its widest, so an hour-long call does not relayout.
    static let elapsedSample = "0:00:00"

    static func title(_ call: MeetingCall, limit: Int) -> String {
        MeetingsFormat.shortened(MeetingsFormat.title(call.meeting, text: ZenithStrings.meetings(L10n.shared.language)),
                                 limit: limit)
    }

    /// The wider side, measured as the strip draws it.
    static func stripWing(_ call: MeetingCall?, in geometry: NotchGeometry) -> CGFloat {
        let range = NotchWatchSupport.stripWingRange
        guard let call else { return range.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: range.lowerBound)
        let glyphInset = provisional.compactActivityEdgeInset(boxHeight: glyphSize, radius: 0)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = glyphInset + glyphSize + spacing + width(title(call, limit: titleLimit), font: titleFont)
        let right = textInset + width(elapsedSample, font: elapsedFont) + spacing + dotSize + spacing + micWidth
        return min(range.upperBound, max(left, right) + NotchTimerSupport.stripCameraGap)
    }

    /// The floating capsule's row: glyph, title, clock, dot and mic.
    static func capsuleSurface(_ call: MeetingCall?, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let call else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.spacing
            + width(title(call, limit: capsuleTitleLimit), font: capsuleTitleFont) + layout.groupSpacing
            + width(elapsedSample, font: capsuleElapsedFont) + spacing + dotSize + spacing + micWidth
        return layout.surface(content: content, maximum: layout.Maximum.calendar, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }
}

/// The provider's glyph in its colour.
private struct MeetingsGlyph: View {
    let provider: MeetingProvider
    let size: CGFloat

    var body: some View {
        Image(systemName: provider.symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(ZenithIslandPalette.color(hex: provider.tint))
    }
}

/// How long the call has run, the camera's dot and the mic.
private struct MeetingsCallControls: View {
    let call: MeetingCall
    let font: NSFont
    @ObservedObject private var meetings = MeetingsService.shared
    @ObservedObject private var mic = MicMuteService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = ZenithStrings.meetings(l10n.language)
        HStack(spacing: MeetingsStripLayout.spacing) {
            Text(call.since, style: .timer)
                .font(Font(font as CTFont))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .frame(width: MeetingsStripLayout.width(MeetingsStripLayout.elapsedSample, font: font), alignment: .trailing)
                .accessibilityLabel(text.elapsedLabel)
            Circle()
                .fill(ZenithStatus.success)
                .frame(width: MeetingsStripLayout.dotSize, height: MeetingsStripLayout.dotSize)
                .opacity(meetings.cameraInUse ? 1 : 0)
                .scaleEffect(meetings.cameraInUse || reduceMotion ? 1 : 0.2)
                .animation(reduceMotion ? IslandMotion.easeInOut(ZenithMotion.fast) : IslandMotion.spring(response: 0.32, damping: 0.8),
                           value: meetings.cameraInUse)
                .accessibilityHidden(!meetings.cameraInUse)
                .accessibilityLabel(text.cameraOn)
            micButton(text)
        }
    }

    @ViewBuilder
    private func micButton(_ text: ZenithMeetingsStrings) -> some View {
        let muted = mic.isMuted
        let glyph = Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
            .font(.system(size: MeetingsStripLayout.micSize, weight: .semibold))
            .foregroundStyle(muted ? ZenithStatus.error : Color.white.opacity(0.92))
            .contentTransition(.symbolEffect(.replace))
            .frame(width: MeetingsStripLayout.micWidth, height: MeetingsStripLayout.micWidth)
            .contentShape(Rectangle())
        if meetings.offersMute {
            Button { meetings.toggleMute() } label: { glyph }
                .buttonStyle(.plain)
                .help(muted ? text.unmute : text.mute)
                .accessibilityLabel(muted ? text.unmute : text.mute)
                .accessibilityValue(muted ? text.micMuted : text.micLive)
        } else {
            glyph.accessibilityLabel(muted ? text.micMuted : text.micLive)
        }
    }
}

struct MeetingsActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var meetings = MeetingsService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The call ending clears it before the strip has left.
        NotchStripHold(meetings.call, shows: meetings.call != nil) { call in
            if let call { strip(call) }
        }
    }

    private func strip(_ call: MeetingCall) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        return HStack(spacing: 0) {
            Button { meetings.focusCall() } label: {
                HStack(spacing: MeetingsStripLayout.spacing) {
                    MeetingsGlyph(provider: call.meeting.provider, size: MeetingsStripLayout.glyphSize)
                    Text(MeetingsStripLayout.title(call, limit: MeetingsStripLayout.titleLimit))
                        .font(Font(MeetingsStripLayout.titleFont as CTFont))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: MeetingsStripLayout.glyphSize, radius: 0))
                .frame(width: wing, height: height, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(MeetingsFormat.title(call.meeting, text: ZenithStrings.meetings(l10n.language)))
            .accessibilityValue(call.meeting.provider.name)
            Color.clear.frame(width: geometry.compactActivityCameraGap)
            MeetingsCallControls(call: call, font: MeetingsStripLayout.elapsedFont)
                .padding(.trailing, geometry.compactActivityEdgeInset(boxHeight: 8, radius: 0))
                .frame(width: wing, height: height, alignment: .trailing)
                .clipped()
        }
        .frame(height: height)
        .padding(.horizontal, geometry.compactActivityHorizontalPadding)
        .padding(.top, geometry.compactActivityTopPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ZenithStrings.meetings(l10n.language).title)
    }
}

/// The call in the floating capsule: glyph, title, clock, dot and mic in one row.
struct MeetingsCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var meetings = MeetingsService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(meetings.call, shows: meetings.call != nil) { call in
            if let call { row(call) }
        }
    }

    private func row(_ call: MeetingCall) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        return HStack(spacing: layout.groupSpacing) {
            Button { meetings.focusCall() } label: {
                HStack(spacing: layout.spacing) {
                    MeetingsGlyph(provider: call.meeting.provider, size: layout.symbolSize)
                        .frame(width: layout.symbolWidth)
                    Text(MeetingsStripLayout.title(call, limit: MeetingsStripLayout.capsuleTitleLimit))
                        .font(Font(MeetingsStripLayout.capsuleTitleFont as CTFont))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(MeetingsFormat.title(call.meeting, text: ZenithStrings.meetings(l10n.language)))
            .accessibilityValue(call.meeting.provider.name)
            Spacer(minLength: 0)
            MeetingsCallControls(call: call, font: MeetingsStripLayout.capsuleElapsedFont)
        }
        .padding(.leading, side + layout.endPadding)
        .padding(.trailing, side + layout.endPadding)
        .frame(width: size.width, height: geometry.stripHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ZenithStrings.meetings(l10n.language).title)
    }
}
