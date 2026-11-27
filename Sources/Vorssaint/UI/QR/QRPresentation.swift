// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import SwiftUI

// Zenith fork: a code presented for a room of phones. It covers the display
// with the pointer in near black and holds the code large in the middle, on
// white, with its text under it; Esc or a click puts everything back.

final class QRPresentationController {
    static let shared = QRPresentationController()

    private var window: QRPresentationWindow?
    private var keyMonitor: Any?
    private let state = QRPresentationState()

    private init() {}

    func present(_ payload: String) {
        guard let matrix = QRService.shared.matrix(payload, correction: QRSettings.correction()) else {
            ZenithQuiet.beep()
            return
        }
        dismiss(animated: false)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let window = QRPresentationWindow(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                          backing: .buffered, defer: false)
        state.shown = false
        let view = QRPresentationView(matrix: matrix, logo: QRSettings.logo(), payload: payload, state: state,
                                      close: { [weak self] in self?.dismiss(animated: true) })
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.setFrame(screen.frame, display: false)
        self.window = window
        window.orderFrontRegardless()
        window.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === window else { return event }
            if Int(event.keyCode) == kVK_Escape || Int(event.keyCode) == kVK_Return || Int(event.keyCode) == kVK_Space {
                self?.dismiss(animated: true)
                return nil
            }
            return event
        }
        DispatchQueue.main.async { self.state.shown = true }
    }

    func dismiss(animated: Bool) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        guard let window else { return }
        self.window = nil
        state.shown = false
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { window.orderOut(nil) }
        } else {
            window.orderOut(nil)
        }
    }
}

final class QRPresentationWindow: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

final class QRPresentationState: ObservableObject {
    @Published var shown = false
}

private struct QRPresentationView: View {
    let matrix: QRMatrix
    let logo: Bool
    let payload: String
    @ObservedObject var state: QRPresentationState
    let close: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height) * 0.64
            ZStack {
                Color.black.opacity(0.94)
                    .opacity(state.shown ? 1 : 0)
                VStack(spacing: 22) {
                    QRCodeView(matrix: matrix, logo: logo)
                        .frame(width: side, height: side)
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                        .modifier(QRArrival(shown: state.shown, reduceMotion: reduceMotion))
                    Text(payload.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " "))
                        .font(ZenithType.mono(max(14, side * 0.03)))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: side)
                        .opacity(state.shown ? 1 : 0)
                    Text(ZenithStrings.qr(l10n.language).presentHint)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .opacity(state.shown ? 1 : 0)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast)
                   : .spring(response: 0.46, dampingFraction: 0.86), value: state.shown)
    }
}
