import 'dart:io';

import '../services/upload_service.dart';

class ProctoringRemoteDataSource {
  ProctoringRemoteDataSource({required UploadService uploadService}) : _uploadService = uploadService;

  final UploadService _uploadService;

  Future<String> uploadCompressedVideo({
    required String compressedPath,
    required String token,
    required String examId,
    required String candidateId,
    required String uploadId,
  }) {
    return _uploadService.uploadVideo(
      file: File(compressedPath),
      token: token,
      examId: examId,
      candidateId: candidateId,
      uploadId: uploadId,
    );
  }
}
