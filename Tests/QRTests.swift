// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: QR codes. The payloads and their escaping (Wi-Fi, wa.me, the
/// vCard), telling what a clipboard holds, codes made and read back by Vision
/// with and without the star, the SVG's structure, the link safety hints,
/// the history in its own defaults suite with its backup registration, the
/// shortcut roles and the words in every language.
enum QRTests {
    static func run(_ suite: TestSuite) {
        wifi(suite)
        whatsapp(suite)
        contact(suite)
        detection(suite)
        matrix(suite)
        roundTrip(suite)
        svg(suite)
        safety(suite)
        history(suite)
        shortcuts(suite)
        strings(suite)
    }

    // MARK: Payloads

    private static func wifi(_ suite: TestSuite) {
        let tricky = QRWiFi(ssid: #"Studio;1,"A":\B"#, password: #"p@ss;w,rd:"x"\"#, security: .wpa)
        suite.expect(tricky.payload == #"WIFI:T:WPA;S:Studio\;1\,\"A\"\:\\B;P:p@ss\;w\,rd\:\"x\"\\;;"#,
                     "a Wi-Fi code escapes ; , : \" and \\ in the name and the password: \(tricky.payload ?? "nil")")
        suite.expect(QRWiFi.parse(tricky.payload ?? "") == tricky, "an escaped Wi-Fi code reads back as it was")
        suite.expect(QRWiFi(ssid: "Cafe", password: "ignored", security: .open).payload == "WIFI:T:nopass;S:Cafe;;",
                     "an open network leaves the password out")
        suite.expect(QRWiFi(ssid: "Lab", password: "k3y", security: .wep, hidden: true).payload
                        == "WIFI:T:WEP;S:Lab;P:k3y;H:true;;",
                     "WEP and a hidden network are written as such")
        suite.expect(QRWiFi(ssid: "", password: "x").payload == nil, "a network without a name makes no code")
        suite.expect(QRWiFi.parse("WIFI:S:Home;P:secret;T:WPA;;") == QRWiFi(ssid: "Home", password: "secret", security: .wpa),
                     "fields read in any order")
        suite.expect(QRWiFi.parse("wifi:T:nopass;S:Open;;")?.security == QRWiFiSecurity.open
                        && QRWiFi.parse("hello") == nil && QRWiFi.parse("WIFI:T:WPA;;") == nil,
                     "an open network reads back; text and a nameless network are not Wi-Fi")
    }

    private static func whatsapp(_ suite: TestSuite) {
        typealias Chat = QRWhatsApp
        suite.expect(Chat(number: "+62 812-3456-7890").normalizedNumber == "6281234567890"
                        && Chat(number: "0812 3456 7890", countryCode: "62").normalizedNumber == "6281234567890"
                        && Chat(number: "0062 812 3456 7890", countryCode: "1").normalizedNumber == "6281234567890"
                        && Chat(number: "(021) 555.1234", countryCode: "+62").normalizedNumber == "62215551234"
                        && Chat(number: "+0812", countryCode: "62").normalizedNumber == "0812"
                        && Chat(number: "15551234567", countryCode: "62").normalizedNumber == "15551234567",
                     "a number keeps only its digits; a local leading 0 takes the country code, + and 00 mean it is international")
        suite.expect(Chat(number: "0812345678", countryCode: "").normalizedNumber == "0812345678",
                     "without a country code a local number is left as written")
        let message = "Halo kak, galeri sudah siap! 50% & lainnya?\nBaris dua ☕ #1 = /ok"
        let chat = Chat(number: "+62 812 3456 7890", message: message)
        let payload = chat.payload ?? ""
        suite.expect(payload.hasPrefix("https://wa.me/6281234567890?text=Halo%20kak%2C%20galeri%20sudah%20siap%21%2050%25%20%26%20lainnya%3F%0ABaris%20dua%20%E2%98%95%20%231%20%3D%20%2Fok"),
                     "the message is percent-encoded as UTF-8, spaces, line breaks and reserved marks included: \(payload)")
        suite.expect(!payload.contains(" ") && !payload.contains("+"), "a wa.me link has no space and no plus left in it")
        suite.expect(URL(string: payload).flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                        .queryItems?.first { $0.name == "text" }?.value == message,
                     "the encoded message decodes back to the words typed")
        suite.expect(Chat(number: "+62 812 3456 7890").payload == "https://wa.me/6281234567890",
                     "no message, no text parameter")
        suite.expect(Chat(number: "+62 812 3456 7890", message: "   ").payload == "https://wa.me/6281234567890"
                        && Chat(number: "12").payload == nil && Chat(number: "abc").payload == nil,
                     "a blank message is left out, and a number too short to dial makes no code")
        let parsed = URL(string: payload).flatMap(QRWhatsApp.parse)
        suite.expect(parsed?.normalizedNumber == "6281234567890" && parsed?.message == message,
                     "a wa.me link reads back into its number and message")
        suite.expect(URL(string: "https://api.whatsapp.com/send?phone=6281234&text=hi").flatMap(QRWhatsApp.parse)
                        == QRWhatsApp(number: "+6281234", countryCode: "", message: "hi")
                        && URL(string: "https://example.com/6281234").flatMap(QRWhatsApp.parse) == nil,
                     "api.whatsapp.com reads too; other sites are not WhatsApp")
        suite.expect(QRWhatsApp.callingCode(region: "ID") == "62" && QRWhatsApp.callingCode(region: "us") == "1"
                        && QRWhatsApp.callingCode(region: "ZZ") == "" && QRWhatsApp.callingCode(region: nil) == "",
                     "the Mac's region gives the calling code, or none when unknown")
    }

    private static func contact(_ suite: TestSuite) {
        let card = QRContact(name: "Faiz Andhilmi", phone: "+62 812 3456 7890", email: "halo@satuvisual.id",
                             organization: "Satu Visual, Studio; Ltd", url: "https://satuvisual.id")
        let payload = card.payload ?? ""
        let lines = payload.components(separatedBy: "\r\n")
        suite.expect(lines == ["BEGIN:VCARD", "VERSION:3.0", "N:Andhilmi;Faiz;;;", "FN:Faiz Andhilmi",
                               #"ORG:Satu Visual\, Studio\; Ltd"#, "TEL;TYPE=CELL:+62 812 3456 7890",
                               "EMAIL:halo@satuvisual.id", "URL:https://satuvisual.id", "END:VCARD"],
                     "a contact is a minimal vCard 3.0 with CRLF lines and its commas and semicolons escaped: \(lines)")
        suite.expect(QRContact.parse(payload) == card, "the vCard reads back into the same fields")
        suite.expect(QRContact(name: #"A\B"#).payload?.contains(#"FN:A\\B"#) == true
                        && QRContact(name: "Solo").payload?.contains("N:;Solo;;;") == true,
                     "a backslash is escaped, and a single name is the given name")
        suite.expect(QRContact(phone: "0812").payload?.contains("FN:0812") == true && QRContact().payload == nil
                        && QRContact(organization: "Only a company").payload == nil,
                     "a card needs a name, a phone or an email, and is named after what it has")
    }

    // MARK: Detection

    private static func detection(_ suite: TestSuite) {
        typealias D = QRDetector
        suite.expect(D.detect("https://satuvisual.id/gallery/wisuda-2026") == .url("https://satuvisual.id/gallery/wisuda-2026")
                        && D.detect("  https://satuvisual.id  \n") == .url("https://satuvisual.id"),
                     "a link is a link, trimmed")
        suite.expect(D.detect("satuvisual.id") == .url("https://satuvisual.id")
                        && D.detect("www.example.xyz") == .url("https://www.example.xyz")
                        && D.detect("drive.google.com/drive/folders/abc") == .url("https://drive.google.com/drive/folders/abc"),
                     "a bare address takes https://")
        suite.expect(D.detect("notes.txt") == .text("notes.txt") && D.detect("v1.2.3") == .text("v1.2.3")
                        && D.detect("hello world") == .text("hello world")
                        && D.detect("localhost:3000") == .text("localhost:3000"),
                     "a file name, a version or words stay text")
        suite.expect(D.detect("mailto:halo@satuvisual.id") == .url("mailto:halo@satuvisual.id")
                        && D.detect("tel:+628123") == .url("tel:+628123")
                        && D.detect("javascript:alert(1)") == .text("javascript:alert(1)")
                        && D.detect("http://") == .text("http://"),
                     "mail and phone links are links; a script or an empty link is only text")
        suite.expect(D.detect("WIFI:T:WPA;S:Studio;P:k3y;;") == .wifi(QRWiFi(ssid: "Studio", password: "k3y", security: .wpa)),
                     "a Wi-Fi code is Wi-Fi")
        if case .contact(let card)? = D.detect("BEGIN:VCARD\nVERSION:3.0\nFN:Faiz\nTEL:0812\nEND:VCARD") {
            suite.expect(card.name == "Faiz" && card.phone == "0812", "a vCard is a contact")
        } else {
            suite.expect(false, "a vCard is a contact")
        }
        suite.expect(D.detect("https://wa.me/6281234567?text=Halo") == .whatsapp(QRWhatsApp(number: "+6281234567",
                                                                                          message: "Halo")),
                     "a wa.me link is a WhatsApp chat")
        suite.expect(D.detect("") == nil && D.detect("  \n ") == nil
                        && D.detect(String(repeating: "a", count: D.offerLimit + 1)) == nil
                        && D.detect(String(repeating: "a", count: D.offerLimit)) != nil
                        && D.detect("bell\u{7}") == nil && D.detect("nul\u{0}") == nil,
                     "nothing, a long text or control characters are not offered")
        suite.expect(D.offers("line one\nline two") && D.offers("https://x.com") && !D.offers(""),
                     "the clipboard card offers a code for a link or a short text")
        suite.expect(QRContent.text("  ").payload == nil && QRContent.url(" https://a.co \n").payload == "https://a.co"
                        && QRContent.text(" keep  spaces ").payload == " keep  spaces ",
                     "an empty field makes no code; a link is trimmed, text is kept as typed")
    }

    // MARK: Codes

    private static func matrix(_ suite: TestSuite) {
        guard let code = QRMatrix.make("https://satuvisual.id", correction: .medium) else {
            suite.expect(false, "CoreImage makes a code")
            return
        }
        suite.expect(code.size >= 21 && (code.size - 21) % 4 == 0 && code.modules.count == code.size * code.size,
                     "a code is 21 + 4n modules a side: \(code.size)")
        func finder(atX x0: Int, y y0: Int) -> Bool {
            (0..<7).allSatisfy { y in
                (0..<7).allSatisfy { x in
                    let ring = x == 0 || y == 0 || x == 6 || y == 6
                    let core = (2...4).contains(x) && (2...4).contains(y)
                    return code[x0 + x, y0 + y] == (ring || core)
                }
            }
        }
        suite.expect(finder(atX: 0, y: 0) && finder(atX: code.size - 7, y: 0) && finder(atX: 0, y: code.size - 7),
                     "the margin is trimmed: the three finder patterns sit in the corners")
        let high = QRMatrix.make("https://satuvisual.id", correction: .high)
        suite.expect((high?.size ?? 0) >= code.size, "High correction makes the same text a denser or equal code")
        suite.expect(QRMatrix.make("", correction: .medium) == nil
                        && QRMatrix.make(String(repeating: "x", count: QRCorrection.medium.capacity + 1), correction: .medium) == nil
                        && QRMatrix.make(String(repeating: "x", count: 1000), correction: .high) != nil,
                     "nothing or more than the level holds makes no code")
        let pad = code.logoPad
        suite.expect(pad.side >= 5 && pad.side % 2 == code.size % 2 && pad.origin * 2 + pad.side == code.size
                        && pad.origin >= 8 && Double(pad.side * pad.side) / Double(code.size * code.size) < 0.09,
                     "the star's pad is centred, clear of the finder patterns and under a tenth of the code")
        suite.expect(!code.isDrawn(x: code.size / 2, y: code.size / 2, logo: true)
                        && code.isDrawn(x: 0, y: 0, logo: true) == code[0, 0],
                     "modules under the pad are left white; the rest are drawn as they are")
        suite.expect(QRCorrection.stored("H") == .high && QRCorrection.stored("x") == .medium && QRCorrection.stored(nil) == .medium
                        && QRCorrection.allCases.map(\.percent) == [7, 15, 25, 30],
                     "an unknown stored level reads as medium")

        guard let image = QRRender.image(code, moduleSize: 4, logo: false) else {
            suite.expect(false, "the code renders")
            return
        }
        let total = code.size + QRRender.quietZone * 2
        suite.expect(image.width == total * 4 && image.height == total * 4,
                     "a render is the code and its four module quiet zone, whole pixels a module")
        let pixels = rgba(image)
        func dark(_ x: Int, _ y: Int) -> Bool { pixels[(y * image.width + x) * 4] < 64 }
        suite.expect(!dark(0, 0) && !dark(15, 15) && dark(16, 16) && dark(16 + 27, 16 + 27) && !dark(16 + 28, 16 + 4),
                     "the quiet zone is white and the first finder starts four modules in, square edged")
        let reds = Set(stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] })
        suite.expect(reds.isSubset(of: [0x0A, 0xFF]), "only two shades: dark modules on white, no blur: \(reds.sorted())")
        suite.expect(QRRender.pngData(code, logo: true).map { $0.starts(with: [0x89, 0x50, 0x4E, 0x47]) } == true,
                     "a code writes as a PNG")
    }

