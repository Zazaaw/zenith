// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct KeyboardDebounceSettings: View {
    private struct KeyWindowRow: Identifiable {
        let keyCode: Int64
        let window: Int
        var id: Int64 { keyCode }
    }

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var debounce = KeyboardDebounceService.shared
    @AppStorage(DefaultsKey.keyboardDebounceEnabled) private var enabled = false
    @AppStorage(DefaultsKey.keyboardDebounceWindowMs) private var globalWindow = Defaults.defaultKeyboardDebounceWindowMs
    @AppStorage(DefaultsKey.keyboardDebounceKeyWindows) private var keyWindowsRaw = ""
    @State private var selectedKeyCode: Int64?
    @State private var selectedWindow = Defaults.defaultKeyboardDebounceWindowMs

    private var text: ZenithInputWindowsStrings { ZenithStrings.inputWindows(l10n.language) }

    // Zenith fork: a kit feature page: the hero with the master switch, the
    // preview, the window for every key, then the keys with windows of their own.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: l10n.s.keyDebounceName, subtitle: text.keyDebounceSubtitle, chips: chips,
                           isOn: enabledBinding, switchLabel: l10n.s.keyDebounceEnable, switchHint: l10n.s.keyDebounceCaption,
                           animation: .keyDebounce)
                if enabled, !permissions.accessibility {
                    InputWindowsPermissionSection()
                }
                ZenithKeyDebouncePreviewCard()
                ZenithSection {
                    ZenithRow(l10n.s.keyDebounceGlobalWindow, value: globalWindowBinding,
                              in: Defaults.allowedKeyboardDebounceWindowRange,
                              step: Defaults.keyboardDebounceWindowStep,
                              info: l10n.s.keyDebounceCaption, format: { "\($0) ms" })
                        .disabled(!enabled)
                        .zenithPreviewTarget("keyDebounce.window")
                }
                perKey
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .zenithPreviewJumps()
        .onAppear {
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
            selectedWindow = Defaults.sanitizedKeyboardDebounceWindow(selectedWindow)
        }
    }

    private var chips: [ZenithChip] {
        var chips = [ZenithChip("\(Defaults.sanitizedKeyboardDebounceWindow(globalWindow)) ms"),
                     ZenithChip(text.count(keyWindows.count, "key", "keys"))]
        if enabled, debounce.isRunning { chips.append(ZenithChip(text.activeNow, dot: ZenithStatus.success)) }
        return chips
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { value in
            enabled = value
            KeyboardDebounceService.shared.syncWithPreferences()
            guard value, !permissions.accessibility else { return }
            permissions.requestAccessibility()
            permissions.openAccessibilitySettings()
        })
    }

    private var perKey: some View {
        ZenithSection(l10n.s.keyDebouncePerKeySection) {
            ZenithRow(l10n.s.keyDebounceKeyLabel, info: l10n.s.keyDebouncePerKeyCaption) {
                HStack(spacing: 8) {
                    Picker(l10n.s.keyDebounceKeyLabel, selection: $selectedKeyCode) {
                        Text(l10n.s.keyDebounceKeyLabel).tag(Int64?.none)
                        ForEach(KeyboardDebounceKeyCatalog.common) { key in
                            Text(key.label).tag(Optional(key.code))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    ZenithRowStepper(title: l10n.s.keyDebounceKeyLabel, value: $selectedWindow,
                                     range: Defaults.allowedKeyboardDebounceWindowRange,
                                     step: Defaults.keyboardDebounceWindowStep, format: { "\($0) ms" })
                    Button(l10n.s.keyDebounceAddKey) {
                        if let selectedKeyCode { setWindow(selectedWindow, for: selectedKeyCode) }
                    }
                    .disabled(selectedKeyCode == nil)
                }
            }
            if keyWindows.isEmpty {
                Text(l10n.s.keyDebounceNoOverrides)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                ForEach(keyWindows) { row in
                    ZenithRow(KeyboardDebounceKeyCatalog.label(for: row.keyCode)) {
                        HStack(spacing: 8) {
                            ZenithRowStepper(title: KeyboardDebounceKeyCatalog.label(for: row.keyCode),
                                             value: binding(for: row.keyCode),
                                             range: Defaults.allowedKeyboardDebounceWindowRange,
                                             step: Defaults.keyboardDebounceWindowStep, format: { "\($0) ms" })
                            Button {
                                removeWindow(for: row.keyCode)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help(l10n.s.keyDebounceRemoveKey)
                            .accessibilityLabel(l10n.s.keyDebounceRemoveKey)
                        }
                    }
                }
            }
        }
        .disabled(!enabled)
    }

    private var globalWindowBinding: Binding<Int> {
        Binding {
            Defaults.sanitizedKeyboardDebounceWindow(globalWindow)
        } set: { value in
            globalWindow = Defaults.sanitizedKeyboardDebounceWindow(value)
            KeyboardDebounceService.shared.syncWithPreferences()
        }
    }

    private var keyWindows: [KeyWindowRow] {
        KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
            .map { KeyWindowRow(keyCode: $0.key, window: $0.value) }
            .sorted {
                KeyboardDebounceKeyCatalog.label(for: $0.keyCode) < KeyboardDebounceKeyCatalog.label(for: $1.keyCode)
            }
    }

    private func binding(for keyCode: Int64) -> Binding<Int> {
        Binding {
            KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)[keyCode]
                ?? Defaults.defaultKeyboardDebounceWindowMs
        } set: { value in
            setWindow(value, for: keyCode)
        }
    }

    private func setWindow(_ value: Int, for keyCode: Int64) {
        var windows = KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
        windows[keyCode] = Defaults.sanitizedKeyboardDebounceWindow(value)
        keyWindowsRaw = KeyboardDebounceConfig.encodeKeyWindows(windows)
        KeyboardDebounceService.shared.syncWithPreferences()
    }

    private func removeWindow(for keyCode: Int64) {
        var windows = KeyboardDebounceConfig.decodeKeyWindows(keyWindowsRaw)
        windows.removeValue(forKey: keyCode)
        keyWindowsRaw = KeyboardDebounceConfig.encodeKeyWindows(windows)
        KeyboardDebounceService.shared.syncWithPreferences()
    }
}
