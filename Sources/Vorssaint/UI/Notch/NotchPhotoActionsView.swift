// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the photo actions' surface on the island's Files page, in the
// bento language: the picture on the left, a hairline, then the options as
// segmented wells under mono labels, the one solid action, progress, and the
// result with its sizes in mono.
//
// Motion is SwiftUI's own, so it runs at the display's refresh rate: only
// transforms, opacity, trims and masks animate, every animated layer has a
// fixed size, and the page itself never changes height. Reduce Motion turns
// each movement into a cross-fade.

/// The interactive spring: response 0.36, damping 0.86.
private let photoSpring = Animation.spring(response: 0.36, dampingFraction: 0.86)

struct NotchPhotoActionsView: View {
    let session: NotchPhotoSession
    /// The page's content height; the picture takes a square of it.
    let height: CGFloat
    @ObservedObject private var photos = NotchPhotoActionsService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    private var text: ZenithPhotoActionsStrings { ZenithStrings.photoActions(l10n.language) }
    private var side: CGFloat { max(72, min(height - 8, 164)) }

    private var phaseKey: String {
        switch session.phase {
        case .ready: return "ready"
        case .working: return "working"
        case .done: return "done"
        case .failed: return "failed"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            NotchPhotoPreview(session: session, side: side, arrived: arrived, text: text)
                .padding(.trailing, 14)
            ZenithBentoDivider(.vertical)
            ZStack(alignment: .topLeading) {
                pane
                    .id(phaseKey)
                    .transition(reduceMotion ? .opacity
                                : .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity))
            }
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : ZenithMotion.reveal(), value: phaseKey)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: arrive)
        .onChange(of: session.id) {
            arrived = false
            DispatchQueue.main.async(execute: arrive)
        }
    }

    /// The picture settles in and the layers of the pane follow it, 40 ms apart.
    private func arrive() {
        guard !arrived else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : photoSpring) { arrived = true }
    }

    @ViewBuilder private var pane: some View {
        switch session.phase {
        case .ready:
            if session.action == .transform {
                NotchPhotoTransformPane(session: session, arrived: arrived, text: text)
            } else {
                NotchPhotoCutoutPane(session: session, arrived: arrived, text: text)
            }
        case let .working(progress, completed):
            NotchPhotoWorkingPane(session: session, progress: progress, completed: completed, text: text)
        case let .done(result):
            NotchPhotoDonePane(session: session, result: result, text: text)
        case let .failed(failure):
            NotchPhotoFailedPane(session: session, failure: failure, text: text)
        }
    }
}

// MARK: - Panes

/// Transform's options: the step, its choice, the strip chip and Apply.
private struct NotchPhotoTransformPane: View {
    let session: NotchPhotoSession
    let arrived: Bool
    let text: ZenithPhotoActionsStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotchPhotoHeader(label: text.transform, symbol: "photo.stack", meta: inputMeta(session), text: text)
                .modifier(NotchPhotoLayer(index: 0, shown: arrived))
            ZenithSegmented(selection: $photos.kind, options: [
                (.convert, text.convert), (.resize, text.resize), (.compress, text.compress), (.strip, text.strip),
            ], fontSize: 11)
            .modifier(NotchPhotoLayer(index: 1, shown: arrived))
            options
                .frame(height: 45, alignment: .topLeading)
                .modifier(NotchPhotoLayer(index: 2, shown: arrived))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if photos.kind != .strip { stripChip.transition(.opacity) }
                Spacer(minLength: 6)
                Button(text.apply) { photos.apply() }
                    .buttonStyle(NotchPhotoPrimaryButtonStyle())
            }
            .modifier(NotchPhotoLayer(index: 3, shown: arrived))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The chosen step's choice, cross-faded when the step changes.
    private var options: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 5) {
                Text(optionLabel).modifier(ZenithBentoLabelStyle())
                switch photos.kind {
                case .convert:
                    ZenithSegmented(selection: $photos.format,
                                    options: photos.offeredFormats.map { ($0, $0.title) }, mono: true)
                case .resize:
                    ZenithSegmented(selection: $photos.longEdge, options: NotchPhotoLongEdge.allCases.map {
                        ($0, $0.pixels.map(String.init) ?? text.original)
                    }, mono: true)
                case .compress:
                    ZenithSegmented(selection: $photos.quality,
                                    options: NotchPhotoQuality.allCases.map { ($0, "\($0.rawValue)") }, mono: true)
                case .strip:
                    Text(text.stripDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .id(photos.kind)
            .transition(.opacity)
        }
    }

    private var optionLabel: String {
        switch photos.kind {
        case .convert: return text.format
        case .resize: return text.longEdge
        case .compress: return text.quality
        case .strip: return "EXIF · GPS"
        }
    }

    /// Strip EXIF and GPS along with the chosen step.
    private var stripChip: some View {
        Button {
            withAnimation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast))) { photos.alsoStrips.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: photos.alsoStrips ? "checkmark" : "location.slash")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 10)
                Text(text.alsoStrip)
                    .lineLimit(1)
            }
            .font(ZenithType.mono(10.5, weight: .medium))
            .foregroundStyle(photos.alsoStrips ? ZenithIsland.primary : ZenithIsland.secondary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .modifier(ZenithIslandTabBlock(selected: photos.alsoStrips))
            .contentShape(Capsule())
        }
        .buttonStyle(NotchPhotoPressStyle())
        .accessibilityAddTraits(photos.alsoStrips ? .isSelected : [])
    }
}

