// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
//
// Zenith fork: lays the island catalog's renders out as a PDF.
//
//   swift Tools/IslandCatalog/MakeCatalogPDF.swift <render folder> <pdf path> <commit>
//
// Reads manifest.json and the PNGs `--render-island-catalog` wrote, and the
// approved mockups in Tools/IslandCatalog/Planned. Run through render.sh.

import AppKit

// MARK: - Content

enum Layout { case pair, wide, screen, mockup, note }

struct Item {
    let id: String
    let title: String
    let what: String
    let when: String
    let setting: String
    var layout: Layout = .pair
    /// A display without a notch, whose island floats as a capsule in the menu bar.
    var capsuleDisplay = false
    var note: String? = nil
}

struct Section {
    let title: String
    let intro: String
    let items: [Item]
}

func pair(_ id: String, _ title: String, _ what: String, _ when: String, _ setting: String,
          capsule: Bool = false, note: String? = nil) -> Item {
    Item(id: id, title: title, what: what, when: when, setting: setting, layout: .pair, capsuleDisplay: capsule, note: note)
}

func wide(_ id: String, _ title: String, _ what: String, _ when: String, _ setting: String, note: String? = nil) -> Item {
    Item(id: id, title: title, what: what, when: when, setting: setting, layout: .wide, note: note)
}

func unrendered(_ title: String, _ what: String, _ when: String, _ setting: String, reason: String) -> Item {
    Item(id: "", title: title, what: what, when: when, setting: setting, layout: .note, note: reason)
}

let di = "Settings › Dynamic Island"

