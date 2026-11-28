// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: Privacy Blur's decisions. The items found in a WhatsApp
/// window's tree (the shape probed on the owner's Mac) and in any app's,
/// a chat row's parts, clipping to what shows, the options, scrolling ahead
/// of a read, what the pointer, a held key and typing reveal and how fast,
/// which windows get a pane and when a pane is out of place, when the blur
/// is up, the chosen apps and the preferences. No window, observer, monitor
/// or Accessibility call.
enum PrivacyBlurTests {
    static func run(_ suite: TestSuite) {
        whatsApp(suite)
        rowParts(suite)
        bubbles(suite)
        layouts(suite)
        clipping(suite)
        generic(suite)
        options(suite)
        scrolling(suite)
        tree(suite)
        revealing(suite)
        transitions(suite)
        holdKey(suite)
        placement(suite)
        ordering(suite)
        activation(suite)
        apps(suite)
        preferences(suite)
        words(suite)
    }

    private static func node(_ id: Int, _ role: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                             subrole: String = "", _ children: [PrivacyBlurNode] = []) -> PrivacyBlurNode {
        PrivacyBlurNode(id: id, role: role, subrole: subrole, frame: CGRect(x: x, y: y, width: w, height: h),
                        children: children)
    }

    private static func sampleScene(origin: CGPoint = .zero) -> PrivacyBlurScene {
        let sample = PrivacyBlurSample.whatsApp(origin: origin)
        return PrivacyBlurItems.classify(.tuned, root: sample.root, window: sample.window)
    }

    /// The same scene, but for floating-point rounding.
    private static func same(_ a: PrivacyBlurScene, _ b: PrivacyBlurScene) -> Bool {
        func close(_ x: CGRect, _ y: CGRect) -> Bool {
            abs(x.minX - y.minX) < 0.001 && abs(x.minY - y.minY) < 0.001 && abs(x.width - y.width) < 0.001
                && abs(x.height - y.height) < 0.001
        }
        return a.recognized == b.recognized && a.items.count == b.items.count && a.areas.count == b.areas.count
            && zip(a.items, b.items).allSatisfy { $0.kind == $1.kind && $0.area == $1.area && close($0.rect, $1.rect) }
            && zip(a.areas, b.areas).allSatisfy { $0.id == $1.id && close($0.rect, $1.rect) }
    }

    private static func count(_ scene: PrivacyBlurScene, _ kind: PrivacyBlurItemKind) -> Int {
        scene.items.filter { $0.kind == kind }.count
    }

    // MARK: Items

    private static func whatsApp(_ suite: TestSuite) {
        let scene = sampleScene()
        let window = CGRect(origin: .zero, size: PrivacyBlurSample.windowSize)
        suite.expect(scene.recognized, "WhatsApp's tree is recognised")
        // Nine rows show under the search header: the selected one (a static text) and eight buttons.
        suite.expect(count(scene, .avatar) == 9 + 1 && count(scene, .name) == 9 + 1 && count(scene, .preview) == 9,
                     "each visible chat row has a photo, a name and a preview; the open chat adds a photo and a name")
        suite.expect(count(scene, .message) == 6 && count(scene, .media) == 1,
                     "six text bubbles and one photo show; the date chip and what scrolled away don't")
        suite.expect(count(scene, .input) == 1, "the typing field is one item")
        suite.expect(scene.items.allSatisfy { window.contains($0.rect) && $0.rect.width >= 3 && $0.rect.height >= 3 },
                     "every item lies inside the window")
        let list = scene.areas.first { $0.id == PrivacyBlurWhatsAppRules.listArea }
        let conversation = scene.areas.first { $0.id == PrivacyBlurWhatsAppRules.conversationArea }
        suite.expect(list?.rect == CGRect(x: 0, y: 110, width: 506, height: 619),
                     "the chat list scrolls under its search header, to the window's bottom")
        suite.expect(conversation?.rect == CGRect(x: 507, y: 56, width: 419, height: 625),
                     "the conversation scrolls between its header and the typing row")
        suite.expect(scene.items.filter { [.avatar, .name, .preview].contains($0.kind) && $0.area == PrivacyBlurWhatsAppRules.listArea }
                        .allSatisfy { $0.rect.maxX <= 506 && $0.rect.minY >= 110 },
                     "the rows' parts stay in the chat list, under its header")
        // The navigation strip's labels (Chats, Updates, Communities) are 166 pt wide texts in a 186 pt column:
        // neither rows nor bubbles.
        suite.expect(!scene.items.contains { $0.rect.width == 166 && $0.rect.height == 32 },
                     "the navigation strip's labels aren't blurred")
        let header = scene.items.filter { $0.area == nil && ($0.kind == .name || $0.kind == .avatar) }
        suite.expect(header.count == 2 && header.allSatisfy { $0.rect.minX >= 507 && $0.rect.maxY <= 60 },
                     "the open chat's photo and name sit in its header")
        if let photo = header.first(where: { $0.kind == .avatar }), let name = header.first(where: { $0.kind == .name }) {
            suite.expect(photo.rect.maxX <= name.rect.minX + 2 && abs(photo.rect.width - photo.rect.height) < 0.5
                            && abs(photo.cornerRadius - photo.rect.width / 2) < 0.01,
                         "the header's photo is a circle just before the name")
            suite.expect(name.rect.maxX < 800, "the call and search buttons are not the name")
        }
        let input = scene.items.first { $0.kind == .input }
        suite.expect(input.map { $0.rect.contains(CGRect(x: 572, y: 693, width: 293, height: 21)) } ?? false,
                     "the typing field's blur covers the field")
        // The same window anywhere on screen gives the same items, in its own space.
        let moved = sampleScene(origin: CGPoint(x: 471, y: 194))
        suite.expect(same(moved, scene), "items are in the window's own space, wherever the window is")
        let other = sampleScene(origin: CGPoint(x: -1400, y: -300))
        suite.expect(same(other, scene), "a window on a display left of and above the main one reads the same")
    }

