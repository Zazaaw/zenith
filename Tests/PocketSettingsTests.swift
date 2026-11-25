// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreImage
import Foundation

/// Zenith fork: Settings → iPhone & Watch. Pocket starts off with everything
/// but answering shared; the relay fields read past what a paste brings and
/// refuse the keys that must stay in the dashboard; each phase draws its own
/// pairing section and preview state; the captions; and the pairing code
/// reads back, through a QR detector, as the very pairing it was made from.
enum PocketSettingsTests {
    static func run(_ suite: TestSuite) {
        defaults(suite)
        relayURL(suite)
        relayKey(suite)
        stages(suite)
        captions(suite)
        code(suite)
        search(suite)
    }

    /// A JWT-shaped key whose payload names `role`.
    private static func jwt(_ role: String) -> String {
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
            + Data(#"{"iss":"supabase","ref":"abcdefghijklmnop","role":"\#(role)","iat":1700000000,"exp":2000000000}"#.utf8).base64URL
            + ".k3pL0cR9gS1u7oT8b2nQ5zY4xW6vE0aH1jM3fD7eC9s"
    }

    private static let relay = PocketRelayConfig(url: URL(string: "https://abcdefghijklmnop.supabase.co")!, anonKey: jwt("anon"))

    private static func defaults(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.pocket-defaults"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        PocketPreferences.registerDefaults(in: defaults)
        suite.expect(!defaults.bool(forKey: PocketDefaults.enabled), "Pocket starts off")
        suite.expect(defaults.bool(forKey: PocketDefaults.shareWallpaper) && defaults.bool(forKey: PocketDefaults.shareAgents)
                     && defaults.bool(forKey: PocketDefaults.shareNowPlaying), "wallpaper, Claude Code and music are shared")
        suite.expect(!defaults.bool(forKey: PocketDefaults.allowAnswers), "the phone can't answer Claude Code until allowed")
        suite.expect(PocketPreferences.initial.keys.allSatisfy { $0.hasPrefix("zenithPocket") }, "every key is Pocket's own")
    }

    private static func relayURL(_ suite: TestSuite) {
        func url(_ text: String) -> String? { PocketRelayDraft.normalizedURL(text)?.absoluteString }
        let origin = "https://abcdefghijklmnop.supabase.co"
        for typed in ["  https://abcdefghijklmnop.supabase.co/  ", "abcdefghijklmnop.supabase.co",
                      "https://abcdefghijklmnop.supabase.co/rest/v1/", "HTTPS://ABCDEFGHIJKLMNOP.supabase.co",
                      "\nhttps://abcdefghijklmnop.supabase.co//\n"] {
            suite.expect(url(typed) == origin, "\"\(typed)\" reads as the project's origin: \(url(typed) ?? "nil")")
        }
        suite.expect(url("https://localhost:54321") == "https://localhost:54321", "a port is kept")
        for typed in ["", "   ", "http://abcdefghijklmnop.supabase.co", "https://abcdefghijklmnop.supabase.co/functions/v1",
                      "https://abcdefghijklmnop.supabase.co?x=1", "https://user:secret@abcdefghijklmnop.supabase.co",
                      "https://", "ftp://example.com", "https://abcdefghijklmnop.supabase.co#top"] {
            suite.expect(url(typed) == nil, "\"\(typed)\" is not a relay origin")
        }
        let draft = PocketRelayDraft(url: "http://abcdefghijklmnop.supabase.co", key: jwt("anon"))
        suite.expect(draft.urlProblem == .url && draft.keyProblem == nil && draft.relay == nil,
                     "plain http is refused on the URL field alone")
        let empty = PocketRelayDraft(url: " ", key: "\n")
        suite.expect(empty.isEmpty && empty.urlProblem == nil && empty.keyProblem == nil && empty.relay == nil,
                     "empty fields have nothing to say and nothing to save")
    }

    private static func relayKey(_ suite: TestSuite) {
        let anon = jwt("anon")
        let wrapped = "  \"" + anon.prefix(40) + "\n   " + anon.dropFirst(40) + "\"  "
        suite.expect(PocketRelayDraft.normalizedKey(wrapped) == anon, "spaces, line breaks and quotes are dropped from a key")
        let draft = PocketRelayDraft(url: "abcdefghijklmnop.supabase.co/", key: wrapped)
        suite.expect(draft.relay == relay && draft.relay?.isValid == true, "a pasted URL and key make the relay")
        suite.expect(PocketRelayDraft(relay).relay == relay, "a saved relay fills the fields and reads back the same")
        suite.expect(PocketRelayDraft(nil).isEmpty, "no relay leaves the fields empty")
        func problem(_ key: String) -> PocketRelayDraft.Problem? {
            PocketRelayDraft(url: "https://abcdefghijklmnop.supabase.co", key: key).keyProblem
        }
        suite.expect(problem(jwt("service_role")) == .secretKey, "the service_role key is refused")
        suite.expect(problem("sb_secret_abc123") == .secretKey, "a secret key is refused")
        suite.expect(problem("sb_publishable_abc123") == .newFormatKey, "a publishable key asks for the legacy anon key")
        for key in ["nonsense", "a..b", "a.b", ".b.c", String(repeating: "a.", count: 2) + String(repeating: "x", count: 2100)] {
            suite.expect(problem(key) == .key, "\"\(key.prefix(20))\" is not an anon key")
        }
        suite.expect(PocketRelayDraft(url: "https://abcdefghijklmnop.supabase.co", key: jwt("service_role")).relay == nil,
                     "nothing is saved with the service_role key")
        suite.expect(problem("header.notbase64!.sig") == nil, "a key whose payload can't be read is left to the relay")
    }

    private static func stages(_ suite: TestSuite) {
        let pairing = PocketPairing.make(relay: relay, macName: "Studio Mac")
        let seen = Date(timeIntervalSinceReferenceDate: 800_000_000)
        typealias Stage = PocketPairingStage
        suite.expect(Stage.of(.off, enabled: false, hasRelay: false) == .needs([.enable, .relay]), "off and no relay: both")
        suite.expect(Stage.of(.off, enabled: true, hasRelay: false) == .needs([.relay]), "on, no relay: the relay")
        suite.expect(Stage.of(.off, enabled: false, hasRelay: true) == .needs([.enable]), "a relay, off: the switch")
        suite.expect(Stage.of(.off, enabled: true, hasRelay: true) == .starting, "all set, the service not yet reporting")
        suite.expect(Stage.of(.unpaired, enabled: true, hasRelay: true) == .unpaired, "unpaired offers to pair")
        suite.expect(Stage.of(.pairing(pairing), enabled: true, hasRelay: true) == .pairing(pairing.url),
                     "pairing shows the pairing's own code")
        suite.expect(Stage.of(.paired(lastSeen: seen), enabled: true, hasRelay: true) == .paired(lastSeen: seen), "paired")
        suite.expect(Stage.needs([.enable]).previewState == PocketPreviewState.unpaired
                     && Stage.starting.previewState == PocketPreviewState.unpaired
                     && Stage.unpaired.previewState == PocketPreviewState.unpaired
                     && Stage.pairing(pairing.url).previewState == PocketPreviewState.pairing
                     && Stage.paired(lastSeen: nil).previewState == PocketPreviewState.paired,
                     "the preview opens on the state the phone is in")
    }

    private static func captions(_ suite: TestSuite) {
        let text = ZenithStrings.pocket(.enUS)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let phone = PocketDeviceReport.Device(kind: .iphone, name: "iPhone 13 Pro", percent: 43, charging: true,
                                              readAt: now.addingTimeInterval(-125))
        suite.expect(PocketSettingsText.caption(phone, now: now, text) == "43% · charging · seen 2 min ago",
                     PocketSettingsText.caption(phone, now: now, text))
        let watch = PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 140, charging: false,
                                              readAt: now.addingTimeInterval(30))
        suite.expect(PocketSettingsText.caption(watch, now: now, text) == "100% · seen just now",
                     "a level past 100 and a clock running ahead read sensibly")
        suite.expect(PocketSettingsText.ago(3 * 3600, text) == "3 h ago" && PocketSettingsText.ago(2 * 86_400, text) == "2 d ago",
                     "hours and days")
        suite.expect(PocketSettingsText.link(.live, text) == text.linkLive && PocketSettingsText.link(.connecting, text) == text.linkConnecting
                     && PocketSettingsText.link(.offline, text) == text.linkOffline, "the link's three states")
        suite.expect(PocketSettingsText.lastSeen(nil, now: now, text) == text.waitingFirst, "no message yet")
        suite.expect(PocketSettingsText.lastSeen(now.addingTimeInterval(-600), now: now, text) == "last message 10 min ago",
                     "the last message")
        suite.expect(PocketSettingsText.phoneName(PocketStore.sampleDevices, text) == "iPhone 13 Pro"
                     && PocketSettingsText.phoneName([], text) == "iPhone", "the phone's name, else iPhone")
        suite.expect(text.unpair("iPhone 13 Pro") == "Unpair iPhone 13 Pro?", "Unpair names the phone")
        for problem in [PocketRelayDraft.Problem.url, .key, .secretKey, .newFormatKey] {
            suite.expect(!PocketSettingsText.problem(problem, text).isEmpty, "\(problem) has a line")
        }
        suite.expect(text.all.count > 50 && text.all.allSatisfy { !$0.isEmpty }, "every page string has text")
        let preview = ZenithPocketPreviewStrings.shared
        suite.expect(preview.headlineBold.hasSuffix(",") && preview.headlineRest.hasPrefix(" "),
                     "the phone's headline reads as one sentence")
    }

