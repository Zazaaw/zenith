// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: workspaces. One click sets the Mac up for a kind of work:
// opens its apps (with a folder or a link each), hides or quits the rest,
// arranges the windows with Window Layout's positions, turns Keep Awake on or
// off, runs a Shortcut that sets a Focus, picks a sound output, a wallpaper,
// and opens links. Each step is optional and runs in order; one that fails is
// reported and the rest still run.
//
// Everything here is pure (Foundation and CoreGraphics only) and compiled into
// the tests: the model and its storage with migration, the examples, editing,
// the runner over any performer, the notice text, the Shortcuts command, the
// capture of the current windows and the plans for hiding and quitting.
// WorkspaceService runs them; WorkspaceSystemPerformer touches the Mac.

// MARK: - Model

/// A workspace's identity colour, from the island's calm palette (the 400
/// steps its modules wear on soft tiles). Identity, never a state.
enum WorkspaceColor: String, CaseIterable, Codable {
    case blue, indigo, violet, rose, orange, amber, green, teal

    var hex: UInt32 {
        switch self {
        case .blue: return 0x60A5FA
        case .indigo: return 0x818CF8
        case .violet: return 0xA78BFA
        case .rose: return 0xFB7185
        case .orange: return 0xFB923C
        case .amber: return 0xFBBF24
        case .green: return 0x4ADE80
        case .teal: return 0x2DD4BF
        }
    }

    func title(_ text: ZenithWorkspacesStrings) -> String {
        switch self {
        case .blue: return text.blue
        case .indigo: return text.indigo
        case .violet: return text.violet
        case .rose: return text.rose
        case .orange: return text.orange
        case .amber: return text.amber
        case .green: return text.green
        case .teal: return text.teal
        }
    }
}

/// The SF Symbols a workspace can wear.
enum WorkspaceSymbols {
    static let fallback = "square.grid.2x2"
    static let choices = [
        "chevron.left.forwardslash.chevron.right", "terminal", "film", "camera.aperture",
        "photo", "paintbrush.pointed", "pencil.and.ruler", "music.note",
        "book", "briefcase", "graduationcap", "cup.and.saucer",
        "gamecontroller", "person.2", "moon.stars", fallback,
    ]
}

/// An app a step names: found by its bundle identifier, then by where it was
/// last seen. `target` is an optional file, folder or link it opens with.
struct WorkspaceApp: Codable, Equatable, Hashable {
    var bundleID: String
    var name: String
    var path: String
    var target: String

    init(bundleID: String, name: String, path: String = "", target: String = "") {
        self.bundleID = bundleID
        self.name = name
        self.path = path
        self.target = target
    }

    private enum CodingKeys: String, CodingKey { case bundleID = "bundle", name, path, target }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID) ?? ""
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        let stored = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        name = stored.isEmpty ? WorkspaceApp.name(fromPath: path, fallback: bundleID) : stored
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
        guard !bundleID.isEmpty || !path.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .bundleID, in: c, debugDescription: "an app with neither a bundle nor a path")
        }
    }

    /// "Visual Studio Code" from ".../Visual Studio Code.app".
    static func name(fromPath path: String, fallback: String) -> String {
        guard !path.isEmpty else { return fallback }
        var name = (path as NSString).lastPathComponent
        if name.hasSuffix(".app") { name.removeLast(4) }
        return name.isEmpty ? fallback : name
    }

    /// The app's identity in lists: its bundle, or its path for a program without one.
    var identity: String { bundleID.isEmpty ? path : bundleID }
}

/// A window's place captured on one display: relative to that display's
/// frame (AppKit orientation, origin bottom left), with the display's size
/// then, so another display can take it in proportion.
struct WorkspaceFrame: Codable, Equatable {
    var display: String
    var displaySize: CGSize
    var rect: CGRect
}

/// Where an app's front window goes: a Window Layout position, or a frame captured from the screen.
enum WorkspacePlacement: Equatable {
    case layout(WindowLayoutAction)
    case frame(WorkspaceFrame)

