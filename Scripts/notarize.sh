#!/bin/bash
# Builds a signed universal app, packs it into dist/FreeMyMacOS.dmg, notarizes and staples it.
# Usage:
#   SIGN_ID="Developer ID Application: <Name> (<TEAMID>)" NOTARY_PROFILE=<profile> Scripts/notarize.sh
#
# NOTARY_PROFILE is a keychain profile created once with:
#   xcrun notarytool store-credentials <profile> --apple-id <you@example.com> --team-id <TEAMID>
set -euo pipefail

if [ -z "${SIGN_ID:-}" ] || [ -z "${NOTARY_PROFILE:-}" ]; then
  echo "error: SIGN_ID and NOTARY_PROFILE must both be set." >&2
  echo "  SIGN_ID         your Developer ID Application identity (see: security find-identity -v -p codesigning)" >&2
  echo "  NOTARY_PROFILE  a notarytool keychain profile (see: xcrun notarytool store-credentials --help)" >&2
  echo "usage: SIGN_ID=\"Developer ID Application: <Name> (<TEAMID>)\" NOTARY_PROFILE=<profile> $0" >&2
  exit 64
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

SIGN_ID="$SIGN_ID" "$root/Scripts/bundle.sh" release

app="$root/dist/FreeMyMacOS.app"
dmg="$root/dist/FreeMyMacOS.dmg"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"

rm -f "$dmg"
hdiutil create -volname "FreeMyMacOS" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"

codesign --sign "$SIGN_ID" --timestamp --force "$dmg"
codesign --verify --strict "$dmg"

xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"

echo "Notarized $dmg"
