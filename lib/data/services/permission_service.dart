import 'package:permission_handler/permission_handler.dart';

class PermissionCheckResult {
  const PermissionCheckResult({
    required this.allGranted,
    required this.permanentlyDenied,
    required this.deniedPermissions,
  });

  final bool allGranted;
  final bool permanentlyDenied;
  final List<Permission> deniedPermissions;
}

class PermissionService {
  Future<PermissionCheckResult> ensureExamPermissions() async {
    // We intentionally avoid requesting legacy storage permission here because
    // recordings are written inside app-scoped directories.
    // Requesting storage on newer Android versions can return denied and block
    // exam start unnecessarily.
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final denied = <Permission>[];
    var hasPermanentDenial = false;

    for (final entry in statuses.entries) {
      final status = entry.value;
      if (!status.isGranted) {
        denied.add(entry.key);
      }
      if (status.isPermanentlyDenied) {
        hasPermanentDenial = true;
      }
    }

    return PermissionCheckResult(
      allGranted: denied.isEmpty,
      permanentlyDenied: hasPermanentDenial,
      deniedPermissions: denied,
    );
  }

  Future<bool> openPermissionSettings() {
    return openAppSettings();
  }
}
