import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/constants/proctoring_constants.dart';

class ConsentAuditService {
  ConsentAuditService(this._dio);

  final Dio _dio;

  Future<void> logConsent({
    required String token,
    required String examId,
    required String candidateId,
    required String appVersion,
  }) async {
    final rawDeviceFingerprint = '$candidateId:$examId:$appVersion';
    final deviceHash = sha256.convert(rawDeviceFingerprint.codeUnits).toString();

    await _dio.post<void>(
      ProctoringConstants.consentAuditEndpoint,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
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
