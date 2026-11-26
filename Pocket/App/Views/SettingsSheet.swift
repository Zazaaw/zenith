// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The paired Mac, the link, the look, and unpairing.
struct SettingsSheet: View {
    @Environment(PocketModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ThemeChoice.key) private var theme = ThemeChoice.system
    @State private var confirmUnpair = false
    @AppStorage(PhoneBattery.nameKey) private var phoneName = ""
    @AppStorage(WatchBridge.nameKey) private var watchName = ""
    @FocusState private var naming: NameField?

    private enum NameField: Hashable { case phone, watch }
    @Namespace private var themePill

    var body: some View {
        ZStack {
            K.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(K.sans(15, bold: true)).foregroundStyle(K.fg)
                            .pressable()
                    }
                    .padding(.horizontal, 24).padding(.top, 18)
                    Hero(eyebrow: "Settings", badge: linkBadge,
                         sentence: PocketSentence(lead: "Paired with ", value: model.pairing?.macName ?? "no Mac", after: ".",
                                                  rest: "", tone: .plain))
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Mac")
                            .blurFade(index: 2)
                        Rows {
                            Row(symbol: "laptopcomputer", title: model.pairing?.macName ?? "Mac", meta: heardLine) { EmptyView() }
                            Row(symbol: "dot.radiowaves.left.and.right", title: "Relay", meta: linkLine, divider: false) { EmptyView() }
                        }
                        .blurFade(index: 3)
                        if let problem = model.relayProblem {
                            Text(problem).font(K.mono(11)).foregroundStyle(K.amber).padding(.horizontal, 4)
                        }
                        PillButton(title: "Unpair") { confirmUnpair = true }
                            .padding(.top, 14)
                        Text("Unpairing deletes the key on this iPhone. To pair again, show the code in Zenith once more.")
                            .font(K.sans(13)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                        SectionLabel(text: "Names").padding(.top, 22)
                        VStack(spacing: 10) {
                            nameField(.phone, symbol: "iphone", text: $phoneName, placeholder: PhoneBattery.fallbackName)
                            nameField(.watch, symbol: "applewatch", text: $watchName, placeholder: "Apple Watch")
                        }
                        Text("The names Zenith shows, as in “Locked from \(PhoneBattery.name)”. iOS and watchOS don't share the names from Settings with apps.")
                            .font(K.sans(13)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                        SectionLabel(text: "Appearance").padding(.top, 22)
                        themePicker
                        SectionLabel(text: "About").padding(.top, 22)
                        Text("Zenith Pocket \(version), by Satu Visual. Free software under the GPL. Plus Jakarta Sans under the SIL Open Font License.")
                            .font(K.sans(13)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                        SectionLabel(text: "Acknowledgements").padding(.top, 22)
                        Text("The splash's glass is ported from glass-icon-reveal by zanwei, under the MIT License.")
                            .font(K.sans(13)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 20).padding(.top, 26)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(K.fg)
        .presentationBackground(K.bg)
        .preferredColorScheme(theme.scheme)
        .confirmationDialog("Unpair from \(model.pairing?.macName ?? "this Mac")?", isPresented: $confirmUnpair, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) { model.unpair() }
        }
    }

    /// What Zenith calls this iPhone or its Watch; empty keeps the default.
    private func nameField(_ field: NameField, symbol: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(K.muted)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(K.sans(15, bold: true))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($naming, equals: field)
                .onSubmit { saveNames() }
                .onChange(of: text.wrappedValue) { _, next in
                    if next.count > PhoneBattery.maximumName { text.wrappedValue = String(next.prefix(PhoneBattery.maximumName)) }
                }
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                    saveNames()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(K.faint)
                }
                .buttonStyle(PressStyle(haptic: true))
                .accessibilityLabel("Use the default name")
            }
        }
        .padding(.horizontal, 14).frame(height: 50)
        .surface(radius: 16)
        .onChange(of: naming) { old, _ in if old == field { saveNames() } }
    }

    private func saveNames() {
        for name in [$phoneName, $watchName] {
            let trimmed = name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != name.wrappedValue { name.wrappedValue = trimmed }
        }
        model.deviceNamesChanged()
    }

    /// System, Light or Dark, as a segmented capsule whose ink pill slides.
    private var themePicker: some View {
        HStack(spacing: 0) {
            ForEach(ThemeChoice.allCases) { choice in
                let selected = theme == choice
                Button {
                    Haptics.select()
                    withAnimation(Motion.spring) { theme = choice }
                } label: {
                    Text(choice.title).font(K.sans(14, bold: true))
                        .foregroundStyle(selected ? K.inverse : K.muted)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background {
                            if selected { Capsule().fill(K.fg).matchedGeometryEffect(id: "theme", in: themePill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PressStyle(haptic: false))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .surface(radius: 23)
    }

    private var linkBadge: PocketBadge {
        switch model.link {
        case .live: return PocketBadge("Live", .good)
        case .connecting: return PocketBadge("Connecting", .attention)
        case .offline: return PocketBadge("Offline", .quiet)
        }
    }

    private var linkLine: String {
        switch model.link {
        case .live: return "live · sealed"
        case .connecting: return "connecting"
        case .offline: return "closed"
        }
    }

    private var heardLine: String {
        guard let heard = model.heardAt else { return "not heard from yet" }
        return "heard " + PocketPresentation.ago(heard, now: Date())
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
