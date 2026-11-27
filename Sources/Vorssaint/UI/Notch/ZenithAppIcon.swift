// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the island's colourful icons. Faiz chose colour over the
// all-monochrome glyphs: each module, home shortcut, tool and home widget is
// a small glossy app icon in its identity colour (`NotchModule.zenithTint`).
//
// Drawn with SwiftUI shapes and gradients only, so it is crisp at any size:
// a rounded square with continuous corners (22.5% of its side, as app icons
// round), a vertical gradient derived from the tint (a lighter, slightly
// desaturated top into a deeper, richer bottom), a soft radial bloom and a
// gloss sheen across the top, inner shadows that light the top edge and
// shade the bottom one, a hairline whose light falls from above, then the
// white SF Symbol with a slight drop shadow in the tint's own darkest tone.
// Neutral tints (Vercel, GitHub) become graphite icons, as a terminal's is.
//
// The artwork is Zenith's own; only the idea of colourful icons in a dark
// island comes from the reference.
//
// Faiz later found the glossy squircles too loud beside the calm island and
// chose the soft tinted tiles (`ZenithIslandGlyphTile`) for every icon. The
// island draws `ZenithIslandIcon`, which follows `ZenithIconStyle`; the
// glossy icon stays here, one switch away.

/// Which icons the island draws: the soft tinted tiles (false) or the glossy
/// app icons (true). One switch for the shortcuts, the tools, the home
/// widgets and the edit strip.
enum ZenithIconStyle {
    static let glossy = false
}

/// A shortcut's, tool's or widget's icon in the island, in the style
/// `ZenithIconStyle` picks: its glyph on a soft tile of its colour, or the
/// glossy app icon.
struct ZenithIslandIcon: View {
    let symbol: String
    let hex: UInt32
    var size: CGFloat = 34
    /// The glossy icon's outer shadow; the tiles have none.
    var lifted = true

    var body: some View {
        if ZenithIconStyle.glossy {
            ZenithAppIcon(symbol: symbol, hex: hex, size: size, lifted: lifted)
        } else {
            ZenithIslandGlyphTile(symbol: symbol, tint: ZenithIslandPalette.color(hex: hex), size: size)
        }
    }
}

/// The colours an icon is drawn with, derived from its tint.
struct ZenithAppIconPalette: Equatable {
    var top: Color
    var bottom: Color
    /// The glyph's drop shadow.
    var shade: Color
    /// The tint itself, for marks drawn beside the icon.
    var tint: Color

    init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255, green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        let base = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        tint = Color(nsColor: base)
        func color(_ h: CGFloat, _ s: CGFloat, _ b: CGFloat) -> Color {
            Color(nsColor: NSColor(hue: (h + 1).truncatingRemainder(dividingBy: 1), saturation: min(1, max(0, s)),
                                   brightness: min(1, max(0, b)), alpha: 1))
        }
        if saturation < 0.12 {
            // A grey tint reads as graphite with a cool cast, like a terminal.
            top = color(0.6, 0.1, 0.42)
            bottom = color(0.62, 0.18, 0.16)
            shade = color(0.62, 0.3, 0.05)
        } else {
            // Bright yellows and limes need a deeper bottom for a white glyph to hold.
            let light = brightness > 0.85 && (hue > 0.1 && hue < 0.3)
            top = color(hue - 0.008, saturation * 0.86, brightness * 1.08 + 0.04)
            bottom = color(hue + 0.018, saturation * 1.12 + 0.06, brightness * (light ? 0.6 : 0.68))
            shade = color(hue + 0.02, saturation, brightness * 0.32)
        }
    }
}

/// A glossy app icon: `symbol` in white over its tint's gradient.
struct ZenithAppIcon: View {
    let symbol: String
    let hex: UInt32
    var size: CGFloat = 56
    /// The glyph's share of the side.
    var glyphScale: CGFloat = 0.48
    /// Draws without the outer shadow, for a dense strip.
    var lifted = true
    @Environment(\.colorSchemeContrast) private var contrast

    init(symbol: String, hex: UInt32, size: CGFloat = 56, glyphScale: CGFloat = 0.48, lifted: Bool = true) {
        self.symbol = symbol
        self.hex = hex
        self.size = size
        self.glyphScale = glyphScale
        self.lifted = lifted
    }

    /// A module's icon in its identity colour.
    init(module: NotchModule, size: CGFloat = 56, lifted: Bool = true) {
        self.init(symbol: module.zenithIconSymbol, hex: ZenithIslandPalette.hex(module), size: size, lifted: lifted)
    }

    /// The corner app icons use: 22.5% of the side, continuous.
    static func cornerRadius(size: CGFloat) -> CGFloat { size * 0.225 }

