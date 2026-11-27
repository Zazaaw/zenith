// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the hero animations of the sound and capture pages, one per
// tool, in the kit's rules (docs/SETTINGS-KIT.md): a few shapes drawn from
// `context.t`, loops of 1, 2 or 4 seconds, and a still frame (t = 1.1) that
// reads on its own.

// MARK: - Volume Mixer

/// Volume Mixer: three faders beside the icon, each app at its own level.
struct ZenithVolumeMixerHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            context.icon.offset(x: -30)
            HStack(spacing: 9) {
                ForEach(0..<3, id: \.self) { k in
                    let level = 0.3 + 0.55 * ZenithKitEase.pulse(t + Double(k) * 1.3, period: 4)
                    fader(level, tint: context.tint, dark: context.dark)
                }
            }
            .offset(x: 62)
        }
    }

    private func fader(_ level: Double, tint: ZenithCategoryTint, dark: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(Color.primary.opacity(dark ? 0.16 : 0.12)).frame(width: 6, height: 74)
            Capsule().fill(LinearGradient(colors: [tint.light.color, tint.deep.color], startPoint: .top, endPoint: .bottom))
                .frame(width: 6, height: 74 * level)
            Circle().fill(Color.white).frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .offset(y: -74 * level + 6.5)
        }
        .frame(height: 74, alignment: .bottom)
    }
}

extension ZenithHeroAnimation where Self == ZenithVolumeMixerHeroArt {
    static var volumeMixer: Self { .init() }
}

// MARK: - Sound Output

/// Sound Output: the sound waves switch sides, from one device to the other.
struct ZenithSoundOutputHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let right = p < 0.5
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let wave = ZenithKitEase.phase(context.t, period: 1, offset: Double(k) / 3)
                let side: CGFloat = right ? 1 : -1
                Circle()
                    .trim(from: 0.4, to: 0.6)
                    .stroke(context.tint.light.color.opacity(0.75 * (1 - wave)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 70 + 70 * wave, height: 70 + 70 * wave)
                    .rotationEffect(.degrees(right ? 180 : 0))
                    .offset(x: side * 18)
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithSoundOutputHeroArt {
    static var soundOutput: Self { .init() }
}

// MARK: - Music Blocker

/// Music Blocker: a note rises from the icon and is stopped by a red bar.
struct ZenithMusicBlockerHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let rise = ZenithKitEase.smooth(p / 0.45)
        let blocked = ZenithKitEase.smooth((p - 0.4) / 0.15)
        ZStack {
            context.icon
            ZStack {
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                Circle()
                    .strokeBorder(ZenithStatus.error, lineWidth: 3.5)
                    .frame(width: 38, height: 38)
                    .overlay(Capsule().fill(ZenithStatus.error).frame(width: 3.5, height: 38).rotationEffect(.degrees(45)))
                    .scaleEffect(0.6 + 0.4 * blocked)
                    .opacity(blocked)
            }
            .offset(x: 46, y: -24 - 30 * rise)
            .opacity(p > 0.9 ? 1 - ZenithKitEase.smooth((p - 0.9) / 0.1) : 1)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMusicBlockerHeroArt {
    static var musicBlocker: Self { .init() }
}

// MARK: - Mic Mute

/// Mic Mute: the voice's level beside the icon, then the slash, and the level drops.
struct ZenithMicMuteHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let p = ZenithKitEase.phase(t, period: 4)
        let muted = p < 0.5 ? ZenithKitEase.smooth((p - 0.1) / 0.1) : 1 - ZenithKitEase.smooth((p - 0.6) / 0.1)
        ZStack {
            context.icon
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { k in
                    let voice = 0.35 + 0.65 * ZenithKitEase.pulse(t * 2 + Double(k) * 0.37, period: 1)
                    Capsule()
                        .fill(context.tint.light.color.opacity(0.85))
                        .frame(width: 4, height: 6 + 30 * voice * (1 - 0.85 * muted))
                }
            }
            .frame(height: 40)
            .offset(x: 72)
            Circle()
                .fill(ZenithStatus.error)
                .frame(width: 26, height: 26)
                .overlay(Image(systemName: "mic.slash.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(0.5 + 0.5 * muted)
                .opacity(muted)
                .offset(x: 36, y: -36)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMicMuteHeroArt {
    static var micMute: Self { .init() }
}

// MARK: - Screenshot

/// Screenshot: the selection's corners close in on the icon, and the shutter flashes.
struct ZenithScreenshotHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let close = ZenithKitEase.smooth(p / 0.45)
        let flash = p > 0.5 ? max(0, 1 - (p - 0.5) / 0.2) : 0
        let side = 160 - 40 * close
        ZStack {
            context.icon
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.45 * flash))
                .frame(width: 88, height: 88)
            ForEach(0..<4, id: \.self) { k in
                Corner()
                    .stroke(context.tint.light.color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(Double(k) * 90))
                    .offset(x: (k == 0 || k == 3 ? -1 : 1) * side / 2, y: (k < 2 ? -1 : 1) * side / 2)
            }
        }
    }

    /// One corner of the selection, its point at the top left.
    private struct Corner: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithScreenshotHeroArt {
    static var screenshot: Self { .init() }
}

// MARK: - Screen Recording

/// Screen Recording: the red dot pulses and the ring fills as the take runs.
struct ZenithScreenRecordingHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let beat = ZenithKitEase.pulse(t, period: 1)
        let take = ZenithKitEase.phase(t, period: 4)
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(context.dark ? 0.14 : 0.1), lineWidth: 4)
                .frame(width: 138, height: 138)
            Circle()
                .trim(from: 0, to: take)
                .stroke(ZenithStatus.error.opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 138, height: 138)
            context.icon
            Circle()
                .fill(ZenithStatus.error)
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(0.85 + 0.25 * beat)
                .shadow(color: ZenithStatus.error, radius: 6 * beat)
                .offset(x: 38, y: -38)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithScreenRecordingHeroArt {
    static var screenRecording: Self { .init() }
}

