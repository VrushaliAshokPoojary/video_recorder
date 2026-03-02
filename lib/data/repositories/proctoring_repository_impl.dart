import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/background/background_initializer.dart';
import '../../domain/models/exam_session.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../services/camera_service.dart';
import '../services/compression_service.dart';
import '../services/screen_recording_service.dart';
import '../services/upload_service.dart';

class FinalizedVideoResult {
  const FinalizedVideoResult({
    required this.videoArchivePath,
    required this.screenArchivePath,
    this.videoProjectArchivePath,
    this.screenProjectArchivePath,
  });

  final String videoArchivePath;
  final String screenArchivePath;
  final String? videoProjectArchivePath;
  final String? screenProjectArchivePath;
}

class ProctoringRepositoryImpl implements ProctoringRepository {
  ProctoringRepositoryImpl({
    required CameraService cameraService,
    required CompressionService compressionService,
    required UploadService uploadService,
    required ScreenRecordingService screenRecordingService,
  })  : _cameraService = cameraService,
        _compressionService = compressionService,
        _uploadService = uploadService,
        _screenRecordingService = screenRecordingService;

  final CameraService _cameraService;
  final CompressionService _compressionService;
  final UploadService _uploadService;
  final ScreenRecordingService _screenRecordingService;

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
    await Future.wait([
      _cameraService.startRecording(),
      _screenRecordingService.startRecording(),
    ]);

    _session = session;
    _sessionStarted = true;
  }

  Future<FinalizedVideoResult?> stopRecordingAndProcess() async {
    if (!_sessionStarted || _session == null) {
      return null;
    }

    if (!_cameraService.isRecording || !_screenRecordingService.isRecording) {
      return null;
    }

    final results = await Future.wait<String>([
      _cameraService.stopRecording(),
      _screenRecordingService.stopRecording(),
    ]);
    final rawPath = results[0];
    final screenRawPath = results[1];
    final result = await _processCompressedArtifacts(
      rawPath,
      screenRawPath: screenRawPath,
      upload: true,
    );

    _sessionStarted = false;
    _session = null;
    await stopBackgroundProctoringService();

    return result;
  }

  Future<FinalizedVideoResult?> finalizeSessionAndGetSavedPath() async {
    if (!_sessionStarted || _session == null) {
      return null;
    }

    if (_cameraService.isRecording && _screenRecordingService.isRecording) {
      final results = await Future.wait<String>([
        _cameraService.stopRecording(),
        _screenRecordingService.stopRecording(),
      ]);
      final rawPath = results[0];
      final screenRawPath = results[1];
      final result = await _processCompressedArtifacts(
        rawPath,
        screenRawPath: screenRawPath,
        upload: true,
      );
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
    required String screenRawPath,
    required bool upload,
  }) async {
    final compressedVideoPath = await _compressionService.compressForUpload(rawPath);
    final compressedScreenPath = await _compressionService.compressForUpload(screenRawPath);

    final videoArchivePath = await _archiveCompressedVideo(
      compressedVideoPath,
      fileName: 'vid_rec.mp4',
    );
    final screenArchivePath = await _archiveCompressedVideo(
      compressedScreenPath,
      fileName: 'scr_rec.mp4',
    );

    final videoProjectArchivePath = await _archiveToProjectFolderBestEffort(
      videoArchivePath,
      fileName: 'vid_rec.mp4',
    );
    final screenProjectArchivePath = await _archiveToProjectFolderBestEffort(
      screenArchivePath,
      fileName: 'scr_rec.mp4',
    );

    await _deleteIfExists(rawPath);
    await _deleteIfExists(screenRawPath);

    if (upload && _session != null) {
      await _uploadService.uploadCompressedVideo(
        filePath: videoArchivePath,
        session: _session!,
      );
      await _uploadService.uploadCompressedVideo(
        filePath: screenArchivePath,
        session: _session!,
      );
    }

    return FinalizedVideoResult(
      videoArchivePath: videoArchivePath,
      screenArchivePath: screenArchivePath,
      videoProjectArchivePath: videoProjectArchivePath,
      screenProjectArchivePath: screenProjectArchivePath,
    );
  }

  @override
  Future<void> stopSession() async {
    await finalizeSessionAndGetSavedPath();
  }

  Future<String> _archiveCompressedVideo(
    String compressedPath, {
    required String fileName,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory(p.join(appDir.path, 'project_video_exports'));
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }

    final archivedPath = p.join(archiveDir.path, fileName);

    return _copyWithRetry(compressedPath, archivedPath);
  }

  Future<String?> _archiveToProjectFolderBestEffort(
    String compressedPath, {
    required String fileName,
  }) async {
    if (!kDebugMode) return null;

    try {
      final projectDir = Directory(p.join(Directory.current.path, 'recordings'));
      if (!await projectDir.exists()) {
        await projectDir.create(recursive: true);
      }

      final devCopyPath = p.join(projectDir.path, fileName);

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

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> dispose() async {
    await _cameraService.dispose();
  }
}
