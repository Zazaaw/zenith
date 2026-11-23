// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Zenith fork: the preview cards of Face Unlock, iPhone Remote, Batteries,
// Shelf, Workspaces and the Command Bar (ZenithSettingsPreviewCard), drawn
// with the pieces in ZenithPreviewsIsland and sample data only.

// MARK: - Face Unlock

/// The padlock island on the lock screen while face unlock scans, matches or
/// fails, in the animation style chosen on the page.
struct ZenithFaceUnlockPreviewCard: View {
    var action: () -> Void
    @State private var state = 0

    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        let captions = [text.faceScanningCaption, text.faceSuccessCaption, text.faceFailureCaption]
        let faces: [FaceUnlockIslandState] = [.scanning, .success, .failure(.wrongFace)]
        ZenithSettingsPreviewCard(id: "faceUnlock", caption: captions[state],
                                  states: [text.faceScanning, text.faceSuccess, text.faceFailure], selection: $state,
                                  highlight: text.faceAnimation) {
            ZenithLockIslandPicture(face: faces[state], action: action)
        }
    }
}

/// The lock screen (this Mac's wallpaper, no menu bar) with the padlock island.
struct ZenithLockIslandPicture: View {
    var face: FaceUnlockIslandState = .hidden
    var moment: ZenithLockIslandMoment = .rest
    var action: () -> Void

    var body: some View {
        let window = ZenithPreviewLockIsland.window
        ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: window.width * 0.62, minimum: 600),
                             menuBar: false) {
            ZenithPreviewLockIsland(face: face, moment: moment)
                .frame(width: window.width, height: window.height, alignment: .top)
                .overlay(alignment: .top) {
                    // The part to click: the island where it settles.
                    let shape = ZenithPreviewLockIsland.shape(face: face, moment: moment)
                    Color.clear
                        .frame(width: shape.width, height: shape.height)
                        .zenithPreviewPart(cornerRadius: 22, highlighted: true, action: action)
                }
        }
    }
}

// MARK: - iPhone Remote

/// Locked from an iPhone (the lock screen's island), or the iPhone checking
/// on the Mac (a burst from the desktop island).
struct ZenithRemotePreviewCard: View {
    var action: () -> Void
    @State private var state = 0

    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        ZenithSettingsPreviewCard(id: "remote", caption: state == 0 ? text.remoteLockedCaption : text.remoteStatusCaption,
                                  states: [text.remoteLocked, text.remoteStatus], selection: $state,
                                  highlight: text.remote) {
            if state == 0 {
                ZenithLockIslandPicture(moment: .remoteLock(device: text.remoteDevice), action: action)
            } else {
                let content = ZenithIslandBurst.Content.remote(ZenithRemoteBurst(device: text.remoteDevice))
                ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(
                    around: ZenithPreviewBurstIsland.size(content).width, minimum: 640)) {
                    ZenithPreviewBurstIsland(content)
                        .zenithPreviewPart(cornerRadius: 18, highlighted: true, action: action)
                }
            }
        }
    }
}

// MARK: - Batteries

/// The Batteries page in the open island, the Battery Low card, and the
/// compact form it leaves in the closed island, with sample readings.
struct ZenithBatteriesPreviewCard: View {
    @Binding var state: Int
    var openLook: () -> Void
    var openAlerts: () -> Void

    static let page = 0, low = 1, compact = 2

