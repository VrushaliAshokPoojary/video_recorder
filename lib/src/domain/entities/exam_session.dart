import 'package:equatable/equatable.dart';

class ExamSession extends Equatable {
  const ExamSession({
    required this.examId,
    required this.candidateId,
    required this.authToken,
    required this.uploadId,
    required this.expiresAtUtc,
  });

  final String examId;
  final String candidateId;
  final String authToken;
  final String uploadId;
  final DateTime expiresAtUtc;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);

  @override
  List<Object?> get props => [examId, candidateId, authToken, uploadId, expiresAtUtc];
}
