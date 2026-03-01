import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../domain/models/exam_session.dart';

class UploadService {
  UploadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> uploadCompressedVideo({
    required String filePath,
    required ExamSession session,
  }) async {
    final file = File(filePath);
    final fileLength = await file.length();

    var offset = 0;
    var chunkIndex = 0;
    while (offset < fileLength) {
      final end = (offset + AppConfig.uploadChunkSizeBytes).clamp(0, fileLength);
      final length = end - offset;

      final chunk = await _readChunk(file, offset, length);

      await _executeWithRetry(() {
        return _dio.post(
          AppConfig.uploadEndpoint,
          data: Stream.value(chunk),
          options: Options(
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer ${session.jwt}',
              'Content-Type': 'application/octet-stream',
              'X-Exam-Id': session.examId,
              'X-User-Id': session.userId,
              'X-Chunk-Index': chunkIndex,
              'X-Chunk-Start': offset,
              'X-Chunk-End': end,
              'X-File-Size': fileLength,
            },
          ),
        );
      });

      offset = end;
      chunkIndex += 1;
    }
  }

  Future<List<int>> _readChunk(File file, int offset, int length) async {
    final raf = await file.open();
    try {
      await raf.setPosition(offset);
      return raf.read(length);
    } finally {
      await raf.close();
    }
  }

  Future<void> _executeWithRetry(Future<void> Function() request) async {
    var attempt = 0;
    while (true) {
      try {
        await request();
        return;
      } on DioException {
        attempt += 1;
        if (attempt >= AppConfig.maxUploadRetries) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }
}
