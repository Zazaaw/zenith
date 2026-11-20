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

struct ZenithLockScreenWidgetStrings {
    let weather: String
    let reminders: String
    /// Under the Weather switch once location access is granted.
    let weatherCaption: String
    /// Under the Reminders switch once access is granted.
    let remindersCaption: String
    let locationNeeded: String
    let locationDenied: String
    let remindersNeeded: String
    let remindersDenied: String
    /// Spoken with the day’s highest and lowest temperatures.
    let high: String
    let low: String
    let overdue: String
}

extension ZenithStrings {
    /// The lock screen’s weather and reminders, and their permissions.
    static func lockScreenWidgets(_ language: AppLanguage) -> ZenithLockScreenWidgetStrings {
        switch language {
        case .enUS:
            return .init(weather: "Weather", reminders: "Reminders",
                         weatherCaption: "The temperature from Open-Meteo for your approximate location. The place name never shows.",
                         remindersCaption: "Up to three reminders due today or overdue, by title only.",
                         locationNeeded: "Weather needs your approximate location.",
                         locationDenied: "Location access for Zenith is off. Turn it on in System Settings to see the weather.",
                         remindersNeeded: "Zenith needs access to your reminders to show them.",
                         remindersDenied: "Reminders access for Zenith is off. Turn it on in System Settings to see them.",
                         high: "High", low: "Low", overdue: "Overdue")
        case .ptBR:
            return .init(weather: "Tempo", reminders: "Lembretes",
                         weatherCaption: "A temperatura do Open-Meteo para sua localização aproximada. O nome do lugar nunca aparece.",
                         remindersCaption: "Até três lembretes para hoje ou atrasados, só pelo título.",
                         locationNeeded: "O tempo precisa da sua localização aproximada.",
                         locationDenied: "O acesso à localização do Zenith está desativado. Ative-o nos Ajustes do Sistema para ver o tempo.",
                         remindersNeeded: "O Zenith precisa de acesso aos seus lembretes para mostrá-los.",
                         remindersDenied: "O acesso aos lembretes do Zenith está desativado. Ative-o nos Ajustes do Sistema para vê-los.",
                         high: "Máxima", low: "Mínima", overdue: "Atrasado")
        case .tr:
            return .init(weather: "Hava Durumu", reminders: "Anımsatıcılar",
                         weatherCaption: "Yaklaşık konumun için Open-Meteo’dan sıcaklık. Yer adı hiçbir zaman gösterilmez.",
                         remindersCaption: "Bugün veya gecikmiş en fazla üç anımsatıcı, yalnızca başlıkla.",
                         locationNeeded: "Hava durumu için yaklaşık konumun gerekiyor.",
                         locationDenied: "Zenith için konum erişimi kapalı. Hava durumunu görmek için Sistem Ayarları’nda aç.",
                         remindersNeeded: "Zenith’in anımsatıcılarını gösterebilmesi için erişim gerekiyor.",
                         remindersDenied: "Zenith için Anımsatıcılar erişimi kapalı. Görmek için Sistem Ayarları’nda aç.",
                         high: "En yüksek", low: "En düşük", overdue: "Gecikmiş")
        case .ru:
            return .init(weather: "Погода", reminders: "Напоминания",
                         weatherCaption: "Температура от Open-Meteo для вашего примерного местоположения. Название места не показывается.",
                         remindersCaption: "До трёх напоминаний на сегодня или просроченных, только названия.",
                         locationNeeded: "Для погоды нужно ваше примерное местоположение.",
                         locationDenied: "Доступ Zenith к геопозиции выключен. Включите его в Системных настройках, чтобы видеть погоду.",
                         remindersNeeded: "Zenith нужен доступ к напоминаниям, чтобы показывать их.",
                         remindersDenied: "Доступ Zenith к напоминаниям выключен. Включите его в Системных настройках, чтобы видеть их.",
                         high: "Макс.", low: "Мин.", overdue: "Просрочено")
        case .es:
            return .init(weather: "Tiempo", reminders: "Recordatorios",
                         weatherCaption: "La temperatura de Open-Meteo para tu ubicación aproximada. El nombre del lugar nunca aparece.",
                         remindersCaption: "Hasta tres recordatorios para hoy o vencidos, solo con su título.",
                         locationNeeded: "El tiempo necesita tu ubicación aproximada.",
                         locationDenied: "El acceso a la ubicación de Zenith está desactivado. Actívalo en Ajustes del Sistema para ver el tiempo.",
                         remindersNeeded: "Zenith necesita acceso a tus recordatorios para mostrarlos.",
                         remindersDenied: "El acceso a Recordatorios de Zenith está desactivado. Actívalo en Ajustes del Sistema para verlos.",
                         high: "Máxima", low: "Mínima", overdue: "Vencido")
        case .sk:
            return .init(weather: "Počasie", reminders: "Pripomienky",
                         weatherCaption: "Teplota z Open-Meteo pre vašu približnú polohu. Názov miesta sa nikdy nezobrazí.",
                         remindersCaption: "Najviac tri pripomienky na dnes alebo po termíne, iba s názvom.",
                         locationNeeded: "Počasie potrebuje vašu približnú polohu.",
                         locationDenied: "Prístup Zenithu k polohe je vypnutý. Zapnite ho v Systémových nastaveniach, aby ste videli počasie.",
                         remindersNeeded: "Zenith potrebuje prístup k vašim pripomienkam, aby ich mohol zobraziť.",
                         remindersDenied: "Prístup Zenithu k pripomienkam je vypnutý. Zapnite ho v Systémových nastaveniach, aby ste ich videli.",
                         high: "Najvyššia", low: "Najnižšia", overdue: "Po termíne")
        case .de:
            return .init(weather: "Wetter", reminders: "Erinnerungen",
                         weatherCaption: "Die Temperatur von Open-Meteo für deinen ungefähren Standort. Der Ortsname wird nie angezeigt.",
                         remindersCaption: "Bis zu drei heute fällige oder überfällige Erinnerungen, nur mit Titel.",
                         locationNeeded: "Für das Wetter wird dein ungefährer Standort benötigt.",
                         locationDenied: "Der Standortzugriff für Zenith ist aus. Schalte ihn in den Systemeinstellungen ein, um das Wetter zu sehen.",
                         remindersNeeded: "Zenith braucht Zugriff auf deine Erinnerungen, um sie anzuzeigen.",
                         remindersDenied: "Der Zugriff auf Erinnerungen ist für Zenith aus. Schalte ihn in den Systemeinstellungen ein, um sie zu sehen.",
                         high: "Höchstwert", low: "Tiefstwert", overdue: "Überfällig")
        case .fr:
            return .init(weather: "Météo", reminders: "Rappels",
                         weatherCaption: "La température d’Open-Meteo pour votre position approximative. Le nom du lieu n’apparaît jamais.",
                         remindersCaption: "Jusqu’à trois rappels du jour ou en retard, avec leur titre seulement.",
                         locationNeeded: "La météo a besoin de votre position approximative.",
                         locationDenied: "L’accès à la localisation est désactivé pour Zenith. Activez-le dans Réglages Système pour voir la météo.",
                         remindersNeeded: "Zenith a besoin d’accéder à vos rappels pour les afficher.",
                         remindersDenied: "L’accès aux rappels est désactivé pour Zenith. Activez-le dans Réglages Système pour les voir.",
                         high: "Max.", low: "Min.", overdue: "En retard")
        case .it:
            return .init(weather: "Meteo", reminders: "Promemoria",
                         weatherCaption: "La temperatura di Open-Meteo per la tua posizione approssimativa. Il nome del luogo non compare mai.",
                         remindersCaption: "Fino a tre promemoria di oggi o scaduti, solo con il titolo.",
                         locationNeeded: "Il meteo ha bisogno della tua posizione approssimativa.",
                         locationDenied: "L’accesso alla posizione per Zenith è disattivato. Attivalo in Impostazioni di Sistema per vedere il meteo.",
                         remindersNeeded: "Zenith ha bisogno di accedere ai tuoi promemoria per mostrarli.",
                         remindersDenied: "L’accesso ai promemoria per Zenith è disattivato. Attivalo in Impostazioni di Sistema per vederli.",
                         high: "Massima", low: "Minima", overdue: "Scaduto")
        case .ja:
            return .init(weather: "天気", reminders: "リマインダー",
                         weatherCaption: "おおよその位置に基づくOpen-Meteoの気温です。地名は表示されません。",
                         remindersCaption: "今日が期限または期限切れのリマインダーを最大3件、タイトルだけ表示します。",
                         locationNeeded: "天気にはおおよその位置情報が必要です。",
                         locationDenied: "Zenithの位置情報へのアクセスがオフです。天気を表示するにはシステム設定でオンにしてください。",
                         remindersNeeded: "リマインダーを表示するには、Zenithにリマインダーへのアクセスを許可してください。",
                         remindersDenied: "Zenithのリマインダーへのアクセスがオフです。表示するにはシステム設定でオンにしてください。",
                         high: "最高", low: "最低", overdue: "期限切れ")
        case .ko:
            return .init(weather: "날씨", reminders: "미리 알림",
                         weatherCaption: "대략적인 위치를 기준으로 Open-Meteo에서 가져온 기온입니다. 장소 이름은 표시되지 않습니다.",
                         remindersCaption: "오늘 마감이거나 기한이 지난 미리 알림을 최대 3개까지 제목만 표시합니다.",
                         locationNeeded: "날씨를 보려면 대략적인 위치가 필요합니다.",
                         locationDenied: "Zenith의 위치 접근이 꺼져 있습니다. 날씨를 보려면 시스템 설정에서 켜세요.",
                         remindersNeeded: "미리 알림을 표시하려면 Zenith에 미리 알림 접근 권한이 필요합니다.",
                         remindersDenied: "Zenith의 미리 알림 접근이 꺼져 있습니다. 보려면 시스템 설정에서 켜세요.",
                         high: "최고", low: "최저", overdue: "기한 지남")
        case .uk:
            return .init(weather: "Погода", reminders: "Нагадування",
                         weatherCaption: "Температура від Open-Meteo для вашого приблизного місця. Назва місця ніколи не показується.",
                         remindersCaption: "До трьох нагадувань на сьогодні або прострочених, лише назви.",
                         locationNeeded: "Для погоди потрібне ваше приблизне місцезнаходження.",
                         locationDenied: "Доступ Zenith до геолокації вимкнено. Увімкніть його в Системних параметрах, щоб бачити погоду.",
                         remindersNeeded: "Zenith потрібен доступ до нагадувань, щоб показувати їх.",
                         remindersDenied: "Доступ Zenith до нагадувань вимкнено. Увімкніть його в Системних параметрах, щоб бачити їх.",
                         high: "Макс.", low: "Мін.", overdue: "Прострочено")
        case .zhHans:
            return .init(weather: "天气", reminders: "提醒事项",
                         weatherCaption: "根据你的大致位置从 Open-Meteo 获取的气温。不会显示地名。",
                         remindersCaption: "最多三个今天到期或已逾期的提醒事项，仅显示标题。",
                         locationNeeded: "天气需要你的大致位置。",
                         locationDenied: "Zenith 的定位访问已关闭。请在系统设置中打开以查看天气。",
                         remindersNeeded: "Zenith 需要访问你的提醒事项才能显示它们。",
                         remindersDenied: "Zenith 的提醒事项访问已关闭。请在系统设置中打开以查看。",
                         high: "最高", low: "最低", overdue: "已逾期")
        case .zhTW:
            return .init(weather: "天氣", reminders: "提醒事項",
                         weatherCaption: "依據你的大致位置從 Open-Meteo 取得的氣溫。不會顯示地名。",
                         remindersCaption: "最多三個今天到期或已逾期的提醒事項，只顯示標題。",
                         locationNeeded: "天氣需要你的大致位置。",
                         locationDenied: "Zenith 的定位取用權限已關閉。請在系統設定中開啟以查看天氣。",
                         remindersNeeded: "Zenith 需要取用你的提醒事項才能顯示。",
                         remindersDenied: "Zenith 的提醒事項取用權限已關閉。請在系統設定中開啟以查看。",
                         high: "最高", low: "最低", overdue: "已逾期")
        case .zhHK:
            return .init(weather: "天氣", reminders: "提醒事項",
                         weatherCaption: "根據你的大概位置從 Open-Meteo 取得的氣溫。不會顯示地名。",
                         remindersCaption: "最多三個今天到期或已逾期的提醒事項，只顯示標題。",
                         locationNeeded: "天氣需要你的大概位置。",
                         locationDenied: "Zenith 的定位存取權限已關閉。請在系統設定中開啟以查看天氣。",
                         remindersNeeded: "Zenith 需要存取你的提醒事項才能顯示。",
                         remindersDenied: "Zenith 的提醒事項存取權限已關閉。請在系統設定中開啟以查看。",
                         high: "最高", low: "最低", overdue: "已逾期")
        }
    }
}

// MARK: Vercel (Zenith fork)

struct ZenithVercelStrings {
    let tokenTitle: String
    let tokenPlaceholder: String
    let tokenCaption: String
    let tokenSaved: String
    let tokenRejected: String
    let save: String
    let remove: String
    let liveActivity: String
    let liveActivityCaption: String
    let missingToken: String
    let unauthorized: String
    let failed: String
    let retry: String
    let empty: String
    let production: String
    let preview: String
    let queued: String
    let initializing: String
    let building: String
    let ready: String
    let error: String
    let canceled: String

    func label(_ state: VercelSupport.State) -> String {
        switch state {
        case .queued: return queued
        case .initializing: return initializing
        case .building: return building
        case .ready: return ready
        case .error: return error
        case .canceled: return canceled
        case .unknown: return "—"
        }
    }
}

