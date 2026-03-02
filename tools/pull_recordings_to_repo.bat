@echo off
setlocal
where adb >nul 2>nul
if errorlevel 1 (
  echo adb not found in PATH. Please open Android Studio and install platform-tools, then add adb to PATH.
  echo Or run PowerShell script after setting ANDROID_SDK_ROOT.
  exit /b 1
)
powershell -ExecutionPolicy Bypass -File "%~dp0pull_recordings_to_repo.ps1" %*
