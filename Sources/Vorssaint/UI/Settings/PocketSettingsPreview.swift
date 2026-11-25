// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the preview card of Settings → iPhone & Watch. This Mac's
// desktop with the page's own window on it, and an iPhone beside it running
// Zenith Pocket, drawn small in Pocket's look: dark grey surfaces, a sentence
// headline (the first part bold, the rest regular grey) and a black pill tab
// bar. Unpaired, the phone asks for the Mac; Pairing, the Mac shows a code
// and the phone scans it; Paired, the phone shows the Mac's battery with what
// Sharing lets through, and the Watch beside it. Sample data only; the loop
// stops while the window is hidden or Reduce Motion is on.

struct PocketPreviewCard: View {
    @Binding var state: Int
    let sharing: PocketPreviewSharing
    var openPairing: () -> Void
    var openSharing: () -> Void

    var body: some View {
        let text = ZenithPocketPreviewStrings.shared
        let captions = [text.unpairedCaption, text.pairingCaption, text.pairedCaption]
        let index = min(max(state, 0), 2)
        ZenithSettingsPreviewCard(id: "pocket", caption: captions[index],
                                  states: [text.unpaired, text.scan, text.paired], selection: $state,
                                  highlight: index == PocketPreviewState.paired ? text.sharingPart : text.pairingPart,
                                  aspectRatio: 1.9) {
            PocketPreviewPicture(state: index, sharing: sharing,
                                 action: index == PocketPreviewState.paired ? openSharing : openPairing)
        }
    }
}

/// What Sharing lets the phone show, so the picture follows the switches.
struct PocketPreviewSharing: Equatable {
    var wallpaper = true
    var agents = true
    var nowPlaying = true
}

private struct PocketPreviewPicture: View {
    let state: Int
    let sharing: PocketPreviewSharing
    let action: () -> Void