extension ZenithStrings {
    static func vercel(_ language: AppLanguage) -> ZenithVercelStrings {
        switch language {
        case .enUS:
            return .init(tokenTitle: "Access token",
                         tokenPlaceholder: "Paste a Vercel access token",
                         tokenCaption: "Create one at vercel.com/account/tokens. Zenith uses it only to read your recent deployments, and keeps it in a private file on this Mac.",
                         tokenSaved: "Saved on this Mac.",
                         tokenRejected: "That doesn’t look like a Vercel token.",
                         save: "Save",
                         remove: "Remove",
                         liveActivity: "Show builds in the closed island",
                         liveActivityCaption: "While a deployment builds, the closed island follows it, then shows for a moment how it ended.",
                         missingToken: "Add a Vercel access token in this section’s settings.",
                         unauthorized: "Vercel didn’t accept the token. Add a new one in this section’s settings.",
                         failed: "Couldn’t reach Vercel.",
                         retry: "Try again",
                         empty: "No deployments yet.",
                         production: "Production",
                         preview: "Preview",
                         queued: "Queued",
                         initializing: "Initializing",
                         building: "Building",
                         ready: "Ready",
                         error: "Error",
                         canceled: "Canceled")
        case .ptBR:
            return .init(tokenTitle: "Token de acesso",
                         tokenPlaceholder: "Cole um token de acesso da Vercel",
                         tokenCaption: "Crie um em vercel.com/account/tokens. O Zenith o usa só para ler suas implantações recentes e o guarda em um arquivo privado neste Mac.",
                         tokenSaved: "Salvo neste Mac.",
                         tokenRejected: "Isso não parece um token da Vercel.",
                         save: "Salvar",
                         remove: "Remover",
                         liveActivity: "Mostrar builds na ilha fechada",
                         liveActivityCaption: "Enquanto uma implantação é criada, a ilha fechada a acompanha e depois mostra por um momento como terminou.",
                         missingToken: "Adicione um token de acesso da Vercel nos ajustes desta seção.",
                         unauthorized: "A Vercel não aceitou o token. Adicione um novo nos ajustes desta seção.",
                         failed: "Não foi possível acessar a Vercel.",
                         retry: "Tentar novamente",
                         empty: "Nenhuma implantação ainda.",
                         production: "Produção",
                         preview: "Prévia",
                         queued: "Na fila",
                         initializing: "Iniciando",
                         building: "Criando",
                         ready: "Pronta",
                         error: "Erro",
                         canceled: "Cancelada")
        case .tr:
            return .init(tokenTitle: "Erişim belirteci",
                         tokenPlaceholder: "Vercel erişim belirtecini yapıştır",
                         tokenCaption: "vercel.com/account/tokens adresinden oluştur. Zenith onu yalnızca son dağıtımlarını okumak için kullanır ve bu Mac’te özel bir dosyada saklar.",
                         tokenSaved: "Bu Mac’e kaydedildi.",
                         tokenRejected: "Bu bir Vercel belirteci gibi görünmüyor.",
                         save: "Kaydet",
                         remove: "Kaldır",
                         liveActivity: "Derlemeleri kapalı adada göster",
                         liveActivityCaption: "Bir dağıtım derlenirken kapalı ada onu izler, ardından nasıl bittiğini kısa bir süre gösterir.",
                         missingToken: "Bu bölümün ayarlarına bir Vercel erişim belirteci ekle.",
                         unauthorized: "Vercel belirteci kabul etmedi. Bu bölümün ayarlarına yenisini ekle.",
                         failed: "Vercel’e ulaşılamadı.",
                         retry: "Tekrar dene",
                         empty: "Henüz dağıtım yok.",
                         production: "Üretim",
                         preview: "Önizleme",
                         queued: "Sırada",
                         initializing: "Başlatılıyor",
                         building: "Derleniyor",
                         ready: "Hazır",
                         error: "Hata",
                         canceled: "İptal edildi")
        case .ru:
            return .init(tokenTitle: "Токен доступа",
                         tokenPlaceholder: "Вставьте токен доступа Vercel",
                         tokenCaption: "Создайте его на vercel.com/account/tokens. Zenith использует его только для чтения последних развёртываний и хранит в закрытом файле на этом Mac.",
                         tokenSaved: "Сохранено на этом Mac.",
                         tokenRejected: "Это не похоже на токен Vercel.",
                         save: "Сохранить",
                         remove: "Удалить",
                         liveActivity: "Показывать сборки в закрытом острове",
                         liveActivityCaption: "Пока идёт сборка развёртывания, закрытый остров следит за ней, а затем ненадолго показывает результат.",
                         missingToken: "Добавьте токен доступа Vercel в настройках этого раздела.",
                         unauthorized: "Vercel не принял токен. Добавьте новый в настройках этого раздела.",
                         failed: "Не удалось связаться с Vercel.",
                         retry: "Повторить",
                         empty: "Развёртываний пока нет.",
                         production: "Продакшен",
                         preview: "Превью",
                         queued: "В очереди",
                         initializing: "Запуск",
                         building: "Сборка",
                         ready: "Готово",
                         error: "Ошибка",
                         canceled: "Отменено")
        case .es:
            return .init(tokenTitle: "Token de acceso",
                         tokenPlaceholder: "Pega un token de acceso de Vercel",
                         tokenCaption: "Crea uno en vercel.com/account/tokens. Zenith solo lo usa para leer tus despliegues recientes y lo guarda en un archivo privado en este Mac.",
                         tokenSaved: "Guardado en este Mac.",
                         tokenRejected: "Eso no parece un token de Vercel.",
                         save: "Guardar",
                         remove: "Eliminar",
                         liveActivity: "Mostrar compilaciones en la isla cerrada",
                         liveActivityCaption: "Mientras se compila un despliegue, la isla cerrada lo sigue y luego muestra un momento cómo terminó.",
                         missingToken: "Añade un token de acceso de Vercel en los ajustes de esta sección.",
                         unauthorized: "Vercel no aceptó el token. Añade uno nuevo en los ajustes de esta sección.",
                         failed: "No se pudo conectar con Vercel.",
                         retry: "Reintentar",
                         empty: "Todavía no hay despliegues.",
                         production: "Producción",
                         preview: "Vista previa",
                         queued: "En cola",
                         initializing: "Iniciando",
                         building: "Compilando",
                         ready: "Listo",
                         error: "Error",
                         canceled: "Cancelado")
        case .sk:
            return .init(tokenTitle: "Prístupový token",
                         tokenPlaceholder: "Vložte prístupový token Vercel",
                         tokenCaption: "Vytvorte ho na vercel.com/account/tokens. Zenith ho používa len na čítanie vašich posledných nasadení a uchováva ho v súkromnom súbore v tomto Macu.",
                         tokenSaved: "Uložené v tomto Macu.",
                         tokenRejected: "Toto nevyzerá ako token Vercel.",
                         save: "Uložiť",
                         remove: "Odstrániť",
                         liveActivity: "Zobrazovať zostavy v zatvorenom Dynamic Island",
                         liveActivityCaption: "Kým sa nasadenie zostavuje, zatvorený Dynamic Island ho sleduje a potom na chvíľu ukáže, ako skončilo.",
                         missingToken: "Pridajte prístupový token Vercel v nastaveniach tejto sekcie.",
                         unauthorized: "Vercel token neprijal. Pridajte nový v nastaveniach tejto sekcie.",
                         failed: "Nepodarilo sa spojiť s Vercel.",
                         retry: "Skúsiť znova",
                         empty: "Zatiaľ žiadne nasadenia.",
                         production: "Produkcia",
                         preview: "Náhľad",
                         queued: "V poradí",
                         initializing: "Spúšťa sa",
                         building: "Zostavuje sa",
                         ready: "Hotovo",
                         error: "Chyba",
                         canceled: "Zrušené")
        case .de:
            return .init(tokenTitle: "Zugriffstoken",
                         tokenPlaceholder: "Vercel-Zugriffstoken einfügen",
                         tokenCaption: "Erstelle eines unter vercel.com/account/tokens. Zenith nutzt es nur, um deine letzten Deployments zu lesen, und bewahrt es in einer privaten Datei auf diesem Mac auf.",
                         tokenSaved: "Auf diesem Mac gesichert.",
                         tokenRejected: "Das sieht nicht wie ein Vercel-Token aus.",
                         save: "Sichern",
                         remove: "Entfernen",
                         liveActivity: "Builds in der geschlossenen Insel zeigen",
                         liveActivityCaption: "Während ein Deployment gebaut wird, folgt ihm die geschlossene Insel und zeigt danach kurz, wie es ausging.",
                         missingToken: "Füge in den Einstellungen dieses Bereichs ein Vercel-Zugriffstoken hinzu.",
                         unauthorized: "Vercel hat das Token nicht akzeptiert. Füge in den Einstellungen dieses Bereichs ein neues hinzu.",
                         failed: "Vercel ist nicht erreichbar.",
                         retry: "Erneut versuchen",
                         empty: "Noch keine Deployments.",
                         production: "Produktion",
                         preview: "Vorschau",
                         queued: "Wartend",
                         initializing: "Startet",
                         building: "Wird gebaut",
                         ready: "Bereit",
                         error: "Fehler",
                         canceled: "Abgebrochen")
        case .fr:
            return .init(tokenTitle: "Jeton d’accès",
                         tokenPlaceholder: "Collez un jeton d’accès Vercel",
                         tokenCaption: "Créez-en un sur vercel.com/account/tokens. Zenith ne s’en sert que pour lire vos déploiements récents et le garde dans un fichier privé sur ce Mac.",
                         tokenSaved: "Enregistré sur ce Mac.",
                         tokenRejected: "Cela ne ressemble pas à un jeton Vercel.",
                         save: "Enregistrer",
                         remove: "Supprimer",
                         liveActivity: "Afficher les builds dans l’île fermée",
                         liveActivityCaption: "Pendant la construction d’un déploiement, l’île fermée le suit, puis montre un instant comment il s’est terminé.",
                         missingToken: "Ajoutez un jeton d’accès Vercel dans les réglages de cette section.",
                         unauthorized: "Vercel n’a pas accepté le jeton. Ajoutez-en un nouveau dans les réglages de cette section.",
                         failed: "Impossible de joindre Vercel.",
                         retry: "Réessayer",
                         empty: "Aucun déploiement pour l’instant.",
                         production: "Production",
                         preview: "Aperçu",
                         queued: "En file",
                         initializing: "Initialisation",
                         building: "Construction",
                         ready: "Prêt",
                         error: "Erreur",
                         canceled: "Annulé")
        case .it:
            return .init(tokenTitle: "Token di accesso",
                         tokenPlaceholder: "Incolla un token di accesso Vercel",
                         tokenCaption: "Creane uno su vercel.com/account/tokens. Zenith lo usa solo per leggere i tuoi deployment recenti e lo conserva in un file privato su questo Mac.",
                         tokenSaved: "Salvato su questo Mac.",
                         tokenRejected: "Non sembra un token Vercel.",
                         save: "Salva",
                         remove: "Rimuovi",
                         liveActivity: "Mostra le build nell’isola chiusa",
                         liveActivityCaption: "Mentre un deployment viene compilato, l’isola chiusa lo segue, poi mostra per un attimo com’è finito.",
                         missingToken: "Aggiungi un token di accesso Vercel nelle impostazioni di questa sezione.",
                         unauthorized: "Vercel non ha accettato il token. Aggiungine uno nuovo nelle impostazioni di questa sezione.",
                         failed: "Impossibile raggiungere Vercel.",
                         retry: "Riprova",
                         empty: "Ancora nessun deployment.",
                         production: "Produzione",
                         preview: "Anteprima",
                         queued: "In coda",
                         initializing: "Avvio",
                         building: "In compilazione",
                         ready: "Pronto",
                         error: "Errore",
                         canceled: "Annullato")
        case .ja:
            return .init(tokenTitle: "アクセストークン",
                         tokenPlaceholder: "Vercelのアクセストークンを貼り付け",
                         tokenCaption: "vercel.com/account/tokensで作成してください。Zenithは最近のデプロイの読み取りにのみ使用し、このMac上の非公開ファイルに保存します。",
                         tokenSaved: "このMacに保存しました。",
                         tokenRejected: "Vercelのトークンではないようです。",
                         save: "保存",
                         remove: "削除",
                         liveActivity: "閉じた島にビルドを表示",
                         liveActivityCaption: "デプロイのビルド中は閉じた島が追跡し、終了後に結果を少しの間表示します。",
                         missingToken: "このセクションの設定でVercelのアクセストークンを追加してください。",
                         unauthorized: "Vercelがトークンを受け付けませんでした。このセクションの設定で新しいトークンを追加してください。",
                         failed: "Vercelに接続できませんでした。",
                         retry: "再試行",
                         empty: "まだデプロイはありません。",
                         production: "本番",
                         preview: "プレビュー",
                         queued: "待機中",
                         initializing: "初期化中",
                         building: "ビルド中",
                         ready: "完了",
                         error: "エラー",
                         canceled: "キャンセル")
        case .ko:
            return .init(tokenTitle: "액세스 토큰",
                         tokenPlaceholder: "Vercel 액세스 토큰 붙여넣기",
                         tokenCaption: "vercel.com/account/tokens에서 만드세요. Zenith는 최근 배포를 읽는 데만 사용하며 이 Mac의 비공개 파일에 보관합니다.",
                         tokenSaved: "이 Mac에 저장되었습니다.",
                         tokenRejected: "Vercel 토큰이 아닌 것 같습니다.",
                         save: "저장",
                         remove: "제거",
                         liveActivity: "닫힌 섬에 빌드 표시",
                         liveActivityCaption: "배포가 빌드되는 동안 닫힌 섬이 따라가고, 끝나면 결과를 잠시 보여줍니다.",
                         missingToken: "이 섹션의 설정에서 Vercel 액세스 토큰을 추가하세요.",
                         unauthorized: "Vercel이 토큰을 받아들이지 않았습니다. 이 섹션의 설정에서 새 토큰을 추가하세요.",
                         failed: "Vercel에 연결할 수 없습니다.",
                         retry: "다시 시도",
                         empty: "아직 배포가 없습니다.",
                         production: "프로덕션",
                         preview: "미리보기",
                         queued: "대기 중",
                         initializing: "초기화 중",
                         building: "빌드 중",
                         ready: "준비됨",
                         error: "오류",
                         canceled: "취소됨")
        case .uk:
            return .init(tokenTitle: "Токен доступу",
                         tokenPlaceholder: "Вставте токен доступу Vercel",
                         tokenCaption: "Створіть його на vercel.com/account/tokens. Zenith використовує його лише для читання останніх розгортань і зберігає в закритому файлі на цьому Mac.",
                         tokenSaved: "Збережено на цьому Mac.",
                         tokenRejected: "Це не схоже на токен Vercel.",
                         save: "Зберегти",
                         remove: "Видалити",
                         liveActivity: "Показувати збірки в закритому острівці",
                         liveActivityCaption: "Поки розгортання збирається, закритий острівець стежить за ним, а потім ненадовго показує результат.",
                         missingToken: "Додайте токен доступу Vercel у налаштуваннях цього розділу.",
                         unauthorized: "Vercel не прийняв токен. Додайте новий у налаштуваннях цього розділу.",
                         failed: "Не вдалося зв’язатися з Vercel.",
                         retry: "Повторити",
                         empty: "Розгортань поки немає.",
                         production: "Продакшн",
                         preview: "Прев’ю",
                         queued: "У черзі",
                         initializing: "Запуск",
                         building: "Збірка",
                         ready: "Готово",
                         error: "Помилка",
                         canceled: "Скасовано")
        case .zhHans:
            return .init(tokenTitle: "访问令牌",
                         tokenPlaceholder: "粘贴 Vercel 访问令牌",
                         tokenCaption: "在 vercel.com/account/tokens 创建一个。Zenith 仅用它读取你最近的部署，并将其保存在这台 Mac 上的私有文件中。",
                         tokenSaved: "已保存在这台 Mac 上。",
                         tokenRejected: "这看起来不像 Vercel 令牌。",
                         save: "保存",
                         remove: "移除",
                         liveActivity: "在收起的岛中显示构建",
                         liveActivityCaption: "部署构建时，收起的岛会跟踪它，结束后短暂显示结果。",
                         missingToken: "请在此部分的设置中添加 Vercel 访问令牌。",
                         unauthorized: "Vercel 未接受该令牌。请在此部分的设置中添加新令牌。",
                         failed: "无法连接 Vercel。",
                         retry: "重试",
                         empty: "还没有部署。",
                         production: "生产",
                         preview: "预览",
                         queued: "排队中",
                         initializing: "初始化中",
                         building: "构建中",
                         ready: "就绪",
                         error: "错误",
                         canceled: "已取消")
        case .zhTW:
            return .init(tokenTitle: "存取權杖",
                         tokenPlaceholder: "貼上 Vercel 存取權杖",
                         tokenCaption: "在 vercel.com/account/tokens 建立一個。Zenith 只用它讀取你最近的部署，並將它保存在這台 Mac 上的私人檔案中。",
                         tokenSaved: "已儲存在這台 Mac 上。",
                         tokenRejected: "這看起來不像 Vercel 權杖。",
                         save: "儲存",
                         remove: "移除",
                         liveActivity: "在收合的島中顯示建置",
                         liveActivityCaption: "部署建置時，收合的島會追蹤它，結束後短暫顯示結果。",
                         missingToken: "請在此區塊的設定中加入 Vercel 存取權杖。",
                         unauthorized: "Vercel 不接受此權杖。請在此區塊的設定中加入新的權杖。",
                         failed: "無法連線至 Vercel。",
                         retry: "再試一次",
                         empty: "尚無部署。",
                         production: "正式環境",
                         preview: "預覽",
                         queued: "排隊中",
                         initializing: "初始化中",
                         building: "建置中",
                         ready: "就緒",
                         error: "錯誤",
                         canceled: "已取消")
        case .zhHK:
            return .init(tokenTitle: "存取權杖",
                         tokenPlaceholder: "貼上 Vercel 存取權杖",
                         tokenCaption: "在 vercel.com/account/tokens 建立一個。Zenith 只用它讀取你最近的部署，並將它保存在這部 Mac 上的私人檔案中。",
                         tokenSaved: "已儲存在這部 Mac 上。",
                         tokenRejected: "這看起來不像 Vercel 權杖。",
                         save: "儲存",
                         remove: "移除",
                         liveActivity: "在收合的島中顯示建置",
                         liveActivityCaption: "部署建置時，收合的島會追蹤它，結束後短暫顯示結果。",
                         missingToken: "請在此區塊的設定中加入 Vercel 存取權杖。",
                         unauthorized: "Vercel 不接受此權杖。請在此區塊的設定中加入新的權杖。",
                         failed: "無法連線至 Vercel。",
                         retry: "再試一次",
                         empty: "尚未有部署。",
                         production: "正式環境",
                         preview: "預覽",
                         queued: "排隊中",
                         initializing: "初始化中",
                         building: "建置中",
                         ready: "就緒",
                         error: "錯誤",
                         canceled: "已取消")
        }
    }
}

extension ZenithStrings {
    /// The Vercel section’s line in the island’s content editor.
    static func vercelSummary(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Your latest deployments, and builds live in the closed island, from Vercel."
        case .ptBR: return "Suas implantações mais recentes e builds ao vivo na ilha fechada, da Vercel."
        case .tr: return "Vercel’den son dağıtımların ve kapalı adada canlı derlemeler."
        case .ru: return "Последние развёртывания и сборки в реальном времени в закрытом острове из Vercel."
        case .es: return "Tus despliegues más recientes y compilaciones en vivo en la isla cerrada, desde Vercel."
        case .sk: return "Vaše posledné nasadenia a zostavy naživo v zatvorenom Dynamic Island z Vercel."
        case .de: return "Deine letzten Deployments und laufende Builds in der geschlossenen Insel, von Vercel."
        case .fr: return "Vos derniers déploiements et les builds en direct dans l’île fermée, depuis Vercel."
        case .it: return "I tuoi deployment più recenti e le build dal vivo nell’isola chiusa, da Vercel."
        case .ja: return "Vercelの最新のデプロイと、閉じた島でのライブビルド。"
        case .ko: return "Vercel의 최근 배포와 닫힌 섬의 실시간 빌드입니다."
        case .uk: return "Останні розгортання та збірки наживо в закритому острівці з Vercel."
        case .zhHans: return "来自 Vercel 的最新部署，以及收起的岛中的实时构建。"
        case .zhTW: return "來自 Vercel 的最新部署，以及收合的島中的即時建置。"
        case .zhHK: return "來自 Vercel 的最新部署，以及收合的島中的即時建置。"
        }
    }
}

// MARK: GitHub (Zenith fork)

struct ZenithGitHubStrings {
    let reviewRequested: String
    let yourPullRequests: String
    let missingCLI: String
    let notSignedIn: String
    let failed: String
    let retry: String
    let nothingToReview: String
    let noneOpen: String
    let checksPassed: String
    let checksFailed: String
    let checksPending: String
    let noChecks: String
    let draft: String
    let cliFoundFormat: String
    let cliMissing: String
    let lookAgain: String
    let signedInFormat: String
    let caption: String

    func cliFound(_ path: String) -> String { String(format: cliFoundFormat, path) }
    func signedIn(_ login: String) -> String { String(format: signedInFormat, login) }

    func label(_ checks: GitHubSupport.Checks) -> String {
        switch checks {
        case .success: return checksPassed
        case .failure: return checksFailed
        case .pending: return checksPending
        case .none: return noChecks
        }
    }
}

extension ZenithStrings {
    static func gitHub(_ language: AppLanguage) -> ZenithGitHubStrings {
        switch language {
        case .enUS:
            return .init(reviewRequested: "Review requested",
                         yourPullRequests: "Your pull requests",
                         missingCLI: "Install the GitHub CLI (gh) to see your pull requests.",
                         notSignedIn: "Run gh auth login in Terminal, then try again.",
                         failed: "Couldn’t reach GitHub.",
                         retry: "Try again",
                         nothingToReview: "Nothing waiting for your review.",
                         noneOpen: "You have no open pull requests.",
                         checksPassed: "Checks passed",
                         checksFailed: "Checks failed",
                         checksPending: "Checks running",
                         noChecks: "No checks",
                         draft: "Draft",
                         cliFoundFormat: "Using %@",
                         cliMissing: "GitHub CLI not found.",
                         lookAgain: "Look again",
                         signedInFormat: "Signed in as %@",
                         caption: "Zenith asks the GitHub CLI you already use, so it needs no token of its own. It refreshes every 5 minutes while this section is on.")
        case .ptBR:
            return .init(reviewRequested: "Revisão solicitada",
                         yourPullRequests: "Seus pull requests",
                         missingCLI: "Instale o GitHub CLI (gh) para ver seus pull requests.",
                         notSignedIn: "Execute gh auth login no Terminal e tente novamente.",
                         failed: "Não foi possível acessar o GitHub.",
                         retry: "Tentar novamente",
                         nothingToReview: "Nada aguardando sua revisão.",
                         noneOpen: "Você não tem pull requests abertos.",
                         checksPassed: "Verificações aprovadas",
                         checksFailed: "Verificações falharam",
                         checksPending: "Verificações em andamento",
                         noChecks: "Sem verificações",
                         draft: "Rascunho",
                         cliFoundFormat: "Usando %@",
                         cliMissing: "GitHub CLI não encontrado.",
                         lookAgain: "Procurar de novo",
                         signedInFormat: "Conectado como %@",
                         caption: "O Zenith consulta o GitHub CLI que você já usa, então não precisa de um token próprio. Ele atualiza a cada 5 minutos enquanto esta seção está ativa.")
        case .tr:
            return .init(reviewRequested: "İnceleme istendi",
                         yourPullRequests: "Pull request’lerin",
                         missingCLI: "Pull request’lerini görmek için GitHub CLI’ı (gh) yükle.",
                         notSignedIn: "Terminal’de gh auth login komutunu çalıştır, sonra tekrar dene.",
                         failed: "GitHub’a ulaşılamadı.",
                         retry: "Tekrar dene",
                         nothingToReview: "İncelemeni bekleyen bir şey yok.",
                         noneOpen: "Açık pull request’in yok.",
                         checksPassed: "Denetimler geçti",
                         checksFailed: "Denetimler başarısız",
                         checksPending: "Denetimler sürüyor",
                         noChecks: "Denetim yok",
                         draft: "Taslak",
                         cliFoundFormat: "Kullanılan: %@",
                         cliMissing: "GitHub CLI bulunamadı.",
                         lookAgain: "Yeniden ara",
                         signedInFormat: "%@ olarak oturum açıldı",
                         caption: "Zenith zaten kullandığın GitHub CLI’a sorar, bu yüzden kendi belirtecine ihtiyaç duymaz. Bu bölüm açıkken 5 dakikada bir yenilenir.")
        case .ru:
            return .init(reviewRequested: "Запрошен обзор",
                         yourPullRequests: "Ваши pull requests",
                         missingCLI: "Установите GitHub CLI (gh), чтобы видеть свои pull requests.",
                         notSignedIn: "Выполните gh auth login в Терминале и повторите попытку.",
                         failed: "Не удалось связаться с GitHub.",
                         retry: "Повторить",
                         nothingToReview: "Ничего не ждёт вашего обзора.",
                         noneOpen: "У вас нет открытых pull requests.",
                         checksPassed: "Проверки пройдены",
                         checksFailed: "Проверки не пройдены",
                         checksPending: "Проверки выполняются",
                         noChecks: "Нет проверок",
                         draft: "Черновик",
                         cliFoundFormat: "Используется %@",
                         cliMissing: "GitHub CLI не найден.",
                         lookAgain: "Искать снова",
                         signedInFormat: "Вход выполнен как %@",
                         caption: "Zenith обращается к GitHub CLI, которым вы уже пользуетесь, поэтому собственный токен не нужен. Обновляется каждые 5 минут, пока раздел включён.")
        case .es:
            return .init(reviewRequested: "Revisión solicitada",
                         yourPullRequests: "Tus pull requests",
                         missingCLI: "Instala GitHub CLI (gh) para ver tus pull requests.",
                         notSignedIn: "Ejecuta gh auth login en Terminal y vuelve a intentarlo.",
                         failed: "No se pudo conectar con GitHub.",
                         retry: "Reintentar",
                         nothingToReview: "Nada espera tu revisión.",
                         noneOpen: "No tienes pull requests abiertos.",
                         checksPassed: "Comprobaciones superadas",
                         checksFailed: "Comprobaciones fallidas",
                         checksPending: "Comprobaciones en curso",
                         noChecks: "Sin comprobaciones",
                         draft: "Borrador",
                         cliFoundFormat: "Usando %@",
                         cliMissing: "No se encontró GitHub CLI.",
                         lookAgain: "Buscar de nuevo",
                         signedInFormat: "Sesión iniciada como %@",
                         caption: "Zenith consulta el GitHub CLI que ya usas, así que no necesita un token propio. Se actualiza cada 5 minutos mientras esta sección está activada.")
        case .sk:
            return .init(reviewRequested: "Vyžiadaná kontrola",
                         yourPullRequests: "Vaše pull requesty",
                         missingCLI: "Nainštalujte GitHub CLI (gh), aby ste videli svoje pull requesty.",
                         notSignedIn: "Spustite gh auth login v Termináli a skúste znova.",
                         failed: "Nepodarilo sa spojiť s GitHubom.",
                         retry: "Skúsiť znova",
                         nothingToReview: "Nič nečaká na vašu kontrolu.",
                         noneOpen: "Nemáte žiadne otvorené pull requesty.",
                         checksPassed: "Kontroly prešli",
                         checksFailed: "Kontroly zlyhali",
                         checksPending: "Kontroly prebiehajú",
                         noChecks: "Bez kontrol",
                         draft: "Koncept",
                         cliFoundFormat: "Používa sa %@",
                         cliMissing: "GitHub CLI sa nenašlo.",
                         lookAgain: "Hľadať znova",
                         signedInFormat: "Prihlásený ako %@",
                         caption: "Zenith sa pýta GitHub CLI, ktoré už používate, takže nepotrebuje vlastný token. Obnovuje sa každých 5 minút, kým je táto sekcia zapnutá.")
        case .de:
            return .init(reviewRequested: "Review angefragt",
                         yourPullRequests: "Deine Pull Requests",
                         missingCLI: "Installiere die GitHub CLI (gh), um deine Pull Requests zu sehen.",
                         notSignedIn: "Führe gh auth login im Terminal aus und versuche es dann erneut.",
                         failed: "GitHub ist nicht erreichbar.",
                         retry: "Erneut versuchen",
                         nothingToReview: "Nichts wartet auf dein Review.",
                         noneOpen: "Du hast keine offenen Pull Requests.",
                         checksPassed: "Checks bestanden",
                         checksFailed: "Checks fehlgeschlagen",
                         checksPending: "Checks laufen",
                         noChecks: "Keine Checks",
                         draft: "Entwurf",
                         cliFoundFormat: "Verwendet %@",
                         cliMissing: "GitHub CLI nicht gefunden.",
                         lookAgain: "Erneut suchen",
                         signedInFormat: "Angemeldet als %@",
                         caption: "Zenith fragt die GitHub CLI, die du bereits nutzt, und braucht daher kein eigenes Token. Solange dieser Bereich aktiv ist, wird alle 5 Minuten aktualisiert.")
        case .fr:
            return .init(reviewRequested: "Revue demandée",
                         yourPullRequests: "Vos pull requests",
                         missingCLI: "Installez GitHub CLI (gh) pour voir vos pull requests.",
                         notSignedIn: "Exécutez gh auth login dans Terminal, puis réessayez.",
                         failed: "Impossible de joindre GitHub.",
                         retry: "Réessayer",
                         nothingToReview: "Rien n’attend votre revue.",
                         noneOpen: "Vous n’avez aucune pull request ouverte.",
                         checksPassed: "Vérifications réussies",
                         checksFailed: "Vérifications échouées",
                         checksPending: "Vérifications en cours",
                         noChecks: "Aucune vérification",
                         draft: "Brouillon",
                         cliFoundFormat: "Utilise %@",
                         cliMissing: "GitHub CLI introuvable.",
                         lookAgain: "Chercher à nouveau",
                         signedInFormat: "Connecté en tant que %@",
                         caption: "Zenith interroge le GitHub CLI que vous utilisez déjà, il n’a donc pas besoin de son propre jeton. Il se met à jour toutes les 5 minutes tant que cette section est activée.")
        case .it:
            return .init(reviewRequested: "Revisione richiesta",
                         yourPullRequests: "Le tue pull request",
                         missingCLI: "Installa GitHub CLI (gh) per vedere le tue pull request.",
                         notSignedIn: "Esegui gh auth login nel Terminale, poi riprova.",
                         failed: "Impossibile raggiungere GitHub.",
                         retry: "Riprova",
                         nothingToReview: "Niente attende la tua revisione.",
                         noneOpen: "Non hai pull request aperte.",
                         checksPassed: "Controlli superati",
                         checksFailed: "Controlli non riusciti",
                         checksPending: "Controlli in corso",
                         noChecks: "Nessun controllo",
                         draft: "Bozza",
                         cliFoundFormat: "In uso: %@",
                         cliMissing: "GitHub CLI non trovato.",
                         lookAgain: "Cerca di nuovo",
                         signedInFormat: "Accesso come %@",
                         caption: "Zenith interroga il GitHub CLI che usi già, quindi non ha bisogno di un token proprio. Si aggiorna ogni 5 minuti mentre questa sezione è attiva.")
        case .ja:
            return .init(reviewRequested: "レビュー依頼",
                         yourPullRequests: "自分のプルリクエスト",
                         missingCLI: "プルリクエストを表示するにはGitHub CLI（gh）をインストールしてください。",
                         notSignedIn: "ターミナルでgh auth loginを実行してから、もう一度お試しください。",
                         failed: "GitHubに接続できませんでした。",
                         retry: "再試行",
                         nothingToReview: "レビュー待ちはありません。",
                         noneOpen: "オープン中のプルリクエストはありません。",
                         checksPassed: "チェック成功",
                         checksFailed: "チェック失敗",
                         checksPending: "チェック実行中",
                         noChecks: "チェックなし",
                         draft: "ドラフト",
                         cliFoundFormat: "使用中: %@",
                         cliMissing: "GitHub CLIが見つかりません。",
                         lookAgain: "もう一度探す",
                         signedInFormat: "%@ としてサインイン中",
                         caption: "Zenithは既に使っているGitHub CLIに問い合わせるため、専用のトークンは不要です。このセクションがオンの間、5分ごとに更新します。")
        case .ko:
            return .init(reviewRequested: "리뷰 요청됨",
                         yourPullRequests: "내 풀 리퀘스트",
                         missingCLI: "풀 리퀘스트를 보려면 GitHub CLI(gh)를 설치하세요.",
                         notSignedIn: "터미널에서 gh auth login을 실행한 다음 다시 시도하세요.",
                         failed: "GitHub에 연결할 수 없습니다.",
                         retry: "다시 시도",
                         nothingToReview: "리뷰를 기다리는 항목이 없습니다.",
                         noneOpen: "열린 풀 리퀘스트가 없습니다.",
                         checksPassed: "검사 통과",
                         checksFailed: "검사 실패",
                         checksPending: "검사 진행 중",
                         noChecks: "검사 없음",
                         draft: "초안",
                         cliFoundFormat: "사용 중: %@",
                         cliMissing: "GitHub CLI를 찾을 수 없습니다.",
                         lookAgain: "다시 찾기",
                         signedInFormat: "%@(으)로 로그인됨",
                         caption: "Zenith는 이미 사용 중인 GitHub CLI에 묻기 때문에 별도의 토큰이 필요 없습니다. 이 섹션이 켜져 있는 동안 5분마다 새로 고칩니다.")
        case .uk:
            return .init(reviewRequested: "Запит на рев’ю",
                         yourPullRequests: "Ваші pull requests",
                         missingCLI: "Установіть GitHub CLI (gh), щоб бачити свої pull requests.",
                         notSignedIn: "Виконайте gh auth login у Терміналі й спробуйте ще раз.",
                         failed: "Не вдалося зв’язатися з GitHub.",
                         retry: "Повторити",
                         nothingToReview: "Ніщо не чекає на ваше рев’ю.",
                         noneOpen: "У вас немає відкритих pull requests.",
                         checksPassed: "Перевірки пройдено",
                         checksFailed: "Перевірки не пройдено",
                         checksPending: "Перевірки тривають",
                         noChecks: "Без перевірок",
                         draft: "Чернетка",
                         cliFoundFormat: "Використовується %@",
                         cliMissing: "GitHub CLI не знайдено.",
                         lookAgain: "Шукати знову",
                         signedInFormat: "Вхід як %@",
                         caption: "Zenith звертається до GitHub CLI, яким ви вже користуєтеся, тож власний токен не потрібен. Оновлюється кожні 5 хвилин, поки розділ увімкнено.")
        case .zhHans:
            return .init(reviewRequested: "请求审查",
                         yourPullRequests: "你的拉取请求",
                         missingCLI: "安装 GitHub CLI（gh）以查看你的拉取请求。",
                         notSignedIn: "在终端中运行 gh auth login，然后重试。",
                         failed: "无法连接 GitHub。",
                         retry: "重试",
                         nothingToReview: "没有等待你审查的内容。",
                         noneOpen: "你没有打开的拉取请求。",
                         checksPassed: "检查通过",
                         checksFailed: "检查失败",
                         checksPending: "检查进行中",
                         noChecks: "无检查",
                         draft: "草稿",
                         cliFoundFormat: "正在使用 %@",
                         cliMissing: "未找到 GitHub CLI。",
                         lookAgain: "重新查找",
                         signedInFormat: "已登录为 %@",
                         caption: "Zenith 会询问你已在使用的 GitHub CLI，因此不需要单独的令牌。此部分开启时每 5 分钟刷新一次。")
        case .zhTW:
            return .init(reviewRequested: "已要求審查",
                         yourPullRequests: "你的提取要求",
                         missingCLI: "安裝 GitHub CLI（gh）以查看你的提取要求。",
                         notSignedIn: "在終端機中執行 gh auth login，然後再試一次。",
                         failed: "無法連線至 GitHub。",
                         retry: "再試一次",
                         nothingToReview: "沒有等待你審查的項目。",
                         noneOpen: "你沒有開啟中的提取要求。",
                         checksPassed: "檢查通過",
                         checksFailed: "檢查失敗",
                         checksPending: "檢查進行中",
                         noChecks: "沒有檢查",
                         draft: "草稿",
                         cliFoundFormat: "正在使用 %@",
                         cliMissing: "找不到 GitHub CLI。",
                         lookAgain: "重新尋找",
                         signedInFormat: "已登入為 %@",
                         caption: "Zenith 會詢問你已在使用的 GitHub CLI，因此不需要另外的權杖。此區塊開啟時每 5 分鐘重新整理一次。")
        case .zhHK:
            return .init(reviewRequested: "已要求審查",
                         yourPullRequests: "你的拉取請求",
                         missingCLI: "安裝 GitHub CLI（gh）以查看你的拉取請求。",
                         notSignedIn: "在終端機中執行 gh auth login，然後再試一次。",
                         failed: "無法連線至 GitHub。",
                         retry: "再試一次",
                         nothingToReview: "沒有等待你審查的項目。",
                         noneOpen: "你沒有開啟中的拉取請求。",
                         checksPassed: "檢查通過",
                         checksFailed: "檢查失敗",
                         checksPending: "檢查進行中",
                         noChecks: "沒有檢查",
                         draft: "草稿",
                         cliFoundFormat: "正在使用 %@",
                         cliMissing: "找不到 GitHub CLI。",
                         lookAgain: "重新尋找",
                         signedInFormat: "已登入為 %@",
                         caption: "Zenith 會詢問你已在使用的 GitHub CLI，因此不需要另外的權杖。此區塊開啟時每 5 分鐘重新載入一次。")
        }
    }
}

