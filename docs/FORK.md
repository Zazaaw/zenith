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
- **Export tracker (branch `feat/export-tracker`):** render DaVinci Resolve, rekaman OBS, dan export
  foto tampil di island tertutup selama filenya tumbuh, lalu ✓ dengan ukuran dan durasinya, plus notice
  kapsul, suara, dan notifikasi kalau island tidak kelihatan. DaVinci Resolve versi gratis tidak punya
  scripting dari luar, jadi deteksinya lewat folder yang diawasi, bukan lewat app. Kode di
  `Services/ExportTracker/ExportTrackerSupport.swift` (murni: filter, state machine, produser, format),
  `ExportWriterProbe.swift` (libproc: siapa yang membuka file dan untuk apa), `ExportTrackerService.swift`
  (FSEvents, sampling, pengumuman), `UI/Notch/ExportTrackerViews.swift` (layout, mark, strip) dan
  `UI/Notch/ExportTrackerSettings.swift`. Teks di `ZenithStrings.exportTracker` (15 bahasa). Test di
  `Tests/ExportTrackerTests.swift` (suite `export-tracker`). Support dan probe ikut `TEST_SOURCES`.
  - **Folder:** satu `FSEventStreamCreate` dengan event per file (`FileEvents`, `IgnoreSelf` supaya tulisan
    Zenith sendiri tidak pernah datang, latensi 0,5 dtk), rekursif. Default `~/Movies` dan `~/Desktop` nyala,
    `~/Downloads` ada di daftar tapi mati. Disimpan sebagai `~/…` (`notchExportFolders` + `notchExportFoldersOff`)
    supaya backup terbaca di Mac lain; folder di drive lain tetap path absolut. Folder di dalam folder lain
    tidak diawasi dua kali; drive yang belum dipasang dilewati dan diambil lagi saat `didMount`.
  - **File yang dihitung:** mov, mp4, mxf, m4v, mkv (format lama OBS), braw, wav, aac, mp3, jpg/jpeg, png,
    tif/tiff, heic, psd, pdf. Dilewati: nama berawalan `.` atau `~$`, akhiran sementara di mana pun di nama
    (`.part`, `.partial`, `.tmp`, `.temp`, `.crdownload`, `.download`), folder tersembunyi, `CacheClip`,
    `.gallery`, `ProxyMedia`, `OptimizedMedia`, dan isi paket/library (`.fcpbundle` (render files Final Cut
    di ~/Movies), `.photoslibrary`, `.lrdata`, `.app`, dll.). File di bawah ukuran minimum (1/10/50/200 MB,
    default 1) tidak tampil. Maksimal 200 file dilacak sekaligus.
  - **State machine** (`ExportTrackerSupport.Tracker`, jam palsu di test): event folder mulai melacak file;
    selama ada yang dilacak ukurannya dibaca `lstat` tiap ~1 dtk, tanpa itu tidak ada timer sama sekali.
    File jadi "exporting" kalau tumbuh dan sudah melewati minimum (waktunya dihitung dari birthtime kalau
    < 24 jam, jadi file yang ketahuan telat tetap benar durasinya). Selesai kalau ukurannya diam 4 dtk **dan**
    tidak ada proses yang masih membukanya untuk menulis; selama masih terbuka (render lambat, rekaman di-pause)
    dicek lagi tiap detik. Kalau kernel tidak bisa menjawab, ukuran diam 4 dtk saja yang memutuskan. File yang
    mendarat utuh (copy) dibuang diam-diam setelah 4 dtk; file yang sudah selesai tidak dilacak lagi 10 menit
    kecuali ukurannya berubah, dan kalau menulis lagi < 8 dtk setelah ✓ ia lanjut dari awal yang sama.
    ✓ tampil 8 dtk.
  - **Siapa yang menulis** (`ExportWriterProbe`): `proc_listpidspath` mencari proses yang membuka file itu
    (seluruh sistem, ~0,2 dtk, jadi hanya saat atribusi dan cek selesai tanpa penulis yang dikenal), lalu
    `PROC_PIDLISTFDS` + `PROC_PIDFDVNODEPATHINFO` membaca mode buka (`FWRITE`) per fd. Setelah penulisnya
    ketahuan, cek selesai hanya membaca fd proses itu. Hanya penulis yang dihitung (pembaca seperti Spotlight
    atau QuickLook tidak). Atribusi dicoba sampai 5 kali dengan jeda 2, 4, 8, 16 dtk. Nama dari `.app` terluar
    di path executable (XPC di dalam app ikut app-nya): DaVinci Resolve, OBS, Final Cut Pro, Compressor, iMovie,
    Premiere Pro, After Effects, Media Encoder, Lightroom/Lightroom Classic, Photoshop, Photos, Capture One,
    Affinity Photo, Pixelmator Pro, CapCut, ffmpeg, HandBrake, Screenshot, QuickTime Player, Logic Pro,
    GarageBand, Audacity; app lain tampil dengan namanya sendiri. Penulis yang bukan export (Finder, cp, ditto,
    rsync, browser, iCloud `bird`, Dropbox, dll.) dan Zenith sendiri membuat file itu dilepas.
  - **Batch foto:** gambar yang mendarat utuh (atau tumbuh < 2 dtk) di satu folder dikumpulkan jadi satu
    export kalau ≥ 3 dan ada app yang bisa mengekspor gambar sedang jalan (dicari dari `proc_listallpids`,
    hanya `.app`, app foto didahulukan). Tanpa app seperti itu dianggap copy dan tidak pernah tampil. Batch
    selesai 4 dtk setelah gambar terakhir: "24 images · 84 MB".
  - **Island:** `NotchCompactActivity.export`, urutan otomatis setelah `command`, ikut picker, tidak pernah jadi
    pasangan, wing geometri Watch (56–150 pt). Kiri: ikon app penulis (dari bundle-nya) atau glyph SF berwarna
    palet island (film untuk file tanpa penulis), lalu ukuran mono di slot selebar `00.0 GB`; kanan: "Exporting"
    (atau "Recording" untuk OBS/QuickTime/Screenshot) abu-abu, nama file putih yang terpotong di tengah, `+N`.
    Selesai: ✓ emerald + ukuran akhir di kiri, durasi mono + nama di kanan (`4.2 GB` | `12:31 Wedding.mov`).
    Kapsul melayang: satu baris. Klik membuka Finder dengan file terpilih. Beberapa export: yang terbaru + `+N`;
    yang baru selesai didahulukan selama ✓-nya. Ukuran yang tumbuh dipublish terpisah (`live`), jadi island
    hanya di-layout ulang saat export mulai/selesai/bertambah, bukan tiap detik. Rate (MB/s) hanya dibacakan
    VoiceOver; di strip tidak muat.
  - **Gerak:** ukuran `.contentTransition(.numericText())` di lebar tetap; mark bernapas pelan (skala 1 → 0,88,
    opacity 1 → 0,7, 1,1 dtk bolak-balik) lewat `.animation(_:body:)` yang hanya menyentuh transform/opacity;
    selesai: mark mengecil keluar dan ✓ membesar masuk lalu bump spring 1,0 → 1,12 → 1,0 (`keyframeAnimator`,
    sama dengan command). Reduce Motion: diam, ganti dengan fade.
  - **Notice dan notifikasi:** `ZenithNotice.Kind.export` (prioritas 1, kedaluwarsa 30 dtk): judul "Export
    finished"/"Recording saved", subjudul "nama · 4.2 GB · DaVinci Resolve" (terpotong di tengah), thumbnail
    QuickLook, centang, klik = Reveal in Finder. Suara `Glass` 0,5 (`notchExportSound`, default nyala). Kalau Mac
    terkunci atau island tidak menampilkan feedback (tersembunyi, full screen), notifikasi macOS lewat
    `Notifier.post(title:body:revealing:)` (baru, di samping `opening:` milik Vercel; klik = file terpilih di
    Finder), saklar "Notify when done" (`notchExportNotify`, default nyala; izin diminta saat diaktifkan).
  - **Settings:** kartu "Exports" di Dynamic Island → Activity, di bawah Terminal commands. Saklar "Export
    tracker" (`notchExportTracker`, default mati), daftar folder (nama Finder + path, saklar per folder, tombol
    hapus, "Add Folder…" lewat open panel, folder yang hilang ditandai), segmented ukuran minimum, saklar suara
    dan notifikasi. Judul digambar sendiri dan saklar `ZenithSwitchRow`/`ZenithSwitchStyle`, jadi tidak masuk
    test search coverage. Semua opsi terdaftar (ikut backup).
  - Edit di file upstream hanya baris bertanda `// Zenith fork`: `NotchSupport` (case, judul, modul, simbol,
    urutan), `NotchService` (`hasExportActivity`, wing, kapsul, sync/stop, langganan `$activity`),
    `NotchView`/`NotchMirrorView` (strip), `NotchTimerStrip`/`NotchCapsuleViews` (tidak berpasangan),
    `NotchSettings` (kartu), `Notifier` + `AppDelegate` (notifikasi yang membuka Finder), `Defaults`, `build.sh`,
    `Tests/MetricsTests.swift`. Test double `NotchMusicVisibilityTests` diberi `hasExportActivity` dan
    `exportStripWing`. File fork yang ikut diubah: `ZenithNoticeSupport/Service/View` (kind `.export`).
  - **Izin:** ~/Movies tidak dilindungi TCC; ~/Desktop dan ~/Downloads akan memicu prompt macOS sekali saat file
    pertama di sana dibaca. Teks `NSDesktopFolderUsageDescription` belum menyebut fitur ini.
  - **Belum diverifikasi di app:** UI app tidak dijalankan. Probe libproc dan state machine dicoba dengan file
    sungguhan yang ditulis bertahap (test). Di program scratch (bukan app) FSEvents + tracker + probe dicoba
    dengan proses lain yang menulis 4 × 0,8 MB lalu diam 6 dtk dengan file masih terbuka: tetap running, ✓
    sekitar 1 dtk setelah file ditutup; `.hidden.mov` dan `.tmp` dilewati, mp4 yang mendarat utuh tidak tampil.
    Ikon app, strip, notice dan notifikasi belum dicoba di Mac.
    Perlu dicek: render DaVinci Resolve sungguhan (apakah menulis langsung ke nama akhir atau lewat nama
    sementara lalu rename, apakah atribusinya "DaVinci Resolve", jeda tulis saat efek berat), rekaman OBS
    (mkv/mp4/hybrid mp4, pause, remux otomatis), export Lightroom/Photos (batch), wing di 120 Hz, bump ✓,
    prompt TCC Desktop.
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
- **Watermark di aksi foto (branch `feat/watermark`):** Faiz fotografer event; foto klien perlu diberi
  watermark sekaligus banyak sebelum dikirim. Watermark jadi langkah kelima Transform dan bisa ikut langkah
  lain dalam satu pass. Kode di `Services/Notch/NotchWatermarkSupport.swift` (murni: style, preset, store
  logo, geometri, pola tile, pilihan putih/hitam), `Services/Notch/NotchWatermarkRenderer.swift` (Core
  Graphics + Core Text), `UI/Notch/NotchWatermarkView.swift` (kontrol island) dan
  `UI/Settings/NotchWatermarkSettings.swift` (kartu Settings). Teks di `ZenithStrings.watermark` (15 bahasa,
  disisipkan setelah blok photo actions). Test di `Tests/WatermarkTests.swift` (suite `watermark`).
  - **Isi:** logo, teks, atau logo + teks. Logo default bintang Satu Visual sebagai path vektor (path
    maskot `NotchMascotGeometry.star`, dinormalisasi ke kotak 1×1), jadi tajam di resolusi berapa pun. Logo
    sendiri: PNG/JPEG/HEIC/TIFF/WebP (dibaca di ukuran tujuan lewat thumbnail Image I/O), PDF (halaman 1
    digambar sebagai vektor) atau SVG (`NSImage`, juga vektor). Teks satu baris SF Pro (`NSFont.systemFont`,
    bobot Regular/Medium/Semibold/Bold), default `© Satu Visual`, maks. 80 karakter.
  - **Ukuran relatif:** semua persen dari sisi pendek gambar. `scale` = tinggi mark (2–30%, default 8);
    teks sendiri 0,62 × tinggi itu, teks di samping logo 0,4 × dengan jarak 0,3 ×; `margin` 0–15% (default 3).
    Posisi grid 3×3: margin hanya di sisi yang disentuh; kalau ruang kurang dari 2 × margin, margin menyusut
    supaya mark tetap di dalam gambar. Opacity 10–100% (default 80).
  - **Warna:** Auto memilih putih atau hitam dari luminans relatif (WCAG) area di bawah mark (seluruh
    gambar untuk tile), dibaca dari salinan sRGB 8×8; ambang 0,179 (titik kontras putih = hitam). Atau putih,
    hitam, warna sendiri (`#RRGGBB`, dari Settings), atau warna asli logo (hanya logo sendiri). Logo selain
    "warna asli" di-tint lewat transparency layer + blend `sourceIn`, jadi bentuk logo tetap. Bayangan lembut
    opsional: gelap di bawah mark terang, glow terang tipis di bawah mark gelap.
  - **Pola tile** (untuk proof): kisi melalui titik tengah gambar, baris naik ke kanan 30°, baris
    selang-seling bergeser setengah langkah, jarak `max(2 × unit, 0,6 × lebar)` / `max(2,2 × unit,
    1,4 × tinggi)`; hanya salinan yang bisa menyentuh gambar yang digambar. Opacity diterapkan sekali ke seluruh
    pola (satu transparency layer), jadi tumpang tindih tidak menebal.
  - **Render** (`NotchPhotoEncoder.transform`, kait di file fork sendiri): decode sekali di ukuran output →
    `prepared` (ruang warna yang bisa dibawa format, latar putih untuk JPEG) → watermark di resolusi penuh dalam
    bitmap yang sama ruang warnanya (P3 tetap P3, 16-bit tetap 16-bit, alpha hanya kalau ada) → encode. EXIF,
    GPS, TIFF, IPTC ikut kecuali Strip/chip Strip EXIF dipilih; orientasi sudah diterapkan ke piksel (output
    selalu orientasi 1). Kalau watermark gagal digambar, file **tidak** ditulis (error), jadi tidak ada foto klien
    yang lolos tanpa watermark. Logo dibaca sekali per batch. Strip + watermark selalu encode ulang (jalur
    salin lossless hanya untuk Strip tanpa watermark). Semua di antrean kerja foto yang sudah ada (di luar main
    thread).
  - **Nama:** akhiran `-wm` setelah akhiran langkah: `photo-wm.jpg`, `photo-2048-wm.jpg`, `photo-q80-wm.jpg`,
    `photo-clean-wm.png`; tidak pernah menimpa (`photo-wm-1.jpg`), lewat `uniqueOutputURL` yang sudah ada.
  - **UI island:** di samping segmented Convert/Resize/Compress/Strip ada tile lembut 30×26 (glyph
    `signature`) untuk langkah Watermark; saat dipilih tile itu beraksen 18/24/100 dan segmented tidak punya
    blok aktif. Area opsi berganti lewat `.zenithMorph`. Opsi: pemilih posisi 3×3 (titik 3,5 pt di tile lembut
    40×40, posisi terpilih titik aksen 7,5 pt yang meluncur dengan `matchedGeometryEffect` + spring; redup saat
    tile), dua slider tipis gaya `ZenithDataBar` (track 3 pt, knob 10 pt yang membesar 1,3× saat ditahan, angka
    mono di kanan; glyph scale/opacity, bukan label, supaya muat di lebar compact ±205 pt), lalu baris 24 pt:
    menu preset (lebar tetap 112 pt + `.fixedSize()`, aturan menu borderless issue #569; nama preset atau
    "Unsaved", isinya preset dengan centang, Save as preset…, Delete preset, Show
    logo/teks/keduanya, Edit text…, Weight, Margin 0/1/2/3/5/8%, Choose logo…, kembali ke bintang), tile warna
    (swatch; menu Auto/White/Black/Custom/warna logo), tile pola tile, tile bayangan. Save as preset dan Edit
    text mengganti baris itu dengan field teks inline (✓/✕, Return/Esc) lewat `.zenithMorph`. Di langkah lain
    ada chip "Watermark" di samping "Strip EXIF" (di lebar sempit keduanya jadi glyph saja lewat
    `ViewThatFits`). Tinggi pane watermark ±162 pt, muat di konten compact 180 pt.
  - **Pratinjau langsung:** di gambar pertama, selama sesi Transform membawa watermark (sebelum hasil ada).
    Mark digambar dengan renderer yang sama ke overlay transparan seukuran thumbnail (≤ 480 px) di antrean
    preview sendiri (`userInteractive`, hanya permintaan terbaru yang digambar, logo di-cache per file), lalu
    ditumpuk di atas thumbnail dengan frame yang sama. Muncul/hilang dengan fade 0,2 dtk; ganti isi tanpa animasi.
  - **Preset:** `notchWatermarkPresets` (JSON `[NotchWatermarkPreset]`; `""` = dua preset awal "Client proof"
    (logo + teks, tile, opacity 32%, tanpa bayangan) dan "Instagram" (logo + teks, kanan bawah, 5%, 85%) dalam
    bahasa app; `"[]"` = memang kosong), `notchWatermarkStyle` (JSON style yang sedang diedit, disimpan 0,35 dtk
    setelah berhenti berubah), `notchWatermarkDefaultPreset` (id preset yang diterapkan ke setiap drop
    Transform baru, `""` = tidak ada). Ketiganya String di `registeredDefaults`, jadi ikut backup dan divalidasi
    `valueLooksRight`. Nama sama (tanpa peduli huruf besar) menimpa preset itu di tempat; maks. 24 preset, nama
    maks. 40 karakter. Decode toleran: field yang hilang pakai default, nilai di luar rentang di-clamp.
  - **Logo di container:** "Choose logo…" (NSOpenPanel) menyalin file ke
    `<Application Support>/<bundle id>/Watermarks/logo-<uuid>.<ext>` lewat `PrivateFileStore` (folder 0700, file
    0600), maks. 40 MB; preferensi hanya menyimpan nama file. Logo yang tidak dipakai style atau preset mana pun
    dihapus. Backup tidak membawa file logo: di Mac lain preset jatuh ke bintang, dan Settings menampilkan
    peringatan amber "This logo isn’t on this Mac".
  - **Settings:** Section "Watermark" di Settings → Shelf, tepat di bawah saklar photo actions (hanya kalau
    saklar itu nyala): Default preset, logo (thumbnail, Choose logo…, kembali ke bintang), teks, Show, Weight,
    Color (+ `ColorPicker` untuk Custom), saklar Soft shadow (`ZenithSwitchRow`), keterangan. Mengedit watermark
    yang sama dengan island (`NotchPhotoActionsService.watermark`).
  - Edit di file upstream bertanda `// Zenith fork`: `Defaults` (3 kunci + registrasi), `ShelfSettings` (satu
    baris section), `build.sh` (`TEST_SOURCES`), `Tests/MetricsTests.swift` (suite). File fork yang ikut berubah:
    `NotchPhotoActionsSupport` (kind `.watermark`, `recipe.watermark`, akhiran), `NotchPhotoActionsEncoder`
    (langkah watermark, parameter `logo`), `NotchPhotoActionsService` (state, preset, logo, preview),
    `NotchPhotoActionsView` (tile langkah, chip, overlay preview; `NotchPhotoPressStyle` jadi internal).
  - **Test:** `WatermarkTests` (suite `watermark`): teks 15 bahasa (apostrof melengkung, tanpa em dash, 9 nama
    posisi), akhiran nama per langkah, matematika penempatan (unit, margin, blok logo/teks, sembilan posisi,
    margin menyusut, mark lebih lebar dari gambar), geometri tile (salinan di tengah, sudut 30° naik ke kanan,
    semua bisa menyentuh gambar, menutup sudut, tanpa duplikat), auto-contrast (luminans, ambang, area atas/
    bawah gambar terbagi), encode/decode style dan preset (round trip, parsial, clamp, nama logo berbahaya,
    preset awal, ganti nama sama, batas), registrasi backup, store logo (nama aman, 0600, prune, PDF), render
    (P3, ukuran, tanpa alpha baru, hitam di putih/putih di hitam, opacity, warna tetap, teks, overlay, tile di
    keempat kuadran, alpha tetap), dan end to end di folder sementara (JPEG P3 miring → tegak ukuran penuh,
    profil P3, EXIF/GPS tetap, mark di pojok yang benar, `photo-wm-1.jpg`, resize + watermark + strip
    `wide-1080-wm.jpg`, PNG strip + watermark `flat-clean-wm.png`). UserDefaults test memakai
    `com.vorssaint.tests.watermark`.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac (120 Hz): tile langkah di
    samping segmented (lebar compact, bahasa panjang), pemilih titik dan slider (drag, VoiceOver adjustable),
    menu preset dan menu warna di island, field inline (apakah island menerima ketikan dan Esc), NSOpenPanel
    dari island (island mungkin menutup; sesi tetap), pratinjau yang ikut slider, chip di lebar sempit, kartu
    Settings terang/gelap, hasil di foto RAW/HEIC sungguhan dari kamera, batch 100 foto (memori, waktu), logo
    SVG/PDF sungguhan dan logo berwarna dengan "warna asli".
