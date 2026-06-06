#!/usr/bin/env bash
#
# Clone Nextcloud Talk Android, apply Biloop branding, and build an APK.
#
# Usage:
#   scripts/build-android.sh
#
# Environment variables:
#   TALK_ANDROID_REPO  Git URL (default: nextcloud/talk-android on GitHub)
#   TALK_ANDROID_REF   Branch/tag to build (default: master)
#   WORK_DIR           Where to clone the source (default: ./upstream-android)
#   GRADLE_TASK        Gradle assemble task (default: assembleGenericDebug)
#   APPLY_BRANDING     Set to 0 to build vanilla upstream
#
# Builds the "generic" flavor (F-Droid, no Google services) in debug, which is
# signed with the Android debug key and therefore directly installable.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_URL="${TALK_ANDROID_REPO:-https://github.com/nextcloud/talk-android.git}"
REF="${TALK_ANDROID_REF:-master}"
WORK_DIR="${WORK_DIR:-upstream-android}"
GRADLE_TASK="${GRADLE_TASK:-assembleGenericDebug}"

echo "==> Building Nextcloud Talk Android"
echo "    repo: $REPO_URL"
echo "    ref:  $REF"
echo "    task: $GRADLE_TASK"

# --- Fetch source -----------------------------------------------------------
if [[ ! -d "$WORK_DIR/.git" ]]; then
  if ! git clone --depth 1 --branch "$REF" "$REPO_URL" "$WORK_DIR" 2>/dev/null; then
    echo "==> ref '$REF' not found as branch/tag, cloning default branch"
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
  bash "$REPO_ROOT/scripts/apply-branding-android.sh" "$UPSTREAM_ABS"
else
  echo "==> APPLY_BRANDING=0, skipping branding"
fi

# --- Build ------------------------------------------------------------------
chmod +x ./gradlew || true
echo "==> Running: ./gradlew $GRADLE_TASK"
./gradlew --no-daemon --stacktrace "$GRADLE_TASK"

echo "==> Build finished. APK(s):"
find app/build/outputs/apk -type f -name '*.apk' 2>/dev/null | sort || true
