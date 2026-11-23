// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: the island's drop zones (ZenithDropZonesSupport): each zone
/// on or off and in its chosen order, the earlier switches they grew out of,
/// Files or AirDrop always on, backups, which zones a drag gets, how far a
/// drag widens the island and when the zones wrap into two rows, where a
/// point lands among the tiles, and the words.
enum DropZonesTests {
    static func run(_ suite: TestSuite) {
        model(suite)
        ordering(suite)
        anyFileRule(suite)
        migration(suite)
        persistence(suite)
        drags(suite)
        widening(suite)
        tiles(suite)
        hitTesting(suite)
        strings(suite)
    }

    private static let suiteName = "com.vorssaint.tests.drop-zones"

    private static func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: Model

    private static func model(_ suite: TestSuite) {
        let standard = ZenithDropZones(encoded: ZenithDropZones.automatic)
        suite.expect(standard.order == ZenithDropZones.defaultOrder
                        && NotchDropTarget.allCases.allSatisfy(standard.isOn)
                        && standard == .standard && ZenithDropZones(encoded: nil) == .standard,
                     "unchanged, every zone is on in the island’s old order")
        suite.expect(ZenithDropZones.defaultOrder == [.files, .airDrop, .media, .transform, .removeBackground, .overlay]
                        && Set(ZenithDropZones.defaultOrder) == Set(NotchDropTarget.allCases),
                     "the old order names every target once")
        let parsed = ZenithDropZones(encoded: " media,files:off, later ,airDrop,media,,transform:off")
        suite.expect(parsed.order == [.media, .files, .airDrop, .transform, .removeBackground, .overlay],
                     "a stored list is read in order, without repeats or blanks, the zones it misses after it: \(parsed.order)")
        suite.expect(!parsed.isOn(.files) && !parsed.isOn(.transform) && parsed.isOn(.media) && parsed.isOn(.removeBackground),
                     "the zones marked off read off, the others and the new ones on")
        suite.expect(parsed.encoded == "media,files:off,later,airDrop,transform:off,removeBackground,overlay"
                        && ZenithDropZones(encoded: parsed.encoded) == parsed,
                     "a name from a newer version keeps its place and the list reads back the same: \(parsed.encoded)")
        let off = standard.setting(.removeBackground, on: false)
        suite.expect(!off.isOn(.removeBackground) && off.isOn(.transform) && off.encoded.contains("removeBackground:off")
                        && off.setting(.removeBackground, on: true) == standard,
                     "each zone switches on its own, Remove Background apart from Transform")
        suite.expect(NotchDropTarget.allCases.map(\.rawValue)
                        == ["files", "airDrop", "media", "transform", "removeBackground", "overlay"],
                     "the stored names stay as they were")
    }

    private static func ordering(_ suite: TestSuite) {
        let standard = ZenithDropZones.standard
        let moved = standard.moving(.overlay, to: 0)
        suite.expect(moved.order == [.overlay, .files, .airDrop, .media, .transform, .removeBackground],
                     "a zone moves to a new place and the rest follow")
        suite.expect(standard.moving(.files, to: 99).order.last == .files && standard.moving(.overlay, to: -4).order.first == .overlay,
                     "a move past either end stops there")
        let off = standard.setting(.transform, on: false).moving(.transform, to: 0)
        suite.expect(off.order.first == .transform && !off.isOn(.transform),
                     "a zone keeps its switch when it moves")
        let permuted: [NotchDropTarget] = [.removeBackground, .transform, .overlay, .media, .airDrop, .files]
        suite.expect(standard.reordering(permuted).order == permuted,
                     "a dragged order is taken whole")
        suite.expect(standard.reordering([.files, .airDrop]) == standard && standard.reordering(permuted + [.files]) == standard,
                     "an order that is not every zone once changes nothing")
        let unknown = ZenithDropZones(encoded: "files,later,airDrop,media,transform,removeBackground,overlay")
        suite.expect(unknown.moving(.airDrop, to: 0).encoded == "airDrop,later,files,media,transform,removeBackground,overlay",
                     "a name the app does not know stays in its slot while the zones move around it")
        suite.expect(moved.arranged([.files, .media, .overlay]) == [.overlay, .files, .media]
                        && standard.arranged([.overlay, .files]) == [.files, .overlay],
                     "a drag’s zones are laid out in the chosen order")
    }

