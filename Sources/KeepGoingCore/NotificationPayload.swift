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
