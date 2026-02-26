# Exam Proctor Flutter App

A production-oriented Flutter architecture for online examination proctoring with:

- Silent front-camera recording (no preview on exam UI)
- On-device compression (~50% size target by bitrate optimization)
- Secure chunked upload with auth token and retries
- Lifecycle-safe orchestration (pause/resume)

## Project structure

```text
lib/src/
  presentation/exam/   # exam screen + controller
  domain/              # entities, repository contracts, use cases
  data/                # services, datasource, repository implementation
  core/                # DI, config, errors
```

## How stealth recording works

`CameraService` starts front-camera recording using the `camera` plugin but **never exposes** `CameraPreview` to UI. The exam widget tree is independent and remains responsive while recording in background service context.

## Compression approach

`CompressionService` uses `video_compress` to keep original duration and reduce file size by bitrate/frame-rate tuning:

- 30 fps normalization
- 720p compression profile
- 30 fps target
- audio retained for integrity

This achieves temporal compression behavior (same timeline, lower bitrate density), targeting roughly half storage versus raw capture in many device profiles.

## Upload strategy

`UploadService` uploads 2MB chunks with metadata:

- `chunkIndex`, `totalChunks`, `uploadId`
- `Authorization: Bearer <JWT>` header
- retry with linear backoff per chunk

Because chunk upload carries persistent `uploadId`, interrupted transfers can resume from the next missing chunk on server-driven workflows.

## Compliance and legal requirements

For proctoring legality and privacy compliance:

1. Display explicit consent before exam start.
2. Document data retention period and deletion policies.
3. Restrict access to recordings and audit all access events.
4. Follow regional laws (GDPR/CCPA/local education policy).

## Notes

- This repository is a template-style implementation; wire your real backend endpoint and token issuing flow.
- Ensure platform manifests include camera/mic permissions (included examples under `android/` and `ios/`).


## Windows + Android Studio full run guide

See `WINDOWS_ANDROID_STUDIO_SETUP.md` for a step-by-step guide from machine setup and cloning to running, testing, and building on Windows with Android Studio.
