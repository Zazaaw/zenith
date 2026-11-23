// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: lock this Mac and check on it from an iPhone. The iPhone's
// Shortcuts app runs "Run Script over SSH" against this Mac over Tailscale;
// its key may only run Zenith's small script (`command=` in
// ~/.ssh/authorized_keys), which accepts `lock [device]` or
// `status [device]` and hands the request to the running app through a file
// in `<container>/remote/requests/`. The app answers in
// `<container>/remote/responses/<id>`. Zenith never unlocks and never runs
// anything else. Pure rules, the script and the authorized_keys edits;
// RemoteControlService runs them. Compiled into the tests.

enum RemoteControl {
    /// `<container>/remote`, and what lives in it.
    static let folderName = "remote"
    static let scriptName = "zenith-remote"
    static let requestsName = "requests"
    static let responsesName = "responses"
    /// The running app's process id, which the script checks before it asks.
    static let pidName = "zenith.pid"
    static let requestExtension = "req"
    /// The first line of every request.
    static let requestHeader = "zenith-remote 1"
    /// A request older than this, or from further ahead than `futureSkew`, is refused.
    static let maximumAge: TimeInterval = 10
    static let futureSkew: TimeInterval = 2
    static let maximumRequestBytes = 1024
    /// How long the script waits for the answer, in tenths of a second.
    static let answerTenths = 40
    /// An answer nobody collected is removed after this long.
    static let staleResponse: TimeInterval = 30
    static let defaultDevice = "iPhone"
    static let maximumDeviceLength = 40
    /// The in-memory log Settings shows.
    static let logLimit = 20
}

enum RemoteVerb: String, CaseIterable, Equatable {
    case lock, status
}

/// One request the script left for the app.
struct RemoteRequest: Equatable {
    let id: String
    let verb: RemoteVerb
    let device: String
    let sent: Date
}

enum RemoteRequestError: Error, Equatable {
    case badID, tooLarge, malformed, unknownVerb, stale
}

enum RemoteRequestParser {
    /// The script names a request `<epoch>-<pid>-<random>`: digits and dashes,
    /// so a name can never climb out of the folder.
    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64 && id.unicodeScalars.allSatisfy {
            $0.isASCII && (CharacterSet.decimalDigits.contains($0) || CharacterSet.letters.contains($0) || $0 == "-")
        }
    }

    /// Reads a request file: the header, the verb, the time it was sent (epoch
    /// seconds) and the device's name. `modified` is the file's own time,
    /// which must be fresh too.
    static func parse(_ data: Data, id: String, modified: Date?, now: Date) -> Result<RemoteRequest, RemoteRequestError> {
        guard isValidID(id) else { return .failure(.badID) }
        guard data.count <= RemoteControl.maximumRequestBytes else { return .failure(.tooLarge) }
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 3, lines[0] == RemoteControl.requestHeader,
              let seconds = TimeInterval(lines[2].trimmingCharacters(in: .whitespaces)), seconds.isFinite
        else { return .failure(.malformed) }
        guard let verb = RemoteVerb(rawValue: lines[1]) else { return .failure(.unknownVerb) }
        let sent = Date(timeIntervalSince1970: seconds)
        guard isFresh(sent, now: now), modified.map({ isFresh($0, now: now) }) ?? true else { return .failure(.stale) }
        let device = RemoteDeviceName.sanitize(lines.count > 3 ? lines[3] : "")
        return .success(RemoteRequest(id: id, verb: verb, device: device, sent: sent))
    }

    static func isFresh(_ date: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(date)
        return age < RemoteControl.maximumAge && age > -RemoteControl.futureSkew
    }

    /// What the app leaves for the script: the exit status on the first line,
    /// then the text to print.
    static func response(status: Int32, text: String) -> Data {
        Data(("\(status)\n" + text + (text.hasSuffix("\n") ? "" : "\n")).utf8)
    }
}

/// The device's name as the island and the log show it.
enum RemoteDeviceName {
    private static let quotes: [(Character, Character)] = [("\"", "\""), ("'", "'"), ("“", "”"), ("‘", "’"), ("„", "“")]

