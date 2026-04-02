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
