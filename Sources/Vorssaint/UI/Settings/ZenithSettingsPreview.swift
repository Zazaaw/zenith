// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import ImageIO
import SwiftUI

// Zenith fork: the preview card every Settings page opens with, in the style
// of the Lock Screen page: a picture of what the page changes on the left
// (the real island, the part of the screen it touches, or a looping
// illustration), and beside it a "Preview" column with the states to look
// at, a line on what the picture shows, and which part is outlined. Clicking
// an outlined part of the picture opens the settings for it. The card folds
// away, and each page remembers whether it is folded.
//
// The pieces:
// - `ZenithSettingsPreviewCard`: the card itself.
// - `ZenithPreviewDesktop`: this Mac's wallpaper with a menu bar, for
//   pictures of the island, the menu bar, panels and windows. Content is laid
//   out in screen points on a virtual screen and scaled to the card.
// - `ZenithPreviewLoop`: a 0…1 phase for looping illustrations that stops
//   while the window is hidden or Reduce Motion is on.
// - `.zenithPreviewPart(_:highlighted:action:)`: outlines a part of the
//   picture and makes it clickable.

/// The card's text. English in every language, like the rest of Zenith's own pages.
struct ZenithSettingsPreviewStrings {
    let preview = "Preview"
    let click = "Click a part of the preview to open its settings."
    let show = "Show preview"
    let hide = "Hide preview"
    func highlighted(_ part: String) -> String { "Highlighted: \(part)" }

    static let shared = ZenithSettingsPreviewStrings()
}

/// The preview card at the top of a Settings page.
///
///     ZenithSettingsPreviewCard(id: "batteries", caption: "…",
///                               states: ["Page", "Low", "Compact"], selection: $state,
///                               highlight: "Layout") {
///         ZenithPreviewDesktop { … }
///     }
struct ZenithSettingsPreviewCard<Picture: View, Footer: View>: View {
    private let caption: String
    private let states: [String]
    private let selection: Binding<Int>?
    private let highlight: String?
    private let aspectRatio: CGFloat
    private let picture: Picture
    private let footer: Footer
    @AppStorage private var collapsed: Bool

    /// - Parameters:
    ///   - id: stable per page (and per section where a page previews
    ///     several features); keys the folded state.
    ///   - caption: one or two sentences on what the picture shows.
    ///   - states: the segmented picker's labels; empty for none.
    ///   - selection: the picked state's index.
    ///   - highlight: the outlined part's name, or nil when nothing is outlined.
    ///   - aspectRatio: the picture's width over height.
    init(id: String, caption: String, states: [String] = [], selection: Binding<Int>? = nil,
         highlight: String? = nil, aspectRatio: CGFloat = 2.2,
         @ViewBuilder picture: () -> Picture, @ViewBuilder footer: () -> Footer) {
        self.caption = caption
        self.states = states
        self.selection = selection
        self.highlight = highlight
        self.aspectRatio = aspectRatio
        self.picture = picture()
        self.footer = footer()
        _collapsed = AppStorage(wrappedValue: false, ZenithSettingsPreviewDefaults.collapsedKey(id))
    }

    private var text: ZenithSettingsPreviewStrings { .shared }

    var body: some View {
        Group {
            if collapsed { folded } else { open }
        }
        .padding(collapsed ? 12 : 16)
        .background(ZenithSurface.cardFill, in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous).strokeBorder(ZenithSurface.hairline))
        .animation(.spring(duration: 0.35, bounce: 0.1), value: collapsed)
    }

    private var folded: some View {
        Button { collapsed = false } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                Text(text.show).font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var open: some View {
        HStack(alignment: .top, spacing: 18) {
            picture
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous).strokeBorder(ZenithSurface.hairline))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(text.preview)
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { collapsed = true } label: {
                        Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help(text.hide)
                    .accessibilityLabel(text.hide)
                }
                if let selection, states.count > 1 {
                    Picker(text.preview, selection: selection) {
                        ForEach(states.indices, id: \.self) { Text(states[$0]).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Text(caption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let highlight {
                    Text(text.click)
                        .font(ZenithType.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(text.highlighted(highlight), systemImage: "hand.point.up.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 10)
                footer
            }
            .frame(width: 184, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        // The column takes the picture's height, so a footer sits at its foot.
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension ZenithSettingsPreviewCard where Footer == EmptyView {
    init(id: String, caption: String, states: [String] = [], selection: Binding<Int>? = nil,
         highlight: String? = nil, aspectRatio: CGFloat = 2.2, @ViewBuilder picture: () -> Picture) {
        self.init(id: id, caption: caption, states: states, selection: selection, highlight: highlight,
                  aspectRatio: aspectRatio, picture: picture, footer: { EmptyView() })
    }
}

enum ZenithSettingsPreviewDefaults {
    static func collapsedKey(_ id: String) -> String { "zenithSettingsPreviewCollapsed.\(id)" }
}

// MARK: - Desktop

/// This Mac's wallpaper, read once as a thumbnail off the main thread; nil
/// (a neutral gradient) while loading or when the picture can't be read.
final class ZenithPreviewWallpaper: ObservableObject {
    static let shared = ZenithPreviewWallpaper()
    @Published private(set) var image: NSImage?
    private var url: URL?

    func load() {
        guard let screen = NSScreen.main, let next = NSWorkspace.shared.desktopImageURL(for: screen), next != url else { return }
        url = next
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                            kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceThumbnailMaxPixelSize: 1600]
            let cg = CGImageSourceCreateWithURL(next as CFURL, nil)
                .flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
            DispatchQueue.main.async {
                guard let self, self.url == next else { return }
                self.image = cg.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
            }
        }
    }
}

/// A piece of this Mac's desktop: the wallpaper, a menu bar and whatever the
/// page changes on it. `content` is laid out in screen points on a virtual
/// screen `screenWidth` wide (its height follows the card's aspect ratio),
/// with the top edge at the top of the menu bar, then scaled to fit, so the
/// real island views can be dropped in at their real size.
struct ZenithPreviewDesktop<Content: View>: View {
    var screenWidth: CGFloat = 1000
    var menuBar = true
    /// Zenith's own menu bar item, drawn among the status items.
    var showsZenithItem = true
    @ViewBuilder var content: () -> Content
    @ObservedObject private var wallpaper = ZenithPreviewWallpaper.shared

    static var menuBarHeight: CGFloat { 30 }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / screenWidth
            let height = geo.size.height / max(scale, 0.01)
            ZStack(alignment: .top) {
                background
                if menuBar { ZenithPreviewMenuBar(showsZenithItem: showsZenithItem) }
                content()
            }
            .frame(width: screenWidth, height: height, alignment: .top)
            .clipped()
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .onAppear { wallpaper.load() }
    }

    @ViewBuilder private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.24, green: 0.26, blue: 0.45), Color(red: 0.45, green: 0.37, blue: 0.62)],
                           startPoint: .top, endPoint: .bottom)
            if let image = wallpaper.image {
                Image(nsImage: image).resizable().interpolation(.medium).aspectRatio(contentMode: .fill)
            }
        }
    }
}