- **Notice kapsul ala Droppy (branch `feat/island-notices`):** event sistem yang singkat tumbuh dari
  island tertutup jadi pil lebar, tampil beberapa detik, lalu menyusut balik. Yang diambil dari
  referensi (`reference/live-activities-*.mp4`) hanya pola dan geraknya, tanpa ikon atau nama Droppy.
  Kode di `Services/Notch/ZenithNoticeSupport.swift` (murni, ikut `TEST_SOURCES`: model, antrean,
  threshold baterai + hysteresis, setelan, ukuran, format), `Services/Notch/ZenithNoticeService.swift`
  (`ZenithNoticeCenter`: sumber, antrean, jendela, gerak, interaksi), `UI/Notch/ZenithNoticeView.swift`
  (bentuk, isi, aksesori) dan `UI/Settings/ZenithNoticeSettings.swift`. Teks di
  `ZenithStrings.notices` (15 bahasa). Test di `Tests/ZenithNoticeTests.swift` (suite `notices`).
  - **Ukuran:** di frame referensi kapsulnya 824 × 162 px (rasio ±5:1) dan judul 13 pt menempatkannya
    di sekitar 400 × 79 pt. Zenith memakai rentang brief: lebar 380 pt (mengikuti island kalau island
    lebih lebar, maks. 420, selalu 12 pt dari tepi layar), baris 62 pt. Glyph/thumbnail 30–32 pt,
    ring 30 pt, saklar Low Power 50 × 28, inset 16, jarak 12, judul semibold 13 putih 95%, subjudul
    11,5 putih 55%.
  - **Bentuk:** island yang melayang (capsule di layar tanpa notch) jadi pil penuh (radius = setengah
    tinggi, hairline putih 12%). Island yang menggantung dari tepi atas (layar ber-notch) tidak bisa
    jadi pil penuh tanpa menaruh teks di bawah kamera, jadi bagian atasnya tetap rata dengan bahu
    island dan barisnya di bawah kamera dengan sudut bawah 31 pt (setengah tinggi baris); tinggi total
    `stripHeight + 56`. Bentuk island sendiri (`NotchShape`) tidak disentuh.
  - **Jendela sendiri:** kapsul digambar di `NotchPanel` terpisah satu level di atas island (masih di
    bawah menu native), selebar gabungan outline island dan kapsul, dan hanya ada selama notice
    tampil. Jadi bentuk, transisi, strip dan halaman island tidak berubah (area agent A); kapsul mulai
    dari outline island saat itu (`surfaceSize`, `surfaceShift`, `capsuleBody` untuk capsule, bahu dan
    `surfaceRadius` untuk notch) dan kembali ke outline island saat itu juga.
  - **Gerak:** bentuk memakai spring (response 0,4, damping 0,82) hanya pada ukuran dan posisi
    (frame + bahu/radius). Isi masuk 0,14 dtk setelah mulai (±60% tumbuh): glyph, judul, subjudul,
    aksesori, masing-masing blur 10 → 0 + opacity 0,24 dtk dengan jeda 40 ms; keluar urutan terbalik,
    lalu bentuk menyusut (spring 0,34 tanpa pantul) dan jendela ditutup. Ring terisi dengan `trim`
    0,6 dtk, centang download digambar dengan `trim` (lingkaran lalu centang), saklar Low Power meluncur
    dengan spring. Update di tempat (notice yang sama) memakai `blurReplace`. Reduce Motion: kapsul
    langsung di ukuran akhir dan hanya fade 0,2 dtk.
  - **Antrean (`ZenithNoticeQueue`):** satu notice sekaligus. Prioritas: baterai sangat lemah 5,
    lemah 4, headphone 3, charger 2, batas charge dan download 1; sama prioritas = urutan datang.
    Notice dengan key sama di-coalesce (yang menunggu diganti di tempat, yang tampil diperbarui dan
    timernya diulang). Charger dicolok membuang peringatan baterai lemah yang menunggu; dicabut
    membuang hint 80%; status charger terbaru yang menang. Yang prioritasnya lebih tinggi memotong yang
    sedang tampil. Maks. 6 menunggu (yang terlama dengan prioritas terendah dibuang). Kedaluwarsa
    kalau menunggu island terlalu lama: baterai 90 dtk, headphone/charger 12 dtk, lainnya 30 dtk.
  - **Kapan boleh tampil:** island jalan, `showsSystemFeedback` (ikut "hidden until hover" dan
    "show activity"), tertutup, tidak peeking/drag/capture controls/command bar/picker activity, tidak
    full screen, dan tidak ada notice kecil island yang sedang tampil (volume dll. selesai dulu). Kalau
    tidak boleh, dicoba lagi tiap 0,5 dtk sampai kedaluwarsa. Saat tampil: island terbuka, peek, drag,
    full screen, atau notice kecil prioritas ≥ 3 (volume, brightness, layout keyboard, mic) langsung
    menyuruhnya pergi.
  - **Durasi dan interaksi:** 4 dtk (baterai lemah 6 dtk). Pointer di atas kapsul menahannya, lalu
    1,5 dtk setelah pointer pergi. Klik di tempat lain (monitor global + lokal, tanpa izin baru) atau
    swipe ke atas di trackpad (kalau gesture island nyala, pakai `NotchGestureSupport`) menutupnya.
    Klik di kapsul menjalankan aksinya lalu menutup. Jendela menerima klik pertama. Isi diumumkan ke
    VoiceOver.
  - **Notice dan sumbernya:**
    - *Baterai 20% / 10%* (merah, saklar Low Power): dari `powerChanged` island (IOPS). Hanya saat tidak
      dicolok. Judul "20% Battery", subjudul "Click for Low Power Mode" atau "Low Power Mode is on"
      (saklar amber, ikut berubah lewat `NSProcessInfoPowerStateDidChange` saat tampil).
    - *Charger dicolok/dicabut*: "Charging · 46%" (bolt + ring hijau) / "On Battery · 46%" (steker,
      ring hijau/amber/merah menurut sisa).
    - *Charge mencapai 80%* (hint kesehatan): "Charging · 80%", daun + ring hijau, subjudul "Unplugging
      around here is easier on the battery". Hanya saat dicolok, tidak di 100%.
    - *Headphone/speaker Bluetooth tersambung*: dari `NotchAccessoryConnectionMonitor` (hanya simbol
      audio dari katalog aksesori: AirPods, AirPods Pro/Max, headphone, speaker). Baterai dibaca dari
      `SystemMonitor` (`peripheralBatterySample`, bacaan terendah dengan nama yang sama). Kalau belum
      ada, ditunggu 1,6 dtk; bacaan yang datang kemudian mengisi ring di tempat. Tanpa bacaan, tanpa
      ring. Aksesori lain (keyboard, mouse, dll.) tetap memakai notice kecil.
    - *Download selesai*: dari `NotchDownloadService.onArrival`. Thumbnail QuickLook
      (`QLThumbnailGenerator`, ikon Finder sampai siap), nama file (dipotong di tengah), "1.6 MB ·
      Downloads" (nama folder dari Finder), centang hijau. Klik = Reveal in Finder.
    - *Focus*: **tidak dibuat.** Zenith belum bisa mendeteksi Focus (tidak ada pembaca Focus/DND di
      kode; notice yang ada adalah layout keyboard), dan macOS tidak memberi tahu app pihak ketiga.
  - **Hysteresis baterai (`ZenithBatteryNoticeState`):** bacaan pertama hanya baseline (Mac yang sudah
    di bawah 20% saat app dibuka diam sampai naik lagi). Tiap threshold bunyi sekali, lalu baru aktif
    lagi setelah charge kembali 3 poin melewatinya (≥ 23% untuk 20%, ≤ 77% untuk 80%). Satu bacaan yang
    melompati dua threshold (setelah sleep) hanya memberi peringatan yang lebih dalam. Colok-cabut di
    level yang sama tidak mengulang peringatan.
  - **Low Power Mode:** perlu admin (`pmset -a lowpowermode 1`). Helper fan control
    (`Sources/FanControlHelper`, root, XPC dengan code requirement) **tidak** ditambah: harus menambah
    method di protokol XPC bersama dan versi helper, memperluas daemon root dari kipas ke setelan daya,
    dan hanya jalan untuk yang sudah menyetujui helper Fan Control (mendaftarkannya sekarang = prompt
    admin yang tidak diharapkan). Jadi klik membuka System Settings › Battery
    (`x-apple.systempreferences:com.apple.Battery-Settings.extension`), tempat saklarnya ada. Tidak ada
    prompt admin, `pmset` tidak pernah dijalankan.
  - **Setelan:** kartu "Notices" di Dynamic Island → Activity, di bawah Terminal commands. Judul digambar
    sendiri (bukan `SettingsCard(title:)`), saklar `ZenithSwitchStyle`/`ZenithSwitchRow`, jadi tidak
    masuk test search coverage. Baris: Low battery (15/20/25/30%, default 20), Very low battery
    (5/10/15%, default 10), Charge reaches (80/85/90/95%, default 80), Charger connected or removed,
    Headphones connected, Download finished. Semua default nyala, terdaftar di `registeredDefaults`
    (ikut backup). Baris baterai hanya muncul di Mac ber-baterai. Saklar dimatikan = island kembali ke
    notice kecilnya untuk event itu; toggle event lama (Battery, Accessories, Downloads di grid
    Activity) tetap jadi gerbang utama (`NotchSupport.routes`).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchService.powerChanged` (lapor ke center,
    notice kecil dilewati kalau kapsul menggantikannya; reaksi maskot tetap), `onArrival` download,
    `NotchAccessoryService.handleConnection`, `NotchSettings` (kartu), `Defaults`, `build.sh`
    (`TEST_SOURCES`), `Tests/MetricsTests.swift` (suite). Tidak ada case activity baru, jadi test double
    tidak berubah.
  - **Belum diverifikasi di app:** UI app tidak dijalankan. Tampilan akhir dicek lewat render statis
    (`ImageRenderer`, stub center) versi melayang dan menggantung. Perlu dicek di Mac: morph dari island
    (notch dan capsule) dan baliknya ke strip activity yang sedang tampil, blur masuk/keluar di 120 Hz,
    hover menahan, klik di luar, swipe ke atas, klik membuka Battery settings/Finder, AirPods sungguhan
    (kapan bacaan baterainya datang), thumbnail QuickLook, island yang terbuka karena hover saat
    pointer melewati kapsul, Increase Contrast, Reduce Motion, dan beberapa display.
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
- **Island ala Droppy, fase 1A fondasi (branch `feat/island-droppy-foundation`):** bentuk, transisi,
  navigasi dan warna bersama untuk island terbuka, dari rekaman referensi di `reference/` (dianalisis
  per frame; pola dan kualitas gerak saja, tanpa aset atau nama). Strip tertutup, live activity,
  `NotchAgents*` dan `NotchNotifications*` tidak disentuh (dikerjakan agent lain).
  - **Ukuran yang diukur** (rekaman 2x, piksel dibagi 2): bahu cekung island terbuka hampir
    lingkaran ~27 pt (lebar dan tinggi sama); sudut bawah cocok dengan sudut 34 pt (galat RMS < 1 pt
    untuk lingkaran maupun sudut kontinu); tinggi island tertutup 32 pt (cocok dengan notch, jadi
    skala 2x benar); pil tab 24 pt × ~110 pt, berjarak ~15 pt di bawah island; tab terpilih kapsul
    abu-abu; transisi halaman: blur puncak ~70–100 ms, tajam lagi ~270 ms.
  - **Siluet** (`UI/Notch/ZenithIslandShape.swift`, `ZenithIslandSilhouette`; kait di `NotchShape.path`
    dan batas `NotchLayout.surfaceRadius`): sudut bawah island terbuka 34 pt (dulu 28), sudut kontinu
    (smoothing 0,6 ala Figma: busur di tengah, ujung melandai ke sisi). Bahu tetap selebar 14 pt
    (lebar island, jendela dan semua halaman tidak berubah) tapi turun 22 pt sebagai busur elips, jadi
    di tiap baris melebar lebih jauh dari lingkaran 14 pt yang lama. Smoothing sengaja 0 untuk bahu:
    smoothing membuat kurva menempel ke tepi layar dan bahunya justru tampak lebih tipis. Profil baru
    masuk perlahan sesuai tinggi (smoothstep 72 → 128 pt), jadi strip tertutup (≤ 72 pt) tergambar
    persis seperti upstream (dicek test titik per titik) dan resize terlihat sebagai morph. Tiap path
    punya elemen yang sama di semua ukuran (3 kurva per sudut) karena Core Animation menginterpolasi
    keyframe path per elemen. Bahu 27 pt penuh seperti referensi butuh island lebih lebar dan inset
    halaman lebih besar (`horizontalInset`), jadi belum diambil; perlu keputusan Faiz. (Sudah diambil
    belakangan, lihat "Bahu island penuh + mirror kamera otomatis".)
  - **Radius konsentris** (`ZenithIslandKit.swift`): `ZenithIsland.innerRadius(depth:outer:minimum:)`
    = luar − inset (minimal 4). `islandRadius` 34, `pageInset` 14 (halaman 28 pt dari tepi jendela,
    14 di antaranya bahu), `cardRadius` 20, `nestedRadius(padding:)` untuk isi kartu. Kartu besar
    upstream (`ZenithIsland.radius` ≥ 16) sekarang 20, bukan 16.
  - **Bento jadi kartu lembut:** API `ZenithBentoGrid` sama, rendernya berubah: tiap sel di atas
    `zenithIslandSoftCard()` (isi putih 6%, garis 8%, garis 40% dengan Increase Contrast, radius 20),
    berjarak `spacing` (celah tempat garis pemisah dulu), jadi tinggi halaman tetap. Wash hover
    `ZenithBentoButtonStyle` default radius 17 (konsentris, 3 pt di dalam kartu). Yang ikut berubah:
    System dan Agents. `ZenithBentoDivider` dan `NotchRail(dividers:)` tetap garis.
  - **Morph + blur** (`UI/Notch/ZenithIslandMorph.swift`): SwiftUI `AnyTransition.zenithMorph`
    (keluar blur 0 → 10, opacity 1 → 0, skala 1 → 0,97; masuk kebalikannya), `zenithMorph(reduceMotion:)`
    (fade biasa), `ZenithMorph.animation` (spring response 0,38, damping 0,86) dan modifier
    `.zenithMorph(on: value)`. Ganti halaman island sendiri terjadi di window host (upstream mematikan
    animasi SwiftUI di sana dan crossfade layer hosting dengan `CATransition` sambil siluet ber-spring
    lewat keyframe CA), jadi kait di `NotchCanvas.transitionContent(.replace)` menambah blur 0 → 10 → 0
    dan skala 1 → 0,97 → 1 (puncak di 30%, total 0,34 dtk, crossfade 0,22 dtk) memakai filter blur dan
    key transform milik animasi arrival, sehingga apa pun yang mengakhiri arrival ikut mengakhirinya.
    Hanya untuk halaman terbuka (`ZenithMorph.morphs(height:)`); bacaan strip tertutup tetap fade 0,18.
    Reduce Motion: crossfade biasa (dulu langsung tanpa transisi). Berlaku untuk semua `.replace`:
    ganti modul, galeri ↔ halaman, detail ↔ halaman, mode Timer.
  - **Pil tab** (`UI/Notch/ZenithIslandDock.swift`): kapsul hitam 26 pt, 12 pt di bawah island (di
    bawah tombol mengambang bawah kalau ada), isi Home (`.controls`), Files (`.files`, badge jumlah item
    Shelf, mono, angka beranimasi), halaman yang sedang tampil kalau bukan keduanya (glyph modul dalam
    warnanya), dan galeri section. Tab terpilih kapsul abu-abu yang meluncur (`matchedGeometryEffect`)
    dengan glyph berwarna modul. Muncul saat island hampir terbuka (setengah `arrivalTime`) dengan spring
    morph + blur, tiap tab menyusul 40 ms; pergi dengan easeIn 0,16 dtk saat island menutup; ikut
    spring tinggi island saat halaman berganti. Di-host di jendela island sendiri: hosting view kedua di
    `NotchQuickAccessContainer` (stage sama dengan tombol mengambang), jadi ikut display island,
    Mission Control, relokasi, dan klik di pil adalah klik di island (tidak menutupnya). `hitTest`
    hanya menerima klik di pil (frame dilaporkan SwiftUI); koridor hover dari tepi bawah island sampai
    bawah pil supaya pointer yang menyeberang celah tidak keluar dari island. Jendela memesan ruang di
    bawah hanya selama pil tampil; `quickAccessBottomInset` geometri ikut, jadi island paling tinggi
    tetap menyisakan ruang. Tombol galeri di baris atas island dihapus (`sectionsButtonInRow = false`,
    termasuk preview di Settings); galeri tetap lewat pil, menu klik kanan, ⌘K dan shortcut ⌥⌘ modul.
    Tooltip memakai judul modul + shortcut (tanpa teks baru).
  - **Warna modul** (`UI/Notch/ZenithIslandPalette.swift`): Faiz memilih island berwarna. Tiap
    `NotchModule` punya warna identitas (`zenithTint`, tingkat 400): Home biru #60A5FA, Mixer indigo
    #818CF8, Music rose #FB7185, Clipboard violet #A78BFA, Captures cyan #22D3EE, Files teal #2DD4BF,
    System hijau #4ADE80, Tools fuchsia #E879F9, Calendar merah #F87171, Notifications amber #FBBF24,
    Timer ungu #C084FC, Camera emerald #34D399, Downloads sky #38BDF8, Scratchpad kuning #FACC15,
    Agents oranye #FB923C, Watch lime #A3E635, WakaTime pink #F472B6, Vercel #E5E7EB, GitHub #CBD5E1.
    Warna identitas tidak pernah berarti status. `ZenithIslandGlyphTile` (Kit): glyph berwarna di tile
    lembut (isi 18%, garis 24%; 30%/55% dengan Increase Contrast), tanpa tint = monokrom. Galeri dan
    ikon Home belum dipindah ke tile ini (fase berikutnya).
  - **File baru yang ikut `TEST_SOURCES`:** `ZenithIslandShape.swift`, `ZenithIslandMorph.swift`,
    `ZenithIslandPalette.swift`. `ZenithIslandDock.swift` hanya app (butuh `NotchService`).
  - **Test:** baru `ZenithIslandTests` (suite notch): strip tertutup identik dengan rumus upstream,
    profil terbuka (bahu lebih dalam, sudut lebih besar, body dan bounding box sama, sudut halaman tetap
    di dalam), elemen path sama di semua ukuran dan tanpa NaN, radius konsentris, jangkauan morph,
    palet unik. Diubah: `NotchTests` "an open island keeps its full corner radius" sekarang
    membandingkan dengan `ZenithIslandSilhouette.openCornerRadius` (dulu 28), tujuannya sama.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac (120 Hz): bentuk bahu
    dan sudut bawah saat buka/tutup dan ganti halaman, blur saat ganti halaman (terutama Music ↔ Home
    dan galeri), pil tab (posisi, jarak 12 pt, muncul/hilang, geser pilihan, badge Shelf, klik tidak
    menutup island, hover menyeberang celah, bersama tombol mengambang bawah), kartu System/Agents,
    Reduce Motion, Increase Contrast, island kaca (pil tetap hitam).
- **Langkah Claude Code live di halaman AI (branch `feat/agents-live-claude`):** halaman AI di island
  dibangun ulang dengan pola dan gerak tampilan agents Droppy (referensi
  `reference/droplet-spot-agents-*.webm`; aset tidak diambil, mark agent tetap milik Zenith). Sumber
  datanya hook resmi Claude Code, polanya sama dengan live activity perintah terminal. Kode di
  `Services/AgentUsage/ClaudeHooksSupport.swift` (murni: parsing event, model sesi, strip, script hook),
  `ClaudeHooksSettings.swift` (merge/hapus di `settings.json`, pembaca/penulis JSON berurutan),
  `ClaudeHooksService.swift` (watcher folder, publish), `UI/Notch/NotchAgentsLiveView.swift` (halaman),
  `UI/Notch/NotchAgentsLiveStrip.swift` (island tertutup) dan `UI/Settings/NotchAgentsClaudeHooksSettings.swift`.
  Teks di `ZenithStrings.claudeHooks` (15 bahasa). Test di `Tests/ClaudeHooksTests.swift` (suite `claude-hooks`).
  - **Hook:** script `sh` `<Application Support>/<bundle id>/zenith-claude-hook.sh` (di samping folder event,
    bukan di dalamnya). Command di `settings.json`: `[ -f '<script>' ] && exec /bin/sh '<script>'; exit 0`,
    jadi kalau script hilang (Zenith dihapus) Claude Code tetap tidak melihat error. Satu `awk` membaca
    JSON dari stdin (tanpa `jq`, tanpa network), menulis `.<pid>.tmp` lalu `mv` ke `<pid>.json` di
    `<Application Support>/<bundle id>/Agents/`. Tidak pernah mencetak ke stdout, selalu exit 0. Diukur
    sekitar 5 ms per event (`Write` 2 MB sekaligus sekitar 0,2 dtk untuk menghitung barisnya). Kalau
    foldernya tidak ada (fitur mati) script langsung keluar.
  - **Event yang didaftarkan:** `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`,
    `Notification`, `Stop`, `SessionEnd`, masing-masing satu grup `{"matcher":"*","hooks":[{"type":"command",
    "command":…,"timeout":5}]}` (tanpa `matcher` untuk event yang tidak memakainya).
  - **Format event:** `{"v":1,"event":"pre","session":"<id>","time":<epoch dtk>,"folder":"<nama folder cwd>",
    "tool":"Edit","id":"<tool_use_id>","target":"Hero.swift","added":22,"removed":6}`. `event` salah satu
    `prompt/pre/post/failure/notification/stop/end`; `notice` untuk notification (`permission_prompt`,
    `idle_prompt`, …). `target` hanya nama file (Read/Edit/Write/MultiEdit/NotebookEdit) atau nama program
    untuk Bash (melewati `VAR=x`, `cd x &&`, `sudo`, `env`, `nice -n 15`, `timeout 30s`, …). Baris dihitung
    dari `old_string`/`new_string`/`content` (escape `\n` di JSON, `\\n` tidak dihitung) dan teksnya dibuang.
    Prompt, perintah, argumen, isi file, pesan notifikasi dan path lengkap tidak pernah ditulis.
  - **Model:** urutan file per mtime (ns di APFS) lalu urutan wajar di satu turn. Prompt memulai turn
    (checklist kosong), Pre menambah langkah ▶ (dobel/terbalik diabaikan, `TodoWrite` tanpa baris), Post ✓,
    Failure ✗ (barisnya tidak dihitung lagi), Notification `permission_prompt` → butuh izin, `idle_prompt`
    dan sejenisnya → menunggu input, Stop → selesai (langkah yang masih jalan dianggap selesai), SessionEnd
    menghapus sesi. Kartu file = file terakhir yang disentuh, +/− kumulatif untuk file itu di turn ini.
    Sesi tanpa event 2 jam dihapus; event yang lebih tua dari itu diabaikan; `.tmp`/file asing > 1 menit
    dihapus; maksimal 400 file per scan. Service: DispatchSource pada folder, parse dan hapus di queue
    sendiri, publish di main, timer hanya untuk ✓ yang habis, "menunggu input" yang keluar dari island
    (10 menit) dan sesi yang basi. Jalan kalau island jalan, section AI tampil dan Claude nyala; mati →
    foldernya dihapus.
  - **Halaman:** header (mark Claude yang bernapas, "Claude", titik + status: "Working in <folder>" warna
    Claude, "Needs your permission"/"Waiting for you" amber, "Done in 2m" emerald) dan pill **Progress |
    Usage | Stats** di kanan (aktif emerald 10/20/100, lainnya abu-abu). Kalau ada beberapa sesi, chip `1/2`
    untuk pindah. **Progress:** checklist 6 langkah terakhir (✓ warna Claude, ▶ untuk yang jalan, amber
    saat menunggu izin, baris selesai lebih redup) dan kartu dalam (isi putih 6%, radius 14) berisi nama file
    mono warna Claude, `+N −M` mono hijau/merah (`numericText`), status (Reading…/Editing…/Saving…/Running…
    → Saved/Finished/Failed) dan bar 3 pt. Tanpa sesi hook: sesi dari log (Codex tetap lewat reader lama)
    atau ajakan "Connect Claude Code". **Usage:** ring per agent (Claude, Codex, OpenCode kalau ada limit)
    dengan mark di tengah, "% left" (atau "% used", ikut setting) di bawah, badge ↺ Codex kalau ada reset.
    **Stats:** kartu upstream (`NotchAgentsView`) apa adanya, termasuk menu periode di baris atas.
  - **Tinggi:** Progress dan Usage tetap 24 + 10 + 112 pt; Stats = tinggi kartu + header
    (`NotchAgentsPageLayout`). Ganti tab memicu `refreshPresentation` lewat `NotchAgentsPageState.$tab`.
  - **Gerak** (SwiftUI saja, transform/opacity/blur): ganti tab, sesi, heading dan file di kartu memakai
    blur crossfade lokal (`AnyTransition.notchAgentsSwap`: blur 6, opacity, skala 0,98; gampang diganti
    `.zenithMorph`). Baris masuk naik 6 pt dari blur, berurutan 40 ms; daftar bergeser dengan spring
    (0,38/0,86); ▶ → ✓ lewat `symbolEffect(.replace)`. Bar: saat jalan isi ease-out ke 62% lalu merayap pelan
    ke 94% (offset, bukan lebar), Post → penuh dengan spring; ganti langkah reset tanpa animasi. Ring masuk
    skala 0,92 + blur + opacity berurutan. Pill tekan 0,96. Reduce Motion: fade saja.
  - **Island tertutup:** memperluas live activity agents yang sudah ada (`.agents`), bukan activity baru.
    Saat ada sesi butuh izin/input: kiri mark Claude + titik amber berdenyut (layer, `NotchAgentPulse`),
    kanan "needs you · <folder>"; wing pinjam geometri Watch (56–150 pt) lewat `agentStripGeometry`.
    Stop pada turn ≥ 10 dtk: ✓ emerald + "done · <folder>" 5 dtk lalu hilang. Izin tetap tampil sampai
    dijawab; menunggu input 10 menit. Suara lembut (`Tink`, 0,35) sekali saat mulai butuh kamu, saklar
    `notchAgentsClaudeSound` (default nyala, ikut backup). Hanya island dengan kamera; kapsul (tanpa notch)
    tetap strip upstream.
  - **Settings:** di Dynamic Island → AI agents, setelah bagian Live (kalau Claude nyala). Status (terhubung /
    untuk build lain atau hook lama / belum / `settings.json` tidak bisa dibaca) dan event terakhir
    (`notchAgentsClaudeLastEvent`, tidak terdaftar jadi tidak ikut backup). "Connect Claude Code" menampilkan
    JSON persis yang akan di-merge sebelum menulis; "Disconnect" hanya mencabut handler Zenith. Merge
    idempoten, kunci dan hook lain (urutan kunci, ejaan angka, karakter) tetap, handler build lain diganti,
    file lama disalin ke `settings.json.zenith-backup`, tulisan atomik ke target symlink, permission
    dipertahankan; file yang bukan JSON objek (mis. ada komentar) tidak pernah disentuh. Saklar suara memakai
    `ZenithSwitchRow`, judul digambar sendiri (tidak masuk test search coverage).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchService` (`hasAgentActivity`, `agentStripGeometry`,
    sync/stop, langganan strip dan tab, tinggi halaman), `NotchAgentStrip` (strip "needs you"), `NotchView` dan
    `NotchContentEditor` (`NotchAgentsLivePage`), `NotchAgentsSettings` (bagian hook), `Defaults`. Test double
    `NotchMusicVisibilityTests` diberi `agentStripGeometry`.
  - **Belum diverifikasi visual:** app UI tidak dijalankan dan `~/.claude/settings.json` asli tidak disentuh.
    Script dicoba dengan payload contoh di folder sementara (redaksi, hitung baris, waktu). Perlu dicek di
    Mac: header dan pill di lebar island tersempit dan bahasa panjang, checklist + kartu (truncation nama
    file, angka count-up), bar di 120 Hz, blur crossfade antartab/sesi, ring Usage, Stats (tinggi dan menu
    periode), strip "needs you"/"done" di island bernotch (lebar wing, denyut amber, suara), alert Connect,
    dan sesi Claude Code sungguhan (permission prompt, idle 60 dtk, beberapa sesi sekaligus).
