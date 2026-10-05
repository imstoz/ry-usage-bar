#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PREVIEW_BUILD="$(mktemp -d)"
trap 'rm -rf "$PREVIEW_BUILD"' EXIT
swiftc -emit-library -emit-module -module-name UsageCore Sources/UsageCore/*.swift -o "$PREVIEW_BUILD/libUsageCore.dylib" -emit-module-path "$PREVIEW_BUILD/UsageCore.swiftmodule"
swiftc -I "$PREVIEW_BUILD" -L "$PREVIEW_BUILD" -lUsageCore -Xlinker -rpath -Xlinker "$PREVIEW_BUILD" Sources/UsageBar/ExecutableDiscovery.swift Sources/UsageBar/PortalLogin.swift Sources/UsageBar/Store.swift Sources/UsageBar/Providers.swift Sources/UsageBar/Theme.swift Sources/UsageBar/Panel.swift scripts/PreviewMain.swift -o "$PREVIEW_BUILD/preview"
mkdir -p assets
"$PREVIEW_BUILD/preview" "$PWD/assets/preview-light.png"
"$PREVIEW_BUILD/preview" "$PWD/assets/preview-dark.png" --dark
