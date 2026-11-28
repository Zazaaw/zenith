// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: Privacy Blur's decisions. The parts of a window each region
/// covers for each app, what the pointer, a held key and typing reveal,
/// which windows get a pane and when a pane is out of place, when the blur
/// is up, the chosen apps and the preferences. No window, observer or monitor.
enum PrivacyBlurTests {
    static func run(_ suite: TestSuite) {
        regionChoice(suite)
        pieces(suite)
        presets(suite)
        revealing(suite)
        holdKey(suite)
        placement(suite)
        ordering(suite)
        activation(suite)
        apps(suite)
        preferences(suite)
        words(suite)
    }

    private static let wide = CGSize(width: 1200, height: 800)

    private static func union(_ pieces: [PrivacyBlurPiece]) -> CGRect {
        pieces.map(\.rect).reduce(CGRect.null) { $0.union($1) }
    }

    private static func area(_ pieces: [PrivacyBlurPiece]) -> CGFloat {
        pieces.reduce(0) { $0 + $1.rect.width * $1.rect.height }
    }

    private static func regionChoice(_ suite: TestSuite) {
        suite.expect(PrivacyBlurRegion.choice(nil) == [.everything] && PrivacyBlurRegion.choice([]) == [.everything]
                        && PrivacyBlurRegion.choice(["nonsense"]) == [.everything],
                     "nothing stored, or nothing known, blurs everything")
        suite.expect(PrivacyBlurRegion.choice(["chatList", "everything"]) == [.everything],
                     "Everything wins over the parts beside it")
        suite.expect(PrivacyBlurRegion.choice(["messages", "names"]) == [.messages, .names], "the parts are read")
        let start: Set<PrivacyBlurRegion> = [.everything]
        let list = PrivacyBlurRegion.toggled(start, .chatList)
        suite.expect(list == [.chatList], "choosing a part leaves Everything")
        let both = PrivacyBlurRegion.toggled(list, .messages)
        suite.expect(both == [.chatList, .messages], "parts combine")
        suite.expect(PrivacyBlurRegion.toggled(both, .everything) == [.everything], "Everything stands alone")
        suite.expect(PrivacyBlurRegion.toggled([.chatList], .chatList) == [.everything],
                     "taking the last part away leaves Everything, never nothing")
        suite.expect(PrivacyBlurRegion.stored([.names, .chatList]) == ["chatList", "names"], "stored in a fixed order")
    }

