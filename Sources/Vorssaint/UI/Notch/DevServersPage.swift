// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Dev servers page in the open island. One row per server
// on a soft card: the framework's monogram on its tinted tile, the project,
// the framework and `localhost:3000` in mono, the uptime ticking in a slot of
// fixed width, and Open, Copy URL and Kill (a second click on "Kill?"
// stops it). Rows come and go with a spring and a blur; the page's states
// swap through the island's morph. Transform, opacity and blur only, so
// nothing lays out again while it moves; Reduce Motion fades.

struct DevServersPage: View {
    let size: CGSize
    @ObservedObject private var service = DevServersService.shared
    @ObservedObject private var l10n = L10n.shared

    private var text: ZenithDevServersStrings { ZenithStrings.devServers(l10n.language) }

    private enum Stage: Hashable { case loading, empty, list }

    private var stage: Stage {
        !service.hasLoaded ? .loading : service.servers.isEmpty ? .empty : .list
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .top)
            .zenithMorph(on: stage)
            .onAppear { service.shown() }
            .onDisappear {
                service.hidden()
                service.cancelKill()
            }
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .loading:
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            DevServersEmpty(text: text)
        case .list:
            DevServersList(servers: service.servers, text: text)
        }
    }
}

// MARK: Motion

enum DevServersMotion {
    /// Rows entering, leaving and closing ranks.
    static func list(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: ZenithMotion.fast) : ZenithMorph.animation
    }

    /// A row rises 8 points out of a blur as it arrives, and blurs out a
    /// little smaller as it leaves; under Reduce Motion it only fades.
    static func row(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: DevServersRowEffect(amount: 1, rise: 8), identity: DevServersRowEffect(amount: 0, rise: 8)),
            removal: .modifier(active: DevServersRowEffect(amount: 1, rise: 0), identity: DevServersRowEffect(amount: 0, rise: 0)))
    }

    /// A small swap inside a row, such as Kill turning into "Kill?".
    static func swap(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeInOut(duration: ZenithMotion.fast) : .spring(response: 0.3, dampingFraction: 0.82)
    }
}

private struct DevServersRowEffect: ViewModifier {
    let amount: CGFloat
    let rise: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: 8 * amount)
            .opacity(Double(1 - amount))
            .scaleEffect(1 - 0.04 * amount)
            .offset(y: rise * amount)
    }
}

// MARK: Pieces

/// The framework's monogram on a tile of its colour, as the island's module
/// tiles are drawn. No brand artwork.
struct DevServerTile: View {
    let server: DevServer
    var size: CGFloat = 30
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let tint = ZenithIslandPalette.color(hex: server.kind.hex)
        let shape = RoundedRectangle(cornerRadius: (size * 0.3).rounded(), style: .continuous)
        let monogram = server.monogram
        Text(monogram)
            .font(.system(size: (size * (monogram.count > 1 ? 0.36 : 0.46)).rounded(), weight: .bold, design: .rounded))
            .tracking(monogram.count > 1 ? -0.3 : 0)
            .foregroundStyle(tint)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background(ZenithIsland.tileFill(tint, contrast: contrast), in: shape)
            .overlay {
                shape.strokeBorder(ZenithIsland.tileStroke(tint, contrast: contrast), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }
}

/// How long the server has run, in mono, its digits rolling, in a slot as
/// wide as the widest reading of its shape so the row never shifts.
struct DevServerUptime: View {
    let startedAt: Date?
    var size: CGFloat = 10.5
    /// VoiceOver's words, `%@` the reading, as in “Running for 12:03”.
    var accessibilityFormat = "%@"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let startedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                let seconds = max(0, context.date.timeIntervalSince(startedAt))
                let reading = DevServersFormat.uptime(seconds)
                Text(reading)
                    .font(ZenithType.mono(size))
                    .foregroundStyle(ZenithIsland.meta)
                    .lineLimit(1)
                    .contentTransition(reduceMotion ? .opacity : .numericText())
                    .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: reading)
                    .frame(width: DevServersMetrics.width(DevServersFormat.uptimeTemplate(seconds), size: size),
                           alignment: .trailing)
                    .accessibilityLabel(accessibilityFormat.replacingOccurrences(of: "%@", with: reading))
            }
        }
    }
}

enum DevServersMetrics {
    /// A row on the page.
    static let rowHeight: CGFloat = 48
    /// Open, Copy URL and Kill side by side, which "Kill?" covers.
    static let actionsWidth: CGFloat = 28 * 3 + 2 * 2

