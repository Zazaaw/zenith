// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Set D: the features Orbit lists that have no illustration yet. Each is the
// feature's own symbol in a glossy gradient on the shared base, tinted by its
// shelf so a row of them still reads as one family. An illustration that
// lands later replaces its entry here under the same name.

enum OrbitIconsD {
    private struct Tint {
        let light: Color
        let deep: Color
        var colors: [Color] { [light, deep] }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    private static let windows = Tint(light: rgb(0.55, 0.75, 1), deep: rgb(0.3, 0.35, 0.95))
    private static let input = Tint(light: rgb(0.85, 0.65, 1), deep: rgb(0.5, 0.3, 0.95))
    private static let files = Tint(light: rgb(0.5, 0.85, 1), deep: rgb(0.15, 0.45, 0.95))
    private static let productivity = Tint(light: rgb(1, 0.82, 0.45), deep: rgb(0.95, 0.5, 0.15))
    private static let sound = Tint(light: rgb(1, 0.55, 0.7), deep: rgb(0.85, 0.2, 0.45))
    private static let system = Tint(light: rgb(0.5, 0.95, 0.85), deep: rgb(0.1, 0.6, 0.7))
    private static let monitor = Tint(light: rgb(0.55, 1, 0.6), deep: rgb(0.1, 0.65, 0.4))
    private static let media = Tint(light: rgb(1, 0.6, 0.85), deep: rgb(0.65, 0.3, 1))
    private static let island = Tint(light: rgb(0.7, 0.7, 1), deep: rgb(0.35, 0.3, 0.9))
    private static let devices = Tint(light: rgb(0.45, 0.95, 0.9), deep: rgb(0.1, 0.5, 0.8))

    private static func icon(_ name: String, _ group: String, _ symbol: String, _ tint: Tint,
                             size: CGFloat = 48) -> OrbitIcon {
        OrbitIcon(name: name, group: group, compact: symbol, tint: tint.colors,
                  art: AnyView(OrbitGlossy(symbol: symbol, colors: tint.colors, size: size)))
    }

    static let icons: [OrbitIcon] = [
        icon("Dock Click", "Windows", "dock.arrow.down.rectangle", windows),
        icon("Window Maximizer", "Windows", "arrow.up.left.and.arrow.down.right", windows, size: 44),
        icon("Spaces Order", "Windows", "rectangle.split.3x1.fill", windows, size: 44),
        icon("Quit Protection", "Windows", "shield.lefthalf.filled", windows),

        icon("Scroll Direction", "Input", "arrow.up.arrow.down", input, size: 46),
        icon("Horizontal Scroll", "Input", "arrow.left.arrow.right", input, size: 46),
        icon("Scroll Zoom", "Input", "plus.magnifyingglass", input),
        icon("Focus Follows Mouse", "Input", "cursorarrow.and.square.on.square.dashed", input, size: 46),
        icon("Linear Scroll", "Input", "arrow.up.and.down.text.horizontal", input, size: 44),
        icon("Scroll Speed", "Input", "gauge.with.dots.needle.67percent", input),
        icon("Mouse Acceleration", "Input", "cursorarrow.rays", input),
        icon("Mouse Navigation", "Input", "arrow.backward.circle.fill", input),
        icon("Middle Click", "Input", "hand.tap.fill", input),
        icon("Click Debounce", "Input", "cursorarrow.click.2", input),
        icon("Key Debounce", "Input", "keyboard.fill", input, size: 42),

        icon("Paste as Plain Text", "Productivity", "doc.plaintext.fill", productivity),

        icon("Cut and Paste", "Files", "scissors", files),
        icon("Finder Rename", "Files", "pencil.line", files),
        icon("Disk Image Installer", "Files", "externaldrive.fill.badge.plus", files, size: 44),

        icon("Audio Priority", "Sound", "list.number", sound, size: 46),

        icon("Up Next", "Media", "list.bullet.below.rectangle", media, size: 46),
        icon("Live Equalizer", "Media", "waveform", media),

        icon("Island Gestures", "Island", "hand.draw.fill", island),

        icon("Extra Brightness", "System", "sun.max.fill", system),
        icon("Kill Process", "System", "xmark.octagon.fill", system),
        icon("CPU", "System", "cpu.fill", monitor),
        icon("GPU", "System", "square.3.layers.3d", monitor),
        icon("Memory", "System", "memorychip.fill", monitor),
        icon("Network", "System", "network", monitor),
        icon("Disk", "System", "internaldrive.fill", monitor, size: 44),
        icon("Power", "System", "bolt.fill", monitor),

        icon("Connected Devices", "Devices", "cable.connector", devices),
        icon("Bluetooth Sleep", "Devices", "wave.3.right.circle.fill", devices),
    ]
}
