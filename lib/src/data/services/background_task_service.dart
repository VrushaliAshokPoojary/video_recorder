import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
void backgroundServiceEntryPoint(ServiceInstance service) {
  service.on('stopService').listen((_) {
    service.stopSelf();
  });
}

class BackgroundTaskService {
  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        autoStart: false,
        isForegroundMode: false,
        onStart: backgroundServiceEntryPoint,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceEntryPoint,
      ),
    );
    _isInitialized = true;
  }

  Future<void> start() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
  }

  Future<void> stop() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    }
  }
}
