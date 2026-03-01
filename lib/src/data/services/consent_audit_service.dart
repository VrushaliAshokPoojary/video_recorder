import 'package:dio/dio.dart';

class ConsentAuditService {
  ConsentAuditService(this._dio);
  final Dio _dio;

  Future<void> logConsent({
    required String examId,
    required String candidateId,
    required String appVersion,
    required String deviceHash,
  }) async {
    await _dio.post(
      'https://api.yourdomain.com/v1/audit/consent',
      data: {
        'examId': examId,
        'candidateId': candidateId,
        'timestampUtc': DateTime.now().toUtc().toIso8601String(),
        'appVersion': appVersion,
        'deviceHash': deviceHash,
      },
    );
  }
}