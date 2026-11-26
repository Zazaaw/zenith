// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Meetings. The island reads today's events from the calendars
// it already reads, finds the ones with a call link (Zoom, Google Meet,
// Microsoft Teams, Webex, Slack huddles, FaceTime, Whereby, Jitsi), shows a
// notice with Join a few minutes before each, and a strip while the call is
// live. Everything here is pure (no EventKit, no CoreAudio, no AppKit) and
// compiled into the tests: the preferences, the link parser, which meeting
// is current or next, when the notice is due and when a call is live.
// MeetingsService reads and listens; MeetingsStrip and the notice draw.

extension DefaultsKey {
    /// Off until turned on in Settings → Meetings.
    static let zenithMeetingsEnabled = "zenithMeetingsEnabled"
    /// Minutes before a start the notice shows (MeetingsSettings.leadChoices).
    static let zenithMeetingsLeadMinutes = "zenithMeetingsLeadMinutes"
    /// The providers turned off, comma separated raw values; "" for none.
    static let zenithMeetingsDisabledProviders = "zenithMeetingsDisabledProviders"
    /// Whether the closed island shows the strip while a call is live.
    static let zenithMeetingsShowsStrip = "zenithMeetingsShowsStrip"
    /// This Mac's record of the meetings already announced, so each gets one
    /// notice across relaunches. Machine state, unregistered: never backed up.
    static let zenithMeetingsNoticed = "zenithMeetingsNoticed"
}

// MARK: - Preferences

struct MeetingsSettings: Equatable {
    var enabled = false
    var leadMinutes = MeetingsSettings.defaultLeadMinutes
    var disabledProviders: Set<MeetingProvider> = []
    var showsStrip = true

    static let leadChoices = [1, 2, 5, 10]
    static let defaultLeadMinutes = 2

    var lead: TimeInterval { TimeInterval(leadMinutes * 60) }
    var enabledProviders: Set<MeetingProvider> { Set(MeetingProvider.allCases).subtracting(disabledProviders) }

    /// A stored lead outside the choices (an older build, a hand edit) reads as the default.
    static func leadMinutes(_ stored: Int?) -> Int {
        stored.flatMap { leadChoices.contains($0) ? $0 : nil } ?? defaultLeadMinutes
    }

    static func current(in defaults: UserDefaults = .standard) -> MeetingsSettings {
        MeetingsSettings(
            enabled: defaults.object(forKey: DefaultsKey.zenithMeetingsEnabled) as? Bool ?? false,
            leadMinutes: leadMinutes(defaults.object(forKey: DefaultsKey.zenithMeetingsLeadMinutes) as? Int),
            disabledProviders: disabled(defaults.string(forKey: DefaultsKey.zenithMeetingsDisabledProviders)),
            showsStrip: defaults.object(forKey: DefaultsKey.zenithMeetingsShowsStrip) as? Bool ?? true)
    }

    /// Unknown names (a provider a later build added, then removed) are left out.
    static func disabled(_ stored: String?) -> Set<MeetingProvider> {
        Set((stored ?? "").split(separator: ",").compactMap {
            MeetingProvider(rawValue: $0.trimmingCharacters(in: .whitespaces))
        })
    }

    static func setProvider(_ provider: MeetingProvider, on: Bool, in defaults: UserDefaults = .standard) {
        var disabled = disabled(defaults.string(forKey: DefaultsKey.zenithMeetingsDisabledProviders))
        if on { disabled.remove(provider) } else { disabled.insert(provider) }
        let stored = MeetingProvider.allCases.filter(disabled.contains).map(\.rawValue).joined(separator: ",")
        defaults.set(stored, forKey: DefaultsKey.zenithMeetingsDisabledProviders)
    }
}

/// The meetings already announced on this Mac, by occurrence, so a relaunch
/// inside a meeting's lead does not announce it twice. Kept a day.
enum MeetingsNoticeLog {
    static let keep: TimeInterval = 24 * 3600

    static func noticed(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(stored(in: defaults).keys)
    }

    static func record(_ meetings: [Meeting], now: Date, in defaults: UserDefaults = .standard) {
        guard !meetings.isEmpty else { return }
        var log = stored(in: defaults).filter { $0.value > now.addingTimeInterval(-keep).timeIntervalSinceReferenceDate }
        for meeting in meetings { log[meeting.id] = meeting.start.timeIntervalSinceReferenceDate }
        defaults.set(log, forKey: DefaultsKey.zenithMeetingsNoticed)
    }