/// Remove Background starts as soon as the picture lands; this pane only
/// returns after Start over.
private struct NotchPhotoCutoutPane: View {
    let session: NotchPhotoSession
    let arrived: Bool
    let text: ZenithPhotoActionsStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NotchPhotoHeader(label: text.removeBackground, symbol: "person.and.background.dotted",
                             meta: inputMeta(session), text: text)
                .modifier(NotchPhotoLayer(index: 0, shown: arrived))
            Text(text.cutoutDetail)
                .font(.system(size: 11.5))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(NotchPhotoLayer(index: 1, shown: arrived))
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(text.apply) { photos.apply() }
                    .buttonStyle(NotchPhotoPrimaryButtonStyle())
            }
            .modifier(NotchPhotoLayer(index: 2, shown: arrived))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The work in progress: a ring and a percentage that both glide between the
/// steps the work reports.
private struct NotchPhotoWorkingPane: View {
    let session: NotchPhotoSession
    let progress: Double
    let completed: Int
    let text: ZenithPhotoActionsStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchPhotoHeader(label: text.processing, symbol: nil,
                             meta: session.inputs.count > 1 ? "\(min(completed + 1, session.inputs.count))/\(session.inputs.count)" : nil,
                             text: text, closes: false)
            HStack(spacing: 10) {
                NotchPhotoProgressRing(progress: progress)
                    .frame(width: 24, height: 24)
                NotchPhotoCountUp(value: progress * 100, size: 24) { "\(Int($0.rounded()))%" }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: progress)
            ZenithStatusLine(color: ZenithStatus.progress, text: session.action == .transform
                             ? text.transform : text.removeBackground, live: true, mono: false)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(text.cancel) { photos.cancel() }
                    .buttonStyle(NotchPhotoOutlineButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }
}

/// The result: a drawn checkmark, the sizes before and after (the new one
/// counting up), and what to do with the files.
private struct NotchPhotoDonePane: View {
    let session: NotchPhotoSession
    let result: NotchPhotoResult
    let text: ZenithPhotoActionsStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownBytes: Double = 0
    @State private var copiedSerial = 0

