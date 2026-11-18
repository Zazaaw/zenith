// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

// Zenith fork: text for Zenith's own features, kept apart from upstream's string
// catalogs so syncs never conflict here. Every AppLanguage has an entry.

struct ZenithAirDropStrings {
    let toggle: String
    let caption: String
}

enum ZenithStrings {
    static func airDrop(_ language: AppLanguage) -> ZenithAirDropStrings {
        switch language {
        case .enUS:
            return .init(toggle: "AirDrop in the Dynamic Island",
                         caption: "Drag files onto the island and drop them on AirDrop to send them to a nearby device. Works even when the shelf or the island’s Files section is off.")
        case .ptBR:
            return .init(toggle: "AirDrop na Dynamic Island",
                         caption: "Arraste arquivos até a ilha e solte-os em AirDrop para enviá-los a um dispositivo próximo. Funciona mesmo com a prateleira ou a seção Arquivos da ilha desativadas.")
        case .tr:
            return .init(toggle: "Dynamic Island’da AirDrop",
                         caption: "Dosyaları adaya sürükleyip AirDrop’a bırakarak yakındaki bir cihaza gönder. Raf veya adanın Dosyalar bölümü kapalıyken de çalışır.")
        case .ru:
            return .init(toggle: "AirDrop в Dynamic Island",
                         caption: "Перетащите файлы на остров и отпустите их на AirDrop, чтобы отправить на устройство поблизости. Работает, даже если полка или раздел «Файлы» на острове выключены.")
        case .es:
            return .init(toggle: "AirDrop en la Dynamic Island",
                         caption: "Arrastra archivos a la isla y suéltalos en AirDrop para enviarlos a un dispositivo cercano. Funciona aunque el estante o la sección Archivos de la isla estén desactivados.")
        case .sk:
            return .init(toggle: "AirDrop v Dynamic Island",
                         caption: "Pretiahnite súbory na ostrov a pustite ich na AirDrop, aby ste ich poslali do zariadenia v blízkosti. Funguje, aj keď je polica alebo sekcia Súbory na ostrove vypnutá.")
        case .de:
            return .init(toggle: "AirDrop in der Dynamic Island",
                         caption: "Zieh Dateien auf die Insel und lass sie auf AirDrop los, um sie an ein Gerät in der Nähe zu senden. Funktioniert auch, wenn die Ablage oder der Bereich „Dateien“ der Insel aus ist.")
        case .fr:
            return .init(toggle: "AirDrop dans la Dynamic Island",
                         caption: "Faites glisser des fichiers sur l’île et déposez-les sur AirDrop pour les envoyer à un appareil à proximité. Fonctionne même si l’étagère ou la section Fichiers de l’île est désactivée.")
        case .it:
            return .init(toggle: "AirDrop nella Dynamic Island",
                         caption: "Trascina i file sull’isola e rilasciali su AirDrop per inviarli a un dispositivo vicino. Funziona anche con lo scaffale o la sezione File dell’isola disattivati.")
        case .ja:
            return .init(toggle: "Dynamic IslandでAirDrop",
                         caption: "ファイルをアイランドにドラッグしてAirDropにドロップすると、近くのデバイスに送信できます。シェルフやアイランドの「ファイル」セクションがオフでも使えます。")
        case .ko:
            return .init(toggle: "Dynamic Island에서 AirDrop",
                         caption: "파일을 아일랜드로 드래그해 AirDrop에 놓으면 근처 기기로 보낼 수 있습니다. 선반이나 아일랜드의 파일 섹션이 꺼져 있어도 작동합니다.")
        case .uk:
            return .init(toggle: "AirDrop у Dynamic Island",
                         caption: "Перетягніть файли на острів і відпустіть їх на AirDrop, щоб надіслати на пристрій поблизу. Працює, навіть якщо полицю або розділ «Файли» на острові вимкнено.")
        case .zhHans:
            return .init(toggle: "在灵动岛中使用隔空投送",
                         caption: "将文件拖到灵动岛，放到 AirDrop 上即可发送到附近的设备。即使储物架或灵动岛的“文件”部分已关闭也可使用。")
        case .zhTW:
            return .init(toggle: "在動態島使用 AirDrop",
                         caption: "將檔案拖到動態島，放在 AirDrop 上即可傳送到附近的裝置。即使暫存架或動態島的「檔案」區塊已關閉也能使用。")
        case .zhHK:
            return .init(toggle: "在動態島使用 AirDrop",
                         caption: "將檔案拖到動態島，放在 AirDrop 上即可傳送到附近的裝置。即使暫存架或動態島的「檔案」部分已關閉也可使用。")
        }
    }
}

