import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/repositories/exam_proctoring_repository_impl.dart';
import '../../domain/entities/recording_session.dart';
import '../../domain/repositories/exam_proctoring_repository.dart';

class ExamController extends ChangeNotifier with WidgetsBindingObserver {
  ExamController({ExamProctoringRepository? repository})
      : _repository = repository ?? ExamProctoringRepositoryImpl();

  final ExamProctoringRepository _repository;

  bool _isExamRunning = false;
  bool _isRecording = false;
  bool _isBusy = false;
  String _statusMessage = 'Ready';
  RecordingSession? _session;
  String? _authToken;

  bool get isExamRunning => _isExamRunning;
  bool get isRecording => _isRecording;
  bool get isBusy => _isBusy;
  String get statusMessage => _statusMessage;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    if (_repository is ExamProctoringRepositoryImpl) {
      _authToken =
          await (_repository as ExamProctoringRepositoryImpl).getStoredToken();
    }
  }

  Future<void> setToken(String token) async {
    _authToken = token;
    if (_repository is ExamProctoringRepositoryImpl) {
      await (_repository as ExamProctoringRepositoryImpl).saveToken(token);
    }
    notifyListeners();
  }

  /// Starts exam and auto-starts stealth recording.
  Future<void> startExam({required String examId}) async {
    if (_isExamRunning || _isBusy) {
      return;
    }

    _setBusy(true, 'Requesting permissions...');
    final granted = await _repository.ensurePermissions();
    if (!granted) {
      _setBusy(false, 'Permissions denied. Cannot start exam.');
      return;
    }

    try {
      _statusMessage = 'Starting stealth recording...';
      notifyListeners();

      _session = await _repository.startExamRecording(examId: examId);
      _isExamRunning = true;
      _isRecording = true;
      _setBusy(false, 'Exam started. Recording in background.');
    } catch (error) {
      _setBusy(false, 'Failed to start recording: $error');
    }
  }

  Future<void> stopExam() async {
    if (!_isExamRunning || _isBusy || _session == null) {
      return;
    }

    if ((_authToken ?? '').isEmpty) {
      _statusMessage = 'Missing auth token. Add token before stopping exam.';
      notifyListeners();
      return;
    }

    _setBusy(true, 'Stopping recording...');

    try {
      final stoppedSession = await _repository.stopExamRecording(
        examId: _session!.examId,
        outputPath: _session!.rawVideoPath,
      );
      _isRecording = false;

      _statusMessage = 'Compressing locally...';
      notifyListeners();
      final compressed = await compute<RecordingSession, RecordingSession>(
        _compressIsolate,
        stoppedSession,
      );

      _statusMessage = 'Uploading securely...';
      notifyListeners();
      await _repository.uploadRecording(
        session: compressed,
        authToken: _authToken!,
      );

      _isExamRunning = false;
      _session = null;
      _setBusy(false, 'Exam completed, compressed video uploaded successfully.');
    } catch (error) {
      _setBusy(false, 'Failed to end exam flow: $error');
    }
  }

  static Future<RecordingSession> _compressIsolate(RecordingSession session) async {
    final repo = ExamProctoringRepositoryImpl();
    final compressed = await repo.compressRecording(session);
    await repo.dispose();
    return compressed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isRecording = false;
      notifyListeners();
    }

    /// Best-effort recovery when returning to foreground.
    if (state == AppLifecycleState.resumed && _isExamRunning && !_isRecording) {
      _resumeStealthRecording();
    }
  }

  Future<void> _resumeStealthRecording() async {
    final existing = _session;
    if (existing == null || _isBusy) {
      return;
    }

    try {
      _statusMessage = 'Resuming recording after interruption...';
      notifyListeners();
      _session = await _repository.startExamRecording(examId: existing.examId);
      _isRecording = true;
      _statusMessage = 'Recording resumed.';
      notifyListeners();
    } catch (_) {
      _statusMessage = 'Could not auto-resume recording. Please keep app active.';
      notifyListeners();
    }
  }

  Future<void> disposeController() async {
    WidgetsBinding.instance.removeObserver(this);
    await _repository.dispose();
  }

  void _setBusy(bool value, String message) {
    _isBusy = value;
    _statusMessage = message;
    notifyListeners();
  }
}
