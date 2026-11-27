// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the words Zenith adds to the sound and capture pages, one page
// per tool (Settings → Volume Mixer, Sound Output, Music Blocker, Mic Mute,
// Screenshot, Screen Recording, Text Capture, Color Picker, Camera Preview):
// each hero's subtitle and chips, and the sections the pages group the
// existing, localized rows under. English in every language, like the kit's
// own words; the rows themselves keep their localized labels.

struct ZenithSoundCaptureStrings {
    // Volume Mixer.
    let mixerSubtitle = "A volume for every app, and the devices they play through."
    let mixerDevices = "Devices and apps"
    let mixerOptions = "Options"
    let mixerVisibleCaption = "Apps turned off here stay out of the mixer, in Settings and the menu bar panel."
    func apps(_ count: Int) -> String { count == 1 ? "1 app" : "\(count) apps" }

    // Sound Output.
    let outputSubtitle = "Switch between your speakers and headphones with one shortcut, and pick which device wins when several are plugged in."
    let outputSwitcher = "Switcher"
    let outputShortcut = "Switch shortcut"
    let outputPriorityTitle = "Priority"
    func devices(_ count: Int) -> String { count == 1 ? "1 device" : "\(count) devices" }

    // Music Blocker.
    let musicSubtitle = "Keeps Apple Music from opening on its own when headphones connect or a play key is pressed."
    let musicReplacement = "Instead"
    let musicNoReplacement = "No replacement"
    let musicClearReplacement = "Clear Replacement"

    // Mic Mute.
    let micSubtitle = "Mute every microphone at once, from a shortcut, the panel or the island."
    let micLive = "Live"
    let micMuted = "Muted"
    let micNow = "Right now"
    let micBehaviour = "Behaviour"
    let micShortcut = "Shortcut"
    let micStage = "While the microphone is muted, the island says so, whatever app you are in."

    // Screenshot.
    let screenshotSubtitle = "Capture an area, a window or the whole screen, mark it up and share it."
    let screenshotCapture = "Capture"
    let screenshotScrolling = "Scrolling screenshot"
    let screenshotShortcuts = "Shortcuts"
    let screenshotAfter = "After a capture"
    let screenshotSaving = "Saving"
    let screenshotLoupe = "Loupe"
    let screenshotStageScreenshot = "Screenshot"
    let screenshotStageScrolling = "Scrolling"

    // Screen Recording.
    let recordingSubtitle = "Record the screen with sound and zoom, then trim it, share it or save it as a GIF."
    let recordingRecord = "Recording"
    let recordingSaving = "Saving"
    let recordingIdle = "Ready"
    let recordingLive = "Recording"

    // Text Capture.
    let textSubtitle = "Copy the text in any part of the screen, and read QR codes, on this Mac."
    let textCapture = "Text"
    let textShortcut = "Shortcut"

    // Color Picker.
    let colorSubtitle = "Pick a colour from anywhere on the screen and copy it in the format you work in."
    let colorFormat = "Copy as"
    let colorPick = "Picking"

    // Camera Preview.
    let cameraSubtitle = "Check how you look before a call, in a round window that floats over everything."
    let cameraPreview = "Preview"
    let cameraStage = "A round window with your camera, over every app, until you close it."

    // Shared.
    let shortcutSet = "Shortcut set"
    let noShortcut = "No shortcut"
    let shortcutSection = "Shortcut"
    let sharing = "Sharing"
    let sharedLinks = "Shared links"

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func soundCapture(_ language: AppLanguage) -> ZenithSoundCaptureStrings {
        ZenithSoundCaptureStrings()
    }
}

/// Settings search: the new pages by the words their owner types, English and
/// Indonesian, which their localized labels do not use.
enum SoundCaptureSearch {
    static let volumeMixer = ["mixer", "volume mixer", "app volume", "per-app volume", "volume aplikasi",
                              "atur volume", "pengatur volume", "suara aplikasi"]
    static let soundOutput = ["sound output", "output", "speaker", "speakers", "headphones", "AirPods",
                              "audio device", "audio priority", "keluaran suara", "ganti speaker", "perangkat audio",
                              "prioritas audio", "headset"]
    static let musicBlocker = ["music blocker", "Apple Music", "Music app", "blokir musik", "musik kebuka sendiri",
                               "Music terbuka sendiri"]
    static let micMute = ["mic", "microphone", "mute", "bisukan", "bisukan mic", "matikan mic", "mikrofon"]
    static let screenshot = ["screenshot", "screen shot", "capture", "tangkapan layar", "ss", "scrolling screenshot",
                             "screenshot panjang", "tangkap layar"]
    static let screenRecording = ["screen recording", "record screen", "recorder", "rekam layar", "perekam layar",
                                  "rekaman layar", "GIF"]
    static let textCapture = ["OCR", "copy text", "text from screen", "salin teks", "teks dari layar", "QR"]
    static let colorPicker = ["color picker", "colour picker", "eyedropper", "hex", "pipet", "pemilih warna",
                              "ambil warna", "kode warna"]
    static let cameraPreview = ["camera", "webcam", "mirror", "kamera", "cermin", "cek kamera"]
}
