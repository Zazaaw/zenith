// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: replying from the island. Only the pure part runs here:
/// which app gets a reply row, AppleScript string escaping (round-tripped
/// through a script that only returns its literal, so no app is addressed),
/// reading Messages' chat list and choosing a chat from a sender, the
/// WhatsApp link, and what each failure falls back to. No message is sent and
/// no app is driven.
enum ReplyTests {
    static func run(_ suite: TestSuite) {
        channelSelection(suite)
        escaping(suite)
        scripts(suite)
        senders(suite)
        chatParsing(suite)
        chatResolution(suite)
        whatsAppLink(suite)
        whatsAppPlan(suite)
        fallbacks(suite)
        hold(suite)
        drafts(suite)
        strings(suite)
    }

    // MARK: Channel selection

    private static func channelSelection(_ suite: TestSuite) {
        suite.expect(ZenithReplyApp(bundleIdentifier: "com.apple.MobileSMS") == .messages
                     && ZenithReplyApp(bundleIdentifier: "com.apple.mobilesms") == .messages,
                     "Messages notifications get the Messages channel, whatever the identifier's case")
        suite.expect(ZenithReplyApp(bundleIdentifier: "net.whatsapp.WhatsApp") == .whatsApp
                     && ZenithReplyApp(bundleIdentifier: "desktop.WhatsApp") == .whatsApp
                     && ZenithReplyApp(bundleIdentifier: " WhatsApp ") == .whatsApp,
                     "the Catalyst and the older desktop WhatsApp both get the WhatsApp channel")
        let others: [String?] = [nil, "", "com.apple.mail", "com.tinyspeck.slackmacgap", "net.whatsapp.WhatsAppBeta",
                                 "com.apple.MobileSMS.extension", "com.apple.iChat"]
        suite.expect(others.allSatisfy { ZenithReplyApp(bundleIdentifier: $0) == nil },
                     "every other app keeps no reply row")
        suite.expect(ZenithReplyApp.messages.placeholder == "iMessage…" && ZenithReplyApp.whatsApp.placeholder == "WhatsApp…",
                     "the field's placeholder names the service, with an ellipsis character")
        let blue = ZenithReplyApp.messages.tint, green = ZenithReplyApp.whatsApp.tint
        suite.expect(blue.blue > blue.red && blue.blue > blue.green && green.green > green.red && green.green > green.blue,
                     "iMessage sends in blue and WhatsApp in green")
    }

    // MARK: AppleScript escaping

    /// Runs `return <literal>`: AppleScript itself reads the literal back.
    private static func roundTrip(_ text: String) -> String? {
        guard let script = NSAppleScript(source: "return " + ZenithAppleScript.literal(text)) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return error == nil ? result.stringValue : nil
    }