    /// The positions offered in the editor: every one that sets a frame on the
    /// window's own display. Moving between displays, centring, full screen
    /// and restoring are about the window as it is, not a place for it.
    static let layouts: [WindowLayoutAction] = WindowLayoutAction.allCases.filter {
        $0.targetCapability == .frame && $0 != .previousDisplay && $0 != .nextDisplay
    }
}

struct WorkspaceArrangement: Codable, Equatable {
    var app: WorkspaceApp
    var placement: WorkspacePlacement

    private enum CodingKeys: String, CodingKey { case app, layout, frame }

    init(app: WorkspaceApp, placement: WorkspacePlacement) {
        self.app = app
        self.placement = placement
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.decode(WorkspaceApp.self, forKey: .app)
        if let frame = try? c.decode(WorkspaceFrame.self, forKey: .frame) {
            placement = .frame(frame)
        } else {
            // A position a newer version named and this one does not know fills the screen.
            let raw = try c.decodeIfPresent(String.self, forKey: .layout) ?? ""
            placement = .layout(WindowLayoutAction(rawValue: raw).flatMap { WorkspacePlacement.layouts.contains($0) ? $0 : nil }
                                ?? .maximize)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(app, forKey: .app)
        switch placement {
        case .layout(let action): try c.encode(action.rawValue, forKey: .layout)
        case .frame(let frame): try c.encode(frame, forKey: .frame)
        }
    }
}

/// A sound output to switch to, by the device's stable UID, and a volume to set (0…1), each optional.
struct WorkspaceSound: Codable, Equatable {
    var uid: String
    var name: String
    var volume: Double?

    init(uid: String = "", name: String = "", volume: Double? = nil) {
        self.uid = uid
        self.name = name
        self.volume = volume.map { min(1, max(0, $0)) }
    }
}

/// What one step does.
enum WorkspaceAction: Equatable {
    case openApps([WorkspaceApp])
    case hideOthers
    case quitApps([WorkspaceApp])
    case arrange([WorkspaceArrangement])
    case keepAwake(Bool)
    /// Runs a Shortcut by name; macOS gives apps no Focus switch of their own.
    case focus(shortcut: String)
    case sound(WorkspaceSound)
    case wallpaper(path: String)
    case openURL(String)

    var kind: WorkspaceStep.Kind {
        switch self {
        case .openApps: return .openApps
        case .hideOthers: return .hideOthers
        case .quitApps: return .quitApps
        case .arrange: return .arrange
        case .keepAwake: return .keepAwake
        case .focus: return .focus
        case .sound: return .sound
        case .wallpaper: return .wallpaper
        case .openURL: return .openURL
        }
    }
}

struct WorkspaceStep: Identifiable, Equatable, Codable {
    /// Also the stored type name, so never renamed.
    enum Kind: String, CaseIterable {
        case openApps, hideOthers, quitApps, arrange, keepAwake, focus, sound, wallpaper, openURL

        var symbol: String {
            switch self {
            case .openApps: return "square.grid.2x2"
            case .hideOthers: return "eye.slash"
            case .quitApps: return "xmark.circle"
            case .arrange: return "rectangle.split.2x1"
            case .keepAwake: return "cup.and.saucer"
            case .focus: return "moon"
            case .sound: return "speaker.wave.2"
            case .wallpaper: return "photo"
            case .openURL: return "link"
            }
        }

        func title(_ text: ZenithWorkspacesStrings) -> String {
            switch self {
            case .openApps: return text.openApps
            case .hideOthers: return text.hideOthers
            case .quitApps: return text.quitApps
            case .arrange: return text.arrange
            case .keepAwake: return text.keepAwake
            case .focus: return text.focus
            case .sound: return text.sound
            case .wallpaper: return text.wallpaper
            case .openURL: return text.openURL
            }
        }

