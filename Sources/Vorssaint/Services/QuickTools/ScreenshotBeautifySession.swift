// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import Combine

/// Zenith fork: Beautify inside one editor window. Entering it flattens the
/// capture once (marks and watermark, no upstream backdrop), then every change
/// to the style re-renders a small preview off the main actor and, once the
/// change settles, the full-resolution export, so Copy, Save and drag-out
/// hand over pixels that are already made.
final class ScreenshotBeautifySession: ObservableObject {
    struct Prepared: Sendable {
        let style: ScreenshotBeautifyStyle
        let image: CGImage
        let data: Data
        let format: ScreenshotBeautifyStyle.Format
        let scale: CGFloat
    }

    @Published private(set) var isActive = false
    @Published var style: ScreenshotBeautifyStyle {
        didSet { styleChanged(from: oldValue) }
    }
    @Published private(set) var presets: [ScreenshotBeautifyPreset]
    @Published private(set) var preview: CGImage?
    @Published private(set) var wallpaperMissing = false
    /// True while an export waits for its pixels.
    @Published private(set) var exporting = false

    private weak var model: ScreenshotEditorModel?
    /// The file this capture came from, if any: Save puts the framed copy beside it.
    let sourceURL: URL?
    private var source: ScreenshotRenderer.Export?
    private var previewShot: CGImage?
    private var shotCorner: CGFloat = 0
    private var wallpaper: CGImage?
    private var renderInFlight = false
    private var renderPending = false
    private var prepared: Prepared?
    private var prepareWork: DispatchWorkItem?
    private var prepareGeneration = 0
    private var prepareWaiters: [(Prepared?) -> Void] = []

    /// The preview's longest side in pixels: sharp on a Retina editor window,
    /// cheap enough to redraw on every slider step.
    static let previewSide: CGFloat = 1800

    init(model: ScreenshotEditorModel, sourceURL: URL?) {
        self.model = model
        self.sourceURL = sourceURL
        style = ScreenshotBeautifyStore.lastStyle()
        presets = ScreenshotBeautifyStore.presets()
    }

    var text: ZenithBeautifyStrings { ZenithStrings.beautify(L10n.shared.language) }
    private var strings: ScreenshotFeatureStrings { FeatureStrings.screenshot(L10n.shared.language) }

    /// The finished canvas in pixels and the capture's scale, for the size readout.
    var outputSize: (size: CGSize, scale: CGFloat)? {
        guard let source else { return nil }
        let pixels = CGSize(width: source.image.width, height: source.image.height)
        return (ScreenshotBeautifyLayout.make(shotPixels: pixels, scale: source.scale, style: style).canvas,
                source.scale)
    }

    /// The preset this exact style came from, if it still matches one.
    var matchingPresetName: String? {
        let current = style.sanitized()
        return presets.first { $0.style == current }?.name
    }

    // MARK: Mode

    func enter() {
        guard !isActive else { return }
        guard let export = model?.beautifySource() else {
            ZenithQuiet.beep()
            return
        }
        source = export
        previewShot = nil
        prepared = nil
        shotCorner = ScreenshotSupport.transparentCornerRadius(of: export.image)
        isActive = true
        loadWallpaperIfNeeded()
        renderPreview()
        schedulePrepare()
    }

    /// Back to the editor. The pixels are let go; entering again flattens the
    /// capture anew, since marks may have changed in between.
    func leave() {
        guard isActive else { return }
        isActive = false
        prepareWork?.cancel()
        prepareGeneration += 1
        let waiters = prepareWaiters
        prepareWaiters = []
        waiters.forEach { $0(nil) }
        exporting = false
        source = nil
        previewShot = nil
        prepared = nil
        preview = nil
    }

    func toggle() {
        if isActive { leave() } else { enter() }
    }

    // MARK: Style

    private func styleChanged(from old: ScreenshotBeautifyStyle) {
        guard style != old else { return }
        ScreenshotBeautifyStore.saveLastStyle(style)
        if style.background == .wallpaper, old.background != .wallpaper { loadWallpaperIfNeeded() }
        guard isActive else { return }
        renderPreview()
        schedulePrepare()
    }

    func apply(_ preset: ScreenshotBeautifyPreset) {
        style = preset.style.sanitized()
    }

    func savePreset(named name: String) {
        let updated = ScreenshotBeautifyPresets.saving(style, named: name, to: presets)
        guard updated != presets else { return }
        presets = updated
        ScreenshotBeautifyStore.savePresets(updated)
    }

