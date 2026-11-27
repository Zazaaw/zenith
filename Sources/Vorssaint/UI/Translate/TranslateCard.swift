// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import AVFoundation
import Carbon.HIToolbox
import Combine
import SwiftUI
import Translation

// Zenith fork: Translate's card. It opens under the pointer like the QR scan
// result, on the island's near black: the languages as chips (tap one to
// change it, the arrows to swap them), the translation, and Copy, Replace
// (paste over the selection) and Speak. Esc or a click elsewhere closes it.
// The card carries the SwiftUI host the Translation framework needs on macOS
// 15; on macOS 26 an installed pair is translated without it.

// MARK: - Model

@available(macOS 15.0, *)
@MainActor
final class TranslateCardModel: ObservableObject {
    enum Phase: Equatable {
        case working
        case translated(String)
        /// The text is already in `language` and there is no other to read it in.
        case alreadyIn(String)
        case needsDownload(from: String?, to: String)
        case unsupported(from: String?, to: String)
        case failed
        /// Nothing to translate; only a line to say why.
        case message(String)
        case accessibility
    }

    @Published private(set) var phase: Phase
    /// The person's choice of source; nil = the detected language.
    @Published private(set) var chosenSource: String?
    @Published private(set) var target: String
    @Published private(set) var detection: TranslateDetection?
    @Published private(set) var languages = TranslateLanguageCode.menu(TranslateLanguageCode.fallbackLanguages)
    @Published private(set) var hostedConfiguration: TranslationSession.Configuration?
    @Published private(set) var speaking = false

    let text: String
    let truncated: Bool
    let origin: TranslateOrigin?
    let showDetection: Bool
    private let preferences: TranslatePreferences?
    /// Bumped by every translation started, so a late answer to an older
    /// one never replaces the current.
    private var generation = 0
    private var hostedGeneration = 0
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate = TranslateSpeechDelegate()

    init(prepared: TranslateText.Prepared, origin: TranslateOrigin, preferences: TranslatePreferences) {
        text = prepared.text
        truncated = prepared.truncated
        self.origin = origin
        self.preferences = preferences
        showDetection = preferences.showDetection
        target = preferences.primary
        phase = .working
        synthesizer.delegate = speechDelegate
        speechDelegate.finished = { [weak self] in self?.speaking = false }
    }

    init(message: String) {
        text = ""
        truncated = false
        origin = nil
        preferences = nil
        showDetection = false
        target = "en"
        phase = .message(message)
    }

    static func accessibilityNeeded() -> TranslateCardModel {
        let model = TranslateCardModel(message: "")
        model.phase = .accessibility
        return model
    }

    var hasLanguages: Bool { preferences != nil }
    var source: String? { chosenSource ?? detection?.code }
    var translation: String? {
        if case .translated(let value) = phase { return value }
        return nil
    }

    var canReplace: Bool {
        if case .selection(_, let replaceable)? = origin { return replaceable && translation != nil }
        return false
    }

    /// Detects the language, picks where it goes and translates.
    func start() {
        guard let preferences else { return }
        detection = TranslateEngine.detect(text)
        let choice = TranslateTargetChoice.choose(detected: detection?.code, primary: preferences.primary,
                                                  second: preferences.second)
        guard let chosen = choice.target else {
            phase = .alreadyIn(detection?.code ?? preferences.primary)
            loadLanguages()
            return
        }
        target = chosen
        translate()
        loadLanguages()
    }

    func setSource(_ code: String?) {
        chosenSource = code
        translate()
    }

    func setTarget(_ code: String) {
        target = code
        translate()
    }

    /// The source becomes the target and the other way round.
    func swap() {
        guard let source else { return }
        let previous = target
        target = source
        chosenSource = previous
        translate()
    }

    private func loadLanguages() {
        Task { @MainActor [weak self] in
            let codes = await TranslateEngine.supportedLanguages()
            self?.languages = codes
        }
    }

