// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Three short cards before the first pairing: what Pocket does, that it is
/// sealed end to end, and where the code is. Then the scanner.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Page {
        let eyebrow: String
        let symbol: String
        let sentence: PocketSentence
    }

    private static let pages: [Page] = [
        Page(eyebrow: "Zenith Pocket", symbol: "macbook.and.iphone",
             sentence: PocketSentence(lead: "Your Mac, ", value: "in your pocket", after: ".",
                                      rest: "Its battery, Keep Awake, the lock and Claude Code, from your iPhone.", tone: .plain)),
        Page(eyebrow: "Private", symbol: "lock.shield",
             sentence: PocketSentence(lead: "Sealed ", value: "end to end", after: ".",
                                      rest: "Only your Mac and this iPhone hold the key. The relay between them carries noise.", tone: .good)),
        Page(eyebrow: "Pairing", symbol: "qrcode.viewfinder",
             sentence: PocketSentence(lead: "Pair in ", value: "one scan", after: ".",
                                      rest: "On your Mac, open Zenith Settings → iPhone & Watch and show the code.", tone: .info)),
    ]

    var body: some View {
        let last = page == Self.pages.count - 1
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if !last {
                    Button("Skip") { finish() }
                        .font(K.sans(15, bold: true)).foregroundStyle(K.muted)
                        .pressable()
                        .transition(.opacity)
                }
            }
            .frame(height: 32)
            .padding(.horizontal, 24).padding(.top, 8)
            Spacer(minLength: 20)
            ZStack(alignment: .topLeading) {
                card(Self.pages[page])
                    .id(page)
                    .transition(.asymmetric(insertion: AnyTransition(TabSlide(direction: 1)), removal: AnyTransition(.blurReplace)))
            }
            Spacer(minLength: 20)
            HStack(spacing: 6) {
                ForEach(Self.pages.indices, id: \.self) { index in
                    Capsule().fill(index == page ? K.fg : K.track)
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .padding(.horizontal, 24)
            .accessibilityElement()
            .accessibilityLabel("Page \(page + 1) of \(Self.pages.count)")
            PillButton(title: last ? "Scan the code" : "Continue", primary: true) {
                if last { finish() } else { withAnimation(Motion.spring) { page += 1 } }
            }
            .contentTransition(.opacity)
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 24)
        }
        .animation(Motion.spring, value: page)
        .gesture(DragGesture(minimumDistance: 24).onEnded { drag in
            if drag.translation.width < -40, !last { withAnimation(Motion.spring) { page += 1 } }
            if drag.translation.width > 40, page > 0 { withAnimation(Motion.spring) { page -= 1 } }
        })
        .sensoryFeedback(.selection, trigger: page)
    }

    private func finish() {
        Haptics.tap()
        onDone()
    }

    private func card(_ page: Page) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Image(systemName: page.symbol)
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(K.color(page.sentence.tone))
                .symbolEffect(.bounce, options: .nonRepeating, value: page.symbol)
                .frame(width: 112, height: 112)
                .surface(radius: 30)
                .padding(.horizontal, 24)
                .blurFade(delay: 0.05, distance: 16)
            Hero(eyebrow: page.eyebrow, badge: nil, sentence: page.sentence)
        }
    }
}
