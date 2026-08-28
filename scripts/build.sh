#!/usr/bin/env bash
# Builds the FileManager scheme. Run from anywhere; configuration is the
# first argument (Debug/Release), destination can be overridden via DESTINATION.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-Debug}"
DEST="${DESTINATION:-generic/platform=iOS Simulator}"

xcodebuild \
  -project FileManagerApp.xcodeproj \
  -scheme FileManager \
  -configuration "$CONFIG" \
  -destination "$DEST" \
  build \
  CODE_SIGNING_ALLOWED=NO