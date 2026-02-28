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
- runs via plugin async calls on the main isolate (safe platform channel usage)

This achieves temporal compression behavior (same timeline, lower bitrate density), targeting roughly half storage versus raw capture in many device profiles.

## Upload strategy

`UploadService` uploads 2MB chunks with metadata:

- `chunkIndex`, `totalChunks`, `uploadId`
- `Authorization: Bearer <JWT>` header
- retry with linear backoff per chunk

Because chunk upload carries persistent `uploadId`, interrupted transfers can resume from the next missing chunk on server-driven workflows.

## Compliance and legal requirements

For proctoring legality and privacy compliance:

1. Display explicit consent before exam start (implemented with a mandatory consent checkbox in the exam screen).
2. Document data retention period and deletion policies.
3. Restrict access to recordings and audit all access events.
4. Follow regional laws (GDPR/CCPA/local education policy).

## Notes

- This repository is a template-style implementation; wire your real backend endpoint and token issuing flow.
- Ensure platform manifests include camera/mic permissions (included examples under `android/` and `ios/`).


## Windows + Android Studio full run guide

See `WINDOWS_ANDROID_STUDIO_SETUP.md` for a step-by-step guide from machine setup and cloning to running, testing, and building on Windows with Android Studio.


## Recording file locations

On Android/iOS, the app now creates a dedicated folder tree for easier access:

- Preferred Android location (public): `/storage/emulated/0/Download/video_recorder/`
- Fallback app-private location: `.../Android/data/<package>/files/video_recorder/`
- Raw recordings: `.../video_recorder/raw/raw_<timestamp>.mp4`
- Compressed recordings: `.../video_recorder/compressed/compressed_<timestamp>.mp4`
- Latest compressed alias: `.../video_recorder/compressed/latest_compressed.mp4`
- Upload-ready recordings (preferred submission source): `.../video_recorder/upload_ready/upload_ready_<timestamp>.mp4`
- Latest upload-ready alias: `.../video_recorder/upload_ready/latest_upload_ready.mp4`

`video_compress` may still create its own temporary output internally, but the app always copies final files into `video_recorder/raw`, `video_recorder/compressed`, and `video_recorder/upload_ready`.

You can access them with:

- Directly on device file manager: `Download/video_recorder/`
- In app result text: check `Raw file:` and `Compressed file:` absolute paths after ending exam
- Android Studio Device Explorer (`/storage/emulated/0/Download/video_recorder/` or app files fallback)

If `adb` is not recognized on Windows PowerShell, use Android Studio Device Explorer or run adb using its full path:

- `"$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices`


## Build cache stability (no need to delete `.gradle`/`build` every run)

This repo now ignores local/generated build caches so they do not pollute commits or require manual cleanup each run.

- Added `.gitignore` entries for Flutter/Gradle outputs (`build/`, `android/.gradle/`, etc.).
- Normal workflow: run `flutter pub get` once, then `flutter run` directly.
- Use `flutter clean` only when troubleshooting corrupted caches or dependency/toolchain upgrades.

## Common runtime issues

- If you see *"must be annotated"* for background service callbacks in release/profile builds, ensure the background entry point function is top-level and marked with `@pragma('vm:entry-point')`.
- If compression intermittently fails with `FileSystemException: An async operation is currently pending`, ensure compression is fully awaited before file copy/upload, cancel previous compression jobs before starting a new one, and clean plugin cache after completion.