    private static var lowDevice: BatteryDevice {
        BatteriesStore.sample.first { $0.id == "sample-gamepad" } ?? BatteriesStore.sample[0]
    }

    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        let captions = [text.batteriesPageCaption, text.batteriesLowCaption, text.batteriesCompactCaption]
        ZenithSettingsPreviewCard(id: "batteries", caption: captions[min(state, 2)],
                                  states: [text.batteriesPage, text.batteriesLow, text.batteriesCompact], selection: $state,
                                  highlight: state == Self.page ? text.batteriesLook : text.batteriesAlerts) {
            switch state {
            case Self.low: low
            case Self.compact: compact
            default: page
            }
        }
    }

    private var page: some View {
        let size = ZenithPreviewOpenIsland<NotchPagePreview>.size(.batteries)
        return ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: size.width, minimum: 720)) {
            ZenithPreviewOpenIsland(module: .batteries) { size in
                BatteriesPage(size: size, sample: BatteriesStore.sample)
            }
            .zenithPreviewPart(cornerRadius: 22, highlighted: true, action: openLook)
        }
    }

    private var low: some View {
        let device = Self.lowDevice
        let alert = BatteriesLowAlert(id: UUID(), device: device, percent: device.percent ?? 0, others: [])
        let content = ZenithIslandBurst.Content.batteryLow(
            BatteriesIslandSupport.lowBurst(alert, text: ZenithStrings.batteriesIsland(.enUS)))
        return ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(
            around: ZenithPreviewBurstIsland.size(content).width, minimum: 640)) {
            ZenithPreviewBurstIsland(content)
                .zenithPreviewPart(cornerRadius: 18, highlighted: true, action: openAlerts)
        }
    }

    private var compact: some View {
        let device = Self.lowDevice
        let indicator = BatteriesLowIndicator(deviceID: device.id, name: device.name, symbol: device.symbolName,
                                              percent: device.percent ?? 0, since: Date())
        let base = ZenithPreviewIslandGeometry.notched
        let geometry = base.compactWatchGeometry(wing: BatteriesStripLayout.stripWing(indicator, in: base))
        let size = geometry.compactActivitySize
        return ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: size.width, minimum: 520)) {
            ZenithPreviewIslandSurface(size: size, geometry: geometry) {
                BatteriesStripContent(indicator: indicator, geometry: geometry)
                    .padding(.horizontal, geometry.compactActivityHorizontalPadding)
                    .padding(.top, geometry.compactActivityTopPadding)
            }
            .zenithPreviewPart(cornerRadius: 12, highlighted: true, action: openAlerts)
        }
    }
}

// MARK: - Shelf

/// A file dragged up to the island, which opens on its drop zones; the zone
/// it lands on lights up. A loop.
struct ZenithShelfPreviewCard: View {
    let targets: [NotchDropTarget]
    var action: () -> Void
    @State private var state = 0

    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        let target: NotchDropTarget = state == 1 && targets.contains(.airDrop) ? .airDrop : .files
        ZenithSettingsPreviewCard(id: "shelf", caption: state == 1 ? text.shelfAirDropCaption : text.shelfFilesCaption,
                                  states: [text.shelfFiles, text.shelfAirDrop], selection: $state,
                                  highlight: text.dropZones) {
            ZenithShelfDropPicture(targets: targets, landing: target, action: action)
        }
    }
}

struct ZenithShelfDropPicture: View {
    let targets: [NotchDropTarget]
    let landing: NotchDropTarget
    var action: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let geometry = ZenithPreviewIslandGeometry.notched
        let count = max(1, targets.count)
        let content = CGSize(width: ZenithDropZoneLayout.contentWidth(count: max(count, ZenithDropZoneLayout.widensFrom),
                                                                       maximum: 600) ?? 400,
                             height: 104)
        let top = ZenithPreviewIslandGeometry.contentTop(geometry)
        let size = NotchLayout.flared(CGSize(width: content.width + NotchLayout.horizontalInset * 2,
                                             height: top + content.height + NotchLayout.bottomInset))
        let frames = ZenithDropZoneLayout.frames(count: count, in: content)
        let index = targets.firstIndex(of: landing) ?? 0
        let screen = ZenithPreviewIslandGeometry.band(around: size.width, minimum: 760)
        ZenithPreviewDesktop(screenWidth: screen) {
            ZenithPreviewLoop(period: 3.6, stillPhase: 0.62) { phase in
                // The file comes up 0…0.45, hovers its zone till 0.85, then fades back.
                let lift = zenithPreviewSegment(phase, 0, 0.45)
                let over = phase > 0.42 && phase < 0.9
                let fade = 1 - zenithPreviewSegment(phase, 0.86, 0.98)
                let tile = frames.indices.contains(index) ? frames[index] : .zero
                let origin = CGPoint(x: (screen - size.width) / 2 + (size.width - content.width) / 2, y: top)
                let goal = CGPoint(x: origin.x + tile.midX + 24, y: origin.y + tile.midY + 30)
                let start = CGPoint(x: screen / 2 + 240, y: size.height + 160)
                ZStack(alignment: .topLeading) {
                    ZenithPreviewIslandSurface(size: size, geometry: geometry) {
                        ZStack(alignment: .topLeading) {
                            ForEach(Array(targets.enumerated()), id: \.element) { offset, target in
                                if frames.indices.contains(offset) {
                                    ZenithDropZoneTile(target: target, language: l10n.language,
                                                       selected: over && target == landing,
                                                       dimmed: over && target != landing, index: offset,
                                                       animatesEntrance: false)
                                        .frame(width: frames[offset].width, height: frames[offset].height)
                                        .position(x: frames[offset].midX, y: frames[offset].midY)
                                }
                            }
                        }
                        .frame(width: content.width, height: content.height, alignment: .topLeading)
                        .padding(.top, top)
                    }
                    .zenithPreviewPart(cornerRadius: 22, highlighted: true, action: action)
                    .frame(width: screen, alignment: .top)
                    ZenithPreviewDraggedFile()
                        .opacity(fade)
                        .position(x: start.x + (goal.x - start.x) * lift, y: start.y + (goal.y - start.y) * lift)
                }
                .frame(width: screen, alignment: .topLeading)
            }
        }
    }
}