    private static func stored(in defaults: UserDefaults) -> [String: Double] {
        (defaults.dictionary(forKey: DefaultsKey.zenithMeetingsNoticed) ?? [:]).compactMapValues { $0 as? Double }
    }
}

// MARK: - Providers

enum MeetingProvider: String, CaseIterable, Identifiable {
    case zoom, meet, teams, webex, slack, facetime, whereby, jitsi

    var id: String { rawValue }

    /// Brand names, the same in every language.
    var name: String {
        switch self {
        case .zoom: return "Zoom"
        case .meet: return "Google Meet"
        case .teams: return "Microsoft Teams"
        case .webex: return "Webex"
        case .slack: return "Slack huddles"
        case .facetime: return "FaceTime"
        case .whereby: return "Whereby"
        case .jitsi: return "Jitsi Meet"
        }
    }

    /// The short name the notice and the strip use.
    var shortName: String {
        switch self {
        case .meet: return "Meet"
        case .teams: return "Teams"
        case .slack: return "Slack"
        case .jitsi: return "Jitsi"
        default: return name
        }
    }

    /// A plain glyph; the colour tells the providers apart.
    var symbol: String {
        switch self {
        case .teams: return "person.2.fill"
        case .slack: return "headphones"
        case .webex: return "video.circle.fill"
        case .zoom, .meet, .facetime, .whereby, .jitsi: return "video.fill"
        }
    }

    /// Each brand's colour, lifted where it would vanish on the island's black.
    var tint: UInt32 {
        switch self {
        case .zoom: return 0x2D8CFF
        case .meet: return 0x34A853
        case .teams: return 0x7B83EB
        case .webex: return 0x07C1E4
        case .slack: return 0xE01E5A
        case .facetime: return 0x34C759
        case .whereby: return 0xA78BFA
        case .jitsi: return 0x60A5FA
        }
    }

    /// The desktop app that holds the call, when it has one: Join opens it,
    /// and a click on the strip brings it forward.
    var appBundleIDs: [String] {
        switch self {
        case .zoom: return ["us.zoom.xos"]
        case .teams: return ["com.microsoft.teams2", "com.microsoft.teams"]
        case .webex: return ["Cisco-Systems.Spark"]
        case .slack: return ["com.tinyspeck.slackmacgap"]
        case .facetime: return ["com.apple.FaceTime"]
        case .meet, .whereby, .jitsi: return []
        }
    }
}

struct MeetingLink: Equatable, Hashable {
    let provider: MeetingProvider
    let url: URL
}

/// How Join opens a link: with whatever handles it (the default browser, or
/// the app that registered its scheme), or with one app.
enum MeetingLaunch: Equatable {
    case open(URL)
    case openWith(URL, bundleID: String)
}

// MARK: - Link parsing

/// Finds a call link in an event's URL, location and notes, in that order.
/// Notes come as plain text or HTML (Exchange, Outlook, Google), with links
/// in `href`s, in angle brackets or bare, often behind a redirect: Google's
/// `google.com/url?q=`, Outlook's Safe Links, Proofpoint's URL Defense,
/// Slack's redirect. Help pages, meeting options and dial-in links are not
/// calls and are passed over.
enum MeetingLinkParser {
    static func link(url: URL?, location: String?, notes: String?,
                     providers: Set<MeetingProvider> = Set(MeetingProvider.allCases)) -> MeetingLink? {
        for text in [url?.absoluteString, location, notes] {
            guard let text, !text.isEmpty else { continue }
            if let link = links(in: text).first(where: { providers.contains($0.provider) }) { return link }
        }
        return nil
    }

    /// Every call link in `text`, in the order they appear, each once.
    static func links(in text: String) -> [MeetingLink] {
        var seen = Set<URL>()
        return candidates(in: text).compactMap { candidate in
            guard let link = classify(candidate), seen.insert(link.url).inserted else { return nil }
            return link
        }
    }

    // MARK: Candidates

