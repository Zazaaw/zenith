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

// MARK: - Dev servers

/// Zenith fork: dev servers (DevServersService): the island page, its home
/// widget, the notice, the closed island's count and the section's options.
struct ZenithDevServersStrings {
    /// The page, its module, its widget and its live activity.
    let title: String
    /// What the section does, in Settings.
    let summary: String
    let empty: String
    let emptyHint: String
    let open: String
    let copyURL: String
    let copied: String
    let kill: String
    /// The kill button's second question.
    let confirmKill: String
    let stopping: String
    /// Help on a Docker row, which has no Kill.
    let dockerOwned: String
    /// `%@` is the uptime, as in “Running for 12:03”.
    let runningFor: String
    /// The notice's subtitle.
    let started: String
    /// `%@` is a count, as in “3 running”.
    let running: String
    let detect: String
    let detectCaption: String
    let announce: String
    let announceCaption: String
    let indicator: String
    let indicatorCaption: String
    let extraPorts: String
    let extraPortsPlaceholder: String
    let extraNames: String
    let extraNamesPlaceholder: String
    let extrasCaption: String
}

extension ZenithStrings {
    static func devServers(_ language: AppLanguage) -> ZenithDevServersStrings {
        switch language {
        case .enUS:
            return .init(title: "Dev servers",
                         summary: "Lists the dev servers running on this Mac, to open, copy or stop them.",
                         empty: "No dev servers running",
                         emptyHint: "Start one with next dev, vite or php artisan serve and it shows up here.",
                         open: "Open", copyURL: "Copy URL", copied: "Copied", kill: "Kill", confirmKill: "Kill?",
                         stopping: "Stopping…", dockerOwned: "Docker forwards this port. Stop the container in Docker.",
                         runningFor: "Running for %@", started: "New dev server", running: "%@ running",
                         detect: "Detect dev servers",
                         detectCaption: "Reads the same listening ports as Port Manager, only while the page or its widget is on screen unless an option below needs more.",
                         announce: "Announce new servers",
                         announceCaption: "A notice with Open when a dev server starts. A restart of the same project on the same port within 30 seconds stays quiet. Checks about every 10 seconds.",
                         indicator: "Show the count in the closed island",
                         indicatorCaption: "A green dot and how many servers are running, as a live activity.",
                         extraPorts: "Also these ports", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Also these processes", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Listeners on these ports, or from processes with these names, count as dev servers too.")
        case .ptBR:
            return .init(title: "Servidores de dev",
                         summary: "Lista os servidores de desenvolvimento em execução neste Mac, para abrir, copiar ou parar.",
                         empty: "Nenhum servidor de dev em execução",
                         emptyHint: "Inicie um com next dev, vite ou php artisan serve e ele aparece aqui.",
                         open: "Abrir", copyURL: "Copiar URL", copied: "Copiado", kill: "Encerrar", confirmKill: "Encerrar?",
                         stopping: "Parando…", dockerOwned: "O Docker encaminha esta porta. Pare o contêiner no Docker.",
                         runningFor: "Em execução há %@", started: "Novo servidor de dev", running: "%@ em execução",
                         detect: "Detectar servidores de dev",
                         detectCaption: "Lê as mesmas portas em escuta do Gerenciador de portas, só enquanto a página ou o widget estiver na tela, a menos que uma opção abaixo precise de mais.",
                         announce: "Avisar sobre novos servidores",
                         announceCaption: "Um aviso com Abrir quando um servidor de dev inicia. Reiniciar o mesmo projeto na mesma porta em até 30 segundos não gera aviso. Verifica a cada 10 segundos, mais ou menos.",
                         indicator: "Mostrar a contagem na ilha fechada",
                         indicatorCaption: "Um ponto verde e quantos servidores estão rodando, como atividade ao vivo.",
                         extraPorts: "Também estas portas", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Também estes processos", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Escutas nestas portas, ou de processos com estes nomes, também contam como servidores de dev.")
        case .tr:
            return .init(title: "Geliştirme sunucuları",
                         summary: "Bu Mac’te çalışan geliştirme sunucularını listeler; açabilir, kopyalayabilir veya durdurabilirsiniz.",
                         empty: "Çalışan geliştirme sunucusu yok",
                         emptyHint: "next dev, vite veya php artisan serve ile birini başlatın, burada görünür.",
                         open: "Aç", copyURL: "URL’yi kopyala", copied: "Kopyalandı", kill: "Sonlandır", confirmKill: "Sonlandır?",
                         stopping: "Durduruluyor…", dockerOwned: "Bu bağlantı noktasını Docker yönlendiriyor. Konteyneri Docker’dan durdurun.",
                         runningFor: "%@ süredir çalışıyor", started: "Yeni geliştirme sunucusu", running: "%@ çalışıyor",
                         detect: "Geliştirme sunucularını algıla",
                         detectCaption: "Port Yöneticisi ile aynı dinlenen bağlantı noktalarını okur; aşağıdaki bir seçenek daha fazlasını gerektirmedikçe yalnızca sayfa veya widget’ı ekrandayken.",
                         announce: "Yeni sunucuları duyur",
                         announceCaption: "Bir geliştirme sunucusu başladığında Aç düğmeli bir bildirim. Aynı projenin aynı bağlantı noktasında 30 saniye içinde yeniden başlaması sessiz kalır. Yaklaşık 10 saniyede bir kontrol eder.",
                         indicator: "Kapalı adada sayıyı göster",
                         indicatorCaption: "Canlı etkinlik olarak yeşil bir nokta ve kaç sunucunun çalıştığı.",
                         extraPorts: "Ayrıca bu bağlantı noktaları", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Ayrıca bu işlemler", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Bu bağlantı noktalarındaki veya bu adlara sahip işlemlerden gelen dinleyiciler de geliştirme sunucusu sayılır.")
        case .ru:
            return .init(title: "Dev-серверы",
                         summary: "Показывает dev-серверы, запущенные на этом Mac, чтобы открыть, скопировать или остановить их.",
                         empty: "Нет запущенных dev-серверов",
                         emptyHint: "Запустите next dev, vite или php artisan serve, и сервер появится здесь.",
                         open: "Открыть", copyURL: "Скопировать URL", copied: "Скопировано", kill: "Завершить", confirmKill: "Завершить?",
                         stopping: "Останавливается…", dockerOwned: "Этот порт пробрасывает Docker. Остановите контейнер в Docker.",
                         runningFor: "Работает %@", started: "Новый dev-сервер", running: "Запущено: %@",
                         detect: "Находить dev-серверы",
                         detectCaption: "Читает те же прослушиваемые порты, что и Менеджер портов, только пока страница или её виджет на экране, если параметр ниже не требует большего.",
                         announce: "Сообщать о новых серверах",
                         announceCaption: "Уведомление с кнопкой «Открыть», когда запускается dev-сервер. Перезапуск того же проекта на том же порту в течение 30 секунд проходит без уведомления. Проверка примерно раз в 10 секунд.",
                         indicator: "Показывать число в закрытом острове",
                         indicatorCaption: "Зелёная точка и число запущенных серверов как живая активность.",
                         extraPorts: "Также эти порты", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Также эти процессы", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Слушатели на этих портах или процессы с такими именами тоже считаются dev-серверами.")
        case .es:
            return .init(title: "Servidores de desarrollo",
                         summary: "Muestra los servidores de desarrollo que se ejecutan en este Mac para abrirlos, copiarlos o detenerlos.",
                         empty: "No hay servidores de desarrollo en ejecución",
                         emptyHint: "Inicia uno con next dev, vite o php artisan serve y aparecerá aquí.",
                         open: "Abrir", copyURL: "Copiar URL", copied: "Copiado", kill: "Terminar", confirmKill: "¿Terminar?",
                         stopping: "Deteniendo…", dockerOwned: "Docker reenvía este puerto. Detén el contenedor en Docker.",
                         runningFor: "En ejecución desde hace %@", started: "Nuevo servidor de desarrollo", running: "%@ en ejecución",
                         detect: "Detectar servidores de desarrollo",
                         detectCaption: "Lee los mismos puertos en escucha que el Gestor de puertos, solo mientras la página o su widget están en pantalla, salvo que una opción de abajo necesite más.",
                         announce: "Avisar de servidores nuevos",
                         announceCaption: "Un aviso con Abrir cuando se inicia un servidor de desarrollo. Reiniciar el mismo proyecto en el mismo puerto en menos de 30 segundos no avisa. Comprueba cada 10 segundos aproximadamente.",
                         indicator: "Mostrar el número en la isla cerrada",
                         indicatorCaption: "Un punto verde y cuántos servidores se ejecutan, como actividad en vivo.",
                         extraPorts: "También estos puertos", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "También estos procesos", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Lo que escuche en estos puertos, o los procesos con estos nombres, también cuentan como servidores de desarrollo.")
        case .sk:
            return .init(title: "Vývojové servery",
                         summary: "Zobrazuje vývojové servery spustené na tomto Macu, aby ste ich mohli otvoriť, skopírovať alebo zastaviť.",
                         empty: "Nebeží žiadny vývojový server",
                         emptyHint: "Spustite ho cez next dev, vite alebo php artisan serve a zobrazí sa tu.",
                         open: "Otvoriť", copyURL: "Kopírovať URL", copied: "Skopírované", kill: "Ukončiť", confirmKill: "Ukončiť?",
                         stopping: "Zastavuje sa…", dockerOwned: "Tento port presmerúva Docker. Kontajner zastavte v Dockeri.",
                         runningFor: "Beží %@", started: "Nový vývojový server", running: "Beží: %@",
                         detect: "Rozpoznávať vývojové servery",
                         detectCaption: "Číta tie isté počúvajúce porty ako Správca portov, len keď je stránka alebo jej widget na obrazovke, ak niektorá voľba nižšie nepotrebuje viac.",
                         announce: "Oznamovať nové servery",
                         announceCaption: "Oznámenie s tlačidlom Otvoriť, keď sa spustí vývojový server. Reštart toho istého projektu na tom istom porte do 30 sekúnd zostane potichu. Kontroluje približne každých 10 sekúnd.",
                         indicator: "Zobraziť počet v zatvorenom ostrove",
                         indicatorCaption: "Zelená bodka a počet bežiacich serverov ako živá aktivita.",
                         extraPorts: "Aj tieto porty", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Aj tieto procesy", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Poslucháči na týchto portoch alebo procesy s týmito názvami sa tiež počítajú ako vývojové servery.")
        case .de:
            return .init(title: "Dev-Server",
                         summary: "Zeigt die Dev-Server, die auf diesem Mac laufen, zum Öffnen, Kopieren oder Beenden.",
                         empty: "Keine Dev-Server aktiv",
                         emptyHint: "Starte einen mit next dev, vite oder php artisan serve, dann erscheint er hier.",
                         open: "Öffnen", copyURL: "URL kopieren", copied: "Kopiert", kill: "Beenden", confirmKill: "Beenden?",
                         stopping: "Wird beendet…", dockerOwned: "Docker leitet diesen Port weiter. Stoppe den Container in Docker.",
                         runningFor: "Läuft seit %@", started: "Neuer Dev-Server", running: "%@ aktiv",
                         detect: "Dev-Server erkennen",
                         detectCaption: "Liest dieselben offenen Ports wie die Portverwaltung, nur solange die Seite oder ihr Widget sichtbar ist, außer eine Option unten braucht mehr.",
                         announce: "Neue Server melden",
                         announceCaption: "Eine Mitteilung mit Öffnen, wenn ein Dev-Server startet. Ein Neustart desselben Projekts auf demselben Port innerhalb von 30 Sekunden bleibt still. Prüft etwa alle 10 Sekunden.",
                         indicator: "Anzahl in der geschlossenen Insel zeigen",
                         indicatorCaption: "Ein grüner Punkt und die Zahl laufender Server als Live-Aktivität.",
                         extraPorts: "Auch diese Ports", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Auch diese Prozesse", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Listener auf diesen Ports oder von Prozessen mit diesen Namen zählen ebenfalls als Dev-Server.")
        case .fr:
            return .init(title: "Serveurs de dev",
                         summary: "Liste les serveurs de développement lancés sur ce Mac, pour les ouvrir, les copier ou les arrêter.",
                         empty: "Aucun serveur de dev en cours",
                         emptyHint: "Lancez-en un avec next dev, vite ou php artisan serve et il s’affichera ici.",
                         open: "Ouvrir", copyURL: "Copier l’URL", copied: "Copiée", kill: "Arrêter", confirmKill: "Arrêter ?",
                         stopping: "Arrêt…", dockerOwned: "Docker redirige ce port. Arrêtez le conteneur dans Docker.",
                         runningFor: "Lancé depuis %@", started: "Nouveau serveur de dev", running: "%@ en cours",
                         detect: "Détecter les serveurs de dev",
                         detectCaption: "Lit les mêmes ports en écoute que le Gestionnaire de ports, seulement quand la page ou son widget est à l’écran, sauf si une option ci-dessous demande plus.",
                         announce: "Annoncer les nouveaux serveurs",
                         announceCaption: "Une notification avec Ouvrir quand un serveur de dev démarre. Un redémarrage du même projet sur le même port en moins de 30 secondes reste discret. Vérifie environ toutes les 10 secondes.",
                         indicator: "Afficher le nombre dans l’île fermée",
                         indicatorCaption: "Un point vert et le nombre de serveurs lancés, comme activité en direct.",
                         extraPorts: "Aussi ces ports", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Aussi ces processus", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Ce qui écoute sur ces ports, ou les processus portant ces noms, compte aussi comme serveur de dev.")
        case .it:
            return .init(title: "Server di sviluppo",
                         summary: "Elenca i server di sviluppo attivi su questo Mac, per aprirli, copiarli o fermarli.",
                         empty: "Nessun server di sviluppo attivo",
                         emptyHint: "Avviane uno con next dev, vite o php artisan serve e apparirà qui.",
                         open: "Apri", copyURL: "Copia URL", copied: "Copiato", kill: "Termina", confirmKill: "Terminare?",
                         stopping: "Arresto…", dockerOwned: "Docker inoltra questa porta. Ferma il container in Docker.",
                         runningFor: "Attivo da %@", started: "Nuovo server di sviluppo", running: "%@ attivi",
                         detect: "Rileva server di sviluppo",
                         detectCaption: "Legge le stesse porte in ascolto di Gestione porte, solo mentre la pagina o il suo widget sono sullo schermo, a meno che un’opzione qui sotto non chieda di più.",
                         announce: "Annuncia i nuovi server",
                         announceCaption: "Un avviso con Apri quando parte un server di sviluppo. Un riavvio dello stesso progetto sulla stessa porta entro 30 secondi resta silenzioso. Controlla circa ogni 10 secondi.",
                         indicator: "Mostra il numero nell’isola chiusa",
                         indicatorCaption: "Un punto verde e quanti server sono attivi, come attività dal vivo.",
                         extraPorts: "Anche queste porte", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Anche questi processi", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Ciò che ascolta su queste porte, o i processi con questi nomi, conta anche come server di sviluppo.")
        case .ja:
            return .init(title: "開発サーバ",
                         summary: "この Mac で動いている開発サーバを一覧にし、開く、コピー、停止ができます。",
                         empty: "実行中の開発サーバはありません",
                         emptyHint: "next dev、vite、php artisan serve などで起動するとここに表示されます。",
                         open: "開く", copyURL: "URL をコピー", copied: "コピーしました", kill: "終了", confirmKill: "終了しますか？",
                         stopping: "停止中…", dockerOwned: "このポートは Docker が転送しています。コンテナは Docker で停止してください。",
                         runningFor: "%@ 実行中", started: "新しい開発サーバ", running: "%@ 件実行中",
                         detect: "開発サーバを検出",
                         detectCaption: "ポートマネージャと同じ待ち受けポートを読み取ります。下のオプションが必要としない限り、ページかウィジェットが表示されている間だけです。",
                         announce: "新しいサーバを通知",
                         announceCaption: "開発サーバが起動すると「開く」付きの通知を表示します。同じプロジェクトが同じポートで 30 秒以内に再起動した場合は通知しません。約 10 秒ごとに確認します。",
                         indicator: "閉じたアイランドに数を表示",
                         indicatorCaption: "緑の点と実行中のサーバ数をライブアクティビティとして表示します。",
                         extraPorts: "追加のポート", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "追加のプロセス", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "これらのポートで待ち受けるもの、またはこれらの名前のプロセスも開発サーバとして扱います。")
        case .ko:
            return .init(title: "개발 서버",
                         summary: "이 Mac에서 실행 중인 개발 서버를 보여 주고 열기, 복사, 중지를 할 수 있습니다.",
                         empty: "실행 중인 개발 서버 없음",
                         emptyHint: "next dev, vite 또는 php artisan serve로 시작하면 여기에 나타납니다.",
                         open: "열기", copyURL: "URL 복사", copied: "복사됨", kill: "종료", confirmKill: "종료할까요?",
                         stopping: "중지 중…", dockerOwned: "이 포트는 Docker가 전달합니다. 컨테이너는 Docker에서 중지하세요.",
                         runningFor: "%@ 동안 실행 중", started: "새 개발 서버", running: "%@개 실행 중",
                         detect: "개발 서버 감지",
                         detectCaption: "포트 관리자와 같은 수신 대기 포트를 읽습니다. 아래 옵션이 더 필요로 하지 않는 한 페이지나 위젯이 화면에 있을 때만 확인합니다.",
                         announce: "새 서버 알리기",
                         announceCaption: "개발 서버가 시작되면 열기 버튼이 있는 알림을 띄웁니다. 같은 프로젝트가 같은 포트에서 30초 안에 다시 시작되면 알리지 않습니다. 약 10초마다 확인합니다.",
                         indicator: "닫힌 아일랜드에 개수 표시",
                         indicatorCaption: "초록 점과 실행 중인 서버 수를 실시간 현황으로 표시합니다.",
                         extraPorts: "추가 포트", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "추가 프로세스", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "이 포트에서 수신 대기하거나 이 이름을 가진 프로세스도 개발 서버로 봅니다.")
        case .uk:
            return .init(title: "Dev-сервери",
                         summary: "Показує dev-сервери, запущені на цьому Mac, щоб відкрити, скопіювати або зупинити їх.",
                         empty: "Немає запущених dev-серверів",
                         emptyHint: "Запустіть next dev, vite або php artisan serve, і сервер з’явиться тут.",
                         open: "Відкрити", copyURL: "Скопіювати URL", copied: "Скопійовано", kill: "Завершити", confirmKill: "Завершити?",
                         stopping: "Зупиняється…", dockerOwned: "Цей порт перенаправляє Docker. Зупиніть контейнер у Docker.",
                         runningFor: "Працює %@", started: "Новий dev-сервер", running: "Запущено: %@",
                         detect: "Знаходити dev-сервери",
                         detectCaption: "Читає ті самі порти, що слухаються, що й Менеджер портів, лише поки сторінка або її віджет на екрані, якщо параметр нижче не потребує більшого.",
                         announce: "Повідомляти про нові сервери",
                         announceCaption: "Сповіщення з кнопкою «Відкрити», коли запускається dev-сервер. Перезапуск того самого проєкту на тому самому порту протягом 30 секунд минає тихо. Перевіряє приблизно що 10 секунд.",
                         indicator: "Показувати число в закритому острові",
                         indicatorCaption: "Зелена крапка й кількість запущених серверів як жива активність.",
                         extraPorts: "Також ці порти", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "Також ці процеси", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "Слухачі на цих портах або процеси з такими назвами теж вважаються dev-серверами.")
        case .zhHans:
            return .init(title: "开发服务器",
                         summary: "列出这台 Mac 上正在运行的开发服务器，可以打开、复制或停止。",
                         empty: "没有正在运行的开发服务器",
                         emptyHint: "用 next dev、vite 或 php artisan serve 启动一个，它就会出现在这里。",
                         open: "打开", copyURL: "复制 URL", copied: "已复制", kill: "结束", confirmKill: "要结束吗？",
                         stopping: "正在停止…", dockerOwned: "此端口由 Docker 转发，请在 Docker 中停止容器。",
                         runningFor: "已运行 %@", started: "新的开发服务器", running: "%@ 个正在运行",
                         detect: "检测开发服务器",
                         detectCaption: "读取与端口管理器相同的监听端口。除非下方选项需要，否则只在页面或其小组件显示时检查。",
                         announce: "通知新的服务器",
                         announceCaption: "开发服务器启动时显示带有“打开”的通知。同一项目在同一端口 30 秒内重启不会再通知。大约每 10 秒检查一次。",
                         indicator: "在收起的灵动岛中显示数量",
                         indicatorCaption: "以实时活动显示绿点和正在运行的服务器数量。",
                         extraPorts: "额外端口", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "额外进程", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "在这些端口上监听的程序，或具有这些名称的进程，也视为开发服务器。")
        case .zhTW:
            return .init(title: "開發伺服器",
                         summary: "列出這台 Mac 上正在執行的開發伺服器，可以打開、複製或停止。",
                         empty: "沒有正在執行的開發伺服器",
                         emptyHint: "用 next dev、vite 或 php artisan serve 啟動一個，它就會出現在這裡。",
                         open: "打開", copyURL: "拷貝 URL", copied: "已拷貝", kill: "結束", confirmKill: "要結束嗎？",
                         stopping: "正在停止…", dockerOwned: "此埠由 Docker 轉送，請在 Docker 中停止容器。",
                         runningFor: "已執行 %@", started: "新的開發伺服器", running: "%@ 個正在執行",
                         detect: "偵測開發伺服器",
                         detectCaption: "讀取與埠管理器相同的監聽埠。除非下方選項需要，否則只在頁面或其小工具顯示時檢查。",
                         announce: "通知新的伺服器",
                         announceCaption: "開發伺服器啟動時顯示附有「打開」的通知。同一專案在同一埠 30 秒內重新啟動不會再通知。大約每 10 秒檢查一次。",
                         indicator: "在收合的動態島中顯示數量",
                         indicatorCaption: "以即時動態顯示綠點和正在執行的伺服器數量。",
                         extraPorts: "額外的埠", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "額外的程序", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "在這些埠上監聽的程式，或具有這些名稱的程序，也視為開發伺服器。")
        case .zhHK:
            return .init(title: "開發伺服器",
                         summary: "列出這部 Mac 上正在執行的開發伺服器，可以打開、拷貝或停止。",
                         empty: "沒有正在執行的開發伺服器",
                         emptyHint: "用 next dev、vite 或 php artisan serve 啟動一個，它就會出現在這裡。",
                         open: "打開", copyURL: "拷貝 URL", copied: "已拷貝", kill: "結束", confirmKill: "要結束嗎？",
                         stopping: "正在停止…", dockerOwned: "此埠由 Docker 轉送，請在 Docker 中停止容器。",
                         runningFor: "已執行 %@", started: "新的開發伺服器", running: "%@ 個正在執行",
                         detect: "偵測開發伺服器",
                         detectCaption: "讀取與埠管理器相同的監聽埠。除非下方選項需要，否則只在頁面或其小工具顯示時檢查。",
                         announce: "通知新的伺服器",
                         announceCaption: "開發伺服器啟動時顯示附有「打開」的通知。同一專案在同一埠 30 秒內重新啟動不會再通知。大約每 10 秒檢查一次。",
                         indicator: "在收合的動態島中顯示數量",
                         indicatorCaption: "以即時動態顯示綠點和正在執行的伺服器數量。",
                         extraPorts: "額外的埠", extraPortsPlaceholder: "8080, 9000-9002",
                         extraNames: "額外的程序", extraNamesPlaceholder: "caddy, hugo",
                         extrasCaption: "在這些埠上監聽的程式，或具有這些名稱的程序，也視為開發伺服器。")
        }
    }
}

/// Zenith fork: the export tracker (ExportTrackerSupport), its live activity,
/// notice and Settings card.
struct ZenithExportTrackerStrings {
    /// The activity’s name in the island’s activity picker.
    let activityTitle: String
    /// The card in Settings → Dynamic Island → Activity.
    let section: String
    let toggle: String
    let toggleCaption: String
    let folders: String
    let foldersCaption: String
    let addFolder: String
    let removeFolder: String
    /// A watched folder that is not there (an unplugged drive).
    let missing: String
    /// The open panel’s button.
    let choose: String
    let minimumSize: String
    /// A size choice; `%d` is the number of megabytes.
    let megabytes: String
    let sound: String
    let notify: String
    let notifyCaption: String
    /// Beside the file name while it grows.
    let exporting: String
    let recording: String
    /// The notice and the notification once it is done.
    let exportFinished: String
    let recordingSaved: String
    /// A batch of images landing one after another; `%d` is how many.
    let images: String
    /// Read aloud for the strip once it is done.
    let finished: String
}

extension ZenithStrings {
    /// Renders, recordings and photo exports in the closed island.
    static func exportTracker(_ language: AppLanguage) -> ZenithExportTrackerStrings {
        switch language {
        case .enUS:
            return .init(activityTitle: "Exports", section: "Exports", toggle: "Export tracker",
                         toggleCaption: "Shows a render, recording or photo export in the closed island while its file grows, then ✓ with the size and time when it’s done. It reads the watched folders only, so it works with DaVinci Resolve, OBS and other apps without plug-ins.",
                         folders: "Watched folders",
                         foldersCaption: "Subfolders are included. Hidden and temporary files, caches, proxies and app libraries are skipped. macOS may ask once before Zenith can read Desktop or Downloads.",
                         addFolder: "Add Folder…", removeFolder: "Remove", missing: "Not found", choose: "Watch",
                         minimumSize: "Minimum size", megabytes: "%d MB",
                         sound: "Play a sound when done", notify: "Notify when done",
                         notifyCaption: "Sends a notification when the Mac is locked or the island is hidden.",
                         exporting: "Exporting", recording: "Recording",
                         exportFinished: "Export finished", recordingSaved: "Recording saved",
                         images: "%d images", finished: "Finished")
        case .ptBR:
            return .init(activityTitle: "Exportações", section: "Exportações", toggle: "Monitor de exportações",
                         toggleCaption: "Mostra na ilha fechada uma renderização, gravação ou exportação de fotos enquanto o arquivo cresce e, ao terminar, ✓ com o tamanho e o tempo. Só lê as pastas monitoradas, então funciona com DaVinci Resolve, OBS e outros apps sem plug-ins.",
                         folders: "Pastas monitoradas",
                         foldersCaption: "Inclui subpastas. Arquivos ocultos e temporários, caches, proxies e bibliotecas de apps ficam de fora. O macOS pode pedir permissão uma vez para o Zenith ler a Mesa ou Downloads.",
                         addFolder: "Adicionar pasta…", removeFolder: "Remover", missing: "Não encontrada", choose: "Monitorar",
                         minimumSize: "Tamanho mínimo", megabytes: "%d MB",
                         sound: "Tocar um som ao terminar", notify: "Notificar ao terminar",
                         notifyCaption: "Envia uma notificação quando o Mac está bloqueado ou a ilha está oculta.",
                         exporting: "Exportando", recording: "Gravando",
                         exportFinished: "Exportação concluída", recordingSaved: "Gravação salva",
                         images: "%d imagens", finished: "Concluído")
        case .tr:
            return .init(activityTitle: "Dışa aktarmalar", section: "Dışa aktarmalar", toggle: "Dışa aktarma izleyici",
                         toggleCaption: "Bir işleme, kayıt ya da fotoğraf dışa aktarması, dosyası büyüdükçe kapalı adada görünür; bitince boyutu ve süresiyle ✓ gösterir. Yalnızca izlenen klasörleri okur, bu yüzden DaVinci Resolve, OBS ve diğer uygulamalarla eklentisiz çalışır.",
                         folders: "İzlenen klasörler",
                         foldersCaption: "Alt klasörler dahildir. Gizli ve geçici dosyalar, önbellekler, proxy’ler ve uygulama arşivleri atlanır. macOS, Zenith’in Masaüstü’nü ya da İndirilenler’i okuması için bir kez izin isteyebilir.",
                         addFolder: "Klasör ekle…", removeFolder: "Kaldır", missing: "Bulunamadı", choose: "İzle",
                         minimumSize: "En küçük boyut", megabytes: "%d MB",
                         sound: "Bitince ses çal", notify: "Bitince bildir",
                         notifyCaption: "Mac kilitliyken ya da ada gizliyken bildirim gönderir.",
                         exporting: "Dışa aktarılıyor", recording: "Kaydediliyor",
                         exportFinished: "Dışa aktarma bitti", recordingSaved: "Kayıt kaydedildi",
                         images: "%d görsel", finished: "Bitti")
        case .ru:
            return .init(activityTitle: "Экспорт", section: "Экспорт", toggle: "Отслеживание экспорта",
                         toggleCaption: "Пока файл растёт, рендер, запись или экспорт фото видны на закрытом острове, а по завершении появляется ✓ с размером и временем. Читаются только отслеживаемые папки, поэтому всё работает с DaVinci Resolve, OBS и другими приложениями без плагинов.",
                         folders: "Отслеживаемые папки",
                         foldersCaption: "Вложенные папки учитываются. Скрытые и временные файлы, кэши, прокси и медиатеки приложений пропускаются. macOS может один раз запросить доступ к папкам «Рабочий стол» и «Загрузки».",
                         addFolder: "Добавить папку…", removeFolder: "Удалить", missing: "Не найдена", choose: "Отслеживать",
                         minimumSize: "Минимальный размер", megabytes: "%d МБ",
                         sound: "Звук по завершении", notify: "Уведомлять по завершении",
                         notifyCaption: "Отправляет уведомление, когда Mac заблокирован или остров скрыт.",
                         exporting: "Экспорт", recording: "Запись",
                         exportFinished: "Экспорт завершён", recordingSaved: "Запись сохранена",
                         images: "Изображения: %d", finished: "Готово")
        case .es:
            return .init(activityTitle: "Exportaciones", section: "Exportaciones", toggle: "Seguimiento de exportaciones",
                         toggleCaption: "Muestra en la isla cerrada un render, una grabación o una exportación de fotos mientras su archivo crece y, al terminar, ✓ con el tamaño y el tiempo. Solo lee las carpetas vigiladas, así que funciona con DaVinci Resolve, OBS y otras apps sin plug-ins.",
                         folders: "Carpetas vigiladas",
                         foldersCaption: "Incluye subcarpetas. Se omiten archivos ocultos y temporales, cachés, proxies y bibliotecas de apps. macOS puede pedir permiso una vez para que Zenith lea el Escritorio o Descargas.",
                         addFolder: "Añadir carpeta…", removeFolder: "Quitar", missing: "No encontrada", choose: "Vigilar",
                         minimumSize: "Tamaño mínimo", megabytes: "%d MB",
                         sound: "Reproducir un sonido al terminar", notify: "Avisar al terminar",
                         notifyCaption: "Envía una notificación cuando el Mac está bloqueado o la isla está oculta.",
                         exporting: "Exportando", recording: "Grabando",
                         exportFinished: "Exportación terminada", recordingSaved: "Grabación guardada",
                         images: "%d imágenes", finished: "Terminado")
        case .sk:
            return .init(activityTitle: "Exporty", section: "Exporty", toggle: "Sledovanie exportov",
                         toggleCaption: "Kým súbor rastie, render, nahrávanie alebo export fotiek sa zobrazí v zatvorenom ostrove a po dokončení ✓ s veľkosťou a časom. Číta len sledované priečinky, takže funguje s DaVinci Resolve, OBS a ďalšími aplikáciami bez doplnkov.",
                         folders: "Sledované priečinky",
                         foldersCaption: "Zahŕňa podpriečinky. Skryté a dočasné súbory, vyrovnávacie pamäte, proxy a knižnice aplikácií sa vynechajú. macOS môže raz požiadať o prístup k Ploche alebo Stiahnutým súborom.",
                         addFolder: "Pridať priečinok…", removeFolder: "Odstrániť", missing: "Nenájdený", choose: "Sledovať",
                         minimumSize: "Minimálna veľkosť", megabytes: "%d MB",
                         sound: "Po dokončení prehrať zvuk", notify: "Upozorniť po dokončení",
                         notifyCaption: "Pošle upozornenie, keď je Mac zamknutý alebo je ostrov skrytý.",
                         exporting: "Exportuje sa", recording: "Nahráva sa",
                         exportFinished: "Export dokončený", recordingSaved: "Nahrávka uložená",
                         images: "Obrázky: %d", finished: "Hotovo")
        case .de:
            return .init(activityTitle: "Exporte", section: "Exporte", toggle: "Export-Tracker",
                         toggleCaption: "Zeigt einen Render, eine Aufnahme oder einen Fotoexport in der geschlossenen Insel, solange die Datei wächst, und danach ✓ mit Größe und Dauer. Es liest nur die beobachteten Ordner und funktioniert so mit DaVinci Resolve, OBS und anderen Apps ohne Plug-ins.",
                         folders: "Beobachtete Ordner",
                         foldersCaption: "Unterordner sind eingeschlossen. Versteckte und temporäre Dateien, Caches, Proxys und App-Mediatheken werden übersprungen. macOS fragt eventuell einmal, bevor Zenith Schreibtisch oder Downloads lesen darf.",
                         addFolder: "Ordner hinzufügen…", removeFolder: "Entfernen", missing: "Nicht gefunden", choose: "Beobachten",
                         minimumSize: "Mindestgröße", megabytes: "%d MB",
                         sound: "Ton abspielen, wenn fertig", notify: "Mitteilen, wenn fertig",
                         notifyCaption: "Sendet eine Mitteilung, wenn der Mac gesperrt oder die Insel ausgeblendet ist.",
                         exporting: "Exportiert", recording: "Nimmt auf",
                         exportFinished: "Export abgeschlossen", recordingSaved: "Aufnahme gesichert",
                         images: "%d Bilder", finished: "Fertig")
        case .fr:
            return .init(activityTitle: "Exports", section: "Exports", toggle: "Suivi des exports",
                         toggleCaption: "Affiche dans l’île fermée un rendu, un enregistrement ou un export de photos tant que son fichier grossit, puis ✓ avec la taille et la durée une fois terminé. Seuls les dossiers surveillés sont lus : cela fonctionne avec DaVinci Resolve, OBS et d’autres apps sans plug-in.",
                         folders: "Dossiers surveillés",
                         foldersCaption: "Les sous-dossiers sont inclus. Les fichiers masqués et temporaires, les caches, les proxys et les bibliothèques d’apps sont ignorés. macOS peut demander une fois l’accès au Bureau ou aux Téléchargements.",
                         addFolder: "Ajouter un dossier…", removeFolder: "Retirer", missing: "Introuvable", choose: "Surveiller",
                         minimumSize: "Taille minimale", megabytes: "%d Mo",
                         sound: "Jouer un son à la fin", notify: "Notifier à la fin",
                         notifyCaption: "Envoie une notification quand le Mac est verrouillé ou que l’île est masquée.",
                         exporting: "Export en cours", recording: "Enregistrement",
                         exportFinished: "Export terminé", recordingSaved: "Enregistrement sauvegardé",
                         images: "%d images", finished: "Terminé")
        case .it:
            return .init(activityTitle: "Esportazioni", section: "Esportazioni", toggle: "Monitor esportazioni",
                         toggleCaption: "Mostra nell’isola chiusa un render, una registrazione o un’esportazione di foto mentre il file cresce, poi ✓ con dimensione e durata quando ha finito. Legge solo le cartelle monitorate, quindi funziona con DaVinci Resolve, OBS e altre app senza plug-in.",
                         folders: "Cartelle monitorate",
                         foldersCaption: "Le sottocartelle sono incluse. File nascosti e temporanei, cache, proxy e librerie delle app vengono saltati. macOS potrebbe chiedere una volta l’accesso a Scrivania o Download.",
                         addFolder: "Aggiungi cartella…", removeFolder: "Rimuovi", missing: "Non trovata", choose: "Monitora",
                         minimumSize: "Dimensione minima", megabytes: "%d MB",
                         sound: "Riproduci un suono alla fine", notify: "Notifica alla fine",
                         notifyCaption: "Invia una notifica quando il Mac è bloccato o l’isola è nascosta.",
                         exporting: "Esportazione", recording: "Registrazione",
                         exportFinished: "Esportazione completata", recordingSaved: "Registrazione salvata",
                         images: "%d immagini", finished: "Completato")
        case .ja:
            return .init(activityTitle: "書き出し", section: "書き出し", toggle: "書き出しトラッカー",
                         toggleCaption: "レンダリング、録画、写真の書き出しを、ファイルが大きくなっている間は閉じたアイランドに表示し、終わるとサイズと時間とともに ✓ を表示します。監視中のフォルダだけを読むので、DaVinci Resolve や OBS などのアプリでもプラグインなしで動作します。",
                         folders: "監視するフォルダ",
                         foldersCaption: "サブフォルダも含まれます。隠しファイル、一時ファイル、キャッシュ、プロキシ、アプリのライブラリはスキップします。Zenith がデスクトップやダウンロードを読む前に、macOS が一度だけ許可を求めることがあります。",
                         addFolder: "フォルダを追加…", removeFolder: "削除", missing: "見つかりません", choose: "監視",
                         minimumSize: "最小サイズ", megabytes: "%d MB",
                         sound: "完了時にサウンドを再生", notify: "完了時に通知",
                         notifyCaption: "Mac がロックされているときやアイランドが非表示のときに通知を送ります。",
                         exporting: "書き出し中", recording: "録画中",
                         exportFinished: "書き出し完了", recordingSaved: "録画を保存しました",
                         images: "%d 枚の画像", finished: "完了")
        case .ko:
            return .init(activityTitle: "내보내기", section: "내보내기", toggle: "내보내기 추적",
                         toggleCaption: "렌더링, 녹화, 사진 내보내기를 파일이 커지는 동안 닫힌 아일랜드에 표시하고, 끝나면 크기와 시간과 함께 ✓를 표시합니다. 감시 중인 폴더만 읽으므로 DaVinci Resolve, OBS 등 다른 앱에서도 플러그인 없이 작동합니다.",
                         folders: "감시 폴더",
                         foldersCaption: "하위 폴더도 포함됩니다. 숨김 파일과 임시 파일, 캐시, 프록시, 앱 보관함은 건너뜁니다. Zenith가 데스크탑이나 다운로드를 읽기 전에 macOS가 한 번 권한을 요청할 수 있습니다.",
                         addFolder: "폴더 추가…", removeFolder: "제거", missing: "찾을 수 없음", choose: "감시",
                         minimumSize: "최소 크기", megabytes: "%d MB",
                         sound: "완료 시 사운드 재생", notify: "완료 시 알림",
                         notifyCaption: "Mac이 잠겨 있거나 아일랜드가 숨겨져 있을 때 알림을 보냅니다.",
                         exporting: "내보내는 중", recording: "녹화 중",
                         exportFinished: "내보내기 완료", recordingSaved: "녹화 저장됨",
                         images: "이미지 %d개", finished: "완료")
        case .uk:
            return .init(activityTitle: "Експорт", section: "Експорт", toggle: "Відстеження експорту",
                         toggleCaption: "Поки файл росте, рендер, запис або експорт фото видно на закритому острівці, а після завершення з’являється ✓ з розміром і часом. Читаються лише відстежувані папки, тож усе працює з DaVinci Resolve, OBS та іншими програмами без плагінів.",
                         folders: "Відстежувані папки",
                         foldersCaption: "Вкладені папки враховуються. Приховані й тимчасові файли, кеші, проксі та медіатеки програм пропускаються. macOS може один раз попросити доступ до Робочого столу або Завантажень.",
                         addFolder: "Додати папку…", removeFolder: "Вилучити", missing: "Не знайдено", choose: "Відстежувати",
                         minimumSize: "Мінімальний розмір", megabytes: "%d МБ",
                         sound: "Звук після завершення", notify: "Сповіщати після завершення",
                         notifyCaption: "Надсилає сповіщення, коли Mac заблоковано або острівець приховано.",
                         exporting: "Експорт", recording: "Запис",
                         exportFinished: "Експорт завершено", recordingSaved: "Запис збережено",
                         images: "Зображення: %d", finished: "Готово")
        case .zhHans:
            return .init(activityTitle: "导出", section: "导出", toggle: "导出追踪",
                         toggleCaption: "渲染、录制或照片导出在文件增长期间显示在收起的岛上，完成后显示 ✓ 以及大小和用时。只读取监视的文件夹，因此无需插件即可配合 DaVinci Resolve、OBS 等 App 使用。",
                         folders: "监视的文件夹",
                         foldersCaption: "包括子文件夹。会跳过隐藏文件和临时文件、缓存、代理文件和 App 资源库。在 Zenith 读取桌面或下载之前，macOS 可能会询问一次。",
                         addFolder: "添加文件夹…", removeFolder: "移除", missing: "未找到", choose: "监视",
                         minimumSize: "最小大小", megabytes: "%d MB",
                         sound: "完成时播放声音", notify: "完成时通知",
                         notifyCaption: "Mac 锁定或岛隐藏时发送通知。",
                         exporting: "正在导出", recording: "正在录制",
                         exportFinished: "导出完成", recordingSaved: "录制已存储",
                         images: "%d 张图片", finished: "已完成")
        case .zhTW:
            return .init(activityTitle: "輸出", section: "輸出", toggle: "輸出追蹤",
                         toggleCaption: "算繪、錄影或照片輸出在檔案增長期間會顯示在收合的島上，完成後顯示 ✓ 及大小與耗時。只讀取監看的資料夾，因此不需外掛即可配合 DaVinci Resolve、OBS 等 App 使用。",
                         folders: "監看的資料夾",
                         foldersCaption: "包含子資料夾。會略過隱藏檔與暫存檔、快取、代理檔與 App 資料庫。Zenith 讀取桌面或下載項目前，macOS 可能會詢問一次。",
                         addFolder: "加入資料夾…", removeFolder: "移除", missing: "找不到", choose: "監看",
                         minimumSize: "最小大小", megabytes: "%d MB",
                         sound: "完成時播放聲音", notify: "完成時通知",
                         notifyCaption: "Mac 鎖定或島已隱藏時傳送通知。",
                         exporting: "正在輸出", recording: "正在錄影",
                         exportFinished: "輸出完成", recordingSaved: "錄影已儲存",
                         images: "%d 張圖片", finished: "已完成")
        case .zhHK:
            return .init(activityTitle: "輸出", section: "輸出", toggle: "輸出追蹤",
                         toggleCaption: "渲染、錄影或相片輸出在檔案增長期間會顯示在收合的島上，完成後顯示 ✓ 及大小與所需時間。只讀取監察的資料夾，因此毋須插件即可配合 DaVinci Resolve、OBS 等 App 使用。",
                         folders: "監察的資料夾",
                         foldersCaption: "包括子資料夾。會略過隱藏及暫存檔案、快取、代理檔案及 App 資料庫。Zenith 讀取桌面或下載項目前，macOS 可能會詢問一次。",
                         addFolder: "加入資料夾…", removeFolder: "移除", missing: "找不到", choose: "監察",
                         minimumSize: "最小大小", megabytes: "%d MB",
                         sound: "完成時播放聲音", notify: "完成時通知",
                         notifyCaption: "Mac 鎖定或島已隱藏時傳送通知。",
                         exporting: "正在輸出", recording: "正在錄影",
                         exportFinished: "輸出完成", recordingSaved: "錄影已儲存",
                         images: "%d 張圖片", finished: "已完成")
        }
    }
}

/// Zenith fork: capsule notices (ZenithNoticeSupport) and their Settings card.
struct ZenithNoticeStrings {
    /// The card in Settings → Dynamic Island → Activity.
    let section: String
    let caption: String
    let lowBattery: String
    let veryLowBattery: String
    let chargeReaches: String
    /// Also the subtitle of the notice when the charge reaches that level.
    let chargeHint: String
    let charger: String
    let audio: String
    let download: String
    /// `%d` is the percentage, as in “20% Battery”.
    let batteryTitle: String
    let lowPowerAction: String
    let lowPowerOn: String
    let charging: String
    let chargerConnected: String
    let onBattery: String
    let chargerRemoved: String
    let connected: String
}

extension ZenithStrings {
    static func notices(_ language: AppLanguage) -> ZenithNoticeStrings {
        switch language {
        case .enUS:
            return .init(section: "Notices",
                         caption: "Short capsules grow out of the island for the battery, headphones and downloads. Turned off, the island shows its small notice instead.",
                         lowBattery: "Low battery", veryLowBattery: "Very low battery", chargeReaches: "Charge reaches",
                         chargeHint: "Unplugging around here is easier on the battery",
                         charger: "Charger connected or removed", audio: "Headphones connected", download: "Download finished",
                         batteryTitle: "%d% Battery", lowPowerAction: "Click for Low Power Mode", lowPowerOn: "Low Power Mode is on",
                         charging: "Charging", chargerConnected: "Power adapter connected",
                         onBattery: "On Battery", chargerRemoved: "Power adapter disconnected", connected: "Connected")
        case .ptBR:
            return .init(section: "Avisos",
                         caption: "Cápsulas curtas saem da ilha para a bateria, os fones e os downloads. Desativado, a ilha mostra o aviso pequeno no lugar.",
                         lowBattery: "Bateria fraca", veryLowBattery: "Bateria muito fraca", chargeReaches: "Carga chega a",
                         chargeHint: "Desconectar por aqui poupa a bateria",
                         charger: "Carregador conectado ou removido", audio: "Fones conectados", download: "Download concluído",
                         batteryTitle: "%d% de bateria", lowPowerAction: "Clique para o Modo de Pouca Energia",
                         lowPowerOn: "Modo de Pouca Energia ativado",
                         charging: "Carregando", chargerConnected: "Adaptador de energia conectado",
                         onBattery: "Na bateria", chargerRemoved: "Adaptador de energia desconectado", connected: "Conectado")
        case .tr:
            return .init(section: "Uyarılar",
                         caption: "Pil, kulaklık ve indirmeler için adadan kısa kapsüller çıkar. Kapalıyken ada bunun yerine küçük uyarısını gösterir.",
                         lowBattery: "Düşük pil", veryLowBattery: "Çok düşük pil", chargeReaches: "Şarj şu seviyede",
                         chargeHint: "Burada fişten çekmek pili daha az yorar",
                         charger: "Şarj aleti takıldı veya çıkarıldı", audio: "Kulaklık bağlandı", download: "İndirme bitti",
                         batteryTitle: "%%d pil", lowPowerAction: "Düşük Güç Modu için tıklayın", lowPowerOn: "Düşük Güç Modu açık",
                         charging: "Şarj oluyor", chargerConnected: "Güç adaptörü takıldı",
                         onBattery: "Pil gücünde", chargerRemoved: "Güç adaptörü çıkarıldı", connected: "Bağlandı")
        case .ru:
            return .init(section: "Уведомления",
                         caption: "Короткие капсулы выходят из острова для батареи, наушников и загрузок. Если выключено, остров показывает своё маленькое уведомление.",
                         lowBattery: "Низкий заряд", veryLowBattery: "Очень низкий заряд", chargeReaches: "Заряд достигает",
                         chargeHint: "Отключить зарядку здесь бережнее для батареи",
                         charger: "Зарядка подключена или отключена", audio: "Наушники подключены", download: "Загрузка завершена",
                         batteryTitle: "Заряд %d%", lowPowerAction: "Нажмите для режима энергосбережения",
                         lowPowerOn: "Режим энергосбережения включён",
                         charging: "Зарядка", chargerConnected: "Адаптер питания подключён",
                         onBattery: "От батареи", chargerRemoved: "Адаптер питания отключён", connected: "Подключено")
        case .es:
            return .init(section: "Avisos",
                         caption: "Cápsulas breves salen de la isla para la batería, los auriculares y las descargas. Si está desactivado, la isla muestra su aviso pequeño.",
                         lowBattery: "Batería baja", veryLowBattery: "Batería muy baja", chargeReaches: "La carga llega a",
                         chargeHint: "Desconectar por aquí cuida la batería",
                         charger: "Cargador conectado o retirado", audio: "Auriculares conectados", download: "Descarga terminada",
                         batteryTitle: "%d% de batería", lowPowerAction: "Haz clic para el modo de bajo consumo",
                         lowPowerOn: "Modo de bajo consumo activado",
                         charging: "Cargando", chargerConnected: "Adaptador de corriente conectado",
                         onBattery: "Con batería", chargerRemoved: "Adaptador de corriente desconectado", connected: "Conectado")
        case .sk:
            return .init(section: "Upozornenia",
                         caption: "Krátke kapsuly vychádzajú z ostrova pre batériu, slúchadlá a stiahnuté súbory. Keď je to vypnuté, ostrov ukáže svoje malé upozornenie.",
                         lowBattery: "Slabá batéria", veryLowBattery: "Veľmi slabá batéria", chargeReaches: "Nabitie dosiahne",
                         chargeHint: "Odpojiť nabíjačku okolo tejto úrovne šetrí batériu",
                         charger: "Nabíjačka pripojená alebo odpojená", audio: "Slúchadlá pripojené", download: "Sťahovanie dokončené",
                         batteryTitle: "Batéria %d %", lowPowerAction: "Kliknite pre režim nízkej spotreby",
                         lowPowerOn: "Režim nízkej spotreby je zapnutý",
                         charging: "Nabíja sa", chargerConnected: "Napájací adaptér pripojený",
                         onBattery: "Na batérii", chargerRemoved: "Napájací adaptér odpojený", connected: "Pripojené")
        case .de:
            return .init(section: "Hinweise",
                         caption: "Kurze Kapseln wachsen aus der Insel: für Batterie, Kopfhörer und Downloads. Ausgeschaltet zeigt die Insel stattdessen ihren kleinen Hinweis.",
                         lowBattery: "Niedriger Batteriestand", veryLowBattery: "Sehr niedriger Batteriestand",
                         chargeReaches: "Ladestand erreicht",
                         chargeHint: "Hier abzustecken schont die Batterie",
                         charger: "Netzteil angeschlossen oder getrennt", audio: "Kopfhörer verbunden", download: "Download abgeschlossen",
                         batteryTitle: "Batterie %d %", lowPowerAction: "Klicken für den Stromsparmodus",
                         lowPowerOn: "Stromsparmodus ist an",
                         charging: "Lädt", chargerConnected: "Netzteil angeschlossen",
                         onBattery: "Batteriebetrieb", chargerRemoved: "Netzteil getrennt", connected: "Verbunden")
        case .fr:
            return .init(section: "Avis",
                         caption: "De courtes capsules sortent de l’île pour la batterie, les écouteurs et les téléchargements. Désactivé, l’île affiche sa petite notification à la place.",
                         lowBattery: "Batterie faible", veryLowBattery: "Batterie très faible", chargeReaches: "La charge atteint",
                         chargeHint: "Débrancher vers ce niveau ménage la batterie",
                         charger: "Chargeur branché ou débranché", audio: "Écouteurs connectés", download: "Téléchargement terminé",
                         batteryTitle: "Batterie à %d %", lowPowerAction: "Cliquez pour le mode économie d’énergie",
                         lowPowerOn: "Mode économie d’énergie activé",
                         charging: "En charge", chargerConnected: "Adaptateur secteur branché",
                         onBattery: "Sur batterie", chargerRemoved: "Adaptateur secteur débranché", connected: "Connecté")
        case .it:
            return .init(section: "Avvisi",
                         caption: "Brevi capsule escono dall’isola per batteria, cuffie e download. Se disattivato, l’isola mostra il suo avviso piccolo.",
                         lowBattery: "Batteria scarica", veryLowBattery: "Batteria quasi scarica", chargeReaches: "La carica arriva al",
                         chargeHint: "Scollegare a questo livello preserva la batteria",
                         charger: "Alimentatore collegato o scollegato", audio: "Cuffie collegate", download: "Download completato",
                         batteryTitle: "Batteria al %d%", lowPowerAction: "Fai clic per il risparmio energetico",
                         lowPowerOn: "Risparmio energetico attivo",
                         charging: "In carica", chargerConnected: "Alimentatore collegato",
                         onBattery: "A batteria", chargerRemoved: "Alimentatore scollegato", connected: "Connesso")
        case .ja:
            return .init(section: "通知カプセル",
                         caption: "バッテリー、ヘッドフォン、ダウンロードの短いカプセルがアイランドから広がります。オフにすると、代わりに小さな通知が表示されます。",
                         lowBattery: "バッテリー残量低下", veryLowBattery: "バッテリー残量わずか", chargeReaches: "充電の目安",
                         chargeHint: "このあたりで外すとバッテリーにやさしいです",
                         charger: "電源アダプタの接続と取り外し", audio: "ヘッドフォンの接続", download: "ダウンロード完了",
                         batteryTitle: "バッテリー %d%", lowPowerAction: "クリックで低電力モード", lowPowerOn: "低電力モードはオンです",
                         charging: "充電中", chargerConnected: "電源アダプタを接続しました",
                         onBattery: "バッテリー駆動", chargerRemoved: "電源アダプタを取り外しました", connected: "接続済み")
        case .ko:
            return .init(section: "알림 캡슐",
                         caption: "배터리, 헤드폰, 다운로드에 대한 짧은 캡슐이 아일랜드에서 펼쳐집니다. 끄면 대신 작은 알림이 표시됩니다.",
                         lowBattery: "배터리 부족", veryLowBattery: "배터리 매우 부족", chargeReaches: "충전 도달",
                         chargeHint: "이쯤에서 분리하면 배터리에 무리가 덜 갑니다",
                         charger: "충전기 연결 또는 분리", audio: "헤드폰 연결", download: "다운로드 완료",
                         batteryTitle: "배터리 %d%", lowPowerAction: "클릭하여 저전력 모드 사용", lowPowerOn: "저전력 모드 켜짐",
                         charging: "충전 중", chargerConnected: "전원 어댑터 연결됨",
                         onBattery: "배터리 사용 중", chargerRemoved: "전원 어댑터 분리됨", connected: "연결됨")
        case .uk:
            return .init(section: "Сповіщення",
                         caption: "Короткі капсули виходять з острова для батареї, навушників і завантажень. Якщо вимкнено, острів показує своє маленьке сповіщення.",
                         lowBattery: "Низький заряд", veryLowBattery: "Дуже низький заряд", chargeReaches: "Заряд досягає",
                         chargeHint: "Відключити зарядку тут дбайливіше для батареї",
                         charger: "Зарядку підключено або від’єднано", audio: "Навушники підключено", download: "Завантаження завершено",
                         batteryTitle: "Заряд %d%", lowPowerAction: "Натисніть для режиму енергозбереження",
                         lowPowerOn: "Режим енергозбереження увімкнено",
                         charging: "Заряджається", chargerConnected: "Адаптер живлення підключено",
                         onBattery: "Від батареї", chargerRemoved: "Адаптер живлення від’єднано", connected: "Підключено")
        case .zhHans:
            return .init(section: "提示胶囊",
                         caption: "电池、耳机和下载的简短胶囊会从灵动岛中展开。关闭后，灵动岛会改为显示小提示。",
                         lowBattery: "电量不足", veryLowBattery: "电量严重不足", chargeReaches: "充电达到",
                         chargeHint: "在这附近拔掉充电器对电池更友好",
                         charger: "充电器接入或拔出", audio: "耳机已连接", download: "下载完成",
                         batteryTitle: "电量 %d%", lowPowerAction: "点按以使用低电量模式", lowPowerOn: "低电量模式已开启",
                         charging: "正在充电", chargerConnected: "已接入电源适配器",
                         onBattery: "使用电池", chargerRemoved: "已拔出电源适配器", connected: "已连接")
        case .zhTW:
            return .init(section: "提示膠囊",
                         caption: "電池、耳機與下載的簡短膠囊會從動態島展開。關閉後，動態島會改為顯示小提示。",
                         lowBattery: "電量不足", veryLowBattery: "電量嚴重不足", chargeReaches: "充電達到",
                         chargeHint: "在這附近拔掉充電器對電池更友善",
                         charger: "充電器接上或拔除", audio: "耳機已連接", download: "下載完成",
                         batteryTitle: "電量 %d%", lowPowerAction: "按一下以使用低耗電模式", lowPowerOn: "低耗電模式已開啟",
                         charging: "充電中", chargerConnected: "已接上電源轉換器",
                         onBattery: "使用電池", chargerRemoved: "已拔除電源轉換器", connected: "已連接")
        case .zhHK:
            return .init(section: "提示膠囊",
                         caption: "電池、耳機和下載的簡短膠囊會從動態島展開。關閉後，動態島會改為顯示小提示。",
                         lowBattery: "電量不足", veryLowBattery: "電量嚴重不足", chargeReaches: "充電達到",
                         chargeHint: "在這附近拔走充電器對電池更好",
                         charger: "充電器接上或拔走", audio: "耳機已連接", download: "下載完成",
                         batteryTitle: "電量 %d%", lowPowerAction: "按一下以使用低耗電模式", lowPowerOn: "低耗電模式已開啟",
                         charging: "充電中", chargerConnected: "已接上電源轉換器",
                         onBattery: "使用電池", chargerRemoved: "已拔走電源轉換器", connected: "已連接")
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

// MARK: Watermark (Zenith fork)

struct ZenithWatermarkStrings {
    let title: String
    let scale: String
    let opacity: String
    let margin: String
    let position: String
    let content: String
    let logo: String
    let text: String
    let logoAndText: String
    let color: String
    let autoColor: String
    let white: String
    let black: String
    let customColor: String
    let originalColors: String
    let shadow: String
    let tile: String
    let presets: String
    let unsaved: String
    let savePreset: String
    let presetName: String
    let save: String
    let deletePreset: String
    let editText: String
    let chooseLogo: String
    let star: String
    let weight: String
    let regular: String
    let medium: String
    let semibold: String
    let bold: String
    let caption: String
    let defaultPreset: String
    let none: String
    let logoMissing: String
    let clientProof: String
    let instagram: String
    /// The 3×3 grid, left to right, top to bottom, for VoiceOver and tooltips.
    let positions: [String]
}

extension ZenithStrings {
    /// The photo actions' Watermark step (NotchWatermarkSupport) and its card in Shelf settings.
    static func watermark(_ language: AppLanguage) -> ZenithWatermarkStrings {
        switch language {
        case .enUS:
            return .init(title: "Watermark", scale: "Scale", opacity: "Opacity", margin: "Margin", position: "Position",
                         content: "Show", logo: "Logo", text: "Text", logoAndText: "Logo and text", color: "Color",
                         autoColor: "Auto contrast", white: "White", black: "Black", customColor: "Custom",
                         originalColors: "Logo’s own colors", shadow: "Soft shadow", tile: "Tile pattern",
                         presets: "Presets", unsaved: "Unsaved", savePreset: "Save as preset…",
                         presetName: "Preset name", save: "Save", deletePreset: "Delete preset",
                         editText: "Edit text…", chooseLogo: "Choose logo…", star: "Satu Visual star",
                         weight: "Weight", regular: "Regular", medium: "Medium", semibold: "Semibold", bold: "Bold",
                         caption: "The Watermark step in Transform marks photos with a logo, text or both before you send them, on its own or together with Convert, Resize or Compress. Each result is a new file ending in -wm. The default preset is applied to every new drop.",
                         defaultPreset: "Default preset", none: "None",
                         logoMissing: "This logo isn’t on this Mac, so the star is used instead.",
                         clientProof: "Client proof", instagram: "Instagram",
                         positions: ["Top left", "Top", "Top right", "Left", "Center", "Right",
                                     "Bottom left", "Bottom", "Bottom right"])
        case .ptBR:
            return .init(title: "Marca d’água", scale: "Escala", opacity: "Opacidade", margin: "Margem",
                         position: "Posição", content: "Mostrar", logo: "Logo", text: "Texto",
                         logoAndText: "Logo e texto", color: "Cor", autoColor: "Contraste automático",
                         white: "Branco", black: "Preto", customColor: "Personalizada",
                         originalColors: "Cores do próprio logo", shadow: "Sombra suave", tile: "Padrão repetido",
                         presets: "Predefinições", unsaved: "Não salva", savePreset: "Salvar como predefinição…",
                         presetName: "Nome da predefinição", save: "Salvar", deletePreset: "Apagar predefinição",
                         editText: "Editar texto…", chooseLogo: "Escolher logo…", star: "Estrela Satu Visual",
                         weight: "Peso", regular: "Regular", medium: "Médio", semibold: "Seminegrito", bold: "Negrito",
                         caption: "A etapa Marca d’água em Transformar marca as fotos com um logo, um texto ou ambos antes de você enviá-las, sozinha ou junto com Converter, Redimensionar ou Comprimir. Cada resultado é um novo arquivo terminado em -wm. A predefinição padrão é aplicada a cada nova imagem solta.",
                         defaultPreset: "Predefinição padrão", none: "Nenhuma",
                         logoMissing: "Este logo não está neste Mac, então a estrela é usada.",
                         clientProof: "Prova para cliente", instagram: "Instagram",
                         positions: ["Superior esquerdo", "Superior", "Superior direito", "Esquerda", "Centro",
                                     "Direita", "Inferior esquerdo", "Inferior", "Inferior direito"])
        case .tr:
            return .init(title: "Filigran", scale: "Ölçek", opacity: "Opaklık", margin: "Kenar boşluğu",
                         position: "Konum", content: "Göster", logo: "Logo", text: "Metin",
                         logoAndText: "Logo ve metin", color: "Renk", autoColor: "Otomatik kontrast",
                         white: "Beyaz", black: "Siyah", customColor: "Özel",
                         originalColors: "Logonun kendi renkleri", shadow: "Yumuşak gölge", tile: "Döşeme deseni",
                         presets: "Hazır ayarlar", unsaved: "Kaydedilmedi", savePreset: "Hazır ayar olarak kaydet…",
                         presetName: "Hazır ayar adı", save: "Kaydet", deletePreset: "Hazır ayarı sil",
                         editText: "Metni düzenle…", chooseLogo: "Logo seç…", star: "Satu Visual yıldızı",
                         weight: "Kalınlık", regular: "Normal", medium: "Orta", semibold: "Yarı kalın", bold: "Kalın",
                         caption: "Dönüştür’deki Filigran adımı, fotoğrafları göndermeden önce logo, metin veya ikisiyle işaretler; tek başına ya da Biçim değiştir, Boyutlandır veya Sıkıştır ile birlikte. Her sonuç -wm ile biten yeni bir dosyadır. Varsayılan hazır ayar her yeni bırakmada uygulanır.",
                         defaultPreset: "Varsayılan hazır ayar", none: "Yok",
                         logoMissing: "Bu logo bu Mac’te yok, bu yüzden yıldız kullanılıyor.",
                         clientProof: "Müşteri provası", instagram: "Instagram",
                         positions: ["Sol üst", "Üst", "Sağ üst", "Sol", "Orta", "Sağ", "Sol alt", "Alt", "Sağ alt"])
        case .ru:
            return .init(title: "Водяной знак", scale: "Масштаб", opacity: "Непрозрачность", margin: "Отступ",
                         position: "Положение", content: "Показывать", logo: "Логотип", text: "Текст",
                         logoAndText: "Логотип и текст", color: "Цвет", autoColor: "Автоконтраст",
                         white: "Белый", black: "Чёрный", customColor: "Свой",
                         originalColors: "Цвета логотипа", shadow: "Мягкая тень", tile: "Узор плиткой",
                         presets: "Пресеты", unsaved: "Не сохранён", savePreset: "Сохранить как пресет…",
                         presetName: "Название пресета", save: "Сохранить", deletePreset: "Удалить пресет",
                         editText: "Изменить текст…", chooseLogo: "Выбрать логотип…", star: "Звезда Satu Visual",
                         weight: "Начертание", regular: "Обычный", medium: "Средний", semibold: "Полужирный",
                         bold: "Жирный",
                         caption: "Шаг «Водяной знак» в «Преобразовать» помечает фото логотипом, текстом или обоими перед отправкой, отдельно или вместе с «Формат», «Размер» или «Сжать». Каждый результат сохраняется новым файлом с окончанием -wm. Пресет по умолчанию применяется к каждому новому перетаскиванию.",
                         defaultPreset: "Пресет по умолчанию", none: "Нет",
                         logoMissing: "Этого логотипа нет на этом Mac, поэтому используется звезда.",
                         clientProof: "Превью для клиента", instagram: "Instagram",
                         positions: ["Слева вверху", "Вверху", "Справа вверху", "Слева", "По центру", "Справа",
                                     "Слева внизу", "Внизу", "Справа внизу"])
        case .es:
            return .init(title: "Marca de agua", scale: "Escala", opacity: "Opacidad", margin: "Margen",
                         position: "Posición", content: "Mostrar", logo: "Logo", text: "Texto",
                         logoAndText: "Logo y texto", color: "Color", autoColor: "Contraste automático",
                         white: "Blanco", black: "Negro", customColor: "Personalizado",
                         originalColors: "Colores del propio logo", shadow: "Sombra suave",
                         tile: "Patrón en mosaico", presets: "Preajustes", unsaved: "Sin guardar",
                         savePreset: "Guardar como preajuste…", presetName: "Nombre del preajuste", save: "Guardar",
                         deletePreset: "Eliminar preajuste", editText: "Editar texto…", chooseLogo: "Elegir logo…",
                         star: "Estrella de Satu Visual", weight: "Grosor", regular: "Normal", medium: "Media",
                         semibold: "Seminegrita", bold: "Negrita",
                         caption: "El paso Marca de agua de Transformar marca las fotos con un logo, un texto o ambos antes de enviarlas, solo o junto con Convertir, Redimensionar o Comprimir. Cada resultado es un archivo nuevo que termina en -wm. El preajuste predeterminado se aplica a cada imagen nueva que sueltes.",
                         defaultPreset: "Preajuste predeterminado", none: "Ninguno",
                         logoMissing: "Este logo no está en este Mac, así que se usa la estrella.",
                         clientProof: "Prueba para cliente", instagram: "Instagram",
                         positions: ["Arriba a la izquierda", "Arriba", "Arriba a la derecha", "Izquierda", "Centro",
                                     "Derecha", "Abajo a la izquierda", "Abajo", "Abajo a la derecha"])
        case .sk:
            return .init(title: "Vodoznak", scale: "Mierka", opacity: "Krytie", margin: "Okraj", position: "Poloha",
                         content: "Zobraziť", logo: "Logo", text: "Text", logoAndText: "Logo a text", color: "Farba",
                         autoColor: "Automatický kontrast", white: "Biela", black: "Čierna", customColor: "Vlastná",
                         originalColors: "Vlastné farby loga", shadow: "Jemný tieň", tile: "Dlaždicový vzor",
                         presets: "Predvoľby", unsaved: "Neuložené", savePreset: "Uložiť ako predvoľbu…",
                         presetName: "Názov predvoľby", save: "Uložiť", deletePreset: "Vymazať predvoľbu",
                         editText: "Upraviť text…", chooseLogo: "Vybrať logo…", star: "Hviezda Satu Visual",
                         weight: "Hrúbka", regular: "Normálne", medium: "Stredné", semibold: "Polotučné",
                         bold: "Tučné",
                         caption: "Krok Vodoznak v Transformovať označí fotky logom, textom alebo oboma ešte pred odoslaním, samostatne alebo spolu s Previesť, Zmeniť veľkosť či Komprimovať. Každý výsledok je nový súbor s koncovkou -wm. Východisková predvoľba sa použije pri každom novom pustení.",
                         defaultPreset: "Východisková predvoľba", none: "Žiadna",
                         logoMissing: "Toto logo na tomto Macu nie je, preto sa použije hviezda.",
                         clientProof: "Náhľad pre klienta", instagram: "Instagram",
                         positions: ["Vľavo hore", "Hore", "Vpravo hore", "Vľavo", "Stred", "Vpravo", "Vľavo dole",
                                     "Dole", "Vpravo dole"])
        case .de:
            return .init(title: "Wasserzeichen", scale: "Größe", opacity: "Deckkraft", margin: "Rand",
                         position: "Position", content: "Anzeigen", logo: "Logo", text: "Text",
                         logoAndText: "Logo und Text", color: "Farbe", autoColor: "Automatischer Kontrast",
                         white: "Weiß", black: "Schwarz", customColor: "Eigene",
                         originalColors: "Eigene Farben des Logos", shadow: "Weicher Schatten", tile: "Kachelmuster",
                         presets: "Vorlagen", unsaved: "Nicht gesichert", savePreset: "Als Vorlage sichern…",
                         presetName: "Name der Vorlage", save: "Sichern", deletePreset: "Vorlage löschen",
                         editText: "Text bearbeiten…", chooseLogo: "Logo auswählen…", star: "Satu Visual Stern",
                         weight: "Stärke", regular: "Normal", medium: "Mittel", semibold: "Halbfett", bold: "Fett",
                         caption: "Der Schritt Wasserzeichen in Umwandeln versieht Fotos vor dem Versenden mit einem Logo, einem Text oder beidem, allein oder zusammen mit Konvertieren, Skalieren oder Komprimieren. Jedes Ergebnis ist eine neue Datei, die auf -wm endet. Die Standardvorlage gilt für jedes neue Ablegen.",
                         defaultPreset: "Standardvorlage", none: "Keine",
                         logoMissing: "Dieses Logo ist nicht auf diesem Mac, daher wird der Stern verwendet.",
                         clientProof: "Kundenvorschau", instagram: "Instagram",
                         positions: ["Oben links", "Oben", "Oben rechts", "Links", "Mitte", "Rechts", "Unten links",
                                     "Unten", "Unten rechts"])
        case .fr:
            return .init(title: "Filigrane", scale: "Taille", opacity: "Opacité", margin: "Marge", position: "Position",
                         content: "Afficher", logo: "Logo", text: "Texte", logoAndText: "Logo et texte",
                         color: "Couleur", autoColor: "Contraste auto", white: "Blanc", black: "Noir",
                         customColor: "Personnalisée", originalColors: "Couleurs du logo", shadow: "Ombre douce",
                         tile: "Motif en mosaïque", presets: "Préréglages", unsaved: "Non enregistré",
                         savePreset: "Enregistrer comme préréglage…", presetName: "Nom du préréglage",
                         save: "Enregistrer", deletePreset: "Supprimer le préréglage", editText: "Modifier le texte…",
                         chooseLogo: "Choisir un logo…", star: "Étoile Satu Visual", weight: "Graisse",
                         regular: "Normal", medium: "Moyen", semibold: "Demi-gras", bold: "Gras",
                         caption: "L’étape Filigrane de Transformer marque les photos d’un logo, d’un texte ou des deux avant leur envoi, seule ou avec Convertir, Redimensionner ou Compresser. Chaque résultat est un nouveau fichier qui se termine par -wm. Le préréglage par défaut s’applique à chaque nouveau dépôt.",
                         defaultPreset: "Préréglage par défaut", none: "Aucun",
                         logoMissing: "Ce logo n’est pas sur ce Mac, l’étoile est donc utilisée.",
                         clientProof: "Épreuve client", instagram: "Instagram",
                         positions: ["En haut à gauche", "En haut", "En haut à droite", "À gauche", "Centre",
                                     "À droite", "En bas à gauche", "En bas", "En bas à droite"])
        case .it:
            return .init(title: "Filigrana", scale: "Scala", opacity: "Opacità", margin: "Margine", position: "Posizione",
                         content: "Mostra", logo: "Logo", text: "Testo", logoAndText: "Logo e testo", color: "Colore",
                         autoColor: "Contrasto automatico", white: "Bianco", black: "Nero",
                         customColor: "Personalizzato", originalColors: "Colori del logo", shadow: "Ombra morbida",
                         tile: "Motivo ripetuto", presets: "Preimpostazioni", unsaved: "Non salvata",
                         savePreset: "Salva come preimpostazione…", presetName: "Nome della preimpostazione",
                         save: "Salva", deletePreset: "Elimina preimpostazione", editText: "Modifica testo…",
                         chooseLogo: "Scegli logo…", star: "Stella Satu Visual", weight: "Spessore",
                         regular: "Normale", medium: "Medio", semibold: "Semigrassetto", bold: "Grassetto",
                         caption: "Il passaggio Filigrana di Trasforma marca le foto con un logo, un testo o entrambi prima di inviarle, da solo o insieme a Converti, Ridimensiona o Comprimi. Ogni risultato è un nuovo file che termina con -wm. La preimpostazione predefinita si applica a ogni nuovo rilascio.",
                         defaultPreset: "Preimpostazione predefinita", none: "Nessuna",
                         logoMissing: "Questo logo non è su questo Mac, quindi viene usata la stella.",
                         clientProof: "Bozza per il cliente", instagram: "Instagram",
                         positions: ["In alto a sinistra", "In alto", "In alto a destra", "A sinistra", "Centro",
                                     "A destra", "In basso a sinistra", "In basso", "In basso a destra"])
        case .ja:
            return .init(title: "透かし", scale: "大きさ", opacity: "不透明度", margin: "余白", position: "位置",
                         content: "表示", logo: "ロゴ", text: "テキスト", logoAndText: "ロゴとテキスト", color: "カラー",
                         autoColor: "自動コントラスト", white: "白", black: "黒", customColor: "カスタム",
                         originalColors: "ロゴ本来の色", shadow: "やわらかい影", tile: "タイル模様",
                         presets: "プリセット", unsaved: "未保存", savePreset: "プリセットとして保存…",
                         presetName: "プリセット名", save: "保存", deletePreset: "プリセットを削除",
                         editText: "テキストを編集…", chooseLogo: "ロゴを選択…", star: "Satu Visual の星",
                         weight: "太さ", regular: "レギュラー", medium: "ミディアム", semibold: "セミボールド",
                         bold: "ボールド",
                         caption: "「変換」の「透かし」ステップは、送る前の写真にロゴ、テキスト、またはその両方を入れます。単独でも、「形式」「サイズ」「圧縮」と一緒にも使えます。結果は末尾が -wm の新しいファイルになります。デフォルトのプリセットは新しくドロップするたびに適用されます。",
                         defaultPreset: "デフォルトのプリセット", none: "なし",
                         logoMissing: "このロゴはこの Mac にないため、代わりに星が使われます。",
                         clientProof: "クライアント確認用", instagram: "Instagram",
                         positions: ["左上", "上", "右上", "左", "中央", "右", "左下", "下", "右下"])
        case .ko:
            return .init(title: "워터마크", scale: "크기", opacity: "불투명도", margin: "여백", position: "위치",
                         content: "표시", logo: "로고", text: "텍스트", logoAndText: "로고와 텍스트", color: "색상",
                         autoColor: "자동 대비", white: "흰색", black: "검은색", customColor: "사용자 지정",
                         originalColors: "로고 원래 색상", shadow: "부드러운 그림자", tile: "타일 패턴",
                         presets: "프리셋", unsaved: "저장 안 됨", savePreset: "프리셋으로 저장…",
                         presetName: "프리셋 이름", save: "저장", deletePreset: "프리셋 삭제",
                         editText: "텍스트 편집…", chooseLogo: "로고 선택…", star: "Satu Visual 별",
                         weight: "굵기", regular: "보통", medium: "중간", semibold: "세미볼드", bold: "볼드",
                         caption: "변환의 워터마크 단계는 사진을 보내기 전에 로고, 텍스트 또는 둘 다를 넣습니다. 단독으로 쓰거나 형식 변환, 크기 조절, 압축과 함께 쓸 수 있습니다. 결과는 이름이 -wm으로 끝나는 새 파일입니다. 기본 프리셋은 새로 놓을 때마다 적용됩니다.",
                         defaultPreset: "기본 프리셋", none: "없음",
                         logoMissing: "이 로고가 이 Mac에 없어서 별이 대신 사용됩니다.",
                         clientProof: "클라이언트 시안", instagram: "Instagram",
                         positions: ["왼쪽 위", "위", "오른쪽 위", "왼쪽", "가운데", "오른쪽", "왼쪽 아래", "아래",
                                     "오른쪽 아래"])
        case .uk:
            return .init(title: "Водяний знак", scale: "Масштаб", opacity: "Непрозорість", margin: "Відступ",
                         position: "Положення", content: "Показувати", logo: "Логотип", text: "Текст",
                         logoAndText: "Логотип і текст", color: "Колір", autoColor: "Автоконтраст",
                         white: "Білий", black: "Чорний", customColor: "Власний",
                         originalColors: "Кольори логотипа", shadow: "М’яка тінь", tile: "Візерунок плиткою",
                         presets: "Пресети", unsaved: "Не збережено", savePreset: "Зберегти як пресет…",
                         presetName: "Назва пресета", save: "Зберегти", deletePreset: "Видалити пресет",
                         editText: "Змінити текст…", chooseLogo: "Вибрати логотип…", star: "Зірка Satu Visual",
                         weight: "Накреслення", regular: "Звичайний", medium: "Середній", semibold: "Напівжирний",
                         bold: "Жирний",
                         caption: "Крок «Водяний знак» у «Перетворити» позначає фото логотипом, текстом або обома перед надсиланням, окремо або разом із «Формат», «Розмір» чи «Стиснути». Кожен результат зберігається новим файлом із закінченням -wm. Пресет за замовчуванням застосовується до кожного нового перетягування.",
                         defaultPreset: "Пресет за замовчуванням", none: "Немає",
                         logoMissing: "Цього логотипа немає на цьому Mac, тому використовується зірка.",
                         clientProof: "Перегляд для клієнта", instagram: "Instagram",
                         positions: ["Ліворуч угорі", "Угорі", "Праворуч угорі", "Ліворуч", "По центру", "Праворуч",
                                     "Ліворуч унизу", "Унизу", "Праворуч унизу"])
        case .zhHans:
            return .init(title: "水印", scale: "尺寸", opacity: "不透明度", margin: "边距", position: "位置",
                         content: "显示", logo: "标志", text: "文字", logoAndText: "标志和文字", color: "颜色",
                         autoColor: "自动对比", white: "白色", black: "黑色", customColor: "自定",
                         originalColors: "标志原色", shadow: "柔和阴影", tile: "平铺图案",
                         presets: "预设", unsaved: "未存储", savePreset: "存储为预设…", presetName: "预设名称",
                         save: "存储", deletePreset: "删除预设", editText: "编辑文字…", chooseLogo: "选择标志…",
                         star: "Satu Visual 星标", weight: "字重", regular: "常规", medium: "中等", semibold: "中粗",
                         bold: "粗体",
                         caption: "“转换”中的“水印”步骤会在发送前为照片加上标志、文字或两者，可以单独使用，也可以和“格式”“大小”“压缩”一起使用。每个结果都是以 -wm 结尾的新文件。每次新的拖放都会应用默认预设。",
                         defaultPreset: "默认预设", none: "无",
                         logoMissing: "这台 Mac 上没有这个标志，所以改用星标。",
                         clientProof: "客户校样", instagram: "Instagram",
                         positions: ["左上", "上", "右上", "左", "居中", "右", "左下", "下", "右下"])
        case .zhTW:
            return .init(title: "浮水印", scale: "尺寸", opacity: "不透明度", margin: "邊界", position: "位置",
                         content: "顯示", logo: "標誌", text: "文字", logoAndText: "標誌和文字", color: "顏色",
                         autoColor: "自動對比", white: "白色", black: "黑色", customColor: "自訂",
                         originalColors: "標誌原色", shadow: "柔和陰影", tile: "拼貼圖樣",
                         presets: "樣式", unsaved: "未儲存", savePreset: "儲存為樣式…", presetName: "樣式名稱",
                         save: "儲存", deletePreset: "刪除樣式", editText: "編輯文字…", chooseLogo: "選擇標誌…",
                         star: "Satu Visual 星標", weight: "字重", regular: "標準", medium: "中等", semibold: "中粗",
                         bold: "粗體",
                         caption: "「轉換」中的「浮水印」步驟會在傳送前為照片加上標誌、文字或兩者，可以單獨使用，也可以和「格式」「大小」「壓縮」一起使用。每個結果都是以 -wm 結尾的新檔案。每次新的拖放都會套用預設樣式。",
                         defaultPreset: "預設樣式", none: "無",
                         logoMissing: "這部 Mac 上沒有這個標誌，因此改用星標。",
                         clientProof: "客戶校樣", instagram: "Instagram",
                         positions: ["左上", "上", "右上", "左", "置中", "右", "左下", "下", "右下"])
        case .zhHK:
            return .init(title: "水印", scale: "尺寸", opacity: "不透明度", margin: "邊界", position: "位置",
                         content: "顯示", logo: "標誌", text: "文字", logoAndText: "標誌及文字", color: "顏色",
                         autoColor: "自動對比", white: "白色", black: "黑色", customColor: "自訂",
                         originalColors: "標誌原色", shadow: "柔和陰影", tile: "平鋪圖案",
                         presets: "樣式", unsaved: "未儲存", savePreset: "儲存為樣式…", presetName: "樣式名稱",
                         save: "儲存", deletePreset: "刪除樣式", editText: "編輯文字…", chooseLogo: "選擇標誌…",
                         star: "Satu Visual 星標", weight: "字重", regular: "標準", medium: "中等", semibold: "中粗",
                         bold: "粗體",
                         caption: "「轉換」中的「水印」步驟會在傳送前為相片加上標誌、文字或兩者，可以單獨使用，亦可以與「格式」「大小」「壓縮」一同使用。每個結果都是以 -wm 結尾的新檔案。每次新的拖放都會套用預設樣式。",
                         defaultPreset: "預設樣式", none: "無",
                         logoMissing: "這部 Mac 上沒有這個標誌，因此改用星標。",
                         clientProof: "客戶校樣", instagram: "Instagram",
                         positions: ["左上", "上", "右上", "左", "置中", "右", "左下", "下", "右下"])
        }
    }
}

struct ZenithDesignOverlayStrings {
    let title: String
    let dropZone: String
    let opacity: String
    let normal: String
    let difference: String
    let invert: String
    let scale: String
    let automatic: String
    let grid: String
    let clickThrough: String
    let lock: String
    let fit: String
    let paste: String
    let choose: String
    let close: String
    let moveHint: String
    let alignedPage: String
    let alignedWindow: String
    let noWindow: String
    let needsScreenRecording: String
    let noImage: String
    let caption: String
    let shortcut: String
    let defaultOpacity: String
    let defaultBlend: String
    let gridCaption: String
    let dropToggle: String
    let blendCaption: String
}

extension ZenithStrings {
    /// The design QA overlay (Services/DesignOverlay): its HUD, the island zone and its settings.
    static func designOverlay(_ language: AppLanguage) -> ZenithDesignOverlayStrings {
        switch language {
        case .enUS:
            return .init(title: "Design overlay",
                         dropZone: "Overlay",
                         opacity: "Opacity",
                         normal: "Normal",
                         difference: "Difference",
                         invert: "Invert",
                         scale: "Scale",
                         automatic: "Auto",
                         grid: "Grid",
                         clickThrough: "Click through",
                         lock: "Lock position",
                         fit: "Fit to window under cursor",
                         paste: "Paste image from clipboard",
                         choose: "Choose image…",
                         close: "Close overlay",
                         moveHint: "Arrow keys move 1 pt, Shift moves 10 pt",
                         alignedPage: "Aligned to the page",
                         alignedWindow: "Aligned to the window",
                         noWindow: "No window under the cursor",
                         needsScreenRecording: "Difference needs Screen Recording. Showing Invert for now.",
                         noImage: "No image on the clipboard",
                         caption: "Lay a Figma export over your build at its real size and check it pixel for pixel. Open it with the shortcut, by dropping an image on the island’s Overlay zone, or by pasting a frame copied as PNG.",
                         shortcut: "Keyboard shortcut",
                         defaultOpacity: "Default opacity",
                         defaultBlend: "Default blend",
                         gridCaption: "Columns · gutter · margin, in points",
                         dropToggle: "Overlay zone in the Dynamic Island",
                         blendCaption: "Difference shows black where the build matches. Invert at 50% turns a match grey and needs no permission.")
        case .ptBR:
            return .init(title: "Sobreposição de design",
                         dropZone: "Sobrepor",
                         opacity: "Opacidade",
                         normal: "Normal",
                         difference: "Diferença",
                         invert: "Inverter",
                         scale: "Escala",
                         automatic: "Auto",
                         grid: "Grade",
                         clickThrough: "Clicar através",
                         lock: "Travar posição",
                         fit: "Ajustar à janela sob o cursor",
                         paste: "Colar imagem da área de transferência",
                         choose: "Escolher imagem…",
                         close: "Fechar sobreposição",
                         moveHint: "As setas movem 1 pt, com Shift 10 pt",
                         alignedPage: "Alinhada à página",
                         alignedWindow: "Alinhada à janela",
                         noWindow: "Nenhuma janela sob o cursor",
                         needsScreenRecording: "Diferença precisa de Gravação de Tela. Mostrando Inverter por enquanto.",
                         noImage: "Nenhuma imagem na área de transferência",
                         caption: "Coloque uma exportação do Figma sobre o seu build no tamanho real e confira pixel a pixel. Abra pelo atalho, soltando uma imagem na zona Sobrepor da ilha ou colando um frame copiado como PNG.",
                         shortcut: "Atalho de teclado",
                         defaultOpacity: "Opacidade padrão",
                         defaultBlend: "Mesclagem padrão",
                         gridCaption: "Colunas · medianiz · margem, em pontos",
                         dropToggle: "Zona Sobrepor na Dynamic Island",
                         blendCaption: "Diferença mostra preto onde o build coincide. Inverter a 50% deixa o que coincide cinza e não precisa de permissão.")
        case .tr:
            return .init(title: "Tasarım katmanı",
                         dropZone: "Katman",
                         opacity: "Opaklık",
                         normal: "Normal",
                         difference: "Fark",
                         invert: "Ters çevir",
                         scale: "Ölçek",
                         automatic: "Otomatik",
                         grid: "Izgara",
                         clickThrough: "Tıklamaları geçir",
                         lock: "Konumu kilitle",
                         fit: "İmlecin altındaki pencereye hizala",
                         paste: "Panodaki görüntüyü yapıştır",
                         choose: "Görüntü seç…",
                         close: "Katmanı kapat",
                         moveHint: "Ok tuşları 1 pt, Shift ile 10 pt taşır",
                         alignedPage: "Sayfaya hizalandı",
                         alignedWindow: "Pencereye hizalandı",
                         noWindow: "İmlecin altında pencere yok",
                         needsScreenRecording: "Fark için Ekran Kaydı izni gerekir. Şimdilik Ters çevir gösteriliyor.",
                         noImage: "Panoda görüntü yok",
                         caption: "Bir Figma dışa aktarımını yapınızın üzerine gerçek boyutunda koyun ve piksel piksel karşılaştırın. Kısayolla, adadaki Katman alanına bir görüntü bırakarak ya da PNG olarak kopyalanmış bir çerçeveyi yapıştırarak açın.",
                         shortcut: "Klavye kısayolu",
                         defaultOpacity: "Varsayılan opaklık",
                         defaultBlend: "Varsayılan karışım",
                         gridCaption: "Sütun · oluk · kenar boşluğu, punto cinsinden",
                         dropToggle: "Dynamic Island’da Katman alanı",
                         blendCaption: "Fark, yapının eşleştiği yerleri siyah gösterir. %50’de Ters çevir eşleşen yerleri griye çevirir ve izin gerektirmez.")
        case .ru:
            return .init(title: "Наложение макета",
                         dropZone: "Наложение",
                         opacity: "Непрозрачность",
                         normal: "Обычный",
                         difference: "Разница",
                         invert: "Инверсия",
                         scale: "Масштаб",
                         automatic: "Авто",
                         grid: "Сетка",
                         clickThrough: "Сквозные клики",
                         lock: "Закрепить положение",
                         fit: "Подогнать к окну под курсором",
                         paste: "Вставить изображение из буфера",
                         choose: "Выбрать изображение…",
                         close: "Закрыть наложение",
                         moveHint: "Стрелки сдвигают на 1 pt, с Shift на 10 pt",
                         alignedPage: "Выровнено по странице",
                         alignedWindow: "Выровнено по окну",
                         noWindow: "Под курсором нет окна",
                         needsScreenRecording: "Для разницы нужна запись экрана. Пока показана инверсия.",
                         noImage: "В буфере нет изображения",
                         caption: "Наложите экспорт из Figma на свою вёрстку в реальном размере и сверьте её до пикселя. Откройте сочетанием клавиш, бросьте изображение на зону «Наложение» острова или вставьте фрейм, скопированный как PNG.",
                         shortcut: "Сочетание клавиш",
                         defaultOpacity: "Непрозрачность по умолчанию",
                         defaultBlend: "Режим по умолчанию",
                         gridCaption: "Колонки · промежуток · поля, в пунктах",
                         dropToggle: "Зона «Наложение» в Dynamic Island",
                         blendCaption: "Разница показывает чёрным места, где вёрстка совпадает. Инверсия при 50% делает совпадения серыми и не требует разрешений.")
        case .es:
            return .init(title: "Superposición de diseño",
                         dropZone: "Superponer",
                         opacity: "Opacidad",
                         normal: "Normal",
                         difference: "Diferencia",
                         invert: "Invertir",
                         scale: "Escala",
                         automatic: "Auto",
                         grid: "Cuadrícula",
                         clickThrough: "Clics a través",
                         lock: "Bloquear posición",
                         fit: "Ajustar a la ventana bajo el cursor",
                         paste: "Pegar imagen del portapapeles",
                         choose: "Elegir imagen…",
                         close: "Cerrar superposición",
                         moveHint: "Las flechas mueven 1 pt, con Mayús 10 pt",
                         alignedPage: "Alineada a la página",
                         alignedWindow: "Alineada a la ventana",
                         noWindow: "No hay ninguna ventana bajo el cursor",
                         needsScreenRecording: "Diferencia necesita Grabación de pantalla. Por ahora se muestra Invertir.",
                         noImage: "No hay ninguna imagen en el portapapeles",
                         caption: "Coloca una exportación de Figma sobre tu build a tamaño real y compárala píxel a píxel. Ábrela con el atajo, soltando una imagen en la zona Superponer de la isla o pegando un frame copiado como PNG.",
                         shortcut: "Atajo de teclado",
                         defaultOpacity: "Opacidad predeterminada",
                         defaultBlend: "Fusión predeterminada",
                         gridCaption: "Columnas · medianil · margen, en puntos",
                         dropToggle: "Zona Superponer en la Dynamic Island",
                         blendCaption: "Diferencia muestra en negro lo que coincide con el build. Invertir al 50 % deja gris lo que coincide y no necesita permisos.")
        case .sk:
            return .init(title: "Prekrytie návrhu",
                         dropZone: "Prekryť",
                         opacity: "Krytie",
                         normal: "Normálne",
                         difference: "Rozdiel",
                         invert: "Invertovať",
                         scale: "Mierka",
                         automatic: "Auto",
                         grid: "Mriežka",
                         clickThrough: "Klikanie cez",
                         lock: "Zamknúť polohu",
                         fit: "Zarovnať k oknu pod kurzorom",
                         paste: "Vložiť obrázok zo schránky",
                         choose: "Vybrať obrázok…",
                         close: "Zavrieť prekrytie",
                         moveHint: "Šípky posúvajú o 1 pt, so Shiftom o 10 pt",
                         alignedPage: "Zarovnané k stránke",
                         alignedWindow: "Zarovnané k oknu",
                         noWindow: "Pod kurzorom nie je žiadne okno",
                         needsScreenRecording: "Rozdiel potrebuje Nahrávanie obrazovky. Zatiaľ sa zobrazuje Invertovať.",
                         noImage: "Schránka neobsahuje obrázok",
                         caption: "Položte export z Figmy na svoju stránku v skutočnej veľkosti a porovnajte ich pixel po pixeli. Otvorte ho skratkou, pustením obrázka na zónu Prekryť na ostrove alebo vložením rámca skopírovaného ako PNG.",
                         shortcut: "Klávesová skratka",
                         defaultOpacity: "Predvolené krytie",
                         defaultBlend: "Predvolené prelínanie",
                         gridCaption: "Stĺpce · medzera · okraj, v bodoch",
                         dropToggle: "Zóna Prekryť v Dynamic Island",
                         blendCaption: "Rozdiel ukazuje čiernou miesta, kde sa stránka zhoduje. Invertovať pri 50 % zafarbí zhodu na sivo a nepotrebuje povolenie.")
        case .de:
            return .init(title: "Design-Overlay",
                         dropZone: "Overlay",
                         opacity: "Deckkraft",
                         normal: "Normal",
                         difference: "Differenz",
                         invert: "Umkehren",
                         scale: "Skalierung",
                         automatic: "Auto",
                         grid: "Raster",
                         clickThrough: "Klicks durchlassen",
                         lock: "Position sperren",
                         fit: "An Fenster unter dem Zeiger ausrichten",
                         paste: "Bild aus der Zwischenablage einsetzen",
                         choose: "Bild auswählen …",
                         close: "Overlay schließen",
                         moveHint: "Pfeiltasten bewegen um 1 pt, mit Umschalt um 10 pt",
                         alignedPage: "An der Seite ausgerichtet",
                         alignedWindow: "Am Fenster ausgerichtet",
                         noWindow: "Kein Fenster unter dem Zeiger",
                         needsScreenRecording: "Differenz braucht Bildschirmaufnahme. Bis dahin wird Umkehren gezeigt.",
                         noImage: "Kein Bild in der Zwischenablage",
                         caption: "Leg einen Figma-Export in echter Größe über deinen Build und prüfe ihn Pixel für Pixel. Öffne ihn mit dem Kurzbefehl, durch Ablegen eines Bilds auf der Overlay-Zone der Insel oder durch Einsetzen eines als PNG kopierten Frames.",
                         shortcut: "Tastaturkurzbefehl",
                         defaultOpacity: "Standarddeckkraft",
                         defaultBlend: "Standardmodus",
                         gridCaption: "Spalten · Steg · Rand, in Punkt",
                         dropToggle: "Overlay-Zone in der Dynamic Island",
                         blendCaption: "Differenz zeigt Schwarz, wo der Build übereinstimmt. Umkehren bei 50 % macht Übereinstimmungen grau und braucht keine Berechtigung.")
        case .fr:
            return .init(title: "Calque de maquette",
                         dropZone: "Calque",
                         opacity: "Opacité",
                         normal: "Normal",
                         difference: "Différence",
                         invert: "Inverser",
                         scale: "Échelle",
                         automatic: "Auto",
                         grid: "Grille",
                         clickThrough: "Clics traversants",
                         lock: "Verrouiller la position",
                         fit: "Aligner sur la fenêtre sous le pointeur",
                         paste: "Coller l’image du presse-papiers",
                         choose: "Choisir une image…",
                         close: "Fermer le calque",
                         moveHint: "Les flèches déplacent de 1 pt, avec Maj de 10 pt",
                         alignedPage: "Aligné sur la page",
                         alignedWindow: "Aligné sur la fenêtre",
                         noWindow: "Aucune fenêtre sous le pointeur",
                         needsScreenRecording: "Différence demande l’enregistrement de l’écran. Inverser est affiché en attendant.",
                         noImage: "Aucune image dans le presse-papiers",
                         caption: "Posez un export Figma sur votre build à sa taille réelle et comparez au pixel près. Ouvrez-le avec le raccourci, en déposant une image sur la zone Calque de l’île ou en collant un frame copié en PNG.",
                         shortcut: "Raccourci clavier",
                         defaultOpacity: "Opacité par défaut",
                         defaultBlend: "Fusion par défaut",
                         gridCaption: "Colonnes · gouttière · marge, en points",
                         dropToggle: "Zone Calque dans la Dynamic Island",
                         blendCaption: "Différence affiche en noir ce qui correspond au build. Inverser à 50 % rend gris ce qui correspond et ne demande aucune autorisation.")
        case .it:
            return .init(title: "Sovrapposizione design",
                         dropZone: "Sovrapponi",
                         opacity: "Opacità",
                         normal: "Normale",
                         difference: "Differenza",
                         invert: "Inverti",
                         scale: "Scala",
                         automatic: "Auto",
                         grid: "Griglia",
                         clickThrough: "Clic passanti",
                         lock: "Blocca posizione",
                         fit: "Allinea alla finestra sotto il puntatore",
                         paste: "Incolla immagine dagli appunti",
                         choose: "Scegli immagine…",
                         close: "Chiudi sovrapposizione",
                         moveHint: "Le frecce spostano di 1 pt, con Maiusc di 10 pt",
                         alignedPage: "Allineata alla pagina",
                         alignedWindow: "Allineata alla finestra",
                         noWindow: "Nessuna finestra sotto il puntatore",
                         needsScreenRecording: "Differenza richiede la Registrazione schermo. Per ora viene mostrato Inverti.",
                         noImage: "Nessuna immagine negli appunti",
                         caption: "Metti un export di Figma sopra la tua build a grandezza reale e controllala pixel per pixel. Aprila con l’abbreviazione, trascinando un’immagine sulla zona Sovrapponi dell’isola o incollando un frame copiato come PNG.",
                         shortcut: "Abbreviazione da tastiera",
                         defaultOpacity: "Opacità predefinita",
                         defaultBlend: "Fusione predefinita",
                         gridCaption: "Colonne · canalino · margine, in punti",
                         dropToggle: "Zona Sovrapponi nella Dynamic Island",
                         blendCaption: "Differenza mostra in nero dove la build coincide. Inverti al 50% rende grigio ciò che coincide e non richiede permessi.")
        case .ja:
            return .init(title: "デザインオーバーレイ",
                         dropZone: "オーバーレイ",
                         opacity: "不透明度",
                         normal: "通常",
                         difference: "差の絶対値",
                         invert: "反転",
                         scale: "スケール",
                         automatic: "自動",
                         grid: "グリッド",
                         clickThrough: "クリックを透過",
                         lock: "位置をロック",
                         fit: "ポインタの下のウインドウに合わせる",
                         paste: "クリップボードの画像をペースト",
                         choose: "画像を選択…",
                         close: "オーバーレイを閉じる",
                         moveHint: "矢印キーで1 pt、Shiftで10 pt移動",
                         alignedPage: "ページに合わせました",
                         alignedWindow: "ウインドウに合わせました",
                         noWindow: "ポインタの下にウインドウがありません",
                         needsScreenRecording: "差の絶対値には画面収録が必要です。いまは反転を表示しています。",
                         noImage: "クリップボードに画像がありません",
                         caption: "Figmaの書き出しを実寸でビルドの上に重ね、ピクセル単位で確認します。ショートカット、アイランドの「オーバーレイ」ゾーンへの画像のドロップ、またはPNGとしてコピーしたフレームのペーストで開きます。",
                         shortcut: "キーボードショートカット",
                         defaultOpacity: "デフォルトの不透明度",
                         defaultBlend: "デフォルトの描画モード",
                         gridCaption: "列 · 間隔 · 余白（ポイント）",
                         dropToggle: "Dynamic Islandの「オーバーレイ」ゾーン",
                         blendCaption: "差の絶対値では一致する部分が黒になります。50%の反転では一致する部分がグレーになり、権限は不要です。")
        case .ko:
            return .init(title: "디자인 오버레이",
                         dropZone: "오버레이",
                         opacity: "불투명도",
                         normal: "보통",
                         difference: "차이",
                         invert: "반전",
                         scale: "배율",
                         automatic: "자동",
                         grid: "격자",
                         clickThrough: "클릭 통과",
                         lock: "위치 고정",
                         fit: "포인터 아래 윈도우에 맞추기",
                         paste: "클립보드 이미지 붙여넣기",
                         choose: "이미지 선택…",
                         close: "오버레이 닫기",
                         moveHint: "화살표 키로 1pt, Shift와 함께 10pt 이동",
                         alignedPage: "페이지에 맞춤",
                         alignedWindow: "윈도우에 맞춤",
                         noWindow: "포인터 아래에 윈도우가 없음",
                         needsScreenRecording: "차이를 보려면 화면 기록 권한이 필요합니다. 지금은 반전을 표시합니다.",
                         noImage: "클립보드에 이미지가 없음",
                         caption: "Figma에서 내보낸 이미지를 실제 크기로 빌드 위에 겹쳐 픽셀 단위로 확인합니다. 단축키, 아일랜드의 오버레이 영역에 이미지 놓기, 또는 PNG로 복사한 프레임 붙여넣기로 엽니다.",
                         shortcut: "키보드 단축키",
                         defaultOpacity: "기본 불투명도",
                         defaultBlend: "기본 혼합 모드",
                         gridCaption: "열 · 간격 · 여백(포인트)",
                         dropToggle: "Dynamic Island의 오버레이 영역",
                         blendCaption: "차이는 빌드와 일치하는 부분을 검정으로 보여 줍니다. 50% 반전은 일치하는 부분을 회색으로 만들며 권한이 필요 없습니다.")
        case .uk:
            return .init(title: "Накладання макета",
                         dropZone: "Накладання",
                         opacity: "Непрозорість",
                         normal: "Звичайний",
                         difference: "Різниця",
                         invert: "Інверсія",
                         scale: "Масштаб",
                         automatic: "Авто",
                         grid: "Сітка",
                         clickThrough: "Наскрізні кліки",
                         lock: "Закріпити положення",
                         fit: "Підігнати до вікна під курсором",
                         paste: "Вставити зображення з буфера",
                         choose: "Вибрати зображення…",
                         close: "Закрити накладання",
                         moveHint: "Стрілки зсувають на 1 pt, із Shift на 10 pt",
                         alignedPage: "Вирівняно за сторінкою",
                         alignedWindow: "Вирівняно за вікном",
                         noWindow: "Під курсором немає вікна",
                         needsScreenRecording: "Для різниці потрібен запис екрана. Поки показано інверсію.",
                         noImage: "У буфері немає зображення",
                         caption: "Накладіть експорт із Figma на свою верстку в реальному розмірі й звірте її до пікселя. Відкрийте сполученням клавіш, киньте зображення на зону «Накладання» острова або вставте фрейм, скопійований як PNG.",
                         shortcut: "Сполучення клавіш",
                         defaultOpacity: "Непрозорість за замовчуванням",
                         defaultBlend: "Режим за замовчуванням",
                         gridCaption: "Колонки · проміжок · поля, у пунктах",
                         dropToggle: "Зона «Накладання» в Dynamic Island",
                         blendCaption: "Різниця показує чорним місця, де верстка збігається. Інверсія при 50% робить збіги сірими й не потребує дозволів.")
        case .zhHans:
            return .init(title: "设计叠加层",
                         dropZone: "叠加",
                         opacity: "不透明度",
                         normal: "正常",
                         difference: "差值",
                         invert: "反相",
                         scale: "缩放",
                         automatic: "自动",
                         grid: "网格",
                         clickThrough: "点按穿透",
                         lock: "锁定位置",
                         fit: "对齐指针下的窗口",
                         paste: "粘贴剪贴板中的图像",
                         choose: "选择图像…",
                         close: "关闭叠加层",
                         moveHint: "方向键移动 1 pt，按住 Shift 移动 10 pt",
                         alignedPage: "已对齐页面",
                         alignedWindow: "已对齐窗口",
                         noWindow: "指针下没有窗口",
                         needsScreenRecording: "差值需要屏幕录制权限。暂时显示反相。",
                         noImage: "剪贴板中没有图像",
                         caption: "将 Figma 导出图以实际尺寸叠在你的构建上，逐像素检查。可用快捷键打开，或把图像拖到灵动岛的“叠加”区域，或粘贴以 PNG 拷贝的画框。",
                         shortcut: "键盘快捷键",
                         defaultOpacity: "默认不透明度",
                         defaultBlend: "默认混合模式",
                         gridCaption: "列 · 间距 · 边距（点）",
                         dropToggle: "灵动岛中的“叠加”区域",
                         blendCaption: "差值会把与构建一致的部分显示为黑色。50% 的反相会让一致的部分变灰，且无需权限。")
        case .zhTW:
            return .init(title: "設計疊加層",
                         dropZone: "疊加",
                         opacity: "不透明度",
                         normal: "正常",
                         difference: "差異化",
                         invert: "反轉",
                         scale: "縮放",
                         automatic: "自動",
                         grid: "格線",
                         clickThrough: "點按穿透",
                         lock: "鎖定位置",
                         fit: "對齊指標下的視窗",
                         paste: "貼上剪貼簿中的影像",
                         choose: "選擇影像…",
                         close: "關閉疊加層",
                         moveHint: "方向鍵移動 1 pt，按住 Shift 移動 10 pt",
                         alignedPage: "已對齊頁面",
                         alignedWindow: "已對齊視窗",
                         noWindow: "指標下沒有視窗",
                         needsScreenRecording: "差異化需要螢幕錄製權限。暫時顯示反轉。",
                         noImage: "剪貼簿中沒有影像",
                         caption: "將 Figma 輸出圖以實際尺寸疊在你的建置上，逐像素檢查。可用快速鍵打開，或把影像拖到動態島的「疊加」區域，或貼上以 PNG 拷貝的框架。",
                         shortcut: "鍵盤快速鍵",
                         defaultOpacity: "預設不透明度",
                         defaultBlend: "預設混合模式",
                         gridCaption: "欄 · 間距 · 邊界（點）",
                         dropToggle: "動態島中的「疊加」區域",
                         blendCaption: "差異化會把與建置一致的部分顯示為黑色。50% 的反轉會讓一致的部分變灰，且不需權限。")
        case .zhHK:
            return .init(title: "設計疊加層",
                         dropZone: "疊加",
                         opacity: "不透明度",
                         normal: "正常",
                         difference: "差異化",
                         invert: "反轉",
                         scale: "縮放",
                         automatic: "自動",
                         grid: "格線",
                         clickThrough: "點按穿透",
                         lock: "鎖定位置",
                         fit: "對齊指標下的視窗",
                         paste: "貼上剪貼板中的圖像",
                         choose: "選擇圖像…",
                         close: "關閉疊加層",
                         moveHint: "方向鍵移動 1 pt，按住 Shift 移動 10 pt",
                         alignedPage: "已對齊頁面",
                         alignedWindow: "已對齊視窗",
                         noWindow: "指標下沒有視窗",
                         needsScreenRecording: "差異化需要螢幕錄影權限。暫時顯示反轉。",
                         noImage: "剪貼板中沒有圖像",
                         caption: "將 Figma 輸出圖以實際尺寸疊在你的建置上，逐像素檢查。可用快速鍵打開，或把圖像拖到動態島的「疊加」區域，或貼上以 PNG 拷貝的框架。",
                         shortcut: "鍵盤快速鍵",
                         defaultOpacity: "預設不透明度",
                         defaultBlend: "預設混合模式",
                         gridCaption: "欄 · 間距 · 邊界（點）",
                         dropToggle: "動態島中的「疊加」區域",
                         blendCaption: "差異化會把與建置一致的部分顯示為黑色。50% 的反轉會令一致的部分變灰，而且不需權限。")
        }
    }
}

// MARK: - Screenshot Beautify (Zenith fork)

struct ZenithBeautifyStrings {
    let title: String
    let enterHelp: String
    let backToEdit: String
    let presets: String
    let savePreset: String
    let presetName: String
    let deletePreset: String
    let background: String
    let gradient: String
    let solid: String
    let transparent: String
    let wallpaper: String
    let wallpaperMissing: String
    let customColor: String
    let layout: String
    let padding: String
    let corners: String
    let aspect: String
    let auto: String
    let shadow: String
    let none: String
    let soft: String
    let strong: String
    let windowFrame: String
    let light: String
    let dark: String
    let caption: String
    let captionPlaceholder: String
    let output: String
    let jpegNeedsBackground: String
    let saveBeside: String
    let saveBesideHelp: String
    let ink: String
    let paper: String
    let mist: String
    let peach: String
    let sage: String
    let sky: String
    let sand: String
    let dusk: String
    let settingsCaption: String
    let afterCapture: String
    let afterCaptureCaption: String
}

extension ZenithStrings {
    /// Beautify in the screenshot editor, the capture preview and Settings (ScreenshotBeautify*).
    static func beautify(_ language: AppLanguage) -> ZenithBeautifyStrings {
        switch language {
        case .enUS:
            return .init(title: "Beautify",
                         enterHelp: "Frame the shot for sharing",
                         backToEdit: "Edit",
                         presets: "Presets",
                         savePreset: "Save as Preset…",
                         presetName: "Preset name",
                         deletePreset: "Delete Preset",
                         background: "Background",
                         gradient: "Gradient",
                         solid: "Solid",
                         transparent: "Clear",
                         wallpaper: "Wallpaper",
                         wallpaperMissing: "The desktop picture can’t be read, so a gradient stands in.",
                         customColor: "Custom color",
                         layout: "Layout",
                         padding: "Padding",
                         corners: "Corners",
                         aspect: "Aspect",
                         auto: "Auto",
                         shadow: "Shadow",
                         none: "None",
                         soft: "Soft",
                         strong: "Strong",
                         windowFrame: "Window frame",
                         light: "Light",
                         dark: "Dark",
                         caption: "Caption",
                         captionPlaceholder: "Add a caption",
                         output: "Output",
                         jpegNeedsBackground: "A clear background always saves as PNG.",
                         saveBeside: "Save Beside Original",
                         saveBesideHelp: "Saves next to the original with -beautified in the name, never over a file",
                         ink: "Ink",
                         paper: "Paper",
                         mist: "Mist",
                         peach: "Peach",
                         sage: "Sage",
                         sky: "Sky",
                         sand: "Sand",
                         dusk: "Dusk",
                         settingsCaption: "Frame screenshots for posts and portfolios: a calm background, padding, rounded corners, a shadow, an optional window frame and caption, at the aspect you need. Open it with Beautify in the editor or on the capture preview.",
                         afterCapture: "Beautify after capture",
                         afterCaptureCaption: "Every new screenshot is framed with the style you used last before it’s copied, saved or shown. Edit and Beautify still open the original.")
        case .ptBR:
            return .init(title: "Embelezar",
                         enterHelp: "Enquadrar a captura para compartilhar",
                         backToEdit: "Editar",
                         presets: "Predefinições",
                         savePreset: "Salvar como predefinição…",
                         presetName: "Nome da predefinição",
                         deletePreset: "Apagar predefinição",
                         background: "Fundo",
                         gradient: "Degradê",
                         solid: "Sólido",
                         transparent: "Transparente",
                         wallpaper: "Papel de parede",
                         wallpaperMissing: "Não é possível ler a imagem da mesa, então um degradê a substitui.",
                         customColor: "Cor personalizada",
                         layout: "Layout",
                         padding: "Margem",
                         corners: "Cantos",
                         aspect: "Proporção",
                         auto: "Auto",
                         shadow: "Sombra",
                         none: "Nenhuma",
                         soft: "Suave",
                         strong: "Forte",
                         windowFrame: "Moldura de janela",
                         light: "Clara",
                         dark: "Escura",
                         caption: "Legenda",
                         captionPlaceholder: "Adicionar legenda",
                         output: "Saída",
                         jpegNeedsBackground: "Um fundo transparente sempre é salvo como PNG.",
                         saveBeside: "Salvar ao lado do original",
                         saveBesideHelp: "Salva junto ao original com -beautified no nome, sem substituir nenhum arquivo",
                         ink: "Tinta",
                         paper: "Papel",
                         mist: "Névoa",
                         peach: "Pêssego",
                         sage: "Sálvia",
                         sky: "Céu",
                         sand: "Areia",
                         dusk: "Crepúsculo",
                         settingsCaption: "Enquadre capturas para posts e portfólios: um fundo sereno, margem, cantos arredondados, sombra, moldura de janela e legenda opcionais, na proporção de que você precisa. Abra com Embelezar no editor ou na prévia da captura.",
                         afterCapture: "Embelezar após capturar",
                         afterCaptureCaption: "Cada nova captura recebe o último estilo usado antes de ser copiada, salva ou exibida. Editar e Embelezar continuam abrindo o original.")
        case .tr:
            return .init(title: "Güzelleştir",
                         enterHelp: "Görüntüyü paylaşım için çerçevele",
                         backToEdit: "Düzenle",
                         presets: "Hazır ayarlar",
                         savePreset: "Hazır ayar olarak kaydet…",
                         presetName: "Hazır ayar adı",
                         deletePreset: "Hazır ayarı sil",
                         background: "Arka plan",
                         gradient: "Gradyan",
                         solid: "Düz renk",
                         transparent: "Şeffaf",
                         wallpaper: "Duvar kâğıdı",
                         wallpaperMissing: "Masaüstü resmi okunamıyor, yerine bir gradyan kullanılıyor.",
                         customColor: "Özel renk",
                         layout: "Yerleşim",
                         padding: "Kenar boşluğu",
                         corners: "Köşeler",
                         aspect: "En boy oranı",
                         auto: "Otomatik",
                         shadow: "Gölge",
                         none: "Yok",
                         soft: "Yumuşak",
                         strong: "Güçlü",
                         windowFrame: "Pencere çerçevesi",
                         light: "Açık",
                         dark: "Koyu",
                         caption: "Altyazı",
                         captionPlaceholder: "Altyazı ekle",
                         output: "Çıktı",
                         jpegNeedsBackground: "Şeffaf arka plan her zaman PNG olarak kaydedilir.",
                         saveBeside: "Orijinalin yanına kaydet",
                         saveBesideHelp: "Adına -beautified ekleyerek orijinalin yanına kaydeder, hiçbir dosyanın üzerine yazmaz",
                         ink: "Mürekkep",
                         paper: "Kâğıt",
                         mist: "Sis",
                         peach: "Şeftali",
                         sage: "Adaçayı",
                         sky: "Gökyüzü",
                         sand: "Kum",
                         dusk: "Alacakaranlık",
                         settingsCaption: "Ekran görüntülerini gönderiler ve portfolyolar için çerçeveleyin: sakin bir arka plan, kenar boşluğu, yuvarlatılmış köşeler, gölge, isteğe bağlı pencere çerçevesi ve altyazı, ihtiyacınız olan oranda. Düzenleyicideki veya yakalama önizlemesindeki Güzelleştir ile açın.",
                         afterCapture: "Yakalamadan sonra güzelleştir",
                         afterCaptureCaption: "Her yeni ekran görüntüsü kopyalanmadan, kaydedilmeden veya gösterilmeden önce son kullandığınız stille çerçevelenir. Düzenle ve Güzelleştir yine orijinali açar.")
        case .ru:
            return .init(title: "Оформить",
                         enterHelp: "Оформить снимок для публикации",
                         backToEdit: "Правка",
                         presets: "Пресеты",
                         savePreset: "Сохранить как пресет…",
                         presetName: "Название пресета",
                         deletePreset: "Удалить пресет",
                         background: "Фон",
                         gradient: "Градиент",
                         solid: "Сплошной",
                         transparent: "Прозрачный",
                         wallpaper: "Обои",
                         wallpaperMissing: "Не удаётся прочитать обои рабочего стола, поэтому вместо них используется градиент.",
                         customColor: "Свой цвет",
                         layout: "Компоновка",
                         padding: "Отступ",
                         corners: "Углы",
                         aspect: "Пропорции",
                         auto: "Авто",
                         shadow: "Тень",
                         none: "Нет",
                         soft: "Мягкая",
                         strong: "Сильная",
                         windowFrame: "Рамка окна",
                         light: "Светлая",
                         dark: "Тёмная",
                         caption: "Подпись",
                         captionPlaceholder: "Добавить подпись",
                         output: "Вывод",
                         jpegNeedsBackground: "Прозрачный фон всегда сохраняется в PNG.",
                         saveBeside: "Сохранить рядом с оригиналом",
                         saveBesideHelp: "Сохраняет рядом с оригиналом с -beautified в имени и никогда не перезаписывает файлы",
                         ink: "Чернила",
                         paper: "Бумага",
                         mist: "Дымка",
                         peach: "Персик",
                         sage: "Шалфей",
                         sky: "Небо",
                         sand: "Песок",
                         dusk: "Сумерки",
                         settingsCaption: "Оформляйте снимки экрана для публикаций и портфолио: спокойный фон, отступы, скруглённые углы, тень, рамка окна и подпись по желанию, в нужных пропорциях. Откройте через «Оформить» в редакторе или в превью снимка.",
                         afterCapture: "Оформлять после снимка",
                         afterCaptureCaption: "Каждый новый снимок оформляется в последнем использованном стиле до копирования, сохранения или показа. «Правка» и «Оформить» по-прежнему открывают оригинал.")
        case .es:
            return .init(title: "Embellecer",
                         enterHelp: "Enmarcar la captura para compartirla",
                         backToEdit: "Editar",
                         presets: "Preajustes",
                         savePreset: "Guardar como preajuste…",
                         presetName: "Nombre del preajuste",
                         deletePreset: "Eliminar preajuste",
                         background: "Fondo",
                         gradient: "Degradado",
                         solid: "Sólido",
                         transparent: "Transparente",
                         wallpaper: "Fondo de pantalla",
                         wallpaperMissing: "No se puede leer la imagen del escritorio, así que se usa un degradado.",
                         customColor: "Color personalizado",
                         layout: "Diseño",
                         padding: "Margen",
                         corners: "Esquinas",
                         aspect: "Proporción",
                         auto: "Auto",
                         shadow: "Sombra",
                         none: "Ninguna",
                         soft: "Suave",
                         strong: "Intensa",
                         windowFrame: "Marco de ventana",
                         light: "Claro",
                         dark: "Oscuro",
                         caption: "Pie de foto",
                         captionPlaceholder: "Añadir pie de foto",
                         output: "Salida",
                         jpegNeedsBackground: "Un fondo transparente siempre se guarda como PNG.",
                         saveBeside: "Guardar junto al original",
                         saveBesideHelp: "Guarda junto al original con -beautified en el nombre, sin sobrescribir ningún archivo",
                         ink: "Tinta",
                         paper: "Papel",
                         mist: "Niebla",
                         peach: "Melocotón",
                         sage: "Salvia",
                         sky: "Cielo",
                         sand: "Arena",
                         dusk: "Anochecer",
                         settingsCaption: "Enmarca capturas para publicaciones y portafolios: un fondo sereno, margen, esquinas redondeadas, sombra, marco de ventana y pie de foto opcionales, en la proporción que necesites. Ábrelo con Embellecer en el editor o en la vista previa de la captura.",
                         afterCapture: "Embellecer tras capturar",
                         afterCaptureCaption: "Cada captura nueva se enmarca con el último estilo que usaste antes de copiarla, guardarla o mostrarla. Editar y Embellecer siguen abriendo el original.")
        case .sk:
            return .init(title: "Skrášliť",
                         enterHelp: "Orámovať snímku na zdieľanie",
                         backToEdit: "Upraviť",
                         presets: "Predvoľby",
                         savePreset: "Uložiť ako predvoľbu…",
                         presetName: "Názov predvoľby",
                         deletePreset: "Vymazať predvoľbu",
                         background: "Pozadie",
                         gradient: "Prechod",
                         solid: "Plná farba",
                         transparent: "Priehľadné",
                         wallpaper: "Tapeta",
                         wallpaperMissing: "Obrázok plochy sa nedá prečítať, preto ho nahrádza prechod.",
                         customColor: "Vlastná farba",
                         layout: "Rozloženie",
                         padding: "Okraj",
                         corners: "Rohy",
                         aspect: "Pomer strán",
                         auto: "Auto",
                         shadow: "Tieň",
                         none: "Žiadny",
                         soft: "Jemný",
                         strong: "Výrazný",
                         windowFrame: "Rám okna",
                         light: "Svetlý",
                         dark: "Tmavý",
                         caption: "Popis",
                         captionPlaceholder: "Pridať popis",
                         output: "Výstup",
                         jpegNeedsBackground: "Priehľadné pozadie sa vždy ukladá ako PNG.",
                         saveBeside: "Uložiť vedľa originálu",
                         saveBesideHelp: "Uloží vedľa originálu s -beautified v názve a nikdy neprepíše súbor",
                         ink: "Atrament",
                         paper: "Papier",
                         mist: "Hmla",
                         peach: "Broskyňa",
                         sage: "Šalvia",
                         sky: "Obloha",
                         sand: "Piesok",
                         dusk: "Súmrak",
                         settingsCaption: "Orámujte snímky obrazovky pre príspevky a portfóliá: pokojné pozadie, okraj, zaoblené rohy, tieň, voliteľný rám okna a popis, v pomere strán, ktorý potrebujete. Otvorte cez Skrášliť v editore alebo v náhľade snímky.",
                         afterCapture: "Skrášliť po zachytení",
                         afterCaptureCaption: "Každá nová snímka sa pred skopírovaním, uložením alebo zobrazením orámuje naposledy použitým štýlom. Upraviť a Skrášliť stále otvárajú originál.")
        case .de:
            return .init(title: "Verschönern",
                         enterHelp: "Aufnahme zum Teilen einrahmen",
                         backToEdit: "Bearbeiten",
                         presets: "Vorlagen",
                         savePreset: "Als Vorlage sichern…",
                         presetName: "Name der Vorlage",
                         deletePreset: "Vorlage löschen",
                         background: "Hintergrund",
                         gradient: "Verlauf",
                         solid: "Einfarbig",
                         transparent: "Transparent",
                         wallpaper: "Hintergrundbild",
                         wallpaperMissing: "Das Schreibtischbild kann nicht gelesen werden, daher springt ein Verlauf ein.",
                         customColor: "Eigene Farbe",
                         layout: "Layout",
                         padding: "Rand",
                         corners: "Ecken",
                         aspect: "Seitenverhältnis",
                         auto: "Auto",
                         shadow: "Schatten",
                         none: "Keiner",
                         soft: "Weich",
                         strong: "Stark",
                         windowFrame: "Fensterrahmen",
                         light: "Hell",
                         dark: "Dunkel",
                         caption: "Bildunterschrift",
                         captionPlaceholder: "Bildunterschrift hinzufügen",
                         output: "Ausgabe",
                         jpegNeedsBackground: "Ein transparenter Hintergrund wird immer als PNG gesichert.",
                         saveBeside: "Neben Original sichern",
                         saveBesideHelp: "Sichert neben dem Original mit -beautified im Namen und überschreibt nie eine Datei",
                         ink: "Tinte",
                         paper: "Papier",
                         mist: "Nebel",
                         peach: "Pfirsich",
                         sage: "Salbei",
                         sky: "Himmel",
                         sand: "Sand",
                         dusk: "Dämmerung",
                         settingsCaption: "Rahme Bildschirmfotos für Posts und Portfolios ein: ruhiger Hintergrund, Rand, abgerundete Ecken, Schatten, optional Fensterrahmen und Bildunterschrift, im gewünschten Seitenverhältnis. Öffne es mit „Verschönern“ im Editor oder in der Vorschau der Aufnahme.",
                         afterCapture: "Nach der Aufnahme verschönern",
                         afterCaptureCaption: "Jedes neue Bildschirmfoto wird vor dem Kopieren, Sichern oder Anzeigen im zuletzt genutzten Stil eingerahmt. „Bearbeiten“ und „Verschönern“ öffnen weiterhin das Original.")
        case .fr:
            return .init(title: "Embellir",
                         enterHelp: "Encadrer la capture pour la partager",
                         backToEdit: "Modifier",
                         presets: "Préréglages",
                         savePreset: "Enregistrer comme préréglage…",
                         presetName: "Nom du préréglage",
                         deletePreset: "Supprimer le préréglage",
                         background: "Arrière-plan",
                         gradient: "Dégradé",
                         solid: "Uni",
                         transparent: "Transparent",
                         wallpaper: "Fond d’écran",
                         wallpaperMissing: "Impossible de lire l’image du bureau, un dégradé la remplace.",
                         customColor: "Couleur personnalisée",
                         layout: "Mise en page",
                         padding: "Marge",
                         corners: "Coins",
                         aspect: "Format",
                         auto: "Auto",
                         shadow: "Ombre",
                         none: "Aucune",
                         soft: "Douce",
                         strong: "Marquée",
                         windowFrame: "Cadre de fenêtre",
                         light: "Clair",
                         dark: "Sombre",
                         caption: "Légende",
                         captionPlaceholder: "Ajouter une légende",
                         output: "Sortie",
                         jpegNeedsBackground: "Un arrière-plan transparent est toujours enregistré en PNG.",
                         saveBeside: "Enregistrer à côté de l’original",
                         saveBesideHelp: "Enregistre à côté de l’original avec -beautified dans le nom, sans jamais écraser de fichier",
                         ink: "Encre",
                         paper: "Papier",
                         mist: "Brume",
                         peach: "Pêche",
                         sage: "Sauge",
                         sky: "Ciel",
                         sand: "Sable",
                         dusk: "Crépuscule",
                         settingsCaption: "Encadrez vos captures pour vos publications et portfolios : un fond apaisé, une marge, des coins arrondis, une ombre, un cadre de fenêtre et une légende en option, au format voulu. Ouvrez-le avec Embellir dans l’éditeur ou dans l’aperçu de la capture.",
                         afterCapture: "Embellir après la capture",
                         afterCaptureCaption: "Chaque nouvelle capture est encadrée avec le dernier style utilisé avant d’être copiée, enregistrée ou affichée. Modifier et Embellir ouvrent toujours l’original.")
        case .it:
            return .init(title: "Abbellisci",
                         enterHelp: "Incornicia lo scatto per condividerlo",
                         backToEdit: "Modifica",
                         presets: "Preimpostazioni",
                         savePreset: "Salva come preimpostazione…",
                         presetName: "Nome della preimpostazione",
                         deletePreset: "Elimina preimpostazione",
                         background: "Sfondo",
                         gradient: "Sfumatura",
                         solid: "Tinta unita",
                         transparent: "Trasparente",
                         wallpaper: "Sfondo scrivania",
                         wallpaperMissing: "Impossibile leggere l’immagine della scrivania, al suo posto c’è una sfumatura.",
                         customColor: "Colore personalizzato",
                         layout: "Layout",
                         padding: "Margine",
                         corners: "Angoli",
                         aspect: "Proporzioni",
                         auto: "Auto",
                         shadow: "Ombra",
                         none: "Nessuna",
                         soft: "Morbida",
                         strong: "Intensa",
                         windowFrame: "Cornice finestra",
                         light: "Chiara",
                         dark: "Scura",
                         caption: "Didascalia",
                         captionPlaceholder: "Aggiungi una didascalia",
                         output: "Output",
                         jpegNeedsBackground: "Uno sfondo trasparente viene sempre salvato in PNG.",
                         saveBeside: "Salva accanto all’originale",
                         saveBesideHelp: "Salva accanto all’originale con -beautified nel nome, senza mai sovrascrivere un file",
                         ink: "Inchiostro",
                         paper: "Carta",
                         mist: "Foschia",
                         peach: "Pesca",
                         sage: "Salvia",
                         sky: "Cielo",
                         sand: "Sabbia",
                         dusk: "Crepuscolo",
                         settingsCaption: "Incornicia le schermate per post e portfolio: uno sfondo calmo, margini, angoli arrotondati, un’ombra, cornice finestra e didascalia facoltative, nelle proporzioni che ti servono. Aprilo con Abbellisci nell’editor o nell’anteprima della cattura.",
                         afterCapture: "Abbellisci dopo la cattura",
                         afterCaptureCaption: "Ogni nuova schermata viene incorniciata con l’ultimo stile usato prima di essere copiata, salvata o mostrata. Modifica e Abbellisci aprono comunque l’originale.")
        case .ja:
            return .init(title: "仕上げ",
                         enterHelp: "共有用にショットを整える",
                         backToEdit: "編集",
                         presets: "プリセット",
                         savePreset: "プリセットとして保存…",
                         presetName: "プリセット名",
                         deletePreset: "プリセットを削除",
                         background: "背景",
                         gradient: "グラデーション",
                         solid: "単色",
                         transparent: "透明",
                         wallpaper: "壁紙",
                         wallpaperMissing: "デスクトップピクチャを読み込めないため、グラデーションで代用しています。",
                         customColor: "カスタムカラー",
                         layout: "レイアウト",
                         padding: "余白",
                         corners: "角",
                         aspect: "縦横比",
                         auto: "自動",
                         shadow: "シャドウ",
                         none: "なし",
                         soft: "ソフト",
                         strong: "強め",
                         windowFrame: "ウインドウフレーム",
                         light: "ライト",
                         dark: "ダーク",
                         caption: "キャプション",
                         captionPlaceholder: "キャプションを追加",
                         output: "出力",
                         jpegNeedsBackground: "透明な背景は常にPNGで保存されます。",
                         saveBeside: "元のファイルの隣に保存",
                         saveBesideHelp: "名前に -beautified を付けて元のファイルの隣に保存し、既存のファイルは上書きしません",
                         ink: "インク",
                         paper: "ペーパー",
                         mist: "ミスト",
                         peach: "ピーチ",
                         sage: "セージ",
                         sky: "スカイ",
                         sand: "サンド",
                         dusk: "ダスク",
                         settingsCaption: "投稿やポートフォリオ用にスクリーンショットを整えます。落ち着いた背景、余白、角丸、シャドウ、必要に応じてウインドウフレームとキャプションを付け、好きな縦横比にできます。エディタまたはキャプチャのプレビューの「仕上げ」から開けます。",
                         afterCapture: "キャプチャ後に仕上げる",
                         afterCaptureCaption: "新しいスクリーンショットは、コピー・保存・表示の前に、最後に使ったスタイルで仕上げられます。「編集」と「仕上げ」では引き続き元の画像が開きます。")
        case .ko:
            return .init(title: "꾸미기",
                         enterHelp: "공유용으로 스크린샷 꾸미기",
                         backToEdit: "편집",
                         presets: "프리셋",
                         savePreset: "프리셋으로 저장…",
                         presetName: "프리셋 이름",
                         deletePreset: "프리셋 삭제",
                         background: "배경",
                         gradient: "그라디언트",
                         solid: "단색",
                         transparent: "투명",
                         wallpaper: "배경화면",
                         wallpaperMissing: "데스크탑 사진을 읽을 수 없어 그라디언트로 대신합니다.",
                         customColor: "사용자 색상",
                         layout: "레이아웃",
                         padding: "여백",
                         corners: "모서리",
                         aspect: "화면비",
                         auto: "자동",
                         shadow: "그림자",
                         none: "없음",
                         soft: "부드럽게",
                         strong: "강하게",
                         windowFrame: "윈도우 프레임",
                         light: "밝게",
                         dark: "어둡게",
                         caption: "캡션",
                         captionPlaceholder: "캡션 추가",
                         output: "출력",
                         jpegNeedsBackground: "투명 배경은 항상 PNG로 저장됩니다.",
                         saveBeside: "원본 옆에 저장",
                         saveBesideHelp: "이름에 -beautified를 붙여 원본 옆에 저장하며 파일을 덮어쓰지 않습니다",
                         ink: "잉크",
                         paper: "페이퍼",
                         mist: "미스트",
                         peach: "피치",
                         sage: "세이지",
                         sky: "스카이",
                         sand: "샌드",
                         dusk: "더스크",
                         settingsCaption: "게시물과 포트폴리오용으로 스크린샷을 꾸밉니다. 차분한 배경, 여백, 둥근 모서리, 그림자, 선택적인 윈도우 프레임과 캡션을 원하는 화면비로 적용합니다. 편집기나 캡처 미리보기에서 꾸미기로 엽니다.",
                         afterCapture: "캡처 후 꾸미기",
                         afterCaptureCaption: "새 스크린샷은 복사, 저장 또는 표시되기 전에 마지막으로 사용한 스타일로 꾸며집니다. 편집과 꾸미기는 여전히 원본을 엽니다.")
        case .uk:
            return .init(title: "Оформити",
                         enterHelp: "Оформити знімок для публікації",
                         backToEdit: "Редагувати",
                         presets: "Пресети",
                         savePreset: "Зберегти як пресет…",
                         presetName: "Назва пресета",
                         deletePreset: "Видалити пресет",
                         background: "Тло",
                         gradient: "Градієнт",
                         solid: "Суцільне",
                         transparent: "Прозоре",
                         wallpaper: "Шпалери",
                         wallpaperMissing: "Не вдається прочитати шпалери робочого столу, тож замість них використовується градієнт.",
                         customColor: "Власний колір",
                         layout: "Компонування",
                         padding: "Відступ",
                         corners: "Кути",
                         aspect: "Пропорції",
                         auto: "Авто",
                         shadow: "Тінь",
                         none: "Немає",
                         soft: "М’яка",
                         strong: "Сильна",
                         windowFrame: "Рамка вікна",
                         light: "Світла",
                         dark: "Темна",
                         caption: "Підпис",
                         captionPlaceholder: "Додати підпис",
                         output: "Вивід",
                         jpegNeedsBackground: "Прозоре тло завжди зберігається як PNG.",
                         saveBeside: "Зберегти поруч з оригіналом",
                         saveBesideHelp: "Зберігає поруч з оригіналом з -beautified у назві й ніколи не перезаписує файли",
                         ink: "Чорнило",
                         paper: "Папір",
                         mist: "Серпанок",
                         peach: "Персик",
                         sage: "Шавлія",
                         sky: "Небо",
                         sand: "Пісок",
                         dusk: "Сутінки",
                         settingsCaption: "Оформлюйте знімки екрана для публікацій і портфоліо: спокійне тло, відступи, заокруглені кути, тінь, рамка вікна й підпис за бажанням, у потрібних пропорціях. Відкрийте через «Оформити» в редакторі або в попередньому перегляді знімка.",
                         afterCapture: "Оформлювати після знімка",
                         afterCaptureCaption: "Кожен новий знімок оформлюється в останньому використаному стилі до копіювання, збереження чи показу. «Редагувати» й «Оформити» й далі відкривають оригінал.")
        case .zhHans:
            return .init(title: "美化",
                         enterHelp: "为分享美化截图",
                         backToEdit: "编辑",
                         presets: "预设",
                         savePreset: "存储为预设…",
                         presetName: "预设名称",
                         deletePreset: "删除预设",
                         background: "背景",
                         gradient: "渐变",
                         solid: "纯色",
                         transparent: "透明",
                         wallpaper: "墙纸",
                         wallpaperMissing: "无法读取桌面图片，因此改用渐变。",
                         customColor: "自定颜色",
                         layout: "布局",
                         padding: "边距",
                         corners: "圆角",
                         aspect: "宽高比",
                         auto: "自动",
                         shadow: "阴影",
                         none: "无",
                         soft: "柔和",
                         strong: "浓重",
                         windowFrame: "窗口边框",
                         light: "浅色",
                         dark: "深色",
                         caption: "说明文字",
                         captionPlaceholder: "添加说明文字",
                         output: "输出",
                         jpegNeedsBackground: "透明背景始终存储为 PNG。",
                         saveBeside: "存储到原图旁边",
                         saveBesideHelp: "在原图旁边存储，名称加上 -beautified，绝不覆盖文件",
                         ink: "墨",
                         paper: "纸",
                         mist: "薄雾",
                         peach: "蜜桃",
                         sage: "鼠尾草",
                         sky: "天空",
                         sand: "沙",
                         dusk: "暮色",
                         settingsCaption: "为帖子和作品集美化截图：沉静的背景、边距、圆角、阴影，以及可选的窗口边框和说明文字，并采用你需要的宽高比。在编辑器或截图预览中点按“美化”即可打开。",
                         afterCapture: "截图后美化",
                         afterCaptureCaption: "每张新截图在拷贝、存储或显示之前，都会套用你上次使用的样式。“编辑”和“美化”仍会打开原图。")
        case .zhTW:
            return .init(title: "美化",
                         enterHelp: "為分享美化截圖",
                         backToEdit: "編輯",
                         presets: "預設組",
                         savePreset: "儲存為預設組…",
                         presetName: "預設組名稱",
                         deletePreset: "刪除預設組",
                         background: "背景",
                         gradient: "漸層",
                         solid: "純色",
                         transparent: "透明",
                         wallpaper: "背景圖片",
                         wallpaperMissing: "無法讀取桌面圖片，因此改用漸層。",
                         customColor: "自訂顏色",
                         layout: "佈局",
                         padding: "邊距",
                         corners: "圓角",
                         aspect: "長寬比",
                         auto: "自動",
                         shadow: "陰影",
                         none: "無",
                         soft: "柔和",
                         strong: "濃重",
                         windowFrame: "視窗邊框",
                         light: "淺色",
                         dark: "深色",
                         caption: "說明文字",
                         captionPlaceholder: "加入說明文字",
                         output: "輸出",
                         jpegNeedsBackground: "透明背景一律儲存為 PNG。",
                         saveBeside: "儲存在原圖旁邊",
                         saveBesideHelp: "在原圖旁邊儲存，名稱加上 -beautified，絕不覆寫檔案",
                         ink: "墨",
                         paper: "紙",
                         mist: "薄霧",
                         peach: "蜜桃",
                         sage: "鼠尾草",
                         sky: "天空",
                         sand: "沙",
                         dusk: "暮色",
                         settingsCaption: "為貼文和作品集美化截圖：沉靜的背景、邊距、圓角、陰影，以及可選的視窗邊框和說明文字，並採用你需要的長寬比。在編輯器或截圖預覽中按一下「美化」即可打開。",
                         afterCapture: "截圖後美化",
                         afterCaptureCaption: "每張新截圖在拷貝、儲存或顯示之前，都會套用你上次使用的樣式。「編輯」和「美化」仍會打開原圖。")
        case .zhHK:
            return .init(title: "美化",
                         enterHelp: "為分享美化截圖",
                         backToEdit: "編輯",
                         presets: "預設",
                         savePreset: "儲存為預設…",
                         presetName: "預設名稱",
                         deletePreset: "刪除預設",
                         background: "背景",
                         gradient: "漸變",
                         solid: "純色",
                         transparent: "透明",
                         wallpaper: "牆紙",
                         wallpaperMissing: "無法讀取桌面圖片，所以改用漸變。",
                         customColor: "自訂顏色",
                         layout: "佈局",
                         padding: "邊距",
                         corners: "圓角",
                         aspect: "長闊比",
                         auto: "自動",
                         shadow: "陰影",
                         none: "無",
                         soft: "柔和",
                         strong: "濃重",
                         windowFrame: "視窗邊框",
                         light: "淺色",
                         dark: "深色",
                         caption: "說明文字",
                         captionPlaceholder: "加入說明文字",
                         output: "輸出",
                         jpegNeedsBackground: "透明背景一律儲存為 PNG。",
                         saveBeside: "儲存在原圖旁邊",
                         saveBesideHelp: "在原圖旁邊儲存，名稱加上 -beautified，絕不覆寫檔案",
                         ink: "墨",
                         paper: "紙",
                         mist: "薄霧",
                         peach: "蜜桃",
                         sage: "鼠尾草",
                         sky: "天空",
                         sand: "沙",
                         dusk: "暮色",
                         settingsCaption: "為帖子和作品集美化截圖：沉靜的背景、邊距、圓角、陰影，以及可選的視窗邊框和說明文字，並採用你需要的長闊比。在編輯器或截圖預覽中按一下「美化」即可打開。",
                         afterCapture: "截圖後美化",
                         afterCaptureCaption: "每張新截圖在拷貝、儲存或顯示之前，都會套用你上次使用的樣式。「編輯」和「美化」仍會打開原圖。")
        }
    }
}

struct ZenithCameraStrings {
    let autoStart: String
    let autoStartCaption: String
    let starting: String
}

extension ZenithStrings {
    /// The island's Camera page starting its mirror by itself (ZenithCameraAutoStart).
    static func camera(_ language: AppLanguage) -> ZenithCameraStrings {
        switch language {
        case .enUS:
            return .init(autoStart: "Start the mirror automatically",
                         autoStartCaption: "Once camera access is allowed, the Camera page shows the live mirror as soon as it opens. The camera still stops when you leave the page or close the island.",
                         starting: "Starting the camera")
        case .ptBR:
            return .init(autoStart: "Iniciar o espelho automaticamente",
                         autoStartCaption: "Com o acesso à câmera permitido, a página Câmera mostra o espelho ao vivo assim que abre. A câmera continua parando quando você sai da página ou fecha a ilha.",
                         starting: "Iniciando a câmera")
        case .tr:
            return .init(autoStart: "Aynayı otomatik başlat",
                         autoStartCaption: "Kamera erişimine izin verildiğinde Kamera sayfası açılır açılmaz canlı aynayı gösterir. Sayfadan ayrıldığında veya adayı kapattığında kamera yine durur.",
                         starting: "Kamera başlatılıyor")
        case .ru:
            return .init(autoStart: "Запускать зеркало автоматически",
                         autoStartCaption: "Если доступ к камере разрешён, страница «Камера» показывает живое зеркало сразу при открытии. Камера по-прежнему выключается, когда вы уходите со страницы или закрываете остров.",
                         starting: "Запуск камеры")
        case .es:
            return .init(autoStart: "Iniciar el espejo automáticamente",
                         autoStartCaption: "Con el acceso a la cámara permitido, la página Cámara muestra el espejo en vivo en cuanto se abre. La cámara se sigue deteniendo al salir de la página o cerrar la isla.",
                         starting: "Iniciando la cámara")
        case .sk:
            return .init(autoStart: "Spúšťať zrkadlo automaticky",
                         autoStartCaption: "Keď je prístup ku kamere povolený, stránka Kamera ukáže živé zrkadlo hneď po otvorení. Kamera sa stále vypne, keď stránku opustíte alebo zatvoríte ostrov.",
                         starting: "Spúšťa sa kamera")
        case .de:
            return .init(autoStart: "Spiegel automatisch starten",
                         autoStartCaption: "Ist der Kamerazugriff erlaubt, zeigt die Seite „Kamera“ den Live-Spiegel, sobald sie aufgeht. Die Kamera stoppt weiterhin, wenn du die Seite verlässt oder die Insel schließt.",
                         starting: "Kamera wird gestartet")
        case .fr:
            return .init(autoStart: "Lancer le miroir automatiquement",
                         autoStartCaption: "Une fois l’accès à la caméra autorisé, la page Caméra affiche le miroir en direct dès son ouverture. La caméra s’arrête toujours quand vous quittez la page ou fermez l’île.",
                         starting: "Démarrage de la caméra")
        case .it:
            return .init(autoStart: "Avvia lo specchio automaticamente",
                         autoStartCaption: "Con l’accesso alla fotocamera consentito, la pagina Fotocamera mostra lo specchio dal vivo appena si apre. La fotocamera si ferma comunque quando lasci la pagina o chiudi l’isola.",
                         starting: "Avvio della fotocamera")
        case .ja:
            return .init(autoStart: "ミラーを自動で開始",
                         autoStartCaption: "カメラへのアクセスが許可されていれば、カメラページを開くとすぐにライブミラーを表示します。ページを離れるかアイランドを閉じると、これまでどおりカメラは停止します。",
                         starting: "カメラを起動中")
        case .ko:
            return .init(autoStart: "미러 자동 시작",
                         autoStartCaption: "카메라 접근이 허용되어 있으면 카메라 페이지를 열자마자 라이브 미러를 보여줍니다. 페이지를 떠나거나 아일랜드를 닫으면 카메라는 계속 꺼집니다.",
                         starting: "카메라 시작 중")
        case .uk:
            return .init(autoStart: "Запускати дзеркало автоматично",
                         autoStartCaption: "Якщо доступ до камери дозволено, сторінка «Камера» показує живе дзеркало одразу після відкриття. Камера й надалі вимикається, коли ви йдете зі сторінки або закриваєте острів.",
                         starting: "Запуск камери")
        case .zhHans:
            return .init(autoStart: "自动开启镜像",
                         autoStartCaption: "允许访问摄像头后，“摄像头”页面一打开就显示实时镜像。离开该页面或关闭灵动岛时，摄像头仍会停止。",
                         starting: "正在启动摄像头")
        case .zhTW:
            return .init(autoStart: "自動開啟鏡像",
                         autoStartCaption: "允許取用相機後，「相機」頁面一打開就會顯示即時鏡像。離開頁面或關閉動態島時，相機仍會停止。",
                         starting: "正在啟動相機")
        case .zhHK:
            return .init(autoStart: "自動開啟鏡像",
                         autoStartCaption: "允許存取相機後，「相機」頁面一打開便會顯示即時鏡像。離開頁面或關閉動態島時，相機仍會停止。",
                         starting: "正在啟動相機")
        }
    }
}

// MARK: - Menu bar hider (Zenith fork)

/// Settings, the chevron's menu and the shortcut of the menu bar hider
/// (MenuBarHiderService, MenuBarHiderSettingsSection).
struct ZenithMenuBarHiderStrings {
    let title: String
    let enable: String
    let enableCaption: String
    let alwaysHidden: String
    let alwaysHiddenCaption: String
    let delay: String
    let delayCaption: String
    /// %d is 5, 10 or 30.
    let secondsFormat: String
    let never: String
    let clickOutside: String
    let hover: String
    let hoverCaption: String
    let notch: String
    let notchCaption: String
    /// %@ lists the apps, comma-separated.
    let behindNotch: String
    let shortcutToggle: String
    let shortcut: String
    let shortcutFailed: String
    let howTo: String
    let stepDrag: String
    let stepClick: String
    let stepAlways: String
    let hiddenLabel: String
    let visibleLabel: String
    let iconInside: String
    let chevronInside: String
    let alwaysOutside: String
    let showHidden: String
    let showAll: String
    let hide: String
    let settings: String
    let chevronHelp: String
    let dividerLabel: String
    let alwaysDividerLabel: String
}

extension ZenithStrings {
    static func menuBarHider(_ language: AppLanguage) -> ZenithMenuBarHiderStrings {
        switch language {
        case .enUS:
            return .init(title: "Menu bar hiding",
                         enable: "Enable menu bar hiding",
                         enableCaption: "Adds a chevron and a divider to the menu bar. Icons left of the divider tuck away until you click the chevron.",
                         alwaysHidden: "Always hidden section",
                         alwaysHiddenCaption: "Adds a second, dotted divider. Icons left of it stay hidden until you ⌥-click the chevron.",
                         delay: "Hide again after",
                         delayCaption: "Icons also hide when the Mac locks, but never while one of their menus is open.",
                         secondsFormat: "%d seconds",
                         never: "Never",
                         clickOutside: "Hide when clicking elsewhere",
                         hover: "Show on hover",
                         hoverCaption: "Rest the pointer on an empty part of the menu bar to show hidden icons.",
                         notch: "Hide items that would sit behind the notch",
                         notchCaption: "When ⌥-click would put always hidden icons behind the camera, only the hidden section shows.",
                         behindNotch: "Behind the notch right now: %@",
                         shortcutToggle: "Keyboard shortcut",
                         shortcut: "Show or hide menu bar icons",
                         shortcutFailed: "macOS refused this shortcut. Another app may be using it.",
                         howTo: "How to arrange",
                         stepDrag: "Hold ⌘ and drag an icon left of the divider to hide it. Drag it back to the right to keep it in view.",
                         stepClick: "Click the chevron, or an empty part of the menu bar, to show or hide the icons.",
                         stepAlways: "Icons left of the dotted divider stay hidden until you ⌥-click the chevron. ⌥-click it to arrange them.",
                         hiddenLabel: "Hidden",
                         visibleLabel: "Visible",
                         iconInside: "Zenith’s icon is left of the divider, so nothing hides. ⌘-drag it to the right of the chevron.",
                         chevronInside: "The chevron is left of the divider, so nothing hides. ⌘-drag it to the right of the divider.",
                         alwaysOutside: "The dotted divider is right of the main one, so it’s ignored. ⌘-drag it further left.",
                         showHidden: "Show Hidden Icons",
                         showAll: "Show All Icons",
                         hide: "Hide Icons",
                         settings: "Menu Bar Settings…",
                         chevronHelp: "Show or hide menu bar icons. ⌥-click to show all.",
                         dividerLabel: "Menu bar divider",
                         alwaysDividerLabel: "Always hidden divider")
        case .ptBR:
            return .init(title: "Ocultar itens da barra de menus",
                         enable: "Ativar ocultação da barra de menus",
                         enableCaption: "Adiciona uma seta e um divisor à barra de menus. Os ícones à esquerda do divisor ficam guardados até você clicar na seta.",
                         alwaysHidden: "Seção sempre oculta",
                         alwaysHiddenCaption: "Adiciona um segundo divisor pontilhado. Os ícones à esquerda dele ficam ocultos até você clicar na seta com ⌥.",
                         delay: "Ocultar de novo após",
                         delayCaption: "Os ícones também se ocultam quando o Mac é bloqueado, mas nunca enquanto um dos seus menus estiver aberto.",
                         secondsFormat: "%d segundos",
                         never: "Nunca",
                         clickOutside: "Ocultar ao clicar em outro lugar",
                         hover: "Mostrar ao passar o cursor",
                         hoverCaption: "Pare o cursor numa parte vazia da barra de menus para mostrar os ícones ocultos.",
                         notch: "Ocultar itens que ficariam atrás do entalhe",
                         notchCaption: "Quando o clique com ⌥ colocaria ícones sempre ocultos atrás da câmera, só a seção oculta aparece.",
                         behindNotch: "Atrás do entalhe agora: %@",
                         shortcutToggle: "Atalho de teclado",
                         shortcut: "Mostrar ou ocultar ícones da barra de menus",
                         shortcutFailed: "O macOS recusou este atalho. Outro app pode estar usando.",
                         howTo: "Como organizar",
                         stepDrag: "Segure ⌘ e arraste um ícone para a esquerda do divisor para ocultá-lo. Arraste de volta para a direita para mantê-lo à vista.",
                         stepClick: "Clique na seta, ou numa parte vazia da barra de menus, para mostrar ou ocultar os ícones.",
                         stepAlways: "Os ícones à esquerda do divisor pontilhado ficam ocultos até você clicar na seta com ⌥. Clique com ⌥ para organizá-los.",
                         hiddenLabel: "Ocultos",
                         visibleLabel: "Visíveis",
                         iconInside: "O ícone do Zenith está à esquerda do divisor, então nada se oculta. Arraste-o com ⌘ para a direita da seta.",
                         chevronInside: "A seta está à esquerda do divisor, então nada se oculta. Arraste-a com ⌘ para a direita do divisor.",
                         alwaysOutside: "O divisor pontilhado está à direita do principal, então é ignorado. Arraste-o com ⌘ mais para a esquerda.",
                         showHidden: "Mostrar Ícones Ocultos",
                         showAll: "Mostrar Todos os Ícones",
                         hide: "Ocultar Ícones",
                         settings: "Ajustes da Barra de Menus…",
                         chevronHelp: "Mostrar ou ocultar ícones da barra de menus. Clique com ⌥ para mostrar todos.",
                         dividerLabel: "Divisor da barra de menus",
                         alwaysDividerLabel: "Divisor sempre oculto")
        case .tr:
            return .init(title: "Menü çubuğunu gizleme",
                         enable: "Menü çubuğu gizlemeyi aç",
                         enableCaption: "Menü çubuğuna bir ok ve bir ayırıcı ekler. Ayırıcının solundaki simgeler, oka tıklayana kadar gizli kalır.",
                         alwaysHidden: "Her zaman gizli bölüm",
                         alwaysHiddenCaption: "İkinci, noktalı bir ayırıcı ekler. Solundaki simgeler, oka ⌥ ile tıklayana kadar gizli kalır.",
                         delay: "Yeniden gizleme süresi",
                         delayCaption: "Simgeler Mac kilitlendiğinde de gizlenir, ama menülerinden biri açıkken asla.",
                         secondsFormat: "%d saniye",
                         never: "Asla",
                         clickOutside: "Başka yere tıklayınca gizle",
                         hover: "Üzerine gelince göster",
                         hoverCaption: "Gizli simgeleri göstermek için imleci menü çubuğunun boş bir yerinde tutun.",
                         notch: "Çentiğin arkasında kalacak öğeleri gizle",
                         notchCaption: "⌥ ile tıklama her zaman gizli simgeleri kameranın arkasına koyacaksa yalnızca gizli bölüm gösterilir.",
                         behindNotch: "Şu an çentiğin arkasında: %@",
                         shortcutToggle: "Klavye kısayolu",
                         shortcut: "Menü çubuğu simgelerini göster veya gizle",
                         shortcutFailed: "macOS bu kısayolu reddetti. Başka bir uygulama kullanıyor olabilir.",
                         howTo: "Nasıl düzenlenir",
                         stepDrag: "Bir simgeyi gizlemek için ⌘ tuşunu basılı tutup ayırıcının soluna sürükleyin. Görünür kalması için sağa geri sürükleyin.",
                         stepClick: "Simgeleri göstermek veya gizlemek için oka ya da menü çubuğunun boş bir yerine tıklayın.",
                         stepAlways: "Noktalı ayırıcının solundaki simgeler, oka ⌥ ile tıklayana kadar gizli kalır. Düzenlemek için ⌥ ile tıklayın.",
                         hiddenLabel: "Gizli",
                         visibleLabel: "Görünür",
                         iconInside: "Zenith simgesi ayırıcının solunda, bu yüzden hiçbir şey gizlenmiyor. ⌘ ile okun sağına sürükleyin.",
                         chevronInside: "Ok ayırıcının solunda, bu yüzden hiçbir şey gizlenmiyor. ⌘ ile ayırıcının sağına sürükleyin.",
                         alwaysOutside: "Noktalı ayırıcı ana ayırıcının sağında, bu yüzden yok sayılıyor. ⌘ ile daha sola sürükleyin.",
                         showHidden: "Gizli Simgeleri Göster",
                         showAll: "Tüm Simgeleri Göster",
                         hide: "Simgeleri Gizle",
                         settings: "Menü Çubuğu Ayarları…",
                         chevronHelp: "Menü çubuğu simgelerini göster veya gizle. Tümünü göstermek için ⌥ ile tıklayın.",
                         dividerLabel: "Menü çubuğu ayırıcısı",
                         alwaysDividerLabel: "Her zaman gizli ayırıcı")
        case .ru:
            return .init(title: "Скрытие значков в строке меню",
                         enable: "Включить скрытие значков",
                         enableCaption: "Добавляет в строку меню стрелку и разделитель. Значки слева от разделителя прячутся, пока вы не нажмёте на стрелку.",
                         alwaysHidden: "Всегда скрытый раздел",
                         alwaysHiddenCaption: "Добавляет второй, пунктирный разделитель. Значки слева от него остаются скрытыми, пока вы не нажмёте на стрелку с ⌥.",
                         delay: "Снова скрывать через",
                         delayCaption: "Значки также прячутся при блокировке Mac, но никогда, пока открыто одно из их меню.",
                         secondsFormat: "%d секунд",
                         never: "Никогда",
                         clickOutside: "Скрывать при щелчке в другом месте",
                         hover: "Показывать при наведении",
                         hoverCaption: "Задержите указатель на пустой части строки меню, чтобы показать скрытые значки.",
                         notch: "Скрывать значки, которые оказались бы за вырезом",
                         notchCaption: "Если щелчок с ⌥ поместит всегда скрытые значки за камеру, покажется только скрытый раздел.",
                         behindNotch: "Сейчас за вырезом: %@",
                         shortcutToggle: "Сочетание клавиш",
                         shortcut: "Показать или скрыть значки строки меню",
                         shortcutFailed: "macOS не принял это сочетание. Возможно, его использует другое приложение.",
                         howTo: "Как расставить",
                         stepDrag: "Удерживая ⌘, перетащите значок левее разделителя, чтобы скрыть его. Верните его вправо, чтобы он остался на виду.",
                         stepClick: "Нажмите на стрелку или на пустую часть строки меню, чтобы показать или скрыть значки.",
                         stepAlways: "Значки левее пунктирного разделителя скрыты, пока вы не нажмёте на стрелку с ⌥. Нажмите с ⌥, чтобы их расставить.",
                         hiddenLabel: "Скрытые",
                         visibleLabel: "Видимые",
                         iconInside: "Значок Zenith левее разделителя, поэтому ничего не скрывается. Перетащите его с ⌘ правее стрелки.",
                         chevronInside: "Стрелка левее разделителя, поэтому ничего не скрывается. Перетащите её с ⌘ правее разделителя.",
                         alwaysOutside: "Пунктирный разделитель правее основного, поэтому он не учитывается. Перетащите его с ⌘ левее.",
                         showHidden: "Показать скрытые значки",
                         showAll: "Показать все значки",
                         hide: "Скрыть значки",
                         settings: "Настройки строки меню…",
                         chevronHelp: "Показать или скрыть значки строки меню. Щелчок с ⌥ показывает все.",
                         dividerLabel: "Разделитель строки меню",
                         alwaysDividerLabel: "Разделитель всегда скрытых значков")
        case .es:
            return .init(title: "Ocultar iconos de la barra de menús",
                         enable: "Activar la ocultación de la barra de menús",
                         enableCaption: "Añade una flecha y un divisor a la barra de menús. Los iconos a la izquierda del divisor se guardan hasta que haces clic en la flecha.",
                         alwaysHidden: "Sección siempre oculta",
                         alwaysHiddenCaption: "Añade un segundo divisor punteado. Los iconos a su izquierda siguen ocultos hasta que haces clic en la flecha con ⌥.",
                         delay: "Volver a ocultar tras",
                         delayCaption: "Los iconos también se ocultan al bloquear el Mac, pero nunca mientras uno de sus menús está abierto.",
                         secondsFormat: "%d segundos",
                         never: "Nunca",
                         clickOutside: "Ocultar al hacer clic en otro sitio",
                         hover: "Mostrar al pasar el puntero",
                         hoverCaption: "Deja el puntero sobre una parte vacía de la barra de menús para mostrar los iconos ocultos.",
                         notch: "Ocultar los ítems que quedarían detrás de la muesca",
                         notchCaption: "Si el clic con ⌥ dejara iconos siempre ocultos detrás de la cámara, solo se muestra la sección oculta.",
                         behindNotch: "Detrás de la muesca ahora: %@",
                         shortcutToggle: "Atajo de teclado",
                         shortcut: "Mostrar u ocultar iconos de la barra de menús",
                         shortcutFailed: "macOS rechazó este atajo. Puede que otra app lo esté usando.",
                         howTo: "Cómo ordenarlos",
                         stepDrag: "Mantén pulsada ⌘ y arrastra un icono a la izquierda del divisor para ocultarlo. Devuélvelo a la derecha para que siga a la vista.",
                         stepClick: "Haz clic en la flecha, o en una parte vacía de la barra de menús, para mostrar u ocultar los iconos.",
                         stepAlways: "Los iconos a la izquierda del divisor punteado siguen ocultos hasta que haces clic en la flecha con ⌥. Haz clic con ⌥ para ordenarlos.",
                         hiddenLabel: "Ocultos",
                         visibleLabel: "Visibles",
                         iconInside: "El icono de Zenith está a la izquierda del divisor, así que no se oculta nada. Arrástralo con ⌘ a la derecha de la flecha.",
                         chevronInside: "La flecha está a la izquierda del divisor, así que no se oculta nada. Arrástrala con ⌘ a la derecha del divisor.",
                         alwaysOutside: "El divisor punteado está a la derecha del principal, así que se ignora. Arrástralo con ⌘ más a la izquierda.",
                         showHidden: "Mostrar iconos ocultos",
                         showAll: "Mostrar todos los iconos",
                         hide: "Ocultar iconos",
                         settings: "Ajustes de la barra de menús…",
                         chevronHelp: "Mostrar u ocultar iconos de la barra de menús. Clic con ⌥ para mostrar todos.",
                         dividerLabel: "Divisor de la barra de menús",
                         alwaysDividerLabel: "Divisor de la sección siempre oculta")
        case .sk:
            return .init(title: "Skrývanie ikon na lište menu",
                         enable: "Zapnúť skrývanie ikon na lište menu",
                         enableCaption: "Pridá na lištu menu šípku a oddeľovač. Ikony naľavo od oddeľovača sa schovajú, kým nekliknete na šípku.",
                         alwaysHidden: "Vždy skrytá sekcia",
                         alwaysHiddenCaption: "Pridá druhý, bodkovaný oddeľovač. Ikony naľavo od neho zostanú skryté, kým nekliknete na šípku s ⌥.",
                         delay: "Znova skryť po",
                         delayCaption: "Ikony sa skryjú aj pri zamknutí Macu, ale nikdy, kým je otvorené niektoré z ich menu.",
                         secondsFormat: "%d sekúnd",
                         never: "Nikdy",
                         clickOutside: "Skryť po kliknutí inam",
                         hover: "Zobraziť pri prejdení kurzorom",
                         hoverCaption: "Podržte kurzor na prázdnej časti lišty menu a skryté ikony sa zobrazia.",
                         notch: "Skryť položky, ktoré by boli za výrezom",
                         notchCaption: "Ak by kliknutie s ⌥ dalo vždy skryté ikony za kameru, zobrazí sa len skrytá sekcia.",
                         behindNotch: "Teraz za výrezom: %@",
                         shortcutToggle: "Klávesová skratka",
                         shortcut: "Zobraziť alebo skryť ikony na lište menu",
                         shortcutFailed: "macOS túto skratku odmietol. Možno ju používa iná aplikácia.",
                         howTo: "Ako ich usporiadať",
                         stepDrag: "Podržte ⌘ a potiahnite ikonu naľavo od oddeľovača, aby sa skryla. Potiahnite ju späť doprava, aby zostala viditeľná.",
                         stepClick: "Kliknite na šípku alebo na prázdnu časť lišty menu a ikony sa zobrazia alebo skryjú.",
                         stepAlways: "Ikony naľavo od bodkovaného oddeľovača zostanú skryté, kým nekliknete na šípku s ⌥. Kliknite s ⌥ a usporiadajte ich.",
                         hiddenLabel: "Skryté",
                         visibleLabel: "Viditeľné",
                         iconInside: "Ikona Zenithu je naľavo od oddeľovača, takže sa nič neskryje. Potiahnite ju s ⌘ napravo od šípky.",
                         chevronInside: "Šípka je naľavo od oddeľovača, takže sa nič neskryje. Potiahnite ju s ⌘ napravo od oddeľovača.",
                         alwaysOutside: "Bodkovaný oddeľovač je napravo od hlavného, takže sa ignoruje. Potiahnite ho s ⌘ viac doľava.",
                         showHidden: "Zobraziť skryté ikony",
                         showAll: "Zobraziť všetky ikony",
                         hide: "Skryť ikony",
                         settings: "Nastavenia lišty menu…",
                         chevronHelp: "Zobraziť alebo skryť ikony na lište menu. Kliknutím s ⌥ zobrazíte všetky.",
                         dividerLabel: "Oddeľovač lišty menu",
                         alwaysDividerLabel: "Oddeľovač vždy skrytých ikon")
        case .de:
            return .init(title: "Menüleistensymbole ausblenden",
                         enable: "Ausblenden in der Menüleiste aktivieren",
                         enableCaption: "Fügt der Menüleiste einen Pfeil und einen Trenner hinzu. Symbole links vom Trenner verschwinden, bis du auf den Pfeil klickst.",
                         alwaysHidden: "Immer ausgeblendeter Bereich",
                         alwaysHiddenCaption: "Fügt einen zweiten, gepunkteten Trenner hinzu. Symbole links davon bleiben ausgeblendet, bis du mit ⌥ auf den Pfeil klickst.",
                         delay: "Wieder ausblenden nach",
                         delayCaption: "Symbole verschwinden auch, wenn der Mac gesperrt wird, aber nie, solange eines ihrer Menüs offen ist.",
                         secondsFormat: "%d Sekunden",
                         never: "Nie",
                         clickOutside: "Beim Klicken woanders ausblenden",
                         hover: "Beim Darüberfahren einblenden",
                         hoverCaption: "Lass den Zeiger auf einer leeren Stelle der Menüleiste ruhen, um ausgeblendete Symbole zu zeigen.",
                         notch: "Objekte ausblenden, die hinter der Notch landen würden",
                         notchCaption: "Würde ein ⌥-Klick immer ausgeblendete Symbole hinter die Kamera schieben, erscheint nur der ausgeblendete Bereich.",
                         behindNotch: "Gerade hinter der Notch: %@",
                         shortcutToggle: "Tastenkurzbefehl",
                         shortcut: "Menüleistensymbole ein- oder ausblenden",
                         shortcutFailed: "macOS hat diesen Kurzbefehl abgelehnt. Vielleicht nutzt ihn eine andere App.",
                         howTo: "So ordnest du sie an",
                         stepDrag: "Halte ⌘ gedrückt und ziehe ein Symbol links neben den Trenner, um es auszublenden. Zieh es nach rechts zurück, damit es sichtbar bleibt.",
                         stepClick: "Klicke auf den Pfeil oder eine leere Stelle der Menüleiste, um die Symbole ein- oder auszublenden.",
                         stepAlways: "Symbole links vom gepunkteten Trenner bleiben ausgeblendet, bis du mit ⌥ auf den Pfeil klickst. Klicke mit ⌥, um sie anzuordnen.",
                         hiddenLabel: "Ausgeblendet",
                         visibleLabel: "Sichtbar",
                         iconInside: "Das Zenith-Symbol liegt links vom Trenner, daher wird nichts ausgeblendet. Zieh es mit ⌘ rechts neben den Pfeil.",
                         chevronInside: "Der Pfeil liegt links vom Trenner, daher wird nichts ausgeblendet. Zieh ihn mit ⌘ rechts neben den Trenner.",
                         alwaysOutside: "Der gepunktete Trenner liegt rechts vom Haupttrenner und wird daher ignoriert. Zieh ihn mit ⌘ weiter nach links.",
                         showHidden: "Ausgeblendete Symbole zeigen",
                         showAll: "Alle Symbole zeigen",
                         hide: "Symbole ausblenden",
                         settings: "Menüleisten-Einstellungen …",
                         chevronHelp: "Menüleistensymbole ein- oder ausblenden. Mit ⌥ klicken, um alle zu zeigen.",
                         dividerLabel: "Menüleistentrenner",
                         alwaysDividerLabel: "Trenner für immer ausgeblendete Symbole")
        case .fr:
            return .init(title: "Masquage de la barre des menus",
                         enable: "Activer le masquage de la barre des menus",
                         enableCaption: "Ajoute une flèche et un séparateur à la barre des menus. Les icônes à gauche du séparateur se rangent jusqu’à ce que vous cliquiez sur la flèche.",
                         alwaysHidden: "Section toujours masquée",
                         alwaysHiddenCaption: "Ajoute un second séparateur, en pointillés. Les icônes à sa gauche restent masquées jusqu’à ce que vous cliquiez sur la flèche avec ⌥.",
                         delay: "Masquer de nouveau après",
                         delayCaption: "Les icônes se masquent aussi au verrouillage du Mac, mais jamais tant qu’un de leurs menus est ouvert.",
                         secondsFormat: "%d secondes",
                         never: "Jamais",
                         clickOutside: "Masquer en cliquant ailleurs",
                         hover: "Afficher au survol",
                         hoverCaption: "Laissez le pointeur sur une partie vide de la barre des menus pour afficher les icônes masquées.",
                         notch: "Masquer les éléments qui seraient derrière l’encoche",
                         notchCaption: "Si un clic avec ⌥ plaçait des icônes toujours masquées derrière la caméra, seule la section masquée s’affiche.",
                         behindNotch: "Derrière l’encoche en ce moment : %@",
                         shortcutToggle: "Raccourci clavier",
                         shortcut: "Afficher ou masquer les icônes de la barre des menus",
                         shortcutFailed: "macOS a refusé ce raccourci. Une autre app l’utilise peut-être.",
                         howTo: "Comment les ranger",
                         stepDrag: "Maintenez ⌘ et faites glisser une icône à gauche du séparateur pour la masquer. Ramenez-la à droite pour la garder visible.",
                         stepClick: "Cliquez sur la flèche, ou sur une partie vide de la barre des menus, pour afficher ou masquer les icônes.",
                         stepAlways: "Les icônes à gauche du séparateur en pointillés restent masquées jusqu’à un clic avec ⌥ sur la flèche. Cliquez avec ⌥ pour les ranger.",
                         hiddenLabel: "Masquées",
                         visibleLabel: "Visibles",
                         iconInside: "L’icône de Zenith est à gauche du séparateur, rien ne se masque donc. Faites-la glisser avec ⌘ à droite de la flèche.",
                         chevronInside: "La flèche est à gauche du séparateur, rien ne se masque donc. Faites-la glisser avec ⌘ à droite du séparateur.",
                         alwaysOutside: "Le séparateur en pointillés est à droite du principal, il est donc ignoré. Faites-le glisser avec ⌘ plus à gauche.",
                         showHidden: "Afficher les icônes masquées",
                         showAll: "Afficher toutes les icônes",
                         hide: "Masquer les icônes",
                         settings: "Réglages de la barre des menus…",
                         chevronHelp: "Afficher ou masquer les icônes de la barre des menus. Clic avec ⌥ pour tout afficher.",
                         dividerLabel: "Séparateur de la barre des menus",
                         alwaysDividerLabel: "Séparateur de la section toujours masquée")
        case .it:
            return .init(title: "Nascondere le icone della barra dei menu",
                         enable: "Attiva il nascondimento nella barra dei menu",
                         enableCaption: "Aggiunge una freccia e un divisore alla barra dei menu. Le icone a sinistra del divisore si nascondono finché non fai clic sulla freccia.",
                         alwaysHidden: "Sezione sempre nascosta",
                         alwaysHiddenCaption: "Aggiunge un secondo divisore tratteggiato. Le icone alla sua sinistra restano nascoste finché non fai clic sulla freccia con ⌥.",
                         delay: "Nascondi di nuovo dopo",
                         delayCaption: "Le icone si nascondono anche quando il Mac si blocca, ma mai mentre uno dei loro menu è aperto.",
                         secondsFormat: "%d secondi",
                         never: "Mai",
                         clickOutside: "Nascondi facendo clic altrove",
                         hover: "Mostra al passaggio del puntatore",
                         hoverCaption: "Lascia il puntatore su una parte vuota della barra dei menu per mostrare le icone nascoste.",
                         notch: "Nascondi gli elementi che finirebbero dietro il notch",
                         notchCaption: "Se il clic con ⌥ mettesse icone sempre nascoste dietro la fotocamera, appare solo la sezione nascosta.",
                         behindNotch: "Dietro il notch ora: %@",
                         shortcutToggle: "Abbreviazione da tastiera",
                         shortcut: "Mostra o nascondi le icone della barra dei menu",
                         shortcutFailed: "macOS ha rifiutato questa abbreviazione. Forse la usa un’altra app.",
                         howTo: "Come disporle",
                         stepDrag: "Tieni premuto ⌘ e trascina un’icona a sinistra del divisore per nasconderla. Riportala a destra per tenerla in vista.",
                         stepClick: "Fai clic sulla freccia, o su una parte vuota della barra dei menu, per mostrare o nascondere le icone.",
                         stepAlways: "Le icone a sinistra del divisore tratteggiato restano nascoste finché non fai clic sulla freccia con ⌥. Fai clic con ⌥ per disporle.",
                         hiddenLabel: "Nascoste",
                         visibleLabel: "Visibili",
                         iconInside: "L’icona di Zenith è a sinistra del divisore, quindi non si nasconde nulla. Trascinala con ⌘ a destra della freccia.",
                         chevronInside: "La freccia è a sinistra del divisore, quindi non si nasconde nulla. Trascinala con ⌘ a destra del divisore.",
                         alwaysOutside: "Il divisore tratteggiato è a destra di quello principale, quindi viene ignorato. Trascinalo con ⌘ più a sinistra.",
                         showHidden: "Mostra icone nascoste",
                         showAll: "Mostra tutte le icone",
                         hide: "Nascondi icone",
                         settings: "Impostazioni barra dei menu…",
                         chevronHelp: "Mostra o nascondi le icone della barra dei menu. Clic con ⌥ per mostrarle tutte.",
                         dividerLabel: "Divisore della barra dei menu",
                         alwaysDividerLabel: "Divisore della sezione sempre nascosta")
        case .ja:
            return .init(title: "メニューバーのアイコンを隠す",
                         enable: "メニューバーのアイコンを隠す機能をオン",
                         enableCaption: "メニューバーに矢印と区切りを追加します。区切りより左のアイコンは、矢印をクリックするまで隠れます。",
                         alwaysHidden: "常に隠すセクション",
                         alwaysHiddenCaption: "点線の区切りをもう1本追加します。その左のアイコンは、⌥を押しながら矢印をクリックするまで隠れたままです。",
                         delay: "再び隠すまで",
                         delayCaption: "Macがロックされたときもアイコンは隠れます。ただし、アイコンのメニューが開いている間は隠れません。",
                         secondsFormat: "%d秒",
                         never: "しない",
                         clickOutside: "ほかの場所をクリックしたら隠す",
                         hover: "ポインタを置いたら表示",
                         hoverCaption: "メニューバーの空いている部分にポインタを置くと、隠れたアイコンが表示されます。",
                         notch: "ノッチの後ろに入る項目を隠す",
                         notchCaption: "⌥クリックで常に隠すアイコンがカメラの後ろに入る場合は、隠すセクションだけを表示します。",
                         behindNotch: "現在ノッチの後ろにあるもの：%@",
                         shortcutToggle: "キーボードショートカット",
                         shortcut: "メニューバーのアイコンを表示または非表示",
                         shortcutFailed: "macOSがこのショートカットを拒否しました。ほかのアプリが使っている可能性があります。",
                         howTo: "並べ方",
                         stepDrag: "⌘を押しながらアイコンを区切りの左へドラッグすると隠れます。右へ戻すと表示されたままになります。",
                         stepClick: "矢印、またはメニューバーの空いている部分をクリックすると、アイコンを表示したり隠したりできます。",
                         stepAlways: "点線の区切りより左のアイコンは、⌥を押しながら矢印をクリックするまで隠れたままです。並べ替えるときも⌥クリックします。",
                         hiddenLabel: "隠す",
                         visibleLabel: "表示",
                         iconInside: "Zenithのアイコンが区切りより左にあるため、何も隠れません。⌘を押しながら矢印の右へドラッグしてください。",
                         chevronInside: "矢印が区切りより左にあるため、何も隠れません。⌘を押しながら区切りの右へドラッグしてください。",
                         alwaysOutside: "点線の区切りがメインの区切りより右にあるため、無視されています。⌘を押しながらもっと左へドラッグしてください。",
                         showHidden: "隠れたアイコンを表示",
                         showAll: "すべてのアイコンを表示",
                         hide: "アイコンを隠す",
                         settings: "メニューバーの設定…",
                         chevronHelp: "メニューバーのアイコンを表示または非表示にします。⌥クリックですべて表示します。",
                         dividerLabel: "メニューバーの区切り",
                         alwaysDividerLabel: "常に隠すセクションの区切り")
        case .ko:
            return .init(title: "메뉴 막대 아이콘 숨기기",
                         enable: "메뉴 막대 아이콘 숨기기 켜기",
                         enableCaption: "메뉴 막대에 화살표와 구분선을 추가합니다. 구분선 왼쪽의 아이콘은 화살표를 클릭할 때까지 숨겨집니다.",
                         alwaysHidden: "항상 숨김 영역",
                         alwaysHiddenCaption: "점선 구분선을 하나 더 추가합니다. 그 왼쪽의 아이콘은 ⌥를 누른 채 화살표를 클릭할 때까지 숨겨져 있습니다.",
                         delay: "다시 숨기기까지",
                         delayCaption: "Mac이 잠기면 아이콘도 숨겨집니다. 단, 아이콘의 메뉴가 열려 있는 동안에는 숨기지 않습니다.",
                         secondsFormat: "%d초",
                         never: "안 함",
                         clickOutside: "다른 곳을 클릭하면 숨기기",
                         hover: "포인터를 올리면 보기",
                         hoverCaption: "메뉴 막대의 빈 곳에 포인터를 올려 두면 숨긴 아이콘이 나타납니다.",
                         notch: "노치 뒤에 놓일 항목 숨기기",
                         notchCaption: "⌥ 클릭으로 항상 숨김 아이콘이 카메라 뒤에 놓이게 되면 숨김 영역만 보여 줍니다.",
                         behindNotch: "지금 노치 뒤에 있는 항목: %@",
                         shortcutToggle: "키보드 단축키",
                         shortcut: "메뉴 막대 아이콘 보기 또는 숨기기",
                         shortcutFailed: "macOS가 이 단축키를 거부했습니다. 다른 앱이 사용 중일 수 있습니다.",
                         howTo: "정리하는 방법",
                         stepDrag: "⌘를 누른 채 아이콘을 구분선 왼쪽으로 드래그하면 숨겨집니다. 오른쪽으로 되돌리면 계속 보입니다.",
                         stepClick: "화살표나 메뉴 막대의 빈 곳을 클릭하면 아이콘을 보이거나 숨길 수 있습니다.",
                         stepAlways: "점선 구분선 왼쪽의 아이콘은 ⌥를 누른 채 화살표를 클릭할 때까지 숨겨져 있습니다. 정리할 때도 ⌥ 클릭하세요.",
                         hiddenLabel: "숨김",
                         visibleLabel: "보임",
                         iconInside: "Zenith 아이콘이 구분선 왼쪽에 있어 아무것도 숨기지 않습니다. ⌘를 누른 채 화살표 오른쪽으로 드래그하세요.",
                         chevronInside: "화살표가 구분선 왼쪽에 있어 아무것도 숨기지 않습니다. ⌘를 누른 채 구분선 오른쪽으로 드래그하세요.",
                         alwaysOutside: "점선 구분선이 기본 구분선 오른쪽에 있어 무시됩니다. ⌘를 누른 채 더 왼쪽으로 드래그하세요.",
                         showHidden: "숨긴 아이콘 보기",
                         showAll: "모든 아이콘 보기",
                         hide: "아이콘 숨기기",
                         settings: "메뉴 막대 설정…",
                         chevronHelp: "메뉴 막대 아이콘을 보이거나 숨깁니다. ⌥ 클릭으로 모두 봅니다.",
                         dividerLabel: "메뉴 막대 구분선",
                         alwaysDividerLabel: "항상 숨김 구분선")
        case .uk:
            return .init(title: "Приховування значків у рядку меню",
                         enable: "Увімкнути приховування значків",
                         enableCaption: "Додає до рядка меню стрілку й роздільник. Значки ліворуч від роздільника ховаються, доки ви не натиснете стрілку.",
                         alwaysHidden: "Завжди прихований розділ",
                         alwaysHiddenCaption: "Додає другий, пунктирний роздільник. Значки ліворуч від нього лишаються прихованими, доки ви не натиснете стрілку з ⌥.",
                         delay: "Знову ховати через",
                         delayCaption: "Значки також ховаються, коли Mac блокується, але ніколи, поки відкрите одне з їхніх меню.",
                         secondsFormat: "%d секунд",
                         never: "Ніколи",
                         clickOutside: "Ховати при клацанні деінде",
                         hover: "Показувати при наведенні",
                         hoverCaption: "Затримайте вказівник на порожній частині рядка меню, щоб показати приховані значки.",
                         notch: "Ховати елементи, які опинилися б за вирізом",
                         notchCaption: "Якщо клацання з ⌥ поставить завжди приховані значки за камеру, з’явиться лише прихований розділ.",
                         behindNotch: "Зараз за вирізом: %@",
                         shortcutToggle: "Сполучення клавіш",
                         shortcut: "Показати або сховати значки рядка меню",
                         shortcutFailed: "macOS не прийняв це сполучення. Можливо, його використовує інша програма.",
                         howTo: "Як розставити",
                         stepDrag: "Утримуючи ⌘, перетягніть значок ліворуч від роздільника, щоб сховати його. Поверніть його праворуч, щоб він лишався на виду.",
                         stepClick: "Натисніть стрілку або порожню частину рядка меню, щоб показати чи сховати значки.",
                         stepAlways: "Значки ліворуч від пунктирного роздільника приховані, доки ви не натиснете стрілку з ⌥. Натисніть з ⌥, щоб їх розставити.",
                         hiddenLabel: "Приховані",
                         visibleLabel: "Видимі",
                         iconInside: "Значок Zenith ліворуч від роздільника, тож нічого не ховається. Перетягніть його з ⌘ праворуч від стрілки.",
                         chevronInside: "Стрілка ліворуч від роздільника, тож нічого не ховається. Перетягніть її з ⌘ праворуч від роздільника.",
                         alwaysOutside: "Пунктирний роздільник праворуч від основного, тож його не враховано. Перетягніть його з ⌘ далі ліворуч.",
                         showHidden: "Показати приховані значки",
                         showAll: "Показати всі значки",
                         hide: "Сховати значки",
                         settings: "Параметри рядка меню…",
                         chevronHelp: "Показати або сховати значки рядка меню. Клацання з ⌥ показує всі.",
                         dividerLabel: "Роздільник рядка меню",
                         alwaysDividerLabel: "Роздільник завжди прихованих значків")
        case .zhHans:
            return .init(title: "隐藏菜单栏图标",
                         enable: "启用菜单栏图标隐藏",
                         enableCaption: "在菜单栏中添加一个箭头和一条分隔线。分隔线左侧的图标会收起，直到你点按箭头。",
                         alwaysHidden: "始终隐藏区域",
                         alwaysHiddenCaption: "再添加一条虚线分隔线。它左侧的图标会一直隐藏，直到你按住 ⌥ 点按箭头。",
                         delay: "再次隐藏前等待",
                         delayCaption: "Mac 锁定时图标也会隐藏，但图标的菜单打开时绝不会隐藏。",
                         secondsFormat: "%d 秒",
                         never: "永不",
                         clickOutside: "点按别处时隐藏",
                         hover: "悬停时显示",
                         hoverCaption: "将指针停在菜单栏的空白处即可显示隐藏的图标。",
                         notch: "隐藏会落在刘海后面的项目",
                         notchCaption: "如果按住 ⌥ 点按会让始终隐藏的图标落到摄像头后面，则只显示隐藏区域。",
                         behindNotch: "当前位于刘海后面：%@",
                         shortcutToggle: "键盘快捷键",
                         shortcut: "显示或隐藏菜单栏图标",
                         shortcutFailed: "macOS 拒绝了此快捷键，可能有其他 App 正在使用。",
                         howTo: "如何整理",
                         stepDrag: "按住 ⌘ 将图标拖到分隔线左侧即可隐藏。拖回右侧即可保持显示。",
                         stepClick: "点按箭头或菜单栏的空白处，即可显示或隐藏图标。",
                         stepAlways: "虚线分隔线左侧的图标会一直隐藏，直到你按住 ⌥ 点按箭头。整理它们时也请按住 ⌥ 点按。",
                         hiddenLabel: "隐藏",
                         visibleLabel: "显示",
                         iconInside: "Zenith 图标位于分隔线左侧，因此不会隐藏任何内容。请按住 ⌘ 将它拖到箭头右侧。",
                         chevronInside: "箭头位于分隔线左侧，因此不会隐藏任何内容。请按住 ⌘ 将它拖到分隔线右侧。",
                         alwaysOutside: "虚线分隔线位于主分隔线右侧，因此被忽略。请按住 ⌘ 将它拖到更左侧。",
                         showHidden: "显示隐藏的图标",
                         showAll: "显示所有图标",
                         hide: "隐藏图标",
                         settings: "菜单栏设置…",
                         chevronHelp: "显示或隐藏菜单栏图标。按住 ⌥ 点按可显示全部。",
                         dividerLabel: "菜单栏分隔线",
                         alwaysDividerLabel: "始终隐藏分隔线")
        case .zhTW:
            return .init(title: "隱藏選單列圖像",
                         enable: "啟用選單列圖像隱藏",
                         enableCaption: "在選單列加入一個箭頭和一條分隔線。分隔線左側的圖像會收起，直到你按一下箭頭。",
                         alwaysHidden: "永遠隱藏區域",
                         alwaysHiddenCaption: "再加入一條虛線分隔線。它左側的圖像會一直隱藏，直到你按住 ⌥ 按一下箭頭。",
                         delay: "再次隱藏前等待",
                         delayCaption: "Mac 鎖定時圖像也會隱藏，但圖像的選單打開時絕不會隱藏。",
                         secondsFormat: "%d 秒",
                         never: "永不",
                         clickOutside: "按一下別處時隱藏",
                         hover: "游標停留時顯示",
                         hoverCaption: "將游標停在選單列的空白處即可顯示隱藏的圖像。",
                         notch: "隱藏會落在瀏海後方的項目",
                         notchCaption: "如果按住 ⌥ 按一下會讓永遠隱藏的圖像落到相機後方，則只顯示隱藏區域。",
                         behindNotch: "目前位於瀏海後方：%@",
                         shortcutToggle: "鍵盤快速鍵",
                         shortcut: "顯示或隱藏選單列圖像",
                         shortcutFailed: "macOS 拒絕了此快速鍵，可能有其他 App 正在使用。",
                         howTo: "如何整理",
                         stepDrag: "按住 ⌘ 將圖像拖到分隔線左側即可隱藏。拖回右側即可保持顯示。",
                         stepClick: "按一下箭頭或選單列的空白處，即可顯示或隱藏圖像。",
                         stepAlways: "虛線分隔線左側的圖像會一直隱藏，直到你按住 ⌥ 按一下箭頭。整理時也請按住 ⌥ 按一下。",
                         hiddenLabel: "隱藏",
                         visibleLabel: "顯示",
                         iconInside: "Zenith 圖像位於分隔線左側，因此不會隱藏任何內容。請按住 ⌘ 將它拖到箭頭右側。",
                         chevronInside: "箭頭位於分隔線左側，因此不會隱藏任何內容。請按住 ⌘ 將它拖到分隔線右側。",
                         alwaysOutside: "虛線分隔線位於主分隔線右側，因此被忽略。請按住 ⌘ 將它拖到更左側。",
                         showHidden: "顯示隱藏的圖像",
                         showAll: "顯示所有圖像",
                         hide: "隱藏圖像",
                         settings: "選單列設定⋯",
                         chevronHelp: "顯示或隱藏選單列圖像。按住 ⌥ 按一下可顯示全部。",
                         dividerLabel: "選單列分隔線",
                         alwaysDividerLabel: "永遠隱藏分隔線")
        case .zhHK:
            return .init(title: "隱藏選單列圖示",
                         enable: "啟用選單列圖示隱藏",
                         enableCaption: "在選單列加入一個箭嘴和一條分隔線。分隔線左邊的圖示會收起，直至你按一下箭嘴。",
                         alwaysHidden: "永遠隱藏區域",
                         alwaysHiddenCaption: "再加入一條虛線分隔線。它左邊的圖示會一直隱藏，直至你按住 ⌥ 按一下箭嘴。",
                         delay: "再次隱藏前等候",
                         delayCaption: "Mac 鎖定時圖示亦會隱藏，但圖示的選單打開時絕不會隱藏。",
                         secondsFormat: "%d 秒",
                         never: "永不",
                         clickOutside: "按一下別處時隱藏",
                         hover: "指標停留時顯示",
                         hoverCaption: "將指標停在選單列的空白處便會顯示隱藏的圖示。",
                         notch: "隱藏會落在瀏海後面的項目",
                         notchCaption: "如果按住 ⌥ 按一下會令永遠隱藏的圖示落到相機後面，便只顯示隱藏區域。",
                         behindNotch: "目前位於瀏海後面：%@",
                         shortcutToggle: "鍵盤快速鍵",
                         shortcut: "顯示或隱藏選單列圖示",
                         shortcutFailed: "macOS 拒絕了此快速鍵，可能有其他 App 正在使用。",
                         howTo: "如何整理",
                         stepDrag: "按住 ⌘ 將圖示拖到分隔線左邊便會隱藏。拖回右邊便會保持顯示。",
                         stepClick: "按一下箭嘴或選單列的空白處，便可顯示或隱藏圖示。",
                         stepAlways: "虛線分隔線左邊的圖示會一直隱藏，直至你按住 ⌥ 按一下箭嘴。整理時亦請按住 ⌥ 按一下。",
                         hiddenLabel: "隱藏",
                         visibleLabel: "顯示",
                         iconInside: "Zenith 圖示位於分隔線左邊，所以不會隱藏任何內容。請按住 ⌘ 將它拖到箭嘴右邊。",
                         chevronInside: "箭嘴位於分隔線左邊，所以不會隱藏任何內容。請按住 ⌘ 將它拖到分隔線右邊。",
                         alwaysOutside: "虛線分隔線位於主分隔線右邊，所以被忽略。請按住 ⌘ 將它拖到更左邊。",
                         showHidden: "顯示隱藏的圖示",
                         showAll: "顯示所有圖示",
                         hide: "隱藏圖示",
                         settings: "選單列設定⋯",
                         chevronHelp: "顯示或隱藏選單列圖示。按住 ⌥ 按一下可顯示全部。",
                         dividerLabel: "選單列分隔線",
                         alwaysDividerLabel: "永遠隱藏分隔線")
        }
    }
}

struct ZenithReplyStrings {
    let reply: String
    let closeReply: String
    let send: String
    let emoji: String
    /// "You: %@", the reply just sent.
    let you: String
    let sending: String
    /// Automatic sending stopped; %@ is the app.
    let openedPrefilled: String
    let openedCopied: String
    /// The setting asked for the app to open instead; %@ is the app.
    let handOffPrefilled: String
    let handOffCopied: String
    let needsAutomation: String
    let needsAccessibility: String
    let grantAccess: String
    let failed: String
    let autoWhatsApp: String
    let autoWhatsAppCaption: String
}

extension ZenithStrings {
    /// Replying to Messages and WhatsApp notifications from the island
    /// (ZenithReplySupport), and its WhatsApp switch in the Notifications settings.
    static func reply(_ language: AppLanguage) -> ZenithReplyStrings {
        switch language {
        case .enUS:
            return .init(reply: "Reply", closeReply: "Close reply", send: "Send", emoji: "Emoji & Symbols",
                         you: "You: %@", sending: "Sending…",
                         openedPrefilled: "Couldn’t send automatically. %@ is open with your reply ready.",
                         openedCopied: "Couldn’t send automatically. %@ is open and your reply is copied.",
                         handOffPrefilled: "%@ is open with your reply ready to send.",
                         handOffCopied: "%@ is open and your reply is copied.",
                         needsAutomation: "Allow Zenith to control Messages to send replies.",
                         needsAccessibility: "Allow Accessibility to send WhatsApp replies.",
                         grantAccess: "Grant access",
                         failed: "Couldn’t send this reply.",
                         autoWhatsApp: "Send WhatsApp replies automatically",
                         autoWhatsAppCaption: "A reply from the Dynamic Island opens the chat in WhatsApp, types your message and presses Return, then goes back to the app you were using. This works through WhatsApp’s window and may stop working after a WhatsApp update; WhatsApp then opens with your reply ready instead. When off, WhatsApp opens and you send the reply yourself.")
        case .ptBR:
            return .init(reply: "Responder", closeReply: "Fechar resposta", send: "Enviar", emoji: "Emoji e Símbolos",
                         you: "Você: %@", sending: "Enviando…",
                         openedPrefilled: "Não foi possível enviar automaticamente. O %@ está aberto com sua resposta pronta.",
                         openedCopied: "Não foi possível enviar automaticamente. O %@ está aberto e sua resposta foi copiada.",
                         handOffPrefilled: "O %@ está aberto com sua resposta pronta para enviar.",
                         handOffCopied: "O %@ está aberto e sua resposta foi copiada.",
                         needsAutomation: "Permita que o Zenith controle o Mensagens para enviar respostas.",
                         needsAccessibility: "Permita a Acessibilidade para enviar respostas no WhatsApp.",
                         grantAccess: "Permitir acesso",
                         failed: "Não foi possível enviar esta resposta.",
                         autoWhatsApp: "Enviar respostas do WhatsApp automaticamente",
                         autoWhatsAppCaption: "Uma resposta da Dynamic Island abre a conversa no WhatsApp, digita sua mensagem e pressiona Return, depois volta ao app que você estava usando. Isso funciona pela janela do WhatsApp e pode parar de funcionar após uma atualização do WhatsApp; nesse caso, o WhatsApp abre com sua resposta pronta. Desativado, o WhatsApp abre e você mesmo envia a resposta.")
        case .tr:
            return .init(reply: "Yanıtla", closeReply: "Yanıtı kapat", send: "Gönder", emoji: "Emoji ve Simgeler",
                         you: "Sen: %@", sending: "Gönderiliyor…",
                         openedPrefilled: "Otomatik gönderilemedi. %@ yanıtın hazır şekilde açıldı.",
                         openedCopied: "Otomatik gönderilemedi. %@ açıldı ve yanıtın kopyalandı.",
                         handOffPrefilled: "%@ yanıtın gönderilmeye hazır şekilde açıldı.",
                         handOffCopied: "%@ açıldı ve yanıtın kopyalandı.",
                         needsAutomation: "Yanıt göndermek için Zenith’in Mesajlar’ı denetlemesine izin ver.",
                         needsAccessibility: "WhatsApp yanıtları göndermek için Erişilebilirlik izni ver.",
                         grantAccess: "Erişim ver",
                         failed: "Bu yanıt gönderilemedi.",
                         autoWhatsApp: "WhatsApp yanıtlarını otomatik gönder",
                         autoWhatsAppCaption: "Dynamic Island’dan verilen yanıt WhatsApp’ta sohbeti açar, mesajını yazar ve Return’e basar, ardından kullandığın uygulamaya döner. Bu, WhatsApp penceresi üzerinden çalışır ve bir WhatsApp güncellemesinden sonra çalışmayı bırakabilir; o zaman WhatsApp yanıtın hazır şekilde açılır. Kapalıyken WhatsApp açılır ve yanıtı sen gönderirsin.")
        case .ru:
            return .init(reply: "Ответить", closeReply: "Закрыть ответ", send: "Отправить", emoji: "Эмодзи и символы",
                         you: "Вы: %@", sending: "Отправка…",
                         openedPrefilled: "Не удалось отправить автоматически. %@ открыт, ответ уже введён.",
                         openedCopied: "Не удалось отправить автоматически. %@ открыт, ответ скопирован.",
                         handOffPrefilled: "%@ открыт, ответ готов к отправке.",
                         handOffCopied: "%@ открыт, ответ скопирован.",
                         needsAutomation: "Разрешите Zenith управлять Сообщениями, чтобы отправлять ответы.",
                         needsAccessibility: "Разрешите Универсальный доступ, чтобы отправлять ответы в WhatsApp.",
                         grantAccess: "Дать доступ",
                         failed: "Не удалось отправить ответ.",
                         autoWhatsApp: "Отправлять ответы WhatsApp автоматически",
                         autoWhatsAppCaption: "Ответ из Dynamic Island открывает чат в WhatsApp, вводит сообщение и нажимает Return, а затем возвращает вас в прежнее приложение. Это работает через окно WhatsApp и может перестать работать после обновления WhatsApp; тогда WhatsApp откроется с готовым ответом. Если выключено, WhatsApp откроется, и вы отправите ответ сами.")
        case .es:
            return .init(reply: "Responder", closeReply: "Cerrar respuesta", send: "Enviar", emoji: "Emojis y símbolos",
                         you: "Tú: %@", sending: "Enviando…",
                         openedPrefilled: "No se pudo enviar automáticamente. %@ está abierto con tu respuesta lista.",
                         openedCopied: "No se pudo enviar automáticamente. %@ está abierto y tu respuesta se copió.",
                         handOffPrefilled: "%@ está abierto con tu respuesta lista para enviar.",
                         handOffCopied: "%@ está abierto y tu respuesta se copió.",
                         needsAutomation: "Permite que Zenith controle Mensajes para enviar respuestas.",
                         needsAccessibility: "Permite Accesibilidad para enviar respuestas de WhatsApp.",
                         grantAccess: "Dar acceso",
                         failed: "No se pudo enviar esta respuesta.",
                         autoWhatsApp: "Enviar respuestas de WhatsApp automáticamente",
                         autoWhatsAppCaption: "Una respuesta desde la Dynamic Island abre el chat en WhatsApp, escribe tu mensaje y pulsa Return, y luego vuelve a la app que estabas usando. Funciona a través de la ventana de WhatsApp y puede dejar de funcionar tras una actualización de WhatsApp; entonces WhatsApp se abre con tu respuesta lista. Desactivado, WhatsApp se abre y la envías tú.")
        case .sk:
            return .init(reply: "Odpovedať", closeReply: "Zavrieť odpoveď", send: "Odoslať", emoji: "Emoji a symboly",
                         you: "Vy: %@", sending: "Odosiela sa…",
                         openedPrefilled: "Nepodarilo sa odoslať automaticky. Aplikácia %@ je otvorená s pripravenou odpoveďou.",
                         openedCopied: "Nepodarilo sa odoslať automaticky. Aplikácia %@ je otvorená a odpoveď je skopírovaná.",
                         handOffPrefilled: "Aplikácia %@ je otvorená s odpoveďou pripravenou na odoslanie.",
                         handOffCopied: "Aplikácia %@ je otvorená a odpoveď je skopírovaná.",
                         needsAutomation: "Povoľte Zenithu ovládať Správy, aby mohol odosielať odpovede.",
                         needsAccessibility: "Povoľte Prístupnosť na odosielanie odpovedí vo WhatsAppe.",
                         grantAccess: "Povoliť prístup",
                         failed: "Túto odpoveď sa nepodarilo odoslať.",
                         autoWhatsApp: "Odosielať odpovede vo WhatsAppe automaticky",
                         autoWhatsAppCaption: "Odpoveď z Dynamic Island otvorí konverzáciu vo WhatsAppe, napíše správu a stlačí Return, potom sa vráti do aplikácie, ktorú ste používali. Funguje cez okno WhatsAppu a po aktualizácii WhatsAppu môže prestať fungovať; vtedy sa WhatsApp otvorí s pripravenou odpoveďou. Keď je vypnuté, WhatsApp sa otvorí a odpoveď odošlete sami.")
        case .de:
            return .init(reply: "Antworten", closeReply: "Antwort schließen", send: "Senden", emoji: "Emoji & Symbole",
                         you: "Du: %@", sending: "Wird gesendet…",
                         openedPrefilled: "Automatisches Senden hat nicht geklappt. %@ ist geöffnet, deine Antwort steht bereit.",
                         openedCopied: "Automatisches Senden hat nicht geklappt. %@ ist geöffnet, deine Antwort ist kopiert.",
                         handOffPrefilled: "%@ ist geöffnet, deine Antwort ist bereit zum Senden.",
                         handOffCopied: "%@ ist geöffnet, deine Antwort ist kopiert.",
                         needsAutomation: "Erlaube Zenith, Nachrichten zu steuern, um Antworten zu senden.",
                         needsAccessibility: "Erlaube Bedienungshilfen, um WhatsApp-Antworten zu senden.",
                         grantAccess: "Zugriff erlauben",
                         failed: "Diese Antwort konnte nicht gesendet werden.",
                         autoWhatsApp: "WhatsApp-Antworten automatisch senden",
                         autoWhatsAppCaption: "Eine Antwort aus der Dynamic Island öffnet den Chat in WhatsApp, tippt deine Nachricht und drückt den Zeilenschalter, danach geht es zurück zur App, die du benutzt hast. Das läuft über das WhatsApp-Fenster und kann nach einem WhatsApp-Update nicht mehr funktionieren; dann öffnet sich WhatsApp mit deiner Antwort. Ist die Option aus, öffnet sich WhatsApp und du sendest selbst.")
        case .fr:
            return .init(reply: "Répondre", closeReply: "Fermer la réponse", send: "Envoyer", emoji: "Emoji et symboles",
                         you: "Vous : %@", sending: "Envoi…",
                         openedPrefilled: "Envoi automatique impossible. %@ est ouvert avec votre réponse prête.",
                         openedCopied: "Envoi automatique impossible. %@ est ouvert et votre réponse est copiée.",
                         handOffPrefilled: "%@ est ouvert avec votre réponse prête à envoyer.",
                         handOffCopied: "%@ est ouvert et votre réponse est copiée.",
                         needsAutomation: "Autorisez Zenith à contrôler Messages pour envoyer des réponses.",
                         needsAccessibility: "Autorisez l’Accessibilité pour envoyer des réponses WhatsApp.",
                         grantAccess: "Autoriser l’accès",
                         failed: "Impossible d’envoyer cette réponse.",
                         autoWhatsApp: "Envoyer automatiquement les réponses WhatsApp",
                         autoWhatsAppCaption: "Une réponse depuis la Dynamic Island ouvre la discussion dans WhatsApp, saisit votre message et appuie sur Retour, puis revient à l’app que vous utilisiez. Cela passe par la fenêtre de WhatsApp et peut cesser de fonctionner après une mise à jour de WhatsApp ; WhatsApp s’ouvre alors avec votre réponse prête. Désactivé, WhatsApp s’ouvre et vous l’envoyez vous-même.")
        case .it:
            return .init(reply: "Rispondi", closeReply: "Chiudi risposta", send: "Invia", emoji: "Emoji e simboli",
                         you: "Tu: %@", sending: "Invio…",
                         openedPrefilled: "Invio automatico non riuscito. L’app %@ è aperta con la risposta pronta.",
                         openedCopied: "Invio automatico non riuscito. L’app %@ è aperta e la risposta è stata copiata.",
                         handOffPrefilled: "L’app %@ è aperta con la risposta pronta da inviare.",
                         handOffCopied: "L’app %@ è aperta e la risposta è stata copiata.",
                         needsAutomation: "Consenti a Zenith di controllare Messaggi per inviare risposte.",
                         needsAccessibility: "Consenti l’Accessibilità per inviare risposte su WhatsApp.",
                         grantAccess: "Consenti accesso",
                         failed: "Impossibile inviare questa risposta.",
                         autoWhatsApp: "Invia automaticamente le risposte WhatsApp",
                         autoWhatsAppCaption: "Una risposta dalla Dynamic Island apre la chat in WhatsApp, scrive il messaggio e preme Invio, poi torna all’app che stavi usando. Funziona tramite la finestra di WhatsApp e potrebbe smettere di funzionare dopo un aggiornamento di WhatsApp; in quel caso WhatsApp si apre con la risposta pronta. Se disattivato, WhatsApp si apre e la invii tu.")
        case .ja:
            return .init(reply: "返信", closeReply: "返信を閉じる", send: "送信", emoji: "絵文字と記号",
                         you: "あなた: %@", sending: "送信中…",
                         openedPrefilled: "自動で送信できませんでした。返信を入力した状態で%@を開きました。",
                         openedCopied: "自動で送信できませんでした。%@を開き、返信をコピーしました。",
                         handOffPrefilled: "返信を入力した状態で%@を開きました。",
                         handOffCopied: "%@を開き、返信をコピーしました。",
                         needsAutomation: "返信を送信するには、Zenithに「メッセージ」の制御を許可してください。",
                         needsAccessibility: "WhatsAppの返信を送信するには、アクセシビリティを許可してください。",
                         grantAccess: "アクセスを許可",
                         failed: "この返信を送信できませんでした。",
                         autoWhatsApp: "WhatsAppの返信を自動で送信",
                         autoWhatsAppCaption: "Dynamic Islandからの返信は、WhatsAppでチャットを開いてメッセージを入力し、Returnキーを押してから、使っていたアプリに戻ります。WhatsAppのウインドウを操作するため、WhatsAppのアップデート後に動作しなくなることがあります。その場合は返信を入力した状態でWhatsAppが開きます。オフにすると、WhatsAppが開き、ご自身で送信します。")
        case .ko:
            return .init(reply: "답장", closeReply: "답장 닫기", send: "보내기", emoji: "이모티콘 및 기호",
                         you: "나: %@", sending: "보내는 중…",
                         openedPrefilled: "자동으로 보내지 못했습니다. 답장이 입력된 상태로 %@을(를) 열었습니다.",
                         openedCopied: "자동으로 보내지 못했습니다. %@을(를) 열고 답장을 복사했습니다.",
                         handOffPrefilled: "답장이 입력된 상태로 %@을(를) 열었습니다.",
                         handOffCopied: "%@을(를) 열고 답장을 복사했습니다.",
                         needsAutomation: "답장을 보내려면 Zenith가 메시지를 제어하도록 허용하세요.",
                         needsAccessibility: "WhatsApp 답장을 보내려면 손쉬운 사용을 허용하세요.",
                         grantAccess: "접근 허용",
                         failed: "이 답장을 보내지 못했습니다.",
                         autoWhatsApp: "WhatsApp 답장 자동으로 보내기",
                         autoWhatsAppCaption: "Dynamic Island에서 보낸 답장은 WhatsApp에서 대화를 열고 메시지를 입력한 뒤 Return 키를 누르고, 사용하던 앱으로 돌아갑니다. WhatsApp 윈도우를 통해 작동하므로 WhatsApp 업데이트 후에는 작동하지 않을 수 있으며, 그때는 답장이 입력된 상태로 WhatsApp이 열립니다. 끄면 WhatsApp이 열리고 직접 보냅니다.")
        case .uk:
            return .init(reply: "Відповісти", closeReply: "Закрити відповідь", send: "Надіслати", emoji: "Емодзі та символи",
                         you: "Ви: %@", sending: "Надсилання…",
                         openedPrefilled: "Не вдалося надіслати автоматично. %@ відкрито, відповідь уже введено.",
                         openedCopied: "Не вдалося надіслати автоматично. %@ відкрито, відповідь скопійовано.",
                         handOffPrefilled: "%@ відкрито, відповідь готова до надсилання.",
                         handOffCopied: "%@ відкрито, відповідь скопійовано.",
                         needsAutomation: "Дозвольте Zenith керувати Повідомленнями, щоб надсилати відповіді.",
                         needsAccessibility: "Дозвольте Універсальний доступ, щоб надсилати відповіді у WhatsApp.",
                         grantAccess: "Надати доступ",
                         failed: "Не вдалося надіслати цю відповідь.",
                         autoWhatsApp: "Надсилати відповіді WhatsApp автоматично",
                         autoWhatsAppCaption: "Відповідь із Dynamic Island відкриває чат у WhatsApp, вводить повідомлення й натискає Return, а потім повертає вас до попередньої програми. Це працює через вікно WhatsApp і може перестати працювати після оновлення WhatsApp; тоді WhatsApp відкриється з готовою відповіддю. Якщо вимкнено, WhatsApp відкриється, і ви надішлете відповідь самі.")
        case .zhHans:
            return .init(reply: "回复", closeReply: "关闭回复", send: "发送", emoji: "表情与符号",
                         you: "你：%@", sending: "正在发送…",
                         openedPrefilled: "无法自动发送。已打开%@，回复已填好。",
                         openedCopied: "无法自动发送。已打开%@，回复已拷贝。",
                         handOffPrefilled: "已打开%@，回复已填好，可以发送。",
                         handOffCopied: "已打开%@，回复已拷贝。",
                         needsAutomation: "允许 Zenith 控制“信息”以发送回复。",
                         needsAccessibility: "允许辅助功能以发送 WhatsApp 回复。",
                         grantAccess: "授予访问权限",
                         failed: "无法发送此回复。",
                         autoWhatsApp: "自动发送 WhatsApp 回复",
                         autoWhatsAppCaption: "从灵动岛回复时，会在 WhatsApp 中打开聊天、输入信息并按下 Return 键，然后返回你正在使用的 App。此功能通过 WhatsApp 窗口操作，WhatsApp 更新后可能失效；届时 WhatsApp 会打开并填好你的回复。关闭后，WhatsApp 会打开，由你自行发送。")
        case .zhTW:
            return .init(reply: "回覆", closeReply: "關閉回覆", send: "傳送", emoji: "表情符號與符號",
                         you: "你：%@", sending: "正在傳送…",
                         openedPrefilled: "無法自動傳送。已打開%@，並已填入回覆。",
                         openedCopied: "無法自動傳送。已打開%@，並已拷貝回覆。",
                         handOffPrefilled: "已打開%@，回覆已填入，可直接傳送。",
                         handOffCopied: "已打開%@，並已拷貝回覆。",
                         needsAutomation: "允許 Zenith 控制「訊息」以傳送回覆。",
                         needsAccessibility: "允許輔助使用以傳送 WhatsApp 回覆。",
                         grantAccess: "授予取用權限",
                         failed: "無法傳送此回覆。",
                         autoWhatsApp: "自動傳送 WhatsApp 回覆",
                         autoWhatsAppCaption: "從動態島回覆時，會在 WhatsApp 中打開聊天、輸入訊息並按下 Return 鍵，然後回到你正在使用的 App。此功能透過 WhatsApp 視窗運作，WhatsApp 更新後可能失效；屆時 WhatsApp 會打開並已填入你的回覆。關閉時，WhatsApp 會打開，由你自行傳送。")
        case .zhHK:
            return .init(reply: "回覆", closeReply: "關閉回覆", send: "傳送", emoji: "表情符號與符號",
                         you: "你：%@", sending: "正在傳送…",
                         openedPrefilled: "無法自動傳送。已開啟%@，並已填入回覆。",
                         openedCopied: "無法自動傳送。已開啟%@，並已拷貝回覆。",
                         handOffPrefilled: "已開啟%@，回覆已填入，可直接傳送。",
                         handOffCopied: "已開啟%@，並已拷貝回覆。",
                         needsAutomation: "允許 Zenith 控制「訊息」以傳送回覆。",
                         needsAccessibility: "允許輔助使用以傳送 WhatsApp 回覆。",
                         grantAccess: "授予取用權限",
                         failed: "無法傳送此回覆。",
                         autoWhatsApp: "自動傳送 WhatsApp 回覆",
                         autoWhatsAppCaption: "從動態島回覆時，會在 WhatsApp 中開啟聊天、輸入訊息並按下 Return 鍵，然後返回你正在使用的 App。此功能透過 WhatsApp 視窗運作，WhatsApp 更新後可能失效；屆時 WhatsApp 會開啟並已填入你的回覆。關閉時，WhatsApp 會開啟，由你自行傳送。")
        }
    }
}

// MARK: Claude Code live steps (Zenith fork)

/// The AI page's Progress, Usage and Stats tabs, the closed island's
/// “needs you”, and the settings that connect Claude Code’s hooks.
struct ZenithClaudeHooksStrings {
    let progress: String
    let usage: String
    let stats: String
    let working: String
    let workingInFormat: String
    let needsPermission: String
    let waitingForYou: String
    let done: String
    let doneAfterFormat: String
    let idle: String
    let reading: String
    let editing: String
    let saving: String
    let runningStep: String
    let workingStep: String
    let saved: String
    let finished: String
    let failed: String
    let noSteps: String
    let nothingRunning: String
    let connectHint: String
    let connect: String
    let noLimits: String
    let nextSession: String
    let needsYou: String
    let doneShort: String
    let section: String
    let caption: String
    let privacy: String
    let disconnect: String
    let connected: String
    let outdated: String
    let notConnected: String
    let unreadable: String
    let lastEventFormat: String
    let noEvents: String
    let newSessions: String
    let confirmTitle: String
    let confirmMessage: String
    let add: String
    let cancel: String
    let editFailed: String
    let sound: String
    let soundCaption: String

    func workingIn(_ folder: String) -> String { workingInFormat.replacingOccurrences(of: "%@", with: folder) }
    func doneAfter(_ duration: String) -> String { doneAfterFormat.replacingOccurrences(of: "%@", with: duration) }
    func lastEvent(_ relative: String) -> String { lastEventFormat.replacingOccurrences(of: "%@", with: relative) }
}

extension ZenithStrings {
    static func claudeHooks(_ language: AppLanguage) -> ZenithClaudeHooksStrings {
        switch language {
        case .enUS:
            return .init(progress: "Progress",
                         usage: "Usage",
                         stats: "Stats",
                         working: "Working",
                         workingInFormat: "Working in %@",
                         needsPermission: "Needs your permission",
                         waitingForYou: "Waiting for you",
                         done: "Done",
                         doneAfterFormat: "Done in %@",
                         idle: "Idle",
                         reading: "Reading…",
                         editing: "Editing…",
                         saving: "Saving…",
                         runningStep: "Running…",
                         workingStep: "Working…",
                         saved: "Saved",
                         finished: "Finished",
                         failed: "Failed",
                         noSteps: "Waiting for the first step",
                         nothingRunning: "No agent is working",
                         connectHint: "Connect Claude Code to follow each step here.",
                         connect: "Connect Claude Code",
                         noLimits: "No limits yet",
                         nextSession: "Next session",
                         needsYou: "needs you",
                         doneShort: "done",
                         section: "Claude Code live steps",
                         caption: "Claude Code tells Zenith each step through its hooks: the AI page shows the steps and the file being written, and the closed island says when a session needs you.",
                         privacy: "The hook keeps the tool, a file’s or program’s name and line counts. Prompts, commands, file contents and messages are never stored.",
                         disconnect: "Disconnect",
                         connected: "Connected in ~/.claude/settings.json",
                         outdated: "Connected for another Zenith build or an older hook. Connect again to update.",
                         notConnected: "Not connected",
                         unreadable: "~/.claude/settings.json isn’t valid JSON. Fix it by hand.",
                         lastEventFormat: "Last event %@",
                         noEvents: "No events yet",
                         newSessions: "New Claude Code sessions pick up the change.",
                         confirmTitle: "Connect Claude Code to Zenith?",
                         confirmMessage: "Zenith merges these hooks into ~/.claude/settings.json and keeps the old file as settings.json.zenith-backup. Your other settings and hooks stay as they are.",
                         add: "Connect",
                         cancel: "Cancel",
                         editFailed: "Couldn’t update ~/.claude/settings.json.",
                         sound: "Sound when Claude needs you",
                         soundCaption: "A soft sound when a session asks for permission or waits for you.")
        case .ptBR:
            return .init(progress: "Progresso",
                         usage: "Uso",
                         stats: "Estatísticas",
                         working: "Trabalhando",
                         workingInFormat: "Trabalhando em %@",
                         needsPermission: "Precisa da sua permissão",
                         waitingForYou: "Esperando você",
                         done: "Concluído",
                         doneAfterFormat: "Concluído em %@",
                         idle: "Inativo",
                         reading: "Lendo…",
                         editing: "Editando…",
                         saving: "Salvando…",
                         runningStep: "Executando…",
                         workingStep: "Trabalhando…",
                         saved: "Salvo",
                         finished: "Concluído",
                         failed: "Falhou",
                         noSteps: "Aguardando o primeiro passo",
                         nothingRunning: "Nenhum agente trabalhando",
                         connectHint: "Conecte o Claude Code para acompanhar cada passo aqui.",
                         connect: "Conectar Claude Code",
                         noLimits: "Sem limites ainda",
                         nextSession: "Próxima sessão",
                         needsYou: "precisa de você",
                         doneShort: "pronto",
                         section: "Passos ao vivo do Claude Code",
                         caption: "O Claude Code informa cada passo ao Zenith pelos hooks: a página de IA mostra os passos e o arquivo sendo escrito, e a ilha fechada avisa quando uma sessão precisa de você.",
                         privacy: "O hook guarda a ferramenta, o nome de um arquivo ou programa e a contagem de linhas. Prompts, comandos, conteúdo de arquivos e mensagens nunca são guardados.",
                         disconnect: "Desconectar",
                         connected: "Conectado em ~/.claude/settings.json",
                         outdated: "Conectado para outra versão do Zenith ou um hook antigo. Conecte de novo para atualizar.",
                         notConnected: "Não conectado",
                         unreadable: "~/.claude/settings.json não é um JSON válido. Corrija-o manualmente.",
                         lastEventFormat: "Último evento %@",
                         noEvents: "Nenhum evento ainda",
                         newSessions: "Novas sessões do Claude Code usam a mudança.",
                         confirmTitle: "Conectar o Claude Code ao Zenith?",
                         confirmMessage: "O Zenith mescla estes hooks em ~/.claude/settings.json e guarda o arquivo antigo como settings.json.zenith-backup. Suas outras configurações e hooks continuam como estão.",
                         add: "Conectar",
                         cancel: "Cancelar",
                         editFailed: "Não foi possível atualizar ~/.claude/settings.json.",
                         sound: "Som quando o Claude precisa de você",
                         soundCaption: "Um som suave quando uma sessão pede permissão ou espera por você.")
        case .tr:
            return .init(progress: "İlerleme",
                         usage: "Kullanım",
                         stats: "İstatistikler",
                         working: "Çalışıyor",
                         workingInFormat: "%@ içinde çalışıyor",
                         needsPermission: "İznini bekliyor",
                         waitingForYou: "Seni bekliyor",
                         done: "Bitti",
                         doneAfterFormat: "%@ içinde bitti",
                         idle: "Boşta",
                         reading: "Okunuyor…",
                         editing: "Düzenleniyor…",
                         saving: "Kaydediliyor…",
                         runningStep: "Çalıştırılıyor…",
                         workingStep: "Çalışıyor…",
                         saved: "Kaydedildi",
                         finished: "Bitti",
                         failed: "Başarısız",
                         noSteps: "İlk adım bekleniyor",
                         nothingRunning: "Çalışan ajan yok",
                         connectHint: "Her adımı burada izlemek için Claude Code’u bağla.",
                         connect: "Claude Code’u bağla",
                         noLimits: "Henüz limit yok",
                         nextSession: "Sonraki oturum",
                         needsYou: "seni bekliyor",
                         doneShort: "bitti",
                         section: "Claude Code canlı adımları",
                         caption: "Claude Code her adımı kancaları üzerinden Zenith’e bildirir: yapay zekâ sayfası adımları ve yazılan dosyayı gösterir, kapalı ada da bir oturum seni beklediğinde haber verir.",
                         privacy: "Kanca yalnızca aracı, bir dosyanın ya da programın adını ve satır sayılarını tutar. İstemler, komutlar, dosya içerikleri ve mesajlar asla saklanmaz.",
                         disconnect: "Bağlantıyı kes",
                         connected: "~/.claude/settings.json içinde bağlı",
                         outdated: "Başka bir Zenith derlemesi ya da eski bir kanca için bağlı. Güncellemek için yeniden bağla.",
                         notConnected: "Bağlı değil",
                         unreadable: "~/.claude/settings.json geçerli bir JSON değil. Elle düzelt.",
                         lastEventFormat: "Son olay %@",
                         noEvents: "Henüz olay yok",
                         newSessions: "Yeni Claude Code oturumları değişikliği kullanır.",
                         confirmTitle: "Claude Code Zenith’e bağlansın mı?",
                         confirmMessage: "Zenith bu kancaları ~/.claude/settings.json dosyasına ekler ve eski dosyayı settings.json.zenith-backup olarak saklar. Diğer ayarların ve kancaların olduğu gibi kalır.",
                         add: "Bağla",
                         cancel: "İptal",
                         editFailed: "~/.claude/settings.json güncellenemedi.",
                         sound: "Claude seni beklediğinde ses çal",
                         soundCaption: "Bir oturum izin istediğinde ya da seni beklediğinde yumuşak bir ses.")
        case .ru:
            return .init(progress: "Ход работы",
                         usage: "Использование",
                         stats: "Статистика",
                         working: "Работает",
                         workingInFormat: "Работает в %@",
                         needsPermission: "Нужно ваше разрешение",
                         waitingForYou: "Ждёт вас",
                         done: "Готово",
                         doneAfterFormat: "Готово за %@",
                         idle: "Простаивает",
                         reading: "Чтение…",
                         editing: "Правка…",
                         saving: "Сохранение…",
                         runningStep: "Выполнение…",
                         workingStep: "Работа…",
                         saved: "Сохранено",
                         finished: "Завершено",
                         failed: "Ошибка",
                         noSteps: "Ждём первый шаг",
                         nothingRunning: "Ни один агент не работает",
                         connectHint: "Подключите Claude Code, чтобы видеть здесь каждый шаг.",
                         connect: "Подключить Claude Code",
                         noLimits: "Лимитов пока нет",
                         nextSession: "Следующая сессия",
                         needsYou: "ждёт вас",
                         doneShort: "готово",
                         section: "Шаги Claude Code в реальном времени",
                         caption: "Claude Code сообщает Zenith о каждом шаге через хуки: страница ИИ показывает шаги и файл, который сейчас пишется, а закрытый остров говорит, когда сессии нужны вы.",
                         privacy: "Хук сохраняет только инструмент, имя файла или программы и число строк. Промпты, команды, содержимое файлов и сообщения никогда не сохраняются.",
                         disconnect: "Отключить",
                         connected: "Подключено в ~/.claude/settings.json",
                         outdated: "Подключено для другой сборки Zenith или старого хука. Подключите снова, чтобы обновить.",
                         notConnected: "Не подключено",
                         unreadable: "~/.claude/settings.json — некорректный JSON. Исправьте его вручную.",
                         lastEventFormat: "Последнее событие %@",
                         noEvents: "Событий пока нет",
                         newSessions: "Изменение подхватят новые сессии Claude Code.",
                         confirmTitle: "Подключить Claude Code к Zenith?",
                         confirmMessage: "Zenith добавит эти хуки в ~/.claude/settings.json и сохранит прежний файл как settings.json.zenith-backup. Остальные настройки и хуки не изменятся.",
                         add: "Подключить",
                         cancel: "Отменить",
                         editFailed: "Не удалось обновить ~/.claude/settings.json.",
                         sound: "Звук, когда Claude нужны вы",
                         soundCaption: "Тихий звук, когда сессия просит разрешения или ждёт вас.")
        case .es:
            return .init(progress: "Progreso",
                         usage: "Uso",
                         stats: "Estadísticas",
                         working: "Trabajando",
                         workingInFormat: "Trabajando en %@",
                         needsPermission: "Necesita tu permiso",
                         waitingForYou: "Esperándote",
                         done: "Listo",
                         doneAfterFormat: "Listo en %@",
                         idle: "Inactivo",
                         reading: "Leyendo…",
                         editing: "Editando…",
                         saving: "Guardando…",
                         runningStep: "Ejecutando…",
                         workingStep: "Trabajando…",
                         saved: "Guardado",
                         finished: "Terminado",
                         failed: "Falló",
                         noSteps: "Esperando el primer paso",
                         nothingRunning: "Ningún agente está trabajando",
                         connectHint: "Conecta Claude Code para seguir cada paso aquí.",
                         connect: "Conectar Claude Code",
                         noLimits: "Aún no hay límites",
                         nextSession: "Siguiente sesión",
                         needsYou: "te necesita",
                         doneShort: "listo",
                         section: "Pasos en vivo de Claude Code",
                         caption: "Claude Code le cuenta cada paso a Zenith mediante sus hooks: la página de IA muestra los pasos y el archivo que se escribe, y la isla cerrada avisa cuando una sesión te necesita.",
                         privacy: "El hook guarda la herramienta, el nombre de un archivo o programa y el número de líneas. Nunca se guardan prompts, comandos, contenido de archivos ni mensajes.",
                         disconnect: "Desconectar",
                         connected: "Conectado en ~/.claude/settings.json",
                         outdated: "Conectado para otra versión de Zenith o un hook antiguo. Vuelve a conectar para actualizar.",
                         notConnected: "No conectado",
                         unreadable: "~/.claude/settings.json no es un JSON válido. Corrígelo a mano.",
                         lastEventFormat: "Último evento %@",
                         noEvents: "Aún no hay eventos",
                         newSessions: "Las nuevas sesiones de Claude Code usan el cambio.",
                         confirmTitle: "¿Conectar Claude Code con Zenith?",
                         confirmMessage: "Zenith combina estos hooks en ~/.claude/settings.json y guarda el archivo anterior como settings.json.zenith-backup. El resto de tus ajustes y hooks no cambia.",
                         add: "Conectar",
                         cancel: "Cancelar",
                         editFailed: "No se pudo actualizar ~/.claude/settings.json.",
                         sound: "Sonido cuando Claude te necesita",
                         soundCaption: "Un sonido suave cuando una sesión pide permiso o te espera.")
        case .sk:
            return .init(progress: "Priebeh",
                         usage: "Využitie",
                         stats: "Štatistiky",
                         working: "Pracuje",
                         workingInFormat: "Pracuje v %@",
                         needsPermission: "Potrebuje tvoje povolenie",
                         waitingForYou: "Čaká na teba",
                         done: "Hotovo",
                         doneAfterFormat: "Hotovo za %@",
                         idle: "Nečinný",
                         reading: "Číta…",
                         editing: "Upravuje…",
                         saving: "Ukladá…",
                         runningStep: "Spúšťa…",
                         workingStep: "Pracuje…",
                         saved: "Uložené",
                         finished: "Dokončené",
                         failed: "Zlyhalo",
                         noSteps: "Čaká sa na prvý krok",
                         nothingRunning: "Žiadny agent nepracuje",
                         connectHint: "Pripoj Claude Code a sleduj tu každý krok.",
                         connect: "Pripojiť Claude Code",
                         noLimits: "Zatiaľ žiadne limity",
                         nextSession: "Ďalšia relácia",
                         needsYou: "potrebuje ťa",
                         doneShort: "hotovo",
                         section: "Kroky Claude Code naživo",
                         caption: "Claude Code cez svoje hooky oznamuje Zenithu každý krok: stránka AI ukazuje kroky a súbor, ktorý sa práve zapisuje, a zatvorený ostrov dá vedieť, keď ťa relácia potrebuje.",
                         privacy: "Hook uchováva len nástroj, názov súboru alebo programu a počty riadkov. Prompty, príkazy, obsah súborov ani správy sa nikdy neukladajú.",
                         disconnect: "Odpojiť",
                         connected: "Pripojené v ~/.claude/settings.json",
                         outdated: "Pripojené pre inú verziu Zenithu alebo starší hook. Pripoj znova na aktualizáciu.",
                         notConnected: "Nepripojené",
                         unreadable: "~/.claude/settings.json nie je platný JSON. Oprav ho ručne.",
                         lastEventFormat: "Posledná udalosť %@",
                         noEvents: "Zatiaľ žiadne udalosti",
                         newSessions: "Zmenu použijú nové relácie Claude Code.",
                         confirmTitle: "Pripojiť Claude Code k Zenithu?",
                         confirmMessage: "Zenith zlúči tieto hooky do ~/.claude/settings.json a pôvodný súbor uloží ako settings.json.zenith-backup. Ostatné nastavenia a hooky zostanú nezmenené.",
                         add: "Pripojiť",
                         cancel: "Zrušiť",
                         editFailed: "~/.claude/settings.json sa nepodarilo aktualizovať.",
                         sound: "Zvuk, keď ťa Claude potrebuje",
                         soundCaption: "Jemný zvuk, keď relácia žiada o povolenie alebo na teba čaká.")
        case .de:
            return .init(progress: "Fortschritt",
                         usage: "Nutzung",
                         stats: "Statistik",
                         working: "Arbeitet",
                         workingInFormat: "Arbeitet in %@",
                         needsPermission: "Braucht deine Erlaubnis",
                         waitingForYou: "Wartet auf dich",
                         done: "Fertig",
                         doneAfterFormat: "Fertig nach %@",
                         idle: "Inaktiv",
                         reading: "Liest…",
                         editing: "Bearbeitet…",
                         saving: "Speichert…",
                         runningStep: "Führt aus…",
                         workingStep: "Arbeitet…",
                         saved: "Gespeichert",
                         finished: "Erledigt",
                         failed: "Fehlgeschlagen",
                         noSteps: "Warten auf den ersten Schritt",
                         nothingRunning: "Kein Agent arbeitet",
                         connectHint: "Verbinde Claude Code, um hier jeden Schritt zu sehen.",
                         connect: "Claude Code verbinden",
                         noLimits: "Noch keine Limits",
                         nextSession: "Nächste Sitzung",
                         needsYou: "braucht dich",
                         doneShort: "fertig",
                         section: "Claude Code live",
                         caption: "Claude Code meldet Zenith jeden Schritt über seine Hooks: Die KI-Seite zeigt die Schritte und die Datei, die gerade geschrieben wird, und die geschlossene Insel sagt Bescheid, wenn eine Sitzung dich braucht.",
                         privacy: "Der Hook behält nur das Werkzeug, den Namen einer Datei oder eines Programms und Zeilenzahlen. Prompts, Befehle, Dateiinhalte und Nachrichten werden nie gespeichert.",
                         disconnect: "Trennen",
                         connected: "Verbunden in ~/.claude/settings.json",
                         outdated: "Für einen anderen Zenith-Build oder einen älteren Hook verbunden. Erneut verbinden, um zu aktualisieren.",
                         notConnected: "Nicht verbunden",
                         unreadable: "~/.claude/settings.json ist kein gültiges JSON. Bitte von Hand korrigieren.",
                         lastEventFormat: "Letztes Ereignis %@",
                         noEvents: "Noch keine Ereignisse",
                         newSessions: "Neue Claude-Code-Sitzungen übernehmen die Änderung.",
                         confirmTitle: "Claude Code mit Zenith verbinden?",
                         confirmMessage: "Zenith fügt diese Hooks in ~/.claude/settings.json ein und behält die alte Datei als settings.json.zenith-backup. Deine anderen Einstellungen und Hooks bleiben, wie sie sind.",
                         add: "Verbinden",
                         cancel: "Abbrechen",
                         editFailed: "~/.claude/settings.json konnte nicht aktualisiert werden.",
                         sound: "Ton, wenn Claude dich braucht",
                         soundCaption: "Ein leiser Ton, wenn eine Sitzung um Erlaubnis bittet oder auf dich wartet.")
        case .fr:
            return .init(progress: "Progression",
                         usage: "Utilisation",
                         stats: "Statistiques",
                         working: "Au travail",
                         workingInFormat: "Au travail dans %@",
                         needsPermission: "Attend votre autorisation",
                         waitingForYou: "Vous attend",
                         done: "Terminé",
                         doneAfterFormat: "Terminé en %@",
                         idle: "Inactif",
                         reading: "Lecture…",
                         editing: "Modification…",
                         saving: "Enregistrement…",
                         runningStep: "Exécution…",
                         workingStep: "Au travail…",
                         saved: "Enregistré",
                         finished: "Terminé",
                         failed: "Échec",
                         noSteps: "En attente de la première étape",
                         nothingRunning: "Aucun agent au travail",
                         connectHint: "Connectez Claude Code pour suivre chaque étape ici.",
                         connect: "Connecter Claude Code",
                         noLimits: "Pas encore de limites",
                         nextSession: "Session suivante",
                         needsYou: "a besoin de vous",
                         doneShort: "terminé",
                         section: "Étapes de Claude Code en direct",
                         caption: "Claude Code signale chaque étape à Zenith par ses hooks\u{00A0}: la page IA montre les étapes et le fichier en cours d’écriture, et l’île fermée prévient quand une session a besoin de vous.",
                         privacy: "Le hook ne garde que l’outil, le nom d’un fichier ou d’un programme et le nombre de lignes. Les prompts, commandes, contenus de fichiers et messages ne sont jamais enregistrés.",
                         disconnect: "Déconnecter",
                         connected: "Connecté dans ~/.claude/settings.json",
                         outdated: "Connecté pour une autre version de Zenith ou un ancien hook. Reconnectez pour mettre à jour.",
                         notConnected: "Non connecté",
                         unreadable: "~/.claude/settings.json n’est pas un JSON valide. Corrigez-le à la main.",
                         lastEventFormat: "Dernier événement\u{00A0}: %@",
                         noEvents: "Aucun événement pour l’instant",
                         newSessions: "Les nouvelles sessions Claude Code prennent en compte le changement.",
                         confirmTitle: "Connecter Claude Code à Zenith\u{00A0}?",
                         confirmMessage: "Zenith fusionne ces hooks dans ~/.claude/settings.json et garde l’ancien fichier sous settings.json.zenith-backup. Vos autres réglages et hooks restent inchangés.",
                         add: "Connecter",
                         cancel: "Annuler",
                         editFailed: "Impossible de mettre à jour ~/.claude/settings.json.",
                         sound: "Son quand Claude a besoin de vous",
                         soundCaption: "Un son discret quand une session demande une autorisation ou vous attend.")
        case .it:
            return .init(progress: "Avanzamento",
                         usage: "Utilizzo",
                         stats: "Statistiche",
                         working: "Al lavoro",
                         workingInFormat: "Al lavoro in %@",
                         needsPermission: "Serve il tuo permesso",
                         waitingForYou: "Ti aspetta",
                         done: "Fatto",
                         doneAfterFormat: "Fatto in %@",
                         idle: "Inattivo",
                         reading: "Lettura…",
                         editing: "Modifica…",
                         saving: "Salvataggio…",
                         runningStep: "Esecuzione…",
                         workingStep: "Al lavoro…",
                         saved: "Salvato",
                         finished: "Completato",
                         failed: "Non riuscito",
                         noSteps: "In attesa del primo passo",
                         nothingRunning: "Nessun agente al lavoro",
                         connectHint: "Collega Claude Code per seguire qui ogni passo.",
                         connect: "Collega Claude Code",
                         noLimits: "Ancora nessun limite",
                         nextSession: "Sessione successiva",
                         needsYou: "ha bisogno di te",
                         doneShort: "fatto",
                         section: "Passi di Claude Code dal vivo",
                         caption: "Claude Code comunica a Zenith ogni passo tramite i suoi hook: la pagina IA mostra i passi e il file in scrittura, e l’isola chiusa avvisa quando una sessione ha bisogno di te.",
                         privacy: "L’hook conserva solo lo strumento, il nome di un file o di un programma e il numero di righe. Prompt, comandi, contenuti dei file e messaggi non vengono mai salvati.",
                         disconnect: "Scollega",
                         connected: "Collegato in ~/.claude/settings.json",
                         outdated: "Collegato per un’altra build di Zenith o un hook più vecchio. Collega di nuovo per aggiornare.",
                         notConnected: "Non collegato",
                         unreadable: "~/.claude/settings.json non è un JSON valido. Correggilo a mano.",
                         lastEventFormat: "Ultimo evento %@",
                         noEvents: "Ancora nessun evento",
                         newSessions: "Le nuove sessioni di Claude Code usano la modifica.",
                         confirmTitle: "Collegare Claude Code a Zenith?",
                         confirmMessage: "Zenith unisce questi hook in ~/.claude/settings.json e conserva il file precedente come settings.json.zenith-backup. Le altre impostazioni e gli altri hook restano come sono.",
                         add: "Collega",
                         cancel: "Annulla",
                         editFailed: "Impossibile aggiornare ~/.claude/settings.json.",
                         sound: "Suono quando Claude ha bisogno di te",
                         soundCaption: "Un suono leggero quando una sessione chiede un permesso o ti aspetta.")
        case .ja:
            return .init(progress: "進捗",
                         usage: "使用量",
                         stats: "統計",
                         working: "作業中",
                         workingInFormat: "%@ で作業中",
                         needsPermission: "許可を求めています",
                         waitingForYou: "入力を待っています",
                         done: "完了",
                         doneAfterFormat: "%@ で完了",
                         idle: "待機中",
                         reading: "読み込み中…",
                         editing: "編集中…",
                         saving: "保存中…",
                         runningStep: "実行中…",
                         workingStep: "作業中…",
                         saved: "保存済み",
                         finished: "完了",
                         failed: "失敗",
                         noSteps: "最初のステップを待っています",
                         nothingRunning: "作業中のエージェントはありません",
                         connectHint: "Claude Code を接続すると、各ステップをここで追えます。",
                         connect: "Claude Code を接続",
                         noLimits: "まだ上限はありません",
                         nextSession: "次のセッション",
                         needsYou: "対応が必要",
                         doneShort: "完了",
                         section: "Claude Code のライブステップ",
                         caption: "Claude Code はフックで各ステップを Zenith に伝えます。AI ページにはステップと書き込み中のファイルが表示され、セッションが対応を待つと閉じたアイランドが知らせます。",
                         privacy: "フックが残すのはツール、ファイル名またはプログラム名、行数だけです。プロンプト、コマンド、ファイルの内容、メッセージは保存されません。",
                         disconnect: "接続を解除",
                         connected: "~/.claude/settings.json で接続済み",
                         outdated: "別の Zenith ビルドまたは古いフックで接続されています。更新するにはもう一度接続してください。",
                         notConnected: "未接続",
                         unreadable: "~/.claude/settings.json が正しい JSON ではありません。手動で修正してください。",
                         lastEventFormat: "最後のイベント: %@",
                         noEvents: "まだイベントはありません",
                         newSessions: "新しい Claude Code セッションから反映されます。",
                         confirmTitle: "Claude Code を Zenith に接続しますか？",
                         confirmMessage: "Zenith はこれらのフックを ~/.claude/settings.json に追加し、元のファイルを settings.json.zenith-backup として保存します。ほかの設定やフックはそのままです。",
                         add: "接続",
                         cancel: "キャンセル",
                         editFailed: "~/.claude/settings.json を更新できませんでした。",
                         sound: "Claude が対応を求めたときにサウンド",
                         soundCaption: "セッションが許可を求めたり入力を待ったりしたときに、控えめな音で知らせます。")
        case .ko:
            return .init(progress: "진행",
                         usage: "사용량",
                         stats: "통계",
                         working: "작업 중",
                         workingInFormat: "%@에서 작업 중",
                         needsPermission: "권한이 필요합니다",
                         waitingForYou: "입력을 기다리는 중",
                         done: "완료",
                         doneAfterFormat: "%@ 만에 완료",
                         idle: "대기 중",
                         reading: "읽는 중…",
                         editing: "편집 중…",
                         saving: "저장 중…",
                         runningStep: "실행 중…",
                         workingStep: "작업 중…",
                         saved: "저장됨",
                         finished: "완료됨",
                         failed: "실패",
                         noSteps: "첫 단계를 기다리는 중",
                         nothingRunning: "작업 중인 에이전트 없음",
                         connectHint: "Claude Code를 연결하면 여기에서 각 단계를 볼 수 있습니다.",
                         connect: "Claude Code 연결",
                         noLimits: "아직 한도 없음",
                         nextSession: "다음 세션",
                         needsYou: "확인 필요",
                         doneShort: "완료",
                         section: "Claude Code 실시간 단계",
                         caption: "Claude Code가 훅으로 각 단계를 Zenith에 알립니다. AI 페이지에는 단계와 작성 중인 파일이 표시되고, 세션이 기다릴 때 닫힌 아일랜드가 알려 줍니다.",
                         privacy: "훅은 도구, 파일 또는 프로그램 이름, 줄 수만 남깁니다. 프롬프트, 명령, 파일 내용, 메시지는 절대 저장되지 않습니다.",
                         disconnect: "연결 해제",
                         connected: "~/.claude/settings.json에 연결됨",
                         outdated: "다른 Zenith 빌드 또는 이전 훅으로 연결되어 있습니다. 업데이트하려면 다시 연결하세요.",
                         notConnected: "연결 안 됨",
                         unreadable: "~/.claude/settings.json이 올바른 JSON이 아닙니다. 직접 수정하세요.",
                         lastEventFormat: "마지막 이벤트 %@",
                         noEvents: "아직 이벤트 없음",
                         newSessions: "새 Claude Code 세션부터 적용됩니다.",
                         confirmTitle: "Claude Code를 Zenith에 연결할까요?",
                         confirmMessage: "Zenith가 이 훅을 ~/.claude/settings.json에 병합하고 기존 파일을 settings.json.zenith-backup으로 보관합니다. 다른 설정과 훅은 그대로 유지됩니다.",
                         add: "연결",
                         cancel: "취소",
                         editFailed: "~/.claude/settings.json을 업데이트할 수 없습니다.",
                         sound: "Claude가 기다릴 때 소리",
                         soundCaption: "세션이 권한을 요청하거나 입력을 기다릴 때 부드러운 소리를 냅니다.")
        case .uk:
            return .init(progress: "Хід роботи",
                         usage: "Використання",
                         stats: "Статистика",
                         working: "Працює",
                         workingInFormat: "Працює в %@",
                         needsPermission: "Потрібен ваш дозвіл",
                         waitingForYou: "Чекає на вас",
                         done: "Готово",
                         doneAfterFormat: "Готово за %@",
                         idle: "Неактивний",
                         reading: "Читання…",
                         editing: "Редагування…",
                         saving: "Збереження…",
                         runningStep: "Виконання…",
                         workingStep: "Робота…",
                         saved: "Збережено",
                         finished: "Завершено",
                         failed: "Помилка",
                         noSteps: "Чекаємо на перший крок",
                         nothingRunning: "Жоден агент не працює",
                         connectHint: "Підключіть Claude Code, щоб бачити тут кожен крок.",
                         connect: "Підключити Claude Code",
                         noLimits: "Лімітів ще немає",
                         nextSession: "Наступна сесія",
                         needsYou: "чекає на вас",
                         doneShort: "готово",
                         section: "Кроки Claude Code наживо",
                         caption: "Claude Code повідомляє Zenith про кожен крок через хуки: сторінка ШІ показує кроки й файл, що зараз записується, а закритий острів повідомляє, коли сесії потрібні ви.",
                         privacy: "Хук зберігає лише інструмент, назву файлу чи програми та кількість рядків. Промпти, команди, вміст файлів і повідомлення ніколи не зберігаються.",
                         disconnect: "Відключити",
                         connected: "Підключено в ~/.claude/settings.json",
                         outdated: "Підключено для іншої збірки Zenith або старого хука. Підключіть знову, щоб оновити.",
                         notConnected: "Не підключено",
                         unreadable: "~/.claude/settings.json — некоректний JSON. Виправте його вручну.",
                         lastEventFormat: "Остання подія %@",
                         noEvents: "Подій ще немає",
                         newSessions: "Зміну підхоплять нові сесії Claude Code.",
                         confirmTitle: "Підключити Claude Code до Zenith?",
                         confirmMessage: "Zenith додасть ці хуки до ~/.claude/settings.json і збереже попередній файл як settings.json.zenith-backup. Інші налаштування й хуки не зміняться.",
                         add: "Підключити",
                         cancel: "Скасувати",
                         editFailed: "Не вдалося оновити ~/.claude/settings.json.",
                         sound: "Звук, коли Claude потрібні ви",
                         soundCaption: "Тихий звук, коли сесія просить дозволу або чекає на вас.")
        case .zhHans:
            return .init(progress: "进度",
                         usage: "用量",
                         stats: "统计",
                         working: "工作中",
                         workingInFormat: "在 %@ 中工作",
                         needsPermission: "需要你的许可",
                         waitingForYou: "正在等你",
                         done: "完成",
                         doneAfterFormat: "用时 %@ 完成",
                         idle: "空闲",
                         reading: "正在读取…",
                         editing: "正在编辑…",
                         saving: "正在保存…",
                         runningStep: "正在运行…",
                         workingStep: "工作中…",
                         saved: "已保存",
                         finished: "已完成",
                         failed: "失败",
                         noSteps: "等待第一步",
                         nothingRunning: "没有正在工作的智能体",
                         connectHint: "连接 Claude Code 即可在这里查看每一步。",
                         connect: "连接 Claude Code",
                         noLimits: "暂无额度信息",
                         nextSession: "下一个会话",
                         needsYou: "需要你",
                         doneShort: "完成",
                         section: "Claude Code 实时步骤",
                         caption: "Claude Code 通过钩子把每一步告诉 Zenith：AI 页面显示步骤和正在写入的文件，会话需要你时，收起的灵动岛会提示。",
                         privacy: "钩子只保留工具、文件或程序的名称以及行数。提示词、命令、文件内容和消息从不保存。",
                         disconnect: "断开连接",
                         connected: "已在 ~/.claude/settings.json 中连接",
                         outdated: "已为其他 Zenith 版本或旧钩子连接。再次连接即可更新。",
                         notConnected: "未连接",
                         unreadable: "~/.claude/settings.json 不是有效的 JSON。请手动修复。",
                         lastEventFormat: "最后事件：%@",
                         noEvents: "暂无事件",
                         newSessions: "新的 Claude Code 会话会应用此更改。",
                         confirmTitle: "将 Claude Code 连接到 Zenith？",
                         confirmMessage: "Zenith 会把这些钩子合并到 ~/.claude/settings.json，并将原文件保存为 settings.json.zenith-backup。其他设置和钩子保持不变。",
                         add: "连接",
                         cancel: "取消",
                         editFailed: "无法更新 ~/.claude/settings.json。",
                         sound: "Claude 需要你时播放声音",
                         soundCaption: "会话请求许可或等待你时，播放柔和的提示音。")
        case .zhTW:
            return .init(progress: "進度",
                         usage: "用量",
                         stats: "統計",
                         working: "工作中",
                         workingInFormat: "在 %@ 中工作",
                         needsPermission: "需要你的許可",
                         waitingForYou: "正在等你",
                         done: "完成",
                         doneAfterFormat: "花了 %@ 完成",
                         idle: "閒置",
                         reading: "正在讀取…",
                         editing: "正在編輯…",
                         saving: "正在儲存…",
                         runningStep: "正在執行…",
                         workingStep: "工作中…",
                         saved: "已儲存",
                         finished: "已完成",
                         failed: "失敗",
                         noSteps: "等待第一步",
                         nothingRunning: "沒有正在工作的代理",
                         connectHint: "連接 Claude Code 即可在這裡查看每一步。",
                         connect: "連接 Claude Code",
                         noLimits: "尚無額度資訊",
                         nextSession: "下一個工作階段",
                         needsYou: "需要你",
                         doneShort: "完成",
                         section: "Claude Code 即時步驟",
                         caption: "Claude Code 會透過掛鉤把每一步告訴 Zenith：AI 頁面顯示步驟和正在寫入的檔案，工作階段需要你時，收合的動態島會提示。",
                         privacy: "掛鉤只保留工具、檔案或程式的名稱和行數。提示詞、指令、檔案內容和訊息從不儲存。",
                         disconnect: "中斷連接",
                         connected: "已在 ~/.claude/settings.json 中連接",
                         outdated: "已為其他 Zenith 版本或舊掛鉤連接。再次連接即可更新。",
                         notConnected: "未連接",
                         unreadable: "~/.claude/settings.json 不是有效的 JSON。請手動修正。",
                         lastEventFormat: "最後事件：%@",
                         noEvents: "尚無事件",
                         newSessions: "新的 Claude Code 工作階段會套用此變更。",
                         confirmTitle: "要將 Claude Code 連接到 Zenith 嗎？",
                         confirmMessage: "Zenith 會將這些掛鉤合併到 ~/.claude/settings.json，並把原檔案保存為 settings.json.zenith-backup。其他設定和掛鉤保持不變。",
                         add: "連接",
                         cancel: "取消",
                         editFailed: "無法更新 ~/.claude/settings.json。",
                         sound: "Claude 需要你時播放聲音",
                         soundCaption: "工作階段要求許可或等待你時，播放柔和的提示音。")
        case .zhHK:
            return .init(progress: "進度",
                         usage: "用量",
                         stats: "統計",
                         working: "工作中",
                         workingInFormat: "在 %@ 中工作",
                         needsPermission: "需要你的許可",
                         waitingForYou: "正在等你",
                         done: "完成",
                         doneAfterFormat: "用了 %@ 完成",
                         idle: "閒置",
                         reading: "正在讀取…",
                         editing: "正在編輯…",
                         saving: "正在儲存…",
                         runningStep: "正在執行…",
                         workingStep: "工作中…",
                         saved: "已儲存",
                         finished: "已完成",
                         failed: "失敗",
                         noSteps: "等待第一步",
                         nothingRunning: "沒有正在工作的代理",
                         connectHint: "連接 Claude Code 即可在這裡查看每一步。",
                         connect: "連接 Claude Code",
                         noLimits: "暫無額度資料",
                         nextSession: "下一個工作階段",
                         needsYou: "需要你",
                         doneShort: "完成",
                         section: "Claude Code 即時步驟",
                         caption: "Claude Code 會透過掛鈎把每一步告訴 Zenith：AI 頁面顯示步驟和正在寫入的檔案，工作階段需要你時，收合的動態島會提示。",
                         privacy: "掛鈎只保留工具、檔案或程式的名稱和行數。提示詞、指令、檔案內容和訊息從不儲存。",
                         disconnect: "中斷連接",
                         connected: "已在 ~/.claude/settings.json 中連接",
                         outdated: "已為其他 Zenith 版本或舊掛鈎連接。再次連接即可更新。",
                         notConnected: "未連接",
                         unreadable: "~/.claude/settings.json 不是有效的 JSON。請手動修正。",
                         lastEventFormat: "最後事件：%@",
                         noEvents: "暫無事件",
                         newSessions: "新的 Claude Code 工作階段會套用此更改。",
                         confirmTitle: "要將 Claude Code 連接到 Zenith 嗎？",
                         confirmMessage: "Zenith 會將這些掛鈎合併到 ~/.claude/settings.json，並把原檔案保存為 settings.json.zenith-backup。其他設定和掛鈎保持不變。",
                         add: "連接",
                         cancel: "取消",
                         editFailed: "無法更新 ~/.claude/settings.json。",
                         sound: "Claude 需要你時播放聲音",
                         soundCaption: "工作階段要求許可或等待你時，播放柔和的提示音。")
        }
    }
}

struct ZenithHomeStrings {
    /// The island menu's item that opens the home page's edit mode.
    let customize: String
    let done: String
    let cancel: String
    /// "Remove %@" and "Add %@", %@ a widget's name.
    let removeFormat: String
    let addFormat: String
    /// A widget the row has no room for.
    let noRoom: String
    /// An empty row in edit mode.
    let emptyHint: String
    /// The weather widget before it may read the location.
    let allowLocation: String
    let openSettings: String

    func remove(_ widget: String) -> String { removeFormat.replacingOccurrences(of: "%@", with: widget) }
    func add(_ widget: String) -> String { addFormat.replacingOccurrences(of: "%@", with: widget) }
}

extension ZenithStrings {
    /// The customisable home page (ZenithHomeLayoutSupport) and its edit mode.
    static func home(_ language: AppLanguage) -> ZenithHomeStrings {
        switch language {
        case .enUS:
            return .init(customize: "Customize Home", done: "Done", cancel: "Cancel",
                         removeFormat: "Remove %@", addFormat: "Add %@",
                         noRoom: "No room for another widget", emptyHint: "Add widgets from the row below",
                         allowLocation: "Allow Location", openSettings: "Open Settings")
        case .ptBR:
            return .init(customize: "Personalizar Início", done: "OK", cancel: "Cancelar",
                         removeFormat: "Remover %@", addFormat: "Adicionar %@",
                         noRoom: "Não há espaço para outro widget", emptyHint: "Adicione widgets da fileira abaixo",
                         allowLocation: "Permitir Localização", openSettings: "Abrir Ajustes")
        case .tr:
            return .init(customize: "Ana Sayfayı Özelleştir", done: "Bitti", cancel: "Vazgeç",
                         removeFormat: "%@ öğesini kaldır", addFormat: "%@ öğesini ekle",
                         noRoom: "Başka bir widget için yer yok", emptyHint: "Aşağıdaki satırdan widget ekle",
                         allowLocation: "Konuma İzin Ver", openSettings: "Ayarları Aç")
        case .ru:
            return .init(customize: "Настроить «Главную»", done: "Готово", cancel: "Отменить",
                         removeFormat: "Удалить «%@»", addFormat: "Добавить «%@»",
                         noRoom: "Нет места для ещё одного виджета", emptyHint: "Добавьте виджеты из ряда ниже",
                         allowLocation: "Разрешить геолокацию", openSettings: "Открыть Настройки")
        case .es:
            return .init(customize: "Personalizar Inicio", done: "OK", cancel: "Cancelar",
                         removeFormat: "Quitar %@", addFormat: "Añadir %@",
                         noRoom: "No hay espacio para otro widget", emptyHint: "Añade widgets desde la fila de abajo",
                         allowLocation: "Permitir ubicación", openSettings: "Abrir Ajustes")
        case .sk:
            return .init(customize: "Prispôsobiť Domov", done: "Hotovo", cancel: "Zrušiť",
                         removeFormat: "Odstrániť %@", addFormat: "Pridať %@",
                         noRoom: "Na ďalší widget nie je miesto", emptyHint: "Pridajte widgety z riadka nižšie",
                         allowLocation: "Povoliť polohu", openSettings: "Otvoriť nastavenia")
        case .de:
            return .init(customize: "Home anpassen", done: "Fertig", cancel: "Abbrechen",
                         removeFormat: "%@ entfernen", addFormat: "%@ hinzufügen",
                         noRoom: "Kein Platz für ein weiteres Widget", emptyHint: "Füge Widgets aus der Reihe unten hinzu",
                         allowLocation: "Standort erlauben", openSettings: "Einstellungen öffnen")
        case .fr:
            return .init(customize: "Personnaliser l’accueil", done: "OK", cancel: "Annuler",
                         removeFormat: "Retirer %@", addFormat: "Ajouter %@",
                         noRoom: "Plus de place pour un autre widget", emptyHint: "Ajoutez des widgets depuis la rangée ci-dessous",
                         allowLocation: "Autoriser la localisation", openSettings: "Ouvrir les Réglages")
        case .it:
            return .init(customize: "Personalizza Home", done: "Fine", cancel: "Annulla",
                         removeFormat: "Rimuovi %@", addFormat: "Aggiungi %@",
                         noRoom: "Non c’è spazio per un altro widget", emptyHint: "Aggiungi widget dalla riga qui sotto",
                         allowLocation: "Consenti posizione", openSettings: "Apri Impostazioni")
        case .ja:
            return .init(customize: "ホームをカスタマイズ", done: "完了", cancel: "キャンセル",
                         removeFormat: "%@を削除", addFormat: "%@を追加",
                         noRoom: "これ以上ウィジェットを置けません", emptyHint: "下の列からウィジェットを追加",
                         allowLocation: "位置情報を許可", openSettings: "設定を開く")
        case .ko:
            return .init(customize: "홈 사용자화", done: "완료", cancel: "취소",
                         removeFormat: "%@ 제거", addFormat: "%@ 추가",
                         noRoom: "위젯을 더 둘 공간이 없습니다", emptyHint: "아래 줄에서 위젯을 추가하세요",
                         allowLocation: "위치 허용", openSettings: "설정 열기")
        case .uk:
            return .init(customize: "Налаштувати «Головну»", done: "Готово", cancel: "Скасувати",
                         removeFormat: "Вилучити «%@»", addFormat: "Додати «%@»",
                         noRoom: "Немає місця для ще одного віджета", emptyHint: "Додайте віджети з ряду нижче",
                         allowLocation: "Дозволити геолокацію", openSettings: "Відкрити Параметри")
        case .zhHans:
            return .init(customize: "自定主页", done: "完成", cancel: "取消",
                         removeFormat: "移除“%@”", addFormat: "添加“%@”",
                         noRoom: "没有空间放更多小组件", emptyHint: "从下方一行添加小组件",
                         allowLocation: "允许定位", openSettings: "打开设置")
        case .zhTW:
            return .init(customize: "自訂主頁", done: "完成", cancel: "取消",
                         removeFormat: "移除「%@」", addFormat: "加入「%@」",
                         noRoom: "沒有空間放更多小工具", emptyHint: "從下方一列加入小工具",
                         allowLocation: "允許定位", openSettings: "打開設定")
        case .zhHK:
            return .init(customize: "自訂主頁", done: "完成", cancel: "取消",
                         removeFormat: "移除「%@」", addFormat: "加入「%@」",
                         noRoom: "沒有空間放更多小工具", emptyHint: "從下方一列加入小工具",
                         allowLocation: "允許定位", openSettings: "打開設定")
        }
    }
}

/// Zenith fork: the home page's shortcut row in "Customize Home" (ZenithHomeShortcutsView).
struct ZenithHomeShortcutStrings {
    /// The edit strip's switch between what it offers.
    let widgets: String
    let shortcuts: String
    /// A shortcut the row has no room for at the island's width.
    let noRoom: String
    /// A shortcut's tooltip in edit mode.
    let dragHint: String
    /// VoiceOver's actions on a shortcut in edit mode.
    let moveLeft: String
    let moveRight: String
}

extension ZenithStrings {
    static func homeShortcuts(_ language: AppLanguage) -> ZenithHomeShortcutStrings {
        switch language {
        case .enUS:
            return .init(widgets: "Widgets", shortcuts: "Shortcuts", noRoom: "No room in the row", dragHint: "Drag to reorder",
                         moveLeft: "Move left", moveRight: "Move right")
        case .ptBR:
            return .init(widgets: "Widgets", shortcuts: "Atalhos", noRoom: "Não há espaço na fileira", dragHint: "Arraste para reordenar",
                         moveLeft: "Mover para a esquerda", moveRight: "Mover para a direita")
        case .tr:
            return .init(widgets: "Widget’lar", shortcuts: "Kısayollar", noRoom: "Satırda yer yok", dragHint: "Sıralamak için sürükle",
                         moveLeft: "Sola taşı", moveRight: "Sağa taşı")
        case .ru:
            return .init(widgets: "Виджеты", shortcuts: "Быстрые действия", noRoom: "В ряду нет места", dragHint: "Перетащите, чтобы изменить порядок",
                         moveLeft: "Переместить влево", moveRight: "Переместить вправо")
        case .es:
            return .init(widgets: "Widgets", shortcuts: "Atajos", noRoom: "No hay espacio en la fila", dragHint: "Arrastra para reordenar",
                         moveLeft: "Mover a la izquierda", moveRight: "Mover a la derecha")
        case .sk:
            return .init(widgets: "Widgety", shortcuts: "Skratky", noRoom: "V riadku nie je miesto", dragHint: "Potiahnutím zmeníte poradie",
                         moveLeft: "Posunúť doľava", moveRight: "Posunúť doprava")
        case .de:
            return .init(widgets: "Widgets", shortcuts: "Kurzbefehle", noRoom: "Kein Platz in der Reihe", dragHint: "Zum Umordnen ziehen",
                         moveLeft: "Nach links bewegen", moveRight: "Nach rechts bewegen")
        case .fr:
            return .init(widgets: "Widgets", shortcuts: "Raccourcis", noRoom: "Plus de place dans la rangée", dragHint: "Faites glisser pour réorganiser",
                         moveLeft: "Déplacer vers la gauche", moveRight: "Déplacer vers la droite")
        case .it:
            return .init(widgets: "Widget", shortcuts: "Scorciatoie", noRoom: "Non c’è spazio nella riga", dragHint: "Trascina per riordinare",
                         moveLeft: "Sposta a sinistra", moveRight: "Sposta a destra")
        case .ja:
            return .init(widgets: "ウィジェット", shortcuts: "ショートカット", noRoom: "この列に空きがありません", dragHint: "ドラッグして並べ替え",
                         moveLeft: "左へ移動", moveRight: "右へ移動")
        case .ko:
            return .init(widgets: "위젯", shortcuts: "단축키", noRoom: "줄에 공간이 없습니다", dragHint: "드래그하여 순서 변경",
                         moveLeft: "왼쪽으로 이동", moveRight: "오른쪽으로 이동")
        case .uk:
            return .init(widgets: "Віджети", shortcuts: "Скорочення", noRoom: "У ряду немає місця", dragHint: "Перетягніть, щоб змінити порядок",
                         moveLeft: "Перемістити ліворуч", moveRight: "Перемістити праворуч")
        case .zhHans:
            return .init(widgets: "小组件", shortcuts: "快捷操作", noRoom: "这一行没有空间了", dragHint: "拖移以重新排序",
                         moveLeft: "左移", moveRight: "右移")
        case .zhTW:
            return .init(widgets: "小工具", shortcuts: "快捷操作", noRoom: "這一列沒有空間了", dragHint: "拖移以重新排序",
                         moveLeft: "左移", moveRight: "右移")
        case .zhHK:
            return .init(widgets: "小工具", shortcuts: "快捷操作", noRoom: "這一列沒有空間了", dragHint: "拖移以重新排序",
                         moveLeft: "左移", moveRight: "右移")
        }
    }
}

// MARK: - Tab bar

/// Zenith fork: the Tab bar card in Settings → Dynamic Island → Layout
/// (ZenithTabBarSettings), which chooses what the open island's pill holds.
struct ZenithTabBarStrings {
    let section: String
    let show: String
    let showHint: String
    /// Above the list of sections.
    let tabs: String
    /// `%d` is the most tabs the pill pins.
    let limitFormat: String
    /// Every pin taken: the remaining switches are off limits.
    let full: String
    /// The gallery's fixed row at the end of the list.
    let alwaysLast: String
    let currentPage: String
    let currentPageHint: String
    let badges: String
    let badgesHint: String
    /// A pinned row's buttons and VoiceOver actions.
    let moveUp: String
    let moveDown: String
    /// VoiceOver's name for the pill drawn at the top of the card.
    let preview: String

    func limit(_ count: Int) -> String { String(format: limitFormat, count) }
}

extension ZenithStrings {
    static func tabBar(_ language: AppLanguage) -> ZenithTabBarStrings {
        switch language {
        case .enUS:
            return .init(section: "Tab bar", show: "Show the tab bar",
                         showHint: "The pill under the open island. Turned off, the island’s top row shows the button for every section again.",
                         tabs: "Tabs", limitFormat: "Up to %d tabs. The last one always opens every section.",
                         full: "The tab bar is full. Turn a tab off to pin another.", alwaysLast: "Always last",
                         currentPage: "Show the current page", currentPageHint: "Adds a tab for the open page while it isn’t pinned.",
                         badges: "Badges", badgesHint: "How many files are held and how many notifications are waiting.",
                         moveUp: "Move up", moveDown: "Move down", preview: "Tab bar preview")
        case .ptBR:
            return .init(section: "Barra de abas", show: "Mostrar a barra de abas",
                         showHint: "A pílula sob a ilha aberta. Desativada, a fileira de cima da ilha volta a mostrar o botão de todas as seções.",
                         tabs: "Abas", limitFormat: "Até %d abas. A última sempre abre todas as seções.",
                         full: "A barra de abas está cheia. Desative uma aba para fixar outra.", alwaysLast: "Sempre por último",
                         currentPage: "Mostrar a página atual",
                         currentPageHint: "Adiciona uma aba para a página aberta enquanto ela não estiver fixada.",
                         badges: "Contadores", badgesHint: "Quantos arquivos estão guardados e quantas notificações esperam.",
                         moveUp: "Mover para cima", moveDown: "Mover para baixo", preview: "Prévia da barra de abas")
        case .tr:
            return .init(section: "Sekme çubuğu", show: "Sekme çubuğunu göster",
                         showHint: "Açık adanın altındaki hap. Kapalıyken adanın üst satırı tüm bölümlerin düğmesini yeniden gösterir.",
                         tabs: "Sekmeler", limitFormat: "En fazla %d sekme. Sonuncusu her zaman tüm bölümleri açar.",
                         full: "Sekme çubuğu dolu. Başka birini sabitlemek için bir sekmeyi kapatın.", alwaysLast: "Her zaman sonda",
                         currentPage: "Geçerli sayfayı göster", currentPageHint: "Açık sayfa sabitlenmemişken onun için bir sekme ekler.",
                         badges: "Rozetler", badgesHint: "Kaç dosyanın tutulduğunu ve kaç bildirimin beklediğini gösterir.",
                         moveUp: "Yukarı taşı", moveDown: "Aşağı taşı", preview: "Sekme çubuğu önizlemesi")
        case .ru:
            return .init(section: "Панель вкладок", show: "Показывать панель вкладок",
                         showHint: "Капсула под открытым островом. Если выключено, в верхнем ряду острова снова появляется кнопка всех разделов.",
                         tabs: "Вкладки", limitFormat: "До %d вкладок. Последняя всегда открывает все разделы.",
                         full: "Панель вкладок заполнена. Выключите вкладку, чтобы закрепить другую.", alwaysLast: "Всегда последняя",
                         currentPage: "Показывать текущую страницу",
                         currentPageHint: "Добавляет вкладку для открытой страницы, пока она не закреплена.",
                         badges: "Счётчики", badgesHint: "Сколько файлов отложено и сколько уведомлений ждёт.",
                         moveUp: "Переместить вверх", moveDown: "Переместить вниз", preview: "Предпросмотр панели вкладок")
        case .es:
            return .init(section: "Barra de pestañas", show: "Mostrar la barra de pestañas",
                         showHint: "La píldora bajo la isla abierta. Si está desactivada, la fila superior de la isla vuelve a mostrar el botón de todas las secciones.",
                         tabs: "Pestañas", limitFormat: "Hasta %d pestañas. La última siempre abre todas las secciones.",
                         full: "La barra de pestañas está llena. Desactiva una pestaña para fijar otra.", alwaysLast: "Siempre al final",
                         currentPage: "Mostrar la página actual",
                         currentPageHint: "Añade una pestaña para la página abierta mientras no esté fijada.",
                         badges: "Contadores", badgesHint: "Cuántos archivos se guardan y cuántas notificaciones esperan.",
                         moveUp: "Subir", moveDown: "Bajar", preview: "Vista previa de la barra de pestañas")
        case .sk:
            return .init(section: "Panel kariet", show: "Zobraziť panel kariet",
                         showHint: "Kapsula pod otvoreným ostrovom. Keď je vypnutá, horný riadok ostrova znova ukáže tlačidlo všetkých sekcií.",
                         tabs: "Karty", limitFormat: "Najviac %d kariet. Posledná vždy otvorí všetky sekcie.",
                         full: "Panel kariet je plný. Vypnite kartu, aby ste pripli inú.", alwaysLast: "Vždy posledná",
                         currentPage: "Zobraziť aktuálnu stránku", currentPageHint: "Pridá kartu pre otvorenú stránku, kým nie je pripnutá.",
                         badges: "Odznaky", badgesHint: "Koľko súborov je odložených a koľko upozornení čaká.",
                         moveUp: "Posunúť nahor", moveDown: "Posunúť nadol", preview: "Náhľad panela kariet")
        case .de:
            return .init(section: "Tableiste", show: "Tableiste zeigen",
                         showHint: "Die Pille unter der geöffneten Insel. Ausgeschaltet zeigt die obere Reihe der Insel wieder die Taste für alle Bereiche.",
                         tabs: "Tabs", limitFormat: "Bis zu %d Tabs. Der letzte öffnet immer alle Bereiche.",
                         full: "Die Tableiste ist voll. Schalte einen Tab aus, um einen anderen anzuheften.", alwaysLast: "Immer zuletzt",
                         currentPage: "Aktuelle Seite zeigen",
                         currentPageHint: "Fügt einen Tab für die geöffnete Seite hinzu, solange sie nicht angeheftet ist.",
                         badges: "Zähler", badgesHint: "Wie viele Dateien abgelegt sind und wie viele Mitteilungen warten.",
                         moveUp: "Nach oben", moveDown: "Nach unten", preview: "Vorschau der Tableiste")
        case .fr:
            return .init(section: "Barre d’onglets", show: "Afficher la barre d’onglets",
                         showHint: "La pilule sous l’île ouverte. Désactivée, la rangée du haut de l’île affiche de nouveau le bouton de toutes les sections.",
                         tabs: "Onglets", limitFormat: "Jusqu’à %d onglets. Le dernier ouvre toujours toutes les sections.",
                         full: "La barre d’onglets est pleine. Désactivez un onglet pour en épingler un autre.", alwaysLast: "Toujours en dernier",
                         currentPage: "Afficher la page actuelle",
                         currentPageHint: "Ajoute un onglet pour la page ouverte tant qu’elle n’est pas épinglée.",
                         badges: "Pastilles", badgesHint: "Combien de fichiers sont gardés et combien de notifications attendent.",
                         moveUp: "Monter", moveDown: "Descendre", preview: "Aperçu de la barre d’onglets")
        case .it:
            return .init(section: "Barra delle schede", show: "Mostra la barra delle schede",
                         showHint: "La pillola sotto l’isola aperta. Disattivata, la riga in alto dell’isola mostra di nuovo il pulsante di tutte le sezioni.",
                         tabs: "Schede", limitFormat: "Fino a %d schede. L’ultima apre sempre tutte le sezioni.",
                         full: "La barra delle schede è piena. Disattiva una scheda per fissarne un’altra.", alwaysLast: "Sempre per ultima",
                         currentPage: "Mostra la pagina attuale", currentPageHint: "Aggiunge una scheda per la pagina aperta finché non è fissata.",
                         badges: "Contatori", badgesHint: "Quanti file sono conservati e quante notifiche aspettano.",
                         moveUp: "Sposta su", moveDown: "Sposta giù", preview: "Anteprima della barra delle schede")
        case .ja:
            return .init(section: "タブバー", show: "タブバーを表示",
                         showHint: "開いたアイランドの下にあるピル。オフにすると、アイランドの上段にすべてのセクションのボタンが戻ります。",
                         tabs: "タブ", limitFormat: "タブは%d個まで。最後のタブはいつでもすべてのセクションを開きます。",
                         full: "タブバーがいっぱいです。別のタブを固定するには、どれかをオフにしてください。", alwaysLast: "常に最後",
                         currentPage: "現在のページを表示", currentPageHint: "開いているページが固定されていないあいだ、そのタブを追加します。",
                         badges: "バッジ", badgesHint: "保管中のファイル数と、待っている通知の数。",
                         moveUp: "上へ移動", moveDown: "下へ移動", preview: "タブバーのプレビュー")
        case .ko:
            return .init(section: "탭 막대", show: "탭 막대 표시",
                         showHint: "열린 아일랜드 아래의 알약 모양 막대입니다. 끄면 아일랜드 윗줄에 모든 섹션 버튼이 다시 나타납니다.",
                         tabs: "탭", limitFormat: "탭은 최대 %d개입니다. 마지막 탭은 항상 모든 섹션을 엽니다.",
                         full: "탭 막대가 가득 찼습니다. 다른 탭을 고정하려면 탭 하나를 끄세요.", alwaysLast: "항상 마지막",
                         currentPage: "현재 페이지 표시", currentPageHint: "열린 페이지가 고정되지 않은 동안 그 페이지의 탭을 추가합니다.",
                         badges: "배지", badgesHint: "보관 중인 파일 수와 기다리는 알림 수입니다.",
                         moveUp: "위로 이동", moveDown: "아래로 이동", preview: "탭 막대 미리 보기")
        case .uk:
            return .init(section: "Панель вкладок", show: "Показувати панель вкладок",
                         showHint: "Капсула під відкритим островом. Якщо вимкнено, у верхньому ряду острова знову з’являється кнопка всіх розділів.",
                         tabs: "Вкладки", limitFormat: "До %d вкладок. Остання завжди відкриває всі розділи.",
                         full: "Панель вкладок заповнена. Вимкніть вкладку, щоб закріпити іншу.", alwaysLast: "Завжди остання",
                         currentPage: "Показувати поточну сторінку",
                         currentPageHint: "Додає вкладку для відкритої сторінки, поки її не закріплено.",
                         badges: "Лічильники", badgesHint: "Скільки файлів відкладено і скільки сповіщень чекає.",
                         moveUp: "Перемістити вгору", moveDown: "Перемістити вниз", preview: "Попередній перегляд панелі вкладок")
        case .zhHans:
            return .init(section: "标签栏", show: "显示标签栏",
                         showHint: "打开的灵动岛下方的胶囊。关闭后，灵动岛顶行会重新显示所有分区的按钮。",
                         tabs: "标签", limitFormat: "最多 %d 个标签。最后一个始终打开所有分区。",
                         full: "标签栏已满。关闭一个标签才能固定另一个。", alwaysLast: "始终在最后",
                         currentPage: "显示当前页面", currentPageHint: "打开的页面未固定时，为它添加一个标签。",
                         badges: "标记", badgesHint: "暂存的文件数和等待中的通知数。",
                         moveUp: "上移", moveDown: "下移", preview: "标签栏预览")
        case .zhTW:
            return .init(section: "標籤列", show: "顯示標籤列",
                         showHint: "打開的動態島下方的膠囊。關閉後，動態島頂列會重新顯示所有區塊的按鈕。",
                         tabs: "標籤", limitFormat: "最多 %d 個標籤。最後一個一律打開所有區塊。",
                         full: "標籤列已滿。關閉一個標籤才能固定另一個。", alwaysLast: "一律在最後",
                         currentPage: "顯示目前頁面", currentPageHint: "打開的頁面未固定時，為它加入一個標籤。",
                         badges: "標記", badgesHint: "暫存的檔案數與等待中的通知數。",
                         moveUp: "上移", moveDown: "下移", preview: "標籤列預覽")
        case .zhHK:
            return .init(section: "標籤列", show: "顯示標籤列",
                         showHint: "打開的動態島下方的膠囊。關閉後，動態島頂行會重新顯示所有區塊的按鈕。",
                         tabs: "標籤", limitFormat: "最多 %d 個標籤。最後一個總是打開所有區塊。",
                         full: "標籤列已滿。關閉一個標籤才可固定另一個。", alwaysLast: "總是在最後",
                         currentPage: "顯示目前頁面", currentPageHint: "打開的頁面未固定時，為它加入一個標籤。",
                         badges: "標記", badgesHint: "暫存的檔案數和等待中的通知數。",
                         moveUp: "上移", moveDown: "下移", preview: "標籤列預覽")
        }
    }
}

// MARK: - Card import

/// Zenith fork: importing camera cards (CardImportService), in the island and in Settings.
struct ZenithCardImportStrings {
    /// The page, its module and its live activity.
    let title: String
    /// What the section does, in Settings.
    let summary: String
    /// The notice's first words.
    let sdCard: String
    /// One, few and many: `%@` is the grouped count.
    let photos: [String]
    /// One, few and many: `%@` is the grouped count.
    let videos: [String]
    let importAction: String
    /// `%@` is a count.
    let newFiles: String
    /// `%@` is a count.
    let alreadyImported: String
    let nothingNew: String
    let noMedia: String
    let scanning: String
    let empty: String
    let destination: String
    let eventPlaceholder: String
    let separateRaw: String
    let videoFolder: String
    let skipImported: String
    let rename: String
    let renameOriginal: String
    let renameDate: String
    let ejectWhenDone: String
    let importing: String
    /// `%@` is files or a time, as in “812 left”.
    let left: String
    let stop: String
    /// `%@` is the count and size, as in “1,248 · 52 GB”.
    let imported: String
    /// `%@` is a count.
    let skippedBefore: String
    let reveal: String
    let eject: String
    let ejected: String
    let ejectFailed: String
    let done: String
    let retry: String
    let cardRemoved: String
    let cardRemovedDetail: String
    let diskFull: String
    /// `%@` is a size.
    let diskFullDetail: String
    let failed: String
    /// `%@` is a file name.
    let failedDetail: String
    let detect: String
    let detectCaption: String
    let folder: String
    let choose: String
    let reset: String
    let defaults: String
    let renameCaption: String
    let skipCaption: String
    let eventCaption: String
}

extension ZenithStrings {
    static func cardImport(_ language: AppLanguage) -> ZenithCardImportStrings {
        switch language {
        case .enUS:
            return .init(title: "Card Import",
                         summary: "Imports photos and videos from camera cards into dated event folders.",
                         sdCard: "SD card",
                         photos: ["%@ photo", "%@ photos", "%@ photos"],
                         videos: ["%@ video", "%@ videos", "%@ videos"],
                         importAction: "Import",
                         newFiles: "%@ new",
                         alreadyImported: "%@ imported before",
                         nothingNew: "Everything on this card was imported before.",
                         noMedia: "No photos or videos on this card.",
                         scanning: "Reading the card…",
                         empty: "Insert a camera card to import its photos and videos.",
                         destination: "Destination",
                         eventPlaceholder: "Event name",
                         separateRaw: "RAW and JPG folders",
                         videoFolder: "Video folder",
                         skipImported: "Skip imported",
                         rename: "Names",
                         renameOriginal: "Original",
                         renameDate: "Date and time",
                         ejectWhenDone: "Eject when done",
                         importing: "Importing",
                         left: "%@ left",
                         stop: "Stop",
                         imported: "Imported %@",
                         skippedBefore: "%@ skipped, imported before",
                         reveal: "Reveal in Finder",
                         eject: "Eject",
                         ejected: "Ejected",
                         ejectFailed: "Couldn’t eject the card. A file on it may be open.",
                         done: "Done",
                         retry: "Retry",
                         cardRemoved: "Card removed",
                         cardRemovedDetail: "Insert it again and retry. Files already copied stay.",
                         diskFull: "Destination disk is full",
                         diskFullDetail: "Free up %@ and retry.",
                         failed: "Import stopped",
                         failedDetail: "Couldn’t copy %@.",
                         detect: "Detect camera cards",
                         detectCaption: "When a card with a DCIM folder or a camera’s video folders mounts, a notice offers to import it. Nothing on the card is ever changed or deleted.",
                         folder: "Import to",
                         choose: "Choose…",
                         reset: "Reset",
                         defaults: "Defaults",
                         renameCaption: "Date and time names files like 20261120-101502-0001.ARW, numbered in the order they were shot.",
                         skipCaption: "Leaves out files whose name, size and capture time match what came off this card before.",
                         eventCaption: "Each import goes into a folder named for the day the newest photo was taken. You can rename it before importing.")
        case .ptBR:
            return .init(title: "Importar cartão",
                         summary: "Importa fotos e vídeos de cartões de câmera para pastas de evento com data.",
                         sdCard: "Cartão SD",
                         photos: ["%@ foto", "%@ fotos", "%@ fotos"],
                         videos: ["%@ vídeo", "%@ vídeos", "%@ vídeos"],
                         importAction: "Importar",
                         newFiles: "%@ novos",
                         alreadyImported: "%@ já importados",
                         nothingNew: "Tudo neste cartão já foi importado.",
                         noMedia: "Nenhuma foto ou vídeo neste cartão.",
                         scanning: "Lendo o cartão…",
                         empty: "Insira um cartão de câmera para importar as fotos e os vídeos.",
                         destination: "Destino",
                         eventPlaceholder: "Nome do evento",
                         separateRaw: "Pastas RAW e JPG",
                         videoFolder: "Pasta Video",
                         skipImported: "Pular importados",
                         rename: "Nomes",
                         renameOriginal: "Original",
                         renameDate: "Data e hora",
                         ejectWhenDone: "Ejetar ao terminar",
                         importing: "Importando",
                         left: "faltam %@",
                         stop: "Parar",
                         imported: "Importados %@",
                         skippedBefore: "%@ ignorados, já importados",
                         reveal: "Mostrar no Finder",
                         eject: "Ejetar",
                         ejected: "Ejetado",
                         ejectFailed: "Não foi possível ejetar o cartão. Algum arquivo nele pode estar aberto.",
                         done: "OK",
                         retry: "Tentar de novo",
                         cardRemoved: "Cartão removido",
                         cardRemovedDetail: "Insira-o de novo e tente outra vez. Os arquivos já copiados ficam.",
                         diskFull: "O disco de destino está cheio",
                         diskFullDetail: "Libere %@ e tente de novo.",
                         failed: "Importação interrompida",
                         failedDetail: "Não foi possível copiar %@.",
                         detect: "Detectar cartões de câmera",
                         detectCaption: "Quando um cartão com pasta DCIM ou pastas de vídeo de câmera é montado, um aviso oferece a importação. Nada no cartão é alterado ou apagado.",
                         folder: "Importar para",
                         choose: "Escolher…",
                         reset: "Redefinir",
                         defaults: "Padrões",
                         renameCaption: "Data e hora nomeia os arquivos como 20261120-101502-0001.ARW, numerados na ordem em que foram feitos.",
                         skipCaption: "Deixa de fora arquivos cujo nome, tamanho e hora da captura batem com o que já saiu deste cartão.",
                         eventCaption: "Cada importação vai para uma pasta com a data da foto mais recente. Dá para renomeá-la antes de importar.")
        case .tr:
            return .init(title: "Kart aktarma",
                         summary: "Kamera kartlarındaki fotoğraf ve videoları tarihli etkinlik klasörlerine aktarır.",
                         sdCard: "SD kart",
                         photos: ["%@ fotoğraf", "%@ fotoğraf", "%@ fotoğraf"],
                         videos: ["%@ video", "%@ video", "%@ video"],
                         importAction: "Aktar",
                         newFiles: "%@ yeni",
                         alreadyImported: "%@ önceden aktarıldı",
                         nothingNew: "Bu karttaki her şey daha önce aktarıldı.",
                         noMedia: "Bu kartta fotoğraf veya video yok.",
                         scanning: "Kart okunuyor…",
                         empty: "Fotoğraf ve videolarını aktarmak için bir kamera kartı takın.",
                         destination: "Hedef",
                         eventPlaceholder: "Etkinlik adı",
                         separateRaw: "RAW ve JPG klasörleri",
                         videoFolder: "Video klasörü",
                         skipImported: "Aktarılanları atla",
                         rename: "Adlar",
                         renameOriginal: "Orijinal",
                         renameDate: "Tarih ve saat",
                         ejectWhenDone: "Bitince çıkar",
                         importing: "Aktarılıyor",
                         left: "%@ kaldı",
                         stop: "Durdur",
                         imported: "Aktarıldı: %@",
                         skippedBefore: "%@ atlandı, önceden aktarılmış",
                         reveal: "Finder’da göster",
                         eject: "Çıkar",
                         ejected: "Çıkarıldı",
                         ejectFailed: "Kart çıkarılamadı. Üzerindeki bir dosya açık olabilir.",
                         done: "Tamam",
                         retry: "Yeniden dene",
                         cardRemoved: "Kart çıkarıldı",
                         cardRemovedDetail: "Yeniden takıp tekrar deneyin. Kopyalanan dosyalar yerinde kalır.",
                         diskFull: "Hedef disk dolu",
                         diskFullDetail: "%@ yer açıp yeniden deneyin.",
                         failed: "Aktarma durdu",
                         failedDetail: "%@ kopyalanamadı.",
                         detect: "Kamera kartlarını algıla",
                         detectCaption: "DCIM klasörü ya da kamera video klasörleri olan bir kart takıldığında bir bildirim aktarmayı önerir. Karttaki hiçbir şey değiştirilmez veya silinmez.",
                         folder: "Aktarma yeri",
                         choose: "Seç…",
                         reset: "Sıfırla",
                         defaults: "Varsayılanlar",
                         renameCaption: "Tarih ve saat, dosyaları çekim sırasına göre numaralayarak 20261120-101502-0001.ARW gibi adlandırır.",
                         skipCaption: "Adı, boyutu ve çekim zamanı bu karttan daha önce gelenle eşleşen dosyaları atlar.",
                         eventCaption: "Her aktarma, en yeni fotoğrafın çekildiği günün adını taşıyan bir klasöre gider. Aktarmadan önce adını değiştirebilirsiniz.")
        case .ru:
            return .init(title: "Импорт с карты",
                         summary: "Импортирует фото и видео с карт камеры в папки событий с датой.",
                         sdCard: "SD-карта",
                         photos: ["%@ фото", "%@ фото", "%@ фото"],
                         videos: ["%@ видео", "%@ видео", "%@ видео"],
                         importAction: "Импорт",
                         newFiles: "новых: %@",
                         alreadyImported: "импортировано ранее: %@",
                         nothingNew: "Всё с этой карты уже импортировано.",
                         noMedia: "На этой карте нет фото и видео.",
                         scanning: "Чтение карты…",
                         empty: "Вставьте карту камеры, чтобы импортировать фото и видео.",
                         destination: "Куда",
                         eventPlaceholder: "Название события",
                         separateRaw: "Папки RAW и JPG",
                         videoFolder: "Папка Video",
                         skipImported: "Пропускать импортированные",
                         rename: "Имена",
                         renameOriginal: "Исходные",
                         renameDate: "Дата и время",
                         ejectWhenDone: "Извлечь по завершении",
                         importing: "Импорт",
                         left: "осталось %@",
                         stop: "Стоп",
                         imported: "Импортировано %@",
                         skippedBefore: "пропущено %@, импортированы ранее",
                         reveal: "Показать в Finder",
                         eject: "Извлечь",
                         ejected: "Извлечена",
                         ejectFailed: "Не удалось извлечь карту. Возможно, на ней открыт файл.",
                         done: "Готово",
                         retry: "Повторить",
                         cardRemoved: "Карта извлечена",
                         cardRemovedDetail: "Вставьте её снова и повторите. Скопированные файлы сохранятся.",
                         diskFull: "Диск назначения заполнен",
                         diskFullDetail: "Освободите %@ и повторите.",
                         failed: "Импорт остановлен",
                         failedDetail: "Не удалось скопировать %@.",
                         detect: "Распознавать карты камеры",
                         detectCaption: "Когда подключается карта с папкой DCIM или папками видео камеры, уведомление предлагает импорт. На карте ничего не меняется и не удаляется.",
                         folder: "Импорт в",
                         choose: "Выбрать…",
                         reset: "Сбросить",
                         defaults: "По умолчанию",
                         renameCaption: "Дата и время называет файлы как 20261120-101502-0001.ARW, нумеруя их в порядке съёмки.",
                         skipCaption: "Пропускает файлы, у которых имя, размер и время съёмки совпадают с уже импортированными с этой карты.",
                         eventCaption: "Каждый импорт попадает в папку с датой самого нового снимка. Её можно переименовать до импорта.")
        case .es:
            return .init(title: "Importar tarjeta",
                         summary: "Importa fotos y vídeos de tarjetas de cámara a carpetas de evento con fecha.",
                         sdCard: "Tarjeta SD",
                         photos: ["%@ foto", "%@ fotos", "%@ fotos"],
                         videos: ["%@ vídeo", "%@ vídeos", "%@ vídeos"],
                         importAction: "Importar",
                         newFiles: "%@ nuevos",
                         alreadyImported: "%@ ya importados",
                         nothingNew: "Todo lo de esta tarjeta ya se importó.",
                         noMedia: "No hay fotos ni vídeos en esta tarjeta.",
                         scanning: "Leyendo la tarjeta…",
                         empty: "Inserta una tarjeta de cámara para importar sus fotos y vídeos.",
                         destination: "Destino",
                         eventPlaceholder: "Nombre del evento",
                         separateRaw: "Carpetas RAW y JPG",
                         videoFolder: "Carpeta Video",
                         skipImported: "Omitir importados",
                         rename: "Nombres",
                         renameOriginal: "Original",
                         renameDate: "Fecha y hora",
                         ejectWhenDone: "Expulsar al terminar",
                         importing: "Importando",
                         left: "quedan %@",
                         stop: "Detener",
                         imported: "Importados %@",
                         skippedBefore: "%@ omitidos, ya importados",
                         reveal: "Mostrar en Finder",
                         eject: "Expulsar",
                         ejected: "Expulsada",
                         ejectFailed: "No se pudo expulsar la tarjeta. Puede que un archivo esté abierto.",
                         done: "Listo",
                         retry: "Reintentar",
                         cardRemoved: "Tarjeta extraída",
                         cardRemovedDetail: "Vuelve a insertarla y reintenta. Los archivos ya copiados se quedan.",
                         diskFull: "El disco de destino está lleno",
                         diskFullDetail: "Libera %@ y reintenta.",
                         failed: "Importación detenida",
                         failedDetail: "No se pudo copiar %@.",
                         detect: "Detectar tarjetas de cámara",
                         detectCaption: "Al montar una tarjeta con carpeta DCIM o carpetas de vídeo de cámara, un aviso ofrece importarla. Nada de la tarjeta se cambia ni se borra.",
                         folder: "Importar en",
                         choose: "Elegir…",
                         reset: "Restablecer",
                         defaults: "Valores predeterminados",
                         renameCaption: "Fecha y hora nombra los archivos como 20261120-101502-0001.ARW, numerados en el orden en que se tomaron.",
                         skipCaption: "Omite los archivos cuyo nombre, tamaño y hora de captura coinciden con lo ya importado de esta tarjeta.",
                         eventCaption: "Cada importación va a una carpeta con la fecha de la foto más reciente. Puedes renombrarla antes de importar.")
        case .sk:
            return .init(title: "Import z karty",
                         summary: "Importuje fotky a videá z kariet fotoaparátu do priečinkov udalostí s dátumom.",
                         sdCard: "SD karta",
                         photos: ["%@ fotka", "%@ fotky", "%@ fotiek"],
                         videos: ["%@ video", "%@ videá", "%@ videí"],
                         importAction: "Importovať",
                         newFiles: "nové: %@",
                         alreadyImported: "už importované: %@",
                         nothingNew: "Všetko z tejto karty už bolo importované.",
                         noMedia: "Na tejto karte nie sú fotky ani videá.",
                         scanning: "Čítam kartu…",
                         empty: "Vložte kartu z fotoaparátu a importujte jej fotky a videá.",
                         destination: "Cieľ",
                         eventPlaceholder: "Názov udalosti",
                         separateRaw: "Priečinky RAW a JPG",
                         videoFolder: "Priečinok Video",
                         skipImported: "Preskočiť importované",
                         rename: "Názvy",
                         renameOriginal: "Pôvodné",
                         renameDate: "Dátum a čas",
                         ejectWhenDone: "Po dokončení vysunúť",
                         importing: "Importuje sa",
                         left: "zostáva %@",
                         stop: "Zastaviť",
                         imported: "Importované %@",
                         skippedBefore: "preskočené: %@, už importované",
                         reveal: "Zobraziť vo Finderi",
                         eject: "Vysunúť",
                         ejected: "Vysunutá",
                         ejectFailed: "Kartu sa nepodarilo vysunúť. Možno je na nej otvorený súbor.",
                         done: "Hotovo",
                         retry: "Skúsiť znova",
                         cardRemoved: "Karta bola vybraná",
                         cardRemovedDetail: "Vložte ju znova a skúste to znova. Skopírované súbory zostanú.",
                         diskFull: "Cieľový disk je plný",
                         diskFullDetail: "Uvoľnite %@ a skúste to znova.",
                         failed: "Import sa zastavil",
                         failedDetail: "Súbor %@ sa nepodarilo skopírovať.",
                         detect: "Rozpoznávať karty fotoaparátu",
                         detectCaption: "Keď sa pripojí karta s priečinkom DCIM alebo priečinkami videa z fotoaparátu, oznámenie ponúkne import. Na karte sa nič nemení ani nemaže.",
                         folder: "Importovať do",
                         choose: "Vybrať…",
                         reset: "Obnoviť",
                         defaults: "Predvolené",
                         renameCaption: "Dátum a čas pomenuje súbory ako 20261120-101502-0001.ARW a očísluje ich v poradí snímania.",
                         skipCaption: "Vynechá súbory, ktorých názov, veľkosť a čas snímania sa zhodujú s tým, čo už z tejto karty prišlo.",
                         eventCaption: "Každý import ide do priečinka s dátumom najnovšej fotky. Pred importom ho môžete premenovať.")
        case .de:
            return .init(title: "Kartenimport",
                         summary: "Importiert Fotos und Videos von Kamerakarten in datierte Event-Ordner.",
                         sdCard: "SD-Karte",
                         photos: ["%@ Foto", "%@ Fotos", "%@ Fotos"],
                         videos: ["%@ Video", "%@ Videos", "%@ Videos"],
                         importAction: "Importieren",
                         newFiles: "%@ neu",
                         alreadyImported: "%@ bereits importiert",
                         nothingNew: "Alles auf dieser Karte wurde bereits importiert.",
                         noMedia: "Keine Fotos oder Videos auf dieser Karte.",
                         scanning: "Karte wird gelesen…",
                         empty: "Stecke eine Kamerakarte ein, um ihre Fotos und Videos zu importieren.",
                         destination: "Ziel",
                         eventPlaceholder: "Name des Events",
                         separateRaw: "RAW- und JPG-Ordner",
                         videoFolder: "Video-Ordner",
                         skipImported: "Importierte überspringen",
                         rename: "Namen",
                         renameOriginal: "Original",
                         renameDate: "Datum und Uhrzeit",
                         ejectWhenDone: "Danach auswerfen",
                         importing: "Import läuft",
                         left: "noch %@",
                         stop: "Stoppen",
                         imported: "Importiert: %@",
                         skippedBefore: "%@ übersprungen, bereits importiert",
                         reveal: "Im Finder zeigen",
                         eject: "Auswerfen",
                         ejected: "Ausgeworfen",
                         ejectFailed: "Die Karte konnte nicht ausgeworfen werden. Vielleicht ist eine Datei darauf geöffnet.",
                         done: "Fertig",
                         retry: "Erneut versuchen",
                         cardRemoved: "Karte entfernt",
                         cardRemovedDetail: "Stecke sie wieder ein und versuche es erneut. Bereits kopierte Dateien bleiben.",
                         diskFull: "Zielvolume ist voll",
                         diskFullDetail: "Gib %@ frei und versuche es erneut.",
                         failed: "Import gestoppt",
                         failedDetail: "%@ konnte nicht kopiert werden.",
                         detect: "Kamerakarten erkennen",
                         detectCaption: "Wird eine Karte mit DCIM-Ordner oder Video-Ordnern einer Kamera aktiviert, bietet ein Hinweis den Import an. Auf der Karte wird nie etwas geändert oder gelöscht.",
                         folder: "Importieren nach",
                         choose: "Auswählen…",
                         reset: "Zurücksetzen",
                         defaults: "Standards",
                         renameCaption: "Datum und Uhrzeit benennt Dateien wie 20261120-101502-0001.ARW, nummeriert in Aufnahmereihenfolge.",
                         skipCaption: "Lässt Dateien aus, deren Name, Größe und Aufnahmezeit mit bereits von dieser Karte Importiertem übereinstimmen.",
                         eventCaption: "Jeder Import landet in einem Ordner mit dem Datum des neuesten Fotos. Du kannst ihn vor dem Import umbenennen.")
        case .fr:
            return .init(title: "Import de carte",
                         summary: "Importe les photos et vidéos des cartes d’appareil photo dans des dossiers d’événement datés.",
                         sdCard: "Carte SD",
                         photos: ["%@ photo", "%@ photos", "%@ photos"],
                         videos: ["%@ vidéo", "%@ vidéos", "%@ vidéos"],
                         importAction: "Importer",
                         newFiles: "%@ nouveaux",
                         alreadyImported: "%@ déjà importés",
                         nothingNew: "Tout le contenu de cette carte a déjà été importé.",
                         noMedia: "Aucune photo ni vidéo sur cette carte.",
                         scanning: "Lecture de la carte…",
                         empty: "Insérez une carte d’appareil photo pour importer ses photos et vidéos.",
                         destination: "Destination",
                         eventPlaceholder: "Nom de l’événement",
                         separateRaw: "Dossiers RAW et JPG",
                         videoFolder: "Dossier Video",
                         skipImported: "Ignorer les importés",
                         rename: "Noms",
                         renameOriginal: "D’origine",
                         renameDate: "Date et heure",
                         ejectWhenDone: "Éjecter à la fin",
                         importing: "Importation",
                         left: "encore %@",
                         stop: "Arrêter",
                         imported: "Importé : %@",
                         skippedBefore: "%@ ignorés, déjà importés",
                         reveal: "Afficher dans le Finder",
                         eject: "Éjecter",
                         ejected: "Éjectée",
                         ejectFailed: "Impossible d’éjecter la carte. Un fichier y est peut-être ouvert.",
                         done: "OK",
                         retry: "Réessayer",
                         cardRemoved: "Carte retirée",
                         cardRemovedDetail: "Réinsérez-la et réessayez. Les fichiers déjà copiés restent.",
                         diskFull: "Le disque de destination est plein",
                         diskFullDetail: "Libérez %@ et réessayez.",
                         failed: "Importation interrompue",
                         failedDetail: "Impossible de copier %@.",
                         detect: "Détecter les cartes d’appareil photo",
                         detectCaption: "Quand une carte avec un dossier DCIM ou des dossiers vidéo d’appareil est montée, un avis propose de l’importer. Rien n’est jamais modifié ni supprimé sur la carte.",
                         folder: "Importer dans",
                         choose: "Choisir…",
                         reset: "Réinitialiser",
                         defaults: "Par défaut",
                         renameCaption: "Date et heure nomme les fichiers comme 20261120-101502-0001.ARW, numérotés dans l’ordre de prise de vue.",
                         skipCaption: "Ignore les fichiers dont le nom, la taille et l’heure de prise de vue correspondent à ce qui a déjà été importé de cette carte.",
                         eventCaption: "Chaque importation va dans un dossier daté du jour de la photo la plus récente. Vous pouvez le renommer avant d’importer.")
        case .it:
            return .init(title: "Importa scheda",
                         summary: "Importa foto e video dalle schede della fotocamera in cartelle evento con data.",
                         sdCard: "Scheda SD",
                         photos: ["%@ foto", "%@ foto", "%@ foto"],
                         videos: ["%@ video", "%@ video", "%@ video"],
                         importAction: "Importa",
                         newFiles: "%@ nuovi",
                         alreadyImported: "%@ già importati",
                         nothingNew: "Tutto su questa scheda è già stato importato.",
                         noMedia: "Nessuna foto o video su questa scheda.",
                         scanning: "Lettura della scheda…",
                         empty: "Inserisci una scheda della fotocamera per importare foto e video.",
                         destination: "Destinazione",
                         eventPlaceholder: "Nome dell’evento",
                         separateRaw: "Cartelle RAW e JPG",
                         videoFolder: "Cartella Video",
                         skipImported: "Salta importati",
                         rename: "Nomi",
                         renameOriginal: "Originali",
                         renameDate: "Data e ora",
                         ejectWhenDone: "Espelli alla fine",
                         importing: "Importazione",
                         left: "mancano %@",
                         stop: "Interrompi",
                         imported: "Importati %@",
                         skippedBefore: "%@ saltati, già importati",
                         reveal: "Mostra nel Finder",
                         eject: "Espelli",
                         ejected: "Espulsa",
                         ejectFailed: "Impossibile espellere la scheda. Forse un file è aperto.",
                         done: "Fine",
                         retry: "Riprova",
                         cardRemoved: "Scheda rimossa",
                         cardRemovedDetail: "Reinseriscila e riprova. I file già copiati restano.",
                         diskFull: "Il disco di destinazione è pieno",
                         diskFullDetail: "Libera %@ e riprova.",
                         failed: "Importazione interrotta",
                         failedDetail: "Impossibile copiare %@.",
                         detect: "Rileva schede della fotocamera",
                         detectCaption: "Quando viene montata una scheda con cartella DCIM o cartelle video della fotocamera, un avviso propone di importarla. Sulla scheda non viene mai modificato né eliminato nulla.",
                         folder: "Importa in",
                         choose: "Scegli…",
                         reset: "Ripristina",
                         defaults: "Predefiniti",
                         renameCaption: "Data e ora nomina i file come 20261120-101502-0001.ARW, numerati nell’ordine di scatto.",
                         skipCaption: "Salta i file con nome, dimensione e ora di scatto uguali a quanto già importato da questa scheda.",
                         eventCaption: "Ogni importazione va in una cartella con la data della foto più recente. Puoi rinominarla prima di importare.")
        case .ja:
            return .init(title: "カード読み込み",
                         summary: "カメラのカードから写真とビデオを日付付きのイベントフォルダに読み込みます。",
                         sdCard: "SDカード",
                         photos: ["写真 %@ 枚", "写真 %@ 枚", "写真 %@ 枚"],
                         videos: ["ビデオ %@ 本", "ビデオ %@ 本", "ビデオ %@ 本"],
                         importAction: "読み込む",
                         newFiles: "新規 %@",
                         alreadyImported: "読み込み済み %@",
                         nothingNew: "このカードの内容はすべて読み込み済みです。",
                         noMedia: "このカードには写真もビデオもありません。",
                         scanning: "カードを読み取り中…",
                         empty: "カメラのカードを挿入すると、写真とビデオを読み込めます。",
                         destination: "読み込み先",
                         eventPlaceholder: "イベント名",
                         separateRaw: "RAW と JPG を分ける",
                         videoFolder: "Video フォルダ",
                         skipImported: "読み込み済みを除外",
                         rename: "ファイル名",
                         renameOriginal: "元の名前",
                         renameDate: "日付と時刻",
                         ejectWhenDone: "完了後に取り出す",
                         importing: "読み込み中",
                         left: "残り %@",
                         stop: "停止",
                         imported: "読み込み完了 %@",
                         skippedBefore: "%@ 件は読み込み済みのため除外",
                         reveal: "Finder に表示",
                         eject: "取り出す",
                         ejected: "取り出し済み",
                         ejectFailed: "カードを取り出せませんでした。カード上のファイルが開いている可能性があります。",
                         done: "完了",
                         retry: "再試行",
                         cardRemoved: "カードが取り外されました",
                         cardRemovedDetail: "もう一度挿入して再試行してください。コピー済みのファイルは残ります。",
                         diskFull: "読み込み先のディスクがいっぱいです",
                         diskFullDetail: "%@ の空きを作って再試行してください。",
                         failed: "読み込みが止まりました",
                         failedDetail: "%@ をコピーできませんでした。",
                         detect: "カメラのカードを検出",
                         detectCaption: "DCIM フォルダやカメラのビデオフォルダがあるカードがマウントされると、通知で読み込みを提案します。カード上のものは変更も削除もしません。",
                         folder: "読み込み先",
                         choose: "選択…",
                         reset: "リセット",
                         defaults: "デフォルト",
                         renameCaption: "日付と時刻では 20261120-101502-0001.ARW のように、撮影順に番号を付けて名前を付けます。",
                         skipCaption: "名前、サイズ、撮影時刻がこのカードから以前読み込んだものと一致するファイルを除外します。",
                         eventCaption: "読み込みごとに、最新の写真の撮影日を名前にしたフォルダに入ります。読み込む前に名前を変更できます。")
        case .ko:
            return .init(title: "카드 가져오기",
                         summary: "카메라 카드의 사진과 동영상을 날짜별 이벤트 폴더로 가져옵니다.",
                         sdCard: "SD 카드",
                         photos: ["사진 %@장", "사진 %@장", "사진 %@장"],
                         videos: ["동영상 %@개", "동영상 %@개", "동영상 %@개"],
                         importAction: "가져오기",
                         newFiles: "새 항목 %@",
                         alreadyImported: "이미 가져옴 %@",
                         nothingNew: "이 카드의 모든 항목을 이미 가져왔습니다.",
                         noMedia: "이 카드에 사진이나 동영상이 없습니다.",
                         scanning: "카드 읽는 중…",
                         empty: "카메라 카드를 넣으면 사진과 동영상을 가져올 수 있습니다.",
                         destination: "저장 위치",
                         eventPlaceholder: "이벤트 이름",
                         separateRaw: "RAW와 JPG 폴더",
                         videoFolder: "Video 폴더",
                         skipImported: "가져온 항목 건너뛰기",
                         rename: "파일 이름",
                         renameOriginal: "원본",
                         renameDate: "날짜와 시간",
                         ejectWhenDone: "완료 후 추출",
                         importing: "가져오는 중",
                         left: "%@ 남음",
                         stop: "중지",
                         imported: "가져옴 %@",
                         skippedBefore: "%@개 건너뜀, 이미 가져옴",
                         reveal: "Finder에서 보기",
                         eject: "추출",
                         ejected: "추출됨",
                         ejectFailed: "카드를 추출할 수 없습니다. 카드의 파일이 열려 있을 수 있습니다.",
                         done: "완료",
                         retry: "다시 시도",
                         cardRemoved: "카드가 제거됨",
                         cardRemovedDetail: "다시 넣고 다시 시도하세요. 복사된 파일은 그대로 남습니다.",
                         diskFull: "저장 디스크가 가득 참",
                         diskFullDetail: "%@를 확보한 뒤 다시 시도하세요.",
                         failed: "가져오기가 중단됨",
                         failedDetail: "%@을(를) 복사할 수 없습니다.",
                         detect: "카메라 카드 감지",
                         detectCaption: "DCIM 폴더나 카메라 동영상 폴더가 있는 카드가 마운트되면 알림이 가져오기를 제안합니다. 카드의 내용은 절대 변경하거나 삭제하지 않습니다.",
                         folder: "가져올 위치",
                         choose: "선택…",
                         reset: "재설정",
                         defaults: "기본값",
                         renameCaption: "날짜와 시간은 촬영 순서대로 번호를 붙여 20261120-101502-0001.ARW처럼 이름을 지정합니다.",
                         skipCaption: "이름, 크기, 촬영 시간이 이 카드에서 이전에 가져온 항목과 같은 파일을 건너뜁니다.",
                         eventCaption: "각 가져오기는 가장 최근 사진의 촬영일 이름의 폴더에 저장됩니다. 가져오기 전에 이름을 바꿀 수 있습니다.")
        case .uk:
            return .init(title: "Імпорт з картки",
                         summary: "Імпортує фото й відео з карток камери в папки подій із датою.",
                         sdCard: "SD-картка",
                         photos: ["%@ фото", "%@ фото", "%@ фото"],
                         videos: ["%@ відео", "%@ відео", "%@ відео"],
                         importAction: "Імпорт",
                         newFiles: "нових: %@",
                         alreadyImported: "імпортовано раніше: %@",
                         nothingNew: "Усе з цієї картки вже імпортовано.",
                         noMedia: "На цій картці немає фото чи відео.",
                         scanning: "Читання картки…",
                         empty: "Вставте картку камери, щоб імпортувати фото й відео.",
                         destination: "Куди",
                         eventPlaceholder: "Назва події",
                         separateRaw: "Папки RAW і JPG",
                         videoFolder: "Папка Video",
                         skipImported: "Пропускати імпортовані",
                         rename: "Назви",
                         renameOriginal: "Початкові",
                         renameDate: "Дата й час",
                         ejectWhenDone: "Вийняти після завершення",
                         importing: "Імпорт",
                         left: "лишилося %@",
                         stop: "Стоп",
                         imported: "Імпортовано %@",
                         skippedBefore: "пропущено %@, імпортовано раніше",
                         reveal: "Показати у Finder",
                         eject: "Вийняти",
                         ejected: "Вийнято",
                         ejectFailed: "Не вдалося вийняти картку. Можливо, на ній відкритий файл.",
                         done: "Готово",
                         retry: "Повторити",
                         cardRemoved: "Картку вийнято",
                         cardRemovedDetail: "Вставте її знову й повторіть. Скопійовані файли залишаться.",
                         diskFull: "Диск призначення заповнено",
                         diskFullDetail: "Звільніть %@ і повторіть.",
                         failed: "Імпорт зупинено",
                         failedDetail: "Не вдалося скопіювати %@.",
                         detect: "Розпізнавати картки камери",
                         detectCaption: "Коли підключається картка з папкою DCIM або папками відео камери, сповіщення пропонує імпорт. На картці нічого не змінюється й не видаляється.",
                         folder: "Імпорт у",
                         choose: "Вибрати…",
                         reset: "Скинути",
                         defaults: "Типові",
                         renameCaption: "Дата й час називає файли як 20261120-101502-0001.ARW, нумеруючи їх у порядку зйомки.",
                         skipCaption: "Пропускає файли, чиї назва, розмір і час зйомки збігаються з уже імпортованими з цієї картки.",
                         eventCaption: "Кожен імпорт потрапляє в папку з датою найновішого знімка. Її можна перейменувати до імпорту.")
        case .zhHans:
            return .init(title: "卡片导入",
                         summary: "将相机存储卡中的照片和视频导入按日期命名的活动文件夹。",
                         sdCard: "SD 卡",
                         photos: ["%@ 张照片", "%@ 张照片", "%@ 张照片"],
                         videos: ["%@ 个视频", "%@ 个视频", "%@ 个视频"],
                         importAction: "导入",
                         newFiles: "新增 %@",
                         alreadyImported: "已导入过 %@",
                         nothingNew: "这张卡上的内容都已导入过。",
                         noMedia: "这张卡上没有照片或视频。",
                         scanning: "正在读取存储卡…",
                         empty: "插入相机存储卡即可导入其中的照片和视频。",
                         destination: "目标位置",
                         eventPlaceholder: "活动名称",
                         separateRaw: "分开 RAW 和 JPG",
                         videoFolder: "Video 文件夹",
                         skipImported: "跳过已导入",
                         rename: "文件名",
                         renameOriginal: "原始",
                         renameDate: "日期和时间",
                         ejectWhenDone: "完成后推出",
                         importing: "正在导入",
                         left: "剩余 %@",
                         stop: "停止",
                         imported: "已导入 %@",
                         skippedBefore: "跳过 %@ 个已导入的文件",
                         reveal: "在访达中显示",
                         eject: "推出",
                         ejected: "已推出",
                         ejectFailed: "无法推出存储卡，卡上的某个文件可能仍在打开。",
                         done: "完成",
                         retry: "重试",
                         cardRemoved: "存储卡已移除",
                         cardRemovedDetail: "重新插入后重试，已复制的文件会保留。",
                         diskFull: "目标磁盘已满",
                         diskFullDetail: "请腾出 %@ 后重试。",
                         failed: "导入已停止",
                         failedDetail: "无法复制 %@。",
                         detect: "检测相机存储卡",
                         detectCaption: "装载含 DCIM 文件夹或相机视频文件夹的存储卡时，会有通知提示导入。卡上的内容绝不会被更改或删除。",
                         folder: "导入到",
                         choose: "选择…",
                         reset: "还原",
                         defaults: "默认设置",
                         renameCaption: "日期和时间会按拍摄顺序编号，将文件命名为 20261120-101502-0001.ARW 这样的格式。",
                         skipCaption: "跳过名称、大小和拍摄时间与之前从这张卡导入的文件一致的文件。",
                         eventCaption: "每次导入都会放进以最新照片拍摄日期命名的文件夹，导入前可以改名。")
        case .zhTW:
            return .init(title: "記憶卡匯入",
                         summary: "將相機記憶卡中的照片和影片匯入以日期命名的活動資料夾。",
                         sdCard: "SD 卡",
                         photos: ["%@ 張照片", "%@ 張照片", "%@ 張照片"],
                         videos: ["%@ 部影片", "%@ 部影片", "%@ 部影片"],
                         importAction: "匯入",
                         newFiles: "新增 %@",
                         alreadyImported: "已匯入過 %@",
                         nothingNew: "這張卡上的內容都已匯入過。",
                         noMedia: "這張卡上沒有照片或影片。",
                         scanning: "正在讀取記憶卡…",
                         empty: "插入相機記憶卡即可匯入其中的照片和影片。",
                         destination: "目的地",
                         eventPlaceholder: "活動名稱",
                         separateRaw: "分開 RAW 和 JPG",
                         videoFolder: "Video 資料夾",
                         skipImported: "略過已匯入",
                         rename: "檔名",
                         renameOriginal: "原始",
                         renameDate: "日期與時間",
                         ejectWhenDone: "完成後退出",
                         importing: "正在匯入",
                         left: "剩餘 %@",
                         stop: "停止",
                         imported: "已匯入 %@",
                         skippedBefore: "略過 %@ 個已匯入的檔案",
                         reveal: "在 Finder 中顯示",
                         eject: "退出",
                         ejected: "已退出",
                         ejectFailed: "無法退出記憶卡，卡上可能有檔案仍在開啟中。",
                         done: "完成",
                         retry: "重試",
                         cardRemoved: "記憶卡已移除",
                         cardRemovedDetail: "重新插入後再試一次，已複製的檔案會保留。",
                         diskFull: "目的地磁碟已滿",
                         diskFullDetail: "請騰出 %@ 後再試一次。",
                         failed: "匯入已停止",
                         failedDetail: "無法複製 %@。",
                         detect: "偵測相機記憶卡",
                         detectCaption: "裝載含 DCIM 資料夾或相機影片資料夾的記憶卡時，會有通知建議匯入。卡上的內容絕不會被更改或刪除。",
                         folder: "匯入至",
                         choose: "選擇…",
                         reset: "重置",
                         defaults: "預設值",
                         renameCaption: "日期與時間會依拍攝順序編號，將檔案命名為 20261120-101502-0001.ARW 這樣的格式。",
                         skipCaption: "略過名稱、大小和拍攝時間與先前從這張卡匯入的檔案相同的檔案。",
                         eventCaption: "每次匯入都會放進以最新照片拍攝日期命名的資料夾，匯入前可以改名。")
        case .zhHK:
            return .init(title: "記憶卡匯入",
                         summary: "將相機記憶卡中的相片和影片匯入以日期命名的活動資料夾。",
                         sdCard: "SD 卡",
                         photos: ["%@ 張相片", "%@ 張相片", "%@ 張相片"],
                         videos: ["%@ 段影片", "%@ 段影片", "%@ 段影片"],
                         importAction: "匯入",
                         newFiles: "新增 %@",
                         alreadyImported: "已匯入過 %@",
                         nothingNew: "這張卡上的內容都已匯入過。",
                         noMedia: "這張卡上沒有相片或影片。",
                         scanning: "正在讀取記憶卡…",
                         empty: "插入相機記憶卡即可匯入其中的相片和影片。",
                         destination: "目的地",
                         eventPlaceholder: "活動名稱",
                         separateRaw: "分開 RAW 和 JPG",
                         videoFolder: "Video 資料夾",
                         skipImported: "略過已匯入",
                         rename: "檔名",
                         renameOriginal: "原始",
                         renameDate: "日期與時間",
                         ejectWhenDone: "完成後退出",
                         importing: "正在匯入",
                         left: "剩餘 %@",
                         stop: "停止",
                         imported: "已匯入 %@",
                         skippedBefore: "略過 %@ 個已匯入的檔案",
                         reveal: "在 Finder 中顯示",
                         eject: "退出",
                         ejected: "已退出",
                         ejectFailed: "無法退出記憶卡，卡上可能有檔案仍在開啟中。",
                         done: "完成",
                         retry: "重試",
                         cardRemoved: "記憶卡已移除",
                         cardRemovedDetail: "重新插入後再試一次，已複製的檔案會保留。",
                         diskFull: "目的地磁碟已滿",
                         diskFullDetail: "請騰出 %@ 後再試一次。",
                         failed: "匯入已停止",
                         failedDetail: "無法複製 %@。",
                         detect: "偵測相機記憶卡",
                         detectCaption: "裝載含 DCIM 資料夾或相機影片資料夾的記憶卡時，會有通知建議匯入。卡上的內容絕不會被更改或刪除。",
                         folder: "匯入至",
                         choose: "選擇…",
                         reset: "重置",
                         defaults: "預設值",
                         renameCaption: "日期與時間會依拍攝順序編號，將檔案命名為 20261120-101502-0001.ARW 這樣的格式。",
                         skipCaption: "略過名稱、大小和拍攝時間與先前從這張卡匯入的檔案相同的檔案。",
                         eventCaption: "每次匯入都會放進以最新相片拍攝日期命名的資料夾，匯入前可以改名。")
        }
    }
}

// MARK: - Daily recap (Zenith fork)

struct ZenithRecapStrings {
    /// The page, its module and the home widget.
    let title: String
    /// What the section does, in Settings.
    let summary: String
    /// The notice’s title.
    let yourDay: String
    /// The notice’s action.
    let open: String
    let empty: String
    let copyText: String
    let copied: String
    let saveImage: String
    let saved: String
    let saveFailed: String
    /// `%@` is the date, as in “My day · Fri, Nov 20”.
    let shareHeading: String
    /// Card labels.
    let coding: String
    let deploys: String
    let commitsLabel: String
    let pullRequests: String
    let commandsLabel: String
    let photosLabel: String
    let videosLabel: String
    let exportsLabel: String
    let agentsLabel: String
    /// `%@` is a duration, as in “6h 11m coding”.
    let codingHeadline: String
    /// One, few and many: `%@` is the grouped count.
    let deploysCount: [String]
    let commitsCount: [String]
    let commandsCount: [String]
    let exportsCount: [String]
    let turns: [String]
    let sessions: [String]
    let pullsOpened: [String]
    let reviewsWaiting: [String]
    let checksFailing: [String]
    let photos: [String]
    let videos: [String]
    let ready: [String]
    let failed: [String]
    let building: [String]
    /// Settings.
    let dailyRecap: String
    let dailyRecapCaption: String
    let showAt: String
    let weekdaysOnly: String
    let include: String
    let includeCaption: String
    let sourceCoding: String
    let sourceDeploys: String
    let sourceGitHub: String
    let sourceTerminal: String
    let sourceImports: String
    let sourceExports: String
    let sourceAgents: String
}

extension ZenithStrings {
    /// Zenith fork: the end-of-day recap (RecapService, RecapPage, RecapSettingsView).
    static func recap(_ language: AppLanguage) -> ZenithRecapStrings {
        switch language {
        case .enUS:
            return .init(title: "Today",
                         summary: "Sums up your day from coding time, deploys, commits, long commands, card imports and exports.",
                         yourDay: "Your day",
                         open: "Open",
                         empty: "Nothing to sum up yet. Coding time, deploys, commits, long commands, imports and exports show up here as your day goes.",
                         copyText: "Copy as text",
                         copied: "Copied",
                         saveImage: "Save image",
                         saved: "Saved to Downloads",
                         saveFailed: "Couldn’t save the image",
                         shareHeading: "My day · %@",
                         coding: "Coding",
                         deploys: "Deploys",
                         commitsLabel: "Commits",
                         pullRequests: "Pull requests",
                         commandsLabel: "Long commands",
                         photosLabel: "Photos",
                         videosLabel: "Videos",
                         exportsLabel: "Exports",
                         agentsLabel: "Agent turns",
                         codingHeadline: "%@ coding",
                         deploysCount: ["%@ deploy", "%@ deploys", "%@ deploys"],
                         commitsCount: ["%@ commit", "%@ commits", "%@ commits"],
                         commandsCount: ["%@ long command", "%@ long commands", "%@ long commands"],
                         exportsCount: ["%@ export", "%@ exports", "%@ exports"],
                         turns: ["%@ agent turn", "%@ agent turns", "%@ agent turns"],
                         sessions: ["%@ session", "%@ sessions", "%@ sessions"],
                         pullsOpened: ["%@ PR opened", "%@ PRs opened", "%@ PRs opened"],
                         reviewsWaiting: ["%@ review waiting", "%@ reviews waiting", "%@ reviews waiting"],
                         checksFailing: ["%@ check failing", "%@ checks failing", "%@ checks failing"],
                         photos: ["%@ photo", "%@ photos", "%@ photos"],
                         videos: ["%@ video", "%@ videos", "%@ videos"],
                         ready: ["%@ ready", "%@ ready", "%@ ready"],
                         failed: ["%@ failed", "%@ failed", "%@ failed"],
                         building: ["%@ building", "%@ building", "%@ building"],
                         dailyRecap: "Daily recap",
                         dailyRecapCaption: "At the time you choose, a notice sums up your day, once a day. The Today page has it any time.",
                         showAt: "Show at",
                         weekdaysOnly: "Weekdays only",
                         include: "Include",
                         includeCaption: "Each part shows only when it has something from today. Nothing new is read from the network, apart from one GitHub search for today’s commits through gh.",
                         sourceCoding: "Coding time from WakaTime",
                         sourceDeploys: "Vercel deploys",
                         sourceGitHub: "GitHub commits and pull requests",
                         sourceTerminal: "Long terminal commands",
                         sourceImports: "Card imports",
                         sourceExports: "Finished exports",
                         sourceAgents: "Claude Code turns")
        case .ptBR:
            return .init(title: "Hoje",
                         summary: "Resume o seu dia com tempo de código, deploys, commits, comandos longos, importações de cartão e exportações.",
                         yourDay: "Seu dia",
                         open: "Abrir",
                         empty: "Nada para resumir ainda. Tempo de código, deploys, commits, comandos longos, importações e exportações aparecem aqui ao longo do dia.",
                         copyText: "Copiar como texto",
                         copied: "Copiado",
                         saveImage: "Salvar imagem",
                         saved: "Salva em Downloads",
                         saveFailed: "Não foi possível salvar a imagem",
                         shareHeading: "Meu dia · %@",
                         coding: "Código",
                         deploys: "Deploys",
                         commitsLabel: "Commits",
                         pullRequests: "Pull requests",
                         commandsLabel: "Comandos longos",
                         photosLabel: "Fotos",
                         videosLabel: "Vídeos",
                         exportsLabel: "Exportações",
                         agentsLabel: "Turnos de agente",
                         codingHeadline: "%@ de código",
                         deploysCount: ["%@ deploy", "%@ deploys", "%@ deploys"],
                         commitsCount: ["%@ commit", "%@ commits", "%@ commits"],
                         commandsCount: ["%@ comando longo", "%@ comandos longos", "%@ comandos longos"],
                         exportsCount: ["%@ exportação", "%@ exportações", "%@ exportações"],
                         turns: ["%@ turno de agente", "%@ turnos de agente", "%@ turnos de agente"],
                         sessions: ["%@ sessão", "%@ sessões", "%@ sessões"],
                         pullsOpened: ["%@ PR aberto", "%@ PRs abertos", "%@ PRs abertos"],
                         reviewsWaiting: ["%@ revisão pendente", "%@ revisões pendentes", "%@ revisões pendentes"],
                         checksFailing: ["%@ check com falha", "%@ checks com falha", "%@ checks com falha"],
                         photos: ["%@ foto", "%@ fotos", "%@ fotos"],
                         videos: ["%@ vídeo", "%@ vídeos", "%@ vídeos"],
                         ready: ["%@ pronto", "%@ prontos", "%@ prontos"],
                         failed: ["%@ com falha", "%@ com falha", "%@ com falha"],
                         building: ["%@ em build", "%@ em build", "%@ em build"],
                         dailyRecap: "Resumo diário",
                         dailyRecapCaption: "No horário que você escolher, um aviso resume o seu dia, uma vez por dia. A página Hoje mostra o resumo a qualquer hora.",
                         showAt: "Mostrar às",
                         weekdaysOnly: "Só em dias úteis",
                         include: "Incluir",
                         includeCaption: "Cada parte aparece só quando tem algo de hoje. Nada novo é lido da rede, exceto uma busca no GitHub pelos commits de hoje via gh.",
                         sourceCoding: "Tempo de código do WakaTime",
                         sourceDeploys: "Deploys da Vercel",
                         sourceGitHub: "Commits e pull requests do GitHub",
                         sourceTerminal: "Comandos longos no terminal",
                         sourceImports: "Importações de cartão",
                         sourceExports: "Exportações concluídas",
                         sourceAgents: "Turnos do Claude Code")
        case .tr:
            return .init(title: "Bugün",
                         summary: "Gününüzü kodlama süresi, deploy’lar, commit’ler, uzun komutlar, kart aktarımları ve dışa aktarmalarla özetler.",
                         yourDay: "Gününüz",
                         open: "Aç",
                         empty: "Henüz özetlenecek bir şey yok. Kodlama süresi, deploy’lar, commit’ler, uzun komutlar, aktarımlar ve dışa aktarmalar gün boyunca burada görünür.",
                         copyText: "Metin olarak kopyala",
                         copied: "Kopyalandı",
                         saveImage: "Görüntüyü kaydet",
                         saved: "İndirilenler’e kaydedildi",
                         saveFailed: "Görüntü kaydedilemedi",
                         shareHeading: "Günüm · %@",
                         coding: "Kodlama",
                         deploys: "Deploy’lar",
                         commitsLabel: "Commit’ler",
                         pullRequests: "Pull request’ler",
                         commandsLabel: "Uzun komutlar",
                         photosLabel: "Fotoğraflar",
                         videosLabel: "Videolar",
                         exportsLabel: "Dışa aktarmalar",
                         agentsLabel: "Ajan turları",
                         codingHeadline: "%@ kodlama",
                         deploysCount: ["%@ deploy", "%@ deploy", "%@ deploy"],
                         commitsCount: ["%@ commit", "%@ commit", "%@ commit"],
                         commandsCount: ["%@ uzun komut", "%@ uzun komut", "%@ uzun komut"],
                         exportsCount: ["%@ dışa aktarma", "%@ dışa aktarma", "%@ dışa aktarma"],
                         turns: ["%@ ajan turu", "%@ ajan turu", "%@ ajan turu"],
                         sessions: ["%@ oturum", "%@ oturum", "%@ oturum"],
                         pullsOpened: ["%@ PR açıldı", "%@ PR açıldı", "%@ PR açıldı"],
                         reviewsWaiting: ["%@ inceleme bekliyor", "%@ inceleme bekliyor", "%@ inceleme bekliyor"],
                         checksFailing: ["%@ kontrol başarısız", "%@ kontrol başarısız", "%@ kontrol başarısız"],
                         photos: ["%@ fotoğraf", "%@ fotoğraf", "%@ fotoğraf"],
                         videos: ["%@ video", "%@ video", "%@ video"],
                         ready: ["%@ hazır", "%@ hazır", "%@ hazır"],
                         failed: ["%@ başarısız", "%@ başarısız", "%@ başarısız"],
                         building: ["%@ derleniyor", "%@ derleniyor", "%@ derleniyor"],
                         dailyRecap: "Günlük özet",
                         dailyRecapCaption: "Seçtiğiniz saatte bir bildirim gününüzü özetler, günde bir kez. Bugün sayfası özeti her zaman gösterir.",
                         showAt: "Gösterme saati",
                         weekdaysOnly: "Yalnızca hafta içi",
                         include: "Dahil et",
                         includeCaption: "Her bölüm yalnızca bugünden bir şey varsa görünür. gh üzerinden bugünkü commit’ler için yapılan tek bir GitHub araması dışında ağdan yeni bir şey okunmaz.",
                         sourceCoding: "WakaTime kodlama süresi",
                         sourceDeploys: "Vercel deploy’ları",
                         sourceGitHub: "GitHub commit’leri ve pull request’leri",
                         sourceTerminal: "Uzun terminal komutları",
                         sourceImports: "Kart aktarımları",
                         sourceExports: "Biten dışa aktarmalar",
                         sourceAgents: "Claude Code turları")
        case .ru:
            return .init(title: "Сегодня",
                         summary: "Подводит итоги дня: время за кодом, деплои, коммиты, долгие команды, импорт с карт и экспорт.",
                         yourDay: "Ваш день",
                         open: "Открыть",
                         empty: "Пока нечего подводить. Время за кодом, деплои, коммиты, долгие команды, импорт и экспорт появятся здесь в течение дня.",
                         copyText: "Скопировать текстом",
                         copied: "Скопировано",
                         saveImage: "Сохранить картинку",
                         saved: "Сохранено в Загрузки",
                         saveFailed: "Не удалось сохранить картинку",
                         shareHeading: "Мой день · %@",
                         coding: "Код",
                         deploys: "Деплои",
                         commitsLabel: "Коммиты",
                         pullRequests: "Пул-реквесты",
                         commandsLabel: "Долгие команды",
                         photosLabel: "Фото",
                         videosLabel: "Видео",
                         exportsLabel: "Экспорт",
                         agentsLabel: "Ходы агентов",
                         codingHeadline: "%@ за кодом",
                         deploysCount: ["%@ деплой", "%@ деплоя", "%@ деплоев"],
                         commitsCount: ["%@ коммит", "%@ коммита", "%@ коммитов"],
                         commandsCount: ["%@ долгая команда", "%@ долгие команды", "%@ долгих команд"],
                         exportsCount: ["%@ экспорт", "%@ экспорта", "%@ экспортов"],
                         turns: ["%@ ход агента", "%@ хода агента", "%@ ходов агента"],
                         sessions: ["%@ сессия", "%@ сессии", "%@ сессий"],
                         pullsOpened: ["%@ PR открыт", "%@ PR открыто", "%@ PR открыто"],
                         reviewsWaiting: ["%@ ревью ждёт", "%@ ревью ждут", "%@ ревью ждут"],
                         checksFailing: ["%@ проверка не прошла", "%@ проверки не прошли", "%@ проверок не прошли"],
                         photos: ["%@ фото", "%@ фото", "%@ фото"],
                         videos: ["%@ видео", "%@ видео", "%@ видео"],
                         ready: ["%@ готов", "%@ готовы", "%@ готовы"],
                         failed: ["%@ с ошибкой", "%@ с ошибкой", "%@ с ошибкой"],
                         building: ["%@ собирается", "%@ собираются", "%@ собираются"],
                         dailyRecap: "Итоги дня",
                         dailyRecapCaption: "В выбранное время уведомление подводит итоги дня, раз в день. На странице «Сегодня» они есть всегда.",
                         showAt: "Показывать в",
                         weekdaysOnly: "Только по будням",
                         include: "Включать",
                         includeCaption: "Каждая часть видна, только если за сегодня что-то есть. Из сети ничего нового не читается, кроме одного поиска коммитов за сегодня на GitHub через gh.",
                         sourceCoding: "Время за кодом из WakaTime",
                         sourceDeploys: "Деплои Vercel",
                         sourceGitHub: "Коммиты и пул-реквесты GitHub",
                         sourceTerminal: "Долгие команды в терминале",
                         sourceImports: "Импорт с карт",
                         sourceExports: "Готовый экспорт",
                         sourceAgents: "Ходы Claude Code")
        case .es:
            return .init(title: "Hoy",
                         summary: "Resume tu día con el tiempo de código, los deploys, commits, comandos largos, importaciones de tarjeta y exportaciones.",
                         yourDay: "Tu día",
                         open: "Abrir",
                         empty: "Aún no hay nada que resumir. El tiempo de código, los deploys, commits, comandos largos, importaciones y exportaciones aparecen aquí a lo largo del día.",
                         copyText: "Copiar como texto",
                         copied: "Copiado",
                         saveImage: "Guardar imagen",
                         saved: "Guardada en Descargas",
                         saveFailed: "No se pudo guardar la imagen",
                         shareHeading: "Mi día · %@",
                         coding: "Código",
                         deploys: "Deploys",
                         commitsLabel: "Commits",
                         pullRequests: "Pull requests",
                         commandsLabel: "Comandos largos",
                         photosLabel: "Fotos",
                         videosLabel: "Vídeos",
                         exportsLabel: "Exportaciones",
                         agentsLabel: "Turnos de agente",
                         codingHeadline: "%@ de código",
                         deploysCount: ["%@ deploy", "%@ deploys", "%@ deploys"],
                         commitsCount: ["%@ commit", "%@ commits", "%@ commits"],
                         commandsCount: ["%@ comando largo", "%@ comandos largos", "%@ comandos largos"],
                         exportsCount: ["%@ exportación", "%@ exportaciones", "%@ exportaciones"],
                         turns: ["%@ turno de agente", "%@ turnos de agente", "%@ turnos de agente"],
                         sessions: ["%@ sesión", "%@ sesiones", "%@ sesiones"],
                         pullsOpened: ["%@ PR abierto", "%@ PR abiertos", "%@ PR abiertos"],
                         reviewsWaiting: ["%@ revisión pendiente", "%@ revisiones pendientes", "%@ revisiones pendientes"],
                         checksFailing: ["%@ check fallido", "%@ checks fallidos", "%@ checks fallidos"],
                         photos: ["%@ foto", "%@ fotos", "%@ fotos"],
                         videos: ["%@ vídeo", "%@ vídeos", "%@ vídeos"],
                         ready: ["%@ listo", "%@ listos", "%@ listos"],
                         failed: ["%@ fallido", "%@ fallidos", "%@ fallidos"],
                         building: ["%@ en build", "%@ en build", "%@ en build"],
                         dailyRecap: "Resumen diario",
                         dailyRecapCaption: "A la hora que elijas, un aviso resume tu día, una vez al día. La página Hoy lo tiene siempre.",
                         showAt: "Mostrar a las",
                         weekdaysOnly: "Solo entre semana",
                         include: "Incluir",
                         includeCaption: "Cada parte aparece solo si hay algo de hoy. No se lee nada nuevo de la red, salvo una búsqueda en GitHub de los commits de hoy a través de gh.",
                         sourceCoding: "Tiempo de código de WakaTime",
                         sourceDeploys: "Deploys de Vercel",
                         sourceGitHub: "Commits y pull requests de GitHub",
                         sourceTerminal: "Comandos largos del terminal",
                         sourceImports: "Importaciones de tarjeta",
                         sourceExports: "Exportaciones terminadas",
                         sourceAgents: "Turnos de Claude Code")
        case .sk:
            return .init(title: "Dnes",
                         summary: "Zhrnie váš deň podľa času pri kóde, deployov, commitov, dlhých príkazov, importov z kariet a exportov.",
                         yourDay: "Váš deň",
                         open: "Otvoriť",
                         empty: "Zatiaľ nie je čo zhrnúť. Čas pri kóde, deploye, commity, dlhé príkazy, importy a exporty sa tu objavia počas dňa.",
                         copyText: "Kopírovať ako text",
                         copied: "Skopírované",
                         saveImage: "Uložiť obrázok",
                         saved: "Uložené do Stiahnutých",
                         saveFailed: "Obrázok sa nepodarilo uložiť",
                         shareHeading: "Môj deň · %@",
                         coding: "Kód",
                         deploys: "Deploye",
                         commitsLabel: "Commity",
                         pullRequests: "Pull requesty",
                         commandsLabel: "Dlhé príkazy",
                         photosLabel: "Fotky",
                         videosLabel: "Videá",
                         exportsLabel: "Exporty",
                         agentsLabel: "Ťahy agentov",
                         codingHeadline: "%@ pri kóde",
                         deploysCount: ["%@ deploy", "%@ deploye", "%@ deployov"],
                         commitsCount: ["%@ commit", "%@ commity", "%@ commitov"],
                         commandsCount: ["%@ dlhý príkaz", "%@ dlhé príkazy", "%@ dlhých príkazov"],
                         exportsCount: ["%@ export", "%@ exporty", "%@ exportov"],
                         turns: ["%@ ťah agenta", "%@ ťahy agenta", "%@ ťahov agenta"],
                         sessions: ["%@ relácia", "%@ relácie", "%@ relácií"],
                         pullsOpened: ["%@ otvorený PR", "%@ otvorené PR", "%@ otvorených PR"],
                         reviewsWaiting: ["%@ čakajúca recenzia", "%@ čakajúce recenzie", "%@ čakajúcich recenzií"],
                         checksFailing: ["%@ zlyhaná kontrola", "%@ zlyhané kontroly", "%@ zlyhaných kontrol"],
                         photos: ["%@ fotka", "%@ fotky", "%@ fotiek"],
                         videos: ["%@ video", "%@ videá", "%@ videí"],
                         ready: ["%@ hotový", "%@ hotové", "%@ hotových"],
                         failed: ["%@ zlyhal", "%@ zlyhali", "%@ zlyhalo"],
                         building: ["%@ sa zostavuje", "%@ sa zostavujú", "%@ sa zostavuje"],
                         dailyRecap: "Denné zhrnutie",
                         dailyRecapCaption: "V čase, ktorý si zvolíte, zhrnie oznámenie váš deň, raz denne. Stránka Dnes ho má vždy.",
                         showAt: "Zobraziť o",
                         weekdaysOnly: "Len v pracovné dni",
                         include: "Zahrnúť",
                         includeCaption: "Každá časť sa zobrazí, len keď má niečo z dneška. Zo siete sa nečíta nič nové okrem jedného hľadania dnešných commitov na GitHube cez gh.",
                         sourceCoding: "Čas pri kóde z WakaTime",
                         sourceDeploys: "Deploye na Verceli",
                         sourceGitHub: "Commity a pull requesty na GitHube",
                         sourceTerminal: "Dlhé príkazy v termináli",
                         sourceImports: "Importy z kariet",
                         sourceExports: "Dokončené exporty",
                         sourceAgents: "Ťahy Claude Code")
        case .de:
            return .init(title: "Heute",
                         summary: "Fasst deinen Tag mit Coding-Zeit, Deploys, Commits, langen Befehlen, Karten-Importen und Exporten zusammen.",
                         yourDay: "Dein Tag",
                         open: "Öffnen",
                         empty: "Noch nichts zusammenzufassen. Coding-Zeit, Deploys, Commits, lange Befehle, Importe und Exporte erscheinen hier im Lauf des Tages.",
                         copyText: "Als Text kopieren",
                         copied: "Kopiert",
                         saveImage: "Bild sichern",
                         saved: "In Downloads gesichert",
                         saveFailed: "Das Bild konnte nicht gesichert werden",
                         shareHeading: "Mein Tag · %@",
                         coding: "Coding",
                         deploys: "Deploys",
                         commitsLabel: "Commits",
                         pullRequests: "Pull Requests",
                         commandsLabel: "Lange Befehle",
                         photosLabel: "Fotos",
                         videosLabel: "Videos",
                         exportsLabel: "Exporte",
                         agentsLabel: "Agent-Runden",
                         codingHeadline: "%@ Coding",
                         deploysCount: ["%@ Deploy", "%@ Deploys", "%@ Deploys"],
                         commitsCount: ["%@ Commit", "%@ Commits", "%@ Commits"],
                         commandsCount: ["%@ langer Befehl", "%@ lange Befehle", "%@ lange Befehle"],
                         exportsCount: ["%@ Export", "%@ Exporte", "%@ Exporte"],
                         turns: ["%@ Agent-Runde", "%@ Agent-Runden", "%@ Agent-Runden"],
                         sessions: ["%@ Sitzung", "%@ Sitzungen", "%@ Sitzungen"],
                         pullsOpened: ["%@ PR eröffnet", "%@ PRs eröffnet", "%@ PRs eröffnet"],
                         reviewsWaiting: ["%@ Review wartet", "%@ Reviews warten", "%@ Reviews warten"],
                         checksFailing: ["%@ Check fehlgeschlagen", "%@ Checks fehlgeschlagen", "%@ Checks fehlgeschlagen"],
                         photos: ["%@ Foto", "%@ Fotos", "%@ Fotos"],
                         videos: ["%@ Video", "%@ Videos", "%@ Videos"],
                         ready: ["%@ fertig", "%@ fertig", "%@ fertig"],
                         failed: ["%@ fehlgeschlagen", "%@ fehlgeschlagen", "%@ fehlgeschlagen"],
                         building: ["%@ im Build", "%@ im Build", "%@ im Build"],
                         dailyRecap: "Tagesrückblick",
                         dailyRecapCaption: "Zur gewählten Uhrzeit fasst eine Mitteilung deinen Tag zusammen, einmal am Tag. Die Seite Heute zeigt ihn jederzeit.",
                         showAt: "Anzeigen um",
                         weekdaysOnly: "Nur an Werktagen",
                         include: "Einbeziehen",
                         includeCaption: "Jeder Teil erscheint nur, wenn es heute etwas gibt. Aus dem Netz wird nichts Neues gelesen, außer einer GitHub-Suche nach den heutigen Commits über gh.",
                         sourceCoding: "Coding-Zeit aus WakaTime",
                         sourceDeploys: "Vercel-Deploys",
                         sourceGitHub: "GitHub-Commits und Pull Requests",
                         sourceTerminal: "Lange Terminal-Befehle",
                         sourceImports: "Karten-Importe",
                         sourceExports: "Fertige Exporte",
                         sourceAgents: "Claude-Code-Runden")
        case .fr:
            return .init(title: "Aujourd’hui",
                         summary: "Résume votre journée avec le temps de code, les déploiements, les commits, les longues commandes, les imports de carte et les exports.",
                         yourDay: "Votre journée",
                         open: "Ouvrir",
                         empty: "Rien à résumer pour l’instant. Le temps de code, les déploiements, commits, longues commandes, imports et exports apparaissent ici au fil de la journée.",
                         copyText: "Copier en texte",
                         copied: "Copié",
                         saveImage: "Enregistrer l’image",
                         saved: "Enregistrée dans Téléchargements",
                         saveFailed: "Impossible d’enregistrer l’image",
                         shareHeading: "Ma journée · %@",
                         coding: "Code",
                         deploys: "Déploiements",
                         commitsLabel: "Commits",
                         pullRequests: "Pull requests",
                         commandsLabel: "Longues commandes",
                         photosLabel: "Photos",
                         videosLabel: "Vidéos",
                         exportsLabel: "Exports",
                         agentsLabel: "Tours d’agent",
                         codingHeadline: "%@ de code",
                         deploysCount: ["%@ déploiement", "%@ déploiements", "%@ déploiements"],
                         commitsCount: ["%@ commit", "%@ commits", "%@ commits"],
                         commandsCount: ["%@ longue commande", "%@ longues commandes", "%@ longues commandes"],
                         exportsCount: ["%@ export", "%@ exports", "%@ exports"],
                         turns: ["%@ tour d’agent", "%@ tours d’agent", "%@ tours d’agent"],
                         sessions: ["%@ session", "%@ sessions", "%@ sessions"],
                         pullsOpened: ["%@ PR ouverte", "%@ PR ouvertes", "%@ PR ouvertes"],
                         reviewsWaiting: ["%@ revue en attente", "%@ revues en attente", "%@ revues en attente"],
                         checksFailing: ["%@ check en échec", "%@ checks en échec", "%@ checks en échec"],
                         photos: ["%@ photo", "%@ photos", "%@ photos"],
                         videos: ["%@ vidéo", "%@ vidéos", "%@ vidéos"],
                         ready: ["%@ prêt", "%@ prêts", "%@ prêts"],
                         failed: ["%@ en échec", "%@ en échec", "%@ en échec"],
                         building: ["%@ en build", "%@ en build", "%@ en build"],
                         dailyRecap: "Récap du jour",
                         dailyRecapCaption: "À l’heure choisie, une notice résume votre journée, une fois par jour. La page Aujourd’hui l’affiche à tout moment.",
                         showAt: "Afficher à",
                         weekdaysOnly: "En semaine uniquement",
                         include: "Inclure",
                         includeCaption: "Chaque partie n’apparaît que si elle a quelque chose d’aujourd’hui. Rien de nouveau n’est lu sur le réseau, sauf une recherche GitHub des commits du jour via gh.",
                         sourceCoding: "Temps de code WakaTime",
                         sourceDeploys: "Déploiements Vercel",
                         sourceGitHub: "Commits et pull requests GitHub",
                         sourceTerminal: "Longues commandes du terminal",
                         sourceImports: "Imports de carte",
                         sourceExports: "Exports terminés",
                         sourceAgents: "Tours de Claude Code")
        case .it:
            return .init(title: "Oggi",
                         summary: "Riassume la tua giornata con tempo di codice, deploy, commit, comandi lunghi, importazioni da scheda ed esportazioni.",
                         yourDay: "La tua giornata",
                         open: "Apri",
                         empty: "Ancora niente da riassumere. Tempo di codice, deploy, commit, comandi lunghi, importazioni ed esportazioni compaiono qui durante la giornata.",
                         copyText: "Copia come testo",
                         copied: "Copiato",
                         saveImage: "Salva immagine",
                         saved: "Salvata in Download",
                         saveFailed: "Impossibile salvare l’immagine",
                         shareHeading: "La mia giornata · %@",
                         coding: "Codice",
                         deploys: "Deploy",
                         commitsLabel: "Commit",
                         pullRequests: "Pull request",
                         commandsLabel: "Comandi lunghi",
                         photosLabel: "Foto",
                         videosLabel: "Video",
                         exportsLabel: "Esportazioni",
                         agentsLabel: "Turni agente",
                         codingHeadline: "%@ di codice",
                         deploysCount: ["%@ deploy", "%@ deploy", "%@ deploy"],
                         commitsCount: ["%@ commit", "%@ commit", "%@ commit"],
                         commandsCount: ["%@ comando lungo", "%@ comandi lunghi", "%@ comandi lunghi"],
                         exportsCount: ["%@ esportazione", "%@ esportazioni", "%@ esportazioni"],
                         turns: ["%@ turno agente", "%@ turni agente", "%@ turni agente"],
                         sessions: ["%@ sessione", "%@ sessioni", "%@ sessioni"],
                         pullsOpened: ["%@ PR aperta", "%@ PR aperte", "%@ PR aperte"],
                         reviewsWaiting: ["%@ revisione in attesa", "%@ revisioni in attesa", "%@ revisioni in attesa"],
                         checksFailing: ["%@ check non superato", "%@ check non superati", "%@ check non superati"],
                         photos: ["%@ foto", "%@ foto", "%@ foto"],
                         videos: ["%@ video", "%@ video", "%@ video"],
                         ready: ["%@ pronto", "%@ pronti", "%@ pronti"],
                         failed: ["%@ fallito", "%@ falliti", "%@ falliti"],
                         building: ["%@ in build", "%@ in build", "%@ in build"],
                         dailyRecap: "Riepilogo giornaliero",
                         dailyRecapCaption: "All’ora che scegli, un avviso riassume la tua giornata, una volta al giorno. La pagina Oggi lo mostra sempre.",
                         showAt: "Mostra alle",
                         weekdaysOnly: "Solo nei giorni feriali",
                         include: "Includi",
                         includeCaption: "Ogni parte compare solo se c’è qualcosa di oggi. Dalla rete non si legge nulla di nuovo, a parte una ricerca su GitHub dei commit di oggi tramite gh.",
                         sourceCoding: "Tempo di codice da WakaTime",
                         sourceDeploys: "Deploy su Vercel",
                         sourceGitHub: "Commit e pull request su GitHub",
                         sourceTerminal: "Comandi lunghi del terminale",
                         sourceImports: "Importazioni da scheda",
                         sourceExports: "Esportazioni completate",
                         sourceAgents: "Turni di Claude Code")
        case .ja:
            return .init(title: "今日",
                         summary: "コーディング時間、デプロイ、コミット、長いコマンド、カードの読み込み、書き出しから1日をまとめます。",
                         yourDay: "今日のまとめ",
                         open: "開く",
                         empty: "まだまとめるものがありません。コーディング時間、デプロイ、コミット、長いコマンド、読み込み、書き出しが1日の中でここに表示されます。",
                         copyText: "テキストでコピー",
                         copied: "コピーしました",
                         saveImage: "画像を保存",
                         saved: "ダウンロードに保存しました",
                         saveFailed: "画像を保存できませんでした",
                         shareHeading: "今日のまとめ · %@",
                         coding: "コーディング",
                         deploys: "デプロイ",
                         commitsLabel: "コミット",
                         pullRequests: "プルリクエスト",
                         commandsLabel: "長いコマンド",
                         photosLabel: "写真",
                         videosLabel: "ビデオ",
                         exportsLabel: "書き出し",
                         agentsLabel: "エージェントのターン",
                         codingHeadline: "コーディング %@",
                         deploysCount: ["デプロイ %@件", "デプロイ %@件", "デプロイ %@件"],
                         commitsCount: ["コミット %@件", "コミット %@件", "コミット %@件"],
                         commandsCount: ["長いコマンド %@件", "長いコマンド %@件", "長いコマンド %@件"],
                         exportsCount: ["書き出し %@件", "書き出し %@件", "書き出し %@件"],
                         turns: ["エージェント %@ターン", "エージェント %@ターン", "エージェント %@ターン"],
                         sessions: ["%@セッション", "%@セッション", "%@セッション"],
                         pullsOpened: ["PR %@件作成", "PR %@件作成", "PR %@件作成"],
                         reviewsWaiting: ["レビュー待ち %@件", "レビュー待ち %@件", "レビュー待ち %@件"],
                         checksFailing: ["失敗したチェック %@件", "失敗したチェック %@件", "失敗したチェック %@件"],
                         photos: ["写真 %@枚", "写真 %@枚", "写真 %@枚"],
                         videos: ["ビデオ %@本", "ビデオ %@本", "ビデオ %@本"],
                         ready: ["完了 %@", "完了 %@", "完了 %@"],
                         failed: ["失敗 %@", "失敗 %@", "失敗 %@"],
                         building: ["ビルド中 %@", "ビルド中 %@", "ビルド中 %@"],
                         dailyRecap: "1日のまとめ",
                         dailyRecapCaption: "選んだ時刻に、1日のまとめを通知で1日1回表示します。「今日」ページではいつでも見られます。",
                         showAt: "表示時刻",
                         weekdaysOnly: "平日のみ",
                         include: "含める項目",
                         includeCaption: "今日のデータがある項目だけを表示します。gh で今日のコミットを1回検索する以外、ネットワークから新しく読み込むものはありません。",
                         sourceCoding: "WakaTime のコーディング時間",
                         sourceDeploys: "Vercel のデプロイ",
                         sourceGitHub: "GitHub のコミットとプルリクエスト",
                         sourceTerminal: "ターミナルの長いコマンド",
                         sourceImports: "カードの読み込み",
                         sourceExports: "完了した書き出し",
                         sourceAgents: "Claude Code のターン")
        case .ko:
            return .init(title: "오늘",
                         summary: "코딩 시간, 배포, 커밋, 긴 명령, 카드 가져오기, 내보내기로 하루를 요약합니다.",
                         yourDay: "오늘 하루",
                         open: "열기",
                         empty: "아직 요약할 내용이 없습니다. 코딩 시간, 배포, 커밋, 긴 명령, 가져오기, 내보내기가 하루 동안 여기에 표시됩니다.",
                         copyText: "텍스트로 복사",
                         copied: "복사됨",
                         saveImage: "이미지 저장",
                         saved: "다운로드에 저장됨",
                         saveFailed: "이미지를 저장할 수 없음",
                         shareHeading: "나의 하루 · %@",
                         coding: "코딩",
                         deploys: "배포",
                         commitsLabel: "커밋",
                         pullRequests: "풀 리퀘스트",
                         commandsLabel: "긴 명령",
                         photosLabel: "사진",
                         videosLabel: "비디오",
                         exportsLabel: "내보내기",
                         agentsLabel: "에이전트 턴",
                         codingHeadline: "코딩 %@",
                         deploysCount: ["배포 %@개", "배포 %@개", "배포 %@개"],
                         commitsCount: ["커밋 %@개", "커밋 %@개", "커밋 %@개"],
                         commandsCount: ["긴 명령 %@개", "긴 명령 %@개", "긴 명령 %@개"],
                         exportsCount: ["내보내기 %@개", "내보내기 %@개", "내보내기 %@개"],
                         turns: ["에이전트 턴 %@회", "에이전트 턴 %@회", "에이전트 턴 %@회"],
                         sessions: ["세션 %@개", "세션 %@개", "세션 %@개"],
                         pullsOpened: ["PR %@개 생성", "PR %@개 생성", "PR %@개 생성"],
                         reviewsWaiting: ["리뷰 대기 %@개", "리뷰 대기 %@개", "리뷰 대기 %@개"],
                         checksFailing: ["실패한 검사 %@개", "실패한 검사 %@개", "실패한 검사 %@개"],
                         photos: ["사진 %@장", "사진 %@장", "사진 %@장"],
                         videos: ["비디오 %@개", "비디오 %@개", "비디오 %@개"],
                         ready: ["완료 %@", "완료 %@", "완료 %@"],
                         failed: ["실패 %@", "실패 %@", "실패 %@"],
                         building: ["빌드 중 %@", "빌드 중 %@", "빌드 중 %@"],
                         dailyRecap: "일일 요약",
                         dailyRecapCaption: "선택한 시간에 알림이 하루를 요약합니다. 하루에 한 번이며, 오늘 페이지에서는 언제든 볼 수 있습니다.",
                         showAt: "표시 시간",
                         weekdaysOnly: "평일만",
                         include: "포함",
                         includeCaption: "오늘 데이터가 있는 항목만 표시됩니다. gh로 오늘 커밋을 한 번 검색하는 것 외에는 네트워크에서 새로 읽는 것이 없습니다.",
                         sourceCoding: "WakaTime 코딩 시간",
                         sourceDeploys: "Vercel 배포",
                         sourceGitHub: "GitHub 커밋과 풀 리퀘스트",
                         sourceTerminal: "터미널의 긴 명령",
                         sourceImports: "카드 가져오기",
                         sourceExports: "완료된 내보내기",
                         sourceAgents: "Claude Code 턴")
        case .uk:
            return .init(title: "Сьогодні",
                         summary: "Підбиває підсумки дня: час за кодом, деплої, коміти, довгі команди, імпорт із карток та експорт.",
                         yourDay: "Ваш день",
                         open: "Відкрити",
                         empty: "Поки нема чого підсумовувати. Час за кодом, деплої, коміти, довгі команди, імпорт та експорт з’являться тут протягом дня.",
                         copyText: "Скопіювати текстом",
                         copied: "Скопійовано",
                         saveImage: "Зберегти зображення",
                         saved: "Збережено в Завантаження",
                         saveFailed: "Не вдалося зберегти зображення",
                         shareHeading: "Мій день · %@",
                         coding: "Код",
                         deploys: "Деплої",
                         commitsLabel: "Коміти",
                         pullRequests: "Пул-реквести",
                         commandsLabel: "Довгі команди",
                         photosLabel: "Фото",
                         videosLabel: "Відео",
                         exportsLabel: "Експорт",
                         agentsLabel: "Ходи агентів",
                         codingHeadline: "%@ за кодом",
                         deploysCount: ["%@ деплой", "%@ деплої", "%@ деплоїв"],
                         commitsCount: ["%@ коміт", "%@ коміти", "%@ комітів"],
                         commandsCount: ["%@ довга команда", "%@ довгі команди", "%@ довгих команд"],
                         exportsCount: ["%@ експорт", "%@ експорти", "%@ експортів"],
                         turns: ["%@ хід агента", "%@ ходи агента", "%@ ходів агента"],
                         sessions: ["%@ сесія", "%@ сесії", "%@ сесій"],
                         pullsOpened: ["%@ PR відкрито", "%@ PR відкрито", "%@ PR відкрито"],
                         reviewsWaiting: ["%@ рев’ю чекає", "%@ рев’ю чекають", "%@ рев’ю чекають"],
                         checksFailing: ["%@ перевірка не пройшла", "%@ перевірки не пройшли", "%@ перевірок не пройшли"],
                         photos: ["%@ фото", "%@ фото", "%@ фото"],
                         videos: ["%@ відео", "%@ відео", "%@ відео"],
                         ready: ["%@ готовий", "%@ готові", "%@ готових"],
                         failed: ["%@ з помилкою", "%@ з помилкою", "%@ з помилкою"],
                         building: ["%@ збирається", "%@ збираються", "%@ збираються"],
                         dailyRecap: "Підсумки дня",
                         dailyRecapCaption: "У вибраний час сповіщення підбиває підсумки дня, раз на день. На сторінці «Сьогодні» вони є завжди.",
                         showAt: "Показувати о",
                         weekdaysOnly: "Лише в будні",
                         include: "Включати",
                         includeCaption: "Кожна частина видна, лише якщо за сьогодні щось є. З мережі нічого нового не читається, крім одного пошуку сьогоднішніх комітів на GitHub через gh.",
                         sourceCoding: "Час за кодом із WakaTime",
                         sourceDeploys: "Деплої Vercel",
                         sourceGitHub: "Коміти й пул-реквести GitHub",
                         sourceTerminal: "Довгі команди в терміналі",
                         sourceImports: "Імпорт із карток",
                         sourceExports: "Готовий експорт",
                         sourceAgents: "Ходи Claude Code")
        case .zhHans:
            return .init(title: "今天",
                         summary: "用编码时长、部署、提交、长命令、存储卡导入和导出来总结你的一天。",
                         yourDay: "你的一天",
                         open: "打开",
                         empty: "还没有可总结的内容。编码时长、部署、提交、长命令、导入和导出会在一天中显示在这里。",
                         copyText: "复制为文本",
                         copied: "已复制",
                         saveImage: "存储图像",
                         saved: "已存储到下载",
                         saveFailed: "无法存储图像",
                         shareHeading: "我的一天 · %@",
                         coding: "编码",
                         deploys: "部署",
                         commitsLabel: "提交",
                         pullRequests: "拉取请求",
                         commandsLabel: "长命令",
                         photosLabel: "照片",
                         videosLabel: "视频",
                         exportsLabel: "导出",
                         agentsLabel: "智能体轮次",
                         codingHeadline: "编码 %@",
                         deploysCount: ["%@ 次部署", "%@ 次部署", "%@ 次部署"],
                         commitsCount: ["%@ 次提交", "%@ 次提交", "%@ 次提交"],
                         commandsCount: ["%@ 个长命令", "%@ 个长命令", "%@ 个长命令"],
                         exportsCount: ["%@ 个导出", "%@ 个导出", "%@ 个导出"],
                         turns: ["%@ 个智能体轮次", "%@ 个智能体轮次", "%@ 个智能体轮次"],
                         sessions: ["%@ 个会话", "%@ 个会话", "%@ 个会话"],
                         pullsOpened: ["新建 %@ 个 PR", "新建 %@ 个 PR", "新建 %@ 个 PR"],
                         reviewsWaiting: ["%@ 个待审查", "%@ 个待审查", "%@ 个待审查"],
                         checksFailing: ["%@ 项检查失败", "%@ 项检查失败", "%@ 项检查失败"],
                         photos: ["%@ 张照片", "%@ 张照片", "%@ 张照片"],
                         videos: ["%@ 个视频", "%@ 个视频", "%@ 个视频"],
                         ready: ["%@ 个就绪", "%@ 个就绪", "%@ 个就绪"],
                         failed: ["%@ 个失败", "%@ 个失败", "%@ 个失败"],
                         building: ["%@ 个构建中", "%@ 个构建中", "%@ 个构建中"],
                         dailyRecap: "每日总结",
                         dailyRecapCaption: "在你选择的时间，通知会总结你的一天，每天一次。“今天”页面随时可以查看。",
                         showAt: "显示时间",
                         weekdaysOnly: "仅工作日",
                         include: "包括",
                         includeCaption: "每项只在今天有内容时显示。除了通过 gh 在 GitHub 上搜索一次今天的提交，不会从网络读取新内容。",
                         sourceCoding: "WakaTime 编码时长",
                         sourceDeploys: "Vercel 部署",
                         sourceGitHub: "GitHub 提交和拉取请求",
                         sourceTerminal: "终端长命令",
                         sourceImports: "存储卡导入",
                         sourceExports: "完成的导出",
                         sourceAgents: "Claude Code 轮次")
        case .zhTW:
            return .init(title: "今天",
                         summary: "以編碼時間、部署、提交、長指令、記憶卡匯入與輸出總結你的一天。",
                         yourDay: "你的一天",
                         open: "打開",
                         empty: "還沒有可總結的內容。編碼時間、部署、提交、長指令、匯入與輸出會在一天中顯示在這裡。",
                         copyText: "拷貝為文字",
                         copied: "已拷貝",
                         saveImage: "儲存影像",
                         saved: "已儲存到下載項目",
                         saveFailed: "無法儲存影像",
                         shareHeading: "我的一天 · %@",
                         coding: "編碼",
                         deploys: "部署",
                         commitsLabel: "提交",
                         pullRequests: "拉取要求",
                         commandsLabel: "長指令",
                         photosLabel: "照片",
                         videosLabel: "影片",
                         exportsLabel: "輸出",
                         agentsLabel: "代理程式回合",
                         codingHeadline: "編碼 %@",
                         deploysCount: ["%@ 次部署", "%@ 次部署", "%@ 次部署"],
                         commitsCount: ["%@ 次提交", "%@ 次提交", "%@ 次提交"],
                         commandsCount: ["%@ 個長指令", "%@ 個長指令", "%@ 個長指令"],
                         exportsCount: ["%@ 個輸出", "%@ 個輸出", "%@ 個輸出"],
                         turns: ["%@ 個代理程式回合", "%@ 個代理程式回合", "%@ 個代理程式回合"],
                         sessions: ["%@ 個工作階段", "%@ 個工作階段", "%@ 個工作階段"],
                         pullsOpened: ["新開 %@ 個 PR", "新開 %@ 個 PR", "新開 %@ 個 PR"],
                         reviewsWaiting: ["%@ 個待審查", "%@ 個待審查", "%@ 個待審查"],
                         checksFailing: ["%@ 項檢查失敗", "%@ 項檢查失敗", "%@ 項檢查失敗"],
                         photos: ["%@ 張照片", "%@ 張照片", "%@ 張照片"],
                         videos: ["%@ 部影片", "%@ 部影片", "%@ 部影片"],
                         ready: ["%@ 個就緒", "%@ 個就緒", "%@ 個就緒"],
                         failed: ["%@ 個失敗", "%@ 個失敗", "%@ 個失敗"],
                         building: ["%@ 個建置中", "%@ 個建置中", "%@ 個建置中"],
                         dailyRecap: "每日總結",
                         dailyRecapCaption: "在你選擇的時間，通知會總結你的一天，每天一次。「今天」頁面隨時可以查看。",
                         showAt: "顯示時間",
                         weekdaysOnly: "僅限平日",
                         include: "包含",
                         includeCaption: "每一項只在今天有內容時顯示。除了透過 gh 在 GitHub 搜尋一次今天的提交，不會從網路讀取新內容。",
                         sourceCoding: "WakaTime 編碼時間",
                         sourceDeploys: "Vercel 部署",
                         sourceGitHub: "GitHub 提交與拉取要求",
                         sourceTerminal: "終端機長指令",
                         sourceImports: "記憶卡匯入",
                         sourceExports: "完成的輸出",
                         sourceAgents: "Claude Code 回合")
        case .zhHK:
            return .init(title: "今天",
                         summary: "以編碼時間、部署、提交、長指令、記憶卡匯入和輸出總結你的一天。",
                         yourDay: "你的一天",
                         open: "打開",
                         empty: "仍未有可總結的內容。編碼時間、部署、提交、長指令、匯入和輸出會在一天中顯示在這裡。",
                         copyText: "拷貝為文字",
                         copied: "已拷貝",
                         saveImage: "儲存影像",
                         saved: "已儲存至下載項目",
                         saveFailed: "無法儲存影像",
                         shareHeading: "我的一天 · %@",
                         coding: "編碼",
                         deploys: "部署",
                         commitsLabel: "提交",
                         pullRequests: "拉取要求",
                         commandsLabel: "長指令",
                         photosLabel: "照片",
                         videosLabel: "影片",
                         exportsLabel: "輸出",
                         agentsLabel: "代理程式回合",
                         codingHeadline: "編碼 %@",
                         deploysCount: ["%@ 次部署", "%@ 次部署", "%@ 次部署"],
                         commitsCount: ["%@ 次提交", "%@ 次提交", "%@ 次提交"],
                         commandsCount: ["%@ 個長指令", "%@ 個長指令", "%@ 個長指令"],
                         exportsCount: ["%@ 個輸出", "%@ 個輸出", "%@ 個輸出"],
                         turns: ["%@ 個代理程式回合", "%@ 個代理程式回合", "%@ 個代理程式回合"],
                         sessions: ["%@ 個工作階段", "%@ 個工作階段", "%@ 個工作階段"],
                         pullsOpened: ["新開 %@ 個 PR", "新開 %@ 個 PR", "新開 %@ 個 PR"],
                         reviewsWaiting: ["%@ 個待審查", "%@ 個待審查", "%@ 個待審查"],
                         checksFailing: ["%@ 項檢查失敗", "%@ 項檢查失敗", "%@ 項檢查失敗"],
                         photos: ["%@ 張照片", "%@ 張照片", "%@ 張照片"],
                         videos: ["%@ 部影片", "%@ 部影片", "%@ 部影片"],
                         ready: ["%@ 個就緒", "%@ 個就緒", "%@ 個就緒"],
                         failed: ["%@ 個失敗", "%@ 個失敗", "%@ 個失敗"],
                         building: ["%@ 個建置中", "%@ 個建置中", "%@ 個建置中"],
                         dailyRecap: "每日總結",
                         dailyRecapCaption: "在你選擇的時間，通知會總結你的一天，每日一次。「今天」頁面隨時可以查看。",
                         showAt: "顯示時間",
                         weekdaysOnly: "只限工作日",
                         include: "包含",
                         includeCaption: "每一項只在今天有內容時顯示。除了透過 gh 在 GitHub 搜尋一次今天的提交，不會從網絡讀取新內容。",
                         sourceCoding: "WakaTime 編碼時間",
                         sourceDeploys: "Vercel 部署",
                         sourceGitHub: "GitHub 提交和拉取要求",
                         sourceTerminal: "終端機長指令",
                         sourceImports: "記憶卡匯入",
                         sourceExports: "完成的輸出",
                         sourceAgents: "Claude Code 回合")
        }
    }
}

// MARK: - Sky

/// Zenith fork: prayer times and the golden hour (SkyService), in the island,
/// on the lock screen, on the home page and in Settings.
struct ZenithSkyStrings {
    /// The module, its page and its section in Settings.
    let title: String
    let summary: String
    let prayerTab: String
    let goldenTab: String
    /// Imsak, Fajr, Sunrise, Dhuhr, Asr, Maghrib and Isha, in that order,
    /// in this language. Indonesian names come from `Prayer.indonesianName`.
    let prayerNames: [String]
    /// "Time for Dhuhr", at the prayer's time.
    let timeFor: String
    let next: String
    let blueHour: String
    let morning: String
    let evening: String
    let tomorrow: String
    /// "Golden hour in 32 min" and "Golden hour · 18 min left".
    let goldenIn: String
    let goldenLeft: String
    let minutes: String
    let sun: String
    let noWindows: String
    let needsLocation: String
    let locationDenied: String
    let chooseCity: String
    let approximated: String
    // Settings.
    let calculation: String
    let method: String
    let asr: String
    let shafii: String
    let hanafi: String
    let adjustments: String
    let adjustmentsCaption: String
    let names: String
    let namesAutomatic: String
    let namesIndonesian: String
    let namesApp: String
    let location: String
    let sourceAutomatic: String
    let sourceCity: String
    let sourceCustom: String
    let latitude: String
    let longitude: String
    let automaticCaption: String
    let manualCaption: String
    let reminders: String
    let remindersCaption: String
    let prayerActivity: String
    let prayerActivityCaption: String
    let lead: String
    let sound: String
    let soundCaption: String
    let chooseSound: String
    let systemSound: String
    let goldenActivity: String
    let goldenActivityCaption: String
    let lockPrayer: String
    let lockGolden: String

    /// The prayer's name in this language.
    func name(_ prayer: Prayer, indonesian: Bool) -> String {
        indonesian ? prayer.indonesianName : prayerNames.indices.contains(prayer.index) ? prayerNames[prayer.index] : prayer.rawValue
    }

    /// "Waktunya Dzuhur" with Indonesian names, otherwise this language's own.
    func arrival(_ prayer: Prayer, indonesian: Bool) -> String {
        indonesian ? "Waktunya " + prayer.indonesianName : filling(timeFor, name(prayer, indonesian: false))
    }

    func minutes(_ count: Int) -> String { minutes.replacingOccurrences(of: "%d", with: "\(count)") }

    func filling(_ format: String, _ value: String) -> String { format.replacingOccurrences(of: "%@", with: value) }
}

extension ZenithStrings {
    static func sky(_ language: AppLanguage) -> ZenithSkyStrings {
        switch language {
        case .enUS:
            return .init(title: "Sky", summary: "Prayer times and the golden hour, worked out on this Mac.",
                         prayerTab: "Prayer times", goldenTab: "Golden hour",
                         prayerNames: ["Imsak", "Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"],
                         timeFor: "Time for %@", next: "Next", blueHour: "Blue hour", morning: "Morning", evening: "Evening",
                         tomorrow: "Tomorrow", goldenIn: "Golden hour in %@", goldenLeft: "Golden hour · %@ left", minutes: "%d min",
                         sun: "Sun", noWindows: "The sun stays out of the golden hour today.",
                         needsLocation: "Prayer times and the golden hour need your approximate location or a city.",
                         locationDenied: "Location access is off for Zenith. Choose a city or allow it in System Settings.",
                         chooseCity: "Choose a City", approximated: "Approximated for a high latitude",
                         calculation: "Calculation", method: "Method", asr: "Asr", shafii: "Shafi’i", hanafi: "Hanafi",
                         adjustments: "Adjustments", adjustmentsCaption: "Minutes added to or taken from each time, after the method’s own.",
                         names: "Prayer names", namesAutomatic: "Automatic", namesIndonesian: "Indonesian", namesApp: "App language",
                         location: "Location", sourceAutomatic: "Approximate", sourceCity: "City", sourceCustom: "Custom",
                         latitude: "Latitude", longitude: "Longitude",
                         automaticCaption: "Uses the weather’s approximate location, rounded to about a kilometer. The times are worked out on this Mac; nothing is sent.",
                         manualCaption: "The times are worked out on this Mac for this place, in the Mac’s time zone.",
                         reminders: "Reminders", remindersCaption: "Each prayer switched on gets the countdown and a notice at its time.",
                         prayerActivity: "Countdown in the closed island", prayerActivityCaption: "Shows the next prayer and the time left, then its arrival for two minutes.",
                         lead: "Starts", sound: "Sound at prayer time",
                         soundCaption: "A soft system sound, or an audio file of your own. No adhan recording is included.",
                         chooseSound: "Choose Sound File…", systemSound: "Use System Sound",
                         goldenActivity: "Golden hour in the closed island",
                         goldenActivityCaption: "Starts 30 minutes before the evening golden hour and counts down while it lasts.",
                         lockPrayer: "Next prayer", lockGolden: "Golden hour")
        case .ptBR:
            return .init(title: "Céu", summary: "Horários de oração e a hora dourada, calculados neste Mac.",
                         prayerTab: "Orações", goldenTab: "Hora dourada",
                         prayerNames: ["Imsak", "Fajr", "Nascer do sol", "Dhuhr", "Asr", "Maghrib", "Isha"],
                         timeFor: "Hora do %@", next: "Próxima", blueHour: "Hora azul", morning: "Manhã", evening: "Tarde",
                         tomorrow: "Amanhã", goldenIn: "Hora dourada em %@", goldenLeft: "Hora dourada · faltam %@", minutes: "%d min",
                         sun: "Sol", noWindows: "Hoje o sol não passa pela hora dourada.",
                         needsLocation: "Os horários de oração e a hora dourada precisam da sua localização aproximada ou de uma cidade.",
                         locationDenied: "O acesso à localização está desativado para o Zenith. Escolha uma cidade ou permita nos Ajustes do Sistema.",
                         chooseCity: "Escolher Cidade", approximated: "Aproximado para uma latitude alta",
                         calculation: "Cálculo", method: "Método", asr: "Asr", shafii: "Shafi’i", hanafi: "Hanafi",
                         adjustments: "Ajustes", adjustmentsCaption: "Minutos somados ou tirados de cada horário, depois dos do método.",
                         names: "Nomes das orações", namesAutomatic: "Automático", namesIndonesian: "Indonésio", namesApp: "Idioma do app",
                         location: "Localização", sourceAutomatic: "Aproximada", sourceCity: "Cidade", sourceCustom: "Personalizada",
                         latitude: "Latitude", longitude: "Longitude",
                         automaticCaption: "Usa a localização aproximada do clima, arredondada a cerca de um quilômetro. Os horários são calculados neste Mac; nada é enviado.",
                         manualCaption: "Os horários são calculados neste Mac para este lugar, no fuso horário do Mac.",
                         reminders: "Lembretes", remindersCaption: "Cada oração ativada ganha a contagem regressiva e um aviso no seu horário.",
                         prayerActivity: "Contagem na ilha fechada", prayerActivityCaption: "Mostra a próxima oração e o tempo que falta, depois a chegada por dois minutos.",
                         lead: "Começa", sound: "Som na hora da oração",
                         soundCaption: "Um som suave do sistema ou um arquivo de áudio seu. Nenhuma gravação de adhan é incluída.",
                         chooseSound: "Escolher Arquivo de Som…", systemSound: "Usar Som do Sistema",
                         goldenActivity: "Hora dourada na ilha fechada",
                         goldenActivityCaption: "Começa 30 minutos antes da hora dourada da tarde e faz a contagem enquanto ela dura.",
                         lockPrayer: "Próxima oração", lockGolden: "Hora dourada")
        case .tr:
            return .init(title: "Gökyüzü", summary: "Namaz vakitleri ve altın saat, bu Mac’te hesaplanır.",
                         prayerTab: "Namaz vakitleri", goldenTab: "Altın saat",
                         prayerNames: ["İmsak", "Sabah", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"],
                         timeFor: "%@ vakti", next: "Sıradaki", blueHour: "Mavi saat", morning: "Sabah", evening: "Akşam",
                         tomorrow: "Yarın", goldenIn: "Altın saate %@", goldenLeft: "Altın saat · %@ kaldı", minutes: "%d dk",
                         sun: "Güneş", noWindows: "Güneş bugün altın saate girmiyor.",
                         needsLocation: "Namaz vakitleri ve altın saat için yaklaşık konumun ya da bir şehir gerekir.",
                         locationDenied: "Zenith için konum erişimi kapalı. Bir şehir seç ya da Sistem Ayarları’ndan izin ver.",
                         chooseCity: "Şehir Seç", approximated: "Yüksek enlem için yaklaşık",
                         calculation: "Hesaplama", method: "Yöntem", asr: "İkindi", shafii: "Şafii", hanafi: "Hanefi",
                         adjustments: "Düzeltmeler", adjustmentsCaption: "Yöntemin kendi ayarlarından sonra her vakte eklenen ya da çıkarılan dakikalar.",
                         names: "Vakit adları", namesAutomatic: "Otomatik", namesIndonesian: "Endonezyaca", namesApp: "Uygulama dili",
                         location: "Konum", sourceAutomatic: "Yaklaşık", sourceCity: "Şehir", sourceCustom: "Özel",
                         latitude: "Enlem", longitude: "Boylam",
                         automaticCaption: "Hava durumunun yaklaşık konumunu kullanır, yaklaşık bir kilometreye yuvarlanır. Vakitler bu Mac’te hesaplanır; hiçbir şey gönderilmez.",
                         manualCaption: "Vakitler bu Mac’te bu yer için, Mac’in saat diliminde hesaplanır.",
                         reminders: "Hatırlatmalar", remindersCaption: "Açık olan her vakit geri sayımı ve vaktinde bir bildirimi alır.",
                         prayerActivity: "Kapalı adada geri sayım", prayerActivityCaption: "Sıradaki vakti ve kalan süreyi, sonra iki dakika boyunca vaktin girdiğini gösterir.",
                         lead: "Başlangıç", sound: "Vakitte ses",
                         soundCaption: "Yumuşak bir sistem sesi ya da kendi ses dosyan. Ezan kaydı eklenmez.",
                         chooseSound: "Ses Dosyası Seç…", systemSound: "Sistem Sesini Kullan",
                         goldenActivity: "Kapalı adada altın saat",
                         goldenActivityCaption: "Akşamki altın saatten 30 dakika önce başlar ve sürdüğü sürece geri sayar.",
                         lockPrayer: "Sıradaki vakit", lockGolden: "Altın saat")
        case .ru:
            return .init(title: "Небо", summary: "Время намаза и золотой час, рассчитанные на этом Mac.",
                         prayerTab: "Время намаза", goldenTab: "Золотой час",
                         prayerNames: ["Имсак", "Фаджр", "Восход", "Зухр", "Аср", "Магриб", "Иша"],
                         timeFor: "Время намаза: %@", next: "Далее", blueHour: "Синий час", morning: "Утро", evening: "Вечер",
                         tomorrow: "Завтра", goldenIn: "Золотой час через %@", goldenLeft: "Золотой час · осталось %@", minutes: "%d мин",
                         sun: "Солнце", noWindows: "Сегодня солнце не входит в золотой час.",
                         needsLocation: "Для времени намаза и золотого часа нужно приблизительное местоположение или город.",
                         locationDenied: "Доступ Zenith к геопозиции выключен. Выберите город или разрешите доступ в Системных настройках.",
                         chooseCity: "Выбрать город", approximated: "Приблизительно для высокой широты",
                         calculation: "Расчёт", method: "Метод", asr: "Аср", shafii: "Шафиитский", hanafi: "Ханафитский",
                         adjustments: "Поправки", adjustmentsCaption: "Минуты, добавленные к каждому времени или убранные из него после поправок метода.",
                         names: "Названия намазов", namesAutomatic: "Автоматически", namesIndonesian: "Индонезийские", namesApp: "Язык приложения",
                         location: "Место", sourceAutomatic: "Приблизительно", sourceCity: "Город", sourceCustom: "Вручную",
                         latitude: "Широта", longitude: "Долгота",
                         automaticCaption: "Использует приблизительную геопозицию погоды, округлённую примерно до километра. Время рассчитывается на этом Mac; ничего не отправляется.",
                         manualCaption: "Время рассчитывается на этом Mac для этого места, в часовом поясе Mac.",
                         reminders: "Напоминания", remindersCaption: "Каждый включённый намаз получает обратный отсчёт и уведомление в своё время.",
                         prayerActivity: "Отсчёт на закрытом острове", prayerActivityCaption: "Показывает следующий намаз и оставшееся время, затем его наступление в течение двух минут.",
                         lead: "Начало", sound: "Звук во время намаза",
                         soundCaption: "Мягкий системный звук или ваш аудиофайл. Записи азана нет.",
                         chooseSound: "Выбрать звуковой файл…", systemSound: "Системный звук",
                         goldenActivity: "Золотой час на закрытом острове",
                         goldenActivityCaption: "Начинается за 30 минут до вечернего золотого часа и ведёт отсчёт, пока он длится.",
                         lockPrayer: "Следующий намаз", lockGolden: "Золотой час")
        case .es:
            return .init(title: "Cielo", summary: "Horarios de oración y la hora dorada, calculados en este Mac.",
                         prayerTab: "Oraciones", goldenTab: "Hora dorada",
                         prayerNames: ["Imsak", "Fajr", "Amanecer", "Dhuhr", "Asr", "Magrib", "Isha"],
                         timeFor: "Hora de %@", next: "Siguiente", blueHour: "Hora azul", morning: "Mañana", evening: "Tarde",
                         tomorrow: "Mañana", goldenIn: "Hora dorada en %@", goldenLeft: "Hora dorada · quedan %@", minutes: "%d min",
                         sun: "Sol", noWindows: "Hoy el sol no pasa por la hora dorada.",
                         needsLocation: "Los horarios de oración y la hora dorada necesitan tu ubicación aproximada o una ciudad.",
                         locationDenied: "El acceso a la ubicación está desactivado para Zenith. Elige una ciudad o permítelo en Ajustes del Sistema.",
                         chooseCity: "Elegir Ciudad", approximated: "Aproximado para una latitud alta",
                         calculation: "Cálculo", method: "Método", asr: "Asr", shafii: "Shafi’i", hanafi: "Hanafi",
                         adjustments: "Ajustes", adjustmentsCaption: "Minutos sumados o restados a cada horario, después de los del método.",
                         names: "Nombres de las oraciones", namesAutomatic: "Automático", namesIndonesian: "Indonesio", namesApp: "Idioma de la app",
                         location: "Ubicación", sourceAutomatic: "Aproximada", sourceCity: "Ciudad", sourceCustom: "Personalizada",
                         latitude: "Latitud", longitude: "Longitud",
                         automaticCaption: "Usa la ubicación aproximada del tiempo, redondeada a un kilómetro más o menos. Los horarios se calculan en este Mac; no se envía nada.",
                         manualCaption: "Los horarios se calculan en este Mac para este lugar, en la zona horaria del Mac.",
                         reminders: "Recordatorios", remindersCaption: "Cada oración activada tiene su cuenta atrás y un aviso a su hora.",
                         prayerActivity: "Cuenta atrás en la isla cerrada", prayerActivityCaption: "Muestra la siguiente oración y el tiempo que falta, y después su llegada durante dos minutos.",
                         lead: "Empieza", sound: "Sonido a la hora de la oración",
                         soundCaption: "Un sonido suave del sistema o un archivo de audio tuyo. No se incluye ninguna grabación del adhan.",
                         chooseSound: "Elegir Archivo de Sonido…", systemSound: "Usar Sonido del Sistema",
                         goldenActivity: "Hora dorada en la isla cerrada",
                         goldenActivityCaption: "Empieza 30 minutos antes de la hora dorada de la tarde y cuenta atrás mientras dura.",
                         lockPrayer: "Siguiente oración", lockGolden: "Hora dorada")
        case .sk:
            return .init(title: "Obloha", summary: "Časy modlitieb a zlatá hodinka, vypočítané na tomto Macu.",
                         prayerTab: "Časy modlitieb", goldenTab: "Zlatá hodinka",
                         prayerNames: ["Imsák", "Fadžr", "Východ slnka", "Zuhr", "Asr", "Magrib", "Iša"],
                         timeFor: "Čas na %@", next: "Ďalšia", blueHour: "Modrá hodinka", morning: "Ráno", evening: "Večer",
                         tomorrow: "Zajtra", goldenIn: "Zlatá hodinka o %@", goldenLeft: "Zlatá hodinka · ešte %@", minutes: "%d min",
                         sun: "Slnko", noWindows: "Slnko sa dnes do zlatej hodinky nedostane.",
                         needsLocation: "Časy modlitieb a zlatá hodinka potrebujú vašu približnú polohu alebo mesto.",
                         locationDenied: "Prístup k polohe je pre Zenith vypnutý. Vyberte mesto alebo ho povoľte v Systémových nastaveniach.",
                         chooseCity: "Vybrať mesto", approximated: "Približne pre vysokú zemepisnú šírku",
                         calculation: "Výpočet", method: "Metóda", asr: "Asr", shafii: "Šáfiovská", hanafi: "Hanafíjska",
                         adjustments: "Úpravy", adjustmentsCaption: "Minúty pridané ku každému času alebo odobraté po úpravách metódy.",
                         names: "Názvy modlitieb", namesAutomatic: "Automaticky", namesIndonesian: "Indonézske", namesApp: "Jazyk aplikácie",
                         location: "Poloha", sourceAutomatic: "Približná", sourceCity: "Mesto", sourceCustom: "Vlastná",
                         latitude: "Zemepisná šírka", longitude: "Zemepisná dĺžka",
                         automaticCaption: "Používa približnú polohu počasia zaokrúhlenú asi na kilometer. Časy sa počítajú na tomto Macu; nič sa neodosiela.",
                         manualCaption: "Časy sa počítajú na tomto Macu pre toto miesto, v časovom pásme Macu.",
                         reminders: "Pripomienky", remindersCaption: "Každá zapnutá modlitba má odpočet a oznámenie v jej čase.",
                         prayerActivity: "Odpočet v zatvorenom ostrove", prayerActivityCaption: "Ukazuje ďalšiu modlitbu a zostávajúci čas, potom jej príchod počas dvoch minút.",
                         lead: "Začína", sound: "Zvuk v čase modlitby",
                         soundCaption: "Jemný systémový zvuk alebo váš vlastný zvukový súbor. Nahrávka azánu nie je súčasťou.",
                         chooseSound: "Vybrať zvukový súbor…", systemSound: "Použiť systémový zvuk",
                         goldenActivity: "Zlatá hodinka v zatvorenom ostrove",
                         goldenActivityCaption: "Začína 30 minút pred večernou zlatou hodinkou a odpočítava, kým trvá.",
                         lockPrayer: "Ďalšia modlitba", lockGolden: "Zlatá hodinka")
        case .de:
            return .init(title: "Himmel", summary: "Gebetszeiten und die goldene Stunde, berechnet auf diesem Mac.",
                         prayerTab: "Gebetszeiten", goldenTab: "Goldene Stunde",
                         prayerNames: ["Imsak", "Fadschr", "Sonnenaufgang", "Dhuhr", "Asr", "Maghrib", "Ischa"],
                         timeFor: "Zeit für %@", next: "Nächstes", blueHour: "Blaue Stunde", morning: "Morgens", evening: "Abends",
                         tomorrow: "Morgen", goldenIn: "Goldene Stunde in %@", goldenLeft: "Goldene Stunde · noch %@", minutes: "%d Min.",
                         sun: "Sonne", noWindows: "Die Sonne erreicht heute keine goldene Stunde.",
                         needsLocation: "Gebetszeiten und die goldene Stunde brauchen deinen ungefähren Standort oder eine Stadt.",
                         locationDenied: "Der Standortzugriff ist für Zenith aus. Wähle eine Stadt oder erlaube ihn in den Systemeinstellungen.",
                         chooseCity: "Stadt wählen", approximated: "Angenähert für einen hohen Breitengrad",
                         calculation: "Berechnung", method: "Methode", asr: "Asr", shafii: "Schafiitisch", hanafi: "Hanafitisch",
                         adjustments: "Korrekturen", adjustmentsCaption: "Minuten, die nach denen der Methode zu jeder Zeit hinzukommen oder abgezogen werden.",
                         names: "Gebetsnamen", namesAutomatic: "Automatisch", namesIndonesian: "Indonesisch", namesApp: "App-Sprache",
                         location: "Ort", sourceAutomatic: "Ungefähr", sourceCity: "Stadt", sourceCustom: "Eigener",
                         latitude: "Breitengrad", longitude: "Längengrad",
                         automaticCaption: "Nutzt den ungefähren Standort des Wetters, auf etwa einen Kilometer gerundet. Die Zeiten werden auf diesem Mac berechnet; nichts wird gesendet.",
                         manualCaption: "Die Zeiten werden auf diesem Mac für diesen Ort berechnet, in der Zeitzone des Mac.",
                         reminders: "Erinnerungen", remindersCaption: "Jedes eingeschaltete Gebet bekommt den Countdown und einen Hinweis zu seiner Zeit.",
                         prayerActivity: "Countdown in der geschlossenen Insel", prayerActivityCaption: "Zeigt das nächste Gebet und die verbleibende Zeit, danach zwei Minuten lang, dass es Zeit ist.",
                         lead: "Beginnt", sound: "Ton zur Gebetszeit",
                         soundCaption: "Ein sanfter Systemton oder eine eigene Audiodatei. Keine Adhan-Aufnahme enthalten.",
                         chooseSound: "Tondatei wählen …", systemSound: "Systemton verwenden",
                         goldenActivity: "Goldene Stunde in der geschlossenen Insel",
                         goldenActivityCaption: "Beginnt 30 Minuten vor der goldenen Stunde am Abend und zählt herunter, solange sie dauert.",
                         lockPrayer: "Nächstes Gebet", lockGolden: "Goldene Stunde")
        case .fr:
            return .init(title: "Ciel", summary: "Heures de prière et heure dorée, calculées sur ce Mac.",
                         prayerTab: "Heures de prière", goldenTab: "Heure dorée",
                         prayerNames: ["Imsak", "Fajr", "Lever du soleil", "Dhuhr", "Asr", "Maghrib", "Isha"],
                         timeFor: "C’est l’heure de %@", next: "Suivante", blueHour: "Heure bleue", morning: "Matin", evening: "Soir",
                         tomorrow: "Demain", goldenIn: "Heure dorée dans %@", goldenLeft: "Heure dorée · encore %@", minutes: "%d min",
                         sun: "Soleil", noWindows: "Le soleil n’atteint pas l’heure dorée aujourd’hui.",
                         needsLocation: "Les heures de prière et l’heure dorée ont besoin de votre position approximative ou d’une ville.",
                         locationDenied: "L’accès à la position est désactivé pour Zenith. Choisissez une ville ou autorisez-le dans Réglages Système.",
                         chooseCity: "Choisir une ville", approximated: "Approximé pour une latitude élevée",
                         calculation: "Calcul", method: "Méthode", asr: "Asr", shafii: "Chaféite", hanafi: "Hanafite",
                         adjustments: "Ajustements", adjustmentsCaption: "Minutes ajoutées à chaque heure ou retirées, après celles de la méthode.",
                         names: "Noms des prières", namesAutomatic: "Automatique", namesIndonesian: "Indonésien", namesApp: "Langue de l’app",
                         location: "Lieu", sourceAutomatic: "Approximative", sourceCity: "Ville", sourceCustom: "Personnalisée",
                         latitude: "Latitude", longitude: "Longitude",
                         automaticCaption: "Utilise la position approximative de la météo, arrondie à environ un kilomètre. Les heures sont calculées sur ce Mac ; rien n’est envoyé.",
                         manualCaption: "Les heures sont calculées sur ce Mac pour ce lieu, dans le fuseau horaire du Mac.",
                         reminders: "Rappels", remindersCaption: "Chaque prière activée a son compte à rebours et un avis à son heure.",
                         prayerActivity: "Compte à rebours dans l’île fermée", prayerActivityCaption: "Affiche la prière suivante et le temps restant, puis son arrivée pendant deux minutes.",
                         lead: "Commence", sound: "Son à l’heure de la prière",
                         soundCaption: "Un son système doux, ou votre propre fichier audio. Aucun enregistrement d’adhan n’est inclus.",
                         chooseSound: "Choisir un fichier son…", systemSound: "Utiliser le son système",
                         goldenActivity: "Heure dorée dans l’île fermée",
                         goldenActivityCaption: "Commence 30 minutes avant l’heure dorée du soir et décompte tant qu’elle dure.",
                         lockPrayer: "Prière suivante", lockGolden: "Heure dorée")
        case .it:
            return .init(title: "Cielo", summary: "Orari di preghiera e ora d’oro, calcolati su questo Mac.",
                         prayerTab: "Orari di preghiera", goldenTab: "Ora d’oro",
                         prayerNames: ["Imsak", "Fajr", "Alba", "Dhuhr", "Asr", "Maghrib", "Isha"],
                         timeFor: "È l’ora di %@", next: "Prossima", blueHour: "Ora blu", morning: "Mattina", evening: "Sera",
                         tomorrow: "Domani", goldenIn: "Ora d’oro tra %@", goldenLeft: "Ora d’oro · mancano %@", minutes: "%d min",
                         sun: "Sole", noWindows: "Oggi il sole non entra nell’ora d’oro.",
                         needsLocation: "Gli orari di preghiera e l’ora d’oro hanno bisogno della tua posizione approssimativa o di una città.",
                         locationDenied: "L’accesso alla posizione è disattivato per Zenith. Scegli una città o consentilo in Impostazioni di Sistema.",
                         chooseCity: "Scegli una città", approximated: "Approssimato per una latitudine alta",
                         calculation: "Calcolo", method: "Metodo", asr: "Asr", shafii: "Sciafeita", hanafi: "Hanafita",
                         adjustments: "Correzioni", adjustmentsCaption: "Minuti aggiunti o tolti a ogni orario, dopo quelli del metodo.",
                         names: "Nomi delle preghiere", namesAutomatic: "Automatico", namesIndonesian: "Indonesiano", namesApp: "Lingua dell’app",
                         location: "Luogo", sourceAutomatic: "Approssimativa", sourceCity: "Città", sourceCustom: "Personalizzata",
                         latitude: "Latitudine", longitude: "Longitudine",
                         automaticCaption: "Usa la posizione approssimativa del meteo, arrotondata a circa un chilometro. Gli orari sono calcolati su questo Mac; non viene inviato nulla.",
                         manualCaption: "Gli orari sono calcolati su questo Mac per questo luogo, nel fuso orario del Mac.",
                         reminders: "Promemoria", remindersCaption: "Ogni preghiera attivata ha il suo conto alla rovescia e un avviso al suo orario.",
                         prayerActivity: "Conto alla rovescia nell’isola chiusa", prayerActivityCaption: "Mostra la prossima preghiera e il tempo che manca, poi il suo arrivo per due minuti.",
                         lead: "Inizia", sound: "Suono all’ora della preghiera",
                         soundCaption: "Un suono di sistema delicato o un tuo file audio. Non è inclusa nessuna registrazione dell’adhan.",
                         chooseSound: "Scegli file audio…", systemSound: "Usa suono di sistema",
                         goldenActivity: "Ora d’oro nell’isola chiusa",
                         goldenActivityCaption: "Inizia 30 minuti prima dell’ora d’oro della sera e fa il conto alla rovescia finché dura.",
                         lockPrayer: "Prossima preghiera", lockGolden: "Ora d’oro")
        case .ja:
            return .init(title: "空", summary: "礼拝時刻とゴールデンアワーを、このMacで計算します。",
                         prayerTab: "礼拝時刻", goldenTab: "ゴールデンアワー",
                         prayerNames: ["イムサーク", "ファジュル", "日の出", "ズフル", "アスル", "マグリブ", "イシャー"],
                         timeFor: "%@の時刻です", next: "次", blueHour: "ブルーアワー", morning: "朝", evening: "夕方",
                         tomorrow: "明日", goldenIn: "ゴールデンアワーまで%@", goldenLeft: "ゴールデンアワー · 残り%@", minutes: "%d分",
                         sun: "太陽", noWindows: "今日は太陽がゴールデンアワーの高さに入りません。",
                         needsLocation: "礼拝時刻とゴールデンアワーには、おおよその位置情報か都市が必要です。",
                         locationDenied: "Zenithの位置情報へのアクセスがオフです。都市を選ぶか、システム設定で許可してください。",
                         chooseCity: "都市を選択", approximated: "高緯度のため近似値",
                         calculation: "計算", method: "方式", asr: "アスル", shafii: "シャーフィイー派", hanafi: "ハナフィー派",
                         adjustments: "調整", adjustmentsCaption: "方式の調整のあとで、各時刻に足したり引いたりする分数です。",
                         names: "礼拝の名前", namesAutomatic: "自動", namesIndonesian: "インドネシア語", namesApp: "アプリの言語",
                         location: "場所", sourceAutomatic: "おおよその位置", sourceCity: "都市", sourceCustom: "カスタム",
                         latitude: "緯度", longitude: "経度",
                         automaticCaption: "天気と同じおおよその位置情報を約1キロメートル単位に丸めて使います。時刻はこのMacで計算され、何も送信されません。",
                         manualCaption: "時刻はこの場所についてこのMacで、Macのタイムゾーンで計算されます。",
                         reminders: "リマインダー", remindersCaption: "オンにした礼拝ごとに、カウントダウンと時刻の通知が出ます。",
                         prayerActivity: "閉じたアイランドのカウントダウン", prayerActivityCaption: "次の礼拝と残り時間を表示し、時刻になると2分間お知らせします。",
                         lead: "開始", sound: "礼拝時刻のサウンド",
                         soundCaption: "やさしいシステムサウンド、または自分のオーディオファイル。アザーンの録音は含まれません。",
                         chooseSound: "サウンドファイルを選択…", systemSound: "システムサウンドを使用",
                         goldenActivity: "閉じたアイランドのゴールデンアワー",
                         goldenActivityCaption: "夕方のゴールデンアワーの30分前に始まり、続くあいだカウントダウンします。",
                         lockPrayer: "次の礼拝", lockGolden: "ゴールデンアワー")
        case .ko:
            return .init(title: "하늘", summary: "기도 시간과 골든아워를 이 Mac에서 계산합니다.",
                         prayerTab: "기도 시간", goldenTab: "골든아워",
                         prayerNames: ["임삭", "파즈르", "일출", "주흐르", "아스르", "마그립", "이샤"],
                         timeFor: "%@ 시간입니다", next: "다음", blueHour: "블루아워", morning: "아침", evening: "저녁",
                         tomorrow: "내일", goldenIn: "골든아워까지 %@", goldenLeft: "골든아워 · %@ 남음", minutes: "%d분",
                         sun: "태양", noWindows: "오늘은 해가 골든아워 높이에 들지 않습니다.",
                         needsLocation: "기도 시간과 골든아워에는 대략적인 위치나 도시가 필요합니다.",
                         locationDenied: "Zenith의 위치 접근이 꺼져 있습니다. 도시를 선택하거나 시스템 설정에서 허용하세요.",
                         chooseCity: "도시 선택", approximated: "고위도라 근사값",
                         calculation: "계산", method: "방식", asr: "아스르", shafii: "샤피이", hanafi: "하나피",
                         adjustments: "조정", adjustmentsCaption: "방식 자체의 조정 뒤에 각 시간에 더하거나 빼는 분입니다.",
                         names: "기도 이름", namesAutomatic: "자동", namesIndonesian: "인도네시아어", namesApp: "앱 언어",
                         location: "위치", sourceAutomatic: "대략적인 위치", sourceCity: "도시", sourceCustom: "직접 입력",
                         latitude: "위도", longitude: "경도",
                         automaticCaption: "날씨와 같은 대략적인 위치를 약 1킬로미터로 반올림해 사용합니다. 시간은 이 Mac에서 계산되며 아무것도 전송되지 않습니다.",
                         manualCaption: "시간은 이 장소를 기준으로 이 Mac에서, Mac의 시간대로 계산됩니다.",
                         reminders: "알림", remindersCaption: "켠 기도마다 카운트다운과 그 시간의 알림이 표시됩니다.",
                         prayerActivity: "닫힌 아일랜드의 카운트다운", prayerActivityCaption: "다음 기도와 남은 시간을 보여 주고, 시간이 되면 2분 동안 알려 줍니다.",
                         lead: "시작", sound: "기도 시간 사운드",
                         soundCaption: "부드러운 시스템 사운드 또는 직접 고른 오디오 파일입니다. 아잔 녹음은 포함되지 않습니다.",
                         chooseSound: "사운드 파일 선택…", systemSound: "시스템 사운드 사용",
                         goldenActivity: "닫힌 아일랜드의 골든아워",
                         goldenActivityCaption: "저녁 골든아워 30분 전에 시작해 골든아워가 이어지는 동안 카운트다운합니다.",
                         lockPrayer: "다음 기도", lockGolden: "골든아워")
        case .uk:
            return .init(title: "Небо", summary: "Час молитви й золота година, обчислені на цьому Mac.",
                         prayerTab: "Час молитви", goldenTab: "Золота година",
                         prayerNames: ["Імсак", "Фаджр", "Схід сонця", "Зухр", "Аср", "Магриб", "Іша"],
                         timeFor: "Час молитви: %@", next: "Далі", blueHour: "Синя година", morning: "Ранок", evening: "Вечір",
                         tomorrow: "Завтра", goldenIn: "Золота година через %@", goldenLeft: "Золота година · лишилося %@", minutes: "%d хв",
                         sun: "Сонце", noWindows: "Сьогодні сонце не входить у золоту годину.",
                         needsLocation: "Для часу молитви й золотої години потрібне приблизне розташування або місто.",
                         locationDenied: "Доступ Zenith до геопозиції вимкнено. Виберіть місто або дозвольте доступ у Системних параметрах.",
                         chooseCity: "Вибрати місто", approximated: "Приблизно для високої широти",
                         calculation: "Обчислення", method: "Метод", asr: "Аср", shafii: "Шафіїтський", hanafi: "Ханафітський",
                         adjustments: "Поправки", adjustmentsCaption: "Хвилини, додані до кожного часу чи відняті від нього після поправок методу.",
                         names: "Назви молитов", namesAutomatic: "Автоматично", namesIndonesian: "Індонезійські", namesApp: "Мова застосунку",
                         location: "Місце", sourceAutomatic: "Приблизно", sourceCity: "Місто", sourceCustom: "Вручну",
                         latitude: "Широта", longitude: "Довгота",
                         automaticCaption: "Використовує приблизну геопозицію погоди, округлену приблизно до кілометра. Час обчислюється на цьому Mac; нічого не надсилається.",
                         manualCaption: "Час обчислюється на цьому Mac для цього місця, у часовому поясі Mac.",
                         reminders: "Нагадування", remindersCaption: "Кожна ввімкнена молитва має зворотний відлік і сповіщення у свій час.",
                         prayerActivity: "Відлік на закритому острові", prayerActivityCaption: "Показує наступну молитву й час, що лишився, а потім її настання протягом двох хвилин.",
                         lead: "Початок", sound: "Звук у час молитви",
                         soundCaption: "М’який системний звук або ваш аудіофайл. Запису азану немає.",
                         chooseSound: "Вибрати звуковий файл…", systemSound: "Системний звук",
                         goldenActivity: "Золота година на закритому острові",
                         goldenActivityCaption: "Починається за 30 хвилин до вечірньої золотої години й веде відлік, поки вона триває.",
                         lockPrayer: "Наступна молитва", lockGolden: "Золота година")
        case .zhHans:
            return .init(title: "天空", summary: "礼拜时间和黄金时刻，在这台 Mac 上计算。",
                         prayerTab: "礼拜时间", goldenTab: "黄金时刻",
                         prayerNames: ["封斋", "晨礼", "日出", "晌礼", "晡礼", "昏礼", "宵礼"],
                         timeFor: "%@时间到了", next: "下一个", blueHour: "蓝调时刻", morning: "早晨", evening: "傍晚",
                         tomorrow: "明天", goldenIn: "%@后进入黄金时刻", goldenLeft: "黄金时刻 · 还剩%@", minutes: "%d 分钟",
                         sun: "太阳", noWindows: "今天太阳不会进入黄金时刻。",
                         needsLocation: "礼拜时间和黄金时刻需要你的大致位置或一个城市。",
                         locationDenied: "Zenith 的位置访问已关闭。请选择一个城市，或在系统设置中允许。",
                         chooseCity: "选择城市", approximated: "高纬度近似值",
                         calculation: "计算", method: "方法", asr: "晡礼", shafii: "沙斐仪派", hanafi: "哈乃斐派",
                         adjustments: "调整", adjustmentsCaption: "在方法自身的调整之后，为每个时间加上或减去的分钟数。",
                         names: "礼拜名称", namesAutomatic: "自动", namesIndonesian: "印度尼西亚语", namesApp: "App 语言",
                         location: "位置", sourceAutomatic: "大致位置", sourceCity: "城市", sourceCustom: "自定",
                         latitude: "纬度", longitude: "经度",
                         automaticCaption: "使用天气的大致位置，取整到约一公里。时间在这台 Mac 上计算，不会发送任何内容。",
                         manualCaption: "时间按这个地点在这台 Mac 上计算，使用 Mac 的时区。",
                         reminders: "提醒", remindersCaption: "每个打开的礼拜都会显示倒计时，并在时间到时提示。",
                         prayerActivity: "收起的灵动岛中显示倒计时", prayerActivityCaption: "显示下一个礼拜和剩余时间，时间到后显示两分钟。",
                         lead: "开始于", sound: "礼拜时间的声音",
                         soundCaption: "柔和的系统声音，或你自己的音频文件。不附带任何宣礼录音。",
                         chooseSound: "选择声音文件…", systemSound: "使用系统声音",
                         goldenActivity: "收起的灵动岛中显示黄金时刻",
                         goldenActivityCaption: "在傍晚黄金时刻前 30 分钟开始，并在其持续期间倒计时。",
                         lockPrayer: "下一个礼拜", lockGolden: "黄金时刻")
        case .zhTW, .zhHK:
            return .init(title: "天空", summary: "禮拜時間和黃金時刻，在這台 Mac 上計算。",
                         prayerTab: "禮拜時間", goldenTab: "黃金時刻",
                         prayerNames: ["封齋", "晨禮", "日出", "晌禮", "晡禮", "昏禮", "宵禮"],
                         timeFor: "%@時間到了", next: "下一個", blueHour: "藍調時刻", morning: "早晨", evening: "傍晚",
                         tomorrow: "明天", goldenIn: "%@後進入黃金時刻", goldenLeft: "黃金時刻 · 還剩%@", minutes: "%d 分鐘",
                         sun: "太陽", noWindows: "今天太陽不會進入黃金時刻。",
                         needsLocation: "禮拜時間和黃金時刻需要你的大概位置或一個城市。",
                         locationDenied: "Zenith 的位置取用已關閉。請選擇一個城市，或在系統設定中允許。",
                         chooseCity: "選擇城市", approximated: "高緯度近似值",
                         calculation: "計算", method: "方法", asr: "晡禮", shafii: "沙斐儀派", hanafi: "哈乃斐派",
                         adjustments: "調整", adjustmentsCaption: "在方法本身的調整之後，為每個時間加上或減去的分鐘數。",
                         names: "禮拜名稱", namesAutomatic: "自動", namesIndonesian: "印尼語", namesApp: "App 語言",
                         location: "位置", sourceAutomatic: "大概位置", sourceCity: "城市", sourceCustom: "自訂",
                         latitude: "緯度", longitude: "經度",
                         automaticCaption: "使用天氣的大概位置，取整到約一公里。時間在這台 Mac 上計算，不會傳送任何內容。",
                         manualCaption: "時間依這個地點在這台 Mac 上計算，使用 Mac 的時區。",
                         reminders: "提醒", remindersCaption: "每個開啟的禮拜都會顯示倒數，並在時間到時提示。",
                         prayerActivity: "收起的動態島中顯示倒數", prayerActivityCaption: "顯示下一個禮拜和剩餘時間，時間到後顯示兩分鐘。",
                         lead: "開始於", sound: "禮拜時間的聲音",
                         soundCaption: "柔和的系統聲音，或你自己的音訊檔案。不附帶任何宣禮錄音。",
                         chooseSound: "選擇聲音檔案…", systemSound: "使用系統聲音",
                         goldenActivity: "收起的動態島中顯示黃金時刻",
                         goldenActivityCaption: "在傍晚黃金時刻前 30 分鐘開始，並在其持續期間倒數。",
                         lockPrayer: "下一個禮拜", lockGolden: "黃金時刻")
        }
    }
}
