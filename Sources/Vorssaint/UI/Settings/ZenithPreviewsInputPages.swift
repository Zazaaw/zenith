// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the preview cards of the keyboard, files and clipboard pages,
// each a looping picture of what the feature does, drawn from sample content
// and this Mac's own choices (keys, modes, windows). An outlined part opens
// its setting: a section anchor through the router where the page has one,
// else a jump to the setting on the page (`zenithPreviewJumps`).

private var inputText: ZenithPreviewsInputStrings { .shared }

private func plus(_ x: CGFloat, _ y: CGFloat) -> some View {
    Text("+").font(.system(size: 16, weight: .medium)).foregroundStyle(.tertiary).position(x: x, y: y)
}

private func arrow(_ x: CGFloat, _ y: CGFloat = 88) -> some View {
    Image(systemName: "arrow.right")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.tertiary)
        .position(x: x, y: y)
}

/// A text field with its caret.
private struct ZPIField: View {
    let content: Text
    var width: CGFloat = 300
    var lit = false
    var caret = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(spacing: 1) {
            content.font(.system(size: 13)).lineLimit(1).fixedSize()
            Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 15).opacity(caret ? 1 : 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: 36)
        .background(shape.fill(ZPI.surface))
        .overlay(shape.strokeBorder(lit ? Color.accentColor.opacity(0.7) : ZPI.stroke, lineWidth: lit ? 1.5 : 1))
    }
}

// MARK: - Key debounce

struct ZenithKeyDebouncePreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.keyboardDebounceWindowMs) private var window = Defaults.defaultKeyboardDebounceWindowMs
    @Environment(\.zenithPreviewJump) private var jump
    @State private var state = 1

    var body: some View {
        let filtered = state == 1
        ZenithSettingsPreviewCard(id: "keyDebounce", caption: filtered ? inputText.debounceKeyCaption : inputText.debounceOffCaption,
                                  states: [inputText.without, inputText.with], selection: $state,
                                  highlight: l10n.s.keyDebounceGlobalWindow) {
            ZPIStage(period: 3.2, still: 0.7) { phase in picture(phase, filtered: filtered) }
        }
    }

    private func picture(_ phase: Double, filtered: Bool) -> some View {
        let press = ZPI.pulse(phase, 0.2, 0.3, fade: 0.02)
        let bounce = ZPI.pulse(phase, 0.33, 0.38, fade: 0.015)
        let landed = phase >= 0.25
        let bounced = phase >= 0.36
        let caret = Int(phase * 10) % 2 == 0
        return ZStack {
            ZPIKey(label: "A", lit: press + bounce > 0.4, depth: max(press, bounce), width: 46, height: 46, fontSize: 16)
                .position(x: 62, y: 74)
            ZPILabel(inputText.key).position(x: 62, y: 116)
            timeline(phase, filtered: filtered)
                .zenithPreviewPart(cornerRadius: 8, highlighted: true) { jump("keyDebounce.window") }
                .position(x: 196, y: 74)
            ZPIField(content: Text("Th") + Text(landed ? "a" : "")
                        + Text(bounced ? "a" : "").foregroundColor(filtered ? .secondary : .primary).strikethrough(filtered),
                     width: 110, caret: caret)
                .position(x: 362, y: 74)
            ZPILabel(inputText.typed).position(x: 362, y: 116)
            ZPIChip(text: filtered ? inputText.oneLetter : inputText.twoLetters, symbol: filtered ? "checkmark" : "exclamationmark.triangle",
                    lit: filtered)
                .opacity(bounced ? 1 : 0.35)
                .position(x: 220, y: 162)
        }
    }

    /// The key's signal: the press, then a bounce inside the window.
    private func timeline(_ phase: Double, filtered: Bool) -> some View {
        let sweep = ZPI.span(phase, 0.1, 0.6)
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.accentColor.opacity(filtered ? 0.14 : 0.05))
                .frame(width: 44, height: 58)
                .offset(x: 50, y: 4)
            Text("\(window) ms").font(ZenithType.mono(9.5, weight: .medium))
                .foregroundStyle(filtered ? Color.accentColor : Color.secondary)
                .fixedSize()
                .offset(x: 52, y: 68)
            Rectangle().fill(ZPI.stroke).frame(width: 140, height: 1.5).offset(y: 62)
            Capsule().fill(Color.accentColor).frame(width: 4, height: 30).offset(x: 48, y: 32)
                .opacity(sweep >= 0.33 ? 1 : 0.2)
            Capsule().fill(filtered ? Color.primary.opacity(0.35) : Color.accentColor).frame(width: 4, height: 20)
                .offset(x: 74, y: 42)
                .opacity(sweep >= 0.52 ? 1 : 0.2)
            Rectangle().fill(Color.primary.opacity(0.3)).frame(width: 1, height: 66).offset(x: 140 * sweep)
        }
        .frame(width: 140, height: 82, alignment: .topLeading)
    }
}

// MARK: - Super key

