# OptionsBGone

A tiny macOS menu-bar app that remaps the extra buttons on a Logitech mouse
(built for the **MX Master 4** over Bluetooth) to keystrokes, app launches, or
shell commands — **without running Logi Options**.

It works by installing a system-wide `CGEventTap` on mouse-button events, so it
doesn't talk to the device directly and doesn't care whether the mouse is on
Bluetooth or the Bolt receiver. Bound buttons are *swallowed* so the OS default
(Back/Forward/etc.) doesn't also fire.

No Dock icon — it lives in the menu bar.

## Features

- **Point-and-click GUI** to add/edit/remove bindings (no JSON required).
- **Record** a button live: click Record, press the mouse button, it captures
  the number for you.
- Actions: **Keystroke** (with ⌘⇧⌥⌃ modifiers), **Launch app**, or **Shell
  command**.
- One-click **presets**: Mission Control, App Exposé, Launchpad, Spotlight,
  Back/Forward, Copy/Paste.
- Optional **launch at login**.

## Build & run

```sh
./build.sh
open build/OptionsBGone.app
```

Requires the Swift toolchain from Command Line Tools. `build.sh` compiles with
`swiftc` directly (SwiftPM is broken on CLT-only installs) and assembles a signed
`OptionsBGone.app`.

## First run

1. Launch the app — a mouse icon appears in the menu bar.
2. macOS prompts for **Accessibility** (System Settings → Privacy & Security →
   Accessibility). Enable **OptionsBGone**. The header in Settings flips to green
   **“Active”** within a second — no restart needed.
3. Menu-bar icon → **Settings…** to add bindings:
   - Click **Record**, press the mouse button you want → its number fills in.
   - Pick an action (or a preset) and hit **Add binding**.

Changes apply live and are saved to
`~/Library/Application Support/OptionsBGone/config.json`.

## Launch at login

```sh
./install-login-item.sh            # install + start now
./install-login-item.sh --uninstall
```

This installs a LaunchAgent that starts the app at login. (It points at the app
in this repo's `build/` folder, so keep the folder where it is — or move the
`.app` to `/Applications` and re-run the script from there.)

## Config format

Keyed by button number (from Record). Example:

```json
{
  "bindings": {
    "3": { "type": "keystroke", "modifiers": ["cmd"], "key": "left", "label": "Back" },
    "4": { "type": "keystroke", "modifiers": ["cmd"], "key": "right", "label": "Forward" },
    "5": { "type": "keystroke", "modifiers": ["cmd"], "key": "space", "label": "Spotlight" },
    "6": { "type": "shell", "command": "open -a 'Mission Control'", "label": "Mission Control" }
  }
}
```

| type        | fields                        | notes |
|-------------|-------------------------------|-------|
| `keystroke` | `key`, `modifiers` (optional) | `key`: a letter/digit, `left/right/up/down`, `f1`–`f12`, `space`, `tab`, `escape`, `home`, `pageup`, … `modifiers`: `cmd`, `shift`, `option`, `control`, `fn`. |
| `launch`    | `app`                         | App name, bundle id, or full path. |
| `shell`     | `command`                     | Run via `/bin/zsh -c`. |
| `none`      | —                             | Passthrough; leaves the button's default behavior alone. |

### Why Mission Control uses a shell command

Mission Control's default `Ctrl+Up` is handled deep in the Dock/WindowServer,
which validates *real* hardware modifier state and ignores **synthesized** key
events — so a keystroke binding silently does nothing. Launching
`Mission Control.app` (`open -a 'Mission Control'`) sidesteps that entirely.
Ordinary app shortcuts like `⌘Space` work fine as keystrokes.

## Notes / limits

- Rebinds buttons macOS already reports as **distinct** events. Two physical
  buttons that emit the *same* number can't be told apart without the HID++
  layer (a bigger project — full device control like Solaar/LogiOps).
- The app is **ad-hoc signed**, so each `./build.sh` changes its signature and
  macOS drops the Accessibility grant. After rebuilding, re-check
  **OptionsBGone** in Accessibility (or run
  `tccutil reset Accessibility com.adamghaida.optionsbgone` and re-add it).

## Possible next steps

- HID++ 2.0 control: divert the gesture button, set DPI, read battery, remap
  on-device.
- A stable local signing identity so the Accessibility grant survives rebuilds.