    var body: some View {
        ZenithPreviewDesktop(screenWidth: 1000) {
            ZenithPreviewLoop(period: 6, stillPhase: state == PocketPreviewState.pairing ? 0.4 : 0.6) { phase in
                HStack(alignment: .center, spacing: 70) {
                    PocketPreviewMacWindow(state: state, phase: phase)
                        .zenithPreviewPart(cornerRadius: 18, highlighted: state != PocketPreviewState.paired,
                                           action: action)
                    PocketPreviewPhone(state: state, sharing: sharing, phase: phase)
                        .overlay(alignment: .bottomLeading) {
                            if state == PocketPreviewState.paired {
                                PocketPreviewWatch().offset(x: -70, y: -14)
                            }
                        }
                        .zenithPreviewPart(cornerRadius: 40, highlighted: state == PocketPreviewState.paired,
                                           action: action)
                }
                .padding(.top, ZenithPreviewDesktop<EmptyView>.menuBarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - The Mac

/// The page's window, small: its button, its code, or the paired devices.
private struct PocketPreviewMacWindow: View {
    let state: Int
    let phase: Double
    private let text = ZenithPocketPreviewStrings.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18),
                         Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) { color in
                    Circle().fill(color).frame(width: 11, height: 11)
                }
                Spacer()
                Text(text.windowTitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 47, height: 1)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 340, height: 300)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.97), in: shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.12)))
        .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
    }

    @ViewBuilder private var content: some View {
        switch state {
        case PocketPreviewState.pairing:
            VStack(spacing: 14) {
                PocketPreviewCode(side: 150)
                Text(text.windowScan).font(.system(size: 14, weight: .semibold))
            }
        case PocketPreviewState.paired:
            VStack(spacing: 10) {
                device("iphone", text.windowPaired, text.windowPairedDetail)
                device("applewatch", text.windowWatch, text.windowWatchDetail)
            }
            .padding(.horizontal, 22)
        default:
            // The button pulses once a loop, as if about to be clicked.
            let press = zenithPreviewSegment(phase, 0.55, 0.65) * (1 - zenithPreviewSegment(phase, 0.65, 0.8))
            VStack(spacing: 18) {
                Image(systemName: "macbook.and.iphone")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.secondary)
                Text(text.windowPair)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 32)
                    .background(Capsule().fill(Color.accentColor))
                    .scaleEffect(1 - 0.06 * press)
            }
        }
    }

    private func device(_ symbol: String, _ name: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 14, weight: .medium))
                Text(detail).font(ZenithType.mono(11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A made-up code, drawn the same way as the real one: never a pairing, so
/// a camera pointed at the preview finds nothing to pair with.
private struct PocketPreviewCode: View {
    let side: CGFloat
    private static let image: CGImage? = {
        let payload = "zenith-pocket://preview?v=1&n=" + String(repeating: "sample-", count: 30)
        guard let url = URL(string: payload), let matrix = PocketQR.matrix(for: url) else { return nil }
        return PocketQR.image(matrix)
    }()

    var body: some View {
        Group {
            if let image = Self.image {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
            } else {
                Color.white
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - The iPhone

/// Pocket's surfaces.
private enum PocketLook {
    static let screen = Color(white: 0.07)
    static let surface = Color(white: 0.15)
    static let secondary = Color(white: 0.58)
    static let width: CGFloat = 214
    static let height: CGFloat = 440
}

private struct PocketPreviewPhone: View {
    let state: Int
    let sharing: PocketPreviewSharing
    let phase: Double

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: 40, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: 34, style: .continuous)
        ZStack(alignment: .top) {
            PocketLook.screen
            screen
            statusBar
        }
        .clipShape(inner)
        .padding(7)
        .frame(width: PocketLook.width, height: PocketLook.height)
        .background(Color.black, in: outer)
        .overlay(outer.strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        .environment(\.colorScheme, .dark)
    }

    private var statusBar: some View {
        HStack {
            Text(ZenithPocketPreviewStrings.shared.phoneTime).font(.system(size: 12, weight: .semibold))
            Spacer()
            Capsule().fill(Color.black).frame(width: 62, height: 18)
            Spacer()
            Image(systemName: "battery.75percent").font(.system(size: 12))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 9)
    }

    @ViewBuilder private var screen: some View {
        switch state {
        case PocketPreviewState.pairing: PocketPreviewScanner(phase: phase)
        case PocketPreviewState.paired: PocketPreviewHome(sharing: sharing, phase: phase)
        default: PocketPreviewWelcome(phase: phase)
        }
    }
}

/// Before pairing: the app asks for the Mac.
private struct PocketPreviewWelcome: View {
    let phase: Double
    private let text = ZenithPocketPreviewStrings.shared

    var body: some View {
        let breathe = 0.5 - 0.5 * cos(phase * 2 * .pi)
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 60)
            Image(systemName: "macbook")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(PocketLook.secondary)
            (Text(text.welcomeTitle).fontWeight(.bold).foregroundColor(.white)
                + Text(text.welcomeRest).foregroundColor(PocketLook.secondary))
                .font(.system(size: 22))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(text.pairButton)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Capsule().fill(Color.white))
                .scaleEffect(1 + 0.025 * breathe)
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 18)
    }
}

/// Pairing: the camera on the Mac's code, a line sweeping it, then the
/// corners turn green once it reads.
private struct PocketPreviewScanner: View {
    let phase: Double
    private let text = ZenithPocketPreviewStrings.shared

    var body: some View {
        let found = phase > 0.72
        let sweep = zenithPreviewSegment(phase, 0.05, 0.68)
        VStack(spacing: 18) {
            Spacer().frame(height: 40)
            ZStack {
                PocketPreviewCode(side: 120)
                    .opacity(0.85)
                    .rotationEffect(.degrees(-4))
                if !found {
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 150, height: 2)
                        .offset(y: -70 + 140 * sweep)
                }
                PocketPreviewBrackets(color: found ? ZenithStatus.success : .white)
                    .frame(width: 160, height: 160)
                if found {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white, ZenithStatus.success)
                }
            }
            .frame(width: 170, height: 170)
            Text(text.scanHint)
                .font(.system(size: 12))
                .foregroundStyle(PocketLook.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.03))
    }
}