    private static func pieces(_ suite: TestSuite) {
        let layout = PrivacyBlurPreset.whatsApp.layout
        let everything = PrivacyBlurRegions.pieces([.everything], layout: layout, size: wide)
        suite.expect(everything.count == 2 && union(everything) == CGRect(origin: .zero, size: wide)
                        && area(everything) == wide.width * wide.height,
                     "Everything covers the window exactly, in two panes")
        suite.expect(everything.first?.rect.maxX == layout.listEdge, "Everything splits at the chat list's edge")
        suite.expect(PrivacyBlurRegions.pieces([], layout: layout, size: wide) == everything,
                     "an empty choice is Everything")

        let list = PrivacyBlurRegions.pieces([.chatList], layout: layout, size: wide)
        suite.expect(list == [PrivacyBlurPiece(region: .chatList,
                                               rect: CGRect(x: layout.rail, y: 0, width: layout.listEdge - layout.rail,
                                                            height: wide.height))],
                     "the chat list is its column, after the rail, top to bottom")
        let messages = PrivacyBlurRegions.pieces([.messages], layout: layout, size: wide)
        suite.expect(messages.count == 1 && messages[0].rect == CGRect(x: layout.listEdge, y: layout.header,
                                                                       width: wide.width - layout.listEdge,
                                                                       height: wide.height - layout.header),
                     "messages are the conversation under its header")
        let names = PrivacyBlurRegions.pieces([.names], layout: layout, size: wide)
        suite.expect(names.count == 2 && names.contains { $0.rect.minY == 0 && $0.rect.height == layout.header
                        && $0.rect.minX == layout.listEdge }
                        && names.contains { $0.rect.minX == layout.rail && $0.rect.width == layout.avatar
                            && $0.rect.minY == layout.listTop },
                     "names and photos are the conversation's header and the list's photo column")
        let listAndNames = PrivacyBlurRegions.pieces([.chatList, .names], layout: layout, size: wide)
        suite.expect(listAndNames.count == 2 && listAndNames.contains { $0.region == .chatList }
                        && !listAndNames.contains { $0.region == .names && $0.rect.minX == layout.rail },
                     "photos inside a blurred chat list are not blurred twice")
        let all3 = PrivacyBlurRegions.pieces([.chatList, .messages, .names], layout: layout, size: wide)
        let overlaps = all3.indices.contains { i in
            all3.indices.contains { j in i < j && all3[i].rect.intersection(all3[j].rect).width * all3[i].rect.intersection(all3[j].rect).height > 0 }
        }
        suite.expect(!overlaps && union(all3) == CGRect(x: layout.rail, y: 0, width: wide.width - layout.rail,
                                                        height: wide.height),
                     "list, messages and names tile the window beside the rail without overlapping")

        // Narrow windows show one column, so a part can't be told from the rest.
        let narrow = CGSize(width: layout.listEdge + 100, height: 700)
        for region in [PrivacyBlurRegion.chatList, .messages, .names] {
            let result = PrivacyBlurRegions.pieces([region], layout: layout, size: narrow)
            suite.expect(result == [PrivacyBlurPiece(region: .everything, rect: CGRect(origin: .zero, size: narrow))],
                         "a narrow window blurs whole for \(region.rawValue)")
        }
        suite.expect(PrivacyBlurRegions.pieces([.chatList], layout: layout, size: .zero).isEmpty,
                     "no window, no parts")
        var far = layout
        far.listEdge = 5000
        let clamped = PrivacyBlurRegions.pieces([.messages], layout: far, size: CGSize(width: 2000, height: 900))
        suite.expect(clamped.allSatisfy { CGRect(x: 0, y: 0, width: 2000, height: 900).contains($0.rect) },
                     "a chat list edge past the window never puts a part outside it")
        var huge = layout
        huge.header = 2000
        let tall = PrivacyBlurRegions.pieces([.messages], layout: huge, size: wide)
        suite.expect(tall.first.map { $0.rect.height >= wide.height * 2 / 3 - 0.5 } ?? false,
                     "a header taller than a third of the window is held to a third")
    }

    private static func presets(_ suite: TestSuite) {
        suite.expect(PrivacyBlurPreset.all.map(\.name) == ["WhatsApp", "Telegram", "Slack", "Discord", "Messages"],
                     "the presets, WhatsApp first")
        suite.expect(Set(PrivacyBlurPreset.all.map(\.id)).count == PrivacyBlurPreset.all.count
                        && PrivacyBlurPreset.all.allSatisfy { $0.bundleIDs.first == $0.id },
                     "each preset has its own id, its first bundle id")
        let allIDs = PrivacyBlurPreset.all.flatMap(\.bundleIDs)
        suite.expect(Set(allIDs).count == allIDs.count, "no bundle id belongs to two presets")
        suite.expect(PrivacyBlurPreset.matching(bundleID: "desktop.WhatsApp") == .whatsApp
                        && PrivacyBlurPreset.matching(bundleID: "com.tdesktop.Telegram") == .telegram
                        && PrivacyBlurPreset.matching(bundleID: "com.example.chat") == nil,
                     "a preset's other bundle ids lead back to it")
        for preset in PrivacyBlurPreset.all {
            let layout = preset.layout
            suite.expect(layout.rail < layout.listEdge && layout.avatar <= layout.listEdge - layout.rail
                            && PrivacyBlurLayout.listEdgeRange.contains(Double(layout.listEdge))
                            && layout.header > 0 && layout.listTop >= 0,
                         "\(preset.name)'s columns make sense")
            for size in [CGSize(width: 1000, height: 700), CGSize(width: 1600, height: 1000), CGSize(width: 2560, height: 1400)] {
                let window = CGRect(origin: .zero, size: size)
                for regions: Set<PrivacyBlurRegion> in [[.everything], [.chatList], [.messages], [.names],
                                                        [.chatList, .messages, .names]] {
                    let result = PrivacyBlurRegions.pieces(regions, layout: layout, size: size)
                    suite.expect(!result.isEmpty && result.allSatisfy { window.contains($0.rect) && $0.rect.width >= 1 },
                                 "\(preset.name) \(regions.map(\.rawValue).sorted()) at \(Int(size.width)) stays inside")
                }
            }
        }
        let discord = PrivacyBlurRegions.pieces([.names], layout: PrivacyBlurPreset.discord.layout, size: wide)
        suite.expect(discord.contains { $0.rect.maxX == wide.width && $0.rect.width == PrivacyBlurPreset.discord.layout.trailing },
                     "Discord's member list counts as names")
        let discordMessages = PrivacyBlurRegions.pieces([.messages], layout: PrivacyBlurPreset.discord.layout, size: wide)
        suite.expect(discordMessages.first.map { $0.rect.maxX == wide.width - PrivacyBlurPreset.discord.layout.trailing } ?? false,
                     "Discord's messages stop at the member list")
    }

