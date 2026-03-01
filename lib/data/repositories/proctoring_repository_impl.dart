import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/background/background_initializer.dart';
import '../../domain/models/exam_session.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../services/camera_service.dart';
import '../services/compression_service.dart';
import '../services/upload_service.dart';

class FinalizedVideoResult {
  const FinalizedVideoResult({
    required this.appArchivePath,
    this.projectArchivePath,
  });

  final String appArchivePath;
  final String? projectArchivePath;
}

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

  bool get isSessionStarted => _sessionStarted;

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

  Future<FinalizedVideoResult?> stopRecordingAndProcess() async {
    if (!_sessionStarted || _session == null) {
      return null;
    }

    if (!_cameraService.isRecording) {
      return null;
    }

    final rawPath = await _cameraService.stopRecording();
    final result = await _processCompressedArtifacts(rawPath, upload: true);

    _sessionStarted = false;
    _session = null;
    await stopBackgroundProctoringService();

    return result;
  }

  Future<FinalizedVideoResult?> finalizeSessionAndGetSavedPath() async {
    if (!_sessionStarted || _session == null) {
      return null;
    }

    if (_cameraService.isRecording) {
      final rawPath = await _cameraService.stopRecording();
      final result = await _processCompressedArtifacts(rawPath, upload: true);
      _sessionStarted = false;
      _session = null;
      await stopBackgroundProctoringService();
      return result;
    }

    _sessionStarted = false;
    _session = null;
    await stopBackgroundProctoringService();
    return null;
  }

  Future<FinalizedVideoResult> _processCompressedArtifacts(
    String rawPath, {
    required bool upload,
  }) async {
    final compressedPath = await _compressionService.compressForUpload(rawPath);
    final appArchivePath = await _archiveCompressedVideo(compressedPath);
    final projectArchivePath = await _archiveToProjectFolderBestEffort(
      appArchivePath,
    );

    if (upload && _session != null) {
      await _uploadService.uploadCompressedVideo(
        filePath: appArchivePath,
        session: _session!,
      );
    }

    return FinalizedVideoResult(
      appArchivePath: appArchivePath,
      projectArchivePath: projectArchivePath,
    );
  }

  @override
  Future<void> stopSession() async {
    await finalizeSessionAndGetSavedPath();
  }

  Future<String> _archiveCompressedVideo(String compressedPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory(p.join(appDir.path, 'project_video_exports'));
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }

    final archivedPath = p.join(
      archiveDir.path,
      'exam_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    return _copyWithRetry(compressedPath, archivedPath);
  }

  Future<String?> _archiveToProjectFolderBestEffort(String compressedPath) async {
    if (!kDebugMode) return null;

    try {
      final projectDir = Directory(p.join(Directory.current.path, 'recordings'));
      if (!await projectDir.exists()) {
        await projectDir.create(recursive: true);
      }

      final devCopyPath = p.join(
        projectDir.path,
        'exam_recording_compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      return await _copyWithRetry(compressedPath, devCopyPath);
    } catch (_) {
      // On real devices, project root isn't writable. Keep best-effort only.
      return null;
    }
  }

  Future<String> _copyWithRetry(String fromPath, String toPath) async {
    final source = File(fromPath);
    const maxAttempts = 6;
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        return (await source.copy(toPath)).path;
      } on FileSystemException {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
    throw StateError('Failed to copy file after retry attempts.');
  }

  Future<void> dispose() async {
    await _cameraService.dispose();
  }
}
