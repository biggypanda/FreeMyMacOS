#!/bin/bash
# Builds FreeMyMacOS and assembles dist/FreeMyMacOS.app.
# Usage: Scripts/bundle.sh [debug|release]   (default: release)
#
# release builds a universal (arm64 + x86_64) binary; debug builds for this Mac only.
# Signs with $SIGN_ID when it is set (e.g. a "Developer ID Application" identity),
# otherwise ad hoc. Always hardened runtime with Support/FreeMyMacOS.entitlements.
set -euo pipefail

config="${1:-release}"
case "$config" in
  debug|release) ;;
  *) echo "usage: $0 [debug|release]" >&2; exit 64 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [ "$config" = "release" ]; then
  arch_flags=(--arch arm64 --arch x86_64)
else
  arch_flags=()
fi

swift build -c "$config" --product FreeMyMacOS ${arch_flags[@]+"${arch_flags[@]}"}
bin_dir="$(swift build -c "$config" ${arch_flags[@]+"${arch_flags[@]}"} --show-bin-path)"

app="$root/dist/FreeMyMacOS.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/FreeMyMacOS" "$app/Contents/MacOS/FreeMyMacOS"
cp "$root/Support/Info.plist" "$app/Contents/Info.plist"
cp "$root/Support/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$app/Contents/PkgInfo"

sign_flags=(--force --options runtime --entitlements "$root/Support/FreeMyMacOS.entitlements")
if [ -n "${SIGN_ID:-}" ]; then
  codesign --sign "$SIGN_ID" --timestamp "${sign_flags[@]}" "$app"
else
  codesign --sign - "${sign_flags[@]}" "$app"
fi
codesign --verify --deep --strict "$app"
echo "Built $app ($config, $(lipo -archs "$app/Contents/MacOS/FreeMyMacOS"))"
