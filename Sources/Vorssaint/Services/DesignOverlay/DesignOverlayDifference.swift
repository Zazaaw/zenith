// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreImage
import CoreImage.CIFilterBuiltins
import ScreenCaptureKit

/// Zenith fork: the overlay's Difference blend.
///
/// macOS composites windows with plain source-over blending, and a window's
/// layers (a `compositingFilter` included) only ever blend with that same
/// window's own content, never with another app's window under it. So a true
/// difference against the browser needs the browser's pixels: ScreenCaptureKit
/// takes the area under the image, leaving every window of this app out, and
/// Core Image blends the reference with it. The result is drawn opaque in the
/// overlay, black where the two match. Without Screen Recording the overlay
/// shows Invert instead, which cancels to grey at 50% with no capture at all.
enum DesignOverlayDifference {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// The screen under `rect` (global points, y down) on one display,
    /// without this app's windows, at the display's pixel density.
    static func capture(rect: CGRect, displayID: CGDirectDisplayID, displayScale: CGFloat) async -> CGImage? {
        guard rect.width >= 1, rect.height >= 1,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              let display = content.displays.first(where: { $0.displayID == displayID })
        else { return nil }
        let own = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
        let bounds = CGDisplayBounds(displayID)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(x: rect.minX - bounds.minX, y: rect.minY - bounds.minY,
                                          width: rect.width, height: rect.height)
        let pixels = DesignOverlaySupport.capturePixels(rect.size, displayScale: displayScale)
        configuration.width = pixels.width
        configuration.height = pixels.height
        configuration.showsCursor = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    /// `|reference − captured|` over the captured area. `crop` is the part of
    /// the reference behind it (DesignOverlaySupport.referenceCrop).
    static func difference(reference: CGImage, crop: CGRect, captured: CGImage, context: CIContext) -> CGImage? {
        guard crop.width > 0, crop.height > 0 else { return nil }
        let background = CIImage(cgImage: captured)
        let slice = CIImage(cgImage: reference).cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: background.extent.width / crop.width,
                                               y: background.extent.height / crop.height))
        let blend = CIFilter.differenceBlendMode()
        blend.inputImage = slice
        blend.backgroundImage = background
        guard let output = blend.outputImage?.cropped(to: background.extent) else { return nil }
        return context.createCGImage(output, from: background.extent, format: .RGBA8,
                                     colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    }

    /// The reference with its colours inverted and its alpha kept.
    static func inverted(_ image: CGImage, context: CIContext) -> CGImage? {
        let source = CIImage(cgImage: image)
        let invert = CIFilter.colorInvert()
        invert.inputImage = source
        guard let output = invert.outputImage else { return nil }
        return context.createCGImage(output, from: source.extent, format: .RGBA8,
                                     colorSpace: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB))
    }
}

/// Zenith fork: what "Fit to window under cursor" aligns to. The window comes
/// from the window server's list (no permission needed for its bounds); with
/// Accessibility, a browser's page area (`AXWebArea`) replaces it, so the
/// image lands on the page's top left rather than above the toolbar.
enum DesignOverlayWindowFinder {
    struct Match {
        let frame: CGRect
        let isPage: Bool
    }

    static func contentUnderCursor() -> Match? {
        let mouse = CGEvent(source: nil)?.location ?? .zero
        let own = getpid()
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        let windows: [DesignOverlayWindowCandidate] = list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != own,
                  ((info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            return DesignOverlayWindowCandidate(pid: pid, frame: frame)
        }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard let target = DesignOverlaySupport.targetWindow(in: windows, mouse: mouse, frontmost: front)
        else { return nil }
        if AXIsProcessTrusted(), let page = webArea(pid: target.pid, window: target.frame) {
            return Match(frame: page, isPage: true)
        }
        return Match(frame: target.frame, isPage: false)
    }

    /// The largest web area in the app's window that matches `window`.
    private static func webArea(pid: pid_t, window: CGRect) -> CGRect? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        // Chromium builds its page tree for assistive apps only when asked.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        let match = windows.first { element in
            frame(of: element).map { DesignOverlaySupport.sameFrame($0, window) } ?? false
        }
        guard let root = match ?? windows.first else { return nil }
        var queue = [root]
        var visited = 0
        var areas: [CGRect] = []
        while !queue.isEmpty, visited < 800 {
            let element = queue.removeFirst()
            visited += 1
            if attribute(element, kAXRoleAttribute) as? String == "AXWebArea" {
                if let area = frame(of: element) { areas.append(area) }
                continue
            }
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                queue.append(contentsOf: children)
            }
        }
        return DesignOverlaySupport.pageFrame(areas, window: window)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute),
              let size = attribute(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        // The type checks above make the casts safe.
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &extent)
        else { return nil }
        return CGRect(origin: point, size: extent)
    }
}