struct ZenithSuperKeyPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.superKeySource) private var sourceRaw = SuperKeySource.capsLock.rawValue
    @AppStorage(DefaultsKey.superKeyModifiers) private var modifierStorage = SuperKeySupport.defaultModifierStorageValue
    @AppStorage(DefaultsKey.superKeySoloAction) private var soloRaw = SuperKeySoloAction.none.rawValue
    @Environment(\.zenithPreviewJump) private var jump
    @State private var state = 0

    var body: some View {
        let text = FeatureStrings.superKey(l10n.language)
        ZenithSettingsPreviewCard(id: "superKey", caption: state == 0 ? inputText.superHoldCaption : inputText.superTapCaption,
                                  states: [inputText.hold, inputText.tapAlone], selection: $state,
                                  highlight: state == 0 ? text.sourceKey : text.soloSection) {
            ZPIStage(period: 3.2, still: state == 0 ? 0.7 : 0.5) { phase in
                if state == 0 { hold(phase) } else { tap(phase) }
            }
        }
    }

    private var sourceLabel: String {
        FeatureStrings.superKey(l10n.language).sourceLabel(SuperKeySource.sanitized(sourceRaw))
    }

    private func sourceKey(depth: Double, highlighted: Bool) -> some View {
        ZPIKey(label: sourceLabel, lit: depth > 0.4, depth: depth, width: 96, height: 38, fontSize: 11)
            .zenithPreviewPart(cornerRadius: 9, highlighted: highlighted) { jump("superKey.main") }
    }

    private func hold(_ phase: Double) -> some View {
        let held = ZPI.pulse(phase, 0.12, 0.88)
        let caps = SuperKeySupport.modifiers(from: modifierStorage).keyCaps
        let fired = ZPI.pulse(phase, 0.5, 0.82)
        return ZStack {
            sourceKey(depth: held, highlighted: true).position(x: 82, y: 76)
            ZPILabel(inputText.holdKey, lit: held > 0.5).position(x: 82, y: 118)
            arrow(160, 76)
            HStack(spacing: 5) {
                ForEach(Array(caps.enumerated()), id: \.offset) { index, cap in
                    ZPIKey(label: cap, lit: phase > 0.18 + Double(index) * 0.06 && held > 0.5)
                }
            }
            .position(x: 258, y: 76)
            ZPILabel(inputText.standsFor).position(x: 258, y: 118)
            plus(350, 76)
            ZPIKey(label: "T", lit: fired > 0.5, depth: fired).position(x: 384, y: 76)
            ZPIChip(text: (caps + ["T"]).joined(), symbol: "bolt.fill", lit: fired > 0.5)
                .opacity(0.35 + 0.65 * fired)
                .position(x: 258, y: 162)
        }
    }

    private func tap(_ phase: Double) -> some View {
        let press = ZPI.pulse(phase, 0.22, 0.34, fade: 0.03)
        let shown = ZPI.pulse(phase, 0.34, 0.85)
        let action = SuperKeySoloAction.sanitized(soloRaw)
        return ZStack {
            sourceKey(depth: press, highlighted: false).position(x: 110, y: 82)
            ZPILabel(inputText.tapAlone, lit: press > 0.5).position(x: 110, y: 124)
            arrow(212, 82)
            ZPIChip(text: soloTitle(action), symbol: soloSymbol(action), lit: action != .none && shown > 0.5)
                .opacity(0.35 + 0.65 * shown)
                .zenithPreviewPart(cornerRadius: 14, highlighted: true) { jump("superKey.solo") }
                .position(x: 316, y: 82)
        }
    }

    private func soloTitle(_ action: SuperKeySoloAction) -> String {
        switch action {
        case .none: return inputText.soloNothing
        case .capsLock: return inputText.soloCapsLock
        case .inputSource: return inputText.soloInputSource
        case .escape: return inputText.soloEscape
        }
    }

    private func soloSymbol(_ action: SuperKeySoloAction) -> String {
        switch action {
        case .none: return "minus"
        case .capsLock: return "capslock"
        case .inputSource: return "globe"
        case .escape: return "escape"
        }
    }
}

// MARK: - Cut & paste, rename