- **Design overlay untuk QA (branch `feat/design-overlay`):** gambar referensi (PNG/JPG dari Figma)
  melayang di atas browser dalam ukuran point aslinya, supaya hasil build bisa dicocokkan dengan desain
  piksel per piksel. Kode di `Services/DesignOverlay/DesignOverlaySupport.swift` (murni, ikut
  `TEST_SOURCES`: skala, ukuran point, koordinat, nudge/lock, memori per display, grid, crop difference,
  pilihan jendela Fit, target drop), `DesignOverlayImageStore.swift` (salinan gambar di container),
  `DesignOverlayDifference.swift` (difference lewat ScreenCaptureKit + Core Image, invert, pencari
  jendela/halaman untuk Fit), `DesignOverlayService.swift` (state, shortcut, jendela, keyboard, memori),
  `UI/DesignOverlay/DesignOverlayWindow.swift` (panel + kanvas layer), `DesignOverlayHUD.swift` (kapsul
  kontrol) dan `DesignOverlaySettings.swift`. Teks di `ZenithStrings.designOverlay` (15 bahasa). Test di
  `Tests/DesignOverlayTests.swift` (suite `design-overlay`).
  - **Jendela:** `NSPanel` borderless non-activating, bening, tanpa shadow, level `.statusBar` (HUD satu
    di atasnya), `.canJoinAllSpaces` + `.fullScreenAuxiliary` + `.stationary` + `.ignoresCycle`, tidak
    pernah jadi key. Click-through default (`ignoresMouseEvents`); kalau dimatikan, gambar bisa di-drag
    (kecuali terkunci) dan klik di gambar memberi keyboard ke HUD. Jendela hanya menutupi bagian gambar
    yang ada di display-nya (gambar halaman panjang tidak kena batas ukuran jendela); layer gambar diletakkan
    dengan offset di dalamnya dan dipotong jadi tile 4096 px (batas tekstur Core Animation 16384). Semua
    perubahan layer tanpa animasi implisit, jadi slider dan nudge langsung tampil di frame berikutnya.
    Muncul/hilang dengan fade alpha 0,2 dtk (Reduce Motion pun tetap fade).
  - **Skala:** DPI dari file menang dulu (144 → 2x, 216 → 3x; 72 dianggap tidak bilang apa-apa). Figma
    tidak menulis DPI, jadi lebar menentukan: lebar frame umum = 1x, dua/tiga kalinya = 2x/3x (2880 → 1440,
    1170 → 390, 1080 → 360). Kalau tidak cocok dan lebih lebar dari layar, faktor terkecil yang muat; selain
    itu 1x. Override manual Auto/1x/2x/3x di HUD. Kalau skala gambar = skala display, tile memakai filter
    `nearest` (1 piksel gambar = 1 piksel device); posisi di-snap ke grid piksel display.
  - **Blend:** Normal; **Difference**: window server menggabungkan jendela dengan source-over biasa, dan
    `compositingFilter` CALayer hanya memadukan isi jendela itu sendiri, jadi difference lintas jendela
    tidak mungkin langsung. Zenith menangkap area di bawah gambar dengan ScreenCaptureKit (semua jendela
    Zenith dikecualikan, `sourceRect` hanya bagian yang terlihat, piksel display), lalu
    `CIDifferenceBlendMode` dengan potongan referensi yang sama, dan hasilnya ditampilkan (hitam = cocok).
    Refresh 2x per detik selama mode ini aktif dan langsung setelah gambar bergeser. Butuh izin Screen
    Recording (diminta sekali saat dipilih); tanpa izin tampil **Invert** dengan catatan di HUD.
    **Invert**: referensi dibalik warnanya (`CIColorInvert`, alpha tetap); di 50% di atas build yang cocok
    hasilnya abu-abu rata, tanpa izin apa pun (pengganti onion skin).
  - **Grid:** mode kedua (tombol di HUD), kolom Figma (kolom sama lebar, gutter, margin kiri/kanan) di atas
    frame gambar, warna rose transparan, tidak ikut opacity gambar. Preset: desktop 12 · 24 · 80, laptop
    12 · 20 · 32, tablet 8 · 16 · 24, mobile 4 · 16 · 16.
  - **HUD:** kapsul hitam 44 pt (seperti pil island) di luar gambar: di bawahnya, lalu di atasnya, lalu di
    pojok kanan bawah area bebas kalau gambar setinggi layar. Panel non-activating yang bisa jadi key (browser
    tetap app terdepan). Isi: grip + ukuran gambar (atau catatan singkat, berganti lewat `.zenithMorph`),
    slider opacity (cyan, langsung tanpa animasi, angka %), tiga blend (violet), menu skala (sky), grid (amber),
    click-through (teal), lock (rose), Fit (emerald), paste (indigo), close. Tile 32 pt, radius 16 konsentris
    dengan kapsul (`ZenithIsland.innerRadius(depth: 6, outer: 22)`); tile aktif = isi 18% + garis 24% warna
    palet island. Grip/readout men-drag jendela (`performDrag`). Masuk dengan spring morph (naik 8 pt, blur
    10 → 0, skala 0,97 → 1), keluar easeIn 0,16 dtk; Reduce Motion: fade. Tombol tekan 0,94.
  - **Keyboard (saat HUD key):** panah 1 pt, Shift + panah 10 pt (diabaikan saat lock), angka 1–9 = 10–90%,
    0 = 100%, F = Fit ke jendela di bawah pointer, ⌘V = paste gambar, Esc = tutup.
  - **Fit:** jendela dari `CGWindowListCopyWindowInfo` (layer 0, bukan milik Zenith): yang paling atas di
    bawah pointer, lalu jendela app terdepan. Dengan izin Accessibility, `AXWebArea` terbesar di jendela itu
    (halaman browser, di bawah toolbar) dipakai; `AXManualAccessibility` diset supaya Chromium membangun
    pohonnya. Tanpa izin: frame jendela (termasuk toolbar). Kalau halaman di display lain, overlay pindah.
  - **Cara buka:** zona drop **Overlay** di island (satu gambar saja, setelah Transform/Remove Background;
    target `NotchDropTarget.overlay`, saklar sendiri `designOverlayDropEnabled`, tetap muncul walau aksi
    foto mati), shortcut global ⌥⌘O (`GlobalShortcutRole.designOverlay`, QuickToolHotkey id 82, bisa
    diganti di Settings dan halaman Shortcuts), dan paste dari clipboard (PNG dulu, lalu TIFF → PNG, lalu
    file gambar yang di-copy; dibaca lewat `GeneralPasteboardAccess`). Shortcut: kalau overlay tampil →
    tutup; kalau tidak → gambar terakhir, lalu gambar di clipboard, lalu panel pilih file.
  - **Memori:** gambar disalin apa adanya (DPI ikut) ke `<Application Support>/<bundle id>/DesignOverlay/
    reference.<ext>` lewat `PrivateFileStore` (owner-only, satu file saja); defaults hanya menyimpan namanya
    (`designOverlayLastImage`, nama polos, path ditolak). Per display (UUID display): offset, opacity, skala,
    lock (`designOverlayDisplays`, maksimal 12, yang terlama dibuang). Keduanya tidak didaftarkan, jadi tidak
    ikut backup. Preferensi yang ikut backup: saklar + kombinasi shortcut, opacity default (50%), blend
    default, preset grid, saklar zona island. Gambar dilepas dari memori saat overlay ditutup.
  - **Settings:** Section "Design overlay" di halaman Screen capture (di bawah opsi tool yang dipilih),
    memakai `ZenithSwitchRow`, `ShortcutPreferenceRow`, slider, picker; heading dari `Section` (bukan
    `SettingsRow`/`SettingsCard` ber-title), jadi tidak masuk test search coverage. Tombol Choose image… dan
    Paste image from clipboard. Fitur ini mengikuti ketersediaan tool Screenshot di Features hub.
  - Edit di file upstream bertanda `// Zenith fork`: `NotchService` (`acceptsPhotoDrop`, `updateFileDrop`,
    `accept`), `NotchFilesView` (zona Overlay), `GlobalShortcut` (role, default, urutan grup capture),
    `Defaults`, `FeatureRuntime` (sync di binding `.screenshot`), `ScreenCaptureSettings`. File fork lain:
    `NotchAirDropSupport` (case `.overlay`), `NotchPhotoActionsSupport`/`Service` (target drop), test double
    `ShelfDropRoutingContract.DesignOverlayService`.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac: lihat daftar "cek manual"
    di laporan branch (export Figma 2x di atas browser, Difference dengan izin Screen Recording, Fit di
    Safari/Chrome, HUD di 120 Hz, full screen, beberapa display). ⌥⌘O bentrok dengan Outline Stroke di Figma
    dan menutupi shortcut lokal ⌥⌘O (Watch) di island; ganti kalau mengganggu.
