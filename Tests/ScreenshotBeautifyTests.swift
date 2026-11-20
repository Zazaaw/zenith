// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: Beautify. The layout (padding, aspect fit, the window frame's
/// bar, the caption, the size cap), the stored style and its gradients, the
/// named presets in their own defaults suite and in backups, the
/// `-beautified` names, and end-to-end renders of a small generated shot
/// (canvas size, alpha for a clear background, PNG and JPEG files).
enum ScreenshotBeautifyTests {
    private typealias Style = ScreenshotBeautifyStyle
    private typealias Layout = ScreenshotBeautifyLayout

    static func run(_ suite: TestSuite) {
        padding(suite)
        aspect(suite)
        frameBar(suite)
        caption(suite)
        limits(suite)
        styleEncoding(suite)
        gradients(suite)
        presets(suite)
        persistence(suite)
        naming(suite)
        render(suite)
        files(suite)
        strings(suite)
    }

    private static func style(_ change: (inout Style) -> Void = { _ in }) -> Style {
        var style = Style()
        style.padding = 0
        style.cornerRadius = 0
        style.shadow = .none
        change(&style)
        return style
    }

    // MARK: Layout

    private static func padding(_ suite: TestSuite) {
        let square = Layout.make(shotPixels: CGSize(width: 1000, height: 1000), scale: 1,
                                 style: style { $0.padding = 0.1 })
        suite.expect(square.canvas == CGSize(width: 1200, height: 1200)
                        && square.shot == CGRect(x: 100, y: 100, width: 1000, height: 1000),
                     "10% padding around a 1000 px square adds 100 px on every side")
        let strip = Layout.make(shotPixels: CGSize(width: 1600, height: 400), scale: 1,
                                style: style { $0.padding = 0.1 })
        suite.expect(strip.canvas == CGSize(width: 1760, height: 560),
                     "padding follows the shot's overall size, so a wide strip gets a sensible margin")
        let none = Layout.make(shotPixels: CGSize(width: 640, height: 480), scale: 2, style: style())
        suite.expect(none.canvas == CGSize(width: 640, height: 480) && none.shot.origin == .zero
                        && none.contentScale == 1,
                     "no padding at Auto keeps the shot's own pixels")
        let clamped = Layout.make(shotPixels: CGSize(width: 1000, height: 1000), scale: 1,
                                  style: style { $0.padding = 4 })
        suite.expect(clamped.canvas.width == 1600, "padding stops at 30%")
    }

    private static func aspect(_ suite: TestSuite) {
        let wide = Layout.make(shotPixels: CGSize(width: 1000, height: 1000), scale: 1,
                               style: style { $0.aspect = .wide })
        suite.expect(wide.canvas == CGSize(width: 1778, height: 1000) && wide.shot.minX == 389
                        && wide.shot.minY == 0,
                     "16:9 widens a square shot and centres it")
        let square = Layout.make(shotPixels: CGSize(width: 1600, height: 400), scale: 1,
                                 style: style { $0.padding = 0.1; $0.aspect = .square })
        suite.expect(square.canvas == CGSize(width: 1760, height: 1760) && square.shot.minY == 680
                        && square.shot.width == 1600,
                     "1:1 grows the short side and keeps the shot at full size in the middle")
        for aspect in Style.Aspect.allCases {
            guard let ratio = aspect.ratio else { continue }
            for shot in [CGSize(width: 2880, height: 1800), CGSize(width: 1170, height: 2532), CGSize(width: 900, height: 900)] {
                let layout = Layout.make(shotPixels: shot, scale: 2, style: style { $0.padding = 0.06; $0.aspect = aspect })
                let measured = layout.canvas.width / layout.canvas.height
                suite.expect(abs(measured - ratio) < 0.002
                                && layout.canvas.width >= layout.shot.width && layout.canvas.height >= layout.shot.height
                                && abs(layout.shot.midX - layout.canvas.width / 2) <= 1,
                             "\(aspect.label) holds its ratio for a \(Int(shot.width))×\(Int(shot.height)) shot, centred")
            }
        }
        suite.expect(Style.Aspect.portrait.ratio == 0.8 && Style.Aspect.story.ratio == 9.0 / 16.0
                        && Style.Aspect.auto.ratio == nil,
                     "4:5 is the Instagram portrait and 9:16 the story")
    }

