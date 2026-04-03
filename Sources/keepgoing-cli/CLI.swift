import Foundation
import KeepGoingCore

@main
struct CLI {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        guard let command = args.first else {
            printUsage()
            return
        }

        switch command {
        case "install":
            install()
        case "uninstall":
            uninstall()
        case "status":
            status()
        case "telegram":
            let subArgs = Array(args.dropFirst())
            telegram(subArgs)
        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    static func printUsage() {
        print("""
        Usage: keepgoing-cli <command>

        Commands:
          install     Install KeepGoing and configure Claude Code hook
          uninstall   Remove KeepGoing and clean up hook
          status      Check if KeepGoing is running
          telegram    Manage Telegram notifications (setup, enable, disable, test)
        """)
    }

    static func install() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 1. Copy .app to ~/Applications
        let appsDir = home.appendingPathComponent("Applications")
        let appDest = appsDir.appendingPathComponent("KeepGoing.app")

        do {
            try fm.createDirectory(at: appsDir, withIntermediateDirectories: true)
            if fm.fileExists(atPath: appDest.path) {
                try fm.removeItem(at: appDest)
            }
            // Look for .app in the same directory as the CLI binary
            let cliDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
            let bundledApp = cliDir.appendingPathComponent("KeepGoing.app")
            if fm.fileExists(atPath: bundledApp.path) {
                try fm.copyItem(at: bundledApp, to: appDest)
                print("✓ Installed KeepGoing.app to ~/Applications/")
            } else {
                print("⚠ KeepGoing.app not found next to CLI. Build with `make bundle` first.")
                print("  Skipping app installation.")
            }
        } catch {
            print("✗ Failed to install app: \(error.localizedDescription)")
        }

        // 2. Patch Claude settings
        let settingsPath = home
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")

        do {
            let existingData = fm.fileExists(atPath: settingsPath.path)
                ? try Data(contentsOf: settingsPath)
                : nil
            let patched = try SettingsPatcher.addHook(to: existingData)
            try fm.createDirectory(
                at: settingsPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try patched.write(to: settingsPath)
            print("✓ Added Notification hook to ~/.claude/settings.json")
        } catch {
            print("✗ Failed to patch settings: \(error.localizedDescription)")
        }

        // 3. Add to Login Items
        let loginItemScript = """
        tell application "System Events"
            if not (exists login item "KeepGoing") then
                make login item at end with properties {path:"\(appDest.path)", hidden:true}
            end if
        end tell
        """
        let addLogin = Process()
        addLogin.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        addLogin.arguments = ["-e", loginItemScript]
        try? addLogin.run()
        addLogin.waitUntilExit()
        if addLogin.terminationStatus == 0 {
            print("✓ Added to Login Items (starts on boot)")
        }

        // 4. Launch the app
        if fm.fileExists(atPath: appDest.path) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = [appDest.path]
            try? task.run()
            print("✓ Launched KeepGoing")
        }

        print("")
        print("Note: KeepGoing needs Accessibility access to focus terminal windows.")
        print("If prompted, grant access in System Settings > Privacy & Security > Accessibility.")
    }

