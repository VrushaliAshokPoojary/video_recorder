import '../../domain/models/exam_session.dart';
import '../../domain/repositories/proctoring_repository.dart';

class StartRecordingUseCase {
  const StartRecordingUseCase(this._repository);

  final ProctoringRepository _repository;

  Future<void> call(ExamSession session) {
    return _repository.startSession(session);
  }
}
