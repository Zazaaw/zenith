// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import SwiftUI

// Zenith fork: what a code read off the screen holds, before anything is
// done with it. The whole text is spelled out; a link names where it goes
// and says when that deserves a second look (http, an IP address, a name
// hidden before an @, lookalike letters, or not a web page at all). Copy
// always works; Open is only offered for a web address and is not the
// default action while there is a warning. Esc or a click elsewhere closes.

final class QRScanResultController {
    static let shared = QRScanResultController()

    private var panel: QRScanResultPanel?
    private var keyMonitor: Any?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    private init() {}

    func show(_ payloads: [String]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show(payloads) }
            return
        }
        close()
        guard !payloads.isEmpty else { return }
        let view = QRScanResultView(payloads: Array(payloads.prefix(3)),
                                    copy: { [weak self] payload in self?.copy(payload) },
                                    open: { [weak self] url in self?.open(url) },
                                    showCode: { [weak self] payload in
                                        self?.close()
                                        QRService.shared.show(QRDetector.detect(payload) ?? .text(payload))
                                    })
        let host = NSHostingController(rootView: view)
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize
        let panel = QRScanResultPanel(contentRect: CGRect(origin: .zero, size: size),
                                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentViewController = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let visible = NSScreen.pointerVisibleFrame
        let pointer = NSEvent.mouseLocation
        var origin = CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height - 18)
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        self.panel = panel
        installMonitors(for: panel)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        for monitor in [keyMonitor, localMonitor, globalMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
        localMonitor = nil
        globalMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func copy(_ payload: String) {
        close()
        GeneralPasteboardAccess.shared.async({ () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareVorssaintSource()
            return pasteboard.setString(payload, forType: .string)
        }, then: { ok in
            if ok { QuickToolHUD.show(icon: "qrcode", message: L10n.shared.s.ocrQRCopied) } else { ZenithQuiet.beep() }
        })
    }

    private func open(_ url: URL) {
        close()
        NSWorkspace.shared.open(url)
    }

    private func installMonitors(for panel: NSPanel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === panel else { return event }
            if Int(event.keyCode) == kVK_Escape {
                self?.close()
                return nil
            }
            return event
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.panel { self?.close() }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }
}

private final class QRScanResultPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

private struct QRScanResultView: View {
    let payloads: [String]
    let copy: (String) -> Void
    let open: (URL) -> Void
    let showCode: (String) -> Void
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var text: ZenithQRStrings { ZenithStrings.qr(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                ZenithIslandGlyphTile(symbol: "qrcode.viewfinder", tint: ZenithIslandPalette.color(hex: 0xC4B5FD), size: 24)
                Text(text.scanFound)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZenithIsland.primary)
            }
            ForEach(Array(payloads.enumerated()), id: \.offset) { index, payload in
                if index > 0 { ZenithBentoDivider(.horizontal) }
                item(payload, primary: index == 0)
            }
        }
        .padding(16)
        .frame(width: 380)
        .modifier(QRCardChrome(cornerRadius: 20))
        .modifier(QRArrival(shown: shown, reduceMotion: reduceMotion))
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMorph.animation) { shown = true }
        }
    }

    @ViewBuilder private func item(_ payload: String, primary: Bool) -> some View {
        let url = QRLinkSafety.openableURL(payload)
        let flags = QRLinkSafety.flags(payload)
        let kind = QRDetector.detect(payload)?.kind ?? .text
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol).font(.system(size: 10, weight: .semibold))
                Text(title(kind).uppercased()).font(ZenithType.mono(9.5, weight: .medium)).tracking(0.4)
            }
            .foregroundStyle(ZenithIsland.label)

            ScrollView(.vertical) {
                Text(payload)
                    .font(ZenithType.mono(11.5))
                    .foregroundStyle(ZenithIsland.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
            }
            .frame(maxHeight: 120)
            .fixedSize(horizontal: false, vertical: true)
            .zenithIslandSoftCard(cornerRadius: 12)

            if let host = url?.host {
                HStack(spacing: 6) {
                    Text(text.goesTo)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                    Text(host)
                        .font(ZenithType.mono(11.5, weight: .semibold))
                        .foregroundStyle(ZenithIsland.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            if !flags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(flags, id: \.self) { flag in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10.5))
                                .foregroundStyle(ZenithStatus.warning)
                            Text(words(flag))
                                .font(.system(size: 11.5))
                                .foregroundStyle(ZenithIsland.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ZenithStatus.fill(ZenithStatus.warning)))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(ZenithStatus.stroke(ZenithStatus.warning), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
            }
            HStack(spacing: 8) {
                Button(text.showCode) { showCode(payload) }
                    .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                Spacer(minLength: 0)
                if let url, flags.isEmpty, primary {
                    Button(text.copy) { copy(payload) }
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                    Button(text.open) { open(url) }
                        .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                        .keyboardShortcut(.defaultAction)
                } else if let url {
                    // With a warning, Return copies; opening takes a deliberate click.
                    if primary {
                        Button(text.copy) { copy(payload) }
                            .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button(text.copy) { copy(payload) }
                            .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                    }
                    Button(text.open) { open(url) }
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                } else if primary {
                    Button(text.copy) { copy(payload) }
                        .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(text.copy) { copy(payload) }
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                }
            }
        }
    }

    private func title(_ kind: QRPayloadKind) -> String {
        switch kind {
        case .url: return text.kindURL
        case .text: return text.kindText
        case .wifi: return text.kindWiFi
        case .whatsapp: return text.kindWhatsApp
        case .contact: return text.kindContact
        }
    }

    private func words(_ flag: QRLinkFlag) -> String {
        switch flag {
        case .notHTTPS: return text.flagHTTP
        case .ipAddress: return text.flagIP
        case .userInfo: return text.flagUserInfo
        case .lookalike: return text.flagLookalike
        case .notWeb: return text.flagNotWeb
        }
    }
}
