import AppKit
import Carbon.HIToolbox

/// Runs the action attached to a button.
enum ActionRunner {
    static func run(_ spec: ActionSpec) {
        switch spec.type {
        case "keystroke": runKeystroke(spec)
        case "launch":    runLaunch(spec)
        case "shell":     runShell(spec)
        case "none":      break
        default:
            NSLog("OptionsBGone: unknown action type '\(spec.type)'")
        }
    }

    // MARK: - Keystroke

    private static func runKeystroke(_ spec: ActionSpec) {
        guard let key = spec.key, let code = keyCode(for: key) else {
            NSLog("OptionsBGone: keystroke has no/unknown key: \(spec.key ?? "nil")")
            return
        }
        let mods = resolveModifiers(spec.modifiers ?? [])
        let src = CGEventSource(stateID: .combinedSessionState)
        Log.write("keystroke: posting key='\(key)' code=\(code) mods=\(mods.map { $0.keyCode })")

        // System hotkeys (Mission Control's Ctrl+Up, Spaces, etc.) are handled by
        // the Dock/WindowServer, which inspects the *real* modifier-key state — not
        // just the flag on a synthetic key event. So we press each modifier as an
        // actual key event first, build up the flags, then send the key, then
        // release everything in reverse. This makes synthesized combos behave like
        // physical ones.
        var flags = CGEventFlags()

        for mod in mods {
            flags.insert(mod.flag)
            let e = CGEvent(keyboardEventSource: src, virtualKey: mod.keyCode, keyDown: true)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }

        let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)

        for mod in mods.reversed() {
            flags.remove(mod.flag)
            let e = CGEvent(keyboardEventSource: src, virtualKey: mod.keyCode, keyDown: false)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
    }

    private struct Modifier { let flag: CGEventFlags; let keyCode: CGKeyCode }

    private static func resolveModifiers(_ mods: [String]) -> [Modifier] {
        mods.compactMap { name in
            switch name.lowercased() {
            case "cmd", "command", "meta": return Modifier(flag: .maskCommand,   keyCode: CGKeyCode(kVK_Command))
            case "shift":                  return Modifier(flag: .maskShift,     keyCode: CGKeyCode(kVK_Shift))
            case "option", "opt", "alt":   return Modifier(flag: .maskAlternate, keyCode: CGKeyCode(kVK_Option))
            case "control", "ctrl":        return Modifier(flag: .maskControl,   keyCode: CGKeyCode(kVK_Control))
            case "fn", "function":         return Modifier(flag: .maskSecondaryFn, keyCode: CGKeyCode(kVK_Function))
            default:
                NSLog("OptionsBGone: unknown modifier '\(name)'")
                return nil
            }
        }
    }

    // MARK: - Launch

    private static func runLaunch(_ spec: ActionSpec) {
        guard let app = spec.app, !app.isEmpty else { return }
        let ws = NSWorkspace.shared
        // Try as a filesystem path first.
        if app.hasPrefix("/") {
            let url = URL(fileURLWithPath: app)
            ws.openApplication(at: url, configuration: .init())
            return
        }
        // Try as a bundle identifier.
        if let url = ws.urlForApplication(withBundleIdentifier: app) {
            ws.openApplication(at: url, configuration: .init())
            return
        }
        // Fall back to `open -a "Name"`.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", app]
        try? p.run()
    }

    // MARK: - Shell

    private static func runShell(_ spec: ActionSpec) {
        guard let command = spec.command, !command.isEmpty else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-c", command]
        do { try p.run() } catch { NSLog("OptionsBGone: shell run failed: \(error)") }
    }

    // MARK: - Key name -> virtual keycode

    private static func keyCode(for name: String) -> CGKeyCode? {
        let n = name.lowercased()
        if let c = keyMap[n] { return c }
        // Single letters/digits fall through the map already; nothing else to do.
        return nil
    }