    private static let schemed = try! NSRegularExpression(
        pattern: #"(?:\b(?:https?|zoommtg|zoomus|facetime)://|\bmsteams:/?)[^\s<>"'`{}|\\^\[\]]+"#,
        options: [.caseInsensitive])
    /// Hosts written without a scheme, as a location field often has them.
    private static let bare = try! NSRegularExpression(
        pattern: #"(?<![\w@./:-])(?:[a-z0-9-]+\.)*(?:zoom\.us|zoomgov\.com|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|webex\.com|whereby\.com|meet\.jit\.si|8x8\.vc|facetime\.apple\.com|app\.slack\.com)/[^\s<>"'`{}|\\^\[\]]+"#,
        options: [.caseInsensitive])

    /// The URLs in `text`, HTML entities decoded, trailing punctuation off, redirects unwrapped.
    static func candidates(in text: String) -> [URL] {
        let decoded = decodeEntities(text)
        let ns = decoded as NSString
        let range = NSRange(location: 0, length: ns.length)
        let withScheme = schemed.matches(in: decoded, range: range).map(\.range)
        let withoutScheme = bare.matches(in: decoded, range: range).map(\.range)
            .filter { found in !withScheme.contains { NSIntersectionRange($0, found).length > 0 } }
        let ordered = (withScheme.map { ($0, true) } + withoutScheme.map { ($0, false) })
            .sorted { $0.0.location < $1.0.location }
        return ordered.compactMap { range, hasScheme in
            let raw = trimmed(ns.substring(with: range))
            guard let url = URL(string: hasScheme ? raw : "https://" + raw) ?? percentEncoded(raw, hasScheme) else {
                return nil
            }
            return unwrapped(url)
        }
    }

