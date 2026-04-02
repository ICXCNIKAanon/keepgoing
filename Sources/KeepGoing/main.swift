import AppKit
import KeepGoingCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionStore = SessionStore()
    var server: Server?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            server = try Server { [weak self] payload in
                Task { @MainActor in
                    self?.sessionStore.add(payload)
                    print("Session added: \(payload.projectName) (\(payload.sessionID))")
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
