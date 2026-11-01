#!/usr/bin/env bash
#
# build-ipa.sh: builds an UNSIGNED .ipa of Timer for sideloading.
#
# The .ipa is intentionally unsigned: sideload tools (AltStore, Sideloadly)
# re-sign it with the user's own Apple ID at install time.
#
# Output: build/Timer-<version>.ipa
#
set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE="build/Timer.xcarchive"
STAGE="build/ipa"

if command -v xcodegen >/dev/null 2>&1; then
  echo "▸ xcodegen generate"
  xcodegen generate --quiet
fi

rm -rf "$ARCHIVE" "$STAGE"
mkdir -p "$STAGE/Payload"

echo "▸ Archiving (unsigned)…"
xcodebuild \
  -project Timer.xcodeproj \
  -scheme Timer \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -quiet archive

APP="$ARCHIVE/Products/Applications/Timer.app"
[ -d "$APP" ] || { echo "✗ Built app not found at $APP" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
OUT="build/Timer-$VERSION.ipa"

echo "▸ Packaging $OUT"
cp -R "$APP" "$STAGE/Payload/"
rm -f "$OUT"
( cd "$STAGE" && zip -qry "../$(basename "$OUT")" Payload )

echo "✓ Wrote $OUT"
