// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: how safe an import is, on the Card Import page. Under a
// finished import, a soft card offers its backup (or says where the drive
// is), shows the backup and its verification under way, then the result;
// below it, the card against the import. The Backups list shows every event
// with its state and its next step. States swap through the island's morph;
// figures roll with `numericText` and the bar slides by scale. "Safe to
// format" is only ever words: nothing here touches the card.

// MARK: Reading

/// What a backup or check under way reads: `42%` and `812 left · 3m`.
private struct CardBackupLiveReading: View {
    @ObservedObject var meter: CardBackupMeter
    let language: AppLanguage
    var showsBar = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = meter.progress
        let locale = language.formattingLocale()
        let text = ZenithStrings.cardImport(language)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(CardImportStripLayout.percentText(progress.percent))
                    .font(ZenithType.mono(11, weight: .semibold))
                    .foregroundStyle(ZenithIsland.primary)
                    .contentTransition(.numericText(value: Double(progress.percent)))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: progress.percent)
                Text(reading(progress, text: text, locale: locale))
                    .font(ZenithType.mono(10.5))
                    .foregroundStyle(ZenithIsland.meta)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: progress.filesLeft)
            }
            if showsBar { CardImportBar(fraction: progress.fraction, height: 3) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(CardImportStripLayout.percentText(progress.percent))
    }

    private func reading(_ progress: CardImportProgress, text: ZenithCardImportStrings, locale: Locale) -> String {
        var parts = [CardImportFormat.filling(text.left, CardImportFormat.count(progress.filesLeft, locale: locale))]
        if let eta = progress.eta { parts.append(CardImportFormat.eta(eta, locale: locale)) }
        return parts.joined(separator: " · ")
    }
}

/// A state's glyph on its tinted tile.
private struct CardBackupGlyph: View {
    let symbol: String
    let color: Color

    var body: some View {
        ZenithIslandGlyphTile(symbol: symbol, tint: color, size: 28)
    }
}

// MARK: Panel

/// Under a finished import: its backup, then the card against the import.
struct CardBackupPanel: View {
    let record: String
    let card: String
    let language: AppLanguage
    @ObservedObject private var backups = CardBackupService.shared
    @ObservedObject private var imports = CardImportService.shared

    private var text: ZenithCardBackupStrings { ZenithStrings.cardBackup(language) }