struct ZenithWakaTimeStrings {
    let today: String
    let topProject: String
    let topLanguage: String
    let lastSevenDays: String
    let nothingYet: String
    let missingKey: String
    let failed: String
    let retry: String
}

extension ZenithStrings {
    static func wakaTime(_ language: AppLanguage) -> ZenithWakaTimeStrings {
        switch language {
        case .enUS:
            return .init(today: "Today", topProject: "Top project", topLanguage: "Top language", lastSevenDays: "Last 7 days", nothingYet: "No coding time yet today.", missingKey: "Add your WakaTime API key to ~/.wakatime.cfg.", failed: "Couldn’t reach WakaTime.", retry: "Try again")
        case .ptBR:
            return .init(today: "Hoje", topProject: "Projeto principal", topLanguage: "Linguagem principal", lastSevenDays: "Últimos 7 dias", nothingYet: "Nenhum tempo de código hoje ainda.", missingKey: "Adicione sua chave de API do WakaTime em ~/.wakatime.cfg.", failed: "Não foi possível acessar o WakaTime.", retry: "Tentar novamente")
        case .tr:
            return .init(today: "Bugün", topProject: "En çok proje", topLanguage: "En çok dil", lastSevenDays: "Son 7 gün", nothingYet: "Bugün henüz kodlama süresi yok.", missingKey: "WakaTime API anahtarını ~/.wakatime.cfg dosyasına ekle.", failed: "WakaTime’a ulaşılamadı.", retry: "Tekrar dene")
        case .ru:
            return .init(today: "Сегодня", topProject: "Главный проект", topLanguage: "Главный язык", lastSevenDays: "Последние 7 дней", nothingYet: "Сегодня ещё нет времени за кодом.", missingKey: "Добавьте ключ API WakaTime в ~/.wakatime.cfg.", failed: "Не удалось связаться с WakaTime.", retry: "Повторить")
        case .es:
            return .init(today: "Hoy", topProject: "Proyecto principal", topLanguage: "Lenguaje principal", lastSevenDays: "Últimos 7 días", nothingYet: "Todavía no hay tiempo de código hoy.", missingKey: "Añade tu clave de API de WakaTime en ~/.wakatime.cfg.", failed: "No se pudo conectar con WakaTime.", retry: "Reintentar")
        case .sk:
            return .init(today: "Dnes", topProject: "Hlavný projekt", topLanguage: "Hlavný jazyk", lastSevenDays: "Posledných 7 dní", nothingYet: "Dnes zatiaľ žiadny čas programovania.", missingKey: "Pridajte kľúč API WakaTime do ~/.wakatime.cfg.", failed: "Nepodarilo sa spojiť s WakaTime.", retry: "Skúsiť znova")
        case .de:
            return .init(today: "Heute", topProject: "Top-Projekt", topLanguage: "Top-Sprache", lastSevenDays: "Letzte 7 Tage", nothingYet: "Heute noch keine Programmierzeit.", missingKey: "Füge deinen WakaTime-API-Schlüssel in ~/.wakatime.cfg hinzu.", failed: "WakaTime ist nicht erreichbar.", retry: "Erneut versuchen")
        case .fr:
            return .init(today: "Aujourd’hui", topProject: "Projet principal", topLanguage: "Langage principal", lastSevenDays: "7 derniers jours", nothingYet: "Pas encore de temps de code aujourd’hui.", missingKey: "Ajoutez votre clé d’API WakaTime dans ~/.wakatime.cfg.", failed: "Impossible de joindre WakaTime.", retry: "Réessayer")
        case .it:
            return .init(today: "Oggi", topProject: "Progetto principale", topLanguage: "Linguaggio principale", lastSevenDays: "Ultimi 7 giorni", nothingYet: "Ancora nessun tempo di programmazione oggi.", missingKey: "Aggiungi la tua chiave API di WakaTime in ~/.wakatime.cfg.", failed: "Impossibile raggiungere WakaTime.", retry: "Riprova")
        case .ja:
            return .init(today: "今日", topProject: "トッププロジェクト", topLanguage: "トップ言語", lastSevenDays: "過去7日間", nothingYet: "今日のコーディング時間はまだありません。", missingKey: "WakaTimeのAPIキーを~/.wakatime.cfgに追加してください。", failed: "WakaTimeに接続できませんでした。", retry: "再試行")
        case .ko:
            return .init(today: "오늘", topProject: "주요 프로젝트", topLanguage: "주요 언어", lastSevenDays: "최근 7일", nothingYet: "오늘은 아직 코딩 시간이 없습니다.", missingKey: "~/.wakatime.cfg에 WakaTime API 키를 추가하세요.", failed: "WakaTime에 연결할 수 없습니다.", retry: "다시 시도")
        case .uk:
            return .init(today: "Сьогодні", topProject: "Головний проєкт", topLanguage: "Головна мова", lastSevenDays: "Останні 7 днів", nothingYet: "Сьогодні ще немає часу за кодом.", missingKey: "Додайте ключ API WakaTime у ~/.wakatime.cfg.", failed: "Не вдалося зв’язатися з WakaTime.", retry: "Повторити")
        case .zhHans:
            return .init(today: "今天", topProject: "主要项目", topLanguage: "主要语言", lastSevenDays: "最近 7 天", nothingYet: "今天还没有编程时间。", missingKey: "请在 ~/.wakatime.cfg 中添加 WakaTime API 密钥。", failed: "无法连接 WakaTime。", retry: "重试")
        case .zhTW:
            return .init(today: "今天", topProject: "主要專案", topLanguage: "主要語言", lastSevenDays: "最近 7 天", nothingYet: "今天還沒有寫程式的時間。", missingKey: "請在 ~/.wakatime.cfg 加入 WakaTime API 金鑰。", failed: "無法連線至 WakaTime。", retry: "再試一次")
        case .zhHK:
            return .init(today: "今天", topProject: "主要項目", topLanguage: "主要語言", lastSevenDays: "最近 7 天", nothingYet: "今天尚未有編程時間。", missingKey: "請在 ~/.wakatime.cfg 加入 WakaTime API 金鑰。", failed: "無法連線至 WakaTime。", retry: "再試一次")
        }
    }
}