    private static func frameBar(_ suite: TestSuite) {
        let framed = Layout.make(shotPixels: CGSize(width: 1000, height: 600), scale: 2,
                                 style: style { $0.frame = .light; $0.padding = 0.05 })
        suite.expect(framed.bar?.height == 56 && framed.card.height == 656
                        && framed.shot.minY == framed.card.minY + 56 && framed.bar?.minY == framed.card.minY,
                     "the title bar is 28 pt on top of the shot")
        let lights = framed.lightCenters(scale: 2)
        suite.expect(lights.count == 3 && lights[0].x == framed.card.minX + 40 && lights[2].x == framed.card.minX + 120
                        && lights.allSatisfy { $0.y == framed.bar!.midY },
                     "three traffic lights, 20 pt apart, centred in the bar")
        let oneX = Layout.make(shotPixels: CGSize(width: 1000, height: 600), scale: 1, style: style { $0.frame = .dark })
        suite.expect(oneX.bar?.height == 28, "a 1x capture gets a 28 px bar")
        let plain = Layout.make(shotPixels: CGSize(width: 1000, height: 600), scale: 2, style: style())
        suite.expect(plain.bar == nil && plain.lightCenters(scale: 2).isEmpty && plain.card == plain.shot,
                     "no frame, no bar")
    }

    private static func caption(_ suite: TestSuite) {
        let shot = CGSize(width: 1000, height: 500)
        let without = Layout.make(shotPixels: shot, scale: 2, style: style { $0.padding = 0.1 })
        let with = Layout.make(shotPixels: shot, scale: 2, style: style { $0.padding = 0.1; $0.caption = "Dashboard, dark" })
        guard let caption = with.caption else {
            suite.expect(false, "a caption gets a line")
            return
        }
        suite.expect(with.captionFontSize == 26 && caption.height == 35 && caption.minY == with.card.maxY + 29,
                     "the caption is small (13 pt at 2x), one line under the shot")
        suite.expect(with.canvas.height == without.canvas.height + 29 + 35 && with.canvas.width == without.canvas.width
                        && caption.maxY <= with.canvas.height - 70,
                     "the canvas grows by the caption and keeps its padding below it")
        suite.expect(with.card.minY < without.card.minY + 1 && abs(caption.midX - with.card.midX) < 0.5,
                     "the shot and caption are centred as one block")
        let blank = Layout.make(shotPixels: shot, scale: 2, style: style { $0.caption = "   " })
        suite.expect(blank.caption == nil && blank.canvas == shot, "blank text is no caption")
        let flush = Layout.make(shotPixels: shot, scale: 2, style: style { $0.caption = "Hi" })
        suite.expect((flush.caption?.maxY ?? .infinity) + 26 <= flush.canvas.height + 0.5,
                     "with no padding the caption still keeps off the edge")
        let wideShot = Layout.make(shotPixels: CGSize(width: 4000, height: 1000), scale: 2, style: style { $0.caption = "Hi" })
        suite.expect(wideShot.captionFontSize == 72, "on a wide shot the caption scales with it")
        let square = Layout.make(shotPixels: shot, scale: 2, style: style { $0.caption = "Hi"; $0.aspect = .square })
        suite.expect(square.canvas.width == square.canvas.height, "an aspect counts the caption too")
    }

