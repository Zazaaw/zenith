// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the menu bar hider's section on Settings → Menu bar, below
/// the panel and icon card. Every switch is a `ZenithSwitchRow`; the heading
/// is drawn here, and the Menu bar search item carries its words.
struct MenuBarHiderSettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = MenuBarHiderService.shared
    @AppStorage(DefaultsKey.menuBarHiderEnabled) private var enabled = false
    @AppStorage(DefaultsKey.menuBarHiderAlwaysHidden) private var alwaysHidden = false
    @AppStorage(DefaultsKey.menuBarHiderDelay) private var delay = MenuBarHiderDelay.standard.rawValue
    @AppStorage(DefaultsKey.menuBarHiderCollapseOnClick) private var collapseOnClick = true
    @AppStorage(DefaultsKey.menuBarHiderShowOnHover) private var showOnHover = false
    @AppStorage(DefaultsKey.menuBarHiderNotchGuard) private var notchGuard = true
    @AppStorage(DefaultsKey.menuBarHiderShortcutEnabled) private var shortcutOn = false

    private var text: ZenithMenuBarHiderStrings { ZenithStrings.menuBarHider(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                heading(text.title)
                SettingsCard {
                    ZenithSwitchRow(text.enable, isOn: $enabled) {
                        label(text.enable, caption: text.enableCaption)
                    }
                    if enabled {
                        ForEach(service.blockers, id: \.self) { blocker in
                            notice(message(for: blocker))
                        }
                        Divider()
                        options
                    }
                }
            }
            if enabled {
                VStack(alignment: .leading, spacing: 10) {
                    heading(text.howTo)
                    SettingsCard {
                        MenuBarHiderIllustration(alwaysHidden: alwaysHidden)
                        VStack(alignment: .leading, spacing: 8) {
                            step("command", text.stepDrag)
                            step("cursorarrow.click", text.stepClick)
                            if alwaysHidden { step("option", text.stepAlways) }
                        }
                    }
                }
            }
        }
        .animation(ZenithMotion.respecting(ZenithMotion.reveal()), value: enabled)
        .animation(ZenithMotion.respecting(ZenithMotion.reveal()), value: alwaysHidden)
        .onChange(of: enabled) { _, _ in service.syncWithPreferences() }
        .onChange(of: alwaysHidden) { _, _ in service.syncWithPreferences() }
        .onChange(of: delay) { _, _ in service.syncWithPreferences() }
        .onChange(of: collapseOnClick) { _, _ in service.syncWithPreferences() }
        .onChange(of: showOnHover) { _, _ in service.syncWithPreferences() }
        .onChange(of: notchGuard) { _, _ in service.syncWithPreferences() }
        .onChange(of: shortcutOn) { _, _ in service.syncWithPreferences() }
    }

    @ViewBuilder
    private var options: some View {
        ZenithSwitchRow(text.alwaysHidden, isOn: $alwaysHidden) {
            label(text.alwaysHidden, caption: text.alwaysHiddenCaption)
        }
        HStack(spacing: 12) {
            label(text.delay, caption: text.delayCaption)
            Spacer(minLength: 12)
            Picker(text.delay, selection: $delay) {
                ForEach(MenuBarHiderDelay.allCases) { choice in
                    Text(delayTitle(choice)).tag(choice.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        ZenithSwitchRow(text.clickOutside, isOn: $collapseOnClick) {
            Text(text.clickOutside)
        }
        ZenithSwitchRow(text.hover, isOn: $showOnHover) {
            label(text.hover, caption: text.hoverCaption)
        }
        if MenuBarHiderSystemSensing.hasNotchedScreen {
            ZenithSwitchRow(text.notch, isOn: $notchGuard) {
                label(text.notch, caption: text.notchCaption)
            }
            .disabled(!alwaysHidden)
            if !service.behindNotch.isEmpty {
                Text(String(format: text.behindNotch, service.behindNotch.joined(separator: ", ")))
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        Divider()
        ZenithSwitchRow(text.shortcutToggle, isOn: $shortcutOn) {
            Text(text.shortcutToggle)
        }
        if shortcutOn {
            ShortcutPreferenceRow(role: .menuBarHider, isEnabled: shortcutOn, label: text.shortcut) {
                service.syncShortcut()
            }
            if service.shortcutRegistrationFailed {
                Text(text.shortcutFailed)
                    .font(ZenithType.caption)
                    .foregroundStyle(ZenithStatus.warning)
            }
        }
    }

    private func delayTitle(_ choice: MenuBarHiderDelay) -> String {
        choice == .never ? text.never : String(format: text.secondsFormat, choice.rawValue)
    }

    private func message(for blocker: MenuBarHiderBlocker) -> String {
        switch blocker {
        case .iconInside: return text.iconInside
        case .chevronInside: return text.chevronInside
        case .alwaysOutside: return text.alwaysOutside
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(ZenithType.sectionTitle)
            .tracking(ZenithType.sectionTitleTracking)
            .padding(.leading, 2)
            .accessibilityAddTraits(.isHeader)
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption)
                .font(ZenithType.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Something keeps the bar from hiding; amber, with words, never color alone.
    private func notice(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ZenithStatus.warning)
            Text(message)
                .font(ZenithType.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZenithStatus.fill(ZenithStatus.warning),
                    in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
            .strokeBorder(ZenithStatus.stroke(ZenithStatus.warning)))
    }

    private func step(_ symbol: String, _ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(message)
                .font(ZenithType.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A small menu bar with one icon being ⌘-dragged from the visible icons
/// left across the divider, into the hidden section. Loops gently while it
/// is on screen; Reduce Motion shows it at rest, the icon already across.
struct MenuBarHiderIllustration: View {
    let alwaysHidden: Bool
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: ZenithMenuBarHiderStrings { ZenithStrings.menuBarHider(l10n.language) }

    private static let slot: CGFloat = 22
    private static let iconSymbols = ["wifi", "battery.75percent", "magnifyingglass"]
    private static let cycle: TimeInterval = 3.6

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if reduceMotion {
                bar(progress: 1, opacity: 1)
            } else {
                TimelineView(.animation) { context in
                    let (progress, opacity) = Self.pose(at: context.date.timeIntervalSinceReferenceDate)
                    bar(progress: progress, opacity: opacity)
                }
            }
            HStack(spacing: 0) {
                // Each word starts or ends at the divider, however long it runs.
                Text(text.hiddenLabel)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: leading + Self.slot * 1.2, alignment: .trailing)
                Text(text.visibleLabel)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, Self.slot * 0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(ZenithType.mono(10, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
        }
        .fixedSize()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.stepDrag)
    }

    /// Rest, drag across on the Style Kit spring, rest, then fade back.
    static func pose(at time: TimeInterval) -> (progress: Double, opacity: Double) {
        let phase = time.truncatingRemainder(dividingBy: cycle)
        switch phase {
        case ..<1.0: return (0, 1)
        case ..<1.8: return (MenuBarHiderGlyphMotion.progress((phase - 1.0) / 0.8), 1)
        case ..<3.2: return (1, 1)
        case ..<3.4: return (1, 1 - (phase - 3.2) / 0.2)
        default: return (0, (phase - 3.4) / 0.2)
        }
    }

    /// Where the hidden section's first gap starts.
    private var leading: CGFloat { (alwaysHidden ? Self.slot * 1.6 : 0) + Self.slot }

    /// `progress` 0 has the dragged icon among the visible ones, 1 left of the divider.
    private func bar(progress: Double, opacity: Double) -> some View {
        let slot = Self.slot
        let settled = min(max(progress, 0), 1)
        return HStack(spacing: 0) {
            if alwaysHidden {
                placeholder.frame(width: slot)
                Image(nsImage: MenuBarHiderGlyph.alwaysDivider())
                    .renderingMode(.template)
                    .frame(width: slot * 0.6)
            }
            placeholder.frame(width: slot)
            // The gaps the dragged icon leaves and lands in.
            Color.clear.frame(width: slot * settled)
            Image(nsImage: MenuBarHiderGlyph.divider())
                .renderingMode(.template)
                .frame(width: slot * 0.6)
            Image(nsImage: MenuBarHiderGlyph.chevron(angle: 0))
                .renderingMode(.template)
                .frame(width: slot)
            BrandMark(width: 15)
                .frame(width: slot)
            Color.clear.frame(width: slot * (1 - settled))
            ForEach(Self.iconSymbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: slot)
            }
        }
        .foregroundStyle(.primary.opacity(0.8))
        .frame(height: 26)
        .overlay(alignment: .leading) {
            dragged.offset(x: leading + slot * 2.6 * (1 - progress)).opacity(opacity)
        }
        .padding(.horizontal, 10)
        .background(ZenithSurface.tileFill, in: Capsule())
        .overlay(Capsule().strokeBorder(ZenithSurface.hairline))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.primary.opacity(0.35))
            .frame(width: 12, height: 12)
    }

    /// The icon in the pointer's grip, with the ⌘ key held beside it.
    private var dragged: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 12, height: 12)
                .frame(width: Self.slot, height: 26)
            Text(verbatim: "⌘")
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(.background, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(ZenithSurface.hairline))
                .offset(x: 6, y: -6)
        }
    }
}
