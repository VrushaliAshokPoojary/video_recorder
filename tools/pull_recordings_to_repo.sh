#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.example.video_recorder}"
DEST_DIR="${2:-recordings}"

mkdir -p "$DEST_DIR"

echo "[1/4] Checking adb device..."
adb get-state >/dev/null

echo "[2/4] Listing files inside app sandbox..."
FILES=$(adb shell "run-as $PKG ls app_flutter/project_video_exports 2>/dev/null" | tr -d '\r' || true)

if [[ -z "$FILES" ]]; then
  echo "No recordings found in app_flutter/project_video_exports for package $PKG"
  exit 0
fi

echo "[3/4] Copying files to /sdcard/Download for adb pull..."
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  adb shell "run-as $PKG cp app_flutter/project_video_exports/$f /sdcard/Download/$f"
done <<< "$FILES"

echo "[4/4] Pulling files into repo folder: $DEST_DIR"
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  adb pull "/sdcard/Download/$f" "$DEST_DIR/$f" >/dev/null
  echo "Saved: $DEST_DIR/$f"
done <<< "$FILES"

echo "Done. You can now play videos directly from $DEST_DIR/."