extension ZenithStrings {
    /// The GitHub section’s line in the island’s content editor.
    static func gitHubSummary(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "Pull requests waiting for your review, and yours with their checks, from GitHub."
        case .ptBR: return "Pull requests aguardando sua revisão e os seus com as verificações, do GitHub."
        case .tr: return "GitHub’dan incelemeni bekleyen pull request’ler ve denetimleriyle birlikte seninkiler."
        case .ru: return "Pull requests, ждущие вашего обзора, и ваши собственные с проверками из GitHub."
        case .es: return "Pull requests que esperan tu revisión y los tuyos con sus comprobaciones, desde GitHub."
        case .sk: return "Pull requesty čakajúce na vašu kontrolu a vaše vlastné s kontrolami z GitHubu."
        case .de: return "Pull Requests, die auf dein Review warten, und deine eigenen mit ihren Checks, von GitHub."
        case .fr: return "Les pull requests qui attendent votre revue, et les vôtres avec leurs vérifications, depuis GitHub."
        case .it: return "Le pull request in attesa della tua revisione e le tue con i relativi controlli, da GitHub."
        case .ja: return "GitHubから、レビュー待ちのプルリクエストと、チェック状況付きの自分のプルリクエスト。"
        case .ko: return "GitHub에서 리뷰를 기다리는 풀 리퀘스트와 검사 상태가 포함된 내 풀 리퀘스트입니다."
        case .uk: return "Pull requests, що чекають на ваше рев’ю, і ваші власні з перевірками з GitHub."
        case .zhHans: return "来自 GitHub 的等待你审查的拉取请求，以及附带检查状态的你的拉取请求。"
        case .zhTW: return "來自 GitHub 等待你審查的提取要求，以及附有檢查狀態的你的提取要求。"
        case .zhHK: return "來自 GitHub 等待你審查的拉取請求，以及附有檢查狀態的你的拉取請求。"
        }
    }
}

// MARK: About (Zenith fork)

/// One tile of the About page’s Features bento.
struct ZenithAboutAreaStrings {
    let title: String
    let caption: String
    /// Short names of what is inside, shown as mono chips.
    let chips: [String]

    init(_ title: String, _ caption: String, _ chips: [String]) {
        self.title = title
        self.caption = caption
        self.chips = chips
    }
}

struct ZenithAboutStrings {
    /// Under the headline, which itself stays English (`ZenithAbout`).
    let subtitle: String
    /// Labels under the three figures.
    let featureCount: String
    let languageCount: String
    let accountCount: String
    let featuresTitle: String
    let featuresCaption: String
    /// The bento’s tiles, one for every `ZenithFeatureArea.ID`.
    let areas: [ZenithFeatureArea.ID: ZenithAboutAreaStrings]
    /// The maker’s card.
    let madeBy: String
    let role: String
    let bio: String
    /// The status chip beside the maker’s name.
    let status: String
    let studioCaption: String
    let website: String

    func area(_ id: ZenithFeatureArea.ID) -> ZenithAboutAreaStrings {
        areas[id] ?? ZenithAboutAreaStrings("", "", [])
    }
}

