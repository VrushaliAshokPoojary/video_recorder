#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.example.video_recorder}"
DEST_DIR="${2:-recordings}"

mkdir -p "$DEST_DIR"

echo "[1/4] Checking adb device..."
adb get-state >/dev/null

echo "[2/4] Listing files inside app sandbox..."
ARCHIVE_FILES=$(adb shell "run-as $PKG ls app_flutter/project_video_exports" 2>/dev/null | tr -d '\r' || true)
FILES=$(printf "%s\n" "$ARCHIVE_FILES" | grep -E "^(vid_rec|scr_rec)\.mp4$" || true)
SOURCE_DIR="app_flutter/project_video_exports"

if [[ -z "$FILES" && -n "$ARCHIVE_FILES" ]]; then
  # Backward-compatible fallback for older archive naming.
  FILES=$(printf "%s\n" "$ARCHIVE_FILES" | grep -E "^exam_.*\.mp4$" || true)
fi

if [[ -z "$FILES" ]]; then
  FILES=$(adb shell "run-as $PKG ls app_flutter/exam_recordings" 2>/dev/null | tr -d '\r' | grep -E '^compressed_.*\.mp4$' || true)
  SOURCE_DIR="app_flutter/exam_recordings"
fi

if [[ -z "$FILES" && "${DISABLE_RAW_FALLBACK:-0}" != "1" ]]; then
  RAW_FILES=$(adb shell "run-as $PKG ls app_flutter/exam_recordings" 2>/dev/null | tr -d '\r' | grep -E '^(raw_|scr_raw_).*\.mp4$' || true)
  if [[ -n "$RAW_FILES" ]]; then
    FILES=$(printf "%s\n" "$RAW_FILES" | tail -n 2)
    SOURCE_DIR="app_flutter/exam_recordings"
    echo "Warning: compressed recordings not found, using raw fallback files."
  fi
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

echo "[4/4] Creating Windows-compatible H.264 outputs (single-copy mode)..."
if command -v ffmpeg >/dev/null 2>&1; then
  keep_originals="${KEEP_ORIGINALS:-0}"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    in="$DEST_DIR/$f"
    [[ -f "$in" ]] || continue
    base="${f%.*}"
    tmp_out="$DEST_DIR/${base}_windows_compatible.tmp.mp4"
    ffmpeg -y -i "$in" -c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.1 -c:a aac -movflags +faststart "$tmp_out" >/dev/null 2>&1 || true
    if [[ -f "$tmp_out" ]]; then
      if [[ "$keep_originals" == "1" ]]; then
        out="$DEST_DIR/${base}_windows_compatible.mp4"
        rm -f "$out"
        mv -f "$tmp_out" "$out"
        echo "Compatible copy: $out"
      else
        rm -f "$in"
        mv -f "$tmp_out" "$in"
        echo "Replaced with compatible version: $in"
      fi
    else
      rm -f "$tmp_out"
      echo "Compatibility transcode failed, keeping original: $in"
    fi
  done <<< "$FILES"
else
  echo "ffmpeg not found. Keeping pulled compressed files as-is."
fi

echo "Done. Play files from $DEST_DIR/."
