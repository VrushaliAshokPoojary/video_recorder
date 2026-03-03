param(
  [string]$PackageName = "com.example.video_recorder",
  [string]$Destination = "recordings",
  [switch]$KeepOriginals,
  [switch]$AllowRawFallback
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

function Get-RunAsListing {
  param(
    [string]$AdbExe,
    [string]$PackageName,
    [string]$RelativeDir
  )

  $checkCmd = "run-as $PackageName sh -c 'if [ -d $RelativeDir ]; then echo EXISTS; fi'"
  $exists = (& $AdbExe shell $checkCmd 2>$null | Out-String).Trim()
  if ($exists -ne "EXISTS") {
    return @()
  }

  $listCmd = "run-as $PackageName ls $RelativeDir"
  $raw = (& $AdbExe shell $listCmd 2>$null | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }

  return $raw -split "`n" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }
}

function Get-PreferredRecordingFiles {
  param(
    [string]$AdbExe,
    [string]$PackageName
  )

  $projectExports = Get-RunAsListing -AdbExe $AdbExe -PackageName $PackageName -RelativeDir "app_flutter/project_video_exports"
  $primary = $projectExports | Where-Object { $_ -match '^(vid_rec|scr_rec)\.mp4$' }
  if ($primary.Count -gt 0) {
    return [PSCustomObject]@{
      SourceDir = "app_flutter/project_video_exports"
      Files = $primary | Sort-Object -Unique
    }
  }

  $examRecordings = Get-RunAsListing -AdbExe $AdbExe -PackageName $PackageName -RelativeDir "app_flutter/exam_recordings"
  $compressed = $examRecordings | Where-Object { $_ -match '^compressed_.*\.mp4$' } | Sort-Object
  if ($compressed.Count -gt 0) {
    $selected = @()
    if ($compressed.Count -ge 2) {
      $selected = $compressed[-2..-1]
    } else {
      $selected = $compressed
    }

    return [PSCustomObject]@{
      SourceDir = "app_flutter/exam_recordings"
      Files = $selected
    }
  }

  if ($AllowRawFallback) {
    # Optional debug fallback: if compression failed and only raw files exist,
    # pull the latest raw pair so recordings can still be inspected.
    $raw = $examRecordings | Where-Object { $_ -match '^(raw_|scr_raw_).*\.mp4$' } | Sort-Object
    if ($raw.Count -gt 0) {
      $selectedRaw = @()
      if ($raw.Count -ge 2) {
        $selectedRaw = $raw[-2..-1]
      } else {
        $selectedRaw = $raw
      }

      return [PSCustomObject]@{
        SourceDir = "app_flutter/exam_recordings"
        Files = $selectedRaw
        IsRawFallback = $true
      }
    }
  }

  return $null
}

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

Write-Host "[2/4] Discovering compressed .mp4 files inside app sandbox..."
$probe = & $AdbExe shell "run-as $PackageName true" 2>&1
$probeText = ($probe | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $probeText -match "run-as:" -or $probeText -match "not debuggable" -or $probeText -match "Package '$PackageName' is unknown") {
  Write-Host "Package is not debuggable or not installed."
  exit 0
}

$selection = Get-PreferredRecordingFiles -AdbExe $AdbExe -PackageName $PackageName
if ($null -eq $selection -or $selection.Files.Count -eq 0) {
  Write-Host "No compressed recordings found in app_flutter/project_video_exports or app_flutter/exam_recordings."
  Write-Host "If you need raw debug pulls, rerun with -AllowRawFallback."
  exit 0
}

$files = $selection.Files
$sourceDir = $selection.SourceDir
Write-Host "Using source dir: $sourceDir"
if ($selection.PSObject.Properties.Name -contains 'IsRawFallback' -and $selection.IsRawFallback) {
  Write-Host "Warning: using raw fallback files because compressed outputs were not found (compression may have failed)."
}

Write-Host "[3/4] Streaming files directly from app sandbox to repo folder: $Destination"
$pulledFiles = @()
foreach ($relativePath in $files) {
  $fileName = [System.IO.Path]::GetFileName($relativePath)
  if ([string]::IsNullOrWhiteSpace($fileName)) { continue }

  $destPath = Join-Path $Destination $fileName
  $escapedDest = $destPath.Replace('"', '""')
  $remotePath = "$sourceDir/$relativePath"
  $escapedRemote = $remotePath.Replace('"', '\"')

  $cmd = '"{0}" exec-out "run-as {1} cat \"{2}\"" > "{3}"' -f $AdbExe, $PackageName, $escapedRemote, $escapedDest
  cmd /c $cmd | Out-Null
  $exitCode = $LASTEXITCODE

  if ($exitCode -eq 0 -and (Test-Path $destPath) -and ((Get-Item $destPath).Length -gt 0)) {
    Write-Host "Saved: $destPath"
    $pulledFiles += $fileName
  } else {
    if (Test-Path $destPath) { Remove-Item -Force $destPath }
    Write-Host "Failed: $destPath"
  }
}

if ($pulledFiles.Count -eq 0) {
  Write-Host "No recordings found inside app sandbox."
  exit 0
}

Write-Host "[4/4] Creating Windows-compatible H.264 outputs (single-copy mode)..."
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($null -ne $ffmpeg) {
  foreach ($f in $pulledFiles) {
    $in = Join-Path $Destination $f
    if (!(Test-Path $in)) { continue }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f)
    $tempOut = Join-Path $Destination ("${base}_windows_compatible.tmp.mp4")
    ffmpeg -y -i $in -c:v libx264 -pix_fmt yuv420p -profile:v high -level 4.1 -c:a aac -movflags +faststart $tempOut | Out-Null
    if (Test-Path $tempOut) {
      if ($KeepOriginals) {
        $out = Join-Path $Destination ("${base}_windows_compatible.mp4")
        if (Test-Path $out) { Remove-Item -Force $out }
        Move-Item -Force $tempOut $out
        Write-Host "Compatible copy: $out"
      } else {
        Remove-Item -Force $in
        Move-Item -Force $tempOut $in
        Write-Host "Replaced with compatible version: $in"
      }
    } else {
      if (Test-Path $tempOut) { Remove-Item -Force $tempOut }
      Write-Host "Compatibility transcode failed, keeping original: $in"
    }
  }
} else {
  Write-Host "ffmpeg not found. Keeping pulled compressed files as-is."
}

Write-Host "Done. Play files from $Destination/."