    private static func rowParts(_ suite: TestSuite) {
        let row = CGRect(x: 0, y: 181, width: 506, height: 69)
        let parts = PrivacyBlurWhatsAppRules.rowParts(row)
        let avatar = parts.first { $0.kind == .avatar }, name = parts.first { $0.kind == .name }
        let preview = parts.first { $0.kind == .preview }
        suite.expect(parts.count == 3 && avatar != nil && name != nil && preview != nil, "a row is a photo, a name and a preview")
        guard let avatar, let name, let preview else { return }
        suite.expect(abs(avatar.rect.width - avatar.rect.height) < 0.01 && avatar.radius == avatar.rect.width / 2
                        && avatar.rect.width >= 44 && avatar.rect.width <= 56,
                     "the photo is a circle about WhatsApp's 49 pt")
        suite.expect(abs(avatar.rect.midY - row.midY) < 0.01 && avatar.rect.minX >= row.minX + 8 && avatar.rect.minX <= row.minX + 20,
                     "the photo sits at the row's left, centred")
        suite.expect(name.rect.minX > avatar.rect.maxX && preview.rect.minX == name.rect.minX,
                     "name and preview start after the photo, aligned")
        suite.expect(name.rect.maxY <= preview.rect.minY + 0.01 && name.rect.minY > row.minY && preview.rect.maxY < row.maxY,
                     "the name is the top line, the preview the bottom one, inside the row")
        suite.expect(name.rect.maxX < preview.rect.maxX && preview.rect.maxX <= row.maxX,
                     "the name leaves the time free; the preview runs nearly to the edge")
        // Proportional: a taller row keeps the layout.
        let tall = PrivacyBlurWhatsAppRules.rowParts(CGRect(x: 100, y: 0, width: 400, height: 90))
        suite.expect(tall.count == 3 && tall.allSatisfy { CGRect(x: 100, y: 0, width: 400, height: 90).contains($0.rect) },
                     "a taller row's parts still fit in it")
        let narrow = PrivacyBlurWhatsAppRules.rowParts(CGRect(x: 0, y: 0, width: 120, height: 69))
        suite.expect(narrow.contains { $0.kind == .avatar } && !narrow.contains { $0.kind == .name },
                     "a row too narrow for a name keeps its photo")
        // A row is told by its shape.
        let list = CGRect(x: 0, y: 0, width: 506, height: 729)
        let tree = PrivacyBlurTreeIndex(node(1, PrivacyBlurRole.group, 0, 0, 506, 729, [
            node(2, PrivacyBlurRole.button, 0, 0, 506, 69), node(3, PrivacyBlurRole.button, 0, 0, 506, 43),
            node(4, PrivacyBlurRole.button, 0, 0, 300, 69), node(5, PrivacyBlurRole.staticText, 0, 0, 506, 69),
            node(6, PrivacyBlurRole.staticText, 0, 0, 506, 69, subrole: PrivacyBlurRole.searchField),
        ]))
        suite.expect(tree.entries[1].role == PrivacyBlurRole.button && PrivacyBlurWhatsAppRules.isRow(tree.entries[1], in: list)
                        && !PrivacyBlurWhatsAppRules.isRow(tree.entries[2], in: list)
                        && !PrivacyBlurWhatsAppRules.isRow(tree.entries[3], in: list)
                        && PrivacyBlurWhatsAppRules.isRow(tree.entries[4], in: list)
                        && !PrivacyBlurWhatsAppRules.isRow(tree.entries[5], in: list),
                     "a row is as wide as its list and a row high (the selected one too); the archived bar and a search field aren't")
    }

