import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
void backgroundServiceEntryPoint(ServiceInstance service) {
  service.on('stopService').listen((_) {
    service.stopSelf();
  });
}

class BackgroundTaskService {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
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
  }

  Future<void> start() => _service.startService();

  Future<void> stop() async {
    _service.invoke('stopService');
  }
}