    private static func revealing(_ suite: TestSuite) {
        let layout = PrivacyBlurPreset.whatsApp.layout
        let pieces = PrivacyBlurRegions.pieces([.chatList, .messages, .names], layout: layout, size: wide)
        func reveal(_ hover: PrivacyBlurHover, _ point: CGPoint?, holding: Bool = false, typing: Bool = false,
                    focused: Bool = false) -> PrivacyBlurReveal {
            PrivacyBlurRevealing.reveal(hover: hover, holding: holding, typing: typing, isFocusedWindow: focused,
                                        pointer: point, windowSize: wide, pieces: pieces)
        }
        let inMessages = CGPoint(x: 800, y: 400), inHeader = CGPoint(x: 800, y: 20), inList = CGPoint(x: 200, y: 400)
        let messagesIndex = pieces.firstIndex { $0.region == .messages }
        let headerIndex = pieces.firstIndex { $0.region == .names && $0.rect.minY == 0 }
        let listIndex = pieces.firstIndex { $0.region == .chatList }
        suite.expect(reveal(.region, inMessages) == messagesIndex.map(PrivacyBlurReveal.piece)
                        && reveal(.region, inHeader) == headerIndex.map(PrivacyBlurReveal.piece)
                        && reveal(.region, inList) == listIndex.map(PrivacyBlurReveal.piece),
                     "hovering reveals the part under the pointer, and only it")
        suite.expect(reveal(.region, CGPoint(x: 30, y: 400)) == .none, "over the unblurred rail nothing changes")
        suite.expect(reveal(.region, CGPoint(x: -5, y: 10)) == .none && reveal(.region, CGPoint(x: 1300, y: 10)) == .none
                        && reveal(.region, nil) == .none,
                     "a pointer outside the window reveals nothing")
        suite.expect(reveal(.off, inMessages) == .none, "with hover off the pointer reveals nothing")
        suite.expect(reveal(.circle, inMessages) == .circle(inMessages), "the circle follows the pointer")
        let rail = PrivacyBlurRegions.pieces([.messages], layout: layout, size: wide)
        suite.expect(PrivacyBlurRevealing.reveal(hover: .circle, holding: false, typing: false, isFocusedWindow: false,
                                                 pointer: CGPoint(x: 20, y: 400), windowSize: wide, pieces: rail) == .none,
                     "a circle that touches no blurred part is no reveal")
        suite.expect(reveal(.off, nil, holding: true) == .all && reveal(.region, inMessages, holding: true) == .all,
                     "holding the key reveals the whole window, wherever the pointer is")
        suite.expect(reveal(.region, nil, typing: true, focused: true) == .all
                        && reveal(.region, nil, typing: true, focused: false) == .none,
                     "typing reveals the window being typed in, not the others")
        // The smallest part wins where parts meet.
        let nested = [PrivacyBlurPiece(region: .everything, rect: CGRect(x: 0, y: 0, width: 100, height: 100)),
                      PrivacyBlurPiece(region: .names, rect: CGRect(x: 10, y: 10, width: 20, height: 20))]
        suite.expect(PrivacyBlurRevealing.piece(at: CGPoint(x: 15, y: 15), in: nested) == 1
                        && PrivacyBlurRevealing.piece(at: CGPoint(x: 60, y: 60), in: nested) == 0,
                     "the smallest part under the pointer is the one revealed")
        // Typing.
        suite.expect(PrivacyBlurRevealing.isTyping(lastKey: 10, now: 10.5)
                        && !PrivacyBlurRevealing.isTyping(lastKey: 10, now: 10 + PrivacyBlurRevealing.typingHold + 0.01)
                        && !PrivacyBlurRevealing.isTyping(lastKey: nil, now: 10)
                        && !PrivacyBlurRevealing.isTyping(lastKey: 10, now: 9),
                     "typing lasts a moment after the last key")
        suite.expect(PrivacyBlurRevealing.countsAsTyping(flags: 0)
                        && PrivacyBlurRevealing.countsAsTyping(flags: PrivacyBlurHoldKey.shiftMask)
                        && PrivacyBlurRevealing.countsAsTyping(flags: PrivacyBlurHoldKey.optionMask)
                        && !PrivacyBlurRevealing.countsAsTyping(flags: PrivacyBlurHoldKey.commandMask)
                        && !PrivacyBlurRevealing.countsAsTyping(flags: PrivacyBlurHoldKey.controlMask),
                     "letters, capitals and ⌥ characters type; ⌘ and ⌃ shortcuts don't")
        // Frost.
        let light = PrivacyBlurRevealing.frostOpacity(strength: 0), heavy = PrivacyBlurRevealing.frostOpacity(strength: 1)
        suite.expect(light > 0 && heavy < 1 && light < heavy
                        && PrivacyBlurRevealing.frostOpacity(strength: 0.5) > light
                        && PrivacyBlurRevealing.frostOpacity(strength: 5) == heavy
                        && PrivacyBlurRevealing.frostOpacity(strength: -1) == light
                        && PrivacyBlurRevealing.frostOpacity(strength: .nan)
                            == PrivacyBlurRevealing.frostOpacity(strength: PrivacyBlurDefaults.defaultStrength),
                     "strength moves the frost between a little and nearly solid, never outside")
    }