extension ZenithStrings {
    /// The About page: Zenith and its features first, then a little about
    /// who makes it. The headline stays English in every language
    /// (`ZenithAbout`); everything else is here.
    static func about(_ language: AppLanguage) -> ZenithAboutStrings {
        switch language {
        case .enUS:
            return .init(subtitle: "A utility hub for your Mac: the notch, the menu bar and every tool in between.",
                         featureCount: "features",
                         languageCount: "languages",
                         accountCount: "accounts, no tracking",
                         featuresTitle: "Features",
                         featuresCaption: "Open a tile to set it up. Anything you don’t use can be switched off entirely.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "The notch becomes a live hub for music, timers, your calendar and whatever is running.",
                                            ["Now Playing", "Live activities", "Lock Screen", "Calendar", "Timer"]),
                             .agents: .init("AI agents",
                                            "Claude and Codex at a glance: usage, limits and the sessions running now.",
                                            ["Claude", "Codex", "Limits", "Live sessions"]),
                             .developers: .init("For developers",
                                            "Deploys, pull requests, coding time and long terminal commands, right by the camera.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminal", "Command Bar"]),
                             .files: .init("Files & photos",
                                            "A shelf for what you drag, AirDrop from the notch and quick photo fixes.",
                                            ["Shelf", "AirDrop", "Convert", "Remove background", "Clipboard"]),
                             .capture: .init("Capture",
                                            "Screenshots, scrolling captures, recordings and text from anything on screen.",
                                            ["Screenshot", "Scrolling", "Recording", "Text (OCR)", "Color picker"]),
                             .system: .init("System",
                                            "CPU, memory, network, battery and fans in the menu bar, and a Mac that stays awake when you need it.",
                                            ["CPU", "Memory", "Network", "Battery", "Fans", "Keep awake"]),
                             .windows: .init("Windows & Dock",
                                            "Switch, snap and preview windows, and quit apps when their last window closes.",
                                            ["Switcher", "Layouts", "Dock previews", "Quit on close"]),
                             .input: .init("Mouse & keyboard",
                                            "Smooth scrolling, button shortcuts and snippets that type themselves.",
                                            ["Smooth scrolling", "Mouse buttons", "Snippets", "Super key"]),
                             .sound: .init("Sound",
                                            "A volume for every app, a quick output switch and a mic you can mute from anywhere.",
                                            ["Mixer", "Output", "Mic mute"]),
                             .utilities: .init("Utilities",
                                            "A quick panel, a scratchpad and the tools that keep your Mac tidy.",
                                            ["Quick panel", "Scratchpad", "Cleaner", "Uninstaller", "Homebrew"]),
                         ],
                         madeBy: "Made by",
                         role: "Fullstack developer & designer",
                         bio: "I’m a fullstack developer and designer, an informatics engineer who codes, designs and shoots. I build web apps end to end, craft modern UI/UX and graphics, and produce video and photography. Living across engineering and design lets me take an idea from concept to a real, shipped product, Zenith included.",
                         status: "Building Zenith",
                         studioCaption: "Creative studio from Sumatra, Indonesia. Photography, film, web and Mac apps.",
                         website: "Website")
        case .ptBR:
            return .init(subtitle: "Uma central de utilitários para o seu Mac: o notch, a barra de menus e cada ferramenta entre eles.",
                         featureCount: "recursos",
                         languageCount: "idiomas",
                         accountCount: "contas, nenhum rastreamento",
                         featuresTitle: "Recursos",
                         featuresCaption: "Abra um bloco para configurá-lo. O que você não usa pode ser desligado por completo.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "O notch vira uma central ao vivo para música, timers, sua agenda e o que estiver rodando.",
                                            ["Tocando agora", "Atividades ao vivo", "Tela de bloqueio", "Calendário", "Timer"]),
                             .agents: .init("Agentes de IA",
                                            "Claude e Codex num relance: uso, limites e as sessões em andamento.",
                                            ["Claude", "Codex", "Limites", "Sessões ao vivo"]),
                             .developers: .init("Para desenvolvedores",
                                            "Deploys, pull requests, tempo de código e comandos longos do terminal, ao lado da câmera.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminal", "Barra de comando"]),
                             .files: .init("Arquivos e fotos",
                                            "Uma área para o que você arrasta, AirDrop pelo notch e ajustes rápidos de fotos.",
                                            ["Área temporária", "AirDrop", "Converter", "Remover fundo", "Área de transferência"]),
                             .capture: .init("Captura",
                                            "Capturas de tela, capturas com rolagem, gravações e texto de qualquer coisa na tela.",
                                            ["Captura de tela", "Rolagem", "Gravação", "Texto (OCR)", "Conta-gotas"]),
                             .system: .init("Sistema",
                                            "CPU, memória, rede, bateria e ventoinhas na barra de menus, e um Mac que fica acordado quando você precisa.",
                                            ["CPU", "Memória", "Rede", "Bateria", "Ventoinhas", "Manter acordado"]),
                             .windows: .init("Janelas e Dock",
                                            "Alterne, encaixe e veja prévias de janelas, e encerre apps quando a última janela fecha.",
                                            ["Alternador", "Layouts", "Prévias do Dock", "Encerrar ao fechar"]),
                             .input: .init("Mouse e teclado",
                                            "Rolagem suave, atalhos nos botões e trechos de texto que se digitam sozinhos.",
                                            ["Rolagem suave", "Botões do mouse", "Trechos", "Super tecla"]),
                             .sound: .init("Som",
                                            "Um volume para cada app, troca rápida de saída e um microfone que você silencia de qualquer lugar.",
                                            ["Mixer", "Saída", "Silenciar microfone"]),
                             .utilities: .init("Utilitários",
                                            "Um painel rápido, um bloco de notas e as ferramentas que mantêm seu Mac em ordem.",
                                            ["Painel rápido", "Bloco de notas", "Limpeza", "Desinstalador", "Homebrew"]),
                         ],
                         madeBy: "Feito por",
                         role: "Desenvolvedor fullstack e designer",
                         bio: "Sou desenvolvedor fullstack e designer, um engenheiro de informática que programa, desenha e fotografa. Crio aplicações web de ponta a ponta, faço UI/UX e gráficos modernos, e produzo vídeo e fotografia. Viver entre engenharia e design me permite levar uma ideia do conceito a um produto real e lançado, inclusive o Zenith.",
                         status: "Construindo o Zenith",
                         studioCaption: "Estúdio criativo de Sumatra, Indonésia. Fotografia, filme, web e apps para Mac.",
                         website: "Site")
        case .tr:
            return .init(subtitle: "Mac’in için bir yardımcı merkez: çentik, menü çubuğu ve aradaki her araç.",
                         featureCount: "özellik",
                         languageCount: "dil",
                         accountCount: "hesap, takip yok",
                         featuresTitle: "Özellikler",
                         featuresCaption: "Ayarlamak için bir kutuyu aç. Kullanmadığın her şey tamamen kapatılabilir.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "Çentik müzik, zamanlayıcılar, takvimin ve çalışan her şey için canlı bir merkeze dönüşür.",
                                            ["Şimdi çalıyor", "Canlı etkinlikler", "Kilit ekranı", "Takvim", "Zamanlayıcı"]),
                             .agents: .init("Yapay zekâ ajanları",
                                            "Claude ve Codex bir bakışta: kullanım, limitler ve şu an çalışan oturumlar.",
                                            ["Claude", "Codex", "Limitler", "Canlı oturumlar"]),
                             .developers: .init("Geliştiriciler için",
                                            "Dağıtımlar, pull request’ler, kodlama süresi ve uzun terminal komutları, kameranın hemen yanında.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminal", "Komut çubuğu"]),
                             .files: .init("Dosyalar ve fotoğraflar",
                                            "Sürüklediklerin için bir raf, çentikten AirDrop ve hızlı fotoğraf düzenlemeleri.",
                                            ["Raf", "AirDrop", "Dönüştür", "Arka planı kaldır", "Pano"]),
                             .capture: .init("Yakalama",
                                            "Ekran görüntüleri, kaydırmalı yakalamalar, kayıtlar ve ekrandaki her şeyden metin.",
                                            ["Ekran görüntüsü", "Kaydırma", "Kayıt", "Metin (OCR)", "Renk damlalığı"]),
                             .system: .init("Sistem",
                                            "Menü çubuğunda CPU, bellek, ağ, pil ve fanlar; gerektiğinde uyanık kalan bir Mac.",
                                            ["CPU", "Bellek", "Ağ", "Pil", "Fanlar", "Uyanık tut"]),
                             .windows: .init("Pencereler ve Dock",
                                            "Pencereleri değiştir, yerleştir ve önizle; son penceresi kapanan uygulamalardan çık.",
                                            ["Değiştirici", "Yerleşimler", "Dock önizlemeleri", "Kapatınca çık"]),
                             .input: .init("Fare ve klavye",
                                            "Akıcı kaydırma, düğme kısayolları ve kendi kendini yazan metin parçacıkları.",
                                            ["Akıcı kaydırma", "Fare düğmeleri", "Parçacıklar", "Süper tuş"]),
                             .sound: .init("Ses",
                                            "Her uygulama için ayrı ses düzeyi, hızlı çıkış değişimi ve her yerden sessize alınan bir mikrofon.",
                                            ["Mikser", "Çıkış", "Mikrofonu sessize al"]),
                             .utilities: .init("Araçlar",
                                            "Hızlı panel, karalama defteri ve Mac’ini derli toplu tutan araçlar.",
                                            ["Hızlı panel", "Karalama defteri", "Temizlik", "Kaldırıcı", "Homebrew"]),
                         ],
                         madeBy: "Yapımcı",
                         role: "Fullstack geliştirici ve tasarımcı",
                         bio: "Fullstack geliştirici ve tasarımcıyım; kod yazan, tasarlayan ve fotoğraf çeken bir bilişim mühendisi. Web uygulamalarını uçtan uca geliştiriyor, modern UI/UX ve grafikler tasarlıyor, video ve fotoğraf üretiyorum. Mühendislik ile tasarım arasında yaşamak, bir fikri kavramdan gerçek, yayınlanmış bir ürüne taşımamı sağlıyor; Zenith de bunlardan biri.",
                         status: "Zenith’i geliştiriyor",
                         studioCaption: "Sumatra, Endonezya’dan bir yaratıcı stüdyo. Fotoğraf, film, web ve Mac uygulamaları.",
                         website: "Web sitesi")
        case .ru:
            return .init(subtitle: "Набор инструментов для вашего Mac: вырез, строка меню и всё, что между ними.",
                         featureCount: "функции",
                         languageCount: "языков",
                         accountCount: "аккаунтов, без слежки",
                         featuresTitle: "Функции",
                         featuresCaption: "Откройте плитку, чтобы настроить раздел. Всё, чем вы не пользуетесь, можно полностью отключить.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "Вырез превращается в живой центр для музыки, таймеров, календаря и всего, что сейчас работает.",
                                            ["Сейчас играет", "Живые активности", "Экран блокировки", "Календарь", "Таймер"]),
                             .agents: .init("ИИ-агенты",
                                            "Claude и Codex с первого взгляда: расход, лимиты и активные сеансы.",
                                            ["Claude", "Codex", "Лимиты", "Активные сеансы"]),
                             .developers: .init("Для разработчиков",
                                            "Деплои, pull requests, время в коде и долгие команды терминала прямо у камеры.",
                                            ["Vercel", "GitHub", "WakaTime", "Терминал", "Командная панель"]),
                             .files: .init("Файлы и фото",
                                            "Полка для всего, что вы перетаскиваете, AirDrop из выреза и быстрая обработка фото.",
                                            ["Полка", "AirDrop", "Конвертация", "Удаление фона", "Буфер обмена"]),
                             .capture: .init("Захват",
                                            "Снимки экрана, снимки с прокруткой, записи и текст с чего угодно на экране.",
                                            ["Снимок экрана", "Прокрутка", "Запись", "Текст (OCR)", "Пипетка"]),
                             .system: .init("Система",
                                            "ЦП, память, сеть, аккумулятор и вентиляторы в строке меню, а Mac не засыпает, когда это нужно.",
                                            ["ЦП", "Память", "Сеть", "Аккумулятор", "Вентиляторы", "Без сна"]),
                             .windows: .init("Окна и Dock",
                                            "Переключайте, раскладывайте и просматривайте окна, а приложения закрываются вместе с последним окном.",
                                            ["Переключатель", "Раскладки", "Превью в Dock", "Закрытие с окном"]),
                             .input: .init("Мышь и клавиатура",
                                            "Плавная прокрутка, сочетания на кнопках и фрагменты текста, которые печатаются сами.",
                                            ["Плавная прокрутка", "Кнопки мыши", "Фрагменты", "Суперклавиша"]),
                             .sound: .init("Звук",
                                            "Громкость для каждого приложения, быстрая смена выхода и микрофон, который выключается откуда угодно.",
                                            ["Микшер", "Выход", "Выключить микрофон"]),
                             .utilities: .init("Утилиты",
                                            "Быстрая панель, блокнот и инструменты, которые поддерживают порядок в Mac.",
                                            ["Быстрая панель", "Блокнот", "Очистка", "Деинсталлятор", "Homebrew"]),
                         ],
                         madeBy: "Автор",
                         role: "Fullstack-разработчик и дизайнер",
                         bio: "Я fullstack-разработчик и дизайнер, инженер-информатик, который пишет код, проектирует и снимает. Делаю веб-приложения от начала до конца, создаю современный UI/UX и графику, снимаю видео и фото. Работа на стыке инженерии и дизайна позволяет мне довести идею от концепции до настоящего выпущенного продукта, включая Zenith.",
                         status: "Делает Zenith",
                         studioCaption: "Креативная студия с Суматры, Индонезия. Фото, видео, веб и приложения для Mac.",
                         website: "Сайт")
        case .es:
            return .init(subtitle: "Un centro de utilidades para tu Mac: el notch, la barra de menús y cada herramienta entre medias.",
                         featureCount: "funciones",
                         languageCount: "idiomas",
                         accountCount: "cuentas, sin rastreo",
                         featuresTitle: "Funciones",
                         featuresCaption: "Abre un bloque para configurarlo. Lo que no uses se puede desactivar por completo.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "El notch se convierte en un centro en vivo para la música, los temporizadores, tu calendario y todo lo que esté en marcha.",
                                            ["Ahora suena", "Actividades en vivo", "Pantalla bloqueada", "Calendario", "Temporizador"]),
                             .agents: .init("Agentes de IA",
                                            "Claude y Codex de un vistazo: uso, límites y las sesiones en curso.",
                                            ["Claude", "Codex", "Límites", "Sesiones en vivo"]),
                             .developers: .init("Para desarrolladores",
                                            "Despliegues, pull requests, tiempo programando y comandos largos de terminal, junto a la cámara.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminal", "Barra de comandos"]),
                             .files: .init("Archivos y fotos",
                                            "Un estante para lo que arrastras, AirDrop desde el notch y retoques rápidos de fotos.",
                                            ["Estante", "AirDrop", "Convertir", "Quitar fondo", "Portapapeles"]),
                             .capture: .init("Captura",
                                            "Capturas de pantalla, capturas con desplazamiento, grabaciones y texto de cualquier cosa en pantalla.",
                                            ["Captura de pantalla", "Desplazamiento", "Grabación", "Texto (OCR)", "Cuentagotas"]),
                             .system: .init("Sistema",
                                            "CPU, memoria, red, batería y ventiladores en la barra de menús, y un Mac que se mantiene activo cuando lo necesitas.",
                                            ["CPU", "Memoria", "Red", "Batería", "Ventiladores", "Mantener activo"]),
                             .windows: .init("Ventanas y Dock",
                                            "Cambia, coloca y previsualiza ventanas, y cierra apps cuando se cierra su última ventana.",
                                            ["Selector", "Distribuciones", "Vistas del Dock", "Salir al cerrar"]),
                             .input: .init("Ratón y teclado",
                                            "Desplazamiento suave, atajos en los botones y fragmentos de texto que se escriben solos.",
                                            ["Desplazamiento suave", "Botones del ratón", "Fragmentos", "Supertecla"]),
                             .sound: .init("Sonido",
                                            "Un volumen para cada app, un cambio rápido de salida y un micrófono que silencias desde cualquier sitio.",
                                            ["Mezclador", "Salida", "Silenciar micrófono"]),
                             .utilities: .init("Utilidades",
                                            "Un panel rápido, un bloc de notas y las herramientas que mantienen tu Mac en orden.",
                                            ["Panel rápido", "Bloc de notas", "Limpieza", "Desinstalador", "Homebrew"]),
                         ],
                         madeBy: "Hecho por",
                         role: "Desarrollador fullstack y diseñador",
                         bio: "Soy desarrollador fullstack y diseñador, un ingeniero informático que programa, diseña y fotografía. Creo aplicaciones web de principio a fin, diseño UI/UX y gráficos modernos, y produzco vídeo y fotografía. Moverme entre la ingeniería y el diseño me permite llevar una idea del concepto a un producto real y publicado, Zenith incluido.",
                         status: "Creando Zenith",
                         studioCaption: "Estudio creativo de Sumatra, Indonesia. Fotografía, cine, web y apps para Mac.",
                         website: "Sitio web")
        case .sk:
            return .init(subtitle: "Centrum nástrojov pre váš Mac: výrez, lišta s ponukami a každý nástroj medzi nimi.",
                         featureCount: "funkcií",
                         languageCount: "jazykov",
                         accountCount: "účtov, žiadne sledovanie",
                         featuresTitle: "Funkcie",
                         featuresCaption: "Otvorte dlaždicu a nastavte ju. Čokoľvek nepoužívate, sa dá úplne vypnúť.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "Z výrezu sa stane živé centrum pre hudbu, časovače, kalendár a všetko, čo práve beží.",
                                            ["Práve hrá", "Živé aktivity", "Uzamknutá obrazovka", "Kalendár", "Časovač"]),
                             .agents: .init("AI agenti",
                                            "Claude a Codex na prvý pohľad: využitie, limity a práve bežiace relácie.",
                                            ["Claude", "Codex", "Limity", "Živé relácie"]),
                             .developers: .init("Pre vývojárov",
                                            "Nasadenia, pull requesty, čas pri kóde a dlhé príkazy terminálu priamo pri kamere.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminál", "Príkazová lišta"]),
                             .files: .init("Súbory a fotky",
                                            "Polica na všetko, čo pretiahnete, AirDrop z výrezu a rýchle úpravy fotiek.",
                                            ["Polica", "AirDrop", "Konverzia", "Odstrániť pozadie", "Schránka"]),
                             .capture: .init("Zachytávanie",
                                            "Snímky obrazovky, posuvné snímky, nahrávky a text z čohokoľvek na obrazovke.",
                                            ["Snímka obrazovky", "Posúvanie", "Nahrávanie", "Text (OCR)", "Výber farby"]),
                             .system: .init("Systém",
                                            "CPU, pamäť, sieť, batéria a ventilátory v lište s ponukami a Mac, ktorý nezaspí, keď to potrebujete.",
                                            ["CPU", "Pamäť", "Sieť", "Batéria", "Ventilátory", "Bdelý režim"]),
                             .windows: .init("Okná a Dock",
                                            "Prepínajte, ukladajte a prezerajte okná a ukončujte apky, keď sa zavrie ich posledné okno.",
                                            ["Prepínač", "Rozloženia", "Náhľady v Docku", "Ukončiť po zatvorení"]),
                             .input: .init("Myš a klávesnica",
                                            "Plynulé rolovanie, skratky na tlačidlách a útržky textu, ktoré sa napíšu samy.",
                                            ["Plynulé rolovanie", "Tlačidlá myši", "Útržky", "Super kláves"]),
                             .sound: .init("Zvuk",
                                            "Hlasitosť pre každú apku, rýchle prepnutie výstupu a mikrofón, ktorý stlmíte odkiaľkoľvek.",
                                            ["Mixér", "Výstup", "Stlmiť mikrofón"]),
                             .utilities: .init("Nástroje",
                                            "Rýchly panel, poznámkový blok a nástroje, ktoré udržia váš Mac v poriadku.",
                                            ["Rýchly panel", "Poznámkový blok", "Čistenie", "Odinštalátor", "Homebrew"]),
                         ],
                         madeBy: "Vytvoril",
                         role: "Fullstack vývojár a dizajnér",
                         bio: "Som fullstack vývojár a dizajnér, informatik, ktorý programuje, navrhuje a fotí. Tvorím webové aplikácie od začiatku do konca, navrhujem moderné UI/UX a grafiku a robím video a fotografiu. Život medzi inžinierstvom a dizajnom mi umožňuje dotiahnuť nápad od konceptu až po skutočný vydaný produkt, vrátane Zenithu.",
                         status: "Tvorí Zenith",
                         studioCaption: "Kreatívne štúdio zo Sumatry v Indonézii. Fotografia, film, web a aplikácie pre Mac.",
                         website: "Web")
        case .de:
            return .init(subtitle: "Eine Werkzeugzentrale für deinen Mac: die Notch, die Menüleiste und jedes Werkzeug dazwischen.",
                         featureCount: "Funktionen",
                         languageCount: "Sprachen",
                         accountCount: "Konten, kein Tracking",
                         featuresTitle: "Funktionen",
                         featuresCaption: "Öffne eine Kachel, um sie einzurichten. Was du nicht nutzt, lässt sich ganz abschalten.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "Die Notch wird zur Live-Zentrale für Musik, Timer, deinen Kalender und alles, was gerade läuft.",
                                            ["Jetzt läuft", "Live-Aktivitäten", "Sperrbildschirm", "Kalender", "Timer"]),
                             .agents: .init("KI-Agenten",
                                            "Claude und Codex auf einen Blick: Nutzung, Limits und die laufenden Sitzungen.",
                                            ["Claude", "Codex", "Limits", "Live-Sitzungen"]),
                             .developers: .init("Für Entwickler",
                                            "Deployments, Pull Requests, Coding-Zeit und lange Terminal-Befehle, direkt neben der Kamera.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminal", "Befehlsleiste"]),
                             .files: .init("Dateien & Fotos",
                                            "Eine Ablage für alles, was du ziehst, AirDrop aus der Notch und schnelle Foto-Korrekturen.",
                                            ["Ablage", "AirDrop", "Umwandeln", "Hintergrund entfernen", "Zwischenablage"]),
                             .capture: .init("Aufnahme",
                                            "Bildschirmfotos, scrollende Aufnahmen, Bildschirmaufnahmen und Text von allem auf dem Bildschirm.",
                                            ["Bildschirmfoto", "Scrollen", "Aufnahme", "Text (OCR)", "Farbpipette"]),
                             .system: .init("System",
                                            "CPU, Speicher, Netzwerk, Batterie und Lüfter in der Menüleiste, und ein Mac, der wach bleibt, wenn du ihn brauchst.",
                                            ["CPU", "Speicher", "Netzwerk", "Batterie", "Lüfter", "Wachhalten"]),
                             .windows: .init("Fenster & Dock",
                                            "Fenster wechseln, anordnen und in der Vorschau sehen, und Apps beenden, wenn ihr letztes Fenster schließt.",
                                            ["Umschalter", "Layouts", "Dock-Vorschau", "Beim Schließen beenden"]),
                             .input: .init("Maus & Tastatur",
                                            "Sanftes Scrollen, Kurzbefehle auf Maustasten und Textbausteine, die sich selbst tippen.",
                                            ["Sanftes Scrollen", "Maustasten", "Textbausteine", "Super-Taste"]),
                             .sound: .init("Ton",
                                            "Eine Lautstärke für jede App, schneller Ausgabewechsel und ein Mikrofon, das du von überall stummschaltest.",
                                            ["Mixer", "Ausgabe", "Mikro stumm"]),
                             .utilities: .init("Werkzeuge",
                                            "Ein Schnellpanel, ein Notizblock und die Werkzeuge, die deinen Mac aufgeräumt halten.",
                                            ["Schnellpanel", "Notizblock", "Aufräumen", "Deinstallieren", "Homebrew"]),
                         ],
                         madeBy: "Gemacht von",
                         role: "Fullstack-Entwickler und Designer",
                         bio: "Ich bin Fullstack-Entwickler und Designer, ein Informatikingenieur, der programmiert, gestaltet und fotografiert. Ich baue Web-Apps von Anfang bis Ende, gestalte moderne UI/UX und Grafiken und produziere Video und Fotografie. Zwischen Technik und Design zu leben, lässt mich eine Idee vom Konzept bis zum echten, veröffentlichten Produkt bringen, Zenith eingeschlossen.",
                         status: "Baut an Zenith",
                         studioCaption: "Kreativstudio aus Sumatra, Indonesien. Fotografie, Film, Web und Mac-Apps.",
                         website: "Website")
        case .fr:
            return .init(subtitle: "Un centre d’utilitaires pour votre Mac. L’encoche, la barre des menus et chaque outil entre les deux.",
                         featureCount: "fonctionnalités",
                         languageCount: "langues",
                         accountCount: "comptes, aucun pistage",
                         featuresTitle: "Fonctionnalités",
                         featuresCaption: "Ouvrez une tuile pour la configurer. Tout ce que vous n’utilisez pas peut être entièrement désactivé.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "L’encoche devient un centre en direct pour la musique, les minuteurs, votre calendrier et tout ce qui tourne.",
                                            ["À l’écoute", "Activités en direct", "Écran verrouillé", "Calendrier", "Minuteur"]),
                             .agents: .init("Agents IA",
                                            "Claude et Codex d’un coup d’œil, avec l’utilisation, les limites et les sessions en cours.",
                                            ["Claude", "Codex", "Limites", "Sessions en direct"]),
                             .developers: .init("Pour les développeurs",
                                            "Déploiements, pull requests, temps de code et longues commandes du terminal, juste à côté de la caméra.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminal", "Barre de commande"]),
                             .files: .init("Fichiers et photos",
                                            "Une étagère pour ce que vous faites glisser, AirDrop depuis l’encoche et des retouches photo rapides.",
                                            ["Étagère", "AirDrop", "Convertir", "Supprimer l’arrière-plan", "Presse-papiers"]),
                             .capture: .init("Capture",
                                            "Captures d’écran, captures défilantes, enregistrements et texte de tout ce qui est à l’écran.",
                                            ["Capture d’écran", "Défilement", "Enregistrement", "Texte (OCR)", "Pipette"]),
                             .system: .init("Système",
                                            "Processeur, mémoire, réseau, batterie et ventilateurs dans la barre des menus, et un Mac qui reste éveillé quand il le faut.",
                                            ["CPU", "Mémoire", "Réseau", "Batterie", "Ventilateurs", "Garder éveillé"]),
                             .windows: .init("Fenêtres et Dock",
                                            "Changez, placez et prévisualisez les fenêtres, et quittez les apps à la fermeture de leur dernière fenêtre.",
                                            ["Sélecteur", "Dispositions", "Aperçus du Dock", "Quitter à la fermeture"]),
                             .input: .init("Souris et clavier",
                                            "Défilement fluide, raccourcis sur les boutons et extraits de texte qui se tapent tout seuls.",
                                            ["Défilement fluide", "Boutons de souris", "Extraits", "Super touche"]),
                             .sound: .init("Son",
                                            "Un volume pour chaque app, un changement de sortie rapide et un micro que vous coupez de partout.",
                                            ["Mélangeur", "Sortie", "Couper le micro"]),
                             .utilities: .init("Utilitaires",
                                            "Un panneau rapide, un bloc-notes et les outils qui gardent votre Mac en ordre.",
                                            ["Panneau rapide", "Bloc-notes", "Nettoyage", "Désinstallation", "Homebrew"]),
                         ],
                         madeBy: "Créé par",
                         role: "Développeur fullstack et designer",
                         bio: "Je suis développeur fullstack et designer, un ingénieur en informatique qui code, conçoit et photographie. Je crée des applications web de bout en bout, je conçois des interfaces UI/UX et des visuels modernes, et je produis de la vidéo et de la photo. Vivre entre ingénierie et design me permet de mener une idée du concept à un vrai produit publié, Zenith compris.",
                         status: "Construit Zenith",
                         studioCaption: "Studio créatif de Sumatra, en Indonésie. Photo, film, web et apps Mac.",
                         website: "Site web")
        case .it:
            return .init(subtitle: "Un centro di utilità per il tuo Mac: il notch, la barra dei menu e ogni strumento nel mezzo.",
                         featureCount: "funzioni",
                         languageCount: "lingue",
                         accountCount: "account, nessun tracciamento",
                         featuresTitle: "Funzioni",
                         featuresCaption: "Apri un riquadro per configurarlo. Ciò che non usi si può disattivare del tutto.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "Il notch diventa un centro dal vivo per musica, timer, calendario e tutto ciò che è in corso.",
                                            ["In riproduzione", "Attività live", "Schermata di blocco", "Calendario", "Timer"]),
                             .agents: .init("Agenti IA",
                                            "Claude e Codex a colpo d’occhio: utilizzo, limiti e le sessioni in corso.",
                                            ["Claude", "Codex", "Limiti", "Sessioni live"]),
                             .developers: .init("Per sviluppatori",
                                            "Deploy, pull request, tempo di programmazione e lunghi comandi del terminale, accanto alla fotocamera.",
                                            ["Vercel", "GitHub", "WakaTime", "Terminale", "Barra dei comandi"]),
                             .files: .init("File e foto",
                                            "Un ripiano per ciò che trascini, AirDrop dal notch e ritocchi rapidi alle foto.",
                                            ["Ripiano", "AirDrop", "Converti", "Rimuovi sfondo", "Appunti"]),
                             .capture: .init("Cattura",
                                            "Istantanee, catture a scorrimento, registrazioni e testo da qualsiasi cosa sullo schermo.",
                                            ["Istantanea", "Scorrimento", "Registrazione", "Testo (OCR)", "Contagocce"]),
                             .system: .init("Sistema",
                                            "CPU, memoria, rete, batteria e ventole nella barra dei menu, e un Mac che resta attivo quando serve.",
                                            ["CPU", "Memoria", "Rete", "Batteria", "Ventole", "Mantieni attivo"]),
                             .windows: .init("Finestre e Dock",
                                            "Cambia, disponi e visualizza in anteprima le finestre, e chiudi le app quando si chiude l’ultima finestra.",
                                            ["Commutatore", "Layout", "Anteprime del Dock", "Esci alla chiusura"]),
                             .input: .init("Mouse e tastiera",
                                            "Scorrimento fluido, scorciatoie sui tasti e frammenti di testo che si scrivono da soli.",
                                            ["Scorrimento fluido", "Tasti del mouse", "Frammenti", "Super tasto"]),
                             .sound: .init("Suono",
                                            "Un volume per ogni app, un cambio rapido dell’uscita e un microfono da silenziare ovunque.",
                                            ["Mixer", "Uscita", "Silenzia microfono"]),
                             .utilities: .init("Utilità",
                                            "Un pannello rapido, un blocco note e gli strumenti che tengono in ordine il tuo Mac.",
                                            ["Pannello rapido", "Blocco note", "Pulizia", "Disinstallatore", "Homebrew"]),
                         ],
                         madeBy: "Creato da",
                         role: "Sviluppatore fullstack e designer",
                         bio: "Sono uno sviluppatore fullstack e designer, un ingegnere informatico che programma, progetta e fotografa. Realizzo app web dall’inizio alla fine, curo UI/UX e grafiche moderne e produco video e fotografia. Vivere tra ingegneria e design mi permette di portare un’idea dal concetto a un prodotto reale e pubblicato, Zenith compreso.",
                         status: "Sta creando Zenith",
                         studioCaption: "Studio creativo di Sumatra, Indonesia. Fotografia, video, web e app per Mac.",
                         website: "Sito web")
        case .ja:
            return .init(subtitle: "Mac のためのユーティリティハブ。ノッチ、メニューバー、そしてその間のあらゆるツール。",
                         featureCount: "機能",
                         languageCount: "言語",
                         accountCount: "アカウント、トラッキングなし",
                         featuresTitle: "機能",
                         featuresCaption: "タイルを開くと設定できます。使わないものは完全にオフにできます。",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "ノッチが、音楽、タイマー、カレンダー、実行中のあらゆるもののライブハブになります。",
                                            ["再生中", "ライブアクティビティ", "ロック画面", "カレンダー", "タイマー"]),
                             .agents: .init("AI エージェント",
                                            "Claude と Codex をひと目で。使用量、上限、実行中のセッション。",
                                            ["Claude", "Codex", "上限", "ライブセッション"]),
                             .developers: .init("開発者向け",
                                            "デプロイ、プルリクエスト、コーディング時間、長いターミナルコマンドを、カメラのすぐ横に。",
                                            ["Vercel", "GitHub", "WakaTime", "ターミナル", "コマンドバー"]),
                             .files: .init("ファイルと写真",
                                            "ドラッグしたものを置くシェルフ、ノッチからの AirDrop、すばやい写真の調整。",
                                            ["シェルフ", "AirDrop", "変換", "背景を削除", "クリップボード"]),
                             .capture: .init("キャプチャ",
                                            "スクリーンショット、スクロールキャプチャ、画面収録、画面上のあらゆるもののテキスト。",
                                            ["スクリーンショット", "スクロール", "収録", "テキスト (OCR)", "カラーピッカー"]),
                             .system: .init("システム",
                                            "メニューバーに CPU、メモリ、ネットワーク、バッテリー、ファン。必要なときはスリープしない Mac に。",
                                            ["CPU", "メモリ", "ネットワーク", "バッテリー", "ファン", "スリープ防止"]),
                             .windows: .init("ウインドウと Dock",
                                            "ウインドウの切り替え、配置、プレビュー。最後のウインドウを閉じたらアプリも終了。",
                                            ["スイッチャー", "レイアウト", "Dock プレビュー", "閉じたら終了"]),
                             .input: .init("マウスとキーボード",
                                            "スムーズスクロール、ボタンのショートカット、ひとりでに入力されるスニペット。",
                                            ["スムーズスクロール", "マウスボタン", "スニペット", "スーパーキー"]),
                             .sound: .init("サウンド",
                                            "アプリごとの音量、すばやい出力の切り替え、どこからでも消音できるマイク。",
                                            ["ミキサー", "出力", "マイクを消音"]),
                             .utilities: .init("ユーティリティ",
                                            "クイックパネル、スクラッチパッド、そして Mac を整えておくツール。",
                                            ["クイックパネル", "スクラッチパッド", "クリーンアップ", "アンインストーラ", "Homebrew"]),
                         ],
                         madeBy: "制作",
                         role: "フルスタック開発者・デザイナー",
                         bio: "フルスタック開発者でありデザイナー。コードを書き、デザインし、写真を撮る情報工学エンジニアです。Webアプリを最初から最後まで作り、モダンなUI/UXやグラフィックをデザインし、映像と写真も手がけています。エンジニアリングとデザインの両方にいることで、アイデアを構想から実際にリリースされるプロダクトまで形にできます。Zenithもそのひとつです。",
                         status: "Zenithを開発中",
                         studioCaption: "インドネシア・スマトラ島のクリエイティブスタジオ。写真、映像、Web、Macアプリ。",
                         website: "Webサイト")
        case .ko:
            return .init(subtitle: "Mac을 위한 유틸리티 허브. 노치, 메뉴 막대, 그리고 그 사이의 모든 도구.",
                         featureCount: "기능",
                         languageCount: "언어",
                         accountCount: "계정, 추적 없음",
                         featuresTitle: "기능",
                         featuresCaption: "타일을 열어 설정하세요. 쓰지 않는 기능은 완전히 끌 수 있습니다.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "노치가 음악, 타이머, 캘린더, 실행 중인 모든 것을 위한 라이브 허브가 됩니다.",
                                            ["지금 재생 중", "실시간 현황", "잠금 화면", "캘린더", "타이머"]),
                             .agents: .init("AI 에이전트",
                                            "Claude와 Codex를 한눈에: 사용량, 한도, 지금 실행 중인 세션.",
                                            ["Claude", "Codex", "한도", "실시간 세션"]),
                             .developers: .init("개발자를 위해",
                                            "배포, 풀 리퀘스트, 코딩 시간, 오래 걸리는 터미널 명령을 카메라 바로 옆에서.",
                                            ["Vercel", "GitHub", "WakaTime", "터미널", "명령 막대"]),
                             .files: .init("파일과 사진",
                                            "끌어 놓은 것을 위한 선반, 노치에서 AirDrop, 빠른 사진 편집.",
                                            ["선반", "AirDrop", "변환", "배경 제거", "클립보드"]),
                             .capture: .init("캡처",
                                            "스크린샷, 스크롤 캡처, 화면 녹화, 화면 속 무엇이든 텍스트로.",
                                            ["스크린샷", "스크롤", "녹화", "텍스트 (OCR)", "색상 선택기"]),
                             .system: .init("시스템",
                                            "메뉴 막대에 CPU, 메모리, 네트워크, 배터리, 팬. 필요할 땐 잠들지 않는 Mac.",
                                            ["CPU", "메모리", "네트워크", "배터리", "팬", "절전 방지"]),
                             .windows: .init("윈도우와 Dock",
                                            "윈도우를 전환하고, 배치하고, 미리 보고, 마지막 윈도우를 닫으면 앱도 종료합니다.",
                                            ["전환기", "레이아웃", "Dock 미리보기", "닫으면 종료"]),
                             .input: .init("마우스와 키보드",
                                            "부드러운 스크롤, 버튼 단축키, 저절로 입력되는 스니펫.",
                                            ["부드러운 스크롤", "마우스 버튼", "스니펫", "슈퍼 키"]),
                             .sound: .init("사운드",
                                            "앱마다 따로 맞추는 음량, 빠른 출력 전환, 어디서든 끌 수 있는 마이크.",
                                            ["믹서", "출력", "마이크 음소거"]),
                             .utilities: .init("유틸리티",
                                            "빠른 패널, 스크래치패드, 그리고 Mac을 깔끔하게 유지하는 도구.",
                                            ["빠른 패널", "스크래치패드", "정리", "앱 제거기", "Homebrew"]),
                         ],
                         madeBy: "만든 사람",
                         role: "풀스택 개발자 겸 디자이너",
                         bio: "저는 풀스택 개발자이자 디자이너로, 코드를 쓰고 디자인하고 사진을 찍는 정보공학 엔지니어입니다. 웹 앱을 처음부터 끝까지 만들고, 현대적인 UI/UX와 그래픽을 디자인하며, 영상과 사진도 제작합니다. 엔지니어링과 디자인을 오가며 아이디어를 콘셉트에서 실제 출시된 제품까지 만들어 냅니다. Zenith도 그중 하나입니다.",
                         status: "Zenith 만드는 중",
                         studioCaption: "인도네시아 수마트라의 크리에이티브 스튜디오. 사진, 영상, 웹, Mac 앱.",
                         website: "웹사이트")
        case .uk:
            return .init(subtitle: "Набір інструментів для вашого Mac: виріз, смуга меню і все, що між ними.",
                         featureCount: "функції",
                         languageCount: "мов",
                         accountCount: "акаунтів, без стеження",
                         featuresTitle: "Функції",
                         featuresCaption: "Відкрийте плитку, щоб налаштувати розділ. Усе, чим ви не користуєтеся, можна повністю вимкнути.",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "Виріз стає живим центром для музики, таймерів, календаря і всього, що зараз працює.",
                                            ["Зараз грає", "Живі активності", "Екран блокування", "Календар", "Таймер"]),
                             .agents: .init("ШІ-агенти",
                                            "Claude і Codex з першого погляду: використання, ліміти й активні сеанси.",
                                            ["Claude", "Codex", "Ліміти", "Активні сеанси"]),
                             .developers: .init("Для розробників",
                                            "Деплої, pull requests, час у коді й довгі команди термінала просто біля камери.",
                                            ["Vercel", "GitHub", "WakaTime", "Термінал", "Панель команд"]),
                             .files: .init("Файли й фото",
                                            "Полиця для всього, що ви перетягуєте, AirDrop з вирізу і швидке редагування фото.",
                                            ["Полиця", "AirDrop", "Конвертація", "Видалення фону", "Буфер обміну"]),
                             .capture: .init("Захоплення",
                                            "Знімки екрана, знімки з прокручуванням, записи й текст із будь-чого на екрані.",
                                            ["Знімок екрана", "Прокручування", "Запис", "Текст (OCR)", "Піпетка"]),
                             .system: .init("Система",
                                            "ЦП, пам’ять, мережа, акумулятор і вентилятори на смузі меню, а Mac не засинає, коли це потрібно.",
                                            ["ЦП", "Пам’ять", "Мережа", "Акумулятор", "Вентилятори", "Без сну"]),
                             .windows: .init("Вікна й Dock",
                                            "Перемикайте, розкладайте й переглядайте вікна, а застосунки закриваються разом з останнім вікном.",
                                            ["Перемикач", "Розкладки", "Перегляд у Dock", "Закриття з вікном"]),
                             .input: .init("Миша й клавіатура",
                                            "Плавна прокрутка, скорочення на кнопках і фрагменти тексту, що друкуються самі.",
                                            ["Плавна прокрутка", "Кнопки миші", "Фрагменти", "Суперклавіша"]),
                             .sound: .init("Звук",
                                            "Гучність для кожного застосунку, швидка зміна виходу й мікрофон, який вимикається звідусіль.",
                                            ["Мікшер", "Вихід", "Вимкнути мікрофон"]),
                             .utilities: .init("Утиліти",
                                            "Швидка панель, блокнот та інструменти, що тримають Mac у порядку.",
                                            ["Швидка панель", "Блокнот", "Очищення", "Деінсталятор", "Homebrew"]),
                         ],
                         madeBy: "Автор",
                         role: "Fullstack-розробник і дизайнер",
                         bio: "Я fullstack-розробник і дизайнер, інженер-інформатик, який пише код, проєктує й фотографує. Створюю вебзастосунки від початку до кінця, роблю сучасний UI/UX і графіку, знімаю відео та фото. Робота на межі інженерії та дизайну дає змогу довести ідею від концепції до справжнього випущеного продукту, зокрема Zenith.",
                         status: "Створює Zenith",
                         studioCaption: "Креативна студія із Суматри, Індонезія. Фото, відео, веб і застосунки для Mac.",
                         website: "Сайт")
        case .zhHans:
            return .init(subtitle: "你的 Mac 实用工具中心：刘海、菜单栏，以及其间的每一个工具。",
                         featureCount: "功能",
                         languageCount: "语言",
                         accountCount: "账户，零追踪",
                         featuresTitle: "功能",
                         featuresCaption: "打开一个方块即可设置。用不到的功能可以完全关闭。",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "刘海变成实时中心，显示音乐、计时器、日历和正在运行的一切。",
                                            ["正在播放", "实时活动", "锁定屏幕", "日历", "计时器"]),
                             .agents: .init("AI 智能体",
                                            "一眼看清 Claude 和 Codex：用量、限额和正在进行的会话。",
                                            ["Claude", "Codex", "限额", "实时会话"]),
                             .developers: .init("为开发者",
                                            "部署、拉取请求、编码时长和耗时的终端命令，就在摄像头旁边。",
                                            ["Vercel", "GitHub", "WakaTime", "终端", "命令栏"]),
                             .files: .init("文件与照片",
                                            "放置拖入内容的暂存架、从刘海使用 AirDrop，以及快速修图。",
                                            ["暂存架", "AirDrop", "转换", "移除背景", "剪贴板"]),
                             .capture: .init("截取",
                                            "截屏、滚动截屏、录屏，以及屏幕上任何内容中的文字。",
                                            ["截屏", "滚动截屏", "录屏", "文字 (OCR)", "颜色吸管"]),
                             .system: .init("系统",
                                            "菜单栏里的 CPU、内存、网络、电池和风扇，需要时让 Mac 保持唤醒。",
                                            ["CPU", "内存", "网络", "电池", "风扇", "保持唤醒"]),
                             .windows: .init("窗口与程序坞",
                                            "切换、排列和预览窗口，最后一个窗口关闭时退出应用。",
                                            ["切换器", "布局", "程序坞预览", "关闭时退出"]),
                             .input: .init("鼠标与键盘",
                                            "平滑滚动、按键快捷方式，以及会自己输入的文本片段。",
                                            ["平滑滚动", "鼠标按键", "文本片段", "超级键"]),
                             .sound: .init("声音",
                                            "为每个应用单独调节音量、快速切换输出，以及随处可静音的麦克风。",
                                            ["混音器", "输出", "静音麦克风"]),
                             .utilities: .init("实用工具",
                                            "快捷面板、便签本，以及让 Mac 保持整洁的工具。",
                                            ["快捷面板", "便签本", "清理", "卸载器", "Homebrew"]),
                         ],
                         madeBy: "制作者",
                         role: "全栈开发者与设计师",
                         bio: "我是一名全栈开发者和设计师，一个会写代码、做设计、也拍照的信息工程师。我从头到尾构建 Web 应用，设计现代的 UI/UX 与图形，也制作视频和摄影作品。游走于工程与设计之间，让我能把一个想法从概念变成真正发布的产品，Zenith 就是其中之一。",
                         status: "正在打造 Zenith",
                         studioCaption: "来自印度尼西亚苏门答腊的创意工作室。摄影、影片、网页与 Mac 应用。",
                         website: "网站")
        case .zhTW:
            return .init(subtitle: "你的 Mac 實用工具中心：瀏海、選單列，以及其間的每一個工具。",
                         featureCount: "功能",
                         languageCount: "語言",
                         accountCount: "帳號，零追蹤",
                         featuresTitle: "功能",
                         featuresCaption: "打開一個方塊即可設定。用不到的功能可以完全關閉。",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "瀏海變成即時中心，顯示音樂、計時器、行事曆和正在執行的一切。",
                                            ["正在播放", "即時動態", "鎖定畫面", "行事曆", "計時器"]),
                             .agents: .init("AI 代理",
                                            "一眼看清 Claude 和 Codex：用量、限額和進行中的工作階段。",
                                            ["Claude", "Codex", "限額", "即時工作階段"]),
                             .developers: .init("為開發者",
                                            "部署、提取要求、寫程式時數和耗時的終端機指令，就在相機旁邊。",
                                            ["Vercel", "GitHub", "WakaTime", "終端機", "指令列"]),
                             .files: .init("檔案與照片",
                                            "放置拖入內容的暫存架、從瀏海使用 AirDrop，以及快速修圖。",
                                            ["暫存架", "AirDrop", "轉換", "移除背景", "剪貼簿"]),
                             .capture: .init("擷取",
                                            "截圖、捲動截圖、螢幕錄影，以及螢幕上任何內容中的文字。",
                                            ["截圖", "捲動截圖", "錄影", "文字 (OCR)", "顏色吸管"]),
                             .system: .init("系統",
                                            "選單列中的 CPU、記憶體、網路、電池和風扇，需要時讓 Mac 保持喚醒。",
                                            ["CPU", "記憶體", "網路", "電池", "風扇", "保持喚醒"]),
                             .windows: .init("視窗與 Dock",
                                            "切換、排列和預覽視窗，最後一個視窗關閉時結束 App。",
                                            ["切換器", "佈局", "Dock 預覽", "關閉時結束"]),
                             .input: .init("滑鼠與鍵盤",
                                            "平滑捲動、按鍵快速鍵，以及會自己輸入的文字片段。",
                                            ["平滑捲動", "滑鼠按鍵", "文字片段", "超級鍵"]),
                             .sound: .init("聲音",
                                            "每個 App 各自的音量、快速切換輸出，以及隨處可靜音的麥克風。",
                                            ["混音器", "輸出", "靜音麥克風"]),
                             .utilities: .init("工具程式",
                                            "快速面板、便條紙，以及讓 Mac 保持整潔的工具。",
                                            ["快速面板", "便條紙", "清理", "解除安裝器", "Homebrew"]),
                         ],
                         madeBy: "製作者",
                         role: "全端開發者與設計師",
                         bio: "我是一名全端開發者和設計師，一個會寫程式、做設計、也拍照的資訊工程師。我從頭到尾打造網頁應用程式，設計現代的 UI/UX 與圖像，也製作影片和攝影作品。遊走於工程與設計之間，讓我能把一個想法從概念變成真正發布的產品，Zenith 就是其中之一。",
                         status: "正在打造 Zenith",
                         studioCaption: "來自印尼蘇門答臘的創意工作室。攝影、影片、網頁與 Mac App。",
                         website: "網站")
        case .zhHK:
            return .init(subtitle: "你的 Mac 實用工具中心：瀏海、選單列，以及兩者之間的每一個工具。",
                         featureCount: "功能",
                         languageCount: "語言",
                         accountCount: "帳戶，零追蹤",
                         featuresTitle: "功能",
                         featuresCaption: "打開一個方塊即可設定。用不着的功能可以完全關閉。",
                         areas: [
                             .island: .init("Dynamic Island",
                                            "瀏海變成即時中心，顯示音樂、計時器、行事曆及正在執行的一切。",
                                            ["正在播放", "即時動態", "鎖定畫面", "行事曆", "計時器"]),
                             .agents: .init("AI 代理",
                                            "一眼看清 Claude 和 Codex：用量、限額及進行中的工作階段。",
                                            ["Claude", "Codex", "限額", "即時工作階段"]),
                             .developers: .init("為開發者而設",
                                            "部署、拉取請求、寫程式時數及耗時的終端機指令，就在相機旁邊。",
                                            ["Vercel", "GitHub", "WakaTime", "終端機", "指令列"]),
                             .files: .init("檔案及相片",
                                            "放置拖入內容的暫存架、從瀏海使用 AirDrop，以及快速修圖。",
                                            ["暫存架", "AirDrop", "轉換", "移除背景", "剪貼板"]),
                             .capture: .init("擷取",
                                            "截圖、捲動截圖、螢幕錄影，以及螢幕上任何內容中的文字。",
                                            ["截圖", "捲動截圖", "錄影", "文字 (OCR)", "顏色吸管"]),
                             .system: .init("系統",
                                            "選單列中的 CPU、記憶體、網絡、電池及風扇，需要時讓 Mac 保持喚醒。",
                                            ["CPU", "記憶體", "網絡", "電池", "風扇", "保持喚醒"]),
                             .windows: .init("視窗及 Dock",
                                            "切換、排列及預覽視窗，最後一個視窗關閉時結束 App。",
                                            ["切換器", "佈局", "Dock 預覽", "關閉時結束"]),
                             .input: .init("滑鼠及鍵盤",
                                            "平滑捲動、按鍵快速鍵，以及會自己輸入的文字片段。",
                                            ["平滑捲動", "滑鼠按鍵", "文字片段", "超級鍵"]),
                             .sound: .init("聲音",
                                            "每個 App 各自的音量、快速切換輸出，以及隨處可靜音的麥克風。",
                                            ["混音器", "輸出", "靜音麥克風"]),
                             .utilities: .init("工具程式",
                                            "快速面板、記事本，以及讓 Mac 保持整潔的工具。",
                                            ["快速面板", "記事本", "清理", "解除安裝器", "Homebrew"]),
                         ],
                         madeBy: "製作者",
                         role: "全端開發者及設計師",
                         bio: "我是一名全端開發者及設計師，一個會寫程式、做設計、也會拍照的資訊工程師。我由頭到尾打造網頁應用程式，設計現代的 UI/UX 及圖像，亦製作影片和攝影作品。遊走於工程與設計之間，令我能把一個想法由概念變成真正推出的產品，Zenith 就是其中之一。",
                         status: "正在打造 Zenith",
                         studioCaption: "來自印尼蘇門答臘的創意工作室。攝影、影片、網頁及 Mac App。",
                         website: "網站")
        }
    }
}

