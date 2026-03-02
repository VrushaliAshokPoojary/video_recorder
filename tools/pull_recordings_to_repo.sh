#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.example.video_recorder}"
DEST_DIR="${2:-recordings}"

mkdir -p "$DEST_DIR"

echo "[1/4] Checking adb device..."
adb get-state >/dev/null

echo "[2/4] Listing files inside app sandbox..."
FILES=$(adb shell "run-as $PKG ls app_flutter/project_video_exports" 2>/dev/null | tr -d '\r' || true)
SOURCE_DIR="app_flutter/project_video_exports"

if [[ -z "$FILES" ]]; then
  FILES=$(adb shell "run-as $PKG ls app_flutter/exam_recordings" 2>/dev/null | tr -d '\r' | grep -E '^compressed_.*\.mp4$' || true)
  SOURCE_DIR="app_flutter/exam_recordings"
fi

if [[ -z "$FILES" ]]; then
  echo "No recordings found in app_flutter/project_video_exports or app_flutter/exam_recordings for package $PKG"
  exit 0
fi

echo "[3/4] Streaming files directly from app sandbox to repo folder: $DEST_DIR"
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  out="$DEST_DIR/$f"
  adb exec-out "run-as $PKG cat $SOURCE_DIR/$f" > "$out" || true
  if [[ -s "$out" ]]; then
    echo "Saved: $out"
  else
    rm -f "$out"
    echo "Failed: $out"
  fi
done <<< "$FILES"

echo "[4/4] Creating Windows-compatible H.264 copies (if ffmpeg exists)..."
if command -v ffmpeg >/dev/null 2>&1; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    in="$DEST_DIR/$f"
    [[ -f "$in" ]] || continue
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
