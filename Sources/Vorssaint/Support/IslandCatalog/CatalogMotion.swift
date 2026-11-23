// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import CoreImage
import SwiftUI

// Zenith fork: the padlock island's states for the catalog, and frame
// sequences of the island's transitions (`ONLY=motion…`), drawn from the
// catalog's own renders of both ends with the island's motion maths:
// NotchMotionTimeline for the shape, ZenithContentRide for the content.

extension CatalogShots {
    /// The padlock island over the lock screen, in each of its states.
    static var lockIslands: [CatalogShot] {
        [
            lockIsland("lock-island-rest") { _ in },
            lockIsland("lock-island-music", setup: { CatalogSamples.music() }) { _ in },
            lockIsland("lock-island-charging") { $0.charging = true; $0.percent = 82 },
            lockIsland("lock-island-focus") { $0.charging = true; $0.percent = 82; $0.focus = "Work" },
            lockIsland("lock-island-farewell", open: true) { $0.moment = .farewell },
            lockIsland("lock-island-remote") { $0.moment = .remoteLock(device: "Faiz’s iPhone") }, // Zenith fork: remote lock
            lockIsland("lock-island-remote-long") { $0.moment = .remoteLock(device: CatalogShots.longDevice) },
            // Zenith fork: unlocked, the welcome grown in the padlock island before the
            // desktop island takes it over, and the bare notch it leaves into.
            lockIsland("lock-island-welcome", open: true) { $0.moment = .welcome(CatalogShots.lockWelcome) },
            lockIsland("lock-island-bare") { $0.moment = .bare },
            // Zenith fork: face unlock (FaceUnlockIslandStage), Glance's animations drawn as stills.
            lockIsland("lock-island-face-armed") { $0.face = .armed },
            lockIsland("lock-island-face-armed-music", setup: { CatalogSamples.music() }) { $0.face = .armed },
            lockIsland("lock-island-face-scanning") { $0.face = .scanning },
            lockIsland("lock-island-face-success") { $0.face = .success },
            lockIsland("lock-island-face-failure") { $0.face = .failure(.wrongFace) },
            lockIsland("lock-island-face-touchid") { $0.face = .needsTouchID },
            lockIsland("lock-island-face-minimal-scanning") { $0.faceStyle = .minimal; $0.face = .scanning },
            lockIsland("lock-island-face-minimal-success") { $0.faceStyle = .minimal; $0.face = .success },
            lockIsland("lock-island-face-none-failure") { $0.faceStyle = .none; $0.face = .failure(.timedOut) },
        ]
    }

    /// Zenith fork: the welcome as the padlock island grows it on unlocking.
    static var lockWelcome: ZenithWelcomeBurst {
        ZenithWelcomeBurst(title: "Welcome back, Faiz", subtitle: "Locked for 2h 14m", photo: nil, initials: "FA")
    }

    /// `frozen` draws the island that far into its entrance from `entrance`, still.
    fileprivate static func lockIsland(_ id: String, open: Bool = false, frozen: TimeInterval? = nil,
                                       entrance: CGSize? = nil, setup: @escaping @MainActor () -> Void = {},
                                       pose: @escaping @MainActor (ZenithLockIslandModel) -> Void) -> CatalogShot {
        CatalogShot(id: id, setup: setup, settle: frozen == nil ? 0.4 : 0.02) {
            let geometry = notched
            let camera = geometry.bareCutout
            let surface = NotchLockScreenLayout.islandSurface(
                in: geometry.screen, cameraWidth: camera.width, cameraHeight: camera.height,
                wing: geometry.lockScreenMusicGeometry.compactActivityWingWidth)
                ?? CGRect(x: geometry.screen.midX - 140, y: geometry.screen.maxY - 32, width: 280, height: 32)
            let window = ZenithLockIsland.windowFrame(around: surface, in: geometry.screen)
            let model = NotchLockScreenModel()
            model.gates.music = true
            model.padlockOpen = open
            let island = ZenithLockIslandModel()
            island.firstName = "Faiz"
            pose(island)
            island.entrance = entrance
            let view = ZenithLockScreenIsland(model: model, island: island, size: surface.size, cameraWidth: camera.width,
                                              geometry: geometry.lockScreenMusicGeometry, window: window.size,
                                              origin: CGPoint(x: surface.minX - window.minX, y: window.maxY - surface.maxY),
                                              frozen: frozen, stillMedia: true) // Zenith fork: no video layer offscreen
            return (AnyView(view), window.size)
        }
    }
}

/// Frame sequences of the island's transitions.
@MainActor
enum CatalogMotion {
    struct Sequence {
        let id: String
        let from: String
        let to: String
    }

