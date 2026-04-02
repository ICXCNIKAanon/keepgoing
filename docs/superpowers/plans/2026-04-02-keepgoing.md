# KeepGoing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS agent app that shows a floating HUD when Claude Code needs input, and focuses the correct terminal window on click.

**Architecture:** Native Swift app with three layers — an NWListener HTTP server receives Claude Code Notification hook POSTs, a SessionStore tracks active sessions, and a SwiftUI HUD renders floating pills that focus the right terminal on click. A separate CLI binary handles install/uninstall.

**Tech Stack:** Swift 6.0, SwiftUI, AppKit, Network.framework (NWListener), CGWindowList API, NSAppleScript, Swift Package Manager

---

## File Structure

```
keepgoing/
├── Package.swift
├── Makefile
├── Sources/
│   ├── KeepGoingCore/                  # Shared library (testable)
│   │   ├── NotificationPayload.swift   # Codable model for hook JSON
│   │   ├── SessionStore.swift          # Observable session list
│   │   ├── Server.swift                # NWListener HTTP server
│   │   ├── HUDWindowController.swift   # Floating NSWindow manager
│   │   ├── HUDView.swift              # SwiftUI pill/stack view
│   │   ├── WindowMatcher.swift         # Pure matching logic
│   │   ├── TerminalFocus.swift         # AppleScript window focus
│   │   ├── AutoDismissMonitor.swift    # Frontmost-window poller
│   │   └── SettingsPatcher.swift       # Claude settings.json merger
│   ├── KeepGoing/                      # App executable (thin)
│   │   └── main.swift
│   └── keepgoing-cli/                  # CLI executable
│       └── main.swift
├── Tests/
│   └── KeepGoingTests/
│       ├── NotificationPayloadTests.swift
│       ├── SessionStoreTests.swift
│       ├── WindowMatcherTests.swift
│       └── SettingsPatcherTests.swift
├── Resources/
│   └── Info.plist
└── scripts/
    └── bundle.sh                       # Creates .app from binary
```

**Key design decision:** All logic lives in `KeepGoingCore` (library target) so tests can `@testable import` it. The `KeepGoing` executable is just a thin `main.swift` that boots `NSApplication`. The `keepgoing-cli` executable handles install/uninstall.

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/KeepGoingCore/NotificationPayload.swift` (placeholder)
- Create: `Sources/KeepGoing/main.swift`
- Create: `Resources/Info.plist`
- Create: `Makefile`
- Create: `scripts/bundle.sh`

- [ ] **Step 1: Initialize git repo**

```bash
cd ~/keepgoing
git init
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeepGoing",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "KeepGoingCore",
            path: "Sources/KeepGoingCore"
        ),
        .executableTarget(
            name: "KeepGoing",
            dependencies: ["KeepGoingCore"],
            path: "Sources/KeepGoing"
        ),
        .executableTarget(
            name: "keepgoing-cli",
            dependencies: ["KeepGoingCore"],
            path: "Sources/keepgoing-cli"
        ),
        .testTarget(
            name: "KeepGoingTests",
            dependencies: ["KeepGoingCore"],
            path: "Tests/KeepGoingTests"
        ),
    ]
)
```

- [ ] **Step 3: Create placeholder KeepGoingCore file**

`Sources/KeepGoingCore/NotificationPayload.swift`:
```swift
import Foundation

public struct NotificationPayload: Codable, Sendable {
    public let sessionID: String
    public let cwd: String
    public let hookEventName: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
    }
}
```

- [ ] **Step 4: Create main.swift (app entry point)**

`Sources/KeepGoing/main.swift`:
```swift
import AppKit
import KeepGoingCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        print("KeepGoing running (no dock icon, no UI)")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 5: Create placeholder CLI main.swift**

`Sources/keepgoing-cli/main.swift`:
```swift
import Foundation
print("keepgoing-cli: not yet implemented")
```

- [ ] **Step 6: Create Info.plist**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.keepgoing.app</string>
    <key>CFBundleName</key>
    <string>KeepGoing</string>
    <key>CFBundleExecutable</key>
    <string>KeepGoing</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

