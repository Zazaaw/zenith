// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// The Features page, as Orbit (Zenith fork): a store-like catalog of every
/// hub feature and Zenith's own pages. Get installs a feature through the
/// hub's runtime, Open goes to its settings, Turn Off uninstalls it from the
/// whole app (Settings, panel, menu bar, shortcuts) and keeps its
/// configuration for its return. A row opens its details, where the
/// permissions it uses can be granted. The permissions portal opens from the
/// header.
struct FeatureHubSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var query = ""
    @State private var category: OrbitCategory = .all
    @State private var detail: OrbitItemID?
    @State private var showingPermissions = false
    @State private var confirmingIslandUninstall = false
    /// The words Settings search knows each item by, read once per visit
    /// and language rather than on every keystroke.
    @State private var searchWords: [OrbitItemID: [String]] = [:]
    @FocusState private var searchFocused: Bool
    /// Installed switches never once turned on, read when the page appears
    /// and after every install change rather than on every redraw.
    @State private var neverUsed: [AppFeature] = []
    /// The batch just uninstalled from that card, kept for its Undo.
    @State private var recentlyUninstalled: [AppFeature] = []

    /// Below this, the offer would be more to read than it saves.
    private static let neverUsedMinimum = 3

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }
    private var text: ZenithOrbitStrings { ZenithStrings.orbit }

    var body: some View {
        content
            .onAppear {
                refreshNeverUsed()
                searchWords = Self.readSearchWords(l10n)
                revealPendingFeatureTarget()
            }
            .onChange(of: router.requestID) { _, _ in revealPendingFeatureTarget() }
            .onChange(of: features.revision) { _, _ in refreshNeverUsed() }
            .onChange(of: l10n.language) { _, _ in searchWords = Self.readSearchWords(l10n) }
            .sheet(item: $detail) { id in
                if let item = OrbitCatalog.item(id) {
                    OrbitDetailSheet(item: item, state: state(of: item),
                                     onAction: { act(on: item, fromDetails: true) },
                                     onTurnOff: turnOffAction(for: item),
                                     onDone: { detail = nil })
                }
            }
            .sheet(isPresented: $showingPermissions) { permissionsSheet }
            .alert(hub.notchUninstallTitle, isPresented: $confirmingIslandUninstall) {
                Button(hub.notchUninstallWithExtensions) {
                    uninstall([.notch] + installedIslandExtensions)
                }
                Button(hub.notchUninstallKeepExtensions) { uninstall([.notch]) }
                Button(hub.presetConfirmCancel, role: .cancel) {}
            } message: {
                Text(String(format: hub.notchUninstallMessageFormat,
                            installedIslandExtensions.map { $0.hubTitle(l10n.s, hub: hub) }
                                .joined(separator: ", ")))
            }
    }

    private var content: some View {
        // The catalog is measured eagerly, so scrolling cannot re-estimate
        // distant rows and re-anchor the viewport in the lazy layout loop
        // reported in #2311 and #2642.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Keep the header's identity stable when a notice changes.
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if features.needsRestartToUnload {
                        restartCard
                    }
                    neverUsedCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { FeatureHubScrollAnchor() }
                catalog
            }
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
        }
        // Include the scroll view's document height in this transaction;
        // animating that height would constrain an immediate notice adjustment
        // against the old bottom limit for the duration of the animation.
        .animation(nil, value: features.needsRestartToUnload)
        .animation(nil, value: neverUsed)
        .animation(nil, value: recentlyUninstalled)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            OrbitItemIcon(name: "Orbit", size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(text.title)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .accessibilityAddTraits(.isHeader)
                Text(text.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            OrbitSearchField(query: $query, placeholder: text.searchPlaceholder,
                             clearTitle: text.clearSearch, focus: $searchFocused)
            Button { showingPermissions = true } label: {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(hub.tabPermissions)
            .accessibilityLabel(hub.tabPermissions)
        }
    }

    private var restartCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.accentColor)
            Text(hub.restartNote)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Button(hub.restartButton) {
                FeatureRuntime.shared.relaunchApp()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
    }

    // MARK: Catalog

    @ViewBuilder
    private var catalog: some View {
        let states = itemStates()
        if query.isEmpty, let featured = OrbitCatalog.item(OrbitCatalog.featured) {
            OrbitHeroBanner(item: featured, state: states[featured.id] ?? .off,
                            onAction: { act(on: featured) },
                            onDetails: { detail = featured.id })
        }
        OrbitFlowLayout {
            ForEach(OrbitCategory.allCases) { shelf in
                OrbitChip(title: text.category(shelf), selected: category == shelf) {
                    category = shelf
                }
            }
        }
        let isOn = { (id: OrbitItemID) in states[id]?.isOn ?? false }
        if !query.isEmpty {
            let found = OrbitCatalog.visible(in: category, query: query, isOn: isOn, words: searchWords)
            if found.isEmpty {
                emptyNote(text.noResults)
            } else {
                section(text.results, found, states)
            }
        } else {
            switch category {
            case .all:
                section(text.ourPicks, OrbitCatalog.picks.compactMap(OrbitCatalog.item), states)
                ForEach(OrbitCategory.shelves) { shelf in
                    let members = OrbitCatalog.visible(in: shelf, query: "", isOn: isOn)
                    section(text.category(shelf), Array(members.prefix(OrbitCatalog.shelfPreviewCount)), states,
                            seeAll: members.count > OrbitCatalog.shelfPreviewCount ? shelf : nil)
                }
            case .installed:
                let installed = OrbitCatalog.visible(in: .installed, query: "", isOn: isOn)
                if installed.isEmpty {
                    emptyNote(text.noneInstalled)
                } else {
                    ForEach(OrbitCategory.shelves) { shelf in
                        let members = installed.filter { $0.category == shelf }
                        if !members.isEmpty { section(text.category(shelf), members, states) }
                    }
                }
            default:
                section(text.category(category), OrbitCatalog.visible(in: category, query: "", isOn: isOn), states)
            }
        }
    }

    /// A titled shelf of rows in two columns.
    private func section(_ title: String, _ items: [OrbitItem], _ states: [OrbitItemID: OrbitItemState],
                         seeAll: OrbitCategory? = nil) -> some View {
        let rows = stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let seeAll {
                    Button(text.seeAll) { category = seeAll }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("\(text.seeAll), \(title)")
                }
            }
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 22) {
                        ForEach(rows[index]) { item in
                            row(item, state: states[item.id] ?? .off)
                                .frame(maxWidth: .infinity)
                        }
                        if rows[index].count == 1 {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: OrbitItem, state: OrbitItemState) -> some View {
        OrbitStoreRow(item: item, state: state, badge: badge(for: item),
                      onDetails: { detail = item.id },
                      onAction: { act(on: item) },
                      onTurnOff: turnOffAction(for: item))
            .id(item.id)
    }

    private func emptyNote(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 30)
    }

    private func badge(for item: OrbitItem) -> String? {
        if item.feature == .notch { return hub.experimentalBadge }
        return item.feature?.isBeta == true ? l10n.s.betaBadge : nil
    }

    // MARK: State

    /// Every item's state from one read of availability and of which
    /// features use each permission right now.
    private func itemStates() -> [OrbitItemID: OrbitItemState] {
        let users = Dictionary(uniqueKeysWithValues: AppPermission.allCases.map {
            ($0, Set(AppFeature.activeFeatures(using: $0)))
        })
        return Dictionary(uniqueKeysWithValues: OrbitCatalog.items.map { item in
            (item.id, state(of: item, users: users))
        })
    }

    private func state(of item: OrbitItem,
                       users: [AppPermission: Set<AppFeature>]? = nil) -> OrbitItemState {
        OrbitCatalog.state(
            of: item,
            isAvailable: \.isAvailable,
            switchValue: { UserDefaults.standard.object(forKey: $0) as? Bool },
            missing: isMissing,
            using: { feature, permission in
                users?[permission]?.contains(feature)
                    ?? AppFeature.activeFeatures(using: permission).contains(feature)
            },
            blockedReason: \.installBlockedReason)
    }

    /// Only a refusal the app can read counts; a grant macOS has not been
    /// asked for yet is requested when the feature first needs it.
    private func isMissing(_ permission: AppPermission) -> Bool {
        switch permission {
        case .accessibility: return !permissions.accessibility
        case .screenRecording: return !permissions.screenRecording
        case .fullDiskAccess: return !permissions.fullDiskAccess
        case .notifications: return permissions.notifications == .denied
        case .camera: return permissions.camera == .denied
        case .microphone: return permissions.microphone == .denied
        case .calendar: return permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted
        case .filesAndFolders, .automationFinder, .automationPlayback, .audioCapture, .appManagement:
            return false
        }
    }

    // MARK: Actions

    /// The capsule's action: Get, or Open.
    private func act(on item: OrbitItem, fromDetails: Bool = false) {
        switch OrbitCatalog.button(for: state(of: item)) {
        case .get: get(item, fromDetails: fromDetails)
        case .open: open(item)
        case .unavailable: break
        }
    }

    /// Installs through the hub's runtime, so its first-install rules and
    /// its hardware gate apply. A feature that now needs a permission shows
    /// its details, where the grant is requested; a Zenith page opens, since
    /// it is switched on and set up there.
    private func get(_ item: OrbitItem, fromDetails: Bool) {
        let plan = OrbitCatalog.getPlan(for: item, isAvailable: \.isAvailable)
        if !plan.install.isEmpty {
            withAnimation(.easeOut(duration: 0.22)) {
                FeatureRuntime.shared.setAvailable(plan.install, true)
            }
        }
        if let destination = plan.opens {
            detail = nil
            SettingsRouter.shared.request(destination)
        } else if !fromDetails, case .needsPermission = state(of: item) {
            detail = item.id
        }
    }

    private func open(_ item: OrbitItem) {
        guard let destination = OrbitCatalog.openDestination(for: item) else {
            detail = item.id
            return
        }
        detail = nil
        SettingsRouter.shared.request(destination, sidebarFeature: item.feature)
    }

    private func turnOffAction(for item: OrbitItem) -> (() -> Void)? {
        guard let features = OrbitCatalog.turnOffFeatures(for: item) else { return nil }
        return {
            // The island's extensions do nothing without it, so leaving
            // asks whether they leave too.
            if features == [.notch], !installedIslandExtensions.isEmpty {
                confirmingIslandUninstall = true
            } else {
                uninstall(features)
            }
        }
    }

    private var installedIslandExtensions: [AppFeature] {
        AppFeature.dynamicIslandExtensions.filter(\.isAvailable)
    }

    private func uninstall(_ features: [AppFeature]) {
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(features, false)
        }
    }

    /// Consumes a pending Features target (a search result, the Command Bar,
    /// an option that needs a feature) by showing that feature's details.
    private func revealPendingFeatureTarget() {
        guard let request = router.pendingFeatureTarget else { return }
        router.consumeFeatureTarget(id: request.id)
        query = ""
        detail = .feature(request.feature)
    }

    private static func readSearchWords(_ l10n: L10n) -> [OrbitItemID: [String]] {
        OrbitCatalog.searchWords(from: SettingsDirectory.searchItems(l10n.s, language: l10n.language))
    }

    // MARK: Permissions

    private var permissionsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(hub.tabPermissions)
                        .font(.system(size: 22, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(hub.permissionsIntro)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PermissionsPortalSections(hub: hub)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button(text.done) { showingPermissions = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
        }
        .frame(width: 560, height: 620)
        .onExitCommand { showingPermissions = false }
    }

    // MARK: Never used

    /// Installed switches that were never once turned on, offered as one
    /// batch. People come to this page to manage the app, so the offer waits
    /// here instead of interrupting anywhere else. Keep ends it for these
    /// features, and Undo puts back exactly what left.
    @ViewBuilder
    private var neverUsedCard: some View {
        if !recentlyUninstalled.isEmpty {
            SettingsCard {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ZenithStatus.success)
                        .accessibilityHidden(true)
                    Text(hub.footerNote)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button(l10n.s.menuUndo, action: undoNeverUsedUninstall)
                }
            }
        } else if neverUsed.count >= Self.neverUsedMinimum {
            SettingsCard(title: hub.neverUsedTitle) {
                Text(String(format: hub.neverUsedMessageFormat,
                            neverUsed.map { $0.hubTitle(l10n.s, hub: hub) }.joined(separator: ", ")))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button(hub.neverUsedKeep, action: keepNeverUsed)
                    Button(hub.neverUsedUninstall, action: uninstallNeverUsed)
                }
            }
        }
    }

    private func refreshNeverUsed() {
        neverUsed = FeatureRuntime.shared.neverSwitchedOnFeatures()
    }

    private func uninstallNeverUsed() {
        // Read again at the click: a switch turned on in the panel since the
        // page appeared takes its feature out of the batch.
        let stillUnused = Set(FeatureRuntime.shared.neverSwitchedOnFeatures())
        let batch = neverUsed.filter(stillUnused.contains)
        guard !batch.isEmpty else {
            refreshNeverUsed()
            return
        }
        recentlyUninstalled = batch
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(batch, false)
        }
    }

    /// Changing one's mind is also an answer to the offer, so the features
    /// that come back are kept and never offered again. None of them was
    /// ever on, and the reinstall leaves their switches off too.
    private func undoNeverUsedUninstall() {
        let batch = recentlyUninstalled
        recentlyUninstalled = []
        FeatureRuntime.shared.keep(batch)
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable(batch, true, enablingFirstInstalls: false)
        }
    }

    private func keepNeverUsed() {
        FeatureRuntime.shared.keep(neverUsed)
        withAnimation(.easeOut(duration: 0.22)) {
            refreshNeverUsed()
        }
    }
}