    private static func code(_ suite: TestSuite) {
        let pairing = PocketPairing.make(relay: relay, macName: "Studio Mac")
        guard let matrix = PocketQR.matrix(for: pairing.url), let image = PocketQR.image(matrix),
              let big = PocketQR.image(matrix, scale: 6) else {
            suite.expect(false, "the pairing URL makes a code")
            return
        }
        let across = PocketQR.modulesAcross(matrix)
        suite.expect(across == matrix.size + 8 && image.width == across && image.height == across,
                     "one pixel per module, inside a four-module quiet zone (\(image.width) for \(matrix.size))")
        suite.expect(big.width == across * 6, "a scale gives that many pixels per module")
        suite.expect(matrix.size <= 81, "the code stays small enough to scan from a screen (\(matrix.size) modules)")
        if let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) {
            let row = image.bytesPerRow
            suite.expect(bytes[0] == 255 && bytes[3 * row + 3] == 255, "the quiet zone is white")
            suite.expect(bytes[4 * row + 4] == 0 && bytes[4 * row + 10] == 0, "the finder pattern starts past the quiet zone")
        }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let message = detector?.features(in: CIImage(cgImage: big)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
        suite.expect(message == pairing.url.absoluteString, "the code reads back as the pairing URL")
        suite.expect(message.flatMap(URL.init(string:)).flatMap(PocketPairing.init(url:)) == pairing,
                     "and the phone gets the very pairing, key included")
        // Whole points per module, two at the least.
        suite.expect(PocketQR.side(modules: 77, fitting: 232) == 231, "the largest whole module that fits")
        suite.expect(PocketQR.side(modules: 77, fitting: 100) == 154, "never under two points a module")
        suite.expect(PocketQR.side(modules: 0, fitting: 232) == 0, "no modules, no code")
    }