/// A plain macOS menu bar: the Apple menu and an app's menus on the left,
/// status items and the clock on the right, the notch's gap in the middle.
struct ZenithPreviewMenuBar: View {
    var showsZenithItem = true

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 15, weight: .medium))
            Text("Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View", "Go"], id: \.self) { Text($0).font(.system(size: 13)) }
            Spacer()
            if showsZenithItem { Image(systemName: "asterisk").font(.system(size: 14, weight: .bold)) }
            Image(systemName: "battery.75percent").font(.system(size: 14))
            Image(systemName: "wifi").font(.system(size: 13, weight: .medium))
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
            Text("Mon 23 Nov  9.41").font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: ZenithPreviewDesktop<EmptyView>.menuBarHeight)
        .background(.black.opacity(0.25))
    }
}

// MARK: - Looping illustrations

/// Gives `content` a phase from 0 to 1 that repeats every `period` seconds.
/// It stands still on `stillPhase` while Reduce Motion is on or the window
/// is hidden (occluded, minimized, closed), so an idle Settings window costs
/// nothing.
struct ZenithPreviewLoop<Content: View>: View {
    var period: TimeInterval = 3
    var stillPhase: Double = 0.5
    @ViewBuilder var content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var windowVisible = true

    var body: some View {
        let paused = reduceMotion || !windowVisible
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            content(paused ? stillPhase : (t.truncatingRemainder(dividingBy: period)) / period)
        }
        .background(ZenithWindowVisibilityReader(visible: $windowVisible))
    }
}

/// Reports whether the hosting window is on screen and not occluded.
private struct ZenithWindowVisibilityReader: NSViewRepresentable {
    @Binding var visible: Bool

    func makeNSView(context: Context) -> ReaderView { ReaderView(report: { visible = $0 }) }
    func updateNSView(_ nsView: ReaderView, context: Context) { nsView.report = { visible = $0 } }

    final class ReaderView: NSView {
        var report: (Bool) -> Void
        private var observers: [NSObjectProtocol] = []

        init(report: @escaping (Bool) -> Void) {
            self.report = report
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { report(false); return }
            let names: [Notification.Name] = [NSWindow.didChangeOcclusionStateNotification,
                                              NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.update()
                }
            }
            update()
        }

        private func update() {
            guard let window else { report(false); return }
            let visible = window.occlusionState.contains(.visible) && !window.isMiniaturized
            DispatchQueue.main.async { [weak self] in self?.report(visible) }
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}

// MARK: - Clickable parts

extension View {
    /// Outlines this part of a preview picture with the accent's dashed line
    /// while `highlighted`, and opens its settings when clicked.
    func zenithPreviewPart(cornerRadius: CGFloat = 10, highlighted: Bool, action: @escaping () -> Void) -> some View {
        modifier(ZenithPreviewPartModifier(cornerRadius: cornerRadius, highlighted: highlighted, action: action))
    }
}

private struct ZenithPreviewPartModifier: ViewModifier {
    let cornerRadius: CGFloat
    let highlighted: Bool
    let action: () -> Void
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(highlighted ? 1 : (hovering ? 0.6 : 0)),
                                  style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(-6)
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture(perform: action)
            .animation(.easeOut(duration: 0.2), value: hovering)
    }
}