/// A notice above the viewport can change height without moving the row the
/// user is working on. SwiftUI's ID-based position only keeps an entire card
/// visible; cards taller than the viewport need the exact pixel offset.
private struct FeatureHubScrollAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> AnchorView { AnchorView() }
    func updateNSView(_ view: AnchorView, context: Context) { view.schedule() }
    static func dismantleNSView(_ view: AnchorView, coordinator: ()) { view.stop() }

    final class AnchorView: NSView {
        private struct Geometry {
            let prefixBottom: CGFloat
            let documentSize: NSSize
            let viewport: NSRect
        }
        private weak var scroll: NSScrollView?
        private var observer: NSObjectProtocol?
        private var documentObserver: NSObjectProtocol?
        private var geometry: Geometry?
        private var adjustment: DispatchWorkItem?
        private var restoring = false

        deinit {
            adjustment?.cancel()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            if let documentObserver { NotificationCenter.default.removeObserver(documentObserver) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            schedule()
        }
        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            schedule()
        }

        func schedule() {
            guard adjustment == nil else { return }
            let work = DispatchWorkItem { [weak self] in self?.restore() }
            adjustment = work
            DispatchQueue.main.async(execute: work)
        }

        private func readGeometry() -> Geometry? {
            guard let scroll, let document = scroll.documentView else { return nil }
            return Geometry(prefixBottom: convert(bounds, to: document).maxY,
                            documentSize: document.frame.size,
                            viewport: scroll.contentView.bounds)
        }

        private func scrolled() {
            guard !restoring, let current = readGeometry() else { return }
            if let previous = geometry,
               previous.documentSize != current.documentSize
                || previous.prefixBottom != current.prefixBottom {
                // A shrinking document can clamp the clip before the notice
                // view is resized. Keep the earlier snapshot until layout ends.
                schedule()
                return
            }
            geometry = current
        }

        private func restore() {
            guard let enclosing = enclosingScrollView,
                  let document = enclosing.documentView else { stop(); return }
            if scroll !== enclosing {
                if let observer { NotificationCenter.default.removeObserver(observer) }
                if let documentObserver { NotificationCenter.default.removeObserver(documentObserver) }
                scroll = enclosing
                geometry = nil
                enclosing.contentView.postsBoundsChangedNotifications = true
                observer = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: enclosing.contentView, queue: .main
                ) { [weak self] _ in self?.scrolled() }
                document.postsFrameChangedNotifications = true
                documentObserver = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: document, queue: .main
                ) { [weak self] _ in self?.schedule() }
            }
            var waitingForDocument = false
            defer {
                if !waitingForDocument { geometry = readGeometry() }
                adjustment = nil
            }
            enclosing.layoutSubtreeIfNeeded()
            guard let previous = geometry, let current = readGeometry(),
                  previous.viewport.minY >= previous.prefixBottom,
                  previous.viewport.size == current.viewport.size,
                  previous.documentSize.width == current.documentSize.width else { return }
            let clip = enclosing.contentView
            let expected = clip.constrainBoundsRect(previous.viewport)
            // Keep an intentional scroll or navigation performed after the
            // snapshot, while accepting the document's automatic bottom clamp.
            guard abs(current.viewport.minY - expected.minY) < 0.5,
                  abs(current.viewport.minX - expected.minX) < 0.5 else { return }
            let delta = current.prefixBottom - previous.prefixBottom
            guard abs(delta) > 0.01 else { return }
            var target = previous.viewport
            target.origin.y += delta
            let constrained = clip.constrainBoundsRect(target)
            if delta > 0,
               current.documentSize.height == previous.documentSize.height,
               target.minY > constrained.minY + 0.5 {
                // The prefix can resize before SwiftUI grows its document.
                // Keep the snapshot until that frame change permits the new
                // offset, instead of losing it against the old bottom limit.
                waitingForDocument = true
                return
            }
            restoring = true
            clip.scroll(to: constrained.origin)
            enclosing.reflectScrolledClipView(clip)
            restoring = false
        }

        func stop() {
            adjustment?.cancel()
            adjustment = nil
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            if let documentObserver { NotificationCenter.default.removeObserver(documentObserver) }
            documentObserver = nil
            geometry = nil
            scroll = nil
        }
    }
}


