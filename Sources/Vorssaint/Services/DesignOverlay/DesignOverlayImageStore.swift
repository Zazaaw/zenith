// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Zenith fork: a reference image, decoded upright, with what Image I/O said about it.
struct DesignOverlayReference {
    /// The copy in the app's container.
    let url: URL
    let image: CGImage
    let info: DesignOverlayImageInfo
}

/// Zenith fork: the design overlay's one reference file. A dropped, chosen or
/// pasted image is copied into `<Application Support>/<bundle id>/DesignOverlay`
/// (owner-only, through PrivateFileStore), so it outlives the original and
/// defaults only ever hold its name. A new reference replaces the last one.
enum DesignOverlayImageStore {
    static var folderURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent("DesignOverlay", isDirectory: true)
    }

    /// The last reference, when its file is still there.
    static func lastReferenceURL(_ memory: DesignOverlayMemory) -> URL? {
        guard let name = memory.lastImageName, let folder = folderURL else { return nil }
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Copies a picture into the container, its bytes untouched so the density
    /// it was exported with survives.
    static func store(fileAt source: URL, memory: DesignOverlayMemory) -> URL? {
        guard DesignOverlayImageInfo(url: source) != nil,
              let data = try? Data(contentsOf: source, options: .mappedIfSafe)
        else { return nil }
        return store(data: data, fileExtension: source.pathExtension, memory: memory)
    }

    static func store(data: Data, fileExtension: String, memory: DesignOverlayMemory) -> URL? {
        guard let folder = folderURL, PrivateFileStore.createDirectory(at: folder) else { return nil }
        let name = DesignOverlayMemory.referenceName(forExtension: fileExtension)
        let url = folder.appendingPathComponent(name)
        guard PrivateFileStore.write(data, to: url) else { return nil }
        // Only one reference is kept: a different extension leaves an older copy behind.
        if let others = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for other in others where other.lastPathComponent != name {
                try? FileManager.default.removeItem(at: other)
            }
        }
        memory.lastImageName = name
        return url
    }

    /// Reads a stored reference, upright.
    static func load(_ url: URL) -> DesignOverlayReference? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let info = DesignOverlayImageInfo(source: source)
        else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let image: CGImage?
        if orientation == 1 {
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        } else {
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(info.pixelWidth, info.pixelHeight),
            ] as CFDictionary)
        }
        guard let image else { return nil }
        return DesignOverlayReference(url: url, image: image, info: info)
    }

    /// An image on a pasteboard as file data: PNG first (Figma's Copy as PNG),
    /// then TIFF turned into PNG, then a copied image file.
    static func imageData(on pasteboard: NSPasteboard) -> (data: Data, fileExtension: String)? {
        if let png = pasteboard.data(forType: .png), DesignOverlayImageInfo(data: png) != nil {
            return (png, "png")
        }
        if let tiff = pasteboard.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return (png, "png")
        }
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        if let url = urls?.first, NotchPhotoActionsSupport.acceptsImage(
               (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType),
           let data = try? Data(contentsOf: url, options: .mappedIfSafe), DesignOverlayImageInfo(data: data) != nil {
            return (data, url.pathExtension)
        }
        return nil
    }
}
