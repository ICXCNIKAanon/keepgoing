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
