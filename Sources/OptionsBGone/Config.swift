import Foundation

/// One action to run when a bound button is pressed.
/// Kept deliberately flat so the JSON is easy to hand-edit.
struct ActionSpec: Codable {
    /// "keystroke" | "launch" | "shell" | "none"
    var type: String
    /// For "keystroke": a single key name, e.g. "c", "left", "f11", "space".
    var key: String? = nil
    /// For "keystroke": modifier names, any of "cmd", "shift", "option"/"alt", "control"/"ctrl", "fn".
    var modifiers: [String]? = nil
    /// For "launch": an app name ("Safari"), bundle id ("com.apple.Safari"), or full path.
    var app: String? = nil
    /// For "shell": a command line run via `/bin/zsh -c`.
    var command: String? = nil
    /// Optional human label shown in the menu.
    var label: String? = nil

    var displayName: String {
        if let label, !label.isEmpty { return label }
        switch type {
        case "keystroke":
            let mods = (modifiers ?? []).map { $0.lowercased() }.joined(separator: "+")
            let k = key ?? "?"
            return mods.isEmpty ? "Key: \(k)" : "Key: \(mods)+\(k)"
        case "launch": return "Launch: \(app ?? "?")"
        case "shell": return "Shell: \(command ?? "?")"
        default: return "None"
        }
    }
}

/// The whole config: a map of mouse-button-number -> action.
/// Button numbers are what macOS reports (see Learn mode).
struct Config: Codable {
    /// Keys are stringified button numbers ("3", "4", ...).
    var bindings: [String: ActionSpec]

    static let empty = Config(bindings: [:])

    /// A starter config with commented-style example entries the user can adapt.
    /// (JSON has no comments, so we ship real-but-inert examples on unlikely buttons.)
    static let starter = Config(bindings: [
        "3": ActionSpec(type: "none", key: nil, modifiers: nil, app: nil, command: nil,
                        label: "Back button — edit me"),
        "4": ActionSpec(type: "none", key: nil, modifiers: nil, app: nil, command: nil,
                        label: "Forward button — edit me"),
    ])
}

enum ConfigStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("OptionsBGone", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent("config.json")
    }

    static func load() -> Config {
        let url = fileURL
        guard let data = try? Data(contentsOf: url) else {
            // First run: seed the file so the user has something to edit.
            let cfg = Config.starter
            save(cfg)
            return cfg
        }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            NSLog("OptionsBGone: failed to parse config (\(error)); using empty config")
            return .empty
        }
    }

    @discardableResult
    static func save(_ config: Config) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            NSLog("OptionsBGone: failed to save config: \(error)")
            return false
        }
    }
}
