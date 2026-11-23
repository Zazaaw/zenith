// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import AppKit
import AVFoundation
import Combine
import SwiftUI

/// Zenith fork: face unlock's setup, in a window of its own (Glance hosts it
/// in the notch; a window is simpler and keeps the island to the lock
/// screen). One at a time: asking again brings the open one forward.
enum FaceUnlockSetupWindow {
    private static var current: Host?

    /// The whole setup, from the intro to "You're all set".
    static func startFirstRun() {
        present(mode: .firstRun, prefill: NSFullUserName().isEmpty ? "Owner" : NSFullUserName())
    }

    /// Another face, or a new capture of the face `replacing` names (keeping
    /// its id; `name` pre-fills the name). The faces are sealed under the
    /// session key, so Touch ID opens the session first; nothing opens if it
    /// does not pass.
    static func startAddFace(replacing: UUID? = nil, name: String = "") {
        let session = FaceUnlockRuntime.shared.session
        session.unlockSession(reason: ZenithStrings.faceUnlock(.enUS).reasonAddFace) { opened in
            guard opened else { return }
            FaceUnlockSetup.faces?.reload()
            present(mode: .addFace(replacing: replacing), prefill: name)
        }
    }

    /// The password step alone; it opens the session itself when it saves.
    static func startPasswordChange() {
        present(mode: .password, prefill: "")
    }

    private static func present(mode: FaceUnlockOnboardingFlow.Mode, prefill: String) {
        if let current {
            current.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let text = ZenithStrings.faceUnlock(.enUS)
        let flow = FaceUnlockOnboardingFlow(mode: mode, prefillName: prefill, .init(
            session: FaceUnlockRuntime.shared.session,
            faces: { FaceUnlockSetup.faces },
            makeEnrollment: { FaceUnlockSetup.makeEnrollment?($0) },
            defaults: .standard,
            accessibility: { AXIsProcessTrusted() },
            camera: {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized: return .granted
                case .notDetermined: return .notDetermined
                default: return .denied
                }
            },
            requestAccessibility: {
                if AXIsProcessTrusted() { return }
                Permissions.shared.requestAccessibility()
            },
            requestCamera: {
                if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                    Permissions.shared.requestCamera()
                } else {
                    Permissions.shared.openCameraSettings()
                }
            },
            cameras: FaceUnlockCameraCatalog.cameras,
            scheduler: FaceUnlockMainScheduler(),
            touchIDReason: mode == .firstRun ? text.reasonSetUp : text.reasonOpen))
        current = Host(flow: flow, title: text.windowTitle)
    }

    private final class Host: NSObject, NSWindowDelegate {
        let window: NSWindow
        let flow: FaceUnlockOnboardingFlow
        private var finished: AnyCancellable?

        init(flow: FaceUnlockOnboardingFlow, title: String) {
            self.flow = flow
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            super.init()
            window.title = title
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: FaceUnlockSetupView(flow: flow))
            window.delegate = self
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            finished = flow.$isFinished.filter { $0 }.sink { [weak self] _ in self?.window.close() }
        }

        func windowWillClose(_ notification: Notification) {
            flow.teardown()
            finished = nil
            FaceUnlockRuntime.shared.session.refresh()
            FaceUnlockSetup.faces?.reload()
            // Setup turns face unlock on at the end; start listening.
            FaceUnlockRuntime.shared.sync()
            FaceUnlockSetupWindow.current = nil
        }
    }
}

// MARK: - Views