    /// A link with a stray space or non-ASCII letter that URL(string:) refuses.
    private static func percentEncoded(_ raw: String, _ hasScheme: Bool) -> URL? {
        let text = hasScheme ? raw : "https://" + raw
        return text.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed.union(.urlQueryAllowed))
            .flatMap(URL.init(string:))
    }

    /// Sentence punctuation after a link, and a closing bracket it never opened.
    static func trimmed(_ raw: String) -> String {
        var text = raw
        while let last = text.last {
            if ".,;:!?*'\"»”’".contains(last) {
                text.removeLast()
            } else if last == ")" && text.filter({ $0 == "(" }).count < text.filter({ $0 == ")" }).count {
                text.removeLast()
            } else {
                break
            }
        }
        return text
    }

    private static let entities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "#39": "'",
    ]

    /// `&amp;` and its kin, decimal and hex references too; tags become spaces
    /// so a link ends where its tag does.
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") || text.contains("<") else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "&", let semicolon = text[index...].prefix(10).firstIndex(of: ";") {
                let name = String(text[text.index(after: index)..<semicolon])
                if let replacement = entity(name) {
                    result += replacement
                    index = text.index(after: semicolon)
                    continue
                }
            }
            if character == "<", let close = text[index...].firstIndex(of: ">"),
               text[text.index(after: index)...].first.map({ $0.isLetter || $0 == "/" || $0 == "!" }) == true {
                // An href's value stays, as a token of its own; the rest of the tag goes.
                let tag = String(text[index...close])
                // Outlook's `<https://…>` is a link in brackets, not a tag.
                if tag.range(of: #"^<[a-z][a-z0-9+.-]*:[^\s]*>$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    result += " " + tag.dropFirst().dropLast() + " "
                    index = text.index(after: close)
                    continue
                }
                result += " " + hrefs(in: tag).joined(separator: " ") + " "
                index = text.index(after: close)
                continue
            }
            result.append(character)
            index = text.index(after: index)
        }
        return result
    }

    private static func entity(_ name: String) -> String? {
        if let known = entities[name.lowercased()] { return known }
        guard name.hasPrefix("#") else { return nil }
        let digits = name.dropFirst()
        let value = digits.lowercased().hasPrefix("x") ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
        return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }

    private static let href = try! NSRegularExpression(pattern: #"href\s*=\s*["']([^"']+)["']"#, options: [.caseInsensitive])

    private static func hrefs(in tag: String) -> [String] {
        let ns = tag as NSString
        return href.matches(in: tag, range: NSRange(location: 0, length: ns.length)).map {
            decodeEntities(ns.substring(with: $0.range(at: 1)))
        }
    }

    // MARK: Redirects

    /// The link behind a redirect, followed a few times for one wrapped twice.
    static func unwrapped(_ url: URL) -> URL {
        var current = url
        for _ in 0..<4 {
            guard let inner = redirectTarget(current), inner != current else { break }
            current = inner
        }
        return current
    }

    private static func redirectTarget(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }
        let path = components.path.lowercased()
        func query(_ names: String...) -> URL? {
            for name in names {
                if let value = components.queryItems?.first(where: { $0.name.lowercased() == name })?.value,
                   let target = URL(string: value.trimmingCharacters(in: .whitespaces)), target.scheme != nil {
                    return target
                }
            }
            return nil
        }
        // Google: www.google.com/url?q=, google.co.uk/url?url=, and the Calendar's own.
        if (host == "google.com" || host.hasSuffix(".google.com") || host.hasPrefix("google.")
            || host.contains(".google.")), path == "/url" {
            return query("q", "url")
        }
        // Outlook Safe Links, worldwide and government.
        if host.hasSuffix("safelinks.protection.outlook.com") || host.hasSuffix("safelinks.protection.office365.us") {
            return query("url")
        }
        // Slack's link redirect.
        if host == "slack-redir.net" { return query("url") }
        // Proofpoint URL Defense v2: `-` for `%` and `_` for `/`.
        if host == "urldefense.proofpoint.com", path.hasPrefix("/v2/url"),
           let value = components.queryItems?.first(where: { $0.name == "u" })?.value {
            let decoded = value.replacingOccurrences(of: "-", with: "%").replacingOccurrences(of: "_", with: "/")
            return decoded.removingPercentEncoding.flatMap(URL.init(string:))
        }
        // Proofpoint URL Defense v3: the link between `__` and `__;`.
        if host == "urldefense.com", components.percentEncodedPath.hasPrefix("/v3/__") {
            let text = url.absoluteString
            guard let start = text.range(of: "/v3/__"),
                  let end = text.range(of: "__;", range: start.upperBound..<text.endIndex) else { return nil }
            return URL(string: String(text[start.upperBound..<end.lowerBound]))
        }
        return nil
    }

    // MARK: Classifying

    /// The provider whose call `url` joins, or nil for anything else.
    static func classify(_ url: URL) -> MeetingLink? {
        guard let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "zoommtg", "zoomus":
            return MeetingLink(provider: .zoom, url: url)
        case "msteams":
            return url.absoluteString.lowercased().contains("meetup-join") || url.absoluteString.contains("/meet/")
                ? MeetingLink(provider: .teams, url: url) : nil
        case "facetime":
            return MeetingLink(provider: .facetime, url: url)
        case "http", "https":
            break
        default:
            return nil
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased() else { return nil }
        let path = components.path
        let parts = path.split(separator: "/").map(String.init)
        let first = parts.first?.lowercased() ?? ""
        func within(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }

        if within("zoom.us") || within("zoomgov.com") || within("zoom.com") {
            // A meeting (/j/), webinar (/w/), personal room (/my/) or the web client's join.
            let joins = (["j", "w", "s", "my"].contains(first) && parts.count >= 2)
                || (first == "wc" && parts.contains { $0.lowercased() == "join" })
            return joins ? MeetingLink(provider: .zoom, url: url) : nil
        }
        if host == "meet.google.com" {
            let code = first.range(of: #"^[a-z]{3}-[a-z]{4}-[a-z]{3}$"#, options: .regularExpression) != nil
            let lookup = first == "lookup" && parts.count >= 2
            return code || lookup ? MeetingLink(provider: .meet, url: url) : nil
        }
        if within("teams.microsoft.com") || within("teams.live.com") || within("teams.microsoft.us")
            || within("teams.cloud.microsoft") {
            let text = url.absoluteString.lowercased()
            let joins = text.contains("meetup-join") || first == "meet" || (first == "l" && parts.count >= 2
                && parts[1].lowercased() == "meet")
            return joins && !path.lowercased().contains("meetingoptions") ? MeetingLink(provider: .teams, url: url) : nil
        }
        if within("webex.com") || within("webex.com.cn") {
            guard !host.hasPrefix("help.") && host != "www.webex.com" && host != "webex.com" else { return nil }
            let lower = path.lowercased()
            let joins = lower.contains("/meet/") || lower.contains("/join") || lower.contains("j.php")
                || lower.contains("/wbxmjs/joinservice") || lower.contains("/webappng/sites/")
            return joins ? MeetingLink(provider: .webex, url: url) : nil
        }
        if within("slack.com") {
            return first == "huddle" && parts.count >= 2 ? MeetingLink(provider: .slack, url: url) : nil
        }
        if host == "facetime.apple.com" {
            return first == "join" ? MeetingLink(provider: .facetime, url: url) : nil
        }
        if within("whereby.com") {
            let reserved: Set<String> = ["", "information", "user", "org", "login", "signup", "pricing", "blog",
                                         "about", "support", "product", "products", "use-cases", "embed", "legal",
                                         "security", "careers", "download", "apps", "developers", "terms", "privacy"]
            return !reserved.contains(first) && !host.hasPrefix("docs.") ? MeetingLink(provider: .whereby, url: url) : nil
        }
        if host == "meet.jit.si" || within("8x8.vc") || host.hasPrefix("jitsi.") || host.contains(".jitsi.")
            || host.hasPrefix("meet.jitsi") {
            let reserved: Set<String> = ["", "static", "libs", "images", "sounds", "lang", "config.js"]
            return !reserved.contains(first) ? MeetingLink(provider: .jitsi, url: url) : nil
        }
        return nil
    }

    // MARK: Joining

    /// How Join opens `link`: Zoom's and Teams' own schemes while their app
    /// is installed (straight into the call, no browser tab left behind),
    /// FaceTime in FaceTime, and the rest with the default browser, whose
    /// page hands the call to the provider's app if it has one.
    static func launch(_ link: MeetingLink, installed: (String) -> Bool) -> MeetingLaunch {
        let url = link.url
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return .open(url) }
        switch link.provider {
        case .zoom:
            if installed("us.zoom.xos"), let native = zoomScheme(url) { return .open(native) }
        case .teams:
            if link.provider.appBundleIDs.contains(where: installed), let native = teamsScheme(url) { return .open(native) }
        case .facetime:
            if installed("com.apple.FaceTime") { return .openWith(url, bundleID: "com.apple.FaceTime") }
        case .meet, .webex, .slack, .whereby, .jitsi:
            break
        }
        return .open(url)
    }

    /// `https://host.zoom.us/j/123?pwd=x` as `zoommtg://host.zoom.us/join?action=join&confno=123&pwd=x`.
    /// Personal rooms by name (/my/) have no number, and stay on the web.
    static func zoomScheme(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return nil }
        let parts = components.path.split(separator: "/").map(String.init)
        let number: String?
        if parts.count >= 2, ["j", "w", "s"].contains(parts[0].lowercased()) { number = parts[1] }
        else if parts.count >= 3, parts[0].lowercased() == "wc", parts[1].lowercased() == "join" { number = parts[2] }
        else if parts.count >= 3, parts[0].lowercased() == "wc", parts[2].lowercased() == "join" { number = parts[1] }
        else { number = nil }
        guard let number, number.allSatisfy(\.isNumber) else { return nil }
        var native = URLComponents()
        native.scheme = "zoommtg"
        native.host = host
        native.path = "/join"
        var items = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: number)]
        for name in ["pwd", "tk", "uname"] {
            if let value = components.queryItems?.first(where: { $0.name == name })?.value {
                items.append(URLQueryItem(name: name, value: value))
            }
        }
        native.queryItems = items
        return native.url
    }

    /// `https://teams.microsoft.com/l/meetup-join/…` as `msteams:/l/meetup-join/…`, the rest kept as written.
    static func teamsScheme(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.percentEncodedPath.lowercased().hasPrefix("/l/meetup-join/") else { return nil }
        var text = "msteams:" + components.percentEncodedPath
        if let query = components.percentEncodedQuery { text += "?" + query }
        if let fragment = components.percentEncodedFragment { text += "#" + fragment }
        return URL(string: text)
    }
}