    private static func holdKey(_ suite: TestSuite) {
        let option = PrivacyBlurHoldKey.option
        suite.expect(option.isHeld(flags: PrivacyBlurHoldKey.optionMask), "⌥ alone is held")
        suite.expect(option.isHeld(flags: PrivacyBlurHoldKey.optionMask | (1 << 16)),
                     "Caps Lock beside it doesn't matter")
        suite.expect(!option.isHeld(flags: PrivacyBlurHoldKey.optionMask | PrivacyBlurHoldKey.shiftMask)
                        && !option.isHeld(flags: PrivacyBlurHoldKey.optionMask | PrivacyBlurHoldKey.commandMask),
                     "a shortcut in progress is not a hold")
        suite.expect(!option.isHeld(flags: 0) && !PrivacyBlurHoldKey.none.isHeld(flags: 0)
                        && !PrivacyBlurHoldKey.none.isHeld(flags: PrivacyBlurHoldKey.optionMask),
                     "nothing held, or the key off, reveals nothing")
        suite.expect(PrivacyBlurHoldKey.control.isHeld(flags: PrivacyBlurHoldKey.controlMask)
                        && PrivacyBlurHoldKey.command.isHeld(flags: PrivacyBlurHoldKey.commandMask)
                        && !PrivacyBlurHoldKey.command.isHeld(flags: PrivacyBlurHoldKey.controlMask),
                     "each key answers to itself")
    }

    private static func entry(_ id: Int, pid: Int32, x: Double = 0, y: Double = 0, width: Double = 800,
                              height: Double = 600, layer: Int = 0, alpha: Double = 1) -> [String: Any] {
        [kCGWindowNumber as String: NSNumber(value: id), kCGWindowOwnerPID as String: NSNumber(value: pid),
         kCGWindowBounds as String: ["X": x, "Y": y, "Width": width, "Height": height],
         kCGWindowLayer as String: NSNumber(value: layer), kCGWindowAlpha as String: NSNumber(value: alpha)]
    }