// MARK: - Permissions portal

struct PermissionsPortalSections: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    let hub: FeatureHubStrings
    let visiblePermissions: [AppPermission]
    @State private var automation: [Permissions.AutomationTarget: Permissions.AutomationStatus] = [:]
    @State private var pollingDemandID = UUID()

    init(hub: FeatureHubStrings,
         visiblePermissions: [AppPermission] = AppPermission.allCases) {
        self.hub = hub
        self.visiblePermissions = visiblePermissions
    }

    var body: some View {
        ForEach(visiblePermissions, id: \.self) { permission in
            PermissionPortalRow(permission: permission,
                                hub: hub,
                                status: status(for: permission))
            if permission != visiblePermissions.last {
                Divider().padding(.leading, 42)
            }
        }
        .onAppear {
            // Statuses that only refresh at launch/activation get a fresh
            // read the moment the portal shows; automation is checked off the
            // main thread because the AE round trip can block briefly.
            permissions.refresh()
            if visiblePermissions.contains(.accessibility)
                || visiblePermissions.contains(.screenRecording) {
                permissions.setActivePermissionSurface(pollingDemandID, visible: true)
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let finder = Permissions.automationStatus(for: .finder)
                DispatchQueue.main.async {
                    automation = [.finder: finder]
                }
            }
        }
        .onDisappear {
            permissions.setActivePermissionSurface(pollingDemandID, visible: false)
        }
    }

    private func status(for permission: AppPermission) -> PermissionPortalRow.Status {
        switch permission {
        case .accessibility: return permissions.accessibility ? .granted : .missing
        case .screenRecording: return permissions.screenRecording ? .granted : .missing
        case .fullDiskAccess: return permissions.fullDiskAccess ? .granted : .missing
        case .filesAndFolders:
            guard AppFeature.cleaner.isAvailable,
                  WhatsAppDownloadSupport.isEnabled else {
                return .unknown
            }
            switch WhatsAppDownloadManager.shared.accessStatus {
            case .available: return .granted
            case .denied: return .missing
            case .unknown: return .unknown
            }
        case .notifications:
            switch permissions.notifications {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .automationFinder: return automationStatus(.finder)
        case .automationPlayback: return .unknown
        case .audioCapture:
            // No public check exists for system audio capture; the mixer
            // reports a failed tap, which is the one readable signal.
            if AppFeature.mixer.isAvailable, AppVolumeMixer.shared.needsPermission {
                return .missing
            }
            return .unknown
        case .microphone:
            switch permissions.microphone {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .calendar:
            return permissions.calendarAccess == .fullAccess ? .granted : .missing
        case .camera:
            switch permissions.camera {
            case .granted: return .granted
            case .denied, .undetermined: return .missing
            case .unknown: return .unknown
            }
        case .appManagement:
            // macOS has no public preflight API for this permission. The
            // system records the app only after its first protected write.
            return .unknown
        }
    }

    private func automationStatus(_ target: Permissions.AutomationTarget) -> PermissionPortalRow.Status {
        switch automation[target] {
        case .granted: return .granted
        case .denied, .undetermined: return .missing
        case .notDeterminable, .none: return .unknown
        }
    }
}

private struct PermissionPortalRow: View {
    enum Status { case granted, missing, unknown }

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let permission: AppPermission
    let hub: FeatureHubStrings
    let status: Status

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // The tile wears the status color, so a glance down the list
            // shows what is granted before any word is read.
            Image(systemName: permission.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)
                .background(statusColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(permission.name(hub))
                        .fontWeight(.medium)
                    statusChip
                }
                Text(permission.explainer(hub))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(usedByLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if status == .granted, activeFeatures.isEmpty {
                    unusedCard
                }
                HStack(spacing: 8) {
                    if status != .granted, hasRequestFlow {
                        Button(hub.requestButton) { request() }
                    }
                    Button(hub.openSystemSettings) { openSystemSettings() }
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var activeFeatures: [AppFeature] {
        AppFeature.activeFeatures(using: permission).filter {
            permission != .notifications || $0 != .monitorPower || PowerSampler.hasInternalBattery
        }
    }

    private var usedByLine: String {
        let names = activeFeatures.map { $0.hubTitle(l10n.s, hub: hub) }
        guard !names.isEmpty else { return hub.usedByNone }
        return String(format: hub.usedByFormat, names.joined(separator: ", "))
    }

    private var statusChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(chipText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return ZenithStatus.success
        case .missing: return ZenithStatus.warning
        case .unknown: return .secondary
        }
    }

    private var chipText: String {
        switch status {
        case .granted: return hub.statusGranted
        case .missing: return hub.statusMissing
        case .unknown: return hub.statusUnknown
        }
    }

    private var unusedCard: some View {
        Text(hub.unusedBanner)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
    }

    private var hasRequestFlow: Bool {
        switch permission {
        case .accessibility, .screenRecording, .fullDiskAccess: return true
        case .notifications: return Permissions.shared.notifications == .undetermined
        case .calendar: return Permissions.shared.calendarAccess == .notDetermined
            || Permissions.shared.calendarAccess == .writeOnly
        case .camera: return Permissions.shared.camera == .undetermined
        case .microphone: return Permissions.shared.microphone == .undetermined
        case .filesAndFolders, .automationFinder, .automationPlayback, .audioCapture,
             .appManagement: return false
        }
    }

    private func request() {
        switch permission {
        case .accessibility: Permissions.shared.requestAccessibility()
        case .screenRecording: Permissions.shared.requestScreenRecording()
        case .fullDiskAccess: Permissions.shared.requestFullDiskAccess()
        case .notifications:
            Notifier.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Permissions.shared.refresh()
            }
        case .calendar: Permissions.shared.requestCalendar()
        case .camera: Permissions.shared.requestCamera()
        case .microphone: Permissions.shared.requestMicrophone()
        case .filesAndFolders, .automationFinder, .automationPlayback, .audioCapture,
             .appManagement:
            break
        }
    }

    private func openSystemSettings() {
        switch permission {
        case .accessibility: Permissions.shared.openAccessibilitySettings()
        case .screenRecording: Permissions.shared.openScreenRecordingSettings()
        case .fullDiskAccess: Permissions.shared.openFullDiskAccessSettings()
        case .filesAndFolders: Permissions.shared.openFilesAndFoldersSettings()
        case .notifications: Permissions.shared.openNotificationSettings()
        case .automationFinder, .automationPlayback: Permissions.shared.openAutomationSettings()
        case .audioCapture: Permissions.shared.openAudioCaptureSettings()
        case .microphone: Permissions.shared.openMicrophoneSettings()
        case .calendar: Permissions.shared.openCalendarSettings()
        case .camera: Permissions.shared.openCameraSettings()
        case .appManagement: Permissions.shared.openAppManagementSettings()
        }
    }
}

// MARK: - Titles, descriptions and permission names

extension AppFeature {
    /// What an option that needs this feature says while it is uninstalled.
    func enableReason(_ l10n: L10n) -> String {
        FeatureStrings.notchEditor(l10n.language).enableFeature(hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)))
    }

    /// Features, at this feature, for an option that needs it.
    func showInFeatures() {
        SettingsRouter.shared.request(FeatureSettingsDestination(.features), targetFeature: self)
    }

    /// Titles reuse the strings users already see across the app; only names
    /// with no clean existing form live in the hub strings.
    func hubTitle(_ s: Strings, hub: FeatureHubStrings,
                  language: AppLanguage = L10n.shared.language) -> String {
        switch self {
        case .switcher: return s.switcherSection
        case .dockPreview: return s.dockPreviewName
        case .dockClick: return hub.titleDockClick
        case .windowMaximizer: return s.windowMaximizeName
        case .windowLayout: return FeatureStrings.windowLayout(language).title
        case .autoQuit: return s.autoQuitName
        case .spacesOrder: return s.spacesOrderName
        case .quitWindowProtection: return FeatureStrings.quitProtection(language).name
        case .scrollInverter: return s.invertMouseScroll
        case .scrollHorizontal: return s.scrollHorizontalName
        case .scrollZoom: return s.zoomSection
        case .focusFollowsMouse: return s.focusFollowsMouseName
        case .smoothScroll: return s.smoothScrollName
        case .linearScroll: return s.linearScrollName
        case .scrollSpeed: return s.scrollSpeedName
        case .mouseAcceleration: return s.mouseAccelerationName
        case .mouseNavigation: return hub.titleMouseNavigation
        case .mouseButtonShortcuts: return FeatureStrings.mouseButtons(language).pageTitle
        case .middleClick: return s.middleClickSection
        case .keyboardDebounce: return s.keyDebounceName
        case .textSnippets: return FeatureStrings.snippets(language).pageTitle
        case .superKey: return FeatureStrings.superKey(language).pageTitle
        case .mouseClickDebounce:
            return FeatureStrings.mouseClickDebounce(language).title
        case .clipboardHistory: return FeatureStrings.clipboard(language).title
        case .pastePlain: return s.pastePlainName
        case .finderCutPaste: return s.cutPasteName
        case .finderRename: return FeatureStrings.finderRename(language).hubTitle
        case .shelf: return s.shelfName
        case .urlCleaner: return s.urlCleanerName
        case .diskImageInstaller:
            return FeatureStrings.diskImageInstaller(language).title
        case .mixer: return s.mixerSection
        case .soundOutputSwitcher: return s.soundOutputSwitcherTitle
        case .audioPriority: return hub.titleAudioPriority
        case .micMute: return s.micMuteName
        case .musicBlock: return hub.titleMusicBlock
        case .keepAwake: return s.keepAwakeTitle
        case .brightness: return FeatureStrings.brightness(language).pageTitle
        case .extraBrightness: return s.extraBrightnessName
        case .bluetoothSleep: return FeatureStrings.bluetoothSleep(language).pageTitle
        case .quickLauncher: return s.launcherName
        case .quickToggles: return FeatureStrings.quickToggles(language).pageTitle
        case .quitApps: return s.quitAppsName
        case .colorPicker: return s.colorPickerName
        case .screenOCR: return s.ocrName
        case .screenshot: return FeatureStrings.screenshot(language).pageTitle
        case .screenRecorder: return FeatureStrings.recorder(language).pageTitle
        case .cameraPreview: return FeatureStrings.cameraPreview(language).pageTitle
        case .wallpaper: return FeatureStrings.wallpaper(language).pageTitle
        case .notchGestures: return FeatureStrings.notchGestures(language).title
        case .notchTimer: return FeatureStrings.notchActivities(language).timer
        case .notchAccessories: return FeatureStrings.notchActivities(language).accessories
        case .notchNotifications: return FeatureStrings.notchNotifications(language).title
        case .notchLyrics: return FeatureStrings.notchMusicExtras(language).lyrics
        case .notchQueue: return FeatureStrings.notchMusicExtras(language).queue
        case .notchLiveEqualizer: return FeatureStrings.notchMusicExtras(language).liveEqualizer
        case .notchDownloads: return FeatureStrings.notchFiles(language).downloadsTitle
        case .notchCalendar: return FeatureStrings.notchCalendar(language).title
        case .notchAgents: return FeatureStrings.notchAgents(language).title
        case .notchWatch: return FeatureStrings.notchWatch(language).title
        case .notchMascot: return FeatureStrings.notchMascot(language).title
        case .notch: return FeatureStrings.notch(language).title
        case .radialMenu: return FeatureStrings.radialMenu(language).pageTitle
        case .scratchpad: return FeatureStrings.scratchpad(language).pageTitle
        case .commandBar: return FeatureStrings.commandBar(language).pageTitle
        case .cleaningMode: return s.cleaningMenuItem
        case .mediaTools: return s.mediaName
        case .cleaner: return s.cleanerName
        case .uninstaller: return s.uninstallerName
        case .killProcess: return FeatureStrings.killProcess(language).pageTitle
        case .portManager: return FeatureStrings.portManager(language).title
        case .homebrew: return s.homebrewName
        case .appUpdates: return FeatureStrings.appUpdates(language).pageTitle
        case .monitorCPU: return s.monitorShowCPU
        case .monitorGPU: return s.monitorShowGPU
        case .monitorMemory: return s.monitorShowMemory
        case .monitorNetwork: return s.monitorShowNetwork
        case .monitorDisk: return s.diskSection
        case .monitorPower: return s.powerSection
        case .connectedDevices: return FeatureStrings.connectedDevices(language).title
        case .fanControl: return FeatureStrings.fanControl(language).title
        }
    }

    func hubDescription(_ hub: FeatureHubStrings) -> String {
        switch self {
        case .switcher: return hub.descSwitcher
        case .dockPreview: return hub.descDockPreview
        case .dockClick: return hub.descDockClick
        case .windowMaximizer: return hub.descWindowMaximizer
        case .windowLayout: return hub.descWindowLayout
        case .autoQuit: return hub.descAutoQuit
        case .spacesOrder: return L10n.shared.s.spacesOrderCaption
        case .quitWindowProtection: return FeatureStrings.quitProtection(L10n.shared.language).description
        case .scrollInverter: return hub.descScrollInverter
        case .scrollHorizontal: return L10n.shared.s.scrollHorizontalCaption
        case .scrollZoom: return L10n.shared.s.pinchZoom
        case .focusFollowsMouse: return L10n.shared.s.focusFollowsMouseCaption
        case .smoothScroll: return hub.descSmoothScroll
        case .linearScroll: return L10n.shared.s.linearScrollCaption
        case .scrollSpeed: return L10n.shared.s.scrollSpeedCaption
        case .mouseAcceleration: return L10n.shared.s.mouseAccelerationCaption
        case .mouseNavigation: return hub.descMouseNavigation
        case .mouseButtonShortcuts: return FeatureStrings.mouseButtons(L10n.shared.language).hubDescription
        case .middleClick: return hub.descMiddleClick
        case .keyboardDebounce: return hub.descKeyboardDebounce
        case .textSnippets: return FeatureStrings.snippets(L10n.shared.language).hubDescription
        case .superKey: return FeatureStrings.superKey(L10n.shared.language).hubDescription
        case .mouseClickDebounce:
            return FeatureStrings.mouseClickDebounce(L10n.shared.language).caption
        case .clipboardHistory: return hub.descClipboardHistory
        case .pastePlain: return hub.descPastePlain
        case .finderCutPaste: return hub.descFinderCutPaste
        case .finderRename: return FeatureStrings.finderRename(L10n.shared.language).hubDescription
        case .shelf: return hub.descShelf
        case .urlCleaner: return hub.descURLCleaner
        case .diskImageInstaller:
            return FeatureStrings.diskImageInstaller(L10n.shared.language).hubDescription
        case .mixer: return hub.descMixer
        case .soundOutputSwitcher: return hub.descSoundOutputSwitcher
        case .audioPriority: return hub.descAudioPriority
        case .micMute: return hub.descMicMute
        case .musicBlock: return hub.descMusicBlock
        case .keepAwake: return hub.descKeepAwake
        case .brightness: return FeatureStrings.brightness(L10n.shared.language).hubDescription
        case .extraBrightness: return hub.descExtraBrightness
        case .bluetoothSleep: return FeatureStrings.bluetoothSleep(L10n.shared.language).hubDescription
        case .quickLauncher: return hub.descQuickLauncher
        case .quickToggles: return FeatureStrings.quickToggles(L10n.shared.language).hubDescription
        case .quitApps: return L10n.shared.s.quitAppsCaption
        case .colorPicker: return hub.descColorPicker
        case .screenOCR: return hub.descScreenOCR
        case .screenshot: return FeatureStrings.screenshot(L10n.shared.language).hubDescription
        case .screenRecorder: return FeatureStrings.recorder(L10n.shared.language).hubDescription
        case .cameraPreview: return FeatureStrings.cameraPreview(L10n.shared.language).hubDescription
        case .wallpaper: return FeatureStrings.wallpaper(L10n.shared.language).hubDescription
        case .notchGestures: return FeatureStrings.notchGestures(L10n.shared.language).description
        case .notchTimer: return FeatureStrings.notchActivities(L10n.shared.language).timerDescription
        case .notchAccessories: return FeatureStrings.notchActivities(L10n.shared.language).accessoryDescription
        case .notchNotifications: return FeatureStrings.notchNotifications(L10n.shared.language).description
        case .notchLyrics: return FeatureStrings.notchMusicExtras(L10n.shared.language).lyricsDescription
        case .notchQueue: return FeatureStrings.notchMusicExtras(L10n.shared.language).queueDescription
        case .notchLiveEqualizer: return FeatureStrings.notchMusicExtras(L10n.shared.language).liveEqualizerDescription
        case .notchDownloads: return FeatureStrings.notchFiles(L10n.shared.language).downloadsDescription
        case .notchCalendar: return FeatureStrings.notchCalendar(L10n.shared.language).description
        case .notchAgents: return FeatureStrings.notchAgents(L10n.shared.language).hubDescription
        case .notchWatch: return FeatureStrings.notchWatch(L10n.shared.language).description
        case .notchMascot: return FeatureStrings.notchMascot(L10n.shared.language).hubDescription
        case .notch: return FeatureStrings.notch(L10n.shared.language).description
        case .radialMenu: return FeatureStrings.radialMenu(L10n.shared.language).hubDescription
        case .scratchpad: return FeatureStrings.scratchpad(L10n.shared.language).hubDescription
        case .commandBar: return FeatureStrings.commandBar(L10n.shared.language).hubDescription
        case .cleaningMode: return hub.descCleaningMode
        case .mediaTools: return hub.descMediaTools
        case .cleaner:
            let description = hub.descCleaner
            guard WhatsAppDownloadSupport.isEnabled else {
                return description
            }
            return description + " · "
                + FeatureStrings.whatsAppDownloads(L10n.shared.language).hubDescription
        case .uninstaller: return hub.descUninstaller
        case .killProcess: return FeatureStrings.killProcess(L10n.shared.language).hubDescription
        case .portManager: return FeatureStrings.portManager(L10n.shared.language).hubDescription
        case .homebrew: return hub.descHomebrew
        case .appUpdates: return FeatureStrings.appUpdates(L10n.shared.language).hubDescription
        case .monitorCPU: return hub.descMonitorCPU
        case .monitorGPU: return hub.descMonitorGPU
        case .monitorMemory: return hub.descMonitorMemory
        case .monitorNetwork: return hub.descMonitorNetwork
        case .monitorDisk: return hub.descMonitorDisk
        case .monitorPower: return hub.descMonitorPower
        case .connectedDevices: return FeatureStrings.connectedDevices(L10n.shared.language).hubDescription
        case .fanControl: return FeatureStrings.fanControl(L10n.shared.language).hubDescription
        }
    }
}

