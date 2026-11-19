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

struct ZenithWakaTimeTokenStrings {
    let codingNow: String
    let lastCodedFormat: String
    let rangeToday: String
    let rangeWeek: String
    let rangeMonth: String
    let rangeYear: String
    let rangeAll: String
    let dailyAverage: String
    let bestDay: String
    let calculating: String
    let languages: String
    let others: String
    let tokenTitle: String
    let tokenPlaceholder: String
    let tokenCaption: String
    let tokenSaved: String
    let tokenRejected: String
    let save: String
    let remove: String

    func lastCoded(_ relative: String) -> String { String(format: lastCodedFormat, relative) }
}

extension ZenithStrings {
    static func wakaTimeToken(_ language: AppLanguage) -> ZenithWakaTimeTokenStrings {
        switch language {
        case .enUS:
            return .init(codingNow: "Coding now",
                         lastCodedFormat: "Last coded %@",
                         rangeToday: "Today",
                         rangeWeek: "7 days",
                         rangeMonth: "30 days",
                         rangeYear: "Year",
                         rangeAll: "All time",
                         dailyAverage: "Daily average",
                         bestDay: "Best day",
                         calculating: "WakaTime is still calculating this range.",
                         languages: "Languages",
                         others: "Others",
                         tokenTitle: "Personal token",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "With a personal WakaTime token (scope read_stats) Zenith shows whether you are coding now and your time over any range. Without one it shows today only. The token stays on this Mac, readable only by your account.",
                         tokenSaved: "Saved on this Mac.",
                         tokenRejected: "That doesn’t look like a personal token (waka_tok_…).",
                         save: "Save",
                         remove: "Remove")
        case .ptBR:
            return .init(codingNow: "Programando agora",
                         lastCodedFormat: "Programou pela última vez %@",
                         rangeToday: "Hoje",
                         rangeWeek: "7 dias",
                         rangeMonth: "30 dias",
                         rangeYear: "Ano",
                         rangeAll: "Tudo",
                         dailyAverage: "Média diária",
                         bestDay: "Melhor dia",
                         calculating: "O WakaTime ainda está calculando este período.",
                         languages: "Linguagens",
                         others: "Outras",
                         tokenTitle: "Token pessoal",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "Com um token pessoal do WakaTime (escopo read_stats), o Zenith mostra se você está programando agora e seu tempo em qualquer período. Sem ele, mostra só hoje. O token fica neste Mac.",
                         tokenSaved: "Salvo neste Mac.",
                         tokenRejected: "Isso não parece um token pessoal (waka_tok_…).",
                         save: "Salvar",
                         remove: "Remover")
        case .tr:
            return .init(codingNow: "Şu an kodluyor",
                         lastCodedFormat: "Son kodlama %@",
                         rangeToday: "Bugün",
                         rangeWeek: "7 gün",
                         rangeMonth: "30 gün",
                         rangeYear: "Yıl",
                         rangeAll: "Tüm zamanlar",
                         dailyAverage: "Günlük ortalama",
                         bestDay: "En iyi gün",
                         calculating: "WakaTime bu aralığı hâlâ hesaplıyor.",
                         languages: "Diller",
                         others: "Diğerleri",
                         tokenTitle: "Kişisel token",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "Kişisel bir WakaTime token’ı (read_stats kapsamı) ile Zenith şu an kodlayıp kodlamadığını ve her aralıktaki süreni gösterir. Token olmadan yalnızca bugünü gösterir. Token bu Mac’te kalır.",
                         tokenSaved: "Bu Mac’e kaydedildi.",
                         tokenRejected: "Bu kişisel bir token’a benzemiyor (waka_tok_…).",
                         save: "Kaydet",
                         remove: "Kaldır")
        case .ru:
            return .init(codingNow: "Сейчас пишет код",
                         lastCodedFormat: "Последний код %@",
                         rangeToday: "Сегодня",
                         rangeWeek: "7 дней",
                         rangeMonth: "30 дней",
                         rangeYear: "Год",
                         rangeAll: "За всё время",
                         dailyAverage: "В среднем за день",
                         bestDay: "Лучший день",
                         calculating: "WakaTime ещё считает этот период.",
                         languages: "Языки",
                         others: "Другие",
                         tokenTitle: "Личный токен",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "С личным токеном WakaTime (область read_stats) Zenith показывает, пишете ли вы код прямо сейчас, и ваше время за любой период. Без него — только сегодня. Токен хранится на этом Mac.",
                         tokenSaved: "Сохранено на этом Mac.",
                         tokenRejected: "Это не похоже на личный токен (waka_tok_…).",
                         save: "Сохранить",
                         remove: "Удалить")
        case .es:
            return .init(codingNow: "Programando ahora",
                         lastCodedFormat: "Programó por última vez %@",
                         rangeToday: "Hoy",
                         rangeWeek: "7 días",
                         rangeMonth: "30 días",
                         rangeYear: "Año",
                         rangeAll: "Todo",
                         dailyAverage: "Promedio diario",
                         bestDay: "Mejor día",
                         calculating: "WakaTime todavía está calculando este periodo.",
                         languages: "Lenguajes",
                         others: "Otros",
                         tokenTitle: "Token personal",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "Con un token personal de WakaTime (alcance read_stats), Zenith muestra si estás programando ahora y tu tiempo en cualquier periodo. Sin él, solo muestra hoy. El token se queda en este Mac.",
                         tokenSaved: "Guardado en este Mac.",
                         tokenRejected: "Eso no parece un token personal (waka_tok_…).",
                         save: "Guardar",
                         remove: "Quitar")
        case .sk:
            return .init(codingNow: "Práve programuje",
                         lastCodedFormat: "Naposledy programoval %@",
                         rangeToday: "Dnes",
                         rangeWeek: "7 dní",
                         rangeMonth: "30 dní",
                         rangeYear: "Rok",
                         rangeAll: "Celkovo",
                         dailyAverage: "Denný priemer",
                         bestDay: "Najlepší deň",
                         calculating: "WakaTime toto obdobie ešte počíta.",
                         languages: "Jazyky",
                         others: "Ostatné",
                         tokenTitle: "Osobný token",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "S osobným tokenom WakaTime (rozsah read_stats) Zenith ukáže, či práve programujete, a váš čas za ľubovoľné obdobie. Bez neho ukáže iba dnešok. Token zostane v tomto Macu.",
                         tokenSaved: "Uložené v tomto Macu.",
                         tokenRejected: "Toto nevyzerá ako osobný token (waka_tok_…).",
                         save: "Uložiť",
                         remove: "Odstrániť")
        case .de:
            return .init(codingNow: "Codet gerade",
                         lastCodedFormat: "Zuletzt gecodet %@",
                         rangeToday: "Heute",
                         rangeWeek: "7 Tage",
                         rangeMonth: "30 Tage",
                         rangeYear: "Jahr",
                         rangeAll: "Gesamt",
                         dailyAverage: "Tagesdurchschnitt",
                         bestDay: "Bester Tag",
                         calculating: "WakaTime berechnet diesen Zeitraum noch.",
                         languages: "Sprachen",
                         others: "Andere",
                         tokenTitle: "Persönliches Token",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "Mit einem persönlichen WakaTime-Token (Bereich read_stats) zeigt Zenith, ob du gerade codest, und deine Zeit in jedem Zeitraum. Ohne Token nur heute. Das Token bleibt auf diesem Mac.",
                         tokenSaved: "Auf diesem Mac gesichert.",
                         tokenRejected: "Das sieht nicht nach einem persönlichen Token aus (waka_tok_…).",
                         save: "Sichern",
                         remove: "Entfernen")
        case .fr:
            return .init(codingNow: "Code en ce moment",
                         lastCodedFormat: "Dernier code %@",
                         rangeToday: "Aujourd’hui",
                         rangeWeek: "7 jours",
                         rangeMonth: "30 jours",
                         rangeYear: "Année",
                         rangeAll: "Tout",
                         dailyAverage: "Moyenne quotidienne",
                         bestDay: "Meilleur jour",
                         calculating: "WakaTime calcule encore cette période.",
                         languages: "Langages",
                         others: "Autres",
                         tokenTitle: "Jeton personnel",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "Avec un jeton personnel WakaTime (portée read_stats), Zenith indique si vous codez en ce moment et votre temps sur n’importe quelle période. Sans jeton, il n’affiche qu’aujourd’hui. Le jeton reste sur ce Mac.",
                         tokenSaved: "Enregistré sur ce Mac.",
                         tokenRejected: "Cela ne ressemble pas à un jeton personnel (waka_tok_…).",
                         save: "Enregistrer",
                         remove: "Supprimer")
        case .it:
            return .init(codingNow: "Sta programmando",
                         lastCodedFormat: "Ultima programmazione %@",
                         rangeToday: "Oggi",
                         rangeWeek: "7 giorni",
                         rangeMonth: "30 giorni",
                         rangeYear: "Anno",
                         rangeAll: "Sempre",
                         dailyAverage: "Media giornaliera",
                         bestDay: "Giorno migliore",
                         calculating: "WakaTime sta ancora calcolando questo periodo.",
                         languages: "Linguaggi",
                         others: "Altri",
                         tokenTitle: "Token personale",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "Con un token personale di WakaTime (ambito read_stats) Zenith mostra se stai programmando ora e il tuo tempo in qualsiasi periodo. Senza, mostra solo oggi. Il token resta su questo Mac.",
                         tokenSaved: "Salvato su questo Mac.",
                         tokenRejected: "Non sembra un token personale (waka_tok_…).",
                         save: "Salva",
                         remove: "Rimuovi")
        case .ja:
            return .init(codingNow: "コーディング中",
                         lastCodedFormat: "最後のコーディング: %@",
                         rangeToday: "今日",
                         rangeWeek: "7日間",
                         rangeMonth: "30日間",
                         rangeYear: "1年",
                         rangeAll: "全期間",
                         dailyAverage: "1日の平均",
                         bestDay: "ベストデイ",
                         calculating: "WakaTimeがこの期間を集計中です。",
                         languages: "言語",
                         others: "その他",
                         tokenTitle: "個人用トークン",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "WakaTimeの個人用トークン（スコープ read_stats）があると、Zenithは今コーディング中かどうかと任意の期間の時間を表示します。ない場合は今日のみ表示します。トークンはこのMacに保存されます。",
                         tokenSaved: "このMacに保存しました。",
                         tokenRejected: "個人用トークン（waka_tok_…）ではないようです。",
                         save: "保存",
                         remove: "削除")
        case .ko:
            return .init(codingNow: "지금 코딩 중",
                         lastCodedFormat: "마지막 코딩 %@",
                         rangeToday: "오늘",
                         rangeWeek: "7일",
                         rangeMonth: "30일",
                         rangeYear: "1년",
                         rangeAll: "전체",
                         dailyAverage: "일일 평균",
                         bestDay: "최고의 날",
                         calculating: "WakaTime이 아직 이 기간을 계산하고 있습니다.",
                         languages: "언어",
                         others: "기타",
                         tokenTitle: "개인 토큰",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "WakaTime 개인 토큰(범위 read_stats)이 있으면 Zenith가 지금 코딩 중인지와 모든 기간의 시간을 보여 줍니다. 없으면 오늘만 보여 줍니다. 토큰은 이 Mac에 보관됩니다.",
                         tokenSaved: "이 Mac에 저장했습니다.",
                         tokenRejected: "개인 토큰(waka_tok_…)이 아닌 것 같습니다.",
                         save: "저장",
                         remove: "제거")
        case .uk:
            return .init(codingNow: "Зараз пише код",
                         lastCodedFormat: "Останній код %@",
                         rangeToday: "Сьогодні",
                         rangeWeek: "7 днів",
                         rangeMonth: "30 днів",
                         rangeYear: "Рік",
                         rangeAll: "За весь час",
                         dailyAverage: "У середньому за день",
                         bestDay: "Найкращий день",
                         calculating: "WakaTime ще рахує цей період.",
                         languages: "Мови",
                         others: "Інші",
                         tokenTitle: "Особистий токен",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "З особистим токеном WakaTime (область read_stats) Zenith показує, чи ви зараз пишете код, і ваш час за будь-який період. Без нього — лише сьогодні. Токен зберігається на цьому Mac.",
                         tokenSaved: "Збережено на цьому Mac.",
                         tokenRejected: "Це не схоже на особистий токен (waka_tok_…).",
                         save: "Зберегти",
                         remove: "Видалити")
        case .zhHans:
            return .init(codingNow: "正在编程",
                         lastCodedFormat: "上次编程：%@",
                         rangeToday: "今天",
                         rangeWeek: "7 天",
                         rangeMonth: "30 天",
                         rangeYear: "一年",
                         rangeAll: "全部",
                         dailyAverage: "每日平均",
                         bestDay: "最佳一天",
                         calculating: "WakaTime 仍在计算这个时间段。",
                         languages: "语言",
                         others: "其他",
                         tokenTitle: "个人令牌",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "有了 WakaTime 个人令牌（范围 read_stats），Zenith 会显示你是否正在编程，以及任意时间段的编程时间。没有令牌时只显示今天。令牌保存在这台 Mac 上。",
                         tokenSaved: "已保存在这台 Mac 上。",
                         tokenRejected: "这看起来不像个人令牌（waka_tok_…）。",
                         save: "保存",
                         remove: "移除")
        case .zhTW:
            return .init(codingNow: "正在寫程式",
                         lastCodedFormat: "上次寫程式：%@",
                         rangeToday: "今天",
                         rangeWeek: "7 天",
                         rangeMonth: "30 天",
                         rangeYear: "一年",
                         rangeAll: "全部",
                         dailyAverage: "每日平均",
                         bestDay: "最佳一天",
                         calculating: "WakaTime 仍在計算這段期間。",
                         languages: "語言",
                         others: "其他",
                         tokenTitle: "個人權杖",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "有了 WakaTime 個人權杖（範圍 read_stats），Zenith 會顯示你是否正在寫程式，以及任何期間的時間。沒有權杖時只顯示今天。權杖會保存在這台 Mac 上。",
                         tokenSaved: "已儲存在這台 Mac 上。",
                         tokenRejected: "這看起來不像個人權杖（waka_tok_…）。",
                         save: "儲存",
                         remove: "移除")
        case .zhHK:
            return .init(codingNow: "正在編程",
                         lastCodedFormat: "上次編程：%@",
                         rangeToday: "今天",
                         rangeWeek: "7 天",
                         rangeMonth: "30 天",
                         rangeYear: "一年",
                         rangeAll: "全部",
                         dailyAverage: "每日平均",
                         bestDay: "最佳一天",
                         calculating: "WakaTime 仍在計算這段期間。",
                         languages: "語言",
                         others: "其他",
                         tokenTitle: "個人權杖",
                         tokenPlaceholder: "waka_tok_…",
                         tokenCaption: "有了 WakaTime 個人權杖（範圍 read_stats），Zenith 會顯示你是否正在編程，以及任何期間的時間。沒有權杖時只顯示今天。權杖會儲存在這部 Mac 上。",
                         tokenSaved: "已儲存在這台 Mac 上。",
                         tokenRejected: "這看起來不像個人權杖（waka_tok_…）。",
                         save: "儲存",
                         remove: "移除")
        }
    }
}

