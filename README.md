<p align="center">
  <img src="Resources/Brand/AppIcon-Default.png" width="128" alt="Zenith app icon">
</p>

<h1 align="center">Zenith</h1>

<p align="center">
  <b>A Dynamic Island and menu bar toolkit for your Mac.</b><br>
  Made by <a href="https://github.com/satuvisual">Satu Visual</a>. Free, open source, and everything stays on your Mac.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B%20%C2%B7%20Apple%20Silicon-black?logo=apple" alt="macOS 14 and newer, Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-black" alt="License: GPL 3.0 or later"></a>
  <a href="../../releases/latest"><img src="https://img.shields.io/github/v/release/satuvisual/zenith?include_prereleases&label=latest%20release&color=black" alt="Latest release"></a>
</p>

<p align="center">
  <a href="../../releases/latest"><img src="https://img.shields.io/badge/Download%20for%20Mac-0A0A0A?style=for-the-badge&logo=apple&logoColor=white" height="40" alt="Download for Mac"></a>
</p>

<p align="center">
  <img src="docs/images/hero.gif" width="100%" alt="The Dynamic Island opening from the notch into Home, switching to the calendar and closing again">
</p>

Zenith turns the notch into a Dynamic Island and fills the menu bar with the small
tools a Mac should have had all along: music, timers, your calendar, a lock screen
with lyrics, unlocking by looking at your Mac, a volume mixer, a system monitor, a
window switcher, clipboard history and many more. Every feature can be switched off on
its own, and nothing needs an account.

## Highlights

<table>
  <tr>
    <td width="33%" valign="top">
      <a href="#dynamic-island"><img src="docs/images/tile-island.jpg" width="100%" alt="The Dynamic Island open on Home"></a>
      <b>Dynamic Island</b><br>
      <sub>Music, timers, calendar, notices and live activities, with iOS-style motion.</sub>
    </td>
    <td width="33%" valign="top">
      <a href="#lock-screen"><img src="docs/images/tile-lock-screen.jpg" width="100%" alt="The lock screen with the clock and lyrics"></a>
      <b>Lock Screen</b><br>
      <sub>The song and its lyrics, your jobs and the weather while the Mac is locked.</sub>
    </td>
    <td width="33%" valign="top">
      <a href="#face-unlock"><img src="docs/images/tile-face-unlock.jpg" width="100%" alt="Face Unlock settings"></a>
      <b>Face Unlock</b><br>
      <sub>Unlock by looking at your Mac. Opt-in, off by default.</sub>
    </td>
  </tr>
  <tr>
    <td width="33%" valign="top">
      <a href="#iphone-remote"><img src="docs/images/tile-iphone-remote.jpg" width="100%" alt="iPhone Remote settings"></a>
      <b>iPhone Remote</b><br>
      <sub>Lock your Mac or check on it from your iPhone.</sub>
    </td>
    <td width="33%" valign="top">
      <a href="#the-menu-bar-panel"><img src="docs/images/tile-menu-bar-panel.jpg" width="100%" alt="The menu bar panel"></a>
      <b>Menu bar panel</b><br>
      <sub>Keep awake, the mixer, system stats and quick toggles, one click away.</sub>
    </td>
    <td width="33%" valign="top">
      <a href="#the-toolkit"><img src="docs/images/tile-tools.jpg" width="100%" alt="The About page listing Zenith's features"></a>
      <b>80 tools</b><br>
      <sub>Windows, keyboard, mouse, clipboard, capture and app management.</sub>
    </td>
  </tr>
</table>

## Dynamic Island

<p align="center">
  <img src="docs/images/island-open-close.gif" width="100%" alt="The island springing open from the notch and closing again">
</p>

The island grows out of the notch and settles back with a spring, the way it does on
iPhone. Hover or click to open it; your music, timers and live activities sit beside the
camera while it is closed. On a display without a notch it floats as a capsule.

<p align="center">
  <img src="docs/images/island-activities.jpg" width="100%" alt="The closed island showing music, a timer with a download, AI agents at work, the next prayer time and a Vercel build">
</p>

**Live activities** show what is going on at a glance: the song playing, a timer, a
download, AI coding agents at work, a build on Vercel, the next prayer time, a meeting
about to start or a long terminal command.

