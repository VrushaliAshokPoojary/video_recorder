param(
  [string]$PackageName = "com.example.video_recorder",
  [string]$Destination = "recordings"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

Write-Host "[1/5] Checking adb device..."
adb get-state | Out-Null

Write-Host "[2/5] Listing files inside app sandbox..."
$filesRaw = adb shell "run-as $PackageName ls app_flutter/project_video_exports 2>nul"
$files = $filesRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

if ($files.Count -eq 0) {
  Write-Host "No recordings found in app_flutter/project_video_exports for package $PackageName"
  exit 0
}

Write-Host "[3/5] Copying files to /sdcard/Download for adb pull..."
foreach ($f in $files) {
  adb shell "run-as $PackageName cp app_flutter/project_video_exports/$f /sdcard/Download/$f" | Out-Null
}

Write-Host "[4/5] Pulling files into repo folder: $Destination"
foreach ($f in $files) {
  adb pull "/sdcard/Download/$f" "$Destination/$f" | Out-Null
  Write-Host "Saved: $Destination/$f"
}

Write-Host "[5/5] Creating Windows-compatible H.264 copies (if ffmpeg exists)..."
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -ne $ffmpeg) {
  foreach ($f in $files) {
    $in = Join-Path $Destination $f
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f)
    $out = Join-Path $Destination ("${base}_windows_compatible.mp4")
    ffmpeg -y -i $in -c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.1 -c:a aac -movflags +faststart $out | Out-Null
    if (Test-Path $out) {
      Write-Host "Compatible copy: $out"
    }
  }
} else {
  Write-Host "ffmpeg not found. Install ffmpeg to auto-generate Windows-compatible copies."
}

Write-Host "Done. Play files from $Destination/."