    private func translate() {
        stopSpeaking()
        generation += 1
        let current = generation
        let from = source
        let to = target
        if let from, TranslateLanguageCode.same(from, to) {
            phase = .alreadyIn(to)
            return
        }
        phase = .working
        let text = self.text
        Task { @MainActor [weak self] in
            let status = await TranslateEngine.status(from: from, to: to, text: text)
            guard let self, current == self.generation else { return }
            switch TranslateRoute.choose(status: status, directAvailable: TranslateEngine.directAvailable,
                                         sourceKnown: from != nil) {
            case .direct:
                do {
                    let result = try await TranslateEngine.translateDirect(text, from: from ?? "", to: to)
                    guard current == self.generation else { return }
                    self.phase = .translated(result)
                } catch {
                    // The session refused what it was said to have: let the
                    // hosted one try, which can also ask for what's missing.
                    guard current == self.generation else { return }
                    self.host(from: from, to: to, generation: current)
                }
            case .hosted:
                self.host(from: from, to: to, generation: current)
            case .download:
                self.phase = .needsDownload(from: from, to: to)
            case .unsupported:
                self.phase = .unsupported(from: from, to: to)
            }
        }
    }

    /// Hands the pair to the card's `translationTask`, which opens a session
    /// and calls `runHosted`.
    private func host(from: String?, to: String, generation: Int) {
        hostedGeneration = generation
        let configuration = TranslateEngine.configuration(from: from, to: to)
        if var existing = hostedConfiguration, existing.source == configuration.source,
           existing.target == configuration.target {
            existing.invalidate()
            hostedConfiguration = existing
        } else {
            hostedConfiguration = configuration
        }
    }

    func runHosted(_ session: TranslationSession) async {
        let current = hostedGeneration
        guard current == generation else { return }
        do {
            let response = try await session.translate(text)
            guard current == generation else { return }
            if chosenSource == nil, detection == nil,
               let found = TranslateLanguageCode.canonical(response.sourceLanguage.maximalIdentifier) {
                detection = TranslateDetection(code: found, confidence: 1)
            }
            phase = .translated(response.targetText)
        } catch {
            guard current == generation else { return }
            phase = .failed
        }
    }

    // MARK: Speech

    func toggleSpeech() {
        if speaking { return stopSpeaking() }
        guard let translation else { return }
        let utterance = AVSpeechUtterance(string: translation)
        let voices = AVSpeechSynthesisVoice.speechVoices().map(\.language)
        if let language = TranslateLanguageCode.speechLanguage(target, available: voices) {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        speaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        guard speaking || synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
    }
}

/// Speech ends on the synthesizer's own thread; the card hears it on main.
private final class TranslateSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var finished: (@MainActor () -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        end()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        end()
    }

    private func end() {
        let finished = self.finished
        DispatchQueue.main.async { MainActor.assumeIsolated { finished?() } }
    }
}

// MARK: - Controller

@available(macOS 15.0, *)
@MainActor
final class TranslateCardController {
    static let shared = TranslateCardController()

    private var panel: TranslateCardPanel?
    private var model: TranslateCardModel?
    private var host: NSHostingView<TranslateCardView>?
    private var changes: AnyCancellable?
    private var keyMonitor: Any?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    /// The card's top edge stays where it opened while it grows or shrinks.
    private var top: CGFloat = 0

    private init() {}

    private var text: ZenithTranslateStrings { ZenithStrings.translate(L10n.shared.language) }

    func showAccessibilityNeeded() {
        show(.accessibilityNeeded())
    }

