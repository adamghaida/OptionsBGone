#!/bin/bash
# Install (or remove) a LaunchAgent so OptionsBGone starts automatically at login.
# Usage:
#   ./install-login-item.sh            install & start now
#   ./install-login-item.sh --uninstall
set -euo pipefail
cd "$(dirname "$0")"

LABEL="com.adamghaida.optionsbgone"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
APP="$(pwd)/build/OptionsBGone.app"
BIN="${APP}/Contents/MacOS/OptionsBGone"

if [[ "${1:-}" == "--uninstall" ]]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Removed login item ($PLIST)."
    exit 0
fi

if [[ ! -x "$BIN" ]]; then
    echo "App not built yet — run ./build.sh first." >&2
    exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>            <string>${LABEL}</string>
    <key>ProgramArguments</key> <array><string>${BIN}</string></array>
    <key>RunAtLoad</key>        <true/>
    <key>KeepAlive</key>        <false/>
    <key>ProcessType</key>      <string>Interactive</string>
</dict>
</plist>
PLISTEOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Installed & started login item -> $PLIST"
echo "OptionsBGone will now launch automatically at login."
