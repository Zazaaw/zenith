// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the padlock island on the lock screen: its greetings and the
// switches Settings → Lock Screen adds for them.

struct ZenithLockIslandStrings {
    /// The settings card.
    let section: String
    let sectionCaption: String
    let charging: String
    let chargingCaption: String
    let focus: String
    let focusCaption: String
    let farewell: String
    let farewellCaption: String
    let welcome: String
    let welcomeCaption: String
    /// The greetings; `{name}` is the account's first name.
    let seeYou: String
    let seeYouNameless: String
    let welcomeBack: String
    let welcomeBackNameless: String
    /// `{duration}` is a short duration such as "2h 14m".
    let lockedFor: String
    /// `{count}` is a number; worded so it reads for any count.
    let notifications: String
}

extension ZenithLockIslandStrings {
    func seeYou(_ name: String) -> String {
        name.isEmpty ? seeYouNameless : seeYou.replacingOccurrences(of: "{name}", with: name)
    }

    func welcomeBack(_ name: String) -> String {
        name.isEmpty ? welcomeBackNameless : welcomeBack.replacingOccurrences(of: "{name}", with: name)
    }

    /// "Locked for 2h 14m · 3 notifications", or without the count when the
    /// island could not count them.
    func detail(duration: String, notifications count: Int?) -> String {
        let locked = lockedFor.replacingOccurrences(of: "{duration}", with: duration)
        guard let count, count > 0 else { return locked }
        return locked + " · " + notifications.replacingOccurrences(of: "{count}", with: String(count))
    }
}