    private static func limits(_ suite: TestSuite) {
        let corner = Layout.make(shotPixels: CGSize(width: 40, height: 40), scale: 2, style: style { $0.cornerRadius = 48 })
        suite.expect(abs(corner.cornerRadius - 20 / Layout.continuousReach) < 0.001,
                     "the corner never outgrows a small shot")
        suite.expect(Layout.make(shotPixels: CGSize(width: 800, height: 600), scale: 2,
                                 style: style { $0.cornerRadius = 12 }).cornerRadius == 24,
                     "corners are in points")
        let huge = Layout.make(shotPixels: CGSize(width: 6000, height: 6000), scale: 2, style: style { $0.aspect = .story })
        suite.expect(max(huge.canvas.width, huge.canvas.height) == Layout.maximumSide && huge.contentScale < 1
                        && abs(huge.shot.width - 6000 * huge.contentScale) < 0.5
                        && abs(huge.canvas.width / huge.canvas.height - 9.0 / 16.0) < 0.002,
                     "a canvas past 8192 px scales down whole, ratio kept")
        let soft = Layout.make(shotPixels: CGSize(width: 1000, height: 1000), scale: 1, style: style { $0.shadow = .soft })
        let strong = Layout.make(shotPixels: CGSize(width: 1000, height: 1000), scale: 1, style: style { $0.shadow = .strong })
        suite.expect(Layout.make(shotPixels: CGSize(width: 10, height: 10), scale: 1, style: style()).shadow == nil
                        && (soft.shadow?.blur ?? 0) > 0 && (strong.shadow?.blur ?? 0) > (soft.shadow?.blur ?? 0)
                        && (strong.shadow?.alpha ?? 0) > (soft.shadow?.alpha ?? 0),
                     "shadow none, soft and strong step up")
        let path = ScreenshotBeautifyRenderer.continuousRoundedRect(CGRect(x: 10, y: 20, width: 300, height: 200), radius: 40)
        suite.expect(path.boundingBoxOfPath.insetBy(dx: -0.01, dy: -0.01).contains(CGRect(x: 10, y: 20, width: 300, height: 200))
                        && !path.contains(CGPoint(x: 11, y: 21)) && path.contains(CGPoint(x: 160, y: 120)),
                     "continuous corners stay in the rect and cut its corners")
    }

    // MARK: Style