struct ZenithLockScreenTerminalStrings {
    /// The readout’s switch.
    let title: String
    let caption: String
    /// Over the list of lines.
    let lines: String
    let showProjects: String
    let showProjectsCaption: String
    let moveUp: String
    let moveDown: String
    /// The `sys` and `ci` lines; the others take their island section’s name.
    let system: String
    let checks: String
}

extension ZenithStrings {
    /// The lock screen’s terminal readout and its lines.
    static func lockScreenTerminal(_ language: AppLanguage) -> ZenithLockScreenTerminalStrings {
        switch language {
        case .enUS:
            return .init(title: "Terminal readout",
                         caption: "A monospaced status readout under the clock. Lines with nothing to show stay hidden, except Battery and CPU.",
                         lines: "Lines and order", showProjects: "Show project names",
                         showProjectsCaption: "When off, the lock screen shows counts and states only, never project, repository or file names.",
                         moveUp: "Move up", moveDown: "Move down", system: "Battery and CPU", checks: "GitHub checks")
        case .ptBR:
            return .init(title: "Leitura de terminal",
                         caption: "Um resumo de status em fonte monoespaçada abaixo do relógio. Linhas sem nada para mostrar ficam ocultas, exceto Bateria e CPU.",
                         lines: "Linhas e ordem", showProjects: "Mostrar nomes de projetos",
                         showProjectsCaption: "Desativado, a tela bloqueada mostra só contagens e estados, nunca nomes de projetos, repositórios ou arquivos.",
                         moveUp: "Mover para cima", moveDown: "Mover para baixo", system: "Bateria e CPU",
                         checks: "Verificações do GitHub")
        case .tr:
            return .init(title: "Terminal görünümü",
                         caption: "Saatin altında eş aralıklı yazıyla bir durum özeti. Gösterecek bir şeyi olmayan satırlar gizlenir; Pil ve CPU her zaman görünür.",
                         lines: "Satırlar ve sıra", showProjects: "Proje adlarını göster",
                         showProjectsCaption: "Kapalıyken kilit ekranı yalnızca sayıları ve durumları gösterir; proje, depo veya dosya adlarını asla göstermez.",
                         moveUp: "Yukarı taşı", moveDown: "Aşağı taşı", system: "Pil ve CPU", checks: "GitHub denetimleri")
        case .ru:
            return .init(title: "Терминальная сводка",
                         caption: "Моноширинная сводка состояния под часами. Строки, которым нечего показать, скрыты, кроме «Аккумулятор и ЦП».",
                         lines: "Строки и порядок", showProjects: "Показывать названия проектов",
                         showProjectsCaption: "Когда выключено, экран блокировки показывает только количество и состояния, без названий проектов, репозиториев и файлов.",
                         moveUp: "Переместить вверх", moveDown: "Переместить вниз", system: "Аккумулятор и ЦП",
                         checks: "Проверки GitHub")
        case .es:
            return .init(title: "Lectura de terminal",
                         caption: "Un resumen de estado en fuente monoespaciada bajo el reloj. Las líneas sin nada que mostrar se ocultan, salvo Batería y CPU.",
                         lines: "Líneas y orden", showProjects: "Mostrar nombres de proyectos",
                         showProjectsCaption: "Desactivado, la pantalla bloqueada solo muestra recuentos y estados, nunca nombres de proyectos, repositorios ni archivos.",
                         moveUp: "Subir", moveDown: "Bajar", system: "Batería y CPU", checks: "Comprobaciones de GitHub")
        case .sk:
            return .init(title: "Terminálový prehľad",
                         caption: "Prehľad stavu neproporcionálnym písmom pod hodinami. Riadky bez obsahu sa skryjú, okrem Batéria a CPU.",
                         lines: "Riadky a poradie", showProjects: "Zobraziť názvy projektov",
                         showProjectsCaption: "Keď je vypnuté, uzamknutá obrazovka ukazuje iba počty a stavy, nikdy názvy projektov, repozitárov ani súborov.",
                         moveUp: "Posunúť nahor", moveDown: "Posunúť nadol", system: "Batéria a CPU", checks: "Kontroly GitHubu")
        case .de:
            return .init(title: "Terminal-Anzeige",
                         caption: "Eine Statusanzeige in Festbreitenschrift unter der Uhr. Zeilen ohne Inhalt bleiben ausgeblendet, außer Batterie und CPU.",
                         lines: "Zeilen und Reihenfolge", showProjects: "Projektnamen anzeigen",
                         showProjectsCaption: "Aus: Der Sperrbildschirm zeigt nur Anzahlen und Zustände, nie Projekt-, Repository- oder Dateinamen.",
                         moveUp: "Nach oben", moveDown: "Nach unten", system: "Batterie und CPU", checks: "GitHub-Checks")
        case .fr:
            return .init(title: "Affichage terminal",
                         caption: "Un état en police à chasse fixe sous l’horloge. Les lignes sans rien à afficher restent masquées, sauf Batterie et CPU.",
                         lines: "Lignes et ordre", showProjects: "Afficher les noms de projets",
                         showProjectsCaption: "Désactivé, l’écran verrouillé n’affiche que des nombres et des états, jamais de noms de projets, de dépôts ou de fichiers.",
                         moveUp: "Monter", moveDown: "Descendre", system: "Batterie et CPU", checks: "Vérifications GitHub")
        case .it:
            return .init(title: "Lettura da terminale",
                         caption: "Un riepilogo di stato a spaziatura fissa sotto l’orologio. Le righe senza nulla da mostrare restano nascoste, tranne Batteria e CPU.",
                         lines: "Righe e ordine", showProjects: "Mostra i nomi dei progetti",
                         showProjectsCaption: "Se disattivato, la schermata di blocco mostra solo conteggi e stati, mai nomi di progetti, repository o file.",
                         moveUp: "Sposta su", moveDown: "Sposta giù", system: "Batteria e CPU", checks: "Controlli GitHub")
        case .ja:
            return .init(title: "ターミナル表示",
                         caption: "時計の下に等幅フォントで状態を表示します。表示する内容がない行は隠れます（バッテリーとCPUは常に表示）。",
                         lines: "行と順序", showProjects: "プロジェクト名を表示",
                         showProjectsCaption: "オフのとき、ロック画面には件数と状態だけを表示し、プロジェクト、リポジトリ、ファイルの名前は表示しません。",
                         moveUp: "上へ移動", moveDown: "下へ移動", system: "バッテリーとCPU", checks: "GitHubのチェック")
        case .ko:
            return .init(title: "터미널 표시",
                         caption: "시계 아래에 고정폭 글꼴로 상태를 보여 줍니다. 보여 줄 내용이 없는 줄은 숨겨지며, 배터리 및 CPU는 항상 표시됩니다.",
                         lines: "줄과 순서", showProjects: "프로젝트 이름 표시",
                         showProjectsCaption: "끄면 잠금 화면에 개수와 상태만 표시되고 프로젝트, 저장소, 파일 이름은 표시되지 않습니다.",
                         moveUp: "위로 이동", moveDown: "아래로 이동", system: "배터리 및 CPU", checks: "GitHub 검사")
        case .uk:
            return .init(title: "Термінальне зведення",
                         caption: "Моноширинне зведення стану під годинником. Рядки, яким нічого показати, приховано, окрім «Акумулятор і ЦП».",
                         lines: "Рядки й порядок", showProjects: "Показувати назви проєктів",
                         showProjectsCaption: "Коли вимкнено, екран блокування показує лише кількість і стани, без назв проєктів, репозиторіїв і файлів.",
                         moveUp: "Перемістити вгору", moveDown: "Перемістити вниз", system: "Акумулятор і ЦП",
                         checks: "Перевірки GitHub")
        case .zhHans:
            return .init(title: "终端读数",
                         caption: "在时钟下方以等宽字体显示状态。没有内容的行会隐藏，“电池和 CPU”始终显示。",
                         lines: "行与顺序", showProjects: "显示项目名称",
                         showProjectsCaption: "关闭时，锁定屏幕只显示数量和状态，从不显示项目、仓库或文件名称。",
                         moveUp: "上移", moveDown: "下移", system: "电池和 CPU", checks: "GitHub 检查")
        case .zhTW:
            return .init(title: "終端機讀數",
                         caption: "在時鐘下方以等寬字體顯示狀態。沒有內容的行會隱藏，「電池與 CPU」一律顯示。",
                         lines: "行與順序", showProjects: "顯示專案名稱",
                         showProjectsCaption: "關閉時，鎖定畫面只顯示數量與狀態，絕不顯示專案、儲存庫或檔案名稱。",
                         moveUp: "上移", moveDown: "下移", system: "電池與 CPU", checks: "GitHub 檢查")
        case .zhHK:
            return .init(title: "終端機讀數",
                         caption: "在時鐘下方以等寬字體顯示狀態。沒有內容的行會隱藏，「電池與 CPU」一律顯示。",
                         lines: "行與次序", showProjects: "顯示項目名稱",
                         showProjectsCaption: "關閉時，鎖定畫面只顯示數量與狀態，絕不顯示項目、儲存庫或檔案名稱。",
                         moveUp: "上移", moveDown: "下移", system: "電池與 CPU", checks: "GitHub 檢查")
        }
    }
}

