# Video Recorder (Exam Proctoring Demo)

A Flutter architecture sample for silent front-camera exam recording with local compression and secure upload.

## Highlights
- Silent/stealth capture controller (`CameraService`) with **no preview widget** shown in exam UI.
- 1080p+ target capture configuration.
- On-device FFmpeg compression tuned for ~50% size reduction via bitrate strategy.
- Chunked/resumable-style upload with retries using Dio + auth token headers.
- Consent and legal notice flow prior to exam start.

## Structure
```
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

## Notes
- Full background camera recording is platform-constrained, especially on iOS. This sample uses a foreground service on Android to improve resilience during lifecycle interruptions.
- Replace `AppConfig.uploadEndpoint` and mock JWT with real backend/auth integration.
