// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings window: the floating sidebar (SettingsSidebarView) beside the
/// open page. The detail keeps each tool's existing settings and section anchor.
/// Zenith fork: the window has no visible title bar; see SettingsWindowChrome.
struct SettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.superKeySource) private var superKeySourceRaw =
        SuperKeySource.capsLock.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var directoryCache = SettingsDirectoryCache()
    @State private var sidebarShown = true
    @State private var isFullScreen = false // Zenith fork

    private var sidebarItems: [SettingsSidebarItem] {
        _ = directoryCache.navigation(
            strings: l10n.s, language: l10n.language,
            superKeySource: SuperKeySource.sanitized(superKeySourceRaw),
            featureRevision: features.revision,
            isAvailable: { features.isAvailable($0) })
        return directoryCache.items
    }

    var body: some View {
        HStack(spacing: 0) {
            if sidebarShown {
                // Zenith fork: the panel runs up to the window's top, the
                // window buttons and controls in its top row.
                SettingsSidebarView(cache: directoryCache, isFullScreen: isFullScreen,
                                    toggleSidebar: toggleSidebar)
                    .padding([.leading, .top, .bottom], SettingsWindowChrome.panelInset)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            // Pages are asked for their ideal size on a page switch. `List`
            // answers that with its full content height rather than a viewport
            // size the way `ScrollView` does, and `.frame(maxHeight: .infinity)`
            // only bounds a size it is given, not one it is asked to report -
            // so a few hundred rows (Kill Process) grew the whole window.
            // `GeometryReader` reports the real space it was actually given for
            // normal layout, and ~zero when asked for an unconstrained ideal
            // size, breaking the chain.
            GeometryReader { geometry in
                // Zenith fork: every page over the dot grid, and a large title
                // above the upstream form pages that have none of their own.
                ZenithSettingsPage(title: zenithPageTitle) {
                    detail
                        .settingsSectionFocus(for: router.page)
                }
                .environment(\.settingsPageIcon, pageIcon)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            // Zenith fork: the page starts under the window's top; with the
            // sidebar hidden it leaves room for the window buttons' row.
            .padding(.top, sidebarShown ? 0
                     : SettingsWindowChrome.topBarHeight - SettingsWindowChrome.contentDragHeight)
            .overlay(alignment: .top) {
                SettingsContentTopStrip(sidebarShown: sidebarShown, isFullScreen: isFullScreen,
                                        toggleSidebar: toggleSidebar)
            }
            .background { ZenithDotGrid() }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // Zenith fork: the window buttons leave the panel's row in full screen.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { note in
            if note.object is SettingsWindow { isFullScreen = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { note in
            if note.object is SettingsWindow { isFullScreen = false }
        }
        .frame(minWidth: 772, maxWidth: .infinity, minHeight: 528, maxHeight: .infinity)
        .onAppear { ensureVisiblePage() }
        .onChange(of: features.revision) { _, _ in ensureVisiblePage() }
        .onChange(of: router.requestID) { _, _ in ensureVisiblePage() }
    }

    private func toggleSidebar() {
        if reduceMotion {
            sidebarShown.toggle()
        } else {
            withAnimation(.snappy(duration: 0.25)) { sidebarShown.toggle() }
        }
    }

    private var selectedSidebarItem: SettingsSidebarItem.ID? {
        let items = sidebarItems
        return SettingsSidebarSupport.selection(for: router.destination, in: items,
                                                preferredID: router.sidebarFeature.map { .feature($0) })
            ?? items.first?.id
    }

    /// Zenith fork: the Orbit icon the open page's header draws: the page's
    /// own, or the tool's when General shows one of its tools on its own.
    private var pageIcon: SettingsPageIcon {
        if router.page == .general, detailShowsGeneralTool, let selected = selectedSidebarItem,
           let item = sidebarItems.first(where: { $0.id == selected }) {
            return SettingsPageIcon(id: item.id, symbol: item.icon)
        }
        return SettingsPageIcon(id: .page(router.page),
                                symbol: SettingsSidebarIcons.fallbackSymbol(page: router.page) ?? "gearshape")
    }

    /// The selected page can leave the sidebar when its last feature is
    /// switched off in the hub; fall back to the hub itself, where the
    /// feature can be brought back.
    private func ensureVisiblePage() {
        if !isPageVisible(router.page) {
            router.page = .features
            return
        }
        guard router.destination.sectionAnchor != nil,
              !sidebarItems.contains(where: { $0.destination == router.destination }) else { return }
        switch router.page {
        case .general:
            // General stays visible when one of its tools is uninstalled.
            router.request(FeatureSettingsDestination(.general), replacingVisit: true)
        case .energy:
            // Energy has no overview row. A history visit to an uninstalled
            // tool should show another available tool, not an empty detail.
            if let available = sidebarItems.first(where: { $0.destination.page == .energy }) {
                router.request(available.destination, replacingVisit: true)
            }
        default:
            break
        }
    }

    private func isPageVisible(_ page: SettingsPage) -> Bool {
        FeatureVisibilitySupport.isPageVisible(page, isAvailable: { $0.isAvailable })
    }

    /// Zenith fork: the title Settings draws above a page, nil for the pages
    /// that open with their own `SettingsPageHeader` or hero.
    private var zenithPageTitle: String? {
        let ownHeader: Set<SettingsPage> = [.features, .notch, .notchMascot, .energy, .monitor, .mouse,
                                            .switcher, .dock, .homebrew, .releaseNotes, .about, .support,
                                            .portManager, .workspaces, .lockScreen, .remote,
                                            .faceUnlock, .batteries, .pocket,
                                            .meetings, .mechakey, .appearance] // Zenith fork: Meetings, Mechakey, Appearance
        if ownHeader.contains(router.page) { return nil }
        if router.page == .translate { return nil } // Zenith fork: Translate opens with its own header
        if router.page.isNotchModulePage { return nil } // Zenith fork: the island's sections open with their hero
        if router.page == .general, !(detailShowsGeneralTool) { return nil }
        let selected = selectedSidebarItem
        return sidebarItems.first(where: { $0.id == selected })?.title
    }

    private var detailShowsGeneralTool: Bool {
        guard let anchor = router.destination.sectionAnchor else { return false }
        return [.panelConfiguration, .mixer, .soundOutputSwitcher, .audioPriority, .musicBlocking].contains(anchor)
            && sidebarItems.contains(where: { $0.destination == router.destination })
    }

    @ViewBuilder
    private var detail: some View {
        switch router.page {
        case .general:
            if let anchor = router.destination.sectionAnchor,
               [.panelConfiguration, .mixer, .soundOutputSwitcher,
                .audioPriority, .musicBlocking].contains(anchor),
               sidebarItems.contains(where: { $0.destination == router.destination }) {
                GeneralToolSettings(anchor: anchor)
            } else {
                GeneralSettings()
            }
        case .features: FeatureHubSettings()
        case .textSnippets: TextSnippetsSettings()
        case .notch: NotchSettings()
        case .notchMascot: NotchMascotSettings()
        case .radialMenu: RadialMenuSettings()
        case .commandBar: CommandBarSettings()
        case .energy: EnergySettings(focus: router.destination.sectionAnchor)
        case .monitor: MonitorSettings()
        case .mouse: MouseSettings()
        case .switcher: SwitcherSettings()
        case .dock: DockSettings()
        case .keyDebounce: KeyboardDebounceSettings()
        case .superKey: SuperKeySettings()
        case .cutPaste: CutPasteSettings()
        case .autoQuit: AutoQuitSettings()
        case .quitProtection: QuitProtectionSettings()
        case .uninstaller: UninstallerView()
        case .killProcess: KillProcessView()
        case .portManager: PortManagerView()
        case .urlCleaner: URLCleanerSettings()
        case .cleaner: CleanerSettings()
        case .homebrew: HomebrewSettings()
        case .appUpdates: AppUpdatesSettings()
        case .media: MediaSettings()
        case .clipboard: ClipboardSettings()
        case .quickTools: QuickToolsSettings()
        case .screenshot: ScreenCaptureSettings()
        case .windowLayout: WindowLayoutSettings()
        case .shelf: ShelfSettings()
        case .shortcuts: ShortcutsSettings()
        case .advanced: AdvancedSettings()
        case .about: AboutSettings()
        case .releaseNotes: ReleaseNotesSettings()
        case .support: SupportSettings()
        case .workspaces: WorkspacesSettings() // Zenith fork
        case .lockScreen: ZenithLockScreenSettings() // Zenith fork
        case .remote: RemoteControlSettings() // Zenith fork
        case .pocket: PocketSettingsPage() // Zenith fork
        case .meetings: MeetingsSettingsPage() // Zenith fork
        case .faceUnlock: FaceUnlockSettingsPage() // Zenith fork
        case .batteries: BatteriesSettingsPage() // Zenith fork
        case .translate: TranslateSettingsPage() // Zenith fork
        case .mechakey: MechakeySettingsPage() // Zenith fork
        case .appearance: AppearanceSettingsPage() // Zenith fork
        // Zenith fork: the island's sections, pages of their own.
        case .notchCalendar: NotchCalendarSettingsPage()
        case .notchNotifications: NotchNotificationsSettingsPage()
        case .notchMusic: NotchMusicSettingsPage()
        case .notchTimer: NotchTimerSettingsPage()
        case .notchAgents: NotchAgentsSettingsPage()
        case .notchDownloads: NotchDownloadsSettingsPage()
        case .notchWatch: NotchWatchSettingsPage()
        }
    }
}

// MARK: - Updates

struct UpdatesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = UpdateService.shared
    @AppStorage(DefaultsKey.autoCheckUpdates) private var autoCheck = true
    @AppStorage(DefaultsKey.includeBetaUpdates) private var includeBetas = AppInfo.isBeta
    @AppStorage(DefaultsKey.showReleaseNotesBeforeUpdate) private var showReleaseNotesFirst = true
    @AppStorage(DefaultsKey.releaseNotesOnUpdate) private var showWhatsNewAfter = true

    var body: some View {
        Section(l10n.s.updatesSection) {
            Toggle(l10n.s.autoCheckToggle, isOn: $autoCheck)
                .onChange(of: autoCheck) { _, value in
                    UpdateService.shared.autoCheckEnabled = value
                }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(l10n.s.includeBetaUpdatesToggle, isOn: $includeBetas)
                    .onChange(of: includeBetas) { _, value in
                        UpdateService.shared.includeBetaUpdates = value
                    }
                SettingsCaptionText(l10n.s.includeBetaUpdatesCaption)
            }

            VStack(alignment: .leading, spacing: 4) {
                let whatsNew = FeatureStrings.whatsNew(l10n.language)
                Toggle(whatsNew.showPreviewToggle, isOn: $showReleaseNotesFirst)
                if showWhatsNewAfter {
                    SettingsCaptionText(whatsNew.showPreviewCaption)
                }
            }

            Toggle(l10n.s.releaseNotesOnUpdateToggle, isOn: $showWhatsNewAfter)

            statusRow

            HStack {
                Button(l10n.s.checkNowButton) {
                    updates.check(manual: true)
                }
                .disabled(isBusy)

                if case .available = updates.state {
                    Button(l10n.s.updateInstallButton) {
                        appDelegate()?.showUpdatePreview()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let lastChecked = updates.lastChecked {
                Text("\(l10n.s.updateLastChecked) \(Self.format(lastChecked))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updates.state {
        case .idle:
            EmptyView()
        case .checking:
            label(l10n.s.updateChecking, system: "arrow.triangle.2.circlepath", tint: .secondary)
        case .upToDate:
            label(l10n.s.updateUpToDate, system: "checkmark.circle.fill", tint: ZenithStatus.success)
        case let .available(version):
            label("\(l10n.s.updateAvailablePrefix) \(version)", system: "arrow.down.circle.fill", tint: .accentColor)
        case let .downloading(progress):
            if let progress {
                label("\(l10n.s.updateDownloading) \(Int(progress * 100))%",
                      system: "arrow.down.circle", tint: .secondary)
            } else {
                label(l10n.s.updateDownloading, system: "arrow.down.circle", tint: .secondary)
            }
        case .installing:
            label(l10n.s.updateInstalling, system: "gearshape.2.fill", tint: .secondary)
        case let .failed(reason):
            label("\(l10n.s.updateFailedPrefix) \(reason)", system: "exclamationmark.triangle.fill", tint: ZenithStatus.warning)
        }
    }

    private func label(_ text: String, system: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system).foregroundStyle(tint)
            Text(text).font(.callout)
            Spacer()
        }
    }

    private var isBusy: Bool {
        switch updates.state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - About

struct AboutSettings: View {
    // Zenith fork: the About page after p441z.my.id, in ZenithAboutPage.swift.
    var body: some View {
        ZenithAboutPage()
    }
}

// MARK: - Release notes

struct ReleaseNotesSettings: View {
    @ObservedObject private var l10n = L10n.shared
    private let notes = ReleaseNotes.current

    // Zenith fork: a system page of the kit (docs/SETTINGS-KIT.md): the
    // header, the highlights on the stage, then the notes, in one scroll.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithSystemHeader(title: l10n.s.obWhatsNewTitle, subtitle: versionLine)
                ReleaseNotesPreviewCard(notes: notes) // Zenith fork
                if notes.sections.isEmpty {
                    fallbackNote
                } else {
                    ForEach(Array(notes.sections.enumerated()), id: \.offset) { _, section in
                        releaseSection(section)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }

    private var versionLine: String {
        if let date = notes.date {
            return "v\(notes.version) · \(date)"
        }
        return "v\(notes.version)"
    }

    private var fallbackNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, alignment: .center)
            Text(l10n.s.obWhatsNewFallback)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func releaseSection(_ section: ReleaseNoteSection) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if !section.title.isEmpty {
                Text(section.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }
            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                releaseItem(item, sectionTitle: section.title)
            }
        }
    }

    @ViewBuilder
    private func releaseItem(_ item: ReleaseNoteItem, sectionTitle: String) -> some View {
        switch item {
        case let .paragraph(text):
            Text(text)
                .font(.system(size: 12.8))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        case let .bullet(text):
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: iconName(for: sectionTitle))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18, alignment: .center)
                Text(text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case let .image(image):
            if let nsImage = releaseNoteImage(image) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .accessibilityLabel(image.alt)
                    .padding(.leading, 27)
            }
        }
    }

    private func releaseNoteImage(_ image: ReleaseNoteImage) -> NSImage? {
        var path = image.path
        if let resourcesRange = path.range(of: "Resources/") {
            path = String(path[resourcesRange.lowerBound...])
        }
        if path.hasPrefix("Resources/") {
            path.removeFirst("Resources/".count)
        }
        let nsPath = path as NSString
        let ext = nsPath.pathExtension
        let name = (nsPath.deletingPathExtension as NSString).lastPathComponent
        let directory = nsPath.deletingLastPathComponent
        guard !name.isEmpty, !ext.isEmpty else { return nil }
        let subdirectory = directory.isEmpty || directory == "." ? nil : directory
        guard let url = Bundle.main.url(forResource: name,
                                        withExtension: ext,
                                        subdirectory: subdirectory) else { return nil }
        return NSImage(contentsOf: url)
    }

    private func iconName(for title: String) -> String {
        switch title.lowercased() {
        case "added": return "plus.circle.fill"
        case "changed": return "slider.horizontal.3"
        case "fixed": return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Support

struct SupportSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    private var donateThanksText: String {
        let thanks = l10n.s.donateThanks
        return colorScheme == .dark
            ? thanks.replacingOccurrences(of: "🖤", with: "🤍")
            : thanks
    }

    // Zenith fork: a system page of the kit (docs/SETTINGS-KIT.md): the
    // header, the picture on the stage, then the two ways to help as rows.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithSystemHeader(title: l10n.s.tabSupport, subtitle: l10n.s.donateHeading)
                SupportPreviewCard() // Zenith fork
                ZenithSection(footer: donateThanksText) {
                    if let coffeeURL = AppInfo.coffeeURL {
                        ZenithRow(l10n.s.donateMessage) {
                            Button {
                                openURL(coffeeURL)
                            } label: {
                                Label(l10n.s.donateButton, systemImage: "cup.and.saucer.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                    ZenithRow(l10n.s.supportIntroStarMessage) {
                        Button {
                            openURL(AppInfo.repositoryURL)
                        } label: {
                            Label(l10n.s.supportIntroStarButton, systemImage: "star.fill")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }
}

// MARK: - Shared settings rows

private struct SettingsCaptionText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Shared permission row

enum PermissionKind {
    case accessibility
    case screenRecording
    case microphone
}

/// Status + actions for one TCC permission; shared by Settings and onboarding.
struct PermissionRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var pollingDemandID = UUID()
    let kind: PermissionKind

    private var granted: Bool {
        switch kind {
        case .accessibility: return permissions.accessibility
        case .screenRecording: return permissions.screenRecording
        case .microphone: return permissions.microphone == .granted
        }
    }

    private var monitorsActivePermission: Bool {
        switch kind {
        case .accessibility, .screenRecording: return true
        case .microphone: return false
        }
    }

    private var name: String {
        switch kind {
        case .accessibility: return l10n.s.permissionAccessibility
        case .screenRecording: return l10n.s.permissionScreenRecording
        case .microphone:
            return FeatureStrings.recorder(l10n.language).microphonePermissionName
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? ZenithStatus.success : ZenithStatus.warning)
                Text(name)
                Spacer()
                Text(granted ? l10n.s.permissionGranted : l10n.s.permissionMissing)
                    .font(.caption)
                    .foregroundStyle(granted ? ZenithStatus.success : ZenithStatus.warning)
            }
            if !granted {
                HStack(spacing: 8) {
                    Button(l10n.s.permissionRequest) {
                        switch kind {
                        case .accessibility:
                            permissions.requestAccessibility()
                        case .screenRecording:
                            permissions.requestScreenRecording()
                        case .microphone:
                            permissions.requestMicrophone()
                        }
                    }
                    Button(l10n.s.permissionOpenSettings) {
                        switch kind {
                        case .accessibility:
                            permissions.openAccessibilitySettings()
                        case .screenRecording:
                            permissions.openScreenRecordingSettings()
                        case .microphone:
                            permissions.openMicrophoneSettings()
                        }
                    }
                }
                .controlSize(.small)
            }
        }
        .onAppear {
            if monitorsActivePermission {
                permissions.setActivePermissionSurface(pollingDemandID, visible: true)
            }
        }
        .onDisappear {
            permissions.setActivePermissionSurface(pollingDemandID, visible: false)
        }
    }
}

/// Secure Event Input blocks every synthetic keystroke. Typing a snippet
/// trigger then does nothing at all, while the snippet library and the
/// Command Bar's typing actions beep; none of the four paths says what is
/// wrong or who is holding it. It also hides every key from the switcher's
/// tap, so the switcher hands ⌘Tab back to macOS for as long as it lasts and
/// the macOS switcher shows up instead. This row is the only place the app
/// explains either. macOS never names the holder, only the app that was
/// active when it turned on, so the row offers that app as a lead rather than
/// as the holder.
///
/// Every call site instantiates it only once secure input is on, and the
/// snippets and switcher pages wait for their own toggles as well, so the
/// `.off` branch below is there to keep the switch exhaustive and for nothing
/// else. What drives the feature is the polling demand on each page; see
/// `SecureInputObservation`.
struct SecureInputRow: View {
    /// What secure input blocks on the page showing the row, which is what
    /// its caption has to explain.
    enum Blocked {
        /// Snippets and the Command Bar's typing actions.
        case typing
        /// The switcher's shortcuts, which macOS's own switcher then answers.
        case switcher
    }

    var blocking: Blocked = .typing
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SecureInputMonitor.shared

    var body: some View {
        let switcher = blocking == .switcher
        switch monitor.holder {
        case .off:
            EmptyView()
        case .app(let name, _):
            row(caption: String(format: switcher ? l10n.s.secureInputSwitcherHeldFormat
                                                 : l10n.s.secureInputHeldFormat, name)) {
                Button(String(format: l10n.s.secureInputRevealFormat, name)) {
                    monitor.revealHolder()
                }
                .controlSize(.small)
            }
        case .unattributed:
            row(caption: switcher ? l10n.s.secureInputSwitcherUnattributed
                                  : l10n.s.secureInputUnattributed) { EmptyView() }
        case .unknown:
            row(caption: switcher ? l10n.s.secureInputSwitcherUnidentified
                                  : l10n.s.secureInputUnidentified) { EmptyView() }
        }
    }

    private func row<Action: View>(caption: String,
                                   @ViewBuilder action: () -> Action) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(ZenithStatus.warning)
                Text(l10n.s.secureInputTitle)
                Spacer()
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            action()
        }
    }
}

/// Keeps secure input polled for as long as the page is on screen and
/// `isActive` holds, e.g. the snippets page only while one of its own
/// toggles is on, since with both off nothing this row could report can
/// show. The demand cannot live on `SecureInputRow`: nothing would
/// register it until the state it reports had already been reached.
private struct SecureInputObservation: ViewModifier {
    let isActive: Bool
    @State private var demandID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { SecureInputMonitor.shared.setObservingSurface(demandID, visible: isActive) }
            .onDisappear { SecureInputMonitor.shared.setObservingSurface(demandID, visible: false) }
            .onChange(of: isActive) { _, active in
                SecureInputMonitor.shared.setObservingSurface(demandID, visible: active)
            }
    }
}

extension View {
    func observesSecureInput(isActive: Bool = true) -> some View {
        modifier(SecureInputObservation(isActive: isActive))
    }
}
