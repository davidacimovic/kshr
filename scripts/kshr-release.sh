#!/usr/bin/env bash
set -euo pipefail

# KSHR release: build the cmux app from this fork, brand it KSHR, sign it with
# David's Developer ID, notarize, make the DMG and the Sparkle appcast, and
# publish a GitHub release on davidacimovic/kshr.
#
# Usage: ./scripts/kshr-release.sh <tag> [--build-only] [--allow-overwrite]
#   <tag>             kshr-v<upstream version>[-N], e.g. kshr-v0.65.0
#   --build-only      stop after signing; leaves build/Build/Products/Release/KSHR.app
#   --allow-overwrite replace existing release assets for the same tag
#
# Differences from scripts/build-sign-upload.sh (upstream):
#   - GhosttyKit comes from scripts/ensure-ghosttykit.sh (prebuilt when pinned).
#   - kshr.entitlements: no Cloud tunnel, no restricted keys, no provisioning
#     profile (sign-cmux-bundle.sh handles the no-profile case).
#   - Single signing pass (CMUX_SIGN_MODE=all) and one notarization of the app.
#   - The built cmux.app is renamed KSHR.app with CFBundleName/DisplayName KSHR.
#   - Sparkle: our EdDSA key (login keychain item kshr-sparkle-private) and feed.
#   - Notarization through a notarytool keychain profile (KSHR_NOTARY_PROFILE).
#   - No Homebrew cask.

usage() { sed -n '4,16p' "$0"; }

BUILD_ONLY=0
ALLOW_OVERWRITE=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only) BUILD_ONLY=1; shift ;;
    --allow-overwrite) ALLOW_OVERWRITE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"
