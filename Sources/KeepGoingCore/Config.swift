import Foundation

public struct Config: Codable, Sendable {
    public var hud: HUDConfig
    public var telegram: TelegramConfig

    public init() {
        self.hud = HUDConfig()
        self.telegram = TelegramConfig()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hud = (try? container.decode(HUDConfig.self, forKey: .hud)) ?? HUDConfig()
        self.telegram = (try? container.decode(TelegramConfig.self, forKey: .telegram)) ?? TelegramConfig()
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
