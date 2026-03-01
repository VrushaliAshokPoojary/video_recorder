import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_recorder/src/data/services/consent_audit_service.dart';
import 'package:video_recorder/src/domain/entities/exam_session.dart';
import 'package:video_recorder/src/domain/entities/proctoring_result.dart';
import 'package:video_recorder/src/domain/repositories/proctoring_repository.dart';
import 'package:video_recorder/src/domain/usecases/end_exam_usecase.dart';
import 'package:video_recorder/src/domain/usecases/start_exam_usecase.dart';
import 'package:video_recorder/src/presentation/exam/bloc/exam_controller.dart';
import 'package:video_recorder/src/presentation/exam/bloc/exam_state.dart';

class _FakeConsentAuditService extends ConsentAuditService {
  _FakeConsentAuditService() : super(Dio());

  @override
  Future<void> logConsent({
    required String token,
    required String examId,
    required String candidateId,
    required String appVersion,
  }) async {}
}

class _FakeRepo implements ProctoringRepository {
  bool started = false;

  @override
  Future<void> startStealthRecording(ExamSession session) async {
    started = true;
  }

  @override
  Future<ProctoringResult> endExamAndUpload(ExamSession session) async {
    return const ProctoringResult(
      rawVideoPath: 'raw.mp4',
      compressedVideoPath: 'compressed.mp4',
      rawSizeBytes: 100,
      compressedSizeBytes: 50,
      uploadReference: 'upload-ref',
    );
  }
}

void main() {
  test('controller moves to running on successful start', () async {
    final repo = _FakeRepo();
    final controller = ExamController(
      startExamUseCase: StartExamUseCase(repo),
      endExamUseCase: EndExamUseCase(repo),
      consentAuditService: _FakeConsentAuditService(),
    );

    final session = ExamSession(
      examId: 'EX1',
      candidateId: 'C1',
      authToken: 'token',
      uploadId: 'up1',
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    await controller.startExam(session: session, consentAccepted: true);

    expect(controller.state.status, ExamStatus.running);
    expect(repo.started, true);

    await controller.close();
  });

  test('controller rejects start when consent missing', () async {
    final repo = _FakeRepo();
    final controller = ExamController(
      startExamUseCase: StartExamUseCase(repo),
      endExamUseCase: EndExamUseCase(repo),
      consentAuditService: _FakeConsentAuditService(),
    );

    final session = ExamSession(
      examId: 'EX1',
      candidateId: 'C1',
      authToken: 'token',
      uploadId: 'up1',
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    await controller.startExam(session: session, consentAccepted: false);

    expect(controller.state.status, ExamStatus.error);
    expect(repo.started, false);

    await controller.close();
  });
}