    private static func styleEncoding(_ suite: TestSuite) {
        var custom = Style()
        custom.background = .solid
        custom.gradient = .sage
        custom.solid = "#1f2330"
        custom.padding = 0.2
        custom.cornerRadius = 20
        custom.shadow = .strong
        custom.frame = .dark
        custom.aspect = .portrait
        custom.caption = "Case study"
        custom.format = .jpeg
        let encoded = custom.encoded()
        let decoded = Style.decoded(encoded)
        suite.expect(decoded == custom.sanitized() && decoded.solid == "#1F2330",
                     "a style survives its JSON round trip, colour normalised")
        suite.expect(encoded.contains("\"gradient\":\"sage\"") && encoded.contains("\"aspect\":\"portrait\""),
                     "the gradient and aspect are stored by name")
        suite.expect(Style.decoded(nil) == Style() && Style.decoded("not json") == Style() && Style.decoded("") == Style(),
                     "nothing stored reads as the default style")
        let partial = Style.decoded(#"{"padding":0.2,"gradient":"neon","shadow":"huge","caption":"Hi"}"#)
        suite.expect(partial.padding == 0.2 && partial.gradient == .mist && partial.shadow == Style().shadow
                        && partial.caption == "Hi" && partial.background == .gradient,
                     "an unknown gradient or shadow falls back alone, the rest stays")
        let wild = Style.decoded(#"{"padding":5,"cornerRadius":-3,"solid":"zzz","caption":"a\nb"}"#)
        suite.expect(wild.padding == 0.3 && wild.cornerRadius == 0 && wild.solid == Style().solid && wild.caption == "a b",
                     "values out of range are pulled back and a caption stays on one line")
        var long = Style()
        long.caption = String(repeating: "x", count: 500)
        suite.expect(long.sanitized().caption.count == Style.captionLimit, "a caption is capped")
        var clear = Style()
        clear.background = .transparent
        clear.format = .jpeg
        suite.expect(!clear.isOpaque && clear.effectiveFormat == .png && custom.effectiveFormat == .jpeg,
                     "JPEG only for an opaque background; Clear always leaves as PNG")
    }

    private static func gradients(_ suite: TestSuite) {
        let all = ScreenshotBeautifyGradient.allCases
        suite.expect(all.count == 8 && Set(all.map(\.rawValue)).count == all.count
                        && all.allSatisfy { $0.stops.count >= 2 },
                     "eight gradients, each with at least two stops")
        suite.expect(ScreenshotBeautifyGradient.ink.luminance < 0.15 && ScreenshotBeautifyGradient.paper.luminance > 0.9,
                     "Satu Visual's monochromes: ink dark, paper light")
        suite.expect(all.filter { ![.ink, .paper, .dusk].contains($0) }.allSatisfy { $0.luminance > 0.6 },
                     "the colourful ones stay soft")
        for gradient in all {
            var style = Style()
            style.gradient = gradient
            suite.expect(Style.decoded(style.encoded()).gradient == gradient
                            && ScreenshotBeautifyGradient.stored(gradient.rawValue) == gradient,
                         "\(gradient.rawValue) round-trips")
        }
        suite.expect(ScreenshotBeautifyGradient.stored(nil) == .mist && ScreenshotBeautifyGradient.stored("x") == .mist,
                     "an unknown gradient reads as Mist")
        suite.expect(ScreenshotBeautifyColor(hex: "#FFFFFF")?.luminance == 1 && ScreenshotBeautifyColor(hex: "000000")?.hex == "#000000"
                        && ScreenshotBeautifyColor(hex: "#12345") == nil && ScreenshotBeautifyColor(hex: "#GGGGGG") == nil,
                     "hex colours parse strictly")
        suite.expect(ScreenshotBeautifySolids.swatches.allSatisfy { ScreenshotBeautifyColor(hex: $0) != nil },
                     "every solid swatch is a valid colour")
    }

    // MARK: Presets

    private static func presets(_ suite: TestSuite) {
        var dark = Style()
        dark.gradient = .ink
        var light = Style()
        light.gradient = .paper
        var list = ScreenshotBeautifyPresets.saving(dark, named: "  Instagram  ", to: [])
        list = ScreenshotBeautifyPresets.saving(light, named: "Portfolio", to: list)
        suite.expect(list.map(\.name) == ["Instagram", "Portfolio"], "presets keep their trimmed names in order")
        list = ScreenshotBeautifyPresets.saving(light, named: "instagram", to: list)
        suite.expect(list.count == 2 && list[0].name == "instagram" && list[0].style.gradient == .paper,
                     "saving under an existing name, any case, replaces it in place")
        suite.expect(ScreenshotBeautifyPresets.saving(dark, named: " \n ", to: list) == list, "an empty name saves nothing")
        var many: [ScreenshotBeautifyPreset] = []
        for index in 0..<20 { many = ScreenshotBeautifyPresets.saving(dark, named: "P\(index)", to: many) }
        suite.expect(many.count == ScreenshotBeautifyPresets.limit && many.first?.name == "P8" && many.last?.name == "P19",
                     "past twelve the oldest falls off")
        suite.expect(ScreenshotBeautifyPresets.removing(named: "Portfolio", from: list).map(\.name) == ["instagram"],
                     "a preset is removed by name")
        let encoded = ScreenshotBeautifyPresets.encoded(list)
        suite.expect(ScreenshotBeautifyPresets.decoded(encoded) == list, "presets survive their JSON round trip")
        let lossy = #"[{"name":"Good","style":{"gradient":"sky"}},{"name":7},{"name":"good","style":{}},{"name":"","style":{}}]"#
        let decoded = ScreenshotBeautifyPresets.decoded(lossy)
        suite.expect(decoded.count == 1 && decoded[0].name == "Good" && decoded[0].style.gradient == .sky,
                     "broken, duplicate and nameless entries are skipped without losing the rest")
        suite.expect(ScreenshotBeautifyPresets.decoded(nil).isEmpty && ScreenshotBeautifyPresets.decoded("{").isEmpty,
                     "nothing stored is no presets")
        let longName = ScreenshotBeautifyPresets.cleanName(String(repeating: "n", count: 90))
        suite.expect(longName.count == ScreenshotBeautifyPresets.nameLimit, "names are capped")
    }

    private static func persistence(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.screenshot-beautify"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "the test defaults suite opens")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.register(defaults: Defaults.registeredDefaults)

        suite.expect(ScreenshotBeautifyStore.lastStyle(defaults) == Style()
                        && ScreenshotBeautifyStore.presets(defaults).isEmpty
                        && !ScreenshotBeautifyStore.beautifiesAfterCapture(defaults),
                     "a fresh Mac starts with the default style, no presets and Beautify after capture off")
        var style = Style()
        style.aspect = .story
        style.caption = "Launch"
        ScreenshotBeautifyStore.saveLastStyle(style, defaults)
        suite.expect(ScreenshotBeautifyStore.lastStyle(defaults) == style, "the last style is remembered")
        let presets = ScreenshotBeautifyPresets.saving(style, named: "Story", to: [])
        ScreenshotBeautifyStore.savePresets(presets, defaults)
        suite.expect(ScreenshotBeautifyStore.presets(defaults) == presets, "named presets are remembered")
        defaults.set(true, forKey: DefaultsKey.screenshotBeautifyAfterCapture)
        suite.expect(ScreenshotBeautifyStore.beautifiesAfterCapture(defaults), "the after-capture switch reads back")

        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.screenshotBeautifyStyle] as? String == ""
                        && registered[DefaultsKey.screenshotBeautifyPresets] as? String == "[]"
                        && registered[DefaultsKey.screenshotBeautifyAfterCapture] as? Bool == false,
                     "Beautify's preferences are registered: style and presets as text, after capture off")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(exported.contains(DefaultsKey.screenshotBeautifyStyle)
                        && exported.contains(DefaultsKey.screenshotBeautifyPresets)
                        && exported.contains(DefaultsKey.screenshotBeautifyAfterCapture),
                     "backups carry the last style, the presets and the after-capture switch")
        suite.expect(SettingsBackupSupport.valueLooksRight(DefaultsKey.screenshotBeautifyPresets, ScreenshotBeautifyPresets.encoded(presets))
                        && !SettingsBackupSupport.valueLooksRight(DefaultsKey.screenshotBeautifyPresets, 3)
                        && SettingsBackupSupport.valueLooksRight(DefaultsKey.screenshotBeautifyAfterCapture, true),
                     "a restored backup is checked against the registered shapes")
    }