let sections: [Section] = [
    Section(title: "Closed & resting", intro: "Island waktu nggak ada yang jalan: cuma nutup kamera, atau istirahat sambil nunjukin satu hal kecil.", items: [
        pair("closed-idle", "Island diam", "Notch hitam polos, persis selebar kamera.", "Island nyala tapi nggak ada aktivitas, dan “At rest” diset Nothing.", "\(di) › tab Activity › At rest › Nothing"),
        pair("closed-mascot-star", "Maskot: bintang Satu Visual", "Companion default Zenith, bintang bermata yang nongkrong di sayap kiri.", "Companion nyala dan island lagi kosong.", "\(di) › tab Companion › Style"),
        pair("closed-mascot-minimal", "Maskot: Minimal", "Gaya companion yang lebih sederhana, di sini pakai palet Peach.", "Sama kayak di atas, gaya Minimal dipilih.", "\(di) › tab Companion › Style, Palette"),
        pair("closed-mascot-robot", "Maskot: Robot, di sisi kanan", "Companion gaya Robot yang duduk di sayap kanan.", "Companion nyala, sisi diset Right.", "\(di) › tab Companion › Style, Side"),
        pair("closed-battery", "Baterai saat istirahat", "Ikon baterai di kiri, persentase di kanan kamera.", "“At rest” diset Battery dan Mac pakai baterai internal.", "\(di) › tab Activity › At rest › Battery"),
        pair("closed-battery-charging", "Baterai lagi dicas", "Ikon baterai berubah jadi ada petirnya.", "At rest = Battery, adaptor tercolok.", "\(di) › tab Activity › At rest › Battery"),
        pair("closed-battery-early", "Peringatan awal (kuning)", "Angka dan ikon jadi kuning sebelum benar-benar lowbat.", "Baterai di bawah batas peringatan awal, nggak dicas.", "\(di) › tab Activity › At rest › Battery › Turn red when low (peringatan awal)"),
        pair("closed-battery-low", "Baterai lemah (merah)", "Angka dan ikon jadi merah.", "Baterai di bawah batas lowbat, nggak dicas.", "\(di) › tab Activity › At rest › Battery › Turn red when low"),
        pair("closed-capsule-battery", "Kapsul di layar tanpa notch", "Di monitor tanpa notch, island jadi kapsul yang melayang di menu bar.", "Island tampil di layar tanpa kamera, bentuk Capsule.", "\(di) › tab Layout › Displays without a notch › Capsule", capsule: true),
        unrendered("Sayap AI allowance", "“At rest” bisa nunjukin sisa jatah Claude/Codex di kedua sayap.", "At rest = AI allowance, dengan akun AI tersambung.", "\(di) › tab Activity › At rest", reason: "Butuh data limit akun asli (Claude/Codex) dan render-nya sengaja nggak baca log atau akun beneran, jadi sayapnya kosong."),
    ]),
    Section(title: "Compact activities", intro: "Strip kecil di kiri-kanan kamera selama ada yang berjalan. Kalau ada beberapa, hover buat milih.", items: [
        pair("compact-music", "Musik", "Cover lagu di kiri, equalizer di kanan.", "Ada lagu yang diputar dan “Show music while playing” nyala.", "\(di) › tab Layout › Show music while playing"),
        pair("compact-music-capsule", "Musik di kapsul", "Versi kapsul buat layar tanpa notch.", "Lagu diputar di layar tanpa notch.", "\(di) › tab Layout › Displays without a notch", capsule: true),
        pair("compact-timer", "Timer", "Ikon timer dan sisa menit.", "Timer atau Pomodoro lagi jalan.", "\(di) › tab Content › Timer"),
        pair("compact-timer-capsule", "Timer di kapsul", "Timer yang sama di kapsul.", "Timer jalan di layar tanpa notch.", "\(di) › tab Content › Timer", capsule: true),
        pair("compact-timer-downloads", "Gabungan: unduhan + timer", "Dua aktivitas berbagi satu strip.", "Dipilih lewat Combine di pemilih aktivitas.", "Hover island › Combine"),
        pair("compact-downloads", "Unduhan", "Progres unduhan, nama file dan persennya.", "Ada file yang sedang diunduh ke folder yang dipantau.", "\(di) › tab Content › Downloads"),
        pair("compact-agents", "AI agent bekerja", "Logo Claude dan lama sesi berjalan.", "Claude Code / Codex lagi ngerjain sesuatu.", "\(di) › tab Content › AI Agents › live activity"),
        pair("compact-agents-two", "Dua AI agent", "Dua agent sekaligus, ikonnya mengecil.", "Claude dan Codex jalan barengan.", "\(di) › tab Content › AI Agents"),
        pair("compact-claude-needs-you", "Claude butuh kamu", "Titik oranye dan “needs you · project”.", "Hook Claude Code nunggu izin atau jawaban.", "\(di) › tab Content › AI Agents › Claude Code hooks"),
        pair("compact-calendar", "Hitung mundur kalender", "Event berikutnya dan menit tersisa.", "Event masuk dalam jarak lead time.", "\(di) › tab Content › Calendar › countdown"),
        pair("compact-keep-awake", "Keep Awake", "Ikon kopi dan sisa waktu.", "Sesi Keep Awake aktif.", "\(di) › tab Activity › Keep Awake"),
        pair("compact-vercel-building", "Vercel: building", "Build Vercel yang sedang jalan.", "Ada deploy baru di project kamu.", "\(di) › tab Content › Vercel › Show builds in the closed island"),
        pair("compact-vercel-ready", "Vercel: ready", "Hasil build sukses, sebentar saja.", "Tepat setelah build selesai.", "\(di) › tab Content › Vercel"),
        pair("compact-vercel-failed", "Vercel: error", "Build gagal, tanda merah.", "Tepat setelah build gagal.", "\(di) › tab Content › Vercel"),
        pair("compact-command-running", "Perintah terminal berjalan", "Program, jumlah yang lain, dan jam jalannya.", "Perintah di terminal jalan lebih lama dari batasnya.", "\(di) › tab Content › Activity › terminal commands"),
        pair("compact-command-finished", "Perintah terminal selesai", "Centang dan durasi akhirnya.", "Sesaat setelah perintah panjang selesai.", "\(di) › tab Content › Activity › terminal commands"),
        pair("compact-card-import", "Import kartu kamera", "Persen, sisa file dan perkiraan waktu.", "Lagi nyalin kartu SD kamera.", "\(di) › tab Content › Card import"),
        pair("compact-card-import-done", "Import selesai", "Jumlah file dan ukuran total.", "Sesaat setelah import beres.", "\(di) › tab Content › Card import"),
        pair("compact-backup", "Backup kartu (verifikasi)", "Progres backup/cek hasil import.", "Backup atau verifikasi sedang jalan.", "\(di) › tab Content › Card import › Backup"),
        pair("compact-export", "Export tracker", "Ukuran file export yang terus tumbuh.", "DaVinci/Premiere/dll lagi export ke folder yang dipantau.", "\(di) › tab Content › Activity › Export tracker"),
        pair("compact-export-done", "Export selesai", "Centang, ukuran akhir dan durasi.", "Sesaat setelah export selesai.", "\(di) › tab Content › Activity › Export tracker"),
        pair("compact-dev-servers", "Dev servers", "Jumlah dev server yang jalan.", "Ada localhost (Next, Vite, dll) yang aktif.", "\(di) › tab Content › Dev servers › Show the count in the closed island"),
        pair("compact-prayer", "Waktu salat mendekat", "Hitung mundur ke salat berikutnya.", "Masuk lead time sebelum waktu salat.", "\(di) › tab Content › Sky › Prayer times"),
        pair("compact-prayer-arrived", "Waktunya salat (sesudah membesar)", "“Waktunya Ashar” dan jamnya, sampai 2 menit setelah waktunya.", "Setelah island adzan (Notices › “Adzan: pill membesar”) mengecil lagi.", "\(di) › tab Content › Sky › Prayer times"),
        pair("compact-golden-hour", "Golden hour", "“Golden hour in 20 min”.", "Golden hour sore mendekat atau sedang berlangsung.", "\(di) › tab Content › Sky › Golden hour in the closed island"),
        pair("compact-git", "Branch Git", "Nama branch dan titik oranye kalau ada perubahan.", "Repo aktif terdeteksi dari editor atau terminal.", "\(di) › tab Content › Git › Show the branch in the closed island"),
        pair("compact-picker", "Pemilih aktivitas", "Daftar aktivitas yang sedang jalan, plus Combine.", "Hover island waktu ada lebih dari satu aktivitas.", "Otomatis, nggak ada setelan"),
        pair("drop-hint", "Target drop", "“Drop files here” saat file diseret ke atas.", "Lagi drag file mendekati island.", "\(di) › tab Behavior › Show a drop target while dragging"),
        pair("drop-hint-mascot", "Target drop + maskot", "Companion ikut melirik file yang diseret.", "Sama, dengan companion nyala.", "\(di) › tab Behavior, tab Companion"),
        pair("capture-controls-collapsed", "Kontrol capture (ciut)", "Kontrol screenshot yang dikecilkan ke strip.", "Saat memilih area screenshot, kontrolnya diciutkan.", "\(di) › tab Behavior › Show screen capture controls in the Dynamic Island"),
        unrendered("Watch (pantau area layar)", "Strip kecil yang nunjukin potongan area layar yang dipantau.", "Saat Watch memantau area tertentu.", "\(di) › tab Content › Watch", reason: "Isinya potongan layar asli secara live. Render offscreen sengaja nggak boleh merekam layar, jadi strip ini dilewati."),
    ]),
    Section(title: "Expanded pages", intro: "Island waktu dibuka: satu halaman per section, baris atasnya membungkus kamera.", items: [
        wide("page-music", "Now Playing", "Pemutar musik: cover, judul, progress, kontrol dan output.", "Buka island lalu pilih Now Playing.", "\(di) › tab Content › Now Playing"),
        wide("page-timer", "Timer", "Timer besar dengan tombol pause dan tutup.", "Buka section Timer, apalagi saat timer jalan.", "\(di) › tab Content › Timer"),
        wide("page-calendar", "Calendar: Week", "Strip minggu ini plus event 7 hari ke depan, yang berikutnya diberi tanda. Baris lebih ringkas (nama kalender cukup dari warna batangnya) dan daftar memudar di tepi bawah, bisa di-scroll sampai event terakhir.", "Buka section Calendar (butuh izin Calendar), pilih Week.", "\(di) › tab Content › Calendar"),
        wide("page-calendar-month", "Calendar: Month", "Grid satu bulan di kiri: hari ini lingkaran merah, hari lewat redup, titik warna kalender (maks 3). Kanan: event hari yang dipilih. Klik hari untuk memilih, ‹ › ganti bulan, tombol today kembali ke hari ini.", "Pilih Month di segmented Week/Month; pilihan terakhir diingat.", "\(di) › tab Content › Calendar"),
        wide("page-downloads", "Downloads", "Unduhan terbaru dan progresnya.", "Buka section Downloads.", "\(di) › tab Content › Downloads"),
        wide("page-files", "Files (shelf)", "Rak file sementara: gambar, PDF, zip, link.", "Buka section Files atau drop file ke island.", "\(di) › tab Content › Files; Settings › Shelf"),
        wide("drop-zones", "Zona drop", "Saat drag, island menawarkan zona: Files, AirDrop, Optimize media.", "Drag file ke island.", "Settings › Shelf › Drop zones"),
        wide("page-clipboard", "Clipboard", "Riwayat clipboard dengan aksi QR, salin, pin, hapus.", "Buka section Clipboard (riwayat harus nyala).", "\(di) › tab Content › Clipboard"),
        wide("page-captures", "Recent captures", "Screenshot dan rekaman terakhir.", "Buka section Captures.", "\(di) › tab Content › Captures", note: "Sengaja ditampilkan kosong: isinya screenshot kamu sendiri."),
        wide("capture-controls", "Kontrol screen capture", "Pilih alat: screenshot, rekam layar, salin teks, color picker, scrolling.", "Saat memulai screen capture dari island.", "\(di) › tab Behavior › Show screen capture controls in the Dynamic Island"),
        wide("capture-controls-recording", "Kontrol rekam layar", "Mode rekam dengan pilihan suara Mac dan mikrofon.", "Pilih Screen recording.", "\(di) › tab Behavior"),
        wide("page-notifications", "Notifications", "Banner notifikasi terbaru, bisa dibuka atau ditutup.", "Buka section Notifications.", "\(di) › tab Content › Notifications"),
        wide("page-system", "System", "CPU, GPU, memori, baterai, jaringan, disk, daya, kipas.", "Buka section System.", "\(di) › tab Content › System", note: "Angka di sini dibaca langsung dari Mac ini saat render."),
        wide("page-tools", "Tools", "Peluncur alat cepat Zenith.", "Buka section Tools.", "\(di) › tab Content › Tools"),
        wide("page-mixer", "Volume mixer", "Volume per aplikasi dan output audio.", "Buka section Volume mixer.", "\(di) › tab Content › Volume mixer", note: "Kosong di catalog: mixer membaca aplikasi audio secara live, yang nggak dijalankan saat render."),
        wide("page-scratchpad", "Scratchpad", "Catatan cepat yang tersimpan sendiri.", "Buka section Scratchpad.", "\(di) › tab Content › Scratchpad", note: "Pakai gambar diam dari preview Settings, supaya file catatan kamu nggak dibuka."),
        wide("page-camera", "Camera mirror", "Cermin kamera di dalam island.", "Buka section Camera mirror.", "\(di) › tab Content › Camera mirror", note: "Kamera nggak pernah dinyalakan saat render, jadi ini gambar diam versi Settings."),
        wide("page-agents", "AI Agents", "Progress, Usage dan Stats untuk Claude/Codex.", "Buka section AI Agents.", "\(di) › tab Content › AI Agents"),
        wide("page-watch", "Watch", "Pilih bagian jendela yang mau dipantau island.", "Buka section Watch.", "\(di) › tab Content › Watch"),
        wide("page-wakatime", "WakaTime", "Waktu coding hari ini, project dan bahasa teratas.", "Buka section WakaTime (butuh API key).", "\(di) › tab Content › WakaTime"),
        wide("page-vercel", "Vercel", "Deployment terbaru per project dan statusnya.", "Buka section Vercel (butuh token).", "\(di) › tab Content › Vercel"),
        wide("page-github", "GitHub", "Review requested dan PR kamu, lengkap dengan status checks.", "Buka section GitHub (lewat gh CLI).", "\(di) › tab Content › GitHub"),
        wide("page-cardImport", "Card import", "Progres import kartu: persen, kecepatan, sisa waktu.", "Kartu kamera dicolok dan import berjalan.", "\(di) › tab Content › Card import"),
        wide("page-devServers", "Dev servers", "Daftar localhost yang jalan: buka, salin, matikan.", "Buka section Dev servers.", "\(di) › tab Content › Dev servers"),
        wide("page-recap", "Today (recap)", "Ringkasan hari ini dalam kartu-kartu.", "Buka section Today, atau dari notice recap.", "\(di) › tab Content › Today"),
        wide("page-sky", "Sky", "Jadwal salat hari ini dan golden hour.", "Buka section Sky.", "\(di) › tab Content › Sky"),
        wide("page-git", "Git", "Status repo: branch, staged, modified, commit terakhir.", "Buka section Git.", "\(di) › tab Content › Git"),
        wide("page-prompter", "Prompter", "Teleprompter: daftar script.", "Buka section Prompter.", "\(di) › tab Content › Prompter"),
    ]),
    Section(title: "Home & tab bar", intro: "Halaman utama island, pill tab di bawahnya, galeri section, dan Command Bar.", items: [
        wide("page-home", "Home", "Volume dan brightness di atas, lagu, lalu shortcut dan widget.", "Buka island (halaman default).", "\(di) › tab Content › Controls; klik kanan island › Customize Home", note: "Slider volume dan brightness tampil sebagai “Output…” dan “Settings…” karena audio dan layar sengaja nggak dibaca saat render."),
        wide("home-tab-bar", "Tab bar", "Pill di bawah island: Home, section yang di-pin, badge, dan galeri.", "Setiap island terbuka.", "\(di) › tab Layout › Tab bar"),
        wide("home-sections", "Explore (galeri section)", "Semua section dengan shortcut keyboard-nya.", "Klik ikon grid atau ⌘K.", "\(di) › tab Content › What appears"),
        pair("home-peek", "Peek", "Island setengah terbuka dengan nama section terakhir.", "Hover saat mode buka “preview”.", "\(di) › tab Behavior › hover"),
        wide("command-bar", "Command Bar di island", "Kolom perintah tumbuh dari island.", "Saat Command Bar dibuka dengan gaya island.", "\(di) › tab Companion › Command Bar in the island"),
        unrendered("Droplet Command Bar", "Animasi tetesan saat Command Bar keluar dari island.", "Sepersekian detik saat Command Bar dibuka.", "\(di) › tab Companion › Command Bar in the island", reason: "Ini animasi di jendelanya sendiri, bukan state diam. Satu frame nggak mewakili, jadi dilewati."),
    ]),
    Section(title: "Notices & alerts", intro: "Kabar singkat: notice kecil yang mengisi sayap island, dan kapsul Zenith yang tumbuh ke bawah.", items: [
        pair("notice-volume", "Volume", "Ikon speaker, persen, dan meter.", "Tombol volume ditekan.", "\(di) › tab Activity › More options › Volume"),
        pair("notice-brightness", "Brightness", "Matahari, persen, meter.", "Tombol brightness ditekan.", "\(di) › tab Activity › More options"),
        pair("notice-keyboard-light", "Lampu keyboard", "Level backlight keyboard.", "Tombol lampu keyboard ditekan.", "\(di) › tab Activity › More options"),
        pair("notice-battery", "Baterai (notice kecil)", "“Charging 54%”.", "Charger dicolok/dicabut, saat kapsul baterai mati.", "\(di) › tab Activity › Notices (mati = notice kecil)"),
        pair("notice-clipboard", "Disalin", "Konfirmasi ada yang dicopy.", "Copy sesuatu, dengan riwayat clipboard nyala.", "\(di) › tab Activity › Notify when something is copied"),
        pair("notice-download", "Unduhan selesai", "Nama file yang baru selesai.", "Unduhan beres, saat kapsul download mati.", "\(di) › tab Activity › More options"),
        pair("notice-timer", "Timer selesai", "“Timer finished”.", "Hitungan timer habis.", "\(di) › tab Content › Timer"),
        pair("notice-accessory", "Aksesori tersambung", "AirPods/aksesori Bluetooth tersambung.", "Perangkat Bluetooth terhubung.", "\(di) › tab Activity › More options"),
        pair("notice-agent-finished", "Agent selesai", "“Claude finished”, durasi dan biaya.", "Sesi AI agent selesai.", "\(di) › tab Content › AI Agents"),
        pair("notice-agent-limit", "Peringatan limit agent", "Jatah sesi hampir habis.", "Pemakaian melewati ambang.", "\(di) › tab Content › AI Agents"),
        pair("notice-track", "Lagu baru", "Judul dan artis lagu yang baru mulai.", "Lagu berganti.", "\(di) › tab Activity › More options › New track"),
        pair("notice-microphone", "Mikrofon mute", "Status mic mute/unmute.", "Shortcut mute mic dipakai.", "\(di) › tab Activity › More options"),
        pair("notice-input-source", "Input source", "Layout keyboard yang baru aktif.", "Ganti input source.", "\(di) › tab Activity › More options › Input source"),
        pair("notice-notification", "Banner notifikasi", "Notifikasi macOS di sayap island.", "Ada notifikasi baru.", "\(di) › tab Content › Notifications"),
        pair("notice-notification-open", "Notifikasi dibuka", "Banner yang membesar dengan isi lengkap.", "Klik banner notifikasi.", "\(di) › tab Content › Notifications; tab Layout › Reply", note: "Baris balasan (Reply) nggak ikut tergambar di render ini."),
        pair("burst-welcome", "“Welcome back, Faiz”", "Island desktop sendiri yang membesar: gembok hijau terbuka, salam, lama terkunci, foto akun di kanan; sekitar 3 detik lalu mengecil.", "Tepat setelah Mac dibuka kuncinya. Kalau island sedang terbuka, menunggu maksimal 5 detik lalu dibatalkan; tidak pernah menumpuk di atas halaman.", "Settings › Lock Screen › Over the wallpaper › Island › Welcome back"),
        pair("burst-remote-status", "“Faiz’s iPhone checked status”", "Island sendiri membesar ±2 detik: ikon iPhone, nama perangkat, “checked status”, ikon mata di kanan. Teks Inggris.", "Shortcut iPhone menjalankan `status` lewat SSH saat Mac tidak terkunci. Saat terkunci tidak muncul apa-apa.", "Settings › iPhone Remote"),
        pair("burst-welcome-remote", "Welcome back setelah dikunci dari iPhone", "Welcome back biasa, tapi barisnya “Locked from iPhone · 1h 20m ago”.", "Unlock pertama setelah Mac dikunci dari iPhone.", "Settings › iPhone Remote; Settings › Lock Screen › Over the wallpaper › Island › Welcome back"),
        pair("burst-claude", "“Claude needs you”", "Mark Claude, “Claude needs you” dan nama folder proyek, bersama bunyi Tink.", "Sesi Claude Code menunggu izin atau prompt. Maksimal sekali per sesi per 3 menit, dan sekali per 30 detik untuk semua sesi.", "\(di) › tab Content › AI Agents › Claude needs you"),
        pair("burst-prayer", "Adzan: pill membesar", "Pill salat sendiri yang membesar jadi satu island: tile simbol salat biru langit, “Waktunya Ashar”, jam · metode, “Next · Maghrib” di kanan, dan garis tipis yang menyusut selama tampil (8 detik). Lalu mengecil lagi ke pill. Tidak ada lapisan kedua di atas pill.", "Tepat waktu salat (yang diingatkan). Kalau island sedang terbuka, menunggu sampai ditutup, maksimal 2 menit.", "\(di) › tab Content › Sky › Prayer times"),
        pair("burst-prayer-capsule", "Adzan di layar tanpa notch", "Island adzan yang sama sebagai kapsul melayang.", "Tepat waktu salat, island di layar tanpa kamera.", "\(di) › tab Layout › Displays without a notch", capsule: true),
        pair("capsule-battery-low", "Kapsul: baterai 20%", "Baterai merah terisi sesuai level, persen besar, “Battery low” dan pil Low Power. Klik membuka pengaturan Battery untuk menyalakan Low Power Mode.", "Baterai turun ke batas Low battery, Low Power Mode mati.", "\(di) › tab Activity › Notices › Low battery"),
        pair("capsule-battery-critical", "Kapsul: baterai 10%, Low Power nyala", "Baterai amber, “Low Power Mode is on”, sisa waktu dari macOS, dan chip “✓ On”.", "Baterai turun ke batas Very low battery, Low Power Mode sudah nyala.", "\(di) › tab Activity › Notices › Very low battery"),
        pair("capsule-battery-critical-unknown", "Kapsul: baterai 9%, tanpa perkiraan", "Sama, tapi macOS belum punya perkiraan sisa waktu: cukup “Plug in soon”.", "Sesaat setelah dicabut, saat macOS masih menghitung.", "\(di) › tab Activity › Notices › Very low battery"),
        pair("burst-charging", "Island: mulai dicas", "Island sendiri yang membesar ±3 detik: baterai terisi sesuai level dengan petir, persen hijau, “Charging” dan “Full in 1h 10m” dari perkiraan macOS.", "Charger dicolok dan baterai mengisi.", "\(di) › tab Activity › Notices › Charger connected or removed"),
        pair("burst-charging-estimating", "Island: dicas, macOS masih menghitung", "Tanpa perkiraan waktu: “Power adapter connected”.", "Sesaat setelah dicolok, sebelum macOS punya perkiraan.", "\(di) › tab Activity › Notices › Charger connected or removed"),
        pair("burst-charge-limit", "Island: mencapai 80%", "Masih mengisi; saran mencabut charger di bawah “Charging”.", "Charge mencapai batas yang dipilih sambil terus mengisi.", "\(di) › tab Activity › Notices › Charge reaches"),
        pair("burst-charge-held", "Island: pengisian ditahan", "Amber: “On hold” dan “Optimized Battery Charging” (nama fitur macOS).", "Masih dicolok tapi pengisian berhenti sebelum penuh (Optimized Battery Charging atau charge limit), sekali per colokan; juga saat dicolok dalam keadaan ditahan.", "\(di) › tab Activity › Notices › Charger connected or removed"),
        pair("burst-unplugged", "Island: pakai baterai", "Sebentar (±2,6 detik): baterai tanpa petir, persen putih, “On Battery” dan sisa waktu dari macOS.", "Charger dicabut.", "\(di) › tab Activity › Notices › Charger connected or removed"),
        pair("burst-unplugged-low", "Island: dicabut saat tinggal sedikit", "Persen amber (≤ 20%, merah ≤ 10%); tanpa perkiraan: “Power adapter disconnected”.", "Charger dicabut saat baterai rendah.", "\(di) › tab Activity › Notices › Charger connected or removed"),
        pair("burst-charging-capsule", "Island: dicas di layar tanpa notch", "Versi kapsul melayang.", "Charger dicolok, island di layar tanpa kamera.", "\(di) › tab Layout › Displays without a notch", capsule: true),
        pair("capsule-audio", "Kapsul: headphone", "Nama headphone dan baterainya.", "Headphone tersambung.", "\(di) › tab Activity › Notices › Headphones connected"),
        pair("capsule-download", "Kapsul: unduhan selesai", "Thumbnail file, ukuran, folder.", "Unduhan selesai.", "\(di) › tab Activity › Notices › Download finished"),
        pair("capsule-card", "Kapsul: kartu dicolok", "Nama kartu dan tombol Import.", "Kartu kamera dimasukkan.", "\(di) › tab Content › Card import"),
        pair("capsule-card-backup", "Kapsul: belum di-backup", "Event yang belum di-backup dan tombol Back up.", "Pengingat backup atau drive backup dicolok.", "\(di) › tab Content › Card import › Backup"),
        pair("capsule-export", "Kapsul: export selesai", "Nama file export dan ukurannya.", "Export selesai.", "\(di) › tab Content › Activity › Export tracker"),
        pair("capsule-dev-server", "Kapsul: dev server jalan", "Framework, project, localhost, tombol Open.", "Dev server baru mulai.", "\(di) › tab Content › Dev servers"),
        pair("capsule-recap", "Kapsul: recap harian", "“Your day” dan angka terbesar hari ini.", "Pada jam recap yang dipilih.", "\(di) › tab Content › Today"),
        pair("capsule-workspace", "Kapsul: workspace siap", "Workspace yang baru dijalankan sudah siap.", "Workspace selesai dibuka.", "Settings › Workspaces"),
    ]),
    Section(title: "Lock screen", intro: "Island dan layer Zenith di lock screen (v2), digambar lewat preview Settings dengan wallpaper contoh.", items: [
        Item(id: "lock-minimal", title: "Lock screen: minimal", what: "Gembok di island, cuaca di bawah jam dengan job di kiri-kanannya (export DaVinci, import kartu), lagu dan lirik karaoke.", when: "Mac dikunci, mode Minimal.", setting: "Settings › Lock Screen › Minimal", layout: .screen, note: "Job tidak lagi menumpuk di atas cuaca: tiap job punya slot sendiri di samping baris."),
        Item(id: "lock-full", title: "Lock screen: full", what: "Layer penuh: piringan lagu, lirik besar, info di kanan atas.", when: "Mac dikunci, mode Full.", setting: "Settings › Lock Screen › Full", layout: .screen),
        wide("lock-island-rest", "Island gembok", "Gembok 17 pt di sayap kiri kamera, sisi kanan kosong.", "Mac dikunci, tidak ada lagu, charger, atau Focus.", "Settings › Lock Screen › Over the wallpaper › Island"),
        wide("lock-island-music", "Island gembok + musik", "Bar equalizer lagu di sayap kanan.", "Lagu diputar saat terkunci.", "Settings › Lock Screen › Music & Lyrics"),
        wide("lock-island-charging", "Island gembok: charging", "Petir + persen hijau (#34D399) di sayap kanan.", "Charger tercolok saat terkunci; 5 detik pertama menang atas Focus.", "Settings › Lock Screen › Over the wallpaper › Island › Charging"),
        wide("lock-island-focus", "Island gembok: Focus", "Bulan + nama Focus ungu (#A78BFA).", "Focus aktif (setelah 5 detik pertama colok charger).", "Settings › Lock Screen › Over the wallpaper › Island › Focus", note: "macOS tidak memberi cara tanpa izin untuk membaca Focus; render ini memakai data contoh, di app slot ini kosong sampai ada pembaca."),
        wide("lock-island-farewell", "“See you, Faiz 👋”", "Island melebar dengan gembok terbuka dan salam, sekitar 2,2 detik, lalu gembok menutup dan island menyusut.", "Mac dikunci di depan Mac.", "Settings › Lock Screen › Over the wallpaper › Island › See you"),
        wide("lock-island-remote", "“Locked from Faiz’s iPhone”", "Pengganti “See you”: island melebar dengan gembok, “Locked from Faiz’s iPhone” di atas “just now” dan ikon iPhone, sekitar 3 detik, lalu menyusut.", "Mac dikunci dari Shortcut iPhone (`lock`).", "Settings › iPhone Remote"),
        wide("lock-island-welcome", "Unlock: welcome di island gembok", "Welcome tumbuh di island gembok sendiri (di atas shield macOS), lalu island desktop mengambil alih di bentuk yang sama tanpa gerak.", "Mac dibuka; hand-off setelah zoom desktop selesai (±1 dtk).", "Settings › Lock Screen › Over the wallpaper › Island › Welcome back"),
        wide("lock-island-face-armed", "Face unlock: siap", "Pil gembok dengan sudut squircle Glance, glyph Face ID 18 pt di sayap kanan, sejauh gembok dari tepi kiri.", "Face unlock aktif di lock screen, menunggu pemicu.", "Settings › Face Unlock"),
        wide("lock-island-face-armed-music", "Face unlock: siap + musik", "Bar musik lalu glyph Face ID di sayap kanan.", "Lagu diputar saat face unlock siap.", "Settings › Face Unlock"),
        wide("lock-island-face-scanning", "Face unlock: memindai", "Panel scanning Glance (252 × 200) dengan sudut squircle (12 → 60, reach 1,528), idleanimation.mp4 berulang.", "Mencari wajah (hover, spasi, wake, atau lock).", "Settings › Face Unlock › Animation"),
        wide("lock-island-face-success", "Face unlock: cocok", "unlockanimation.mp4 sekali, frame terakhir ditahan, lalu berubah jadi welcome.", "Wajah cocok; password diketik.", "Settings › Face Unlock › Animation"),
        wide("lock-island-face-failure", "Face unlock: gagal", "unsuccessfulunlockanimation.mp4 sekali lalu ditahan; hover mencoba lagi.", "Wajah tidak cocok, dicurigai palsu, atau habis waktu.", "Settings › Face Unlock › Animation"),
        wide("lock-island-face-touchid", "Face unlock: butuh Touch ID", "“Unlock with Touch ID once to use Face ID” dengan glyph Touch ID, satu baris di bawah kamera.", "Sesi Touch ID terkunci, password belum bisa diketik.", "Settings › Face Unlock"),
        wide("lock-island-face-minimal-success", "Face unlock minimal: cocok", "✓ di sayap kanan; saat Mac terbuka, langsung morph ke welcome (tidak lewat pil atau notch).", "Wajah cocok, gaya Minimal.", "Settings › Face Unlock › Animation › Minimal"),
        wide("lock-island-face-minimal-scanning", "Face unlock minimal: memindai", "Gaya minimal: gembok di sayap kiri, animasi kecil di sayap kanan, island turun 12 pt.", "Gaya animasi Minimal.", "Settings › Face Unlock › Animation › Minimal"),
        wide("lock-island-face-none-failure", "Face unlock tanpa animasi: gagal", "Panel tetap terbuka dengan gambar diam (unlockstatic.png), tanpa video hasil.", "Gaya animasi None.", "Settings › Face Unlock › Animation › None"),
    ]),
]