    static let sequences: [Sequence] = [
        Sequence(id: "motion-open", from: "closed-idle", to: "page-home"),
        Sequence(id: "motion-swap", from: "page-home", to: "page-system"),
        Sequence(id: "motion-close", from: "page-home", to: "closed-idle"),
        Sequence(id: "motion-notice", from: "closed-idle", to: "notice-volume"),
        Sequence(id: "motion-burst", from: "closed-idle", to: "burst-prayer"),
        Sequence(id: "motion-lock-farewell", from: "lock-island-rest", to: "lock-island-farewell"),
        Sequence(id: "motion-close-strip", from: "page-home", to: "compact-music"),
        Sequence(id: "motion-welcome", from: "closed-idle", to: "burst-welcome"),
        Sequence(id: "motion-welcome-close", from: "burst-welcome", to: "closed-idle"),
        Sequence(id: "motion-claude", from: "closed-idle", to: "burst-claude"),
        Sequence(id: "motion-remote-status", from: "closed-idle", to: "burst-remote-status"),
        Sequence(id: "motion-lock-remote", from: "lock-island-rest", to: "lock-island-remote"),
        // Zenith fork: back into the padlock pill, and the pill growing into the welcome as the Mac unlocks.
        Sequence(id: "motion-lock-remote-close", from: "lock-island-remote", to: "lock-island-rest"),
        Sequence(id: "motion-unlock-welcome", from: "lock-island-music", to: "burst-welcome-remote"),
        // Zenith fork: unlocking, the welcome grows in the padlock island itself; face unlock's scan.
        Sequence(id: "motion-unlock-padlock-welcome", from: "lock-island-music", to: "lock-island-welcome"),
        Sequence(id: "motion-face-scan", from: "lock-island-face-armed", to: "lock-island-face-scanning"),
        Sequence(id: "motion-face-success-welcome", from: "lock-island-face-success", to: "lock-island-welcome"),
        // Zenith fork: the minimal style's success straight into the welcome, never through the pill.
        Sequence(id: "motion-face-minimal-success-welcome", from: "lock-island-face-minimal-success", to: "lock-island-welcome"),
    ]

    /// Zenith fork: the padlock island's own entrance as the Mac locks, drawn
    /// frame by frame by its real view: growing out of the desktop island
    /// (`from`, a closed island shot) straight into its opening moment, whose
    /// content shows from the first frame.
    struct Entrance {
        let id: String
        let from: String
        var open = false
        let pose: @MainActor (ZenithLockIslandModel) -> Void
    }

    static let entrances: [Entrance] = [
        Entrance(id: "motion-lock-entrance-farewell", from: "compact-music", open: true) { $0.moment = .farewell },
        Entrance(id: "motion-lock-entrance-remote", from: "compact-music") { $0.moment = .remoteLock(device: "Faiz’s iPhone") },
        Entrance(id: "motion-lock-entrance-rest", from: "compact-music") { _ in },
        // Zenith fork: as the Mac locks now, from the bare notch, whatever face unlock shows.
        Entrance(id: "motion-lock-entrance-notch-farewell", from: "lock-island-bare", open: true) { $0.moment = .farewell },
        Entrance(id: "motion-lock-entrance-face-armed", from: "lock-island-bare") { $0.face = .armed },
        Entrance(id: "motion-lock-entrance-face-minimal-scanning", from: "lock-island-bare") {
            $0.faceStyle = .minimal; $0.face = .scanning
        },
    ]

    /// Frames per second and seconds drawn; `ZENITH_MOTION_FPS` and
    /// `ZENITH_MOTION_LENGTH` override them, as for a 120 fps check.
    static let fps = ProcessInfo.processInfo.environment["ZENITH_MOTION_FPS"].flatMap(Double.init) ?? 30
    static let length: TimeInterval = ProcessInfo.processInfo.environment["ZENITH_MOTION_LENGTH"].flatMap(Double.init) ?? 1

