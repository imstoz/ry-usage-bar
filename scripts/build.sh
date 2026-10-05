#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ROOT="${RY_BUILD_ROOT:-.build}"
swift build -c release --disable-sandbox --cache-path "$BUILD_ROOT/cache" --scratch-path "$BUILD_ROOT"
BIN="$(swift build -c release --disable-sandbox --cache-path "$BUILD_ROOT/cache" --scratch-path "$BUILD_ROOT" --show-bin-path)"
APP="dist/ry Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/RYUsageBar" "$APP/Contents/MacOS/RYUsageBar"
cp Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
printf 'Built %s (local development signature)\n' "$APP"
