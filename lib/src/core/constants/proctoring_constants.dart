class ProctoringConstants {
  ProctoringConstants._();

  static const int minBitrate = 2 * 1024 * 1024; // 2 Mbps
  static const int maxBitrate = 4 * 1024 * 1024; // 4 Mbps target for 1080p
  static const int targetFrameRate = 30;
  static const int compressionScalePercent = 50;

  /// Provide a real backend URL from build-time vars.
  static const String uploadEndpoint = String.fromEnvironment(
    'UPLOAD_ENDPOINT',
    defaultValue: 'https://staging-api.your-domain.com/v1/uploads/exam-video',
  );

  static const String consentAuditEndpoint = String.fromEnvironment(
    'CONSENT_AUDIT_ENDPOINT',
    defaultValue: 'https://staging-api.your-domain.com/v1/audit/consent',
  );

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://your-domain.com/privacy-policy',
  );

  static const String _examId = String.fromEnvironment('EXAM_ID', defaultValue: '');
  static const String _candidateId = String.fromEnvironment('CANDIDATE_ID', defaultValue: '');
  static const String _authToken = String.fromEnvironment('AUTH_TOKEN', defaultValue: '');
  static const String _sessionExpiryEpochSeconds = String.fromEnvironment(
    'SESSION_EXPIRY_EPOCH_SECONDS',
    defaultValue: '',
  );

  static String? get runtimeExamId => _examId.isEmpty ? null : _examId;
  static String? get runtimeCandidateId => _candidateId.isEmpty ? null : _candidateId;
  static String? get runtimeAuthToken => _authToken.isEmpty ? null : _authToken;

  static int? get runtimeSessionExpiryEpochSeconds =>
      _sessionExpiryEpochSeconds.isEmpty ? null : int.tryParse(_sessionExpiryEpochSeconds);
}