    private static func bubbles(_ suite: TestSuite) {
        let kind = PrivacyBlurWhatsAppRules.bubbleKind
        suite.expect(kind(CGRect(x: 0, y: 0, width: 33, height: 14)) == nil
                        && kind(CGRect(x: 0, y: 0, width: 120, height: 20)) == nil,
                     "date chips and tiny system labels aren't blurred")
        suite.expect(kind(CGRect(x: 0, y: 0, width: 138, height: 174)) == .media
                        && kind(CGRect(x: 0, y: 0, width: 260, height: 260)) == .media,
                     "a photo, a sticker and an album are media")
        suite.expect(kind(CGRect(x: 0, y: 0, width: 272, height: 126)) == .message
                        && kind(CGRect(x: 0, y: 0, width: 140, height: 33)) == .message
                        && kind(CGRect(x: 0, y: 0, width: 250, height: 52)) == .message,
                     "text bubbles, short or long, and a voice note are messages")
        let scene = sampleScene()
        suite.expect(scene.items.filter { $0.kind == .message }.allSatisfy { $0.cornerRadius == PrivacyBlurWhatsAppRules.bubbleRadius }
                        && scene.items.filter { $0.kind == .media }.allSatisfy { $0.cornerRadius == PrivacyBlurWhatsAppRules.mediaRadius },
                     "bubbles and media keep their own corners")
    }

    /// Other window shapes: one column at a time, no open chat, unknown trees.
    private static func layouts(_ suite: TestSuite) {
        let g = PrivacyBlurRole.group, b = PrivacyBlurRole.button, t = PrivacyBlurRole.staticText
        let window = CGRect(x: 0, y: 0, width: 420, height: 700)
        // A narrow window showing the conversation alone.
        let conversationOnly = node(1, PrivacyBlurRole.window, 0, 0, 420, 700, [
            node(2, g, 0, 10, 420, 46, [node(3, b, 50, 10, 61, 36), node(4, b, 380, 14, 28, 28)]),
            node(5, g, 0, 0, 420, 700, [
                node(6, g, 0, 0, 420, 700, [node(7, t, 16, 80, 200, 40), node(8, t, 200, 140, 200, 33), node(9, t, 16, 200, 140, 180)]),
                node(10, PrivacyBlurRole.textArea, 60, 660, 300, 21), node(11, b, 10, 652, 36, 36),
            ]),
        ])
        let one = PrivacyBlurItems.classify(.tuned, root: conversationOnly, window: window)
        suite.expect(one.recognized && count(one, .message) == 2 && count(one, .media) == 1 && count(one, .input) == 1
                        && count(one, .name) == 1 && count(one, .preview) == 0,
                     "a window showing the conversation alone still finds its bubbles, header and field")
        // A narrow window showing the chat list alone.
        let listOnly = node(1, PrivacyBlurRole.window, 0, 0, 420, 700, [
            node(2, g, 0, 10, 420, 100, [node(3, t, 20, 56, 380, 36, subrole: PrivacyBlurRole.searchField)]),
            node(4, g, 0, 0, 420, 700, (0..<5).map { node(10 + $0, b, 0, 120 + CGFloat($0) * 69, 420, 69) }),
        ])
        let list = PrivacyBlurItems.classify(.tuned, root: listOnly, window: window)
        suite.expect(list.recognized && count(list, .avatar) == 5 && count(list, .message) == 0,
                     "a window showing the chat list alone finds its rows")
        // Something else entirely: nothing recognised, so the window blurs whole.
        let unknown = node(1, PrivacyBlurRole.window, 0, 0, 420, 700, [node(2, g, 0, 0, 420, 700, [node(3, b, 10, 10, 80, 30)])])
        let none = PrivacyBlurItems.classify(.tuned, root: unknown, window: window)
        suite.expect(!none.recognized && none.items.isEmpty, "a tree without rows or bubbles isn't recognised")
        suite.expect(PrivacyBlurItems.shown(scene: none, mode: .items, options: .standard, windowSize: window.size)
                        == [PrivacyBlurItems.wholeWindow(window.size)],
                     "an unrecognised window blurs whole, never half-covered")
        // A menu-like column of identical texts is not a conversation.
        let menu = node(1, PrivacyBlurRole.window, 0, 0, 420, 700, [
            node(2, g, 0, 0, 300, 700, (0..<6).map { node(10 + $0, t, 10, 40 + CGFloat($0) * 32, 200, 32) }),
        ])
        suite.expect(!PrivacyBlurItems.classify(.tuned, root: menu, window: window).recognized,
                     "a column of identical texts is a menu, not a chat")
    }