    private static func escaping(_ suite: TestSuite) {
        suite.expect(ZenithAppleScript.literal(#"say "hi""#) == #""say \"hi\"""#, "quotes are escaped")
        suite.expect(ZenithAppleScript.literal(#"C:\path\"#) == #""C:\\path\\""#, "backslashes are escaped")
        suite.expect(ZenithAppleScript.literal("a\nb\r\nc\rd") == #""a\nb\nc\nd""#,
                     "every kind of line break becomes one \\n escape")
        suite.expect(ZenithAppleScript.literal("a\tb") == #""a\tb""#, "a tab becomes \\t")
        suite.expect(ZenithAppleScript.literal("a\u{0}b\u{7}c\u{1B}d\u{7F}") == "\"abcd\"",
                     "other control characters are dropped")
        suite.expect(ZenithAppleScript.literal("Sure! 👍🏽 Link coming 🇮🇩") == "\"Sure! 👍🏽 Link coming 🇮🇩\"",
                     "emoji, skin tones and flags stay as they are")
        suite.expect(ZenithAppleScript.literal("") == "\"\"", "an empty text is an empty literal")
        // A literal that ends a statement early and carries a command must stay text.
        let injection = "\" & (do shell script \"echo pwned\") & \""
        suite.expect(roundTrip(injection) == injection, "text that tries to close the string stays text")
        let samples = ["Sure! Link coming.", #"She said "ok" \o/"#, "line one\nline two", "tab\there",
                       "Sampai jumpa 😄🎉", "引号“测试”", "trailing backslash \\", "¿Qué tal? — bien"]
        for sample in samples {
            suite.expect(roundTrip(sample) == sample, "AppleScript reads back the escaped text: \(sample.debugDescription)")
        }
        suite.expect(roundTrip("a\r\nb") == "a\nb", "a Windows line break reads back as one line break")
    }

    private static func scripts(_ suite: TestSuite) {
        let chat = ZenithAppleScript.messagesSendScript(text: "Hi \"Sam\"", to: .chat("iMessage;-;+15551234567"))
        suite.expect(chat.contains(#"send "Hi \"Sam\"" to chat id "iMessage;-;+15551234567""#)
                     && chat.contains(#"tell application "Messages""#),
                     "a chat reply is sent to the chat by its id, with the text escaped")
        let handle = ZenithAppleScript.messagesSendScript(text: "Hi", to: .handle("sam@example.com"))
        suite.expect(handle.contains(#"send "Hi" to participant "sam@example.com" of targetAccount"#)
                     && handle.contains("service type = iMessage"),
                     "a reply to a bare handle goes over iMessage to that participant")
        let tricky = ZenithAppleScript.messagesSendScript(text: "x", to: .chat("evil\" & quit & \""))
        suite.expect(tricky.contains(#"chat id "evil\" & quit & \"""#), "a chat id is escaped like any text")
        let listing = ZenithAppleScript.messagesChatsScript(limit: 50)
        suite.expect(listing.contains("if chatCount > 50 then set chatCount to 50")
                     && listing.contains("participants of aChat") && !listing.contains("text of"),
                     "the chat list is bounded and reads labels only, no message text")
        suite.expect(ZenithAppleScript.messagesChatsScript(limit: 0).contains("> 1 then"), "the limit never drops below one chat")
    }

    // MARK: Senders

    private static func senders(_ suite: TestSuite) {
        typealias Sender = ZenithReplySender
        suite.expect(Sender.phoneNumber("+62 812-3456-7890") == "+6281234567890"
                     && Sender.phoneNumber("(555) 123.4567") == "5551234567"
                     && Sender.phoneNumber("\u{202A}+1 555 123 4567\u{202C}") == "+15551234567",
                     "a phone number is read with its separators and direction marks removed")
        suite.expect(["Sam", "12345", "+1 555 CALL NOW", "1+5551234567", "Sam 5551234567", "", "1234567890123456"]
                        .allSatisfy { Sender.phoneNumber($0) == nil },
                     "names, short codes, letters and a + in the middle are not phone numbers")
        suite.expect(Sender.isEmail("Sam@Example.com") && !Sender.isEmail("sam@") && !Sender.isEmail("@x.com")
                     && !Sender.isEmail("sam smith@x.com") && !Sender.isEmail("sam@localhost"),
                     "an email address needs a name, an @ and a dotted domain")
        suite.expect(Sender.handle("Sam@Example.com") == "sam@example.com" && Sender.handle("Sam") == nil,
                     "a handle is a phone number or an email address")
        suite.expect(Sender.samePhone("+6281234567890", "081234567890") && Sender.samePhone("+1 (555) 123-4567", "5551234567")
                     && !Sender.samePhone("5551234567", "5551234568") && !Sender.samePhone("123456", "9123456"),
                     "phone numbers match across country codes and trunk zeros, not on a short tail")
        suite.expect(Sender.normalizedName("  ~ Sámuel  O’Neil ") == Sender.normalizedName("samuel o’neil")
                     && Sender.normalizedName("\u{200E}Sam\u{200F}") == "sam",
                     "names compare without case, accents, WhatsApp’s tilde, spacing or direction marks")
    }

    // MARK: Chats

    private static func record(_ id: String, _ name: String, _ participants: [(String, String, String)]) -> String {
        ([id, name] + participants.map { [$0.0, $0.1, $0.2].joined(separator: ZenithAppleScript.valueSeparator) })
            .joined(separator: ZenithAppleScript.fieldSeparator) + ZenithAppleScript.chatSeparator
    }

    private static func chatParsing(_ suite: TestSuite) {
        let output = record("iMessage;-;+15551234567", "missing value", [("+15551234567", "Sam", "Sam Smith")])
            + record("iMessage;+;chat123", "Family", [("+15550000001", "Mum", ""), ("dad@example.com", "", "Dad Smith")])
            + record("", "No id", []) + "\n"
        let chats = ZenithMessagesChats.parse(output)
        suite.expect(chats.count == 2, "chats without an id are skipped")
        suite.expect(chats.first == ZenithMessagesChat(id: "iMessage;-;+15551234567", name: "",
                                                       participants: [.init(handle: "+15551234567", name: "Sam",
                                                                            fullName: "Sam Smith")]),
                     "a chat reads its id, a missing name as empty, and its participant")
        suite.expect(chats.last?.isGroup == true && chats.last?.participants.count == 2 && chats.first?.isGroup == false,
                     "a group is told from a one-to-one chat")
        suite.expect(ZenithMessagesChats.parse("").isEmpty && ZenithMessagesChats.parse("garbage").count == 1,
                     "an empty list reads as no chats")
        suite.expect(ZenithMessagesChat(id: "SMS;-;+1", name: "", participants: []).serviceRank
                     > ZenithMessagesChat(id: "any;-;+1", name: "", participants: []).serviceRank
                     && ZenithMessagesChat(id: "any;-;+1", name: "", participants: []).serviceRank
                     > ZenithMessagesChat(id: "iMessage;-;+1", name: "", participants: []).serviceRank,
                     "iMessage ranks before any, and any before SMS")
    }

    private static func chatResolution(_ suite: TestSuite) {
        func chat(_ id: String, _ name: String = "", people: [(String, String, String)]) -> ZenithMessagesChat {
            ZenithMessagesChat(id: id, name: name, participants: people.map {
                ZenithMessagesParticipant(handle: $0.0, name: $0.1, fullName: $0.2)
            })
        }
        let chats = [
            chat("SMS;-;+15551234567", people: [("+15551234567", "Sam", "Sam Smith")]),
            chat("iMessage;-;+15551234567", people: [("+15551234567", "Sam", "Sam Smith")]),
            chat("iMessage;-;alex@example.com", people: [("alex@example.com", "Alex", "Alex Rivera")]),
            chat("iMessage;-;+15559990000", people: [("+15559990000", "Alex", "Alex Kim")]),
            chat("iMessage;+;chat42", "Weekend Trip", people: [("+15551234567", "Sam", ""), ("alex@example.com", "Alex", "")]),
            chat("iMessage;+;chat43", "Book Club", people: [("+15550000001", "Rita", "")]),
            chat("iMessage;+;chat44", "Book Club", people: [("+15550000002", "Nia", "")]),
            chat("any;-;+6281234567890", people: [("+6281234567890", "", "José Ñúñez")]),
        ]
        let resolve = { (sender: String) -> ZenithMessagesResolution in ZenithMessagesChats.resolve(sender: sender, in: chats) }
        suite.expect(resolve("Sam") == .recipient(.chat("iMessage;-;+15551234567")),
                     "a name picks that person’s iMessage chat over their SMS one")
        suite.expect(resolve("sam smith") == .recipient(.chat("iMessage;-;+15551234567")),
                     "a full name matches without regard to case")
        suite.expect(resolve("(555) 123-4567") == .recipient(.chat("iMessage;-;+15551234567")),
                     "a formatted phone number finds the person’s own chat, not the group they are in")
        suite.expect(resolve("ALEX@example.com") == .recipient(.chat("iMessage;-;alex@example.com")),
                     "an email address finds its chat whatever its case")
        suite.expect(resolve("+44 20 7946 0018") == .recipient(.handle("+442079460018")),
                     "a handle without a chat is sent to directly")
        suite.expect(resolve("weekend trip") == .recipient(.chat("iMessage;+;chat42")), "a group is found by its name")
        suite.expect(resolve("Book Club") == .ambiguous, "two groups with one name are never guessed at")
        suite.expect(resolve("Alex") == .ambiguous, "two people with one name are never guessed at")
        suite.expect(resolve("Alex Kim") == .recipient(.chat("iMessage;-;+15559990000")),
                     "the full name tells the two apart")
        suite.expect(resolve("Jose Nunez") == .recipient(.chat("any;-;+6281234567890")),
                     "accents do not stop a match")
        suite.expect(resolve("Samantha") == .notFound && resolve("") == .notFound && resolve("  \u{200E} ") == .notFound,
                     "an unknown or empty sender finds nothing")
        suite.expect(ZenithMessagesChats.resolve(sender: "Sam", in: []) == .notFound, "no chats, no recipient")
    }

    // MARK: WhatsApp

    private static func whatsAppLink(_ suite: TestSuite) {
        let text = "Sure! Link coming & see you at 5+1=6 #now?\nOK 👍🏽"
        let url = ZenithWhatsAppLink.sendURL(phone: "+62 812-3456-7890", text: text)
        suite.expect(url?.scheme == "whatsapp" && url?.host == "send", "the link opens WhatsApp’s send action")
        let items = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        suite.expect(items.first(where: { $0.name == "phone" })?.value == "6281234567890",
                     "the number goes in as digits only")
        suite.expect(items.first(where: { $0.name == "text" })?.value == text && items.count == 2,
                     "the text survives encoding exactly, with &, =, +, #, ?, line breaks and emoji")
        let raw = url?.absoluteString ?? ""
        suite.expect(!raw.contains(" ") && !raw.contains("\n") && raw.contains("%26") && raw.contains("%2B")
                     && raw.contains("%23") && raw.contains("%3F") && raw.contains("%0A") && raw.contains("%F0%9F%91%8D"),
                     "reserved characters, spaces, line breaks and emoji are percent-encoded")
        suite.expect(ZenithWhatsAppLink.encode("a-b_c.d~e") == "a-b_c.d~e", "unreserved characters stay")
        suite.expect(ZenithWhatsAppLink.sendURL(phone: "12345", text: "x") == nil
                     && ZenithWhatsAppLink.sendURL(phone: "Sam", text: "x") == nil,
                     "no link without a real phone number")
        suite.expect(ZenithWhatsAppLink.sendURL(phone: "5551234567", text: "")?.absoluteString == "whatsapp://send?phone=5551234567",
                     "an empty text leaves the parameter out")
    }

    private static func whatsAppPlan(_ suite: TestSuite) {
        typealias Plan = ZenithWhatsAppPlan
        let link = ZenithWhatsAppLink.sendURL(phone: "+15551234567", text: "Hi")!
        suite.expect(Plan.decide(sender: "+1 555 123 4567", text: "Hi", automatic: true, accessibility: true)
                     == .automate(.link(link)), "a phone number is opened by its link, then sent")
        suite.expect(Plan.decide(sender: "~ Sam", text: "Hi", automatic: true, accessibility: true)
                     == .automate(.search("~ Sam")), "a name goes through WhatsApp’s search")
        suite.expect(Plan.decide(sender: "+1 555 123 4567", text: "Hi", automatic: false, accessibility: true)
                     == .openPrefilled(link), "with the setting off, a phone number’s chat opens with the reply typed")
        suite.expect(Plan.decide(sender: "Sam", text: "Hi", automatic: false, accessibility: true) == .openAndCopy,
                     "with the setting off, a name opens WhatsApp and copies the reply")
        suite.expect(Plan.decide(sender: "Sam", text: "Hi", automatic: true, accessibility: false) == .needsAccessibility,
                     "without Accessibility the automatic path asks for it")
        suite.expect(Plan.decide(sender: "+1 555 123 4567", text: "Hi", automatic: false, accessibility: false)
                     == .openPrefilled(link), "the manual path needs no Accessibility")
        suite.expect(Plan.decide(sender: " ~ ", text: "Hi", automatic: true, accessibility: true) == .openAndCopy,
                     "a sender with no name left is never searched for")
    }

    private static func fallbacks(_ suite: TestSuite) {
        typealias Fallback = ZenithReplyFallback
        let link = ZenithWhatsAppPlan.Route.link(URL(string: "whatsapp://send?phone=1")!)
        let search = ZenithWhatsAppPlan.Route.search("Sam")
        suite.expect(Fallback.whatsApp(after: .sending, route: search) == .opened(prefilled: true, copied: false)
                     && Fallback.whatsApp(after: .sending, route: link) == .opened(prefilled: true, copied: false),
                     "a reply Return did not send stays typed in WhatsApp’s composer")
        suite.expect(Fallback.whatsApp(after: .openingChat, route: link) == .opened(prefilled: true, copied: false)
                     && Fallback.whatsApp(after: .launching, route: link) == .opened(prefilled: true, copied: false),
                     "before the chat opens, a phone number’s link still opens it with the reply")
        suite.expect(Fallback.whatsApp(after: .openingChat, route: search) == .opened(prefilled: false, copied: true)
                     && Fallback.whatsApp(after: .launching, route: search) == .opened(prefilled: false, copied: true)
                     && Fallback.whatsApp(after: .placingText, route: search) == .opened(prefilled: false, copied: true)
                     && Fallback.whatsApp(after: .placingText, route: link) == .opened(prefilled: false, copied: true),
                     "otherwise the reply waits on the clipboard")
        suite.expect(Fallback.messages(errorNumber: nil) == .sent, "a script without an error sent the reply")
        suite.expect(Fallback.messages(errorNumber: -1743) == .needsPermission(.automation)
                     && Fallback.messages(errorNumber: -1744) == .needsPermission(.automation),
                     "denied or undecided Automation asks for access")
        suite.expect([-1712, -1728, -600, 0, -128].allSatisfy { Fallback.messages(errorNumber: $0) == .opened(prefilled: false, copied: true) },
                     "any other failure opens the conversation with the reply copied")
        suite.expect(Fallback.messages(resolution: .recipient(.chat("x"))) == .chat("x")
                     && Fallback.messages(resolution: .ambiguous) == nil && Fallback.messages(resolution: .notFound) == nil,
                     "only a resolved chat or handle is sent to")
    }

    // MARK: Island

    private static func hold(_ suite: TestSuite) {
        let id = UUID(), other = UUID()
        let saved = (ZenithReplyHold.notificationID, ZenithReplyHold.previewExtraHeight)
        defer { ZenithReplyHold.notificationID = saved.0; ZenithReplyHold.previewExtraHeight = saved.1 }
        ZenithReplyHold.notificationID = nil
        ZenithReplyHold.previewExtraHeight = 38
        suite.expect(!ZenithReplyHold.isComposing && ZenithReplyHold.extraHeight(for: id) == 0 && !ZenithReplyHold.holds(nil),
                     "without an open row nothing is held or grown")
        ZenithReplyHold.notificationID = id
        suite.expect(ZenithReplyHold.isComposing && ZenithReplyHold.holds(id) && !ZenithReplyHold.holds(other)
                     && ZenithReplyHold.extraHeight(for: id) == 38 && ZenithReplyHold.extraHeight(for: other) == 0
                     && ZenithReplyHold.extraHeight(for: nil) == 0,
                     "only the banner whose row is open is held and grown")
    }

    private static func drafts(_ suite: TestSuite) {
        suite.expect(ZenithReplyDraft.sendable("  Sure!\nLink coming.  \n") == "Sure!\nLink coming.",
                     "a reply is trimmed at its ends and keeps its own line breaks")
        suite.expect(ZenithReplyDraft.sendable(" \n\t ") == nil && ZenithReplyDraft.sendable("") == nil,
                     "a blank reply is not sent")
        suite.expect(ZenithReplyDraft.sendable(String(repeating: "a", count: 20_000)) == nil, "an enormous paste is not sent")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.reply(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 16 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words every reply string, with curly apostrophes and no em dash")
            let formats = [text.you, text.openedPrefilled, text.openedCopied, text.handOffPrefilled, text.handOffCopied]
            suite.expect(formats.allSatisfy { $0.components(separatedBy: "%@").count == 2 },
                         "\(language.rawValue) names the reply or the app once in each sentence that takes one")
        }
    }
}
