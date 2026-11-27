// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: a page's sections and rows, after the approved mockups: the
// section's title outside a quiet grouped card, compact 40 pt rows split by
// inset hairlines, an ⓘ for each row's explanation.

// MARK: - Section

/// A titled group of rows.
///
///     ZenithSection("Typing", anchor: .myFeatureTyping,
///                   footer: "Password fields stay silent.") {
///         ZenithRow("Volume", value: $volume, in: 0...1, valueLabel: "65%")
///         ZenithRow("Key-up sounds", isOn: $keyUp, info: "Each key sounds again as it comes back up.")
///         ZenithMoreOptions(id: "mechakey", anchors: [.myFeatureRepeat]) { … }
///     }
///
/// Each child is one row: the section pads it to the rows' inset, gives it
/// at least 40 pt and draws the hairline between rows. Content that is not
/// a `ZenithRow` (a picker, a list) gets the same padding; give it its own
/// vertical padding if it is taller than a row. `anchor` makes the section a
/// Settings search destination; `footer` is a `ZenithFootnote` under the card.
struct ZenithSection<Content: View>: View {
    let title: String?
    var anchor: SettingsSectionAnchor?
    var footer: String?
    let content: Content

    init(_ title: String? = nil, anchor: SettingsSectionAnchor? = nil, footer: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.anchor = anchor
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        let section = VStack(alignment: .leading, spacing: 8) {
            if let title { ZenithSectionTitle(title) }
            ZenithRowStack { content }
                .zenithGroupBackground()
            if let footer { ZenithFootnote(footer) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if let anchor {
            section.zenithSectionAnchor(anchor, cornerRadius: ZenithKitSurface.groupRadius + 6, inset: 6)
        } else {
            section
        }
    }
}

// MARK: - Row stack

private struct ZenithFullBleedTrait: _ViewTraitKey {
    static let defaultValue = false
}

extension View {
    /// Tells a section this child pads itself to the card's edges (More options does).
    func zenithFullBleed() -> some View { _trait(ZenithFullBleedTrait.self, true) }
}

/// Lays out each child as a row: padded to the rows' inset, at least 40 pt
/// tall, a hairline between rows. The grouped card is the caller's.
struct ZenithRowStack<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        _VariadicView.Tree(Root()) { content }
    }

