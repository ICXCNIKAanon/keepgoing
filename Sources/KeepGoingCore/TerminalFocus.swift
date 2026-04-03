import AppKit
import ApplicationServices

public enum TerminalFocus {
    public static let supportedBundleIDs: Set<String> = [
        "com.mitchellh.ghostty",
        "com.apple.Terminal",
    ]

    /// Find and focus a terminal window whose title contains the project name.
    @discardableResult
    public static func focusWindowForProject(_ projectName: String) -> Bool {
        for bundleID in supportedBundleIDs {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
                continue
            }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)

            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else {
                continue
            }

            for window in windows {
                var titleRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                      let title = titleRef as? String else {
                    continue
                }

                if title.localizedCaseInsensitiveContains(projectName) {
                    // Raise before activate
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    // Activate brings all windows forward
                    app.activate()
                    // Raise AGAIN after activate settles to force our window on top
                    usleep(150_000)
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    return true
                }
            }
        }
        return false
    }

    /// Check if the frontmost terminal window's title contains the project name.
    public static func frontmostTerminalContains(_ projectName: String) -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              supportedBundleIDs.contains(bundleID) else {
            return false
        }

        let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success else {
            return false
        }

        let window = windowRef as! AXUIElement
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String else {
            return false
        }

        return title.localizedCaseInsensitiveContains(projectName)
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
}
