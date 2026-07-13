#!/bin/bash
# Build OptionsBGone and assemble a .app bundle so macOS Accessibility permission
# attaches to a stable app identity (a bare binary loses the grant on rebuild).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="OptionsBGone"
BUNDLE_ID="com.adamghaida.optionsbgone"
APP_DIR="build/${APP_NAME}.app"

# NOTE: SwiftPM's `swift build` is broken on Command-Line-Tools-only installs
# (missing SWBBuildService.framework), so we compile directly with swiftc.
echo "==> Compiling (release)…"
mkdir -p build
# Pin the deployment target: the beta toolchain otherwise stamps a bogus future
# minos (e.g. 28.0) that is HIGHER than the running OS, and LaunchServices then
# refuses to open the bundle with error -10825.
ARCH="$(uname -m)"
swiftc -O -target "${ARCH}-apple-macos14.0" \
    -o "build/${APP_NAME}" Sources/OptionsBGone/*.swift \
    -framework AppKit -framework SwiftUI

echo "==> Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "build/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>      <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key> <string>0.1</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key> <string>OptionsBGone</string>
</dict>
</plist>
PLIST

# Ad-hoc code signature so the Accessibility grant survives across launches.
echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || \
    echo "   (codesign skipped/failed — app still runs, permission may reprompt)"

echo "==> Done: ${APP_DIR}"
echo "    Launch with:  open \"${APP_DIR}\""