    func show(_ model: TranslateCardModel) {
        close()
        let view = TranslateCardView(model: model, actions: TranslateCardActions(
            copy: { [weak self] in self?.copy() },
            replace: { [weak self] in self?.replace() },
            download: { [weak self] in self?.download() },
            settings: { [weak self] in self?.openSettings() },
            accessibility: { [weak self] in self?.openAccessibility() }))
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let panel = TranslateCardPanel(contentRect: CGRect(origin: .zero, size: size),
                                       styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let visible = NSScreen.pointerVisibleFrame
        let pointer = NSEvent.mouseLocation
        var origin = CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height - 18)
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        top = origin.y + size.height
        self.panel = panel
        self.model = model
        self.host = host
        // The card resizes to what it shows: working, then the translation.
        // Asked again a beat later: the first ask can come before SwiftUI has
        // laid the new state out.
        changes = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.fit() } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { MainActor.assumeIsolated { self?.fit() } }
        }
        installMonitors(for: panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        model.start()
    }

    func close() {
        for monitor in [keyMonitor, localMonitor, globalMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
        localMonitor = nil
        globalMonitor = nil
        changes = nil
        model?.stopSpeaking()
        model = nil
        host = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func fit() {
        guard let panel, let host else { return }
        let size = host.fittingSize
        guard size != panel.frame.size else { return }
        let visible = panel.screen?.visibleFrame ?? NSScreen.pointerVisibleFrame
        var origin = CGPoint(x: panel.frame.minX, y: top - size.height)
        origin.y = max(origin.y, visible.minY + 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
    }

    // MARK: Actions

    private func copy() {
        guard let translation = model?.translation else { return }
        close()
        let copied = text.copied
        GeneralPasteboardAccess.shared.async({ () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareVorssaintSource()
            return pasteboard.setString(translation, forType: .string)
        }, then: { ok in
            if ok { QuickToolHUD.show(icon: "translate", message: copied) } else { ZenithQuiet.beep() }
        })
    }

    /// Pastes the translation over the selection. The card never activated
    /// Zenith, so the app the text came from still has the keyboard once the
    /// card is gone; the clipboard is put back after the paste.
    private func replace() {
        guard let model, model.canReplace, let translation = model.translation,
              case .selection(let pid, _)? = model.origin else { return }
        close()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            ZenithQuiet.beep()
            return
        }
        if !TransientPaste.shared.paste(translation, didFail: { ZenithQuiet.beep() }) { ZenithQuiet.beep() }
    }

    private func download() {
        guard let model else { return }
        guard case .needsDownload(let from, let to) = model.phase else { return }
        close()
        TranslateService.shared.requestDownload(from: from, to: to)
    }

    private func openSettings() {
        close()
        TranslateService.shared.openSettings()
    }

    private func openAccessibility() {
        close()
        Permissions.shared.requestAccessibility()
    }

    // MARK: Closing

    private func installMonitors(for panel: NSPanel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === panel, Int(event.keyCode) == kVK_Escape else { return event }
            MainActor.assumeIsolated { self?.close() }
            return nil
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // A language menu opened from the card is part of it.
            let inMenu = (event.window?.level.rawValue ?? 0) >= NSWindow.Level.popUpMenu.rawValue
            if event.window !== panel, !inMenu { MainActor.assumeIsolated { self?.close() } }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }
}

private final class TranslateCardPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - View

struct TranslateCardActions {
    let copy: () -> Void
    let replace: () -> Void
    let download: () -> Void
    let settings: () -> Void
    let accessibility: () -> Void
}

@available(macOS 15.0, *)
struct TranslateCardView: View {
    @ObservedObject var model: TranslateCardModel
    let actions: TranslateCardActions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let text = ZenithStrings.translate(.enUS)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.hasLanguages { languageRow }
            content
            actionRow
        }
        .padding(14)
        .frame(width: 380)
        .modifier(QRCardChrome(cornerRadius: 20))
        .modifier(QRArrival(shown: shown, reduceMotion: reduceMotion))
        .translationTask(model.hostedConfiguration) { session in
            await model.runHosted(session)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMorph.animation) { shown = true }
        }
    }

    // MARK: Languages

    private var languageRow: some View {
        HStack(spacing: 6) {
            Menu {
                Button(text.detect) { model.setSource(nil) }
                Divider()
                ForEach(model.languages, id: \.self) { code in
                    Button(TranslateLanguageCode.displayName(code)) { model.setSource(code) }
                }
            } label: {
                TranslateChip(title: model.source.map(TranslateLanguageCode.displayName) ?? text.unknownLanguage,
                              detected: model.chosenSource == nil && model.detection != nil)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button(action: model.swap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ZenithIsland.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.source == nil)
            .help(text.swap)
            .accessibilityLabel(text.swap)

            Menu {
                ForEach(model.languages, id: \.self) { code in
                    Button(TranslateLanguageCode.displayName(code)) { model.setTarget(code) }
                }
            } label: {
                TranslateChip(title: TranslateLanguageCode.displayName(model.target), detected: false)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer(minLength: 6)
            if model.showDetection, model.chosenSource == nil, let detection = model.detection {
                Text("\(text.detected.uppercased()) · \(Int((detection.confidence * 100).rounded()))%")
                    .font(ZenithType.mono(9.5, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(ZenithIsland.tertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .working:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(text.translating)
                    .font(.system(size: 12))
                    .foregroundStyle(ZenithIsland.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        case .translated(let translation):
            VStack(alignment: .leading, spacing: 8) {
                Text(model.text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(ZenithIsland.tertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                ScrollView(.vertical) {
                    Text(translation)
                        .font(.system(size: 14))
                        .foregroundStyle(ZenithIsland.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                }
                .frame(maxHeight: 240)
                .fixedSize(horizontal: false, vertical: true)
                .zenithIslandSoftCard(cornerRadius: 12)
                if model.truncated {
                    Text(text.count(text.truncated, TranslateText.maximumLength))
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                }
            }
        case .alreadyIn(let code):
            note(text.name(text.alreadyIn, TranslateLanguageCode.displayName(code)), detail: text.chooseSecond,
                 color: ZenithStatus.info)
        case .needsDownload(let from, let to):
            note(text.pair(text.pairNotDownloaded, from: name(from), to: name(to)), color: ZenithStatus.warning)
        case .unsupported(let from, let to):
            note(text.pair(text.pairUnsupported, from: name(from), to: name(to)), color: ZenithStatus.warning)
        case .failed:
            note(text.failed, color: ZenithStatus.error)
        case .message(let message):
            note(message, color: ZenithStatus.info)
        case .accessibility:
            note(text.accessibilityNeeded, color: ZenithStatus.warning)
        }
    }

    private func name(_ code: String?) -> String {
        code.map(TranslateLanguageCode.displayName) ?? text.unknownLanguage
    }

    private func note(_ message: String, detail: String? = nil, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "translate")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(ZenithIsland.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    @ViewBuilder private var actionRow: some View {
        switch model.phase {
        case .translated:
            HStack(spacing: 8) {
                Button(action: model.toggleSpeech) {
                    Label(model.speaking ? text.stop : text.speak,
                          systemImage: model.speaking ? "stop.fill" : "speaker.wave.2")
                }
                .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                Spacer(minLength: 0)
                if model.canReplace {
                    Button(text.replace, action: actions.replace)
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
                }
                Button(text.copy, action: actions.copy)
                    .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                    .keyboardShortcut(.defaultAction)
            }
        case .needsDownload:
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(text.download, action: actions.download)
                    .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                    .keyboardShortcut(.defaultAction)
            }
        case .alreadyIn, .unsupported:
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(text.openSettings, action: actions.settings)
                    .buttonStyle(ZenithIslandOutlineButtonStyle(height: 26))
            }
        case .accessibility:
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(text.openAccessibility, action: actions.accessibility)
                    .buttonStyle(ZenithIslandPrimaryButtonStyle(height: 26))
                    .keyboardShortcut(.defaultAction)
            }
        case .working, .failed, .message:
            EmptyView()
        }
    }
}

/// A language as a chip: its name in a hairline capsule, a small dot when
/// it was detected rather than chosen.
private struct TranslateChip: View {
    let title: String
    let detected: Bool
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 5) {
            if detected {
                Circle().fill(ZenithIsland.accent).frame(width: 5, height: 5)
            }
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(ZenithIsland.tertiary)
        }
        .foregroundStyle(ZenithIsland.primary)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Capsule().fill(hovering ? ZenithIsland.hoverFill : .clear))
        .overlay(Capsule().strokeBorder(ZenithIsland.outline(contrast, emphasised: hovering), lineWidth: 0.75))
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
    }
}
