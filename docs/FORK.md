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
