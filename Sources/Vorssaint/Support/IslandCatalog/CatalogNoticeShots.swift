// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the island catalog's notices, the small ones that take the
/// closed island's wings and the capsules that grow below it.
@MainActor
extension CatalogShots {
    static func notice(_ id: String, _ notice: NotchNotice, preferences: [String: Any] = [:], mascot: Bool = false,
                       expanded: Bool = false, setup: @escaping @MainActor () -> Void = {}) -> CatalogShot {
        CatalogShot(id: id, preferences: preferences, setup: setup) {
            island(pose {
                $0.notice = notice
                $0.noticeExpanded = expanded
                $0.mascot = mascot
            })
        }
    }

    static let sampleNotification = NotchNotificationContent(app: "Messages", title: "Raka",
                                                             subtitle: "", body: "Sudah lihat revisi logonya? Aku suka yang versi biru.")
    static let notificationID = UUID(uuidString: "6F1D8E0C-5A54-4C38-9F0E-2B7E4C1A9D11")!

    static var notices: [CatalogShot] {
        let language = AppLanguage.enUS
        let notch = FeatureStrings.notch(language)
        let files = FeatureStrings.notchFiles(language)
        let clipboard = FeatureStrings.clipboard(language)
        let agents = FeatureStrings.notchAgents(language)
        let strings = Strings.localized(language)
        return [
            notice("notice-volume", NotchNotice(event: .volume, title: notch.volume, detail: "62%",
                                                symbol: "speaker.wave.2.fill", level: 0.62)),
            notice("notice-brightness", NotchNotice(event: .brightness, title: notch.brightness, detail: "80%",
                                                    symbol: "sun.max.fill", level: 0.8)),
            notice("notice-keyboard-light", NotchNotice(event: .keyboardLight,
                                                        title: FeatureStrings.brightness(language).keyboardLight,
                                                        detail: "40%", symbol: "keyboard", level: 0.4)),
            notice("notice-battery", NotchNotice(event: .battery, title: notch.charging, detail: "54%",
                                                 symbol: "battery.100percent.bolt")),
            notice("notice-clipboard", NotchNotice(event: .clipboard, title: clipboard.copied, detail: clipboard.title,
                                                   symbol: "doc.on.clipboard")),
            notice("notice-download", NotchNotice(event: .download, title: files.completed, detail: "Brand-Guidelines-2026.pdf",
                                                  symbol: "arrow.down.circle.fill", mascot: .celebrate),
                   preferences: [DefaultsKey.notchMascotEnabled: true], mascot: true),
            notice("notice-timer", NotchNotice(event: .timer, title: FeatureStrings.notchActivities(language).finished,
                                               detail: FeatureStrings.notchActivities(language).phase(.timer), symbol: "timer")),
            notice("notice-accessory", NotchNotice(event: .accessory, title: "AirPods Pro", detail: "Connected",
                                                   symbol: "airpodspro")),
            notice("notice-agent-finished", NotchNotice(event: .agents, title: agents.finished("Claude"),
                                                        detail: "4 min · $0.62", symbol: AgentProvider.claude.symbol,
                                                        agent: .claude)),
            notice("notice-agent-limit", NotchNotice(event: .agents, title: "Claude · \(agents.session)",
                                                     detail: "80% used", symbol: "exclamationmark.triangle.fill",
                                                     agent: .claude)),
            notice("notice-track", NotchNotice(event: .track, title: ZenithLockScreenPreviewSample.title,
                                               detail: ZenithLockScreenPreviewSample.artist, symbol: "music.note"),
                   preferences: [DefaultsKey.notchIdleContent: NotchIdleContent.music.rawValue]) { CatalogSamples.music() },
            notice("notice-microphone", NotchNotice(event: .microphone, title: "", detail: strings.micMutedHUD,
                                                    symbol: "mic.slash.fill")),
            notice("notice-input-source", NotchNotice(event: .inputSource, title: "ABC", detail: "U.S.", symbol: "keyboard")),
            notice("notice-notification", NotchNotice(event: .systemNotification, title: sampleNotification.title,
                                                      detail: sampleNotification.body, symbol: "bell.fill",
                                                      notification: sampleNotification, notificationID: notificationID)),
            notice("notice-notification-open", NotchNotice(event: .systemNotification, title: sampleNotification.title,
                                                           detail: sampleNotification.body, symbol: "bell.fill",
                                                           notification: sampleNotification, notificationID: notificationID),
                   expanded: true),
        ] + capsules
    }

    // MARK: Capsules (ZenithNotice)

    static func capsuleNotice(_ id: String, _ make: @escaping @MainActor () -> ZenithNotice) -> CatalogShot {
        CatalogShot(id: id) {
            NotchService.shared.catalogPose(pose())
            let center = ZenithNoticeCenter.shared
            center.catalogPose(make())
            return (AnyView(ZenithNoticeRoot(center: center)), center.panelSize)
        }
    }