extension ZenithStrings {
    static func lockIsland(_ language: AppLanguage) -> ZenithLockIslandStrings {
        switch language {
        case .enUS:
            return .init(section: "Island", sectionCaption: "What the padlock at the camera shows while the Mac is locked",
                         charging: "Charging", chargingCaption: "A green bolt and the charge while the charger is connected",
                         focus: "Focus", focusCaption: "The Focus that is on, in violet, where macOS shares it with apps",
                         farewell: "See you", farewellCaption: "The island waves goodbye as the Mac locks",
                         welcome: "Welcome back", welcomeCaption: "A greeting with how long the Mac was locked as you unlock",
                         seeYou: "See you, {name} 👋", seeYouNameless: "See you 👋",
                         welcomeBack: "Welcome back, {name}", welcomeBackNameless: "Welcome back",
                         lockedFor: "Locked for {duration}", notifications: "notifications: {count}")
        case .ptBR:
            return .init(section: "Ilha", sectionCaption: "O que o cadeado junto à câmera mostra com o Mac bloqueado",
                         charging: "Carregando", chargingCaption: "Um raio verde e a carga enquanto o carregador está conectado",
                         focus: "Foco", focusCaption: "O Foco ativo, em violeta, quando o macOS o compartilha com apps",
                         farewell: "Até logo", farewellCaption: "A ilha se despede quando o Mac bloqueia",
                         welcome: "Bem-vindo de volta", welcomeCaption: "Uma saudação com o tempo bloqueado ao desbloquear",
                         seeYou: "Até logo, {name} 👋", seeYouNameless: "Até logo 👋",
                         welcomeBack: "Bem-vindo de volta, {name}", welcomeBackNameless: "Bem-vindo de volta",
                         lockedFor: "Bloqueado por {duration}", notifications: "notificações: {count}")
        case .tr:
            return .init(section: "Ada", sectionCaption: "Mac kilitliyken kameranın yanındaki kilidin gösterdikleri",
                         charging: "Şarj", chargingCaption: "Şarj aleti takılıyken yeşil şimşek ve şarj düzeyi",
                         focus: "Odak", focusCaption: "Açık olan Odak, mor renkte, macOS uygulamalarla paylaştığında",
                         farewell: "Görüşürüz", farewellCaption: "Mac kilitlenirken ada el sallar",
                         welcome: "Tekrar hoş geldin", welcomeCaption: "Kilidi açınca Mac’in ne kadar kilitli kaldığıyla bir selam",
                         seeYou: "Görüşürüz, {name} 👋", seeYouNameless: "Görüşürüz 👋",
                         welcomeBack: "Tekrar hoş geldin, {name}", welcomeBackNameless: "Tekrar hoş geldin",
                         lockedFor: "{duration} kilitli kaldı", notifications: "bildirim: {count}")
        case .ru:
            return .init(section: "Остров", sectionCaption: "Что показывает замок у камеры, пока Mac заблокирован",
                         charging: "Зарядка", chargingCaption: "Зелёная молния и заряд, пока подключено зарядное устройство",
                         focus: "Фокусирование", focusCaption: "Включённый режим фокусирования фиолетовым, если macOS сообщает его приложениям",
                         farewell: "До встречи", farewellCaption: "Остров прощается, когда Mac блокируется",
                         welcome: "С возвращением", welcomeCaption: "Приветствие с тем, сколько Mac был заблокирован, при разблокировке",
                         seeYou: "До встречи, {name} 👋", seeYouNameless: "До встречи 👋",
                         welcomeBack: "С возвращением, {name}", welcomeBackNameless: "С возвращением",
                         lockedFor: "Заблокирован {duration}", notifications: "уведомления: {count}")
        case .es:
            return .init(section: "Isla", sectionCaption: "Lo que muestra el candado junto a la cámara con el Mac bloqueado",
                         charging: "Cargando", chargingCaption: "Un rayo verde y la carga mientras el cargador está conectado",
                         focus: "Concentración", focusCaption: "El modo de concentración activo, en violeta, cuando macOS lo comparte con las apps",
                         farewell: "Hasta luego", farewellCaption: "La isla se despide cuando el Mac se bloquea",
                         welcome: "Bienvenido de nuevo", welcomeCaption: "Un saludo con el tiempo que estuvo bloqueado al desbloquear",
                         seeYou: "Hasta luego, {name} 👋", seeYouNameless: "Hasta luego 👋",
                         welcomeBack: "Bienvenido de nuevo, {name}", welcomeBackNameless: "Bienvenido de nuevo",
                         lockedFor: "Bloqueado durante {duration}", notifications: "notificaciones: {count}")
        case .sk:
            return .init(section: "Ostrov", sectionCaption: "Čo ukazuje zámok pri kamere, kým je Mac zamknutý",
                         charging: "Nabíjanie", chargingCaption: "Zelený blesk a nabitie, kým je pripojená nabíjačka",
                         focus: "Sústredenie", focusCaption: "Zapnutý režim sústredenia fialovou, ak ho macOS zdieľa s aplikáciami",
                         farewell: "Dovidenia", farewellCaption: "Ostrov sa rozlúči, keď sa Mac zamkne",
                         welcome: "Vitaj späť", welcomeCaption: "Pozdrav s tým, ako dlho bol Mac zamknutý, keď ho odomkneš",
                         seeYou: "Dovidenia, {name} 👋", seeYouNameless: "Dovidenia 👋",
                         welcomeBack: "Vitaj späť, {name}", welcomeBackNameless: "Vitaj späť",
                         lockedFor: "Zamknuté {duration}", notifications: "hlásenia: {count}")
        case .de:
            return .init(section: "Insel", sectionCaption: "Was das Schloss an der Kamera zeigt, solange der Mac gesperrt ist",
                         charging: "Laden", chargingCaption: "Ein grüner Blitz und der Ladestand, solange das Netzteil verbunden ist",
                         focus: "Fokus", focusCaption: "Der aktive Fokus in Violett, sofern macOS ihn mit Apps teilt",
                         farewell: "Bis bald", farewellCaption: "Die Insel winkt zum Abschied, wenn der Mac sperrt",
                         welcome: "Willkommen zurück", welcomeCaption: "Ein Gruß mit der Sperrdauer beim Entsperren",
                         seeYou: "Bis bald, {name} 👋", seeYouNameless: "Bis bald 👋",
                         welcomeBack: "Willkommen zurück, {name}", welcomeBackNameless: "Willkommen zurück",
                         lockedFor: "Gesperrt für {duration}", notifications: "Mitteilungen: {count}")
        case .fr:
            return .init(section: "Île", sectionCaption: "Ce que le cadenas près de la caméra affiche quand le Mac est verrouillé",
                         charging: "Recharge", chargingCaption: "Un éclair vert et la charge tant que le chargeur est branché",
                         focus: "Concentration", focusCaption: "Le mode de concentration actif, en violet, quand macOS le partage avec les apps",
                         farewell: "À bientôt", farewellCaption: "L’île vous salue quand le Mac se verrouille",
                         welcome: "Bon retour", welcomeCaption: "Un mot d’accueil avec la durée du verrouillage au déverrouillage",
                         seeYou: "À bientôt, {name} 👋", seeYouNameless: "À bientôt 👋",
                         welcomeBack: "Bon retour, {name}", welcomeBackNameless: "Bon retour",
                         lockedFor: "Verrouillé pendant {duration}", notifications: "notifications : {count}")
        case .it:
            return .init(section: "Isola", sectionCaption: "Cosa mostra il lucchetto vicino alla fotocamera con il Mac bloccato",
                         charging: "In carica", chargingCaption: "Un fulmine verde e la carica finché il caricatore è collegato",
                         focus: "Full immersion", focusCaption: "La modalità Full immersion attiva, in viola, quando macOS la condivide con le app",
                         farewell: "A presto", farewellCaption: "L’isola ti saluta quando il Mac si blocca",
                         welcome: "Bentornato", welcomeCaption: "Un saluto con quanto è rimasto bloccato il Mac, allo sblocco",
                         seeYou: "A presto, {name} 👋", seeYouNameless: "A presto 👋",
                         welcomeBack: "Bentornato, {name}", welcomeBackNameless: "Bentornato",
                         lockedFor: "Bloccato per {duration}", notifications: "notifiche: {count}")
        case .ja:
            return .init(section: "アイランド", sectionCaption: "Mac のロック中にカメラ横の南京錠が表示する内容",
                         charging: "充電", chargingCaption: "充電器の接続中、緑の稲妻と充電残量を表示",
                         focus: "集中モード", focusCaption: "オンの集中モードを紫で表示（macOS がアプリに共有する場合）",
                         farewell: "またね", farewellCaption: "Mac がロックされるとアイランドが手を振ります",
                         welcome: "おかえり", welcomeCaption: "ロック解除時に、ロックされていた時間を添えてあいさつ",
                         seeYou: "またね、{name} 👋", seeYouNameless: "またね 👋",
                         welcomeBack: "おかえり、{name}", welcomeBackNameless: "おかえり",
                         lockedFor: "{duration} ロック", notifications: "通知: {count}")
        case .ko:
            return .init(section: "아일랜드", sectionCaption: "Mac이 잠겨 있는 동안 카메라 옆 자물쇠가 보여 주는 것",
                         charging: "충전", chargingCaption: "충전기가 연결된 동안 초록색 번개와 충전량",
                         focus: "집중 모드", focusCaption: "켜진 집중 모드를 보라색으로 표시 (macOS가 앱과 공유하는 경우)",
                         farewell: "또 봐요", farewellCaption: "Mac이 잠길 때 아일랜드가 손을 흔들어요",
                         welcome: "다시 오신 걸 환영해요", welcomeCaption: "잠금 해제 시 잠겨 있던 시간과 함께 인사",
                         seeYou: "또 봐요, {name} 👋", seeYouNameless: "또 봐요 👋",
                         welcomeBack: "다시 오신 걸 환영해요, {name}", welcomeBackNameless: "다시 오신 걸 환영해요",
                         lockedFor: "{duration} 동안 잠김", notifications: "알림: {count}")
        case .uk:
            return .init(section: "Острів", sectionCaption: "Що показує замок біля камери, поки Mac заблоковано",
                         charging: "Заряджання", chargingCaption: "Зелена блискавка й заряд, поки під’єднано зарядний пристрій",
                         focus: "Зосередження", focusCaption: "Увімкнений режим зосередження фіолетовим, якщо macOS ділиться ним із програмами",
                         farewell: "До зустрічі", farewellCaption: "Острів прощається, коли Mac блокується",
                         welcome: "З поверненням", welcomeCaption: "Привітання з тим, скільки Mac був заблокований, під час розблокування",
                         seeYou: "До зустрічі, {name} 👋", seeYouNameless: "До зустрічі 👋",
                         welcomeBack: "З поверненням, {name}", welcomeBackNameless: "З поверненням",
                         lockedFor: "Заблоковано {duration}", notifications: "сповіщення: {count}")
        case .zhHans:
            return .init(section: "灵动岛", sectionCaption: "Mac 锁定时摄像头旁的挂锁显示的内容",
                         charging: "充电", chargingCaption: "连接充电器时显示绿色闪电和电量",
                         focus: "专注模式", focusCaption: "以紫色显示已开启的专注模式（macOS 与 App 共享时）",
                         farewell: "回头见", farewellCaption: "Mac 锁定时灵动岛挥手道别",
                         welcome: "欢迎回来", welcomeCaption: "解锁时问候，并显示锁定了多久",
                         seeYou: "回头见，{name} 👋", seeYouNameless: "回头见 👋",
                         welcomeBack: "欢迎回来，{name}", welcomeBackNameless: "欢迎回来",
                         lockedFor: "已锁定 {duration}", notifications: "通知：{count}")
        case .zhTW:
            return .init(section: "動態島", sectionCaption: "Mac 鎖定時相機旁的鎖頭顯示的內容",
                         charging: "充電", chargingCaption: "連接充電器時顯示綠色閃電和電量",
                         focus: "專注模式", focusCaption: "以紫色顯示已開啟的專注模式（macOS 與 App 分享時）",
                         farewell: "待會見", farewellCaption: "Mac 鎖定時動態島揮手道別",
                         welcome: "歡迎回來", welcomeCaption: "解鎖時問候，並顯示鎖定了多久",
                         seeYou: "待會見，{name} 👋", seeYouNameless: "待會見 👋",
                         welcomeBack: "歡迎回來，{name}", welcomeBackNameless: "歡迎回來",
                         lockedFor: "已鎖定 {duration}", notifications: "通知：{count}")
        case .zhHK:
            return .init(section: "動態島", sectionCaption: "Mac 鎖定時相機旁的鎖頭顯示的內容",
                         charging: "充電", chargingCaption: "連接充電器時顯示綠色閃電和電量",
                         focus: "專注模式", focusCaption: "以紫色顯示已開啟的專注模式（macOS 與 App 分享時）",
                         farewell: "遲啲見", farewellCaption: "Mac 鎖定時動態島揮手道別",
                         welcome: "歡迎返嚟", welcomeCaption: "解鎖時問候，並顯示鎖定了幾耐",
                         seeYou: "遲啲見，{name} 👋", seeYouNameless: "遲啲見 👋",
                         welcomeBack: "歡迎返嚟，{name}", welcomeBackNameless: "歡迎返嚟",
                         lockedFor: "已鎖定 {duration}", notifications: "通知：{count}")
        }
    }
}
