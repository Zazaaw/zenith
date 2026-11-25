// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The introduction and pairing until there is a Mac; then the four tabs,
/// each in its own scroll view, over the Liquid Glass island bar.
struct RootView: View {
    @Environment(PocketModel.self) private var model
    @AppStorage("pocket.onboarded") private var onboarded = false
    @State private var network = NetworkWatch()
    /// The tab on screen. It trails `model.tab` by one beat so the slide
    /// knows which way to go before the new tab is drawn.
    @State private var shownTab: PocketModel.Tab = .home
    @State private var direction: CGFloat = 1
    /// Tabs opened this launch: the first open plays every entrance in full,
    /// later ones a quick fade (`firstOpen`).
    @State private var seenTabs: Set<PocketModel.Tab> = []
    @State private var shownFirst = true

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            K.bg.ignoresSafeArea()
            if model.pairing != nil {
                // The aura's mood depends on how long ago the Mac was heard.
                TimelineView(.everyMinute) { context in
                    StateAura(mood: model.mood(now: context.date))
                }
                .ignoresSafeArea()
                .readsTilt()
                .transition(.opacity)
            }
            Ambient(parallax: model.pairing == nil ? 0 : 5).ignoresSafeArea()
            if model.pairing == nil {
                Group {
                    if onboarded {
                        PairView(onIntro: { withAnimation(Motion.reveal) { onboarded = false } })
                    } else {
                        OnboardingView { withAnimation(Motion.reveal) { onboarded = true } }
                    }
                }
                .transition(.blurReplace)
                if let toast = model.toast {
                    ToastView(toast: toast)
                        .padding(.horizontal, 24).padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            } else {
                tabs
                    .transition(.blurReplace)
            }
        }
        .overlay(alignment: .top) {
            if !network.online {
                OfflineBanner()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .foregroundStyle(K.fg)
        .animation(Motion.toast, value: model.toast)
        .animation(Motion.toast, value: network.online)
        .animation(Motion.reveal, value: model.pairing == nil)
        .onAppear {
            shownTab = model.tab
            seenTabs = [model.tab]
        }
        .onChange(of: model.tab) { old, new in
            direction = new.rawValue >= old.rawValue ? 1 : -1
            shownFirst = !seenTabs.contains(new)
            seenTabs.insert(new)
            withAnimation(Motion.spring) { shownTab = new }
        }
        .onChange(of: model.toast) { _, toast in
            guard let toast else { return }
            if toast.ok { Haptics.success() } else { Haptics.warning() }
        }
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

    private var tabs: some View {
        TimelineView(.everyMinute) { context in
            ZStack {
                // Offline, the banner takes the top; the compact header sits under it.
                TabScroll(headerInset: network.online ? 0 : 40, refresh: { await model.refreshNow() }) {
                    page(shownTab, now: context.date)
                        .padding(.bottom, 24)
                }
                .environment(\.firstOpen, shownFirst)
                .id(shownTab)
                .transition(TabSlide(direction: direction))
            }
            // The island sits in the bottom inset: content scrolls up past
            // it and shows through its glass, but never ends hidden under it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    if let toast = model.toast {
                        ToastView(toast: toast)
                            .padding(.horizontal, 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .id(toast.id)
                    }
                    IslandBar()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func page(_ tab: PocketModel.Tab, now: Date) -> some View {
        switch tab {
        case .home: HomeView(now: now)
        case .claude: ClaudeView(now: now)
        case .mac: MacView(now: now)
        case .devices: DevicesView(now: now)
        }
    }
}

/// A command's outcome, above the island bar: a small card that springs up
/// from the bar and sinks back after a few seconds.
struct ToastView: View {
    let toast: PocketModel.Toast

    var body: some View {
        let tint = toast.ok ? K.emerald : K.amber
        HStack(spacing: 10) {
            Image(systemName: toast.ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.12), in: Circle())
                .symbolEffect(.bounce, value: toast.id)
            Text(toast.text).font(K.sans(14)).foregroundStyle(K.fg).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .surface(radius: 18)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}

/// The phone itself has no network: said quietly at the top, since what
/// Pocket shows is then only what it last heard.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash").font(.system(size: 11, weight: .semibold))
            Text("You're offline. Pocket shows what it last heard.").font(K.mono(11))
        }
        .foregroundStyle(K.muted)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
