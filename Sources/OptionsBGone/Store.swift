import SwiftUI

/// A binding as the UI sees it (stable identity for list rows).
struct UIBinding: Identifiable {
    let id = UUID()
    var button: Int
    var spec: ActionSpec
}

/// Shared, observable state: the bindings, capture state, and tap status.
/// All access happens on the main thread (the event tap's callback runs on the
/// main run loop), so no extra synchronization is needed.
final class Store: ObservableObject {
    @Published var bindings: [UIBinding] = []
    @Published var tapActive: Bool = false

    /// Capture ("Record") support for the settings UI.
    @Published var isCapturing: Bool = false
    @Published var capturedButton: Int? = nil

    func load() {
        let cfg = ConfigStore.load()
        bindings = cfg.bindings
            .compactMap { key, spec -> UIBinding? in
                guard let b = Int(key) else { return nil }
                return UIBinding(button: b, spec: spec)
            }
            .sorted { $0.button < $1.button }
    }

    func save() {
        var dict: [String: ActionSpec] = [:]
        for b in bindings { dict[String(b.button)] = b.spec }
        ConfigStore.save(Config(bindings: dict))
    }

    /// Look up the action for a pressed button (used by the event tap).
    func action(for button: Int) -> ActionSpec? {
        bindings.first { $0.button == button }?.spec
    }

    /// Add a new binding, update the one being edited, or overwrite an existing
    /// binding for the same button number.
    func upsert(button: Int, spec: ActionSpec, editingId: UUID?) {
        if let id = editingId, let idx = bindings.firstIndex(where: { $0.id == id }) {
            bindings[idx].button = button
            bindings[idx].spec = spec
        } else if let idx = bindings.firstIndex(where: { $0.button == button }) {
            bindings[idx].spec = spec
        } else {
            bindings.append(UIBinding(button: button, spec: spec))
        }
        bindings.sort { $0.button < $1.button }
        save()
    }

    func delete(_ id: UUID) {
        bindings.removeAll { $0.id == id }
        save()
    }
}