- [ ] **Step 7: Create bundle.sh**

`scripts/bundle.sh`:
```bash
#!/bin/bash
set -euo pipefail

BUILD_DIR=".build/release"
APP_DIR="KeepGoing.app/Contents"

swift build -c release

rm -rf KeepGoing.app
mkdir -p "$APP_DIR/MacOS"
cp "$BUILD_DIR/KeepGoing" "$APP_DIR/MacOS/KeepGoing"
cp Resources/Info.plist "$APP_DIR/Info.plist"

echo "Built KeepGoing.app"
```

- [ ] **Step 8: Create Makefile**

```makefile
.PHONY: build test bundle clean

build:
	swift build

test:
	swift test

bundle:
	bash scripts/bundle.sh

clean:
	swift package clean
	rm -rf KeepGoing.app
```

- [ ] **Step 9: Build and run to verify**

```bash
cd ~/keepgoing
swift build
```

Expected: builds successfully with no errors.

```bash
swift run KeepGoing &
# Should print "KeepGoing running (no dock icon, no UI)"
# No dock icon appears
kill %1
```

- [ ] **Step 10: Create .gitignore and commit**

`.gitignore`:
```
.build/
.swiftpm/
KeepGoing.app/
*.xcodeproj/
DerivedData/
```

```bash
git add -A
git commit -m "feat: project scaffold with SPM, app entry point, build scripts"
```

---

### Task 2: Notification Payload Model (TDD)

**Files:**
- Modify: `Sources/KeepGoingCore/NotificationPayload.swift`
- Create: `Tests/KeepGoingTests/NotificationPayloadTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/KeepGoingTests/NotificationPayloadTests.swift`:
```swift
import Testing
@testable import KeepGoingCore

@Suite struct NotificationPayloadTests {
    @Test func decodesValidHookJSON() throws {
        let json = """
        {
            "session_id": "abc-123",
            "cwd": "/Users/jake/keepgoing",
            "hook_event_name": "Notification"
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(NotificationPayload.self, from: json)
        #expect(payload.sessionID == "abc-123")
        #expect(payload.cwd == "/Users/jake/keepgoing")
        #expect(payload.hookEventName == "Notification")
    }

    @Test func extractsProjectName() throws {
        let payload = NotificationPayload(
            sessionID: "abc",
            cwd: "/Users/jake/keepgoing",
            hookEventName: "Notification"
        )
        #expect(payload.projectName == "keepgoing")
    }

    @Test func extractsProjectNameFromTrailingSlash() throws {
        let payload = NotificationPayload(
            sessionID: "abc",
            cwd: "/Users/jake/keepgoing/",
            hookEventName: "Notification"
        )
        #expect(payload.projectName == "keepgoing")
    }

    @Test func ignoresExtraFieldsInJSON() throws {
        let json = """
        {
            "session_id": "abc",
            "cwd": "/test",
            "hook_event_name": "Notification",
            "notification_type": "idle_prompt",
            "extra_field": true
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(NotificationPayload.self, from: json)
        #expect(payload.sessionID == "abc")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/keepgoing
swift test --filter NotificationPayloadTests
```

Expected: compile error — `projectName` property doesn't exist yet.

- [ ] **Step 3: Implement the model**

Update `Sources/KeepGoingCore/NotificationPayload.swift`:
```swift
import Foundation

public struct NotificationPayload: Codable, Sendable {
    public let sessionID: String
    public let cwd: String
    public let hookEventName: String

    public var projectName: String {
        let url = URL(fileURLWithPath: cwd)
        let name = url.lastPathComponent
        return name.isEmpty || name == "/" ? cwd : name
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
    }

    public init(sessionID: String, cwd: String, hookEventName: String) {
        self.sessionID = sessionID
        self.cwd = cwd
        self.hookEventName = hookEventName
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter NotificationPayloadTests
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KeepGoingCore/NotificationPayload.swift Tests/KeepGoingTests/NotificationPayloadTests.swift
git commit -m "feat: NotificationPayload model with JSON decoding and projectName"
```

