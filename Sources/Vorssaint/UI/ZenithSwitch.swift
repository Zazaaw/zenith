// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith's switch: its label, if shown, then an accent capsule when on and a
/// grey one when off, with a white knob on the Style Kit's toggle curve.
/// Drawn in SwiftUI, never AppKit's NSSwitch (see `ZenithSwitchRow`).
///
/// A custom style is handed the label whatever `labelsHidden()` says, so the
/// style reads the label visibility itself: a row that draws its own title
/// and hides the switch's label would otherwise show the title twice.
struct ZenithSwitchStyle: ToggleStyle {
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 15.0, *) {
            ZenithSwitchStyleBody(configuration: configuration)
        } else {
            zenithSwitchBody(configuration, showsLabel: true)
        }
    }
}

/// The style's body, with the label shown only while labels are visible.
@available(macOS 15.0, *)
private struct ZenithSwitchStyleBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.labelsVisibility) private var labelsVisibility

    var body: some View {
        zenithSwitchBody(configuration, showsLabel: labelsVisibility != .hidden)
    }
}

/// The label (when shown) and the switch. VoiceOver reads it as the system
/// switch with its label either way, so a hidden title is still spoken.
/// Before macOS 15 the visibility cannot be read and the label shows, as it
/// always did; rows that draw their own title use `ZenithSwitch` directly.
@MainActor @ViewBuilder
private func zenithSwitchBody(_ configuration: ToggleStyleConfiguration, showsLabel: Bool) -> some View {
    HStack(spacing: 8) {
        if showsLabel { configuration.label }
        ZenithSwitch(isOn: configuration.$isOn)
    }
    .accessibilityRepresentation {
        Toggle(isOn: configuration.$isOn) { configuration.label }
    }
}

/// The capsule and knob, with the disabled look and keyboard toggling.
struct ZenithSwitch: View {
    @Binding var isOn: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.16)))
            Circle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                .padding(2)
        }
        .frame(width: 34, height: 20)
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Capsule())
        .onTapGesture { if isEnabled { isOn.toggle() } }
        .focusable(isEnabled)
        .onKeyPress(.space) {
            guard isEnabled else { return .ignored }
            isOn.toggle()
            return .handled
        }
        .animation(ZenithMotion.respecting(ZenithMotion.toggle()), value: isOn)
    }
}