    /// Renders every sequence whose id starts with `prefix`; the failures' ids.
    static func render(prefix: String, into folder: URL) -> [String] {
        var failures: [String] = []
        let shots = Dictionary(CatalogShots.all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sources = folder.appendingPathComponent("motion-sources", isDirectory: true)
        try? FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        for entrance in entrances where entrance.id.hasPrefix(prefix) {
            guard let from = shots[entrance.from], let start = end(from, in: sources) else {
                failures.append(entrance.id)
                continue
            }
            print("entrance \(entrance.id) from \(Int(start.size.width))x\(Int(start.size.height))")
            let count = Int(length * fps)
            let frames = (0...count).compactMap { index -> CGImage? in
                let shot = CatalogShots.lockIsland(entrance.id, open: entrance.open, frozen: Double(index) / fps,
                                                   entrance: start.size, pose: entrance.pose)
                let url = sources.appendingPathComponent(String(format: "%@-%03d.png", entrance.id, index))
                guard CatalogRenderer.render(shot, to: url) != nil,
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
                return CGImageSourceCreateImageAtIndex(source, 0, nil)
            }
            var written = 0
            for (index, frame) in frames.enumerated() {
                let url = folder.appendingPathComponent(String(format: "%@-%02d.png", entrance.id, index))
                if write(frame, to: url) { written += 1 }
            }
            if frames.count == count + 1, let sheet = sheet(frames),
               write(sheet, to: folder.appendingPathComponent(entrance.id + "-sheet.png")) {
                print("rendered \(entrance.id): \(written) frames and a sheet")
            } else {
                failures.append(entrance.id)
            }
        }
        for sequence in sequences where sequence.id.hasPrefix(prefix) {
            guard let from = shots[sequence.from], let to = shots[sequence.to],
                  let start = end(from, in: sources), let finish = end(to, in: sources) else {
                failures.append(sequence.id)
                continue
            }
            let frames = draw(sequence, from: start, to: finish)
            var written = 0
            for (index, frame) in frames.enumerated() {
                let url = folder.appendingPathComponent(String(format: "%@-%02d.png", sequence.id, index))
                if write(frame, to: url) { written += 1 }
            }
            if let sheet = sheet(frames), write(sheet, to: folder.appendingPathComponent(sequence.id + "-sheet.png")) {
                print("rendered \(sequence.id): \(written) frames and a sheet")
            } else {
                failures.append(sequence.id)
            }
        }
        return failures
    }

    /// One end of a transition: the shot's render, and the island inside it.
    private struct End {
        let image: CGImage
        /// Pixels per point, and the island's box in pixels, top left origin.
        let scale: CGFloat
        let island: CGRect
        var size: CGSize { CGSize(width: island.width / scale, height: island.height / scale) }
        var content: CGImage? { image.cropping(to: island) }
    }

    private static func end(_ shot: CatalogShot, in folder: URL) -> End? {
        let url = folder.appendingPathComponent(shot.id + ".png")
        guard let entry = CatalogRenderer.render(shot, to: url),
              let width = entry["width"] as? CGFloat, width > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let box = opaqueBox(image) else { return nil }
        return End(image: image, scale: CGFloat(image.width) / width, island: box)
    }

    /// The island is the render's opaque part: its black silhouette.
    private static func opaqueBox(_ image: CGImage) -> CGRect? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 200 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // The bitmap's rows run from the top.
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private static let context = CIContext()
    private static var blurs: [String: CGImage] = [:]

    private static func blurred(_ image: CGImage, radius: CGFloat, key: String) -> (CGImage, CGFloat) {
        let rounded = (radius * 2).rounded() / 2
        guard rounded > 0 else { return (image, 0) }
        let id = "\(key)-\(rounded)"
        if let cached = blurs[id] { return (cached, 0) }
        // Edges clamped: the island's own shape clips the content anyway.
        let input = CIImage(cgImage: image)
        guard let output = context.createCGImage(input.clampedToExtent().applyingGaussianBlur(sigma: rounded)
                                                    .cropped(to: input.extent), from: input.extent) else { return (image, 0) }
        blurs[id] = output
        return (output, 0)
    }

    private static func draw(_ sequence: Sequence, from start: End, to finish: End) -> [CGImage] {
        let scale = max(start.scale, finish.scale)
        let floor = sequence.id.hasPrefix("motion-lock")
            ? NotchMotionFloor.floor(camera: CGSize(width: CatalogShots.notched.bareCutout.width, height: min(start.size.height, finish.size.height)),
                                     target: finish.size, closedHeight: min(start.size.height, finish.size.height))
            : NotchMotionFloor.floor(for: finish.size, geometry: CatalogShots.notched)
        let timeline = NotchMotionTimeline(from: start.size, to: finish.size, begin: 0, floor: floor)
        // Closing (the island getting shorter) lets the page leave with the shrink.
        let timing: ZenithContentRide.Timing = finish.size.height < start.size.height ? .closing : .opening
        // The content's folded scale and opacity as the window host draws them.
        let probe = [0, 0.02, 0.04, 0.06, 0.08, 0.12, 0.2, 0.3, 0.45, 0.7, 1.0]
        let dense = stride(from: 0.0, through: 1.0, by: 1.0 / 240).map { $0 }
        let composites = ZenithContentRide.frames(at: dense, islandWidths: dense.map { timeline.shape(at: $0).width },
                                                  from: start.size.width, to: finish.size.width, timing: timing)
        let samples = probe.map { time -> String in
            let shape = timeline.shape(at: time)
            let frame = composites[min(composites.count - 1, Int((time * 240).rounded()))]
            let scale = Int((frame.scale * 100).rounded()), opacity = Int((frame.opacity * 100).rounded())
            return "\(Int((time * 1_000).rounded())) ms \(Int(shape.width.rounded()))x\(Int(shape.height.rounded()))"
                + " scale \(scale)% opacity \(opacity)%"
        }
        print("samples \(sequence.id) floor \(Int(floor.width))x\(Int(floor.height)): " + samples.joined(separator: ", "))
        var incomingFloor: CGFloat = 0
        let reach = timeline.frames().sizes.reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) }
        let canvas = CGSize(width: (reach.width + 160).rounded(.up), height: (reach.height + 60).rounded(.up))
        let count = Int(length * fps)
        return (0...count).compactMap { index in
            let time = Double(index) / fps
            let shape = timeline.shape(at: time)
            let pixels = CGSize(width: canvas.width * scale, height: canvas.height * scale)
            guard let context = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            // Points, from the top left.
            context.translateBy(x: 0, y: pixels.height)
            context.scaleBy(x: scale, y: -scale)
            context.setFillColor(CGColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1))
            context.fill(CGRect(origin: .zero, size: canvas))
            // The island's path is drawn from its own origin, then moved to the centre.
            var centre = CGAffineTransform(translationX: (canvas.width - shape.width) / 2, y: 0)
            let local = NotchShape(attached: true, radius: NotchLayout.surfaceRadius(height: shape.height))
                .path(in: CGRect(origin: .zero, size: shape)).cgPath
            let path = local.copy(using: &centre) ?? local
            context.addPath(path)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fillPath()
            context.saveGState()
            context.addPath(path)
            context.clip()
            let leaving = ZenithContentRide.outgoing(at: time, islandWidth: shape.width, pageWidth: start.size.width, timing: timing)
            let arriving = ZenithContentRide.incoming(at: time, islandWidth: shape.width, pageWidth: finish.size.width,
                                                      timing: timing, scaleFloor: incomingFloor)
            incomingFloor = max(incomingFloor, arriving.scale)
            place(start, layer: leaving, key: sequence.id + "-from", in: context, canvas: canvas)
            place(finish, layer: arriving, key: sequence.id + "-to", in: context, canvas: canvas)
            context.restoreGState()
            return context.makeImage()
        }
    }

    /// One end's content at its ride's opacity, blur, scale and rise, hung
    /// from the island's top centre.
    private static func place(_ end: End, layer: ZenithContentRide.Layer, key: String, in context: CGContext, canvas: CGSize) {
        guard layer.opacity > 0.005, let content = end.content else { return }
        let (image, pad) = blurred(content, radius: layer.blur * end.scale, key: key)
        let size = CGSize(width: end.size.width * layer.scale, height: end.size.height * layer.scale)
        let padding = pad / end.scale * layer.scale
        let rect = CGRect(x: (canvas.width - size.width) / 2 - padding, y: layer.offset * layer.scale - padding,
                          width: size.width + padding * 2, height: size.height + padding * 2)
        context.saveGState()
        context.setAlpha(CGFloat(layer.opacity))
        // CGContext draws images upright in a flipped space only when flipped back.
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    /// Every other frame, half size, three to a row, numbered.
    private static func sheet(_ frames: [CGImage]) -> CGImage? {
        let picked = frames.enumerated().filter { $0.offset % max(2, Int(fps / 30)) == 0 }
        guard let first = picked.first?.element else { return nil }
        let cell = CGSize(width: first.width / 2, height: first.height / 2)
        let columns = 3, rows = (picked.count + columns - 1) / columns
        let label: CGFloat = 26
        let size = CGSize(width: cell.width * CGFloat(columns), height: (cell.height + label) * CGFloat(rows))
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: 0.1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        for (position, entry) in picked.enumerated() {
            let column = position % columns, row = position / columns
            let origin = CGPoint(x: CGFloat(column) * cell.width, y: size.height - CGFloat(row + 1) * (cell.height + label))
            context.draw(entry.element, in: CGRect(origin: origin, size: cell))
            let text = NSAttributedString(string: "\(Int((Double(entry.offset) / fps * 1_000).rounded())) ms",
                                          attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .semibold),
                                                       .foregroundColor: NSColor.white])
            let line = CTLineCreateWithAttributedString(text)
            context.textPosition = CGPoint(x: origin.x + 8, y: origin.y + cell.height + 6)
            CTLineDraw(line, context)
        }
        return context.makeImage()
    }

    private static func write(_ image: CGImage, to url: URL) -> Bool {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }
}
#endif
