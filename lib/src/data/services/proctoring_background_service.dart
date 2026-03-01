import 'package:flutter_background_service/flutter_background_service.dart';

/// Optional background bootstrap for long-running exam sessions.
///
/// Recording itself is controlled by [CameraService], but this service can be
/// used to keep orchestration alive when app is backgrounded.
class ProctoringBackgroundService {
  Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false,
      ),
    );
  }
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) {
  // Keep lightweight. Heavy work stays in camera/ffmpeg processes.
}
