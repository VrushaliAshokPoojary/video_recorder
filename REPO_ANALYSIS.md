# Repository Analysis: `video_recorder`

## 1) High-level purpose

This project is a Flutter-based exam proctoring demo that attempts to:

- Run a question-based exam UI.
- Start **front camera recording** + **screen recording** when the exam starts.
- Stop recordings on submit.
- Compress both videos using FFmpeg (including 2x speed-up).
- Upload files in chunks with retries.
- Persist canonical outputs (`vid_rec.mp4`, `scr_rec.mp4`) in app-local storage.
- Optionally copy outputs to repo-local `recordings/` in debug/best-effort mode.

## 2) Architecture and layering

The repo follows a clean-ish layered structure:

- **Presentation** (`lib/presentation`): UI page and controller/state.
- **Domain** (`lib/domain`): session model and repository contract.
- **Data** (`lib/data`): repository implementation + concrete platform services.
- **Core** (`lib/core`): config constants and background initializer stubs.

Flow shape:

1. `ExamPage` creates and listens to `ExamController`.
2. Controller requests permissions and calls repository `startSession`.
3. Repository starts background service (currently no-op), initializes camera, and starts camera + screen capture together.
4. On submit, repository stops both, compresses, archives, uploads, and deletes raw files.

## 3) Runtime working model

### App bootstrap

- Entry point calls `initializeBackgroundService()` then launches `ExamPage`.
- Background initializer functions are currently no-op stubs (explicitly documented).

### Consent and exam UX

- Mandatory consent dialog appears after first frame.
- Exam has 5 questions with Previous/Next pagination.
- Start button only appears on the first page before exam starts.
- Submit button appears on the last page after exam starts.

### Recording pipeline

- Camera: `camera` plugin, front lens preference, `ResolutionPreset.max`, audio enabled.
- Screen: `flutter_screen_recording` start/stop.
- Both are started/stopped as a pair via `Future.wait`.

### Compression and upload

- Compression via `flutter_ffmpeg` with:
  - `setpts=0.5*PTS` (2x speed video),
  - `atempo=2.0` (audio sync),
  - H.264 + AAC output.
- Chunk upload uses `Dio`, custom headers (exam/user/chunk metadata), and retry with linear-ish backoff.

### Storage strategy

- Raw files go to `<app-docs>/exam_recordings/`.
- Compressed canonical outputs archived to `<app-docs>/project_video_exports/`.
- Raw files are deleted after processing.
- Debug best-effort copy to `<repo>/recordings/` is attempted.

## 4) What works well

- Clear end-to-end flow from consent -> record -> compress -> upload -> archive.
- Good separation between UI/controller and infrastructure services.
- Canonical output naming (`vid_rec.mp4`, `scr_rec.mp4`) simplifies evaluation.
- Reasonable upload resilience with retries.
- Pull scripts for macOS/Linux/Windows are practical and include fallback logic.

## 5) Risks / correctness gaps found

1. **Platform permissions are missing in manifests/plists**:
   - AndroidManifest currently has no CAMERA / RECORD_AUDIO declarations.
   - iOS Info.plist currently has no camera/mic usage description keys.
   Without these, runtime permission flow cannot succeed correctly on devices.

2. **Repository partial-stop behavior**:
   - Finalization returns `null` if both camera and screen are not simultaneously recording.
   - A partial-failure scenario could discard salvageable artifact processing.

3. **Upload API assumptions**:
   - Chunk POST uses one endpoint and metadata headers but no file identifier/hash in protocol.
   - Real backend integration likely requires explicit session/file/chunk completion handshake.

4. **Dependency age / maintenance concern**:
   - `flutter_ffmpeg` has ecosystem maintenance concerns and may be hard on recent toolchains.

5. **No automated tests**:
   - No unit/integration tests for controller transitions or repository pipeline behavior.

## 6) Suggested hardening roadmap

Priority order:

1. Add required Android/iOS permission declarations immediately.
2. Add unit tests for `ExamController` and repository state transitions.
3. Introduce resilient finalize logic for partial recording availability.
4. Add upload contract versioning and explicit file/chunk IDs.
5. Consider migration path from `flutter_ffmpeg` if toolchain issues arise.
6. Add telemetry/metrics hooks around compression/upload durations and failures.

## 7) Environment validation result in this workspace

- Flutter SDK is **not installed** in this environment (`flutter: command not found`), so runtime/lint/test execution could not be performed here.
- Analysis is therefore based on static code inspection and repository scripts/configs.
