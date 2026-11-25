// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The companion from Zenith's island, on the Claude tab: the Satu Visual
/// star with two eyes on its horizontal arm, as `NotchMascotView` draws its
/// `.satuVisual` style. Its face follows the session: busy eyes and a bob
/// while Claude works, a look and a blink while it waits for you, wide eyes
/// and a hop while it asks, a calm face that grows sleepy when nothing runs.
/// The eyes lean with the phone; a tap gets a reaction.
///
/// Every motion is a state change SwiftUI animates; a small loop sets the
/// next one only while the star is on screen and the app is active, and
/// never with Reduce Motion, which keeps one still face per mood.
struct ClaudeMascot: View {
    enum Mood: Equatable {
        case working, waiting, asking, idle

        init(_ state: PocketClaude.Session.State?) {
            switch state {
            case .working: self = .working
            case .waiting, .done: self = .waiting
            case .asking: self = .asking
            case nil: self = .idle
            }
        }
    }

    let mood: Mood
    var size: CGFloat = 116

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme

    @State private var left = MascotEye.open
    @State private var right = MascotEye.open
    /// Where the eyes look, in shares of the star's size; y grows downward.
    @State private var gaze = CGPoint.zero
    /// The head's lean, in radians.
    @State private var lean = 0.0
    /// The eyes' height while they blink, 1 open.
    @State private var lids: CGFloat = 1
    @State private var bobUp = false
    @State private var breathIn = false
    @State private var hops = 0
    @State private var pops = 0
    @State private var asleep = false
    /// A reaction's face holds until then; the loop leaves the eyes alone.
    @State private var flashUntil = Date.distantPast
    @State private var taps: [Date] = []
    @State private var onScreen = true

    /// Moves only while someone can see them.
    private var lively: Bool { !reduceMotion && onScreen && scenePhase == .active }

    var body: some View {
        let tint = accent
        ZStack {
            halo(tint)
            ground
            figure
                .keyframeAnimator(initialValue: Bounce(), trigger: hops) { content, bounce in
                    content
                        .scaleEffect(x: 1 + bounce.squash * 0.8, y: 1 - bounce.squash, anchor: .bottom)
                        .offset(y: bounce.lift * size)
                } keyframes: { _ in
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(-0.16, duration: 0.2)
                        CubicKeyframe(0, duration: 0.17)
                        CubicKeyframe(-0.05, duration: 0.11)
                        CubicKeyframe(0, duration: 0.14)
                    }
                    KeyframeTrack(\.squash) {
                        CubicKeyframe(-0.12, duration: 0.075)
                        CubicKeyframe(0, duration: 0.11)
                        CubicKeyframe(0.14, duration: 0.2)
                        CubicKeyframe(0, duration: 0.06)
                        CubicKeyframe(0.06, duration: 0.075)
                        CubicKeyframe(0, duration: 0.1)
                    }
                }
                .keyframeAnimator(initialValue: Bounce(), trigger: pops) { content, bounce in
                    content.scaleEffect(x: 1 + bounce.squash * 0.8, y: 1 - bounce.squash, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.squash) {
                        CubicKeyframe(-0.14, duration: 0.12)
                        CubicKeyframe(0.06, duration: 0.12)
                        CubicKeyframe(0, duration: 0.1)
                    }
                }
                .offset(y: bobUp ? -size * 0.035 : 0)
                .scaleEffect(breathIn ? 1.018 : 1, anchor: .bottom)
        }
        .frame(width: size * 1.9, height: size * 1.45)
        .contentShape(Circle().scale(0.7))
        .onTapGesture(perform: tapped)
        .onScrollVisibilityChange(threshold: 0.05) { onScreen = $0 }
        .onAppear { settle(animated: false) }
        .onChange(of: mood) { old, new in changed(from: old, to: new) }
        .task(id: Loop(mood: mood, lively: lively)) {
            guard lively else { return }
            await live()
        }
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private var figure: some View {
        let dark = scheme == .dark
        return ZStack {
            StarShape()
                .fill(LinearGradient(colors: dark ? [Self.pearlLight, Self.pearlShade] : [Color(white: 0.22), Color(white: 0.04)],
                                     startPoint: .top, endPoint: .bottom), style: FillStyle(eoFill: true))
            MascotFace(left: left, right: right, gaze: gaze, lids: lids,
                       ink: dark ? Self.ink : Color(white: 0.97))
                // The eyes stay on the star, wherever they look.
                .mask(StarShape().fill(style: FillStyle(eoFill: true)))
        }
        .frame(width: size, height: size)
        .rotationEffect(.radians(lean))
        .animation(Motion.spring, value: lean)
        .shadow(color: .black.opacity(dark ? 0 : 0.16), radius: size * 0.1, y: size * 0.07)
        .shadow(color: accent.opacity(dark ? 0.35 : 0), radius: size * 0.16)
    }

