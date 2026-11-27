// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import AppKit
import SwiftUI

// Zenith fork: Settings → Face Unlock, a page of its own (Glance's General,
// Recognition, Camera, Your Face and Password pages in one), built with the
// Settings kit. The switch in the hero, setup as a callout until it is done,
// the session, what starts a scan and the camera (how long and how it
// retries under More options), recognition, the animation, the faces (Face
// Lab under More options), the password, and the notes that say what this
// trades away.

struct FaceUnlockSettingsPage: View {
    @ObservedObject private var session = FaceUnlockRuntime.shared.session
    @AppStorage(DefaultsKey.faceUnlockEnabled) private var enabled = false
    @AppStorage(DefaultsKey.faceUnlockNoticeAccepted) private var noticeAccepted = false
    @AppStorage(DefaultsKey.faceUnlockTriggers) private var triggersValue = FaceUnlockTriggers.defaultEncoded
    @AppStorage(DefaultsKey.faceUnlockAutoLockDays) private var autoLockDays = FaceUnlockAutoLock.sevenDays.rawValue
    @AppStorage(DefaultsKey.faceUnlockLivenessEnabled) private var livenessEnabled = true
    @AppStorage(DefaultsKey.faceUnlockLivenessMode) private var livenessMode = FaceUnlockLivenessLevel.light.rawValue
    @AppStorage(DefaultsKey.faceUnlockMatchThreshold) private var matchThreshold = FaceUnlockMatchLevel.standard.threshold
    @AppStorage(DefaultsKey.faceUnlockCameraID) private var cameraID = ""
    @AppStorage(DefaultsKey.faceUnlockDetectionSeconds) private var detectionSeconds = FaceUnlockPreferences.defaultDetectionSeconds
    @AppStorage(DefaultsKey.faceUnlockMinimumFaceWidth) private var minimumFaceWidth = FaceUnlockDistanceLevel.standard.minimumFaceWidth
    @AppStorage(DefaultsKey.faceUnlockRetryOnHover) private var retryOnHover = true
    @AppStorage(DefaultsKey.faceUnlockAutoRetry) private var autoRetry = false
    @AppStorage(DefaultsKey.faceUnlockAnimationStyle) private var animationStyle = FaceUnlockAnimationStyle.original.rawValue

    @State private var faces: [FaceUnlockFace]?
    @State private var cameras: [FaceUnlockOnboardingFlow.Camera] = []
    @State private var inputMonitoring = FaceUnlockSpaceKeyMonitor.access
    @State private var renaming: FaceUnlockFace?
    @State private var newName = ""
    @State private var renameProblem: String?
    @State private var deleting: FaceUnlockFace?
    @State private var confirmsRemovePassword = false
    @State private var confirmsReset = false
    @State private var faceError: String?

    private let text = ZenithStrings.faceUnlock(.enUS)
    private let page = ZenithStrings.everyday(.enUS)

    private var supported: Bool { FaceUnlockRuntime.isSupported }
    private var recognition: Bool { FaceUnlockSetup.isRecognitionAvailable }
    private var triggers: Set<FaceUnlockTrigger> { FaceUnlockTriggers.decode(triggersValue) }
    private var isSetUp: Bool { session.hasPassword && noticeAccepted }

    private static let animationID = "zenith.preview.animation" // Zenith fork