    func deletePreset(named name: String) {
        presets = ScreenshotBeautifyPresets.removing(named: name, from: presets)
        ScreenshotBeautifyStore.savePresets(presets)
    }

    private func loadWallpaperIfNeeded() {
        guard style.background == .wallpaper, wallpaper == nil else { return }
        ScreenshotBeautifyWallpaper.load { [weak self] image in
            guard let self else { return }
            self.wallpaper = image
            self.wallpaperMissing = image == nil
            guard self.isActive, image != nil else { return }
            self.prepared = nil
            self.renderPreview()
            self.schedulePrepare()
        }
    }

    private func input(shot: CGImage, from source: ScreenshotRenderer.Export) -> ScreenshotBeautifyRenderer.Input {
        ScreenshotBeautifyRenderer.Input(shot: shot,
                                         shotPixels: CGSize(width: source.image.width, height: source.image.height),
                                         scale: source.scale,
                                         style: style,
                                         wallpaper: style.background == .wallpaper ? wallpaper : nil,
                                         shotCorner: shotCorner)
    }

    // MARK: Preview

    /// One preview render at a time; changes made meanwhile collapse into one
    /// more render of the latest style, so a dragged slider never queues work.
    private func renderPreview() {
        guard isActive, let source else { return }
        if renderInFlight {
            renderPending = true
            return
        }
        renderInFlight = true
        let full = source.image
        let reducedShot = previewShot
        let template = input(shot: full, from: source)
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> (CGImage?, CGImage) in
                let shot = reducedShot ?? ScreenshotBeautifyRenderer.reduced(full, maximumSide: Self.previewSide)
                let layout = ScreenshotBeautifyLayout.make(shotPixels: template.shotPixels, scale: template.scale,
                                                           style: template.style)
                let outputScale = min(1, Self.previewSide / max(layout.canvas.width, layout.canvas.height))
                let input = ScreenshotBeautifyRenderer.Input(shot: shot, shotPixels: template.shotPixels,
                                                             scale: template.scale, style: template.style,
                                                             wallpaper: template.wallpaper,
                                                             shotCorner: template.shotCorner)
                return (ScreenshotBeautifyRenderer.render(input, outputScale: outputScale), shot)
            }.value
            guard let self else { return }
            self.renderInFlight = false
            guard self.isActive, self.source?.image === full else { return }
            self.previewShot = result.1
            if let image = result.0 { self.preview = image }
            if self.renderPending {
                self.renderPending = false
                self.renderPreview()
            }
        }
    }

    // MARK: Export

    private func schedulePrepare() {
        prepareWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.prepareNow() }
        prepareWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Hands over the full-resolution export of the current style, made now
    /// if the one ready in the background is for an older style.
    private func withPrepared(_ body: @escaping (Prepared?) -> Void) {
        if let prepared, prepared.style == style.sanitized() {
            body(prepared)
            return
        }
        prepareWaiters.append(body)
        exporting = true
        prepareWork?.cancel()
        prepareNow()
    }

    private func prepareNow() {
        guard isActive, let source else { return }
        prepareGeneration += 1
        let generation = prepareGeneration
        let input = input(shot: source.image, from: source)
        let style = input.style.sanitized()
        let scale = source.scale
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Prepared? in
                guard let image = ScreenshotBeautifyRenderer.render(input),
                      let data = ScreenshotBeautifyRenderer.encode(image, scale: scale, format: style.effectiveFormat)
                else { return nil }
                return Prepared(style: style, image: image, data: data, format: style.effectiveFormat, scale: scale)
            }.value
            // A newer export is on its way and answers whoever is waiting.
            guard let self, generation == self.prepareGeneration else { return }
            self.prepared = result
            self.exporting = false
            let waiters = self.prepareWaiters
            self.prepareWaiters = []
            waiters.forEach { $0(result) }
        }
    }

    private func exportName(_ format: ScreenshotBeautifyStyle.Format) -> String {
        let base = ScreenshotSupport.fileName(prefix: strings.fileNamePrefix, date: Date(),
                                              fileExtension: format.fileExtension)
        return ScreenshotBeautifyNaming.beautifiedName(for: base, fileExtension: format.fileExtension) { _ in false }
    }

    /// Copies the framed picture as PNG and TIFF (and as a file unless the
    /// screenshot settings ask for the image only). The editor stays open, so
    /// another aspect can follow straight away.
    func copy() {
        withPrepared { [weak self] prepared in
            guard let self, let prepared else {
                ZenithQuiet.beep()
                return
            }
            let imageOnly = UserDefaults.standard.bool(forKey: DefaultsKey.screenshotCopyImageOnly)
            let folder = imageOnly ? nil : ScreenshotSupport.copiedFilesDirectory()
            let name = self.exportName(.png)
            Task { @MainActor [weak self] in
                let output = await Task.detached(priority: .userInitiated) {
                    () -> (URL?, ScreenshotEditorController.ClipboardPayload)? in
                    let png = prepared.format == .png
                        ? prepared.data : ScreenshotRenderer.pngData(from: prepared.image, scale: prepared.scale)
                    guard let png else { return nil }
                    let payload = ScreenshotEditorController.clipboardPayload(
                        from: ScreenshotRenderer.Export(image: prepared.image, scale: prepared.scale), png: png)
                    guard let folder else { return (nil, payload) }
                    guard let url = try? ScreenshotSupport.copiedFile(data: png, name: name, directory: folder)
                    else { return nil }
                    return (url, payload)
                }.value
                guard let output,
                      ScreenshotEditorController.copyFile(output.0, payload: output.1, imageOnly: imageOnly)
                else {
                    if let url = output?.0 { try? FileManager.default.removeItem(at: url) }
                    ZenithQuiet.beep()
                    return
                }
                if let folder, let url = output.0 {
                    ScreenshotSupport.pruneCopiedFiles(in: folder, preserving: url)
                }
                self?.model?.markExported()
                QuickToolHUD.show(icon: "wand.and.stars", message: self?.strings.copiedHUD ?? "")
            }
        }
    }

    /// Saves beside the file the capture came from, or in the screenshot
    /// folder when there is none, with `-beautified` added and never over an
    /// existing file.
    func saveBesideOriginal() {
        withPrepared { [weak self] prepared in
            guard let self, let prepared else {
                ZenithQuiet.beep()
                return
            }
            let ext = prepared.format.fileExtension
            var consumedNumber: Int?
            let url: URL
            if ScreenshotBeautifyNaming.isUsableOriginal(self.sourceURL), let original = self.sourceURL {
                url = ScreenshotBeautifyNaming.beautifiedURL(beside: original, fileExtension: ext)
            } else {
                let destination = ScreenshotService.saveDestination(strings: self.strings, fileExtension: ext)
                consumedNumber = destination.consumedNumber
                url = ScreenshotBeautifyNaming.beautifiedURL(beside: destination.url, fileExtension: ext)
            }
            do {
                // Refuses to replace a file of that name, even one that
                // appeared after the name was chosen.
                try prepared.data.write(to: url, options: .withoutOverwriting)
                self.model?.markExported()
                QuickToolHUD.show(icon: "wand.and.stars",
                                  message: String(format: self.strings.savedHUDFormat,
                                                  url.deletingLastPathComponent().lastPathComponent))
            } catch {
                if let consumedNumber { ScreenshotService.rewindNumberSequence(toReuse: consumedNumber) }
                ZenithQuiet.beep()
            }
        }
    }

    /// The framed picture as a file for a drag out of the editor. The export
    /// is normally ready already; if the style changed a moment ago it is
    /// made here, since the drag cannot wait.
    func dragProvider() -> NSItemProvider {
        guard isActive, let source else { return NSItemProvider() }
        let current = style.sanitized()
        let ready: Prepared
        if let prepared, prepared.style == current {
            ready = prepared
        } else {
            guard let image = ScreenshotBeautifyRenderer.render(input(shot: source.image, from: source)),
                  let data = ScreenshotBeautifyRenderer.encode(image, scale: source.scale,
                                                               format: current.effectiveFormat)
            else { return NSItemProvider() }
            ready = Prepared(style: current, image: image, data: data, format: current.effectiveFormat,
                             scale: source.scale)
            prepared = ready
        }
        guard let url = try? ScreenshotSupport.temporaryDragFile(data: ready.data, name: exportName(ready.format)),
              let provider = NSItemProvider(contentsOf: url)
        else { return NSItemProvider() }
        let folder = url.deletingLastPathComponent()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 60 * 60) {
            try? FileManager.default.removeItem(at: folder)
        }
        model?.markExported()
        return provider
    }

    // MARK: Keys

    /// ⌘C and Return copy, ⌘S saves beside the original, Escape goes back to
    /// editing. Everything else, ⌘W included, carries on as usual.
    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = Int(event.keyCode)
        if flags.intersection([.command, .option, .control]) == .command {
            switch key {
            case kVK_ANSI_C:
                if !event.isARepeat { copy() }
                return true
            case kVK_ANSI_S:
                if !event.isARepeat { saveBesideOriginal() }
                return true
            default:
                return false
            }
        }
        guard flags.isDisjoint(with: [.command, .control, .option]) else { return false }
        switch key {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if !event.isARepeat { copy() }
            return true
        case kVK_Escape:
            leave()
            return true
        default:
            return false
        }
    }
}