    private func halo(_ tint: Color) -> some View {
        Circle()
            .fill(RadialGradient(colors: [tint.opacity(scheme == .dark ? 0.34 : 0.22), tint.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size * 0.92))
            .frame(width: size * 1.85, height: size * 1.85)
            .scaleEffect(mood == .asking ? 1.08 : asleep ? 0.86 : 1)
            .opacity(asleep ? 0.55 : 1)
            .animation(Motion.reveal, value: mood)
            .animation(Motion.reveal, value: asleep)
            .animation(Motion.reveal, value: tint)
    }

    /// A soft shadow on the ground that shrinks as it lifts.
    private var ground: some View {
        Ellipse()
            .fill(K.fg.opacity(scheme == .dark ? 0.16 : 0.09))
            .frame(width: size * 0.62, height: size * 0.075)
            .blur(radius: size * 0.03)
            .scaleEffect(bobUp ? 0.88 : 1)
            .offset(y: size * 0.6)
    }

    private var accent: Color {
        switch mood {
        case .working: return K.purple
        case .asking: return K.amber
        case .waiting: return K.amber.opacity(0.7)
        case .idle: return asleep ? K.faint : K.emerald
        }
    }

    // The companion's pearl palette and ink, from NotchMascotColor.
    private static let pearlLight = Color(red: 0.99, green: 0.98, blue: 0.96)
    private static let pearlShade = Color(red: 0.84, green: 0.85, blue: 0.90)
    private static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)

    // MARK: Moods

    private struct Loop: Equatable {
        let mood: Mood
        let lively: Bool
    }

    struct Bounce {
        var lift: CGFloat = 0
        var squash: CGFloat = 0
    }

    /// The face each mood keeps when nothing else happens.
    private func base(_ mood: Mood) -> (MascotEye, MascotEye, CGPoint, Double) {
        switch mood {
        case .working: return (.open, .open, CGPoint(x: 0.03, y: 0.012), 0)
        case .waiting: return (.open, .open, .zero, 0)
        case .asking: return (.wide, .wide, CGPoint(x: 0, y: -0.01), 0)
        case .idle where asleep: return (.sleepy, .sleepy, CGPoint(x: 0, y: 0.012), 0.05)
        case .idle: return (.open, .open, .zero, 0)
        }
    }

    private func settle(animated: Bool = true) {
        let (l, r, g, t) = base(mood)
        var transaction = Transaction(animation: animated ? Motion.respecting(reduceMotion, Self.morph) : nil)
        transaction.disablesAnimations = !animated
        withTransaction(transaction) {
            left = l; right = r; gaze = g; lean = t
        }
    }

    private func changed(from old: Mood, to new: Mood) {
        asleep = false
        flashUntil = .distantPast
        settle()
        guard !reduceMotion else { return }
        switch new {
        case .asking: hops += 1
        case .working: pops += 1
        case .waiting where old == .working:
            // A turn just ended: a glad face, then it looks at you.
            flash(.happy, .happy, for: 1.1)
            hops += 1
        default: break
        }
    }

    /// Shows a face for a moment, then goes back to the mood's own.
    private func flash(_ l: MascotEye, _ r: MascotEye, gaze next: CGPoint = CGPoint(x: 0, y: -0.01), for seconds: Double) {
        let until = Date().addingTimeInterval(seconds)
        flashUntil = until
        withAnimation(Motion.respecting(reduceMotion, Self.morph)) {
            left = l; right = r; gaze = next
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard flashUntil == until else { return }
            flashUntil = .distantPast
            settle()
        }
    }

