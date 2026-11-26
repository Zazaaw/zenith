// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the pieces of Orbit, the store-like Features page: an item's
// icon, its row and capsule button, the shelf chips, the banner and the
// detail sheet. The page itself (FeatureHubSettings) decides what they show.

/// An item's art, scaled from the kit's 100 pt canvas.
struct OrbitItemIcon: View {
    let name: String
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let icon = OrbitIcons.named(name) {
                OrbitIconView(icon: icon)
            } else {
                OrbitIconBase()
            }
        }
        .frame(width: 100, height: 100)
        .scaleEffect(size / 100)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Get, Open or a greyed Get, as the App Store draws them.
struct OrbitCapsuleButton: View {
    let kind: OrbitButton
    let title: String
    var prominent = false
    var warns = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if warns {
                    Circle().fill(ZenithStatus.warning).frame(width: 6, height: 6)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(minWidth: 62, minHeight: 24)
            .foregroundStyle(foreground)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(kind == .unavailable)
    }

    private var foreground: Color {
        if prominent { return .white }
        switch kind {
        case .get: return .accentColor
        case .open: return .primary
        case .unavailable: return .secondary
        }
    }

    private var fill: Color {
        if prominent { return .accentColor }
        return kind == .get ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.08)
    }
}

/// One catalog row: the icon, name and one line, and the capsule. The row
/// opens the item's details; the capsule acts.
struct OrbitStoreRow: View {
    let item: OrbitItem
    let state: OrbitItemState
    let badge: String?
    let onDetails: () -> Void
    let onAction: () -> Void
    let onTurnOff: (() -> Void)?
    @State private var hovering = false

    private var text: ZenithOrbitStrings { ZenithStrings.orbit }
    private var name: String { text.name(item.id) }
    private var button: OrbitButton { OrbitCatalog.button(for: state) }

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onDetails) {
                HStack(spacing: 11) {
                    OrbitItemIcon(name: item.iconName, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            if let badge { OrbitBadge(title: badge) }
                        }
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(needsPermission ? AnyShapeStyle(ZenithStatus.warning)
                                                             : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name). \(subtitle). \(stateLabel)")
            .accessibilityHint(text.showsDetails)
            OrbitCapsuleButton(kind: button, title: title(for: button), warns: needsPermission, action: onAction)
                .help(helpText)
                .accessibilityLabel("\(title(for: button)) \(name)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
            .fill(hovering ? Color.primary.opacity(0.04) : .clear))
        .overlay(alignment: .bottom) {
            Rectangle().fill(ZenithSurface.hairline).frame(height: 0.5).padding(.leading, 55)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button(text.details, action: onDetails)
            if button != .unavailable { Button(title(for: button), action: onAction) }
            if let onTurnOff, state.isOn { Divider(); Button(text.turnOff, action: onTurnOff) }
        }
    }

    private var needsPermission: Bool {
        if case .needsPermission = state { return true }
        return false
    }

    private var subtitle: String {
        if case .needsPermission(let permissions) = state, let first = permissions.first {
            return String(format: text.needsFormat, first.name(FeatureStrings.hub(L10n.shared.language)))
        }
        return text.summary(item.id)
    }

    private var stateLabel: String {
        switch state {
        case .on: return text.stateOn
        case .off: return text.stateOff
        case .needsPermission: return text.stateNeedsPermission
        case .unsupported(let reason): return reason
        }
    }

    private var helpText: String {
        if case .unsupported(let reason) = state { return reason }
        return ""
    }

    private func title(for button: OrbitButton) -> String {
        button == .open ? text.open : text.get
    }
}

struct OrbitBadge: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 8.5, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .foregroundStyle(ZenithStatus.warning)
            .background(Capsule().fill(ZenithStatus.fill(ZenithStatus.warning)))
            .accessibilityHidden(true)
    }
}

/// A shelf chip.
struct OrbitChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.06)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Lays chips out in rows, wrapping when the page is narrow.
struct OrbitFlowLayout: Layout {
    var spacing: CGFloat = 6

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

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// The banner at the top of All: one featured item on a gradient.
struct OrbitHeroBanner: View {
    let item: OrbitItem
    let state: OrbitItemState
    let onAction: () -> Void
    let onDetails: () -> Void

    private var text: ZenithOrbitStrings { ZenithStrings.orbit }
    private static let deep = Color(red: 0.36, green: 0.22, blue: 0.75)

