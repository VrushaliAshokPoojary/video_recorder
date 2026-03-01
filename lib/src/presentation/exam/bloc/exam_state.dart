import 'package:equatable/equatable.dart';

import '../../../domain/entities/proctoring_result.dart';

enum ExamStatus {
  idle,
  starting,
  running,
  ending,
  finished,
  error,
}

class ExamState extends Equatable {
  const ExamState({
    this.status = ExamStatus.idle,
    this.errorMessage,
    this.result,
  });

  final ExamStatus status;
  final String? errorMessage;
  final ProctoringResult? result;

  ExamState copyWith({
    ExamStatus? status,
    String? errorMessage,
    ProctoringResult? result,
  }) {
    return ExamState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, result];
}
