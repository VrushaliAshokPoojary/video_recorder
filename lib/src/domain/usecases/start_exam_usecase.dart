import '../entities/exam_session.dart';
import '../repositories/proctoring_repository.dart';

class StartExamUseCase {
  StartExamUseCase(this._repository);

  final ProctoringRepository _repository;

  Future<void> call(ExamSession session) {
    return _repository.startStealthRecording(session);
  }
}