// MARK: - Arguments and inputs

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    FileHandle.standardError.write("usage: MakeCatalogPDF <render folder> <pdf> <commit>\n".data(using: .utf8)!)
    exit(1)
}
let renders = URL(fileURLWithPath: arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: arguments[2])
let commit = arguments[3]
let planned = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Planned", isDirectory: true)

struct Render { let width: CGFloat; let height: CGFloat; let image: NSImage }
var renderCache: [String: Render] = [:]
let manifest: [[String: Any]] = {
    guard let data = try? Data(contentsOf: renders.appendingPathComponent("manifest.json")),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
    return list
}()
let manifestByID = Dictionary(manifest.compactMap { entry in (entry["id"] as? String).map { ($0, entry) } }, uniquingKeysWith: { $1 })

func render(_ id: String) -> Render? {
    if let cached = renderCache[id] { return cached }
    let result: Render?
    if id.hasPrefix("planned/") {
        let name = String(id.dropFirst("planned/".count))
        result = NSImage(contentsOf: planned.appendingPathComponent(name + ".png")).map {
            let rep = $0.representations.first
            return Render(width: CGFloat(rep?.pixelsWide ?? 1600) / 2, height: CGFloat(rep?.pixelsHigh ?? 360) / 2, image: $0)
        }
    } else if let entry = manifestByID[id], let image = NSImage(contentsOf: renders.appendingPathComponent(id + ".png")) {
        result = Render(width: (entry["width"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? image.size.width,
                        height: (entry["height"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? image.size.height,
                        image: image)
    } else {
        result = nil
    }
    renderCache[id] = result
    return result
}

// The notched menu bar is as tall as the closed island; a capsule display's is 24 points.
let notchBar: CGFloat = render("closed-idle")?.height ?? 38
let capsuleBar: CGFloat = 24
let notchWidth: CGFloat = render("closed-idle")?.width ?? 200

// MARK: - Style

let pageSize = CGSize(width: 842, height: 595)
let margin: CGFloat = 44
let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
let secondary = NSColor(srgbRed: 0.43, green: 0.43, blue: 0.45, alpha: 1)
let tertiary = NSColor(srgbRed: 0.62, green: 0.62, blue: 0.64, alpha: 1)
let paper = NSColor(srgbRed: 0.975, green: 0.972, blue: 0.965, alpha: 1)
let rule = NSColor(srgbRed: 0.88, green: 0.87, blue: 0.85, alpha: 1)
let accent = NSColor(srgbRed: 0.36, green: 0.55, blue: 0.94, alpha: 1)

func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont { .systemFont(ofSize: size, weight: weight) }

func paragraph(_ lineHeight: CGFloat = 1.25, alignment: NSTextAlignment = .left) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineHeightMultiple = lineHeight
    style.alignment = alignment
    style.lineBreakMode = .byWordWrapping
    return style
}

func attributed(_ text: String, _ font: NSFont, _ color: NSColor, line: CGFloat = 1.25,
                alignment: NSTextAlignment = .left, kern: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color,
                                                  .paragraphStyle: paragraph(line, alignment: alignment), .kern: kern])
}

@discardableResult
func draw(_ text: NSAttributedString, in rect: CGRect) -> CGFloat {
    let bounds = text.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                   options: [.usesLineFragmentOrigin, .usesFontLeading])
    text.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(rect.height, bounds.height)),
              options: [.usesLineFragmentOrigin, .usesFontLeading])
    return ceil(bounds.height)
}