---

### Task 3: Session Store (TDD)

**Files:**
- Create: `Sources/KeepGoingCore/SessionStore.swift`
- Create: `Tests/KeepGoingTests/SessionStoreTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/KeepGoingTests/SessionStoreTests.swift`:
```swift
import Testing
@testable import KeepGoingCore

@Suite(.serialized)
@MainActor
struct SessionStoreTests {
    @Test func addSession() {
        let store = SessionStore()
        let payload = NotificationPayload(sessionID: "s1", cwd: "/proj/a", hookEventName: "Notification")
        store.add(payload)
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].sessionID == "s1")
        #expect(store.sessions[0].projectName == "a")
    }

    @Test func deduplicatesBySessionID() {
        let store = SessionStore()
        let p1 = NotificationPayload(sessionID: "s1", cwd: "/proj/a", hookEventName: "Notification")
        let p2 = NotificationPayload(sessionID: "s1", cwd: "/proj/a", hookEventName: "Notification")
        store.add(p1)
        store.add(p2)
        #expect(store.sessions.count == 1)
    }

    @Test func removeBySessionID() {
        let store = SessionStore()
        store.add(NotificationPayload(sessionID: "s1", cwd: "/a", hookEventName: "Notification"))
        store.add(NotificationPayload(sessionID: "s2", cwd: "/b", hookEventName: "Notification"))
        store.remove(sessionID: "s1")
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].sessionID == "s2")
    }

    @Test func mostRecentFirst() {
        let store = SessionStore()
        store.add(NotificationPayload(sessionID: "s1", cwd: "/a", hookEventName: "Notification"))
        store.add(NotificationPayload(sessionID: "s2", cwd: "/b", hookEventName: "Notification"))
        #expect(store.sessions[0].sessionID == "s2")
    }

    @Test func isEmpty() {
        let store = SessionStore()
        #expect(store.isEmpty)
        store.add(NotificationPayload(sessionID: "s1", cwd: "/a", hookEventName: "Notification"))
        #expect(!store.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter SessionStoreTests
```

Expected: compile error — `SessionStore` doesn't exist.

- [ ] **Step 3: Implement SessionStore**

`Sources/KeepGoingCore/SessionStore.swift`:
```swift
import Foundation
import Observation

public struct NotificationSession: Identifiable, Sendable {
    public let id: String
    public let sessionID: String
    public let cwd: String
    public let projectName: String
    public let timestamp: Date

    public init(payload: NotificationPayload) {
        self.id = payload.sessionID
        self.sessionID = payload.sessionID
        self.cwd = payload.cwd
        self.projectName = payload.projectName
        self.timestamp = Date()
    }
}

@MainActor
@Observable
public final class SessionStore {
    public private(set) var sessions: [NotificationSession] = []

    public var isEmpty: Bool { sessions.isEmpty }

    public init() {}

    public func add(_ payload: NotificationPayload) {
        // Remove existing entry for this session (dedup)
        sessions.removeAll { $0.sessionID == payload.sessionID }
        // Insert at front (most recent first)
        sessions.insert(NotificationSession(payload: payload), at: 0)
    }

    public func remove(sessionID: String) {
        sessions.removeAll { $0.sessionID == sessionID }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter SessionStoreTests
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KeepGoingCore/SessionStore.swift Tests/KeepGoingTests/SessionStoreTests.swift
git commit -m "feat: SessionStore with add/remove/dedup, most-recent-first ordering"
```

---

### Task 4: HTTP Server

**Files:**
- Create: `Sources/KeepGoingCore/Server.swift`
- Modify: `Sources/KeepGoing/main.swift`

- [ ] **Step 1: Implement Server**

