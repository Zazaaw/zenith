// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Card Import page in the open island. One card at a time:
// what is on it, where it goes and how, then the copy's progress, then how it
// ended. The states swap through the island's morph (blur, opacity, scale);
// the progress rolls its digits and slides its bar by scale, so nothing lays
// out again ten times a second. Colour comes from the module's palette on
// soft cards concentric with the island; status colours keep their meaning.

struct CardImportPage: View {
    let size: CGSize
    @ObservedObject private var service = CardImportService.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var backups = CardBackupService.shared

    private var text: ZenithCardImportStrings { ZenithStrings.cardImport(l10n.language) }

    /// Which state shows; a change swaps the page through the morph.
    private enum Stage: Hashable { case empty, reading(String), ready(String), copying, finished, failed, backups }

    private var stage: Stage {
        if backups.showsList { return .backups }
        if let session = service.session, service.card?.id == session.cardID || session.isRunning
            || !service.cards.contains(where: { $0.id == session.cardID }) {
            switch session.phase {
            case .preparing, .copying: return .copying
            case .finished: return .finished
            case .failed: return .failed
            }
        }
        guard let card = service.card else { return .empty }
        return card.scan == nil ? .reading(card.id) : .ready(card.id)
    }

    var body: some View {
        content
            .frame(width: size.width, height: max(size.height, CardImportPageMetrics.minimumHeight), alignment: .top)
            .zenithMorph(on: stage)
            .environment(\.locale, l10n.language.formattingLocale())
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .empty:
            CardImportEmpty(symbol: "sdcard", message: text.empty) {
                CardBackupPendingSummary(language: l10n.language)
            }
        case .backups:
            CardBackupList(language: l10n.language)
        case .reading:
            VStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(text.scanning).font(.system(size: 12)).foregroundStyle(ZenithIsland.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if let card = service.card, let scan = card.scan {
                CardImportReadyView(card: card, scan: scan, text: text, language: l10n.language)
            }
        case .copying:
            if let session = service.session {
                CardImportCopyingView(session: session, meter: service.meter, text: text, language: l10n.language)
            }
        case .finished:
            if let session = service.session {
                CardImportResultView(session: session, text: text, language: l10n.language)
            }
        case .failed:
            if let session = service.session {
                CardImportResultView(session: session, text: text, language: l10n.language)
            }
        }
    }
}

// MARK: Pieces

/// An empty state with the module's glyph on its tinted tile.
private struct CardImportEmpty<Actions: View>: View {
    let symbol: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 12) {
            ZenithIslandGlyphTile(symbol: symbol, tint: NotchModule.cardImport.zenithTint, size: 48)
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(ZenithIsland.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .fixedSize(horizontal: false, vertical: true)
            actions()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension CardImportEmpty where Actions == EmptyView {
    init(symbol: String, message: String) {
        self.init(symbol: symbol, message: message) { EmptyView() }
    }
}

/// The page's one main step on a solid capsule in the module's colour.
struct CardImportPrimaryStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(Color.black.opacity(0.86))
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(Capsule().fill(NotchModule.cardImport.zenithTint))
            .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? ZenithMotion.pressedScale : 1)
            .animation(ZenithMotion.respecting(ZenithMotion.press), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// A card's name with its tile and what it holds.
struct CardImportHeader<Trailing: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: symbol, tint: NotchModule.cardImport.zenithTint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.2)
                    .lineLimit(1).truncationMode(.middle)
                Text(detail)
                    .font(ZenithType.mono(10.5))
                    .foregroundStyle(ZenithIsland.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }
}

// MARK: Ready

private struct CardImportReadyView: View {
    let card: CardImportCard
    let scan: CardScan
    let text: ZenithCardImportStrings
    let language: AppLanguage
    @ObservedObject private var service = CardImportService.shared
    @FocusState private var naming: Bool

    private var locale: Locale { language.formattingLocale() }

    /// Files this draft would copy, after what came off the card before.
    private var newFiles: Int {
        service.draft.options.skipImported ? max(0, scan.files.count - card.importedBefore) : scan.files.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardImportHeader(symbol: "sdcard.fill", title: card.name,
                             detail: [CardImportFormat.contents(scan, text: text, language: language),
                                      CardImportFormat.bytes(scan.bytes)].filter { !$0.isEmpty }.joined(separator: " · ")) {
                CardBackupPendingButton(language: language)
                if service.cards.count > 1 { cardMenu }
                NotchIconButton(symbol: "eject", title: text.eject) { service.eject() }
                    .help(text.eject)
            }
            if scan.isEmpty {
                Text(text.noMedia).font(.system(size: 12)).foregroundStyle(ZenithIsland.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                destination
                options
                footer
            }
        }
        .padding(.top, 2)
    }

