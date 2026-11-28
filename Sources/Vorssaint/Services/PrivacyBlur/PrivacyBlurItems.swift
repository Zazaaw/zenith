// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: what Privacy Blur blurs in a window, one item at a time: each
// chat row's photo, name and last-message preview, each message bubble (text
// or media), the open chat's photo and name, and the typing field. Pure
// logic over a snapshot of the window's Accessibility tree, so the tests
// reach every rule with synthetic trees.
//
// Privacy: a snapshot holds roles, subroles, positions and sizes, nothing
// else. Privacy Blur never reads an element's text (AXValue, AXTitle,
// AXDescription, AXHelp, AXPlaceholderValue, ...): the items are found by
// their shape, never by what they say.
//
// Frames come in the window server's space (top left of the main display,
// y down); scenes leave in the window's own space (its top left, y down).

/// A link from a snapshot's node to the app's live element (an
/// `AXUIElement`), so one part of the tree can be read again. Nil in tests.
final class PrivacyBlurElementHandle: @unchecked Sendable {
    let element: AnyObject
    init(_ element: AnyObject) { self.element = element }
}

/// One element of a window's Accessibility tree: its role, subrole and
/// frame, and its children. Never its text.
struct PrivacyBlurNode: @unchecked Sendable {
    var id: Int
    var role: String
    var subrole: String = ""
    /// The window server's space.
    var frame: CGRect
    var children: [PrivacyBlurNode] = []
    var handle: PrivacyBlurElementHandle?

    init(id: Int, role: String, subrole: String = "", frame: CGRect, children: [PrivacyBlurNode] = [],
         handle: PrivacyBlurElementHandle? = nil) {
        self.id = id
        self.role = role
        self.subrole = subrole
        self.frame = frame
        self.children = children
        self.handle = handle
    }

    /// The node with `id`, anywhere under this one.
    func node(_ id: Int) -> PrivacyBlurNode? {
        if self.id == id { return self }
        for child in children { if let found = child.node(id) { return found } }
        return nil
    }

    /// The tree with the node `id` swapped for `replacement` (a part read
    /// again), or nil when no node has that id any more.
    func replacing(_ id: Int, with replacement: PrivacyBlurNode) -> PrivacyBlurNode? {
        if self.id == id { return replacement }
        for (index, child) in children.enumerated() {
            if let replaced = child.replacing(id, with: replacement) {
                var copy = self
                copy.children[index] = replaced
                return copy
            }
        }
        return nil
    }

    var count: Int { 1 + children.reduce(0) { $0 + $1.count } }

    /// The tree moved by `dx`, `dy` (a part read after the window moved).
    func offset(dx: CGFloat, dy: CGFloat) -> PrivacyBlurNode {
        var copy = self
        copy.frame = frame.offsetBy(dx: dx, dy: dy)
        copy.children = children.map { $0.offset(dx: dx, dy: dy) }
        return copy
    }
}

/// The Accessibility roles the rules look at.
enum PrivacyBlurRole {
    static let window = "AXWindow"
    static let group = "AXGroup"
    static let button = "AXButton"
    static let staticText = "AXStaticText"
    static let heading = "AXHeading"
    static let textArea = "AXTextArea"
    static let textField = "AXTextField"
    static let image = "AXImage"
    static let link = "AXLink"
    static let scrollArea = "AXScrollArea"
    static let cell = "AXCell"
    static let row = "AXRow"
    static let searchField = "AXSearchField" // a subrole
    static let secureField = "AXSecureTextField" // a subrole

    /// Roles whose children never matter: the element's frame is the item.
    /// The walk doesn't descend into them.
    static let leaves: Set<String> = [staticText, heading, textArea, textField, image, link]
}

// MARK: - Items

/// What an item is, and so which option blurs it.
enum PrivacyBlurItemKind: String, CaseIterable {
    /// A text bubble in the open chat.
    case message
    /// A picture, video or sticker bubble.
    case media
    /// A chat row's last-message line.
    case preview
    /// A profile picture: a chat row's or the open chat's.
    case avatar
    /// A chat or group name: a chat row's top line or the open chat's header.
    case name
    /// The field you type in.
    case input
    /// The whole window, for the window mode and when no item is found.
    case window
}

