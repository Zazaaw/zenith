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
        .page(.remote): ZenithRemoteSearch.aliases,
        .page(.pocket): PocketSearch.aliases,
        .page(.faceUnlock): FaceUnlockSearch.aliases,
        .page(.batteries): BatteriesSearch.aliases,
        .page(.translate): TranslateSearch.aliases,
        .page(.meetings): MeetingsSearch.aliases,
        .page(.about): ["tentang", "tentang aplikasi", "versi", "version", "Satu Visual", "Zenith"],
    ]

    static func items(language: AppLanguage, state: SettingsSearchState) -> [SettingsSearchItem] {
        let wakaToken = ZenithStrings.wakaTimeToken(language)
        let wakaGoal = ZenithStrings.wakaTimeGoal(language)
        let vercel = ZenithStrings.vercel(language)
        let vercelAlerts = ZenithStrings.vercelAlerts(language)
        let gitHub = ZenithStrings.gitHub(language)
        let hooks = ZenithStrings.claudeHooks(language)
        let chime = ZenithStrings.claudeChime(language) // Zenith fork: when Claude needs you
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
        let lockPage = ZenithStrings.lockScreenPage(language)
        let lockIsland = ZenithStrings.lockIsland(language) // the padlock island's switches
        let remote = ZenithStrings.remote(language) // iPhone Remote
        let pocket = ZenithStrings.pocket(language) // iPhone & Watch
        let watchtower = ZenithStrings.pocketWatchtower(language)
        let face = ZenithStrings.faceUnlock(language) // Face Unlock
        let batteries = ZenithStrings.batteries(language) // Batteries
        let translate = ZenithStrings.translate(language) // Translate
        let meetings = ZenithStrings.meetings(language) // Meetings
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
            // Lock Screen: one result per tab, each landing on its tab.
            page(.zenithLockScreen, title: lockScreen.overWallpaper, icon: "lock.display",
                 keywords: [lockPage.activityRow, widgets.weather, widgets.reminders, sky.lockPrayer, sky.lockGolden,
                            lockScreen.jobs, lockScreen.jobExport, lockScreen.jobCardImport, lockScreen.jobBackup,
                            lockScreen.jobCommand, lockScreen.jobVercel, lockPage.jobExport, lockPage.jobCardImport,
                            lockPage.jobCommand, lockIsland.section, lockIsland.charging, lockIsland.focus,
                            lockIsland.farewell, lockIsland.welcome],
                 aliases: ["activity row", "baris aktivitas", "cuaca", "pengingat", "progress", "progres",
                           "progres pekerjaan", "gembok", "padlock", "see you", "welcome back", "selamat datang"]),
            page(.zenithLockScreenMusic, title: lockPage.tabMusic, icon: "music.note",
                 keywords: [lockPage.music, lockScreen.nowPlaying, lockScreen.titleControls, lockScreen.lyrics,
                            lockScreen.karaoke, lockPage.lyricShade, lockPage.lyricTiming],
                 aliases: ["lirik", "lyrics", "karaoke", "lagu", "musik", "now playing", "sedang diputar",
                           "bayangan lirik", "lyric shade", "timing lirik", "geser lirik", "lyric offset",
                           "lyrics delay", "lirik telat", "sinkron lirik"]),
            page(.zenithLockScreenTerminal, title: terminal.title, icon: "terminal",
                 keywords: [lockScreen.terminal, terminal.lines, terminal.showProjects, terminalTitle.windowTitle,
                            terminalTitle.useComputerName, lockScreen.placement],
                 aliases: ["terminal readout", "terminal layar kunci", "posisi terminal"]),
            page(.zenithLockScreenLyrics, title: lockScreen.fullSection, icon: "music.note.list",
                 keywords: [lockScreen.full, lockScreen.fullDisc, lockPage.fullDiscSpin, lockScreen.fullAccount,
                            lockPage.fullAccount, lockScreen.fullDevice, lockScreen.fullClock, lockScreen.fullLoginHint,
                            lockPage.topRight, lockScreen.background, lockPage.style, lockScreen.backgroundSolid,
                            lockScreen.backgroundBlurred, lockScreen.color, lockScreen.colorFromCover,
                            lockScreen.colorChoose, lockPage.tone, lockPage.toneVivid, lockPage.toneMuted, lockScreen.blur],
                 aliases: ["full lyrics", "full-screen lyrics", "lirik layar penuh", "lirik penuh", "piringan hitam",
                           "piringan muter", "spin the record", "vinyl", "pojok kanan atas", "top right corner",
                           "cover color", "background color", "latar", "latar belakang", "blur", "warna latar",
                           "warna sendiri", "warna sampul", "sampul blur", "nada warna", "redam", "muted color"]),
            // iPhone Remote: lock and check status from an iPhone.
            page(.zenithRemote, title: remote.enable, icon: "iphone.radiowaves.left.and.right",
                 keywords: [remote.title, remote.checklist, remote.remoteLogin, remote.tailscale, remote.devices,
                            remote.shortcut, remote.test, remote.hardening, remote.recent],
                 aliases: ZenithRemoteSearch.aliases),
            // iPhone & Watch: Zenith Pocket's switch, relay, pairing and sharing.
            page(.zenithPocket, title: pocket.enable, icon: "macbook.and.iphone",
                 keywords: [pocket.title], aliases: PocketSearch.aliases),
            page(.zenithPocketRelay, title: pocket.relay, icon: "server.rack",
                 keywords: [pocket.projectURL, pocket.anonKey],
                 aliases: ["supabase", "relay", "anon key", "project url", "server", "kunci publik"]),
            page(.zenithPocketPairing, title: pocket.pairing, icon: "qrcode",
                 keywords: [pocket.pairPhone, pocket.scanTitle, pocket.unpair],
                 aliases: ["pair", "pasangkan", "pasang hp", "sambungkan hp", "qr", "scan qr hp", "scan",
                           "unpair", "lepas pasangan"]),
            page(.zenithPocketSharing, title: pocket.sharing, icon: "square.and.arrow.up",
                 keywords: [pocket.shareWallpaper, pocket.shareAgents, pocket.shareNowPlaying, pocket.allowAnswers],
                 aliases: ["wallpaper hp", "claude di hp", "jawab claude", "approve from phone", "berbagi"]),
            page(.zenithPocketWatchtower, title: watchtower.title, icon: "binoculars",
                 keywords: PocketWatchtowerSearch.keywords(language), aliases: PocketWatchtowerSearch.aliases),
            // Face Unlock: unlock by looking at the Mac.
            page(.zenithFaceUnlock, title: face.enable, icon: "faceid",
                 keywords: [face.title, face.setUp, face.session, face.sessionOpen, face.sessionLocked, face.lockNow,
                            face.unlockWithTouchID, face.autoLock, face.triggers, face.onLock, face.onWake,
                            face.onHover, face.onSpace, face.scanning, face.scanDuration, face.retryOnHover,
                            face.autoRetry, face.camera, face.recognition, face.matchStrictness, face.detectionDistance, face.liveness,
                            face.livenessLevel, face.animation, face.faces, face.addFace, face.password,
                            face.passwordStored, face.passwordMissing, face.reset, face.lab, face.openLab, face.notes],
                 aliases: FaceUnlockSearch.aliases),
            // Batteries: the switch and the devices, when to warn, the iPhone and the Watch.
            // Meetings: the switch and calendars, the notice and the strip, the providers.
            page(.zenithMeetings, title: meetings.enable, icon: "video",
                 keywords: [meetings.title, meetings.calendarAccess, meetings.calendars],
                 aliases: MeetingsSearch.aliases),
            page(.zenithMeetingsCalls, title: meetings.before, icon: "bell.badge",
                 keywords: [meetings.lead, meetings.during, meetings.showsStrip, meetings.join, meetings.mute],
                 aliases: ["join meeting", "notice", "strip", "mute", "gabung", "pengingat rapat", "bisukan mic"]),
            page(.zenithMeetingsProviders, title: meetings.providers, icon: "video.badge.checkmark",
                 keywords: MeetingProvider.allCases.map(\.name),
                 aliases: ["zoom", "google meet", "teams", "webex", "slack", "facetime", "whereby", "jitsi"]),
            page(.zenithBatteries, title: batteries.enable, icon: "battery.75percent",
                 keywords: [batteries.title, batteries.look, batteries.layout, batteries.rings, batteries.list,
                            batteries.devices, batteries.hide, batteries.hidden],
                 aliases: BatteriesSearch.aliases),
            page(.zenithBatteriesAlerts, title: batteries.lowBatteryAlert, icon: "bell.badge",
                 keywords: [batteries.warnAt, batteries.checkEvery, batteries.airPodsScanning],
                 aliases: ["low battery", "battery alert", "AirPods", "peringatan baterai", "baterai lemah",
                           "baterai habis", "batre lemah", "batre habis"]),
            page(.zenithBatteriesIPhone, title: batteries.iOSSection, icon: "iphone",
                 keywords: [batteries.readIOS, batteries.needsTools, batteries.install, "libimobiledevice"],
                 aliases: ["iPhone battery", "iPad", "Apple Watch", "watch", "baterai iPhone", "baterai HP", "batre HP",
                           "jam tangan", "baterai jam"]),
            // Translate: the switch and the shortcut, the languages, the downloads.
            page(.zenithTranslate, title: translate.enable, icon: "translate",
                 keywords: [translate.title, translate.shortcutTitle], aliases: TranslateSearch.aliases),
            page(.zenithTranslateLanguages, title: translate.languagesSection, icon: "character.bubble",
                 keywords: [translate.target, translate.secondTarget, translate.showDetection],
                 aliases: ["target language", "detect language", "bahasa tujuan", "bahasa kedua", "deteksi bahasa"]),
            page(.zenithTranslateDownloads, title: translate.downloadsSection, icon: "arrow.down.circle",
                 keywords: [translate.download, translate.manageDownloads, translate.checkPair],
                 aliases: ["offline", "download language", "unduh bahasa", "bahasa terunduh"]),
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
                                 keywords: [hooks.connect, hooks.sound, chime.alert, chime.soundAndIsland, chime.needsYou],
                                 aliases: ["Claude Code", "hooks", "live steps", "langkah Claude", "chime", "Tink", "bunyi",
                                           "suara Claude", "Claude butuh kamu"], feature: .notchAgents))
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
