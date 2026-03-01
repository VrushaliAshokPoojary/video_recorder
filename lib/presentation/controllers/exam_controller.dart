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
  bool showPermissionSettingsAction = false;
  bool examSubmitted = false;
  String status = 'Please review consent and start exam.';

  ExamSession? _activeSession;

  Future<void> acceptConsent() async {
    consentAccepted = true;
    status = 'Consent captured. Start exam to begin secure recording.';
    notifyListeners();
  }

  Future<void> startExamAndRecording() async {
    if (isRecording || isBusy || examSubmitted) return;

    isBusy = true;
    showPermissionSettingsAction = false;
    status = 'Checking permissions...';
    notifyListeners();

    try {
      if (!consentAccepted) {
        status = 'User consent is required before exam can begin.';
        return;
      }

      final permissionResult = await _permissionService.ensureExamPermissions();
      if (!permissionResult.allGranted) {
        showPermissionSettingsAction = permissionResult.permanentlyDenied;
        status = permissionResult.permanentlyDenied
            ? 'Camera/microphone permission permanently denied. Open settings to allow access.'
            : 'Camera/microphone permission denied. Please allow access and try again.';
        return;
      }

      status = 'Starting exam session...';
      notifyListeners();

      final session = ExamSession(
        examId: const Uuid().v4(),
        userId: 'student_001',
        jwt: 'mock.jwt.token',
      );

      await _repository.startSession(session);
      _activeSession = session;
      isRecording = true;
      status = 'Exam started. Proctoring video recording is active.';
    } catch (e) {
      isRecording = false;
      status = 'Failed to start recording: $e';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> submitExam() async {
    if (isBusy || examSubmitted) return;

    isBusy = true;
    status = 'Submitting exam and finalizing recording...';
    notifyListeners();

    try {
      final savedPath = await _repository.finalizeSessionAndGetSavedPath();
      isRecording = false;
      _activeSession = null;
      examSubmitted = true;

      if (savedPath == null) {
        status =
            'Exam submitted. No active recording was found, but submission completed.';
      } else {
        status = 'Exam submitted successfully. Video saved at: $savedPath';
      }
    } catch (e) {
      status = 'Submission failed: $e';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> openAppSettingsForPermissions() async {
    await _permissionService.openPermissionSettings();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!isRecording) return;

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
