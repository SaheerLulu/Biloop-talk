#!/usr/bin/env bash
#
# Apply Biloop branding to a checked-out copy of Nextcloud Talk Android.
#
# Usage:
#   scripts/apply-branding-android.sh <path-to-upstream-checkout>
#
# Rebrands:
#   * app name  -> "Biloop Talk"  (app/src/main/res/values/setup.xml)
#   * launcher icon -> Biloop icon:
#       - drawable/ic_launcher_background.xml  -> solid purple vector
#       - drawable-<dpi>/ic_launcher_foreground.png -> white "B"
#       - mipmap-<dpi>/ic_launcher(.|_round.)png -> full Biloop icon
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
ANDROID_ASSETS="$BRANDING_DIR/android"
UPSTREAM_ABS="$(cd "$UPSTREAM" && pwd)"
RES="$UPSTREAM_ABS/app/src/main/res"

if [[ ! -d "$RES" ]]; then
  echo "error: $RES not found (unexpected upstream layout)" >&2
  exit 1
fi

echo "==> Applying Biloop branding to $UPSTREAM_ABS"

# --- 1. App name ------------------------------------------------------------
APP_NAME="$(node -e "process.stdout.write(require('$BRANDING_DIR/branding.json').productName)")"
SETUP="$RES/values/setup.xml"
if [[ -f "$SETUP" ]]; then
  sed -E -i \
    -e "s#(<string name=\"nc_app_name\">)[^<]*(</string>)#\1${APP_NAME}\2#" \
    -e "s#(<string name=\"nc_app_product_name\">)[^<]*(</string>)#\1${APP_NAME}\2#" \
    -e "s#(<string name=\"nc_server_product_name\">)[^<]*(</string>)#\1Biloop#" \
    "$SETUP"
  echo "    + app name -> ${APP_NAME}, server product name -> Biloop"
else
  echo "    ! $SETUP not found, skipping app name" >&2
fi

# --- 1b. Replace remaining "Nextcloud" mentions in user-facing strings ------
# Only touch string resources (display text), never code/package identifiers.
nc_count=0
while IFS= read -r -d '' f; do
  sed -i -e 's/Nextcloud Talk/Biloop Talk/g' -e 's/Nextcloud/Biloop/g' "$f"
  nc_count=$((nc_count+1))
done < <(find "$RES/../.." -path '*/res/values*/strings.xml' -print0 2>/dev/null)
echo "    + rebranded Nextcloud -> Biloop in $nc_count strings.xml file(s)"

# --- 2. Launcher icon -------------------------------------------------------
# Remove the upstream launcher background/foreground resources so our copies
# are the single definition of each resource name (avoid duplicate-resource
# build errors). They stay drawables (referenced from Kotlin too).
find "$RES" -type f \( -name 'ic_launcher_background.*' -o -name 'ic_launcher_foreground.*' \) \
  -path '*drawable*' -print -delete || true

# Solid purple background (vector drawable).
mkdir -p "$RES/drawable"
cp "$ANDROID_ASSETS/drawable/ic_launcher_background.xml" "$RES/drawable/ic_launcher_background.xml"
echo "    + drawable/ic_launcher_background.xml"

# White "B" foreground (PNG per density).
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$RES/drawable-$d"
  cp "$ANDROID_ASSETS/drawable-$d/ic_launcher_foreground.png" "$RES/drawable-$d/ic_launcher_foreground.png"
done
echo "    + drawable-<dpi>/ic_launcher_foreground.png"

# Legacy launcher icons (pre-API26).
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$RES/mipmap-$d"
  cp "$ANDROID_ASSETS/mipmap-$d/ic_launcher.png" "$RES/mipmap-$d/ic_launcher.png"
  cp "$ANDROID_ASSETS/mipmap-$d/ic_launcher_round.png" "$RES/mipmap-$d/ic_launcher_round.png"
done
echo "    + mipmap-<dpi>/ic_launcher(.|_round.)png"

echo "==> Branding applied."
