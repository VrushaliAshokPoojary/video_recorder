# Flutter Exam Proctoring Recorder

This project records front-camera video silently during an exam, compresses it locally, and uploads it to a backend API.

## Current implementation status

Implemented:
- Silent front-camera recording service (`CameraService`)
- On-device compression (`CompressionService`, `video_compress`)
- Upload with retry + resumable offset probe (`UploadService`)
- Session-based exam start (no hardcoded IDs/tokens in UI)
- Consent gate (camera + policy acceptance checkboxes)
- Consent audit API call before recording starts
- Developer/QA docs under `docs/`

## 1) Prerequisites

1. Install Flutter stable and verify:
   ```bash
   flutter --version
   flutter doctor -v
   ```
2. Configure Android Studio/Xcode toolchains.
3. Use a physical device with a front camera.

## 2) Install dependencies

```bash
flutter pub get
```

## 3) Configure platform permissions

### Android (`android/app/src/main/AndroidManifest.xml`)
Required permissions are already included for camera/microphone/network/foreground service.

### iOS (`ios/Runner/Info.plist`)
Camera and microphone usage descriptions are already included.

## 4) Configure runtime API/session values

Pass runtime values with `--dart-define`:

- `UPLOAD_ENDPOINT`
- `CONSENT_AUDIT_ENDPOINT`
- `EXAM_ID`
- `CANDIDATE_ID`
- `AUTH_TOKEN`
- `SESSION_EXPIRY_EPOCH_SECONDS` (optional, unix epoch seconds)
- `PRIVACY_POLICY_URL` (optional, shown to candidates before recording)

Example:

```bash
flutter run \
  --dart-define=UPLOAD_ENDPOINT=https://staging-api.your-domain.com/v1/uploads/exam-video \
  --dart-define=CONSENT_AUDIT_ENDPOINT=https://staging-api.your-domain.com/v1/audit/consent \
  --dart-define=EXAM_ID=EX-2026-001 \
  --dart-define=CANDIDATE_ID=CAND-1001 \
  --dart-define=AUTH_TOKEN=<your-jwt> \
  --dart-define=SESSION_EXPIRY_EPOCH_SECONDS=1767225600 \
  --dart-define=PRIVACY_POLICY_URL=https://your-domain.com/privacy-policy
```

If any required session values are missing, the app blocks exam start and shows guidance.

## 5) Run the app

```bash
flutter run
```

## 6) End-to-end flow

1. Open app.
2. Confirm consent checkboxes.
3. Tap **Start Recording (Stealth)**.
4. Answer exam questions (UI remains responsive, no preview shown).
5. Tap **Stop Recording, Compress & Upload**.
6. App stops recording, compresses video, and uploads to backend.

## 7) Files generated

- Raw recording: app docs `exam_recordings/raw/`
- Compressed recording: app docs `exam_recordings/compressed/`
- Best-effort developer mirror: `developer_artifacts/recordings/`

## 8) Project docs to complete release

- `docs/api_contract.md`
- `docs/manual_qa_checklist.md`
- `docs/compression_validation.md`
- `docs/release_checklist.md`
- `docs/monitoring_kpis.md`

## 9) Production hardening checklist

Before production release, complete:
- Certificate pinning in Dio
- Local video encryption at rest
- Server-side retention/deletion policy
- Real backend `uploadId` life-cycle with idempotent `uploadReference`
- Full automated test suite + CI gates


## Android v1 embedding troubleshooting

If you see `Build failed due to use of deleted Android v1 embedding`, this project already uses v2 embedding (`MainActivity` extends `io.flutter.embedding.android.FlutterActivity` and manifest contains `flutterEmbedding=2`).

Most commonly, this error comes from an outdated plugin still using v1 APIs. This project now uses `video_compress` for on-device compression to avoid legacy embedding paths. After pulling latest changes, run:

```bash
flutter clean
flutter pub get
flutter run
```

If your local pub cache still resolves old plugin versions, run:

```bash
flutter pub cache clean
flutter pub get
```
