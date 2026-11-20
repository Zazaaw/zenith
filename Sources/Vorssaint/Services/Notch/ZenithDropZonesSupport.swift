// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the island's drop zones as one choice. Every target a drag can
// land on (Files, AirDrop, Optimize media, Transform, Remove Background,
// Overlay) can be switched off and put in the order the island lays them out,
// from Settings › Shelf › Drop zones. A drag that offers three zones or more
// widens the island so each gets a comfortable tile, and wraps into two rows
// rather than squeezing when even the widest island cannot hold one.
//
// The test executable compiles this file (build.sh, TEST_SOURCES): keep it
// free of anything outside Foundation, CoreGraphics, the string catalogs and
// the drop targets' own support files.

extension NotchDropTarget {
    /// The zone's full name: the island's tooltip and spoken label, and its
    /// row in Settings.
    func zenithTitle(_ language: AppLanguage) -> String {
        switch self {
        case .files: return FeatureStrings.notch(language).files
        case .airDrop: return "AirDrop"
        case .media: return FeatureStrings.notchFiles(language).optimizeMedia
        case .transform: return ZenithStrings.photoActions(language).transform
        case .removeBackground: return ZenithStrings.photoActions(language).removeBackground
        case .overlay: return ZenithStrings.designOverlay(language).dropZone
        }
    }

    /// The name a tile shows when the full one would need a second line.
    func zenithShortTitle(_ language: AppLanguage) -> String {
        let text = ZenithStrings.dropZones(language)
        switch self {
        case .files, .airDrop, .overlay: return zenithTitle(language)
        case .media: return text.optimizeShort
        case .transform: return text.transformShort
        case .removeBackground: return text.removeBackgroundShort
        }
    }

    /// When a drag gets the zone, in one line for its row in Settings.
    func zenithWhen(_ language: AppLanguage) -> String {
        let text = ZenithStrings.dropZones(language)
        switch self {
        case .files: return text.filesWhen
        case .airDrop: return text.airDropWhen
        case .media: return text.mediaWhen
        case .transform: return text.transformWhen
        case .removeBackground: return text.removeBackgroundWhen
        case .overlay: return text.overlayWhen
        }
    }

    /// The zone's glyph, in the island and in Settings.
    var zenithSymbol: String {
        switch self {
        case .files: return "tray.and.arrow.down"
        case .airDrop: return "dot.radiowaves.left.and.right"
        case .media: return "wand.and.stars"
        case .transform: return "photo.stack"
        case .removeBackground: return "person.and.background.dotted"
        case .overlay: return DesignOverlaySupport.dropSymbol
        }
    }

    /// A calm identity colour (sRGB 0xRRGGBB, the 300 and 400 steps the
    /// island's modules wear): never a status, always beside the zone's
    /// glyph and name. Files keeps the Files section's teal.
    var zenithTintHex: UInt32 {
        switch self {
        case .files: return 0x2DD4BF            // teal, the Files section's own
        case .airDrop: return 0x38BDF8          // sky
        case .media: return 0xA78BFA            // violet
        case .transform: return 0x818CF8        // indigo
        case .removeBackground: return 0xF472B6 // pink
        case .overlay: return 0x22D3EE          // cyan, the capture tools'
        }
    }
}

// MARK: - Settings

/// The zones a person keeps, in their order, each on or off. Stored as one
/// comma-separated list under `DefaultsKey.zenithDropZones`, an entry per
/// target with `:off` after the ones switched off. Until the card is first
/// changed the stored value is `auto`, and the zones follow the switches that
/// came before it (`notchAirDropEnabled`, `notchPhotoActionsEnabled`,
/// `designOverlayDropEnabled`), so old backups and the old switches keep
/// their meaning. Saving writes those switches too, from the zones.
struct ZenithDropZones: Equatable {
    struct Entry: Equatable {
        /// A target's raw value, or a name a newer version wrote.
        let name: String
        var isOn: Bool
        var target: NotchDropTarget? { NotchDropTarget(rawValue: name) }
    }

