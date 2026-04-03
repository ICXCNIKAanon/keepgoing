import Foundation

public struct NotificationPayload: Codable, Sendable {
    public let sessionID: String
    public let cwd: String
    public let hookEventName: String

    /// Folder name from cwd (e.g., "thundrrscout")
    public var folderName: String {
        let url = URL(fileURLWithPath: cwd)
        let name = url.lastPathComponent
        return name.isEmpty || name == "/" ? cwd : name
    }

    /// Session name from Claude's transcript, or folder name as fallback.
    /// This matches the Ghostty window title (e.g., "andrew").
    public var sessionName: String {
        Self.lookupSessionName(sessionID: sessionID) ?? folderName
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

    /// Look up the custom session title from Claude's transcript .jsonl file.
    private static func lookupSessionName(sessionID: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // Claude stores transcripts in project directories
        let projectsDir = "\(home)/.claude/projects"

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else {
            return nil
        }

        for projectDir in projectDirs {
            let transcriptPath = "\(projectsDir)/\(projectDir)/\(sessionID).jsonl"
            guard let data = FileManager.default.contents(atPath: transcriptPath),
                  let content = String(data: data, encoding: .utf8) else {
                continue
            }

            // Scan lines for custom-title entry
            for line in content.components(separatedBy: "\n") {
                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      json["type"] as? String == "custom-title",
                      let title = json["customTitle"] as? String else {
                    continue
                }
                return title
            }
        }
        return nil
    }
}
