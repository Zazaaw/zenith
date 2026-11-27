// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the kit's notes: a callout for something the person must
// know or do (a permission, a problem, a success), and a footnote for the
// quiet line under a section (a credit, where a setting moved).

/// A status message in the Style Kit's form: the status colour's 10% fill,
/// 20% border and full-strength icon, with optional actions.
///
///     ZenithCallout(.warning, "Input Monitoring is off for Zenith…") {
///         Button("Open Input Monitoring") { … }
///     }
///     ZenithCallout(.success, title: "Paired", "Your iPhone is connected.")
struct ZenithCallout<Actions: View>: View {
    enum Status {
        case info, warning, error, success

        var color: Color {
            switch self {
            case .info: return ZenithStatus.info
            case .warning: return ZenithStatus.warning
            case .error: return ZenithStatus.error
            case .success: return ZenithStatus.success
            }
        }

        var symbol: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }

    let status: Status
    var title: String?
    let text: String
    let actions: Actions
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ status: Status, title: String? = nil, _ text: String, @ViewBuilder actions: () -> Actions) {
        self.status = status
        self.title = title
        self.text = text
        self.actions = actions()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithKitSurface.groupRadius, style: .continuous)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.symbol)
                .font(.system(size: 14))
                .foregroundStyle(status.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title).font(ZenithType.emphasis)
                    }
                    Text(text)
                        .font(ZenithType.footnote)
                        .foregroundStyle(title == nil ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZenithStatus.fill(status.color), in: shape)
        .overlay(shape.strokeBorder(status.color.opacity(contrast == .increased ? 0.6 : 0.2)))
        .accessibilityElement(children: .contain)
    }
}

extension ZenithCallout where Actions == EmptyView {
    init(_ status: Status, title: String? = nil, _ text: String) {
        self.init(status, title: title, text) { EmptyView() }
    }
}

/// The quiet line under a section: a credit, where a setting moved.
///
///     ZenithFootnote("Theme and Liquid Glass moved to Appearance.")
struct ZenithFootnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 4)
    }
}
