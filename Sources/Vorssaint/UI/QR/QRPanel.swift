// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Carbon.HIToolbox
import SwiftUI

// Zenith fork: the QR page, a floating card beside whatever is in front. The
// code sits large on its white tile on the left with its text below it and
// four actions (copy the picture, save PNG or SVG, present it full screen,
// share it); the kind of code and its fields are on the right, with the
// last codes made under them. It takes the keyboard for its fields without
// bringing the app forward, and Esc closes it.

final class QRPanelController {
    static let shared = QRPanelController()

    private var panel: QRPanelWindow?
    private let model = QRPanelModel()
    private var keyMonitor: Any?

    private init() {}

    static let size = CGSize(width: 640, height: 470)

    var window: NSWindow? { panel }

    /// Opens the page on `content` (or a fresh link field), or brings it
    /// forward with the new content when it is already open.
    func show(_ content: QRContent?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show(content) }
            return
        }
        model.load(content)
        if let content, let payload = content.payload { QRService.shared.record(payload) }
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = panel ?? makePanel()
        self.panel = panel
        place(panel)
        model.presented = false
        panel.orderFrontRegardless()
        panel.makeKey()
        installMonitor(for: panel)
        DispatchQueue.main.async { self.model.presented = true }
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        if let payload = model.content.payload { QRService.shared.record(payload) }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        model.presented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self, !self.model.presented else { return }
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> QRPanelWindow {
        let panel = QRPanelWindow(contentRect: CGRect(origin: .zero, size: Self.size),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
        let host = NSHostingView(rootView: QRPanelView(model: model, close: { [weak self] in self?.close() }))
        host.frame = CGRect(origin: .zero, size: Self.size)
        panel.contentView = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    /// Centred on the display with the pointer, a little above the middle.
    private func place(_ panel: NSPanel) {
        let visible = NSScreen.pointerVisibleFrame
        let size = Self.size
        let origin = CGPoint(x: visible.midX - size.width / 2,
                             y: min(visible.maxY - size.height - 24, visible.midY - size.height / 2 + visible.height * 0.08))
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }

    private func installMonitor(for panel: NSPanel) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === panel else { return event }
            let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            if Int(event.keyCode) == kVK_Escape || (command && event.charactersIgnoringModifiers == "w") {
                self?.close()
                return nil
            }
            return event
        }
    }
}

/// Borderless, non-activating, yet able to take the keyboard for its fields.
final class QRPanelWindow: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Model

final class QRPanelModel: ObservableObject {
    @Published var kind: QRPayloadKind = .url
    @Published var url = ""
    @Published var text = ""
    @Published var wifi = QRWiFi()
    @Published var whatsapp = QRWhatsApp(countryCode: QRWhatsApp.callingCode(region: Locale.current.region?.identifier))
    @Published var contact = QRContact()
    /// Bumped whenever a code is put in from outside (opened, picked from
    /// the list, a new kind), which is when it arrives with the morph;
    /// typing changes the code in place.
    @Published private(set) var arrival = 0
    @Published var presented = false

    var content: QRContent {
        switch kind {
        case .url: return .url(url)
        case .text: return .text(text)
        case .wifi: return .wifi(wifi)
        case .whatsapp: return .whatsapp(whatsapp)
        case .contact: return .contact(contact)
        }
    }

    func load(_ content: QRContent?) {
        switch content {
        case .url(let value)?: url = value
        case .text(let value)?: text = value
        case .wifi(let value)?: wifi = value
        case .whatsapp(let value)?:
            whatsapp = value
            if whatsapp.countryCode.isEmpty {
                whatsapp.countryCode = QRWhatsApp.callingCode(region: Locale.current.region?.identifier)
            }
        case .contact(let value)?: contact = value
        case nil: url = ""
        }
        kind = content?.kind ?? .url
        arrival += 1
    }

    func choose(_ kind: QRPayloadKind) {
        guard kind != self.kind else { return }
        self.kind = kind
        arrival += 1
    }
}

// MARK: - View

