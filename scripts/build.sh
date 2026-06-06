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

REPO_URL="${TALK_DESKTOP_REPO:-https://github.com/nextcloud/talk-desktop.git}"
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

# --- Resolve the right build scripts ----------------------------------------
# Talk Desktop uses electron-forge with split scripts:
#   build:<long>    -> electron-forge package  (compiles + packages the app)
#   package:<long>  -> electron-forge make --skip-package  (builds installers)
# so the app must be packaged first, then the installers made.
case "$PLATFORM" in
  win)   LONG="windows" ;;
  mac)   LONG="mac" ;;
  linux) LONG="linux" ;;
  *) echo "error: unknown platform '$PLATFORM'" >&2; exit 2 ;;
esac

# Allow unsigned builds (no signing certs in CI by default).
export CSC_IDENTITY_AUTO_DISCOVERY="${CSC_IDENTITY_AUTO_DISCOVERY:-false}"

HAS() { node -e "process.exit(require('./package.json').scripts?.['$1']?0:1)" 2>/dev/null; }

if HAS "build:$LONG" && HAS "package:$LONG"; then
  # electron-forge (Talk Desktop): package, then make installers.
  echo "==> Running: npm run build:$LONG && npm run package:$LONG"
  npm run "build:$LONG"
  npm run "package:$LONG"
elif HAS "package:$LONG"; then
  echo "==> Running: npm run package:$LONG"
  npm run "package:$LONG"
elif HAS "build"; then
  # Generic electron-builder fallback.
  echo "==> Running: npm run build && npx electron-builder"
  npm run build
  case "$PLATFORM" in win) EB="--win";; mac) EB="--mac";; linux) EB="--linux";; esac
  npx --no-install electron-builder "$EB" || npx electron-builder "$EB"
else
  echo "error: no recognized build script (build:$LONG / package:$LONG / build)" >&2
  exit 1
fi

echo "==> Build finished. Looking for artifacts..."
# electron-forge writes to ./out/make; electron-builder would use ./dist.
for d in out/make dist out release; do
  if [[ -d "$d" ]]; then
    echo "---- $d ----"
    find "$d" -maxdepth 4 -type f 2>/dev/null | sort || true
  fi
done
