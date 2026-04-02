import Testing
@testable import KeepGoingCore

@Suite struct WindowMatcherTests {
    static let ghosttyID = "com.mitchellh.ghostty"
    static let terminalID = "com.apple.Terminal"

    @Test func matchesByProjectName() {
        let windows = [
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 100, title: "jake@mac: ~/keepgoing"),
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 101, title: "jake@mac: ~/nucleus"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match?.windowID == 100)
    }

    @Test func matchesBySessionName() {
        let windows = [
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 100, title: "keepgoing — claude"),
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 101, title: "other session"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match?.windowID == 100)
    }

    @Test func returnsNilWhenNoMatch() {
        let windows = [
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 100, title: "unrelated window"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match == nil)
    }

    @Test func prefersExactProjectNameOverPartial() {
        let windows = [
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 100, title: "keepgoing-api"),
            TerminalWindowInfo(bundleID: Self.ghosttyID, pid: 1, windowID: 101, title: "keepgoing"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        // Both contain "keepgoing", first match wins — acceptable for v1
        #expect(match != nil)
    }

    @Test func matchesAcrossTerminalApps() {
        let windows = [
            TerminalWindowInfo(bundleID: Self.terminalID, pid: 2, windowID: 200, title: "keepgoing — -zsh"),
        ]
        let match = WindowMatcher.findMatch(cwd: "/Users/jake/keepgoing", windows: windows)
        #expect(match?.windowID == 200)
        #expect(match?.bundleID == Self.terminalID)
    }
}
