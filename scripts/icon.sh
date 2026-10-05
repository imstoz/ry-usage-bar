#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICON_BUILD="$(mktemp -d)"
trap 'rm -rf "$ICON_BUILD"' EXIT
mkdir -p "$ICON_BUILD/AppIcon.iconset" assets
swift scripts/Icon.swift "$ICON_BUILD/icon.png"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$ICON_BUILD/icon.png" --out "$ICON_BUILD/AppIcon.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" "$ICON_BUILD/icon.png" --out "$ICON_BUILD/AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
python3 - "$ICON_BUILD/AppIcon.iconset" assets/AppIcon.icns <<'ICONPY'
from pathlib import Path
import struct, sys
root = Path(sys.argv[1])
chunks = []
for kind, name in [(b'icp4', 'icon_16x16.png'), (b'icp5', 'icon_32x32.png'), (b'icp6', 'icon_32x32@2x.png'), (b'ic07', 'icon_128x128.png'), (b'ic08', 'icon_256x256.png'), (b'ic09', 'icon_512x512.png'), (b'ic10', 'icon_512x512@2x.png')]:
    png = (root / name).read_bytes()
    chunks.append(kind + struct.pack('>I', len(png) + 8) + png)
body = b''.join(chunks)
Path(sys.argv[2]).write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
ICONPY
