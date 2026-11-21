// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the text Settings → Lock Screen adds for its preview, its tabs
// and the lock screen v2's second round of switches. The page's earlier text
// stays in ZenithLockScreenSettingsStrings.swift.

struct ZenithLockScreenPageStrings {
    /// Under the page's title.
    let subtitle: String
    /// The preview card: its title, the two layers, and its two lines.
    let preview: String
    let previewMinimal: String
    let previewFull: String
    let previewWallpaper: String
    let previewClick: String
    /// The part the preview outlines; `{part}` is its name.
    let highlighted: String
    /// The tab of the song's title and lyrics.
    let tabMusic: String
    /// The card of the island's items over the wallpaper.
    let activityRow: String
    let activityRowCaption: String
    /// Under Job progress; the chips' short names follow.
    let jobsCaption: String
    let jobExport: String
    let jobCardImport: String
    let jobCommand: String
    /// The lock screen's own music switch (NotchLockScreenItem.music).
    let music: String
    let nowPlayingCaption: String
    /// The shade behind the title and lyrics.
    let lyricShade: String
    let lyricShadeCaption: String
    /// The lyric offset slider: its title, caption, ends and value; `{value}` is a signed number.
    let lyricTiming: String
    let lyricTimingCaption: String
    let earlier: String
    let later: String
    let seconds: String
    /// The minimal layer's title and lyrics, as the preview names them.
    let titleAndLyrics: String
    /// Under the full layer's switch.
    let fullOpenCaption: String
    /// Chips of the full layer.
    let fullDiscSpin: String
    let fullAccount: String
    /// The full layer's top right corner.
    let topRight: String
    let topRightCaption: String
    /// The full layer's background: its style and the cover colour's tone.
    let style: String
    let tone: String
    let toneVivid: String
    let toneMuted: String
}

extension ZenithLockScreenPageStrings {
    /// "Highlighted: Activity row", in this language's own punctuation.
    func highlighting(_ part: String) -> String {
        highlighted.replacingOccurrences(of: "{part}", with: part)
    }

    /// The lyric offset as the slider shows it: signed, to the tenth, in this
    /// language's unit, such as "+0.4 s", "−1.2 s" or "+3 s"; nothing moved reads "0 s".
    func offset(_ value: Double, locale: Locale) -> String {
        let range = ZenithLockScreenLyricOffset.range
        let tenths = (min(max(value.isFinite ? value : 0, range.lowerBound), range.upperBound) * 10).rounded()
        let number: String
        if tenths == 0 {
            number = 0.formatted(.number.locale(locale))
        } else {
            let magnitude = (abs(tenths) / 10).formatted(.number.precision(.fractionLength(0...1)).locale(locale))
            number = (tenths > 0 ? "+" : "\u{2212}") + magnitude
        }
        return seconds.replacingOccurrences(of: "{value}", with: number)
    }
}

