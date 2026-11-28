// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the shield App Lock draws over a locked app's windows, and
// nothing else. One borderless pane exactly over each of the app's windows
// on the current Space, on that window's own level and ordered just above
// it, so another app's window that covers it still covers the pane; the
// pane blurs and dims what is under it and takes the clicks meant for the
// window. One card (the app's icon with a padlock, its name, Cancel and
// Unlock) in its own small panel, centred in the app's frontmost window,
// or alone in the middle of the screen when the app shows none. The card
// takes the keyboard without bringing Zenith forward (a non-activating
// panel), so typing never reaches the locked app; the menu bar, the Dock,
// the system's Touch ID and password prompt and Zenith's island all sit on
// higher levels and stay above. AppLockWindowTracker says when to look at
// the windows again; AppLockShieldPlacement decides where everything goes;
// AppLockService decides when the shield shows.

/// What the shield's card shows.
@MainActor
final class AppLockShieldModel: ObservableObject {
    enum Status: Equatable {
        case idle
        /// Zenith's Face Unlock is looking for a face.
        case face
        /// macOS asks for Touch ID or the password.
        case waiting
        /// The face was not matched and macOS asks now.
        case faceMissed
        /// Not unlocked; Unlock tries again.
        case failed

        /// A Touch ID or password prompt is open.
        var isPrompting: Bool { self == .waiting || self == .faceMissed }
    }

    let name: String
    let icon: NSImage
    @Published var status: Status = .idle
    var onUnlock: (() -> Void)?
    var onCancel: (() -> Void)?

    init(name: String, icon: NSImage, status: Status = .idle) {
        self.name = name
        self.icon = icon
        self.status = status
    }

    func line(_ text: ZenithAppLockStrings) -> String? {
        switch status {
        case .idle: return nil
        case .face: return text.lookingForFace
        case .waiting: return text.waiting
        case .faceMissed: return text.faceNotRecognized
        case .failed: return text.failed
        }
    }
}