    private static func clipping(_ suite: TestSuite) {
        let clip = CGRect(x: 0, y: 100, width: 300, height: 400)
        suite.expect(PrivacyBlurGeometry.visible(CGRect(x: 10, y: 80, width: 50, height: 50), in: clip)
                        == CGRect(x: 10, y: 100, width: 50, height: 30),
                     "an item partly under a header shows only its visible part")
        suite.expect(PrivacyBlurGeometry.visible(CGRect(x: 10, y: 20, width: 50, height: 50), in: clip) == nil
                        && PrivacyBlurGeometry.visible(CGRect(x: 10, y: 98, width: 50, height: 4), in: clip) == nil,
                     "an item scrolled away, or only a sliver of it, is dropped")
        suite.expect(PrivacyBlurGeometry.band(clip, top: 150, bottom: 450) == CGRect(x: 0, y: 150, width: 300, height: 300)
                        && PrivacyBlurGeometry.band(clip, top: 0, bottom: 1000) == clip
                        && PrivacyBlurGeometry.band(clip, top: 600, bottom: 700).isNull,
                     "an area is held between its header and its footer")
        let scene = sampleScene()
        // The photo bubble starts above the header: only what shows under it is blurred.
        let media = scene.items.first { $0.kind == .media }
        suite.expect(media?.rect == CGRect(x: 523, y: 56, width: 138, height: 151),
                     "a bubble scrolled half under the header is blurred where it shows")
        // The last chat row runs past the window's bottom.
        let lowest = scene.items.filter { $0.area == PrivacyBlurWhatsAppRules.listArea }.map(\.rect.maxY).max() ?? 0
        suite.expect(lowest <= PrivacyBlurSample.windowSize.height, "the last row's parts stop at the window's edge")
        let bubbles = scene.items.filter { $0.area == PrivacyBlurWhatsAppRules.conversationArea }
        suite.expect(bubbles.allSatisfy { $0.rect.maxY <= 681 && $0.rect.minY >= 56 },
                     "bubbles never spill over the header or the typing row")
    }

    private static func generic(_ suite: TestSuite) {
        let window = CGRect(x: 100, y: 100, width: 800, height: 600)
        let root = node(1, PrivacyBlurRole.window, 100, 100, 800, 600, [
            node(2, PrivacyBlurRole.heading, 400, 110, 120, 20),
            node(3, PrivacyBlurRole.scrollArea, 100, 140, 300, 560, [
                node(4, PrivacyBlurRole.image, 110, 150, 40, 40),          // a photo
                node(5, PrivacyBlurRole.staticText, 160, 150, 200, 18),
                node(6, PrivacyBlurRole.staticText, 160, 60, 200, 18),     // scrolled above the area
                node(7, PrivacyBlurRole.image, 110, 200, 12, 12),          // an icon
            ]),
            node(8, PrivacyBlurRole.image, 450, 200, 240, 160),            // media
            node(9, PrivacyBlurRole.textArea, 420, 650, 400, 24),
            node(10, PrivacyBlurRole.textField, 420, 120, 200, 22, subrole: PrivacyBlurRole.searchField),
            node(11, PrivacyBlurRole.staticText, 100, 100, 800, 600),      // a document, not a block
        ])
        let scene = PrivacyBlurItems.classify(.generic, root: root, window: window)
        suite.expect(scene.recognized && count(scene, .name) == 1 && count(scene, .avatar) == 1 && count(scene, .message) == 1
                        && count(scene, .media) == 1 && count(scene, .input) == 1,
                     "any app: each text block, heading, photo, picture and text field is an item")
        suite.expect(scene.areas.count == 1 && scene.items.filter { $0.area != nil }.count == 2,
                     "items in a scroll area move with it; those outside it don't")
        suite.expect(!scene.items.contains { $0.rect.minY < 40 && $0.area != nil },
                     "a text scrolled out of its area isn't blurred")
        suite.expect(scene.items.allSatisfy { CGRect(x: -4, y: -4, width: 808, height: 608).contains($0.rect) },
                     "items are in the window's own space")
        let empty = PrivacyBlurItems.classify(.generic, root: node(1, PrivacyBlurRole.window, 0, 0, 800, 600), window: window)
        suite.expect(!empty.recognized, "an app showing nothing to Accessibility blurs whole")
        let huge = node(1, PrivacyBlurRole.window, 0, 0, 800, 600,
                        (0..<1000).map { node(2 + $0, PrivacyBlurRole.staticText, 10, CGFloat($0 % 60) * 10, 50, 8) })
        suite.expect(PrivacyBlurItems.classify(.generic, root: huge, window: CGRect(x: 0, y: 0, width: 800, height: 600)).items.count
                        == PrivacyBlurItems.maximumItems,
                     "a huge tree is capped")
    }