    private var smaller: Bool { result.outputBytes < result.inputBytes }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                NotchPhotoCheckmark()
                    .frame(width: 13, height: 13)
                Text(text.done).modifier(ZenithBentoLabelStyle())
                Spacer(minLength: 6)
                ZenithBentoMeta(text: result.folder.map { "→ " + $0.lastPathComponent })
                NotchPhotoGlyphButton(symbol: "xmark", title: text.close) { photos.close() }
            }
            .frame(height: 14)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(NotchPhotoActionsSupport.formatBytes(result.inputBytes))
                    .font(ZenithType.mono(12, weight: .medium))
                    .foregroundStyle(ZenithIsland.tertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ZenithIsland.label)
                NotchPhotoCountUp(value: shownBytes, size: 22) { NotchPhotoActionsSupport.formatBytes(Int64($0.rounded())) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(NotchPhotoActionsSupport.formatBytes(result.inputBytes)) → \(NotchPhotoActionsSupport.formatBytes(result.outputBytes))")
            HStack(spacing: 10) {
                let change = NotchPhotoActionsSupport.sizeChange(from: result.inputBytes, to: result.outputBytes)
                if !change.isEmpty {
                    ZenithStatusLine(color: smaller ? ZenithStatus.success : ZenithIsland.secondary, text: change)
                }
                if result.outputs.count > 1 {
                    ZenithBentoMeta(text: "×\(result.outputs.count)", size: 11)
                }
                if result.skipped > 0 {
                    ZenithStatusLine(color: ZenithStatus.warning, text: "\(text.skipped) \(result.skipped)")
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button(text.revealInFinder) { photos.revealResults() }
                    .buttonStyle(NotchPhotoOutlineButtonStyle())
                Button {
                    photos.copyResults()
                    let serial = photos.copySerial
                    // "Copied" for a moment, then the button reads Copy again.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeOut(duration: ZenithMotion.fast)) { copiedSerial = serial }
                    }
                } label: {
                    Text(copiedSerial == photos.copySerial ? text.copy : text.copied)
                        .contentTransition(.opacity)
                }
                .buttonStyle(NotchPhotoOutlineButtonStyle())
                Spacer(minLength: 4)
                NotchPhotoGlyphButton(symbol: "arrow.counterclockwise", title: text.again) { photos.again() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            copiedSerial = photos.copySerial
            let target = Double(result.outputBytes)
            if reduceMotion {
                shownBytes = target
            } else {
                withAnimation(ZenithMotion.reveal(0.7).delay(0.12)) { shownBytes = target }
            }
        }
        .animation(.easeOut(duration: ZenithMotion.fast), value: photos.copySerial)
    }
}

private struct NotchPhotoFailedPane: View {
    let session: NotchPhotoSession
    let failure: NotchPhotoFailure
    let text: ZenithPhotoActionsStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchPhotoHeader(label: session.action == .transform ? text.transform : text.removeBackground,
                             symbol: nil, meta: nil, text: text)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                ZenithStatusDot(color: failure == .noSubject ? ZenithStatus.warning : ZenithStatus.error)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                Text(failure == .noSubject ? text.noSubject : text.failed)
                    .font(.system(size: 12))
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                if session.action == .transform {
                    Button(text.again) { photos.again() }
                        .buttonStyle(NotchPhotoOutlineButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// "3 · 12 MB": how many pictures and how much they weigh.
private func inputMeta(_ session: NotchPhotoSession) -> String {
    let size = NotchPhotoActionsSupport.formatBytes(session.inputBytes)
    return session.inputs.count > 1 ? "\(session.inputs.count) · \(size)" : size
}

/// A pane's heading: the mono label, its metadata and the way out.
private struct NotchPhotoHeader: View {
    let label: String
    let symbol: String?
    let meta: String?
    let text: ZenithPhotoActionsStrings
    var closes = true
    @ObservedObject private var photos = NotchPhotoActionsService.shared

    var body: some View {
        ZenithBentoHeader(label: label, symbol: symbol) {
            HStack(spacing: 6) {
                ZenithBentoMeta(text: meta)
                if closes { NotchPhotoGlyphButton(symbol: "xmark", title: text.close) { photos.close() } }
            }
        }
    }
}

/// A layer of the pane arriving after the picture: it rises a few points and
/// fades in, `index` × 40 ms after the first.
private struct NotchPhotoLayer: ViewModifier {
    let index: Int
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 6)
            .animation((reduceMotion ? Animation.easeOut(duration: 0.2) : photoSpring)
                .delay(ZenithMotion.layerDelay(index + 1)), value: shown)
    }
}

// MARK: - The picture

/// The dropped picture in a fixed square: a stack for a batch, a shimmer while
/// the work runs, the cutout's reveal when it is done, and the result to drag.
private struct NotchPhotoPreview: View {
    let session: NotchPhotoSession
    let side: CGFloat
    let arrived: Bool
    let text: ZenithPhotoActionsStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var result: NotchPhotoResult? {
        if case let .done(result) = session.phase { return result }
        return nil
    }

