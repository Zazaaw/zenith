// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: what Settings → iPhone & Watch decides without drawing, so the
// tests can check it: Pocket's defaults, the relay as typed, which pairing
// section the phase asks for, the captions, and the pairing QR code.

/// Pocket's preferences as they start. Registered at launch beside Batteries',
/// so the page and the service read the same values before anything is set.
enum PocketPreferences {
    static let initial: [String: Any] = [
        PocketDefaults.enabled: false,
        PocketDefaults.shareWallpaper: true,
        PocketDefaults.shareAgents: true,
        PocketDefaults.shareNowPlaying: true,
        PocketDefaults.allowAnswers: false,
    ]

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: initial)
    }
}

// MARK: - Relay

/// The relay as typed into the page. People paste the URL and the key from
/// Supabase's dashboard, with stray spaces, a trailing slash or the REST
/// path, and the key wrapped over lines; this reads past all of that, and
/// refuses the keys that must never leave the dashboard.
struct PocketRelayDraft: Equatable {
    enum Problem: Equatable {
        /// Not an https origin.
        case url
        /// Not shaped like an anon key.
        case key
        /// The service_role (or sb_secret_) key, which opens the whole project.
        case secretKey
        /// One of Supabase's newer publishable keys, which the relay can't use.
        case newFormatKey
    }

    var url: String
    var key: String

    init(url: String, key: String) {
        self.url = url
        self.key = key
    }

    /// The fields as a saved relay fills them.
    init(_ relay: PocketRelayConfig?) {
        self.init(url: relay?.url.absoluteString ?? "", key: relay?.anonKey ?? "")
    }

    var isEmpty: Bool { Self.trimmed(url).isEmpty && Self.trimmed(key).isEmpty }

    /// What is wrong with the URL; nil when it is fine or still empty.
    var urlProblem: Problem? {
        guard !Self.trimmed(url).isEmpty else { return nil }
        return Self.normalizedURL(url) == nil ? .url : nil
    }

    /// What is wrong with the key; nil when it is fine or still empty.
    var keyProblem: Problem? {
        let key = Self.normalizedKey(key)
        guard !key.isEmpty else { return nil }
        if key.hasPrefix("sb_secret_") { return .secretKey }
        if key.hasPrefix("sb_publishable_") { return .newFormatKey }
        let parts = key.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty }), key.count < 2048 else { return .key }
        if Self.role(of: parts[1]) == "service_role" { return .secretKey }
        return nil
    }

    /// The relay to save: both fields filled and sound, and accepted by
    /// PocketKit's own check.
    var relay: PocketRelayConfig? {
        guard urlProblem == nil, keyProblem == nil, let url = Self.normalizedURL(url) else { return nil }
        let key = Self.normalizedKey(key)
        guard !key.isEmpty else { return nil }
        let relay = PocketRelayConfig(url: url, anonKey: key)
        return relay.isValid ? relay : nil
    }

    /// The project's origin, `https://host[:port]`: spaces trimmed, https
    /// added when no scheme was typed, a trailing slash or `/rest/v1` (what
    /// the dashboard's API page shows) dropped. Anything else on the path,
    /// a query, a login or plain http is refused.
    static func normalizedURL(_ text: String) -> URL? {
        var string = trimmed(text)
        guard !string.isEmpty else { return nil }
        if !string.contains("://") { string = "https://" + string }
        while string.hasSuffix("/") { string.removeLast() }
        if string.lowercased().hasSuffix("/rest/v1") { string.removeLast("/rest/v1".count) }
        while string.hasSuffix("/") { string.removeLast() }
        guard let parts = URLComponents(string: string), parts.scheme?.lowercased() == "https",
              let host = parts.host?.lowercased(), !host.isEmpty, !host.contains(" "),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty else { return nil }
        var clean = URLComponents()
        clean.scheme = "https"
        clean.host = host
        clean.port = parts.port
        guard let url = clean.url, PocketRelayConfig(url: url, anonKey: "a.b.c").isValid else { return nil }
        return url
    }

    /// The key without the spaces, line breaks and quotes a paste brings.
    static func normalizedKey(_ text: String) -> String {
        String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) && $0 != "\"" && $0 != "'" })
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The `role` claim of a JWT's payload, when it reads as one.
    private static func role(of payload: Substring) -> String? {
        guard let data = Data(base64URL: String(payload)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["role"] as? String
    }
}

// MARK: - Pairing

/// The pairing section the page draws.
enum PocketPairingStage: Equatable {
    /// Pocket can't start: these are missing.
    case needs([PocketMissing])
    /// Everything is set, and the service hasn't reported yet.
    case starting
    case unpaired
    /// A code is on screen; the URL is what it encodes.
    case pairing(URL)
    case paired(lastSeen: Date?)