        /// A new, empty step of this kind.
        var blank: WorkspaceAction {
            switch self {
            case .openApps: return .openApps([])
            case .hideOthers: return .hideOthers
            case .quitApps: return .quitApps([])
            case .arrange: return .arrange([])
            case .keepAwake: return .keepAwake(true)
            case .focus: return .focus(shortcut: "")
            case .sound: return .sound(WorkspaceSound())
            case .wallpaper: return .wallpaper(path: "")
            case .openURL: return .openURL("")
            }
        }
    }

    var id: UUID
    var isEnabled: Bool
    var action: WorkspaceAction

    init(id: UUID = UUID(), isEnabled: Bool = true, _ action: WorkspaceAction) {
        self.id = id
        self.isEnabled = isEnabled
        self.action = action
    }

    var kind: Kind { action.kind }

    private enum CodingKeys: String, CodingKey { case id, on, type, apps, arrangements, flag, text, sound }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .on) ?? true
        let raw = try c.decode(String.self, forKey: .type)
        guard let kind = Kind(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "unknown step \(raw)")
        }
        let apps = (try? c.decode(WorkspaceLossyList<WorkspaceApp>.self, forKey: .apps))?.items ?? []
        let text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        switch kind {
        case .openApps: action = .openApps(apps)
        case .hideOthers: action = .hideOthers
        case .quitApps: action = .quitApps(apps)
        case .arrange:
            action = .arrange((try? c.decode(WorkspaceLossyList<WorkspaceArrangement>.self, forKey: .arrangements))?.items ?? [])
        case .keepAwake: action = .keepAwake(try c.decodeIfPresent(Bool.self, forKey: .flag) ?? true)
        case .focus: action = .focus(shortcut: text)
        case .sound: action = .sound((try? c.decode(WorkspaceSound.self, forKey: .sound)) ?? WorkspaceSound())
        case .wallpaper: action = .wallpaper(path: text)
        case .openURL: action = .openURL(text)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(isEnabled, forKey: .on)
        try c.encode(kind.rawValue, forKey: .type)
        switch action {
        case .openApps(let apps), .quitApps(let apps): try c.encode(apps, forKey: .apps)
        case .hideOthers: break
        case .arrange(let arrangements): try c.encode(arrangements, forKey: .arrangements)
        case .keepAwake(let on): try c.encode(on, forKey: .flag)
        case .focus(let name): try c.encode(name, forKey: .text)
        case .sound(let sound): try c.encode(sound, forKey: .sound)
        case .wallpaper(let path): try c.encode(path, forKey: .text)
        case .openURL(let link): try c.encode(link, forKey: .text)
        }
    }
}

struct Workspace: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var symbol: String
    var color: WorkspaceColor
    /// Off: kept, still runnable from Settings, but out of the Command Bar,
    /// the island and its shortcut. The examples ship off.
    var isEnabled: Bool
    /// One of the presets Zenith ships, until it is edited.
    var isExample: Bool
    /// A `GlobalShortcut.storageValue`, or empty for none.
    var shortcut: String
    var steps: [WorkspaceStep]

    init(id: UUID = UUID(), name: String, symbol: String = WorkspaceSymbols.fallback, color: WorkspaceColor = .blue,
         isEnabled: Bool = true, isExample: Bool = false, shortcut: String = "", steps: [WorkspaceStep] = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.color = color
        self.isEnabled = isEnabled
        self.isExample = isExample
        self.shortcut = shortcut
        self.steps = steps
    }

    private enum CodingKeys: String, CodingKey { case id, name, symbol, color, on, example, shortcut, steps }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try c.decodeIfPresent(String.self, forKey: .name) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        self.symbol = symbol.isEmpty ? WorkspaceSymbols.fallback : symbol
        color = (try? c.decode(WorkspaceColor.self, forKey: .color)) ?? .blue
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .on) ?? true
        isExample = try c.decodeIfPresent(Bool.self, forKey: .example) ?? false
        shortcut = try c.decodeIfPresent(String.self, forKey: .shortcut) ?? ""
        steps = (try? c.decode(WorkspaceLossyList<WorkspaceStep>.self, forKey: .steps))?.items ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(symbol, forKey: .symbol)
        try c.encode(color, forKey: .color)
        try c.encode(isEnabled, forKey: .on)
        if isExample { try c.encode(true, forKey: .example) }
        if !shortcut.isEmpty { try c.encode(shortcut, forKey: .shortcut) }
        try c.encode(steps, forKey: .steps)
    }

    /// The apps the workspace opens or arranges: never hidden or quit by its own steps.
    var ownBundleIDs: Set<String> {
        var ids = Set<String>()
        for step in steps where step.isEnabled {
            switch step.action {
            case .openApps(let apps): ids.formUnion(apps.map(\.bundleID))
            case .arrange(let arrangements): ids.formUnion(arrangements.map(\.app.bundleID))
            default: break
            }
        }
        ids.remove("")
        return ids
    }

    /// Steps that will run, in order.
    var runnableSteps: [WorkspaceStep] { steps.filter(\.isEnabled) }
}