    private static func roundTrip(_ suite: TestSuite) {
        let payloads = [
            "https://satuvisual.id/gallery/wisuda-sma-2026?client=ayu&ref=qr",
            QRWiFi(ssid: #"Studio;1,"A":\B"#, password: "p@ss;w,rd", security: .wpa).payload ?? "",
            QRWhatsApp(number: "0812 3456 7890", countryCode: "62", message: "Halo, galeri sudah siap!").payload ?? "",
            QRContact(name: "Faiz Andhilmi", phone: "+62 812 3456 7890", email: "halo@satuvisual.id",
                      organization: "Satu Visual").payload ?? "",
            "Meja 4: kopi susu, dua gelas",
        ]
        for payload in payloads {
            for logo in [false, true] {
                let correction: QRCorrection = logo ? .high : .medium
                guard let code = QRMatrix.make(payload, correction: correction),
                      let image = QRRender.image(code, moduleSize: 8, logo: logo) else {
                    suite.expect(false, "\(payload) makes a code")
                    continue
                }
                let read = QRScanner.read(image)
                suite.expect(read == [payload],
                             "made and read back by Vision\(logo ? " with the star" : ""): \(payload) -> \(read)")
            }
        }
        // A long link reaches a version with alignment patterns near the
        // middle; the star must still leave it readable.
        let long = "https://satuvisual.id/clients/" + String(repeating: "gallery-", count: 18) + "end"
        if let code = QRMatrix.make(long, correction: .high), let image = QRRender.image(code, moduleSize: 6, logo: true) {
            suite.expect(QRScanner.read(image) == [long], "a dense code with the star still reads (\(code.size) modules)")
        } else {
            suite.expect(false, "a long link makes a code")
        }
        // Two codes side by side read top to bottom, then left to right.
        if let a = QRMatrix.make("left", correction: .medium).flatMap({ QRRender.image($0, moduleSize: 6, logo: false) }),
           let b = QRMatrix.make("right", correction: .medium).flatMap({ QRRender.image($0, moduleSize: 6, logo: false) }),
           let pair = sideBySide(a, b) {
            suite.expect(QRScanner.read(pair) == ["left", "right"], "two codes read left to right: \(QRScanner.read(pair))")
        }
        suite.expect(QRScanner.read(blank(200)).isEmpty, "an image without a code reads nothing")
    }

    // MARK: SVG

    private static func svg(_ suite: TestSuite) {
        guard let code = QRMatrix.make("https://satuvisual.id", correction: .high) else {
            suite.expect(false, "a code for the SVG")
            return
        }
        let total = code.size + QRRender.quietZone * 2
        let plain = QRRender.svg(code, logo: false)
        suite.expect(plain.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg xmlns=\"http://www.w3.org/2000/svg\"")
                        && plain.contains("viewBox=\"0 0 \(total) \(total)\"")
                        && plain.contains("shape-rendering=\"crispEdges\"")
                        && plain.contains("<rect width=\"\(total)\" height=\"\(total)\" fill=\"#FFFFFF\"/>")
                        && plain.hasSuffix("</svg>\n") && !plain.contains("evenodd"),
                     "an SVG is one module a unit, a white square, then the dark path")
        suite.expect(XMLParser(data: Data(plain.utf8)).parse(), "the SVG is well formed XML")
        let paths = attribute("d", in: plain)
        suite.expect(paths.count == 1, "one path holds every module without the star")
        let drawn = modules(fromPath: paths.first ?? "", offset: QRRender.quietZone)
        var expected = Set<ModulePoint>()
        for y in 0..<code.size {
            for x in 0..<code.size where code.isDrawn(x: x, y: y, logo: false) { expected.insert(ModulePoint(x: x, y: y)) }
        }
        suite.expect(drawn == expected, "the path's row runs cover exactly the dark modules")
        suite.expect((paths.first ?? "").components(separatedBy: "M").count - 1 == code.runs(logo: false).count,
                     "one subpath a run")

        let starred = QRRender.svg(code, logo: true)
        let starredPaths = attribute("d", in: starred)
        suite.expect(XMLParser(data: Data(starred.utf8)).parse() && starredPaths.count == 2
                        && starred.contains("fill-rule=\"evenodd\""),
                     "with the star, a second even-odd path draws it")
        let starModules = modules(fromPath: starredPaths.first ?? "", offset: QRRender.quietZone)
        let pad = code.logoPad
        suite.expect(!starModules.contains { $0.x >= pad.origin && $0.x < pad.origin + pad.side
                                             && $0.y >= pad.origin && $0.y < pad.origin + pad.side },
                     "no module is drawn under the star's pad")
        let rect = QRRender.starRect(code)
        let numbers = (starredPaths.last ?? "").split(whereSeparator: { !"0123456789.-".contains($0) }).compactMap { Double($0) }
        suite.expect(!numbers.isEmpty && numbers.allSatisfy { $0 >= rect.minX - 0.01 && $0 <= rect.maxX + 0.01 },
                     "the star stays inside its pad")
    }

