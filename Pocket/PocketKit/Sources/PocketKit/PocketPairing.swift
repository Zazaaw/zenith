// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation

/// Where the paired devices meet: a Supabase project's URL and its public
/// (anon) key. The key only opens the two relay functions and Realtime; it
/// never reads anything, because everything there is sealed.
public struct PocketRelayConfig: Codable, Hashable, Sendable {
    public var url: URL
    public var anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    /// Accepts only an https Supabase-style origin and a JWT-shaped key.
    public var isValid: Bool {
        guard url.scheme == "https", let host = url.host, !host.isEmpty, url.path.isEmpty || url.path == "/" else { return false }
        let parts = anonKey.split(separator: ".")
        return parts.count == 3 && anonKey.count < 2048
    }
}

/// One pairing between a Mac and a phone: the relay, a random identity the
/// box and channel names are derived from, and the 256-bit key that seals
/// every message. It travels once, inside the QR code Zenith shows.
public struct PocketPairing: Codable, Hashable, Sendable {
    public static let urlScheme = "zenith-pocket"
    public static let version = 1

    public var relay: PocketRelayConfig
    /// 32 random bytes. Never sent anywhere except inside the QR code.
    public var pairID: Data
    /// 32 random bytes: the ChaCha20-Poly1305 key.
    public var key: Data
    /// The Mac's name, for the phone to show.
    public var macName: String

    public init(relay: PocketRelayConfig, pairID: Data, key: Data, macName: String) {
        self.relay = relay
        self.pairID = pairID
        self.key = key
        self.macName = macName
    }

    /// A fresh pairing for this Mac.
    public static func make(relay: PocketRelayConfig, macName: String) -> PocketPairing {
        PocketPairing(relay: relay, pairID: randomBytes(32), key: randomBytes(32), macName: macName)
    }

    public var symmetricKey: SymmetricKey { SymmetricKey(data: key) }

    // MARK: Derived names

    /// The Realtime topic both sides join.
    public var channelName: String { "pocket-" + String(derive("channel").prefix(40)) }
    /// The Mac's last state (battery, coding, Claude, wallpaper hash …).
    public var macBoxID: String { derive("box/mac") }
    /// The phone's last report (its own and the Watch's battery).
    public var phoneBoxID: String { derive("box/phone") }
    /// The Mac's wallpaper thumbnail, kept apart because it is the large one.
    public var wallpaperBoxID: String { derive("box/wallpaper") }

    func derive(_ purpose: String) -> String {
        var hasher = SHA256()
        hasher.update(data: Data("zenith-pocket/v1/".utf8))
        hasher.update(data: Data(purpose.utf8))
        hasher.update(data: pairID)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: QR code

    /// `zenith-pocket://pair?v=1&u=…&a=…&p=…&k=…&n=…`
    public var url: URL {
        var c = URLComponents()
        c.scheme = Self.urlScheme
        c.host = "pair"
        c.queryItems = [
            URLQueryItem(name: "v", value: String(Self.version)),
            URLQueryItem(name: "u", value: relay.url.absoluteString),
            URLQueryItem(name: "a", value: relay.anonKey),
            URLQueryItem(name: "p", value: pairID.base64URL),
            URLQueryItem(name: "k", value: key.base64URL),
            URLQueryItem(name: "n", value: macName),
        ]
        return c.url!
    }

    /// Reads a scanned code. Anything malformed, from another version, or
    /// with keys of the wrong size is refused.
    public init?(url: URL) {
        guard url.scheme == Self.urlScheme, url.host == "pair",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("v") == String(Self.version),
              let relayURL = value("u").flatMap(URL.init(string:)),
              let anon = value("a"),
              let pair = value("p").flatMap(Data.init(base64URL:)), pair.count == 32,
              let key = value("k").flatMap(Data.init(base64URL:)), key.count == 32 else { return nil }
        let relay = PocketRelayConfig(url: relayURL, anonKey: anon)
        guard relay.isValid else { return nil }
        let name = String((value("n") ?? "Mac").prefix(64))
        self.init(relay: relay, pairID: pair, key: key, macName: name.isEmpty ? "Mac" : name)
    }
}

func randomBytes(_ count: Int) -> Data {
    let key = SymmetricKey(size: SymmetricKeySize(bitCount: count * 8))
    return key.withUnsafeBytes { Data($0) }
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL: String) {
        var s = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }
}