/// A document being dragged, with the pointer holding it.
private struct ZenithPreviewDraggedFile: View {
    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: NSWorkspace.shared.icon(for: .pdf))
                .resizable()
                .frame(width: 44, height: 44)
            Text(ZenithPreviewsIslandStrings.shared.sampleFile)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.accentColor, in: Capsule())
        }
        .opacity(0.9)
        .overlay(alignment: .topLeading) { ZenithPreviewPointer().offset(x: 18, y: 14) }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Workspaces

/// A workspace run from the island: the tile spins, then its apps' windows
/// slide into the places it keeps for them. A loop.
struct ZenithWorkspacesPreviewCard: View {
    var action: () -> Void

    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        ZenithSettingsPreviewCard(id: "workspaces", caption: text.workspacesCaption, highlight: text.workspacesList) {
            ZenithWorkspacesPicture(action: action)
        }
    }
}

private struct ZenithWorkspacesPicture: View {
    var action: () -> Void
    private static let tiles: [(symbol: String, color: WorkspaceColor)] = [
        ("paintbrush.pointed", .violet), ("chevron.left.forwardslash.chevron.right", .blue), ("video", .green),
    ]

    var body: some View {
        let geometry = ZenithPreviewIslandGeometry.notched
        let text = ZenithPreviewsIslandStrings.shared
        let top = ZenithPreviewIslandGeometry.contentTop(geometry)
        let card = CGSize(width: 252, height: 82)
        let size = NotchLayout.flared(CGSize(width: max(card.width + NotchLayout.horizontalInset * 2, geometry.cameraWidth + 220),
                                             height: top + card.height + NotchLayout.bottomInset))
        let screen: CGFloat = 820
        ZenithPreviewDesktop(screenWidth: screen) {
            ZenithPreviewLoop(period: 5, stillPhase: 0.8) { phase in
                let running = phase > 0.12 && phase < 0.4
                let left = zenithPreviewSegment(phase, 0.36, 0.56) - zenithPreviewSegment(phase, 0.9, 1)
                let right = zenithPreviewSegment(phase, 0.44, 0.64) - zenithPreviewSegment(phase, 0.9, 1)
                ZStack(alignment: .top) {
                    ZenithPreviewAppWindow(tint: WorkspaceColor.violet.hex)
                        .frame(width: 330, height: 210)
                        .offset(x: -178 - 240 * (1 - left), y: size.height + 24)
                        .opacity(left)
                    ZenithPreviewAppWindow(tint: WorkspaceColor.blue.hex)
                        .frame(width: 330, height: 210)
                        .offset(x: 178 + 240 * (1 - right), y: size.height + 24)
                        .opacity(right)
                    ZenithPreviewIslandSurface(size: size, geometry: geometry) {
                        VStack(alignment: .leading, spacing: 6) {
                            ZenithHomeWidgetHeader(widget: .workspaces, title: text.workspacesList)
                            HStack(spacing: 6) {
                                ForEach(Array(Self.tiles.enumerated()), id: \.offset) { index, tile in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            ZenithIslandGlyphTile(symbol: tile.symbol,
                                                                  tint: ZenithIslandPalette.color(hex: tile.color.hex), size: 24)
                                                .opacity(running && index == 0 ? 0 : 1)
                                            if running && index == 0 { ProgressView().controlSize(.mini) }
                                        }
                                        .frame(width: 24, height: 24)
                                        Text(text.sampleWorkspaces[index])
                                            .font(.system(size: 10.5, weight: .medium))
                                            .foregroundStyle(ZenithIsland.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(index == 0 && phase > 0.06 && phase < 0.4 ? 0.14 : 0.06),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                        .padding(12)
                        .frame(width: card.width, height: card.height, alignment: .topLeading)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: ZenithIsland.cardRadius,
                                                                                style: .continuous))
                        .padding(.top, top)
                    }
                    .zenithPreviewPart(cornerRadius: 22, highlighted: true, action: action)
                }
                .frame(width: screen, alignment: .top)
            }
        }
    }
}

/// An app's window: a title bar with its lights over a few lines of content.
private struct ZenithPreviewAppWindow: View {
    let tint: UInt32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 10, height: 10) }
            }
            RoundedRectangle(cornerRadius: 6).fill(ZenithIslandPalette.color(hex: tint).opacity(0.55)).frame(height: 90)
            ForEach(0..<3, id: \.self) { line in
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.16))
                    .frame(width: line == 2 ? 180 : nil, height: 10)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(white: 0.16).opacity(0.95), in: shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}

