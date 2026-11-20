// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import CoreImage
import Darwin
import Foundation
import ImageIO
import Vision

// Zenith fork: instant QR codes. A link, a line of text, a Wi-Fi network, a
// WhatsApp chat or a small contact card becomes a QR code that phones scan;
// a code on the screen can be read back, with its link spelled out and
// checked before it is opened.
//
// Everything here is pure (Foundation, CoreGraphics, CoreImage and Vision)
// and compiled into the tests: the payloads and their escaping, telling what
// a clipboard holds, the module matrix and its rendering (PNG and SVG, with
// the Satu Visual star in the middle), reading codes from an image, the link
// safety hints and the history. QRService and the views under UI/QR use them.

// MARK: - Error correction

/// How much of a code can be lost (a smudge, glare, a logo) and still read.
enum QRCorrection: String, CaseIterable, Identifiable {
    case low = "L", medium = "M", quartile = "Q", high = "H"

    var id: String { rawValue }

    /// The share of the code that can be restored, for the picker.
    var percent: Int {
        switch self {
        case .low: return 7
        case .medium: return 15
        case .quartile: return 25
        case .high: return 30
        }
    }

    /// The most bytes a version 40 code holds at this level.
    var capacity: Int {
        switch self {
        case .low: return 2953
        case .medium: return 2331
        case .quartile: return 1663
        case .high: return 1273
        }
    }

    /// A stored value, or medium when there is none or it is unknown.
    static func stored(_ value: Any?) -> QRCorrection {
        (value as? String).flatMap(QRCorrection.init(rawValue:)) ?? .medium
    }
}

// MARK: - Payloads

/// The kinds of code the QR page makes, in the order its picker shows them.
enum QRPayloadKind: String, CaseIterable, Identifiable {
    case url, text, wifi, whatsapp, contact

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .url: return "link"
        case .text: return "text.alignleft"
        case .wifi: return "wifi"
        case .whatsapp: return "message.fill"
        case .contact: return "person.crop.circle"
        }
    }
}

enum QRWiFiSecurity: String, CaseIterable, Identifiable {
    case wpa = "WPA", wep = "WEP", open = "nopass"

    var id: String { rawValue }
}

/// A Wi-Fi network as the `WIFI:` scheme phones join from their camera.
struct QRWiFi: Equatable {
    var ssid = ""
    var password = ""
    var security = QRWiFiSecurity.wpa
    var hidden = false

    /// `WIFI:T:WPA;S:name;P:secret;;`, with `\ ; , : "` escaped in the name
    /// and the password. An open network leaves the password out. Nil
    /// without a name.
    var payload: String? {
        guard !ssid.isEmpty else { return nil }
        var fields = "T:\(security.rawValue);S:\(QRPayload.escapeWiFi(ssid));"
        if security != .open { fields += "P:\(QRPayload.escapeWiFi(password));" }
        if hidden { fields += "H:true;" }
        return "WIFI:\(fields);"
    }

    /// Reads a `WIFI:` payload back, escapes undone; nil for anything else.
    static func parse(_ payload: String) -> QRWiFi? {
        guard payload.uppercased().hasPrefix("WIFI:") else { return nil }
        var wifi = QRWiFi()
        var security: String?
        for field in QRPayload.splitEscaped(String(payload.dropFirst(5)), separator: ";") {
            guard let colon = field.firstIndex(of: ":") else { continue }
            let key = field[..<colon].uppercased()
            let value = QRPayload.unescapeWiFi(String(field[field.index(after: colon)...]))
            switch key {
            case "S": wifi.ssid = value
            case "P": wifi.password = value
            case "T": security = value.uppercased()
            case "H": wifi.hidden = value.lowercased() == "true"
            default: break
            }
        }
        guard !wifi.ssid.isEmpty else { return nil }
        switch security {
        case "WEP": wifi.security = .wep
        case "NOPASS", "", nil: wifi.security = wifi.password.isEmpty ? .open : .wpa
        default: wifi.security = .wpa
        }
        return wifi
    }
}

/// A WhatsApp chat link (`https://wa.me/<number>?text=…`).
struct QRWhatsApp: Equatable {
    var number = ""
    /// Digits put in place of a leading 0, for a number written the local way.
    var countryCode = ""
    var message = ""

