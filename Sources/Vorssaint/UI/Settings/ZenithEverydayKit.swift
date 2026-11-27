// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: small pieces the Everyday and Devices pages share on top of
// the Settings kit (docs/SETTINGS-KIT.md).

/// A missing permission, while it is missing: the kit's warning section with
/// the shared `PermissionRow` (which asks, opens System Settings and notices
/// the grant), and the line that says what else the feature will ask for.
struct ZenithPermissionSection: View {
    let kind: PermissionKind
    var note: String?
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ZenithSection(l10n.s.permissionRequired, footer: note) {
            PermissionRow(kind: kind).padding(.vertical, 8)
        }
    }
}

/// A numbered step: the number in a quiet circle, then what to do.
struct ZenithStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: "\(number)")
                .font(ZenithType.mono(10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(ZenithSurface.tileFill))
                .overlay(Circle().strokeBorder(ZenithSurface.tileStroke))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
            Text(text)
                .font(ZenithType.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

/// A line of state inside a section (active now, what was just removed):
/// a status glyph and a short caption.
struct ZenithRowStatus: View {
    let text: String
    var symbol = "checkmark.circle.fill"
    var color: Color = ZenithStatus.success

    var body: some View {
        Label(text, systemImage: symbol)
            .font(ZenithType.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
    }
}

/// The page column every kit page scrolls: 760 pt at most, centred.
struct ZenithPageColumn<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
    }
}
