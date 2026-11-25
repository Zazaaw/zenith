// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: Settings → iPhone & Watch, Zenith Pocket's page, beside iPhone
/// Remote. The switch, the relay (the person's own Supabase project), pairing
/// by QR code as the phase asks, the paired phone and Watch, and what is
/// shared. The page only reads `PocketStore.shared` and writes
/// `PocketDefaults`; the service does the rest through the store's actions.
struct PocketSettingsPage: View {
    @ObservedObject private var store = PocketStore.shared
    @AppStorage(PocketDefaults.enabled) private var enabled = false
    @AppStorage(PocketDefaults.shareWallpaper) private var shareWallpaper = true
    @AppStorage(PocketDefaults.shareAgents) private var shareAgents = true
    @AppStorage(PocketDefaults.shareNowPlaying) private var shareNowPlaying = true
    @AppStorage(PocketDefaults.allowAnswers) private var allowAnswers = false

    @State private var draft = PocketRelayDraft(url: "", key: "")
    /// Set by Save: from then on the fields say what is wrong as they change.
    @State private var showsProblems = false
    @State private var confirmingUnpair = false
    @State private var previewState = PocketPreviewState.unpaired

    private let text = ZenithStrings.pocket(.enUS)

    private var stage: PocketPairingStage {
        PocketPairingStage.of(store.phase, enabled: enabled, hasRelay: store.relay != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle)
                PocketPreviewCard(state: $previewState,
                                  sharing: PocketPreviewSharing(wallpaper: shareWallpaper, agents: shareAgents,
                                                                nowPlaying: shareNowPlaying)) {
                    open(.zenithPocketPairing)
                } openSharing: {
                    open(.zenithPocketSharing)
                }
                Rectangle().fill(ZenithSurface.hairline).frame(height: 1)
                enableSection
                relaySection
                pairingSection
                sharingSection
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.5)
                PocketWatchtowerSection().disabled(!enabled).opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear {
            draft = PocketRelayDraft(store.relay)
            previewState = stage.previewState
        }
        .onChange(of: store.relay) { _, relay in
            draft = PocketRelayDraft(relay)
            showsProblems = false
        }
        .onChange(of: stage.previewState) { _, state in previewState = state }
        .onChange(of: stage) { _, stage in
            if case .paired = stage {} else { confirmingUnpair = false }
        }
    }

    private func open(_ anchor: SettingsSectionAnchor) {
        SettingsRouter.shared.request(FeatureSettingsDestination(.pocket, sectionAnchor: anchor))
    }

    // MARK: Turn on

    private var enableSection: some View {
        PocketSection {
            PocketRow {
                ZenithSwitchRow(text.enable, isOn: $enabled) {
                    rowTitle(text.enable, caption: text.enableCaption)
                }
            }
        }
        .zenithSectionAnchor(.zenithPocket)
    }

    // MARK: Relay

    private var relaySection: some View {
        PocketSection(symbol: "server.rack", title: text.relay, footnote: text.relayCaption) {
            PocketRow {
                field(text.projectURL, problem: showsProblems ? draft.urlProblem : nil) {
                    TextField(text.projectURL, text: $draft.url, prompt: Text(text.projectURLPrompt))
                        .textFieldStyle(.roundedBorder)
                        .font(ZenithType.mono(12))
                        .onSubmit(save)
                }
            }
            PocketDivider()
            PocketRow {
                field(text.anonKey, problem: showsProblems ? draft.keyProblem : nil) {
                    TextField(text.anonKey, text: $draft.key, prompt: Text(text.anonKeyPrompt), axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .font(ZenithType.mono(11))
                        .onSubmit(save)
                }
            }
            PocketDivider()
            PocketRow {
                relayStatus
                Spacer(minLength: 12)
                if store.relay != nil {
                    Button(text.forget) { store.saveRelay(nil) }
                }
                Button(text.save, action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.isEmpty || isSaved)
            }
            if let problem = store.problem, !problem.isEmpty {
                PocketDivider()
                PocketRow {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(ZenithType.caption)
                        .foregroundStyle(ZenithStatus.error)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .zenithSectionAnchor(.zenithPocketRelay)
    }

    /// Whether the fields hold the saved relay, read past spaces and slashes.
    private var isSaved: Bool {
        guard let saved = store.relay else { return false }
        return draft.relay == saved
    }

    @ViewBuilder private var relayStatus: some View {
        if isSaved {
            Label(text.saved, systemImage: "checkmark.circle.fill")
                .font(ZenithType.caption)
                .foregroundStyle(ZenithStatus.success)
        } else if store.relay != nil, !draft.isEmpty, case .paired = stage {
            caption(text.changeUnpairs)
        }
    }

    private func save() {
        guard let relay = draft.relay else {
            showsProblems = true
            return
        }
        showsProblems = false
        guard relay != store.relay else { return }
        store.saveRelay(relay)
    }

    private func field<Field: View>(_ label: String, problem: PocketRelayDraft.Problem?,
                                    @ViewBuilder _ content: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(ZenithType.rowTitle)
            content()
            if let problem {
                Text(PocketSettingsText.problem(problem, text))
                    .font(ZenithType.caption)
                    .foregroundStyle(ZenithStatus.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Pairing

    private var pairingSection: some View {
        let trailing: String? = {
            if case .paired = stage { return PocketSettingsText.link(store.link, text) }
            return nil
        }()
        return PocketSection(symbol: "qrcode", title: text.pairing, trailing: trailing) {
            switch stage {
            case .needs(let missing): needsRow(missing)
            case .starting:
                PocketRow {
                    ProgressView().controlSize(.small)
                    caption(text.starting)
                    Spacer()
                }
            case .unpaired:
                PocketRow {
                    rowTitle(text.pairPhone, caption: text.pairCaption)
                    Spacer(minLength: 12)
                    Button(text.pairPhone) { store.startPairing() }
                        .buttonStyle(.borderedProminent)
                }
            case .pairing(let url): pairingRow(url)
            case .paired(let lastSeen): paired(lastSeen)
            }
        }
        .zenithSectionAnchor(.zenithPocketPairing)
    }

    private func needsRow(_ missing: [PocketMissing]) -> some View {
        PocketRow {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(text.missingTitle).font(ZenithType.rowTitle)
                ForEach(missing, id: \.self) { item in
                    caption(item == .enable ? text.missingEnable : text.missingRelay)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func pairingRow(_ url: URL) -> some View {
        PocketRow {
            HStack(alignment: .top, spacing: 20) {
                PocketQRCode(url: url, label: text.codeLabel)
                VStack(alignment: .leading, spacing: 12) {
                    Text(text.scanTitle).font(ZenithType.emphasis)
                    VStack(alignment: .leading, spacing: 8) {
                        step(1, text.stepOpen)
                        step(2, text.stepPair)
                        step(3, text.stepPoint)
                    }
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        caption(text.scanWaiting)
                    }
                    caption(text.scanPrivate)
                    Spacer(minLength: 0)
                    Button(text.cancel) { store.cancelPairing() }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        }
    }

    /// The link and the last message, the phone and its Watch, then Unpair,
    /// which asks once in place.
    private func paired(_ lastSeen: Date?) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 0) {
                PocketRow {
                    Circle().fill(linkColor).frame(width: 8, height: 8).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PocketSettingsText.link(store.link, text)).font(ZenithType.rowTitle)
                        Text(PocketSettingsText.lastSeen(lastSeen, now: context.date, text))
                            .font(ZenithType.mono(10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if store.devices.isEmpty {
                    PocketDivider()
                    PocketRow { caption(text.noDevices); Spacer(minLength: 0) }
                }
                ForEach(store.devices, id: \.self) { device in
                    PocketDivider()
                    deviceRow(device, now: context.date)
                }
                PocketDivider()
                unpairRow
            }
        }
    }

    private var linkColor: Color {
        switch store.link {
        case .live: return ZenithStatus.success
        case .connecting: return ZenithStatus.progress
        case .offline: return Color.secondary
        }
    }

    private func deviceRow(_ device: PocketDeviceReport.Device, now: Date) -> some View {
        PocketRow {
            Image(systemName: device.kind == .watch ? "applewatch" : "iphone")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(ZenithType.rowTitle).lineLimit(1)
                Text(PocketSettingsText.caption(device, now: now, text))
                    .font(ZenithType.mono(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                if device.charging {
                    Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(ZenithStatus.success)
                }
                Text("\(min(max(device.percent, 0), 100))%")
                    .font(ZenithType.figures(15))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder private var unpairRow: some View {
        if confirmingUnpair {
            PocketRow {
                VStack(alignment: .leading, spacing: 3) {
                    Text(text.unpair(PocketSettingsText.phoneName(store.devices, text))).font(ZenithType.rowTitle)
                    caption(text.unpairCaption)
                }
                Spacer(minLength: 12)
                Button(text.cancel) { confirmingUnpair = false }
                Button(text.unpair, role: .destructive) {
                    confirmingUnpair = false
                    store.unpair()
                }
                .buttonStyle(.borderedProminent)
                .tint(ZenithStatus.error)
            }
        } else {
            PocketRow {
                Spacer()
                Button(text.unpair) { confirmingUnpair = true }
            }
        }
    }

    // MARK: Sharing

    private var sharingSection: some View {
        PocketSection(symbol: "square.and.arrow.up", title: text.sharing) {
            PocketRow {
                ZenithSwitchRow(text.shareWallpaper, isOn: $shareWallpaper) {
                    rowTitle(text.shareWallpaper, caption: text.shareWallpaperCaption)
                }
            }
            PocketDivider()
            PocketRow {
                ZenithSwitchRow(text.shareAgents, isOn: $shareAgents) {
                    rowTitle(text.shareAgents, caption: text.shareAgentsCaption)
                }
            }
            PocketDivider()
            PocketRow {
                ZenithSwitchRow(text.shareNowPlaying, isOn: $shareNowPlaying) {
                    rowTitle(text.shareNowPlaying, caption: text.shareNowPlayingCaption)
                }
            }
            PocketDivider()
            PocketRow {
                ZenithSwitchRow(text.allowAnswers, isOn: $allowAnswers) {
                    rowTitle(text.allowAnswers, caption: text.allowAnswersCaption)
                }
            }
        }
        .zenithSectionAnchor(.zenithPocketSharing)
    }

    // MARK: Pieces

    private func rowTitle(_ title: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(ZenithType.rowTitle)
            if let caption { self.caption(caption) }
        }
    }

    private func caption(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func step(_ number: Int, _ string: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(ZenithType.mono(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(ZenithSurface.tileFill))
                .overlay(Circle().strokeBorder(ZenithSurface.tileStroke))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(string)
                .font(ZenithType.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - QR code

/// The pairing code, made once per URL, on a white tile whatever the
/// appearance, at a whole number of points per module and never smoothed.
private struct PocketQRCode: View {
    let url: URL
    let label: String
    @State private var code: (url: URL, image: CGImage, modules: Int)?

    var body: some View {
        let side = code.map { PocketQR.side(modules: $0.modules, fitting: 232) } ?? 232
        Group {
            if let code, code.url == url {
                Image(decorative: code.image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .accessibilityLabel(label)
            } else {
                Color.white
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous).strokeBorder(ZenithSurface.hairline))
        .onAppear(perform: make)
        .onChange(of: url) { _, _ in make() }
    }

    private func make() {
        guard code?.url != url else { return }
        guard let matrix = PocketQR.matrix(for: url), let image = PocketQR.image(matrix) else {
            code = nil
            return
        }
        code = (url, image, PocketQR.modulesAcross(matrix))
    }
}

// MARK: - Chrome

/// A section: its glyph and bold title above a hairline card, an optional
/// mono label at the title's trailing edge, and an optional line under it.
/// The same chrome as the Batteries page.
private struct PocketSection<Content: View>: View {
    var symbol: String? = nil
    var title: String? = nil
    var trailing: String? = nil
    var footnote: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let symbol, let title {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(title)
                        .font(ZenithType.sectionTitle)
                        .tracking(ZenithType.sectionTitleTracking)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 12)
                    if let trailing {
                        Text(trailing.uppercased())
                            .font(ZenithType.mono(9.5, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 16)
                    }
                }
                .padding(.leading, 2)
            }
            let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .background(ZenithSurface.cardFill, in: shape)
                .overlay(shape.strokeBorder(ZenithSurface.hairline))
            if let footnote {
                Text(footnote)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PocketRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

private struct PocketDivider: View {
    var body: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).padding(.horizontal, 16)
    }
}