func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
    ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                           options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
}

// MARK: - The stage: a slice of screen with the island hanging in it

/// A calm dusk wallpaper, the same family the lock screen renders use.
func wallpaper(in rect: CGRect) {
    NSGradient(colors: [NSColor(srgbRed: 0.17, green: 0.21, blue: 0.43, alpha: 1),
                        NSColor(srgbRed: 0.5, green: 0.42, blue: 0.68, alpha: 1),
                        NSColor(srgbRed: 0.93, green: 0.66, blue: 0.56, alpha: 1)])?.draw(in: rect, angle: 90)
    // Flipped context: angle 90 runs top to bottom here.
    let hill = NSBezierPath()
    hill.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    hill.line(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.22))
    hill.curve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.12),
               controlPoint1: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.maxY - rect.height * 0.42),
               controlPoint2: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.maxY - rect.height * 0.02))
    hill.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
    hill.close()
    NSColor(srgbRed: 0.24, green: 0.2, blue: 0.36, alpha: 0.85).setFill()
    hill.fill()
}

/// The menu bar: translucent, with made-up menus on the left and the clock
/// on the right, each kept clear of the island.
func menuBar(in rect: CGRect, scale: CGFloat, islandWidth: CGFloat) {
    NSColor(white: 1, alpha: 0.22).setFill()
    rect.fill()
    let size = 11 * scale
    let baseline = rect.midY - size * 0.62
    let room = rect.width / 2 - islandWidth / 2 - 10 * scale
    var x = rect.minX + 14 * scale
    for (index, word) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
        let text = attributed(word, font(size, index == 0 ? .bold : .medium), NSColor(white: 1, alpha: 0.92))
        guard x + text.size().width < rect.minX + room else { break }
        text.draw(at: CGPoint(x: x, y: baseline))
        x += text.size().width + 18 * scale
    }
    var right = rect.maxX - 14 * scale
    for word in ["Sat 21 Nov  15.48", "100%"] {
        let text = attributed(word, font(size, .medium), NSColor(white: 1, alpha: 0.92))
        guard right - text.size().width > rect.maxX - room else { break }
        right -= text.size().width
        text.draw(at: CGPoint(x: right, y: baseline))
        right -= 18 * scale
    }
}

