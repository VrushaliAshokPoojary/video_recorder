import '../../domain/repositories/proctoring_repository.dart';

class StopRecordingUseCase {
  const StopRecordingUseCase(this._repository);

  final ProctoringRepository _repository;

  Future<void> call() {
    return _repository.stopSession();
  }
}
