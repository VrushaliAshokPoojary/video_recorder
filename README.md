# Video Recorder (Exam Proctoring Demo)

A Flutter architecture sample for silent front-camera exam recording with local compression and secure upload.

## Implemented Scope
- Silent/stealth capture controller (`CameraService`) with **no camera preview widget** shown in exam UI.
- Simultaneous screen recording starts/stops with webcam recording on exam start/submit.
- 1080p+ target capture validation and 30fps target compression profile (orientation-safe long-edge/short-edge checks to avoid false failures on portrait devices).
- On-device FFmpeg compression applies a 2x playback speed-up (full-content fast-forward) with synchronized audio/video before upload.
- Chunked upload with retries using Dio + JWT bearer header.
- On submit, compressed webcam + compressed screen copies are archived to app local folder `project_video_exports/`.
- Consent appears as a mandatory popup dialog; once accepted, it disappears and only exam UI remains visible.
- Exam uses pagination with one question per page, Previous/Next navigation, and submission on the last page.
- Runtime permission flow requests only camera + microphone (no legacy storage permission), reducing false denials on modern Android versions.

## Architecture
```text
recordings/
  .gitkeep
lib/
  core/
    background/background_initializer.dart
    config/app_config.dart
  data/
    repositories/proctoring_repository_impl.dart
    services/
      camera_service.dart
      compression_service.dart
      permission_service.dart
      screen_recording_service.dart
      upload_service.dart
  domain/
    models/exam_session.dart
    repositories/proctoring_repository.dart
  presentation/
    controllers/exam_controller.dart
    pages/exam_page.dart
```

## Project Run & Execution Guidelines

### 1) Prerequisites
Install the following locally:
- Flutter stable (3.22+ recommended)
- Dart SDK (bundled with Flutter)
- Android Studio + Android SDK / Xcode (for iOS)
- Java 17 (for modern Android Gradle toolchains)

Verify setup:
```bash
flutter --version
flutter doctor -v
```

### 2) Get Dependencies
From project root:
```bash
flutter pub get
```

### 3) Add Platform Folders (if missing)
This repository currently contains Dart source only. If `android/` and `ios/` do not exist, generate them:
```bash
flutter create .
```

> Re-run `flutter pub get` after generation.

### 4) Configure Android Permissions
Update `android/app/src/main/AndroidManifest.xml`:
- Required permissions:
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`

Also ensure:
- `minSdkVersion` and Gradle settings satisfy plugin requirements (`camera`, `flutter_screen_recording`, `flutter_ffmpeg`).

### 5) Configure iOS Permissions
Update `ios/Runner/Info.plist` with human-readable usage descriptions:
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- If saving outside app documents, include relevant photo-library/storage keys.

### 6) Run in Debug Mode
```bash
flutter run
```
Choose a **physical device** for real camera tests.

### 7) Production Build Commands
Android APK:
```bash
flutter build apk --release
```
Android App Bundle:
```bash
flutter build appbundle --release
```
iOS:
```bash
flutter build ios --release
```

### 8) Runtime Flow Validation Checklist
1. Launch app.
2. Accept consent checkbox.
3. Tap **Start Exam** on the first question page (recording starts automatically).
4. Verify no camera preview appears on exam UI.
5. Answer text input while recording (UI should remain responsive).
6. Navigate with **Previous/Next** and tap **End & Submit Exam** on the last page.
7. Verify status transitions indicate compression then upload.
8. Validate output in app documents directory `project_video_exports/` and (debug best-effort) `<project_root>/recordings/`.


### Saved Video Locations
- Raw webcam recording (temporary): `<AppDocuments>/exam_recordings/raw_<timestamp>.mp4`
- Raw screen recording (temporary): `<AppDocuments>/exam_recordings/scr_raw_<timestamp>.mp4`
- Final archived webcam copy (compressed, always): `<AppDocuments>/project_video_exports/vid_rec.mp4`
- Final archived screen copy (compressed, always): `<AppDocuments>/project_video_exports/scr_rec.mp4`
- Raw files are deleted after processing; only processed/compressed outputs are retained in archive folders.
- Development best-effort copies: `<project_root>/recordings/vid_rec.mp4` and `<project_root>/recordings/scr_rec.mp4`
  - Note: on physical phones this host project path is usually not writable; app-local archive remains authoritative.


### Automatic copy to this repo (recommended for assignment evaluation)
After you submit the exam on device:

**macOS/Linux**
```bash
./tools/pull_recordings_to_repo.sh
```

**Windows PowerShell**
```powershell
.\tools\pull_recordings_to_repo.ps1
```

**Windows CMD**
```cmd
tools\pull_recordings_to_repo.bat
```

This pulls files from app storage (`project_video_exports`) into your repository `recordings/` folder.
The pull scripts prioritize canonical outputs `vid_rec.mp4` and `scr_rec.mp4`; they only fall back to legacy `exam_*.mp4` files when canonical files are absent.
If `ffmpeg` is installed on your machine, the script also creates `*_windows_compatible.mp4` files using H.264 + AAC (`yuv420p`) for broad Windows Media Player compatibility.

If your package name is custom:
```powershell
.\tools\pull_recordings_to_repo.ps1 -PackageName your.package.name
```

### How to access recordings quickly (Windows)
1. Complete exam and tap **End & Submit Exam**.
2. Run:
   ```powershell
   .\tools\pull_recordings_to_repo.ps1
   ```
3. Open `recordings/` in this repo and play the generated `.mp4`.
4. If available, prefer `*_windows_compatible.mp4` for Windows Media Player.

### 9) Endpoint Wiring (Required Before Production)
Update `AppConfig.uploadEndpoint` and replace mock JWT/session values with real auth/session data:
- `lib/core/config/app_config.dart`
- `lib/presentation/controllers/exam_controller.dart`

### 10) Recommended CI Checks
Run before merge:
```bash
flutter format .
flutter analyze
flutter test
```

## Operational Notes
- Full background camera behavior is constrained by platform policies, especially iOS.
- For exam integrity: pair this client with backend heartbeat/session attestation.
- Test on target low/mid-tier hardware for thermals and battery impact.

## Compliance & Legal Usage
This app must only be used in environments with explicit legal authorization and informed consent.
Recommended controls:
- clear purpose disclosure,
- retention/deletion policy,
- jurisdiction-specific legal review,
- secure transit/storage and strict access controls.


## Troubleshooting
- If app does not install, run: `flutter clean && flutter pub get` then uninstall old app from device and retry `flutter run`.
- If install still fails, verify device storage, USB debugging trust dialog, and `adb devices` visibility.
- If script says `adb not recognized`, install Android Platform-Tools and either add `adb` to PATH or set `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) so scripts can locate `platform-tools/adb`.
- If PowerShell showed `/system/bin/sh: can't create nul`, use the updated script (this is fixed by handling stderr on Windows side rather than Android shell redirection).
- If older script showed `cp ... Permission denied` while copying to `/sdcard/Download`, use the updated scripts; they now stream directly from app sandbox to your repo folder (no `/sdcard` copy step).
- Vendor logs like `gralloc4: Empty SMPTE 2094-40 data` are common device/driver noise and not usually fatal by themselves.
