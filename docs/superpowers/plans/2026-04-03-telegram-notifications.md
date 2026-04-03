# Telegram Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional Telegram push notifications to KeepGoing so users get alerted on their phone when Claude Code needs input.

**Architecture:** A `Config` model reads `~/.keepgoing/config.json` on each notification. If Telegram is enabled, `TelegramNotifier` fires an async URLSession POST to the Telegram Bot API in parallel with the existing HUD. The CLI gains a `telegram` subcommand for interactive setup.

**Tech Stack:** Foundation URLSession (HTTPS POST), Codable config, existing KeepGoingCore library

---

## File Structure

```
Sources/
├── KeepGoingCore/
│   ├── Config.swift              # NEW — Codable config model, read/write ~/.keepgoing/config.json
│   └── TelegramNotifier.swift    # NEW — sendMessage via Telegram Bot API
├── KeepGoing/
│   └── main.swift                # MODIFY — fire TelegramNotifier alongside SessionStore
└── keepgoing-cli/
    └── CLI.swift                 # MODIFY — add telegram subcommand

Tests/
└── KeepGoingTests/
    ├── ConfigTests.swift         # NEW — config parsing/defaults tests
    └── TelegramNotifierTests.swift  # NEW — URL/body construction tests
```

---

### Task 1: Config Model (TDD)

**Files:**
- Create: `Sources/KeepGoingCore/Config.swift`
- Create: `Tests/KeepGoingTests/ConfigTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/KeepGoingTests/ConfigTests.swift`:
```swift
import Testing
import Foundation
@testable import KeepGoingCore

@Suite struct ConfigTests {
    @Test func defaultsWhenFileDoesNotExist() {
        let config = Config.load(from: "/tmp/keepgoing-test-nonexistent/config.json")
        #expect(config.hud.enabled == true)
        #expect(config.telegram.enabled == false)
        #expect(config.telegram.botToken == nil)
        #expect(config.telegram.chatId == nil)
    }

    @Test func parsesValidConfig() throws {
        let json = """
        {
            "hud": { "enabled": false },
            "telegram": {
                "enabled": true,
                "botToken": "123:ABC",
                "chatId": "456"
            }
        }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(Config.self, from: json)
        #expect(config.hud.enabled == false)
        #expect(config.telegram.enabled == true)
        #expect(config.telegram.botToken == "123:ABC")
        #expect(config.telegram.chatId == "456")
    }

    @Test func parsesPartialConfig() throws {
        let json = """
        { "telegram": { "enabled": true, "botToken": "123:ABC", "chatId": "456" } }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(Config.self, from: json)
        #expect(config.hud.enabled == true)
        #expect(config.telegram.enabled == true)
    }

    @Test func roundTrips() throws {
        var config = Config()
        config.telegram.enabled = true
        config.telegram.botToken = "tok"
        config.telegram.chatId = "cid"
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded.telegram.botToken == "tok")
        #expect(decoded.telegram.chatId == "cid")
    }

    @Test func savesAndLoads() throws {
        let path = "/tmp/keepgoing-test-\(UUID().uuidString)/config.json"
        var config = Config()
        config.telegram.enabled = true
        config.telegram.botToken = "test-token"
        config.telegram.chatId = "test-chat"
        try config.save(to: path)

        let loaded = Config.load(from: path)
        #expect(loaded.telegram.enabled == true)
        #expect(loaded.telegram.botToken == "test-token")
        #expect(loaded.telegram.chatId == "test-chat")

        // Cleanup
        try? FileManager.default.removeItem(atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/keepgoing && swift test --filter ConfigTests
```

Expected: compile error — `Config` doesn't exist.

- [ ] **Step 3: Implement Config**

`Sources/KeepGoingCore/Config.swift`:
```swift
import Foundation

public struct Config: Codable, Sendable {
    public var hud: HUDConfig
    public var telegram: TelegramConfig

    public init() {
        self.hud = HUDConfig()
        self.telegram = TelegramConfig()
    }

    public static let defaultPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.keepgoing/config.json"
    }()

    public static func load(from path: String = Config.defaultPath) -> Config {
        guard let data = FileManager.default.contents(atPath: path) else {
            return Config()
        }
        return (try? JSONDecoder().decode(Config.self, from: data)) ?? Config()
    }

    public func save(to path: String = Config.defaultPath) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}

public struct HUDConfig: Codable, Sendable {
    public var enabled: Bool

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }
}

public struct TelegramConfig: Codable, Sendable {
    public var enabled: Bool
    public var botToken: String?
    public var chatId: String?

    public init(enabled: Bool = false, botToken: String? = nil, chatId: String? = nil) {
        self.enabled = enabled
        self.botToken = botToken
        self.chatId = chatId
    }

    public var isConfigured: Bool {
        enabled && botToken != nil && chatId != nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter ConfigTests
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KeepGoingCore/Config.swift Tests/KeepGoingTests/ConfigTests.swift
git commit -m "feat: Config model for ~/.keepgoing/config.json with HUD and Telegram settings"
```

