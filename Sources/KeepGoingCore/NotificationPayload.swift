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