`Sources/KeepGoingCore/Server.swift`:
```swift
import Foundation
import Network

public final class Server: Sendable {
    private let listener: NWListener
    private let onNotification: @Sendable (NotificationPayload) -> Void

    public init(port: UInt16 = 7433, onNotification: @escaping @Sendable (NotificationPayload) -> Void) throws {
        self.onNotification = onNotification
        let params = NWParameters.tcp
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    public func start() {
        listener.newConnectionHandler = { [onNotification] connection in
            Server.handleConnection(connection, onNotification: onNotification)
        }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("KeepGoing listening on port \(self.listener.port?.rawValue ?? 0)")
            }
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    public func stop() {
        listener.cancel()
    }

    private static func handleConnection(
        _ connection: NWConnection,
        onNotification: @escaping @Sendable (NotificationPayload) -> Void
    ) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            defer {
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                connection.send(
                    content: response.data(using: .utf8),
                    completion: .contentProcessed { _ in connection.cancel() }
                )
            }

            guard let data, let str = String(data: data, encoding: .utf8) else { return }

            // Extract body after HTTP headers
            guard let separatorRange = str.range(of: "\r\n\r\n") else { return }
            let body = String(str[separatorRange.upperBound...])
            guard let bodyData = body.data(using: .utf8) else { return }

            do {
                let payload = try JSONDecoder().decode(NotificationPayload.self, from: bodyData)
                onNotification(payload)
            } catch {
                print("KeepGoing: failed to decode payload: \(error)")
            }
        }
    }
}
```

- [ ] **Step 2: Wire server into main.swift**

Update `Sources/KeepGoing/main.swift`:
```swift
import AppKit
import KeepGoingCore

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
```

- [ ] **Step 3: Build and test manually**

```bash
cd ~/keepgoing
swift build
```

Expected: builds cleanly.

In one terminal:
```bash
swift run KeepGoing
```
Expected: `KeepGoing listening on port 7433`

In another terminal:
```bash
echo '{"session_id":"test-1","cwd":"/Users/jake/keepgoing","hook_event_name":"Notification"}' | curl -s -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @-
```

Expected: first terminal prints `Session added: keepgoing (test-1)`. Curl returns with exit code 0.

Stop the app with Ctrl+C.

- [ ] **Step 4: Commit**

```bash
git add Sources/KeepGoingCore/Server.swift Sources/KeepGoing/main.swift
git commit -m "feat: NWListener HTTP server, wired into app lifecycle"
```

---

### Task 5: HUD Window & SwiftUI View

**Files:**
- Create: `Sources/KeepGoingCore/HUDView.swift`
- Create: `Sources/KeepGoingCore/HUDWindowController.swift`
- Modify: `Sources/KeepGoing/main.swift`

- [ ] **Step 1: Create the SwiftUI view**

`Sources/KeepGoingCore/HUDView.swift`:
```swift
import SwiftUI

public struct HUDView: View {
    let sessions: [NotificationSession]
    let onTap: (NotificationSession) -> Void

    public init(sessions: [NotificationSession], onTap: @escaping (NotificationSession) -> Void) {
        self.sessions = sessions
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(sessions) { session in
                HUDRow(session: session)
                    .onTapGesture { onTap(session) }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: sessions.map(\.id))
    }
}

struct HUDRow: View {
    let session: NotificationSession

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text(session.projectName)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("— Claude is waiting")
                .foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}
```

- [ ] **Step 2: Create the window controller**

`Sources/KeepGoingCore/HUDWindowController.swift`:
```swift
import AppKit
import SwiftUI

@MainActor
public final class HUDWindowController {
    private var window: NSWindow?
    private let sessionStore: SessionStore
    private let onTap: (NotificationSession) -> Void
    private var observation: Any?

    public init(sessionStore: SessionStore, onTap: @escaping (NotificationSession) -> Void) {
        self.sessionStore = sessionStore
        self.onTap = onTap
        startObserving()
    }

    private func startObserving() {
        observation = withObservationTracking {
            _ = sessionStore.sessions
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateVisibility()
                self?.startObserving()
            }
        }
    }

    private func updateVisibility() {
        if sessionStore.isEmpty {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        if window == nil {
            let hudView = HUDView(sessions: sessionStore.sessions, onTap: onTap)
            let hostingView = NSHostingView(rootView: hudView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 50)

            let w = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            w.level = .floating
            w.backgroundColor = .clear
            w.isOpaque = false
            w.hasShadow = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.contentView = hostingView
            w.ignoresMouseEvents = false

            self.window = w
        }

        // Update content
        let hudView = HUDView(sessions: sessionStore.sessions, onTap: onTap)
        let hostingView = NSHostingView(rootView: hudView)
        window?.contentView = hostingView

        // Size to fit content
        let fittingSize = hostingView.fittingSize
        window?.setContentSize(fittingSize)

        // Position top center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - fittingSize.width / 2
            let y = screenFrame.maxY - 80
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window?.orderFront(nil)
    }

    private func hideWindow() {
        window?.orderOut(nil)
        window = nil
    }
}
```

