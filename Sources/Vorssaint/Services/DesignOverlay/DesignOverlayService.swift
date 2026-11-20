// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreImage
import UniformTypeIdentifiers

/// Zenith fork: the design QA overlay. One reference image at a time, shown
/// at its true point size over whatever is under it, with a HUD to tune it.
/// Opened from the global shortcut, the island's Overlay zone or the
/// clipboard; each display remembers where the image sat, its opacity and
/// its scale. The overlay's settings sit with the screenshot tool, whose
/// availability it follows.
@MainActor
final class DesignOverlayService: ObservableObject {
    static let shared = DesignOverlayService()

    /// A short note the HUD shows in place of the image's size.
    enum Feedback: Equatable, Hashable {
        case alignedPage, alignedWindow, noWindow, noImage, needsScreenRecording
    }

    @Published private(set) var isVisible = false
    @Published private(set) var reference: DesignOverlayReference?
    @Published private(set) var opacity = DesignOverlaySupport.defaultOpacity
    @Published private(set) var blend = DesignOverlayBlend.normal
    @Published private(set) var scaleChoice = DesignOverlayScaleChoice.automatic
    @Published private(set) var showsGrid = false
    @Published private(set) var clickThrough = true
    @Published private(set) var placement = DesignOverlayPlacement(offset: .zero)
    @Published private(set) var feedback: Feedback?
    @Published private(set) var shortcutRegistrationFailed = false

    private(set) var displayID = CGMainDisplayID()
    private let hotkey = QuickToolHotkey(id: 82)
    private let memory = DesignOverlayMemory()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var overlay: DesignOverlayPanel?
    private var canvas: DesignOverlayCanvas?
    private var hud: DesignOverlayHUD?
    private var inverted: CGImage?
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var saveTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var differenceLoop: Task<Void, Never>?
    private var differenceTask: Task<Void, Never>?
    private var differencePending = false
    private var askedForScreenRecording = false

    private init() {
        hotkey.onPress = { [weak self] in self?.toggle() }
    }

    // MARK: Preferences

    func syncWithPreferences() {
        let available = AppFeature.screenshot.isAvailable
        let enabled = available && UserDefaults.standard.bool(forKey: DefaultsKey.designOverlayShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.designOverlayShortcut, fallback: .designOverlayDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.designOverlayShortcut)
        if !available { close(animated: false) }
    }

    private var defaultOpacity: Double {
        let stored = UserDefaults.standard.object(forKey: DefaultsKey.designOverlayDefaultOpacity) as? Double
        return DesignOverlaySupport.clampedOpacity(stored ?? DesignOverlaySupport.defaultOpacity)
    }

    private var defaultBlend: DesignOverlayBlend {
        .stored(UserDefaults.standard.string(forKey: DefaultsKey.designOverlayDefaultBlend))
    }

    private var grid: DesignOverlayGrid {
        DesignOverlayGridPreset.stored(UserDefaults.standard.string(forKey: DefaultsKey.designOverlayGridPreset)).grid
    }

    // MARK: Geometry

    var detectedScale: Int {
        guard let reference else { return 1 }
        return DesignOverlaySupport.detectedScale(reference.info, screenPointWidth: displayBounds.width)
    }

    var scale: Int { scaleChoice.resolved(detected: detectedScale) }

    var pointSize: CGSize {
        guard let reference else { return .zero }
        return DesignOverlaySupport.pointSize(pixelWidth: reference.info.pixelWidth,
                                              pixelHeight: reference.info.pixelHeight, scale: scale)
    }

    /// The whole image in global points, y down.
    var imageFrame: CGRect {
        DesignOverlaySupport.frame(offset: placement.offset, size: pointSize, display: displayBounds)
    }

    /// "1440 × 3200 pt", the image's size on screen.
    var sizeLabel: String {
        let size = pointSize
        return "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) pt"
    }

    private var displayBounds: CGRect { CGDisplayBounds(displayID) }
    private var primaryHeight: CGFloat { CGDisplayBounds(CGMainDisplayID()).height }

