#!/bin/bash
# Finder drag-to-Applications image. App signing must happen before this step.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-dist/ry Usage Bar.app}"
OUTPUT="${2:-dist/ry-usage-bar.dmg}"
PYTHON="${RY_DMG_PYTHON:-python3}"
"$PYTHON" -c 'import dmgbuild' || { printf 'Install packaging dependency: python3 -m pip install -r scripts/dmg-requirements.txt\n' >&2; exit 1; }
mkdir -p dist
swift scripts/InstallerBackground.swift dist/installer-background.png
"$PYTHON" -m dmgbuild -s scripts/dmg-settings.py -D "app=$APP" -D 'background=dist/installer-background.png' 'ry Usage Bar' "$OUTPUT"
hdiutil verify "$OUTPUT"
