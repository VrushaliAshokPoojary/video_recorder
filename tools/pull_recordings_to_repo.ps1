param(
  [string]$PackageName = "com.example.video_recorder",
  [string]$Destination = "recordings"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

Write-Host "[1/4] Checking adb device..."
$adb = Get-Command adb -ErrorAction SilentlyContinue
if ($null -eq $adb) {
  $sdkRoot = $env:ANDROID_SDK_ROOT
  if ([string]::IsNullOrWhiteSpace($sdkRoot)) { $sdkRoot = $env:ANDROID_HOME }
  if (-not [string]::IsNullOrWhiteSpace($sdkRoot)) {
    $candidate = Join-Path $sdkRoot "platform-tools\adb.exe"
    if (Test-Path $candidate) { $adb = @{ Source = $candidate } }
  }
}
if ($null -eq $adb) {
  throw "adb not found. Install Android platform-tools and add adb to PATH, or set ANDROID_SDK_ROOT/ANDROID_HOME."
}
$AdbExe = $adb.Source
& $AdbExe get-state | Out-Null

Write-Host "[2/4] Listing files inside app sandbox..."
$filesRaw = & $AdbExe shell "run-as $PackageName ls app_flutter/project_video_exports" 2>$null
$allArchiveFiles = $filesRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
$targetFiles = @('vid_rec.mp4', 'scr_rec.mp4')
$files = $allArchiveFiles | Where-Object { $targetFiles -contains $_ }

if ($files.Count -eq 0 -and $allArchiveFiles.Count -gt 0) {
  # Backward-compatible fallback for older archive naming.
  $files = $allArchiveFiles | Where-Object { $_ -like "exam_*.mp4" }
}

if ($files.Count -eq 0) {
  $filesRaw = & $AdbExe shell "run-as $PackageName ls app_flutter/exam_recordings" 2>$null
  $files = $filesRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -like "compressed_*.mp4" }
  $sourceDir = "app_flutter/exam_recordings"
} else {
  $sourceDir = "app_flutter/project_video_exports"
}

if ($files.Count -eq 0) {
  Write-Host "No recordings found in app_flutter/project_video_exports or app_flutter/exam_recordings for package $PackageName"
  exit 0
}

Write-Host "[3/4] Streaming files directly from app sandbox to repo folder: $Destination"
foreach ($f in $files) {
  $destPath = Join-Path $Destination $f
  $escapedDest = $destPath.Replace('"', '""')
  $cmd = '"{0}" exec-out "run-as {1} cat {2}/{3}" > "{4}"' -f $AdbExe, $PackageName, $sourceDir, $f, $escapedDest
  cmd /c $cmd | Out-Null
  $exitCode = $LASTEXITCODE

  if ($exitCode -eq 0 -and (Test-Path $destPath) -and ((Get-Item $destPath).Length -gt 0)) {
    Write-Host "Saved: $destPath"
  } else {
    if (Test-Path $destPath) { Remove-Item -Force $destPath }
    Write-Host "Failed: $destPath"
  }
}

Write-Host "[4/4] Creating Windows-compatible H.264 copies (if ffmpeg exists)..."
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -ne $ffmpeg) {
  foreach ($f in $files) {
    $in = Join-Path $Destination $f
    if (!(Test-Path $in)) { continue }
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
