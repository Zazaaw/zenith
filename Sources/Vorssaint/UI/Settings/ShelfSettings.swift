// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Settings → Shelf. Zenith fork: rebuilt with the Settings kit. The switch
/// is the hero's, then the preview, where the shelf opens as pictures, how
/// to open it (rarer ways under More options), what a drop does, the apps
/// it never opens over, and the island's drop zones with Transform's
/// watermark.
struct ShelfSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var shelf = ShelfService.shared
    @AppStorage(DefaultsKey.shelfEnabled) private var enabled = false
    @AppStorage(DefaultsKey.shelfShortcutEnabled) private var shortcutEnabled = true
    @AppStorage(DefaultsKey.shelfShortcutAddsFinderSelection) private var shortcutAddsFinderSelection = false
    @AppStorage(DefaultsKey.shelfShakeToOpen) private var shake = true
    @AppStorage(DefaultsKey.shelfDropZoneEnabled) private var dropZone = true
    @AppStorage(DefaultsKey.shelfDockPlacement) private var dockPlacement = ShelfDockPlacement.menuBar.rawValue
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(DefaultsKey.shelfEdgeDragEnabled) private var edgeDrag = false
    @AppStorage(DefaultsKey.shelfCloseAfterDrop) private var closeAfterDrop = false
    @AppStorage(DefaultsKey.shelfRemoveAfterDrop) private var removeAfterDrop = true
    @AppStorage(DefaultsKey.shelfClearOnClose) private var clearOnClose = false
    @AppStorage(DefaultsKey.notchShelf) private var opensInIsland = true
    @AppStorage(GlobalShortcutRole.shelf.storageKey) private var shortcutRaw =
        GlobalShortcutRole.shelf.defaultShortcut.storageValue
    @State private var showingAppPicker = false
    @State private var islandShowsFiles = NotchSupport.showsFiles()
    @AppStorage(DefaultsKey.notchAirDropEnabled) private var airDrop = true
    @AppStorage(DefaultsKey.notchPhotoActionsEnabled) private var photoActions = true // Zenith fork
    @AppStorage(DefaultsKey.zenithDropZones) private var dropZones = ZenithDropZones.automatic // Zenith fork

    private let page = ZenithStrings.everyday(.enUS)

    /// Zenith fork: the zones a file dragged to the island offers, as the
    /// preview card draws them: the shelf's own first.
    private var previewTargets: [NotchDropTarget] {
        let zones = ZenithDropZones(encoded: dropZones, airDrop: airDrop, photoActions: photoActions)
        let others = zones.entries.filter(\.isOn).compactMap(\.target).filter { $0 != .files && !$0.isPhotoAction }
        return Array(([NotchDropTarget.files] + others).prefix(3))
    }

    /// Adding the Finder selection asks to control Finder, so the promise of
    /// no permission only holds while that option is off.
    private var needsNoPermission: Bool { !(shortcutEnabled && shortcutAddsFinderSelection) }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: l10n.s.shelfName, subtitle: l10n.s.shelfEnableCaption, chips: chips,
                           isOn: Binding(get: { enabled }, set: { on in
                               enabled = on
                               ShelfService.shared.syncWithPreferences()
                           }),
                           switchLabel: l10n.s.shelfEnable, animation: .shelf)
                ZenithShelfPreviewCard(targets: previewTargets) {
                    SettingsRouter.shared.request(FeatureSettingsDestination(.shelf, sectionAnchor: .zenithDropZones))
                }
                if enabled {
                    if islandShowsFiles { opensInPicker }
                    openingSection
                    behaviorSection
                    exclusionsSection
                } else {
                    howSection
                }
                // Zenith fork: every zone a drag on the island can land on (AirDrop, Transform,
                // Remove Background, Overlay and the shelf's own), switched and ordered in one section.
                ZenithDropZonesSettingsSection(islandShowsFiles: islandShowsFiles)
                // Zenith fork: Transform's watermark.
                if ZenithDropZones(encoded: dropZones, airDrop: airDrop, photoActions: photoActions).isOn(.transform) {
                    NotchWatermarkSettingsSection()
                }
                if enabled { howSection }
            }
        }
        // The island can be switched on or its modules changed elsewhere while this page is open.
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)) { _ in
            islandShowsFiles = NotchSupport.showsFiles()
        }
        .sheet(isPresented: $showingAppPicker) {
            appPickerSheet
        }
    }

    private var chips: [ZenithChip] {
        var chips: [ZenithChip] = []
        if shortcutEnabled {
            if let shortcut = GlobalShortcut(storageValue: shortcutRaw) {
                chips.append(ZenithChip(shortcut.displayString))
            }
        }
        if islandShowsFiles {
            chips.append(ZenithChip(opensInIsland ? FeatureStrings.notch(l10n.language).title
                                    : FeatureStrings.notchEditor(l10n.language).separate))
        }
        if needsNoPermission { chips.append(ZenithChip(page.shelfNoPermission)) }
        return chips
    }

    private var islandOn: Bool {
        islandEnabled && NotchSupport.isEnabled()
    }

    // MARK: Where it opens

    /// Mirrors the island page's Files choice, which only matters while the island shows Files.
    private var opensInPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(FeatureStrings.notchEditor(l10n.language).destinations)
            ZenithVisualPicker(FeatureStrings.notchEditor(l10n.language).destinations, selection: $opensInIsland,
                               options: [
                                   ZenithPickerOption(true, FeatureStrings.notch(l10n.language).title),
                                   ZenithPickerOption(false, FeatureStrings.notchEditor(l10n.language).separate),
                               ], minimumTileWidth: 150, tileHeight: 70) { island, _ in
                ShelfPlacementArt(island: island)
            }
        }
    }

    // MARK: Opening

    private var openingSection: some View {
        ZenithSection(page.shelfOpening) {
            ZenithRow(l10n.s.shelfShortcutToggle, isOn: $shortcutEnabled)
                .onChange(of: shortcutEnabled) { _, _ in ShelfService.shared.syncHotkey() }
            ShortcutPreferenceRow(role: .shelf, isEnabled: shortcutEnabled) {
                ShelfService.shared.syncHotkey()
            }
            .padding(.vertical, 8)
            if shortcutEnabled, shelf.hotkeyRegistrationFailed {
                ZenithRowStatus(text: l10n.s.shortcutUnavailable, symbol: "exclamationmark.triangle.fill",
                                color: ZenithStatus.warning)
            }
            ZenithRow(l10n.s.shelfDropZoneToggle, isOn: $dropZone,
                      info: dockPlacement == ShelfDockPlacement.topCenter.rawValue && !islandOn
                        ? l10n.s.shelfDropZoneCaptionTopCenter : l10n.s.shelfDropZoneCaption)
                .onChange(of: dropZone) { _, _ in ShelfService.shared.syncDragMonitor() }
            if dropZone {
                ZenithRow(l10n.s.shelfDockPlacement, selection: $dockPlacement,
                          essential: islandOn ? l10n.s.shelfDockIslandNote : nil) {
                    Text(l10n.s.shelfDockMenuBar).tag(ShelfDockPlacement.menuBar.rawValue)
                    Text(l10n.s.shelfDockTopCenter).tag(ShelfDockPlacement.topCenter.rawValue)
                }
                .disabled(islandOn)
                .onChange(of: dockPlacement) { _, _ in ShelfService.shared.syncDockedShelf() }
            }
            Button {
                ShelfService.shared.summon()
            } label: {
                Label(l10n.s.shelfOpenNow, systemImage: "tray.and.arrow.down")
            }
            .padding(.vertical, 8)
            ZenithMoreOptions(id: "shelf") {
                if shortcutEnabled {
                    ZenithRow(l10n.s.shelfShortcutFinderSelection, isOn: $shortcutAddsFinderSelection,
                              info: l10n.s.shelfShortcutFinderSelectionCaption,
                              essential: shortcutAddsFinderSelection ? l10n.s.cutPasteAutomationNote : nil)
                }
                ZenithRow(l10n.s.shelfShakeToggle, isOn: $shake, info: l10n.s.shelfShakeCaption)
                    .onChange(of: shake) { _, _ in ShelfService.shared.syncDragMonitor() }
                ZenithRow(l10n.s.shelfEdgeToggle, isOn: $edgeDrag, info: l10n.s.shelfEdgeCaption)
                    .onChange(of: edgeDrag) { _, _ in ShelfService.shared.syncDragMonitor() }
            }
        }
    }

    // MARK: Behaviour

    private var behaviorSection: some View {
        ZenithSection(l10n.s.shelfBehaviorTitle) {
            ZenithRow(l10n.s.shelfRemoveAfterDrop, isOn: $removeAfterDrop, info: l10n.s.shelfRemoveAfterDropCaption)
            ZenithRow(l10n.s.shelfCloseAfterDrop, isOn: $closeAfterDrop, info: l10n.s.shelfCloseAfterDropCaption)
            ZenithRow(l10n.s.shelfClearOnClose, isOn: $clearOnClose, info: l10n.s.shelfClearOnCloseCaption)
        }
    }

    // MARK: Exclusions

    private var exclusionsSection: some View {
        ZenithSection(l10n.s.shelfExclusionsTitle, footer: l10n.s.shelfExclusionsCaption) {
            if sortedExclusions.isEmpty {
                Text(l10n.s.shelfExclusionsEmpty)
                    .font(ZenithType.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            ForEach(sortedExclusions, id: \.self) { bundleID in
                HStack(spacing: 9) {
                    Image(nsImage: InstalledApps.icon(for: bundleID))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(InstalledApps.name(for: bundleID))
                    Spacer()
                    Button {
                        shelf.removeAutomaticExclusion(bundleID)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.s.shortcutClear)
                }
                .padding(.vertical, 8)
            }
            Button {
                showingAppPicker = true
            } label: {
                Label(l10n.s.autoQuitAddApp, systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .padding(.vertical, 8)
        }
    }

    private var sortedExclusions: [String] {
        shelf.automaticExclusions.sorted {
            InstalledApps.name(for: $0)
                .localizedCaseInsensitiveCompare(InstalledApps.name(for: $1)) == .orderedAscending
        }
    }

    private var appPickerSheet: some View {
        let excluded = Set(shelf.automaticExclusions)
        return AppPickerView {
            showingAppPicker = false
        } onSelect: { url in
            showingAppPicker = false
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
            shelf.addAutomaticExclusion(bundleID)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: excluded)
        }
    }

    // MARK: How it works

    private var howSection: some View {
        ZenithSection(l10n.s.shelfHowTitle) {
            ZenithStepRow(number: 1, text: l10n.s.shelfStep1)
            ZenithStepRow(number: 2, text: l10n.s.shelfStep2)
            ZenithStepRow(number: 3, text: l10n.s.shelfStep3)
        }
    }
}

/// Where the shelf opens, as a picture: inside the island at the top of the
/// screen, or as a window of its own.
private struct ShelfPlacementArt: View {
    let island: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)).frame(width: 110, height: 58)
            if island {
                Capsule().fill(Color.black).frame(width: 62, height: 20)
                    .overlay(HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.75)).frame(width: 10, height: 10)
                        }
                    })
                    .offset(y: 2)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.2)))
                    .frame(width: 54, height: 34)
                    .overlay(HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.45)).frame(width: 10, height: 12)
                        }
                    })
                    .offset(x: 18, y: 14)
            }
        }
        .frame(width: 110, height: 58)
        .accessibilityHidden(true)
    }
}