    var body: some View {
        let palette = ZenithAppIconPalette(hex: hex)
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius(size: size), style: .continuous)
        let unit = max(0.5, size / 64)
        // The body, lit from above: highlight along the top edge, shade
        // along the bottom one.
        shape.fill(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom)
            .shadow(.inner(color: .white.opacity(0.42), radius: 1.2 * unit, y: 1.4 * unit))
            .shadow(.inner(color: .black.opacity(0.28), radius: 3 * unit, y: -2.4 * unit)))
            .overlay {
                // A soft bloom behind the glyph.
                shape.fill(RadialGradient(colors: [.white.opacity(0.22), .white.opacity(0)],
                                          center: UnitPoint(x: 0.5, y: 0.18), startRadius: 0, endRadius: size * 0.7))
            }
            .overlay(alignment: .top) {
                // The gloss: a sheen over the top half that fades out before the middle.
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 1.3, height: size * 0.72)
                    .offset(y: -size * 0.2)
            }
            .clipShape(shape)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * glyphScale, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: palette.shade.opacity(0.55), radius: 1.6 * unit, y: 1.2 * unit)
            }
            .overlay {
                // The hairline, bright above and faint below.
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(contrast == .increased ? 0.7 : 0.38),
                                                           .white.opacity(contrast == .increased ? 0.3 : 0.06)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: max(0.5, 0.75 * unit))
            }
            .frame(width: size, height: size)
        .compositingGroup()
        .shadow(color: .black.opacity(lifted ? 0.4 : 0), radius: lifted ? 3 * unit : 0, y: lifted ? 2 * unit : 0)
        .accessibilityHidden(true)
    }
}

/// A chosen or current icon's mark: a small accent disc with a check, so the
/// state never rests on colour alone.
struct ZenithAppIconCheck: View {
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(ZenithIsland.accent, in: Circle())
            .overlay { Circle().strokeBorder(Color.black, lineWidth: 1.5) }
            .accessibilityHidden(true)
    }
}

/// A press sinks the icon a little, on a quick spring.
struct ZenithAppIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(ZenithMotion.respecting(IslandMotion.spring(response: 0.24, damping: 0.7)), value: configuration.isPressed)
    }
}

// MARK: - Glyphs and colours

extension NotchModule {
    /// The glyph on the module's app icon: filled where a filled symbol
    /// reads better on colour than the page's own outline glyph.
    var zenithIconSymbol: String {
        switch self {
        case .controls: return "house.fill"
        case .mixer: return "slider.vertical.3"
        case .music: return "music.note"
        case .clipboard: return "doc.on.clipboard.fill"
        case .captures: return "camera.viewfinder"
        case .files: return "tray.full.fill"
        case .system: return "gauge.with.dots.needle.50percent"
        case .tools: return "wrench.and.screwdriver.fill"
        case .calendar: return "calendar"
        case .notifications: return "bell.badge.fill"
        case .timer: return "timer"
        case .camera: return "video.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .scratchpad: return "note.text"
        case .agents: return "sparkles"
        case .watch: return "eye.fill"
        case .wakatime: return "chevron.left.forwardslash.chevron.right"
        case .vercel: return "triangle.fill"
        case .github: return "arrow.triangle.branch"
        case .cardImport: return "sdcard.fill"
        case .devServers: return "server.rack"
        case .recap: return "sun.horizon.fill"
        case .sky: return "moon.stars.fill"
        case .git: return GitSupportSymbols.module // Zenith fork
        case .prompter: return "scroll.fill"
        case .batteries: return "battery.75percent" // Zenith fork
        case .calculator: return "plus.forwardslash.minus" // Zenith fork
        }
    }
}

extension NotchControlItem {
    /// The home shortcut's icon colour: the page it opens where it has one,
    /// otherwise a colour of its own.
    var zenithIconHex: UInt32 {
        switch self {
        case .volume: return ZenithIslandPalette.hex(.mixer)
        case .brightness, .keyboardLight: return 0xFBBF24
        case .keepAwake: return 0xF59E0B          // amber
        case .microphone: return 0xF472B6         // pink
        case .screenshot: return 0x22D3EE         // cyan
        case .recording: return 0xEF4444          // red
        case .speedTest: return 0x34D399          // emerald
        case .panel: return 0x60A5FA              // blue
        case .mixer: return ZenithIslandPalette.hex(.mixer)
        case .commandBar: return 0x94A3B8         // slate, a terminal's graphite
        case .scratchpad: return ZenithIslandPalette.hex(.scratchpad)
        case .music: return ZenithIslandPalette.hex(.music)
        case .timer: return ZenithIslandPalette.hex(.timer)
        case .calendar: return ZenithIslandPalette.hex(.calendar)
        }
    }
}

extension QuickLauncherItem {
    /// The tool's icon colour on the island's Tools grid.
    var zenithIconHex: UInt32 {
        switch self {
        case .keepAwake: return 0xF59E0B      // amber
        case .cleaner: return 0x2DD4BF        // teal
        case .toggles: return 0x60A5FA        // blue
        case .micMute: return 0xF472B6        // pink
        case .screenOCR: return 0x22D3EE      // cyan
        case .colorPicker: return 0xE879F9    // fuchsia
        case .clipboard: return ZenithIslandPalette.hex(.clipboard)
        case .windowLayout: return 0x38BDF8   // sky
        case .cleaning: return 0xA3E635       // lime
        case .homebrew: return 0xFB923C       // orange
        case .media: return 0xFB7185          // rose
        case .urlCleaner: return 0x34D399     // emerald
        case .uninstaller: return 0xF87171    // red
        case .screenshot: return 0x06B6D4     // deep cyan
        case .screenRecorder: return 0xEF4444 // red
        case .cameraPreview: return 0x10B981  // green
        case .scratchpad: return ZenithIslandPalette.hex(.scratchpad)
        }
    }
}
