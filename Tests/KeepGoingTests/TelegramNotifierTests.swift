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
        TelegramNotifier.send(projectName: "test", config: config)
    }

    @Test func skipsWhenEnabledButMissingToken() {
        let config = TelegramConfig(enabled: true, botToken: nil, chatId: "123")
        TelegramNotifier.send(projectName: "test", config: config)
    }
}
