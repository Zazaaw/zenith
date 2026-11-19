// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Settings chrome after p441z.my.id. A large title above
// the upstream form pages, the dot grid showing through, the brand under the
// sidebar, and the maker on the About page.

/// One Settings page: an optional large title, then the page itself, with the
/// form backgrounds cleared so the dot grid shows through.
struct ZenithSettingsPage<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                ZenithPageTitle(title: title)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .scrollContentBackground(.hidden)
        .headerProminence(.increased)
    }
}

/// The brand under the sidebar: the Satu Visual mark, the app and its version.
struct ZenithSidebarFooter: View {
    var body: some View {
        HStack(spacing: 9) {
            BrandBadge(size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppInfo.name).font(.system(size: 12, weight: .semibold))
                Text("v\(AppInfo.version) · \(AppInfo.maker)")
                    .font(ZenithType.mono(9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(ZenithSurface.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - About

/// Who makes Zenith. Public facts only, as on p441z.my.id.
enum ZenithMaker {
    static let name = "Faiz Hazim Hawari"
    static let handle = "p441z"
    static let portfolioURL = URL(string: "https://p441z.my.id")!
    static let links: [(title: String, url: URL)] = [
        ("GitHub", URL(string: "https://github.com/Zazaaw")!),
        ("Instagram", URL(string: "https://www.instagram.com/faizhazimhawarii")!),
        ("LinkedIn", URL(string: "https://www.linkedin.com/in/zazaaw/")!),
    ]

    static let photo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "zenith-maker", withExtension: "jpg",
                                        subdirectory: "Images") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

/// The maker's photo, name, line and bio, then the links.
struct ZenithMakerCard: View {
    let strings: ZenithMakerStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                photo
                VStack(alignment: .leading, spacing: 4) {
                    Text(ZenithMaker.name)
                        .font(.system(size: 21, weight: .bold))
                        .tracking(-0.5)
                    Text(strings.role)
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                    Text("@\(ZenithMaker.handle)")
                        .font(ZenithType.mono(11))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(strings.bio)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            ZenithFlowRow(spacing: 8) {
                ZenithLinkPill(title: strings.website, url: ZenithMaker.portfolioURL)
                ForEach(ZenithMaker.links, id: \.title) { link in
                    ZenithLinkPill(title: link.title, url: link.url)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ZenithSurface.cardFill, in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
            .strokeBorder(ZenithSurface.hairline))
    }

    @ViewBuilder
    private var photo: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Group {
            if let image = ZenithMaker.photo {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Text("F").font(.system(size: 30, weight: .bold)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ZenithSurface.tileFill)
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(shape)
        .overlay(shape.strokeBorder(ZenithSurface.tileStroke))
        .accessibilityLabel(ZenithMaker.name)
    }
}

/// A row on the About page like the résumé card on p441z.my.id: a tile, a
/// title over a muted line, and an arrow out.
struct ZenithLinkCard<Tile: View>: View {
    let title: String
    let caption: String
    let url: URL
    let tile: Tile
    @Environment(\.openURL) private var openURL
    @State private var hovering = false

    init(title: String, caption: String, url: URL, @ViewBuilder tile: () -> Tile) {
        self.title = title
        self.caption = caption
        self.url = url
        self.tile = tile()
    }

    var body: some View {
        Button { openURL(url) } label: {
            HStack(spacing: 14) {
                tile
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(hovering ? .primary : .secondary)
                    .offset(x: hovering ? 1.5 : 0, y: hovering ? -1.5 : 0)
            }
            .padding(14)
            .background(hovering ? ZenithSurface.tileFill : ZenithSurface.cardFill,
                        in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
                .strokeBorder(ZenithSurface.hairline))
            .contentShape(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(url.absoluteString)
    }
}

/// A small outlined link with an arrow, for the maker's profiles.
struct ZenithLinkPill: View {
    let title: String
    let url: URL
    @State private var hovering = false

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(hovering ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(hovering ? ZenithSurface.tileFill : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(ZenithSurface.tileStroke))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(url.absoluteString)
    }
}

/// Lays its children out left to right and wraps to the next line.
struct ZenithFlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
