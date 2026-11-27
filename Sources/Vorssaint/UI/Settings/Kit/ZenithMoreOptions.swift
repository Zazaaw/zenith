// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: a page's advanced rows, folded under "More options" at the
// foot of a section, as in the approved mockups.

/// Advanced rows, folded away. Put it last in a `ZenithSection`; its rows
/// join the section's card when it opens.
///
///     ZenithSection("Typing") {
///         ZenithRow("Volume", value: $volume, in: 0...1)
///         ZenithMoreOptions(id: "mechakey", anchors: [.myFeatureRepeat]) {
///             ZenithRow("Ignore key repeat", isOn: $ignoreRepeat, info: "…")
///                 .zenithSectionAnchor(.myFeatureRepeat)
///         }
///     }
///
/// - `id`: stable per page (and per fold, if a page has two); keys whether
///   it was left open. It starts folded.
/// - `anchors`: the Settings search destinations inside. When search lands
///   on one, the fold opens itself so the page can scroll to it.
struct ZenithMoreOptions<Content: View>: View {
    let anchors: Set<SettingsSectionAnchor>
    let content: Content
    @AppStorage private var remembered: Bool
    @State private var openedForSearch: Bool
    @ObservedObject private var router = SettingsRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(id: String, anchors: Set<SettingsSectionAnchor> = [], @ViewBuilder content: () -> Content) {
        self.anchors = anchors
        self.content = content()
        _remembered = AppStorage(wrappedValue: false, ZenithMoreOptionsRule.key(id))
        // Built while Settings lands on an anchor inside: open from the first frame,
        // so the section is there to scroll to.
        _openedForSearch = State(initialValue: ZenithMoreOptionsRule.opensForSearch(
            target: SettingsRouter.shared.destination.sectionAnchor, inside: anchors))
    }

    private var isOpen: Bool {
        ZenithMoreOptionsRule.isOpen(remembered: remembered, openedForSearch: openedForSearch)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack {
                    Text(ZenithKitStrings.moreOptions)
                        .font(ZenithType.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.horizontal, ZenithKitSurface.rowInset)
                .frame(minHeight: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ZenithKitStrings.moreOptions)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            if isOpen {
                ZenithRowSeparator()
                ZenithRowStack { content }
            }
        }
        .zenithFullBleed()
        .onChange(of: router.requestID) { _, _ in
            if ZenithMoreOptionsRule.opensForSearch(target: router.destination.sectionAnchor, inside: anchors) {
                openedForSearch = true
            }
        }
    }

    private func toggle() {
        let open = !isOpen
        let change = {
            remembered = open
            if !open { openedForSearch = false }
        }
        if reduceMotion {
            change()
        } else {
            withAnimation(ZenithMotion.toggle(), change)
        }
    }
}
