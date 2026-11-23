// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the pictures in the preview cards of the island's own pages
// (ZenithSettingsPreviewCard). Each is the real island, or its real pieces,
// drawn on ZenithPreviewDesktop with sample data: nothing here poses a
// service, reads a device or starts work, and what moves stops with
// ZenithPreviewLoop. The pages' cards are in ZenithPreviewsIslandPages.

// MARK: - Geometry

/// The island the pictures draw: this Mac's camera when it has one, else a
/// 14-inch MacBook Pro's. Read once.
@MainActor
enum ZenithPreviewIslandGeometry {
    static let notched: NotchGeometry = {
        if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let bar = screen.frame.maxY - screen.visibleFrame.maxY
            var geometry = NotchGeometry(screen: CGRect(origin: .zero, size: screen.frame.size),
                                         safeAreaTop: screen.safeAreaInsets.top, cameraWidth: max(0, right.minX - left.maxX),
                                         layout: .spacious, menuBarHeight: bar > 0 ? bar : screen.safeAreaInsets.top)
            geometry.compactSideRoom = 280
            return geometry
        }
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                     cameraWidth: 185, layout: .spacious, menuBarHeight: 32)
        geometry.compactSideRoom = 280
        return geometry
    }()

    /// How wide a band of the screen a picture shows around an island
    /// `width` points wide: close enough to read, with desktop either side.
    static func band(around width: CGFloat, minimum: CGFloat = 560) -> CGFloat {
        max(minimum, (width + 160).rounded())
    }

    /// The owner's room rule for what the pictures lay out themselves: 20
    /// points below the camera strip.
    static func contentTop(_ geometry: NotchGeometry) -> CGFloat {
        geometry.floats ? NotchLayout.bottomInset : geometry.cameraHeight + 20
    }
}

extension View {
    /// A preview card in a grouped Form's section header: in the page's own
    /// type and colours rather than the header's, and clear of the first box.
    func zenithFormPreviewCard() -> some View {
        textCase(nil)
            .foregroundStyle(.primary)
            .font(.body)
            .padding(.bottom, 8)
    }
}

// MARK: - The island

/// The island's black silhouette at `size`, hanging from the top of the
/// desktop picture, with `content` inside, drawn as the island draws it. The
/// content never takes a click; the picture's parts do.
struct ZenithPreviewIslandSurface<Content: View>: View {
    let size: CGSize
    let geometry: NotchGeometry
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape.island(height: size.height, geometry: geometry).fill(Color.black)
            content()
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(NotchShape.island(height: size.height, geometry: geometry))
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .foregroundStyle(.white)
        .tint(.white)
        .environment(\.colorScheme, .dark)
        .environment(\.notchPresentation, true)
        .environment(\.notchSettingsPreview, true)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

extension ZenithPreviewIslandSurface where Content == EmptyView {
    init(size: CGSize, geometry: NotchGeometry) {
        self.init(size: size, geometry: geometry, content: { EmptyView() })
    }
}

/// The open island on one of its sections, as Settings → Dynamic Island →
/// Content previews it (NotchIslandPreview): the real page and its top row,
/// at the island's real size around this Mac's camera. `page` draws another
/// page in the section's place (a page with sample data).
struct ZenithPreviewOpenIsland<Page: View>: View {
    let module: NotchModule
    @ViewBuilder var page: (CGSize) -> Page
    @ObservedObject private var notch = NotchService.shared

    static func size(_ module: NotchModule) -> CGSize { NotchService.shared.previewSize(for: module) }

    var body: some View {
        let geometry = notch.previewGeometry(for: module)
        let size = notch.previewSize(for: module)
        let content = geometry.contentSize(for: size)
        let band = NotchBand(geometry: geometry, contentWidth: content.width)
        let wraps = geometry.pageTop == .wrapsCamera
        ZenithPreviewIslandSurface(size: size, geometry: geometry) {
            page(content)
                .frame(width: content.width, height: content.height, alignment: .top)
                .clipped()
                .padding(.top, geometry.pageTopInset - geometry.headerTopInset)
                .overlayPreferenceValue(NotchBandKey.self, alignment: .top) { items in
                    if geometry.headerRowHeight > 0 {
                        NotchBandRow(band: band) {
                            if !wraps {
                                if band.sectionsButton { NotchSectionsButton(action: {}) }
                                items.leading
                            }
                        } trailing: {
                            items.trailing
                            if band.trailingSectionsButton { NotchSectionsButton(action: {}) }
                        }
                    }
                }
                .environment(\.notchBand, band)
                .padding(.horizontal, NotchLayout.horizontalInset)
                .padding(.top, geometry.headerTopInset)
                .padding(.bottom, NotchLayout.bottomInset)
        }
    }
}

extension ZenithPreviewOpenIsland where Page == NotchPagePreview {
    init(module: NotchModule) {
        self.init(module: module) { size in NotchPagePreview(module: module, size: size) }
    }
}

/// The island grown for a burst (a notice of Zenith's own), as the window
/// host draws it.
struct ZenithPreviewBurstIsland: View {
    let burst: ZenithIslandBurst
    let geometry: NotchGeometry

