// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: replying to a message straight from the island. This file is
// the pure part (which app a notification can be answered in, the AppleScript
// Messages runs, how a sender becomes a chat, the WhatsApp link, and what to
// do when a step fails); the test executable compiles it. Nothing here ever
// logs or stores the text of a message or a reply.

/// An app whose notifications get a reply row. Every other app keeps none.
enum ZenithReplyApp: String, CaseIterable, Equatable, Sendable {
    case messages
    case whatsApp

    /// Messages (iMessage, SMS and RCS all post from the same app).
    static let messagesBundleIdentifiers = ["com.apple.MobileSMS"]
    /// The current Catalyst app, then the older desktop app's identifiers.
    static let whatsAppBundleIdentifiers = ["net.whatsapp.WhatsApp", "desktop.WhatsApp", "WhatsApp"]

    init?(bundleIdentifier: String?) {
        guard let identifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty else { return nil }
        func matches(_ list: [String]) -> Bool {
            list.contains { $0.caseInsensitiveCompare(identifier) == .orderedSame }
        }
        if matches(Self.messagesBundleIdentifiers) { self = .messages }
        else if matches(Self.whatsAppBundleIdentifiers) { self = .whatsApp }
        else { return nil }
    }

    /// The composer's placeholder: the service's own name, as the app shows it.
    var placeholder: String {
        switch self {
        case .messages: return "iMessage…"
        case .whatsApp: return "WhatsApp…"
        }
    }

    /// The name shown when the notification carries no app label.
    var displayName: String {
        switch self {
        case .messages: return "Messages"
        case .whatsApp: return "WhatsApp"
        }
    }

    /// The send button and the "You:" line wear the service's colour:
    /// iMessage blue and WhatsApp green, in sRGB.
    var tint: (red: Double, green: Double, blue: Double) {
        switch self {
        case .messages: return (10 / 255, 132 / 255, 255 / 255)
        case .whatsApp: return (37 / 255, 211 / 255, 102 / 255)
        }
    }
}

/// What a reply goes to: the notification's app and who sent it. Only the
/// sender's label is kept, never the message.
struct ZenithReplyTarget: Equatable, Sendable {
    let notificationID: UUID
    let app: ZenithReplyApp
    let bundleIdentifier: String
    /// The app as the notification names it, for messages about it.
    let appName: String
    /// The notification's title: a contact's name, a group's name or a handle.
    let sender: String
}

enum ZenithReplyPermission: Equatable, Sendable {
    case automation
    case accessibility
}

enum ZenithReplyOutcome: Equatable, Sendable {
    case sent
    /// Sending automatically did not finish. The app was opened instead,
    /// with the reply already in its composer, or on the clipboard.
    case opened(prefilled: Bool, copied: Bool)
    case needsPermission(ZenithReplyPermission)
    case failed
}

/// The island keeps a banner whose reply row is open, through the pointer
/// leaving and another app activating, and grows its preview to fit the row.
/// The composer sets these on the main thread; the island reads them.
enum ZenithReplyHold {
    /// The notification whose reply row is open, on whichever surface.
    static var notificationID: UUID?
    /// Extra height for a held preview, while its row is open.
    static var previewExtraHeight: CGFloat = 0

    static var isComposing: Bool { notificationID != nil }

    static func holds(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return id == notificationID
    }

    static func extraHeight(for id: UUID?) -> CGFloat {
        holds(id) ? previewExtraHeight : 0
    }

    /// The reply row as the preview measures it: the row and the gap above.
    static let rowHeight: CGFloat = 30
    static let rowSpacing: CGFloat = 8
}

// MARK: - Sender labels

enum ZenithReplySender {
    /// Bidirectional and invisible formatting marks that apps wrap names and
    /// numbers in. They are not part of what a person typed.
    private static let formatting: Set<UInt32> = [
        0x061C, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069, 0xFEFF,
    ]

