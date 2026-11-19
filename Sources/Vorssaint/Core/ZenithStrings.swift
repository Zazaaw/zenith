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

// MARK: About, the maker (Zenith fork)

struct ZenithMakerStrings {
    let madeBy: String
    let role: String
    let bio: String
    let studioCaption: String
    let website: String
}

extension ZenithStrings {
    /// The About page’s “Made by” card.
    static func maker(_ language: AppLanguage) -> ZenithMakerStrings {
        switch language {
        case .enUS:
            return .init(madeBy: "Made by",
                         role: "Fullstack developer & designer",
                         bio: "I’m a fullstack developer and designer, an informatics engineer who codes, designs and shoots. I build web apps end to end, craft modern UI/UX and graphics, and produce video and photography. Living across engineering and design lets me take an idea from concept to a real, shipped product, Zenith included.",
                         studioCaption: "Creative studio from Sumatra, Indonesia. Photography, film, web and Mac apps.",
                         website: "Website")
        case .ptBR:
            return .init(madeBy: "Feito por",
                         role: "Desenvolvedor fullstack e designer",
                         bio: "Sou desenvolvedor fullstack e designer, um engenheiro de informática que programa, desenha e fotografa. Crio aplicações web de ponta a ponta, faço UI/UX e gráficos modernos, e produzo vídeo e fotografia. Viver entre engenharia e design me permite levar uma ideia do conceito a um produto real e lançado, inclusive o Zenith.",
                         studioCaption: "Estúdio criativo de Sumatra, Indonésia. Fotografia, filme, web e apps para Mac.",
                         website: "Site")
        case .tr:
            return .init(madeBy: "Yapımcı",
                         role: "Fullstack geliştirici ve tasarımcı",
                         bio: "Fullstack geliştirici ve tasarımcıyım; kod yazan, tasarlayan ve fotoğraf çeken bir bilişim mühendisi. Web uygulamalarını uçtan uca geliştiriyor, modern UI/UX ve grafikler tasarlıyor, video ve fotoğraf üretiyorum. Mühendislik ile tasarım arasında yaşamak, bir fikri kavramdan gerçek, yayınlanmış bir ürüne taşımamı sağlıyor; Zenith de bunlardan biri.",
                         studioCaption: "Sumatra, Endonezya’dan bir yaratıcı stüdyo. Fotoğraf, film, web ve Mac uygulamaları.",
                         website: "Web sitesi")
        case .ru:
            return .init(madeBy: "Автор",
                         role: "Fullstack-разработчик и дизайнер",
                         bio: "Я fullstack-разработчик и дизайнер, инженер-информатик, который пишет код, проектирует и снимает. Делаю веб-приложения от начала до конца, создаю современный UI/UX и графику, снимаю видео и фото. Работа на стыке инженерии и дизайна позволяет мне довести идею от концепции до настоящего выпущенного продукта, включая Zenith.",
                         studioCaption: "Креативная студия с Суматры, Индонезия. Фото, видео, веб и приложения для Mac.",
                         website: "Сайт")
        case .es:
            return .init(madeBy: "Hecho por",
                         role: "Desarrollador fullstack y diseñador",
                         bio: "Soy desarrollador fullstack y diseñador, un ingeniero informático que programa, diseña y fotografía. Creo aplicaciones web de principio a fin, diseño UI/UX y gráficos modernos, y produzco vídeo y fotografía. Moverme entre la ingeniería y el diseño me permite llevar una idea del concepto a un producto real y publicado, Zenith incluido.",
                         studioCaption: "Estudio creativo de Sumatra, Indonesia. Fotografía, cine, web y apps para Mac.",
                         website: "Sitio web")
        case .sk:
            return .init(madeBy: "Vytvoril",
                         role: "Fullstack vývojár a dizajnér",
                         bio: "Som fullstack vývojár a dizajnér, informatik, ktorý programuje, navrhuje a fotí. Tvorím webové aplikácie od začiatku do konca, navrhujem moderné UI/UX a grafiku a robím video a fotografiu. Život medzi inžinierstvom a dizajnom mi umožňuje dotiahnuť nápad od konceptu až po skutočný vydaný produkt, vrátane Zenithu.",
                         studioCaption: "Kreatívne štúdio zo Sumatry v Indonézii. Fotografia, film, web a aplikácie pre Mac.",
                         website: "Web")
        case .de:
            return .init(madeBy: "Gemacht von",
                         role: "Fullstack-Entwickler und Designer",
                         bio: "Ich bin Fullstack-Entwickler und Designer, ein Informatikingenieur, der programmiert, gestaltet und fotografiert. Ich baue Web-Apps von Anfang bis Ende, gestalte moderne UI/UX und Grafiken und produziere Video und Fotografie. Zwischen Technik und Design zu leben, lässt mich eine Idee vom Konzept bis zum echten, veröffentlichten Produkt bringen, Zenith eingeschlossen.",
                         studioCaption: "Kreativstudio aus Sumatra, Indonesien. Fotografie, Film, Web und Mac-Apps.",
                         website: "Website")
        case .fr:
            return .init(madeBy: "Créé par",
                         role: "Développeur fullstack et designer",
                         bio: "Je suis développeur fullstack et designer, un ingénieur en informatique qui code, conçoit et photographie. Je crée des applications web de bout en bout, je conçois des interfaces UI/UX et des visuels modernes, et je produis de la vidéo et de la photo. Vivre entre ingénierie et design me permet de mener une idée du concept à un vrai produit publié, Zenith compris.",
                         studioCaption: "Studio créatif de Sumatra, en Indonésie. Photo, film, web et apps Mac.",
                         website: "Site web")
        case .it:
            return .init(madeBy: "Creato da",
                         role: "Sviluppatore fullstack e designer",
                         bio: "Sono uno sviluppatore fullstack e designer, un ingegnere informatico che programma, progetta e fotografa. Realizzo app web dall’inizio alla fine, curo UI/UX e grafiche moderne e produco video e fotografia. Vivere tra ingegneria e design mi permette di portare un’idea dal concetto a un prodotto reale e pubblicato, Zenith compreso.",
                         studioCaption: "Studio creativo di Sumatra, Indonesia. Fotografia, video, web e app per Mac.",
                         website: "Sito web")
        case .ja:
            return .init(madeBy: "制作",
                         role: "フルスタック開発者・デザイナー",
                         bio: "フルスタック開発者でありデザイナー。コードを書き、デザインし、写真を撮る情報工学エンジニアです。Webアプリを最初から最後まで作り、モダンなUI/UXやグラフィックをデザインし、映像と写真も手がけています。エンジニアリングとデザインの両方にいることで、アイデアを構想から実際にリリースされるプロダクトまで形にできます。Zenithもそのひとつです。",
                         studioCaption: "インドネシア・スマトラ島のクリエイティブスタジオ。写真、映像、Web、Macアプリ。",
                         website: "Webサイト")
        case .ko:
            return .init(madeBy: "만든 사람",
                         role: "풀스택 개발자 겸 디자이너",
                         bio: "저는 풀스택 개발자이자 디자이너로, 코드를 쓰고 디자인하고 사진을 찍는 정보공학 엔지니어입니다. 웹 앱을 처음부터 끝까지 만들고, 현대적인 UI/UX와 그래픽을 디자인하며, 영상과 사진도 제작합니다. 엔지니어링과 디자인을 오가며 아이디어를 콘셉트에서 실제 출시된 제품까지 만들어 냅니다. Zenith도 그중 하나입니다.",
                         studioCaption: "인도네시아 수마트라의 크리에이티브 스튜디오. 사진, 영상, 웹, Mac 앱.",
                         website: "웹사이트")
        case .uk:
            return .init(madeBy: "Автор",
                         role: "Fullstack-розробник і дизайнер",
                         bio: "Я fullstack-розробник і дизайнер, інженер-інформатик, який пише код, проєктує й фотографує. Створюю вебзастосунки від початку до кінця, роблю сучасний UI/UX і графіку, знімаю відео та фото. Робота на межі інженерії та дизайну дає змогу довести ідею від концепції до справжнього випущеного продукту, зокрема Zenith.",
                         studioCaption: "Креативна студія із Суматри, Індонезія. Фото, відео, веб і застосунки для Mac.",
                         website: "Сайт")
        case .zhHans:
            return .init(madeBy: "制作者",
                         role: "全栈开发者与设计师",
                         bio: "我是一名全栈开发者和设计师，一个会写代码、做设计、也拍照的信息工程师。我从头到尾构建 Web 应用，设计现代的 UI/UX 与图形，也制作视频和摄影作品。游走于工程与设计之间，让我能把一个想法从概念变成真正发布的产品，Zenith 就是其中之一。",
                         studioCaption: "来自印度尼西亚苏门答腊的创意工作室。摄影、影片、网页与 Mac 应用。",
                         website: "网站")
        case .zhTW:
            return .init(madeBy: "製作者",
                         role: "全端開發者與設計師",
                         bio: "我是一名全端開發者和設計師，一個會寫程式、做設計、也拍照的資訊工程師。我從頭到尾打造網頁應用程式，設計現代的 UI/UX 與圖像，也製作影片和攝影作品。遊走於工程與設計之間，讓我能把一個想法從概念變成真正發布的產品，Zenith 就是其中之一。",
                         studioCaption: "來自印尼蘇門答臘的創意工作室。攝影、影片、網頁與 Mac App。",
                         website: "網站")
        case .zhHK:
            return .init(madeBy: "製作者",
                         role: "全端開發者及設計師",
                         bio: "我是一名全端開發者及設計師，一個會寫程式、做設計、也會拍照的資訊工程師。我由頭到尾打造網頁應用程式，設計現代的 UI/UX 及圖像，亦製作影片和攝影作品。遊走於工程與設計之間，令我能把一個想法由概念變成真正推出的產品，Zenith 就是其中之一。",
                         studioCaption: "來自印尼蘇門答臘的創意工作室。攝影、影片、網頁及 Mac App。",
                         website: "網站")
        }
    }
}