extension AppPermission {
    func name(_ hub: FeatureHubStrings) -> String {
        switch self {
        case .accessibility: return hub.permAccessibility
        case .screenRecording: return hub.permScreenRecording
        case .fullDiskAccess: return hub.permFullDisk
        case .filesAndFolders: return hub.permFilesAndFolders
        case .notifications: return hub.permNotifications
        case .automationFinder: return hub.permAutomationFinder
        case .automationPlayback: return FeatureStrings.notchMusicExtras(L10n.shared.language).automationPermission
        case .audioCapture: return hub.permAudioCapture
        case .microphone: return FeatureStrings.recorder(L10n.shared.language).microphonePermissionName
        case .calendar: return FeatureStrings.notchCalendar(L10n.shared.language).title
        case .camera: return FeatureStrings.cameraPreview(L10n.shared.language).permName
        case .appManagement: return FeatureStrings.settingsCategories(L10n.shared.language).appManagement
        }
    }

    func explainer(_ hub: FeatureHubStrings) -> String {
        switch self {
        case .accessibility: return hub.explainAccessibility
        case .screenRecording: return hub.explainScreenRecording
        case .fullDiskAccess: return hub.explainFullDisk
        case .filesAndFolders: return hub.explainFilesAndFolders
        case .notifications: return hub.explainNotifications
        case .automationFinder: return hub.explainAutomationFinder
        case .automationPlayback: return FeatureStrings.notchMusicExtras(L10n.shared.language).automationExplanation
        case .audioCapture: return hub.explainAudioCapture
        case .microphone:
            return FeatureStrings.recorder(L10n.shared.language).microphonePermissionExplain
        case .calendar: return FeatureStrings.notchCalendar(L10n.shared.language).permission
        case .camera: return FeatureStrings.cameraPreview(L10n.shared.language).permExplain
        case .appManagement: return hub.explainAppManagement
        }
    }
}
