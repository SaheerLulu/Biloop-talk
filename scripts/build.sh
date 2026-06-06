#!/usr/bin/env bash
#
# Clone Nextcloud Talk Desktop and build a distributable for the target platform.
#
# Usage:
#   scripts/build.sh <platform>
#
# <platform> is one of: win | mac | linux
#
# Environment variables:
#   TALK_DESKTOP_REPO   Git URL to clone (default: nextcloud/talk_desktop on GitHub)
#   TALK_DESKTOP_REF    Branch or tag to check out (default: main)
#   WORK_DIR            Where to clone the source (default: ./upstream)
#
# This script is intended to run on a machine that matches the target OS:
#   - mac   builds must run on macOS  (electron-builder needs hdiutil)
#   - win   builds run natively on Windows runners (no Wine required there)
#   - linux builds run on Linux
#
set -euo pipefail

PLATFORM="${1:-}"
if [[ -z "$PLATFORM" ]]; then
  echo "error: missing platform argument (win|mac|linux)" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_URL="${TALK_DESKTOP_REPO:-https://github.com/nextcloud/talk_desktop.git}"
REF="${TALK_DESKTOP_REF:-main}"
WORK_DIR="${WORK_DIR:-upstream}"

echo "==> Building Nextcloud Talk Desktop"
echo "    repo:     $REPO_URL"
echo "    ref:      $REF"
echo "    platform: $PLATFORM"
echo "    workdir:  $WORK_DIR"

# --- Fetch source -----------------------------------------------------------
if [[ ! -d "$WORK_DIR/.git" ]]; then
  # Try the requested ref first; fall back to the default branch.
  if ! git clone --depth 1 --branch "$REF" "$REPO_URL" "$WORK_DIR" 2>/dev/null; then
    echo "==> ref '$REF' not found as branch/tag, cloning default branch"
    git clone --depth 1 "$REPO_URL" "$WORK_DIR"
  fi
else
  echo "==> Source already present in $WORK_DIR, reusing"
fi

cd "$WORK_DIR"
echo "==> Checked out commit: $(git rev-parse --short HEAD)"
UPSTREAM_ABS="$(pwd)"

# --- Apply Biloop branding --------------------------------------------------
# Set APPLY_BRANDING=0 to build vanilla upstream instead.
if [[ "${APPLY_BRANDING:-1}" != "0" ]]; then
  bash "$REPO_ROOT/scripts/apply-branding.sh" "$UPSTREAM_ABS"
else
  echo "==> APPLY_BRANDING=0, skipping branding"
fi

# --- Install dependencies ---------------------------------------------------
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi

# --- Resolve the right build script ----------------------------------------
# Map our short platform name to the conventional electron-builder flag and to
# the long name used in upstream npm scripts (package:windows / package:mac ...).
case "$PLATFORM" in
  win)   EB_FLAG="--win";   LONG="windows" ;;
  mac)   EB_FLAG="--mac";   LONG="mac" ;;
  linux) EB_FLAG="--linux"; LONG="linux" ;;
  *) echo "error: unknown platform '$PLATFORM'" >&2; exit 2 ;;
esac

# Allow unsigned builds: without signing certificates electron-builder would
# otherwise abort. CI may override these by providing real certs.
export CSC_IDENTITY_AUTO_DISCOVERY="${CSC_IDENTITY_AUTO_DISCOVERY:-false}"

# Pick the best available script from package.json, in order of preference:
#   1. package:<long>       (e.g. package:windows) — upstream's own script
#   2. build  + electron-builder <flag>
#   3. electron-builder <flag>   (assumes a prior compile step is not required)
HAS() { node -e "process.exit(require('./package.json').scripts?.['$1']?0:1)" 2>/dev/null; }

if HAS "package:$LONG"; then
  echo "==> Running: npm run package:$LONG"
  npm run "package:$LONG"
elif HAS "build"; then
  echo "==> Running: npm run build && npx electron-builder $EB_FLAG"
  npm run build
  npx --no-install electron-builder "$EB_FLAG" || npx electron-builder "$EB_FLAG"
else
  echo "==> Running: npx electron-builder $EB_FLAG"
  npx --no-install electron-builder "$EB_FLAG" || npx electron-builder "$EB_FLAG"
fi

echo "==> Build finished. Looking for artifacts..."
# electron-builder default output dir is ./dist; some projects override it.
for d in dist out release build/dist; do
  if [[ -d "$d" ]]; then
    echo "---- $d ----"
    ls -la "$d" || true
  fi
done