    private var cardMenu: some View {
        Menu {
            ForEach(service.cards) { other in
                Button(other.name) { service.select(other.id) }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .medium)).zenithIslandGlyph()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var destination: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(text.destination).modifier(ZenithBentoLabelStyle())
                Spacer(minLength: 4)
                Text(CardImportDestination.stored(CardImportService.baseFolder) + "/")
                    .font(ZenithType.mono(10))
                    .foregroundStyle(ZenithIsland.meta)
                    .lineLimit(1).truncationMode(.head)
                    .help(CardImportService.baseFolder.path)
            }
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NotchModule.cardImport.zenithTint)
                TextField(text.eventPlaceholder, text: $service.draft.eventName,
                          prompt: Text(text.eventPlaceholder).foregroundStyle(ZenithIsland.meta))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .focused($naming)
                    .onSubmit(start)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .modifier(ZenithIslandFieldChrome(focused: naming, cornerRadius: ZenithIsland.nestedRadius(padding: 10)))
        }
        .padding(10)
        .zenithIslandSoftCard()
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    toggle(text.separateRaw, isOn: $service.draft.options.separateRaw)
                    toggle(text.videoFolder, isOn: $service.draft.options.videoFolder)
                }
                GridRow {
                    toggle(text.skipImported, isOn: $service.draft.options.skipImported)
                    toggle(text.ejectWhenDone, isOn: $service.draft.options.ejectWhenDone)
                }
            }
            HStack(spacing: 8) {
                Text(text.rename).font(.system(size: 12)).foregroundStyle(ZenithIsland.secondary)
                Spacer(minLength: 4)
                ZenithSegmented(selection: $service.draft.options.rename,
                                options: [(CardRenamePattern.original, text.renameOriginal),
                                          (CardRenamePattern.dateSequence, text.renameDate)],
                                height: 24, fontSize: 11, fills: false)
                    .fixedSize()
            }
        }
        .padding(10)
        .zenithIslandSoftCard()
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(.system(size: 12)).foregroundStyle(ZenithIsland.primary)
                .lineLimit(1).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(ZenithIslandSwitchStyle(scale: 0.76))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            let new = newFiles
            if new > 0 {
                ZenithStatusLine(color: NotchModule.cardImport.zenithTint,
                                 text: CardImportFormat.filling(text.newFiles, CardImportFormat.count(new, locale: locale)),
                                 size: 10.5, emphasised: true)
            }
            if card.importedBefore > 0, service.draft.options.skipImported {
                Text(CardImportFormat.filling(text.alreadyImported, CardImportFormat.count(card.importedBefore, locale: locale)))
                    .font(ZenithType.mono(10.5)).foregroundStyle(ZenithIsland.meta).lineLimit(1)
            }
            if new == 0 {
                Text(text.nothingNew).font(.system(size: 11.5)).foregroundStyle(ZenithIsland.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(text.importAction, action: start)
                .buttonStyle(CardImportPrimaryStyle())
                .disabled(new == 0)
        }
    }

    private func start() {
        guard newFiles > 0 else { return }
        naming = false
        service.startImport()
    }
}

// MARK: Copying

private struct CardImportCopyingView: View {
    let session: CardImportSession
    @ObservedObject var meter: CardImportMeter
    let text: ZenithCardImportStrings
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var locale: Locale { language.formattingLocale() }

    var body: some View {
        let progress = meter.progress
        VStack(alignment: .leading, spacing: 10) {
            CardImportHeader(symbol: "camera.fill", title: session.cardName,
                             detail: "→ " + session.folder.lastPathComponent) {
                Button(text.stop) { CardImportService.shared.stopImport() }
                    .buttonStyle(ZenithIslandOutlineButtonStyle())
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ZenithFigure.compose(CardImportStripLayout.percentText(progress.percent), size: 34)
                        .tracking(-0.5)
                        .contentTransition(.numericText(value: Double(progress.percent)))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: progress.percent)
                    Text(text.importing)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchModule.cardImport.zenithTint)
                    Spacer(minLength: 8)
                    if let speed = progress.bytesPerSecond, speed > 0 {
                        Text(CardImportFormat.bytes(Int64(speed)) + "/s")
                            .font(ZenithType.mono(10.5)).foregroundStyle(ZenithIsland.meta)
                            .contentTransition(.numericText())
                    }
                }
                CardImportBar(fraction: progress.fraction, height: 4)
                HStack(spacing: 0) {
                    reading("\(CardImportFormat.count(progress.copiedFiles, locale: locale)) / "
                            + CardImportFormat.count(progress.totalFiles, locale: locale))
                    Spacer(minLength: 8)
                    reading(CardImportFormat.bytes(progress.copiedBytes) + " / " + CardImportFormat.bytes(progress.totalBytes))
                    Spacer(minLength: 8)
                    reading(progress.eta.map { CardImportFormat.filling(text.left, CardImportFormat.eta($0, locale: locale)) }
                            ?? "…")
                }
                Text(progress.current ?? " ")
                    .font(ZenithType.mono(10))
                    .foregroundStyle(ZenithIsland.meta)
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(12)
            .zenithIslandSoftCard()
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityValue(CardImportStripLayout.percentText(progress.percent))
    }

    private func reading(_ value: String) -> some View {
        Text(value)
            .font(ZenithType.mono(11, weight: .medium))
            .foregroundStyle(ZenithIsland.secondary)
            .lineLimit(1)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: value)
    }
}

