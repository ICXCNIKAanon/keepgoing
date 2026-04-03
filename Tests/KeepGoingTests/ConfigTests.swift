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
