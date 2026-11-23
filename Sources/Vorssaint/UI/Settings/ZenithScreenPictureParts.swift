// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the pieces the screen previews are drawn from (see
// ZenithScreenPreviews): a desktop with its own menu bar, windows, the menu
// bar panel, the island, the Dock, app icons, a pointer and notices. All
// sizes are screen points on the preview's virtual screen.

enum ZenithScreenPictureMetrics {
    /// How wide a screen the pictures show.
    static let width: CGFloat = 800

    /// `phase` eased from 0 at `start` to 1 at `end`.
    static func step(_ phase: Double, _ start: Double, _ end: Double) -> CGFloat {
        let t = min(max((phase - start) / (end - start), 0), 1)
        return CGFloat(t * t * (3 - 2 * t))
    }

    /// Up from 0 to 1 between `a` and `b`, back down between `c` and `d`.
    static func pulse(_ phase: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> CGFloat {
        step(phase, a, b) * (1 - step(phase, c, d))
    }
}

extension View {
    /// Places the view with its top edge at `top` and its centre at `x`,
    /// whatever its height, as a panel hangs from the menu bar.
    func pinnedTop(x: CGFloat, top: CGFloat) -> some View {
        frame(height: 1000, alignment: .top).position(x: x, y: top + 500)
    }
}

/// A desktop of the preview's width with its own menu bar, so the status
/// items a feature adds sit among the usual ones. `content` gets the
/// screen's size and places its parts with `.position`.
struct ZenithScreenDesktop<Extra: View, Content: View>: View {
    var zenithActive = false
    var menuBar = true
    @ViewBuilder var extra: () -> Extra
    @ViewBuilder var content: (CGSize) -> Content

    var body: some View {
        // The screen's height follows the card's shape; measured here, since
        // the wallpaper filling the desktop can be taller than the screen.
        GeometryReader { geo in
            let width = ZenithScreenPictureMetrics.width
            let screen = CGSize(width: width, height: width * geo.size.height / max(geo.size.width, 1))
            // The menu bar under the content: the island hangs over it, and
            // a dimmed screen dims it too.
            ZenithPreviewDesktop(screenWidth: width, menuBar: false) {
                ZStack(alignment: .topLeading) { content(screen) }
                    .frame(width: screen.width, height: screen.height, alignment: .topLeading)
                    .background(alignment: .top) {
                        if menuBar { ZenithScreenMenuBar(zenithActive: zenithActive, extra: extra) }
                    }
            }
        }
    }
}

extension ZenithScreenDesktop where Extra == EmptyView {
    init(zenithActive: Bool = false, menuBar: Bool = true, @ViewBuilder content: @escaping (CGSize) -> Content) {
        self.init(zenithActive: zenithActive, menuBar: menuBar, extra: { EmptyView() }, content: content)
    }
}

/// The shared card's menu bar (ZenithPreviewMenuBar) with room for status
/// items left of Zenith's, and Zenith's item as this Mac draws it: the
/// symbol picked in General › Menu bar, or the mark.
struct ZenithScreenMenuBar<Extra: View>: View {
    var zenithActive = false
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 15, weight: .medium))
            Text(verbatim: "Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View", "Go"], id: \.self) { Text(verbatim: $0).font(.system(size: 13)) }
            Spacer()
            extra()
            ZenithScreenZenithItem(active: zenithActive)
            Image(systemName: "battery.75percent").font(.system(size: 14))
            Image(systemName: "wifi").font(.system(size: 13, weight: .medium))
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
            Text(verbatim: "Mon 23 Nov  9.41").font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: ZenithPreviewDesktop<EmptyView>.menuBarHeight)
        .background(.black.opacity(0.25))
    }
}

/// Zenith's own status item.
struct ZenithScreenZenithItem: View {
    var active = false
    var size: CGFloat = 14
    @AppStorage(DefaultsKey.menuBarIconSymbol) private var symbol = ""

    var body: some View {
        let name = Defaults.sanitizedMenuBarIconSymbol(symbol)
        if !name.isEmpty {
            Image(systemName: name).font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? Color.orange : .white)
        } else if let glyph = BlackHoleGlyph.image(active: active) {
            Image(nsImage: glyph).renderingMode(active ? .original : .template)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(height: size * 1.15)
        } else {
            Image(systemName: "asterisk").font(.system(size: size, weight: .bold))
        }
    }
}

/// The island at the camera, black, with whatever it shows either side.
struct ZenithScreenIsland<Leading: View, Trailing: View>: View {
    var width: CGFloat = 220
    var height: CGFloat = 32
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(width: width, height: height)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 13, bottomTrailingRadius: 13, style: .continuous)
            .fill(.black))
    }
}

/// An app's icon: a rounded square in its color with a symbol.
struct ZenithScreenAppIcon: View {
    let app: ZenithScreenApp
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(LinearGradient(colors: [app.color.opacity(0.85), app.color], startPoint: .top, endPoint: .bottom))
            .overlay(Image(systemName: app.symbol).font(.system(size: size * 0.48, weight: .semibold)).foregroundStyle(.white))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}