    private func tapped() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 1.6 } + [now]
        if asleep {
            asleep = false
            Haptics.soft()
            if !reduceMotion { pops += 1 }
            flash(.wide, .wide, for: 0.7)
            return
        }
        if taps.count >= 3 {
            Haptics.success()
            taps = []
            flash(.heart, .heart, for: 1.4)
        } else {
            Haptics.soft()
            flash(.happy, .happy, for: 0.9)
        }
        if !reduceMotion { hops += 1 }
    }

    /// The eyes' morph from one shape to another, the Mac's curve.
    private static let morph = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.24)

    // MARK: Living

    /// Blinks, glances and bobs, each on its own beat, until the mood
    /// changes or the star leaves the screen.
    private func live() async {
        let clock = ContinuousClock()
        var blinkAt = clock.now + .seconds(Double.random(in: 1.2...3))
        var lookAt = clock.now + .seconds(beat(mood))
        var swayAt = clock.now + .seconds(0.3)
        var blinks = 0
        defer {
            withAnimation(.easeOut(duration: 0.35)) {
                bobUp = false
                breathIn = false
            }
        }
        while !Task.isCancelled {
            let wake = min(blinkAt, lookAt, swayAt)
            try? await Task.sleep(until: wake, clock: .continuous)
            if Task.isCancelled { return }
            let now = clock.now
            let free = Date() >= flashUntil
            if now >= swayAt {
                if mood == .working {
                    withAnimation(.easeInOut(duration: 0.55)) { bobUp.toggle() }
                    swayAt = now + .seconds(0.55)
                } else {
                    let breath = asleep ? 2.8 : 2.2
                    withAnimation(.easeInOut(duration: breath)) { breathIn.toggle() }
                    swayAt = now + .seconds(breath)
                }
            }
            if now >= blinkAt {
                if free, left.blinks, right.blinks { await blink(twice: Double.random(in: 0...1) < 0.18) }
                blinks += 1
                if mood == .idle, !asleep, blinks >= 7, free {
                    // A long quiet makes its eyes heavy; it stops blinking then.
                    asleep = true
                    settle()
                }
                blinkAt = clock.now + .seconds(mood == .idle ? Double.random(in: 4...7.5) : Double.random(in: 2.6...6.4))
            }
            if now >= lookAt {
                if free, !asleep { look() }
                lookAt = clock.now + .seconds(beat(mood))
            }
        }
    }

    private func beat(_ mood: Mood) -> Double {
        switch mood {
        case .working: return Double.random(in: 0.6...1.5)
        case .asking: return Double.random(in: 2.6...3.8)
        case .waiting, .idle: return Double.random(in: 3.5...6.5)
        }
    }

    private func blink(twice: Bool) async {
        for round in 0..<(twice ? 2 : 1) {
            if round > 0 { try? await Task.sleep(for: .seconds(0.08)) }
            withAnimation(.easeIn(duration: 0.07)) { lids = 0.1 }
            try? await Task.sleep(for: .seconds(0.08))
            withAnimation(.easeOut(duration: 0.1)) { lids = 1 }
        }
    }

    /// Where the eyes go next: busy darts while working, a glance away and
    /// back at rest, a hop now and then while it asks.
    private func look() {
        switch mood {
        case .working:
            if Double.random(in: 0...1) < 0.2 {
                // Thinking: one eye narrows, the head tips, eyes up and over.
                withAnimation(Self.morph) { left = .squint; right = .open }
                withAnimation(Motion.spring) { gaze = CGPoint(x: 0.05, y: -0.016); lean = -0.08 }
            } else {
                let spots = [CGPoint(x: -0.055, y: 0.012), CGPoint(x: 0.055, y: 0.012), CGPoint(x: 0.02, y: 0.016),
                             CGPoint(x: -0.03, y: -0.012), CGPoint(x: 0.045, y: -0.01), CGPoint(x: -0.06, y: 0)]
                let next = spots.filter { $0 != gaze }.randomElement() ?? .zero
                withAnimation(Self.morph) { left = .open; right = .open }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { gaze = next; lean = 0 }
            }
        case .asking:
            hops += 1
            withAnimation(Motion.spring) { gaze = Bool.random() ? CGPoint(x: 0, y: -0.01) : CGPoint(x: -0.04, y: -0.014) }
        case .waiting, .idle:
            guard Double.random(in: 0...1) < 0.45 else { return }
            let away = CGPoint(x: (Bool.random() ? 1 : -1) * 0.055, y: 0.004)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { gaze = away }
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                guard Date() >= flashUntil, !asleep else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { gaze = base(mood).2 }
            }
        }
    }
}