    private static func placement(_ suite: TestSuite) {
        let info: [[String: Any]] = [
            entry(10, pid: 1, width: 300, height: 80, layer: 101),   // a menu
            entry(11, pid: 1, x: 40, y: 60),                            // the chat
            entry(12, pid: 2),                                          // another app
            entry(13, pid: 1, width: 60, height: 60),                   // a tiny helper window
            entry(14, pid: 1, alpha: 0),                                // invisible
            [kCGWindowNumber as String: NSNumber(value: 15)],           // no bounds
            entry(16, pid: 1, x: 900, y: 100, width: 500, height: 400), // a second chat window
        ]
        let windows = PrivacyBlurPlacement.windows(from: info)
        suite.expect(windows.map(\.id) == [10, 11, 12, 13, 14, 16], "entries without bounds are skipped, order kept")
        suite.expect(windows[1].frame == CGRect(x: 40, y: 60, width: 800, height: 600) && windows[0].layer == 101,
                     "bounds and layers are read")
        let targets = PrivacyBlurPlacement.targets(in: windows, pids: [1])
        suite.expect(targets.map(\.id) == [11, 16],
                     "only the chosen app's visible, ordinary, chat-sized windows get a pane, front to back")
        suite.expect(PrivacyBlurPlacement.targets(in: windows, pids: []).isEmpty, "no chosen app, no panes")
        let cocoa = PrivacyBlurPlacement.cocoaFrame(CGRect(x: 40, y: 60, width: 800, height: 600), mainDisplayHeight: 1000)
        suite.expect(cocoa == CGRect(x: 40, y: 340, width: 800, height: 600), "window server rects flip into AppKit's")
        let local = PrivacyBlurPlacement.localPoint(CGPoint(x: 140, y: 840), inWindow: CGRect(x: 40, y: 60, width: 800, height: 600),
                                                    mainDisplayHeight: 1000)
        suite.expect(local == CGPoint(x: 100, y: 100), "the pointer lands in the window's own top-left space")
        let otherDisplay = PrivacyBlurPlacement.cocoaFrame(CGRect(x: -1200, y: -200, width: 800, height: 600),
                                                           mainDisplayHeight: 1000)
        suite.expect(otherDisplay == CGRect(x: -1200, y: 600, width: 800, height: 600),
                     "a window on a display left of and above the main one flips the same way")
    }

    private static func ordering(_ suite: TestSuite) {
        let own: pid_t = 99
        func window(_ id: CGWindowID, _ pid: pid_t) -> PrivacyBlurWindow {
            PrivacyBlurWindow(id: id, pid: pid, frame: CGRect(x: 0, y: 0, width: 800, height: 600), layer: 0, alpha: 1)
        }
        let target = window(2, 1)
        let rightAbove = [window(50, own), target, window(3, 7)]
        suite.expect(!PrivacyBlurPlacement.needsOrdering(overlay: 50, target: target, ownPID: own, in: rightAbove),
                     "a pane just above its window stays where it is")
        let covered = [window(3, 7), window(50, own), target]
        suite.expect(!PrivacyBlurPlacement.needsOrdering(overlay: 50, target: target, ownPID: own, in: covered),
                     "another app's window over both is left alone: the pane stays under it")
        let below = [target, window(50, own)]
        suite.expect(PrivacyBlurPlacement.needsOrdering(overlay: 50, target: target, ownPID: own, in: below),
                     "the window came forward over its pane: order it again")
        let between = [window(50, own), window(3, 7), target]
        suite.expect(PrivacyBlurPlacement.needsOrdering(overlay: 50, target: target, ownPID: own, in: between),
                     "another app's window between the pane and its window: order again")
        let sheet = [window(50, own), window(4, 1), window(51, own), target]
        suite.expect(!PrivacyBlurPlacement.needsOrdering(overlay: 50, target: target, ownPID: own, in: sheet),
                     "the app's own sheet and Zenith's other panes between them are fine")
        suite.expect(PrivacyBlurPlacement.needsOrdering(overlay: nil, target: target, ownPID: own, in: rightAbove)
                        && PrivacyBlurPlacement.needsOrdering(overlay: 77, target: target, ownPID: own, in: rightAbove),
                     "a pane not yet on screen is ordered in")
        suite.expect(PrivacyBlurPlacement.needsOrdering(overlay: 50, target: window(9, 1), ownPID: own, in: rightAbove),
                     "a window not in the list orders its pane again (it is read again next time)")
    }

