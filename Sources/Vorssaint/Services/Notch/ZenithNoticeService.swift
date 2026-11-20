// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import QuickLookThumbnailing
import SwiftUI

// Zenith fork: presents capsule notices. Sources report here (the island's
// power reading, the accessory connection monitor, the download service); the
// queue in ZenithNoticeSupport decides what shows. The capsule lives in a
// window of its own above the closed island, starting from the island's own
// outline and returning to it, so the island's shape, its transitions and its
// strips stay untouched underneath.

/// The capsule's outline in the window, top-left origin: its frame and the
/// island's corners it grows from, as the shape draws them.
struct ZenithNoticeOutline: Equatable {
    var rect: CGRect
    /// Hangs from the top edge with the island's shoulders, or floats as a pill.
    var hanging: Bool
    var shoulder: CGFloat
    var radius: CGFloat
}

final class ZenithNoticeCenter: ObservableObject {
    static let shared = ZenithNoticeCenter()

    // What the view draws.
    @Published private(set) var notice: ZenithNotice?
    /// Bumped when the notice on screen is replaced in place.
    @Published private(set) var revision = 0
    @Published private(set) var outline = ZenithNoticeOutline(rect: .zero, hanging: false, shoulder: 0, radius: 0)
    /// The row the content takes, in the window.
    @Published private(set) var row = CGRect.zero
    @Published private(set) var contentShown = false
    @Published private(set) var surfaceOpacity = 1.0
    @Published private(set) var panelSize = CGSize.zero
    @Published private(set) var lowPowerOn = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published private(set) var thumbnails: [URL: NSImage] = [:]

    private var queue = ZenithNoticeQueue()
    private var battery = ZenithBatteryNoticeState()
    private var panel: NotchPanel?
    private var generation = 0
    private var phase = Phase.idle
    private var dismissWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var shownAt: TimeInterval = 0
    private var hoveredUntil: TimeInterval = 0
    private var mouseMonitors: [Any] = []
    private var islandSubscriptions: Set<AnyCancellable> = []
    private var powerObserver: NSObjectProtocol?
    private var gesture = NotchGestureSupport()
    /// Headphones waiting a moment for their first battery reading.
    private var audioWaits: [String: (work: DispatchWorkItem, subscription: AnyCancellable?)] = [:]
    /// The screen frame the capsule grows to, and the window it is drawn in.
    private var capsuleFrame = CGRect.zero
    private var panelFrame = CGRect.zero

    private enum Phase { case idle, growing, shown, leaving }

    private init() {}

    private var text: ZenithNoticeStrings { ZenithStrings.notices(L10n.shared.language) }
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    // MARK: Sources

    /// The island's power reading changed. Returns whether a capsule takes the
    /// place of the island's small battery notice for this change.
    @discardableResult
    func handlePower(before: PowerReading, next: PowerReading) -> Bool {
        let settings = ZenithBatterySettings.current()
        let previous = Self.reading(before), reading = Self.reading(next)
        let events = battery.update(reading, previous: previous, settings: settings)
        guard NotchSupport.routes(.battery) else { return false }
        for event in events { enqueue(notice(for: event, reading: next)) }
        return ZenithBatteryNoticeState.replacesSmallNotice(before: previous, after: reading, settings: settings)
    }