    // MARK: Naming

    private static func naming(_ suite: TestSuite) {
        let none: (String) -> Bool = { _ in false }
        suite.expect(ScreenshotBeautifyNaming.beautifiedName(for: "Screenshot 2026-11-20 at 10.00.00.png",
                                                            fileExtension: "png", exists: none)
                        == "Screenshot 2026-11-20 at 10.00.00-beautified.png",
                     "the suffix goes before the extension")
        suite.expect(ScreenshotBeautifyNaming.beautifiedName(for: "Hero.png", fileExtension: "jpg", exists: none)
                        == "Hero-beautified.jpg",
                     "the extension follows the export's format")
        suite.expect(ScreenshotBeautifyNaming.beautifiedName(for: "Hero-beautified.png", fileExtension: "png",
                                                            exists: { $0 == "Hero-beautified.png" })
                        == "Hero-beautified 2.png",
                     "a framed file framed again never stacks suffixes or overwrites")
        suite.expect(ScreenshotBeautifyNaming.beautifiedName(for: "/tmp/dir/Shot.heic", fileExtension: "png", exists: none)
                        == "Shot-beautified.png",
                     "only the name is used, never the path")

        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent("BeautifyTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: folder) }
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            let original = folder.appendingPathComponent("Shot.png")
            try Data([1]).write(to: original)
            try Data([2]).write(to: folder.appendingPathComponent("Shot-beautified.png"))
            try Data([3]).write(to: folder.appendingPathComponent("Shot-beautified 2.png"))
            let url = ScreenshotBeautifyNaming.beautifiedURL(beside: original, fileExtension: "png")
            suite.expect(url.lastPathComponent == "Shot-beautified 3.png" && url.deletingLastPathComponent() == folder,
                         "beside the original, past every existing framed copy")
            suite.expect((try? Data(contentsOf: folder.appendingPathComponent("Shot-beautified.png"))) == Data([2]),
                         "the earlier framed copy is untouched")
            suite.expect(!ScreenshotBeautifyNaming.isUsableOriginal(original)
                            && !ScreenshotBeautifyNaming.isUsableOriginal(nil)
                            && !ScreenshotBeautifyNaming.isUsableOriginal(folder.appendingPathComponent("gone.png")),
                         "temporary copies and missing files are no original to save beside")
        } catch {
            suite.expect(false, "the naming fixture writes: \(error)")
        }
    }