    static var capsules: [CatalogShot] {
        let text = ZenithStrings.notices(.enUS)
        return [
            capsuleNotice("capsule-battery-low") {
                ZenithNotice(kind: .batteryLow, key: ZenithNoticeKey.batteryLow,
                             title: ZenithNoticeFormat.filling(text.batteryTitle, percent: 20),
                             subtitle: text.lowPowerAction, accessory: .lowPower(on: false), action: .batterySettings)
            },
            capsuleNotice("capsule-battery-critical") {
                ZenithNotice(kind: .batteryCritical, key: ZenithNoticeKey.batteryLow,
                             title: ZenithNoticeFormat.filling(text.batteryTitle, percent: 10),
                             subtitle: text.lowPowerOn, accessory: .lowPower(on: true), action: .batterySettings)
            },
            capsuleNotice("capsule-charging") {
                ZenithNotice(kind: .charging, key: ZenithNoticeKey.power,
                             title: ZenithNoticeFormat.titled(text.charging, percent: 54), subtitle: text.chargerConnected,
                             glyph: .symbol("bolt.fill", .green), accessory: .ring(percent: 54, tone: .green))
            },
            capsuleNotice("capsule-charge-limit") {
                ZenithNotice(kind: .chargeLimit, key: ZenithNoticeKey.chargeLimit,
                             title: ZenithNoticeFormat.titled(text.charging, percent: 80), subtitle: text.chargeHint,
                             glyph: .symbol("leaf.fill", .green), accessory: .ring(percent: 80, tone: .green))
            },
            capsuleNotice("capsule-unplugged") {
                ZenithNotice(kind: .unplugged, key: ZenithNoticeKey.power,
                             title: ZenithNoticeFormat.titled(text.onBattery, percent: 76), subtitle: text.chargerRemoved,
                             glyph: .symbol("powerplug", .white), accessory: .ring(percent: 76, tone: ZenithNoticeFormat.batteryTone(76)))
            },
            capsuleNotice("capsule-audio") {
                ZenithNotice(kind: .audio, key: ZenithNoticeKey.audio("AirPods Pro"), title: "AirPods Pro",
                             subtitle: text.connected, glyph: .symbol("airpodspro", .white),
                             accessory: .ring(percent: 85, tone: ZenithNoticeFormat.batteryTone(85)))
            },
            capsuleNotice("capsule-download") {
                let url = URL(fileURLWithPath: "/Users/Shared/Downloads/Brand-Guidelines-2026.pdf")
                return ZenithNotice(kind: .download, key: ZenithNoticeKey.download(url), title: "Brand-Guidelines-2026.pdf",
                                    subtitle: ZenithNoticeFormat.downloadDetail(bytes: 38_400_000, folder: "Downloads"),
                                    glyph: .symbol("doc.richtext.fill", .accent), accessory: .checkmark, action: .reveal(url))
            },
            capsuleNotice("capsule-card") {
                ZenithNotice(kind: .card, key: ZenithNoticeKey.card("SONY-A7S"), title: "SONY A7S III card",
                             subtitle: "412 files · 48 GB",
                             glyph: .symbol("sdcard.fill", .tint(NotchModule.cardImport)),
                             accessory: .action(ZenithStrings.cardImport(.enUS).importAction), action: .importCard("SONY-A7S"))
            },
            capsuleNotice("capsule-card-backup") {
                ZenithNotice(kind: .card, key: ZenithNoticeKey.cardBackup, title: "2 events not backed up",
                             subtitle: "Wedding Raka & Dina · Company profile",
                             glyph: .symbol("externaldrive.badge.exclamationmark", .amber),
                             accessory: .action("Back up"), action: .backUpCards)
            },
            capsuleNotice("capsule-export") {
                let url = URL(fileURLWithPath: "/Users/Shared/Exports/Wedding-Teaser-4K.mov")
                return ZenithNotice(kind: .export, key: ZenithNoticeKey.export("catalog"), title: "Export finished",
                                    subtitle: "Wedding-Teaser-4K.mov · 2.4 GB",
                                    glyph: .symbol("film.stack", .hex(0xF2994A)), accessory: .checkmark, action: .reveal(url))
            },
            capsuleNotice("capsule-dev-server") {
                let server = CatalogSamples.servers[0]
                let strings = ZenithStrings.devServers(.enUS)
                return ZenithNotice(kind: .devServer, key: ZenithNoticeKey.devServer(server.id),
                                    title: DevServersFormat.noticeTitle(server), subtitle: strings.started,
                                    glyph: .symbol(NotchModule.devServers.zenithIconSymbol, .tint(NotchModule.devServers)),
                                    accessory: .action(strings.open), action: .openURL(server.url!))
            },
            capsuleNotice("capsule-recap") {
                ZenithNotice(kind: .recap, key: ZenithNoticeKey.recap("catalog"), title: ZenithStrings.recap(.enUS).yourDay,
                             subtitle: "5h 12m coded · 14 commits · 3 deploys",
                             glyph: .symbol(NotchModule.recap.zenithIconSymbol, .tint(NotchModule.recap)),
                             accessory: .action(ZenithStrings.recap(.enUS).open), action: .openRecap)
            },
            capsuleNotice("capsule-prayer") {
                let sky = ZenithStrings.sky(.enUS)
                return ZenithNotice(kind: .prayer, key: ZenithNoticeKey.prayer("asr"),
                                    title: sky.arrival(.asr, indonesian: true),
                                    subtitle: "15:04 · Jakarta · " + PrayerConfiguration().method.title,
                                    glyph: .symbol(Prayer.asr.symbol, .tint(NotchModule.sky)))
            },
            capsuleNotice("capsule-workspace") {
                ZenithNotice(kind: .workspace, key: ZenithNoticeKey.workspace("catalog"), title: "Coding workspace ready",
                             subtitle: "VS Code · Terminal · Figma", glyph: .symbol("hammer.fill", .hex(0x5B8DEF)),
                             accessory: .checkmark)
            },
        ]
    }
}
#endif