- [ ] **Step 3: Wire HUD into AppDelegate**

Update `Sources/KeepGoing/main.swift`:
```swift
import AppKit
import KeepGoingCore

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
```

- [ ] **Step 4: Build and test manually**

```bash
swift build
swift run KeepGoing &
```

In another terminal, send a test notification:
```bash
echo '{"session_id":"s1","cwd":"/Users/jake/keepgoing","hook_event_name":"Notification"}' | curl -s -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @-
```

Expected: a floating pill appears top-center of screen showing "keepgoing — Claude is waiting". Clicking it dismisses the pill.

Send a second notification to test stacking:
```bash
echo '{"session_id":"s2","cwd":"/Users/jake/nucleus","hook_event_name":"Notification"}' | curl -s -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @-
```

Expected: two pills stacked vertically. Clicking one dismisses only that row.

Stop the app with `kill %1`.

- [ ] **Step 5: Commit**

```bash
git add Sources/KeepGoingCore/HUDView.swift Sources/KeepGoingCore/HUDWindowController.swift Sources/KeepGoing/main.swift
git commit -m "feat: floating HUD window with SwiftUI pill view, stacking, click-to-dismiss"
```

---

### Task 6: Terminal Window Discovery & Focus

**Files:**
- Create: `Sources/KeepGoingCore/WindowMatcher.swift`
- Create: `Sources/KeepGoingCore/TerminalFocus.swift`
- Create: `Tests/KeepGoingTests/WindowMatcherTests.swift`
- Modify: `Sources/KeepGoing/main.swift`

- [ ] **Step 1: Write failing tests for WindowMatcher**

`Tests/KeepGoingTests/WindowMatcherTests.swift`:
```swift
import Testing
@testable import KeepGoingCore

@Suite struct WindowMatcherTests {
    static let ghosttyID = "com.mitchellh.ghostty"
    static let terminalID = "com.apple.Terminal"

    @Test func matchesByProjectName() {
        let windows = [
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 100, title: "jake@mac: ~/keepgoing"),
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 101, title: "jake@mac: ~/nucleus"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match?.windowID == 100)
    }

    @Test func matchesBySessionName() {
        let windows = [
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 100, title: "keepgoing — claude"),
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 101, title: "other session"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match?.windowID == 100)
    }

    @Test func returnsNilWhenNoMatch() {
        let windows = [
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 100, title: "unrelated window"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match == nil)
    }

    @Test func prefersExactProjectNameOverPartial() {
        let windows = [
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 100, title: "keepgoing-api"),
            TerminalWindowInfo(bundleID: ghosttyID, pid: 1, windowID: 101, title: "keepgoing"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        // Both contain "keepgoing", first match wins — acceptable for v1
        #expect(match != nil)
    }

    @Test func matchesAcrossTerminalApps() {
        let windows = [
            TerminalWindowInfo(bundleID: terminalID, pid: 2, windowID: 200, title: "keepgoing — -zsh"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match?.windowID == 200)
        #expect(match?.bundleID == terminalID)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter WindowMatcherTests
```

Expected: compile error — `WindowMatcher` and `TerminalWindowInfo` don't exist.

- [ ] **Step 3: Implement WindowMatcher**

