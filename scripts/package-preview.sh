#!/bin/bash
# Produces a universal development preview. For public signed releases use release.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD_ROOT="${RY_BUILD_ROOT:-.build-preview}"
for ARCH in arm64 x86_64; do
  swift build -c release --arch "$ARCH" --disable-sandbox --cache-path "$BUILD_ROOT/cache" --scratch-path "$BUILD_ROOT/$ARCH"
done
APP="dist/ry Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ARM_BIN="$(swift build -c release --arch arm64 --scratch-path "$BUILD_ROOT/arm64" --show-bin-path)"
INTEL_BIN="$(swift build -c release --arch x86_64 --scratch-path "$BUILD_ROOT/x86_64" --show-bin-path)"
lipo -create "$ARM_BIN/RYUsageBar" "$INTEL_BIN/RYUsageBar" -output "$APP/Contents/MacOS/RYUsageBar"
cp Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
ditto -c -k --keepParent "$APP" "dist/ry-usage-bar-preview-$VERSION-universal.zip"
./scripts/package-dmg.sh "$APP" "dist/ry-usage-bar-preview-$VERSION-universal.dmg"
(cd dist && shasum -a 256 "ry-usage-bar-preview-$VERSION-universal.zip" "ry-usage-bar-preview-$VERSION-universal.dmg" > SHA256SUMS)
printf 'Universal preview packaged. Not Developer ID signed or notarised.\n'