// MARK: - Command Bar

/// The Command Bar dropping out of the island, a question typed into it and
/// its answer. A loop.
struct ZenithCommandBarPreviewCard: View {
    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        ZenithSettingsPreviewCard(id: "commandBar", caption: text.commandBarCaption) {
            ZenithCommandBarPicture()
        }
    }
}

private struct ZenithCommandBarPicture: View {
    var body: some View {
        let geometry = ZenithPreviewIslandGeometry.notched
        let text = ZenithPreviewsIslandStrings.shared
        let closed = geometry.restingSize(showsContent: false)
        let screen: CGFloat = 680
        ZenithPreviewDesktop(screenWidth: screen) {
            ZenithPreviewLoop(period: 5, stillPhase: 0.75) { phase in
                let drop = zenithPreviewSegment(phase, 0.04, 0.24) - zenithPreviewSegment(phase, 0.92, 1)
                let typed = Int((Double(text.commandBarQuery.count) * zenithPreviewSegment(phase, 0.28, 0.52)).rounded())
                let answer = zenithPreviewSegment(phase, 0.54, 0.62)
                let query = String(text.commandBarQuery.prefix(typed))
                ZStack(alignment: .top) {
                    ZenithPreviewIslandSurface(size: closed, geometry: geometry)
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            BrandMark(width: 20).opacity(0.85)
                            Text(query.isEmpty ? " " : query)
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                            Rectangle().fill(Color.accentColor).frame(width: 2, height: 22)
                                .opacity(phase.truncatingRemainder(dividingBy: 0.1) < 0.05 ? 1 : 0.2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 17)
                        .frame(height: CommandBarView.fieldHeight)
                        if answer > 0 {
                            Divider().overlay(.white.opacity(0.1))
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.accentColor.opacity(0.8),
                                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(text.commandBarAnswer).font(.system(size: 15, weight: .semibold))
                                    Text(text.commandBarAnswerDetail).font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Text(text.commandBarCopy)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.white.opacity(0.08), in: Capsule())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(8)
                            .opacity(answer)
                        }
                    }
                    .frame(width: CommandBarView.width)
                    .foregroundStyle(.white)
                    .background(Color(white: 0.1).opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12)))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .environment(\.colorScheme, .dark)
                    .scaleEffect(0.4 + 0.6 * drop, anchor: .top)
                    .offset(y: closed.height + 18 + 70 * drop)
                    .opacity(drop)
                }
                .frame(width: screen, alignment: .top)
            }
        }
    }
}
