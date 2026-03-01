import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

/// Initializes background service wiring.
///
/// We keep `autoStart` disabled to avoid launching a second Flutter engine at
/// app startup (which can cause jank on lower-end devices). The service is
/// started explicitly when exam recording begins.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _serviceEntryPoint,
      autoStart: false,
      isForegroundMode: true,
      autoStartOnBoot: false,
      foregroundServiceNotificationId: 90210,
      initialNotificationTitle: 'Exam proctoring active',
      initialNotificationContent: 'Session integrity checks are running',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _serviceEntryPoint,
    ),
  );
}

Future<void> startBackgroundProctoringService() async {
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  }
}

Future<void> stopBackgroundProctoringService() async {
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (running) {
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
void _serviceEntryPoint(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 20), (_) {
    service.invoke('heartbeat', {
      'ts': DateTime.now().toIso8601String(),
    });
  });
}