@MainActor
final class AppLockShieldController {
    private(set) var model: AppLockShieldModel?
    private var pid: pid_t?
    private var panes: [CGWindowID: AppLockPane] = [:]
    private var card: AppLockCardPanel?
    /// The window the card sits in, nil while it stands alone.
    private var cardHost: CGWindowID?
    private var cardMisses = 0
    private let tracker = AppLockWindowTracker()
    private var resignObserver: NSObjectProtocol?
    /// Bumped by every show and dismiss, so a late refresh of an earlier
    /// shield changes nothing.
    private var generation = 0
    private var refreshPending = false
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func show(_ model: AppLockShieldModel, coveringProcess pid: pid_t) {
        dismiss()
        guard !ZenithQuiet.isOn else { return } // never a pane, a card or an observer in tests or the catalog
        self.model = model
        self.pid = pid
        let card = AppLockCardPanel(model: model)
        self.card = card
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: card, queue: .main) { [weak self] _ in
            // Something took the keyboard: if the locked app put its window
            // back over a pane, the next look takes the keyboard back.
            MainActor.assumeIsolated { self?.refreshSoon() }
        }
        tracker.start(pid: pid) { [weak self] event in self?.handle(event) }
        refresh()
        takeKeyboard()
    }

    /// Takes the keyboard: typing goes to the shield, not the app under it.
    /// Never while macOS asks for Touch ID or the password: that prompt has it.
    func focus() {
        guard card != nil else { return }
        refresh()
        takeKeyboard()
    }

    func dismiss() {
        generation &+= 1
        tracker.stop()
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        panes.values.forEach { $0.close() }
        panes.removeAll()
        card?.orderOut(nil)
        card?.close()
        card = nil
        cardHost = nil
        cardMisses = 0
        model = nil
        pid = nil
    }

    // MARK: Following the windows

    private func handle(_ event: AppLockWindowTracker.Event) {
        switch event {
        case .moved, .tick:
            refresh()
        case .changed:
            refreshSoon()
        case .focus:
            // The locked app focused one of its windows: the keyboard comes back.
            refreshSoon()
            takeKeyboard()
        }
    }

    /// A look now and again just after, for changes the window server
    /// finishes after it tells (coming forward, a Space, a window coming back).
    private func refreshSoon() {
        let current = generation
        if !refreshPending {
            refreshPending = true
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.refreshPending = false
                    guard self?.generation == current else { return }
                    self?.refresh()
                }
            }
        }
        for delay in [0.08, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated {
                    guard self?.generation == current else { return }
                    self?.refresh()
                }
            }
        }
    }

    /// Reads the window list once and makes the panes and the card match it.
    private func refresh() {
        guard let pid, let card, !ZenithQuiet.isOn else { return }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                              kCGNullWindowID) as? [[String: Any]] ?? []
        let windows = AppLockShieldPlacement.windows(from: info)
        let targets = AppLockShieldPlacement.targets(in: windows, pid: pid)
        let wanted = Set(targets.map(\.id))
        for (id, pane) in panes where !wanted.contains(id) {
            pane.close()
            panes[id] = nil
        }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let host = AppLockShieldPlacement.cardHost(among: targets)
        var raised = false
        var hostReordered = false
        // Back to front, so each pane lands above its own window in turn.
        for target in targets.reversed() {
            let pane = panes[target.id] ?? AppLockPane()
            panes[target.id] = pane
            pane.update(frame: AppLockShieldPlacement.flipped(target.frame, mainDisplayHeight: mainHeight),
                        layer: target.layer, showsPadlock: target.id != host)
            // Up but missing from this Space's list twice running: the pane
            // stayed on the Space its window left (full screen, a moved
            // window). Out and in again brings it to the current one.
            pane.misses = AppLockShieldPlacement.misses(after: pane.misses, isUp: pane.isOnScreen,
                                                        isListed: Self.isListed(pane.windowNumber, in: windows))
            if pane.misses >= AppLockShieldPlacement.strandedAfter {
                pane.hide()
                pane.misses = 0
            }
            let number = pane.isOnScreen ? pane.windowNumber : nil
            if AppLockShieldPlacement.wasRaisedOver(pane: number, above: target, in: windows) { raised = true }
            if AppLockShieldPlacement.needsOrdering(pane: number, above: target, ownPID: ownPID, in: windows) {
                pane.order(above: target.id)
                if target.id == host { hostReordered = true }
            }
        }
        place(card, host: targets.first { $0.id == host }, hostReordered: hostReordered, windows: windows,
              mainHeight: mainHeight)
        // The locked app came back over its pane and took the keyboard with it.
        if raised { takeKeyboard() }
    }

    private func place(_ card: AppLockCardPanel, host: AppLockWindow?, hostReordered: Bool, windows: [AppLockWindow],
                       mainHeight: CGFloat) {
        let flip = { (rect: CGRect) in AppLockShieldPlacement.flipped(rect, mainDisplayHeight: mainHeight) }
        let screens = NSScreen.screens
        let mouse = NSEvent.mouseLocation
        // Standing alone, the card keeps its screen; it first shows where the pointer is.
        let kept = host == nil && cardHost == nil && card.isVisible ? card.screen : nil
        let around = kept ?? screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? screens.first
        let fallback = around.map { flip($0.visibleFrame) } ?? CGRect(origin: .zero, size: AppLockCardPanel.size)
        let frame = AppLockShieldPlacement.cardFrame(size: AppLockCardPanel.size, host: host?.frame,
                                                     screens: screens.map { flip($0.visibleFrame) }, fallback: fallback)
        card.place(frame: flip(frame), layer: host?.layer ?? 0)
        cardMisses = AppLockShieldPlacement.misses(after: cardMisses, isUp: card.isVisible,
                                                   isListed: Self.isListed(card.number, in: windows))
        if cardMisses >= AppLockShieldPlacement.strandedAfter {
            card.orderOut(nil)
            cardMisses = 0
        }
        let hostChanged = host?.id != cardHost
        cardHost = host?.id
        if let host, let hostPane = panes[host.id], let paneNumber = hostPane.windowNumber, hostPane.isOnScreen {
            // Just above the host's pane, with nothing but Zenith's own between.
            let paneEntry = AppLockWindow(id: paneNumber, pid: ownPID, frame: host.frame, layer: host.layer, alpha: 1)
            if hostChanged || hostReordered || !card.isVisible
                || AppLockShieldPlacement.needsOrdering(pane: card.number, above: paneEntry, ownPID: ownPID, in: windows) {
                card.order(.above, relativeTo: Int(paneNumber))
            }
        } else if host == nil, hostChanged || !card.isVisible {
            card.orderFrontRegardless()
        }
    }

    private static func isListed(_ number: CGWindowID?, in windows: [AppLockWindow]) -> Bool {
        guard let number else { return false }
        return windows.contains { $0.id == number }
    }

    /// The card becomes the key window without Zenith coming forward. If
    /// macOS will not hand a background app's panel the keyboard, Zenith
    /// comes forward for it, which still leaves the locked app's windows
    /// under their panes.
    private func takeKeyboard() {
        guard let card, card.isVisible, model?.status.isPrompting != true else { return }
        card.makeKey()
        let current = generation
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == current, let card = self.card, card.isVisible,
                      self.model?.status.isPrompting != true, !card.isKeyWindow else { return }
                NSApp.activate(ignoringOtherApps: true)
                card.makeKey()
            }
        }
    }
}

