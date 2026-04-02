import AppKit

@MainActor
public final class AutoDismissMonitor {
    private var timer: Timer?
    private let sessionStore: SessionStore
    private let pollInterval: TimeInterval

    public init(sessionStore: SessionStore, pollInterval: TimeInterval = 3.0) {
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
        // Nothing to monitor
        if sessionStore.isEmpty {
            stop()
            return
        }

        // Get frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              TerminalFocus.supportedBundleIDs.contains(bundleID)
        else { return }

        // Get terminal windows and check which sessions are visible
        let windows = TerminalFocus.listWindows()
        // Find the frontmost window (first in list for the active app)
        guard let frontWindow = windows.first(where: { $0.bundleID == bundleID }) else { return }

        // Check if any tracked session matches the frontmost terminal window
        for session in sessionStore.sessions {
            if WindowMatcher.findMatch(cwd: session.cwd, windows: [frontWindow]) != nil {
                sessionStore.remove(sessionID: session.sessionID)
            }
        }
    }
}