struct ZenithCutPastePreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @AppStorage(DefaultsKey.finderRenameShortcut) private var renameRaw = GlobalShortcut.finderRenameDefault.storageValue
    @State private var picked: Int?

    private var states: [SettingsSectionAnchor] {
        [(AppFeature.finderCutPaste, SettingsSectionAnchor.finderCutPaste), (.finderRename, .finderRename)]
            .filter { $0.0.isAvailable }.map { $0.1 }
    }

    private var routed: Int? {
        guard router.page == .finderTools, let anchor = router.destination.sectionAnchor else { return nil }
        return states.firstIndex(of: anchor)
    }

    var body: some View {
        let states = self.states
        let index = min(picked ?? routed ?? 0, max(0, states.count - 1))
        let section = states.isEmpty ? .finderCutPaste : states[index]
        ZenithSettingsPreviewCard(id: "cutPaste", caption: section == .finderRename ? inputText.renameCaption : inputText.cutPasteCaption,
                                  states: states.map { $0 == .finderRename ? inputText.rename : inputText.cutPaste },
                                  selection: Binding(get: { index }, set: { picked = $0 }),
                                  highlight: section == .finderRename ? FeatureStrings.finderRename(l10n.language).hubTitle
                                                                      : inputText.cutPaste) {
            ZPIStage(period: 3.6, still: 0.6) { phase in
                if section == .finderRename { rename(phase) } else { cutPaste(phase) }
            }
        }
        .onChange(of: router.requestID) { _, _ in picked = nil }
    }

    private func open(_ anchor: SettingsSectionAnchor) {
        picked = nil
        router.request(FeatureSettingsDestination(.finderTools, sectionAnchor: anchor))
    }

    private func cutPaste(_ phase: Double) -> some View {
        let cut = ZPI.pulse(phase, 0.15, 0.3)
        let paste = ZPI.pulse(phase, 0.48, 0.62)
        let move = ZPI.ease(phase, 0.52, 0.7)
        let reset = ZPI.span(phase, 0.92, 1)
        return ZStack {
            ZPIWindow(width: 160, height: 120, title: inputText.desktop) { EmptyView() }
                .position(x: 118, y: 80)
            ZPIWindow(width: 160, height: 120, title: inputText.documents) { EmptyView() }
                .position(x: 322, y: 80)
            ZPIFile(name: inputText.sampleFile, symbol: "doc.richtext.fill", selected: move < 0.5,
                    dimmed: phase > 0.22 && move < 1)
                .position(x: 118 + 204 * move, y: 92)
                .opacity(1 - reset)
            HStack(spacing: 22) {
                ZPIChord(caps: ["⌘", "X"], lit: cut > 0.5, depth: cut)
                ZPIChord(caps: ["⌘", "V"], lit: paste > 0.5, depth: paste)
            }
            .zenithPreviewPart(cornerRadius: 10, highlighted: true) { open(.finderCutPaste) }
            .position(x: 220, y: 170)
        }
    }

    private func rename(_ phase: Double) -> some View {
        let shortcut = GlobalShortcut(storageValue: renameRaw, requiringModifier: false) ?? .finderRenameDefault
        let press = ZPI.pulse(phase, 0.15, 0.28)
        let editing = phase > 0.25 && phase < 0.85
        let typed = ZPI.span(phase, 0.38, 0.7)
        let name = phase < 0.33 ? inputText.sampleImage
            : String(inputText.renamedImage.prefix(Int((Double(inputText.renamedImage.count) * typed).rounded())))
        return ZStack {
            ZPIWindow(width: 300, height: 120, title: inputText.desktop) {
                HStack(spacing: 34) {
                    ZPIFile(name: inputText.sampleFile, symbol: "doc.richtext.fill")
                    VStack(spacing: 3) {
                        Image(systemName: "photo.fill").font(.system(size: 26)).foregroundStyle(Color.primary.opacity(0.55))
                        Text(name.isEmpty && editing ? " " : (phase >= 0.85 ? inputText.renamedImage : name))
                            .font(.system(size: 9.5, weight: .medium))
                            .fixedSize()
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3).fill(editing ? ZPI.surface : Color.accentColor))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.accentColor, lineWidth: editing ? 1.5 : 0))
                            .foregroundStyle(editing ? Color.primary : Color.white)
                    }
                    ZPIFile(name: inputText.documents, symbol: "folder.fill")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .position(x: 220, y: 80)
            ZPIChord(caps: shortcut.keyCaps, lit: press > 0.5, depth: press)
                .zenithPreviewPart(cornerRadius: 10, highlighted: true) { open(.finderRename) }
                .position(x: 220, y: 170)
        }
    }
}

// MARK: - Auto quit

