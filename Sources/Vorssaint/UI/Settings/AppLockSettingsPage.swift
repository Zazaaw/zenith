// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Zenith fork: Settings → App Lock, a feature page on the Settings kit
/// (docs/SETTINGS-KIT.md): the hero with the master switch (off by default),
/// the shield on the stage, the locked apps, how unlocking works, when an
/// app locks again with Lock Now, and an honest row about the limits.
/// Everything writes `AppLockDefaults`; `AppLockService` follows.
struct AppLockSettingsPage: View {
    @ObservedObject private var service = AppLockService.shared
    @AppStorage(AppLockDefaults.enabled) private var enabled = false
    @AppStorage(AppLockDefaults.relock) private var relock = AppLockRelock.standard.rawValue
    @AppStorage(AppLockDefaults.scope) private var scope = AppLockScope.eachApp.rawValue
    @AppStorage(AppLockDefaults.faceUnlock) private var faceUnlock = true
    @AppStorage(AppLockDefaults.lockWithMac) private var lockWithMac = true
    @AppStorage(AppLockDefaults.hideWhenInactive) private var hideWhenInactive = false
    @State private var apps: [String] = UserDefaults.standard.stringArray(forKey: AppLockDefaults.apps) ?? []
    @State private var refused = false
    @State private var stageState = 0

    private let text = ZenithStrings.appLock(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                           isOn: Binding(get: { enabled }, set: { on in
                               enabled = on
                               service.sync()
                           }),
                           switchLabel: text.enable, switchHint: text.enableHint, animation: .appLock)
                    .zenithSectionAnchor(.zenithAppLock, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                stage
                Group {
                    lockedApps
                    unlocking
                    lockAgain
                    limits
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // A restored backup or another window changed the list.
            let stored = UserDefaults.standard.stringArray(forKey: AppLockDefaults.apps) ?? []
            if stored != apps { apps = stored }
        }
    }

    private var chips: [ZenithChip] {
        let face = faceUnlock && AppLockService.faceUnlockSetUp
        return [ZenithChip(text.appCount(AppLockApps.cleaned(apps).count)),
                ZenithChip(face ? text.chipFace : text.chipTouchID),
                ZenithChip(text.relockTitle(AppLockRelock(rawValue: relock) ?? .standard))]
    }

    // MARK: Stage

    private var stage: some View {
        ZenithStage(caption: text.stageCaption, states: [text.stageLocked, text.stageScanning, text.stageUnlocked],
                    selection: $stageState) {
            AppLockStageArt(state: stageState, text: text)
        }
    }

    // MARK: Locked apps

    private var lockedApps: some View {
        ZenithSection(text.appsSection, anchor: .zenithAppLockApps,
                      footer: refused ? text.exemptRefused : nil) {
            let shown = AppLockApps.cleaned(apps)
            if shown.isEmpty {
                ZenithRow(text.noApps) { EmptyView() }
            }
            ForEach(shown, id: \.self) { bundleID in
                AppLockAppRow(info: AppLockAppInfo(bundleID: bundleID), text: text) { remove(bundleID) }
            }
            ZenithRow(text.addRow) {
                HStack(spacing: 8) {
                    runningMenu
                    Button(text.addApp, action: chooseApps)
                }
            }
        }
    }