struct ZenithLockScreenTerminalTitleStrings {
    /// Over the field for the readout’s title bar.
    let windowTitle: String
    let caption: String
    /// The button that fills in `<computer name> — status`.
    let useComputerName: String
}

extension ZenithStrings {
    /// The terminal readout’s own name in its title bar.
    static func lockScreenTerminalTitle(_ language: AppLanguage) -> ZenithLockScreenTerminalTitleStrings {
        switch language {
        case .enUS:
            return .init(windowTitle: "Window title",
                         caption: "Shown in the readout’s title bar. Leave it empty for the default.",
                         useComputerName: "Use this Mac’s name")
        case .ptBR:
            return .init(windowTitle: "Título da janela",
                         caption: "Aparece na barra de título da leitura. Deixe vazio para usar o padrão.",
                         useComputerName: "Usar o nome deste Mac")
        case .tr:
            return .init(windowTitle: "Pencere başlığı",
                         caption: "Görünümün başlık çubuğunda gösterilir. Varsayılan için boş bırakın.",
                         useComputerName: "Bu Mac’in adını kullan")
        case .ru:
            return .init(windowTitle: "Заголовок окна",
                         caption: "Показывается в заголовке сводки. Оставьте пустым для стандартного.",
                         useComputerName: "Использовать имя этого Mac")
        case .es:
            return .init(windowTitle: "Título de la ventana",
                         caption: "Se muestra en la barra de título de la lectura. Déjalo vacío para usar el predeterminado.",
                         useComputerName: "Usar el nombre de este Mac")
        case .sk:
            return .init(windowTitle: "Názov okna",
                         caption: "Zobrazuje sa v záhlaví prehľadu. Ak ho necháte prázdny, použije sa predvolený.",
                         useComputerName: "Použiť názov tohto Macu")
        case .de:
            return .init(windowTitle: "Fenstertitel",
                         caption: "Steht in der Titelleiste der Anzeige. Leer lassen für den Standardtitel.",
                         useComputerName: "Namen dieses Mac verwenden")
        case .fr:
            return .init(windowTitle: "Titre de la fenêtre",
                         caption: "Affiché dans la barre de titre de l’affichage. Laissez vide pour le titre par défaut.",
                         useComputerName: "Utiliser le nom de ce Mac")
        case .it:
            return .init(windowTitle: "Titolo della finestra",
                         caption: "Compare nella barra del titolo. Lascialo vuoto per usare quello predefinito.",
                         useComputerName: "Usa il nome di questo Mac")
        case .ja:
            return .init(windowTitle: "ウインドウのタイトル",
                         caption: "表示のタイトルバーに表示されます。空欄にするとデフォルトになります。",
                         useComputerName: "このMacの名前を使用")
        case .ko:
            return .init(windowTitle: "윈도우 제목",
                         caption: "표시의 제목 막대에 나타납니다. 비워 두면 기본값을 사용합니다.",
                         useComputerName: "이 Mac의 이름 사용")
        case .uk:
            return .init(windowTitle: "Заголовок вікна",
                         caption: "Показується в заголовку зведення. Залиште порожнім для стандартного.",
                         useComputerName: "Використати назву цього Mac")
        case .zhHans:
            return .init(windowTitle: "窗口标题",
                         caption: "显示在读数的标题栏中。留空则使用默认标题。",
                         useComputerName: "使用这台 Mac 的名称")
        case .zhTW:
            return .init(windowTitle: "視窗標題",
                         caption: "顯示在讀數的標題列中。留空即使用預設標題。",
                         useComputerName: "使用這部 Mac 的名稱")
        case .zhHK:
            return .init(windowTitle: "視窗標題",
                         caption: "顯示在讀數的標題列中。留空即使用預設標題。",
                         useComputerName: "使用這部 Mac 的名稱")
        }
    }
}

struct ZenithVercelAlertStrings {
    /// The switch in the Vercel section’s options.
    let failureAlerts: String
    let failureAlertsCaption: String
    /// The notification’s title; its body is the project and branch.
    let buildFailed: String
}

extension ZenithStrings {
    /// A notification when a Vercel build fails.
    static func vercelAlerts(_ language: AppLanguage) -> ZenithVercelAlertStrings {
        switch language {
        case .enUS:
            return .init(failureAlerts: "Notify when a build fails",
                         failureAlertsCaption: "Checks every 10 minutes, or every 2 while something builds, even with the island closed. The notification names the project and branch, never the commit message.",
                         buildFailed: "Vercel build failed")
        case .ptBR:
            return .init(failureAlerts: "Avisar quando um build falhar",
                         failureAlertsCaption: "Verifica a cada 10 minutos, ou a cada 2 enquanto algo é criado, mesmo com a ilha fechada. A notificação mostra o projeto e o branch, nunca a mensagem do commit.",
                         buildFailed: "Build da Vercel falhou")
        case .tr:
            return .init(failureAlerts: "Derleme başarısız olunca bildir",
                         failureAlertsCaption: "Ada kapalıyken bile 10 dakikada bir, bir derleme sürerken 2 dakikada bir denetler. Bildirim projeyi ve dalı gösterir, commit iletisini asla göstermez.",
                         buildFailed: "Vercel derlemesi başarısız oldu")
        case .ru:
            return .init(failureAlerts: "Уведомлять о неудачной сборке",
                         failureAlertsCaption: "Проверяет каждые 10 минут, а во время сборки каждые 2, даже когда остров закрыт. В уведомлении только проект и ветка, без сообщения коммита.",
                         buildFailed: "Сборка Vercel не удалась")
        case .es:
            return .init(failureAlerts: "Avisar cuando falle una compilación",
                         failureAlertsCaption: "Comprueba cada 10 minutos, o cada 2 mientras algo se compila, incluso con la isla cerrada. La notificación muestra el proyecto y la rama, nunca el mensaje del commit.",
                         buildFailed: "Falló la compilación en Vercel")
        case .sk:
            return .init(failureAlerts: "Upozorniť, keď zostava zlyhá",
                         failureAlertsCaption: "Kontroluje každých 10 minút a počas zostavovania každé 2 minúty, aj keď je Dynamic Island zatvorený. Upozornenie ukáže projekt a vetvu, nikdy správu commitu.",
                         buildFailed: "Zostava vo Verceli zlyhala")
        case .de:
            return .init(failureAlerts: "Melden, wenn ein Build fehlschlägt",
                         failureAlertsCaption: "Prüft alle 10 Minuten, während eines Builds alle 2, auch bei geschlossener Insel. Die Mitteilung nennt Projekt und Branch, nie die Commit-Nachricht.",
                         buildFailed: "Vercel-Build fehlgeschlagen")
        case .fr:
            return .init(failureAlerts: "Prévenir en cas d’échec d’un build",
                         failureAlertsCaption: "Vérifie toutes les 10 minutes, ou toutes les 2 pendant un build, même l’île fermée. La notification indique le projet et la branche, jamais le message du commit.",
                         buildFailed: "Échec du build Vercel")
        case .it:
            return .init(failureAlerts: "Avvisa quando una build non riesce",
                         failureAlertsCaption: "Controlla ogni 10 minuti, o ogni 2 durante una build, anche con l’isola chiusa. La notifica indica progetto e branch, mai il messaggio del commit.",
                         buildFailed: "Build Vercel non riuscita")
        case .ja:
            return .init(failureAlerts: "ビルドが失敗したら通知",
                         failureAlertsCaption: "島を閉じていても10分ごと、ビルド中は2分ごとに確認します。通知にはプロジェクトとブランチだけを表示し、コミットメッセージは表示しません。",
                         buildFailed: "Vercelのビルドに失敗しました")
        case .ko:
            return .init(failureAlerts: "빌드 실패 시 알림",
                         failureAlertsCaption: "섬이 닫혀 있어도 10분마다, 빌드 중에는 2분마다 확인합니다. 알림에는 프로젝트와 브랜치만 표시되며 커밋 메시지는 표시되지 않습니다.",
                         buildFailed: "Vercel 빌드 실패")
        case .uk:
            return .init(failureAlerts: "Сповіщати про невдалу збірку",
                         failureAlertsCaption: "Перевіряє кожні 10 хвилин, а під час збірки кожні 2, навіть коли острівець закрито. У сповіщенні лише проєкт і гілка, без повідомлення коміту.",
                         buildFailed: "Збірка Vercel не вдалася")
        case .zhHans:
            return .init(failureAlerts: "构建失败时通知",
                         failureAlertsCaption: "即使岛已收起，也会每 10 分钟检查一次，构建期间每 2 分钟一次。通知只显示项目和分支，从不显示提交信息。",
                         buildFailed: "Vercel 构建失败")
        case .zhTW:
            return .init(failureAlerts: "建置失敗時通知",
                         failureAlertsCaption: "即使島已收合，也會每 10 分鐘檢查一次，建置期間每 2 分鐘一次。通知只顯示專案與分支，絕不顯示提交訊息。",
                         buildFailed: "Vercel 建置失敗")
        case .zhHK:
            return .init(failureAlerts: "建置失敗時通知",
                         failureAlertsCaption: "即使島已收合，亦會每 10 分鐘檢查一次，建置期間每 2 分鐘一次。通知只顯示項目與分支，絕不顯示提交訊息。",
                         buildFailed: "Vercel 建置失敗")
        }
    }
}

struct ZenithCommandActivityStrings {
    /// The activity’s name in the island’s activity picker.
    let activityTitle: String
    /// The card in Settings → Dynamic Island → Activity.
    let section: String
    let toggle: String
    let toggleCaption: String
    let showAfter: String
    /// A threshold choice; `%d` is the number of seconds.
    let seconds: String
    let showFolder: String
    let showFolderCaption: String
    let ignore: String
    let ignorePlaceholder: String
    let ignoreCaption: String
    let hook: String
    let hookCaption: String
    let install: String
    let copy: String
    let copied: String
    let remove: String
    let installed: String
    let notInstalled: String
    let otherBuild: String
    let damaged: String
    /// `%@` is how long ago, such as “2 min ago”.
    let lastEvent: String
    let noEvents: String
    let newTab: String
    let confirmTitle: String
    let confirmMessage: String
    let add: String
    let cancel: String
    let editFailed: String
    /// Read aloud for the strip.
    let running: String
    let succeeded: String
    let failed: String
}

