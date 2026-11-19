// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: colours of a deployment's state, from the Style Kit palette:
/// waiting is info blue, building is progress purple, ready is emerald,
/// failed is red, and a canceled one is grey.
enum VercelStyle {
    static func tint(_ state: VercelSupport.State) -> Color {
        switch state {
        case .queued: return ZenithStatus.info
        case .initializing, .building: return ZenithStatus.progress
        case .ready: return ZenithStatus.success
        case .error: return ZenithStatus.error
        case .canceled, .unknown: return ZenithStatus.neutral
        }
    }

    static func relative(_ date: Date, language: AppLanguage, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}

/// A state's mark, breathing while the deployment is on its way unless
/// Reduce Motion is on.
struct VercelStateMark: View {
    let symbol: String
    let size: CGFloat
    let tint: Color
    let pulsing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.pulse, options: .repeating, isActive: pulsing && !reduceMotion)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

// MARK: Page

/// Zenith fork: the Vercel page in the Dynamic Island: the latest deployments
/// across the personal account and its teams, newest first.
struct NotchVercelView: View {
    let size: CGSize
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = VercelService.shared

    private var text: ZenithVercelStrings { ZenithStrings.vercel(l10n.language) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear { service.viewAppeared() }
    }

    @ViewBuilder private var content: some View {
        switch (service.state, service.deployments.isEmpty) {
        case (.missingToken, _):
            NotchEmptyView(symbol: "key", message: text.missingToken)
        case (.unauthorized, _):
            NotchEmptyView(symbol: "key", message: text.unauthorized)
        case (.failed, true):
            NotchEmptyView(symbol: "wifi.exclamationmark", message: text.failed) {
                NotchPillButton(title: text.retry, prominent: true) { service.refresh(force: true) }
            }
        case (.ready, true):
            NotchEmptyView(symbol: VercelSupport.symbol, message: text.empty)
        case (_, true):
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case (_, false):
            list
        }
    }

