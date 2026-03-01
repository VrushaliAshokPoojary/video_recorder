import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';

class UploadService {
  UploadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> uploadWithRetry({
    required String filePath,
    required String examId,
    required String authToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    Object? lastError;

    for (int attempt = 1; attempt <= AppConstants.uploadMaxRetries; attempt++) {
      try {
        await _uploadInChunks(
          filePath: filePath,
          examId: examId,
          authToken: authToken,
          onProgress: onProgress,
        );
        return;
      } catch (error) {
        lastError = error;
        if (attempt == AppConstants.uploadMaxRetries) {
          break;
        }
        await Future<void>.delayed(
          Duration(
            milliseconds: AppConstants.uploadRetryBaseDelay.inMilliseconds * attempt,
          ),
        );
      }
    }

    throw StateError('Upload failed after retries: $lastError');
  }

  /// Chunked upload with Content-Range enables resumable semantics if backend
  /// stores per-range progress.
  Future<void> _uploadInChunks({
    required String filePath,
    required String examId,
    required String authToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final totalBytes = await file.length();
    final chunkSize = AppConstants.defaultUploadChunkSizeBytes;

    var offset = 0;
    while (offset < totalBytes) {
      final end = (offset + chunkSize > totalBytes)
          ? totalBytes
          : offset + chunkSize;
      final stream = file.openRead(offset, end);
      final length = end - offset;

      await _dio.post(
        AppConstants.uploadEndpoint,
        data: stream,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $authToken',
            HttpHeaders.contentTypeHeader: 'video/mp4',
            'X-Exam-Id': examId,
            HttpHeaders.contentLengthHeader: length,
            'Content-Range': 'bytes $offset-${end - 1}/$totalBytes',
          },
        ),
      );

      offset = end;
      onProgress?.call(offset, totalBytes);
    }
  }
}
