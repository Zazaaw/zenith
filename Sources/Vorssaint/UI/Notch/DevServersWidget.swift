// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Dev servers widget for Customize Home. Up to three
/// running servers, each a green dot, the project and `localhost:3000` in
/// mono; how many run in its heading; a click opens the page. While it shows,
/// the servers are looked at as often as on the page.
struct DevServersHomeWidget: View {
    let service: NotchService
    @ObservedObject private var servers = DevServersService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let shown = 3

    private var text: ZenithDevServersStrings { ZenithStrings.devServers(l10n.language) }

    var body: some View {
        let list = Array(servers.servers.prefix(Self.shown))
        ZenithHomeOpenButton(action: { service.select(.devServers) }) {
            VStack(alignment: .leading, spacing: 5) {
                ZenithHomeWidgetHeader(widget: .devServers, title: text.title) {
                    if !servers.servers.isEmpty {
                        Text("\(servers.servers.count)")
                            .font(ZenithType.mono(10, weight: .semibold))
                            .foregroundStyle(ZenithIsland.meta)
                            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(servers.servers.count)))
                    }
                }
                if list.isEmpty {
                    Text(servers.hasLoaded ? text.empty : " ")
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(list) { server in
                            row(server)
                                .transition(DevServersMotion.row(reduceMotion: reduceMotion))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(DevServersMotion.list(reduceMotion: reduceMotion), value: list.map(\.id))
        }
        .onAppear { servers.shown() }
        .onDisappear { servers.hidden() }
    }

    private func row(_ server: DevServer) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ZenithStatus.success)
                .frame(width: 5, height: 5)
            Text(server.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            Text(server.host)
                .font(ZenithType.mono(9.5))
                .foregroundStyle(ZenithIsland.meta)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 13)
        .accessibilityElement(children: .combine)
    }
}