// MARK: Result

/// How the import ended: imported, with Reveal in Finder and Eject, or what
/// went wrong with a retry.
private struct CardImportResultView: View {
    let session: CardImportSession
    let text: ZenithCardImportStrings
    let language: AppLanguage
    @ObservedObject private var service = CardImportService.shared

    private var locale: Locale { language.formattingLocale() }
    private var failure: CardImportFailure? {
        if case .failed(let failure) = session.phase { return failure }
        return nil
    }

    /// Zenith fork: the import's backup and the card's check, under a finished import.
    private var backupRecord: String? { failure == nil ? session.backupRecord : nil }

    var body: some View {
        let compact = backupRecord != nil
        VStack(spacing: compact ? 8 : 12) {
            Spacer(minLength: 0)
            CardImportResultMark(failure: failure)
                .frame(width: compact ? 34 : 46, height: compact ? 34 : 46)
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
                    .multilineTextAlignment(.center)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(ZenithIsland.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 340)
            HStack(spacing: 8) { actions }
            if let backupRecord {
                CardBackupPanel(record: backupRecord, card: session.cardID, language: language)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch failure {
        case nil:
            return CardImportFormat.filling(text.imported, CardImportFormat.summary(files: session.copiedFiles,
                                                                                     bytes: session.copiedBytes,
                                                                                     language: language))
        case .cardRemoved?: return text.cardRemoved
        case .diskFull?: return text.diskFull
        case .failed?: return text.failed
        }
    }

    private var detail: String {
        var lines: [String] = []
        switch failure {
        case nil:
            lines.append("→ " + CardImportDestination.stored(session.folder))
            if session.skipped > 0 {
                lines.append(CardImportFormat.filling(text.skippedBefore, CardImportFormat.count(session.skipped, locale: locale)))
            }
            if session.eject == .failed { lines.append(text.ejectFailed) }
        case .cardRemoved?:
            lines.append(text.cardRemovedDetail)
        case .diskFull(let needed)?:
            lines.append(CardImportFormat.filling(text.diskFullDetail, CardImportFormat.bytes(needed)))
        case .failed(let file)?:
            lines.append(CardImportFormat.filling(text.failedDetail, file))
        }
        if failure != nil, session.copiedFiles > 0 {
            lines.append(CardImportFormat.filling(text.imported, CardImportFormat.summary(files: session.copiedFiles,
                                                                                           bytes: session.copiedBytes,
                                                                                           language: language)))
        }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder private var actions: some View {
        let cardHere = service.cards.contains { $0.id == session.cardID && $0.scan != nil }
        if failure == nil {
            // Zenith fork: with the backup below, that is the next step, so Reveal steps back.
            if backupRecord != nil {
                Button(text.reveal) { service.reveal() }.buttonStyle(ZenithIslandOutlineButtonStyle(height: 28))
            } else {
                Button(text.reveal) { service.reveal() }
                    .buttonStyle(CardImportPrimaryStyle())
            }
            switch session.eject {
            case .ejected:
                ZenithStatusLine(color: ZenithStatus.success, text: text.ejected, size: 11)
            case .ejecting:
                ProgressView().controlSize(.small)
            case .idle, .failed:
                if cardHere {
                    Button(text.eject) { service.eject() }.buttonStyle(ZenithIslandOutlineButtonStyle(height: 28))
                }
            }
        } else {
            Button(text.retry) { service.retry() }
                .buttonStyle(CardImportPrimaryStyle())
                .disabled(!cardHere)
            if session.copiedFiles > 0 {
                Button(text.reveal) { service.reveal() }.buttonStyle(ZenithIslandOutlineButtonStyle(height: 28))
            }
        }
        Button(text.done) { service.dismissResult() }.buttonStyle(ZenithIslandOutlineButtonStyle(height: 28))
    }
}

/// The result's mark: a check drawn with `trim` in an emerald ring that
/// fills behind it, or a cross in red (amber for a full disk, which the
/// person can fix and retry).
private struct CardImportResultMark: View {
    let failure: CardImportFailure?
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let color = failure == nil ? ZenithStatus.success : {
            if case .diskFull? = failure { return ZenithStatus.warning }
            return ZenithStatus.error
        }()
        ZStack {
            Circle().fill(color.opacity(0.14))
            Circle()
                .trim(from: 0, to: shown || reduceMotion ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if failure == nil {
                CardImportCheck(color: color, lineWidth: 3, delay: 0.3)
                    .padding(13)
            } else {
                Image(systemName: failure == .cardRemoved ? "sdcard" : "exclamationmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                    .opacity(shown || reduceMotion ? 1 : 0)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.45)) { shown = true }
        }
        .accessibilityHidden(true)
    }
}