    private static func options(_ suite: TestSuite) {
        let scene = sampleScene()
        let size = PrivacyBlurSample.windowSize
        let all = PrivacyBlurItems.shown(scene: scene, mode: .items, options: .standard, windowSize: size)
        suite.expect(all == scene.items, "the defaults blur every item, as the extension's do")
        func without(_ change: (inout PrivacyBlurItemOptions) -> Void) -> [PrivacyBlurItem] {
            var options = PrivacyBlurItemOptions.standard
            change(&options)
            return PrivacyBlurItems.shown(scene: scene, mode: .items, options: options, windowSize: size)
        }
        suite.expect(!without { $0.messages = false }.contains { $0.kind == .message }
                        && without { $0.messages = false }.contains { $0.kind == .media },
                     "All messages in chat off leaves media blurred")
        suite.expect(!without { $0.media = false }.contains { $0.kind == .media }, "Media preview off clears pictures")
        suite.expect(!without { $0.previews = false }.contains { $0.kind == .preview }
                        && without { $0.previews = false }.contains { $0.kind == .name },
                     "Last messages preview off clears the previews only")
        suite.expect(!without { $0.avatars = false }.contains { $0.kind == .avatar }, "Profile pictures off clears the photos")
        suite.expect(!without { $0.names = false }.contains { $0.kind == .name }, "Group/user names off clears the names")
        suite.expect(!without { $0.input = false }.contains { $0.kind == .input }, "Blur typing input off clears the field")
        let nothing = without {
            $0.messages = false; $0.media = false; $0.previews = false; $0.avatars = false; $0.names = false; $0.input = false
        }
        suite.expect(nothing.isEmpty, "with every option off nothing is blurred")
        suite.expect(PrivacyBlurItems.shown(scene: scene, mode: .window, options: .standard, windowSize: size)
                        == [PrivacyBlurItems.wholeWindow(size)]
                        && PrivacyBlurItems.shown(scene: nil, mode: .items, options: .standard, windowSize: size)
                        == [PrivacyBlurItems.wholeWindow(size)],
                     "the window mode, and no read yet (or no Accessibility), blur the whole window")
        suite.expect(PrivacyBlurItems.shown(scene: scene, mode: .items, options: .standard, windowSize: .zero).isEmpty,
                     "no window, nothing")
        suite.expect(PrivacyBlurItemKind.allCases.allSatisfy { PrivacyBlurItemOptions.standard.blurs($0) }
                        && PrivacyBlurItemOptions.standard.hoverReveal && !PrivacyBlurItemOptions.standard.noDelay,
                     "every kind is on by default, hovering reveals, with the delay")
    }

    private static func scrolling(_ suite: TestSuite) {
        let scene = sampleScene()
        let list = PrivacyBlurWhatsAppRules.listArea, conversation = PrivacyBlurWhatsAppRules.conversationArea
        suite.expect(PrivacyBlurScrolling.area(at: CGPoint(x: 200, y: 400), in: scene.areas)?.id == list
                        && PrivacyBlurScrolling.area(at: CGPoint(x: 700, y: 400), in: scene.areas)?.id == conversation
                        && PrivacyBlurScrolling.area(at: CGPoint(x: 700, y: 20), in: scene.areas) == nil,
                     "the wheel scrolls the area under the pointer, not the headers")
        suite.expect(PrivacyBlurScrolling.contentDelta(scrollingDeltaY: 12, precise: true) == 12
                        && PrivacyBlurScrolling.contentDelta(scrollingDeltaY: 3, precise: false) == nil
                        && PrivacyBlurScrolling.contentDelta(scrollingDeltaY: 0, precise: true) == nil,
                     "a trackpad's points are followed ahead; a notched wheel's lines wait for the read")
        suite.expect(PrivacyBlurScrolling.residual(now: [1: 30, 2: -5], atRead: [1: 10, 2: -5]) == [1: 20],
                     "what scrolled since a read began is what still has to move")
        let shifted = PrivacyBlurScrolling.shifted(scene.items, areas: scene.areas, offsets: [conversation: -40])
        let before = scene.items.filter { $0.area == conversation }, after = shifted.filter { $0.area == conversation }
        suite.expect(shifted.filter { $0.area == list } == scene.items.filter { $0.area == list }
                        && shifted.filter { $0.area == nil } == scene.items.filter { $0.area == nil },
                     "only the scrolled area's items move")
        suite.expect(after.allSatisfy { item in before.contains { abs($0.rect.minY - 40 - item.rect.minY) < 0.01 || item.rect.minY == 56 } }
                        && after.allSatisfy { $0.rect.minY >= 56 && $0.rect.maxY <= 681 },
                     "they move by the wheel's delta and stay clipped to the area")
        suite.expect(after.count < before.count || after.contains { $0.rect.minY == 56 },
                     "a bubble pushed under the header is cut or dropped")
        suite.expect(PrivacyBlurScrolling.shifted(scene.items, areas: scene.areas, offsets: [:]) == scene.items,
                     "nothing scrolled, nothing moves")
        let ledger = PrivacyBlurScrollLedger()
        ledger.add(1, 5)
        ledger.add(1, 7)
        ledger.add(2, -3)
        suite.expect(ledger.snapshot() == [1: 12, 2: -3], "the ledger keeps a running total per area")
    }

