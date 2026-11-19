// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

/// Zenith fork: the measures of a Vercel build in the closed island, shared by
/// the island's geometry (NotchService) and the strips that draw it
/// (VercelActivityStrips), so the wings fit what is drawn.
///
/// Around a camera: the state's mark and its word left of the camera, the
/// project right of it. In a floating capsule: mark, word and project in one row.
enum VercelActivityLayout {
    static let labelFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
    static let projectFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let markSpacing: CGFloat = 5
    /// Below this wing the words go and only the mark and the project stay.
    static let labelledWing: CGFloat = 72

    static func symbol(_ activity: VercelSupport.Activity) -> String {
        switch activity {
        case .building: return VercelSupport.symbol
        case .result(_, let state): return state.symbol
        }
    }

    /// "Building", "Ready", "Error" or "Canceled".
    static func label(_ activity: VercelSupport.Activity, language: AppLanguage) -> String {
        ZenithStrings.vercel(language).label(activity.state)
    }

    /// The project, with how many more build alongside it.
    static func detail(_ activity: VercelSupport.Activity) -> String {
        if case .building(let project, let count) = activity, count > 1 { return "\(project) +\(count - 1)" }
        return activity.project
    }

    static func iconSize(height: CGFloat) -> CGFloat { min(13, NotchTimerSupport.stripIconSize(height: height)) }

    /// The wider side, measured as the strip draws it, with the clearance from
    /// the silhouette's curve and air beside the camera. The watch's wings
    /// fit the same mark-and-reading shape, so the island lends them.
    static func stripWing(_ activity: VercelSupport.Activity?, language: AppLanguage,
                          in geometry: NotchGeometry) -> CGFloat {
        guard let activity else { return NotchWatchSupport.stripWingRange.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let height = provisional.compactActivityContentHeight
        let icon = iconSize(height: height)
        let iconInset = provisional.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = iconInset + symbolWidth(symbol(activity), size: icon) + markSpacing
            + width(label(activity, language: language), font: labelFont)
        let right = textInset + width(detail(activity), font: projectFont)
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }

    /// The floating capsule's row: mark, word and project.
    static func capsuleSurface(_ activity: VercelSupport.Activity?, language: AppLanguage,
                               geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let activity else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.spacing
            + layout.width(label(activity, language: language), font: layout.titleFont) + layout.groupSpacing
            + layout.width(detail(activity), font: layout.detailFont)
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func symbolWidth(_ name: String, size: CGFloat) -> CGFloat {
        NotchKeepAwakeSupport.symbolWidth(name, size: size)
    }
}