/// One blurred item, in the window's own space.
struct PrivacyBlurItem: Equatable {
    var kind: PrivacyBlurItemKind
    var rect: CGRect
    var cornerRadius: CGFloat
    /// The scroll area it moves with, if any (`PrivacyBlurScrollArea.id`).
    var area: Int?
}

/// A part of the window that scrolls (the chat list, the conversation):
/// where its items show, in the window's own space.
struct PrivacyBlurScrollArea: Equatable {
    /// Stable across reads while the layout holds, so scrolling between
    /// two reads is credited to the same area.
    let id: Int
    let rect: CGRect
    /// The snapshot node to read again while it scrolls.
    let nodeID: Int
}

/// What a read of one window found.
struct PrivacyBlurScene: Equatable {
    var items: [PrivacyBlurItem]
    var areas: [PrivacyBlurScrollArea]
    /// False when the window's structure wasn't recognised: the window
    /// then blurs whole, never half-covered.
    var recognized: Bool

    static let unrecognized = PrivacyBlurScene(items: [], areas: [], recognized: false)
}

/// The item options, as the browser extension has them. All on but "No
/// transition delay".
struct PrivacyBlurItemOptions: Equatable {
    var messages = true
    var previews = true
    var media = true
    var avatars = true
    var names = true
    var input = true
    var hoverReveal = true
    var noDelay = false

    static let standard = PrivacyBlurItemOptions()

    func blurs(_ kind: PrivacyBlurItemKind) -> Bool {
        switch kind {
        case .message: return messages
        case .media: return media
        case .preview: return previews
        case .avatar: return avatars
        case .name: return names
        case .input: return input
        case .window: return true
        }
    }
}

enum PrivacyBlurItems {
    /// A window blurred whole follows the window's corners.
    static let windowCornerRadius: CGFloat = 12
    /// More items than this in one window and the rest are left to the walk's cap.
    static let maximumItems = 400

    static func wholeWindow(_ size: CGSize) -> PrivacyBlurItem {
        PrivacyBlurItem(kind: .window, rect: CGRect(origin: .zero, size: size), cornerRadius: windowCornerRadius)
    }

    /// The items an overlay draws: the scene's items the options blur, or
    /// the whole window in the window mode, without a scene (no
    /// Accessibility, no read yet) or when the scene wasn't recognised.
    static func shown(scene: PrivacyBlurScene?, mode: PrivacyBlurMode, options: PrivacyBlurItemOptions,
                      windowSize: CGSize) -> [PrivacyBlurItem] {
        guard windowSize.width >= 1, windowSize.height >= 1 else { return [] }
        guard mode == .items, let scene, scene.recognized else { return [wholeWindow(windowSize)] }
        return scene.items.filter { options.blurs($0.kind) }
    }

    /// The item under `point` (the window's space): the smallest that holds
    /// it, nil outside them all.
    static func item(at point: CGPoint, in items: [PrivacyBlurItem]) -> Int? {
        items.indices.filter { items[$0].rect.contains(point) }
            .min { items[$0].rect.width * items[$0].rect.height < items[$1].rect.width * items[$1].rect.height }
    }

    /// The rules for an app's window.
    static func classify(_ support: PrivacyBlurItemSupport, root: PrivacyBlurNode, window: CGRect) -> PrivacyBlurScene {
        switch support {
        case .tuned: return PrivacyBlurWhatsAppRules.scene(root: root, window: window)
        case .generic: return PrivacyBlurGenericRules.scene(root: root, window: window)
        }
    }
}

// MARK: - Geometry

enum PrivacyBlurGeometry {
    /// Slivers thinner than this are dropped.
    static let minimumVisible: CGFloat = 3

    /// The part of `rect` inside `clip`, nil when nothing worth a blur is left.
    static func visible(_ rect: CGRect, in clip: CGRect) -> CGRect? {
        let part = rect.intersection(clip)
        guard !part.isNull, part.width >= minimumVisible, part.height >= minimumVisible else { return nil }
        return part
    }

    /// `rect` from the window server's space into the window's own.
    static func local(_ rect: CGRect, in window: CGRect) -> CGRect {
        rect.offsetBy(dx: -window.minX, dy: -window.minY)
    }

