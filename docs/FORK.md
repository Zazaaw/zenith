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
| Atribusi | "Based on Vorssaint" wajib di About dan README; header copyright upstream tidak boleh dihapus |

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

**1b. Belum dikerjakan:**

- Teks UI di 15 bahasa (sekitar 1.880 kemunculan "Vorssaint"), termasuk label ikon
  menu bar `keepAwakeActiveIconVorssaint`.
- Nama folder backup pengaturan (`SettingsBackupSupport`: "vorssaint").
- `Tools/uninstall.sh` masih untuk Vorssaint. **Jangan dijalankan untuk Zenith.**
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

# 5. Teks brand "Vorssaint" baru yang dibawa upstream (di luar header copyright),
#    supaya bisa diarahkan ke file brand Zenith.
git diff "$BASE" main -- Sources | grep -E '^\+' | grep -v 'Copyright (C)' | grep -i vorssaint

# 6. Merge ke dev, selesaikan konflik, lalu validasi.
git switch dev
git merge main
./build.sh && ./build/Vorssaint --selftest && ./build.sh --test
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