    /// Its size around this Mac's camera.
    static func size(_ content: ZenithIslandBurst.Content) -> CGSize {
        ZenithIslandBurstLayout.size(ZenithIslandBurst(content, start: .distantPast),
                                     geometry: ZenithPreviewIslandGeometry.notched)
    }

    init(_ content: ZenithIslandBurst.Content) {
        burst = ZenithIslandBurst(content, start: .distantPast)
        geometry = ZenithPreviewIslandGeometry.notched
    }

    var body: some View {
        let size = ZenithIslandBurstLayout.size(burst, geometry: geometry)
        ZenithPreviewIslandSurface(size: size, geometry: geometry) {
            ZenithIslandBurstView(burst: burst, geometry: geometry)
        }
    }
}

/// The padlock island over the lock screen (ZenithLockScreenIsland), with a
/// model of its own: face unlock's states and the remote lock. It moves
/// between them on the island's own springs and stands still once there.
/// Face unlock's animations show as stills, so no video plays in Settings.
struct ZenithPreviewLockIsland: View {
    var face: FaceUnlockIslandState = .hidden
    var moment: ZenithLockIslandMoment = .rest
    @StateObject private var model = NotchLockScreenModel()
    @StateObject private var island = ZenithLockIslandModel()

    /// The island's window on the lock screen, which the picture places.
    static var window: CGRect {
        let geometry = ZenithPreviewIslandGeometry.notched
        return ZenithLockIsland.windowFrame(around: surface, in: geometry.screen)
    }

    /// The island's shape once it settles on `face` or `moment`, for the
    /// outline around it.
    static func shape(face: FaceUnlockIslandState, moment: ZenithLockIslandMoment) -> CGSize {
        let geometry = ZenithPreviewIslandGeometry.notched
        let surface = Self.surface
        if case .remoteLock(let device) = moment {
            return ZenithLockIsland.remoteFit(device: device, camera: surface.height, resting: surface.width,
                                              screenWidth: geometry.screen.width).size
        }
        guard face != .hidden else { return surface.size }
        return FaceUnlockIslandLayout.scanSize(style: FaceUnlockIslandStyle.current(), resting: surface.size,
                                               camera: geometry.bareCutout)
    }

    private static var surface: CGRect {
        let geometry = ZenithPreviewIslandGeometry.notched
        let camera = geometry.bareCutout
        return NotchLockScreenLayout.islandSurface(
            in: geometry.screen, cameraWidth: camera.width, cameraHeight: camera.height,
            wing: geometry.lockScreenMusicGeometry.compactActivityWingWidth)
            ?? CGRect(x: geometry.screen.midX - 140, y: geometry.screen.maxY - 32, width: 280, height: 32)
    }