    /// The number as wa.me wants it: digits only, in international form. A
    /// `+` or `00` in front means it already is; a single leading 0 is the
    /// local trunk prefix, which the country code replaces.
    var normalizedNumber: String {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = QRPayload.asciiDigits(trimmed)
        let international = trimmed.hasPrefix("+") || trimmed.hasPrefix("＋") || digits.hasPrefix("00")
        if digits.hasPrefix("00") { digits.removeFirst(2) }
        let code = QRPayload.asciiDigits(countryCode)
        if !international, digits.hasPrefix("0"), !code.isEmpty {
            digits = code + digits.drop { $0 == "0" }
        }
        return digits
    }

    var payload: String? {
        let digits = normalizedNumber
        guard digits.count >= 5 else { return nil }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return "https://wa.me/\(digits)" + (text.isEmpty ? "" : "?text=\(QRPayload.percentEncode(text))")
    }

    /// A wa.me or api.whatsapp.com link read back into its number and message.
    static func parse(_ url: URL) -> QRWhatsApp? {
        guard let host = url.host?.lowercased() else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let text = items.first { $0.name == "text" }?.value ?? ""
        let number: String
        if host == "wa.me" || host == "www.wa.me" {
            number = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else if host == "api.whatsapp.com" {
            number = items.first { $0.name == "phone" }?.value ?? ""
        } else {
            return nil
        }
        guard !number.isEmpty, number.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return QRWhatsApp(number: "+" + number, countryCode: "", message: text)
    }

    /// The calling code for the Mac's region, so a local number written with
    /// its leading 0 still reaches the right country. Empty when unknown.
    static func callingCode(region: String?) -> String {
        guard let region else { return "" }
        let codes: [String: String] = [
            "ID": "62", "MY": "60", "SG": "65", "TH": "66", "PH": "63", "VN": "84", "IN": "91",
            "US": "1", "CA": "1", "GB": "44", "AU": "61", "NZ": "64", "NL": "31", "BE": "32",
            "BR": "55", "PT": "351", "TR": "90", "RU": "7", "ES": "34", "MX": "52", "AR": "54",
            "SK": "421", "CZ": "420", "DE": "49", "AT": "43", "CH": "41", "FR": "33", "IT": "39",
            "JP": "81", "KR": "82", "UA": "380", "CN": "86", "TW": "886", "HK": "852",
        ]
        return codes[region.uppercased()] ?? ""
    }
}

/// A small contact card: vCard 3.0 with the fields people trade at events.
struct QRContact: Equatable {
    var name = ""
    var phone = ""
    var email = ""
    var organization = ""
    var url = ""

    var payload: String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = QRPayload.singleLine(phone)
        let email = QRPayload.singleLine(email)
        let organization = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = QRPayload.singleLine(url)
        guard !name.isEmpty || !phone.isEmpty || !email.isEmpty else { return nil }
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        // N wants family;given. One name field is split at its last space.
        let parts = name.split(separator: " ")
        let family = parts.count > 1 ? String(parts.last ?? "") : ""
        let given = parts.count > 1 ? parts.dropLast().joined(separator: " ") : name
        lines.append("N:\(QRPayload.escapeVCard(family));\(QRPayload.escapeVCard(given));;;")
        lines.append("FN:\(QRPayload.escapeVCard(name.isEmpty ? (phone.isEmpty ? email : phone) : name))")
        if !organization.isEmpty { lines.append("ORG:\(QRPayload.escapeVCard(organization))") }
        if !phone.isEmpty { lines.append("TEL;TYPE=CELL:\(phone)") }
        if !email.isEmpty { lines.append("EMAIL:\(email)") }
        if !url.isEmpty { lines.append("URL:\(url)") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    /// The fields this card writes, read back from any vCard; nil when the
    /// text is not one.
    static func parse(_ payload: String) -> QRContact? {
        let normalized = payload.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.uppercased().hasPrefix("BEGIN:VCARD") else { return nil }
        var contact = QRContact()
        for raw in normalized.split(separator: "\n") {
            let line = String(raw)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].split(separator: ";").first.map { $0.uppercased() } ?? ""
            let value = String(line[line.index(after: colon)...])
            switch name {
            case "FN": contact.name = QRPayload.unescapeVCard(value)
            case "ORG": contact.organization = QRPayload.unescapeVCard(value)
            case "TEL" where contact.phone.isEmpty: contact.phone = value
            case "EMAIL" where contact.email.isEmpty: contact.email = value
            case "URL" where contact.url.isEmpty: contact.url = value
            default: break
            }
        }
        return contact
    }
}

/// What a code holds, as the QR page edits it.
enum QRContent: Equatable {
    case url(String)
    case text(String)
    case wifi(QRWiFi)
    case whatsapp(QRWhatsApp)
    case contact(QRContact)