/// The island at `scale`, hanging from the top of a rounded screen slice.
func stage(_ item: Item, render: Render, in rect: CGRect, scale preferred: CGFloat) {
    let bar = item.capsuleDisplay ? capsuleBar : notchBar
    let scale = min(preferred, (rect.width * 0.9) / render.width, (rect.height - 22) / render.height)
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
    clip.addClip()
    wallpaper(in: rect)
    let barRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bar * scale)
    let size = CGSize(width: render.width * scale, height: render.height * scale)
    // Strips wider than the notch still leave the menus their side.
    menuBar(in: barRect, scale: scale, islandWidth: max(size.width, notchWidth * scale))
    render.image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.minY, width: size.width, height: size.height),
                      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    let scaleText = attributed(String(format: "%.0f%%", scale * 100), font(7.5, .medium), NSColor(white: 1, alpha: 0.75))
    scaleText.draw(at: CGPoint(x: rect.maxX - scaleText.size().width - 9, y: rect.maxY - 15))
}

/// A whole picture, rounded, fitted into `rect`.
func picture(_ render: Render, in rect: CGRect) -> CGRect {
    let scale = min(rect.width / render.width, rect.height / render.height)
    let size = CGSize(width: render.width * scale, height: render.height * scale)
    let frame = CGRect(x: rect.midX - size.width / 2, y: rect.minY, width: size.width, height: size.height)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12).addClip()
    render.image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                      hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    return frame
}