    /// An accessory connected. Returns whether a capsule shows it, so the
    /// island's small notice stays away. Only headphones and speakers get one.
    @discardableResult
    func accessoryConnected(name: String, majorClass: UInt32, minorClass: UInt32) -> Bool {
        let symbol = NotchAccessorySupport.symbol(name: name, majorClass: majorClass, minorClass: minorClass)
        guard ZenithAudioNotice.isAudio(symbol: symbol), UserDefaults.standard.bool(forKey: DefaultsKey.notchNoticeAudio),
              NotchSupport.routes(.accessory), !name.isEmpty else { return false }
        let key = ZenithNoticeKey.audio(name)
        if let percent = audioPercent(name) {
            enqueue(audioNotice(name: name, symbol: symbol, percent: percent))
            return true
        }
        // Bluetooth batteries are read every so often; a reading that lands
        // soon after the connection still makes the first notice, and one
        // that lands while it shows fills its ring.
        audioWaits[key]?.work.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.audioWaits[key] = nil
            self.enqueue(self.audioNotice(name: name, symbol: symbol, percent: self.audioPercent(name)))
        }
        let subscription = SystemMonitor.shared.$snapshot.map(\.peripheralBatterySample).removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let percent = self.audioPercent(name), let wait = self.audioWaits[key] else { return }
                wait.work.cancel()
                self.audioWaits[key] = nil
                self.enqueue(self.audioNotice(name: name, symbol: symbol, percent: percent))
            }
        audioWaits[key] = (work, subscription)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
        return true
    }

    /// A download finished. Returns whether a capsule shows it.
    @discardableResult
    func downloadFinished(_ url: URL, name: String) -> Bool {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.notchNoticeDownload), NotchSupport.routes(.download) else {
            return false
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        let bytes = values?.isDirectory == true ? nil : values?.fileSize.map(Int64.init)
        let folder = FileManager.default.displayName(atPath: url.deletingLastPathComponent().path)
        requestThumbnail(url)
        enqueue(ZenithNotice(kind: .download, key: ZenithNoticeKey.download(url),
                             title: name.isEmpty ? url.lastPathComponent : name,
                             subtitle: ZenithNoticeFormat.downloadDetail(bytes: bytes, folder: folder),
                             glyph: .file(url), accessory: .checkmark, action: .reveal(url)))
        return true
    }

    /// A camera card mounted (CardImportService). Returns whether a capsule shows it.
    @discardableResult
    func cardInserted(volume: String, title: String, subtitle: String) -> Bool {
        guard CardImportOptions.isEnabled() else { return false }
        enqueue(ZenithNotice(kind: .card, key: ZenithNoticeKey.card(volume), title: title, subtitle: subtitle,
                             glyph: .symbol("sdcard.fill", .tint(NotchModule.cardImport)),
                             accessory: .action(ZenithStrings.cardImport(L10n.shared.language).importAction),
                             action: .importCard(volume)))
        return true
    }

    /// The card left before anyone answered: its notice goes too.
    func cardRemoved(volume: String) {
        let key = ZenithNoticeKey.card(volume)
        queue.removeAll { $0.key == key }
        if notice?.key == key { dismiss(quickly: true) }
    }

    /// An export finished (ExportTrackerService): its title, the file and its
    /// size below, the file's thumbnail, and a click reveals it.
    func exportFinished(_ url: URL, key: String, title: String, subtitle: String) {
        guard ExportTrackerSupport.isEnabled() else { return }
        requestThumbnail(url)
        enqueue(ZenithNotice(kind: .export, key: ZenithNoticeKey.export(key), title: title, subtitle: subtitle,
                             glyph: .file(url), accessory: .checkmark, action: .reveal(url)))
    }

    /// A dev server started (DevServersService): `Next.js · Swift-portfolio ·
    /// localhost:3000`, and Open as the click. Returns whether a capsule shows it.
    @discardableResult
    func devServerStarted(_ server: DevServer) -> Bool {
        guard DevServersOptions.current().announces, DevServersOptions.isEnabled(), let url = server.url else { return false }
        let text = ZenithStrings.devServers(L10n.shared.language)
        enqueue(ZenithNotice(kind: .devServer, key: ZenithNoticeKey.devServer(server.coalescingKey),
                             title: DevServersFormat.noticeTitle(server), subtitle: text.started,
                             glyph: .symbol(NotchModule.devServers.zenithIconSymbol, .tint(NotchModule.devServers)),
                             accessory: .action(text.open), action: .openURL(url)))
        return true
    }

    private static func reading(_ power: PowerReading) -> ZenithBatteryReading {
        ZenithBatteryReading(percent: power.chargePercent, external: power.externalConnected, charging: power.isCharging)
    }

    private func notice(for event: ZenithBatteryEvent, reading: PowerReading) -> ZenithNotice {
        let text = text
        switch event {
        case let .low(percent, critical):
            return ZenithNotice(kind: critical ? .batteryCritical : .batteryLow, key: ZenithNoticeKey.batteryLow,
                                title: ZenithNoticeFormat.filling(text.batteryTitle, percent: percent),
                                subtitle: lowPowerOn ? text.lowPowerOn : text.lowPowerAction,
                                accessory: .lowPower(on: lowPowerOn), action: .batterySettings)
        case let .charging(percent):
            return ZenithNotice(kind: .charging, key: ZenithNoticeKey.power,
                                title: ZenithNoticeFormat.titled(text.charging, percent: percent),
                                subtitle: text.chargerConnected,
                                glyph: .symbol("bolt.fill", .green),
                                accessory: percent.map { .ring(percent: $0, tone: .green) } ?? .none)
        case let .unplugged(percent):
            return ZenithNotice(kind: .unplugged, key: ZenithNoticeKey.power,
                                title: ZenithNoticeFormat.titled(text.onBattery, percent: percent),
                                subtitle: text.chargerRemoved,
                                glyph: .symbol("powerplug", .white),
                                accessory: percent.map { .ring(percent: $0, tone: ZenithNoticeFormat.batteryTone($0)) } ?? .none)
        case let .chargeLimit(percent):
            return ZenithNotice(kind: .chargeLimit, key: ZenithNoticeKey.chargeLimit,
                                title: ZenithNoticeFormat.titled(text.charging, percent: percent),
                                subtitle: text.chargeHint,
                                glyph: .symbol("leaf.fill", .green),
                                accessory: .ring(percent: percent, tone: .green))
        }
    }

    private func audioNotice(name: String, symbol: String, percent: Int?) -> ZenithNotice {
        ZenithNotice(kind: .audio, key: ZenithNoticeKey.audio(name), title: name, subtitle: text.connected,
                     glyph: .symbol(symbol, .white),
                     accessory: percent.map { .ring(percent: $0, tone: ZenithNoticeFormat.batteryTone($0)) } ?? .none)
    }

    private func audioPercent(_ name: String) -> Int? {
        let devices = SystemMonitor.shared.snapshot.peripheralBatterySample.devices
        return ZenithAudioNotice.batteryPercent(named: name, in: devices.map { ($0.name, $0.percent) })
    }

    private func requestThumbnail(_ url: URL) {
        guard thumbnails[url] == nil else { return }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let side = ZenithNoticeLayout.glyph + 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side), scale: scale,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let image = representation?.cgImage else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Only the files that can still show keep a thumbnail.
                self.thumbnails = self.thumbnails.filter { key, _ in self.isWanted(key) }
                self.thumbnails[url] = NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width) / scale,
                                                                            height: CGFloat(image.height) / scale))
            }
        }
    }

    private func isWanted(_ url: URL) -> Bool {
        if notice?.glyph == .file(url) { return true }
        return queue.pending.contains { $0.notice.glyph == .file(url) }
    }

    // MARK: Queue

    private func enqueue(_ incoming: ZenithNotice) {
        var incoming = incoming
        // A low battery notice reads Low Power Mode as it shows.
        if case .lowPower = incoming.accessory { incoming = refreshedLowPower(incoming) }
        switch queue.enqueue(incoming, now: now) {
        case .updatedCurrent:
            guard phase == .growing || phase == .shown else {
                // The one leaving cannot take it any more; it waits its turn.
                queue.finishCurrent()
                _ = queue.enqueue(incoming, now: now)
                presentNextIfPossible()
                return
            }
            notice = incoming
            revision += 1
            scheduleDismissal(after: incoming.duration)
        case .preempts:
            if phase == .shown || phase == .growing { dismiss(quickly: true) }
        case .queued, .coalesced:
            break
        }
        presentNextIfPossible()
    }

    /// Whether the closed island is free to grow a capsule: on, showing what
    /// happens, closed and not busy with a drag, capture or another notice.
    private var islandAllows: Bool {
        let island = NotchService.shared
        return island.running && island.showsSystemFeedback && !island.expanded && !island.peeking
            && !island.dragPlaceholder && island.captureControls == nil && !island.fullscreenCompact
            && !island.showsCompactActivityPicker && !island.showingCommandBar
    }

    private func presentNextIfPossible() {
        guard phase == .idle else { return }
        retryWork?.cancel(); retryWork = nil
        // Waiting ends when nothing is left that is still news.
        queue.prune(now: now)
        guard !queue.isEmpty else { return }
        // A small notice already on the island, as the volume, finishes first.
        guard islandAllows, NotchService.shared.notice == nil else {
            let work = DispatchWorkItem { [weak self] in self?.presentNextIfPossible() }
            retryWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            return
        }
        guard let next = queue.next(now: now) else { return }
        present(next)
    }

    // MARK: Presentation

    private func present(_ next: ZenithNotice) {
        generation += 1
        let token = generation
        let island = NotchService.shared
        let geometry = island.geometry
        let closed = closedIslandFrame()
        let capsule = ZenithNoticeLayout.frame(screen: geometry.screen, centerX: geometry.screen.midX,
                                               closedWidth: closed.width, floats: geometry.floats,
                                               top: geometry.floats ? geometry.floatingDrop + (geometry.floatingGap ?? 0) : 0,
                                               stripHeight: geometry.stripHeight)
        capsuleFrame = capsule
        panelFrame = capsule.union(closed).integral
        let panel = panel ?? makePanel()
        panel.setFrame(panelFrame, display: false)
        panelSize = panelFrame.size

        let start = outline(closedFrame: closed, closed: true)
        let end = outline(closedFrame: capsule, closed: false)
        let rowTop = ZenithNoticeLayout.rowTop(floats: geometry.floats, stripHeight: geometry.stripHeight)
        row = CGRect(x: end.rect.minX + end.shoulder, y: end.rect.minY + rowTop,
                     width: end.rect.width - end.shoulder * 2, height: ZenithNoticeLayout.rowHeight)
        lowPowerOn = ProcessInfo.processInfo.isLowPowerModeEnabled
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            notice = next
            contentShown = false
            outline = reduceMotion ? end : start
            surfaceOpacity = reduceMotion ? 0 : 1
        }
        phase = .growing
        shownAt = now
        panel.orderFrontRegardless()
        watchIsland()
        installMouseMonitors()

        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == token else { return }
            if self.reduceMotion {
                withAnimation(.easeOut(duration: ZenithNoticeTiming.fade)) {
                    self.surfaceOpacity = 1
                    self.contentShown = true
                }
                self.phase = .shown
                return
            }
            withAnimation(.spring(response: ZenithNoticeTiming.springResponse,
                                  dampingFraction: ZenithNoticeTiming.springDamping)) { self.outline = end }
            DispatchQueue.main.asyncAfter(deadline: .now() + ZenithNoticeTiming.contentDelay) { [weak self] in
                guard let self, self.generation == token, self.phase == .growing else { return }
                self.contentShown = true
                self.phase = .shown
            }
        }
        scheduleDismissal(after: next.duration)
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: next.accessibilityText, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    /// The closed island's surface on screen, which the capsule grows from
    /// and returns to: the floating capsule's body, or the hanging strip.
    private func closedIslandFrame() -> CGRect {
        let island = NotchService.shared
        let geometry = island.geometry
        let size = island.surfaceSize
        let frame = CGRect(x: geometry.screen.midX + island.surfaceShift - size.width / 2,
                           y: geometry.screen.maxY - geometry.floatingDrop - size.height,
                           width: size.width, height: size.height)
        guard let gap = geometry.floatingGap else { return frame }
        // Flipped to the layout's top-left space and back, as the capsule is drawn.
        let body = NotchLayout.capsuleBody(in: CGRect(origin: .zero, size: size), gap: gap)
        return CGRect(x: frame.minX + body.minX, y: frame.maxY - body.maxY, width: body.width, height: body.height)
    }

    /// An outline in the window for a frame on screen. Closed, it keeps the
    /// island's own corners; grown, a floating one is a full pill and a
    /// hanging one rounds the row below the camera by half its height.
    private func outline(closedFrame frame: CGRect, closed: Bool) -> ZenithNoticeOutline {
        let geometry = NotchService.shared.geometry
        let rect = CGRect(x: frame.minX - panelFrame.minX, y: panelFrame.maxY - frame.maxY,
                          width: frame.width, height: frame.height)
        if geometry.floats {
            return ZenithNoticeOutline(rect: rect, hanging: false, shoulder: 0, radius: frame.height / 2)
        }
        // The notice's own capsule keeps upstream's shoulder: only the open
        // island flares (ZenithIslandSilhouette).
        let shoulder = NotchLayout.plainShoulder(height: frame.height)
        let radius = closed ? NotchLayout.surfaceRadius(height: frame.height) : ZenithNoticeLayout.rowHeight / 2
        return ZenithNoticeOutline(rect: rect, hanging: true, shoulder: shoulder, radius: radius)
    }

    private func scheduleDismissal(after delay: TimeInterval) {
        dismissWork?.cancel()
        let token = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            // The pointer on the capsule holds it, a little past leaving it.
            if self.capsuleFrame.contains(NSEvent.mouseLocation) { self.hoveredUntil = self.now + ZenithNoticeTiming.hoverGrace }
            if self.hoveredUntil > self.now {
                self.scheduleDismissal(after: max(0.25, self.hoveredUntil - self.now))
                return
            }
            self.dismiss()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// The content blurs out in reverse, then the shape shrinks back into the
    /// island as it is now. `quickly` skips the hold for a notice that outranks it.
    func dismiss(quickly: Bool = false) {
        guard phase == .growing || phase == .shown else { return }
        dismissWork?.cancel(); dismissWork = nil
        phase = .leaving
        generation += 1
        let token = generation
        removeMouseMonitors()
        if reduceMotion {
            withAnimation(.easeOut(duration: ZenithNoticeTiming.fade)) { surfaceOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + ZenithNoticeTiming.fade) { [weak self] in
                guard let self, self.generation == token else { return }
                self.finish()
            }
            return
        }
        contentShown = false
        let closed = closedIslandFrame()
        // The island may have changed while the capsule covered it; the
        // window stays as it is, so the shrink ends inside it.
        let target = outline(closedFrame: closed.intersection(panelFrame).isNull ? closed : closed.intersection(panelFrame),
                             closed: true)
        let contentOut = quickly ? 0.08 : ZenithNoticeTiming.contentOut
        DispatchQueue.main.asyncAfter(deadline: .now() + contentOut) { [weak self] in
            guard let self, self.generation == token else { return }
            withAnimation(.spring(response: ZenithNoticeTiming.springResponse * 0.85, dampingFraction: 1)) {
                self.outline = target
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + ZenithNoticeTiming.shrink) { [weak self] in
                guard let self, self.generation == token else { return }
                self.finish()
            }
        }
    }

    private func finish() {
        panel?.orderOut(nil)
        islandSubscriptions.removeAll()
        stopLowPowerObserver()
        notice = nil
        contentShown = false
        phase = .idle
        queue.finishCurrent()
        hoveredUntil = 0
        thumbnails = thumbnails.filter { key, _ in isWanted(key) }
        DispatchQueue.main.asyncAfter(deadline: .now() + ZenithNoticeTiming.gap) { [weak self] in
            self?.presentNextIfPossible()
        }
    }

    /// The island opening, or a notice the person caused (volume, brightness,
    /// a layout switch), takes the place at once.
    private func watchIsland() {
        islandSubscriptions.removeAll()
        let island = NotchService.shared
        Publishers.CombineLatest4(island.$expanded, island.$peeking, island.$dragPlaceholder, island.$hiddenInFullscreen)
            .dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] expanded, peeking, drag, fullscreen in
                guard expanded || peeking || drag || fullscreen else { return }
                self?.dismiss(quickly: true)
            }.store(in: &islandSubscriptions)
        island.$notice.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] shown in
                guard let shown, shown.event.priority >= 3 else { return }
                self?.dismiss(quickly: true)
            }.store(in: &islandSubscriptions)
        if case .lowPower = notice?.accessory { startLowPowerObserver() }
    }

    // MARK: Low Power Mode

    private func refreshedLowPower(_ notice: ZenithNotice) -> ZenithNotice {
        var notice = notice
        let on = ProcessInfo.processInfo.isLowPowerModeEnabled
        notice.accessory = .lowPower(on: on)
        notice.subtitle = on ? text.lowPowerOn : text.lowPowerAction
        return notice
    }

    /// Turned on in System Settings while the notice shows, its switch follows.
    private func startLowPowerObserver() {
        guard powerObserver == nil else { return }
        powerObserver = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil,
                                                               queue: .main) { [weak self] _ in
            guard let self, let shown = self.notice, case .lowPower = shown.accessory else { return }
            self.lowPowerOn = ProcessInfo.processInfo.isLowPowerModeEnabled
            let refreshed = self.refreshedLowPower(shown)
            guard refreshed != shown else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { self.notice = refreshed }
        }
    }

    private func stopLowPowerObserver() {
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        powerObserver = nil
    }

    // MARK: Interaction

    /// A click on the capsule does what it offers, then lets it go.
    func activate() {
        guard let shown = notice, phase == .growing || phase == .shown else { return }
        switch shown.action {
        case .none:
            break
        case .batterySettings:
            // Low Power Mode needs an administrator, and the privileged helper
            // only drives the fans; Battery settings has the switch itself.
            if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        case .reveal(let url):
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        case .importCard(let volume):
            // Zenith fork: after the capsule has gone, so the island opens on its own.
            dismiss(quickly: true)
            DispatchQueue.main.async { CardImportService.shared.openImport(volume: volume) }
            return
        case .openURL(let url):
            if !NSWorkspace.shared.open(url) { NSSound.beep() }
        }
        dismiss(quickly: true)
    }

    private func installMouseMonitors() {
        removeMouseMonitors()
        // A click anywhere else lets the capsule go.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss() }
        }) { mouseMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if let self, event.window !== self.panel { self.dismiss() }
            return event
        }) { mouseMonitors.append(local) }
    }

    private func removeMouseMonitors() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
    }

    /// With the island's gestures on, swiping up on the capsule sends it back.
    private func handleScroll(_ event: NSEvent) -> Bool {
        guard NotchGestureSupport.isEnabled(), phase == .shown || phase == .growing else { return false }
        let x = NotchGestureSupport.movement(Double(event.scrollingDeltaX), precise: event.hasPreciseScrollingDeltas,
                                             inverted: event.isDirectionInvertedFromDevice)
        let y = NotchGestureSupport.movement(Double(event.scrollingDeltaY), precise: event.hasPreciseScrollingDeltas,
                                             inverted: event.isDirectionInvertedFromDevice)
        let action = gesture.handle(x: x, y: y, timestamp: event.timestamp,
                                    began: event.phase.contains(.began),
                                    ended: !event.phase.intersection([.ended, .cancelled]).isEmpty,
                                    momentum: !event.momentumPhase.isEmpty,
                                    precise: event.hasPreciseScrollingDeltas, hasPhase: !event.phase.isEmpty,
                                    allowVertical: true, allowHorizontal: false, expanded: true)
        guard action == .close else { return true }
        gesture = NotchGestureSupport()
        dismiss(quickly: true)
        return true
    }

    // MARK: Window

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(contentRect: panelFrame, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // Just above the island, still below native menus.
        panel.level = NSWindow.Level(rawValue: NotchPanel.normalLevel.rawValue + 1)
        panel.collectionBehavior = NotchPanel.overlayCollectionBehavior
        panel.handleScroll = { [weak self] event in self?.handleScroll(event) ?? false }
        let host = ZenithNoticeHostingView(rootView: ZenithNoticeRoot(center: self))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        self.panel = panel
        return panel
    }

    /// Settings changed: what waits for a notice that is now off goes.
    func syncWithPreferences() {
        let defaults = UserDefaults.standard
        let settings = ZenithBatterySettings.current(in: defaults)
        queue.removeAll { notice in
            switch notice.kind {
            case .batteryLow: return !settings.lowOn
            case .batteryCritical: return !settings.criticalOn
            case .charging, .unplugged: return !settings.chargerOn
            case .chargeLimit: return !settings.highOn
            case .audio: return !defaults.bool(forKey: DefaultsKey.notchNoticeAudio)
            case .download: return !defaults.bool(forKey: DefaultsKey.notchNoticeDownload)
            case .card: return !CardImportOptions.isEnabled(in: defaults)
            case .export: return !ExportTrackerSupport.isEnabled(in: defaults)
            case .devServer:
                let options = DevServersOptions.current(in: defaults)
                return !options.enabled || !options.announces
            }
        }
    }
}

/// The capsule takes the first click, as the island does, while another app is active.
private final class ZenithNoticeHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
