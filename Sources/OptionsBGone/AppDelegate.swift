import AppKit
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tap = EventTap()
    private let store = Store()
    private var settingsWC: NSWindowController?
    private var permissionTimer: Timer?

    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()
        buildStatusItem()
        buildMenu()

        tap.onButton = { [weak self] button, down in
            guard let self else { return false }
            guard down else { return false }

            // Capture mode: report the pressed button to the UI, swallow it so it
            // doesn't also trigger its default action while recording.
            if self.store.isCapturing {
                Log.write("button \(button) down — captured for UI")
                DispatchQueue.main.async {
                    self.store.capturedButton = button
                    self.store.isCapturing = false
                }
                return true
            }

            if let spec = self.store.action(for: button), spec.type != "none" {
                Log.write("button \(button) down — MATCH type=\(spec.type) key=\(spec.key ?? "-") mods=\(spec.modifiers ?? []); swallowing + running")
                DispatchQueue.main.async { ActionRunner.run(spec) }
                return true
            }
            Log.write("button \(button) down — no binding (pass through)")
            return false
        }

        startTapOrRequestPermission()

        // First-run convenience: open the window so the user sees the UI.
        if store.bindings.isEmpty { openSettings() }
    }

    // MARK: - Permission / tap lifecycle

    private func startTapOrRequestPermission() {
        if tap.start() {
            store.tapActive = true
            updateStatusLine()
            return
        }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
        store.tapActive = false
        updateStatusLine()

        if permissionTimer == nil {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                if self.tap.start() {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    self.store.tapActive = true
                    self.updateStatusLine()
                }
            }
        }
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "OptionsBGone") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "MX"
            }
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        updateStatusLine()

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OptionsBGone", action: #selector(quit), keyEquivalent: "q").target = self

        statusItem.menu = menu
    }

    private func updateStatusLine() {
        statusLine.title = store.tapActive
            ? "OptionsBGone — active"
            : "OptionsBGone — needs Accessibility permission"
    }

    @objc private func openSettings() {
        if settingsWC == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: hosting)
            window.title = "OptionsBGone"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            settingsWC = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWC?.showWindow(nil)
        settingsWC?.window?.center()
        settingsWC?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func reloadConfig() {
        store.load()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
