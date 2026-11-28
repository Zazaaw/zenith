// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import QuartzCore

/// Zenith fork: Privacy Blur's pane over one chat window. Borderless, clear,
/// click-through and never key, on the ordinary window level so it can sit
/// just above the app's window and stay under whatever covers that window.
/// It is left in screen captures on purpose: a shared screen shows the frost.
final class PrivacyBlurOverlayPanel: OverlayPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // A window partly off screen keeps its frame; AppKit would pull the pane back on screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// No Space flag: the pane stays on the Space it was ordered on, with
    /// its window, and may join a full-screen app's Space.
    static let behavior: NSWindow.CollectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .normal
        collectionBehavior = Self.behavior
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        animationBehavior = .none
        isExcludedFromWindowsMenu = true
    }
}

/// One pane and what it shows: a rounded blur per item. Kept by
/// `PrivacyBlurTracker`, one per chat window on screen, closed as soon as
/// that window leaves the screen.
@MainActor
final class PrivacyBlurOverlay {
    let targetID: CGWindowID
    private let panel = PrivacyBlurOverlayPanel()
    private let canvas = PrivacyBlurCanvas()
    /// The target's frame in the window server's space.
    private(set) var frame: CGRect = .zero
    private(set) var items: [PrivacyBlurItem] = []
    private var frost = -1.0
    private(set) var reveal = PrivacyBlurReveal.none
    /// A reveal waiting for the pointer to rest, and since when.
    var pending: (reveal: PrivacyBlurReveal, since: TimeInterval)?

    init(targetID: CGWindowID) {
        self.targetID = targetID
        canvas.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        canvas.autoresizingMask = [.width, .height]
        panel.contentView = canvas
    }

    /// The pane's window number once it is on screen.
    var windowNumber: CGWindowID? {
        panel.windowNumber > 0 ? CGWindowID(panel.windowNumber) : nil
    }

    var isOnScreen: Bool { panel.isVisible }

    /// The item revealed now, if one is.
    var revealedItem: PrivacyBlurItem? {
        if case .item(let index) = reveal, items.indices.contains(index) { return items[index] }
        return nil
    }

    /// Moves the pane onto its window and lays out its items. Cheap when
    /// nothing changed: the tracker calls it on every refresh, and on every
    /// wheel event while a window scrolls. The revealed item stays revealed
    /// when it only moved.
    func update(frame: CGRect, cocoaFrame: CGRect, items: [PrivacyBlurItem], frost: Double) {
        if panel.frame != cocoaFrame { panel.setFrame(cocoaFrame, display: false) }
        self.frame = frame
        guard items != self.items || frost != self.frost else { return }
        reveal = PrivacyBlurRevealing.remap(reveal, from: self.items, to: items)
        self.items = items
        self.frost = frost
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        canvas.setItems(items, frost: frost)
        canvas.apply(reveal, transition: nil)
        CATransaction.commit()
    }

    /// Just above the chat window: under anything that covers it.
    func order(above target: CGWindowID) {
        panel.order(.above, relativeTo: Int(target))
    }

    /// Shows `reveal`, fading as `transition` says (nil: at once).
    func apply(_ reveal: PrivacyBlurReveal, transition: PrivacyBlurTransition?) {
        guard reveal != self.reveal else { return }
        self.reveal = reveal
        canvas.apply(reveal, transition: transition)
    }

    /// Refreshes in a row the pane was up but not in the on-screen list.
    var misses = 0

    func hide() {
        panel.orderOut(nil)
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}

/// The pane's content: one rounded blur per item, in the window's own space
/// (flipped, origin top left), from a pool that only grows. Corners follow
/// the window's.
final class PrivacyBlurCanvas: NSView {
    private var parts: [PrivacyBlurPartView] = []
    private var shown = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = PrivacyBlurItems.windowCornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setItems(_ items: [PrivacyBlurItem], frost: Double) {
        while parts.count < items.count {
            let part = PrivacyBlurPartView(frame: .zero)
            addSubview(part)
            parts.append(part)
        }
        for (index, part) in parts.enumerated() {
            guard index < items.count else {
                if !part.isHidden { part.isHidden = true }
                continue
            }
            let item = items[index]
            if part.isHidden { part.isHidden = false }
            if part.frame != item.rect { part.frame = item.rect }
            part.setCornerRadius(item.cornerRadius)
            part.setFrost(frost)
        }
        shown = items.count
    }

