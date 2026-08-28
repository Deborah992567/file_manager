#!/usr/bin/env bash
# Builds, boots a simulator, installs and launches the app, then confirms the
# process stays alive (no immediate crash). Pass a device id via DEVICE.
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-20FB3DD0-32D3-4A62-AABC-E6D48D0CADEE}"

echo "==> Building Debug (simulator)"
xcodebuild \
  -project FileManagerApp.xcodeproj \
  -scheme FileManager \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  build CODE_SIGNING_ALLOWED=NO >/dev/null

BP=$(xcodebuild \
  -project FileManagerApp.xcodeproj \
  -scheme FileManager \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -showBuildSettings build CODE_SIGNING_ALLOWED=NO 2>/dev/null \
  | grep -m1 " BUILT_PRODUCTS_DIR = " | sed 's/.*= //')

BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$BP/FileManager.app/Info.plist")

echo "==> Booting simulator"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

echo "==> Installing $BUNDLE"
xcrun simctl install "$DEVICE" "$BP/FileManager.app"

echo "==> Launching"
xcrun simctl launch "$DEVICE" "$BUNDLE"
sleep 6

if xcrun simctl spawn "$DEVICE" launchctl list 2>/dev/null | grep -q "com.novafiles.app"; then
  echo "==> OK: app is running"
else
  echo "==> ERROR: app exited (crash suspected)"
  exit 1
fi

xcrun simctl io "$DEVICE" screenshot /tmp/nova_smoke.png >/dev/null
echo "==> Screenshot: /tmp/nova_smoke.png"