/// A viewfinder's four corners.
private struct PocketPreviewBrackets: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let length: CGFloat = 26, radius: CGFloat = 10
            var path = Path()
            let w = size.width, h = size.height
            path.move(to: CGPoint(x: 0, y: length)); path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero); path.addLine(to: CGPoint(x: length, y: 0))
            path.move(to: CGPoint(x: w - length, y: 0)); path.addLine(to: CGPoint(x: w - radius, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: radius), control: CGPoint(x: w, y: 0)); path.addLine(to: CGPoint(x: w, y: length))
            path.move(to: CGPoint(x: w, y: h - length)); path.addLine(to: CGPoint(x: w, y: h - radius))
            path.addQuadCurve(to: CGPoint(x: w - radius, y: h), control: CGPoint(x: w, y: h)); path.addLine(to: CGPoint(x: w - length, y: h))
            path.move(to: CGPoint(x: length, y: h)); path.addLine(to: CGPoint(x: radius, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - radius), control: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: 0, y: h - length))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }
}

/// Paired: the Mac in a sentence, then what Sharing lets through, over the
/// black pill tab bar.
private struct PocketPreviewHome: View {
    let sharing: PocketPreviewSharing
    let phase: Double
    @ObservedObject private var wallpaper = ZenithPreviewWallpaper.shared
    private let text = ZenithPocketPreviewStrings.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Spacer().frame(height: 34)
                if sharing.wallpaper { wallpaperCard }
                (Text(text.headlineBold).fontWeight(.bold).foregroundColor(.white)
                    + Text(text.headlineRest).foregroundColor(PocketLook.secondary))
                    .font(.system(size: 19))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, sharing.wallpaper ? 2 : 24)
                if sharing.agents { agentCard }
                if sharing.nowPlaying { musicCard }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            tabBar
        }
    }

    private var wallpaperCard: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(red: 0.24, green: 0.26, blue: 0.45), Color(red: 0.45, green: 0.37, blue: 0.62)],
                           startPoint: .top, endPoint: .bottom)
            if let image = wallpaper.image {
                Image(nsImage: image).resizable().interpolation(.medium).aspectRatio(contentMode: .fill)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 5) {
                Image(systemName: "laptopcomputer").font(.system(size: 10, weight: .semibold))
                Text(text.macName).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(9)
        }
        .frame(height: 92)
        .frame(maxWidth: .infinity)
        .clipShape(shape)
    }

    private var agentCard: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZenithStatus.progress)
                .frame(width: 28, height: 28)
                .background(ZenithStatus.fill(ZenithStatus.progress), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(text.claude).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text(text.claudeLine).font(.system(size: 10.5)).foregroundStyle(PocketLook.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            // Three dots taking turns, like a step in progress.
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { dot in
                    let lit = Int(phase * 9) % 3 == dot
                    Circle().fill(Color.white.opacity(lit ? 0.9 : 0.3)).frame(width: 4, height: 4)
                }
            }
        }
        .padding(9)
        .background(PocketLook.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var musicCard: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.42, blue: 0.55), Color(red: 0.35, green: 0.3, blue: 0.85)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(text.song).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Text(text.artist).font(.system(size: 10.5)).foregroundStyle(PocketLook.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: geo.size.width * (0.25 + 0.5 * phase))
                    }
                }
                .frame(height: 3)
            }
            Image(systemName: "pause.fill").font(.system(size: 12)).foregroundStyle(.white)
        }
        .padding(9)
        .background(PocketLook.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.tabs.enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(index == 0 ? Color.white : PocketLook.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 42)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - The Watch

/// The paired Watch, its face a ring of the Mac's battery.
private struct PocketPreviewWatch: View {
    var body: some View {
        let outer = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack {
            Color.black
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 6).frame(width: 52, height: 52)
            Circle().trim(from: 0, to: 0.47)
                .stroke(ZenithStatus.success, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 52)
            Text(ZenithPocketPreviewStrings.shared.watchPercent).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .padding(5)
        .frame(width: 84, height: 100)
        .background(Color(white: 0.12), in: outer)
        .overlay(outer.strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .environment(\.colorScheme, .dark)
    }
}