    /// Printable characters only: control characters and line breaks become
    /// spaces, invisible format characters (which could reorder the text) go;
    /// spaces collapsed, one pair of surrounding quotes removed, at most 40
    /// characters; "iPhone" when nothing is left.
    static func sanitize(_ raw: String) -> String {
        let printable = String(String.UnicodeScalarView(raw.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            switch scalar.properties.generalCategory {
            case .control, .lineSeparator, .paragraphSeparator: return " "
            case .format, .surrogate, .privateUse, .unassigned: return nil
            default: return scalar
            }
        }))
        var name = printable.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        for (open, close) in quotes where name.count >= 2 && name.first == open && name.last == close {
            name = String(name.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            break
        }
        if name.count > RemoteControl.maximumDeviceLength {
            name = String(name.prefix(RemoteControl.maximumDeviceLength)).trimmingCharacters(in: .whitespaces)
        }
        return name.isEmpty ? RemoteControl.defaultDevice : name
    }

    /// "Faiz’s iPhone" → "iPhone": the kind of device, for the welcome back.
    static func short(_ name: String) -> String {
        for mark in ["’s ", "'s "] {
            if let range = name.range(of: mark, options: .backwards) {
                let rest = name[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { return rest }
            }
        }
        return name
    }
}

/// At most `limit` requests in any `window` seconds, every device together.
struct RemoteRateLimiter {
    var limit = 10
    var window: TimeInterval = 60
    private(set) var accepted: [Date] = []

    mutating func allow(at now: Date) -> Bool {
        accepted.removeAll { now.timeIntervalSince($0) >= window || $0 > now }
        guard accepted.count < limit else { return false }
        accepted.append(now)
        return true
    }
}

/// A short English duration: "3h 12m", "45m", "40s", "2d 3h".
enum RemoteDuration {
    static func text(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        let days = total / 86_400, hours = total % 86_400 / 3_600, minutes = total % 3_600 / 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(max(1, total))s"
    }
}

// MARK: - Status

/// What the status answer is made of, read on the main thread.
struct RemoteStatusInput: Equatable {
    enum Charge: Equatable { case charging, held, full, onBattery }
    struct Job: Equatable {
        let title: String
        let fraction: Double?
    }

    var locked = false
    /// When the Mac locked, or since when it has been in use.
    var since: Date?
    var batteryPercent: Int?
    var charge: Charge?
    var jobs: [Job] = []
    var title: String?
    var artist: String?
    /// Today's coding time, when WakaTime is set up.
    var wakaTimeSeconds: Double?
}

enum RemoteStatusText {
    static let jobLimit = 3

    /// A few short English lines, only those that have something to say:
    ///
    ///     Unlocked · in use 3h 12m
    ///     Battery 82% · charging
    ///     Export DaVinci 62%
    ///     Here With Me · d4vd
    ///     WakaTime today 4h 56m
    static func make(_ input: RemoteStatusInput, now: Date) -> String {
        var lines: [String] = []
        let elapsed = input.since.map { RemoteDuration.text(now.timeIntervalSince($0)) }
        if input.locked {
            lines.append(elapsed.map { "Locked · \($0)" } ?? "Locked")
        } else {
            lines.append(elapsed.map { "Unlocked · in use \($0)" } ?? "Unlocked")
        }
        if let percent = input.batteryPercent {
            let state: String?
            switch input.charge {
            case .charging: state = "charging"
            case .held: state = "on hold"
            case .full: state = "charged"
            case .onBattery: state = "on battery"
            case nil: state = nil
            }
            lines.append("Battery \(min(100, max(0, percent)))%" + (state.map { " · " + $0 } ?? ""))
        }
        for job in input.jobs.prefix(jobLimit) {
            let title = clean(job.title)
            guard !title.isEmpty else { continue }
            if let fraction = job.fraction, fraction.isFinite {
                lines.append("\(title) \(Int((min(1, max(0, fraction)) * 100).rounded(.down)))%")
            } else {
                lines.append("\(title) running")
            }
        }
        if let title = input.title.map(clean), !title.isEmpty {
            let artist = input.artist.map(clean) ?? ""
            lines.append(artist.isEmpty ? title : "\(title) · \(artist)")
        }
        if let seconds = input.wakaTimeSeconds, seconds >= 60 {
            lines.append("WakaTime today \(RemoteDuration.text(seconds))")
        }
        return lines.joined(separator: "\n")
    }

