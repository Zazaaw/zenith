// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A page or a directly selectable tool in the flat Settings sidebar.
struct SettingsSidebarItem: Identifiable {
    enum ID: Hashable {
        case page(SettingsPage)
        case feature(AppFeature)
        case setting(SettingsSectionAnchor)
    }

    let id: ID
    let destination: FeatureSettingsDestination
    let title: String
    let icon: String
}

/// One group of the sidebar (or its tiles), in `SettingsSidebarLayout`'s order.
struct SettingsSidebarSection: Identifiable {
    let group: SettingsSidebarGroup
    let items: [SettingsSidebarItem]
    var id: SettingsSidebarGroup { group }
    var title: String { group.title }
}

/// Builds one row per tool, even when several tools share one Settings card.
enum SettingsSidebarSupport {
    /// Zenith fork: pages that hold several features yet keep a single row,
    /// as every page does now: one sidebar row, one page, one feature's job.
    /// Their features land on their sections without rows of their own.
    static let onePageRows: Set<SettingsPage> = [.scrolling, .pointer, .mouseButtons, .dock, .spaces]

    static func items(page: SettingsPage, title: String, icon: String,
                      preferredFeatures: [AppFeature], includePage: Bool,
                      isAvailable: (AppFeature) -> Bool,
                      featureTitle: (AppFeature) -> String) -> [SettingsSidebarItem] {
        guard FeatureVisibilitySupport.isPageVisible(page, isAvailable: isAvailable) else { return [] }
        let pageItem = SettingsSidebarItem(id: .page(page),
                                           destination: FeatureSettingsDestination(page),
                                           title: title, icon: icon)
        var rows = includePage ? [pageItem] : []
        var seenFeatures: Set<AppFeature> = []
        for feature in preferredFeatures + AppFeature.allCases where !onePageRows.contains(page) {
            guard seenFeatures.insert(feature).inserted else { continue }
            let destination = feature.settingsDestination
            guard destination.page == page, destination.sectionAnchor != nil,
                  isAvailable(feature) else { continue }
            rows.append(SettingsSidebarItem(id: .feature(feature),
                                            destination: destination,
                                            title: featureTitle(feature),
                                            icon: feature.symbolName))
        }
        if rows.isEmpty { rows.append(pageItem) }
        return rows
    }

    /// Scrolling capture shares screenshot ownership but has its own destination.
    static func screenshotRows(_ rows: [SettingsSidebarItem], language: AppLanguage)
        -> [SettingsSidebarItem] {
        guard let index = rows.firstIndex(where: { $0.id == .feature(.screenshot) }) else {
            return rows
        }
        var result = rows
        result.insert(SettingsSidebarItem(
            id: .setting(.screenshotScrolling),
            destination: ScreenCaptureTool.scrolling.settingsDestination,
            title: FeatureStrings.screenshot(language).scrollingCaptureTitle,
            icon: ScreenCaptureTool.scrolling.systemImageName), at: index + 1)
        return result
    }

    static func selection(for destination: FeatureSettingsDestination,
                          in items: [SettingsSidebarItem],
                          preferredID: SettingsSidebarItem.ID? = nil)
        -> SettingsSidebarItem.ID? {
        if let preferredID,
           items.contains(where: { $0.id == preferredID && $0.destination == destination }) {
            return preferredID
        }
        if destination.sectionAnchor != nil,
           let tool = items.first(where: { $0.destination == destination }) {
            return tool.id
        }
        if items.contains(where: { $0.id == .page(destination.page) }) {
            return .page(destination.page)
        }
        return items.first(where: { $0.destination.page == destination.page })?.id
    }
}