    static func uninstall() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 1. Quit app if running
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "KeepGoing.app"]
        try? task.run()
        task.waitUntilExit()

        // 2. Remove from Login Items
        let removeLogin = Process()
        removeLogin.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        removeLogin.arguments = ["-e", "tell application \"System Events\" to delete login item \"KeepGoing\""]
        removeLogin.standardError = FileHandle.nullDevice
        try? removeLogin.run()
        removeLogin.waitUntilExit()
        print("✓ Removed from Login Items")

        // 3. Remove app
        let appPath = home
            .appendingPathComponent("Applications")
            .appendingPathComponent("KeepGoing.app")
        if fm.fileExists(atPath: appPath.path) {
            try? fm.removeItem(at: appPath)
            print("✓ Removed ~/Applications/KeepGoing.app")
        }

        // 4. Remove hook from settings
        let settingsPath = home
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        if fm.fileExists(atPath: settingsPath.path) {
            do {
                let data = try Data(contentsOf: settingsPath)
                let patched = try SettingsPatcher.removeHook(from: data)
                try patched.write(to: settingsPath)
                print("✓ Removed hook from ~/.claude/settings.json")
            } catch {
                print("✗ Failed to update settings: \(error.localizedDescription)")
            }
        }

        print("✓ KeepGoing uninstalled")
    }

    static func telegram(_ args: [String]) {
        guard let sub = args.first else {
            print("""
            Usage: keepgoing-cli telegram <command>

            Commands:
              setup     Connect a Telegram bot for push notifications
              enable    Enable Telegram notifications
              disable   Disable Telegram notifications
              test      Send a test notification
              status    Show Telegram configuration status
            """)
            return
        }

        switch sub {
        case "setup":
            telegramSetup()
        case "enable":
            var config = Config.load()
            guard config.telegram.botToken != nil, config.telegram.chatId != nil else {
                print("✗ Run `keepgoing-cli telegram setup` first")
                return
            }
            config.telegram.enabled = true
            try? config.save()
            print("✓ Telegram notifications enabled")
        case "disable":
            var config = Config.load()
            config.telegram.enabled = false
            try? config.save()
            print("✓ Telegram notifications disabled")
        case "test":
            let config = Config.load()
            guard config.telegram.isConfigured,
                  let token = config.telegram.botToken,
                  let chatId = config.telegram.chatId else {
                print("✗ Telegram not configured. Run `keepgoing-cli telegram setup` first")
                return
            }
            print("Sending test message...")
            let semaphore = DispatchSemaphore(value: 0)
            guard let url = TelegramNotifier.buildURL(botToken: token),
                  let body = try? TelegramNotifier.buildBody(chatId: chatId, projectName: "test") else {
                print("✗ Failed to build request")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error {
                    print("✗ Failed: \(error.localizedDescription)")
                } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    print("✓ Test message sent! Check Telegram.")
                } else {
                    print("✗ Unexpected response")
                }
                semaphore.signal()
            }.resume()
            semaphore.wait()
        case "status":
            let config = Config.load()
            if config.telegram.isConfigured {
                print("Telegram: enabled")
                print("Bot token: \(config.telegram.botToken!.prefix(10))...")
                print("Chat ID: \(config.telegram.chatId!)")
            } else if config.telegram.botToken != nil {
                print("Telegram: configured but disabled")
            } else {
                print("Telegram: not configured")
            }
        default:
            print("Unknown telegram command: \(sub)")
        }
    }

    static func telegramSetup() {
        print("""

        Telegram Setup
        ──────────────
        1. Open Telegram and message @BotFather
        2. Send /newbot and follow the prompts
        3. Copy the bot token (looks like 123456:ABC-DEF...)

        """)

        print("Paste your bot token: ", terminator: "")
        guard let token = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            print("✗ No token provided")
            return
        }

        // Validate token format: digits:alphanumeric
        guard token.contains(":"), token.split(separator: ":").count == 2 else {
            print("✗ Invalid token format. Should look like 123456:ABC-DEF...")
            return
        }

        print("")
        print("Now open Telegram and send /start to your new bot.")
        print("Waiting for your message (up to 60 seconds)...")

        // Poll getUpdates to find chat_id
        var chatId: String?
        let deadline = Date().addingTimeInterval(60)

        while Date() < deadline {
            guard let url = URL(string: "https://api.telegram.org/bot\(token)/getUpdates") else { break }
            let semaphore = DispatchSemaphore(value: 0)
            var responseData: Data?
            URLSession.shared.dataTask(with: url) { data, _, _ in
                responseData = data
                semaphore.signal()
            }.resume()
            semaphore.wait()

            if let data = responseData,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["result"] as? [[String: Any]],
               let first = results.first,
               let message = first["message"] as? [String: Any],
               let chat = message["chat"] as? [String: Any],
               let id = chat["id"] as? Int {
                chatId = String(id)
                break
            }

            Thread.sleep(forTimeInterval: 2)
        }

        guard let chatId else {
            print("✗ Timed out waiting for /start message. Try again.")
            return
        }

        // Save config
        var config = Config.load()
        config.telegram.enabled = true
        config.telegram.botToken = token
        config.telegram.chatId = chatId

        do {
            try config.save()
        } catch {
            print("✗ Failed to save config: \(error.localizedDescription)")
            return
        }

        // Send confirmation message
        TelegramNotifier.send(projectName: "setup-complete", config: config.telegram)
        // Wait for the async send
        Thread.sleep(forTimeInterval: 1)

        print("")
        print("✓ Telegram connected! (chat_id: \(chatId))")
        print("✓ Sent confirmation message — check Telegram")
        print("✓ Config saved to ~/.keepgoing/config.json")
    }

    static func status() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "KeepGoing"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        if task.terminationStatus == 0 {
            print("KeepGoing is running")
        } else {
            print("KeepGoing is not running")
        }

        // Check if hook is installed
        let fm = FileManager.default
        let settingsPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        if fm.fileExists(atPath: settingsPath.path),
           let data = try? Data(contentsOf: settingsPath),
           let str = String(data: data, encoding: .utf8),
           str.contains("localhost:7433") {
            print("Hook is installed in ~/.claude/settings.json")
        } else {
            print("Hook is NOT installed")
        }
    }
}
