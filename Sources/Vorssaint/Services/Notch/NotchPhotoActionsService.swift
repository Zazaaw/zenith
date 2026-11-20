// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import CoreImage
import UniformTypeIdentifiers
import Vision

/// Zenith fork: one drop on a photo target, from its options to its result.
struct NotchPhotoSession: Identifiable {
    let id = UUID()
    let action: NotchPhotoAction
    let inputs: [URL]
    let inputBytes: Int64
    /// The first picture, small, for the surface; nil until it is read.
    var thumbnail: CGImage?
    var phase: NotchPhotoPhase = .ready
}

enum NotchPhotoPhase {
    case ready
    case working(progress: Double, completed: Int)
    case done(NotchPhotoResult)
    case failed(NotchPhotoFailure)

    var isWorking: Bool { if case .working = self { return true } else { return false } }
}

struct NotchPhotoResult {
    let outputs: [URL]
    let inputBytes: Int64
    let outputBytes: Int64
    /// Inputs that could not be processed in a batch that otherwise went through.
    let skipped: Int
    let folder: URL?
    /// The first result, small: a cutout to reveal, a transform to show.
    let preview: CGImage?
}

enum NotchPhotoFailure: Equatable {
    case noSubject
    case failed
}

/// Zenith fork: the island's photo actions (NotchPhotoActionsSupport). The
/// session and the options live here, so the surface survives the island
/// closing and reopening; the work runs on a background queue and only its
/// results come back to the main thread. Results are saved beside the
/// originals (Downloads where that folder cannot be written), as Optimize
/// media saves them, and join the shelf when it is on.
final class NotchPhotoActionsService: ObservableObject {
    static let shared = NotchPhotoActionsService()

    @Published private(set) var session: NotchPhotoSession?
    /// False while a running job's surface stepped aside for another drop.
    @Published private(set) var presented = false
    @Published var kind: NotchPhotoTransformKind = .convert {
        didSet { if kind != oldValue { refreshWatermarkPreview() } }
    }
    @Published var format: NotchPhotoFormat = .jpeg
    @Published var longEdge: NotchPhotoLongEdge = .large
    @Published var quality: NotchPhotoQuality = .balanced
    @Published var alsoStrips = false
    /// The watermark chip beside Convert, Resize, Compress and Strip.
    @Published var alsoWatermarks = false {
        didSet { if alsoWatermarks != oldValue { refreshWatermarkPreview() } }
    }
    /// The watermark being edited, saved as it changes (a moment later, so a
    /// slider's drag writes once) and shared with Shelf settings.
    @Published var watermark = NotchWatermarkSupport.style() {
        didSet {
            guard watermark != oldValue else { return }
            refreshWatermarkPreview()
            scheduleWatermarkSave()
        }
    }
    @Published private(set) var watermarkPresets: [NotchWatermarkPreset] = []
    /// The watermark alone, drawn over transparency at the thumbnail's size,
    /// for the surface to lay over the first picture.
    @Published private(set) var watermarkPreview: CGImage?
    /// Bumped by Copy, so the button can say it worked.
    @Published private(set) var copySerial = 0
    /// A result is being dragged out of the island, which must not take it back.
    @Published var isDraggingOut = false

    /// Convert's formats on this Mac, read once.
    let offeredFormats = NotchPhotoFormat.offered(writable: NotchPhotoEncoder.writableTypes)

    private let queue = DispatchQueue(label: "id.satuvisual.zenith.notch.photo", qos: .userInitiated)
    private var cancellation: NotchPhotoCancellation?
    /// The live preview's own queue, so dragging a slider never waits behind
    /// a batch; only the newest request draws.
    private let previewQueue = DispatchQueue(label: "id.satuvisual.zenith.notch.watermark", qos: .userInteractive)
    private let previewState = NotchWatermarkPreviewState()
    private var previewGeneration = 0
    private var pendingWatermarkSave: DispatchWorkItem?

