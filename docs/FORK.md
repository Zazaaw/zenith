# Zenith by Satu Visual

Fork dari [vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils),
dikelola [Satu Visual](https://github.com/satuvisual) (@Zazaaw). Tujuannya: memakai
bahasa desain sendiri (Satu Visual + p441z Style Kit), me-redesign dan menambah fitur
notch, dan menambah fitur lain, sambil tetap mengikuti update dari upstream.

Status: **dalam pengembangan, belum dirilis.** Kode masih memakai identitas Vorssaint;
rebranding dikerjakan bertahap (lihat di bawah).

## Identitas

| | |
|---|---|
| Nama | **Zenith**, selalu ditulis "Zenith by Satu Visual" (ada app kecil lain bernama Zenith) |
| Repo | [satuvisual/zenith](https://github.com/satuvisual/zenith) |
| Bundle ID (rencana) | `id.satuvisual.zenith` |
| Logo | Bintang 8 lengan Satu Visual (monokrom); dipakai untuk ikon app, glyph menu bar, notch idle, About, DMG |
| Atribusi | Kredit ke Vorssaint hanya di README (bagian Credits dan License). Header copyright upstream di file sumber tidak boleh dihapus. UI app tidak menyebut Vorssaint; kalau build Zenith suatu saat disebarkan, tambahkan layar lisensi di app (GPL §5d). |

## Urutan rebranding

1. **Identitas dan keamanan.** Nama, bundle ID (sekitar 20 ID turunan `com.vorssaint.*`),
   auto-update (sekarang mengarah ke rilis GitHub Vorssaint, jadi bisa menimpa fork),
   feedback dan sharing (mengirim ke `screenshots.vorssaint.com`), identitas signing,
   link donasi dan sosial. Identitas dikumpulkan di satu file brand.
2. **Identitas visual.** Ikon, logo, glyph menu bar, design tokens.
3. **Redesign per area.** Notch, panel menu bar, lalu Settings.
4. **Fitur baru.**

Nama internal (folder `Sources/Vorssaint/`, nama modul, nama tipe) **tidak** di-rename,
karena memindahkan path ribuan file akan membuat setiap sync konflik.

### Status fase 1

**1a. Identitas inti dan keamanan (selesai, branch `feat/rebrand-identity`):**

- Semua nilai brand ada di `Core/AppInfo.swift`: nama, pembuat, copyright (dengan
  atribusi Vorssaint), website, repo, bundle ID, dan saklar layanan.
- Auto-update **mati** (`AppInfo.updatesEnabled = false`). Installer upstream
  memverifikasi Developer ID Vorssaint (Team `3D485NHW29`), jadi kalau update tetap
  mengarah ke upstream, Zenith akan ditimpa Vorssaint resmi.
- Feedback **mati** (`AppInfo.feedbackEndpoint = nil`, error `unavailable`). Sharing
  screenshot/rekaman diarahkan ke host `.invalid` yang tidak pernah resolve, jadi tidak
  ada data yang terkirim ke `screenshots.vorssaint.com`. Tombol share masih terlihat.
- Tombol donasi disembunyikan (`coffeeURL = nil`). Discord dan X juga `nil` (tidak dipakai di UI).
- Bundle ID `id.satuvisual.zenith` / `.dev`, executable `Zenith` / `ZenithDeveloper`,
  helper fan-control `id.satuvisual.zenith.fan-control`, nama app dan teks izin
  (Info.plist dan 14 `InfoPlist.strings`).
- Daftar perlindungan diri (Quit All, Dock click, Kill Process, Cleaner, Uninstaller)
  mengenali ID Zenith. ID Vorssaint tetap dilindungi.
- `build.sh --install` tidak lagi menghapus app lama Vorssaint; test isolasi install
  diubah sesuai aturan itu.
- Judul panel, User-Agent, dan nama klien memakai `AppInfo.name`.

**1b. Teks UI (selesai, branch `feat/rebrand-ui-strings`):**

- "Vorssaint" → "Zenith" di 1.475 string literal Swift (60 file, 15 bahasa). Diganti
  dengan pemindai yang paham sintaks string Swift, jadi komentar, header copyright,
  nama properti (mis. `keepAwakeActiveIconVorssaint`), dan ID huruf kecil tidak tersentuh.
  Teks UI baru dari upstream bisa disisir dengan cara yang sama (lihat langkah sync 5).
- Sengaja dikecualikan: `AppInfo.swift` (atribusi), `BundleMigration.swift` (hanya
  aktif untuk bundle ID yang sama, jadi tidak pernah jalan di Zenith), dan
  `UpdateInstallerSupport.swift` (update mati).
- File konfigurasi pindah dari `~/.config/vorssaint/` ke `~/.config/zenith/`, supaya
  tidak berbagi pengaturan dengan Vorssaint kalau keduanya terpasang. Fallback path
  wallpaper memakai bundle ID Zenith.

**Fondasi (branch `feat/foundation`):**

- README Zenith; Vorssaint hanya di bagian Credits dan License. `.gitattributes`
  membuat README versi kita selalu menang saat merge.
- Copyright yang terlihat (About, Info.plist) hanya "© 2026 Satu Visual".
- Nama yang bisa dilihat pengguna memakai `zenith`: aturan sudoers
  `/etc/sudoers.d/zenith-clamshell` (dan Zenith tidak lagi menghapus aturan
  Vorssaint), lock file helper kipas `/var/run/zenith-fan-control.*`, file sementara
  (`.zenith-partial-*`, `.zenith-*.partial`, `zenith-homebrew-*`, `zenith-uninstall-*`,
  `.zenith-XXXXXX`), proses `zenith-relaunch`, skema `zenith-task`, backup wallpaper
  `WallpaperIndex.zenith-bak`, kunci file backup `zenithBackupVersion` /
  `zenithBackupAppVersion` (backup dari Vorssaint tidak bisa di-restore ke Zenith).
- `Tools/uninstall.sh` sekarang untuk Zenith dan tidak menyentuh Vorssaint.
- Glyph menu bar dinaikkan ke 17 pt setelah dicek di menu bar sungguhan.

**Fondasi tahap 2 (branch `feat/foundation-2`):**

- Dokumen repo: `SUPPORT.md` dan `SECURITY.md` ditulis ulang untuk Zenith (merge=ours);
  `SPONSORS.md`, `TRADEMARKS.md`, `docs/assets/`, `docs/demo.gif` dan
  `.github/FUNDING.yml` (tombol Sponsor ke akun Vorssaint) dihapus; `CODEOWNERS`
  jadi `@Zazaaw` (sebelumnya setiap PR meminta review dari akun Vorssaint).
- `CONTRIBUTING.md`, `docs/*.md` dan template issue/PR diganti namanya oleh
  `Tools/zenith-rebrand-docs.py` (nama, URL ke `satuvisual/zenith/blob/dev`, ID, path),
  dengan catatan Zenith di CONTRIBUTING dan PRIVACY.
- Variabel lingkungan untuk file shell pengguna: `ZENITH_RESOLVING_ENVIRONMENT`.
- `CHANGELOG.md` di repo tetap versi upstream (diubah upstream tiap rilis); salinan
  yang dibaca What's New diganti namanya oleh `build.sh` saat build.
- Tur highlights 3.4.0 dan ajakan star/donasi 3.4.4 milik upstream disembunyikan
  (`AppInfo.showsUpstreamReleaseIntros = false`), termasuk tombol "Review highlights"
  di About. What's New biasa tetap tampil.
- **Versi:** Zenith memakai nomor versi upstream (sekarang 3.4.4). Upstream menaikkannya
  di `Info.plist` tiap rilis dan test mengunci angkanya, jadi nomor sendiri akan
  konflik di setiap sync. Build Zenith dikenali dari commit di About.

**Sisa yang belum dikerjakan:**

- Gambar `Resources/Images/highlights-*` tidak dimuat kode mana pun, dan
  `Resources/Gifs/highlights-notch.gif` hanya dipakai tur highlights yang
  disembunyikan. Dibiarkan supaya sync tetap mulus.
- Nama internal yang tidak terlihat pengguna dibiarkan: label antrean dan log
  `com.vorssaint.*`, ID sentinel AirPlay `vorssaint.output.airplay`, simbol
  `vorssaint_now_playing_*` (penghubung dylib dan `now-playing.pl`), kunci defaults
  `vorssDisabledSleep`, dan string `communityIntroFollowButton` yang tidak dipakai UI.
- Workflow `release.yml` dan `issue-fix-status.yml` milik pipeline rilis upstream
  tidak dipakai Zenith.
- Catatan rilis (`ReleaseNotes.swift`, `CHANGELOG.md`) masih riwayat rilis Vorssaint,
  termasuk klaim "Signed with an Apple Developer ID and notarized" yang belum berlaku
  untuk Zenith.
- `UpdateInstallerSupport` masih memverifikasi Team ID Vorssaint. Ganti ke Team ID
  Satu Visual begitu ada Apple Developer Program, lalu nyalakan `updatesEnabled`.
- Workflow `release.yml` adalah pipeline rilis Vorssaint (signing dan notarisasi
  mereka), jadi tidak dipakai Zenith.
- Identitas signing lokal "Vorssaint Utils Signing" sengaja dipertahankan: hanya ada
  di keychain dan tidak pernah terlihat pengguna, dan menggantinya akan menghapus izin
  yang sudah diberikan.
- Label internal (`com.vorssaint.*` di queue/log, `VorssaintBuildCommit`, nama
  dylib/modul) dibiarkan karena tidak terlihat pengguna.

## Aturan yang mengikat

- **GPL-3.0-or-later.** Kalau hasil fork disebarkan, source code-nya wajib terbuka
  dengan lisensi yang sama.
- **[TRADEMARKS.md](../TRADEMARKS.md).** Sebelum build apa pun disebarkan, nama, ikon,
  bundle ID, identitas signing, dan feed update wajib diganti. Jangan pernah
  menampilkan build fork sebagai Vorssaint resmi.
- File baru tetap memakai header SPDX dan copyright seperti file upstream
  (lihat [CONTRIBUTING.md](../CONTRIBUTING.md)).

### Status fase 2: identitas visual

**Selesai (branch `feat/visual-identity`):**

- Sumber logo: `Resources/Brand/satuvisual-mark.svg` (bintang Satu Visual).
  `swift Tools/zenith-brand-assets.swift` membangkitkan ulang master
  `Resources/Brand/logo.png` dan `Resources/Brand/AppIcon-Default.png`; jalankan
  setiap kali logo atau desain ikon berubah, lalu commit hasilnya.
- Ikon app: squircle putih (superellipse n=5, body 824 pt di kanvas 1024), gradasi
  halus, bayangan lembut, bintang `#0A0A0A` setengah lebar body.
- Glyph menu bar: bintang 14 pt di tengah kanvas 26×20 pt (dicek berdampingan dengan
  ikon sistem di menu bar terang dan gelap).
- `BrandMark.png` tetap memakai kotak 640×324 milik upstream (bintang setinggi kotak,
  di tengah), jadi 10 pemakaian `BrandMark(width:)` tidak perlu diubah.
- `BrandBadge` (About, What's New) sekarang terang seperti ikon app.
- Ikon adaptif `AppIcon.icon` (hanya terpakai dengan Xcode 26) memakai SVG bintang,
  skala 2.0. **Belum pernah dirender**, karena `actool` hanya ada di Xcode 26.
- DMG: judul "Zenith", teks "Drag Zenith to Applications", panah monokrom, nama
  file `dist/Zenith-<versi>.dmg`. `make-dmg.sh` belum dijalankan lokal (mengontrol Finder).

**Belum:**

- Design tokens dan redesign UI (fase 3). Latar onboarding masih `Theme.spaceGradient`.
- Gambar dan GIF sorotan fitur (`Resources/Images`, `Resources/Gifs`) masih
  screenshot UI Vorssaint.

### Fase 3: design tokens dan redesign UI

Keputusan desain: SF Pro untuk semua teks, kontrol mengikuti warna aksen sistem,
warna status dan data memakai palet p441z Style Kit (blue info, purple proses, amber
peringatan, emerald sukses, red error; warna lain jadi abu-abu), gerak mengikuti kurva
dan spring Style Kit. Urutan redesign: notch, panel menu bar, lalu Settings.

- **3a (selesai):** `Sources/Vorssaint/UI/ZenithTokens.swift` berisi `ZenithStatus`,
  `ZenithMotion`, `ZenithRadius` dan `ZenithType`. Belum ada view yang memakainya, jadi
  tampilan belum berubah. Status di mode terang memakai tingkat 600 (bukan 500 seperti
  Style Kit) supaya teks kecil tetap terbaca di latar putih.
- **Notch (palet status, selesai):** peringatan/gagal amber, error merah, sukses
  emerald, timer purple, keep-awake amber; toggle mikrofon ikut aksen sistem. Warna
  identitas dibiarkan (merek AI agent, bagian Music dan Calendar, aksen kalender, api
  streak, Watch). `NotchUpdateControl` tidak diubah (dikompilasi ke test tanpa token,
  dan update mati). Gerak dan radius notch dipertahankan atas keputusan Faiz.
- **Settings (palet, header, radius, selesai):** status di `UI/Settings/` memakai
  `ZenithStatus` (aktif/diizinkan/tersimpan emerald; shortcut gagal, izin hilang, gagal,
  konflik, update menunggu, badge eksperimental/beta amber; error yang dulu merah tetap
  merah). Warna identitas dibiarkan: tile ikon sidebar, bintang di Support, preview
  jendela di Appearance, miniatur radial menu dan menu bar, maskot. Halaman redesign
  dibuka dengan `SettingsPageHeader` (judul tebal + satu baris muted, opsional kontrol
  di kanan) di `SettingsCard.swift`. Radius kartu, anchor, chip pilihan dan tile memakai
  `ZenithRadius` dengan nilai yang sama (kartu Settings 16 = `panel`). Halaman `Form`
  grouped bawaan upstream belum punya header ini; `NotchSettings` belum disentuh.
  `ZenithTokens.swift` ikut dikompilasi ke test karena `SettingsCard` disalin ke sana.
- **Zona AirDrop di notch (selesai):** `Services/Notch/NotchAirDropSupport.swift`.
  Pilihan zona sekarang muncul untuk semua file: Files, AirDrop, dan Optimize media
  (hanya untuk media). `ShelfDropRoutingTests` disesuaikan dan tidak pernah memicu
  AirDrop sungguhan.
- **AirDrop berdiri sendiri (selesai):** pengaturan `notchAirDropEnabled` (default nyala)
  di halaman Shelf; tanpa Shelf/Files, drag file "meminjam" halaman Files dengan AirDrop
  sebagai satu-satunya zona. Teks fitur Zenith ada di `Core/ZenithStrings.swift`
  (15 bahasa; test upstream mewajibkan apostrof melengkung ’).
- **Maskot bintang Satu Visual (selesai):** gaya `satuVisual` (default) di
  `NotchMascotStyle`, geometri `NotchMascotGeometry.star` (fill even-odd untuk potongan X),
  dua mata kecil di lengan horizontal.
- **WakaTime (selesai):** bagian notch `.wakatime` dan kartu panel `PanelSectionID.wakatime`,
  kode di `Services/WakaTime/` dan `UI/WakaTime/`. Hanya muncul kalau `~/.wakatime.cfg` ada.
  API key WakaTime hanya boleh membaca `status_bar/today`; summaries/stats/durations
  butuh OAuth, jadi grafik 7 hari dibangun Zenith dari total harian yang dilihatnya
  (`zenithWakaTimeHistory`, tidak ikut backup). Data diambil hanya saat tampilan terlihat,
  paling sering tiap 5 menit. Test di `Tests/WakaTimeTests.swift` (suite `wakatime`).
- **Token pribadi (WakaTime, Vercel):** disimpan oleh `Services/ZenithSecretStore.swift` sebagai
  file `0600` di `<container>/Secrets/` (folder `0700`), bukan Keychain: build self-signed
  tanpa Team ID membuat macOS mengikat item keychain ke cdhash biner, jadi prompt muncul
  lagi tiap rebuild walau sudah "Always Allow". Token lama di Keychain dipindah otomatis
  sekali. Kembali ke Keychain kalau Zenith nanti ditandatangani Developer ID.
- **Cuaca dan pengingat di lock screen (branch `feat/lockscreen-weather-reminders`):**
  dua item baru di baris aktivitas lock screen, masing-masing dengan saklar sendiri di
  Settings → Dynamic Island → Activity → Lock Screen. Kode di `Services/Weather/`,
  `Services/Reminders/`, `Services/Notch/NotchLockScreenWidgets.swift` (start/stop
  bersama lock screen) dan `NotchLockScreenWidgetAccess.swift`; edit di file upstream
  hanya baris bertanda `// Zenith fork:`. Test di `Tests/LockScreenWidgetsTests.swift`
  (suite `lockscreen-widgets`).
  - **Default mati.** Keduanya butuh izin macOS, jadi saklarnya default off
    (`notchLockScreenWeather`, `notchLockScreenReminders`). Izin hanya diminta saat
    pengguna menyalakan saklar (saklar itu sendiri hanya terlihat kalau lock screen
    nyala); tidak pernah saat launch, dari lock screen, atau dari test. Di bawah saklar
    ada keterangan sumber data, atau tombol "Grant access" / "Open System Settings…"
    kalau izin belum diberikan atau ditolak. Lock screen hanya membaca data kalau lock
    screen nyala, saklar nyala, dan izin sudah diberikan.
  - **Cuaca:** Location Services (`NSLocationUsageDescription`,
    `NSLocationWhenInUseUsageDescription`, entitlement hardened runtime
    `com.apple.security.personal-information.location`), akurasi 3 km, sekali minta
    (`requestLocation`) dengan batas 20 detik. Posisi dibulatkan ke 2 desimal (±1 km);
    hanya posisi bulat itu yang disimpan (`zenithWeatherLocation`, tidak ikut backup,
    dihapus kalau izin dicabut) dan dikirim ke Open-Meteo (gratis, tanpa key, selalu
    Celsius lalu dikonversi sesuai `temperatureUnit`). Posisi dipakai ulang sampai 1 jam.
    Data dibaca saat lock screen muncul kalau umurnya > 30 menit, lalu tiap 30 menit
    selama lock screen tetap tampil (5 menit setelah gagal); di luar itu tidak ada
    jaringan sama sekali. Data yang lebih tua dari 3 jam tidak ditampilkan. Di lock
    screen: simbol cuaca (siang/malam), suhu sekarang, dan tertinggi/terendah hari ini
    dengan warna redup. **Nama tempat tidak pernah tampil.**
  - **Pengingat:** EventKit `requestFullAccessToReminders`
    (`NSRemindersFullAccessUsageDescription`; entitlement calendars yang sudah ada juga
    mencakup Reminders). Pengingat belum selesai yang jatuh tempo hari ini atau sudah
    lewat, paling awal dulu, maksimal 3 (sisanya jadi "+N"). Yang terlewat ditandai ikon
    `exclamationmark.circle` (tetap putih, semua ikon di baris lock screen putih). Hanya
    judul yang tampil, tidak pernah catatan; tidak ada yang disimpan ke disk. Dibaca saat
    lock screen muncul, saat `EKEventStoreChanged`/ganti hari/ganti zona waktu, dan tiap
    30 menit selama lock screen tampil.
  - Kedua item ditambahkan paling akhir di `NotchLockScreenActivity`, jadi kalau baris
    terlalu panjang, `ViewThatFits` membuang keduanya lebih dulu.
- **Vercel dan GitHub (branch `feat/vercel-github`):** dua bagian notch baru, hanya di
  notch (tidak ada kartu panel menu bar, tidak menyentuh lock screen). Kode di
  `Services/Vercel/`, `Services/GitHub/`, `UI/Vercel/`, `UI/GitHub/`; teks di
  `Core/ZenithStrings.swift` (15 bahasa). Test di `Tests/VercelGitHubTests.swift`
  (suite `vercel` dan `gh`; nama `github` ditolak sandbox agent, jadi dipendekkan).
  - **Vercel** (`.vercel`, ⌥⌘E). Auth: access token Vercel ditempel sekali di opsi
    bagian Vercel (Dynamic Island → Content → Vercel), disimpan lewat
    `Services/ZenithSecretStore.swift` sebagai file `<container>/Secrets/vercel-token`
    (folder 0700, file 0600, dikecualikan dari Time Machine), **bukan** Keychain (build
    self-signed tanpa Team ID membuat Keychain minta izin lagi setiap rebuild) dan bukan
    UserDefaults/backup. Dikirim hanya ke `api.vercel.com` sebagai `Authorization: Bearer`.
    Endpoint: `GET /v2/teams?limit=10`, lalu `GET /v6/deployments?limit=10` untuk akun
    pribadi (tanpa `teamId`) dan tiap tim (`teamId=`, maks. 10 tim); hasil digabung,
    tanpa duplikat, terbaru dulu, maks. 12. Field: `uid`, `name`, `url`,
    `readyState`/`state`, `created`/`createdAt`, `target`, `inspectorUrl`,
    `meta.githubCommitRef`/`githubCommitMessage` (juga GitLab/Bitbucket). Klik baris
    membuka URL deployment kalau READY, selain itu halaman inspector (build log).
    Visibilitas: bagian ini selalu ada di daftar Content supaya token bisa ditempel, tapi
    baru tampil di island kalau `notchVercelEnabled` nyala (default mati); menyimpan
    token otomatis menyalakannya, jadi pengguna lama tidak tiba-tiba melihat bagian baru.
    Polling hanya saat island jalan, bagian Vercel tampil, dan token ada: tiap 15 dtk
    selama ada deployment QUEUED/INITIALIZING/BUILDING, tiap 2 menit kalau tidak,
    5 menit setelah gagal (1 menit kalau gagal saat build); token ditolak (401/403 di
    semua scope) menghentikan polling sampai token baru disimpan. Token hanya dibaca dari
    disk saat bagian nyala atau halamannya/opsinya dibuka.
  - **Live activity Vercel**: `NotchCompactActivity.vercel`, urutan otomatis setelah
    agents. Selama ada build, island tertutup menampilkan mark + "Building" di kiri kamera
    dan nama project di kanan (kapsul: satu baris); build yang terlihat berjalan di polling
    sebelumnya lalu selesai ditampilkan 8 detik ("Ready"/"Error"/"Canceled" dengan
    simbolnya), lalu hilang. Pulse simbol mengikuti Reduce Motion. Ikut picker activity
    seperti activity lain; bisa dimatikan di opsi Vercel (`notchVercelActivity`, default
    nyala). Wing memakai geometri Watch (`compactWatchGeometry`, 56–150 pt) karena
    `minimumCompactWidth` privat di `NotchSupport.swift`. Hook di file upstream ditandai
    `// Zenith fork`: `NotchSupport` (case, urutan activity), `NotchService`
    (`hasVercelActivity`, geometri, ukuran kapsul, langganan `$activity`, sync/stop
    service), `NotchView`/`NotchMirrorView` (strip), `NotchTimerStrip`/`NotchCapsuleViews`
    (Vercel tidak pernah jadi pasangan).
  - **GitHub** (`.github`, ⌥⌘U) lewat `gh` yang sudah login, tanpa token baru. Satu
    panggilan `gh api graphql` (pencarian `is:pr is:open review-requested:@me` dan
    `is:pr is:open author:@me`, 8 per grup, dengan `statusCheckRollup` commit terakhir).
    Selalu di luar main thread (`BoundedProcessRunner`, timeout 25 dtk), tanpa prompt,
    update notice, atau warna. Lokasi `gh`: Homebrew (`/opt/homebrew/bin`,
    `/usr/local/bin`), MacPorts, `~/.local/bin`, `~/bin`, Nix, shim mise/asdf,
    `/usr/bin`, lalu PATH app; PATH login shell (`HomebrewEnvironment.loginShellExports`)
    hanya dicari saat tombol "Look again" di opsi GitHub ditekan, karena menjalankan file
    startup shell. Bagian ini tersedia hanya kalau `gh` ditemukan (cek file, di-cache
    10 dtk); tanpa `gh` daftar Content menampilkan alasannya dan opsinya tetap bisa dibuka.
    Status: gh tidak ada, belum login (exit 4 / HTTP 401), gagal, masing-masing dengan
    pesan. Polling tiap 5 menit selama bagian tampil, plus saat halaman muncul kalau data
    lebih tua dari 2 menit.
- **Terminal readout di lock screen (branch `feat/lockscreen-terminal`):** panel status
  bergaya output terminal di bawah baris aktivitas lock screen. Bukan terminal sungguhan,
  hanya teks monospace untuk dipantau sekilas saat Mac terkunci. Kode di
  `Services/Notch/NotchLockScreenTerminalSupport.swift` (logika murni: model baris, urutan,
  visibilitas, sensor nama, format, layout), `Services/Notch/NotchLockScreenTerminal.swift`
  (start/stop sumber data bersama lock screen), `UI/Notch/NotchLockScreenTerminalView.swift`,
  dan `UI/Settings/NotchLockScreenTerminalSettings.swift`. Teks Settings di
  `Core/ZenithStrings.swift` (15 bahasa). Test di `Tests/LockScreenTerminalTests.swift`
  (suite `lockscreen-terminal`).
  - **Default mati** (`notchLockScreenTerminal`). Pengaturannya di Settings → Dynamic Island
    → Activity → Lock Screen, di bawah saklar item: saklar utama, daftar baris (saklar per
    baris, tombol naik/turun untuk urutan), dan "Show project names"
    (`notchLockScreenTerminalProjects`, default mati). Urutan dan pilihan disimpan dalam satu
    string `notchLockScreenTerminalLines`, mis. `agents,waka,-vercel,-ci,sys,dl,timer`
    (`-` = mati; nama asing/duplikat dilewati; baris baru dari versi nanti masuk di akhir,
    mati). Semuanya ikut backup karena terdaftar di `registeredDefaults`.
  - **Tampilan:** kartu `ZenithRadius.card` hitam 60% dengan garis putih 10% (Reduce
    Transparency: solid; Increase Contrast: garis 35%), lebar sama dengan panel musik (404 pt),
    SF Mono 11,5 pt, tinggi baris 16 pt. Tiap baris: prompt `›` redup, label 6 karakter, nilai
    putih 92%; diakhiri baris prompt dengan kursor blok yang berkedip tiap 0,5 dtk (diam
    saat mengetik dan saat Reduce Motion). Warna hanya untuk titik kecil `ZenithStatus`:
    merah untuk build Vercel gagal dan check GitHub gagal, amber untuk baterai ≤ 20% tanpa
    charger. Label tetap bahasa Inggris di semua bahasa, nilainya juga (gaya output CLI).
  - **Mengetik masuk:** saat lock screen muncul, baris muncul satu per satu tiap 40 ms
    (`ZenithMotion.layerStagger`), utuh per baris. Setelah itu nilai berubah di tempat lewat
    `TimelineView` per detik plus `@ObservedObject` ke tiap service, tanpa mengetik ulang.
    Reduce Motion: semua langsung tampil.
  - **Format per baris** (nama project/repo/file hanya kalau "Show project names" nyala):
    `agents  2 running · claude, codex` (nama → `claude@zenith`), `waka  3h 12m · goal 75%`
    (+ project teratas hari ini), `vercel  building` / `2 building` / `queued` /
    `ready · 2h ago` / `failed · 5m ago` (+ project), `ci  1 check failing · 2 pending ·
    1 review` / `3 checks passing` / `1 open` (+ repo PR yang gagal/pending),
    `sys  bat 84% · cpu 23%` (`charging` saat mengisi; Mac tanpa baterai hanya `cpu`;
    belum ada data `cpu --`), `dl  2 files 37%` (rata-rata progres; + nama file pertama),
    `timer  12:04 left` / `focus 12:04 left` / `03:10 elapsed` / `12:04 paused` / `done`.
    Baris yang sumbernya kosong disembunyikan, kecuali `sys`. Nama provider agent (claude,
    codex) tetap tampil seperti item agents lock screen yang sudah ada; yang disensor nama
    project-nya.
  - **Sumber data hanya jalan selama readout tampil.** Ketersediaan dicek saat lock screen
    muncul: agents butuh fitur agents nyala, waka butuh `~/.wakatime.cfg` atau token, dl butuh
    rute downloads, timer butuh fitur timer; Vercel dan `ci` default mati karena memakai
    jaringan / menjalankan `gh` (tanpa token atau `gh` barisnya kosong saja). Start/stop di
    `NotchLockScreenTerminal`: WakaTime lewat `viewAppeared`/`viewDisappeared`; Vercel dan
    GitHub lewat penghitung penonton baru `lockScreenShown()`/`lockScreenHidden()` (polling
    jalan kalau bagian island-nya nyala **atau** readout tampil; data yang dibaca < 1 menit
    (Vercel) / < 2 menit (GitHub) tidak dibaca ulang saat terkunci; polling khusus lock screen
    tidak pernah memunculkan live activity Vercel di island); `SystemMonitor` lewat konsumen
    baru `setLockScreenNeeds` (hanya CPU dan baterai); agents dan downloads distart lalu
    dihentikan bersama scene lock screen seperti item lain.
  - **Layout:** readout tergantung 10 pt di bawah baris aktivitas; tinggi kartu mengikuti
    jumlah baris yang dipilih dan tersedia (+ baris kursor). Player musik mengambil sisa ruang
    di bawahnya; kalau sisa itu kurang dari tinggi minimum player (190 pt) dan musik bisa
    tampil, readout yang mengalah (tidak tampil), mis. di layar setinggi 800 pt.
  - Edit di file upstream hanya baris bertanda `// Zenith fork`: `NotchLockScreenService`
    (frame, panel, start/stop) dan `SystemMonitor` (konsumen lock screen). Test double di
    `Tests/SystemMonitorPlanTests.swift` ikut diberi `lockScreenNeeds`.
  - **Belum diverifikasi visual:** tampilan di lock screen sungguhan, efek ketik, kedip
    kursor, dan tata letak bersama player musik belum dilihat di Mac (app UI tidak dijalankan
    saat pengerjaan).
- **Panel menu bar, bahasa desain Settings (branch `feat/panel-redesign`):** panel memakai
  bahasa p441z.my.id yang sama dengan Settings, diperkecil untuk panel 332 pt. Hanya
  visual; perilaku, layout, dan daftar section tidak berubah. Komponen baru di
  `UI/MenuPanel/ZenithPanelChrome.swift`; file upstream hanya diberi kait bertanda
  `// Zenith fork`, kebanyakan di blok bersama sehingga hampir semua section ikut berubah
  tanpa diedit satu per satu.
  - **Judul section** (`PanelSection` di `PanelLayout.swift`, juga kategori Quick Controls):
    `ZenithPanelSectionLabel`, mono 10 medium, huruf kapital, tracking 0,6, abu-abu. Fungsi
    global `sectionTitle()` di `Theme.swift` tidak diubah karena juga dipakai Recorder.
  - **Kartu** (`panelCard()` di `Theme.swift`): `ZenithSurface.cardFill` + garis
    `ZenithSurface.hairline`, radius `ZenithRadius.card` (12). Dengan Increase Contrast
    garisnya lebih tebal (`ZenithPanelSurface`). Cabang island (`NotchControlSurface`) tetap.
    `PanelSurface` tidak diubah karena juga dipakai editor layout panel di Settings dan
    radial menu. Highlight hover baris ikut radius 9 dan abu-abu tile.
  - **Tab section:** glyph abu-abu (medium); hanya tab terpilih yang beraksen, sebagai tile
    10% isi / 20% garis / glyph 100%; hover abu-abu tipis. Wadahnya kartu hairline. Tab di
    island tetap hitam/putih seperti upstream.
  - **Chip dan pilihan segmen:** `KeepAwakeChipStyle` meneruskan ke `ZenithPanelChipStyle`
    (pil bergaris; terpilih aksen 10/20/100). Segmented control native di Fan Control
    (mode), Homebrew (mode, jenis, filter), dan WakaTime (rentang) diganti
    `ZenithPanelSegmented`, baris chip yang sama.
  - **Tombol:** Settings/Quit di footer, tombol kembali di detail metrik, reset di header
    section, dan tombol satuan jaringan memakai `ZenithPanelOutlineButtonStyle` (garis
    hairline, abu-abu, terangkat saat hover). Tombol edit section yang aktif jadi pil aksen
    10/20/100, bukan kotak biru penuh. Tombol `.bordered`/`.borderedProminent` bawaan
    sistem di dalam section dibiarkan.
  - **Saklar:** semua saklar panel (baris Quick Controls/Toggles, Keep Awake, opsi, mixer,
    prioritas audio, brightness, fan, wallpaper) memakai `ZenithSwitchStyle` lewat
    `.zenithPanelSwitch(_:)`, diskalakan ke ukuran AppKit yang dipakai sebelumnya (regular
    34×20, small ×0,88, mini ×0,76). Saklar yang punya label sendiri memakai
    `ZenithPanelLabeledSwitchStyle`. Alasannya sama dengan Settings: NSSwitch yang nilainya
    berubah dari tempat lain saat terlihat bisa memicu siklus AttributeGraph.
  - **Warna:** glyph baris abu-abu (bukan aksen); warna hanya untuk arti: perlu tindakan
    amber, aktif emerald, error merah (`ZenithStatus`). Badge Beta jadi tag mono amber
    10/20/100 (`ZenithPanelTag`), tag Internal/External di Disk tag mono abu-abu. Warna data
    (grafik, sparkline, bar) tidak disentuh.
  - **Angka dan metadata:** hint shortcut dan hitungan kategori memakai mono; status Keep
    Awake memakai digit monospace. Sel suhu di System jadi garis, bukan blok abu-abu.
  - **Ikut berubah di island:** chip, saklar, dan segmen juga tampil di panel yang di-host
    island (section yang sama) serta di halaman WakaTime dan Fan Control island, karena
    view-nya sama.
  - **Dibiarkan:** banner update (`UpdateBanner`; update dimatikan di fork), editor otomasi
    dan pemilih ikon Keep Awake (dipakai juga di Settings), Quick Clipboard (panel terpisah),
    mixer dan slider, galeri wallpaper. Section WakaTime dan Wallpaper memang tanpa kartu
    sejak upstream/awal, tetap begitu.
  - **Belum diverifikasi visual:** app UI tidak dijalankan saat pengerjaan; tampilan terang
    dan gelap, Increase Contrast, dan panel di island perlu dicek di Mac.
- **Judul terminal readout dan notifikasi build Vercel gagal (branch
  `feat/terminal-title-vercel-alerts`):**
  - **Judul title bar:** `notchLockScreenTerminalTitle` (string, default kosong = `zenith — status`,
    ikut backup). Di Settings ada `TextField` di bawah "Show project names" dengan placeholder
    `zenith — status`, tombol ikon `desktopcomputer` yang mengisi `<nama komputer> — status`
    (dibaca lewat `SCDynamicStoreCopyComputerName` saat tombol ditekan, bukan
    `Host.current()` yang bisa memblokir), dan satu baris keterangan. Pembersihan ada di fungsi
    murni `NotchLockScreenTerminalSupport`: `titleInput` (saat mengetik: baris baru/tab/karakter
    kontrol jadi spasi, maks. 32 karakter) dan `title` (untuk readout: spasi beruntun dirapatkan,
    ujung di-trim, maks. 32, kosong = default); `computerTitle` memendekkan nama panjang dengan
    `…` supaya tetap berakhir `— status`. Judul ikut `NotchLockScreenTerminalConfiguration`, jadi
    dibaca sekali saat lock screen muncul.
  - **Notifikasi build gagal:** `notchVercelFailureAlerts` (default mati, ikut backup), saklar
    `ZenithSwitchRow` di opsi Vercel di bawah saklar live activity. Izin notifikasi diminta saat
    saklar dinyalakan (`Notifier.requestPermission()`, seperti fitur notifikasi lain); kirimnya
    lewat `Notifier.post`, yang diam-diam membuang notifikasi kalau izin tidak ada (pola WakaTime).
  - **Polling:** tidak ada loop kedua. `VercelService` tetap satu loop; kalau island atau lock
    screen sudah polling (15 dtk / 2 menit), alert memakai hasil yang sama. Kalau tidak ada yang
    menonton, loop jalan "di belakang": tiap 2 menit selama ada deployment
    QUEUED/INITIALIZING/BUILDING, tiap 10 menit kalau tidak (juga setelah gagal). Disinkronkan dari
    `AppDelegate.applicationDidFinishLaunching` (`syncFailureAlerts()`, di samping
    `syncGoalMonitoring()`), saat saklar berubah, dan saat token disimpan/dihapus.
    `NotchService.stop()` sekarang hanya berarti "island berhenti": alert tetap jalan di belakang.
    Live activity di island tetap hanya dari polling island.
  - **Yang dianggap gagal** (fungsi murni `VercelSupport.failureAlerts` + `failureBaseline`):
    deployment ERROR yang pada baca sebelumnya terlihat QUEUED/INITIALIZING/BUILDING, atau yang belum
    pernah terlihat, dibuat setelah baca sebelumnya (toleransi jam 60 dtk), dan sudah ERROR. Baca
    pertama setelah launch, setelah saklar dinyalakan, atau setelah token baru hanya menyimpan
    baseline, tidak pernah memberi notifikasi. Build yang sedang diikuti tetap diingat sampai 6 jam
    walau timnya hilang dari satu baca; ERROR yang belum pernah terlihat dan umurnya > 6 jam
    (mis. setelah Mac tidur lama) diabaikan; maksimal 3 notifikasi per baca. Tiap uid hanya sekali:
    32 uid terakhir disimpan di memori saja (tidak di UserDefaults; tidak perlu, karena baca
    pertama setelah launch tidak pernah memberi notifikasi).
  - **Isi notifikasi:** judul "Vercel build failed" (15 bahasa), isi `project · branch`. Pesan
    commit dan nama tim tidak pernah tampil. Klik membuka halaman inspector (build log); untuk itu
    `Notifier` dapat `post(title:body:opening:)` dan `zenithOpenURL(from:)` (hanya https), dan
    delegate notifikasi di `AppDelegate` membukanya lewat `NSWorkspace`. Edit di file upstream
    (`Notifier`, `AppDelegate`, `Defaults`) ditandai `// Zenith fork`.
  - **Belum diverifikasi:** notifikasi sungguhan, klik notifikasi, dan polling ke API Vercel
    asli belum dicoba (app UI tidak dijalankan, API Vercel tidak dipanggil). Tampilan field judul
    di Settings dan judul di lock screen juga belum dilihat.
- **Island terbuka, bahasa desain Settings (branch `feat/island-redesign`):** area terakhir
  yang masih bergaya upstream. Bahasa p441z.my.id diterjemahkan ke latar hitam island. Hanya
  visual; perilaku, layout, ukuran siluet, urutan dan daftar modul tidak berubah. Komponen di
  `UI/Notch/ZenithIslandChrome.swift`; file upstream hanya diberi kait bertanda
  `// Zenith fork`, kebanyakan di komponen bersama sehingga hampir semua halaman ikut berubah.
  File ini ikut dikompilasi ke test (`build.sh`, `TEST_SOURCES`) karena beberapa deklarasi
  island disalin ke test, jadi hanya boleh bergantung pada SwiftUI, AppKit, `ZenithTokens` dan
  `ZenithSwitch` (tidak boleh memakai `ZenithPanel*` atau tipe Notch).
  - **Nilai di atas hitam** (`ZenithIsland`): teks putih 0,92 / 0,55 / 0,35; garis putih 10%
    (22% saat hover/ditekankan, 45% dengan Increase Contrast); lift kartu putih 4%, hover 7%.
    Aksen diambil dari `NSColor.controlAccentColor`, karena island memberi `.tint(.white)`.
  - **Komponen bersama:** `NotchIconButton` jadi glyph abu-abu 0,55 → 0,92 saat hover, tile
    aksen 10/20/100 hanya kalau `selected` (pin, extra musik). `NotchPillButton` jadi pil
    bergaris (yang `prominent` garis lebih terang, tidak pernah diisi). Glyph `NotchEmptyView`
    di sumur hairline. `NotchControlSurface` (kartu System, AI, clipboard, kartu musik di Home,
    scratchpad, juga kartu panel yang di-host island dan preview island di Settings) jadi kartu
    hairline; entri clipboard yang di-pin memakai garis lebih terang (status, bukan pilihan, jadi
    tetap abu-abu). Cabang Liquid Glass macOS 26 tidak diubah.
  - **Radius:** radius kartu `NotchControlSurface` dipetakan ke langkah `ZenithRadius`
    (`ZenithIsland.radius`: 18 → 16, 14 → 12, 12 → 12). Ini mengganti keputusan lama "radius notch
    dipertahankan" khusus untuk kartu; bentuk island dan tombol tidak berubah. Clipboard ikut
    memetakan bentuk overlay-nya supaya sudut garis sorot sama dengan kartunya.
  - **Galeri section (pemilih modul):** glyph monokrom (warna identitas Music pink, Calendar merah,
    Timer ungu di galeri dihapus), section aktif memakai tile aksen 10/20/100 dengan centang aksen.
    Sorotan keyboard tetap terlihat: garis putih 40%, atau garis aksen 50% di tile aktif
    (penyimpangan kecil dari 20% supaya kursor terbaca). Shortcut ⌥⌘ mono 0,35, kolom cari jadi
    sumur hairline.
  - **Home:** sumur glyph shortcut jadi lingkaran hairline; yang aktif memakai aksen (pilihan
    tool di capture controls) atau warna statusnya dalam bentuk 10/20/100 (rekam dan mikrofon
    mati merah, Keep Awake amber, timer ungu), bukan lingkaran penuh.
  - **Halaman:** kartu yang mengisi abu-abu sendiri (Downloads, Notifications, Watch, event
    Calendar) jadi kartu hairline; tombol `.bordered`/`.borderedProminent` (izin Calendar,
    clipboard mati, Mixer, Camera) jadi `ZenithIslandOutlineButtonStyle`. Pilihan memakai aksen
    hanya saat dipilih: mode Timer (dulu garis bawah ungu), pad Scratchpad, zona drop Shelf di
    bawah file, hari terpilih di grid bulan dan strip minggu, tombol bulan, format warna di Tools
    (segmented native jadi `ZenithIslandSegmented`, hanya di island). Judul kartu AI, kartu System,
    label hari Calendar dan header GitHub jadi label mono kapital. Waktu, ukuran, persen, jumlah,
    dan hint ⌘N clipboard memakai mono. Start dan tombol bulat Timer jadi ungu 10/20/100.
  - **Saklar:** Downloads, Watch, audio capture controls (×0,88), dan opsi Tools di island
    memakai `ZenithIslandSwitchStyle` (`ZenithSwitch` diskalakan ke ukuran AppKit). Tools di HUD
    terpisah tetap NSSwitch (`zenithIslandSwitches(_:)`).
  - **Warna yang dibiarkan:** warna data dan arti tetap (`ZenithStatus`, warna kalender di batang
    event, lingkaran merah hari ini, mark dan tag agent dalam warna providernya (sekarang
    10/20/100), mark deployment Vercel, sampul album, maskot, visualisasi musik). Event yang
    sedang berlangsung memakai emerald (`ZenithStatus.success`, dulu `.mint`).
  - **Dibiarkan:** island tertutup dan live activity (termasuk `NotchActivityPicker`), lock
    screen, siluet, logika hover/buka, layout player musik, preview notifikasi yang dibuka dari
    strip (tinggi tombolnya diukur), tile Shelf (`UI/Shelf`, dipakai juga di luar island), tab
    panel yang di-host island (cabang notch ada di `MenuPanel/ZenithPanelChrome.swift`, di luar
    cakupan), halaman WakaTime (sudah memakai token dan chip panel), track Mixer, wash hover
    `NotchButtonStyle`, `NotchMeter`, label pengaturan Pomodoro (mono kapital terlalu lebar untuk
    barisnya), angka rounded di halaman AI (test `NotchAgentLimitReadingTests` mengukur lebar dengan
    font itu; angkanya sudah digit monospace).
  - Tidak ada test yang diubah. 51 pesan "AttributeGraph: cycle detected" di suite notch juga
    muncul di `dev` tanpa perubahan ini.
  - **Belum diverifikasi visual:** app UI tidak dijalankan saat pengerjaan. Perlu dicek di Mac:
    tiap halaman island, hover glyph, sorotan keyboard di galeri, Increase Contrast, Reduce
    Transparency, dan fokus keyboard pada saklar audio capture controls.
- **Island terbuka v2, komponen bento (branch `feat/island-v2`):** v1 nyaris tidak terasa,
  apalagi saat island tampil abu-abu tembus pandang di atas wallpaper (nilai 4%/10% hilang). v2
  mengganti komponennya, bukan sekadar mewarnai ulang, dengan acuan halaman Resume p441z.my.id.
  Hanya visual; perilaku, ukuran island, siluet, logika hover/buka, urutan dan ketersediaan modul
  tidak berubah. Island tertutup, live activity, dan lock screen tidak disentuh.
  - **Komponen baru** di `UI/Notch/ZenithIslandKit.swift` (ikut dikompilasi ke test lewat
    `TEST_SOURCES`, jadi hanya SwiftUI, AppKit, `ZenithTokens` dan `ZenithIsland`):
    `ZenithBentoGrid`/`ZenithBentoCell`/`ZenithBentoHeader`/`ZenithBentoMeta` (sel tanpa kotak,
    dipisah garis 1 pt putih 12% (40% dengan Increase Contrast) yang diletakkan di tengah celah lama,
    jadi tinggi halaman tetap; header label mono kapital 10 pt tracking 0,6 putih 45%, meta mono
    putih 35% di kanan), `ZenithBentoDivider`, `ZenithBentoButtonStyle` (wash 6% saat hover, tanpa
    lift/skala), `ZenithFigure` (angka besar SF Mono semibold tracking −0,5; satuan seperti `%`,
    `GB`, `h`, `↓`, `$` otomatis lebih kecil dan redup), `ZenithDataBar` (kapsul 3 pt, isi putih 85%
    di track 10%, warna hanya untuk peringatan/error, tanda pace opsional), `ZenithChartBar` dan
    `ZenithChart` (batang tipis, atas membulat, putih 25%, batang terkini/ditunjuk 90%),
    `ZenithSegmented` (wadah putih 7% + garis 8%, padding 3 pt, blok aktif putih 14% + garis, teks
    95%/50%, tanpa biru, meluncur dengan `matchedGeometryEffect` di kurva toggle, diam saat Reduce
    Motion), `ZenithStatusDot`/`ZenithStatusLine` (titik 6 pt warna arti, glow saat live, selalu
    ditemani kata), `ZenithCommandRow` (baris galeri), `zenithDropZone` (garis putus-putus),
    `ZenithIslandPrimaryAction`/`ZenithIslandPrimaryButtonStyle` (satu-satunya aksi padat: kapsul
    putih 90%, teks gelap), `ZenithIslandRoundControl`, `ZenithIslandSheet` (scratchpad di atas dot
    grid), `ZenithIslandTabBlock`, `ZenithIslandShortcutGlyph`, `ZenithIslandBand`, `ZenithSystemCell`.
  - **Nilai `ZenithIsland` dinaikkan:** teks utama 0,95, hairline 0,12 (kuat 0,28, Increase Contrast
    0,4), lift kartu 0 (tidak ada lagi), hover 0,06. `ZenithIslandTag` jadi kapsul bergaris mono 10,
    teks putih 50%, garis 15%; warna provider/status hanya sebagai titik 5 pt di dalamnya.
    `NotchPillButton` yang `prominent` jadi aksi padat putih.
  - **Baris atas island:** `NotchIconButton` jadi glyph polos 0,55 → 0,95 saat hover tanpa kotak
    (yang `selected` memakai aksen + garis kecil di bawahnya), `NotchBandMenuLabel` jadi judul mono 12
    + chevron tanpa chrome, `NotchBandBackButton` chevron + nama halaman tanpa chrome. `NotchMenuButton`
    tidak lagi memberi wash; label di dalamnya menerima status hover (`zenithIslandHoverTracked`).
  - **Galeri section jadi command palette:** baris glyph 16 pt monokrom, nama 13 medium, shortcut mono
    redup di kanan; dua kolom kalau lebar cukup, satu kolom di lebar tersempit. Hover 6%, section aktif
    garis aksen 2 pt di kiri + glyph aksen, kursor keyboard isi 10% + garis 1 pt 30%. Konstanta di
    `NotchLayout` (`NotchSupport.swift`, bertanda `// Zenith fork`): baris 32,5 pt, jarak 2 pt, kolom
    minimal 170 pt, maksimal 2 kolom, dan `sectionListHeight(budget:)` yang menjaga tinggi galeri sama
    dengan tiga baris tile upstream (preset: 8 baris = 274 pt), jadi island galeri tidak berubah tinggi.
    Cari, navigasi keyboard, paging per baris, urutan, ketersediaan tetap. Jarak geser trackpad ikut
    pitch baris baru (34,5 pt).
  - **Per halaman:** System dan AI jadi grid bento (angka mono besar, bar 3 pt, chart tipis; warna
    provider dibuat redup untuk beberapa agent, putih untuk satu; agent yang bekerja = titik emerald
    menyala). WakaTime di island punya layout sendiri (status line, segmented rentang, sel total,
    proyek/bahasa teratas, bahasa, grafik hari); kartu panel menu bar tetap. Vercel, GitHub, Downloads
    dan agenda Calendar jadi baris bergaris dengan titik status; warna kalender tetap di batang 3 pt.
    Notifications jadi sel bento (rail `NotchRail(dividers: true)`), Home dan Tools jadi glyph polos
    berlabel mono yang dipisah garis, player di Home di atas hairline. Timer: mode jadi segmented, jam
    mono putih, fase titik status, jeda/lanjut lingkaran hairline, Start aksi padat. Player musik:
    timeline kapsul 3 pt, waktu mono, glyph satu tingkat lebih ringan dengan play/pause sedikit lebih
    besar; layout, ukuran, cover, lirik dan antrean tetap. Files/Shelf: zona drop garis putus-putus.
    Scratchpad di atas dot grid tipis dengan pad aktif sebagai blok padat. Watch, Mixer, Camera ikut
    (bacaan mono, titik live, aksi padat). Clipboard tetap kartu (pratinjau konten), hanya chrome-nya
    ikut nilai baru.
  - **Tidak memakai bento penuh:** Clipboard (kartu adalah pratinjau isi dan diukur test), Mixer
    (fader vertikal), Camera (pratinjau gambar), Music (layout diikat kontrak ukuran), Calendar (grid
    bulan dan agenda punya layout sendiri; agenda jadi timeline bergaris), ruler Timer (gambar AppKit,
    tetap oranye). Aturan lain (mono, titik, garis, aksi padat) tetap diterapkan di sana.
  - **Test yang diubah:** `NotchAgentLimitReadingTests` mengukur bacaan dengan font mono baru (tujuan
    sama: bacaan muat). `NotchTests` (galeri): preset 8 baris bukan 3, 2 kolom (1 di lebar tersempit),
    8 baris = ruang 3 baris tile upstream, lebar baris minimal pakai `sectionColumnSpacing`.
    `NotchSectionPagingTests`: jarak geser dinyatakan dengan `NotchSectionScroll.rowStep`/`firstStep`,
    bukan angka pitch tile lama (94 pt).
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac, terutama di island
    abu-abu tembus pandang: galeri command palette (kolom, kursor keyboard, paging), grid System/AI,
    WakaTime, segmented Timer di baris atas (ViewThatFits ke menu bila sempit), label mono Home di
    bahasa panjang, Increase Contrast, Reduce Motion.
- **Live activity perintah terminal (branch `feat/command-activity`):** perintah zsh yang lama
  (`./build.sh --test`, `npm run build`, `docker build`, deploy) tampil di island tertutup selama
  jalan, lalu ✓/✗ dengan durasinya. Polanya sama dengan live activity Vercel. Kode di
  `Services/Command/CommandActivitySupport.swift` (murni: parsing, nama program, daftar abaikan,
  threshold, format jam, keputusan stale, blok `.zshrc`), `Services/Command/CommandActivityService.swift`,
  dan `UI/Command/CommandActivityViews.swift` (layout, strip, Settings). Teks di `Core/ZenithStrings.swift`
  (15 bahasa). Test di `Tests/CommandActivityTests.swift` (suite `command-activity`).
  - **Hook zsh** (`CommandActivitySupport.hookBlock`): blok bertanda `# >>> zenith command activity >>>`
    … `# <<< zenith command activity <<<` dengan `preexec` (lewat `add-zsh-hook`) dan `precmd` (dipasang
    paling depan di `precmd_functions` supaya `$?` masih milik perintahnya). Folder tujuan ditulis di
    blok saat dibuat, jadi build rilis dan Developer masing-masing menulis ke
    `<Application Support>/<bundle id>/Commands/` miliknya; memasang dari build lain mengganti blok yang ada.
    Hanya builtin (`print` ke `.tmp` lalu `zf_mv`, `$EPOCHREALTIME`), tanpa proses tambahan: diukur
    sekitar 0,24 ms per perintah. Tidak pernah mencetak apa pun. Baris yang diketik dengan spasi di
    depan dilewati. Kalau foldernya tidak ada (fitur mati) hook hanya mengecek folder itu.
  - **Format event:** `<id>.start.json` = `{"id":"<pid>-<n>","pid":…,"tty":"ttys003","start":<epoch>,
    "cmd":"…","cwd":"<nama folder>"}`; `<id>.end.json` = `{"id":…,"status":<exit>,"end":<epoch>}`.
    `cmd` dipotong 400 karakter. File start tetap ada selama perintah jalan (supaya app yang
    di-restart masih tahu), lalu dua-duanya dihapus saat end diproses.
  - **Service:** DispatchSource pada folder (bukan polling), parsing dan hapus file di queue sendiri,
    publish di main. Timer hanya untuk momen yang berubah sendiri (lewat threshold, lewat 1 jam, hasil
    habis) dan, selama ada yang jalan, cek tiap 30 dtk apakah shell-nya masih hidup (`kill(pid, 0)`):
    tab yang ditutup saat perintah jalan tidak pernah menjalankan `precmd`. Perintah > 12 jam dianggap
    stale. `.tmp` dan file asing > 1 menit dihapus. Jalan hanya kalau island jalan dan saklar nyala;
    dimatikan, foldernya ikut dihapus.
  - **Privasi:** island hanya menampilkan nama program (`npm run build` → `npm`, `./build.sh` tetap,
    path lain jadi nama file), melewati `VAR=x`, `sudo`, `env`, `nice`, `time`, `timeout`, `caffeinate`,
    `xcrun`, dan setup di depan (`cd x && …`). Argumen dibaca sekali untuk memilih program dan tidak
    disimpan. Nama folder hanya kalau "Show folder" nyala (default mati).
  - **Daftar abaikan:** editor, pager, `man`, `ssh`, `top`/`htop`, `tmux`, agent (`claude`, `codex`, …),
    shell database, REPL tanpa argumen (`python3`, `node`, `swift`), `tail -f`, `log stream`, `git log/diff`,
    dev server (`npm run dev`, `npm start`, `vite`, `next dev`, `docker compose up` tanpa `-d`, …).
    Tambahan sendiri lewat field "Also ignore" (`notchCommandIgnored`).
  - **Island:** `NotchCompactActivity.command`, urutan otomatis setelah vercel, ikut picker activity,
    tidak pernah jadi pasangan. Tidak punya halaman, jadi klik membuka home (`.controls`). Wing memakai
    geometri Watch seperti Vercel. Kiri: arc ungu (`ZenithStatus.progress`) yang berputar + jam mono
    (`0:42`, `3:05`, `1:02:10`); kanan: program (+N kalau ada perintah lain yang juga tampil,
    `· folder`). Yang tampil adalah perintah yang mulai paling awal, jadi tidak lompat saat terminal lain
    ikut. Hasil: ✓ emerald / ✗ merah + durasi total, 6 dtk.
  - **Gerak:** jam di `TimelineView(.periodic(from: start, by: 1))` yang hanya membungkus teksnya, digit
    mono, `.contentTransition(.numericText())`, slot selebar bacaan terlebar (`00:00`, `00:00:00` setelah
    1 jam) jadi wing tidak berubah selama berdetak. Arc berputar dengan `.animation(_:body:)` yang hanya
    menyentuh `rotationEffect` (tidak ikut animasi layout island). Selesai: arc mengecil dan memudar
    sementara ✓/✗ membesar masuk (warna berpindah lewat crossfade), lalu bump spring 1,0 → 1,12 → 1,0
    (`keyframeAnimator`, ~0,35 dtk). Masuk/keluar strip memakai transisi island yang sama dengan Vercel
    (`NotchStripHold`). Reduce Motion: arc diam, tanpa bump, ganti dengan fade.
  - **Settings:** kartu "Terminal commands" di Dynamic Island → Activity, di bawah Lock Screen. Saklar
    "Command activity" (`notchCommandActivity`, default mati), "Show after" 5/8/15/30 dtk
    (`notchCommandThreshold`, default 8), "Show folder" (`notchCommandShowsFolder`), "Also ignore". Bagian
    shell hook: status (terpasang / untuk build lain / belum / blok rusak) dan kapan event terakhir
    (`notchCommandLastEvent`, tidak terdaftar jadi tidak ikut backup), tombol "Install shell hook" (alert
    menampilkan blok persis sebelum menulis), "Copy snippet", "Remove hook". Tulisan ke `~/.zshrc`
    mengikuti symlink (dotfile manager), atomik, permission dipertahankan; blok dengan marker yang tidak
    lengkap tidak pernah disentuh. Judul kartu digambar sendiri (bukan `SettingsCard(title:)`) dan saklar
    memakai `ZenithSwitchRow`, jadi tidak masuk test search coverage.
  - Edit di file upstream hanya baris bertanda `// Zenith fork`: `NotchSupport` (case, urutan, judul,
    simbol), `NotchService` (`hasCommandActivity`, wing, kapsul, sync/stop, langganan `$activity`),
    `NotchView`/`NotchMirrorView` (strip), `NotchTimerStrip`/`NotchCapsuleViews` (tidak berpasangan),
    `NotchSettings` (kartu), `Defaults`. Test double `NotchMusicVisibilityTests` diberi
    `hasCommandActivity` dan `commandStripWing`.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Hook sudah dicoba di zsh terisolasi
    (`ZDOTDIR` sementara, bukan `~/.zshrc` asli): escape JSON, status exit, baris berawalan spasi, waktu.
    Perlu dicek di Mac: putaran arc dan roll digit di 120 Hz, morph ✓/✗ dan bump, lebar wing saat lewat
    1 jam, kapsul, alert install, dan perilaku di beberapa tab terminal.
- **Aksi foto di island (branch `feat/notch-transform`):** drag gambar ke island, pilih aksinya di
  sana. Kode di `Services/Notch/NotchPhotoActionsSupport.swift` (logika murni: target, format,
  resep, ukuran, nama file, bacaan), `NotchPhotoActionsEncoder.swift` (Image I/O dan Core Image,
  tanpa dependency baru), `NotchPhotoActionsService.swift` (sesi, antrean kerja, Vision, Shelf,
  clipboard) dan `UI/Notch/NotchPhotoActionsView.swift`. Teks di `Core/ZenithStrings.swift`
  (15 bahasa). Test di `Tests/PhotoActionsTests.swift` (suite `photo-actions`) dan tambahan di
  `ShelfDropRoutingTests`.
  - **Target drop:** kalau semua item yang di-drag adalah gambar (JPEG, PNG, TIFF, HEIC/HEIF, WebP,
    BMP, RAW kamera, PSD, AVIF; GIF/SVG/PDF tidak), pemilih zona menambah **Transform** dan, untuk
    satu gambar saja, **Remove Background**, di kanan zona yang sudah ada (Files, AirDrop, Optimize
    media). Hanya URL file; promise (mis. dari Photos) dan payload campuran tetap ke Shelf. Maksimal
    100 file. Non-gambar tidak berubah. `NotchDropTarget` dapat dua case baru;
    `NotchAirDropSupport.targets(files:airDrop:media:photo:)` menyusun urutannya.
  - **Syarat:** island menampilkan bagian Files (permukaannya tinggal di halaman Files, jadi tidak
    "meminjam" halaman seperti AirDrop) dan saklar `notchPhotoActionsEnabled` (default nyala, ikut
    backup) di Settings → Shelf, di bawah saklar AirDrop, memakai `ZenithSwitchRow`.
  - **Transform:** satu langkah per kali lewat segmented: Convert (JPG, PNG, WebP kalau Image I/O bisa
    menulisnya, HEIC; dicek dengan `CGImageDestinationCopyTypeIdentifiers()`, di macOS 15.5 WebP
    **tidak** bisa ditulis jadi pilihannya JPG/PNG/HEIC), Resize (sisi panjang 1080/2048/4096/Original,
    tidak pernah memperbesar, format sumber dipertahankan), Compress (JPEG 60/80/90) dan Strip (EXIF,
    GPS, TIFF, XMP dibuang; untuk format dan ukuran yang sama datanya disalin tanpa encode ulang
    lewat `CGImageDestinationCopyImageSource`, orientasi disimpan). Chip "Strip EXIF" bisa
    menyertakan strip di Convert/Resize/Compress. Kualitas lossy 0,9 untuk Convert/Resize.
  - **Warna:** gambar didekode dengan `MediaImageProcessing.decode` (thumbnail Image I/O yang sudah
    menerapkan orientasi) dan tetap di ruang warnanya, jadi profil sRGB/Display P3/Adobe RGB ikut
    tertanam. Ruang yang tidak bisa dibawa format (CMYK, Lab, tanpa tag) dikonversi ke sRGB, ruang
    extended/HDR ke Display P3. JPEG dengan alpha diletakkan di atas putih. Renderer
    `MediaService` sengaja tidak dipakai: ia menggambar ke bitmap device RGB yang menghilangkan P3.
    Yang dipakai ulang dari Media: decoder, batas ukuran render, staging + `installStagedOutput`
    (tidak pernah menimpa), `makeVisibleIfNeeded`, pembersih nama file.
  - **Remove Background:** `VNGenerateForegroundInstanceMaskRequest` (macOS 14+, offline), mask
    seukuran gambar dari `generateScaledMaskForImage`, lalu `CIBlendWithMask` ke latar transparan.
    Kanvas tetap seukuran aslinya (posisi subjek sama), PNG `nama-cutout.png`. Tanpa subjek: pesan
    "No subject found" dengan titik amber. Langsung jalan saat di-drop (tidak ada opsi).
  - **Hasil disimpan di samping file asli** (pola Optimize media), lalu ditambahkan ke Shelf kalau
    Shelf nyala. Folder yang tidak bisa ditulis atau folder sementara → `~/Downloads`. Nama tidak
    pernah menimpa: `photo.jpg`, lalu `photo-1.jpg`, `photo-2.jpg`; akhiran `-2048`, `-q80`,
    `-clean`, `-cutout`. Hasil bisa Reveal in Finder, Copy (URL file; satu hasil juga datanya, supaya
    bisa di-paste sebagai gambar) dan di-drag keluar dari thumbnail (semua hasil sekaligus).
  - **Kerja di luar main thread:** antrean serial `userInitiated`; progres per tahap file dikirim ke
    main thread, cancel di antara tahap. Drop lain ke Files/Optimize menutup hasil; job yang masih
    jalan diteruskan diam-diam dan hasilnya tetap masuk Shelf.
  - **Gerak** (semua lewat sistem animasi SwiftUI, hanya transform/opacity/trim/mask, tinggi halaman
    tidak berubah): zona drop masuk berurutan 40 ms (skala 0,97→1, opacity, glyph naik 5 pt), zona
    yang ditunjuk spring (response 0,34, damping 0,84) dengan glyph naik 3 pt dan garis lebih terang;
    thumbnail mendarat dari skala 0,86 dan offset −14 dengan spring (0,36/0,86), lapisan panel kanan
    menyusul tiap 40 ms; antarfase cross-fade + offset 6 pt di kurva reveal; saat proses ada shimmer
    (gradien di mask yang digeser offset) dan cincin progres `trim` yang meluncur antar nilai;
    selesai: centang digambar dengan `trim`, ukuran hasil menghitung naik (view `Animatable`);
    Remove Background: subjek muncul di atas papan catur (`Canvas` + `.drawingGroup()`) lewat cakram
    radial lembut yang membesar (satu nilai, 0,75 dtk, sekali per sesi). Tombol: tekan 100 ms ke
    0,96, lepas dengan spring. Reduce Motion: semuanya jadi cross-fade.
  - Edit di file upstream bertanda `// Zenith fork`: `NotchService` (properti target foto,
    `acceptsPhotoDrop`, begin/update/end/accept drop, `canAccept`, `stop`), `NotchFilesView` (zona
    foto, permukaan aksi, sel zona drop baru `NotchDropZoneCell` untuk semua zona), `ShelfSettings`,
    `Defaults`.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Encode, strip, profil warna dan komposisi
    cutout dites di suite `photo-actions`; Vision dicoba manual di gambar contoh sistem (bukan di test).
    Perlu dicek di Mac: lima zona drop di lebar compact (teks dua baris), drop sungguhan dari Finder,
    animasi di 120 Hz, panel opsi di bahasa panjang, drag hasil keluar, Copy ke Figma/Slack.
- **Halaman About tentang Zenith (branch `feat/about-zenith`, menggantikan `feat/about-portfolio`):**
  versi portofolio terlalu banyak bercerita tentang pembuatnya, jadi About sekarang menjelaskan Zenith
  dan fiturnya, dan pembuatnya hanya sedikit (seperti kartu "Made by" sebelumnya). View di
  `UI/Settings/ZenithAboutPage.swift`; data dan logika murni (`ZenithAbout`: headline, angka, daftar
  tile dan rutenya; `ZenithBento`: kolom dan baris grid; `ZenithRevealQueue`: jadwal masuk tile;
  `ZenithMaker`; decrypt) di `ZenithAboutSupport.swift`, ikut dikompilasi ke test (suite `settings`,
  `Tests/ZenithAboutTests.swift`). `AboutSettings` di `SettingsView.swift` tetap hanya memanggil
  `ZenithAboutPage`.
  - **Urutan:** hero (ikon app dari bundle 80 pt, cadangannya `BrandBadge`; "Zenith"; versi mono,
    badge beta, commit khusus build dev), headline "Your Mac, at its ⟨peak/notch/music/agents/builds/
    files⟩" (sengaja **tetap Inggris** di semua bahasa), subtitle berkilau (diterjemahkan), tiga angka
    (jumlah `AppFeature.allCases` = isi halaman Features, sekarang 83; jumlah `AppLanguage` = 15;
    0 akun/tanpa pelacakan), bagian Features (judul decrypt + satu baris) dengan grid bento, lalu
    "Made by" (kartu lama: foto, nama, chip hijau "Building Zenith" kalau muat di samping nama, peran,
    `@p441z`, bio, tombol bulat situs/GitHub/LinkedIn/Instagram), kartu Satu Visual, kartu repo,
    "Review introduction", `UpdatesView` kalau `updatesEnabled`, copyright.
  - **Bento:** 10 tile, `ZenithAbout.areas`. Dua kolom kalau lebar ≥ 460 pt, satu kolom kalau lebih
    sempit; Dynamic Island dan System selebar dua kolom (irama: lebar, dua pasang, lebar, dua pasang).
    Tile sebaris setinggi tile tertinggi; tile yang sendirian melebar penuh. Tiap tile: SF Symbol di
    kotak abu-abu, judul tebal, satu baris abu-abu, chip mono. Klik membuka fitur pertama yang masih
    terpasang; kalau tidak ada satu pun, membuka halaman Features di fitur pertama:
    Dynamic Island → `.notch`; AI agents → Content › Agents; For developers → Content › Vercel
    (tanpa island: Command Bar); Files & photos → Shelf (lalu Clipboard); Capture → Screenshot
    (lalu Recorder, OCR, Color picker); System → Monitor (lalu Keep Awake); Windows & Dock → Switcher
    (lalu Window Layout, Dock, Quit on close); Mouse & keyboard → Smooth scrolling (lalu fitur mouse
    lain, Snippets, Super Key); Sound → Mixer (lalu Output, Mic mute); Utilities → Quick panel (lalu
    Scratchpad, Cleaner, Uninstaller, Homebrew).
  - **Teks:** `ZenithStrings.about` (15 bahasa) menggantikan `ZenithStrings.maker`: subtitle, label
    angka, judul/keterangan Features, judul, keterangan dan chip tiap tile, dan teks kartu pembuat
    (`madeBy`, `role`, bio, status, keterangan studio, "Website"). Nama produk (Claude, Codex, Vercel,
    GitHub, WakaTime, AirDrop, Homebrew) tetap sama di semua bahasa dan dikunci test.
  - **Dihapus:** headline "I build for the web…", angka tahun/disiplin, linimasa Now, marquee Stack,
    bio yang naik per kata (`TextRenderer`), serta 13 SVG stack (`si-swift`, `si-react`, dst.). SVG
    sosial (`si-github`, `si-linkedin`, `si-instagram`, simple-icons 11.15.0, CC0-1.0) tetap.
  - **Gerak:** blok masuk naik 8 pt + opacity di kurva reveal, jeda 60 ms; blok di bawah lipatan
    menunggu di-scroll (`onScrollVisibilityChange` macOS 15; cadangan 2 dtk hanya kalau scroll view
    tidak pernah melapor). Tile bento masuk satu per satu saat terlihat: naik 12 pt + opacity, jarak
    60 ms dalam urutan baca, tile yang terlihat belakangan menunggu antrean. Kata headline decrypt
    tiap 3 dtk, judul bagian decrypt saat muncul, subtitle berkilau, angka menghitung naik, hover tile,
    tombol sosial dan kartu naik 2 pt dengan spring (0,3/0,8), panah tile bergeser 2 pt. Gerak terus-
    menerus berhenti saat halaman ditinggal atau jendela Settings tertutup/tertutupi
    (`SettingsWindowVisibility`). Reduce Motion: hanya fade.
  - **Belum diverifikasi di app:** UI app tidak dijalankan. Tata letak dicek lewat render statis
    (`ImageRenderer`, salinan halaman dengan stub) di 480–760 pt, terang/gelap, Inggris, Jerman,
    Jepang, Rusia. Perlu dicek di Mac: animasi masuk tile saat di-scroll di 120 Hz, decrypt, kilau
    subtitle, hover tile, klik tile ke halaman yang benar (dan ke Features kalau fitur tidak
    terpasang), ikon app asli di hero, tombol "Review introduction" (tidak bisa dirender statis).
- **Balas pesan dari island (branch `feat/notifications-reply`):** notifikasi Messages dan WhatsApp
  bisa dibalas langsung dari island, polanya seperti Droppy. Kode di
  `Services/Notifications/ZenithReplySupport.swift` (murni, ikut `TEST_SOURCES`: app mana yang dapat
  baris balas, escape string AppleScript, skrip Messages, parsing daftar chat, resolusi pengirim ke
  chat, link `whatsapp://`, rencana dan fallback, `ZenithReplyHold`), `ZenithReplyChannels.swift`
  (protokol `ZenithReplyChannel`, channel Messages dan WhatsApp, helper AX `ZenithAX`),
  `ZenithReplyComposer.swift` (state baris balas, draft, status, keyboard), `UI/Notch/ZenithReplyRow.swift`
  dan `UI/Settings/ZenithReplySettings.swift`. Teks di `ZenithStrings.reply` (15 bahasa). Test di
  `Tests/ReplyTests.swift` (suite `reply`).
  - **Sumber data:** notifikasi dibaca lewat Accessibility dari banner `com.apple.notificationcenterui`
    (`NotchNotificationReaderCore`). Yang tersedia hanya label: nama app (header), judul (pengirim
    atau nama grup), subjudul, isi, plus `AXIdentifier` banner (UUID, bukan id chat). Bundle id sumber
    diresolusi dari nama app (`NotchNotificationSources`) dan sekarang dibuka lewat
    `NotchNotificationService.sourceBundleIdentifier(for:)`. Tidak ada nomor telepon atau id chat,
    kecuali kalau judulnya sendiri berupa nomor/email (kontak yang belum disimpan).
  - **Messages (`com.apple.MobileSMS`):** di antrean sendiri (NSAppleScript tidak pernah di main thread),
    skrip pertama membaca maksimal 200 chat: id, nama, dan handle/nama/nama lengkap tiap peserta
    (tanpa isi pesan). Resolusi: judul berupa nomor/email → chat 1:1 orang itu (iMessage > any > RCS >
    SMS), kalau tidak ada dikirim langsung ke handle lewat akun iMessage; nama → grup dengan nama itu,
    atau chat 1:1 yang nama/nama lengkap pesertanya sama (tanpa beda huruf besar, aksen, spasi, tanda
    arah). Dua grup atau dua handle berbeda dengan nama sama = ambigu, tidak pernah ditebak. Lalu
    `send … to chat id …` atau `send … to participant … of (1st account whose service type = iMessage)`.
    Error −1743/−1744 → status "Allow Zenith to control Messages" + tombol "Grant access" (membuka
    Privacy › Automation). Gagal lain atau chat tidak ketemu → balasan disalin (ditandai
    `org.nspasteboard.ConcealedType`, riwayat clipboard Zenith melewatinya) dan percakapan dibuka dari
    notifikasinya (cadangan: buka Messages).
  - **WhatsApp (`net.whatsapp.WhatsApp`, yang terpasang di Mac ini; juga `desktop.WhatsApp`):** saklar
    "Send WhatsApp replies automatically" (`notchWhatsAppAutoReply`, default nyala, ikut backup) di
    Settings › Dynamic Island › Notifications, dengan caption bahwa ini bisa rusak setelah update
    WhatsApp. Nyala: aktifkan WhatsApp (luncurkan kalau perlu, tunggu jadi frontmost), buka chat (judul
    berupa nomor → `whatsapp://send?phone=<digit>&text=<encoded>`; nama → field pencarian lewat AX
    subrole `AXSearchField` atau ⌘F, isi nama lewat AXValue atau paste, tekan hasil pertama yang
    labelnya sama dengan nama, cadangan ↓ + Return), lalu verifikasi header percakapan di panel kanan
    memuat nama itu. Teks ditaruh lewat AXValue di composer (`AXTextArea` terbawah yang bukan field
    cari), dicek dibaca ulang, cadangan paste lewat `TransientPaste` (clipboard dipulihkan). Return
    dikirim lewat CGEvent hanya saat WhatsApp frontmost; terkirim = composer melepas teksnya dalam 2
    dtk, kalau tidak, sekali lagi lewat paste. Sukses → app sebelumnya diaktifkan lagi. Batas waktu
    total 15 dtk, timeout AX 0,5 dtk. Gagal di tahap mana pun → WhatsApp dibuka dengan teks sudah di
    composer (atau lewat link untuk nomor), atau teks disalin, dan statusnya "Couldn’t send
    automatically. WhatsApp is open …". Mati: nomor → link dengan teks terisi; nama → buka WhatsApp +
    salin. Tanpa Accessibility (seharusnya tidak terjadi karena notifikasi butuh itu) → "Grant access".
  - **UI:** tombol balas (`arrowshape.turn.up.left`) di header sel notifikasi halaman island dan di
    baris aksi preview yang ditahan pointer. Baris balas: field kapsul dengan placeholder layanan
    ("iMessage…", "WhatsApp…"), tombol kirim bulat warna layanan (biru iMessage #0A84FF, hijau WhatsApp
    #25D366; redup saat kosong, spinner saat mengirim) dan tombol emoji (`NSApp.activate()` lalu
    `orderFrontCharacterPalette`, karena palet mengetik ke app aktif). Return kirim, Esc tutup (di
    halaman lewat `setPageLayer(.notifications)`, di preview lewat `onExitCommand`). Setelah kirim,
    baris pesan crossfade blur ke "You: …" warna layanan, jam jadi waktu relatif ("now", "6 sec. ago",
    `RelativeDateTimeFormatter` per bahasa), teks yang terkirim memudar + blur di atas field yang
    sudah kosong. Status lain (fallback, izin) tampil amber di baris yang sama. Tidak ada tombol
    lampiran (tidak ada jalurnya di dua app ini).
  - **Keyboard:** sama dengan Command Bar di island: `NotchPanel.acceptsKeyFocus = true` + `makeKey()`
    (panel non-activating, app depan tidak kehilangan aktif), dilepas lewat `resignPanelKey()` saat baris
    di preview ditutup dan island tidak terbuka.
  - **Gerak:** preview tumbuh dengan spring pertumbuhan island sendiri (`NotchMotion.growingHeight`)
    karena `surfaceSize` menambahkan `ZenithReplyHold.extraHeight` (baris 30 pt + jarak 8 pt, plus
    selisih tinggi status kalau lebih panjang dari pesan). Kontrol baris masuk blur 10→0 + opacity +
    skala 0,96→1, spring (0,36/0,86), jeda 40 ms per kontrol. Status `.blurReplace`, kurva smooth 0,35
    dtk. Reduce Motion: hanya fade. Semua animasi SwiftUI.
  - **Ditahan selama menulis:** `ZenithReplyHold` membuat island tidak menutup saat pointer keluar atau
    app lain aktif (`keepsWorkingSurface`) dan preview tidak dilepas (`releaseNotification`). Klik di luar
    menutup baris (island terbuka: lewat monitor island; preview: monitor global milik composer), begitu
    juga aktivasi app lain yang bukan akibat pengiriman. Setelah ditutup, `hover(false)` dipanggil supaya
    pointer yang sudah pergi menutup island seperti biasa.
  - **Privasi:** draft dan balasan terkirim hanya di memori, hilang bersama notifikasinya. Tidak ada log;
    pesan error AppleScript tidak dibaca (bisa mengutip skrip, jadi balasannya). Hanya label chat yang
    dibaca dari Messages.
  - **Izin:** `NSAppleEventsUsageDescription` sudah ada, kalimatnya ditambah "send the replies you write in
    the Dynamic Island to Messages" di `Info.plist` dan 14 `InfoPlist.strings`. Entitlement
    `com.apple.security.automation.apple-events` sudah ada, tidak diubah. Accessibility memakai izin
    yang sudah dipakai notifikasi.
  - Edit di file upstream bertanda `// Zenith fork`: `NotchService` (`keepsWorkingSurface`,
    `surfaceSize`, `releaseNotification`), `NotchNotificationService` (`sourceBundleIdentifier`),
    `NotchNotificationsView` (tombol, slot pesan, slot waktu, baris), `NotchSettings` (saklar), `Defaults`.
  - **Belum diverifikasi di app:** UI app tidak dijalankan dan tidak ada pesan sungguhan yang dikirim.
    Skrip AppleScript sudah dicompile (`osacompile`, tanpa dijalankan) dan escape-nya diuji bolak-balik
    lewat skrip `return "…"`. Alur AX WhatsApp ditulis dari pola AX umum, belum dicoba di jendela
    WhatsApp Catalyst. Perlu dicek di Mac: lihat laporan "cek manual" di PR.
- `PanelMetricColor` sengaja belum dipetakan: dipakai untuk tingkat status (bar
  hijau/kuning/merah) sekaligus warna identitas kategori (GPU cyan, memori mint, disk
  kuning). Dipetakan per pemakaian saat redesign panel menu bar.

## Branch dan remote

```
upstream/main  repo asli (fetch saja; push ke upstream sengaja dimatikan)
      │
      ▼
main           cermin murni upstream/main. JANGAN commit langsung ke sini.
      │  merge (bukan rebase)
      ▼
dev            semua pekerjaan fork
      ├── feat/…   branch fitur, di-merge balik ke dev
```

| Remote     | URL                                               |
|------------|---------------------------------------------------|
| `origin`   | https://github.com/satuvisual/zenith.git          |
| `upstream` | https://github.com/vorssaint/vorssaint-utils.git  |

Konfigurasi lokal (perlu di-set ulang kalau clone baru):

```sh
git remote add upstream https://github.com/vorssaint/vorssaint-utils.git
git remote set-url --push upstream DISABLED-no-push-to-upstream
git branch --set-upstream-to=upstream/main main
git config rerere.enabled true      # ingat cara menyelesaikan konflik
git config rerere.autoupdate true
git config pull.rebase false
git config merge.ours.driver true   # dipakai .gitattributes: README.md versi kita selalu menang
```

## Sync dari upstream (target: seminggu sekali)

```sh
# 1. Ambil update dan majukan main. Harus selalu fast-forward.
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main

# 2. Lihat apa yang berubah sejak sync terakhir.
BASE=$(git merge-base dev main)
git log --oneline "$BASE"..main
git diff --stat "$BASE" main

# 3. File yang diubah KEDUA pihak, jadi calon konflik.
comm -12 <(git diff --name-only "$BASE" main | sort) \
         <(git diff --name-only "$BASE" dev  | sort)

# 4. File UI baru dari upstream. Git tidak menganggapnya konflik, tapi tampilannya
#    masih gaya Vorssaint, jadi perlu dicek apakah harus disesuaikan ke desain fork.
git diff --name-only --diff-filter=A "$BASE" main -- Sources/Vorssaint/UI

# 5. ID dan URL brand baru yang dibawa upstream (di luar header copyright).
#    Teks UI ditangani langkah 7; yang di sini perlu dicek manual
#    (com.vorssaint.*, vorssaint.com, path, sudoers, dll.).
git diff "$BASE" main -- Sources | grep -E '^\+' | grep -v 'Copyright (C)' | grep -i vorssaint

# 6. Merge ke dev, selesaikan konflik.
git switch dev
git merge main

# 7. Ganti "Vorssaint" di teks UI dan dokumen baru, lalu validasi.
#    Dokumen bawaan upstream yang konflik: ambil versi upstream, lalu jalankan
#    tool dokumen lagi (git checkout --theirs <file>).
#    File yang dihapus Zenith (SPONSORS.md, TRADEMARKS.md, docs/assets, docs/demo.gif,
#    .github/FUNDING.yml) dan diubah upstream: cukup `git rm` lagi.
python3 Tools/zenith-rebrand-strings.py --check || python3 Tools/zenith-rebrand-strings.py --apply
python3 Tools/zenith-rebrand-docs.py --check || python3 Tools/zenith-rebrand-docs.py --apply
./build.sh && ./build/Zenith --selftest && ./build.sh --test
git push origin dev
```

Kalau `merge --ff-only` di langkah 1 gagal, berarti ada commit yang nyasar ke `main`.
Pindahkan commit itu ke `dev` dulu, jangan di-force.

## Strategi supaya sync tetap ringan

1. **Design tokens dulu.** Upstream menulis style langsung di banyak file
   (per 18 Nov 2026: `.font(.system(size:))` di sekitar 137 file, `cornerRadius:`
   di sekitar 130 file; hanya sekitar 9 file yang memakai `Theme`/`PanelSurface`).
   Redesign ditempuh lewat lapisan token: pertama ganti hardcode jadi token dengan
   nilai yang **sama persis** dengan upstream (tampilan tidak berubah), baru setelah itu
   ubah nilai token ke gaya p441z. Refactor token yang netral ini juga bisa diajukan
   ke upstream (buka issue dulu, sesuai CONTRIBUTING); kalau diterima, beda fork
   dengan upstream jadi jauh lebih kecil.
2. **Kode fork di file sendiri.** Fitur baru sebaiknya di file atau folder baru;
   perubahan pada file upstream dibuat sekecil mungkin.
3. **Perbaikan yang berguna umum dikirim ke upstream** sebagai PR, supaya tidak
   menjadi beban sync.
4. **Merge, bukan rebase**, dan sync rutin. Konflik kecil yang sering lebih murah
   daripada konflik besar yang jarang.

## Build dan tes

```sh
./build.sh                    # build optimized (seperti CI), tanpa menyentuh keychain
./build/Vorssaint --selftest
./build.sh --test             # unit test; --list-tests / --test-suite=NAMA
./build.sh --dev              # varian Developer; membuat identitas signing lokal
                              # (Tools/setup-signing.sh) kalau belum ada
./build.sh --dev --install    # pasang dan buka "Vorssaint (Developer)" di /Applications
```

Toolchain yang sudah terverifikasi di Mac ini (18 Nov 2026, upstream `89d26260`):
Command Line Tools, Swift 6.1.2, SDK macOS 15.5, tanpa Xcode. Build sekitar 3 menit,
selftest OK, `--test` OK (122.933 pengecekan). Ada 4 warning `NSImage` non-Sendable
(ShelfService, ClipboardThumbnailImage, WallpaperSection) yang muncul karena SDK 15.5
lebih lama dari SDK yang dipakai upstream; ini bukan regresi dari fork. Ikon adaptif
dilewati karena `actool` hanya ada di Xcode 26+, dan Dock memakai AppIcon.icns.

## Keputusan yang belum diambil

- Auto-update: dimatikan dulu, atau diarahkan ke rilis `satuvisual/zenith`.
- Feedback dan sharing: dimatikan, atau diganti layanan sendiri.
- Struktur token desain (nama, skala, tempat file).
- Lokasi kode khusus fork (folder sendiri atau prefix nama file).
- Daftar fitur tambahan selain notch.
