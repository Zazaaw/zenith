// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the photo actions' watermark in Shelf settings (a Settings
/// kit section, its look under More options), beside the
/// photo actions' own switch: the preset every new drop starts from, the logo
/// (the Satu Visual star or a chosen PNG, SVG or PDF), the text and its
/// weight, the colour and the shadow. It edits the same watermark the island
/// does (`NotchPhotoActionsService.watermark`), so both always agree.
struct NotchWatermarkSettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var photos = NotchPhotoActionsService.shared
    @AppStorage(DefaultsKey.notchWatermarkDefaultPreset) private var defaultPreset = ""

    var body: some View {
        let text = ZenithStrings.watermark(l10n.language)
        ZenithSection(text.title, anchor: .zenithWatermark, footer: text.caption) { // Settings search lands here
            ZenithRow(text.defaultPreset, selection: $defaultPreset) {
                Text(text.none).tag("")
                ForEach(photos.watermarkPresets) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            ZenithRow(text.logo, warning: missingLogo ? text.logoMissing : nil) {
                HStack(spacing: 8) {
                    NotchWatermarkLogoThumbnail(file: photos.watermark.logoFile)
                        .frame(width: 22, height: 22)
                    if photos.watermark.logoFile != nil {
                        Button(text.star) { photos.useWatermarkStar() }
                    } else {
                        Text(text.star).foregroundStyle(.secondary)
                    }
                    Button(text.chooseLogo) { photos.chooseWatermarkLogo() }
                }
            }
            ZenithRow(text.text) {
                TextField(text.text, text: Binding(
                    get: { photos.watermark.text },
                    set: { photos.watermark.text = NotchWatermarkSupport.textInput($0) }),
                          prompt: Text(NotchWatermarkStyle.defaultText))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 220)
            }
            ZenithRow(text.content, selection: $photos.watermark.content) {
                Text(text.logo).tag(NotchWatermarkContent.logo)
                Text(text.text).tag(NotchWatermarkContent.text)
                Text(text.logoAndText).tag(NotchWatermarkContent.both)
            }
            ZenithMoreOptions(id: "shelf.watermark") {
                ZenithRow(text.weight, selection: $photos.watermark.weight) {
                    Text(text.regular).tag(NotchWatermarkWeight.regular)
                    Text(text.medium).tag(NotchWatermarkWeight.medium)
                    Text(text.semibold).tag(NotchWatermarkWeight.semibold)
                    Text(text.bold).tag(NotchWatermarkWeight.bold)
                }
                ZenithRow(text.color) {
                    HStack(spacing: 8) {
                        if photos.watermark.color == .custom {
                            ColorPicker(text.customColor, selection: customColor, supportsOpacity: false)
                                .labelsHidden()
                        }
                        ZenithRowMenu(title: text.color, selection: $photos.watermark.color, options: colorOptions(text))
                    }
                }
                ZenithRow(text.shadow, isOn: $photos.watermark.shadow)
            }
        }
    }

    private var missingLogo: Bool {
        guard let file = photos.watermark.logoFile else { return false }
        return !NotchWatermarkLogoStore.exists(file)
    }

    @ViewBuilder
    private func colorOptions(_ text: ZenithWatermarkStrings) -> some View {
        Text(text.autoColor).tag(NotchWatermarkColor.auto)
        Text(text.white).tag(NotchWatermarkColor.white)
        Text(text.black).tag(NotchWatermarkColor.black)
        Text(text.customColor).tag(NotchWatermarkColor.custom)
        if photos.watermark.logoFile != nil {
            Text(text.originalColors).tag(NotchWatermarkColor.original)
        }
    }

    /// The custom colour as `#RRGGBB`, read and written through sRGB.
    private var customColor: Binding<Color> {
        Binding(
            get: {
                let rgb = NotchWatermarkSupport.rgb(hex: photos.watermark.customColor) ?? (1, 1, 1)
                return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
            },
            set: { color in
                guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                photos.watermark.customColor = NotchWatermarkSupport.hex(
                    red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
            })
    }
}

/// The logo, small: the star as a template in the label colour, a chosen
/// logo in its own colours.
private struct NotchWatermarkLogoThumbnail: View {
    let file: String?
    @State private var image: CGImage?
    @State private var template = true

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 2)
                    .renderingMode(template ? .template : .original)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.primary)
            } else {
                Color.clear
            }
        }
        .task(id: file) { render() }
        .accessibilityHidden(true)
    }

    private func render() {
        let logo = NotchWatermarkLogo.load(file)
        let side = 52
        let size = logo.aspect >= 1 ? CGSize(width: CGFloat(side), height: (CGFloat(side) / logo.aspect).rounded())
            : CGSize(width: (CGFloat(side) * logo.aspect).rounded(), height: CGFloat(side))
        guard let context = CGContext(data: nil, width: max(1, Int(size.width)), height: max(1, Int(size.height)),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        logo.draw(in: context, rect: CGRect(origin: .zero, size: size))
        template = logo.isStar
        image = context.makeImage()
    }
}
