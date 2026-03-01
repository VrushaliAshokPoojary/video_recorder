import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> ensureExamPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }
}
