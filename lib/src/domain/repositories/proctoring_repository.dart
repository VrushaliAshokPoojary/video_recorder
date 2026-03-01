import '../entities/exam_session.dart';
import '../entities/proctoring_result.dart';

abstract class ProctoringRepository {
  Future<void> startStealthRecording(ExamSession session);

  Future<ProctoringResult> endExamAndUpload(ExamSession session);
}
