import '../entities/exam_session.dart';
import '../entities/proctoring_result.dart';

abstract class ProctoringRepository {
  Future<void> ensurePermissionsOrThrow();
  Future<void> startSessionRecording(ExamSession session);
  Future<ProctoringResult> stopAndUploadSession(ExamSession session);
  Future<void> onLifecyclePaused(ExamSession session);
  Future<void> onLifecycleResumed(ExamSession session);
  Future<void> dispose();
}