/// Decodes what it can of a list and skips the rest, so one entry a newer
/// version wrote (an unknown step) never costs the whole list.
struct WorkspaceLossyList<Element: Decodable>: Decodable {
    let items: [Element]

    private struct Skip: Decodable {}

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [Element] = []
        while !container.isAtEnd {
            if let item = try? container.decode(Element.self) {
                items.append(item)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        self.items = items
    }
}

// MARK: - Editing

extension Workspace {
    /// Any edit makes an example the user's own.
    func edited(_ change: (inout Workspace) -> Void) -> Workspace {
        var copy = self
        change(&copy)
        if copy != self { copy.isExample = false }
        return copy
    }

    func addingStep(_ kind: WorkspaceStep.Kind, id: UUID = UUID()) -> Workspace {
        edited { $0.steps.append(WorkspaceStep(id: id, kind.blank)) }
    }

    func removingStep(_ id: UUID) -> Workspace {
        edited { $0.steps.removeAll { $0.id == id } }
    }

    /// Moves a step by `offset` places, clamped to the list.
    func movingStep(_ id: UUID, by offset: Int) -> Workspace {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return self }
        let target = min(max(0, index + offset), steps.count - 1)
        guard target != index else { return self }
        return edited { workspace in
            let step = workspace.steps.remove(at: index)
            workspace.steps.insert(step, at: target)
        }
    }

    func replacingStep(_ step: WorkspaceStep) -> Workspace {
        edited { workspace in
            guard let index = workspace.steps.firstIndex(where: { $0.id == step.id }) else { return }
            workspace.steps[index] = step
        }
    }
}

// MARK: - Storage

/// The workspaces as JSON in one registered default (so backups carry them):
/// `{"version":1,"workspaces":[…]}`. An empty value is a Mac that never
/// edited them, which shows the examples; the first save stores them for real.
enum WorkspaceLibrary {
    static let version = 1
    /// Global shortcuts are registered for this many at most.
    static let maximum = 32

    private struct Envelope: Codable {
        var version: Int
        var workspaces: [Workspace]

        init(version: Int, workspaces: [Workspace]) {
            self.version = version
            self.workspaces = workspaces
        }