[[ $# -eq 1 ]] || { usage >&2; exit 1; }
TAG="$1"
[[ "$TAG" == kshr-v* ]] || { echo "tag must look like kshr-v0.65.0 (upstream v* tags are cmux's)" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# Build phases shell out to rustup/cargo (diff sidecar, nucleo FFI, cmux-cua) and go
# (WireGuard, required for Release); make them visible to xcodebuild's scripts.
export PATH="$HOME/.cargo/bin:/opt/homebrew/opt/rustup/bin:/opt/homebrew/bin:$HOME/go/bin:$PATH"
# The wireguard-go phase prepends /usr/local/go/bin itself; point it at the real Go.
if command -v go >/dev/null 2>&1; then export CMUX_GO_BIN_DIR="$(dirname "$(command -v go)")"; fi

SIGN_HASH="${KSHR_SIGN_HASH:-57B8DAD2045B4073DEF92144166DDBE8C2DCE503}"   # Developer ID Application: David Acimovic (X9YF2BH97P)
ENTITLEMENTS="kshr.entitlements"
NOTARY_PROFILE="${KSHR_NOTARY_PROFILE:-kshr-notary}"
GH_REPO="${GH_REPO:-davidacimovic/kshr}"; export GH_REPO
FEED_URL="${KSHR_FEED_URL:-https://github.com/$GH_REPO/releases/latest/download/appcast.xml}"
SPARKLE_KEYCHAIN_ITEM="${KSHR_SPARKLE_KEYCHAIN_ITEM:-kshr-sparkle-private}"
PRODUCTS="build/Build/Products/Release"
BUILT_APP="$PRODUCTS/cmux.app"
APP_PATH="$PRODUCTS/KSHR.app"
DMG="KSHR-macos.dmg"

# --- Pre-flight ---
for tool in xcodebuild create-dmg xcrun codesign ditto gh python3 swift; do
  command -v "$tool" >/dev/null || { echo "MISSING: $tool" >&2; exit 1; }
done
security find-identity -v -p codesigning | grep -q "$SIGN_HASH" || {
  echo "Signing identity $SIGN_HASH is not in the keychain" >&2; exit 1; }
SPARKLE_PRIVATE_KEY="$(security find-generic-password -s "$SPARKLE_KEYCHAIN_ITEM" -a "$USER" -w 2>/dev/null || true)"
[[ -n "$SPARKLE_PRIVATE_KEY" ]] || { echo "No Sparkle key in the keychain (item $SPARKLE_KEYCHAIN_ITEM)" >&2; exit 1; }
export SPARKLE_PRIVATE_KEY
if (( ! BUILD_ONLY )); then
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || {
    echo "No notarytool profile '$NOTARY_PROFILE'. Create it once (asks for an app-specific password):" >&2
    echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <developer Apple ID> --team-id X9YF2BH97P" >&2
    exit 1; }
fi
echo "Pre-flight checks passed"

# --- GhosttyKit (prebuilt when the pinned checksum exists, else zig build) ---
./scripts/ensure-ghosttykit.sh
[[ -d GhosttyKit.xcframework ]] || cp -R ghostty/macos/GhosttyKit.xcframework GhosttyKit.xcframework

# --- Build app (Release, unsigned) ---
echo "Building app..."
rm -rf build/ && mkdir -p build
xcodebuild -scheme cmux -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build > build/xcodebuild.log 2>&1 || { tail -40 build/xcodebuild.log; echo "xcodebuild failed (full log: build/xcodebuild.log)" >&2; exit 1; }
tail -3 build/xcodebuild.log
[[ -d "$BUILT_APP" ]] || { echo "build produced no $BUILT_APP" >&2; exit 1; }
[[ -x "$BUILT_APP/Contents/Resources/bin/ghostty" ]] || { echo "Ghostty theme picker helper missing" >&2; exit 1; }
echo "Build succeeded"

# --- Brand: KSHR.app, display name, Sparkle feed and key ---
mv "$BUILT_APP" "$APP_PATH"
APP_PLIST="$APP_PATH/Contents/Info.plist"
for key in CFBundleName CFBundleDisplayName; do
  /usr/libexec/PlistBuddy -c "Set :$key KSHR" "$APP_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :$key string KSHR" "$APP_PLIST"
done
SPARKLE_PUBLIC_KEY_DERIVED=$(swift scripts/derive_sparkle_public_key.swift "$SPARKLE_PRIVATE_KEY")
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$APP_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$APP_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY_DERIVED" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $FEED_URL" "$APP_PLIST"
echo "Branded: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PLIST") / $(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$APP_PLIST") / feed $FEED_URL"

# Non-sandboxed app: Sparkle's sandbox-only XPC services would stall the installer handoff.
./scripts/remove-sparkle-sandbox-xpc-services.sh "$APP_PATH"

# --- Codesign (one pass, no provisioning profile) ---
echo "Codesigning..."
CMUX_SIGN_MODE=all ./scripts/sign-cmux-bundle.sh "$APP_PATH" "$ENTITLEMENTS" "$SIGN_HASH"
codesign -dvv "$APP_PATH" 2>&1 | grep -E '^(Identifier|Authority=Developer|TeamIdentifier)' | sed 's/^/  /'
echo "Codesign verified"

if (( BUILD_ONLY )); then
  echo ""
  echo "=== build-only: $APP_PATH is signed (not notarized) ==="
  exit 0
fi

# --- Notarize app ---
echo "Notarizing app..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" kshr-notary.zip
xcrun notarytool submit kshr-notary.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
rm -f kshr-notary.zip
echo "App notarized"

# --- DMG ---
echo "Creating DMG..."
./scripts/verify-app-bundle-licenses.sh "$APP_PATH"
rm -f "$DMG"
create-dmg --codesign "$SIGN_HASH" "$DMG" "$APP_PATH"
echo "Notarizing DMG..."
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "DMG notarized"

# --- Sparkle appcast ---
echo "Generating appcast..."
DOWNLOAD_URL_PREFIX="https://github.com/$GH_REPO/releases/download/$TAG/" \
RELEASE_NOTES_URL="https://github.com/$GH_REPO/releases/tag/$TAG" \
  ./scripts/sparkle_generate_appcast.sh "$DMG" "$TAG" appcast.xml

# --- GitHub release on the fork ---
if gh release view "$TAG" >/dev/null 2>&1; then
  EXISTING="$(gh release view "$TAG" --json assets --jq '.assets[].name' || true)"
  if printf '%s\n' "$EXISTING" | grep -Fxq "$DMG" || printf '%s\n' "$EXISTING" | grep -Fxq appcast.xml; then
    (( ALLOW_OVERWRITE )) || { echo "Refusing to overwrite assets of existing release $TAG (use --allow-overwrite)" >&2; exit 1; }
    gh release upload "$TAG" "$DMG" appcast.xml --clobber
  else
    gh release upload "$TAG" "$DMG" appcast.xml
  fi
else
  gh release create "$TAG" "$DMG" appcast.xml --title "$TAG" --notes "KSHR build of cmux ${TAG#kshr-v}. See README-KSHR.md."
fi
gh release view "$TAG"
echo "Feed: $FEED_URL"
echo "DMG sha256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
echo ""
echo "=== Release $TAG complete ==="
