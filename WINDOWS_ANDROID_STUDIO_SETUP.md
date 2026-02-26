# Windows + Android Studio Setup and Run Guide

This guide takes you from **fresh machine** to **running the app on an Android device/emulator**.

---

## 1) Prerequisites

Install the following in order:

1. **Git for Windows**
   - Download: https://git-scm.com/download/win
   - During install, keep default options.

2. **Flutter SDK (stable)**
   - Download stable zip: https://docs.flutter.dev/get-started/install/windows/mobile
   - Extract to a path with no spaces, e.g.:
     - `C:\dev\flutter`

3. **Android Studio (latest stable)**
   - Download: https://developer.android.com/studio
   - Install with default options.

4. **VS Code (optional)**
   - Helpful for editing, but Android Studio is enough.

---

## 2) Configure PATH on Windows

Add Flutter and Android tools to PATH.

1. Open **Start → Edit the system environment variables → Environment Variables**.
2. Under **User variables**, edit `Path` and add:
   - `C:\dev\flutter\bin`
   - `%LOCALAPPDATA%\Android\Sdk\platform-tools`
   - `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin` (if exists)
3. Close all terminals and reopen **PowerShell**.

Verify:

```powershell
flutter --version
```

---

## 3) Install Android SDK components in Android Studio

1. Open **Android Studio**.
2. Go to **More Actions → SDK Manager**.
3. In **SDK Platforms**, install one recent Android API (e.g., API 34/35).
4. In **SDK Tools**, install/check:
   - Android SDK Build-Tools
   - Android SDK Command-line Tools (latest)
   - Android SDK Platform-Tools
   - Android Emulator
5. Apply changes and wait for download completion.

---

## 4) Accept Android licenses and run Flutter doctor

In PowerShell:

```powershell
flutter doctor
flutter doctor --android-licenses
flutter doctor
```

You should see green checks for Flutter + Android toolchain.

---

## 5) Clone this repository

```powershell
git clone <YOUR_REPO_URL>
cd video_recorder
```

If your repo URL is private, use the HTTPS/SSH URL from your Git provider.

---

## 6) Open in Android Studio

1. Android Studio → **Open**.
2. Select the `video_recorder` folder.
3. Wait for indexing/Gradle sync.

---

## 7) Install project dependencies

From terminal in project root:

```powershell
flutter clean
flutter pub get
```

This installs all Dart/Flutter dependencies declared in `pubspec.yaml`.

---

## 8) Android permissions and platform checks

This project already contains Android/iOS permission placeholders. For Android, verify these exist in:

- `android/app/src/main/AndroidManifest.xml`
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`
  - foreground service permissions

If you customize package/application IDs, keep those permissions intact.

---

## 9) Create and start Android emulator (or connect device)

### Option A: Emulator

1. Android Studio → **Device Manager**.
2. Create Virtual Device (e.g., Pixel 6).
3. Choose a recent system image.
4. Start emulator.

### Option B: Physical Android device

1. Enable **Developer options** + **USB debugging**.
2. Connect via USB.
3. Accept debugging prompt on device.

Check connected devices:

```powershell
flutter devices
```

---

## 10) Run the app

From project root:

```powershell
flutter run
```

If multiple devices are connected:

```powershell
flutter devices
flutter run -d <device_id>
```

---

## 11) Build release APK (optional)

```powershell
flutter build apk --release
```

Output file:

- `build\app\outputs\flutter-apk\app-release.apk`

---

## 12) Run tests and static analysis

```powershell
flutter analyze
flutter test
```

---

## 13) Common issues and fixes

### A) `flutter` command not found
- PATH not set correctly.
- Reopen terminal after editing PATH.
- Verify `C:\dev\flutter\bin` exists.

### B) Android licenses not accepted
- Run:
  ```powershell
  flutter doctor --android-licenses
  ```

### C) No devices detected
- Start emulator OR reconnect physical device.
- Run:
  ```powershell
  adb devices
  flutter devices
  ```

### D) Gradle/JDK mismatch
- In Android Studio, use bundled JDK (Settings → Build Tools → Gradle).
- Re-run:
  ```powershell
  flutter clean
  flutter pub get
  flutter run
  ```

### E) Camera/mic permission denied during runtime
- Open app settings on device and grant camera/microphone.
- Reinstall app if permission state is permanently denied.

---

### F) Build failed due to deleted Android v1 embedding
- This project is configured for **Flutter Android embedding v2** (`flutterEmbedding=2` in manifest + `MainActivity : FlutterActivity`).
- If you still see this error in your local clone, refresh Android host files:
  ```powershell
  flutter create .
  flutter clean
  flutter pub get
  flutter run
  ```
- If prompted about overwriting Android files, keep the v2 embedding versions.

---

### G) Manifest merger failed for `BackgroundService@exported`
- Cause: your app manifest and `flutter_background_service_android` manifest declare different `android:exported` values for the same service.
- Fix: in `android/app/src/main/AndroidManifest.xml`, add `xmlns:tools` on `<manifest>` and add `tools:replace="android:exported"` on the `BackgroundService` entry.

---

## 14) Proctoring compliance checklist (must do before production)

1. Show **clear consent UI** before exam start.
2. Explain recording purpose, retention period, and deletion policy.
3. Restrict recording access to authorized staff only.
4. Apply region-specific legal controls (GDPR/CCPA/local rules).
5. Store authentication tokens securely and rotate keys.

---

## 15) Quick command checklist

```powershell
# one-time machine setup
flutter doctor
flutter doctor --android-licenses

# project setup
git clone <YOUR_REPO_URL>
cd video_recorder
flutter clean
flutter pub get

# run
flutter devices
flutter run

# quality checks
flutter analyze
flutter test

# release
flutter build apk --release
```