    var body: some View {
        ZStack {
            if session.inputs.count > 1 { stack }
            picture
            if let result {
                NotchPhotoDragSource(urls: result.outputs, image: result.preview ?? session.thumbnail)
                    .frame(width: fitted.width, height: fitted.height)
                    .help(text.dragHint)
                    .accessibilityLabel(text.dragHint)
            }
        }
        .frame(width: side, height: side)
        .overlay(alignment: .topTrailing) {
            if session.inputs.count > 1 {
                Text("×\(session.inputs.count)")
                    .font(ZenithType.mono(10, weight: .medium))
                    .foregroundStyle(ZenithIsland.primary)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(Capsule().fill(Color.black.opacity(0.72)))
                    .overlay(Capsule().strokeBorder(ZenithIsland.outline(contrast, emphasised: true), lineWidth: 1))
                    .offset(x: 4, y: -4)
            }
        }
        // The thumbnail is read off the main thread and fades in when it arrives.
        .animation(.easeOut(duration: ZenithMotion.fast), value: session.thumbnail != nil)
        // The picture settles in from the drop: a little larger, a little high.
        .scaleEffect(arrived || reduceMotion ? 1 : 0.86)
        .offset(y: arrived || reduceMotion ? 0 : -14)
        .opacity(arrived ? 1 : 0)
    }

    /// The picture's own shape inside the square, so every layer over it has
    /// the same fixed frame.
    private var fitted: CGSize {
        let image = result?.preview ?? session.thumbnail
        guard let image, image.width > 0, image.height > 0 else { return CGSize(width: side, height: side) }
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        return aspect >= 1 ? CGSize(width: side, height: (side / aspect).rounded())
            : CGSize(width: (side * aspect).rounded(), height: side)
    }

    @ViewBuilder private var picture: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
        if session.action == .removeBackground, let cutout = result?.preview {
            NotchPhotoCutoutReveal(sessionID: session.id, original: session.thumbnail, cutout: cutout, size: fitted)
                .overlay(shape.strokeBorder(ZenithIsland.outline(contrast), lineWidth: 1).allowsHitTesting(false))
        } else if let thumbnail = session.thumbnail {
            Image(decorative: thumbnail, scale: 1)
                .resizable()
                .interpolation(.high)
                .frame(width: fitted.width, height: fitted.height)
                .overlay {
                    if session.phase.isWorking { NotchPhotoShimmer() }
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(ZenithIsland.outline(contrast), lineWidth: 1).allowsHitTesting(false))
                .transition(.opacity)
        } else {
            shape.fill(Color.white.opacity(0.04))
                .overlay(shape.strokeBorder(ZenithIsland.outline(contrast), lineWidth: 1))
                .overlay(Image(systemName: "photo").font(.system(size: 22, weight: .light))
                    .foregroundStyle(ZenithIsland.tertiary))
                .frame(width: side * 0.8, height: side * 0.8)
                .overlay { if session.phase.isWorking { NotchPhotoShimmer().clipShape(shape) } }
        }
    }

