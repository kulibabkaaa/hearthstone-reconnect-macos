#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/Support/AppIconSource.png"
MASTER="$ROOT/Support/AppIcon.png"
ICONSET="$ROOT/Support/AppIcon.iconset"
OUTPUT="$ROOT/Support/AppIcon.icns"

/usr/bin/xcrun swift "$ROOT/Scripts/generate_icon.swift" \
    "$SOURCE" "$MASTER"

/bin/rm -rf "$ICONSET"
/bin/mkdir -p "$ICONSET"

resize() {
    local pixels="$1"
    local filename="$2"
    /usr/bin/sips -z "$pixels" "$pixels" "$MASTER" \
        --out "$ICONSET/$filename" >/dev/null
}

resize 16 icon_16x16.png
resize 32 icon_16x16@2x.png
resize 32 icon_32x32.png
resize 64 icon_32x32@2x.png
resize 128 icon_128x128.png
resize 256 icon_128x128@2x.png
resize 256 icon_256x256.png
resize 512 icon_256x256@2x.png
resize 512 icon_512x512.png
resize 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "$OUTPUT"