extension ZenithStrings {
    static func lockScreenPage(_ language: AppLanguage) -> ZenithLockScreenPageStrings {
        switch language {
        case .enUS:
            return .init(subtitle: "What shows while your Mac is locked. Changes show in the preview right away.",
                         preview: "Preview", previewMinimal: "Minimal", previewFull: "Full",
                         previewWallpaper: "Drawn on this Mac’s own wallpaper, so it matches the device you are on.",
                         previewClick: "Click a part of the preview to open its settings.",
                         highlighted: "Highlighted: {part}", tabMusic: "Music & Lyrics", activityRow: "Activity row",
                         activityRowCaption: "Under the clock, beside the weather",
                         jobsCaption: "A ring for long jobs, at most two at a time", jobExport: "Exports",
                         jobCardImport: "SD import", jobCommand: "Commands", music: "Music on the lock screen",
                         nowPlayingCaption: "Title and artist under the activity row", lyricShade: "Lyric shade",
                         lyricShadeCaption: "A soft shade behind the title and lyrics, for light wallpapers",
                         lyricTiming: "Lyric timing",
                         lyricTimingCaption: "Move it when the lyrics run behind or ahead of the song.",
                         earlier: "Earlier", later: "Later", seconds: "{value} s", titleAndLyrics: "Title and lyrics",
                         fullOpenCaption: "Click the lyric to open it; the ⤡ button closes it",
                         fullDiscSpin: "Spin the record", fullAccount: "Photo & name", topRight: "Top right",
                         topRightCaption: "Beside the ⤡ button", style: "Style", tone: "Tone", toneVivid: "Vivid",
                         toneMuted: "Muted")
        case .ptBR:
            return .init(subtitle: "O que aparece enquanto o Mac está bloqueado. As mudanças aparecem na prévia na hora.",
                         preview: "Prévia", previewMinimal: "Mínimo", previewFull: "Completo",
                         previewWallpaper: "Desenhada sobre o próprio papel de parede deste Mac, para combinar com o dispositivo em que você está.",
                         previewClick: "Clique em uma parte da prévia para abrir os ajustes dela.",
                         highlighted: "Destacado: {part}", tabMusic: "Música e letra", activityRow: "Linha de atividades",
                         activityRowCaption: "Sob o relógio, ao lado do clima",
                         jobsCaption: "Um anel para tarefas longas, no máximo duas por vez", jobExport: "Exportações",
                         jobCardImport: "Importação SD", jobCommand: "Comandos", music: "Música na tela bloqueada",
                         nowPlayingCaption: "Título e artista sob a linha de atividades", lyricShade: "Sombra da letra",
                         lyricShadeCaption: "Uma sombra suave atrás do título e da letra, para papéis de parede claros",
                         lyricTiming: "Sincronia da letra",
                         lyricTimingCaption: "Ajuste quando a letra estiver atrasada ou adiantada em relação à música.",
                         earlier: "Antes", later: "Depois", seconds: "{value} s", titleAndLyrics: "Título e letra",
                         fullOpenCaption: "Clique na letra para abri-la; o botão ⤡ a fecha", fullDiscSpin: "Girar o disco",
                         fullAccount: "Foto e nome", topRight: "Canto superior direito",
                         topRightCaption: "Ao lado do botão ⤡", style: "Estilo", tone: "Tom", toneVivid: "Vivo",
                         toneMuted: "Suave")
        case .tr:
            return .init(subtitle: "Mac kilitliyken görünenler. Değişiklikler önizlemede hemen görünür.",
                         preview: "Önizleme", previewMinimal: "Sade", previewFull: "Tam",
                         previewWallpaper: "Bu Mac’in kendi duvar kâğıdı üzerine çizilir, böylece kullandığın aygıtla eşleşir.",
                         previewClick: "Ayarlarını açmak için önizlemenin bir bölümüne tıkla.",
                         highlighted: "Vurgulanan: {part}", tabMusic: "Müzik ve sözler", activityRow: "Etkinlik satırı",
                         activityRowCaption: "Saatin altında, hava durumunun yanında",
                         jobsCaption: "Uzun işler için bir halka, aynı anda en çok iki tane", jobExport: "Dışa aktarmalar",
                         jobCardImport: "SD içe aktarma", jobCommand: "Komutlar", music: "Kilit ekranında müzik",
                         nowPlayingCaption: "Etkinlik satırının altında şarkı adı ve sanatçı", lyricShade: "Söz gölgesi",
                         lyricShadeCaption: "Açık renkli duvar kâğıtları için başlığın ve sözlerin arkasında yumuşak bir gölge",
                         lyricTiming: "Söz zamanlaması",
                         lyricTimingCaption: "Sözler şarkının gerisinde ya da önünde kalırsa kaydır.", earlier: "Erken",
                         later: "Geç", seconds: "{value} sn", titleAndLyrics: "Başlık ve sözler",
                         fullOpenCaption: "Açmak için söze tıkla; ⤡ düğmesi kapatır", fullDiscSpin: "Plağı döndür",
                         fullAccount: "Fotoğraf ve ad", topRight: "Sağ üst", topRightCaption: "⤡ düğmesinin yanında",
                         style: "Stil", tone: "Ton", toneVivid: "Canlı", toneMuted: "Yumuşak")
        case .ru:
            return .init(subtitle: "Что видно, пока Mac заблокирован. Изменения сразу видны в превью.", preview: "Превью",
                         previewMinimal: "Минимально", previewFull: "Полностью",
                         previewWallpaper: "Нарисовано на собственных обоях этого Mac, чтобы совпадать с вашим устройством.",
                         previewClick: "Нажмите на часть превью, чтобы открыть её настройки.",
                         highlighted: "Выделено: {part}", tabMusic: "Музыка и текст", activityRow: "Строка активности",
                         activityRowCaption: "Под часами, рядом с погодой",
                         jobsCaption: "Кольцо для долгих задач, не больше двух сразу", jobExport: "Экспорт",
                         jobCardImport: "Импорт SD", jobCommand: "Команды", music: "Музыка на экране блокировки",
                         nowPlayingCaption: "Название и исполнитель под строкой активности",
                         lyricShade: "Тень под текстом",
                         lyricShadeCaption: "Мягкая тень за названием и текстом для светлых обоев",
                         lyricTiming: "Синхронизация текста",
                         lyricTimingCaption: "Сдвиньте, если текст отстаёт от песни или опережает её.", earlier: "Раньше",
                         later: "Позже", seconds: "{value} с", titleAndLyrics: "Название и текст",
                         fullOpenCaption: "Нажмите на строку, чтобы открыть; кнопка ⤡ закрывает",
                         fullDiscSpin: "Вращать пластинку", fullAccount: "Фото и имя", topRight: "Справа вверху",
                         topRightCaption: "Рядом с кнопкой ⤡", style: "Стиль", tone: "Тон", toneVivid: "Яркий",
                         toneMuted: "Приглушённый")
        case .es:
            return .init(subtitle: "Lo que aparece con el Mac bloqueado. Los cambios se ven en la vista previa al instante.",
                         preview: "Vista previa", previewMinimal: "Mínima", previewFull: "Completa",
                         previewWallpaper: "Dibujada sobre el propio fondo de pantalla de este Mac, para que coincida con el dispositivo que usas.",
                         previewClick: "Haz clic en una parte de la vista previa para abrir sus ajustes.",
                         highlighted: "Resaltado: {part}", tabMusic: "Música y letra", activityRow: "Fila de actividad",
                         activityRowCaption: "Bajo el reloj, junto al tiempo",
                         jobsCaption: "Un anillo para tareas largas, como máximo dos a la vez", jobExport: "Exportaciones",
                         jobCardImport: "Importación SD", jobCommand: "Comandos", music: "Música en la pantalla bloqueada",
                         nowPlayingCaption: "Título y artista bajo la fila de actividad", lyricShade: "Sombra de la letra",
                         lyricShadeCaption: "Una sombra suave tras el título y la letra, para fondos claros",
                         lyricTiming: "Sincronía de la letra",
                         lyricTimingCaption: "Muévela cuando la letra vaya atrasada o adelantada respecto a la canción.",
                         earlier: "Antes", later: "Después", seconds: "{value} s", titleAndLyrics: "Título y letra",
                         fullOpenCaption: "Haz clic en la letra para abrirla; el botón ⤡ la cierra",
                         fullDiscSpin: "Girar el disco", fullAccount: "Foto y nombre", topRight: "Arriba a la derecha",
                         topRightCaption: "Junto al botón ⤡", style: "Estilo", tone: "Tono", toneVivid: "Vivo",
                         toneMuted: "Apagado")
        case .sk:
            return .init(subtitle: "Čo sa zobrazí, keď je Mac zamknutý. Zmeny hneď uvidíte v náhľade.", preview: "Náhľad",
                         previewMinimal: "Minimálne", previewFull: "Celé",
                         previewWallpaper: "Kreslené na vlastnú tapetu tohto Macu, aby zodpovedalo zariadeniu, na ktorom ste.",
                         previewClick: "Kliknutím na časť náhľadu otvoríte jej nastavenia.",
                         highlighted: "Zvýraznené: {part}", tabMusic: "Hudba a text", activityRow: "Riadok aktivít",
                         activityRowCaption: "Pod hodinami, vedľa počasia",
                         jobsCaption: "Krúžok pre dlhé úlohy, najviac dva naraz", jobExport: "Exporty",
                         jobCardImport: "Import z SD", jobCommand: "Príkazy", music: "Hudba na zamknutej obrazovke",
                         nowPlayingCaption: "Názov a interpret pod riadkom aktivít", lyricShade: "Tieň pod textom",
                         lyricShadeCaption: "Jemný tieň za názvom a textom pre svetlé tapety",
                         lyricTiming: "Časovanie textu",
                         lyricTimingCaption: "Posuňte, keď text mešká za skladbou alebo ju predbieha.", earlier: "Skôr",
                         later: "Neskôr", seconds: "{value} s", titleAndLyrics: "Názov a text",
                         fullOpenCaption: "Kliknutím na text ho otvoríte; tlačidlo ⤡ ho zavrie",
                         fullDiscSpin: "Otáčať platňu", fullAccount: "Fotka a meno", topRight: "Vpravo hore",
                         topRightCaption: "Vedľa tlačidla ⤡", style: "Štýl", tone: "Tón", toneVivid: "Sýty",
                         toneMuted: "Tlmený")
        case .de:
            return .init(subtitle: "Was erscheint, solange der Mac gesperrt ist. Änderungen zeigt die Vorschau sofort.",
                         preview: "Vorschau", previewMinimal: "Minimal", previewFull: "Vollbild",
                         previewWallpaper: "Auf dem eigenen Hintergrundbild dieses Mac gezeichnet, passend zum verwendeten Gerät.",
                         previewClick: "Auf einen Teil der Vorschau klicken, um seine Einstellungen zu öffnen.",
                         highlighted: "Hervorgehoben: {part}", tabMusic: "Musik & Liedtext",
                         activityRow: "Aktivitätszeile", activityRowCaption: "Unter der Uhr, neben dem Wetter",
                         jobsCaption: "Ein Ring für lange Aufgaben, höchstens zwei gleichzeitig", jobExport: "Exporte",
                         jobCardImport: "SD-Import", jobCommand: "Befehle", music: "Musik auf dem Sperrbildschirm",
                         nowPlayingCaption: "Titel und Interpret unter der Aktivitätszeile",
                         lyricShade: "Schatten hinter dem Text",
                         lyricShadeCaption: "Ein weicher Schatten hinter Titel und Liedtext, für helle Hintergrundbilder",
                         lyricTiming: "Timing des Liedtexts",
                         lyricTimingCaption: "Verschieben, wenn der Liedtext dem Lied hinterherläuft oder vorauseilt.",
                         earlier: "Früher", later: "Später", seconds: "{value} s", titleAndLyrics: "Titel und Liedtext",
                         fullOpenCaption: "Zum Öffnen auf den Liedtext klicken; die Taste ⤡ schließt ihn",
                         fullDiscSpin: "Schallplatte drehen", fullAccount: "Foto & Name", topRight: "Oben rechts",
                         topRightCaption: "Neben der Taste ⤡", style: "Stil", tone: "Farbton", toneVivid: "Kräftig",
                         toneMuted: "Gedämpft")
        case .fr:
            return .init(subtitle: "Ce qui s’affiche quand le Mac est verrouillé. Les changements apparaissent tout de suite dans l’aperçu.",
                         preview: "Aperçu", previewMinimal: "Minimal", previewFull: "Plein écran",
                         previewWallpaper: "Dessiné sur le fond d’écran de ce Mac, pour correspondre à l’appareil que vous utilisez.",
                         previewClick: "Cliquez sur une partie de l’aperçu pour ouvrir ses réglages.",
                         highlighted: "En surbrillance : {part}", tabMusic: "Musique et paroles",
                         activityRow: "Ligne d’activité", activityRowCaption: "Sous l’horloge, à côté de la météo",
                         jobsCaption: "Un anneau pour les longues tâches, deux au plus à la fois", jobExport: "Exports",
                         jobCardImport: "Import SD", jobCommand: "Commandes", music: "Musique sur l’écran verrouillé",
                         nowPlayingCaption: "Titre et artiste sous la ligne d’activité", lyricShade: "Ombre des paroles",
                         lyricShadeCaption: "Une ombre douce derrière le titre et les paroles, pour les fonds clairs",
                         lyricTiming: "Synchronisation des paroles",
                         lyricTimingCaption: "Décalez-les quand les paroles sont en retard ou en avance sur la chanson.",
                         earlier: "Plus tôt", later: "Plus tard", seconds: "{value} s", titleAndLyrics: "Titre et paroles",
                         fullOpenCaption: "Cliquez sur les paroles pour les ouvrir ; le bouton ⤡ les ferme",
                         fullDiscSpin: "Faire tourner le disque", fullAccount: "Photo et nom",
                         topRight: "En haut à droite", topRightCaption: "À côté du bouton ⤡", style: "Style",
                         tone: "Teinte", toneVivid: "Vive", toneMuted: "Atténuée")
        case .it:
            return .init(subtitle: "Cosa appare mentre il Mac è bloccato. Le modifiche si vedono subito nell’anteprima.",
                         preview: "Anteprima", previewMinimal: "Minimale", previewFull: "Completa",
                         previewWallpaper: "Disegnata sullo sfondo di questo Mac, così corrisponde al dispositivo che stai usando.",
                         previewClick: "Fai clic su una parte dell’anteprima per aprirne le impostazioni.",
                         highlighted: "Evidenziato: {part}", tabMusic: "Musica e testo",
                         activityRow: "Riga delle attività", activityRowCaption: "Sotto l’orologio, accanto al meteo",
                         jobsCaption: "Un anello per le attività lunghe, al massimo due alla volta",
                         jobExport: "Esportazioni", jobCardImport: "Importazione SD", jobCommand: "Comandi",
                         music: "Musica nella schermata di blocco",
                         nowPlayingCaption: "Titolo e artista sotto la riga delle attività", lyricShade: "Ombra del testo",
                         lyricShadeCaption: "Un’ombra morbida dietro titolo e testo, per sfondi chiari",
                         lyricTiming: "Sincronia del testo",
                         lyricTimingCaption: "Spostalo quando il testo è in ritardo o in anticipo sulla canzone.",
                         earlier: "Prima", later: "Dopo", seconds: "{value} s", titleAndLyrics: "Titolo e testo",
                         fullOpenCaption: "Fai clic sul testo per aprirlo; il pulsante ⤡ lo chiude",
                         fullDiscSpin: "Fai girare il disco", fullAccount: "Foto e nome", topRight: "In alto a destra",
                         topRightCaption: "Accanto al pulsante ⤡", style: "Stile", tone: "Tonalità", toneVivid: "Vivace",
                         toneMuted: "Tenue")
        case .ja:
            return .init(subtitle: "Macのロック中に表示するもの。変更はすぐにプレビューに反映されます。", preview: "プレビュー", previewMinimal: "ミニマル",
                         previewFull: "全画面", previewWallpaper: "このMac自身の壁紙の上に描くので、使っているデバイスと同じ見た目になります。",
                         previewClick: "プレビューの一部をクリックすると、その設定が開きます。", highlighted: "ハイライト：{part}", tabMusic: "音楽と歌詞",
                         activityRow: "アクティビティの行", activityRowCaption: "時計の下、天気の横", jobsCaption: "時間のかかるジョブのリング。同時に最大2つ",
                         jobExport: "書き出し", jobCardImport: "SD読み込み", jobCommand: "コマンド", music: "ロック画面の音楽",
                         nowPlayingCaption: "アクティビティの行の下にタイトルとアーティスト", lyricShade: "歌詞の影",
                         lyricShadeCaption: "明るい壁紙向けに、タイトルと歌詞の後ろに柔らかい影", lyricTiming: "歌詞のタイミング",
                         lyricTimingCaption: "歌詞が曲より遅れたり先走ったりするときに調整します。", earlier: "早く", later: "遅く", seconds: "{value}秒",
                         titleAndLyrics: "タイトルと歌詞", fullOpenCaption: "歌詞をクリックすると開き、⤡ボタンで閉じます", fullDiscSpin: "レコードを回す",
                         fullAccount: "写真と名前", topRight: "右上", topRightCaption: "⤡ボタンの横", style: "スタイル", tone: "色調",
                         toneVivid: "鮮やか", toneMuted: "落ち着いた")
        case .ko:
            return .init(subtitle: "Mac이 잠겨 있는 동안 보이는 항목. 변경 사항은 미리보기에 바로 나타납니다.", preview: "미리보기", previewMinimal: "최소",
                         previewFull: "전체", previewWallpaper: "이 Mac의 배경화면 위에 그려지므로 사용 중인 기기와 똑같이 보입니다.",
                         previewClick: "미리보기의 한 부분을 클릭하면 해당 설정이 열립니다.", highlighted: "강조됨: {part}", tabMusic: "음악 및 가사",
                         activityRow: "활동 줄", activityRowCaption: "시계 아래, 날씨 옆", jobsCaption: "오래 걸리는 작업의 링, 한 번에 최대 두 개",
                         jobExport: "내보내기", jobCardImport: "SD 가져오기", jobCommand: "명령", music: "잠금 화면의 음악",
                         nowPlayingCaption: "활동 줄 아래의 제목과 아티스트", lyricShade: "가사 그림자",
                         lyricShadeCaption: "밝은 배경화면을 위해 제목과 가사 뒤에 부드러운 그림자", lyricTiming: "가사 타이밍",
                         lyricTimingCaption: "가사가 노래보다 늦거나 빠를 때 조절하세요.", earlier: "빠르게", later: "느리게", seconds: "{value}초",
                         titleAndLyrics: "제목과 가사", fullOpenCaption: "가사를 클릭하면 열리고 ⤡ 버튼으로 닫습니다", fullDiscSpin: "레코드 회전",
                         fullAccount: "사진 및 이름", topRight: "오른쪽 위", topRightCaption: "⤡ 버튼 옆", style: "스타일", tone: "톤",
                         toneVivid: "선명하게", toneMuted: "차분하게")
        case .uk:
            return .init(subtitle: "Що видно, поки Mac замкнено. Зміни одразу видно в попередньому перегляді.",
                         preview: "Перегляд", previewMinimal: "Мінімально", previewFull: "Повністю",
                         previewWallpaper: "Намальовано на власних шпалерах цього Mac, тож збігається з вашим пристроєм.",
                         previewClick: "Натисніть на частину перегляду, щоб відкрити її налаштування.",
                         highlighted: "Виділено: {part}", tabMusic: "Музика й текст", activityRow: "Рядок активності",
                         activityRowCaption: "Під годинником, поруч із погодою",
                         jobsCaption: "Кільце для довгих завдань, не більше двох одночасно", jobExport: "Експорт",
                         jobCardImport: "Імпорт SD", jobCommand: "Команди", music: "Музика на замкненому екрані",
                         nowPlayingCaption: "Назва й виконавець під рядком активності", lyricShade: "Тінь під текстом",
                         lyricShadeCaption: "М’яка тінь за назвою й текстом для світлих шпалер",
                         lyricTiming: "Синхронізація тексту",
                         lyricTimingCaption: "Зсуньте, коли текст відстає від пісні або випереджає її.", earlier: "Раніше",
                         later: "Пізніше", seconds: "{value} с", titleAndLyrics: "Назва й текст",
                         fullOpenCaption: "Натисніть на рядок, щоб відкрити; кнопка ⤡ закриває",
                         fullDiscSpin: "Обертати платівку", fullAccount: "Фото й ім’я", topRight: "Праворуч угорі",
                         topRightCaption: "Поруч із кнопкою ⤡", style: "Стиль", tone: "Тон", toneVivid: "Яскравий",
                         toneMuted: "Приглушений")
        case .zhHans:
            return .init(subtitle: "Mac 锁定时显示的内容。更改会立即显示在预览中。", preview: "预览", previewMinimal: "简洁", previewFull: "全屏",
                         previewWallpaper: "绘制在这台 Mac 自己的墙纸上，与你正在使用的设备一致。", previewClick: "点按预览中的某个部分即可打开它的设置。",
                         highlighted: "已高亮：{part}", tabMusic: "音乐与歌词", activityRow: "活动行", activityRowCaption: "时钟下方，天气旁边",
                         jobsCaption: "为耗时任务显示圆环，最多同时两个", jobExport: "导出", jobCardImport: "SD 导入", jobCommand: "命令",
                         music: "锁定屏幕上的音乐", nowPlayingCaption: "活动行下方的标题和艺人", lyricShade: "歌词阴影",
                         lyricShadeCaption: "在标题和歌词后加一层柔和阴影，适合浅色墙纸", lyricTiming: "歌词时间",
                         lyricTimingCaption: "歌词比歌曲慢或快时调整它。", earlier: "提前", later: "延后", seconds: "{value} 秒",
                         titleAndLyrics: "标题和歌词", fullOpenCaption: "点按歌词打开；⤡ 按钮关闭", fullDiscSpin: "转动唱片",
                         fullAccount: "照片和名称", topRight: "右上角", topRightCaption: "在 ⤡ 按钮旁边", style: "样式", tone: "色调",
                         toneVivid: "鲜艳", toneMuted: "柔和")
        case .zhTW:
            return .init(subtitle: "Mac 鎖定時顯示的內容。變更會立即顯示在預覽中。", preview: "預覽", previewMinimal: "簡潔", previewFull: "全螢幕",
                         previewWallpaper: "繪製在這台 Mac 自己的背景圖片上，與你正在使用的裝置一致。", previewClick: "按一下預覽中的某個部分即可打開它的設定。",
                         highlighted: "已標示：{part}", tabMusic: "音樂與歌詞", activityRow: "活動列", activityRowCaption: "時鐘下方，天氣旁邊",
                         jobsCaption: "為耗時工作顯示圓環，最多同時兩個", jobExport: "輸出", jobCardImport: "SD 匯入", jobCommand: "指令",
                         music: "鎖定畫面上的音樂", nowPlayingCaption: "活動列下方的標題和演出者", lyricShade: "歌詞陰影",
                         lyricShadeCaption: "在標題和歌詞後加上柔和陰影，適合淺色背景圖片", lyricTiming: "歌詞時間",
                         lyricTimingCaption: "歌詞比歌曲慢或快時調整它。", earlier: "提前", later: "延後", seconds: "{value} 秒",
                         titleAndLyrics: "標題和歌詞", fullOpenCaption: "按一下歌詞打開；⤡ 按鈕關閉", fullDiscSpin: "轉動唱片",
                         fullAccount: "照片和名稱", topRight: "右上角", topRightCaption: "在 ⤡ 按鈕旁邊", style: "樣式", tone: "色調",
                         toneVivid: "鮮豔", toneMuted: "柔和")
        case .zhHK:
            return .init(subtitle: "Mac 鎖定時顯示的內容。變更會即時顯示在預覽中。", preview: "預覽", previewMinimal: "簡潔", previewFull: "全螢幕",
                         previewWallpaper: "繪製在這部 Mac 自己的背景圖片上，與你正在使用的裝置一致。", previewClick: "按一下預覽中的某個部分即可打開它的設定。",
                         highlighted: "已標示：{part}", tabMusic: "音樂與歌詞", activityRow: "活動列", activityRowCaption: "時鐘下方，天氣旁邊",
                         jobsCaption: "為耗時工作顯示圓環，最多同時兩個", jobExport: "輸出", jobCardImport: "SD 匯入", jobCommand: "指令",
                         music: "鎖定畫面上的音樂", nowPlayingCaption: "活動列下方的標題及演出者", lyricShade: "歌詞陰影",
                         lyricShadeCaption: "在標題及歌詞後加上柔和陰影，適合淺色背景圖片", lyricTiming: "歌詞時間",
                         lyricTimingCaption: "歌詞比歌曲慢或快時調整它。", earlier: "提前", later: "延後", seconds: "{value} 秒",
                         titleAndLyrics: "標題及歌詞", fullOpenCaption: "按一下歌詞打開；⤡ 按鈕關閉", fullDiscSpin: "轉動唱片",
                         fullAccount: "相片及名稱", topRight: "右上角", topRightCaption: "在 ⤡ 按鈕旁邊", style: "樣式", tone: "色調",
                         toneVivid: "鮮豔", toneMuted: "柔和")
        }
    }
}
