// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ApplicationServices

// Zenith fork: reads which project an editor's focused window shows, through
// Accessibility, which Zenith already holds for its other features. Only
// reads: the window's document (a file URL VS Code, Cursor and Xcode set) and
// its title. Without the permission it reads nothing and asks for nothing.
// The title names a folder only by its last component, which is matched
// against the folders the person pinned, the repositories seen lately and,
// for the VS Code family, the folders its own `storage.json` lists.

enum GitFocusReader {
    struct Focus: Equatable {
        var document: String?
        var title: String?
    }

    /// The focused (or else main) window's document and title; nothing
    /// without Accessibility. Each question waits a quarter second at most.
    static func read(pid: pid_t) -> Focus? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard let window = element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute) else {
            return Focus()
        }
        AXUIElementSetMessagingTimeout(window, 0.25)
        return Focus(document: string(window, kAXDocumentAttribute), title: string(window, kAXTitleAttribute))
    }

    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        if let text = value as? String { return text.isEmpty ? nil : text }
        if let url = value as? URL { return url.absoluteString }
        return nil
    }

    // MARK: Resolving

    /// The repository the focus names: its document's, or the known folder
    /// its title names. Off the main thread.
    static func repository(for focus: Focus, editor: GitEditor, known: [String],
                           storage: (GitEditor) -> [String]) -> GitRepoLocation? {
        if let document = focus.document, let path = GitEditor.path(fromDocument: document),
           let location = GitRepoLocator.locate(from: path) {
            return location
        }
        guard let title = focus.title else { return nil }
        let names = editor.folderNames(fromTitle: title)
        guard !names.isEmpty else { return nil }
        if let folder = GitEditor.resolve(names: names, among: known), let location = GitRepoLocator.locate(from: folder) {
            return location
        }
        if let folder = GitEditor.resolve(names: names, among: storage(editor)),
           let location = GitRepoLocator.locate(from: folder) {
            return location
        }
        return nil
    }

    /// The folders a VS Code family editor lists in its `storage.json`.
    static func storageFolders(_ editor: GitEditor) -> [String] {
        guard let folder = editor.storageFolder else { return [] }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("User/globalStorage/storage.json", isDirectory: false)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              (attributes[.size] as? NSNumber)?.intValue ?? 0 < 8 * 1024 * 1024,
              let data = try? Data(contentsOf: url) else { return [] }
        return GitEditor.storageFolders(data)
    }
}