    // MARK: Safety

    private static func safety(_ suite: TestSuite) {
        typealias S = QRLinkSafety
        suite.expect(S.flags("https://satuvisual.id/gallery") == [] && S.flags("HTTPS://Satuvisual.id") == [],
                     "a named https site has nothing to flag")
        suite.expect(S.flags("http://satuvisual.id") == [.notHTTPS], "http is flagged")
        suite.expect(S.flags("https://192.168.1.10/login") == [.ipAddress]
                        && S.flags("http://10.0.0.1:8080") == [.notHTTPS, .ipAddress]
                        && S.flags("https://[::1]:8443/") == [.ipAddress]
                        && S.flags("https://3232235777/") == [.ipAddress]
                        && S.flags("https://0xC0A80001/") == [.ipAddress],
                     "an IP host is flagged, in dotted, IPv6, decimal and hex form")
        suite.expect(S.flags("https://bank.com@evil.example/") == [.userInfo]
                        && S.flags("https://user:pass@site.com") == [.userInfo],
                     "a name before @ is flagged")
        suite.expect(S.flags("https://xn--pple-43d.com") == [.lookalike], "punycode is flagged")
        suite.expect(S.flags("javascript:alert(1)") == [.notWeb] && S.flags("file:///etc/hosts") == [.notWeb]
                        && S.flags("someapp://do/thing") == [.notWeb],
                     "a script, a file or an app's own scheme is not a web page")
        suite.expect(S.flags("WIFI:T:WPA;S:x;;") == [] && S.flags("mailto:a@b.co") == [] && S.flags("hello there") == []
                        && S.flags("just text") == [] && S.flags("BEGIN:VCARD") == [],
                     "Wi-Fi, mail and plain text are not links to warn about")
        suite.expect(S.openableURL("https://satuvisual.id")?.host == "satuvisual.id"
                        && S.openableURL("http://a.co") != nil && S.openableURL("javascript:alert(1)") == nil
                        && S.openableURL("mailto:a@b.co") == nil && S.openableURL("https:// spaced") == nil,
                     "only a web address can be opened from the result")
        suite.expect(S.isIPAddress("8.8.8.8") && S.isIPAddress("fe80::1") && !S.isIPAddress("satuvisual.id")
                        && !S.isIPAddress("1.example") && !S.isIPAddress("0x"),
                     "IP addresses are told from names")
    }

