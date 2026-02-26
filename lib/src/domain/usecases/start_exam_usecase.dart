import '../entities/exam_session.dart';
import '../repositories/proctoring_repository.dart';

class StartExamUseCase {
  const StartExamUseCase(this._repository);

  final ProctoringRepository _repository;

  Future<void> call(ExamSession session) async {
    await _repository.ensurePermissionsOrThrow();
    await _repository.startSessionRecording(session);
  }
}
