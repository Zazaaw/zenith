// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Meetings. Call links in the shapes calendars really hold
/// them (bare, in HTML notes, behind Google's, Outlook's, Proofpoint's and
/// Slack's redirects), and the links that only look like calls; the right
/// app for Join; today's meetings, the current and the next; when the notice
/// is due and when the one timer fires; when a call is live and when it ends;
/// the preferences and the words.
enum MeetingsTests {
    static func run(_ suite: TestSuite) {
        suite.run("meetings links") { links(suite) }
        suite.run("meetings html and redirects") { wrapped(suite) }
        suite.run("meetings not calls") { notCalls(suite) }
        suite.run("meetings event fields") { fields(suite) }
        suite.run("meetings join") { joining(suite) }
        suite.run("meetings schedule") { schedule(suite) }
        suite.run("meetings notice timing") { noticeTiming(suite) }
        suite.run("meetings call") { calls(suite) }
        suite.run("meetings settings") { settings(suite) }
        suite.run("meetings format") { format(suite) }
    }

    private static func provider(_ text: String) -> MeetingProvider? {
        MeetingLinkParser.links(in: text).first?.provider
    }

    private static func url(_ text: String) -> String? {
        MeetingLinkParser.links(in: text).first?.url.absoluteString
    }

    // MARK: Links

    private static func links(_ suite: TestSuite) {
        let cases: [(String, MeetingProvider)] = [
            ("https://zoom.us/j/1234567890?pwd=abcDEF123", .zoom),
            ("https://us02web.zoom.us/j/85012345678?pwd=Q2xYa1Rx", .zoom),
            ("https://acme.zoom.us/j/98765432100", .zoom),
            ("https://zoom.us/w/91234567890?tk=abc", .zoom),
            ("https://zoom.us/my/jane.doe", .zoom),
            ("https://app.zoom.us/wc/join/1234567890", .zoom),
            ("https://zoom.us/wc/1234567890/join?pwd=x", .zoom),
            ("https://agency.zoomgov.com/j/1601234567", .zoom),
            ("zoommtg://zoom.us/join?action=join&confno=123456789", .zoom),
            ("https://meet.google.com/abc-defg-hij", .meet),
            ("https://meet.google.com/abc-defg-hij?authuser=1&hs=122", .meet),
            ("https://meet.google.com/lookup/abcdef12345", .meet),
            ("https://teams.microsoft.com/l/meetup-join/19%3ameeting_NjQ1ZDk2%40thread.v2/0?context=%7b%22Tid%22%3a%22abc%22%7d",
             .teams),
            ("https://teams.live.com/meet/9876543210123?p=AbCdEf", .teams),
            ("https://teams.microsoft.com/meet/123456789?p=xyz", .teams),
            ("https://gov.teams.microsoft.us/l/meetup-join/19%3ameeting_x%40thread.v2/0", .teams),
            ("https://teams.microsoft.com/dl/launcher/launcher.html?url=%2F_%23%2Fl%2Fmeetup-join%2F19%3Ameeting_x", .teams),
            ("msteams:/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=%7b%7d", .teams),
            ("https://acme.webex.com/meet/jane.doe", .webex),
            ("https://acme.webex.com/acme/j.php?MTID=m0123456789abcdef", .webex),
            ("https://acme.webex.com/wbxmjs/joinservice/sites/acme/meeting/download/abc", .webex),
            ("https://app.slack.com/huddle/T012AB3C4/C0123ABCDEF", .slack),
            ("https://facetime.apple.com/join#v=1&p=AbCdEfGh&k=XyZ123", .facetime),
            ("https://whereby.com/team-standup", .whereby),
            ("https://acme.whereby.com/design-review", .whereby),
            ("https://meet.jit.si/WeeklySyncAcme", .jitsi),
            ("https://8x8.vc/vpaas-magic-cookie-abc/Standup", .jitsi),
            ("https://jitsi.example.org/OpsRoom", .jitsi),
        ]
        for (text, expected) in cases {
            suite.expect(provider(text) == expected, "\(text) is a \(expected.name) link: \(String(describing: provider(text)))")
        }
        // Case and a scheme left out, as locations hold them.
        suite.expect(provider("HTTPS://ZOOM.US/j/123456789") == .zoom, "the scheme and host in capitals still read")
        suite.expect(url("meet.google.com/abc-defg-hij") == "https://meet.google.com/abc-defg-hij",
                     "a Meet link without a scheme gets https")
        suite.expect(provider("Room 4B / zoom.us/j/555123456") == .zoom, "a bare Zoom link in a location")
        // Sentence punctuation is not part of the link.
        suite.expect(url("Join here: https://meet.google.com/abc-defg-hij.") == "https://meet.google.com/abc-defg-hij",
                     "a trailing full stop is dropped")
        suite.expect(url("(https://zoom.us/j/123456789)") == "https://zoom.us/j/123456789",
                     "an unopened closing bracket is dropped")
        suite.expect(url("“https://whereby.com/standup”,") == "https://whereby.com/standup", "curly quotes and a comma are dropped")
        suite.expect(url("<https://zoom.us/j/123456789?pwd=abc>") == "https://zoom.us/j/123456789?pwd=abc",
                     "Outlook's angle brackets are not part of the link")
        // Several links: in order, each once.
        let both = MeetingLinkParser.links(in: "Zoom https://zoom.us/j/111111111 or Meet https://meet.google.com/abc-defg-hij, "
                                               + "again https://zoom.us/j/111111111")
        suite.expect(both.map(\.provider) == [.zoom, .meet], "two links in order, the repeat once: \(both)")
    }

