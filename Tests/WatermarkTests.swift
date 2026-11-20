// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: the photo actions' Watermark step. Placement and the tile
/// pattern as geometry, Auto's white-or-black choice, presets and their place
/// in backups, the logo store, then the encode path end to end on small
/// generated pictures in a temporary folder.
enum WatermarkTests {
    private typealias Support = NotchWatermarkSupport
    private static let suiteName = "com.vorssaint.tests.watermark"

    static func run(_ suite: TestSuite) {
        strings(suite)
        recipes(suite)
        placement(suite)
        tiles(suite)
        contrast(suite)
        styles(suite)
        presets(suite)
        backups(suite)
        logos(suite)
        rendering(suite)
        endToEnd(suite)
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.watermark(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String } + text.positions
            suite.expect(values.count == 37 + 9 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") },
                         "\(language.rawValue) words every watermark option, with curly apostrophes")
            suite.expect(!values.contains { $0.contains("\u{2014}") }, "\(language.rawValue) uses no em dash")
            suite.expect(text.positions.count == 9 && Set(text.positions).count == 9,
                         "\(language.rawValue) names all nine places")
            suite.expect(text.caption.contains("-wm"), "\(language.rawValue) says what the output is called")
        }
    }

    // MARK: Recipes

    private static func recipes(_ suite: TestSuite) {
        let writable = ["public.jpeg", "public.png", "public.heic", "public.tiff"]
        var mark = NotchPhotoRecipe(kind: .watermark)
        mark.watermark = NotchWatermarkStyle()
        suite.expect(mark.nameSuffix == "-wm" && mark.outputFormat(source: .heic, writable: writable) == .heic
                        && mark.outputLongEdge == nil && !mark.stripsMetadata,
                     "the Watermark step keeps format, size and EXIF, and names the output -wm")
        suite.expect(mark.outputFormat(source: .webp, writable: writable) == .jpeg,
                     "a source Zenith cannot write is watermarked to JPEG")
        var resized = NotchPhotoRecipe(kind: .resize, longEdge: .large)
        resized.watermark = NotchWatermarkStyle()
        suite.expect(resized.nameSuffix == "-2048-wm" && resized.outputLongEdge == 2048,
                     "a resize that carries the watermark names both")
        var compressed = NotchPhotoRecipe(kind: .compress, quality: .balanced)
        compressed.watermark = NotchWatermarkStyle()
        suite.expect(compressed.nameSuffix == "-q80-wm", "a compression that carries the watermark names both")
        var stripped = NotchPhotoRecipe(kind: .strip)
        stripped.watermark = NotchWatermarkStyle()
        suite.expect(stripped.nameSuffix == "-clean-wm" && stripped.stripsMetadata,
                     "a strip that carries the watermark still strips")
        suite.expect(NotchPhotoRecipe(kind: .resize).nameSuffix == "-2048", "no watermark, no -wm")
    }

    // MARK: Placement

    private static func placement(_ suite: TestSuite) {
        let canvas = CGSize(width: 6000, height: 4000)
        let unit = Support.unit(canvas: canvas, scale: 8)
        suite.expectClose(Double(unit), 320, "the mark is 8% of the short edge tall")
        suite.expectClose(Double(Support.margin(canvas: canvas, margin: 3)), 120, "the margin is 3% of the short edge")
        let portrait = CGSize(width: 4000, height: 6000)
        suite.expect(Support.unit(canvas: portrait, scale: 8) == unit, "a portrait uses the same short edge")

        let logo = Support.block(unit: 320, content: .logo, logoAspect: 2, textSize: CGSize(width: 900, height: 150))
        suite.expect(logo.size == CGSize(width: 640, height: 320) && logo.text == nil
                        && logo.logo == CGRect(x: 0, y: 0, width: 640, height: 320),
                     "a logo alone is unit tall at its own aspect, and ignores the text")
        let both = Support.block(unit: 320, content: .both, logoAspect: 1, textSize: CGSize(width: 900, height: 150))
        suite.expect(both.size == CGSize(width: 320 + 96 + 900, height: 320),
                     "logo, gap and text sit on one line, got \(both.size)")
        suite.expect(both.text?.minX == 416 && both.text?.midY == 160 && both.logo?.midY == 160,
                     "the text follows the logo, both centred on the line")
        let text = Support.block(unit: 320, content: .text, logoAspect: 1, textSize: CGSize(width: 900, height: 150))
        suite.expect(text.size == CGSize(width: 900, height: 150) && text.logo == nil, "text alone is its own size")
        suite.expect(Support.block(unit: 320, content: .text, logoAspect: 1, textSize: nil).size == .zero,
                     "no text to draw, nothing laid out")
        suite.expect(Support.block(unit: 100, content: .logo, logoAspect: 500, textSize: nil).size.width == 1000,
                     "an extreme logo aspect is held to 10:1")
        suite.expect(Support.fontSize(unit: 100, content: .text) > Support.fontSize(unit: 100, content: .both),
                     "text alone is set larger than text beside a logo")

        let block = CGSize(width: 640, height: 320)
        func origin(_ position: NotchWatermarkPosition) -> CGPoint {
            Support.origin(canvas: canvas, block: block, position: position, margin: 120)
        }
        suite.expect(origin(.topLeft) == CGPoint(x: 120, y: 120), "top left sits the margin in")
        suite.expect(origin(.bottomRight) == CGPoint(x: 6000 - 640 - 120, y: 4000 - 320 - 120),
                     "bottom right sits the margin in from both edges")
        suite.expect(origin(.center) == CGPoint(x: 2680, y: 1840), "the centre is centred")
        suite.expect(origin(.top) == CGPoint(x: 2680, y: 120) && origin(.right) == CGPoint(x: 5240, y: 1840)
                        && origin(.bottomLeft) == CGPoint(x: 120, y: 3560),
                     "edges and corners take the margin only where they touch")
        suite.expect(NotchWatermarkPosition.allCases.map(\.row) == [0, 0, 0, 1, 1, 1, 2, 2, 2]
                        && NotchWatermarkPosition.allCases.map(\.column) == [0, 1, 2, 0, 1, 2, 0, 1, 2],
                     "the grid reads left to right, top to bottom")
        let tight = Support.origin(canvas: CGSize(width: 700, height: 400), block: block, position: .bottomRight,
                                   margin: 120)
        suite.expect(tight == CGPoint(x: 30, y: 40),
                     "a margin larger than the room left shrinks to keep the mark inside, got \(tight)")
        let wide = Support.origin(canvas: CGSize(width: 500, height: 400), block: block, position: .topLeft, margin: 20)
        suite.expect(wide.x == -70, "a mark wider than the picture is centred across it")
    }

    // MARK: Tile pattern

    private static func tiles(_ suite: TestSuite) {
        let canvas = CGSize(width: 3000, height: 2000)
        let block = CGSize(width: 600, height: 200)
        let unit: CGFloat = 200
        let centres = Support.tileCenters(canvas: canvas, block: block, unit: unit)
        let step = Support.tileSteps(block: block, unit: unit)
        suite.expect(centres.count > 4, "the pattern repeats, got \(centres.count) copies")
        suite.expect(centres.contains { hypot($0.x - 1500, $0.y - 1000) < 0.001 }, "one copy sits at the centre")
        let radius = hypot(block.width, block.height) / 2
        suite.expect(centres.allSatisfy { $0.x > -radius && $0.x < canvas.width + radius
                                            && $0.y > -radius && $0.y < canvas.height + radius },
                     "every copy can touch the picture")
        // The copy one step along the centre's row rises to the right at 30°.
        let angle = -Support.tileAngle * .pi / 180
        let next = CGPoint(x: 1500 + step.width * cos(angle), y: 1000 + step.width * sin(angle))
        suite.expect(centres.contains { hypot($0.x - next.x, $0.y - next.y) < 0.001 },
                     "rows rise to the right at \(Support.tileAngle)°")
        suite.expect(next.y < 1000 && next.x > 1500, "up and to the right on screen")
        // Every part of the picture is near a copy: no bare corner.
        let reach = hypot(step.width, step.height)
        let samples = stride(from: 0.0, through: 3000.0, by: 250.0).flatMap { x in
            stride(from: 0.0, through: 2000.0, by: 250.0).map { CGPoint(x: x, y: $0) }
        }
        suite.expect(samples.allSatisfy { point in centres.contains { hypot($0.x - point.x, $0.y - point.y) <= reach } },
                     "the pattern covers the whole picture, corners included")
        let unique = Set(centres.map { "\(Int($0.x.rounded())),\(Int($0.y.rounded()))" })
        suite.expect(unique.count == centres.count, "no copy is drawn twice")
        suite.expect(Support.tileCenters(canvas: .zero, block: block, unit: unit).isEmpty
                        && Support.tileCenters(canvas: canvas, block: .zero, unit: unit).isEmpty,
                     "nothing to tile, no copies")
        suite.expect(step.width > block.width && step.height > block.height, "copies keep room between them")
    }

    // MARK: Auto contrast

    private static func contrast(_ suite: TestSuite) {
        suite.expectClose(Support.relativeLuminance(red: 1, green: 1, blue: 1), 1, "white is fully luminous")
        suite.expectClose(Support.relativeLuminance(red: 0, green: 0, blue: 0), 0, "black has no luminance")
        suite.expect(Support.tone(luminance: 0.9) == .dark && Support.tone(luminance: 0.02) == .light,
                     "a light backdrop gets a black mark, a dark one a white mark")
        let grey = Support.relativeLuminance(red: 0.5, green: 0.5, blue: 0.5)
        suite.expect(Support.tone(luminance: grey) == .dark, "mid grey reads better with black (WCAG crossover)")
        let navy = Support.relativeLuminance(red: 0.1, green: 0.15, blue: 0.35)
        suite.expect(Support.tone(luminance: navy) == .light, "navy takes white")

        // A picture white on top, black below: each region reads its own half.
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let split = halves(width: 200, height: 200, space: srgb, top: [1, 1, 1, 1], bottom: [0, 0, 0, 1])
        let top = NotchWatermarkRenderer.luminance(of: split, in: CGRect(x: 20, y: 20, width: 60, height: 40)) ?? -1
        let bottom = NotchWatermarkRenderer.luminance(of: split, in: CGRect(x: 120, y: 140, width: 60, height: 40)) ?? -1
        suite.expect(top > 0.9 && bottom < 0.05, "a region's luminance comes from under it, got \(top) / \(bottom)")
        suite.expect(NotchWatermarkRenderer.luminance(of: split, in: CGRect(x: 400, y: 400, width: 10, height: 10)) == nil,
                     "a region off the picture reads nothing")
        let style = NotchWatermarkStyle()
        let onWhite = NotchWatermarkRenderer.color(for: style, autoTone: .dark)
        suite.expect(NotchWatermarkRenderer.luminance(of: onWhite) < 0.01, "Auto on white is black")
        suite.expect(NotchWatermarkRenderer.luminance(of: NotchWatermarkRenderer.color(for: style, autoTone: .light)) > 0.99,
                     "Auto on black is white")
        var fixed = style
        fixed.color = .white
        suite.expect(NotchWatermarkRenderer.luminance(of: NotchWatermarkRenderer.color(for: fixed, autoTone: .dark)) > 0.99,
                     "a fixed white stays white on white")
        fixed.color = .custom
        fixed.customColor = "#FF0000"
        let red = NotchWatermarkRenderer.color(for: fixed, autoTone: .dark)
        suite.expectClose(NotchWatermarkRenderer.luminance(of: red), 0.2126, "the custom colour is drawn as given",
                          tol: 0.01)
        suite.expect(Support.rgb(hex: "#0A0A0A")?.red == 10.0 / 255 && Support.rgb(hex: "nope") == nil
                        && Support.hex(red: 1, green: 0.5, blue: 0) == "#FF8000",
                     "colours read and write as #RRGGBB")
    }

    // MARK: Styles

    private static func styles(_ suite: TestSuite) {
        var style = NotchWatermarkStyle(content: .both, logoFile: "logo-abc.png", text: "© Studio", weight: .bold,
                                        position: .topRight, margin: 5, scale: 12, opacity: 0.5, color: .custom,
                                        customColor: "#112233", shadow: false, tiled: true)
        suite.expect(NotchWatermarkStyle.decoded(style.encoded()) == style, "a style survives a round trip")
        suite.expect(style.encoded() == style.encoded(), "the same style always writes the same text")
        suite.expect(NotchWatermarkStyle.decoded(nil) == NotchWatermarkStyle()
                        && NotchWatermarkStyle.decoded("not json") == NotchWatermarkStyle(),
                     "nothing stored, or garbage, reads as the default")
        let partial = NotchWatermarkStyle.decoded(#"{"position":2,"scale":500,"opacity":-1,"text":"A\nB","shape":"x"}"#)
        suite.expect(partial.position == .topRight && partial.scale == 30 && partial.opacity == 0.1
                        && partial.text == "A B" && partial.content == .logo && partial.shadow,
                     "a partial or out-of-range style keeps what it has, clamped, defaults for the rest")
        style.logoFile = "../../etc/passwd.png"
        suite.expect(style.sanitized().logoFile == nil, "a logo name that could leave its folder is dropped")
        style.customColor = "red"
        suite.expect(style.sanitized().customColor == "#FFFFFF", "a colour that does not parse falls back to white")
        style.text = String(repeating: "x", count: 200)
        suite.expect(style.sanitized().text.count == NotchWatermarkStyle.textLimit, "the text is held to one short line")
        var empty = NotchWatermarkStyle(content: .text, text: "  ")
        suite.expect(!empty.sanitized().drawsSomething, "text alone with no words draws nothing")
        empty.content = .both
        suite.expect(empty.sanitized().drawsSomething, "the logo still draws beside empty text")

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        suite.expect(Support.style(in: defaults) == NotchWatermarkStyle(), "an unset style reads as the default")
        let saved = NotchWatermarkStyle(content: .text, text: "© Satu Visual 2026", position: .bottom)
        Support.saveStyle(saved, in: defaults)
        suite.expect(Support.style(in: defaults) == saved, "the style is saved and read back")
    }

    // MARK: Presets

    private static func presets(_ suite: TestSuite) {
        let starters = Support.decodedPresets(nil, language: .enUS)
        suite.expect(starters.map(\.id) == ["client-proof", "instagram"]
                        && starters.map(\.name) == ["Client proof", "Instagram"],
                     "never saved, the two starters are offered")
        suite.expect(starters[0].style.tiled && starters[0].style.content == .both && !starters[1].style.tiled,
                     "the proof tiles the picture, the posting preset marks a corner")
        suite.expect(Support.decodedPresets("", language: .de).first?.name == "Kundenvorschau",
                     "the starters speak the app’s language")
        suite.expect(Support.decodedPresets("[]", language: .enUS).isEmpty, "a list emptied on purpose stays empty")
        suite.expect(Support.decodedPresets("{oops", language: .enUS).isEmpty, "a broken list is not trusted")

        var counter = 0
        func id() -> String { counter += 1; return "id-\(counter)" }
        let proof = NotchWatermarkStyle(content: .both, opacity: 0.3, tiled: true)
        var saved = Support.saving(proof, named: "  Client\nproof  ", to: [], id: id)
        suite.expect(saved.presets.count == 1 && saved.presets[0].name == "Client proof" && saved.id == "id-1",
                     "a preset is saved under its trimmed one-line name")
        let insta = NotchWatermarkStyle(position: .bottomRight, scale: 5)
        saved = Support.saving(insta, named: "Instagram", to: saved.presets, id: id)
        suite.expect(saved.presets.map(\.name) == ["Client proof", "Instagram"], "a new name goes last")
        let changed = NotchWatermarkStyle(position: .bottomLeft, scale: 6)
        saved = Support.saving(changed, named: "instagram", to: saved.presets, id: id)
        suite.expect(saved.presets.count == 2 && saved.presets[1].style == changed && saved.id == "id-2"
                        && saved.presets[1].name == "instagram",
                     "the same name in any case replaces its preset in place, as last typed")
        suite.expect(Support.saving(proof, named: "   ", to: saved.presets).id == nil, "a blank name saves nothing")
        let full = (0..<Support.presetLimit).map { NotchWatermarkPreset(id: "p\($0)", name: "P\($0)", style: proof) }
        suite.expect(Support.saving(proof, named: "One more", to: full).id == nil
                        && Support.saving(changed, named: "P3", to: full).id == "p3",
                     "a full list refuses a new name but still updates an old one")
        suite.expect(Support.presetName(String(repeating: "n", count: 90))?.count == Support.presetNameLimit,
                     "a long name is cut")

        let encoded = Support.encodedPresets(saved.presets)
        let decoded = Support.decodedPresets(encoded, language: .enUS)
        suite.expect(decoded == saved.presets, "presets survive a round trip")
        suite.expect(Support.matchingPreset(changed, in: decoded)?.id == "id-2"
                        && Support.matchingPreset(NotchWatermarkStyle(scale: 21), in: decoded) == nil,
                     "an unchanged style is recognised as its preset, an edited one is not")
        let doubled = Support.encodedPresets(saved.presets + [saved.presets[0]])
        suite.expect(Support.decodedPresets(doubled, language: .enUS).count == 2, "a repeated id is read once")

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        suite.expect(Support.presets(in: defaults, language: .enUS).count == 2 && Support.defaultPresetID(in: defaults) == nil,
                     "a fresh Mac has the starters and no default preset")
        Support.savePresets(saved.presets, in: defaults)
        defaults.set("id-2", forKey: DefaultsKey.notchWatermarkDefaultPreset)
        suite.expect(Support.presets(in: defaults, language: .enUS) == saved.presets
                        && Support.defaultPresetID(in: defaults) == "id-2",
                     "saved presets and the default preset are read back")
        Support.savePresets([], in: defaults)
        suite.expect(Support.presets(in: defaults, language: .enUS).isEmpty, "deleting every preset leaves none")
    }

    // MARK: Backups

    private static func backups(_ suite: TestSuite) {
        let keys = [DefaultsKey.notchWatermarkStyle, DefaultsKey.notchWatermarkPresets,
                    DefaultsKey.notchWatermarkDefaultPreset]
        let exported = SettingsBackupSupport.exportKeys()
        for key in keys {
            suite.expect(Defaults.registeredDefaults[key] as? String == "", "\(key) is registered as text")
            suite.expect(exported.contains(key), "\(key) travels in settings backups")
            suite.expect(SettingsBackupSupport.valueLooksRight(key, "[]")
                            && !SettingsBackupSupport.valueLooksRight(key, 3),
                         "a restored \(key) must be text")
        }
        let preset = NotchWatermarkPreset(id: "x", name: "Proof", style: NotchWatermarkStyle(tiled: true))
        let restored = Support.decodedPresets(Support.encodedPresets([preset]), language: .enUS)
        suite.expect(restored == [preset], "a backed-up preset restores as it was")
    }

    // MARK: Logos

    private static func logos(_ suite: TestSuite) {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-watermark-container-\(UUID().uuidString)", isDirectory: true)
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-watermark-source-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: container)
            try? FileManager.default.removeItem(at: scratch)
        }
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let png = scratch.appendingPathComponent("Studio Logo.png")
        write(solid(width: 300, height: 100, space: srgb, alpha: true, color: [1, 1, 1, 1]), type: UTType.png.identifier,
              to: png, properties: [:])

        let name = NotchWatermarkLogoStore.importLogo(from: png, container: container, id: "ABC")
        suite.expect(name == "logo-abc.png", "a logo is copied under a safe name, got \(name ?? "nil")")
        let copy = NotchWatermarkLogoStore.url(for: "logo-abc.png", container: container)
        suite.expect(copy?.deletingLastPathComponent().lastPathComponent == NotchWatermarkLogoStore.folderName
                        && copy.map { FileManager.default.fileExists(atPath: $0.path) } == true,
                     "the copy lives in the container's Watermarks folder")
        let mode = copy.flatMap { (try? FileManager.default.attributesOfItem(atPath: $0.path))?[.posixPermissions] as? Int }
        suite.expect(mode == 0o600, "the copy is the owner’s alone")
        suite.expect(NotchWatermarkLogoStore.exists("logo-abc.png", container: container)
                        && !NotchWatermarkLogoStore.exists("logo-missing.png", container: container),
                     "the store knows which logos it has")
        let logo = NotchWatermarkLogo.load("logo-abc.png", container: container)
        suite.expect(!logo.isStar && abs(logo.aspect - 3) < 0.001, "a stored logo loads at its own aspect")
        suite.expect(NotchWatermarkLogo.load("logo-missing.png", container: container).isStar
                        && NotchWatermarkLogo.load(nil, container: container).isStar,
                     "a missing logo falls back to the star")
        suite.expect(NotchWatermarkLogo.star.aspect == 1, "the star is square")

        let text = scratch.appendingPathComponent("notes.txt")
        try? Data("hi".utf8).write(to: text)
        suite.expect(NotchWatermarkLogoStore.importLogo(from: text, container: container) == nil,
                     "only pictures become logos")
        for bad in ["../logo.png", "logo.txt", ".hidden.png", "a/b.png", ""] {
            suite.expect(!NotchWatermarkLogoStore.isValidName(bad), "\(bad.isEmpty ? "an empty name" : bad) is refused")
        }

        _ = NotchWatermarkLogoStore.importLogo(from: png, container: container, id: "old")
        NotchWatermarkLogoStore.prune(keeping: ["logo-abc.png"], container: container)
        suite.expect(NotchWatermarkLogoStore.exists("logo-abc.png", container: container)
                        && !NotchWatermarkLogoStore.exists("logo-old.png", container: container),
                     "logos nothing uses are removed, the rest kept")

        // A vector logo: a PDF page drawn at the size it lands at.
        let pdf = scratch.appendingPathComponent("mark.pdf")
        var box = CGRect(x: 0, y: 0, width: 200, height: 100)
        if let context = CGContext(pdf as CFURL, mediaBox: &box, nil) {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(box)
            context.endPDFPage()
            context.closePDF()
        }
        let vector = NotchWatermarkLogo.load(url: pdf)
        suite.expect(vector.map { abs($0.aspect - 2) < 0.001 } == true, "a PDF logo loads at its page's aspect")
    }

    // MARK: Rendering

    private static func rendering(_ suite: TestSuite) {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        // The star at the centre, opaque, no shadow: its left arm reads dark
        // on white and light on black.
        var style = NotchWatermarkStyle(position: .center, margin: 0, scale: 30, opacity: 1, shadow: false)
        let white = solid(width: 400, height: 400, space: p3, alpha: false, color: [1, 1, 1, 1])
        let black = solid(width: 400, height: 400, space: p3, alpha: false, color: [0, 0, 0, 1])
        let unit = Support.unit(canvas: CGSize(width: 400, height: 400), scale: 30)
        let arm = CGPoint(x: 200 - unit / 2 + unit * 0.12, y: 200)
        if let marked = NotchWatermarkRenderer.watermarked(white, style: style, logo: .star) {
            suite.expect(marked.colorSpace?.name == CGColorSpace.displayP3, "the picture keeps Display P3")
            suite.expect(marked.width == 400 && marked.height == 400 && !NotchPhotoEncoder.hasAlpha(marked),
                         "the picture keeps its size and gains no alpha")
            suite.expect(pixel(marked, at: arm).red < 30, "Auto draws black on white")
            suite.expect(pixel(marked, at: CGPoint(x: 20, y: 20)).red > 250, "the rest of the picture is untouched")
        } else {
            suite.expect(false, "a watermark is drawn")
        }
        if let marked = NotchWatermarkRenderer.watermarked(black, style: style, logo: .star) {
            suite.expect(pixel(marked, at: arm).red > 225, "Auto draws white on black")
        }
        // Half opacity lands between the two.
        style.opacity = 0.5
        if let marked = NotchWatermarkRenderer.watermarked(black, style: style, logo: .star) {
            let value = pixel(marked, at: arm).red
            suite.expect((100...160).contains(value), "opacity is honoured, got \(value)")
        }
        // A fixed colour wins over Auto.
        style.opacity = 1
        style.color = .white
        if let marked = NotchWatermarkRenderer.watermarked(white, style: style, logo: .star) {
            suite.expect(pixel(marked, at: arm).red > 250, "a fixed white is drawn even on white")
        }

        // Text alone, and a transparent overlay for the preview.
        let text = NotchWatermarkStyle(content: .text, text: "© Satu Visual", position: .center, scale: 20, opacity: 1,
                                       color: .black, shadow: false)
        let wide = solid(width: 800, height: 400, space: srgb, alpha: false, color: [1, 1, 1, 1])
        if let marked = NotchWatermarkRenderer.watermarked(wide, style: text, logo: .star) {
            suite.expect(darkPixels(marked) > 400, "the text is drawn")
        }
        if let overlay = NotchWatermarkRenderer.overlay(for: wide, style: text, logo: .star) {
            suite.expect(overlay.width == 800 && overlay.height == 400 && NotchPhotoEncoder.hasAlpha(overlay),
                         "the preview's overlay is the picture's size, over transparency")
            suite.expect(pixel(overlay, at: CGPoint(x: 5, y: 5)).alpha == 0 && opaquePixels(overlay) > 400,
                         "the overlay holds the mark and nothing else")
        }

        // The tile pattern marks the picture all over.
        let tiled = NotchWatermarkStyle(content: .logo, scale: 8, opacity: 1, color: .black, shadow: false, tiled: true)
        if let marked = NotchWatermarkRenderer.watermarked(wide, style: tiled, logo: .star) {
            let quadrants = [CGRect(x: 0, y: 0, width: 400, height: 200), CGRect(x: 400, y: 0, width: 400, height: 200),
                             CGRect(x: 0, y: 200, width: 400, height: 200), CGRect(x: 400, y: 200, width: 400, height: 200)]
            suite.expect(quadrants.allSatisfy { darkPixels(marked, in: $0) > 50 }, "the pattern reaches every quarter")
        }

        // A transparent PNG keeps its alpha under the mark.
        let clear = solid(width: 200, height: 200, space: srgb, alpha: true, color: [0, 0, 0, 0])
        if let marked = NotchWatermarkRenderer.watermarked(clear, style: NotchWatermarkStyle(), logo: .star) {
            suite.expect(NotchPhotoEncoder.hasAlpha(marked) && pixel(marked, at: CGPoint(x: 5, y: 5)).alpha == 0,
                         "transparency stays transparent")
        }
    }

    // MARK: End to end

    private static func endToEnd(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-watermark-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!

        // A Display P3 JPEG stored sideways, with a lens and a location.
        let source = folder.appendingPathComponent("photo.jpg")
        let written = write(solid(width: 600, height: 400, space: p3, alpha: false, color: [1, 1, 1, 1]),
                            type: UTType.jpeg.identifier, to: source, properties: [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "Zenith Test Lens"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 6.2, kCGImagePropertyGPSLatitudeRef: "S"],
        ])
        suite.expect(written, "the fixture is written")
        let original = try? Data(contentsOf: source)
        var reserved = Set<String>()
        var recipe = NotchPhotoRecipe(kind: .watermark)
        recipe.watermark = NotchWatermarkStyle(position: .bottomRight, margin: 3, scale: 10, opacity: 1, shadow: false)
        var stages: [Double] = []
        let marked = try? NotchPhotoEncoder.transform(source, recipe: recipe, directory: folder, reserved: &reserved,
                                                      stage: { stages.append($0) })
        suite.expect(marked?.url.lastPathComponent == "photo-wm.jpg", "the output is named -wm beside the original")
        if let url = marked?.url {
            let info = read(url)
            suite.expect(info.width == 400 && info.height == 600 && info.orientation == 1,
                         "the sideways photo is written upright at full size, got \(info.width)×\(info.height)")
            suite.expect(info.profile == "Display P3", "Display P3 survives, got \(info.profile ?? "none")")
            suite.expect(info.lens == "Zenith Test Lens" && info.hasGPS, "the watermark keeps EXIF and GPS")
            // The star sits in the bottom-right corner of the upright picture.
            let canvas = CGSize(width: 400, height: 600)
            let unit = Support.unit(canvas: canvas, scale: 10)
            let margin = Support.margin(canvas: canvas, margin: 3)
            let corner = Support.origin(canvas: canvas, block: CGSize(width: unit, height: unit), position: .bottomRight,
                                        margin: margin)
            if let image = decode(url) {
                let arm = CGPoint(x: corner.x + unit * 0.12, y: corner.y + unit / 2)
                suite.expect(pixel(image, at: arm).red < 60, "the mark is in the output where it was placed")
                suite.expect(pixel(image, at: CGPoint(x: 20, y: 20)).red > 240, "the rest is untouched")
            }
        }
        suite.expect(stages.contains(0.7) && stages == stages.sorted(), "the watermark reports its own stage")
        suite.expect((try? Data(contentsOf: source)) == original, "the original is never touched")

        // Again: never overwrites, takes the next name.
        let again = try? NotchPhotoEncoder.transform(source, recipe: recipe, directory: folder, reserved: &reserved)
        suite.expect(again?.url.lastPathComponent == "photo-wm-1.jpg", "a second run takes the next name")

        // Resize, watermark and strip in one pass.
        let wide = folder.appendingPathComponent("wide.jpg")
        _ = write(solid(width: 1600, height: 900, space: p3, alpha: false, color: [0, 0, 0, 1]),
                  type: UTType.jpeg.identifier, to: wide, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.5, kCGImagePropertyGPSLatitudeRef: "S"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifLensModel: "Zenith Test Lens"],
        ])
        var combined = NotchPhotoRecipe(kind: .resize, longEdge: .hd)
        combined.alsoStrips = true
        combined.watermark = NotchWatermarkStyle(content: .logo, position: .topLeft, scale: 10, opacity: 1, shadow: false)
        let resized = try? NotchPhotoEncoder.transform(wide, recipe: combined, directory: folder, reserved: &reserved)
        suite.expect(resized?.url.lastPathComponent == "wide-1080-wm.jpg", "the name carries both steps")
        if let url = resized?.url {
            let info = read(url)
            suite.expect(info.width == 1080 && (607...608).contains(info.height), "resized first, got \(info.width)×\(info.height)")
            suite.expect(!info.hasGPS && info.lens == nil, "stripped as asked")
            suite.expect(info.profile == "Display P3", "the profile is kept")
            if let image = decode(url) {
                let canvas = CGSize(width: image.width, height: image.height)
                let unit = Support.unit(canvas: canvas, scale: 10)
                let margin = Support.margin(canvas: canvas, margin: 3)
                let arm = CGPoint(x: margin + unit * 0.12, y: margin + unit / 2)
                suite.expect(pixel(image, at: arm).red > 200, "the mark is drawn at the output's size, white on black")
            }
        }

        // Strip with the watermark re-encodes: the mark is there.
        let png = folder.appendingPathComponent("flat.png")
        _ = write(solid(width: 300, height: 300, space: p3, alpha: true, color: [1, 1, 1, 1]),
                  type: UTType.png.identifier, to: png, properties: [:])
        var strip = NotchPhotoRecipe(kind: .strip)
        strip.watermark = NotchWatermarkStyle(position: .center, scale: 30, opacity: 1, shadow: false)
        let cleaned = try? NotchPhotoEncoder.transform(png, recipe: strip, directory: folder, reserved: &reserved)
        suite.expect(cleaned?.url.lastPathComponent == "flat-clean-wm.png", "Strip with the watermark names both")
        if let url = cleaned?.url, let image = decode(url) {
            let unit = Support.unit(canvas: CGSize(width: 300, height: 300), scale: 30)
            suite.expect(read(url).type == UTType.png.identifier && read(url).profile == "Display P3",
                         "a PNG stays a P3 PNG")
            suite.expect(pixel(image, at: CGPoint(x: 150 - unit / 2 + unit * 0.12, y: 150)).red < 30,
                         "the strip did not copy the picture past the watermark")
        }
    }

    // MARK: Fixtures

    private static func solid(width: Int, height: Int, space: CGColorSpace, alpha: Bool, color: [CGFloat]) -> CGImage {
        let info = alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: info.rawValue)!
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(colorSpace: space, components: color)!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// `top` over the upper half, `bottom` over the lower (as seen).
    private static func halves(width: Int, height: Int, space: CGColorSpace, top: [CGFloat], bottom: [CGFloat]) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(colorSpace: space, components: bottom)!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(CGColor(colorSpace: space, components: top)!)
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
        return context.makeImage()!
    }

    @discardableResult
    private static func write(_ image: CGImage, type: String, to url: URL, properties: [CFString: Any]) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private static func decode(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private struct Info {
        var type: String?
        var width = 0
        var height = 0
        var orientation = 1
        var profile: String?
        var lens: String?
        var hasGPS = false
    }

    private static func read(_ url: URL) -> Info {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return Info() }
        var info = Info()
        info.type = CGImageSourceGetType(source) as String?
        info.width = (properties[kCGImagePropertyPixelWidth] as? Int) ?? 0
        info.height = (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0
        info.orientation = (properties[kCGImagePropertyOrientation] as? Int) ?? 1
        info.profile = properties[kCGImagePropertyProfileName] as? String
        info.lens = (properties[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifLensModel] as? String
        info.hasGPS = properties[kCGImagePropertyGPSDictionary] != nil
        return info
    }

    private struct Pixel {
        var red = 0
        var alpha = 0
    }

    /// The picture as sRGB bytes, rows from the top.
    private static func bytes(_ image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    /// One pixel, `point` from the top left.
    private static func pixel(_ image: CGImage, at point: CGPoint) -> Pixel {
        let x = min(image.width - 1, max(0, Int(point.x))), y = min(image.height - 1, max(0, Int(point.y)))
        let pixels = bytes(image)
        let index = (y * image.width + x) * 4
        return Pixel(red: Int(pixels[index]), alpha: Int(pixels[index + 3]))
    }

    private static func darkPixels(_ image: CGImage, in rect: CGRect? = nil) -> Int {
        let pixels = bytes(image)
        let area = rect ?? CGRect(x: 0, y: 0, width: image.width, height: image.height)
        var count = 0
        for y in Int(area.minY)..<min(image.height, Int(area.maxY)) {
            for x in Int(area.minX)..<min(image.width, Int(area.maxX)) where pixels[(y * image.width + x) * 4] < 100 {
                count += 1
            }
        }
        return count
    }

    private static func opaquePixels(_ image: CGImage) -> Int {
        let pixels = bytes(image)
        return stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] > 128 }.count
    }
}