    /// `clip` with its top no higher than `top` and its bottom no lower than `bottom`.
    static func band(_ clip: CGRect, top: CGFloat, bottom: CGFloat) -> CGRect {
        let minY = max(clip.minY, top), maxY = min(clip.maxY, bottom)
        guard maxY > minY else { return .null }
        return CGRect(x: clip.minX, y: minY, width: clip.width, height: maxY - minY)
    }
}

/// A snapshot laid out flat: each node with its parent and children, in
/// the walk's order.
struct PrivacyBlurTreeIndex {
    struct Entry {
        let node: PrivacyBlurNode
        let parent: Int?
        var children: [Int] = []
        var frame: CGRect { node.frame }
        var role: String { node.role }
    }

    private(set) var entries: [Entry] = []

    init(_ root: PrivacyBlurNode) {
        var stack: [(PrivacyBlurNode, Int?)] = [(root, nil)]
        while let (node, parent) = stack.popLast() {
            let index = entries.count
            entries.append(Entry(node: node, parent: parent))
            if let parent { entries[parent].children.append(index) }
            for child in node.children.reversed() { stack.append((child, index)) }
        }
    }

    /// Whether `ancestor` holds `index` somewhere under it.
    func isAncestor(_ ancestor: Int, of index: Int) -> Bool {
        var current = entries[index].parent
        while let at = current {
            if at == ancestor { return true }
            current = entries[at].parent
        }
        return false
    }

    func related(_ a: Int, _ b: Int) -> Bool { a == b || isAncestor(a, of: b) || isAncestor(b, of: a) }

    /// The nearest ancestor with `role`.
    func ancestor(of index: Int, role: String) -> Int? {
        var current = entries[index].parent
        while let at = current {
            if entries[at].role == role { return at }
            current = entries[at].parent
        }
        return nil
    }
}

// MARK: - WhatsApp

/// WhatsApp for Mac (Catalyst), from its tree's shape: a column of chat
/// rows (one button per row, as wide as the list), a column of bubbles
/// (one static text each, narrower than the conversation), a header above
/// each column and the typing field under the conversation. Columns are
/// found by role and geometry, never by position in the tree, so another
/// window size or layout (one column at a time) still reads.
enum PrivacyBlurWhatsAppRules {
    /// Where a chat row's parts sit, as fractions of the row's height (69 pt
    /// in WhatsApp): the photo a square on the left, the name the top line,
    /// the preview the bottom line. Generous on purpose: blurring a little
    /// past the text never shows it.
    struct RowRules: Equatable {
        var avatarSide = 0.72, avatarMaxSide: CGFloat = 56, avatarInset = 0.19, avatarMinInset: CGFloat = 8
        var textGap = 0.17
        var nameTop = 0.14, nameHeight = 0.36, nameTrailing: CGFloat = 64
        var previewTop = 0.5, previewHeight = 0.38, previewTrailing: CGFloat = 12
        static let standard = RowRules()
    }

    static let rows = RowRules.standard
    /// A chat row's height and width, against its list.
    static let rowHeights: ClosedRange<CGFloat> = 50...110
    static let rowMinimumWidth: CGFloat = 200
    static let rowWidthShare: CGFloat = 0.9
    /// A bubble is narrower than this share of the conversation.
    static let bubbleWidthShare: CGFloat = 0.92
    /// Columns narrower than this are the navigation strip.
    static let minimumColumn: CGFloat = 200
    static let bubbleRadius: CGFloat = 9
    static let mediaRadius: CGFloat = 12
    static let lineRadius: CGFloat = 6
    static let inputRadius: CGFloat = 10
    /// The areas' ids: fixed, the layout has one of each.
    static let listArea = 1
    static let conversationArea = 2