    private static func activation(_ suite: TestSuite) {
        let none = PrivacyBlurSharing()
        var mirrored = PrivacyBlurSharing()
        mirrored.mirrored = true
        var watched = PrivacyBlurSharing()
        watched.screenWatched = true
        var presenting = PrivacyBlurSharing()
        presenting.presentation = true
        suite.expect(!none.isSharing && mirrored.isSharing && watched.isSharing && presenting.isSharing,
                     "mirroring, a screen watcher or presentation mode each count as sharing")
        suite.expect(!PrivacyBlurActivation.automatic(enabled: false, when: .always, sharing: mirrored),
                     "off is off, whatever is shared")
        suite.expect(PrivacyBlurActivation.automatic(enabled: true, when: .always, sharing: none),
                     "Always blurs without sharing")
        suite.expect(!PrivacyBlurActivation.automatic(enabled: true, when: .whileSharing, sharing: none)
                        && PrivacyBlurActivation.automatic(enabled: true, when: .whileSharing, sharing: mirrored)
                        && PrivacyBlurActivation.automatic(enabled: true, when: .whileSharing, sharing: presenting),
                     "While sharing waits for a share, a mirror or presentation mode")
        // The shortcut.
        suite.expect(PrivacyBlurActivation.toggled(automatic: true, override: nil) == false
                        && PrivacyBlurActivation.effective(automatic: true, override: false) == false,
                     "the shortcut pauses a blur that is up")
        suite.expect(PrivacyBlurActivation.toggled(automatic: true, override: false) == nil,
                     "and a second press hands back to the rules")
        suite.expect(PrivacyBlurActivation.toggled(automatic: false, override: nil) == true
                        && PrivacyBlurActivation.effective(automatic: false, override: true),
                     "it starts a blur that waits for sharing")
        suite.expect(PrivacyBlurActivation.override(false, afterAutomatic: true, becomes: true) == false
                        && PrivacyBlurActivation.override(true, afterAutomatic: false, becomes: true) == nil
                        && PrivacyBlurActivation.override(false, afterAutomatic: true, becomes: false) == nil,
                     "a pause lasts until sharing starts or ends, then the rules lead again")
        suite.expect(PrivacyBlurActivation.effective(automatic: false, override: nil) == false
                        && PrivacyBlurActivation.effective(automatic: true, override: nil),
                     "without an override the rules decide")
    }

