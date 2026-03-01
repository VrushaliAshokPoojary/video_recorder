import 'package:equatable/equatable.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.examId,
    required this.candidateId,
    required this.token,
    required this.expiresAtUtc,
    required this.uploadId,
  });

  final String examId;
  final String candidateId;
  final String token;
  final DateTime expiresAtUtc;
  final String uploadId;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);

  @override
  List<Object?> get props => [examId, candidateId, token, expiresAtUtc, uploadId];
}
