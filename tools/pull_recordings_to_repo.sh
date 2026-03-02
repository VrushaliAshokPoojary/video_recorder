#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.example.video_recorder}"
DEST_DIR="${2:-recordings}"

mkdir -p "$DEST_DIR"

echo "[1/5] Checking adb device..."
adb get-state >/dev/null

echo "[2/5] Listing files inside app sandbox..."
FILES=$(adb shell "run-as $PKG ls app_flutter/project_video_exports 2>/dev/null" | tr -d '\r' || true)

if [[ -z "$FILES" ]]; then
  echo "No recordings found in app_flutter/project_video_exports for package $PKG"
  exit 0
fi

echo "[3/5] Copying files to /sdcard/Download for adb pull..."
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  adb shell "run-as $PKG cp app_flutter/project_video_exports/$f /sdcard/Download/$f"
done <<< "$FILES"

echo "[4/5] Pulling files into repo folder: $DEST_DIR"
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  adb pull "/sdcard/Download/$f" "$DEST_DIR/$f" >/dev/null
  echo "Saved: $DEST_DIR/$f"
done <<< "$FILES"

echo "[5/5] Creating Windows-compatible H.264 copies (if ffmpeg exists)..."
if command -v ffmpeg >/dev/null 2>&1; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    in="$DEST_DIR/$f"
    base="${f%.*}"
    out="$DEST_DIR/${base}_windows_compatible.mp4"
    ffmpeg -y -i "$in" -c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.1 -c:a aac -movflags +faststart "$out" >/dev/null 2>&1 || true
    if [[ -f "$out" ]]; then
      echo "Compatible copy: $out"
    fi
  done <<< "$FILES"
else
  echo "ffmpeg not found. Install ffmpeg to auto-generate Windows-compatible copies."
fi

echo "Done. Play files from $DEST_DIR/."