        private enum CodingKeys: String, CodingKey { case version, workspaces }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
            workspaces = (try? c.decode(WorkspaceLossyList<Workspace>.self, forKey: .workspaces))?.items ?? []
        }
    }

    /// Reads the stored text. Version 0 was a bare list; newer versions are
    /// read as far as this one understands them.
    static func decode(_ raw: String) -> [Workspace] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return examples }
        guard let data = trimmed.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        let list: [Workspace]
        if trimmed.hasPrefix("[") {
            list = (try? decoder.decode(WorkspaceLossyList<Workspace>.self, from: data))?.items ?? []
        } else {
            list = (try? decoder.decode(Envelope.self, from: data))?.workspaces ?? []
        }
        var seen = Set<UUID>()
        return list.filter { seen.insert($0.id).inserted }
    }

    static func encode(_ workspaces: [Workspace]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Envelope(version: version, workspaces: workspaces)),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    static func load(from defaults: UserDefaults = .standard) -> [Workspace] {
        decode(defaults.string(forKey: DefaultsKey.zenithWorkspaces) ?? "")
    }

    static func save(_ workspaces: [Workspace], to defaults: UserDefaults = .standard) {
        let encoded = encode(workspaces)
        guard defaults.string(forKey: DefaultsKey.zenithWorkspaces) != encoded else { return }
        defaults.set(encoded, forKey: DefaultsKey.zenithWorkspaces)
    }

    // MARK: Examples

    static let codingID = UUID(uuidString: "6F1D0C52-7C0B-4E57-9A43-0D7E6C1A0001")!
    static let editingID = UUID(uuidString: "6F1D0C52-7C0B-4E57-9A43-0D7E6C1A0002")!

    /// Two presets for the owner's modes of work, off until edited and turned
    /// on: apps that are not installed are reported, never guessed.
    static var examples: [Workspace] {
        let code = WorkspaceApp(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code")
        let chrome = WorkspaceApp(bundleID: "com.google.Chrome", name: "Google Chrome")
        let terminal = WorkspaceApp(bundleID: "com.apple.Terminal", name: "Terminal")
        let claude = WorkspaceApp(bundleID: "com.anthropic.claudefordesktop", name: "Claude")
        let resolve = WorkspaceApp(bundleID: "com.blackmagic-design.DaVinciResolve", name: "DaVinci Resolve")
        let lightroom = WorkspaceApp(bundleID: "com.adobe.LightroomClassicCC7", name: "Adobe Lightroom Classic")
        let finder = WorkspaceApp(bundleID: "com.apple.finder", name: "Finder")
        func id(_ n: Int, _ workspace: Int) -> UUID {
            func byte(_ value: Int) -> String {
                let hex = String(value, radix: 16, uppercase: true)
                return hex.count < 2 ? "0" + hex : hex
            }
            return UUID(uuidString: "6F1D0C52-7C0B-4E57-9A43-0D7E6C1A" + byte(workspace) + byte(n))!
        }
        let coding = Workspace(id: codingID, name: "Coding", symbol: "chevron.left.forwardslash.chevron.right",
                               color: .blue, isEnabled: false, isExample: true, steps: [
            WorkspaceStep(id: id(1, 1), .openApps([code, chrome, terminal, claude])),
            WorkspaceStep(id: id(2, 1), .hideOthers),
            WorkspaceStep(id: id(3, 1), .arrange([
                WorkspaceArrangement(app: code, placement: .layout(.leftTwoThirds)),
                WorkspaceArrangement(app: chrome, placement: .layout(.rightThird)),
            ])),
            WorkspaceStep(id: id(4, 1), .keepAwake(true)),
            WorkspaceStep(id: id(5, 1), isEnabled: false, .focus(shortcut: "Coding Focus")),
        ])
        let editing = Workspace(id: editingID, name: "Editing", symbol: "film", color: .violet,
                                isEnabled: false, isExample: true, steps: [
            WorkspaceStep(id: id(1, 2), .openApps([resolve, lightroom, finder])),
            WorkspaceStep(id: id(2, 2), .hideOthers),
            WorkspaceStep(id: id(3, 2), .arrange([
                WorkspaceArrangement(app: resolve, placement: .layout(.maximize)),
            ])),
            WorkspaceStep(id: id(4, 2), .keepAwake(true)),
            WorkspaceStep(id: id(5, 2), isEnabled: false, .focus(shortcut: "Editing Focus")),
        ])
        return [coding, editing]
    }
}

// MARK: - Running

/// Why part of a step did not happen. Each names what it was about.
enum WorkspaceProblem: Equatable {
    case appMissing(String)
    case openFailed(String)
    case notRunning(String)
    case noWindow(String)
    case needsAccessibility
    case quitFailed(String)
    case shortcutFailed(String)
    case keepAwakeUnavailable
    case outputMissing(String)
    case wallpaperFailed
    case linkFailed(String)

