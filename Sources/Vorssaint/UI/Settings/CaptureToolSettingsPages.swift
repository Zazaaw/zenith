// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the smaller capture tools, a Settings page each (they were the
// tools of Screen capture and a section of Quick Tools): Text Capture, Color
// Picker and Camera Preview. Feature pages in the kit (docs/SETTINGS-KIT.md).
// Screenshot and Screen Recording have files of their own.

// MARK: - A capture tool's shortcut

/// The shortcut that opens the capture chooser straight on one tool, and
/// whether it opens the chooser's menu with it.
struct CaptureToolShortcutRows: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ScreenCaptureService.shared
    @AppStorage private var enabled: Bool
    @AppStorage private var showsCaptureMenu: Bool

    private let tool: ScreenCaptureTool
    private let keys: ScreenCaptureTool.DedicatedShortcut

    init(tool: ScreenCaptureTool) {
        self.tool = tool
        keys = tool.dedicatedShortcut
        _enabled = AppStorage(wrappedValue: false, keys.enabledKey)
        _showsCaptureMenu = AppStorage(wrappedValue: true, tool.showCaptureMenuOnShortcutKey)
    }

    var body: some View {
        ZenithRowStack {
            ZenithShortcutSwitchRows(title: keys.role.title(l10n.s), role: keys.role, isOn: $enabled,
                                     failed: service.toolShortcutRegistrationFailures.contains(tool)) {
                service.syncWithPreferences()
            }
            ZenithRow(FeatureStrings.screenshot(l10n.language).showCaptureMenuOnShortcut, isOn: $showsCaptureMenu)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.55)
        }
        .zenithFullBleed()
    }

    /// The hero's chip for this tool's shortcut.
    static func chip(_ tool: ScreenCaptureTool) -> ZenithChip {
        let keys = tool.dedicatedShortcut
        return ZenithShortcutChip.chip(keys.role, enabled: UserDefaults.standard.bool(forKey: keys.enabledKey))
    }
}

/// Screen Recording permission, while it is missing.
struct CapturePermissionSection: View {
    let kind: PermissionKind
    @ObservedObject private var permissions = Permissions.shared

    var body: some View {
        if !granted {
            ZenithSection { PermissionRow(kind: kind).padding(.vertical, 10) }
        }
    }

    private var granted: Bool {
        switch kind {
        case .accessibility: return permissions.accessibility
        case .screenRecording: return permissions.screenRecording
        case .microphone: return permissions.microphone == .granted
        }
    }
}

// MARK: - Text Capture

struct TextCaptureSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.screenOCRRemoveLineBreaks) private var removesLineBreaks = false
    @AppStorage(DefaultsKey.screenOCRDetectQRCodes) private var detectsQRCodes = true

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        ZenithToolPage {
            ZenithHero(title: s.ocrName, subtitle: text.textSubtitle,
                       chips: [CaptureToolShortcutRows.chip(.text)], animation: .textCapture)
                .zenithSectionAnchor(.screenOCR, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            CapturePermissionSection(kind: .screenRecording)
            ZenithScenePreview(scenes: [.screenText])
            ZenithSection(text.textCapture) {
                ZenithRow(text.tryNow, info: s.ocrCaption, button: s.ocrName) { ScreenTextService.shared.capture() }
                ZenithRow(s.ocrRemoveLineBreaksToggle, isOn: $removesLineBreaks, info: s.ocrRemoveLineBreaksCaption)
                ZenithRow(s.ocrQRToggle, isOn: $detectsQRCodes, info: s.ocrQRCaption)
            }
            ZenithSection(text.textShortcut) {
                CaptureToolShortcutRows(tool: .text)
            }
        }
    }
}

// MARK: - Color Picker

struct ColorPickerSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.colorPickerFormat) private var format = "hex"
    @AppStorage(DefaultsKey.colorPickerBareHex) private var usesBareHex = false

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        let current = ColorCopyFormat.sanitized(format)
        ZenithToolPage {
            ZenithHero(title: s.colorPickerName, subtitle: text.colorSubtitle,
                       chips: [ZenithChip(current.label), CaptureToolShortcutRows.chip(.color)],
                       animation: .colorPicker)
                .zenithSectionAnchor(.colorPicker, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            ZenithScenePreview(scenes: [.color])
            VStack(alignment: .leading, spacing: 10) {
                ZenithSectionTitle(s.colorPickerFormatLabel)
                ZenithVisualPicker(s.colorPickerFormatLabel, selection: Binding(get: { current.rawValue },
                                                                                 set: { format = $0 }),
                                   options: ColorCopyFormat.allCases.map {
                                       ZenithPickerOption($0.rawValue, $0.label, detail: Self.sample($0, bareHex: usesBareHex))
                                   }, minimumTileWidth: 120) { raw, _ in
                    ColorFormatTileArt(sample: Self.sample(ColorCopyFormat.sanitized(raw), bareHex: usesBareHex))
                }
            }
            ZenithSection(text.colorPick) {
                ZenithRow(text.tryNow, info: s.colorPickerCaption, button: s.colorPickerPickNow) {
                    ColorSamplerService.shared.pick()
                }
                if current == .hex {
                    ZenithRow(s.colorPickerBareHexToggle, isOn: $usesBareHex)
                }
            }
            ZenithSection(text.shortcutSection) {
                CaptureToolShortcutRows(tool: .color)
            }
        }
    }

    /// A colour in `format`, as the picker would copy it.
    static func sample(_ format: ColorCopyFormat, bareHex: Bool) -> String {
        ColorValue.string(red: 0.2, green: 0.55, blue: 1, format: format, bareHex: bareHex)
    }
}

/// A format's tile: a swatch and the colour as it would be copied.
private struct ColorFormatTileArt: View {
    let sample: String

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.2, green: 0.55, blue: 1))
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(0.7)))
            Text(verbatim: sample)
                .font(ZenithType.mono(9.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 8)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - Camera Preview

struct CameraPreviewSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var cameraPreview = CameraPreviewService.shared
    @AppStorage(DefaultsKey.cameraPreviewShortcutEnabled) private var shortcutEnabled = false

    private let text = ZenithStrings.soundCapture(.enUS)

    var body: some View {
        let s = l10n.s
        let strings = FeatureStrings.cameraPreview(l10n.language)
        ZenithToolPage {
            ZenithHero(title: strings.pageTitle, subtitle: text.cameraSubtitle,
                       chips: [ZenithShortcutChip.chip(.cameraPreview, enabled: shortcutEnabled)],
                       animation: .cameraPreview)
                .zenithSectionAnchor(.cameraPreview, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            // The camera can't be asked again once refused: straight to System Settings.
            if permissions.camera == .denied {
                ZenithCallout(.warning, title: strings.permName, s.permissionMissing) {
                    Button(s.permissionOpenSettings) { Permissions.shared.openCameraSettings() }
                }
            }
            ZenithSettingsPreviewCard(id: "cameraPreview", caption: text.cameraStage) {
                QuickToolsPreviewPicture(group: .windows, shown: .cameraPreview, available: [.cameraPreview],
                                         open: { _ in })
            }
            ZenithSection(text.cameraPreview) {
                ZenithRow(text.tryNow, info: strings.panelCaption, button: strings.openButton) {
                    CameraPreviewService.shared.show()
                }
            }
            ZenithSection(text.shortcutSection) {
                ZenithShortcutSwitchRows(title: s.quickToolShortcutToggle, role: .cameraPreview, isOn: $shortcutEnabled,
                                         failed: cameraPreview.shortcutRegistrationFailed) {
                    CameraPreviewService.shared.syncWithPreferences()
                }
            }
        }
    }
}
