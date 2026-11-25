// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PackageDescription

// Zenith Pocket's shared core: the pairing code, the sealed envelope, the
// messages, and the relay client. The iPhone and Watch apps use it as a
// package; Zenith on the Mac compiles the same files through build.sh.
let package = Package(
    name: "PocketKit",
    platforms: [.macOS("14.0"), .iOS("26.0"), .watchOS("26.0")],
    products: [.library(name: "PocketKit", targets: ["PocketKit"])],
    targets: [
        .target(name: "PocketKit"),
        .testTarget(name: "PocketKitTests", dependencies: ["PocketKit"]),
    ]
)
