import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/recording_session.dart';
import '../../domain/repositories/exam_proctoring_repository.dart';
import '../services/camera_service.dart';
import '../services/compression_service.dart';
import '../services/permission_service.dart';
import '../services/upload_service.dart';

class ExamProctoringRepositoryImpl implements ExamProctoringRepository {
  ExamProctoringRepositoryImpl({
    CameraService? cameraService,
    CompressionService? compressionService,
    UploadService? uploadService,
    PermissionService? permissionService,
    FlutterSecureStorage? secureStorage,
  })  : _cameraService = cameraService ?? CameraService(),
        _compressionService = compressionService ?? CompressionService(),
        _uploadService = uploadService ?? UploadService(),
        _permissionService = permissionService ?? PermissionService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final CameraService _cameraService;
  final CompressionService _compressionService;
  final UploadService _uploadService;
  final PermissionService _permissionService;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<bool> ensurePermissions() => _permissionService.ensureRequiredPermissions();

  @override
  Future<RecordingSession> startExamRecording({required String examId}) async {
    await _cameraService.initialize();
    final outputPath = await _cameraService.startRecording(examId: examId);
    return RecordingSession(
      examId: examId,
      rawVideoPath: outputPath,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<RecordingSession> stopExamRecording({
    required String examId,
    required String outputPath,
  }) async {
    final path = await _cameraService.stopRecording(fallbackPath: outputPath);
    return RecordingSession(
      examId: examId,
      rawVideoPath: path,
      endedAt: DateTime.now(),
    );
  }

  @override
  Future<RecordingSession> compressRecording(RecordingSession session) async {
    final compressed = await _compressionService.compressVideo(
      session.rawVideoPath,
      examId: session.examId,
    );
    return session.copyWith(compressedVideoPath: compressed);
  }

  @override
  Future<void> uploadRecording({
    required RecordingSession session,
    required String authToken,
  }) async {
    final uploadPath = session.compressedVideoPath ?? session.rawVideoPath;
    await _uploadService.uploadWithRetry(
      filePath: uploadPath,
      examId: session.examId,
      authToken: authToken,
    );
  }

  Future<String?> getStoredToken() {
    return _secureStorage.read(key: 'jwt_token');
  }

  Future<void> saveToken(String token) {
    return _secureStorage.write(key: 'jwt_token', value: token);
  }

  @override
  Future<void> dispose() => _cameraService.dispose();
}