struct ZenithAutoQuitPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.zenithPreviewJump) private var jump

    var body: some View {
        ZenithSettingsPreviewCard(id: "autoQuit", caption: inputText.autoQuitCaption,
                                  highlight: l10n.s.autoQuitEnable) {
            ZPIStage(period: 3.6, still: 0.3) { phase in picture(phase) }
        }
    }

    private func picture(_ phase: Double) -> some View {
        let travel = ZPI.ease(phase, 0.08, 0.28)
        let click = ZPI.pulse(phase, 0.28, 0.36, fade: 0.02)
        let close = ZPI.ease(phase, 0.34, 0.46)
        let quit = ZPI.ease(phase, 0.5, 0.62)
        let back = ZPI.ease(phase, 0.9, 1)
        let gone = close * (1 - back)
        let dot = 1 - quit * (1 - back)
        return ZStack {
            ZPIWindow(width: 210, height: 110, title: "Photos") {
                Image(systemName: "photo").font(.system(size: 34, weight: .light)).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .scaleEffect(1 - 0.15 * gone)
            .opacity(1 - gone)
            .position(x: 220, y: 68)
            ZPIPointer(pressed: click > 0.5)
                .position(x: 160 - 26 * travel + 2, y: 40 - 12 * travel + 12)
                .opacity(1 - gone)
            ZPILabel(inputText.closeLastWindow, lit: close > 0.5).opacity(close > 0.5 ? 1 - back : 0)
                .position(x: 220, y: 68)
            dock(dot: dot, quit: quit * (1 - back))
                .zenithPreviewPart(cornerRadius: 14, highlighted: true) { jump("autoQuit.main") }
                .position(x: 220, y: 158)
        }
    }

    private func dock(dot: Double, quit: Double) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(["folder.fill", "safari.fill", "photo.fill", "music.note"].enumerated()), id: \.offset) { index, symbol in
                VStack(spacing: 3) {
                    ZPIAppIcon(symbol: symbol, tint: index == 2 ? .accentColor : Color(white: 0.5), size: 30)
                    Circle().fill(Color.primary.opacity(0.6)).frame(width: 4, height: 4)
                        .opacity(index == 2 ? dot : (index == 0 ? 1 : 0))
                }
                .overlay(alignment: .top) {
                    if index == 2 {
                        ZPIChip(text: inputText.appQuits, symbol: "power").opacity(quit).offset(y: -34).fixedSize()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ZPI.raised.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ZPI.stroke))
    }
}

// MARK: - Quit protection

struct ZenithQuitProtectionPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.quitProtectionQuitMode) private var quitMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseMode) private var closeMode = QuitProtectionMode.hold.rawValue
    @AppStorage(DefaultsKey.quitProtectionQuitExtraModifier) private var quitExtra = QuitProtectionExtraModifier.shift.rawValue
    @AppStorage(DefaultsKey.quitProtectionCloseExtraModifier) private var closeExtra = QuitProtectionExtraModifier.shift.rawValue
    @Environment(\.zenithPreviewJump) private var jump
    @State private var state = 0

    private var shortcut: QuitProtectionShortcut { state == 0 ? .quit : .close }

    var body: some View {
        let mode = QuitProtectionSupport.modeFor(shortcut == .quit ? quitMode : closeMode)
        let strings = FeatureStrings.quitProtection(l10n.language)
        let modeName: String = switch mode {
        case .hold: strings.hold
        case .doublePress: strings.doublePress
        case .extraModifier: strings.extraModifier
        }
        ZenithSettingsPreviewCard(id: "quitProtection", caption: caption(mode),
                                  states: QuitProtectionShortcut.allCases.map(\.symbol), selection: $state,
                                  highlight: "\(shortcut.symbol) · \(modeName)") {
            ZPIStage(period: 3.4, still: still(mode)) { phase in picture(phase, mode: mode) }
        }
    }

    /// The moment the picture stands on with Reduce Motion on.
    private func still(_ mode: QuitProtectionMode) -> Double {
        switch mode {
        case .hold: return 0.5
        case .doublePress: return 0.35
        case .extraModifier: return 0.3
        }
    }

    private func caption(_ mode: QuitProtectionMode) -> String {
        switch mode {
        case .hold: return inputText.quitHoldCaption
        case .doublePress: return inputText.quitDoubleCaption
        case .extraModifier: return inputText.quitExtraCaption
        }
    }

    private var extraCap: String {
        let raw = shortcut == .quit ? quitExtra : closeExtra
        switch QuitProtectionSupport.extraModifierFor(raw) {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

    private func picture(_ phase: Double, mode: QuitProtectionMode) -> some View {
        let letter = shortcut == .quit ? "Q" : "W"
        let (depth, ring, done, hint, extra): (Double, Double, Double, String?, Bool) = {
            switch mode {
            case .hold:
                return (ZPI.pulse(phase, 0.12, 0.7), ZPI.span(phase, 0.14, 0.62), ZPI.ease(phase, 0.64, 0.74),
                        inputText.holdToQuit, false)
            case .doublePress:
                let first = ZPI.pulse(phase, 0.15, 0.25, fade: 0.02)
                let second = ZPI.pulse(phase, 0.45, 0.55, fade: 0.02)
                return (max(first, second), phase > 0.2 ? (phase > 0.5 ? 1 : 0.5) : 0, ZPI.ease(phase, 0.55, 0.66),
                        phase > 0.2 && phase < 0.55 ? inputText.pressTwice : nil, false)
            case .extraModifier:
                let plain = ZPI.pulse(phase, 0.12, 0.24, fade: 0.02)
                let full = ZPI.pulse(phase, 0.42, 0.56, fade: 0.02)
                return (max(plain, full), 0, ZPI.ease(phase, 0.56, 0.66),
                        phase > 0.14 && phase < 0.42 ? inputText.extraKey : nil, phase > 0.38)
            }
        }()
        let back = ZPI.ease(phase, 0.9, 1)
        let gone = done * (1 - back)
        let caps = (extra ? [extraCap] : []) + ["⌘", letter]
        return ZStack {
            ZStack {
                if mode != .extraModifier {
                    Circle().stroke(ZPI.line, lineWidth: 4).frame(width: 118, height: 118)
                    Circle().trim(from: 0, to: ring * (1 - back))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 118, height: 118)
                }
                ZPIChord(caps: caps, lit: depth > 0.4, depth: depth)
            }
            .zenithPreviewPart(cornerRadius: 60, highlighted: true) { jump(shortcut == .quit ? "quitProtection.quit" : "quitProtection.close") }
            .position(x: 120, y: 88)
            if let hint {
                ZPIChip(text: hint, symbol: "hand.raised.fill").position(x: 120, y: 172)
            }
            arrow(222)
            ZPIWindow(width: 160, height: 116, title: "TextEdit") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule().fill(ZPI.line).frame(width: [120, 90, 110, 70][index], height: 5)
                    }
                }
                .padding(12)
            }
            .scaleEffect(1 - 0.12 * gone)
            .opacity(1 - gone)
            .position(x: 330, y: 80)
            ZPILabel(shortcut == .quit ? inputText.quitApp : inputText.closeWindow, lit: done > 0.5)
                .position(x: 330, y: 162)
        }
    }
}

