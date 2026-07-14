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
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    bindingsSection
                    editorSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 640)
        .onChange(of: store.capturedButton) { _, newValue in
            if let b = newValue { buttonText = String(b) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("OptionsBGone").font(.title2.bold())
                Text("Remap your mouse's extra buttons")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            statusPill
        }
        .padding(20)
    }

    private var statusPill: some View {
        let active = store.tapActive
        return HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(active ? "Active" : "Needs Permission")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule().fill((active ? Color.green : Color.orange).opacity(0.15))
        )
        .foregroundStyle(active ? Color.green : Color.orange)
    }

    // MARK: - Bindings list

    private var bindingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Your bindings", systemImage: "list.bullet")

            if store.bindings.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.bindings.enumerated()), id: \.element.id) { index, b in
                        if index > 0 { Divider().padding(.leading, 52) }
                        bindingRow(b)
                    }
                }
                .card()
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.badge.clock")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No bindings yet")
                    .font(.callout.weight(.medium))
                Text("Add one below — click Record, then press a button.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 22)
            Spacer()
        }
        .card()
    }

    private func bindingRow(_ b: UIBinding) -> some View {
        HStack(spacing: 12) {
            Text("\(b.button)")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            Image(systemName: actionIcon(b.spec.type))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(actionHeadline(b.spec))
                    .fontWeight(.medium)
                Text(actionSubtitle(b.spec))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button { loadIntoEditor(b) } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit")

            Button { store.delete(b.id) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Delete")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(editingId == nil ? "Add binding" : "Edit binding",
                         systemImage: editingId == nil ? "plus.circle" : "pencil.circle")

            VStack(alignment: .leading, spacing: 14) {
                fieldRow("Button") {
                    TextField("number", text: $buttonText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                    Button {
                        store.capturedButton = nil
                        store.isCapturing = true
                    } label: {
                        Label(store.isCapturing ? "Press a button…" : "Record",
                              systemImage: store.isCapturing ? "dot.radiowaves.left.and.right" : "record.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(store.isCapturing ? .red : .accentColor)
                    .disabled(store.isCapturing)
                }

                fieldRow("Action") {
                    Picker("", selection: $actionType) {
                        Text("Keystroke").tag("keystroke")
                        Text("Launch app").tag("launch")
                        Text("Shell").tag("shell")
                        Text("None").tag("none")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }

                fieldRow("Presets") {
                    Menu("Choose a preset…") {
                        Button("Mission Control") { applyPreset("shell", command: "open -a 'Mission Control'") }
                        Button("Launchpad") { applyPreset("launch", app: "Launchpad") }
                        Button("Spotlight (⌘Space)") { applyPreset("keystroke", mods: ["cmd"], key: "space") }
                        Divider()
                        Button("Back (⌘←)") { applyPreset("keystroke", mods: ["cmd"], key: "left") }
                        Button("Forward (⌘→)") { applyPreset("keystroke", mods: ["cmd"], key: "right") }
                        Button("Copy (⌘C)") { applyPreset("keystroke", mods: ["cmd"], key: "c") }
                        Button("Paste (⌘V)") { applyPreset("keystroke", mods: ["cmd"], key: "v") }
                    }
                    .frame(maxWidth: 220)
                }

                Divider()

                switch actionType {
                case "keystroke": keystrokeFields
                case "launch":    launchFields
                case "shell":     shellFields
                default:
                    Text("This button will pass through untouched.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                HStack {
                    if editingId != nil {
                        Button("Cancel", role: .cancel) { resetEditor() }
                    }
                    Spacer()
                    Button {
                        commit()
                    } label: {
                        Label(editingId == nil ? "Add binding" : "Save changes",
                              systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .card()
        }
    }

    private var keystrokeFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldRow("Key") {
                TextField("e.g. c, left, up, f11, space", text: $keyText)
                    .textFieldStyle(.roundedBorder)
            }
            fieldRow("Modifiers") {
                HStack(spacing: 6) {
                    modToggle("⌘", $modCmd)
                    modToggle("⇧", $modShift)
                    modToggle("⌥", $modOption)
                    modToggle("⌃", $modControl)
                }
                Spacer()
            }
        }
    }

    private var launchFields: some View {
        fieldRow("App") {
            TextField("name, bundle id, or path", text: $appText)
                .textFieldStyle(.roundedBorder)
            Button("Choose…") { chooseApp() }
                .buttonStyle(.bordered)
        }
    }

    private var shellFields: some View {
        fieldRow("Command") {
            TextField("shell command (run via zsh)", text: $shellText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Small building blocks

    private func sectionTitle(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func fieldRow<Content: View>(_ label: String,
                                         @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            content()
        }
    }

    private func modToggle(_ symbol: String, _ binding: SwiftUI.Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(symbol).font(.system(size: 15, weight: .medium))
        }
        .toggleStyle(.button)
        .frame(width: 40)
    }

    // MARK: - Row content helpers

    private func actionIcon(_ type: String) -> String {
        switch type {
        case "keystroke": return "keyboard"
        case "launch":    return "app.dashed"
        case "shell":     return "terminal"
        default:          return "circle.dotted"
        }
    }

    private func actionHeadline(_ spec: ActionSpec) -> String {
        if let label = spec.label, !label.isEmpty { return label }
        switch spec.type {
        case "keystroke": return "Keystroke"
        case "launch":    return "Launch app"
        case "shell":     return "Shell command"
        default:          return "None"
        }
    }

    private func actionSubtitle(_ spec: ActionSpec) -> String {
        switch spec.type {
        case "keystroke":
            let mods = (spec.modifiers ?? []).map { symbolFor($0) }.joined()
            return mods + (spec.key ?? "")
        case "launch":  return spec.app ?? ""
        case "shell":   return spec.command ?? ""
        default:        return "passes through"
        }
    }

    private func symbolFor(_ modifier: String) -> String {
        switch modifier.lowercased() {
        case "cmd", "command", "meta": return "⌘"
        case "shift":                  return "⇧"
        case "option", "opt", "alt":   return "⌥"
        case "control", "ctrl":        return "⌃"
        case "fn", "function":         return "fn"
        default:                       return modifier
        }
    }

    // MARK: - Actions

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

// MARK: - Card container

/// A subtly elevated card that reads clearly in both light and dark mode
/// (`.controlBackgroundColor` is nearly identical to the window background in
/// dark mode, so cards vanished — this uses an adaptive fill + border instead).
private struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.055) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(scheme == .dark ? 0.14 : 0.09), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0 : 0.06), radius: 4, y: 1)
    }
}

private extension View {
    func card() -> some View { modifier(CardStyle()) }
}
