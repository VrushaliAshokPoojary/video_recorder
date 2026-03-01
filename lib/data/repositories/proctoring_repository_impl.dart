import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/background/background_initializer.dart';
import '../../domain/models/exam_session.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../services/camera_service.dart';
import '../services/compression_service.dart';
import '../services/upload_service.dart';

class ProctoringRepositoryImpl implements ProctoringRepository {
  ProctoringRepositoryImpl({
    required CameraService cameraService,
    required CompressionService compressionService,
    required UploadService uploadService,
  })  : _cameraService = cameraService,
        _compressionService = compressionService,
        _uploadService = uploadService;

  final CameraService _cameraService;
  final CompressionService _compressionService;
  final UploadService _uploadService;

  ExamSession? _session;
  bool _sessionStarted = false;

  @override
  Future<void> startSession(ExamSession session) async {
    if (_sessionStarted) {
      throw StateError('Exam session already started.');
    }

    await startBackgroundProctoringService();
    await _cameraService.initializeFrontCamera();
    await _cameraService.ensureCaptureQuality();
    await _cameraService.startRecording();

    _session = session;
    _sessionStarted = true;
  }

  /// Stops recording, compresses, uploads, and stores a copy in a stable folder.
  ///
  /// Returns saved compressed file path (or null if recording was not active).
  Future<String?> finalizeSessionAndGetSavedPath() async {
    if (!_sessionStarted || _session == null) {
      return null;
    }

    String? rawPath;
    if (_cameraService.isRecording) {
      rawPath = await _cameraService.stopRecording();
    }

    if (rawPath == null) {
      await stopBackgroundProctoringService();
      _sessionStarted = false;
      _session = null;
      return null;
    }

    final compressedPath = await _compressionService.compressForUpload(rawPath);
    final archivedCopyPath = await _archiveCompressedVideo(compressedPath);

    await _uploadService.uploadCompressedVideo(
      filePath: compressedPath,
      session: _session!,
    );

    await stopBackgroundProctoringService();

    _sessionStarted = false;
    _session = null;

    return archivedCopyPath;
  }

  @override
  Future<void> stopSession() async {
    await finalizeSessionAndGetSavedPath();
  }

  Future<String> _archiveCompressedVideo(String compressedPath) async {
    final appDir = await getApplicationDocumentsDirectory();

    // Assignment-aligned local folder where processed videos are retained.
    final archiveDir = Directory(p.join(appDir.path, 'project_video_exports'));
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }

    final archivedPath = p.join(
      archiveDir.path,
      'exam_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    return (await File(compressedPath).copy(archivedPath)).path;
  }

  Future<void> dispose() async {
    await _cameraService.dispose();
  }
}
