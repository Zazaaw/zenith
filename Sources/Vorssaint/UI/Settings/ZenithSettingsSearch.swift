// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Settings search for the fork's own features. Upstream's
/// directory indexes upstream's pages; this adds one result per section the
/// fork adds, landing on its page and, where it has one, on its section's
/// anchor or its island module, so the page scrolls to it and outlines it.
///
/// Keywords are the localized labels each section shows, so they follow the
/// app's language. Aliases are plain English and Indonesian words a label
/// does not use, such as "sholat" for Prayer times: they find a result in
/// every language and show its title rather than themselves.
enum ZenithSettingsSearch {
    /// Adds the fork's results, and the aliases of the fork's pages that
    /// upstream's directory already lists.
    static func extend(_ items: inout [SettingsSearchItem], language: AppLanguage, state: SettingsSearchState) {
        for index in items.indices {
            if let words = pageAliases[items[index].id] { items[index].aliases += words }
        }
        items += self.items(language: language, state: state)
    }

    /// Pages that are fork pages already, or that the fork rewrote.
    static let pageAliases: [SettingsSearchItem.ID: [String]] = [
        .page(.workspaces): ["workspace", "ruang kerja", "mode kerja", "preset kerja", "profil kerja"],
        .page(.lockScreen): ["lock screen", "lockscreen", "layar kunci", "kunci layar", "layar terkunci"],
        .page(.about): ["tentang", "tentang aplikasi", "versi", "version", "Satu Visual", "Zenith"],
    ]