extension ZenithStrings {
    /// The WakaTime card's line in the panel layout editor.
    static func wakaTimeSummary(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Today’s coding time and the last 7 days, from WakaTime."
        case .ptBR: return "Tempo de código de hoje e dos últimos 7 dias, do WakaTime."
        case .tr: return "WakaTime’dan bugünkü ve son 7 günlük kodlama süresi."
        case .ru: return "Время за кодом сегодня и за последние 7 дней из WakaTime."
        case .es: return "Tiempo de código de hoy y de los últimos 7 días, desde WakaTime."
        case .sk: return "Čas programovania dnes a za posledných 7 dní z WakaTime."
        case .de: return "Programmierzeit von heute und den letzten 7 Tagen aus WakaTime."
        case .fr: return "Temps de code d’aujourd’hui et des 7 derniers jours, depuis WakaTime."
        case .it: return "Tempo di programmazione di oggi e degli ultimi 7 giorni, da WakaTime."
        case .ja: return "WakaTimeから今日と過去7日間のコーディング時間を表示します。"
        case .ko: return "WakaTime에서 가져온 오늘과 최근 7일의 코딩 시간입니다."
        case .uk: return "Час за кодом сьогодні та за останні 7 днів із WakaTime."
        case .zhHans: return "来自 WakaTime 的今天和最近 7 天的编程时间。"
        case .zhTW: return "來自 WakaTime 的今天與最近 7 天寫程式時間。"
        case .zhHK: return "來自 WakaTime 的今天與最近 7 天編程時間。"
        }
    }
}
