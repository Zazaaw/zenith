// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the shield App Lock draws over a locked app. One borderless
// window per screen, above normal windows (floating level, so the menu bar,
// the Dock and the system's Touch ID and password prompt stay above it), on
// every Space and over full-screen apps, blurring what is behind it. The card
// with the app's icon, its name and Unlock sits on the screen that shows most
// of the app's windows. AppLockService decides when it shows.

/// What the shield's card shows.
@MainActor
final class AppLockShieldModel: ObservableObject {
    enum Status: Equatable {
        case idle
        /// Zenith's Face Unlock is looking for a face.
        case face
        /// macOS asks for Touch ID or the password.
        case waiting
        /// The face was not matched and macOS asks now.
        case faceMissed
        /// Not unlocked; Unlock tries again.
        case failed

        /// A Touch ID or password prompt is open.
        var isPrompting: Bool { self == .waiting || self == .faceMissed }
    }

    let name: String
    let icon: NSImage
    @Published var status: Status = .idle
    var onUnlock: (() -> Void)?
    var onCancel: (() -> Void)?

    init(name: String, icon: NSImage, status: Status = .idle) {
        self.name = name
        self.icon = icon
        self.status = status
    }

    func line(_ text: ZenithAppLockStrings) -> String? {
        switch status {
        case .idle: return nil
        case .face: return text.lookingForFace
        case .waiting: return text.waiting
        case .faceMissed: return text.faceNotRecognized
        case .failed: return text.failed
        }
    }
}

@MainActor
final class AppLockShieldController {
    private(set) var model: AppLockShieldModel?
    private var windows: [AppLockShieldWindow] = []
    private var keyWindow: AppLockShieldWindow?

    func show(_ model: AppLockShieldModel, coveringProcess pid: pid_t) {
        dismiss()
        guard !ZenithQuiet.isOn else { return }
        self.model = model
        let screens = NSScreen.screens
        let target = Self.screen(showingMostOf: pid, in: screens) ?? NSScreen.main ?? screens.first
        for screen in screens {
            let window = AppLockShieldWindow.make(screen: screen,
                                                  content: AppLockShieldView(model: model, showsCard: screen == target))
            window.orderFrontRegardless()
            windows.append(window)
            if screen == target { keyWindow = window }
        }
        focus()
    }

    /// Takes the keyboard: typing goes to the shield, not the app under it.
    func focus() {
        guard !windows.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        for window in windows { window.orderFrontRegardless() }
        (keyWindow ?? windows.first)?.makeKey()
    }

    func dismiss() {
        for window in windows { window.orderOut(nil) }
        windows = []
        keyWindow = nil
        model = nil
    }

    /// The screen with the largest share of the app's on-screen windows.
    /// Window bounds need no permission (their titles would).
    static func screen(showingMostOf pid: pid_t, in screens: [NSScreen]) -> NSScreen? {
        guard let primary = screens.first,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return nil }
        var best: (screen: NSScreen, area: CGFloat)?
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { continue }
            // Window Server space has its origin at the top left of the primary screen.
            let flipped = CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
            for screen in screens {
                let overlap = screen.frame.intersection(flipped)
                guard !overlap.isNull else { continue }
                let area = overlap.width * overlap.height
                if area > (best?.area ?? 0) { best = (screen, area) }
            }
        }
        return best?.screen
    }
}

/// A shield over one screen. Borderless windows need leave to take the keyboard.
final class AppLockShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension AppLockShieldWindow {
    @MainActor
    static func make(screen: NSScreen, content: AppLockShieldView) -> AppLockShieldWindow {
        let window = AppLockShieldWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered,
                                         defer: false)
        window.configure(screen: screen, content: content)
        return window
    }

    @MainActor
    private func configure(screen: NSScreen, content: AppLockShieldView) {
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        animationBehavior = .none
        isMovable = false
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        let hosting = NSHostingView(rootView: content)
        hosting.frame = blur.bounds
        hosting.autoresizingMask = [.width, .height]
        blur.addSubview(hosting)
        contentView = blur
        setFrame(screen.frame, display: false)
    }
}

/// The shield's picture: a dim over the blur, and on one screen the card.
struct AppLockShieldView: View {
    @ObservedObject var model: AppLockShieldModel
    let showsCard: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let text = ZenithStrings.appLock(.enUS)

    var body: some View {
        ZStack {
            // Over the blur, so large text behind it stays unreadable.
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.25)
                .ignoresSafeArea()
            if showsCard {
                AppLockShieldCard(model: model, text: text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The card: the app's icon with a padlock, its name, what is happening, and
/// Cancel (hides the app) beside Unlock.
struct AppLockShieldCard: View {
    @ObservedObject var model: AppLockShieldModel
    let text: ZenithAppLockStrings

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: model.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                AppLockPadlockBadge(size: 34)
                    .offset(x: 6, y: 4)
            }
            .accessibilityHidden(true)
            Text(model.name)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
            Text(text.lockedBy)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            if let line = model.line(text) {
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(model.status == .failed ? ZenithStatus.warning : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(text.cancel) { model.onCancel?() }
                    .keyboardShortcut(.cancelAction)
                Button(model.status == .face ? text.usePassword : text.unlock) { model.onUnlock?() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.status.isPrompting)
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .frame(minWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.name), \(text.lockedBy)")
    }
}

/// A round padlock badge: the shield's mark, also on the Settings stage.
struct AppLockPadlockBadge: View {
    var size: CGFloat = 34
    var open = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.78)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            Image(systemName: open ? "lock.open.fill" : "lock.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(Color(red: 0.2, green: 0.26, blue: 0.42))
        }
        .frame(width: size, height: size)
    }
}