    /// The stored value before the card was ever changed.
    static let automatic = "auto"
    static let defaultsKey = DefaultsKey.zenithDropZones
    /// The island's order before it could be chosen.
    static let defaultOrder: [NotchDropTarget] = [.files, .airDrop, .media, .transform, .removeBackground, .overlay]
    /// A drag of any kind lands on one of these, so one of them always stays on.
    static let anyFileTargets: [NotchDropTarget] = [.files, .airDrop]
    private static let offSuffix = ":off"

    /// Every entry in order: each known target once, names it does not know
    /// kept where they were so a backup from a newer version survives.
    private(set) var entries: [Entry]

    init(entries: [Entry]) {
        var seen = Set<String>()
        var kept = entries.filter { !$0.name.isEmpty && seen.insert($0.name).inserted }
        // A target the list does not name (a new one, or a list written by
        // hand) joins at the end, on.
        for target in Self.defaultOrder where !seen.contains(target.rawValue) {
            kept.append(Entry(name: target.rawValue, isOn: true))
        }
        self.entries = kept
        if !Self.anyFileTargets.contains(where: isOn) {
            // Never stored this way by the card; a hand-made list gets Files back.
            setOn(.files, true)
        }
    }

    /// The zones as the switches before the card set them.
    init(airDrop: Bool, photoActions: Bool, overlay: Bool) {
        self.init(entries: Self.defaultOrder.map { target in
            let on: Bool
            switch target {
            case .airDrop: on = airDrop
            case .transform, .removeBackground: on = photoActions
            case .overlay: on = overlay
            case .files, .media: on = true
            }
            return Entry(name: target.rawValue, isOn: on)
        })
    }

    /// A stored list; `auto` (or nothing) reads the earlier switches.
    init(encoded: String?, airDrop: Bool = true, photoActions: Bool = true, overlay: Bool = true) {
        guard let encoded, encoded != Self.automatic else {
            self.init(airDrop: airDrop, photoActions: photoActions, overlay: overlay)
            return
        }
        self.init(entries: encoded.split(separator: ",").map { part in
            let item = part.trimmingCharacters(in: .whitespaces)
            let off = item.hasSuffix(Self.offSuffix)
            return Entry(name: off ? String(item.dropLast(Self.offSuffix.count)) : item, isOn: !off)
        })
    }

    static var standard: ZenithDropZones { ZenithDropZones(airDrop: true, photoActions: true, overlay: true) }

    var encoded: String {
        entries.map { $0.isOn ? $0.name : $0.name + Self.offSuffix }.joined(separator: ",")
    }

    /// The known targets in order.
    var order: [NotchDropTarget] { entries.compactMap(\.target) }

    func isOn(_ target: NotchDropTarget) -> Bool {
        entries.first { $0.name == target.rawValue }?.isOn ?? true
    }

    /// Whether switching `target` off still leaves Files or AirDrop on, so a
    /// drag always has somewhere to land. Zones only some drags get can
    /// always be switched off.
    func canTurnOff(_ target: NotchDropTarget) -> Bool {
        guard Self.anyFileTargets.contains(target) else { return true }
        return Self.anyFileTargets.contains { $0 != target && isOn($0) }
    }

    /// The zones with `target` switched; turning off the last of Files and
    /// AirDrop leaves them as they are.
    func setting(_ target: NotchDropTarget, on: Bool) -> ZenithDropZones {
        guard on || canTurnOff(target) else { return self }
        var next = self
        next.setOn(target, on)
        return next
    }

    /// The zones with `target` moved to `index` among the known targets.
    func moving(_ target: NotchDropTarget, to index: Int) -> ZenithDropZones {
        var known = order
        guard let from = known.firstIndex(of: target) else { return self }
        known.remove(at: from)
        known.insert(target, at: min(max(index, 0), known.count))
        return reordering(known)
    }

    /// The zones in `order` (a permutation of the known targets, as a drag in
    /// Settings hands it back). Unknown names stay in their slots.
    func reordering(_ order: [NotchDropTarget]) -> ZenithDropZones {
        guard Set(order) == Set(self.order), order.count == self.order.count else { return self }
        var queue = order[...]
        var next = self
        for index in next.entries.indices where next.entries[index].target != nil {
            let target = queue.removeFirst()
            next.entries[index] = Entry(name: target.rawValue, isOn: isOn(target))
        }
        return next
    }