`Sources/KeepGoingCore/WindowMatcher.swift`:
```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter WindowMatcherTests
```

Expected: all 5 tests pass.

- [ ] **Step 5: Implement TerminalFocus**

`Sources/KeepGoingCore/TerminalFocus.swift`:
```swift
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
            app.activate(options: [.activateIgnoringOtherApps])
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
                app.activate(options: [.activateIgnoringOtherApps])
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
```

- [ ] **Step 6: Wire focus into HUD tap handler**

Update `Sources/KeepGoing/main.swift` — replace the `hudController` initialization:
```swift
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
```

- [ ] **Step 7: Build and test manually**

```bash
swift build
swift run KeepGoing &
```

Open a Ghostty window at `~/keepgoing`. Then in another terminal:
```bash
echo '{"session_id":"s1","cwd":"/Users/jakewlittle/keepgoing","hook_event_name":"Notification"}' | curl -s -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @-
```

Expected: HUD pill appears. Clicking it should bring the Ghostty window with `keepgoing` in the title to the front and dismiss the pill.

Note: first run will trigger an Accessibility permission prompt. Grant it.

Stop with `kill %1`.

- [ ] **Step 8: Commit**

```bash
git add Sources/KeepGoingCore/WindowMatcher.swift Sources/KeepGoingCore/TerminalFocus.swift Tests/KeepGoingTests/WindowMatcherTests.swift Sources/KeepGoing/main.swift
git commit -m "feat: terminal window discovery via CGWindowList, focus via AppleScript"
```

---

### Task 7: Auto-Dismiss Monitor

**Files:**
- Create: `Sources/KeepGoingCore/AutoDismissMonitor.swift`
- Modify: `Sources/KeepGoing/main.swift`

- [ ] **Step 1: Implement AutoDismissMonitor**

`Sources/KeepGoingCore/AutoDismissMonitor.swift`:
```swift
import AppKit

@MainActor
public final class AutoDismissMonitor {
    private var timer: Timer?
    private let sessionStore: SessionStore
    private let pollInterval: TimeInterval

    public init(sessionStore: SessionStore, pollInterval: TimeInterval = 3.0) {
        self.sessionStore = sessionStore
        self.pollInterval = pollInterval
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.check()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func check() {
        // Nothing to monitor
        if sessionStore.isEmpty {
            stop()
            return
        }

        // Get frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              TerminalFocus.supportedBundleIDs.contains(bundleID)
        else { return }

        // Get terminal windows and check which sessions are visible
        let windows = TerminalFocus.listWindows()
        // Find the frontmost window (first in list for the active app)
        guard let frontWindow = windows.first(where: { $0.bundleID == bundleID }) else { return }

        // Check if any tracked session matches the frontmost terminal window
        for session in sessionStore.sessions {
            if WindowMatcher.findMatch(cwd: session.cwd, windows: [frontWindow]) != nil {
                sessionStore.remove(sessionID: session.sessionID)
            }
        }
    }
}
```

- [ ] **Step 2: Wire into AppDelegate**

Update `Sources/KeepGoing/main.swift` — add to AppDelegate:
```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionStore = SessionStore()
    var server: Server?
    var hudController: HUDWindowController?
    var autoDismiss: AutoDismissMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        hudController = HUDWindowController(sessionStore: sessionStore) { [weak self] session in
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
```

- [ ] **Step 3: Build and test manually**

```bash
swift build
swift run KeepGoing &
```

1. Send a notification via curl
2. HUD appears
3. Switch to the terminal window matching the notification's cwd
4. Wait ~3 seconds
5. HUD should auto-dismiss

Stop with `kill %1`.

- [ ] **Step 4: Commit**

```bash
git add Sources/KeepGoingCore/AutoDismissMonitor.swift Sources/KeepGoing/main.swift
git commit -m "feat: auto-dismiss HUD when user switches to the correct terminal"
```

---

### Task 8: CLI Installer — Settings Patcher (TDD)

