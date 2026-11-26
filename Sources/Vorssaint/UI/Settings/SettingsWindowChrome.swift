// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the Settings window's frame, after macOS 26's System Settings.
/// The content reaches the top of the window under a hidden, transparent
/// title bar, so the floating sidebar panel runs up to the top and the
/// system's own close, minimise and zoom buttons sit inside its top-left
/// corner. An empty unified toolbar is what places them there: AppKit lays
/// the buttons out for a toolbar-height title bar, centred 26 points from
/// the top, without the app moving them by hand. The sidebar toggle and
/// Back and Forward live in the panel's top row, or over the page's top-left
/// while the sidebar is hidden.
enum SettingsWindowChrome {
    /// The title bar's height with the empty toolbar; the window buttons are
    /// centred in it.
    static let topBarHeight: CGFloat = 52
    /// The floating panels' inset from the window's edges.
    static let panelInset: CGFloat = 8
    /// From the window's leading edge to past the zoom button, where the
    /// controls beside the window buttons may start.
    static let windowButtonsReserve: CGFloat = 88
    /// The draggable strip over the page's top while the sidebar is showing.
    static let contentDragHeight: CGFloat = 20
}

extension SettingsWindow {
    /// The hosting controller sizes nothing, bridges no toolbar or title (the
    /// window's toolbar is the empty one below) and adds no safe area for the
    /// title bar: the views place themselves around the window buttons.
    static func prepare<Content: View>(host: NSHostingController<Content>) {
        host.sizingOptions = []
        host.sceneBridgingOptions = []
        host.safeAreaRegions = []
    }

    /// Full-size content under a hidden, transparent title bar, with the
    /// empty unified toolbar that sets the window buttons' place.
    func applyZenithChrome() {
        styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        titlebarSeparatorStyle = .none
        let toolbar = NSToolbar(identifier: "id.satuvisual.zenith.settings")
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        if #available(macOS 15.0, *) { toolbar.allowsDisplayModeCustomization = false }
        self.toolbar = toolbar
        toolbarStyle = .unified
    }
}

// MARK: - Drag area

/// A stretch of the window's top that moves the window like a title bar:
/// a drag moves it, and a double-click does what the system setting says.
struct SettingsWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func isAccessibilityElement() -> Bool { false }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            guard event.clickCount == 2 else {
                window.performDrag(with: event)
                return
            }
            guard !window.styleMask.contains(.fullScreen) else { return }
            switch SettingsTitleBarDoubleClick.current() {
            case .zoom: window.performZoom(nil)
            case .minimize: window.performMiniaturize(nil)
            case .none: break
            }
        }
    }
}

// MARK: - Controls

/// The sidebar toggle, Back and Forward, beside the window buttons. ⌃⌘S
/// toggles the sidebar; Back and Forward keep their Go menu keys.
struct SettingsWindowControls: View {
    let sidebarShown: Bool
    let toggleSidebar: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared

    var body: some View {
        let strings = SettingsNavigationStrings.localized(l10n.language)
        HStack(spacing: 2) {
            SettingsChromeButton(symbol: "sidebar.left",
                                 title: sidebarShown ? strings.hideSidebar : strings.showSidebar,
                                 action: toggleSidebar)
                .keyboardShortcut("s", modifiers: [.control, .command])
            SettingsChromeButton(symbol: "chevron.backward", title: strings.back) {
                router.goBack(isPageVisible: Self.isPageVisible)
            }
            .disabled(!router.canGoBack(isPageVisible: Self.isPageVisible))
            SettingsChromeButton(symbol: "chevron.forward", title: strings.forward) {
                router.goForward(isPageVisible: Self.isPageVisible)
            }
            .disabled(!router.canGoForward(isPageVisible: Self.isPageVisible))
        }
    }

    private static func isPageVisible(_ page: SettingsPage) -> Bool {
        FeatureVisibilitySupport.isPageVisible(page, isAvailable: { $0.isAvailable })
    }
}

/// One borderless icon button of the window's controls, lit while the
/// pointer is over it.
private struct SettingsChromeButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(hovering && isEnabled ? 0.08 : 0))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(title)
    }

    private var foreground: AnyShapeStyle {
        guard isEnabled else { return AnyShapeStyle(.tertiary) }
        return contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }
}

// MARK: - Page top

/// The strip over the page's top: it moves the window, fades the page out as
/// it scrolls up under the window's top, and holds the controls while the
/// sidebar is hidden.
struct SettingsContentTopStrip: View {
    let sidebarShown: Bool
    let isFullScreen: Bool
    let toggleSidebar: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let background = Color(nsColor: .windowBackgroundColor)
        ZStack(alignment: .leading) {
            LinearGradient(stops: [.init(color: background, location: 0),
                                   .init(color: background, location: sidebarShown ? 0.3 : 0.55),
                                   .init(color: background.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            SettingsWindowDragArea()
            if !sidebarShown {
                SettingsWindowControls(sidebarShown: false, toggleSidebar: toggleSidebar)
                    .padding(.leading, isFullScreen ? 12 : SettingsWindowChrome.windowButtonsReserve)
            }
        }
        .frame(height: sidebarShown ? SettingsWindowChrome.contentDragHeight : SettingsWindowChrome.topBarHeight)
        .overlay(alignment: .bottom) {
            if !sidebarShown, contrast == .increased {
                Rectangle().fill(Color.primary.opacity(0.3)).frame(height: 1)
            }
        }
    }
}