/// The sample apps the pictures use.
struct ZenithScreenApp: Hashable {
    let symbol: String
    let color: Color
    let name: String

    private static var text: ZenithPreviewsScreenStrings { .shared }
    static let finder = ZenithScreenApp(symbol: "face.smiling", color: Color(red: 0.2, green: 0.55, blue: 0.95), name: "Finder")
    static var safari: ZenithScreenApp { .init(symbol: "safari", color: Color(red: 0.15, green: 0.5, blue: 0.95), name: text.appSafari) }
    static var music: ZenithScreenApp { .init(symbol: "music.note", color: Color(red: 0.98, green: 0.25, blue: 0.4), name: text.appMusic) }
    static var mail: ZenithScreenApp { .init(symbol: "envelope.fill", color: Color(red: 0.2, green: 0.6, blue: 1), name: text.appMail) }
    static var notes: ZenithScreenApp { .init(symbol: "note.text", color: Color(red: 0.98, green: 0.78, blue: 0.2), name: text.appNotes) }
    static var zoom: ZenithScreenApp { .init(symbol: "video.fill", color: Color(red: 0.18, green: 0.45, blue: 0.98), name: text.appZoom) }
    static var figma: ZenithScreenApp { .init(symbol: "pencil.and.outline", color: Color(red: 0.55, green: 0.3, blue: 0.95), name: text.appFigma) }
    static var arc: ZenithScreenApp { .init(symbol: "circle.hexagonpath.fill", color: Color(red: 0.95, green: 0.35, blue: 0.45), name: text.appArc) }
    static var raycast: ZenithScreenApp { .init(symbol: "bolt.fill", color: Color(red: 0.95, green: 0.3, blue: 0.25), name: text.appRaycast) }
    static var terminal: ZenithScreenApp { .init(symbol: "terminal.fill", color: Color(white: 0.25), name: text.appTerminal) }
    static var dock: [ZenithScreenApp] { [.finder, .safari, .mail, .music, .notes, .figma, .terminal] }
}

/// A Mac window: the title bar's buttons, a sidebar and some lines of
/// content. `greenPart` outlines the green button and opens its settings.
struct ZenithScreenWindow: View {
    var title = ""
    var tint: Color = .blue
    var sidebar = true
    var greenPart: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
                green
                Text(verbatim: title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.leading, 6).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(height: 26)
            HStack(alignment: .top, spacing: 0) {
                if sidebar {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([46, 58, 40, 52], id: \.self) { width in
                            Capsule().fill(Color.primary.opacity(0.14)).frame(width: CGFloat(width), height: 6)
                        }
                    }
                    .padding(12)
                    .frame(width: 86, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color.primary.opacity(0.04))
                }
                VStack(alignment: .leading, spacing: 9) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.55)).frame(height: 38)
                    ForEach([1.0, 0.8, 0.92, 0.6, 0.85, 0.7], id: \.self) { fraction in
                        GeometryReader { geo in
                            Capsule().fill(Color.primary.opacity(0.12)).frame(width: geo.size.width * fraction, height: 6)
                        }
                        .frame(height: 6)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(ZenithScreenSurface.window)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
    }

    @ViewBuilder private var green: some View {
        let button = Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 10, height: 10)
        if let greenPart {
            button.zenithPreviewPart(cornerRadius: 8, highlighted: true, action: greenPart)
        } else {
            button
        }
    }
}

/// A window drawn small, for previews and thumbnails: it takes any size.
struct ZenithScreenThumbnail: View {
    var tint: Color = .blue

    var body: some View {
        GeometryReader { geo in
            let unit = max(geo.size.height / 10, 3)
            VStack(alignment: .leading, spacing: unit * 0.7) {
                HStack(spacing: unit * 0.45) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18),
                             Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) { color in
                        Circle().fill(color).frame(width: unit * 0.8, height: unit * 0.8)
                    }
                }
                RoundedRectangle(cornerRadius: unit * 0.5, style: .continuous).fill(tint.opacity(0.6))
                    .frame(height: unit * 2.4)
                ForEach([0.9, 0.7, 0.8], id: \.self) { fraction in
                    Capsule().fill(Color.primary.opacity(0.14))
                        .frame(width: (geo.size.width - unit * 2) * fraction, height: unit * 0.55)
                }
            }
            .padding(unit)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(ZenithScreenSurface.window)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }
}

enum ZenithScreenSurface {
    /// A window's background in the current appearance.
    static let window = Color(nsColor: .windowBackgroundColor)
    /// The menu bar panel's background, as the panel draws it.
    static func panel(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(white: 0.11) : Color(white: 0.97) }
}

