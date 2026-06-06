#!/usr/bin/env bash
#
# Apply Biloop branding to a checked-out copy of Nextcloud Talk Desktop.
#
# Usage:
#   scripts/apply-branding.sh <path-to-upstream-checkout>
#
# Reads branding/branding.json and the icon assets in branding/, then:
#   * patches package.json  (productName, description, author, homepage,
#     copyright, and the electron-builder appId / productName / icon paths)
#   * installs the Biloop icon as the electron-builder app icon for every
#     platform (electron-builder converts the 1024px PNG to .icns/.ico)
#   * overwrites any existing icon.png/icon.ico assets found in the upstream
#     tree so in-app icons pick up the new brand too
#
set -euo pipefail

UPSTREAM="${1:-}"
if [[ -z "$UPSTREAM" || ! -d "$UPSTREAM" ]]; then
  echo "error: pass the path to the upstream checkout" >&2
  exit 2
fi

# Resolve this repo's branding dir relative to this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANDING_DIR="$REPO_ROOT/branding"

UPSTREAM_ABS="$(cd "$UPSTREAM" && pwd)"

echo "==> Applying Biloop branding to $UPSTREAM_ABS"

# --- 1. Place the brand icon where electron-builder looks for it -------------
# electron-builder uses the buildResources dir (default: ./build). Providing a
# 1024x1024 icon.png there lets it generate .icns (mac) and .ico (win).
mkdir -p "$UPSTREAM_ABS/build"
cp "$BRANDING_DIR/icon.png" "$UPSTREAM_ABS/build/icon.png"
cp "$BRANDING_DIR/icon.ico" "$UPSTREAM_ABS/build/icon.ico"
echo "    + build/icon.png, build/icon.ico"

# Overwrite any pre-existing PNG/ICO icons in the upstream tree (img/, src/,
# resources/, ...) so the running app, tray, and window icons rebrand too.
# We only touch files literally named icon.png / icon.ico / app icon variants
# to avoid clobbering unrelated images.
while IFS= read -r -d '' f; do
  case "$(basename "$f")" in
    icon.png|app.png|logo.png|512x512.png|256x256.png|favicon.png)
      cp "$BRANDING_DIR/icon.png" "$f"; echo "    ~ $f" ;;
  esac
done < <(find "$UPSTREAM_ABS" -path '*/node_modules/*' -prune -o \
            -type f -name '*.png' -print0 2>/dev/null)

while IFS= read -r -d '' f; do
  cp "$BRANDING_DIR/icon.ico" "$f"; echo "    ~ $f"
done < <(find "$UPSTREAM_ABS" -path '*/node_modules/*' -prune -o \
            -type f -name 'icon.ico' -print0 2>/dev/null)

# --- 2. Patch package.json ---------------------------------------------------
node - "$UPSTREAM_ABS/package.json" "$BRANDING_DIR/branding.json" <<'NODE'
const fs = require('fs');
const [pkgPath, brandPath] = process.argv.slice(2);
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
const b = JSON.parse(fs.readFileSync(brandPath, 'utf8'));

// Top-level metadata
pkg.productName = b.productName;
pkg.description = b.description;
pkg.author = b.author;
pkg.homepage = b.homepage;

// electron-builder config (may live under pkg.build)
pkg.build = pkg.build || {};
const build = pkg.build;
build.appId = b.appId;
build.productName = b.productName;
build.copyright = b.copyright;

// Point every platform's icon at the brand icon. electron-builder converts
// the PNG to the per-platform format it needs.
build.mac = build.mac || {};
build.win = build.win || {};
build.linux = build.linux || {};
build.mac.icon = 'build/icon.png';
build.win.icon = 'build/icon.ico';
build.linux.icon = 'build/icon.png';
build.icon = 'build/icon.png';

fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
console.log('    + package.json: productName=' + b.productName + ', appId=' + b.appId);
NODE

echo "==> Branding applied."
