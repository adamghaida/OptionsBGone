import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: Store

    // Editor state.
    @State private var buttonText = ""
    @State private var actionType = "keystroke"
    @State private var keyText = ""
    @State private var modCmd = false
    @State private var modShift = false
    @State private var modOption = false
    @State private var modControl = false
    @State private var appText = ""
    @State private var shellText = ""
    @State private var editingId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            bindingsList
            Divider()
            editor
        }
        .padding(18)
        .frame(minWidth: 480, minHeight: 540, alignment: .top)
        .onChange(of: store.capturedButton) { _, newValue in
            if let b = newValue { buttonText = String(b) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "computermouse.fill").font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("OptionsBGone").font(.headline)
                Text(store.tapActive ? "Active" : "Needs Accessibility permission")
                    .font(.caption)
                    .foregroundColor(store.tapActive ? .green : .orange)
            }
            Spacer()
        }
    }

    // MARK: Existing bindings

    private var bindingsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bindings").font(.subheadline).bold()
            if store.bindings.isEmpty {
                Text("No bindings yet — add one below.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(store.bindings) { b in
                    HStack {
                        Text("Button \(b.button)")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 90, alignment: .leading)
                        Text(b.spec.displayName).foregroundColor(.secondary)
                        Spacer()
                        Button("Edit") { loadIntoEditor(b) }
                            .buttonStyle(.borderless)
                        Button { store.delete(b.id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    // MARK: Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(editingId == nil ? "Add binding" : "Edit binding")
                .font(.subheadline).bold()

            HStack {
                Text("Button").frame(width: 72, alignment: .leading)
                TextField("number", text: $buttonText).frame(width: 70)
                Button(store.isCapturing ? "Press a button…" : "Record") {
                    store.capturedButton = nil
                    store.isCapturing = true
                }
                .disabled(store.isCapturing)
                Text("(click Record, then press the mouse button)")
                    .font(.caption).foregroundColor(.secondary)
            }

            HStack {
                Text("Action").frame(width: 72, alignment: .leading)
                Picker("", selection: $actionType) {
                    Text("Keystroke").tag("keystroke")
                    Text("Launch app").tag("launch")
                    Text("Shell").tag("shell")
                    Text("None").tag("none")
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            HStack {
                Text("Presets").frame(width: 72, alignment: .leading)
                Menu("Choose a preset…") {
                    Button("Mission Control") { applyPreset("keystroke", mods: ["control"], key: "up") }
                    Button("App Windows (Exposé)") { applyPreset("keystroke", mods: ["control"], key: "down") }
                    Button("Launchpad") { applyPreset("launch", app: "Launchpad") }
                    Button("Spotlight (⌘Space)") { applyPreset("keystroke", mods: ["cmd"], key: "space") }
                    Divider()
                    Button("Back (⌘←)") { applyPreset("keystroke", mods: ["cmd"], key: "left") }
                    Button("Forward (⌘→)") { applyPreset("keystroke", mods: ["cmd"], key: "right") }
                    Button("Copy (⌘C)") { applyPreset("keystroke", mods: ["cmd"], key: "c") }
                    Button("Paste (⌘V)") { applyPreset("keystroke", mods: ["cmd"], key: "v") }
                }
                .frame(width: 200)
            }

            switch actionType {
            case "keystroke": keystrokeFields
            case "launch":    launchFields
            case "shell":     shellFields
            default:          EmptyView()
            }

            HStack {
                Spacer()
                if editingId != nil {
                    Button("Cancel") { resetEditor() }
                }
                Button(editingId == nil ? "Add binding" : "Update") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(Int(buttonText) == nil)
            }
        }
    }

    private var keystrokeFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Key").frame(width: 72, alignment: .leading)
                TextField("e.g. c, left, up, f11, space", text: $keyText)
            }
            HStack {
                Spacer().frame(width: 72)
                Toggle("⌘", isOn: $modCmd)
                Toggle("⇧", isOn: $modShift)
                Toggle("⌥", isOn: $modOption)
                Toggle("⌃", isOn: $modControl)
            }
            .toggleStyle(.button)
        }
    }

    private var launchFields: some View {
        HStack {
            Text("App").frame(width: 72, alignment: .leading)
            TextField("name, bundle id, or path", text: $appText)
            Button("Choose…") { chooseApp() }
        }
    }

    private var shellFields: some View {
        HStack {
            Text("Command").frame(width: 72, alignment: .leading)
            TextField("shell command (run via zsh)", text: $shellText)
        }
    }

    // MARK: Actions

    private func applyPreset(_ type: String, mods: [String] = [], key: String = "",
                             app: String = "", command: String = "") {
        actionType = type
        modCmd = mods.contains("cmd")
        modShift = mods.contains("shift")
        modOption = mods.contains("option")
        modControl = mods.contains("control")
        keyText = key
        appText = app
        shellText = command
    }

    private func currentModifiers() -> [String] {
        var m: [String] = []
        if modCmd { m.append("cmd") }
        if modShift { m.append("shift") }
        if modOption { m.append("option") }
        if modControl { m.append("control") }
        return m
    }

    private func commit() {
        guard let button = Int(buttonText) else { return }
        var spec = ActionSpec(type: actionType)
        switch actionType {
        case "keystroke":
            spec.key = keyText
            spec.modifiers = currentModifiers()
        case "launch":
            spec.app = appText
        case "shell":
            spec.command = shellText
        default:
            break
        }
        store.upsert(button: button, spec: spec, editingId: editingId)
        resetEditor()
    }

    private func loadIntoEditor(_ b: UIBinding) {
        editingId = b.id
        buttonText = String(b.button)
        actionType = b.spec.type
        keyText = b.spec.key ?? ""
        let mods = (b.spec.modifiers ?? []).map { $0.lowercased() }
        modCmd = mods.contains { ["cmd", "command", "meta"].contains($0) }
        modShift = mods.contains("shift")
        modOption = mods.contains { ["option", "opt", "alt"].contains($0) }
        modControl = mods.contains { ["control", "ctrl"].contains($0) }
        appText = b.spec.app ?? ""
        shellText = b.spec.command ?? ""
    }

    private func resetEditor() {
        editingId = nil
        buttonText = ""
        actionType = "keystroke"
        keyText = ""
        modCmd = false; modShift = false; modOption = false; modControl = false
        appText = ""; shellText = ""
        store.isCapturing = false
        store.capturedButton = nil
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appText = url.path
        }
    }
}
