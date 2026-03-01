class ExamSession {
  const ExamSession({
    required this.examId,
    required this.userId,
    required this.jwt,
  });

  final String examId;
  final String userId;
  final String jwt;
}
