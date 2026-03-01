class AuthSession {
  const AuthSession({
    required this.examId,
    required this.candidateId,
    required this.token,
    required this.expiresAtUtc,
  });

  final String examId;
  final String candidateId;
  final String token;
  final DateTime expiresAtUtc;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);
}