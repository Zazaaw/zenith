// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import QuartzCore

/// Zenith fork: the menu bar hider's own status items, the chevron and its
/// dividers. Created only while the feature is on; every decision about
/// lengths and order comes from MenuBarHiderCore.
final class MenuBarHiderStatusItems: MenuBarHiderItemHost {
    enum Click {
        case primary(option: Bool)
        case secondary(NSStatusBarButton)
    }

    var onClick: ((Click) -> Void)?
    /// Zenith's own icon, for seeding the first places and for the order check.
    var mainItemFrame: () -> CGRect? = { nil }

    private var chevron: NSStatusItem?
    private var divider: NSStatusItem?
    private var alwaysDivider: NSStatusItem?
    private let glyph = MenuBarHiderGlyphAnimator()
    private var lastLengths: MenuBarHiderLengths?

    var isInstalled: Bool { chevron != nil }
    var hasAlwaysDivider: Bool { alwaysDivider != nil }

    /// The window numbers of the hider's own items, which the window probes skip.
    var windowNumbers: Set<Int> {
        Set([chevron, divider, alwaysDivider].compactMap { $0?.button?.window?.windowNumber })
    }

    /// The dividers stretched across the empty menu bar right now. Their
    /// buttons are switched off, so a click there never lights up the whole
    /// bar; the service reads such a click from the window instead.
    var longDividerWindowNumbers: Set<Int> {
        Set([divider, alwaysDivider].compactMap { item in
            guard let item, item.length > MenuBarHiderLayout.alwaysDividerLength else { return nil }
            return item.button?.window?.windowNumber
        })
    }

    func install(alwaysHidden: Bool) {
        guard !isInstalled else { return }
        seedPlaces(alwaysHidden: alwaysHidden)
        let text = ZenithStrings.menuBarHider(L10n.shared.language)
        // Newest is born leftmost, so without saved places the order is still
        // chevron, divider, always hidden divider, right to left.
        let chevron = makeItem(MenuBarHiderPlacement.chevronName, length: MenuBarHiderLayout.chevronLength)
        chevron.button?.toolTip = text.chevronHelp
        chevron.button?.setAccessibilityLabel(text.shortcut)
        glyph.button = chevron.button
        glyph.set(expanded: false, animated: false)
        self.chevron = chevron
        let divider = makeItem(MenuBarHiderPlacement.dividerName, length: MenuBarHiderLayout.dividerLength)
        divider.button?.setAccessibilityLabel(text.dividerLabel)
        self.divider = divider
        if alwaysHidden { setAlwaysDivider(true) }
        lastLengths = nil
    }

    func uninstall() {
        glyph.stop()
        for item in [alwaysDivider, divider, chevron].compactMap({ $0 }) {
            NSStatusBar.system.removeStatusItem(item)
        }
        chevron = nil
        divider = nil
        alwaysDivider = nil
        lastLengths = nil
    }

    func setAlwaysDivider(_ installed: Bool) {
        if installed, alwaysDivider == nil, isInstalled {
            seedPlaces(alwaysHidden: true)
            let item = makeItem(MenuBarHiderPlacement.alwaysDividerName, length: MenuBarHiderLayout.alwaysDividerLength)
            item.button?.setAccessibilityLabel(ZenithStrings.menuBarHider(L10n.shared.language).alwaysDividerLabel)
            alwaysDivider = item
            lastLengths = nil
        } else if !installed, let item = alwaysDivider {
            item.length = MenuBarHiderLayout.alwaysDividerLength
            NSStatusBar.system.removeStatusItem(item)
            alwaysDivider = nil
            lastLengths = nil
        }
    }

    func apply(_ lengths: MenuBarHiderLengths) {
        guard lengths != lastLengths else { return }
        lastLengths = lengths
        if let divider {
            // Collapsed, the divider is the empty stretch of the bar: no line.
            let short = lengths.divider <= MenuBarHiderLayout.dividerLength
            divider.length = lengths.divider
            divider.button?.image = short ? MenuBarHiderGlyph.divider() : nil
            divider.button?.isEnabled = short
        }
        if let alwaysDivider {
            let length = lengths.alwaysDivider ?? MenuBarHiderLayout.alwaysDividerLength
            let short = length <= MenuBarHiderLayout.alwaysDividerLength
            alwaysDivider.length = length
            alwaysDivider.button?.image = short ? MenuBarHiderGlyph.alwaysDivider() : nil
            alwaysDivider.button?.isEnabled = short
        }
    }

    func showExpanded(_ expanded: Bool, animated: Bool) {
        glyph.set(expanded: expanded, animated: animated)
    }

