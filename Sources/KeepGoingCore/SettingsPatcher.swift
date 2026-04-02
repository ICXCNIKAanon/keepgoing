import Foundation

public enum SettingsPatcher {
    public static let hookCommand = "curl -s --connect-timeout 1 -X POST http://localhost:7433/notify -H 'Content-Type: application/json' -d @- || true"

    public static func addHook(to settingsData: Data?) throws -> Data {
        var settings = try deserialize(settingsData)

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var notifications = hooks["Notification"] as? [[String: Any]] ?? []

        // Check if already installed
        let alreadyExists = notifications.contains { entry in
            guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return entryHooks.contains { $0["command"] as? String == hookCommand }
        }

        if !alreadyExists {
            let newEntry: [String: Any] = [
                "matcher": "",
                "hooks": [
                    ["type": "command", "command": hookCommand]
                ],
            ]
            notifications.append(newEntry)
        }

        hooks["Notification"] = notifications
        settings["hooks"] = hooks

        return try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
    }

    public static func removeHook(from settingsData: Data) throws -> Data {
        var settings = try deserialize(settingsData)

        guard var hooks = settings["hooks"] as? [String: Any],
              var notifications = hooks["Notification"] as? [[String: Any]]
        else {
            return settingsData
        }

        notifications.removeAll { entry in
            guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return entryHooks.contains { $0["command"] as? String == hookCommand }
        }

        hooks["Notification"] = notifications
        settings["hooks"] = hooks

        return try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
    }

    private static func deserialize(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