    private static func tree(_ suite: TestSuite) {
        let sample = PrivacyBlurSample.whatsApp()
        let scene = sampleScene()
        guard let area = scene.areas.first(where: { $0.id == PrivacyBlurWhatsAppRules.conversationArea }),
              let part = sample.root.node(area.nodeID) else { return suite.expect(false, "the conversation's node") }
        // The part read again after a scroll of 30 points, with new ids.
        func moved(_ node: PrivacyBlurNode, by dy: CGFloat, base: Int) -> PrivacyBlurNode {
            var copy = node
            copy.id = base + node.id
            copy.frame = node.id == part.id ? node.frame : node.frame.offsetBy(dx: 0, dy: dy)
            copy.children = node.children.map { moved($0, by: dy, base: base) }
            return copy
        }
        let fresh = moved(part, by: -30, base: 10_000)
        guard let replaced = sample.root.replacing(area.nodeID, with: fresh) else { return suite.expect(false, "replace") }
        suite.expect(replaced.count == sample.root.count && replaced.node(fresh.id) != nil && replaced.node(area.nodeID) == nil,
                     "a part read again replaces its old self in the tree")
        let after = PrivacyBlurItems.classify(.tuned, root: replaced, window: sample.window)
        suite.expect(after.items.filter { $0.area == PrivacyBlurWhatsAppRules.listArea }
                        == scene.items.filter { $0.area == PrivacyBlurWhatsAppRules.listArea }
                        && after.areas.first { $0.id == PrivacyBlurWhatsAppRules.conversationArea }?.nodeID == fresh.id,
                     "the rest of the window is unchanged, and the area points at the new part")
        suite.expect(sample.root.replacing(99_999, with: fresh) == nil, "a part no longer in the tree is dropped")
        let shifted = sample.root.offset(dx: 10, dy: -5)
        suite.expect(shifted.frame == sample.root.frame.offsetBy(dx: 10, dy: -5)
                        && shifted.node(area.nodeID)?.frame == part.frame.offsetBy(dx: 10, dy: -5),
                     "a tree moves as one")
        let index = PrivacyBlurTreeIndex(sample.root)
        suite.expect(index.entries.count == sample.root.count && index.entries.first?.parent == nil
                        && index.entries.dropFirst().allSatisfy { $0.parent != nil },
                     "the flat index holds every node with its parent")
    }

