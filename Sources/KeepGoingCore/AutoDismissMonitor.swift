import AppKit

@MainActor
public final class AutoDismissMonitor {
    private var timer: Timer?
    private let sessionStore: SessionStore
    private let pollInterval: TimeInterval

    public init(sessionStore: SessionStore, pollInterval: TimeInterval = 0.5) {
        self.sessionStore = sessionStore
        self.pollInterval = pollInterval
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.check()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        if sessionStore.isEmpty {
            stop()
            return
        }

        // Check each tracked session against the frontmost terminal window
        for session in sessionStore.sessions {
            if TerminalFocus.frontmostTerminalContains(session.projectName) {
                sessionStore.remove(sessionID: session.sessionID)
            }
        }
    }
}
