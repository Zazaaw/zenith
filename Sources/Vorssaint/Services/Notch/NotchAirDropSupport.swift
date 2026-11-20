// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

/// Where files dragged onto the open island land. Zenith adds AirDrop beside
/// upstream's two targets: the shelf (Files) and Optimize media, and, for
/// images, the photo actions (NotchPhotoActionsSupport) and the design
/// overlay (DesignOverlaySupport). The raw values name them in the drop
/// zones' stored order (ZenithDropZones), so they stay as they are.
enum NotchDropTarget: String, CaseIterable {
    case files
    case airDrop
    case media
    case transform
    case removeBackground
    case overlay

    /// The targets only an image drag gets, which follow the others.
    var isPhotoAction: Bool { self == .transform || self == .removeBackground || self == .overlay }
}

/// Zenith fork: the AirDrop drop zone in the notch. Drop files on it and the
/// system AirDrop picker opens with them, one step instead of a share menu.
enum NotchAirDropSupport {
    /// Whether the AirDrop zone is on (Settings › Shelf › Drop zones). It stands
    /// on its own: neither the shelf nor the island's Files section has to be on.
    static var isEnabled: Bool { ZenithDropZones.current().isOn(.airDrop) }

    /// The targets offered for a drag, left to right.
    static func targets(files: Bool, airDrop: Bool, media: Bool) -> [NotchDropTarget] {
        targets(files: files, airDrop: airDrop, media: media, photo: [])
    }

    /// The same, with the photo targets an image drag gets after the others.
    static func targets(files: Bool, airDrop: Bool, media: Bool, photo: [NotchDropTarget]) -> [NotchDropTarget] {
        (files ? [.files] : []) + (airDrop ? [.airDrop] : []) + (media ? [.media] : [])
            + photo.filter(\.isPhotoAction)
    }

    /// The target under `point`, among the tiles the chooser draws across the
    /// page (`ZenithDropZoneLayout`): equal tiles on one row, or on two when
    /// even the widened island cannot hold them. The nearest tile wins, so a
    /// point in a gap or past an edge still finds one.
    static func target(at point: CGPoint, in geometry: NotchGeometry, size: CGSize,
                       targets: [NotchDropTarget]) -> NotchDropTarget {
        guard targets.count > 1 else { return targets.first ?? .files }
        let content = geometry.contentSize(for: size)
        let local = CGPoint(x: point.x - (size.width / 2 - content.width / 2), y: point.y - geometry.pageTopInset)
        let index = ZenithDropZoneLayout.index(at: local, count: targets.count, in: content)
        return targets[min(max(index, 0), targets.count - 1)]
    }

    /// File URLs on a drag pasteboard, the only items Zenith sends over AirDrop.
    static func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) ?? []
        return objects.compactMap { $0 as? URL }.filter(\.isFileURL)
    }

    /// Whether AirDrop can take these files on this Mac right now.
    static func canSend(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return false }
        return service.canPerform(withItems: urls)
    }

    /// Opens the system AirDrop picker with the files. False when AirDrop is
    /// unavailable, for instance with Wi-Fi or Bluetooth off.
    @MainActor
    @discardableResult
    static func send(_ urls: [URL]) -> Bool {
        guard canSend(urls), let service = NSSharingService(named: .sendViaAirDrop) else { return false }
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
        return true
    }
}