    static func scene(root: PrivacyBlurNode, window: CGRect) -> PrivacyBlurScene {
        let tree = PrivacyBlurTreeIndex(root)
        let list = chatList(tree)
        let conversation = self.conversation(tree, excluding: list)
        guard list != nil || conversation != nil else { return .unrecognized }
        var items: [PrivacyBlurItem] = []
        var areas: [PrivacyBlurScrollArea] = []

        if let list {
            let container = tree.entries[list]
            let top = header(tree, over: list, window: window).map { tree.entries[$0].frame.maxY } ?? window.minY
            let clip = PrivacyBlurGeometry.band(container.frame.intersection(window), top: top, bottom: window.maxY)
            if !clip.isNull {
                areas.append(PrivacyBlurScrollArea(id: listArea, rect: PrivacyBlurGeometry.local(clip, in: window),
                                                   nodeID: container.node.id))
                for row in container.children where isRow(tree.entries[row], in: container.frame) {
                    let frame = tree.entries[row].frame
                    guard PrivacyBlurGeometry.visible(frame, in: clip) != nil else { continue }
                    for part in rowParts(frame) {
                        guard let shown = PrivacyBlurGeometry.visible(part.rect, in: clip) else { continue }
                        items.append(PrivacyBlurItem(kind: part.kind, rect: PrivacyBlurGeometry.local(shown, in: window),
                                                     cornerRadius: part.radius, area: listArea))
                    }
                }
            }
        }

        if let conversation {
            let container = tree.entries[conversation]
            let span = container.frame
            let head = header(tree, over: conversation, window: window)
            let top = head.map { tree.entries[$0].frame.maxY } ?? window.minY
            let composer = self.composer(tree, under: span, window: window)
            let bottom = composer.map { $0.band.minY - 4 } ?? window.maxY
            let clip = PrivacyBlurGeometry.band(span.intersection(window), top: top, bottom: bottom)
            if let head {
                for part in headerParts(tree, head) {
                    guard let shown = PrivacyBlurGeometry.visible(part.rect, in: window) else { continue }
                    items.append(PrivacyBlurItem(kind: part.kind, rect: PrivacyBlurGeometry.local(shown, in: window),
                                                 cornerRadius: part.radius))
                }
            }
            if !clip.isNull {
                areas.append(PrivacyBlurScrollArea(id: conversationArea, rect: PrivacyBlurGeometry.local(clip, in: window),
                                                   nodeID: container.node.id))
                for child in container.children {
                    guard let frame = bubble(tree, child, in: span), let kind = bubbleKind(frame),
                          let shown = PrivacyBlurGeometry.visible(frame, in: clip) else { continue }
                    items.append(PrivacyBlurItem(kind: kind, rect: PrivacyBlurGeometry.local(shown, in: window),
                                                 cornerRadius: kind == .media ? mediaRadius : bubbleRadius,
                                                 area: conversationArea))
                }
            }
            if let composer, let shown = PrivacyBlurGeometry.visible(composer.field.insetBy(dx: -6, dy: -6), in: window) {
                items.append(PrivacyBlurItem(kind: .input, rect: PrivacyBlurGeometry.local(shown, in: window),
                                             cornerRadius: inputRadius))
            }
        }
        return PrivacyBlurScene(items: Array(items.prefix(PrivacyBlurItems.maximumItems)), areas: areas, recognized: true)
    }

    // MARK: Chat list

    /// A chat row in a list of `container`'s frame: a button (or the
    /// selected row's static text) as wide as the list, a row's height.
    static func isRow(_ entry: PrivacyBlurTreeIndex.Entry, in container: CGRect) -> Bool {
        let roles = [PrivacyBlurRole.button, PrivacyBlurRole.staticText, PrivacyBlurRole.cell, PrivacyBlurRole.row]
        return roles.contains(entry.role) && entry.node.subrole != PrivacyBlurRole.searchField
            && entry.frame.width >= max(rowMinimumWidth, container.width * rowWidthShare)
            && rowHeights.contains(entry.frame.height)
    }

    /// The node whose children are the most chat rows, at least one a button.
    static func chatList(_ tree: PrivacyBlurTreeIndex) -> Int? {
        var best: (index: Int, rows: Int)?
        for (index, entry) in tree.entries.enumerated() where entry.frame.width >= minimumColumn && !entry.children.isEmpty {
            let rows = entry.children.filter { isRow(tree.entries[$0], in: entry.frame) }
            guard rows.contains(where: { tree.entries[$0].role == PrivacyBlurRole.button }) else { continue }
            if rows.count > (best?.rows ?? 0) { best = (index, rows.count) }
        }
        return best?.index
    }

