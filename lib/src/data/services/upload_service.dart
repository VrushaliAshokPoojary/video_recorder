import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/proctoring_exception.dart';

class UploadResponse {
  const UploadResponse({required this.uploadId});

  final String uploadId;
}

class UploadService {
  UploadService(this._dio);

  final Dio _dio;

  /// Uploads compressed video using chunked requests.
  ///
  /// Chunking gives resumable behavior: if a network failure occurs,
  /// remaining chunks can continue on retry from the last confirmed index.
  Future<UploadResponse> uploadCompressedVideo({
    required File file,
    required String examId,
    required String candidateId,
    required String authToken,
  }) async {
    final total = await file.length();
    if (total <= 0) {
      throw ProctoringException('Compressed recording is empty.');
    }

    const chunkSize = 2 * 1024 * 1024;
    final chunks = (total / chunkSize).ceil();

    String? uploadId;

    for (var i = 0; i < chunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize) > total ? total : start + chunkSize;
      final length = end - start;
      final chunkBytes = await _readChunk(file, start, length);

      final response = await _executeWithRetry(
        () {
          final formData = FormData.fromMap({
            'examId': examId,
            'candidateId': candidateId,
            'chunkIndex': i,
            'totalChunks': chunks,
            'uploadId': uploadId,
            'videoChunk': MultipartFile.fromBytes(
              chunkBytes,
              filename: 'chunk_$i.bin',
            ),
          });

          return _dio.post<Map<String, dynamic>>(
            AppConfig.uploadEndpoint,
            data: formData,
            options: Options(
              headers: {
                HttpHeaders.authorizationHeader: 'Bearer $authToken',
              },
            ),
          );
        },
      );

      final data = response.data;
      if (data == null) {
        throw ProctoringException('Upload API returned empty response.');
      }
      uploadId = data['uploadId'] as String? ?? uploadId;
    }

    if (uploadId == null) {
      throw ProctoringException('Upload did not return an uploadId.');
    }

    return UploadResponse(uploadId: uploadId);
  }

  Future<List<int>> _readChunk(File file, int start, int length) async {
    final access = await file.open();
    try {
      await access.setPosition(start);
      return access.read(length);
    } finally {
      await access.close();
    }
  }

  Future<Response<T>> _executeWithRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await request();
      } on DioException catch (e) {
        final shouldRetry = attempt < AppConfig.maxUploadRetries;
        if (!shouldRetry) {
          throw ProctoringException('Upload failed after retries: ${e.message}');
        }
        await Future<void>.delayed(
          AppConfig.retryBackoff * attempt,
        );
      }
    }
  }
}