    private var runningMenu: some View {
        let locked = Set(apps.map { $0.lowercased() })
        let running = NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, let id = app.bundleIdentifier else { return false }
                return !AppLockExemptions.isExempt(id) && !locked.contains(id.lowercased())
            }
            .map(AppLockAppInfo.init(app:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Menu(text.addRunning) {
            ForEach(running, id: \.bundleID) { info in
                Button {
                    add([info.bundleID])
                } label: {
                    Label { Text(info.name) } icon: { Image(nsImage: Self.menuIcon(info.icon)) }
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(running.isEmpty)
    }

    private static func menuIcon(_ image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = text.chooseAppsPrompt
        panel.message = text.chooseAppsMessage
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        add(panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
    }

    private func add(_ bundleIDs: [String]) {
        let result = AppLockApps.adding(bundleIDs, to: apps)
        refused = !result.refused.isEmpty
        save(result.apps)
    }

    private func remove(_ bundleID: String) {
        refused = false
        save(AppLockApps.removing(bundleID, from: apps))
    }

    private func save(_ list: [String]) {
        apps = list
        UserDefaults.standard.set(list, forKey: AppLockDefaults.apps)
        service.sync()
    }

    // MARK: Unlocking

    private var unlocking: some View {
        ZenithSection(text.unlockSection) {
            ZenithRow(text.systemMethod, info: text.systemMethodCaption) {
                Text(text.always).foregroundStyle(.secondary)
            }
            if AppLockService.faceUnlockSetUp {
                ZenithRow(text.faceMethod, isOn: $faceUnlock, info: text.faceMethodCaption)
            } else if FaceUnlockRuntime.isSupported {
                ZenithRow(text.faceMethod, info: text.faceMethodCaption, essential: text.faceNotSetUp) {
                    Button(text.openFaceUnlock) {
                        SettingsRouter.shared.request(FeatureSettingsDestination(.faceUnlock, sectionAnchor: .zenithFaceUnlock))
                    }
                }
            } else {
                ZenithRow(text.faceMethod, info: text.faceMethodCaption, essential: text.faceUnsupported) { EmptyView() }
            }
        }
    }

    // MARK: Lock again

    private var lockAgain: some View {
        ZenithSection(text.relockSection, anchor: .zenithAppLockRelock) {
            ZenithRow(text.relock, selection: $relock, info: text.relockCaption) {
                ForEach(AppLockRelock.allCases) { Text(text.relockTitle($0)).tag($0.rawValue) }
            }
            ZenithRow(text.scope, selection: $scope, info: text.scopeCaption) {
                ForEach(AppLockScope.allCases) { Text(text.scopeTitle($0)).tag($0.rawValue) }
            }
            ZenithRow(text.lockWithMac, isOn: $lockWithMac, info: text.lockWithMacCaption)
            ZenithRow(text.lockNowTitle, info: text.lockNowCaption,
                      essential: service.lockedNow ? text.lockedNow : nil) {
                Button(text.lockNow) { service.lockNow() }
            }
            ZenithMoreOptions(id: "appLock", anchors: [.zenithAppLockHide]) {
                ZenithRow(text.hideWhenInactive, isOn: $hideWhenInactive, info: text.hideWhenInactiveCaption)
                    .zenithSectionAnchor(.zenithAppLockHide, cornerRadius: 10, inset: 4)
            }
        }
    }

    // MARK: Limits

    private var limits: some View {
        ZenithSection(text.limitsSection) {
            ZenithRow(text.limitsTitle, info: text.limitsCaption) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }
        }
    }
}

/// One locked app: its icon, name and identifier, and Remove.
struct AppLockAppRow: View {
    let info: AppLockAppInfo
    let text: ZenithAppLockStrings
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: info.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .opacity(info.isInstalled ? 1 : 0.5)
                .accessibilityHidden(true)
            ZenithRow(info.name, info: info.bundleID, essential: info.isInstalled ? nil : text.notInstalled) {
                Button(text.remove, action: remove)
            }
        }
    }
}

// MARK: - Stage art

/// A window on the stage, covered by the shield while locked, a face ring
/// while Face Unlock looks, and open once unlocked. Still, as the pills choose.
struct AppLockStageArt: View {
    let state: Int
    let text: ZenithAppLockStrings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        ZStack {
            window(dark: dark)
            if state < 2 {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(dark ? 0.35 : 0.12)))
                    .frame(width: 300, height: 170)
                card
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state == 2 ? text.stageUnlocked : text.stageLocked)
    }

    private func window(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 7, height: 7) }
                Spacer()
            }
            .padding(9)
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(0..<4) { i in
                        Capsule().fill(.primary.opacity(i == 1 ? 0.35 : 0.15)).frame(width: 58, height: 7)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(i == 0 ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.12))
                            .frame(width: [150, 120, 170][i], height: 22)
                            .frame(maxWidth: .infinity, alignment: i == 0 ? .trailing : .leading)
                    }
                }
            }
            .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 170)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(dark ? Color(white: 0.16) : .white))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }

    private var card: some View {
        VStack(spacing: 6) {
            ZStack {
                if state == 1 {
                    Circle()
                        .stroke(ZenithStatus.info, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .frame(width: 58, height: 58)
                    Image(systemName: "faceid")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(ZenithStatus.info)
                } else {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.78, blue: 1), Color(red: 0.42, green: 0.32, blue: 0.95)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    AppLockPadlockBadge(size: 22)
                        .offset(x: 19, y: 17)
                }
            }
            .frame(height: 58)
            Text(state == 1 ? text.lookingForFace : text.lockedBy)
                .font(.system(size: 11, weight: .semibold))
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 70, height: 20)
                .overlay(Text(text.unlock).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white))
                .opacity(state == 1 ? 0.45 : 1)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }
}
