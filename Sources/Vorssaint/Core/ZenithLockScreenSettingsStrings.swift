// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

// Zenith fork: the text of Settings → Lock Screen and the short labels of the
// lock screen's job rings. Kept apart from ZenithStrings.swift so the lock
// screen's own work and this page never touch the same lines.

struct ZenithLockScreenSettingsStrings {
    /// The section of what shows over the wallpaper.
    let overWallpaper: String
    let jobs: String
    let jobExport: String
    let jobCardImport: String
    let jobBackup: String
    let jobCommand: String
    let jobVercel: String
    let nowPlaying: String
    let lyrics: String
    let karaoke: String
    let titleControls: String
    let lyricsCaption: String
    /// The terminal readout's section.
    let terminal: String
    let placement: String
    let placementNormal: String
    let placementLow: String
    /// The full-screen lyrics' section.
    let fullSection: String
    let full: String
    let fullDisc: String
    let fullAccount: String
    let fullDevice: String
    let fullClock: String
    /// The full layer's background: a solid colour or the cover blurred.
    let background: String
    let backgroundSolid: String
    let backgroundBlurred: String
    /// Where the solid colour comes from.
    let color: String
    let colorFromCover: String
    let colorChoose: String
    let customColorCaption: String
    /// The blur's strength, and the words at the slider's ends.
    let blur: String
    let blurSoft: String
    let blurStrong: String
    let fullLoginHint: String
    let fullCaption: String
    /// Where the lock screen card was, on the Dynamic Island page.
    let movedCaption: String
    let open: String
    /// The rings' labels when nothing more specific is known.
    let labelExport: String
    let labelImport: String
    let labelBackup: String
    let labelCheck: String
}

