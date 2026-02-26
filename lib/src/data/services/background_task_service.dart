import 'dart:isolate';

import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundTaskService {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        isForegroundMode: false,
        onStart: _onStart,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );
  }

  Future<void> start() => _service.startService();

  Future<void> stop() async {
    await _service.invoke('stopService');
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    // Intentionally lightweight. The main CPU-heavy task (compression) is
    // offloaded to an isolate from the repository layer.
    service.on('stopService').listen((_) {
      service.stopSelf();
    });

    Isolate.current.addOnExitListener(
      RawReceivePort((_) {}).sendPort,
    );
  }
}