    var body: some View {
        let button = OrbitCatalog.button(for: state)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Self.deep, Color(red: 0.1, green: 0.42, blue: 0.95)],
                           startPoint: .leading, endPoint: .trailing)
            orbitArt
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text.featured.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(text.name(item.id))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text(text.heroText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 380, alignment: .leading)
                Spacer(minLength: 12)
                Button(action: onAction) {
                    Text(button == .open ? text.open : text.get)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Self.deep)
                        .padding(.horizontal, 18)
                        .frame(height: 28)
                        .background(Capsule().fill(.white))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(button == .unavailable)
                .accessibilityLabel("\(button == .open ? text.open : text.get) \(text.name(item.id))")
            }
            .padding(18)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onDetails)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(text.featured): \(text.name(item.id)). \(text.heroText)")
    }

    /// The item's icon, large, on faint orbits, with the sound of a call
    /// drawn as bars behind it. Still: nothing moves.
    private var orbitArt: some View {
        ZStack {
            HStack(spacing: 3) {
                ForEach(0..<26, id: \.self) { index in
                    Capsule().fill(.white.opacity(0.28))
                        .frame(width: 4, height: 10 + abs(sin(Double(index) * 0.55)) * 56)
                }
            }
            .offset(x: -40)
            ForEach([150.0, 230.0], id: \.self) { diameter in
                Ellipse().stroke(.white.opacity(0.16), lineWidth: 1.2)
                    .frame(width: diameter, height: diameter * 0.42)
                    .rotationEffect(.degrees(-14))
            }
            .offset(x: 70)
            OrbitItemIcon(name: item.iconName, size: 76)
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                .offset(x: 70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 150)
        .accessibilityHidden(true)
    }
}

/// A capsule search field with a clear button. Escape clears it.
struct OrbitSearchField: View {
    @Binding var query: String
    let placeholder: String
    let clearTitle: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused(focus)
                .onExitCommand { query = "" }
                .accessibilityLabel(placeholder)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearTitle)
            }
        }
        .padding(.horizontal, 11)
        .frame(width: 210, height: 30)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(focus.wrappedValue ? 0.18 : 0.06), lineWidth: 0.5))
    }
}

// MARK: - Detail sheet

struct OrbitDetailSheet: View {
    let item: OrbitItem
    let state: OrbitItemState
    let onAction: () -> Void
    let onTurnOff: (() -> Void)?
    let onDone: () -> Void
    @ObservedObject private var l10n = L10n.shared

    private var text: ZenithOrbitStrings { ZenithStrings.orbit }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    var body: some View {
        let button = OrbitCatalog.button(for: state)
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 16) {
                        OrbitItemIcon(name: item.iconName, size: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text.name(item.id))
                                .font(.system(size: 22, weight: .bold))
                                .accessibilityAddTraits(.isHeader)
                            Text(text.category(item.category))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                OrbitCapsuleButton(kind: button, title: button == .open ? text.open : text.get,
                                                   prominent: button == .get, action: onAction)
                                if let onTurnOff, state.isOn {
                                    OrbitCapsuleButton(kind: .open, title: text.turnOff, action: onTurnOff)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    Text(description)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                    notes
                    if !item.permissions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(text.permissions)
                                .font(.system(size: 13, weight: .semibold))
                            PermissionsPortalSections(hub: hub, visiblePermissions: item.permissions)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button(text.done, action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 480, height: 520)
        .onExitCommand(perform: onDone)
    }

    private var description: String {
        if let feature = item.feature { return feature.hubDescription(hub) }
        return Self.pageDescription(item.page, language: l10n.language)
    }

    /// The subtitle each Zenith page already shows under its title.
    static func pageDescription(_ page: SettingsPage?, language: AppLanguage) -> String {
        switch page {
        case .lockScreen?: return ZenithStrings.lockScreenPage(language).subtitle
        case .meetings?: return ZenithStrings.meetings(language).subtitle
        case .translate?: return ZenithStrings.translate(language).subtitle
        case .workspaces?: return ZenithStrings.workspaces(language).subtitle
        case .pocket?: return ZenithStrings.pocket(language).subtitle
        case .remote?: return ZenithStrings.remote(language).subtitle
        case .batteries?: return ZenithStrings.batteries(language).subtitle
        case .faceUnlock?: return ZenithStrings.faceUnlock(language).subtitle
        default: return ""
        }
    }

    @ViewBuilder
    private var notes: some View {
        let lines = noteLines
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noteLines: [String] {
        var lines: [String] = []
        if case .unsupported(let reason) = state { lines.append(reason) }
        if let required = item.requires, !required.isAvailable {
            lines.append(String(format: text.alsoAddsFormat, text.name(.feature(required))))
        }
        if let feature = item.feature {
            lines.append("\(text.runs): \(energyLabel(feature.energyProfile))")
            lines.append(text.keepsSettings)
        } else {
            lines.append(item.switchKey == nil ? text.partOfZenith : text.turnsOnInPage)
        }
        return lines
    }

    private func energyLabel(_ profile: FeatureEnergyProfile) -> String {
        switch profile {
        case .idle: return hub.energyIdle
        case .mouse: return hub.energyMouse
        case .pointer: return hub.energyPointer
        case .keyboard: return hub.energyKeyboard
        case .inputs: return hub.energyInputs
        case .periodic: return hub.energyPeriodic
        }
    }
}
