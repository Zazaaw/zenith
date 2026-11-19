// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the terminal readout follows the lock screen.
///
/// `NotchLockScreenService` asks here what the readout shows as the lock
/// screen appears, starts its sources with it and stops them as it goes, all
/// on the main thread. Each source reads only while the readout is on screen:
/// WakaTime and Vercel as viewers, `gh` on its own refresh, the system monitor
/// for CPU and battery alone. The agents and downloads it starts are stopped
/// by the lock screen itself, with the rest of its scene.
enum NotchLockScreenTerminal {
    /// What the readout shows, or nil when it is off.
    static func configuration(in defaults: UserDefaults = .standard) -> NotchLockScreenTerminalConfiguration? {
        guard NotchLockScreenTerminalSupport.isEnabled(in: defaults) else { return nil }
        let sources = NotchLockScreenTerminalSupport.selection(in: defaults).shown.filter { isAvailable($0, in: defaults) }
        guard !sources.isEmpty else { return nil }
        return NotchLockScreenTerminalConfiguration(sources: sources,
                                                    showsProjects: NotchLockScreenTerminalSupport.showsProjects(in: defaults),
                                                    title: NotchLockScreenTerminalSupport.title(in: defaults))
    }

    /// Whether this Mac can fill a line at all. Vercel and GitHub find out
    /// for themselves: a missing token or `gh` simply leaves the line empty.
    private static func isAvailable(_ source: NotchLockScreenTerminalSource, in defaults: UserDefaults) -> Bool {
        switch source {
        case .agents: return NotchAgentSupport.isEnabled(in: defaults)
        case .waka: return WakaTimeSupport.hasConfiguration() || MainActor.assumeIsolated { WakaTimeService.shared.hasToken }
        case .vercel, .ci, .sys: return true
        case .dl: return NotchSupport.routes(.download)
        case .timer: return NotchTimerSupport.isEnabled(in: defaults)
        }
    }

    static func start(_ configuration: NotchLockScreenTerminalConfiguration) {
        MainActor.assumeIsolated {
            stop()
            let sources = Set(configuration.sources)
            if sources.contains(.agents) { AgentUsageService.shared.syncWithPreferences() }
            if sources.contains(.dl) { NotchDownloadService.shared.syncWithPreferences() }
            if sources.contains(.waka) {
                WakaTimeService.shared.viewAppeared()
                Running.wakaTime = true
            }
            if sources.contains(.vercel) {
                VercelService.shared.lockScreenShown()
                Running.vercel = true
            }
            if sources.contains(.ci) {
                GitHubService.shared.lockScreenShown()
                Running.gitHub = true
            }
            if sources.contains(.sys) {
                var needs = SystemMonitorPanelNeeds()
                needs.cpu = true
                needs.battery = true
                SystemMonitor.shared.setLockScreenNeeds(needs)
                Running.monitor = true
            }
        }
    }

    static func stop() {
        MainActor.assumeIsolated {
            if Running.wakaTime {
                WakaTimeService.shared.viewDisappeared()
                Running.wakaTime = false
            }
            if Running.vercel {
                VercelService.shared.lockScreenHidden()
                Running.vercel = false
            }
            if Running.gitHub {
                GitHubService.shared.lockScreenHidden()
                Running.gitHub = false
            }
            if Running.monitor {
                SystemMonitor.shared.setLockScreenNeeds(.none)
                Running.monitor = false
            }
        }
    }
}

@MainActor
private enum Running {
    static var wakaTime = false
    static var vercel = false
    static var gitHub = false
    static var monitor = false
}