    /// The stage for `phase`. While the service says `.off`, the page says
    /// what the person still has to do, from the preference and the relay it
    /// can see itself.
    static func of(_ phase: PocketPhase, enabled: Bool, hasRelay: Bool) -> PocketPairingStage {
        switch phase {
        case .off:
            let missing = (enabled ? [] : [PocketMissing.enable]) + (hasRelay ? [] : [.relay])
            return missing.isEmpty ? .starting : .needs(missing)
        case .unpaired: return .unpaired
        case .pairing(let pairing): return .pairing(pairing.url)
        case .paired(let lastSeen): return .paired(lastSeen: lastSeen)
        }
    }

    /// The preview card's state that matches: Unpaired, Pairing or Paired.
    var previewState: Int {
        switch self {
        case .needs, .starting, .unpaired: return PocketPreviewState.unpaired
        case .pairing: return PocketPreviewState.pairing
        case .paired: return PocketPreviewState.paired
        }
    }
}

enum PocketMissing: Equatable {
    case enable, relay
}

/// The preview card's states, by index.
enum PocketPreviewState {
    static let unpaired = 0, pairing = 1, paired = 2
}

// MARK: - Captions

enum PocketSettingsText {
    /// How long ago, in the captions' short form: "just now", "5 min ago", "2 h ago", "3 d ago".
    static func ago(_ seconds: TimeInterval, _ text: ZenithPocketStrings) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes < 1 { return text.justNow }
        if minutes < 60 { return text.count(text.minutesAgo, minutes) }
        if minutes < 24 * 60 { return text.count(text.hoursAgo, minutes / 60) }
        return text.count(text.daysAgo, minutes / (24 * 60))
    }

    /// "43% · charging · seen 2 min ago".
    static func caption(_ device: PocketDeviceReport.Device, now: Date, _ text: ZenithPocketStrings) -> String {
        var parts = ["\(min(max(device.percent, 0), 100))%"]
        if device.charging { parts.append(text.charging) }
        parts.append(text.time(text.seen, ago(now.timeIntervalSince(device.readAt), text)))
        return parts.joined(separator: " · ")
    }

    static func link(_ status: PocketLink.Status, _ text: ZenithPocketStrings) -> String {
        switch status {
        case .live: return text.linkLive
        case .connecting: return text.linkConnecting
        case .offline: return text.linkOffline
        }
    }

    /// "last message 3 min ago", or that none came yet.
    static func lastSeen(_ date: Date?, now: Date, _ text: ZenithPocketStrings) -> String {
        guard let date else { return text.waitingFirst }
        return text.time(text.lastMessage, ago(now.timeIntervalSince(date), text))
    }

    /// The paired phone's name for the Unpair question: the report's iPhone, else "iPhone".
    static func phoneName(_ devices: [PocketDeviceReport.Device], _ text: ZenithPocketStrings) -> String {
        devices.first { $0.kind == .iphone }?.name ?? text.deviceFallback
    }

    static func problem(_ problem: PocketRelayDraft.Problem, _ text: ZenithPocketStrings) -> String {
        switch problem {
        case .url: return text.urlInvalid
        case .key: return text.keyInvalid
        case .secretKey: return text.keyIsSecret
        case .newFormatKey: return text.keyIsNewFormat
        }
    }
}

// MARK: - QR code

/// The pairing code: CoreImage's QR modules (QRMatrix), drawn one pixel per
/// module (or `scale` pixels) inside the standard four-module quiet zone,
/// black on white whatever the appearance, so any camera reads it. Shown
/// without interpolation at a whole number of points per module, so every
/// module's edge lands on a pixel.
enum PocketQR {
    static let quietZone = 4
    /// Low: a screen doesn't smudge, and fewer, larger modules read faster.
    static let correction = QRCorrection.low

    static func matrix(for url: URL) -> QRMatrix? {
        QRMatrix.make(url.absoluteString, correction: correction)
    }

    /// Modules across, the quiet zone included.
    static func modulesAcross(_ matrix: QRMatrix) -> Int { matrix.size + 2 * quietZone }

    /// The code as a greyscale image, `scale` pixels per module.
    static func image(_ matrix: QRMatrix, scale: Int = 1) -> CGImage? {
        let scale = max(1, scale)
        let side = modulesAcross(matrix) * scale
        var pixels = [UInt8](repeating: 255, count: side * side)
        for y in 0..<matrix.size {
            for x in 0..<matrix.size where matrix[x, y] {
                for dy in 0..<scale {
                    let row = ((y + quietZone) * scale + dy) * side
                    for dx in 0..<scale { pixels[row + (x + quietZone) * scale + dx] = 0 }
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The side in points that fits `target`: a whole number of points per
    /// module, at least `minimumModule`, so the code stays crisp and big
    /// enough to scan even when the space is short.
    static func side(modules: Int, fitting target: CGFloat, minimumModule: Int = 2) -> CGFloat {
        guard modules > 0 else { return 0 }
        let perModule = max(minimumModule, Int((target / CGFloat(modules)).rounded(.down)))
        return CGFloat(perModule * modules)
    }
}
