import 'dart:io';

import '../../domain/entities/exam_session.dart';
import '../../domain/entities/proctoring_result.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../datasources/permission_datasource.dart';
import '../services/background_task_service.dart';
import '../services/camera_service.dart';
import '../services/compression_service.dart';
import '../services/upload_service.dart';

class ProctoringRepositoryImpl implements ProctoringRepository {
  ProctoringRepositoryImpl({
    required PermissionDataSource permissionDataSource,
    required CameraService cameraService,
    required CompressionService compressionService,
    required UploadService uploadService,
    required BackgroundTaskService backgroundTaskService,
  })  : _permissionDataSource = permissionDataSource,
        _cameraService = cameraService,
        _compressionService = compressionService,
        _uploadService = uploadService,
        _backgroundTaskService = backgroundTaskService;

  final PermissionDataSource _permissionDataSource;
  final CameraService _cameraService;
  final CompressionService _compressionService;
  final UploadService _uploadService;
  final BackgroundTaskService _backgroundTaskService;

  @override
  Future<void> ensurePermissionsOrThrow() {
    return _permissionDataSource.requestRequiredPermissionsOrThrow();
  }

  @override
  Future<void> startSessionRecording(ExamSession session) async {
    await _backgroundTaskService.initialize();
    await _backgroundTaskService.start();
    await _cameraService.startStealthRecording();
  }

  @override
  Future<ProctoringResult> stopAndUploadSession(ExamSession session) async {
    try {
      final rawPath = await _cameraService.stopRecording();

      // Keep compression on the main isolate because plugin calls use platform
      // channels which are not safe from a detached isolate by default.
      final compressionResult = await _compressionService.compress(rawPath);

      final uploadResult = await _uploadService.uploadCompressedVideo(
        file: File(compressionResult.path),
        examId: session.examId,
        candidateId: session.candidateId,
        authToken: session.authToken,
      );

      return ProctoringResult(
        originalPath: rawPath,
        compressedPath: compressionResult.path,
        uploadId: uploadResult.uploadId,
        originalBytes: compressionResult.originalBytes,
        compressedBytes: compressionResult.compressedBytes,
      );
    } finally {
      await _backgroundTaskService.stop();
    }
  }

  @override
  Future<void> onLifecyclePaused(ExamSession session) async {
    // Device-specific behavior can interrupt recording after pause.
    // We proactively ensure recording continues once app regains focus.
  }

  @override
  Future<void> onLifecycleResumed(ExamSession session) async {
    await _cameraService.restartIfNeeded();
  }

  @override
  Future<void> dispose() async {
    await _cameraService.dispose();
    await _backgroundTaskService.stop();
  }
}