    private static func revealing(_ suite: TestSuite) {
        let size = PrivacyBlurSample.windowSize
        let items = sampleScene().items
        func reveal(_ point: CGPoint?, hover: Bool = true, holding: Bool = false, typing: Bool = false,
                    focused: Bool = false, items: [PrivacyBlurItem] = items) -> PrivacyBlurReveal {
            PrivacyBlurRevealing.reveal(hoverReveal: hover, holding: holding, typing: typing, isFocusedWindow: focused,
                                        pointer: point, windowSize: size, items: items)
        }
        let onBubble = CGPoint(x: 770, y: 292)
        guard case .item(let index) = reveal(onBubble) else { return suite.expect(false, "hovering a bubble reveals an item") }
        suite.expect(items[index].kind == .message && items[index].rect.contains(onBubble),
                     "hovering a bubble reveals that bubble alone")
        let onAvatar = CGPoint(x: 13 + 25, y: 215)
        if case .item(let avatar) = reveal(onAvatar) {
            suite.expect(items[avatar].kind == .avatar, "hovering a row's photo reveals the photo, not the row")
        } else {
            suite.expect(false, "hovering a row's photo reveals it")
        }
        suite.expect(reveal(CGPoint(x: 68, y: 400)) == .none, "between a photo and its name nothing clears")
        suite.expect(reveal(onBubble, hover: false) == .none, "with hovering off the pointer reveals nothing")
        suite.expect(reveal(CGPoint(x: -5, y: 10)) == .none && reveal(nil) == .none, "a pointer outside reveals nothing")
        suite.expect(reveal(nil, hover: false, holding: true) == .all, "holding the key reveals everything")
        suite.expect(reveal(nil, typing: true, focused: true) == .all && reveal(nil, typing: true, focused: false) == .none,
                     "typing reveals the window being typed in, not the others")
        let whole = [PrivacyBlurItems.wholeWindow(size)]
        suite.expect(reveal(onBubble, items: whole) == .circle(onBubble), "a window blurred whole clears a circle")
        // The smallest item wins where items meet.
        let nested = [PrivacyBlurItem(kind: .window, rect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerRadius: 0),
                      PrivacyBlurItem(kind: .avatar, rect: CGRect(x: 10, y: 10, width: 20, height: 20), cornerRadius: 10)]
        suite.expect(PrivacyBlurItems.item(at: CGPoint(x: 15, y: 15), in: nested) == 1
                        && PrivacyBlurItems.item(at: CGPoint(x: 60, y: 60), in: nested) == 0
                        && PrivacyBlurItems.item(at: CGPoint(x: 160, y: 60), in: nested) == nil,
                     "the smallest item under the pointer is the one hit")
        // The revealed item survives a scroll or a read.
        let bubble = items[index]
        var nudged = bubble
        nudged.rect = bubble.rect.offsetBy(dx: 0, dy: -6)
        let reordered = [items[0], nudged] + items.filter { $0 != bubble && $0 != items[0] }
        suite.expect(PrivacyBlurRevealing.remap(.item(index), from: items, to: reordered) == .item(1),
                     "a revealed bubble that moved a little stays revealed at its new place")
        suite.expect(PrivacyBlurRevealing.remap(.item(index), from: items, to: items.filter { $0 != bubble }) == .none,
                     "a revealed bubble that scrolled away is no longer revealed")
        suite.expect(PrivacyBlurRevealing.remap(.all, from: items, to: []) == .all, "other reveals stay")
        suite.expect(!PrivacyBlurRevealing.sameItem(bubble, PrivacyBlurItem(kind: .media, rect: bubble.rect, cornerRadius: 0))
                        && PrivacyBlurRevealing.sameItem(bubble, nudged),
                     "the same item is the same kind, mostly overlapping")
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

    private static func transitions(_ suite: TestSuite) {
        let standard = PrivacyBlurTransition.timing(noDelay: false, reduceMotion: false)
        let quick = PrivacyBlurTransition.timing(noDelay: true, reduceMotion: false)
        let still = PrivacyBlurTransition.timing(noDelay: false, reduceMotion: true)
        suite.expect(standard.delay > 0 && standard.fadeIn > 0 && standard.fadeOut > 0,
                     "by default an item clears after a short rest, with a fade")
        suite.expect(quick.delay == 0 && quick.fadeIn == 0, "No transition delay clears at once")
        suite.expect(still.delay == standard.delay && still.fadeIn == 0 && still.fadeOut == 0,
                     "Reduce Motion keeps the rest but drops the fades")
        suite.expect(PrivacyBlurTransition.waits(from: .none, to: .item(3)) && PrivacyBlurTransition.waits(from: .item(2), to: .item(3))
                        && PrivacyBlurTransition.waits(from: .none, to: .circle(.zero)),
                     "an item coming clear waits for the pointer to rest")
        suite.expect(!PrivacyBlurTransition.waits(from: .item(2), to: .none) && !PrivacyBlurTransition.waits(from: .none, to: .all)
                        && !PrivacyBlurTransition.waits(from: .item(2), to: .item(2))
                        && !PrivacyBlurTransition.waits(from: .circle(.zero), to: .circle(CGPoint(x: 5, y: 5))),
                     "blurring again, holding the key and the circle following the pointer never wait")
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

    // MARK: Windows

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
        suite.expect(PrivacyBlurRegions.minimumSide == PrivacyBlurPlacement.minimumSide, "the old name still answers")
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

    // MARK: Apps and preferences

    private static func apps(_ suite: TestSuite) {
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
        suite.expect(PrivacyBlurApps.support(of: "net.whatsapp.WhatsApp") == .tuned
                        && PrivacyBlurApps.support(of: "ru.keepcoder.Telegram") == .generic
                        && PrivacyBlurApps.support(of: "com.example.chat") == .generic,
                     "WhatsApp has rules of its own; the rest use the generic ones")
        suite.expect(PrivacyBlurMode.of("net.whatsapp.WhatsApp", stored: [:]) == .items
                        && PrivacyBlurPreset.all.dropFirst().allSatisfy { PrivacyBlurMode.of($0.id, stored: [:]) == .window }
                        && PrivacyBlurMode.of("com.example.chat", stored: [:]) == .window,
                     "WhatsApp blurs item by item by default; apps without their own rules blur whole")
        suite.expect(PrivacyBlurMode.of("com.tinyspeck.slackmacgap", stored: ["com.tinyspeck.slackmacgap": "items"]) == .items
                        && PrivacyBlurMode.of("net.whatsapp.WhatsApp", stored: ["net.whatsapp.WhatsApp": "window"]) == .window
                        && PrivacyBlurMode.of("net.whatsapp.WhatsApp", stored: ["net.whatsapp.WhatsApp": "loud"]) == .items,
                     "a stored mode wins, an unknown one reads as the default")
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
        suite.expect(!fresh.enabled && fresh.apps == ["net.whatsapp.WhatsApp"] && fresh.mode(of: "net.whatsapp.WhatsApp") == .items
                        && fresh.options == .standard && fresh.holdKey == .none && !fresh.revealWhileTyping
                        && fresh.when == .always && !fresh.presentation
                        && fresh.strength == PrivacyBlurDefaults.defaultStrength,
                     "off by default: WhatsApp item by item, every option on, hover reveals with the delay, always")
        defaults.set(["com.tinyspeck.slackmacgap"], forKey: PrivacyBlurDefaults.apps)
        defaults.set(["com.tinyspeck.slackmacgap": "items"], forKey: PrivacyBlurDefaults.modes)
        defaults.set(false, forKey: PrivacyBlurDefaults.media)
        defaults.set(false, forKey: PrivacyBlurDefaults.names)
        defaults.set(true, forKey: PrivacyBlurDefaults.noDelay)
        defaults.set("option", forKey: PrivacyBlurDefaults.holdKey)
        defaults.set("whileSharing", forKey: PrivacyBlurDefaults.when)
        defaults.set(3.0, forKey: PrivacyBlurDefaults.strength)
        let set = PrivacyBlurPreferences(defaults: defaults)
        suite.expect(set.apps == ["com.tinyspeck.slackmacgap"] && set.mode(of: "com.tinyspeck.slackmacgap") == .items
                        && !set.options.media && !set.options.names && set.options.messages && set.options.noDelay
                        && set.holdKey == .option && set.when == .whileSharing && set.strength == 1,
                     "the choices are read, strength held to its range")
        defaults.set("sometimes", forKey: PrivacyBlurDefaults.when)
        let unknown = PrivacyBlurPreferences(defaults: defaults)
        suite.expect(unknown.when == .always, "an unknown choice reads as the default")
        // The first version's hover menu.
        defaults.set("off", forKey: PrivacyBlurDefaults.legacyHover)
        suite.expect(!PrivacyBlurPreferences(defaults: defaults).options.hoverReveal,
                     "a person who had turned hovering off keeps it off")
        defaults.set(true, forKey: PrivacyBlurDefaults.hoverReveal)
        suite.expect(PrivacyBlurPreferences(defaults: defaults).options.hoverReveal, "the new switch wins once set")
        defaults.removeObject(forKey: PrivacyBlurDefaults.hoverReveal)
        defaults.set("circle", forKey: PrivacyBlurDefaults.legacyHover)
        suite.expect(PrivacyBlurPreferences(defaults: defaults).options.hoverReveal, "any other old hover choice reveals")
        let keys = PrivacyBlurDefaults.backupKeys
        suite.expect(keys.allSatisfy { $0.hasPrefix("zenithPrivacyBlur") } && keys.contains(PrivacyBlurDefaults.enabled)
                        && keys.isSuperset(of: [PrivacyBlurDefaults.modes, PrivacyBlurDefaults.messages, PrivacyBlurDefaults.previews,
                                                PrivacyBlurDefaults.media, PrivacyBlurDefaults.avatars, PrivacyBlurDefaults.names,
                                                PrivacyBlurDefaults.input, PrivacyBlurDefaults.hoverReveal, PrivacyBlurDefaults.noDelay])
                        && !keys.contains(PrivacyBlurDefaults.presentationMode),
                     "the backup carries the preferences, not one talk's presentation mode")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: PrivacyBlurDefaults.backupKeys),
                     "the settings backup includes Privacy Blur")
    }

