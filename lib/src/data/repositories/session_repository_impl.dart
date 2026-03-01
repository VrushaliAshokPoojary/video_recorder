import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/constants/proctoring_constants.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final Uuid _uuid = const Uuid();

  @override
  Future<AuthSession?> loadCurrentSession() async {
    final examId = ProctoringConstants.runtimeExamId;
    final candidateId = ProctoringConstants.runtimeCandidateId;
    final token = ProctoringConstants.runtimeAuthToken;

    if (examId == null || candidateId == null || token == null) {
      return null;
    }

    final expiresAtUtc = _resolveExpiry(token);

    return AuthSession(
      examId: examId,
      candidateId: candidateId,
      token: token,
      expiresAtUtc: expiresAtUtc,
      uploadId: _uuid.v4(),
    );
  }

  DateTime _resolveExpiry(String jwt) {
    final providedEpoch = ProctoringConstants.runtimeSessionExpiryEpochSeconds;
    if (providedEpoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(providedEpoch * 1000, isUtc: true);
    }

    final parts = jwt.split('.');
    if (parts.length == 3) {
      try {
        final normalized = base64Url.normalize(parts[1]);
        final payloadJson = utf8.decode(base64Url.decode(normalized));
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final exp = payload['exp'];
        if (exp is int) {
          return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
        }
        if (exp is String) {
          final parsed = int.tryParse(exp);
          if (parsed != null) {
            return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
          }
        }
      } catch (_) {
        // Fall through to conservative fallback below.
      }
    }

    // Conservative fallback: short-lived session when token expiry cannot be decoded.
    return DateTime.now().toUtc().add(const Duration(minutes: 15));
  }
}