    private static func anyFileRule(_ suite: TestSuite) {
        let standard = ZenithDropZones.standard
        let noFiles = standard.setting(.files, on: false)
        suite.expect(!noFiles.isOn(.files) && noFiles.isOn(.airDrop) && !noFiles.canTurnOff(.airDrop),
                     "with Files off, AirDrop has to stay on")
        suite.expect(noFiles.setting(.airDrop, on: false) == noFiles,
                     "turning off the last of Files and AirDrop is refused")
        let noAirDrop = standard.setting(.airDrop, on: false)
        suite.expect(!noAirDrop.canTurnOff(.files) && noAirDrop.setting(.files, on: false) == noAirDrop,
                     "with AirDrop off, Files has to stay on")
        suite.expect(standard.canTurnOff(.files) && standard.canTurnOff(.airDrop),
                     "with both on, either can go")
        let onlyFiles = [NotchDropTarget.airDrop, .media, .transform, .removeBackground, .overlay]
            .reduce(standard) { $0.setting($1, on: false) }
        suite.expect(onlyFiles.order.filter(onlyFiles.isOn) == [.files],
                     "every image and media zone can be switched off, leaving Files alone")
        suite.expect(ZenithDropZones(encoded: "files:off,airDrop:off").isOn(.files)
                        && ZenithDropZones(airDrop: false, photoActions: false, overlay: false).isOn(.files),
                     "a list that would leave a drag nowhere to land gets Files back")
    }

    private static func migration(_ suite: TestSuite) {
        let defaults = freshDefaults()
        suite.expect(ZenithDropZones.current(in: defaults) == .standard,
                     "nothing stored reads as every zone on")
        defaults.set(false, forKey: DefaultsKey.notchAirDropEnabled)
        defaults.set(false, forKey: DefaultsKey.notchPhotoActionsEnabled)
        let migrated = ZenithDropZones.current(in: defaults)
        suite.expect(!migrated.isOn(.airDrop) && !migrated.isOn(.transform) && !migrated.isOn(.removeBackground)
                        && migrated.isOn(.files) && migrated.isOn(.media) && migrated.isOn(.overlay)
                        && migrated.order == ZenithDropZones.defaultOrder,
                     "until the card changes them, the zones follow the AirDrop and photo actions switches")
        defaults.set(false, forKey: DefaultsKey.designOverlayDropEnabled)
        suite.expect(!ZenithDropZones.current(in: defaults).isOn(.overlay),
                     "and the Overlay zone’s own switch")
        defaults.set(ZenithDropZones.automatic, forKey: ZenithDropZones.defaultsKey)
        suite.expect(!ZenithDropZones.current(in: defaults).isOn(.overlay), "“auto” is the same as nothing stored")
        defaults.set("overlay,files,airDrop,media,transform,removeBackground", forKey: ZenithDropZones.defaultsKey)
        let stored = ZenithDropZones.current(in: defaults)
        suite.expect(stored.isOn(.airDrop) && stored.isOn(.overlay) && stored.order.first == .overlay,
                     "once the card saved its list, the list wins over the earlier switches")
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func persistence(_ suite: TestSuite) {
        suite.expect(ZenithDropZones.defaultsKey == DefaultsKey.zenithDropZones
                        && Defaults.registeredDefaults[DefaultsKey.zenithDropZones] as? String == ZenithDropZones.automatic,
                     "the zones’ key is registered, unchanged by default")
        let keys = [DefaultsKey.zenithDropZones, DefaultsKey.notchAirDropEnabled,
                    DefaultsKey.notchPhotoActionsEnabled, DefaultsKey.designOverlayDropEnabled]
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: keys),
                     "the zones and the switches they grew out of travel with settings backups")
        let defaults = freshDefaults()
        ZenithDropZones.save(.standard, in: defaults)
        suite.expect(defaults.persistentDomain(forName: suiteName)?.isEmpty ?? true,
                     "saving the zones unchanged writes nothing")
        let next = ZenithDropZones.standard.setting(.removeBackground, on: false).setting(.airDrop, on: false)
            .moving(.overlay, to: 1)
        ZenithDropZones.save(next, in: defaults)
        suite.expect(defaults.string(forKey: DefaultsKey.zenithDropZones) == next.encoded
                        && ZenithDropZones.current(in: defaults) == next,
                     "saved zones read back as they were")
        // The stored values alone: other suites register the app's defaults in this process.
        let written = defaults.persistentDomain(forName: suiteName) ?? [:]
        suite.expect(written[DefaultsKey.notchAirDropEnabled] as? Bool == false
                        && written[DefaultsKey.designOverlayDropEnabled] == nil
                        && written[DefaultsKey.notchPhotoActionsEnabled] == nil,
                     "the earlier switches move with the zones, and only those that changed are written")
        ZenithDropZones.save(next.setting(.transform, on: false), in: defaults)
        suite.expect(defaults.object(forKey: DefaultsKey.notchPhotoActionsEnabled) as? Bool == false,
                     "with Transform and Remove Background both off, the photo actions switch reads off")
        // A backup written before the card has only the earlier switches;
        // importing it clears the list, and the zones follow those switches.
        defaults.removeObject(forKey: DefaultsKey.zenithDropZones)
        defaults.set(true, forKey: DefaultsKey.notchAirDropEnabled)
        let restored = ZenithDropZones.current(in: defaults)
        suite.expect(restored.isOn(.airDrop) && !restored.isOn(.transform) && restored.order == ZenithDropZones.defaultOrder,
                     "an older backup restores the zones its switches describe")
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: Drags

