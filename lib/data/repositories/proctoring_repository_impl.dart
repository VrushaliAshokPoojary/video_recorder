import 'dart:async';
import 'dart:isolate';

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

    await _cameraService.initializeFrontCamera();
    await _cameraService.ensureCaptureQuality();
    await _cameraService.startRecording();

    _session = session;
    _sessionStarted = true;
  }

  @override
  Future<void> stopSession() async {
    if (!_sessionStarted || _session == null) {
      return;
    }

    final rawPath = await _cameraService.stopRecording();

    // Heavy media processing is pushed to a worker isolate so the exam screen
    // remains responsive and user input latency stays low.
    final compressedPath = await Isolate.run(
      () => _compressionService.compressForUpload(rawPath),
    );

    await Isolate.run(
      () => _uploadService.uploadCompressedVideo(
        filePath: compressedPath,
        session: _session!,
      ),
    );

    _sessionStarted = false;
    _session = null;
  }

  Future<void> dispose() async {
    await _cameraService.dispose();
  }
}