---

### Task 2: TelegramNotifier (TDD)

**Files:**
- Create: `Sources/KeepGoingCore/TelegramNotifier.swift`
- Create: `Tests/KeepGoingTests/TelegramNotifierTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/KeepGoingTests/TelegramNotifierTests.swift`:
```swift
import Testing
import Foundation
@testable import KeepGoingCore

@Suite struct TelegramNotifierTests {
    @Test func buildsCorrectURL() {
        let url = TelegramNotifier.buildURL(botToken: "123:ABC")
        #expect(url?.absoluteString == "https://api.telegram.org/bot123:ABC/sendMessage")
    }

    @Test func buildsCorrectBody() throws {
        let body = try TelegramNotifier.buildBody(chatId: "456", projectName: "nucleus")
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        #expect(json["chat_id"] as? String == "456")
        #expect(json["text"] as? String == "Claude is waiting — nucleus")
    }

    @Test func skipsWhenNotConfigured() {
        let config = TelegramConfig(enabled: false, botToken: nil, chatId: nil)
        // Should not crash or throw
        TelegramNotifier.send(projectName: "test", config: config)
    }

    @Test func skipsWhenEnabledButMissingToken() {
        let config = TelegramConfig(enabled: true, botToken: nil, chatId: "123")
        TelegramNotifier.send(projectName: "test", config: config)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter TelegramNotifierTests
```

Expected: compile error — `TelegramNotifier` doesn't exist.

- [ ] **Step 3: Implement TelegramNotifier**

`Sources/KeepGoingCore/TelegramNotifier.swift`:
```swift
import Foundation

public enum TelegramNotifier {
    public static func send(projectName: String, config: TelegramConfig) {
        guard config.isConfigured,
              let token = config.botToken,
              let chatId = config.chatId,
              let url = buildURL(botToken: token) else {
            return
        }

        guard let body = try? buildBody(chatId: chatId, projectName: projectName) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                print("KeepGoing: Telegram send failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    public static func buildURL(botToken: String) -> URL? {
        URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage")
    }

    public static func buildBody(chatId: String, projectName: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "chat_id": chatId,
            "text": "Claude is waiting — \(projectName)",
        ])
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter TelegramNotifierTests
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KeepGoingCore/TelegramNotifier.swift Tests/KeepGoingTests/TelegramNotifierTests.swift
git commit -m "feat: TelegramNotifier sends messages via Bot API"
```

---

### Task 3: Wire Telegram into App

**Files:**
- Modify: `Sources/KeepGoing/main.swift`

- [ ] **Step 1: Update the server callback to fire Telegram**

Replace the full contents of `Sources/KeepGoing/main.swift` with:

```swift
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
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/keepgoing && swift build
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/KeepGoing/main.swift
git commit -m "feat: fire Telegram notification alongside HUD on each hook event"
```

---

### Task 4: CLI Telegram Subcommand

**Files:**
- Modify: `Sources/keepgoing-cli/CLI.swift`

- [ ] **Step 1: Add telegram subcommand**

In `CLI.swift`, add to the `switch command` block:

```swift
case "telegram":
    let subArgs = Array(args.dropFirst())
    telegram(subArgs)
```

Add to `printUsage()`:

```swift
  telegram    Manage Telegram notifications (setup, enable, disable, test)
```

Add the `telegram` function and its helpers:

```swift
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
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/keepgoing && swift build
```

- [ ] **Step 3: Test the CLI**

```bash
.build/debug/keepgoing-cli telegram status
```

Expected: `Telegram: not configured`

- [ ] **Step 4: Commit**

```bash
git add Sources/keepgoing-cli/CLI.swift
git commit -m "feat: CLI telegram subcommand with setup, enable, disable, test, status"
```

---

### Task 5: Run All Tests & Push

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
cd ~/keepgoing && swift test
```

Expected: all tests pass (19 existing + 5 Config + 4 Telegram = 28).

- [ ] **Step 2: Push**

```bash
git push origin main
```
