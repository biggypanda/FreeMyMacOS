#!/bin/bash
# Regenerates Support/AppIcon.icns from Scripts/make-icon.swift.
# Usage: Scripts/make-icon.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

source_png="$work/icon-1024.png"
swift "$root/Scripts/make-icon.swift" "$source_png"

iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  double=$((size * 2))
  sips -z "$size" "$size" "$source_png" --out "$iconset/icon_${size}x${size}.png" > /dev/null
  sips -z "$double" "$double" "$source_png" --out "$iconset/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns "$iconset" -o "$root/Support/AppIcon.icns"
echo "Wrote $root/Support/AppIcon.icns"