// MARK: - Wallpaper

/// The current desktop picture, blurred once and kept while it stays the same file.
enum ScreenshotBeautifyWallpaper {
    private static var cached: (path: String, image: CGImage)?

    static func load(_ completion: @escaping (CGImage?) -> Void) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            completion(nil)
            return
        }
        if let cached, cached.path == url.path {
            completion(cached.image)
            return
        }
        Task { @MainActor in
            let image = await Task.detached(priority: .userInitiated) {
                ScreenshotBeautifyRenderer.blurredWallpaper(at: url)
            }.value
            if let image { cached = (url.path, image) }
            completion(image)
        }
    }
}

// MARK: - After capture

/// "Beautify after capture": frames each new screenshot with the last style
/// before it is copied, saved or previewed, and remembers the raw capture so
/// Edit and Beautify open the original rather than framing a frame.
enum ScreenshotBeautifyAuto {
    private static var originals: [(framed: CGImage, raw: ScreenshotSelectionController.Capture)] = []
    private static var passedThrough: ObjectIdentifier?
    /// Only the newest captures can still be opened from their preview.
    private static let memory = 2

    /// Takes the capture when the setting is on and renders it off the main
    /// actor; `resume` then receives the framed capture (or the raw one, if
    /// rendering failed) to route as usual. False leaves it to the caller.
    static func intercept(_ capture: ScreenshotSelectionController.Capture,
                          resume: @escaping (ScreenshotSelectionController.Capture) -> Void) -> Bool {
        guard AppFeature.screenshot.isAvailable, ScreenshotBeautifyStore.beautifiesAfterCapture() else { return false }
        let identity = ObjectIdentifier(capture.image)
        if passedThrough == identity {
            passedThrough = nil
            return false
        }
        guard !originals.contains(where: { $0.framed === capture.image }) else { return false }
        let style = ScreenshotBeautifyStore.lastStyle()
        let render: (CGImage?) -> Void = { wallpaper in
            let input = ScreenshotBeautifyRenderer.Input(
                shot: capture.image,
                shotPixels: CGSize(width: capture.image.width, height: capture.image.height),
                scale: capture.scale, style: style, wallpaper: wallpaper,
                shotCorner: ScreenshotSupport.transparentCornerRadius(of: capture.image))
            Task { @MainActor in
                let framed = await Task.detached(priority: .userInitiated) {
                    ScreenshotBeautifyRenderer.render(input)
                }.value
                guard let framed else {
                    passedThrough = identity
                    resume(capture)
                    return
                }
                originals.append((framed, capture))
                originals = Array(originals.suffix(memory))
                resume(ScreenshotSelectionController.Capture(
                    image: framed, scale: capture.scale, anchorRect: capture.anchorRect,
                    sourceFormat: style.effectiveFormat == .jpeg ? .jpeg : .png))
            }
        }
        if style.background == .wallpaper {
            ScreenshotBeautifyWallpaper.load(render)
        } else {
            render(nil)
        }
        return true
    }

    /// The capture an editor should open: a framed one goes back to its raw
    /// original, opened in Beautify so the frame is still what it shows.
    static func editorCapture(for capture: ScreenshotSelectionController.Capture,
                              beautify: Bool) -> (capture: ScreenshotSelectionController.Capture, beautify: Bool) {
        guard let entry = originals.last(where: { $0.framed === capture.image }) else { return (capture, beautify) }
        var raw = entry.raw
        if raw.sourceURL == nil { raw.sourceURL = capture.sourceURL }
        return (raw, true)
    }

    /// The capture with the file it was saved to, so Save can go beside it.
    static func withSource(_ capture: ScreenshotSelectionController.Capture,
                           _ url: URL?) -> ScreenshotSelectionController.Capture {
        guard let url else { return capture }
        var result = capture
        result.sourceURL = url
        return result
    }
}