    /// A row's photo, name and preview, in the window server's space.
    static func rowParts(_ row: CGRect) -> [(kind: PrivacyBlurItemKind, rect: CGRect, radius: CGFloat)] {
        let r = rows, h = row.height
        let side = min(h * r.avatarSide, r.avatarMaxSide)
        let avatarX = row.minX + max(r.avatarMinInset, h * r.avatarInset)
        let avatar = CGRect(x: avatarX, y: row.midY - side / 2, width: side, height: side)
        let textX = avatar.maxX + max(8, h * r.textGap)
        let nameWidth = row.maxX - r.nameTrailing - textX
        let previewWidth = row.maxX - r.previewTrailing - textX
        var parts: [(PrivacyBlurItemKind, CGRect, CGFloat)] = [(.avatar, avatar, side / 2)]
        if nameWidth > 8 {
            parts.append((.name, CGRect(x: textX, y: row.minY + h * r.nameTop, width: nameWidth, height: h * r.nameHeight),
                          lineRadius))
        }
        if previewWidth > 8 {
            parts.append((.preview, CGRect(x: textX, y: row.minY + h * r.previewTop, width: previewWidth,
                                           height: h * r.previewHeight), lineRadius))
        }
        return parts.map { (kind: $0.0, rect: $0.1, radius: $0.2) }
    }

    // MARK: Conversation

    /// A bubble's frame: a static text narrower than the conversation, or
    /// one wrapped alone in a group (the encryption notice).
    static func bubble(_ tree: PrivacyBlurTreeIndex, _ index: Int, in container: CGRect) -> CGRect? {
        var entry = tree.entries[index]
        if entry.role == PrivacyBlurRole.group, entry.children.count == 1 { entry = tree.entries[entry.children[0]] }
        guard entry.role == PrivacyBlurRole.staticText, entry.node.subrole != PrivacyBlurRole.searchField,
              entry.frame.width >= 8, entry.frame.height >= 8,
              entry.frame.width < container.width * bubbleWidthShare else { return nil }
        return entry.frame
    }

    /// Text, media, or nothing for a date chip or a tiny system label.
    static func bubbleKind(_ frame: CGRect) -> PrivacyBlurItemKind? {
        if frame.height <= 22 && frame.width <= 150 { return nil }
        let aspect = frame.width / frame.height
        if frame.height >= 100 && aspect >= 0.45 && aspect <= 1.45 { return .media }
        return .message
    }

    /// The node whose children are the most bubbles, not the chat list nor
    /// a node around or inside it. A column of identical texts is a menu.
    static func conversation(_ tree: PrivacyBlurTreeIndex, excluding list: Int?) -> Int? {
        var best: (index: Int, bubbles: Int)?
        for (index, entry) in tree.entries.enumerated() where entry.frame.width >= minimumColumn && !entry.children.isEmpty {
            if let list, tree.related(index, list) { continue }
            let frames = entry.children.compactMap { bubble(tree, $0, in: entry.frame) }
            guard !frames.isEmpty else { continue }
            if frames.count >= 4, Set(frames.map { "\(Int($0.width))x\(Int($0.height))" }).count == 1 { continue }
            if frames.count > (best?.bubbles ?? 0) { best = (index, frames.count) }
        }
        return best?.index
    }

    /// The bar at the top of a column: a group across most of the column,
    /// starting near the window's top, not around or inside the column's
    /// content. The lowest one wins.
    static func header(_ tree: PrivacyBlurTreeIndex, over container: Int, window: CGRect) -> Int? {
        let span = tree.entries[container].frame
        var best: Int?
        for (index, entry) in tree.entries.enumerated()
            where entry.role == PrivacyBlurRole.group && !entry.children.isEmpty && !tree.related(index, container) {
            let frame = entry.frame
            guard frame.minX >= span.minX - 2, frame.maxX <= span.maxX + 2, frame.width >= span.width * 0.6,
                  frame.minY <= window.minY + 40, (24...160).contains(frame.height) else { continue }
            if best.map({ tree.entries[$0].frame.maxY < frame.maxY }) ?? true { best = index }
        }
        return best
    }