    private static func search(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.pocket-search"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let state = SettingsSearchState(defaults: defaults, hardware: .init(
            battery: true, notchedDisplay: true, plainDisplay: false,
            keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        let all: (AppFeature) -> Bool = { _ in true }
        func routes(_ query: String, top: Int = ForkSettingsSearchTests.top) -> [FeatureSettingsDestination] {
            let items = SettingsDirectory.searchItems(Strings.localized(.enUS), language: .enUS, state: state)
            return SettingsSearchSupport.groupedMatchingItems(query: query, items: items, isAvailable: all)
                .flatMap { ($0.parentMatches ? [$0.parentSuggestion] : []) + $0.suggestions }
                .prefix(top)
                .map { SettingsSearchSupport.route(for: $0, isAvailable: all).destination }
        }
        let anchored = { (anchor: SettingsSectionAnchor) in FeatureSettingsDestination(.pocket, sectionAnchor: anchor) }
        let pocket: Set<FeatureSettingsDestination> = [
            FeatureSettingsDestination(.pocket), anchored(.zenithPocket), anchored(.zenithPocketRelay),
            anchored(.zenithPocketPairing), anchored(.zenithPocketSharing),
        ]
        for query in ["iphone & watch", "pocket", "zenith pocket", "hp", "pasangkan", "supabase", "anon key", "pair iphone",
                      "let the phone answer"] {
            let found = routes(query)
            suite.expect(found.contains(where: pocket.contains),
                         "searching \"\(query)\" offers iPhone & Watch among the first \(ForkSettingsSearchTests.top): \(found)")
        }
        // Words other pages own first (Batteries' Watch, the QR code page) still find this one further down.
        for query in ["jam tangan", "qr"] {
            let found = routes(query, top: 10)
            suite.expect(found.contains(where: pocket.contains), "searching \"\(query)\" offers iPhone & Watch too: \(found)")
        }
        suite.expect(routes("pasangkan").contains(anchored(.zenithPocketPairing)), "\"pasangkan\" opens Pairing")
        suite.expect(routes("supabase").contains(anchored(.zenithPocketRelay)), "\"supabase\" opens the relay")
        let aliases = ZenithSettingsSearch.pageAliases[.page(.pocket)] ?? []
        suite.expect(["pocket", "hp", "jam", "pasangkan", "qr"].allSatisfy(aliases.contains), "the page's aliases")
        suite.expect(FeatureVisibilitySupport.features(for: .pocket).isEmpty, "a page of the app's own, which no hub feature hides")
        suite.expect([SettingsSectionAnchor.zenithPocket, .zenithPocketRelay, .zenithPocketPairing, .zenithPocketSharing]
                        .allSatisfy { $0.page == .pocket }, "the page's anchors land on it")
    }
}
