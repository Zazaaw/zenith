// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import ApplicationServices
import CoreGraphics
import Foundation

// Zenith fork: reads a chat window's Accessibility tree for Privacy Blur,
// off the main thread, one read at a time on a serial queue. A whole window
// (about 85 elements in WhatsApp, 25 ms on an M4) when it opens, changes
// layout or switches chat; only the part that scrolls (about a dozen
// elements, 2.5 ms) while it scrolls.
//
// Privacy: each element gives its role, subrole, position, size and
// children, in one call. Nothing else is asked for, never AXValue,
// AXTitle, AXDescription or any other text: Privacy Blur finds the items
// by their shape, not by what they say. Nothing read is stored past the
// next read or leaves the process.

/// What one read found.
struct PrivacyBlurRead: @unchecked Sendable {
    /// The window's tree, or the part read again; nil when the window
    /// couldn't be read (no Accessibility, gone, not answering).
    let root: PrivacyBlurNode?
    /// The window's frame as Accessibility has it, which the tree's frames share.
    let window: CGRect
    /// The window's element, to read its frame again with a part.
    let windowHandle: PrivacyBlurElementHandle?
    /// The scroll totals as the read began.
    let totals: [Int: CGFloat]
    let elements: Int
    let duration: TimeInterval
}

final class PrivacyBlurContentReader: @unchecked Sendable {
    /// A whole window: deep enough for WhatsApp's 9 levels with room, and
    /// a budget that caps an app with a huge tree (an Electron app) at a
    /// cost still off the main thread.
    static let maximumDepth = 18
    static let maximumElements = 900
    /// A scroll area read again: its rows and bubbles and their wrappers.
    static let partDepth = 3
    /// Per element: an app that stops answering never holds a read for long.
    static let timeout: Float = 0.25

    private static let attributes = [kAXRoleAttribute, kAXSubroleAttribute, kAXPositionAttribute, kAXSizeAttribute,
                                     kAXChildrenAttribute] as CFArray
    private static let frameAttributes = [kAXPositionAttribute, kAXSizeAttribute] as CFArray

    private let queue = DispatchQueue(label: "id.satuvisual.zenith.privacy-blur.reader", qos: .userInteractive)
    // Confined to `queue`.
    private var nextID = 0
    private var windowElements: [CGWindowID: AXUIElement] = [:]

    /// Reads the window `windowID` of `pid` whole; `frame` is the window
    /// server's frame, to tell its Accessibility window among the app's.
    func readWindow(pid: pid_t, windowID: CGWindowID, frame: CGRect, ledger: PrivacyBlurScrollLedger,
                    completion: @escaping @MainActor (PrivacyBlurRead) -> Void) {
        queue.async { [self] in
            let start = CFAbsoluteTimeGetCurrent()
            let totals = ledger.snapshot()
            var read = PrivacyBlurRead(root: nil, window: frame, windowHandle: nil, totals: totals, elements: 0, duration: 0)
            if AXIsProcessTrusted(), let element = window(pid: pid, windowID: windowID, frame: frame),
               let windowFrame = Self.frame(of: element) {
                var budget = Self.maximumElements
                let root = walk(element, depth: 0, maximumDepth: Self.maximumDepth, window: windowFrame, budget: &budget)
                read = PrivacyBlurRead(root: root, window: windowFrame, windowHandle: PrivacyBlurElementHandle(element),
                                       totals: totals, elements: Self.maximumElements - budget,
                                       duration: CFAbsoluteTimeGetCurrent() - start)
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(read) } }
        }
    }

    /// Reads one part of a window again (a scroll area), with the window's frame.
    func readPart(_ part: PrivacyBlurElementHandle, window: PrivacyBlurElementHandle, ledger: PrivacyBlurScrollLedger,
                  completion: @escaping @MainActor (PrivacyBlurRead) -> Void) {
        queue.async { [self] in
            let start = CFAbsoluteTimeGetCurrent()
            let totals = ledger.snapshot()
            let windowElement = window.element as! AXUIElement
            let partElement = part.element as! AXUIElement
            var read = PrivacyBlurRead(root: nil, window: .null, windowHandle: window, totals: totals, elements: 0, duration: 0)
            if let windowFrame = Self.frame(of: windowElement) {
                var budget = Self.maximumElements
                let root = walk(partElement, depth: 0, maximumDepth: Self.partDepth, window: windowFrame, budget: &budget)
                read = PrivacyBlurRead(root: root, window: windowFrame, windowHandle: window, totals: totals,
                                       elements: Self.maximumElements - budget, duration: CFAbsoluteTimeGetCurrent() - start)
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(read) } }
        }
    }

    /// Lets go of the windows it knew (the tracker stopped).
    func forget() {
        queue.async { [self] in windowElements.removeAll() }
    }

    // MARK: Walking

    /// The window's Accessibility element: the one remembered, while it
    /// still sits on the window server's frame, or the app's window that does.
    private func window(pid: pid_t, windowID: CGWindowID, frame: CGRect) -> AXUIElement? {
        if let known = windowElements[windowID], let knownFrame = Self.frame(of: known),
           Self.matches(knownFrame, frame) { return known }
        windowElements[windowID] = nil
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Self.timeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        let found = windows.first { element in
            AXUIElementSetMessagingTimeout(element, Self.timeout)
            return Self.frame(of: element).map { Self.matches($0, frame) } ?? false
        }
        windowElements[windowID] = found
        return found
    }

    private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }

    /// Role, subrole, frame and children of `element`, and the same for its
    /// children: not into leaf roles (their frame is the item), not past the
    /// depth or the budget, and not into a child wholly outside the window
    /// (a lazy list's far rows).
    private func walk(_ element: AXUIElement, depth: Int, maximumDepth: Int, window: CGRect,
                      budget: inout Int) -> PrivacyBlurNode? {
        guard budget > 0 else { return nil }
        budget -= 1
        AXUIElementSetMessagingTimeout(element, Self.timeout)
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, Self.attributes, [], &values) == .success,
              let array = values as [AnyObject]?, array.count == 5 else { return nil }
        let role = array[0] as? String ?? ""
        let subrole = array[1] as? String ?? ""
        let frame = CGRect(origin: Self.point(array[2]) ?? .zero, size: Self.size(array[3]) ?? .zero)
        nextID += 1
        var node = PrivacyBlurNode(id: nextID, role: role, subrole: subrole, frame: frame,
                                   handle: PrivacyBlurElementHandle(element))
        // A child wholly outside the window (a lazy list's far rows) keeps
        // its frame, but its own children carry no items.
        let outside = depth > 0 && !frame.isEmpty && !frame.intersects(window)
        guard depth < maximumDepth, !outside, !PrivacyBlurRole.leaves.contains(role),
              let children = array[4] as? [AXUIElement], !children.isEmpty else { return node }
        for child in children {
            guard budget > 0 else { break }
            if let read = walk(child, depth: depth + 1, maximumDepth: maximumDepth, window: window, budget: &budget) {
                node.children.append(read)
            }
        }
        return node
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, frameAttributes, [], &values) == .success,
              let array = values as [AnyObject]?, array.count == 2,
              let origin = point(array[0]), let size = size(array[1]) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func point(_ value: AnyObject) -> CGPoint? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        var point = CGPoint.zero
        return AXValueGetType(axValue) == .cgPoint && AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private static func size(_ value: AnyObject) -> CGSize? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        var size = CGSize.zero
        return AXValueGetType(axValue) == .cgSize && AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }
}