    var body: some View {
        let geometry = ZenithPreviewIslandGeometry.notched
        let surface = Self.surface
        let window = Self.window
        ZenithLockScreenIsland(model: model, island: island, size: surface.size,
                               cameraWidth: geometry.bareCutout.width, geometry: geometry.lockScreenMusicGeometry,
                               window: window.size,
                               origin: CGPoint(x: surface.minX - window.minX, y: window.maxY - surface.maxY),
                               stillMedia: true)
            .frame(width: window.width, height: window.height, alignment: .top)
            .environment(\.colorScheme, .dark)
            .allowsHitTesting(false)
            .onAppear {
                model.gates.music = true
                island.firstName = "Alex"
                island.faceStyle = FaceUnlockIslandStyle.current()
                island.face = face
                island.moment = moment
            }
            .onChange(of: face) { _, next in
                island.faceStyle = FaceUnlockIslandStyle.current()
                island.face = next
            }
            .onChange(of: moment) { _, next in island.moment = next }
    }
}

/// A pointer, drawn as macOS draws its arrow.
struct ZenithPreviewPointer: View {
    var body: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.black)
            .background(
                Image(systemName: "cursorarrow")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

/// Eases 0…1 in and out.
func zenithPreviewEase(_ t: Double) -> Double {
    let t = min(1, max(0, t))
    return t * t * (3 - 2 * t)
}

/// Where `phase` is between `start` and `end`, 0…1, eased.
func zenithPreviewSegment(_ phase: Double, _ start: Double, _ end: Double) -> Double {
    zenithPreviewEase((phase - start) / max(0.0001, end - start))
}

// MARK: - Dynamic Island

/// The Dynamic Island page's card: the real island on this Mac's desktop,
/// open on its home, on the section picked under Content, with a notice
/// grown out of it, being opened by the pointer, or with the companion
/// beside the camera. Its states are the page's tabs.
struct ZenithNotchPreviewCard: View {
    @Binding var tab: NotchSettingsTab
    let module: NotchModule
    let showsCompanion: Bool
    @ObservedObject private var l10n = L10n.shared

    private var text: ZenithPreviewsIslandStrings { .shared }

    private var tabs: [NotchSettingsTab] {
        [.layout, .content, .activity, .behavior] + (showsCompanion ? [.companion] : [])
    }

    var body: some View {
        let tabs = tabs
        ZenithSettingsPreviewCard(
            id: "notch", caption: caption,
            states: tabs.map(title), selection: Binding(get: { tabs.firstIndex(of: tab) ?? 0 },
                                                        set: { if tabs.indices.contains($0) { tab = tabs[$0] } }),
            highlight: highlight) {
            picture
        }
    }

    private func title(_ tab: NotchSettingsTab) -> String {
        switch tab {
        case .layout: return text.notchLayout
        case .content: return text.notchContent
        case .activity: return text.notchActivity
        case .behavior: return text.notchBehavior
        case .companion: return text.notchCompanion
        }
    }

    private var caption: String {
        switch tab {
        case .layout: return text.notchLayoutCaption
        case .content: return text.notchContentCaption
        case .activity: return text.notchActivityCaption
        case .behavior: return text.notchBehaviorCaption
        case .companion: return text.notchCompanionCaption
        }
    }

    private var highlight: String {
        switch tab {
        case .layout: return text.island
        case .content: return module.title(l10n.language)
        case .activity: return text.notices
        case .behavior: return text.opening
        case .companion: return text.companion
        }
    }

    @ViewBuilder private var picture: some View {
        switch tab {
        case .layout: open(.controls)
        case .content: open(module)
        case .activity: activity
        case .behavior: ZenithNotchOpeningPicture { tab = .behavior }
        case .companion: ZenithMascotPicture(highlighted: true) { tab = .companion }
        }
    }

    private func open(_ module: NotchModule) -> some View {
        let size = ZenithPreviewOpenIsland<NotchPagePreview>.size(module)
        return ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: size.width, minimum: 720)) {
            ZenithPreviewOpenIsland(module: module)
                .zenithPreviewPart(cornerRadius: 22, highlighted: true) { tab = module == .controls ? .layout : .content }
        }
        .id(module)
    }

    private var activity: some View {
        let content = ZenithIslandBurst.Content.charge(
            ZenithChargeBurst.make(.charging, percent: 82, minutes: 34, island: ZenithStrings.island(.enUS),
                                   notices: ZenithStrings.notices(.enUS), locale: Locale(identifier: "en_US")))
        let size = ZenithPreviewBurstIsland.size(content)
        return ZenithPreviewDesktop(screenWidth: ZenithPreviewIslandGeometry.band(around: size.width, minimum: 640)) {
            ZenithPreviewBurstIsland(content)
                .zenithPreviewPart(cornerRadius: 18, highlighted: true) { tab = .activity }
        }
    }
}

/// The island open on its home, built once: the loop around it only fades it.
private struct ZenithPreviewOpenHome: View, Equatable {
    var body: some View { ZenithPreviewOpenIsland(module: .controls) }
}

/// The pointer reaching the closed island, which opens on its home and
/// closes again as the pointer leaves. A loop.
struct ZenithNotchOpeningPicture: View {
    var action: () -> Void