    /// "Export" before an export's label, and so on; a command or a label that
    /// already says it stays as it is.
    static func jobTitle(prefix: String?, label: String) -> String {
        let label = clean(label)
        guard let prefix, !prefix.isEmpty else { return label }
        if label.isEmpty { return prefix }
        return label.lowercased().hasPrefix(prefix.lowercased()) ? label : "\(prefix) \(label)"
    }

    /// One line, at most 60 characters.
    private static func clean(_ text: String) -> String {
        let flat = text.split(whereSeparator: { $0.isNewline || $0.isWhitespace }).joined(separator: " ")
        return flat.count > 60 ? String(flat.prefix(59)) + "…" : flat
    }
}

// MARK: - What the island and the iPhone read (English)

enum RemoteText {
    static let checkedStatus = "checked status"
    static let justNow = "just now"

    static func lockedFrom(_ device: String) -> String { "Locked from \(device)" }

    /// The welcome back's line after a remote lock: "Locked from iPhone · 1h 20m ago".
    static func welcomeDetail(device: String, seconds: TimeInterval) -> String {
        "Locked from \(RemoteDeviceName.short(device)) · \(RemoteDuration.text(seconds)) ago"
    }

    static func locked(macBook: Bool) -> String { "\(macBook ? "MacBook" : "Mac") locked ✓" }
    static func alreadyLocked(macBook: Bool) -> String { "\(macBook ? "MacBook" : "Mac") is already locked ✓" }
    static let screenSaver = "Screen saver started; it locks if a password is required"
    static let tooMany = "Too many requests. Try again in a minute."
    static let expired = "The request expired. Try again."
    static let unknown = "usage: lock [device name] | status [device name]"
    static let notRunning = "Zenith isn't running"
    static let noAnswer = "Zenith didn't answer"
}

/// The remote lock the lock screen's padlock island greets with "Locked
/// from Faiz’s iPhone", set just before the Mac locks and taken once by the
/// island as it notices the lock. Main thread only.
enum ZenithRemoteLockMark {
    /// How long a mark waits for the lock to be noticed.
    static let window: TimeInterval = 10
    nonisolated(unsafe) private static var pending: (device: String, at: Date)?

    static func mark(device: String, at date: Date = Date()) { pending = (device, date) }

