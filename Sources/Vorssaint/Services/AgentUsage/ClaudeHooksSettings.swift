// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Zenith's hooks in Claude Code's `~/.claude/settings.json`.
///
/// The file belongs to the person and to Claude Code, so an edit keeps every
/// other key, hook and value as it was, in its order, and only adds or takes
/// away the handlers whose command runs Zenith's hook script. The file is read
/// and written with a small ordered JSON reader (`ClaudeSettingsJSON`), so a
/// key's place and a number's spelling survive; it is written the way Claude
/// Code writes it, two spaces deep. Before a change the old file is copied
/// beside it (`settings.json.zenith-backup`), and the new one is written
/// atomically to the link's target when the file is a link.
enum ClaudeHooksSettings {
    /// What every handler Zenith adds runs; how an edit recognises its own.
    static let marker = ClaudeHooksSupport.scriptName
    static let backupSuffix = ".zenith-backup"
    /// A hook that takes longer is cancelled by Claude Code. Zenith's takes a few milliseconds.
    static let timeout = 5
    /// Zenith fork: `Stop` may hold a finished turn for Zenith Pocket's reply
    /// (`ClaudeHooksSupport.awayWait`), with a minute to spare. Without Away
    /// mode it returns at once, as every other event does.
    static let stopTimeout = ClaudeHooksSupport.awayWait + 60

    /// The timeout Zenith's handler on `event` carries.
    static func timeout(for event: String) -> Int {
        event == "Stop" ? stopTimeout : timeout
    }

    /// The events Zenith listens to and whether each takes a matcher.
    static let events: [(name: String, matcher: Bool)] = [
        ("UserPromptSubmit", false), ("PreToolUse", true), ("PostToolUse", true), ("PostToolUseFailure", true),
        ("Notification", true), ("Stop", false), ("SessionEnd", true)
    ]

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    /// The command each handler runs: the script when it is there, nothing
    /// otherwise, and always a clean exit, so a removed Zenith never shows
    /// Claude Code an error.
    static func command(script: String) -> String {
        let quoted = "'" + script.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "[ -f \(quoted) ] && exec /bin/sh \(quoted); exit 0"
    }

    /// The handler group added to every event.
    static func group(command: String, matcher: Bool, timeout: Int = timeout) -> ClaudeSettingsJSON {
        var members: [ClaudeSettingsJSON.Member] = []
        if matcher { members.append(.init("matcher", .string("*"))) }
        members.append(.init("hooks", .array([.object([
            .init("type", .string("command")),
            .init("command", .string(command)),
            .init("timeout", .number(String(timeout)))
        ])])))
        return .object(members)
    }

    /// Exactly what a connection merges into the file, for the alert that asks first.
    static func fragment(command: String) -> String {
        let hooks = ClaudeSettingsJSON.object(events.map { event in
            .init(event.name, .array([group(command: command, matcher: event.matcher, timeout: timeout(for: event.name))]))
        })
        return ClaudeSettingsJSON.object([.init("hooks", hooks)]).serialized()
    }

    // MARK: State

    enum State: Equatable {
        /// No handler of Zenith's.
        case missing
        /// Every event runs this command.
        case connected
        /// Zenith's handlers are there, but for another build, an older
        /// script or only some events.
        case outdated
        /// The file is not JSON Zenith can read; it is never touched.
        case unreadable
    }