    /// The open chat's photo and name in its header: the name is what sits
    /// in the header but its small icon buttons (call, search, menu), the
    /// photo the circle just before it.
    static func headerParts(_ tree: PrivacyBlurTreeIndex, _ header: Int)
        -> [(kind: PrivacyBlurItemKind, rect: CGRect, radius: CGFloat)] {
        let bar = tree.entries[header].frame
        let content = tree.entries[header].children.map { tree.entries[$0] }.filter { entry in
            let frame = entry.frame
            let iconButton = entry.role == PrivacyBlurRole.button && frame.width <= 34 && frame.height <= 34
            return !iconButton && frame.width >= 4 && frame.height >= 4 && frame.intersects(bar)
        }
        let name = content.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        guard !name.isNull else { return [] }
        let side = min(bar.height * 0.78, 40)
        let avatarX = max(bar.minX + 2, name.minX - side - 4)
        var parts: [(kind: PrivacyBlurItemKind, rect: CGRect, radius: CGFloat)] = []
        if name.minX - avatarX >= side * 0.75 {
            parts.append((.avatar, CGRect(x: avatarX, y: name.midY - side / 2, width: side, height: side), side / 2))
        }
        parts.append((.name, name.insetBy(dx: -2, dy: -2), lineRadius))
        return parts
    }

    /// The typing field under the conversation, and the band its row
    /// covers (the field with the buttons beside it).
    static func composer(_ tree: PrivacyBlurTreeIndex, under span: CGRect, window: CGRect)
        -> (field: CGRect, band: CGRect)? {
        let fields = tree.entries.indices.filter { index in
            let entry = tree.entries[index]
            return entry.role == PrivacyBlurRole.textArea && entry.frame.midX >= span.minX
                && entry.frame.midX <= span.maxX && entry.frame.midY > window.midY
        }
        guard let index = fields.max(by: { tree.entries[$0].frame.maxY < tree.entries[$1].frame.maxY }) else { return nil }
        let field = tree.entries[index].frame
        var band = field
        if let parent = tree.entries[index].parent {
            for sibling in tree.entries[parent].children {
                let frame = tree.entries[sibling].frame
                if frame.height <= 60, abs(frame.midY - field.midY) <= 30 { band = band.union(frame) }
            }
        }
        return (field, band)
    }
}

// MARK: - Any app

/// For an app without rules of its own: every text block (a static text),
/// every heading (often a name), every picture big enough to be a photo
/// or media, and every text field. Items move with the scroll area around
/// them and show only inside it. Unverified on the owner's Mac, so apps
/// start on the whole window and the page calls it experimental.
enum PrivacyBlurGenericRules {
    static let avatarMaxSide: CGFloat = 72
    static let mediaMinSide: CGFloat = 48
    /// A text taller than this share of the window is a document, not a block.
    static let maximumShare: CGFloat = 0.6

    static func scene(root: PrivacyBlurNode, window: CGRect) -> PrivacyBlurScene {
        let tree = PrivacyBlurTreeIndex(root)
        var items: [PrivacyBlurItem] = []
        var areaByIndex: [Int: PrivacyBlurScrollArea] = [:]
        let scrollAreas = tree.entries.indices.filter { tree.entries[$0].role == PrivacyBlurRole.scrollArea }
            .sorted { (tree.entries[$0].frame.minX, tree.entries[$0].frame.minY) < (tree.entries[$1].frame.minX, tree.entries[$1].frame.minY) }
        for (order, index) in scrollAreas.enumerated() {
            guard let clip = PrivacyBlurGeometry.visible(tree.entries[index].frame, in: window) else { continue }
            areaByIndex[index] = PrivacyBlurScrollArea(id: 100 + order, rect: PrivacyBlurGeometry.local(clip, in: window),
                                                       nodeID: tree.entries[index].node.id)
        }
        let windowArea = window.width * window.height
        for (index, entry) in tree.entries.enumerated() where index > 0 {
            guard let kind = kind(of: entry) else { continue }
            let areaIndex = tree.ancestor(of: index, role: PrivacyBlurRole.scrollArea)
            let area = areaIndex.flatMap { areaByIndex[$0] }
            let clip = areaIndex.map { tree.entries[$0].frame.intersection(window) } ?? window
            guard let shown = PrivacyBlurGeometry.visible(entry.frame, in: clip),
                  shown.width * shown.height <= windowArea * maximumShare else { continue }
            let radius: CGFloat = kind == .avatar ? min(shown.width, shown.height) / 2 : (kind == .media ? 8 : 5)
            let rect = kind == .input ? shown.insetBy(dx: -3, dy: -3) : shown
            items.append(PrivacyBlurItem(kind: kind, rect: PrivacyBlurGeometry.local(rect, in: window),
                                         cornerRadius: radius, area: area?.id))
            if items.count >= PrivacyBlurItems.maximumItems { break }
        }
        return PrivacyBlurScene(items: items, areas: Array(areaByIndex.values).sorted { $0.id < $1.id },
                                recognized: !items.isEmpty)
    }