// MARK: - Meetings

/// One event as the calendar gives it, before its link is looked for.
struct MeetingCandidate: Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    var allDay = false
    var url: URL? = nil
    var location: String? = nil
    var notes: String? = nil
}

/// An event with a call link: what the notice and the strip show.
struct Meeting: Equatable, Identifiable {
    /// The occurrence: the event and its start, so each repeat is its own.
    let id: String
    let title: String
    let start: Date
    let end: Date
    let link: MeetingLink

    var provider: MeetingProvider { link.provider }

    static func from(_ candidate: MeetingCandidate, providers: Set<MeetingProvider>) -> Meeting? {
        guard !candidate.allDay, candidate.end > candidate.start,
              let link = MeetingLinkParser.link(url: candidate.url, location: candidate.location, notes: candidate.notes,
                                                providers: providers) else { return nil }
        return Meeting(id: candidate.id, title: candidate.title, start: candidate.start, end: candidate.end, link: link)
    }
}

/// Which meeting is current or next, when its notice is due, and when the
/// service has to look again: one timer, never a poll.
enum MeetingSchedule {
    /// A meeting found already under way (the Mac was asleep, Zenith just
    /// started) still gets its notice this long after it began.
    static let joinGrace: TimeInterval = 5 * 60
    /// How far past midnight today's read reaches, for a meeting just after it.
    static let readOverlap: TimeInterval = 15 * 60

