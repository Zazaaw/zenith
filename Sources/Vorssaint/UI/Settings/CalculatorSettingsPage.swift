// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Calculator, a feature page on the Settings kit:
/// the hero with the master switch, the stage showing an answer as it is
/// typed (in the island or the Command Bar), where it shows, and how answers
/// are written. Everything writes `CalculatorDefaults`; the island's module
/// list and the Command Bar read them when they open.
struct CalculatorSettingsPage: View {
    @ObservedObject private var service = CalculatorService.shared
    @AppStorage(CalculatorDefaults.enabled) private var enabled = false
    @AppStorage(CalculatorDefaults.showInIsland) private var showInIsland = true
    @AppStorage(CalculatorDefaults.showInCommandBar) private var showInCommandBar = true
    @AppStorage(CalculatorDefaults.decimalPlaces) private var decimalPlaces = CalculatorFormat.automatic
    @State private var stageState = 0

    private let text = ZenithStrings.calculator(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                           // The island follows its preferences on its own.
                           isOn: $enabled,
                           switchLabel: text.enable, switchHint: text.enableHint, animation: .calculator)
                    .zenithSectionAnchor(.zenithCalculator, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                ZenithStage(caption: text.stageCaption, states: [text.stageIsland, text.stageCommandBar],
                            selection: $stageState) {
                    CalculatorStageArt(commandBar: stageState == 1, places: decimalPlaces)
                }
                Group {
                    places
                    answers
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { service.loadHistory() }
    }

    private var chips: [ZenithChip] {
        var chips: [ZenithChip] = []
        if showInIsland { chips.append(ZenithChip("⌥⌘=")) }
        chips.append(ZenithChip(text.places(decimalPlaces) + " decimals"))
        return chips
    }

    private var places: some View {
        ZenithSection(text.placesSection) {
            ZenithRow(text.showInIsland, isOn: $showInIsland, info: text.showInIslandCaption)
            ZenithRow(text.showInCommandBar, isOn: $showInCommandBar, info: text.showInCommandBarCaption)
        }
    }

    private var answers: some View {
        ZenithSection(text.answersSection, anchor: .zenithCalculatorAnswers, footer: text.syntaxFootnote) {
            ZenithRow(text.decimalPlaces, selection: $decimalPlaces, info: text.decimalPlacesCaption) {
                ForEach(CalculatorDefaults.placeChoices, id: \.self) { Text(text.places($0)).tag($0) }
            }
            ZenithRow(text.clearHistory, info: text.clearHistoryCaption, button: text.clear) {
                service.clearHistory()
            }
            .disabled(service.history.entries.isEmpty)
        }
    }
}

// MARK: - Stage art

/// The island's Calculator, or a Command Bar row, answering a sum.
struct CalculatorStageArt: View {
    let commandBar: Bool
    let places: Int

    private static let expression = "1200 × 12 + 10%"

    private var answer: String {
        let value = CalculatorEngine.value(Self.expression) ?? 0
        return CalculatorText.display(value, places: places)
    }

    var body: some View {
        Group {
            if commandBar { bar } else { island }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.expression) is \(answer)")
    }

    private var island: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(verbatim: Self.expression)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(verbatim: "= " + answer)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                ForEach(["7", "8", "9", "÷", "+"], id: \.self) { key in
                    Text(verbatim: key)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 24)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.1)))
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.92)).padding(-2)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }

    private var bar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold))
                Text(verbatim: Self.expression).font(.system(size: 14))
                Spacer()
            }
            .foregroundStyle(.white)
            HStack(spacing: 10) {
                Image(systemName: "plus.forwardslash.minus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.14)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: answer).font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    Text(verbatim: "Return to copy").font(.system(size: 10.5)).opacity(0.6)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor.opacity(0.35)))
        }
        .padding(12)
        .frame(width: 300)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.07).opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }
}