    func frames() -> MenuBarHiderFrames {
        func frame(_ item: NSStatusItem?) -> CGRect? {
            guard let item, item.isVisible, let window = item.button?.window, window.isVisible else { return nil }
            let frame = window.frame
            return frame.width > 0 && frame.height > 0 ? frame : nil
        }
        return MenuBarHiderFrames(main: mainItemFrame(), chevron: frame(chevron),
                                  divider: frame(divider), alwaysDivider: frame(alwaysDivider))
    }

    // MARK: Building

    private func makeItem(_ name: String, length: CGFloat) -> NSStatusItem {
        // A place macOS remembers as removed would keep the item out of the bar.
        for key in MenuBarHiderPlacement.visibilityKeys(name) {
            UserDefaults.standard.removeObject(forKey: key)
        }
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = name
        // ⌘-dragging reorders, but never drags the item out of the bar.
        item.behavior = []
        item.isVisible = true
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        return item
    }

    private func seedPlaces(alwaysHidden: Bool) {
        let screens = NSScreen.screens.map(\.frame)
        let distance = mainItemFrame().flatMap { MenuBarHiderPlacement.distance(of: $0, screens: screens) }
        MenuBarHiderPlacement.seed(in: .standard,
                                   mainAutosaveName: StatusItemPlacementSupport.mainAutosaveName(in: .standard),
                                   mainDistance: distance, alwaysHidden: alwaysHidden)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if secondary {
            onClick?(.secondary(sender))
        } else {
            onClick?(.primary(option: event?.modifierFlags.contains(.option) == true))
        }
    }
}

// MARK: - Glyphs

/// Minimal template glyphs, so macOS tints them for a light or dark menu bar
/// and inverts them while pressed.
enum MenuBarHiderGlyph {
    /// A thin chevron, `‹` at angle 0, turned about its center.
    static func chevron(angle: Double) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 16), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let path = NSBezierPath()
            path.move(to: CGPoint(x: center.x + 1.9, y: center.y + 4.2))
            path.line(to: CGPoint(x: center.x - 1.9, y: center.y))
            path.line(to: CGPoint(x: center.x + 1.9, y: center.y - 4.2))
            var transform = AffineTransform(translationByX: center.x, byY: center.y)
            transform.rotate(byRadians: CGFloat(angle))
            transform.translate(x: -center.x, y: -center.y)
            path.transform(using: transform)
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// A short, faint line where the hidden section begins.
    static func divider() -> NSImage {
        let image = NSImage(size: NSSize(width: MenuBarHiderLayout.dividerLength, height: 16), flipped: false) { rect in
            let line = NSBezierPath(roundedRect: CGRect(x: rect.midX - 0.6, y: rect.midY - 6, width: 1.2, height: 12),
                                    xRadius: 0.6, yRadius: 0.6)
            NSColor.black.withAlphaComponent(0.55).setFill()
            line.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Three dots, so the always hidden divider reads apart from the main one.
    static func alwaysDivider() -> NSImage {
        let image = NSImage(size: NSSize(width: MenuBarHiderLayout.alwaysDividerLength, height: 16), flipped: false) { rect in
            NSColor.black.withAlphaComponent(0.55).setFill()
            for offset in [-4.5, 0, 4.5] as [CGFloat] {
                NSBezierPath(ovalIn: CGRect(x: rect.midX - 1.1, y: rect.midY + offset - 1.1, width: 2.2, height: 2.2)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Turns the chevron half a circle on the Style Kit spring, one frame per
/// display refresh (120 Hz on ProMotion). Reduce Motion sets it at once.
final class MenuBarHiderGlyphAnimator: NSObject {
    weak var button: NSStatusBarButton?
    private var link: CADisplayLink?
    private var from = 0.0
    private var to = 0.0
    private var current = 0.0
    private var start: CFTimeInterval = 0

    func set(expanded: Bool, animated: Bool) {
        let target = MenuBarHiderGlyphMotion.restingAngle(expanded: expanded)
        guard target != to || button?.image == nil else { return }
        to = target
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let button else {
            stop()
            current = target
            draw()
            return
        }
        from = current
        start = CACurrentMediaTime()
        if link == nil {
            let link = button.displayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - start
        guard elapsed < MenuBarHiderGlyphMotion.duration else {
            current = to
            draw()
            stop()
            return
        }
        current = MenuBarHiderGlyphMotion.angle(from: from, to: to, elapsed: elapsed)
        draw()
    }

    private func draw() {
        button?.image = MenuBarHiderGlyph.chevron(angle: current)
    }
}