    /// `targets` (the zones a drag gets) in this order.
    func arranged(_ targets: [NotchDropTarget]) -> [NotchDropTarget] {
        let order = self.order
        return targets.sorted { (order.firstIndex(of: $0) ?? .max) < (order.firstIndex(of: $1) ?? .max) }
    }

    private mutating func setOn(_ target: NotchDropTarget, _ on: Bool) {
        guard let index = entries.firstIndex(where: { $0.name == target.rawValue }) else { return }
        entries[index].isOn = on
    }

    // MARK: Drags

    /// An image drag's own zones, after the photo actions' and the overlay's
    /// rules: Transform for up to 100 images, Remove Background and Overlay
    /// for one. `overlayAvailable` is the screenshot tool, which carries
    /// the overlay.
    func imageTargets(imageCount: Int, overlayAvailable: Bool) -> [NotchDropTarget] {
        let photo = NotchPhotoActionsSupport.targets(imageCount: imageCount, allImages: imageCount > 0).filter(isOn)
        return DesignOverlaySupport.dropTargets(photo: photo, imageCount: imageCount,
                                                overlay: overlayAvailable && isOn(.overlay))
    }

    /// The zones `drag` gets, left to right, as the island offers them:
    /// Files while the shelf takes drops, AirDrop for files, Optimize media
    /// for a batch the media tools take (it needs the shelf too, as it lives
    /// on the Files page), and an image's own zones while the island shows
    /// its Files page.
    func targets(for drag: ZenithDropDrag, shelf: Bool = true, mediaTools: Bool = true,
                 filesPage: Bool = true, overlayAvailable: Bool = true) -> [NotchDropTarget] {
        let images = filesPage ? imageTargets(imageCount: drag.images, overlayAvailable: overlayAvailable) : []
        return arranged(NotchAirDropSupport.targets(files: shelf && isOn(.files),
                                                    airDrop: drag.files && isOn(.airDrop),
                                                    media: shelf && mediaTools && drag.media && isOn(.media),
                                                    photo: images))
    }

    // MARK: Storage

    static func current(in defaults: UserDefaults = .standard) -> ZenithDropZones {
        ZenithDropZones(encoded: defaults.string(forKey: defaultsKey),
                        airDrop: defaults.object(forKey: DefaultsKey.notchAirDropEnabled) as? Bool ?? true,
                        photoActions: defaults.object(forKey: DefaultsKey.notchPhotoActionsEnabled) as? Bool ?? true,
                        overlay: defaults.object(forKey: DefaultsKey.designOverlayDropEnabled) as? Bool ?? true)
    }

    /// Saves the zones and moves the earlier switches with them; nothing is
    /// written when nothing changed.
    static func save(_ zones: ZenithDropZones, in defaults: UserDefaults = .standard) {
        guard zones != current(in: defaults) else { return }
        defaults.set(zones.encoded, forKey: defaultsKey)
        let legacy: [(String, Bool)] = [
            (DefaultsKey.notchAirDropEnabled, zones.isOn(.airDrop)),
            (DefaultsKey.notchPhotoActionsEnabled, zones.isOn(.transform) || zones.isOn(.removeBackground)),
            (DefaultsKey.designOverlayDropEnabled, zones.isOn(.overlay)),
        ]
        for (key, value) in legacy where defaults.object(forKey: key) as? Bool ?? true != value {
            defaults.set(value, forKey: key)
        }
    }
}

/// What a drag carries, as far as the zones care.
struct ZenithDropDrag: Equatable {
    /// File URLs, which AirDrop sends.
    var files: Bool
    /// A batch the media tools can optimize.
    var media: Bool
    /// Images only, this many (0 when anything else is in the drag).
    var images: Int

    /// Files of no particular kind, such as PDFs or folders.
    static let otherFiles = ZenithDropDrag(files: true, media: false, images: 0)
    /// Videos, or other media the tools optimize but no image zone takes.
    static let mediaFiles = ZenithDropDrag(files: true, media: true, images: 0)
    static func images(_ count: Int) -> ZenithDropDrag { ZenithDropDrag(files: true, media: true, images: count) }
    static let oneImage = images(1)
}

// MARK: - Layout