/// The two eyes, which lean with the phone. Kept apart so the tilt, read
/// thirty times a second, redraws only them.
private struct MascotFace: View {
    let left: MascotEye
    let right: MascotEye
    let gaze: CGPoint
    let lids: CGFloat
    let ink: Color

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                eye(left, right: false)
                eye(right, right: true)
            }
            .offset(x: gaze.x * side, y: gaze.y * side)
            .animation(Motion.spring, value: gaze)
        }
    }

    private func eye(_ kind: MascotEye, right: Bool) -> some View {
        let center = right ? MascotEye.rightCenter : MascotEye.leftCenter
        return MascotEyeShape(outline: kind.outline(right: right))
            .fill(ink)
            .scaleEffect(x: 1, y: lids, anchor: UnitPoint(x: center.x, y: center.y))
            .animation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.24), value: kind)
    }
}

// MARK: - Eyes

/// The companion's eye shapes (`NotchMascotEye`), every one drawn as the
/// same 24 points, so any eye can turn into any other one point at a time.
enum MascotEye: CaseIterable, Hashable {
    case open, closed, happy, heart, sleepy, wide, squint

    var blinks: Bool { self == .open || self == .wide || self == .squint }

    /// The eyes' centres and an open eye's size, in shares of the star: the
    /// Mac's face layout (shares of a box the star fills 84% of), rescaled.
    static let leftCenter = CGPoint(x: 0.295, y: 0.501)
    static let rightCenter = CGPoint(x: 0.705, y: 0.501)
    static let size = CGSize(width: 0.042 / 0.84, height: 0.078 / 0.84)
    static let count = 24

    /// Each eye's points on either side, worked out once.
    private static let outlines: [MascotEye: (left: AnimatablePoints, right: AnimatablePoints)] =
        Dictionary(uniqueKeysWithValues: allCases.map { eye in
            (eye, (left: eye.make(right: false, center: leftCenter), right: eye.make(right: true, center: rightCenter)))
        })

    func outline(right: Bool) -> AnimatablePoints {
        guard let both = Self.outlines[self] else { return make(right: right, center: right ? Self.rightCenter : Self.leftCenter) }
        return right ? both.right : both.left
    }

    private func make(right: Bool, center: CGPoint) -> AnimatablePoints {
        let w = Self.size.width, h = Self.size.height
        var points: [CGPoint]
        switch self {
        case .open: points = EyeOutlines.stadium(width: w, height: h, center: .zero)
        case .closed: points = EyeOutlines.stadium(width: w * 1.5, height: w * 0.45, center: CGPoint(x: 0, y: h * 0.12))
        case .squint: points = EyeOutlines.stadium(width: w, height: h * 0.55, center: CGPoint(x: 0, y: h * 0.08))
        case .wide: points = EyeOutlines.ellipse(radii: CGSize(width: w * 0.8, height: w * 0.8), center: CGPoint(x: 0, y: -h * 0.02))
        case .happy: points = EyeOutlines.arch(span: w * 2.1, rise: h * 0.42, thickness: w * 0.55, top: -h * 0.18)
        case .heart: points = EyeOutlines.heart(width: w * 2.0, height: w * 1.8, center: CGPoint(x: 0, y: -h * 0.02))
        case .sleepy: points = EyeOutlines.lid(width: w * 1.25, top: h * 0.02, depth: h * 0.38)
        }
        if right { points = points.map { CGPoint(x: -$0.x, y: $0.y) } }
        let placed = EyeOutlines.resample(points, count: Self.count).map { CGPoint(x: $0.x + center.x, y: $0.y + center.y) }
        return AnimatablePoints(placed)
    }
}

/// An eye: a smooth closed curve through its points, given in shares of the
/// frame, so one eye morphs into another as SwiftUI animates the points.
struct MascotEyeShape: Shape {
    var outline: AnimatablePoints