    static func kind(of entry: PrivacyBlurTreeIndex.Entry) -> PrivacyBlurItemKind? {
        let frame = entry.frame, subrole = entry.node.subrole
        guard frame.width >= 6, frame.height >= 6 else { return nil }
        switch entry.role {
        case PrivacyBlurRole.staticText where subrole != PrivacyBlurRole.searchField:
            return .message
        case PrivacyBlurRole.heading:
            return .name
        case PrivacyBlurRole.image:
            let side = max(frame.width, frame.height)
            if side <= avatarMaxSide, side >= 16, abs(frame.width - frame.height) <= side * 0.15 { return .avatar }
            return min(frame.width, frame.height) >= mediaMinSide ? .media : nil
        case PrivacyBlurRole.textArea, PrivacyBlurRole.textField:
            return subrole == PrivacyBlurRole.searchField || subrole == PrivacyBlurRole.secureField ? nil : .input
        default:
            return nil
        }
    }
}

// MARK: - Scrolling

/// Scrolling ahead of the next read: each area's items move by what the
/// wheel scrolled since the read began, and show only inside their area.
/// The read that follows puts them where the app has them.
enum PrivacyBlurScrolling {
    /// The scroll area under `point` (the window's space): the smallest.
    static func area(at point: CGPoint, in areas: [PrivacyBlurScrollArea]) -> PrivacyBlurScrollArea? {
        areas.filter { $0.rect.contains(point) }.min { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }
    }

    /// The wheel's movement of the content in points, y down, or nil when it
    /// can't be told ahead (a notched wheel scrolls by lines the app sizes).
    static func contentDelta(scrollingDeltaY: CGFloat, precise: Bool) -> CGFloat? {
        guard precise, scrollingDeltaY.isFinite, scrollingDeltaY != 0 else { return nil }
        return scrollingDeltaY
    }

    /// How far each area scrolled since a read began: the running totals
    /// now, less the totals when it began.
    static func residual(now: [Int: CGFloat], atRead: [Int: CGFloat]) -> [Int: CGFloat] {
        var result: [Int: CGFloat] = [:]
        for (area, total) in now {
            let moved = total - (atRead[area] ?? 0)
            if abs(moved) >= 0.01 { result[area] = moved }
        }
        return result
    }

    /// `items` with each area's moved by its offset and clipped to it.
    static func shifted(_ items: [PrivacyBlurItem], areas: [PrivacyBlurScrollArea],
                        offsets: [Int: CGFloat]) -> [PrivacyBlurItem] {
        guard !offsets.isEmpty else { return items }
        return items.compactMap { item in
            guard let id = item.area, let dy = offsets[id], let area = areas.first(where: { $0.id == id }) else { return item }
            guard let shown = PrivacyBlurGeometry.visible(item.rect.offsetBy(dx: 0, dy: dy), in: area.rect) else { return nil }
            var moved = item
            moved.rect = shown
            return moved
        }
    }
}

/// Running scroll totals per scroll area of one window. The main thread
/// adds the wheel's deltas; a read takes a copy as it begins, so what
/// scrolled while it ran is still applied on top of it.
final class PrivacyBlurScrollLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var totals: [Int: CGFloat] = [:]

    func add(_ area: Int, _ delta: CGFloat) {
        lock.lock()
        totals[area, default: 0] += delta
        lock.unlock()
    }

    func snapshot() -> [Int: CGFloat] {
        lock.lock()
        defer { lock.unlock() }
        return totals
    }
}

// MARK: - Sample

/// A WhatsApp window's tree as WhatsApp for Mac shows it (probed on the
/// owner's Mac by roles and frames only, a 926 × 729 window): the
/// navigation strip, the chat list under its header, the conversation
/// under its header with the typing field. For the tests and the
/// Settings page's stage.
enum PrivacyBlurSample {
    static let windowSize = CGSize(width: 926, height: 729)