    /// Today's meetings from the calendar's events: timed, with a link from a
    /// provider that is on, not over, in start order.
    static func meetings(_ candidates: [MeetingCandidate], providers: Set<MeetingProvider>, now: Date) -> [Meeting] {
        candidates.compactMap { Meeting.from($0, providers: providers) }
            .filter { $0.end > now }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
    }

    /// The span the service reads: today, and a little past midnight.
    static func readInterval(now: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = (calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400))
            .addingTimeInterval(readOverlap)
        return DateInterval(start: start, end: end)
    }

    /// The meeting under way; of two overlapping, the one that began last.
    static func current(_ meetings: [Meeting], now: Date) -> Meeting? {
        meetings.filter { $0.start <= now && now < $0.end }.max { $0.start < $1.start }
    }

    /// The next one to start, today.
    static func next(_ meetings: [Meeting], now: Date, calendar: Calendar = .current) -> Meeting? {
        meetings.filter { $0.start > now && calendar.isDate($0.start, inSameDayAs: now) }.min { $0.start < $1.start }
    }

    /// The meeting the island attends to: one under way, else one inside its
    /// lead. Nil while none is near, and then nothing listens.
    static func focus(_ meetings: [Meeting], now: Date, lead: TimeInterval) -> Meeting? {
        if let current = current(meetings, now: now) {
            // A meeting about to start takes over from one about to end.
            if let soon = meetings.filter({ $0.start > now && $0.start.addingTimeInterval(-lead) <= now })
                .min(by: { $0.start < $1.start }), current.end <= soon.start.addingTimeInterval(lead) {
                return soon
            }
            return current
        }
        return meetings.filter { $0.start > now && $0.start.addingTimeInterval(-lead) <= now }.min { $0.start < $1.start }
    }

    /// Whether a meeting's notice is due at `now`: from its lead before the
    /// start until a little after it, and never once it ended.
    static func noticeIsDue(_ meeting: Meeting, now: Date, lead: TimeInterval) -> Bool {
        meeting.start.addingTimeInterval(-lead) <= now && now < meeting.start.addingTimeInterval(joinGrace)
            && now < meeting.end
    }

    /// The notices due at `now` that were not shown yet, in start order.
    static func noticesDue(_ meetings: [Meeting], now: Date, lead: TimeInterval, noticed: Set<String>) -> [Meeting] {
        meetings.filter { !noticed.contains($0.id) && noticeIsDue($0, now: now, lead: lead) }
    }

    /// The next moment anything changes: a lead begins, a meeting ends, or
    /// the day turns. The service's one timer fires then.
    static func nextWake(_ meetings: [Meeting], now: Date, lead: TimeInterval, calendar: Calendar = .current) -> Date {
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        let moments = meetings.flatMap { [$0.start.addingTimeInterval(-lead), $0.end] }.filter { $0 > now }
        return min(moments.min() ?? midnight, midnight)
    }
}

// MARK: - The call

/// A call the island shows: its meeting, since when, and whether the
/// microphone was seen in use (then letting it go ends the call).
struct MeetingCall: Equatable {
    var meeting: Meeting
    let since: Date
    var micSeen: Bool
}

/// Decides when a call is live. One starts while a meeting is near (under
/// way or inside its lead) and another app holds the microphone, or once the
/// person joined it from the notice. It ends when the microphone is let go
/// (after a short grace, as apps reopen it when switching devices) or when
/// the meeting ends, unless the microphone is still held: a meeting running
/// over keeps its strip, up to an hour.
struct MeetingCallTracker {
    static let releaseGrace: TimeInterval = 4
    static let overrun: TimeInterval = 60 * 60

