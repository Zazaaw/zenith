// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Prompter page of the island. At rest it is the chosen
// script, editable in place, with the scripts in the top row and Start beside
// them. Prompting, the island grows down from the camera into a tall, narrow
// reading panel (`ZenithPrompterIslandGeometry`, through the island's own
// geometry), and the page becomes the reader: white on black, a soft guide a
// third of the way down, faded edges, and a column that scrolls on every
// display frame from `PrompterClock`.

enum PrompterReaderMetrics {
    /// The text's inset from the reading panel's sides.
    static let textInset: Double = 18
    /// The progress line and the controls under the text.
    static let footerHeight: CGFloat = 34
    /// The guide sits a third of the way down, where the eyes rest naturally
    /// below the camera.
    static let guideFraction: CGFloat = 1.0 / 3.0
}

struct PrompterPage: View {
    let size: CGSize
    /// Settings shows the page at rest, never a session.
    var preview = false
    @ObservedObject private var service = PrompterService.shared

    var body: some View {
        if !preview, service.session != nil {
            PrompterReader(size: size)
        } else {
            PrompterScriptPage(preview: preview)
        }
    }
}

// MARK: - At rest

/// The chosen script in an editor, the scripts' menu and Start in the top row.
private struct PrompterScriptPage: View {
    let preview: Bool
    @ObservedObject private var service = PrompterService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchPrompterSpeed) private var speed = PrompterSettings.defaultSpeed
    @Environment(\.notchBand) private var band

    private var text: ZenithPrompterStrings { ZenithStrings.prompter(l10n.language) }
    private var hasWords: Bool { PrompterText.wordCount(service.draft) > 0 }

    var body: some View {
        Group {
            if service.scripts.isEmpty {
                NotchEmptyView(symbol: NotchModule.prompter.symbol, message: text.noScripts) {
                    if !preview {
                        HStack(spacing: 8) {
                            NotchPillButton(title: text.newScript, prominent: true) { service.createScript() }
                            NotchPillButton(title: text.importScript) {
                                service.presentImport(from: NotchService.shared.presentationWindow)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    editor
                    meta
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .notchBand(leading: {
            if !service.scripts.isEmpty { scriptMenu }
        }, trailing: {
            if !service.scripts.isEmpty {
                NotchPillButton(title: text.start, prominent: true) { service.startSession() }
                    .disabled(!hasWords || preview)
                    .help(text.keysHint)
            }
        })
        .onDisappear { service.flushSave() }
    }

    @ViewBuilder private var editor: some View {
        let inset = NSSize(width: 6, height: 6)
        ZStack(alignment: .topLeading) {
            if preview {
                Text(service.draft.isEmpty ? text.placeholder : service.draft)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(service.draft.isEmpty ? 0.35 : 0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            } else {
                PlainTextEditor(text: Binding(get: { service.draft }, set: { service.setDraft($0) }),
                                fontSize: 13, textColor: .white, textContainerInset: inset,
                                onCreate: { view in view.insertionPointColor = .white })
                .id(service.selectedID)
                if service.draft.isEmpty {
                    Text(text.placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.leading, inset.width + PlainTextEditor.lineFragmentPadding)
                        .padding(.top, inset.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(ZenithIslandSheet())
    }

    /// About how long it reads, at the speed it will start at.
    private var meta: some View {
        let seconds = service.duration(of: service.draft, wpm: speed)
        return HStack(spacing: 8) {
            Text("≈ \(PrompterFormat.clock(seconds))")
            Text("\(PrompterSettings.clampedSpeed(speed)) \(text.wpm)")
            Spacer(minLength: 8)
            Image(systemName: "keyboard")
                .help(text.keysHint)
                .accessibilityLabel(text.keysHint)
        }
        .font(ZenithType.mono(10.5))
        .foregroundStyle(ZenithIsland.tertiary)
        .padding(.horizontal, 4)
    }

    private var scriptMenu: some View {
        NotchMenuButton(title: text.scripts, items: menuItems, cornerRadius: 9) {
            NotchBandMenuLabel(title: service.selectedScript?.name ?? text.scripts)
        }
        .frame(maxWidth: band.besideCamera ? band.side : 220, alignment: .leading)
        .help(text.scripts)
        .accessibilityValue(service.selectedScript?.name ?? "")
    }

    private var menuItems: [NotchMenuItem] {
        guard !preview else { return [] }
        var items = service.scripts.map { script in
            NotchMenuItem(title: script.name, checked: script.id == service.selectedID) { service.select(script.id) }
        }
        items.append(.separator)
        items.append(NotchMenuItem(title: text.newScript, symbol: "plus") { service.createScript() })
        items.append(NotchMenuItem(title: text.importScript, symbol: "square.and.arrow.down") {
            service.presentImport(from: NotchService.shared.presentationWindow)
        })
        if service.canUseScratchpad {
            items.append(NotchMenuItem(title: text.fromScratchpad, symbol: "note.text") { service.createFromScratchpad() })
        }
        return items
    }
}

// MARK: - Prompting

/// The reading panel: the column on black under a guide band, with faded
/// edges, the countdown over it and the controls below.
private struct PrompterReader: View {
    let size: CGSize
    @ObservedObject private var service = PrompterService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var text: ZenithPrompterStrings { ZenithStrings.prompter(l10n.language) }

    var body: some View {
        if let session = service.session {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    viewport(session, size: proxy.size)
                }
                .clipShape(RoundedRectangle(cornerRadius: ZenithIsland.cardRadius, style: .continuous))
                PrompterFooter(session: session, text: text)
                    .frame(height: PrompterReaderMetrics.footerHeight)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func viewport(_ session: PrompterSessionState, size: CGSize) -> some View {
        let settings = session.settings
        let line = PrompterLayout.lineHeight(textSize: settings.textSize, lineSpacing: 1)
        let guideY = (size.height * PrompterReaderMetrics.guideFraction).rounded()
        let columnWidth = max(0, size.width - PrompterReaderMetrics.textInset * 2)
        return ZStack(alignment: .topLeading) {
            Color.black
            if settings.guide {
                PrompterGuideBand(height: line * 1.3, contrast: contrast)
                    .position(x: size.width / 2, y: guideY)
            }
            TimelineView(.animation(minimumInterval: nil, paused: !session.animating(at: Date().timeIntervalSinceReferenceDate))) { context in
                let offset = service.session?.clock.offset(at: context.date.timeIntervalSinceReferenceDate) ?? 0
                PrompterColumn(paragraphs: session.paragraphs, textSize: settings.textSize,
                               lineSpacing: settings.lineSpacing, alignment: settings.alignment,
                               width: columnWidth, generation: session.generation)
                    .equatable()
                    .frame(width: columnWidth, alignment: .top)
                    .offset(x: PrompterReaderMetrics.textInset, y: guideY - line / 2 - offset)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .opacity(session.countdown == nil ? 1 : 0.35)
            .mask(PrompterFadeMask(height: size.height, guideY: guideY, line: line))
            .scaleEffect(x: settings.mirror ? -1 : 1, y: 1)
            if let count = session.countdown {
                countdown(count, mirror: settings.mirror)
                    .position(x: size.width / 2, y: guideY)
            }
            if session.finished {
                Text(text.finished)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZenithIsland.secondary)
                    .position(x: size.width / 2, y: size.height - 18)
                    .transition(.zenithMorph(reduceMotion: reduceMotion))
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: session.countdown)
        .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: session.finished)
        .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: settings.mirror)
        .contentShape(Rectangle())
        .onTapGesture { service.togglePlayback() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.title)
        .accessibilityValue(session.paragraphs.first?.text ?? "")
        .accessibilityAction(named: session.playing ? text.pause : text.play) { service.togglePlayback() }
    }

    /// 3, 2, 1: each number blurs in as the last blurs out.
    private func countdown(_ count: Int, mirror: Bool) -> some View {
        ZStack {
            Text("\(count)")
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .id(count)
                .transition(.zenithMorph(reduceMotion: reduceMotion))
        }
        .scaleEffect(x: mirror ? -1 : 1, y: 1)
        .accessibilityHidden(true)
    }
}

/// The text, laid out once per layout; the reader only moves it. Equatable,
/// so the frame-by-frame timeline never lays it out again. Each paragraph
/// reports where it sits, which replaces the estimate the session started on.
private struct PrompterColumn: View, Equatable {
    static let space = "zenith.prompter.column"

    let paragraphs: [PrompterParagraph]
    let textSize: Int
    let lineSpacing: Double
    let alignment: PrompterAlignment
    let width: CGFloat
    let generation: Int

    var body: some View {
        let centered = alignment == .center
        VStack(alignment: centered ? .center : .leading, spacing: PrompterLayout.paragraphSpacing(textSize: textSize)) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                Text(paragraph.text)
                    .font(.system(size: CGFloat(textSize), weight: paragraph.heading ? .heavy : .semibold))
                    .lineSpacing(PrompterLayout.extraLineSpacing(textSize: textSize, lineSpacing: lineSpacing))
                    .multilineTextAlignment(centered ? .center : .leading)
                    .foregroundStyle(paragraph.heading ? Color.white.opacity(0.72) : .white)
                    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frame in
                        PrompterService.shared.measured(index: index, frame: frame, generation: generation)
                    }
            }
        }
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .coordinateSpace(.named(Self.space))
    }
}

/// A soft band across the panel where the line to read sits, with a small
/// mark at each end in the module's colour.
private struct PrompterGuideBand: View {
    let height: CGFloat
    let contrast: ColorSchemeContrast

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(10, height / 3), style: .continuous)
                .fill(Color.white.opacity(contrast == .increased ? 0.14 : 0.07))
                .padding(.horizontal, 6)
            HStack {
                Capsule().fill(NotchModule.prompter.zenithTint).frame(width: 3, height: height * 0.5)
                Spacer()
                Capsule().fill(NotchModule.prompter.zenithTint).frame(width: 3, height: height * 0.5)
            }
            .padding(.horizontal, 2)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Text above the guide dims as it has been read, and both edges fade out.
private struct PrompterFadeMask: View {
    let height: CGFloat
    let guideY: CGFloat
    let line: CGFloat

    var body: some View {
        let h = max(1, height)
        func at(_ y: CGFloat) -> CGFloat { min(1, max(0, y / h)) }
        let read = at(guideY - line * 1.6)
        let reading = max(read + 0.001, at(guideY - line * 0.7))
        let bottom = max(reading + 0.001, 0.84)
        return LinearGradient(stops: [
            .init(color: .black.opacity(0), location: 0),
            .init(color: .black.opacity(0.4), location: read),
            .init(color: .black, location: reading),
            .init(color: .black, location: bottom),
            .init(color: .black.opacity(0), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }
}

/// The progress line, the speed, the time left and the controls. Its own
/// timeline keeps the line moving with the text.
private struct PrompterFooter: View {
    let session: PrompterSessionState
    let text: ZenithPrompterStrings
    @ObservedObject private var service = PrompterService.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !session.animating(at: Date().timeIntervalSinceReferenceDate))) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let state = service.session ?? session
            let offset = state.clock.offset(at: now)
            VStack(spacing: 4) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ZenithIsland.barTrack)
                        Capsule().fill(NotchModule.prompter.zenithTint)
                            .frame(width: proxy.size.width * state.timeline.progress(offset: offset))
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 10)
                HStack(spacing: 6) {
                    NotchIconButton(symbol: state.playing ? "pause.fill" : "play.fill",
                                    title: state.playing ? text.pause : text.play) { service.togglePlayback() }
                    if state.voiceHolding {
                        Label(text.voiceHolding, systemImage: "mic")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(ZenithStatus.warning)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 4) {
                            if state.listening {
                                Image(systemName: "mic").help(text.voiceTitle)
                            }
                            Text("\(state.settings.speed) \(text.wpm)")
                        }
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(String(format: text.leftFormat, PrompterFormat.clock(state.timeline.timeLeft(offset: offset,
                                                                                                 wpm: state.settings.speed))))
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(1)
                    NotchIconButton(symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                    title: text.mirror, selected: state.settings.mirror) { service.toggleMirror() }
                    NotchIconButton(symbol: "xmark", title: text.exit) { service.stop() }
                        .help(text.keysHint)
                }
            }
            .padding(.top, 4)
        }
    }
}