    static func take(at now: Date = Date()) -> String? {
        defer { pending = nil }
        guard let pending, now.timeIntervalSince(pending.at) < window, now >= pending.at.addingTimeInterval(-1)
        else { return nil }
        return pending.device
    }
}

// MARK: - The script

enum RemoteScript {
    /// The forced command's script. POSIX sh, standard tools only (no
    /// network, no interpreter), safe to run any number of times. It takes
    /// `lock [device]` or `status [device]` from $SSH_ORIGINAL_COMMAND (the
    /// first line, case-insensitive verb, quotes around the name removed),
    /// cleans the name, leaves a 0600 request for the running app, waits up
    /// to `waitTenths` tenths of a second for the answer, prints it and
    /// removes both files.
    static func text(folder: String, waitTenths: Int = RemoteControl.answerTenths) -> String {
        #"""
        #!/bin/sh
        # zenith-remote: lets an iPhone lock this Mac or ask how it is, through Zenith.
        # Added by Zenith (Settings > iPhone Remote) as the only command an iPhone's
        # SSH key may run. It accepts "lock [device name]" or "status [device name]",
        # asks the running Zenith through a file and prints its answer. It never
        # unlocks the Mac, uses no network and runs nothing else.
        umask 077
        PATH=/usr/bin:/bin
        export PATH
        LC_ALL=C
        export LC_ALL
        d=\#(shellQuoted(folder))
        usage() { echo "\#(RemoteText.unknown)"; exit 2; }
        c=$(printf '%s\n' "${SSH_ORIGINAL_COMMAND-}" | head -n 1 | tr '\t\r' '  ' | tr -d '\000-\010\012-\037\177')
        c=${c#"${c%%[! ]*}"}
        c=${c%"${c##*[! ]}"}
        v=${c%% *}
        n=${c#"$v"}
        n=${n#"${n%%[! ]*}"}
        v=$(printf '%s' "$v" | tr 'A-Z' 'a-z')
        case "$v" in
          lock|status) ;;
          *) usage ;;
        esac
        for q in '"' "'"; do
          case "$n" in
            "$q"*"$q") n=${n#"$q"}; n=${n%"$q"}; break ;;
          esac
        done
        case "$n" in
          “*”) n=${n#“}; n=${n%”} ;;
          ‘*’) n=${n#‘}; n=${n%’} ;;
        esac
        n=$(printf '%s' "$n" | LC_ALL=en_US.UTF-8 cut -c 1-\#(RemoteControl.maximumDeviceLength))
        [ -n "$n" ] || n='\#(RemoteControl.defaultDevice)'
        p=$(cat "$d/\#(RemoteControl.pidName)" 2>/dev/null)
        case "$p" in
          ''|*[!0-9]*) echo "\#(RemoteText.notRunning)"; exit 1 ;;
        esac
        if ! kill -0 "$p" 2>/dev/null || [ ! -d "$d/\#(RemoteControl.requestsName)" ]; then
          echo "\#(RemoteText.notRunning)"; exit 1
        fi
        r=$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')
        i="$(date +%s)-$$-$r"
        t="$d/\#(RemoteControl.requestsName)/.$i.tmp"
        q="$d/\#(RemoteControl.requestsName)/$i.\#(RemoteControl.requestExtension)"
        a="$d/\#(RemoteControl.responsesName)/$i"
        printf '%s\n%s\n%s\n%s\n' '\#(RemoteControl.requestHeader)' "$v" "$(date +%s)" "$n" > "$t" || exit 1
        mv -f "$t" "$q" || { rm -f "$t"; exit 1; }
        k=0
        while [ "$k" -lt \#(waitTenths) ]; do
          if [ -f "$a" ]; then
            s=$(head -n 1 "$a")
            tail -n +2 "$a"
            rm -f "$a" "$q"
            case "$s" in
              ''|*[!0-9]*) exit 1 ;;
            esac
            exit "$s"
          fi
          sleep 0.1
          k=$((k + 1))
        done
        rm -f "$q"
        echo "\#(RemoteText.noAnswer)"
        exit 1

        """#
    }

    /// `/bin/sh '<script>'`, the forced command, or nil for a path the
    /// authorized_keys line could not carry (a double quote or a line break).
    static func command(script: String) -> String? {
        guard !script.isEmpty, !script.contains("\""), !script.contains(where: \.isNewline) else { return nil }
        return "/bin/sh " + shellQuoted(script)
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// What to type in the Shortcut's script field: `lock "Faiz’s iPhone"`.
    static func shortcutScript(_ verb: RemoteVerb, device: String) -> String {
        let name = RemoteDeviceName.sanitize(device).replacingOccurrences(of: "\"", with: "")
        return "\(verb.rawValue) \"\(name)\""
    }

    /// The optional hardening the person may run himself: key-only SSH. The
    /// drop-in sorts before macOS's own 100-macos.conf, so its values win.
    static let hardeningPath = "/etc/ssh/sshd_config.d/050-zenith.conf"
    static let hardeningCommand =
        "printf 'PasswordAuthentication no\\nKbdInteractiveAuthentication no\\n' | sudo tee \(hardeningPath) > /dev/null"
}

// MARK: - Tailscale

enum RemoteTailscale {
    static let appPath = "/Applications/Tailscale.app"
    static let cliPath = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    /// Makes the app's binary act as the command line tool instead of the GUI.
    static let cliModeVariable = "TAILSCALE_BE_CLI"

    struct Status: Equatable {
        let running: Bool
        /// The MagicDNS name's first label, such as "faizs-macbook-pro".
        let host: String?
    }

    /// Reads `tailscale status --json`: the backend state and this Mac's DNS name.
    static func parse(_ data: Data) -> Status? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let running = (object["BackendState"] as? String) == "Running"
        let me = object["Self"] as? [String: Any]
        let dns = (me?["DNSName"] as? String).flatMap(shortHost)
        let host = dns ?? (me?["HostName"] as? String).flatMap(shortHost)
        return Status(running: running, host: host)
    }

    /// "faizs-macbook-pro.tail1234.ts.net." → "faizs-macbook-pro".
    static func shortHost(_ name: String) -> String? {
        let label = name.trimmingCharacters(in: .whitespaces).split(separator: ".").first.map(String.init) ?? ""
        guard !label.isEmpty, label.unicodeScalars.allSatisfy({
            $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-")
        }) else { return nil }
        return label.lowercased()
    }

    /// The local host name as a fallback host: "Faizs-MacBook-Pro" → "faizs-macbook-pro.local".
    static func localHost(_ name: String?) -> String? {
        guard let name, let short = shortHost(name) else { return nil }
        return short + ".local"
    }
}

// MARK: - authorized_keys

/// An SSH public key as pasted from the Shortcuts app.
struct RemotePublicKey: Equatable {
    let type: String
    /// The key's base64 blob.
    let blob: String

    static let types: Set<String> = ["ssh-ed25519", "ssh-rsa", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384",
                                     "ecdsa-sha2-nistp521", "sk-ssh-ed25519@openssh.com",
                                     "sk-ecdsa-sha2-nistp256@openssh.com"]

    /// `ssh-ed25519 AAAA… [comment]`: a known type, then base64 whose
    /// decoded blob starts with the same type, as every SSH key does.
    static func parse(_ text: String) -> RemotePublicKey? {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
        guard let index = words.firstIndex(where: types.contains), index + 1 < words.count else { return nil }
        let type = words[index], blob = words[index + 1]
        guard blob.count <= 16_384, let data = Data(base64Encoded: blob), data.count > 4 else { return nil }
        let bytes = [UInt8](data)
        let length = Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
        guard length == type.utf8.count, bytes.count >= 4 + length,
              String(decoding: bytes[4..<(4 + length)], as: UTF8.self) == type else { return nil }
        return RemotePublicKey(type: type, blob: blob)
    }

    /// The last characters of the key, enough to tell two apart.
    var tail: String { String(blob.suffix(8)) }
}

/// A device Zenith added to authorized_keys.
struct RemoteDevice: Equatable, Identifiable {
    let name: String
    let key: RemotePublicKey
    var id: String { key.blob }
}

enum RemoteAuthorizedKeys {
    /// Every line Zenith adds ends with this and the device's name.
    static let marker = "zenith-remote:"
    static let restrictions = "restrict,no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding"
    static let fileName = "authorized_keys"
    static let backupName = "authorized_keys.zenith-backup"

    enum Outcome: Equatable {
        case changed, unchanged
        /// The key is already in the file on a line Zenith did not add, which
        /// would let it in without the restrictions.
        case conflict
        case invalidKey, invalidScript, notFound, isLink, failed
    }

    /// The one restricted line for `key`, named `name`.
    static func line(key: RemotePublicKey, name: String, script: String) -> String? {
        guard let command = RemoteScript.command(script: script) else { return nil }
        let name = RemoteDeviceName.sanitize(name)
        return "\(restrictions),command=\"\(command)\" \(key.type) \(key.blob) \(marker)\(name)"
    }

    /// A line's parts: its words split on spaces outside double quotes.
    struct Entry {
        let key: RemotePublicKey
        let options: String?
        let comment: String

        var isZenith: Bool {
            (options?.hasPrefix(restrictions + ",command=\"") ?? false) && comment.hasPrefix(marker)
        }

        var name: String { String(comment.dropFirst(marker.count)) }
    }

    static func entry(_ line: String) -> Entry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        var words: [String] = []
        var current = "", quoted = false, escaped = false
        var rest = Substring(trimmed)
        // Words until the key, then the rest of the line is its comment.
        while let character = rest.first {
            rest.removeFirst()
            if escaped { current.append(character); escaped = false; continue }
            if character == "\\" && quoted { current.append(character); escaped = true; continue }
            if character == "\"" { quoted.toggle() }
            if character.isWhitespace && !quoted {
                if !current.isEmpty { words.append(current); current = "" }
                if words.count >= 2, RemotePublicKey.types.contains(words[words.count - 2]) { break }
                continue
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        guard let index = words.firstIndex(where: RemotePublicKey.types.contains), index + 1 < words.count, index <= 1
        else { return nil }
        let key = RemotePublicKey(type: words[index], blob: words[index + 1])
        return Entry(key: key, options: index == 1 ? words[0] : nil,
                     comment: rest.trimmingCharacters(in: .whitespaces))
    }

    /// The devices Zenith added, in the file's order.
    static func devices(in text: String) -> [RemoteDevice] {
        text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            guard let entry = entry(String(line)), entry.isZenith else { return nil }
            return RemoteDevice(name: entry.name, key: entry.key)
        }
    }

    /// `text` with `key`'s restricted line: appended, or replacing Zenith's
    /// own line for the same key (a new name or script); unchanged when the
    /// same line is there already.
    static func adding(_ key: RemotePublicKey, name: String, script: String, to text: String) -> (String, Outcome) {
        guard let new = line(key: key, name: name, script: script) else { return (text, .invalidScript) }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let index = lines.firstIndex(where: { entry($0)?.key.blob == key.blob }) {
            guard entry(lines[index])?.isZenith == true else { return (text, .conflict) }
            if lines[index] == new { return (text, .unchanged) }
            lines[index] = new
            return (lines.joined(separator: "\n"), .changed)
        }
        var result = text
        if !result.isEmpty && !result.hasSuffix("\n") { result += "\n" }
        return (result + new + "\n", .changed)
    }

    /// `text` without Zenith's line for `blob`; lines Zenith did not add stay.
    static func removing(_ blob: String, from text: String) -> (String, Outcome) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let kept = lines.filter { line in
            guard let entry = entry(line) else { return true }
            return !(entry.isZenith && entry.key.blob == blob)
        }
        guard kept.count != lines.count else { return (text, .notFound) }
        return (kept.joined(separator: "\n"), .changed)
    }

    // MARK: The file

    /// The devices in `<ssh>/authorized_keys`.
    static func devices(ssh: URL) -> [RemoteDevice] {
        let file = ssh.appendingPathComponent(fileName)
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return devices(in: text)
    }

    static func add(_ key: RemotePublicKey, name: String, script: String, ssh: URL) -> Outcome {
        edit(ssh: ssh) { adding(key, name: name, script: script, to: $0) }
    }

    static func remove(_ blob: String, ssh: URL) -> Outcome {
        edit(ssh: ssh) { removing(blob, from: $0) }
    }

    /// Creates `<ssh>` 0700 and the file 0600 when missing, refuses a file
    /// that is a link, keeps a copy of the file as it was in
    /// `authorized_keys.zenith-backup` (0600) before changing it, and writes
    /// only when the text changes.
    private static func edit(ssh: URL, _ change: (String) -> (String, Outcome)) -> Outcome {
        let manager = FileManager.default
        let file = ssh.appendingPathComponent(fileName)
        var isFolder: ObjCBool = false
        if !manager.fileExists(atPath: ssh.path, isDirectory: &isFolder) {
            guard (try? manager.createDirectory(at: ssh, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])) != nil else { return .failed }
            try? manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: ssh.path)
        } else if !isFolder.boolValue {
            return .failed
        }
        let attributes = try? manager.attributesOfItem(atPath: file.path)
        if attributes?[.type] as? FileAttributeType == .typeSymbolicLink { return .isLink }
        let existing: Data?
        if attributes != nil {
            guard let data = try? Data(contentsOf: file) else { return .failed }
            existing = data
        } else {
            existing = nil
        }
        guard let old = existing.map({ String(data: $0, encoding: .utf8) }) ?? "" else { return .failed }
        let (new, outcome) = change(old)
        guard outcome == .changed else { return outcome }
        if let existing {
            let backup = ssh.appendingPathComponent(backupName)
            if (try? manager.attributesOfItem(atPath: backup.path))?[.type] as? FileAttributeType == .typeSymbolicLink {
                return .isLink
            }
            guard (try? existing.write(to: backup, options: .atomic)) != nil else { return .failed }
            try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        guard (try? Data(new.utf8).write(to: file, options: .atomic)) != nil else { return .failed }
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return .changed
    }
}
