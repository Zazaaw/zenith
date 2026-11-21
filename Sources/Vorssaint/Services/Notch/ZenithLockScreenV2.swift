// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import CoreImage
import OpenDirectory
import SwiftUI
import SystemConfiguration

/// Zenith fork: who is at this Mac, for the full layer's bottom left corner.
/// Read from this Mac only: the account's own picture, full name and the
/// computer's name. Nothing leaves the Mac.
struct ZenithLockScreenAccount: Equatable {
    var name: String
    var device: String
    var photo: NSImage?
    var initials: String { ZenithLockScreenInitials.of(name) }

    /// Off the main thread: Open Directory answers from the local node.
    static func photoData() -> Data? {
        guard let node = try? ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeLocalNodes)),
              let record = try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(),
                                            attributes: [kODAttributeTypeJPEGPhoto, kODAttributeTypePicture]) else { return nil }
        if let data = (try? record.values(forAttribute: kODAttributeTypeJPEGPhoto))?.first as? Data, !data.isEmpty {
            return data
        }
        // An account picked from the system's set keeps a path instead.
        guard let path = (try? record.values(forAttribute: kODAttributeTypePicture))?.first as? String,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              (attributes[.size] as? Int ?? 0) <= 8 * 1024 * 1024 else { return nil }
        return FileManager.default.contents(atPath: path)
    }

    static func deviceName() -> String {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? Host.current().localizedName ?? ""
    }
}

/// Zenith fork: the blurred cover behind the full layer, rendered once per
/// song; a new `id` crossfades to it.
struct ZenithLockScreenBackdropImage: Equatable {
    let id: Int
    let image: NSImage
}

/// Zenith fork: what the lock screen v2 shows, settled when the lock screen
/// appears, and whether the full layer is up.
final class ZenithLockScreenV2Model: ObservableObject {
    @Published var gates = ZenithLockScreenV2Gates()
    @Published var fullShown = false
    @Published var scheme = ZenithLockScreenPalette.Scheme.neutral
    @Published var backdrop: ZenithLockScreenBackdropImage?
    @Published var account: ZenithLockScreenAccount?
    /// Whether the lyric's hover hint may still show, read as the lock screen appears.
    @Published private(set) var hintAvailable = false
    private var hintCounted = false
    var openFull: () -> Void = {}
    var closeFull: () -> Void = {}

    func readHint(in defaults: UserDefaults = .standard) {
        hintAvailable = ZenithLockScreenHint.shows(count: defaults.integer(forKey: DefaultsKey.zenithLockLyricHintCount))
        hintCounted = false
    }

    /// Counted once per lock screen, however often the lyric is hovered.
    func noteHintShown(in defaults: UserDefaults = .standard) {
        guard hintAvailable, !hintCounted else { return }
        hintCounted = true
        defaults.set(defaults.integer(forKey: DefaultsKey.zenithLockLyricHintCount) + 1,
                     forKey: DefaultsKey.zenithLockLyricHintCount)
    }

    /// Timed lines to sing along with, which the minimal lyric and the full
    /// layer both need.
    static func timedLyrics(_ lyrics: NotchLyrics?, playback: NotchPlayback?) -> NotchLyrics? {
        guard let lyrics, !lyrics.instrumental, !lyrics.lines.isEmpty, playback?.hasPosition == true else { return nil }
        return lyrics
    }
}

/// Zenith fork: runs the lock screen v2 while the lock screen shows. The lock
/// screen service builds the panels; this opens and closes the full layer,
/// keeps the lyrics and the cover colour current, and stops it all on hide.
final class ZenithLockScreenV2 {
    let model = ZenithLockScreenV2Model()
    private var full: NotchLockScreenPanel?
    private weak var island: NSPanel?
    private var subscriptions = Set<AnyCancellable>()
    private var pointerTimer: Timer?
    private var pointerOrigin = CGPoint.zero
    private var keyMonitors: [Any] = []
    private var closeWork: DispatchWorkItem?
    private var lyricsShown = false
    private var accountRequest = 0
    private var backdropRequest = 0
    private var screenSize = CGSize.zero
    private static let renderQueue = DispatchQueue(label: "com.vorssaint.lockscreen-v2.backdrop", qos: .utility)
    private static let imageContext = CIContext(options: [.cacheIntermediates: false])