    var body: some View {
        ScrollViewReader { proxy in // Zenith fork: the preview card scrolls to its settings
        ScrollView {
            ZenithPageColumn {
                hero
                    .zenithSectionAnchor(.zenithFaceUnlock, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
                if !supported {
                    ZenithCallout(.warning, text.unsupported)
                } else if !isSetUp {
                    ZenithCallout(.info, title: text.setUp,
                                  recognition ? text.setUpCaption : text.recognitionMissing) {
                        Button(text.setUp) { FaceUnlockSetupWindow.startFirstRun() }
                            .disabled(!recognition)
                    }
                }
                ZenithFaceUnlockPreviewCard { // Zenith fork: the shared preview card
                    if isSetUp {
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Self.animationID, anchor: .center) }
                    } else {
                        SettingsRouter.shared.request(FeatureSettingsDestination(.faceUnlock, sectionAnchor: .zenithFaceUnlock))
                    }
                }
                if isSetUp {
                    sessionSection
                    triggersSection
                    recognitionSection
                    animationSection.id(Self.animationID)
                    facesSection
                    passwordSection
                }
                notesSection
            }
        }
        }
        .onAppear {
            session.refresh()
            reloadFaces()
            cameras = FaceUnlockCameraCatalog.cameras()
            inputMonitoring = FaceUnlockSpaceKeyMonitor.access
        }
        .onReceive(NotificationCenter.default.publisher(for: .faceUnlockSessionDidChange)) { _ in reloadFaces() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            inputMonitoring = FaceUnlockSpaceKeyMonitor.access
            session.refresh()
            reloadFaces()
        }
        .sheet(item: $renaming) { face in renameSheet(face) }
        .confirmationDialog(deleting.map { text.named(text.deleteConfirm, $0.name) } ?? "",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(text.delete, role: .destructive) {
                if let face = deleting { perform { try FaceUnlockSetup.faces?.delete(face.id) } }
                deleting = nil
            }
            Button(text.cancel, role: .cancel) { deleting = nil }
        }
    }

    // MARK: Hero

    /// The switch, once Face Unlock can run here. Turning it on before setup
    /// runs the setup instead.
    @ViewBuilder private var hero: some View {
        if supported {
            ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                       isOn: Binding(get: { enabled && isSetUp }, set: setEnabled),
                       switchLabel: text.enable, switchHint: text.enableCaption, animation: .faceUnlock)
                .disabled(!recognition && !isSetUp)
        } else {
            ZenithHero(title: text.title, subtitle: text.subtitle, animation: .faceUnlock)
        }
    }

    private var chips: [ZenithChip] {
        guard isSetUp else { return [ZenithChip(page.faceNotSetUp)] }
        var chips = [ZenithChip(session.isUnlocked ? text.sessionOpen : text.sessionLocked,
                                dot: session.isUnlocked ? ZenithStatus.success : nil)]
        if let faces { chips.append(ZenithChip(page.faceCount(faces.count))) }
        return chips
    }

    /// Turning it on before setup runs the setup, which turns it on at the end.
    private func setEnabled(_ on: Bool) {
        if on, !isSetUp {
            FaceUnlockSetupWindow.startFirstRun()
            return
        }
        enabled = on
        FaceUnlockRuntime.shared.sync()
    }

    // MARK: Session

    private var sessionSection: some View {
        ZenithSection(text.session) {
            if session.isUnlocked {
                ZenithRow(text.sessionOpen, info: text.sessionOpenCaption, button: text.lockNow) {
                    session.lockSession()
                }
            } else {
                ZenithRow(text.sessionLocked, info: text.sessionLockedCaption) {
                    Button(session.isAuthenticating ? text.authenticating : text.unlockWithTouchID) {
                        session.unlockSession(reason: text.reasonOpen) { _ in reloadFaces() }
                    }
                    .disabled(session.isAuthenticating)
                }
            }
            if let error = session.lastError {
                ZenithRowStatus(text: text.error(error), symbol: "xmark.octagon.fill", color: ZenithStatus.error)
            }
            ZenithRow(text.autoLock, selection: $autoLockDays,
                      essential: autoLockDays == FaceUnlockAutoLock.never.rawValue ? text.neverCaption : nil) {
                ForEach(FaceUnlockAutoLock.allCases) { value in
                    Text(text.autoLockTitle(value)).tag(value.rawValue)
                }
            }
        }
    }

    // MARK: Triggers and scanning

    private var triggersSection: some View {
        ZenithSection(text.triggers, footer: text.triggersCaption) {
            ZenithRow(text.onLock, isOn: trigger(.onLock))
            ZenithRow(text.onWake, isOn: trigger(.onWake))
            ZenithRow(text.onHover, isOn: trigger(.onHover))
            ZenithRow(text.onSpace, isOn: trigger(.onSpace),
                      essential: triggers.contains(.onSpace) && inputMonitoring != .granted ? text.spaceAccess : nil)
            if triggers.contains(.onSpace), inputMonitoring != .granted {
                Button(text.openInputMonitoring) { Self.openPrivacyPane("Privacy_ListenEvent") }
                    .padding(.vertical, 8)
            }
            ZenithRow(text.camera, selection: $cameraID) {
                Text(text.systemDefault).tag("")
                ForEach(cameras) { camera in Text(camera.name).tag(camera.id) }
                // A chosen camera that is unplugged keeps its place in the menu.
                if !cameraID.isEmpty, !cameras.contains(where: { $0.id == cameraID }) {
                    Text(cameraID).tag(cameraID)
                }
            }
            .onChange(of: cameraID) { _, value in
                // Empty is the system default: no key, as recognition reads it.
                if value.isEmpty { UserDefaults.standard.removeObject(forKey: DefaultsKey.faceUnlockCameraID) }
            }
            ZenithMoreOptions(id: "faceUnlock.scanning") {
                ZenithRow(text.scanDuration, selection: $detectionSeconds) {
                    ForEach(Array(FaceUnlockPreferences.detectionRange), id: \.self) { seconds in
                        Text(text.seconds(seconds)).tag(seconds)
                    }
                }
                ZenithRow(text.retryOnHover, isOn: $retryOnHover)
                ZenithRow(text.autoRetry, isOn: $autoRetry)
            }
        }
    }

    private func trigger(_ trigger: FaceUnlockTrigger) -> Binding<Bool> {
        Binding(get: { triggers.contains(trigger) }, set: { on in
            triggersValue = FaceUnlockTriggers.encode(FaceUnlockTriggers.toggled(trigger, on: on, in: triggers))
            // Input Monitoring is asked for only on turning "On space" on.
            if trigger == .onSpace, on, FaceUnlockSpaceKeyMonitor.access == .notDetermined {
                FaceUnlockSpaceKeyMonitor.requestAccess()
                // The answer lands just after the call returns.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    inputMonitoring = FaceUnlockSpaceKeyMonitor.access
                }
            }
            FaceUnlockRuntime.shared.sync()
        })
    }

    // MARK: Recognition

    private var recognitionSection: some View {
        ZenithSection(text.recognition) {
            ZenithRow(text.matchStrictness, selection: Binding(
                get: { FaceUnlockMatchLevel.nearest(to: matchThreshold) },
                set: { matchThreshold = $0.threshold })) {
                ForEach(FaceUnlockMatchLevel.allCases) { level in Text(text.match(level)).tag(level) }
            }
            ZenithRow(text.detectionDistance, selection: Binding(
                get: { FaceUnlockDistanceLevel.nearest(to: minimumFaceWidth) },
                set: { minimumFaceWidth = $0.minimumFaceWidth }), info: text.detectionDistanceCaption) {
                ForEach(FaceUnlockDistanceLevel.allCases) { level in Text(text.distance(level)).tag(level) }
            }
            ZenithRow(text.liveness, isOn: $livenessEnabled, info: text.livenessCaption)
            ZenithRow(text.livenessLevel, selection: $livenessMode,
                      info: livenessMode == FaceUnlockLivenessLevel.heavy.rawValue ? text.heavyCaption : text.lightCaption) {
                ForEach(FaceUnlockLivenessLevel.allCases) { level in Text(text.liveness(level)).tag(level.rawValue) }
            }
            .disabled(!livenessEnabled)
            .opacity(livenessEnabled ? 1 : 0.45)
        }
    }

    // MARK: Animation

    private var animationSection: some View {
        ZenithSection(text.animation) {
            ZenithRow(text.animation, selection: $animationStyle,
                      essential: animationStyle == FaceUnlockAnimationStyle.none.rawValue ? text.noAnimationCaption : nil) {
                ForEach(FaceUnlockAnimationStyle.allCases) { style in Text(text.animation(style)).tag(style.rawValue) }
            }
        }
    }

    // MARK: Faces

    private var facesSection: some View {
        ZenithSection(text.faces, footer: text.facesCaption) {
            if let faces {
                if faces.isEmpty {
                    Text(text.facesEmpty).font(ZenithType.body).foregroundStyle(.secondary).padding(.vertical, 8)
                }
                ForEach(faces) { face in faceRow(face) }
                if !faces.isEmpty, !faces.contains(where: \.isEnabled) {
                    ZenithRowStatus(text: text.facesNoneOn, symbol: "exclamationmark.triangle.fill",
                                    color: ZenithStatus.warning)
                }
            } else {
                Text(text.facesLocked).font(ZenithType.body).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            if let faceError {
                ZenithRowStatus(text: faceError, symbol: "xmark.octagon.fill", color: ZenithStatus.error)
            }
            HStack {
                Spacer()
                Button(text.addFace) { FaceUnlockSetupWindow.startAddFace() }
                    .disabled(!recognition)
            }
            .padding(.vertical, 8)
            ZenithMoreOptions(id: "faceUnlock") {
                ZenithRow(text.lab, info: text.labCaption, button: text.openLab) { FaceUnlockLab.open() }
                    .disabled(!recognition)
            }
        }
    }

    private func faceRow(_ face: FaceUnlockFace) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle").font(.system(size: 18)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(face.name).font(ZenithType.rowTitle)
                if face.needsRecapture {
                    Text(text.recapture).font(ZenithType.caption).foregroundStyle(ZenithStatus.warning)
                } else {
                    Text(face.createdAt, format: .dateTime.day().month().year())
                        .font(ZenithType.mono(10)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(text.rename) {
                newName = face.name
                renameProblem = nil
                renaming = face
            }
            Button(text.delete) { deleting = face }
            ZenithSwitch(isOn: Binding(get: { face.isEnabled }, set: { on in
                perform { try FaceUnlockSetup.faces?.setEnabled(face.id, on) }
            }))
            .accessibilityRepresentation {
                Toggle(face.name, isOn: Binding(get: { face.isEnabled }, set: { on in
                    perform { try FaceUnlockSetup.faces?.setEnabled(face.id, on) }
                }))
            }
        }
        .padding(.vertical, 8)
    }

    private func renameSheet(_ face: FaceUnlockFace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text.rename).font(ZenithType.title)
            TextField(text.namePlaceholder, text: $newName).textFieldStyle(.roundedBorder).frame(width: 280)
            if let renameProblem {
                Text(renameProblem).font(ZenithType.caption).foregroundStyle(ZenithStatus.error)
            }
            HStack {
                Spacer()
                Button(text.cancel) { renaming = nil }.keyboardShortcut(.cancelAction)
                Button(text.save) { rename(face) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func rename(_ face: FaceUnlockFace) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            renameProblem = text.nameEmpty
            return
        }
        guard FaceUnlockSetup.faces?.nameIsTaken(name, excluding: face.id) != true else {
            renameProblem = text.named(text.nameTaken, name)
            return
        }
        perform { try FaceUnlockSetup.faces?.rename(face.id, to: name) }
        renaming = nil
    }

    private func reloadFaces() {
        FaceUnlockSetup.faces?.reload()
        faces = FaceUnlockSetup.faces?.faces
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
            faceError = nil
        } catch {
            faceError = (error as? FaceUnlockSecurityError).map(text.error) ?? String(describing: error)
        }
        reloadFaces()
    }

    // MARK: Password

    private var passwordSection: some View {
        ZenithSection(text.password) {
            if session.hasPassword {
                ZenithRow(text.passwordStored) {
                    HStack(spacing: 8) {
                        Button(text.changePassword) { FaceUnlockSetupWindow.startPasswordChange() }
                        Button(text.removePassword) { confirmsRemovePassword = true }
                    }
                }
            } else {
                ZenithRow(text.passwordMissing, button: text.setPassword) {
                    FaceUnlockSetupWindow.startPasswordChange()
                }
            }
            ZenithRow(text.reset, essential: text.resetCaption, button: text.resetButton, role: .destructive) {
                confirmsReset = true
            }
            .confirmationDialog(text.resetConfirm, isPresented: $confirmsReset) {
                Button(text.resetButton, role: .destructive, action: resetAll)
                Button(text.cancel, role: .cancel) {}
            }
        }
        .confirmationDialog(text.removePasswordConfirm, isPresented: $confirmsRemovePassword) {
            Button(text.removePassword, role: .destructive) { session.removePassword() }
            Button(text.cancel, role: .cancel) {}
        }
    }

    /// Faces first: once the key is gone they could not be deleted through it.
    private func resetAll() {
        FaceUnlockSetup.faces?.deleteAll()
        session.resetAll()
        enabled = false
        noticeAccepted = false
        FaceUnlockRuntime.shared.sync()
        reloadFaces()
    }

    // MARK: Notes

    /// What Face Unlock trades away; always in view, set up or not.
    private var notesSection: some View {
        ZenithSection(text.notes) {
            note(symbol: "exclamationmark.shield", text.noteSecurity, color: ZenithStatus.warning)
            note(symbol: "play.rectangle", text.noteVideo, color: ZenithStatus.warning)
            note(symbol: "keyboard", text.noteTyping, color: ZenithStatus.warning)
            note(symbol: "key.horizontal", text.noteStorage, color: ZenithStatus.info)
        }
    }

    // MARK: Pieces

    private func note(symbol: String, _ string: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            Text(string)
                .font(ZenithType.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    static func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The cameras the picker offers, from recognition's catalog (built-in,
/// external and Continuity), listed without turning any on or asking for access.
enum FaceUnlockCameraCatalog {
    static func cameras() -> [FaceUnlockOnboardingFlow.Camera] {
        FaceCameraCatalog.availableDevices().map { .init(id: $0.id, name: $0.name) }
    }
}
