#!/bin/bash
# Builds a signed, notarised universal DMG. Does not publish or upload a release.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set a Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set the name of a notarytool Keychain profile}"
swift test
for ARCH in arm64 x86_64; do
  swift build -c release --arch "$ARCH" --scratch-path ".build-$ARCH"
done
APP="dist/ry Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ARM_BIN="$(swift build -c release --arch arm64 --scratch-path .build-arm64 --show-bin-path)"
INTEL_BIN="$(swift build -c release --arch x86_64 --scratch-path .build-x86_64 --show-bin-path)"
lipo -create "$ARM_BIN/RYUsageBar" "$INTEL_BIN/RYUsageBar" -output "$APP/Contents/MacOS/RYUsageBar"
cp Info.plist "$APP/Contents/Info.plist"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --strict "$APP"
ditto -c -k --keepParent "$APP" dist/notarise.zip
xcrun notarytool submit dist/notarise.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/ry Usage Bar.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname 'ry Usage Bar' -srcfolder "$STAGE" -ov -format UDZO dist/ry-usage-bar.dmg
codesign --timestamp --sign "$SIGNING_IDENTITY" dist/ry-usage-bar.dmg
xcrun notarytool submit dist/ry-usage-bar.dmg --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple dist/ry-usage-bar.dmg
xcrun stapler validate dist/ry-usage-bar.dmg
shasum -a 256 dist/ry-usage-bar.dmg > dist/SHA256SUMS
printf 'Release artefacts built; review before publishing.\n'
