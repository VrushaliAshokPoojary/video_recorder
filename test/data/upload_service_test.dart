import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_recorder/src/data/services/upload_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.onFetch});

  final Future<ResponseBody> Function(RequestOptions requestOptions) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions requestOptions,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(requestOptions);
  }
}

void main() {
  test('upload adds auth/exam/candidate headers and conditional content-range', () async {
    final tempFile = File('${Directory.systemTemp.path}/upload_test.mp4');
    await tempFile.writeAsBytes(List<int>.filled(16, 1));

    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter(
      onFetch: (req) async {
        requests.add(req);
        if (req.method == 'HEAD') {
          return ResponseBody.fromString(
            '',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
              'x-uploaded-bytes': ['0'],
            },
          );
        }

        return ResponseBody.fromString(
          jsonEncode({'uploadReference': 'up_ref'}),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      },
    );

    final service = UploadService(dio);
    final ref = await service.uploadVideo(
      file: tempFile,
      token: 'jwt-token',
      examId: 'EX1',
      candidateId: 'C1',
      uploadId: 'up1',
    );

    expect(ref, 'up_ref');

    final postRequest = requests.firstWhere((r) => r.method == 'POST');
    expect(postRequest.headers[HttpHeaders.authorizationHeader], 'Bearer jwt-token');
    expect(postRequest.headers['X-Exam-Id'], 'EX1');
    expect(postRequest.headers['X-Candidate-Id'], 'C1');
    expect(postRequest.headers.containsKey('Content-Range'), isFalse);

    await tempFile.delete();
  });

  test('upload throws when uploadReference is missing in server response', () async {
    final tempFile = File('${Directory.systemTemp.path}/upload_test_missing_ref.mp4');
    await tempFile.writeAsBytes(List<int>.filled(16, 1));

    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter(
      onFetch: (req) async {
        if (req.method == 'HEAD') {
          return ResponseBody.fromString(
            '',
            200,
            headers: {'x-uploaded-bytes': ['0']},
          );
        }

        return ResponseBody.fromString(
          jsonEncode({'status': 'ok'}),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']},
        );
      },
    );

    final service = UploadService(dio);
    await expectLater(
      service.uploadVideo(
        file: tempFile,
        token: 'jwt-token',
        examId: 'EX1',
        candidateId: 'C1',
        uploadId: 'up1',
      ),
      throwsException,
    );

    await tempFile.delete();
  });
}
