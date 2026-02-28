import 'package:flutter/foundation.dart';

import '../../core/errors/proctoring_exception.dart';
import '../../domain/entities/exam_session.dart';
import '../../domain/entities/proctoring_result.dart';
import '../../domain/repositories/proctoring_repository.dart';
import '../../domain/usecases/end_exam_usecase.dart';
import '../../domain/usecases/start_exam_usecase.dart';

enum ExamStatus { idle, starting, running, ending, completed, failed }

class ExamController extends ChangeNotifier {
  ExamController({
    required StartExamUseCase startExamUseCase,
    required EndExamUseCase endExamUseCase,
    required ProctoringRepository proctoringRepository,
  })  : _startExamUseCase = startExamUseCase,
        _endExamUseCase = endExamUseCase,
        _proctoringRepository = proctoringRepository;

  final StartExamUseCase _startExamUseCase;
  final EndExamUseCase _endExamUseCase;
  final ProctoringRepository _proctoringRepository;

  ExamStatus _status = ExamStatus.idle;
  String? _error;
  ProctoringResult? _result;
  ExamSession? _activeSession;
  bool _hasConsent = false;

  ExamStatus get status => _status;
  String? get error => _error;
  ProctoringResult? get result => _result;
  bool get hasConsent => _hasConsent;

  void setConsent(bool value) {
    _hasConsent = value;
    if (_error != null) {
      _error = null;
    }
    notifyListeners();
  }

  Future<void> startExam() async {
    if (!_hasConsent) {
      _status = ExamStatus.failed;
      _error =
          'Candidate consent is required before starting monitored recording.';
      notifyListeners();
      return;
    }

    _status = ExamStatus.starting;
    _error = null;
    notifyListeners();

    try {
      final session = ExamSession(
        examId: 'EXAM-2026-001',
        candidateId: 'CAND-200',
        authToken: 'mock-jwt-token',
        startedAt: DateTime.now(),
      );

      await _startExamUseCase(session);
      _activeSession = session;
      _status = ExamStatus.running;
    } on ProctoringException catch (e) {
      _status = ExamStatus.failed;
      _error = e.message;
    } catch (e) {
      _status = ExamStatus.failed;
      _error = 'Unexpected error: $e';
    }

    notifyListeners();
  }

  Future<void> endExam() async {
    final session = _activeSession;
    if (session == null) return;

    _status = ExamStatus.ending;
    notifyListeners();

    try {
      _result = await _endExamUseCase(session);
      _status = ExamStatus.completed;
    } catch (e) {
      _status = ExamStatus.failed;
      _error = e.toString();
    }

    notifyListeners();
  }

  Future<void> onAppPaused() async {
    final session = _activeSession;
    if (session == null) return;
    await _proctoringRepository.onLifecyclePaused(session);
  }

  Future<void> onAppResumed() async {
    final session = _activeSession;
    if (session == null) return;
    await _proctoringRepository.onLifecycleResumed(session);
  }

  Future<void> shutdown() async {
    await _proctoringRepository.dispose();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