// MARK: - A pane over one window

/// The pane's window: borderless, clear and never key, so a click on it
/// leaves the keyboard with the card and does not bring Zenith forward. It
/// takes the clicks meant for the window under it.
final class AppLockPanePanel: OverlayPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // A window partly off screen keeps its frame; AppKit would pull the pane back on screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// No Space flag: the pane stays on the Space it was ordered on, with its
    /// window, and may join a full-screen app's Space.
    static let behavior: NSWindow.CollectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        AppLockPanePanel.configure(self)
    }

    /// What the panes and the card share.
    static func configure(_ panel: NSPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .normal
        panel.collectionBehavior = behavior
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        panel.isExcludedFromWindowsMenu = true
        panel.isMovable = false
    }
}

/// One pane, kept by the controller while its window is on screen.
@MainActor
final class AppLockPane {
    private let panel = AppLockPanePanel()
    private let content = AppLockPaneView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    /// Refreshes in a row the pane was up but not in the on-screen list.
    var misses = 0

    init() {
        content.autoresizingMask = [.width, .height]
        panel.contentView = content
    }

    var windowNumber: CGWindowID? { panel.windowNumber > 0 ? CGWindowID(panel.windowNumber) : nil }
    var isOnScreen: Bool { panel.isVisible }

    /// Cheap when nothing changed: called on every refresh.
    func update(frame: CGRect, layer: Int, showsPadlock: Bool) {
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        let level = NSWindow.Level(rawValue: layer)
        if panel.level != level { panel.level = level }
        content.showsPadlock = showsPadlock
    }

    /// Just above its window: under anything that covers it.
    func order(above target: CGWindowID) {
        panel.order(.above, relativeTo: Int(target))
    }

    func hide() {
        panel.orderOut(nil)
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}

/// The pane's picture: the system's behind-window blur, a frost and a dim
/// over it so even large text stays unreadable, and a small padlock on
/// every window but the one holding the card. Corners a little inside the
/// window's own.
final class AppLockPaneView: NSView {
    private let effect = NSVisualEffectView()
    private let tint = NSView()
    private let padlock = NSHostingView(rootView: AppLockPadlockBadge(size: 40))