    /// The tree, with the window's top left at `origin` in the window server's space.
    static func whatsApp(origin: CGPoint = .zero) -> (root: PrivacyBlurNode, window: CGRect) {
        var next = 0
        func node(_ role: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, subrole: String = "",
                  _ children: [PrivacyBlurNode] = []) -> PrivacyBlurNode {
            next += 1
            return PrivacyBlurNode(id: next, role: role, subrole: subrole,
                                   frame: CGRect(x: origin.x + x, y: origin.y + y, width: w, height: h), children: children)
        }
        let g = PrivacyBlurRole.group, b = PrivacyBlurRole.button, t = PrivacyBlurRole.staticText
        let navigation = node(g, 0, 0, 186, 729, (0..<12).map { i in
            node(i == 6 ? PrivacyBlurRole.heading : t, 10, 41 + CGFloat(i) * 32, 166, 32)
        })
        let navigationButtons = node(g, 8, 693, 170, 28, [node(b, 8, 693, 59, 28), node(b, 150, 693, 28, 28)])
        let listHeader = node(g, 0, 10, 506, 100, [
            node(b, 200, 14, 28, 28), node(PrivacyBlurRole.heading, 327, 20, 38, 16), node(b, 464, 14, 28, 28),
            node(t, 202, 56, 288, 36, subrole: PrivacyBlurRole.searchField), node(b, 202, 56, 288, 36),
        ])
        var rows = [node(g, 0, 69, 506, 43, [node(b, 0, 69, 506, 43)]), node(t, 0, 112, 506, 69)]
        rows += (0..<8).map { i in node(b, 0, 181 + CGFloat(i) * 69, 506, 69) }
        rows.append(node(g, 212, 66_816, 269, 13, [node(t, 230, 66_816, 251, 13), node(PrivacyBlurRole.link, 368, 66_816, 111, 13)]))
        let list = node(g, 0, 0, 506, 729, rows)
        let listColumn = node(g, 0, 0, 506, 729, [listHeader, node(g, 0, 0, 506, 729, [node(g, 0, 0, 506, 729, [list])])])
        let conversationHeader = node(g, 507, 10, 419, 46, [
            node(b, 560, 10, 61, 36), node(g, 568, 20, 53, 17), node(g, 622, 12, 162, 32),
            node(b, 800, 14, 28, 28), node(b, 842, 14, 28, 28), node(b, 884, 14, 28, 28),
        ])
        let bubbles = node(g, 507, 0, 419, 729, [
            node(g, 564, -430, 306, 30, [node(t, 588, -430, 258, 30)]),
            node(t, 523, -16, 256, 46),     // scrolled under the header
            node(t, 523, 33, 138, 174),     // a photo, partly under the header
            node(t, 700, 223, 33, 14),      // a date chip
            node(t, 638, 253, 272, 81),
            node(t, 523, 346, 140, 33),
            node(t, 523, 382, 272, 126),    // a long text: wide, not media
            node(t, 721, 520, 189, 33),
            node(t, 675, 556, 235, 33),
            node(t, 523, 601, 251, 68),
        ])
        let content = node(g, 507, 0, 419, 729, [
            bubbles, node(b, 517, 685, 36, 36), node(PrivacyBlurRole.textArea, 572, 693, 293, 21),
            node(b, 840, 691, 24, 24), node(b, 880, 685, 36, 36),
        ])
        let conversationColumn = node(g, 507, 0, 419, 729, [conversationHeader, node(g, 507, 0, 419, 729, [content])])
        let root = node(PrivacyBlurRole.window, 0, 0, 926, 729, subrole: "AXStandardWindow", [
            node(g, 0, 0, 926, 729, subrole: "iOSContentGroup", [
                node(g, 0, 0, 926, 729, [
                    node(g, 0, 0, 926, 729, [navigation, navigationButtons]),
                    node(g, 0, 0, 926, 729, [listColumn, conversationColumn]),
                ]),
            ]),
            node(b, 8, 8, 16, 16, subrole: "AXCloseButton"),
        ])
        return (root, CGRect(origin: origin, size: windowSize))
    }
}
