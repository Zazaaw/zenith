// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: workspaces (WorkspaceSupport): the model through JSON and
/// its migration, the examples, editing and step order, the runner over a
/// fake performer (a failing step never stops the rest, and the notice says
/// what failed), the Shortcuts command, links and paths, the capture of the
/// current windows and their way back to a display, hiding and quitting,
/// backups, the notice kind and the strings. No app is launched or quit.
enum WorkspacesTests {
    static func run(_ suite: TestSuite) {
        roundTrip(suite)
        migration(suite)
        examples(suite)
        editing(suite)
        runner(suite)
        summary(suite)
        shortcutsCommand(suite)
        targets(suite)
        capture(suite)
        plans(suite)
        geometry(suite)
        backup(suite)
        notice(suite)
        strings(suite)
    }

    private static let suiteName = "com.vorssaint.tests.workspaces"
    private static let text = ZenithStrings.workspaces(.enUS)

    private static func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static let code = WorkspaceApp(bundleID: "com.microsoft.VSCode", name: "Visual Studio Code",
                                           path: "/Applications/Visual Studio Code.app", target: "~/Developer/zenith")
    private static let chrome = WorkspaceApp(bundleID: "com.google.Chrome", name: "Google Chrome", target: "https://p441z.my.id")

    /// A workspace with one step of every kind.
    private static let everything: Workspace = {
        Workspace(name: "Everything", symbol: "terminal", color: .amber, isEnabled: true, shortcut: "control+option:18", steps: [
            WorkspaceStep(.openApps([code, chrome])),
            WorkspaceStep(.hideOthers),
            WorkspaceStep(isEnabled: false, .quitApps([WorkspaceApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack")])),
            WorkspaceStep(.arrange([
                WorkspaceArrangement(app: code, placement: .layout(.leftTwoThirds)),
                WorkspaceArrangement(app: chrome, placement: .frame(WorkspaceFrame(display: "D1", displaySize: CGSize(width: 1512, height: 982),
                                                                                    rect: CGRect(x: 1008, y: 0, width: 504, height: 950)))),
            ])),
            WorkspaceStep(.keepAwake(false)),
            WorkspaceStep(.focus(shortcut: "Coding Focus")),
            WorkspaceStep(.sound(WorkspaceSound(uid: "BuiltInSpeakerDevice", name: "MacBook Pro Speakers", volume: 0.4))),
            WorkspaceStep(.wallpaper(path: "/System/Library/Desktop Pictures/Sonoma.heic")),
            WorkspaceStep(.openURL("https://github.com/satuvisual/zenith")),
        ])
    }()

    private static func roundTrip(_ suite: TestSuite) {
        let list = [everything] + WorkspaceLibrary.examples
        let encoded = WorkspaceLibrary.encode(list)
        suite.expect(encoded.hasPrefix("{") && encoded.contains("\"version\":1"),
                     "workspaces are stored in a versioned envelope")
        suite.expect(WorkspaceLibrary.decode(encoded) == list,
                     "every step, placement, sound and flag survives a round trip through JSON")
        suite.expect(WorkspaceLibrary.encode(WorkspaceLibrary.decode(encoded)) == encoded,
                     "encoding is stable, so a save without a change writes the same text")
        suite.expect(Set(WorkspaceStep.Kind.allCases.map(\.rawValue)).count == WorkspaceStep.Kind.allCases.count
                     && everything.steps.map(\.kind) == WorkspaceStep.Kind.allCases,
                     "the fixture covers every kind of step")
        suite.expect(WorkspaceSound(volume: 1.7).volume == 1 && WorkspaceSound(volume: -1).volume == 0,
                     "a volume is kept between silent and full")
    }

    private static func migration(_ suite: TestSuite) {
        // Version 0 was a bare list, with fewer fields than now.
        let legacy = """
        [{"name":" Coding ","steps":[{"type":"openApps","apps":[{"bundle":"com.apple.Terminal"},{"name":"nothing"}]},
          {"type":"teleport"},{"type":"keepAwake"},{"type":"arrange","arrangements":[{"app":{"bundle":"com.apple.Terminal"},"layout":"sideways"}]}]}]
        """
        let migrated = WorkspaceLibrary.decode(legacy)
        let first = migrated.first
        suite.expect(migrated.count == 1 && first?.name == "Coding" && first?.isEnabled == true
                     && first?.symbol == WorkspaceSymbols.fallback && first?.color == .blue
                     && first?.shortcut == "" && first?.isExample == false,
                     "a version 0 list reads with every missing field at its default")
        suite.expect(first?.steps.map(\.kind) == [.openApps, .keepAwake, .arrange],
                     "an unknown step is skipped and the rest keep their order")
        if case .openApps(let apps) = first?.steps.first?.action {
            suite.expect(apps.count == 1 && apps[0].name == "com.apple.Terminal" && apps[0].bundleID == "com.apple.Terminal",
                         "an app with neither bundle nor path is dropped, and a nameless one is named by its bundle")
        } else {
            suite.expect(false, "the migrated open step reads")
        }
        if let step = first?.steps.dropFirst().first, case .keepAwake(let on) = step.action {
            suite.expect(on && step.isEnabled, "a Keep Awake step without its flag turns Keep Awake on")
        } else {
            suite.expect(false, "the migrated Keep Awake step reads")
        }
        if case .arrange(let arrangements) = first?.steps.last?.action {
            suite.expect(arrangements.first?.placement == .layout(.maximize),
                         "a position this version does not know fills the screen")
        } else {
            suite.expect(false, "the migrated arrange step reads")
        }
        let future = """
        {"version":7,"later":true,"workspaces":[{"id":"6F1D0C52-7C0B-4E57-9A43-0D7E6C1AFFFF","name":"New","color":"ultraviolet",
          "steps":[],"sparkle":1},{"id":"6F1D0C52-7C0B-4E57-9A43-0D7E6C1AFFFF","name":"Twin"}]}
        """
        let ahead = WorkspaceLibrary.decode(future)
        suite.expect(ahead.count == 1 && ahead[0].name == "New" && ahead[0].color == .blue,
                     "a newer version reads as far as this one understands, an unknown colour turns blue, a repeated id once")
        suite.expect(WorkspaceLibrary.decode("").count == 2 && WorkspaceLibrary.decode("  \n") == WorkspaceLibrary.examples,
                     "a Mac that never edited them sees the examples")
        suite.expect(WorkspaceLibrary.decode("not json").isEmpty && WorkspaceLibrary.decode("{\"version\":1}").isEmpty,
                     "unreadable text is no workspaces, never the examples again")
        suite.expect(WorkspaceLibrary.decode(WorkspaceLibrary.encode([])).isEmpty,
                     "deleting every workspace stays deleted")
    }

    private static func examples(_ suite: TestSuite) {
        let list = WorkspaceLibrary.examples
        suite.expect(list.map(\.name) == ["Coding", "Editing"] && list.allSatisfy { !$0.isEnabled && $0.isExample },
                     "Coding and Editing ship as examples, off until edited")
        suite.expect(list.map(\.id) == [WorkspaceLibrary.codingID, WorkspaceLibrary.editingID]
                     && WorkspaceLibrary.examples == list
                     && Set(list.flatMap { $0.steps.map(\.id) }).count == list.reduce(0) { $0 + $1.steps.count },
                     "the examples and their steps keep the same ids on every read")
        let coding = list[0]
        suite.expect(coding.ownBundleIDs == ["com.microsoft.VSCode", "com.google.Chrome", "com.apple.Terminal",
                                             "com.anthropic.claudefordesktop"],
                     "Coding opens VS Code, Chrome, Terminal and Claude")
        if case .arrange(let arrangements) = coding.steps.first(where: { $0.kind == .arrange })?.action {
            suite.expect(arrangements.map(\.placement) == [.layout(.leftTwoThirds), .layout(.rightThird)],
                         "Coding puts VS Code on the left two thirds and Chrome on the right third")
        } else {
            suite.expect(false, "Coding arranges its windows")
        }
        suite.expect(list.allSatisfy { $0.steps.first { $0.kind == .focus }?.isEnabled == false },
                     "the Focus step waits off until its Shortcut exists")
        let turnedOn = coding.edited { $0.isEnabled = true }
        suite.expect(!turnedOn.isExample && turnedOn.isEnabled && coding.edited { _ in }.isExample,
                     "an edit makes an example the user's own; no edit leaves it an example")
    }

    private static func editing(_ suite: TestSuite) {
        let ids = (0..<3).map { _ in UUID() }
        var workspace = Workspace(name: "Order", steps: [
            WorkspaceStep(id: ids[0], .openApps([])), WorkspaceStep(id: ids[1], .hideOthers), WorkspaceStep(id: ids[2], .keepAwake(true)),
        ])
        workspace = workspace.movingStep(ids[2], by: -1)
        suite.expect(workspace.steps.map(\.id) == [ids[0], ids[2], ids[1]], "a step moves up one place")
        workspace = workspace.movingStep(ids[0], by: -5)
        suite.expect(workspace.steps.map(\.id) == [ids[0], ids[2], ids[1]], "moving the first step up is clamped")
        workspace = workspace.movingStep(ids[0], by: 9)
        suite.expect(workspace.steps.map(\.id) == [ids[2], ids[1], ids[0]], "a step moves to the end at most")
        let added = UUID()
        workspace = workspace.addingStep(.focus, id: added)
        suite.expect(workspace.steps.last?.id == added && workspace.steps.last?.action == .focus(shortcut: ""),
                     "a new step comes last and empty")
        workspace = workspace.removingStep(ids[1])
        suite.expect(workspace.steps.map(\.id) == [ids[2], ids[0], added], "removing a step keeps the others in order")
        var replaced = workspace.steps[0]
        replaced.isEnabled = false
        suite.expect(workspace.replacingStep(replaced).steps[0].isEnabled == false
                     && workspace.replacingStep(replaced).runnableSteps.map(\.id) == [ids[0], added],
                     "a step switched off is kept but does not run")
        suite.expect(WorkspacePlacement.layouts.contains(.leftTwoThirds) && WorkspacePlacement.layouts.contains(.maximize)
                     && !WorkspacePlacement.layouts.contains(.nextDisplay) && !WorkspacePlacement.layouts.contains(.restore)
                     && !WorkspacePlacement.layouts.contains(.center) && !WorkspacePlacement.layouts.contains(.fullScreen),
                     "the positions offered are Window Layout's that place a window on its display")
    }

    /// Records the steps it is asked for and fails the ones it is told to.
    private final class FakePerformer: WorkspacePerforming {
        var performed: [WorkspaceStep.Kind] = []
        var failing: [WorkspaceStep.Kind: [WorkspaceProblem]] = [:]

        func perform(_ action: WorkspaceAction, in workspace: Workspace) -> [WorkspaceProblem] {
            performed.append(action.kind)
            return failing[action.kind] ?? []
        }
    }

    private static func runner(_ suite: TestSuite) {
        let workspace = everything
        let fake = FakePerformer()
        let report = WorkspaceRunner.run(workspace, with: fake)
        let expected: [WorkspaceStep.Kind] = [.openApps, .hideOthers, .arrange, .keepAwake, .focus, .sound, .wallpaper, .openURL]
        suite.expect(fake.performed == expected && report.ran == expected && report.succeeded,
                     "enabled steps run in their order and a step switched off is skipped")

        let failing = FakePerformer()
        failing.failing = [.openApps: [.appMissing("DaVinci Resolve"), .openFailed("Figma")],
                           .arrange: [.needsAccessibility], .focus: [.shortcutFailed("Coding Focus")],
                           .wallpaper: [.appMissing("DaVinci Resolve")]]
        let partial = WorkspaceRunner.run(workspace, with: failing)
        suite.expect(failing.performed == expected,
                     "a step that fails never stops the steps after it")
        suite.expect(partial.problems == [.appMissing("DaVinci Resolve"), .openFailed("Figma"), .needsAccessibility,
                                          .shortcutFailed("Coding Focus")] && !partial.succeeded,
                     "every problem is kept once, in the order it happened")

        let stopping = FakePerformer()
        var allowed = 2
        let stopped = WorkspaceRunner.run(workspace, with: stopping) {
            allowed -= 1
            return allowed >= 0
        }
        suite.expect(stopped.ran == [.openApps, .hideOthers] && stopping.performed == [.openApps, .hideOthers],
                     "a run told to stop stops between steps")
        let empty = WorkspaceRunner.run(Workspace(name: "Nothing"), with: FakePerformer())
        suite.expect(empty.ran.isEmpty && empty.succeeded, "a workspace without steps is ready at once")
    }

    private static func summary(_ suite: TestSuite) {
        let ok = WorkspaceRunReport(workspaceID: UUID(), name: "Coding", ran: [.openApps], problems: [])
        let notice = WorkspaceFormat.notice(ok, text: text)
        suite.expect(notice.title == "Coding workspace ready" && notice.subtitle == "Everything is in place",
                     "a run without problems reads “Coding workspace ready”")
        let two = WorkspaceRunReport(workspaceID: UUID(), name: "Editing", ran: [.openApps, .focus],
                                     problems: [.appMissing("DaVinci Resolve"), .shortcutFailed("Editing Focus")])
        let twoNotice = WorkspaceFormat.notice(two, text: text)
        suite.expect(twoNotice.title == "Editing workspace ran with problems"
                     && twoNotice.subtitle == "DaVinci Resolve not found · Shortcut “Editing Focus” failed",
                     "a run with problems lists them")
        let many = WorkspaceRunReport(workspaceID: UUID(), name: " ", ran: [],
                                      problems: [.needsAccessibility, .keepAwakeUnavailable, .wallpaperFailed, .linkFailed("x")])
        let manyNotice = WorkspaceFormat.notice(many, text: text)
        suite.expect(manyNotice.title == "Untitled workspace ran with problems"
                     && manyNotice.subtitle == "Arranging windows needs Accessibility · Keep awake is off in Features · +2 more",
                     "two problems are named and the rest counted; a blank name reads Untitled")
        suite.expect(WorkspaceFormat.commandTitle("Coding", text: text) == "Workspace: Coding",
                     "the Command Bar row reads “Workspace: Coding”")
        let problems: [WorkspaceProblem] = [.appMissing("A"), .openFailed("A"), .notRunning("A"), .noWindow("A"),
                                            .needsAccessibility, .quitFailed("A"), .shortcutFailed("A"), .keepAwakeUnavailable,
                                            .outputMissing("A"), .wallpaperFailed, .linkFailed("A")]
        for language in AppLanguage.allCases {
            let words = ZenithStrings.workspaces(language)
            let texts = problems.map { $0.text(words) }
            suite.expect(texts.allSatisfy { !$0.isEmpty && !$0.contains("%@") } && Set(texts).count == texts.count,
                         "every problem has its own words in \(language)")
            let filled = WorkspaceFormat.notice(many, text: words)
            suite.expect(!filled.title.contains("%@") && !filled.subtitle.contains("%d") && filled.subtitle.contains("2"),
                         "the notice fills its name and count in \(language)")
        }
    }

    private static func shortcutsCommand(_ suite: TestSuite) {
        suite.expect(WorkspaceShortcutsCommand.path == "/usr/bin/shortcuts"
                     && WorkspaceShortcutsCommand.arguments("  Coding Focus \n") == ["run", "Coding Focus"],
                     "the Shortcut runs by its trimmed name through /usr/bin/shortcuts run")
        suite.expect(WorkspaceShortcutsCommand.arguments("") == nil && WorkspaceShortcutsCommand.arguments("   ") == nil
                     && WorkspaceShortcutsCommand.arguments("a\0b") == nil,
                     "an empty name or one with a NUL never runs")
        let hostile = "Focus\"; rm -rf ~ $(say hi) `id` 'x'"
        suite.expect(WorkspaceShortcutsCommand.arguments(hostile) == ["run", hostile],
                     "quotes, dollars and backticks reach the process as one literal argument, with no shell")
        suite.expect(WorkspaceShortcutsCommand.displayed("It's Focus") == "shortcuts run 'It'\\''s Focus'"
                     && WorkspaceShortcutsCommand.displayed("$(id)") == "shortcuts run '$(id)'",
                     "the command Settings shows is single-quoted with its quotes escaped")
    }

    private static func targets(_ suite: TestSuite) {
        let home = "/Users/zenith"
        suite.expect(WorkspaceTarget.url("~/Developer/zenith", home: home)?.path == "/Users/zenith/Developer/zenith"
                     && WorkspaceTarget.url("~", home: home)?.path == home
                     && WorkspaceTarget.url("/tmp/a b", home: home)?.isFileURL == true,
                     "a path opens as a file, with ~ for home")
        suite.expect(WorkspaceTarget.url("https://p441z.my.id")?.absoluteString == "https://p441z.my.id"
                     && WorkspaceTarget.url("figma://file/abc")?.scheme == "figma"
                     && WorkspaceTarget.url("github.com/satuvisual")?.absoluteString == "https://github.com/satuvisual",
                     "a link keeps its scheme, and a bare host is a web page")
        suite.expect(WorkspaceTarget.url("") == nil && WorkspaceTarget.url("just words") == nil,
                     "text that is neither a path nor a link opens nothing")
    }

    private static func capture(_ suite: TestSuite) {
        let laptop = WorkspaceDisplay(id: "LAPTOP", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                      visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949), isMain: true)
        let studio = WorkspaceDisplay(id: "STUDIO", frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
                                      visibleFrame: CGRect(x: 1512, y: 0, width: 2560, height: 1415), isMain: false)
        let displays = [laptop, studio]
        let onStudio = CGRect(x: 1512 + 100, y: 200, width: 1200, height: 900)
        let frame = WorkspaceCapture.frame(for: onStudio, displays: displays)
        suite.expect(frame?.display == "STUDIO" && frame?.rect == CGRect(x: 100, y: 200, width: 1200, height: 900)
                     && frame?.displaySize == CGSize(width: 2560, height: 1440),
                     "a window is stored on its display, relative to it")
        suite.expect(frame.flatMap { WorkspaceCapture.resolve($0, displays: displays) } == onStudio,
                     "a window goes back exactly where it was on the same display")
        let spanning = CGRect(x: 1300, y: 100, width: 600, height: 400)
        suite.expect(WorkspaceCapture.frame(for: spanning, displays: displays)?.display == "STUDIO",
                     "a window across two displays belongs to the one it covers most")
        let offscreen = CGRect(x: -900, y: 100, width: 400, height: 300)
        suite.expect(WorkspaceCapture.frame(for: offscreen, displays: displays)?.display == "LAPTOP",
                     "a window off every display belongs to the nearest")
        suite.expect(WorkspaceCapture.frame(for: .zero, displays: displays) == nil
                     && WorkspaceCapture.frame(for: onStudio, displays: []) == nil,
                     "no window or no display captures no frame")
        if let frame {
            let moved = WorkspaceCapture.resolve(frame, displays: [laptop])
            let sx: CGFloat = 1512.0 / 2560.0
            let sy: CGFloat = 982.0 / 1440.0
            let expected = CGRect(x: 100 * sx, y: 200 * sy, width: 1200 * sx, height: 900 * sy).integral
            suite.expect(moved == expected && moved.map { laptop.visibleFrame.contains($0) } == true,
                         "a window whose display is gone lands on the main display in proportion")
        }
        let tooTall = WorkspaceFrame(display: "LAPTOP", displaySize: laptop.frame.size, rect: CGRect(x: 1400, y: 900, width: 900, height: 2000))
        let clamped = WorkspaceCapture.resolve(tooTall, displays: displays)
        suite.expect(clamped.map { laptop.visibleFrame.contains($0) } == true && clamped?.height == laptop.visibleFrame.height,
                     "a frame that would hang off its display is kept within the visible area")

        let apps = [
            WorkspaceCapturedApp(bundleID: "com.apple.finder", name: "Finder", path: "/System/Library/CoreServices/Finder.app",
                                 frame: CGRect(x: 10, y: 10, width: 800, height: 500)),
            WorkspaceCapturedApp(bundleID: "id.satuvisual.zenith", name: "Zenith", path: "/Applications/Zenith.app", frame: nil),
            WorkspaceCapturedApp(bundleID: "com.google.Chrome", name: "Google Chrome", path: "/Applications/Google Chrome.app", frame: onStudio),
            WorkspaceCapturedApp(bundleID: "com.google.Chrome", name: "Google Chrome", path: "", frame: nil),
            WorkspaceCapturedApp(bundleID: "", name: "java", path: "/usr/bin/java", frame: nil),
            WorkspaceCapturedApp(bundleID: "com.apple.Terminal", name: "Terminal", path: "", frame: nil),
        ]
        let ids = (UUID(), UUID(), UUID())
        let captured = WorkspaceCapture.workspace(named: "Current Setup", apps: apps, displays: displays,
                                                  excluding: ["id.satuvisual.zenith"], id: ids.0, stepIDs: (ids.1, ids.2))
        suite.expect(captured.name == "Current Setup" && captured.id == ids.0 && captured.isEnabled && !captured.isExample
                     && captured.steps.map(\.id) == [ids.1, ids.2],
                     "a capture is a new workspace of its own, on, with an open step and an arrange step")
        if case .openApps(let opened) = captured.steps.first?.action {
            suite.expect(opened.map(\.bundleID) == ["com.apple.finder", "com.google.Chrome", "com.apple.Terminal"],
                         "it opens each running app once, in order, without Zenith or a program with no bundle")
        } else {
            suite.expect(false, "the capture opens apps")
        }
        if case .arrange(let arrangements) = captured.steps.last?.action {
            suite.expect(arrangements.map(\.app.bundleID) == ["com.apple.finder", "com.google.Chrome"]
                         && arrangements.last?.placement == .frame(frame!),
                         "only the windows that were read are placed, each on its display")
        } else {
            suite.expect(false, "the capture arranges windows")
        }
        let blind = WorkspaceCapture.workspace(named: "x", apps: [apps[5]], displays: displays, excluding: [])
        suite.expect(blind.steps.map(\.kind) == [.openApps],
                     "without Accessibility a capture opens the apps and places nothing")
    }

    private static func plans(_ suite: TestSuite) {
        let running = [
            WorkspaceRunningApp(pid: 1, bundleID: "com.microsoft.VSCode", activationPolicy: 0, isTerminated: false),
            WorkspaceRunningApp(pid: 2, bundleID: "com.tinyspeck.slackmacgap", activationPolicy: 0, isTerminated: false),
            WorkspaceRunningApp(pid: 3, bundleID: "id.satuvisual.zenith", activationPolicy: 0, isTerminated: false),
            WorkspaceRunningApp(pid: 4, bundleID: "com.apple.finder", activationPolicy: 0, isTerminated: false),
            WorkspaceRunningApp(pid: 5, bundleID: "com.apple.Spotlight", activationPolicy: 2, isTerminated: false),
            WorkspaceRunningApp(pid: 6, bundleID: "com.spotify.client", activationPolicy: 0, isTerminated: false, isHidden: true),
            WorkspaceRunningApp(pid: 7, bundleID: nil, activationPolicy: 0, isTerminated: false),
            WorkspaceRunningApp(pid: 8, bundleID: "com.apple.mail", activationPolicy: 0, isTerminated: true),
            WorkspaceRunningApp(pid: 9, bundleID: "com.vorssaint.utils", activationPolicy: 0, isTerminated: false),
        ]
        let zenith = WorkspacePlans.zenithIDs(own: "id.satuvisual.zenith")
        suite.expect(zenith.contains("id.satuvisual.zenith") && zenith.isSuperset(of: QuickTogglesSupport.vorssaintBundleIdentifiers),
                     "Zenith is known by every name it has gone by")
        let hide = WorkspacePlans.hideTargets(running, keeping: zenith.union(["com.microsoft.VSCode"]))
        suite.expect(hide == [2, 4, 7] || (hide == [2, 4, 7, 9] && !zenith.contains("com.vorssaint.utils")),
                     "hiding others leaves the workspace's apps, Zenith, background agents and hidden or closed apps alone")
        let listed = ["com.tinyspeck.slackmacgap", "com.microsoft.VSCode", "com.apple.finder", "com.apple.Spotlight",
                      "com.spotify.client", "com.apple.mail", "id.satuvisual.zenith"]
            .map { WorkspaceApp(bundleID: $0, name: $0) }
        let quit = WorkspacePlans.quitTargets(listed, running: running, exceptions: ["com.spotify.client"],
                                              keeping: ["com.microsoft.VSCode"])
        suite.expect(quit == [2],
                     "quitting asks only listed regular apps, never the workspace's own, Finder, Zenith, an exception or a closed app")
        suite.expect(WorkspacePlans.quitTargets([], running: running, exceptions: [], keeping: []).isEmpty,
                     "a quit step with no apps quits nothing")
    }

    private static func geometry(_ suite: TestSuite) {
        let rect = CGRect(x: 40, y: 120, width: 800, height: 600)
        let ax = WorkspaceGeometry.axRect(fromAppKit: rect, top: 982)
        suite.expect(ax == CGRect(x: 40, y: 262, width: 800, height: 600)
                     && WorkspaceGeometry.appKitRect(fromAX: ax, top: 982) == rect,
                     "AppKit and Accessibility frames convert both ways around the main display's top")
        let main = WorkspaceDisplay(id: "A", frame: CGRect(x: 0, y: 0, width: 100, height: 100), visibleFrame: .zero, isMain: true)
        let side = WorkspaceDisplay(id: "B", frame: CGRect(x: 100, y: 0, width: 100, height: 100), visibleFrame: .zero, isMain: false)
        suite.expect(WorkspaceGeometry.display(for: CGRect(x: 150, y: 10, width: 20, height: 20), in: [main, side])?.id == "B"
                     && WorkspaceGeometry.display(for: CGRect(x: 900, y: 900, width: 20, height: 20), in: [side, main])?.id == "A"
                     && WorkspaceGeometry.display(for: rect, in: []) == nil,
                     "a layout uses the display the window is on, else the main one")
    }

    private static func backup(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.zenithWorkspaces] as? String == "",
                     "the workspaces have a registered default, empty until edited")
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.zenithWorkspaces)
                     && !SettingsBackupSupport.machineStateKeys.contains(DefaultsKey.zenithWorkspaces),
                     "backups carry the workspaces")
        suite.expect(SettingsBackupSupport.valueLooksRight(DefaultsKey.zenithWorkspaces, WorkspaceLibrary.encode([everything]))
                     && !SettingsBackupSupport.valueLooksRight(DefaultsKey.zenithWorkspaces, 3),
                     "a restored backup's workspaces are text")
        let defaults = freshDefaults()
        suite.expect(WorkspaceLibrary.load(from: defaults) == WorkspaceLibrary.examples,
                     "a fresh Mac loads the examples")
        WorkspaceLibrary.save([everything], to: defaults)
        suite.expect(WorkspaceLibrary.load(from: defaults) == [everything], "saved workspaces load back")
        WorkspaceLibrary.save([], to: defaults)
        suite.expect(WorkspaceLibrary.load(from: defaults).isEmpty
                     && defaults.string(forKey: DefaultsKey.zenithWorkspaces)?.isEmpty == false,
                     "an empty list is stored as one, not as a Mac that never edited them")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func notice(_ suite: TestSuite) {
        suite.expect(ZenithNotice.Kind.workspace.priority == 3 && ZenithNoticeQueue.lifetime(.workspace) == 30
                     && ZenithNoticeTiming.duration(.workspace) == 6,
                     "a workspace's notice comes soon after it was asked for and stays long enough to read")
        suite.expect(ZenithNoticeKey.workspace("A") == "workspace.A" && ZenithNoticeKey.workspace("A") != ZenithNoticeKey.workspace("B"),
                     "running the same workspace again updates its notice in place")
        suite.expect(Set(WorkspaceColor.allCases.map(\.hex)).count == WorkspaceColor.allCases.count
                     && WorkspaceColor.allCases.allSatisfy { ZenithIslandPalette.color(hex: $0.hex) == ZenithIslandPalette.color(hex: $0.hex) },
                     "each workspace colour is its own")
        suite.expect(ZenithHomeWidget.workspaces.module == nil && ZenithHomeWidget.workspaces.isAvailable(modules: [])
                     && ZenithHomeLayout.automatic != ZenithHomeWidget.workspaces.rawValue,
                     "the home widget stands alone, without a page of its own")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let words = ZenithStrings.workspaces(language)
            let all = Mirror(reflecting: words).children.compactMap { $0.value as? String }
            suite.expect(all.count > 70 && all.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                         "every workspace text is filled in \(language)")
            suite.expect(all.allSatisfy { !$0.contains("'") && !$0.contains("\u{2014}") },
                         "workspace text uses curly apostrophes and no em dash in \(language)")
            let formats = [words.commandFormat, words.readyFormat, words.issuesFormat, words.notFoundFormat, words.openFailedFormat,
                           words.notRunningFormat, words.noWindowFormat, words.quitFailedFormat, words.shortcutFailedFormat,
                           words.outputMissingFormat, words.linkFailedFormat]
            suite.expect(formats.allSatisfy { $0.components(separatedBy: "%@").count == 2 }
                         && words.moreFormat.components(separatedBy: "%d").count == 2,
                         "each format names its value once in \(language)")
            suite.expect(Set(WorkspaceStep.Kind.allCases.map { $0.title(words) }).count == WorkspaceStep.Kind.allCases.count
                         && Set(WorkspaceColor.allCases.map { $0.title(words) }).count == WorkspaceColor.allCases.count,
                         "steps and colours have names of their own in \(language)")
            suite.expect(ZenithWorkspacesSearch.keywords(language).contains(words.kind),
                         "Settings search finds the page in \(language)")
        }
    }
}