    func text(_ s: ZenithWorkspacesStrings) -> String {
        switch self {
        case .appMissing(let name): return s.format(s.notFoundFormat, name)
        case .openFailed(let name): return s.format(s.openFailedFormat, name)
        case .notRunning(let name): return s.format(s.notRunningFormat, name)
        case .noWindow(let name): return s.format(s.noWindowFormat, name)
        case .needsAccessibility: return s.needsAccessibility
        case .quitFailed(let name): return s.format(s.quitFailedFormat, name)
        case .shortcutFailed(let name): return s.format(s.shortcutFailedFormat, name)
        case .keepAwakeUnavailable: return s.keepAwakeUnavailable
        case .outputMissing(let name): return s.format(s.outputMissingFormat, name)
        case .wallpaperFailed: return s.wallpaperFailed
        case .linkFailed(let link): return s.format(s.linkFailedFormat, link)
        }
    }
}

/// Carries out one step on the Mac (or, in the tests, pretends to) and says
/// what went wrong; an empty list is a step done. It runs off the main thread
/// and may wait.
protocol WorkspacePerforming: AnyObject {
    func perform(_ action: WorkspaceAction, in workspace: Workspace) -> [WorkspaceProblem]
}

struct WorkspaceRunReport: Equatable {
    let workspaceID: UUID
    let name: String
    /// The steps that ran, in order.
    let ran: [WorkspaceStep.Kind]
    let problems: [WorkspaceProblem]

    var succeeded: Bool { problems.isEmpty }
}

enum WorkspaceRunner {
    /// Runs the enabled steps in their order. A step's problems are kept and
    /// the next step runs anyway; `shouldContinue` stops between steps.
    static func run(_ workspace: Workspace, with performer: WorkspacePerforming,
                    shouldContinue: () -> Bool = { true }) -> WorkspaceRunReport {
        var ran: [WorkspaceStep.Kind] = []
        var problems: [WorkspaceProblem] = []
        for step in workspace.runnableSteps {
            guard shouldContinue() else { break }
            ran.append(step.kind)
            for problem in performer.perform(step.action, in: workspace) where !problems.contains(problem) {
                problems.append(problem)
            }
        }
        return WorkspaceRunReport(workspaceID: workspace.id, name: workspace.name, ran: ran, problems: problems)
    }
}

enum WorkspaceFormat {
    /// What the capsule notice says: "Coding workspace ready" over
    /// "Everything is in place", or over what went wrong, two at most and the count of the rest.
    static func notice(_ report: WorkspaceRunReport, text: ZenithWorkspacesStrings) -> (title: String, subtitle: String) {
        let name = displayName(report.name, text: text)
        guard !report.succeeded else { return (text.format(text.readyFormat, name), text.allDone) }
        var parts = report.problems.prefix(2).map { $0.text(text) }
        if report.problems.count > 2 { parts.append(text.format(text.moreFormat, report.problems.count - 2)) }
        return (text.format(text.issuesFormat, name), parts.joined(separator: " · "))
    }

    /// "Workspace: Coding", the Command Bar's row.
    static func commandTitle(_ name: String, text: ZenithWorkspacesStrings) -> String {
        text.format(text.commandFormat, displayName(name, text: text))
    }

    static func displayName(_ name: String, text: ZenithWorkspacesStrings) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text.untitled : trimmed
    }
}

/// `/usr/bin/shortcuts run "<name>"`, the one public way to reach a Focus.
/// The name goes to the process as one argument, so nothing is parsed by a
/// shell; `displayed` quotes it for the line Settings shows.
enum WorkspaceShortcutsCommand {
    static let path = "/usr/bin/shortcuts"
    static let timeout: TimeInterval = 30

    static func arguments(_ name: String) -> [String]? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\0") else { return nil }
        return ["run", trimmed]
    }

    /// The command as it would be typed in a terminal, single-quoted.
    static func displayed(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = "'" + trimmed.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "shortcuts run " + quoted
    }
}