struct FaceUnlockSetupView: View {
    @ObservedObject var flow: FaceUnlockOnboardingFlow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var password = ""
    private let text = ZenithStrings.faceUnlock(.enUS)
    private let permissionPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .id(flow.step)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .offset(x: flow.movedForward ? 24 : -24).combined(with: .opacity),
                    removal: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if let problem = flow.problem {
                Text(message(problem))
                    .font(ZenithType.footnote)
                    .foregroundStyle(ZenithStatus.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
            }
            buttons
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 24)
        .frame(width: 520, height: 500)
        .background(ZenithDotGrid().opacity(0.6))
        .animation(ZenithMotion.respecting(ZenithMotion.reveal()), value: flow.step)
        .onReceive(permissionPoll) { _ in if flow.step == .permissions { flow.refreshPermissions() } }
    }

    @ViewBuilder
    private var content: some View {
        switch flow.step {
        case .intro:
            hero(symbol: "faceid", title: text.introTitle, body: text.introBody)
        case .permissions:
            VStack(alignment: .leading, spacing: 14) {
                heading(text.permissionsTitle, text.permissionsBody)
                permission(symbol: "accessibility", title: text.accessibility, detail: text.accessibilityDetail,
                           granted: flow.accessibilityGranted, action: flow.grantAccessibility)
                permission(symbol: "camera", title: text.cameraPermission, detail: text.cameraDetail,
                           granted: flow.cameraAccess == .granted, action: flow.grantCamera)
            }
        case .securityNotice:
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(ZenithStatus.warning)
                Text(text.noticeTitle)
                    .font(ZenithType.display)
                    .tracking(ZenithType.pageTitleTracking / 2)
                    .fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach([text.noteSecurity, text.noteVideo, text.noteTyping, text.noteStorage], id: \.self) {
                            Text($0)
                                .font(ZenithType.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        case .preSetup:
            hero(symbol: "person.crop.circle.dashed", title: text.preSetupTitle, body: text.preSetupBody)
        case .selectCamera:
            VStack(alignment: .leading, spacing: 14) {
                heading(text.selectCameraTitle, text.selectCameraBody)
                Picker(text.camera, selection: Binding(get: { flow.selectedCameraID ?? "" },
                                                        set: { flow.selectCamera($0.isEmpty ? nil : $0) })) {
                    Text(text.systemDefault).tag("")
                    ForEach(flow.cameras) { camera in Text(camera.name).tag(camera.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 320)
            }
        case .enroll:
            FaceUnlockEnrollView(flow: flow, text: text)
        case .name:
            VStack(alignment: .leading, spacing: 14) {
                heading(text.nameTitle, text.nameBody)
                TextField(text.namePlaceholder, text: $flow.pendingName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onSubmit { flow.advance() }
            }
        case .password:
            VStack(alignment: .leading, spacing: 14) {
                heading(text.passwordTitle, text.passwordBody)
                SecureField(text.passwordPlaceholder, text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onSubmit(save)
            }
        case .complete:
            hero(symbol: "checkmark.circle", title: text.completeTitle,
                 body: flow.mode == .firstRun ? text.completeBody : "", tint: ZenithStatus.success)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            if flow.showsBack {
                Button(flow.mode == .firstRun ? text.back : text.cancel) { flow.back() }
                    .keyboardShortcut(.cancelAction)
            } else if flow.step == .enroll {
                Button(flow.mode == .firstRun ? text.back : text.cancel) { flow.back() }
                    .keyboardShortcut(.cancelAction)
            }
            Spacer()
            switch flow.step {
            case .enroll:
                EmptyView()
            case .complete:
                Button(text.done) { flow.cancel() }.keyboardShortcut(.defaultAction)
            case .securityNotice:
                Button(text.understand) { flow.advance() }.keyboardShortcut(.defaultAction)
            case .password:
                Button(flow.isSaving ? text.saving : text.confirm, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || flow.isSaving)
            default:
                Button(text.next) { flow.advance() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!flow.canAdvance)
            }
        }
        .controlSize(.large)
    }

    private func save() {
        guard !password.isEmpty else { return }
        let typed = password
        flow.finish(password: typed)
    }

    // MARK: Pieces

    private func hero(symbol: String, title: String, body: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(tint)
                .frame(width: 84, height: 84)
                .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(ZenithSurface.tileStroke))
                .padding(.bottom, 6)
            Text(title)
                .font(ZenithType.pageTitle)
                .tracking(ZenithType.pageTitleTracking)
            if !body.isEmpty {
                Text(body)
                    .font(ZenithType.pageSubtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func heading(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ZenithType.display)
                .tracking(ZenithType.pageTitleTracking / 2)
            Text(body)
                .font(ZenithType.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    private func permission(symbol: String, title: String, detail: String, granted: Bool,
                            action: @escaping () -> Void) -> some View {
        // A row of the setup window, not of Settings: drawn here so Settings
        // search does not index it.
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .background(ZenithSurface.tileFill, in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                    .strokeBorder(ZenithSurface.tileStroke))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ZenithType.rowTitle)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if granted {
                Label(text.allowed, systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(ZenithType.footnote)
                    .foregroundStyle(ZenithStatus.success)
            } else {
                Button(text.allow, action: action)
            }
        }
        .padding(16)
        .background(ZenithSurface.cardFill, in: shape)
        .overlay(shape.strokeBorder(ZenithSurface.hairline))
    }

    private func message(_ problem: FaceUnlockOnboardingFlow.Problem) -> String {
        switch problem {
        case .nameEmpty: return text.nameEmpty
        case .nameTaken(let name): return text.named(text.nameTaken, name)
        case .recognitionUnavailable: return text.recognitionMissing
        case .saveFailed: return text.errorSave
        case .security(let error): return text.error(error)
        }
    }
}

/// The camera in a circle, a ring of eight marks lit as each direction is
/// captured, a marker where the head points, a soft sweep toward the next
/// direction (Glance's ring and direction sweep, drawn in the window), and
/// the guidance line under it.
private struct FaceUnlockEnrollView: View {
    @ObservedObject var flow: FaceUnlockOnboardingFlow
    let text: ZenithFaceUnlockStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diameter: CGFloat = 220
    private var progress: FaceUnlockEnrollmentProgress { flow.progress }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ring
                if let driver = flow.cameraPreview(), progress.cameraError == nil {
                    driver.cameraPreview()
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .opacity(flow.showsCaptured ? 0 : 1)
                } else {
                    Circle().fill(ZenithSurface.tileFill).frame(width: diameter, height: diameter)
                }
                if flow.showsCaptured {
                    Image(systemName: "checkmark")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(ZenithStatus.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: diameter + 70, height: diameter + 70)
            .animation(ZenithMotion.respecting(ZenithMotion.spring()), value: flow.showsCaptured)
            Text(progress.cameraError ?? text.guidance(progress))
                .font(ZenithType.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .id(progress.cameraError ?? text.guidance(progress))
                .transition(.opacity)
                .animation(ZenithMotion.respecting(ZenithMotion.reveal(ZenithMotion.fast)),
                           value: text.guidance(progress))
            ProgressView(value: progress.fraction).frame(width: 180)
        }
        .frame(maxWidth: .infinity)
    }

    private var ring: some View {
        ZStack {
            ForEach(FaceUnlockEnrollmentPose.allCases.filter { $0 != .center }, id: \.self) { pose in
                let lit = progress.captured.contains(pose)
                let current = progress.pose == pose
                Capsule()
                    .fill(lit ? ZenithStatus.success : Color.primary.opacity(current ? 0.55 : 0.18))
                    .frame(width: 5, height: lit || current ? 18 : 12)
                    .offset(y: -(diameter / 2 + 20))
                    .rotationEffect(.degrees(pose.compassAngle ?? 0))
                    .animation(ZenithMotion.respecting(ZenithMotion.spring()), value: lit)
            }
            if let turn = progress.headTurn {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 9, height: 9)
                    .offset(y: -(diameter / 2 + 8 + 12 * CGFloat(turn.progress)))
                    .rotationEffect(.degrees(turn.angle))
                    .animation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast)), value: turn)
            }
            if let angle = progress.pose?.compassAngle, !progress.isComplete, !reduceMotion {
                FaceUnlockDirectionSweep(diameter: diameter + 40)
                    .rotationEffect(.degrees(angle))
                    .id(angle)
            }
        }
    }
}

/// A soft arc of light that runs out toward the asked direction, over and
/// over: the motion is the cue, not an arrow (Glance's direction sweep, in
/// the window rather than across the screen).
private struct FaceUnlockDirectionSweep: View {
    let diameter: CGFloat
    @State private var travelled = false

    var body: some View {
        Circle()
            // A 22° arc, turned so its middle points up before the caller turns it.
            .trim(from: 0, to: 0.06)
            .stroke(Color.accentColor.opacity(0.55), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(-90 - 0.06 * 180))
            .frame(width: diameter, height: diameter)
            .scaleEffect(travelled ? 1.08 : 0.92)
            .opacity(travelled ? 0 : 1)
            .blur(radius: 4)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { travelled = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