// MARK: - Text Capture

/// Text Capture: a scan line runs down lines of text, which light up as it passes.
struct ZenithTextCaptureHeroArt: ZenithHeroAnimation {
    private static let widths: [CGFloat] = [56, 44, 60, 34]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let scan = ZenithKitEase.smooth(p / 0.7)
        ZStack {
            context.base
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.widths.indices, id: \.self) { k in
                    let read = scan > (Double(k) + 0.5) / Double(Self.widths.count)
                    Capsule()
                        .fill(read ? context.tint.light.color : (context.dark ? Color.white.opacity(0.35) : Color.black.opacity(0.18)))
                        .frame(width: Self.widths[k], height: 6)
                }
            }
            .frame(width: 60, alignment: .leading)
            Capsule()
                .fill(context.tint.light.color)
                .frame(width: 76, height: 2.5)
                .shadow(color: context.tint.light.color, radius: 5)
                .offset(y: -26 + 52 * scan)
                .opacity(p > 0.85 ? 0 : 1)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithTextCaptureHeroArt {
    static var textCapture: Self { .init() }
}

// MARK: - Color Picker

/// Color Picker: swatches circle the icon, and the one under the dropper grows.
struct ZenithColorPickerHeroArt: ZenithHeroAnimation {
    private static let swatches: [Color] = [
        Color(red: 1, green: 0.36, blue: 0.42), Color(red: 1, green: 0.72, blue: 0.2),
        Color(red: 0.3, green: 0.85, blue: 0.5), Color(red: 0.25, green: 0.6, blue: 1),
        Color(red: 0.7, green: 0.45, blue: 1),
    ]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let picked = Int((t / 0.8).rounded(.down)) % Self.swatches.count
        let grow = ZenithKitEase.pulse(t, period: 0.8)
        ZStack {
            ForEach(Self.swatches.indices, id: \.self) { k in
                let angle = (Double(k) / Double(Self.swatches.count) - 0.25) * 2 * .pi
                Circle()
                    .fill(Self.swatches[k])
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                    .scaleEffect(k == picked ? 1 + 0.35 * grow : 0.85)
                    .shadow(color: Self.swatches[k].opacity(k == picked ? 0.8 : 0), radius: 6)
                    .offset(x: 72 * cos(angle), y: 72 * sin(angle))
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithColorPickerHeroArt {
    static var colorPicker: Self { .init() }
}

// MARK: - Camera Preview

/// Camera Preview: a round preview floats beside the icon, its ring breathing.
struct ZenithCameraPreviewHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let breath = ZenithKitEase.pulse(t, period: 4)
        ZStack {
            context.icon.offset(x: -14, y: 10)
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(white: 0.4), Color(white: 0.18)], startPoint: .top, endPoint: .bottom))
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(y: 7)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
            .overlay(Circle().strokeBorder(context.tint.light.color.opacity(0.6 * (1 - breath)), lineWidth: 2)
                .scaleEffect(1.1 + 0.25 * breath))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .offset(x: 48, y: -40 + 4 * (breath - 0.5))
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithCameraPreviewHeroArt {
    static var cameraPreview: Self { .init() }
}