/// A grey slice standing in for what was not rendered.
func placeholder(_ item: Item, in rect: CGRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
    NSColor(srgbRed: 0.93, green: 0.92, blue: 0.9, alpha: 1).setFill()
    path.fill()
    rule.setStroke()
    path.lineWidth = 1
    let dashes: [CGFloat] = [5, 4]
    path.setLineDash(dashes, count: 2, phase: 0)
    path.stroke()
    let title = attributed("Tidak dirender offscreen", font(12, .semibold), secondary, alignment: .center)
    let reason = attributed(item.note ?? "", font(9.5), secondary, line: 1.3, alignment: .center)
    let inner = rect.insetBy(dx: 30, dy: 0)
    let total = height(of: title, width: inner.width) + 6 + height(of: reason, width: inner.width)
    var y = rect.midY - total / 2
    y += draw(title, in: CGRect(x: inner.minX, y: y, width: inner.width, height: 0)) + 6
    draw(reason, in: CGRect(x: inner.minX, y: y, width: inner.width, height: 0))
}

// MARK: - Text blocks

func captionText(_ item: Item, size: CGFloat = 9.5) -> NSAttributedString {
    let text = NSMutableAttributedString()
    func row(_ label: String, _ body: String) {
        text.append(attributed(label + "\n", font(size - 1.5, .semibold), tertiary, line: 1.15, kern: 0.4))
        text.append(attributed(body + "\n", font(size), ink, line: 1.28))
        text.append(attributed("\n", font(4), ink, line: 1))
    }
    row("APA INI", item.what)
    row("KAPAN MUNCUL", item.when)
    row("PENGATURANNYA DI MANA", item.setting)
    if let note = item.note, item.layout != .note {
        text.append(attributed("Catatan: " + note, font(size - 1), secondary, line: 1.28))
    }
    return text
}