    var kind: QRPayloadKind {
        switch self {
        case .url: return .url
        case .text: return .text
        case .wifi: return .wifi
        case .whatsapp: return .whatsapp
        case .contact: return .contact
        }
    }

    /// The exact text the code carries; nil while there is nothing to encode.
    var payload: String? {
        switch self {
        case .url(let value):
            let trimmed = QRPayload.singleLine(value)
            return trimmed.isEmpty ? nil : trimmed
        case .text(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        case .wifi(let wifi): return wifi.payload
        case .whatsapp(let chat): return chat.payload
        case .contact(let contact): return contact.payload
        }
    }
}

/// The escaping and encoding the payloads share.
enum QRPayload {
    /// The `WIFI:` scheme's special characters, each escaped with a backslash.
    static let wifiSpecials: Set<Character> = ["\\", ";", ",", ":", "\""]

    static func escapeWiFi(_ value: String) -> String {
        var result = ""
        for character in value {
            if wifiSpecials.contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    static func unescapeWiFi(_ value: String) -> String {
        var result = ""
        var escaping = false
        for character in value {
            if escaping {
                result.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Splits at `separator` where it is not escaped; the pieces keep their escapes.
    static func splitEscaped(_ value: String, separator: Character) -> [String] {
        var pieces: [String] = []
        var current = ""
        var escaping = false
        for character in value {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" {
                current.append(character)
                escaping = true
            } else if character == separator {
                pieces.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    /// vCard text values: backslash, comma and semicolon escaped, line
    /// breaks written as `\n`.
    static func escapeVCard(_ value: String) -> String {
        var result = ""
        for character in value {
            switch character {
            case "\\": result += "\\\\"
            case ",": result += "\\,"
            case ";": result += "\\;"
            case "\n", "\r\n", "\r": result += "\\n"
            default: result.append(character)
            }
        }
        return result
    }

    static func unescapeVCard(_ value: String) -> String {
        var result = ""
        var escaping = false
        for character in value {
            if escaping {
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// RFC 3986's unreserved characters, ASCII only: everything else in a
    /// message is percent-encoded as UTF-8, spaces and line breaks included.
    static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    static func asciiDigits(_ value: String) -> String {
        String(value.unicodeScalars.filter { $0.value >= 48 && $0.value <= 57 }.map(Character.init))
    }

    /// Trimmed, with any line break taken out.
    static func singleLine(_ value: String) -> String {
        value.components(separatedBy: .newlines).joined().trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Telling what a clipboard holds

enum QRDetector {
    /// The longest text the island and the shortcut offer as a code: a
    /// longer one makes a dense code that a phone struggles with across a
    /// table, and is rarely what is shared at an event.
    static let offerLimit = 600

    /// Top-level domains read as a link without a scheme or a path.
    static let commonDomains: Set<String> = [
        "com", "net", "org", "id", "io", "co", "me", "app", "dev", "ai", "xyz", "site", "link", "page",
        "art", "studio", "design", "photo", "photos", "gallery", "info", "biz", "my", "sg", "uk", "us",
        "de", "fr", "it", "es", "nl", "br", "jp", "kr", "tw", "hk", "cn", "ru", "ua", "sk", "tr", "au",
    ]

    /// Schemes a phone's camera does something useful with.
    static let linkSchemes: Set<String> = ["http", "https", "mailto", "tel", "sms", "geo", "facetime"]

    /// What `text` would be as a code, or nil when it should not be one
    /// (empty, too long, or holding control characters).
    static func detect(_ text: String) -> QRContent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= offerLimit,
              !trimmed.unicodeScalars.contains(where: { $0.value < 32 && $0 != "\n" && $0 != "\t" && $0 != "\r"
                  || $0.value == 127 })
        else { return nil }
        if let wifi = QRWiFi.parse(trimmed) { return .wifi(wifi) }
        if trimmed.uppercased().hasPrefix("BEGIN:VCARD"), let contact = QRContact.parse(trimmed),
           contact.payload != nil {
            return .contact(contact)
        }
        if let link = link(trimmed) {
            if let url = URL(string: link), let chat = QRWhatsApp.parse(url) { return .whatsapp(chat) }
            return .url(link)
        }
        return .text(trimmed)
    }

    /// The text as a link: as written when it has a scheme a camera acts on,
    /// or with `https://` in front of a bare address (`satuvisual.id/gallery`).
    static func link(_ text: String) -> String? {
        guard !text.contains(where: { $0.isWhitespace }) else { return nil }
        if let colon = text.firstIndex(of: ":") {
            let scheme = text[..<colon].lowercased()
            if linkSchemes.contains(scheme) {
                guard let url = URL(string: text) else { return nil }
                if scheme == "http" || scheme == "https" { return url.host?.isEmpty == false ? text : nil }
                return text[text.index(after: colon)...].isEmpty ? nil : text
            }
            // host:port/path without a scheme falls through to the bare check.
        }
        let host = text.split(separator: "/", maxSplits: 1).first.map(String.init) ?? text
        let hostOnly = host.split(separator: ":").first.map(String.init) ?? host
        let labels = hostOnly.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ label in
            !label.isEmpty && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }), let tld = labels.last, tld.count >= 2, tld.allSatisfy(\.isLetter) else { return nil }
        let hasPath = text.contains("/")
        let www = hostOnly.lowercased().hasPrefix("www.")
        guard hasPath || www || commonDomains.contains(tld.lowercased()) else { return nil }
        let candidate = "https://" + text
        return URL(string: candidate)?.host == nil ? nil : candidate
    }

    /// Whether the island's clipboard card offers its QR action.
    static func offers(_ text: String) -> Bool { detect(text) != nil }
}

// MARK: - Module matrix

/// A QR code's modules, row by row from the top left; true is dark.
struct QRMatrix: Hashable {
    let size: Int
    let modules: [Bool]

    subscript(x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < size, y < size else { return false }
        return modules[y * size + x]
    }

    /// One CoreImage context for every code: it is costly to make, and safe
    /// to share between threads.
    private static let context = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])

    /// The code CoreImage makes for `payload`, read module by module; nil
    /// when it is empty or longer than the level holds.
    static func make(_ payload: String, correction: QRCorrection) -> QRMatrix? {
        let data = Data(payload.utf8)
        guard !data.isEmpty, data.count <= correction.capacity,
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correction.rawValue, forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent.integral
        let width = Int(extent.width), height = Int(extent.height)
        guard width > 0, height > 0, width < 400, height < 400 else { return nil }
        // RGBA, top row first; CoreImage leaves an L8 bitmap untouched.
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        rgba.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            context.render(output, toBitmap: base, rowBytes: width * 4, bounds: extent, format: .RGBA8, colorSpace: space)
        }
        let pixels = stride(from: 0, to: rgba.count, by: 4).map { rgba[$0] }
        return trimmed(pixels, width: width, height: height)
    }

    /// The dark modules' bounding square, which drops the margin CoreImage
    /// adds: the three finder patterns sit in its corners.
    static func trimmed(_ pixels: [UInt8], width: Int, height: Int) -> QRMatrix? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] < 128 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let side = maxX - minX + 1
        guard side == maxY - minY + 1, side >= 21 else { return nil }
        var modules = [Bool](repeating: false, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                modules[y * side + x] = pixels[(minY + y) * width + minX + x] < 128
            }
        }
        return QRMatrix(size: side, modules: modules)
    }

    /// The square of modules left white for the star: about a fifth of the
    /// code's side, centred on a module, with the star a module in from its
    /// edge. Small enough that High correction restores what it hides, and
    /// clear of the finder patterns in the corners.
    var logoPad: (origin: Int, side: Int) {
        var side = Int((Double(size) * QRRender.logoShare).rounded())
        if side % 2 != size % 2 { side += 1 }
        side = max(5, side)
        return ((size - side) / 2, side)
    }

    /// Whether a module is drawn: dark, and outside the star's pad when there is one.
    func isDrawn(x: Int, y: Int, logo: Bool) -> Bool {
        guard self[x, y] else { return false }
        guard logo else { return true }
        let pad = logoPad
        return !(x >= pad.origin && x < pad.origin + pad.side && y >= pad.origin && y < pad.origin + pad.side)
    }

    /// Each row's dark runs, as (x, y, length), for the SVG and for drawing.
    func runs(logo: Bool) -> [(x: Int, y: Int, length: Int)] {
        var runs: [(x: Int, y: Int, length: Int)] = []
        for y in 0..<size {
            var x = 0
            while x < size {
                guard isDrawn(x: x, y: y, logo: logo) else { x += 1; continue }
                let start = x
                while x < size, isDrawn(x: x, y: y, logo: logo) { x += 1 }
                runs.append((start, y, x - start))
            }
        }
        return runs
    }
}

// MARK: - Rendering

enum QRRender {
    /// Dark modules: the brand's near black, always on white. Light modules on
    /// a dark island read poorly on many phone cameras, so a code is never
    /// drawn inverted.
    static let dark: UInt32 = 0x0A0A0A
    /// The quiet zone around the code, in modules. The standard asks for
    /// four; it is what lets a phone find the code on a busy screen.
    static let quietZone = 4
    /// The star's pad, as a share of the code's side.
    static let logoShare = 0.22

    /// The Satu Visual star in a unit square, y down, for the even-odd rule.
    static let star: CGPath = {
        let box = NotchMascotGeometry.starBox
        var transform = CGAffineTransform(scaleX: 1 / box.width, y: 1 / box.height)
            .translatedBy(x: -box.minX, y: -box.minY)
        let path = NotchMascotGeometry.star(size: 1)
        return path.copy(using: &transform) ?? path
    }()

    /// The star inside the pad, in module units from the top left of the
    /// code with its quiet zone.
    static func starRect(_ matrix: QRMatrix, quietZone: Int = quietZone) -> CGRect {
        let pad = matrix.logoPad
        let inset = 1.0
        return CGRect(x: Double(pad.origin + quietZone) + inset, y: Double(pad.origin + quietZone) + inset,
                      width: Double(pad.side) - inset * 2, height: Double(pad.side) - inset * 2)
    }

    /// The code as a bitmap, `moduleSize` pixels a module, quiet zone
    /// included: crisp squares on white, the star drawn as a shape. Shown
    /// scaled with nearest-neighbour sampling, so it stays sharp at any size.
    static func image(_ matrix: QRMatrix, moduleSize: Int, logo: Bool, quietZone: Int = quietZone) -> CGImage? {
        let total = matrix.size + quietZone * 2
        let side = total * max(1, moduleSize)
        let scale = CGFloat(max(1, moduleSize))
        guard side > 0, side <= 16_384, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let ink = color(dark)
        context.setFillColor(ink)
        // CoreGraphics counts rows from the bottom; the matrix from the top.
        for run in matrix.runs(logo: logo) {
            let rect = CGRect(x: CGFloat(run.x + quietZone) * scale,
                              y: CGFloat(total - 1 - (run.y + quietZone)) * scale,
                              width: CGFloat(run.length) * scale, height: scale)
            context.fill(rect)
        }
        if logo {
            context.setShouldAntialias(true)
            let rect = starRect(matrix, quietZone: quietZone)
            var transform = CGAffineTransform(translationX: rect.minX * scale,
                                              y: (Double(total) - rect.minY) * scale)
                .scaledBy(x: rect.width * scale, y: -rect.height * scale)
            if let star = star.copy(using: &transform) {
                context.addPath(star)
                context.fillPath(using: .evenOdd)
            }
        }
        return context.makeImage()
    }

    /// PNG bytes for a file or the pasteboard, about 1200 pixels across.
    static func pngData(_ matrix: QRMatrix, logo: Bool, targetPixels: Int = 1200) -> Data? {
        let total = matrix.size + quietZone * 2
        guard let image = image(matrix, moduleSize: max(8, targetPixels / total), logo: logo) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// The code as an SVG drawn from its modules: one path of row runs on a
    /// white square, one unit a module, the star as a second path. Edges are
    /// crisp at any size.
    static func svg(_ matrix: QRMatrix, logo: Bool, quietZone: Int = quietZone) -> String {
        let total = matrix.size + quietZone * 2
        let ink = String(format: "#%06X", dark)
        var path = ""
        for run in matrix.runs(logo: logo) {
            path += "M\(run.x + quietZone) \(run.y + quietZone)h\(run.length)v1h-\(run.length)z"
        }
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(total) \(total)" width="\(total * 10)" \
        height="\(total * 10)" shape-rendering="crispEdges">
        <rect width="\(total)" height="\(total)" fill="#FFFFFF"/>
        <path fill="\(ink)" d="\(path)"/>

        """
        if logo {
            let rect = starRect(matrix, quietZone: quietZone)
            var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width, y: rect.height)
            if let star = star.copy(using: &transform) {
                svg += "<path fill=\"\(ink)\" fill-rule=\"evenodd\" shape-rendering=\"geometricPrecision\" d=\"\(svgPath(star))\"/>\n"
            }
        }
        svg += "</svg>\n"
        return svg
    }

    /// A CGPath as SVG path data, three decimals at most.
    static func svgPath(_ path: CGPath) -> String {
        var data = ""
        func number(_ value: CGFloat) -> String {
            var text = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), Double(value))
            while text.contains("."), text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
            return text == "-0" ? "0" : text
        }
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint: data += "M\(number(points[0].x)) \(number(points[0].y))"
            case .addLineToPoint: data += "L\(number(points[0].x)) \(number(points[0].y))"
            case .addQuadCurveToPoint:
                data += "Q\(number(points[0].x)) \(number(points[0].y)) \(number(points[1].x)) \(number(points[1].y))"
            case .addCurveToPoint:
                data += "C\(number(points[0].x)) \(number(points[0].y)) \(number(points[1].x)) \(number(points[1].y)) "
                    + "\(number(points[2].x)) \(number(points[2].y))"
            case .closeSubpath: data += "Z"
            @unknown default: break
            }
        }
        return data
    }

    static func color(_ hex: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Reading codes

enum QRScanner {
    /// Matrix codes only, as the screen text tool reads them: striped areas
    /// of an ordinary screen fire 1D barcode detection falsely.
    static let symbologies: [VNBarcodeSymbology] = [.qr, .microQR, .aztec, .dataMatrix, .pdf417]

    /// Every code Vision finds in the image, top to bottom, then left to right.
    static func read(_ image: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = symbologies
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil else { return [] }
        var seen = Set<String>()
        return (request.results ?? [])
            .sorted { lhs, rhs in
                let rowL = ((1 - lhs.boundingBox.midY) * 20).rounded(), rowR = ((1 - rhs.boundingBox.midY) * 20).rounded()
                return rowL == rowR ? lhs.boundingBox.minX < rhs.boundingBox.minX : rowL < rowR
            }
            .compactMap { $0.payloadStringValue }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

// MARK: - Link safety

enum QRLinkFlag: String, CaseIterable {
    /// http, not https: anyone on the network can read or change the page.
    case notHTTPS
    /// A bare IP address instead of a named site.
    case ipAddress
    /// A name before an @ (`https://bank.com@evil.example`), which hides the real host.
    case userInfo
    /// Punycode or non-ASCII letters, which can imitate a known name.
    case lookalike
    /// Not a web page at all (`javascript:`, `file:`, an app's own scheme).
    case notWeb
}

enum QRLinkSafety {
    /// A scanned payload as a link the result card can open; nil when it is
    /// not a web address, which is only ever copied.
    static func openableURL(_ payload: String) -> URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: { $0.isWhitespace }), let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// What to point out before a scanned link is opened. Text that is not a
    /// link of any kind has nothing to flag.
    static func flags(_ payload: String) -> [QRLinkFlag] {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: { $0.isWhitespace }),
              let colon = trimmed.firstIndex(of: ":"),
              trimmed[..<colon].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+-.".contains($0)) }),
              trimmed[..<colon].first?.isLetter == true
        else { return [] }
        let scheme = trimmed[..<colon].lowercased()
        guard scheme == "http" || scheme == "https" else {
            // A Wi-Fi network or a contact card is data, not somewhere to go.
            if ["wifi", "begin", "mailto", "tel", "sms", "geo", "facetime", "mecard", "smsto"].contains(scheme) {
                return []
            }
            return [.notWeb]
        }
        var flags: [QRLinkFlag] = []
        if scheme == "http" { flags.append(.notHTTPS) }
        guard let url = URL(string: trimmed), let host = url.host else { return flags }
        if isIPAddress(host) { flags.append(.ipAddress) }
        if url.user != nil || url.password != nil { flags.append(.userInfo) }
        let lowered = host.lowercased()
        if lowered.split(separator: ".").contains(where: { $0.hasPrefix("xn--") })
            || host.unicodeScalars.contains(where: { !$0.isASCII }) {
            flags.append(.lookalike)
        }
        return flags
    }

    /// IPv4 (dotted, or one decimal number, which browsers also accept) and IPv6.
    static func isIPAddress(_ host: String) -> Bool {
        let bare = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        var v4 = in_addr()
        var v6 = in6_addr()
        if inet_pton(AF_INET, bare, &v4) == 1 || inet_pton(AF_INET6, bare, &v6) == 1 { return true }
        if !bare.isEmpty, bare.allSatisfy({ $0.isASCII && $0.isNumber }) { return true }
        if bare.lowercased().hasPrefix("0x"), bare.dropFirst(2).allSatisfy(\.isHexDigit), bare.count > 2 { return true }
        return false
    }

    /// The host a link goes to, for the result card's emphasis.
    static func host(_ payload: String) -> String? {
        openableURL(payload)?.host
    }
}

// MARK: - Settings and history

enum QRSettings {
    /// The level a code is made at: the chosen one, or High under the star.
    static func correction(_ defaults: UserDefaults = .standard) -> QRCorrection {
        logo(defaults) ? .high : QRCorrection.stored(defaults.object(forKey: DefaultsKey.zenithQRCorrection))
    }

    static func logo(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.zenithQRLogo)
    }

    /// The options and their first-run values; registered, so a settings
    /// backup carries them (the history too).
    static var registered: [String: Any] {
        [
            DefaultsKey.zenithQRCorrection: QRCorrection.medium.rawValue,
            DefaultsKey.zenithQRLogo: false,
            DefaultsKey.zenithQRShortcutEnabled: true,
            DefaultsKey.zenithQRScanShortcutEnabled: true,
            DefaultsKey.zenithQRHistory: [String](),
        ]
    }
}

/// The last codes made, newest first, as their text (images are made again).
enum QRHistory {
    static let maximum = 10

    static func load(_ defaults: UserDefaults = .standard) -> [String] {
        let stored = defaults.stringArray(forKey: DefaultsKey.zenithQRHistory) ?? []
        var seen = Set<String>()
        return Array(stored.filter { !$0.isEmpty && seen.insert($0).inserted }.prefix(maximum))
    }

    /// `payload` at the front, an earlier copy of it taken out, ten at most.
    static func adding(_ payload: String, to list: [String]) -> [String] {
        guard !payload.isEmpty else { return list }
        return Array(([payload] + list.filter { $0 != payload }).prefix(maximum))
    }

    @discardableResult
    static func record(_ payload: String, defaults: UserDefaults = .standard) -> [String] {
        let list = adding(payload, to: load(defaults))
        defaults.set(list, forKey: DefaultsKey.zenithQRHistory)
        return list
    }

    @discardableResult
    static func remove(_ payload: String, defaults: UserDefaults = .standard) -> [String] {
        let list = load(defaults).filter { $0 != payload }
        defaults.set(list, forKey: DefaultsKey.zenithQRHistory)
        return list
    }

    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.set([String](), forKey: DefaultsKey.zenithQRHistory)
    }
}