    var body: some View {
        if let entry = backups.record(record) {
            VStack(alignment: .leading, spacing: 8) {
                backupRow(entry)
                    .zenithMorph(on: backupKey(entry))
                if entry.card(card) != nil {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.75)
                    cardRow(entry)
                        .zenithMorph(on: cardKey(entry))
                }
            }
            .padding(10)
            .zenithIslandSoftCard()
            .frame(maxWidth: 380)
        }
    }

    // MARK: Backup

    private enum BackupKey: Hashable { case live(CardBackupStage?), failed, verified, backedUp, offer, connect, none }

    private func backupKey(_ entry: CardBackupRecord) -> BackupKey {
        if let run = backups.activeRun(entry.id) {
            if case .running(let stage) = run.phase { return .live(stage) }
            return .live(nil)
        }
        if case .failed? = backups.backupResult(entry.id)?.phase { return .failed }
        switch entry.state {
        case .verified: return .verified
        case .backedUp: return .backedUp
        case .imported:
            if backups.destinations.isEmpty { return .none }
            return backups.mountedDestinations.isEmpty ? .connect : .offer
        }
    }

    @ViewBuilder private func backupRow(_ entry: CardBackupRecord) -> some View {
        let tint = NotchModule.cardImport.zenithTint
        switch backupKey(entry) {
        case .live(let stage):
            row(symbol: stage == .verifying ? "checkmark.shield.fill" : "externaldrive.fill", color: tint,
                title: stage == .verifying ? text.verifying : text.backingUp) {
                // Waiting behind another event's backup: no reading of its own yet.
                if stage == nil { detail("…") } else { CardBackupLiveReading(meter: backups.meter, language: language) }
            } trailing: {
                Button(ZenithStrings.cardImport(language).stop) { backups.stopAll() }
                    .buttonStyle(ZenithIslandOutlineButtonStyle())
            }
        case .failed:
            let result = backups.backupResult(entry.id)
            let failure: CardBackupFailure = { if case .failed(let f)? = result?.phase { return f } else { return .driveRemoved } }()
            row(symbol: "xmark", color: failureColor(failure), title: CardBackupFormat.failure(failure, text: text, language: language)) {
                detail(mismatchNames(result?.mismatches ?? []) ?? driveName(result))
            } trailing: {
                if !backups.mountedDestinations.isEmpty {
                    Button(ZenithStrings.cardImport(language).retry) { backups.backUp(entry.id) }
                        .buttonStyle(CardImportPrimaryStyle())
                }
            }
        case .verified:
            let copy = entry.bestCopy
            row(symbol: "checkmark.seal.fill", color: ZenithStatus.success,
                title: CardBackupFormat.verified(files: copy?.files ?? entry.files, bytes: copy?.bytes ?? entry.bytes,
                                                 text: text, language: language)) {
                detail("→ " + (copy?.drive ?? ""))
            } trailing: { EmptyView() }
        case .backedUp:
            row(symbol: "externaldrive.fill", color: ZenithStatus.info,
                title: CardImportFormat.filling(text.backedUpTo, entry.bestCopy?.drive ?? "")) {
                detail(text.notVerifiedYet)
            } trailing: {
                if !backups.mountedDestinations.isEmpty {
                    Button(text.verify) { backups.backUp([entry.id], verify: true) }
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 28))
                }
            }
        case .offer:
            row(symbol: "externaldrive.badge.exclamationmark", color: ZenithStatus.warning, title: text.notBackedUpYet) {
                detail("→ " + backups.mountedDestinations.map(\.destination.volumeName).joined(separator: ", "))
            } trailing: {
                Button(text.backUpNow) { backups.backUp(entry.id) }
                    .buttonStyle(CardImportPrimaryStyle())
            }
        case .connect:
            row(symbol: "externaldrive.badge.exclamationmark", color: ZenithStatus.warning, title: text.notBackedUpYet) {
                detail(CardImportFormat.filling(text.connectDrive, backups.destinations.first?.volumeName ?? ""))
            } trailing: { EmptyView() }
        case .none:
            row(symbol: "externaldrive.badge.exclamationmark", color: ZenithStatus.warning, title: text.notBackedUpYet) {
                detail(text.noDestination)
            } trailing: { EmptyView() }
        }
    }

    // MARK: Card

    private enum CardKey: Hashable { case live, failed, matched, offer, none }

    private func cardKey(_ entry: CardBackupRecord) -> CardKey {
        if backups.activeRun(entry.id, cardCheck: true) != nil { return .live }
        if let result = backups.checkResult(entry.id, card: card) {
            if case .failed = result.phase { return .failed }
            return .matched
        }
        if let known = entry.card(card), known.verified != nil {
            return known.problems == 0 ? .matched : .failed
        }
        return backups.canCheckCard(card, record: entry.id) ? .offer : .none
    }

    @ViewBuilder private func cardRow(_ entry: CardBackupRecord) -> some View {
        switch cardKey(entry) {
        case .live:
            let running: Bool = {
                if case .running? = backups.activeRun(entry.id, cardCheck: true)?.phase { return true }
                return false
            }()
            row(symbol: "sdcard.fill", color: NotchModule.cardImport.zenithTint, title: text.verifying) {
                if running { CardBackupLiveReading(meter: backups.meter, language: language) } else { detail("…") }
            } trailing: { EmptyView() }
        case .failed:
            let result = backups.checkResult(entry.id, card: card)
            let count = result?.mismatches.count ?? entry.card(card)?.problems ?? 0
            let failure: CardBackupFailure = {
                if case .failed(let f)? = result?.phase { return f }
                return .mismatches(count)
            }()
            row(symbol: "sdcard", color: ZenithStatus.error, title: CardBackupFormat.failure(failure, text: text, language: language)) {
                detail(mismatchNames(result?.mismatches ?? []) ?? "")
            } trailing: {
                if backups.canCheckCard(card, record: entry.id) {
                    Button(ZenithStrings.cardImport(language).retry) { backups.checkCard(card, record: entry.id) }
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 28))
                }
            }
        case .matched:
            let safe = entry.state == .verified
            row(symbol: "sdcard.fill", color: ZenithStatus.success, title: text.cardMatches) {
                ZenithStatusLine(color: safe ? ZenithStatus.success : ZenithStatus.warning,
                                 text: safe ? text.safeToFormat : text.backUpFirst, mono: false, size: 10.5)
            } trailing: { EmptyView() }
        case .offer:
            HStack(spacing: 8) {
                Image(systemName: "sdcard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ZenithIsland.secondary)
                    .frame(width: 28)
                Text(entry.card(card)?.name ?? "")
                    .font(ZenithType.mono(10.5)).foregroundStyle(ZenithIsland.meta)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                Button(text.verifyCard) { backups.checkCard(card, record: entry.id) }
                    .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
            }
        case .none:
            EmptyView()
        }
    }

    // MARK: Pieces

    private func row<Detail: View, Trailing: View>(symbol: String, color: Color, title: String,
                                                   @ViewBuilder detail: () -> Detail,
                                                   @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            CardBackupGlyph(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                detail()
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func detail(_ value: String) -> some View {
        Text(value)
            .font(ZenithType.mono(10.5))
            .foregroundStyle(ZenithIsland.meta)
            .lineLimit(2).truncationMode(.middle)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func failureColor(_ failure: CardBackupFailure) -> Color {
        if case .diskFull = failure { return ZenithStatus.warning }
        return ZenithStatus.error
    }

    private func mismatchNames(_ mismatches: [CardBackupMismatch]) -> String? {
        guard !mismatches.isEmpty else { return nil }
        let names = mismatches.prefix(2).map { ($0.file as NSString).lastPathComponent }
        let more = mismatches.count - names.count
        return (names + (more > 0 ? ["+" + CardImportFormat.count(more, locale: language.formattingLocale())] : []))
            .joined(separator: ", ")
    }

    private func driveName(_ run: CardBackupRun?) -> String {
        if case .backup(_, let drive)? = run?.kind { return "→ " + drive }
        return ""
    }
}

// MARK: Pending

/// On an empty page: how many events wait for a backup, and the list.
struct CardBackupPendingSummary: View {
    let language: AppLanguage
    @ObservedObject private var backups = CardBackupService.shared

    var body: some View {
        let pending = backups.pending
        if !backups.records.isEmpty {
            VStack(spacing: 8) {
                if !pending.isEmpty {
                    ZenithStatusLine(color: ZenithStatus.warning,
                                     text: CardBackupFormat.reminderTitle(pending, text: ZenithStrings.cardBackup(language),
                                                                          language: language),
                                     size: 10.5, emphasised: true)
                }
                Button(ZenithStrings.cardBackup(language).title) { backups.showsList = true }
                    .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
            }
        }
    }
}

/// In a card's header, while events wait for a backup: a drive with a mark
/// that opens the list.
struct CardBackupPendingButton: View {
    let language: AppLanguage
    @ObservedObject private var backups = CardBackupService.shared

    var body: some View {
        let pending = backups.pending
        if !pending.isEmpty {
            let title = CardBackupFormat.reminderTitle(pending, text: ZenithStrings.cardBackup(language), language: language)
            NotchIconButton(symbol: "externaldrive.badge.exclamationmark", title: title) { backups.showsList = true }
                .foregroundStyle(ZenithStatus.warning)
                .transition(.opacity)
        }
    }
}

// MARK: List

/// Every event the island imported, newest first, with its state and its
/// next step.
struct CardBackupList: View {
    let language: AppLanguage
    @ObservedObject private var backups = CardBackupService.shared

    private var text: ZenithCardBackupStrings { ZenithStrings.cardBackup(language) }
    private static let shown = 30

    var body: some View {
        let records = Array(backups.records.prefix(Self.shown))
        VStack(alignment: .leading, spacing: 10) {
            CardImportHeader(symbol: "externaldrive.fill", title: text.title, detail: drives) {
                if backups.pending.count > 1, !backups.mountedDestinations.isEmpty {
                    Button(text.backUpAll) { backups.backUpPending() }
                        .buttonStyle(ZenithIslandOutlineButtonStyle())
                }
                NotchIconButton(symbol: "xmark", title: text.close) { backups.showsList = false }
            }
            if records.isEmpty {
                Text(text.noEvents).font(.system(size: 12)).foregroundStyle(ZenithIsland.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if backups.pending.isEmpty {
                    ZenithStatusLine(color: ZenithStatus.success, text: text.allSafe, mono: false, size: 11)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            if index > 0 { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.75) }
                            CardBackupListRow(record: record, language: language)
                        }
                    }
                    .padding(.horizontal, 10)
                    .zenithIslandSoftCard()
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    /// `T7 Shield · Connected`, for each destination.
    private var drives: String {
        let list = backups.destinations
        guard !list.isEmpty else { return text.noDestinations }
        return list.map { $0.volumeName + " · " + (backups.isMounted($0) ? text.connected : text.notConnected) }
            .joined(separator: "   ")
    }
}

private struct CardBackupListRow: View {
    let record: CardBackupRecord
    let language: AppLanguage
    @ObservedObject private var backups = CardBackupService.shared

    private var text: ZenithCardBackupStrings { ZenithStrings.cardBackup(language) }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.event)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1).truncationMode(.middle)
                HStack(spacing: 8) {
                    ZenithStatusLine(color: stateColor, text: stateText, size: 10)
                    Text(figures).font(ZenithType.mono(10)).foregroundStyle(ZenithIsland.meta).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing
                .zenithMorph(on: trailingKey)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(ZenithStrings.cardImport(language).reveal) { backups.reveal(record) }
        }
    }

    private var stateColor: Color {
        switch record.state {
        case .imported: return ZenithStatus.warning
        case .backedUp: return ZenithStatus.info
        case .verified: return ZenithStatus.success
        }
    }

    private var stateText: String {
        if case .failed(let failure)? = backups.backupResult(record.id)?.phase {
            return CardBackupFormat.failure(failure, text: text, language: language)
        }
        switch record.state {
        case .imported: return text.stateImported
        case .backedUp: return text.stateBackedUp
        case .verified: return text.stateVerified
        }
    }

    private var figures: String {
        let date = record.imported.formatted(.dateTime.day().month(.abbreviated).locale(language.formattingLocale()))
        return [CardBackupFormat.files(record.files, text: text, language: language), CardImportFormat.bytes(record.bytes), date]
            .joined(separator: " · ")
    }

    /// A card of this event in the Mac that was not compared yet.
    private var checkableCard: String? {
        record.cards.first { $0.verified == nil && backups.canCheckCard($0.id, record: record.id) }?.id
    }

    private enum TrailingKey: Hashable { case live, waiting, backUp, verify, card, none }

    private var trailingKey: TrailingKey {
        let runs = [backups.activeRun(record.id), backups.activeRun(record.id, cardCheck: true)].compactMap { $0 }
        if runs.contains(where: { if case .running = $0.phase { return true } else { return false } }) { return .live }
        if !runs.isEmpty { return .waiting }
        let mounted = !backups.mountedDestinations.isEmpty
        switch record.state {
        case .imported where mounted: return .backUp
        case .backedUp where mounted: return .verify
        default: return checkableCard != nil ? .card : .none
        }
    }

    @ViewBuilder private var trailing: some View {
        switch trailingKey {
        case .live:
            CardBackupLiveReading(meter: backups.meter, language: language, showsBar: false)
                .fixedSize()
        case .waiting:
            ProgressView().controlSize(.small)
        case .backUp:
            Button(text.backUp) { backups.backUp(record.id) }
                .buttonStyle(CardImportPrimaryStyle())
        case .verify:
            Button(text.verify) { backups.backUp([record.id], verify: true) }
                .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
        case .card:
            Button(text.verifyCardShort) { if let card = checkableCard { backups.checkCard(card, record: record.id) } }
                .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
        case .none:
            EmptyView()
        }
    }
}
