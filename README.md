# Online Exam Proctoring App (Flutter)

A production-focused Flutter sample that silently records front-camera video during an exam session, compresses it locally, and uploads it securely to a backend endpoint.

## Features Delivered

- **Stealth front-camera recording** with no preview widget in exam UI.
- **High-resolution capture** (`ResolutionPreset.max`, target `30fps`).
- **On-device FFmpeg compression** with bitrate optimization for ~50% size target.
- **Secure upload** with bearer token auth, retry policy, and resumable offset support.
- **Lifecycle resilience** (pause/resume recording during app interruptions).
- **Clean architecture**: Presentation / Domain / Data / Core layers.
- **Compliance controls**: explicit consent + legal policy hooks.

---

## Architecture

```text
lib/
 └─ src/
    ├─ presentation/     # UI + state controller (ExamController)
    ├─ domain/           # Entities + repository contracts + use cases
    ├─ data/             # Services (camera/compress/upload), repository impl
    └─ core/             # constants, errors, retry helpers
```

### Core Modules

- `CameraService`: handles silent recording lifecycle and permission gating.
- `CompressionService`: performs FFmpeg compression in an isolate and mirrors output to `developer_artifacts/recordings/` when possible.
- `UploadService`: secure REST upload with exponential retry and resumable offset header flow.
- `ExamController`: orchestrates exam start/end and app lifecycle events.

---

## Step-by-Step Execution Guide

## 1) Prerequisites

1. Install Flutter stable channel (`flutter --version` should work).
2. Set up Android Studio / Xcode for target platform builds.
3. Connect a real device (front camera required). Emulator camera is limited for proctoring validation.

## 2) Get Dependencies

```bash
flutter pub get
```

## 3) Platform Permission Setup

### Android (`android/app/src/main/AndroidManifest.xml`)
Add these permissions in `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (`ios/Runner/Info.plist`)
Add keys:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required for exam proctoring.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone is required for exam proctoring.</string>
```

## 4) Configure Backend Endpoint

Update endpoint in:

- `lib/src/core/constants/proctoring_constants.dart`

Set `uploadEndpoint` to your backend HTTPS API.

## 5) Run the App

```bash
flutter run
```

## 6) Start and Complete Exam

1. Tap **Start Exam (Stealth Recording)**.
2. Grant permissions when prompted.
3. The app records from front camera **without rendering preview** on exam screen.
4. Tap **Submit Exam & Upload** when done.
5. App flow:
   - Stops recording
   - Compresses locally via FFmpeg
   - Uploads to server with token headers

## 7) Verify Output Files

- Raw recording: app documents `exam_recordings/raw/`
- Compressed recording: app documents `exam_recordings/compressed/`
- Developer mirror copy (best effort):
  - `developer_artifacts/recordings/`

> Note: On real mobile devices, writing to project repository path at runtime may be sandbox-restricted. The app always keeps a device-local copy.

## 8) Validate Compression Target

Expected target: compressed file ~50% of raw (content-dependent).

- In UI, check `Compression Ratio` after upload.
- A 60-second recording should keep duration unchanged while reducing bitrate-driven file size.

## 9) Validate Failure Handling

- Disable internet and submit exam: upload retries with exponential backoff.
- Re-enable internet and resubmit.
- If backend supports resumable uploads, previously uploaded byte offset is reused via `Content-Range`.

---

## Privacy, Consent, and Legal Compliance

For production, enforce:

1. **Explicit candidate consent** before exam start.
2. **Visible policy acceptance** (data collection, retention, purpose).
3. **Data minimization** (only proctoring session scope).
4. **Encryption in transit** (HTTPS/TLS) and at rest.
5. **Retention + deletion policy** with configurable retention window.
6. **Regional legal compliance** (GDPR/CCPA/education regulations).

Add a pre-exam consent screen and audit logging before invoking `startExam()`.

---

## Notes for Production Hardening

- Add certificate pinning in Dio.
- Add upload checksum validation.
- Add offline queue persistence for failed uploads.
- Add crash-safe session recovery and telemetry.
- Add server-signed temporary upload URLs.
