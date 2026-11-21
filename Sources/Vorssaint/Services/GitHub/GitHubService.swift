// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: pull requests waiting for review and the person's own, read
/// with the GitHub CLI they already signed in with.
///
/// It reads every `GitHubSupport.refreshInterval` while the island runs and
/// shows the GitHub section, or the lock screen's terminal readout shows its
/// checks line, and when the page appears with an inbox older
/// than `GitHubSupport.staleAfter`. `gh` always runs off the main thread,
/// and never runs at all when it is not installed. Like the island's own
/// services it lives on the main thread.
final class GitHubService: ObservableObject {
    static let shared = GitHubService()

    enum State: Equatable {
        case idle, loading, ready, missingCLI, notSignedIn, failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var inbox: GitHubSupport.Inbox?
    @Published private(set) var executable: URL?
    @Published private(set) var lookingAgain = false

    private var polling = false
    private var request: Task<Void, Never>?
    private var timer: Timer?
    private var lastFetch: Date?
    /// The lock screen's terminal readout, while it shows the checks line.
    private var lockScreenViewers = 0

    private init() {}

    static func isModuleOn(in defaults: UserDefaults = .standard) -> Bool {
        NotchSupport.isEnabled(in: defaults) && NotchSupport.modules(in: defaults).contains(.github)
    }

    // MARK: Lifecycle

    /// Called with every island preference sync: starts or stops the refresh.
    func syncWithPreferences() {
        let wanted = Self.isModuleOn() || lockScreenViewers > 0
        guard wanted != polling else { return }
        polling = wanted
        if wanted {
            // An inbox read moments ago waits for the next turn.
            viewAppeared()
            let timer = Timer(timeInterval: GitHubSupport.refreshInterval, repeats: true) { [weak self] _ in
                self?.refresh()
            }
            timer.tolerance = 30
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else {
            stop()
        }
    }

    func stop() {
        polling = false
        timer?.invalidate()
        timer = nil
        request?.cancel()
        request = nil
    }

    /// The lock screen's terminal readout appeared with a checks line.
    func lockScreenShown() {
        lockScreenViewers += 1
        syncWithPreferences()
    }

    func lockScreenHidden() {
        guard lockScreenViewers > 0 else { return }
        lockScreenViewers -= 1
        syncWithPreferences()
    }

    func viewAppeared() {
#if VORSSAINT_DEVELOPMENT
        // Zenith fork: the island catalog draws sample data only.
        if IslandCatalog.isRendering { return }
#endif
        if state == .ready, let lastFetch, Date().timeIntervalSince(lastFetch) < GitHubSupport.staleAfter { return }
        refresh()
    }

    // MARK: Refresh

    func refresh(force: Bool = false) {
        if force { request?.cancel(); request = nil }
        guard request == nil else { return }
        let found = GitHubCLI.installed()
        if executable != found { executable = found }
        guard let found else {
            state = .missingCLI
            return
        }
        if inbox == nil { state = .loading }
        request = Task { @MainActor [weak self] in
            let outcome = await Self.read(found)
            guard let self, !Task.isCancelled else { return }
            self.request = nil
            self.lastFetch = Date()
            switch outcome {
            case .success(let inbox):
                self.inbox = inbox
                self.state = .ready
            case .failure(.notSignedIn):
                self.inbox = nil
                self.state = .notSignedIn
            case .failure(.failed):
                // Keep showing the last good inbox; say so only when there is none.
                if self.inbox == nil { self.state = .failed }
            }
        }
    }

    /// Runs the login shell to find a `gh` outside the usual folders, then
    /// tells the island, whose GitHub section may have just become available.
    func lookAgain() {
        guard !lookingAgain else { return }
        lookingAgain = true
        Task { @MainActor [weak self] in
            let found = await Task.detached(priority: .userInitiated) { GitHubCLI.lookAgain() }.value
            guard let self else { return }
            self.lookingAgain = false
            self.executable = found
            NotchService.shared.syncWithPreferences()
            self.refresh(force: true)
        }
    }

    // MARK: The CLI

    private static func read(_ executable: URL) async -> Result<GitHubSupport.Inbox, GitHubSupport.Failure> {
        await Task.detached(priority: .utility) {
            let result = BoundedProcessRunner.run(executable.path, GitHubSupport.arguments(),
                                                  timeout: GitHubSupport.timeout, maxOutputBytes: 4 * 1024 * 1024,
                                                  environment: GitHubSupport.environment(for: executable))
            guard result.status == 0, !result.timedOut, let inbox = GitHubSupport.inbox(from: result.output) else {
                if result.timedOut { return .failure(.failed) }
                return .failure(GitHubSupport.failure(status: result.status,
                                                      output: String(decoding: result.output, as: UTF8.self)))
            }
            return .success(inbox)
        }.value
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension GitHubService {
    func catalogPose(_ inbox: GitHubSupport.Inbox?) {
        state = inbox == nil ? .idle : .ready
        self.inbox = inbox
        lookingAgain = false
    }
}
#endif