    private static func words(_ suite: TestSuite) {
        let text = ZenithStrings.privacyBlur(.enUS)
        suite.expect(text.all.allSatisfy { !$0.isEmpty }, "every string has words")
        suite.expect(PrivacyBlurMode.allCases.allSatisfy { !text.title($0, generic: false).isEmpty }
                        && text.title(.items, generic: true) != text.title(.items, generic: false)
                        && PrivacyBlurHoldKey.allCases.allSatisfy { !text.title($0).isEmpty }
                        && PrivacyBlurWhen.allCases.allSatisfy { !text.title($0).isEmpty },
                     "every choice has a name; the generic item mode says it is experimental")
        suite.expect([text.messages, text.previews, text.media, text.avatars, text.names, text.input, text.hoverReveal,
                      text.noDelay] == ["All messages in chat", "Last messages preview", "Media preview", "Profile pictures",
                                        "Group/user names", "Blur typing input", "Reveal items on hover", "No transition delay"],
                     "the options are named as the extension names them")
        suite.expect(text.appCount(1) == "1 app" && text.appCount(3) == "3 apps", "the app count chip")
        suite.expect(Set(PrivacyBlurSearch.aliases).count == PrivacyBlurSearch.aliases.count
                        && PrivacyBlurSearch.aliases.contains("whatsapp") && PrivacyBlurSearch.aliases.contains("privasi"),
                     "search finds it in English and Indonesian, each alias once")
    }
}
