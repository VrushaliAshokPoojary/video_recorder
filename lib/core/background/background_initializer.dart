import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

/// Initializes a foreground/background service.
///
/// On Android, camera access in full background is heavily restricted by OS
/// policies, so this keeps a foreground service alive to reduce process kills
/// during long exam sessions and lifecycle transitions.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _serviceEntryPoint,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: false,
      foregroundServiceNotificationId: 90210,
      // Avoid requesting explicit foreground service type here because
      // Android 14+ enforces a strict manifest/runtime subset check. If the
      // generated manifest does not declare matching type, app crashes on boot.
      // Integrators can declare service type in AndroidManifest when needed.
      initialNotificationTitle: 'Exam proctoring active',
      initialNotificationContent: 'Session integrity checks are running',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _serviceEntryPoint,
    ),
  );
}

@pragma('vm:entry-point')
void _serviceEntryPoint(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  Timer.periodic(const Duration(seconds: 20), (_) {
    service.invoke('heartbeat', {
      'ts': DateTime.now().toIso8601String(),
    });
  });
}