    private static func drags(_ suite: TestSuite) {
        let zones = ZenithDropZones.standard
        suite.expect(zones.targets(for: .otherFiles) == [.files, .airDrop],
                     "any file gets Files and AirDrop")
        suite.expect(zones.targets(for: .mediaFiles) == [.files, .airDrop, .media],
                     "media files add Optimize media")
        suite.expect(zones.targets(for: .images(3)) == [.files, .airDrop, .media, .transform],
                     "several images add Transform")
        suite.expect(zones.targets(for: .oneImage) == ZenithDropZones.defaultOrder,
                     "one image gets every zone, Remove Background and Overlay with it")
        suite.expect(zones.targets(for: .images(NotchPhotoActionsSupport.maximumItems + 1)) == [.files, .airDrop, .media],
                     "more images than Transform takes stay with the other zones")
        suite.expect(zones.targets(for: ZenithDropDrag(files: false, media: false, images: 0)) == [.files],
                     "something that is not a file (a note, a link) only goes to the shelf")
        let noCutout = zones.setting(.removeBackground, on: false)
        suite.expect(noCutout.targets(for: .oneImage) == [.files, .airDrop, .media, .transform, .overlay]
                        && noCutout.targets(for: .images(3)) == zones.targets(for: .images(3)),
                     "Remove Background off leaves it out and nothing else")
        suite.expect(zones.setting(.transform, on: false).targets(for: .oneImage).contains(.removeBackground),
                     "Remove Background stands without Transform")
        suite.expect(zones.setting(.files, on: false).targets(for: .mediaFiles) == [.airDrop, .media],
                     "Optimize media stays with Files off")
        suite.expect(zones.targets(for: .oneImage, shelf: false) == [.airDrop, .transform, .removeBackground, .overlay],
                     "without the shelf, Files and Optimize media are gone")
        suite.expect(zones.targets(for: .oneImage, mediaTools: false).contains(.media) == false,
                     "without the media tools, Optimize media is gone")
        suite.expect(zones.targets(for: .oneImage, filesPage: false) == [.files, .airDrop, .media],
                     "without the island’s Files page, an image gets no image zones")
        suite.expect(!zones.targets(for: .oneImage, overlayAvailable: false).contains(.overlay),
                     "without the screenshot tool, no Overlay")
        let reordered = zones.moving(.overlay, to: 0).moving(.removeBackground, to: 1)
        suite.expect(reordered.targets(for: .oneImage) == [.overlay, .removeBackground, .files, .airDrop, .media, .transform]
                        && reordered.targets(for: .otherFiles) == [.files, .airDrop],
                     "a drag gets its zones in the chosen order")
        suite.expect(zones.imageTargets(imageCount: 1, overlayAvailable: true) == [.transform, .removeBackground, .overlay]
                        && zones.setting(.overlay, on: false).imageTargets(imageCount: 1, overlayAvailable: true)
                            == [.transform, .removeBackground]
                        && zones.imageTargets(imageCount: 0, overlayAvailable: true).isEmpty,
                     "an image’s own zones follow their switches")
    }