- **Ikon berwarna, galeri Widgets dan Customize Home (branch `feat/island-home-custom`):** pola dan
  gerak dari rekaman referensi `reference/home-shelf-*.mp4` dan `buy-shelf-*.mp4` (dianalisis per frame;
  artwork ikon tidak diambil, semua ikon digambar Zenith sendiri). Faiz memilih ikon berwarna (bosan
  serba monokrom).
  - **`ZenithAppIcon`** (`UI/Notch/ZenithAppIcon.swift`, hanya app; sekarang di balik `ZenithIconStyle.glossy = false`,
    lihat "Galeri tenang, ikon tenang, editor shortcut Home"): squircle sudut kontinu 22,5% sisi,
    gradasi vertikal dari warna modul (`zenithTint`/hex): atas lebih terang dan sedikit kurang jenuh, bawah
    lebih gelap dan lebih kaya (kuning/lime turun lebih dalam supaya glyph putih tetap terbaca); bloom radial
    lembut, kilau elips di setengah atas, inner shadow terang di tepi atas dan gelap di tepi bawah, hairline
    yang terang di atas dan pudar di bawah, glyph SF Symbol putih semibold dengan drop shadow kecil dalam
    nada tergelap warnanya, bayangan luar halus (bisa dimatikan, `lifted: false`, untuk strip padat). Warna
    abu-abu (Vercel, GitHub) jadi ikon grafit. Hanya shape dan gradient SwiftUI, tajam di semua ukuran.
    Glyph per modul `NotchModule.zenithIconSymbol` (versi filled: Home `house.fill`, Tools
    `wrench.and.screwdriver.fill`, Notifications `bell.badge.fill`, dst.), warna dari `ZenithIslandPalette`.
    Shortcut Home `NotchControlItem.zenithIconHex` dan tool `QuickLauncherItem.zenithIconHex` punya warna
    sendiri (Keep Awake amber, mic pink, screenshot cyan, rekam merah, speed test emerald, panel biru, Command
    Bar slate, Homebrew oranye, Color Picker fuchsia, dst.). `ZenithAboutPage` punya ikon privat bernama sama,
    jadi diganti nama `ZenithAboutAppIcon`.
  - **Tile Home dan Tools:** `NotchActionTile` menerima `iconHex`; dengan itu glyph jadi `ZenithAppIcon` 34 pt.
    Status aktif tetap: titik status menyala di pojok + simbol berubah; rekam dan mic mati mengubah ikon jadi
    merah. Tools di island (`QuickLauncherView`, cabang `notchSize`) memakai ikon 32 pt; panel cepat terpisah
    tidak berubah. Preview island di Settings (`NotchLayoutEditor`) ikut.
  - **Galeri jadi Widgets** (dibatalkan: galeri kembali ke command palette, lihat "Galeri tenang, ikon tenang, editor
    shortcut Home") (`UI/Notch/ZenithWidgetsGallery.swift`, kait satu baris di `NotchSectionsView`):
    grid ikon 60 pt dengan nama di bawahnya, halaman bergeser ke samping (spring `ZenithMorph`; Reduce Motion:
    crossfade), page control (titik, yang aktif kapsul 14 pt) di baris atas island di samping kolom cari.
    Yang dipertahankan: cari, navigasi keyboard (grid service sama; ikon yang disorot membawa halamannya),
    tanda modul aktif (badge centang aksen di pojok ikon), ketersediaan dan urutan (`filteredSections`), dan
    shortcut ⌥⌘ (badge mono kecil di bawah ikon saat hover atau kursor keyboard, plus tooltip). Baris masuk
    naik 6 pt dari blur berurutan 40 ms. Tekan ikon menyusut ke 0,94 dengan spring.
  - **Kontrak tinggi galeri tetap:** konstanta `NotchLayout` (bertanda `// Zenith fork`) jadi sel 86 pt, jarak
    baris 8, lebar kolom minimal 84, jarak kolom 4, maks. 8 kolom, `sectionIndicatorWidth` 0 (titik pindah ke
    baris atas). `sectionListHeight(budget:)` tidak berubah, jadi preset tetap 3 baris = 274 pt, persis
    tinggi galeri sebelumnya. Kolom: compact 4, spacious 5, lebar tersempit 3; 19 modul = 2 halaman.
    `NotchService`: `sectionRow` sekarang selalu baris pertama sebuah halaman (`ZenithWidgetsPaging.pageStart`),
    satu langkah scroll = satu halaman, dan swipe ke samping di trackpad ikut menggeser (sumbu dominan
    `scrollingDeltaX`/`Y`).
  - **Customize Home:** item menu klik kanan island "Customize Home" (paling atas, juga di klik kanan tab Home
    pil). Masuk mode edit di halaman Home (pindah ke Home dulu kalau perlu): widget bergoyang ±1° (Reduce
    Motion: diam), tiap widget bergaris putus-putus dengan badge hapus merah (masuk 40 ms setelah garis), dan
    strip di bawah naik dengan spring + blur (ikon berurutan 40 ms, ✕/✓ menyusul). Strip: ikon 34 pt semua
    widget yang halamannya nyala, nama 9,5 pt, centang aksen untuk yang sudah ada; klik = tambah/hapus; yang
    tidak muat diredupkan dengan tooltip "No room for another widget". ✕ membatalkan (layout kembali), ✓
    (Return) menyimpan. Mode edit batal sendiri kalau halaman Home hilang (ganti halaman, galeri, island
    tertutup). Menambah widget: ikon terbang dari strip ke tempatnya (`matchedGeometryEffect`), lalu blur-fade
    jadi isi widget; island melebar lewat spring siluetnya sendiri. Menghapus: widget menyusut 0,82 + blur 10 +
    fade, island menyempit.
  - **Kandidat widget** (`UI/Notch/ZenithHomeWidgets.swift`): Now Playing (kartu player Home yang sudah ada),
    Timer (jam mono, fase, satu tombol bulat ungu: start mode tersimpan / jeda / lanjut / fase berikut),
    Clipboard (dua salinan terakhir sebagai kartu kecil, klik = salin lagi dengan centang), Calendar (acara
    berikut minggu ini dengan batang warna kalender), Weather (simbol, suhu, tinggi/rendah; tanpa izin lokasi
    menampilkan tombol "Allow Location"/"Open Settings", tidak pernah meminta sendiri), System (CPU dan memori
    dengan bar 3 pt), Agents (bacaan strip AI + titik hijau saat agent bekerja), Shelf (tiga item pertama +
    jumlah). Klik badan widget membuka halamannya. Widget yang halamannya mati tetap tersimpan tapi tidak tampil.
    `WeatherService` mendapat `homeShown()/homeHidden()`: pembacaan sama dengan lock screen selama widget tampil.
  - **Model** (`Services/Notch/ZenithHomeLayoutSupport.swift`, murni, ikut `TEST_SOURCES`): `ZenithHomeWidget`
    (modul, glyph, warna, lebar alami 172–300 pt), `ZenithHomeLayout` (maks. 3 berdampingan, tanpa duplikat,
    tambah/hapus/pindah, `canAdd` dengan lebar maksimum layar), `ZenithHomeIsland` (draft mode edit sebagai
    state statis seperti `ZenithReplyHold`, geometri island), `ZenithWidgetsPaging`.
  - **Persistensi:** `zenithHomeLayout` (`DefaultsKey.zenithHomeLayout`), daftar dipisah koma, mis.
    `nowPlaying,timer,clipboard`; `""` = Home tanpa kartu; default terdaftar `auto` = belum pernah diatur;
    karena terdaftar, ikut backup. Migrasi: `auto` = player kalau saklar Music Home nyala, kalau tidak kosong (persis Home
    lama). Saklar Music di Settings tetap penentu player: dimatikan → player keluar dari layout; dinyalakan →
    player kembali di depan (widget terakhir mengalah kalau penuh). Menyimpan layout ikut mengubah `music` di
    `notchHiddenControls` (format daftar terurut tetap).
  - **Lebar island:** satu widget mengisi baris seperti player dulu (lebar island tidak berubah). Dua atau lebih:
    `NotchGeometry.zenithHome` (diisi `expandedGeometry` hanya di Home) membuat `expandedWidth` minimal
    jumlah lebar widget + jarak 10 + inset, dibatasi tepi layar (`zenithHomeMaximumContentWidth`); widget yang
    membuat baris melewati batas itu tidak ditawarkan (tidak wrap). Mode edit menambah tinggi strip
    (58 + 10 pt) lewat `expandedSize`. Semua perubahan memanggil `refreshPresentation()`, jadi ukuran berubah
    lewat animasi siluet island sendiri. Di dalam baris, lebar tiap widget sebanding dengan lebar alaminya.
    Preview island di Settings (`NotchContentEditor`) ikut menampilkan widget, tapi tidak pernah mode edit
    (`notchSettingsPreview`) dan tidak dilebarkan (geometri preview tidak diberi `zenithHome`).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchSupport` (konstanta galeri, `zenithHome`, lebar dan
    tinggi Home), `NotchService` (geometri Home, paging halaman, swipe samping), `NotchSectionsView` (galeri),
    `NotchControlsView` (baris widget, strip, tile berwarna), `NotchView` (item menu), `QuickLauncherView`
    (ikon Tools), `NotchLayoutEditor` (preview), `Defaults` (kunci), `build.sh` (`TEST_SOURCES`),
    `Tests/MetricsTests.swift` (suite). Teks di `ZenithStrings.home` (15 bahasa; nama widget memakai judul
    modul yang sudah ada dan kata Weather dari lock screen).
  - **Test:** baru `Tests/HomeLayoutTests.swift` (suite `home-layout`): tambah/hapus/urut, batas 3 dan lebar
    layar, encode/decode dan nama asing, kunci terdaftar + ikut backup, migrasi dan sinkron saklar Music,
    ketersediaan, ukuran island (satu widget = Home lama persis, tiga widget melebar, mode edit menambah strip,
    tidak melewati layar), draft mode edit, halaman galeri, teks. Diubah: `NotchTests` (galeri: 3 baris bukan
    8, kolom 4/5/3 bukan 2/2/1, 2 halaman bukan ≤ 3 posisi baris; tujuan sama: tinggi galeri = tiga baris tile
    upstream), `NotchSectionPagingTests` (double `NSEvent` dapat `scrollingDeltaX`, dan test baru swipe
    samping menggeser galeri).
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Ikon dan mock galeri/mode edit dirender statis
    (`ImageRenderer`). Perlu dicek di Mac (120 Hz): ikon di island kaca abu-abu, galeri (geser halaman, titik,
    badge shortcut, kursor keyboard, cari), masuk/keluar mode edit, goyangan, ikon terbang dari strip,
    island melebar/menyempit tanpa isi melompat, widget Weather/Clipboard/Timer sungguhan, menu klik kanan,
    Reduce Motion, Increase Contrast, layar kecil.
- **Import kartu kamera (branch `feat/card-import`):** kartu SD/CFexpress dari kamera dikenali saat
  di-mount, ditawarkan lewat notice kapsul, lalu diimpor dari halaman island sendiri dengan progres di
  island tertutup. Untuk alur fotografer acara (wisuda, acara sekolah): ribuan foto dan video sekali
  colok. Kode di `Services/CardImport/CardImportSupport.swift` (murni, ikut `TEST_SOURCES`: aturan
  deteksi, klasifikasi, scan, opsi, tujuan, rencana, ledger, laju dan ETA, model activity, format),
  `CardImportCopier.swift` (`CardImportJob`, salin per file, ikut `TEST_SOURCES`),
  `CardImportService.swift` (volume, notice, sesi, eject), `UI/Notch/CardImportPage.swift` (halaman),
  `UI/Notch/CardImportStrip.swift` (island tertutup dan kapsul) dan `UI/Notch/CardImportSettings.swift`.
  Teks di `ZenithStrings.cardImport` (15 bahasa, bentuk jamak one/few/many untuk ru/uk/sk). Test di
  `Tests/CardImportTests.swift` (suite `card-import`).
  - **Deteksi:** hanya saat island jalan dan saklar `notchCardImportEnabled` nyala (default nyala).
    `NSWorkspace.didMountNotification`/`didUnmountNotification`; volume yang sudah ter-mount saat start
    ikut dibaca tanpa notice. Syarat volume: lokal, bukan startup disk, dan removable atau ejectable
    (slot SD bawaan MacBook memang "internal" tapi removable). Syarat isi: folder `DCIM`,
    `PRIVATE/M4ROOT` (Sony XAVC), `PRIVATE/AVCHD`, `AVCHD`, atau `CLIP`. Yang di-scan hanya akar media:
    `DCIM/**`, `PRIVATE/M4ROOT/CLIP`, `PRIVATE/AVCHD/BDMV/STREAM`, `AVCHD/BDMV/STREAM`, `CLIP/**`, jadi
    thumbnail Sony (`THMBNL`, JPG) dan proxy (`SUB`, MP4) tidak terhitung. File tersembunyi dan
    AppleDouble `._*` dilewati. Foto: JPG/JPEG/HEIC/HEIF (masuk JPG) dan RAW ARW, CR2, CR3, NEF, RAF,
    DNG, ORF, RW2; video: MP4, MOV, MTS, MXF, BRAW. Scan di queue `utility`, tidak pernah di main thread.
    Waktu ambil = tanggal pembuatan file (kamera menulisnya saat memotret), cadangannya tanggal ubah;
    EXIF tidak dibaca supaya ribuan file tetap cepat.
  - **Identitas kartu:** `volumeUUIDString`, atau UUID Disk Arbitration (kartu FAT/exFAT sering tidak
    memberi UUID ke Foundation), atau `nama-kapasitas`. Format ulang di kamera = UUID baru = ledger baru.
  - **Notice:** `ZenithNotice.Kind.card` (prioritas 3 seperti headphone: di atas download dan charger, di
    bawah baterai lemah), tampil 7 dtk, menunggu island sampai 30 dtk, key `card.<uuid>` (kartu yang sama
    di-coalesce). Judul `SD card · 1,248 photos · 64 GB` (video kalau tanpa foto), subjudul nama volume,
    jumlah video, dan "N imported before". Glyph `sdcard.fill` warna modul (`Tone.tint`) dan aksesori
    baru `.action("Import")`: pil padat warna modul. Klik = `CardImportService.openImport` (island
    terbuka di halaman Card Import). Kartu dicabut sebelum dijawab = notice-nya ikut pergi.
  - **Modul baru `NotchModule.cardImport`** (⌥⌘J, glyph `sdcard`, warna peach `#FDBA74`: semua tingkat
    400 di palet sudah terpakai, jadi diambil tingkat 300 oranye). Selalu terdaftar di Content supaya
    opsinya terjangkau; tampil di island selama deteksi nyala. Halaman (min. 232 pt, island custom yang
    lebih pendek men-scroll):
    - *Kosong:* tile glyph + "Insert a camera card…". *Membaca:* spinner + "Reading the card…".
    - *Siap:* header (tile, nama volume, isi dan ukuran mono, tombol eject, menu ganti kartu kalau lebih
      dari satu), kartu lembut Destination (base folder mono di kanan, field nama event dengan ikon
      folder warna modul, terisi `YYYY-MM-DD` dari hari foto terbaru yang belum diimpor, cadangannya
      hari ini), kartu lembut opsi (empat saklar `ZenithIslandSwitchStyle` ×0,76 dalam grid dua kolom +
      `ZenithSegmented` Original | Date and time), lalu baris status ("N new" titik warna modul, "N
      imported before" mono) dan tombol Import padat warna modul. Opsi di halaman hanya untuk import ini;
      default-nya dari Settings dan direset tiap kartu baru.
    - *Menyalin:* header (glyph kamera, nama kartu, `→ nama event`, tombol Stop), kartu lembut berisi
      persen besar `ZenithFigure` dengan `numericText`, kata "Importing" warna modul, kecepatan, bar 4 pt,
      `412 / 1,036`, `21.4 / 52 GB`, `3m left`, nama file yang sedang disalin.
    - *Selesai:* cincin emerald yang terisi (`trim`) dengan ✓ yang tergambar (`trim`, jeda 0,3 dtk),
      "Imported 1,248 · 52 GB", `→ ~/Pictures/Imports/<event>`, "N skipped, imported before", tombol
      Reveal in Finder (padat), Eject (atau status Ejected), Done.
    - *Gagal:* kartu dicabut (ikon `sdcard` merah), disk penuh (amber, "Free up X and retry."), atau file
      gagal (merah, nama file). Retry (aktif kalau kartunya ada), Reveal in Finder kalau sudah ada yang
      tersalin, Done.
    - Ganti state lewat `.zenithMorph(on:)`; Reduce Motion: fade.
  - **Rencana import (`CardImportPlanner`):** tujuan `<base>/<event>/`; base default `~/Pictures/Imports`
    (disimpan dengan `~` kalau di dalam home), nama event dibersihkan (`/` dan `:` jadi `-`, tanpa titik di
    depan, tanpa karakter kontrol, maks. 120). Subfolder: `RAW/` dan `JPG/` (HEIC ikut JPG) kalau
    "RAW and JPG folders" nyala, `Video/` kalau "Video folder" nyala, selain itu langsung di folder event.
    Nama: asli, atau `YYYYMMDD-HHMMSS-####` (waktu ambil zona lokal, nomor urut menurut waktu ambil,
    empat digit lalu melebar; RAW dan JPG satu jepretan (folder + nama tanpa ekstensi sama) berbagi
    nomor; ekstensi dipertahankan apa adanya). Tabrakan nama (dua folder DCIM dengan nama sama, file
    yang sudah ada) tidak pernah menimpa: `-1`, `-2`, tanpa beda huruf besar. Skip imported: file yang
    key ledger-nya `nama|ukuran|detik ambil` sudah tercatat; file yang sudah tersalin di sesi ini selalu
    dilewati saat retry, apa pun opsinya.
  - **Ledger:** `<container>/CardImport/ledger-<uuid>.json` (folder 0700), hanya key (tanpa path atau isi),
    maks. 50.000 terbaru, ditulis tiap 40 file dan saat import berakhir. Tidak ikut backup.
  - **Salin (`CardImportJob`):** `Task.detached(priority: .utility)`: rencana (cek nama yang sudah ada di
    disk), cek ruang kosong (`volumeAvailableCapacityForImportantUsage` + margin 256 MB; kurang = langsung
    gagal disk penuh dengan jumlah yang dibutuhkan), lalu file satu per satu: `read`/`write` POSIX 4 MB
    dengan `F_NOCACHE`, ke `.zenith-import-<uuid>.partial` di folder tujuannya, ukuran dicek dua kali
    (byte yang ditulis dan ukuran file), tanggal pembuatan dan ubah dari kartu dipasang, lalu
    `renamex_np(RENAME_EXCL)` ke nama final (EEXIST = nama berikutnya, tidak pernah menimpa). Gagal di
    tengah = file partial dihapus; partial sisa run yang terhenti (Mac tidur, Zenith keluar) dibersihkan
    sebelum run berikutnya. Kartu tidak pernah ditulis, dipindah, atau dihapus. Main thread membaca state
    job (di balik lock) tiap 0,1 dtk lewat timer, hanya selama menyalin.
  - **Error:** kartu dicabut = read gagal dan volume hilang (stat gagal atau device id berubah; job
    menunggu sampai 1,5 dtk karena read gagal sebelum unmount datang; unmount juga menandai job, dan
    kegagalan file dalam 5 dtk sebelum unmount diklasifikasi ulang sebagai kartu dicabut). Disk penuh =
    `ENOSPC`/`EDQUOT` (juga `NSFileWriteOutOfSpaceError`). Stop = sesi selesai, yang sudah tersalin
    tetap ada (dan tercatat di ledger), halaman kembali ke kartu.
  - **Eject:** "Eject when done" (default nyala) menjalankan `NSWorkspace.unmountAndEjectDevice` di
    background setelah import sukses; tombol Eject di header dan di hasil. Gagal (file terbuka) ditulis di
    halaman hasil. Tidak pernah saat menyalin.
  - **Live activity `NotchCompactActivity.cardImport`:** urutan otomatis setelah `command`, ikut picker,
    tidak pernah berpasangan, klik membuka halaman. Wing pinjam geometri Watch. Kiri: glyph
    `camera.fill` warna modul + persen mono 11 (`numericText`); kanan: `812 left · 3m` mono 10,5 di atas
    bar 2 pt warna modul. Kapsul: glyph, persen, bar 34 pt, bacaan. Lebar wing dihitung dari bacaan
    terlebar untuk import ini (`100%`, jumlah file kartu, `1h 59m`), jadi tidak berubah selama angka
    bergulir; `NotchService` hanya berlangganan `activity` yang kasar (mulai/selesai/gagal), progres
    punya `ObservableObject` sendiri (`CardImportMeter`) yang hanya diamati strip dan halaman. Selesai:
    glyph mengecil keluar, ✓ emerald tergambar `trim`, kanan `1,248 · 52 GB`, 8 dtk. Gagal: ✗ merah +
    "Card removed"/"Destination disk is full"/"Import stopped", 15 dtk (halaman menyimpannya sampai Done).
  - **Gerak:** semua SwiftUI, hanya transform/opacity/blur/trim: bar memakai `scaleEffect(x:anchor:
    .leading)` (bukan lebar) dengan `.smooth(0,35)`, angka `numericText`, mark berganti dengan skala +
    opacity di spring, ✓ dan cincin `trim`, halaman `.zenithMorph`. Reduce Motion: fade, tanpa gulir angka.
  - **Settings:** opsi section Card Import di Dynamic Island → Content (seperti Vercel/GitHub): saklar
    "Detect camera cards", "Import to" (path mono, Choose… lewat `NSOpenPanel`, Reset kalau custom),
    keterangan folder event, lalu Defaults: RAW and JPG folders, Video folder, Skip imported (dengan
    keterangan pencocokan), Names (segmented Original / Date and time, dengan contoh nama), Eject when
    done. Semua `ZenithSwitchRow`/`ZenithSwitchStyle`, tanpa `SettingsRow`, jadi tidak masuk test search
    coverage. Kunci `notchCardImport*` terdaftar di `registeredDefaults` (ikut backup).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchSupport` (case modul dan activity, simbol,
    shortcut, ketersediaan, gerbang modul, tinggi konten, urutan activity), `NotchService` (activity,
    wing, kapsul, langganan, sync/stop), `NotchView`/`NotchMirrorView` (strip, halaman, judul, tinggi
    minimum), `NotchTimerStrip`/`NotchCapsuleViews` (tidak berpasangan), `NotchContentEditor`,
    `NotchEditorStrings`, `NotchSettings` (opsi), `Defaults`, `build.sh` (`TEST_SOURCES`),
    `Tests/MetricsTests.swift` (suite). File fork yang ikut berubah: `ZenithIslandPalette` (warna),
    `ZenithNoticeSupport`/`Service`/`View` (kind, tone, aksesori, aksi). Test double
    `NotchMusicVisibilityTests` diberi `hasCardImportActivity` dan `cardImportStripWing`.
  - **Belum diverifikasi dengan kartu sungguhan:** app UI tidak dijalankan dan tidak ada volume yang
    di-mount, dibaca, atau di-eject saat pengerjaan. Scan, rencana, ledger, dan salin (termasuk tanggal,
    tabrakan, partial, kartu hilang, disk penuh dari errno) dites di folder sementara.
- **Bahu island penuh + mirror kamera otomatis (branch `feat/island-shoulders-camera`):** dua permintaan
  Faiz setelah melihat fondasi island.
  - **Bahu:** island terbuka sekarang memakai flare penuh dari referensi: bahu cekung lingkaran 27 pt lebar
    × 27 pt turun (`ZenithIslandSilhouette.openShoulderWidth`/`openShoulderDepth`, dulu elips 14 × 22). Angka
    dari pengukuran fase 1A (rekaman 2x, ~27 pt, lebar = tinggi); tidak diukur ulang.
  - **Kontrak lebar (rok di luar body):** `NotchLayout.shoulderFlare` = 27 − 14 = 13 pt. `shoulder(height:)` =
    bahu upstream (`plainShoulder(height:)`) + `shoulderFlare(height:)`, yang ikut `openness` (smoothstep 72 → 128
    pt), jadi strip tertutup ≤ 72 pt tetap persis upstream dan bahu melebar/menyempit mulus saat buka/tutup.
    Island terbuka 26 pt lebih lebar (`expandedWidth` = lebar pilihan + 26; lebar custom 360–600 dan preset
    480/560 tetap berarti lebar body + bahu lama) dan `horizontalInset` 28 → 41, jadi body dan lebar isi halaman
    sama persis dengan sebelumnya (isi tetap 14 pt dari sisi body, `ZenithIsland.pageInset`, radius konsentris
    tidak berubah: kartu 20 = 34 − 14). Yang lebarnya ikut: pratinjau notifikasi (`notificationPreviewWidth` + 26),
    Command Bar (lewat `horizontalInset`), kontrol tangkapan (lewat `expandedWidth`). Permukaan pendek dengan inset
    sendiri dilebarkan sesuai flare di tingginya (`NotchLayout.flared`): peek (`peekWidth` + flare, isi
    `horizontalInset(height:)`), placeholder drag (18 + flare), pemilih activity (`horizontalPadding`), jadi
    body-nya sama dengan upstream di semua tinggi. Batas layar `expandedWidth` tetap `screen.width − 24 − gutter × 2`
    (di layar sangat sempit isi bisa 26 pt lebih sempit). Notice Zenith (jendela sendiri) tetap memakai
    `plainShoulder`. Editor layout di Settings: tarik ukuran mulai dari lebar tanpa flare, jadi tidak melebar 26 pt
    tiap tarikan (posisi bubble tombol di pratinjau tidak diubah, bisa bergeser ±6 pt di skala 0,5).
  - **Hit-test, jendela, pil:** klik tetap per path (area transparan di luar bahu tembus), jendela = ukuran island
    (+ gutter), body untuk pil tab dan tombol mengambang dihitung dari `shoulder(height:)` jadi tetap di tengah dan
    sejajar body. Hover memakai kotak island, jadi koridor hover di samping body sekarang 27 pt (dulu 14).
  - **Path:** elemen tetap sama di semua ukuran (lingkaran = kurva tengah, dua kurva titik).
  - **Kamera:** halaman Camera island langsung membuka mirror saat tampil kalau akses kamera sudah `.authorized`
    dan saklar "Start the mirror automatically" (`notchCameraAutoStart`, default nyala, ikut backup) nyala; sekali
    per kunjungan, jadi Stop di baris atas tetap berhenti. Belum ditentukan: tombol "Open camera" tetap (minta izin
    lalu mulai). Ditolak: pesan upstream tetap. Berhenti tetap saat meninggalkan halaman atau island menutup. Logika
    di `Services/QuickTools/ZenithCameraAutoStart.swift` (ikut `TEST_SOURCES`), gerak di
    `UI/Notch/ZenithCameraReveal.swift`: halaman yang akan auto-start langsung jadi halaman gelap mirror (tanpa kedip
    placeholder), spinner kecil baru muncul kalau sesi > 150 ms, gambar masuk opacity 0 → 1 + blur 10 → 0 (0,32 dtk,
    kurva `ZenithMotion.reveal`) lewat filter blur Core Animation di layer preview (blur SwiftUI tidak sampai ke layer
    AVFoundation); Reduce Motion: fade saja. Saklar di Settings → Dynamic Island → Camera (`ZenithSwitchRow`), teks
    di `ZenithStrings.camera` (15 bahasa).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchSupport` (`NotchLayout`, `expandedWidth`,
    `notificationPreviewWidth`, `peek`, `NotchActivityPickerLayout`), `NotchService` (placeholder drag), `NotchView`
    (padding peek, drag, picker), `NotchLayoutEditor` (awal resize), `CameraPreviewView` (`revealsGently`),
    `NotchCameraView`, `NotchSettings`, `Defaults`, `build.sh` (`TEST_SOURCES`).
  - **Test:** `ZenithIslandTests` ditambah `openShoulder` (kurva bahu terbuka lingkaran 27 pt, galat < 0,1 pt, lurus
    setelah 27 pt, bahu naik mulus dan monoton 60 → 140 pt, body di tempat bahu berakhir di tiap tinggi, strip tertutup
    tanpa flare), `shoulderSkirt` (inset 41, isi 14 pt dari body, `expandedWidth` = pilihan + 26, lebar isi dan body
    sama dengan upstream di semua preset/lebar/kamera, peek dan pemilih activity, strip tertutup tidak berubah) dan
    `cameraAutoStart`. `openProfile` membandingkan dengan island upstream yang digeser 13 pt (body sama), dan
    `upstreamPath` memakai rumus bahu upstream langsung. Diubah dengan sengaja (tujuan sama, lebar + flare):
    `NotchTests` "an open island keeps its full corner radius and shoulder" (bahu = 27), "a chosen width narrower
    than the player…" (360 + 26), "a width set by hand is the island's…" (+ 26, pembanding preset ikut), "custom
    dimensions fit every module…" (+ 26), `NotchNotificationTests` "the preview card is about a native banner wide…"
    (400 + 26) dan "a wide camera keeps its clearance…" (+ 26). Double `CameraPreviewView` di `NotchCompactTests`
    menerima `revealsGently` dan dicek.
  - **Belum diverifikasi visual:** app UI tidak dijalankan, kamera tidak dinyalakan. Perlu dicek di Mac: bahu 27 pt
    saat buka/tutup (120 Hz), sambungan bahu dengan tepi layar dan dengan notch fisik, pil tab dan tombol mengambang
    tetap sejajar, peek/pemilih activity/pratinjau notifikasi/Command Bar, island kapsul, island kaca, dan halaman
    Camera (auto-start tanpa kedip, spinner hanya saat lambat, blur-in, Stop, ganti halaman, tutup island, izin
    belum ditentukan/ditolak).
- **Galeri tenang, ikon tenang, editor shortcut Home (branch `feat/calm-gallery-home-shortcuts`):** feedback Faiz
  setelah "Ikon berwarna, galeri Widgets dan Customize Home": galeri versi sebelumnya terasa lebih segar dan
  tenang, squircle glossy terlalu ramai. Bahu 27 pt tetap (siluet tidak disentuh).
  - **Galeri kembali jadi command palette** (island v2): `ZenithCommandRow` (glyph, nama, shortcut mono redup, dua
    kolom, satu kolom di lebar tersempit, garis aksen 2 pt untuk modul aktif, kursor keyboard, cari, titik baris di
    kanan). Bedanya: glyph duduk di tile lembut warna modul (`ZenithIslandGlyphTile` 22 pt, radius 6,5,
    `ZenithCommandRow(tint:)`; tanpa `tint` tetap glyph monokrom). Konstanta `NotchLayout` kembali ke angka list
    (baris 32,5, jarak 2, kolom min. 170, jarak kolom 8, maks. 2 kolom, indikator 12), `sectionListHeight(budget:)`
    tidak berubah, jadi tinggi galeri tetap (preset 8 baris = 274 pt). `sectionRow` kembali ke semantik upstream
    (baris pertama yang tampil, kursor keyboard digeser seperlunya, satu langkah = satu baris); yang dipertahankan
    dari galeri Widgets: swipe samping di trackpad tetap menggeser galeri (sumbu dominan), sekarang per baris.
    `ZenithWidgetsGallery.swift` dan `ZenithWidgetsPaging` dihapus (ada di riwayat, commit `032871e5`).
  - **Ikon tenang:** `ZenithIslandIcon` (di `ZenithAppIcon.swift`) menggambar tile shortcut Home, Tools di island,
    heading widget, strip mode edit, ikon terbang, dan preview Settings sebagai glyph warna di tile lembut
    (`ZenithIslandGlyphTile`, warna dari `zenithIconHex`/`hex` lewat `ZenithIslandPalette.color(hex:)`). Titik status
    aktif tetap, rekam dan mic mati tetap membuat tile merah. `ZenithAppIcon` tetap ada di balik satu saklar:
    `ZenithIconStyle.glossy = false` (ubah ke `true` untuk kembali ke squircle glossy).
  - **Editor shortcut Home:** Customize Home sekarang juga mengedit baris shortcut di bawah widget.
    - Strip mode edit punya baris atas: segmented `Widgets | Shortcuts` (`ZenithSegmented`) di kiri, ✕/✓ di kanan
      (26 pt), lalu baris ikon di bawahnya (`ZenithHomeIsland.stripHeight` 58 → 84). Sisi Shortcuts menampilkan semua
      `NotchControlItem` yang bukan level dan bukan player, yang tersedia di Mac ini (`isAvailable` upstream: fitur
      terpasang dan nyala, halaman tujuan tampil), centang aksen untuk yang sudah di baris; klik = tambah/hapus.
    - Di baris shortcut, tiap tile bergoyang ±1° dengan badge hapus merah di sudut ikon, klik tile dimatikan, dan tile
      bisa diseret: tile mengikuti pointer (skala 1,08), tetangga bergeser memberi ruang dengan spring, dilepas = tile
      spring ke tempat barunya lalu urutan disimpan di draft tanpa gerak kedua. Drag memakai `DragGesture` SwiftUI di
      dalam island (bukan drag session, jadi shelf/drop tidak ikut). VoiceOver: aksi Move left/Move right/Remove.
    - ✕ membatalkan widget dan shortcut sekaligus; ✓ (Return) menyimpan keduanya. Mode edit batal sendiri kalau
      halaman Home hilang, seperti sebelumnya.
  - **Persistensi:** tidak ada kunci baru. Baris memakai kunci upstream yang juga diedit kartu Home di Settings:
    `notchControlOrder` (urutan, ditulis seperti Settings: semua shortcut dipisah koma) dan `notchHiddenControls`
    (yang dimatikan, tetap daftar terurut; entri level, `music` milik widget, dan nama asing dipertahankan). Keduanya
    sudah terdaftar di `registeredDefaults`, jadi ikut backup. Yang tidak berubah tidak ditulis. Island dan Settings
    selalu membaca kebenaran yang sama (`NotchSupport.controls`).
  - **Batas:** `ZenithHomeShortcuts.capacity` = jumlah shortcut terbanyak yang muat tanpa rail menggulir, dengan
    layout halaman Home sendiri (`NotchLayout.controls`: baris yang diizinkan tinggi halaman, kolom sampai jaraknya
    menutup) di lebar island saat ini (lebar pilihan, dilebarkan widget). Compact ±5, Spacious sampai 2 baris. Kalau
    penuh, ikon di strip diredupkan dengan tooltip "No room in the row"; shortcut lama yang melebihi batas (diatur dari
    Settings) diredupkan di baris dengan tooltip sama dan tetap disimpan (rail menggulir seperti upstream).
  - **Gerak (120 Hz):** menambah = ikon terbang dari strip ke baris (`matchedGeometryEffect`), lalu blur-fade jadi
    tile; menghapus = menyusut, blur, fade (`zenithHomeDeparture`); geser urutan dan reflow baris = spring
    `ZenithMorph`. Island membesar/mengecil lewat geometri sendiri: selama edit, `ZenithHomeIsland.controls` memberi
    draft shortcut ke `pageSize` dan `naturalContentWidth`. Reduce Motion: fade, tanpa terbang, drop langsung.
  - **Kode:** model murni `Services/Notch/ZenithHomeShortcutsSupport.swift` (ikut `TEST_SOURCES`):
    `ZenithHomeShortcuts` (urutan + yang dimatikan, tambah di akhir, hapus menyimpan tempat, pindah dalam baris tanpa
    menggeser yang di luar baris, decode/encode, save, `capacity`), `NotchGeometry.zenithHomeShortcutCapacity`,
    `ZenithHomeIsland.shortcutDraft`/`controls(_:)`. Tampilan `UI/Notch/ZenithHomeShortcutsView.swift`
    (`ZenithHomeShortcutEditing`, `ZenithHomeShortcutCandidate`); state di `ZenithHomeEditor`. Teks di
    `ZenithStrings.homeShortcuts` (15 bahasa: Widgets, Shortcuts, No room in the row, Drag to reorder, Move left,
    Move right).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchSupport` (konstanta galeri kembali), `NotchService`
    (paging galeri kembali ke upstream, `pageSize` dan `expandedGeometry` membaca draft, `zenithReloadHomeControls`),
    `NotchSectionsView` (galeri list + tint), `NotchControlsView` (draft shortcut, modifier edit), `build.sh`
    (`TEST_SOURCES`).
  - **Test:** `HomeLayoutTests` (suite `home-layout`) ditambah `shortcutEditing` (tambah di akhir, tidak dobel, level
    dan player ditolak, hapus menyimpan tempat, pindah/clamp/geser, yang di luar baris tidak bergeser),
    `shortcutAvailability` (yang tidak tersedia menunggu, tidak ditawarkan, tidak bisa ditambah; ikut `isAvailable`
    upstream), `shortcutFitting` (muat tanpa gulir dan satu lagi akan menggulir di compact/spacious, lebar sempit lebih
    sedikit, minimal satu, baris penuh menolak), `shortcutPersistence` (kunci upstream terdaftar dan ikut backup,
    decode/encode, default upstream, daftar hidden mempertahankan level/`music`/nama asing, save tanpa perubahan tidak
    menulis, hasil save terbaca sama oleh `NotchSupport.controls`), `shortcutEditMode` (draft dipakai island saat edit,
    batal tidak menulis, selesai menyimpan), dan teks. Dihapus: `galleryPages` (model paging galeri sudah tidak ada).
    Diubah kembali ke angka list (tujuan sama: tinggi galeri = tiga baris tile upstream): `NotchTests` blok galeri (8
    baris, 2/2/1 kolom, ≤ 3 posisi baris) + cek tile tint muat di baris, `NotchSectionPagingTests` (swipe samping
    menggeser satu baris).
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Galeri dan mode edit shortcut dirender statis sebagai mock
    dari komponen Kit asli (`ImageRenderer`). Perlu dicek di Mac (120 Hz): galeri (tile tint di island hitam dan kaca,
    kursor keyboard, modul aktif, swipe samping), tile Home/Tools tenang (titik aktif, merah saat rekam/mic mati), strip
    (segmented, ✕/✓, ganti sisi), drag shortcut (tetangga bergeser, drop, drag sampai keluar island, rail dua baris
    di Spacious), ikon terbang dari strip, hapus, island melebar/meninggi saat shortcut bertambah, tooltip redup,
    Reduce Motion, VoiceOver.
- **Isi pil tab dipilih dari Settings (branch `feat/tab-bar-settings`):** Faiz ingin memilih modul apa saja yang ada di
  pil tab dan urutannya, hanya dari Settings (tanpa mode edit di island).
  - **Kartu "Tab bar"** di Settings › Dynamic Island › Layout, di bawah kartu ukuran (`UI/Settings/ZenithTabBarSettings.swift`,
    kait satu baris di `NotchSettings.layoutPage`). Judul digambar sendiri di atas kartu hairline (`SettingsCard` tanpa
    `title:`, seperti kartu Notices, supaya test cakupan pencarian tidak menuntut judul baru), isinya dari atas:
    - preview pil yang hidup, digambar dengan view pil yang sama dengan island (`ZenithIslandDockPill`) di tile abu-abu;
      tab yang dipilih: halaman sekarang contoh (modul pertama yang tampil tapi tidak di-pin) kalau "Show the current
      page" nyala, kalau tidak tab pin pertama. Badge memakai jumlah asli, dengan contoh (3 dan 2) selama kosong, supaya
      saklarnya kelihatan efeknya. Berubah dengan spring morph saat saklar/urutan berubah.
    - saklar "Show the tab bar" (default nyala);
    - "Tabs": semua modul island dalam urutan pil (yang di-pin dulu, lalu sisanya dalam urutan island), tiap baris tile
      glyph lembut (`ZenithIslandGlyphTile` + `zenithTint`), nama, saklar (nyala = di-pin). Baris yang di-pin punya
      handle drag (`PanelReorderableItem`, drag yang sama dengan daftar Sections di tab Content) plus tombol ▲/▼ dan aksi
      VoiceOver Move up/Move down (drag di Settings belum bisa dicek di sini, jadi tombol jadi jalur pasti). Modul yang
      tidak bisa tampil diredupkan dengan alasannya: mati di tab Content ("Show “X” on the Content tab.", kalimat
      upstream), fiturnya mati (`enableReason`), GitHub tanpa gh, selain itu teks `disabled` upstream; saklarnya mati.
    - baris tetap terakhir "Explore" (glyph grid, "Always last", gembok), tidak bisa dimatikan atau dipindah;
    - caption batas "Up to 6 tabs…", berganti "The tab bar is full…" saat penuh; saklar sisanya dimatikan;
    - saklar "Show the current page" dan "Badges" (default nyala).
    Saat bar mati, semua di bawah saklar utama diredupkan dan tidak bisa diubah (pilihan tetap tersimpan).
  - **Kunci** (semua terdaftar di `registeredDefaults`, jadi ikut backup): `zenithTabBarEnabled` (Bool, `true`),
    `zenithTabBarModules` (raw value modul dipisah koma, urutan pil, default `controls,files`), `zenithTabBarCurrentPage`
    (Bool, `true`), `zenithTabBarBadges` (Bool, `true`). Nama yang tidak dikenal dan modul yang tidak tampil dilewati saat
    dibaca, tapi tetap disimpan di tempatnya (backup dari versi lebih baru tidak kehilangan pin; modul yang kembali tampil
    muncul lagi di posisinya). Modul baru di versi berikutnya tidak otomatis di-pin. `""` = tidak ada pin (bukan default).
  - **Model murni** `Services/Notch/ZenithTabBarSupport.swift` (ikut `TEST_SOURCES`): `ZenithTabBarItem`
    (`module`/`page`/`gallery`), `ZenithTabBarPins` (decode/encode, `visible` = dikenal + tampil + maks. 6, `canPin`,
    `pinning` di akhir, `unpinning`, `moving`/`reordering` hanya menggeser slot yang tampil, `listed` untuk kartu),
    `ZenithTabBarConfiguration`, `ZenithTabBar` (`maximumPinned` 6, `layout`, `badge`, `symbol`, `configuration(in:)`,
    `sectionsButtonInRow`), `ZenithTabBarAvailability` (`available`/`hidden`/`unavailable`).
  - **Perilaku pil:** `ZenithIslandDockView` membaca tiga kunci lewat `@AppStorage`, jadi perubahan dari Settings langsung
    dipakai dan bergerak dengan spring morph yang sama (kapsul pilihan tetap meluncur). Isi: pin yang tampil (≤ 6) dalam
    urutannya, lalu tab halaman sekarang kalau halaman itu tidak di-pin atau sedang ada detail (dan saklarnya nyala),
    lalu galeri selalu terakhir. Kalau saklar halaman sekarang mati dan halaman tidak di-pin, tidak ada tab terpilih.
    Klik tab pin membuka modulnya; tab halaman di detail tetap kembali. Badge: jumlah Shelf di Files dan jumlah notifikasi
    di Notifications (`NotchNotificationService.items`), bisa dimatikan. Glyph Home/Files tetap versi filled
    (`house.fill`, `tray.fill`), modul lain glyph modulnya. Menu klik kanan Customize Home tetap di tab Home.
    `maximumWidth` (koridor hover) 220 → 360: muat 8 tab dengan dua badge. Pil digambar ulang sebagai
    `ZenithIslandDockPill` (dipakai island dan preview Settings); `ZenithIslandDockItem` diganti `ZenithTabBarItem`, id
    aksesibilitas tetap (`notch.dock.home`, `.files`, `.page`, `.sections`; pin lain `notch.dock.<raw>`).
  - **Bar mati:** pil tidak tampil (`dock:` di `present` ikut `ZenithTabBar.isEnabled()`), jendela tidak lagi memesan ruang
    di bawah island, dan tombol galeri di baris atas kembali dengan aturan upstream (`!access.actions.contains(.explore)`)
    lewat `ZenithTabBar.sectionsButtonInRow`, juga di preview island Settings (`NotchService.previewGeometry`,
    `NotchLayoutEditor`, yang ikut digambar ulang lewat `@AppStorage`). Shortcut keyboard dan galeri tidak berubah.
  - Edit di file upstream bertanda `// Zenith fork`: `Defaults` (4 kunci + default), `NotchService` (`dock:`, reservasi
    ruang, `sectionsButtonInRow`, `previewGeometry`), `NotchLayoutEditor` (preview), `NotchSettings` (kartu), `build.sh`
    (`TEST_SOURCES`), `Tests/MetricsTests.swift` (suite). Teks di `ZenithStrings.tabBar` (15 bahasa, apostrof lengkung,
    tanpa em dash; "Drag to reorder" dipakai ulang dari `homeShortcuts`, "Explore" dari `sectionsTitle`).
  - **Test:** baru `Tests/TabBarTests.swift` (suite `tab-bar`): parse/serialisasi dan nama asing, ketersediaan
    (routed/hidden/unavailable, pin yang kembali di tempatnya, daftar kartu), batas 6 (yang ketujuh ditolak, hanya pin
    yang tampil dihitung), urutan (geser, clamp, drag hanya permutasi pin yang tampil), galeri selalu terakhir dan
    sekali, aturan halaman sekarang (nyala/mati, pin, detail), badge, default = pil lama persis (dibandingkan dengan
    aturan lama di semua halaman, detail, galeri, dengan/tanpa Files), tombol galeri baris atas kembali saat bar mati
    (dan tidak saat tombol mengambang Explore ada), kunci terdaftar + ikut backup + save tanpa perubahan tidak menulis, teks.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac: kartu Tab bar (light/dark, lebar Settings
    sempit, preview pil di tile, baris redup + alasan, caption batas, Explore terkunci), drag baris pin dan tombol ▲/▼,
    pil di island berubah langsung saat saklar/urutan diganti (spring, kapsul pilihan meluncur, tab masuk/keluar), 6 pin +
    halaman sekarang + badge (lebar pil dan koridor hover), bar mati (pil hilang, tombol galeri kembali di baris atas
    island dan preview Settings, tanpa ruang kosong di bawah island), badge notifikasi, VoiceOver.
- **Dev servers di island (branch `feat/dev-servers`):** dev server yang sedang jalan (Next.js, Vite, Laravel, …)
  tampil sebagai halaman island sendiri, widget Home, notice kapsul saat ada yang baru, dan (opsional) jumlahnya di
  island tertutup. Kode di `Services/DevServers/DevServersSupport.swift` (murni, ikut `TEST_SOURCES`: klasifikasi,
  nama proyek, alamat dan URL, pengelompokan, uptime, parsing argv, coalescing notice, state machine Kill),
  `DevServersProbe.swift` (libproc/sysctl, ikut `TEST_SOURCES`), `DevServersService.swift` (polling, cache, aksi),
  `UI/Notch/DevServersPage.swift`, `DevServersStrip.swift`, `DevServersWidget.swift`, `DevServersSettings.swift`. Teks di
  `ZenithStrings.devServers` (15 bahasa). Test di `Tests/DevServersTests.swift` (suite `dev-servers`).
  - **Sumber data:** tidak ada scanner kedua. Daftar port memakai pembaca Port Manager apa adanya
    (`PortManagerService.zenithListeners()`, kait satu baris ke `snapshot()` privat: lsof `-iTCP -sTCP:LISTEN` yang
    sama, sekitar 30 ms, parser `PortManagerSupport.parseLsof`). Proses di belakang tiap port dibaca sekali dari kernel
    (`DevServersProbe`): argv lewat `KERN_PROCARGS2`, folder kerja lewat `proc_pidinfo(PROC_PIDVNODEPATHINFO)`, uid,
    parent dan waktu mulai lewat `PROC_PIDTBSDINFO`, path lewat `proc_pidpath`, nama parent lewat `proc_name`. Di-cache per
    pid + waktu mulai, jadi pid yang dipakai ulang dibaca lagi. Tidak ada proses yang dijalankan selain lsof itu.
  - **Hanya yang lokal dan milik sendiri:** endpoint loopback atau wildcard (`127.x`, `::1`, `*`, `0.0.0.0`, `::`); bind
    ke IP LAN tertentu dilewati. Proses uid lain, pid Zenith sendiri, nama Zenith/Vorssaint, layanan sistem (path di
    `/System/`, `/usr/libexec/`, `/usr/sbin/`, `/sbin/`, `/Library/Apple/`, atau nama seperti ControlCenter (AirPlay di
    5000/7000), rapportd, sharingd, launchd), dan helper yang dibundel app (path berisi `.app/`, misalnya node milik
    Adobe atau Code Helper VS Code) tidak pernah tampil, bahkan kalau portnya didaftarkan sendiri. Pengecualian `.app/`:
    Python (CLT dan Homebrew menjalankan `Python.app` di dalam framework-nya) dan Docker/OrbStack.
  - **Klasifikasi** (dari nama proses lsof `+c0`, argv, parent, path):
    - Next.js: argv[0] `next-server (vX)` (judul yang dipasang Next sendiri), path `/next/dist/`, atau bin `next` + `dev`/`start`.
    - Nuxt (`nuxi`/`nuxt`), Astro, Remix (`remix`, `remix-serve`, `@remix-run/`), dicek sebelum Vite karena ketiganya
      menjalankan Vite di dalam; Vite (`.bin/vite`, `vite/bin/vite.js`, juga lewat `bun --bun vite`); webpack
      (`webpack-dev-server`, `webpack serve`).
    - PHP: `php artisan serve` dan anaknya (`php -S … /laravel/framework/…/server.php`) = Laravel; `php -S` lain = PHP;
      php-fpm tidak.
    - Python: `-m http.server` = Python, `uvicorn` (bin atau `-m`) = Uvicorn, `flask run` = Flask, `manage.py runserver` = Django.
    - Rails: `rails s`/`rails server`, atau judul Puma (`puma 6.4.2 (tcp://…)`).
    - Go: parent `go` (`go run`) atau `air`, atau binary di folder `go-build`; binary `*.test` (server test) tidak.
    - Flutter: `dart` yang menjalankan `flutter_tools.snapshot` (`flutter run -d chrome`).
    - Supabase: port 54321–54324 milik Docker (atau proses bernama supabase), satu baris untuk keempatnya, URL ke Studio
      (54323). Docker: `com.docker.*`, `docker-proxy`, `vpnkit*`, OrbStack, `limactl`; satu baris per port.
    - Runtime polos (`node`, `bun`, `deno`) hanya kalau folder kerjanya bukan `/` dan ada `package.json`/`deno.json`/
      lockfile Bun, atau argv-nya berisi `dev`, `--watch`, `--hot`, `serve`, `nodemon`, `tsx`, `ts-node`.
    - Tambahan sendiri: port (boleh rentang, `9000-9002`, maks. 64 per rentang) dan nama proses (tanpa beda huruf besar)
      jadi "custom" dengan nama prosesnya. Framework yang dikenali tetap memakai namanya walau portnya didaftarkan.
  - **Pengelompokan:** satu baris per proses (IPv4 + IPv6 port yang sama = satu, beberapa port = satu dengan port terkecil
    sebagai URL). Server yang fork dengan socket bersama (reloader uvicorn, cluster) diwakili parent-nya. Docker satu baris
    per port; Supabase satu baris. Urut menurut port.
  - **Nama proyek:** basename folder kerja proses; folder di dalam `node_modules` dan folder generik (`src`, `public`,
    `dist`, `build`, `out`, `.next`, `tmp`, `bin`) naik ke proyeknya; `/` dan home = tanpa nama (baris dipimpin nama
    framework). Docker/Supabase tanpa proyek.
  - **Alamat:** semua yang lokal dibuka sebagai `http://localhost:<port>` dan ditulis `localhost:3000` (IPv4, IPv6 dan
    wildcard sama-sama dijawab localhost, seperti yang dicetak framework-nya).
  - **Polling:** tiap 3 dtk selama halaman atau widget Home tampil (hitungan `shown()`/`hidden()`, termasuk preview di
    Settings), tiap 10 dtk hanya kalau "Announce new servers" atau hitungan island tertutup nyala (dan island jalan),
    selain itu tidak ada timer sama sekali. Timer di main run loop dengan toleransi 20%; lsof dan probe di queue
    `utility` sendiri.
  - **Halaman `NotchModule.devServers`** (⌥⌘L, glyph `server.rack`, warna hijau muda `#86EFAC`, tingkat 300 seperti Card
    Import karena tingkat 400 sudah habis). Selalu terdaftar di Content; tampil selama deteksi nyala (default nyala). Tiap
    baris kartu lembut 48 pt (radius 14): monogram framework di tile lembut warna framework (tanpa logo merek: `N`, `V`,
    `L`, `Py`, `Go`, …), proyek (13 semibold), framework + `localhost:3000` mono, uptime mono (`0:42`, `12:03`,
    `3:05:12`, `2d 03:05`) dengan `numericText` di slot selebar bacaan terlebar bentuknya, lalu Open
    (`arrow.up.right.square`, browser default), Copy URL (ikon jadi ✓ 1,6 dtk) dan Kill. Klik kanan baris: Open, Copy URL.
    Kosong: tile modul + "No dev servers running" + contoh perintah. State halaman (memuat/kosong/daftar) lewat
    `.zenithMorph(on:)`.
  - **Kill:** klik pertama mengubah tiga tombol jadi satu kapsul merah "Kill?" di tempat yang sama (Open/Copy blur dan pudar
    di bawahnya, jadi layout baris tidak bergeser); klik kedua dalam 3 dtk menghentikan, selain itu pertanyaannya lewat
    sendiri. Lalu SIGTERM lewat jalur yang sama dengan Port Manager (`KillProcessService.kill(pid:name:startedAt:force:)`,
    identitas pid + waktu mulai dicek, proses terlindungi ditolak), dan SIGKILL kalau proses yang persis sama masih ada
    setelah 3 dtk. Selama itu spinner kecil. Baris Docker/Supabase tidak punya Kill (membunuh backend Docker = Docker
    berhenti); ikonnya `shippingbox` redup dengan tooltip. Tidak digerbang `AppFeature.killProcess` (fitur opt-in Port
    Manager/Kill Process), karena yang dihentikan hanya proses milik sendiri atas dua klik eksplisit.
  - **Gerak (120 Hz):** baris masuk naik 8 pt dari blur 8 + opacity + skala 0,96, keluar blur + pudar + skala; daftar
    bergeser dengan spring `ZenithMorph`; Kill → "Kill?" spring 0,3 (skala dari kanan + opacity, blur di tombol lain).
    Reduce Motion: fade saja, tanpa gulir angka.
  - **Notice:** `ZenithNotice.Kind.devServer` (prioritas 1, tampil 5 dtk, menunggu island maks. 20 dtk), judul
    `Next.js · Swift-portfolio · localhost:3000`, subjudul "New dev server", glyph modul, aksesori `.action("Open")`, aksi
    baru `.openURL`. Coalescing di `DevServersAnnouncer`: look pertama = baseline (yang sudah jalan diam), key = proyek
    (atau framework) + port, dan key yang terlihat dalam 30 dtk terakhir dianggap restart (hot reload, nodemon, air) jadi
    tidak diumumkan; key notice yang sama juga di-coalesce oleh antrean. Saklar dimatikan lalu dinyalakan = baseline baru.
  - **Widget Home `ZenithHomeWidget.devServers`** (lebar 216): heading + jumlah, maks. tiga baris (titik hijau, proyek,
    host mono), kosong "No dev servers running", klik membuka halaman. Header dan tombol buka widget dibuka dari `private`
    supaya bisa dipakai di file sendiri.
  - **Island tertutup (opsional, default mati):** `NotchCompactActivity.devServers`, ada selama saklar nyala dan ada server.
    Kiri titik hijau `ZenithStatusDot` (live), kanan jumlah mono 11 dengan `numericText`; kapsul: titik + jumlah. Wing pinjam
    geometri Watch. Urutan otomatis setelah music, sebelum Keep Awake (jalan seharian seperti Keep Awake), tidak pernah
    berpasangan, klik membuka halaman. Rapi di sistem activity yang ada, jadi dibuat.
  - **Settings:** opsi section Dev servers di Dynamic Island → Content: "Detect dev servers" (`notchDevServersEnabled`,
    nyala), "Announce new servers" (`notchDevServersAnnounce`, nyala), "Show the count in the closed island"
    (`notchDevServersIndicator`, mati), "Also these ports" (`notchDevServersExtraPorts`) dan "Also these processes"
    (`notchDevServersExtraNames`), keduanya disimpan saat Return atau fokus pindah. Semua `ZenithSwitchRow`, tanpa
    `SettingsRow`; terdaftar di `registeredDefaults` (ikut backup).
  - Edit di file upstream bertanda `// Zenith fork`: `PortManagerService` (kait `zenithListeners`), `NotchSupport` (case
    modul dan activity, simbol, shortcut, ketersediaan, gerbang modul, tinggi konten, urutan activity), `NotchService`
    (activity, wing, kapsul, sync/stop, langganan `$indicator`), `NotchView`/`NotchMirrorView` (strip, halaman, judul),
    `NotchTimerStrip`/`NotchCapsuleViews` (tidak berpasangan), `NotchContentEditor`, `NotchEditorStrings`,
    `NotchSettings`, `Defaults`, `build.sh` (`TEST_SOURCES`), `Tests/MetricsTests.swift` (suite). File fork yang ikut
    berubah: `ZenithIslandPalette`, `ZenithAppIcon`, `ZenithNoticeSupport`/`Service` (kind, aksi), `ZenithHomeLayoutSupport`,
    `ZenithHomeWidgets`. Test diubah: `NotchMusicVisibilityTests` (double diberi `hasDevServersActivity` dan
    `devServersStripWing`), `NotchTests` (urutan modul + `.devServers`; galeri "≤ 3 posisi baris" jadi "> 1" karena 21
    modul = 11 baris; tujuannya tetap: preset perlu melangkah untuk mencapai baris terakhir).
  - **Test (`dev-servers`):** klasifikasi ~40 contoh proses/argv, layanan sistem yang diabaikan walau portnya didaftarkan,
    nama proyek dari folder, format host/URL IPv4/IPv6/0.0.0.0/LAN, uptime, pengelompokan (dual-stack, multi-port, fork,
    Docker, Supabase), parsing `KERN_PROCARGS2`, tambahan port/nama, coalescing restart, state machine Kill, notice,
    setelan (suite `com.vorssaint.tests.dev-servers`), urutan activity, dan satu test nyata: test membuka socket TCP di
    port acak 127.0.0.1, membacanya lewat lsof dengan argumen Port Manager + `parseLsof`, lalu probe (uid, waktu mulai,
    folder, argv) dan scanner (port didaftarkan → baris custom; dengan konteks asli → diabaikan karena milik Zenith
    sendiri). Tidak ada proses yang diberi sinyal.
  - **Sudah dicoba di Mac ini (tanpa UI):** harness kecil dari Support + Probe + parser Port Manager terhadap lsof asli
    menemukan `node server.js` (folder dengan package.json, bind `[::1]`) sebagai Node.js dan `python3 -m http.server` (dari
    Python.app CLT) sebagai Python, keduanya dengan nama proyek dari folder; ControlCenter, rapportd, Spotify, Figma
    agent, Code Helper VS Code, Claude Code dan `ruby` dengan socket polos tidak masuk.
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac (120 Hz): halaman (baris masuk/keluar, Kill →
    "Kill?" → spinner → baris hilang, Copy ✓, uptime bergulir), widget Home, notice + Open, hitungan di island tertutup dan
    kapsul, Settings, dengan `next dev`, `vite` dan `php artisan serve` sungguhan (Next/Vite/Laravel belum dijalankan di
    sini: tidak ada proyek dan PHP tidak terpasang).
- **Rekap akhir hari "Today" (branch `feat/daily-recap`):** ringkasan hari ini dari data yang sudah dipegang
  Zenith, sebagai halaman island, widget Home, dan notice kapsul sekali sehari di jam pilihan. Tidak ada sumber
  jaringan atau token baru. Kode di `Services/Recap/RecapSupport.swift` (murni, ikut `TEST_SOURCES`: sumber,
  setelan, jadwal, tally harian, agregasi, format kartu/headline/teks, query pencarian commit),
  `Services/Recap/RecapService.swift` (baca service lain, tally, timer, notice, salin teks),
  `UI/Notch/RecapPage.swift` (halaman, bento, count-up, aksi band, simpan gambar, widget Home) dan
  `UI/Notch/RecapSettings.swift`. Teks di `ZenithStrings.recap` (15 bahasa, bentuk one/few/many). Test di
  `Tests/RecapTests.swift` (suite `recap`).
  - **Sumber** (masing-masing opsional; kartu hanya tampil kalau ada data hari ini):
    - *Coding* (WakaTime): `WakaTimeService.today` (total, project dan bahasa teratas). Total di bawah 1 menit
      atau bertanggal kemarin dilewati. Dibaca ulang lewat `refreshIfStale()` kalau `~/.wakatime.cfg`/token ada.
    - *Deploys* (Vercel): deployment di `VercelService.deployments` yang `created` hari ini (ready/failed/building).
      Kalau belum ada baca hari ini (`lastFetch`, sekarang `private(set)`), rekap boleh memanggil `refresh()` sekali
      lewat service yang sama, hanya kalau token ada. Batas: list Vercel maks. 12 terbaru, jadi hari dengan lebih
      dari 12 deploy terhitung kurang.
    - *GitHub*: satu-satunya `gh` tambahan adalah pencarian commit (`RecapCommits`):
      `gh api -X GET search/commits -H "Accept: application/vnd.github+json" -f q="author:<login> committer-date:>=2026-11-20T00:00:00+07:00" -f per_page=1`,
      membaca `total_count` saja. Login dari inbox GitHub kalau sudah ada, selain itu `@me`; tengah malam lokal
      ditulis dengan offset zona waktu supaya "hari ini" mengikuti hari Faiz, bukan UTC. Lewat
      `BoundedProcessRunner` di luar main thread, timeout 20 dtk, paling sering tiap 10 menit, tidak jalan kalau
      `gh` tidak ada. Inbox (`GitHubService`) hanya dibaca ulang kalau bagian GitHub memang nyala. Fragment
      GraphQL inbox ditambah `createdAt` (`PullRequest.created`) untuk "PR opened today"; review yang menunggu dan
      check gagal ikut jadi catatan kartu. **PR merged/reviewed hari ini tidak dihitung**: butuh query kedua
      (mis. `contributionsCollection` atau search `merged:>=`), di luar batas satu query tambahan.
    - *Long commands*: `CommandActivityService` tidak menyimpan riwayat, jadi ditambah hook kecil: perintah yang
      selesai dan melewati threshold island dicatat ke tally (`RecapEvent.command`).
    - *Photos* (Card Import): ledger hanya menyimpan key tanpa tanggal, jadi `CardImportService.record` ikut
      mencatat jumlah foto/video dan byte per batch yang selesai tersalin (`RecapEvent.imported`).
    - *Exports*: `ExportTrackerService.announce` mencatat tiap export selesai dan ukurannya (`RecapEvent.exported`).
    - *Agent turns* (Claude Code): `ClaudeHooksService.scan` mencatat tiap event `prompt` sebagai satu turn, sesi
      dihitung dari id unik (maks. 64 diingat) (`RecapEvent.agent`).
  - **Tally harian** (`RecapTally`): hanya angka, tanpa nama/path, disimpan sebagai JSON di
    `notchRecapTally` (tidak terdaftar, jadi tidak ikut backup). Event dari hari yang lebih baru memulai tally baru;
    event telat dari hari sebelumnya diabaikan. Hari = tanggal kalender lokal saat event terjadi.
  - **Agregasi** (`RecapSupport.aggregate`): urutan coding, deploys, github, terminal, photos, exports, agents;
    sumber yang dimatikan di Settings tidak pernah tampil. Kartu (`RecapFormat.cards`): label, angka (durasi atau
    hitungan), catatan per bagian (`RecapCard.Note`, hanya bagian gagal yang merah).
  - **Jadwal** (`RecapSchedule`): default 17:00, setiap hari; "Weekdays only" melewati Sabtu/Minggu. Due kalau
    nyala, bukan hari libur, belum tampil hari itu, dan jam sudah lewat (sampai tengah malam). `notchRecapLastShown`
    (`yyyy-MM-dd` lokal, tidak ikut backup) dibandingkan sebagai string: tanggal sama **atau lebih baru** (jam
    mundur) = sudah tampil. Pindah zona ke barat ke tanggal yang sama tidak menampilkan ulang; ke timur ke tanggal
    berikutnya menunggu jam di hari itu. Jam yang dilompati DST pindah ke momen valid berikutnya. Satu `Timer` ke
    momen berikutnya (`nextCheck`), dicek ulang saat wake, ganti zona, jam sistem berubah, dan ganti hari; hanya
    selama island jalan (`NotchService.syncWithPreferences`/`stop`). Saat due: hari ditandai dulu, sumber
    diperbarui, tunggu ±6 dtk (plus pencarian commit sampai 15 dtk), lalu notice dikirim kalau hari tidak kosong.
    Island dibuka setelah jam 17:00 = notice langsung (sekali). Snooze tidak dibuat.
  - **Notice**: `ZenithNotice.Kind.recap` (prioritas 1, tampil 8 dtk, menunggu island sampai 10 menit), key
    `recap.<hari>` (tidak pernah antre dua kali), judul "Your day", subjudul headline tiga teratas
    (`6h 11m coding · 4 deploys · 1,248 photos`; urutan coding, deploys, photos, commits, exports, agents,
    commands), glyph `sun.horizon.fill` warna modul, aksesori `.action("Open")`, aksi `.openRecap` = island
    terbuka di halaman Today (setelah kapsul pergi, seperti Import kartu).
  - **Modul `NotchModule.recap`** ("Today", ⌥⌘Y, glyph `sun.horizon`, warna periwinkle `#A5B4FC` = indigo 300)
    selalu tersedia. Halaman: bento kartu `zenithIslandSoftCard` (radius 20, konsentris; tile glyph 18 pt radius
    `nestedRadius(padding: 10)`), wash warna sumber 10% → 2% dari atas, label mono kapital 9,5, angka
    `ZenithFigure` 22 pt, satu baris catatan 11 pt. Kolom: ≤ 3 kartu sebaris, 4 = 2×2, ≥ 5 = 3 kolom (2 kalau
    lebar < 400); baris terakhir yang pendek melebar penuh. Tinggi kartu 82–104 pt; kalau tidak muat (mis. 7
    kartu di island compact 180 pt) halaman menggulir. Kosong: tile + teks. Band atas: "Copy as text" dan
    "Save image" (`NotchIconButton`, ikon berganti ✓ sebentar). Ganti kosong ↔ isi lewat `.zenithMorph`.
  - **Gerak (120 Hz):** kartu naik 10 pt dari blur 8 + opacity, kurva reveal 0,45 dtk, jeda 40 ms per kartu
    (`ZenithMotion.layerDelay`); angka menghitung naik 0,8 dtk di kurva reveal lewat view `Animatable`
    (`RecapCountUp`), juga saat data baru datang. Reduce Motion: kartu hanya fade 0,2 dtk, angka langsung.
  - **Copy as text** (`RecapFormat.summary`): judul `My day · Fri, Nov 20` lalu satu baris per sumber
    (`Coding 6h 11m · Swift`, `Deploys 4 · 1 failed`, `Commits 12 · 1 PR opened`, ...). Nama project, review
    menunggu dan check gagal tidak ikut dibagikan. Lewat `GeneralPasteboardAccess`.
  - **Save image**: `ImageRenderer` (skala 2) merender `RecapShareCard` (kartu hitam radius 34, judul, tanggal,
    bento yang sama tanpa animasi, "ZENITH" kecil) ke PNG di Downloads: `Zenith Today 2026-11-20.png`, lalu
    ` 2`, ` 3` kalau sudah ada (tidak pernah menimpa). macOS bisa meminta izin folder Downloads sekali.
  - **Widget Home** `ZenithHomeWidget.today` (lebar 216, warna modul): angka terbesar hari ini + label, lalu dua
    headline berikutnya; klik membuka halaman Today.
  - **Settings**: opsi section Today di Dynamic Island → Content: saklar "Daily recap" (`notchRecapEnabled`, default
    nyala), "Show at" (`DatePicker` jam:menit, `notchRecapMinutes`, default 1020), "Weekdays only"
    (`notchRecapWeekdaysOnly`, default mati), lalu "Include" per sumber (`notchRecapHiddenSources`, daftar yang
    dimatikan). Semua `ZenithSwitchRow`, tanpa `SettingsRow`; keempat kunci terdaftar (ikut backup).
  - Edit di file upstream bertanda `// Zenith fork`: `NotchSupport` (case modul, simbol, shortcut, ketersediaan,
    tinggi konten), `NotchService` (sync/stop), `NotchView` (halaman + band, judul), `NotchContentEditor`,
    `NotchEditorStrings`, `NotchSettings` (opsi), `Defaults`, `build.sh` (`TEST_SOURCES`),
    `Tests/MetricsTests.swift` (suite). File fork yang ikut berubah: `ZenithNoticeSupport`/`Service` (kind, aksi),
    `ZenithIslandPalette`, `ZenithAppIcon` (glyph), `ZenithHomeLayoutSupport`/`ZenithHomeWidgets` (widget),
    `GitHubSupport` (`createdAt`), `VercelService` (`lastFetch` terbaca), `CommandActivityService`,
    `CardImportService`, `ExportTrackerService`, `ClaudeHooksService` (catat ke tally).
  - **Test:** baru `RecapTests` (suite `recap`): agregasi penuh dan dengan sumber hilang/kemarin, tally lintas
    tengah malam/event telat/batas sesi/round trip/tidak ikut backup, format kartu dan catatan, plural
    en/ru/sk/uk/ja, headline, teks bagikan (semua bahasa tanpa em dash/apostrof lurus), jadwal (jam, mati, akhir
    pekan, lintas tengah malam, zona waktu barat/timur, DST), setelan dan registrasi, argumen pencarian commit dan
    parse `total_count`, kind notice, palet, teks 15 bahasa. Diubah dengan sengaja: `NotchTests` urutan modul
    (+ `.recap`) dan galeri "≤ 3 posisi baris" jadi "> 1" (tiap modul fork menambah baris; tujuannya tetap:
    baris perlu digeser).
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Bento dan kartu simpan gambar dirender statis
    (`ImageRenderer`, ukuran compact 424×180 dan spacious 504×264). Perlu dicek di Mac (120 Hz): notice jam 17:00
    (dan saat island dibuka setelahnya), Open, kartu naik + blur + count-up, gulir 7 kartu di compact, ganti
    kosong ↔ isi, Copy/Save (izin Downloads), widget Home, preview di Settings, Reduce Motion, Increase Contrast,
    island kaca. Pencarian commit dengan `gh` asli (apakah `author:@me` diterima endpoint commit) belum dicoba.
- **Jadwal sholat dan golden hour (branch `feat/prayer-golden-hour`):** waktu sholat dan jendela golden/blue
  hour untuk fotografer, dihitung offline di Mac (tanpa jaringan, tanpa kode pihak ketiga). Kode di
  `Services/Sky/SolarSupport.swift` (murni: posisi matahari), `Services/Sky/PrayerTimesSupport.swift` (murni:
  metode, jadwal, penyesuaian, next/current, activity, format, kota, setelan, `SkyDay`),
  `Services/Sky/SkyService.swift` (satu timer, notice, suara), dan `UI/Notch/Sky*` (`SkyStrip`, `SkyPage`,
  `SkyWidgets`, `SkySettingsView`). Teks di `ZenithStrings.sky` (15 bahasa). Test di `Tests/SkyTests.swift`
  (suite `sky`); kedua file Support ikut `TEST_SOURCES`.
  - **Algoritma matahari:** rumus presisi rendah Meeus (bab 25 dan 28) seperti di kalkulator NOAA: bujur tampak,
    kemiringan ekliptika, deklinasi, equation of time, lalu hour angle dan elevasi geometris (pusat matahari, tanpa
    refraksi). Terbit/terbenam memakai −0,833°. Waktu untuk ketinggian tertentu dicari iteratif (6 langkah, deklinasi
    dihitung ulang di waktu itu), jadi tidak bergantung pada zona waktu. Semua fungsi mengembalikan nil atau nilai
    terhingga, tidak pernah NaN.
  - **Metode sholat** (deskripsi PrayTimes.org, ditulis sendiri): Kemenag RI (default; Subuh 20°, Isya 18°, ihtiyat
    +2 menit di semua waktu, Terbit −2, Dzuhur transit + 2), MWL 18/17, Umm al-Qura 18,5 / Isya Maghrib + 90 menit
    (tanpa aturan 120 menit Ramadan), Egyptian 19,5/17,5, ISNA 15/15, MUIS/JAKIM 20/18. Ashar Syafi'i (bayangan 1) atau
    Hanafi (2). Imsak = Subuh − 10 menit. Dibulatkan ke menit terdekat (cocok dengan tabel Kemenag), lalu
    penyesuaian per waktu −10…+10 menit; Imsak ikut Subuh yang sudah disesuaikan lalu ditambah penyesuaiannya sendiri.
  - **Lintang tinggi:** aturan angle-based (Subuh/Isya tidak lebih jauh dari matahari daripada sudut/60 malam, seperti
    Aladhan). Kalau matahari tidak terbit/terbenam (siang/malam kutub), dipakai lintang ±64° di meridian yang sama dan
    jadwal ditandai `approximated` (halaman menulis "Approximated for a high latitude").
  - **Validasi** (`SkyTests`): Kemenag Jakarta Pusat (6°10' LS, 106°49' BT) 1 Jan, 21 Jan, 15 Jun, 1 Nov, 20 Nov 2026
    dan Medan (3°35' LU, 98°39' BT) 1 Mar, 21 Mar, 15 Jul, 21 Nov 2026 dari jadwalsholat.org (parameter Kemenag):
    semua waktu ±1 menit; di koordinat brief (−6,2, 106,8 dan 3,59, 98,67) ±2 menit. Jadwal imsakiyah resmi Kemenag
    DKI 19 Feb 2026 (Imsak 04:31, Subuh 04:41, Maghrib 18:18, Isya 19:28) ±1. Metode lain vs Aladhan (Jakarta 20 Nov
    2026, Hanafi, Makkah Umm al-Qura 21 Jun, London dan Oslo MWL angle-based 21 Jun) ±1 menit (praktis sama persis).
    Matahari: deklinasi dan EoT contoh Meeus 25.a/28.a, elevasi contoh NREL SPA, civil twilight/terbit/transit/terbenam
    vs sunrise-sunset.org ±60 dtk (selisih nyata ≤ 10 dtk).
  - **Lokasi:** sumber `automatic` (posisi kira-kira milik cuaca), `city` (24 kota besar Indonesia, bawaan), atau
    `custom` (lat/long). `WeatherService` dapat kait kecil: `place` (posisi bulat terakhir, dipublish), `locateForSky`
    (minta fix hanya kalau izin sudah granted dan fix lebih tua dari batas; tidak pernah prompt, tidak membaca cuaca;
    `finishLocating` tidak fetch cuaca kalau tidak ada tampilan cuaca), dan pemberitahuan ke `SkyService` saat
    posisi/izin berubah. Izin hanya diminta lewat tombol "Allow Location" di halaman/widget/Settings. Nama tempat
    hanya tampil untuk kota pilihan, tidak pernah untuk posisi otomatis atau ketikan. Zona waktu: zona sistem.
    Teks izin lokasi (`NSLocation*UsageDescription`, Info.plist + 13 lproj) sekarang menyebut jadwal sholat dan golden
    hour, dan bahwa jadwal dihitung di Mac.
  - **Nama:** setelan "Prayer names" Automatic / Indonesian / App language. Automatic = Indonesia kalau bahasa
    pilihan Mac `id` atau region `ID` (app tidak punya bahasa Indonesia). Nama Indonesia: Imsak, Subuh, Terbit, Dzuhur,
    Ashar, Maghrib, Isya; "Waktunya Dzuhur". Nama per bahasa app ada di `ZenithStrings.sky.prayerNames` (Turki Sabah/Öğle/
    İkindi/Akşam/Yatsı, Cina 晨礼/晌礼/晡礼/昏礼/宵礼, dst.).
  - **Modul baru `NotchModule.sky`** (⌥⌘Q, glyph `sun.horizon`, warna biru langit `#93C5FD`, tingkat 300 (bentrok ⌥⌘Y dan warna dengan Today diselesaikan saat merge); golden
    `#FCD34D`, blue `#93C5FD`, warna identitas, bukan status). Selalu tersedia. Halaman (min. 196 pt): segmented
    "Prayer times | Golden hour" (`notchSkyPage`, tidak ikut backup), meta kota · metode di kanan.
    - *Prayer times:* hero (tile glyph, "NEXT · ASHAR", countdown mono 24 pt `-1:12:04` dengan `numericText` di slot
      selebar `-00:00:00`, jamnya), lalu tujuh tile lembut (Imsak…Isya): yang berikut di-tint indigo, yang sedang
      berlangsung titik kecil, yang lewat lebih redup.
    - *Golden hour:* hero ke golden hour berikut (atau sisa waktu kalau sedang berlangsung) dengan rentang mono dan arc
      kecil lintasan matahari hari ini (garis horizon, pita golden −4…+6 amber tipis, penanda dengan elevasi saat ini
      `12.4°`), lalu sampai empat tile jendela berikut (golden/blue, pagi/sore/besok, `17:21–18:04`).
    - Tanpa tempat: tile + pesan + "Allow Location" / "Open Settings" / "Choose a City" (membuka opsi Sky).
    - Ganti tab dan state lewat `.zenithMorph(on:)`; Reduce Motion: fade. Halaman di-render ulang tiap menit
      (`TimelineView(.everyMinute)`), countdown tiap detik hanya di teksnya.
  - **Live activity:** `NotchCompactActivity.prayer` dan `.golden`, urutan otomatis setelah `export`, sebelum
    `calendar`; ikut picker, tidak pernah berpasangan, wing geometri Watch, klik membuka halaman Sky.
    - *Prayer:* mulai N menit sebelum waktu (10/15/30, default 10, `notchSkyPrayerLead`) untuk sholat yang diingatkan.
      Kiri: glyph matahari/bulan per waktu (indigo) + countdown mono `-12:04`; kanan: nama sholat. Saat waktunya: kiri jam
      `11:40`, kanan "Waktunya Dzuhur" selama 2 menit (glyph bump spring sekali). Saklar `notchSkyPrayerActivity`.
    - *Golden:* 30 menit sebelum golden hour sore: kiri `☀ 17:21` amber, kanan "Golden hour in 32 min"; selama
      golden hour: jam berakhir dan "Golden hour · 18 min left". Saklar `notchSkyGoldenActivity` (default nyala). Golden
      hour pagi hanya di halaman.
    - Lebar wing dihitung dari bacaan terlebar semua fase activity itu, jadi island tidak relayout saat countdown
      berdetak atau saat waktunya tiba. `SkyService` hanya mempublish perubahan fase; detik hanya di `TimelineView`
      yang membungkus teks. Strip menahan state terakhir saat pergi (`NotchStripHold`).
  - **Notice dan suara:** `ZenithNotice.Kind.prayer` (prioritas 3, tampil 6 dtk, menunggu island sampai 120 dtk), judul
    "Waktunya Dzuhur", subjudul `11:40 · Medan · Kemenag RI` (kota hanya kalau dipilih), glyph tint Sky. Sekali per waktu,
    dan tidak diumumkan kalau ketahuan > 90 dtk setelah waktunya (Mac baru bangun). Suara opsional
    (`notchSkyPrayerSound`, default mati): system sound `Purr` 0,6, atau file audio sendiri lewat "Choose Sound File…"
    yang disalin ke `<container>/Sky/prayer-sound.<ext>` (maks. 50 MB; nama di `notchSkyPrayerSoundFile`, tidak ikut
    backup). Tidak ada rekaman adzan yang dibundel.
  - **Service:** jalan kalau island jalan dan modul Sky tampil. Satu `Timer` ke momen berikut yang mengubah activity
    (awal lead, waktu, akhir 2 menit, lead/awal/akhir golden hour, tengah malam), plus `NSCalendarDayChanged`, ganti
    zona waktu/jam, dan bangun dari tidur. Lock screen, home, dan Settings membaca `currentDay()` tanpa menyalakan apa pun.
  - **Lock screen:** item "Next prayer" (`☾ Ashar 15:04  1h 04m`) dan "Golden hour" (`17:21–18:04` / sisa menit),
    default mati (`notchLockScreenPrayer`, `notchLockScreenGolden`), paling akhir di baris jadi paling dulu dibuang
    `ViewThatFits`. Terminal readout: baris `sholat`/`prayer` (`ashar 15:04 · in 1h 04m`, `isya now`) dan `golden`
    (`17:21–18:04 · in 32m`, `now · 18m left`), keduanya mati dan masuk di akhir urutan.
  - **Home:** widget `prayer` (berikut, jam, countdown) dan `golden` (rentang, countdown, arc mini) untuk Customize Home;
    modulnya Sky. Tanpa tempat: prompt lokasi ringkas, tidak pernah meminta sendiri.
  - **Settings:** opsi section Sky di Dynamic Island → Content: Calculation (metode + sudutnya, Ashar, nama, penyesuaian
    per waktu dengan stepper), Location (Approximate/City/Custom, catatan izin + tombol, daftar kota, field lat/long),
    Reminders (saklar per sholat termasuk Imsak, countdown di island + lead, suara + pilih file/putar/kembali ke
    system sound), Golden hour (saklar activity). Semua `ZenithSwitchRow`/`ZenithSwitchStyle`, judul digambar sendiri,
    tanpa `SettingsRow`. Kunci `notchSky*` terdaftar di `registeredDefaults` (ikut backup), kecuali file suara dan tab.
  - Edit di file upstream bertanda `// Zenith fork`: `NotchSupport` (case modul dan activity, simbol, shortcut,
    ketersediaan, judul, urutan activity, tinggi konten), `NotchService` (activity, wing, kapsul, langganan, sync/stop),
    `NotchView`/`NotchMirrorView` (strip, halaman, judul, tinggi minimum), `NotchTimerStrip`/`NotchCapsuleViews` (tidak
    berpasangan), `NotchContentEditor`, `NotchEditorStrings`, `NotchSettings` (opsi), `NotchLockScreenSupport`/`Service`/
    `View` (item), `NotchLockScreenTerminalView`, `NotchLockScreenTerminalSettings`, `Defaults`, `build.sh`
    (`TEST_SOURCES`), `Tests/MetricsTests.swift`. File fork yang ikut berubah: `WeatherService`, `ZenithNoticeSupport`/
    `Service`, `ZenithIslandPalette`, `ZenithAppIcon`, `ZenithHomeLayoutSupport`/`View`/`Widgets`,
    `NotchLockScreenItems`, `NotchLockScreenTerminal`/`Support`.
  - **Test yang disesuaikan (tujuan sama):** `NotchTests` (daftar modul + `.sky`; galeri 21 modul jadi ≤ 4 posisi baris, dulu ≤ 3), `NotchMusicVisibilityTests` (double
    `hasPrayerActivity`/`hasGoldenActivity` + wing), `LockScreenTerminalTests` (urutan default dan perpindahan dengan dua
    baris baru di akhir), `NotchLockScreenTests` (semua item), `HomeLayoutTests` (widget golden memakai amber sendiri,
    bukan warna halaman Sky).
  - Desimal elevasi dan sudut metode memakai locale eksplisit (`String(format:locale:)`, test repository).
  - **Belum diverifikasi visual:** app UI tidak dijalankan. Perlu dicek di Mac (120 Hz): strip prayer/golden (wing,
    roll digit, ganti ke "Waktunya …", bump glyph), kapsul, halaman Sky (tile, hero, arc dan penanda, morph antar tab,
    island kaca), widget home, item lock screen dan baris readout, notice kapsul + suara (system dan file sendiri),
    prompt izin lokasi dari tombol Sky, Settings (stepper, field lat/long), Reduce Motion, Increase Contrast.
- **Beautify di editor screenshot (branch `feat/screenshot-beautify`):** membingkai screenshot untuk Instagram dan
  portofolio: latar, padding, sudut, bayangan, bingkai jendela, rasio, dan caption, di resolusi Retina penuh. Kode di
  `Services/QuickTools/ScreenshotBeautifySupport.swift` (gaya, gradien, preset, layout, nama file; ikut test),
  `ScreenshotBeautifyRenderer.swift` (CoreGraphics/CoreImage, tanpa main actor; ikut test),
  `ScreenshotBeautifySession.swift` (state per jendela editor, export, after capture), `UI/Screenshot/ScreenshotBeautifyStage.swift`
  (stage dan inspector) dan `ScreenshotBeautifySettings.swift`. Teks di `ZenithStrings.beautify` (15 bahasa). Test di
  `Tests/ScreenshotBeautifyTests.swift` (suite `screenshot-beautify`).
  - **Masuk:** tombol tongkat (`wand.and.stars`) di action cluster editor; tombol yang sama di thumbnail preview setelah
    capture (preview melayang dan di island) dan tombol **B** di preview. Dari preview, Beautify = Edit dengan satu
    permintaan (`ScreenshotBeautifyHandoff`, berlaku 3 dtk): editor berikutnya langsung terbuka di Beautify. Stage menutupi
    editor (editor tetap hidup di bawahnya, anotasi dan undo utuh); "Edit" atau Esc kembali ke editor.
  - **Sumber:** `ScreenshotEditorModel.beautifySource()` meratakan capture dengan anotasi dan watermark, ukuran penuh, tanpa
    backdrop upstream dan pembulatannya. Backdrop upstream diabaikan selama Beautify (keduanya tidak ditumpuk).
  - **Opsi:** latar Gradient (8 preset tenang: Ink dan Paper monokrom Satu Visual, Mist, Peach, Sage, Sky, Sand, Dusk),
    Solid (6 swatch + color well), Clear (transparan), Wallpaper (gambar desktop `NSScreen.main`, diperkecil ke 1600 px
    dan di-blur CIGaussianBlur 3,5%, di-cache per file; kalau tidak terbaca, gradien Mist menggantikan dan ada catatan).
    Padding 0–30% dari ukuran shot (akar luas, jadi strip lebar tetap wajar), sudut 0–48 pt kontinu (kurva squircle
    Apple, dibatasi ukuran shot), bayangan None/Soft/Strong (mengikuti sudut jendela transparan, tidak pernah jadi pelat
    gelap di latar Clear), bingkai jendela Light/Dark (bar 28 pt, tiga lampu 12 pt berjarak 20 pt, garis tepi tipis),
    rasio Auto/16:9/1:1/4:5/9:16, caption satu baris (SF Pro medium, min. 13 pt, warna gelap/terang menurut terang latar).
  - **Layout:** shot tidak pernah diperkecil; kanvas yang tumbuh mengikuti padding dan rasio, konten (shot + caption) di
    tengah. Hanya kanvas di atas 8192 px yang diperkecil utuh. Semua dalam piksel dengan asal kiri atas
    (`ScreenshotBeautifyLayout`), dipakai preview dan export.
  - **Render:** preview 1800 px dirender di `Task.detached` tiap perubahan (satu render jalan, perubahan di tengahnya
    digabung jadi satu render berikutnya); export penuh disiapkan di belakang 0,35 dtk setelah perubahan terakhir, jadi
    Copy, Save dan drag biasanya langsung. Ruang warna mengikuti shot (P3 tetap P3). Di harness lokal 1600×1000 @2x:
    export penuh 30–70 ms, preview 7–13 ms.
  - **Export:** Copy (PNG + TIFF, plus file di cache kecuali "image only", sama seperti editor), Save beside original
    (`<nama>-beautified.png/.jpg`, unik dengan " 2", ditulis `.withoutOverwriting`; asal = file sumber kalau ada dan di folder
    milik pengguna, file yang disimpan preview, atau folder screenshot), drag-out (file sementara 1 jam). PNG, atau JPEG
    (0,92) kalau latar tidak Clear. Export tidak menutup editor (beberapa rasio bisa diekspor berturut-turut) dan menandai
    capture sudah diekspor. Shortcut di Beautify: ⏎/⌘C copy, ⌘S save, Esc kembali. Preferensi 1x downscale tidak berlaku.
  - **Preset dan memori:** gaya terakhir (`screenshotBeautifyStyle`, JSON) dan preset bernama (`screenshotBeautifyPresets`,
    maks. 12, nama sama = ganti) terdaftar di `registeredDefaults`, jadi ikut backup. Decode per field, jadi gaya lama atau
    backup yang diedit tetap terbaca.
  - **Beautify after capture** (`screenshotBeautifyAfterCapture`, default mati, kartu "Beautify" di Screen capture): setiap
    capture baru dibingkai dengan gaya terakhir sebelum copy/save/preview/shelf (hook di `route`, setelah
    `beginLatestCapture`, lalu capture berbingkai di-route lagi). Pasangan berbingkai → mentah diingat untuk 2 capture
    terakhir, jadi Edit/Beautify dari preview membuka capture mentah di Beautify, bukan bingkai di dalam bingkai.
  - **Hook di file upstream** (bertanda `// Zenith fork`): `ScreenshotEditorController` (`beautifySource`, properti
    session, init memetakan capture, root view `ScreenshotBeautifyContainer`, `handleKey`, masuk Beautify di akhir
    `show`), `ScreenshotEditorView` (tombol), `ScreenshotQuickPreviewController` (tombol thumbnail, tombol island, tombol B),
    `ScreenshotService` (`route`, `.edit` membawa file tersimpan, `editImage(at:)` membawa URL), `ScreenshotSelectionController`
    (`Capture.sourceURL`), `ScreenCaptureSettings` (kartu), `Defaults`, `build.sh` (`TEST_SOURCES`), `MetricsTests`.
    Sengaja tidak menyentuh `openEditor`, `editFromPreview`, `perform` dan baris pertama `route`: test upstream menyalin
    fungsi itu apa adanya (`Tests/generate_sources.py`) atau memeriksa urutannya.
  - **Belum diverifikasi visual:** app UI tidak dijalankan; hasil render dicek lewat harness lokal (PNG statis). Perlu dicek
    di Mac: transisi masuk/keluar stage di 120 Hz dan Reduce Motion, slider dan preview saat digeser, inspector di jendela
    minimum, tombol di thumbnail preview dan di island, B di preview, Copy ke Figma/Slack, Save di samping file shelf dan di
    folder screenshot, drag ke Finder, wallpaper dinamis/foto/warna polos, capture P3, Beautify after capture dengan setiap
    after-capture action, VoiceOver.
- **Penyembunyi ikon menu bar (branch `feat/menubar-hider`):** ide yang sama dengan Ice/Hidden Bar, ditulis
  sendiri tanpa kode pihak ketiga. Kode di `Services/MenuBarHider/MenuBarHiderSupport.swift` (murni: setelan,
  state machine, panjang, urutan, notch, hover, penempatan awal, kurva glyph, `MenuBarHiderCore` di balik protokol
  `MenuBarHiderItemHost`/`MenuBarHiderSensing`), `MenuBarHiderItems.swift` (status item dan glyph),
  `MenuBarHiderService.swift` (event, timer, probe window server), dan `UI/Settings/MenuBarHiderSettings.swift`.
  Teks di `ZenithStrings.menuBarHider` (15 bahasa, disisipkan setelah blok Camera). Test di
  `Tests/MenuBarHiderTests.swift` (suite `menubar-hider`); file Support ikut `TEST_SOURCES`.
  - **Teknik:** tiga status item milik Zenith, dari kanan ke kiri: chevron (20 pt), divider, dan opsional divider
    "always hidden" (titik tiga). Divider yang di-collapse panjangnya `max(10.000, 2 × layar terlebar)` pt, jadi
    semua item di kirinya terdorong keluar layar; saat terbuka divider jadi garis tipis 10 pt (always 12 pt).
    Pengguna mengatur ikon dengan ⌘-drag melewati divider (gesture bawaan macOS). Posisi disimpan macOS sendiri
    lewat `autosaveName` (`ZenithMenuBarHiderChevron`, `…Divider`, `…AlwaysDivider`) di kunci
    `NSStatusItem Preferred Position <nama>`; ini state Mac, tidak ikut backup. Pertama kali, posisi di-seed
    satu poin di kiri posisi tersimpan ikon Zenith (+1, +2, +3; kalau ikon belum punya posisi, dihitung dari
    frame-nya), supaya chevron lahir di samping ikon Zenith, bukan di ujung kiri dekat notch. `behavior = []`
    (bisa diurutkan, tidak bisa di-drag keluar), kunci `NSStatusItem Visible` dibersihkan sebelum dibuat.
  - **Bagian:** collapsed (hanya ikon terlihat), hidden (bagian tersembunyi), all (termasuk always hidden).
    Klik chevron atau shortcut: buka/tutup bagian hidden. ⌥-klik: buka semua / tutup. Always hidden hanya
    terbuka lewat ⌥-klik atau menu chevron (klik kanan: Show Hidden Icons / Show All Icons / Hide Icons, daftar
    ikon di balik notch, Menu Bar Settings…), tidak pernah lewat hover atau shortcut. Divider yang sedang
    panjang menutupi area kosong menu bar; tombolnya dimatikan supaya klik di situ tidak menyorot seluruh bar,
    dan klik itu dibaca monitor lokal sebagai klik chevron.
  - **Auto-collapse:** 5/10/30 dtk/never (default 10, `menuBarHiderDelay`, 0 = never). Klik di luar menu bar
    (default nyala, `menuBarHiderCollapseOnClick`) memajukan collapse ke 0,3 dtk. Mac terkunci, tidur, layar
    tidur, atau ganti user: langsung collapse. Saat jatuh tempo, collapse ditunda per 1 dtk selama ada menu
    terbuka (window apa pun di level pop-up menu, dari `CGWindowListCopyWindowInfo`, tanpa izin), tombol mouse
    ditekan, atau pointer masih di menu bar. Popover non-menu milik app lain tidak terdeteksi; delay yang jadi
    pengamannya.
  - **Hover** (default mati, `menuBarHiderShowOnHover`): monitor `mouseMoved` global+lokal hanya selama
    collapsed (atau terbuka karena hover). Pointer diam 0,25 dtk di pita kosong antara batas kiri dan divider
    → bagian hidden terbuka; keluar dari menu bar → collapse 0,8 dtk kemudian. Batas kiri: tepi kanan notch
    dan/atau ujung menu app depan (AX, hanya kalau Accessibility sudah diizinkan, dibaca di background saat app
    berganti); tanpa keduanya hanya 160 pt di samping ikon.
  - **Ikon Zenith selalu terlihat:** sebelum collapse urutan dicek dari frame window (tepi kanan, jadi tetap
    benar walau divider sedang panjang). Kalau ikon Zenith atau chevron ada di kiri divider, collapse ditolak,
    bar tetap terbuka tanpa timer, dan Settings menulis alasannya (amber). Dicek juga 1 dtk setelah item dibuat
    dan setelah ganti layar; kalau ikon sudah terlanjur tersembunyi, bar dibuka lagi. Divider always hidden yang
    ada di kanan divider utama diabaikan (tetap pendek) dengan peringatan. Island dan window-nya tidak disentuh;
    `NotchMenuBarSpace` sudah membuang window status yang lebih lebar dari layar.
  - **Notch:** gap kamera dari `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`. "Hide items that would sit behind
    the notch" (default nyala, `menuBarHiderNotchGuard`, hanya tampil di Mac bernotch, aktif kalau always hidden
    nyala): 0,15 dtk setelah ⌥-klik, kalau divider always hidden atau ikon di bagiannya mulai di kiri tepi kanan
    notch, Zenith kembali ke bagian hidden saja (timer tetap). Nama app yang ikonnya sekarang di balik notch
    (owner window, tanpa izin) tampil di Settings dan menu chevron. Batasnya: Zenith tidak bisa memindahkan ikon
    app lain dari balik notch atau menampilkannya di panel terpisah seperti Ice Bar.
  - **Glyph:** chevron template tipis (`‹`, garis 1,6 pt) yang berputar setengah lingkaran dengan kurva spring
    Style Kit `(.34, 1.36, .5, 1)` 0,3 dtk, digambar ulang tiap frame lewat `NSView.displayLink` (120 Hz di
    ProMotion); Reduce Motion: langsung. Divider: garis 1,2 pt alpha 0,55; always hidden: tiga titik.
  - **Shortcut:** role `GlobalShortcutRole.menuBarHider`, default ⌃⌥⌘B, mati sampai `menuBarHiderShortcutEnabled`
    dinyalakan (juga butuh `menuBarHiderEnabled`). Hotkey `QuickToolHotkey(id: 97)`. Role-nya didaftarkan ke
    fitur `.quickToggles` hanya untuk halaman Shortcuts; hotkey sendiri tidak bergantung pada fitur itu. Setelah
    perekaman shortcut, `ShortcutCapture.end` mengirim `.zenithShortcutCaptureEnded` supaya hotkey terdaftar lagi.
  - **Settings:** section "Menu bar hiding" di bawah kartu Menu bar (Settings → Menu bar): saklar utama (default
    mati), peringatan urutan, Always hidden section, Hide again after (menu), Hide when clicking elsewhere, Show on
    hover, Hide items behind the notch, Keyboard shortcut + `ShortcutPreferenceRow`; lalu "How to arrange" dengan
    ilustrasi menu bar mini (ikon beraksen dengan badge ⌘ di-drag dari ikon terlihat melewati divider, loop
    `TimelineView` 3,6 dtk dengan spring yang sama; Reduce Motion: diam di posisi akhir) dan langkah-langkahnya.
    Semua `ZenithSwitchRow`, judul digambar sendiri, tanpa `SettingsRow`/`SettingsCard(title:)`. Kata kuncinya
    ditambahkan ke item pencarian Menu bar. Menyalakan saklar membuat item dengan bar terbuka dan terkunci
    (tanpa timer) supaya tidak ada ikon yang tiba-tiba hilang sebelum diatur; saat launch berikutnya bar mulai
    collapsed. Mematikan: divider dipendekkan dulu, lalu item dihapus. Semua kunci `menuBarHider*` terdaftar di
    `registeredDefaults` (ikut backup).
  - Edit di file upstream bertanda `// Zenith fork`: `AppDelegate` (start setelah status item, pendekkan divider
    saat quit), `ShortcutCapture` (notifikasi), `GlobalShortcut` (default dan role), `Defaults` (kunci),
    `GeneralToolSettings` (section), `SettingsDirectory` (kata kunci), `build.sh` (`TEST_SOURCES`),
    `Tests/MetricsTests.swift` (suite).
  - **Belum diverifikasi di Mac:** app UI tidak dijalankan. Perlu dicek: posisi awal chevron di samping ikon Zenith,
    ⌘-drag melewati divider, collapse/expand dengan putaran chevron, posisi tetap setelah relaunch (dan setelah
    quit dalam keadaan collapsed), ⌥-klik, hover, menu chevron, klik area kosong, auto-collapse dengan menu ikon
    tersembunyi terbuka, lock, notch guard di MacBook bernotch, bar yang penuh sesak, dan Reduce Motion.
- **Workspaces (branch `feat/workspaces`):** preset sekali klik yang menyiapkan Mac untuk satu mode kerja
  (coding, editing foto/video, desain). Kode di `Services/Workspaces/WorkspaceSupport.swift` (murni, ikut
  `TEST_SOURCES`: model, JSON + migrasi, contoh, edit, runner, teks notice, perintah Shortcuts, capture, rencana
  hide/quit, geometri), `WorkspaceService.swift` (simpan, jalankan satu per satu di queue latar, notice, shortcut
  global), `WorkspaceSystemPerformer.swift` (langkah di Mac sungguhan + AX + capture), `WorkspaceAudio.swift`,
  `WorkspaceCommandBar.swift`, `UI/Settings/WorkspacesSettings.swift`, `UI/Settings/WorkspacesStepEditor.swift`,
  `UI/Notch/WorkspacesHomeWidget.swift`. Teks di `ZenithStrings.workspaces` (15 bahasa, apostrof lengkung, tanpa em
  dash). Test di `Tests/WorkspacesTests.swift` (suite `workspaces`).
  - **Model:** `Workspace` (id, nama, SF Symbol dari 16 pilihan, warna `WorkspaceColor` dari palet tenang island
    (tingkat 400: blue, indigo, violet, rose, orange, amber, green, teal), `isEnabled`, `isExample`, shortcut
    `GlobalShortcut.storageValue`, langkah berurutan). `WorkspaceStep` = id + saklar + `WorkspaceAction`:
    `openApps` (app per bundle ID lalu path terakhir, plus target opsional: folder, file, atau link),
    `hideOthers`, `quitApps`, `arrange` (`WorkspaceArrangement`: app + posisi Window Layout atau `WorkspaceFrame`
    hasil capture), `keepAwake(on/off)`, `focus(shortcut:)`, `sound` (UID device + volume opsional), `wallpaper`,
    `openURL`.
  - **Penyimpanan:** JSON di satu kunci terdaftar `zenithWorkspaces` (default `""`, jadi ikut backup):
    `{"version":1,"workspaces":[…]}`. `""` = Mac yang belum pernah mengedit, menampilkan dua contoh; simpan pertama
    menulisnya sungguhan (daftar kosong tetap kosong). Versi 0 (list polos) dibaca; field yang hilang memakai default,
    langkah/app/warna/posisi yang tidak dikenal dilewati atau jatuh ke default (posisi asing = maximize, warna asing =
    blue), id ganda dibaca sekali. Teks rusak = tidak ada workspace (bukan contoh lagi).
  - **Contoh:** "Coding" (VS Code, Chrome, Terminal, Claude; hide others; VS Code kiri 2/3 + Chrome kanan 1/3; Keep
    Awake nyala; Focus "Coding Focus" mati) dan "Editing" (DaVinci Resolve, Lightroom Classic, Finder; hide others;
    Resolve maximize; Keep Awake; Focus "Editing Focus" mati). Keduanya `isEnabled = false` dan `isExample`; edit apa pun
    menghapus tanda contoh. Id contoh tetap. App yang belum terpasang dilaporkan, tidak ditebak.
  - **Menjalankan:** `WorkspaceRunner.run` menjalankan langkah yang nyala sesuai urutan lewat `WorkspacePerforming`
    (protokol, jadi test memakai performer palsu). Masalah tiap langkah dicatat (sekali per jenis) dan langkah
    berikutnya tetap jalan. Satu run sekaligus, di `DispatchQueue` latar; AppKit dan service lain disentuh di main
    thread. Hasil: notice kapsul `ZenithNotice.Kind.workspace` (prioritas 3, tampil 6 dtk, menunggu island maks.
    30 dtk, key `workspace.<id>`), glyph workspace dalam warnanya (`Tone.hex`, baru), judul "Coding workspace ready" +
    "Everything is in place" + centang, atau "Coding workspace ran with problems" + dua masalah pertama dan "+N more".
    Island mati = notifikasi biasa (`Notifier.post`). Hasil terakhir juga tampil di Settings.
  - **Langkah dan fitur yang dipakai ulang:**
    - *Open apps:* `NSWorkspace.openApplication` / `open(_:withApplicationAt:)` (target `~`/path = file, skema = link,
      host polos = https), tunggu sampai `isFinishedLaunching` (maks. 15 dtk) lalu jeda 0,35 dtk.
    - *Hide other apps:* `NSRunningApplication.hide()` untuk app reguler yang tidak dibuka/diatur workspace, tidak
      pernah Zenith (semua bundle ID lama Vorssaint ikut).
    - *Quit apps:* aturan dan pengecualian Quit Apps (`QuickTogglesSupport.shouldQuitApp`,
      `sanitizedQuitAllExceptions`, Finder/Phone/Zenith selalu aman), hanya `terminate()`, tidak pernah force quit;
      app milik workspace sendiri tidak pernah ditutup; yang masih terbuka setelah 6 dtk (mis. minta simpan) dilaporkan.
      Catatan: Quit Protection upstream hanya menjaga ⌘Q/⌘W keyboard, tidak punya daftar app terlindungi, jadi
      yang dihormati di sini adalah pengecualian Quit Apps.
    - *Arrange windows:* geometri Window Layout (`WindowLayoutGeometry.rect` dengan gap, margin, dan
      `windowLayoutVisibleFrame` milik user) di display tempat jendela berada; set ukuran/posisi lewat AX di
      `WorkspaceWindows` dengan `EnhancedUserInterfaceSuspension`. `WindowLayoutService.apply` hanya bekerja di jendela
      yang fokus dan semua fungsi per-jendelanya `private`, jadi tidak dipanggil (tanpa kait di file upstream). Pilihan
      posisi = semua aksi Window Layout dengan kapabilitas `.frame` kecuali pindah display. Butuh Accessibility;
      tanpa izin, langkah ini melapor "needs Accessibility" dan halaman menampilkan `PermissionRow`.
    - *Keep Awake:* `KeepAwakeManager.activate(minutes: 0)` / `deactivate`. Karena `activate` menyimpan durasi sebagai
      pilihan default user, `defaultDuration` dan `keepAwakeSwitchUsesUntil` dikembalikan setelahnya. Fitur mati di
      Features = dilaporkan.
    - *Focus:* `/usr/bin/shortcuts run "<nama>"` lewat `BoundedProcessRunner` (timeout 30 dtk), nama sebagai satu
      argumen (tanpa shell); Settings menampilkan perintahnya dengan kutip tunggal. macOS tidak punya API Focus publik,
      jadi UI menjelaskan: buat Shortcut yang menyetel Focus, lalu ketik namanya.
    - *Sound output:* lewat mixer (`AppVolumeMixer.setUniversalOutputDeviceUID`) kalau device ada di daftarnya, kalau
      tidak (fitur suara mati, daftar mixer kosong) langsung lewat HAL di `WorkspaceAudio`; volume lewat
      `AppVolumeMixer.setSystemOutputVolume`.
    - *Wallpaper:* `WallpaperService.apply` (semua display/Space sesuai setelannya) kalau fitur wallpaper nyala, kalau
      tidak `NSWorkspace.setDesktopImageURL` per layar.
    - *Open a link:* `NSWorkspace.open`.
  - **Capture current:** app reguler yang terlihat (tanpa Zenith), diurutkan dari belakang ke depan menurut
    `CGWindowListCopyWindowInfo` (tanpa izin), jadi saat dibuka ulang yang paling depan kembali di depan. Frame jendela
    depan dibaca lewat AX (kalau diizinkan) dan disimpan relatif ke display-nya dengan UUID display
    (`CGDisplayCreateUUIDFromDisplayID`) dan ukuran display saat itu. Saat dijalankan: display yang sama = posisi
    persis; display hilang = display utama secara proporsional; selalu dijepit ke area terlihat.
  - **Entry point:** Command Bar (`CommandBarCatalog.workspaceEntries`, baris "Workspace: Coding" ber-id
    `action.workspaces.<uuid>` sehingga alias, pin, dan shortcut baris Command Bar ikut jalan), shortcut global per
    workspace (`QuickToolHotkey` id 1800+posisi, maks. 32, konflik dicek terhadap role upstream dan workspace lain),
    widget Home `ZenithHomeWidget.workspaces` (lebar 252, warna cyan 300 `#67E8F9`, maks. tiga tile tenang, klik =
    jalan, spinner selama jalan), Settings (Run Now di daftar dan editor). Panel menu bar **tidak** diberi entry: perlu
    `PanelSectionID` baru dengan sekitar tujuh switch di file upstream, tidak sederhana.
  - **Settings:** halaman baru `SettingsPage.workspaces` di Utilities (bagian aplikasi, tanpa `AppFeature`, jadi tidak
    ada saklar di Features dan hitungan fitur upstream tidak berubah). `SettingsPageHeader` + tombol Capture Current dan
    New Workspace; kartu daftar (tile glyph lembut dalam warna workspace, nama, tag EXAMPLE, ringkasan langkah, shortcut
    mono, tombol play); di bawahnya editor: nama, simbol, warna, saklar "Use this workspace" (`ZenithSwitchRow`),
    shortcut (`ShortcutRecorderButton`), Run Now, Delete (konfirmasi), hasil terakhir; lalu "Steps" dengan menu Add Step,
    tiap langkah: tile, ▲/▼, hapus, saklar (`ZenithSwitchStyle`), dan isinya. Pemilih app `NSOpenPanel` hanya `.app`
    (mulai di /Applications), pemilih target folder/file, pemilih gambar. Judul digambar sendiri, `SettingsCard` tanpa
    `title:`, tanpa `SettingsRow`, jadi tidak masuk test search coverage; halaman bisa dicari lewat
    `SettingsDirectory` (`ZenithWorkspacesSearch.keywords`). Gerak: spring `ZenithMotion` (opacity/scale saja), Reduce
    Motion = fade.
  - Edit di file upstream bertanda `// Zenith fork`: `Defaults` (kunci + default), `FeatureVisibilitySupport` (case
    halaman), `SettingsView` (detail + header sendiri), `SettingsDirectory` (item), `CommandBarCatalog.build` (satu
    baris), `AppDelegate` (`WorkspaceService.shared.start()`, hanya mendaftarkan shortcut kalau ada), `ShortcutCapture.end`
    (daftar ulang shortcut workspace setelah merekam), `build.sh` (`TEST_SOURCES`), `Tests/MetricsTests.swift` (suite).
    Test upstream yang ikut disesuaikan: `CommandBarFeatureTests` (stub `workspaceEntries` di host build),
    `ShortcutClearingTests` (stub `WorkspaceService`), `HomeLayoutTests` (widget tanpa halaman sekarang weather dan
    workspaces). File fork yang ikut berubah: `ZenithNoticeSupport`/`Service`/`View` (kind, `Tone.hex`),
    `ZenithHomeLayoutSupport`/`View`/`Widgets` (widget).
  - **Test (`workspaces`):** round trip semua jenis langkah, migrasi v0/versi baru/field hilang/langkah asing, contoh,
    urutan (geser, clamp, tambah, hapus, mati), runner dengan performer palsu (urutan, langkah mati dilewati, gagal
    tidak menghentikan, masalah unik, berhenti di antara langkah), teks notice (siap, masalah, +N, tanpa nama, 15
    bahasa), perintah Shortcuts (trim, NUL, karakter shell literal, kutip tampilan), target path/link, capture (display,
    relatif, lintas display, di luar layar, display hilang proporsional, jepit, tanpa Zenith/duplikat/bundle kosong,
    tanpa AX), rencana hide/quit, konversi AX ↔ AppKit, registrasi + backup, kind notice, teks. Tidak ada app yang
    dibuka atau ditutup.
  - **Belum diverifikasi di Mac:** app UI tidak dijalankan. Perlu dicek: halaman Settings (terang/gelap, lebar sempit,
    editor langkah, pemilih app, perekam shortcut, konfirmasi hapus), Run Now dengan app sungguhan (urutan buka, jeda,
    hide, quit yang minta simpan), arrange dengan VS Code/Chrome (gap Window Layout, display kedua), Capture Current
    lalu jalankan di susunan display lain, Keep Awake (durasi default tidak berubah), Shortcut Focus sungguhan, ganti
    output (dengan dan tanpa fitur Mixer), wallpaper (dengan dan tanpa fitur Wallpaper), notice kapsul (siap/masalah,
    notch dan capsule), widget Home (spinner, Reduce Motion), baris Command Bar, shortcut global setelah merekam
    shortcut lain.
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
