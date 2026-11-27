// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: Settings → iPhone & Watch, Zenith Pocket's page, beside iPhone
/// Remote, built with the Settings kit. The switch in the hero, the relay (the person's own Supabase project), pairing
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
    private let page = ZenithStrings.everyday(.enUS)

    private var stage: PocketPairingStage {
        PocketPairingStage.of(store.phase, enabled: enabled, hasRelay: store.relay != nil)
    }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips, isOn: $enabled,
                           switchLabel: text.enable, switchHint: text.enableCaption, animation: .pocket)
                    .zenithSectionAnchor(.zenithPocket, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                PocketPreviewCard(state: $previewState,
                                  sharing: PocketPreviewSharing(wallpaper: shareWallpaper, agents: shareAgents,
                                                                nowPlaying: shareNowPlaying)) {
                    open(.zenithPocketPairing)
                } openSharing: {
                    open(.zenithPocketSharing)
                }
                relaySection
                pairingSection
                sharingSection
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.5)
                PocketWatchtowerSection().disabled(!enabled).opacity(enabled ? 1 : 0.5)
            }
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

    private var chips: [ZenithChip] {
        if case .paired = stage {
            return [ZenithChip(PocketSettingsText.link(store.link, text), dot: linkColor),
                    ZenithChip(PocketSettingsText.phoneName(store.devices, text))]
        }
        return [ZenithChip(page.pocketNotPaired)]
    }

    private func open(_ anchor: SettingsSectionAnchor) {
        SettingsRouter.shared.request(FeatureSettingsDestination(.pocket, sectionAnchor: anchor))
    }

    // MARK: Relay

    private var relaySection: some View {
        ZenithSection(text.relay, anchor: .zenithPocketRelay, footer: text.relayCaption) {
            field(text.projectURL, problem: showsProblems ? draft.urlProblem : nil) {
                TextField(text.projectURL, text: $draft.url, prompt: Text(text.projectURLPrompt))
                    .textFieldStyle(.roundedBorder)
                    .font(ZenithType.mono(12))
                    .onSubmit(save)
            }
            field(text.anonKey, problem: showsProblems ? draft.keyProblem : nil) {
                TextField(text.anonKey, text: $draft.key, prompt: Text(text.anonKeyPrompt), axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .font(ZenithType.mono(11))
                    .onSubmit(save)
            }
            HStack(spacing: 8) {
                relayStatus
                Spacer(minLength: 12)
                if store.relay != nil {
                    Button(text.forget) { store.saveRelay(nil) }
                }
                Button(text.save, action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.isEmpty || isSaved)
            }
            .padding(.vertical, 8)
            if let problem = store.problem, !problem.isEmpty {
                ZenithRowStatus(text: problem, symbol: "exclamationmark.triangle.fill", color: ZenithStatus.error)
            }
        }
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
        .padding(.vertical, 10)
    }

    // MARK: Pairing

    private var pairingSection: some View {
        ZenithSection(text.pairing, anchor: .zenithPocketPairing) {
            switch stage {
            case .needs(let missing): needsRow(missing)
            case .starting:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    caption(text.starting)
                }
                .padding(.vertical, 8)
            case .unpaired:
                ZenithRow(text.pairPhone, info: text.pairCaption, button: text.pairPhone) { store.startPairing() }
            case .pairing(let url): pairingRow(url)
            case .paired(let lastSeen): paired(lastSeen)
            }
        }
    }

    private func needsRow(_ missing: [PocketMissing]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(text.missingTitle).font(ZenithType.rowTitle)
                ForEach(missing, id: \.self) { item in
                    caption(item == .enable ? text.missingEnable : text.missingRelay)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    private func pairingRow(_ url: URL) -> some View {
        HStack(alignment: .top, spacing: 20) {
            PocketQRCode(url: url, label: text.codeLabel)
            VStack(alignment: .leading, spacing: 12) {
                Text(text.scanTitle).font(ZenithType.emphasis)
                VStack(alignment: .leading, spacing: 0) {
                    ZenithStepRow(number: 1, text: text.stepOpen)
                    ZenithStepRow(number: 2, text: text.stepPair)
                    ZenithStepRow(number: 3, text: text.stepPoint)
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
        .padding(.vertical, 14)
    }

    /// The link and the last message, the phone and its Watch, then Unpair,
    /// which asks once in place.
    private func paired(_ lastSeen: Date?) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Circle().fill(linkColor).frame(width: 8, height: 8).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PocketSettingsText.link(store.link, text)).font(ZenithType.rowTitle)
                        Text(PocketSettingsText.lastSeen(lastSeen, now: context.date, text))
                            .font(ZenithType.mono(10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                if store.devices.isEmpty {
                    ZenithRowSeparator().padding(.leading, -ZenithKitSurface.rowInset)
                    caption(text.noDevices).padding(.vertical, 10)
                }
                ForEach(store.devices, id: \.self) { device in
                    ZenithRowSeparator().padding(.leading, -ZenithKitSurface.rowInset)
                    deviceRow(device, now: context.date)
                }
                ZenithRowSeparator().padding(.leading, -ZenithKitSurface.rowInset)
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
        HStack(spacing: 12) {
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
        .padding(.vertical, 10)
    }

    @ViewBuilder private var unpairRow: some View {
        if confirmingUnpair {
            HStack(spacing: 8) {
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
            .padding(.vertical, 10)
        } else {
            HStack {
                Spacer()
                Button(text.unpair) { confirmingUnpair = true }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: Sharing

    private var sharingSection: some View {
        ZenithSection(text.sharing, anchor: .zenithPocketSharing) {
            ZenithRow(text.shareWallpaper, isOn: $shareWallpaper, info: text.shareWallpaperCaption)
            ZenithRow(text.shareAgents, isOn: $shareAgents, info: text.shareAgentsCaption)
            ZenithRow(text.shareNowPlaying, isOn: $shareNowPlaying, info: text.shareNowPlayingCaption)
            ZenithMoreOptions(id: "pocket") {
                ZenithRow(text.allowAnswers, isOn: $allowAnswers, info: text.allowAnswersCaption)
                PocketMacSettingsRows()
            }
        }
    }

    // MARK: Pieces

    private func caption(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
