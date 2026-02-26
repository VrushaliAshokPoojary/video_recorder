import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/proctoring_exception.dart';

class PermissionDataSource {
  Future<void> requestRequiredPermissionsOrThrow() async {
    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();

    if (!camera.isGranted || !microphone.isGranted) {
      throw ProctoringException(
        'Camera and microphone permission are required to start the exam.',
      );
    }
  }
}
