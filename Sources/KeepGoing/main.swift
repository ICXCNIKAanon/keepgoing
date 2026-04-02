import AppKit
import KeepGoingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionStore = SessionStore()
    var server: Server?
    var hudController: HUDWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        hudController = HUDWindowController(sessionStore: sessionStore) { [weak self] session in
            self?.sessionStore.remove(sessionID: session.sessionID)
            // Terminal focus will be added in Task 6
            print("Clicked: \(session.projectName)")
        }

        do {
            server = try Server { [weak self] payload in
                Task { @MainActor in
                    self?.sessionStore.add(payload)
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
