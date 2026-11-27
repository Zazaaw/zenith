// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import UniformTypeIdentifiers

// Zenith fork: what a QR code can become outside the app: a picture on the
// clipboard, a PNG or SVG file, or a file handed to the share menu. Each
// one is made again from the code's text at the current settings.

enum QRExport {
    enum Format { case png, svg }

    /// A PNG of the code on the clipboard, through the pasteboard's own lane.
    static func copyImage(_ payload: String, completion: @escaping (Bool) -> Void = { _ in }) {
        guard let data = pngData(payload) else {
            completion(false)
            return
        }
        GeneralPasteboardAccess.shared.async({ () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareVorssaintSource()
            return pasteboard.setData(data, forType: .png)
        }, then: { ok in
            if ok {
                QRService.shared.record(payload)
                QuickToolHUD.show(icon: "qrcode", message: ZenithStrings.qr(L10n.shared.language).copied)
            } else {
                ZenithQuiet.beep()
            }
            completion(ok)
        })
    }

    /// Asks where to keep the code, then writes it as a PNG or an SVG.
    static func save(_ payload: String, as format: Format, above window: NSWindow?) {
        let correction = QRSettings.correction()
        let logo = QRSettings.logo()
        guard let matrix = QRService.shared.matrix(payload, correction: correction) else {
            ZenithQuiet.beep()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .svg]
        panel.nameFieldStringValue = fileName(payload) + (format == .png ? ".png" : ".svg")
        panel.canCreateDirectories = true
        // The QR page floats; the save panel has to come out above it.
        if let window { panel.level = NSWindow.Level(rawValue: window.level.rawValue + 1) }
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let data: Data?
            switch format {
            case .png: data = QRRender.pngData(matrix, logo: logo)
            case .svg: data = QRRender.svg(matrix, logo: logo).data(using: .utf8)
            }
            guard let data, (try? data.write(to: url, options: .atomic)) != nil else {
                ZenithQuiet.beep()
                return
            }
            QRService.shared.record(payload)
        }
    }

    /// The share menu with the code as a PNG file (AirDrop, Messages, Mail…).
    static func share(_ payload: String, from view: NSView) {
        guard let data = pngData(payload) else {
            ZenithQuiet.beep()
            return
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Zenith QR", isDirectory: true)
        let url = folder.appendingPathComponent(fileName(payload) + ".png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            ZenithQuiet.beep()
            return
        }
        QRService.shared.record(payload)
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    static func pngData(_ payload: String) -> Data? {
        guard let matrix = QRService.shared.matrix(payload, correction: QRSettings.correction()) else { return nil }
        return QRRender.pngData(matrix, logo: QRSettings.logo())
    }

    /// "QR satuvisual.id", "QR Wi-Fi Studio", or plain "QR code".
    static func fileName(_ payload: String) -> String {
        let base: String
        switch QRDetector.detect(payload) {
        case .url(let link)?: base = URL(string: link)?.host ?? ""
        case .wifi(let wifi)?: base = wifi.ssid
        case .whatsapp(let chat)?: base = "WhatsApp " + chat.normalizedNumber
        case .contact(let contact)?: base = contact.name
        default: base = ""
        }
        let cleaned = base.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>\n\r")).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? ZenithStrings.qr(L10n.shared.language).title : "QR " + String(cleaned.prefix(60))
    }
}
