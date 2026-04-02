import AppKit
import CoreGraphics

public enum TerminalFocus {
    public static let supportedBundleIDs: Set<String> = [
        "com.mitchellh.ghostty",
        "com.apple.Terminal",
    ]

    /// List all terminal windows currently on screen.
    public static func listWindows() -> [TerminalWindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let windowID = info[kCGWindowNumber as String] as? UInt32,
                  let title = info[kCGWindowName as String] as? String,
                  let app = NSRunningApplication(processIdentifier: pid),
                  let bundleID = app.bundleIdentifier,
                  supportedBundleIDs.contains(bundleID)
            else { return nil }

            return TerminalWindowInfo(bundleID: bundleID, pid: pid, windowID: windowID, title: title)
        }
    }

    /// Activate the terminal app and raise the matching window.
    public static func focus(_ window: TerminalWindowInfo) {
        // Activate the app
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate()
        }

        // Raise the specific window via AppleScript
        let appName = appName(for: window.bundleID)
        let escapedTitle = window.title.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "\(appName)"
            activate
            repeat with w in windows
                if name of w contains "\(escapedTitle)" then
                    set index of w to 1
                    return
                end if
            end repeat
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    /// Activate any terminal app as a fallback.
    public static func activateAnyTerminal() {
        for bundleID in supportedBundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                app.activate()
                return
            }
        }
    }

    private static func appName(for bundleID: String) -> String {
        switch bundleID {
        case "com.mitchellh.ghostty": return "Ghostty"
        case "com.apple.Terminal": return "Terminal"
        default: return bundleID
        }
    }
}