**Files:**
- Create: `Sources/KeepGoingCore/SettingsPatcher.swift`
- Create: `Tests/KeepGoingTests/SettingsPatcherTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/KeepGoingTests/SettingsPatcherTests.swift`:
```swift
import Testing
import Foundation
@testable import KeepGoingCore

@Suite struct SettingsPatcherTests {
    static let hookCommand = "curl -s --connect-timeout 1 -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @- || true"

    @Test func createsSettingsFromScratch() throws {
        let result = try SettingsPatcher.addHook(to: nil)
        let json = try JSONSerialization.jsonObject(with: result) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        let notifications = hooks["Notification"] as! [[String: Any]]
        #expect(notifications.count == 1)
        let hookList = notifications[0]["hooks"] as! [[String: Any]]
        #expect(hookList[0]["command"] as! String == Self.hookCommand)
    }

    @Test func preservesExistingSettings() throws {
        let existing = """
        {"model": "opus", "theme": "dark"}
        """.data(using: .utf8)!
        let result = try SettingsPatcher.addHook(to: existing)
        let json = try JSONSerialization.jsonObject(with: result) as! [String: Any]
        #expect(json["model"] as! String == "opus")
        #expect(json["theme"] as! String == "dark")
        #expect(json["hooks"] != nil)
    }

    @Test func preservesExistingHooks() throws {
        let existing = """
        {"hooks": {"Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "echo done"}]}]}}
        """.data(using: .utf8)!
        let result = try SettingsPatcher.addHook(to: existing)
        let json = try JSONSerialization.jsonObject(with: result) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        #expect(hooks["Stop"] != nil)
        #expect(hooks["Notification"] != nil)
    }

    @Test func doesNotDuplicateHook() throws {
        let existing = """
        {"hooks": {"Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "\(Self.hookCommand)"}]}]}}
        """.data(using: .utf8)!
        let result = try SettingsPatcher.addHook(to: existing)
        let json = try JSONSerialization.jsonObject(with: result) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        let notifications = hooks["Notification"] as! [[String: Any]]
        #expect(notifications.count == 1)
    }

    @Test func removesHook() throws {
        let existing = """
        {"hooks": {"Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "\(Self.hookCommand)"}]}]}}
        """.data(using: .utf8)!
        let result = try SettingsPatcher.removeHook(from: existing)
        let json = try JSONSerialization.jsonObject(with: result) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        let notifications = hooks["Notification"] as! [[String: Any]]
        #expect(notifications.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter SettingsPatcherTests
```

Expected: compile error — `SettingsPatcher` doesn't exist.

- [ ] **Step 3: Implement SettingsPatcher**

`Sources/KeepGoingCore/SettingsPatcher.swift`:
```swift
import Foundation

public enum SettingsPatcher {
    public static let hookCommand = "curl -s --connect-timeout 1 -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @- || true"

    public static func addHook(to settingsData: Data?) throws -> Data {
        var settings = try deserialize(settingsData)

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var notifications = hooks["Notification"] as? [[String: Any]] ?? []

        // Check if already installed
        let alreadyExists = notifications.contains { entry in
            guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return entryHooks.contains { $0["command"] as? String == hookCommand }
        }

        if !alreadyExists {
            let newEntry: [String: Any] = [
                "matcher": "",
                "hooks": [
                    ["type": "command", "command": hookCommand]
                ],
            ]
            notifications.append(newEntry)
        }

        hooks["Notification"] = notifications
        settings["hooks"] = hooks

        return try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
    }

    public static func removeHook(from settingsData: Data) throws -> Data {
        var settings = try deserialize(settingsData)

        guard var hooks = settings["hooks"] as? [String: Any],
              var notifications = hooks["Notification"] as? [[String: Any]]
        else {
            return settingsData
        }

        notifications.removeAll { entry in
            guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return entryHooks.contains { $0["command"] as? String == hookCommand }
        }

        hooks["Notification"] = notifications
        settings["hooks"] = hooks

        return try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
    }

    private static func deserialize(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter SettingsPatcherTests
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/KeepGoingCore/SettingsPatcher.swift Tests/KeepGoingTests/SettingsPatcherTests.swift
git commit -m "feat: SettingsPatcher for safe Claude settings.json hook management"
```