extension ZenithStrings {
    /// Long-running terminal commands in the closed island.
    static func commandActivity(_ language: AppLanguage) -> ZenithCommandActivityStrings {
        switch language {
        case .enUS:
            return .init(activityTitle: "Terminal", section: "Terminal commands",
                         toggle: "Command activity",
                         toggleCaption: "A command that runs a while in zsh shows in the closed island with its time, then ✓ or ✗ when it ends. Only the program’s name shows, never its arguments.",
                         showAfter: "Show after", seconds: "%d s",
                         showFolder: "Show folder",
                         showFolderCaption: "Adds the name of the folder the command runs in.",
                         ignore: "Also ignore", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Program names, separated by commas. Editors, pagers, ssh, top, tail -f, REPLs, dev servers and claude are always left out.",
                         hook: "Shell hook",
                         hookCaption: "A few lines in ~/.zshrc tell Zenith when a command starts and ends. They use shell builtins only, print nothing, and skip lines typed with a leading space.",
                         install: "Install shell hook", copy: "Copy snippet", copied: "Copied", remove: "Remove hook",
                         installed: "Installed in ~/.zshrc", notInstalled: "Not installed",
                         otherBuild: "Installed for another Zenith build. Install again to use this one.",
                         damaged: "~/.zshrc has an unfinished Zenith block. Fix it by hand.",
                         lastEvent: "Last command seen %@", noEvents: "No commands seen yet",
                         newTab: "Open a new terminal tab for the change to apply.",
                         confirmTitle: "Add the shell hook to ~/.zshrc?",
                         confirmMessage: "Zenith adds this block to the end of ~/.zshrc. Nothing else in the file changes.",
                         add: "Add", cancel: "Cancel", editFailed: "Couldn’t update ~/.zshrc.",
                         running: "Running", succeeded: "Succeeded", failed: "Failed")
        case .ptBR:
            return .init(activityTitle: "Terminal", section: "Comandos do Terminal",
                         toggle: "Atividade de comandos",
                         toggleCaption: "Um comando que demora no zsh aparece na ilha fechada com o tempo e, ao terminar, com ✓ ou ✗. Só o nome do programa aparece, nunca os argumentos.",
                         showAfter: "Mostrar após", seconds: "%d s",
                         showFolder: "Mostrar pasta",
                         showFolderCaption: "Inclui o nome da pasta onde o comando roda.",
                         ignore: "Ignorar também", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Nomes de programas separados por vírgulas. Editores, paginadores, ssh, top, tail -f, REPLs, servidores de desenvolvimento e claude ficam sempre de fora.",
                         hook: "Hook do shell",
                         hookCaption: "Algumas linhas em ~/.zshrc avisam o Zenith quando um comando começa e termina. Usam só comandos internos do shell, não imprimem nada e ignoram linhas digitadas com espaço no início.",
                         install: "Instalar hook do shell", copy: "Copiar trecho", copied: "Copiado", remove: "Remover hook",
                         installed: "Instalado em ~/.zshrc", notInstalled: "Não instalado",
                         otherBuild: "Instalado para outra versão do Zenith. Instale de novo para usar esta.",
                         damaged: "~/.zshrc tem um bloco do Zenith incompleto. Corrija-o manualmente.",
                         lastEvent: "Último comando %@", noEvents: "Nenhum comando visto ainda",
                         newTab: "Abra uma nova aba do terminal para aplicar a mudança.",
                         confirmTitle: "Adicionar o hook do shell a ~/.zshrc?",
                         confirmMessage: "O Zenith adiciona este bloco ao fim de ~/.zshrc. Nada mais no arquivo muda.",
                         add: "Adicionar", cancel: "Cancelar", editFailed: "Não foi possível atualizar ~/.zshrc.",
                         running: "Em execução", succeeded: "Concluído", failed: "Falhou")
        case .tr:
            return .init(activityTitle: "Terminal", section: "Terminal komutları",
                         toggle: "Komut etkinliği",
                         toggleCaption: "zsh’de bir süre çalışan bir komut, kapalı adada süresiyle görünür; bitince ✓ ya da ✗ gösterir. Yalnızca programın adı görünür, argümanları asla.",
                         showAfter: "Şu süreden sonra göster", seconds: "%d sn",
                         showFolder: "Klasörü göster",
                         showFolderCaption: "Komutun çalıştığı klasörün adını ekler.",
                         ignore: "Bunları da yok say", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Virgülle ayrılmış program adları. Düzenleyiciler, sayfalayıcılar, ssh, top, tail -f, REPL’ler, geliştirme sunucuları ve claude her zaman dışarıda kalır.",
                         hook: "Kabuk kancası",
                         hookCaption: "~/.zshrc içindeki birkaç satır, bir komut başlayıp bittiğinde Zenith’e haber verir. Yalnızca kabuk yerleşiklerini kullanır, hiçbir şey yazdırmaz ve başında boşluk olan satırları atlar.",
                         install: "Kabuk kancasını kur", copy: "Parçacığı kopyala", copied: "Kopyalandı", remove: "Kancayı kaldır",
                         installed: "~/.zshrc içine kuruldu", notInstalled: "Kurulu değil",
                         otherBuild: "Başka bir Zenith derlemesi için kurulu. Bunu kullanmak için yeniden kur.",
                         damaged: "~/.zshrc içinde yarım kalmış bir Zenith bloğu var. Elle düzelt.",
                         lastEvent: "Son komut %@", noEvents: "Henüz komut görülmedi",
                         newTab: "Değişikliğin geçerli olması için yeni bir terminal sekmesi aç.",
                         confirmTitle: "Kabuk kancası ~/.zshrc dosyasına eklensin mi?",
                         confirmMessage: "Zenith bu bloğu ~/.zshrc dosyasının sonuna ekler. Dosyada başka hiçbir şey değişmez.",
                         add: "Ekle", cancel: "Vazgeç", editFailed: "~/.zshrc güncellenemedi.",
                         running: "Çalışıyor", succeeded: "Başarılı", failed: "Başarısız")
        case .ru:
            return .init(activityTitle: "Терминал", section: "Команды терминала",
                         toggle: "Активность команд",
                         toggleCaption: "Долгая команда в zsh появляется на закрытом острове со временем выполнения, а по завершении — с ✓ или ✗. Показывается только имя программы, без аргументов.",
                         showAfter: "Показывать через", seconds: "%d с",
                         showFolder: "Показывать папку",
                         showFolderCaption: "Добавляет имя папки, в которой выполняется команда.",
                         ignore: "Также игнорировать", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Имена программ через запятую. Редакторы, пейджеры, ssh, top, tail -f, REPL, серверы разработки и claude не показываются никогда.",
                         hook: "Хук оболочки",
                         hookCaption: "Несколько строк в ~/.zshrc сообщают Zenith, когда команда начинается и заканчивается. Они используют только встроенные команды оболочки, ничего не выводят и пропускают строки, начинающиеся с пробела.",
                         install: "Установить хук", copy: "Скопировать фрагмент", copied: "Скопировано", remove: "Удалить хук",
                         installed: "Установлен в ~/.zshrc", notInstalled: "Не установлен",
                         otherBuild: "Установлен для другой сборки Zenith. Установите снова, чтобы использовать эту.",
                         damaged: "В ~/.zshrc есть незавершённый блок Zenith. Исправьте его вручную.",
                         lastEvent: "Последняя команда %@", noEvents: "Команд пока не было",
                         newTab: "Откройте новую вкладку терминала, чтобы изменение вступило в силу.",
                         confirmTitle: "Добавить хук оболочки в ~/.zshrc?",
                         confirmMessage: "Zenith добавит этот блок в конец ~/.zshrc. Больше в файле ничего не изменится.",
                         add: "Добавить", cancel: "Отменить", editFailed: "Не удалось обновить ~/.zshrc.",
                         running: "Выполняется", succeeded: "Успешно", failed: "Ошибка")
        case .es:
            return .init(activityTitle: "Terminal", section: "Comandos de Terminal",
                         toggle: "Actividad de comandos",
                         toggleCaption: "Un comando que tarda en zsh aparece en la isla cerrada con su tiempo y, al terminar, con ✓ o ✗. Solo se muestra el nombre del programa, nunca sus argumentos.",
                         showAfter: "Mostrar tras", seconds: "%d s",
                         showFolder: "Mostrar carpeta",
                         showFolderCaption: "Añade el nombre de la carpeta donde se ejecuta el comando.",
                         ignore: "Ignorar también", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Nombres de programas separados por comas. Editores, paginadores, ssh, top, tail -f, REPL, servidores de desarrollo y claude siempre quedan fuera.",
                         hook: "Hook de la shell",
                         hookCaption: "Unas pocas líneas en ~/.zshrc avisan a Zenith cuando un comando empieza y termina. Solo usan órdenes internas de la shell, no imprimen nada y omiten las líneas escritas con un espacio delante.",
                         install: "Instalar hook de la shell", copy: "Copiar fragmento", copied: "Copiado", remove: "Quitar hook",
                         installed: "Instalado en ~/.zshrc", notInstalled: "No instalado",
                         otherBuild: "Instalado para otra compilación de Zenith. Instálalo de nuevo para usar esta.",
                         damaged: "~/.zshrc tiene un bloque de Zenith incompleto. Corrígelo a mano.",
                         lastEvent: "Último comando %@", noEvents: "Aún no se ha visto ningún comando",
                         newTab: "Abre una pestaña nueva de la terminal para aplicar el cambio.",
                         confirmTitle: "¿Añadir el hook de la shell a ~/.zshrc?",
                         confirmMessage: "Zenith añade este bloque al final de ~/.zshrc. Nada más del archivo cambia.",
                         add: "Añadir", cancel: "Cancelar", editFailed: "No se pudo actualizar ~/.zshrc.",
                         running: "En curso", succeeded: "Correcto", failed: "Falló")
        case .sk:
            return .init(activityTitle: "Terminál", section: "Príkazy terminálu",
                         toggle: "Aktivita príkazov",
                         toggleCaption: "Príkaz, ktorý v zsh beží dlhšie, sa zobrazí v zatvorenom ostrove s časom a po skončení s ✓ alebo ✗. Zobrazí sa len názov programu, nikdy jeho argumenty.",
                         showAfter: "Zobraziť po", seconds: "%d s",
                         showFolder: "Zobraziť priečinok",
                         showFolderCaption: "Pridá názov priečinka, v ktorom príkaz beží.",
                         ignore: "Ignorovať aj", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Názvy programov oddelené čiarkami. Editory, stránkovače, ssh, top, tail -f, REPL, vývojové servery a claude sa nezobrazujú nikdy.",
                         hook: "Hook shellu",
                         hookCaption: "Niekoľko riadkov v ~/.zshrc oznámi Zenithu, kedy príkaz začne a skončí. Používajú len vstavané príkazy shellu, nič nevypisujú a vynechajú riadky začínajúce medzerou.",
                         install: "Nainštalovať hook shellu", copy: "Kopírovať úryvok", copied: "Skopírované", remove: "Odstrániť hook",
                         installed: "Nainštalovaný v ~/.zshrc", notInstalled: "Nenainštalovaný",
                         otherBuild: "Nainštalovaný pre inú zostavu Zenithu. Nainštalujte znova, ak chcete použiť túto.",
                         damaged: "~/.zshrc obsahuje nedokončený blok Zenithu. Opravte ho ručne.",
                         lastEvent: "Posledný príkaz %@", noEvents: "Zatiaľ žiadne príkazy",
                         newTab: "Zmena sa prejaví v novej karte terminálu.",
                         confirmTitle: "Pridať hook shellu do ~/.zshrc?",
                         confirmMessage: "Zenith pridá tento blok na koniec ~/.zshrc. Nič iné sa v súbore nezmení.",
                         add: "Pridať", cancel: "Zrušiť", editFailed: "~/.zshrc sa nepodarilo upraviť.",
                         running: "Beží", succeeded: "Úspešné", failed: "Zlyhalo")
        case .de:
            return .init(activityTitle: "Terminal", section: "Terminal-Befehle",
                         toggle: "Befehlsaktivität",
                         toggleCaption: "Ein Befehl, der in zsh länger läuft, erscheint in der geschlossenen Insel mit seiner Zeit und am Ende mit ✓ oder ✗. Nur der Name des Programms wird gezeigt, nie seine Argumente.",
                         showAfter: "Zeigen nach", seconds: "%d s",
                         showFolder: "Ordner zeigen",
                         showFolderCaption: "Ergänzt den Namen des Ordners, in dem der Befehl läuft.",
                         ignore: "Auch ignorieren", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Programmnamen, durch Kommas getrennt. Editoren, Pager, ssh, top, tail -f, REPLs, Entwicklungsserver und claude bleiben immer außen vor.",
                         hook: "Shell-Hook",
                         hookCaption: "Ein paar Zeilen in ~/.zshrc melden Zenith, wann ein Befehl beginnt und endet. Sie nutzen nur Shell-Builtins, geben nichts aus und überspringen Zeilen, die mit einem Leerzeichen beginnen.",
                         install: "Shell-Hook installieren", copy: "Snippet kopieren", copied: "Kopiert", remove: "Hook entfernen",
                         installed: "In ~/.zshrc installiert", notInstalled: "Nicht installiert",
                         otherBuild: "Für einen anderen Zenith-Build installiert. Erneut installieren, um diesen zu nutzen.",
                         damaged: "~/.zshrc enthält einen unvollständigen Zenith-Block. Bitte von Hand korrigieren.",
                         lastEvent: "Letzter Befehl %@", noEvents: "Noch keine Befehle gesehen",
                         newTab: "Öffne einen neuen Terminal-Tab, damit die Änderung greift.",
                         confirmTitle: "Shell-Hook zu ~/.zshrc hinzufügen?",
                         confirmMessage: "Zenith hängt diesen Block an das Ende von ~/.zshrc an. Sonst ändert sich nichts an der Datei.",
                         add: "Hinzufügen", cancel: "Abbrechen", editFailed: "~/.zshrc konnte nicht aktualisiert werden.",
                         running: "Läuft", succeeded: "Erfolgreich", failed: "Fehlgeschlagen")
        case .fr:
            return .init(activityTitle: "Terminal", section: "Commandes du Terminal",
                         toggle: "Activité des commandes",
                         toggleCaption: "Une commande qui dure dans zsh s’affiche dans l’île fermée avec son temps, puis avec ✓ ou ✗ à la fin. Seul le nom du programme apparaît, jamais ses arguments.",
                         showAfter: "Afficher après", seconds: "%d s",
                         showFolder: "Afficher le dossier",
                         showFolderCaption: "Ajoute le nom du dossier où la commande s’exécute.",
                         ignore: "Ignorer aussi", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Noms de programmes séparés par des virgules. Les éditeurs, pagers, ssh, top, tail -f, REPL, serveurs de développement et claude sont toujours exclus.",
                         hook: "Hook du shell",
                         hookCaption: "Quelques lignes dans ~/.zshrc indiquent à Zenith quand une commande commence et se termine. Elles n’utilisent que des commandes internes du shell, n’affichent rien et ignorent les lignes tapées avec une espace au début.",
                         install: "Installer le hook du shell", copy: "Copier l’extrait", copied: "Copié", remove: "Retirer le hook",
                         installed: "Installé dans ~/.zshrc", notInstalled: "Non installé",
                         otherBuild: "Installé pour une autre version de Zenith. Réinstallez-le pour utiliser celle-ci.",
                         damaged: "~/.zshrc contient un bloc Zenith incomplet. Corrigez-le à la main.",
                         lastEvent: "Dernière commande %@", noEvents: "Aucune commande vue pour l’instant",
                         newTab: "Ouvrez un nouvel onglet de terminal pour appliquer le changement.",
                         confirmTitle: "Ajouter le hook du shell à ~/.zshrc\u{00A0}?",
                         confirmMessage: "Zenith ajoute ce bloc à la fin de ~/.zshrc. Rien d’autre ne change dans le fichier.",
                         add: "Ajouter", cancel: "Annuler", editFailed: "Impossible de mettre à jour ~/.zshrc.",
                         running: "En cours", succeeded: "Réussi", failed: "Échec")
        case .it:
            return .init(activityTitle: "Terminale", section: "Comandi del Terminale",
                         toggle: "Attività dei comandi",
                         toggleCaption: "Un comando che dura a lungo in zsh appare nell’isola chiusa con il suo tempo e, alla fine, con ✓ o ✗. Si vede solo il nome del programma, mai i suoi argomenti.",
                         showAfter: "Mostra dopo", seconds: "%d s",
                         showFolder: "Mostra cartella",
                         showFolderCaption: "Aggiunge il nome della cartella in cui gira il comando.",
                         ignore: "Ignora anche", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Nomi di programmi separati da virgole. Editor, pager, ssh, top, tail -f, REPL, server di sviluppo e claude restano sempre esclusi.",
                         hook: "Hook della shell",
                         hookCaption: "Poche righe in ~/.zshrc dicono a Zenith quando un comando inizia e finisce. Usano solo comandi interni della shell, non stampano nulla e saltano le righe digitate con uno spazio iniziale.",
                         install: "Installa hook della shell", copy: "Copia snippet", copied: "Copiato", remove: "Rimuovi hook",
                         installed: "Installato in ~/.zshrc", notInstalled: "Non installato",
                         otherBuild: "Installato per un’altra build di Zenith. Installalo di nuovo per usare questa.",
                         damaged: "~/.zshrc contiene un blocco Zenith incompleto. Correggilo a mano.",
                         lastEvent: "Ultimo comando %@", noEvents: "Nessun comando visto finora",
                         newTab: "Apri una nuova scheda del terminale per applicare la modifica.",
                         confirmTitle: "Aggiungere l’hook della shell a ~/.zshrc?",
                         confirmMessage: "Zenith aggiunge questo blocco alla fine di ~/.zshrc. Nient’altro cambia nel file.",
                         add: "Aggiungi", cancel: "Annulla", editFailed: "Impossibile aggiornare ~/.zshrc.",
                         running: "In corso", succeeded: "Riuscito", failed: "Non riuscito")
        case .ja:
            return .init(activityTitle: "ターミナル", section: "ターミナルのコマンド",
                         toggle: "コマンドのアクティビティ",
                         toggleCaption: "zshで時間のかかるコマンドが、閉じたアイランドに経過時間付きで表示され、終わると✓か✗が出ます。表示されるのはプログラム名だけで、引数は表示されません。",
                         showAfter: "表示までの時間", seconds: "%d秒",
                         showFolder: "フォルダを表示",
                         showFolderCaption: "コマンドを実行しているフォルダの名前を添えます。",
                         ignore: "ほかに無視する", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "プログラム名をカンマで区切って入力します。エディタ、ページャ、ssh、top、tail -f、REPL、開発サーバ、claudeは常に除外されます。",
                         hook: "シェルフック",
                         hookCaption: "~/.zshrcの数行が、コマンドの開始と終了をZenithに伝えます。シェルの組み込みコマンドだけを使い、何も出力せず、先頭にスペースを付けて入力した行は記録しません。",
                         install: "シェルフックをインストール", copy: "スニペットをコピー", copied: "コピーしました", remove: "フックを削除",
                         installed: "~/.zshrcにインストール済み", notInstalled: "未インストール",
                         otherBuild: "別のZenithビルド用にインストールされています。このビルドで使うには再インストールしてください。",
                         damaged: "~/.zshrcに不完全なZenithブロックがあります。手動で修正してください。",
                         lastEvent: "最後のコマンド：%@", noEvents: "まだコマンドを受け取っていません",
                         newTab: "変更を反映するには、ターミナルで新しいタブを開いてください。",
                         confirmTitle: "シェルフックを~/.zshrcに追加しますか？",
                         confirmMessage: "Zenithはこのブロックを~/.zshrcの末尾に追加します。ファイルのほかの部分は変わりません。",
                         add: "追加", cancel: "キャンセル", editFailed: "~/.zshrcを更新できませんでした。",
                         running: "実行中", succeeded: "成功", failed: "失敗")
        case .ko:
            return .init(activityTitle: "터미널", section: "터미널 명령",
                         toggle: "명령 활동",
                         toggleCaption: "zsh에서 오래 걸리는 명령이 닫힌 아일랜드에 경과 시간과 함께 표시되고, 끝나면 ✓ 또는 ✗가 나타납니다. 프로그램 이름만 표시되며 인수는 절대 표시되지 않습니다.",
                         showAfter: "표시까지", seconds: "%d초",
                         showFolder: "폴더 표시",
                         showFolderCaption: "명령이 실행되는 폴더 이름을 함께 표시합니다.",
                         ignore: "추가로 무시", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "쉼표로 구분한 프로그램 이름입니다. 편집기, 페이저, ssh, top, tail -f, REPL, 개발 서버, claude는 항상 제외됩니다.",
                         hook: "셸 훅",
                         hookCaption: "~/.zshrc의 몇 줄이 명령의 시작과 끝을 Zenith에 알려 줍니다. 셸 내장 명령만 사용하고, 아무것도 출력하지 않으며, 공백으로 시작하는 줄은 건너뜁니다.",
                         install: "셸 훅 설치", copy: "스니펫 복사", copied: "복사됨", remove: "훅 제거",
                         installed: "~/.zshrc에 설치됨", notInstalled: "설치되지 않음",
                         otherBuild: "다른 Zenith 빌드용으로 설치되어 있습니다. 이 빌드를 사용하려면 다시 설치하세요.",
                         damaged: "~/.zshrc에 끝나지 않은 Zenith 블록이 있습니다. 직접 수정하세요.",
                         lastEvent: "마지막 명령 %@", noEvents: "아직 받은 명령이 없습니다",
                         newTab: "변경 사항을 적용하려면 새 터미널 탭을 여세요.",
                         confirmTitle: "~/.zshrc에 셸 훅을 추가할까요?",
                         confirmMessage: "Zenith가 이 블록을 ~/.zshrc 끝에 추가합니다. 파일의 다른 부분은 바뀌지 않습니다.",
                         add: "추가", cancel: "취소", editFailed: "~/.zshrc를 업데이트할 수 없습니다.",
                         running: "실행 중", succeeded: "성공", failed: "실패")
        case .uk:
            return .init(activityTitle: "Термінал", section: "Команди термінала",
                         toggle: "Активність команд",
                         toggleCaption: "Довга команда в zsh з’являється на закритому острівці з часом виконання, а після завершення — з ✓ або ✗. Показується лише назва програми, без аргументів.",
                         showAfter: "Показувати через", seconds: "%d с",
                         showFolder: "Показувати папку",
                         showFolderCaption: "Додає назву папки, у якій виконується команда.",
                         ignore: "Також ігнорувати", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "Назви програм через кому. Редактори, пейджери, ssh, top, tail -f, REPL, сервери розробки й claude не показуються ніколи.",
                         hook: "Хук оболонки",
                         hookCaption: "Кілька рядків у ~/.zshrc повідомляють Zenith, коли команда починається й закінчується. Вони використовують лише вбудовані команди оболонки, нічого не виводять і пропускають рядки, що починаються з пробілу.",
                         install: "Установити хук", copy: "Скопіювати фрагмент", copied: "Скопійовано", remove: "Видалити хук",
                         installed: "Установлено в ~/.zshrc", notInstalled: "Не встановлено",
                         otherBuild: "Установлено для іншої збірки Zenith. Установіть знову, щоб використовувати цю.",
                         damaged: "У ~/.zshrc є незавершений блок Zenith. Виправте його вручну.",
                         lastEvent: "Остання команда %@", noEvents: "Команд ще не було",
                         newTab: "Відкрийте нову вкладку термінала, щоб зміна набула чинності.",
                         confirmTitle: "Додати хук оболонки до ~/.zshrc?",
                         confirmMessage: "Zenith додасть цей блок у кінець ~/.zshrc. Більше нічого у файлі не зміниться.",
                         add: "Додати", cancel: "Скасувати", editFailed: "Не вдалося оновити ~/.zshrc.",
                         running: "Виконується", succeeded: "Успішно", failed: "Помилка")
        case .zhHans:
            return .init(activityTitle: "终端", section: "终端命令",
                         toggle: "命令活动",
                         toggleCaption: "在 zsh 中运行较久的命令会显示在收起的岛上并计时，结束时显示 ✓ 或 ✗。只显示程序名，从不显示参数。",
                         showAfter: "显示时机", seconds: "%d 秒",
                         showFolder: "显示文件夹",
                         showFolderCaption: "附上命令所在文件夹的名称。",
                         ignore: "另外忽略", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "用逗号分隔的程序名。编辑器、分页器、ssh、top、tail -f、REPL、开发服务器和 claude 始终不显示。",
                         hook: "Shell 钩子",
                         hookCaption: "~/.zshrc 中的几行会在命令开始和结束时通知 Zenith。它们只使用 shell 内建命令，不输出任何内容，并跳过以空格开头的输入行。",
                         install: "安装 Shell 钩子", copy: "拷贝代码片段", copied: "已拷贝", remove: "移除钩子",
                         installed: "已安装到 ~/.zshrc", notInstalled: "未安装",
                         otherBuild: "已为另一个 Zenith 版本安装。重新安装即可用于当前版本。",
                         damaged: "~/.zshrc 中有不完整的 Zenith 代码块，请手动修复。",
                         lastEvent: "上一条命令：%@", noEvents: "尚未收到命令",
                         newTab: "打开新的终端标签页后更改才会生效。",
                         confirmTitle: "要将 Shell 钩子添加到 ~/.zshrc 吗？",
                         confirmMessage: "Zenith 会将此代码块添加到 ~/.zshrc 末尾，文件的其他内容不会改变。",
                         add: "添加", cancel: "取消", editFailed: "无法更新 ~/.zshrc。",
                         running: "运行中", succeeded: "成功", failed: "失败")
        case .zhTW:
            return .init(activityTitle: "終端機", section: "終端機指令",
                         toggle: "指令動態",
                         toggleCaption: "在 zsh 中執行較久的指令會顯示在收合的島上並計時，結束時顯示 ✓ 或 ✗。只顯示程式名稱，絕不顯示參數。",
                         showAfter: "顯示時機", seconds: "%d 秒",
                         showFolder: "顯示檔案夾",
                         showFolderCaption: "附上指令所在檔案夾的名稱。",
                         ignore: "另外忽略", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "以逗號分隔的程式名稱。編輯器、分頁器、ssh、top、tail -f、REPL、開發伺服器和 claude 一律不顯示。",
                         hook: "Shell 掛鉤",
                         hookCaption: "~/.zshrc 中的幾行會在指令開始與結束時通知 Zenith。它們只使用 shell 內建指令，不輸出任何內容，並略過以空格開頭的輸入行。",
                         install: "安裝 Shell 掛鉤", copy: "拷貝程式碼片段", copied: "已拷貝", remove: "移除掛鉤",
                         installed: "已安裝到 ~/.zshrc", notInstalled: "未安裝",
                         otherBuild: "已為另一個 Zenith 版本安裝。重新安裝即可用於目前的版本。",
                         damaged: "~/.zshrc 中有不完整的 Zenith 區塊，請手動修正。",
                         lastEvent: "上一個指令：%@", noEvents: "尚未收到指令",
                         newTab: "打開新的終端機標籤頁後變更才會生效。",
                         confirmTitle: "要將 Shell 掛鉤加入 ~/.zshrc 嗎？",
                         confirmMessage: "Zenith 會將此區塊加到 ~/.zshrc 結尾，檔案的其他內容不會改變。",
                         add: "加入", cancel: "取消", editFailed: "無法更新 ~/.zshrc。",
                         running: "執行中", succeeded: "成功", failed: "失敗")
        case .zhHK:
            return .init(activityTitle: "終端機", section: "終端機指令",
                         toggle: "指令動態",
                         toggleCaption: "在 zsh 中執行較久的指令會顯示在收合的島上並計時，完成時顯示 ✓ 或 ✗。只顯示程式名稱，絕不顯示參數。",
                         showAfter: "顯示時機", seconds: "%d 秒",
                         showFolder: "顯示資料夾",
                         showFolderCaption: "附上指令所在資料夾的名稱。",
                         ignore: "另外忽略", ignorePlaceholder: "make, terraform",
                         ignoreCaption: "以逗號分隔的程式名稱。編輯器、分頁器、ssh、top、tail -f、REPL、開發伺服器和 claude 一律不顯示。",
                         hook: "Shell 掛鈎",
                         hookCaption: "~/.zshrc 中的幾行會在指令開始與結束時通知 Zenith。它們只使用 shell 內建指令，不輸出任何內容，並略過以空格開頭的輸入行。",
                         install: "安裝 Shell 掛鈎", copy: "拷貝程式碼片段", copied: "已拷貝", remove: "移除掛鈎",
                         installed: "已安裝到 ~/.zshrc", notInstalled: "未安裝",
                         otherBuild: "已為另一個 Zenith 版本安裝。重新安裝即可用於目前的版本。",
                         damaged: "~/.zshrc 中有不完整的 Zenith 區塊，請手動修正。",
                         lastEvent: "上一個指令：%@", noEvents: "尚未收到指令",
                         newTab: "開啟新的終端機分頁後變更才會生效。",
                         confirmTitle: "要將 Shell 掛鈎加入 ~/.zshrc 嗎？",
                         confirmMessage: "Zenith 會將此區塊加到 ~/.zshrc 結尾，檔案的其他內容不會改變。",
                         add: "加入", cancel: "取消", editFailed: "無法更新 ~/.zshrc。",
                         running: "執行中", succeeded: "成功", failed: "失敗")
        }
    }
}

struct ZenithPhotoActionsStrings {
    let toggle: String
    let caption: String
    let transform: String
    let removeBackground: String
    let convert: String
    let resize: String
    let compress: String
    let strip: String
    let format: String
    let longEdge: String
    let quality: String
    let original: String
    let stripDetail: String
    let alsoStrip: String
    let cutoutDetail: String
    let apply: String
    let cancel: String
    let close: String
    let again: String
    let processing: String
    let done: String
    let revealInFinder: String
    let copy: String
    let copied: String
    let noSubject: String
    let failed: String
    let skipped: String
    let busy: String
    let dragHint: String
}

