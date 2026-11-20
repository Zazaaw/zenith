// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the QR codes in the island. A QR action on a clipboard card
// whose entry is a link or a short text (and the same in its menu), and the
// home page's "QR from clipboard" widget: a small code of the latest copy,
// which opens the QR page large.

/// The QR action on a clipboard card; nothing for an entry no code is made of.
struct QRClipboardButton: View {
    let entry: ClipboardHistoryEntry
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if entry.kind == .text, QRDetector.offers(entry.text) {
            NotchIconButton(symbol: "qrcode", title: ZenithStrings.qr(l10n.language).title) {
                QRService.shared.show(text: entry.text)
            }
        }
    }
}

/// The same action in a clipboard card's menu.
struct QRClipboardMenuItem: View {
    let entry: ClipboardHistoryEntry
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if entry.kind == .text, QRDetector.offers(entry.text) {
            Button(ZenithStrings.qr(l10n.language).title) { QRService.shared.show(text: entry.text) }
        }
    }
}

/// Customize Home's "QR from clipboard": the latest copy's code on its white
/// tile beside the copy itself; a click opens the QR page with it.
struct QRHomeWidget: View {
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.zenithQRLogo) private var logo = false
    @AppStorage(DefaultsKey.zenithQRCorrection) private var storedCorrection = QRCorrection.medium.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = ZenithStrings.qr(l10n.language)
        let entry = history.latestPasteboardEntry ?? history.entries.first
        let content = entry.flatMap { $0.kind == .text ? QRDetector.detect($0.text) : nil }
        let payload = content?.payload
        let matrix = payload.flatMap { QRService.shared.matrix($0, correction: logo ? .high : QRCorrection.stored(storedCorrection)) }
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let content, let payload, let matrix {
                    Button { QRService.shared.show(content) } label: {
                        HStack(spacing: 10) {
                            QRCodeView(matrix: matrix, logo: logo)
                                .frame(width: 58, height: 58)
                            VStack(alignment: .leading, spacing: 6) {
                                ZenithHomeWidgetHeader(widget: .qr, title: text.title)
                                Text(payload.replacingOccurrences(of: "\r\n", with: " ")
                                    .replacingOccurrences(of: "\n", with: " "))
                                    .font(ZenithType.mono(10))
                                    .foregroundStyle(ZenithIsland.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(text.fromClipboard)
                    .transition(.zenithMorph(reduceMotion: reduceMotion))
                    .id(payload)
                } else {
                    Button { QRService.shared.newCode() } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ZenithHomeWidgetHeader(widget: .qr, title: text.title)
                            Text(text.widgetEmpty)
                                .font(.system(size: 10.5))
                                .foregroundStyle(ZenithIsland.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(text.newCode)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: payload)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
