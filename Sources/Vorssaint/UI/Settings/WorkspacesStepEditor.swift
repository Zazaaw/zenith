// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: a workspace's steps in Settings → Workspaces. Each step is a
// row with its glyph on a soft tile, buttons that move or remove it and a
// switch that skips it, and under it what the step does: apps to open (each
// with an optional folder, file or link), apps to quit, windows to place with
// Window Layout's positions, Keep Awake on or off, a Shortcut for Focus, a
// sound output and volume, a wallpaper, a link.

struct WorkspacesStepEditor: View {
    let workspace: Workspace
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WorkspaceService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: ZenithWorkspacesStrings { ZenithStrings.workspaces(l10n.language) }

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: ZenithMotion.fast) : ZenithMotion.spring()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(text.steps)
                    .font(ZenithType.sectionTitle)
                    .tracking(ZenithType.sectionTitleTracking)
                    .padding(.leading, 2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Menu {
                    ForEach(WorkspaceStep.Kind.allCases, id: \.self) { kind in
                        Button { add(kind) } label: { Label(kind.title(text), systemImage: kind.symbol) }
                    }
                } label: {
                    Label(text.addStep, systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            SettingsCard {
                if workspace.steps.isEmpty {
                    Text(text.noSteps)
                        .font(ZenithType.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(workspace.steps.enumerated()), id: \.element.id) { index, step in
                            VStack(alignment: .leading, spacing: 0) {
                                if index > 0 { hairline.padding(.vertical, 12) }
                                row(step, index: index, count: workspace.steps.count)
                            }
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        }
                    }
                }
            }
        }
    }

    // MARK: Row

    private func row(_ step: WorkspaceStep, index: Int, count: Int) -> some View {
        let title = step.kind.title(text)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZenithIslandGlyphTile(symbol: step.kind.symbol, tint: ZenithIslandPalette.color(hex: workspace.color.hex), size: 26)
                    .saturation(step.isEnabled ? 1 : 0)
                    .opacity(step.isEnabled ? 1 : 0.5)
                Text(title)
                    .font(ZenithType.rowTitle)
                    .foregroundStyle(step.isEnabled ? .primary : .secondary)
                Spacer(minLength: 8)
                iconButton("chevron.up", text.moveUp, enabled: index > 0) { move(step.id, by: -1) }
                iconButton("chevron.down", text.moveDown, enabled: index < count - 1) { move(step.id, by: 1) }
                iconButton("trash", text.remove, enabled: true) { remove(step.id) }
                Toggle(title, isOn: Binding(get: { step.isEnabled }, set: { on in change(step.id) { $0.isEnabled = on } }))
                    .labelsHidden()
                    .toggleStyle(ZenithSwitchStyle())
            }
            detail(step)
                .padding(.leading, 36)
                .disabled(!step.isEnabled)
                .opacity(step.isEnabled ? 1 : 0.45)
        }
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if index > 0 { Button(text.moveUp) { move(step.id, by: -1) } }
            if index < count - 1 { Button(text.moveDown) { move(step.id, by: 1) } }
            Button(text.remove) { remove(step.id) }
        }
    }

    @ViewBuilder
    private func detail(_ step: WorkspaceStep) -> some View {
        switch step.action {
        case .openApps(let apps):
            appList(apps, step: step, withTargets: true) { $0.action = .openApps($1) }
        case .hideOthers:
            caption(text.hideHint)
        case .quitApps(let apps):
            VStack(alignment: .leading, spacing: 8) {
                appList(apps, step: step, withTargets: false) { $0.action = .quitApps($1) }
                caption(text.quitHint)
            }
        case .arrange(let arrangements):
            arrangementList(arrangements, step: step)
        case .keepAwake(let on):
            Picker(text.keepAwake, selection: Binding(get: { on }, set: { value in change(step.id) { $0.action = .keepAwake(value) } })) {
                Text(text.on).tag(true)
                Text(text.off).tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 200)
        case .focus(let name):
            VStack(alignment: .leading, spacing: 6) {
                TextField(text.shortcutName, text: Binding(get: { name },
                                                          set: { value in change(step.id) { $0.action = .focus(shortcut: value) } }))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(WorkspaceShortcutsCommand.displayed(name))
                        .font(ZenithType.mono(11))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                caption(text.focusHint)
            }
        case .sound(let sound):
            WorkspaceSoundEditor(sound: sound, text: text) { value in change(step.id) { $0.action = .sound(value) } }
        case .wallpaper(let path):
            HStack(spacing: 10) {
                if path.isEmpty {
                    Text(text.noImage).font(ZenithType.body).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                    Text((path as NSString).lastPathComponent)
                        .font(ZenithType.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(path)
                }
                Spacer(minLength: 8)
                Button(text.chooseImage) {
                    if let chosen = WorkspacePickers.chooseImage() { change(step.id) { $0.action = .wallpaper(path: chosen) } }
                }
            }
        case .openURL(let link):
            TextField("https://", text: Binding(get: { link }, set: { value in change(step.id) { $0.action = .openURL(value) } }))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
        }
    }

    // MARK: Apps

    private func appList(_ apps: [WorkspaceApp], step: WorkspaceStep, withTargets: Bool,
                         save: @escaping (inout WorkspaceStep, [WorkspaceApp]) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(apps.enumerated()), id: \.offset) { index, app in
                HStack(spacing: 8) {
                    appLabel(app)
                    if withTargets {
                        TextField(text.targetPlaceholder, text: Binding(get: { app.target }, set: { value in
                            var next = apps
                            next[index].target = value
                            change(step.id) { save(&$0, next) }
                        }))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                        iconButton("folder", text.targetPlaceholder, enabled: true) {
                            guard let chosen = WorkspacePickers.chooseTarget() else { return }
                            var next = apps
                            next[index].target = chosen
                            change(step.id) { save(&$0, next) }
                        }
                    }
                    iconButton("xmark", text.remove, enabled: true) {
                        var next = apps
                        next.remove(at: index)
                        withAnimation(motion) { change(step.id) { save(&$0, next) } }
                    }
                }
            }
            addAppButton {
                let chosen = WorkspacePickers.chooseApps().filter { new in !apps.contains { $0.identity == new.identity } }
                guard !chosen.isEmpty else { return }
                withAnimation(motion) { change(step.id) { save(&$0, apps + chosen) } }
            }
        }
    }

    private func arrangementList(_ arrangements: [WorkspaceArrangement], step: WorkspaceStep) -> some View {
        let layoutText = FeatureStrings.windowLayout(l10n.language)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(arrangements.enumerated()), id: \.offset) { index, arrangement in
                HStack(spacing: 8) {
                    appLabel(arrangement.app)
                    Picker(text.arrange, selection: Binding(get: { Self.tag(arrangement.placement) }, set: { tag in
                        guard let action = WindowLayoutAction(rawValue: tag) else { return }
                        var next = arrangements
                        next[index].placement = .layout(action)
                        change(step.id) { $0.action = .arrange(next) }
                    })) {
                        if case .frame = arrangement.placement {
                            Text(text.capturedPlace).tag(Self.frameTag)
                        }
                        ForEach(WorkspacePlacement.layouts, id: \.self) { action in
                            Label(action.title(layoutText), systemImage: action.symbolName).tag(action.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    iconButton("xmark", text.remove, enabled: true) {
                        var next = arrangements
                        next.remove(at: index)
                        withAnimation(motion) { change(step.id) { $0.action = .arrange(next) } }
                    }
                }
            }
            addAppButton {
                let chosen = WorkspacePickers.chooseApps()
                    .filter { new in !arrangements.contains { $0.app.identity == new.identity } }
                    .map { WorkspaceArrangement(app: $0, placement: .layout(.maximize)) }
                guard !chosen.isEmpty else { return }
                withAnimation(motion) { change(step.id) { $0.action = .arrange(arrangements + chosen) } }
            }
            caption(text.arrangeHint)
        }
    }

    private static let frameTag = "zenith.captured"

    private static func tag(_ placement: WorkspacePlacement) -> String {
        switch placement {
        case .layout(let action): return action.rawValue
        case .frame: return frameTag
        }
    }

    private func appLabel(_ app: WorkspaceApp) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: WorkspacePickers.icon(app))
                .resizable()
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            Text(app.name)
                .font(ZenithType.body)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
    }

    private func addAppButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(text.addApp, systemImage: "plus.app") }
            .buttonStyle(.borderless)
    }

    // MARK: Pieces

    private func iconButton(_ symbol: String, _ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(title)
        .accessibilityLabel(title)
    }

    private func caption(_ value: String) -> some View {
        Text(value)
            .font(ZenithType.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var hairline: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).accessibilityHidden(true)
    }

    // MARK: Edits

    /// Changes one step of the workspace as it is stored now.
    private func change(_ id: UUID, _ transform: (inout WorkspaceStep) -> Void) {
        guard let current = service.workspace(workspace.id),
              var step = current.steps.first(where: { $0.id == id }) else { return }
        transform(&step)
        service.update(current.replacingStep(step))
    }

    private func add(_ kind: WorkspaceStep.Kind) {
        guard let current = service.workspace(workspace.id) else { return }
        withAnimation(motion) { service.update(current.addingStep(kind)) }
    }

    private func remove(_ id: UUID) {
        guard let current = service.workspace(workspace.id) else { return }
        withAnimation(motion) { service.update(current.removingStep(id)) }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let current = service.workspace(workspace.id) else { return }
        withAnimation(motion) { service.update(current.movingStep(id, by: offset)) }
    }
}

