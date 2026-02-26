class ExamSession {
  const ExamSession({
    required this.examId,
    required this.candidateId,
    required this.authToken,
    required this.startedAt,
  });

  final String examId;
  final String candidateId;
  final String authToken;
  final DateTime startedAt;
}
