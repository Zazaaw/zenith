// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the selftest's check that every grown island's own view fits
/// the island its layout measured, offscreen, with the longest words in every
/// language (ZenithIslandFitSamples): the bursts, the lock screen's grown
/// padlock island and the capsule notices. On one line a row's ideal width is
/// within the room the island leaves it; on two, it is no taller than its
/// row and would not take a third line given one.
@MainActor
enum IslandFitCheck {
    static func failures() -> [String] {
        var failures: [String] = []
        for language in AppLanguage.allCases {
            for (name, burst) in ZenithIslandFitSamples.bursts(language) {
                for (place, geometry) in [("notch", notched), ("capsule", capsule)] {
                    let fit = ZenithIslandBurstLayout.fit(burst, geometry: geometry)
                    if let problem = check(ZenithIslandBurstRow(burst: burst, lines: fit.lines),
                                           roomier: ZenithIslandBurstRow(burst: burst, lines: fit.lines + 1),
                                           content: fit.content,
                                           height: ZenithIslandBurstLayout.contentHeight(burst, lines: fit.lines),
                                           lines: fit.lines) {
                        failures.append("burst \(name) \(language.rawValue) \(place): \(problem)")
                    }
                }
            }
        }
        for device in ["Faiz’s iPhone", ZenithIslandFitSamples.device] {
            let camera: CGFloat = 37
            let fit = ZenithLockIsland.remoteFit(device: device, camera: camera, resting: 285, screenWidth: 1800)
            let height = ZenithLockIsland.grownHeight(camera: camera, lines: fit.lines) - camera
                - ZenithIslandInset.belowCamera - ZenithIslandInset.padding
            if let problem = check(ZenithLockRemoteRow(device: device, lines: fit.lines),
                                   roomier: ZenithLockRemoteRow(device: device, lines: fit.lines + 1),
                                   content: fit.content, height: height, lines: fit.lines) {
                failures.append("lock screen remote \(device): \(problem)")
            }
        }
        for (name, notice) in capsules() {
            let measured = ZenithNoticeMeasure.content(notice)
            let fit = ZenithNoticeLayout.fit(fixed: measured.fixed, title: measured.title, subtitle: measured.subtitle,
                                             closedWidth: 0, screenWidth: notched.screen.width, floats: false)
            let height = ZenithIslandInset.height(content: ZenithNoticeLayout.rowHeight(lines: fit.lines, floats: false),
                                                  strip: notched.stripHeight)
            // The row runs between the capsule's shoulders; the view keeps the edge itself.
            let content = fit.width - NotchLayout.plainShoulder(height: height) * 2
            func view(_ lines: Int) -> ZenithNoticeContent {
                ZenithNoticeContent(notice: notice, shown: true, reduceMotion: true, thumbnail: nil, lines: lines)
            }
            if let problem = check(view(fit.lines), roomier: view(fit.lines + 1), content: content,
                                   height: ZenithNoticeLayout.rowHeight(lines: fit.lines, floats: false), lines: fit.lines,
                                   flexibleHeight: true) {
                failures.append("capsule \(name): \(problem)")
            }
        }
        return failures
    }

    /// What is wrong with `row` in `content` points by `height`, if anything.
    /// A row that fills its height (a capsule's content) is only checked for
    /// its width and lines.
    private static func check<Row: View, Roomier: View>(_ row: Row, roomier: Roomier, content: CGFloat, height: CGFloat,
                                                         lines: Int, flexibleHeight: Bool = false) -> String? {
        if lines == 1 {
            let ideal = size(row.fixedSize())
            if ideal.width > content + 0.5 { return "\(ideal.width.rounded()) points wide in \(content.rounded())" }
            if !flexibleHeight, ideal.height > height + 0.5 { return "\(ideal.height) points tall in \(height)" }
            return nil
        }
        let fitted = size(row.frame(width: content).fixedSize(horizontal: false, vertical: true))
        let open = size(roomier.frame(width: content).fixedSize(horizontal: false, vertical: true))
        if !flexibleHeight, fitted.height > height + 0.5 { return "\(fitted.height) points tall in \(height)" }
        if open.height > fitted.height + 0.5 { return "needs more than \(lines) lines in \(content.rounded()) points" }
        return nil
    }

    private static func size<V: View>(_ view: V) -> CGSize {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
        return host.fittingSize
    }

    private static let notched: NotchGeometry = {
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1800, height: 1169), safeAreaTop: 37,
                                     cameraWidth: 205, layout: .spacious)
        geometry.compactSideRoom = 280
        return geometry
    }()

    private static let capsule: NotchGeometry = {
        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080), safeAreaTop: 0, cameraWidth: 0,
                                     layout: .spacious, menuBarHeight: 24, silhouette: .capsule, barEdge: 0.5)
        geometry.compactSideRoom = 280
        return geometry
    }()

    /// The capsule notices, worded at their longest.
    private static func capsules() -> [(String, ZenithNotice)] {
        let text = ZenithStrings.notices(L10n.shared.language)
        let download = URL(fileURLWithPath: "/Users/Shared/Downloads/Brand-Guidelines-2026-final-final-approved-v12.pdf")
        let export = URL(fileURLWithPath: "/Users/Shared/Exports/Wedding-Teaser-Raka-Dina-4K-HDR-final.mov")
        return [
            ("audio", ZenithNotice(kind: .audio, key: ZenithNoticeKey.audio("long"), title: ZenithIslandFitSamples.device,
                                   subtitle: text.connected, glyph: .symbol("airpodspro", .white),
                                   accessory: .ring(percent: 100, tone: .green))),
            ("download", ZenithNotice(kind: .download, key: ZenithNoticeKey.download(download),
                                      title: download.lastPathComponent,
                                      subtitle: ZenithNoticeFormat.downloadDetail(bytes: 38_400_000_000, folder: "Downloads"),
                                      glyph: .symbol("doc.richtext.fill", .accent), accessory: .checkmark,
                                      action: .reveal(download))),
            ("export", ZenithNotice(kind: .export, key: ZenithNoticeKey.export("long"), title: "Export finished",
                                    subtitle: export.lastPathComponent + " · 24.4 GB",
                                    glyph: .symbol("film.stack", .hex(0xF2994A)), accessory: .checkmark, action: .reveal(export))),
            ("card", ZenithNotice(kind: .card, key: ZenithNoticeKey.cardBackup, title: "12 events not backed up",
                                  subtitle: "Wedding Raka & Dina · Company profile · Graduation SMA 3 · Pensi 2026",
                                  glyph: .symbol("externaldrive.badge.exclamationmark", .amber),
                                  accessory: .action("Back up"), action: .backUpCards)),
            ("workspace", ZenithNotice(kind: .workspace, key: ZenithNoticeKey.workspace("long"),
                                       title: "Coding workspace ready",
                                       subtitle: "Visual Studio Code · Terminal · Figma · Linear · Arc · Slack · Notion",
                                       glyph: .symbol("hammer.fill", .hex(0x5B8DEF)), accessory: .checkmark)),
        ]
    }
}
