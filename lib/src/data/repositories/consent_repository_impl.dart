import '../../domain/repositories/consent_repository.dart';
import '../services/consent_audit_service.dart';

class ConsentRepositoryImpl implements ConsentRepository {
  ConsentRepositoryImpl({
    required ConsentAuditService consentAuditService,
    required String authToken,
  })  : _consentAuditService = consentAuditService,
        _authToken = authToken;

  final ConsentAuditService _consentAuditService;
  final String _authToken;

  @override
  Future<void> logConsent({
    required String examId,
    required String candidateId,
    required String appVersion,
    required String deviceHash,
  }) {
    return _consentAuditService.logConsent(
      token: _authToken,
      examId: examId,
      candidateId: candidateId,
      appVersion: appVersion,
    );
  }
}
