import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../../../data/services/camera_service.dart';
import '../../../data/services/consent_audit_service.dart';
import '../../../domain/entities/exam_session.dart';
import '../../../domain/usecases/end_exam_usecase.dart';
import '../../../domain/usecases/start_exam_usecase.dart';
import 'exam_state.dart';

class ExamController extends Cubit<ExamState> with WidgetsBindingObserver {
  ExamController({
    required StartExamUseCase startExamUseCase,
    required EndExamUseCase endExamUseCase,
    required ConsentAuditService consentAuditService,
  })  : _startExamUseCase = startExamUseCase,
        _endExamUseCase = endExamUseCase,
        _consentAuditService = consentAuditService,
        super(const ExamState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final StartExamUseCase _startExamUseCase;
  final EndExamUseCase _endExamUseCase;
  final ConsentAuditService _consentAuditService;
  ExamSession? _session;

  Future<void> startExam({
    required ExamSession session,
    required bool consentAccepted,
  }) async {
    if (state.status == ExamStatus.running || state.status == ExamStatus.starting) {
      return;
    }

    if (!consentAccepted) {
      emit(
        state.copyWith(
          status: ExamStatus.error,
          errorMessage:
              'Consent is required before starting the proctored exam session.',
        ),
      );
      return;
    }

    if (session.isExpired || session.authToken.isEmpty) {
      emit(
        state.copyWith(
          status: ExamStatus.error,
          errorMessage: 'Session expired. Please login again.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ExamStatus.starting, errorMessage: null));

    try {
      await _consentAuditService.logConsent(
        token: session.authToken,
        examId: session.examId,
        candidateId: session.candidateId,
        appVersion: '1.0.0',
      );

      _session = session;
      await _startExamUseCase(session);
      emit(state.copyWith(status: ExamStatus.running));
    } catch (e) {
      final message = e.toString();
      final friendlyMessage = message.contains('Front camera not available')
          ? 'Front camera unavailable. This device cannot start proctored exam.'
          : message;
      emit(state.copyWith(status: ExamStatus.error, errorMessage: friendlyMessage));
    }
  }

  Future<void> endExam() async {
    final session = _session;
    if (session == null || state.status != ExamStatus.running) return;

    emit(state.copyWith(status: ExamStatus.ending));

    try {
      final result = await _endExamUseCase(session);
      emit(state.copyWith(status: ExamStatus.finished, result: result));
    } catch (e) {
      final message = e.toString();
      final friendlyMessage = message.contains('Front camera not available')
          ? 'Front camera unavailable. This device cannot start proctored exam.'
          : message;
      emit(state.copyWith(status: ExamStatus.error, errorMessage: friendlyMessage));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraService = getIt<CameraService>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      cameraService.pauseIfNeeded();
    }

    if (state == AppLifecycleState.resumed) {
      cameraService.resumeIfNeeded();
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