extension ZenithStrings {
    static func lockScreenSettings(_ language: AppLanguage) -> ZenithLockScreenSettingsStrings {
        switch language {
        case .enUS:
            return .init(overWallpaper: "Over the wallpaper", jobs: "Job progress",
                         jobExport: "Exports, such as DaVinci Resolve", jobCardImport: "SD card import",
                         jobBackup: "Backups", jobCommand: "Long terminal commands", jobVercel: "Vercel deployments",
                         nowPlaying: "Now playing title", lyrics: "Lyrics", karaoke: "Karaoke highlight",
                         titleControls: "Tap the title for controls",
                         lyricsCaption: "Lyrics use the same lyrics source and consent as the Dynamic Island.",
                         terminal: "Terminal", placement: "Position", placementNormal: "Normal", placementLow: "Low",
                         fullSection: "Full-screen lyrics", full: "Open full lyrics when the lyric is clicked",
                         fullDisc: "Record", fullAccount: "Account photo and name", fullDevice: "Device name",
                         fullClock: "Clock", background: "Background", backgroundSolid: "Solid color",
                         backgroundBlurred: "Blurred cover", color: "Color", colorFromCover: "From the cover",
                         colorChoose: "Choose",
                         customColorCaption: "The text color adjusts automatically for contrast.",
                         blur: "Blur", blurSoft: "Soft", blurStrong: "Strong",
                         fullLoginHint: "Login hint",
                         fullCaption: "Full-screen lyrics cover the clock and the login. Move the mouse, click or pause the music to come back; typing your password and Touch ID still work.",
                         movedCaption: "What shows over the wallpaper, the terminal readout and full-screen lyrics have a page of their own.",
                         open: "Open", labelExport: "Export", labelImport: "Import", labelBackup: "Backup",
                         labelCheck: "Check")
        case .ptBR:
            return .init(overWallpaper: "Sobre o papel de parede", jobs: "Progresso de tarefas",
                         jobExport: "Exportações, como o DaVinci Resolve", jobCardImport: "Importação de cartão SD",
                         jobBackup: "Backups", jobCommand: "Comandos longos do terminal", jobVercel: "Implantações da Vercel",
                         nowPlaying: "Título do que está tocando", lyrics: "Letra", karaoke: "Destaque de karaokê",
                         titleControls: "Toque no título para os controles",
                         lyricsCaption: "A letra usa a mesma fonte e o mesmo consentimento do Dynamic Island.",
                         terminal: "Terminal", placement: "Posição", placementNormal: "Normal", placementLow: "Baixa",
                         fullSection: "Letra em tela cheia", full: "Abrir a letra completa ao clicar na letra",
                         fullDisc: "Disco", fullAccount: "Foto e nome da conta", fullDevice: "Nome do dispositivo",
                         fullClock: "Relógio", background: "Fundo", backgroundSolid: "Cor sólida",
                         backgroundBlurred: "Capa desfocada", color: "Cor", colorFromCover: "Da capa",
                         colorChoose: "Escolher",
                         customColorCaption: "A cor do texto se ajusta sozinha para manter o contraste.",
                         blur: "Desfoque", blurSoft: "Suave", blurStrong: "Forte",
                         fullLoginHint: "Dica de login",
                         fullCaption: "A letra em tela cheia cobre o relógio e o login. Mova o mouse, clique ou pause a música para voltar; digitar a senha e o Touch ID continuam funcionando.",
                         movedCaption: "O que aparece sobre o papel de parede, a leitura de terminal e a letra em tela cheia têm uma página própria.",
                         open: "Abrir", labelExport: "Exportação", labelImport: "Importação", labelBackup: "Backup",
                         labelCheck: "Verificação")
        case .tr:
            return .init(overWallpaper: "Duvar kâğıdının üzerinde", jobs: "İş ilerlemesi",
                         jobExport: "DaVinci Resolve gibi dışa aktarmalar", jobCardImport: "SD kart içe aktarma",
                         jobBackup: "Yedeklemeler", jobCommand: "Uzun terminal komutları", jobVercel: "Vercel dağıtımları",
                         nowPlaying: "Çalan şarkının adı", lyrics: "Şarkı sözleri", karaoke: "Karaoke vurgusu",
                         titleControls: "Denetimler için başlığa dokun",
                         lyricsCaption: "Şarkı sözleri, Dynamic Island ile aynı kaynağı ve izni kullanır.",
                         terminal: "Terminal", placement: "Konum", placementNormal: "Normal", placementLow: "Alçak",
                         fullSection: "Tam ekran şarkı sözleri", full: "Söze tıklandığında tüm sözleri aç",
                         fullDisc: "Plak", fullAccount: "Hesap fotoğrafı ve adı", fullDevice: "Aygıt adı",
                         fullClock: "Saat", background: "Arka plan", backgroundSolid: "Düz renk",
                         backgroundBlurred: "Bulanık kapak", color: "Renk", colorFromCover: "Kapaktan",
                         colorChoose: "Seç",
                         customColorCaption: "Yazı rengi, karşıtlık için kendiliğinden ayarlanır.",
                         blur: "Bulanıklık", blurSoft: "Hafif", blurStrong: "Güçlü",
                         fullLoginHint: "Giriş ipucu",
                         fullCaption: "Tam ekran sözler saati ve girişi örter. Geri dönmek için fareyi oynat, tıkla veya müziği duraklat; parolayı yazmak ve Touch ID yine çalışır.",
                         movedCaption: "Duvar kâğıdının üzerinde görünenler, terminal görünümü ve tam ekran sözlerin artık kendi sayfası var.",
                         open: "Aç", labelExport: "Dışa aktarma", labelImport: "İçe aktarma", labelBackup: "Yedekleme",
                         labelCheck: "Denetim")
        case .ru:
            return .init(overWallpaper: "Поверх обоев", jobs: "Ход задач",
                         jobExport: "Экспорт, например из DaVinci Resolve", jobCardImport: "Импорт с SD-карты",
                         jobBackup: "Резервные копии", jobCommand: "Долгие команды терминала", jobVercel: "Развёртывания Vercel",
                         nowPlaying: "Название играющей песни", lyrics: "Текст песни", karaoke: "Подсветка как в караоке",
                         titleControls: "Нажатие на название открывает управление",
                         lyricsCaption: "Текст песни берётся из того же источника и с тем же согласием, что и в Dynamic Island.",
                         terminal: "Терминал", placement: "Положение", placementNormal: "Обычное", placementLow: "Низкое",
                         fullSection: "Текст песни на весь экран", full: "Открывать весь текст по нажатию на строку",
                         fullDisc: "Пластинка", fullAccount: "Фото и имя учётной записи", fullDevice: "Имя устройства",
                         fullClock: "Часы", background: "Фон", backgroundSolid: "Сплошной цвет",
                         backgroundBlurred: "Размытая обложка", color: "Цвет", colorFromCover: "Из обложки",
                         colorChoose: "Выбрать",
                         customColorCaption: "Цвет текста подстраивается сам ради контраста.",
                         blur: "Размытие", blurSoft: "Мягкое", blurStrong: "Сильное",
                         fullLoginHint: "Подсказка для входа",
                         fullCaption: "Текст на весь экран закрывает часы и вход. Чтобы вернуться, подвиньте мышь, нажмите или поставьте музыку на паузу; ввод пароля и Touch ID работают как обычно.",
                         movedCaption: "То, что показывается поверх обоев, терминальная сводка и текст на весь экран теперь на отдельной странице.",
                         open: "Открыть", labelExport: "Экспорт", labelImport: "Импорт", labelBackup: "Копия",
                         labelCheck: "Проверка")
        case .es:
            return .init(overWallpaper: "Sobre el fondo de pantalla", jobs: "Progreso de tareas",
                         jobExport: "Exportaciones, como DaVinci Resolve", jobCardImport: "Importación de tarjeta SD",
                         jobBackup: "Copias de seguridad", jobCommand: "Comandos largos de terminal", jobVercel: "Despliegues de Vercel",
                         nowPlaying: "Título de lo que suena", lyrics: "Letra", karaoke: "Resaltado de karaoke",
                         titleControls: "Toca el título para ver los controles",
                         lyricsCaption: "La letra usa la misma fuente y el mismo consentimiento que el Dynamic Island.",
                         terminal: "Terminal", placement: "Posición", placementNormal: "Normal", placementLow: "Baja",
                         fullSection: "Letra a pantalla completa", full: "Abrir la letra completa al hacer clic en la letra",
                         fullDisc: "Disco", fullAccount: "Foto y nombre de la cuenta", fullDevice: "Nombre del dispositivo",
                         fullClock: "Reloj", background: "Fondo", backgroundSolid: "Color sólido",
                         backgroundBlurred: "Portada desenfocada", color: "Color", colorFromCover: "De la portada",
                         colorChoose: "Elegir",
                         customColorCaption: "El color del texto se ajusta solo para mantener el contraste.",
                         blur: "Desenfoque", blurSoft: "Suave", blurStrong: "Intenso",
                         fullLoginHint: "Indicación de inicio de sesión",
                         fullCaption: "La letra a pantalla completa cubre el reloj y el inicio de sesión. Mueve el ratón, haz clic o pausa la música para volver; escribir la contraseña y Touch ID siguen funcionando.",
                         movedCaption: "Lo que aparece sobre el fondo de pantalla, la lectura de terminal y la letra a pantalla completa tienen su propia página.",
                         open: "Abrir", labelExport: "Exportación", labelImport: "Importación", labelBackup: "Copia",
                         labelCheck: "Comprobación")
        case .sk:
            return .init(overWallpaper: "Nad tapetou", jobs: "Priebeh úloh",
                         jobExport: "Exporty, napríklad z DaVinci Resolve", jobCardImport: "Import z SD karty",
                         jobBackup: "Zálohy", jobCommand: "Dlhé príkazy v termináli", jobVercel: "Nasadenia Vercel",
                         nowPlaying: "Názov prehrávanej skladby", lyrics: "Text piesne", karaoke: "Zvýraznenie ako pri karaoke",
                         titleControls: "Klepnutím na názov zobraziť ovládanie",
                         lyricsCaption: "Text piesne používa rovnaký zdroj a súhlas ako Dynamic Island.",
                         terminal: "Terminál", placement: "Poloha", placementNormal: "Normálna", placementLow: "Nízka",
                         fullSection: "Text piesne na celú obrazovku", full: "Po kliknutí na text otvoriť celý text",
                         fullDisc: "Platňa", fullAccount: "Fotka a meno účtu", fullDevice: "Názov zariadenia",
                         fullClock: "Hodiny", background: "Pozadie", backgroundSolid: "Jednofarebné",
                         backgroundBlurred: "Rozmazaný obal", color: "Farba", colorFromCover: "Z obalu",
                         colorChoose: "Vybrať",
                         customColorCaption: "Farba textu sa kvôli kontrastu prispôsobí sama.",
                         blur: "Rozmazanie", blurSoft: "Jemné", blurStrong: "Silné",
                         fullLoginHint: "Nápoveda k prihláseniu",
                         fullCaption: "Text na celú obrazovku zakryje hodiny aj prihlásenie. Na návrat pohnite myšou, kliknite alebo pozastavte hudbu; zadanie hesla a Touch ID fungujú ďalej.",
                         movedCaption: "Čo sa zobrazí nad tapetou, terminálový prehľad a text na celú obrazovku majú vlastnú stránku.",
                         open: "Otvoriť", labelExport: "Export", labelImport: "Import", labelBackup: "Záloha",
                         labelCheck: "Kontrola")
        case .de:
            return .init(overWallpaper: "Über dem Hintergrundbild", jobs: "Fortschritt von Aufgaben",
                         jobExport: "Exporte, etwa aus DaVinci Resolve", jobCardImport: "Import von SD-Karte",
                         jobBackup: "Backups", jobCommand: "Lange Terminal-Befehle", jobVercel: "Vercel-Deployments",
                         nowPlaying: "Titel der Wiedergabe", lyrics: "Liedtext", karaoke: "Karaoke-Hervorhebung",
                         titleControls: "Titel antippen für Steuerelemente",
                         lyricsCaption: "Liedtexte nutzen dieselbe Quelle und dieselbe Zustimmung wie die Dynamic Island.",
                         terminal: "Terminal", placement: "Position", placementNormal: "Normal", placementLow: "Tief",
                         fullSection: "Liedtext im Vollbild", full: "Beim Klick auf den Liedtext den ganzen Text öffnen",
                         fullDisc: "Schallplatte", fullAccount: "Foto und Name des Accounts", fullDevice: "Gerätename",
                         fullClock: "Uhr", background: "Hintergrund", backgroundSolid: "Einfarbig",
                         backgroundBlurred: "Unscharfes Cover", color: "Farbe", colorFromCover: "Vom Cover",
                         colorChoose: "Auswählen",
                         customColorCaption: "Die Textfarbe passt sich für den Kontrast automatisch an.",
                         blur: "Unschärfe", blurSoft: "Weich", blurStrong: "Stark",
                         fullLoginHint: "Anmeldehinweis",
                         fullCaption: "Der Liedtext im Vollbild verdeckt Uhr und Anmeldung. Zum Zurückkehren die Maus bewegen, klicken oder die Musik pausieren; Passworteingabe und Touch ID funktionieren weiterhin.",
                         movedCaption: "Was über dem Hintergrundbild erscheint, die Terminal-Anzeige und der Liedtext im Vollbild haben eine eigene Seite.",
                         open: "Öffnen", labelExport: "Export", labelImport: "Import", labelBackup: "Backup",
                         labelCheck: "Prüfung")
        case .fr:
            return .init(overWallpaper: "Sur le fond d’écran", jobs: "Progression des tâches",
                         jobExport: "Exports, comme DaVinci Resolve", jobCardImport: "Importation de carte SD",
                         jobBackup: "Sauvegardes", jobCommand: "Longues commandes du terminal", jobVercel: "Déploiements Vercel",
                         nowPlaying: "Titre en cours de lecture", lyrics: "Paroles", karaoke: "Surlignage karaoké",
                         titleControls: "Toucher le titre pour les commandes",
                         lyricsCaption: "Les paroles utilisent la même source et le même consentement que la Dynamic Island.",
                         terminal: "Terminal", placement: "Position", placementNormal: "Normale", placementLow: "Basse",
                         fullSection: "Paroles en plein écran", full: "Ouvrir toutes les paroles d’un clic sur les paroles",
                         fullDisc: "Disque", fullAccount: "Photo et nom du compte", fullDevice: "Nom de l’appareil",
                         fullClock: "Horloge", background: "Fond", backgroundSolid: "Couleur unie",
                         backgroundBlurred: "Pochette floutée", color: "Couleur", colorFromCover: "De la pochette",
                         colorChoose: "Choisir",
                         customColorCaption: "La couleur du texte s’adapte d’elle-même pour garder le contraste.",
                         blur: "Flou", blurSoft: "Léger", blurStrong: "Fort",
                         fullLoginHint: "Indication de connexion",
                         fullCaption: "Les paroles en plein écran couvrent l’horloge et la connexion. Bougez la souris, cliquez ou mettez la musique en pause pour revenir ; la saisie du mot de passe et Touch ID fonctionnent toujours.",
                         movedCaption: "Ce qui s’affiche sur le fond d’écran, l’affichage terminal et les paroles en plein écran ont leur propre page.",
                         open: "Ouvrir", labelExport: "Export", labelImport: "Import", labelBackup: "Sauvegarde",
                         labelCheck: "Vérification")
        case .it:
            return .init(overWallpaper: "Sopra lo sfondo", jobs: "Avanzamento delle attività",
                         jobExport: "Esportazioni, come DaVinci Resolve", jobCardImport: "Importazione da scheda SD",
                         jobBackup: "Backup", jobCommand: "Comandi lunghi del terminale", jobVercel: "Deployment di Vercel",
                         nowPlaying: "Titolo in riproduzione", lyrics: "Testo", karaoke: "Evidenziazione karaoke",
                         titleControls: "Tocca il titolo per i controlli",
                         lyricsCaption: "Il testo usa la stessa fonte e lo stesso consenso della Dynamic Island.",
                         terminal: "Terminale", placement: "Posizione", placementNormal: "Normale", placementLow: "Bassa",
                         fullSection: "Testo a schermo intero", full: "Apri il testo completo quando fai clic sul testo",
                         fullDisc: "Disco", fullAccount: "Foto e nome dell’account", fullDevice: "Nome del dispositivo",
                         fullClock: "Orologio", background: "Sfondo", backgroundSolid: "Tinta unita",
                         backgroundBlurred: "Copertina sfocata", color: "Colore", colorFromCover: "Dalla copertina",
                         colorChoose: "Scegli",
                         customColorCaption: "Il colore del testo si adatta da solo per il contrasto.",
                         blur: "Sfocatura", blurSoft: "Leggera", blurStrong: "Forte",
                         fullLoginHint: "Suggerimento di accesso",
                         fullCaption: "Il testo a schermo intero copre l’orologio e l’accesso. Muovi il mouse, fai clic o metti in pausa la musica per tornare; la password e Touch ID funzionano comunque.",
                         movedCaption: "Ciò che appare sopra lo sfondo, la lettura da terminale e il testo a schermo intero hanno una pagina propria.",
                         open: "Apri", labelExport: "Esportazione", labelImport: "Importazione", labelBackup: "Backup",
                         labelCheck: "Verifica")
        case .ja:
            return .init(overWallpaper: "壁紙の上", jobs: "ジョブの進行状況",
                         jobExport: "DaVinci Resolveなどの書き出し", jobCardImport: "SDカードの読み込み",
                         jobBackup: "バックアップ", jobCommand: "時間のかかるターミナルコマンド", jobVercel: "Vercelのデプロイ",
                         nowPlaying: "再生中のタイトル", lyrics: "歌詞", karaoke: "カラオケ風のハイライト",
                         titleControls: "タイトルをタップしてコントロールを表示",
                         lyricsCaption: "歌詞はDynamic Islandと同じ取得元と同意を使います。",
                         terminal: "ターミナル", placement: "位置", placementNormal: "標準", placementLow: "低め",
                         fullSection: "全画面の歌詞", full: "歌詞をクリックしたら全画面の歌詞を開く",
                         fullDisc: "レコード", fullAccount: "アカウントの写真と名前", fullDevice: "デバイス名",
                         fullClock: "時計", background: "背景", backgroundSolid: "単色",
                         backgroundBlurred: "ぼかしたカバー", color: "色", colorFromCover: "カバーから",
                         colorChoose: "選択",
                         customColorCaption: "文字の色はコントラストに合わせて自動で調整されます。",
                         blur: "ぼかし", blurSoft: "弱", blurStrong: "強",
                         fullLoginHint: "ログインのヒント",
                         fullCaption: "全画面の歌詞は時計とログインを覆います。マウスを動かす、クリックする、または音楽を一時停止すると戻ります。パスワード入力とTouch IDはそのまま使えます。",
                         movedCaption: "壁紙の上に表示するもの、ターミナル表示、全画面の歌詞は専用のページに移りました。",
                         open: "開く", labelExport: "書き出し", labelImport: "読み込み", labelBackup: "バックアップ",
                         labelCheck: "確認")
        case .ko:
            return .init(overWallpaper: "배경화면 위", jobs: "작업 진행 상황",
                         jobExport: "DaVinci Resolve 같은 내보내기", jobCardImport: "SD 카드 가져오기",
                         jobBackup: "백업", jobCommand: "오래 걸리는 터미널 명령", jobVercel: "Vercel 배포",
                         nowPlaying: "재생 중인 제목", lyrics: "가사", karaoke: "노래방 하이라이트",
                         titleControls: "제목을 탭하여 제어기 보기",
                         lyricsCaption: "가사는 Dynamic Island와 같은 출처와 동의를 사용합니다.",
                         terminal: "터미널", placement: "위치", placementNormal: "보통", placementLow: "낮게",
                         fullSection: "전체 화면 가사", full: "가사를 클릭하면 전체 가사 열기",
                         fullDisc: "레코드", fullAccount: "계정 사진 및 이름", fullDevice: "기기 이름",
                         fullClock: "시계", background: "배경", backgroundSolid: "단색",
                         backgroundBlurred: "흐린 커버", color: "색상", colorFromCover: "커버에서",
                         colorChoose: "선택",
                         customColorCaption: "텍스트 색상은 대비에 맞게 자동으로 조절됩니다.",
                         blur: "흐림", blurSoft: "약하게", blurStrong: "강하게",
                         fullLoginHint: "로그인 안내",
                         fullCaption: "전체 화면 가사는 시계와 로그인을 가립니다. 돌아가려면 마우스를 움직이거나 클릭하거나 음악을 일시 정지하세요. 암호 입력과 Touch ID는 계속 작동합니다.",
                         movedCaption: "배경화면 위에 보이는 항목, 터미널 표시, 전체 화면 가사는 별도의 페이지로 옮겨졌습니다.",
                         open: "열기", labelExport: "내보내기", labelImport: "가져오기", labelBackup: "백업",
                         labelCheck: "확인")
        case .uk:
            return .init(overWallpaper: "Поверх шпалер", jobs: "Перебіг завдань",
                         jobExport: "Експорт, наприклад із DaVinci Resolve", jobCardImport: "Імпорт з SD-картки",
                         jobBackup: "Резервні копії", jobCommand: "Довгі команди термінала", jobVercel: "Розгортання Vercel",
                         nowPlaying: "Назва пісні, що грає", lyrics: "Текст пісні", karaoke: "Підсвічування як у караоке",
                         titleControls: "Натискання на назву відкриває керування",
                         lyricsCaption: "Текст пісні береться з того самого джерела й з тією самою згодою, що й у Dynamic Island.",
                         terminal: "Термінал", placement: "Положення", placementNormal: "Звичайне", placementLow: "Низьке",
                         fullSection: "Текст пісні на весь екран", full: "Відкривати весь текст натисканням на рядок",
                         fullDisc: "Платівка", fullAccount: "Фото й ім’я облікового запису", fullDevice: "Назва пристрою",
                         fullClock: "Годинник", background: "Тло", backgroundSolid: "Суцільний колір",
                         backgroundBlurred: "Розмита обкладинка", color: "Колір", colorFromCover: "З обкладинки",
                         colorChoose: "Вибрати",
                         customColorCaption: "Колір тексту сам підлаштовується заради контрасту.",
                         blur: "Розмиття", blurSoft: "М’яке", blurStrong: "Сильне",
                         fullLoginHint: "Підказка для входу",
                         fullCaption: "Текст на весь екран закриває годинник і вхід. Щоб повернутися, поворушіть мишею, натисніть або призупиніть музику; введення пароля й Touch ID працюють як завжди.",
                         movedCaption: "Те, що показується поверх шпалер, термінальне зведення й текст на весь екран тепер на окремій сторінці.",
                         open: "Відкрити", labelExport: "Експорт", labelImport: "Імпорт", labelBackup: "Копія",
                         labelCheck: "Перевірка")
        case .zhHans:
            return .init(overWallpaper: "墙纸上方", jobs: "任务进度",
                         jobExport: "导出，例如 DaVinci Resolve", jobCardImport: "SD 卡导入",
                         jobBackup: "备份", jobCommand: "耗时较长的终端命令", jobVercel: "Vercel 部署",
                         nowPlaying: "正在播放的标题", lyrics: "歌词", karaoke: "卡拉 OK 高亮",
                         titleControls: "轻点标题显示控制",
                         lyricsCaption: "歌词使用与 Dynamic Island 相同的来源和许可。",
                         terminal: "终端", placement: "位置", placementNormal: "正常", placementLow: "偏低",
                         fullSection: "全屏歌词", full: "点按歌词时打开完整歌词",
                         fullDisc: "唱片", fullAccount: "账户照片和名称", fullDevice: "设备名称",
                         fullClock: "时钟", background: "背景", backgroundSolid: "纯色",
                         backgroundBlurred: "模糊封面", color: "颜色", colorFromCover: "取自封面",
                         colorChoose: "自选",
                         customColorCaption: "文字颜色会自动调整以保持对比度。",
                         blur: "模糊", blurSoft: "柔和", blurStrong: "强烈",
                         fullLoginHint: "登录提示",
                         fullCaption: "全屏歌词会遮住时钟和登录界面。移动鼠标、点按或暂停音乐即可返回；输入密码和触控 ID 仍可使用。",
                         movedCaption: "墙纸上方显示的内容、终端读数和全屏歌词现在有自己的页面。",
                         open: "打开", labelExport: "导出", labelImport: "导入", labelBackup: "备份",
                         labelCheck: "检查")
        case .zhTW:
            return .init(overWallpaper: "背景圖片上方", jobs: "工作進度",
                         jobExport: "輸出，例如 DaVinci Resolve", jobCardImport: "SD 卡匯入",
                         jobBackup: "備份", jobCommand: "耗時較長的終端機指令", jobVercel: "Vercel 部署",
                         nowPlaying: "正在播放的標題", lyrics: "歌詞", karaoke: "卡拉 OK 標示",
                         titleControls: "點一下標題顯示控制項",
                         lyricsCaption: "歌詞使用與 Dynamic Island 相同的來源和同意設定。",
                         terminal: "終端機", placement: "位置", placementNormal: "一般", placementLow: "偏低",
                         fullSection: "全螢幕歌詞", full: "按一下歌詞時打開完整歌詞",
                         fullDisc: "唱片", fullAccount: "帳號照片和名稱", fullDevice: "裝置名稱",
                         fullClock: "時鐘", background: "背景", backgroundSolid: "純色",
                         backgroundBlurred: "模糊封面", color: "顏色", colorFromCover: "取自封面",
                         colorChoose: "自選",
                         customColorCaption: "文字顏色會自動調整以維持對比。",
                         blur: "模糊", blurSoft: "柔和", blurStrong: "強烈",
                         fullLoginHint: "登入提示",
                         fullCaption: "全螢幕歌詞會蓋住時鐘和登入畫面。移動滑鼠、按一下或暫停音樂即可返回；輸入密碼和 Touch ID 仍可使用。",
                         movedCaption: "背景圖片上方顯示的內容、終端機讀數和全螢幕歌詞現在有自己的頁面。",
                         open: "打開", labelExport: "輸出", labelImport: "匯入", labelBackup: "備份",
                         labelCheck: "檢查")
        case .zhHK:
            return .init(overWallpaper: "背景圖片上方", jobs: "工作進度",
                         jobExport: "輸出，例如 DaVinci Resolve", jobCardImport: "SD 卡匯入",
                         jobBackup: "備份", jobCommand: "耗時較長的終端機指令", jobVercel: "Vercel 部署",
                         nowPlaying: "正在播放的標題", lyrics: "歌詞", karaoke: "卡拉 OK 標示",
                         titleControls: "點一下標題顯示控制項",
                         lyricsCaption: "歌詞使用與 Dynamic Island 相同的來源及同意設定。",
                         terminal: "終端機", placement: "位置", placementNormal: "一般", placementLow: "偏低",
                         fullSection: "全螢幕歌詞", full: "按一下歌詞時打開完整歌詞",
                         fullDisc: "唱片", fullAccount: "帳戶相片及名稱", fullDevice: "裝置名稱",
                         fullClock: "時鐘", background: "背景", backgroundSolid: "純色",
                         backgroundBlurred: "模糊封面", color: "顏色", colorFromCover: "取自封面",
                         colorChoose: "自選",
                         customColorCaption: "文字顏色會自動調整以保持對比。",
                         blur: "模糊", blurSoft: "柔和", blurStrong: "強烈",
                         fullLoginHint: "登入提示",
                         fullCaption: "全螢幕歌詞會蓋住時鐘及登入畫面。移動滑鼠、按一下或暫停音樂即可返回；輸入密碼及 Touch ID 仍可使用。",
                         movedCaption: "背景圖片上方顯示的內容、終端機讀數及全螢幕歌詞現在有自己的頁面。",
                         open: "打開", labelExport: "輸出", labelImport: "匯入", labelBackup: "備份",
                         labelCheck: "檢查")
        }
    }
}