    func apply(_ reveal: PrivacyBlurReveal, transition: PrivacyBlurTransition?) {
        for (index, part) in parts.prefix(shown).enumerated() {
            let clear: Bool
            var hole: CGPoint?
            switch reveal {
            case .none: clear = false
            case .all: clear = true
            case .item(let shown): clear = index == shown
            case .circle(let point):
                clear = false
                let radius = PrivacyBlurRevealing.circleRadius
                let reach = part.frame.insetBy(dx: -radius, dy: -radius)
                if reach.contains(point) { hole = CGPoint(x: point.x - part.frame.minX, y: point.y - part.frame.minY) }
            }
            part.setHole(hole)
            part.setClear(clear, transition: transition)
        }
    }
}

/// One blurred item: the system's behind-window blur with a frost of the
/// window background colour over it, rounded like the item. A soft hole can
/// be cut where the pointer is, through both (a window blurred whole).
final class PrivacyBlurPartView: NSView {
    private let effect = NSVisualEffectView()
    private let tint = NSView()
    private var frost = 0.0
    private var radius: CGFloat = -1
    private var clear = false
    private var hole: CGPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        effect.material = .fullScreenUI
        effect.blendingMode = .behindWindow
        effect.state = .active // the app in front is never Zenith
        effect.autoresizingMask = [.width, .height]
        effect.frame = bounds
        addSubview(effect)
        tint.frame = bounds
        tint.wantsLayer = true
        tint.layer?.cornerCurve = .continuous
        tint.layer?.masksToBounds = true
        tint.autoresizingMask = [.width, .height]
        addSubview(tint)
        updateFrostColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateFrostColor()
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        guard changed else { return }
        if hole != nil {
            applyHole()
        } else {
            applyCorners()
        }
    }

    func setFrost(_ value: Double) {
        guard value != frost else { return }
        frost = value
        updateFrostColor()
    }

    /// The item's corner radius, held to half its shorter side (a photo
    /// clipped by a header stays rounded, not stretched).
    func setCornerRadius(_ value: CGFloat) {
        guard value != radius else { return }
        radius = value
        applyCorners()
    }

    private var effectiveRadius: CGFloat {
        max(0, min(radius, bounds.width / 2, bounds.height / 2))
    }

    private func applyCorners() {
        guard hole == nil else { return }
        let r = effectiveRadius
        effect.maskImage = r > 0.5 ? Self.roundedMask(radius: r) : nil
        tint.layer?.cornerRadius = r
        tint.layer?.mask = nil
    }

    private func updateFrostColor() {
        var color = NSColor.windowBackgroundColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            color = NSColor.windowBackgroundColor.withAlphaComponent(frost).cgColor
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.layer?.backgroundColor = color
        CATransaction.commit()
    }

    func setClear(_ clear: Bool, transition: PrivacyBlurTransition?) {
        guard clear != self.clear else { return }
        self.clear = clear
        let target: CGFloat = clear ? 0 : 1
        let duration = transition.map { clear ? $0.fadeIn : $0.fadeOut } ?? 0
        guard duration > 0 else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            alphaValue = target
            CATransaction.commit()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = target
        }
    }

    /// A soft circle cleared at `point` (this view's space), or none.
    func setHole(_ point: CGPoint?) {
        if let point, let hole, abs(point.x - hole.x) < 1.5, abs(point.y - hole.y) < 1.5 { return }
        guard point != nil || hole != nil else { return }
        hole = point
        if hole == nil { applyCorners() } else { applyHole() }
    }

    private func applyHole() {
        guard let hole, let image = Self.holeMask(size: bounds.size, center: hole,
                                                  radius: PrivacyBlurRevealing.circleRadius) else {
            applyCorners()
            return
        }
        effect.maskImage = NSImage(cgImage: image, size: bounds.size)
        guard let layer = tint.layer else { return }
        let mask = layer.mask ?? CALayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.frame = layer.bounds
        mask.contents = image
        mask.contentsGravity = .resize
        layer.mask = mask
        CATransaction.commit()
    }

    /// Stretchable rounded masks, one per radius in half points.
    private static var roundedMasks: [Int: NSImage] = [:]

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let key = Int((radius * 2).rounded())
        if let cached = roundedMasks[key] { return cached }
        let r = CGFloat(key) / 2
        let side = r * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        image.resizingMode = .stretch
        roundedMasks[key] = image
        return image
    }

    /// An alpha mask the size of the part at half resolution (the edge is
    /// soft anyway): opaque everywhere but a circle that fades out to clear
    /// at its centre.
    private static func holeMask(size: CGSize, center: CGPoint, radius: CGFloat) -> CGImage? {
        let scale: CGFloat = 0.5
        let width = max(1, Int((size.width * scale).rounded(.up))), height = max(1, Int((size.height * scale).rounded(.up)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // The view is flipped; the bitmap is not.
        let middle = CGPoint(x: center.x * scale, y: (size.height - center.y) * scale)
        let colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors,
                                        locations: [0, 0.55, 1]) else { return nil }
        context.setBlendMode(.destinationOut)
        context.drawRadialGradient(gradient, startCenter: middle, startRadius: 0, endCenter: middle,
                                   endRadius: radius * scale, options: [])
        return context.makeImage()
    }
}