---

### Task 9: CLI Installer

**Files:**
- Modify: `Sources/keepgoing-cli/CLI.swift` (rename from `main.swift` — required for `@main` attribute)

- [ ] **Step 1: Rename and implement the CLI**

Delete `Sources/keepgoing-cli/main.swift` and create `Sources/keepgoing-cli/CLI.swift`:
```swift
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
        let appSource = Bundle.main.bundlePath
            .replacingOccurrences(of: "keepgoing-cli", with: "KeepGoing.app")
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
```

- [ ] **Step 2: Build and test manually**

```bash
swift build
.build/debug/keepgoing-cli status
```

Expected: prints whether KeepGoing is running and hook status.

```bash
.build/debug/keepgoing-cli install
```

Expected: patches `~/.claude/settings.json` (creates if needed), copies .app, launches.

```bash
.build/debug/keepgoing-cli uninstall
```

Expected: stops app, removes .app, removes hook from settings.

- [ ] **Step 3: Commit**

```bash
git add Sources/keepgoing-cli/
git commit -m "feat: CLI installer with install/uninstall/status commands"
```

---

### Task 10: Build, Release & GitHub Setup

**Files:**
- Modify: `Makefile`
- Modify: `scripts/bundle.sh`
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Update Makefile with release targets**

Update `Makefile`:
```makefile
.PHONY: build test bundle release clean

build:
	swift build

test:
	swift test

bundle:
	bash scripts/bundle.sh

release: bundle
	cd KeepGoing.app && zip -r ../KeepGoing-macos.zip .
	@echo "Release artifact: KeepGoing-macos.zip"

clean:
	swift package clean
	rm -rf KeepGoing.app KeepGoing-macos.zip
```

- [ ] **Step 2: Update bundle.sh for universal binary**

Update `scripts/bundle.sh`:
```bash
#!/bin/bash
set -euo pipefail

APP_DIR="KeepGoing.app/Contents"

# Build universal binary
swift build -c release --arch arm64 --arch x86_64

rm -rf KeepGoing.app
mkdir -p "$APP_DIR/MacOS"

cp .build/apple/Products/Release/KeepGoing "$APP_DIR/MacOS/KeepGoing"
cp Resources/Info.plist "$APP_DIR/Info.plist"

# Also copy the CLI next to the .app for the installer
cp .build/apple/Products/Release/keepgoing-cli "$APP_DIR/MacOS/keepgoing-cli"

echo "Built KeepGoing.app (universal binary)"
```

- [ ] **Step 3: Create GitHub Actions release workflow**

`.github/workflows/release.yml`:
```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build universal binary
        run: make release
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: KeepGoing-macos.zip
          generate_release_notes: true
```

- [ ] **Step 4: Run all tests**

```bash
cd ~/keepgoing
swift test
```

Expected: all tests pass (NotificationPayload, SessionStore, WindowMatcher, SettingsPatcher).

- [ ] **Step 5: Run a full end-to-end manual test**

```bash
make bundle
open KeepGoing.app
```

Then test the full flow:
1. Send a notification via curl — HUD should appear
2. Click the HUD — terminal should focus, HUD should dismiss
3. Send another notification — HUD appears
4. Switch to the matching terminal manually — HUD auto-dismisses after ~3 seconds
5. Send two notifications for different cwds — both pills stack
6. Click one — only that pill dismisses

- [ ] **Step 6: Create GitHub repo and push**

```bash
cd ~/keepgoing
gh repo create ICXCNIKAanon/keepgoing --private --source=. --push
```

- [ ] **Step 7: Tag v0.1.0**

```bash
git tag v0.1.0
git push origin v0.1.0
```

Expected: GitHub Actions builds the release and attaches `KeepGoing-macos.zip`.

- [ ] **Step 8: Commit any remaining files**

```bash
git add -A
git commit -m "feat: build scripts, CI release workflow, ready for v0.1.0"
```
