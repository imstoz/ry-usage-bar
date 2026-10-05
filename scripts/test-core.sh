#!/bin/bash
# Runs the same regression cases when command line tools omit XCTest.
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_BUILD="$(mktemp -d)"
trap 'rm -rf "$TEST_BUILD"' EXIT
swiftc -emit-library -emit-module -enable-testing -module-name UsageCore Sources/UsageCore/*.swift -o "$TEST_BUILD/libUsageCore.dylib" -emit-module-path "$TEST_BUILD/UsageCore.swiftmodule"
swiftc -D RY_STANDALONE_TESTS -I "$TEST_BUILD" -L "$TEST_BUILD" -lUsageCore -Xlinker -rpath -Xlinker "$TEST_BUILD" Tests/UsageCoreTests/UsageTests.swift scripts/CoreTestMain.swift -o "$TEST_BUILD/tests"
"$TEST_BUILD/tests"