    // MARK: HTML and redirects

    private static func wrapped(_ suite: TestSuite) {
        let html = #"<p>Join Zoom Meeting<br><a href="https://us06web.zoom.us/j/81234567890?pwd=aBc&amp;uname=x" target="_blank">https://us06web.zoom.us/j/81234567890?pwd=aBc&amp;uname=x</a></p>"#
        suite.expect(url(html) == "https://us06web.zoom.us/j/81234567890?pwd=aBc&uname=x",
                     "a link in an href, &amp; decoded: \(url(html) ?? "nil")")
        let teamsHTML = """
            <div>________________________________________________________________________________</div>
            <div><span style="font-size:24px">Microsoft Teams meeting</span></div>
            <a href="https://teams.microsoft.com/l/meetup-join/19%3ameeting_ZjE%40thread.v2/0?context=%7b%22Tid%22%3a%22t%22%7d" \
            title="Meeting join link">Join the meeting now</a>
            <a href="https://aka.ms/JoinTeamsMeeting?omkt=en-US">Need help?</a> | \
            <a href="https://teams.microsoft.com/meetingOptions/?organizerId=1&amp;tenantId=2">Meeting options</a>
            """
        suite.expect(provider(teamsHTML) == .teams, "a Teams invitation in HTML")
        suite.expect(MeetingLinkParser.links(in: teamsHTML).count == 1,
                     "help and meeting options are not calls: \(MeetingLinkParser.links(in: teamsHTML))")
        suite.expect(url("Join&#58; https:&#x2F;&#x2F;meet.google.com&#47;abc-defg-hij") == "https://meet.google.com/abc-defg-hij",
                     "numeric character references decode")
        suite.expect(provider("<a href='https://whereby.com/standup'>Room</a>") == .whereby, "single-quoted href")

        // Google's redirect, as Calendar writes descriptions.
        let google = "https://www.google.com/url?q=https://zoom.us/j/123456789?pwd%3Dabc&sa=D&source=calendar&ust=1700000000000000&usg=AOvVaw0"
        suite.expect(provider(google) == .zoom, "Google's redirect unwraps to Zoom")
        suite.expect(url(google) == "https://zoom.us/j/123456789?pwd=abc", "its target, decoded: \(url(google) ?? "nil")")
        let googleEncoded = "https://www.google.com/url?q=https%3A%2F%2Fmeet.google.com%2Fabc-defg-hij&sa=D"
        suite.expect(url(googleEncoded) == "https://meet.google.com/abc-defg-hij", "an encoded Google redirect")
        let googleHTML = #"<a href="https://www.google.com/url?q=https%3A%2F%2Fteams.microsoft.com%2Fl%2Fmeetup-join%2F19%253ameeting_x%2540thread.v2%2F0&amp;sa=D&amp;source=calendar">Join</a>"#
        suite.expect(provider(googleHTML) == .teams, "a Google redirect to Teams inside an href")

        // Outlook Safe Links.
        let safe = "https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fteams.microsoft.com%2Fl%2Fmeetup-join%2F19%253ameeting_abc%2540thread.v2%2F0%3Fcontext%3D%257b%257d&data=05%7C01%7C&sdata=abc%3D&reserved=0"
        suite.expect(provider(safe) == .teams, "Safe Links unwrap to Teams")
        suite.expect(url(safe)?.hasPrefix("https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0") == true,
                     "the target keeps its own encoding: \(url(safe) ?? "nil")")
        let safeZoom = "https://eur03.safelinks.protection.outlook.com/?url=https%3A%2F%2Fzoom.us%2Fj%2F987654321&data=x"
        suite.expect(provider(safeZoom) == .zoom, "Safe Links to Zoom")
        // Twice wrapped: Safe Links around Google.
        let twice = "https://nam02.safelinks.protection.outlook.com/?url=" + (google.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")
            + "&data=1"
        suite.expect(provider(twice) == .zoom, "Safe Links around Google's redirect: \(url(twice) ?? "nil")")
        // Proofpoint.
        let v2 = "https://urldefense.proofpoint.com/v2/url?u=https-3A__zoom.us_j_123456789-3Fpwd-3Dabc&d=DwMFaQ&c=x&r=y"
        suite.expect(url(v2) == "https://zoom.us/j/123456789?pwd=abc", "Proofpoint v2 decodes: \(url(v2) ?? "nil")")
        let v3 = "https://urldefense.com/v3/__https://meet.google.com/abc-defg-hij__;!!ABC123!xyz$"
        suite.expect(url(v3) == "https://meet.google.com/abc-defg-hij", "Proofpoint v3 decodes: \(url(v3) ?? "nil")")
        // Slack's redirect.
        let slack = "https://slack-redir.net/link?url=https%3A%2F%2Fwhereby.com%2Fdesign"
        suite.expect(provider(slack) == .whereby, "Slack's redirect unwraps")
        // A redirect to something else is no call.
        suite.expect(provider("https://www.google.com/url?q=https://example.com/agenda&sa=D") == nil,
                     "a redirect to an agenda is no call")
    }

    // MARK: Not calls

    private static func notCalls(_ suite: TestSuite) {
        let cases = [
            "https://zoom.us/download",
            "https://zoom.us/meeting/register/tJ0kcuGhqDMiGtE",
            "https://zoom.us/u/abc123",
            "https://support.zoom.us/hc/en-us",
            "https://zoom.us/j/",
            "https://meet.google.com/",
            "https://tel.meet/abc-defg-hij?pin=1234",
            "https://support.google.com/a/users/answer/9282720",
            "https://meet.google.com/abcd-efg-hij",
            "https://aka.ms/JoinTeamsMeeting",
            "https://teams.microsoft.com/meetingOptions/?organizerId=1",
            "https://www.microsoft.com/microsoft-teams/join-a-meeting",
            "https://help.webex.com/en-us/article/join",
            "https://www.webex.com/downloads.html",
            "https://acme.slack.com/archives/C0123",
            "https://whereby.com/information/pricing",
            "https://whereby.com/",
            "https://meet.jit.si/",
            "https://facetime.apple.com/",
            "https://example.com/zoom.us/j/123",
            "tel:+15551234567,,123456789#",
            "mailto:jane@zoom.us",
            "Conference room 3",
        ]
        for text in cases {
            suite.expect(MeetingLinkParser.links(in: text).isEmpty,
                         "\(text) is not a call: \(MeetingLinkParser.links(in: text))")
        }
    }

    // MARK: Event fields

    private static func fields(_ suite: TestSuite) {
        let zoom = URL(string: "https://zoom.us/j/111111111")
        let link = MeetingLinkParser.link(url: zoom, location: "https://meet.google.com/abc-defg-hij", notes: nil)
        suite.expect(link?.provider == .zoom, "the event's URL comes first")
        let fromLocation = MeetingLinkParser.link(url: URL(string: "https://example.com/agenda"),
                                                  location: "Microsoft Teams Meeting",
                                                  notes: "Join: https://meet.google.com/abc-defg-hij")
        suite.expect(fromLocation?.provider == .meet, "a URL that is no call falls through to the notes")
        let off = MeetingLinkParser.link(url: zoom, location: nil, notes: "or https://whereby.com/standup",
                                         providers: [.whereby])
        suite.expect(off?.provider == .whereby, "a provider turned off is passed over for the next")
        suite.expect(MeetingLinkParser.link(url: zoom, location: nil, notes: nil, providers: []) == nil,
                     "with every provider off, nothing is a call")
        suite.expect(MeetingLinkParser.link(url: nil, location: "", notes: "Lunch") == nil, "no link, no meeting")

        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let allDay = MeetingCandidate(id: "a", title: "Offsite", start: start, end: start.addingTimeInterval(86_400),
                                      allDay: true, url: zoom)
        suite.expect(Meeting.from(allDay, providers: Set(MeetingProvider.allCases)) == nil, "an all-day event is no call")
        let timed = MeetingCandidate(id: "b", title: "Standup", start: start, end: start.addingTimeInterval(900), url: zoom)
        suite.expect(Meeting.from(timed, providers: Set(MeetingProvider.allCases))?.provider == .zoom, "a timed one is")
    }

    // MARK: Join

    private static func joining(_ suite: TestSuite) {
        func launch(_ text: String, installed: Set<String>) -> MeetingLaunch? {
            MeetingLinkParser.links(in: text).first.map { MeetingLinkParser.launch($0, installed: installed.contains) }
        }
        let zoom = "https://acme.zoom.us/j/81234567890?pwd=aBc123&uname=Jane"
        suite.expect(launch(zoom, installed: ["us.zoom.xos"])
                        == .open(URL(string: "zoommtg://acme.zoom.us/join?action=join&confno=81234567890&pwd=aBc123&uname=Jane")!),
                     "with Zoom installed, its own scheme: \(String(describing: launch(zoom, installed: ["us.zoom.xos"])))")
        suite.expect(launch(zoom, installed: []) == .open(URL(string: zoom)!), "without it, the browser")
        suite.expect(launch("https://zoom.us/my/jane.doe", installed: ["us.zoom.xos"])
                        == .open(URL(string: "https://zoom.us/my/jane.doe")!), "a personal room by name stays on the web")
        suite.expect(launch("https://zoom.us/wc/join/123456789", installed: ["us.zoom.xos"])
                        == .open(URL(string: "zoommtg://zoom.us/join?action=join&confno=123456789")!), "the web client's number")
        let teams = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=%7b%7d"
        suite.expect(launch(teams, installed: ["com.microsoft.teams2"])
                        == .open(URL(string: "msteams:/l/meetup-join/19%3ameeting_x%40thread.v2/0?context=%7b%7d")!),
                     "with Teams installed, msteams: keeps the encoding")
        suite.expect(launch(teams, installed: []) == .open(URL(string: teams)!), "without it, the browser")
        suite.expect(launch("https://teams.live.com/meet/9876543210?p=x", installed: ["com.microsoft.teams2"])
                        == .open(URL(string: "https://teams.live.com/meet/9876543210?p=x")!), "a Teams (free) link on the web")
        let facetime = "https://facetime.apple.com/join#v=1&p=abc&k=def"
        suite.expect(launch(facetime, installed: ["com.apple.FaceTime"])
                        == .openWith(URL(string: facetime)!, bundleID: "com.apple.FaceTime"), "FaceTime in FaceTime")
        suite.expect(launch("https://meet.google.com/abc-defg-hij", installed: ["us.zoom.xos", "com.microsoft.teams2"])
                        == .open(URL(string: "https://meet.google.com/abc-defg-hij")!), "Meet in the browser")
        suite.expect(launch("zoommtg://zoom.us/join?confno=1", installed: [])
                        == .open(URL(string: "zoommtg://zoom.us/join?confno=1")!), "an app scheme opens as it is")
    }

    // MARK: Schedule

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    /// Today at `hour:minute` in the test calendar.
    private static func at(_ hour: Int, _ minute: Int = 0, day: Int = 26) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private static func meeting(_ id: String, _ start: Date, minutes: Int = 30,
                                link: String = "https://zoom.us/j/123456789", title: String? = nil) -> Meeting {
        Meeting(id: id, title: title ?? id, start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                link: MeetingLinkParser.links(in: link).first!)
    }

    private static func schedule(_ suite: TestSuite) {
        let zoom = URL(string: "https://zoom.us/j/123456789")
        let candidates = [
            MeetingCandidate(id: "late", title: "Late", start: at(16), end: at(17), url: zoom),
            MeetingCandidate(id: "lunch", title: "Lunch", start: at(12), end: at(13)),
            MeetingCandidate(id: "early", title: "Early", start: at(8), end: at(9), url: zoom),
            MeetingCandidate(id: "now", title: "Now", start: at(10), end: at(11),
                             notes: "Join https://meet.google.com/abc-defg-hij"),
        ]
        let found = MeetingSchedule.meetings(candidates, providers: Set(MeetingProvider.allCases), now: at(10, 15))
        suite.expect(found.map(\.id) == ["now", "late"], "linked, not over, in start order: \(found.map(\.id))")
        suite.expect(MeetingSchedule.meetings(candidates, providers: [.zoom], now: at(10, 15)).map(\.id) == ["late"],
                     "Meet turned off leaves its meeting out")
        suite.expect(MeetingSchedule.current(found, now: at(10, 15))?.id == "now", "the one under way is current")
        suite.expect(MeetingSchedule.next(found, now: at(10, 15), calendar: calendar)?.id == "late", "the next one today")
        suite.expect(MeetingSchedule.next(found, now: at(16, 30), calendar: calendar) == nil, "none left today")

        let overlapping = [meeting("a", at(10), minutes: 60), meeting("b", at(10, 30), minutes: 60)]
        suite.expect(MeetingSchedule.current(overlapping, now: at(10, 45))?.id == "b", "of two overlapping, the later start")
        let tomorrow = [meeting("t", at(9, day: 27))]
        suite.expect(MeetingSchedule.next(tomorrow, now: at(10), calendar: calendar) == nil, "tomorrow is not today’s next")

        let interval = MeetingSchedule.readInterval(now: at(10, 15), calendar: calendar)
        suite.expect(interval.start == at(0) && interval.end == at(0, 15, day: 27), "today’s read, a little past midnight")

        // Focus: what the listeners follow.
        let day = [meeting("standup", at(10), minutes: 15), meeting("review", at(10, 30))]
        let lead: TimeInterval = 120
        suite.expect(MeetingSchedule.focus(day, now: at(9, 57), lead: lead) == nil, "before the lead nothing is near")
        suite.expect(MeetingSchedule.focus(day, now: at(9, 58), lead: lead)?.id == "standup", "the lead begins")
        suite.expect(MeetingSchedule.focus(day, now: at(10, 10), lead: lead)?.id == "standup", "under way")
        suite.expect(MeetingSchedule.focus(day, now: at(10, 20), lead: lead) == nil, "between meetings nothing listens")
        let backToBack = [meeting("one", at(10)), meeting("two", at(10, 30))]
        suite.expect(MeetingSchedule.focus(backToBack, now: at(10, 29), lead: lead)?.id == "two",
                     "back to back, the next one takes over inside its lead")

        // The one timer.
        suite.expect(MeetingSchedule.nextWake(day, now: at(9), lead: lead, calendar: calendar) == at(9, 58),
                     "the timer waits for the first lead")
        suite.expect(MeetingSchedule.nextWake(day, now: at(10, 5), lead: lead, calendar: calendar) == at(10, 15),
                     "then the meeting’s end")
        suite.expect(MeetingSchedule.nextWake(day, now: at(10, 15), lead: lead, calendar: calendar) == at(10, 28),
                     "then the next lead")
        suite.expect(MeetingSchedule.nextWake(day, now: at(11), lead: lead, calendar: calendar) == at(0, day: 27),
                     "with nothing left, midnight")
        suite.expect(MeetingSchedule.nextWake([], now: at(11), lead: lead, calendar: calendar) == at(0, day: 27),
                     "no meetings: only midnight")
    }

    // MARK: Notice timing

    private static func noticeTiming(_ suite: TestSuite) {
        let standup = meeting("standup", at(10), minutes: 15)
        for (minutes, lead) in [(1, 60.0), (2, 120.0), (5, 300.0), (10, 600.0)] {
            let opens = at(10).addingTimeInterval(-lead)
            suite.expect(!MeetingSchedule.noticeIsDue(standup, now: opens.addingTimeInterval(-1), lead: lead),
                         "\(minutes) min: not a second early")
            suite.expect(MeetingSchedule.noticeIsDue(standup, now: opens, lead: lead), "\(minutes) min: due at its lead")
        }
        let lead: TimeInterval = 120
        suite.expect(MeetingSchedule.noticeIsDue(standup, now: at(10, 4), lead: lead), "still due just after the start")
        suite.expect(!MeetingSchedule.noticeIsDue(standup, now: at(10, 5), lead: lead), "not once the grace has passed")
        let short = meeting("short", at(10), minutes: 3)
        suite.expect(!MeetingSchedule.noticeIsDue(short, now: at(10, 3), lead: lead), "never once it ended")

        let day = [standup, meeting("review", at(10, 1))]
        suite.expect(MeetingSchedule.noticesDue(day, now: at(9, 59), lead: lead, noticed: []).map(\.id) == ["standup", "review"],
                     "two due at once, in start order")
        suite.expect(MeetingSchedule.noticesDue(day, now: at(9, 59), lead: lead, noticed: ["standup"]).map(\.id) == ["review"],
                     "one notice per meeting")

        // The log that keeps it to one across relaunches.
        let domain = "com.vorssaint.tests.meetings-log"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        MeetingsNoticeLog.record([standup], now: at(9, 58), in: defaults)
        suite.expect(MeetingsNoticeLog.noticed(in: defaults) == ["standup"], "a notice shown is remembered")
        let tomorrow = meeting("tomorrow", at(10, day: 28))
        MeetingsNoticeLog.record([tomorrow], now: at(9, 58, day: 28), in: defaults)
        suite.expect(MeetingsNoticeLog.noticed(in: defaults) == ["tomorrow"], "a day later the old one is forgotten")
    }

    // MARK: The call

    private static func calls(_ suite: TestSuite) {
        let lead: TimeInterval = 120
        let standup = meeting("standup", at(10), minutes: 30)
        let day = [standup]
        var tracker = MeetingCallTracker()

        suite.expect(tracker.update(meetings: day, now: at(9), lead: lead, micInUse: true) == nil,
                     "the mic in use with no meeting near is no call")
        let started = tracker.update(meetings: day, now: at(9, 59), lead: lead, micInUse: true)
        suite.expect(started?.meeting.id == "standup" && started?.since == at(9, 59), "the mic in use inside the lead starts it")
        suite.expect(tracker.nextCheck(now: at(10)) == at(10, 30), "the tracker looks again at the end")
        suite.expect(tracker.update(meetings: day, now: at(10, 5), lead: lead, micInUse: false) != nil,
                     "a moment without the mic keeps it")
        suite.expect(tracker.nextCheck(now: at(10, 5)) == at(10, 5).addingTimeInterval(MeetingCallTracker.releaseGrace),
                     "and looks again when the grace ends")
        suite.expect(tracker.update(meetings: day, now: at(10, 5).addingTimeInterval(2), lead: lead, micInUse: true) != nil,
                     "the mic back within the grace: the same call")
        suite.expect(tracker.call?.since == at(9, 59), "its clock keeps running")
        _ = tracker.update(meetings: day, now: at(10, 10), lead: lead, micInUse: false)
        suite.expect(tracker.update(meetings: day, now: at(10, 10).addingTimeInterval(4), lead: lead, micInUse: false) == nil,
                     "the mic let go past the grace ends it")
        suite.expect(tracker.update(meetings: day, now: at(10, 11), lead: lead, micInUse: false) == nil,
                     "and it does not come back by itself")
        suite.expect(tracker.update(meetings: day, now: at(10, 12), lead: lead, micInUse: true)?.since == at(10, 12),
                     "joining again starts a new one")

        // Running over.
        suite.expect(tracker.update(meetings: day, now: at(10, 40), lead: lead, micInUse: true) != nil,
                     "past the end with the mic still held, it runs over")
        suite.expect(tracker.update(meetings: day, now: at(11, 31), lead: lead, micInUse: true) == nil,
                     "an hour past the end it stops")

        // Joined from the notice, before the app opens the mic.
        var joined = MeetingCallTracker()
        joined.join(standup, at: at(9, 59))
        let early = joined.update(meetings: day, now: at(9, 59), lead: lead, micInUse: false)
        suite.expect(early?.since == at(9, 59) && early?.micSeen == false, "Join shows the call before the mic")
        suite.expect(joined.update(meetings: day, now: at(10, 20), lead: lead, micInUse: false) != nil,
                     "without the mic it holds while the meeting runs")
        suite.expect(joined.update(meetings: day, now: at(10, 30), lead: lead, micInUse: false) == nil,
                     "and ends with the meeting")

        var muted = MeetingCallTracker()
        muted.join(standup, at: at(10))
        _ = muted.update(meetings: day, now: at(10), lead: lead, micInUse: false)
        _ = muted.update(meetings: day, now: at(10, 1), lead: lead, micInUse: true)
        _ = muted.update(meetings: day, now: at(10, 15), lead: lead, micInUse: false)
        suite.expect(muted.update(meetings: day, now: at(10, 16), lead: lead, micInUse: false) == nil,
                     "after the mic was seen, letting it go ends a joined call too")

        // The title follows an edit to the event.
        var edited = MeetingCallTracker()
        _ = edited.update(meetings: day, now: at(10), lead: lead, micInUse: true)
        let renamed = Meeting(id: "standup", title: "Daily", start: standup.start, end: standup.end, link: standup.link)
        suite.expect(edited.update(meetings: [renamed], now: at(10, 1), lead: lead, micInUse: true)?.meeting.title == "Daily",
                     "a renamed event renames the strip")
        edited.reset()
        suite.expect(edited.call == nil && edited.joined.isEmpty, "reset forgets everything")
    }

    // MARK: Settings

    private static func settings(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.meetings-settings"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let fresh = MeetingsSettings.current(in: defaults)
        suite.expect(!fresh.enabled && fresh.leadMinutes == 2 && fresh.showsStrip && fresh.disabledProviders.isEmpty,
                     "off by default, 2 minutes, the strip on, every provider")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.zenithMeetingsEnabled] as? Bool == false,
                     "registered off, so it is backed up")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.zenithMeetingsLeadMinutes] as? Int == 2, "the lead registered")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.zenithMeetingsNoticed] == nil,
                     "the notices shown are this Mac’s, never backed up")
        suite.expect(MeetingsSettings.leadChoices == [1, 2, 5, 10], "the lead's choices")
        defaults.set(7, forKey: DefaultsKey.zenithMeetingsLeadMinutes)
        suite.expect(MeetingsSettings.current(in: defaults).leadMinutes == 2, "a lead outside the choices reads as the default")
        defaults.set(5, forKey: DefaultsKey.zenithMeetingsLeadMinutes)
        suite.expect(MeetingsSettings.current(in: defaults).lead == 300, "5 minutes")
        MeetingsSettings.setProvider(.slack, on: false, in: defaults)
        MeetingsSettings.setProvider(.zoom, on: false, in: defaults)
        suite.expect(defaults.string(forKey: DefaultsKey.zenithMeetingsDisabledProviders) == "zoom,slack",
                     "turned off providers stored in a stable order")
        MeetingsSettings.setProvider(.zoom, on: true, in: defaults)
        let current = MeetingsSettings.current(in: defaults)
        suite.expect(current.disabledProviders == [.slack] && !current.enabledProviders.contains(.slack)
                        && current.enabledProviders.contains(.zoom), "turned back on")
        suite.expect(MeetingsSettings.disabled("zoom, gotomeeting,,teams") == [.zoom, .teams], "unknown names are skipped")
    }

    // MARK: Format and words

    private static func format(_ suite: TestSuite) {
        let text = ZenithStrings.meetings(.enUS)
        let standup = meeting("standup", at(10), minutes: 30, title: "Design review")
        suite.expect(MeetingsFormat.relative(at(10), now: at(9, 58), text: text) == "In 2 min", "two minutes ahead")
        suite.expect(MeetingsFormat.relative(at(10), now: at(9, 58).addingTimeInterval(30), text: text) == "In 2 min",
                     "1:30 ahead still reads 2, rounded up")
        suite.expect(MeetingsFormat.relative(at(10), now: at(10), text: text) == text.startsNow, "at the start")
        suite.expect(MeetingsFormat.relative(at(10), now: at(10, 3), text: text) == "Started 3 min ago", "after it")
        var locale = Locale(identifier: "en_GB")
        suite.expect(MeetingsFormat.timeRange(standup, locale: locale, calendar: calendar) == "10:00 – 10:30",
                     "the hours in the locale's clock: \(MeetingsFormat.timeRange(standup, locale: locale, calendar: calendar))")
        locale = Locale(identifier: "en_US")
        suite.expect(MeetingsFormat.timeRange(standup, locale: locale, calendar: calendar).contains("AM"),
                     "a 12-hour locale's clock")
        suite.expect(MeetingsFormat.noticeSubtitle(standup, now: at(9, 58), text: text, locale: Locale(identifier: "en_GB"),
                                                   calendar: calendar) == "In 2 min · 10:00 – 10:30", "the notice's line")
        let untitled = meeting("x", at(10), link: "https://meet.google.com/abc-defg-hij", title: "  ")
        suite.expect(MeetingsFormat.title(untitled, text: text) == "Meet call", "an untitled meeting named by its provider")
        suite.expect(MeetingsFormat.elapsed(65) == "1:05" && MeetingsFormat.elapsed(3723) == "1:02:03"
                        && MeetingsFormat.elapsed(-4) == "0:00", "the call's clock")
        suite.expect(MeetingsFormat.shortened("Quarterly planning with design", limit: 16) == "Quarterly plann…",
                     "a long title shortened: \(MeetingsFormat.shortened("Quarterly planning with design", limit: 16))")
        suite.expect(MeetingsFormat.shortened("Standup", limit: 16) == "Standup", "a short one kept")

        suite.expect(text.all.allSatisfy { !$0.isEmpty && !$0.contains("'") }, "every string written, apostrophes curly")
        suite.expect(Set(MeetingProvider.allCases.map(\.name)).count == MeetingProvider.allCases.count, "providers named apart")
        suite.expect(MeetingsSearch.aliases.contains("rapat") && MeetingsSearch.aliases.contains("zoom"),
                     "search knows the Indonesian word and the providers")
    }
}
