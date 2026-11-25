// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreMotion
import SwiftUI
import UIKit

/// How the phone leans away from the way it is held, for parallax: `x` and
/// `y` in −1…1, 0 at rest. The rest pose follows the hand slowly, so holding
/// the phone at any angle reads as level and only a lean moves things.
/// Motion runs only while a view reads it (`.readsTilt()`), at 30 Hz, and
/// never with Reduce Motion. Used on the main thread.
@MainActor @Observable
final class Tilt {
    static let shared = Tilt()

    private(set) var x: Double = 0
    private(set) var y: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var readers = 0
    @ObservationIgnored private var rest: (x: Double, y: Double)?

    /// How far a lean goes before it reads as the whole way (in g).
    private static let reach = 0.35
    /// How much of the gap to the hand's pose the rest closes per update.
    private static let follow = 0.02

    func begin() {
        readers += 1
        if readers == 1 { startUpdates() }
    }

    func end() {
        readers = max(0, readers - 1)
        guard readers == 0 else { return }
        manager.stopDeviceMotionUpdates()
        rest = nil
        x = 0
        y = 0
    }

    private func startUpdates() {
        guard manager.isDeviceMotionAvailable, !UIAccessibility.isReduceMotionEnabled else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            let gx = gravity.x, gy = gravity.y
            MainActor.assumeIsolated { self?.update(gx, gy) }
        }
    }

    private func update(_ gx: Double, _ gy: Double) {
        var base = rest ?? (gx, gy)
        base.x += (gx - base.x) * Self.follow
        base.y += (gy - base.y) * Self.follow
        rest = base
        x = Self.clamp((gx - base.x) / Self.reach)
        y = Self.clamp((gy - base.y) / Self.reach)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(-1, value)) }
}

private struct TiltReader: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @State private var reading = false

    func body(content: Content) -> some View {
        content
            .onAppear { set(phase == .active) }
            .onDisappear { set(false) }
            .onChange(of: phase) { _, next in set(next == .active) }
    }

    private func set(_ on: Bool) {
        guard on != reading else { return }
        reading = on
        if on { Tilt.shared.begin() } else { Tilt.shared.end() }
    }
}

extension View {
    /// Keeps `Tilt.shared` running while this view shows and the app is active.
    func readsTilt() -> some View { modifier(TiltReader()) }
}