    private var list: some View {
        let mixes = VercelSupport.mixesScopes(service.deployments)
        // More deployments than the page holds: scroll, with the island's soft edges.
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                header
                ForEach(service.deployments) { deployment in
                    VercelDeploymentRow(deployment: deployment, text: text, language: l10n.language,
                                        showsScope: mixes)
                }
            }
            .padding(.bottom, 8)
        }
        .notchScrollEdgeFade()
    }

    private var header: some View {
        let building = service.deployments.filter(\.state.inProgress).count
        return HStack(spacing: 6) {
            if building > 0 {
                VercelStateMark(symbol: VercelSupport.symbol, size: 10, tint: ZenithStatus.progress, pulsing: true)
                Text("\(text.building) · \(building)")
                    .font(ZenithType.caption.weight(.semibold))
                    .foregroundStyle(ZenithStatus.progress)
            }
            Spacer(minLength: 0)
            Button { service.refresh(force: true) } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(text.retry)
            .accessibilityLabel(text.retry)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
}

/// One deployment: its state, project and target, the branch and commit,
/// and how long ago. A click opens the deployment, or its build log on the
/// dashboard while it builds or after it failed.
private struct VercelDeploymentRow: View {
    let deployment: VercelSupport.Deployment
    let text: ZenithVercelStrings
    let language: AppLanguage
    let showsScope: Bool
    @State private var hovered = false

    var body: some View {
        Button {
            if let url = deployment.openURL { NSWorkspace.shared.open(url) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VercelStateMark(symbol: deployment.state.symbol, size: 13, tint: VercelStyle.tint(deployment.state),
                                pulsing: deployment.state.inProgress)
                    .frame(width: 18, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(deployment.project).font(ZenithType.emphasis).lineLimit(1).truncationMode(.tail)
                        Text(deployment.isProduction ? text.production : text.preview)
                            .font(ZenithType.caption)
                            .foregroundStyle(deployment.isProduction ? .primary : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(deployment.isProduction ? 0.14 : 0.07)))
                            .lineLimit(1)
                            .fixedSize()
                        Spacer(minLength: 4)
                        Text(VercelStyle.relative(deployment.created, language: language))
                            .font(ZenithType.caption).monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    HStack(spacing: 4) {
                        Text(text.label(deployment.state))
                            .foregroundStyle(VercelStyle.tint(deployment.state))
                            .fixedSize()
                        if let detail = detail {
                            Text("· " + detail).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                        }
                    }
                    .font(ZenithType.caption)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                .fill(Color.primary.opacity(hovered ? 0.07 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast)), value: hovered)
        .help(deployment.host ?? deployment.project)
        .accessibilityElement(children: .combine)
    }

    /// The team when the list mixes several, then the branch and the commit's first line.
    private var detail: String? {
        let parts = [showsScope ? deployment.scope : nil, deployment.branch, deployment.commitTitle].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: Settings

/// Zenith fork: the Vercel section's options: the access token, kept in a
/// private file (ZenithSecretStore), whether builds show in the closed island,
/// and whether a failed build sends a notification.
struct VercelSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = VercelService.shared
    @AppStorage(DefaultsKey.notchVercelActivity) private var liveActivity = true
    @AppStorage(DefaultsKey.notchVercelFailureAlerts) private var failureAlerts = false
    @State private var draft = ""
    @State private var rejected = false

    private var text: ZenithVercelStrings { ZenithStrings.vercel(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.tokenTitle).font(ZenithType.emphasis)
            if service.hasToken {
                HStack {
                    Label(text.tokenSaved, systemImage: "checkmark.seal.fill")
                        .foregroundStyle(ZenithStatus.success)
                    Spacer()
                    Button(text.remove, role: .destructive) { service.removeToken() }
                }
                if service.state == .unauthorized {
                    Text(text.unauthorized).font(ZenithType.caption).foregroundStyle(ZenithStatus.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack {
                    SecureField(text.tokenPlaceholder, text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                    Button(text.save, action: save).disabled(draft.isEmpty)
                }
                if rejected {
                    Text(text.tokenRejected).font(ZenithType.caption).foregroundStyle(ZenithStatus.error)
                }
            }
            Text(text.tokenCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().padding(.vertical, 4)
            ZenithSwitchRow(text.liveActivity, isOn: $liveActivity) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.liveActivity)
                    Text(text.liveActivityCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            let alerts = ZenithStrings.vercelAlerts(l10n.language)
            ZenithSwitchRow(alerts.failureAlerts, isOn: $failureAlerts) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alerts.failureAlerts)
                    Text(alerts.failureAlertsCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onChange(of: failureAlerts) { _, isOn in
                // Asked only when the person turns the alerts on.
                if isOn { Notifier.requestPermission() }
                service.syncFailureAlerts()
            }
        }
        .onAppear { service.loadTokenIfNeeded() }
    }

    private func save() {
        guard VercelSupport.isPlausibleToken(draft) else { rejected = true; return }
        rejected = false
        if service.saveToken(draft) { draft = "" }
    }
}

// MARK: Closed island

/// Zenith fork: a Vercel build in the closed island, around the camera: the
/// state's mark and word on the left, the project on the right, each
/// anchored to its own edge so the silhouette's curve decides the margin.
struct VercelActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var vercel = VercelService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The result going clears the activity before the strip has left.
        NotchStripHold(vercel.activity, shows: vercel.activity != nil) { activity in
            if let activity { strip(activity) }
        }
    }

    private func strip(_ activity: VercelSupport.Activity) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let icon = VercelActivityLayout.iconSize(height: height)
        let tint = VercelStyle.tint(activity.state)
        let label = VercelActivityLayout.label(activity, language: l10n.language)
        let detail = VercelActivityLayout.detail(activity)
        return Button { service.openActivity(.vercel) } label: {
            HStack(spacing: 0) {
                HStack(spacing: VercelActivityLayout.markSpacing) {
                    if wing >= 28 {
                        VercelStateMark(symbol: VercelActivityLayout.symbol(activity), size: icon, tint: tint,
                                        pulsing: activity.state.inProgress)
                    }
                    if wing >= VercelActivityLayout.labelledWing {
                        Text(label)
                            .font(Font(VercelActivityLayout.labelFont as CTFont))
                            .foregroundStyle(tint)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2))
                .frame(width: wing, height: height, alignment: .leading)
                .clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                Group {
                    if wing >= 36 {
                        Text(detail)
                            .font(Font(VercelActivityLayout.projectFont as CTFont))
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
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
        .accessibilityLabel("Vercel")
        .accessibilityValue("\(label), \(detail)")
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

/// Zenith fork: a Vercel build in the floating capsule: mark, word and
/// project in one row. A click on the capsule opens the Vercel page.
struct VercelCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var vercel = VercelService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(vercel.activity, shows: vercel.activity != nil) { activity in
            if let activity { row(activity) }
        }
    }

    private func row(_ activity: VercelSupport.Activity) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        let tint = VercelStyle.tint(activity.state)
        let label = VercelActivityLayout.label(activity, language: l10n.language)
        let detail = VercelActivityLayout.detail(activity)
        return HStack(spacing: layout.spacing) {
            VercelStateMark(symbol: VercelActivityLayout.symbol(activity), size: layout.symbolSize, tint: tint,
                            pulsing: activity.state.inProgress)
                .frame(width: layout.symbolWidth)
            Text(label)
                .font(Font(layout.titleFont as CTFont))
                .foregroundStyle(tint)
                .lineLimit(1)
                .fixedSize()
            Text(detail)
                .font(Font(layout.detailFont as CTFont))
                .lineLimit(1).truncationMode(.tail)
                .padding(.leading, layout.groupSpacing - layout.spacing)
        }
        .padding(.leading, side + layout.endPadding)
        .padding(.trailing, side + layout.endPadding)
        .frame(width: size.width, height: geometry.stripHeight)
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vercel")
        .accessibilityValue("\(label), \(detail)")
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