    var animatableData: AnimatablePoints {
        get { outline }
        set { outline = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let points = outline.points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        var path = Path()
        let count = points.count
        guard count >= 3 else { return path }
        path.move(to: points[0])
        for index in 0..<count {
            let previous = points[(index - 1 + count) % count]
            let current = points[index]
            let next = points[(index + 1) % count]
            let after = points[(index + 2) % count]
            path.addCurve(to: next,
                          control1: CGPoint(x: current.x + (next.x - previous.x) / 6, y: current.y + (next.y - previous.y) / 6),
                          control2: CGPoint(x: next.x - (after.x - current.x) / 6, y: next.y - (after.y - current.y) / 6))
        }
        path.closeSubpath()
        return path
    }
}

/// Points SwiftUI can animate between, x and y in turn. The empty value is
/// zero, so sums and differences treat a missing point as the origin.
struct AnimatablePoints: VectorArithmetic {
    var values: [Double]

    init(_ points: [CGPoint]) { values = points.flatMap { [Double($0.x), Double($0.y)] } }
    private init(values: [Double]) { self.values = values }

    var points: [CGPoint] {
        stride(from: 0, to: values.count - 1, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) }
    }

    static var zero: AnimatablePoints { AnimatablePoints(values: []) }

    static func + (lhs: AnimatablePoints, rhs: AnimatablePoints) -> AnimatablePoints { combine(lhs, rhs, +) }
    static func - (lhs: AnimatablePoints, rhs: AnimatablePoints) -> AnimatablePoints { combine(lhs, rhs, -) }

    mutating func scale(by rhs: Double) {
        for index in values.indices { values[index] *= rhs }
    }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    private static func combine(_ lhs: AnimatablePoints, _ rhs: AnimatablePoints,
                                _ operation: (Double, Double) -> Double) -> AnimatablePoints {
        let count = max(lhs.values.count, rhs.values.count)
        var values = [Double](repeating: 0, count: count)
        for index in 0..<count {
            let a = index < lhs.values.count ? lhs.values[index] : 0
            let b = index < rhs.values.count ? rhs.values[index] : 0
            values[index] = operation(a, b)
        }
        return AnimatablePoints(values: values)
    }
}

/// The eye outlines of `NotchMascotGeometry`, ported point for point.
private enum EyeOutlines {
    private static let dense = 96