    static func items(language: AppLanguage, state: SettingsSearchState) -> [SettingsSearchItem] {
        let wakaToken = ZenithStrings.wakaTimeToken(language)
        let wakaGoal = ZenithStrings.wakaTimeGoal(language)
        let vercel = ZenithStrings.vercel(language)
        let vercelAlerts = ZenithStrings.vercelAlerts(language)
        let gitHub = ZenithStrings.gitHub(language)
        let hooks = ZenithStrings.claudeHooks(language)
        let card = ZenithStrings.cardImport(language)
        let backup = ZenithStrings.cardBackup(language)
        let servers = ZenithStrings.devServers(language)
        let git = ZenithStrings.git(language)
        let sky = ZenithStrings.sky(language)
        let recap = ZenithStrings.recap(language)
        let prompter = ZenithStrings.prompter(language)
        let camera = ZenithStrings.camera(language)
        let reply = ZenithStrings.reply(language)
        let lockScreen = ZenithStrings.lockScreenSettings(language)
        let widgets = ZenithStrings.lockScreenWidgets(language)
        let terminal = ZenithStrings.lockScreenTerminal(language)
        let terminalTitle = ZenithStrings.lockScreenTerminalTitle(language)
        let commands = ZenithStrings.commandActivity(language)
        let exports = ZenithStrings.exportTracker(language)
        let notices = ZenithStrings.notices(language)
        let tabBar = ZenithStrings.tabBar(language)
        let dropZones = ZenithStrings.dropZones(language)
        let watermark = ZenithStrings.watermark(language)
        let overlay = ZenithStrings.designOverlay(language)
        let beautify = ZenithStrings.beautify(language)
        let qr = ZenithStrings.qr(language)
        let hider = ZenithStrings.menuBarHider(language)

        var items: [SettingsSearchItem] = [
            // Dynamic Island › Content: the fork's modules and their options.
            module(.wakatime, .zenithWakaTime, title: "WakaTime",
                   keywords: [wakaToken.tokenTitle, wakaGoal.goalTitle],
                   aliases: ["coding time", "waktu coding", "waktu ngoding", "ngoding", "statistik coding"]),
            module(.vercel, .zenithVercel, title: "Vercel",
                   keywords: [vercel.tokenTitle, vercel.liveActivity, vercelAlerts.failureAlerts],
                   aliases: ["deploy", "deployment", "deploy gagal", "build gagal"]),
            module(.github, .zenithGitHub, title: "GitHub", keywords: [gitHub.lookAgain, "GitHub CLI"],
                   aliases: ["gh", "pull request", "PR", "code review", "review"]),
            module(.cardImport, .zenithCardImport, title: card.title,
                   keywords: [card.detect, card.folder, card.separateRaw, card.videoFolder, card.skipImported,
                              card.rename, card.ejectWhenDone],
                   aliases: ["SD card", "kartu SD", "kartu memori", "kartu kamera", "memory card", "CFexpress", "DCIM",
                             "import foto", "impor foto"]),
            section(.zenithCardBackup, in: .module(.cardImport), title: backup.settingsTitle,
                    icon: "externaldrive.badge.checkmark",
                    keywords: [backup.addDestination, backup.automatic, backup.verifyAfter, backup.reminder],
                    aliases: ["backups", "cadangan", "cadangkan", "backup kartu", "verifikasi backup", "SHA-256"]),
            module(.devServers, .zenithDevServers, title: servers.title,
                   keywords: [servers.detect, servers.announce, servers.indicator, servers.extraPorts, servers.extraNames],
                   aliases: ["dev server", "localhost", "server lokal", "next dev", "vite", "artisan serve"]),
            module(.git, .zenithGit, title: git.title,
                   keywords: [git.fromEditor, git.fromTerminal, git.fetch, git.indicator, git.pinned],
                   aliases: ["repo", "repository", "repositori", "branch", "commit"]),
            section(.zenithPrayerTimes, in: .module(.sky), title: sky.prayerTab, icon: "moon.stars",
                    keywords: [sky.calculation, sky.method, sky.asr, sky.adjustments, sky.names, sky.location,
                               sky.prayerActivity, sky.sound],
                    aliases: ["prayer", "sholat", "shalat", "salat", "jadwal sholat", "waktu sholat", "adzan", "azan",
                              "imsak", "subuh", "dzuhur", "ashar", "maghrib", "isya", "Kemenag"]),
            section(.zenithGoldenHour, in: .module(.sky), title: sky.goldenTab, icon: "sun.horizon",
                    keywords: [sky.goldenActivity],
                    aliases: ["golden hour", "blue hour", "sunset", "senja", "matahari terbenam", "jam emas"]),
            module(.sky, .zenithSky, title: sky.title, keywords: [], aliases: ["langit"]),
            module(.recap, .zenithRecap, title: recap.title,
                   keywords: [recap.dailyRecap, recap.showAt, recap.weekdaysOnly, recap.include],
                   aliases: ["recap", "rekap", "rekap harian", "hari ini", "ringkasan harian", "rangkuman",
                             "daily summary"]),
            module(.prompter, .zenithPrompter, title: prompter.title,
                   keywords: [prompter.scripts, prompter.reading, prompter.mirrorTitle, prompter.guideTitle,
                              prompter.voiceTitle, prompter.shortcutTitle],
                   aliases: ["teleprompter", "naskah", "skrip", "script", "autocue"]),
            section(.zenithCameraAutoStart, in: .module(.camera), title: camera.autoStart, icon: "web.camera",
                    keywords: [], aliases: ["mirror kamera", "cermin kamera", "kamera otomatis"], feature: .cameraPreview),
            section(.zenithReply, in: .module(.notifications), title: reply.autoWhatsApp,
                    icon: "arrowshape.turn.up.left", keywords: [],
                    aliases: ["reply", "balas", "balas pesan", "WhatsApp", "iMessage"], feature: .notchNotifications),
            // Lock Screen: what shows over the wallpaper, the terminal readout and full-screen lyrics.
            page(.zenithLockScreen, title: lockScreen.overWallpaper, icon: "lock.display",
                 keywords: [widgets.weather, widgets.reminders, sky.lockPrayer, sky.lockGolden, lockScreen.jobs,
                            lockScreen.jobExport, lockScreen.jobCardImport, lockScreen.jobBackup, lockScreen.jobCommand,
                            lockScreen.jobVercel, lockScreen.nowPlaying, lockScreen.lyrics, lockScreen.karaoke,
                            lockScreen.titleControls],
                 aliases: ["cuaca", "pengingat", "progress", "progres", "progres pekerjaan", "lirik", "lyrics",
                           "karaoke", "lagu", "now playing", "sedang diputar"]),
            page(.zenithLockScreenTerminal, title: terminal.title, icon: "terminal",
                 keywords: [lockScreen.terminal, terminal.lines, terminal.showProjects, terminalTitle.windowTitle,
                            terminalTitle.useComputerName, lockScreen.placement],
                 aliases: ["terminal readout", "terminal layar kunci", "posisi terminal"]),
            page(.zenithLockScreenLyrics, title: lockScreen.fullSection, icon: "music.note.list",
                 keywords: [lockScreen.full, lockScreen.fullDisc, lockScreen.fullAccount, lockScreen.fullDevice,
                            lockScreen.fullClock, lockScreen.fullCoverColor, lockScreen.fullLoginHint],
                 aliases: ["full lyrics", "full-screen lyrics", "lirik layar penuh", "lirik penuh", "piringan hitam",
                           "vinyl"]),
            // Dynamic Island › Activity: the fork's cards.
            section(.zenithCommandActivity, in: .activity, title: commands.section, icon: "terminal",
                    keywords: [commands.toggle, commands.showAfter, commands.showFolder, commands.ignore, commands.hook],
                    aliases: ["terminal", "zsh", "perintah terminal", "long command", "shell hook"]),
            section(.zenithExportTracker, in: .activity, title: exports.section, icon: "square.and.arrow.up",
                    keywords: [exports.toggle, exports.folders, exports.minimumSize, exports.sound, exports.notify],
                    aliases: ["export", "ekspor", "render", "DaVinci Resolve", "OBS", "Lightroom"]),
            section(.zenithNotices, in: .activity, title: notices.section, icon: "capsule",
                    keywords: [notices.lowBattery, notices.veryLowBattery, notices.chargeReaches, notices.charger,
                               notices.audio, notices.download],
                    aliases: ["notice", "kapsul", "notifikasi kapsul", "baterai", "headphones", "AirPods"]),
            // Dynamic Island › Layout.
            section(.zenithTabBar, in: .layout, title: tabBar.section, icon: "rectangle.split.3x1",
                    keywords: [tabBar.show, tabBar.tabs, tabBar.currentPage, tabBar.badges],
                    aliases: ["tab", "pil tab", "pill"]),
            // Shelf.
            page(.zenithDropZones, title: dropZones.title, icon: "square.and.arrow.down.on.square",
                 keywords: NotchDropTarget.allCases.map { $0.zenithTitle(language) },
                 aliases: ["drop zone", "zona drop", "hapus latar", "remove background"]),
            page(.zenithWatermark, title: watermark.title, icon: "signature",
                 keywords: [watermark.defaultPreset, watermark.content, watermark.chooseLogo, watermark.shadow],
                 aliases: ["tanda air", "watermark foto", "logo foto"]),
            // Screen capture.
            page(.zenithDesignOverlay, title: overlay.title, icon: "square.on.square.dashed",
                 keywords: [overlay.shortcut, overlay.defaultOpacity, overlay.defaultBlend, overlay.grid],
                 aliases: ["overlay", "Figma", "pixel perfect", "QA desain", "overlay desain", "referensi desain"],
                 feature: .screenshot),
            page(.zenithBeautify, title: beautify.title, icon: "wand.and.stars",
                 keywords: [beautify.afterCapture],
                 aliases: ["percantik", "bingkai", "frame", "mockup", "Instagram"], feature: .screenshot),
            // Clipboard.
            page(.zenithQR, title: qr.title, icon: "qrcode",
                 keywords: [qr.correction, qr.logo, qr.fromClipboard, qr.scan, qr.newCode],
                 aliases: ["QR", "kode QR", "pindai", "pindai QR", "scan QR", "barcode"]),
            // General › Menu bar, where the hider's card follows the panel's.
            SettingsSearchItem(id: .setting(.zenithMenuBarHider),
                               destination: FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration),
                               title: hider.title, icon: "menubar.arrow.up.rectangle",
                               keywords: [hider.enable, hider.alwaysHidden, hider.delay, hider.clickOutside, hider.hover,
                                          hider.notch, hider.shortcutToggle, hider.shortcut],
                               aliases: ["menu bar", "sembunyikan ikon", "sembunyikan ikon menu bar", "ikon menu bar",
                                         "hidden bar", "Bartender"]),
        ]
        // Claude Code's hooks show under the AI agents options while Claude is on.
        if state.on(DefaultsKey.notchAgentsClaude) {
            items.append(section(.zenithClaudeHooks, in: .module(.agents), title: hooks.section, icon: "sparkles",
                                 keywords: [hooks.connect, hooks.sound],
                                 aliases: ["Claude Code", "hooks", "live steps", "langkah Claude"], feature: .notchAgents))
        }
        return items
    }

    /// The anchors that only name a search result; the page it opens has no
    /// such section (the hider opens the Menu bar tool, where its card is).
    static let unplacedAnchors: Set<SettingsSectionAnchor> = [.zenithMenuBarHider]

    // MARK: Builders

    /// A module of the island's Content tab, which opens with its options
    /// outlined. A section rather than a `.notch` result, whose identity the
    /// command bar keeps for the island's own labels.
    private static func module(_ module: NotchModule, _ anchor: SettingsSectionAnchor, title: String,
                               keywords: [String], aliases: [String]) -> SettingsSearchItem {
        section(anchor, in: .module(module), title: title, icon: module.symbol, keywords: keywords, aliases: aliases)
    }

    /// A section inside one of the island's tabs or module options.
    private static func section(_ anchor: SettingsSectionAnchor, in location: NotchSettingsLocation, title: String,
                                icon: String, keywords: [String], aliases: [String],
                                feature: AppFeature? = nil) -> SettingsSearchItem {
        SettingsSearchItem(id: .setting(anchor), destination: FeatureSettingsDestination(notch: location, sectionAnchor: anchor),
                           title: title, icon: icon, keywords: keywords, feature: feature, aliases: aliases)
    }

    /// A section of an ordinary Settings page.
    private static func page(_ anchor: SettingsSectionAnchor, title: String, icon: String, keywords: [String],
                             aliases: [String], feature: AppFeature? = nil) -> SettingsSearchItem {
        SettingsSearchItem(id: .setting(anchor), destination: FeatureSettingsDestination(anchor.page, sectionAnchor: anchor),
                           title: title, icon: icon, keywords: keywords, feature: feature, aliases: aliases)
    }
}

private extension SettingsSearchItem {
    init(id: ID, destination: FeatureSettingsDestination, title: String, icon: String, keywords: [String],
         feature: AppFeature? = nil, aliases: [String]) {
        self.init(id: id, destination: destination, title: title, icon: icon, keywords: keywords, feature: feature)
        self.aliases = aliases
    }
}
