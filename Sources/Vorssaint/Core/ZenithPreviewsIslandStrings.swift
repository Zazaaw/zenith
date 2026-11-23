// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the preview cards of the island's and Zenith's own Settings
// pages (Dynamic Island, Companion, Face Unlock, iPhone Remote, Batteries,
// Shelf, Workspaces, Command Bar). English in every language, like the rest
// of Zenith's own pages. The names, places and numbers in the pictures are
// made up.

struct ZenithPreviewsIslandStrings {
    // Dynamic Island.
    let notchLayout = "Layout"
    let notchContent = "Content"
    let notchActivity = "Activity"
    let notchBehavior = "Behavior"
    let notchCompanion = "Companion"
    let notchLayoutCaption = "The island open on this Mac, at its real size, with the size and buttons set below."
    let notchContentCaption = "The section picked below, as the open island draws it."
    let notchActivityCaption = "What the closed island shows: a notice growing out of it, then what it rests with."
    let notchBehaviorCaption = "Loops while you look: the pointer reaches the island and it opens."
    let notchCompanionCaption = "The companion resting beside the camera, as it looks and sleeps right now."
    let island = "Island"
    let section = "Section"
    let notices = "Notices"
    let opening = "Opening"

    // Companion.
    let companionCaption = "Your companion beside the camera, in the look chosen below. Switched off, it sleeps."
    let companion = "Companion"

    // Face Unlock.
    let faceScanning = "Scanning"
    let faceSuccess = "Success"
    let faceFailure = "Failure"
    let faceScanningCaption = "On the lock screen, the island looks for your face."
    let faceSuccessCaption = "Your face matched: the island says so, then welcomes you back."
    let faceFailureCaption = "Not you, or too dark: the island shakes it off and waits for another try."
    let faceAnimation = "Animation"

    // iPhone Remote.
    let remoteLocked = "Locked"
    let remoteStatus = "Status"
    let remoteLockedCaption = "Locked from your iPhone, the lock screen’s island says which one did it."
    let remoteStatusCaption = "When your iPhone checks on the Mac, the island shows it for a moment."
    let remoteDevice = "Alex’s iPhone"
    let remote = "iPhone Remote"

    // Batteries.
    let batteriesPage = "Page"
    let batteriesLow = "Low"
    let batteriesCompact = "Compact"
    let batteriesPageCaption = "Every device’s battery in the open island, drawn from sample readings."
    let batteriesLowCaption = "A device running low grows the island for a moment with the Battery Low card."
    let batteriesCompactCaption = "After the card, the closed island keeps the device and its level beside the camera."
    let batteriesLook = "Look"
    let batteriesAlerts = "Alerts"

    // Shelf.
    let shelfFiles = "Files"
    let shelfAirDrop = "AirDrop"
    let shelfFilesCaption = "Drag a file to the island and drop it on Files to keep it on the shelf."
    let shelfAirDropCaption = "Drop it on AirDrop instead to send it to a device nearby."
    let dropZones = "Drop zones"
    let sampleFile = "Brief.pdf"

    // Workspaces.
    let workspacesCaption = "Loops while you look: a workspace runs from the island and puts its apps in place."
    let workspacesList = "Workspaces"
    let sampleWorkspaces = ["Studio", "Code", "Meeting"]

    // Command Bar.
    let commandBarCaption = "Loops while you look: the bar drops out of the island and answers as you type."
    let commandBarQuery = "100 km to mi"
    let commandBarAnswer = "62.14 mi"
    let commandBarAnswerDetail = "Conversion"
    let commandBarCopy = "Copy"

    static let shared = ZenithPreviewsIslandStrings()
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func previewsIsland(_ language: AppLanguage) -> ZenithPreviewsIslandStrings { .shared }
}
