// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The paired Mac, the link, and unpairing.
struct SettingsSheet: View {
    @Environment(PocketModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmUnpair = false

    var body: some View {
        ZStack {
            K.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(K.sans(15, bold: true)).foregroundStyle(K.fg)
                    }
                    .padding(.horizontal, 24).padding(.top, 18)
                    Hero(eyebrow: "Settings", badge: linkBadge,
                         sentence: PocketSentence(lead: "Paired with ", value: model.pairing?.macName ?? "no Mac", after: ".",
                                                  rest: "", tone: .plain))
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Mac")
                        Rows {
                            Row(symbol: "laptopcomputer", title: model.pairing?.macName ?? "Mac", meta: heardLine) { EmptyView() }
                            Row(symbol: "dot.radiowaves.left.and.right", title: "Relay", meta: linkLine, divider: false) { EmptyView() }
                        }
                        if let problem = model.relayProblem {
                            Text(problem).font(K.mono(11)).foregroundStyle(K.amber).padding(.horizontal, 4)
                        }
                        PillButton(title: "Unpair") { confirmUnpair = true }
                            .padding(.top, 14)
                        Text("Unpairing deletes the key on this iPhone. To pair again, show the code in Zenith once more.")
                            .font(K.sans(13)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                        SectionLabel(text: "About").padding(.top, 22)
                        Text("Zenith Pocket \(version), by Satu Visual. Free software under the GPL. Plus Jakarta Sans under the SIL Open Font License.")
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
        .confirmationDialog("Unpair from \(model.pairing?.macName ?? "this Mac")?", isPresented: $confirmUnpair, titleVisibility: .visible) {
            Button("Unpair", role: .destructive) { model.unpair() }
        }
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
