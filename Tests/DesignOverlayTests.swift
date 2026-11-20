// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: the design QA overlay. Scale detection (pixel width and the
/// density a file states, read back from real PNGs), point sizes, nudging and
/// the lock, per-display memory in its own defaults suite, the column grid,
/// the HUD's placement, the difference crop, Fit's window choice, and the
/// island drop path with the Overlay zone, run through NotchService's own
/// methods against the drop routing doubles.
enum DesignOverlayTests {
    private typealias Support = DesignOverlaySupport

    static func run(_ suite: TestSuite) {
        scale(suite)
        pointSize(suite)
        placement(suite)
        memory(suite)
        grid(suite)
        geometry(suite)
        fit(suite)
        dropTargets(suite)
        dropRouting(suite)
        preferences(suite)
        strings(suite)
    }

    // MARK: Scale

    private static func scale(_ suite: TestSuite) {
        suite.expect(Support.detectedScale(pixelWidth: 2880, dpi: nil) == 2, "a 2880 px export is a 1440 frame at 2x")
        suite.expect(Support.detectedScale(pixelWidth: 1440, dpi: nil) == 1, "a 1440 px export is 1x")
        suite.expect(Support.detectedScale(pixelWidth: 1170, dpi: nil) == 3, "1170 px is a 390 phone at 3x")
        suite.expect(Support.detectedScale(pixelWidth: 750, dpi: nil) == 2, "750 px is a 375 phone at 2x")
        suite.expect(Support.detectedScale(pixelWidth: 1080, dpi: nil) == 3, "1080 px is a 360 frame at 3x")
        suite.expect(Support.detectedScale(pixelWidth: 2560, dpi: nil) == 2, "2560 px is a 1280 frame at 2x")
        suite.expect(Support.detectedScale(pixelWidth: 1000, dpi: 144) == 2
                        && Support.detectedScale(pixelWidth: 1000, dpi: 216) == 3,
                     "a stated 144 or 216 dpi decides before the width")
        suite.expect(Support.detectedScale(pixelWidth: 2880, dpi: 72) == 2,
                     "the 72 dpi default says nothing, so the width decides")
        suite.expect(Support.detectedScale(pixelWidth: 1440, dpi: 96) == 1, "96 dpi is still 1x")
        suite.expect(Support.detectedScale(pixelWidth: 5000, dpi: 1000) == 3, "a huge density is held at 3x")
        suite.expect(Support.detectedScale(pixelWidth: 1237, dpi: nil) == 1, "an odd width with no density is 1x")
        suite.expect(Support.detectedScale(pixelWidth: 2200, dpi: nil, screenPointWidth: 1512) == 2,
                     "an unknown width wider than the screen takes the factor that fits it")
        suite.expect(Support.detectedScale(pixelWidth: 1920, dpi: nil, screenPointWidth: 1512) == 2,
                     "a 1920 export wider than a 1512 screen is read as 2x")
        suite.expect(Support.detectedScale(pixelWidth: 1920, dpi: nil, screenPointWidth: 1920) == 1,
                     "on a screen that holds it, 1920 stays 1x")
        suite.expect(Support.detectedScale(pixelWidth: 0, dpi: nil) == 1, "no width is 1x")

        suite.expect(DesignOverlayScaleChoice.automatic.resolved(detected: 2) == 2
                        && DesignOverlayScaleChoice.x1.resolved(detected: 2) == 1
                        && DesignOverlayScaleChoice.x3.resolved(detected: 1) == 3
                        && DesignOverlayScaleChoice.automatic.resolved(detected: 9) == 3,
                     "a hand-set scale overrides the detected one; automatic stays within 1x to 3x")
        suite.expect(DesignOverlayScaleChoice.stored("x2") == .x2 && DesignOverlayScaleChoice.stored("nope") == .automatic,
                     "an unknown stored scale reads as automatic")

        // The density travels in real files: written by Image I/O, read back.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("design-overlay-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let retina = folder.appendingPathComponent("frame@2x.png")
        let plain = folder.appendingPathComponent("frame.png")
        let wroteRetina = writePNG(width: 288, height: 120, dpi: 144, to: retina)
        let wrotePlain = writePNG(width: 2880, height: 40, dpi: nil, to: plain)
        let retinaInfo = DesignOverlayImageInfo(url: retina)
        let plainInfo = DesignOverlayImageInfo(url: plain)
        suite.expect(wroteRetina && retinaInfo?.pixelWidth == 288 && retinaInfo?.pixelHeight == 120
                        && retinaInfo.map { Support.detectedScale($0) } == 2,
                     "a PNG stating 144 dpi reads back as 2x: \(String(describing: retinaInfo))")
        suite.expect(wrotePlain && plainInfo.map { Support.detectedScale($0) } == 2,
                     "a PNG with no density falls back to its width: \(String(describing: plainInfo))")
        let data = (try? Data(contentsOf: retina)) ?? Data()
        suite.expect(DesignOverlayImageInfo(data: data) == retinaInfo, "clipboard data reads like the file")
        suite.expect(DesignOverlayImageInfo(data: Data("not an image".utf8)) == nil, "text is not a reference")
    }