func titleText(_ item: Item, size: CGFloat = 15) -> NSAttributedString {
    attributed(item.title, font(size, .semibold), ink, line: 1.1)
}

// MARK: - Pages

enum Page {
    case cover
    case contents
    case divider(Int)
    case items(section: Int, [Item])
}

var pages: [Page] = [.cover, .contents]
var sectionPage: [Int: Int] = [:]
for (index, section) in sections.enumerated() {
    sectionPage[index] = pages.count + 1
    pages.append(.divider(index))
    var pending: [Item] = []
    for item in section.items {
        if item.layout == .pair || item.layout == .note {
            pending.append(item)
            if pending.count == 2 { pages.append(.items(section: index, pending)); pending = [] }
        } else {
            if !pending.isEmpty { pages.append(.items(section: index, pending)); pending = [] }
            pages.append(.items(section: index, [item]))
        }
    }
    if !pending.isEmpty { pages.append(.items(section: index, pending)) }
}

let missing = sections.flatMap(\.items).filter { $0.layout != .note && render($0.id) == nil }.map(\.id)
if !missing.isEmpty {
    FileHandle.standardError.write("✗ missing renders: \(missing.joined(separator: ", "))\n".data(using: .utf8)!)
    exit(1)
}

let listed = Set(sections.flatMap(\.items).map(\.id))
let unlisted = manifest.compactMap { $0["id"] as? String }.filter { !listed.contains($0) }
if !unlisted.isEmpty { print("note: renders not in the catalog: \(unlisted.joined(separator: ", "))") }

func chrome(page number: Int, section: String?) {
    if let section {
        attributed(section.uppercased(), font(8, .semibold), tertiary, kern: 0.8).draw(at: CGPoint(x: margin, y: 24))
    }
    attributed("Zenith — Dynamic Island", font(8), tertiary).draw(at: CGPoint(x: margin, y: pageSize.height - 30))
    let numberText = attributed("\(number) / \(pages.count)", font(8, .medium), tertiary)
    numberText.draw(at: CGPoint(x: pageSize.width - margin - numberText.size().width, y: pageSize.height - 30))
}

