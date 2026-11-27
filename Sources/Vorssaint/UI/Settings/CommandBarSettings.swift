// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct CommandBarSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = CommandBarService.shared
    @ObservedObject private var secureInput = SecureInputMonitor.shared
    @AppStorage(DefaultsKey.commandBarShortcutEnabled) private var shortcutEnabled = false
    @AppStorage(DefaultsKey.commandBarCompactMode) private var compactMode = false
    @AppStorage(DefaultsKey.commandBarEmojiSkinTone) private var emojiSkinTone = ""
    @AppStorage(DefaultsKey.commandBarASCIILayoutEnabled) private var asciiLayoutEnabled = false
    @AppStorage(DefaultsKey.commandBarDisabledSources) private var disabledSources = ""
    @AppStorage(DefaultsKey.commandBarAliases) private var aliasesRaw = ""
    @AppStorage(DefaultsKey.commandBarPins) private var pinsRaw = ""
    @AppStorage(DefaultsKey.commandBarHidden) private var hiddenRaw = ""
    @AppStorage(DefaultsKey.commandBarLinks) private var linksData = Data()
    @AppStorage(DefaultsKey.commandBarRowShortcuts) private var rowShortcutsRaw = ""
    @AppStorage(DefaultsKey.commandBarFileScopes) private var fileScopesRaw = ""
    @AppStorage(DefaultsKey.commandBarFileIgnores) private var fileIgnoresRaw = ""
    @State private var editing: CommandBarLink?
    @State private var ignoreDraft = ""
    @State private var showsAppShortcuts = false

    private var text: CommandBarFeatureStrings { FeatureStrings.commandBar(l10n.language) }
    /// The snippet library already says "save", "delete" and "name" in every
    /// language; saying them twice would only mean two things to keep.
    private var common: SnippetFeatureStrings { FeatureStrings.snippets(l10n.language) }
    private var editLabel: String { FeatureStrings.screenshot(l10n.language).editButton }

    /// The examples do double duty: they say what the bar can do, which no
    /// list of toggles ever manages to.
    private var examples: [String] {
        ["100 km to mi", "2+2*3", "brightness 40", "fire", "battery"].filter {
            $0 != "battery" || PowerSampler.hasInternalBattery
        }
    }

    private let page = ZenithStrings.systemApps(.enUS)

    // Zenith fork: built with the Settings kit (docs/SETTINGS-KIT.md): the
    // hero, the preview, the bar and its shortcut, what it searches, the
    // folders a file search reads, then what the person saved in it.
    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: text.pageTitle, subtitle: page.commandSubtitle, chips: chips,
                           animation: .commandBar)
                ZenithCommandBarPreviewCard()
                barSection
                ZenithSection {
                    ZenithRow(text.appCenterTitle, info: text.appCenterCaption, navigate: { showsAppShortcuts = true })
                }
                sourcesSection
                filesSection
                linksSection
                listSection(text.rowShortcutsTitle, empty: text.rowShortcutsEmpty, rows: boundRows) { entry in
                    rowShortcutRow(entry)
                }
                listSection(text.namedTitle, empty: text.namedEmpty, rows: named) { entry in
                    savedRow(entry, alias: entry.alias) { removeAlias(entry.key) }
                }
                listSection(text.pinnedTitle, empty: text.pinnedEmpty, rows: pinned) { entry in
                    savedRow(entry) { removePin(entry.key) }
                }
                ZenithSection(text.hiddenTitle) {
                    if hidden.isEmpty {
                        ZenithRow(text.hiddenEmpty) { EmptyView() }
                    }
                    ForEach(hidden, id: \.key) { entry in
                        savedRow(entry) { unhide(entry.key) }
                    }
                    ZenithRow(text.forgetAllButton, button: text.forgetAllButton) {
                        CommandBarService.shared.forgetLearnedRanking()
                    }
                }
            }
        }
        .toggleStyle(ZenithSwitchStyle())
        .observesSecureInput()
        .sheet(isPresented: $showsAppShortcuts) {
            CommandBarAppShortcutsView()
        }
        .sheet(item: $editing) { link in
            CommandBarLinkEditor(draft: link, text: text, common: common) { saved in
                save(saved)
                editing = nil
            } cancel: {
                editing = nil
            }
        }
    }

    private var chips: [ZenithChip] {
        let sources = CommandBarSource.allCases.filter {
            CommandBarPreferences.isEnabled($0, disabledRaw: disabledSources)
        }.count
        var chips = [ZenithChip(page.commandSources(sources))]
        if shortcutEnabled {
            let role = GlobalShortcutRole.commandBar
            let shortcut = GlobalShortcut(storageValue: UserDefaults.standard.string(forKey: role.storageKey) ?? "")
                ?? role.defaultShortcut
            chips.insert(ZenithChip(shortcut.displayString), at: 0)
        }
        if compactMode { chips.append(ZenithChip(text.compactModeToggle)) }
        return chips
    }

    // MARK: - The bar

    /// Opening the bar and putting it back, the shortcut that opens it, and
    /// how it looks. Neither button carries an icon: a ⌘ glyph in front of
    /// "Open the bar now" reads as the shortcut that opens it, which it is not.
    private var barSection: some View {
        ZenithSection(page.commandBar, footer: text.privacyNote) {
            ZenithRow(text.pageTitle, info: text.positionCaption + " " + text.settingsCaption) {
                HStack(spacing: 8) {
                    Button(text.openButton) {
                        CommandBarService.shared.show()
                    }
                    Button(text.resetPositionButton) {
                        CommandBarService.shared.resetPanelPosition()
                    }
                    .disabled(!service.hasCustomPosition)
                }
            }
            HStack(spacing: 6) {
                Text(text.tryTheseLabel)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                ForEach(examples, id: \.self) { example in
                    Text(example)
                        .font(.system(size: 10.5, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }
            .padding(.vertical, 10)
            // Not the shared "Global shortcut" label the other feature
            // pages use: this page already has an "open the bar" button, so
            // the switch has to say which of the two it arms.
            ZenithRow(text.shortcutToggle, isOn: $shortcutEnabled,
                      warning: shortcutEnabled && service.shortcutRegistrationFailed ? l10n.s.shortcutUnavailable : nil)
                .onChange(of: shortcutEnabled) { _, _ in
                    CommandBarService.shared.syncWithPreferences()
                }
            ShortcutPreferenceRow(role: .commandBar, isEnabled: shortcutEnabled) {
                CommandBarService.shared.syncWithPreferences()
            }
            .padding(.vertical, 8)
            if secureInput.holder != .off {
                SecureInputRow().padding(.vertical, 8)
            }
            // No callback: the bar reads this on every open, and opening
            // Settings has already hidden it, so the two can never be on
            // screen with a stale value between them.
            ZenithRow(text.compactModeToggle, isOn: $compactMode, info: text.compactModeCaption)
            if CommandBarPreferences.isEnabled(.emoji, disabledRaw: disabledSources) {
                ZenithRow(text.emojiSkinToneLabel, info: text.emojiSkinToneCaption) {
                    Picker(text.emojiSkinToneLabel, selection: $emojiSkinTone) {
                        ForEach(CommandBarEmoji.SkinTone.allCases) { tone in
                            Text(tone.swatch).tag(tone.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            ZenithMoreOptions(id: "commandBar") {
                // Like compact mode this needs no callback: the bar reads
                // the switch on every open, so there is no live state to sync.
                ZenithRow(text.asciiLayoutToggle, isOn: $asciiLayoutEnabled, info: text.asciiLayoutCaption)
            }
        }
    }

    // MARK: - What it searches

    private var sourcesSection: some View {
        ZenithSection(text.sourcesTitle, footer: text.sourcesCaption) {
            ForEach(CommandBarSource.allCases) { source in
                ZenithRow(title(for: source), isOn: binding(for: source))
                    .disabled(source.isAlwaysOn)
            }
        }
    }

    private var filesSection: some View {
        ZenithSection(text.filesTitle) {
            ZenithRow(text.filesAddFolder, info: text.filesCaption,
                      essential: fileScopes.isEmpty ? text.filesEmpty : nil) {
                Button {
                    addFileScope()
                } label: {
                    Label(text.filesAddFolder, systemImage: "plus")
                }
            }
            ForEach(fileScopes, id: \.self) { scope in
                ZenithRow(scope) {
                    Button(text.removeButton) { removeFileScope(scope) }
                }
            }
            ZenithMoreOptions(id: "commandBar.files") {
                ZenithRow(text.filesIgnoreCaption) { EmptyView() }
                ForEach(fileIgnores, id: \.self) { pattern in
                    ZenithRow(pattern) {
                        Button(text.removeButton) { removeFileIgnore(pattern) }
                    }
                }
                HStack(spacing: 8) {
                    TextField(text.filesIgnorePlaceholder, text: $ignoreDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addFileIgnore() }
                    Button(text.filesIgnoreAdd) { addFileIgnore() }
                        .disabled(ignoreDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - What the person saved

    private var linksSection: some View {
        ZenithSection(text.linksTitle) {
            if links.isEmpty {
                ZenithRow(text.linksEmpty) { EmptyView() }
            }
            ForEach(links) { link in
                ZenithRow(link.name, info: link.destination) {
                    HStack(spacing: 6) {
                        Image(systemName: link.kind.symbolName)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Button(editLabel) { editing = link }
                        Button(text.removeButton) { removeLink(link) }
                    }
                }
            }
            ZenithRow(text.linkAddButton) {
                Button {
                    editing = CommandBarLink()
                } label: {
                    Label(text.linkAddButton, systemImage: "plus")
                }
            }
        }
    }

    private func listSection<Row: View>(_ title: String, empty: String, rows: [NamedRow],
                                        @ViewBuilder row: @escaping (NamedRow) -> Row) -> some View {
        ZenithSection(title) {
            if rows.isEmpty {
                ZenithRow(empty) { EmptyView() }
            }
            ForEach(rows, id: \.key) { entry in row(entry) }
        }
    }

    /// A combination another app already holds never fires, and a row
    /// showing a dead key is worse than no key, so it says so.
    private func rowShortcutRow(_ entry: NamedRow) -> some View {
        ZenithRow(entry.title,
                  warning: service.refusedRowShortcutKeys.contains(entry.key) ? l10n.s.shortcutUnavailable : nil) {
            HStack(spacing: 8) {
                Text(entry.alias)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                Button(text.removeButton) { removeRowShortcut(entry.key) }
            }
        }
    }

    private func savedRow(_ entry: NamedRow, alias: String = "", remove: @escaping () -> Void) -> some View {
        ZenithRow(entry.title) {
            HStack(spacing: 8) {
                if !alias.isEmpty {
                    Text(alias)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
                Button(text.removeButton, action: remove)
            }
        }
    }

    // MARK: - The places the person saved

    private var links: [CommandBarLink] { CommandBarLinks.decode(linksData) }

    private var boundRows: [NamedRow] {
        CommandBarRowShortcuts.decode(rowShortcutsRaw)
            .map { NamedRow(key: $0.key, title: title(forKey: $0.key), alias: $0.value.displayString) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func removeRowShortcut(_ key: String) {
        var next = CommandBarRowShortcuts.decode(rowShortcutsRaw)
        next.removeValue(forKey: key)
        rowShortcutsRaw = CommandBarRowShortcuts.encode(next) ?? ""
        CommandBarService.shared.syncWithPreferences()
    }

    private func save(_ link: CommandBarLink) {
        var next = links
        if let index = next.firstIndex(where: { $0.id == link.id }) {
            next[index] = link
        } else {
            next.append(link)
        }
        linksData = CommandBarLinks.encode(next) ?? Data()
    }

    private func removeLink(_ link: CommandBarLink) {
        linksData = CommandBarLinks.encode(links.filter { $0.id != link.id }) ?? Data()
    }

    // MARK: - The lists, resolved to something readable

    private struct NamedRow {
        let key: String
        let title: String
        let alias: String
    }

    /// A key whose row is not in the catalog right now (an app that was
    /// removed) still shows, by its key, so nothing the person set can become
    /// invisible and unremovable. An uninstalled hub feature is dropped
    /// instead: its pin is not a leftover id.
    private func title(forKey key: String) -> String {
        service.entryTitle(forStableKey: key) ?? key
    }

    private var named: [NamedRow] {
        CommandBarPreferences.decodeAliases(aliasesRaw)
            .map { NamedRow(key: $0.key, title: title(forKey: $0.key), alias: $0.value) }
            .sorted { $0.alias.localizedStandardCompare($1.alias) == .orderedAscending }
    }

    private var pinned: [NamedRow] {
        CommandBarPreferences.listedPins(
            CommandBarPreferences.decodePins(pinsRaw),
            present: service.presentStableKeys)
            .map { NamedRow(key: $0, title: title(forKey: $0), alias: "") }
    }

    private var hidden: [NamedRow] {
        CommandBarPreferences.decodeHidden(hiddenRaw)
            .sorted()
            .map { NamedRow(key: $0, title: title(forKey: $0), alias: "") }
    }

    private func binding(for source: CommandBarSource) -> Binding<Bool> {
        Binding {
            CommandBarPreferences.isEnabled(source, disabledRaw: disabledSources)
        } set: { isOn in
            var current = CommandBarPreferences.disabledSources(from: disabledSources)
            if isOn { current.remove(source) } else { current.insert(source) }
            disabledSources = CommandBarPreferences.storageValue(for: current)
            CommandBarService.shared.syncWithPreferences()
        }
    }

    private func title(for source: CommandBarSource) -> String {
        switch source {
        case .actions: return text.sourceActions
        case .apps: return text.sourceApps
        case .menus: return text.sourceMenus
        case .windows: return text.sourceWindows
        case .quitApps: return text.sourceQuitApps
        case .uninstallApps: return l10n.s.uninstallerName
        case .settingsPages: return text.sourceSettingsPages
        case .macSettings: return text.sourceMacSettings
        case .snippets: return text.sourceSnippets
        case .clipboard: return text.sourceClipboard
        case .emoji: return text.sourceEmoji
        case .folders: return text.sourceFolders
        case .answers: return text.sourceAnswers
        case .calculator: return text.sourceCalculator
        case .selection: return text.sourceSelection
        case .links: return text.linksTitle
        case .files: return text.sourceFiles
        case .killProcess: return FeatureStrings.killProcess(l10n.language).pageTitle
        }
    }

    // MARK: - The folders a file search looks in

    private var fileScopes: [String] {
        CommandBarFileSearchSupport.decodeList(fileScopesRaw)
    }

    private var fileIgnores: [String] {
        CommandBarFileSearchSupport.decodeList(fileIgnoresRaw)
    }

    /// Stored with a tilde, so a list made on one Mac still points somewhere
    /// on another and a settings export stays portable.
    private func addFileScope() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let added = panel.urls.map { ($0.path as NSString).abbreviatingWithTildeInPath }
        writeFileScopes(fileScopes + added)
    }

    private func removeFileScope(_ scope: String) {
        writeFileScopes(fileScopes.filter { $0 != scope })
    }

    private func addFileIgnore() {
        let pattern = ignoreDraft.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        ignoreDraft = ""
        writeFileIgnores(fileIgnores + [pattern])
    }

    private func removeFileIgnore(_ pattern: String) {
        writeFileIgnores(fileIgnores.filter { $0 != pattern })
    }

    /// Both lists are resolved once and kept, so typing never pays for
    /// reading them; the service is told the moment they change.
    private func writeFileScopes(_ scopes: [String]) {
        fileScopesRaw = CommandBarFileSearchSupport.encodeList(scopes)
        CommandBarService.shared.syncWithPreferences()
    }

    private func writeFileIgnores(_ patterns: [String]) {
        fileIgnoresRaw = CommandBarFileSearchSupport.encodeList(patterns)
        CommandBarService.shared.syncWithPreferences()
    }

    private func removeAlias(_ key: String) {
        var aliases = CommandBarPreferences.decodeAliases(aliasesRaw)
        aliases.removeValue(forKey: key)
        aliasesRaw = CommandBarPreferences.encodeAliases(aliases) ?? ""
    }

    private func removePin(_ key: String) {
        pinsRaw = CommandBarPreferences.encodePins(
            CommandBarPreferences.decodePins(pinsRaw).filter { $0 != key })
    }

    private func unhide(_ key: String) {
        var keys = CommandBarPreferences.decodeHidden(hiddenRaw)
        keys.remove(key)
        hiddenRaw = CommandBarPreferences.encodeHidden(keys)
        CommandBarService.shared.syncWithPreferences()
    }
}

/// Saving a place: a name to call it by, where it goes, and the words that
/// get filled in when it opens. Deliberately three fields and a picker — the
/// person has to look at it once and know what to do.
private struct CommandBarLinkEditor: View {
    @State var draft: CommandBarLink
    let text: CommandBarFeatureStrings
    let common: SnippetFeatureStrings
    let save: (CommandBarLink) -> Void
    let cancel: () -> Void

    @ObservedObject private var l10n = L10n.shared

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(text.linksTitle)
                .font(.system(size: 15, weight: .semibold))

            Picker("", selection: $draft.kind) {
                Text(text.linkKindLink).tag(CommandBarLink.Kind.link)
                Text(text.linkKindPlace).tag(CommandBarLink.Kind.place)
                Text(text.linkKindScript).tag(CommandBarLink.Kind.script)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 5) {
                Text(common.nameLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(text.linkDestinationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("", text: $draft.destination)
                        .textFieldStyle(.roundedBorder)
                    if draft.kind == .place || draft.kind == .script {
                        // Typing a path by hand is how people get it wrong.
                        Button(FeatureStrings.radialMenu(l10n.language).chooseButton) {
                            chooseDestination()
                        }
                    }
                }
            }

            if draft.kind != .script {
                VStack(alignment: .leading, spacing: 6) {
                    Text(text.linkPlaceholdersHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(CommandBarLinkPlaceholder.allCases) { placeholder in
                            Button {
                                draft.destination += placeholder.token
                            } label: {
                                VStack(spacing: 1) {
                                    Text(placeholder.token)
                                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    Text(meaning(of: placeholder))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.primary.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                            .help(meaning(of: placeholder))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text.scriptHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(text.scriptRunsWithoutArgument, isOn: $draft.runsWithoutArgument)
                        .font(.caption)
                    Toggle(text.scriptRunsDirectly, isOn: $draft.runsDirectly)
                        .font(.caption)
                }
            }

            HStack {
                Spacer()
                Button(l10n.s.uninstallerCancel, action: cancel)
                Button(common.saveButton) {
                    var clean = draft
                    clean.name = clean.name.trimmingCharacters(in: .whitespaces)
                    clean.destination = clean.destination.trimmingCharacters(in: .whitespaces)
                    save(clean)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func meaning(of placeholder: CommandBarLinkPlaceholder) -> String {
        switch placeholder {
        case .query: return text.placeholderQuery
        case .clipboard: return text.placeholderClipboard
        case .selection: return text.placeholderSelection
        case .date: return text.placeholderDate
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        // A script is a file, never a folder; a place can be either.
        panel.canChooseDirectories = draft.kind == .place
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        draft.destination = url.path
        if draft.name.isEmpty { draft.name = url.lastPathComponent }
    }
}