/// The sound step: an output device (or the current one) and, when set, a volume.
private struct WorkspaceSoundEditor: View {
    let sound: WorkspaceSound
    let text: ZenithWorkspacesStrings
    let save: (WorkspaceSound) -> Void
    @State private var devices: [WorkspaceAudio.Device] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(text.device).font(ZenithType.body)
                Spacer(minLength: 12)
                Picker(text.device, selection: Binding(get: { sound.uid }, set: { uid in
                    let name = devices.first { $0.uid == uid }?.name ?? ""
                    save(WorkspaceSound(uid: uid, name: name, volume: sound.volume))
                })) {
                    Text(text.keepCurrent).tag("")
                    ForEach(listed) { device in Text(device.name).tag(device.uid) }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
            }
            ZenithSwitchRow(text.volume, isOn: Binding(get: { sound.volume != nil }, set: { on in
                save(WorkspaceSound(uid: sound.uid, name: sound.name, volume: on ? (sound.volume ?? 0.5) : nil))
            })) {
                Text(text.volume).font(ZenithType.body)
            }
            if let volume = sound.volume {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: Binding(get: { volume }, set: { value in
                        save(WorkspaceSound(uid: sound.uid, name: sound.name, volume: value))
                    }), in: 0...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                .frame(maxWidth: 320)
                .accessibilityLabel(text.volume)
            }
        }
        .onAppear { devices = WorkspaceAudio.outputDevices() }
    }

    /// The devices connected now, and the chosen one even while it is not.
    private var listed: [WorkspaceAudio.Device] {
        guard !sound.uid.isEmpty, !devices.contains(where: { $0.uid == sound.uid }) else { return devices }
        return devices + [WorkspaceAudio.Device(uid: sound.uid, name: sound.name.isEmpty ? sound.uid : sound.name)]
    }
}