// MARK: - URL cleaner

struct ZenithURLCleanerPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.zenithPreviewJump) private var jump

    var body: some View {
        ZenithSettingsPreviewCard(id: "urlCleaner", caption: inputText.urlCaption, highlight: l10n.s.urlCleanerRulesTitle) {
            ZPIStage(period: 3.6, still: 0.4) { phase in picture(phase) }
        }
    }

    /// Mono, so the parameters' width follows their length.
    private static let urlFont: CGFloat = 10

    private func picture(_ phase: Double) -> some View {
        let copy = ZPI.pulse(phase, 0.12, 0.26)
        let marked = ZPI.ease(phase, 0.28, 0.38)
        let collapse = ZPI.ease(phase, 0.45, 0.62)
        let back = ZPI.ease(phase, 0.92, 1)
        let shrink = collapse * (1 - back)
        let done = ZPI.pulse(phase, 0.62, 0.92)
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return ZStack {
            HStack(spacing: 0) {
                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.secondary).padding(.trailing, 6)
                Text(inputText.sampleHost).font(ZenithType.mono(Self.urlFont, weight: .medium)).foregroundStyle(ZPI.ink).fixedSize()
                HStack(spacing: 0) {
                    ForEach(inputText.sampleTracking, id: \.self) { parameter in
                        Text(parameter).font(ZenithType.mono(Self.urlFont))
                            .foregroundStyle(marked > 0.5 ? ZenithStatus.warning : Color.secondary)
                            .fixedSize()
                            .background(ZenithStatus.warning.opacity(0.16 * marked * (1 - shrink)))
                    }
                }
                .frame(width: CGFloat(inputText.sampleTracking.joined().count) * Self.urlFont * 0.62 * (1 - shrink), alignment: .leading)
                .clipped()
                .opacity(1 - shrink)
                .zenithPreviewPart(cornerRadius: 6, highlighted: true) { jump("urlCleaner.rules") }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: 420, height: 38)
            .background(shape.fill(ZPI.surface))
            .overlay(shape.strokeBorder(done > 0.5 ? Color.accentColor.opacity(0.6) : ZPI.stroke))
            .position(x: 220, y: 70)
            ZPIChord(caps: ["⌘", "C"], lit: copy > 0.5, depth: copy)
                .position(x: 140, y: 138)
            arrow(196, 138)
            ZPIChip(text: inputText.cleaned, symbol: "checkmark", lit: done > 0.5)
                .opacity(0.3 + 0.7 * done)
                .position(x: 290, y: 138)
        }
    }
}

// MARK: - Clipboard

struct ZenithClipboardPreviewCard: View {
    @ObservedObject private var router = SettingsRouter.shared
    @State private var picked: Int?

    private enum Part { case history, plain, qr }

    private var parts: [Part] {
        var parts: [Part] = []
        if AppFeature.clipboardHistory.isAvailable { parts.append(.history) }
        if AppFeature.pastePlain.isAvailable { parts.append(.plain) }
        parts.append(.qr)
        return parts
    }

    private func anchor(_ part: Part) -> SettingsSectionAnchor {
        switch part {
        case .history: return .clipboardHistory
        case .plain: return .pastePlain
        case .qr: return .zenithQR
        }
    }

    private func title(_ part: Part) -> String {
        switch part {
        case .history: return inputText.history
        case .plain: return inputText.plainText
        case .qr: return inputText.qr
        }
    }

    private var routed: Int? {
        guard router.page == .clipboard, let anchor = router.destination.sectionAnchor else { return nil }
        return parts.firstIndex { self.anchor($0) == anchor }
    }

