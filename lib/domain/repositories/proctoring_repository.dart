import '../models/exam_session.dart';

abstract class ProctoringRepository {
  Future<void> startSession(ExamSession session);
  Future<void> stopSession();
}
