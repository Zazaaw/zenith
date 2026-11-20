// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the overlay's floating controls, a black capsule like the
/// island's pill that sits outside the image. It can take the keyboard (for
/// the arrow keys) without activating Zenith, so the browser stays the
/// frontmost app.
final class DesignOverlayHUDPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        // The capsule draws its own shadow inside the margin; a window shadow
        // would be traced while the capsule is still faded out.
        hasShadow = false
        level = DesignOverlayPanel.hudLevel
        collectionBehavior = DesignOverlayPanel.behavior
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
        isFloatingPanel = true
        animationBehavior = .none
    }
}

/// Whether the capsule is in, which its entrance and exit animate on.
final class DesignOverlayHUDPresence: ObservableObject {
    @Published var shown = false
}

/// The HUD's window and its SwiftUI content.
@MainActor
final class DesignOverlayHUD {
    let panel = DesignOverlayHUDPanel()
    let presence = DesignOverlayHUDPresence()
    private var hideWork: Task<Void, Never>?

    init(service: DesignOverlayService) {
        let host = NSHostingView(rootView: DesignOverlayHUDView(service: service, presence: presence))
        host.layoutSubtreeIfNeeded()
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
    }

    var size: CGSize { panel.frame.size }

    /// Shows the capsule with its top left at `origin` (global points, y down).
    func show(at origin: CGPoint, primaryHeight: CGFloat) {
        hideWork?.cancel()
        let frame = DesignOverlaySupport.cocoaFrame(CGRect(origin: origin, size: size), primaryHeight: primaryHeight)
        panel.setFrameOrigin(frame.origin)
        panel.orderFrontRegardless()
        // One runloop turn later, so SwiftUI sees the change and animates it.
        Task { @MainActor [presence] in presence.shown = true }
    }