/// How the island lays the zones out while a drag hovers it, and how a
/// point finds its zone, so what it draws and where a drop lands agree.
enum ZenithDropZoneLayout {
    /// Between zones, across and down.
    static let spacing: CGFloat = NotchFileToolsSupport.dropSpacing
    /// The width a zone asks for, and the least it takes on one row.
    static let preferredTileWidth: CGFloat = 124
    static let minimumTileWidth: CGFloat = 116
    /// From this many zones the island widens to fit them.
    static let widensFrom = 3
    /// A tile is landscape or square: never taller than this share of its width.
    static let tileAspect: CGFloat = 0.88

    /// A row of `columns` tiles of `tile` points each.
    static func rowWidth(columns: Int, tile: CGFloat) -> CGFloat {
        guard columns > 0 else { return 0 }
        return CGFloat(columns) * tile + CGFloat(columns - 1) * spacing
    }

    /// The page width a drag's zones ask for, at most `maximum` (the widest
    /// page the display leaves the island). Nil below three zones, which
    /// keep the island's own width. One row when it holds every zone at
    /// least 116 points wide; otherwise two rows of comfortable tiles.
    static func contentWidth(count: Int, maximum: CGFloat) -> CGFloat? {
        guard count >= widensFrom else { return nil }
        let maximum = max(0, maximum)
        let preferred = rowWidth(columns: count, tile: preferredTileWidth)
        if preferred <= maximum { return preferred }
        if rowWidth(columns: count, tile: minimumTileWidth) <= maximum { return maximum }
        return min(maximum, rowWidth(columns: columns(count: count, rows: 2), tile: preferredTileWidth))
    }

    /// One row while every zone gets 116 points at `width`, otherwise two.
    static func rows(count: Int, width: CGFloat) -> Int {
        guard count >= widensFrom else { return 1 }
        return rowWidth(columns: count, tile: minimumTileWidth) <= width + 0.5 ? 1 : 2
    }

    static func columns(count: Int, rows: Int) -> Int {
        guard count > 0 else { return 0 }
        let rows = max(1, min(rows, count))
        return (count + rows - 1) / rows
    }

    /// Each zone's frame in a page of `size`, its origin at the page's top
    /// leading corner: equal tiles filling the width, centred down the page,
    /// a short last row centred across it.
    static func frames(count: Int, in size: CGSize) -> [CGRect] {
        guard count > 0, size.width > 0, size.height > 0 else { return [] }
        let rows = min(rows(count: count, width: size.width), count)
        let columns = columns(count: count, rows: rows)
        let tileWidth = max(1, (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let rowHeight = max(1, (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
        let tileHeight = min(rowHeight, (tileWidth * tileAspect).rounded())
        let block = tileHeight * CGFloat(rows) + spacing * CGFloat(rows - 1)
        let top = (size.height - block) / 2
        return (0..<count).map { index in
            let row = index / columns
            let column = index % columns
            let inRow = min(columns, count - row * columns)
            let left = (size.width - rowWidth(columns: inRow, tile: tileWidth)) / 2
            return CGRect(x: left + CGFloat(column) * (tileWidth + spacing),
                          y: top + CGFloat(row) * (tileHeight + spacing),
                          width: tileWidth, height: tileHeight)
        }
    }

    /// The zone nearest `point` in a page of `size`: the row nearest it
    /// down the page, then the tile nearest it across that row. A point in
    /// a gap goes to the closer side, and one past an edge to the zone
    /// along that edge.
    static func index(at point: CGPoint, count: Int, in size: CGSize) -> Int {
        let frames = frames(count: count, in: size)
        guard !frames.isEmpty else { return 0 }
        func distance(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            value < low ? low - value : value > high ? value - high : 0
        }
        let rowTops = Array(Set(frames.map(\.minY))).sorted()
        let row = rowTops.min { a, b in
            let height = frames[0].height
            return distance(point.y, a, a + height) < distance(point.y, b, b + height)
        } ?? rowTops[0]
        let candidates = frames.indices.filter { frames[$0].minY == row }
        return candidates.min { a, b in
            distance(point.x, frames[a].minX, frames[a].maxX) < distance(point.x, frames[b].minX, frames[b].maxX)
        } ?? 0
    }
}
