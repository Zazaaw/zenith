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
        ] + bursts + capsules
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

    // MARK: Bursts (the island grown for a moment)

    /// The island grown for `content`, `elapsed` seconds into its stay.
    static func burst(_ id: String, preferences: [String: Any] = [:], geometry: NotchGeometry? = nil,
                      elapsed: TimeInterval = 0, setup: @escaping @MainActor () -> Void = {},
                      _ content: @escaping @MainActor () -> ZenithIslandBurst.Content) -> CatalogShot {
        CatalogShot(id: id, preferences: preferences, setup: setup) {
            let burst = ZenithIslandBurst(content(), start: Date().addingTimeInterval(-elapsed))
            return island(pose {
                if let geometry { $0.geometry = geometry }
                $0.notice = NotchNotice(event: burst.event, title: burst.title, detail: burst.subtitle,
                                        symbol: "circle", zenith: burst)
            })
        }
    }

    static let indonesianNames: [String: Any] = [DefaultsKey.notchSkyNames: PrayerTimesSupport.NameStyle.indonesian.rawValue]

    static var bursts: [CatalogShot] {
        // Today's own Asr in Jakarta, so the next prayer is its Maghrib.
        let prayer: @MainActor () -> ZenithIslandBurst.Content = {
            let asr = CatalogSamples.skyDay.moments.first { $0.prayer == .asr && Calendar.current.isDateInToday($0.time) }
                ?? PrayerMoment(prayer: .asr, time: CatalogSamples.now)
            return .prayer(SkyService.shared.prayerBurst(asr))
        }
        return [
            burst("burst-prayer", preferences: indonesianNames, elapsed: 3.2, setup: { CatalogSamples.prayer(arrived: true) },
                  prayer),
            burst("burst-prayer-capsule", preferences: indonesianNames.merging([
                DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue]) { $1 },
                  geometry: capsule, elapsed: 3.2, setup: { CatalogSamples.prayer(arrived: true) }, prayer),
            burst("burst-charging") { charge(.charging, percent: 82, minutes: 70) },
            burst("burst-welcome") {
                let text = ZenithStrings.lockIsland(.enUS)
                return .welcome(ZenithWelcomeBurst(
                    title: text.welcomeBack("Faiz"),
                    subtitle: text.detail(duration: ZenithLockIsland.duration(2 * 3_600 + 14 * 60, locale: Locale(identifier: "en_US")),
                                          notifications: nil),
                    photo: nil, initials: "FH"))
            },
            burst("burst-remote-status") { .remote(ZenithRemoteBurst(device: "Faiz’s iPhone")) },
            burst("burst-welcome-remote") {
                .welcome(ZenithWelcomeBurst(title: ZenithStrings.lockIsland(.enUS).welcomeBack("Faiz"),
                                            subtitle: RemoteText.welcomeDetail(device: "Faiz’s iPhone", seconds: 80 * 60),
                                            photo: nil, initials: "FH"))
            },
            burst("burst-claude") {
                .agent(ZenithAgentBurst(provider: .claude, title: ZenithStrings.claudeChime(.enUS).needsYou, subtitle: "zenith"))
            },
            burst("burst-charging-estimating") { charge(.charging, percent: 46, minutes: nil) },
            burst("burst-charge-limit") { charge(.charging, percent: 80, minutes: nil,
                                                 hint: ZenithStrings.notices(.enUS).chargeHint) },
            burst("burst-charge-held") { charge(.held, percent: 80, minutes: nil) },
            burst("burst-unplugged") { charge(.onBattery, percent: 76, minutes: 260) },
            burst("burst-unplugged-low") { charge(.onBattery, percent: 18, minutes: nil) },
            burst("burst-charging-capsule", preferences: [DefaultsKey.notchSilhouette: NotchSilhouette.capsule.rawValue],
                  geometry: capsule) { charge(.charging, percent: 82, minutes: 70) },
        ]
    }

    /// A charger moment as the notice center builds it.
    static func charge(_ state: ZenithChargeState, percent: Int, minutes: Int?, hint: String? = nil) -> ZenithIslandBurst.Content {
        .charge(ZenithChargeBurst.make(state, percent: percent, minutes: minutes, hint: hint,
                                       island: ZenithStrings.island(.enUS), notices: ZenithStrings.notices(.enUS),
                                       locale: Locale(identifier: "en_US")))
    }

    /// A low battery notice as the notice center builds it.
    static func battery(_ kind: ZenithNotice.Kind, percent: Int, lowPowerOn: Bool, minutesLeft: Int?) -> ZenithNotice {
        let notice = ZenithNotice(kind: kind, key: ZenithNoticeKey.batteryLow, title: "", subtitle: "",
                                  glyph: .battery(percent: percent, tone: .red), accessory: .lowPower(on: lowPowerOn),
                                  action: .batterySettings, minutesLeft: minutesLeft)
        return ZenithBatteryNoticeLook.refreshed(notice, lowPowerOn: lowPowerOn, island: ZenithStrings.island(.enUS),
                                                 notices: ZenithStrings.notices(.enUS), locale: Locale(identifier: "en_US"))
    }

    static var capsules: [CatalogShot] {
        let text = ZenithStrings.notices(.enUS)
        return [
            capsuleNotice("capsule-battery-low") {
                battery(.batteryLow, percent: 20, lowPowerOn: false, minutesLeft: 70)
            },
            capsuleNotice("capsule-battery-critical") {
                battery(.batteryCritical, percent: 10, lowPowerOn: true, minutesLeft: 25)
            },
            capsuleNotice("capsule-battery-critical-unknown") {
                battery(.batteryCritical, percent: 9, lowPowerOn: true, minutesLeft: nil)
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
            capsuleNotice("capsule-workspace") {
                ZenithNotice(kind: .workspace, key: ZenithNoticeKey.workspace("catalog"), title: "Coding workspace ready",
                             subtitle: "VS Code · Terminal · Figma", glyph: .symbol("hammer.fill", .hex(0x5B8DEF)),
                             accessory: .checkmark)
            },
        ]
    }
}
#endif
