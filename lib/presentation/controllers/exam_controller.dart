import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/proctoring_repository_impl.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/compression_service.dart';
import '../../data/services/permission_service.dart';
import '../../data/services/upload_service.dart';
import '../../domain/models/exam_session.dart';

class ExamController extends ChangeNotifier with WidgetsBindingObserver {
  ExamController({
    PermissionService? permissionService,
    ProctoringRepositoryImpl? repository,
  })  : _permissionService = permissionService ?? PermissionService(),
        _repository =
            repository ??
            ProctoringRepositoryImpl(
              cameraService: CameraService(),
              compressionService: CompressionService(),
              uploadService: UploadService(),
            ) {
    WidgetsBinding.instance.addObserver(this);
  }

  final PermissionService _permissionService;
  final ProctoringRepositoryImpl _repository;

  bool isBusy = false;
  bool isRecording = false;
  bool consentAccepted = false;
  String status = 'Waiting to start exam';

  ExamSession? _activeSession;

  Future<void> acceptConsent() async {
    consentAccepted = true;
    notifyListeners();
  }

  Future<void> startExamAndRecording() async {
    if (isRecording || isBusy) return;

    isBusy = true;
    status = 'Checking permissions...';
    notifyListeners();

    try {
      final granted = await _permissionService.ensureExamPermissions();
      if (!granted) {
        status =
            'Camera/microphone permission denied. Exam cannot start safely.';
        return;
      }

      if (!consentAccepted) {
        status = 'User consent is required before recording can begin.';
        return;
      }

      status = 'Starting secure proctoring...';
      notifyListeners();

      final session = ExamSession(
        examId: const Uuid().v4(),
        userId: 'student_001',
        jwt: 'mock.jwt.token',
      );

      await _repository.startSession(session);
      _activeSession = session;
      isRecording = true;
      status =
          'Exam live. Front camera is recording silently in the background.';
    } catch (e) {
      status = 'Failed to start recording: $e';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> stopExamAndFinalize() async {
    if (!isRecording || isBusy) return;

    isBusy = true;
    status = 'Stopping recording and processing video...';
    notifyListeners();

    try {
      await _repository.stopSession();
      isRecording = false;
      _activeSession = null;
      status = 'Exam ended. Video compressed and uploaded securely.';
    } catch (e) {
      status = 'Stop failed: $e';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!isRecording) return;

    // Lifecycle handling:
    // - When app becomes inactive/paused, the background service keeps process
    //   alive on Android.
    // - On resume, we can validate session continuity and restart capture if
    //   required by backend policy.
    if (state == AppLifecycleState.resumed && _activeSession != null) {
      status = 'Exam resumed. Verifying proctoring session continuity...';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repository.dispose();
    super.dispose();
  }
}
