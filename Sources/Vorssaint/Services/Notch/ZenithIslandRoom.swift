// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

// Zenith fork: the room an island keeps around what it shows once it grows
// past the camera's strip: a capsule notice, a burst (prayer time, charging)
// and the collapsed capture controls. Content keeps `edge` from the body's
// straight sides, past the shoulders, and the island grows wider instead of
// pressing content toward them, up to `maximumWidth` and the display; only
// past that does text wrap or truncate. Compiled into the tests.
//
// The compact strips beside the camera keep upstream's own measures: their
// wings sit in the menu bar between status items, where the room is the
// menus' (NotchGeometry.compactSideRoom), not the island's to take.

enum ZenithIslandRoom {
    /// From the body's straight side, past its shoulder, to the content.
    static let edge: CGFloat = 30
    /// Above and below a row of content.
    static let vertical: CGFloat = 14
    /// The narrowest grown island, as wide as the capsule notices always were.
    static let minimumWidth: CGFloat = 380
    /// The widest it grows before text wraps or truncates.
    static let maximumWidth: CGFloat = 580
    /// Kept clear at each side of the display.
    static let screenMargin: CGFloat = 12

    /// The island's width for `content` points of content inside shoulders of
    /// `shoulder`: the content and its edges, at least `minimum` and as wide as
    /// the island it grows from (`covering`), so nothing of that one shows
    /// past it; at most `maximum`, unless the island it covers is wider, and
    /// never past the display's margins.
    static func width(content: CGFloat, shoulder: CGFloat, covering closed: CGFloat = 0,
                      minimum: CGFloat = minimumWidth, maximum: CGFloat = maximumWidth,
                      screenWidth: CGFloat) -> CGFloat {
        let content = content.isFinite ? max(0, content) : 0
        let wanted = (content + (edge + max(0, shoulder)) * 2).rounded(.up)
        let floor = max(minimum, closed.isFinite ? closed.rounded(.up) : 0)
        let ceiling = max(floor, maximum)
        let screen = screenWidth.isFinite ? screenWidth - screenMargin * 2 : ceiling
        return max(0, min(min(max(wanted, floor), ceiling), screen))
    }

    /// What is left for content inside an island of `width`.
    static func contentWidth(width: CGFloat, shoulder: CGFloat) -> CGFloat {
        max(0, width - (edge + max(0, shoulder)) * 2)
    }

    /// How many lines `text` points of text take beside `fixed` points of
    /// glyphs and controls in an island of `width`: one, or two when it does
    /// not fit, as a grown island past its widest wraps rather than squeeze.
    static func lines(text: CGFloat, fixed: CGFloat, width: CGFloat, shoulder: CGFloat) -> Int {
        text > contentWidth(width: width, shoulder: shoulder) - fixed + 0.5 ? 2 : 1
    }

    /// A line of text as AppKit lays it out, rounded up.
    static func measure(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
    }
}

/// Zenith fork: the collapsed capture controls' row below the camera: the
/// tool's glyph and name, a dim hint and a round chevron (ZenithCaptureStrip).
/// The island is as wide as the widest tool's row needs, so choosing another
/// tool changes the words, not the island.
enum ZenithCaptureStripLayout {
    /// The row below the camera, starting just above the strip's bottom.
    static let rowHeight: CGFloat = 42
    static let rowOverlap: CGFloat = 2
    static let icon: CGFloat = 22
    static let iconGap: CGFloat = 10
    static let hintGap: CGFloat = 8
    static let buttonGap: CGFloat = 18
    static let button: CGFloat = 30
    static let titleFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
    static let hintFont = NSFont.systemFont(ofSize: 13)

    static func title(_ tool: ScreenCaptureTool, language: AppLanguage) -> String {
        tool.settingsTitle(Strings.localized(language), language: language)
    }

    static func hint(_ tool: ScreenCaptureTool, language: AppLanguage) -> String {
        let text = ZenithStrings.island(language)
        switch tool {
        case .screenshot: return text.dragArea
        case .recording: return text.dragRecording
        case .text: return text.dragText
        case .color: return text.clickColor
        case .scrolling: return text.dragScrolling
        }
    }

    /// The row's content for one tool, the gaps included.
    static func contentWidth(_ tool: ScreenCaptureTool, language: AppLanguage) -> CGFloat {
        icon + iconGap + ZenithIslandRoom.measure(title(tool, language: language), font: titleFont)
            + hintGap + ZenithIslandRoom.measure(hint(tool, language: language), font: hintFont) + 2
            + buttonGap + button
    }

    /// The island around the row, by the room rule, and at least as wide as
    /// the strip it collapsed from.
    static func size(language: AppLanguage, geometry: NotchGeometry) -> CGSize {
        let height = geometry.stripHeight - rowOverlap + rowHeight
        let content = ScreenCaptureTool.allCases.map { contentWidth($0, language: language) }.max() ?? 0
        let width = ZenithIslandRoom.width(content: content, shoulder: NotchLayout.shoulder(height: height),
                                           covering: geometry.cameraWidth + 56, screenWidth: geometry.screen.width)
        return CGSize(width: width, height: height)
    }
}