    var showsPadlock = true {
        didSet { if showsPadlock != oldValue { padlock.isHidden = !showsPadlock } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let radius = AppLockShieldPlacement.cornerRadius
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        effect.material = .fullScreenUI
        effect.blendingMode = .behindWindow
        effect.state = .active // the app in front is the locked one, never Zenith
        effect.maskImage = Self.roundedMask(radius: radius)
        effect.frame = bounds
        effect.autoresizingMask = [.width, .height]
        addSubview(effect)
        tint.wantsLayer = true
        tint.frame = bounds
        tint.autoresizingMask = [.width, .height]
        addSubview(tint)
        let side: CGFloat = 52
        padlock.frame = NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        padlock.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        addSubview(padlock)
        updateTint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTint()
    }

    /// The window's background colour as a frost, darkened: the old
    /// full-screen shield's dim, now on the window alone.
    private func updateTint() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        var color = NSColor.black.withAlphaComponent(0.4).cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let base = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) ?? (dark ? .black : .white)
            let dimmed = base.blended(withFraction: dark ? 0.45 : 0.2, of: .black) ?? base
            color = dimmed.withAlphaComponent(dark ? 0.55 : 0.45).cgColor
        }
        tint.layer?.backgroundColor = color
    }

    /// A stretchable rounded rectangle, the way NSVisualEffectView rounds a
    /// behind-window blur.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - The card

/// The card's own panel: borderless, clear around the card, and able to be
/// the key window without making Zenith the active app. Every key goes
/// here, none to the locked app: Esc cancels, Return unlocks, Tab moves
/// between the buttons, and the rest (shortcuts included) is dropped.
final class AppLockCardPanel: OverlayPanel {
    /// Room for the card at its tallest and its shadow.
    static let size = CGSize(width: 440, height: 460)

    private let onKey: @MainActor (AppLockShieldKey) -> Void

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    @MainActor
    init(model: AppLockShieldModel) {
        onKey = { [weak model] key in
            switch key {
            case .cancel: model?.onCancel?()
            case .unlock: model?.onUnlock?()
            case .pass, .swallow: break
            }
        }
        super.init(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        AppLockPanePanel.configure(self)
        becomesKeyOnlyIfNeeded = false
        let hosting = NSHostingView(rootView: AppLockShieldCard(model: model, text: ZenithStrings.appLock(.enUS))
            .frame(maxWidth: .infinity, maxHeight: .infinity))
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    var number: CGWindowID? { windowNumber > 0 ? CGWindowID(windowNumber) : nil }

    func place(frame: CGRect, layer: Int) {
        if self.frame != frame { setFrame(frame, display: false) }
        let level = NSWindow.Level(rawValue: layer)
        if self.level != level { self.level = level }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true } // the card's own buttons
        let key = AppLockShieldKey.action(keyCode: event.keyCode)
        guard key != .pass else { return false }
        onKey(key)
        return true
    }

    override func keyDown(with event: NSEvent) {
        let key = AppLockShieldKey.action(keyCode: event.keyCode)
        if key == .pass { return super.keyDown(with: event) }
        onKey(key)
    }

    override func cancelOperation(_ sender: Any?) {
        onKey(.cancel)
    }
}

/// The card: the app's icon with a padlock, its name, what is happening, and
/// Cancel (hides the app) beside Unlock.
struct AppLockShieldCard: View {
    @ObservedObject var model: AppLockShieldModel
    let text: ZenithAppLockStrings

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: model.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                AppLockPadlockBadge(size: 34)
                    .offset(x: 6, y: 4)
            }
            .accessibilityHidden(true)
            Text(model.name)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(text.lockedBy)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if let line = model.line(text) {
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(model.status == .failed ? ZenithStatus.warning : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(text.cancel) { model.onCancel?() }
                    .keyboardShortcut(.cancelAction)
                Button(model.status == .face ? text.usePassword : text.unlock) { model.onUnlock?() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.status.isPrompting)
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 28)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.name), \(text.lockedBy)")
    }
}

/// A round padlock badge: the shield's mark, also on the Settings stage.
struct AppLockPadlockBadge: View {
    var size: CGFloat = 34
    var open = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.78)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            Image(systemName: open ? "lock.open.fill" : "lock.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(Color(red: 0.2, green: 0.26, blue: 0.42))
        }
        .frame(width: size, height: size)
    }
}