    private init() {
        watermarkPresets = NotchWatermarkSupport.presets(language: L10n.shared.language)
    }

    var isRunning: Bool { session?.phase.isWorking == true }
    var canAcceptDrop: Bool { !isRunning }
    var isPresented: Bool { session != nil && presented && NotchPhotoActionsSupport.isEnabled }

    // MARK: Drops

    /// The images a drag carries: file URLs only, every item a picture, and
    /// nothing else on the pasteboard (promises and mixed payloads stay with
    /// the shelf).
    func imageURLs(in pasteboard: NSPasteboard) -> [URL] {
        guard !pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) else { return [] }
        let urls = NotchAirDropSupport.fileURLs(in: pasteboard)
        guard !urls.isEmpty, urls.count >= (pasteboard.pasteboardItems?.count ?? 0) else { return [] }
        let images = urls.allSatisfy { url in
            NotchPhotoActionsSupport.acceptsImage((try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType)
        }
        return images ? urls : []
    }

    /// The photo targets for a drag, then the design overlay's for one image.
    func dropTargets(for pasteboard: NSPasteboard) -> [NotchDropTarget] {
        let urls = imageURLs(in: pasteboard)
        let photo = NotchPhotoActionsSupport.isEnabled
            ? NotchPhotoActionsSupport.targets(imageCount: urls.count, allImages: !urls.isEmpty) : []
        return DesignOverlaySupport.dropTargets(photo: photo, imageCount: urls.count,
                                                overlay: DesignOverlaySupport.isDropEnabled)
    }

    @discardableResult
    func open(_ target: NotchDropTarget, pasteboard: NSPasteboard) -> Bool {
        guard let action = NotchPhotoAction(target: target) else { return false }
        let urls = imageURLs(in: pasteboard)
        guard NotchPhotoActionsSupport.targets(imageCount: urls.count, allImages: !urls.isEmpty).contains(target)
        else { return false }
        return open(action, inputs: urls)
    }

    /// A new session for the dropped images. Remove Background has no options,
    /// so it starts at once; Transform waits for Apply.
    @discardableResult
    func open(_ action: NotchPhotoAction, inputs: [URL]) -> Bool {
        guard NotchPhotoActionsSupport.isEnabled, canAcceptDrop, !inputs.isEmpty else { return false }
        let bytes = inputs.reduce(Int64(0)) { $0 + NotchPhotoEncoder.fileSize($1) }
        let opened = NotchPhotoSession(action: action, inputs: inputs, inputBytes: bytes)
        if action == .transform { prepareWatermark() }
        watermarkPreview = nil
        session = opened
        presented = true
        loadThumbnail(for: opened)
        if action == .removeBackground { apply() }
        return true
    }

