import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../../../data/services/camera_service.dart';
import '../../../domain/entities/exam_session.dart';
import '../../../domain/usecases/end_exam_usecase.dart';
import '../../../domain/usecases/start_exam_usecase.dart';
import 'exam_state.dart';

class ExamController extends Cubit<ExamState> with WidgetsBindingObserver {
  ExamController({
    required StartExamUseCase startExamUseCase,
    required EndExamUseCase endExamUseCase,
  })  : _startExamUseCase = startExamUseCase,
        _endExamUseCase = endExamUseCase,
        super(const ExamState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final StartExamUseCase _startExamUseCase;
  final EndExamUseCase _endExamUseCase;
  ExamSession? _session;

  Future<void> startExam(ExamSession session) async {
    if (state.status == ExamStatus.running || state.status == ExamStatus.starting) {
      return;
    }

    emit(state.copyWith(status: ExamStatus.starting, errorMessage: null));

    try {
      _session = session;
      await _startExamUseCase(session);
      emit(state.copyWith(status: ExamStatus.running));
    } catch (e) {
      emit(state.copyWith(status: ExamStatus.error, errorMessage: e.toString()));
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
      emit(state.copyWith(status: ExamStatus.error, errorMessage: e.toString()));
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