    private(set) var call: MeetingCall?
    private(set) var releasedAt: Date?
    /// Meetings joined from the notice, and when.
    private(set) var joined: [String: Date] = [:]

    mutating func join(_ meeting: Meeting, at now: Date) {
        joined[meeting.id] = now
    }

    mutating func reset() {
        call = nil
        releasedAt = nil
        joined = [:]
    }

    @discardableResult
    mutating func update(meetings: [Meeting], now: Date, lead: TimeInterval, micInUse: Bool) -> MeetingCall? {
        joined = joined.filter { id, _ in meetings.contains { $0.id == id && $0.end > now } || call?.meeting.id == id }
        if var call {
            if let edited = meetings.first(where: { $0.id == call.meeting.id }) { call.meeting = edited }
            if micInUse {
                call.micSeen = true
                releasedAt = nil
            } else if call.micSeen {
                let released = releasedAt ?? now
                releasedAt = released
                if now.timeIntervalSince(released) >= Self.releaseGrace { return end(call) }
            }
            if now >= call.meeting.end, !(micInUse && now < call.meeting.end.addingTimeInterval(Self.overrun)) {
                return end(call)
            }
            self.call = call
            return call
        }
        guard let focus = MeetingSchedule.focus(meetings, now: now, lead: lead) else { return nil }
        if micInUse {
            call = MeetingCall(meeting: focus, since: now, micSeen: true)
        } else if let joinedAt = joined[focus.id] {
            call = MeetingCall(meeting: focus, since: joinedAt, micSeen: false)
        }
        return call
    }

    private mutating func end(_ ended: MeetingCall) -> MeetingCall? {
        joined[ended.meeting.id] = nil
        call = nil
        releasedAt = nil
        return nil
    }

    /// When the tracker must look again with nothing else happening: the end
    /// of a release's grace, the meeting's end, or the end of its overrun.
    func nextCheck(now: Date) -> Date? {
        guard let call else { return nil }
        if let releasedAt { return releasedAt.addingTimeInterval(Self.releaseGrace) }
        return now < call.meeting.end ? call.meeting.end : call.meeting.end.addingTimeInterval(Self.overrun)
    }
}

// MARK: - Formatting

enum MeetingsFormat {
    /// "10:00 – 10:30" in the locale's own clock.
    static func timeRange(_ meeting: Meeting, locale: Locale, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: meeting.start) + " – " + formatter.string(from: meeting.end)
    }

    /// Whole minutes until a start, rounded up so “in 2 min” never reads 1 at 1:30.
    static func minutes(until start: Date, now: Date) -> Int {
        Int((start.timeIntervalSince(now) / 60).rounded(.up))
    }

    /// "In 2 min", "Now", "Started 3 min ago".
    static func relative(_ start: Date, now: Date, text: ZenithMeetingsStrings) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds > 30 { return text.startsIn.replacingOccurrences(of: "{n}", with: "\(max(1, minutes(until: start, now: now)))") }
        if seconds > -60 { return text.startsNow }
        let ago = Int((-seconds / 60).rounded(.down))
        return text.startedAgo.replacingOccurrences(of: "{n}", with: "\(ago)")
    }

    /// The notice's line under the title: when, then the hours.
    static func noticeSubtitle(_ meeting: Meeting, now: Date, text: ZenithMeetingsStrings, locale: Locale,
                               calendar: Calendar = .current) -> String {
        relative(meeting.start, now: now, text: text) + " · " + timeRange(meeting, locale: locale, calendar: calendar)
    }

    /// The meeting's title, or the provider's name for an untitled one.
    static func title(_ meeting: Meeting, text: ZenithMeetingsStrings) -> String {
        let title = meeting.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? text.untitled.replacingOccurrences(of: "{provider}", with: meeting.provider.shortName) : title
    }

    /// "4:05", "1:02:03": how long the call has run.
    static func elapsed(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600, minutes = (total % 3600) / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }

    /// A title cut to `limit` characters with an ellipsis, for the strip's wing.
    static func shortened(_ title: String, limit: Int) -> String {
        guard title.count > limit, limit > 1 else { return title }
        return String(title.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