    // MARK: History and settings

    private static func history(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.qr"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "the isolated defaults suite opens")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        suite.expect(QRHistory.load(defaults).isEmpty, "a fresh Mac has made no codes")
        for index in 1...12 { QRHistory.record("code \(index)", defaults: defaults) }
        let twelve = QRHistory.load(defaults)
        suite.expect(twelve.count == QRHistory.maximum && twelve.first == "code 12" && twelve.last == "code 3",
                     "the last ten codes are kept, newest first: \(twelve)")
        QRHistory.record("code 5", defaults: defaults)
        let again = QRHistory.load(defaults)
        suite.expect(again.first == "code 5" && again.count == 10 && again.filter { $0 == "code 5" }.count == 1,
                     "making a code again moves it to the front, once")
        QRHistory.record("", defaults: defaults)
        suite.expect(QRHistory.load(defaults) == again, "an empty code is never kept")
        suite.expect(QRHistory.remove("code 5", defaults: defaults).first == "code 12"
                        && !QRHistory.load(defaults).contains("code 5"),
                     "one code can be forgotten")
        defaults.set(["a", "", "a", "b"] + (1...20).map { "x\($0)" }, forKey: DefaultsKey.zenithQRHistory)
        suite.expect(QRHistory.load(defaults) == ["a", "b"] + (1...8).map { "x\($0)" },
                     "a stored list is read without blanks or repeats, ten at most")
        QRHistory.clear(defaults)
        suite.expect(QRHistory.load(defaults).isEmpty, "the list clears")
        suite.expect(QRHistory.adding("new", to: (1...10).map(String.init)) == ["new"] + (1...9).map(String.init),
                     "adding to a full list drops the oldest")

        suite.expect(QRSettings.correction(defaults) == .medium && !QRSettings.logo(defaults),
                     "codes start at medium correction without the star")
        defaults.set("Q", forKey: DefaultsKey.zenithQRCorrection)
        suite.expect(QRSettings.correction(defaults) == .quartile, "the chosen level is used")
        defaults.set(true, forKey: DefaultsKey.zenithQRLogo)
        suite.expect(QRSettings.correction(defaults) == .high && QRSettings.logo(defaults),
                     "the star always makes the code at High")

        let registered = Defaults.registeredDefaults
        let ours = QRSettings.registered
        suite.expect(ours.count == 5 && ours.allSatisfy { key, value in
            (registered[key] as? NSObject)?.isEqual(value) == true
        }, "every QR option and the history are registered with their first-run values")
        let exported = SettingsBackupSupport.exportKeys()
        let keys = [DefaultsKey.zenithQRCorrection, DefaultsKey.zenithQRLogo, DefaultsKey.zenithQRShortcutEnabled,
                    DefaultsKey.zenithQRShortcut, DefaultsKey.zenithQRScanShortcutEnabled, DefaultsKey.zenithQRScanShortcut,
                    DefaultsKey.zenithQRHistory]
        suite.expect(keys.allSatisfy(exported.contains) && !keys.contains(where: SettingsBackupSupport.machineStateKeys.contains),
                     "a settings backup carries the QR options, shortcuts and history")
        suite.expect(SettingsBackupSupport.valueLooksRight(DefaultsKey.zenithQRHistory, ["https://satuvisual.id"])
                        && !SettingsBackupSupport.valueLooksRight(DefaultsKey.zenithQRHistory, "one string")
                        && SettingsBackupSupport.valueLooksRight(DefaultsKey.zenithQRCorrection, "H"),
                     "a restored history must be a list of texts")
    }

