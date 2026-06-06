#!/usr/bin/env bash
#
# Clone Nextcloud Talk iOS, apply Biloop branding, and build an UNSIGNED .ipa.
#
# Usage:
#   scripts/build-ios.sh
#
# Environment variables:
#   TALK_IOS_REPO   Git URL (default: nextcloud/talk-ios on GitHub)
#   TALK_IOS_REF    Branch/tag to build (default: main)
#   WORK_DIR        Where to clone the source (default: ./upstream-ios)
#   APPLY_BRANDING  Set to 0 to build vanilla upstream
#
# Produces an UNSIGNED archive/.ipa. An unsigned .ipa cannot be installed via
# the App Store; it can be sideloaded with tools that re-sign it (AltStore,
# Sideloadly) or re-signed with an Apple Developer certificate.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_URL="${TALK_IOS_REPO:-https://github.com/nextcloud/talk-ios.git}"
REF="${TALK_IOS_REF:-main}"
WORK_DIR="${WORK_DIR:-upstream-ios}"
WORKSPACE="NextcloudTalk.xcworkspace"
SCHEME="NextcloudTalk"

echo "==> Building Nextcloud Talk iOS (Biloop Talk)"
echo "    repo: $REPO_URL  ref: $REF"

# --- Fetch source -----------------------------------------------------------
if [[ ! -d "$WORK_DIR/.git" ]]; then
  if ! git clone --depth 1 --branch "$REF" "$REPO_URL" "$WORK_DIR" 2>/dev/null; then
    git clone --depth 1 "$REPO_URL" "$WORK_DIR"
  fi
else
  echo "==> Source already present in $WORK_DIR, reusing"
fi

cd "$WORK_DIR"
UPSTREAM_ABS="$(pwd)"
echo "==> Checked out commit: $(git rev-parse --short HEAD)"

# --- Apply Biloop branding --------------------------------------------------
if [[ "${APPLY_BRANDING:-1}" != "0" ]]; then
  bash "$REPO_ROOT/scripts/apply-branding-ios.sh" "$UPSTREAM_ABS"
else
  echo "==> APPLY_BRANDING=0, skipping branding"
fi

# --- CocoaPods --------------------------------------------------------------
if [[ -f Podfile ]]; then
  echo "==> pod install"
  pod install --repo-update
fi

BUILD_DIR="$UPSTREAM_ABS/build"
ARCHIVE="$BUILD_DIR/BiloopTalk.xcarchive"
rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"

# --- Unsigned archive -------------------------------------------------------
echo "==> xcodebuild archive (unsigned)"
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  PROVISIONING_PROFILE_SPECIFIER="" AD_HOC_CODE_SIGNING_ALLOWED=YES \
  | { command -v xcpretty >/dev/null 2>&1 && xcpretty || cat; }

# --- Package unsigned .ipa --------------------------------------------------
APP="$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -1)"
if [[ -z "$APP" ]]; then
  echo "error: no .app found in archive" >&2
  exit 1
fi
rm -rf "$BUILD_DIR/Payload"; mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"
( cd "$BUILD_DIR" && zip -qry "BiloopTalk-ios-unsigned.ipa" Payload )
echo "==> Built: $BUILD_DIR/BiloopTalk-ios-unsigned.ipa"
ls -lh "$BUILD_DIR"/*.ipa