/// Zenith's menu bar panel: the mark, the strip of section tabs, a section's
/// title and its card. `tabsPart` outlines the strip.
struct ZenithScreenPanel<Content: View>: View {
    var selected: PanelSectionID?
    var title: String
    var width: CGFloat = 290
    var tabsPart: (() -> Void)?
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var scheme
    @AppStorage(DefaultsKey.panelSectionOrder) private var order = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ZenithScreenZenithItem(size: 24)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
            tabs
            Text(title.uppercased())
                .font(ZenithType.mono(10.5, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        }
        .padding(14)
        .frame(width: width, alignment: .topLeading)
        .background(ZenithScreenSurface.panel(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }

    /// The panel's tabs in this Mac's order, as many as fit.
    private var sections: [PanelSectionID] {
        let _ = order
        // WakaTime's tab needs its key file read; the picture leaves it out.
        let shown = PanelLayout.order.filter { $0 != .wakatime && PanelLayout.isVisibleInPanel($0) }
        var result = Array(shown.prefix(9))
        if let selected, !result.contains(selected) { result[result.count > 0 ? result.count - 1 : 0] = selected }
        return result.isEmpty ? [selected ?? .keepAwake] : result
    }

    @ViewBuilder private var tabs: some View {
        let strip = HStack(spacing: 0) {
            ForEach(sections) { section in
                Image(systemName: section.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(section == selected ? Color.accentColor : .primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(section == selected ? Color.accentColor.opacity(0.16) : .clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        if let tabsPart {
            strip.zenithPreviewPart(cornerRadius: 14, highlighted: true, action: tabsPart)
        } else {
            strip
        }
    }
}

/// A row in a panel card: an icon, a title, a detail and a trailing view.
struct ZenithScreenPanelRow<Trailing: View>: View {
    var app: ZenithScreenApp?
    var symbol: String?
    let title: String
    var detail: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 9) {
            if let app {
                ZenithScreenAppIcon(app: app, size: 24)
            } else if let symbol {
                Image(systemName: symbol).font(.system(size: 14)).frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: title).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                if let detail {
                    Text(verbatim: detail).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            trailing()
        }
    }
}

/// A slider's track filled to `value`.
struct ZenithScreenLevel: View {
    var value: CGFloat
    var width: CGFloat = 110
    var tint: Color = .accentColor

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.12))
            Capsule().fill(tint).frame(width: max(6, width * min(max(value, 0), 1)))
        }
        .frame(width: width, height: 6)
    }
}

/// A dark notice in the style of the island's and the system's HUDs.
struct ZenithScreenNotice: View {
    let symbol: String
    var tint: Color = .white
    let title: String
    var detail: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.system(size: 14, weight: .semibold))
                if let detail {
                    Text(verbatim: detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(Color(white: 0.12).opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
        .fixedSize()
    }
}

/// The Dock, with its icons and the dot under running apps.
struct ZenithScreenDockBar: View {
    var apps: [ZenithScreenApp] = ZenithScreenApp.dock
    var size: CGFloat = 40
    /// The icon outlined as a part of the picture.
    var part: (index: Int, action: () -> Void)?
    var lifted: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                VStack(spacing: 3) {
                    icon(app, index: index)
                        .offset(y: lifted == index ? -6 : 0)
                    Circle().fill(.white.opacity(index < 4 ? 0.8 : 0)).frame(width: 3.5, height: 3.5)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 3)
        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.25)))
    }

    @ViewBuilder private func icon(_ app: ZenithScreenApp, index: Int) -> some View {
        if let part, part.index == index {
            ZenithScreenAppIcon(app: app, size: size).zenithPreviewPart(cornerRadius: 12, highlighted: true, action: part.action)
        } else {
            ZenithScreenAppIcon(app: app, size: size)
        }
    }

    /// The x of icon `index`'s centre from the bar's leading edge.
    static func iconCenter(_ index: Int, size: CGFloat = 40) -> CGFloat { 8 + size / 2 + CGFloat(index) * (size + 8) }
    static func width(count: Int, size: CGFloat = 40) -> CGFloat { 16 + CGFloat(count) * size + CGFloat(max(count - 1, 0)) * 8 }
}

/// The pointer.
struct ZenithScreenPointer: View {
    var symbol = "cursorarrow"

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.black)
            .shadow(color: .white, radius: 0.6)
            .shadow(color: .white, radius: 0.6)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

/// A key on the keyboard, pressed while `down`.
struct ZenithScreenKey: View {
    let label: String
    var symbol: String?
    var down = false

    var body: some View {
        Group {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium))
            } else {
                Text(verbatim: label).font(.system(size: 15, weight: .medium))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 42, height: 38)
        .background(Color(white: down ? 0.32 : 0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.18)))
        .shadow(color: .black.opacity(0.35), radius: down ? 1 : 3, y: down ? 0 : 2)
        .scaleEffect(down ? 0.94 : 1)
    }
}

/// A small black strip like the menu bar, drawn larger in the middle of a
/// picture so its items can be read.
struct ZenithScreenMenuBarLens<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 14) { content() }
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .fixedSize()
    }
}