    private static func writePNG(width: Int, height: Int, dpi: Double?, to url: URL) -> Bool {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return false }
        var properties: [CFString: Any] = [:]
        if let dpi {
            properties[kCGImagePropertyDPIWidth] = dpi
            properties[kCGImagePropertyDPIHeight] = dpi
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    // MARK: Point size

    private static func pointSize(_ suite: TestSuite) {
        suite.expect(Support.pointSize(pixelWidth: 2880, pixelHeight: 6400, scale: 2) == CGSize(width: 1440, height: 3200),
                     "a 2x export covers half its pixels in points")
        suite.expect(Support.pointSize(pixelWidth: 1170, pixelHeight: 2532, scale: 3) == CGSize(width: 390, height: 844),
                     "a 3x phone export lands on its frame size")
        suite.expect(Support.pointSize(pixelWidth: 1440, pixelHeight: 900, scale: 1) == CGSize(width: 1440, height: 900),
                     "1x is pixels for points")
        suite.expect(Support.pointSize(pixelWidth: 100, pixelHeight: 100, scale: 7).width == 100 / 3,
                     "the scale is held to 3x")
        suite.expect(Support.snapped(10.3, displayScale: 2) == 10.5 && Support.snapped(10.2, displayScale: 2) == 10
                        && Support.snapped(10.4, displayScale: 1) == 10 && Support.snapped(3, displayScale: CGFloat.nan) == 3,
                     "an edge snaps to the display's pixel grid")
        suite.expect(Support.clampedOpacity(0) == 0.05 && Support.clampedOpacity(2) == 1
                        && Support.clampedOpacity(Double.nan) == Support.defaultOpacity && Support.defaultOpacity == 0.5,
                     "opacity defaults to 50% and stays visible")
        suite.expect(Support.opacity(forDigit: 1) == 0.1 && Support.opacity(forDigit: 5) == 0.5
                        && Support.opacity(forDigit: 0) == 1 && Support.opacity(forDigit: 10) == nil,
                     "digit keys set the opacity in tens, 0 for full")
    }

    // MARK: Nudge and lock

    private static func placement(_ suite: TestSuite) {
        let start = DesignOverlayPlacement(offset: CGPoint(x: 100, y: 200))
        suite.expect(start.nudged(.right, large: false).offset == CGPoint(x: 101, y: 200)
                        && start.nudged(.left, large: false).offset == CGPoint(x: 99, y: 200)
                        && start.nudged(.up, large: false).offset == CGPoint(x: 100, y: 199)
                        && start.nudged(.down, large: false).offset == CGPoint(x: 100, y: 201),
                     "an arrow moves the image one point, up moving it up the screen")
        suite.expect(start.nudged(.right, large: true).offset == CGPoint(x: 110, y: 200)
                        && start.nudged(.up, large: true).offset == CGPoint(x: 100, y: 190),
                     "with Shift an arrow moves ten points")
        let locked = start.locking(true)
        suite.expect(locked.nudged(.right, large: true) == locked
                        && locked.moved(by: CGVector(dx: 30, dy: 4)) == locked
                        && locked.moved(to: .zero) == locked,
                     "a locked image ignores arrows, drags and Fit")
        suite.expect(locked.locking(false).nudged(.down, large: false).offset == CGPoint(x: 100, y: 201),
                     "unlocked, it moves again from where it was")
        suite.expect(start.moved(by: CGVector(dx: CGFloat.nan, dy: 1)) == start && start.moved(to: CGPoint(x: CGFloat.infinity, y: 0)) == start,
                     "a non-finite move is ignored")
        var walked = start
        for _ in 0..<10 { walked = walked.nudged(.right, large: false) }
        suite.expect(walked.offset == start.nudged(.right, large: true).offset, "ten nudges make one Shift nudge")
        suite.expect(DesignOverlayNudge(keyCode: 123) == .left && DesignOverlayNudge(keyCode: 124) == .right
                        && DesignOverlayNudge(keyCode: 125) == .down && DesignOverlayNudge(keyCode: 126) == .up
                        && DesignOverlayNudge(keyCode: 0) == nil,
                     "the arrow keys map to their directions")
    }

    // MARK: Memory

    private static func memory(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.design-overlay"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let memory = DesignOverlayMemory(defaults: defaults)
        suite.expect(memory.record(for: "A") == nil && memory.lastImageName == nil, "a fresh Mac remembers nothing")

        let laptop = DesignOverlayDisplayRecord(offset: CGPoint(x: 12, y: 40), opacity: 0.35, scale: .x2, locked: true)
        let external = DesignOverlayDisplayRecord(offset: CGPoint(x: -300, y: 88.5), opacity: 0.8, scale: .automatic)
        memory.save(laptop, for: "LAPTOP-UUID")
        memory.save(external, for: "EXTERNAL-UUID")
        suite.expect(memory.record(for: "LAPTOP-UUID") == laptop && memory.record(for: "EXTERNAL-UUID") == external,
                     "each display keeps its own position, opacity, scale and lock")
        let again = DesignOverlayMemory(defaults: defaults)
        suite.expect(again.record(for: "LAPTOP-UUID")?.offset == CGPoint(x: 12, y: 40),
                     "the position survives a new reader of the same defaults")
        var moved = laptop
        moved.offset = CGPoint(x: 13, y: 40)
        memory.save(moved, for: "LAPTOP-UUID")
        suite.expect(memory.record(for: "LAPTOP-UUID") == moved && memory.record(for: "EXTERNAL-UUID") == external,
                     "saving one display leaves the other alone")
        memory.save(laptop, for: "")
        suite.expect(defaults.dictionary(forKey: DefaultsKey.designOverlayDisplays)?.count == 2,
                     "a display without an identity is not stored")

        for index in 0..<(DesignOverlayMemory.capacity + 3) {
            memory.save(external, for: "D\(index)", now: Date(timeIntervalSince1970: 1_000_000 + Double(index)))
        }
        let stored = defaults.dictionary(forKey: DefaultsKey.designOverlayDisplays) ?? [:]
        suite.expect(stored.count == DesignOverlayMemory.capacity && stored["D0"] == nil
                        && stored["D\(DesignOverlayMemory.capacity + 2)"] != nil,
                     "the records stay bounded and the oldest display goes first")

        defaults.set(["LAPTOP-UUID": ["x": "left", "y": 1]], forKey: DefaultsKey.designOverlayDisplays)
        suite.expect(memory.record(for: "LAPTOP-UUID") == nil, "a damaged record is ignored")
        defaults.set(["LAPTOP-UUID": ["x": 4, "y": 5, "opacity": 9, "scale": "x9"]], forKey: DefaultsKey.designOverlayDisplays)
        let repaired = memory.record(for: "LAPTOP-UUID")
        suite.expect(repaired?.opacity == 1 && repaired?.scale == .automatic && repaired?.locked == false,
                     "an out-of-range record is read back within range")

        memory.lastImageName = "reference.png"
        suite.expect(memory.lastImageName == "reference.png", "the last image is remembered by name only")
        memory.lastImageName = "../escape.png"
        suite.expect(memory.lastImageName == nil, "a name that is a path is refused")
        defaults.set("/etc/passwd", forKey: DefaultsKey.designOverlayLastImage)
        suite.expect(memory.lastImageName == nil, "a stored path is never read as a name")
        suite.expect(DesignOverlayMemory.referenceName(forExtension: "PNG") == "reference.png"
                        && DesignOverlayMemory.referenceName(forExtension: "jpg") == "reference.jpg"
                        && DesignOverlayMemory.referenceName(forExtension: "exe") == "reference.png",
                     "the copy keeps a picture's extension and nothing else")
    }

    // MARK: Grid

    private static func grid(_ suite: TestSuite) {
        let desktop = DesignOverlayGridPreset.desktop.grid
        let columns = desktop.columnFrames(in: CGSize(width: 1440, height: 900))
        suite.expect(columns.count == 12, "the desktop grid has twelve columns")
        suite.expect(columns.first?.minX == 80 && abs((columns.last?.maxX ?? 0) - 1360) < 0.001,
                     "the columns sit inside an 80 point margin on both sides")
        let width = (1440 - 160 - 24 * 11) / 12.0
        suite.expect(columns.allSatisfy { abs($0.width - width) < 0.001 && $0.height == 900 && $0.minY == 0 },
                     "every column is the same width and runs the frame's height")
        let gaps = zip(columns, columns.dropFirst()).map { $1.minX - $0.maxX }
        suite.expect(gaps.count == 11 && gaps.allSatisfy { abs($0 - 24) < 0.001 }, "a 24 point gutter between columns")

        let mobile = DesignOverlayGridPreset.mobile.grid.columnFrames(in: CGSize(width: 390, height: 844))
        suite.expect(mobile.count == 4 && mobile.first?.minX == 16 && abs((mobile.last?.maxX ?? 0) - 374) < 0.001
                        && abs(mobile[0].width - (390 - 32 - 48) / 4) < 0.001,
                     "the phone grid: four columns, 16 point gutters and margins")
        suite.expect(DesignOverlayGrid(columns: 12, gutter: 24, margin: 80).columnFrames(in: CGSize(width: 300, height: 10)).isEmpty,
                     "a grid that cannot fit draws nothing")
        suite.expect(DesignOverlayGrid(columns: 0, gutter: 0, margin: 0).columnFrames(in: CGSize(width: 300, height: 10)).isEmpty
                        && DesignOverlayGrid(columns: 3, gutter: -1, margin: 0).columnFrames(in: CGSize(width: 300, height: 10)).isEmpty,
                     "a grid without columns, or with a negative gutter, draws nothing")
        let single = DesignOverlayGrid(columns: 1, gutter: 20, margin: 0).columnFrames(in: CGSize(width: 300, height: 10))
        suite.expect(single == [CGRect(x: 0, y: 0, width: 300, height: 10)], "one column without margin fills the frame")
        suite.expect(desktop.label == "12 · 24 · 80" && DesignOverlayGrid(columns: 6, gutter: 12.5, margin: 0).label == "6 · 12.5 · 0",
                     "a preset reads as columns, gutter and margin")
        suite.expect(Set(DesignOverlayGridPreset.allCases.map(\.grid)).count == DesignOverlayGridPreset.allCases.count
                        && DesignOverlayGridPreset.stored("tablet") == .tablet && DesignOverlayGridPreset.stored(nil) == .desktop,
                     "the presets differ, and an unknown one reads as desktop")
    }

    // MARK: Geometry

    private static func geometry(_ suite: TestSuite) {
        let primary: CGFloat = 982
        let global = CGRect(x: 100, y: 50, width: 400, height: 300)
        let cocoa = Support.cocoaFrame(global, primaryHeight: primary)
        suite.expect(cocoa == CGRect(x: 100, y: 632, width: 400, height: 300)
                        && Support.globalFrame(cocoa, primaryHeight: primary) == global,
                     "global and AppKit frames convert both ways")
        let external = CGRect(x: 1512, y: -200, width: 2560, height: 1440)
        let offset = CGPoint(x: 40, y: 64)
        let frame = Support.frame(offset: offset, size: CGSize(width: 1440, height: 3200), display: external)
        suite.expect(frame.origin == CGPoint(x: 1552, y: -136)
                        && Support.offset(placing: frame.origin, in: external) == offset,
                     "an offset into a display places the image there and back")

        let visible = CGRect(x: 0, y: 33, width: 1512, height: 900)
        let small = CGRect(x: 100, y: 100, width: 600, height: 400)
        let hud = CGSize(width: 680, height: 64)
        suite.expect(Support.hudOrigin(image: small, hud: hud, visible: visible) == CGPoint(x: 100, y: 512),
                     "the HUD sits under the image when there is room")
        let low = CGRect(x: 100, y: 600, width: 600, height: 300)
        suite.expect(Support.hudOrigin(image: low, hud: hud, visible: visible) == CGPoint(x: 100, y: 524),
                     "then over it")
        let page = CGRect(x: 0, y: 33, width: 1440, height: 3200)
        let corner = Support.hudOrigin(image: page, hud: hud, visible: visible)
        suite.expect(corner == CGPoint(x: 1512 - 680 - 12, y: 933 - 64 - 12),
                     "a page taller than the screen leaves the HUD in the bottom corner: \(corner)")
        let right = Support.hudOrigin(image: CGRect(x: 1400, y: 100, width: 100, height: 100), hud: hud, visible: visible)
        suite.expect(right.x + hud.width <= visible.maxX, "the HUD never runs off the right edge")

        // Difference: the slice of a 2x reference behind the visible part of the image.
        let image = CGRect(x: 0, y: 900, width: 1440, height: 3200)
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let crop = Support.referenceCrop(frame: image, visible: screen, imageScale: 2)
        suite.expect(crop == CGRect(x: 0, y: 6400 - 164, width: 2880, height: 164),
                     "only the image's visible top strip is compared, in reference pixels from the bottom: \(crop)")
        let whole = Support.referenceCrop(frame: CGRect(x: 10, y: 10, width: 100, height: 50), visible: screen, imageScale: 1)
        suite.expect(whole == CGRect(x: 0, y: 0, width: 100, height: 50), "an image fully on screen is compared whole")
        suite.expect(Support.referenceCrop(frame: CGRect(x: 2000, y: 0, width: 10, height: 10), visible: screen,
                                           imageScale: 1) == .zero,
                     "an image off the display compares nothing")
        suite.expect(Support.capturePixels(CGSize(width: 1440, height: 164), displayScale: 2) == (2880, 328)
                        && Support.capturePixels(CGSize(width: 0.2, height: 0.2), displayScale: 2) == (1, 1),
                     "the capture asks for the display's own pixels")
    }

    // MARK: Fit

    private static func fit(_ suite: TestSuite) {
        let browser = DesignOverlayWindowCandidate(pid: 10, frame: CGRect(x: 0, y: 33, width: 1440, height: 900))
        let editor = DesignOverlayWindowCandidate(pid: 20, frame: CGRect(x: 900, y: 100, width: 600, height: 700))
        let sliver = DesignOverlayWindowCandidate(pid: 30, frame: CGRect(x: 0, y: 0, width: 1512, height: 24))
        let front = [sliver, editor, browser]
        suite.expect(Support.targetWindow(in: front, mouse: CGPoint(x: 1000, y: 300), frontmost: 10) == editor,
                     "the topmost window under the pointer wins")
        suite.expect(Support.targetWindow(in: front, mouse: CGPoint(x: 200, y: 300), frontmost: 20) == browser,
                     "a window under the pointer beats the frontmost app")
        suite.expect(Support.targetWindow(in: front, mouse: CGPoint(x: 5000, y: 5000), frontmost: 10) == browser,
                     "away from every window, the frontmost app's window")
        suite.expect(Support.targetWindow(in: front, mouse: CGPoint(x: 5, y: 5), frontmost: nil) == editor,
                     "slivers like a bar are skipped")
        suite.expect(Support.targetWindow(in: [], mouse: .zero, frontmost: nil) == nil, "no windows, no target")

        let window = CGRect(x: 0, y: 33, width: 1440, height: 900)
        let page = CGRect(x: 0, y: 120, width: 1440, height: 813)
        let frame = CGRect(x: 40, y: 300, width: 300, height: 250)
        suite.expect(Support.pageFrame([frame, page], window: window) == page,
                     "the page is the largest web area, not a frame inside it")
        suite.expect(Support.pageFrame([CGRect(x: 0, y: 120, width: 1440, height: 2000)], window: window)
                        == CGRect(x: 0, y: 120, width: 1440, height: 813),
                     "a page area is held inside its window")
        suite.expect(Support.pageFrame([CGRect(x: 0, y: 0, width: 10, height: 10)], window: window) == nil,
                     "without a real page area, Fit uses the window")
        suite.expect(Support.sameFrame(window, window.offsetBy(dx: 1, dy: -1)) && !Support.sameFrame(window, page),
                     "Accessibility and window server frames match within two points")
    }

    // MARK: Island

    private static func dropTargets(_ suite: TestSuite) {
        suite.expect(Support.dropTargets(photo: [.transform, .removeBackground], imageCount: 1, overlay: true)
                        == [.transform, .removeBackground, .overlay],
                     "one image gets Overlay after the photo actions")
        suite.expect(Support.dropTargets(photo: [.transform], imageCount: 3, overlay: true) == [.transform],
                     "several images get no Overlay")
        suite.expect(Support.dropTargets(photo: [.transform, .removeBackground], imageCount: 1, overlay: false)
                        == [.transform, .removeBackground],
                     "with the zone off, an image keeps the photo actions only")
        suite.expect(Support.dropTargets(photo: [], imageCount: 1, overlay: true) == [.overlay],
                     "with photo actions off, one image still gets Overlay")
        suite.expect(Support.dropTargets(photo: [], imageCount: 0, overlay: true).isEmpty, "no image, no Overlay")
        suite.expect(Support.dropTargets(photo: [.overlay, .transform], imageCount: 1, overlay: true) == [.transform, .overlay],
                     "Overlay appears once, last")
        suite.expect(NotchAirDropSupport.targets(files: true, airDrop: true, media: true,
                                                 photo: [.transform, .removeBackground, .overlay])
                        == [.files, .airDrop, .media, .transform, .removeBackground, .overlay],
                     "the island lays Overlay out after every other zone")
        suite.expect(NotchDropTarget.overlay.isPhotoAction && NotchPhotoAction(target: .overlay) == nil,
                     "Overlay is an image target but not a photo action")
    }

    /// NotchService's own begin, update and accept, compiled against the drop doubles.
    private static func dropRouting(_ suite: TestSuite) {
        typealias Context = ShelfDropRoutingContract
        let board = NSPasteboard.withUniqueName()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("design-overlay-drop-\(UUID().uuidString)", isDirectory: true)
        defer {
            board.releaseGlobally()
            try? FileManager.default.removeItem(at: folder)
            Context.ShelfService.shared = Context.ShelfService()
            Context.NotchFileToolsService.shared = Context.NotchFileToolsService()
            Context.NotchPhotoActionsService.shared = Context.NotchPhotoActionsService()
            Context.DesignOverlayService.shared = Context.DesignOverlayService()
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let image = folder.appendingPathComponent("frame.png")
        _ = writePNG(width: 8, height: 8, dpi: nil, to: image)
        board.clearContents()
        board.writeObjects([image as NSURL])

        func reset() {
            Context.AppFeature.shelf.isAvailable = true
            Context.UserDefaults.standard.enabled = true
            Context.ShelfService.shared = Context.ShelfService()
            Context.NotchFileToolsService.shared = Context.NotchFileToolsService()
            Context.NotchPhotoActionsService.shared = Context.NotchPhotoActionsService()
            Context.NotchPhotoActionsService.shared.targets = [.transform, .removeBackground, .overlay]
            Context.DesignOverlayService.shared = Context.DesignOverlayService()
        }
        func lastColumn(_ notch: Context.Notch) -> CGPoint {
            let content = notch.geometry.contentSize(for: notch.surfaceSize)
            let left = notch.surfaceSize.width / 2 - content.width / 2
            let columns = CGFloat(NotchAirDropSupport.targets(files: notch.offersFilesDrop, airDrop: notch.offersAirDrop,
                                                              media: notch.offersMediaDrop,
                                                              photo: notch.offersPhotoTargets).count)
            return CGPoint(x: left + content.width * (columns - 0.5) / columns, y: 10)
        }

        reset()
        let notch = Context.Notch()
        notch.acceptsPhotoDrop = true
        notch.beginFileDrop(board)
        suite.expect(notch.choosingFileDropDestination && notch.offersPhotoTargets.last == .overlay,
                     "an image drag offers the Overlay zone last")
        suite.expect(notch.updateFileDrop(at: lastColumn(notch)) && notch.photoDropTarget == .overlay
                        && !notch.targetsAirDrop && !notch.targetsMediaDrop,
                     "the last column is Overlay, and it takes the drop")
        Context.NotchPhotoActionsService.shared.canAcceptDrop = false
        suite.expect(notch.updateFileDrop(at: lastColumn(notch)),
                     "a running photo job does not keep the overlay from taking a reference")
        let collapses = notch.collapses
        let pages = notch.opened
        let accepted = notch.accept(board)
        let overlay = Context.DesignOverlayService.shared
        suite.expect(accepted && overlay.opened == 1 && notch.collapses == collapses + 1
                        && !notch.heldDrag && !notch.dragPlaceholder,
                     "a drop on Overlay opens the overlay and closes the island")
        suite.expect(Context.NotchPhotoActionsService.shared.opened.isEmpty && notch.opened == pages
                        && Context.ShelfService.shared.ordinaryAccepts == 0
                        && Context.NotchFileToolsService.shared.mediaSession == nil,
                     "a drop on Overlay reaches neither the photo actions, the Files page, the shelf nor the media tools")
        suite.expect(notch.offersPhotoTargets.isEmpty && notch.photoDropTarget == nil && !notch.choosingFileDropDestination,
                     "the drop clears the zones")

        reset()
        Context.DesignOverlayService.shared.accepts = false
        let refused = Context.Notch()
        refused.acceptsPhotoDrop = true
        refused.beginFileDrop(board)
        _ = refused.updateFileDrop(at: lastColumn(refused))
        let before = refused.collapses
        suite.expect(!refused.accept(board) && refused.collapses == before && refused.heldDrag,
                     "an image the overlay cannot read leaves the island as it was")

        reset()
        let transform = Context.Notch()
        transform.acceptsPhotoDrop = true
        transform.beginFileDrop(board)
        let content = transform.geometry.contentSize(for: transform.surfaceSize)
        let left = transform.surfaceSize.width / 2 - content.width / 2
        let count = CGFloat(NotchAirDropSupport.targets(files: transform.offersFilesDrop, airDrop: transform.offersAirDrop,
                                                        media: transform.offersMediaDrop,
                                                        photo: transform.offersPhotoTargets).count)
        _ = transform.updateFileDrop(at: CGPoint(x: left + content.width * (count - 2.5) / count, y: 10))
        suite.expect(transform.photoDropTarget == .transform && transform.accept(board)
                        && Context.NotchPhotoActionsService.shared.opened == [.transform]
                        && Context.DesignOverlayService.shared.opened == 0,
                     "Transform still goes to the photo actions beside Overlay")
    }

    // MARK: Preferences and words

    private static func preferences(_ suite: TestSuite) {
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.designOverlayShortcutEnabled] as? Bool == true
                        && registered[DefaultsKey.designOverlayShortcut] as? String
                            == GlobalShortcut.designOverlayDefault.storageValue
                        && registered[DefaultsKey.designOverlayDefaultOpacity] as? Double == 0.5
                        && registered[DefaultsKey.designOverlayDefaultBlend] as? String == DesignOverlayBlend.normal.rawValue
                        && registered[DefaultsKey.designOverlayGridPreset] as? String == DesignOverlayGridPreset.desktop.rawValue
                        && registered[DefaultsKey.designOverlayDropEnabled] as? Bool == true,
                     "the overlay's preferences are registered, so they travel in backups")
        suite.expect(registered[DefaultsKey.designOverlayDisplays] == nil && registered[DefaultsKey.designOverlayLastImage] == nil
                        && !SettingsBackupSupport.exportKeys().contains(DefaultsKey.designOverlayDisplays)
                        && !SettingsBackupSupport.exportKeys().contains(DefaultsKey.designOverlayLastImage),
                     "positions and the last image are this Mac's state and stay out of backups")
        suite.expect(GlobalShortcut.designOverlayDefault == GlobalShortcut(keyCode: 31, modifiers: [.option, .command]),
                     "the default shortcut is Option-Command-O")
        let role = GlobalShortcutRole.designOverlay
        suite.expect(role.storageKey == DefaultsKey.designOverlayShortcut && role.defaultShortcut == .designOverlayDefault
                        && role.requiredEnableKeys == [DefaultsKey.designOverlayShortcutEnabled]
                        && role.feature == .screenshot,
                     "the overlay's shortcut role is wired to its own keys and follows the screenshot tool")
        suite.expect(GlobalShortcutRole.captureRoles(in: GlobalShortcutRole.allCases).last == .designOverlay,
                     "the shortcut lists last in the Screen capture group")
        suite.expect(DesignOverlayBlend.stored("difference") == .difference && DesignOverlayBlend.stored("x") == .normal,
                     "an unknown stored blend reads as normal")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.designOverlay(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 28 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("—") },
                         "\(language.rawValue) words the design overlay, with curly apostrophes and no em dash")
        }
        suite.expect(GlobalShortcutRole.designOverlay.title(L10n.shared.s) == ZenithStrings.designOverlay(L10n.shared.language).title,
                     "the shortcut is named after the overlay")
    }
}