    private func loadThumbnail(for opened: NotchPhotoSession) {
        let id = opened.id
        let url = opened.inputs[0]
        queue.async { [weak self] in
            let image = NotchPhotoEncoder.uprightImage(at: url, maximumDimension: 480)
            let box = NotchPhotoImageBox(image)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.session?.id == id else { return }
                self.session?.thumbnail = box.image
                self.refreshWatermarkPreview()
            }
        }
    }

    // MARK: Work

    var recipe: NotchPhotoRecipe {
        NotchPhotoRecipe(kind: kind, format: offeredFormats.contains(format) ? format : .jpeg,
                         longEdge: longEdge, quality: quality, alsoStrips: alsoStrips,
                         watermark: appliesWatermark ? watermark.sanitized() : nil)
    }

    /// The Watermark step, or another step with the watermark chip on.
    var appliesWatermark: Bool { kind == .watermark || alsoWatermarks }

    func apply() {
        guard var current = session, !current.phase.isWorking else { return }
        let id = current.id
        let action = current.action
        let inputs = current.inputs
        let recipe = recipe
        let token = NotchPhotoCancellation()
        cancellation = token
        current.phase = .working(progress: 0, completed: 0)
        session = current
        let fallback = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let temporaryRoots = [FileManager.default.temporaryDirectory,
                              URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
        queue.async { [weak self] in
            var reserved = Set<String>()
            var outputs: [NotchPhotoOutput] = []
            // A batch reads its watermark's logo once.
            let logo = recipe.watermark.map { NotchWatermarkLogo.load($0.logoFile) }
            var failure: NotchPhotoFailure?
            files: for (index, input) in inputs.enumerated() {
                if token.isCancelled { break }
                let directory = NotchPhotoActionsSupport.outputDirectory(
                    for: input, isWritable: { FileManager.default.isWritableFile(atPath: $0.path) },
                    temporaryRoots: temporaryRoots, fallback: fallback)
                let stage: (Double) -> Void = { value in
                    let progress = NotchPhotoActionsSupport.progress(completed: index, total: inputs.count, stage: value)
                    DispatchQueue.main.async { self?.report(progress, completed: index, for: id) }
                }
                do {
                    switch action {
                    case .transform:
                        outputs.append(try NotchPhotoEncoder.transform(input, recipe: recipe, directory: directory,
                                                                       reserved: &reserved, logo: logo,
                                                                       cancellation: token, stage: stage))
                    case .removeBackground:
                        outputs.append(try NotchPhotoSubject.cutout(input, directory: directory, reserved: &reserved,
                                                                    cancellation: token, stage: stage))
                    }
                } catch NotchPhotoError.cancelled {
                    break files
                } catch NotchPhotoError.noSubject {
                    failure = .noSubject
                } catch {
                    failure = .failed
                }
                stage(1)
            }
            let preview = outputs.first.flatMap { NotchPhotoEncoder.uprightImage(at: $0.url, maximumDimension: 480) }
            let result = NotchPhotoResult(outputs: outputs.map(\.url),
                                          inputBytes: outputs.reduce(0) { $0 + $1.inputBytes },
                                          outputBytes: outputs.reduce(0) { $0 + $1.outputBytes },
                                          skipped: inputs.count - outputs.count,
                                          folder: outputs.first?.url.deletingLastPathComponent(),
                                          preview: preview)
            let box = NotchPhotoResultBox(result)
            let cancelled = token.isCancelled
            DispatchQueue.main.async { self?.finish(box.result, failure: failure, cancelled: cancelled, for: id) }
        }
    }

    private func report(_ progress: Double, completed: Int, for id: UUID) {
        guard var current = session, current.id == id, current.phase.isWorking else { return }
        current.phase = .working(progress: progress, completed: completed)
        session = current
    }

    private func finish(_ result: NotchPhotoResult, failure: NotchPhotoFailure?, cancelled: Bool, for id: UUID) {
        cancellation = nil
        if !result.outputs.isEmpty, AppFeature.shelf.isAvailable,
           UserDefaults.standard.bool(forKey: DefaultsKey.shelfEnabled) {
            _ = ShelfService.shared.addFiles(result.outputs)
        }
        guard var current = session, current.id == id else { return }
        if cancelled, result.outputs.isEmpty {
            current.phase = .ready
        } else if result.outputs.isEmpty {
            current.phase = .failed(failure ?? .failed)
        } else {
            current.phase = .done(result)
        }
        session = current
        // A run that finished behind another drop leaves its results in the shelf.
        if !presented, !current.phase.isWorking { session = nil }
    }

    func cancel() {
        cancellation?.cancel()
    }

    /// Back to the options with the same images, after a result or a failure.
    func again() {
        guard var current = session, !current.phase.isWorking else { return }
        current.phase = .ready
        session = current
    }

    func close() {
        cancellation?.cancel()
        cancellation = nil
        session = nil
        presented = false
        previewGeneration += 1
        watermarkPreview = nil
        flushWatermarkSave()
    }

    /// Another drop takes the page: an idle session ends, a running one keeps
    /// working out of sight and its results join the shelf.
    func hide() {
        guard session != nil else { return }
        if isRunning { presented = false } else { close() }
    }

    func stop() { close() }

    func syncWithPreferences() {
        if !NotchPhotoActionsSupport.isEnabled { close() }
    }

    // MARK: Watermark

    /// A new drop starts from the saved presets as they are now (a restored
    /// backup included) and from the default preset, if one is chosen.
    private func prepareWatermark() {
        flushWatermarkSave()
        watermarkPresets = NotchWatermarkSupport.presets(language: L10n.shared.language)
        if let id = NotchWatermarkSupport.defaultPresetID(),
           let preset = watermarkPresets.first(where: { $0.id == id }) {
            watermark = preset.style
        }
    }

    /// The preset the watermark is, unchanged; nil once it is edited.
    var currentWatermarkPreset: NotchWatermarkPreset? {
        NotchWatermarkSupport.matchingPreset(watermark, in: watermarkPresets)
    }

    func applyWatermarkPreset(_ id: String) {
        guard let preset = watermarkPresets.first(where: { $0.id == id }) else { return }
        watermark = preset.style
    }

    /// Saves the watermark under `name`; true when it was saved.
    @discardableResult
    func saveWatermarkPreset(named name: String) -> Bool {
        let saved = NotchWatermarkSupport.saving(watermark, named: name, to: watermarkPresets)
        guard saved.id != nil else { return false }
        watermarkPresets = saved.presets
        NotchWatermarkSupport.savePresets(saved.presets)
        return true
    }

    func deleteWatermarkPreset(_ id: String) {
        watermarkPresets.removeAll { $0.id == id }
        NotchWatermarkSupport.savePresets(watermarkPresets)
        if NotchWatermarkSupport.defaultPresetID() == id {
            UserDefaults.standard.set("", forKey: DefaultsKey.notchWatermarkDefaultPreset)
        }
        pruneWatermarkLogos()
    }

    /// Picks a PNG, SVG or PDF (or another picture) for the logo and copies
    /// it into the app's container, where presets find it later.
    func chooseWatermarkLogo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = NotchWatermarkLogoStore.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.message = ZenithStrings.watermark(L10n.shared.language).chooseLogo
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              NotchWatermarkLogo.load(url: url) != nil,
              let name = NotchWatermarkLogoStore.importLogo(from: url) else { return }
        var style = watermark
        style.logoFile = name
        if style.content == .text { style.content = .both }
        watermark = style
        pruneWatermarkLogos()
    }

    /// Back to the bundled star.
    func useWatermarkStar() {
        guard watermark.logoFile != nil else { return }
        watermark.logoFile = nil
        if watermark.color == .original { watermark.color = .auto }
        pruneWatermarkLogos()
    }

    /// Logos that neither the watermark nor any preset uses are removed.
    private func pruneWatermarkLogos() {
        var names = Set(watermarkPresets.compactMap(\.style.logoFile))
        if let file = watermark.logoFile { names.insert(file) }
        previewQueue.async { NotchWatermarkLogoStore.prune(keeping: names) }
    }

    private func scheduleWatermarkSave() {
        pendingWatermarkSave?.cancel()
        let style = watermark
        let work = DispatchWorkItem { NotchWatermarkSupport.saveStyle(style) }
        pendingWatermarkSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func flushWatermarkSave() {
        guard let pending = pendingWatermarkSave, !pending.isCancelled else { return }
        pending.cancel()
        pendingWatermarkSave = nil
        NotchWatermarkSupport.saveStyle(watermark)
    }

    /// Redraws the live preview for the first picture: on the preview queue,
    /// the newest request only, the logo read once per file.
    func refreshWatermarkPreview() {
        previewGeneration += 1
        guard let session, session.action == .transform, appliesWatermark, let thumbnail = session.thumbnail else {
            if watermarkPreview != nil { watermarkPreview = nil }
            return
        }
        let generation = previewGeneration
        let style = watermark.sanitized()
        let backdrop = NotchPhotoImageBox(thumbnail)
        let state = previewState
        state.request(generation)
        previewQueue.async { [weak self] in
            guard state.isNewest(generation) else { return }
            let logo = state.logo(for: style.logoFile)
            let overlay = backdrop.image.flatMap { NotchWatermarkRenderer.overlay(for: $0, style: style, logo: logo) }
            let box = NotchPhotoImageBox(overlay)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.previewGeneration == generation else { return }
                self.watermarkPreview = box.image
            }
        }
    }

    // MARK: Results

    func revealResults() {
        guard case let .done(result)? = session?.phase else { return }
        NSWorkspace.shared.activateFileViewerSelecting(result.outputs)
    }

    /// Puts the results on the clipboard as files; a single result also as
    /// its picture, so it pastes into a design or a chat as an image.
    func copyResults() {
        guard case let .done(result)? = session?.phase, !result.outputs.isEmpty else { return }
        let urls = result.outputs
        GeneralPasteboardAccess.shared.async {
            let board = NSPasteboard.general
            board.clearContents()
            if urls.count == 1, let url = urls.first {
                let item = NSPasteboardItem()
                item.setString(url.absoluteString, forType: .fileURL)
                if let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType,
                   let data = try? Data(contentsOf: url) {
                    item.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
                }
                board.writeObjects([item])
            } else {
                board.writeObjects(urls.map { $0 as NSURL })
            }
        }
        copySerial += 1
    }
}