    /// A capsule standing on its round ends, or lying on them when wider.
    static func stadium(width: CGFloat, height: CGFloat, center: CGPoint) -> [CGPoint] {
        let radius = min(width, height) / 2
        let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        let corners: [(CGPoint, CGFloat)] = [
            (CGPoint(x: rect.maxX - radius, y: rect.minY + radius), -.pi / 2),
            (CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), 0),
            (CGPoint(x: rect.minX + radius, y: rect.maxY - radius), .pi / 2),
            (CGPoint(x: rect.minX + radius, y: rect.minY + radius), .pi),
        ]
        var points: [CGPoint] = []
        let steps = dense / 4
        for (corner, start) in corners {
            for step in 0...steps {
                let angle = start + CGFloat(step) / CGFloat(steps) * .pi / 2
                points.append(CGPoint(x: corner.x + radius * cos(angle), y: corner.y + radius * sin(angle)))
            }
        }
        return points
    }

    static func ellipse(radii: CGSize, center: CGPoint) -> [CGPoint] {
        (0..<dense).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) / CGFloat(dense) * 2 * .pi
            return CGPoint(x: center.x + radii.width * cos(angle), y: center.y + radii.height * sin(angle))
        }
    }

    /// Eyes shut with a smile: a band bent upward, round at both ends.
    static func arch(span: CGFloat, rise: CGFloat, thickness: CGFloat, top: CGFloat) -> [CGPoint] {
        let half = max(0.0001, span / 2 - thickness / 2)
        let lift = max(0.0001, rise)
        let radius = (half * half + lift * lift) / (2 * lift)
        let center = CGPoint(x: 0, y: top + thickness / 2 + radius)
        let reach = asin(min(1, half / radius))
        func onArc(_ angle: CGFloat, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
        }
        let steps = dense / 3
        var points: [CGPoint] = []
        for step in 0...steps {
            points.append(onArc(-reach + CGFloat(step) / CGFloat(steps) * reach * 2, radius + thickness / 2))
        }
        let rightEnd = onArc(reach, radius)
        for step in 1..<12 {
            let angle = reach + CGFloat(step) / 12 * .pi
            points.append(CGPoint(x: rightEnd.x + thickness / 2 * sin(angle), y: rightEnd.y - thickness / 2 * cos(angle)))
        }
        for step in 0...steps {
            points.append(onArc(reach - CGFloat(step) / CGFloat(steps) * reach * 2, radius - thickness / 2))
        }
        let leftEnd = onArc(-reach, radius)
        for step in 1..<12 {
            let angle = -reach + .pi + CGFloat(step) / 12 * .pi
            points.append(CGPoint(x: leftEnd.x + thickness / 2 * sin(angle), y: leftEnd.y - thickness / 2 * cos(angle)))
        }
        return points
    }

    static func heart(width: CGFloat, height: CGFloat, center: CGPoint) -> [CGPoint] {
        let raw: [CGPoint] = (0..<dense).map { index in
            let t = CGFloat(index) / CGFloat(dense) * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            return CGPoint(x: x, y: y)
        }
        let minY = raw.map(\.y).min() ?? 0, maxY = raw.map(\.y).max() ?? 1
        let middle = (minY + maxY) / 2
        return raw.map { CGPoint(x: center.x + $0.x / 32 * width, y: center.y - ($0.y - middle) / (maxY - minY) * height) }
    }

    /// A drowsy eye: the lid's flat edge on top, the eye's round bottom below.
    static func lid(width: CGFloat, top: CGFloat, depth: CGFloat) -> [CGPoint] {
        let half = width / 2
        var points: [CGPoint] = []
        let flat = dense / 4
        for step in 0...flat {
            points.append(CGPoint(x: -half + CGFloat(step) / CGFloat(flat) * width, y: top))
        }
        let round = dense - flat
        for step in 1..<round {
            let angle = CGFloat(step) / CGFloat(round) * .pi
            points.append(CGPoint(x: half * cos(angle), y: top + depth * sin(angle)))
        }
        return points
    }

    /// `count` points evenly spaced along the outline, from where its top
    /// crosses the middle line, clockwise on screen: every eye has its points
    /// in the same places, which is what lets one become another.
    static func resample(_ outline: [CGPoint], count: Int) -> [CGPoint] {
        guard outline.count >= 3, count >= 3 else { return outline }
        var points = outline
        var area: CGFloat = 0
        for index in points.indices {
            let a = points[index], b = points[(index + 1) % points.count]
            area += a.x * b.y - b.x * a.y
        }
        if area < 0 { points.reverse() }
        var start: (index: Int, point: CGPoint)?
        for index in points.indices {
            let a = points[index], b = points[(index + 1) % points.count]
            guard (a.x <= 0 && b.x > 0) || (a.x >= 0 && b.x < 0) || a.x == 0 else { continue }
            let share = b.x == a.x ? 0 : -a.x / (b.x - a.x)
            let crossing = CGPoint(x: 0, y: a.y + (b.y - a.y) * share)
            if let found = start, crossing.y >= found.point.y { continue }
            start = (index, crossing)
        }
        guard let start else { return Array(points.prefix(count)) }
        var walk = [start.point]
        for offset in 1...points.count {
            walk.append(points[(start.index + offset) % points.count])
        }
        walk.append(start.point)
        var lengths: [CGFloat] = [0]
        for index in 1..<walk.count {
            lengths.append(lengths[index - 1] + hypot(walk[index].x - walk[index - 1].x, walk[index].y - walk[index - 1].y))
        }
        let total = lengths.last ?? 0
        guard total > 0 else { return Array(repeating: start.point, count: count) }
        var result: [CGPoint] = []
        var segment = 1
        for step in 0..<count {
            let target = total * CGFloat(step) / CGFloat(count)
            while segment < lengths.count - 1, lengths[segment] < target { segment += 1 }
            let span = lengths[segment] - lengths[segment - 1]
            let share = span > 0 ? (target - lengths[segment - 1]) / span : 0
            let a = walk[segment - 1], b = walk[segment]
            result.append(CGPoint(x: a.x + (b.x - a.x) * share, y: a.y + (b.y - a.y) * share))
        }
        return result
    }
}