    static func state(of text: String?, command: String) -> State {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .missing }
        guard let root = ClaudeSettingsJSON.parse(text), case .object = root else { return .unreadable }
        let hooks = root["hooks"]
        var ours = 0, current = 0
        for event in events {
            let handlers = (hooks?[event.name]?.arrayValue ?? []).flatMap { group in group["hooks"]?.arrayValue ?? [] }
            let mine = handlers.filter { $0["command"]?.stringValue?.contains(marker) == true }
            if !mine.isEmpty { ours += 1 }
            // Zenith fork: a handler whose timeout is too short for this event
            // (a Stop from before Away mode) needs connecting again.
            let long = mine.allSatisfy { handler in
                guard case .number(let text)? = handler["timeout"], let seconds = Double(text) else { return false }
                return seconds >= Double(timeout(for: event.name))
            }
            if mine.compactMap({ $0["command"]?.stringValue }) == [command] && long { current += 1 }
        }
        // Handlers left on events Zenith no longer uses count too.
        let elsewhere = (hooks?.objectValue ?? []).contains { member in
            !events.contains { $0.name == member.key } && (member.value.arrayValue ?? []).contains { group in
                (group["hooks"]?.arrayValue ?? []).contains { $0["command"]?.stringValue?.contains(marker) == true }
            }
        }
        if ours == 0 && !elsewhere { return .missing }
        return current == events.count && !elsewhere ? .connected : .outdated
    }

    // MARK: Editing text

    /// `text` with Zenith's handlers on every event and every older one of
    /// them gone. Nil when the text is not a JSON object.
    static func installing(command: String, into text: String?) -> String? {
        let source = text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? text! : "{}"
        guard var root = ClaudeSettingsJSON.parse(source), case .object = root else { return nil }
        var hooks = root["hooks"] ?? .object([])
        guard case .object = hooks else { return nil }
        hooks = removingOurs(from: hooks)
        for event in events {
            var groups = hooks[event.name] ?? .array([])
            guard case .array(var list) = groups else { return nil }
            list.append(group(command: command, matcher: event.matcher, timeout: timeout(for: event.name)))
            groups = .array(list)
            hooks[event.name] = groups
        }
        root["hooks"] = hooks
        return root.serialized(trailingNewline: source.hasSuffix("\n"))
    }

    /// `text` without Zenith's handlers. Groups, events and the `hooks` key
    /// are dropped only when they held nothing but Zenith's. Nil when the
    /// text is not a JSON object.
    static func removing(from text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text ?? "" }
        guard var root = ClaudeSettingsJSON.parse(text), case .object = root else { return nil }
        guard let hooks = root["hooks"] else { return text }
        guard case .object = hooks else { return text }
        let cleaned = removingOurs(from: hooks)
        if case .object(let members) = cleaned, members.isEmpty, hooks.objectValue?.isEmpty == false {
            root["hooks"] = nil
        } else {
            root["hooks"] = cleaned
        }
        return root.serialized(trailingNewline: text.hasSuffix("\n"))
    }

    /// Every handler running Zenith's script taken out; a group, an event or
    /// the whole object emptied by that goes too, one already empty stays.
    private static func removingOurs(from hooks: ClaudeSettingsJSON) -> ClaudeSettingsJSON {
        guard case .object(let members) = hooks else { return hooks }
        var kept: [ClaudeSettingsJSON.Member] = []
        for member in members {
            guard case .array(let groups) = member.value else { kept.append(member); continue }
            var keptGroups: [ClaudeSettingsJSON] = []
            var removedAny = false
            for group in groups {
                guard case .array(let handlers)? = group["hooks"] else { keptGroups.append(group); continue }
                let others = handlers.filter { $0["command"]?.stringValue?.contains(marker) != true }
                if others.count == handlers.count { keptGroups.append(group); continue }
                removedAny = true
                if others.isEmpty { continue }
                var changed = group
                changed["hooks"] = .array(others)
                keptGroups.append(changed)
            }
            if removedAny && keptGroups.isEmpty { continue }
            kept.append(.init(member.key, .array(keptGroups)))
        }
        return .object(kept)
    }

    // MARK: Editing the file

    enum EditResult: Equatable {
        case changed, unchanged, unreadable, failed
    }

    /// Reads the file at `url` (followed to its target when it is a link).
    static func read(at url: URL) -> String?? {
        let target = url.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: target.path) else { return .some(nil) }
        guard let data = try? Data(contentsOf: target), let text = String(data: data, encoding: .utf8) else { return nil }
        return .some(text)
    }

    /// Connects (`command` set) or disconnects (nil) the file at `url`: the
    /// old file copied to `<name>.zenith-backup` first, the new one written
    /// atomically with the permissions the old one had.
    static func edit(at url: URL, install command: String?) -> EditResult {
        let target = url.resolvingSymlinksInPath()
        guard let current = read(at: url) else { return .unreadable }
        if current == nil && command == nil { return .unchanged }
        let edited = command.map { installing(command: $0, into: current) } ?? removing(from: current)
        guard let edited else { return .unreadable }
        guard edited != (current ?? "") else { return .unchanged }
        let manager = FileManager.default
        let permissions = (try? manager.attributesOfItem(atPath: target.path))?[.posixPermissions] as? NSNumber
        if let current {
            let backup = target.deletingLastPathComponent()
                .appendingPathComponent(target.lastPathComponent + backupSuffix, isDirectory: false)
            guard (try? Data(current.utf8).write(to: backup, options: .atomic)) != nil else { return .failed }
            try? manager.setAttributes([.posixPermissions: permissions ?? NSNumber(value: 0o600)], ofItemAtPath: backup.path)
        } else {
            guard (try? manager.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)) != nil else { return .failed }
        }
        guard (try? Data(edited.utf8).write(to: target, options: .atomic)) != nil else { return .failed }
        try? manager.setAttributes([.posixPermissions: permissions ?? NSNumber(value: 0o644)], ofItemAtPath: target.path)
        return .changed
    }
}

