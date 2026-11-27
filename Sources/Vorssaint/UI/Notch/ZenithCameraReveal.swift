// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import QuartzCore
import SwiftUI

// Zenith fork: how the island's live mirror arrives (ZenithCameraAutoStart).
// The image fades in from a light blur, on `ZenithMotion.reveal`'s curve, on
// its own preview layer, which the window server renders: SwiftUI's blur does
// not reach into a hosted layer.
// While the session starts the page stays dark, and only a session slower
// than `loadingDelay` shows a spinner, so a quick start never flashes one.

enum ZenithCameraReveal {
    private static let blurName = "zenithCameraReveal"

    /// Fades `layer` in from `ZenithCameraAutoStart.blur`, or only fades it
    /// with Reduce Motion. The blur filter leaves once the image is sharp, so
    /// it costs no render pass afterwards.
    static func run(on layer: CALayer, reduceMotion: Bool) {
        let duration = reduceMotion ? ZenithMotion.fast : ZenithCameraAutoStart.revealDuration
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        layer.add(fade, forKey: "zenith.camera.fade")
        guard !reduceMotion, let filter = makeBlur() else { return }
        layer.filters = [filter]
        let blur = CABasicAnimation(keyPath: "filters.\(blurName).inputRadius")
        blur.fromValue = ZenithCameraAutoStart.blur
        blur.toValue = 0
        blur.duration = duration
        blur.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        layer.add(blur, forKey: "zenith.camera.blur")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak layer] in
            layer?.filters = nil
        }
    }

    /// Core Animation's own blur, as the island's arrival uses it; nil where
    /// the system offers none, and the image then only fades in.
    private static func makeBlur() -> NSObject? {
        let make = NSSelectorFromString("filterWithType:")
        guard let type = NSClassFromString("CAFilter") as? NSObject.Type, type.responds(to: make),
              let filter = type.perform(make, with: "gaussianBlur")?.takeUnretainedValue() as? NSObject else { return nil }
        filter.setValue(blurName, forKey: "name")
        filter.setValue(0, forKey: "inputRadius")
        return filter
    }
}

/// The dark page while the mirror starts: nothing at first, then a quiet
/// spinner if the camera takes longer than `ZenithCameraAutoStart.loadingDelay`.
struct ZenithCameraLoading: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSpinner = false

    var body: some View {
        ProgressView()
            .controlSize(.small)
            .tint(.white)
            .opacity(showsSpinner ? 0.7 : 0)
            .accessibilityLabel(ZenithStrings.camera(l10n.language).starting)
            .task {
                try? await Task.sleep(for: .seconds(ZenithCameraAutoStart.loadingDelay))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : IslandMotion.easeOut(ZenithMotion.fast)) { showsSpinner = true }
            }
    }
}
