// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: every grown island fits its words. A burst's island is
/// measured from the same pieces and gaps its view draws, wide enough for
/// its row on one line up to the widest island, then with the subtitle on a
/// second line; never truncated, never under the camera. The selftest checks
/// the views themselves against these measures.
enum IslandFitTests {
    static func run(_ suite: TestSuite) {
        remoteStatus(suite)
        everyBurst(suite)
        lockScreen(suite)
    }

    /// A 14-inch MacBook Pro's camera, about 205 by 37 points.
    static let notched: NotchGeometry = {
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1800, height: 1169), safeAreaTop: 37,
                                     cameraWidth: 205, layout: .spacious)
        geometry.compactSideRoom = 280
        return geometry
    }()

    static let smaller = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                       cameraWidth: 185, layout: .spacious, menuBarHeight: 32)

    static let capsule: NotchGeometry = {
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0, cameraWidth: 0,
                                     layout: .spacious, menuBarHeight: 24, silhouette: .capsule, barEdge: 0.5)
        geometry.compactSideRoom = 280
        return geometry
    }()

    private typealias Layout = ZenithIslandBurstLayout

    private static func remoteStatus(_ suite: TestSuite) {
        let burst = ZenithIslandBurst(.remote(ZenithRemoteBurst(device: "Faiz’s iPhone")), start: Date(timeIntervalSince1970: 0))
        let row = Layout.row(burst)
        let device = Layout.words("Faiz’s iPhone", Layout.chargeTitleFont)
        let detail = Layout.words(RemoteText.checkedStatus, Layout.remoteDetailFont)
        // The view draws: the iPhone, a gap, the name, a gap, what it did, at least a column's gap, the eye.
        let drawn = Layout.remoteGlyph + Layout.remoteGap + device + Layout.remoteWordGap + detail + Layout.columnGap
            + Layout.remoteGlyph
        suite.expect(abs(row.width - drawn) < 0.001,
                     "the status row is measured with every piece and gap its view draws: \(row.width) vs \(drawn)")
        let fit = Layout.fit(burst, geometry: notched)
        suite.expect(fit.lines == 1 && row.fits(fit.content, lines: 1),
                     "“Faiz’s iPhone checked status” fits one line: \(fit)")
        suite.expect(fit.size.height == notched.stripHeight + ZenithIslandInset.belowCamera + Layout.remoteRow
                        + ZenithIslandInset.padding && ZenithIslandInset.padding == 20
                        && Layout.rowTop(geometry: notched) >= notched.stripHeight,
                     "the island drops just enough for one row below the camera, with 20 points below it")
        let shoulder = NotchLayout.shoulder(height: fit.size.height)
        suite.expect(abs(fit.size.width - 2 * (ZenithIslandRoom.edge + shoulder) - fit.content) < 0.001
                        && ZenithIslandRoom.edge == 20,
                     "20 points of room beside the row, past the shoulders")
    }

    private static func everyBurst(_ suite: TestSuite) {
        var failures: [String] = []
        for language in AppLanguage.allCases {
            for (name, burst) in ZenithIslandFitSamples.bursts(language) {
                for (place, geometry) in [("notch", notched), ("small notch", smaller), ("capsule", capsule)] {
                    let fit = Layout.fit(burst, geometry: geometry)
                    let row = Layout.row(burst)
                    let underCamera = !geometry.floats && Layout.rowTop(geometry: geometry) < geometry.stripHeight
                    if !row.fits(fit.content, lines: fit.lines) || fit.lines > 2 || underCamera
                        || fit.size.width > ZenithIslandRoom.maximumWidth + 0.5 {
                        failures.append("\(language.rawValue) \(name) \(place): row \(row) in \(fit)")
                    }
                }
            }
        }
        suite.expect(failures.isEmpty, "every burst fits its island in every language: \(failures.prefix(6))")
        let long = ZenithIslandBurst(.agent(ZenithAgentBurst(provider: .claude, title: "Claude needs you",
                                                             subtitle: String(repeating: "folder-", count: 14))),
                                     start: Date(timeIntervalSince1970: 0))
        let fit = Layout.fit(long, geometry: notched)
        suite.expect(fit.lines == 2 && fit.size.width == ZenithIslandRoom.maximumWidth
                        && fit.size.height == Layout.size(long, geometry: notched).height
                        && fit.size.height - Layout.contentHeight(long) - Layout.rowTop(geometry: notched)
                            - ZenithIslandInset.padding == Layout.lineHeight,
                     "past the widest island the subtitle takes a second line and the row grows by one: \(fit)")
    }

    private static func lockScreen(_ suite: TestSuite) {
        let camera: CGFloat = 37, resting: CGFloat = 205 + 2 * 40
        var failures: [String] = []
        for device in ["Faiz’s iPhone", ZenithIslandFitSamples.device] {
            let fit = ZenithLockIsland.remoteFit(device: device, camera: camera, resting: resting, screenWidth: 1800)
            let row = ZenithLockIsland.remoteRow(device: device)
            if !row.fits(fit.content, lines: fit.lines) || fit.size.width < resting
                || fit.size.width > ZenithIslandRoom.maximumWidth + 0.5
                || fit.size.height != ZenithLockIsland.grownHeight(camera: camera, lines: fit.lines) {
                failures.append("\(device): \(fit)")
            }
        }
        suite.expect(failures.isEmpty, "“Locked from …” grows the padlock island into two lines below the camera: \(failures)")
        let short = ZenithLockIsland.remoteFit(device: "Faiz’s iPhone", camera: camera, resting: resting, screenWidth: 1800)
        suite.expect(short.size.height == camera + ZenithIslandInset.belowCamera + Layout.welcomeRow + ZenithIslandInset.padding
                        && short.lines == 1,
                     "its words sit below the camera, with the island's padding below them: \(short)")
        let surface = CGRect(x: 900 - resting / 2, y: 1169 - camera, width: resting, height: camera)
        let window = ZenithLockIsland.windowFrame(around: surface, in: CGRect(x: 0, y: 0, width: 1800, height: 1169))
        let tallest = ZenithLockIsland.grownHeight(camera: camera, lines: 2)
        suite.expect(window.width >= ZenithIslandRoom.maximumWidth + 2 * ZenithIslandMotion.widthSwingLimit
                        && window.height >= tallest + ZenithIslandMotion.heightSwingLimit && window.maxY == 1169,
                     "the padlock island's window holds the grown island and its swing: \(window)")
        let overflowing = AppLanguage.allCases.filter {
            ZenithIslandRoom.measure(ZenithIslandFitSamples.farewell($0), font: .systemFont(ofSize: 13, weight: .semibold)) + 2
                + ZenithLockIsland.wingInset * 2 > ZenithLockIsland.maximumWing
        }
        suite.expect(overflowing.isEmpty, "the farewell fits its wing beside the camera in every language: \(overflowing)")
        suite.expect(ZenithLockIsland.handsOver(pill: CGSize(width: resting, height: camera))
                        && !ZenithLockIsland.handsOver(pill: .zero)
                        && !ZenithLockIsland.handsOver(pill: CGSize(width: CGFloat.nan, height: camera)),
                     "the island takes over from a padlock pill with a size to start from")
    }
}
