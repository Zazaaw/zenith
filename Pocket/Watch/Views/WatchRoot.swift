// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The pages, top to bottom: the Mac, Claude, what plays, the batteries.
/// Before a pairing arrives from the iPhone, one page says how to get it.
struct WatchRoot: View {
    @Environment(WatchModel.self) private var model
    @State private var page = Page.mac
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Page: Hashable { case mac, claude, media, batteries }

    var body: some View {
        Group {
            if model.pairing == nil {
                PairPrompt()
            } else {
                TabView(selection: $page) {
                    MacPage().tag(Page.mac)
                    ClaudePage().tag(Page.claude)
                    MediaPage().tag(Page.media)
                    BatteriesPage().tag(Page.batteries)
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .overlay(alignment: .bottom) {
            if let note = model.note {
                NoteBanner(note: note)
                    .padding(.horizontal, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(note.id)
            }
        }
        .animation(Motion.respecting(reduceMotion, Motion.spring), value: model.note)
        .animation(Motion.respecting(reduceMotion, Motion.reveal), value: model.pairing == nil)
    }
}

/// No pairing yet: the iPhone app hands it over once it is paired with Zenith.
private struct PairPrompt: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                StarShape().fill(K.fg, style: FillStyle(eoFill: true)).frame(width: 30, height: 30)
                SentenceText(sentence: PocketSentence(lead: "Open ", value: "Pocket", after: "",
                                                      rest: "on your iPhone, paired with Zenith. It passes the pairing to this Watch.",
                                                      tone: .plain))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}

/// A page's small header: what it is about, in caps.
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(K.faint).lineLimit(1)
    }
}
