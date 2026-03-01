import '../entities/exam_session.dart';
import '../entities/proctoring_result.dart';
import '../repositories/proctoring_repository.dart';

class EndExamUseCase {
  EndExamUseCase(this._repository);

  final ProctoringRepository _repository;

  Future<ProctoringResult> call(ExamSession session) {
    return _repository.endExamAndUpload(session);
  }
}