    /// The batch behind the first picture: two hairline cards, turned.
    private var stack: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
        return ZStack {
            shape.fill(Color.white.opacity(0.03))
                .overlay(shape.strokeBorder(ZenithIsland.outline(contrast), lineWidth: 1))
                .frame(width: side * 0.8, height: side * 0.8)
                .rotationEffect(.degrees(-7))
                .offset(x: -6, y: 2)
            shape.fill(Color.white.opacity(0.03))
                .overlay(shape.strokeBorder(ZenithIsland.outline(contrast), lineWidth: 1))
                .frame(width: side * 0.8, height: side * 0.8)
                .rotationEffect(.degrees(5))
                .offset(x: 6, y: -2)
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// A light band sweeping across the picture while the work runs: a white
/// wash masked by a gradient that moves by offset alone.
private struct NotchPhotoShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let band = max(24, width * 0.55)
            ZStack {
                Color.black.opacity(0.18)
                if !reduceMotion {
                    Color.white.opacity(0.32)
                        .mask(alignment: .leading) {
                            LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: band)
                                .offset(x: -band + phase * (width + band))
                        }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}

/// Remove Background's moment: the subject opens out of the original over a
/// transparency checkerboard, inside a soft disc that grows from the centre.
/// One value drives it, 0.75 s on the reveal curve. Played once per session.
private struct NotchPhotoCutoutReveal: View {
    let sessionID: UUID
    let original: CGImage?
    let cutout: CGImage
    let size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
        ZStack {
            NotchPhotoCheckerboard()
                .drawingGroup()
            if let original {
                picture(original).mask { mask(inverted: true) }
            }
            picture(cutout).mask { mask(inverted: false) }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .onAppear {
            guard !NotchPhotoRevealLedger.shared.played.contains(sessionID) else {
                reveal = 1
                return
            }
            NotchPhotoRevealLedger.shared.played.insert(sessionID)
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : ZenithMotion.reveal(0.75).delay(0.05)) { reveal = 1 }
        }
    }

    private func picture(_ image: CGImage) -> some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder private func mask(inverted: Bool) -> some View {
        if reduceMotion {
            Rectangle().opacity(inverted ? 1 - reveal : reveal)
        } else {
            let diameter = max(size.width, size.height)
            let disc = Circle()
                .fill(RadialGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.7),
                                             .init(color: .white.opacity(0), location: 1)],
                                     center: .center, startRadius: 0, endRadius: diameter / 2))
                .frame(width: diameter, height: diameter)
                .scaleEffect(max(0.001, reveal * 2.3))
            if inverted {
                ZStack {
                    Rectangle()
                    disc.blendMode(.destinationOut)
                }
                .compositingGroup()
            } else {
                disc
            }
        }
    }
}

/// Sessions whose reveal has played, so reopening the island shows the result
/// at rest instead of playing it again.
private final class NotchPhotoRevealLedger {
    static let shared = NotchPhotoRevealLedger()
    var played = Set<UUID>()
}

/// The transparency grid, drawn once in a Canvas.
private struct NotchPhotoCheckerboard: View {
    var cell: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.16)))
            var squares = Path()
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : cell
                while x < size.width {
                    squares.addRect(CGRect(x: x, y: y, width: cell, height: cell))
                    x += cell * 2
                }
                y += cell
                row += 1
            }
            context.fill(squares, with: .color(Color(white: 0.24)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Progress and completion

/// A thin ring whose trim follows the work; the caller animates it.
private struct NotchPhotoProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// A figure that counts to its value: SwiftUI interpolates `value` frame by
/// frame and the text follows in mono.
private struct NotchPhotoCountUp: View, Animatable {
    var value: Double
    var size: CGFloat = 22
    let format: (Double) -> String

    init(value: Double, size: CGFloat = 22, format: @escaping (Double) -> String) {
        self.value = value
        self.size = size
        self.format = format
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        ZenithFigure(text: format(value), size: size)
            .fixedSize()
    }
}

private struct NotchPhotoCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.77, y: rect.minY + rect.height * 0.31))
        return path
    }
}

/// Done: an emerald ring whose check draws itself by trim.
private struct NotchPhotoCheckmark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().fill(ZenithStatus.fill(ZenithStatus.success))
            Circle().strokeBorder(ZenithStatus.success.opacity(0.45), lineWidth: 1)
            NotchPhotoCheckShape()
                .trim(from: 0, to: reduceMotion ? 1 : drawn)
                .stroke(ZenithStatus.success, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .opacity(reduceMotion ? drawn : 1)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : ZenithMotion.reveal(0.4).delay(0.1)) { drawn = 1 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// Press feedback: down to 0.96 in 100 ms, back on a spring. Under Reduce
/// Motion a press dims instead.
private struct NotchPhotoPress: ViewModifier {
    let pressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
            .opacity(pressed && reduceMotion ? 0.7 : 1)
            .animation(pressed ? .easeOut(duration: 0.1) : .spring(response: 0.32, dampingFraction: 0.82), value: pressed)
    }
}