    // MARK: Rendering

    /// A small opaque shot: red with a blue top row, at 2x.
    private static func shot(width: Int = 40, height: Int = 30) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: height - 1, width: width, height: 1))
        return context.makeImage()
    }

    /// RGBA of the pixel `x` from the left and `y` from the top.
    private static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return Array(bytes[offset..<offset + 4])
    }

    private static func render(_ suite: TestSuite) {
        guard let image = shot() else {
            suite.expect(false, "the test shot draws")
            return
        }
        let size = CGSize(width: image.width, height: image.height)
        func input(_ style: Style) -> ScreenshotBeautifyRenderer.Input {
            ScreenshotBeautifyRenderer.Input(shot: image, shotPixels: size, scale: 2, style: style, wallpaper: nil)
        }

        let clearStyle = style { $0.background = .transparent; $0.padding = 0.25 }
        let layout = Layout.make(shotPixels: size, scale: 2, style: clearStyle)
        guard let clear = ScreenshotBeautifyRenderer.render(input(clearStyle)) else {
            suite.expect(false, "a clear composition renders")
            return
        }
        suite.expect(CGSize(width: clear.width, height: clear.height) == layout.canvas && clear.width == 58,
                     "the render is exactly the layout's canvas")
        let inset = Int(layout.shot.minX)
        suite.expect(pixel(clear, 0, 0)[3] == 0 && pixel(clear, clear.width - 1, clear.height - 1)[3] == 0,
                     "a clear background leaves the margin transparent")
        let middle = pixel(clear, clear.width / 2, clear.height / 2)
        suite.expect(middle == [255, 0, 0, 255], "the shot keeps its pixels: \(middle)")
        suite.expect(pixel(clear, inset + 2, inset)[2] == 255 && pixel(clear, inset + 2, inset + 2)[0] == 255,
                     "the shot is drawn the right way up")

        let paper = style { $0.background = .gradient; $0.gradient = .paper; $0.padding = 0.25 }
        guard let opaque = ScreenshotBeautifyRenderer.render(input(paper)) else {
            suite.expect(false, "a gradient composition renders")
            return
        }
        let corner = pixel(opaque, 0, 0)
        suite.expect(corner[3] == 255 && corner[0] > 240, "a gradient fills the margin: \(corner)")
        let solid = style { $0.background = .solid; $0.solid = "#0A0A0A"; $0.padding = 0.25 }
        if let dark = ScreenshotBeautifyRenderer.render(input(solid)) {
            suite.expect(pixel(dark, 1, 1) == [10, 10, 10, 255], "a solid fills the margin with its colour")
        } else {
            suite.expect(false, "a solid composition renders")
        }
        let wallpaper = style { $0.background = .wallpaper; $0.padding = 0.25 }
        suite.expect(ScreenshotBeautifyRenderer.render(input(wallpaper)).map { pixel($0, 0, 0)[3] } == 255,
                     "with no wallpaper to read, a gradient stands in")

        let rounded = style { $0.background = .transparent; $0.cornerRadius = 6 }
        if let roundedImage = ScreenshotBeautifyRenderer.render(input(rounded)) {
            suite.expect(pixel(roundedImage, 0, 0)[3] == 0 && pixel(roundedImage, 20, 15)[3] == 255,
                         "rounded corners cut the shot's corners to transparency")
        } else {
            suite.expect(false, "a rounded composition renders")
        }

        // Wide enough for the three lights, 40 pt of them at 2x.
        let framed = style { $0.background = .gradient; $0.frame = .light; $0.padding = 0.1; $0.caption = "Hi" }
        let wide = shot(width: 300, height: 120)
        let framedLayout = Layout.make(shotPixels: CGSize(width: 300, height: 120), scale: 2, style: framed)
        if let wide, let framedImage = ScreenshotBeautifyRenderer.render(
            .init(shot: wide, shotPixels: CGSize(width: 300, height: 120), scale: 2, style: framed, wallpaper: nil)),
           let light = framedLayout.lightCenters(scale: 2).first {
            let red = pixel(framedImage, Int(light.x), Int(light.y))
            suite.expect(CGSize(width: framedImage.width, height: framedImage.height) == framedLayout.canvas
                            && red[0] > 200 && red[1] < 140,
                         "the window frame draws its close light: \(red)")
        } else {
            suite.expect(false, "a framed composition with a caption renders")
        }

        let shadowed = style { $0.background = .transparent; $0.padding = 0.3; $0.shadow = .strong }
        if let shadowImage = ScreenshotBeautifyRenderer.render(input(shadowed)) {
            let below = Layout.make(shotPixels: size, scale: 2, style: shadowed).shot
            let under = pixel(shadowImage, Int(below.midX), Int(below.maxY) + 2)
            suite.expect(under[3] > 0 && pixel(shadowImage, 0, 0)[3] < under[3],
                         "a shadow falls below the shot, even on a clear background")
        } else {
            suite.expect(false, "a shadowed composition renders")
        }

        if let half = ScreenshotBeautifyRenderer.render(input(paper), outputScale: 0.5) {
            suite.expect(half.width == 29 && abs(half.height - opaque.height / 2) <= 1,
                         "the preview renders the same picture at a smaller size")
        } else {
            suite.expect(false, "a reduced preview renders")
        }
        let reduced = ScreenshotBeautifyRenderer.reduced(image, maximumSide: 20)
        suite.expect(reduced.width == 20 && reduced.height == 15
                        && ScreenshotBeautifyRenderer.reduced(image, maximumSide: 100) === image,
                     "the preview's copy of the shot shrinks only when it is larger")
    }

    private static func files(_ suite: TestSuite) {
        guard let image = shot() else { return }
        let size = CGSize(width: image.width, height: image.height)
        let clearStyle = style { $0.background = .transparent; $0.padding = 0.25 }
        let opaqueStyle = style { $0.background = .gradient; $0.padding = 0.25; $0.format = .jpeg }
        guard let clear = ScreenshotBeautifyRenderer.render(.init(shot: image, shotPixels: size, scale: 2,
                                                                  style: clearStyle, wallpaper: nil)),
              let opaque = ScreenshotBeautifyRenderer.render(.init(shot: image, shotPixels: size, scale: 2,
                                                                   style: opaqueStyle, wallpaper: nil))
        else {
            suite.expect(false, "the file fixtures render")
            return
        }
        func read(_ data: Data?) -> (type: String, image: CGImage, dpi: Double)? {
            guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let type = CGImageSourceGetType(source) as String?,
                  let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            return (type, decoded, (properties?[kCGImagePropertyDPIWidth] as? Double) ?? 0)
        }
        let png = read(ScreenshotBeautifyRenderer.encode(clear, scale: 2, format: clearStyle.effectiveFormat))
        suite.expect(png?.type == UTType.png.identifier && png?.image.width == clear.width
                        && png.map { pixel($0.image, 0, 0)[3] } == 0 && png?.dpi == 144,
                     "a clear export is a PNG that keeps its alpha and its 2x density")
        let jpeg = read(ScreenshotBeautifyRenderer.encode(opaque, scale: 2, format: opaqueStyle.effectiveFormat))
        suite.expect(jpeg?.type == UTType.jpeg.identifier && jpeg?.image.width == opaque.width && jpeg?.dpi == 144,
                     "an opaque export can be a JPEG at the same size")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.beautify(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 43 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words Beautify, with curly apostrophes and no em dash")
            suite.expect(text.saveBesideHelp.contains(ScreenshotBeautifyNaming.suffix),
                         "\(language.rawValue) names the -beautified suffix as files get it")
        }
    }
}
