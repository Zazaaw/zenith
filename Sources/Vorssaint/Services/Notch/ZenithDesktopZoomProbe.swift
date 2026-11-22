// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

/// Zenith fork: an empty, clear window on the desktop that only reports how
/// the window server scales the desktop. As the Mac unlocks, macOS zooms
/// every desktop window from about 0.9 back to 1 while its shield fades the
/// lock screen out; this window's on-screen bounds say when that is over.
/// It draws nothing and takes no clicks.
final class ZenithDesktopZoomProbe {
    private static let side: CGFloat = 40
    private let window: NSPanel
    private var timer: Timer?

    init(screen: CGRect) {
        window = NSPanel(contentRect: CGRect(x: screen.minX, y: screen.minY, width: Self.side, height: Self.side),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.sharingType = .none
        window.level = NotchPanel.normalLevel
        window.collectionBehavior = NotchPanel.overlayCollectionBehavior
        window.orderFrontRegardless()
    }

    deinit { close() }

    /// The desktop's scale now, as the window server shows this window; nil
    /// when it cannot say.
    var scale: CGFloat? {
        guard window.windowNumber > 0,
              let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(window.windowNumber)) as? [[String: Any]],
              let bounds = info.first?[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.width > 0 else { return nil }
        return rect.width / Self.side
    }

    /// Calls `done` once the desktop is no longer zooming (ZenithDesktopZoom),
    /// with how long it waited and whether it saw a zoom at all.
    func waitForRest(_ done: @escaping (TimeInterval, Bool) -> Void) {
        timer?.invalidate()
        let start = CACurrentMediaTime()
        var sawZoom = false
        var first: CGFloat?
        let check = { [weak self] (_: Timer?) in
            let elapsed = CACurrentMediaTime() - start
            let scale = self?.scale
            if first == nil { first = scale }
            sawZoom = sawZoom || ZenithDesktopZoom.zooming(scale)
            guard ZenithDesktopZoom.settled(elapsed: elapsed, scale: scale, sawZoom: sawZoom),
                  let self, self.timer != nil else { return }
            self.timer?.invalidate()
            self.timer = nil
            ZenithLockTrace.log(ZenithDesktopZoom.text("desktop zoom first scale %.3f", Double(first ?? 0)))
            done(elapsed, sawZoom)
        }
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { check($0) }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check(nil)
    }

    func close() {
        timer?.invalidate()
        timer = nil
        window.orderOut(nil)
        window.close()
    }
}

extension ZenithDesktopZoom {
    /// How much of a drawn image is opaque, 0 to 1: a look drawn blank reads 0.
    static func meanAlpha(_ bitmap: NSBitmapImageRep) -> Double {
        let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
        guard width > 0, height > 0 else { return 0 }
        var total = 0.0, count = 0
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                total += Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
                count += 1
            }
        }
        return count == 0 ? 0 : total / Double(count)
    }
}
