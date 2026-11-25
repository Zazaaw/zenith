// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Network
import Observation

/// Whether this iPhone has a network at all, so Pocket can say "you're
/// offline" instead of blaming a Mac that may be fine.
@MainActor
@Observable
final class NetworkWatch {
    private(set) var online = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.online = online }
        }
        monitor.start(queue: DispatchQueue(label: "id.satuvisual.zenith.pocket.network"))
    }

    deinit { monitor.cancel() }
}
