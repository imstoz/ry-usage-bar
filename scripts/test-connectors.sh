#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD="$(mktemp -d)"
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -emit-library -emit-module -module-name UsageCore Sources/UsageCore/*.swift -o "$TEST_BUILD/libUsageCore.dylib" -emit-module-path "$TEST_BUILD/UsageCore.swiftmodule"
swiftc -I "$TEST_BUILD" -L "$TEST_BUILD" -lUsageCore -Xlinker -rpath -Xlinker "$TEST_BUILD" Sources/UsageBar/Providers.swift scripts/ConnectorTestMain.swift -o "$TEST_BUILD/tests"
"$TEST_BUILD/tests"