    private static func apps(_ suite: TestSuite) {
        suite.expect(PrivacyBlurApps.normalized(nil) == ["net.whatsapp.WhatsApp"], "WhatsApp by default")
        suite.expect(PrivacyBlurApps.normalized([]).isEmpty, "an emptied list stays empty")
        suite.expect(PrivacyBlurApps.normalized(["desktop.WhatsApp", "net.whatsapp.WhatsApp", " com.example.chat ", "",
                                                 "com.example.chat"]) == ["net.whatsapp.WhatsApp", "com.example.chat"],
                     "each app once, a preset's other ids folded into it, blanks dropped")
        suite.expect(PrivacyBlurApps.matches(bundleID: "desktop.WhatsApp", app: "net.whatsapp.WhatsApp")
                        && PrivacyBlurApps.matches(bundleID: "com.example.chat", app: "com.example.chat")
                        && !PrivacyBlurApps.matches(bundleID: "com.example.other", app: "com.example.chat")
                        && !PrivacyBlurApps.matches(bundleID: nil, app: "com.example.chat"),
                     "running apps are matched by bundle id, a preset by any of its ids")
        suite.expect(PrivacyBlurApps.app(for: "com.hnc.DiscordPTB", in: ["com.hnc.Discord"]) == "com.hnc.Discord"
                        && PrivacyBlurApps.app(for: "com.hnc.Discord", in: ["net.whatsapp.WhatsApp"]) == nil,
                     "a running app leads to the chosen entry it belongs to")
        suite.expect(PrivacyBlurApps.name(of: "net.whatsapp.WhatsApp", customNames: [:]) == "WhatsApp"
                        && PrivacyBlurApps.name(of: "com.example.chat", customNames: ["com.example.chat": "Chatty"]) == "Chatty"
                        && PrivacyBlurApps.name(of: "com.example.chat", customNames: [:]) == "chat",
                     "names come from the preset, the chosen app, or the bundle id")
        suite.expect(PrivacyBlurApps.layout(of: "com.example.chat", listEdges: [:]) == .generic,
                     "an unknown app gets the generic layout")
        suite.expect(PrivacyBlurApps.layout(of: "net.whatsapp.WhatsApp", listEdges: ["net.whatsapp.WhatsApp": 500]).listEdge == 500
                        && PrivacyBlurApps.layout(of: "net.whatsapp.WhatsApp", listEdges: ["net.whatsapp.WhatsApp": 99_999]).listEdge
                            == CGFloat(PrivacyBlurLayout.listEdgeRange.upperBound)
                        && PrivacyBlurApps.layout(of: "net.whatsapp.WhatsApp", listEdges: ["net.whatsapp.WhatsApp": .nan])
                            == PrivacyBlurPreset.whatsApp.layout,
                     "the slider's chat list edge is used, held to its range")
        suite.expect(PrivacyBlurApps.addablePresets(to: ["net.whatsapp.WhatsApp"]).map(\.name)
                        == ["Telegram", "Slack", "Discord", "Messages"],
                     "Add offers the presets not chosen yet")
    }

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.privacy-blur"
        guard let defaults = UserDefaults(suiteName: domain) else { return suite.expect(false, "test defaults") }
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let fresh = PrivacyBlurPreferences(defaults: defaults)
        suite.expect(!fresh.enabled && fresh.apps == ["net.whatsapp.WhatsApp"] && fresh.regions(of: "net.whatsapp.WhatsApp") == [.everything]
                        && fresh.hover == .region && fresh.holdKey == .none && !fresh.revealWhileTyping
                        && fresh.when == .always && !fresh.presentation
                        && fresh.strength == PrivacyBlurDefaults.defaultStrength,
                     "off by default: WhatsApp, Everything, hover reveals a part, always")
        defaults.set(["com.tinyspeck.slackmacgap"], forKey: PrivacyBlurDefaults.apps)
        defaults.set(["com.tinyspeck.slackmacgap": ["messages"]], forKey: PrivacyBlurDefaults.regions)
        defaults.set("circle", forKey: PrivacyBlurDefaults.hover)
        defaults.set("option", forKey: PrivacyBlurDefaults.holdKey)
        defaults.set("whileSharing", forKey: PrivacyBlurDefaults.when)
        defaults.set(3.0, forKey: PrivacyBlurDefaults.strength)
        let set = PrivacyBlurPreferences(defaults: defaults)
        suite.expect(set.apps == ["com.tinyspeck.slackmacgap"] && set.regions(of: "com.tinyspeck.slackmacgap") == [.messages]
                        && set.hover == .circle && set.holdKey == .option && set.when == .whileSharing && set.strength == 1,
                     "the choices are read, strength held to its range")
        defaults.set("sometimes", forKey: PrivacyBlurDefaults.when)
        defaults.set("loud", forKey: PrivacyBlurDefaults.hover)
        let unknown = PrivacyBlurPreferences(defaults: defaults)
        suite.expect(unknown.when == .always && unknown.hover == .region, "an unknown choice reads as the default")
        suite.expect(PrivacyBlurDefaults.backupKeys.allSatisfy { $0.hasPrefix("zenithPrivacyBlur") }
                        && PrivacyBlurDefaults.backupKeys.contains(PrivacyBlurDefaults.enabled)
                        && PrivacyBlurDefaults.backupKeys.contains(PrivacyBlurDefaults.regions)
                        && !PrivacyBlurDefaults.backupKeys.contains(PrivacyBlurDefaults.presentationMode),
                     "the backup carries the preferences, not one talk's presentation mode")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: PrivacyBlurDefaults.backupKeys),
                     "the settings backup includes Privacy Blur")
    }

    private static func words(_ suite: TestSuite) {
        let text = ZenithStrings.privacyBlur(.enUS)
        suite.expect(text.all.allSatisfy { !$0.isEmpty }, "every string has words")
        suite.expect(PrivacyBlurRegion.allCases.allSatisfy { !text.title($0).isEmpty && !text.detail($0).isEmpty }
                        && PrivacyBlurHover.allCases.allSatisfy { !text.title($0).isEmpty }
                        && PrivacyBlurHoldKey.allCases.allSatisfy { !text.title($0).isEmpty }
                        && PrivacyBlurWhen.allCases.allSatisfy { !text.title($0).isEmpty },
                     "every choice has a name")
        suite.expect(text.appCount(1) == "1 app" && text.appCount(3) == "3 apps", "the app count chip")
        suite.expect(Set(PrivacyBlurSearch.aliases).count == PrivacyBlurSearch.aliases.count
                        && PrivacyBlurSearch.aliases.contains("whatsapp") && PrivacyBlurSearch.aliases.contains("privasi"),
                     "search finds it in English and Indonesian, each alias once")
    }
}
