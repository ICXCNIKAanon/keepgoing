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
            let projectName = session.projectName
            self?.sessionStore.remove(sessionID: session.sessionID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !TerminalFocus.focusWindowForProject(projectName) {
                    TerminalFocus.activateAnyTerminal()
                }
            }
        }

        autoDismiss = AutoDismissMonitor(sessionStore: sessionStore)

        do {
            server = try Server { [weak self] payload in
                // Fire Telegram notification (async, non-blocking)
                let config = Config.load()
                if config.telegram.isConfigured {
                    TelegramNotifier.send(projectName: payload.projectName, config: config.telegram)
                }

                // Update HUD on main thread
                Task { @MainActor in
                    let config = Config.load()
                    if config.hud.enabled {
                        self?.sessionStore.add(payload)
                        self?.autoDismiss?.start()
                    }
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