    var body: some View {
        let geometry = ZenithPreviewIslandGeometry.notched
        let closed = geometry.restingSize(showsContent: false)
        let open = ZenithPreviewOpenIsland<NotchPagePreview>.size(.controls)
        let screen = ZenithPreviewIslandGeometry.band(around: open.width, minimum: 720)
        ZenithPreviewDesktop(screenWidth: screen) {
            ZenithPreviewLoop(period: 4.5, stillPhase: 0.65) { phase in
                // In 0…0.3, rests 0.3…0.4, grows 0.4…0.55, open till 0.8, closes, leaves.
                let grow = zenithPreviewSegment(phase, 0.38, 0.52) - zenithPreviewSegment(phase, 0.8, 0.92)
                let size = CGSize(width: closed.width + (open.width - closed.width) * grow,
                                  height: closed.height + (open.height - closed.height) * grow)
                let arrive = zenithPreviewSegment(phase, 0.05, 0.35) - zenithPreviewSegment(phase, 0.85, 1)
                let rest = CGPoint(x: screen / 2 + 260, y: 200)
                let target = CGPoint(x: screen / 2 + 30, y: closed.height * 0.6)
                let shown = zenithPreviewSegment(phase, 0.5, 0.56) - zenithPreviewSegment(phase, 0.76, 0.8)
                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .top) {
                        ZenithPreviewIslandSurface(size: size, geometry: geometry)
                        ZenithPreviewOpenHome()
                            .equatable()
                            .opacity(shown)
                    }
                    .frame(width: open.width, height: open.height, alignment: .top)
                    .zenithPreviewPart(cornerRadius: 16, highlighted: true, action: action)
                    .frame(width: screen, alignment: .top)
                    ZenithPreviewPointer()
                        .offset(x: rest.x + (target.x - rest.x) * arrive, y: rest.y + (target.y - rest.y) * arrive)
                }
                .frame(width: screen, alignment: .topLeading)
            }
        }
    }
}

// MARK: - Companion

/// The closed island with the companion resting beside the camera, in the
/// look chosen and asleep while it is switched off, close up.
struct ZenithMascotPicture: View {
    var highlighted = true
    var action: () -> Void
    @AppStorage(DefaultsKey.notchMascotEnabled) private var enabled = false
    @AppStorage(DefaultsKey.notchMascotStyle) private var style = NotchMascotStyle.satuVisual.rawValue
    @AppStorage(DefaultsKey.notchMascotShape) private var shape = NotchMascotShape.ball.rawValue
    @AppStorage(DefaultsKey.notchMascotPalette) private var palette = NotchMascotPalette.pearl.rawValue
    @AppStorage(DefaultsKey.notchMascotSide) private var side = NotchMascotSide.left.rawValue

    private var look: NotchMascotLook {
        NotchMascotLook(style: NotchMascotStyle(rawValue: style) ?? .satuVisual,
                        shape: NotchMascotShape(rawValue: shape) ?? .ball,
                        palette: NotchMascotPalette(rawValue: palette) ?? .pearl)
    }

    var body: some View {
        let model = NotchMascotStageModel(side: NotchMascotSide(rawValue: side) ?? .left)
        let track = model.track
        ZenithPreviewDesktop(screenWidth: max(560, model.strip.width + 200)) {
            model.shape(height: model.strip.height)
                .fill(Color.black)
                .frame(width: model.strip.width, height: model.strip.height)
                .overlay(alignment: .top) {
                    NotchMascotTrackView(look: look, track: track, rests: true, visit: nil, mood: .idle,
                                         reaction: nil, awake: enabled)
                        .frame(width: track.width, height: track.height)
                        .allowsHitTesting(false)
                }
                .clipShape(model.shape(height: model.strip.height))
                .zenithPreviewPart(cornerRadius: 12, highlighted: highlighted, action: action)
        }
    }
}

/// The Companion page's own card, when it shows as a page of its own (as a
/// tab of the Dynamic Island page, that page's card shows it).
struct ZenithMascotPreviewCard: View {
    var action: () -> Void

    var body: some View {
        let text = ZenithPreviewsIslandStrings.shared
        ZenithSettingsPreviewCard(id: "notchMascot", caption: text.companionCaption, highlight: text.companion) {
            ZenithMascotPicture(action: action)
        }
    }
}
