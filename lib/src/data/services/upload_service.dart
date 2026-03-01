import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/proctoring_constants.dart';
import '../../core/errors/proctoring_exception.dart';
import '../../core/utils/retry_policy.dart';

class UploadService {
  UploadService(this._dio);

  final Dio _dio;

  Future<String> uploadVideo({
    required File file,
    required String token,
    required String examId,
    required String candidateId,
    required String uploadId,
  }) async {
    final totalBytes = await file.length();
    // HEAD probe asks server where to resume so uploads can continue after interruptions.
    final uploaded = await _queryUploadedBytes(uploadId, token);

    return withRetry(
      action: () async {
        final stream = file.openRead(uploaded, totalBytes);
        final response = await _dio.post<Map<String, dynamic>>(
          ProctoringConstants.uploadEndpoint,
          data: stream,
          options: Options(
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'video/mp4',
              'X-Exam-Id': examId,
              'X-Candidate-Id': candidateId,
              HttpHeaders.contentLengthHeader: (totalBytes - uploaded).toString(),
              if (uploaded > 0) 'Content-Range': 'bytes $uploaded-${totalBytes - 1}/$totalBytes',
            },
          ),
        );

        if ((response.statusCode ?? 500) >= 400) {
          throw ProctoringException('Upload failed with status ${response.statusCode}');
        }

        final uploadReference = response.data?['uploadReference'] as String?;
        if (uploadReference == null || uploadReference.isEmpty) {
          throw ProctoringException('Upload succeeded but uploadReference was missing from server response.');
        }

        return uploadReference;
      },
      maxAttempts: 4,
    );
  }

  Future<int> _queryUploadedBytes(String uploadId, String token) async {
    try {
      final res = await _dio.head<Map<String, dynamic>>(
        ProctoringConstants.uploadEndpoint,
        queryParameters: {'uploadId': uploadId},
        options: Options(
          headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
        ),
      );

      return int.tryParse(res.headers.value('x-uploaded-bytes') ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
