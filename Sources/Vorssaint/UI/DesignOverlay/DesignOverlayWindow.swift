// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import QuartzCore

/// Zenith fork: the design overlay's window. Borderless, clear and above
/// ordinary windows, on every Space and beside full-screen apps. It never
/// becomes key (the HUD takes the keyboard) and, while click-through is on,
/// it never sees the mouse either, so the browser under it stays usable.
final class DesignOverlayPanel: OverlayPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // An image taller than the screen keeps its frame; AppKit would pull it back on screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    /// Above floating panels and the browser, under the HUD and menus.
    static let overlayLevel = NSWindow.Level.statusBar
    static let hudLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    static let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary,
                                                         .ignoresCycle]

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = Self.overlayLevel
        collectionBehavior = Self.behavior
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        animationBehavior = .none
        alphaValue = 0
    }
}

/// The image, the difference and the grid, as layers. The window covers only
/// the part of the image on its display, so the image layer sits at an offset
/// inside it and may run past its edges. Geometry is flipped (y down), the
/// same space the service keeps its frames in. Every change is applied
/// without implicit animation, so sliders and nudges land on the next frame.
final class DesignOverlayCanvas: NSView {
    /// Core Animation's texture limit is 16384 pixels a side; tiles keep far under it.
    private static let tileSide = 4096

    private let root = CALayer()
    private let content = CALayer()
    private let differenceLayer = CALayer()
    private let grid = CAShapeLayer()
    private var tiles: [CALayer] = []

    var onDrag: ((CGVector) -> Void)?
    var onPress: (() -> Void)?
    private var dragStart: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        root.isGeometryFlipped = true
        root.masksToBounds = true
        root.backgroundColor = .clear
        // A hosted layer: AppKit leaves its geometry and sublayers to this view.
        layer = root
        wantsLayer = true
        content.anchorPoint = .zero
        differenceLayer.anchorPoint = .zero
        differenceLayer.isHidden = true
        differenceLayer.magnificationFilter = .nearest
        content.addSublayer(differenceLayer)
        root.addSublayer(content)
        grid.anchorPoint = .zero
        grid.fillColor = NSColor(srgbRed: 0.98, green: 0.44, blue: 0.52, alpha: 0.14).cgColor
        grid.strokeColor = NSColor(srgbRed: 0.98, green: 0.44, blue: 0.52, alpha: 0.55).cgColor
        grid.lineWidth = 0.5
        grid.isHidden = true
        root.addSublayer(grid)
        for layer in [root, content, differenceLayer, grid] { layer.actions = Self.noActions }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static let noActions: [String: CAAction] = [
        "position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "contents": NSNull(), "opacity": NSNull(),
        "hidden": NSNull(), "path": NSNull(), "sublayers": NSNull(), "transform": NSNull(),
    ]

    /// Lays `image` out in tiles across `size` points; `crisp` maps one image
    /// pixel to one device pixel without filtering.
    func setImage(_ image: CGImage?, size: CGSize, crisp: Bool, contentsScale: CGFloat) {
        Self.still {
            tiles.forEach { $0.removeFromSuperlayer() }
            tiles = []
            guard let image else { return }
            let width = image.width
            let height = image.height
            let scaleX = size.width / CGFloat(max(width, 1))
            let scaleY = size.height / CGFloat(max(height, 1))
            var y = 0
            while y < height {
                let tileHeight = min(Self.tileSide, height - y)
                var x = 0
                while x < width {
                    let tileWidth = min(Self.tileSide, width - x)
                    if let piece = image.cropping(to: CGRect(x: x, y: y, width: tileWidth, height: tileHeight)) {
                        let tile = CALayer()
                        tile.actions = Self.noActions
                        tile.anchorPoint = .zero
                        tile.contents = piece
                        tile.contentsGravity = .resize
                        tile.contentsScale = contentsScale
                        tile.magnificationFilter = crisp ? .nearest : .linear
                        tile.minificationFilter = crisp ? .nearest : .trilinear
                        tile.frame = CGRect(x: CGFloat(x) * scaleX, y: CGFloat(y) * scaleY,
                                            width: CGFloat(tileWidth) * scaleX, height: CGFloat(tileHeight) * scaleY)
                        tile.isHidden = !differenceLayer.isHidden
                        content.insertSublayer(tile, below: differenceLayer)
                        tiles.append(tile)
                    }
                    x += tileWidth
                }
                y += tileHeight
            }
        }
    }

    /// Where the whole image sits in this view (y down), which may run past its bounds.
    func setImageFrame(_ frame: CGRect) {
        Self.still {
            content.frame = frame
            grid.frame = frame
        }
    }

    func setOpacity(_ opacity: Double) {
        Self.still { content.opacity = Float(opacity) }
    }

    /// The Difference result over `rect` of the image (its own points), or
    /// nil to show the image itself.
    func setDifference(_ image: CGImage?, in rect: CGRect) {
        Self.still {
            differenceLayer.contents = image
            differenceLayer.frame = rect
            differenceLayer.isHidden = image == nil
            tiles.forEach { $0.isHidden = image != nil }
        }
    }

    /// The grid's columns in the image's own points, or nil for none.
    func setGrid(_ columns: [CGRect]?) {
        Self.still {
            guard let columns, !columns.isEmpty else {
                grid.isHidden = true
                grid.path = nil
                return
            }
            let path = CGMutablePath()
            columns.forEach { path.addRect($0) }
            grid.path = path
            grid.isHidden = false
        }
    }

    private static func still(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    // MARK: Dragging, while click-through is off

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        onPress?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let now = NSEvent.mouseLocation
        dragStart = now
        // AppKit's y runs up; the overlay's runs down.
        onDrag?(CGVector(dx: now.x - start.x, dy: start.y - now.y))
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }
}