    var body: some View {
        let parts = self.parts
        let index = min(picked ?? routed ?? 0, parts.count - 1)
        let part = parts[index]
        let caption: String = switch part {
        case .history: inputText.historyCaption
        case .plain: inputText.plainCaption
        case .qr: inputText.qrCaption
        }
        ZenithSettingsPreviewCard(id: "clipboard", caption: caption, states: parts.map(title),
                                  selection: Binding(get: { index }, set: { picked = $0 }), highlight: title(part)) {
            ZPIStage(period: part == .history ? 4 : 3.4, still: part == .history ? 0.8 : 0.6) { phase in
                switch part {
                case .history: history(phase)
                case .plain: plain(phase)
                case .qr: qr(phase)
                }
            }
        }
        .onChange(of: router.requestID) { _, _ in picked = nil }
    }

    private func open(_ part: Part) {
        picked = nil
        router.request(FeatureSettingsDestination(.clipboard, sectionAnchor: anchor(part)))
    }

    private func history(_ phase: Double) -> some View {
        let symbols = ["text.alignleft", "link", "paintpalette.fill", "doc.fill"]
        let arrivals = (0..<4).map { ZPI.ease(phase, 0.08 + Double($0) * 0.18, 0.16 + Double($0) * 0.18) }
        let count = arrivals.filter { $0 > 0 }.count
        let copying = (0..<4).contains { ZPI.pulse(phase, 0.04 + Double($0) * 0.18, 0.14 + Double($0) * 0.18, fade: 0.02) > 0.5 }
        let fade = 1 - ZPI.ease(phase, 0.9, 1)
        return ZStack {
            ZPIChord(caps: ["⌘", "C"], lit: copying, depth: copying ? 1 : 0).position(x: 96, y: 88)
            arrow(178)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<4, id: \.self) { slot in
                    // Newest on top: slot 0 holds the latest arrival.
                    let item = count - 1 - slot
                    if item >= 0 {
                        row(symbol: symbols[item], title: inputText.sampleClips[item], newest: slot == 0)
                            .opacity(slot == 0 ? arrivals[item] : 1)
                            .offset(y: slot == 0 ? -10 * (1 - arrivals[item]) : 0)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: 200, height: 160, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ZPI.raised))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ZPI.stroke))
            .opacity(fade)
            .zenithPreviewPart(cornerRadius: 14, highlighted: true) { open(.history) }
            .position(x: 300, y: 98)
        }
    }

    private func row(symbol: String, title: String, newest: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(symbol == "paintpalette.fill" ? ZenithStatus.info : Color.secondary)
                .frame(width: 16)
            Text(title).font(.system(size: 11)).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 7).fill(newest ? Color.accentColor.opacity(0.16) : ZPI.surface))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(newest ? Color.accentColor.opacity(0.45) : ZPI.line))
    }

    private func plain(_ phase: Double) -> some View {
        let caps = GlobalShortcutRole.pastePlain.assignedShortcut()?.keyCaps ?? ["⌥", "⇧", "⌘", "V"]
        let press = ZPI.pulse(phase, 0.3, 0.45)
        let pasted = ZPI.ease(phase, 0.42, 0.55) * (1 - ZPI.ease(phase, 0.92, 1))
        return ZStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(inputText.richSample).font(.system(size: 15, weight: .heavy, design: .serif))
                    .foregroundStyle(Color(red: 0.85, green: 0.3, blue: 0.4))
                Text("example.com").font(.system(size: 11)).underline().foregroundStyle(ZenithStatus.info)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ZPI.stroke))
            .position(x: 92, y: 80)
            ZPIChord(caps: caps, lit: press > 0.5, depth: press)
                .zenithPreviewPart(cornerRadius: 10, highlighted: true) { open(.plain) }
                .position(x: 220, y: 150)
            arrow(190, 80)
            ZPIField(content: Text(pasted > 0.5 ? "\(inputText.richSample) example.com" : ""), width: 190,
                     lit: pasted > 0.5, caret: true)
                .opacity(0.5 + 0.5 * max(pasted, 0.4))
                .position(x: 330, y: 80)
        }
    }

    private func qr(_ phase: Double) -> some View {
        let grow = ZPI.ease(phase, 0.3, 0.5) * (1 - ZPI.ease(phase, 0.9, 1))
        return ZStack {
            ZPIChip(text: inputText.qrSample, symbol: "link", lit: false).position(x: 110, y: 90)
            arrow(200, 90)
            ZenithInputSampleQR()
                .frame(width: 120, height: 120)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .scaleEffect(0.6 + 0.4 * grow)
                .opacity(0.25 + 0.75 * grow)
                .zenithPreviewPart(cornerRadius: 12, highlighted: true) { open(.qr) }
                .position(x: 310, y: 98)
        }
    }
}

