import Foundation

public struct TelegramNotifier: Sendable {
    public static func buildURL(botToken: String) -> URL? {
        URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage")
    }

    public static func buildBody(chatId: String, projectName: String) throws -> Data {
        let payload: [String: Any] = [
            "chat_id": chatId,
            "text": "Claude is waiting — \(projectName)"
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    public static func send(projectName: String, config: TelegramConfig) {
        guard config.isConfigured,
              let botToken = config.botToken,
              let chatId = config.chatId else { return }
        guard let url = buildURL(botToken: botToken),
              let body = try? buildBody(chatId: chatId, projectName: projectName) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }
}
