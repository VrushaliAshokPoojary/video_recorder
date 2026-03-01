import 'dart:io';

import '../../domain/entities/exam_session.dart';
import '../../domain/entities/proctoring_result.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../datasources/proctoring_remote_data_source.dart';
import '../services/camera_service.dart';
import '../services/compression_service.dart';

class ProctoringRepositoryImpl implements ProctoringRepository {
  ProctoringRepositoryImpl({
    required CameraService cameraService,
    required CompressionService compressionService,
    required ProctoringRemoteDataSource remoteDataSource,
  })  : _cameraService = cameraService,
        _compressionService = compressionService,
        _remoteDataSource = remoteDataSource;

  final CameraService _cameraService;
  final CompressionService _compressionService;
  final ProctoringRemoteDataSource _remoteDataSource;

  @override
  Future<void> startStealthRecording(ExamSession session) {
    return _cameraService.startSilentRecording();
  }

  @override
  Future<ProctoringResult> endExamAndUpload(ExamSession session) async {
    final rawPath = await _cameraService.stopRecordingAndPersist();
    final rawSize = await File(rawPath).length();

    final compressed = await _compressionService.compressForUpload(rawPath);

    final ref = await _remoteDataSource.uploadCompressedVideo(
      compressedPath: compressed.outputPath,
      token: session.authToken,
      examId: session.examId,
      candidateId: session.candidateId,
      uploadId: session.uploadId,
    );

    return ProctoringResult(
      rawVideoPath: rawPath,
      compressedVideoPath: compressed.outputPath,
      rawSizeBytes: rawSize,
      compressedSizeBytes: compressed.outputSize,
      uploadReference: ref,
    );
  }
}
