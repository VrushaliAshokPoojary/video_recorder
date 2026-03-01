import '../entities/recording_session.dart';

abstract class ExamProctoringRepository {
  Future<bool> ensurePermissions();

  Future<RecordingSession> startExamRecording({required String examId});

  Future<RecordingSession> stopExamRecording({
    required String examId,
    required String outputPath,
  });

  Future<RecordingSession> compressRecording(RecordingSession session);

  Future<void> uploadRecording({
    required RecordingSession session,
    required String authToken,
  });

  Future<void> dispose();
}