/// A link or a file the step opens: a URL with a scheme, or a path (with `~`).
enum WorkspaceTarget {
    static func url(_ text: String, home: String = NSHomeDirectory()) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            let expanded = trimmed == "~" ? home
                : trimmed.hasPrefix("~/") ? home + String(trimmed.dropFirst(1)) : trimmed
            return URL(fileURLWithPath: expanded)
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty else {
            // "example.com" means the web page.
            if trimmed.contains("."), !trimmed.contains(" "), let web = URL(string: "https://" + trimmed) { return web }
            return nil
        }
        return url
    }
}

// MARK: - Hiding and quitting

/// A running app, as the plans see it.
struct WorkspaceRunningApp: Equatable {
    let pid: Int32
    let bundleID: String?
    /// `NSApplication.ActivationPolicy.rawValue`: 0 is a regular app with a Dock icon.
    let activationPolicy: Int
    let isTerminated: Bool
    var isHidden = false
}

enum WorkspacePlans {
    /// Zenith itself, by every name it has gone by.
    static func zenithIDs(own: String?) -> Set<String> {
        var ids = Set(QuickTogglesSupport.vorssaintBundleIdentifiers)
        if let own { ids.insert(own) }
        return ids
    }

    /// Hide others: every regular app showing that the workspace does not
    /// open or arrange, never Zenith.
    static func hideTargets(_ running: [WorkspaceRunningApp], keeping: Set<String>) -> [Int32] {
        running.filter { app in
            guard app.activationPolicy == 0, !app.isTerminated, !app.isHidden else { return false }
            guard let id = app.bundleID else { return true }
            return !keeping.contains(id)
        }.map(\.pid)
    }

    /// Quit: the listed apps that are running, as Quit Apps decides them (a
    /// regular app, not Zenith, not Finder or Phone, not one of its
    /// exceptions), and never an app the workspace itself opens.
    static func quitTargets(_ listed: [WorkspaceApp], running: [WorkspaceRunningApp],
                            exceptions: [String], keeping: Set<String>) -> [Int32] {
        let wanted = Set(listed.map(\.bundleID)).subtracting(keeping).subtracting([""])
        let kept = Set(QuickTogglesSupport.sanitizedQuitAllExceptions(exceptions))
        return running.filter { app in
            guard let id = app.bundleID, wanted.contains(id) else { return false }
            return QuickTogglesSupport.shouldQuitApp(bundleIdentifier: id, activationPolicyRawValue: app.activationPolicy,
                                                     isTerminated: app.isTerminated, exceptions: kept)
        }.map(\.pid)
    }
}

// MARK: - Capture

/// A display as the capture and the arrangement see it, in AppKit coordinates.
struct WorkspaceDisplay: Equatable {
    /// A stable identifier for the display (its UUID), which survives reconnects.
    let id: String
    let frame: CGRect
    let visibleFrame: CGRect
    let isMain: Bool
}

/// A regular app running now, with its front window's frame when Accessibility could read it.
struct WorkspaceCapturedApp: Equatable {
    let bundleID: String
    let name: String
    let path: String
    let frame: CGRect?
}

enum WorkspaceCapture {
    /// "Capture Current": opens the apps running now, and puts their front
    /// windows back where they are, display by display.
    static func workspace(named name: String, apps: [WorkspaceCapturedApp], displays: [WorkspaceDisplay],
                          excluding: Set<String>, id: UUID = UUID(), stepIDs: (UUID, UUID) = (UUID(), UUID())) -> Workspace {
        var seen = Set<String>()
        let kept = apps.filter { !$0.bundleID.isEmpty && !excluding.contains($0.bundleID) && seen.insert($0.bundleID).inserted }
        let refs = kept.map { WorkspaceApp(bundleID: $0.bundleID, name: $0.name, path: $0.path) }
        var steps = [WorkspaceStep(id: stepIDs.0, .openApps(refs))]
        let arrangements = zip(kept, refs).compactMap { captured, app -> WorkspaceArrangement? in
            guard let rect = captured.frame, let frame = frame(for: rect, displays: displays) else { return nil }
            return WorkspaceArrangement(app: app, placement: .frame(frame))
        }
        if !arrangements.isEmpty { steps.append(WorkspaceStep(id: stepIDs.1, .arrange(arrangements))) }
        return Workspace(id: id, name: name, symbol: WorkspaceSymbols.fallback, color: .teal, steps: steps)
    }