struct ZenithWakaTimeGoalStrings {
    let goalTitle: String
    let goalOff: String
    let goalReachedTitle: String
    let goalReachedBodyFormat: String
    let goalProgressFormat: String

    func reachedBody(_ total: String) -> String { String(format: goalReachedBodyFormat, total) }
    func progress(_ goal: String) -> String { String(format: goalProgressFormat, goal) }
}

extension ZenithStrings {
    static func wakaTimeGoal(_ language: AppLanguage) -> ZenithWakaTimeGoalStrings {
        switch language {
        case .enUS:
            return .init(goalTitle: "Daily goal", goalOff: "Off", goalReachedTitle: "Daily coding goal reached", goalReachedBodyFormat: "%@ of coding today.", goalProgressFormat: "of %@")
        case .ptBR:
            return .init(goalTitle: "Meta diária", goalOff: "Desligada", goalReachedTitle: "Meta diária de código atingida", goalReachedBodyFormat: "%@ de código hoje.", goalProgressFormat: "de %@")
        case .tr:
            return .init(goalTitle: "Günlük hedef", goalOff: "Kapalı", goalReachedTitle: "Günlük kodlama hedefine ulaşıldı", goalReachedBodyFormat: "Bugün %@ kodlama.", goalProgressFormat: "/ %@")
        case .ru:
            return .init(goalTitle: "Цель на день", goalOff: "Выкл.", goalReachedTitle: "Дневная цель по коду достигнута", goalReachedBodyFormat: "Сегодня %@ за кодом.", goalProgressFormat: "из %@")
        case .es:
            return .init(goalTitle: "Meta diaria", goalOff: "Desactivada", goalReachedTitle: "Meta diaria de código alcanzada", goalReachedBodyFormat: "%@ de código hoy.", goalProgressFormat: "de %@")
        case .sk:
            return .init(goalTitle: "Denný cieľ", goalOff: "Vypnutý", goalReachedTitle: "Denný cieľ programovania splnený", goalReachedBodyFormat: "Dnes %@ programovania.", goalProgressFormat: "z %@")
        case .de:
            return .init(goalTitle: "Tagesziel", goalOff: "Aus", goalReachedTitle: "Tagesziel fürs Programmieren erreicht", goalReachedBodyFormat: "Heute %@ programmiert.", goalProgressFormat: "von %@")
        case .fr:
            return .init(goalTitle: "Objectif quotidien", goalOff: "Désactivé", goalReachedTitle: "Objectif de code du jour atteint", goalReachedBodyFormat: "%@ de code aujourd’hui.", goalProgressFormat: "sur %@")
        case .it:
            return .init(goalTitle: "Obiettivo giornaliero", goalOff: "No", goalReachedTitle: "Obiettivo di programmazione raggiunto", goalReachedBodyFormat: "%@ di programmazione oggi.", goalProgressFormat: "su %@")
        case .ja:
            return .init(goalTitle: "1日の目標", goalOff: "オフ", goalReachedTitle: "今日のコーディング目標を達成しました", goalReachedBodyFormat: "今日は%@コーディングしました。", goalProgressFormat: "/ %@")
        case .ko:
            return .init(goalTitle: "일일 목표", goalOff: "끔", goalReachedTitle: "오늘의 코딩 목표 달성", goalReachedBodyFormat: "오늘 %@ 코딩했습니다.", goalProgressFormat: "/ %@")
        case .uk:
            return .init(goalTitle: "Ціль на день", goalOff: "Вимк.", goalReachedTitle: "Денну ціль за кодом досягнуто", goalReachedBodyFormat: "Сьогодні %@ за кодом.", goalProgressFormat: "з %@")
        case .zhHans:
            return .init(goalTitle: "每日目标", goalOff: "关闭", goalReachedTitle: "已达成今日编程目标", goalReachedBodyFormat: "今天已编程 %@。", goalProgressFormat: "/ %@")
        case .zhTW:
            return .init(goalTitle: "每日目標", goalOff: "關閉", goalReachedTitle: "已達成今日寫程式目標", goalReachedBodyFormat: "今天已寫程式 %@。", goalProgressFormat: "/ %@")
        case .zhHK:
            return .init(goalTitle: "每日目標", goalOff: "關閉", goalReachedTitle: "已達成今日編程目標", goalReachedBodyFormat: "今天已編程 %@。", goalProgressFormat: "/ %@")
        }
    }
}
