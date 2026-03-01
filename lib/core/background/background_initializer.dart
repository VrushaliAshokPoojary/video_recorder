/// Background service bootstrap is intentionally a no-op in this sample.
///
/// Why:
/// - On some Android devices/ROMs, `flutter_background_service` may spawn a
///   secondary Flutter engine that can produce isolate/plugin warnings and
///   lifecycle crashes (as seen in runtime logs).
/// - Core exam recording flow already works while app stays in foreground.
///
/// Production apps can replace this with a platform-specific foreground service
/// implementation after validating manifest + OEM behavior.
Future<void> initializeBackgroundService() async {}

Future<void> startBackgroundProctoringService() async {}

Future<void> stopBackgroundProctoringService() async {}