/// A picture handed from the work queue to the main thread.
private final class NotchPhotoImageBox: @unchecked Sendable {
    let image: CGImage?
    init(_ image: CGImage?) { self.image = image }
}

/// The live preview's bookkeeping, shared by the main thread (which asks)
/// and the preview queue (which draws): the newest request, and the logo it
/// last read so a slider's drag does not read the file again.
private final class NotchWatermarkPreviewState: @unchecked Sendable {
    private let lock = NSLock()
    private var newest = 0
    private var cached: NotchWatermarkLogo?

    func request(_ generation: Int) { lock.withLock { newest = max(newest, generation) } }
    func isNewest(_ generation: Int) -> Bool { lock.withLock { generation >= newest } }

    /// Called on the preview queue only.
    func logo(for file: String?) -> NotchWatermarkLogo {
        if let cached = lock.withLock({ cached }), cached.file == file { return cached }
        let logo = NotchWatermarkLogo.load(file)
        lock.withLock { cached = logo }
        return logo
    }
}

private final class NotchPhotoResultBox: @unchecked Sendable {
    let result: NotchPhotoResult
    init(_ result: NotchPhotoResult) { self.result = result }
}

/// Vision's subject lifting, all on this Mac: the foreground instances'
/// mask at the picture's size, composed over transparency by Core Image.
enum NotchPhotoSubject {
    static func cutout(_ input: URL, directory: URL, reserved: inout Set<String>,
                       cancellation: NotchPhotoCancellation, stage: (Double) -> Void) throws -> NotchPhotoOutput {
        guard let image = NotchPhotoEncoder.uprightImage(at: input, maximumDimension: MediaSupport.maxImageRenderDimension)
        else { throw NotchPhotoError.unreadable }
        try cancellation.check()
        stage(0.15)
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        try cancellation.check()
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw NotchPhotoError.noSubject
        }
        stage(0.6)
        let mask = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        try cancellation.check()
        guard let cutout = NotchPhotoEncoder.cutout(image, mask: CIImage(cvPixelBuffer: mask)) else {
            throw NotchPhotoError.writeFailed
        }
        stage(0.85)
        return try NotchPhotoEncoder.writeCutout(cutout, for: input, directory: directory, reserved: &reserved)
    }
}