func drawCover() {
    let hero = CGRect(x: 0, y: 0, width: pageSize.width, height: 330)
    wallpaper(in: hero)
    menuBar(in: CGRect(x: 0, y: 0, width: hero.width, height: notchBar * 1.6), scale: 1.6, islandWidth: (render("compact-timer-downloads")?.width ?? 380) * 1.6)
    if let island = render("compact-timer-downloads") ?? render("closed-idle") {
        let scale: CGFloat = 1.6
        let size = CGSize(width: island.width * scale, height: island.height * scale)
        island.image.draw(in: CGRect(x: hero.midX - size.width / 2, y: 0, width: size.width, height: size.height),
                          from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    var y: CGFloat = 372
    y += draw(attributed("Zenith — Dynamic Island", font(34, .bold), ink, line: 1.05), in: CGRect(x: margin, y: y, width: 600, height: 0)) + 8
    y += draw(attributed("Katalog visual semua yang bisa ditampilkan island, satu per satu, dirender dari view aslinya dengan data contoh.",
                         font(13), secondary, line: 1.3), in: CGRect(x: margin, y: y, width: 520, height: 0)) + 22
    let renderCount = manifest.count
    let meta = "21 November 2026\nBuild: Zenith (Developer) · commit \(commit)\n\(renderCount) render · \(pages.count) halaman"
    draw(attributed(meta, font(10, .medium), secondary, line: 1.45), in: CGRect(x: margin, y: y, width: 520, height: 0))
    attributed("by Satu Visual", font(10, .semibold), tertiary).draw(at: CGPoint(x: pageSize.width - margin - 70, y: pageSize.height - 40))
}

func drawContents() {
    chrome(page: 2, section: nil)
    var y: CGFloat = 70
    y += draw(attributed("Daftar isi", font(24, .bold), ink), in: CGRect(x: margin, y: y, width: 400, height: 0)) + 26
    for (index, section) in sections.enumerated() {
        let rendered = section.items.filter { $0.layout != .note }.count
        let notes = section.items.count - rendered
        let left = attributed(String(format: "%02d   ", index + 1), font(13, .semibold), tertiary)
        let title = attributed(section.title, font(15, .semibold), ink)
        left.draw(at: CGPoint(x: margin, y: y + 1))
        title.draw(at: CGPoint(x: margin + 36, y: y))
        let pageText = attributed("\(sectionPage[index] ?? 0)", font(13, .semibold), ink)
        pageText.draw(at: CGPoint(x: pageSize.width - margin - pageText.size().width, y: y + 1))
        let detail = "\(rendered) state" + (notes > 0 ? " · \(notes) tidak dirender" : "") + " — " + section.intro
        let used = draw(attributed(detail, font(9.5), secondary, line: 1.25), in: CGRect(x: margin + 36, y: y + 21, width: 560, height: 0))
        y += 21 + used + 14
        rule.setFill()
        CGRect(x: margin + 36, y: y - 7, width: pageSize.width - margin * 2 - 36, height: 0.5).fill()
    }
    draw(attributed("Cara baca: tiap state digambar di atas wallpaper contoh di bawah menu bar palsu, supaya island kelihatan di tempatnya. Persen di pojok gambar = skala dari ukuran asli (100% = 1 point layar).",
                    font(9), tertiary, line: 1.3), in: CGRect(x: margin, y: pageSize.height - 70, width: 640, height: 0))
}

func drawDivider(_ index: Int, page number: Int) {
    chrome(page: number, section: nil)
    let section = sections[index]
    attributed(String(format: "%02d", index + 1), font(64, .bold), rule).draw(at: CGPoint(x: margin, y: 170))
    draw(attributed(section.title, font(30, .bold), ink), in: CGRect(x: margin, y: 262, width: 600, height: 0))
    draw(attributed(section.intro, font(13), secondary, line: 1.35), in: CGRect(x: margin, y: 306, width: 520, height: 0))
}

func drawPair(_ items: [Item], section: Int, page number: Int) {
    chrome(page: number, section: sections[section].title)
    let top: CGFloat = 50
    let blockHeight: CGFloat = (pageSize.height - top - 48) / 2
    for (slot, item) in items.enumerated() {
        let y = top + CGFloat(slot) * blockHeight
        let shown = item.layout == .note ? 120 : (render(item.id)?.height ?? 38) * 1.3 + 96
        let stageRect = CGRect(x: margin, y: y + 6, width: 470, height: min(blockHeight - 26, shown))
        if item.layout == .note {
            placeholder(item, in: stageRect)
        } else if let render = render(item.id) {
            stage(item, render: render, in: stageRect, scale: 1.3)
        }
        let textX = stageRect.maxX + 24
        let width = pageSize.width - margin - textX
        var ty = y + 8
        ty += draw(titleText(item), in: CGRect(x: textX, y: ty, width: width, height: 0)) + 10
        draw(captionText(item), in: CGRect(x: textX, y: ty, width: width, height: 0))
        if slot == 0, items.count > 1 {
            rule.setFill()
            CGRect(x: margin, y: y + blockHeight - 6, width: pageSize.width - margin * 2, height: 0.5).fill()
        }
    }
}

func drawSingle(_ item: Item, section: Int, page number: Int) {
    chrome(page: number, section: sections[section].title)
    guard let render = render(item.id) else { return }
    let top: CGFloat = 46
    let textHeight: CGFloat = 118
    let area = CGRect(x: margin, y: top, width: pageSize.width - margin * 2, height: pageSize.height - top - 48 - textHeight)
    var bottom = area.maxY
    switch item.layout {
    case .wide:
        stage(item, render: render, in: area, scale: 0.95)
    case .screen:
        bottom = picture(render, in: area).maxY
    case .mockup:
        let frame = picture(render, in: CGRect(x: area.minX, y: area.minY + 40, width: area.width, height: area.height - 40))
        let badge = attributed("  RENCANA · BELUM DIBUAT  ", font(9, .bold), .white, kern: 0.6)
        let size = badge.size()
        let badgeRect = CGRect(x: frame.minX, y: frame.minY - size.height - 16, width: size.width, height: size.height + 8)
        NSColor(srgbRed: 0.93, green: 0.55, blue: 0.2, alpha: 1).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: badgeRect.height / 2, yRadius: badgeRect.height / 2).fill()
        badge.draw(at: CGPoint(x: badgeRect.minX, y: badgeRect.minY + 4))
        attributed("Mockup yang disetujui, bukan render dari aplikasi.", font(9), secondary)
            .draw(at: CGPoint(x: badgeRect.maxX + 10, y: badgeRect.minY + 4))
        bottom = frame.maxY + 16
    default:
        break
    }
    // Title on the left, the three answers in columns beside it.
    let y = bottom + 18
    let columns = pageSize.width - margin * 2
    draw(titleText(item, size: 17), in: CGRect(x: margin, y: y, width: 210, height: 0))
    let fields: [(String, String)] = [("APA INI", item.what), ("KAPAN MUNCUL", item.when), ("PENGATURANNYA DI MANA", item.setting)]
    let start = margin + 230
    let columnWidth = (columns - 230 - 2 * 18) / 3
    for (index, field) in fields.enumerated() {
        let x = start + CGFloat(index) * (columnWidth + 18)
        let label = attributed(field.0, font(8, .semibold), tertiary, kern: 0.4)
        label.draw(at: CGPoint(x: x, y: y + 2))
        draw(attributed(field.1, font(9.5), ink, line: 1.28), in: CGRect(x: x, y: y + 17, width: columnWidth, height: 0))
    }
    if let note = item.note {
        draw(attributed("Catatan: " + note, font(8.5), secondary, line: 1.25),
             in: CGRect(x: margin, y: y + 60, width: 210, height: 0))
    }
}

// MARK: - Writing

var mediaBox = CGRect(origin: .zero, size: pageSize)
let info: [CFString: Any] = [kCGPDFContextTitle: "Zenith — Dynamic Island", kCGPDFContextAuthor: "Satu Visual",
                             kCGPDFContextCreator: "Tools/IslandCatalog/MakeCatalogPDF.swift"]
guard let context = CGContext(output as CFURL, mediaBox: &mediaBox, info as CFDictionary) else {
    FileHandle.standardError.write("✗ cannot write \(output.path)\n".data(using: .utf8)!)
    exit(1)
}
for (index, page) in pages.enumerated() {
    context.beginPDFPage(nil)
    context.translateBy(x: 0, y: pageSize.height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    paper.setFill()
    CGRect(origin: .zero, size: pageSize).fill()
    let number = index + 1
    switch page {
    case .cover: drawCover()
    case .contents: drawContents()
    case .divider(let section): drawDivider(section, page: number)
    case .items(let section, let items):
        if items.count == 1, items[0].layout != .pair, items[0].layout != .note {
            drawSingle(items[0], section: section, page: number)
        } else {
            drawPair(items, section: section, page: number)
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    context.endPDFPage()
}
context.closePDF()
print("\(pages.count) pages, \(manifest.count) renders")