    // MARK: Widening

    private static func widening(_ suite: TestSuite) {
        typealias Layout = ZenithDropZoneLayout
        suite.expect(Layout.contentWidth(count: 2, maximum: 2000) == nil && Layout.contentWidth(count: 0, maximum: 2000) == nil,
                     "one or two zones keep the island’s width")
        suite.expect(Layout.contentWidth(count: 5, maximum: 2000) == 5 * 124 + 4 * 12
                        && Layout.contentWidth(count: 6, maximum: 2000) == 6 * 124 + 5 * 12,
                     "three zones or more ask for 124 points each, 12 apart")
        suite.expect(Layout.contentWidth(count: 6, maximum: 780) == 780 && Layout.rows(count: 6, width: 780) == 1,
                     "short of room, one row still holds them while each gets 116 points")
        let wrapped = Layout.contentWidth(count: 6, maximum: 700)
        suite.expect(wrapped == 3 * 124 + 2 * 12 && Layout.rows(count: 6, width: wrapped ?? 0) == 2,
                     "where even the widest island cannot, they wrap into two rows of comfortable tiles")
        suite.expect(Layout.contentWidth(count: 5, maximum: 300) == 300,
                     "never wider than the display allows")

        let compact = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 32, cameraWidth: 180)
        var five = compact
        five.zenithDropZoneCount = 5
        suite.expect(five.contentWidth == 668 && five.expandedWidth == 668 + NotchLayout.horizontalInset * 2,
                     "five zones widen a compact island to a comfortable tile each: \(five.contentWidth)")
        // Zenith fork: the island fits the zones' rows, so they sit on its padding line below.
        let block = Layout.blockHeight(count: 5, width: five.contentWidth)
        suite.expect(block == (124 * Layout.tileAspect).rounded() && block < compact.contentBudget
                        && five.expandedSize(module: .files).height
                            == compact.expandedSize(module: .files).height - compact.contentBudget + block,
                     "a drag choosing a zone fits the island to the zones' row: \(block)")
        suite.expect(Layout.frames(count: 5, in: CGSize(width: five.contentWidth, height: block))
                        .allSatisfy { $0.minY == 0 && $0.maxY == block },
                     "the zones fill the page they fit, from its top to the padding line")
        suite.expect(Layout.blockHeight(count: 6, width: 396) == 2 * (124 * Layout.tileAspect).rounded() + Layout.spacing
                        && Layout.blockHeight(count: 0, width: 400) == 0 && Layout.blockHeight(count: 3, width: 0) == 0,
                     "two rows add their gap; no zones or no room take no height")
        var three = compact
        three.zenithDropZoneCount = 3
        var two = compact
        two.zenithDropZoneCount = 2
        suite.expect(three.expandedWidth == compact.expandedWidth && two.expandedWidth == compact.expandedWidth,
                     "zones that already fit leave the island as it was")
        var spacious = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 32,
                                     cameraWidth: 180, layout: .spacious)
        let spaciousWidth = spacious.expandedWidth
        spacious.zenithDropZoneCount = 3
        suite.expect(spacious.expandedWidth == spaciousWidth,
                     "a wider chosen island is never narrowed for the zones")
        let maximum = 780 + NotchLayout.horizontalInset * 2 + 24 + NotchQuickAccessLayout.gutter * 2
        var tight = NotchGeometry(screen: CGRect(x: 0, y: 0, width: maximum, height: 900), safeAreaTop: 32, cameraWidth: 180)
        tight.zenithDropZoneCount = 6
        suite.expect(tight.expandedWidth == maximum - 24 - NotchQuickAccessLayout.gutter * 2 && tight.contentWidth == 780
                        && tight.zenithDropMaximumContentWidth == 780,
                     "widening stops at the display’s edge, as every island does: \(tight.contentWidth)")
        var small = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 700), safeAreaTop: 32, cameraWidth: 180)
        let smallWidth = small.expandedWidth
        small.zenithDropZoneCount = 6
        suite.expect(small.expandedWidth == smallWidth && Layout.rows(count: 6, width: small.contentWidth) == 2,
                     "a small display keeps the island and wraps six zones into two rows")
        var closed = compact
        closed.zenithDropZoneCount = 0
        suite.expect(closed == compact, "no drag, no change")
    }

    private static func tiles(_ suite: TestSuite) {
        typealias Layout = ZenithDropZoneLayout
        let page = CGSize(width: 668, height: 180)
        let frames = Layout.frames(count: 5, in: page)
        suite.expect(frames.count == 5 && frames.allSatisfy { abs($0.width - 124) < 0.01 && $0.height <= $0.width },
                     "five tiles of 124 points, landscape or square: \(frames.map(\.size))")
        suite.expect(frames.allSatisfy { CGRect(origin: .zero, size: page).contains($0) }
                        && zip(frames, frames.dropFirst()).allSatisfy { abs($1.minX - $0.maxX - 12) < 0.01 && $0.minY == $1.minY },
                     "on one row, 12 points apart, inside the page")
        suite.expect(abs(frames[0].minY - (page.height - frames[0].height) / 2) < 0.01,
                     "the row sits in the middle of the page")
        let wrapped = Layout.frames(count: 5, in: CGSize(width: 396, height: 180))
        let rows = Set(wrapped.map(\.minY)).sorted()
        suite.expect(rows.count == 2 && wrapped.filter { $0.minY == rows[0] }.count == 3
                        && wrapped.filter { $0.minY == rows[1] }.count == 2
                        && wrapped.allSatisfy { $0.height <= $0.width && $0.height >= 60 },
                     "wrapped, three tiles over two, each still landscape: \(wrapped)")
        let lower = wrapped.filter { $0.minY == rows[1] }
        suite.expect(abs((lower[0].minX + lower[1].maxX) / 2 - 198) < 0.01 && abs(rows[1] - rows[0] - wrapped[0].height - 12) < 0.01,
                     "a short last row is centred, 12 points below the first")
        let two = Layout.frames(count: 2, in: CGSize(width: 424, height: 180))
        suite.expect(two.count == 2 && abs(two[0].width - 206) < 0.01 && two[0].height == 180,
                     "two zones share the island’s page as before")
        suite.expect(Layout.frames(count: 0, in: page).isEmpty && Layout.frames(count: 3, in: .zero).isEmpty,
                     "no zones or no room draws nothing")
    }

    // MARK: Hit-testing

    private static func hitTesting(_ suite: TestSuite) {
        typealias Layout = ZenithDropZoneLayout
        for (count, size) in [(5, CGSize(width: 668, height: 180)), (6, CGSize(width: 396, height: 180)),
                              (2, CGSize(width: 424, height: 180)), (3, CGSize(width: 424, height: 264))] {
            let frames = Layout.frames(count: count, in: size)
            suite.expect(frames.indices.allSatisfy { Layout.index(at: CGPoint(x: frames[$0].midX, y: frames[$0].midY),
                                                                   count: count, in: size) == $0 },
                         "the centre of every tile finds that tile (\(count) zones in \(size))")
        }
        let page = CGSize(width: 668, height: 180)
        let frames = Layout.frames(count: 5, in: page)
        suite.expect(Layout.index(at: CGPoint(x: frames[1].maxX + 2, y: 90), count: 5, in: page) == 1
                        && Layout.index(at: CGPoint(x: frames[2].minX - 2, y: 90), count: 5, in: page) == 2,
                     "a point in a gap goes to the closer tile")
        suite.expect(Layout.index(at: CGPoint(x: -40, y: -40), count: 5, in: page) == 0
                        && Layout.index(at: CGPoint(x: 900, y: 400), count: 5, in: page) == 4
                        && Layout.index(at: CGPoint(x: frames[3].midX, y: 2), count: 5, in: page) == 3,
                     "a point past an edge, or above the row, finds the tile along it")
        let wrappedSize = CGSize(width: 396, height: 180)
        suite.expect(Layout.index(at: CGPoint(x: 198, y: 170), count: 5, in: wrappedSize) >= 3
                        && Layout.index(at: CGPoint(x: 20, y: 5), count: 5, in: wrappedSize) == 0,
                     "two rows: low on the page is the second row, high the first")

        // The drop's own test, in the island's coordinates, on a widened island.
        let targets = ZenithDropZones.defaultOrder
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 32, cameraWidth: 180)
        geometry.zenithDropZoneCount = targets.count
        for geometry in [geometry, smallGeometry(count: targets.count)] {
            let size = geometry.expandedSize(module: .files)
            let content = geometry.contentSize(for: size)
            let origin = CGPoint(x: size.width / 2 - content.width / 2, y: geometry.pageTopInset)
            let tiles = Layout.frames(count: targets.count, in: content)
            suite.expect(tiles.indices.allSatisfy { index in
                NotchAirDropSupport.target(at: CGPoint(x: origin.x + tiles[index].midX, y: origin.y + tiles[index].midY),
                                           in: geometry, size: size, targets: targets) == targets[index]
            }, "the island lands a drop on the tile drawn under it (\(Set(tiles.map(\.minY)).count) rows)")
            suite.expect(NotchAirDropSupport.target(at: CGPoint(x: -5, y: 10), in: geometry, size: size, targets: targets) == .files,
                         "the island’s far left edge is the first zone")
        }
        suite.expect(NotchAirDropSupport.target(at: .zero, in: geometry, size: .zero, targets: [.airDrop]) == .airDrop
                        && NotchAirDropSupport.target(at: .zero, in: geometry, size: .zero, targets: []) == .files,
                     "a single zone takes the whole island")
    }

    private static func smallGeometry(count: Int) -> NotchGeometry {
        var small = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1000, height: 700), safeAreaTop: 32, cameraWidth: 180)
        small.zenithDropZoneCount = count
        return small
    }

    // MARK: Words

    private static func strings(_ suite: TestSuite) {
        let font = NSFont.systemFont(ofSize: 12.5, weight: .medium)
        // A tile at its narrowest, less its padding.
        let room = ZenithDropZoneLayout.minimumTileWidth - 20
        for language in AppLanguage.allCases {
            let text = ZenithStrings.dropZones(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 15 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words every drop zone string, with curly apostrophes and no em dash")
            for target in NotchDropTarget.allCases {
                let full = target.zenithTitle(language)
                let short = target.zenithShortTitle(language)
                let width = (short as NSString).size(withAttributes: [.font: font]).width
                suite.expect(!full.isEmpty && !short.isEmpty && short.count <= full.count && width <= room,
                             "\(language.rawValue) \(target.rawValue): “\(short)” fits one line of a tile (\(Int(width)) pt)")
                suite.expect(!target.zenithWhen(language).isEmpty, "\(language.rawValue) says when \(target.rawValue) shows")
            }
        }
        suite.expect(NotchDropTarget.removeBackground.zenithShortTitle(.enUS) == "Remove BG"
                        && NotchDropTarget.removeBackground.zenithTitle(.enUS) == "Remove Background",
                     "Remove Background keeps its full name for the tooltip and shortens on the tile")
        suite.expect(Set(NotchDropTarget.allCases.map(\.zenithTintHex)).count == NotchDropTarget.allCases.count
                        && Set(NotchDropTarget.allCases.map(\.zenithSymbol)).count == NotchDropTarget.allCases.count,
                     "every zone has its own colour and glyph")
    }
}
