# Video Recorder (Exam Proctoring Demo)

A Flutter architecture sample for silent front-camera exam recording with local compression and secure upload.

## Implemented Scope
- Silent/stealth capture controller (`CameraService`) with **no camera preview widget** shown in exam UI.
- 1080p+ target capture validation and 30fps target compression profile.
- On-device compression using `video_compress` (FFmpeg-equivalent workflow) tuned for substantial size reduction before upload.
- Chunked upload with retries using Dio + JWT bearer header.
- Consent and legal notice flow prior to exam start.

## Architecture
```text
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

### 4) Configure Android Permissions and Service
Update `android/app/src/main/AndroidManifest.xml`:
- Required permissions:
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_CAMERA`
  - Storage permissions based on target SDK strategy
- Register background service if needed by plugin docs.

Also ensure:
- `minSdkVersion` and Gradle settings satisfy `camera`, `video_compress`, and `flutter_background_service` plugin requirements.
- If you explicitly configure camera foreground service types in Dart/runtime, declare matching service metadata in `AndroidManifest.xml` (e.g., `android:foregroundServiceType="camera"` on the background service entry) to avoid Android 14+ subset-check crashes.

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
3. Tap **Start Recording**.
4. Verify no camera preview appears on exam UI.
5. Answer text input while recording (UI should remain responsive).
6. Tap **Stop Recording**.
7. Verify status transitions indicate compression then upload.
8. Validate output in app documents directory `exam_recordings/`.

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