    private struct Root: _VariadicView_UnaryViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            let first = children.first?.id
            VStack(alignment: .leading, spacing: 0) {
                ForEach(children) { child in
                    if child.id != first { ZenithRowSeparator() }
                    if child[ZenithFullBleedTrait.self] {
                        child
                    } else {
                        child
                            .padding(.horizontal, ZenithKitSurface.rowInset)
                            .frame(maxWidth: .infinity, minHeight: ZenithKitSurface.rowHeight, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Row

/// One row: the title with its ⓘ, an essential line or a warning under it
/// when needed, and a control at the trailing edge.
///
///     ZenithRow("Key-up sounds", isOn: $keyUp, info: "Each key sounds again…")
///     ZenithRow("Language", selection: $language) { ForEach(…) { Text($0.name).tag($0) } }
///     ZenithRow("Volume", value: $volume, in: 0...1, valueLabel: "65%",
///               minimumSymbol: "speaker.fill", maximumSymbol: "speaker.wave.3.fill")
///     ZenithRow("Check every", value: $minutes, in: 1...60, format: { "\($0) min" })
///     ZenithRow("Turn sounds on or off", info: "…", warning: message) { ShortcutRecorderButton(…) }
///     ZenithRow("Feedback", info: "…", button: "Send Feedback…") { openFeedback() }
///     ZenithRow("Calendars", value: "3 of 5", navigate: { showCalendars = true })
///     ZenithRow("Anything", info: "…") { MyTrailingControl() }
///
/// - `info`: the explanation, behind the ⓘ (hover or click).
/// - `essential`: a line the person must read to use the row (a permission,
///   why it is off). Shown under the title. Use it rarely.
/// - `warning`: a problem with the row's value right now, under the title in
///   the warning colour (a shortcut another app holds).
struct ZenithRow<Trailing: View>: View {
    let title: String
    var info: String?
    var essential: String?
    var warning: String?
    var badge: String?
    var navigate: (() -> Void)?
    let trailing: Trailing

    init(_ title: String, info: String? = nil, essential: String? = nil, warning: String? = nil,
         badge: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.info = info
        self.essential = essential
        self.warning = warning
        self.badge = badge
        self.trailing = trailing()
    }

    var body: some View {
        if let navigate {
            Button(action: navigate) { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                ZenithRowLabel(title: title, info: info, essential: essential, badge: badge)
                if let warning, !warning.isEmpty {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(ZenithType.caption)
                        .foregroundStyle(ZenithStatus.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.vertical, 7)
    }
}

// MARK: Toggle

/// The row's switch; VoiceOver reads it by the row's title.
struct ZenithRowSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        ZenithSwitch(isOn: $isOn)
            .accessibilityRepresentation { Toggle(title, isOn: $isOn) }
    }
}

extension ZenithRow where Trailing == ZenithRowSwitch {
    /// A row with a switch.
    init(_ title: String, isOn: Binding<Bool>, info: String? = nil, essential: String? = nil,
         warning: String? = nil, badge: String? = nil) {
        self.init(title, info: info, essential: essential, warning: warning, badge: badge) {
            ZenithRowSwitch(title: title, isOn: isOn)
        }
    }
}

// MARK: Menu

/// The row's pop-up menu.
struct ZenithRowMenu<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    let options: Options

    var body: some View {
        Picker(title, selection: $selection) { options }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
    }
}

extension ZenithRow {
    /// A row with a pop-up menu of `options` (tagged views).
    init<Value: Hashable, Options: View>(_ title: String, selection: Binding<Value>, info: String? = nil,
                                         essential: String? = nil, badge: String? = nil,
                                         @ViewBuilder options: () -> Options)
        where Trailing == ZenithRowMenu<Value, Options> {
        let options = options()
        self.init(title, info: info, essential: essential, badge: badge) {
            ZenithRowMenu(title: title, selection: selection, options: options)
        }
    }
}

// MARK: Slider

/// The row's slider, with optional end symbols and a value label.
struct ZenithRowSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var valueLabel: String?
    var minimumSymbol: String?
    var maximumSymbol: String?
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 8) {
            if let minimumSymbol {
                Image(systemName: minimumSymbol).font(.system(size: 10)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            slider.frame(width: 180)
            if let maximumSymbol {
                Image(systemName: maximumSymbol).font(.system(size: 10)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            if let valueLabel {
                Text(valueLabel)
                    .font(ZenithType.figures(11.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 34, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel ?? "")
        } else {
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel ?? "")
        }
    }
}

extension ZenithRow where Trailing == ZenithRowSlider {
    /// A row with a slider. `valueLabel` shows the value in words ("65%").
    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil,
         info: String? = nil, essential: String? = nil, valueLabel: String? = nil,
         minimumSymbol: String? = nil, maximumSymbol: String? = nil,
         onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self.init(title, info: info, essential: essential) {
            ZenithRowSlider(title: title, value: value, range: range, step: step, valueLabel: valueLabel,
                            minimumSymbol: minimumSymbol, maximumSymbol: maximumSymbol,
                            onEditingChanged: onEditingChanged)
        }
    }
}

// MARK: Stepper

/// The row's stepper with its value in words.
struct ZenithRowStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let format: (Int) -> String

    var body: some View {
        HStack(spacing: 8) {
            Text(format(value))
                .font(ZenithType.figures(12.5, weight: .regular))
                .foregroundStyle(.secondary)
            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityRepresentation {
            Stepper(title, value: $value, in: range, step: step)
                .accessibilityValue(format(value))
        }
    }
}

extension ZenithRow where Trailing == ZenithRowStepper {
    /// A row with a stepper; `format` words the value ("15 min").
    init(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1,
         info: String? = nil, essential: String? = nil, format: @escaping (Int) -> String = { "\($0)" }) {
        self.init(title, info: info, essential: essential) {
            ZenithRowStepper(title: title, value: value, range: range, step: step, format: format)
        }
    }
}

// MARK: Button

/// The row's button.
struct ZenithRowButton: View {
    let label: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(label, role: role, action: action)
            .controlSize(.regular)
    }
}

extension ZenithRow where Trailing == ZenithRowButton {
    /// A row with a button at the trailing edge.
    init(_ title: String, info: String? = nil, essential: String? = nil, button: String,
         role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(title, info: info, essential: essential) {
            ZenithRowButton(label: button, role: role, action: action)
        }
    }
}

// MARK: Navigation

/// The chevron (and value) of a row that opens something: a sheet, a page.
struct ZenithRowChevron: View {
    var value: String?

    var body: some View {
        HStack(spacing: 6) {
            if let value {
                Text(value).font(ZenithType.body).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

extension ZenithRow where Trailing == ZenithRowChevron {
    /// A row that opens something when clicked, with a chevron ›.
    init(_ title: String, info: String? = nil, value: String? = nil, navigate: @escaping () -> Void) {
        self.init(title, info: info) { ZenithRowChevron(value: value) }
        self.navigate = navigate
    }
}

// MARK: Shortcut

/// The row's shortcut recorder, at the width the recorders share.
struct ZenithRowShortcut<Recorder: View>: View {
    let recorder: Recorder

    var body: some View {
        recorder.frame(width: 130)
    }
}

extension ZenithRow {
    /// A row with a shortcut recorder; `warning` says why a shortcut was refused.
    init<Recorder: View>(_ title: String, info: String? = nil, warning: String? = nil,
                         @ViewBuilder shortcut: () -> Recorder) where Trailing == ZenithRowShortcut<Recorder> {
        let recorder = shortcut()
        self.init(title, info: info, warning: warning) { ZenithRowShortcut(recorder: recorder) }
    }
}
