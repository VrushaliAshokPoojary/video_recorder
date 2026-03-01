# Video Recorder (Online Exam Proctoring)

Production-oriented Flutter scaffold for stealth front-camera recording during an exam session, with local compression and secure upload.

## Implemented Architecture

- `presentation/`: `ExamPage` + `ExamController` (UI orchestration & lifecycle)
- `domain/`: entities + repository contract
- `data/`: repository implementation + modular services:
  - `CameraService`
  - `CompressionService`
  - `UploadService`
  - `PermissionService`

## Key Behaviors

1. **Two-button UI** (`Start Recording` / `Stop Recording`) for manual control.
2. **Automatic exam-start recording** from front camera.
3. **No camera preview shown** to keep exam interface clean.
4. **On-device FFmpeg compression** targeting ~50% bitrate.
5. **Secure upload** with bearer token + chunked resumable semantics + retries.
6. **Lifecycle handling** with best-effort resume on app interruption.

## Setup

```bash
flutter pub get
flutter run
```

## Notes for Real Production Deployment

- Validate camera plugin capabilities on target devices to enforce strict 1080p@30fps.
- Replace mock endpoint in `AppConstants.uploadEndpoint`.
- Align with local legal/privacy rules and show institution-approved consent notices.
- Consider native foreground service implementations for stronger background guarantees.