    func hide() {
        presence.shown = false
        hideWork?.cancel()
        hideWork = Task { @MainActor [panel] in
            try? await Task.sleep(nanoseconds: UInt64(ZenithMotion.fast * 1_000_000_000))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    func focus() {
        panel.makeKeyAndOrderFront(nil)
    }
}

/// The capsule: grip and readout, opacity, blend, scale, grid, click-through,
/// lock, Fit, paste and close. Each control wears an island colour on its
/// glyph and, when on, over a soft tile of the same hue; radii nest inside
/// the capsule's.
struct DesignOverlayHUDView: View {
    @ObservedObject var service: DesignOverlayService
    @ObservedObject var presence: DesignOverlayHUDPresence
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    static let height: CGFloat = 44
    static let inset: CGFloat = 6
    static let tile: CGFloat = 32
    /// Transparent room around the capsule for its rise and blur.
    static let margin: CGFloat = 10
    /// Concentric with the capsule: its radius less the inset (16).
    static var tileRadius: CGFloat { ZenithIsland.innerRadius(depth: inset, outer: height / 2) }

    private var text: ZenithDesignOverlayStrings { ZenithStrings.designOverlay(l10n.language) }

    private enum Tint {
        static let opacity = ZenithIslandPalette.color(.captures)    // cyan
        static let blend = ZenithIslandPalette.color(.clipboard)     // violet
        static let scale = ZenithIslandPalette.color(.downloads)     // sky
        static let grid = ZenithIslandPalette.color(.notifications)  // amber
        static let through = ZenithIslandPalette.color(.files)       // teal
        static let lock = ZenithIslandPalette.color(.music)          // rose
        static let fit = ZenithIslandPalette.color(.camera)          // emerald
        static let paste = ZenithIslandPalette.color(.mixer)         // indigo
    }

    var body: some View {
        HStack(spacing: 4) {
            readout
            separator
            opacityControl
            separator
            ForEach(DesignOverlayBlend.allCases) { blend in
                tile(symbol: Self.symbol(blend), tint: Tint.blend, active: service.blend == blend,
                     help: title(blend)) { service.setBlend(blend) }
            }
            scaleMenu
            separator
            tile(symbol: "rectangle.split.3x1", tint: Tint.grid, active: service.showsGrid, help: text.grid) {
                service.setShowsGrid(!service.showsGrid)
            }
            tile(symbol: "cursorarrow.rays", tint: Tint.through, active: service.clickThrough,
                 help: text.clickThrough) { service.setClickThrough(!service.clickThrough) }
            tile(symbol: service.placement.locked ? "lock.fill" : "lock.open", tint: Tint.lock,
                 active: service.placement.locked, help: text.lock) { service.setLocked(!service.placement.locked) }
            tile(symbol: "viewfinder", tint: Tint.fit, active: false, help: text.fit) { service.fitToWindowUnderCursor() }
                .disabled(service.placement.locked)
            tile(symbol: "doc.on.clipboard", tint: Tint.paste, active: false, help: text.paste) {
                service.pasteFromClipboard()
            }
            separator
            tile(symbol: "xmark", tint: nil, active: false, help: text.close) { service.close() }
        }
        .padding(.horizontal, Self.inset)
        .frame(height: Self.height)
        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.94)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(ZenithIsland.outline(contrast), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        .environment(\.colorScheme, .dark)
        .modifier(DesignOverlayHUDEntrance(shown: presence.shown, reduceMotion: reduceMotion))
        .padding(Self.margin)
        .fixedSize()
    }

    // MARK: Pieces

    /// The grip and the image's size, or a short note after an action. The
    /// whole area drags the HUD.
    private var readout: some View {
        HStack(spacing: 6) {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ZenithIsland.meta)
                .frame(width: 10)
            Group {
                if let note = service.feedback {
                    Text(note.text(text))
                        .foregroundStyle(note.isWarning ? ZenithStatus.warning : ZenithIsland.primary)
                } else {
                    Text(service.sizeLabel)
                        .foregroundStyle(ZenithIsland.label)
                }
            }
            .font(ZenithType.mono(10.5, weight: .medium))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(width: 112, alignment: .leading)
            .zenithMorph(on: service.feedback)
        }
        .padding(.leading, 6)
        .frame(height: Self.tile)
        .overlay(DesignOverlayDragArea(tooltip: text.moveHint))
        .accessibilityElement(children: .combine)
        .accessibilityHint(text.moveHint)
    }

    private var opacityControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tint.opacity)
                .frame(width: 22, height: Self.tile)
            // Bound straight to the layer: no animation between the slider and the image.
            Slider(value: Binding(get: { service.opacity }, set: { service.setOpacity($0) }),
                   in: DesignOverlaySupport.opacityRange)
                .controlSize(.small)
                .tint(Tint.opacity)
                .frame(width: 104)
                .accessibilityLabel(text.opacity)
            Text("\(Int((service.opacity * 100).rounded()))%")
                .font(ZenithType.mono(10.5, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .help(text.opacity)
    }

    private var scaleMenu: some View {
        Menu {
            ForEach(DesignOverlayScaleChoice.allCases) { choice in
                Button {
                    service.setScaleChoice(choice)
                } label: {
                    if service.scaleChoice == choice { Label(scaleTitle(choice), systemImage: "checkmark") }
                    else { Text(scaleTitle(choice)) }
                }
            }
        } label: {
            Text("\(service.scale)×")
                .font(ZenithType.mono(11, weight: .semibold))
                .foregroundStyle(service.scaleChoice == .automatic ? ZenithIsland.primary : Tint.scale)
                .frame(width: Self.tile, height: Self.tile)
                .background(service.scaleChoice == .automatic ? Color.clear : ZenithIsland.tileFill(Tint.scale, contrast: contrast),
                            in: RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(text.scale)
    }

    private var separator: some View {
        Rectangle()
            .fill(ZenithIsland.divider(contrast))
            .frame(width: 0.75, height: 18)
            .padding(.horizontal, 2)
    }

    private func tile(symbol: String, tint: Color?, active: Bool, help: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? (tint ?? ZenithIsland.primary) : ZenithIsland.primary.opacity(0.82))
                .frame(width: Self.tile, height: Self.tile)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
                    if active, let tint {
                        shape.fill(ZenithIsland.tileFill(tint, contrast: contrast))
                            .overlay(shape.strokeBorder(ZenithIsland.tileStroke(tint, contrast: contrast), lineWidth: 0.75))
                    } else {
                        shape.fill(Color.white.opacity(0.001))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(DesignOverlayPressStyle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    // MARK: Words and glyphs

    private static func symbol(_ blend: DesignOverlayBlend) -> String {
        switch blend {
        case .normal: return "photo"
        case .difference: return "minus.square"
        case .invert: return "circle.righthalf.filled"
        }
    }

    private func title(_ blend: DesignOverlayBlend) -> String {
        switch blend {
        case .normal: return text.normal
        case .difference: return text.difference
        case .invert: return text.invert
        }
    }

    private func scaleTitle(_ choice: DesignOverlayScaleChoice) -> String {
        switch choice {
        case .automatic: return "\(text.automatic) (\(service.detectedScale)×)"
        case .x1: return "1×"
        case .x2: return "2×"
        case .x3: return "3×"
        }
    }
}

extension DesignOverlayService.Feedback {
    func text(_ strings: ZenithDesignOverlayStrings) -> String {
        switch self {
        case .alignedPage: return strings.alignedPage
        case .alignedWindow: return strings.alignedWindow
        case .noWindow: return strings.noWindow
        case .noImage: return strings.noImage
        case .needsScreenRecording: return strings.needsScreenRecording
        }
    }

    var isWarning: Bool { self == .noWindow || self == .noImage || self == .needsScreenRecording }
}

/// The capsule rises in from a soft blur on the island's spring, and leaves
/// the same way, faster. Reduce Motion leaves a fade.
private struct DesignOverlayHUDEntrance: ViewModifier {
    let shown: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let moving = !reduceMotion && !shown
        content
            .offset(y: moving ? 8 : 0)
            .scaleEffect(moving ? ZenithMorph.scale : 1)
            .blur(radius: moving ? ZenithMorph.blur : 0)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: ZenithMotion.fast)
                       : shown ? ZenithMorph.animation : .easeIn(duration: ZenithMotion.fast * 0.8),
                       value: shown)
    }
}

/// Press down fast to 0.94, spring back on release.
private struct DesignOverlayPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ZenithMotion.pressedScale : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(configuration.isPressed ? ZenithMotion.press : ZenithMorph.animation,
                       value: configuration.isPressed)
    }
}

/// A transparent strip that drags the HUD's window, the way a title bar does.
private struct DesignOverlayDragArea: NSViewRepresentable {
    let tooltip: String

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.toolTip = tooltip
        return view
    }

    func updateNSView(_ view: DragView, context: Context) {
        view.toolTip = tooltip
    }

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.makeKey()
            window?.performDrag(with: event)
        }
    }
}
