#!/bin/bash
# Packs an app into a styled, compressed DMG: dark background, app on the left, Applications on the right.
# Usage: Scripts/make-dmg.sh <path/to/App.app> <output.dmg>
# Finder lays out the window, so the first run may ask to allow controlling Finder.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <path/to/App.app> <output.dmg>" >&2
  exit 64
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$1"
dmg="$2"
app_name="$(basename "$app")"
volume="${app_name%.app}"

work="$(mktemp -d)"
mount_dir=""
cleanup() {
  if [ -n "$mount_dir" ] && [ -d "$mount_dir" ]; then
    hdiutil detach -quiet "$mount_dir" || hdiutil detach -quiet -force "$mount_dir" || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

# Background: one HiDPI TIFF holding the 1x and 2x renderings.
swift "$root/Scripts/make-dmg-background.swift" "$work/background.png" "$work/background@2x.png" > /dev/null
staging="$work/staging"
mkdir -p "$staging/.background"
tiffutil -cathidpicheck "$work/background.png" "$work/background@2x.png" -out "$staging/.background/background.tiff" > /dev/null 2>&1
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"

# Writable image first, so Finder can store the window layout in .DS_Store.
if [ -d "/Volumes/$volume" ]; then
  echo "error: /Volumes/$volume is already mounted; eject it first." >&2
  exit 1
fi
rw="$work/rw.dmg"
hdiutil create -quiet -volname "$volume" -srcfolder "$staging" -fs HFS+ -format UDRW -ov "$rw"
mount_dir="$(hdiutil attach -readwrite -noverify -noautoopen "$rw" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
disk_name="$(basename "$mount_dir")"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$disk_name"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "$app_name" of container window to {170, 200}
    set position of item "Applications" of container window to {490, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

chflags hidden "$mount_dir/.background" || true
sync
hdiutil detach -quiet "$mount_dir"
mount_dir=""

rm -f "$dmg"
hdiutil convert -quiet "$rw" -format UDZO -imagekey zlib-level=9 -o "$dmg"
echo "Wrote $dmg"
