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

        // 3. Launch the app
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

        // 2. Remove app
        let appPath = home
            .appendingPathComponent("Applications")
            .appendingPathComponent("KeepGoing.app")
        if fm.fileExists(atPath: appPath.path) {
            try? fm.removeItem(at: appPath)
            print("✓ Removed ~/Applications/KeepGoing.app")
        }

        // 3. Remove hook from settings
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
