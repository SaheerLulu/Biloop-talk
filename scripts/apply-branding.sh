#!/usr/bin/env bash
#
# Apply Biloop branding to a checked-out copy of Nextcloud Talk Desktop.
#
# Usage:
#   scripts/apply-branding.sh <path-to-upstream-checkout>
#
# Talk Desktop has a first-class branding mechanism (build/resolveBuildConfig.js):
# if a file exists at <repo>/.overrides/build.config.json it is merged over the
# base build config and BUILD_CONFIG.isBranded becomes true (which also hides
# the upstream "Nextcloud" homepage/issues links and the GitHub update checker).
#
# This script:
#   * writes .overrides/build.config.json from branding/branding.json
#     (application name, description, brand colors)
#   * replaces the packaged-app icon used by electron-forge
#     (packagerConfig.icon -> img/icons/icon[.icns|.ico|.png]); the .icns is
#     generated from the PNG on macOS where iconutil/sips are available
#   * patches package.json metadata (productName/description/author/homepage)
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

echo "==> Applying Biloop branding to $UPSTREAM_ABS"

# --- 1. Build-config overrides (the official branding hook) ------------------
mkdir -p "$UPSTREAM_ABS/.overrides"
node - "$UPSTREAM_ABS/.overrides/build.config.json" "$BRANDING_DIR/branding.json" <<'NODE'
const fs = require('fs');
const [outPath, brandPath] = process.argv.slice(2);
const b = JSON.parse(fs.readFileSync(brandPath, 'utf8'));
// Partial<BuildConfigFile> — only the keys we want to override.
const overrides = {
  applicationName: b.productName,
  description: b.description,
  brandColor: b.brandColor,
  brandGradient: b.brandGradient,
  brandFontColor: b.brandFontColor,
  helpUrl: b.helpUrl,
  privacyUrl: b.privacyUrl,
};
// NOTE: setting primaryColor/backgroundColor here flips the upstream
// `withThemingOverrides` flag, which then requires pre-generated Nextcloud
// style overrides (scripts/override-nextcloud-styles.mjs) or the build fails.
// brandColor already themes the welcome/splash/installer; the in-app Talk UI
// follows the connected server's theme.
fs.writeFileSync(outPath, JSON.stringify(overrides, null, 2) + '\n');
console.log('    + .overrides/build.config.json (isBranded=true): ' + b.productName);
NODE

# --- 2. App icon (electron-forge packagerConfig.icon = img/icons/icon) -------
ICON_DIR="$UPSTREAM_ABS/img/icons"
mkdir -p "$ICON_DIR"
cp "$BRANDING_DIR/icon.png" "$ICON_DIR/icon.png"
cp "$BRANDING_DIR/icon.ico" "$ICON_DIR/icon.ico"
echo "    + img/icons/icon.png, img/icons/icon.ico"

# Generate img/icons/icon.icns for macOS packaging (needs Apple tooling).
if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  ICONSET="$(mktemp -d)/icon.iconset"
  mkdir -p "$ICONSET"
  for sz in 16 32 64 128 256 512; do
    sips -z "$sz" "$sz"           "$BRANDING_DIR/icon.png" --out "$ICONSET/icon_${sz}x${sz}.png"    >/dev/null
    sips -z "$((sz*2))" "$((sz*2))" "$BRANDING_DIR/icon.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ICON_DIR/icon.icns"
  echo "    + img/icons/icon.icns (generated via iconutil)"
else
  echo "    ~ skipping .icns generation (iconutil/sips not available on this OS)"
fi

# Also refresh any other square app icons in the tree (tray/app), but only
# files literally named icon.png / app.png to avoid distorting other artwork.
while IFS= read -r -d '' f; do
  case "$(basename "$f")" in
    icon.png|app.png) cp "$BRANDING_DIR/icon.png" "$f"; echo "    ~ $f" ;;
  esac
done < <(find "$UPSTREAM_ABS" -path '*/node_modules/*' -prune -o \
            -path '*/.git/*' -prune -o -type f -name '*.png' -print0 2>/dev/null)

# --- 3. package.json metadata ------------------------------------------------
node - "$UPSTREAM_ABS/package.json" "$BRANDING_DIR/branding.json" <<'NODE'
const fs = require('fs');
const [pkgPath, brandPath] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const b = JSON.parse(fs.readFileSync(brandPath, 'utf8'));
pkg.productName = b.productName;
pkg.description = b.description;
pkg.author = b.author;
pkg.homepage = b.homepage;
fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
console.log('    + package.json: productName=' + b.productName);
NODE

# --- 4. Installer assets ----------------------------------------------------
# macOS DMG background (the blue Nextcloud-branded image shown while installing).
if [[ -f "$BRANDING_DIR/dmg-background.png" ]]; then
  for bg in "$UPSTREAM_ABS/img/dmg-background.png" "$UPSTREAM_ABS/img/dmg-background@2x.png"; do
    [[ -f "$bg" ]] || continue
    if command -v sips >/dev/null 2>&1; then
      W=$(sips -g pixelWidth "$bg" | awk '/pixelWidth/{print $2}')
      H=$(sips -g pixelHeight "$bg" | awk '/pixelHeight/{print $2}')
      sips -s format png -z "$H" "$W" "$BRANDING_DIR/dmg-background.png" --out "$bg" >/dev/null
    else
      cp "$BRANDING_DIR/dmg-background.png" "$bg"
    fi
    echo "    ~ $(basename "$bg") (Biloop DMG background)"
  done
fi

# Windows Squirrel installer icon URL (was the nextcloud raw icon).
FORGE="$UPSTREAM_ABS/forge.config.js"
[[ -f "$FORGE" ]] && perl -i -pe "s{iconUrl: '[^']*'}{iconUrl: 'https://raw.githubusercontent.com/SaheerLulu/Biloop-talk/main/branding/icon.ico'}" "$FORGE" \
  && echo "    + forge.config.js Squirrel iconUrl -> Biloop"

echo "==> Branding applied."