extension ZenithStrings {
    /// The island's photo actions (NotchPhotoActionsSupport) and their switch in Shelf settings.
    static func photoActions(_ language: AppLanguage) -> ZenithPhotoActionsStrings {
        switch language {
        case .enUS:
            return .init(toggle: "Photo actions in the Dynamic Island",
                         caption: "Drop images on Transform to convert, resize, compress or strip their metadata, or one image on Remove Background for a transparent PNG of its subject. Results are saved next to the originals and added to the shelf. Everything runs on this Mac.",
                         transform: "Transform",
                         removeBackground: "Remove Background",
                         convert: "Convert",
                         resize: "Resize",
                         compress: "Compress",
                         strip: "Strip",
                         format: "Format",
                         longEdge: "Long edge",
                         quality: "Quality",
                         original: "Original",
                         stripDetail: "Removes EXIF and GPS: camera, lens, location and capture details. The picture itself isn’t re-encoded.",
                         alsoStrip: "Strip EXIF",
                         cutoutDetail: "A transparent PNG of the subject, made on this Mac.",
                         apply: "Apply",
                         cancel: "Cancel",
                         close: "Close",
                         again: "Start over",
                         processing: "Processing",
                         done: "Done",
                         revealInFinder: "Reveal in Finder",
                         copy: "Copy",
                         copied: "Copied",
                         noSubject: "No subject found in this image.",
                         failed: "Couldn’t process this image.",
                         skipped: "Skipped",
                         busy: "Busy",
                         dragHint: "Drag the result anywhere")
        case .ptBR:
            return .init(toggle: "Ações de foto na Dynamic Island",
                         caption: "Solte imagens em Transformar para converter, redimensionar, comprimir ou remover os metadados, ou uma imagem em Remover fundo para um PNG transparente do objeto. Os resultados são salvos ao lado dos originais e adicionados à prateleira. Tudo é feito neste Mac.",
                         transform: "Transformar",
                         removeBackground: "Remover fundo",
                         convert: "Converter",
                         resize: "Redimensionar",
                         compress: "Comprimir",
                         strip: "Limpar",
                         format: "Formato",
                         longEdge: "Lado maior",
                         quality: "Qualidade",
                         original: "Original",
                         stripDetail: "Remove EXIF e GPS: câmera, lente, local e detalhes da captura. A imagem em si não é recodificada.",
                         alsoStrip: "Sem EXIF",
                         cutoutDetail: "Um PNG transparente do objeto, feito neste Mac.",
                         apply: "Aplicar",
                         cancel: "Cancelar",
                         close: "Fechar",
                         again: "Recomeçar",
                         processing: "Processando",
                         done: "Pronto",
                         revealInFinder: "Mostrar no Finder",
                         copy: "Copiar",
                         copied: "Copiado",
                         noSubject: "Nenhum objeto encontrado nesta imagem.",
                         failed: "Não foi possível processar esta imagem.",
                         skipped: "Ignoradas",
                         busy: "Ocupado",
                         dragHint: "Arraste o resultado para onde quiser")
        case .tr:
            return .init(toggle: "Dynamic Island’da fotoğraf işlemleri",
                         caption: "Görselleri dönüştürmek, yeniden boyutlandırmak, sıkıştırmak veya meta verilerini silmek için Dönüştür’e, konusunun saydam PNG’si için tek bir görseli Arka Planı Kaldır’a bırak. Sonuçlar orijinallerin yanına kaydedilir ve rafa eklenir. Her şey bu Mac’te çalışır.",
                         transform: "Dönüştür",
                         removeBackground: "Arka Planı Kaldır",
                         convert: "Biçim değiştir",
                         resize: "Boyutlandır",
                         compress: "Sıkıştır",
                         strip: "Temizle",
                         format: "Biçim",
                         longEdge: "Uzun kenar",
                         quality: "Kalite",
                         original: "Orijinal",
                         stripDetail: "EXIF ve GPS’i siler: kamera, lens, konum ve çekim bilgileri. Görüntünün kendisi yeniden kodlanmaz.",
                         alsoStrip: "EXIF’i sil",
                         cutoutDetail: "Konunun saydam bir PNG’si, bu Mac’te hazırlanır.",
                         apply: "Uygula",
                         cancel: "Vazgeç",
                         close: "Kapat",
                         again: "Baştan başla",
                         processing: "İşleniyor",
                         done: "Bitti",
                         revealInFinder: "Finder’da göster",
                         copy: "Kopyala",
                         copied: "Kopyalandı",
                         noSubject: "Bu görselde konu bulunamadı.",
                         failed: "Bu görsel işlenemedi.",
                         skipped: "Atlandı",
                         busy: "Meşgul",
                         dragHint: "Sonucu istediğin yere sürükle")
        case .ru:
            return .init(toggle: "Действия с фото в Dynamic Island",
                         caption: "Перетащите изображения на «Преобразовать», чтобы сменить формат, размер, сжать их или удалить метаданные, или одно изображение на «Удалить фон», чтобы получить PNG объекта с прозрачным фоном. Результаты сохраняются рядом с оригиналами и добавляются на полку. Всё выполняется на этом Mac.",
                         transform: "Преобразовать",
                         removeBackground: "Удалить фон",
                         convert: "Формат",
                         resize: "Размер",
                         compress: "Сжать",
                         strip: "Очистить",
                         format: "Формат",
                         longEdge: "Длинная сторона",
                         quality: "Качество",
                         original: "Исходный",
                         stripDetail: "Удаляет EXIF и GPS: камеру, объектив, место и данные съёмки. Само изображение не перекодируется.",
                         alsoStrip: "Без EXIF",
                         cutoutDetail: "PNG объекта с прозрачным фоном, создаётся на этом Mac.",
                         apply: "Применить",
                         cancel: "Отменить",
                         close: "Закрыть",
                         again: "Заново",
                         processing: "Обработка",
                         done: "Готово",
                         revealInFinder: "Показать в Finder",
                         copy: "Копировать",
                         copied: "Скопировано",
                         noSubject: "На этом изображении не найден объект.",
                         failed: "Не удалось обработать изображение.",
                         skipped: "Пропущено",
                         busy: "Занято",
                         dragHint: "Перетащите результат куда угодно")
        case .es:
            return .init(toggle: "Acciones de fotos en la Dynamic Island",
                         caption: "Suelta imágenes en Transformar para convertirlas, redimensionarlas, comprimirlas o quitarles los metadatos, o una imagen en Quitar fondo para obtener un PNG transparente del sujeto. Los resultados se guardan junto a los originales y se añaden al estante. Todo se hace en este Mac.",
                         transform: "Transformar",
                         removeBackground: "Quitar fondo",
                         convert: "Convertir",
                         resize: "Redimensionar",
                         compress: "Comprimir",
                         strip: "Limpiar",
                         format: "Formato",
                         longEdge: "Lado largo",
                         quality: "Calidad",
                         original: "Original",
                         stripDetail: "Quita EXIF y GPS: cámara, objetivo, ubicación y datos de la toma. La imagen en sí no se vuelve a codificar.",
                         alsoStrip: "Sin EXIF",
                         cutoutDetail: "Un PNG transparente del sujeto, hecho en este Mac.",
                         apply: "Aplicar",
                         cancel: "Cancelar",
                         close: "Cerrar",
                         again: "Empezar de nuevo",
                         processing: "Procesando",
                         done: "Listo",
                         revealInFinder: "Mostrar en Finder",
                         copy: "Copiar",
                         copied: "Copiado",
                         noSubject: "No se encontró ningún sujeto en esta imagen.",
                         failed: "No se pudo procesar esta imagen.",
                         skipped: "Omitidas",
                         busy: "Ocupado",
                         dragHint: "Arrastra el resultado adonde quieras")
        case .sk:
            return .init(toggle: "Akcie s fotkami v Dynamic Island",
                         caption: "Pustite obrázky na Transformovať, aby ste ich previedli, zmenšili, skomprimovali alebo odstránili metadáta, alebo jeden obrázok na Odstrániť pozadie pre priehľadné PNG objektu. Výsledky sa uložia vedľa originálov a pridajú sa na policu. Všetko beží na tomto Macu.",
                         transform: "Transformovať",
                         removeBackground: "Odstrániť pozadie",
                         convert: "Previesť",
                         resize: "Zmeniť veľkosť",
                         compress: "Komprimovať",
                         strip: "Vyčistiť",
                         format: "Formát",
                         longEdge: "Dlhšia strana",
                         quality: "Kvalita",
                         original: "Pôvodná",
                         stripDetail: "Odstráni EXIF a GPS: fotoaparát, objektív, polohu a údaje o snímke. Samotný obrázok sa znova nekóduje.",
                         alsoStrip: "Bez EXIF",
                         cutoutDetail: "Priehľadné PNG objektu, vytvorené na tomto Macu.",
                         apply: "Použiť",
                         cancel: "Zrušiť",
                         close: "Zavrieť",
                         again: "Začať znova",
                         processing: "Spracúva sa",
                         done: "Hotovo",
                         revealInFinder: "Ukázať vo Finderi",
                         copy: "Kopírovať",
                         copied: "Skopírované",
                         noSubject: "Na tomto obrázku sa nenašiel žiadny objekt.",
                         failed: "Tento obrázok sa nepodarilo spracovať.",
                         skipped: "Preskočené",
                         busy: "Zaneprázdnené",
                         dragHint: "Výsledok potiahnite kamkoľvek")
        case .de:
            return .init(toggle: "Fotoaktionen in der Dynamic Island",
                         caption: "Lass Bilder auf Umwandeln los, um sie zu konvertieren, zu verkleinern, zu komprimieren oder ihre Metadaten zu entfernen, oder ein Bild auf Hintergrund entfernen für ein transparentes PNG des Motivs. Die Ergebnisse werden neben den Originalen gesichert und zur Ablage hinzugefügt. Alles läuft auf diesem Mac.",
                         transform: "Umwandeln",
                         removeBackground: "Hintergrund entfernen",
                         convert: "Konvertieren",
                         resize: "Skalieren",
                         compress: "Komprimieren",
                         strip: "Bereinigen",
                         format: "Format",
                         longEdge: "Lange Kante",
                         quality: "Qualität",
                         original: "Original",
                         stripDetail: "Entfernt EXIF und GPS: Kamera, Objektiv, Ort und Aufnahmedaten. Das Bild selbst wird nicht neu kodiert.",
                         alsoStrip: "Ohne EXIF",
                         cutoutDetail: "Ein transparentes PNG des Motivs, erstellt auf diesem Mac.",
                         apply: "Anwenden",
                         cancel: "Abbrechen",
                         close: "Schließen",
                         again: "Neu beginnen",
                         processing: "Wird verarbeitet",
                         done: "Fertig",
                         revealInFinder: "Im Finder zeigen",
                         copy: "Kopieren",
                         copied: "Kopiert",
                         noSubject: "In diesem Bild wurde kein Motiv gefunden.",
                         failed: "Dieses Bild konnte nicht verarbeitet werden.",
                         skipped: "Übersprungen",
                         busy: "Beschäftigt",
                         dragHint: "Zieh das Ergebnis, wohin du willst")
        case .fr:
            return .init(toggle: "Actions photo dans la Dynamic Island",
                         caption: "Déposez des images sur Transformer pour les convertir, les redimensionner, les compresser ou retirer leurs métadonnées, ou une image sur Supprimer l’arrière-plan pour obtenir un PNG transparent du sujet. Les résultats sont enregistrés à côté des originaux et ajoutés à l’étagère. Tout se fait sur ce Mac.",
                         transform: "Transformer",
                         removeBackground: "Supprimer l’arrière-plan",
                         convert: "Convertir",
                         resize: "Redimensionner",
                         compress: "Compresser",
                         strip: "Nettoyer",
                         format: "Format",
                         longEdge: "Grand côté",
                         quality: "Qualité",
                         original: "Originale",
                         stripDetail: "Retire l’EXIF et le GPS : appareil, objectif, lieu et données de prise de vue. L’image elle-même n’est pas réencodée.",
                         alsoStrip: "Sans EXIF",
                         cutoutDetail: "Un PNG transparent du sujet, créé sur ce Mac.",
                         apply: "Appliquer",
                         cancel: "Annuler",
                         close: "Fermer",
                         again: "Recommencer",
                         processing: "Traitement",
                         done: "Terminé",
                         revealInFinder: "Afficher dans le Finder",
                         copy: "Copier",
                         copied: "Copié",
                         noSubject: "Aucun sujet trouvé dans cette image.",
                         failed: "Impossible de traiter cette image.",
                         skipped: "Ignorées",
                         busy: "Occupé",
                         dragHint: "Faites glisser le résultat où vous voulez")
        case .it:
            return .init(toggle: "Azioni foto nella Dynamic Island",
                         caption: "Rilascia le immagini su Trasforma per convertirle, ridimensionarle, comprimerle o rimuoverne i metadati, oppure un’immagine su Rimuovi sfondo per un PNG trasparente del soggetto. I risultati vengono salvati accanto agli originali e aggiunti allo scaffale. Tutto avviene su questo Mac.",
                         transform: "Trasforma",
                         removeBackground: "Rimuovi sfondo",
                         convert: "Converti",
                         resize: "Ridimensiona",
                         compress: "Comprimi",
                         strip: "Pulisci",
                         format: "Formato",
                         longEdge: "Lato lungo",
                         quality: "Qualità",
                         original: "Originale",
                         stripDetail: "Rimuove EXIF e GPS: fotocamera, obiettivo, posizione e dati di scatto. L’immagine in sé non viene ricodificata.",
                         alsoStrip: "Senza EXIF",
                         cutoutDetail: "Un PNG trasparente del soggetto, creato su questo Mac.",
                         apply: "Applica",
                         cancel: "Annulla",
                         close: "Chiudi",
                         again: "Ricomincia",
                         processing: "Elaborazione",
                         done: "Fatto",
                         revealInFinder: "Mostra nel Finder",
                         copy: "Copia",
                         copied: "Copiato",
                         noSubject: "Nessun soggetto trovato in questa immagine.",
                         failed: "Impossibile elaborare questa immagine.",
                         skipped: "Saltate",
                         busy: "Occupato",
                         dragHint: "Trascina il risultato dove vuoi")
        case .ja:
            return .init(toggle: "Dynamic Islandの写真アクション",
                         caption: "画像を「変換」にドロップすると、形式の変換、サイズ変更、圧縮、メタデータの削除ができます。1枚の画像を「背景を削除」にドロップすると、被写体の透過PNGを作成します。結果は元のファイルの隣に保存され、シェルフに追加されます。すべてこのMac上で処理されます。",
                         transform: "変換",
                         removeBackground: "背景を削除",
                         convert: "形式",
                         resize: "サイズ",
                         compress: "圧縮",
                         strip: "情報を削除",
                         format: "形式",
                         longEdge: "長辺",
                         quality: "画質",
                         original: "元のサイズ",
                         stripDetail: "EXIFとGPS（カメラ、レンズ、位置情報、撮影情報）を削除します。画像そのものは再エンコードしません。",
                         alsoStrip: "EXIFを削除",
                         cutoutDetail: "被写体の透過PNGを、このMac上で作成します。",
                         apply: "適用",
                         cancel: "キャンセル",
                         close: "閉じる",
                         again: "やり直す",
                         processing: "処理中",
                         done: "完了",
                         revealInFinder: "Finderに表示",
                         copy: "コピー",
                         copied: "コピーしました",
                         noSubject: "この画像に被写体が見つかりません。",
                         failed: "この画像を処理できませんでした。",
                         skipped: "スキップ",
                         busy: "処理中",
                         dragHint: "結果を好きな場所へドラッグ")
        case .ko:
            return .init(toggle: "Dynamic Island 사진 작업",
                         caption: "이미지를 변환에 놓으면 형식 변환, 크기 조절, 압축, 메타데이터 제거를 할 수 있고, 이미지 하나를 배경 제거에 놓으면 피사체의 투명 PNG를 만듭니다. 결과는 원본 옆에 저장되고 선반에 추가됩니다. 모든 작업은 이 Mac에서 처리됩니다.",
                         transform: "변환",
                         removeBackground: "배경 제거",
                         convert: "형식 변환",
                         resize: "크기 조절",
                         compress: "압축",
                         strip: "정보 제거",
                         format: "형식",
                         longEdge: "긴 변",
                         quality: "품질",
                         original: "원본",
                         stripDetail: "EXIF와 GPS(카메라, 렌즈, 위치, 촬영 정보)를 제거합니다. 이미지 자체는 다시 인코딩하지 않습니다.",
                         alsoStrip: "EXIF 제거",
                         cutoutDetail: "피사체의 투명 PNG를 이 Mac에서 만듭니다.",
                         apply: "적용",
                         cancel: "취소",
                         close: "닫기",
                         again: "처음부터",
                         processing: "처리 중",
                         done: "완료",
                         revealInFinder: "Finder에서 보기",
                         copy: "복사",
                         copied: "복사됨",
                         noSubject: "이 이미지에서 피사체를 찾지 못했습니다.",
                         failed: "이 이미지를 처리할 수 없습니다.",
                         skipped: "건너뜀",
                         busy: "사용 중",
                         dragHint: "결과를 원하는 곳으로 드래그")
        case .uk:
            return .init(toggle: "Дії з фото в Dynamic Island",
                         caption: "Перетягніть зображення на «Перетворити», щоб змінити формат, розмір, стиснути їх або видалити метадані, або одне зображення на «Видалити фон», щоб отримати PNG об’єкта з прозорим тлом. Результати зберігаються поруч з оригіналами й додаються на полицю. Усе виконується на цьому Mac.",
                         transform: "Перетворити",
                         removeBackground: "Видалити фон",
                         convert: "Формат",
                         resize: "Розмір",
                         compress: "Стиснути",
                         strip: "Очистити",
                         format: "Формат",
                         longEdge: "Довга сторона",
                         quality: "Якість",
                         original: "Початковий",
                         stripDetail: "Видаляє EXIF і GPS: камеру, об’єктив, місце й дані зйомки. Саме зображення не перекодовується.",
                         alsoStrip: "Без EXIF",
                         cutoutDetail: "PNG об’єкта з прозорим тлом, створюється на цьому Mac.",
                         apply: "Застосувати",
                         cancel: "Скасувати",
                         close: "Закрити",
                         again: "Почати знову",
                         processing: "Обробка",
                         done: "Готово",
                         revealInFinder: "Показати у Finder",
                         copy: "Копіювати",
                         copied: "Скопійовано",
                         noSubject: "На цьому зображенні не знайдено об’єкта.",
                         failed: "Не вдалося обробити зображення.",
                         skipped: "Пропущено",
                         busy: "Зайнято",
                         dragHint: "Перетягніть результат куди завгодно")
        case .zhHans:
            return .init(toggle: "灵动岛中的照片操作",
                         caption: "将图片拖到“转换”可转换格式、调整大小、压缩或移除元数据；将单张图片拖到“移除背景”可得到主体的透明 PNG。结果保存在原图旁边，并添加到储物架。所有处理都在这台 Mac 上完成。",
                         transform: "转换",
                         removeBackground: "移除背景",
                         convert: "格式",
                         resize: "大小",
                         compress: "压缩",
                         strip: "清除信息",
                         format: "格式",
                         longEdge: "长边",
                         quality: "质量",
                         original: "原始",
                         stripDetail: "移除 EXIF 和 GPS：相机、镜头、位置和拍摄信息。图片本身不会重新编码。",
                         alsoStrip: "移除 EXIF",
                         cutoutDetail: "主体的透明 PNG，在这台 Mac 上生成。",
                         apply: "应用",
                         cancel: "取消",
                         close: "关闭",
                         again: "重新开始",
                         processing: "处理中",
                         done: "完成",
                         revealInFinder: "在访达中显示",
                         copy: "拷贝",
                         copied: "已拷贝",
                         noSubject: "此图片中未找到主体。",
                         failed: "无法处理此图片。",
                         skipped: "已跳过",
                         busy: "忙碌",
                         dragHint: "将结果拖到任意位置")
        case .zhTW:
            return .init(toggle: "動態島中的照片操作",
                         caption: "將圖片拖到「轉換」可轉換格式、調整大小、壓縮或移除後設資料；將單張圖片拖到「移除背景」可取得主體的透明 PNG。結果會儲存在原檔旁邊，並加入暫存架。所有處理都在這台 Mac 上完成。",
                         transform: "轉換",
                         removeBackground: "移除背景",
                         convert: "格式",
                         resize: "大小",
                         compress: "壓縮",
                         strip: "清除資訊",
                         format: "格式",
                         longEdge: "長邊",
                         quality: "品質",
                         original: "原始",
                         stripDetail: "移除 EXIF 與 GPS：相機、鏡頭、位置與拍攝資訊。圖片本身不會重新編碼。",
                         alsoStrip: "移除 EXIF",
                         cutoutDetail: "主體的透明 PNG，在這台 Mac 上產生。",
                         apply: "套用",
                         cancel: "取消",
                         close: "關閉",
                         again: "重新開始",
                         processing: "處理中",
                         done: "完成",
                         revealInFinder: "在 Finder 中顯示",
                         copy: "拷貝",
                         copied: "已拷貝",
                         noSubject: "此圖片中找不到主體。",
                         failed: "無法處理此圖片。",
                         skipped: "已略過",
                         busy: "忙碌中",
                         dragHint: "將結果拖到任何地方")
        case .zhHK:
            return .init(toggle: "動態島中的相片操作",
                         caption: "將圖片拖到「轉換」可轉換格式、調整大小、壓縮或移除後設資料；將單張圖片拖到「移除背景」可取得主體的透明 PNG。結果會儲存在原檔旁邊，並加入暫存架。所有處理都在這部 Mac 上完成。",
                         transform: "轉換",
                         removeBackground: "移除背景",
                         convert: "格式",
                         resize: "大小",
                         compress: "壓縮",
                         strip: "清除資料",
                         format: "格式",
                         longEdge: "長邊",
                         quality: "質素",
                         original: "原始",
                         stripDetail: "移除 EXIF 與 GPS：相機、鏡頭、位置與拍攝資料。圖片本身不會重新編碼。",
                         alsoStrip: "移除 EXIF",
                         cutoutDetail: "主體的透明 PNG，在這部 Mac 上產生。",
                         apply: "套用",
                         cancel: "取消",
                         close: "關閉",
                         again: "重新開始",
                         processing: "處理中",
                         done: "完成",
                         revealInFinder: "在 Finder 中顯示",
                         copy: "拷貝",
                         copied: "已拷貝",
                         noSubject: "此圖片中找不到主體。",
                         failed: "無法處理此圖片。",
                         skipped: "已略過",
                         busy: "忙碌中",
                         dragHint: "將結果拖到任何地方")
        }
    }
}
