import Foundation
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