/// A QR-looking pattern, the same every time: three finder squares and a
/// fixed scatter of modules. Not a readable code.
private struct ZenithInputSampleQR: View {
    var body: some View {
        Canvas { context, size in
            let count = 21
            let cell = size.width / CGFloat(count)
            var path = Path()
            var seed: UInt32 = 0x5A17
            for y in 0..<count {
                for x in 0..<count {
                    seed = seed &* 1_103_515_245 &+ 12_345
                    let finder = (x < 8 && y < 8) || (x >= count - 8 && y < 8) || (x < 8 && y >= count - 8)
                    guard !finder, (seed >> 16) & 1 == 1 else { continue }
                    path.addRect(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell))
                }
            }
            for origin in [CGPoint.zero, CGPoint(x: CGFloat(count - 7), y: 0), CGPoint(x: 0, y: CGFloat(count - 7))] {
                let outer = CGRect(x: origin.x * cell, y: origin.y * cell, width: cell * 7, height: cell * 7)
                path.addRect(outer)
                path.addRect(outer.insetBy(dx: cell, dy: cell))
                path.addRect(outer.insetBy(dx: cell * 2, dy: cell * 2))
            }
            context.fill(path, with: .color(.black), style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Text snippets

struct ZenithTextSnippetsPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.zenithPreviewJump) private var jump
    @State private var state = 0

    var body: some View {
        let text = FeatureStrings.snippets(l10n.language)
        ZenithSettingsPreviewCard(id: "textSnippets", caption: state == 0 ? inputText.snippetCaption : inputText.libraryCaption,
                                  states: [inputText.trigger, inputText.library], selection: $state,
                                  highlight: state == 0 ? inputText.trigger : text.libraryTitle) {
            ZPIStage(period: 3.6, still: state == 0 ? 0.6 : 0.5) { phase in
                if state == 0 { trigger(phase) } else { library(phase) }
            }
        }
    }

    private func trigger(_ phase: Double) -> some View {
        let source = inputText.sampleTrigger
        let typed = Int((Double(source.count) * ZPI.span(phase, 0.1, 0.4)).rounded())
        let expanded = phase > 0.48 && phase < 0.95
        let glow = ZPI.pulse(phase, 0.48, 0.75)
        let caret = Int(phase * 10) % 2 == 0
        let content: Text = expanded
            ? Text("Ship to: ") + Text(inputText.sampleExpansion).foregroundColor(glow > 0.5 ? .accentColor : .primary)
            : Text("Ship to: ") + Text(String(source.prefix(typed))).font(ZenithType.mono(13, weight: .semibold))
        return ZStack {
            ZPIField(content: content, width: 330, lit: glow > 0.5, caret: caret)
                .position(x: 220, y: 72)
            HStack(spacing: 10) {
                ZPIChip(text: source, symbol: "character.cursor.ibeam", lit: false)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                ZPIChip(text: inputText.sampleExpansion, lit: expanded)
            }
            .zenithPreviewPart(cornerRadius: 14, highlighted: true) { jump("snippets.list") }
            .position(x: 220, y: 146)
        }
    }

    private func library(_ phase: Double) -> some View {
        let open = ZPI.ease(phase, 0.08, 0.2) * (1 - ZPI.ease(phase, 0.66, 0.74))
        let selected = phase < 0.35 ? 0 : 1
        let pasted = phase > 0.7 && phase < 0.95
        return ZStack {
            ZPIField(content: Text("Hi! ") + Text(pasted ? inputText.sampleSnippets[1].1 : ""), width: 250, caret: true)
                .position(x: 150, y: 50)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                    Text(inputText.searchSnippets).font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
                ForEach(Array(inputText.sampleSnippets.enumerated()), id: \.offset) { index, snippet in
                    HStack(spacing: 8) {
                        Text(snippet.0).font(ZenithType.mono(10.5, weight: .semibold))
                            .foregroundStyle(index == selected ? Color.accentColor : .secondary)
                            .frame(width: 44, alignment: .leading)
                        Text(snippet.1).font(.system(size: 11)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(index == selected ? Color.accentColor.opacity(0.16) : .clear))
                }
            }
            .padding(10)
            .frame(width: 230)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ZPI.raised))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(ZPI.stroke))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            .scaleEffect(0.9 + 0.1 * open)
            .opacity(open)
            .zenithPreviewPart(cornerRadius: 14, highlighted: true) { jump("snippets.library") }
            .position(x: 290, y: 122)
        }
    }
}

// MARK: - Radial menu

