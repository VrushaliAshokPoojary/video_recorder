import 'package:equatable/equatable.dart';

class ExamSession extends Equatable {
  const ExamSession({
    required this.examId,
    required this.candidateId,
    required this.authToken,
  });

  final String examId;
  final String candidateId;
  final String authToken;

  @override
  List<Object?> get props => [examId, candidateId, authToken];
}
