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
