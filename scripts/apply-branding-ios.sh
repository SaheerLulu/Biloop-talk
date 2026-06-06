#!/usr/bin/env bash
#
# Apply Biloop branding to a checked-out copy of Nextcloud Talk iOS.
#
# Usage:
#   scripts/apply-branding-ios.sh <path-to-upstream-checkout>
#
# Rebrands (best run on macOS, where PlistBuddy/sips are available):
#   * app display name -> "Biloop Talk" (NextcloudTalk/Info.plist + pbxproj)
#   * brand color -> #502C6F and disable server theming (NCAppBranding.m)
#   * "Nextcloud" -> "Biloop" in Localizable.strings
#   * app icon -> Biloop icon (AppIcon.appiconset PNGs)
#
set -euo pipefail

UPSTREAM="${1:-}"
if [[ -z "$UPSTREAM" || ! -d "$UPSTREAM" ]]; then
  echo "error: pass the path to the upstream checkout" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANDING_DIR="$REPO_ROOT/branding"
UPSTREAM_ABS="$(cd "$UPSTREAM" && pwd)"
APP_NAME="$(node -e "process.stdout.write(require('$BRANDING_DIR/branding.json').productName)")"
BRAND_HEX="$(node -e "process.stdout.write(require('$BRANDING_DIR/branding.json').brandColor)")"

echo "==> Applying Biloop branding to $UPSTREAM_ABS"

# --- 1. App display name -----------------------------------------------------
INFO="$UPSTREAM_ABS/NextcloudTalk/Info.plist"
if [[ -f "$INFO" ]]; then
  if [[ -x /usr/libexec/PlistBuddy ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "$INFO" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_NAME}" "$INFO"
  else
    perl -0777 -i -pe "s{(<key>CFBundleDisplayName</key>\\s*<string>)[^<]*(</string>)}{\${1}${APP_NAME}\${2}}s" "$INFO"
  fi
  echo "    + Info.plist CFBundleDisplayName -> ${APP_NAME}"
fi

# pbxproj display-name build settings (extensions etc.)
PBX="$UPSTREAM_ABS/NextcloudTalk.xcodeproj/project.pbxproj"
[[ -f "$PBX" ]] && perl -i -pe 's/(INFOPLIST_KEY_CFBundleDisplayName = ")Nextcloud Talk(")/${1}'"${APP_NAME}"'${2}/g' "$PBX" \
  && echo "    + pbxproj display names -> ${APP_NAME}"

# --- 2. Brand color + force brand (NCAppBranding.m) --------------------------
NCB="$UPSTREAM_ABS/NextcloudTalk/Settings/NCAppBranding.m"
if [[ -f "$NCB" ]]; then
  BRAND_HEX="$BRAND_HEX" perl -i -pe 's/(brandColorHex = \@")#[0-9A-Fa-f]{6}(")/$1$ENV{BRAND_HEX}$2/' "$NCB"
  perl -i -pe 's/(useServerThemimg = )YES/${1}NO/' "$NCB"
  echo "    + NCAppBranding brandColor -> ${BRAND_HEX}, server theming off"
fi

# --- 3. Replace "Nextcloud" mentions in user-facing strings -----------------
nc=0
while IFS= read -r -d '' f; do
  APP_NAME="$APP_NAME" perl -i -pe 's/Nextcloud Talk/$ENV{APP_NAME}/g; s/Nextcloud/Biloop/g;' "$f"
  nc=$((nc+1))
done < <(find "$UPSTREAM_ABS/NextcloudTalk" -name 'Localizable.strings' -print0 2>/dev/null)
echo "    + rebranded Nextcloud -> Biloop in $nc Localizable.strings file(s)"

# --- 4. App icon (AppIcon.appiconset) ---------------------------------------
MASTER="$BRANDING_DIR/ios/AppIcon.png"
ICONSET="$(find "$UPSTREAM_ABS" -type d -name 'AppIcon.appiconset' 2>/dev/null | head -1)"
if [[ -n "$ICONSET" && -f "$MASTER" ]] && command -v sips >/dev/null 2>&1; then
  n=0
  for png in "$ICONSET"/*.png; do
    [[ -e "$png" ]] || continue
    W=$(sips -g pixelWidth "$png" | awk '/pixelWidth/{print $2}')
    H=$(sips -g pixelHeight "$png" | awk '/pixelHeight/{print $2}')
    [[ -n "$W" && -n "$H" ]] && sips -s format png -z "$H" "$W" "$MASTER" --out "$png" >/dev/null && n=$((n+1))
  done
  echo "    + replaced $n AppIcon PNG(s)"
else
  echo "    ~ skipping app icon (no appiconset or sips unavailable)"
fi

echo "==> Branding applied."