<p align="center">
  <img src="docs/images/island-notices.gif" width="100%" alt="A prayer time notice and the charging notice growing out of the notch">
</p>

**Notices** pop out of the notch for the moments that matter: charging, volume and
brightness, AirPods connecting, a finished download, a prayer time, or Claude asking for
you.

<table>
  <tr>
    <td width="50%"><img src="docs/images/island-tab-bar.jpg" width="100%" alt="Home with its widgets and the tab bar under the island"></td>
    <td width="50%"><img src="docs/images/island-calendar.jpg" width="100%" alt="The calendar's month view in the island"></td>
  </tr>
  <tr>
    <td><sub><b>Home</b> gathers widgets for now playing, the mixer, Keep Awake, timers and your next event, with a tab bar for the other pages.</sub></td>
    <td><sub><b>Calendar</b> in a week or month view, with your appointments beside it.</sub></td>
  </tr>
  <tr>
    <td><img src="docs/images/island-player.jpg" width="100%" alt="The music player page"></td>
    <td><img src="docs/images/island-drop.jpg" width="100%" alt="Drop zones: Files, AirDrop and Optimize media"></td>
  </tr>
  <tr>
    <td><sub><b>Now playing</b> from Music, Spotify and your browser, with lyrics and the queue.</sub></td>
    <td><sub><b>Drop zones</b>: drag a file onto the notch to keep it on the shelf, AirDrop it or shrink it.</sub></td>
  </tr>
</table>

<p align="center">
  <img src="docs/images/island-page-swap.gif" width="100%" alt="The island swapping from Home to the calendar and back">
</p>

**For developers**, the island follows Claude Code, Codex, GitHub Copilot and OpenCode
sessions with their usage and limits, your Vercel deployments, pull requests waiting on
GitHub, your coding time from WakaTime, running dev servers and the current Git branch.

<table>
  <tr>
    <td width="33%"><img src="docs/images/island-wakatime.jpg" width="100%" alt="WakaTime coding time"></td>
    <td width="33%"><img src="docs/images/island-github.jpg" width="100%" alt="GitHub pull requests"></td>
    <td width="33%"><img src="docs/images/island-vercel-page.jpg" width="100%" alt="Vercel deployments"></td>
  </tr>
</table>

<p align="center">
  <img src="docs/images/settings-island.png" width="100%" alt="The Dynamic Island settings with its visual editor">
</p>

Arrange the island in a visual editor: drag buttons around it, pick its size and choose
what shows while it is closed.

## Lock Screen

<p align="center">
  <img src="docs/images/lock-screen-minimal.jpg" width="100%" alt="The minimal lock screen: date, clock, activity row and the current lyric over the wallpaper">
</p>

While your Mac is locked, Zenith draws over the wallpaper: the clock, a row with your
running jobs as progress rings, the weather and the next prayer time, and the song with
its current lyric. A terminal readout can show the last lines of a long command, and the
island greets you as you lock and welcomes you back when you return.

<p align="center">
  <img src="docs/images/lock-screen-lyrics.jpg" width="100%" alt="Full-screen lyrics with the album art and playback controls">
</p>

Switch to **full-screen lyrics** for a view tinted with the album's colours, with the
cover, playback controls and the words as they are sung.

<p align="center">
  <img src="docs/images/settings-lock-screen.png" width="100%" alt="Lock Screen settings with a live preview">
</p>

Settings shows a live preview of the lock screen; click any part of it to change it.

## Face Unlock

<p align="center">
  <img src="docs/images/lock-face-unlock.gif" width="100%" alt="The island scanning a face on the lock screen, confirming it, then welcoming the user back">
</p>