    /// The display a window is mostly on, and the window relative to it.
    static func frame(for rect: CGRect, displays: [WorkspaceDisplay]) -> WorkspaceFrame? {
        guard rect.width > 0, rect.height > 0, !displays.isEmpty else { return nil }
        func overlap(_ display: WorkspaceDisplay) -> CGFloat {
            let shared = display.frame.intersection(rect)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        let best = displays.max { overlap($0) < overlap($1) }!
        let display = overlap(best) > 0 ? best : nearest(to: CGPoint(x: rect.midX, y: rect.midY), in: displays)
        let relative = rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        return WorkspaceFrame(display: display.id, displaySize: display.frame.size, rect: relative)
    }

    /// Where a captured frame goes now: on its display when it is connected,
    /// otherwise on the main display in proportion; kept within the visible
    /// area either way.
    static func resolve(_ frame: WorkspaceFrame, displays: [WorkspaceDisplay]) -> CGRect? {
        guard !displays.isEmpty else { return nil }
        var rect = frame.rect
        let display: WorkspaceDisplay
        if let same = displays.first(where: { $0.id == frame.display }) {
            display = same
        } else {
            display = displays.first(where: \.isMain) ?? displays[0]
            let sx = frame.displaySize.width > 0 ? display.frame.width / frame.displaySize.width : 1
            let sy = frame.displaySize.height > 0 ? display.frame.height / frame.displaySize.height : 1
            rect = CGRect(x: rect.minX * sx, y: rect.minY * sy, width: rect.width * sx, height: rect.height * sy)
        }
        rect = rect.offsetBy(dx: display.frame.minX, dy: display.frame.minY)
        return clamped(rect, to: display.visibleFrame)
    }

    static func clamped(_ rect: CGRect, to visible: CGRect) -> CGRect {
        guard visible.width > 0, visible.height > 0 else { return rect.integral }
        let width = min(rect.width, visible.width)
        let height = min(rect.height, visible.height)
        let x = min(max(rect.minX, visible.minX), visible.maxX - width)
        let y = min(max(rect.minY, visible.minY), visible.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private static func nearest(to point: CGPoint, in displays: [WorkspaceDisplay]) -> WorkspaceDisplay {
        displays.min { distance(point, $0.frame) < distance(point, $1.frame) }!
    }

    private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}

// MARK: - Settings search

/// What finds the Workspaces page in Settings search and the Command Bar.
enum ZenithWorkspacesSearch {
    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.workspaces(language)
        return [text.kind, text.capture, text.runNow] + WorkspaceStep.Kind.allCases.map { $0.title(text) }
            + ["workspace", "preset", "mode", "Focus", "Shortcuts"]
    }
}

// MARK: - Window placement

enum WorkspaceGeometry {
    /// The display a window belongs to: the one it covers most, else the main one.
    static func display(for window: CGRect, in displays: [WorkspaceDisplay]) -> WorkspaceDisplay? {
        guard !displays.isEmpty else { return nil }
        func overlap(_ display: WorkspaceDisplay) -> CGFloat {
            let shared = display.frame.intersection(window)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        let best = displays.max { overlap($0) < overlap($1) }!
        return overlap(best) > 0 ? best : (displays.first(where: \.isMain) ?? displays[0])
    }

    /// AppKit's frame (origin bottom left of the main display) as
    /// Accessibility's (origin top left), and back; `top` is the main display's maxY.
    static func axRect(fromAppKit rect: CGRect, top: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
    }

    static func appKitRect(fromAX rect: CGRect, top: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: top - rect.minY - rect.height, width: rect.width, height: rect.height)
    }
}
