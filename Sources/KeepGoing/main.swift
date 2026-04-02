import AppKit
import KeepGoingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionStore = SessionStore()
    var server: Server?
    var hudController: HUDWindowController?
    var autoDismiss: AutoDismissMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        hudController = HUDWindowController(sessionStore: sessionStore) { [weak self] session in
            // Find and focus the terminal window
            let windows = TerminalFocus.listWindows()
            if let match = WindowMatcher.findMatch(cwd: session.cwd, windows: windows) {
                TerminalFocus.focus(match)
            } else {
                TerminalFocus.activateAnyTerminal()
            }
            self?.sessionStore.remove(sessionID: session.sessionID)
        }

        autoDismiss = AutoDismissMonitor(sessionStore: sessionStore)

        do {
            server = try Server { [weak self] payload in
                Task { @MainActor in
                    self?.sessionStore.add(payload)
                    self?.autoDismiss?.start()
                }
            }
            server?.start()
        } catch {
            print("KeepGoing: failed to start server: \(error)")
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