    private var screen: NSScreen? {
        NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        } ?? NSScreen.main
    }

    private var displayScale: CGFloat { screen?.backingScaleFactor ?? 2 }

    /// The display's area free of the menu bar and Dock, in global points.
    private var visibleBounds: CGRect {
        guard let screen else { return displayBounds }
        return DesignOverlaySupport.globalFrame(screen.visibleFrame, primaryHeight: primaryHeight)
    }

    /// The display's stable identity, which survives restarts and reconnecting.
    private var displayKey: String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String?
        else { return "display-\(displayID)" }
        return string
    }

    private static func displayUnderPointer() -> CGDirectDisplayID {
        let point = CGEvent(source: nil)?.location ?? .zero
        var display = CGDirectDisplayID()
        var count: UInt32 = 0
        guard CGGetDisplaysWithPoint(point, 1, &display, &count) == .success, count > 0 else { return CGMainDisplayID() }
        return display
    }

    // MARK: Opening

    /// The shortcut: closes a showing overlay, otherwise brings back the last
    /// reference, or the clipboard's image, or asks for a file.
    func toggle() {
        if isVisible {
            close()
            return
        }
        if let url = DesignOverlayImageStore.lastReferenceURL(memory), open(storedAt: url) { return }
        pasteFromClipboard(orChoose: true)
    }

    /// A drop on the island's Overlay zone.
    @discardableResult
    func open(dropped pasteboard: NSPasteboard) -> Bool {
        guard AppFeature.screenshot.isAvailable,
              let url = NotchPhotoActionsService.shared.imageURLs(in: pasteboard).first
        else { return false }
        return open(fileAt: url)
    }

    @discardableResult
    func open(fileAt url: URL) -> Bool {
        guard let stored = DesignOverlayImageStore.store(fileAt: url, memory: memory) else { return false }
        return open(storedAt: stored)
    }

    /// The clipboard's image as the reference: a frame Figma copied as PNG.
    /// Read off the main thread, as every general pasteboard read is.
    func pasteFromClipboard(orChoose choose: Bool = false) {
        GeneralPasteboardAccess.shared.async(timeout: 3, { @Sendable _ in
            DesignOverlayImageStore.imageData(on: NSPasteboard.general)
        }, then: { [weak self] found in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let found, let stored = DesignOverlayImageStore.store(data: found.data,
                                                                         fileExtension: found.fileExtension,
                                                                         memory: self.memory),
                   self.open(storedAt: stored) {
                    return
                }
                if choose { self.chooseImage() } else { self.show(.noImage) }
            }
        })
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP]
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            MainActor.assumeIsolated {
                guard response == .OK, let url = panel.url else { return }
                self?.open(fileAt: url)
            }
        }
    }

    @discardableResult
    private func open(storedAt url: URL) -> Bool {
        guard AppFeature.screenshot.isAvailable, let loaded = DesignOverlayImageStore.load(url) else { return false }
        let wasVisible = isVisible
        reference = loaded
        inverted = nil
        // A new reference while the overlay shows keeps where and how it shows.
        if !wasVisible {
            displayID = Self.displayUnderPointer()
            blend = defaultBlend
            showsGrid = false
            clickThrough = true
            if let record = memory.record(for: displayKey) {
                opacity = record.opacity
                scaleChoice = record.scale
                placement = DesignOverlayPlacement(offset: record.offset, locked: record.locked)
            } else {
                opacity = defaultOpacity
                scaleChoice = .automatic
                placement = DesignOverlayPlacement(offset: initialOffset())
            }
        }
        present(wasVisible: wasVisible)
        return true
    }

    /// With nothing remembered: on the window under the pointer when there is
    /// one on this display, otherwise the top left of the free area.
    private func initialOffset() -> CGPoint {
        if let match = DesignOverlayWindowFinder.contentUnderCursor(), displayBounds.contains(match.frame.origin) {
            return snapped(DesignOverlaySupport.offset(placing: match.frame.origin, in: displayBounds))
        }
        return DesignOverlaySupport.offset(placing: visibleBounds.origin, in: displayBounds)
    }

    private func present(wasVisible: Bool) {
        hideTask?.cancel()
        let panel = overlay ?? makeOverlay()
        panel.ignoresMouseEvents = clickThrough
        applyImage()
        layout()
        if !wasVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = ZenithMotion.fast
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
                panel.animator().alphaValue = 1
            }
            let hud = hud ?? DesignOverlayHUD(service: self)
            self.hud = hud
            hud.show(at: DesignOverlaySupport.hudOrigin(image: imageFrame, hud: hud.size, visible: visibleBounds),
                     primaryHeight: primaryHeight)
            installMonitors()
        }
        isVisible = true
        syncDifference()
    }

    private func makeOverlay() -> DesignOverlayPanel {
        let panel = DesignOverlayPanel()
        let canvas = DesignOverlayCanvas(frame: .zero)
        canvas.onDrag = { [weak self] delta in self?.move(by: delta) }
        canvas.onPress = { [weak self] in self?.hud?.focus() }
        panel.contentView = canvas
        overlay = panel
        self.canvas = canvas
        return panel
    }

    // MARK: Closing

    func close() { close(animated: true) }

    func close(animated: Bool) {
        guard isVisible || overlay?.isVisible == true else { return }
        saveNow()
        isVisible = false
        stopDifference()
        removeMonitors()
        hud?.hide()
        feedback = nil
        let panel = overlay
        if animated, let panel {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = ZenithMotion.fast
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
                panel.animator().alphaValue = 0
            }
            hideTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(ZenithMotion.fast * 1_000_000_000))
                guard !Task.isCancelled, let self, !self.isVisible else { return }
                self.releaseImage()
            }
        } else {
            releaseImage()
        }
    }

    /// The image is read again from the container next time; a big
    /// reference does not stay in memory while nothing shows it.
    private func releaseImage() {
        overlay?.orderOut(nil)
        canvas?.setImage(nil, size: .zero, crisp: false, contentsScale: 1)
        canvas?.setDifference(nil, in: .zero)
        reference = nil
        inverted = nil
    }

    // MARK: HUD actions

    /// Immediate, with no animation between the slider and the layer.
    func setOpacity(_ value: Double) {
        let next = DesignOverlaySupport.clampedOpacity(value)
        guard next != opacity else { return }
        opacity = next
        canvas?.setOpacity(next)
        scheduleSave()
    }

    func setBlend(_ next: DesignOverlayBlend) {
        guard next != blend else { return }
        blend = next
        if next == .difference, !DesignOverlayDifference.hasPermission, !askedForScreenRecording {
            askedForScreenRecording = true
            CGRequestScreenCaptureAccess()
        }
        applyImage()
        syncDifference()
    }

    func setScaleChoice(_ next: DesignOverlayScaleChoice) {
        guard next != scaleChoice else { return }
        scaleChoice = next
        applyImage()
        layout()
        scheduleSave()
        scheduleDifference()
    }

    func setShowsGrid(_ shows: Bool) {
        showsGrid = shows
        applyGrid()
    }

    func setClickThrough(_ through: Bool) {
        clickThrough = through
        overlay?.ignoresMouseEvents = through
    }

    func setLocked(_ locked: Bool) {
        placement = placement.locking(locked)
        scheduleSave()
    }

    func nudge(_ direction: DesignOverlayNudge, large: Bool) {
        update(placement.nudged(direction, large: large))
    }

    func move(by delta: CGVector) {
        update(placement.moved(by: delta))
    }

    /// Puts the image's top left on the page (or window) under the pointer.
    func fitToWindowUnderCursor() {
        guard !placement.locked else { return }
        guard let match = DesignOverlayWindowFinder.contentUnderCursor() else {
            show(.noWindow)
            return
        }
        // The page may sit on another display: the overlay follows it there.
        var display = CGDirectDisplayID()
        var count: UInt32 = 0
        if CGGetDisplaysWithPoint(match.frame.origin, 1, &display, &count) == .success, count > 0, display != displayID {
            saveNow()
            displayID = display
            applyImage()
        }
        update(placement.moved(to: snapped(DesignOverlaySupport.offset(placing: match.frame.origin, in: displayBounds))))
        show(match.isPage ? .alignedPage : .alignedWindow)
    }

    private func update(_ next: DesignOverlayPlacement) {
        guard next != placement else { return }
        placement = next
        layout()
        scheduleSave()
        scheduleDifference()
    }

    private func snapped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: DesignOverlaySupport.snapped(point.x, displayScale: displayScale),
                y: DesignOverlaySupport.snapped(point.y, displayScale: displayScale))
    }

    private func show(_ note: Feedback) {
        feedback = note
        feedbackTask?.cancel()
        feedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            self?.feedback = nil
        }
    }

    // MARK: Drawing

    /// The image the layers show for the blend: the reference, or its
    /// inverse for Invert and for Difference while it cannot capture.
    private func applyImage() {
        guard let reference, let canvas else { return }
        let invertedNeeded = blend == .invert || (blend == .difference && !DesignOverlayDifference.hasPermission)
        if invertedNeeded, inverted == nil {
            inverted = DesignOverlayDifference.inverted(reference.image, context: context)
        }
        let image = invertedNeeded ? (inverted ?? reference.image) : reference.image
        canvas.setImage(image, size: pointSize, crisp: CGFloat(scale) == displayScale,
                        contentsScale: displayScale)
        canvas.setOpacity(opacity)
        if blend != .difference { canvas.setDifference(nil, in: .zero) }
        applyGrid()
    }

    private func applyGrid() {
        canvas?.setGrid(showsGrid ? grid.columnFrames(in: pointSize) : nil)
    }

    /// The window covers the part of the image on its display; the image
    /// layer sits inside it at the matching offset.
    private func layout() {
        guard let overlay, let canvas else { return }
        let frame = imageFrame
        let slice = frame.intersection(displayBounds)
        guard !slice.isNull, slice.width >= 1, slice.height >= 1 else {
            overlay.orderOut(nil)
            return
        }
        overlay.setFrame(DesignOverlaySupport.cocoaFrame(slice, primaryHeight: primaryHeight), display: false)
        canvas.frame = CGRect(origin: .zero, size: slice.size)
        canvas.setImageFrame(CGRect(x: frame.minX - slice.minX, y: frame.minY - slice.minY,
                                    width: frame.width, height: frame.height))
        if isVisible, !overlay.isVisible { overlay.orderFrontRegardless() }
    }

    // MARK: Difference

    /// Difference refreshes twice a second while it shows, and right after
    /// the image moves.
    private func syncDifference() {
        guard isVisible, blend == .difference else {
            stopDifference()
            return
        }
        guard DesignOverlayDifference.hasPermission else {
            stopDifference()
            show(.needsScreenRecording)
            return
        }
        refreshDifference()
        guard differenceLoop == nil else { return }
        differenceLoop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                self?.refreshDifference()
            }
        }
    }

    private func stopDifference() {
        differenceLoop?.cancel()
        differenceLoop = nil
        differencePending = false
    }

    private func scheduleDifference() {
        guard isVisible, blend == .difference else { return }
        refreshDifference()
    }

    private func refreshDifference() {
        guard isVisible, blend == .difference, let reference else { return }
        guard differenceTask == nil else {
            differencePending = true
            return
        }
        let frame = imageFrame
        let visible = frame.intersection(displayBounds)
        guard !visible.isNull, visible.width >= 1, visible.height >= 1 else { return }
        let crop = DesignOverlaySupport.referenceCrop(frame: frame, visible: visible, imageScale: scale)
        let display = displayID
        let density = displayScale
        let image = reference.image
        let local = CGRect(x: visible.minX - frame.minX, y: visible.minY - frame.minY,
                           width: visible.width, height: visible.height)
        differenceTask = Task { @MainActor [weak self] in
            let captured = await DesignOverlayDifference.capture(rect: visible, displayID: display, displayScale: density)
            guard let self else { return }
            self.differenceTask = nil
            if let captured, self.isVisible, self.blend == .difference, self.imageFrame == frame,
               let result = DesignOverlayDifference.difference(reference: image, crop: crop, captured: captured,
                                                                context: self.context) {
                self.canvas?.setDifference(result, in: local)
            }
            if self.differencePending {
                self.differencePending = false
                self.refreshDifference()
            }
        }
    }

    // MARK: Keyboard and screens

    private func installMonitors() {
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self, let hud = self.hud, event.window === hud.panel else { return false }
                    return self.handleKey(event)
                }
                return handled ? nil : event
            }
        }
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.screensChanged() }
            }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    /// Arrows nudge (Shift for 10), digits set the opacity, F fits, ⌘V
    /// pastes, Esc closes: while the HUD has the keyboard.
    private func handleKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if let direction = DesignOverlayNudge(keyCode: event.keyCode), modifiers.subtracting(.shift).isEmpty {
            nudge(direction, large: modifiers.contains(.shift))
            return true
        }
        if event.keyCode == 53, modifiers.isEmpty {
            close()
            return true
        }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if modifiers == .command, key == "v" {
            pasteFromClipboard()
            return true
        }
        guard modifiers.isEmpty else { return false }
        if key == "f" {
            fitToWindowUnderCursor()
            return true
        }
        if key.count == 1, let digit = Int(key), let value = DesignOverlaySupport.opacity(forDigit: digit) {
            setOpacity(value)
            return true
        }
        return false
    }

    /// A display that went away takes the overlay back to the main one.
    private func screensChanged() {
        guard isVisible else { return }
        var active = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &active, &count)
        if !active.prefix(Int(count)).contains(displayID) {
            displayID = CGMainDisplayID()
            if let record = memory.record(for: displayKey) {
                placement = DesignOverlayPlacement(offset: record.offset, locked: record.locked)
            }
        }
        applyImage()
        layout()
        scheduleDifference()
    }

    // MARK: Memory

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard reference != nil else { return }
        memory.save(DesignOverlayDisplayRecord(offset: placement.offset, opacity: opacity, scale: scaleChoice,
                                               locked: placement.locked),
                    for: displayKey)
    }
}