Look at your Mac and it unlocks: the island scans, confirms, and welcomes you back.
Zenith recognizes your face on the Mac itself with its ordinary camera, checks that it
sees a live person, and then types your login password for you. It is adapted from
[Glance](https://github.com/jonnyoo/glance) by Jonathan Zhou, needs macOS 15, and is
**off until you turn it on**. Read the [security notice](#face-unlock-security-notice)
first.

<p align="center">
  <img src="docs/images/settings-face-unlock.png" width="100%" alt="Face Unlock settings">
</p>

## iPhone Remote

<p align="center">
  <img src="docs/images/iphone-remote-island.jpg" width="100%" alt="The island saying the Mac was locked from an iPhone, and that the iPhone checked its status">
</p>

Lock your Mac, or ask how it is doing, from your iPhone with a Shortcut. The request
travels over SSH, at home or anywhere through Tailscale, and the island tells you which
iPhone asked. Your iPhone can only lock the Mac or read its status; it can never unlock
it or run anything else.

<p align="center">
  <img src="docs/images/settings-remote.png" width="100%" alt="iPhone Remote settings: the checklist, devices and the values for the Shortcut">
</p>

Settings walks you through it: a checklist for Remote Login and Tailscale, the iPhones
you have added, and the values to type into the Shortcut.

## The menu bar panel

<table>
  <tr>
    <td width="25%" valign="top"><img src="docs/images/panel-keep-awake.jpg" width="100%" alt="The panel's Keep Awake section"></td>
    <td width="25%" valign="top"><img src="docs/images/panel-toggles.jpg" width="100%" alt="The panel's quick toggles"></td>
    <td width="25%" valign="top"><img src="docs/images/panel-wakatime.jpg" width="100%" alt="The panel's WakaTime section"></td>
    <td width="25%" valign="top"><img src="docs/images/panel-utilities.jpg" width="100%" alt="The panel's utilities"></td>
  </tr>
</table>

Click the star in the menu bar for the panel: Keep Awake, the volume mixer, CPU, memory,
network, disk, battery and fans, brightness, quick toggles, the wallpaper and every
utility, each section one click away. Choose and order the sections yourself.

## The toolkit

<p align="center">
  <img src="docs/images/settings-general.png" width="100%" alt="Zenith Settings, General page">
</p>

**Sound.** A per-app volume mixer with boost past 100%, per-app output, an output
switcher and microphone controls.

**Know what your Mac is doing.** System monitor for CPU, GPU, memory, temperatures and
battery, fan control, menu bar readouts, network and speed test, and alerts.

**Windows and the Dock.** An app and window switcher with live previews, window
layouts and snapping, Dock previews, Dock click actions, fixed Space order, workspaces,
and protection against accidental ⌘Q and ⌘W.

**Keyboard and mouse.** Text snippets, smooth and linear scrolling, pointer
acceleration control, side and extra mouse buttons, a super key, a radial menu, and
fixes for worn keyboards and mice.

**Clipboard, files and links.** Clipboard history, paste as plain text, a drag-and-drop
shelf, Finder cut and paste, clean URLs, QR codes and a disk image installer.

**Everyday tools.** A command bar, a quick panel, quick toggles, a scratchpad, a camera
preview and a cleaning mode that locks the keyboard.

**Capture and create.** Screenshots with annotation and scrolling capture, screen
recording with editing, text recognition, a color picker and local media tools.

**App management.** App updates, cleaner, uninstaller, Homebrew manager and a port
manager.

**Energy and display.** Keep awake, per-display brightness, extra XDR brightness and
Bluetooth handling on sleep.

<p align="center">
  <img src="docs/images/settings-monitor.png" width="100%" alt="Monitor settings: what the menu bar and the panel show">
</p>

## Download and install

<p>
  <a href="../../releases/latest"><img src="https://img.shields.io/badge/Download%20for%20Mac-0A0A0A?style=for-the-badge&logo=apple&logoColor=white" height="40" alt="Download for Mac"></a>
</p>

1. Download the latest disk image from [Releases](../../releases/latest).
2. Open it and drag **Zenith** into **Applications**.
3. Open Zenith from Applications. Its star appears in the menu bar.

**The first launch.** Zenith is not notarized by Apple yet, so macOS stops it the first
time with a message that it cannot check it for malicious software. To open it anyway:

- Open **System Settings → Privacy & Security**, scroll down to the message about
  Zenith and click **Open Anyway**, then confirm; or
- remove the quarantine flag in Terminal:

  ```sh
  xattr -dr com.apple.quarantine /Applications/Zenith.app
  ```

You only need to do this once.

**Requirements.** A Mac with Apple Silicon and macOS 14 Sonoma or newer. Face Unlock
needs macOS 15 Sequoia or newer. The Dynamic Island works on Macs with a notch and, as a
floating capsule, on displays without one.

## Build from source

You need a Mac with Apple Silicon, macOS 14 Sonoma or newer, and the Xcode Command
Line Tools. Xcode itself is not required.

```sh
git clone https://github.com/satuvisual/zenith.git
cd zenith
./build.sh --dev            # build the Developer variant
./build.sh --dev --install  # install "Zenith (Developer)" and open it
./build.sh                  # build the optimized app
```

The first `--dev` build creates a local signing identity in its own keychain so the
permissions you grant survive rebuilds. [CONTRIBUTING.md](CONTRIBUTING.md) has the
checks to run, and [docs/FORK.md](docs/FORK.md) explains how the project follows its
upstream.

## Permissions and privacy

Everything runs on your Mac. There is no account, no analytics and no tracking, and
Zenith does not send feedback, upload screenshots or check for updates. The network is
used only by things you start or connect yourself: the speed test, Homebrew actions,
lyric and cover lookups, the weather, and the services you sign in to (WakaTime, Vercel
and GitHub).

Each feature asks only for the macOS permissions it needs, when you first use it, and
explains why in plain words. Nothing is required to get started.

- [Privacy](docs/PRIVACY.md): what Zenith reads, where it stays and every network connection.
- [Permissions](docs/PERMISSIONS.md): each macOS permission and the features that use it.
- [Troubleshooting](docs/TROUBLESHOOTING.md): including how to reset permissions.

## Face Unlock security notice

> [!WARNING]
> **Face Unlock is not as secure as Touch ID or Face ID.** It is built for convenience,
> not for high-security sign-in.
>
> - It uses your Mac's ordinary camera. The liveness check stops photos and phone
>   screens, but **someone holding up a video of you may fool it**.
> - When it recognizes you, it **types your stored login password** into the lock
>   screen. Anyone it mistakes for you gets in.
> - Your password is sealed with AES-GCM in a file only your account can read. Its key
>   lives in your login keychain, and Zenith asks for Touch ID before it opens that key.
>   macOS itself does not enforce that Touch ID step; Zenith does.
>
> Face Unlock is opt-in and **off by default**. Don't turn it on for a Mac that holds
> anything you could not afford to lose, or where someone you don't trust has your
> photos or videos.

## Credits and license

Zenith stands on the work of others:

- **[Vorssaint Utils](https://github.com/vorssaint/vorssaint-utils)**, the free and
  open-source macOS menu bar toolkit Zenith is based on and follows (GPL-3.0). All of
  the core tools come from that project and its contributors. Thank you.
- **[Glance](https://github.com/jonnyoo/glance)** by Jonathan Zhou (MIT License), which
  Face Unlock is adapted from. Its notice is in the app's About page.
- **[Mechvibes](https://github.com/hainguyents13/mechvibes)** by Hải Nguyễn (MIT License),
  whose keyboard sound packs Mechakey plays. Its notice is in the app's About page.
- **[InsightFace](https://github.com/deepinsight/insightface)**, whose ArcFace model
  recognizes faces for Face Unlock. Its weights are licensed for non-commercial
  research use only.

<p align="center">
  <img src="docs/images/about-credits.png" width="560" alt="The credits in Zenith's About page">
</p>

Zenith is built by [Satu Visual](https://github.com/satuvisual), by Faiz
([Zazaaw](https://github.com/Zazaaw) on GitHub).

Zenith is free software under the [GNU General Public License v3.0 or later](LICENSE).
Zenith's changes are © 2026 Satu Visual; the original code is © 2026 Vorssaint and its
contributors, under the same license.

## Contributing

Bug reports and ideas are welcome in [Issues](../../issues). Before opening a pull
request, read [CONTRIBUTING.md](CONTRIBUTING.md) for the code conventions and the checks
each change needs. Security issues go through [SECURITY.md](SECURITY.md), and help is in
[SUPPORT.md](SUPPORT.md).

<p align="center">
  <sub>Made by <a href="https://github.com/satuvisual">Satu Visual</a></sub>
</p>