    static func stripped(_ value: String) -> String {
        let scalars = value.unicodeScalars.filter { !formatting.contains($0.value) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A name compared the way a person reads it: case, accents, width and
    /// spacing do not tell two names apart. WhatsApp marks a name the sender
    /// chose for themselves with a leading tilde.
    static func normalizedName(_ value: String) -> String {
        var name = stripped(value)
        while name.hasPrefix("~") { name = String(name.dropFirst()).trimmingCharacters(in: .whitespaces) }
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                  locale: Locale(identifier: "en_US_POSIX"))
        return folded.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// The digits of a phone number, with a leading + kept, when the whole
    /// label is one: digits with the usual separators, 6 to 15 digits long.
    static func phoneNumber(_ value: String) -> String? {
        let label = stripped(value)
        guard !label.isEmpty, label.utf8.count <= 40 else { return nil }
        var digits = ""
        var sawPlus = false
        for (index, character) in label.enumerated() {
            if character.isASCII, character.isNumber { digits.append(character); continue }
            if character == "+", index == 0 { sawPlus = true; continue }
            if [" ", "-", "(", ")", ".", "\u{00A0}"].contains(character) { continue }
            return nil
        }
        guard (6...15).contains(digits.count) else { return nil }
        return (sawPlus ? "+" : "") + digits
    }

    static func isEmail(_ value: String) -> Bool {
        let label = stripped(value)
        guard label.utf8.count <= 254, !label.contains(where: { $0.isWhitespace }) else { return false }
        let parts = label.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    /// A phone number or an email address: an address Messages can send to
    /// without knowing the person.
    static func handle(_ value: String) -> String? {
        if let phone = phoneNumber(value) { return phone }
        let label = stripped(value)
        return isEmail(label) ? label.lowercased() : nil
    }

    /// Two numbers name the same phone when their digits agree, allowing for
    /// a country code or a national trunk 0 written on only one of them.
    static func samePhone(_ lhs: String, _ rhs: String) -> Bool {
        func digits(_ value: String) -> String {
            let all = value.filter { $0.isASCII && $0.isNumber }
            return String(all.drop(while: { $0 == "0" }))
        }
        let a = digits(lhs), b = digits(rhs)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        let (short, long) = a.count < b.count ? (a, b) : (b, a)
        return short.count >= 7 && long.hasSuffix(short)
    }

    static func sameHandle(_ lhs: String, _ rhs: String) -> Bool {
        if phoneNumber(lhs) != nil, phoneNumber(rhs) != nil { return samePhone(lhs, rhs) }
        return stripped(lhs).caseInsensitiveCompare(stripped(rhs)) == .orderedSame
    }
}

// MARK: - AppleScript

enum ZenithAppleScript {
    /// The text as an AppleScript string literal. Backslashes and quotes are
    /// escaped, every line break becomes `\n`, tabs `\t`, and other control
    /// characters are dropped; everything else, emoji included, stays as it is.
    static func literal(_ text: String) -> String {
        var result = "\""
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        for scalar in normalized.unicodeScalars {
            switch scalar {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n", "\r", "\u{2028}", "\u{2029}", "\u{0085}": result += "\\n"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F { continue }
                result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    /// Separators the chat list is written with: no name or handle holds them.
    static let chatSeparator = "\u{1E}"
    static let fieldSeparator = "\u{1F}"
    static let valueSeparator = "\u{1D}"

    /// Lists Messages' chats: each chat's id and name, then each participant's
    /// handle, name and full name. Only labels, never a message.
    static func messagesChatsScript(limit: Int = 200) -> String {
        """
        with timeout of 10 seconds
        tell application "Messages"
            set chatSep to character id 30
            set fieldSep to character id 31
            set valueSep to character id 29
            set output to ""
            set chatCount to count of chats
            if chatCount > \(max(1, limit)) then set chatCount to \(max(1, limit))
            repeat with i from 1 to chatCount
                set aChat to chat i
                set chatID to ""
                set chatName to ""
                try
                    set chatID to id of aChat as text
                end try
                try
                    set itemValue to name of aChat
                    if itemValue is not missing value then set chatName to itemValue as text
                end try
                set chatLine to chatID & fieldSep & chatName
                try
                    repeat with aParticipant in participants of aChat
                        set handleText to ""
                        set nameText to ""
                        set fullText to ""
                        try
                            set handleText to handle of aParticipant as text
                        end try
                        try
                            set itemValue to name of aParticipant
                            if itemValue is not missing value then set nameText to itemValue as text
                        end try
                        try
                            set itemValue to full name of aParticipant
                            if itemValue is not missing value then set fullText to itemValue as text
                        end try
                        set chatLine to chatLine & fieldSep & handleText & valueSep & nameText & valueSep & fullText
                    end repeat
                end try
                set output to output & chatLine & chatSep
            end repeat
            return output
        end tell
        end timeout
        """
    }

    /// Sends the text to a chat by its id, or to a handle over iMessage.
    static func messagesSendScript(text: String, to recipient: ZenithMessagesRecipient) -> String {
        switch recipient {
        case .chat(let id):
            return """
            with timeout of 15 seconds
            tell application "Messages"
                send \(literal(text)) to chat id \(literal(id))
            end tell
            end timeout
            """
        case .handle(let handle):
            return """
            with timeout of 15 seconds
            tell application "Messages"
                set targetAccount to 1st account whose service type = iMessage
                send \(literal(text)) to participant \(literal(handle)) of targetAccount
            end tell
            end timeout
            """
        }
    }

    /// Apple Event errors a script can end with.
    static let notPermitted = -1743
    static let wouldRequireConsent = -1744
    static let timedOut = -1712
    static let userCanceled = -128
}

// MARK: - Messages chats

struct ZenithMessagesParticipant: Equatable, Sendable {
    let handle: String
    let name: String
    let fullName: String
}

struct ZenithMessagesChat: Equatable, Sendable {
    let id: String
    let name: String
    let participants: [ZenithMessagesParticipant]

    /// A group has its own id form (`;+;`) and more than one other person.
    var isGroup: Bool { id.contains(";+;") || participants.count != 1 }

    /// iMessage first, then whatever Messages picks, RCS, then SMS.
    var serviceRank: Int {
        let service = id.split(separator: ";", maxSplits: 1).first.map(String.init)?.lowercased() ?? ""
        switch service {
        case "imessage": return 0
        case "any": return 1
        case "rcs": return 2
        case "sms": return 3
        default: return 4
        }
    }
}

enum ZenithMessagesRecipient: Equatable, Sendable {
    case chat(String)
    case handle(String)
}

enum ZenithMessagesResolution: Equatable, Sendable {
    case recipient(ZenithMessagesRecipient)
    /// More than one person or group fits the label.
    case ambiguous
    case notFound
}

enum ZenithMessagesChats {
    static func parse(_ output: String) -> [ZenithMessagesChat] {
        func clean(_ value: Substring) -> String {
            let text = String(value).trimmingCharacters(in: .whitespacesAndNewlines)
            return text == "missing value" ? "" : text
        }
        return output.split(separator: Character(ZenithAppleScript.chatSeparator)).compactMap { record in
            let fields = record.split(separator: Character(ZenithAppleScript.fieldSeparator),
                                      omittingEmptySubsequences: false)
            guard let first = fields.first else { return nil }
            let id = clean(first)
            guard !id.isEmpty else { return nil }
            let name = fields.count > 1 ? clean(fields[1]) : ""
            let participants = fields.dropFirst(2).compactMap { field -> ZenithMessagesParticipant? in
                let values = field.split(separator: Character(ZenithAppleScript.valueSeparator),
                                         omittingEmptySubsequences: false).map(clean)
                guard let handle = values.first else { return nil }
                let participant = ZenithMessagesParticipant(handle: handle, name: values.count > 1 ? values[1] : "",
                                                            fullName: values.count > 2 ? values[2] : "")
                return participant.handle.isEmpty && participant.name.isEmpty && participant.fullName.isEmpty
                    ? nil : participant
            }
            return ZenithMessagesChat(id: id, name: name, participants: participants)
        }
    }

    /// Finds the chat a notification came from by its title. A handle goes to
    /// that person's own chat, or straight to the handle when there is none.
    /// A name must fit one group, or one person; a name two people share is
    /// ambiguous, since sending to the wrong one is worse than not sending.
    static func resolve(sender: String, in chats: [ZenithMessagesChat]) -> ZenithMessagesResolution {
        let label = ZenithReplySender.normalizedName(sender)
        guard !label.isEmpty else { return .notFound }
        func best(_ matches: [ZenithMessagesChat]) -> ZenithMessagesChat? {
            matches.enumerated().min { lhs, rhs in
                (lhs.element.serviceRank, lhs.offset) < (rhs.element.serviceRank, rhs.offset)
            }?.element
        }
        if let handle = ZenithReplySender.handle(sender) {
            let own = chats.filter { chat in
                !chat.isGroup && chat.participants.contains { ZenithReplySender.sameHandle($0.handle, handle) }
            }
            if let chat = best(own) { return .recipient(.chat(chat.id)) }
            return .recipient(.handle(handle))
        }
        let groups = chats.filter { $0.isGroup && ZenithReplySender.normalizedName($0.name) == label }
        if groups.count == 1 { return .recipient(.chat(groups[0].id)) }
        if groups.count > 1 { return .ambiguous }
        let people = chats.filter { chat in
            !chat.isGroup && chat.participants.contains { participant in
                [participant.name, participant.fullName].contains { ZenithReplySender.normalizedName($0) == label }
            }
        }
        // One person can have chats on several services, and the same handle
        // in each; two different handles may be two different people.
        var handles: [String] = []
        for chat in people {
            for participant in chat.participants where !handles.contains(where: {
                ZenithReplySender.sameHandle($0, participant.handle)
            }) { handles.append(participant.handle) }
        }
        if handles.count > 1 { return .ambiguous }
        if let chat = best(people) { return .recipient(.chat(chat.id)) }
        return .notFound
    }
}

// MARK: - WhatsApp

enum ZenithWhatsAppLink {
    /// Characters a query value may keep as they are; everything else,
    /// including `&`, `=`, `+`, `#`, line breaks and emoji, is escaped.
    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// Opens WhatsApp on a phone number's chat with the text in its composer.
    /// The number goes in as digits only, as WhatsApp expects.
    static func sendURL(phone: String, text: String) -> URL? {
        let digits = phone.filter { $0.isASCII && $0.isNumber }
        guard (6...15).contains(digits.count) else { return nil }
        var link = "whatsapp://send?phone=" + digits
        if !text.isEmpty { link += "&text=" + encode(text) }
        return URL(string: link)
    }
}

/// How a WhatsApp reply is delivered, decided before anything is touched.
enum ZenithWhatsAppPlan: Equatable, Sendable {
    enum Route: Equatable, Sendable {
        /// The sender is a phone number: the link opens its chat with the text.
        case link(URL)
        /// A name: WhatsApp's search finds the chat.
        case search(String)
    }

    case automate(Route)
    /// Open WhatsApp on the chat with the reply in its composer, to send by hand.
    case openPrefilled(URL)
    /// Open WhatsApp and put the reply on the clipboard.
    case openAndCopy
    case needsAccessibility

    static func decide(sender: String, text: String, automatic: Bool, accessibility: Bool) -> ZenithWhatsAppPlan {
        let link = ZenithReplySender.phoneNumber(sender).flatMap { ZenithWhatsAppLink.sendURL(phone: $0, text: text) }
        guard automatic else { return link.map(ZenithWhatsAppPlan.openPrefilled) ?? .openAndCopy }
        guard accessibility else { return .needsAccessibility }
        if let link { return .automate(.link(link)) }
        let name = ZenithReplySender.stripped(sender)
        guard !ZenithReplySender.normalizedName(name).isEmpty else { return .openAndCopy }
        return .automate(.search(name))
    }
}

/// The step an automated WhatsApp reply reached before it stopped.
enum ZenithWhatsAppStage: Equatable, Sendable {
    /// WhatsApp could not be started or brought forward.
    case launching
    /// The chat could not be found or confirmed.
    case openingChat
    /// The chat is open, but the reply could not be put in its composer.
    case placingText
    /// The reply is in the composer, but Return did not send it.
    case sending
}

enum ZenithReplyFallback {
    /// What a stopped WhatsApp reply leaves behind. The reply is never lost:
    /// it is in the composer, opened by its link, or on the clipboard.
    static func whatsApp(after stage: ZenithWhatsAppStage, route: ZenithWhatsAppPlan.Route) -> ZenithReplyOutcome {
        switch stage {
        case .sending:
            return .opened(prefilled: true, copied: false)
        case .launching, .openingChat, .placingText:
            if case .link = route, stage != .placingText { return .opened(prefilled: true, copied: false) }
            return .opened(prefilled: false, copied: true)
        }
    }

    /// What a Messages script's error number means for the reply. Denied
    /// Automation asks for access; anything else opens the conversation with
    /// the reply on the clipboard.
    static func messages(errorNumber: Int?) -> ZenithReplyOutcome {
        guard let errorNumber else { return .sent }
        switch errorNumber {
        case ZenithAppleScript.notPermitted, ZenithAppleScript.wouldRequireConsent:
            return .needsPermission(.automation)
        default:
            return .opened(prefilled: false, copied: true)
        }
    }

    /// A chat that cannot be told apart is never guessed at.
    static func messages(resolution: ZenithMessagesResolution) -> ZenithMessagesRecipient? {
        if case .recipient(let recipient) = resolution { return recipient }
        return nil
    }
}

// MARK: - Draft

enum ZenithReplyDraft {
    /// A reply worth sending: not just spaces and line breaks. Its own line
    /// breaks and spacing are kept as written, only the ends are trimmed.
    static func sendable(_ draft: String) -> String? {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.count <= 16_384 else { return nil }
        return text
    }
}