private struct NotchPhotoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(NotchPhotoPress(pressed: configuration.isPressed))
    }
}

/// The island's one solid action, with press feedback.
private struct NotchPhotoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZenithIslandPrimaryButtonStyle(height: 28).makeBody(configuration: configuration)
            .modifier(NotchPhotoPress(pressed: configuration.isPressed))
    }
}

/// A hairline capsule, with press feedback.
private struct NotchPhotoOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZenithIslandOutlineButtonStyle(height: 26).makeBody(configuration: configuration)
            .modifier(NotchPhotoPress(pressed: configuration.isPressed))
    }
}

/// A bare glyph that brightens under the pointer (close, start over).
private struct NotchPhotoGlyphButton: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(hovering ? ZenithIsland.primary : ZenithIsland.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(hovering ? ZenithIsland.hoverFill : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(NotchPhotoPressStyle())
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(title)
        .accessibilityLabel(title)
    }
}

// MARK: - Drop zones

/// A drop zone of the island's chooser (Files, AirDrop, Optimize media and
/// the photo actions). When a drag enters, the zones breathe in one after
/// another, 40 ms apart: from 0.97 to full size, their dashed hairline fading
/// up and their glyph rising a few points. The zone under the pointer
/// brightens and lifts its glyph on a spring.
struct NotchDropZoneCell: View {
    let title: String
    let symbol: String
    let selected: Bool
    var available = true
    var note: String?
    var index = 0
    @State private var entered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(selected ? ZenithIsland.accent : ZenithIsland.secondary)
                .scaleEffect(selected && !reduceMotion ? 1.06 : 1)
                .offset(y: reduceMotion ? 0 : selected ? -3 : entered ? 0 : 5)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(selected ? ZenithIsland.primary : ZenithIsland.secondary)
            if !available, let note, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zenithDropZone(targeted: selected)
        .scaleEffect(reduceMotion ? 1 : entered ? (selected ? 1.015 : 1) : 0.97)
        .opacity(entered ? (available ? 1 : 0.5) : 0)
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : .spring(response: 0.34, dampingFraction: 0.84),
                   value: selected)
        .onAppear {
            withAnimation((reduceMotion ? Animation.easeOut(duration: 0.2)
                           : .spring(response: 0.38, dampingFraction: 0.86)).delay(ZenithMotion.layerDelay(index))) {
                entered = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Drag out

/// The finished files dragged out of the island as a stack, wherever they are
/// wanted: Finder, Mail, a browser upload, a design tool.
private struct NotchPhotoDragSource: NSViewRepresentable {
    let urls: [URL]
    let image: CGImage?

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.urls = urls
        view.image = image
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.urls = urls
        view.image = image
    }

    final class DragView: NSView {
        var urls: [URL] = []
        var image: CGImage?
        private var downEvent: NSEvent?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            downEvent = event
        }

        override func mouseUp(with event: NSEvent) {
            downEvent = nil
        }

        override func mouseDragged(with event: NSEvent) {
            guard let downEvent, !urls.isEmpty else { return }
            self.downEvent = nil
            let picture: NSImage? = image.map { NSImage(cgImage: $0, size: bounds.size) }
            let items = urls.enumerated().map { index, url -> NSDraggingItem in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                let offset = CGFloat(min(index, 3)) * 4
                let frame = bounds.offsetBy(dx: offset, dy: -offset)
                item.setDraggingFrame(frame, contents: picture ?? NSWorkspace.shared.icon(forFile: url.path))
                return item
            }
            NotchPhotoActionsService.shared.isDraggingOut = true
            beginDraggingSession(with: items, event: downEvent, source: NotchPhotoDragOut.shared)
        }
    }
}

/// The drag's source, kept apart from the view: the island may close while
/// the files are still on their way.
private final class NotchPhotoDragOut: NSObject, NSDraggingSource {
    static let shared = NotchPhotoDragOut()

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        NotchPhotoActionsService.shared.isDraggingOut = false
    }
}
