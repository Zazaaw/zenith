// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Pairing until there is a Mac; then the four tabs over the island bar.
struct RootView: View {
    @Environment(PocketModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            K.bg.ignoresSafeArea()
            Ambient().ignoresSafeArea()
            if model.pairing == nil {
                PairView()
            } else {
                TimelineView(.everyMinute) { context in
                    ScrollView {
                        Group {
                            switch model.tab {
                            case .home: HomeView(now: context.date)
                            case .control: ControlView(now: context.date)
                            case .agents: AgentsView(now: context.date)
                            case .devices: DevicesView(now: context.date)
                            }
                        }
                        .padding(.bottom, 150)
                    }
                    .scrollIndicators(.hidden)
                }
                IslandBar()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
            }
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.horizontal, 24)
                    .padding(.bottom, model.pairing == nil ? 24 : (model.islandQuestion == nil ? 84 : 220))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .foregroundStyle(K.fg)
        .animation(.spring(duration: 0.35), value: model.toast)
        .sheet(isPresented: $model.showingSettings) {
            SettingsSheet().environment(model)
        }
        .alert("Pair with \(model.replacement?.macName ?? "this Mac")?", isPresented: Binding(
            get: { model.replacement != nil }, set: { if !$0 { model.replacement = nil } })) {
            Button("Pair") { if let next = model.replacement { model.pair(with: next) } }
            Button("Cancel", role: .cancel) { model.replacement = nil }
        } message: {
            Text("Pocket forgets \(model.pairing?.macName ?? "the Mac it's paired with") and shows this Mac instead.")
        }
    }
}

/// A command's outcome, above the island bar.
struct ToastView: View {
    let toast: PocketModel.Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(toast.ok ? K.emerald : K.amber)
            Text(toast.text).font(K.sans(14)).foregroundStyle(K.fg).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}
