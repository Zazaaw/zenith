// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith's switch: its label, if shown, then an accent capsule when on and a
/// grey one when off, with a white knob on the Style Kit's toggle curve.
/// Drawn in SwiftUI, never AppKit's NSSwitch (see `ZenithSwitchRow`).
struct ZenithSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            ZenithSwitch(isOn: configuration.$isOn)
        }
        // VoiceOver reads it as the system switch, with its label.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
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
