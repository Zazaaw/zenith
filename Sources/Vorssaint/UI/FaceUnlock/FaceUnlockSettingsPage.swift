// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import AppKit
import AVFoundation
import SwiftUI

// Zenith fork: Settings → Face Unlock, a page of its own (Glance's General,
// Recognition, Camera, Your Face and Password pages in one). The switch, the
// session, what starts a scan, scanning, recognition, the animation, the
// faces, the password, Face Lab, and the notes that say what this trades
// away. Headings are drawn here and switches are ZenithSwitchRow, like the
// fork's other pages.

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

    private var supported: Bool { FaceUnlockRuntime.isSupported }
    private var recognition: Bool { FaceUnlockSetup.isRecognitionAvailable }
    private var triggers: Set<FaceUnlockTrigger> { FaceUnlockTriggers.decode(triggersValue) }
    private var isSetUp: Bool { session.hasPassword && noticeAccepted }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle)
                enableCard
                if isSetUp {
                    sessionCard
                    triggersCard
                    scanningCard
                    recognitionCard
                    animationCard
                    facesCard
                    passwordCard
                    labCard
                }
                notesCard
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
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

    // MARK: Switch

    private var enableCard: some View {
        SettingsCard {
            if !supported {
                note(symbol: "exclamationmark.triangle", text.unsupported, color: ZenithStatus.warning)
            } else {
                ZenithSwitchRow(text.enable, isOn: Binding(get: { enabled && isSetUp }, set: setEnabled)) {
                    SettingsRow(symbol: "faceid", title: text.enable, caption: text.enableCaption) { EmptyView() }
                }
                .disabled(!recognition && !isSetUp)
                if !isSetUp {
                    Divider()
                    SettingsRow(symbol: "person.crop.circle.badge.plus", title: text.setUp,
                                caption: recognition ? text.setUpCaption : text.recognitionMissing) {
                        Button(text.setUp) { FaceUnlockSetupWindow.startFirstRun() }
                            .disabled(!recognition)
                    }
                }
            }
        }
        .zenithSectionAnchor(.zenithFaceUnlock)
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

    private var sessionCard: some View {
        SettingsCard(title: text.session) {
            if session.isUnlocked {
                SettingsRow(symbol: "lock.open", title: text.sessionOpen, caption: text.sessionOpenCaption) {
                    Button(text.lockNow) { session.lockSession() }
                }
            } else {
                SettingsRow(symbol: "lock", title: text.sessionLocked, caption: text.sessionLockedCaption) {
                    Button(session.isAuthenticating ? text.authenticating : text.unlockWithTouchID) {
                        session.unlockSession(reason: text.reasonOpen) { _ in reloadFaces() }
                    }
                    .disabled(session.isAuthenticating)
                }
            }
            if let error = session.lastError {
                Text(text.error(error))
                    .font(ZenithType.caption)
                    .foregroundStyle(ZenithStatus.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, settingsRowTextInset)
            }
            Divider()
            SettingsMenuRow(symbol: "timer", title: text.autoLock, selection: $autoLockDays) {
                ForEach(FaceUnlockAutoLock.allCases) { value in
                    Text(text.autoLockTitle(value)).tag(value.rawValue)
                }
            }
            if autoLockDays == FaceUnlockAutoLock.never.rawValue {
                caption(text.neverCaption)
            }
        }
    }

    // MARK: Triggers

    private var triggersCard: some View {
        SettingsCard(title: text.triggers) {
            caption(text.triggersCaption)
            ZenithSwitchRow(text.onLock, isOn: trigger(.onLock)) {
                SettingsRow(symbol: "lock.laptopcomputer", title: text.onLock) { EmptyView() }
            }
            ZenithSwitchRow(text.onWake, isOn: trigger(.onWake)) {
                SettingsRow(symbol: "sun.max", title: text.onWake) { EmptyView() }
            }
            ZenithSwitchRow(text.onHover, isOn: trigger(.onHover)) {
                SettingsRow(symbol: "cursorarrow.rays", title: text.onHover) { EmptyView() }
            }
            ZenithSwitchRow(text.onSpace, isOn: trigger(.onSpace)) {
                SettingsRow(symbol: "space", title: text.onSpace) { EmptyView() }
            }
            if triggers.contains(.onSpace), inputMonitoring != .granted {
                VStack(alignment: .leading, spacing: 6) {
                    caption(text.spaceAccess)
                    Button(text.openInputMonitoring) {
                        Self.openPrivacyPane("Privacy_ListenEvent")
                    }
                    .padding(.leading, settingsRowTextInset)
                }
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

    // MARK: Scanning

    private var scanningCard: some View {
        SettingsCard(title: text.scanning) {
            SettingsMenuRow(symbol: "hourglass", title: text.scanDuration, selection: $detectionSeconds) {
                ForEach(Array(FaceUnlockPreferences.detectionRange), id: \.self) { seconds in
                    Text(text.seconds(seconds)).tag(seconds)
                }
            }
            ZenithSwitchRow(text.retryOnHover, isOn: $retryOnHover) {
                SettingsRow(symbol: "arrow.clockwise", title: text.retryOnHover) { EmptyView() }
            }
            ZenithSwitchRow(text.autoRetry, isOn: $autoRetry) {
                SettingsRow(symbol: "arrow.triangle.2.circlepath", title: text.autoRetry) { EmptyView() }
            }
            SettingsMenuRow(symbol: "camera", title: text.camera, selection: $cameraID) {
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
        }
    }

    // MARK: Recognition

    private var recognitionCard: some View {
        SettingsCard(title: text.recognition) {
            SettingsChoiceRow(symbol: "person.crop.square", title: text.matchStrictness, selection: Binding(
                get: { FaceUnlockMatchLevel.nearest(to: matchThreshold) },
                set: { matchThreshold = $0.threshold })) {
                ForEach(FaceUnlockMatchLevel.allCases) { level in Text(text.match(level)).tag(level) }
            }
            Divider()
            ZenithSwitchRow(text.liveness, isOn: $livenessEnabled) {
                SettingsRow(symbol: "eye", title: text.liveness, caption: text.livenessCaption) { EmptyView() }
            }
            SettingsChoiceRow(symbol: "checkmark.shield", title: text.livenessLevel, selection: $livenessMode) {
                ForEach(FaceUnlockLivenessLevel.allCases) { level in Text(text.liveness(level)).tag(level.rawValue) }
            }
            .disabled(!livenessEnabled)
            .opacity(livenessEnabled ? 1 : 0.45)
            caption(livenessMode == FaceUnlockLivenessLevel.heavy.rawValue ? text.heavyCaption : text.lightCaption)
        }
    }

    // MARK: Animation

    private var animationCard: some View {
        SettingsCard(title: text.animation) {
            SettingsChoiceRow(symbol: "sparkles", title: text.animation, selection: $animationStyle) {
                ForEach(FaceUnlockAnimationStyle.allCases) { style in Text(text.animation(style)).tag(style.rawValue) }
            }
            if animationStyle == FaceUnlockAnimationStyle.none.rawValue {
                caption(text.noAnimationCaption)
            }
        }
    }

    // MARK: Faces

    private var facesCard: some View {
        SettingsCard(title: text.faces) {
            caption(text.facesCaption)
            if let faces {
                if faces.isEmpty {
                    Text(text.facesEmpty).font(ZenithType.footnote).foregroundStyle(.secondary)
                }
                ForEach(faces) { face in faceRow(face) }
                if !faces.isEmpty, !faces.contains(where: \.isEnabled) {
                    note(symbol: "exclamationmark.triangle", text.facesNoneOn, color: ZenithStatus.warning)
                }
            } else {
                Text(text.facesLocked).font(ZenithType.footnote).foregroundStyle(.secondary)
            }
            if let faceError {
                Text(faceError).font(ZenithType.caption).foregroundStyle(ZenithStatus.error)
            }
            HStack {
                Spacer()
                Button(text.addFace) { FaceUnlockSetupWindow.startAddFace() }
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

    private var passwordCard: some View {
        SettingsCard(title: text.password) {
            if session.hasPassword {
                SettingsRow(symbol: "key", title: text.passwordStored) {
                    HStack(spacing: 8) {
                        Button(text.changePassword) { FaceUnlockSetupWindow.startPasswordChange() }
                        Button(text.removePassword) { confirmsRemovePassword = true }
                    }
                }
            } else {
                SettingsRow(symbol: "key", title: text.passwordMissing) {
                    Button(text.setPassword) { FaceUnlockSetupWindow.startPasswordChange() }
                }
            }
            Divider()
            SettingsRow(symbol: "trash", title: text.reset, caption: text.resetCaption) {
                Button(text.resetButton) { confirmsReset = true }
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

    // MARK: Face Lab

    private var labCard: some View {
        SettingsCard(title: text.lab) {
            SettingsRow(symbol: "flask", title: text.lab, caption: text.labCaption) {
                Button(text.openLab) { FaceUnlockLab.open() }
                    .disabled(!recognition)
            }
        }
    }

    // MARK: Notes

    private var notesCard: some View {
        SettingsCard(title: text.notes) {
            note(symbol: "exclamationmark.shield", text.noteSecurity, color: ZenithStatus.warning)
            note(symbol: "play.rectangle", text.noteVideo, color: ZenithStatus.warning)
            note(symbol: "keyboard", text.noteTyping, color: ZenithStatus.warning)
            note(symbol: "key.horizontal", text.noteStorage, color: ZenithStatus.info)
        }
    }

    // MARK: Pieces

    private func caption(_ string: String) -> some View {
        Text(string)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(symbol: String, _ string: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            Text(string)
                .font(ZenithType.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The cameras the picker offers: built-in, external and Continuity, listed
/// without turning any on or asking for camera access.
enum FaceUnlockCameraCatalog {
    static func cameras() -> [FaceUnlockOnboardingFlow.Camera] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                         mediaType: .video, position: .unspecified)
            .devices.map { .init(id: $0.uniqueID, name: $0.localizedName) }
    }
}
