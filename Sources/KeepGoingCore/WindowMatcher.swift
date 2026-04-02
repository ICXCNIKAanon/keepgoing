import Foundation

public struct TerminalWindowInfo: Sendable {
    public let bundleID: String
    public let pid: pid_t
    public let windowID: UInt32
    public let title: String

    public init(bundleID: String, pid: pid_t, windowID: UInt32, title: String) {
        self.bundleID = bundleID
        self.pid = pid
        self.windowID = windowID
        self.title = title
    }
}

public enum WindowMatcher {
    public static func findMatch(
        cwd: String,
        windows: [TerminalWindowInfo]
    ) -> TerminalWindowInfo? {
        let projectName = URL(fileURLWithPath: cwd).lastPathComponent
        guard !projectName.isEmpty, projectName != "/" else { return nil }

        // Search window titles for the project name
        return windows.first { $0.title.localizedCaseInsensitiveContains(projectName) }
    }
}