    private static let keyMap: [String: CGKeyCode] = [
        "a": CGKeyCode(kVK_ANSI_A), "b": CGKeyCode(kVK_ANSI_B), "c": CGKeyCode(kVK_ANSI_C),
        "d": CGKeyCode(kVK_ANSI_D), "e": CGKeyCode(kVK_ANSI_E), "f": CGKeyCode(kVK_ANSI_F),
        "g": CGKeyCode(kVK_ANSI_G), "h": CGKeyCode(kVK_ANSI_H), "i": CGKeyCode(kVK_ANSI_I),
        "j": CGKeyCode(kVK_ANSI_J), "k": CGKeyCode(kVK_ANSI_K), "l": CGKeyCode(kVK_ANSI_L),
        "m": CGKeyCode(kVK_ANSI_M), "n": CGKeyCode(kVK_ANSI_N), "o": CGKeyCode(kVK_ANSI_O),
        "p": CGKeyCode(kVK_ANSI_P), "q": CGKeyCode(kVK_ANSI_Q), "r": CGKeyCode(kVK_ANSI_R),
        "s": CGKeyCode(kVK_ANSI_S), "t": CGKeyCode(kVK_ANSI_T), "u": CGKeyCode(kVK_ANSI_U),
        "v": CGKeyCode(kVK_ANSI_V), "w": CGKeyCode(kVK_ANSI_W), "x": CGKeyCode(kVK_ANSI_X),
        "y": CGKeyCode(kVK_ANSI_Y), "z": CGKeyCode(kVK_ANSI_Z),
        "0": CGKeyCode(kVK_ANSI_0), "1": CGKeyCode(kVK_ANSI_1), "2": CGKeyCode(kVK_ANSI_2),
        "3": CGKeyCode(kVK_ANSI_3), "4": CGKeyCode(kVK_ANSI_4), "5": CGKeyCode(kVK_ANSI_5),
        "6": CGKeyCode(kVK_ANSI_6), "7": CGKeyCode(kVK_ANSI_7), "8": CGKeyCode(kVK_ANSI_8),
        "9": CGKeyCode(kVK_ANSI_9),
        "space": CGKeyCode(kVK_Space), "return": CGKeyCode(kVK_Return), "enter": CGKeyCode(kVK_Return),
        "tab": CGKeyCode(kVK_Tab), "escape": CGKeyCode(kVK_Escape), "esc": CGKeyCode(kVK_Escape),
        "delete": CGKeyCode(kVK_Delete), "backspace": CGKeyCode(kVK_Delete),
        "forwarddelete": CGKeyCode(kVK_ForwardDelete),
        "left": CGKeyCode(kVK_LeftArrow), "right": CGKeyCode(kVK_RightArrow),
        "up": CGKeyCode(kVK_UpArrow), "down": CGKeyCode(kVK_DownArrow),
        "home": CGKeyCode(kVK_Home), "end": CGKeyCode(kVK_End),
        "pageup": CGKeyCode(kVK_PageUp), "pagedown": CGKeyCode(kVK_PageDown),
        "f1": CGKeyCode(kVK_F1), "f2": CGKeyCode(kVK_F2), "f3": CGKeyCode(kVK_F3),
        "f4": CGKeyCode(kVK_F4), "f5": CGKeyCode(kVK_F5), "f6": CGKeyCode(kVK_F6),
        "f7": CGKeyCode(kVK_F7), "f8": CGKeyCode(kVK_F8), "f9": CGKeyCode(kVK_F9),
        "f10": CGKeyCode(kVK_F10), "f11": CGKeyCode(kVK_F11), "f12": CGKeyCode(kVK_F12),
        "-": CGKeyCode(kVK_ANSI_Minus), "=": CGKeyCode(kVK_ANSI_Equal),
        "[": CGKeyCode(kVK_ANSI_LeftBracket), "]": CGKeyCode(kVK_ANSI_RightBracket),
        ";": CGKeyCode(kVK_ANSI_Semicolon), "'": CGKeyCode(kVK_ANSI_Quote),
        ",": CGKeyCode(kVK_ANSI_Comma), ".": CGKeyCode(kVK_ANSI_Period),
        "/": CGKeyCode(kVK_ANSI_Slash), "\\": CGKeyCode(kVK_ANSI_Backslash),
        "`": CGKeyCode(kVK_ANSI_Grave),
    ]
}