struct ZenithRadialMenuPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.zenithPreviewJump) private var jump

    private static let symbols = ["safari", "folder", "camera.viewfinder", "music.note", "terminal", "gearshape"]

    var body: some View {
        ZenithSettingsPreviewCard(id: "radialMenu", caption: inputText.radialCaption,
                                  highlight: FeatureStrings.radialMenu(l10n.language).actionsHeader) {
            ZPIStage(period: 3.6, still: 0.6) { phase in picture(phase) }
        }
    }

    private func picture(_ phase: Double) -> some View {
        let open = ZPI.ease(phase, 0.1, 0.22) * (1 - ZPI.ease(phase, 0.72, 0.8))
        let aim = ZPI.ease(phase, 0.3, 0.5)
        let chosen = 2
        let angle = -90.0 + Double(chosen) * 60
        let center = CGPoint(x: 220, y: 98)
        let pointer = CGPoint(x: center.x + CGFloat(cos(angle * .pi / 180) * 48 * aim),
                              y: center.y + CGFloat(sin(angle * .pi / 180) * 48 * aim))
        let ran = ZPI.pulse(phase, 0.78, 0.98)
        return ZStack {
            wheel(highlight: aim > 0.3 ? chosen : nil, angle: angle, aim: aim)
                .scaleEffect(0.7 + 0.3 * open)
                .opacity(open)
                .zenithPreviewPart(cornerRadius: 90, highlighted: true) { jump("radial.actions") }
                .position(center)
            ZPIPointer().position(x: pointer.x + 8, y: pointer.y + 10)
            ZPIChip(text: inputText.radialSamples[chosen], symbol: Self.symbols[chosen])
                .opacity(ran)
                .position(x: 220, y: 98)
        }
    }

    private func wheel(highlight: Int?, angle: Double, aim: Double) -> some View {
        let diameter: CGFloat = 168
        return ZStack {
            Circle().fill(ZPI.raised.opacity(0.95))
            Circle().strokeBorder(ZPI.stroke)
            if highlight != nil {
                RadialPreviewWedge(center: angle, width: 60)
                    .fill(Color.accentColor.opacity(0.28 * aim))
            }
            ForEach(0..<6, id: \.self) { index in
                let theta = (-90.0 + Double(index) * 60) * .pi / 180
                Image(systemName: Self.symbols[index])
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(highlight == index ? Color.accentColor : ZPI.ink)
                    .offset(x: CGFloat(cos(theta)) * 60, y: CGFloat(sin(theta)) * 60)
            }
            Circle().fill(ZPI.surface).frame(width: 52, height: 52)
                .overlay(Circle().strokeBorder(ZPI.stroke))
            Text(highlight.map { inputText.radialSamples[$0] } ?? "")
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 46)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }
}

/// One slice of the wheel, `width` degrees around `center`.
private struct RadialPreviewWedge: Shape {
    let center: Double
    let width: Double

    func path(in rect: CGRect) -> Path {
        let mid = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: mid, radius: rect.width / 2 - 3, startAngle: .degrees(center - width / 2),
                    endAngle: .degrees(center + width / 2), clockwise: false)
        path.addArc(center: mid, radius: 28, startAngle: .degrees(center + width / 2),
                    endAngle: .degrees(center - width / 2), clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Shortcuts

struct ZenithShortcutsPreviewCard: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.zenithPreviewJump) private var jump

    private static let rows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", "⇧"],
        ["⌃", "⌥", "⌘", "Space", "⌘", "⌥"],
    ]

    /// A few of this Mac's own shortcuts, from features that are installed.
    private var samples: [(role: GlobalShortcutRole, caps: [String])] {
        let preferred: [GlobalShortcutRole] = [.clipboard, .screenshot, .commandBar, .keepAwake, .radialMenu, .shelf]
        let available = Set(GlobalShortcutRole.availableRoles(isAvailable: { $0.isAvailable }))
        let picked = preferred.filter(available.contains).compactMap { role -> (role: GlobalShortcutRole, caps: [String])? in
            guard let shortcut = role.assignedShortcut() else { return nil }
            return (role: role, caps: shortcut.keyCaps)
        }
        return picked.isEmpty ? [(role: .clipboard, caps: ["⌥", "⌘", "V"])] : Array(picked.prefix(3))
    }

    var body: some View {
        let samples = self.samples
        ZenithSettingsPreviewCard(id: "shortcuts", caption: inputText.shortcutsCaption, highlight: inputText.keyboard) {
            ZPIStage(period: 2.4 * Double(samples.count)) { phase in
                let index = min(samples.count - 1, Int(phase * Double(samples.count)))
                let local = phase * Double(samples.count) - Double(index)
                picture(samples[index], local: local)
            }
        }
    }

    private func picture(_ sample: (role: GlobalShortcutRole, caps: [String]), local: Double) -> some View {
        let press = ZPI.pulse(local, 0.2, 0.8, fade: 0.08)
        let lit = Set(sample.caps.map { $0.uppercased() })
        return ZStack {
            HStack(spacing: 10) {
                Text(sample.role.title(l10n.s)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(sample.caps.joined(separator: " ")).font(ZenithType.mono(12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .opacity(0.3 + 0.7 * press)
            .position(x: 220, y: 18)
            VStack(spacing: 4) {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                            let on = lit.contains(key.uppercased()) && press > 0.3
                            ZPIKey(label: key, lit: on, depth: on ? press : 0, width: key == "Space" ? 118 : 26,
                                   height: 22, fontSize: 10)
                        }
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ZPI.raised.opacity(0.6)))
            .zenithPreviewPart(cornerRadius: 14, highlighted: true) { jump("shortcuts.\(sample.role.group.rawValue)") }
            .position(x: 220, y: 116)
        }
    }
}
