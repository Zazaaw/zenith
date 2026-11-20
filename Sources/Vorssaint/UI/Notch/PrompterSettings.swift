// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AVFoundation
import SwiftUI

/// Zenith fork: the Prompter section's options in Settings → Dynamic Island →
/// Content: the scripts (new, import, from the Scratchpad, rename, delete,
/// and the text itself), the reading (speed, size, spacing, alignment, the
/// panel's size), mirror, the guide, the voice pace and the start/stop
/// shortcut. Switches are `ZenithSwitchRow`, so nothing here joins the
/// settings search index.
struct PrompterSettingsView: View {
    @ObservedObject private var service = PrompterService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchPrompterSpeed) private var speed = PrompterSettings.defaultSpeed
    @AppStorage(DefaultsKey.notchPrompterTextSize) private var textSize = PrompterSettings.defaultTextSize
    @AppStorage(DefaultsKey.notchPrompterLineSpacing) private var lineSpacing = PrompterSettings.defaultLineSpacing
    @AppStorage(DefaultsKey.notchPrompterAlignment) private var alignment = PrompterAlignment.center.rawValue
    @AppStorage(DefaultsKey.notchPrompterWidth) private var width = PrompterSettings.defaultWidth
    @AppStorage(DefaultsKey.notchPrompterHeight) private var height = PrompterSettings.defaultHeight
    @AppStorage(DefaultsKey.notchPrompterMirror) private var mirror = false
    @AppStorage(DefaultsKey.notchPrompterGuide) private var guide = true
    @AppStorage(DefaultsKey.notchPrompterVoicePaced) private var voicePaced = false
    @AppStorage(DefaultsKey.notchPrompterShortcut) private var shortcut = ""
    @State private var nameDraft = ""
    @State private var confirmingDelete: PrompterScript?
    @State private var shortcutMessage: String?
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    @FocusState private var nameFocused: Bool

    private var text: ZenithPrompterStrings { ZenithStrings.prompter(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            scriptsSection
            Divider().padding(.vertical, 2)
            readingSection
            Divider().padding(.vertical, 2)
            ZenithSwitchRow(text.mirrorTitle, isOn: $mirror) { label(text.mirrorTitle, caption: text.mirrorCaption) }
            ZenithSwitchRow(text.guideTitle, isOn: $guide) { label(text.guideTitle, caption: text.guideCaption) }
            ZenithSwitchRow(text.voiceTitle, isOn: voiceBinding) { label(text.voiceTitle, caption: text.voiceCaption) }
            if voicePaced, microphone == .denied || microphone == .restricted {
                HStack(spacing: 8) {
                    Image(systemName: "mic.slash").foregroundStyle(ZenithStatus.warning)
                    Text(text.micDenied).font(ZenithType.caption)
                    Spacer(minLength: 8)
                    Button(text.openSystemSettings) { Permissions.shared.openMicrophoneSettings() }
                }
            }
            Divider().padding(.vertical, 2)
            shortcutRow
        }
        .zenithSectionAnchor(.zenithPrompter) // Settings search lands here
        .onAppear {
            nameDraft = service.selectedScript?.name ?? ""
            microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        }
        .onChange(of: service.selectedID) { _, _ in nameDraft = service.selectedScript?.name ?? "" }
        .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
        .alert(String(format: text.deleteTitle, confirmingDelete?.name ?? ""),
               isPresented: Binding(get: { confirmingDelete != nil }, set: { if !$0 { confirmingDelete = nil } })) {
            Button(text.delete, role: .destructive) {
                if let script = confirmingDelete { service.delete(script.id) }
                confirmingDelete = nil
            }
            Button(text.cancel, role: .cancel) { confirmingDelete = nil }
        } message: {
            Text(text.deleteMessage)
        }
    }

    // MARK: Scripts

    private var scriptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(text.scripts).font(ZenithType.emphasis)
                Spacer(minLength: 8)
                Button(text.newScript) { service.createScript() }
                Button(text.importScript) { service.presentImport(from: NSApp.keyWindow) }
                if service.canUseScratchpad {
                    Button(text.fromScratchpad) { service.createFromScratchpad() }
                }
            }
            .controlSize(.small)
            if service.scripts.isEmpty {
                Text(text.noScripts).font(ZenithType.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(service.scripts) { script in row(script) }
                }
                .background(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous).fill(ZenithSurface.cardFill))
                .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous).strokeBorder(ZenithSurface.hairline))
                if let script = service.selectedScript { editor(script) }
            }
        }
    }

    private func row(_ script: PrompterScript) -> some View {
        let selected = script.id == service.selectedID
        return Button { service.select(script.id) } label: {
            HStack(spacing: 8) {
                Image(systemName: script.format == .markdown ? "doc.richtext" : "doc.plaintext")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(script.name).lineLimit(1)
                Spacer(minLength: 8)
                if selected {
                    Text("≈ \(PrompterFormat.clock(service.duration(of: service.draft, wpm: speed)))")
                        .font(ZenithType.mono(11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: ZenithRadius.medium, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.12) : .clear)
                .padding(2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func editor(_ script: PrompterScript) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(text.name, text: $nameDraft, prompt: Text(text.untitledScript))
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(commitName)
                Button(text.start) { service.startSession(script.id) }
                    .disabled(PrompterText.wordCount(service.draft) == 0)
                    .help(text.keysHint)
                Button(role: .destructive) { confirmingDelete = script } label: {
                    Image(systemName: "trash")
                }
                .help(text.delete)
                .accessibilityLabel(text.delete)
            }
            ZStack(alignment: .topLeading) {
                PlainTextEditor(text: Binding(get: { service.draft }, set: { service.setDraft($0) }), fontSize: 13,
                                textContainerInset: NSSize(width: 6, height: 6))
                    .id(script.id)
                if service.draft.isEmpty {
                    Text(text.placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6 + PlainTextEditor.lineFragmentPadding)
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 180)
            .background(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous).fill(ZenithSurface.cardFill))
            .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous).strokeBorder(ZenithSurface.hairline))
        }
    }

    private func commitName() {
        guard let script = service.selectedScript else { return }
        let cleaned = PrompterLibrary.cleanName(nameDraft, fallback: text.untitledScript)
        if cleaned != script.name { service.rename(script.id, to: cleaned) }
        nameDraft = cleaned
    }

    // MARK: Reading

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.reading).font(ZenithType.emphasis)
            slider(text.speed, value: intBinding($speed, PrompterSettings.clampedSpeed),
                   range: Double(PrompterSettings.speedRange.lowerBound)...Double(PrompterSettings.speedRange.upperBound),
                   step: Double(PrompterSettings.speedStep), reading: "\(PrompterSettings.clampedSpeed(speed)) \(text.wpm)")
            slider(text.textSize, value: intBinding($textSize, PrompterSettings.clampedTextSize),
                   range: Double(PrompterSettings.textSizeRange.lowerBound)...Double(PrompterSettings.textSizeRange.upperBound),
                   step: Double(PrompterSettings.textSizeStep), reading: "\(PrompterSettings.clampedTextSize(textSize)) pt")
            slider(text.lineSpacing, value: Binding(get: { PrompterSettings.clampedLineSpacing(lineSpacing) },
                                                    set: { lineSpacing = PrompterSettings.clampedLineSpacing($0) }),
                   range: PrompterSettings.lineSpacingRange, step: 0.05,
                   reading: String(format: "%.2f×", locale: MetricFormat.locale, PrompterSettings.clampedLineSpacing(lineSpacing)))
            HStack(spacing: 12) {
                Text(text.alignment)
                Spacer(minLength: 12)
                Picker(text.alignment, selection: $alignment) {
                    Text(text.centered).tag(PrompterAlignment.center.rawValue)
                    Text(text.left).tag(PrompterAlignment.leading.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            slider(text.width, value: intBinding($width) { PrompterSettings.clamped($0, to: PrompterSettings.widthRange) },
                   range: Double(PrompterSettings.widthRange.lowerBound)...Double(PrompterSettings.widthRange.upperBound),
                   step: 10, reading: "\(PrompterSettings.clamped(width, to: PrompterSettings.widthRange)) pt")
            slider(text.height, value: intBinding($height) { PrompterSettings.clamped($0, to: PrompterSettings.heightRange) },
                   range: Double(PrompterSettings.heightRange.lowerBound)...Double(PrompterSettings.heightRange.upperBound),
                   step: 10, reading: "\(PrompterSettings.clamped(height, to: PrompterSettings.heightRange)) pt")
            Text(text.sizeCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
                        reading: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Slider(value: value, in: range, step: step) { Text(title) }
                .labelsHidden()
                .frame(maxWidth: 200)
            Text(reading)
                .font(ZenithType.mono(11))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private func intBinding(_ stored: Binding<Int>, _ clamp: @escaping (Int) -> Int) -> Binding<Double> {
        Binding(get: { Double(clamp(stored.wrappedValue)) }, set: { stored.wrappedValue = clamp(Int($0.rounded())) })
    }

    // MARK: Voice and shortcut

    /// Turning it on asks for the microphone once, if it was never asked.
    private var voiceBinding: Binding<Bool> {
        Binding(get: { voicePaced }, set: { on in
            voicePaced = on
            guard on else { return }
            microphone = AVCaptureDevice.authorizationStatus(for: .audio)
            if microphone == .notDetermined {
                Permissions.shared.requestMicrophone { granted in
                    microphone = granted ? .authorized : .denied
                    if !granted { voicePaced = false }
                }
            }
        })
    }

    private var shortcutRow: some View {
        let s = l10n.s
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                label(text.shortcutTitle, caption: text.shortcutCaption)
                Spacer(minLength: 12)
                if service.shortcutRefused {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ZenithStatus.warning)
                        .help(s.shortcutNotCaptured)
                }
                ShortcutRecorderButton(
                    shortcut: GlobalShortcut(storageValue: shortcut) ?? .radialMenuDefault,
                    isEnabled: true,
                    waitingTitle: s.shortcutPressKeys,
                    emptyTitle: shortcut.isEmpty ? s.shortcutNone : nil,
                    clearAction: {
                        shortcutMessage = nil
                        shortcut = ""
                        service.syncShortcut()
                    },
                    notCapturedAction: { shortcutMessage = s.shortcutNotCaptured },
                    recordingChanged: { recording in if recording { shortcutMessage = nil } },
                    invalidAction: { shortcutMessage = s.shortcutInvalid },
                    captureAction: { captured in
                        if let owner = service.conflict(for: captured) {
                            shortcutMessage = s.shortcutConflictFormat.replacingOccurrences(of: "%@", with: owner)
                            return
                        }
                        shortcutMessage = nil
                        shortcut = captured.storageValue
                        service.syncShortcut()
                    }
                )
                .frame(width: 130)
            }
            if let shortcutMessage {
                Text(shortcutMessage)
                    .font(ZenithType.caption)
                    .foregroundStyle(ZenithStatus.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