/// A JSON value that keeps its object keys in order and its numbers as
/// written, so a file read and written back changes only what was edited.
indirect enum ClaudeSettingsJSON: Equatable {
    struct Member: Equatable {
        let key: String
        var value: ClaudeSettingsJSON
        init(_ key: String, _ value: ClaudeSettingsJSON) {
            self.key = key
            self.value = value
        }
    }

    case object([Member])
    case array([ClaudeSettingsJSON])
    case string(String)
    /// The number's text, as it was written.
    case number(String)
    case bool(Bool)
    case null

    var objectValue: [Member]? { if case .object(let members) = self { return members } else { return nil } }
    var arrayValue: [ClaudeSettingsJSON]? { if case .array(let values) = self { return values } else { return nil } }
    var stringValue: String? { if case .string(let value) = self { return value } else { return nil } }

    /// An object's member; setting nil removes it, a new key goes at the end.
    subscript(key: String) -> ClaudeSettingsJSON? {
        get { objectValue?.first { $0.key == key }?.value }
        set {
            guard case .object(var members) = self else { return }
            if let index = members.firstIndex(where: { $0.key == key }) {
                if let newValue { members[index].value = newValue } else { members.remove(at: index) }
            } else if let newValue {
                members.append(Member(key, newValue))
            }
            self = .object(members)
        }
    }

    // MARK: Reading

    static func parse(_ text: String) -> ClaudeSettingsJSON? {
        var parser = Parser(bytes: Array(text.utf8))
        parser.skipBOM()
        guard let value = parser.value(depth: 0) else { return nil }
        parser.skipSpace()
        return parser.index == parser.bytes.count ? value : nil
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0
        static let maxDepth = 256

        mutating func skipBOM() {
            if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF { index = 3 }
        }

        mutating func skipSpace() {
            while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
        }

        mutating func value(depth: Int) -> ClaudeSettingsJSON? {
            guard depth < Self.maxDepth else { return nil }
            skipSpace()
            guard index < bytes.count else { return nil }
            switch bytes[index] {
            case UInt8(ascii: "{"): return object(depth: depth)
            case UInt8(ascii: "["): return array(depth: depth)
            case UInt8(ascii: "\""): return string().map(ClaudeSettingsJSON.string)
            case UInt8(ascii: "t"): return literal("true", .bool(true))
            case UInt8(ascii: "f"): return literal("false", .bool(false))
            case UInt8(ascii: "n"): return literal("null", .null)
            default: return number()
            }
        }

        mutating func literal(_ word: String, _ value: ClaudeSettingsJSON) -> ClaudeSettingsJSON? {
            let expected = Array(word.utf8)
            guard index + expected.count <= bytes.count, Array(bytes[index..<index + expected.count]) == expected else {
                return nil
            }
            index += expected.count
            return value
        }

        mutating func object(depth: Int) -> ClaudeSettingsJSON? {
            index += 1
            var members: [Member] = []
            skipSpace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "}") { index += 1; return .object([]) }
            while true {
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: "\""), let key = string() else { return nil }
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { return nil }
                index += 1
                guard let value = value(depth: depth + 1) else { return nil }
                members.append(Member(key, value))
                skipSpace()
                guard index < bytes.count else { return nil }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "}") { index += 1; return .object(members) }
                return nil
            }
        }

        mutating func array(depth: Int) -> ClaudeSettingsJSON? {
            index += 1
            var values: [ClaudeSettingsJSON] = []
            skipSpace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "]") { index += 1; return .array([]) }
            while true {
                guard let value = value(depth: depth + 1) else { return nil }
                values.append(value)
                skipSpace()
                guard index < bytes.count else { return nil }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "]") { index += 1; return .array(values) }
                return nil
            }
        }

        mutating func string() -> String? {
            index += 1
            var output: [UInt8] = []
            var pendingHigh: UInt16?
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == UInt8(ascii: "\"") {
                    guard pendingHigh == nil else { return nil }
                    return String(bytes: output, encoding: .utf8)
                }
                if byte < 0x20 { return nil }
                guard byte == UInt8(ascii: "\\") else {
                    guard pendingHigh == nil else { return nil }
                    output.append(byte)
                    continue
                }
                guard index < bytes.count else { return nil }
                let escape = bytes[index]
                index += 1
                if escape != UInt8(ascii: "u"), pendingHigh != nil { return nil }
                switch escape {
                case UInt8(ascii: "\""): output.append(0x22)
                case UInt8(ascii: "\\"): output.append(0x5C)
                case UInt8(ascii: "/"): output.append(0x2F)
                case UInt8(ascii: "b"): output.append(0x08)
                case UInt8(ascii: "f"): output.append(0x0C)
                case UInt8(ascii: "n"): output.append(0x0A)
                case UInt8(ascii: "r"): output.append(0x0D)
                case UInt8(ascii: "t"): output.append(0x09)
                case UInt8(ascii: "u"):
                    guard index + 4 <= bytes.count,
                          let unit = UInt16(String(decoding: bytes[index..<index + 4], as: UTF8.self), radix: 16) else {
                        return nil
                    }
                    index += 4
                    if let high = pendingHigh {
                        guard (0xDC00...0xDFFF).contains(unit) else { return nil }
                        pendingHigh = nil
                        let scalar = 0x10000 + ((UInt32(high) - 0xD800) << 10) + (UInt32(unit) - 0xDC00)
                        guard let character = Unicode.Scalar(scalar) else { return nil }
                        output.append(contentsOf: Array(String(Character(character)).utf8))
                    } else if (0xD800...0xDBFF).contains(unit) {
                        pendingHigh = unit
                    } else if (0xDC00...0xDFFF).contains(unit) {
                        return nil
                    } else {
                        guard let character = Unicode.Scalar(unit) else { return nil }
                        output.append(contentsOf: Array(String(Character(character)).utf8))
                    }
                default: return nil
                }
            }
            return nil
        }

        mutating func number() -> ClaudeSettingsJSON? {
            let start = index
            if index < bytes.count, bytes[index] == UInt8(ascii: "-") { index += 1 }
            guard index < bytes.count, isDigit(bytes[index]) else { return nil }
            if bytes[index] == UInt8(ascii: "0") { index += 1 } else { while index < bytes.count, isDigit(bytes[index]) { index += 1 } }
            if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
                index += 1
                guard index < bytes.count, isDigit(bytes[index]) else { return nil }
                while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            }
            if index < bytes.count, bytes[index] == UInt8(ascii: "e") || bytes[index] == UInt8(ascii: "E") {
                index += 1
                if index < bytes.count, bytes[index] == UInt8(ascii: "+") || bytes[index] == UInt8(ascii: "-") { index += 1 }
                guard index < bytes.count, isDigit(bytes[index]) else { return nil }
                while index < bytes.count, isDigit(bytes[index]) { index += 1 }
            }
            return .number(String(decoding: bytes[start..<index], as: UTF8.self))
        }

        func isDigit(_ byte: UInt8) -> Bool { byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9") }
    }

    // MARK: Writing

    /// Two spaces deep, as Claude Code writes the file.
    func serialized(trailingNewline: Bool = false) -> String {
        var output = ""
        write(into: &output, indent: 0)
        return trailingNewline ? output + "\n" : output
    }

    private func write(into output: inout String, indent: Int) {
        switch self {
        case .object(let members):
            guard !members.isEmpty else { output += "{}"; return }
            output += "{\n"
            for (offset, member) in members.enumerated() {
                output += String(repeating: "  ", count: indent + 1)
                Self.writeString(member.key, into: &output)
                output += ": "
                member.value.write(into: &output, indent: indent + 1)
                output += offset == members.count - 1 ? "\n" : ",\n"
            }
            output += String(repeating: "  ", count: indent) + "}"
        case .array(let values):
            guard !values.isEmpty else { output += "[]"; return }
            output += "[\n"
            for (offset, value) in values.enumerated() {
                output += String(repeating: "  ", count: indent + 1)
                value.write(into: &output, indent: indent + 1)
                output += offset == values.count - 1 ? "\n" : ",\n"
            }
            output += String(repeating: "  ", count: indent) + "]"
        case .string(let value): Self.writeString(value, into: &output)
        case .number(let text): output += text
        case .bool(let value): output += value ? "true" : "false"
        case .null: output += "null"
        }
    }

    private static func writeString(_ value: String, into output: inout String) {
        output += "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{08}": output += "\\b"
            case "\u{0C}": output += "\\f"
            default:
                if scalar.value < 0x20 {
                    output += String(format: "\\u%04x", scalar.value)
                } else {
                    output.unicodeScalars.append(scalar)
                }
            }
        }
        output += "\""
    }
}