    init() {
        model.openFull = { [weak self] in self?.openFull() }
        model.closeFull = { [weak self] in self?.closeFull(animated: true) }
    }

    /// As the lock screen appears. `full` has joined the lock screen's Space
    /// but is not ordered in; `island` stays drawn above it.
    func begin(_ gates: ZenithLockScreenV2Gates, full: NotchLockScreenPanel?, island: NSPanel?) {
        subscriptions.removeAll()
        model.gates = gates
        model.fullShown = false
        model.readHint()
        self.full = full
        self.island = island
        let music = NotchMusicService.shared
        if gates.lyrics {
            // The island's own lookup, with its own consent: online only when
            // the island may go online, the stored lines otherwise.
            lyricsShown = true
            music.$playback
                .receive(on: DispatchQueue.main)
                .sink { [weak self] playback in
                    NotchLyricsService.shared.update(playback: playback, visible: true)
                    self?.checkFull()
                }
                .store(in: &subscriptions)
            NotchLyricsService.shared.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.checkFull() }
                .store(in: &subscriptions)
        }
        screenSize = full?.frame.size ?? .zero
        model.backdrop = nil
        model.scheme = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: nil)
        let followsCover = gates.full && (gates.fullBackground == .blurredCover || gates.fullCoverColor)
        if followsCover {
            music.$artwork
                .receive(on: DispatchQueue.main)
                .removeDuplicates { $0 === $1 }
                .sink { [weak self] image in self?.coverChanged(image) }
                .store(in: &subscriptions)
        }
        if gates.fullAccount || gates.fullDevice { loadAccount() } else { model.account = nil }
    }

    /// As the lock screen leaves. Hands back the full layer when it is on
    /// screen, so it can fade out with the rest.
    func end() -> NotchLockScreenPanel? {
        subscriptions.removeAll()
        stopWatching()
        closeWork?.cancel()
        closeWork = nil
        accountRequest += 1
        backdropRequest += 1
        model.backdrop = nil
        if lyricsShown {
            lyricsShown = false
            NotchLyricsService.shared.hide()
        }
        let visible = full?.isVisible == true ? full : nil
        if visible == nil { full?.orderOut(nil) }
        full = nil
        island = nil
        model.fullShown = false
        return visible
    }

    private func loadAccount() {
        accountRequest += 1
        let request = accountRequest
        let gates = model.gates
        let name = NSFullUserName()
        model.account = ZenithLockScreenAccount(name: gates.fullAccount ? name : "", device: "", photo: nil)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let photo = gates.fullAccount ? ZenithLockScreenAccount.photoData() : nil
            let device = gates.fullDevice ? ZenithLockScreenAccount.deviceName() : ""
            DispatchQueue.main.async {
                guard let self, self.accountRequest == request else { return }
                self.model.account = ZenithLockScreenAccount(name: gates.fullAccount ? name : "", device: device,
                                                             photo: photo.flatMap(NSImage.init(data:)))
            }
        }
    }

    // MARK: Full layer

    private var fullFits: Bool {
        let music = NotchMusicService.shared
        guard model.gates.full, music.playback?.isPlaying == true else { return false }
        let lyrics = NotchLyricsService.shared
        return ZenithLockScreenV2Model.timedLyrics(lyrics.lyrics, playback: music.playback) != nil || lyrics.state == .loading
    }

    private func openFull() {
        guard let full, !model.fullShown, fullFits else { return }
        model.fullShown = true
        full.alphaValue = 0
        full.orderFrontRegardless()
        // The padlock island stays over the full layer.
        if let island, island.isVisible { island.orderFrontRegardless() }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            full.animator().alphaValue = 1
        }
        startWatching()
    }

    private func closeFull(animated: Bool) {
        guard model.fullShown else { return }
        model.fullShown = false
        stopWatching()
        closeWork?.cancel()
        closeWork = nil
        guard let full else { return }
        guard animated else { full.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            full.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak full] in
            // Opened again while fading: it stays.
            guard let full, self?.model.fullShown != true else { return }
            full.orderOut(nil)
        })
    }

    /// Music that stops, or a song with no timed lines, sends the full layer
    /// back after a moment's grace.
    private func checkFull() {
        guard model.fullShown else { return }
        if fullFits {
            closeWork?.cancel()
            closeWork = nil
            return
        }
        guard closeWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.closeWork = nil
            if !self.fullFits { self.closeFull(animated: true) }
        }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + ZenithLockScreenFullExit.pauseGrace, execute: work)
    }

    /// The pointer moving, or a key if one reaches this app while locked,
    /// hands the screen back to the login controls. The panels never take
    /// key focus, so the keystroke still goes to the password field.
    private func startWatching() {
        stopWatching()
        pointerOrigin = NSEvent.mouseLocation
        let timer = Timer(timeInterval: ZenithLockScreenFullExit.pollInterval, repeats: true) { [weak self] _ in
            self?.pollPointer()
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown], handler: { [weak self] _ in
            self?.closeFull(animated: true)
        }) { keyMonitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { [weak self] event in
            self?.closeFull(animated: true)
            return event
        }) { keyMonitors.append(monitor) }
    }

    private func stopWatching() {
        pointerTimer?.invalidate()
        pointerTimer = nil
        keyMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors.removeAll()
    }

    private func pollPointer() {
        guard model.fullShown else { stopWatching(); return }
        if ZenithLockScreenFullExit.moved(from: pointerOrigin, to: NSEvent.mouseLocation) { closeFull(animated: true) }
    }

    // MARK: Cover colour

    private func coverChanged(_ image: NSImage?) {
        let gates = model.gates
        backdropRequest += 1
        switch gates.fullBackground {
        case .solid:
            let scheme = ZenithLockScreenPalette.scheme(for: gates, cover: image.flatMap(Self.dominantColor(of:)),
                                                        blurredAverage: nil)
            if model.scheme != scheme { model.scheme = scheme }
        case .blurredCover:
            guard let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                model.backdrop = nil
                model.scheme = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: nil)
                return
            }
            let request = backdropRequest
            let radius = gates.fullBlurRadius
            let screen = screenSize
            // Blurred once per song, off the main thread, on a small copy.
            Self.renderQueue.async { [weak self] in
                let rendered = Self.blurredCover(cgImage, points: radius, screen: screen)
                DispatchQueue.main.async {
                    guard let self, self.backdropRequest == request else { return }
                    guard let rendered else {
                        self.model.backdrop = nil
                        self.model.scheme = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: nil)
                        return
                    }
                    let size = NSSize(width: rendered.image.width, height: rendered.image.height)
                    self.model.backdrop = ZenithLockScreenBackdropImage(id: request, image: NSImage(cgImage: rendered.image, size: size))
                    self.model.scheme = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: rendered.average)
                }
            }
        }
    }

    /// The cover filled into a small square, Gaussian-blurred by what
    /// `points` comes to once that square fills `screen`, with its mean colour.
    static func blurredCover(_ cover: CGImage, points: Double,
                             screen: CGSize) -> (image: CGImage, average: ZenithLockScreenRGB)? {
        let side = ZenithLockScreenBackdrop.side
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let small = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Aspect fill into the square, as the screen will fill with it.
        let width = CGFloat(cover.width), height = CGFloat(cover.height)
        guard width > 0, height > 0 else { return nil }
        let scale = max(CGFloat(side) / width, CGFloat(side) / height)
        small.interpolationQuality = .medium
        small.draw(cover, in: CGRect(x: (CGFloat(side) - width * scale) / 2, y: (CGFloat(side) - height * scale) / 2,
                                     width: width * scale, height: height * scale))
        guard let copy = small.makeImage() else { return nil }
        let radius = ZenithLockScreenBackdrop.imageRadius(points: points, image: CGSize(width: side, height: side),
                                                          screen: screen)
        let input = CIImage(cgImage: copy)
        // Clamped first, so the edges blur into the cover, not into clear.
        let blurred = input.clampedToExtent()
            .applyingGaussianBlur(sigma: max(0.5, radius))
            .cropped(to: input.extent)
        guard let image = imageContext.createCGImage(blurred, from: input.extent, format: .RGBA8, colorSpace: space) else {
            return nil
        }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let read = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard read, let average = ZenithLockScreenPalette.average(rgba: pixels, count: side * side) else { return nil }
        return (image, average)
    }

    /// The cover drawn into 24 × 24 sRGB pixels, then its most common colour.
    static func dominantColor(of image: NSImage) -> ZenithLockScreenRGB? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drawn ? ZenithLockScreenPalette.dominant(rgba: pixels, count: side * side) : nil
    }
}

extension ZenithLockScreenRGB {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}