    static func width(_ text: String, size: CGFloat) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }
}

private struct DevServersEmpty: View {
    let text: ZenithDevServersStrings

    var body: some View {
        VStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: NotchModule.devServers.zenithIconSymbol, tint: NotchModule.devServers.zenithTint,
                                  size: 44)
            Text(text.empty)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
            Text(text.emptyHint)
                .font(.system(size: 11.5))
                .foregroundStyle(ZenithIsland.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: List

private struct DevServersList: View {
    let servers: [DevServer]
    let text: ZenithDevServersStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(servers) { server in
                    DevServerRow(server: server, text: text)
                        .transition(DevServersMotion.row(reduceMotion: reduceMotion))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(DevServersMotion.list(reduceMotion: reduceMotion), value: servers.map(\.id))
    }
}

private struct DevServerRow: View {
    let server: DevServer
    let text: ZenithDevServersStrings
    @ObservedObject private var service = DevServersService.shared

    var body: some View {
        HStack(spacing: 10) {
            DevServerTile(server: server)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.title)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    if server.project != nil {
                        Text(server.framework)
                            .font(.system(size: 11))
                            .foregroundStyle(ZenithIsland.secondary)
                    }
                    Text(server.host)
                        .font(ZenithType.mono(10.5))
                        .foregroundStyle(ZenithIsland.secondary)
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DevServerUptime(startedAt: server.startedAt, accessibilityFormat: text.runningFor)
            DevServerActions(server: server, text: text)
        }
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .frame(height: DevServersMetrics.rowHeight)
        .zenithIslandSoftCard(cornerRadius: 14)
        .contentShape(Rectangle())
        .contextMenu {
            Button(text.open) { service.open(server) }
            Button(text.copyURL) { service.copyURL(server) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel([server.title, server.project == nil ? nil : server.framework, server.host]
            .compactMap { $0 }.joined(separator: ", "))
    }
}

/// Open, Copy URL and Kill. A first click on Kill turns the three into one
/// red "Kill?" over the same place, which a second click confirms; Open and
/// Copy blur away under it, so the row's layout never moves.
private struct DevServerActions: View {
    let server: DevServer
    let text: ZenithDevServersStrings
    @ObservedObject private var service = DevServersService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let confirming = service.kill.isConfirming(server.id, now: ProcessInfo.processInfo.systemUptime)
        let stopping = service.kill.isStopping(server.id)
        let copied = service.copiedID == server.id
        ZStack(alignment: .trailing) {
            HStack(spacing: 2) {
                NotchIconButton(symbol: "arrow.up.right.square", title: text.open) { service.open(server) }
                NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", title: copied ? text.copied : text.copyURL) {
                    service.copyURL(server)
                }
                killButton(stopping: stopping)
                    .opacity(confirming ? 0 : 1)
            }
            .opacity(confirming ? 0 : 1)
            .blur(radius: confirming && !reduceMotion ? 6 : 0)
            .allowsHitTesting(!confirming)
            if confirming {
                Button { service.pressKill(server) } label: {
                    Text(text.confirmKill)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: DevServersMetrics.actionsWidth, minHeight: 26)
                        .background(Capsule().fill(ZenithStatus.error))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(text.kill)
                .accessibilityLabel(text.confirmKill)
                .transition(reduceMotion ? .opacity
                            : .scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: DevServersMetrics.actionsWidth, alignment: .trailing)
        .animation(DevServersMotion.swap(reduceMotion: reduceMotion), value: confirming)
        .animation(DevServersMotion.swap(reduceMotion: reduceMotion), value: stopping)
    }

    @ViewBuilder private func killButton(stopping: Bool) -> some View {
        if !server.kind.killable {
            Image(systemName: "shippingbox")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ZenithIsland.tertiary)
                .frame(width: 28, height: 28)
                .help(text.dockerOwned)
                .accessibilityLabel(text.dockerOwned)
        } else if stopping {
            ProgressView()
                .controlSize(.mini)
                .frame(width: 28, height: 28)
                .help(text.stopping)
                .accessibilityLabel(text.stopping)
                .transition(.opacity)
        } else {
            NotchIconButton(symbol: "xmark", title: text.kill) { service.pressKill(server) }
                .disabled(!server.canKill)
                .transition(.opacity)
        }
    }
}
