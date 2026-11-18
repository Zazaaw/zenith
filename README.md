<p align="center">
  <img src="Resources/Brand/AppIcon-Default.png" width="128" alt="Zenith app icon">
</p>

<h1 align="center">Zenith</h1>

<p align="center">
  A menu bar and notch toolkit for macOS, by <a href="https://github.com/satuvisual">Satu Visual</a>.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B%20Apple%20Silicon-black" alt="macOS 14 and newer, Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-black" alt="License GPL 3.0 or later"></a>
  <img src="https://img.shields.io/badge/status-in%20development-black" alt="In development">
</p>

Zenith lives at the top of your screen, in the menu bar and around the notch, and
gathers the small tools a Mac should have had all along. Everything runs on your Mac,
with no account and no tracking.

> **Status:** Zenith is in active development and has no public releases yet. Build it
> from source (see below).

## What's inside

**Sound.** A per-app volume mixer with boost past 100%, per-app output, an output
switcher and microphone controls.

**Know what your Mac is doing.** System monitor for CPU, GPU, memory, temperatures and
battery, fan control, menu bar readouts, network and speed test, and alerts.

**Windows and the Dock.** An app and window switcher with live previews, window
layouts and snapping, Dock previews, Dock click actions, fixed Space order, and
protection against accidental ⌘Q and ⌘W.

**Keyboard and mouse.** Text snippets, smooth and linear scrolling, pointer
acceleration control, side and extra mouse buttons, a super key, and fixes for worn
keyboards and mice.

**Clipboard, files and links.** Clipboard history, paste as plain text, a drag-and-drop
shelf, Finder cut and paste, clean URLs and a disk image installer.

**Everyday tools.** A notch island for music, notifications, calendar, timers,
downloads and AI agent usage; a command bar; a quick panel; quick toggles; a radial
menu; a scratchpad; and a cleaning mode that locks the keyboard.

**Capture and create.** Screenshots with annotation and scrolling capture, screen
recording with editing, camera preview, text recognition, a color picker and local
media tools.

**App management.** App updates, cleaner, uninstaller, Homebrew manager and a port
manager.

**Energy and display.** Keep awake, per-display brightness, extra XDR brightness and
Bluetooth handling on sleep.

Each feature can be switched on or off on its own, and every macOS permission is
optional and explained in plain words.

## Private by default

Zenith keeps your data on your Mac. It has no account, analytics or tracking, and it
does not send feedback, upload screenshots or check for updates. The network is used
only by things you start yourself, such as the speed test, Homebrew actions and the
optional lyric lookup.

## Build it yourself

You need a Mac with Apple Silicon, macOS 14 Sonoma or newer, and the Xcode Command
Line Tools. Xcode itself is not required.

```sh
git clone https://github.com/satuvisual/zenith.git
cd zenith
./build.sh --dev            # build the Developer variant
./build.sh --dev --install  # install "Zenith (Developer)" and open it
```

The first `--dev` build creates a local signing identity in its own keychain so the
permissions you grant survive rebuilds. Development notes, the branch model and how the
project follows its upstream are in [docs/FORK.md](docs/FORK.md).

## Credits

Zenith is based on [Vorssaint](https://github.com/vorssaint/vorssaint-utils), the free
and open-source macOS menu bar toolkit, and follows its development. All of the core
features come from that project and its contributors. Thank you.

## License

[GPL 3.0 or later](LICENSE). Zenith's changes are © 2026 Satu Visual; the original code
is © 2026 Vorssaint and its contributors, under the same license.

<p align="center">
  <sub>Made by <a href="https://github.com/satuvisual">Satu Visual</a></sub>
</p>