struct QRPanelView: View {
    @ObservedObject var model: QRPanelModel
    let close: () -> Void
    @ObservedObject private var service = QRService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.zenithQRLogo) private var logo = false
    @AppStorage(DefaultsKey.zenithQRCorrection) private var storedCorrection = QRCorrection.medium.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    @State private var shareAnchor: NSView?
    @State private var saveAnchor: NSView?

    private var text: ZenithQRStrings { ZenithStrings.qr(l10n.language) }
    private var correction: QRCorrection { logo ? .high : QRCorrection.stored(storedCorrection) }
    private var payload: String? { model.content.payload }
    private var matrix: QRMatrix? { payload.flatMap { service.matrix($0, correction: correction) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .top, spacing: 18) {
                codeColumn.frame(width: 248)
                editColumn.frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .frame(width: QRPanelController.size.width, height: QRPanelController.size.height, alignment: .topLeading)
        .modifier(QRCardChrome(cornerRadius: 26))
        .modifier(QRArrival(shown: model.presented, reduceMotion: reduceMotion))
        .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMorph.animation, value: model.presented)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: "qrcode", tint: ZenithIslandPalette.color(hex: 0xC4B5FD), size: 26)
            Text(text.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
            Spacer(minLength: 8)
            NotchIconButton(symbol: "xmark", title: text.close, action: close)
        }
    }

    // MARK: Code

    private var codeColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let matrix {
                    QRCodeView(matrix: matrix, logo: logo)
                        .transition(.zenithMorph(reduceMotion: reduceMotion))
                        .id(model.arrival)
                } else {
                    placeholder
                        .transition(.opacity)
                }
            }
            .frame(width: 248, height: 248)
            .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: model.arrival)
            .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: matrix == nil)

            Text(payload ?? " ")
                .font(ZenithType.mono(10.5))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .center)
                .textSelection(.enabled)
                .help(payload ?? "")

            HStack(spacing: 6) {
                QRActionButton(symbol: "doc.on.doc", title: text.copyImage, done: copied) { copyImage() }
                saveMenu
                QRActionButton(symbol: "rectangle.inset.filled", title: text.present) { present() }
                QRActionButton(symbol: "square.and.arrow.up", title: text.share) { share() }
                    .background(QRViewAnchor(view: $shareAnchor))
            }
            .disabled(matrix == nil)
        }
    }

    private var placeholder: some View {
        let tooLong = payload != nil && matrix == nil
        return VStack(spacing: 10) {
            Image(systemName: tooLong ? "exclamationmark.triangle" : "qrcode")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(tooLong ? ZenithStatus.warning : ZenithIsland.tertiary)
            Text(tooLong ? text.tooLong : text.empty)
                .font(.system(size: 11.5))
                .foregroundStyle(ZenithIsland.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zenithIslandSoftCard(cornerRadius: 18)
    }

    private var saveMenu: some View {
        QRActionButton(symbol: "square.and.arrow.down", title: text.save) {
            guard let saveAnchor else { return }
            QRMenu.pop([(text.savePNG, { save(.png) }), (text.saveSVG, { save(.svg) })], below: saveAnchor)
        }
        .background(QRViewAnchor(view: $saveAnchor))
    }

    // MARK: Editing

    private var editColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZenithSegmented(selection: Binding(get: { model.kind }, set: { model.choose($0) }),
                            options: QRPayloadKind.allCases.map { (value: $0, title: title($0)) }, fontSize: 11)
            fields
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .zenithIslandSoftCard(cornerRadius: 18)
                .zenithMorph(on: model.kind)
            Toggle(isOn: $logo) {
                HStack(spacing: 8) {
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ZenithIsland.secondary)
                    Text(text.logo)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ZenithIsland.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                }
            }
            .toggleStyle(ZenithIslandSwitchStyle(scale: 0.8))
            recent
        }
    }

    @ViewBuilder private var fields: some View {
        switch model.kind {
        case .url:
            QRField(placeholder: "https://", text: $model.url, mono: true)
        case .text:
            QRField(placeholder: text.textPlaceholder, text: $model.text, lines: 5)
        case .wifi:
            VStack(alignment: .leading, spacing: 8) {
                QRField(placeholder: text.wifiName, text: $model.wifi.ssid)
                if model.wifi.security != .open {
                    QRField(placeholder: text.wifiPassword, text: $model.wifi.password, mono: true)
                }
                ZenithSegmented(selection: $model.wifi.security,
                                options: [(.wpa, "WPA/WPA3"), (.wep, "WEP"), (.open, text.wifiOpen)], height: 24, fontSize: 10.5)
                Toggle(isOn: $model.wifi.hidden) {
                    Text(text.wifiHidden).font(.system(size: 11.5)).foregroundStyle(ZenithIsland.secondary)
                    Spacer(minLength: 4)
                }
                .toggleStyle(ZenithIslandSwitchStyle(scale: 0.75))
            }
        case .whatsapp:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    QRField(placeholder: "+", text: $model.whatsapp.countryCode, mono: true)
                        .frame(width: 64)
                        .help(text.waCountry)
                    QRField(placeholder: text.waNumber, text: $model.whatsapp.number, mono: true)
                }
                QRField(placeholder: text.waMessage, text: $model.whatsapp.message, lines: 3)
                Text(text.waHint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ZenithIsland.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .contact:
            VStack(alignment: .leading, spacing: 8) {
                QRField(placeholder: text.contactName, text: $model.contact.name)
                HStack(spacing: 8) {
                    QRField(placeholder: text.contactPhone, text: $model.contact.phone, mono: true)
                    QRField(placeholder: text.contactEmail, text: $model.contact.email)
                }
                HStack(spacing: 8) {
                    QRField(placeholder: text.contactOrg, text: $model.contact.organization)
                    QRField(placeholder: text.contactURL, text: $model.contact.url)
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(text.recent.uppercased())
                    .font(ZenithType.mono(9.5, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(ZenithIsland.label)
                Spacer(minLength: 4)
                if !service.history.isEmpty {
                    Button(text.clearRecent) { service.clearHistory() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ZenithIsland.tertiary)
                }
            }
            if service.history.isEmpty {
                Text(text.recentEmpty)
                    .font(.system(size: 11))
                    .foregroundStyle(ZenithIsland.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(service.history, id: \.self) { entry in
                            QRHistoryRow(payload: entry, current: entry == payload,
                                         pick: { pick(entry) }, forget: { service.forget(entry) }, text: text)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(ZenithMotion.respecting(ZenithMotion.spring()), value: service.history)
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

    // MARK: Actions

    private func pick(_ entry: String) {
        model.load(QRDetector.detect(entry) ?? .text(entry))
    }

    private func copyImage() {
        guard let payload else { return }
        QRExport.copyImage(payload) { ok in
            guard ok else { return }
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
        }
    }

    private func save(_ format: QRExport.Format) {
        guard let payload else { return }
        QRExport.save(payload, as: format, above: QRPanelController.shared.window)
    }

    private func present() {
        guard let payload else { return }
        QRService.shared.record(payload)
        QRPresentationController.shared.present(payload)
    }

    private func share() {
        guard let payload, let shareAnchor else { return }
        QRExport.share(payload, from: shareAnchor)
    }
}

/// A field on the QR card: plain text on a faint well, mono for numbers and links.
struct QRField: View {
    let placeholder: String
    @Binding var text: String
    var mono = false
    var lines = 1
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if lines > 1 {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(lines, reservesSpace: true)
            } else {
                TextField(placeholder, text: $text)
                    .lineLimit(1)
            }
        }
        .textFieldStyle(.plain)
        .font(mono ? ZenithType.mono(12) : .system(size: 12.5))
        .foregroundStyle(ZenithIsland.primary)
        .focused($focused)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(focused ? 0.09 : 0.06)))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(focused ? 0.22 : 0.08), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: focused)
    }
}

/// One code from the list: its kind's glyph and its text; a click puts it
/// back on the page.
private struct QRHistoryRow: View {
    let payload: String
    let current: Bool
    let pick: () -> Void
    let forget: () -> Void
    let text: ZenithQRStrings
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: pick) {
                HStack(spacing: 8) {
                    Image(systemName: (QRDetector.detect(payload)?.kind ?? .text).symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ZenithIsland.secondary)
                        .frame(width: 14)
                    Text(payload.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " "))
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(current ? ZenithIsland.primary : ZenithIsland.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if hovering {
                Button(action: forget) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(ZenithIsland.tertiary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(current ? Color.white.opacity(0.08) : hovering ? ZenithIsland.rowHover : .clear))
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(payload)
    }
}

/// A small menu under a control, its items running closures.
enum QRMenu {
    private final class Item: NSMenuItem {
        var run: () -> Void = {}
        @objc func fire() { run() }
    }

    static func pop(_ items: [(String, () -> Void)], below view: NSView) {
        let menu = NSMenu()
        for (title, run) in items {
            let item = Item(title: title, action: #selector(Item.fire), keyEquivalent: "")
            item.target = item
            item.run = run
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: view.isFlipped ? view.bounds.height + 4 : -4), in: view)
    }
}

/// Hands a SwiftUI control's AppKit view out, for a menu to point at.
struct QRViewAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.view = view }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
