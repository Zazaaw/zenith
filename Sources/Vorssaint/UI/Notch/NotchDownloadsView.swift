// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct NotchDownloadsSettingsControls: View {
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var enabled = true
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    // Zenith fork: Settings → Dynamic Island → Modules → Downloads, a section of compact rows (docs/SETTINGS-KIT.md).
    var body: some View {
        let pages = ZenithStrings.islandPages(l10n.language)
        ZenithSection(pages.folder) {
            ZenithRow(text.downloadsTitle, isOn: $enabled, info: text.downloadsHint)
                .disabled(!AppFeature.notchDownloads.isAvailable)
            ZenithRow(downloads.folderName ?? text.chooseFolder,
                      warning: downloads.folderUnavailable ? text.folderUnavailable : nil) {
                HStack(spacing: 8) {
                    if downloads.folderName != nil || downloads.folderUnavailable {
                        Button(text.clearFolder, action: downloads.forgetFolder)
                    }
                    Button(text.chooseFolder, action: downloads.chooseFolder)
                }
                .controlSize(.small)
            }
        }
        .onChange(of: enabled) { NotchService.shared.syncWithPreferences() }
    }
}

/// Before a folder is chosen the page says what it will do and offers the one
/// step that starts it, in the same voice as the island's other empty pages.
private struct NotchDownloadsSetupView: View {
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var enabled = true
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 12) {
                glyph
                copy.multilineTextAlignment(.center)
                actions
            }
            HStack(spacing: 16) {
                glyph
                VStack(alignment: .leading, spacing: 10) {
                    copy.multilineTextAlignment(.leading)
                    actions
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var glyph: some View {
        Image(systemName: downloads.folderUnavailable ? "exclamationmark.triangle" : "arrow.down.circle")
            .font(.system(size: 26, weight: .light))
            .foregroundStyle(ZenithIsland.secondary) // Zenith fork
            .frame(width: 56, height: 56)
            .zenithIslandCard(cornerRadius: ZenithRadius.panel) // Zenith fork: a hairline well
            .accessibilityHidden(true)
    }

    private var copy: some View {
        // Off, the page says what Downloads does beside its switch; on, which
        // folder to choose.
        Text(downloads.folderUnavailable ? text.folderUnavailable
             : offersSwitchOnly ? text.downloadsTitle : enabled ? text.downloadsHint : text.downloadsDescription)
            .font(.system(size: 12))
            .foregroundStyle(downloads.folderUnavailable ? ZenithStatus.warning : .white.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Off on a Mac without the feature: there is no folder to choose and
    /// nothing to switch, so the page only names itself.
    private var offersSwitchOnly: Bool { !enabled && !AppFeature.notchDownloads.isAvailable }

    @ViewBuilder private var actions: some View {
        if offersSwitchOnly {
            EmptyView()
        } else if !enabled {
            Toggle(text.downloadsTitle, isOn: $enabled)
                .toggleStyle(ZenithIslandSwitchStyle()) // Zenith fork
                .onChange(of: enabled) { NotchService.shared.syncWithPreferences() }
        } else {
            chooseActions
        }
    }

    private var chooseActions: some View {
        HStack(spacing: 8) {
            Button(action: downloads.chooseFolder) {
                Text(text.chooseFolder)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .modifier(ZenithIslandPill(prominent: true)) // Zenith fork
                    .contentShape(Capsule())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 14))
            if downloads.folderUnavailable {
                Button(action: downloads.forgetFolder) {
                    Text(text.clearFolder)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ZenithIsland.secondary) // Zenith fork
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .contentShape(Capsule())
                }
                .buttonStyle(NotchButtonStyle(cornerRadius: 14))
            }
        }
    }
}

struct NotchDownloadsView: View {
    let size: CGSize
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDownloadsEnabled) private var enabled = true
    @Environment(\.notchSettingsPreview) private var preview
    private var text: NotchFilesStrings { FeatureStrings.notchFiles(l10n.language) }

    private var needsSetup: Bool { !enabled || downloads.folderName == nil || downloads.folderUnavailable }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if needsSetup {
                NotchDownloadsSetupView()
            } else if downloads.items.isEmpty {
                NotchEmptyView(symbol: "arrow.down.circle", message: text.waiting)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) { // Zenith fork: rows parted by hairlines
                        ForEach(downloads.items) { item in
                            if item.id != downloads.items.first?.id { ZenithBentoDivider(.horizontal) } // Zenith fork
                            downloadCard(item)
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The watched folder heads the island's top row, so the cards start at
        // the top of the page. The setup offers its own choice instead.
        .notchBand(leading: { if !needsSetup { folderMenu } })
        // Another section or a collapse takes the page away; its chooser
        // could no longer return the folder here. Settings keeps its own.
        .onDisappear { if !preview { downloads.cancelNotchFolderChoice() } }
    }

    /// The watched folder by name, with the choice of another one or none.
    private var folderMenu: some View {
        let name = downloads.folderName ?? text.downloadsTitle
        return NotchMenuButton(title: text.downloadsTitle, items: [
            NotchMenuItem(title: text.chooseFolder, action: downloads.chooseFolder),
            NotchMenuItem(title: text.clearFolder, action: downloads.forgetFolder)
        ], cornerRadius: 9) {
            NotchBandMenuLabel(title: name, symbol: "folder", truncation: .middle)
        }
        .help(name)
        .accessibilityValue(name)
    }

    private func downloadCard(_ item: NotchDownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                let fileLabel = HStack(spacing: 8) {
                    // Zenith fork: a status dot, emerald once saved, purple and glowing while it arrives.
                    ZenithStatusDot(color: item.completed ? ZenithStatus.success : ZenithStatus.progress,
                                    live: item.active && !item.completed)
                    Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if item.completed {
                    Button {
                        if !NSWorkspace.shared.open(item.url) { ZenithQuiet.beep() }
                    } label: {
                        fileLabel.frame(minHeight: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(NotchButtonStyle(cornerRadius: 6, lifts: false))
                    .help(l10n.s.shelfActionOpen)
                    .accessibilityHint(l10n.s.shelfActionOpen)
                    NotchIconButton(symbol: "folder", title: l10n.s.mediaOpenInFinder) {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                    if AppFeature.shelf.isAvailable {
                        NotchIconButton(symbol: "tray.and.arrow.down", title: FeatureStrings.notch(l10n.language).files) {
                            _ = ShelfService.shared.addFiles([item.url])
                        }
                    }
                } else {
                    fileLabel
                    if let fraction = item.fraction {
                        ZenithFigure(text: fraction.formatted(.percent.precision(.fractionLength(0))), size: 15) // Zenith fork
                    }
                }
            }
            if item.completed {
                Text(text.saved).zenithIslandMeta(10).foregroundStyle(ZenithIsland.meta) // Zenith fork
                    .padding(.leading, 20) // Zenith fork: under the name
            } else {
                if let fraction = item.fraction {
                    ZenithDataBar(value: fraction) // Zenith fork: a 3-point level
                } else if item.active {
                    ProgressView().controlSize(.small)
                }
                HStack {
                    Text(item.active ? text.inProgress : "")
                    Spacer()
                    if let bytes = item.receivedBytes, bytes > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    } else if item.fraction == nil {
                        Text(text.totalUnknown)
                    }
                }.zenithIslandMeta(10).foregroundStyle(ZenithIsland.meta).lineLimit(1) // Zenith fork
            }
        }
        .padding(.horizontal, 8) // Zenith fork: a row, no card
        .padding(.vertical, 10) // Zenith fork
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .accessibilityElement(children: .contain)
    }
}

struct NotchDownloadStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var downloads = NotchDownloadService.shared
    @ObservedObject private var l10n = L10n.shared

    private var geometry: NotchGeometry { displayGeometry ?? service.compactActivityGeometry }
    /// The arrow keeps the shared gap from the top and bottom edges too.
    private var iconSize: CGFloat {
        min(17, geometry.compactActivityContentHeight - NotchLayout.compactEdgeGap * 2)
    }
    private var iconInset: CGFloat {
        geometry.compactActivityEdgeInset(boxHeight: iconSize, radius: iconSize / 2)
    }

    var body: some View {
        let item = downloads.items.first { $0.active && !$0.completed }
        Button { service.openActivity(.downloads) } label: {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    if geometry.compactActivityWingWidth >= 40 {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: iconSize))
                        if NotchDownloadSupport.showsCompactName(in: geometry) {
                            Text(item?.name ?? FeatureStrings.notchFiles(l10n.language).downloadsTitle)
                                .font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                .padding(.leading, geometry.compactActivityWingWidth >= 40 ? iconInset : 0)
                .padding(.trailing, 4)
                // Each wing anchors to its own edge, so the silhouette's curve
                // decides the margin instead of the content's own width.
                .frame(width: geometry.compactActivityWingWidth, alignment: .leading).clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                HStack(spacing: 6) {
                    // The name widens both wings; the bar fills the side the
                    // percentage alone would leave as a band of black.
                    if NotchDownloadSupport.showsCompactName(in: geometry), let fraction = item?.fraction {
                        NotchMeter(value: fraction, height: 4).padding(.leading, 4)
                    } else {
                        Spacer(minLength: 0)
                    }
                    if geometry.compactActivityWingWidth >= 36 {
                        if let fraction = item?.fraction {
                            Text(fraction, format: NotchDownloadSupport.percentFormat(l10n.language))
                                .font(.system(size: NotchDownloadSupport.percentSize, weight: .medium))
                                .monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(NotchDownloadSupport.percentMinimumScale)
                                .layoutPriority(1)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                    }
                }
                .padding(.trailing, geometry.compactActivityWingWidth >= 36
                                    ? NotchDownloadSupport.percentInset(in: geometry) : 0)
                .frame(width: geometry.compactActivityWingWidth, alignment: .trailing).clipped()
            }
            .frame(height: geometry.compactActivityContentHeight)
            .padding(.horizontal, geometry.compactActivityHorizontalPadding)
            .padding(.top, geometry.compactActivityTopPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item?.name ?? FeatureStrings.notchFiles(l10n.language).downloadsTitle)
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
