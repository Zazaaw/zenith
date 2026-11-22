// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance
// (ScanAnimationView.swift).

import AVFoundation
import AppKit
import SwiftUI

/// Zenith fork: one of Glance's animations in the padlock island, muted
/// (it plays on the lock screen), looping where Glance loops and otherwise
/// held on its last frame. With the animation style set to none it shows
/// the still; `still` draws a frame instead of playing, for the catalog,
/// whose offscreen renders never capture a video layer.
struct FaceUnlockMediaView: View {
    let media: FaceUnlockIslandMedia
    var plays = true
    var still = false

    var body: some View {
        if still || !plays {
            Image(nsImage: (plays ? FaceUnlockMediaLibrary.frame(media) : nil) ?? FaceUnlockMediaLibrary.poster ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            FaceUnlockPlayerView(media: media)
        }
    }
}

/// The media in the app's resources (build.sh copies them to FaceUnlock/).
enum FaceUnlockMediaLibrary {
    static func url(_ name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: FaceUnlockIslandMedia.folder)
    }

    static let poster: NSImage? = url(FaceUnlockIslandMedia.poster, extension: "png").flatMap(NSImage.init(contentsOf:))

    nonisolated(unsafe) private static var frames: [FaceUnlockIslandMedia: NSImage] = [:]

    /// A still of `media` at its `stillTime`, read once and kept.
    static func frame(_ media: FaceUnlockIslandMedia) -> NSImage? {
        if let frame = frames[media] { return frame }
        guard let url = url(media.resource, extension: "mp4") else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let image = try? generator.copyCGImage(at: CMTime(seconds: media.stillTime, preferredTimescale: 600),
                                                     actualTime: nil) else { return nil }
        let frame = NSImage(cgImage: image, size: CGSize(width: image.width / 2, height: image.height / 2))
        frames[media] = frame
        return frame
    }
}

private struct FaceUnlockPlayerView: NSViewRepresentable {
    let media: FaceUnlockIslandMedia

    func makeNSView(context: Context) -> FaceUnlockPlayerHostView {
        let view = FaceUnlockPlayerHostView()
        view.apply(media)
        return view
    }

    func updateNSView(_ view: FaceUnlockPlayerHostView, context: Context) {
        view.apply(media)
    }

    static func dismantleNSView(_ view: FaceUnlockPlayerHostView, coordinator: ()) {
        view.stop()
    }
}

/// Glance's player: the still until the video's first frame is ready (a
/// fixed delay raced the decode and flashed black), then the video.
final class FaceUnlockPlayerHostView: NSView {
    private let playerLayer = AVPlayerLayer()
    private let posterLayer = CALayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var current: FaceUnlockIslandMedia?
    private var readiness: NSKeyValueObservation?
    private var fallback: DispatchWorkItem?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        posterLayer.contentsGravity = .resizeAspect
        posterLayer.contents = FaceUnlockMediaLibrary.poster
        layer?.addSublayer(posterLayer)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.isHidden = true
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        posterLayer.frame = bounds
        CATransaction.commit()
    }

    func apply(_ media: FaceUnlockIslandMedia) {
        guard media != current else { return }
        current = media
        stop()
        guard let url = FaceUnlockMediaLibrary.url(media.resource, extension: "mp4") else { return }
        let player = AVQueuePlayer()
        // On the lock screen: never a sound.
        player.isMuted = true
        let item = AVPlayerItem(url: url)
        if media.loops {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
            // Holds the last frame rather than rewinding.
            player.actionAtItemEnd = .none
        }
        playerLayer.player = player
        self.player = player
        let reveal = { [weak self] in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.playerLayer.isHidden = false
            self.posterLayer.isHidden = true
            CATransaction.commit()
        }
        readiness = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, change in
            guard change.newValue == true else { return }
            DispatchQueue.main.async {
                self?.fallback?.cancel()
                self?.readiness = nil
                reveal()
            }
        }
        // Should the layer never say it is ready, the still does not stay forever.
        let work = DispatchWorkItem { reveal() }
        fallback = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        player.play()
    }

    func stop() {
        readiness = nil
        fallback?.cancel()
        fallback = nil
        looper?.disableLooping()
        looper = nil
        player?.pause()
        player?.removeAllItems()
        player = nil
        playerLayer.player = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.isHidden = true
        posterLayer.isHidden = false
        CATransaction.commit()
    }
}