    private static func shortcuts(_ suite: TestSuite) {
        suite.expect(GlobalShortcut.zenithQRDefault == GlobalShortcut(keyCode: 15, modifiers: [.control, .option, .command])
                        && GlobalShortcut.zenithQRScanDefault
                            == GlobalShortcut(keyCode: 15, modifiers: [.control, .option, .shift, .command]),
                     "a QR of the clipboard is Control-Option-Command-R; scanning adds Shift")
        suite.expect(GlobalShortcut.zenithQRDefault != GlobalShortcut.quitAllDefault
                        && GlobalShortcutRole.allCases.filter { $0.defaultShortcut == .zenithQRDefault } == [.zenithQR]
                        && GlobalShortcutRole.allCases.filter { $0.defaultShortcut == .zenithQRScanDefault } == [.zenithQRScan],
                     "neither default is taken by another shortcut (Control-Option-Command-Q is Quit all's)")
        let make = GlobalShortcutRole.zenithQR, scan = GlobalShortcutRole.zenithQRScan
        suite.expect(make.storageKey == DefaultsKey.zenithQRShortcut && make.requiredEnableKeys == [DefaultsKey.zenithQRShortcutEnabled]
                        && make.feature == .clipboardHistory
                        && scan.storageKey == DefaultsKey.zenithQRScanShortcut
                        && scan.requiredEnableKeys == [DefaultsKey.zenithQRScanShortcutEnabled] && scan.feature == .screenOCR,
                     "the roles are wired to their own keys; scanning follows the screen text tool")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[make.storageKey] as? String == GlobalShortcut.zenithQRDefault.storageValue
                        && registered[scan.storageKey] as? String == GlobalShortcut.zenithQRScanDefault.storageValue
                        && registered[DefaultsKey.zenithQRShortcutEnabled] as? Bool == true
                        && registered[DefaultsKey.zenithQRScanShortcutEnabled] as? Bool == true,
                     "both shortcuts are on by default and registered for backups")
        suite.expect(GlobalShortcut(storageValue: GlobalShortcut.zenithQRScanDefault.storageValue) == .zenithQRScanDefault,
                     "the scan shortcut survives being written and read back")
        let capture = GlobalShortcutRole.captureRoles(in: GlobalShortcutRole.allCases)
        suite.expect(capture.contains(.zenithQRScan) && capture.last == .designOverlay && !capture.contains(.zenithQR),
                     "scanning lists with the screen capture shortcuts, before the design overlay")
        suite.expect(!GlobalShortcutRole.activeRoles(isOn: { $0 != DefaultsKey.zenithQRShortcutEnabled }).contains(make)
                        && !GlobalShortcutRole.activeRoles(isOn: { _ in true }, isAvailable: { $0 != .screenOCR }).contains(scan),
                     "a shortcut switched off, or a tool not installed, leaves its keys free")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let values = Mirror(reflecting: ZenithStrings.qr(language)).children.compactMap { $0.value as? String }
            suite.expect(values.count == 54 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words the QR codes, with curly apostrophes and no em dash")
        }
        suite.expect(GlobalShortcutRole.zenithQR.title(L10n.shared.s) == ZenithStrings.qr(L10n.shared.language).fromClipboard
                        && GlobalShortcutRole.zenithQRScan.title(L10n.shared.s) == ZenithStrings.qr(L10n.shared.language).scan,
                     "the shortcuts are named after what they do")
        suite.expect(ZenithHomeWidget.qr.module == nil && ZenithHomeWidget.qr.symbol == "qrcode",
                     "the QR widget stands alone on the home page")
    }

    // MARK: Helpers

    private struct ModulePoint: Hashable { let x: Int; let y: Int }

    /// The modules a path of `Mx yhNv1h-Nz` runs covers, in matrix units.
    private static func modules(fromPath path: String, offset: Int) -> Set<ModulePoint> {
        var result = Set<ModulePoint>()
        for run in path.components(separatedBy: "M").dropFirst() {
            let scanner = Scanner(string: run)
            guard let x = scanner.scanInt(), let y = scanner.scanInt(), scanner.scanString("h") != nil,
                  let length = scanner.scanInt() else { continue }
            for dx in 0..<length { result.insert(ModulePoint(x: x - offset + dx, y: y - offset)) }
        }
        return result
    }

    private static func attribute(_ name: String, in svg: String) -> [String] {
        svg.components(separatedBy: " \(name)=\"").dropFirst().compactMap { $0.components(separatedBy: "\"").first }
    }

    private static func rgba(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return pixels }
        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private static func blank(_ side: Int) -> CGImage {
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()!
    }

    private static func sideBySide(_ a: CGImage, _ b: CGImage) -> CGImage? {
        let width = a.width + b.width + 40, height = max(a.height, b.height) + 40
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(a, in: CGRect(x: 10, y: 20, width: a.width, height: a.height))
        context.draw(b, in: CGRect(x: a.width + 30, y: 20, width: b.width, height: b.height))
        return context.makeImage()
    }
}
