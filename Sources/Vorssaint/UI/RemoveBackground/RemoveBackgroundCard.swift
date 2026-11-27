// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import SwiftUI

// Zenith fork: Remove Background's card, under the pointer like Translate's:
// a spinner while Vision works, then the result on a checkerboard with Reveal
// and Copy. It never activates Zenith; a click elsewhere or Escape closes it.

enum RemoveBackgroundCardContent {
    case working(String)
    case message(String)
    case result(summary: String, preview: CGImage?, files: [URL], pngs: [Data], copied: Bool)
}

@MainActor
final class RemoveBackgroundCardController {
    static let shared = RemoveBackgroundCardController()

    private var panel: RemoveBackgroundCardPanel?
    private var keyMonitor: Any?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var anchor: CGPoint?

    private init() {}

    func show(_ content: RemoveBackgroundCardContent) {
        let point = anchor ?? NSEvent.mouseLocation
        close()
        anchor = point
        let view = RemoveBackgroundCardView(content: content, actions: RemoveBackgroundCardActions(
            reveal: { [weak self] files in
                self?.close()
                NSWorkspace.shared.activateFileViewerSelecting(files)
            },
            copy: { [weak self] files, pngs in self?.copy(files: files, pngs: pngs) },
            close: { [weak self] in self?.close() }))
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let panel = RemoveBackgroundCardPanel(contentRect: CGRect(origin: .zero, size: size),
                                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
                                              defer: false)
        panel.contentView = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let visible = NSScreen.pointerVisibleFrame
        var origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height - 18)
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        self.panel = panel
        installMonitors(for: panel)
        panel.orderFrontRegardless()
        if case .working = content { return }
        panel.makeKey()
    }

    func close() {
        for monitor in [keyMonitor, localMonitor, globalMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        keyMonitor = nil
        localMonitor = nil
        globalMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        anchor = nil
    }

    private func copy(files: [URL], pngs: [Data]) {
        let all = pngs + files.compactMap { try? Data(contentsOf: $0) }
        close()
        RemoveBackgroundService.copy(pngs: all) { ok in
            if ok {
                QuickToolHUD.show(icon: "person.and.background.dotted",
                                  message: ZenithStrings.removeBackground(.enUS).copied)
            } else {
                ZenithQuiet.beep()
            }
        }
    }

    private func installMonitors(for panel: NSPanel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === panel, Int(event.keyCode) == kVK_Escape else { return event }
            MainActor.assumeIsolated { self?.close() }
            return nil
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== panel { MainActor.assumeIsolated { self?.close() } }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }
}

private final class RemoveBackgroundCardPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

struct RemoveBackgroundCardActions {
    let reveal: ([URL]) -> Void
    let copy: ([URL], [Data]) -> Void
    let close: () -> Void
}

struct RemoveBackgroundCardView: View {
    let content: RemoveBackgroundCardContent
    let actions: RemoveBackgroundCardActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let text = ZenithStrings.removeBackground(.enUS)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch content {
            case .working(let message):
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(message).font(.system(size: 12.5)).foregroundStyle(ZenithIsland.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            case .message(let message):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "person.and.background.dotted")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZenithStatus.info)
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(ZenithIsland.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case let .result(summary, preview, files, pngs, copied):
                if let preview {
                    RemoveBackgroundChecker()
                        .overlay(Image(decorative: preview, scale: 1).resizable().scaledToFit().padding(10))
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                let none = files.isEmpty && pngs.isEmpty
                HStack(spacing: 8) {
                    Image(systemName: none ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(none ? ZenithStatus.warning : ZenithStatus.success)
                    Text(summary)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(ZenithIsland.primary)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    if !files.isEmpty {
                        Button(text.reveal) { actions.reveal(files) }
                            .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                    }
                    if !none {
                        Button(copied ? text.copied : text.copy) { actions.copy(files, pngs) }
                            .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 340)
        .modifier(QRCardChrome(cornerRadius: 20))
        .modifier(QRArrival(shown: shown, reduceMotion: reduceMotion))
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMorph.animation) { shown = true }
        }
    }
}

/// The transparent checkerboard a cutout sits on.
struct RemoveBackgroundChecker: View {
    var square: CGFloat = 8
    var light = Color(white: 0.32)
    var dark = Color(white: 0.22)

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dark))
            let columns = Int(size.width / square) + 1, rows = Int(size.height / square) + 1
            var path = Path()
            for row in 0..<rows {
                for column in 0..<columns where (row + column) % 2 == 0 {
                    path.addRect(CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square))
                }
            }
            context.fill(path, with: .color(light))
        }
        .accessibilityHidden(true)
    }
}
