import 'package:exam_proctor_app/src/domain/entities/exam_session.dart';
import 'package:exam_proctor_app/src/domain/entities/proctoring_result.dart';
import 'package:exam_proctor_app/src/domain/repositories/proctoring_repository.dart';
import 'package:exam_proctor_app/src/domain/usecases/end_exam_usecase.dart';
import 'package:exam_proctor_app/src/domain/usecases/start_exam_usecase.dart';
import 'package:exam_proctor_app/src/presentation/exam/exam_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements ProctoringRepository {
  bool started = false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> ensurePermissionsOrThrow() async {}

  @override
  Future<void> onLifecyclePaused(ExamSession session) async {}

  @override
  Future<void> onLifecycleResumed(ExamSession session) async {}

  @override
  Future<void> startSessionRecording(ExamSession session) async {
    started = true;
  }

  @override
  Future<ProctoringResult> stopAndUploadSession(ExamSession session) async {
    return const ProctoringResult(
      originalPath: 'raw.mp4',
      compressedPath: 'compressed.mp4',
      uploadId: 'upload-1',
      originalBytes: 100,
      compressedBytes: 50,
    );
  }
}

void main() {
  test('controller blocks start when consent is not provided', () async {
    final repo = _FakeRepo();
    final controller = ExamController(
      startExamUseCase: StartExamUseCase(repo),
      endExamUseCase: EndExamUseCase(repo),
      proctoringRepository: repo,
    );

    await controller.startExam();

    expect(controller.status, ExamStatus.failed);
    expect(repo.started, isFalse);
    expect(controller.error, contains('consent'));
  });

  test('controller starts and ends exam flow', () async {
    final repo = _FakeRepo();
    final controller = ExamController(
      startExamUseCase: StartExamUseCase(repo),
      endExamUseCase: EndExamUseCase(repo),
      proctoringRepository: repo,
    );

    controller.setConsent(true);
    await controller.startExam();
    expect(controller.status, ExamStatus.running);
    expect(repo.started, isTrue);

    await controller.endExam();
    expect(controller.status, ExamStatus.completed);
    expect(controller.result?.uploadId, 'upload-1');
  });
}
